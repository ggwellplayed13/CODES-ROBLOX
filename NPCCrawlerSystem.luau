--[[
    +------------------------------------------------------------------------------+
    |                    HUMANOID HORROR ENTITY SYSTEM                              |
    |                 VERSIÓN 7 - "THE FLESH CRAWLER"                               |
    |                      TERROR MÁXIMO - PESADILLA PURA                           |
    +------------------------------------------------------------------------------+
    
    Una criatura humanoide GIGANTE grotescamente deformada: 
    - ENORME - casi 3 metros de alto erguida
    - Piel humana realista pero enferma y descompuesta
    - Camina en 4 patas con la CARA HACIA EL JUGADOR (corregido)
    - Movimientos de araña/insecto extremadamente perturbadores
    - Cara destrozada con mandíbula desencajada
    - Sonidos viscerales y gritos humanos distorsionados
    - Ojos que te siguen incluso cuando mira hacia otro lado
    - Dedos que se doblan en direcciones imposibles
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local SpawnCrawlerEvent = ReplicatedStorage:WaitForChild("SpawnCrawlerEvent", 10)

-- -------------------------------------------------------------------------------
-- CONFIGURACIÓN DEL HORROR MÁXIMO
-- -------------------------------------------------------------------------------
local HORROR_CONFIG = {
	-- ESCALA GIGANTE
	SCALE = 2.2,                  -- Mucho más grande que un humano normal

	-- VELOCIDADES
	SPEED_BIPEDAL = 8,            -- Muy lento erguido (acechando)
	SPEED_QUADRUPED = 48,         -- TERRÍFICAMENTE rápido en 4 patas
	SPEED_BURST = 60,             -- Burst de velocidad
	SPEED_TRANSITION = 0.2,       -- Transición muy rápida (perturbadora)

	-- DISTANCIAS
	DETECTION_RANGE = 300,
	CHASE_THRESHOLD = 70,
	ATTACK_RANGE = 8,
	LUNGE_RANGE = 15,

	-- COMBATE
	DAMAGE = 45,
	ATTACK_COOLDOWN = 0.4,
	LUNGE_DAMAGE = 60,
	REWARD_SURVIVAL = 25,

	-- COLORES - PIEL HUMANA REALISTA PERO ENFERMA
	SKIN_HEALTHY = Color3.fromRGB(210, 170, 140),      -- Piel humana base
	SKIN_PALE = Color3.fromRGB(190, 165, 145),         -- Piel pálida
	SKIN_SICK = Color3.fromRGB(175, 155, 120),         -- Piel enferma amarillenta
	SKIN_DEAD = Color3.fromRGB(140, 130, 115),         -- Piel muerta grisácea
	SKIN_BRUISED = Color3.fromRGB(130, 100, 110),      -- Moretones
	SKIN_VEINS = Color3.fromRGB(80, 50, 70),           -- Venas visibles
	SKIN_INFECTED = Color3.fromRGB(150, 140, 90),      -- Infección amarilla

	FLESH_EXPOSED = Color3.fromRGB(150, 60, 60),       -- Carne viva roja
	FLESH_MUSCLE = Color3.fromRGB(120, 45, 50),        -- Músculo expuesto
	FLESH_DARK = Color3.fromRGB(90, 35, 40),           -- Carne oscura
	FLESH_ROTTING = Color3.fromRGB(100, 90, 60),       -- Carne podrida

	BONE_WHITE = Color3.fromRGB(235, 225, 210),        -- Hueso fresco
	BONE_OLD = Color3.fromRGB(200, 185, 160),          -- Hueso viejo
	BONE_YELLOW = Color3.fromRGB(220, 200, 150),       -- Hueso amarillento

	-- OJOS HUMANOS PERO PERTURBADORES
	EYE_SCLERA = Color3.fromRGB(255, 250, 240),        -- Blanco del ojo
	EYE_SCLERA_SICK = Color3.fromRGB(255, 240, 200),   -- Blanco amarillento
	EYE_BLOODSHOT = Color3.fromRGB(200, 50, 50),       -- Vasos sanguíneos
	EYE_IRIS_BLUE = Color3.fromRGB(70, 130, 180),      -- Iris azul
	EYE_IRIS_BROWN = Color3.fromRGB(100, 70, 40),      -- Iris marrón
	EYE_PUPIL = Color3.fromRGB(5, 5, 5),               -- Pupila negra
	EYE_GLOW = Color3.fromRGB(255, 255, 200),          -- Brillo antinatural

	-- BOCA/DIENTES HUMANOS PERO GROTESCOS
	LIPS_COLOR = Color3.fromRGB(140, 90, 100),         -- Labios pálidos
	LIPS_CRACKED = Color3.fromRGB(100, 60, 70),        -- Labios agrietados
	GUM_HEALTHY = Color3.fromRGB(180, 100, 110),       -- Encías
	GUM_INFECTED = Color3.fromRGB(120, 80, 70),        -- Encías infectadas
	TEETH_WHITE = Color3.fromRGB(245, 240, 230),       -- Dientes blancos
	TEETH_YELLOW = Color3.fromRGB(220, 200, 150),      -- Dientes amarillos
	TEETH_ROTTEN = Color3.fromRGB(80, 70, 50),         -- Dientes podridos
	TONGUE_COLOR = Color3.fromRGB(160, 90, 100),       -- Lengua rosada
	TONGUE_SICK = Color3.fromRGB(140, 100, 80),        -- Lengua enferma
	MOUTH_INTERIOR = Color3.fromRGB(80, 30, 40),       -- Interior boca
	SALIVA = Color3.fromRGB(200, 195, 180),            -- Saliva

	-- PELO HUMANO
	HAIR_BLACK = Color3.fromRGB(25, 20, 18),
	HAIR_BROWN = Color3.fromRGB(60, 45, 35),
	HAIR_GRAY = Color3.fromRGB(120, 115, 110),

	-- UÑAS
	NAIL_HEALTHY = Color3.fromRGB(230, 200, 180),      -- Uñas normales
	NAIL_DIRTY = Color3.fromRGB(150, 130, 100),        -- Uñas sucias
	NAIL_BLACK = Color3.fromRGB(40, 35, 30),           -- Uñas negras
	NAIL_BLOODY = Color3.fromRGB(120, 50, 50),         -- Uñas con sangre

	-- DIMENSIONES CORPORALES ESCALADAS (GIGANTE)
	HEAD_SIZE = Vector3.new(1.3, 1.5, 1.2),
	NECK_LENGTH = 1.0,
	TORSO_UPPER_SIZE = Vector3.new(2.0, 1.8, 0.9),
	TORSO_LOWER_SIZE = Vector3.new(1.6, 1.0, 0.7),

	-- BRAZOS LARGOS Y GROTESCOS
	SHOULDER_SIZE = 0.4,
	UPPER_ARM_SIZE = Vector3.new(0.28, 2.0, 0.28),
	FOREARM_SIZE = Vector3.new(0.24, 2.2, 0.24),
	HAND_SIZE = Vector3.new(0.7, 0.9, 0.18),
	FINGER_LENGTH = 0.8,

	-- PIERNAS
	HIP_SIZE = 0.38,
	THIGH_SIZE = Vector3.new(0.38, 1.8, 0.38),
	SHIN_SIZE = Vector3.new(0.32, 2.0, 0.32),
	FOOT_SIZE = Vector3.new(0.4, 0.2, 1.0),

	-- COMPORTAMIENTO
	TWITCH_FREQUENCY = 0.3,
	HEAD_ROTATION_SPEED = 20,
	STOP_MOTION_CHANCE = 0.1,
	SUDDEN_MOVE_CHANCE = 0.06,
	NECK_CRACK_CHANCE = 0.04,

	-- SONIDOS
	BREATHING_RATE = 3.0,
	BONE_CRACK_FREQUENCY = 0.4,
	SCREAM_CHANCE = 0.03,
	WHISPER_CHANCE = 0.02,

	LOBBY_START_X = -75,
	LOBBY_END_X = 75,
}

-- Aplicar escala
local S = HORROR_CONFIG.SCALE
HORROR_CONFIG.HEAD_SIZE = HORROR_CONFIG.HEAD_SIZE * S
HORROR_CONFIG.TORSO_UPPER_SIZE = HORROR_CONFIG.TORSO_UPPER_SIZE * S
HORROR_CONFIG.TORSO_LOWER_SIZE = HORROR_CONFIG.TORSO_LOWER_SIZE * S
HORROR_CONFIG.UPPER_ARM_SIZE = HORROR_CONFIG.UPPER_ARM_SIZE * S
HORROR_CONFIG.FOREARM_SIZE = HORROR_CONFIG.FOREARM_SIZE * S
HORROR_CONFIG.HAND_SIZE = HORROR_CONFIG.HAND_SIZE * S
HORROR_CONFIG.THIGH_SIZE = HORROR_CONFIG.THIGH_SIZE * S
HORROR_CONFIG.SHIN_SIZE = HORROR_CONFIG.SHIN_SIZE * S
HORROR_CONFIG.FOOT_SIZE = HORROR_CONFIG.FOOT_SIZE * S
HORROR_CONFIG.FINGER_LENGTH = HORROR_CONFIG.FINGER_LENGTH * S
HORROR_CONFIG.NECK_LENGTH = HORROR_CONFIG.NECK_LENGTH * S
HORROR_CONFIG.SHOULDER_SIZE = HORROR_CONFIG.SHOULDER_SIZE * S
HORROR_CONFIG.HIP_SIZE = HORROR_CONFIG.HIP_SIZE * S

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
-- CREAR THE FLESH CRAWLER - HORROR MÁXIMO
-- -------------------------------------------------------------------------------

local function CreateHorrorNPC(spawnPosition, triggerPlayer, side, zDir, doorFrameInfo, lifetime)
	local npcLifetime = lifetime
	if not npcLifetime or npcLifetime <= 0 then
		npcLifetime = 60
	end

	print("===========================================")
	print("?????? THE FLESH CRAWLER SPAWNED ??????")
	print("   Scale: "..S.."x (GIGANTE)")
	print("   Lifetime: "..npcLifetime.." seconds")
	print("   Position: "..tostring(spawnPosition))
	print("===========================================")

	local npcFolder = Instance.new("Folder")
	npcFolder.Name = "HorrorEntity"
	npcFolder.Parent = workspace

	local npcModel = Instance.new("Model")
	npcModel.Name = "TheFleshCrawler"
	npcModel.Parent = npcFolder

	local spawnTime = tick()
	npcFolder: SetAttribute("SpawnTime", spawnTime)
	npcFolder:SetAttribute("Lifetime", npcLifetime)
	npcModel:SetAttribute("SpawnTime", spawnTime)
	npcModel:SetAttribute("Lifetime", npcLifetime)

	local groundY = 0.5
	local baseHeightBipedal = 4.5 * S
	local baseHeightQuadruped = 1.2 * S

	-- ---------------------------------------------------------------------------
	-- TORSO PRINCIPAL - CUERPO HUMANO DEFORMADO
	-- ---------------------------------------------------------------------------

	-- Torso superior (pecho)
	local torsoUpper = CreatePart(
		"TorsoUpper",
		HORROR_CONFIG.TORSO_UPPER_SIZE,
		HORROR_CONFIG.SKIN_PALE,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	torsoUpper.CanCollide = true

	-- Torso inferior (abdomen)
	local torsoLower = CreatePart(
		"TorsoLower",
		HORROR_CONFIG.TORSO_LOWER_SIZE,
		HORROR_CONFIG.SKIN_SICK,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)

	-- Costillas visibles (el cuerpo está demacrado)
	local ribs = {}
	for i = 1, 8 do
		for side = -1, 1, 2 do
			local rib = CreatePart(
				"Rib"..i.."_"..side,
				Vector3.new(0.6 * S, 0.05 * S, 0.08 * S),
				HORROR_CONFIG.BONE_WHITE,
				Enum.Material.SmoothPlastic,
				0.15,
				npcModel
			)
			table.insert(ribs, {part = rib, index = i, side = side})
		end
	end

	-- Columna vertebral (muy visible, sobresale)
	local spineSegments = {}
	for i = 1, 10 do
		local vertebra = CreatePart(
			"Vertebra"..i,
			Vector3.new(0.18 * S, 0.2 * S, 0.25 * S),
			HORROR_CONFIG.BONE_OLD,
			Enum.Material.SmoothPlastic,
			0.1,
			npcModel
		)
		CreateMesh(vertebra, Enum.MeshType.Sphere)
		table.insert(spineSegments, {part = vertebra, index = i})
	end

	-- Venas visibles en el torso
	local torsoVeins = {}
	for i = 1, 12 do
		local vein = CreatePart(
			"TorsoVein"..i,
			Vector3.new(0.03 * S, (0.3 + math.random() * 0.4) * S, 0.03 * S),
			HORROR_CONFIG.SKIN_VEINS,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		table.insert(torsoVeins, {
			part = vein,
			offset = Vector3.new(
				(math.random() - 0.5) * 1.5 * S,
				(math.random() - 0.5) * 1.5 * S,
				(math.random() > 0.5 and 0.35 or -0.35) * S
			),
			pulsePhase = math.random() * math.pi * 2
		})
	end

	-- Heridas y carne expuesta
	local wounds = {}
	for i = 1, 5 do
		local wound = CreatePart(
			"Wound"..i,
			Vector3.new((0.15 + math.random() * 0.2) * S, (0.1 + math.random() * 0.15) * S, 0.05 * S),
			math.random() > 0.5 and HORROR_CONFIG.FLESH_EXPOSED or HORROR_CONFIG.FLESH_DARK,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		CreateMesh(wound, Enum.MeshType.Sphere)
		table.insert(wounds, {
			part = wound,
			offset = Vector3.new(
				(math.random() - 0.5) * 1.2 * S,
				(math.random() - 0.5) * 1.4 * S,
				(math.random() > 0.5 and 0.4 or -0.3) * S
			)
		})
	end

	-- ---------------------------------------------------------------------------
	-- CUELLO - LARGO Y PUEDE GIRAR DE FORMA ANTINATURAL
	-- ---------------------------------------------------------------------------

	local neckSegments = {}
	local numNeckSegments = 6
	for i = 1, numNeckSegments do
		local segSize = (0.35 - (i-1) * 0.025) * S
		local segment = CreatePart(
			"NeckSeg"..i,
			Vector3.new(segSize, 0.18 * S, segSize),
			LerpColor(HORROR_CONFIG.SKIN_PALE, HORROR_CONFIG.SKIN_SICK, i/numNeckSegments),
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		CreateMesh(segment, Enum.MeshType.Cylinder)

		-- Tendones visibles en cada segmento
		local tendons = {}
		for t = 1, 3 do
			local tendon = CreatePart(
				"Tendon"..i.."_"..t,
				Vector3.new(0.04 * S, 0.2 * S, 0.04 * S),
				HORROR_CONFIG.FLESH_MUSCLE,
				Enum.Material.SmoothPlastic,
				0.2,
				npcModel
			)
			table.insert(tendons, {part = tendon, angle = (t-1) * (math.pi * 2 / 3)})
		end

		table.insert(neckSegments, {
			part = segment,
			index = i,
			tendons = tendons,
			bendAngle = 0,
			twistAngle = 0
		})
	end

	-- ---------------------------------------------------------------------------
	-- CABEZA - CARA HUMANA PERO COMPLETAMENTE PERTURBADORA
	-- ---------------------------------------------------------------------------

	local head = CreatePart(
		"Head",
		HORROR_CONFIG.HEAD_SIZE,
		HORROR_CONFIG.SKIN_HEALTHY,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	CreateMesh(head, Enum.MeshType.Sphere, Vector3.new(1, 1.15, 0.95))

	-- Piel de la cara con diferentes tonos
	local faceSkin = {}
	-- Frente
	local forehead = CreatePart(
		"Forehead",
		Vector3.new(0.9 * S, 0.4 * S, 0.15 * S),
		HORROR_CONFIG.SKIN_PALE,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	CreateMesh(forehead, Enum.MeshType.Sphere, Vector3.new(1, 0.6, 0.3))
	table.insert(faceSkin, forehead)

	-- Pómulos hundidos
	for side = -1, 1, 2 do
		local cheekbone = CreatePart(
			"Cheekbone"..side,
			Vector3.new(0.35 * S, 0.25 * S, 0.2 * S),
			HORROR_CONFIG.BONE_WHITE,
			Enum.Material.SmoothPlastic,
			0.4,
			npcModel
		)
		CreateMesh(cheekbone, Enum.MeshType.Sphere)
		table.insert(faceSkin, {part = cheekbone, side = side, type = "cheekbone"})
	end

	-- Mejillas hundidas (demacrado)
	for side = -1, 1, 2 do
		local cheek = CreatePart(
			"Cheek"..side,
			Vector3.new(0.3 * S, 0.4 * S, 0.25 * S),
			HORROR_CONFIG.SKIN_DEAD,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		CreateMesh(cheek, Enum.MeshType.Sphere, Vector3.new(1, 1, 0.5))
	end

	-- Venas en la cabeza
	local headVeins = {}
	for i = 1, 10 do
		local vein = CreatePart(
			"HeadVein"..i,
			Vector3.new(0.025 * S, (0.2 + math.random() * 0.3) * S, 0.02 * S),
			HORROR_CONFIG.SKIN_VEINS,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		table.insert(headVeins, {
			part = vein,
			offset = Vector3.new(
				(math.random() - 0.5) * 0.9 * S,
				(math.random() - 0.3) * 0.8 * S,
				(math.random() - 0.5) * 0.6 * S
			),
			pulsePhase = math.random() * math.pi * 2
		})
	end

	-- Pelo sparse y desagradable
	local hairStrands = {}
	for i = 1, 20 do
		local strand = CreatePart(
			"Hair"..i,
			Vector3.new(0.015 * S, (0.15 + math.random() * 0.25) * S, 0.015 * S),
			math.random() > 0.3 and HORROR_CONFIG.HAIR_BLACK or HORROR_CONFIG.HAIR_GRAY,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		table.insert(hairStrands, {
			part = strand,
			offset = Vector3.new(
				(math.random() - 0.5) * 0.7 * S,
				0.5 * S + math.random() * 0.2 * S,
				(math.random() - 0.5) * 0.5 * S
			),
			swayPhase = math.random() * math.pi * 2
		})
	end

	-- ---------------------------------------------------------------------------
	-- OJOS - HUMANOS PERO INYECTADOS EN SANGRE Y PERTURBADORES
	-- ---------------------------------------------------------------------------

	local eyes = {}
	local eyeConfigs = {
		-- Ojo izquierdo principal (ligeramente más grande, asimétrico)
		{x = -0.32 * S, y = 0.18 * S, z = -0.52 * S, size = 0.28 * S, isMain = true, irisColor = HORROR_CONFIG.EYE_IRIS_BLUE},
		-- Ojo derecho principal
		{x = 0.30 * S, y = 0.15 * S, z = -0.50 * S, size = 0.26 * S, isMain = true, irisColor = HORROR_CONFIG.EYE_IRIS_BROWN},
		-- Tercer ojo (en la frente, parcialmente oculto bajo piel)
		{x = 0.05 * S, y = 0.55 * S, z = -0.42 * S, size = 0.18 * S, isMain = false, irisColor = HORROR_CONFIG.EYE_IRIS_BLUE, hidden = true},
	}

	for i, config in ipairs(eyeConfigs) do
		-- Cuenca del ojo (hundida, ojeras oscuras)
		local socket = CreatePart(
			"EyeSocket"..i,
			Vector3.new(config.size * 1.6, config.size * 1.4, config.size * 0.5),
			HORROR_CONFIG.SKIN_BRUISED,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		CreateMesh(socket, Enum.MeshType.Sphere)

		-- Globo ocular (esclerótica)
		local eyeball = CreateBallPart(
			"Eyeball"..i,
			config.size,
			config.hidden and HORROR_CONFIG.EYE_SCLERA_SICK or HORROR_CONFIG.EYE_SCLERA,
			Enum.Material.SmoothPlastic,
			npcModel
		)

		-- Vasos sanguíneos en el ojo
		local eyeVeins = {}
		for v = 1, 6 do
			local vein = CreatePart(
				"EyeVein"..i.."_"..v,
				Vector3.new(0.008 * S, config.size * 0.35, 0.004 * S),
				HORROR_CONFIG.EYE_BLOODSHOT,
				Enum.Material.SmoothPlastic,
				0.2,
				npcModel
			)
			table.insert(eyeVeins, {
				part = vein,
				angle = (v - 1) * (math.pi / 3) + (math.random() - 0.5) * 0.3
			})
		end

		-- Iris
		local iris = CreateBallPart(
			"Iris"..i,
			config.size * 0.45,
			config.irisColor,
			Enum.Material.SmoothPlastic,
			npcModel
		)

		-- Pupila (puede dilatarse de forma antinatural)
		local pupil = CreateBallPart(
			"Pupil"..i,
			config.size * 0.25,
			HORROR_CONFIG.EYE_PUPIL,
			Enum.Material.SmoothPlastic,
			npcModel
		)

		-- Reflejo de luz en el ojo
		local reflection = CreateBallPart(
			"EyeReflect"..i,
			config.size * 0.08,
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic,
			npcModel
		)
		reflection.Material = Enum.Material.Neon
		reflection.Transparency = 0.3

		-- Párpados
		local eyelidTop = CreatePart(
			"EyelidTop"..i,
			Vector3.new(config.size * 1.3, config.size * 0.5, config.size * 0.3),
			HORROR_CONFIG.SKIN_HEALTHY,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		CreateMesh(eyelidTop, Enum.MeshType.Sphere, Vector3.new(1, 0.5, 0.4))

		local eyelidBottom = CreatePart(
			"EyelidBottom"..i,
			Vector3.new(config.size * 1.2, config.size * 0.35, config.size * 0.25),
			HORROR_CONFIG.SKIN_PALE,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		CreateMesh(eyelidBottom, Enum.MeshType.Sphere, Vector3.new(1, 0.4, 0.35))

		-- Pestañas (sparse y desiguales)
		local lashes = {}
		for l = 1, 5 do
			local lash = CreatePart(
				"Lash"..i.."_"..l,
				Vector3.new(0.01 * S, 0.05 * S, 0.005 * S),
				HORROR_CONFIG.HAIR_BLACK,
				Enum.Material.SmoothPlastic,
				0,
				npcModel
			)
			table.insert(lashes, {part = lash, xOff = (l - 3) * 0.04 * S})
		end

		-- Luz del ojo (brillo antinatural)
		local eyeLight = Instance.new("PointLight")
		eyeLight.Brightness = 0.2
		eyeLight.Color = HORROR_CONFIG.EYE_GLOW
		eyeLight.Range = 5 * S
		eyeLight.Parent = eyeball

		table.insert(eyes, {
			socket = socket,
			eyeball = eyeball,
			veins = eyeVeins,
			iris = iris,
			pupil = pupil,
			reflection = reflection,
			eyelidTop = eyelidTop,
			eyelidBottom = eyelidBottom,
			lashes = lashes,
			light = eyeLight,
			config = config,
			blinkTime = 0,
			blinkDuration = 0,
			isBlinking = false,
			lookOffset = {x = 0, y = 0},
			twitchPhase = math.random() * math.pi * 2,
			pupilDilation = 1
		})
	end

	-- ---------------------------------------------------------------------------
	-- NARIZ - HUMANA PERO ROTA/DEFORMADA
	-- ---------------------------------------------------------------------------

	local nose = CreatePart(
		"Nose",
		Vector3.new(0.2 * S, 0.35 * S, 0.25 * S),
		HORROR_CONFIG.SKIN_HEALTHY,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	CreateMesh(nose, Enum.MeshType.Sphere, Vector3.new(0.7, 1, 1))

	-- Puente de la nariz (roto, desviado)
	local noseBridge = CreatePart(
		"NoseBridge",
		Vector3.new(0.12 * S, 0.25 * S, 0.15 * S),
		HORROR_CONFIG.SKIN_PALE,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)

	-- Fosas nasales
	local nostrils = {}
	for side = -1, 1, 2 do
		local nostril = CreatePart(
			"Nostril"..side,
			Vector3.new(0.08 * S, 0.06 * S, 0.1 * S),
			HORROR_CONFIG.MOUTH_INTERIOR,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		CreateMesh(nostril, Enum.MeshType.Sphere)
		table.insert(nostrils, {part = nostril, side = side})
	end

	-- ---------------------------------------------------------------------------
	-- BOCA - DESENCAJADA, DIENTES HUMANOS PERO GROTESCOS
	-- ---------------------------------------------------------------------------

	-- Labios (agrietados, pálidos)
	local upperLip = CreatePart(
		"UpperLip",
		Vector3.new(0.55 * S, 0.12 * S, 0.2 * S),
		HORROR_CONFIG.LIPS_CRACKED,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	CreateMesh(upperLip, Enum.MeshType.Sphere, Vector3.new(1, 0.6, 0.8))

	local lowerLip = CreatePart(
		"LowerLip",
		Vector3.new(0.5 * S, 0.1 * S, 0.18 * S),
		HORROR_CONFIG.LIPS_COLOR,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	CreateMesh(lowerLip, Enum.MeshType.Sphere, Vector3.new(1, 0.5, 0.7))

	-- Mandíbula (puede desencajarse)
	local jaw = CreatePart(
		"Jaw",
		Vector3.new(0.75 * S, 0.4 * S, 0.55 * S),
		HORROR_CONFIG.SKIN_SICK,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	CreateMesh(jaw, Enum.MeshType.Sphere, Vector3.new(1, 0.7, 0.9))

	-- Interior de la boca
	local mouthInterior = CreatePart(
		"MouthInterior",
		Vector3.new(0.55 * S, 0.35 * S, 0.4 * S),
		HORROR_CONFIG.MOUTH_INTERIOR,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)

	-- Encías
	local gumUpper = CreatePart(
		"GumUpper",
		Vector3.new(0.5 * S, 0.1 * S, 0.22 * S),
		HORROR_CONFIG.GUM_INFECTED,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	local gumLower = CreatePart(
		"GumLower",
		Vector3.new(0.45 * S, 0.08 * S, 0.2 * S),
		HORROR_CONFIG.GUM_HEALTHY,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)

	-- DIENTES SUPERIORES - Humanos pero algunos rotos/podridos
	local teethUpper = {}
	local toothPositions = {-0.18, -0.13, -0.08, -0.03, 0.03, 0.08, 0.13, 0.18}
	for i, xPos in ipairs(toothPositions) do
		local isRotten = math.random() < 0.2
		local isBroken = math.random() < 0.15
		local toothHeight = (0.12 - (isBroken and 0.04 or 0)) * S
		local toothColor = isRotten and HORROR_CONFIG.TEETH_ROTTEN or 
			(math.random() < 0.6 and HORROR_CONFIG.TEETH_WHITE or HORROR_CONFIG.TEETH_YELLOW)

		local tooth = CreatePart(
			"ToothUpper"..i,
			Vector3.new(0.045 * S, toothHeight, 0.035 * S),
			toothColor,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)

		table.insert(teethUpper, {
			part = tooth,
			xOff = xPos * S,
			angle = (math.random() - 0.5) * math.rad(15),
			height = toothHeight
		})
	end

	-- DIENTES INFERIORES
	local teethLower = {}
	for i, xPos in ipairs(toothPositions) do
		local isRotten = math.random() < 0.25
		local isMissing = math.random() < 0.1
		if not isMissing then
			local toothHeight = 0.1 * S
			local tooth = CreatePart(
				"ToothLower"..i,
				Vector3.new(0.04 * S, toothHeight, 0.03 * S),
				isRotten and HORROR_CONFIG.TEETH_ROTTEN or HORROR_CONFIG.TEETH_YELLOW,
				Enum.Material.SmoothPlastic,
				0,
				npcModel
			)
			table.insert(teethLower, {
				part = tooth,
				xOff = xPos * S,
				angle = (math.random() - 0.5) * math.rad(20)
			})
		end
	end

	-- Lengua (grande, puede salir de la boca)
	local tongue = CreatePart(
		"Tongue",
		Vector3.new(0.2 * S, 0.08 * S, 0.4 * S),
		HORROR_CONFIG.TONGUE_SICK,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	CreateMesh(tongue, Enum.MeshType.Sphere, Vector3.new(1, 0.5, 1.5))

	-- Punta de la lengua
	local tongueTip = CreatePart(
		"TongueTip",
		Vector3.new(0.12 * S, 0.05 * S, 0.15 * S),
		HORROR_CONFIG.TONGUE_COLOR,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	CreateMesh(tongueTip, Enum.MeshType.Sphere, Vector3.new(1, 0.4, 1.2))

	-- Saliva/baba
	local droolStrands = {}
	for i = 1, 4 do
		local strand = CreatePart(
			"Drool"..i,
			Vector3.new(0.02 * S, 0.15 * S, 0.02 * S),
			HORROR_CONFIG.SALIVA,
			Enum.Material.SmoothPlastic,
			0.4,
			npcModel
		)
		table.insert(droolStrands, {
			part = strand,
			xOff = (i - 2.5) * 0.1 * S,
			baseLength = 0.15 * S
		})
	end

	-- ---------------------------------------------------------------------------
	-- OREJAS - HUMANAS PERO DEFORMADAS
	-- ---------------------------------------------------------------------------

	local ears = {}
	for side = -1, 1, 2 do
		local ear = CreatePart(
			"Ear"..side,
			Vector3.new(0.1 * S, 0.25 * S, 0.15 * S),
			HORROR_CONFIG.SKIN_HEALTHY,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		CreateMesh(ear, Enum.MeshType.Sphere, Vector3.new(0.4, 1, 0.8))

		local earInner = CreatePart(
			"EarInner"..side,
			Vector3.new(0.06 * S, 0.15 * S, 0.08 * S),
			HORROR_CONFIG.SKIN_PALE,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)

		table.insert(ears, {outer = ear, inner = earInner, side = side})
	end

	-- ---------------------------------------------------------------------------
	-- BRAZOS - EXTREMADAMENTE LARGOS, ARTICULACIONES VISIBLES
	-- ---------------------------------------------------------------------------

	local arms = {}
	for side = -1, 1, 2 do
		local armFolder = Instance.new("Folder")
		armFolder.Name = side == -1 and "LeftArm" or "RightArm"
		armFolder.Parent = npcModel

		-- Hombro (articulación visible)
		local shoulder = CreateBallPart(
			"Shoulder",
			HORROR_CONFIG.SHOULDER_SIZE,
			HORROR_CONFIG.SKIN_SICK,
			Enum.Material.SmoothPlastic,
			armFolder
		)

		-- Clavícula visible
		local clavicle = CreatePart(
			"Clavicle",
			Vector3.new(0.5 * S, 0.08 * S, 0.08 * S),
			HORROR_CONFIG.BONE_WHITE,
			Enum.Material.SmoothPlastic,
			0.3,
			armFolder
		)

		-- Brazo superior
		local upperArm = CreatePart(
			"UpperArm",
			HORROR_CONFIG.UPPER_ARM_SIZE,
			HORROR_CONFIG.SKIN_PALE,
			Enum.Material.SmoothPlastic,
			0,
			armFolder
		)
		CreateMesh(upperArm, Enum.MeshType.Cylinder)

		-- Músculos visibles en brazo
		local upperArmMuscle = CreatePart(
			"UpperArmMuscle",
			Vector3.new(HORROR_CONFIG.UPPER_ARM_SIZE.X * 1.2, HORROR_CONFIG.UPPER_ARM_SIZE.Y * 0.4, HORROR_CONFIG.UPPER_ARM_SIZE.Z * 1.1),
			HORROR_CONFIG.SKIN_HEALTHY,
			Enum.Material.SmoothPlastic,
			0,
			armFolder
		)
		CreateMesh(upperArmMuscle, Enum.MeshType.Sphere, Vector3.new(1, 0.5, 0.8))

		-- Codo (hueso muy visible, puede doblarse hacia atrás)
		local elbow = CreateBallPart(
			"Elbow",
			0.22 * S,
			HORROR_CONFIG.BONE_OLD,
			Enum.Material.SmoothPlastic,
			armFolder
		)
		elbow.Transparency = 0.3

		-- Antebrazo (muy largo)
		local forearm = CreatePart(
			"Forearm",
			HORROR_CONFIG.FOREARM_SIZE,
			HORROR_CONFIG.SKIN_SICK,
			Enum.Material.SmoothPlastic,
			0,
			armFolder
		)
		CreateMesh(forearm, Enum.MeshType.Cylinder)

		-- Tendones visibles en antebrazo
		local forearmTendons = {}
		for t = 1, 3 do
			local tendon = CreatePart(
				"ForearmTendon"..t,
				Vector3.new(0.03 * S, HORROR_CONFIG.FOREARM_SIZE.Y * 0.8, 0.02 * S),
				HORROR_CONFIG.SKIN_VEINS,
				Enum.Material.SmoothPlastic,
				0.2,
				armFolder
			)
			table.insert(forearmTendons, {part = tendon, angle = (t-1) * (math.pi * 2 / 3)})
		end

		-- Muñeca
		local wrist = CreateBallPart(
			"Wrist",
			0.12 * S,
			HORROR_CONFIG.BONE_WHITE,
			Enum.Material.SmoothPlastic,
			armFolder
		)
		wrist.Transparency = 0.4

		-- Mano (grande, huesuda)
		local hand = CreatePart(
			"Hand",
			HORROR_CONFIG.HAND_SIZE,
			HORROR_CONFIG.SKIN_PALE,
			Enum.Material.SmoothPlastic,
			0,
			armFolder
		)
		CreateMesh(hand, Enum.MeshType.Sphere, Vector3.new(1, 1.2, 0.35))

		-- Nudillos visibles
		local knuckles = {}
		for k = 1, 4 do
			local knuckle = CreateBallPart(
				"Knuckle"..k,
				0.06 * S,
				HORROR_CONFIG.BONE_WHITE,
				Enum.Material.SmoothPlastic,
				armFolder
			)
			knuckle.Transparency = 0.4
			table.insert(knuckles, {part = knuckle, xOff = (k - 2.5) * 0.12 * S})
		end

		-- Dedos (5 dedos con 3 segmentos cada uno + garra)
		local fingers = {}
		for f = 1, 5 do
			local segments = {}
			local segLengths = {0.4, 0.35, 0.3}
			local segWidths = {0.045, 0.04, 0.035}

			for seg = 1, 3 do
				local segment = CreatePart(
					"Finger"..f.."_Seg"..seg,
					Vector3.new(segWidths[seg] * S, HORROR_CONFIG.FINGER_LENGTH * segLengths[seg], segWidths[seg] * S),
					seg == 3 and HORROR_CONFIG.SKIN_DEAD or HORROR_CONFIG.SKIN_PALE,
					Enum.Material.SmoothPlastic,
					0,
					armFolder
				)

				-- Articulación del dedo
				local joint = CreateBallPart(
					"FingerJoint"..f.."_"..seg,
					segWidths[seg] * 1.1 * S,
					HORROR_CONFIG.SKIN_SICK,
					Enum.Material.SmoothPlastic,
					armFolder
				)

				table.insert(segments, {part = segment, joint = joint})
			end

			-- Uña/Garra (larga y sucia)
			local nailCondition = math.random()
			local nailColor = nailCondition < 0.3 and HORROR_CONFIG.NAIL_BLACK or
				(nailCondition < 0.6 and HORROR_CONFIG.NAIL_DIRTY or HORROR_CONFIG.NAIL_HEALTHY)
			local nail = CreatePart(
				"Nail"..f,
				Vector3.new(0.035 * S, 0.18 * S, 0.05 * S),
				nailColor,
				Enum.Material.SmoothPlastic,
				0,
				armFolder
			)
			CreateMesh(nail, Enum.MeshType.Wedge)

			table.insert(fingers, {
				segments = segments,
				nail = nail,
				index = f,
				xOff = (f - 3) * 0.12 * S,
				curlPhase = math.random() * math.pi,
				isThumb = f == 1
			})
		end

		table.insert(arms, {
			folder = armFolder,
			shoulder = shoulder,
			clavicle = clavicle,
			upperArm = upperArm,
			upperArmMuscle = upperArmMuscle,
			elbow = elbow,
			forearm = forearm,
			forearmTendons = forearmTendons,
			wrist = wrist,
			hand = hand,
			knuckles = knuckles,
			fingers = fingers,
			side = side
		})
	end

	-- ---------------------------------------------------------------------------
	-- PIERNAS - ARTICULACIONES QUE PUEDEN INVERTIRSE
	-- ---------------------------------------------------------------------------

	local legs = {}
	for side = -1, 1, 2 do
		local legFolder = Instance.new("Folder")
		legFolder.Name = side == -1 and "LeftLeg" or "RightLeg"
		legFolder.Parent = npcModel

		-- Cadera
		local hip = CreateBallPart(
			"Hip",
			HORROR_CONFIG.HIP_SIZE,
			HORROR_CONFIG.SKIN_SICK,
			Enum.Material.SmoothPlastic,
			legFolder
		)

		-- Muslo
		local thigh = CreatePart(
			"Thigh",
			HORROR_CONFIG.THIGH_SIZE,
			HORROR_CONFIG.SKIN_PALE,
			Enum.Material.SmoothPlastic,
			0,
			legFolder
		)
		CreateMesh(thigh, Enum.MeshType.Cylinder)

		-- Músculo del muslo
		local thighMuscle = CreatePart(
			"ThighMuscle",
			Vector3.new(HORROR_CONFIG.THIGH_SIZE.X * 1.3, HORROR_CONFIG.THIGH_SIZE.Y * 0.35, HORROR_CONFIG.THIGH_SIZE.Z * 1.2),
			HORROR_CONFIG.SKIN_HEALTHY,
			Enum.Material.SmoothPlastic,
			0,
			legFolder
		)
		CreateMesh(thighMuscle, Enum.MeshType.Sphere, Vector3.new(1, 0.4, 0.9))

		-- Rodilla (muy prominente)
		local knee = CreateBallPart(
			"Knee",
			0.28 * S,
			HORROR_CONFIG.BONE_WHITE,
			Enum.Material.SmoothPlastic,
			legFolder
		)
		knee.Transparency = 0.25

		-- Rótula visible
		local kneecap = CreatePart(
			"Kneecap",
			Vector3.new(0.15 * S, 0.15 * S, 0.1 * S),
			HORROR_CONFIG.BONE_OLD,
			Enum.Material.SmoothPlastic,
			0.3,
			legFolder
		)
		CreateMesh(kneecap, Enum.MeshType.Sphere)

		-- Espinilla
		local shin = CreatePart(
			"Shin",
			HORROR_CONFIG.SHIN_SIZE,
			HORROR_CONFIG.SKIN_SICK,
			Enum.Material.SmoothPlastic,
			0,
			legFolder
		)
		CreateMesh(shin, Enum.MeshType.Cylinder)

		-- Hueso de la espinilla visible
		local shinBone = CreatePart(
			"ShinBone",
			Vector3.new(0.06 * S, HORROR_CONFIG.SHIN_SIZE.Y * 0.9, 0.08 * S),
			HORROR_CONFIG.BONE_WHITE,
			Enum.Material.SmoothPlastic,
			0.4,
			legFolder
		)

		-- Tobillo
		local ankle = CreateBallPart(
			"Ankle",
			0.15 * S,
			HORROR_CONFIG.BONE_OLD,
			Enum.Material.SmoothPlastic,
			legFolder
		)
		ankle.Transparency = 0.35

		-- Pie
		local foot = CreatePart(
			"Foot",
			HORROR_CONFIG.FOOT_SIZE,
			HORROR_CONFIG.SKIN_DEAD,
			Enum.Material.SmoothPlastic,
			0,
			legFolder
		)
		CreateMesh(foot, Enum.MeshType.Sphere, Vector3.new(0.7, 0.4, 1.5))

		-- Dedos del pie
		local toes = {}
		for t = 1, 5 do
			local toeSize = t == 1 and 0.08 or 0.06
			local toe = CreatePart(
				"Toe"..t,
				Vector3.new(toeSize * S, toeSize * S, 0.12 * S),
				HORROR_CONFIG.SKIN_DEAD,
				Enum.Material.SmoothPlastic,
				0,
				legFolder
			)
			CreateMesh(toe, Enum.MeshType.Sphere)

			local toeNail = CreatePart(
				"ToeNail"..t,
				Vector3.new(toeSize * 0.8 * S, 0.03 * S, 0.06 * S),
				HORROR_CONFIG.NAIL_DIRTY,
				Enum.Material.SmoothPlastic,
				0,
				legFolder
			)

			table.insert(toes, {
				part = toe,
				nail = toeNail,
				xOff = (t - 3) * 0.055 * S
			})
		end

		table.insert(legs, {
			folder = legFolder,
			hip = hip,
			thigh = thigh,
			thighMuscle = thighMuscle,
			knee = knee,
			kneecap = kneecap,
			shin = shin,
			shinBone = shinBone,
			ankle = ankle,
			foot = foot,
			toes = toes,
			side = side
		})
	end

	-- ---------------------------------------------------------------------------
	-- EFECTOS DE PARTÍCULAS
	-- ---------------------------------------------------------------------------

	-- Aura de oscuridad más intensa
	local darkAura = Instance.new("ParticleEmitter")
	darkAura.Texture = "rbxassetid://243098098"
	darkAura.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 15, 25)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 5, 12))
	})
	darkAura.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5 * S),
		NumberSequenceKeypoint.new(0.5, 1.5 * S),
		NumberSequenceKeypoint.new(1, 2.5 * S)
	})
	darkAura.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.75),
		NumberSequenceKeypoint.new(1, 1)
	})
	darkAura.Lifetime = NumberRange.new(0.8, 1.5)
	darkAura.Rate = 15
	darkAura.Speed = NumberRange.new(0.5, 1.5)
	darkAura.SpreadAngle = Vector2.new(360, 360)
	darkAura.Parent = torsoUpper

	-- Babeo más intenso
	local droolEmitter = Instance.new("ParticleEmitter")
	droolEmitter.Texture = "rbxassetid://243098098"
	droolEmitter.Color = ColorSequence.new(HORROR_CONFIG.SALIVA)
	droolEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05 * S),
		NumberSequenceKeypoint.new(1, 0.02 * S)
	})
	droolEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1)
	})
	droolEmitter.Lifetime = NumberRange.new(0.4, 0.8)
	droolEmitter.Rate = 0
	droolEmitter.Speed = NumberRange.new(0.5, 1.5)
	droolEmitter.Acceleration = Vector3.new(0, -25, 0)
	droolEmitter.Parent = jaw

	-- Vapor de respiración
	local breathMist = Instance.new("ParticleEmitter")
	breathMist.Texture = "rbxassetid://243098098"
	breathMist.Color = ColorSequence.new(Color3.fromRGB(150, 140, 130))
	breathMist.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15 * S),
		NumberSequenceKeypoint.new(0.5, 0.4 * S),
		NumberSequenceKeypoint.new(1, 0.7 * S)
	})
	breathMist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1)
	})
	breathMist.Lifetime = NumberRange.new(0.3, 0.6)
	breathMist.Rate = 0
	breathMist.Speed = NumberRange.new(2, 4)
	breathMist.Parent = jaw

	-- ---------------------------------------------------------------------------
	-- VARIABLES DE ANIMACIÓN
	-- ---------------------------------------------------------------------------

	local npcX = spawnPosition.X
	local npcZ = spawnPosition.Z
	local npcRotation = zDir > 0 and 0 or math.pi

	local animTime = 0
	local breathTime = 0
	local twitchTimer = 0
	local headRotationExtra = 0
	local targetHeadRotation = 0
	local neckTwist = 0
	local targetNeckTwist = 0

	local isQuadruped = false
	local quadrupedBlend = 0
	local isWalking = false
	local isAttacking = false
	local mouthOpen = 0
	local currentSpeed = HORROR_CONFIG.SPEED_BIPEDAL
	local isFrozen = false

	-- ---------------------------------------------------------------------------
	-- FUNCIÓN DE ACTUALIZACIÓN - CORREGIDA PARA CAMINAR CORRECTAMENTE
	-- ---------------------------------------------------------------------------

	local function UpdateNPCPosition(x, z, rotY, walking, deltaTime, targetDistance, targetPos)
		npcX = x
		npcZ = z
		npcRotation = rotY or npcRotation
		isWalking = walking or false

		if deltaTime then
			animTime = animTime + deltaTime * (isQuadruped and 20 or 5)
			breathTime = breathTime + deltaTime * HORROR_CONFIG.BREATHING_RATE
			twitchTimer = twitchTimer + deltaTime
		end

		-- Efecto stop-motion
		if not isFrozen and math.random() < HORROR_CONFIG.STOP_MOTION_CHANCE * deltaTime then
			isFrozen = true
			task.delay(0.03 + math.random() * 0.12, function()
				isFrozen = false
			end)
		end

		if isFrozen then return end

		-- Determinar modo cuadrúpedo
		local shouldBeQuadruped = targetDistance and targetDistance < HORROR_CONFIG.CHASE_THRESHOLD and isWalking

		if shouldBeQuadruped and quadrupedBlend < 1 then
			quadrupedBlend = math.min(1, quadrupedBlend + deltaTime / HORROR_CONFIG.SPEED_TRANSITION)
		elseif not shouldBeQuadruped and quadrupedBlend > 0 then
			quadrupedBlend = math.max(0, quadrupedBlend - deltaTime / HORROR_CONFIG.SPEED_TRANSITION)
		end

		isQuadruped = quadrupedBlend > 0.5
		currentSpeed = Lerp(HORROR_CONFIG.SPEED_BIPEDAL, HORROR_CONFIG.SPEED_QUADRUPED, quadrupedBlend)

		-- Partículas
		droolEmitter.Rate = quadrupedBlend * 10
		breathMist.Rate = quadrupedBlend * 6

		-- Altura base
		local baseHeight = Lerp(baseHeightBipedal, baseHeightQuadruped, quadrupedBlend)

		-- Movimientos perturbadores
		local walkBob = isWalking and math.sin(animTime * 2) * (0.12 + quadrupedBlend * 0.25) * S or 0
		local sway = isWalking and math.sin(animTime * 1.2) * (0.1 + quadrupedBlend * 0.2) * S or 0

		-- Twitches
		local twitchX, twitchY, twitchZ = 0, 0, 0
		if math.random() < HORROR_CONFIG.TWITCH_FREQUENCY * (1 + quadrupedBlend * 2) * deltaTime * 60 then
			twitchX = (math.random() - 0.5) * 0.2 * S
			twitchY = (math.random() - 0.5) * 0.15 * S
			twitchZ = (math.random() - 0.5) * 0.2 * S
		end

		-- Cuello puede girar para mirar hacia atrás
		if math.random() < HORROR_CONFIG.NECK_CRACK_CHANCE * deltaTime * 60 then
			targetNeckTwist = (math.random() - 0.5) * math.pi * 0.8
		end
		neckTwist = LerpAngle(neckTwist, targetNeckTwist, deltaTime * 3)

		local baseY = groundY + baseHeight + walkBob

		-- =====================================================================
		-- INCLINACIÓN DEL TORSO - CORREGIDA
		-- En modo cuadrúpedo:  el torso se inclina hacia ADELANTE (no hacia atrás)
		-- La cara mira hacia el suelo/jugador, no hacia arriba
		-- =====================================================================

		local torsoLean = Lerp(math.rad(5), math.rad(85), quadrupedBlend)  -- Se inclina hacia adelante
		local torsoRoll = isWalking and math.sin(animTime * 1.5) * math.rad(6 + quadrupedBlend * 12) or 0
		local torsoPitch = math.sin(animTime * 0.7) * math.rad(2)

		local baseCFrame = CFrame.new(x + sway + twitchX, baseY + twitchY, z + twitchZ) 
			* CFrame.Angles(0, npcRotation, 0)
			* CFrame.Angles(torsoLean + torsoPitch, 0, torsoRoll)

		-- -----------------------------------------------------------------------
		-- TORSO
		-- -----------------------------------------------------------------------
		torsoUpper.CFrame = baseCFrame
		torsoLower.CFrame = baseCFrame * CFrame.new(0, -HORROR_CONFIG.TORSO_UPPER_SIZE.Y * 0.55, 0.1 * S)

		-- Costillas (respiran)
		for _, rib in ipairs(ribs) do
			local ribY = HORROR_CONFIG.TORSO_UPPER_SIZE.Y * 0.3 - (rib.index - 1) * 0.18 * S
			local ribExpand = math.sin(breathTime * math.pi) * 0.025 * S
			local ribAngle = rib.side * math.rad(35 + math.sin(breathTime) * 5)
			rib.part.CFrame = torsoUpper.CFrame 
				* CFrame.new(rib.side * (HORROR_CONFIG.TORSO_UPPER_SIZE.X * 0.3 + ribExpand), ribY, -HORROR_CONFIG.TORSO_UPPER_SIZE.Z * 0.3)
				* CFrame.Angles(0, ribAngle, math.rad(rib.side * 25))
		end

		-- Columna vertebral
		for i, seg in ipairs(spineSegments) do
			local spineY = HORROR_CONFIG.TORSO_UPPER_SIZE.Y * 0.4 - (i - 1) * 0.25 * S
			local waveOffset = math.sin(animTime * 0.6 + i * 0.4) * 0.04 * S
			seg.part.CFrame = baseCFrame 
				* CFrame.new(waveOffset, spineY, HORROR_CONFIG.TORSO_UPPER_SIZE.Z * 0.4)
				* CFrame.Angles(math.rad(8), 0, 0)
		end

		-- Venas del torso (pulsan)
		for _, vein in ipairs(torsoVeins) do
			local pulse = 1 + math.sin(breathTime * 4 + vein.pulsePhase) * 0.2
			vein.part.Size = Vector3.new(0.03 * S * pulse, vein.part.Size.Y, 0.03 * S * pulse)
			vein.part.CFrame = torsoUpper.CFrame * CFrame.new(vein.offset)
		end

		-- Heridas
		for _, wound in ipairs(wounds) do
			wound.part.CFrame = torsoUpper.CFrame * CFrame.new(wound.offset)
		end

		-- -----------------------------------------------------------------------
		-- CUELLO - Se extiende hacia adelante en modo cuadrúpedo
		-- -----------------------------------------------------------------------

		local neckForwardOffset = Lerp(0, 0.8 * S, quadrupedBlend)
		local neckUpOffset = Lerp(HORROR_CONFIG.TORSO_UPPER_SIZE.Y * 0.5, 0.2 * S, quadrupedBlend)

		-- El cuello se curva para que la cabeza mire hacia adelante/abajo
		local neckBaseBend = Lerp(math.rad(-10), math.rad(-60), quadrupedBlend)

		local neckBaseCFrame = baseCFrame * CFrame.new(0, neckUpOffset, -neckForwardOffset)

		for i, seg in ipairs(neckSegments) do
			local t = i / #neckSegments
			local segBend = math.sin(animTime * 1.5 + i * 0.4) * math.rad(6)
			local segTwist = neckTwist * t + math.sin(animTime * 1.2 + i * 0.3) * math.rad(4)

			local segForward = t * neckForwardOffset * 0.5
			local segUp = t * 0.15 * S

			seg.part.CFrame = neckBaseCFrame 
				* CFrame.new(0, segUp, -segForward)
				* CFrame.Angles(neckBaseBend * t + segBend, segTwist, 0)
				* CFrame.Angles(0, 0, math.rad(90))

			-- Tendones del cuello
			for _, tendon in ipairs(seg.tendons) do
				local tOff = 0.12 * S
				tendon.part.CFrame = seg.part.CFrame 
					* CFrame.Angles(0, 0, -math.rad(90))
					* CFrame.new(math.cos(tendon.angle) * tOff, 0, math.sin(tendon.angle) * tOff)
			end
		end

		-- -----------------------------------------------------------------------
		-- CABEZA - CORREGIDA:  Mira hacia ADELANTE/ABAJO en modo cuadrúpedo
		-- -----------------------------------------------------------------------

		local lastNeckSeg = neckSegments[#neckSegments]

		-- Calcular posición de la cabeza
		local headForward = Lerp(0.3 * S, 0.6 * S, quadrupedBlend)
		local headUp = Lerp(0.4 * S, 0.1 * S, quadrupedBlend)

		-- En modo cuadrúpedo, la cabeza se inclina para mirar hacia adelante (hacia el jugador)
		-- NO hacia arriba.La cara debe estar orientada hacia donde se mueve.
		local headPitch = Lerp(math.rad(0), math.rad(-70), quadrupedBlend)  -- Negativo = mira hacia abajo/adelante

		-- Twitches de cabeza
		local headTwitchX = math.sin(twitchTimer * HORROR_CONFIG.HEAD_ROTATION_SPEED) * math.rad(4)
		local headTwitchZ = math.cos(twitchTimer * HORROR_CONFIG.HEAD_ROTATION_SPEED * 0.7) * math.rad(3)

		-- Twitch violento ocasional
		if math.random() < 0.012 then
			headTwitchX = headTwitchX + (math.random() - 0.5) * math.rad(35)
			headTwitchZ = headTwitchZ + (math.random() - 0.5) * math.rad(25)
		end

		local headCFrame = lastNeckSeg.part.CFrame
			* CFrame.Angles(0, 0, -math.rad(90))  -- Corregir rotación del cilindro
			* CFrame.new(0, headUp, -headForward)
			* CFrame.Angles(headPitch + headTwitchX, neckTwist * 0.3, headTwitchZ)

		head.CFrame = headCFrame

		-- Frente
		forehead.CFrame = headCFrame * CFrame.new(0, HORROR_CONFIG.HEAD_SIZE.Y * 0.25, -HORROR_CONFIG.HEAD_SIZE.Z * 0.35)

		-- Venas de la cabeza (pulsan)
		for _, vein in ipairs(headVeins) do
			local pulse = 1 + math.sin(breathTime * 3.5 + vein.pulsePhase) * 0.18
			vein.part.Size = Vector3.new(0.025 * S * pulse, vein.part.Size.Y, 0.02 * S * pulse)
			vein.part.CFrame = headCFrame * CFrame.new(vein.offset)
		end

		-- Pelo
		for _, strand in ipairs(hairStrands) do
			local swayAngle = math.sin(animTime * 1.8 + strand.swayPhase) * math.rad(12)
			strand.part.CFrame = headCFrame 
				* CFrame.new(strand.offset)
				* CFrame.Angles(swayAngle, 0, swayAngle * 0.4)
		end

		-- Orejas
		for _, ear in ipairs(ears) do
			ear.outer.CFrame = headCFrame * CFrame.new(ear.side * HORROR_CONFIG.HEAD_SIZE.X * 0.5, 0, 0)
			ear.inner.CFrame = ear.outer.CFrame * CFrame.new(ear.side * 0.02 * S, 0, -0.02 * S)
		end

		-- -----------------------------------------------------------------------
		-- OJOS - Siempre intentan mirar al jugador
		-- -----------------------------------------------------------------------

		local pupilDilation = Lerp(1, 2.2, quadrupedBlend)  -- Pupilas se dilatan cuando persigue

		for _, eyeData in ipairs(eyes) do
			local cfg = eyeData.config

			-- Parpadeo asimétrico
			if not eyeData.isBlinking and math.random() < 0.008 then
				eyeData.isBlinking = true
				eyeData.blinkTime = 0
				eyeData.blinkDuration = 0.04 + math.random() * 0.08
			end

			if eyeData.isBlinking then
				eyeData.blinkTime = eyeData.blinkTime + deltaTime
				if eyeData.blinkTime >= eyeData.blinkDuration then
					eyeData.isBlinking = false
				end
			end

			local eyelidClose = eyeData.isBlinking and 1 or 0

			-- Movimiento de ojos - SIEMPRE intentan mirar al objetivo
			local lookX = math.sin(breathTime * 2.5 + eyeData.twitchPhase) * 0.02
			local lookY = math.cos(breathTime * 2 + eyeData.twitchPhase) * 0.015

			if targetPos then
				local toTarget = (targetPos - headCFrame.Position)
				if toTarget.Magnitude > 0.1 then
					local localTarget = headCFrame: PointToObjectSpace(targetPos)
					lookX = math.clamp(localTarget.X * 0.008, -0.04, 0.04)
					lookY = math.clamp(localTarget.Y * 0.008, -0.03, 0.03)
				end
			end

			-- Posicionar partes del ojo
			eyeData.socket.CFrame = headCFrame * CFrame.new(cfg.x, cfg.y, cfg.z)
			eyeData.eyeball.CFrame = headCFrame * CFrame.new(cfg.x + lookX, cfg.y + lookY, cfg.z - cfg.size * 0.2)

			-- Venas del ojo
			for _, vein in ipairs(eyeData.veins) do
				vein.part.CFrame = eyeData.eyeball.CFrame 
					* CFrame.Angles(0, vein.angle, 0)
					* CFrame.new(0, cfg.size * 0.25, 0)
			end

			-- Iris y pupila (siguen mirando al jugador)
			eyeData.iris.CFrame = eyeData.eyeball.CFrame * CFrame.new(lookX * 3, lookY * 3, -cfg.size * 0.35)

			local currentPupilSize = cfg.size * 0.25 * pupilDilation
			eyeData.pupil.Size = Vector3.new(currentPupilSize, currentPupilSize, currentPupilSize)
			eyeData.pupil.CFrame = eyeData.iris.CFrame * CFrame.new(0, 0, -cfg.size * 0.08)

			-- Reflejo
			eyeData.reflection.CFrame = eyeData.eyeball.CFrame * CFrame.new(lookX + 0.02, lookY + 0.02, -cfg.size * 0.45)

			-- Párpados
			local topLidY = cfg.y + cfg.size * 0.35 - eyelidClose * cfg.size * 0.4
			local bottomLidY = cfg.y - cfg.size * 0.25 + eyelidClose * cfg.size * 0.25
			eyeData.eyelidTop.CFrame = headCFrame * CFrame.new(cfg.x, topLidY, cfg.z - cfg.size * 0.15)
			eyeData.eyelidBottom.CFrame = headCFrame * CFrame.new(cfg.x, bottomLidY, cfg.z - cfg.size * 0.12)

			-- Pestañas
			for _, lash in ipairs(eyeData.lashes) do
				lash.part.CFrame = eyeData.eyelidTop.CFrame * CFrame.new(lash.xOff, cfg.size * 0.15, -cfg.size * 0.1)
					* CFrame.Angles(math.rad(-30), 0, 0)
			end

			-- Luz del ojo
			if eyeData.light then
				eyeData.light.Brightness = Lerp(0.2, 1.2, quadrupedBlend) * (1 - eyelidClose * 0.8)
			end
		end

		-- -----------------------------------------------------------------------
		-- NARIZ
		-- -----------------------------------------------------------------------
		nose.CFrame = headCFrame * CFrame.new(0.02 * S, -0.05 * S, -HORROR_CONFIG.HEAD_SIZE.Z * 0.48)
		noseBridge.CFrame = headCFrame * CFrame.new(0.03 * S, 0.1 * S, -HORROR_CONFIG.HEAD_SIZE.Z * 0.42)

		for _, nostril in ipairs(nostrils) do
			nostril.part.CFrame = nose.CFrame * CFrame.new(nostril.side * 0.06 * S, -0.1 * S, -0.05 * S)
		end

		-- -----------------------------------------------------------------------
		-- BOCA - Se abre grotescamente en modo cuadrúpedo
		-- -----------------------------------------------------------------------

		local targetMouthOpen = Lerp(0.05, 1.0, quadrupedBlend)
		if isAttacking then targetMouthOpen = 1.4 end
		mouthOpen = Lerp(mouthOpen, targetMouthOpen, deltaTime * 6)

		-- Respiración jadeante
		if isQuadruped then
			mouthOpen = mouthOpen + math.sin(animTime * 5) * 0.25
		end

		local jawDrop = mouthOpen * 0.5 * S
		local jawForward = mouthOpen * 0.15 * S

		-- Labio superior
		upperLip.CFrame = headCFrame * CFrame.new(0, -HORROR_CONFIG.HEAD_SIZE.Y * 0.35, -HORROR_CONFIG.HEAD_SIZE.Z * 0.42)

		-- Mandíbula (se desencaja)
		jaw.CFrame = headCFrame * CFrame.new(0, -HORROR_CONFIG.HEAD_SIZE.Y * 0.45 - jawDrop, -HORROR_CONFIG.HEAD_SIZE.Z * 0.35 - jawForward)
			* CFrame.Angles(math.rad(mouthOpen * 40), 0, 0)

		-- Labio inferior (sigue a la mandíbula)
		lowerLip.CFrame = jaw.CFrame * CFrame.new(0, 0.15 * S, -0.15 * S)

		-- Interior de la boca
		mouthInterior.CFrame = headCFrame * CFrame.new(0, -HORROR_CONFIG.HEAD_SIZE.Y * 0.38 - jawDrop * 0.5, -HORROR_CONFIG.HEAD_SIZE.Z * 0.32)

		-- Encías
		gumUpper.CFrame = headCFrame * CFrame.new(0, -HORROR_CONFIG.HEAD_SIZE.Y * 0.32, -HORROR_CONFIG.HEAD_SIZE.Z * 0.45)
		gumLower.CFrame = jaw.CFrame * CFrame.new(0, 0.12 * S, -0.1 * S)

		-- Dientes superiores
		for _, tooth in ipairs(teethUpper) do
			tooth.part.CFrame = gumUpper.CFrame 
				* CFrame.new(tooth.xOff, -0.05 * S, -0.02 * S)
				* CFrame.Angles(math.rad(180) + tooth.angle, 0, 0)
		end

		-- Dientes inferiores
		for _, tooth in ipairs(teethLower) do
			tooth.part.CFrame = gumLower.CFrame 
				* CFrame.new(tooth.xOff, 0.04 * S, -0.02 * S)
				* CFrame.Angles(tooth.angle, 0, 0)
		end

		-- Lengua (sale más cuando la boca está abierta)
		local tongueOut = mouthOpen * 0.3 * S
		tongue.CFrame = jaw.CFrame * CFrame.new(0, 0.08 * S, -0.05 * S - tongueOut)
			* CFrame.Angles(math.rad(-20 - mouthOpen * 25), math.sin(animTime * 2.5) * math.rad(8), 0)
		tongueTip.CFrame = tongue.CFrame * CFrame.new(0, 0, -0.2 * S)

		-- Saliva/baba
		for _, strand in ipairs(droolStrands) do
			local droolLength = strand.baseLength * (1 + mouthOpen * 3)
			strand.part.Size = Vector3.new(0.02 * S, droolLength, 0.02 * S)
			strand.part.CFrame = jaw.CFrame * CFrame.new(strand.xOff, -droolLength/2 - 0.05 * S, -0.15 * S)
		end

		-- -----------------------------------------------------------------------
		-- BRAZOS - Movimiento de araña en modo cuadrúpedo
		-- -----------------------------------------------------------------------

		for _, arm in ipairs(arms) do
			local armPhase = arm.side == -1 and 0 or math.pi
			local spiderPhase = animTime * 2.2 + armPhase

			-- Posición del hombro
			local shoulderY = Lerp(HORROR_CONFIG.TORSO_UPPER_SIZE.Y * 0.35, 0, quadrupedBlend)
			local shoulderZ = Lerp(0, -0.3 * S, quadrupedBlend)
			local shoulderOffset = Vector3.new(
				arm.side * HORROR_CONFIG.TORSO_UPPER_SIZE.X * 0.55,
				shoulderY,
				shoulderZ
			)
			local shoulderCFrame = baseCFrame * CFrame.new(shoulderOffset)
			arm.shoulder.CFrame = shoulderCFrame

			-- Clavícula
			arm.clavicle.CFrame = baseCFrame * CFrame.new(arm.side * HORROR_CONFIG.TORSO_UPPER_SIZE.X * 0.3, HORROR_CONFIG.TORSO_UPPER_SIZE.Y * 0.4, -0.1 * S)
				* CFrame.Angles(0, arm.side * math.rad(25), math.rad(arm.side * 10))

			-- Ángulos del brazo
			local upperArmPitch, upperArmRoll, forearmPitch

			if quadrupedBlend < 0.5 then
				-- Modo bípedo
				local walkSwing = isWalking and math.sin(animTime + armPhase) * math.rad(25) or 0
				upperArmPitch = math.rad(-15) + walkSwing
				upperArmRoll = arm.side * math.rad(12)
				forearmPitch = math.rad(-35) - math.abs(math.sin(animTime + armPhase)) * math.rad(20)
			else
				-- Modo cuadrúpedo - movimiento de araña
				upperArmPitch = math.rad(-80) + math.sin(spiderPhase) * math.rad(40)
				upperArmRoll = arm.side * math.rad(35)
				forearmPitch = math.rad(-100) + math.cos(spiderPhase) * math.rad(35)
			end

			-- Interpolar
			upperArmPitch = Lerp(
				math.rad(-15) + (isWalking and math.sin(animTime + armPhase) * math.rad(25) or 0),
				math.rad(-80) + math.sin(spiderPhase) * math.rad(40),
				quadrupedBlend
			)
			forearmPitch = Lerp(
				math.rad(-35) - math.abs(math.sin(animTime + armPhase)) * math.rad(20),
				math.rad(-100) + math.cos(spiderPhase) * math.rad(35),
				quadrupedBlend
			)
			upperArmRoll = Lerp(arm.side * math.rad(12), arm.side * math.rad(35), quadrupedBlend)

			-- Brazo superior
			local upperArmCFrame = shoulderCFrame
				* CFrame.Angles(upperArmPitch, 0, upperArmRoll)
				* CFrame.new(0, -HORROR_CONFIG.UPPER_ARM_SIZE.Y * 0.5, 0)
			arm.upperArm.CFrame = upperArmCFrame * CFrame.Angles(0, 0, math.rad(90))
			arm.upperArmMuscle.CFrame = upperArmCFrame * CFrame.new(arm.side * 0.05 * S, HORROR_CONFIG.UPPER_ARM_SIZE.Y * 0.15, 0)

			-- Codo
			local elbowCFrame = upperArmCFrame * CFrame.new(0, -HORROR_CONFIG.UPPER_ARM_SIZE.Y * 0.5, 0)
			arm.elbow.CFrame = elbowCFrame

			-- Antebrazo
			local forearmCFrame = elbowCFrame
				* CFrame.Angles(forearmPitch, 0, 0)
				* CFrame.new(0, -HORROR_CONFIG.FOREARM_SIZE.Y * 0.5, 0)
			arm.forearm.CFrame = forearmCFrame * CFrame.Angles(0, 0, math.rad(90))

			-- Tendones del antebrazo
			for _, tendon in ipairs(arm.forearmTendons) do
				local tOff = HORROR_CONFIG.FOREARM_SIZE.X * 0.4
				tendon.part.CFrame = forearmCFrame 
					* CFrame.new(math.cos(tendon.angle) * tOff, 0, math.sin(tendon.angle) * tOff)
			end

			-- Muñeca
			local wristCFrame = forearmCFrame * CFrame.new(0, -HORROR_CONFIG.FOREARM_SIZE.Y * 0.5, 0)
			arm.wrist.CFrame = wristCFrame

			-- Mano
			local handPitch = Lerp(math.rad(10), math.rad(-85), quadrupedBlend)
			local handCFrame = wristCFrame * CFrame.Angles(handPitch, 0, 0) * CFrame.new(0, -HORROR_CONFIG.HAND_SIZE.Y * 0.4, 0)
			arm.hand.CFrame = handCFrame

			-- Nudillos
			for _, knuckle in ipairs(arm.knuckles) do
				knuckle.part.CFrame = handCFrame * CFrame.new(knuckle.xOff, -HORROR_CONFIG.HAND_SIZE.Y * 0.3, -0.02 * S)
			end

			-- Dedos
			local baseCurl = Lerp(math.rad(20), math.rad(75), quadrupedBlend)
			if isAttacking then baseCurl = math.rad(95) end

			for _, finger in ipairs(arm.fingers) do
				local fingerCurl = baseCurl + math.sin(breathTime * 1.5 + finger.curlPhase) * math.rad(10)
				local fingerSpread = (finger.index - 3) * math.rad(8)

				-- Posición base del dedo
				local fingerBaseX = finger.xOff
				if finger.isThumb then
					fingerBaseX = arm.side * HORROR_CONFIG.HAND_SIZE.X * 0.35
				end

				local prevCFrame = handCFrame * CFrame.new(fingerBaseX, -HORROR_CONFIG.HAND_SIZE.Y * 0.35, -0.02 * S)
					* CFrame.Angles(0, fingerSpread, 0)

				for segIdx, seg in ipairs(finger.segments) do
					local segCurl = fingerCurl * (0.4 + segIdx * 0.2)
					if finger.isThumb then segCurl = segCurl * 0.6 end

					seg.joint.CFrame = prevCFrame

					local segCFrame = prevCFrame * CFrame.Angles(segCurl, 0, 0)
						* CFrame.new(0, -seg.part.Size.Y * 0.5, 0)
					seg.part.CFrame = segCFrame

					prevCFrame = segCFrame * CFrame.new(0, -seg.part.Size.Y * 0.5, 0)
				end

				-- Uña
				finger.nail.CFrame = prevCFrame * CFrame.Angles(math.rad(40), 0, 0)
					* CFrame.new(0, -0.08 * S, 0)
			end
		end

		-- -----------------------------------------------------------------------
		-- PIERNAS - Articulaciones invertidas en modo cuadrúpedo
		-- -----------------------------------------------------------------------

		for _, leg in ipairs(legs) do
			local legPhase = leg.side == -1 and math.pi or 0
			local walkCycle = isWalking and math.sin(animTime + legPhase) or 0
			local walkLift = isWalking and math.max(0, math.sin(animTime + legPhase)) * 0.3 * S or 0

			-- Cadera
			local hipY = Lerp(-HORROR_CONFIG.TORSO_LOWER_SIZE.Y * 0.4, -HORROR_CONFIG.TORSO_LOWER_SIZE.Y * 0.2, quadrupedBlend)
			local hipZ = Lerp(0.1 * S, 0.4 * S, quadrupedBlend)
			local hipOffset = Vector3.new(
				leg.side * HORROR_CONFIG.TORSO_LOWER_SIZE.X * 0.4,
				hipY,
				hipZ
			)
			local hipCFrame = baseCFrame * CFrame.new(hipOffset)
			leg.hip.CFrame = hipCFrame

			-- Ángulos de la pierna
			local thighPitch, shinPitch
			local kneeDirection = Lerp(-1, 1, quadrupedBlend)  -- Invertir rodilla en modo cuadrúpedo

			thighPitch = Lerp(math.rad(10), math.rad(-45), quadrupedBlend) + walkCycle * math.rad(35)
			shinPitch = Lerp(math.rad(20), math.rad(85), quadrupedBlend) + walkCycle * math.rad(20)

			-- Muslo
			local thighCFrame = hipCFrame
				* CFrame.Angles(thighPitch, 0, leg.side * math.rad(6))
				* CFrame.new(0, -HORROR_CONFIG.THIGH_SIZE.Y * 0.5, 0)
			leg.thigh.CFrame = thighCFrame * CFrame.Angles(0, 0, math.rad(90))
			leg.thighMuscle.CFrame = thighCFrame * CFrame.new(0, HORROR_CONFIG.THIGH_SIZE.Y * 0.1, -leg.side * 0.05 * S)

			-- Rodilla
			local kneeCFrame = thighCFrame * CFrame.new(0, -HORROR_CONFIG.THIGH_SIZE.Y * 0.5, 0)
			leg.knee.CFrame = kneeCFrame
			leg.kneecap.CFrame = kneeCFrame * CFrame.new(0, 0, -0.12 * S * kneeDirection)

			-- Espinilla
			local shinCFrame = kneeCFrame
				* CFrame.Angles(shinPitch * kneeDirection, 0, 0)
				* CFrame.new(0, -HORROR_CONFIG.SHIN_SIZE.Y * 0.5, 0)
			leg.shin.CFrame = shinCFrame * CFrame.Angles(0, 0, math.rad(90))
			leg.shinBone.CFrame = shinCFrame * CFrame.new(0, 0, -0.08 * S)

			-- Tobillo
			local ankleCFrame = shinCFrame * CFrame.new(0, -HORROR_CONFIG.SHIN_SIZE.Y * 0.5, 0)
			leg.ankle.CFrame = ankleCFrame

			-- Pie (toca el suelo)
			local footY = groundY + 0.1 * S + walkLift
			local footTarget = Vector3.new(ankleCFrame.Position.X, footY, ankleCFrame.Position.Z)
			local footCFrame = CFrame.new(footTarget) * CFrame.Angles(0, npcRotation, 0)
			leg.foot.CFrame = footCFrame

			-- Dedos del pie
			for _, toe in ipairs(leg.toes) do
				toe.part.CFrame = footCFrame * CFrame.new(toe.xOff, 0.03 * S, -HORROR_CONFIG.FOOT_SIZE.Z * 0.4)
				toe.nail.CFrame = toe.part.CFrame * CFrame.new(0, 0.02 * S, -0.06 * S)
			end
		end
	end

	-- Posición inicial
	UpdateNPCPosition(npcX, npcZ, npcRotation, false, 0, 999, nil)

	-- ---------------------------------------------------------------------------
	-- SONIDOS PERTURBADORES
	-- ---------------------------------------------------------------------------

	-- Sonido de aparición (grito distorsionado)
	local spawnSound = Instance.new("Sound")
	spawnSound.SoundId = "rbxassetid://9114221735"
	spawnSound.Volume = 1.5
	spawnSound.PlaybackSpeed = 0.5
	spawnSound.Parent = torsoUpper
	spawnSound:Play()

	-- Respiración agitada
	local breathingSound = Instance.new("Sound")
	breathingSound.SoundId = "rbxassetid://122922351443677"
	breathingSound.Volume = 0.5
	breathingSound.Looped = true
	breathingSound.PlaybackSpeed = 0.7
	breathingSound.Parent = head
	breathingSound:Play()

	-- Gruñido gutural
	local growlSound = Instance.new("Sound")
	growlSound.SoundId = "rbxassetid://9114221580"
	growlSound.Volume = 0.7
	growlSound.PlaybackSpeed = 0.35
	growlSound.Parent = head

	-- Huesos crujiendo
	local boneSound = Instance.new("Sound")
	boneSound.SoundId = "rbxassetid://5766332557"
	boneSound.Volume = 0.5
	boneSound.PlaybackSpeed = 0.5
	boneSound.Parent = torsoUpper

	-- Pasos/galope
	local gallopSound = Instance.new("Sound")
	gallopSound.SoundId = "rbxassetid://99852253884447"
	gallopSound.Volume = 0.9
	gallopSound.Looped = true
	gallopSound.PlaybackSpeed = 2.0
	gallopSound.Parent = torsoUpper
	gallopSound:Play()

	-- Grito de ataque
	local screamSound = Instance.new("Sound")
	screamSound.SoundId = "rbxassetid://9114221580"
	screamSound.Volume = 1.0
	screamSound.PlaybackSpeed = 1.0
	screamSound.Parent = head

	-- ---------------------------------------------------------------------------
	-- ANIMACIÓN DE ATAQUE
	-- ---------------------------------------------------------------------------

	local function PlayAttackAnimation(targetPos)
		if isAttacking then return end
		isAttacking = true

		-- Ojos brillan
		for _, eyeData in ipairs(eyes) do
			if eyeData.light then
				TweenService:Create(eyeData.light, TweenInfo.new(0.06), {Brightness = 6}):Play()
			end
			TweenService:Create(eyeData.eyeball, TweenInfo.new(0.06), {Color = Color3.fromRGB(255, 230, 200)}):Play()
		end

		mouthOpen = 1.5
		screamSound:Play()
		darkAura.Rate = 40

		-- Lunge
		local lungeDir = (targetPos - Vector3.new(npcX, 0, npcZ))
		if lungeDir.Magnitude > 0.1 then
			lungeDir = lungeDir.Unit
		else
			lungeDir = Vector3.new(0, 0, -1)
		end

		local startX, startZ = npcX, npcZ
		local lungeDistance = 5 * S
		local endX = npcX + lungeDir.X * lungeDistance
		local endZ = npcZ + lungeDir.Z * lungeDistance

		if not IsInLobby(endX) then
			for i = 1, 12 do
				local t = i / 12
				local easeT = 1 - (1 - t) * (1 - t)
				npcX = startX + (endX - startX) * easeT
				npcZ = startZ + (endZ - startZ) * easeT
				task.wait(0.012)
			end
		end

		task.wait(0.12)

		-- Reset
		for _, eyeData in ipairs(eyes) do
			if eyeData.light then
				TweenService:Create(eyeData.light, TweenInfo.new(0.25), {Brightness = Lerp(0.2, 1.2, quadrupedBlend)}):Play()
			end
			local origColor = eyeData.config.hidden and HORROR_CONFIG.EYE_SCLERA_SICK or HORROR_CONFIG.EYE_SCLERA
			TweenService:Create(eyeData.eyeball, TweenInfo.new(0.25), {Color = origColor}):Play()
		end

		darkAura.Rate = 15
		isAttacking = false
	end

	-- ---------------------------------------------------------------------------
	-- EFECTO DE MUERTE
	-- ---------------------------------------------------------------------------

	local function PlayDeathEffect()
		darkAura.Enabled = false
		droolEmitter.Enabled = false
		breathMist.Enabled = false
		breathingSound:Stop()
		gallopSound:Stop()

		local deathScream = Instance.new("Sound")
		deathScream.SoundId = "rbxassetid://9114221580"
		deathScream.Volume = 1.3
		deathScream.PlaybackSpeed = 0.3
		deathScream.Parent = head
		deathScream:Play()

		-- Huesos rompiéndose
		for i = 1, 4 do
			task.delay(i * 0.15, function()
				local crack = Instance.new("Sound")
				crack.SoundId = "rbxassetid://5766332557"
				crack.Volume = 0.6
				crack.PlaybackSpeed = 0.4 + math.random() * 0.3
				crack.Parent = torsoUpper
				crack:Play()
				Debris:AddItem(crack, 2)
			end)
		end

		-- Ojos se apagan
		for i, eyeData in ipairs(eyes) do
			task.delay(i * 0.12, function()
				if eyeData.light then
					TweenService:Create(eyeData.light, TweenInfo.new(0.4), {Brightness = 0}):Play()
				end
				TweenService:Create(eyeData.eyeball, TweenInfo.new(0.4), {Color = Color3.fromRGB(50, 50, 50)}):Play()
			end)
		end

		task.wait(0.5)

		-- Colapso
		for _, part in pairs(npcModel:GetDescendants()) do
			if part:IsA("BasePart") then
				TweenService:Create(part, TweenInfo.new(1.0, Enum.EasingStyle.Quad), {
					Transparency = 1,
					Position = part.Position + Vector3.new(
						(math.random() - 0.5) * 0.8 * S,
						-1.2 * S,
						(math.random() - 0.5) * 0.8 * S
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
	local lastAttackTime = 0
	local lastBoneCrackTime = 0

	local function FindNearestPlayer()
		local nearest, nearestDist = nil, HORROR_CONFIG.DETECTION_RANGE
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
		if tick() - lastAttackTime < HORROR_CONFIG.ATTACK_COOLDOWN then return end
		if isAttacking then return end
		lastAttackTime = tick()

		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChild("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")

		if hum and hum.Health > 0 and hrp then
			coroutine.wrap(function()
				PlayAttackAnimation(hrp.Position)
			end)()

			task.wait(0.1)

			local dist = (hrp.Position - Vector3.new(npcX, 0, npcZ)).Magnitude
			if dist < HORROR_CONFIG.ATTACK_RANGE and hum.Health > 0 then
				local hitSound = Instance.new("Sound")
				hitSound.SoundId = "rbxassetid://5766332557"
				hitSound.Volume = 0.9
				hitSound.PlaybackSpeed = 1.0
				hitSound.Parent = torsoUpper
				hitSound: Play()

				hum:TakeDamage(HORROR_CONFIG.DAMAGE)
				Debris:AddItem(hitSound, 1)
			end
		end
	end

	-- ---------------------------------------------------------------------------
	-- LOOP PRINCIPAL
	-- ---------------------------------------------------------------------------

	local chaseConnection
	chaseConnection = RunService.Heartbeat:Connect(function(dt)
		if not isAlive or not torsoUpper or not torsoUpper.Parent then
			if chaseConnection then chaseConnection:Disconnect() end
			return
		end

		-- Lifetime check
		local elapsedTime = tick() - spawnTime
		if elapsedTime >= npcLifetime then
			print("?? Flesh Crawler lifetime expired")
			isAlive = false
			if chaseConnection then chaseConnection: Disconnect() end
			PlayDeathEffect()
			task.wait(1.2)
			if npcFolder and npcFolder.Parent then
				npcFolder:Destroy()
			end
			return
		end

		-- Stunned check
		if npcModel: GetAttribute("Stunned") then
			UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, 999, nil)
			return
		end

		-- .check
		if IsInLobby(npcX) then
			print("?? Flesh Crawler entered .- destroying")
			isAlive = false
			if chaseConnection then chaseConnection:Disconnect() end
			PlayDeathEffect()
			task.wait(1.2)
			if npcFolder and npcFolder.Parent then
				npcFolder:Destroy()
			end
			return
		end

		local target, distance = FindNearestPlayer()
		local targetPosition = nil

		if target and target.Character then
			local hrp = target.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				targetPosition = hrp.Position
			end
		end

		-- Sonidos
		breathingSound.PlaybackSpeed = Lerp(0.5, 1.0, quadrupedBlend)
		breathingSound.Volume = Lerp(0.5, 0.9, quadrupedBlend)
		gallopSound.Volume = Lerp(0, 0.7, quadrupedBlend)

		-- Huesos crujiendo
		if isWalking and tick() - lastBoneCrackTime > (1 / HORROR_CONFIG.BONE_CRACK_FREQUENCY) then
			if math.random() < 0.35 then
				lastBoneCrackTime = tick()
				local crack = Instance.new("Sound")
				crack.SoundId = "rbxassetid://5766332557"
				crack.Volume = 0.25 + quadrupedBlend * 0.25
				crack.PlaybackSpeed = 0.4 + math.random() * 0.4
				crack.Parent = torsoUpper
				crack:Play()
				Debris:AddItem(crack, 1.5)
			end
		end

		if target then
			local char = target.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					local direction = Vector3.new(hrp.Position.X - npcX, 0, hrp.Position.Z - npcZ)

					if direction.Magnitude > 0.5 then
						local lookAngle = math.atan2(-direction.X, -direction.Z)

						if distance > HORROR_CONFIG.ATTACK_RANGE then
							local moveDir = direction.Unit
							local newX = npcX + moveDir.X * currentSpeed * dt
							local newZ = npcZ + moveDir.Z * currentSpeed * dt

							if not IsInLobby(newX) then
								UpdateNPCPosition(newX, newZ, lookAngle, true, dt, distance, targetPosition)
							else
								UpdateNPCPosition(npcX, npcZ, lookAngle, false, dt, distance, targetPosition)
							end
						else
							UpdateNPCPosition(npcX, npcZ, lookAngle, false, dt, distance, targetPosition)
							AttackPlayer(target)
						end
					else
						UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, distance, targetPosition)
					end
				else
					UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, 999, nil)
				end
			else
				UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, 999, nil)
			end
		else
			if math.random() < 0.003 then
				npcRotation = npcRotation + (math.random() - 0.5) * math.rad(60)
			end
			UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, 999, nil)
		end
	end)

	-- ---------------------------------------------------------------------------
	-- COMPORTAMIENTOS AMBIENTALES
	-- ---------------------------------------------------------------------------

	-- Gruñidos aleatorios
	coroutine.wrap(function()
		while isAlive and head and head.Parent do
			task.wait(math.random(3, 8))
			if isAlive and head and head.Parent and not isAttacking then
				local growl = Instance.new("Sound")
				growl.SoundId = "rbxassetid://9114221580"
				growl.Volume = 0.3 + quadrupedBlend * 0.4
				growl.PlaybackSpeed = 0.25 + math.random() * 1.00
				growl.Parent = head
				growl:Play()
				Debris:AddItem(growl, 4)
			end
		end
	end)()

	-- Gritos ocasionales
	coroutine.wrap(function()
		while isAlive and head and head.Parent do
			task.wait(math.random(12, 25))
			if isAlive and not isAttacking and math.random() < HORROR_CONFIG.SCREAM_CHANCE * 15 then
				local scream = Instance.new("Sound")
				scream.SoundId = "rbxassetid://9114221580"
				scream.Volume = 0.8
				scream.PlaybackSpeed = 1.0 + math.random() * 0.6
				scream.Parent = head
				scream:Play()

				for _, eyeData in ipairs(eyes) do
					if eyeData.light then
						eyeData.light.Brightness = 4
						task.delay(0.6, function()
							if eyeData.light then
								eyeData.light.Brightness = Lerp(0.2, 1.2, quadrupedBlend)
							end
						end)
					end
				end

				Debris:AddItem(scream, 4)
			end
		end
	end)()

	-- Cuello girando para mirar atrás
	coroutine.wrap(function()
		while isAlive and head and head.Parent do
			task.wait(math.random(6, 15))
			if isAlive and not isAttacking then
				targetNeckTwist = (math.random() - 0.5) * math.pi * 0.7

				-- Sonido de cuello crujiendo
				local neckCrack = Instance.new("Sound")
				neckCrack.SoundId = "rbxassetid://5766332557"
				neckCrack.Volume = 0.4
				neckCrack.PlaybackSpeed = 0.6
				neckCrack.Parent = head
				neckCrack:Play()
				Debris:AddItem(neckCrack, 2)

				task.wait(1.5 + math.random() * 1.5)
				targetNeckTwist = 0
			end
		end
	end)()

	-- Sonidos de transición de modo
	coroutine.wrap(function()
		local lastQuadState = isQuadruped
		while isAlive and torsoUpper and torsoUpper.Parent do
			task.wait(0.1)
			if isQuadruped ~= lastQuadState then
				for i = 1, 4 do
					task.delay(i * 0.08, function()
						if torsoUpper and torsoUpper.Parent then
							local crack = Instance.new("Sound")
							crack.SoundId = "rbxassetid://5766332557"
							crack.Volume = 0.55
							crack.PlaybackSpeed = 0.45 + math.random() * 1.0
							crack.Parent = torsoUpper
							crack: Play()
							Debris: AddItem(crack, 2)
						end
					end)
				end

				if isQuadruped then
					task.wait(0.12)
					growlSound.PlaybackSpeed = 0.4
					growlSound: Play()
				end

				lastQuadState = isQuadruped
			end
		end
	end)()

	-- Cleanup
	npcFolder.AncestryChanged:Connect(function()
		if not npcFolder.Parent then
			isAlive = false
			breathingSound:Stop()
			gallopSound:Stop()
			if chaseConnection then chaseConnection: Disconnect() end
		end
	end)

	return npcFolder
end

-- -------------------------------------------------------------------------------
-- EVENT LISTENER
-- -------------------------------------------------------------------------------

if SpawnCrawlerEvent then
	SpawnCrawlerEvent.Event:Connect(function(position, player, side, zDir, doorFrameInfo, lifetime)
		print("?????? SpawnFleshCrawlerEvent received - Lifetime: "..tostring(lifetime))
		task.wait(0.2)
		CreateHorrorNPC(position, player, side, zDir, doorFrameInfo, lifetime)
	end)
end

print("=== THE FLESH CRAWLER - ULTIMATE HORROR V7 ===")
print("   Scale: "..S.."x GIGANTE")
print("   Bipedal Speed: "..HORROR_CONFIG.SPEED_BIPEDAL)
print("   Quadruped Speed: "..HORROR_CONFIG.SPEED_QUADRUPED)
print("   Chase Threshold: "..HORROR_CONFIG.CHASE_THRESHOLD.." studs")
print("")
print("   CARACTERÍSTICAS DE TERROR:")
print("   ? Piel humana realista pero enferma")
print("   ? Ojos que SIEMPRE te miran")
print("   ? Mandíbula que se DESENCAJA")
print("   ? Cuello que gira 180 grados")
print("   ? Articulaciones INVERTIDAS")
print("   ? Camina en 4 patas HACIA TI")
print("   ? Costillas y huesos VISIBLES")
print("   ? Venas que PULSAN")
print("   ? Sonidos de huesos CRUJIENDO")
print("   ? Efecto STOP-MOTION perturbador")
print("   ? Dedos con 3 articulaciones + garras")
print("   ? Saliva/baba goteando")
print("===============================================")