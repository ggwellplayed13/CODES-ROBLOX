--[[
    +------------------------------------------------------------------------------+
    |                     CURRENCY SYSTEM V9 - WITH ENDGAME TRIGGER                 |
    |           Items ordered by purchase, persist on death, no boost stacking      |
    |           FIXED: Race conditions, chest rewards, data persistence             |
    |           CURRENCY: Valor Coin (VC) - Asset 123140394605437                    |
    |           NEW: Triggers endgame cinematic at 10,000 VC                        |
    +------------------------------------------------------------------------------+
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- ===============================================================================
-- ENDGAME MODULE (Lazy load to avoid circular dependency)
-- ===============================================================================

local EndgameCinematicModule = nil
local endgameTriggered = {} -- [userId] = true to prevent double triggers

local function GetEndgameModule()
	if EndgameCinematicModule then return EndgameCinematicModule end
	local success, result = pcall(function()
		return require(ServerScriptService:WaitForChild("EndgameCinematicModule", 5))
	end)
	if success and result then
		EndgameCinematicModule = result
	end
	return EndgameCinematicModule
end

local function CheckEndgameTrigger(player)
	if not player or not player.Parent then return end
	local userId = player.UserId
	if endgameTriggered[userId] then return end

	local endgameModule = GetEndgameModule()
	if not endgameModule then return end

	if endgameModule.HasCompletedEndgame(player) then
		endgameTriggered[userId] = true
		return
	end

	local data = playerData and playerData[userId]
	if not data then return end

	if (data.vc or 0) >= 10000 then
		endgameTriggered[userId] = true
		print("?? [CurrencySystem] Player " .. player.Name .. " reached 10,000 VC! Triggering endgame!")
		task.spawn(function()
			endgameModule.Play(player)
		end)
	end
end

-- ===============================================================================
-- DATASTORE INITIALIZATION
-- ===============================================================================

local PlayerDataStore = nil
local DATA_STORE_RETRIES = 3
local DATA_STORE_RETRY_DELAY = 1

local function InitDataStore()
	local success, result = pcall(function()
		return DataStoreService:GetDataStore("InfiniteStreetData_V4")
	end)

	if success then
		PlayerDataStore = result
		print("? [CurrencySystem] DataStore initialized successfully")
	else
		warn("? [CurrencySystem] Failed to initialize DataStore: " .. tostring(result))
	end
end

InitDataStore()

-- ===============================================================================
-- REMOTE EVENTS SETUP
-- ===============================================================================

local CurrencyRemotes = ReplicatedStorage:FindFirstChild("CurrencyRemotes")
if not CurrencyRemotes then
	CurrencyRemotes = Instance.new("Folder")
	CurrencyRemotes.Name = "CurrencyRemotes"
	CurrencyRemotes.Parent = ReplicatedStorage
end

local function GetOrCreateRemote(name)
	local remote = CurrencyRemotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = CurrencyRemotes
	end
	return remote
end

local UpdateCurrencyEvent = GetOrCreateRemote("UpdateCurrency")
local SyncDataEvent = GetOrCreateRemote("SyncData")
local DoorOpenedEvent = GetOrCreateRemote("DoorOpened")
local SurvivedDoorEvent = GetOrCreateRemote("SurvivedDoor")
local PlayerDiedEvent = GetOrCreateRemote("PlayerDied")
local PurchaseItemEvent = GetOrCreateRemote("PurchaseItem")
local UseItemEvent = GetOrCreateRemote("UseItem")
local BoostUpdateEvent = GetOrCreateRemote("BoostUpdate")
local ChestRewardEvent = GetOrCreateRemote("ChestReward")
local RobuxBoostSyncEvent = GetOrCreateRemote("RobuxBoostSync")

-- -------------------------------------------------------------------------------
-- CONFIGURATION
-- -------------------------------------------------------------------------------
local LOSE_ITEMS_ON_DEATH = true
local LOSE_ITEMS_ON_LEAVE = false
local DEATH_PENALTY_PERCENT = 1.00
local MAX_STACK = 10
local MAX_SLOTS = 6
local BASE_MAX_HEALTH = 100  -- Default humanoid MaxHealth

local ITEMS = {
	{id = "bandage", name = "Bandage", price = 15, type = "heal", value = 20, icon = "??"},
	{id = "medkit", name = "Med Kit", price = 35, type = "heal", value = 50, icon = "??"},
	{id = "adrenaline", name = "Adrenaline", price = 75, type = "heal", value = 100, icon = "??"},
	{id = "energy_drink", name = "Energy Drink", price = 25, type = "stamina_boost", duration = 30, icon = "??"},
	{id = "super_energy", name = "Super Energy", price = 50, type = "stamina_boost", duration = 60, icon = "?"},
	{id = "ultra_boost", name = "Ultra Boost", price = 100, type = "stamina_boost", duration = 120, icon = "??"},
	{id = "speed_pill", name = "Speed Pill", price = 30, type = "speed_boost", value = 1.5, duration = 20, icon = "??"},
	{id = "turbo_boots", name = "Turbo Boots", price = 60, type = "speed_boost", value = 2.0, duration = 15, icon = "??"},
}

local function GetItemById(itemId)
	for _, item in ipairs(ITEMS) do
		if item.id == itemId then
			return item
		end
	end
	return nil
end

-- -------------------------------------------------------------------------------
-- PLAYER DATA STORAGE
-- -------------------------------------------------------------------------------

playerData = {}  -- NOTE: Made non-local so CheckEndgameTrigger can access it
local playerBoosts = {}
local dataLoaded = {}
local saveLock = {}

local function GetDefaultData()
	return {
		vc = 0,
		inventory = {},
		totalEarned = 0,
		deaths = 0,
		version = 4,
		hasSpeedBoostForever = false,
		hasDoubleHealthForever = false,
		hasSpeedBoost1Life = false,
		hasDoubleHealth1Life = false,
	}
end

-- -------------------------------------------------------------------------------
-- DATA MIGRATION
-- -------------------------------------------------------------------------------

local function MigrateData(data)
	if not data then return GetDefaultData() end

	if data.version and data.version >= 4 then
		-- Ensure new Robux boost fields exist for older V4 saves
		if data.hasSpeedBoostForever == nil then data.hasSpeedBoostForever = false end
		if data.hasDoubleHealthForever == nil then data.hasDoubleHealthForever = false end
		if data.hasSpeedBoost1Life == nil then data.hasSpeedBoost1Life = false end
		if data.hasDoubleHealth1Life == nil then data.hasDoubleHealth1Life = false end
		return data
	end

	local newData = {
		vc = data.vc or data.usd or 0,
		inventory = {},
		totalEarned = data.totalEarned or 0,
		deaths = data.deaths or 0,
		version = 4,
		hasSpeedBoostForever = false,
		hasDoubleHealthForever = false,
		hasSpeedBoost1Life = false,
		hasDoubleHealth1Life = false,
	}

	if data.inventory and type(data.inventory) == "table" then
		local isOldFormat = false
		for key, value in pairs(data.inventory) do
			if type(key) == "string" and type(value) == "number" then
				isOldFormat = true
				break
			end
		end

		if isOldFormat then
			for itemId, quantity in pairs(data.inventory) do
				if quantity > 0 then
					table.insert(newData.inventory, {
						itemId = itemId,
						quantity = quantity
					})
				end
			end
			print("[CurrencySystem] ?? Migrated inventory from old format")
		else
			for _, slot in ipairs(data.inventory) do
				if slot.itemId and slot.quantity and slot.quantity > 0 then
					table.insert(newData.inventory, {
						itemId = slot.itemId,
						quantity = slot.quantity
					})
				end
			end
		end
	end

	print("[CurrencySystem] ?? Migrated data from V" .. (data.version or "?") .. " to V4 (USD -> VC)")
	return newData
end

-- -------------------------------------------------------------------------------
-- BOOST MANAGEMENT
-- -------------------------------------------------------------------------------

local function GetPlayerBoosts(player)
	if not playerBoosts[player.UserId] then
		playerBoosts[player.UserId] = {
			staminaBoostEndTime = 0,
			speedBoostEndTime = 0,
			speedMultiplier = 1,
			robuxSpeedMultiplier = 1,
		}
	end
	return playerBoosts[player.UserId]
end

local function IsStaminaBoostActive(player)
	local boosts = GetPlayerBoosts(player)
	return tick() < boosts.staminaBoostEndTime
end

local function IsSpeedBoostActive(player)
	local boosts = GetPlayerBoosts(player)
	return tick() < boosts.speedBoostEndTime
end

local function GetStaminaBoostRemaining(player)
	local boosts = GetPlayerBoosts(player)
	local remaining = boosts.staminaBoostEndTime - tick()
	return remaining > 0 and remaining or 0
end

local function GetSpeedBoostRemaining(player)
	local boosts = GetPlayerBoosts(player)
	local remaining = boosts.speedBoostEndTime - tick()
	return remaining > 0 and remaining or 0
end

local function SyncBoostsToClient(player)
	if not player or not player.Parent then return end
	local boosts = GetPlayerBoosts(player)
	BoostUpdateEvent:FireClient(player, {
		staminaRemaining = GetStaminaBoostRemaining(player),
		speedRemaining = GetSpeedBoostRemaining(player),
		speedMultiplier = boosts.speedMultiplier,
	})
end

-- -------------------------------------------------------------------------------
-- DATASTORE FUNCTIONS
-- -------------------------------------------------------------------------------

local function LoadPlayerData(player)
	if not player or not player.Parent then return GetDefaultData() end

	local key = "Player_" .. player.UserId

	if dataLoaded[player.UserId] and playerData[player.UserId] then
		return playerData[player.UserId]
	end

	if not PlayerDataStore then
		warn("[CurrencySystem] ?? DataStore not available, using default data for " .. player.Name)
		playerData[player.UserId] = GetDefaultData()
		dataLoaded[player.UserId] = true
		return playerData[player.UserId]
	end

	local data = nil
	for attempt = 1, DATA_STORE_RETRIES do
		local success, result = pcall(function()
			return PlayerDataStore:GetAsync(key)
		end)

		if success then
			data = result
			break
		else
			warn("[CurrencySystem] Load attempt " .. attempt .. " failed for " .. player.Name .. ": " .. tostring(result))
			if attempt < DATA_STORE_RETRIES then
				task.wait(DATA_STORE_RETRY_DELAY)
			end
		end
	end

	if data then
		data = MigrateData(data)
		playerData[player.UserId] = data
		print("? [CurrencySystem] Loaded data for " .. player.Name .. ": " .. data.vc .. " VC, " .. #data.inventory .. " item slots")
	else
		playerData[player.UserId] = GetDefaultData()
		print("?? [CurrencySystem] Created new data for " .. player.Name)
	end

	dataLoaded[player.UserId] = true
	return playerData[player.UserId]
end

local function SavePlayerData(player, forceSync)
	if not player then return false end

	local userId = player.UserId
	local data = playerData[userId]
	if not data then return false end

	if saveLock[userId] then
		return false
	end
	saveLock[userId] = true

	if not PlayerDataStore then
		warn("[CurrencySystem] ?? DataStore not available, cannot save for " .. (player.Name or tostring(userId)))
		saveLock[userId] = nil
		return false
	end

	local key = "Player_" .. userId
	local success = false

	for attempt = 1, DATA_STORE_RETRIES do
		local saveSuccess, err = pcall(function()
			PlayerDataStore:SetAsync(key, data)
		end)

		if saveSuccess then
			print("?? [CurrencySystem] Saved data for " .. (player.Name or tostring(userId)) .. ": " .. data.vc .. " VC")
			success = true
			break
		else
			warn("[CurrencySystem] Save attempt " .. attempt .. " failed: " .. tostring(err))
			if attempt < DATA_STORE_RETRIES then
				task.wait(DATA_STORE_RETRY_DELAY)
			end
		end
	end

	saveLock[userId] = nil
	return success
end

-- -------------------------------------------------------------------------------
-- SYNC FUNCTIONS
-- -------------------------------------------------------------------------------

local function SyncPlayer(player)
	if not player or not player.Parent then return end
	local data = playerData[player.UserId]
	if data then
		SyncDataEvent:FireClient(player, data)
	end
end

local function SyncPlayerWithStatus(player, status, extra)
	if not player or not player.Parent then return end
	local data = playerData[player.UserId]
	SyncDataEvent:FireClient(player, data, status, extra)
end

-- -------------------------------------------------------------------------------
-- CURRENCY FUNCTIONS
-- -------------------------------------------------------------------------------

local function AddMoney(player, amount, reason)
	if not player or not player.Parent then
		warn("[CurrencySystem] AddMoney failed: player is nil or not in game")
		return false
	end

	local data = playerData[player.UserId]
	if not data then
		warn("[CurrencySystem] AddMoney failed: no data for player " .. player.Name)
		data = LoadPlayerData(player)
		if not data then
			return false
		end
	end

	local oldAmount = data.vc
	data.vc = data.vc + amount
	data.totalEarned = data.totalEarned + amount

	print("?? [CurrencySystem] Added " .. amount .. " VC to " .. player.Name .. " - Reason: " .. (reason or "Unknown") .. " - Old: " .. oldAmount .. " -> New: " .. data.vc)

	UpdateCurrencyEvent:FireClient(player, data.vc, amount, reason or "Reward")
	SyncPlayer(player)

	task.spawn(function()
		SavePlayerData(player)
	end)

	-- CHECK ENDGAME TRIGGER
	task.spawn(function()
		CheckEndgameTrigger(player)
	end)

	return true
end

local function RemoveMoney(player, amount, reason)
	if not player or not player.Parent then return false end
	local data = playerData[player.UserId]
	if not data then return false end

	if data.vc >= amount then
		data.vc = data.vc - amount
		UpdateCurrencyEvent:FireClient(player, data.vc, -amount, reason or "Purchase")
		SyncPlayer(player)
		return true
	end
	return false
end

-- -------------------------------------------------------------------------------
-- INVENTORY FUNCTIONS
-- -------------------------------------------------------------------------------

local function FindItemSlot(inventory, itemId)
	for i, slot in ipairs(inventory) do
		if slot.itemId == itemId then
			return i
		end
	end
	return nil
end

local function AddItemToInventory(player, itemId)
	local data = playerData[player.UserId]
	if not data then
		data = LoadPlayerData(player)
		if not data then
			return false, "NO_DATA"
		end
	end

	local item = GetItemById(itemId)
	if not item then return false, "INVALID_ITEM" end

	local existingSlot = FindItemSlot(data.inventory, itemId)

	if existingSlot then
		if data.inventory[existingSlot].quantity >= MAX_STACK then
			return false, "FULL_STACK"
		end
		data.inventory[existingSlot].quantity = data.inventory[existingSlot].quantity + 1
		return true, existingSlot
	else
		if #data.inventory >= MAX_SLOTS then
			return false, "INVENTORY_FULL"
		end

		table.insert(data.inventory, {
			itemId = itemId,
			quantity = 1
		})
		return true, #data.inventory
	end
end

local function RemoveItemFromInventory(player, itemId)
	local data = playerData[player.UserId]
	if not data then return false end

	local slotIndex = FindItemSlot(data.inventory, itemId)
	if not slotIndex then return false end

	data.inventory[slotIndex].quantity = data.inventory[slotIndex].quantity - 1

	if data.inventory[slotIndex].quantity <= 0 then
		table.remove(data.inventory, slotIndex)
	end

	return true
end

-- -------------------------------------------------------------------------------
-- CHEST ITEM HANDLING
-- -------------------------------------------------------------------------------

local function AddChestItemToInventory(player, itemId)
	if not player then
		warn("[CurrencySystem] AddChestItem failed: player is nil")
		return false
	end

	if not player.Parent then
		warn("[CurrencySystem] AddChestItem failed: player not in game")
		return false
	end

	if not dataLoaded[player.UserId] then
		print("[CurrencySystem] Data not loaded for " .. player.Name .. ", loading now...")
		LoadPlayerData(player)
		task.wait(0.1)
	end

	local data = playerData[player.UserId]
	if not data then
		warn("[CurrencySystem] AddChestItem failed: no data for " .. player.Name .. ", creating default")
		data = GetDefaultData()
		playerData[player.UserId] = data
		dataLoaded[player.UserId] = true
	end

	local item = GetItemById(itemId)
	if not item then
		warn("[CurrencySystem] AddChestItem failed: invalid item ID: " .. tostring(itemId))
		return false
	end

	local success, status = AddItemToInventory(player, itemId)

	if success then
		print("?? [CurrencySystem] Chest item added to " .. player.Name .. ": " .. item.name)
		SyncPlayerWithStatus(player, "CHEST_ITEM_ADDED", itemId)

		task.spawn(function()
			SavePlayerData(player)
		end)

		return true
	else
		local moneyValue = math.floor(item.price * 0.8)
		data.vc = data.vc + moneyValue
		data.totalEarned = data.totalEarned + moneyValue

		print("?? [CurrencySystem] Inventory full for " .. player.Name .. ", gave " .. moneyValue .. " VC instead of " .. item.name)

		UpdateCurrencyEvent:FireClient(player, data.vc, moneyValue, "Chest (inv full): " .. item.name)
		SyncPlayer(player)

		task.spawn(function()
			SavePlayerData(player)
		end)

		-- CHECK ENDGAME TRIGGER
		task.spawn(function()
			CheckEndgameTrigger(player)
		end)

		return false
	end
end

-- -------------------------------------------------------------------------------
-- APPLY ITEM EFFECTS
-- -------------------------------------------------------------------------------

local function ApplyItemEffect(player, item)
	if not player or not player.Parent then return false, "NO_PLAYER" end
	if not item then return false, "NO_ITEM" end

	local character = player.Character
	if not character then return false, "NO_CHARACTER" end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false, "DEAD" end

	local boosts = GetPlayerBoosts(player)

	if item.type == "heal" then
		local healAmount = humanoid.MaxHealth * (item.value / 100)
		local oldHealth = humanoid.Health
		humanoid.Health = math.min(humanoid.Health + healAmount, humanoid.MaxHealth)
		local actualHeal = humanoid.Health - oldHealth

		print("?? [CurrencySystem] " .. player.Name .. " healed for " .. math.floor(actualHeal) .. " HP using " .. item.name)
		return true, "HEALED"

	elseif item.type == "stamina_boost" then
		if IsStaminaBoostActive(player) then
			local remaining = math.ceil(GetStaminaBoostRemaining(player))
			return false, "BOOST_ACTIVE", remaining
		end

		boosts.staminaBoostEndTime = tick() + item.duration
		print("? [CurrencySystem] " .. player.Name .. " activated stamina boost for " .. item.duration .. "s")
		SyncBoostsToClient(player)

		task.delay(item.duration, function()
			if player and player.Parent then
				SyncBoostsToClient(player)
			end
		end)

		return true, "STAMINA_BOOST"

	elseif item.type == "speed_boost" then
		if IsSpeedBoostActive(player) then
			local remaining = math.ceil(GetSpeedBoostRemaining(player))
			return false, "BOOST_ACTIVE", remaining
		end

		local walkSpeed = 20
		local runSpeed = 36

		local boostedWalkSpeed = walkSpeed * item.value * boosts.robuxSpeedMultiplier
		local boostedRunSpeed = runSpeed * item.value * boosts.robuxSpeedMultiplier

		humanoid.WalkSpeed = boostedRunSpeed
		boosts.speedBoostEndTime = tick() + item.duration
		boosts.speedMultiplier = item.value

		print("?? [CurrencySystem] " .. player.Name .. " activated speed boost (" .. item.value .. "x) for " .. item.duration .. "s - Speed: " .. boostedRunSpeed)
		SyncBoostsToClient(player)

		task.spawn(function()
			while tick() < boosts.speedBoostEndTime do
				if player and player.Parent then
					local char = player.Character
					if char then
						local hum = char:FindFirstChild("Humanoid")
						if hum and hum.Health > 0 then
							local moveDir = hum.MoveDirection.Magnitude
							if moveDir > 0.1 then
								hum.WalkSpeed = boostedRunSpeed
							else
								hum.WalkSpeed = boostedWalkSpeed
							end
						end
					end
				else
					break
				end
				task.wait(0.1)
			end

			if player and player.Parent then
				local char = player.Character
				if char then
					local hum = char:FindFirstChild("Humanoid")
					if hum then
						hum.WalkSpeed = walkSpeed * boosts.robuxSpeedMultiplier
						boosts.speedMultiplier = 1
						SyncBoostsToClient(player)
					end
				end
			end
		end)

		return true, "SPEED_BOOST"
	end
	return false, "UNKNOWN_TYPE"
end

-- -------------------------------------------------------------------------------
-- ROBUX BOOST FUNCTIONS
-- -------------------------------------------------------------------------------

local function ApplyRobuxBoosts(player)
	if not player or not player.Parent then return end
	local data = playerData[player.UserId]
	if not data then return end

	local char = player.Character
	if not char then return end

	local humanoid = char:FindFirstChild("Humanoid")
	if not humanoid then return end

	local boosts = GetPlayerBoosts(player)

	-- Apply Double Health (Forever or 1-Life)
	if data.hasDoubleHealthForever or data.hasDoubleHealth1Life then
		humanoid.MaxHealth = BASE_MAX_HEALTH * 2
		humanoid.Health = BASE_MAX_HEALTH * 2
	end

	-- Apply Speed Boost (Forever or 1-Life)
	if data.hasSpeedBoostForever or data.hasSpeedBoost1Life then
		boosts.robuxSpeedMultiplier = 1.5
		-- Only set WalkSpeed directly if no consumable speed boost is currently active
		if not IsSpeedBoostActive(player) then
			humanoid.WalkSpeed = 20 * 1.5
		end
	else
		boosts.robuxSpeedMultiplier = 1
	end

	-- Sync ownership status to client
	RobuxBoostSyncEvent:FireClient(player, {
		hasSpeedBoostForever = data.hasSpeedBoostForever or false,
		hasDoubleHealthForever = data.hasDoubleHealthForever or false,
		hasSpeedBoost1Life = data.hasSpeedBoost1Life or false,
		hasDoubleHealth1Life = data.hasDoubleHealth1Life or false,
	})
end

local function GrantRobuxBoost(player, boostType)
	if not player or not player.Parent then return false end
	local data = playerData[player.UserId]
	if not data then return false end

	if boostType == "SPEED_BOOST_1LIFE" then
		data.hasSpeedBoost1Life = true
	elseif boostType == "SPEED_BOOST_FOREVER" then
		data.hasSpeedBoostForever = true
	elseif boostType == "DOUBLE_HEALTH_1LIFE" then
		data.hasDoubleHealth1Life = true
	elseif boostType == "DOUBLE_HEALTH_FOREVER" then
		data.hasDoubleHealthForever = true
	else
		warn("[CurrencySystem] GrantRobuxBoost: unknown boostType " .. tostring(boostType))
		return false
	end

	-- Apply boost to character immediately if alive
	ApplyRobuxBoosts(player)

	-- Persist
	task.spawn(function()
		SavePlayerData(player)
	end)

	print("[CurrencySystem] Granted Robux boost '" .. boostType .. "' to " .. player.Name)
	return true
end

-- -------------------------------------------------------------------------------
-- EVENT HANDLERS
-- -------------------------------------------------------------------------------

local function OnDoorOpened(player, reward)
	AddMoney(player, reward, "Door opened")
end

local function OnSurvived(player, reward, npcType)
	if not player or not player.Parent then return end

	local data = playerData[player.UserId]
	if not data then
		data = LoadPlayerData(player)
	end

	if not data then return end

	data.vc = data.vc + reward
	data.totalEarned = data.totalEarned + reward

	print("??? [CurrencySystem] " .. player.Name .. " survived " .. (npcType or "NPC") .. " and earned " .. reward .. " VC")

	SyncPlayer(player)

	task.spawn(function()
		SavePlayerData(player)
	end)

	-- CHECK ENDGAME TRIGGER
	task.spawn(function()
		CheckEndgameTrigger(player)
	end)
end

local function OnPlayerDied(player)
	if not player then return end

	local data = playerData[player.UserId]
	if not data then
		data = LoadPlayerData(player)
		if not data then return end
	end

	data.deaths = (data.deaths or 0) + 1

	local penalty = math.floor((data.vc or 0) * DEATH_PENALTY_PERCENT)
	if penalty > 0 then
		data.vc = math.max(0, (data.vc or 0) - penalty)
		UpdateCurrencyEvent:FireClient(player, data.vc, -penalty, "Death penalty (" .. tostring(math.floor(DEATH_PENALTY_PERCENT * 100)) .. "% VC)")
	end

	if LOSE_ITEMS_ON_DEATH then
		if data.inventory and #data.inventory > 0 then
			data.inventory = {}
			print("?? [CurrencySystem] " .. (player.Name or tostring(player.UserId)) .. " lost all inventory items on death.")
			SyncPlayerWithStatus(player, "ITEMS_LOST_ON_DEATH")
		end
	end

	-- Clear 1-Life Robux boosts on death
	local hadDoubleHealth1Life = data.hasDoubleHealth1Life
	local hadSpeedBoost1Life = data.hasSpeedBoost1Life
	data.hasSpeedBoost1Life = false
	data.hasDoubleHealth1Life = false

	-- Determine Robux speed multiplier that survives death (only Forever)
	local survivingSpeedMult = data.hasSpeedBoostForever and 1.5 or 1

	playerBoosts[player.UserId] = {
		staminaBoostEndTime = 0,
		speedBoostEndTime = 0,
		speedMultiplier = 1,
		robuxSpeedMultiplier = survivingSpeedMult,
	}

	-- Reset MaxHealth if 1-Life double health was active and Forever is not
	if hadDoubleHealth1Life and not data.hasDoubleHealthForever then
		local char = player.Character
		if char then
			local humanoid = char:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.MaxHealth = BASE_MAX_HEALTH
				humanoid.Health = math.min(humanoid.Health, BASE_MAX_HEALTH)
			end
		end
	end

	-- Notify client of updated Robux boost state
	RobuxBoostSyncEvent:FireClient(player, {
		hasSpeedBoostForever = data.hasSpeedBoostForever or false,
		hasDoubleHealthForever = data.hasDoubleHealthForever or false,
		hasSpeedBoost1Life = false,
		hasDoubleHealth1Life = false,
	})

	SyncPlayer(player)
	SyncBoostsToClient(player)

	task.spawn(function()
		SavePlayerData(player)
	end)
end

-- -------------------------------------------------------------------------------
-- REMOTE EVENT CONNECTIONS
-- -------------------------------------------------------------------------------

PlayerDiedEvent.OnServerEvent:Connect(function(player)
	OnPlayerDied(player)
end)

PurchaseItemEvent.OnServerEvent:Connect(function(player, itemId)
	if not player or not player.Parent then return end
	if not dataLoaded[player.UserId] then
		SyncDataEvent:FireClient(player, nil, "DATA_NOT_LOADED")
		return
	end

	local item = GetItemById(itemId)
	if not item then return end

	local data = playerData[player.UserId]
	if not data then return end

	if data.vc < item.price then
		SyncDataEvent:FireClient(player, data, "NO_MONEY")
		return
	end

	local success, status = AddItemToInventory(player, itemId)
	if not success then
		SyncDataEvent:FireClient(player, data, status)
		return
	end

	data.vc = data.vc - item.price
	UpdateCurrencyEvent:FireClient(player, data.vc, -item.price, "Bought " .. item.name)
	SyncDataEvent:FireClient(player, data, "PURCHASE_SUCCESS", itemId)

	print("?? [CurrencySystem] " .. player.Name .. " bought " .. item.name)

	task.spawn(function()
		SavePlayerData(player)
	end)
end)

UseItemEvent.OnServerEvent:Connect(function(player, itemId)
	if not player or not player.Parent then return end
	if not dataLoaded[player.UserId] then return end

	local data = playerData[player.UserId]
	if not data then return end

	local slotIndex = FindItemSlot(data.inventory, itemId)
	if not slotIndex then return end

	if data.inventory[slotIndex].quantity <= 0 then return end

	local item = GetItemById(itemId)
	if not item then return end

	local effectApplied, status, extraData = ApplyItemEffect(player, item)

	if effectApplied then
		RemoveItemFromInventory(player, itemId)
		SyncDataEvent:FireClient(player, data, "ITEM_USED", item)

		task.spawn(function()
			SavePlayerData(player)
		end)
	else
		if status == "BOOST_ACTIVE" then
			SyncDataEvent:FireClient(player, data, "BOOST_ALREADY_ACTIVE", {
				item = item,
				remainingTime = extraData
			})
		else
			SyncDataEvent:FireClient(player, data, "EFFECT_FAILED", item)
		end
	end
end)

-- -------------------------------------------------------------------------------
-- PLAYER CONNECTIONS
-- -------------------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		local data = LoadPlayerData(player)

		playerBoosts[player.UserId] = {
			staminaBoostEndTime = 0,
			speedBoostEndTime = 0,
			speedMultiplier = 1,
			robuxSpeedMultiplier = 1,
		}

		task.wait(1)
		if player and player.Parent then
			SyncPlayer(player)
			SyncBoostsToClient(player)
			print("?? [CurrencySystem] Synced data to " .. player.Name .. ": " .. (data and data.vc or 0) .. " VC")
		end
	end)

	player.CharacterAdded:Connect(function(char)
		playerBoosts[player.UserId] = {
			staminaBoostEndTime = 0,
			speedBoostEndTime = 0,
			speedMultiplier = 1,
			robuxSpeedMultiplier = 1,
		}

		local humanoid = char:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				OnPlayerDied(player)
			end)
		end

		task.wait(0.5)
		if player and player.Parent then
			SyncPlayer(player)
			SyncBoostsToClient(player)
			-- Re-apply any active Robux boosts (Forever or 1-Life)
			ApplyRobuxBoosts(player)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	if not dataLoaded[player.UserId] then
		LoadPlayerData(player)
	end

	local data = playerData[player.UserId]

	if LOSE_ITEMS_ON_LEAVE and data then
		if data.inventory and #data.inventory > 0 then
			data.inventory = {}
			print("?? [CurrencySystem] " .. (player.Name or tostring(player.UserId)) .. " lost all inventory items on leave.")
		end
	end

	if dataLoaded[player.UserId] and data then
		local saved = SavePlayerData(player)
		print("?? [CurrencySystem] Player " .. (player.Name or tostring(player.UserId)) .. " leaving, save " .. (saved and "successful" or "failed"))
	else
		pcall(function() SavePlayerData(player) end)
		print("?? [CurrencySystem] Player " .. (player.Name or tostring(player.UserId)) .. " leaving (no dataLoaded)")
	end

	task.delay(5, function()
		playerData[player.UserId] = nil
		playerBoosts[player.UserId] = nil
		dataLoaded[player.UserId] = nil
		saveLock[player.UserId] = nil
		endgameTriggered[player.UserId] = nil
	end)
end)

-- -------------------------------------------------------------------------------
-- AUTO-SAVE SYSTEM
-- -------------------------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(60)

		local playerCount = 0
		for _, player in pairs(Players:GetPlayers()) do
			if dataLoaded[player.UserId] and playerData[player.UserId] then
				playerCount = playerCount + 1
				task.spawn(function()
					SavePlayerData(player)
				end)
				task.wait(0.5)
			end
		end

		if playerCount > 0 then
			print("?? [CurrencySystem] Auto-saved " .. playerCount .. " players")
		end
	end
end)

-- -------------------------------------------------------------------------------
-- SHUTDOWN SAVE
-- -------------------------------------------------------------------------------

game:BindToClose(function()
	print("?? [CurrencySystem] Server shutting down, saving all player data...")

	for _, player in pairs(Players:GetPlayers()) do
		if dataLoaded[player.UserId] and playerData[player.UserId] then
			task.spawn(function()
				SavePlayerData(player)
			end)
		end
	end

	task.wait(5)
	print("? [CurrencySystem] Shutdown save complete")
end)

-- ===============================================================================
-- EXPORT TO _G
-- ===============================================================================

_G.CurrencySystem = {
	AddMoney = AddMoney,
	RemoveMoney = RemoveMoney,
	OnDoorOpened = OnDoorOpened,
	OnSurvived = OnSurvived,
	AddChestItem = AddChestItemToInventory,
	GetItemById = GetItemById,
	IsDataLoaded = function(player)
		return dataLoaded[player.UserId] == true
	end,
	GetPlayerData = function(player)
		return playerData[player.UserId]
	end,
	-- Robux boost functions
	GrantRobuxBoost = GrantRobuxBoost,
	ApplyRobuxBoosts = ApplyRobuxBoosts,
	HasSpeedBoost = function(player)
		local data = playerData[player.UserId]
		return data and (data.hasSpeedBoostForever or data.hasSpeedBoost1Life) or false
	end,
	HasDoubleHealth = function(player)
		local data = playerData[player.UserId]
		return data and (data.hasDoubleHealthForever or data.hasDoubleHealth1Life) or false
	end,
}

print("? [CurrencySystem] V9 Loaded - Currency: Valor Coin (VC) - Endgame at 10,000 VC")
print("? [CurrencySystem] _G.CurrencySystem ready with all functions")