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

local function getCharacter()
	return localPlayer.Character or localPlayer.CharacterAdded:Wait()
end

-- BACKGROUND INITIAL TELEPORT TO PREVENT UI CRASHING
task.spawn(function()
	local character = getCharacter()
	if character then
		pcall(function()
			local things = workspace:WaitForChild("__THINGS", 10)
			local instances = things and things:WaitForChild("Instances", 5)
			local backrooms = instances and instances:WaitForChild("Backrooms", 5)
			local teleports = backrooms and backrooms:WaitForChild("Teleports", 5)
			local enterPart = teleports and teleports:WaitForChild("Enter", 5)
			if enterPart then
				character:PivotTo(enterPart.CFrame)
			end
		 pcall(function()
	end)
end)

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

	local imageUrl = decoded.data.imageUrl
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

	pcall(function()
		httpRequest({
			Url = getgenv().webhook,
			Method = "POST",
			Headers = {	["Content-Type"] = "application/json" },
			Body = body
		})
	end)
end

-- FIXED DELTA VERIFY-TELEPORT BYPASS SERVER HOPPING FUNCTION
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

-- ==========================================
-- RECONSTRUCTED UI FEATURES AND BUTTONS SECTION
-- ==========================================

-- MAIN TAB FEATURES
local AutoHuntToggle = Tab:CreateToggle({
	Name = "Auto Hunt Gamemaster Room",
	CurrentValue = false,
	Flag = "AutoHuntGM",
	Callback = function(Value)
		_G.IsScanning = Value
		if Value then
			StatusLabel:SetText("Status: Scanning rooms...")
			task.spawn(function()
				while _G.IsScanning do
					task.wait(2)
					local instances = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Instances")
					local gmStage = instances and instances:FindFirstChild("GameMastersStage", true)
					
					if gmStage then
						StatusLabel:SetText("Status: Gamemaster Found!")
						Rayfield:Notify({Title = "Target Found!", Content = "Gamemaster room detected in this server!", Duration = 10})
						local char = getCharacter()
						if char and gmStage:FindFirstChild("Enter") then
							char:PivotTo(gmStage.Enter.CFrame)
						end
						_G.IsScanning = false
						break
					else
						StatusLabel:SetText("Status: Not found. Hopping server...")
						serverHop("Gamemaster Stage not found. Looking for a new server...")
						break
					end
				end
			end)
		else
			StatusLabel:SetText("Status: Idle")
		end
	end,
})

local FreeEggTPButton = Tab:CreateButton({
	Name = "Teleport to Free Egg Room",
	Callback = function()
		local instances = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Instances")
		local target = instances and (instances:FindFirstChild("DeepFreeEggRoom1", true) or instances:FindFirstChild("DeepFreeEggRoom2", true))
		if target and target:FindFirstChild("Enter") then
			getCharacter():PivotTo(target.Enter.CFrame)
		else
			Rayfield:Notify({Title = "Error", Content = "Free Egg Room not generated in this server.", Duration = 3})
		end
	end,
})

local LockedEggTPButton = Tab:CreateButton({
	Name = "Teleport to Locked Egg Room",
	Callback = function()
		local instances = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Instances")
		local target = instances and instances:FindFirstChild("DeepLockedEggRoom", true)
		if target and target:FindFirstChild("Enter") then
			getCharacter():PivotTo(target.Enter.CFrame)
		else
			Rayfield:Notify({Title = "Error", Content = "Locked Egg Room not found.", Duration = 3})
		end
	end,
})

-- BOSS CHEST TAB FEATURES
local BossTPButton = MiniBossTab:CreateButton({
	Name = "Teleport to Boss Chest Room",
	Callback = function()
		local instances = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Instances")
		local target = instances and (instances:FindFirstChild("DeepChestRoom1", true) or instances:FindFirstChild("DeepChestRoom2", true) or instances:FindFirstChild("DeepChestRoom3", true))
		if target and target:FindFirstChild("Enter") then
			getCharacter():PivotTo(target.Enter.CFrame)
		else
			Rayfield:Notify({Title = "Error", Content = "Boss Chest Room not found.", Duration = 3})
		end
	end,
})

local AutoFarmBoss = MiniBossTab:CreateToggle({
	Name = "Auto Farm Boss Chest",
	CurrentValue = false,
	Flag = "AutoBoss",
	Callback = function(Value)
