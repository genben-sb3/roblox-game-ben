--!strict
local AnimationIds = require("./AnimationIds")

return {
	["every animation id points at an uploaded asset"] = function()
		local count = 0
		for name, id in AnimationIds :: { [string]: string } do
			count += 1
			assert(
				string.match(id, "^rbxassetid://%d+$") ~= nil,
				`{name} is not an uploaded asset id: {id}`
			)
		end
		assert(count > 0, "the generated module is empty — did the upload run?")
	end,
}
