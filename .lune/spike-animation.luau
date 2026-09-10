--!strict
--[[
	The spike from issue #7: can the agent make an animation without Studio?

	Builds a `KeyframeSequence` in memory (the right arm swings up and back
	down), serializes it to `.rbxm`, uploads it through Open Cloud as an
	`Animation` asset, and writes the resulting ID into
	`src/shared/AnimationIds.luau`, which Rojo syncs to Studio.

		lune run spike-animation             # build, upload, write the ID module
		lune run spike-animation -- --dry-run  # build and verify only

	Only Ben can answer the actual question, by pressing Play and watching the
	arm — `src/client/AnimationSpike.client.luau` plays whatever ID this wrote.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local OpenCloud = require("./lib/openCloud")

local CFrame = roblox.CFrame
local Enum = roblox.Enum

local BUILD_PATH = "build/spike-arm-raise.rbxm"
local ID_MODULE_PATH = "src/shared/AnimationIds.luau"
local ID_KEY = "spikeArmRaise"

-- One swing: down, up, down. The last keyframe's time is the clip length.
local KEYFRAMES = {
	{ time = 0, raised = false },
	{ time = 0.6, raised = true },
	{ time = 1.2, raised = false },
}

-- A joint this clip touches, and where it goes in the raised keyframe. `raised`
-- is the only pose that differs; everywhere else the joint stays at rest.
type Joint = {
	name: string,
	raised: roblox.CFrame?,
	children: { Joint }?,
}

-- Swinging the shoulder around X lifts the arm forward on both rig types,
-- whichever way the joint happens to be oriented. This is a spike: the point
-- is motion Ben can see from any camera angle, not a pose that looks good.
local SHOULDER_SWING = CFrame.Angles(-math.rad(100), 0, 0)
local ELBOW_BEND = CFrame.Angles(-math.rad(35), 0, 0)

--[[
	The rig, as far as this clip touches it.

	Both rig types are in here on purpose. A `Pose` whose name matches no joint
	on the character is ignored, so one clip covers R15 and R6 and the spike
	does not hinge on which avatar type the place happens to be set to.
]]
local RIG: Joint = {
	name = "HumanoidRootPart",
	children = {
		{
			name = "LowerTorso", -- R15
			children = {
				{
					name = "UpperTorso",
					children = {
						{
							name = "RightUpperArm",
							raised = SHOULDER_SWING,
							children = {
								{ name = "RightLowerArm", raised = ELBOW_BEND },
							},
						},
					},
				},
			},
		},
		{
			name = "Torso", -- R6
			children = {
				{ name = "Right Arm", raised = SHOULDER_SWING },
			},
		},
	},
}

local function buildPose(joint: Joint, raised: boolean, parent: roblox.Instance): roblox.Instance
	local pose = roblox.Instance.new("Pose")
	pose.Name = joint.name
	pose.CFrame = if raised then joint.raised or CFrame.identity else CFrame.identity
	pose.Weight = 1
	pose.EasingStyle = Enum.PoseEasingStyle.Cubic
	pose.EasingDirection = Enum.PoseEasingDirection.Out
	pose.Parent = parent

	for _, child in joint.children or {} do
		buildPose(child, raised, pose)
	end
	return pose
end

local function buildKeyframeSequence(): roblox.Instance
	local sequence = roblox.Instance.new("KeyframeSequence")
	sequence.Name = "SpikeArmRaise"
	sequence.Loop = true
	-- Action outranks the idle animation the default character plays; on Core
	-- priority the idle would simply win and nothing would look different.
	sequence.Priority = Enum.AnimationPriority.Action

	for _, moment in KEYFRAMES do
		local keyframe = roblox.Instance.new("Keyframe")
		keyframe.Name = `Keyframe{moment.time}`
		keyframe.Time = moment.time
		keyframe.Parent = sequence
		buildPose(RIG, moment.raised, keyframe)
	end

	return sequence
end

--[[
	Reads the serialized bytes back before they are uploaded.

	Cheap insurance for the one thing this spike cannot see: if the tree that
	comes back out of the file is not the tree we built, the answer from Studio
	would be about our bug and not about Roblox' processing.
]]
-- Walks a pose path like { "HumanoidRootPart", "Torso", "Right Arm" }, and says
-- which step is missing instead of erroring halfway down the chain.
local function poseAt(keyframe: roblox.Instance, path: { string }): roblox.Instance
	local current = keyframe
	for _, name in path do
		local child = current:FindFirstChild(name)
		assert(child ~= nil, `no pose named {name} under {current.Name}`)
		current = child :: roblox.Instance
	end
	return current
end

local function verifyRoundTrip(bytes: string)
	local roots = roblox.deserializeModel(bytes)
	assert(#roots == 1, `expected 1 root instance, got {#roots}`)

	local sequence = roots[1]
	assert(
		sequence.ClassName == "KeyframeSequence",
		`expected a KeyframeSequence, got {sequence.ClassName}`
	)
	assert((sequence :: any).Loop == true, "the clip should loop")

	local keyframes = sequence:GetChildren()
	assert(#keyframes == 3, `expected 3 keyframes, got {#keyframes}`)

	local raisedFound = false
	for _, keyframe in keyframes do
		assert(keyframe.ClassName == "Keyframe", `expected a Keyframe, got {keyframe.ClassName}`)
		local r6Arm = poseAt(keyframe, { "HumanoidRootPart", "Torso", "Right Arm" })
		local r15Arm =
			poseAt(keyframe, { "HumanoidRootPart", "LowerTorso", "UpperTorso", "RightUpperArm" })
		if
			(r6Arm :: any).CFrame ~= CFrame.identity
			and (r15Arm :: any).CFrame ~= CFrame.identity
		then
			raisedFound = true
		end
	end
	assert(raisedFound, "no keyframe actually moves the arm")

	print(`  round-trip ok: {#keyframes} keyframes, {#bytes} bytes`)
end

-- The generated module: the two `%s` are the key and the asset ID.
local ID_MODULE_TEMPLATE = [[
--!strict
--[==[
	Asset IDs of the animations we uploaded, generated by
	`lune run spike-animation`. Do not edit by hand.

	Every upload mints a new ID — Open Cloud cannot replace the content of an
	existing Animation asset — so this file changes on every iteration.
]==]

return table.freeze({
	%s = "rbxassetid://%s",
})
]]

local function writeIdModule(assetId: string)
	fs.writeFile(ID_MODULE_PATH, string.format(ID_MODULE_TEMPLATE, ID_KEY, assetId))
	print(`  wrote {ID_MODULE_PATH}`)
end

local dryRun = table.find(process.args, "--dry-run") ~= nil

print("Building the KeyframeSequence …")
local bytes = roblox.serializeModel({ buildKeyframeSequence() })
verifyRoundTrip(bytes)

if not fs.isDir("build") then
	fs.writeDir("build")
end
fs.writeFile(BUILD_PATH, bytes)
print(`  wrote {BUILD_PATH}`)

if dryRun then
	print("\nDry run: nothing uploaded.")
	return
end

print("\nUploading to Open Cloud …")
local credentials = OpenCloud.credentials()
local assetId = OpenCloud.uploadAsset({
	assetType = "Animation",
	displayName = "SpikeArmRaise",
	description = "Spike (issue #7): KeyframeSequence built on Linux with Lune, never opened in Studio.",
	fileName = "spike-arm-raise.rbxm",
	contents = bytes,
	contentType = "model/x-rbxm",
}, credentials)

print(`  asset {assetId}`)
writeIdModule(assetId)

print("\nUploaded. Now Ben presses Play and says whether the arm moves.")
