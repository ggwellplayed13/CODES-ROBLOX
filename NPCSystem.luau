--[[
    +------------------------------------------------------------------------------+
    |                    HOLLOW MAN HORROR ENTITY SYSTEM                            |
    |                 VERSIÓN 7 - "THE HOLLOW MAN" - FIXED EVENTS                   |
    |                      TERROR ABSOLUTO - VACÍO VIVIENTE                         |
    +------------------------------------------------------------------------------+
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- ===============================================================================
-- ESPERAR EL EVENTO CORRECTO:  SpawnHollowManEvent
-- ===============================================================================

print("=== HOLLOW MAN SYSTEM LOADING ===")
print("Waiting for SpawnHollowManEvent...")

local SpawnHollowManEvent = ReplicatedStorage:WaitForChild("SpawnHollowManEvent", 15)

if SpawnHollowManEvent then
	print("? SpawnHollowManEvent FOUND!")
else
	warn("? SpawnHollowManEvent NOT FOUND after 15 seconds!")
end

-- -------------------------------------------------------------------------------
-- CONFIGURACIÓN DEL HOLLOW MAN
-- -------------------------------------------------------------------------------
local HOLLOW_CONFIG = {
	SCALE = 2.3,
	SPEED_STALK = 12,
	SPEED_CHASE = 32,
	SPEED_GLITCH = 45,
	DAMAGE = 25,
	ATTACK_COOLDOWN = 0.7,
	ATTACK_RANGE = 7,
	DETECTION_RANGE = 250,

	VOID_ABSOLUTE = Color3.fromRGB(2, 2, 3),
	VOID_DEEP = Color3.fromRGB(5, 5, 8),
	VOID_SURFACE = Color3.fromRGB(10, 10, 15),
	VOID_EDGE = Color3.fromRGB(15, 12, 20),
	VOID_SHIMMER = Color3.fromRGB(25, 20, 35),

	EYE_COLOR = Color3.fromRGB(255, 255, 255),
	EYE_STARE = Color3.fromRGB(255, 255, 200),
	EYE_ANGRY = Color3.fromRGB(255, 50, 50),
	EYE_FLICKER = Color3.fromRGB(200, 200, 255),

	MOUTH_VOID = Color3.fromRGB(0, 0, 0),
	TEETH_COLOR = Color3.fromRGB(240, 235, 220),
	TEETH_ROTTEN = Color3.fromRGB(180, 160, 100),
	SMILE_EDGE = Color3.fromRGB(80, 40, 50),

	DISTORTION_COLOR = Color3.fromRGB(20, 15, 30),
	FOOTPRINT_COLOR = Color3.fromRGB(5, 5, 10),

	HEAD_SIZE = Vector3.new(1.2, 1.4, 1.1),
	TORSO_SIZE = Vector3.new(1.6, 2.2, 0.7),
	ARM_LENGTH = 3.2,
	HAND_SIZE = Vector3.new(0.5, 0.7, 0.15),
	FINGER_LENGTH = 0.6,
	LEG_LENGTH = 2.8,

	FREEZE_CHANCE = 0.008,
	FREEZE_DURATION = 1.0,
	TWITCH_CHANCE = 0.08,
	SMILE_GROW_CHANCE = 0.015,
	WRONG_WALK_CHANCE = 0.02,

	SMILE_MIN = 0.1,
	SMILE_MAX = 1.5,
	SMILE_SPEED = 0.5,

	LOBBY_START_X = -75,
	LOBBY_END_X = 75,
}

-- Aplicar escala
local S = HOLLOW_CONFIG.SCALE
HOLLOW_CONFIG.HEAD_SIZE = HOLLOW_CONFIG.HEAD_SIZE * S
HOLLOW_CONFIG.TORSO_SIZE = HOLLOW_CONFIG.TORSO_SIZE * S
HOLLOW_CONFIG.HAND_SIZE = HOLLOW_CONFIG.HAND_SIZE * S
HOLLOW_CONFIG.ARM_LENGTH = HOLLOW_CONFIG.ARM_LENGTH * S
HOLLOW_CONFIG.FINGER_LENGTH = HOLLOW_CONFIG.FINGER_LENGTH * S
HOLLOW_CONFIG.LEG_LENGTH = HOLLOW_CONFIG.LEG_LENGTH * S

local function IsInLobby(x)
	return x >= HOLLOW_CONFIG.LOBBY_START_X and x <= HOLLOW_CONFIG.LOBBY_END_X
end

-- -------------------------------------------------------------------------------
-- UTILIDADES
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
-- CREAR THE HOLLOW MAN
-- -------------------------------------------------------------------------------

local function CreateHollowManNPC(spawnPosition, triggerPlayer, side, zDir, doorFrameInfo, lifetime)
	local npcLifetime = lifetime
	if not npcLifetime or npcLifetime <= 0 then
		npcLifetime = 45
	end

	print("===========================================")
	print("?????? THE HOLLOW MAN SPAWNED ??????")
	print("   Scale: "..S.."x")
	print("   Lifetime: "..npcLifetime.." seconds")
	print("   Position: "..tostring(spawnPosition))
	print("   Side: "..tostring(side))
	print("   zDir: "..tostring(zDir))
	print("===========================================")

	local npcFolder = Instance.new("Folder")
	npcFolder.Name = "HollowManEntity"
	npcFolder.Parent = workspace

	local npcModel = Instance.new("Model")
	npcModel.Name = "TheHollowMan"
	npcModel.Parent = npcFolder

	local spawnTime = tick()
	npcFolder: SetAttribute("SpawnTime", spawnTime)
	npcFolder:SetAttribute("Lifetime", npcLifetime)
	npcModel:SetAttribute("SpawnTime", spawnTime)
	npcModel:SetAttribute("Lifetime", npcLifetime)

	local groundY = 0.5

	-- ---------------------------------------------------------------------------
	-- TORSO
	-- ---------------------------------------------------------------------------
	local torso = CreatePart(
		"Torso",
		HOLLOW_CONFIG.TORSO_SIZE,
		HOLLOW_CONFIG.VOID_ABSOLUTE,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	torso.CanCollide = true
	CreateMesh(torso, Enum.MeshType.Sphere, Vector3.new(1, 1.2, 0.6))

	local voidLayers = {}
	for i = 1, 4 do
		local layerSize = HOLLOW_CONFIG.TORSO_SIZE * (1.05 + i * 0.04)
		local layer = CreatePart(
			"VoidLayer"..i,
			layerSize,
			LerpColor(HOLLOW_CONFIG.VOID_DEEP, HOLLOW_CONFIG.VOID_EDGE, i/4),
			Enum.Material.SmoothPlastic,
			0.3 + i * 0.15,
			npcModel
		)
		CreateMesh(layer, Enum.MeshType.Sphere, Vector3.new(1, 1.2 + i * 0.05, 0.55))
		table.insert(voidLayers, {part = layer, offset = i * 0.02 * S, pulsePhase = i * 0.5})
	end

	local innerForms = {}
	for i = 1, 6 do
		local form = CreatePart(
			"InnerForm"..i,
			Vector3.new(0.4 * S, 0.08 * S, 0.15 * S),
			HOLLOW_CONFIG.VOID_SHIMMER,
			Enum.Material.SmoothPlastic,
			0.6,
			npcModel
		)
		table.insert(innerForms, {
			part = form,
			index = i,
			side = i % 2 == 0 and 1 or -1,
			flickerPhase = math.random() * math.pi * 2
		})
	end

	local pelvis = CreatePart(
		"Pelvis",
		Vector3.new(1.2 * S, 0.6 * S, 0.5 * S),
		HOLLOW_CONFIG.VOID_DEEP,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	CreateMesh(pelvis, Enum.MeshType.Sphere, Vector3.new(1, 0.7, 0.8))

	-- ---------------------------------------------------------------------------
	-- CUELLO
	-- ---------------------------------------------------------------------------
	local neckSegments = {}
	for i = 1, 4 do
		local segSize = (0.3 - i * 0.02) * S
		local seg = CreatePart(
			"NeckSeg"..i,
			Vector3.new(segSize, 0.15 * S, segSize),
			HOLLOW_CONFIG.VOID_SURFACE,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		CreateMesh(seg, Enum.MeshType.Cylinder)
		table.insert(neckSegments, {part = seg, index = i, tiltAngle = 0, twistAngle = 0})
	end

	-- ---------------------------------------------------------------------------
	-- CABEZA
	-- ---------------------------------------------------------------------------
	local head = CreatePart(
		"Head",
		HOLLOW_CONFIG.HEAD_SIZE,
		HOLLOW_CONFIG.VOID_ABSOLUTE,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	CreateMesh(head, Enum.MeshType.Sphere, Vector3.new(1, 1.15, 0.95))

	local headOuter = CreatePart(
		"HeadOuter",
		HOLLOW_CONFIG.HEAD_SIZE * 1.05,
		HOLLOW_CONFIG.VOID_DEEP,
		Enum.Material.SmoothPlastic,
		0.4,
		npcModel
	)
	CreateMesh(headOuter, Enum.MeshType.Sphere, Vector3.new(1, 1.15, 0.95))

	local faceVoid = CreatePart(
		"FaceVoid",
		Vector3.new(0.9 * S, 1.0 * S, 0.3 * S),
		HOLLOW_CONFIG.VOID_ABSOLUTE,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	CreateMesh(faceVoid, Enum.MeshType.Sphere, Vector3.new(1, 1, 0.4))

	-- ---------------------------------------------------------------------------
	-- OJOS
	-- ---------------------------------------------------------------------------
	local eyes = {}
	local eyeConfigs = {
		{x = -0.25 * S, y = 0.2 * S, z = -0.48 * S, size = 0.18 * S},
		{x = 0.25 * S, y = 0.18 * S, z = -0.46 * S, size = 0.16 * S},
	}

	for i, config in ipairs(eyeConfigs) do
		local socket = CreatePart(
			"EyeSocket"..i,
			Vector3.new(config.size * 1.8, config.size * 1.6, config.size * 0.8),
			HOLLOW_CONFIG.VOID_ABSOLUTE,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		CreateMesh(socket, Enum.MeshType.Sphere)

		local eyeGlow = CreateBallPart("EyeGlow"..i, config.size * 0.6, HOLLOW_CONFIG.EYE_COLOR, Enum.Material.Neon, npcModel)
		local pupil = CreateBallPart("Pupil"..i, config.size * 0.25, HOLLOW_CONFIG.VOID_ABSOLUTE, Enum.Material.SmoothPlastic, npcModel)

		local eyeLight = Instance.new("PointLight")
		eyeLight.Color = HOLLOW_CONFIG.EYE_COLOR
		eyeLight.Brightness = 4
		eyeLight.Range = 12 * S
		eyeLight.Shadows = true
		eyeLight.Parent = eyeGlow

		local eyeTrail = CreatePart("EyeTrail"..i, Vector3.new(config.size * 0.4, config.size * 0.3, config.size * 0.8),
			HOLLOW_CONFIG.EYE_FLICKER, Enum.Material.Neon, 0.5, npcModel)

		table.insert(eyes, {
			socket = socket, glow = eyeGlow, pupil = pupil, trail = eyeTrail, light = eyeLight,
			config = config, lookOffset = {x = 0, y = 0}, dilated = false, flickerPhase = math.random() * math.pi * 2
		})
	end

	-- ---------------------------------------------------------------------------
	-- LA SONRISA
	-- ---------------------------------------------------------------------------
	local mouthVoid = CreatePart("MouthVoid", Vector3.new(0.5 * S, 0.15 * S, 0.4 * S), HOLLOW_CONFIG.MOUTH_VOID, Enum.Material.SmoothPlastic, 0, npcModel)
	CreateMesh(mouthVoid, Enum.MeshType.Sphere)

	local smileEdgeTop = CreatePart("SmileEdgeTop", Vector3.new(0.55 * S, 0.04 * S, 0.1 * S), HOLLOW_CONFIG.SMILE_EDGE, Enum.Material.SmoothPlastic, 0, npcModel)
	local smileEdgeBottom = CreatePart("SmileEdgeBottom", Vector3.new(0.5 * S, 0.03 * S, 0.08 * S), HOLLOW_CONFIG.SMILE_EDGE, Enum.Material.SmoothPlastic, 0, npcModel)

	local smileCorners = {}
	for sideVal = -1, 1, 2 do
		local corner = CreatePart("SmileCorner"..sideVal, Vector3.new(0.06 * S, 0.12 * S, 0.04 * S), HOLLOW_CONFIG.SMILE_EDGE, Enum.Material.SmoothPlastic, 0, npcModel)
		table.insert(smileCorners, {part = corner, side = sideVal})
	end

	local teeth = {}
	for i = 1, 12 do
		local xPos = (i - 6.5) * 0.035 * S
		if math.random() > 0.15 then
			local isRotten = math.random() < 0.3
			local toothHeight = (0.06 + (math.random() < 0.2 and 0.04 or 0) + math.random() * 0.03) * S
			local tooth = CreatePart("Tooth"..i, Vector3.new(0.025 * S, toothHeight, 0.02 * S),
				isRotten and HOLLOW_CONFIG.TEETH_ROTTEN or HOLLOW_CONFIG.TEETH_COLOR, Enum.Material.SmoothPlastic, 0, npcModel)
			table.insert(teeth, {part = tooth, xOff = xPos, height = toothHeight, angle = (math.random() - 0.5) * math.rad(20), upper = i <= 6})
		end
	end

	-- ---------------------------------------------------------------------------
	-- BRAZOS
	-- ---------------------------------------------------------------------------
	local arms = {}
	for sideVal = -1, 1, 2 do
		local armFolder = Instance.new("Folder")
		armFolder.Name = sideVal == -1 and "LeftArm" or "RightArm"
		armFolder.Parent = npcModel

		local shoulder = CreateBallPart("Shoulder", 0.28 * S, HOLLOW_CONFIG.VOID_SURFACE, Enum.Material.SmoothPlastic, armFolder)

		local armSegments = {}
		for i = 1, 5 do
			local segWidth = (0.15 - i * 0.015) * S
			local seg = CreatePart("ArmSeg"..i, Vector3.new(segWidth, HOLLOW_CONFIG.ARM_LENGTH / 5, segWidth),
				LerpColor(HOLLOW_CONFIG.VOID_DEEP, HOLLOW_CONFIG.VOID_SURFACE, i/5), Enum.Material.SmoothPlastic, 0, armFolder)
			CreateMesh(seg, Enum.MeshType.Cylinder)
			table.insert(armSegments, {part = seg, index = i, delayedAngle = 0, targetAngle = 0})
		end

		local wrist = CreateBallPart("Wrist", 0.1 * S, HOLLOW_CONFIG.VOID_EDGE, Enum.Material.SmoothPlastic, armFolder)
		local hand = CreatePart("Hand", HOLLOW_CONFIG.HAND_SIZE, HOLLOW_CONFIG.VOID_SURFACE, Enum.Material.SmoothPlastic, 0, armFolder)
		CreateMesh(hand, Enum.MeshType.Sphere, Vector3.new(1, 1.3, 0.35))

		local fingers = {}
		for f = 1, 5 do
			local segments = {}
			for seg = 1, 3 do
				local fingerSeg = CreatePart("Finger"..f.."_"..seg, Vector3.new(0.025 * S, HOLLOW_CONFIG.FINGER_LENGTH * 0.35, 0.02 * S),
					seg == 3 and HOLLOW_CONFIG.VOID_EDGE or HOLLOW_CONFIG.VOID_SURFACE, Enum.Material.SmoothPlastic, 0, armFolder)
				table.insert(segments, fingerSeg)
			end
			local claw = CreatePart("Claw"..f, Vector3.new(0.02 * S, 0.12 * S, 0.03 * S), HOLLOW_CONFIG.VOID_SHIMMER, Enum.Material.SmoothPlastic, 0, armFolder)
			CreateMesh(claw, Enum.MeshType.Wedge)
			table.insert(fingers, {segments = segments, claw = claw, index = f, xOff = (f - 3) * 0.08 * S, curlPhase = math.random() * math.pi, twitchTimer = 0})
		end

		table.insert(arms, {folder = armFolder, shoulder = shoulder, segments = armSegments, wrist = wrist, hand = hand, fingers = fingers, side = sideVal, swingAngle = 0, delayedSwing = 0, attackAngle = 0})
	end

	-- ---------------------------------------------------------------------------
	-- PIERNAS
	-- ---------------------------------------------------------------------------
	local legs = {}
	for sideVal = -1, 1, 2 do
		local legFolder = Instance.new("Folder")
		legFolder.Name = sideVal == -1 and "LeftLeg" or "RightLeg"
		legFolder.Parent = npcModel

		local hip = CreateBallPart("Hip", 0.25 * S, HOLLOW_CONFIG.VOID_SURFACE, Enum.Material.SmoothPlastic, legFolder)
		local thigh = CreatePart("Thigh", Vector3.new(0.22 * S, HOLLOW_CONFIG.LEG_LENGTH * 0.45, 0.22 * S), HOLLOW_CONFIG.VOID_DEEP, Enum.Material.SmoothPlastic, 0, legFolder)
		CreateMesh(thigh, Enum.MeshType.Cylinder)
		local knee = CreateBallPart("Knee", 0.18 * S, HOLLOW_CONFIG.VOID_EDGE, Enum.Material.SmoothPlastic, legFolder)
		local shin = CreatePart("Shin", Vector3.new(0.18 * S, HOLLOW_CONFIG.LEG_LENGTH * 0.45, 0.18 * S), HOLLOW_CONFIG.VOID_DEEP, Enum.Material.SmoothPlastic, 0, legFolder)
		CreateMesh(shin, Enum.MeshType.Cylinder)
		local ankle = CreateBallPart("Ankle", 0.12 * S, HOLLOW_CONFIG.VOID_SURFACE, Enum.Material.SmoothPlastic, legFolder)
		local foot = CreatePart("Foot", Vector3.new(0.2 * S, 0.1 * S, 0.5 * S), HOLLOW_CONFIG.VOID_SURFACE, Enum.Material.SmoothPlastic, 0, legFolder)
		CreateMesh(foot, Enum.MeshType.Sphere, Vector3.new(0.6, 0.4, 1.5))

		table.insert(legs, {folder = legFolder, hip = hip, thigh = thigh, knee = knee, shin = shin, ankle = ankle, foot = foot, side = sideVal, swingAngle = 0})
	end

	-- Sombra
	local independentShadow = CreatePart("IndependentShadow", Vector3.new(3 * S, 0.05, 3 * S), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, 0.5, npcModel)
	independentShadow.CastShadow = false

	local shadowOffset = {x = 0, z = 0}
	local shadowTargetOffset = {x = 0, z = 0}

	-- ---------------------------------------------------------------------------
	-- PARTÍCULAS
	-- ---------------------------------------------------------------------------
	local voidAura = Instance.new("ParticleEmitter")
	voidAura.Texture = "rbxassetid://243098098"
	voidAura.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, HOLLOW_CONFIG.VOID_ABSOLUTE), ColorSequenceKeypoint.new(1, HOLLOW_CONFIG.VOID_DEEP)})
	voidAura.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3 * S), NumberSequenceKeypoint.new(0.5, 1.2 * S), NumberSequenceKeypoint.new(1, 2 * S)})
	voidAura.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 1)})
	voidAura.Lifetime = NumberRange.new(0.5, 1)
	voidAura.Rate = 15
	voidAura.Speed = NumberRange.new(0.3, 1)
	voidAura.SpreadAngle = Vector2.new(360, 360)
	voidAura.Parent = torso

	local distortionEmitter = Instance.new("ParticleEmitter")
	distortionEmitter.Texture = "rbxassetid://243098098"
	distortionEmitter.Color = ColorSequence.new(HOLLOW_CONFIG.DISTORTION_COLOR)
	distortionEmitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1 * S), NumberSequenceKeypoint.new(0.5, 0.4 * S), NumberSequenceKeypoint.new(1, 0)})
	distortionEmitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1)})
	distortionEmitter.Lifetime = NumberRange.new(0.2, 0.4)
	distortionEmitter.Rate = 8
	distortionEmitter.Speed = NumberRange.new(2, 5)
	distortionEmitter.SpreadAngle = Vector2.new(180, 180)
	distortionEmitter.Parent = torso

	local footprintEmitter = Instance.new("ParticleEmitter")
	footprintEmitter.Texture = "rbxassetid://243098098"
	footprintEmitter.Color = ColorSequence.new(HOLLOW_CONFIG.FOOTPRINT_COLOR)
	footprintEmitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5 * S), NumberSequenceKeypoint.new(1, 1.5 * S)})
	footprintEmitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
	footprintEmitter.Lifetime = NumberRange.new(2, 4)
	footprintEmitter.Rate = 0
	footprintEmitter.Speed = NumberRange.new(0, 0.1)
	footprintEmitter.EmissionDirection = Enum.NormalId.Bottom
	footprintEmitter.Parent = pelvis

	local negativeLight = Instance.new("PointLight")
	negativeLight.Color = HOLLOW_CONFIG.VOID_ABSOLUTE
	negativeLight.Brightness = -0.5
	negativeLight.Range = 15 * S
	negativeLight.Shadows = false
	negativeLight.Parent = torso

	-- ---------------------------------------------------------------------------
	-- VARIABLES DE ANIMACIÓN
	-- ---------------------------------------------------------------------------
	local npcX = spawnPosition.X
	local npcZ = spawnPosition.Z
	local npcRotation = zDir > 0 and 0 or math.pi

	local walkTime = 0
	local breathTime = 0
	local isWalking = false
	local isAttacking = false
	local isFrozen = false
	local freezeTimer = 0
	local freezeCooldown = 0

	local smileAmount = HOLLOW_CONFIG.SMILE_MIN
	local targetSmile = HOLLOW_CONFIG.SMILE_MIN

	local wrongWalkActive = false
	local wrongWalkPhase = 0
	local wrongWalkCooldown = 0

	-- ---------------------------------------------------------------------------
	-- FUNCIÓN DE ACTUALIZACIÓN
	-- ---------------------------------------------------------------------------
	local function UpdateNPCPosition(x, z, rotY, walking, deltaTime, targetDistance, targetPos)
		npcX = x
		npcZ = z
		npcRotation = rotY or npcRotation
		isWalking = walking or false

		if deltaTime then
			if isWalking then
				walkTime = walkTime + deltaTime * 7
			end
			breathTime = breathTime + deltaTime * 1.5

			if freezeCooldown > 0 then freezeCooldown = freezeCooldown - deltaTime end
			if wrongWalkCooldown > 0 then wrongWalkCooldown = wrongWalkCooldown - deltaTime end
		end

		-- Congelarse
		if not isFrozen and freezeCooldown <= 0 and math.random() < HOLLOW_CONFIG.FREEZE_CHANCE then
			if targetDistance and targetDistance < 40 and targetDistance > 15 then
				isFrozen = true
				freezeTimer = HOLLOW_CONFIG.FREEZE_DURATION
				freezeCooldown = 8
			end
		end

		if isFrozen then
			freezeTimer = freezeTimer - deltaTime
			if freezeTimer <= 0 then isFrozen = false end
		end

		-- Caminar mal
		if isWalking and not wrongWalkActive and wrongWalkCooldown <= 0 and math.random() < HOLLOW_CONFIG.WRONG_WALK_CHANCE then
			wrongWalkActive = true
			wrongWalkPhase = math.random() * math.pi * 2
			wrongWalkCooldown = 5
			task.delay(0.3 + math.random() * 0.5, function() wrongWalkActive = false end)
		end

		-- Sonrisa
		if targetDistance and targetDistance < 30 then
			targetSmile = Lerp(HOLLOW_CONFIG.SMILE_MIN, HOLLOW_CONFIG.SMILE_MAX, (30 - targetDistance) / 30)
		else
			targetSmile = HOLLOW_CONFIG.SMILE_MIN + math.sin(breathTime * 0.5) * 0.1
		end

		if math.random() < HOLLOW_CONFIG.SMILE_GROW_CHANCE then
			targetSmile = HOLLOW_CONFIG.SMILE_MAX
			task.delay(0.3 + math.random() * 0.5, function() targetSmile = HOLLOW_CONFIG.SMILE_MIN end)
		end

		smileAmount = Lerp(smileAmount, targetSmile, deltaTime * HOLLOW_CONFIG.SMILE_SPEED * 3)

		-- Sombra
		if math.random() < 0.01 then
			shadowTargetOffset.x = (math.random() - 0.5) * 2 * S
			shadowTargetOffset.z = (math.random() - 0.5) * 2 * S
		end
		shadowOffset.x = Lerp(shadowOffset.x, shadowTargetOffset.x, deltaTime * 0.5)
		shadowOffset.z = Lerp(shadowOffset.z, shadowTargetOffset.z, deltaTime * 0.5)

		-- Cálculos base
		local breathScale = 1 + math.sin(breathTime * math.pi) * 0.02
		local walkBob = isWalking and math.sin(walkTime * 2) * 0.08 * S or 0
		local walkSway = isWalking and math.sin(walkTime) * 0.02 or 0

		local twitchX, twitchY, twitchZ = 0, 0, 0
		if math.random() < HOLLOW_CONFIG.TWITCH_CHANCE * 0.1 then
			twitchX = (math.random() - 0.5) * 0.05
			twitchY = (math.random() - 0.5) * 0.04
			twitchZ = (math.random() - 0.5) * 0.05
		end

		local legTotalLength = HOLLOW_CONFIG.LEG_LENGTH * 0.9
		local baseHeight = groundY + legTotalLength + 0.5 * S
		local torsoY = baseHeight + walkBob
		local pelvisY = torsoY - 1.2 * S

		local baseCFrame = CFrame.new(x + walkSway + twitchX, torsoY + twitchY, z + twitchZ) * CFrame.Angles(0, npcRotation, walkSway * 0.5)

		-- TORSO
		torso.CFrame = baseCFrame
		torso.Size = HOLLOW_CONFIG.TORSO_SIZE * Vector3.new(breathScale, 1, breathScale)

		for i, layer in ipairs(voidLayers) do
			local pulse = 1 + math.sin(breathTime * 2 + layer.pulsePhase) * 0.03
			layer.part.CFrame = baseCFrame * CFrame.new(0, 0, layer.offset * pulse)
			layer.part.Size = HOLLOW_CONFIG.TORSO_SIZE * (1.05 + i * 0.04) * pulse
		end

		for _, form in ipairs(innerForms) do
			local flicker = math.sin(breathTime * 3 + form.flickerPhase) > 0.7
			form.part.Transparency = flicker and 0.4 or 0.9
			local formY = HOLLOW_CONFIG.TORSO_SIZE.Y * 0.3 - form.index * 0.12 * S
			form.part.CFrame = baseCFrame * CFrame.new(form.side * 0.4 * S, formY, -0.15 * S) * CFrame.Angles(0, form.side * math.rad(30), 0)
		end

		pelvis.CFrame = baseCFrame * CFrame.new(0, -1.2 * S, 0)

		-- CUELLO
		local neckBaseCFrame = baseCFrame * CFrame.new(0, HOLLOW_CONFIG.TORSO_SIZE.Y * 0.45, 0)
		local neckTwist = 0
		if isFrozen and targetPos then
			local toTarget = (targetPos - Vector3.new(x, 0, z))
			if toTarget.Magnitude > 0.5 then
				local targetAngle = math.atan2(-toTarget.X, -toTarget.Z)
				local angleDiff = targetAngle - npcRotation
				neckTwist = math.clamp(angleDiff, -math.pi * 0.6, math.pi * 0.6)
			end
		end

		for i, seg in ipairs(neckSegments) do
			local t = i / #neckSegments
			local segBend = math.sin(breathTime * 1.5 + i * 0.3) * math.rad(5)
			local segTwist = neckTwist * t
			seg.part.CFrame = neckBaseCFrame * CFrame.new(0, t * 0.5 * S, 0) * CFrame.Angles(segBend, segTwist, 0) * CFrame.Angles(0, 0, math.rad(90))
		end

		-- CABEZA
		local lastNeckSeg = neckSegments[#neckSegments]
		local headTilt = math.sin(breathTime * 0.8) * math.rad(3)
		local headTwitchX, headTwitchZ = 0, 0
		if math.random() < 0.005 then
			headTwitchX = (math.random() - 0.5) * math.rad(15)
			headTwitchZ = (math.random() - 0.5) * math.rad(10)
		end

		local headCFrame = lastNeckSeg.part.CFrame * CFrame.Angles(0, 0, -math.rad(90)) * CFrame.new(0, 0.5 * S, 0) * CFrame.Angles(headTilt + headTwitchX, neckTwist, headTwitchZ)
		head.CFrame = headCFrame
		headOuter.CFrame = headCFrame
		faceVoid.CFrame = headCFrame * CFrame.new(0, -0.05 * S, -HOLLOW_CONFIG.HEAD_SIZE.Z * 0.4)

		-- OJOS
		for _, eyeData in ipairs(eyes) do
			local cfg = eyeData.config
			local lookX, lookY = 0, 0
			if targetPos then
				local toTarget = (targetPos - headCFrame.Position)
				if toTarget.Magnitude > 0.5 then
					local localTarget = headCFrame: PointToObjectSpace(targetPos)
					lookX = math.clamp(localTarget.X * 0.015, -0.03 * S, 0.03 * S)
					lookY = math.clamp(localTarget.Y * 0.01, -0.02 * S, 0.02 * S)
				end
			end

			local eyeFlicker = math.sin(breathTime * 5 + eyeData.flickerPhase) > 0.98
			eyeData.socket.CFrame = headCFrame * CFrame.new(cfg.x, cfg.y, cfg.z)
			eyeData.glow.CFrame = headCFrame * CFrame.new(cfg.x + lookX, cfg.y + lookY, cfg.z - 0.08 * S)
			eyeData.glow.Transparency = eyeFlicker and 0.8 or 0
			eyeData.pupil.CFrame = eyeData.glow.CFrame * CFrame.new(0, 0, -cfg.size * 0.2)
			eyeData.trail.CFrame = headCFrame * CFrame.new(cfg.x, cfg.y, cfg.z + 0.1 * S)

			if eyeData.light then
				local intensity = 4
				if targetDistance and targetDistance < 20 then
					intensity = Lerp(4, 10, (20 - targetDistance) / 20)
					eyeData.light.Color = LerpColor(HOLLOW_CONFIG.EYE_COLOR, HOLLOW_CONFIG.EYE_STARE, (20 - targetDistance) / 20)
				else
					eyeData.light.Color = HOLLOW_CONFIG.EYE_COLOR
				end
				if eyeFlicker then intensity = 1 end
				eyeData.light.Brightness = intensity
			end
		end

		-- SONRISA
		local mouthY = -HOLLOW_CONFIG.HEAD_SIZE.Y * 0.35
		local mouthWidth = 0.5 * S * (1 + smileAmount * 0.6)
		local mouthHeight = 0.15 * S * (1 + smileAmount * 2)

		mouthVoid.Size = Vector3.new(mouthWidth, mouthHeight, 0.4 * S)
		mouthVoid.CFrame = headCFrame * CFrame.new(0, mouthY - smileAmount * 0.1 * S, -HOLLOW_CONFIG.HEAD_SIZE.Z * 0.42)

		smileEdgeTop.Size = Vector3.new(mouthWidth + 0.05 * S, 0.04 * S, 0.1 * S)
		smileEdgeTop.CFrame = headCFrame * CFrame.new(0, mouthY + mouthHeight * 0.4, -HOLLOW_CONFIG.HEAD_SIZE.Z * 0.43)

		smileEdgeBottom.Size = Vector3.new(mouthWidth, 0.03 * S, 0.08 * S)
		smileEdgeBottom.CFrame = headCFrame * CFrame.new(0, mouthY - mouthHeight * 0.5 - smileAmount * 0.15 * S, -HOLLOW_CONFIG.HEAD_SIZE.Z * 0.42)

		for _, corner in ipairs(smileCorners) do
			local cornerX = corner.side * (mouthWidth * 0.5 + 0.02 * S)
			local cornerY = mouthY + smileAmount * 0.2 * S
			corner.part.Size = Vector3.new(0.06 * S, 0.08 * S + smileAmount * 0.1 * S, 0.04 * S)
			corner.part.CFrame = headCFrame * CFrame.new(cornerX, cornerY, -HOLLOW_CONFIG.HEAD_SIZE.Z * 0.41) * CFrame.Angles(0, 0, corner.side * math.rad(-20 - smileAmount * 30))
		end

		for _, tooth in ipairs(teeth) do
			local toothVisible = smileAmount > 0.3
			tooth.part.Transparency = toothVisible and 0 or 0.8
			if tooth.upper then
				tooth.part.CFrame = headCFrame * CFrame.new(tooth.xOff, mouthY + mouthHeight * 0.2, -HOLLOW_CONFIG.HEAD_SIZE.Z * 0.44) * CFrame.Angles(math.rad(180) + tooth.angle, 0, 0)
			else
				tooth.part.CFrame = headCFrame * CFrame.new(tooth.xOff, mouthY - mouthHeight * 0.3 - smileAmount * 0.1 * S, -HOLLOW_CONFIG.HEAD_SIZE.Z * 0.43) * CFrame.Angles(tooth.angle, 0, 0)
			end
		end

		-- BRAZOS
		for _, arm in ipairs(arms) do
			local armPhase = walkTime + arm.side * math.pi * 0.5
			local targetSwing = isWalking and math.sin(armPhase) * math.rad(25) or 0
			arm.delayedSwing = Lerp(arm.delayedSwing, targetSwing, deltaTime * 4)
			local armSwing = arm.delayedSwing

			local shoulderX = arm.side * HOLLOW_CONFIG.TORSO_SIZE.X * 0.55
			local shoulderY = HOLLOW_CONFIG.TORSO_SIZE.Y * 0.35
			arm.shoulder.CFrame = baseCFrame * CFrame.new(shoulderX, shoulderY, 0)

			local prevCFrame = arm.shoulder.CFrame
			local segLength = HOLLOW_CONFIG.ARM_LENGTH / #arm.segments

			for i, seg in ipairs(arm.segments) do
				seg.targetAngle = armSwing * (1 - i * 0.1) + arm.attackAngle * (i / #arm.segments)
				seg.delayedAngle = Lerp(seg.delayedAngle, seg.targetAngle, deltaTime * (6 - i * 0.5))
				local segWave = math.sin(breathTime * 2 + i * 0.5) * math.rad(2)
				local segPitch = math.rad(-10) + seg.delayedAngle + segWave
				local segRoll = arm.side * math.rad(15 + i * 3)
				local segCFrame = prevCFrame * CFrame.Angles(segPitch, 0, segRoll) * CFrame.new(0, -segLength * 0.5, 0)
				seg.part.CFrame = segCFrame * CFrame.Angles(0, 0, math.rad(90))
				prevCFrame = segCFrame * CFrame.new(0, -segLength * 0.5, 0)
			end

			arm.wrist.CFrame = prevCFrame
			local handWave = math.sin(breathTime * 1.5 + arm.side) * math.rad(8)
			local handCFrame = prevCFrame * CFrame.Angles(handWave, 0, arm.side * math.rad(5)) * CFrame.new(0, -HOLLOW_CONFIG.HAND_SIZE.Y * 0.4, 0)
			arm.hand.CFrame = handCFrame

			local fingerCurl = math.rad(20) + smileAmount * math.rad(20)
			for _, finger in ipairs(arm.fingers) do
				local curl = fingerCurl + math.sin(breathTime + finger.curlPhase) * math.rad(8)
				local fingerBase = handCFrame * CFrame.new(finger.xOff, -HOLLOW_CONFIG.HAND_SIZE.Y * 0.4, 0)
				local prevFingerCFrame = fingerBase
				for segIdx, seg in ipairs(finger.segments) do
					local segCurl = curl * (0.3 + segIdx * 0.25)
					local segCFrame = prevFingerCFrame * CFrame.Angles(segCurl, 0, 0) * CFrame.new(0, -seg.Size.Y * 0.5, 0)
					seg.CFrame = segCFrame
					prevFingerCFrame = segCFrame * CFrame.new(0, -seg.Size.Y * 0.5, 0)
				end
				finger.claw.CFrame = prevFingerCFrame * CFrame.Angles(math.rad(40), 0, 0) * CFrame.new(0, -0.06 * S, 0)
			end
		end

		-- PIERNAS
		local thighLength = HOLLOW_CONFIG.LEG_LENGTH * 0.45
		local shinLength = HOLLOW_CONFIG.LEG_LENGTH * 0.45

		for _, leg in ipairs(legs) do
			local legPhase = walkTime + (leg.side == -1 and 0 or math.pi)
			local legSwing
			if wrongWalkActive then
				legSwing = math.sin(walkTime * 3 + wrongWalkPhase) * math.rad(35)
			else
				legSwing = isWalking and math.sin(legPhase) * math.rad(30) or 0
			end

			local hipX = leg.side * 0.4 * S
			local hipY = pelvisY - 0.1 * S
			leg.hip.CFrame = baseCFrame * CFrame.new(hipX, -1.0 * S, 0)

			local thighCFrame = CFrame.new(x + hipX + walkSway, hipY, z) * CFrame.Angles(0, npcRotation, 0) * CFrame.Angles(legSwing, 0, leg.side * math.rad(3)) * CFrame.new(0, -thighLength * 0.5, 0)
			leg.thigh.CFrame = thighCFrame * CFrame.Angles(0, 0, math.rad(90))

			local kneePos = thighCFrame * CFrame.new(0, -thighLength * 0.5, 0)
			leg.knee.CFrame = CFrame.new(kneePos.Position)

			local shinAngle = math.rad(-5) - legSwing * 0.5
			local shinCFrame = kneePos * CFrame.Angles(shinAngle, 0, 0) * CFrame.new(0, -shinLength * 0.5, 0)
			leg.shin.CFrame = shinCFrame * CFrame.Angles(0, 0, math.rad(90))

			local anklePos = shinCFrame * CFrame.new(0, -shinLength * 0.5, 0)
			leg.ankle.CFrame = CFrame.new(anklePos.Position)

			local walkLift = isWalking and math.max(0, math.sin(legPhase)) * 0.12 * S or 0
			local footY = groundY + 0.05 * S + walkLift
			local footForward = isWalking and math.sin(legPhase) * 0.3 * S or 0
			local footCFrame = CFrame.new(x + hipX + walkSway, footY, z + footForward) * CFrame.Angles(0, npcRotation, 0)
			leg.foot.CFrame = footCFrame

			if isWalking and walkLift < 0.02 * S and math.random() < 0.05 then
				footprintEmitter:Emit(1)
			end
		end

		-- SOMBRA
		independentShadow.CFrame = CFrame.new(x + shadowOffset.x, groundY + 0.02, z + shadowOffset.z)
		independentShadow.Size = Vector3.new((3 + smileAmount) * S, 0.05, (3 + smileAmount) * S)
	end

	-- Posición inicial
	UpdateNPCPosition(npcX, npcZ, npcRotation, false, 0, 999, nil)

	-- ---------------------------------------------------------------------------
	-- SONIDOS
	-- ---------------------------------------------------------------------------
	local spawnSound = Instance.new("Sound")
	spawnSound.SoundId = "rbxassetid://120923220505708"
	spawnSound.Volume = 0.9
	spawnSound.PlaybackSpeed = 4.0
	spawnSound.Parent = torso
	spawnSound:Play()

	local whisperSound = Instance.new("Sound")
	whisperSound.SoundId = "rbxassetid://79261984390684"
	whisperSound.Volume = 0.3
	whisperSound.Looped = true
	whisperSound.PlaybackSpeed = 1.0
	whisperSound.Parent = head
	whisperSound:Play()

	local staticSound = Instance.new("Sound")
	staticSound.SoundId = "rbxassetid://116168267708732"
	staticSound.Volume = 0.5
	staticSound.Looped = true
	staticSound.PlaybackSpeed = 0.6
	staticSound.Parent = torso

	local isChasing = false

	-- ---------------------------------------------------------------------------
	-- ANIMACIÓN DE ATAQUE
	-- ---------------------------------------------------------------------------
	local function PlayAttackAnimation(targetPosition)
		if isAttacking then return end
		isAttacking = true
		targetSmile = HOLLOW_CONFIG.SMILE_MAX

		for _, eyeData in ipairs(eyes) do
			if eyeData.light then
				TweenService:Create(eyeData.light, TweenInfo.new(0.1), {Color = HOLLOW_CONFIG.EYE_ANGRY, Brightness = 15}):Play()
			end
			TweenService:Create(eyeData.glow, TweenInfo.new(0.1), {Color = HOLLOW_CONFIG.EYE_ANGRY}):Play()
		end

		local attackSound = Instance.new("Sound")
		attackSound.SoundId = "rbxassetid://116168267708732"
		attackSound.Volume = 0.8
		attackSound.PlaybackSpeed = 0.6
		attackSound.Parent = head
		attackSound:Play()

		for _, arm in ipairs(arms) do arm.attackAngle = math.rad(-80) end
		task.wait(0.15)
		for _, arm in ipairs(arms) do arm.attackAngle = math.rad(60) end

		local slashEffect = CreatePart("SlashEffect", Vector3.new(0.1, 0.1, 0.1), HOLLOW_CONFIG.VOID_SHIMMER, Enum.Material.Neon, 0.3, workspace)
		slashEffect.Position = Vector3.new(npcX, groundY + 2 * S, npcZ) + (CFrame.Angles(0, npcRotation, 0).LookVector * 2 * S)

		local slashParticles = Instance.new("ParticleEmitter")
		slashParticles.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, HOLLOW_CONFIG.VOID_SHIMMER), ColorSequenceKeypoint.new(1, HOLLOW_CONFIG.VOID_ABSOLUTE)})
		slashParticles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5 * S), NumberSequenceKeypoint.new(0.5, 1.5 * S), NumberSequenceKeypoint.new(1, 0)})
		slashParticles.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
		slashParticles.Lifetime = NumberRange.new(0.15, 0.3)
		slashParticles.Rate = 100
		slashParticles.Speed = NumberRange.new(15, 30)
		slashParticles.SpreadAngle = Vector2.new(45, 45)
		slashParticles.Parent = slashEffect

		Debris:AddItem(slashEffect, 0.5)
		task.wait(0.05)
		slashParticles.Enabled = false
		task.wait(0.2)

		for _, arm in ipairs(arms) do arm.attackAngle = 0 end
		for _, eyeData in ipairs(eyes) do
			if eyeData.light then
				TweenService:Create(eyeData.light, TweenInfo.new(0.3), {Color = HOLLOW_CONFIG.EYE_COLOR, Brightness = 4}):Play()
			end
			TweenService:Create(eyeData.glow, TweenInfo.new(0.3), {Color = HOLLOW_CONFIG.EYE_COLOR}):Play()
		end

		targetSmile = HOLLOW_CONFIG.SMILE_MIN
		Debris:AddItem(attackSound, 2)
		isAttacking = false
	end

	-- ---------------------------------------------------------------------------
	-- EFECTO DE MUERTE
	-- ---------------------------------------------------------------------------
	local function PlayDeathEffect()
		voidAura.Enabled = false
		distortionEmitter.Enabled = false
		footprintEmitter.Enabled = false
		whisperSound:Stop()
		staticSound:Stop()

		local deathSound = Instance.new("Sound")
		deathSound.SoundId = "rbxassetid://120923220505708"
		deathSound.Volume = 1.5
		deathSound.PlaybackSpeed = 0.2
		deathSound.Parent = torso
		deathSound: Play()

		for _, eyeData in ipairs(eyes) do
			if eyeData.light then TweenService:Create(eyeData.light, TweenInfo.new(0.4), {Brightness = 0}):Play() end
			TweenService:Create(eyeData.glow, TweenInfo.new(0.4), {Transparency = 1}):Play()
		end

		targetSmile = HOLLOW_CONFIG.SMILE_MAX * 1.5

		local deathParticles = Instance.new("ParticleEmitter")
		deathParticles.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, HOLLOW_CONFIG.VOID_SHIMMER), ColorSequenceKeypoint.new(1, HOLLOW_CONFIG.VOID_ABSOLUTE)})
		deathParticles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1 * S), NumberSequenceKeypoint.new(0.5, 2 * S), NumberSequenceKeypoint.new(1, 0)})
		deathParticles.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
		deathParticles.Lifetime = NumberRange.new(0.5, 1)
		deathParticles.Rate = 80
		deathParticles.Speed = NumberRange.new(3, 8)
		deathParticles.SpreadAngle = Vector2.new(180, 180)
		deathParticles.Parent = torso

		for _, part in pairs(npcModel:GetDescendants()) do
			if part:IsA("BasePart") then TweenService:Create(part, TweenInfo.new(0.6), {Transparency = 1}):Play() end
		end

		task.wait(0.7)
		deathParticles.Enabled = false
		Debris:AddItem(deathSound, 2)
	end

	-- ---------------------------------------------------------------------------
	-- IA PRINCIPAL
	-- ---------------------------------------------------------------------------
	local isAlive = true
	local lastAttackTime = 0

	local function FindNearestPlayer()
		local nearest, nearestDist = nil, HOLLOW_CONFIG.DETECTION_RANGE
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
		if tick() - lastAttackTime < HOLLOW_CONFIG.ATTACK_COOLDOWN then return end
		if isAttacking then return end
		lastAttackTime = tick()

		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChild("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")

		if hum and hum.Health > 0 and hrp then
			coroutine.wrap(function() PlayAttackAnimation(hrp.Position) end)()
			task.wait(0.2)

			local attackSound = Instance.new("Sound")
			attackSound.SoundId = "rbxassetid://5766332557"
			attackSound.Volume = 0.7
			attackSound.PlaybackSpeed = 0.8
			attackSound.Parent = torso
			attackSound:Play()

			local dist = (hrp.Position - Vector3.new(npcX, 0, npcZ)).Magnitude
			if dist < HOLLOW_CONFIG.ATTACK_RANGE + 2 and hum.Health > 0 then
				hum: TakeDamage(HOLLOW_CONFIG.DAMAGE)

				local hitEffect = CreatePart("HitEffect", Vector3.new(0.5, 0.5, 0.5), HOLLOW_CONFIG.VOID_SHIMMER, Enum.Material.Neon, 0.3, workspace)
				hitEffect.Shape = Enum.PartType.Ball
				hitEffect.Position = hrp.Position
				TweenService:Create(hitEffect, TweenInfo.new(0.25), {Size = Vector3.new(3, 3, 3), Transparency = 1}):Play()
				Debris:AddItem(hitEffect, 0.4)
			end

			Debris:AddItem(attackSound, 1.5)
		end
	end

	-- ---------------------------------------------------------------------------
	-- LOOP PRINCIPAL
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
			print("? Hollow Man lifetime expired after "..string.format("%.1f", elapsedTime).." seconds")
			isAlive = false
			if chaseConnection then chaseConnection: Disconnect() end
			PlayDeathEffect()
			task.wait(0.8)
			if npcFolder and npcFolder.Parent then
				npcFolder: Destroy()
			end
			return
		end

		-- STUNNED CHECK
		if npcModel:GetAttribute("Stunned") then
			UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, 999, nil)
			return
		end

		-- .CHECK
		if IsInLobby(npcX) then
			print("?? Hollow Man entered .- destroying")
			isAlive = false
			if chaseConnection then chaseConnection:Disconnect() end
			PlayDeathEffect()
			task.wait(0.7)
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
				local hrp = char: FindFirstChild("HumanoidRootPart")
				if hrp then
					targetPos = hrp.Position
					local direction = Vector3.new(hrp.Position.X - npcX, 0, hrp.Position.Z - npcZ)

					if direction.Magnitude > 0.5 then
						local lookAngle = math.atan2(-direction.X, -direction.Z)

						if not isFrozen then
							if distance > HOLLOW_CONFIG.ATTACK_RANGE then
								local moveSpeed
								if distance < 30 then
									moveSpeed = HOLLOW_CONFIG.SPEED_CHASE
									isRunningThisFrame = true
								else
									moveSpeed = HOLLOW_CONFIG.SPEED_STALK
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

		-- CONTROL DE SONIDOS
		if isRunningThisFrame and not isChasing then
			isChasing = true
			whisperSound:Stop()
			staticSound:Play()
		elseif not isRunningThisFrame and isChasing then
			isChasing = false
			staticSound:Stop()
			whisperSound:Play()
		end
	end)

	-- ---------------------------------------------------------------------------
	-- EFECTOS AMBIENTALES
	-- ---------------------------------------------------------------------------
	coroutine.wrap(function()
		while isAlive and head and head.Parent do
			task.wait(math.random(5, 12))
			if isAlive and head and head.Parent and not isAttacking then
				local whisper = Instance.new("Sound")
				whisper.SoundId = "rbxassetid://9114221580"
				whisper.Volume = 0.15
				whisper.PlaybackSpeed = 0.1 + math.random() * 0.15
				whisper.Parent = head
				whisper:Play()
				Debris:AddItem(whisper, 4)
			end
		end
	end)()

	coroutine.wrap(function()
		while isAlive and #eyes > 0 do
			task.wait(math.random(3, 7))
			if isAlive and not isAttacking then
				for _, eyeData in ipairs(eyes) do
					if eyeData.glow and eyeData.glow.Parent then
						local originalTrans = eyeData.glow.Transparency
						eyeData.glow.Transparency = 1
						eyeData.pupil.Transparency = 1
						task.wait(0.06)
						if eyeData.glow and eyeData.glow.Parent then
							eyeData.glow.Transparency = originalTrans
							eyeData.pupil.Transparency = 0
						end
					end
				end
			end
		end
	end)()

	npcFolder.AncestryChanged:Connect(function()
		if not npcFolder.Parent then
			isAlive = false
			whisperSound:Stop()
			staticSound:Stop()
			if chaseConnection then chaseConnection: Disconnect() end
		end
	end)

	return npcFolder
end

-- ===============================================================================
-- EVENT LISTENER - CORREGIDO PARA USAR SpawnNPCEvent (el evento del Shadow/Hollow)
-- ===============================================================================

-- Buscar el evento correcto que usa MainGameServer para el SHADOW/HOLLOW
local SpawnNPCEvent = ReplicatedStorage:FindFirstChild("SpawnNPCEvent")

if SpawnNPCEvent then
	print("? SpawnNPCEvent FOUND - Connecting Hollow Man spawner...")
	SpawnNPCEvent.Event:Connect(function(position, player, side, zDir, doorFrameInfo, lifetime)
		print("=====================================")
		print("?????? SpawnNPCEvent RECEIVED!")
		print("   Position: "..tostring(position))
		print("   Player: "..tostring(player))
		print("   Side: "..tostring(side))
		print("   zDir: "..tostring(zDir))
		print("   Lifetime: "..tostring(lifetime))
		print("=====================================")
		task.wait(0.3)
		CreateHollowManNPC(position, player, side, zDir, doorFrameInfo, lifetime)
	end)
	print("? Hollow Man spawner connected to SpawnNPCEvent!")
else
	warn("? SpawnNPCEvent NOT FOUND!")
end

-- También conectar a SpawnHollowManEvent si existe (por si se usa ese nombre)
if SpawnHollowManEvent then
	print("? SpawnHollowManEvent also found - Connecting...")
	SpawnHollowManEvent.Event:Connect(function(position, player, side, zDir, doorFrameInfo, lifetime)
		print("=====================================")
		print("?????? SpawnHollowManEvent RECEIVED!")
		print("   Position: "..tostring(position))
		print("   Lifetime: "..tostring(lifetime))
		print("=====================================")
		task.wait(0.3)
		CreateHollowManNPC(position, player, side, zDir, doorFrameInfo, lifetime)
	end)
end

print("=== HOLLOW MAN HORROR SYSTEM V7 - LOADED ===")
print("   Stalk Speed: "..HOLLOW_CONFIG.SPEED_STALK)
print("   Chase Speed: "..HOLLOW_CONFIG.SPEED_CHASE)
print("   Attack Range: "..HOLLOW_CONFIG.ATTACK_RANGE)
print("   Scale: "..S.."x")
print("   Listening for:  SpawnNPCEvent")
print("============================================")