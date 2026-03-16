--[[
    +------------------------------------------------------------------------------+
    |                 ULTIMATE PLAYER HUD V15 (COIN IMAGE NOTIFICATIONS)            |
    |         Shows remaining boost time, prevents stacking                         |
    |         FIXED: Notifications higher + smaller when shop open                  |
    |         UPDATED: Coin image replaces "VC" text in notifications               |
    |         CURRENCY: Valor Coin (VC)                                             |
    +------------------------------------------------------------------------------+
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- -------------------------------------------------------------------------------
-- VALOR COIN IMAGE ASSET
-- -------------------------------------------------------------------------------
local VC_IMAGE_ID = "rbxassetid://123140394605437"

-- -------------------------------------------------------------------------------
-- WAIT FOR CHARACTER SAFELY
-- -------------------------------------------------------------------------------

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid", 10)

-- -------------------------------------------------------------------------------
-- WAIT FOR REMOTE EVENTS
-- -------------------------------------------------------------------------------

local function WaitForRemote(parent, name, timeout)
	local remote = parent:WaitForChild(name, timeout or 10)
	if not remote then
		warn("[HUD] Could not find remote: " .. name)
	end
	return remote
end

local CurrencyRemotes = ReplicatedStorage:WaitForChild("CurrencyRemotes", 15)

local UpdateCurrencyEvent, SyncDataEvent, UseItemEvent, DoorOpenedEvent, SurvivedDoorEvent, BoostUpdateEvent

if CurrencyRemotes then
	UpdateCurrencyEvent = WaitForRemote(CurrencyRemotes, "UpdateCurrency")
	SyncDataEvent = WaitForRemote(CurrencyRemotes, "SyncData")
	UseItemEvent = WaitForRemote(CurrencyRemotes, "UseItem")
	DoorOpenedEvent = WaitForRemote(CurrencyRemotes, "DoorOpened")
	SurvivedDoorEvent = WaitForRemote(CurrencyRemotes, "SurvivedDoor")
	BoostUpdateEvent = WaitForRemote(CurrencyRemotes, "BoostUpdate")
else
	warn("[HUD] CurrencyRemotes folder not found!")
end

-- -------------------------------------------------------------------------------
-- CONFIGURATION
-- -------------------------------------------------------------------------------
local CONFIG = {
	WALK_SPEED = 20,
	RUN_SPEED = 36,
	MAX_STAMINA = 100,
	STAMINA_DRAIN = 5,
	STAMINA_REGEN = 15,
	REGEN_DELAY = 1.5,
	JUMP_COST = 1,
	CRITICAL_HEALTH_PCT = 0.25,
	LOW_STAMINA_PCT = 0.2,
	COLOR_HEALTH_OK = Color3.fromRGB(80, 255, 120),
	COLOR_HEALTH_LOW = Color3.fromRGB(255, 40, 40),
	COLOR_HEALTH_REGEN = Color3.fromRGB(150, 255, 180),
	COLOR_HEALTH_HEAL = Color3.fromRGB(100, 255, 200),
	COLOR_STAMINA_OK = Color3.fromRGB(80, 220, 255),
	COLOR_STAMINA_LOW = Color3.fromRGB(255, 150, 50),
	COLOR_STAMINA_BOOST = Color3.fromRGB(100, 255, 255),
	COLOR_SPEED_BOOST = Color3.fromRGB(255, 200, 100),
	COLOR_VC = Color3.fromRGB(100, 255, 100),
	LOBBY_START_X = -75,
	LOBBY_END_X = 75,
}

-- -------------------------------------------------------------------------------
-- STATE VARIABLES
-- -------------------------------------------------------------------------------

local currentStamina = CONFIG.MAX_STAMINA
local isTryingToSprint = false
local mobileSprintToggle = false
local canSprint = true
local lastSprintTime = 0

local staminaBoostActive = false
local staminaBoostEndTime = 0
local speedBoostActive = false
local speedBoostEndTime = 0

local playerVC = 0
local playerInventory = {}

local isInLobby = false
local previousHealth = 100
local isRegenerating = false
local justHealed = false
local healFlashEndTime = 0

local ui = {
	healthFill = nil,
	staminaFill = nil,
	healthContainer = nil,
	sprintIcon = nil,
	vcLabel = nil,
	vcIcon = nil,
	inventoryFrame = nil,
	notificationFrame = nil,
	lobbyIndicator = nil,
	boostContainer = nil,
	staminaBoostIndicator = nil,
	staminaBoostTimer = nil,
	speedBoostIndicator = nil,
	speedBoostTimer = nil,
}

local hudReady = false


-- -------------------------------------------------------------------------------
-- CINEMATIC STATE - Hide HUD during intro
-- -------------------------------------------------------------------------------

local isCinematicActive = false

local CinematicRemotes = ReplicatedStorage:FindFirstChild("CinematicRemotes")
if CinematicRemotes then
	local StartCinematicEvent = CinematicRemotes:FindFirstChild("StartCinematic")
	local EndCinematicEvent = CinematicRemotes:FindFirstChild("EndCinematic")

	if StartCinematicEvent then
		StartCinematicEvent.OnClientEvent:Connect(function()
			isCinematicActive = true
			local playerGui = player:FindFirstChild("PlayerGui")
			if playerGui then
				local ultimateHUD = playerGui:FindFirstChild("UltimateHUD")
				if ultimateHUD then
					ultimateHUD.Enabled = false
				end
			end
		end)
	end

	if EndCinematicEvent then
		EndCinematicEvent.OnClientEvent:Connect(function()
			isCinematicActive = false
			local playerGui = player:FindFirstChild("PlayerGui")
			if playerGui then
				local ultimateHUD = playerGui:FindFirstChild("UltimateHUD")
				if ultimateHUD then
					ultimateHUD.Enabled = true
				end
			end
		end)
	end
end

-- -------------------------------------------------------------------------------
-- DEVICE DETECTION
-- -------------------------------------------------------------------------------

local function IsMobile()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function GetScreenScale()
	local viewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
	local baseWidth = 1920
	local baseHeight = 1080

	local scaleX = viewportSize.X / baseWidth
	local scaleY = viewportSize.Y / baseHeight

	return math.min(scaleX, scaleY, 1)
end

-- -------------------------------------------------------------------------------
-- HELPER FUNCTIONS
-- -------------------------------------------------------------------------------

local function CheckIfPlayerInLobby()
	if not character or not character.Parent then return false end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	return hrp.Position.X >= CONFIG.LOBBY_START_X and hrp.Position.X <= CONFIG.LOBBY_END_X
end

local function FormatTime(seconds)
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	if mins > 0 then
		return string.format("%d:%02d", mins, secs)
	else
		return string.format("%ds", secs)
	end
end

-- -------------------------------------------------------------------------------
-- ITEMS CONFIG
-- -------------------------------------------------------------------------------

local ITEMS = {
	{id = "bandage", name = "Bandage", icon = "??", type = "heal", value = 20},
	{id = "medkit", name = "Med Kit", icon = "??", type = "heal", value = 50},
	{id = "adrenaline", name = "Adrenaline", icon = "??", type = "heal", value = 100},
	{id = "energy_drink", name = "Energy Drink", icon = "??", type = "stamina_boost", duration = 30},
	{id = "super_energy", name = "Super Energy", icon = "?", type = "stamina_boost", duration = 60},
	{id = "ultra_boost", name = "Ultra Boost", icon = "??", type = "stamina_boost", duration = 120},
	{id = "speed_pill", name = "Speed Pill", icon = "??", type = "speed_boost", value = 1.5, duration = 20},
	{id = "turbo_boots", name = "Turbo Boots", icon = "??", type = "speed_boost", value = 2.0, duration = 15},
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
-- NOTIFICATIONS (WITH COIN IMAGE - COMPACT LAYOUT, NO GAPS)
-- -------------------------------------------------------------------------------

local activeNotifications = {}

local function ShowNotification(text, color, duration)
	if not ui.notificationFrame then return end

	local isMobile = IsMobile()
	local shopOpen = _G.ShopIsOpen or false

	local notifHeight = isMobile and 22 or 28
	local notifSpacing = isMobile and 26 or 32

	if shopOpen then
		notifHeight = isMobile and 18 or 24
		notifSpacing = isMobile and 22 or 28
	end

	-- Check if this notification is about VC currency
	local hasVC = string.find(text, "VC")

	local notif = Instance.new("Frame")
	notif.Name = "NotifFrame"
	notif.Size = UDim2.new(1, 0, 0, notifHeight)
	notif.Position = UDim2.new(0, 0, 0, 0)
	notif.BackgroundTransparency = 0.2
	notif.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	notif.BorderSizePixel = 0
	notif.ZIndex = 100
	notif.ClipsDescendants = false
	notif.Parent = ui.notificationFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = notif

	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.new(1, 1, 1)
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = notif

	if hasVC then
		-- Split text around "VC" and use coin image instead
		local beforeVC, afterVC = string.match(text, "(.-)%s*VC(.*)")
		if not beforeVC then
			beforeVC = text
			afterVC = ""
		end

		-- Inner container with horizontal layout so everything stays compact
		local innerContainer = Instance.new("Frame")
		innerContainer.Name = "InnerContainer"
		innerContainer.Size = UDim2.new(1, -8, 1, 0)
		innerContainer.Position = UDim2.new(0, 4, 0, 0)
		innerContainer.BackgroundTransparency = 1
		innerContainer.ZIndex = 101
		innerContainer.Parent = notif

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Padding = UDim.new(0, 0) -- No gap, elements touch each other
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = innerContainer

		-- Text before "VC" (e.g. "+5")
		local beforeLabel = Instance.new("TextLabel")
		beforeLabel.Name = "BeforeText"
		beforeLabel.Size = UDim2.new(0, 0, 1, 0)
		beforeLabel.AutomaticSize = Enum.AutomaticSize.X
		beforeLabel.BackgroundTransparency = 1
		beforeLabel.Text = beforeVC
		beforeLabel.TextColor3 = color or Color3.new(1, 1, 1)
		beforeLabel.TextSize = notifHeight - 8
		beforeLabel.Font = Enum.Font.GothamBold
		beforeLabel.TextXAlignment = Enum.TextXAlignment.Left
		beforeLabel.ZIndex = 101
		beforeLabel.LayoutOrder = 1
		beforeLabel.Parent = innerContainer

		-- Coin image (overlaps slightly to stay tight)
		local coinSize = notifHeight + 10
		local coinIcon = Instance.new("ImageLabel")
		coinIcon.Name = "CoinIcon"
		coinIcon.Size = UDim2.new(0, coinSize, 0, coinSize)
		coinIcon.BackgroundTransparency = 1
		coinIcon.Image = VC_IMAGE_ID
		coinIcon.ScaleType = Enum.ScaleType.Fit
		coinIcon.ZIndex = 101
		coinIcon.LayoutOrder = 2
		coinIcon.Parent = innerContainer

		-- Text after "VC" (e.g. " - Door opened")
		if afterVC and afterVC ~= "" then
			local afterLabel = Instance.new("TextLabel")
			afterLabel.Name = "AfterText"
			afterLabel.Size = UDim2.new(0, 0, 1, 0)
			afterLabel.AutomaticSize = Enum.AutomaticSize.X
			afterLabel.BackgroundTransparency = 1
			afterLabel.Text = afterVC
			afterLabel.TextColor3 = color or Color3.new(1, 1, 1)
			afterLabel.TextSize = notifHeight - 8
			afterLabel.Font = Enum.Font.GothamBold
			afterLabel.TextXAlignment = Enum.TextXAlignment.Left
			afterLabel.ZIndex = 101
			afterLabel.LayoutOrder = 3
			afterLabel.Parent = innerContainer
		end
	else
		-- Normal notification without VC - just text
		local textLabel = Instance.new("TextLabel")
		textLabel.Name = "Text"
		textLabel.Size = UDim2.new(1, -16, 1, 0)
		textLabel.Position = UDim2.new(0, 8, 0, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = text
		textLabel.TextColor3 = color or Color3.new(1, 1, 1)
		textLabel.TextScaled = true
		textLabel.Font = Enum.Font.GothamBold
		textLabel.ZIndex = 101
		textLabel.TextXAlignment = Enum.TextXAlignment.Left
		textLabel.Parent = notif
	end

	table.insert(activeNotifications, 1, {notif = notif, spacing = notifSpacing})

	local yOffset = 0
	for i, data in ipairs(activeNotifications) do
		if data.notif and data.notif.Parent then
			TweenService:Create(data.notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, 0, 0, yOffset)
			}):Play()
			yOffset = yOffset + data.spacing
		end
	end

	if #activeNotifications > 3 then
		local oldData = activeNotifications[#activeNotifications]
		if oldData and oldData.notif and oldData.notif.Parent then
			oldData.notif:Destroy()
		end
		table.remove(activeNotifications, #activeNotifications)
	end

	task.delay(duration or 3, function()
		for i, data in ipairs(activeNotifications) do
			if data.notif == notif then
				table.remove(activeNotifications, i)
				break
			end
		end

		if notif and notif.Parent then
			TweenService:Create(notif, TweenInfo.new(0.5), {
				Position = UDim2.new(1, 50, 0, notif.Position.Y.Offset),
				BackgroundTransparency = 1,
			}):Play()

			-- Fade all children (text, images, strokes)
			for _, child in pairs(notif:GetDescendants()) do
				if child:IsA("TextLabel") then
					TweenService:Create(child, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
				elseif child:IsA("ImageLabel") then
					TweenService:Create(child, TweenInfo.new(0.5), {ImageTransparency = 1}):Play()
				elseif child:IsA("UIStroke") then
					TweenService:Create(child, TweenInfo.new(0.5), {Transparency = 1}):Play()
				end
			end

			task.wait(0.6)
			if notif and notif.Parent then
				notif:Destroy()
			end
		end

		local newYOffset = 0
		for i, data in ipairs(activeNotifications) do
			if data.notif and data.notif.Parent then
				TweenService:Create(data.notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.new(0, 0, 0, newYOffset)
				}):Play()
				newYOffset = newYOffset + data.spacing
			end
		end
	end)
end
-- -------------------------------------------------------------------------------
-- CREATE HUD
-- -------------------------------------------------------------------------------

local function CreateHUD()
	local playerGui = player:WaitForChild("PlayerGui")

	if playerGui:FindFirstChild("UltimateHUD") then
		playerGui.UltimateHUD:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "UltimateHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	if isCinematicActive then
		gui.Enabled = false
	end

	local isMobile = IsMobile()
	local scale = isMobile and 0.85 or 1

	local mainFrameWidth = math.floor(240 * scale)
	local mainFrameHeight = math.floor(100 * scale)

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "StatsContainer"
	mainFrame.Size = UDim2.new(0, mainFrameWidth, 0, mainFrameHeight)
	mainFrame.Position = UDim2.new(0, math.floor(25 * scale), 1, math.floor(-125 * scale))
	mainFrame.BackgroundTransparency = 1
	mainFrame.Parent = gui

	local function CreateBar(name, posY, height, color, labelText)
		local bg = Instance.new("Frame")
		bg.Name = name .. "BG"
		bg.Size = UDim2.new(1, 0, 0, math.floor(height * scale))
		bg.Position = UDim2.new(0, 0, 0, math.floor(posY * scale))
		bg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		bg.BorderSizePixel = 0
		bg.Parent = mainFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = bg

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Thickness = 2
		stroke.Transparency = 0.5
		stroke.Parent = bg

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.new(1, 0, 1, 0)
		fill.BackgroundColor3 = color
		fill.BorderSizePixel = 0
		fill.Parent = bg

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 4)
		fillCorner.Parent = fill

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0, 50, 1, 0)
		label.Position = UDim2.new(0, 5, 0, 0)
		label.BackgroundTransparency = 1
		label.Text = labelText
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextSize = math.floor(10 * scale)
		label.TextTransparency = 0.4
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 2
		label.Parent = bg

		return fill, bg
	end

	local hFill, hCont = CreateBar("Health", 0, 16, CONFIG.COLOR_HEALTH_OK, "HP")
	ui.healthFill = hFill
	ui.healthContainer = hCont

	local sFill, sCont = CreateBar("Stamina", 22, 8, CONFIG.COLOR_STAMINA_OK, "STM")
	ui.staminaFill = sFill

	-- VC (Valor Coin) Display Frame
	local vcFrameHeight = math.floor(28 * scale)

	local vcFrame = Instance.new("Frame")
	vcFrame.Name = "VCFrame"
	vcFrame.Size = UDim2.new(1, 0, 0, vcFrameHeight)
	vcFrame.Position = UDim2.new(0, 0, 0, math.floor(38 * scale))
	vcFrame.BackgroundColor3 = Color3.fromRGB(20, 35, 20)
	vcFrame.BorderSizePixel = 0
	vcFrame.Parent = mainFrame

	local vcCorner = Instance.new("UICorner")
	vcCorner.CornerRadius = UDim.new(0, 4)
	vcCorner.Parent = vcFrame
	-- Coin image icon - MUCH BIGGER
	local vcIconSize = math.floor(46 * scale)
	local vcIconImg = Instance.new("ImageLabel")
	vcIconImg.Name = "VCIcon"
	vcIconImg.Size = UDim2.new(0, vcIconSize, 0, vcIconSize)
	vcIconImg.Position = UDim2.new(0, vcIconSize - 30, 0.5, -vcIconSize / 2)
	vcIconImg.BackgroundTransparency = 1
	vcIconImg.Image = VC_IMAGE_ID
	vcIconImg.ScaleType = Enum.ScaleType.Fit
	vcIconImg.ZIndex = 3
	vcIconImg.Parent = vcFrame
	ui.vcIcon = vcIconImg

	local vcLabel = Instance.new("TextLabel")
	vcLabel.Name = "VCLabel"
	vcLabel.Size = UDim2.new(1, -(vcIconSize + 14), 1, 0)
	vcLabel.Position = UDim2.new(0, vcIconSize + 10, 0, 0)
	vcLabel.BackgroundTransparency = 1
	vcLabel.Text = "0 VC"
	vcLabel.TextColor3 = CONFIG.COLOR_VC
	vcLabel.TextScaled = true
	vcLabel.Font = Enum.Font.GothamBold
	vcLabel.TextXAlignment = Enum.TextXAlignment.Left
	vcLabel.ZIndex = 3
	vcLabel.Parent = vcFrame
	ui.vcLabel = vcLabel

	-- Boost Container - ADJUSTED POSITION for bigger VCFrame
	local boostContainer = Instance.new("Frame")
	boostContainer.Name = "BoostContainer"
	boostContainer.Size = UDim2.new(0, mainFrameWidth, 0, math.floor(50 * scale))
	boostContainer.Position = UDim2.new(0, 0, 0, math.floor(72 * scale))
	boostContainer.BackgroundTransparency = 1
	boostContainer.Parent = mainFrame
	ui.boostContainer = boostContainer

	local boostLayout = Instance.new("UIListLayout")
	boostLayout.FillDirection = Enum.FillDirection.Vertical
	boostLayout.Padding = UDim.new(0, 4)
	boostLayout.Parent = boostContainer

	-- Stamina Boost Indicator
	local staminaBoostFrame = Instance.new("Frame")
	staminaBoostFrame.Name = "StaminaBoostIndicator"
	staminaBoostFrame.Size = UDim2.new(1, 0, 0, math.floor(22 * scale))
	staminaBoostFrame.BackgroundColor3 = Color3.fromRGB(20, 50, 55)
	staminaBoostFrame.BorderSizePixel = 0
	staminaBoostFrame.Visible = false
	staminaBoostFrame.Parent = boostContainer
	ui.staminaBoostIndicator = staminaBoostFrame

	local staminaBoostCorner = Instance.new("UICorner")
	staminaBoostCorner.CornerRadius = UDim.new(0, 4)
	staminaBoostCorner.Parent = staminaBoostFrame

	local staminaBoostStroke = Instance.new("UIStroke")
	staminaBoostStroke.Color = CONFIG.COLOR_STAMINA_BOOST
	staminaBoostStroke.Thickness = 1
	staminaBoostStroke.Transparency = 0.5
	staminaBoostStroke.Parent = staminaBoostFrame

	local staminaBoostIcon = Instance.new("TextLabel")
	staminaBoostIcon.Size = UDim2.new(0, math.floor(22 * scale), 1, 0)
	staminaBoostIcon.Position = UDim2.new(0, 2, 0, 0)
	staminaBoostIcon.BackgroundTransparency = 1
	staminaBoostIcon.Text = "?"
	staminaBoostIcon.TextScaled = true
	staminaBoostIcon.Parent = staminaBoostFrame

	local staminaBoostLabel = Instance.new("TextLabel")
	staminaBoostLabel.Size = UDim2.new(0, math.floor(100 * scale), 1, 0)
	staminaBoostLabel.Position = UDim2.new(0, math.floor(26 * scale), 0, 0)
	staminaBoostLabel.BackgroundTransparency = 1
	staminaBoostLabel.Text = "NO STAMINA COST"
	staminaBoostLabel.TextColor3 = CONFIG.COLOR_STAMINA_BOOST
	staminaBoostLabel.TextScaled = true
	staminaBoostLabel.Font = Enum.Font.GothamBold
	staminaBoostLabel.TextXAlignment = Enum.TextXAlignment.Left
	staminaBoostLabel.Parent = staminaBoostFrame

	local staminaBoostTimer = Instance.new("TextLabel")
	staminaBoostTimer.Name = "Timer"
	staminaBoostTimer.Size = UDim2.new(0, math.floor(50 * scale), 1, 0)
	staminaBoostTimer.Position = UDim2.new(1, math.floor(-55 * scale), 0, 0)
	staminaBoostTimer.BackgroundTransparency = 1
	staminaBoostTimer.Text = "0s"
	staminaBoostTimer.TextColor3 = Color3.new(1, 1, 1)
	staminaBoostTimer.TextScaled = true
	staminaBoostTimer.Font = Enum.Font.GothamBold
	staminaBoostTimer.TextXAlignment = Enum.TextXAlignment.Right
	staminaBoostTimer.Parent = staminaBoostFrame
	ui.staminaBoostTimer = staminaBoostTimer

	-- Speed Boost Indicator
	local speedBoostFrame = Instance.new("Frame")
	speedBoostFrame.Name = "SpeedBoostIndicator"
	speedBoostFrame.Size = UDim2.new(1, 0, 0, math.floor(22 * scale))
	speedBoostFrame.BackgroundColor3 = Color3.fromRGB(50, 40, 20)
	speedBoostFrame.BorderSizePixel = 0
	speedBoostFrame.Visible = false
	speedBoostFrame.Parent = boostContainer
	ui.speedBoostIndicator = speedBoostFrame

	local speedBoostCorner = Instance.new("UICorner")
	speedBoostCorner.CornerRadius = UDim.new(0, 4)
	speedBoostCorner.Parent = speedBoostFrame

	local speedBoostStroke = Instance.new("UIStroke")
	speedBoostStroke.Color = CONFIG.COLOR_SPEED_BOOST
	speedBoostStroke.Thickness = 1
	speedBoostStroke.Transparency = 0.5
	speedBoostStroke.Parent = speedBoostFrame

	local speedBoostIcon = Instance.new("TextLabel")
	speedBoostIcon.Size = UDim2.new(0, math.floor(22 * scale), 1, 0)
	speedBoostIcon.Position = UDim2.new(0, 2, 0, 0)
	speedBoostIcon.BackgroundTransparency = 1
	speedBoostIcon.Text = "??"
	speedBoostIcon.TextScaled = true
	speedBoostIcon.Parent = speedBoostFrame

	local speedBoostLabel = Instance.new("TextLabel")
	speedBoostLabel.Size = UDim2.new(0, math.floor(100 * scale), 1, 0)
	speedBoostLabel.Position = UDim2.new(0, math.floor(26 * scale), 0, 0)
	speedBoostLabel.BackgroundTransparency = 1
	speedBoostLabel.Text = "SPEED BOOST"
	speedBoostLabel.TextColor3 = CONFIG.COLOR_SPEED_BOOST
	speedBoostLabel.TextScaled = true
	speedBoostLabel.Font = Enum.Font.GothamBold
	speedBoostLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedBoostLabel.Parent = speedBoostFrame

	local speedBoostTimer = Instance.new("TextLabel")
	speedBoostTimer.Name = "Timer"
	speedBoostTimer.Size = UDim2.new(0, math.floor(50 * scale), 1, 0)
	speedBoostTimer.Position = UDim2.new(1, math.floor(-55 * scale), 0, 0)
	speedBoostTimer.BackgroundTransparency = 1
	speedBoostTimer.Text = "0s"
	speedBoostTimer.TextColor3 = Color3.new(1, 1, 1)
	speedBoostTimer.TextScaled = true
	speedBoostTimer.Font = Enum.Font.GothamBold
	speedBoostTimer.TextXAlignment = Enum.TextXAlignment.Right
	speedBoostTimer.Parent = speedBoostFrame
	ui.speedBoostTimer = speedBoostTimer

	-- Lobby Indicator
	local lobbyFrame = Instance.new("Frame")
	lobbyFrame.Name = "LobbyIndicator"
	lobbyFrame.Size = UDim2.new(1, 0, 0, math.floor(20 * scale))
	lobbyFrame.BackgroundColor3 = Color3.fromRGB(30, 80, 50)
	lobbyFrame.BorderSizePixel = 0
	lobbyFrame.Visible = false
	lobbyFrame.Parent = boostContainer
	ui.lobbyIndicator = lobbyFrame

	local lobbyCorner = Instance.new("UICorner")
	lobbyCorner.CornerRadius = UDim.new(0, 4)
	lobbyCorner.Parent = lobbyFrame

	local lobbyLabel = Instance.new("TextLabel")
	lobbyLabel.Name = "LobbyLabel"
	lobbyLabel.Size = UDim2.new(1, -10, 1, 0)
	lobbyLabel.Position = UDim2.new(0, 5, 0, 0)
	lobbyLabel.BackgroundTransparency = 1
	lobbyLabel.Text = "?? SAFE ZONE - Regenerating"
	lobbyLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
	lobbyLabel.TextScaled = true
	lobbyLabel.Font = Enum.Font.GothamBold
	lobbyLabel.TextXAlignment = Enum.TextXAlignment.Left
	lobbyLabel.Parent = lobbyFrame

	-- Inventory Hotbar (scaled for mobile)
	local invWidth = isMobile and 280 or 340
	local invHeight = isMobile and 45 or 55
	local slotSize = isMobile and 42 or 52

	local invFrame = Instance.new("Frame")
	invFrame.Name = "InventoryHotbar"
	invFrame.Size = UDim2.new(0, invWidth, 0, invHeight)
	invFrame.Position = UDim2.new(0.5, -invWidth/2, 1, -invHeight - 30)
	invFrame.BackgroundTransparency = 1
	invFrame.Parent = gui
	ui.inventoryFrame = invFrame

	ui.slotSize = slotSize

	local invLayout = Instance.new("UIListLayout")
	invLayout.FillDirection = Enum.FillDirection.Horizontal
	invLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	invLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	invLayout.Padding = UDim.new(0, 5)
	invLayout.SortOrder = Enum.SortOrder.LayoutOrder
	invLayout.Parent = invFrame

	-- NOTIFICATION FRAME
	local notifWidth = isMobile and 220 or 280
	local notifTopMargin = isMobile and 25 or 20

	local notifFrame = Instance.new("Frame")
	notifFrame.Name = "Notifications"
	notifFrame.Size = UDim2.new(0, notifWidth, 0, 120)
	notifFrame.Position = UDim2.new(0.5, -notifWidth/2, 0, notifTopMargin)
	notifFrame.BackgroundTransparency = 1
	notifFrame.ZIndex = 100
	notifFrame.Parent = gui
	ui.notificationFrame = notifFrame

	-- Mobile Sprint Button
	if UserInputService.TouchEnabled then
		local btn = Instance.new("ImageButton")
		btn.Name = "MobileSprint"
		btn.Size = UDim2.new(0, 60, 0, 60)
		btn.Position = UDim2.new(1, -80, 1, -160)
		btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
		btn.BackgroundTransparency = 0.5
		btn.Image = "rbxassetid://14703440150"
		btn.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = btn

		local sprintLabel = Instance.new("TextLabel")
		sprintLabel.Name = "SprintLabel"
		sprintLabel.Size = UDim2.new(1, 0, 1, 0)
		sprintLabel.BackgroundTransparency = 1
		sprintLabel.Text = "SPRINT"
		sprintLabel.TextScaled = true
		sprintLabel.Font = Enum.Font.GothamBlack
		sprintLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		sprintLabel.TextStrokeTransparency = 0.3
		sprintLabel.TextXAlignment = Enum.TextXAlignment.Center
		sprintLabel.TextYAlignment = Enum.TextYAlignment.Center
		sprintLabel.ZIndex = 6
		sprintLabel.Parent = btn

		btn.MouseButton1Click:Connect(function()
			mobileSprintToggle = not mobileSprintToggle
			isTryingToSprint = mobileSprintToggle

			TweenService:Create(btn, TweenInfo.new(0.15), {
				BackgroundColor3 = mobileSprintToggle
					and Color3.fromRGB(60, 120, 80)
					or Color3.fromRGB(30, 30, 35)
			}):Play()
		end)

		ui.sprintIcon = btn
	end

	hudReady = true
	print("? [HUD] V15 Created Successfully - Valor Coin (VC)")
end

-- -------------------------------------------------------------------------------
-- UPDATE INVENTORY UI
-- -------------------------------------------------------------------------------

local function UpdateInventoryUI()
	if not ui.inventoryFrame then return end

	for _, child in pairs(ui.inventoryFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local slotSize = ui.slotSize or 52

	for slotIndex, slotData in ipairs(playerInventory) do
		if slotIndex > 6 then break end

		local itemId = slotData.itemId
		local quantity = slotData.quantity

		if quantity > 0 then
			local item = GetItemById(itemId)
			if item then
				local slot = Instance.new("Frame")
				slot.Name = "Slot_" .. slotIndex
				slot.Size = UDim2.new(0, slotSize, 0, slotSize)
				slot.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
				slot.BorderSizePixel = 0
				slot.LayoutOrder = slotIndex
				slot.Parent = ui.inventoryFrame

				local slotCorner = Instance.new("UICorner")
				slotCorner.CornerRadius = UDim.new(0, 8)
				slotCorner.Parent = slot

				local slotStroke = Instance.new("UIStroke")
				slotStroke.Color = Color3.fromRGB(80, 80, 90)
				slotStroke.Thickness = 2
				slotStroke.Parent = slot

				local icon = Instance.new("TextLabel")
				icon.Name = "Icon"
				icon.Size = UDim2.new(1, 0, 0.65, 0)
				icon.Position = UDim2.new(0, 0, 0.05, 0)
				icon.BackgroundTransparency = 1
				icon.Text = item.icon
				icon.TextScaled = true
				icon.Parent = slot

				local qty = Instance.new("TextLabel")
				qty.Name = "Quantity"
				qty.Size = UDim2.new(1, -4, 0.3, 0)
				qty.Position = UDim2.new(0, 2, 0.68, 0)
				qty.BackgroundTransparency = 1
				qty.Text = "x" .. quantity
				qty.TextColor3 = Color3.new(1, 1, 1)
				qty.TextScaled = true
				qty.Font = Enum.Font.GothamBold
				qty.Parent = slot

				local keyLabel = Instance.new("TextLabel")
				keyLabel.Name = "KeyLabel"
				keyLabel.Size = UDim2.new(0, 16, 0, 16)
				keyLabel.Position = UDim2.new(0, 2, 0, 2)
				keyLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
				keyLabel.Text = tostring(slotIndex)
				keyLabel.TextColor3 = Color3.new(1, 1, 1)
				keyLabel.TextScaled = true
				keyLabel.Font = Enum.Font.GothamBold
				keyLabel.Parent = slot

				local keyCorner = Instance.new("UICorner")
				keyCorner.CornerRadius = UDim.new(0, 4)
				keyCorner.Parent = keyLabel

				local btn = Instance.new("TextButton")
				btn.Name = "UseButton"
				btn.Size = UDim2.new(1, 0, 1, 0)
				btn.BackgroundTransparency = 1
				btn.Text = ""
				btn.Parent = slot

				local capturedItemId = itemId

				btn.MouseButton1Click:Connect(function()
					if UseItemEvent then
						UseItemEvent:FireServer(capturedItemId)
					end
				end)

				btn.MouseEnter:Connect(function()
					TweenService:Create(slot, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(50, 50, 60)}):Play()
					TweenService:Create(slotStroke, TweenInfo.new(0.1), {Color = Color3.fromRGB(120, 120, 140)}):Play()
				end)

				btn.MouseLeave:Connect(function()
					TweenService:Create(slot, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 30, 35)}):Play()
					TweenService:Create(slotStroke, TweenInfo.new(0.1), {Color = Color3.fromRGB(80, 80, 90)}):Play()
				end)
			end
		end
	end
end

-- -------------------------------------------------------------------------------
-- UPDATE BOOST INDICATORS
-- -------------------------------------------------------------------------------

local function UpdateBoostIndicators()
	if not ui.staminaBoostIndicator or not ui.speedBoostIndicator then return end

	local now = tick()

	local staminaRemaining = staminaBoostEndTime - now
	if staminaRemaining > 0 then
		staminaBoostActive = true
		ui.staminaBoostIndicator.Visible = true
		ui.staminaBoostTimer.Text = FormatTime(staminaRemaining)

		if staminaRemaining <= 5 then
			local pulse = (math.sin(now * 8) + 1) / 2
			ui.staminaBoostIndicator.BackgroundColor3 = Color3.fromRGB(20, 50, 55):Lerp(Color3.fromRGB(60, 30, 30), pulse)
		else
			ui.staminaBoostIndicator.BackgroundColor3 = Color3.fromRGB(20, 50, 55)
		end
	else
		if staminaBoostActive then
			staminaBoostActive = false
			ShowNotification("? Stamina boost ended", Color3.fromRGB(150, 150, 150), 2)
		end
		ui.staminaBoostIndicator.Visible = false
	end

	local speedRemaining = speedBoostEndTime - now
	if speedRemaining > 0 then
		speedBoostActive = true
		ui.speedBoostIndicator.Visible = true
		ui.speedBoostTimer.Text = FormatTime(speedRemaining)

		if speedRemaining <= 5 then
			local pulse = (math.sin(now * 8) + 1) / 2
			ui.speedBoostIndicator.BackgroundColor3 = Color3.fromRGB(50, 40, 20):Lerp(Color3.fromRGB(60, 30, 30), pulse)
		else
			ui.speedBoostIndicator.BackgroundColor3 = Color3.fromRGB(50, 40, 20)
		end
	else
		if speedBoostActive then
			speedBoostActive = false
			ShowNotification("?? Speed boost ended", Color3.fromRGB(150, 150, 150), 2)
		end
		ui.speedBoostIndicator.Visible = false
	end
end

-- -------------------------------------------------------------------------------
-- APPLY CLIENT-SIDE ITEM EFFECTS
-- -------------------------------------------------------------------------------

local function ApplyClientItemEffect(item)
	if not item then return end

	if item.type == "heal" then
		justHealed = true
		healFlashEndTime = tick() + 1.5
		ShowNotification("?? +" .. item.value .. "% HP", Color3.fromRGB(100, 255, 100), 2)

	elseif item.type == "stamina_boost" then
		staminaBoostEndTime = tick() + item.duration
		staminaBoostActive = true
		currentStamina = CONFIG.MAX_STAMINA
		ShowNotification("? No stamina cost for " .. item.duration .. "s", Color3.fromRGB(100, 255, 255), 3)

	elseif item.type == "speed_boost" then
		speedBoostEndTime = tick() + item.duration
		speedBoostActive = true
		ShowNotification("?? +" .. math.floor((item.value - 1) * 100) .. "% speed for " .. item.duration .. "s", Color3.fromRGB(255, 200, 100), 3)
	end
end

-- -------------------------------------------------------------------------------
-- UPDATE LOBBY STATUS
-- -------------------------------------------------------------------------------

local function UpdateLobbyStatus()
	if not humanoid or humanoid.Health <= 0 then return end

	local wasInLobby = isInLobby
	isInLobby = CheckIfPlayerInLobby()

	local currentHealth = humanoid.Health
	local needsHealing = currentHealth < humanoid.MaxHealth

	local healthIncreased = currentHealth > previousHealth + 0.1
	isRegenerating = healthIncreased and isInLobby and not justHealed

	previousHealth = currentHealth

	if ui.lobbyIndicator then
		ui.lobbyIndicator.Visible = isInLobby and needsHealing
	end

	if isInLobby and not wasInLobby then
		if needsHealing then
			ShowNotification("?? Entered Safe Zone - Health will regenerate", Color3.fromRGB(100, 255, 150), 3)
		else
			ShowNotification("?? Entered Safe Zone", Color3.fromRGB(100, 255, 150), 2)
		end
	elseif not isInLobby and wasInLobby then
		ShowNotification("?? Left Safe Zone - Use items to heal", Color3.fromRGB(255, 200, 100), 3)
	end
end

-- -------------------------------------------------------------------------------
-- SPRINT AND STAMINA LOGIC (FIXED - Respects speed boosts)
-- -------------------------------------------------------------------------------

local function UpdateStamina(dt)
	if not humanoid or humanoid.Health <= 0 then return end

	if justHealed and tick() >= healFlashEndTime then
		justHealed = false
	end

	local isMoving = humanoid.MoveDirection.Magnitude > 0.1

	local isSpeedBoosted = speedBoostActive and (speedBoostEndTime - tick()) > 0

	local baseWalkSpeed = CONFIG.WALK_SPEED
	local baseRunSpeed = CONFIG.RUN_SPEED

	if isSpeedBoosted then
		if isTryingToSprint and isMoving and canSprint then
			if not staminaBoostActive then
				currentStamina = math.clamp(currentStamina - (CONFIG.STAMINA_DRAIN * dt), 0, CONFIG.MAX_STAMINA)
			end
			lastSprintTime = tick()

			if currentStamina <= 0 and not staminaBoostActive then
				canSprint = false
				mobileSprintToggle = false
			end
		else
			if tick() - lastSprintTime > CONFIG.REGEN_DELAY then
				currentStamina = math.clamp(currentStamina + (CONFIG.STAMINA_REGEN * dt), 0, CONFIG.MAX_STAMINA)
			end

			if not canSprint and currentStamina > (CONFIG.MAX_STAMINA * 0.15) then
				canSprint = true
			end
		end
		return
	end

	if isTryingToSprint and isMoving and canSprint then
		if not staminaBoostActive then
			currentStamina = math.clamp(currentStamina - (CONFIG.STAMINA_DRAIN * dt), 0, CONFIG.MAX_STAMINA)
		end

		humanoid.WalkSpeed = baseRunSpeed
		lastSprintTime = tick()

		if currentStamina <= 0 and not staminaBoostActive then
			canSprint = false
			mobileSprintToggle = false
			humanoid.WalkSpeed = baseWalkSpeed
		end
	else
		if not isTryingToSprint then
			humanoid.WalkSpeed = baseWalkSpeed
		end

		if tick() - lastSprintTime > CONFIG.REGEN_DELAY then
			currentStamina = math.clamp(currentStamina + (CONFIG.STAMINA_REGEN * dt), 0, CONFIG.MAX_STAMINA)
		end

		if not canSprint and currentStamina > (CONFIG.MAX_STAMINA * 0.15) then
			canSprint = true
		end
	end
end

-- -------------------------------------------------------------------------------
-- VISUAL UPDATE
-- -------------------------------------------------------------------------------

local function UpdateVisuals()
	if not hudReady or not humanoid or not ui.healthFill then return end

	local healthPct = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)

	TweenService:Create(ui.healthFill, TweenInfo.new(0.1), {
		Size = UDim2.new(healthPct, 0, 1, 0)
	}):Play()

	if healthPct <= CONFIG.CRITICAL_HEALTH_PCT then
		local pulse = (math.sin(tick() * 10) + 1) / 2
		ui.healthFill.BackgroundColor3 = CONFIG.COLOR_HEALTH_LOW:Lerp(Color3.new(1, 1, 1), pulse * 0.5)
	elseif justHealed then
		local pulse = (math.sin(tick() * 8) + 1) / 2
		ui.healthFill.BackgroundColor3 = CONFIG.COLOR_HEALTH_HEAL:Lerp(Color3.new(1, 1, 1), pulse * 0.4)
	elseif isRegenerating then
		local pulse = (math.sin(tick() * 3) + 1) / 2
		ui.healthFill.BackgroundColor3 = CONFIG.COLOR_HEALTH_OK:Lerp(CONFIG.COLOR_HEALTH_REGEN, pulse * 0.3)
	else
		ui.healthFill.BackgroundColor3 = CONFIG.COLOR_HEALTH_OK
	end

	if ui.staminaFill then
		local staminaPct = currentStamina / CONFIG.MAX_STAMINA

		TweenService:Create(ui.staminaFill, TweenInfo.new(0.1), {
			Size = UDim2.new(staminaPct, 0, 1, 0)
		}):Play()

		if staminaBoostActive then
			local pulse = (math.sin(tick() * 5) + 1) / 2
			ui.staminaFill.BackgroundColor3 = CONFIG.COLOR_STAMINA_BOOST:Lerp(Color3.new(1, 1, 1), pulse * 0.3)
		elseif staminaPct <= CONFIG.LOW_STAMINA_PCT or not canSprint then
			local pulse = (math.sin(tick() * 15) + 1) / 2
			local baseColor = canSprint and CONFIG.COLOR_STAMINA_LOW or Color3.fromRGB(150, 50, 50)
			ui.staminaFill.BackgroundColor3 = baseColor:Lerp(Color3.new(1, 1, 1), pulse * 0.3)
		else
			ui.staminaFill.BackgroundColor3 = CONFIG.COLOR_STAMINA_OK
		end
	end

	if ui.vcLabel then
		ui.vcLabel.Text = playerVC .. " VC"
	end

	UpdateBoostIndicators()
end

-- -------------------------------------------------------------------------------
-- CONTROLS
-- -------------------------------------------------------------------------------

local function SetupInputs()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			isTryingToSprint = true
		end

		local keyNumber = nil
		if input.KeyCode == Enum.KeyCode.One then keyNumber = 1
		elseif input.KeyCode == Enum.KeyCode.Two then keyNumber = 2
		elseif input.KeyCode == Enum.KeyCode.Three then keyNumber = 3
		elseif input.KeyCode == Enum.KeyCode.Four then keyNumber = 4
		elseif input.KeyCode == Enum.KeyCode.Five then keyNumber = 5
		elseif input.KeyCode == Enum.KeyCode.Six then keyNumber = 6
		end

		if keyNumber and UseItemEvent then
			local slotData = playerInventory[keyNumber]
			if slotData and slotData.quantity > 0 then
				UseItemEvent:FireServer(slotData.itemId)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			if not UserInputService.TouchEnabled then
				isTryingToSprint = false
			end
		end
	end)

	ContextActionService:BindAction("SprintAction", function(name, state, input)
		isTryingToSprint = (state == Enum.UserInputState.Begin)
	end, false, Enum.KeyCode.ButtonL3, Enum.KeyCode.ButtonB)
end

-- -------------------------------------------------------------------------------
-- SERVER EVENTS
-- -------------------------------------------------------------------------------

if UpdateCurrencyEvent then
	UpdateCurrencyEvent.OnClientEvent:Connect(function(newAmount, change, reason)
		playerVC = newAmount

		local color = change >= 0 and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
		local sign = change >= 0 and "+" or ""
		ShowNotification(sign .. change .. " VC - " .. reason, color, 3)
	end)
end

if SyncDataEvent then
	SyncDataEvent.OnClientEvent:Connect(function(data, status, extra)
		if data then
			playerVC = data.vc or 0
			playerInventory = data.inventory or {}
			UpdateInventoryUI()
		end

		if status == "PURCHASE_SUCCESS" then
			local item = GetItemById(extra)
			if item then
				ShowNotification("?? Bought " .. item.icon .. " " .. item.name, Color3.fromRGB(100, 255, 150), 2)
			end
		elseif status == "NO_MONEY" then
			ShowNotification("? Not enough VC", Color3.fromRGB(255, 100, 100), 2)
		elseif status == "FULL_STACK" then
			ShowNotification("?? Item stack is full (max 10)", Color3.fromRGB(255, 150, 100), 2)
		elseif status == "INVENTORY_FULL" then
			ShowNotification("?? Inventory full (max 6 slots)", Color3.fromRGB(255, 100, 100), 2)
		elseif status == "ITEM_USED" then
			ApplyClientItemEffect(extra)
			UpdateInventoryUI()
		elseif status == "EFFECT_FAILED" then
			ShowNotification("? Cannot use item right now", Color3.fromRGB(255, 100, 100), 2)
		elseif status == "BOOST_ALREADY_ACTIVE" then
			local remainingTime = extra and extra.remainingTime or 0
			local itemName = extra and extra.item and extra.item.name or "Boost"
			ShowNotification("? " .. itemName .. " already active! Wait " .. math.ceil(remainingTime) .. "s", Color3.fromRGB(255, 200, 100), 3)
		elseif status == "DATA_NOT_LOADED" then
			ShowNotification("? Please wait, loading data...", Color3.fromRGB(255, 200, 100), 2)
		elseif status == "CHEST_ITEM_ADDED" then
			local itemId = extra
			local item = GetItemById(itemId)
			if item then
				ShowNotification("?? Found " .. item.icon .. " " .. item.name .. " in chest!", Color3.fromRGB(255, 200, 100), 3)
			end
			UpdateInventoryUI()
		elseif status == "ITEMS_LOST_ON_DEATH" then
			ShowNotification("?? You lost all your items!", Color3.fromRGB(255, 80, 80), 3)
		end
	end)
end

if BoostUpdateEvent then
	BoostUpdateEvent.OnClientEvent:Connect(function(boostData)
		if boostData then
			if boostData.staminaRemaining and boostData.staminaRemaining > 0 then
				staminaBoostEndTime = tick() + boostData.staminaRemaining
			else
				staminaBoostEndTime = 0
			end

			if boostData.speedRemaining and boostData.speedRemaining > 0 then
				speedBoostEndTime = tick() + boostData.speedRemaining
			else
				speedBoostEndTime = 0
			end
		end
	end)
end

if DoorOpenedEvent then
	DoorOpenedEvent.OnClientEvent:Connect(function(reward)
		playerVC = playerVC + reward
	end)
end

if SurvivedDoorEvent then
	SurvivedDoorEvent.OnClientEvent:Connect(function(reward, npcType)
		playerVC = playerVC + reward
	end)
end

-- -------------------------------------------------------------------------------
-- INITIALIZATION
-- -------------------------------------------------------------------------------

CreateHUD()
SetupInputs()
UpdateInventoryUI()

if humanoid then
	previousHealth = humanoid.Health
end

isInLobby = CheckIfPlayerInLobby()

UserInputService.JumpRequest:Connect(function()
	if currentStamina > CONFIG.JUMP_COST and not staminaBoostActive then
		currentStamina = currentStamina - CONFIG.JUMP_COST
		lastSprintTime = tick()
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if character and humanoid and humanoid.Health > 0 then
		UpdateStamina(dt)
		UpdateLobbyStatus()
		UpdateVisuals()
	else
		if ui.lobbyIndicator then
			ui.lobbyIndicator.Visible = false
		end
		if ui.staminaBoostIndicator then
			ui.staminaBoostIndicator.Visible = false
		end
		if ui.speedBoostIndicator then
			ui.speedBoostIndicator.Visible = false
		end
	end
end)

player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid = character:WaitForChild("Humanoid", 10)
	currentStamina = CONFIG.MAX_STAMINA
	canSprint = true
	isTryingToSprint = false

	staminaBoostActive = false
	staminaBoostEndTime = 0
	speedBoostActive = false
	speedBoostEndTime = 0

	isInLobby = false
	isRegenerating = false
	justHealed = false

	if humanoid then
		previousHealth = humanoid.Health
	end

	if ui.lobbyIndicator then
		ui.lobbyIndicator.Visible = false
	end

	if ui.staminaBoostIndicator then
		ui.staminaBoostIndicator.Visible = false
	end

	if ui.speedBoostIndicator then
		ui.speedBoostIndicator.Visible = false
	end

	task.wait(0.5)
	isInLobby = CheckIfPlayerInLobby()
	UpdateInventoryUI()
end)

print("? [HUD] V15 Loaded - Currency: Valor Coin (VC)")