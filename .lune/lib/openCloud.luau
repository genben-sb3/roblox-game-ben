--!strict
--[[
	Talking to Roblox Open Cloud from claudebox.

	Two things live here, and nothing else: reading the credentials the wizard
	(`scripts/setup-open-cloud.sh`) left in `.env`, and uploading one file as an
	asset. Callers hand over bytes and get back an asset ID — the multipart
	body, the long-running operation and its polling stay in this file.

	The Assets API answers an upload with an *operation*, not with the asset:
	moderation runs first. `uploadAsset` does not return until that operation is
	done, so a caller can write the ID straight into a generated module.
]]

local fs = require("@lune/fs")
local net = require("@lune/net")
local serde = require("@lune/serde")
local task = require("@lune/task")

local ENV_PATH = ".env"
local ASSETS_URL = "https://apis.roblox.com/assets/v1/assets"
local OPERATIONS_URL = "https://apis.roblox.com/assets/v1/operations"

-- Moderation on a small animation is quick, but it is a queue and not a
-- guarantee. Give it half a minute before calling it a failure.
local POLL_INTERVAL_SECONDS = 2
local POLL_ATTEMPTS = 15

export type Credentials = {
	apiKey: string,
	creatorId: string,
	creatorType: string,
}

export type UploadOptions = {
	assetType: string,
	displayName: string,
	description: string,
	fileName: string,
	contents: string,
	contentType: string,
}

local OpenCloud = {}

--[[
	The values `scripts/setup-open-cloud.sh` wrote into `.env`.

	Errors rather than returning nil: every caller needs all of them, and the
	fix is always the same one command.
]]
function OpenCloud.credentials(): Credentials
	local path = ENV_PATH
	if not fs.isFile(path) then
		error(`no {path} — run ./scripts/setup-open-cloud.sh first`)
	end

	local values: { [string]: string } = {}
	for line in string.gmatch(fs.readFile(path), "[^\r\n]+") do
		local key, value = string.match(line, "^%s*([%w_]+)%s*=%s*(.-)%s*$")
		if key ~= nil and value ~= nil then
			-- The wizard writes bare values, but a hand-edited `.env` may quote.
			values[key] = string.match(value, `^"(.*)"$`)
				or string.match(value, "^'(.*)'$")
				or value
		end
	end

	local function required(key: string): string
		local value = values[key]
		if value == nil or value == "" then
			error(`{path} has no {key} — re-run ./scripts/setup-open-cloud.sh`)
		end
		return value
	end

	return {
		apiKey = required("ROBLOX_API_KEY"),
		creatorId = required("ROBLOX_CREATOR_ID"),
		creatorType = values["ROBLOX_CREATOR_TYPE"] or "User",
	}
end

-- One `multipart/form-data` body, built by hand because Lune's net client has
-- no form encoder. Field order matches Roblox' own curl example.
local function multipartBody(boundary: string, requestJson: string, options: UploadOptions): string
	local parts = {
		`--{boundary}\r\n`,
		'Content-Disposition: form-data; name="request"\r\n',
		"Content-Type: application/json\r\n\r\n",
		requestJson,
		`\r\n--{boundary}\r\n`,
		`Content-Disposition: form-data; name="fileContent"; filename="{options.fileName}"\r\n`,
		`Content-Type: {options.contentType}\r\n\r\n`,
		options.contents,
		`\r\n--{boundary}--\r\n`,
	}
	return table.concat(parts)
end

local function creationContext(credentials: Credentials): { creator: { [string]: string } }
	local creator = if credentials.creatorType == "Group"
		then { groupId = credentials.creatorId }
		else { userId = credentials.creatorId }
	return { creator = creator }
end

--[[
	Polls one upload operation until Roblox has minted an asset ID.
]]
local function awaitAsset(operationId: string, credentials: Credentials): string
	for attempt = 1, POLL_ATTEMPTS do
		local response = net.request({
			url = `{OPERATIONS_URL}/{operationId}`,
			method = "GET",
			headers = { ["x-api-key"] = credentials.apiKey },
		})
		if not response.ok then
			error(
				`polling failed: HTTP {response.statusCode} {response.statusMessage}\n{response.body}`
			)
		end

		local operation = serde.decode("json", response.body) :: {
			done: boolean?,
			response: { assetId: string? }?,
			error: { message: string? }?,
		}

		if operation.error ~= nil then
			error(`Roblox rejected the upload: {operation.error.message or response.body}`)
		end
		if operation.done == true then
			local assetId = operation.response ~= nil and operation.response.assetId or nil
			if assetId == nil then
				error(`operation finished without an asset ID:\n{response.body}`)
			end
			return assetId
		end

		print(`  waiting for moderation ({attempt}/{POLL_ATTEMPTS}) …`)
		task.wait(POLL_INTERVAL_SECONDS)
	end

	error(`operation {operationId} still not done after {POLL_ATTEMPTS * POLL_INTERVAL_SECONDS}s`)
end

--[[
	Uploads `options.contents` as a new asset and returns its ID.

	Always a *new* asset: Open Cloud can only replace the content of `.fbx`
	assets, so every iteration on an animation costs a fresh ID.
]]
function OpenCloud.uploadAsset(options: UploadOptions, credentials: Credentials): string
	local requestJson = serde.encode("json", {
		assetType = options.assetType,
		displayName = options.displayName,
		description = options.description,
		creationContext = creationContext(credentials),
	})

	local boundary = `----lune{os.time()}{math.random(100000, 999999)}`
	local response = net.request({
		url = ASSETS_URL,
		method = "POST",
		headers = {
			["x-api-key"] = credentials.apiKey,
			["content-type"] = `multipart/form-data; boundary={boundary}`,
		},
		body = multipartBody(boundary, requestJson, options),
	})

	if not response.ok then
		error(`upload failed: HTTP {response.statusCode} {response.statusMessage}\n{response.body}`)
	end

	local operation = serde.decode("json", response.body) :: { path: string?, operationId: string? }
	-- The field is documented as `path` ("operations/{id}"); older responses
	-- carry a bare `operationId`. Accept either.
	local operationId = operation.operationId
		or string.match(operation.path or "", "operations/(.+)")
	if operationId == nil then
		error(`upload accepted but no operation to poll:\n{response.body}`)
	end

	return awaitAsset(operationId, credentials)
end

return OpenCloud
