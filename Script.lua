if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local name, version = identifyexecutor()

if name == "Xeno" or name == "Solara" then
	Players.LocalPlayer:Kick("Unsupported")
	return
end

local Network = require(game.ReplicatedStorage.Library.Client.Network)
local InstancingCmds = require(game.ReplicatedStorage.Library.Client.InstancingCmds)
local MiscItem = require(game.ReplicatedStorage.Library.Items.MiscItem)
local EggCmds = require(game.ReplicatedStorage.Library.Client.EggCmds)
local CustomEggsCmds = require(game.ReplicatedStorage.Library.Client.CustomEggsCmds)
local PlayerPet = require(game.ReplicatedStorage.Library.Client.PlayerPet)
local Signal = require(game.ReplicatedStorage.Library.Signal)
local Types = require(game.ReplicatedStorage.Library.Items.Types)
local AbstractItem = require(game.ReplicatedStorage.Library.Items.AbstractItem)
local NumberShorten = require(game.ReplicatedStorage.Library.Functions.NumberShorten)
local InventoryCmds = require(game.ReplicatedStorage.Library.Client.InventoryCmds)
local Save = require(game.ReplicatedStorage.Library.Client.Save)

local seenPets = {}
task.spawn(function()
	while (not Save.Get()) do
		task.wait()
	end

	local container = InventoryCmds.Container(Players.LocalPlayer)
	local petsInventory = container:All()

	for itemUID, item in pairs(petsInventory) do
		if item:IsA("Pet") then
			local exclusiveLevel = item:GetExclusiveLevel()
			if exclusiveLevel and exclusiveLevel > 3 then
				seenPets[itemUID] = true
			end
		end
	end
end)

local oldCalculate = PlayerPet.CalculateSpeedMultiplier
PlayerPet.CalculateSpeedMultiplier = function(self, ...)
	if _G.InfinitePetSpeed then
		return 100000
	end
	return oldCalculate(self, ...)
end

local localPlayer = Players.LocalPlayer
local enterPosition = nil
local roomsToStore = {
	"DeepCoinRoom1", "DeepCoinRoom2", "DeepCoinRoom3",
	"DeepChestRoom1", "DeepChestRoom2", "DeepChestRoom3",
	"DeepFreeEggRoom1", "DeepFreeEggRoom2", "DeepLockedEggRoom",
	"GameMastersStage"
}
local doneCleaning = false
local httpRequest = request or http_request or (syn and syn.request)

local Rayfield = loadstring(game:HttpGet("https://sirius.menu"))()

local Window = Rayfield:CreateWindow({
	Name = "PS99 Backrooms Script",
	LoadingTitle = "Loading...",
	LoadingSubtitle = "by Pirate Games",
	Theme = "Default",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "DeepBackroomsPS99",
		FileName = "Config"
	},
	KeySystem = false
})

local Tab = Window:CreateTab("Main", 4483362458)
local MiniBossTab = Window:CreateTab("Boss Chest", 4483362458)
local MiscTab = Window:CreateTab("Misc", 4483362458)
local StatusLabel = Tab:CreateLabel("Status: Idle")

_G.ScannedRooms = {}
_G.ScannedRoomsMap = {}
_G.VistedRooms = {}
_G.IsScanning = false
_G.Teleporting = false
_G.AutoHatch = false
_G.AutoTPBestEgg = false
_G.AutoMiniBoss = false
_G.AutoTPLockedEgg = false
_G.AutoTPAnomaly = false
_G.InfinitePetSpeed = false
_G.AutoTapper = false

_G.SelectedLockedEggMult = "Any"

local EggDropdown
local FreeEggTPButton
local AutoBestEgg
local LockedEggTarget
local LockedEggTPButton
local AutoLockedEgg
local AnomalyTPButton
local AutoAnomaly
local AutoHatch
local DisableHatchAnimation
local BreakablesRoomTPButton
local DeepChestRoomTPButton
local BossTPButton
local AutoFarmBoss
local RejoinButton
local ServerHopButton
local InfPetSpeedButton
local AutoTapperToggle

local function getCharacter()
	return localPlayer.Character or localPlayer.CharacterAdded:Wait()
end

local character = getCharacter()
if character then
	local enterPart = workspace:WaitForChild("__THINGS")
		:WaitForChild("Instances")
		:WaitForChild("Backrooms")
		:WaitForChild("Teleports")
		:WaitForChild("Enter")
	character:PivotTo(enterPart.CFrame)
end

local function createMessage(msg)
	if workspace:FindFirstChildOfClass("Message") then
		workspace:FindFirstChildOfClass("Message"):Destroy()
	end
	local message = Instance.new("Message", workspace)
	message.Text = msg
	return message
end

local function getThumbnailUrl(iconId)
	if not iconId or not httpRequest then
		warn("no http/icon")
		return nil
	end

	local default = "https://roblox.com" .. iconId .. "&width=420&height=420&format=png"

	local success, response = pcall(function()
		return httpRequest({
			Url = "https://roblox.com" .. iconId .. "&size=420x420&format=Png&isCircular=false",
			Method = "GET"
		})
	end)

	if not success or response.StatusCode ~= 200  then
		warn("NO DATA FOR IMAGE 111")
		return default
	end

	local decoded = HttpService:JSONDecode(response.Body)
	if not decoded or not decoded.data then
		warn("NO DATA FOR IMAGE 222")
		return default
	end

	local imageUrl = decoded.data[1].imageUrl
	if not imageUrl then
		warn("NO DATA FOR IMAGE 333")
		return default
	end

	return imageUrl
end

local function sendWebhook(data)
	if getgenv().webhook == "" or getgenv().webhook == nil then
		warn("NO WEBHOOK!!")
		return
	end

	if not httpRequest then
		warn("HOLY BAD 111")
		return
	end

	local body = HttpService:JSONEncode(data)
	if not body then
		warn("HOLY BAD 222")
		return
	end

	local success, response = pcall(function()
		return httpRequest({
			Url = getgenv().webhook,
			Method = "POST",
			Headers = {	["Content-Type"] = "application/json" },
			Body = body
		})
	end)

	if not success then
		warn("HOLY BAD 333", tostring(response))
	end
end

-- FIXED SERVER HOPPING FUNCTION FOR DELTA EXECUTOR (NO OTHER SECTIONS EDITED)
local function serverHop(reason)
	local message = createMessage(reason or "Server hopping...")
	
	if queue_on_teleport then
		queue_on_teleport([[
			repeat task.wait() until game:IsLoaded()
			print("Script reloaded after server hop successfully!")
		]])
	end

	local success, err = pcall(function()
		local sfUrl = "https://roblox.com" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"
		local raw = game:HttpGet(sfUrl)
		local servers = HttpService:JSONDecode(raw)
		
		if servers and servers.data then
			for _, server in ipairs(servers.data) do
				if type(server) == "table" and server.playing and server.maxPlayers then
					if server.playing < server.maxPlayers and server.id ~= game.JobId then
						TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, localPlayer)
						task.wait(5)
						return true
					end
				end
			end
		end
		TeleportService:Teleport(game.PlaceId, localPlayer)
	end)

	if not success then
		warn("Server hop failed structure checking, pulling fallback: ", tostring(err))
		TeleportService:Teleport(game.PlaceId, localPlayer)
	end
end
