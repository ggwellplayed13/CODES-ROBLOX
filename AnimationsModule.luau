--[[
    +------------------------------------------------------------------------------+
    |                    INFINITE STREET - ANIMATIONS MODULE                        |
    |                    VERSION 39 - ALL HORROR ANIMATIONS FIXED                   |
    +------------------------------------------------------------------------------+
]]

local AnimationsModule = {}

-- Services
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")

-- -------------------------------------------------------------------------------
-- ANIMATION TIMING CONFIG
-- -------------------------------------------------------------------------------

AnimationsModule.TIMING = {
	EYES_FADE_IN = 0.5,
	EYES_VISIBLE_DURATION = 2.0,
	BLINK_COUNT = 2,
	BLINK_OFF_TIME = 0.08,
	BLINK_ON_TIME = 0.17,
	BLINK_PAUSE = 0.4,
	EYES_FADE_OUT = 0.2,
}

-- -------------------------------------------------------------------------------
-- KNOCK ANIMATION CONFIG
-- -------------------------------------------------------------------------------

AnimationsModule.KNOCK_CONFIG = {
	TOTAL_DURATION = 1,
	NUM_KNOCKS = 3,
	VIBRATION_INTENSITY = 0.15,
	VIBRATION_DURATION = 0.08,
}

-- -------------------------------------------------------------------------------
-- STUN EFFECT CONFIG
-- -------------------------------------------------------------------------------

AnimationsModule.STUN_CONFIG = {
	STAR_SIZE_STUDS = 0.6,
	STAR_COLOR = Color3.fromRGB(255, 255, 100),
	STAR_ROTATION_SPEED = 200,
	STAR_ORBIT_RADIUS = 1.5,
	STAR_HEIGHT_OFFSET = 2.0,

	LEVELS = {
		LIGHT = {
			STARS = 3,
			FLASH_COLOR = Color3.fromRGB(255, 255, 150),
		},
		MEDIUM = {
			STARS = 5,
			FLASH_COLOR = Color3.fromRGB(255, 200, 100),
		},
		STRONG = {
			STARS = 7,
			FLASH_COLOR = Color3.fromRGB(255, 100, 100),
		},
	},
}

-- -------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
-- -------------------------------------------------------------------------------

local function LerpColor(c1, c2, t)
	return Color3.new(c1.R + (c2.R - c1.R) * t, c1.G + (c2.G - c1.G) * t, c1.B + (c2.B - c1.B) * t)
end

AnimationsModule.LerpColor = LerpColor

-- -------------------------------------------------------------------------------
-- SAFE REQUIRE FOR HORROR MODULES
-- -------------------------------------------------------------------------------

local HollowManHorrorAnimation = nil
local WatcherHorrorAnimation = nil
local CrawlerHorrorAnimation = nil
local PhantomHorrorAnimation = nil
local ScreamerHorrorAnimation = nil
local HarvesterHorrorAnimation = nil
local StitcherHorrorAnimation = nil
local MinerHorrorAnimation = nil
local SlenderHorrorAnimation = nil
local ShadowManHorrorAnimation = nil

local function SafeRequire(moduleName)
	local success, result = pcall(function()
		local module = ServerScriptService:FindFirstChild(moduleName)
		if module then
			return require(module)
		end
		return nil
	end)
	if success and result then
		print("[AnimationsModule] ? Loaded:  " ..moduleName)
		return result
	else
		warn("[AnimationsModule] ? Failed to load: " ..moduleName .." - " ..tostring(result))
		return nil
	end
end

-- Load all horror animation modules
local function LoadAllModules()
	HollowManHorrorAnimation = SafeRequire("HollowManHorrorAnimation")
	WatcherHorrorAnimation = SafeRequire("WatcherHorrorAnimation")
	CrawlerHorrorAnimation = SafeRequire("CrawlerHorrorAnimation")
	PhantomHorrorAnimation = SafeRequire("PhantomHorrorAnimation")
	ScreamerHorrorAnimation = SafeRequire("ScreamerHorrorAnimation")
	HarvesterHorrorAnimation = SafeRequire("HarvesterHorrorAnimation")
	StitcherHorrorAnimation = SafeRequire("StitcherHorrorAnimation")
	MinerHorrorAnimation = SafeRequire("MinerHorrorAnimation")
	SlenderHorrorAnimation = SafeRequire("SlenderHorrorAnimation")
	ShadowManHorrorAnimation = SafeRequire("ShadowManHorrorAnimation")
end

LoadAllModules()

-- -------------------------------------------------------------------------------
-- DOOR VIBRATION ANIMATION
-- -------------------------------------------------------------------------------

function AnimationsModule.VibrateDoorPart(doorPart, originalCFrame, zDir)
	if not doorPart or not doorPart.Parent then return end

	local intensity = AnimationsModule.KNOCK_CONFIG.VIBRATION_INTENSITY
	local duration = AnimationsModule.KNOCK_CONFIG.VIBRATION_DURATION

	local shakeCFrame = originalCFrame * CFrame.new(0, 0, zDir * intensity)

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local tweenForward = TweenService:Create(doorPart, tweenInfo, {CFrame = shakeCFrame})
	tweenForward:Play()
	tweenForward.Completed:Wait()

	local tweenBack = TweenService:Create(doorPart, tweenInfo, {CFrame = originalCFrame})
	tweenBack:Play()
	tweenBack.Completed:Wait()
end

function AnimationsModule.PlayKnockVibration(doorPart, zDir)
	if not doorPart or not doorPart.Parent then return end

	local originalCFrame = doorPart.CFrame
	local knockInterval = AnimationsModule.KNOCK_CONFIG.TOTAL_DURATION / AnimationsModule.KNOCK_CONFIG.NUM_KNOCKS

	for i = 1, AnimationsModule.KNOCK_CONFIG.NUM_KNOCKS do
		task.spawn(function()
			task.wait((i - 1) * knockInterval)
			AnimationsModule.VibrateDoorPart(doorPart, originalCFrame, zDir)
		end)
	end
end

-- -------------------------------------------------------------------------------
-- DOOR OPEN/CLOSE ANIMATIONS
-- -------------------------------------------------------------------------------

function AnimationsModule.CreateDoorAnimator(door, panels, handle, hingeX, doorCenterY, doorZ, doorWidth, zDir)
	local animator = {}

	function animator.SetAngle(deg)
		local rad = math.rad(deg)
		local pivot = Vector3.new(hingeX, doorCenterY, doorZ)
		local offset = Vector3.new(doorWidth/2, 0, 0)
		local cf = CFrame.new(pivot) * CFrame.Angles(0, rad, 0) * CFrame.new(offset)
		door.CFrame = cf
		for _, p in ipairs(panels) do
			p.part.CFrame = cf * CFrame.new(p.offset)
		end
		handle.CFrame = cf * CFrame.new(animator.handleOffset)
	end

	animator.handleOffset = Vector3.new(doorWidth/2 - 0.5, -0.15, zDir * (0.25/2 + 0.08))

	function animator.OpenDoor(openAngle, duration)
		local steps = 45
		local stepTime = duration / steps

		for i = 1, steps do
			local progress = i / steps
			local easedProgress = 1 - math.pow(1 - progress, 3)
			local currentAngle = openAngle * easedProgress
			animator.SetAngle(currentAngle)
			task.wait(stepTime)
		end
		animator.SetAngle(openAngle)
	end

	function animator.CloseDoor(fromAngle, duration)
		local steps = 20
		local stepTime = duration / steps

		for i = 1, steps do
			local progress = i / steps
			local easedProgress = progress * progress
			local currentAngle = fromAngle * (1 - easedProgress)
			animator.SetAngle(currentAngle)
			task.wait(stepTime)
		end
		animator.SetAngle(0)
	end

	return animator
end

-- -------------------------------------------------------------------------------
-- STANDARD EYE CREATION FUNCTIONS
-- -------------------------------------------------------------------------------

function AnimationsModule.CreateStandardEyes(doorX, eyeY, eyeZ, eyeColor, doorFolder, MakePart)
	local eyeParts = {}
	local eyeLights = {}
	local eyeGap = 0.4

	local leftEye = MakePart("LeftEye", Vector3.new(0.15, 0.35, 0.06),
		Vector3.new(doorX - eyeGap/2, eyeY, eyeZ),
		eyeColor, Enum.Material.Neon, doorFolder, false, false, 1)

	local rightEye = MakePart("RightEye", Vector3.new(0.15, 0.35, 0.06),
		Vector3.new(doorX + eyeGap/2, eyeY, eyeZ),
		eyeColor, Enum.Material.Neon, doorFolder, false, false, 1)

	local leftEyeLight = Instance.new("PointLight")
	leftEyeLight.Brightness = 0
	leftEyeLight.Color = eyeColor
	leftEyeLight.Range = 5
	leftEyeLight.Parent = leftEye

	local rightEyeLight = Instance.new("PointLight")
	rightEyeLight.Brightness = 0
	rightEyeLight.Color = eyeColor
	rightEyeLight.Range = 5
	rightEyeLight.Parent = rightEye

	table.insert(eyeParts, leftEye)
	table.insert(eyeParts, rightEye)
	table.insert(eyeLights, leftEyeLight)
	table.insert(eyeLights, rightEyeLight)

	return eyeParts, eyeLights
end

function AnimationsModule.CreateWatcherEyes(doorX, eyeY, eyeZ, doorFolder, MakePart)
	local eyeParts = {}
	local eyeLights = {}

	local watcherEyeColors = {
		PRIMARY = Color3.fromRGB(255, 60, 30),
		SECONDARY = Color3.fromRGB(255, 180, 50),
	}

	local mainEyeSize = Vector3.new(0.8, 0.8, 0.08)

	local mainEyeSclera = MakePart("WatcherMainEye", mainEyeSize,
		Vector3.new(doorX, eyeY + 0.8, eyeZ),
		Color3.fromRGB(255, 250, 240), Enum.Material.Neon, doorFolder, false, false, 1)

	local mainEyeIris = MakePart("WatcherMainIris", Vector3.new(0.48, 0.48, 0.05),
		Vector3.new(doorX, eyeY + 0.8, eyeZ + 0.02),
		watcherEyeColors.PRIMARY, Enum.Material.Neon, doorFolder, false, false, 1)

	local mainEyePupil = MakePart("WatcherMainPupil", Vector3.new(0.12, 0.4, 0.04),
		Vector3.new(doorX, eyeY + 0.8, eyeZ + 0.04),
		Color3.fromRGB(0, 0, 0), Enum.Material.SmoothPlastic, doorFolder, false, false, 1)

	local mainEyeLight = Instance.new("PointLight")
	mainEyeLight.Brightness = 0
	mainEyeLight.Color = watcherEyeColors.PRIMARY
	mainEyeLight.Range = 12
	mainEyeLight.Parent = mainEyeIris

	table.insert(eyeParts, mainEyeSclera)
	table.insert(eyeParts, mainEyeIris)
	table.insert(eyeParts, mainEyePupil)
	table.insert(eyeLights, mainEyeLight)

	local mediumEyePositions = {
		{x = -1.2, y = 1.5}, {x = 1.4, y = 1.3},
		{x = -0.8, y = -0.3}, {x = 1.1, y = -0.5},
	}

	for i, pos in ipairs(mediumEyePositions) do
		local mediumEye = MakePart("WatcherMediumEye"..i, Vector3.new(0.25, 0.3, 0.06),
			Vector3.new(doorX + pos.x, eyeY + pos.y, eyeZ),
			watcherEyeColors.SECONDARY, Enum.Material.Neon, doorFolder, false, false, 1)

		local mediumLight = Instance.new("PointLight")
		mediumLight.Brightness = 0
		mediumLight.Color = watcherEyeColors.SECONDARY
		mediumLight.Range = 4
		mediumLight.Parent = mediumEye

		table.insert(eyeParts, mediumEye)
		table.insert(eyeLights, mediumLight)
	end

	return eyeParts, eyeLights
end

-- -------------------------------------------------------------------------------
-- EYE ANIMATION CONTROLLER (For standard eyes without horror animation)
-- -------------------------------------------------------------------------------

function AnimationsModule.CreateEyeAnimator(eyeParts, eyeLights, eyeType)
	local animator = {}

	function animator.FadeInEyes()
		for _, eyePart in ipairs(eyeParts) do
			TweenService:Create(eyePart, TweenInfo.new(AnimationsModule.TIMING.EYES_FADE_IN), {Transparency = 0}):Play()
		end
		for _, light in ipairs(eyeLights) do
			TweenService: Create(light, TweenInfo.new(AnimationsModule.TIMING.EYES_FADE_IN), {Brightness = 4}):Play()
		end
		task.wait(AnimationsModule.TIMING.EYES_FADE_IN)
	end

	function animator.FadeOutEyes()
		for _, eyePart in ipairs(eyeParts) do
			TweenService: Create(eyePart, TweenInfo.new(AnimationsModule.TIMING.EYES_FADE_OUT), {Transparency = 1}):Play()
		end
		for _, light in ipairs(eyeLights) do
			TweenService:Create(light, TweenInfo.new(AnimationsModule.TIMING.EYES_FADE_OUT), {Brightness = 0}):Play()
		end
		task.wait(AnimationsModule.TIMING.EYES_FADE_OUT)
	end

	function animator.BlinkEyes()
		for _ = 1, AnimationsModule.TIMING.BLINK_COUNT do
			for _, eyePart in ipairs(eyeParts) do
				eyePart.Transparency = 1
			end
			for _, light in ipairs(eyeLights) do
				light.Brightness = 0
			end
			task.wait(AnimationsModule.TIMING.BLINK_OFF_TIME)

			for _, eyePart in ipairs(eyeParts) do
				eyePart.Transparency = 0
			end
			for _, light in ipairs(eyeLights) do
				light.Brightness = 4
			end
			task.wait(AnimationsModule.TIMING.BLINK_ON_TIME)
		end
		task.wait(AnimationsModule.TIMING.BLINK_PAUSE)
	end

	function animator.GetHorrorDuration()
		return 0
	end

	return animator
end

-- -------------------------------------------------------------------------------
-- STUN EFFECT ANIMATION
-- -------------------------------------------------------------------------------

function AnimationsModule.CreateStunEffect(npcModel, stunTime, powerLevel, headPartOverride)
	if not npcModel or not npcModel.Parent then return end

	local levelConfig = AnimationsModule.STUN_CONFIG.LEVELS[powerLevel] or AnimationsModule.STUN_CONFIG.LEVELS.LIGHT
	local starCount = levelConfig.STARS

	local attachPart = headPartOverride

	if not attachPart then
		attachPart = npcModel:FindFirstChild("Head") 
			or npcModel:FindFirstChild("HeadMain")
			or npcModel:FindFirstChild("Skull")
			or npcModel:FindFirstChild("Crown")
			or npcModel:FindFirstChild("Chest")
			or npcModel:FindFirstChild("Thorax") 
			or npcModel: FindFirstChild("CoreBody")
			or npcModel:FindFirstChild("Abdomen")
			or npcModel:FindFirstChild("Eyeball")
			or npcModel:FindFirstChildWhichIsA("BasePart")
	end

	if not attachPart then return end

	local stunFolder = Instance.new("Folder")
	stunFolder.Name = "StunEffect"
	stunFolder.Parent = npcModel

	local stars = {}
	local starSize = AnimationsModule.STUN_CONFIG.STAR_SIZE_STUDS

	for i = 1, starCount do
		local starPart = Instance.new("Part")
		starPart.Name = "Star"..i
		starPart.Size = Vector3.new(starSize, starSize, 0.1)
		starPart.Anchored = true
		starPart.CanCollide = false
		starPart.CastShadow = false
		starPart.Material = Enum.Material.Neon
		starPart.Color = AnimationsModule.STUN_CONFIG.STAR_COLOR
		starPart.Transparency = 0
		starPart.Parent = stunFolder

		local frontGui = Instance.new("SurfaceGui")
		frontGui.Name = "StarFront"
		frontGui.Face = Enum.NormalId.Front
		frontGui.LightInfluence = 0
		frontGui.Brightness = 2
		frontGui.Parent = starPart

		local starLabel = Instance.new("TextLabel")
		starLabel.Size = UDim2.new(1, 0, 1, 0)
		starLabel.BackgroundTransparency = 1
		starLabel.Text = "?"
		starLabel.TextScaled = true
		starLabel.TextColor3 = AnimationsModule.STUN_CONFIG.STAR_COLOR
		starLabel.Font = Enum.Font.GothamBold
		starLabel.Parent = frontGui

		local backGui = Instance.new("SurfaceGui")
		backGui.Name = "StarBack"
		backGui.Face = Enum.NormalId.Back
		backGui.LightInfluence = 0
		backGui.Brightness = 2
		backGui.Parent = starPart

		local starLabelBack = Instance.new("TextLabel")
		starLabelBack.Size = UDim2.new(1, 0, 1, 0)
		starLabelBack.BackgroundTransparency = 1
		starLabelBack.Text = "?"
		starLabelBack.TextScaled = true
		starLabelBack.TextColor3 = AnimationsModule.STUN_CONFIG.STAR_COLOR
		starLabelBack.Font = Enum.Font.GothamBold
		starLabelBack.Parent = backGui

		local starLight = Instance.new("PointLight")
		starLight.Brightness = 1
		starLight.Color = AnimationsModule.STUN_CONFIG.STAR_COLOR
		starLight.Range = 2
		starLight.Parent = starPart

		table.insert(stars, {
			part = starPart,
			angle = (i - 1) * (360 / starCount),
			orbitSpeed = AnimationsModule.STUN_CONFIG.STAR_ROTATION_SPEED + math.random(-20, 20),
			verticalOffset = math.random() * 0.3,
		})
	end

	local startTime = tick()
	local animationConnection

	animationConnection = RunService.Heartbeat:Connect(function()
		local elapsed = tick() - startTime

		if elapsed >= stunTime or not stunFolder or not stunFolder.Parent then
			if animationConnection then
				animationConnection:Disconnect()
			end
			if stunFolder and stunFolder.Parent then
				for _, starData in ipairs(stars) do
					if starData.part and starData.part.Parent then
						TweenService:Create(starData.part, TweenInfo.new(0.3), {
							Transparency = 1
						}):Play()
					end
				end

				task.delay(0.35, function()
					if stunFolder and stunFolder.Parent then
						stunFolder: Destroy()
					end
				end)
			end
			return
		end

		if not attachPart or not attachPart.Parent then
			if animationConnection then
				animationConnection:Disconnect()
			end
			if stunFolder then stunFolder:Destroy() end
			return
		end

		local headPosition = attachPart.Position
		local orbitCenter = headPosition + Vector3.new(0, AnimationsModule.STUN_CONFIG.STAR_HEIGHT_OFFSET, 0)

		for _, starData in ipairs(stars) do
			if starData.part and starData.part.Parent then
				local currentAngle = starData.angle + (elapsed * starData.orbitSpeed)
				local radAngle = math.rad(currentAngle)

				local offsetX = math.cos(radAngle) * AnimationsModule.STUN_CONFIG.STAR_ORBIT_RADIUS
				local offsetZ = math.sin(radAngle) * AnimationsModule.STUN_CONFIG.STAR_ORBIT_RADIUS
				local offsetY = math.sin(elapsed * 3 + starData.angle) * 0.15 + starData.verticalOffset

				local starPosition = orbitCenter + Vector3.new(offsetX, offsetY, offsetZ)

				local camera = workspace.CurrentCamera
				if camera then
					local lookAt = camera.CFrame.Position
					local direction = (lookAt - starPosition).Unit
					starData.part.CFrame = CFrame.new(starPosition, starPosition + direction)
				else
					starData.part.Position = starPosition
				end
			end
		end
	end)

	return stunFolder
end

-- -------------------------------------------------------------------------------
-- HELPER:  CREATE EYES BASED ON TYPE (FIXED VERSION)
-- -------------------------------------------------------------------------------

function AnimationsModule.CreateEyesForNPC(eyeType, eyeColor, doorX, eyeY, eyeZ, doorFolder, MakePart, voidCenterZ, holeWidth, holeHeight, zDir)
	local eyeParts = {}
	local eyeLights = {}
	local horrorAnimator = nil
	local horrorDuration = 0

	zDir = zDir or 1

	-- Normalize eyeType to uppercase for consistent matching
	local normalizedEyeType = eyeType and string.upper(eyeType) or "UNKNOWN"

	-- Debug output
	print("[AnimationsModule] ========================================")
	print("[AnimationsModule] CreateEyesForNPC called:")
	print("  - eyeType (original): " ..tostring(eyeType))
	print("  - eyeType (normalized): " ..normalizedEyeType)
	print("  - voidCenterZ: " ..tostring(voidCenterZ))
	print("  - zDir: " ..tostring(zDir))
	print("[AnimationsModule] Module Status:")
	print("  - HollowManHorrorAnimation: " ..tostring(HollowManHorrorAnimation ~= nil))
	print("  - WatcherHorrorAnimation: " ..tostring(WatcherHorrorAnimation ~= nil))
	print("  - CrawlerHorrorAnimation: " ..tostring(CrawlerHorrorAnimation ~= nil))
	print("  - PhantomHorrorAnimation: " ..tostring(PhantomHorrorAnimation ~= nil))
	print("  - ScreamerHorrorAnimation: " ..tostring(ScreamerHorrorAnimation ~= nil))
	print("  - HarvesterHorrorAnimation: " ..tostring(HarvesterHorrorAnimation ~= nil))
	print("  - MinerHorrorAnimation: " .. tostring(MinerHorrorAnimation ~= nil))
	print("[AnimationsModule] ========================================")

	-- =========================================================================
	-- HARVESTER REAPER
	-- =========================================================================
	if normalizedEyeType == "HARVESTER_REAPER" or normalizedEyeType == "HARVESTER" then
		if voidCenterZ and HarvesterHorrorAnimation then
			print("[AnimationsModule] ? Creating HARVESTER horror animation")
			local success, result = pcall(function()
				return HarvesterHorrorAnimation.Create(
					doorX, eyeY, eyeZ, doorFolder, zDir, voidCenterZ
				)
			end)
			if success and result then
				horrorAnimator = result
				horrorDuration = HarvesterHorrorAnimation.TIMING.TOTAL_DURATION
				print("[AnimationsModule] ? Harvester horror duration: " ..horrorDuration)
			else
				warn("[AnimationsModule] ? Failed to create Harvester animation: " ..tostring(result))
			end
		else
			print("[AnimationsModule] ? Cannot create Harvester:  voidCenterZ=" ..tostring(voidCenterZ) ..", module=" ..tostring(HarvesterHorrorAnimation ~= nil))
		end
		eyeParts, eyeLights = AnimationsModule.CreateStandardEyes(doorX, eyeY, eyeZ, eyeColor, doorFolder, MakePart)

		-- =========================================================================
		-- WATCHER - The Thousand Eyes
		-- =========================================================================
	elseif normalizedEyeType == "WATCHER_SINGLE" or normalizedEyeType == "WATCHER" or normalizedEyeType == "WATCHER_MULTI" then
		if voidCenterZ and WatcherHorrorAnimation then
			print("[AnimationsModule] ? Creating WATCHER horror animation")
			local success, result = pcall(function()
				return WatcherHorrorAnimation.Create(
					doorX, eyeY, eyeZ, doorFolder, zDir, voidCenterZ
				)
			end)
			if success and result then
				horrorAnimator = result
				horrorDuration = WatcherHorrorAnimation.TIMING.TOTAL_DURATION
				print("[AnimationsModule] ? Watcher horror duration: " ..horrorDuration)
			else
				warn("[AnimationsModule] ? Failed to create Watcher animation: " ..tostring(result))
			end
		else
			print("[AnimationsModule] ? Cannot create Watcher: voidCenterZ=" ..tostring(voidCenterZ) ..", module=" ..tostring(WatcherHorrorAnimation ~= nil))
		end
		eyeParts, eyeLights = AnimationsModule.CreateWatcherEyes(doorX, eyeY, eyeZ, doorFolder, MakePart)

		-- =========================================================================
		-- SHADOW / HOLLOW MAN - Standard white eyes
		-- =========================================================================
	elseif normalizedEyeType == "MINER" or normalizedEyeType == "MINER_GHOST" then
		if voidCenterZ and MinerHorrorAnimation then
			print("[AnimationsModule] ?? Creating MINER horror animation")
			local success, result = pcall(function()
				return MinerHorrorAnimation.Create(
					doorX, eyeY, eyeZ, doorFolder, zDir, voidCenterZ
				)
			end)
			if success and result then
				horrorAnimator = result
				horrorDuration = MinerHorrorAnimation.TIMING.TOTAL_DURATION
				print("[AnimationsModule] ?? Miner horror duration: " .. horrorDuration)
			else
				warn("[AnimationsModule] ? Failed to create Miner animation: " .. tostring(result))
			end
		else
			print("[AnimationsModule] ?? Cannot create Miner: voidCenterZ=" .. tostring(voidCenterZ) .. ", module=" .. tostring(MinerHorrorAnimation ~= nil))
		end
		eyeParts, eyeLights = AnimationsModule.CreateStandardEyes(doorX, eyeY, eyeZ, eyeColor, doorFolder, MakePart)
		
		
	elseif normalizedEyeType == "SLENDER" or normalizedEyeType == "SLENDER_VOID" then
		if voidCenterZ and SlenderHorrorAnimation then
			print("[AnimationsModule] ??? Creating SLENDER horror animation")
			local success, result = pcall(function()
				return SlenderHorrorAnimation.Create(
					doorX, eyeY, eyeZ, doorFolder, zDir, voidCenterZ, holeWidth or 10, holeHeight or 12
				)
			end)
			if success and result then
				horrorAnimator = result
				horrorDuration = SlenderHorrorAnimation.TIMING.TOTAL_DURATION
				print("[AnimationsModule] ??? Slender horror duration: " ..horrorDuration)
			else
				warn("[AnimationsModule] ? Failed to create Slender animation: " ..tostring(result))
			end
		else
			print("[AnimationsModule] ??? Cannot create Slender: voidCenterZ=" ..tostring(voidCenterZ) ..", module=" ..tostring(SlenderHorrorAnimation ~= nil))
		end
		eyeParts, eyeLights = AnimationsModule.CreateStandardEyes(doorX, eyeY, eyeZ, eyeColor, doorFolder, MakePart)
		
	elseif normalizedEyeType == "STITCHER" or normalizedEyeType == "STITCHER_BUTTONS" then
		if voidCenterZ and StitcherHorrorAnimation then
			print("[AnimationsModule] Creating STITCHER horror animation")
			local success, result = pcall(function()
				return StitcherHorrorAnimation.Create(
					doorX, eyeY, eyeZ, doorFolder, zDir, voidCenterZ
				)
			end)
			if success and result then
				horrorAnimator = result
				horrorDuration = StitcherHorrorAnimation.TIMING.TOTAL_DURATION
				print("[AnimationsModule] Stitcher horror duration: " .. horrorDuration)
			else
				warn("[AnimationsModule] Failed to create Stitcher animation: " .. tostring(result))
			end
		else
			print("[AnimationsModule] Cannot create Stitcher: voidCenterZ=" .. tostring(voidCenterZ) .. ", module=" .. tostring(StitcherHorrorAnimation ~= nil))
		end
		eyeParts, eyeLights = AnimationsModule.CreateStandardEyes(doorX, eyeY, eyeZ, eyeColor, doorFolder, MakePart)
		
	elseif normalizedEyeType == "STANDARD" or normalizedEyeType == "HOLLOW_MAN" or normalizedEyeType == "SHADOW" then
		if voidCenterZ and HollowManHorrorAnimation then
			print("[AnimationsModule] ? Creating HOLLOW MAN horror animation")
			local success, result = pcall(function()
				return HollowManHorrorAnimation.Create(
					doorX, eyeY, eyeZ, doorFolder, zDir, voidCenterZ
				)
			end)
			if success and result then
				horrorAnimator = result
				horrorDuration = HollowManHorrorAnimation.TIMING.TOTAL_DURATION
				print("[AnimationsModule] ? HollowMan horror duration: " ..horrorDuration)
			else
				warn("[AnimationsModule] ? Failed to create HollowMan animation: " ..tostring(result))
			end
		else
			print("[AnimationsModule] ? Cannot create HollowMan: voidCenterZ=" ..tostring(voidCenterZ) ..", module=" ..tostring(HollowManHorrorAnimation ~= nil))
		end
		eyeParts, eyeLights = AnimationsModule.CreateStandardEyes(doorX, eyeY, eyeZ, eyeColor, doorFolder, MakePart)

		-- =========================================================================
		-- CRAWLER - 8 Eyes
		-- =========================================================================
	elseif normalizedEyeType == "CRAWLER_8EYES" or normalizedEyeType == "CRAWLER" then
		if voidCenterZ and CrawlerHorrorAnimation then
			print("[AnimationsModule] ? Creating CRAWLER horror animation")
			local success, result = pcall(function()
				return CrawlerHorrorAnimation.Create(
					doorX, eyeY, eyeZ, doorFolder, zDir, voidCenterZ, holeWidth or 7, holeHeight or 10
				)
			end)
			if success and result then
				horrorAnimator = result
				horrorDuration = CrawlerHorrorAnimation.TIMING.TOTAL_DURATION
				print("[AnimationsModule] ? Crawler horror duration: " ..horrorDuration)
			else
				warn("[AnimationsModule] ? Failed to create Crawler animation: " ..tostring(result))
			end
		else
			print("[AnimationsModule] ? Cannot create Crawler: voidCenterZ=" ..tostring(voidCenterZ) ..", module=" ..tostring(CrawlerHorrorAnimation ~= nil))
		end
		eyeParts, eyeLights = AnimationsModule.CreateStandardEyes(doorX, eyeY, eyeZ, eyeColor, doorFolder, MakePart)


	elseif normalizedEyeType == "SHADOW_MAN" or normalizedEyeType == "SHADOWMAN" then
		if voidCenterZ and ShadowManHorrorAnimation then
			print("[AnimationsModule] ??? Creating SHADOW MAN horror animation")
			local success, result = pcall(function()
				return ShadowManHorrorAnimation.Create(
					doorX, eyeY, eyeZ, doorFolder, zDir, voidCenterZ, holeWidth or 7, holeHeight or 10
				)
			end)
			if success and result then
				horrorAnimator = result
				horrorDuration = ShadowManHorrorAnimation.TIMING.TOTAL_DURATION
				print("[AnimationsModule] ??? Shadow Man horror duration: " ..horrorDuration)
			else
				warn("[AnimationsModule] ? Failed to create Shadow Man animation: " ..tostring(result))
			end
		else
			print("[AnimationsModule] ??? Cannot create Shadow Man: voidCenterZ=" ..tostring(voidCenterZ) ..", module=" ..tostring(ShadowManHorrorAnimation ~= nil))
		end
		eyeParts, eyeLights = AnimationsModule.CreateStandardEyes(doorX, eyeY, eyeZ, eyeColor, doorFolder, MakePart)
		
		-- =========================================================================
		-- PHANTOM - Ethereal Glow
		-- =========================================================================
	elseif normalizedEyeType == "PHANTOM_GLOW" or normalizedEyeType == "PHANTOM" then
		if voidCenterZ and PhantomHorrorAnimation then
			print("[AnimationsModule] ? Creating PHANTOM horror animation")
			local success, result = pcall(function()
				return PhantomHorrorAnimation.Create(
					doorX, eyeY, eyeZ, doorFolder, zDir, voidCenterZ
				)
			end)
			if success and result then
				horrorAnimator = result
				horrorDuration = PhantomHorrorAnimation.TIMING.TOTAL_DURATION
				print("[AnimationsModule] ? Phantom horror duration: " ..horrorDuration)
			else
				warn("[AnimationsModule] ? Failed to create Phantom animation: " ..tostring(result))
			end
		else
			print("[AnimationsModule] ? Cannot create Phantom: voidCenterZ=" ..tostring(voidCenterZ) ..", module=" ..tostring(PhantomHorrorAnimation ~= nil))
		end
		eyeParts, eyeLights = AnimationsModule.CreateStandardEyes(doorX, eyeY, eyeZ, eyeColor, doorFolder, MakePart)

		-- =========================================================================
		-- SCREAMER - Giant screaming creature
		-- =========================================================================
	elseif normalizedEyeType == "SCREAMER" then
		if voidCenterZ and ScreamerHorrorAnimation then
			print("[AnimationsModule] ? Creating SCREAMER horror animation")
			local success, result = pcall(function()
				return ScreamerHorrorAnimation.Create(
					doorX, eyeY, eyeZ, doorFolder, zDir, voidCenterZ, holeWidth or 10, holeHeight or 12
				)
			end)
			if success and result then
				horrorAnimator = result
				horrorDuration = ScreamerHorrorAnimation.TIMING.TOTAL_DURATION
				print("[AnimationsModule] ? Screamer horror duration: " ..horrorDuration)
			else
				warn("[AnimationsModule] ? Failed to create Screamer animation: " ..tostring(result))
			end
		else
			print("[AnimationsModule] ? Cannot create Screamer: voidCenterZ=" ..tostring(voidCenterZ) ..", module=" ..tostring(ScreamerHorrorAnimation ~= nil))
		end
		eyeParts, eyeLights = AnimationsModule.CreateStandardEyes(doorX, eyeY, eyeZ, eyeColor, doorFolder, MakePart)

		-- =========================================================================
		-- DEFAULT / UNKNOWN TYPE
		-- =========================================================================
	else
		print("[AnimationsModule] ? Unknown eyeType:  '" ..tostring(eyeType) .."' - Creating standard eyes only")
		eyeParts, eyeLights = AnimationsModule.CreateStandardEyes(doorX, eyeY, eyeZ, eyeColor, doorFolder, MakePart)
	end

	-- Create standard animator for fallback
	local standardAnimator = AnimationsModule.CreateEyeAnimator(eyeParts, eyeLights, eyeType)

	-- =========================================================================
	-- COMBINED ANIMATOR
	-- =========================================================================
	local combinedAnimator = {}

	function combinedAnimator.FadeInEyes()
		if horrorAnimator and horrorAnimator.PlayHorrorAnimation then
			print("[AnimationsModule] ? Playing horror animation for:  " ..tostring(eyeType))
			local success, err = pcall(function()
				horrorAnimator.PlayHorrorAnimation()
			end)
			if not success then
				warn("[AnimationsModule] ? Error playing horror animation: " ..tostring(err))
				standardAnimator.FadeInEyes()
			end
		else
			print("[AnimationsModule] ? Playing standard fade in for: " ..tostring(eyeType))
			standardAnimator.FadeInEyes()
		end
	end

	function combinedAnimator.FadeOutEyes()
		if horrorAnimator and horrorAnimator.Cleanup then
			print("[AnimationsModule] ? Cleaning up horror animation for: " ..tostring(eyeType))
			local success, err = pcall(function()
				horrorAnimator.Cleanup()
			end)
			if not success then
				warn("[AnimationsModule] ? Error cleaning up horror animation: " ..tostring(err))
			end
		else
			standardAnimator.FadeOutEyes()
		end
	end

	function combinedAnimator.BlinkEyes()
		if not horrorAnimator then
			standardAnimator.BlinkEyes()
		end
	end

	function combinedAnimator.GetHorrorDuration()
		print("[AnimationsModule] GetHorrorDuration called, returning: " ..horrorDuration)
		return horrorDuration
	end

	function combinedAnimator.SetLookTarget(targetPosition)
		if horrorAnimator and horrorAnimator.SetLookTarget then
			horrorAnimator.SetLookTarget(targetPosition)
		end
	end

	function combinedAnimator.IsHorrorPlaying()
		if horrorAnimator and horrorAnimator.IsPlaying then
			return horrorAnimator.IsPlaying()
		end
		return false
	end

	return eyeParts, eyeLights, combinedAnimator
end

-- -------------------------------------------------------------------------------
-- DEBUG: Print loaded modules
-- -------------------------------------------------------------------------------

function AnimationsModule.PrintLoadedModules()
	print("+-----------------------------------------------------------+")
	print("|         ANIMATIONS MODULE - HORROR MODULES STATUS         |")
	print("+-----------------------------------------------------------+")
	print("|  HollowManHorrorAnimation:  " ..(HollowManHorrorAnimation and "? LOADED" or "? NOT FOUND"))
	print("|  WatcherHorrorAnimation:    " ..(WatcherHorrorAnimation and "? LOADED" or "? NOT FOUND"))
	print("|  CrawlerHorrorAnimation:   " ..(CrawlerHorrorAnimation and "? LOADED" or "? NOT FOUND"))
	print("|  StitcherHorrorAnimation: " .. (StitcherHorrorAnimation and "LOADED" or "NOT FOUND"))
	print("|  PhantomHorrorAnimation:   " ..(PhantomHorrorAnimation and "? LOADED" or "? NOT FOUND"))
	print("|  ScreamerHorrorAnimation:  " ..(ScreamerHorrorAnimation and "? LOADED" or "? NOT FOUND"))
	print("|  HarvesterHorrorAnimation: " ..(HarvesterHorrorAnimation and "? LOADED" or "? NOT FOUND"))
	print("|  MinerHorrorAnimation:    " .. (MinerHorrorAnimation and "? LOADED" or "? NOT FOUND"))
	print("|  SlenderHorrorAnimation:   " ..(SlenderHorrorAnimation and "? LOADED" or "? NOT FOUND"))
	print("|  ShadowManHorrorAnimation: " ..(ShadowManHorrorAnimation and "? LOADED" or "? NOT FOUND"))
	print("+-----------------------------------------------------------+")
end

-- Reload modules function (useful for debugging)
function AnimationsModule.ReloadModules()
	print("[AnimationsModule] Reloading all horror modules...")
	LoadAllModules()
	AnimationsModule.PrintLoadedModules()
end

AnimationsModule.PrintLoadedModules()

return AnimationsModule