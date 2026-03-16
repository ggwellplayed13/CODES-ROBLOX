--[[
    +------------------------------------------------------------------------------+
    |                    HUMANOID HORROR ENTITY SYSTEM                              |
    |                 VERSIÓN 2 - "THE SCREAMER"                                    |
    |                      TERROR AUDITIVO - PESADILLA SONORA                       |
    +------------------------------------------------------------------------------+
    
    Una criatura humanoide grotescamente invertida:    
    - Postura invertida - camina con las MANOS, piernas hacia arriba
    - CARA MIRANDO HACIA ADELANTE (corregido)
    - Boca ENORME - ocupa 70% de la cara con 5 filas de dientes
    - Sin ojos - solo cuencas vacías que lloran sangre NEGRA
    - Orejas gigantes - con 6 segmentos que GIRAN independientemente
    - Garganta visible - cuerdas vocales pulsantes cuando grita
    - Piel gris ceniza - con grietas que revelan oscuridad interior púrpura
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local SpawnScreamerEvent = ReplicatedStorage:WaitForChild("SpawnScreamerEvent", 10)

-- -------------------------------------------------------------------------------
-- CONFIGURACIÓN
-- -------------------------------------------------------------------------------
local HORROR_CONFIG = {
	SCALE = 2.0,

	-- VELOCIDADES
	SPEED_LISTENING = 0,
	SPEED_TRACKING = 34,
	SPEED_STALKING = 30,
	SPEED_SCREAMING = 0,

	-- DISTANCIAS
	DETECTION_RANGE = 250,
	TRACKING_THRESHOLD = 150,
	STALKING_THRESHOLD = 40,
	ATTACK_RANGE = 6,
	SCREAM_RANGE = 25,

	-- COMBATE
	DAMAGE_NORMAL = 35,
	DAMAGE_SCREAM = 40,
	ATTACK_COOLDOWN = 0.6,
	SCREAM_COOLDOWN = 8,
	PARALYSIS_DURATION = 3,
	KNOCKBACK_FORCE = 80,

	-- COLORES
	SKIN_ASH = Color3.fromRGB(85, 80, 78),
	SKIN_ASH_LIGHT = Color3.fromRGB(95, 90, 88),
	SKIN_ASH_DARK = Color3.fromRGB(65, 60, 58),
	SKIN_CRACK = Color3.fromRGB(45, 40, 38),

	INNER_PURPLE = Color3.fromRGB(80, 20, 100),
	INNER_PURPLE_DARK = Color3.fromRGB(50, 10, 70),
	INNER_PURPLE_GLOW = Color3.fromRGB(120, 40, 160),

	BLOOD_BLACK = Color3.fromRGB(15, 10, 12),
	BLOOD_BLACK_SHINE = Color3.fromRGB(25, 18, 22),

	MOUTH_INTERIOR = Color3.fromRGB(30, 15, 20),
	MOUTH_DEEP = Color3.fromRGB(10, 5, 8),
	GUM_COLOR = Color3.fromRGB(60, 30, 40),
	TEETH_WHITE = Color3.fromRGB(230, 225, 220),
	TEETH_YELLOW = Color3.fromRGB(200, 180, 140),
	TEETH_ROTTEN = Color3.fromRGB(80, 70, 50),

	THROAT_FLESH = Color3.fromRGB(100, 50, 60),
	VOCAL_CORDS = Color3.fromRGB(150, 70, 90),
	VOCAL_CORDS_ACTIVE = Color3.fromRGB(200, 100, 130),

	EAR_OUTER = Color3.fromRGB(75, 70, 68),
	EAR_INNER = Color3.fromRGB(90, 50, 60),
	EAR_MEMBRANE = Color3.fromRGB(110, 70, 85),

	SOCKET_VOID = Color3.fromRGB(5, 3, 5),
	SOCKET_EDGE = Color3.fromRGB(40, 30, 35),

	NAIL_BLACK = Color3.fromRGB(25, 20, 18),

	-- DIMENSIONES
	HEAD_SIZE = Vector3.new(1.0, 1.2, 1.0),
	TORSO_SIZE = Vector3.new(1.4, 1.6, 0.7),
	PELVIS_SIZE = Vector3.new(1.0, 0.5, 0.5),

	UPPER_ARM_SIZE = Vector3.new(0.25, 1.4, 0.25),
	FOREARM_SIZE = Vector3.new(0.22, 1.5, 0.22),
	HAND_SIZE = Vector3.new(0.5, 0.2, 0.7),
	FINGER_LENGTH = 0.45,

	THIGH_SIZE = Vector3.new(0.28, 1.3, 0.28),
	SHIN_SIZE = Vector3.new(0.24, 1.4, 0.24),
	FOOT_SIZE = Vector3.new(0.25, 0.5, 0.18),

	EAR_SIZE = Vector3.new(0.4, 0.8, 0.1),
	EAR_SEGMENTS = 6,

	MOUTH_WIDTH = 0.75,
	MOUTH_HEIGHT = 0.6,
	TEETH_ROWS = 5,

	LISTENING_DURATION = 3.0,
	EAR_ROTATION_SPEED = 2.5,
	TWITCH_FREQUENCY = 0.15,
	CRACK_PULSE_SPEED = 1.5,

	STATE_LISTENING = 1,
	STATE_TRACKING = 2,
	STATE_STALKING = 3,
	STATE_SCREAMING = 4,

	LOBBY_START_X = -75,
	LOBBY_END_X = 75,
}

-- Aplicar escala
local S = HORROR_CONFIG.SCALE
HORROR_CONFIG.HEAD_SIZE = HORROR_CONFIG.HEAD_SIZE * S
HORROR_CONFIG.TORSO_SIZE = HORROR_CONFIG.TORSO_SIZE * S
HORROR_CONFIG.PELVIS_SIZE = HORROR_CONFIG.PELVIS_SIZE * S
HORROR_CONFIG.UPPER_ARM_SIZE = HORROR_CONFIG.UPPER_ARM_SIZE * S
HORROR_CONFIG.FOREARM_SIZE = HORROR_CONFIG.FOREARM_SIZE * S
HORROR_CONFIG.HAND_SIZE = HORROR_CONFIG.HAND_SIZE * S
HORROR_CONFIG.THIGH_SIZE = HORROR_CONFIG.THIGH_SIZE * S
HORROR_CONFIG.SHIN_SIZE = HORROR_CONFIG.SHIN_SIZE * S
HORROR_CONFIG.FOOT_SIZE = HORROR_CONFIG.FOOT_SIZE * S
HORROR_CONFIG.EAR_SIZE = HORROR_CONFIG.EAR_SIZE * S
HORROR_CONFIG.FINGER_LENGTH = HORROR_CONFIG.FINGER_LENGTH * S
HORROR_CONFIG.MOUTH_WIDTH = HORROR_CONFIG.MOUTH_WIDTH * S
HORROR_CONFIG.MOUTH_HEIGHT = HORROR_CONFIG.MOUTH_HEIGHT * S

local function IsInLobby(x)
	return x >= HORROR_CONFIG.LOBBY_START_X and x <= HORROR_CONFIG.LOBBY_END_X
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

local function LerpAngle(a, b, t)
	local diff = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + diff * t
end

-- -------------------------------------------------------------------------------
-- CREAR THE SCREAMER
-- -------------------------------------------------------------------------------

local function CreateHorrorNPC(spawnPosition, triggerPlayer, side, zDir, doorFrameInfo, lifetime)
	local npcLifetime = lifetime or 60

	print("===========================================")
	print("???? THE SCREAMER V2 SPAWNED ????")
	print("   Scale: "..S.."x")
	print("   Lifetime: "..npcLifetime.." seconds")
	print("===========================================")

	local npcFolder = Instance.new("Folder")
	npcFolder.Name = "HorrorEntity"
	npcFolder.Parent = workspace

	local npcModel = Instance.new("Model")
	npcModel.Name = "TheScreamer"
	npcModel.Parent = npcFolder

	local spawnTime = tick()
	npcFolder: SetAttribute("SpawnTime", spawnTime)
	npcFolder:SetAttribute("Lifetime", npcLifetime)
	npcModel:SetAttribute("SpawnTime", spawnTime)
	npcModel:SetAttribute("Lifetime", npcLifetime)
	npcModel:SetAttribute("BodyCharge", 0)
	npcModel:SetAttribute("HeadCharge", 0)
	npcModel:SetAttribute("Stunned", false)
	npcModel:SetAttribute("StunDuration", 3)

	local groundY = 0.5
	local handHeight = HORROR_CONFIG.HAND_SIZE.Y
	local armLength = HORROR_CONFIG.UPPER_ARM_SIZE.Y + HORROR_CONFIG.FOREARM_SIZE.Y
	local torsoHeight = groundY + handHeight + armLength * 0.85

	-- ---------------------------------------------------------------------------
	-- TORSO
	-- ---------------------------------------------------------------------------

	local torso = CreatePart(
		"Torso",
		HORROR_CONFIG.TORSO_SIZE,
		HORROR_CONFIG.SKIN_ASH,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	torso.CanCollide = true

	local pelvis = CreatePart(
		"Pelvis",
		HORROR_CONFIG.PELVIS_SIZE,
		HORROR_CONFIG.SKIN_ASH_DARK,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)

	-- Grietas en el torso
	local cracks = {}
	local crackPositions = {
		{x = 0.25, y = 0.25, z = 0.48, rotZ = 15},
		{x = -0.2, y = 0.1, z = 0.48, rotZ = -20},
		{x = 0.1, y = -0.15, z = 0.48, rotZ = 5},
		{x = -0.3, y = -0.25, z = 0.48, rotZ = -10},
		{x = 0.2, y = 0.0, z = -0.48, rotZ = 25},
		{x = -0.1, y = 0.2, z = -0.48, rotZ = -15},
	}

	for i, pos in ipairs(crackPositions) do
		local crackLength = (0.2 + math.random() * 0.15) * S

		local crack = CreatePart(
			"Crack"..i,
			Vector3.new(0.025 * S, crackLength, 0.012 * S),
			HORROR_CONFIG.SKIN_CRACK,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)

		local innerGlow = CreatePart(
			"CrackGlow"..i,
			Vector3.new(0.018 * S, crackLength * 0.85, 0.008 * S),
			HORROR_CONFIG.INNER_PURPLE_GLOW,
			Enum.Material.Neon,
			0.3,
			npcModel
		)

		local glowLight = Instance.new("PointLight")
		glowLight.Brightness = 0.25
		glowLight.Color = HORROR_CONFIG.INNER_PURPLE_GLOW
		glowLight.Range = 1.2 * S
		glowLight.Parent = innerGlow

		table.insert(cracks, {
			outer = crack,
			inner = innerGlow,
			light = glowLight,
			offset = Vector3.new(
				pos.x * HORROR_CONFIG.TORSO_SIZE.X,
				pos.y * HORROR_CONFIG.TORSO_SIZE.Y,
				pos.z * HORROR_CONFIG.TORSO_SIZE.Z
			),
			rotation = CFrame.Angles(0, 0, math.rad(pos.rotZ)),
			pulsePhase = math.random() * math.pi * 2
		})
	end

	-- Columna vertebral
	local spineSegments = {}
	for i = 1, 7 do
		local vertebra = CreatePart(
			"Vertebra"..i,
			Vector3.new(0.1 * S, 0.1 * S, 0.12 * S),
			HORROR_CONFIG.SKIN_ASH_DARK,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		CreateMesh(vertebra, Enum.MeshType.Sphere)
		table.insert(spineSegments, {part = vertebra, index = i})
	end

	-- ---------------------------------------------------------------------------
	-- CUELLO - Más largo y flexible para que la cabeza mire adelante
	-- ---------------------------------------------------------------------------

	local neckSegments = {}
	local numNeckSegs = 4
	for i = 1, numNeckSegs do
		local segSize = (0.22 - (i-1) * 0.02) * S
		local segment = CreatePart(
			"NeckSeg"..i,
			Vector3.new(segSize, 0.12 * S, segSize),
			HORROR_CONFIG.SKIN_ASH,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		CreateMesh(segment, Enum.MeshType.Cylinder)
		table.insert(neckSegments, {part = segment, index = i})
	end

	-- Garganta
	local throat = CreatePart(
		"Throat",
		Vector3.new(0.15 * S, 0.18 * S, 0.08 * S),
		HORROR_CONFIG.THROAT_FLESH,
		Enum.Material.SmoothPlastic,
		0.15,
		npcModel
	)
	CreateMesh(throat, Enum.MeshType.Sphere, Vector3.new(1, 1.2, 0.6))

	-- Cuerdas vocales
	local vocalCords = {}
	for i = 1, 3 do
		local cord = CreatePart(
			"VocalCord"..i,
			Vector3.new(0.01 * S, 0.08 * S, 0.006 * S),
			HORROR_CONFIG.VOCAL_CORDS,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)

		local cordLight = Instance.new("PointLight")
		cordLight.Brightness = 0
		cordLight.Color = HORROR_CONFIG.VOCAL_CORDS_ACTIVE
		cordLight.Range = 1.5 * S
		cordLight.Parent = cord

		table.insert(vocalCords, {
			part = cord,
			light = cordLight,
			xOff = (i - 2) * 0.025 * S,
			vibrationPhase = math.random() * math.pi * 2
		})
	end

	-- ---------------------------------------------------------------------------
	-- CABEZA
	-- ---------------------------------------------------------------------------

	local head = CreatePart(
		"Head",
		HORROR_CONFIG.HEAD_SIZE,
		HORROR_CONFIG.SKIN_ASH,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	CreateMesh(head, Enum.MeshType.Sphere, Vector3.new(1, 1.1, 0.95))

	-- Grietas de la cabeza
	local headCracks = {}
	local headCrackPositions = {
		{x = 0.3, y = 0.25, z = 0.15},
		{x = -0.25, y = 0.3, z = 0.2},
		{x = 0.2, y = -0.1, z = 0.35},
		{x = -0.3, y = 0.05, z = 0.25},
	}

	for i, pos in ipairs(headCrackPositions) do
		local crack = CreatePart(
			"HeadCrack"..i,
			Vector3.new(0.018 * S, 0.12 * S, 0.008 * S),
			HORROR_CONFIG.SKIN_CRACK,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)

		local innerGlow = CreatePart(
			"HeadCrackGlow"..i,
			Vector3.new(0.012 * S, 0.1 * S, 0.006 * S),
			HORROR_CONFIG.INNER_PURPLE_GLOW,
			Enum.Material.Neon,
			0.4,
			npcModel
		)

		table.insert(headCracks, {
			outer = crack,
			inner = innerGlow,
			offset = Vector3.new(
				pos.x * HORROR_CONFIG.HEAD_SIZE.X,
				pos.y * HORROR_CONFIG.HEAD_SIZE.Y,
				pos.z * HORROR_CONFIG.HEAD_SIZE.Z
			),
			pulsePhase = math.random() * math.pi * 2
		})
	end

	-- ---------------------------------------------------------------------------
	-- CUENCAS VACÍAS
	-- ---------------------------------------------------------------------------

	local eyeSockets = {}
	local socketConfigs = {
		{x = -0.25, y = 0.18, z = -0.4, size = 0.15 * S},
		{x = 0.25, y = 0.18, z = -0.4, size = 0.15 * S},
	}

	for i, config in ipairs(socketConfigs) do
		local socketOuter = CreatePart(
			"SocketOuter"..i,
			Vector3.new(config.size * 1.3, config.size * 1.1, config.size * 0.4),
			HORROR_CONFIG.SOCKET_EDGE,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		CreateMesh(socketOuter, Enum.MeshType.Sphere)

		local socketVoid = CreateBallPart(
			"SocketVoid"..i,
			config.size * 0.6,
			HORROR_CONFIG.SOCKET_VOID,
			Enum.Material.SmoothPlastic,
			npcModel
		)

		local bloodTrails = {}
		for t = 1, 3 do
			local trailLength = (0.15 + math.random() * 0.1) * S
			local trail = CreatePart(
				"BloodTrail"..i.."_"..t,
				Vector3.new(0.015 * S, trailLength, 0.012 * S),
				HORROR_CONFIG.BLOOD_BLACK,
				Enum.Material.SmoothPlastic,
				0,
				npcModel
			)

			table.insert(bloodTrails, {
				part = trail,
				xOff = (t - 2) * 0.025 * S,
				length = trailLength,
				flowPhase = math.random() * math.pi * 2
			})
		end

		local bloodEmitter = Instance.new("ParticleEmitter")
		bloodEmitter.Texture = "rbxassetid://243098098"
		bloodEmitter.Color = ColorSequence.new(HORROR_CONFIG.BLOOD_BLACK)
		bloodEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.015 * S),
			NumberSequenceKeypoint.new(1, 0.008 * S)
		})
		bloodEmitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1)
		})
		bloodEmitter.Lifetime = NumberRange.new(0.3, 0.6)
		bloodEmitter.Rate = 2
		bloodEmitter.Speed = NumberRange.new(0.1, 0.2)
		bloodEmitter.Acceleration = Vector3.new(0, -8, 0)
		bloodEmitter.Parent = socketVoid

		table.insert(eyeSockets, {
			outer = socketOuter,
			void = socketVoid,
			bloodTrails = bloodTrails,
			emitter = bloodEmitter,
			config = {
				x = config.x * HORROR_CONFIG.HEAD_SIZE.X,
				y = config.y * HORROR_CONFIG.HEAD_SIZE.Y,
				z = config.z * HORROR_CONFIG.HEAD_SIZE.Z,
				size = config.size
			}
		})
	end

	-- ---------------------------------------------------------------------------
	-- OREJAS GIGANTES
	-- ---------------------------------------------------------------------------

	local ears = {}
	for sideNum = -1, 1, 2 do
		local earFolder = Instance.new("Folder")
		earFolder.Name = sideNum == -1 and "LeftEar" or "RightEar"
		earFolder.Parent = npcModel

		local earBase = CreatePart(
			"EarBase",
			Vector3.new(0.12 * S, 0.15 * S, 0.08 * S),
			HORROR_CONFIG.EAR_OUTER,
			Enum.Material.SmoothPlastic,
			0,
			earFolder
		)
		CreateMesh(earBase, Enum.MeshType.Sphere)

		local segments = {}
		local segmentHeight = HORROR_CONFIG.EAR_SIZE.Y / HORROR_CONFIG.EAR_SEGMENTS

		for seg = 1, HORROR_CONFIG.EAR_SEGMENTS do
			local segWidth = HORROR_CONFIG.EAR_SIZE.X * (1 - (seg - 1) * 0.1)

			local segment = CreatePart(
				"EarSegment"..seg,
				Vector3.new(segWidth, segmentHeight * 0.85, HORROR_CONFIG.EAR_SIZE.Z),
				LerpColor(HORROR_CONFIG.EAR_OUTER, HORROR_CONFIG.EAR_INNER, (seg - 1) / HORROR_CONFIG.EAR_SEGMENTS),
				Enum.Material.SmoothPlastic,
				0,
				earFolder
			)

			local membrane = CreatePart(
				"EarMembrane"..seg,
				Vector3.new(segWidth * 0.55, segmentHeight * 0.65, 0.012 * S),
				HORROR_CONFIG.EAR_MEMBRANE,
				Enum.Material.SmoothPlastic,
				0.35,
				earFolder
			)

			table.insert(segments, {
				part = segment,
				membrane = membrane,
				index = seg,
				width = segWidth,
				currentRotation = 0,
				targetRotation = 0,
				rotationSpeed = (0.8 + math.random() * 0.4) * HORROR_CONFIG.EAR_ROTATION_SPEED
			})
		end

		table.insert(ears, {
			folder = earFolder,
			base = earBase,
			segments = segments,
			side = sideNum,
			listeningPhase = math.random() * math.pi * 2
		})
	end

	-- ---------------------------------------------------------------------------
	-- BOCA GIGANTE
	-- ---------------------------------------------------------------------------

	local upperLip = CreatePart(
		"UpperLip",
		Vector3.new(HORROR_CONFIG.MOUTH_WIDTH, 0.06 * S, 0.12 * S),
		HORROR_CONFIG.SKIN_ASH_DARK,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	CreateMesh(upperLip, Enum.MeshType.Sphere, Vector3.new(1, 0.5, 0.8))

	local lowerJaw = CreatePart(
		"LowerJaw",
		Vector3.new(HORROR_CONFIG.MOUTH_WIDTH * 0.95, 0.15 * S, 0.15 * S),
		HORROR_CONFIG.SKIN_ASH_DARK,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	CreateMesh(lowerJaw, Enum.MeshType.Sphere, Vector3.new(1, 0.7, 0.9))

	local mouthInterior = CreatePart(
		"MouthInterior",
		Vector3.new(HORROR_CONFIG.MOUTH_WIDTH * 0.8, HORROR_CONFIG.MOUTH_HEIGHT * 0.45, 0.2 * S),
		HORROR_CONFIG.MOUTH_INTERIOR,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)

	local mouthAbyss = CreatePart(
		"MouthAbyss",
		Vector3.new(HORROR_CONFIG.MOUTH_WIDTH * 0.55, HORROR_CONFIG.MOUTH_HEIGHT * 0.3, 0.25 * S),
		HORROR_CONFIG.MOUTH_DEEP,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)

	-- 5 Filas de dientes
	local teethRows = {}
	for row = 1, HORROR_CONFIG.TEETH_ROWS do
		local rowTeeth = {}
		local teethPerRow = 8 - (row - 1) * 1
		local rowDepth = (row - 1) * 0.035 * S
		local rowWidth = HORROR_CONFIG.MOUTH_WIDTH * (1 - (row - 1) * 0.12)

		for t = 1, teethPerRow do
			local xPos = (t - (teethPerRow + 1) / 2) * (rowWidth * 0.85 / teethPerRow)
			local isRotten = math.random() < (0.1 + row * 0.08)
			local toothHeight = (0.06 + row * 0.012) * S
			local toothColor = isRotten and HORROR_CONFIG.TEETH_ROTTEN or
				(math.random() < 0.5 and HORROR_CONFIG.TEETH_WHITE or HORROR_CONFIG.TEETH_YELLOW)

			local toothUpper = CreatePart(
				"ToothUpper_R"..row.."_"..t,
				Vector3.new(0.025 * S, toothHeight, 0.02 * S),
				toothColor,
				Enum.Material.SmoothPlastic,
				0,
				npcModel
			)

			local toothLower = CreatePart(
				"ToothLower_R"..row.."_"..t,
				Vector3.new(0.022 * S, toothHeight * 0.85, 0.018 * S),
				math.random() < 0.3 and HORROR_CONFIG.TEETH_ROTTEN or HORROR_CONFIG.TEETH_YELLOW,
				Enum.Material.SmoothPlastic,
				0,
				npcModel
			)

			table.insert(rowTeeth, {
				upper = toothUpper,
				lower = toothLower,
				xPos = xPos,
				angle = (math.random() - 0.5) * math.rad(8)
			})
		end

		table.insert(teethRows, {
			teeth = rowTeeth,
			row = row,
			depth = rowDepth,
			width = rowWidth
		})
	end

	local tongue = CreatePart(
		"Tongue",
		Vector3.new(0.15 * S, 0.05 * S, 0.25 * S),
		HORROR_CONFIG.THROAT_FLESH,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	CreateMesh(tongue, Enum.MeshType.Sphere, Vector3.new(1, 0.4, 1.3))

	-- ---------------------------------------------------------------------------
	-- BRAZOS
	-- ---------------------------------------------------------------------------

	local arms = {}
	for sideNum = -1, 1, 2 do
		local armFolder = Instance.new("Folder")
		armFolder.Name = sideNum == -1 and "LeftArm" or "RightArm"
		armFolder.Parent = npcModel

		local shoulder = CreateBallPart("Shoulder", 0.22 * S, HORROR_CONFIG.SKIN_ASH, Enum.Material.SmoothPlastic, armFolder)
		local upperArm = CreatePart("UpperArm", HORROR_CONFIG.UPPER_ARM_SIZE, HORROR_CONFIG.SKIN_ASH, Enum.Material.SmoothPlastic, 0, armFolder)
		CreateMesh(upperArm, Enum.MeshType.Cylinder)
		local elbow = CreateBallPart("Elbow", 0.14 * S, HORROR_CONFIG.SKIN_ASH_DARK, Enum.Material.SmoothPlastic, armFolder)
		local forearm = CreatePart("Forearm", HORROR_CONFIG.FOREARM_SIZE, HORROR_CONFIG.SKIN_ASH, Enum.Material.SmoothPlastic, 0, armFolder)
		CreateMesh(forearm, Enum.MeshType.Cylinder)
		local wrist = CreateBallPart("Wrist", 0.09 * S, HORROR_CONFIG.SKIN_ASH_DARK, Enum.Material.SmoothPlastic, armFolder)
		local hand = CreatePart("Hand", HORROR_CONFIG.HAND_SIZE, HORROR_CONFIG.SKIN_ASH, Enum.Material.SmoothPlastic, 0, armFolder)
		CreateMesh(hand, Enum.MeshType.Sphere, Vector3.new(1, 0.45, 1.15))

		local fingers = {}
		for f = 1, 5 do
			local segments = {}
			local segLengths = {0.35, 0.3, 0.25}

			for seg = 1, 3 do
				local segWidth = (0.035 - seg * 0.004) * S
				local segment = CreatePart(
					"Finger"..f.."_Seg"..seg,
					Vector3.new(segWidth, HORROR_CONFIG.FINGER_LENGTH * segLengths[seg], segWidth),
					HORROR_CONFIG.SKIN_ASH_DARK,
					Enum.Material.SmoothPlastic,
					0,
					armFolder
				)
				local joint = CreateBallPart("FingerJoint"..f.."_"..seg, segWidth * 1.1, HORROR_CONFIG.SKIN_ASH, Enum.Material.SmoothPlastic, armFolder)
				table.insert(segments, {part = segment, joint = joint, width = segWidth})
			end

			local claw = CreatePart("Claw"..f, Vector3.new(0.02 * S, 0.08 * S, 0.035 * S), HORROR_CONFIG.NAIL_BLACK, Enum.Material.SmoothPlastic, 0, armFolder)
			CreateMesh(claw, Enum.MeshType.Wedge)

			table.insert(fingers, {
				segments = segments,
				claw = claw,
				index = f,
				xOff = (f - 3) * 0.085 * S,
				isThumb = f == 1
			})
		end

		table.insert(arms, {
			folder = armFolder,
			shoulder = shoulder,
			upperArm = upperArm,
			elbow = elbow,
			forearm = forearm,
			wrist = wrist,
			hand = hand,
			fingers = fingers,
			side = sideNum
		})
	end

	-- ---------------------------------------------------------------------------
	-- PIERNAS
	-- ---------------------------------------------------------------------------

	local legs = {}
	for sideNum = -1, 1, 2 do
		local legFolder = Instance.new("Folder")
		legFolder.Name = sideNum == -1 and "LeftLeg" or "RightLeg"
		legFolder.Parent = npcModel

		local hip = CreateBallPart("Hip", 0.2 * S, HORROR_CONFIG.SKIN_ASH, Enum.Material.SmoothPlastic, legFolder)
		local thigh = CreatePart("Thigh", HORROR_CONFIG.THIGH_SIZE, HORROR_CONFIG.SKIN_ASH, Enum.Material.SmoothPlastic, 0, legFolder)
		CreateMesh(thigh, Enum.MeshType.Cylinder)
		local knee = CreateBallPart("Knee", 0.15 * S, HORROR_CONFIG.SKIN_ASH_DARK, Enum.Material.SmoothPlastic, legFolder)
		local shin = CreatePart("Shin", HORROR_CONFIG.SHIN_SIZE, HORROR_CONFIG.SKIN_ASH, Enum.Material.SmoothPlastic, 0, legFolder)
		CreateMesh(shin, Enum.MeshType.Cylinder)
		local ankle = CreateBallPart("Ankle", 0.1 * S, HORROR_CONFIG.SKIN_ASH_DARK, Enum.Material.SmoothPlastic, legFolder)
		local foot = CreatePart("Foot", HORROR_CONFIG.FOOT_SIZE, HORROR_CONFIG.SKIN_ASH_DARK, Enum.Material.SmoothPlastic, 0, legFolder)
		CreateMesh(foot, Enum.MeshType.Sphere, Vector3.new(0.6, 1, 0.5))

		table.insert(legs, {
			folder = legFolder,
			hip = hip,
			thigh = thigh,
			knee = knee,
			shin = shin,
			ankle = ankle,
			foot = foot,
			side = sideNum
		})
	end

	-- ---------------------------------------------------------------------------
	-- PARTÍCULAS
	-- ---------------------------------------------------------------------------

	local darkAura = Instance.new("ParticleEmitter")
	darkAura.Texture = "rbxassetid://243098098"
	darkAura.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, HORROR_CONFIG.INNER_PURPLE_DARK),
		ColorSequenceKeypoint.new(1, HORROR_CONFIG.INNER_PURPLE)
	})
	darkAura.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15 * S),
		NumberSequenceKeypoint.new(0.5, 0.6 * S),
		NumberSequenceKeypoint.new(1, 1.1 * S)
	})
	darkAura.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.5, 0.85),
		NumberSequenceKeypoint.new(1, 1)
	})
	darkAura.Lifetime = NumberRange.new(0.4, 0.8)
	darkAura.Rate = 6
	darkAura.Speed = NumberRange.new(0.15, 0.6)
	darkAura.SpreadAngle = Vector2.new(360, 360)
	darkAura.Parent = torso

	-- ---------------------------------------------------------------------------
	-- VARIABLES DE ESTADO
	-- ---------------------------------------------------------------------------

	local npcX = spawnPosition.X
	local npcZ = spawnPosition.Z
	local npcRotation = zDir > 0 and 0 or math.pi

	local animTime = 0
	local breathTime = 0
	local mouthOpen = 0.1
	local currentState = HORROR_CONFIG.STATE_LISTENING
	local stateTimer = 0
	local isWalking = false
	local isAttacking = false
	local isScreaming = false
	local lastScreamTime = -HORROR_CONFIG.SCREAM_COOLDOWN
	local currentSpeed = HORROR_CONFIG.SPEED_LISTENING

	-- ---------------------------------------------------------------------------
	-- FUNCIÓN DE ACTUALIZACIÓN - CORREGIDA
	-- ---------------------------------------------------------------------------

	local function UpdateNPCPosition(x, z, rotY, walking, deltaTime, targetDistance, targetPos)
		npcX = x
		npcZ = z
		npcRotation = rotY or npcRotation
		isWalking = walking or false

		if deltaTime then
			animTime = animTime + deltaTime * 5
			breathTime = breathTime + deltaTime * 2
		end

		local walkBob = isWalking and math.sin(animTime * 2) * 0.08 * S or 0
		local walkSway = isWalking and math.sin(animTime * 1.5) * 0.06 * S or 0

		local twitchX, twitchY, twitchZ = 0, 0, 0
		if math.random() < HORROR_CONFIG.TWITCH_FREQUENCY * deltaTime * 60 then
			twitchX = (math.random() - 0.5) * 0.08 * S
			twitchY = (math.random() - 0.5) * 0.06 * S
			twitchZ = (math.random() - 0.5) * 0.08 * S
		end

		-- =====================================================================
		-- POSICIÓN BASE DEL TORSO
		-- El torso está inclinado hacia adelante, NO completamente invertido
		-- Esto permite que la cabeza mire hacia donde camina
		-- =====================================================================

		local torsoY = torsoHeight + walkBob

		-- El torso se inclina hacia adelante (como si estuviera gateando)
		-- No está completamente invertido (180°), sino inclinado (~120°)
		local torsoLean = math.rad(115)  -- Inclinación del torso

		local baseCFrame = CFrame.new(x + walkSway + twitchX, torsoY + twitchY, z + twitchZ)
			* CFrame.Angles(0, npcRotation, 0)
			* CFrame.Angles(torsoLean, 0, 0)

		-- -----------------------------------------------------------------------
		-- TORSO
		-- -----------------------------------------------------------------------
		torso.CFrame = baseCFrame

		-- Pelvis (hacia arriba/atrás del torso)
		local pelvisOffset = CFrame.new(0, -HORROR_CONFIG.TORSO_SIZE.Y * 0.55, 0)
		pelvis.CFrame = baseCFrame * pelvisOffset

		-- Grietas
		for _, crack in ipairs(cracks) do
			local pulse = 0.5 + 0.5 * math.sin(breathTime * HORROR_CONFIG.CRACK_PULSE_SPEED + crack.pulsePhase)
			crack.outer.CFrame = baseCFrame * CFrame.new(crack.offset) * crack.rotation
			crack.inner.CFrame = crack.outer.CFrame * CFrame.new(0, 0, 0.006 * S)
			if crack.light then
				crack.light.Brightness = 0.12 + pulse * 0.3
			end
		end

		-- Columna
		for i, seg in ipairs(spineSegments) do
			local spineY = HORROR_CONFIG.TORSO_SIZE.Y * 0.3 - (i - 1) * 0.12 * S
			seg.part.CFrame = baseCFrame * CFrame.new(0, spineY, HORROR_CONFIG.TORSO_SIZE.Z * 0.48)
		end

		-- -----------------------------------------------------------------------
		-- CUELLO - Se curva para que la cabeza mire HACIA ADELANTE
		-- -----------------------------------------------------------------------

		local neckBasePos = baseCFrame * CFrame.new(0, HORROR_CONFIG.TORSO_SIZE.Y * 0.5, 0)

		-- El cuello se curva hacia adelante/abajo para compensar la inclinación del torso
		-- y hacer que la cara mire hacia donde camina
		local neckBendAngle = math.rad(-75)  -- Curva el cuello hacia adelante

		local neckLength = 0.4 * S
		local neckEndPos = neckBasePos 
			* CFrame.new(0, neckLength * 0.3, -neckLength * 0.7)
			* CFrame.Angles(neckBendAngle, 0, 0)

		-- Posicionar segmentos del cuello
		for i, seg in ipairs(neckSegments) do
			local t = i / #neckSegments
			local segPos = neckBasePos: Lerp(neckEndPos, t)
			seg.part.CFrame = segPos * CFrame.Angles(0, 0, math.rad(90))
		end

		-- Garganta (visible en el frente)
		throat.CFrame = neckEndPos * CFrame.new(0, 0, -0.08 * S)

		-- Cuerdas vocales
		local vocalVibration = isScreaming and 1 or 0
		for _, cord in ipairs(vocalCords) do
			local vibrate = math.sin(animTime * 35 + cord.vibrationPhase) * 0.012 * S * vocalVibration
			cord.part.CFrame = throat.CFrame * CFrame.new(cord.xOff + vibrate, 0, 0.015 * S)
			cord.part.Color = isScreaming and HORROR_CONFIG.VOCAL_CORDS_ACTIVE or HORROR_CONFIG.VOCAL_CORDS
			if cord.light then
				cord.light.Brightness = vocalVibration * 2
			end
		end

		-- -----------------------------------------------------------------------
		-- CABEZA - MIRANDO HACIA ADELANTE
		-- -----------------------------------------------------------------------

		-- La cabeza está al final del cuello, mirando hacia adelante
		local headCFrame = neckEndPos 
			* CFrame.new(0, HORROR_CONFIG.HEAD_SIZE.Y * 0.4, -0.1 * S)
			* CFrame.Angles(math.rad(-25), 0, 0)  -- Ligera inclinación para mirar al frente

		head.CFrame = headCFrame

		-- Grietas de la cabeza
		for _, crack in ipairs(headCracks) do
			crack.outer.CFrame = headCFrame * CFrame.new(crack.offset)
			crack.inner.CFrame = crack.outer.CFrame * CFrame.new(0, 0, 0.004 * S)
		end

		-- -----------------------------------------------------------------------
		-- CUENCAS VACÍAS (en el frente de la cara)
		-- -----------------------------------------------------------------------
		for _, socket in ipairs(eyeSockets) do
			local cfg = socket.config
			socket.outer.CFrame = headCFrame * CFrame.new(cfg.x, cfg.y, cfg.z)
			socket.void.CFrame = socket.outer.CFrame * CFrame.new(0, 0, cfg.size * 0.1)

			for _, trail in ipairs(socket.bloodTrails) do
				local flowOffset = math.sin(breathTime * 0.5 + trail.flowPhase) * 0.006 * S
				trail.part.CFrame = headCFrame * CFrame.new(
					cfg.x + trail.xOff + flowOffset,
					cfg.y - cfg.size * 0.5 - trail.length * 0.5,
					cfg.z + 0.015 * S
				)
			end
		end

		-- -----------------------------------------------------------------------
		-- OREJAS (a los lados de la cabeza)
		-- -----------------------------------------------------------------------
		for _, ear in ipairs(ears) do
			local earBaseX = ear.side * (HORROR_CONFIG.HEAD_SIZE.X * 0.5 + 0.06 * S)
			local earBaseCFrame = headCFrame * CFrame.new(earBaseX, 0.03 * S, 0)
			ear.base.CFrame = earBaseCFrame

			local isListening = currentState == HORROR_CONFIG.STATE_LISTENING
			local segmentHeight = HORROR_CONFIG.EAR_SIZE.Y / HORROR_CONFIG.EAR_SEGMENTS

			local prevCFrame = earBaseCFrame
			for i, seg in ipairs(ear.segments) do
				if isListening then
					seg.targetRotation = math.sin(breathTime * seg.rotationSpeed + ear.listeningPhase + i * 0.4) * math.rad(35)
				else
					seg.targetRotation = 0
				end
				seg.currentRotation = LerpAngle(seg.currentRotation, seg.targetRotation, deltaTime * 4)

				local segCFrame = prevCFrame
					* CFrame.new(ear.side * 0.025 * S, segmentHeight * 0.45, 0)
					* CFrame.Angles(0, seg.currentRotation, ear.side * math.rad(10))

				seg.part.CFrame = segCFrame
				seg.membrane.CFrame = segCFrame * CFrame.new(0, 0, -HORROR_CONFIG.EAR_SIZE.Z * 0.3)

				prevCFrame = segCFrame * CFrame.new(ear.side * 0.012 * S, segmentHeight * 0.45, 0)
			end
		end

		-- -----------------------------------------------------------------------
		-- BOCA (en el frente de la cara, abajo)
		-- -----------------------------------------------------------------------
		local targetMouthOpen = 0.1
		if currentState == HORROR_CONFIG.STATE_SCREAMING then
			targetMouthOpen = 1.5
		elseif currentState == HORROR_CONFIG.STATE_STALKING then
			targetMouthOpen = 0.3
		end
		if isAttacking then targetMouthOpen = 1.2 end

		mouthOpen = Lerp(mouthOpen, targetMouthOpen, deltaTime * 5)

		local mouthY = -HORROR_CONFIG.HEAD_SIZE.Y * 0.25
		local jawDrop = mouthOpen * 0.35 * S

		upperLip.CFrame = headCFrame * CFrame.new(0, mouthY + HORROR_CONFIG.MOUTH_HEIGHT * 0.25, -HORROR_CONFIG.HEAD_SIZE.Z * 0.42)

		lowerJaw.CFrame = headCFrame * CFrame.new(0, mouthY - HORROR_CONFIG.MOUTH_HEIGHT * 0.15 - jawDrop, -HORROR_CONFIG.HEAD_SIZE.Z * 0.4)
			* CFrame.Angles(math.rad(mouthOpen * 40), 0, 0)

		mouthInterior.CFrame = headCFrame * CFrame.new(0, mouthY - jawDrop * 0.25, -HORROR_CONFIG.HEAD_SIZE.Z * 0.32)
		mouthAbyss.CFrame = headCFrame * CFrame.new(0, mouthY - jawDrop * 0.15, -HORROR_CONFIG.HEAD_SIZE.Z * 0.22)

		-- Dientes
		for _, rowData in ipairs(teethRows) do
			local rowY = mouthY + HORROR_CONFIG.MOUTH_HEIGHT * 0.2

			for _, tooth in ipairs(rowData.teeth) do
				tooth.upper.CFrame = headCFrame
					* CFrame.new(tooth.xPos, rowY - rowData.depth, -HORROR_CONFIG.HEAD_SIZE.Z * 0.44 - rowData.depth)
					* CFrame.Angles(math.rad(180) + tooth.angle, 0, 0)

				local lowerY = mouthY - HORROR_CONFIG.MOUTH_HEIGHT * 0.12 - jawDrop
				tooth.lower.CFrame = headCFrame
					* CFrame.new(tooth.xPos, lowerY + rowData.depth, -HORROR_CONFIG.HEAD_SIZE.Z * 0.42 - rowData.depth)
					* CFrame.Angles(tooth.angle, 0, 0)
			end
		end

		local tongueOut = mouthOpen * 0.12 * S
		tongue.CFrame = lowerJaw.CFrame * CFrame.new(0, 0.05 * S, -0.04 * S - tongueOut)
			* CFrame.Angles(math.rad(-8 - mouthOpen * 12), math.sin(animTime * 2) * math.rad(3), 0)

		-- -----------------------------------------------------------------------
		-- BRAZOS (caminando con las manos)
		-- -----------------------------------------------------------------------
		for _, arm in ipairs(arms) do
			local armPhase = arm.side == -1 and 0 or math.pi
			local walkCycle = isWalking and math.sin(animTime + armPhase) or 0
			local walkLift = isWalking and math.max(0, math.sin(animTime + armPhase)) * 0.12 * S or 0

			-- Hombro (en la parte "superior" del torso inclinado)
			local shoulderOffset = Vector3.new(
				arm.side * (HORROR_CONFIG.TORSO_SIZE.X * 0.5 + 0.08 * S),
				HORROR_CONFIG.TORSO_SIZE.Y * 0.35,
				0
			)
			local shoulderCFrame = baseCFrame * CFrame.new(shoulderOffset)
			arm.shoulder.CFrame = shoulderCFrame

			-- El brazo se extiende hacia abajo para tocar el suelo
			local upperArmPitch = math.rad(-70) + walkCycle * math.rad(20)
			local forearmPitch = math.rad(-40) + math.abs(walkCycle) * math.rad(12)

			local upperArmCFrame = shoulderCFrame
				* CFrame.Angles(upperArmPitch, 0, arm.side * math.rad(12))
				* CFrame.new(0, -HORROR_CONFIG.UPPER_ARM_SIZE.Y * 0.5, 0)
			arm.upperArm.CFrame = upperArmCFrame * CFrame.Angles(0, 0, math.rad(90))

			local elbowCFrame = upperArmCFrame * CFrame.new(0, -HORROR_CONFIG.UPPER_ARM_SIZE.Y * 0.5, 0)
			arm.elbow.CFrame = elbowCFrame

			local forearmCFrame = elbowCFrame
				* CFrame.Angles(forearmPitch, 0, 0)
				* CFrame.new(0, -HORROR_CONFIG.FOREARM_SIZE.Y * 0.5, 0)
			arm.forearm.CFrame = forearmCFrame * CFrame.Angles(0, 0, math.rad(90))

			local wristCFrame = forearmCFrame * CFrame.new(0, -HORROR_CONFIG.FOREARM_SIZE.Y * 0.5, 0)
			arm.wrist.CFrame = wristCFrame

			-- Mano en el suelo
			local handY = groundY + HORROR_CONFIG.HAND_SIZE.Y * 0.5 + walkLift
			local handCFrame = CFrame.new(wristCFrame.Position.X, handY, wristCFrame.Position.Z)
				* CFrame.Angles(math.rad(-90), npcRotation, 0)
			arm.hand.CFrame = handCFrame

			-- Dedos agarrando el suelo
			local fingerCurl = math.rad(50)
			for _, finger in ipairs(arm.fingers) do
				local fingerBaseX = finger.xOff
				if finger.isThumb then
					fingerBaseX = arm.side * HORROR_CONFIG.HAND_SIZE.X * 0.32
				end

				local prevCFrame = handCFrame * CFrame.new(fingerBaseX, 0, -HORROR_CONFIG.HAND_SIZE.Z * 0.32)

				for segIdx, seg in ipairs(finger.segments) do
					local segCurl = fingerCurl * (0.3 + segIdx * 0.2)
					seg.joint.CFrame = prevCFrame
					local segCFrame = prevCFrame
						* CFrame.Angles(segCurl, 0, 0)
						* CFrame.new(0, -seg.part.Size.Y * 0.5, 0)
					seg.part.CFrame = segCFrame
					prevCFrame = segCFrame * CFrame.new(0, -seg.part.Size.Y * 0.5, 0)
				end

				finger.claw.CFrame = prevCFrame
					* CFrame.Angles(math.rad(20), 0, 0)
					* CFrame.new(0, -0.04 * S, 0)
			end
		end

		-- -----------------------------------------------------------------------
		-- PIERNAS (hacia arriba/atrás)
		-- -----------------------------------------------------------------------
		for _, leg in ipairs(legs) do
			local legPhase = leg.side == -1 and math.pi * 0.5 or math.pi * 1.5
			local legSway = math.sin(animTime * 0.6 + legPhase) * math.rad(10)

			-- Cadera (en la parte de atrás/arriba del torso)
			local hipOffset = Vector3.new(
				leg.side * HORROR_CONFIG.PELVIS_SIZE.X * 0.32,
				-HORROR_CONFIG.TORSO_SIZE.Y * 0.5 - HORROR_CONFIG.PELVIS_SIZE.Y * 0.8,
				0
			)
			local hipCFrame = baseCFrame * CFrame.new(hipOffset)
			leg.hip.CFrame = hipCFrame

			-- Las piernas apuntan hacia arriba/atrás
			local thighPitch = math.rad(145) + legSway
			local thighCFrame = hipCFrame
				* CFrame.Angles(thighPitch, 0, leg.side * math.rad(6))
				* CFrame.new(0, -HORROR_CONFIG.THIGH_SIZE.Y * 0.5, 0)
			leg.thigh.CFrame = thighCFrame * CFrame.Angles(0, 0, math.rad(90))

			local kneeCFrame = thighCFrame * CFrame.new(0, -HORROR_CONFIG.THIGH_SIZE.Y * 0.5, 0)
			leg.knee.CFrame = kneeCFrame

			local shinPitch = math.rad(-20) + math.sin(animTime * 0.45 + legPhase) * math.rad(6)
			local shinCFrame = kneeCFrame
				* CFrame.Angles(shinPitch, 0, 0)
				* CFrame.new(0, -HORROR_CONFIG.SHIN_SIZE.Y * 0.5, 0)
			leg.shin.CFrame = shinCFrame * CFrame.Angles(0, 0, math.rad(90))

			local ankleCFrame = shinCFrame * CFrame.new(0, -HORROR_CONFIG.SHIN_SIZE.Y * 0.5, 0)
			leg.ankle.CFrame = ankleCFrame

			local footCFrame = ankleCFrame
				* CFrame.Angles(math.rad(80) + math.sin(animTime + legPhase) * math.rad(12), 0, 0)
				* CFrame.new(0, -HORROR_CONFIG.FOOT_SIZE.Y * 0.5, 0)
			leg.foot.CFrame = footCFrame
		end
	end

	-- Posición inicial
	UpdateNPCPosition(npcX, npcZ, npcRotation, false, 0.016, 999, nil)

	-- ---------------------------------------------------------------------------
	-- SONIDOS
	-- ---------------------------------------------------------------------------

	local breathingSound = Instance.new("Sound")
	breathingSound.SoundId = "rbxassetid://85565102538331"
	breathingSound.Volume = 1.0
	breathingSound.Looped = true
	breathingSound.PlaybackSpeed = 0.5
	breathingSound.Parent = head
	breathingSound:Play()

	local listeningSound = Instance.new("Sound")
	listeningSound.SoundId = "rbxassetid://5766332557"
	listeningSound.Volume = 0.2
	listeningSound.Looped = true
	listeningSound.PlaybackSpeed = 0.8
	listeningSound.Parent = head

	local growlSound = Instance.new("Sound")
	growlSound.SoundId = "rbxassetid://9114221580"
	growlSound.Volume = 0.5
	growlSound.PlaybackSpeed = 0.25
	growlSound.Parent = head

	local screamSound = Instance.new("Sound")
	screamSound.SoundId = "rbxassetid://101363423575730"
	screamSound.Volume = 1.0
	screamSound.PlaybackSpeed = 1.0
	screamSound.Parent = head

	local handstepSound = Instance.new("Sound")
	handstepSound.SoundId = "rbxassetid://124605353623000"
	handstepSound.Volume = 0.2
	handstepSound.PlaybackSpeed = 2.0
	handstepSound.Parent = torso

	-- ---------------------------------------------------------------------------
	-- FUNCIÓN DE GRITO
	-- ---------------------------------------------------------------------------

	local function PerformScream()
		if isScreaming then return end
		if tick() - lastScreamTime < HORROR_CONFIG.SCREAM_COOLDOWN then return end

		isScreaming = true
		lastScreamTime = tick()
		currentState = HORROR_CONFIG.STATE_SCREAMING

		for _, cord in ipairs(vocalCords) do
			if cord.light then
				TweenService:Create(cord.light, TweenInfo.new(0.1), {Brightness = 5}):Play()
			end
			TweenService:Create(cord.part, TweenInfo.new(0.1), {Color = HORROR_CONFIG.VOCAL_CORDS_ACTIVE}):Play()
		end

		for _, crack in ipairs(cracks) do
			if crack.light then
				TweenService: Create(crack.light, TweenInfo.new(0.15), {Brightness = 1.5}):Play()
			end
		end

		darkAura.Rate = 35
		screamSound:Play()

		for _, player in pairs(Players:GetPlayers()) do
			local char = player.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChild("Humanoid")

				if hrp and hum and hum.Health > 0 then
					local dist = (hrp.Position - Vector3.new(npcX, hrp.Position.Y, npcZ)).Magnitude

					if dist <= HORROR_CONFIG.SCREAM_RANGE and not IsInLobby(hrp.Position.X) then
						hum: TakeDamage(HORROR_CONFIG.DAMAGE_SCREAM)

						local knockbackDir = (hrp.Position - Vector3.new(npcX, hrp.Position.Y, npcZ)).Unit
						local knockback = Instance.new("BodyVelocity")
						knockback.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
						knockback.Velocity = knockbackDir * HORROR_CONFIG.KNOCKBACK_FORCE + Vector3.new(0, 25, 0)
						knockback.Parent = hrp
						Debris:AddItem(knockback, 0.25)

						char:SetAttribute("Paralyzed", true)
						task.delay(HORROR_CONFIG.PARALYSIS_DURATION, function()
							if char and char.Parent then
								char:SetAttribute("Paralyzed", false)
							end
						end)
					end
				end
			end
		end

		task.wait(2.0)

		-- Reset efectos
		for _, cord in ipairs(vocalCords) do
			if cord.light then
				TweenService:Create(cord.light, TweenInfo.new(0.5), {Brightness = 0}):Play()
			end
			TweenService:Create(cord.part, TweenInfo.new(0.5), {Color = HORROR_CONFIG.VOCAL_CORDS}):Play()
		end

		for _, crack in ipairs(cracks) do
			if crack.light then
				TweenService:Create(crack.light, TweenInfo.new(0.5), {Brightness = 0.25}):Play()
			end
		end

		darkAura.Rate = 6
		isScreaming = false
		currentState = HORROR_CONFIG.STATE_LISTENING
	end

	-- ---------------------------------------------------------------------------
	-- FUNCIÓN DE ATAQUE NORMAL
	-- ---------------------------------------------------------------------------

	local lastAttackTime = 0

	local function AttackPlayer(player)
		if tick() - lastAttackTime < HORROR_CONFIG.ATTACK_COOLDOWN then return end
		if isAttacking or isScreaming then return end

		lastAttackTime = tick()
		isAttacking = true

		local char = player.Character
		if not char then
			isAttacking = false
			return
		end

		local hum = char:FindFirstChild("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")

		if hum and hum.Health > 0 and hrp then
			local biteSound = Instance.new("Sound")
			biteSound.SoundId = "rbxassetid://5766332557"
			biteSound.Volume = 0.8
			biteSound.PlaybackSpeed = 2.0
			biteSound.Parent = head
			biteSound:Play()

			task.wait(0.12)

			local dist = (hrp.Position - Vector3.new(npcX, hrp.Position.Y, npcZ)).Magnitude
			if dist < HORROR_CONFIG.ATTACK_RANGE and hum.Health > 0 then
				hum: TakeDamage(HORROR_CONFIG.DAMAGE_NORMAL)
			end

			Debris:AddItem(biteSound, 1)
		end

		task.wait(0.15)
		isAttacking = false
	end

	-- ---------------------------------------------------------------------------
	-- EFECTO DE MUERTE
	-- ---------------------------------------------------------------------------

	local function PlayDeathEffect()
		darkAura.Enabled = false
		breathingSound:Stop()
		listeningSound: Stop()

		local deathScream = Instance.new("Sound")
		deathScream.SoundId = "rbxassetid://72245886498891"
		deathScream.Volume = 1.5
		deathScream.PlaybackSpeed = 0.8
		deathScream.Parent = head
		deathScream:Play()

		for _, crack in ipairs(cracks) do
			if crack.light then
				TweenService:Create(crack.light, TweenInfo.new(0.8), {Brightness = 0}):Play()
			end
			TweenService:Create(crack.inner, TweenInfo.new(0.8), {Transparency = 1}):Play()
		end

		for _, cord in ipairs(vocalCords) do
			if cord.light then
				TweenService: Create(cord.light, TweenInfo.new(0.5), {Brightness = 0}):Play()
			end
		end

		for _, socket in ipairs(eyeSockets) do
			socket.emitter.Enabled = false
		end

		task.wait(0.8)

		for _, part in pairs(npcModel:GetDescendants()) do
			if part:IsA("BasePart") then
				TweenService:Create(part, TweenInfo.new(1.0, Enum.EasingStyle.Quad), {
					Transparency = 1,
					Position = part.Position + Vector3.new(
						(math.random() - 0.5) * 0.5 * S,
						-0.8 * S,
						(math.random() - 0.5) * 0.5 * S
					)
				}):Play()
			end
		end

		task.wait(1.1)
		Debris:AddItem(deathScream, 3)
	end

	-- ---------------------------------------------------------------------------
	-- IA PRINCIPAL
	-- ---------------------------------------------------------------------------

	local isAlive = true
	local lastSeenPosition = nil

	local function FindNearestPlayer()
		local nearest, nearestDist = nil, HORROR_CONFIG.DETECTION_RANGE
		for _, player in pairs(Players:GetPlayers()) do
			local char = player.Character
			if char then
				local hrp = char: FindFirstChild("HumanoidRootPart")
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

	local function ChangeState(newState)
		if currentState == newState then return end
		currentState = newState
		stateTimer = 0

		if newState == HORROR_CONFIG.STATE_LISTENING then
			currentSpeed = HORROR_CONFIG.SPEED_LISTENING
			listeningSound:Play()
		elseif newState == HORROR_CONFIG.STATE_TRACKING then
			currentSpeed = HORROR_CONFIG.SPEED_TRACKING
			listeningSound:Stop()
			growlSound:Play()
		elseif newState == HORROR_CONFIG.STATE_STALKING then
			currentSpeed = HORROR_CONFIG.SPEED_STALKING
			listeningSound:Stop()
			breathingSound.Volume = 0.1
		elseif newState == HORROR_CONFIG.STATE_SCREAMING then
			currentSpeed = HORROR_CONFIG.SPEED_SCREAMING
		end
	end

	-- ---------------------------------------------------------------------------
	-- LOOP PRINCIPAL
	-- ---------------------------------------------------------------------------

	local chaseConnection
	chaseConnection = RunService.Heartbeat:Connect(function(dt)
		if not isAlive or not torso or not torso.Parent then
			if chaseConnection then chaseConnection:Disconnect() end
			return
		end

		local elapsedTime = tick() - spawnTime
		if elapsedTime >= npcLifetime then
			isAlive = false
			if chaseConnection then chaseConnection: Disconnect() end
			PlayDeathEffect()
			task.wait(1.2)
			if npcFolder and npcFolder.Parent then
				npcFolder:Destroy()
			end
			return
		end

		if npcModel:GetAttribute("Stunned") then
			UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, 999, nil)
			return
		end

		if IsInLobby(npcX) then
			isAlive = false
			if chaseConnection then chaseConnection: Disconnect() end
			PlayDeathEffect()
			task.wait(1.2)
			if npcFolder and npcFolder.Parent then
				npcFolder: Destroy()
			end
			return
		end

		stateTimer = stateTimer + dt

		local target, distance = FindNearestPlayer()
		local targetPosition = nil

		if target and target.Character then
			local hrp = target.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				targetPosition = hrp.Position
				lastSeenPosition = targetPosition
			end
		end

		if isWalking and not isScreaming then
			if math.floor(animTime * 2) % 2 == 0 and not handstepSound.Playing then
				handstepSound: Play()
			end
		end

		-- MÁQUINA DE ESTADOS
		if currentState == HORROR_CONFIG.STATE_LISTENING then
			if target and distance < HORROR_CONFIG.TRACKING_THRESHOLD then
				ChangeState(HORROR_CONFIG.STATE_TRACKING)
			elseif stateTimer > HORROR_CONFIG.LISTENING_DURATION then
				npcRotation = npcRotation + (math.random() - 0.5) * math.rad(90)
				stateTimer = 0
			end
			UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, distance or 999, targetPosition)

		elseif currentState == HORROR_CONFIG.STATE_TRACKING then
			if target and distance < HORROR_CONFIG.STALKING_THRESHOLD then
				ChangeState(HORROR_CONFIG.STATE_STALKING)
			elseif targetPosition then
				local direction = Vector3.new(targetPosition.X - npcX, 0, targetPosition.Z - npcZ)
				if direction.Magnitude > 1 then
					local lookAngle = math.atan2(-direction.X, -direction.Z)
					local moveDir = direction.Unit
					local newX = npcX + moveDir.X * currentSpeed * dt
					local newZ = npcZ + moveDir.Z * currentSpeed * dt

					if not IsInLobby(newX) then
						UpdateNPCPosition(newX, newZ, lookAngle, true, dt, distance, targetPosition)
					else
						UpdateNPCPosition(npcX, npcZ, lookAngle, false, dt, distance, targetPosition)
					end
				else
					ChangeState(HORROR_CONFIG.STATE_LISTENING)
				end
			elseif lastSeenPosition then
				local direction = Vector3.new(lastSeenPosition.X - npcX, 0, lastSeenPosition.Z - npcZ)
				if direction.Magnitude > 2 then
					local lookAngle = math.atan2(-direction.X, -direction.Z)
					local moveDir = direction.Unit
					local newX = npcX + moveDir.X * currentSpeed * dt
					local newZ = npcZ + moveDir.Z * currentSpeed * dt
					if not IsInLobby(newX) then
						UpdateNPCPosition(newX, newZ, lookAngle, true, dt, distance or 999, nil)
					end
				else
					lastSeenPosition = nil
					ChangeState(HORROR_CONFIG.STATE_LISTENING)
				end
			else
				ChangeState(HORROR_CONFIG.STATE_LISTENING)
			end

		elseif currentState == HORROR_CONFIG.STATE_STALKING then
			if target and targetPosition then
				local direction = Vector3.new(targetPosition.X - npcX, 0, targetPosition.Z - npcZ)

				if distance <= HORROR_CONFIG.SCREAM_RANGE and tick() - lastScreamTime >= HORROR_CONFIG.SCREAM_COOLDOWN then
					coroutine.wrap(function()
						PerformScream()
					end)()
				elseif distance <= HORROR_CONFIG.ATTACK_RANGE then
					local lookAngle = math.atan2(-direction.X, -direction.Z)
					UpdateNPCPosition(npcX, npcZ, lookAngle, false, dt, distance, targetPosition)
					AttackPlayer(target)
				elseif direction.Magnitude > 0.5 then
					local lookAngle = math.atan2(-direction.X, -direction.Z)
					local moveDir = direction.Unit
					local newX = npcX + moveDir.X * currentSpeed * dt
					local newZ = npcZ + moveDir.Z * currentSpeed * dt

					if not IsInLobby(newX) then
						UpdateNPCPosition(newX, newZ, lookAngle, true, dt, distance, targetPosition)
					else
						UpdateNPCPosition(npcX, npcZ, lookAngle, false, dt, distance, targetPosition)
					end
				end
			else
				ChangeState(HORROR_CONFIG.STATE_TRACKING)
			end

		elseif currentState == HORROR_CONFIG.STATE_SCREAMING then
			UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, distance or 999, targetPosition)
		end
	end)

	-- ---------------------------------------------------------------------------
	-- COMPORTAMIENTOS AMBIENTALES
	-- ---------------------------------------------------------------------------

	coroutine.wrap(function()
		while isAlive and head and head.Parent do
			task.wait(math.random(4, 10))
			if isAlive and currentState == HORROR_CONFIG.STATE_LISTENING then
				local earSound = Instance.new("Sound")
				earSound.SoundId = "rbxassetid://5766332557"
				earSound.Volume = 0.15
				earSound.PlaybackSpeed = 0.5 + math.random() * 0.3
				earSound.Parent = head
				earSound:Play()
				Debris:AddItem(earSound, 2)
			end
		end
	end)()

	coroutine.wrap(function()
		while isAlive and head and head.Parent do
			task.wait(math.random(8, 18))
			if isAlive and not isScreaming and currentState ~= HORROR_CONFIG.STATE_LISTENING then
				local growl = Instance.new("Sound")
				growl.SoundId = "rbxassetid://9114221580"
				growl.Volume = 0.25
				growl.PlaybackSpeed = 0.2 + math.random() * 0.15
				growl.Parent = head
				growl:Play()
				Debris:AddItem(growl, 4)
			end
		end
	end)()

	npcFolder.AncestryChanged:Connect(function()
		if not npcFolder.Parent then
			isAlive = false
			breathingSound: Stop()
			listeningSound:Stop()
			if chaseConnection then chaseConnection: Disconnect() end
		end
	end)

	return npcFolder
end

-- -------------------------------------------------------------------------------
-- EVENT LISTENER
-- -------------------------------------------------------------------------------

if SpawnScreamerEvent then
	SpawnScreamerEvent.Event:Connect(function(position, player, side, zDir, doorFrameInfo, lifetime)
		print("???? SpawnScreamerEvent received - Lifetime: "..tostring(lifetime))
		task.wait(0.2)
		CreateHorrorNPC(position, player, side, zDir, doorFrameInfo, lifetime)
	end)
end

print("=== THE SCREAMER V2 - AUDITORY HORROR ===")
print("   Scale: "..S.."x")
print("   CARA MIRANDO HACIA ADELANTE")
print("   Tracking Speed: "..HORROR_CONFIG.SPEED_TRACKING)
print("   Stalking Speed: "..HORROR_CONFIG.SPEED_STALKING)
print("   Scream Range: "..HORROR_CONFIG.SCREAM_RANGE.." studs")
print("   Scream Damage: "..HORROR_CONFIG.DAMAGE_SCREAM)
print("   Paralysis:  "..HORROR_CONFIG.PARALYSIS_DURATION.." seconds")
print("===========================================")