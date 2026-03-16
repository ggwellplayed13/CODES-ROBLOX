--[[
    +------------------------------------------------------------------------------+
    |                    PHANTOM HORROR ENTITY SYSTEM                               |
    |                 VERSIÓN 6 - "THE WEEPING SPECTER"                             |
    |                      TERROR ETÉREO - PESADILLA FLOTANTE                       |
    +------------------------------------------------------------------------------+
    
    Un espíritu atormentado GIGANTE que: 
    - Flota de forma antinatural con movimientos erráticos
    - Tiene una cara humana destrozada que LLORA SANGRE
    - Cabeza que se DESENCAJA y gira de forma imposible
    - Brazos extremadamente largos que se estiran para alcanzarte
    - SUSURRA tu nombre antes de atacar
    - Se TELETRANSPORTA apareciendo DETRÁS de ti
    - Deja un rastro de niebla y lamentos
    - Su boca se abre revelando un VACÍO INFINITO
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local SpawnPhantomEvent = ReplicatedStorage:WaitForChild("SpawnPhantomEvent", 10)

-- -------------------------------------------------------------------------------
-- CONFIGURACIÓN DEL TERROR ETÉREO
-- -------------------------------------------------------------------------------
local PHANTOM_CONFIG = {
	-- ESCALA
	SCALE = 2.5,                  -- MUY grande, imponente

	-- VELOCIDADES
	SPEED_NORMAL = 12,
	SPEED_HUNTING = 22,           -- Más rápido cuando te persigue
	SPEED_ERRATIC = 35,           -- Velocidad de movimiento errático

	-- COMBATE
	DAMAGE = 40,
	ATTACK_COOLDOWN = 1.2,
	ATTACK_RANGE = 10,
	DETECTION_RANGE = 300,

	-- TELETRANSPORTE
	TELEPORT_COOLDOWN = 4,
	TELEPORT_RANGE = 25,
	TELEPORT_BEHIND_CHANCE = 0.6, -- 60% chance de aparecer DETRÁS del jugador

	-- COLORES - ESPECTRO ATORMENTADO
	-- Piel espectral (como un cadáver ahogado)
	SKIN_GHOSTLY = Color3.fromRGB(180, 190, 200),
	SKIN_PALE = Color3.fromRGB(160, 170, 185),
	SKIN_DEAD = Color3.fromRGB(140, 150, 170),
	SKIN_BRUISED = Color3.fromRGB(120, 100, 130),
	SKIN_VEINS = Color3.fromRGB(80, 60, 100),

	-- Sangre y lágrimas
	BLOOD_FRESH = Color3.fromRGB(80, 20, 30),
	BLOOD_OLD = Color3.fromRGB(50, 15, 20),
	TEARS_BLOOD = Color3.fromRGB(100, 25, 35),

	-- Ojos (hundidos, vacíos, lloran sangre)
	EYE_SOCKET = Color3.fromRGB(20, 15, 25),
	EYE_VOID = Color3.fromRGB(5, 5, 10),
	EYE_GLOW = Color3.fromRGB(200, 220, 255),
	EYE_GLOW_ANGRY = Color3.fromRGB(255, 100, 100),

	-- Boca (vacío infinito)
	MOUTH_VOID = Color3.fromRGB(3, 3, 8),
	MOUTH_INTERIOR = Color3.fromRGB(15, 10, 20),
	TEETH_COLOR = Color3.fromRGB(200, 190, 170),
	TEETH_ROTTEN = Color3.fromRGB(120, 110, 80),

	-- Ropa/Mortaja desgarrada
	SHROUD_MAIN = Color3.fromRGB(40, 45, 55),
	SHROUD_TORN = Color3.fromRGB(30, 35, 45),
	SHROUD_FADE = Color3.fromRGB(20, 25, 35),

	-- Efectos espectrales
	GLOW_COLD = Color3.fromRGB(150, 180, 220),
	GLOW_INTENSE = Color3.fromRGB(200, 230, 255),
	MIST_COLOR = Color3.fromRGB(100, 120, 150),
	SOUL_WISP = Color3.fromRGB(180, 200, 240),

	-- Pelo (largo, mojado, cubre parte de la cara)
	HAIR_WET = Color3.fromRGB(15, 12, 10),
	HAIR_GRAY = Color3.fromRGB(60, 55, 50),

	-- DIMENSIONES (escaladas)
	HEAD_SIZE = Vector3.new(1.4, 1.6, 1.3),
	TORSO_SIZE = Vector3.new(1.8, 2.2, 0.8),
	ARM_LENGTH = 3.5,             -- Brazos MUY largos
	HAND_SIZE = Vector3.new(0.6, 0.8, 0.15),
	FINGER_LENGTH = 0.7,

	-- COMPORTAMIENTO PERTURBADOR
	HEAD_TWITCH_CHANCE = 0.15,
	HEAD_SNAP_CHANCE = 0.03,      -- Chance de girar cabeza 180° instantáneamente
	ARM_REACH_CHANCE = 0.08,      -- Chance de estirar brazos hacia ti
	FLICKER_CHANCE = 0.05,        -- Chance de "parpadear" como estática
	CRYING_INTENSITY = 1.0,

	-- FLOTACIÓN
	FLOAT_HEIGHT = 2.0,
	FLOAT_AMPLITUDE = 0.5,
	FLOAT_SPEED = 1.2,
	SWAY_AMOUNT = 0.3,

	LOBBY_START_X = -75,
	LOBBY_END_X = 75,
}

-- Aplicar escala
local S = PHANTOM_CONFIG.SCALE
PHANTOM_CONFIG.HEAD_SIZE = PHANTOM_CONFIG.HEAD_SIZE * S
PHANTOM_CONFIG.TORSO_SIZE = PHANTOM_CONFIG.TORSO_SIZE * S
PHANTOM_CONFIG.HAND_SIZE = PHANTOM_CONFIG.HAND_SIZE * S
PHANTOM_CONFIG.ARM_LENGTH = PHANTOM_CONFIG.ARM_LENGTH * S
PHANTOM_CONFIG.FINGER_LENGTH = PHANTOM_CONFIG.FINGER_LENGTH * S
PHANTOM_CONFIG.FLOAT_HEIGHT = PHANTOM_CONFIG.FLOAT_HEIGHT * S
PHANTOM_CONFIG.FLOAT_AMPLITUDE = PHANTOM_CONFIG.FLOAT_AMPLITUDE * S

local function IsInLobby(x)
	return x >= PHANTOM_CONFIG.LOBBY_START_X and x <= PHANTOM_CONFIG.LOBBY_END_X
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
	part.CastShadow = false
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
-- CREAR THE WEEPING SPECTER
-- -------------------------------------------------------------------------------

local function CreatePhantomNPC(spawnPosition, triggerPlayer, side, zDir, doorFrameInfo, lifetime)
	local npcLifetime = lifetime
	if not npcLifetime or npcLifetime <= 0 then
		npcLifetime = 55
	end

	print("===========================================")
	print("?????? THE WEEPING SPECTER SPAWNED ??????")
	print("   Scale: "..S.."x")
	print("   Lifetime:  "..npcLifetime.." seconds")
	print("   Position: "..tostring(spawnPosition))
	print("===========================================")

	local npcFolder = Instance.new("Folder")
	npcFolder.Name = "PhantomEntity"
	npcFolder.Parent = workspace

	local npcModel = Instance.new("Model")
	npcModel.Name = "TheWeepingSpecter"
	npcModel.Parent = npcFolder

	local spawnTime = tick()
	npcFolder: SetAttribute("SpawnTime", spawnTime)
	npcFolder:SetAttribute("Lifetime", npcLifetime)
	npcModel:SetAttribute("SpawnTime", spawnTime)
	npcModel:SetAttribute("Lifetime", npcLifetime)

	local groundY = 0.5

	-- ---------------------------------------------------------------------------
	-- TORSO/CUERPO - Mortaja desgarrada
	-- ---------------------------------------------------------------------------

	-- Torso principal (fantasmal, semi-transparente)
	local torso = CreatePart(
		"Torso",
		PHANTOM_CONFIG.TORSO_SIZE,
		PHANTOM_CONFIG.SKIN_GHOSTLY,
		Enum.Material.Glass,
		0.3,
		npcModel
	)
	torso.CanCollide = true
	CreateMesh(torso, Enum.MeshType.Sphere, Vector3.new(1, 1.2, 0.6))

	-- Capas de mortaja desgarrada
	local shroudLayers = {}
	for i = 1, 5 do
		local layerSize = PHANTOM_CONFIG.TORSO_SIZE * (1.1 + i * 0.08)
		local layer = CreatePart(
			"ShroudLayer"..i,
			layerSize,
			LerpColor(PHANTOM_CONFIG.SHROUD_MAIN, PHANTOM_CONFIG.SHROUD_FADE, i/5),
			Enum.Material.Fabric,
			0.4 + i * 0.1,
			npcModel
		)
		CreateMesh(layer, Enum.MeshType.Sphere, Vector3.new(1, 1.1 + i * 0.1, 0.5))
		table.insert(shroudLayers, {part = layer, offset = i * 0.05 * S})
	end

	-- Jirones de tela colgando
	local shroudTatters = {}
	for i = 1, 12 do
		local tatterLength = (0.8 + math.random() * 1.2) * S
		local tatter = CreatePart(
			"Tatter"..i,
			Vector3.new(0.15 * S, tatterLength, 0.08 * S),
			PHANTOM_CONFIG.SHROUD_TORN,
			Enum.Material.Fabric,
			0.3 + math.random() * 0.3,
			npcModel
		)
		table.insert(shroudTatters, {
			part = tatter,
			angle = (i / 12) * math.pi * 2,
			length = tatterLength,
			swayPhase = math.random() * math.pi * 2
		})
	end

	-- Costillas visibles a través de la piel translúcida
	local visibleRibs = {}
	for i = 1, 6 do
		for side = -1, 1, 2 do
			local rib = CreatePart(
				"Rib"..i.."_"..side,
				Vector3.new(0.5 * S, 0.04 * S, 0.06 * S),
				PHANTOM_CONFIG.SKIN_DEAD,
				Enum.Material.Glass,
				0.5,
				npcModel
			)
			table.insert(visibleRibs, {part = rib, index = i, side = side})
		end
	end

	-- ---------------------------------------------------------------------------
	-- CUELLO - Largo, puede estirarse y girar
	-- ---------------------------------------------------------------------------

	local neckSegments = {}
	local numNeckSegs = 5
	for i = 1, numNeckSegs do
		local segSize = (0.35 - i * 0.03) * S
		local seg = CreatePart(
			"NeckSeg"..i,
			Vector3.new(segSize, 0.2 * S, segSize),
			PHANTOM_CONFIG.SKIN_PALE,
			Enum.Material.Glass,
			0.25,
			npcModel
		)
		CreateMesh(seg, Enum.MeshType.Cylinder)
		table.insert(neckSegments, {
			part = seg,
			baseSize = segSize,
			bendAngle = 0,
			twistAngle = 0
		})
	end

	-- Venas/tendones visibles en el cuello
	local neckVeins = {}
	for i = 1, 4 do
		local vein = CreatePart(
			"NeckVein"..i,
			Vector3.new(0.025 * S, 0.8 * S, 0.02 * S),
			PHANTOM_CONFIG.SKIN_VEINS,
			Enum.Material.Glass,
			0.4,
			npcModel
		)
		table.insert(neckVeins, {part = vein, angle = (i - 1) * (math.pi / 2)})
	end

	-- ---------------------------------------------------------------------------
	-- CABEZA - Cara humana destrozada que llora sangre
	-- ---------------------------------------------------------------------------

	local head = CreatePart(
		"Head",
		PHANTOM_CONFIG.HEAD_SIZE,
		PHANTOM_CONFIG.SKIN_GHOSTLY,
		Enum.Material.Glass,
		0.15,
		npcModel
	)
	CreateMesh(head, Enum.MeshType.Sphere, Vector3.new(1, 1.1, 0.95))

	-- Piel de la cara - demacrada, hundida
	local cheekLeft = CreatePart(
		"CheekLeft",
		Vector3.new(0.35 * S, 0.4 * S, 0.25 * S),
		PHANTOM_CONFIG.SKIN_DEAD,
		Enum.Material.Glass,
		0.2,
		npcModel
	)
	CreateMesh(cheekLeft, Enum.MeshType.Sphere, Vector3.new(1, 1, 0.4))

	local cheekRight = CreatePart(
		"CheekRight",
		Vector3.new(0.35 * S, 0.4 * S, 0.25 * S),
		PHANTOM_CONFIG.SKIN_DEAD,
		Enum.Material.Glass,
		0.2,
		npcModel
	)
	CreateMesh(cheekRight, Enum.MeshType.Sphere, Vector3.new(1, 1, 0.4))

	-- Frente con venas
	local forehead = CreatePart(
		"Forehead",
		Vector3.new(0.9 * S, 0.4 * S, 0.2 * S),
		PHANTOM_CONFIG.SKIN_PALE,
		Enum.Material.Glass,
		0.2,
		npcModel
	)
	CreateMesh(forehead, Enum.MeshType.Sphere, Vector3.new(1, 0.5, 0.3))

	-- Venas en la cabeza (pulsan)
	local headVeins = {}
	for i = 1, 8 do
		local vein = CreatePart(
			"HeadVein"..i,
			Vector3.new(0.02 * S, (0.15 + math.random() * 0.2) * S, 0.015 * S),
			PHANTOM_CONFIG.SKIN_VEINS,
			Enum.Material.Glass,
			0.3,
			npcModel
		)
		table.insert(headVeins, {
			part = vein,
			offset = Vector3.new(
				(math.random() - 0.5) * 0.8 * S,
				(math.random() - 0.3) * 0.6 * S,
				(math.random() - 0.5) * 0.5 * S
			),
			pulsePhase = math.random() * math.pi * 2
		})
	end

	-- ---------------------------------------------------------------------------
	-- PELO - Largo, mojado, cubre parcialmente la cara
	-- ---------------------------------------------------------------------------

	local hairStrands = {}
	for i = 1, 30 do
		local strandLength = (0.4 + math.random() * 0.8) * S
		local strand = CreatePart(
			"Hair"..i,
			Vector3.new(0.025 * S, strandLength, 0.02 * S),
			math.random() > 0.2 and PHANTOM_CONFIG.HAIR_WET or PHANTOM_CONFIG.HAIR_GRAY,
			Enum.Material.Glass,
			0.2,
			npcModel
		)

		-- Algunos mechones caen sobre la cara
		local coversFace = i <= 8
		table.insert(hairStrands, {
			part = strand,
			offset = Vector3.new(
				(math.random() - 0.5) * 0.7 * S,
				0.5 * S + math.random() * 0.2 * S,
				coversFace and (-0.3 - math.random() * 0.3) * S or (math.random() - 0.5) * 0.4 * S
			),
			length = strandLength,
			swayPhase = math.random() * math.pi * 2,
			coversFace = coversFace
		})
	end

	-- ---------------------------------------------------------------------------
	-- OJOS - Cuencas hundidas, vacías, LLORAN SANGRE
	-- ---------------------------------------------------------------------------

	local eyes = {}
	local eyeConfigs = {
		{x = -0.28 * S, y = 0.15 * S, z = -0.5 * S, size = 0.28 * S},
		{x = 0.28 * S, y = 0.12 * S, z = -0.48 * S, size = 0.26 * S},
	}

	for i, config in ipairs(eyeConfigs) do
		-- Cuenca profundamente hundida
		local socket = CreatePart(
			"EyeSocket"..i,
			Vector3.new(config.size * 1.8, config.size * 1.6, config.size * 0.8),
			PHANTOM_CONFIG.EYE_SOCKET,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		CreateMesh(socket, Enum.MeshType.Sphere)

		-- Vacío profundo dentro del ojo
		local void = CreatePart(
			"EyeVoid"..i,
			Vector3.new(config.size * 1.2, config.size * 1.0, config.size * 0.5),
			PHANTOM_CONFIG.EYE_VOID,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		CreateMesh(void, Enum.MeshType.Sphere)

		-- Brillo espectral (aparece y desaparece)
		local glow = CreateBallPart(
			"EyeGlow"..i,
			config.size * 0.4,
			PHANTOM_CONFIG.EYE_GLOW,
			Enum.Material.Neon,
			npcModel
		)
		glow.Transparency = 0.3

		-- Luz del ojo
		local eyeLight = Instance.new("PointLight")
		eyeLight.Color = PHANTOM_CONFIG.EYE_GLOW
		eyeLight.Brightness = 2
		eyeLight.Range = 8 * S
		eyeLight.Shadows = true
		eyeLight.Parent = glow

		-- LÁGRIMAS DE SANGRE
		local bloodTears = {}
		for t = 1, 3 do
			local tear = CreatePart(
				"BloodTear"..i.."_"..t,
				Vector3.new(0.03 * S, (0.2 + math.random() * 0.3) * S, 0.02 * S),
				PHANTOM_CONFIG.TEARS_BLOOD,
				Enum.Material.Glass,
				0.2,
				npcModel
			)
			table.insert(bloodTears, {
				part = tear,
				xOff = (t - 2) * 0.05 * S,
				length = 0.2 + math.random() * 0.3,
				flowPhase = math.random() * math.pi * 2
			})
		end

		table.insert(eyes, {
			socket = socket,
			void = void,
			glow = glow,
			light = eyeLight,
			bloodTears = bloodTears,
			config = config,
			glowIntensity = 0,
			targetGlowIntensity = 1,
			twitchPhase = math.random() * math.pi * 2
		})
	end

	-- ---------------------------------------------------------------------------
	-- NARIZ - Apenas visible, cartílago
	-- ---------------------------------------------------------------------------

	local nose = CreatePart(
		"Nose",
		Vector3.new(0.12 * S, 0.2 * S, 0.15 * S),
		PHANTOM_CONFIG.SKIN_DEAD,
		Enum.Material.Glass,
		0.3,
		npcModel
	)
	CreateMesh(nose, Enum.MeshType.Sphere, Vector3.new(0.5, 1, 0.8))

	local nostrilLeft = CreatePart(
		"NostrilL",
		Vector3.new(0.04 * S, 0.03 * S, 0.05 * S),
		PHANTOM_CONFIG.MOUTH_INTERIOR,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)

	local nostrilRight = CreatePart(
		"NostrilR",
		Vector3.new(0.04 * S, 0.03 * S, 0.05 * S),
		PHANTOM_CONFIG.MOUTH_INTERIOR,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)

	-- ---------------------------------------------------------------------------
	-- BOCA - Se abre revelando un VACÍO INFINITO
	-- ---------------------------------------------------------------------------

	-- Labios pálidos, agrietados
	local upperLip = CreatePart(
		"UpperLip",
		Vector3.new(0.45 * S, 0.08 * S, 0.15 * S),
		PHANTOM_CONFIG.SKIN_BRUISED,
		Enum.Material.Glass,
		0.2,
		npcModel
	)
	CreateMesh(upperLip, Enum.MeshType.Sphere, Vector3.new(1, 0.5, 0.6))

	local lowerLip = CreatePart(
		"LowerLip",
		Vector3.new(0.4 * S, 0.06 * S, 0.12 * S),
		PHANTOM_CONFIG.SKIN_DEAD,
		Enum.Material.Glass,
		0.2,
		npcModel
	)
	CreateMesh(lowerLip, Enum.MeshType.Sphere, Vector3.new(1, 0.4, 0.5))

	-- Mandíbula (puede desencajarse MUCHO)
	local jaw = CreatePart(
		"Jaw",
		Vector3.new(0.7 * S, 0.35 * S, 0.5 * S),
		PHANTOM_CONFIG.SKIN_PALE,
		Enum.Material.Glass,
		0.2,
		npcModel
	)
	CreateMesh(jaw, Enum.MeshType.Sphere, Vector3.new(1, 0.6, 0.8))

	-- Interior de la boca - VACÍO INFINITO
	local mouthVoid = CreatePart(
		"MouthVoid",
		Vector3.new(0.5 * S, 0.4 * S, 0.6 * S),
		PHANTOM_CONFIG.MOUTH_VOID,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	CreateMesh(mouthVoid, Enum.MeshType.Sphere)

	-- Oscuridad que se extiende desde la boca cuando está abierta
	local voidTendrils = {}
	for i = 1, 6 do
		local tendril = CreatePart(
			"VoidTendril"..i,
			Vector3.new(0.04 * S, 0.3 * S, 0.04 * S),
			PHANTOM_CONFIG.MOUTH_VOID,
			Enum.Material.SmoothPlastic,
			0.3,
			npcModel
		)
		table.insert(voidTendrils, {
			part = tendril,
			angle = (i / 6) * math.pi * 2,
			baseLength = 0.3 * S
		})
	end

	-- Dientes (pocos, rotos, irregulares)
	local teeth = {}
	local toothPositions = {-0.15, -0.08, 0, 0.08, 0.15}
	for i, xPos in ipairs(toothPositions) do
		if math.random() > 0.2 then -- Algunos dientes faltan
			local isRotten = math.random() < 0.4
			local toothHeight = (0.08 + math.random() * 0.06) * S
			local tooth = CreatePart(
				"Tooth"..i,
				Vector3.new(0.035 * S, toothHeight, 0.025 * S),
				isRotten and PHANTOM_CONFIG.TEETH_ROTTEN or PHANTOM_CONFIG.TEETH_COLOR,
				Enum.Material.Glass,
				0.3,
				npcModel
			)
			table.insert(teeth, {
				part = tooth,
				xOff = xPos * S,
				angle = (math.random() - 0.5) * math.rad(25),
				upper = i <= 3
			})
		end
	end

	-- ---------------------------------------------------------------------------
	-- BRAZOS - EXTREMADAMENTE LARGOS, pueden estirarse
	-- ---------------------------------------------------------------------------

	local arms = {}
	for side = -1, 1, 2 do
		local armFolder = Instance.new("Folder")
		armFolder.Name = side == -1 and "LeftArm" or "RightArm"
		armFolder.Parent = npcModel

		-- Hombro
		local shoulder = CreateBallPart(
			"Shoulder",
			0.3 * S,
			PHANTOM_CONFIG.SKIN_PALE,
			Enum.Material.Glass,
			armFolder
		)
		shoulder.Transparency = 0.25

		-- Segmentos del brazo (múltiples para poder ondular)
		local armSegments = {}
		local numArmSegs = 6
		for i = 1, numArmSegs do
			local segWidth = (0.18 - i * 0.015) * S
			local seg = CreatePart(
				"ArmSeg"..i,
				Vector3.new(segWidth, PHANTOM_CONFIG.ARM_LENGTH / numArmSegs, segWidth),
				LerpColor(PHANTOM_CONFIG.SKIN_GHOSTLY, PHANTOM_CONFIG.SKIN_DEAD, i/numArmSegs),
				Enum.Material.Glass,
				0.25 + i * 0.05,
				armFolder
			)
			CreateMesh(seg, Enum.MeshType.Cylinder)
			table.insert(armSegments, {
				part = seg,
				index = i,
				wavePhase = i * 0.3
			})
		end

		-- Muñeca
		local wrist = CreateBallPart(
			"Wrist",
			0.1 * S,
			PHANTOM_CONFIG.SKIN_DEAD,
			Enum.Material.Glass,
			armFolder
		)
		wrist.Transparency = 0.3

		-- Mano (grande, huesuda, dedos largos)
		local hand = CreatePart(
			"Hand",
			PHANTOM_CONFIG.HAND_SIZE,
			PHANTOM_CONFIG.SKIN_PALE,
			Enum.Material.Glass,
			0.2,
			armFolder
		)
		CreateMesh(hand, Enum.MeshType.Sphere, Vector3.new(1, 1.2, 0.3))

		-- Dedos (5 dedos muy largos)
		local fingers = {}
		for f = 1, 5 do
			local segments = {}
			local segLengths = {0.35, 0.35, 0.35}

			for seg = 1, 3 do
				local fingerSeg = CreatePart(
					"Finger"..f.."_"..seg,
					Vector3.new(0.03 * S, PHANTOM_CONFIG.FINGER_LENGTH * segLengths[seg], 0.025 * S),
					seg == 3 and PHANTOM_CONFIG.SKIN_DEAD or PHANTOM_CONFIG.SKIN_PALE,
					Enum.Material.Glass,
					0.25 + seg * 0.1,
					armFolder
				)
				table.insert(segments, fingerSeg)
			end

			-- Uña larga y negra
			local nail = CreatePart(
				"Nail"..f,
				Vector3.new(0.025 * S, 0.15 * S, 0.04 * S),
				Color3.fromRGB(30, 25, 20),
				Enum.Material.Glass,
				0.2,
				armFolder
			)
			CreateMesh(nail, Enum.MeshType.Wedge)

			table.insert(fingers, {
				segments = segments,
				nail = nail,
				index = f,
				xOff = (f - 3) * 0.1 * S,
				curlPhase = math.random() * math.pi
			})
		end

		-- Efecto de estiramiento (brazos pueden alargarse)
		table.insert(arms, {
			folder = armFolder,
			shoulder = shoulder,
			segments = armSegments,
			wrist = wrist,
			hand = hand,
			fingers = fingers,
			side = side,
			currentStretch = 1.0,  -- Multiplicador de longitud
			targetStretch = 1.0
		})
	end

	-- ---------------------------------------------------------------------------
	-- COLA ESPECTRAL (reemplaza piernas)
	-- ---------------------------------------------------------------------------

	local tailSegments = {}
	local numTailSegs = 12
	for i = 1, numTailSegs do
		local progress = i / numTailSegs
		local segWidth = PHANTOM_CONFIG.TORSO_SIZE.X * (1 - progress * 0.8)
		local seg = CreatePart(
			"TailSeg"..i,
			Vector3.new(segWidth, 0.25 * S, segWidth * 0.6),
			LerpColor(PHANTOM_CONFIG.SHROUD_MAIN, PHANTOM_CONFIG.SHROUD_FADE, progress),
			Enum.Material.Glass,
			0.3 + progress * 0.6,
			npcModel
		)
		CreateMesh(seg, Enum.MeshType.Sphere, Vector3.new(1, 0.5, 0.8))
		table.insert(tailSegments, {
			part = seg,
			progress = progress,
			wavePhase = i * 0.25
		})
	end

	-- Wisps finales de la cola
	local tailWisps = {}
	for i = 1, 8 do
		local wisp = CreatePart(
			"TailWisp"..i,
			Vector3.new(0.1 * S, (0.4 + math.random() * 0.4) * S, 0.08 * S),
			PHANTOM_CONFIG.SOUL_WISP,
			Enum.Material.Neon,
			0.5,
			npcModel
		)
		table.insert(tailWisps, {
			part = wisp,
			angle = (i / 8) * math.pi * 2,
			length = 0.4 + math.random() * 0.4
		})
	end

	-- ---------------------------------------------------------------------------
	-- EFECTOS DE PARTÍCULAS
	-- ---------------------------------------------------------------------------

	-- Niebla fría que emana
	local mistEmitter = Instance.new("ParticleEmitter")
	mistEmitter.Texture = "rbxassetid://243098098"
	mistEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PHANTOM_CONFIG.MIST_COLOR),
		ColorSequenceKeypoint.new(1, PHANTOM_CONFIG.SHROUD_FADE)
	})
	mistEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5 * S),
		NumberSequenceKeypoint.new(0.5, 1.5 * S),
		NumberSequenceKeypoint.new(1, 3 * S)
	})
	mistEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.7),
		NumberSequenceKeypoint.new(1, 1)
	})
	mistEmitter.Lifetime = NumberRange.new(1, 2)
	mistEmitter.Rate = 20
	mistEmitter.Speed = NumberRange.new(0.5, 2)
	mistEmitter.SpreadAngle = Vector2.new(360, 360)
	mistEmitter.Acceleration = Vector3.new(0, -2, 0)
	mistEmitter.Parent = torso

	-- Lágrimas de sangre cayendo
	local bloodDripEmitter = Instance.new("ParticleEmitter")
	bloodDripEmitter.Texture = "rbxassetid://243098098"
	bloodDripEmitter.Color = ColorSequence.new(PHANTOM_CONFIG.TEARS_BLOOD)
	bloodDripEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.03 * S),
		NumberSequenceKeypoint.new(1, 0.01 * S)
	})
	bloodDripEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1)
	})
	bloodDripEmitter.Lifetime = NumberRange.new(0.5, 1)
	bloodDripEmitter.Rate = 8
	bloodDripEmitter.Speed = NumberRange.new(0.5, 1)
	bloodDripEmitter.Acceleration = Vector3.new(0, -15, 0)
	bloodDripEmitter.Parent = head

	-- Almas atormentadas saliendo del cuerpo
	local soulEmitter = Instance.new("ParticleEmitter")
	soulEmitter.Texture = "rbxassetid://243098098"
	soulEmitter.Color = ColorSequence.new(PHANTOM_CONFIG.SOUL_WISP)
	soulEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2 * S),
		NumberSequenceKeypoint.new(0.5, 0.5 * S),
		NumberSequenceKeypoint.new(1, 0)
	})
	soulEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	soulEmitter.Lifetime = NumberRange.new(2, 4)
	soulEmitter.Rate = 3
	soulEmitter.Speed = NumberRange.new(1, 3)
	soulEmitter.SpreadAngle = Vector2.new(40, 40)
	soulEmitter.Acceleration = Vector3.new(0, 5, 0)
	soulEmitter.Parent = torso

	-- Luz central fría
	local coreLight = Instance.new("PointLight")
	coreLight.Color = PHANTOM_CONFIG.GLOW_COLD
	coreLight.Brightness = 1.5
	coreLight.Range = 20 * S
	coreLight.Shadows = true
	coreLight.Parent = torso

	-- ---------------------------------------------------------------------------
	-- VARIABLES DE ANIMACIÓN
	-- ---------------------------------------------------------------------------

	local npcX = spawnPosition.X
	local npcZ = spawnPosition.Z
	local npcRotation = zDir > 0 and 0 or math.pi

	local floatTime = 0
	local waveTime = 0
	local twitchTimer = 0

	local isAttacking = false
	local isPhasing = false
	local isTeleporting = false
	local mouthOpen = 0
	local targetMouthOpen = 0
	local headSnapped = false
	local headSnapAngle = 0
	local currentSpeed = PHANTOM_CONFIG.SPEED_NORMAL

	-- Para el efecto de estiramiento de brazos
	local armReaching = false
	local reachTarget = nil

	-- ---------------------------------------------------------------------------
	-- FUNCIÓN DE ACTUALIZACIÓN
	-- ---------------------------------------------------------------------------

	local function UpdateNPCPosition(x, z, rotY, moving, deltaTime, targetDistance, targetPos)
		npcX = x
		npcZ = z
		npcRotation = rotY or npcRotation

		if deltaTime then
			floatTime = floatTime + deltaTime * PHANTOM_CONFIG.FLOAT_SPEED
			waveTime = waveTime + deltaTime * 2
			twitchTimer = twitchTimer + deltaTime
		end

		-- Efecto de parpadeo/glitch
		local flickering = false
		if math.random() < PHANTOM_CONFIG.FLICKER_CHANCE * deltaTime * 60 then
			flickering = true
		end

		-- Flotación y movimiento errático
		local floatY = groundY + PHANTOM_CONFIG.FLOAT_HEIGHT + math.sin(floatTime * math.pi) * PHANTOM_CONFIG.FLOAT_AMPLITUDE
		local swayX = math.sin(floatTime * 0.8) * PHANTOM_CONFIG.SWAY_AMOUNT * S
		local swayZ = math.cos(floatTime * 0.6) * PHANTOM_CONFIG.SWAY_AMOUNT * 0.7 * S

		-- Movimiento errático ocasional
		if math.random() < 0.02 then
			swayX = swayX + (math.random() - 0.5) * 0.5 * S
			swayZ = swayZ + (math.random() - 0.5) * 0.5 * S
		end

		local basePos = Vector3.new(x + swayX, floatY, z + swayZ)
		local baseCFrame = CFrame.new(basePos) * CFrame.Angles(0, npcRotation, 0)

		-- Inclinación suave del cuerpo
		local bodyTilt = math.sin(floatTime * 0.5) * math.rad(5)
		local bodySway = math.cos(floatTime * 0.7) * math.rad(3)
		baseCFrame = baseCFrame * CFrame.Angles(bodyTilt, 0, bodySway)

		-- -----------------------------------------------------------------------
		-- TORSO
		-- -----------------------------------------------------------------------
		torso.CFrame = baseCFrame
		torso.Transparency = flickering and 0.8 or 0.3

		-- Capas de mortaja
		for i, layer in ipairs(shroudLayers) do
			local layerWave = math.sin(waveTime + i * 0.3) * 0.05 * S
			layer.part.CFrame = baseCFrame * CFrame.new(0, layerWave, layer.offset)
			layer.part.Transparency = flickering and 1 or (0.4 + i * 0.1)
		end

		-- Jirones de tela
		for _, tatter in ipairs(shroudTatters) do
			local tatterX = math.cos(tatter.angle) * PHANTOM_CONFIG.TORSO_SIZE.X * 0.5
			local tatterZ = math.sin(tatter.angle) * PHANTOM_CONFIG.TORSO_SIZE.Z * 0.5
			local tatterSway = math.sin(waveTime * 1.5 + tatter.swayPhase) * math.rad(20)

			tatter.part.CFrame = baseCFrame 
				* CFrame.new(tatterX, -PHANTOM_CONFIG.TORSO_SIZE.Y * 0.4, tatterZ)
				* CFrame.Angles(tatterSway, 0, math.sin(waveTime + tatter.swayPhase) * math.rad(10))
				* CFrame.new(0, -tatter.length * 0.5, 0)
		end

		-- Costillas visibles
		for _, rib in ipairs(visibleRibs) do
			local ribY = PHANTOM_CONFIG.TORSO_SIZE.Y * 0.2 - rib.index * 0.15 * S
			local ribAngle = rib.side * math.rad(35)
			rib.part.CFrame = baseCFrame 
				* CFrame.new(rib.side * 0.3 * S, ribY, -0.15 * S)
				* CFrame.Angles(0, ribAngle, math.rad(rib.side * 20))
		end

		-- -----------------------------------------------------------------------
		-- CUELLO
		-- -----------------------------------------------------------------------
		local neckBaseY = PHANTOM_CONFIG.TORSO_SIZE.Y * 0.45
		local neckBaseCFrame = baseCFrame * CFrame.new(0, neckBaseY, 0)

		-- Head snap effect (girar cabeza instantáneamente)
		if not headSnapped and math.random() < PHANTOM_CONFIG.HEAD_SNAP_CHANCE * deltaTime * 60 then
			headSnapped = true
			headSnapAngle = (math.random() - 0.5) * math.pi * 0.8
			task.delay(0.5 + math.random() * 1, function()
				headSnapped = false
				headSnapAngle = 0
			end)
		end

		for i, seg in ipairs(neckSegments) do
			local t = i / #neckSegments
			local segBend = math.sin(waveTime * 1.2 + i * 0.4) * math.rad(8)
			local segTwist = headSnapAngle * t

			seg.part.CFrame = neckBaseCFrame 
				* CFrame.new(0, t * 0.6 * S, 0)
				* CFrame.Angles(segBend, segTwist, 0)
				* CFrame.Angles(0, 0, math.rad(90))
		end

		-- Venas del cuello
		for _, vein in ipairs(neckVeins) do
			local veinOff = 0.12 * S
			vein.part.CFrame = neckBaseCFrame 
				* CFrame.new(math.cos(vein.angle) * veinOff, 0.3 * S, math.sin(vein.angle) * veinOff)
		end

		-- -----------------------------------------------------------------------
		-- CABEZA
		-- -----------------------------------------------------------------------
		local lastNeckSeg = neckSegments[#neckSegments]
		local headBob = math.sin(floatTime * 1.5) * 0.05 * S

		-- Twitches de cabeza
		local headTwitchX = 0
		local headTwitchZ = 0
		if math.random() < PHANTOM_CONFIG.HEAD_TWITCH_CHANCE * deltaTime * 60 then
			headTwitchX = (math.random() - 0.5) * math.rad(30)
			headTwitchZ = (math.random() - 0.5) * math.rad(20)
		end

		local headCFrame = lastNeckSeg.part.CFrame 
			* CFrame.Angles(0, 0, -math.rad(90))
			* CFrame.new(0, 0.4 * S + headBob, 0)
			* CFrame.Angles(headTwitchX, headSnapAngle, headTwitchZ)

		head.CFrame = headCFrame
		head.Transparency = flickering and 0.7 or 0.15

		-- Mejillas
		cheekLeft.CFrame = headCFrame * CFrame.new(-0.35 * S, -0.1 * S, -0.25 * S)
		cheekRight.CFrame = headCFrame * CFrame.new(0.35 * S, -0.1 * S, -0.25 * S)

		-- Frente
		forehead.CFrame = headCFrame * CFrame.new(0, PHANTOM_CONFIG.HEAD_SIZE.Y * 0.3, -PHANTOM_CONFIG.HEAD_SIZE.Z * 0.35)

		-- Venas de la cabeza (pulsan)
		for _, vein in ipairs(headVeins) do
			local pulse = 1 + math.sin(floatTime * 4 + vein.pulsePhase) * 0.2
			vein.part.Size = Vector3.new(0.02 * S * pulse, vein.part.Size.Y, 0.015 * S * pulse)
			vein.part.CFrame = headCFrame * CFrame.new(vein.offset)
		end

		-- Pelo
		for _, strand in ipairs(hairStrands) do
			local strandSway = math.sin(waveTime * 1.5 + strand.swayPhase) * math.rad(15)
			local gravityPull = strand.coversFace and math.rad(30) or math.rad(10)

			strand.part.CFrame = headCFrame 
				* CFrame.new(strand.offset)
				* CFrame.Angles(gravityPull + strandSway, 0, strandSway * 0.5)
		end

		-- -----------------------------------------------------------------------
		-- OJOS (lloran sangre)
		-- -----------------------------------------------------------------------
		for _, eyeData in ipairs(eyes) do
			local cfg = eyeData.config

			-- Hacer que los ojos brillen más cuando está cerca del jugador
			if targetDistance and targetDistance < 30 then
				eyeData.targetGlowIntensity = 2
			else
				eyeData.targetGlowIntensity = 0.5 + math.sin(floatTime * 2) * 0.5
			end
			eyeData.glowIntensity = Lerp(eyeData.glowIntensity, eyeData.targetGlowIntensity, deltaTime * 3)

			eyeData.socket.CFrame = headCFrame * CFrame.new(cfg.x, cfg.y, cfg.z)
			eyeData.void.CFrame = headCFrame * CFrame.new(cfg.x, cfg.y, cfg.z - 0.05 * S)

			-- Brillo aparece y desaparece
			eyeData.glow.CFrame = headCFrame * CFrame.new(cfg.x, cfg.y, cfg.z - 0.1 * S)
			eyeData.glow.Transparency = 1 - eyeData.glowIntensity * 0.7
			eyeData.glow.Size = Vector3.new(1,1,1) * cfg.size * 0.4 * eyeData.glowIntensity

			if eyeData.light then
				eyeData.light.Brightness = eyeData.glowIntensity * 3
				eyeData.light.Color = targetDistance and targetDistance < 20 and PHANTOM_CONFIG.EYE_GLOW_ANGRY or PHANTOM_CONFIG.EYE_GLOW
			end

			-- Lágrimas de sangre
			for _, tear in ipairs(eyeData.bloodTears) do
				local tearFlow = math.sin(floatTime * 3 + tear.flowPhase) * 0.05 * S
				local tearLength = tear.length * S * (1 + math.sin(floatTime * 2 + tear.flowPhase) * 0.3)
				tear.part.Size = Vector3.new(0.03 * S, tearLength, 0.02 * S)
				tear.part.CFrame = headCFrame * CFrame.new(cfg.x + tear.xOff + tearFlow, cfg.y - cfg.size * 0.7 - tearLength * 0.5, cfg.z - 0.02 * S)
			end
		end

		-- -----------------------------------------------------------------------
		-- NARIZ
		-- -----------------------------------------------------------------------
		nose.CFrame = headCFrame * CFrame.new(0, -0.05 * S, -PHANTOM_CONFIG.HEAD_SIZE.Z * 0.45)
		nostrilLeft.CFrame = nose.CFrame * CFrame.new(-0.04 * S, -0.08 * S, -0.03 * S)
		nostrilRight.CFrame = nose.CFrame * CFrame.new(0.04 * S, -0.08 * S, -0.03 * S)

		-- -----------------------------------------------------------------------
		-- BOCA
		-- -----------------------------------------------------------------------
		-- Boca se abre cuando está cerca o atacando
		if targetDistance and targetDistance < 25 then
			targetMouthOpen = 0.3 + (25 - targetDistance) / 25 * 0.7
		else
			targetMouthOpen = math.sin(floatTime * 0.5) * 0.1
		end
		if isAttacking then targetMouthOpen = 1.5 end

		mouthOpen = Lerp(mouthOpen, targetMouthOpen, deltaTime * 4)

		local mouthY = -PHANTOM_CONFIG.HEAD_SIZE.Y * 0.35
		local jawDrop = mouthOpen * 0.5 * S
		local jawForward = mouthOpen * 0.15 * S

		upperLip.CFrame = headCFrame * CFrame.new(0, mouthY, -PHANTOM_CONFIG.HEAD_SIZE.Z * 0.42)

		jaw.CFrame = headCFrame * CFrame.new(0, mouthY - 0.15 * S - jawDrop, -PHANTOM_CONFIG.HEAD_SIZE.Z * 0.35 - jawForward)
			* CFrame.Angles(math.rad(mouthOpen * 50), 0, 0)

		lowerLip.CFrame = jaw.CFrame * CFrame.new(0, 0.1 * S, -0.1 * S)

		-- Vacío de la boca
		mouthVoid.CFrame = headCFrame * CFrame.new(0, mouthY - jawDrop * 0.5, -PHANTOM_CONFIG.HEAD_SIZE.Z * 0.3)
		mouthVoid.Size = Vector3.new(0.5 * S, (0.2 + mouthOpen * 0.4) * S, 0.6 * S)
		mouthVoid.Transparency = mouthOpen > 0.3 and 0 or 0.5

		-- Zarcillos de vacío
		for _, tendril in ipairs(voidTendrils) do
			local tendrilLength = tendril.baseLength * mouthOpen * 2
			local tendrilWave = math.sin(waveTime * 3 + tendril.angle) * 0.1 * S
			local tendrilAngle = tendril.angle + waveTime * 0.5

			tendril.part.Size = Vector3.new(0.04 * S, tendrilLength, 0.04 * S)
			tendril.part.Transparency = mouthOpen < 0.3 and 1 or (0.3 + (1 - mouthOpen) * 0.5)
			tendril.part.CFrame = mouthVoid.CFrame 
				* CFrame.new(math.cos(tendrilAngle) * 0.15 * S + tendrilWave, -tendrilLength * 0.5, math.sin(tendrilAngle) * 0.1 * S)
				* CFrame.Angles(math.rad(20), tendrilAngle, 0)
		end

		-- Dientes
		for _, tooth in ipairs(teeth) do
			if tooth.upper then
				tooth.part.CFrame = upperLip.CFrame * CFrame.new(tooth.xOff, -0.03 * S, -0.02 * S)
					* CFrame.Angles(math.rad(180) + tooth.angle, 0, 0)
			else
				tooth.part.CFrame = jaw.CFrame * CFrame.new(tooth.xOff, 0.1 * S, -0.08 * S)
					* CFrame.Angles(tooth.angle, 0, 0)
			end
		end

		-- -----------------------------------------------------------------------
		-- BRAZOS (pueden estirarse hacia el jugador)
		-- -----------------------------------------------------------------------
		for _, arm in ipairs(arms) do
			-- Actualizar estiramiento
			if armReaching and reachTarget then
				arm.targetStretch = 1.5
			else
				arm.targetStretch = 1.0
			end
			arm.currentStretch = Lerp(arm.currentStretch, arm.targetStretch, deltaTime * 3)

			local armPhase = floatTime + arm.side * 0.5
			local armWave = math.sin(armPhase) * 0.3

			-- Hombro
			local shoulderX = arm.side * PHANTOM_CONFIG.TORSO_SIZE.X * 0.55
			local shoulderY = PHANTOM_CONFIG.TORSO_SIZE.Y * 0.3
			arm.shoulder.CFrame = baseCFrame * CFrame.new(shoulderX, shoulderY, 0)

			-- Segmentos del brazo (ondulantes)
			local prevCFrame = arm.shoulder.CFrame
			local segLength = (PHANTOM_CONFIG.ARM_LENGTH / #arm.segments) * arm.currentStretch

			for i, seg in ipairs(arm.segments) do
				local segWave = math.sin(waveTime * 2 + seg.wavePhase + arm.side) * math.rad(15)
				local segPitch = math.rad(-30) + armWave * 0.5 + (i / #arm.segments) * math.rad(-40)
				local segRoll = arm.side * math.rad(20 + i * 5)

				local segCFrame = prevCFrame 
					* CFrame.Angles(segPitch + segWave, 0, segRoll)
					* CFrame.new(0, -segLength * 0.5, 0)

				seg.part.Size = Vector3.new(seg.part.Size.X, segLength, seg.part.Size.Z)
				seg.part.CFrame = segCFrame * CFrame.Angles(0, 0, math.rad(90))
				seg.part.Transparency = flickering and 0.9 or (0.25 + i * 0.05)

				prevCFrame = segCFrame * CFrame.new(0, -segLength * 0.5, 0)
			end

			-- Muñeca
			arm.wrist.CFrame = prevCFrame

			-- Mano
			local handWave = math.sin(armPhase * 1.5) * math.rad(20)
			local handCFrame = prevCFrame * CFrame.Angles(handWave, 0, arm.side * math.rad(10))
				* CFrame.new(0, -PHANTOM_CONFIG.HAND_SIZE.Y * 0.4, 0)
			arm.hand.CFrame = handCFrame

			-- Dedos
			local fingerCurl = math.rad(30) + mouthOpen * math.rad(40)
			for _, finger in ipairs(arm.fingers) do
				local fingerWave = math.sin(waveTime + finger.curlPhase) * math.rad(10)
				local curl = fingerCurl + fingerWave

				local fingerBase = handCFrame * CFrame.new(finger.xOff, -PHANTOM_CONFIG.HAND_SIZE.Y * 0.4, 0)
				local prevFingerCFrame = fingerBase

				for segIdx, seg in ipairs(finger.segments) do
					local segCurl = curl * (0.3 + segIdx * 0.25)
					local segCFrame = prevFingerCFrame 
						* CFrame.Angles(segCurl, 0, 0)
						* CFrame.new(0, -seg.Size.Y * 0.5, 0)
					seg.CFrame = segCFrame
					prevFingerCFrame = segCFrame * CFrame.new(0, -seg.Size.Y * 0.5, 0)
				end

				-- Uña
				finger.nail.CFrame = prevFingerCFrame * CFrame.Angles(math.rad(35), 0, 0)
					* CFrame.new(0, -0.07 * S, 0)
			end
		end

		-- -----------------------------------------------------------------------
		-- COLA ESPECTRAL
		-- -----------------------------------------------------------------------
		local tailBaseY = -PHANTOM_CONFIG.TORSO_SIZE.Y * 0.4
		for i, seg in ipairs(tailSegments) do
			local segOffset = i * 0.3 * S
			local segWave = math.sin(waveTime * 1.5 + seg.wavePhase) * 0.15 * S * seg.progress
			local segSway = math.cos(waveTime + seg.wavePhase) * 0.1 * S * seg.progress

			seg.part.CFrame = baseCFrame 
				* CFrame.new(segWave, tailBaseY - segOffset, segSway)
				* CFrame.Angles(math.rad(seg.progress * 30), segWave, 0)
			seg.part.Transparency = flickering and 1 or (0.3 + seg.progress * 0.6)
		end

		-- Wisps de la cola
		local lastTailSeg = tailSegments[#tailSegments]
		for _, wisp in ipairs(tailWisps) do
			local wispAngle = wisp.angle + waveTime * 0.5
			local wispX = math.cos(wispAngle) * 0.3 * S
			local wispZ = math.sin(wispAngle) * 0.2 * S
			local wispWave = math.sin(waveTime * 2 + wisp.angle) * 0.1 * S

			wisp.part.CFrame = lastTailSeg.part.CFrame 
				* CFrame.new(wispX + wispWave, -wisp.length * 0.5 * S, wispZ)
				* CFrame.Angles(math.rad(20) + wispWave, wispAngle, 0)
			wisp.part.Transparency = flickering and 1 or 0.5
		end

		-- Actualizar luz central
		coreLight.Brightness = 1.5 + math.sin(floatTime * 3) * 0.5
		if flickering then
			coreLight.Brightness = 0.2
		end
	end

	-- Posición inicial
	UpdateNPCPosition(npcX, npcZ, npcRotation, false, 0, 999, nil)

	-- ---------------------------------------------------------------------------
	-- SONIDOS
	-- ---------------------------------------------------------------------------

	-- Sonido de aparición (lamento)
	local spawnSound = Instance.new("Sound")
	spawnSound.SoundId = "rbxassetid://9114221735"
	spawnSound.Volume = 1.2
	spawnSound.PlaybackSpeed = 0.4
	spawnSound.Parent = torso
	spawnSound:Play()

	-- Susurros constantes
	local whisperSound = Instance.new("Sound")
	whisperSound.SoundId = "rbxassetid://9114221580"
	whisperSound.Volume = 0.15
	whisperSound.Looped = true
	whisperSound.PlaybackSpeed = 0.25
	whisperSound.Parent = torso
	whisperSound: Play()

	-- Lamento de fondo
	local wailSound = Instance.new("Sound")
	wailSound.SoundId = "rbxassetid://9114488653"
	wailSound.Volume = 0.1
	wailSound.Looped = true
	wailSound.PlaybackSpeed = 0.3
	wailSound.Parent = head
	wailSound:Play()

	-- Sonido de cadenas/huesos
	local chainSound = Instance.new("Sound")
	chainSound.SoundId = "rbxassetid://5766332557"
	chainSound.Volume = 0.08
	chainSound.Looped = true
	chainSound.PlaybackSpeed = 0.4
	chainSound.Parent = torso
	chainSound:Play()

	-- Grito de ataque
	local screamSound = Instance.new("Sound")
	screamSound.SoundId = "rbxassetid://9114221735"
	screamSound.Volume = 1.5
	screamSound.PlaybackSpeed = 0.6
	screamSound.Parent = head

	-- ---------------------------------------------------------------------------
	-- SISTEMA DE TELETRANSPORTE MEJORADO
	-- ---------------------------------------------------------------------------

	local lastTeleportTime = 0

	local function TeleportToPosition(targetX, targetZ, behindPlayer)
		if IsInLobby(targetX) then return false end
		if isTeleporting then return false end

		isTeleporting = true
		isPhasing = true

		-- Efecto de desvanecimiento
		mistEmitter.Rate = 50
		soulEmitter.Rate = 15

		-- Sonido de teletransporte
		local teleportSound = Instance.new("Sound")
		teleportSound.SoundId = "rbxassetid://80126562543070"
		teleportSound.Volume = 1.0
		teleportSound.PlaybackSpeed = 1.5
		teleportSound.Parent = torso
		teleportSound: Play()

		-- Desvanecer todas las partes
		local allParts = {}
		for _, part in pairs(npcModel:GetDescendants()) do
			if part:IsA("BasePart") then
				table.insert(allParts, {part = part, originalTrans = part.Transparency})
			end
		end

		-- Fade out
		for _, data in ipairs(allParts) do
			TweenService:Create(data.part, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				Transparency = 1
			}):Play()
		end

		-- Ojos brillan intensamente antes de desaparecer
		for _, eyeData in ipairs(eyes) do
			if eyeData.light then
				TweenService:Create(eyeData.light, TweenInfo.new(0.2), {
					Brightness = 8
				}):Play()
			end
		end

		task.wait(0.35)

		-- Mover a nueva posición
		npcX = targetX
		npcZ = targetZ

		-- Efecto de aparición en nueva ubicación
		local appearEffect = Instance.new("Part")
		appearEffect.Name = "AppearEffect"
		appearEffect.Size = Vector3.new(3 * S, 6 * S, 3 * S)
		appearEffect.Color = PHANTOM_CONFIG.MIST_COLOR
		appearEffect.Material = Enum.Material.Neon
		appearEffect.Transparency = 0.5
		appearEffect.Anchored = true
		appearEffect.CanCollide = false
		appearEffect.CastShadow = false
		appearEffect.Position = Vector3.new(targetX, groundY + PHANTOM_CONFIG.FLOAT_HEIGHT, targetZ)
		appearEffect.Parent = workspace

		TweenService:Create(appearEffect, TweenInfo.new(0.5), {
			Size = Vector3.new(8 * S, 10 * S, 8 * S),
			Transparency = 1
		}):Play()

		Debris:AddItem(appearEffect, 0.6)

		-- Sonido de aparición (grito ahogado)
		local appearSound = Instance.new("Sound")
		appearSound.SoundId = "rbxassetid://120923220505708"
		appearSound.Volume = 0.8
		appearSound.PlaybackSpeed = 2.0
		appearSound.Parent = torso
		appearSound:Play()
		Debris:AddItem(appearSound, 3)

		task.wait(0.1)

		-- Fade in
		for _, data in ipairs(allParts) do
			TweenService:Create(data.part, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
				Transparency = data.originalTrans
			}):Play()
		end

		-- Restaurar ojos
		for _, eyeData in ipairs(eyes) do
			if eyeData.light then
				TweenService:Create(eyeData.light, TweenInfo.new(0.3), {
					Brightness = 2
				}):Play()
			end
		end

		task.delay(0.4, function()
			mistEmitter.Rate = 20
			soulEmitter.Rate = 3
			isTeleporting = false
			isPhasing = false
		end)

		Debris:AddItem(teleportSound, 3)
		return true
	end

	-- Función para teletransportarse DETRÁS del jugador
	local function TeleportBehindPlayer(player)
		local char = player.Character
		if not char then return false end

		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then return false end

		-- Calcular posición detrás del jugador
		local playerLook = hrp.CFrame.LookVector
		local behindDistance = 8 * S
		local behindPos = hrp.Position - playerLook * behindDistance

		if IsInLobby(behindPos.X) then
			-- Si la posición está en el lobby, aparecer al lado
			behindPos = hrp.Position + hrp.CFrame.RightVector * behindDistance
		end

		if IsInLobby(behindPos.X) then return false end

		return TeleportToPosition(behindPos.X, behindPos.Z, true)
	end

	-- ---------------------------------------------------------------------------
	-- ANIMACIÓN DE ATAQUE
	-- ---------------------------------------------------------------------------

	local function PlayAttackAnimation(targetPos)
		if isAttacking or isPhasing then return end
		isAttacking = true

		-- Brazos se estiran hacia el objetivo
		armReaching = true
		reachTarget = targetPos

		-- Boca se abre completamente
		targetMouthOpen = 1.5

		-- Ojos brillan rojos
		for _, eyeData in ipairs(eyes) do
			if eyeData.light then
				TweenService:Create(eyeData.light, TweenInfo.new(0.15), {
					Brightness = 10,
					Color = PHANTOM_CONFIG.EYE_GLOW_ANGRY,
					Range = 15 * S
				}):Play()
			end
			TweenService:Create(eyeData.glow, TweenInfo.new(0.15), {
				Color = PHANTOM_CONFIG.EYE_GLOW_ANGRY
			}):Play()
		end

		-- Luz central se vuelve intensa
		TweenService:Create(coreLight, TweenInfo.new(0.15), {
			Brightness = 5,
			Color = PHANTOM_CONFIG.EYE_GLOW_ANGRY
		}):Play()

		-- Grito
		screamSound:Play()

		-- Efecto de onda de frío
		local coldWave = Instance.new("Part")
		coldWave.Name = "ColdWave"
		coldWave.Size = Vector3.new(2 * S, 0.2 * S, 2 * S)
		coldWave.Color = PHANTOM_CONFIG.GLOW_COLD
		coldWave.Material = Enum.Material.Neon
		coldWave.Transparency = 0.3
		coldWave.Anchored = true
		coldWave.CanCollide = false
		coldWave.CastShadow = false
		coldWave.CFrame = CFrame.new(npcX, groundY + 0.5, npcZ)
		coldWave.Parent = workspace

		TweenService:Create(coldWave, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
			Size = Vector3.new(25 * S, 0.2 * S, 25 * S),
			Transparency = 1
		}):Play()

		Debris:AddItem(coldWave, 0.7)

		-- Movimiento hacia el objetivo
		local direction = (targetPos - Vector3.new(npcX, 0, npcZ))
		if direction.Magnitude > 0.5 then
			local lungeDir = direction.Unit
			local startX, startZ = npcX, npcZ
			local lungeDistance = 6 * S
			local endX = npcX + lungeDir.X * lungeDistance
			local endZ = npcZ + lungeDir.Z * lungeDistance

			if not IsInLobby(endX) then
				for i = 1, 10 do
					local t = i / 10
					local easeT = 1 - (1 - t) * (1 - t)
					npcX = startX + (endX - startX) * easeT
					npcZ = startZ + (endZ - startZ) * easeT
					task.wait(0.015)
				end
			end
		end

		task.wait(0.3)

		-- Reset
		armReaching = false
		reachTarget = nil
		targetMouthOpen = 0

		for _, eyeData in ipairs(eyes) do
			if eyeData.light then
				TweenService:Create(eyeData.light, TweenInfo.new(0.4), {
					Brightness = 2,
					Color = PHANTOM_CONFIG.EYE_GLOW,
					Range = 8 * S
				}):Play()
			end
			TweenService:Create(eyeData.glow, TweenInfo.new(0.4), {
				Color = PHANTOM_CONFIG.EYE_GLOW
			}):Play()
		end

		TweenService:Create(coreLight, TweenInfo.new(0.4), {
			Brightness = 1.5,
			Color = PHANTOM_CONFIG.GLOW_COLD
		}):Play()

		isAttacking = false
	end

	-- ---------------------------------------------------------------------------
	-- EFECTO DE MUERTE
	-- ---------------------------------------------------------------------------

	local function PlayDeathEffect()
		mistEmitter.Enabled = false
		bloodDripEmitter.Enabled = false
		soulEmitter.Enabled = false
		whisperSound:Stop()
		wailSound:Stop()
		chainSound:Stop()

		-- Grito final agonizante
		local deathScream = Instance.new("Sound")
		deathScream.SoundId = "rbxassetid://120923220505708"
		deathScream.Volume = 1.0
		deathScream.PlaybackSpeed = 1.0
		deathScream.Parent = torso
		deathScream: Play()

		-- Ojos parpadean erráticamente
		for i = 1, 5 do
			task.delay(i * 0.1, function()
				for _, eyeData in ipairs(eyes) do
					if eyeData.light then
						eyeData.light.Brightness = math.random() * 10
					end
				end
			end)
		end

		-- Ojos se apagan
		task.delay(0.5, function()
			for _, eyeData in ipairs(eyes) do
				if eyeData.light then
					TweenService:Create(eyeData.light, TweenInfo.new(0.5), {
						Brightness = 0
					}):Play()
				end
			end
		end)

		-- Explosión de almas
		local soulBurst = Instance.new("Part")
		soulBurst.Name = "SoulBurst"
		soulBurst.Size = Vector3.new(2 * S, 2 * S, 2 * S)
		soulBurst.Color = PHANTOM_CONFIG.SOUL_WISP
		soulBurst.Material = Enum.Material.Neon
		soulBurst.Transparency = 0.3
		soulBurst.Shape = Enum.PartType.Ball
		soulBurst.Anchored = true
		soulBurst.CanCollide = false
		soulBurst.CastShadow = false
		soulBurst.Position = torso.Position
		soulBurst.Parent = workspace

		local burstLight = Instance.new("PointLight")
		burstLight.Color = PHANTOM_CONFIG.GLOW_INTENSE
		burstLight.Brightness = 10
		burstLight.Range = 40 * S
		burstLight.Shadows = false
		burstLight.Parent = soulBurst

		TweenService:Create(soulBurst, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {
			Size = Vector3.new(20 * S, 20 * S, 20 * S),
			Transparency = 1
		}):Play()

		TweenService:Create(burstLight, TweenInfo.new(0.7), {
			Brightness = 0
		}):Play()

		Debris:AddItem(soulBurst, 0.8)

		-- Todas las partes se disuelven
		task.wait(0.3)

		for _, part in pairs(npcModel:GetDescendants()) do
			if part:IsA("BasePart") then
				-- Flotar hacia arriba mientras se disuelven
				TweenService:Create(part, TweenInfo.new(1.0, Enum.EasingStyle.Quad), {
					Transparency = 1,
					Position = part.Position + Vector3.new(
						(math.random() - 0.5) * 2 * S,
						3 * S,
						(math.random() - 0.5) * 2 * S
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

	local function FindNearestPlayer()
		local nearest, nearestDist = nil, PHANTOM_CONFIG.DETECTION_RANGE
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
		if tick() - lastAttackTime < PHANTOM_CONFIG.ATTACK_COOLDOWN then return end
		if isAttacking or isPhasing then return end
		lastAttackTime = tick()

		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChild("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")

		if hum and hum.Health > 0 and hrp then
			coroutine.wrap(function()
				PlayAttackAnimation(hrp.Position)
			end)()

			task.wait(0.25)

			local dist = (hrp.Position - Vector3.new(npcX, 0, npcZ)).Magnitude
			if dist < PHANTOM_CONFIG.ATTACK_RANGE + 3 and hum.Health > 0 then
				-- Efecto de congelamiento en el jugador
				local freezeEffect = Instance.new("Part")
				freezeEffect.Name = "FreezeEffect"
				freezeEffect.Size = Vector3.new(4, 4, 4)
				freezeEffect.Color = PHANTOM_CONFIG.GLOW_COLD
				freezeEffect.Material = Enum.Material.Ice
				freezeEffect.Transparency = 0.5
				freezeEffect.Shape = Enum.PartType.Ball
				freezeEffect.Anchored = true
				freezeEffect.CanCollide = false
				freezeEffect.CastShadow = false
				freezeEffect.Position = hrp.Position
				freezeEffect.Parent = workspace

				TweenService:Create(freezeEffect, TweenInfo.new(1.5), {
					Transparency = 1,
					Size = Vector3.new(8, 8, 8)
				}):Play()

				Debris:AddItem(freezeEffect, 1.6)

				-- Daño
				hum: TakeDamage(PHANTOM_CONFIG.DAMAGE)

				-- Ralentizar al jugador temporalmente
				local originalSpeed = hum.WalkSpeed
				hum.WalkSpeed = originalSpeed * 0.3

				-- Sonido de impacto
				local hitSound = Instance.new("Sound")
				hitSound.SoundId = "rbxassetid://9114222045"
				hitSound.Volume = 0.8
				hitSound.PlaybackSpeed = 0.7
				hitSound.Parent = hrp
				hitSound:Play()
				Debris:AddItem(hitSound, 2)

				task.delay(2.5, function()
					if hum and hum.Parent then
						hum.WalkSpeed = originalSpeed
					end
				end)
			end
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

		-- Lifetime check
		local elapsedTime = tick() - spawnTime
		if elapsedTime >= npcLifetime then
			print("? Weeping Specter lifetime expired after "..string.format("%.1f", elapsedTime).." seconds")
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

		if isPhasing then
			return
		end

		-- .check
		if IsInLobby(npcX) then
			print("?? Weeping Specter entered .- destroying")
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

		-- Actualizar velocidad basada en distancia
		if distance and distance < 40 then
			currentSpeed = PHANTOM_CONFIG.SPEED_HUNTING
		else
			currentSpeed = PHANTOM_CONFIG.SPEED_NORMAL
		end

		-- Actualizar sonidos basados en distancia
		if distance and distance < 50 then
			whisperSound.Volume = Lerp(0.15, 0.4, (50 - distance) / 50)
			wailSound.Volume = Lerp(0.1, 0.3, (50 - distance) / 50)
		else
			whisperSound.Volume = 0.15
			wailSound.Volume = 0.1
		end

		if target then
			local char = target.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					-- TELETRANSPORTE - Chance de aparecer detrás del jugador
					if distance > 25 and tick() - lastTeleportTime > PHANTOM_CONFIG.TELEPORT_COOLDOWN then
						lastTeleportTime = tick()

						if math.random() < PHANTOM_CONFIG.TELEPORT_BEHIND_CHANCE then
							-- Teletransportarse DETRÁS del jugador
							TeleportBehindPlayer(target)
						else
							-- Teletransportarse a una posición cercana aleatoria
							local randomAngle = math.random() * math.pi * 2
							local teleportDist = 10 + math.random() * 10
							local teleportX = hrp.Position.X + math.cos(randomAngle) * teleportDist
							local teleportZ = hrp.Position.Z + math.sin(randomAngle) * teleportDist

							if not IsInLobby(teleportX) then
								TeleportToPosition(teleportX, teleportZ, false)
							end
						end
					end

					local direction = Vector3.new(hrp.Position.X - npcX, 0, hrp.Position.Z - npcZ)

					if direction.Magnitude > 0.5 then
						local lookAngle = math.atan2(-direction.X, -direction.Z)

						if distance > PHANTOM_CONFIG.ATTACK_RANGE then
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
			-- Sin objetivo - flotar erráticamente
			if math.random() < 0.005 then
				npcRotation = npcRotation + (math.random() - 0.5) * math.rad(90)
			end
			UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, 999, nil)
		end
	end)

	-- ---------------------------------------------------------------------------
	-- COMPORTAMIENTOS AMBIENTALES
	-- ---------------------------------------------------------------------------

	-- Susurros aleatorios más fuertes
	coroutine.wrap(function()
		while isAlive and torso and torso.Parent do
			task.wait(math.random(5, 12))
			if isAlive and torso and torso.Parent and not isAttacking then
				local whisper = Instance.new("Sound")
				whisper.SoundId = "rbxassetid://9114221580"
				whisper.Volume = 0.3
				whisper.PlaybackSpeed = 0.2 + math.random() * 0.2
				whisper.Parent = head
				whisper:Play()
				Debris:AddItem(whisper, 4)
			end
		end
	end)()

	-- Lamentos ocasionales
	coroutine.wrap(function()
		while isAlive and head and head.Parent do
			task.wait(math.random(8, 18))
			if isAlive and not isAttacking and not isPhasing then
				local wail = Instance.new("Sound")
				wail.SoundId = "rbxassetid://9114221735"
				wail.Volume = 0.5
				wail.PlaybackSpeed = 0.35 + math.random() * 0.2
				wail.Parent = head
				wail:Play()

				-- Hacer que los ojos brillen durante el lamento
				for _, eyeData in ipairs(eyes) do
					if eyeData.light then
						local origBrightness = eyeData.light.Brightness
						TweenService:Create(eyeData.light, TweenInfo.new(0.3), {
							Brightness = 6
						}):Play()
						task.delay(1, function()
							if eyeData.light then
								TweenService:Create(eyeData.light, TweenInfo.new(0.5), {
									Brightness = origBrightness
								}):Play()
							end
						end)
					end
				end

				Debris:AddItem(wail, 5)
			end
		end
	end)()

	-- Head snap aleatorio (girar cabeza 180°)
	coroutine.wrap(function()
		while isAlive and head and head.Parent do
			task.wait(math.random(10, 25))
			if isAlive and not isAttacking then
				headSnapped = true
				headSnapAngle = math.pi * (math.random() > 0.5 and 1 or -1) * (0.6 + math.random() * 0.3)

				-- Sonido de cuello crujiendo
				local crackSound = Instance.new("Sound")
				crackSound.SoundId = "rbxassetid://5766332557"
				crackSound.Volume = 0.4
				crackSound.PlaybackSpeed = 0.5
				crackSound.Parent = head
				crackSound:Play()
				Debris:AddItem(crackSound, 2)

				task.wait(1 + math.random() * 2)
				headSnapped = false
				headSnapAngle = 0
			end
		end
	end)()

	-- Efecto de estiramiento de brazos aleatorio
	coroutine.wrap(function()
		while isAlive and torso and torso.Parent do
			task.wait(math.random(6, 15))
			if isAlive and not isAttacking and not isPhasing then
				armReaching = true
				for _, arm in ipairs(arms) do
					arm.targetStretch = 1.3 + math.random() * 0.4
				end
				task.wait(0.8 + math.random() * 1)
				armReaching = false
				for _, arm in ipairs(arms) do
					arm.targetStretch = 1.0
				end
			end
		end
	end)()

	-- Flickering aleatorio (efecto de estática)
	coroutine.wrap(function()
		while isAlive and torso and torso.Parent do
			task.wait(math.random(4, 10))
			if isAlive and not isPhasing then
				-- Flickering rápido
				for i = 1, 3 + math.random(2) do
					coreLight.Brightness = 0.1
					task.wait(0.03 + math.random() * 0.05)
					coreLight.Brightness = 1.5 + math.sin(floatTime * 3) * 0.5
					task.wait(0.02 + math.random() * 0.03)
				end
			end
		end
	end)()

	-- Cleanup cuando se destruye
	npcFolder.AncestryChanged:Connect(function()
		if not npcFolder.Parent then
			isAlive = false
			whisperSound:Stop()
			wailSound:Stop()
			chainSound:Stop()
			if chaseConnection then chaseConnection: Disconnect() end
		end
	end)

	return npcFolder
end

-- -------------------------------------------------------------------------------
-- EVENT LISTENER
-- -------------------------------------------------------------------------------

if SpawnPhantomEvent then
	SpawnPhantomEvent.Event:Connect(function(position, player, side, zDir, doorFrameInfo, lifetime)
		print("?? SpawnWeepingSpecterEvent received - Lifetime: "..tostring(lifetime))
		task.wait(0.3)
		CreatePhantomNPC(position, player, side, zDir, doorFrameInfo, lifetime)
	end)
end

print("=== THE WEEPING SPECTER - PHANTOM HORROR V6 ===")
print("   Scale: "..S.."x GIGANTE")
print("   Speed Normal: "..PHANTOM_CONFIG.SPEED_NORMAL)
print("   Speed Hunting:  "..PHANTOM_CONFIG.SPEED_HUNTING)
print("   Detection Range: "..PHANTOM_CONFIG.DETECTION_RANGE.." studs")
print("   Teleport Cooldown: "..PHANTOM_CONFIG.TELEPORT_COOLDOWN.." seconds")
print("   Teleport Behind Chance: "..(PHANTOM_CONFIG.TELEPORT_BEHIND_CHANCE * 100).."%")
print("")
print("   CARACTERÍSTICAS DE TERROR:")
print("   ? Cara humana destrozada")
print("   ? LLORA SANGRE constantemente")
print("   ? Ojos que BRILLAN cuando te acercas")
print("   ? Boca que revela un VACÍO INFINITO")
print("   ? Cabeza que gira 180° de golpe")
print("   ? Brazos que se ESTIRAN hacia ti")
print("   ? Se TELETRANSPORTA DETRÁS de ti")
print("   ? Efecto de FLICKERING/ESTÁTICA")
print("   ? Susurros y lamentos constantes")
print("   ? Cola espectral que ondula")
print("   ? Pelo mojado que cubre la cara")
print("   ? Mortaja desgarrada flotante")
print("   ? Ataque que CONGELA al jugador")
print("===============================================")