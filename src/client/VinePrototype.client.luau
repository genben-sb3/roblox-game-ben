--!strict
--[[
	PROTOTYPE — throwaway, lives on `prototype/vine`, never merged to main.

	Question: can Ben tell at duel distance, in under a second, that an
	incoming Ability is a Vine and not a Root? (Issue #5, ADR 0001.)

	Three structurally different Vine variants on one fixed duel scene, seen
	from behind the defender the way the Commit Window will show it:

		A  Lash     one line — a tendril shoots from the attacker's hand
		B  Current  a field — everything around you streams toward the hand
		C  Coil     an enclosure — a spiral closes around you

	All of them end the same way: the defender is yanked toward the attacker,
	because that is what a Vine does. Only the incoming part differs, and that
	is the part the defender has to read.

	Keys:  Left / Right  switch variant     Space  replay now
	       S  toggle slow motion             D      cycle duel distance

	Built only from ParticleEmitter, Beam and Trail on invisible carrier parts,
	with textures that ship with the client, so nothing needs uploading.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsStudio() then
	return
end

-- Far above whatever the place has, so nothing else is in the shot.
local ORIGIN = Vector3.new(0, 300, 0)
local HIP = 2
local DISTANCES = { 12, 20, 30 }
local PULL_DISTANCE = 5
local SLOW_MOTION = 0.3
local LOOP_PAUSE = 1.2

local VINE_DARK = Color3.fromRGB(30, 110, 40)
local VINE_LIGHT = Color3.fromRGB(170, 255, 90)
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"

local distanceIndex = 2
local speed = 1

local scene = Instance.new("Folder")
scene.Name = "VinePrototype"
scene.Parent = workspace

local floor = Instance.new("Part")
floor.Name = "Floor"
floor.Anchored = true
floor.Size = Vector3.new(80, 1, 80)
floor.Position = ORIGIN - Vector3.new(0, 0.5, 0)
floor.Color = Color3.fromRGB(72, 66, 60)
floor.Material = Enum.Material.SmoothPlastic
floor.Parent = scene

----------------------------------------------------------------------------
-- Figures: block stand-ins, so the effect is judged against a body's scale.
----------------------------------------------------------------------------

type Figure = {
	model: Model,
	hand: Attachment,
	chest: Attachment,
	home: CFrame,
}

local function limb(model: Model, name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = model
	return part
end

-- Builds a figure at the origin with its pivot at the hip. The attacker holds
-- its right arm out toward the defender; the defender's arms hang.
local function buildFigure(name: string, color: Color3, armForward: boolean): Figure
	local model = Instance.new("Model")
	model.Name = name
	local root = CFrame.new()

	local torso = limb(model, "Torso", Vector3.new(2, 2, 1), color)
	torso.CFrame = root * CFrame.new(0, 1, 0)
	limb(model, "Head", Vector3.new(1.2, 1.2, 1.2), color).CFrame = root * CFrame.new(0, 2.6, 0)
	limb(model, "LeftArm", Vector3.new(1, 2, 1), color).CFrame = root * CFrame.new(-1.5, 1, 0)
	limb(model, "LeftLeg", Vector3.new(1, 2, 1), color).CFrame = root * CFrame.new(-0.5, -1, 0)
	limb(model, "RightLeg", Vector3.new(1, 2, 1), color).CFrame = root * CFrame.new(0.5, -1, 0)

	local rightArm = limb(model, "RightArm", Vector3.new(1, 2, 1), color)
	if armForward then
		-- Rotating 90 degrees about X turns the arm's down axis into forward.
		rightArm.CFrame = root * CFrame.new(1.5, 1.6, -1) * CFrame.Angles(math.rad(90), 0, 0)
	else
		rightArm.CFrame = root * CFrame.new(1.5, 1, 0)
	end

	local hand = Instance.new("Attachment")
	hand.Name = "Hand"
	hand.Position = Vector3.new(0, -1.1, 0)
	hand.Parent = rightArm

	local chest = Instance.new("Attachment")
	chest.Name = "Chest"
	chest.Parent = torso

	model.WorldPivot = root
	model.Parent = scene
	return { model = model, hand = hand, chest = chest, home = root }
end

local attacker = buildFigure("Attacker", Color3.fromRGB(180, 70, 60), true)
local defender = buildFigure("Defender", Color3.fromRGB(70, 110, 190), false)

local cameraCFrame = CFrame.new()

local function layout()
	local half = DISTANCES[distanceIndex] / 2
	local attackerAt = ORIGIN + Vector3.new(0, HIP, -half)
	local defenderAt = ORIGIN + Vector3.new(0, HIP, half)
	attacker.home = CFrame.lookAt(attackerAt, defenderAt)
	defender.home = CFrame.lookAt(defenderAt, attackerAt)
	attacker.model:PivotTo(attacker.home)
	defender.model:PivotTo(defender.home)

	-- Over the defender's right shoulder, looking at the attacker's chest.
	local forward = defender.home.LookVector
	local right = defender.home.RightVector
	local eye = defenderAt - forward * 8 + right * 2.5 + Vector3.new(0, 3, 0)
	cameraCFrame = CFrame.lookAt(eye, attackerAt + Vector3.new(0, 1, 0))
end

----------------------------------------------------------------------------
-- Timeline helpers. Every duration runs through `speed`, so slow motion
-- stretches the whole effect, particles included.
----------------------------------------------------------------------------

local function animate(duration: number, step: (number) -> ())
	local t = 0
	while t < duration do
		t += task.wait() * speed
		step(math.min(t / duration, 1))
	end
end

local function hold(duration: number)
	animate(duration, function() end)
end

local function easeOut(a: number): number
	return 1 - (1 - a) * (1 - a)
end

local function carrier(parent: Instance, position: Vector3, size: Vector3?): Part
	local part = Instance.new("Part")
	part.Name = "Carrier"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size or Vector3.new(0.2, 0.2, 0.2)
	part.Position = position
	part.Parent = parent
	return part
end

local function attach(parent: Instance, position: Vector3?): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Position = position or Vector3.zero
	attachment.Parent = parent
	return attachment
end

local function fadeOut(): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local function shrink(size: number): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
end

local function emitter(parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLES
	e.Rate = 0
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Color = ColorSequence.new(VINE_LIGHT, VINE_DARK)
	e.Transparency = fadeOut()
	e.TimeScale = speed
	e.Parent = parent
	return e
end

local function vineBeam(parent: Instance, a0: Attachment, a1: Attachment, width: number): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = width
	beam.Width1 = width
	beam.FaceCamera = true
	beam.Segments = 20
	beam.LightEmission = 0.6
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(VINE_DARK, VINE_LIGHT)
	beam.Parent = parent
	return beam
end

-- A short green flare at the attacker's hand, so every variant has the same
-- tell for "a cast starts now".
local function windup(effect: Instance)
	local flare = emitter(attacker.hand)
	flare.Lifetime = NumberRange.new(0.2, 0.3)
	flare.Speed = NumberRange.new(3, 5)
	flare.SpreadAngle = Vector2.new(180, 180)
	flare.Size = shrink(0.7)
	flare:Emit(20)
	-- Emitters on the figure outlive the effect folder, so tie them to it.
	effect.Destroying:Connect(function()
		flare:Destroy()
	end)
	hold(0.12)
end

----------------------------------------------------------------------------
-- The shared ending: whatever the variant, the defender gets yanked in.
----------------------------------------------------------------------------

type Context = {
	effect: Folder,
	hit: () -> (),
	pull: (duration: number, onStep: (() -> ())?) -> (),
}

local function pull(duration: number, onStep: (() -> ())?)
	local start = defender.model:GetPivot()
	local target = start + start.LookVector * PULL_DISTANCE
	animate(duration, function(a)
		defender.model:PivotTo(start:Lerp(target, easeOut(a)))
		if onStep then
			onStep()
		end
	end)
end

local function impactBurst(parent: Instance)
	local burst = emitter(parent)
	burst.Lifetime = NumberRange.new(0.25, 0.4)
	burst.Speed = NumberRange.new(10, 16)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Size = shrink(0.9)
	burst:Emit(40)
end

----------------------------------------------------------------------------
-- Variant A: Lash. One line, hand to chest, whipping as it travels.
----------------------------------------------------------------------------

local function lash(ctx: Context)
	windup(ctx.effect)

	local from = attacker.hand.WorldPosition
	local tip = carrier(ctx.effect, from)
	local tipAttachment = attach(tip)
	local beam = vineBeam(tip, attacker.hand, tipAttachment, 0.7)
	beam.Width1 = 0.3

	local trail = Instance.new("Trail")
	trail.Attachment0 = attach(tip, Vector3.new(0, 0.35, 0))
	trail.Attachment1 = attach(tip, Vector3.new(0, -0.35, 0))
	trail.Lifetime = 0.15
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Color = ColorSequence.new(VINE_LIGHT)
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = tip

	animate(0.35, function(a)
		local arc = Vector3.new(0, math.sin(a * math.pi) * 1.5, 0)
		tip.Position = from:Lerp(defender.chest.WorldPosition, easeOut(a)) + arc
		local whip = math.sin(a * math.pi * 3) * 3 * (1 - a)
		beam.CurveSize0 = whip
		beam.CurveSize1 = -whip
	end)

	ctx.hit()
	impactBurst(tip)
	ctx.pull(0.3, function()
		tip.Position = defender.chest.WorldPosition
	end)
	hold(0.35)
	animate(0.2, function(a)
		beam.Transparency = NumberSequence.new(a)
	end)
end

----------------------------------------------------------------------------
-- Variant B: Current. No line at all: the air around the defender streams
-- into the attacker's open hand.
----------------------------------------------------------------------------

local function current(ctx: Context)
	windup(ctx.effect)

	local toHand = (attacker.hand.WorldPosition - defender.chest.WorldPosition).Unit
	local field = carrier(ctx.effect, defender.chest.WorldPosition, Vector3.new(7, 7, 7))
	local streaks = emitter(field)
	streaks.Shape = Enum.ParticleEmitterShape.Sphere
	streaks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	streaks.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	streaks.Orientation = Enum.ParticleOrientation.VelocityParallel
	streaks.Speed = NumberRange.new(1, 2)
	streaks.Acceleration = toHand * 160
	streaks.Lifetime = NumberRange.new(0.35, 0.5)
	streaks.Brightness = 2
	streaks.Color = ColorSequence.new(VINE_DARK, VINE_LIGHT)
	streaks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.2, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})

	-- The mouth: particles converging into the hand, where the current ends.
	local mouthPart = carrier(ctx.effect, attacker.hand.WorldPosition, Vector3.new(5, 5, 5))
	local mouth = emitter(mouthPart)
	mouth.Shape = Enum.ParticleEmitterShape.Sphere
	mouth.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	mouth.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	mouth.Speed = NumberRange.new(8, 9)
	mouth.Lifetime = NumberRange.new(0.25, 0.3)
	mouth.Size = shrink(0.5)
	mouth.Rate = 120

	animate(0.55, function(a)
		streaks.Rate = 40 + 360 * a
	end)

	ctx.hit()
	impactBurst(field)
	ctx.pull(0.35, function()
		field.Position = defender.chest.WorldPosition
	end)
	streaks.Rate = 0
	mouth.Rate = 0
	hold(0.5)
end

----------------------------------------------------------------------------
-- Variant C: Coil. A spiral closes around the defender from the top down,
-- then a stem snaps to the attacker's hand.
----------------------------------------------------------------------------

local COIL_POINTS = 18
local COIL_TURNS = 2
local COIL_HEIGHT = 4.2

local function coil(ctx: Context)
	windup(ctx.effect)

	local function feet(): Vector3
		return defender.model:GetPivot().Position - Vector3.new(0, HIP, 0)
	end

	local center = carrier(ctx.effect, feet())
	local points: { Attachment } = {}
	local beams: { Beam } = {}
	for i = 1, COIL_POINTS do
		points[i] = attach(center)
	end
	for i = 1, COIL_POINTS - 1 do
		local beam = vineBeam(center, points[i], points[i + 1], 0.35)
		beam.Segments = 1
		beam.Color = ColorSequence.new(VINE_DARK:Lerp(VINE_LIGHT, i / COIL_POINTS))
		beam.Enabled = false
		beams[i] = beam
	end

	local function place(radius: number, spin: number, reveal: number)
		for i, point in points do
			local t = (i - 1) / (COIL_POINTS - 1)
			local angle = spin + t * COIL_TURNS * 2 * math.pi
			point.Position = Vector3.new(
				math.cos(angle) * radius,
				0.3 + t * COIL_HEIGHT,
				math.sin(angle) * radius
			)
		end
		-- Revealed from the top down, so it never reads as growing out of the
		-- ground the way a Root would.
		for i, beam in beams do
			beam.Enabled = 1 - i / (COIL_POINTS - 1) <= reveal
		end
	end

	animate(0.55, function(a)
		local eased = easeOut(a)
		place(6 + (1.5 - 6) * eased, (1 - eased) * 3 * math.pi, math.min(1, a * 1.6))
	end)

	ctx.hit()
	impactBurst(defender.chest)
	vineBeam(center, attacker.hand, points[COIL_POINTS], 0.45)
	ctx.pull(0.35, function()
		center.Position = feet()
	end)
	hold(0.35)
	animate(0.2, function(a)
		for _, beam in center:GetChildren() do
			if beam:IsA("Beam") then
				beam.Transparency = NumberSequence.new(a)
			end
		end
	end)
end

----------------------------------------------------------------------------
-- Playback: loop the chosen variant, show the clock.
----------------------------------------------------------------------------

type Variant = { key: string, name: string, play: (Context) -> () }

local VARIANTS: { Variant } = {
	{ key = "A", name = "Lash", play = lash },
	{ key = "B", name = "Current", play = current },
	{ key = "C", name = "Coil", play = coil },
}

local variantIndex = 1
local castStartedAt: number? = nil
local hitAfter: number? = nil
local finishedAfter: number? = nil
local effect: Folder? = nil
local loopThread: thread? = nil

local function cleanup()
	if effect then
		effect:Destroy()
		effect = nil
	end
	defender.model:PivotTo(defender.home)
end

local function playOnce()
	cleanup()
	local folder = Instance.new("Folder")
	folder.Name = "Effect"
	folder.Parent = scene
	effect = folder

	local startedAt = os.clock()
	castStartedAt, hitAfter, finishedAfter = startedAt, nil, nil
	VARIANTS[variantIndex].play({
		effect = folder,
		hit = function()
			hitAfter = os.clock() - startedAt
		end,
		pull = pull,
	})
	finishedAfter = os.clock() - startedAt
end

local function restart()
	if loopThread then
		task.cancel(loopThread)
	end
	cleanup()
	loopThread = task.spawn(function()
		while true do
			playOnce()
			task.wait(LOOP_PAUSE)
		end
	end)
end

----------------------------------------------------------------------------
-- HUD: the variant switcher at the bottom, the state in the top left.
----------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "VinePrototype"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -24)
bar.Size = UDim2.fromOffset(360, 44)
bar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
bar.BackgroundTransparency = 0.1
bar.Parent = gui
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 22)

local function barButton(text: string, x: number): TextButton
	local button = Instance.new("TextButton")
	button.Text = text
	button.Size = UDim2.fromOffset(44, 44)
	button.Position = UDim2.new(x, if x == 0 then 4 else -48, 0, 0)
	button.BackgroundTransparency = 1
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 22
	button.Parent = bar
	return button
end

local previous = barButton("<", 0)
local nextButton = barButton(">", 1)

local barLabel = Instance.new("TextLabel")
barLabel.Size = UDim2.new(1, -104, 1, 0)
barLabel.Position = UDim2.fromOffset(52, 0)
barLabel.BackgroundTransparency = 1
barLabel.TextColor3 = Color3.new(1, 1, 1)
barLabel.Font = Enum.Font.GothamBold
barLabel.TextSize = 18
barLabel.Parent = bar

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(16, 16)
status.Size = UDim2.fromOffset(360, 150)
status.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
status.BackgroundTransparency = 0.3
status.TextColor3 = Color3.new(1, 1, 1)
status.Font = Enum.Font.Code
status.TextSize = 15
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Parent = gui
Instance.new("UIPadding", status).PaddingLeft = UDim.new(0, 8)

local function seconds(value: number?): string
	return if value then string.format("%.2f s", value) else "-"
end

local function switch(step: number)
	variantIndex = (variantIndex - 1 + step) % #VARIANTS + 1
	local variant = VARIANTS[variantIndex]
	barLabel.Text = `{variant.key}  {variant.name}`
	restart()
end

previous.Activated:Connect(function()
	switch(-1)
end)
nextButton.Activated:Connect(function()
	switch(1)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.Left then
		switch(-1)
	elseif key == Enum.KeyCode.Right then
		switch(1)
	elseif key == Enum.KeyCode.Space then
		restart()
	elseif key == Enum.KeyCode.S then
		speed = if speed == 1 then SLOW_MOTION else 1
		restart()
	elseif key == Enum.KeyCode.D then
		distanceIndex = distanceIndex % #DISTANCES + 1
		cleanup()
		layout()
		restart()
	end
end)

RunService:BindToRenderStep("VinePrototypeCamera", Enum.RenderPriority.Camera.Value + 1, function()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = cameraCFrame

	local variant = VARIANTS[variantIndex]
	local clock = if finishedAfter
		then finishedAfter
		elseif castStartedAt then os.clock() - castStartedAt
		else nil
	status.Text = table.concat({
		`variant   {variant.key} {variant.name}`,
		`clock     {seconds(clock)}  (real time from cast)`,
		`hit at    {seconds(hitAfter)}`,
		`speed     {speed}x  [S]`,
		`distance  {DISTANCES[distanceIndex]} studs  [D]`,
		"",
		"Left/Right variant   Space replay",
	}, "\n")
end)

layout()
switch(0)
