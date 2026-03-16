--[[
    +------------------------------------------------------------------------------+
    |                         SHOP UI - STORE INTERFACE                             |
    |                    V8 - IMPROVED MOVEMENT BLOCKING                            |
    |                    CURRENCY: Valor Coin (VC)                                  |
    +------------------------------------------------------------------------------+
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CurrencyRemotes = ReplicatedStorage:WaitForChild("CurrencyRemotes")
local OpenShopEvent = CurrencyRemotes:WaitForChild("OpenShop")
local PurchaseItemEvent = CurrencyRemotes:WaitForChild("PurchaseItem")
local SyncDataEvent = CurrencyRemotes:WaitForChild("SyncData")
local PurchaseRobuxItemEvent = CurrencyRemotes:WaitForChild("PurchaseRobuxItem", 30)
local RobuxBoostSyncEvent = CurrencyRemotes:WaitForChild("RobuxBoostSync", 30)

if not PurchaseRobuxItemEvent then
	warn("[ShopUI] PurchaseRobuxItem remote not found - Premium purchases will not work")
end
if not RobuxBoostSyncEvent then
	warn("[ShopUI] RobuxBoostSync remote not found - Premium ownership sync will not work")
end

-- -------------------------------------------------------------------------------
-- VALOR COIN IMAGE ASSET
-- -------------------------------------------------------------------------------
local VC_IMAGE_ID = "rbxassetid://123140394605437"

-- -------------------------------------------------------------------------------
-- DEVICE DETECTION
-- -------------------------------------------------------------------------------

local function IsMobile()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function GetViewportSize()
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1920, 1080)
end

-- -------------------------------------------------------------------------------
-- ITEMS CONFIGURATION (ENGLISH)
-- -------------------------------------------------------------------------------

local ITEMS = {
	{id = "bandage", name = "Bandage", description = "Restores 20% health", price = 15, icon = "??", category = "Healing"},
	{id = "medkit", name = "Med Kit", description = "Restores 50% health", price = 35, icon = "??", category = "Healing"},
	{id = "adrenaline", name = "Adrenaline", description = "Restores 100% health", price = 75, icon = "??", category = "Healing"},
	{id = "energy_drink", name = "Energy Drink", description = "No stamina cost for 30 sec", price = 25, icon = "?", category = "Stamina"},
	{id = "super_energy", name = "Super Energy", description = "No stamina cost for 60 sec", price = 50, icon = "??", category = "Stamina"},
	{id = "ultra_boost", name = "Ultra Boost", description = "No stamina cost for 120 sec", price = 100, icon = "??", category = "Stamina"},
	{id = "speed_pill", name = "Speed Pill", description = "+50% speed for 20 sec", price = 30, icon = "??", category = "Speed"},
	{id = "turbo_boots", name = "Turbo Boots", description = "+100% speed for 15 sec", price = 60, icon = "??", category = "Speed"},
}

-- -------------------------------------------------------------------------------
-- PREMIUM ITEMS CONFIGURATION (ROBUX)
-- -------------------------------------------------------------------------------

local PREMIUM_ITEMS = {
	{
		id = "SPEED_BOOST_1LIFE",
		name = "Speed Boost",
		description = "x1.5 speed until you die",
		price = 9,
		icon = "⚡",
		tag = "1 Life",
		forever = false,
	},
	{
		id = "SPEED_BOOST_FOREVER",
		name = "Speed Boost",
		description = "x1.5 speed permanently",
		price = 129,
		icon = "🌟",
		tag = "Forever",
		forever = true,
		ownedField = "hasSpeedBoostForever",
	},
	{
		id = "DOUBLE_HEALTH_1LIFE",
		name = "Double Health",
		description = "x2 max health until you die",
		price = 9,
		icon = "❤️",
		tag = "1 Life",
		forever = false,
	},
	{
		id = "DOUBLE_HEALTH_FOREVER",
		name = "Double Health",
		description = "x2 max health permanently",
		price = 129,
		icon = "💎",
		tag = "Forever",
		forever = true,
		ownedField = "hasDoubleHealthForever",
	},
}

-- Tracks ownership of permanent Robux items (updated via RobuxBoostSync event)
local robuxOwnership = {
	hasSpeedBoostForever   = false,
	hasDoubleHealthForever = false,
	hasSpeedBoost1Life     = false,
	hasDoubleHealth1Life   = false,
}

local shopGui = nil
local isShopOpen = false
local playerVC = 0
local activeTab = "items" -- "items" or "premium"

_G.ShopIsOpen = false

-- -------------------------------------------------------------------------------
-- MOVEMENT CONTROL VARIABLES
-- -------------------------------------------------------------------------------

local savedWalkSpeed = 16
local savedJumpPower = 50
local savedJumpHeight = nil
local movementConnection = nil

-- -------------------------------------------------------------------------------
-- MOUSE CONTROL (Uses Global Controller)
-- -------------------------------------------------------------------------------

local function GetMouseController()
	local attempts = 0
	while not _G.MouseController and attempts < 50 do
		task.wait(0.1)
		attempts = attempts + 1
	end
	return _G.MouseController
end

local function UnlockMouse()
	local controller = GetMouseController()
	if controller then
		controller:Unlock("shop")
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		player.CameraMode = Enum.CameraMode.Classic
	end
end

local function LockMouse()
	local controller = GetMouseController()
	if controller then
		controller:ReleaseLock("shop")
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end
end

-- -------------------------------------------------------------------------------
-- MOVEMENT BLOCKING FUNCTIONS
-- -------------------------------------------------------------------------------

local function BlockPlayerMovement()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		savedWalkSpeed = humanoid.WalkSpeed
		savedJumpPower = humanoid.JumpPower

		local success, currentJumpHeight = pcall(function()
			return humanoid.JumpHeight
		end)
		if success then
			savedJumpHeight = currentJumpHeight
		end

		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0

		pcall(function()
			humanoid.JumpHeight = 0
		end)

		if movementConnection then
			movementConnection:Disconnect()
		end

		movementConnection = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			if isShopOpen and humanoid.WalkSpeed ~= 0 then
				humanoid.WalkSpeed = 0
			end
		end)
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		humanoidRootPart.Anchored = true
	end
end

local function UnblockPlayerMovement()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = savedWalkSpeed
		humanoid.JumpPower = savedJumpPower

		if savedJumpHeight then
			pcall(function()
				humanoid.JumpHeight = savedJumpHeight
			end)
		end

		if movementConnection then
			movementConnection:Disconnect()
			movementConnection = nil
		end
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		humanoidRootPart.Anchored = false
	end
end

-- -------------------------------------------------------------------------------
-- CREATE SHOP UI (RESPONSIVE - NO BACKDROP)
-- -------------------------------------------------------------------------------

local function CreateShopUI()
	if playerGui:FindFirstChild("ShopGUI") then
		playerGui.ShopGUI:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopGUI"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	shopGui = gui

	local isMobile = IsMobile()
	local viewportSize = GetViewportSize()

	local shopWidth, shopHeight, cardWidth, cardHeight, columns
	local headerHeight, fontSize, iconSize, buttonHeight

	if isMobile then
		shopWidth = math.min(viewportSize.X * 0.92, 400)
		shopHeight = math.min(viewportSize.Y * 0.75, 500)
		cardWidth = math.floor((shopWidth - 50) / 2)
		cardHeight = 110
		columns = 2
		headerHeight = 50
		fontSize = 12
		iconSize = 35
		buttonHeight = 28
	else
		shopWidth = 650
		shopHeight = 480
		cardWidth = 195
		cardHeight = 130
		columns = 3
		headerHeight = 60
		fontSize = 16
		iconSize = 45
		buttonHeight = 32
	end

	-- Main container (centered)
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, shopWidth, 0, shopHeight)
	mainFrame.Position = UDim2.new(0.5, -shopWidth/2, 0.5, -shopHeight/2)
	mainFrame.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
	mainFrame.BorderSizePixel = 0
	mainFrame.Active = true
	mainFrame.Parent = gui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, isMobile and 12 or 16)
	mainCorner.Parent = mainFrame

	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = Color3.fromRGB(100, 110, 130)
	mainStroke.Thickness = isMobile and 2 or 3
	mainStroke.Parent = mainFrame

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, headerHeight)
	header.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
	header.BorderSizePixel = 0
	header.Parent = mainFrame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, isMobile and 12 or 16)
	headerCorner.Parent = header

	local headerFix = Instance.new("Frame")
	headerFix.Size = UDim2.new(1, 0, 0.5, 0)
	headerFix.Position = UDim2.new(0, 0, 0.5, 0)
	headerFix.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
	headerFix.BorderSizePixel = 0
	headerFix.Parent = header

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, isMobile and 80 or 120, 1, 0)
	title.Position = UDim2.new(0, isMobile and 10 or 20, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "?? SHOP"
	title.TextColor3 = Color3.fromRGB(255, 230, 120)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	-- VC Display
	local vcFrameWidth = isMobile and 120 or 170
	local vcFrameHeight = isMobile and 30 or 40

	local vcFrame = Instance.new("Frame")
	vcFrame.Name = "VCFrame"
	vcFrame.Size = UDim2.new(0, vcFrameWidth, 0, vcFrameHeight)
	vcFrame.Position = UDim2.new(0.5, -vcFrameWidth/2, 0.5, -vcFrameHeight/2)
	vcFrame.BackgroundColor3 = Color3.fromRGB(40, 80, 50)
	vcFrame.Parent = header

	local vcCorner = Instance.new("UICorner")
	vcCorner.CornerRadius = UDim.new(0, 8)
	vcCorner.Parent = vcFrame

	-- Coin icon image inside VC display (BIGGER)
	local vcIconSize = isMobile and 54 or 58
	local vcIcon = Instance.new("ImageLabel")
	vcIcon.Name = "VCIcon"
	vcIcon.Size = UDim2.new(0, vcIconSize, 0, vcIconSize)
	vcIcon.Position = UDim2.new(0, -2, 0.5, -vcIconSize/2)
	vcIcon.BackgroundTransparency = 1
	vcIcon.Image = VC_IMAGE_ID
	vcIcon.ScaleType = Enum.ScaleType.Fit
	vcIcon.ZIndex = 2
	vcIcon.Parent = vcFrame

	local vcDisplay = Instance.new("TextLabel")
	vcDisplay.Name = "VCDisplay"
	vcDisplay.Size = UDim2.new(1, -(vcIconSize - 8), 1, 0)
	vcDisplay.Position = UDim2.new(0, vcIconSize - 12, 0, 0)
	vcDisplay.BackgroundTransparency = 1
	vcDisplay.Text = "0 VC"
	vcDisplay.TextColor3 = Color3.fromRGB(120, 255, 140)
	vcDisplay.TextScaled = true
	vcDisplay.Font = Enum.Font.GothamBold
	vcDisplay.TextXAlignment = Enum.TextXAlignment.Left
	vcDisplay.ZIndex = 3
	vcDisplay.Parent = vcFrame

	-- Close button
	local closeBtnSize = isMobile and 35 or 45

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, closeBtnSize, 0, closeBtnSize)
	closeBtn.Position = UDim2.new(1, -closeBtnSize - 15, 0, (headerHeight - closeBtnSize) / 2)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = header

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0.5, 0)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(230, 80, 80)}):Play()
	end)

	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(200, 60, 60)}):Play()
	end)

	closeBtn.MouseButton1Click:Connect(function()
		CloseShop()
	end)

	-- -----------------------------------------------------------------------
	-- TAB BAR (between header and content)
	-- -----------------------------------------------------------------------

	local tabHeight = isMobile and 38 or 42

	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, 0, 0, tabHeight)
	tabBar.Position = UDim2.new(0, 0, 0, headerHeight)
	tabBar.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
	tabBar.BorderSizePixel = 0
	tabBar.Parent = mainFrame

	local tabPadding = Instance.new("UIPadding")
	tabPadding.PaddingLeft  = UDim.new(0, isMobile and 8 or 12)
	tabPadding.PaddingRight = UDim.new(0, isMobile and 8 or 12)
	tabPadding.PaddingTop    = UDim.new(0, 5)
	tabPadding.PaddingBottom = UDim.new(0, 5)
	tabPadding.Parent = tabBar

	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.Padding = UDim.new(0, isMobile and 6 or 8)
	tabList.VerticalAlignment = Enum.VerticalAlignment.Center
	tabList.Parent = tabBar

	local tabBtnWidth = isMobile and 110 or 130
	local tabBtnHeight = tabHeight - 10

	local itemsTabBtn = Instance.new("TextButton")
	itemsTabBtn.Name = "ItemsTab"
	itemsTabBtn.Size = UDim2.new(0, tabBtnWidth, 0, tabBtnHeight)
	itemsTabBtn.BackgroundColor3 = Color3.fromRGB(60, 70, 90)  -- active color
	itemsTabBtn.Text = "🛒 Items"
	itemsTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	itemsTabBtn.TextScaled = true
	itemsTabBtn.Font = Enum.Font.GothamBold
	itemsTabBtn.BorderSizePixel = 0
	itemsTabBtn.Parent = tabBar

	local itemsTabCorner = Instance.new("UICorner")
	itemsTabCorner.CornerRadius = UDim.new(0, 8)
	itemsTabCorner.Parent = itemsTabBtn

	local premiumTabBtn = Instance.new("TextButton")
	premiumTabBtn.Name = "PremiumTab"
	premiumTabBtn.Size = UDim2.new(0, tabBtnWidth, 0, tabBtnHeight)
	premiumTabBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 52)  -- inactive color
	premiumTabBtn.Text = "💎 Premium"
	premiumTabBtn.TextColor3 = Color3.fromRGB(160, 165, 185)
	premiumTabBtn.TextScaled = true
	premiumTabBtn.Font = Enum.Font.GothamBold
	premiumTabBtn.BorderSizePixel = 0
	premiumTabBtn.Parent = tabBar

	local premiumTabCorner = Instance.new("UICorner")
	premiumTabCorner.CornerRadius = UDim.new(0, 8)
	premiumTabCorner.Parent = premiumTabBtn

	-- -----------------------------------------------------------------------
	-- CONTENT CONTAINER (below header + tab bar)
	-- -----------------------------------------------------------------------

	local totalHeaderHeight = headerHeight + tabHeight

	local contentContainer = Instance.new("Frame")
	contentContainer.Name = "Content"
	contentContainer.Size = UDim2.new(1, 0, 1, -totalHeaderHeight)
	contentContainer.Position = UDim2.new(0, 0, 0, totalHeaderHeight)
	contentContainer.BackgroundTransparency = 1
	contentContainer.Parent = mainFrame

	-- -----------------------------------------------------------------------
	-- ITEMS TAB CONTENT
	-- -----------------------------------------------------------------------

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ScrollFrame"
	scrollFrame.Size = UDim2.new(1, -20, 1, -20)
	scrollFrame.Position = UDim2.new(0, 10, 0, 10)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = isMobile and 4 or 6
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(120, 130, 160)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.Visible = true
	scrollFrame.Parent = contentContainer

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, cardWidth, 0, cardHeight)
	gridLayout.CellPadding = UDim2.new(0, isMobile and 8 or 10, 0, isMobile and 8 or 10)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = scrollFrame

	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 20)
	end)

	-- Create item cards
	for i, item in ipairs(ITEMS) do
		local card = Instance.new("Frame")
		card.Name = "ItemCard_" .. item.id
		card.BackgroundColor3 = Color3.fromRGB(65, 70, 85)
		card.BorderSizePixel = 0
		card.LayoutOrder = i
		card.Parent = scrollFrame

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 10)
		cardCorner.Parent = card

		-- Icon
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Name = "Icon"
		iconLabel.Size = UDim2.new(0, iconSize, 0, iconSize)
		iconLabel.Position = UDim2.new(0, isMobile and 8 or 10, 0, isMobile and 5 or 10)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = item.icon
		iconLabel.TextScaled = true
		iconLabel.Font = Enum.Font.Gotham
		iconLabel.Parent = card

		-- Name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.Size = UDim2.new(1, -iconSize - (isMobile and 15 or 25), 0, isMobile and 18 or 22)
		nameLabel.Position = UDim2.new(0, iconSize + (isMobile and 8 or 15), 0, isMobile and 5 or 10)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = item.name
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextScaled = true
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = card

		-- Description
		local descLabel = Instance.new("TextLabel")
		descLabel.Name = "Description"
		descLabel.Size = UDim2.new(1, -15, 0, isMobile and 28 or 35)
		descLabel.Position = UDim2.new(0, isMobile and 8 or 10, 0, isMobile and 42 or 55)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = item.description
		descLabel.TextColor3 = Color3.fromRGB(200, 205, 220)
		descLabel.TextScaled = true
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextWrapped = true
		descLabel.Parent = card

		-- Buy button (with coin image + price)
		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyBtn"
		buyBtn.Size = UDim2.new(1, -15, 0, buttonHeight)
		buyBtn.Position = UDim2.new(0, 7.5, 1, -buttonHeight - 8)
		buyBtn.BackgroundColor3 = Color3.fromRGB(60, 170, 90)
		buyBtn.Text = "" -- We'll use child elements instead
		buyBtn.TextColor3 = Color3.new(1, 1, 1)
		buyBtn.TextSize = fontSize
		buyBtn.Font = Enum.Font.GothamBold
		buyBtn.Parent = card

		local buyCorner = Instance.new("UICorner")
		buyCorner.CornerRadius = UDim.new(0, 8)
		buyCorner.Parent = buyBtn

		-- Coin icon inside buy button (BIGGER + overlapping closer to price)
		local btnCoinSize = isMobile and 44 or 48
		local btnCoinIcon = Instance.new("ImageLabel")
		btnCoinIcon.Name = "CoinIcon"
		btnCoinIcon.Size = UDim2.new(0, btnCoinSize, 0, btnCoinSize)
		btnCoinIcon.Position = UDim2.new(0.5, -btnCoinSize - 2, 0.5, -btnCoinSize/2)
		btnCoinIcon.BackgroundTransparency = 1
		btnCoinIcon.Image = VC_IMAGE_ID
		btnCoinIcon.ScaleType = Enum.ScaleType.Fit
		btnCoinIcon.ZIndex = 2
		btnCoinIcon.Parent = buyBtn

		local btnPriceLabel = Instance.new("TextLabel")
		btnPriceLabel.Name = "PriceLabel"
		btnPriceLabel.Size = UDim2.new(0.5, 10, 1, 0)
		btnPriceLabel.Position = UDim2.new(0.5, -8, 0, 0)
		btnPriceLabel.BackgroundTransparency = 1
		btnPriceLabel.Text = item.price .. " VC"
		btnPriceLabel.TextColor3 = Color3.new(1, 1, 1)
		btnPriceLabel.TextScaled = true
		btnPriceLabel.Font = Enum.Font.GothamBold
		btnPriceLabel.TextXAlignment = Enum.TextXAlignment.Left
		btnPriceLabel.ZIndex = 3
		btnPriceLabel.Parent = buyBtn

		buyBtn.MouseEnter:Connect(function()
			TweenService:Create(buyBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(80, 200, 110)}):Play()
			TweenService:Create(card, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(75, 80, 100)}):Play()
		end)

		buyBtn.MouseLeave:Connect(function()
			TweenService:Create(buyBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(60, 170, 90)}):Play()
			TweenService:Create(card, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(65, 70, 85)}):Play()
		end)

		buyBtn.MouseButton1Click:Connect(function()
			TweenService:Create(buyBtn, TweenInfo.new(0.05), {BackgroundColor3 = Color3.fromRGB(120, 230, 150)}):Play()
			PurchaseItemEvent:FireServer(item.id)
			task.wait(0.1)
			TweenService:Create(buyBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(60, 170, 90)}):Play()
		end)

		-- Category badge
		local categoryBadge = Instance.new("TextLabel")
		categoryBadge.Name = "Category"
		categoryBadge.Size = UDim2.new(0, isMobile and 55 or 70, 0, isMobile and 14 or 18)
		categoryBadge.Position = UDim2.new(1, isMobile and -60 or -75, 0, isMobile and 24 or 32)
		categoryBadge.BackgroundColor3 = Color3.fromRGB(85, 95, 125)
		categoryBadge.Text = item.category
		categoryBadge.TextColor3 = Color3.fromRGB(220, 225, 240)
		categoryBadge.TextScaled = true
		categoryBadge.Font = Enum.Font.GothamBold
		categoryBadge.Parent = card

		local catCorner = Instance.new("UICorner")
		catCorner.CornerRadius = UDim.new(0, 5)
		catCorner.Parent = categoryBadge
	end

	-- -----------------------------------------------------------------------
	-- PREMIUM TAB CONTENT
	-- -----------------------------------------------------------------------

	local premCardWidth = isMobile and math.floor((shopWidth - 40) / 2) or 290
	local premCardHeight = isMobile and 115 or 135

	local premiumFrame = Instance.new("ScrollingFrame")
	premiumFrame.Name = "PremiumFrame"
	premiumFrame.Size = UDim2.new(1, -20, 1, -20)
	premiumFrame.Position = UDim2.new(0, 10, 0, 10)
	premiumFrame.BackgroundTransparency = 1
	premiumFrame.BorderSizePixel = 0
	premiumFrame.ScrollBarThickness = isMobile and 4 or 6
	premiumFrame.ScrollBarImageColor3 = Color3.fromRGB(120, 130, 160)
	premiumFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	premiumFrame.Visible = false
	premiumFrame.Parent = contentContainer

	local premGrid = Instance.new("UIGridLayout")
	premGrid.CellSize = UDim2.new(0, premCardWidth, 0, premCardHeight)
	premGrid.CellPadding = UDim2.new(0, isMobile and 8 or 10, 0, isMobile and 8 or 10)
	premGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	premGrid.SortOrder = Enum.SortOrder.LayoutOrder
	premGrid.Parent = premiumFrame

	premGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		premiumFrame.CanvasSize = UDim2.new(0, 0, 0, premGrid.AbsoluteContentSize.Y + 20)
	end)

	-- Create premium product cards
	for i, item in ipairs(PREMIUM_ITEMS) do
		local pCard = Instance.new("Frame")
		pCard.Name = "PremCard_" .. item.id
		pCard.BackgroundColor3 = Color3.fromRGB(55, 60, 78)
		pCard.BorderSizePixel = 0
		pCard.LayoutOrder = i
		pCard.Parent = premiumFrame

		local pCardCorner = Instance.new("UICorner")
		pCardCorner.CornerRadius = UDim.new(0, 10)
		pCardCorner.Parent = pCard

		local pCardStroke = Instance.new("UIStroke")
		pCardStroke.Color = Color3.fromRGB(80, 100, 150)
		pCardStroke.Thickness = 1
		pCardStroke.Parent = pCard

		-- Icon
		local pIcon = Instance.new("TextLabel")
		pIcon.Name = "Icon"
		pIcon.Size = UDim2.new(0, iconSize, 0, iconSize)
		pIcon.Position = UDim2.new(0, isMobile and 8 or 10, 0, isMobile and 5 or 10)
		pIcon.BackgroundTransparency = 1
		pIcon.Text = item.icon
		pIcon.TextScaled = true
		pIcon.Font = Enum.Font.Gotham
		pIcon.Parent = pCard

		-- Name
		local pName = Instance.new("TextLabel")
		pName.Name = "Name"
		pName.Size = UDim2.new(1, -iconSize - (isMobile and 15 or 25), 0, isMobile and 18 or 22)
		pName.Position = UDim2.new(0, iconSize + (isMobile and 8 or 15), 0, isMobile and 5 or 10)
		pName.BackgroundTransparency = 1
		pName.Text = item.name
		pName.TextColor3 = Color3.fromRGB(255, 255, 255)
		pName.TextScaled = true
		pName.Font = Enum.Font.GothamBold
		pName.TextXAlignment = Enum.TextXAlignment.Left
		pName.Parent = pCard

		-- Description
		local pDesc = Instance.new("TextLabel")
		pDesc.Name = "Description"
		pDesc.Size = UDim2.new(1, -15, 0, isMobile and 28 or 35)
		pDesc.Position = UDim2.new(0, isMobile and 8 or 10, 0, isMobile and 42 or 55)
		pDesc.BackgroundTransparency = 1
		pDesc.Text = item.description
		pDesc.TextColor3 = Color3.fromRGB(200, 210, 235)
		pDesc.TextScaled = true
		pDesc.Font = Enum.Font.Gotham
		pDesc.TextXAlignment = Enum.TextXAlignment.Left
		pDesc.TextWrapped = true
		pDesc.Parent = pCard

		-- Tag badge (1 Life / Forever)
		local tagBadge = Instance.new("TextLabel")
		tagBadge.Name = "Tag"
		tagBadge.Size = UDim2.new(0, isMobile and 55 or 65, 0, isMobile and 14 or 18)
		tagBadge.Position = UDim2.new(1, isMobile and -60 or -70, 0, isMobile and 24 or 32)
		tagBadge.BackgroundColor3 = item.forever and Color3.fromRGB(60, 50, 100) or Color3.fromRGB(80, 60, 40)
		tagBadge.Text = item.tag
		tagBadge.TextColor3 = item.forever and Color3.fromRGB(200, 180, 255) or Color3.fromRGB(255, 220, 140)
		tagBadge.TextScaled = true
		tagBadge.Font = Enum.Font.GothamBold
		tagBadge.Parent = pCard

		local tagCorner = Instance.new("UICorner")
		tagCorner.CornerRadius = UDim.new(0, 5)
		tagCorner.Parent = tagBadge

		-- Buy button (Robux style)
		local pBuyBtn = Instance.new("TextButton")
		pBuyBtn.Name = "BuyBtn"
		pBuyBtn.Size = UDim2.new(1, -15, 0, buttonHeight)
		pBuyBtn.Position = UDim2.new(0, 7.5, 1, -buttonHeight - 8)
		pBuyBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 60)
		pBuyBtn.Text = "R$ " .. item.price
		pBuyBtn.TextColor3 = Color3.new(1, 1, 1)
		pBuyBtn.TextScaled = true
		pBuyBtn.Font = Enum.Font.GothamBold
		pBuyBtn.BorderSizePixel = 0
		pBuyBtn.Parent = pCard

		local pBuyCorner = Instance.new("UICorner")
		pBuyCorner.CornerRadius = UDim.new(0, 8)
		pBuyCorner.Parent = pBuyBtn

		-- Update button to show OWNED if applicable
		local function RefreshBuyButton()
			if item.forever and item.ownedField and robuxOwnership[item.ownedField] then
				pBuyBtn.Text = "OWNED ✓"
				pBuyBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 60)
				pBuyBtn.TextColor3 = Color3.fromRGB(150, 255, 170)
				pBuyBtn.Active = false
				pBuyBtn.AutoButtonColor = false
			else
				pBuyBtn.Text = "R$ " .. item.price
				pBuyBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 60)
				pBuyBtn.TextColor3 = Color3.new(1, 1, 1)
				pBuyBtn.Active = true
				pBuyBtn.AutoButtonColor = true
			end
		end

		-- Store refresh function reference on button for later updates
		pBuyBtn:SetAttribute("ItemId", item.id)
		RefreshBuyButton()

		pBuyBtn.MouseEnter:Connect(function()
			if pBuyBtn.Active then
				TweenService:Create(pBuyBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(0, 190, 80)}):Play()
				TweenService:Create(pCard, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(65, 72, 95)}):Play()
			end
		end)

		pBuyBtn.MouseLeave:Connect(function()
			if pBuyBtn.Active then
				TweenService:Create(pBuyBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(0, 150, 60)}):Play()
				TweenService:Create(pCard, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(55, 60, 78)}):Play()
			end
		end)

		pBuyBtn.MouseButton1Click:Connect(function()
			if not pBuyBtn.Active then return end
			-- Fire server to prompt the Robux purchase dialog
			if PurchaseRobuxItemEvent then
				PurchaseRobuxItemEvent:FireServer(item.id)
			end
		end)
	end

	-- -----------------------------------------------------------------------
	-- TAB SWITCHING LOGIC
	-- -----------------------------------------------------------------------

	local function SwitchToTab(tab)
		activeTab = tab
		if tab == "items" then
			scrollFrame.Visible = true
			premiumFrame.Visible = false
			itemsTabBtn.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
			itemsTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			premiumTabBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 52)
			premiumTabBtn.TextColor3 = Color3.fromRGB(160, 165, 185)
		else
			scrollFrame.Visible = false
			premiumFrame.Visible = true
			premiumTabBtn.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
			premiumTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			itemsTabBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 52)
			itemsTabBtn.TextColor3 = Color3.fromRGB(160, 165, 185)
			-- Refresh OWNED status when Premium tab is opened
			for _, pCard in pairs(premiumFrame:GetChildren()) do
				if pCard:IsA("Frame") then
					local btn = pCard:FindFirstChild("BuyBtn")
					if btn then
						local itemId = btn:GetAttribute("ItemId")
						for _, premItem in ipairs(PREMIUM_ITEMS) do
							if premItem.id == itemId and premItem.forever and premItem.ownedField then
								if robuxOwnership[premItem.ownedField] then
									btn.Text = "OWNED ✓"
									btn.BackgroundColor3 = Color3.fromRGB(30, 120, 60)
									btn.TextColor3 = Color3.fromRGB(150, 255, 170)
									btn.Active = false
									btn.AutoButtonColor = false
								end
								break
							end
						end
					end
				end
			end
		end
	end

	-- Apply correct tab on creation (preserve active tab across reopens)
	SwitchToTab(activeTab)

	itemsTabBtn.MouseButton1Click:Connect(function()
		SwitchToTab("items")
	end)

	premiumTabBtn.MouseButton1Click:Connect(function()
		SwitchToTab("premium")
	end)

	return gui
end

-- -------------------------------------------------------------------------------
-- UPDATE PREMIUM BUTTONS (called when RobuxBoostSync fires)
-- -------------------------------------------------------------------------------

local function UpdatePremiumButtons()
	if not shopGui then return end
	local mainFrame = shopGui:FindFirstChild("MainFrame")
	if not mainFrame then return end
	local content = mainFrame:FindFirstChild("Content")
	if not content then return end
	local premFrame = content:FindFirstChild("PremiumFrame")
	if not premFrame then return end

	for _, pCard in pairs(premFrame:GetChildren()) do
		if pCard:IsA("Frame") then
			local btn = pCard:FindFirstChild("BuyBtn")
			if btn then
				local itemId = btn:GetAttribute("ItemId")
				for _, premItem in ipairs(PREMIUM_ITEMS) do
					if premItem.id == itemId and premItem.forever and premItem.ownedField then
						if robuxOwnership[premItem.ownedField] then
							btn.Text = "OWNED ✓"
							btn.BackgroundColor3 = Color3.fromRGB(30, 120, 60)
							btn.TextColor3 = Color3.fromRGB(150, 255, 170)
							btn.Active = false
							btn.AutoButtonColor = false
						else
							btn.Text = "R$ " .. premItem.price
							btn.BackgroundColor3 = Color3.fromRGB(0, 150, 60)
							btn.TextColor3 = Color3.new(1, 1, 1)
							btn.Active = true
							btn.AutoButtonColor = true
						end
						break
					end
				end
			end
		end
	end
end

-- -------------------------------------------------------------------------------
-- OPEN/CLOSE SHOP FUNCTIONS
-- -------------------------------------------------------------------------------

local function UpdateShopVC()
	if shopGui then
		local mainFrame = shopGui:FindFirstChild("MainFrame")
		if mainFrame then
			local header = mainFrame:FindFirstChild("Header")
			if header then
				local vcFrame = header:FindFirstChild("VCFrame")
				if vcFrame then
					local vcDisplay = vcFrame:FindFirstChild("VCDisplay")
					if vcDisplay then
						vcDisplay.Text = playerVC .. " VC"
					end
				end
			end
		end
	end
end

local function OpenShop()
	if isShopOpen then return end
	isShopOpen = true
	_G.ShopIsOpen = true

	CreateShopUI()

	UpdateShopVC()
	UnlockMouse()

	BlockPlayerMovement()

	shopGui.Enabled = true

	local isMobile = IsMobile()
	local viewportSize = GetViewportSize()

	local shopWidth, shopHeight
	if isMobile then
		shopWidth = math.min(viewportSize.X * 0.92, 400)
		shopHeight = math.min(viewportSize.Y * 0.75, 500)
	else
		shopWidth = 650
		shopHeight = 480
	end

	local mainFrame = shopGui:FindFirstChild("MainFrame")
	if mainFrame then
		mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		mainFrame.Size = UDim2.new(0, 0, 0, 0)
		mainFrame.BackgroundTransparency = 1

		TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
			Size = UDim2.new(0, shopWidth, 0, shopHeight),
			Position = UDim2.new(0.5, -shopWidth/2, 0.5, -shopHeight/2),
			BackgroundTransparency = 0
		}):Play()
	end
end

function CloseShop()
	if not isShopOpen then return end
	isShopOpen = false
	_G.ShopIsOpen = false

	if shopGui then
		local mainFrame = shopGui:FindFirstChild("MainFrame")

		if mainFrame then
			TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 0, 0, 0),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				BackgroundTransparency = 1
			}):Play()

			task.wait(0.2)
		end

		shopGui.Enabled = false
	end

	UnblockPlayerMovement()

	LockMouse()
end

-- -------------------------------------------------------------------------------
-- EVENTS
-- -------------------------------------------------------------------------------

OpenShopEvent.OnClientEvent:Connect(function()
	OpenShop()
end)

SyncDataEvent.OnClientEvent:Connect(function(data, status, extra)
	if data then
		playerVC = data.vc or 0
		UpdateShopVC()
	end
end)

-- Handle Robux ownership sync from server
if RobuxBoostSyncEvent then
	RobuxBoostSyncEvent.OnClientEvent:Connect(function(ownershipData)
		if not ownershipData then return end
		-- Update local ownership state
		robuxOwnership.hasSpeedBoostForever   = ownershipData.hasSpeedBoostForever   or false
		robuxOwnership.hasDoubleHealthForever = ownershipData.hasDoubleHealthForever or false
		robuxOwnership.hasSpeedBoost1Life     = ownershipData.hasSpeedBoost1Life     or false
		robuxOwnership.hasDoubleHealth1Life   = ownershipData.hasDoubleHealth1Life   or false
		-- Refresh UI if shop is currently open
		if isShopOpen then
			UpdatePremiumButtons()
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if isShopOpen then
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.E then
			CloseShop()
		end
	end
end)

player.CharacterAdded:Connect(function(char)
	if isShopOpen then
		CloseShop()
	end

	if movementConnection then
		movementConnection:Disconnect()
		movementConnection = nil
	end
end)

-- -------------------------------------------------------------------------------
-- HANDLE SCREEN SIZE CHANGES (rotation, resize)
-- -------------------------------------------------------------------------------

workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	if isShopOpen then
		task.wait(0.1)
		local wasOpen = isShopOpen
		if wasOpen then
			CloseShop()
			task.wait(0.3)
			OpenShop()
		end
	end
end)

-- -------------------------------------------------------------------------------
-- INITIALIZATION
-- -------------------------------------------------------------------------------

CreateShopUI()

print("?? [ShopUI] V8 Loaded - Currency: Valor Coin (VC)")