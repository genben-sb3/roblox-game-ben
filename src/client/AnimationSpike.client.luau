--!strict
--[[
	Plays the animation the agent built without Studio (issue #7).

	`lune run spike-animation` builds a KeyframeSequence on Linux, uploads it
	through Open Cloud and writes its ID into `src/shared/AnimationIds.luau`.
	This script loads that ID onto the local character and loops it.

	Everything it prints is there to keep Ben's answer unambiguous: if the arm
	does not move, the Output window should say whether the asset arrived, what
	rig and joint type the character has, and whether the track has any length.
	A clip that never loaded, a joint type we posed wrong and an `.rbxm` Roblox
	refused to process all look identical from the outside otherwise.

	Delete this once the answer is recorded in an ADR.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationIds = require(ReplicatedStorage.Shared.AnimationIds)

local TAG = "[AnimationSpike]"
local WAIT_SECONDS = 10

-- The joint driving the pose we animate, per rig type. Since the Avatar Joint
-- Upgrade an R15 character may carry `AnimationConstraint`s instead of
-- `Motor6D`s, and which one it is decides where to look next if nothing moves.
local ANIMATED_LIMB = {
	[Enum.HumanoidRigType.R15] = "RightUpperArm",
	[Enum.HumanoidRigType.R6] = "Right Arm",
}

local function reportJoint(character: Model, humanoid: Humanoid)
	local limbName = ANIMATED_LIMB[humanoid.RigType]
	local limb = character:FindFirstChild(limbName)
	if limb == nil then
		warn(`{TAG} no {limbName} on this character`)
		return
	end

	local joint = limb:FindFirstChildWhichIsA("Motor6D")
		or limb:FindFirstChildWhichIsA("AnimationConstraint")
	print(`{TAG} {limbName} joint: {if joint ~= nil then joint.ClassName else "none found"}`)
end

local function play(character: Model)
	local humanoid = character:WaitForChild("Humanoid", WAIT_SECONDS) :: Humanoid?
	if humanoid == nil then
		warn(`{TAG} no Humanoid after {WAIT_SECONDS}s`)
		return
	end

	print(`{TAG} rig type: {humanoid.RigType.Name}`)
	reportJoint(character, humanoid)

	-- The Animator normally replicates in with the character. Creating one is
	-- the documented fallback, and better than waiting here forever.
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		animator = humanoid:WaitForChild("Animator", WAIT_SECONDS) :: Animator?
	end
	if animator == nil then
		warn(`{TAG} no Animator after {WAIT_SECONDS}s — creating one`)
		animator = Instance.new("Animator");
		(animator :: Animator).Parent = humanoid
	end

	local animation = Instance.new("Animation")
	animation.Name = "SpikeArmRaise"
	animation.AnimationId = AnimationIds.spikeArmRaise
	print(`{TAG} animation id: {animation.AnimationId}`)

	-- A hint, not a verdict: PreloadAsync is unreliable for animations and
	-- reports Failure for assets that play. Only the track length below says
	-- whether the clip really arrived.
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync({ animation }, function(_contentId, status)
			print(`{TAG} preload says {status.Name} (unreliable for animations, ignore on its own)`)
		end)
	end)
	if not ok then
		warn(`{TAG} preload failed: {err}`)
	end

	local loaded, trackOrError = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if not loaded then
		warn(`{TAG} LoadAnimation failed: {trackOrError}`)
		return
	end

	local track = trackOrError :: AnimationTrack
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Action
	track:Play()

	-- Length stays 0 until the clip data is in, so a track that loaded but has
	-- no length is the failure this spike is looking for: Roblox took the file
	-- and made an asset out of it, but there is no usable clip inside.
	task.wait(1)
	print(`{TAG} track length {string.format("%.2f", track.Length)}s, playing {track.IsPlaying}`)
	if track.Length == 0 then
		warn(`{TAG} the track has no length — the asset carries no usable clip.`)
	else
		print(`{TAG} the clip is in. If the right arm swings, the spike says yes.`)
	end
end

local player = Players.LocalPlayer
if player.Character ~= nil then
	task.spawn(play, player.Character :: Model)
end
player.CharacterAdded:Connect(play)
