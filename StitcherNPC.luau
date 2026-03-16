--[[
    +------------------------------------------------------------------------------+
    |                    THE STITCHER - HORROR ENTITY SYSTEM                        |
    |                 VERSION 1.0 - "THE STITCHER" - SEWN NIGHTMARE                |
    |                   A crawling doll-like entity with needle fingers             |
    +------------------------------------------------------------------------------+
    
    The Stitcher: A horrifying doll-like creature made of sewn-together fabric
    and leather. It crawls and skitters along surfaces with needle-like fingers.
    Its button eyes blink desynchronized. Its mouth is stitched shut but it
    still makes muffled sounds. When it attacks, it "sews" damage into players
    with rapid needle strikes.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- ===============================================================================
-- WAIT FOR SPAWN EVENT
-- ===============================================================================

print("=== THE STITCHER SYSTEM LOADING ===")
print("Waiting for SpawnStitcherEvent...")

local SpawnStitcherEvent = ReplicatedStorage:WaitForChild("SpawnStitcherEvent", 15)

if SpawnStitcherEvent then
	print("[Stitcher] SpawnStitcherEvent FOUND!")
else
	warn("[Stitcher] SpawnStitcherEvent NOT FOUND after 15 seconds!")
end

-- -------------------------------------------------------------------------------
-- CONFIGURATION
-- -------------------------------------------------------------------------------

local STITCHER_CONFIG = {
	SCALE = 1.8,
	SPEED_STALK = 14,
	SPEED_CHASE = 28,
	SPEED_SKITTER = 38, -- burst speed when close
	DAMAGE = 30,
	ATTACK_COOLDOWN = 0.6,
	ATTACK_RANGE = 6,
	DETECTION_RANGE = 220,

	-- Body colors
	FABRIC_MAIN = Color3.fromRGB(65, 50, 40),     -- Dirty burlap
	FABRIC_PATCH = Color3.fromRGB(85, 60, 45),    -- Leather patches
	FABRIC_DARK = Color3.fromRGB(30, 22, 18),     -- Dark fabric
	STITCH_COLOR = Color3.fromRGB(20, 12, 8),     -- Dark thread
	STITCH_RED = Color3.fromRGB(80, 15, 10),      -- Bloody thread

	-- Button eyes
	BUTTON_LEFT = Color3.fromRGB(35, 30, 25),     -- Dark brown button
	BUTTON_RIGHT = Color3.fromRGB(25, 35, 30),    -- Dark green button (mismatched)
	BUTTON_SHINE = Color3.fromRGB(255, 240, 200),
	BUTTON_THREAD = Color3.fromRGB(160, 140, 100),

	-- Needle fingers
	NEEDLE_COLOR = Color3.fromRGB(190, 185, 180), -- Tarnished metal
	NEEDLE_TIP = Color3.fromRGB(220, 210, 200),

	-- Mouth
	MOUTH_STITCH = Color3.fromRGB(60, 10, 10),

	-- Effects
	THREAD_TRAIL_COLOR = Color3.fromRGB(15, 10, 8),
	STUFFING_COLOR = Color3.fromRGB(200, 190, 170), -- Cotton stuffing

	-- Body dimensions
	HEAD_SIZE = Vector3.new(1.0, 1.1, 0.9),
	TORSO_SIZE = Vector3.new(1.3, 1.8, 0.6),
	ARM_LENGTH = 2.8, -- Long arms for crawling
	LEG_LENGTH = 2.0, -- Shorter legs (crawls)

	-- Behavior
	SKITTER_CHANCE = 0.02,  -- Chance to do a quick skitter movement
	SKITTER_DURATION = 0.4,
	HEAD_COCK_CHANCE = 0.01, -- Cock head to side creepily
	HEAD_COCK_ANGLE = 45,
	STITCH_TEAR_CHANCE = 0.008, -- Chance to "tear" a stitch (visual glitch)

	LOBBY_START_X = -75,
	LOBBY_END_X = 75,
}

-- Apply scale
local S = STITCHER_CONFIG.SCALE
STITCHER_CONFIG.HEAD_SIZE = STITCHER_CONFIG.HEAD_SIZE * S
STITCHER_CONFIG.TORSO_SIZE = STITCHER_CONFIG.TORSO_SIZE * S
STITCHER_CONFIG.ARM_LENGTH = STITCHER_CONFIG.ARM_LENGTH * S
STITCHER_CONFIG.LEG_LENGTH = STITCHER_CONFIG.LEG_LENGTH * S

local function IsInLobby(x)
	return x >= STITCHER_CONFIG.LOBBY_START_X and x <= STITCHER_CONFIG.LOBBY_END_X
end

-- -------------------------------------------------------------------------------
-- UTILITIES
-- -------------------------------------------------------------------------------

local function CreatePart(name, size, color, material, transparency, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = true
	part.Parent = parent
	return part
end

local function CreateMesh(parent, meshType, scale)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = meshType or Enum.MeshType.Brick
	if scale then
		mesh.Scale = scale
	end
	mesh.Parent = parent
	return mesh
end

local function CreateBallPart(name, diameter, color, material, parent)
	local part = CreatePart(name, Vector3.new(diameter, diameter, diameter), color, material, 0, parent)
	part.Shape = Enum.PartType.Ball
	return part
end

local function Lerp(a, b, t)
	return a + (b - a) * t
end

local function LerpColor(c1, c2, t)
	return Color3.new(
		c1.R + (c2.R - c1.R) * t,
		c1.G + (c2.G - c1.G) * t,
		c1.B + (c2.B - c1.B) * t
	)
end

-- -------------------------------------------------------------------------------
-- CREATE THE STITCHER NPC
-- -------------------------------------------------------------------------------

local function CreateStitcherNPC(spawnPosition, triggerPlayer, side, zDir, doorFrameInfo, lifetime)
	local npcLifetime = lifetime
	if not npcLifetime or npcLifetime <= 0 then
		npcLifetime = 50
	end

	print("===========================================")
	print("    THE STITCHER SPAWNED")
	print("   Scale: " .. S .. "x")
	print("   Lifetime: " .. npcLifetime .. " seconds")
	print("   Position: " .. tostring(spawnPosition))
	print("===========================================")

	local npcFolder = Instance.new("Folder")
	npcFolder.Name = "StitcherEntity"
	npcFolder.Parent = workspace

	local npcModel = Instance.new("Model")
	npcModel.Name = "TheStitcher"
	npcModel.Parent = npcFolder

	local spawnTime = tick()
	npcFolder:SetAttribute("SpawnTime", spawnTime)
	npcFolder:SetAttribute("Lifetime", npcLifetime)
	npcModel:SetAttribute("SpawnTime", spawnTime)
	npcModel:SetAttribute("Lifetime", npcLifetime)

	local groundY = 0.5

	-- ---------------------------------------------------------------------------
	-- TORSO - Lumpy sewn fabric body
	-- ---------------------------------------------------------------------------
	local torso = CreatePart(
		"Torso",
		STITCHER_CONFIG.TORSO_SIZE,
		STITCHER_CONFIG.FABRIC_MAIN,
		Enum.Material.Fabric,
		0,
		npcModel
	)
	torso.CanCollide = true
	CreateMesh(torso, Enum.MeshType.Sphere, Vector3.new(1, 1.1, 0.7))

	-- Patches on torso
	local patches = {}
	local patchConfigs = {
		{x = 0.3, y = 0.2, z = -0.25, sx = 0.4, sy = 0.5, rot = 15},
		{x = -0.2, y = -0.3, z = -0.22, sx = 0.35, sy = 0.3, rot = -20},
		{x = 0.0, y = 0.4, z = -0.28, sx = 0.5, sy = 0.25, rot = 8},
		{x = -0.35, y = 0.1, z = 0.2, sx = 0.3, sy = 0.4, rot = -12},
	}

	for i, pcfg in ipairs(patchConfigs) do
		local patch = CreatePart(
			"Patch" .. i,
			Vector3.new(pcfg.sx * S, pcfg.sy * S, 0.05 * S),
			STITCHER_CONFIG.FABRIC_PATCH,
			Enum.Material.Fabric,
			0,
			npcModel
		)
		table.insert(patches, {part = patch, config = pcfg})
	end

	-- Stitching lines on torso
	local stitchLines = {}
	for i = 1, 6 do
		local stitch = CreatePart(
			"TorsoStitch" .. i,
			Vector3.new(0.03 * S, 0.3 * S + math.random() * 0.2 * S, 0.02 * S),
			(i % 3 == 0) and STITCHER_CONFIG.STITCH_RED or STITCHER_CONFIG.STITCH_COLOR,
			Enum.Material.Fabric,
			0,
			npcModel
		)
		table.insert(stitchLines, {
			part = stitch,
			xOff = (math.random() - 0.5) * 0.8 * S,
			yOff = (math.random() - 0.5) * 1.0 * S,
			angle = (math.random() - 0.5) * math.rad(40),
		})
	end

	-- Pelvis area
	local pelvis = CreatePart(
		"Pelvis",
		Vector3.new(0.9 * S, 0.5 * S, 0.4 * S),
		STITCHER_CONFIG.FABRIC_DARK,
		Enum.Material.Fabric,
		0,
		npcModel
	)
	CreateMesh(pelvis, Enum.MeshType.Sphere, Vector3.new(1, 0.7, 0.8))

	-- ---------------------------------------------------------------------------
	-- NECK - Stitched together
	-- ---------------------------------------------------------------------------
	local neckParts = {}
	for i = 1, 3 do
		local seg = CreatePart(
			"NeckSeg" .. i,
			Vector3.new((0.25 - i * 0.02) * S, 0.12 * S, (0.25 - i * 0.02) * S),
			STITCHER_CONFIG.FABRIC_MAIN,
			Enum.Material.Fabric,
			0,
			npcModel
		)
		CreateMesh(seg, Enum.MeshType.Cylinder)

		-- Neck stitch ring
		local ring = CreatePart(
			"NeckRing" .. i,
			Vector3.new(0.28 * S, 0.03 * S, 0.28 * S),
			STITCHER_CONFIG.STITCH_COLOR,
			Enum.Material.Fabric,
			0,
			npcModel
		)

		table.insert(neckParts, {segment = seg, ring = ring, index = i})
	end

	-- ---------------------------------------------------------------------------
	-- HEAD - Deformed stitched doll head
	-- ---------------------------------------------------------------------------
	local head = CreatePart(
		"Head",
		STITCHER_CONFIG.HEAD_SIZE,
		STITCHER_CONFIG.FABRIC_MAIN,
		Enum.Material.Fabric,
		0,
		npcModel
	)
	CreateMesh(head, Enum.MeshType.Sphere, Vector3.new(1, 1.1, 0.9))

	-- Head seam (visible stitch line down the center)
	local headSeam = CreatePart(
		"HeadSeam",
		Vector3.new(0.03 * S, STITCHER_CONFIG.HEAD_SIZE.Y * 0.9, 0.05 * S),
		STITCHER_CONFIG.STITCH_RED,
		Enum.Material.Fabric,
		0,
		npcModel
	)

	-- Cross stitches on seam
	local seamStitches = {}
	for i = 1, 5 do
		local cs = CreatePart(
			"SeamStitch" .. i,
			Vector3.new(0.12 * S, 0.02 * S, 0.02 * S),
			STITCHER_CONFIG.STITCH_COLOR,
			Enum.Material.Fabric,
			0,
			npcModel
		)
		table.insert(seamStitches, {part = cs, index = i})
	end

	-- ---------------------------------------------------------------------------
	-- BUTTON EYES - Mismatched and sewn on
	-- ---------------------------------------------------------------------------
	local eyes = {}
	local eyeConfigs = {
		-- Left: bigger, brown, 4-hole, slightly drooping
		{x = -0.22, y = 0.15, z = -0.45, size = 0.20, color = STITCHER_CONFIG.BUTTON_LEFT, holes = 4, droop = 0},
		-- Right: smaller, green-ish, 2-hole, tilted
		{x = 0.24, y = 0.2, z = -0.43, size = 0.15, color = STITCHER_CONFIG.BUTTON_RIGHT, holes = 2, droop = 0},
	}

	for i, cfg in ipairs(eyeConfigs) do
		local button = Instance.new("Part")
		button.Name = "ButtonEye" .. i
		button.Shape = Enum.PartType.Cylinder
		button.Size = Vector3.new(0.04 * S, cfg.size * S, cfg.size * S)
		button.Color = cfg.color
		button.Material = Enum.Material.SmoothPlastic
		button.Anchored = true
		button.CanCollide = false
		button.CastShadow = false
		button.Parent = npcModel

		local rim = Instance.new("Part")
		rim.Name = "ButtonRim" .. i
		rim.Shape = Enum.PartType.Cylinder
		rim.Size = Vector3.new(0.02 * S, (cfg.size + 0.03) * S, (cfg.size + 0.03) * S)
		rim.Color = LerpColor(cfg.color, Color3.new(0, 0, 0), 0.3)
		rim.Material = Enum.Material.SmoothPlastic
		rim.Anchored = true
		rim.CanCollide = false
		rim.CastShadow = false
		rim.Parent = npcModel

		-- Thread through holes
		local holeThreads = {}
		for h = 1, cfg.holes do
			local t = CreatePart(
				"EyeThread" .. i .. "_" .. h,
				Vector3.new(cfg.size * 0.5 * S, 0.02 * S, 0.02 * S),
				STITCHER_CONFIG.BUTTON_THREAD,
				Enum.Material.Fabric,
				0,
				npcModel
			)
			table.insert(holeThreads, t)
		end

		-- Dangling thread (loose thread from sewing)
		local dangleThread = CreatePart(
			"DangleThread" .. i,
			Vector3.new(0.015 * S, 0.15 * S, 0.015 * S),
			STITCHER_CONFIG.BUTTON_THREAD,
			Enum.Material.Fabric,
			0,
			npcModel
		)

		-- Light behind button
		local eyeLight = Instance.new("PointLight")
		eyeLight.Color = STITCHER_CONFIG.BUTTON_SHINE
		eyeLight.Brightness = 1.5
		eyeLight.Range = 8 * S
		eyeLight.Shadows = true
		eyeLight.Parent = button

		-- Shine reflection
		local shine = CreateBallPart(
			"Shine" .. i,
			cfg.size * 0.12 * S,
			STITCHER_CONFIG.BUTTON_SHINE,
			Enum.Material.Neon,
			npcModel
		)

		table.insert(eyes, {
			button = button,
			rim = rim,
			holeThreads = holeThreads,
			dangleThread = dangleThread,
			shine = shine,
			light = eyeLight,
			config = cfg,
			blinkCooldown = 2.0 + math.random() * 4.0,
			isOpen = true,
			lookOffset = {x = 0, y = 0},
		})
	end

	-- ---------------------------------------------------------------------------
	-- STITCHED MOUTH - Sewn shut with visible thread
	-- ---------------------------------------------------------------------------
	local mouthLine = CreatePart(
		"MouthLine",
		Vector3.new(0.4 * S, 0.03 * S, 0.03 * S),
		STITCHER_CONFIG.MOUTH_STITCH,
		Enum.Material.Fabric,
		0,
		npcModel
	)

	local mouthStitches = {}
	for i = 1, 8 do
		local ms = CreatePart(
			"MouthStitch" .. i,
			Vector3.new(0.025 * S, 0.1 * S, 0.02 * S),
			STITCHER_CONFIG.STITCH_RED,
			Enum.Material.Fabric,
			0,
			npcModel
		)
		table.insert(mouthStitches, {
			part = ms,
			index = i,
			xOff = (i - 4.5) * 0.045 * S,
		})
	end

	-- ---------------------------------------------------------------------------
	-- ARMS - Long, with needle fingers
	-- ---------------------------------------------------------------------------
	local arms = {}
	for sideVal = -1, 1, 2 do
		local armFolder = Instance.new("Folder")
		armFolder.Name = sideVal == -1 and "LeftArm" or "RightArm"
		armFolder.Parent = npcModel

		local shoulder = CreateBallPart("Shoulder", 0.22 * S, STITCHER_CONFIG.FABRIC_MAIN, Enum.Material.Fabric, armFolder)

		-- Seam on shoulder
		local shoulderSeam = CreatePart("ShoulderSeam", Vector3.new(0.25 * S, 0.02 * S, 0.02 * S),
			STITCHER_CONFIG.STITCH_COLOR, Enum.Material.Fabric, 0, armFolder)

		local armSegments = {}
		for i = 1, 4 do
			local segWidth = (0.13 - i * 0.012) * S
			local seg = CreatePart(
				"ArmSeg" .. i,
				Vector3.new(segWidth, STITCHER_CONFIG.ARM_LENGTH / 4, segWidth),
				(i % 2 == 0) and STITCHER_CONFIG.FABRIC_PATCH or STITCHER_CONFIG.FABRIC_MAIN,
				Enum.Material.Fabric,
				0,
				armFolder
			)
			CreateMesh(seg, Enum.MeshType.Cylinder)
			table.insert(armSegments, {part = seg, index = i, delayedAngle = 0, targetAngle = 0})
		end

		-- Wrist ball
		local wrist = CreateBallPart("Wrist", 0.08 * S, STITCHER_CONFIG.FABRIC_DARK, Enum.Material.Fabric, armFolder)

		-- Hand - fabric palm
		local hand = CreatePart(
			"Hand",
			Vector3.new(0.35 * S, 0.45 * S, 0.1 * S),
			STITCHER_CONFIG.FABRIC_MAIN,
			Enum.Material.Fabric,
			0,
			armFolder
		)
		CreateMesh(hand, Enum.MeshType.Sphere, Vector3.new(1, 1.2, 0.3))

		-- NEEDLE FINGERS - 5 per hand, metallic needles
		local fingers = {}
		for f = 1, 5 do
			-- Fabric finger base
			local fingerBase = CreatePart(
				"FingerBase" .. f,
				Vector3.new(0.03 * S, 0.15 * S, 0.025 * S),
				STITCHER_CONFIG.FABRIC_DARK,
				Enum.Material.Fabric,
				0,
				armFolder
			)

			-- Metal needle extension
			local needle = CreatePart(
				"Needle" .. f,
				Vector3.new(0.015 * S, 0.35 * S, 0.015 * S),
				STITCHER_CONFIG.NEEDLE_COLOR,
				Enum.Material.Metal,
				0,
				armFolder
			)

			-- Needle tip (sharper, lighter)
			local tip = CreatePart(
				"NeedleTip" .. f,
				Vector3.new(0.008 * S, 0.08 * S, 0.008 * S),
				STITCHER_CONFIG.NEEDLE_TIP,
				Enum.Material.Metal,
				0,
				armFolder
			)
			CreateMesh(tip, Enum.MeshType.Wedge, Vector3.new(0.5, 1, 0.5))

			table.insert(fingers, {
				base = fingerBase,
				needle = needle,
				tip = tip,
				index = f,
				xOff = (f - 3) * 0.06 * S,
				curlPhase = math.random() * math.pi,
				twitchTimer = 0,
			})
		end

		table.insert(arms, {
			folder = armFolder,
			shoulder = shoulder,
			shoulderSeam = shoulderSeam,
			segments = armSegments,
			wrist = wrist,
			hand = hand,
			fingers = fingers,
			side = sideVal,
			swingAngle = 0,
			delayedSwing = 0,
			attackAngle = 0,
		})
	end

	-- ---------------------------------------------------------------------------
	-- LEGS - Shorter, for crawling posture
	-- ---------------------------------------------------------------------------
	local legs = {}
	for sideVal = -1, 1, 2 do
		local legFolder = Instance.new("Folder")
		legFolder.Name = sideVal == -1 and "LeftLeg" or "RightLeg"
		legFolder.Parent = npcModel

		local hip = CreateBallPart("Hip", 0.2 * S, STITCHER_CONFIG.FABRIC_MAIN, Enum.Material.Fabric, legFolder)
		local thigh = CreatePart("Thigh", Vector3.new(0.18 * S, STITCHER_CONFIG.LEG_LENGTH * 0.5, 0.18 * S),
			STITCHER_CONFIG.FABRIC_DARK, Enum.Material.Fabric, 0, legFolder)
		CreateMesh(thigh, Enum.MeshType.Cylinder)
		local knee = CreateBallPart("Knee", 0.15 * S, STITCHER_CONFIG.FABRIC_PATCH, Enum.Material.Fabric, legFolder)
		local shin = CreatePart("Shin", Vector3.new(0.15 * S, STITCHER_CONFIG.LEG_LENGTH * 0.45, 0.15 * S),
			STITCHER_CONFIG.FABRIC_MAIN, Enum.Material.Fabric, 0, legFolder)
		CreateMesh(shin, Enum.MeshType.Cylinder)
		local ankle = CreateBallPart("Ankle", 0.1 * S, STITCHER_CONFIG.FABRIC_DARK, Enum.Material.Fabric, legFolder)
		local foot = CreatePart("Foot", Vector3.new(0.18 * S, 0.08 * S, 0.4 * S),
			STITCHER_CONFIG.FABRIC_DARK, Enum.Material.Fabric, 0, legFolder)
		CreateMesh(foot, Enum.MeshType.Sphere, Vector3.new(0.6, 0.4, 1.5))

		table.insert(legs, {
			folder = legFolder,
			hip = hip,
			thigh = thigh,
			knee = knee,
			shin = shin,
			ankle = ankle,
			foot = foot,
			side = sideVal,
			swingAngle = 0,
		})
	end

	-- Shadow
	local shadow = CreatePart("Shadow", Vector3.new(2.5 * S, 0.05, 2.5 * S),
		Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, 0.5, npcModel)
	shadow.CastShadow = false

	-- ---------------------------------------------------------------------------
	-- PARTICLES & EFFECTS
	-- ---------------------------------------------------------------------------

	-- Thread trail emitter (leaves dark threads behind)
	local threadTrail = Instance.new("ParticleEmitter")
	threadTrail.Texture = "rbxassetid://243098098"
	threadTrail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, STITCHER_CONFIG.THREAD_TRAIL_COLOR),
		ColorSequenceKeypoint.new(1, STITCHER_CONFIG.STITCH_COLOR),
	})
	threadTrail.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05 * S),
		NumberSequenceKeypoint.new(0.5, 0.15 * S),
		NumberSequenceKeypoint.new(1, 0),
	})
	threadTrail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	threadTrail.Lifetime = NumberRange.new(1, 3)
	threadTrail.Rate = 8
	threadTrail.Speed = NumberRange.new(0.1, 0.5)
	threadTrail.SpreadAngle = Vector2.new(180, 180)
	threadTrail.Parent = torso

	-- Stuffing particles (cotton puffs leak out occasionally)
	local stuffingEmitter = Instance.new("ParticleEmitter")
	stuffingEmitter.Texture = "rbxassetid://243098098"
	stuffingEmitter.Color = ColorSequence.new(STITCHER_CONFIG.STUFFING_COLOR)
	stuffingEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1 * S),
		NumberSequenceKeypoint.new(0.5, 0.2 * S),
		NumberSequenceKeypoint.new(1, 0.05 * S),
	})
	stuffingEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	stuffingEmitter.Lifetime = NumberRange.new(0.5, 1.5)
	stuffingEmitter.Rate = 0 -- Burst only
	stuffingEmitter.Speed = NumberRange.new(1, 3)
	stuffingEmitter.SpreadAngle = Vector2.new(90, 90)
	stuffingEmitter.Parent = torso

	-- Ambient dark light
	local ambientLight = Instance.new("PointLight")
	ambientLight.Color = STITCHER_CONFIG.FABRIC_DARK
	ambientLight.Brightness = -0.3
	ambientLight.Range = 12 * S
	ambientLight.Shadows = false
	ambientLight.Parent = torso

	-- ---------------------------------------------------------------------------
	-- ANIMATION VARIABLES
	-- ---------------------------------------------------------------------------
	local npcX = spawnPosition.X
	local npcZ = spawnPosition.Z
	local npcRotation = zDir > 0 and 0 or math.pi

	local walkTime = 0
	local breathTime = 0
	local isWalking = false
	local isAttacking = false
	local isSkittering = false
	local skitterTimer = 0

	local headCockAngle = 0
	local headCockTarget = 0
	local headCockCooldown = 0

	-- ---------------------------------------------------------------------------
	-- UPDATE NPC POSITION (ANIMATION LOOP)
	-- ---------------------------------------------------------------------------
	local function UpdateNPCPosition(x, z, rotY, walking, deltaTime, targetDistance, targetPos)
		npcX = x
		npcZ = z
		npcRotation = rotY or npcRotation
		isWalking = walking or false

		if deltaTime then
			if isWalking then
				local speedMult = isSkittering and 2.5 or 1.0
				walkTime = walkTime + deltaTime * 8 * speedMult
			end
			breathTime = breathTime + deltaTime * 1.2

			if headCockCooldown > 0 then headCockCooldown = headCockCooldown - deltaTime end
			if skitterTimer > 0 then skitterTimer = skitterTimer - deltaTime end
			if skitterTimer <= 0 then isSkittering = false end
		end

		-- Head cock behavior
		if not isAttacking and headCockCooldown <= 0 and math.random() < STITCHER_CONFIG.HEAD_COCK_CHANCE then
			if targetDistance and targetDistance < 35 and targetDistance > 10 then
				headCockTarget = (math.random() > 0.5 and 1 or -1) * math.rad(STITCHER_CONFIG.HEAD_COCK_ANGLE)
				headCockCooldown = 3.0 + math.random() * 4.0
				task.delay(0.8 + math.random() * 1.0, function()
					headCockTarget = 0
				end)
			end
		end
		headCockAngle = Lerp(headCockAngle, headCockTarget, (deltaTime or 0.016) * 3)

		-- Skitter trigger
		if isWalking and not isSkittering and skitterTimer <= 0 and math.random() < STITCHER_CONFIG.SKITTER_CHANCE then
			if targetDistance and targetDistance < 25 then
				isSkittering = true
				skitterTimer = STITCHER_CONFIG.SKITTER_DURATION
			end
		end

		-- Stitch tear effect
		if math.random() < STITCHER_CONFIG.STITCH_TEAR_CHANCE then
			stuffingEmitter:Emit(3)
		end

		-- Base calculations
		local breathScale = 1 + math.sin(breathTime * math.pi) * 0.015
		local walkBob = isWalking and math.sin(walkTime * 2) * 0.06 * S or 0
		local walkSway = isWalking and math.sin(walkTime) * 0.025 or 0

		-- Crawling posture: lower body height
		local legTotalLength = STITCHER_CONFIG.LEG_LENGTH * 0.7
		local baseHeight = groundY + legTotalLength + 0.3 * S
		local torsoY = baseHeight + walkBob
		local pelvisY = torsoY - 1.0 * S

		-- Crawling lean forward
		local crawlLean = isWalking and math.rad(-15) or math.rad(-5)

		local baseCFrame = CFrame.new(x + walkSway, torsoY, z)
			* CFrame.Angles(0, npcRotation, walkSway * 0.5)
			* CFrame.Angles(crawlLean, 0, 0)

		-- TORSO
		torso.CFrame = baseCFrame
		torso.Size = STITCHER_CONFIG.TORSO_SIZE * Vector3.new(breathScale, 1, breathScale)

		-- Patches follow torso
		for _, patchData in ipairs(patches) do
			local pcfg = patchData.config
			patchData.part.CFrame = baseCFrame
				* CFrame.new(pcfg.x * S, pcfg.y * S, pcfg.z * S)
				* CFrame.Angles(0, 0, math.rad(pcfg.rot))
		end

		-- Stitch lines follow torso
		for _, sl in ipairs(stitchLines) do
			sl.part.CFrame = baseCFrame
				* CFrame.new(sl.xOff, sl.yOff, -STITCHER_CONFIG.TORSO_SIZE.Z * 0.45)
				* CFrame.Angles(0, 0, sl.angle)
		end

		pelvis.CFrame = baseCFrame * CFrame.new(0, -1.0 * S, 0)

		-- NECK
		local neckBaseCFrame = baseCFrame * CFrame.new(0, STITCHER_CONFIG.TORSO_SIZE.Y * 0.4, -0.1 * S)
		for i, neckData in ipairs(neckParts) do
			local t = i / #neckParts
			local neckSway = math.sin(breathTime * 1.2 + i * 0.4) * math.rad(3)
			local neckCF = neckBaseCFrame * CFrame.new(0, t * 0.4 * S, 0) * CFrame.Angles(neckSway, 0, 0)
			neckData.segment.CFrame = neckCF * CFrame.Angles(0, 0, math.rad(90))
			neckData.ring.CFrame = neckCF
		end

		-- HEAD
		local lastNeck = neckParts[#neckParts]
		local headTilt = math.sin(breathTime * 0.6) * math.rad(2)
		local headCFrame = lastNeck.segment.CFrame
			* CFrame.Angles(0, 0, -math.rad(90))
			* CFrame.new(0, 0.45 * S, 0)
			* CFrame.Angles(headTilt, 0, headCockAngle)

		head.CFrame = headCFrame

		-- Head seam
		headSeam.CFrame = headCFrame * CFrame.new(0, 0, -STITCHER_CONFIG.HEAD_SIZE.Z * 0.42)

		-- Seam cross stitches
		for _, ss in ipairs(seamStitches) do
			local yOff = (ss.index - 3) * 0.15 * S
			ss.part.CFrame = headCFrame * CFrame.new(0, yOff, -STITCHER_CONFIG.HEAD_SIZE.Z * 0.43)
		end

		-- BUTTON EYES
		for _, eyeData in ipairs(eyes) do
			local cfg = eyeData.config
			local lookX, lookY = 0, 0

			if targetPos then
				local toTarget = (targetPos - headCFrame.Position)
				if toTarget.Magnitude > 0.5 then
					local localTarget = headCFrame:PointToObjectSpace(targetPos)
					lookX = math.clamp(localTarget.X * 0.01, -0.02 * S, 0.02 * S)
					lookY = math.clamp(localTarget.Y * 0.01, -0.015 * S, 0.015 * S)
				end
			end

			-- Posicionar el ojo pegado a la cara mirando hacia enfrente
			-- El cilindro debe quedar con su eje apuntando hacia afuera de la cara (eje Z local de la cabeza)
			local eyeCFrame = headCFrame
				* CFrame.new(cfg.x * S + lookX, cfg.y * S + lookY, cfg.z * S)
				* CFrame.Angles(0, math.rad(90), 0) -- Rotar para que el cilindro apunte hacia enfrente (eje Z)

			eyeData.button.CFrame = eyeCFrame
			eyeData.rim.CFrame = eyeCFrame * CFrame.new(0, 0, 0.02 * S) -- Rim ligeramente detrás
			eyeData.shine.CFrame = eyeCFrame * CFrame.new(cfg.size * 0.2 * S, cfg.size * 0.15 * S, -0.03 * S) -- Brillo al frente

			-- Thread through holes
			for h, thr in ipairs(eyeData.holeThreads) do
				local angle = (h - 1) * (180 / #eyeData.holeThreads)
				thr.CFrame = eyeCFrame * CFrame.Angles(0, 0, math.rad(angle))
			end

			-- Dangling thread sways
			local dangleSway = math.sin(breathTime * 2 + cfg.x * 10) * math.rad(15)
			eyeData.dangleThread.CFrame = eyeCFrame
				* CFrame.new(0, -cfg.size * 0.5 * S, 0)
				* CFrame.Angles(dangleSway, 0, 0)
				* CFrame.new(0, -0.07 * S, 0)

			-- DESYNCHRONIZED BLINKING
			if deltaTime then
				eyeData.blinkCooldown = eyeData.blinkCooldown - deltaTime
				if eyeData.blinkCooldown <= 0 and eyeData.isOpen then
					eyeData.blinkCooldown = 1.5 + math.random() * 5.0
					eyeData.isOpen = false
					eyeData.button.Transparency = 0.85
					eyeData.shine.Transparency = 1
					eyeData.light.Brightness = 0.2

					local blinkDuration = 0.04 + math.random() * 0.1
					task.delay(blinkDuration, function()
						if eyeData.button and eyeData.button.Parent then
							eyeData.isOpen = true
							eyeData.button.Transparency = 0
							eyeData.shine.Transparency = 0.3
							eyeData.light.Brightness = 1.5
						end
					end)
				end
			end
		end

		-- STITCHED MOUTH
		local mouthY = -STITCHER_CONFIG.HEAD_SIZE.Y * 0.3
		mouthLine.CFrame = headCFrame * CFrame.new(0.02 * S, mouthY, -STITCHER_CONFIG.HEAD_SIZE.Z * 0.43)

		for _, ms in ipairs(mouthStitches) do
			local stitchAngle = (ms.index % 2 == 0) and math.rad(12) or math.rad(-12)
			ms.part.CFrame = headCFrame
				* CFrame.new(0.02 * S + ms.xOff, mouthY, -STITCHER_CONFIG.HEAD_SIZE.Z * 0.44)
				* CFrame.Angles(0, 0, stitchAngle)
		end

		-- ARMS
		for _, arm in ipairs(arms) do
			local armPhase = walkTime + arm.side * math.pi * 0.5
			local targetSwing = isWalking and math.sin(armPhase) * math.rad(35) or 0
			arm.delayedSwing = Lerp(arm.delayedSwing, targetSwing, (deltaTime or 0.016) * 5)

			local shoulderX = arm.side * STITCHER_CONFIG.TORSO_SIZE.X * 0.55
			local shoulderY = STITCHER_CONFIG.TORSO_SIZE.Y * 0.3
			arm.shoulder.CFrame = baseCFrame * CFrame.new(shoulderX, shoulderY, 0)
			arm.shoulderSeam.CFrame = arm.shoulder.CFrame

			local prevCFrame = arm.shoulder.CFrame
			local segLength = STITCHER_CONFIG.ARM_LENGTH / #arm.segments

			for i, seg in ipairs(arm.segments) do
				seg.targetAngle = arm.delayedSwing * (1 - i * 0.1) + arm.attackAngle * (i / #arm.segments)
				seg.delayedAngle = Lerp(seg.delayedAngle, seg.targetAngle, (deltaTime or 0.016) * (6 - i * 0.5))
				local segWave = math.sin(breathTime * 1.8 + i * 0.6) * math.rad(2)
				local segPitch = math.rad(-12) + seg.delayedAngle + segWave
				local segRoll = arm.side * math.rad(12 + i * 4)
				local segCFrame = prevCFrame * CFrame.Angles(segPitch, 0, segRoll) * CFrame.new(0, -segLength * 0.5, 0)
				seg.part.CFrame = segCFrame * CFrame.Angles(0, 0, math.rad(90))
				prevCFrame = segCFrame * CFrame.new(0, -segLength * 0.5, 0)
			end

			arm.wrist.CFrame = prevCFrame
			local handWave = math.sin(breathTime * 1.3 + arm.side * 2) * math.rad(6)
			local handCFrame = prevCFrame * CFrame.Angles(handWave, 0, arm.side * math.rad(4)) * CFrame.new(0, -0.2 * S, 0)
			arm.hand.CFrame = handCFrame

			-- NEEDLE FINGERS
			local baseCurl = math.rad(25)
			for _, finger in ipairs(arm.fingers) do
				local curl = baseCurl + math.sin(breathTime + finger.curlPhase) * math.rad(10)

				-- Twitch individual fingers randomly
				if deltaTime then
					finger.twitchTimer = finger.twitchTimer - deltaTime
					if finger.twitchTimer <= 0 and math.random() < 0.005 then
						finger.twitchTimer = 0.1
						curl = curl + math.rad(40)
					end
				end

				local fingerBase = handCFrame * CFrame.new(finger.xOff, -0.2 * S, 0)

				-- Fabric base
				local baseCF = fingerBase * CFrame.Angles(curl, 0, 0) * CFrame.new(0, -0.075 * S, 0)
				finger.base.CFrame = baseCF

				-- Needle
				local needleCF = baseCF * CFrame.Angles(curl * 0.5, 0, 0) * CFrame.new(0, -0.175 * S, 0)
				finger.needle.CFrame = needleCF

				-- Needle tip
				finger.tip.CFrame = needleCF * CFrame.new(0, -0.175 * S - 0.04 * S, 0)
			end
		end

		-- LEGS
		local thighLength = STITCHER_CONFIG.LEG_LENGTH * 0.5
		local shinLength = STITCHER_CONFIG.LEG_LENGTH * 0.45

		for _, leg in ipairs(legs) do
			local legPhase = walkTime + (leg.side == -1 and 0 or math.pi)
			local legSwing = isWalking and math.sin(legPhase) * math.rad(25) or 0

			local hipX = leg.side * 0.35 * S
			local hipY = pelvisY - 0.05 * S
			leg.hip.CFrame = baseCFrame * CFrame.new(hipX, -0.8 * S, 0)

			local thighCFrame = CFrame.new(x + hipX + walkSway, hipY, z)
				* CFrame.Angles(0, npcRotation, 0)
				* CFrame.Angles(crawlLean, 0, 0)
				* CFrame.Angles(legSwing, 0, leg.side * math.rad(3))
				* CFrame.new(0, -thighLength * 0.5, 0)
			leg.thigh.CFrame = thighCFrame * CFrame.Angles(0, 0, math.rad(90))

			local kneePos = thighCFrame * CFrame.new(0, -thighLength * 0.5, 0)
			leg.knee.CFrame = CFrame.new(kneePos.Position)

			local shinAngle = math.rad(-8) - legSwing * 0.4
			local shinCFrame = kneePos * CFrame.Angles(shinAngle, 0, 0) * CFrame.new(0, -shinLength * 0.5, 0)
			leg.shin.CFrame = shinCFrame * CFrame.Angles(0, 0, math.rad(90))

			local anklePos = shinCFrame * CFrame.new(0, -shinLength * 0.5, 0)
			leg.ankle.CFrame = CFrame.new(anklePos.Position)

			local walkLift = isWalking and math.max(0, math.sin(legPhase)) * 0.1 * S or 0
			local footY = groundY + 0.04 * S + walkLift
			local footForward = isWalking and math.sin(legPhase) * 0.25 * S or 0
			leg.foot.CFrame = CFrame.new(x + hipX + walkSway, footY, z + footForward)
				* CFrame.Angles(0, npcRotation, 0)
		end

		-- SHADOW
		shadow.CFrame = CFrame.new(x, groundY + 0.02, z)
		shadow.Size = Vector3.new(2.5 * S, 0.05, 2.5 * S)
	end

	-- Initial position
	UpdateNPCPosition(npcX, npcZ, npcRotation, false, 0, 999, nil)

	-- ---------------------------------------------------------------------------
	-- SOUNDS
	-- ---------------------------------------------------------------------------
	local spawnSound = Instance.new("Sound")
	spawnSound.SoundId = "rbxassetid://9114120101"
	spawnSound.Volume = 0.8
	spawnSound.PlaybackSpeed = 0.6
	spawnSound.Parent = torso
	spawnSound:Play()

	local ambientSound = Instance.new("Sound")
	ambientSound.SoundId = "rbxassetid://79261984390684"
	ambientSound.Volume = 0.25
	ambientSound.Looped = true
	ambientSound.PlaybackSpeed = 0.7
	ambientSound.Parent = head
	ambientSound:Play()

	-- Clicking/tapping sound for needle fingers
	local clickSound = Instance.new("Sound")
	clickSound.SoundId = "rbxassetid://9114221580"
	clickSound.Volume = 0.3
	clickSound.Looped = true
	clickSound.PlaybackSpeed = 1.5
	clickSound.Parent = torso

	local isChasing = false

	-- ---------------------------------------------------------------------------
	-- ATTACK ANIMATION
	-- ---------------------------------------------------------------------------
	local function PlayAttackAnimation(targetPosition)
		if isAttacking then return end
		isAttacking = true

		-- Eyes flash
		for _, eyeData in ipairs(eyes) do
			if eyeData.light then
				TweenService:Create(eyeData.light, TweenInfo.new(0.08), {
					Brightness = 8,
					Color = Color3.fromRGB(255, 80, 60),
				}):Play()
			end
		end

		-- Stuffing burst from attack force
		stuffingEmitter:Emit(5)

		-- Attack sound
		local attackSound = Instance.new("Sound")
		attackSound.SoundId = "rbxassetid://5766332557"
		attackSound.Volume = 0.7
		attackSound.PlaybackSpeed = 1.2
		attackSound.Parent = torso
		attackSound:Play()

		-- Rapid needle strike (both arms forward then back)
		for _, arm in ipairs(arms) do arm.attackAngle = math.rad(-60) end
		task.wait(0.1)
		for _, arm in ipairs(arms) do arm.attackAngle = math.rad(50) end

		-- Slash effect
		local slashEffect = CreatePart("SlashEffect", Vector3.new(0.1, 0.1, 0.1),
			STITCHER_CONFIG.NEEDLE_TIP, Enum.Material.Neon, 0.3, workspace)
		slashEffect.Position = Vector3.new(npcX, groundY + 1.5 * S, npcZ)
			+ (CFrame.Angles(0, npcRotation, 0).LookVector * 1.8 * S)

		local slashParticles = Instance.new("ParticleEmitter")
		slashParticles.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, STITCHER_CONFIG.NEEDLE_COLOR),
			ColorSequenceKeypoint.new(1, STITCHER_CONFIG.STITCH_RED),
		})
		slashParticles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3 * S),
			NumberSequenceKeypoint.new(0.5, 0.8 * S),
			NumberSequenceKeypoint.new(1, 0),
		})
		slashParticles.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		slashParticles.Lifetime = NumberRange.new(0.1, 0.25)
		slashParticles.Rate = 80
		slashParticles.Speed = NumberRange.new(10, 25)
		slashParticles.SpreadAngle = Vector2.new(40, 40)
		slashParticles.Parent = slashEffect

		Debris:AddItem(slashEffect, 0.4)
		task.wait(0.05)
		slashParticles.Enabled = false
		task.wait(0.15)

		-- Reset
		for _, arm in ipairs(arms) do arm.attackAngle = 0 end
		for _, eyeData in ipairs(eyes) do
			if eyeData.light then
				TweenService:Create(eyeData.light, TweenInfo.new(0.3), {
					Brightness = 1.5,
					Color = STITCHER_CONFIG.BUTTON_SHINE,
				}):Play()
			end
		end

		Debris:AddItem(attackSound, 2)
		isAttacking = false
	end

	-- ---------------------------------------------------------------------------
	-- DEATH EFFECT
	-- ---------------------------------------------------------------------------
	local function PlayDeathEffect()
		threadTrail.Enabled = false
		ambientSound:Stop()
		clickSound:Stop()

		-- Death sound
		local deathSound = Instance.new("Sound")
		deathSound.SoundId = "rbxassetid://9114120101"
		deathSound.Volume = 1.2
		deathSound.PlaybackSpeed = 0.15
		deathSound.Parent = torso
		deathSound:Play()

		-- Eyes dim
		for _, eyeData in ipairs(eyes) do
			if eyeData.light then
				TweenService:Create(eyeData.light, TweenInfo.new(0.5), {Brightness = 0}):Play()
			end
			TweenService:Create(eyeData.button, TweenInfo.new(0.5), {Transparency = 1}):Play()
			TweenService:Create(eyeData.shine, TweenInfo.new(0.3), {Transparency = 1}):Play()
		end

		-- Massive stuffing burst (it's coming apart)
		stuffingEmitter.Rate = 40
		stuffingEmitter:Emit(20)

		-- All parts fade
		for _, part in pairs(npcModel:GetDescendants()) do
			if part:IsA("BasePart") then
				TweenService:Create(part, TweenInfo.new(0.7), {Transparency = 1}):Play()
			end
		end

		task.wait(0.8)
		stuffingEmitter.Enabled = false
		Debris:AddItem(deathSound, 2)
	end

	-- ---------------------------------------------------------------------------
	-- AI LOGIC
	-- ---------------------------------------------------------------------------
	local isAlive = true
	local lastAttackTime = 0

	local function FindNearestPlayer()
		local nearest, nearestDist = nil, STITCHER_CONFIG.DETECTION_RANGE
		for _, player in pairs(Players:GetPlayers()) do
			local char = player.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChild("Humanoid")
				if hrp and hum and hum.Health > 0 then
					local dist = (hrp.Position - Vector3.new(npcX, 0, npcZ)).Magnitude
					if dist < nearestDist and not IsInLobby(hrp.Position.X) then
						nearestDist = dist
						nearest = player
					end
				end
			end
		end
		return nearest, nearestDist
	end

	local function AttackPlayer(player)
		if tick() - lastAttackTime < STITCHER_CONFIG.ATTACK_COOLDOWN then return end
		if isAttacking then return end
		lastAttackTime = tick()

		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChild("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")

		if hum and hum.Health > 0 and hrp then
			coroutine.wrap(function() PlayAttackAnimation(hrp.Position) end)()
			task.wait(0.15)

			local dist = (hrp.Position - Vector3.new(npcX, 0, npcZ)).Magnitude
			if dist < STITCHER_CONFIG.ATTACK_RANGE + 2 and hum.Health > 0 then
				hum:TakeDamage(STITCHER_CONFIG.DAMAGE)

				-- Hit effect with needle sparks
				local hitEffect = CreatePart("HitEffect", Vector3.new(0.5, 0.5, 0.5),
					STITCHER_CONFIG.NEEDLE_TIP, Enum.Material.Neon, 0.3, workspace)
				hitEffect.Shape = Enum.PartType.Ball
				hitEffect.Position = hrp.Position
				TweenService:Create(hitEffect, TweenInfo.new(0.2), {
					Size = Vector3.new(2.5, 2.5, 2.5),
					Transparency = 1,
				}):Play()
				Debris:AddItem(hitEffect, 0.3)
			end
		end
	end

	-- ---------------------------------------------------------------------------
	-- MAIN LOOP
	-- ---------------------------------------------------------------------------
	local chaseConnection = nil
	chaseConnection = RunService.Heartbeat:Connect(function(dt)
		if not isAlive or not torso or not torso.Parent then
			if chaseConnection then chaseConnection:Disconnect() end
			return
		end

		-- LIFETIME CHECK
		local elapsedTime = tick() - spawnTime
		if elapsedTime >= npcLifetime then
			print("[Stitcher] Lifetime expired after " .. string.format("%.1f", elapsedTime) .. " seconds")
			isAlive = false
			if chaseConnection then chaseConnection:Disconnect() end
			PlayDeathEffect()
			task.wait(0.9)
			if npcFolder and npcFolder.Parent then
				npcFolder:Destroy()
			end
			return
		end

		-- STUNNED CHECK
		if npcModel:GetAttribute("Stunned") then
			UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, 999, nil)
			return
		end

		-- LOBBY CHECK
		if IsInLobby(npcX) then
			print("[Stitcher] Entered lobby - destroying")
			isAlive = false
			if chaseConnection then chaseConnection:Disconnect() end
			PlayDeathEffect()
			task.wait(0.8)
			if npcFolder and npcFolder.Parent then
				npcFolder:Destroy()
			end
			return
		end

		local target, distance = FindNearestPlayer()
		local targetPos = nil
		local isRunningThisFrame = false

		if target then
			local char = target.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					targetPos = hrp.Position
					local direction = Vector3.new(hrp.Position.X - npcX, 0, hrp.Position.Z - npcZ)

					if direction.Magnitude > 0.5 then
						local lookAngle = math.atan2(-direction.X, -direction.Z)

						if distance > STITCHER_CONFIG.ATTACK_RANGE then
							local moveSpeed
							if distance < 20 then
								moveSpeed = isSkittering and STITCHER_CONFIG.SPEED_SKITTER or STITCHER_CONFIG.SPEED_CHASE
								isRunningThisFrame = true
							else
								moveSpeed = STITCHER_CONFIG.SPEED_STALK
								isRunningThisFrame = false
							end

							local moveDir = direction.Unit
							local newX = npcX + moveDir.X * moveSpeed * dt
							local newZ = npcZ + moveDir.Z * moveSpeed * dt

							if not IsInLobby(newX) then
								UpdateNPCPosition(newX, newZ, lookAngle, true, dt, distance, targetPos)
							else
								UpdateNPCPosition(npcX, npcZ, lookAngle, false, dt, distance, targetPos)
								isRunningThisFrame = false
							end
						else
							UpdateNPCPosition(npcX, npcZ, lookAngle, false, dt, distance, targetPos)
							AttackPlayer(target)
							isRunningThisFrame = false
						end
					else
						UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, distance, targetPos)
					end
				else
					UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, 999, nil)
				end
			else
				UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, 999, nil)
			end
		else
			UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, 999, nil)
		end

		-- SOUND CONTROL
		if isRunningThisFrame and not isChasing then
			isChasing = true
			ambientSound:Stop()
			clickSound:Play()
		elseif not isRunningThisFrame and isChasing then
			isChasing = false
			clickSound:Stop()
			ambientSound:Play()
		end
	end)

	-- ---------------------------------------------------------------------------
	-- AMBIENT EFFECTS
	-- ---------------------------------------------------------------------------

	-- Random muffled sounds (mouth is sewn shut)
	coroutine.wrap(function()
		while isAlive and head and head.Parent do
			task.wait(math.random(4, 10))
			if isAlive and head and head.Parent and not isAttacking then
				local muffle = Instance.new("Sound")
				muffle.SoundId = "rbxassetid://9114221580"
				muffle.Volume = 0.12
				muffle.PlaybackSpeed = 0.08 + math.random() * 0.1
				muffle.Parent = head
				muffle:Play()
				Debris:AddItem(muffle, 4)
			end
		end
	end)()

	-- Needle click ambient (when not chasing)
	coroutine.wrap(function()
		while isAlive and torso and torso.Parent do
			task.wait(math.random(2, 6))
			if isAlive and not isChasing and torso and torso.Parent then
				local click = Instance.new("Sound")
				click.SoundId = "rbxassetid://9114120101"
				click.Volume = 0.08
				click.PlaybackSpeed = 2.0 + math.random() * 1.0
				click.Parent = torso
				click:Play()
				Debris:AddItem(click, 2)
			end
		end
	end)()

	-- Cleanup on destroy
	npcFolder.AncestryChanged:Connect(function()
		if not npcFolder.Parent then
			isAlive = false
			ambientSound:Stop()
			clickSound:Stop()
			if chaseConnection then chaseConnection:Disconnect() end
		end
	end)

	return npcFolder
end

-- ===============================================================================
-- EVENT LISTENERS
-- ===============================================================================

if SpawnStitcherEvent then
	SpawnStitcherEvent.Event:Connect(function(position, player, side, zDir, doorFrameInfo, lifetime)
		print("=====================================")
		print("    SpawnStitcherEvent RECEIVED!")
		print("   Position: " .. tostring(position))
		print("   Lifetime: " .. tostring(lifetime))
		print("=====================================")
		task.wait(0.3)
		CreateStitcherNPC(position, player, side, zDir, doorFrameInfo, lifetime)
	end)
	print("[Stitcher] Connected to SpawnStitcherEvent!")
end

print("=== THE STITCHER HORROR SYSTEM V1.0 - LOADED ===")
print("   Stalk Speed: " .. STITCHER_CONFIG.SPEED_STALK)
print("   Chase Speed: " .. STITCHER_CONFIG.SPEED_CHASE)
print("   Skitter Speed: " .. STITCHER_CONFIG.SPEED_SKITTER)
print("   Attack Range: " .. STITCHER_CONFIG.ATTACK_RANGE)
print("   Scale: " .. S .. "x")
print("================================================")