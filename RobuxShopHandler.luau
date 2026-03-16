--[[
    +------------------------------------------------------------------------------+
    |                  ROBUX SHOP HANDLER - PREMIUM PURCHASES                      |
    |        Handles MarketplaceService developer product purchases                 |
    |        Works with CurrencySystem.luau for data persistence                   |
    +------------------------------------------------------------------------------+
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- -------------------------------------------------------------------------------
-- PRODUCT IDS (Developer Products from Roblox Dashboard)
-- -------------------------------------------------------------------------------

local PRODUCT_IDS = {
	SPEED_BOOST_1LIFE    = 3557304553, -- 9 R$  - x1.5 speed until you die
	SPEED_BOOST_FOREVER  = 3557296682, -- 129 R$ - x1.5 speed permanently
	DOUBLE_HEALTH_1LIFE  = 3557341944, -- 9 R$  - x2 max health until you die
	DOUBLE_HEALTH_FOREVER= 3557342108, -- 129 R$ - x2 max health permanently
}

-- Reverse lookup: productId -> boostType
local PRODUCT_TYPE = {}
for boostType, productId in pairs(PRODUCT_IDS) do
	PRODUCT_TYPE[productId] = boostType
end

-- -------------------------------------------------------------------------------
-- REMOTE EVENTS SETUP
-- -------------------------------------------------------------------------------

local CurrencyRemotes = ReplicatedStorage:WaitForChild("CurrencyRemotes", 30)
if not CurrencyRemotes then
	error("[RobuxShopHandler] CurrencyRemotes folder not found!")
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

-- PurchaseRobuxItem: Client → Server - request to prompt a Robux purchase
local PurchaseRobuxItemEvent = GetOrCreateRemote("PurchaseRobuxItem")

-- RobuxBoostSync is created by CurrencySystem; we wait for it here
local RobuxBoostSyncEvent = CurrencyRemotes:WaitForChild("RobuxBoostSync", 30)
if not RobuxBoostSyncEvent then
	-- Fallback: create it if CurrencySystem hasn't created it yet
	RobuxBoostSyncEvent = GetOrCreateRemote("RobuxBoostSync")
end

-- -------------------------------------------------------------------------------
-- WAIT FOR CURRENCY SYSTEM
-- -------------------------------------------------------------------------------

local function WaitForCurrencySystem(timeout)
	local elapsed = 0
	while not _G.CurrencySystem and elapsed < (timeout or 30) do
		task.wait(0.5)
		elapsed = elapsed + 0.5
	end
	return _G.CurrencySystem
end

-- -------------------------------------------------------------------------------
-- SYNC HELPER
-- -------------------------------------------------------------------------------

local function SyncRobuxStatus(player)
	if not player or not player.Parent then return end
	local currencySystem = _G.CurrencySystem
	if not currencySystem then return end

	local data = currencySystem.GetPlayerData(player)
	if not data then return end

	RobuxBoostSyncEvent:FireClient(player, {
		hasSpeedBoostForever  = data.hasSpeedBoostForever  or false,
		hasDoubleHealthForever = data.hasDoubleHealthForever or false,
		hasSpeedBoost1Life    = data.hasSpeedBoost1Life    or false,
		hasDoubleHealth1Life  = data.hasDoubleHealth1Life  or false,
	})
end

-- -------------------------------------------------------------------------------
-- PURCHASE REQUEST HANDLER (Client → Server)
-- -------------------------------------------------------------------------------

PurchaseRobuxItemEvent.OnServerEvent:Connect(function(player, productType)
	if not player or not player.Parent then return end

	local productId = PRODUCT_IDS[productType]
	if not productId then
		warn("[RobuxShopHandler] Unknown product type from " .. player.Name .. ": " .. tostring(productType))
		return
	end

	-- Check if a Forever product is already owned - no need to prompt again
	local currencySystem = _G.CurrencySystem
	if currencySystem then
		local data = currencySystem.GetPlayerData(player)
		if data then
			if productType == "SPEED_BOOST_FOREVER" and data.hasSpeedBoostForever then
				print("[RobuxShopHandler] " .. player.Name .. " already owns Speed Boost Forever")
				return
			end
			if productType == "DOUBLE_HEALTH_FOREVER" and data.hasDoubleHealthForever then
				print("[RobuxShopHandler] " .. player.Name .. " already owns Double Health Forever")
				return
			end
		end
	end

	-- Prompt the Robux purchase dialog
	MarketplaceService:PromptProductPurchase(player, productId)
end)

-- Handle purchase receipt (Roblox calls this when a developer product purchase is confirmed)
-- NOTE: There must be only ONE ProcessReceipt handler per server. If other scripts in this
-- game handle Robux purchases, consolidate them into a single handler.
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Player left the game; return NotProcessedYet so Roblox retries later
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productType = PRODUCT_TYPE[receiptInfo.ProductId]
	if not productType then
		-- Not one of our Robux shop products; grant anyway to avoid refund loop
		warn("[RobuxShopHandler] Unknown productId: " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Wait for CurrencySystem if it isn't ready yet
	local currencySystem = WaitForCurrencySystem(20)
	if not currencySystem then
		warn("[RobuxShopHandler] CurrencySystem unavailable, cannot process receipt for " .. player.Name)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Wait until the player's data is loaded
	local waitTime = 0
	while not currencySystem.IsDataLoaded(player) and waitTime < 10 do
		task.wait(0.5)
		waitTime = waitTime + 0.5
	end

	-- Grant the boost via CurrencySystem
	local success = currencySystem.GrantRobuxBoost(player, productType)

	if success then
		print("[RobuxShopHandler] Purchase granted: " .. productType .. " for " .. player.Name)
		-- Sync updated ownership status to client UI
		SyncRobuxStatus(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		warn("[RobuxShopHandler] Failed to grant " .. productType .. " for " .. player.Name)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

-- -------------------------------------------------------------------------------
-- SYNC ON PLAYER JOIN & CHARACTER SPAWN
-- -------------------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player)
	-- Wait for data to load then sync Robux boost status to the client UI
	task.spawn(function()
		local currencySystem = WaitForCurrencySystem(30)
		if not currencySystem then return end

		-- Wait for data to finish loading
		local waitTime = 0
		while not currencySystem.IsDataLoaded(player) and waitTime < 15 do
			task.wait(0.5)
			waitTime = waitTime + 0.5
		end

		if player and player.Parent then
			SyncRobuxStatus(player)
		end
	end)
end)

-- Sync status to existing players on script load (in case of hot-reload)
for _, player in pairs(Players:GetPlayers()) do
	task.spawn(function()
		local currencySystem = WaitForCurrencySystem(10)
		if currencySystem and player and player.Parent then
			SyncRobuxStatus(player)
		end
	end)
end

print("[RobuxShopHandler] Loaded - Handling Robux Premium purchases")
