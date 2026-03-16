--[[
    +------------------------------------------------------------------------------+
    ¦                       NPC HARVESTER ENTITY SYSTEM                             ¦
    ¦                    VERSIÓN 5 - ULTIMATE ABILITIES                             ¦
    +------------------------------------------------------------------------------+
    
    NUEVAS HABILIDADES:
    1.DARKNESS VEIL - Oscurece la pantalla de todos los jugadores
    2.SOUL SCREAM - Grito aterrador que ralentiza jugadores cercanos
    3.PHANTOM DASH - Dash rápido hacia el objetivo
    4.DEATH MARK - Marca a un jugador para recibir más daño
    5.REAPER'S HARVEST - Ataque en área devastador
    6.TELEPORT BEHIND - Mejorado con efectos
]]

local Players = game:GetService("Players")
local RunService = game: GetService("RunService")
local TweenService = game: GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local SpawnHarvesterEvent = ReplicatedStorage:WaitForChild("SpawnHarvesterEvent", 10)

-- -------------------------------------------------------------------------------
-- CREAR REMOTE EVENTS PARA EFECTOS EN CLIENTE
-- -------------------------------------------------------------------------------

local HarvesterRemotes = ReplicatedStorage:FindFirstChild("HarvesterRemotes") or Instance.new("Folder")
HarvesterRemotes.Name = "HarvesterRemotes"
HarvesterRemotes.Parent = ReplicatedStorage

local function GetOrCreateRemote(name)
	local existing = HarvesterRemotes:FindFirstChild(name)
	if existing then return existing end
	local new = Instance.new("RemoteEvent")
	new.Name = name
	new.Parent = HarvesterRemotes
	return new
end

local DarknessVeilEvent = GetOrCreateRemote("DarknessVeil")
local SoulScreamEvent = GetOrCreateRemote("SoulScream")
local DeathMarkEvent = GetOrCreateRemote("DeathMark")
local JumpscareEvent = GetOrCreateRemote("Jumpscare")

-- -------------------------------------------------------------------------------
-- CONFIGURACIÓN DEL HARVESTER - COMPLETAMENTE CONFIGURABLE
-- -------------------------------------------------------------------------------

local HARVESTER_CONFIG = {
	-- =========================================================================
	-- STATS BÁSICOS
	-- =========================================================================
	SPEED = 26,
	DAMAGE = 55,
	ATTACK_COOLDOWN = 1.8,
	ATTACK_RANGE = 10,
	DETECTION_RANGE = 320,
	REWARD_SURVIVAL = 150,

	-- =========================================================================
	-- HABILIDAD 1: DARKNESS VEIL (Oscurecer pantalla)
	-- =========================================================================
	DARKNESS_VEIL = {
		ENABLED = true,
		DURATION = 5,                    -- ?? DURACIÓN DE LA OSCURIDAD (segundos)
		COOLDOWN = 25,                   -- Cooldown entre usos
		TRIGGER_HEALTH_PERCENT = 0.7,    -- Se activa cuando HP del jugador < 70%
		TRIGGER_ON_SPAWN = true,         -- Activar al aparecer
		SPAWN_DELAY = 3,                 -- Delay después de spawn
		DARKNESS_INTENSITY = 0.95,       -- 0-1 (1 = completamente negro)
		FOG_DENSITY = 0.8,               -- Densidad de niebla
		AMBIENT_COLOR = Color3.fromRGB(5, 0, 10),
		WHISPER_VOLUME = 0.6,
		HEARTBEAT_SOUND = true,
		RANDOM_TRIGGER_CHANCE = 0.15,    -- 15% chance cada 10 segundos
	},

	-- =========================================================================
	-- HABILIDAD 2: SOUL SCREAM (Grito que ralentiza)
	-- =========================================================================
	SOUL_SCREAM = {
		ENABLED = true,
		RANGE = 100,                      -- Radio del efecto
		SLOW_PERCENT = 0.4,              -- Reduce velocidad al 40%
		SLOW_DURATION = 3,               -- ?? DURACIÓN DEL SLOW (segundos)
		COOLDOWN = 15,
		DAMAGE = 10,                     -- Daño menor por el grito
		SCREEN_SHAKE = true,
		SHAKE_INTENSITY = 15,
	},

	-- =========================================================================
	-- HABILIDAD 3: PHANTOM DASH (Dash rápido)
	-- =========================================================================
	PHANTOM_DASH = {
		ENABLED = true,
		DISTANCE = 25,                   -- Distancia del dash
		SPEED_MULTIPLIER = 8,            -- Velocidad durante dash
		COOLDOWN = 8,
		DAMAGE_ON_CONTACT = 30,          -- Daño si golpea durante dash
		LEAVES_TRAIL = true,
		TRAIL_COLOR = Color3.fromRGB(100, 50, 150),
	},

	-- =========================================================================
	-- HABILIDAD 4: DEATH MARK (Marca de muerte)
	-- =========================================================================
	DEATH_MARK = {
		ENABLED = true,
		DURATION = 8,                    -- ?? DURACIÓN DE LA MARCA (segundos)
		DAMAGE_MULTIPLIER = 1.5,         -- 50% más daño al marcado
		COOLDOWN = 20,
		VISUAL_EFFECT = true,            -- Efecto visual sobre el jugador
		MARK_COLOR = Color3.fromRGB(255, 0, 50),
		PRIORITY_TARGET = true,          -- El Harvester persigue al marcado
	},

	-- =========================================================================
	-- HABILIDAD 5: REAPER'S HARVEST (Ataque en área)
	-- =========================================================================
	REAPERS_HARVEST = {
		ENABLED = true,
		RANGE = 30,                      -- Radio del ataque
		DAMAGE = 40,                     -- Daño base
		CHARGE_TIME = 1.5,               -- Tiempo de carga (warning)
		COOLDOWN = 20,
		KNOCKBACK = 25,                  -- Fuerza de empuje
		SLOW_AFTER = 0.5,                -- Slow después del golpe
		SLOW_DURATION = 2,
		WARNING_COLOR = Color3.fromRGB(255, 50, 50),
	},

	-- =========================================================================
	-- HABILIDAD 6: TELEPORT BEHIND (Mejorado)
	-- =========================================================================
	TELEPORT_BEHIND = {
		ENABLED = true,
		CHANCE = 0.35,                   -- 25% chance por ataque
		COOLDOWN = 6,
		DISTANCE_BEHIND = 5,             -- Distancia detrás del jugador
		ATTACK_DELAY = 0.3,              -- Delay antes de atacar
		WHISPER_BEFORE = true,           -- Susurro antes de teleport
	},

	-- =========================================================================
	-- HABILIDAD 7: JUMPSCARE (Al matar)
	-- =========================================================================
	JUMPSCARE = {
		ENABLED = true,
		DURATION = 1.5,                  -- ?? DURACIÓN DEL JUMPSCARE
		ON_KILL = true,                  -- Activar al matar
		ON_LOW_HEALTH = true,            -- Activar cuando jugador tiene poca vida
		LOW_HEALTH_THRESHOLD = 0.2,      -- 20% HP
		CHANCE_ON_ATTACK = 0.1,          -- 10% en cada ataque
	},

	-- =========================================================================
	-- STUN SYSTEM (Cuando recibe daño)
	-- =========================================================================
	STUN_TIMES = {
		BODY_CHARGE_1 = 0.2,
		BODY_CHARGE_2 = 0.5,
		BODY_CHARGE_3 = 1.0,
		HEAD_CHARGE_1 = 1.5,
		HEAD_CHARGE_2 = 2.5,
		HEAD_CHARGE_3 = 4.0,
	},

	-- =========================================================================
	-- APARIENCIA
	-- =========================================================================
	CLOAK_COLOR = Color3.fromRGB(12, 8, 18),
	CLOAK_SECONDARY = Color3.fromRGB(20, 15, 28),
	CLOAK_INNER = Color3.fromRGB(5, 3, 8),
	BONE_COLOR = Color3.fromRGB(215, 205, 195),
	BONE_SHADOW = Color3.fromRGB(160, 150, 140),
	EYE_COLOR = Color3.fromRGB(255, 50, 50),
	EYE_INNER = Color3.fromRGB(255, 150, 100),
	SCYTHE_HANDLE = Color3.fromRGB(55, 40, 30),
	SCYTHE_BLADE = Color3.fromRGB(45, 45, 50),
	SCYTHE_EDGE = Color3.fromRGB(220, 60, 90),
	SOUL_COLOR = Color3.fromRGB(130, 180, 255),
	VOID_COLOR = Color3.fromRGB(2, 1, 3),

	-- Colores de habilidades
	ABILITY_GLOW = Color3.fromRGB(150, 50, 200),
	RAGE_COLOR = Color3.fromRGB(255, 30, 30),

	-- =========================================================================
	-- DIMENSIONES
	-- =========================================================================
	TOTAL_HEIGHT = 8,
	CLOAK_WIDTH = 3.2,
	SCYTHE_LENGTH = 6.5,

	-- =========================================================================
	-- ANIMACIÓN
	-- =========================================================================
	HOVER_SPEED = 0.9,
	HOVER_AMPLITUDE = 0.2,
	BREATH_SPEED = 1.2,

	-- =========================================================================
	-- .BOUNDS
	-- =========================================================================
	LOBBY_START_X = -75,
	LOBBY_END_X = 75,
}

-- -------------------------------------------------------------------------------
-- FUNCIÓN PARA VERIFICAR SI ESTÁ EN LOBBY
-- -------------------------------------------------------------------------------

local function IsInLobby(x)
	return x >= HARVESTER_CONFIG.LOBBY_START_X and x <= HARVESTER_CONFIG.LOBBY_END_X
end

-- -------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
-- -------------------------------------------------------------------------------

local function CreateMesh(parent, meshType, scale)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = meshType or Enum.MeshType.Brick
	if scale then
		mesh.Scale = scale
	end
	mesh.Parent = parent
	return mesh
end

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

-- -------------------------------------------------------------------------------
-- SISTEMA DE HABILIDADES
-- -------------------------------------------------------------------------------

local AbilitySystem = {}

-- HABILIDAD 1: DARKNESS VEIL
function AbilitySystem.DarknessVeil(config, npcPosition)
	if not config.ENABLED then return end

	local darknessData = {
		duration = config.DURATION,
		intensity = config.DARKNESS_INTENSITY,
		fogDensity = config.FOG_DENSITY,
		ambientColor = config.AMBIENT_COLOR,
		whisperVolume = config.WHISPER_VOLUME,
		heartbeat = config.HEARTBEAT_SOUND,
	}

	-- Enviar a todos los jugadores fuera del lobby
	for _, player in pairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp and not IsInLobby(hrp.Position.X) then
				DarknessVeilEvent:FireClient(player, darknessData)
			end
		end
	end

	print("?? HARVESTER: Darkness Veil activated for "..config.DURATION.." seconds!")
end

-- HABILIDAD 2: SOUL SCREAM
function AbilitySystem.SoulScream(config, npcX, npcZ)
	if not config.ENABLED then return end

	local affectedPlayers = {}
	local npcPos = Vector3.new(npcX, 0, npcZ)

	for _, player in pairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChild("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local dist = (hrp.Position - npcPos).Magnitude
				if dist <= config.RANGE and not IsInLobby(hrp.Position.X) then
					table.insert(affectedPlayers, {
						player = player,
						humanoid = hum,
						originalSpeed = hum.WalkSpeed
					})
				end
			end
		end
	end

	-- Aplicar efectos
	for _, data in ipairs(affectedPlayers) do
		-- Daño menor
		data.humanoid:TakeDamage(config.DAMAGE)

		-- Ralentizar
		data.humanoid.WalkSpeed = data.originalSpeed * config.SLOW_PERCENT

		-- Enviar efecto visual
		SoulScreamEvent:FireClient(data.player, {
			shake = config.SCREEN_SHAKE,
			shakeIntensity = config.SHAKE_INTENSITY,
			duration = config.SLOW_DURATION,
		})

		-- Restaurar velocidad después
		task.delay(config.SLOW_DURATION, function()
			if data.humanoid and data.humanoid.Parent then
				data.humanoid.WalkSpeed = data.originalSpeed
			end
		end)
	end

	print("?? HARVESTER: Soul Scream hit "..#affectedPlayers.." players!")
	return #affectedPlayers
end

-- HABILIDAD 4: DEATH MARK
function AbilitySystem.ApplyDeathMark(config, targetPlayer, markedPlayers)
	if not config.ENABLED then return false end

	local playerId = targetPlayer.UserId

	-- Ya está marcado
	if markedPlayers[playerId] then return false end

	markedPlayers[playerId] = {
		player = targetPlayer,
		expireTime = tick() + config.DURATION,
		damageMultiplier = config.DAMAGE_MULTIPLIER,
	}

	-- Enviar efecto visual
	DeathMarkEvent:FireClient(targetPlayer, {
		duration = config.DURATION,
		color = config.MARK_COLOR,
	})

	-- Remover marca después de duración
	task.delay(config.DURATION, function()
		markedPlayers[playerId] = nil
	end)

	print("?? HARVESTER: Death Mark applied to "..targetPlayer.Name.."!")
	return true
end

-- HABILIDAD 5: REAPER'S HARVEST (Ataque en área)
function AbilitySystem.ReapersHarvest(config, npcX, npcZ, warningCallback, damageCallback)
	if not config.ENABLED then return end

	local npcPos = Vector3.new(npcX, 0, npcZ)

	-- Fase de warning
	if warningCallback then
		warningCallback(npcPos, config.RANGE, config.WARNING_COLOR)
	end

	task.wait(config.CHARGE_TIME)

	-- Fase de daño
	local hitPlayers = {}
	for _, player in pairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local hrp = char: FindFirstChild("HumanoidRootPart")
			local hum = char: FindFirstChild("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local dist = (hrp.Position - npcPos).Magnitude
				if dist <= config.RANGE and not IsInLobby(hrp.Position.X) then
					-- Daño
					hum: TakeDamage(config.DAMAGE)

					-- Knockback
					local knockDir = (hrp.Position - npcPos).Unit
					local bodyVel = Instance.new("BodyVelocity")
					bodyVel.Velocity = knockDir * config.KNOCKBACK + Vector3.new(0, 15, 0)
					bodyVel.MaxForce = Vector3.new(50000, 50000, 50000)
					bodyVel.Parent = hrp
					Debris:AddItem(bodyVel, 0.3)

					-- Slow después del golpe
					local origSpeed = hum.WalkSpeed
					hum.WalkSpeed = origSpeed * config.SLOW_AFTER
					task.delay(config.SLOW_DURATION, function()
						if hum and hum.Parent then
							hum.WalkSpeed = origSpeed
						end
					end)

					table.insert(hitPlayers, player)
				end
			end
		end
	end

	if damageCallback then
		damageCallback(hitPlayers)
	end

	print("?? HARVESTER: Reaper's Harvest hit "..#hitPlayers.." players!")
	return hitPlayers
end

-- HABILIDAD 7: JUMPSCARE
function AbilitySystem.TriggerJumpscare(config, targetPlayer)
	if not config.ENABLED then return end

	JumpscareEvent:FireClient(targetPlayer, {
		duration = config.DURATION,
	})

	print("?? HARVESTER: Jumpscare triggered on "..targetPlayer.Name.."!")
end

-- -------------------------------------------------------------------------------
-- CREATE HARVESTER NPC
-- -------------------------------------------------------------------------------

local function CreateHarvesterNPC(spawnPosition, triggerPlayer, side, zDir, doorFrameInfo, lifetime)
	-- =========================================================================
	-- LIFETIME SYSTEM
	-- =========================================================================
	local npcLifetime = lifetime
	if not npcLifetime or npcLifetime <= 0 then
		npcLifetime = 65
		warn("?? Harvester:  No lifetime received, using default:  65 seconds")
	end

	print("===========================================")
	print("?? HARVESTER SPAWNED - ULTIMATE VERSION")
	print("   Lifetime: "..npcLifetime.." seconds")
	print("   Position: "..tostring(spawnPosition))
	print("   Abilities Enabled:")
	print("     - Darkness Veil:  "..tostring(HARVESTER_CONFIG.DARKNESS_VEIL.ENABLED))
	print("     - Soul Scream: "..tostring(HARVESTER_CONFIG.SOUL_SCREAM.ENABLED))
	print("     - Phantom Dash: "..tostring(HARVESTER_CONFIG.PHANTOM_DASH.ENABLED))
	print("     - Death Mark:  "..tostring(HARVESTER_CONFIG.DEATH_MARK.ENABLED))
	print("     - Reaper's Harvest: "..tostring(HARVESTER_CONFIG.REAPERS_HARVEST.ENABLED))
	print("===========================================")

	local npcFolder = Instance.new("Folder")
	npcFolder.Name = "HarvesterEntity"
	npcFolder.Parent = workspace

	local npcModel = Instance.new("Model")
	npcModel.Name = "HarvesterNPC"
	npcModel.Parent = npcFolder

	local spawnTime = tick()
	npcFolder: SetAttribute("SpawnTime", spawnTime)
	npcFolder:SetAttribute("Lifetime", npcLifetime)
	npcModel:SetAttribute("SpawnTime", spawnTime)
	npcModel:SetAttribute("Lifetime", npcLifetime)

	local groundY = 0.5
	local hoverHeight = 1.0
	local HEIGHT = HARVESTER_CONFIG.TOTAL_HEIGHT

	-- =========================================================================
	-- ABILITY COOLDOWNS & STATE
	-- =========================================================================
	local abilityCooldowns = {
		darknessVeil = 0,
		soulScream = 0,
		phantomDash = 0,
		deathMark = 0,
		reapersHarvest = 0,
		teleportBehind = 0,
	}

	local abilityState = {
		isDashing = false,
		isChargingHarvest = false,
		markedPlayers = {},
		currentTarget = nil,
		priorityTarget = nil,  -- Jugador marcado con Death Mark
	}

	-- ---------------------------------------------------------------------------
	-- CREAR TODAS LAS PARTES DEL MODELO (mismo código que antes)
	-- ---------------------------------------------------------------------------

	-- CLOAK LOWER SECTION
	local cloakLower = CreatePart(
		"CloakLower",
		Vector3.new(HARVESTER_CONFIG.CLOAK_WIDTH * 1.3, HEIGHT * 0.35, 2.4),
		HARVESTER_CONFIG.CLOAK_COLOR,
		Enum.Material.Fabric,
		0,
		npcModel
	)
	cloakLower.CanCollide = true
	CreateMesh(cloakLower, Enum.MeshType.Brick, Vector3.new(1, 1, 0.8))

	-- CLOAK MIDDLE SECTION
	local cloakMiddle = CreatePart(
		"CloakMiddle",
		Vector3.new(HARVESTER_CONFIG.CLOAK_WIDTH, HEIGHT * 0.3, 1.8),
		HARVESTER_CONFIG.CLOAK_SECONDARY,
		Enum.Material.Fabric,
		0,
		npcModel
	)

	-- SHOULDERS
	local shoulderLeft = CreatePart(
		"ShoulderLeft",
		Vector3.new(0.9, 0.7, 1.2),
		HARVESTER_CONFIG.CLOAK_COLOR,
		Enum.Material.Fabric,
		0,
		npcModel
	)
	CreateMesh(shoulderLeft, Enum.MeshType.Sphere, Vector3.new(1, 0.8, 1))

	local shoulderRight = CreatePart(
		"ShoulderRight",
		Vector3.new(0.9, 0.7, 1.2),
		HARVESTER_CONFIG.CLOAK_COLOR,
		Enum.Material.Fabric,
		0,
		npcModel
	)
	CreateMesh(shoulderRight, Enum.MeshType.Sphere, Vector3.new(1, 0.8, 1))

	-- HOOD
	local hoodBack = CreatePart(
		"HoodBack",
		Vector3.new(2.2, 2.4, 2.0),
		HARVESTER_CONFIG.CLOAK_COLOR,
		Enum.Material.Fabric,
		0,
		npcModel
	)
	CreateMesh(hoodBack, Enum.MeshType.Sphere, Vector3.new(1, 1, 0.9))

	local hoodTop = CreatePart(
		"HoodTop",
		Vector3.new(1.8, 0.8, 1.6),
		HARVESTER_CONFIG.CLOAK_COLOR,
		Enum.Material.Fabric,
		0,
		npcModel
	)
	CreateMesh(hoodTop, Enum.MeshType.Sphere, Vector3.new(1, 1, 1))

	local hoodRimLeft = CreatePart(
		"HoodRimLeft",
		Vector3.new(0.25, 1.8, 0.8),
		HARVESTER_CONFIG.CLOAK_SECONDARY,
		Enum.Material.Fabric,
		0,
		npcModel
	)

	local hoodRimRight = CreatePart(
		"HoodRimRight",
		Vector3.new(0.25, 1.8, 0.8),
		HARVESTER_CONFIG.CLOAK_SECONDARY,
		Enum.Material.Fabric,
		0,
		npcModel
	)

	local hoodRimTop = CreatePart(
		"HoodRimTop",
		Vector3.new(1.5, 0.25, 0.6),
		HARVESTER_CONFIG.CLOAK_SECONDARY,
		Enum.Material.Fabric,
		0,
		npcModel
	)

	-- VOID INTERIOR
	local voidInterior = CreatePart(
		"VoidInterior",
		Vector3.new(1.5, 1.7, 1.0),
		HARVESTER_CONFIG.VOID_COLOR,
		Enum.Material.SmoothPlastic,
		0,
		npcModel
	)
	CreateMesh(voidInterior, Enum.MeshType.Sphere, Vector3.new(1, 1, 0.5))

	-- SKULL
	local skull = CreatePart(
		"Skull",
		Vector3.new(1.0, 1.2, 0.9),
		HARVESTER_CONFIG.BONE_COLOR,
		Enum.Material.SmoothPlastic,
		0.35,
		npcModel
	)
	CreateMesh(skull, Enum.MeshType.Head, Vector3.new(1.1, 1.15, 1.1))

	local cheekLeft = CreatePart(
		"CheekLeft",
		Vector3.new(0.35, 0.25, 0.3),
		HARVESTER_CONFIG.BONE_SHADOW,
		Enum.Material.SmoothPlastic,
		0.4,
		npcModel
	)
	CreateMesh(cheekLeft, Enum.MeshType.Sphere)

	local cheekRight = CreatePart(
		"CheekRight",
		Vector3.new(0.35, 0.25, 0.3),
		HARVESTER_CONFIG.BONE_SHADOW,
		Enum.Material.SmoothPlastic,
		0.4,
		npcModel
	)
	CreateMesh(cheekRight, Enum.MeshType.Sphere)

	local jaw = CreatePart(
		"Jaw",
		Vector3.new(0.6, 0.3, 0.5),
		HARVESTER_CONFIG.BONE_COLOR,
		Enum.Material.SmoothPlastic,
		0.4,
		npcModel
	)
	CreateMesh(jaw, Enum.MeshType.Head, Vector3.new(1, 0.8, 1))

	-- EYES
	local eyes = {}
	for i = 1, 2 do
		local eyeSocket = CreatePart(
			"EyeSocket"..i,
			Vector3.new(0.28, 0.32, 0.15),
			HARVESTER_CONFIG.VOID_COLOR,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		CreateMesh(eyeSocket, Enum.MeshType.Sphere)

		local eyeGlow = CreatePart(
			"EyeGlow"..i,
			Vector3.new(0.18, 0.24, 0.08),
			HARVESTER_CONFIG.EYE_COLOR,
			Enum.Material.Neon,
			0,
			npcModel
		)
		CreateMesh(eyeGlow, Enum.MeshType.Sphere)

		local eyePupil = CreatePart(
			"EyePupil"..i,
			Vector3.new(0.08, 0.12, 0.04),
			HARVESTER_CONFIG.EYE_INNER,
			Enum.Material.Neon,
			0,
			npcModel
		)
		CreateMesh(eyePupil, Enum.MeshType.Sphere)

		local eyeLight = Instance.new("PointLight")
		eyeLight.Brightness = 3
		eyeLight.Color = HARVESTER_CONFIG.EYE_COLOR
		eyeLight.Range = 6
		eyeLight.Shadows = true
		eyeLight.Parent = eyeGlow

		table.insert(eyes, {
			socket = eyeSocket,
			glow = eyeGlow,
			pupil = eyePupil,
			light = eyeLight,
			side = i == 1 and -1 or 1
		})
	end

	-- ARMS
	local arms = {}
	for i = 1, 2 do
		local armSide = i == 1 and -1 or 1

		local upperArm = CreatePart(
			"UpperArm"..i,
			Vector3.new(0.45, 1.2, 0.45),
			HARVESTER_CONFIG.CLOAK_COLOR,
			Enum.Material.Fabric,
			0,
			npcModel
		)

		local lowerArm = CreatePart(
			"LowerArm"..i,
			Vector3.new(0.35, 1.0, 0.35),
			HARVESTER_CONFIG.CLOAK_SECONDARY,
			Enum.Material.Fabric,
			0,
			npcModel
		)

		local hand = CreatePart(
			"Hand"..i,
			Vector3.new(0.4, 0.55, 0.22),
			HARVESTER_CONFIG.BONE_COLOR,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)

		local fingers = {}
		for f = 1, 4 do
			local finger = CreatePart(
				"Finger"..i.."_"..f,
				Vector3.new(0.06, 0.25, 0.06),
				HARVESTER_CONFIG.BONE_COLOR,
				Enum.Material.SmoothPlastic,
				0,
				npcModel
			)
			CreateMesh(finger, Enum.MeshType.Cylinder)
			table.insert(fingers, finger)
		end

		local thumb = CreatePart(
			"Thumb"..i,
			Vector3.new(0.07, 0.18, 0.07),
			HARVESTER_CONFIG.BONE_COLOR,
			Enum.Material.SmoothPlastic,
			0,
			npcModel
		)
		CreateMesh(thumb, Enum.MeshType.Cylinder)

		table.insert(arms, {
			upper = upperArm,
			lower = lowerArm,
			hand = hand,
			fingers = fingers,
			thumb = thumb,
			side = armSide
		})
	end

	-- CLOAK TATTERS
	local cloakTatters = {}
	local tatterCount = 8
	for i = 1, tatterCount do
		local tatterHeight = 0.8 + math.random() * 0.6
		local tatterWidth = 0.3 + math.random() * 0.2
		local tatter = CreatePart(
			"Tatter"..i,
			Vector3.new(tatterWidth, tatterHeight, 0.15),
			HARVESTER_CONFIG.CLOAK_COLOR,
			Enum.Material.Fabric,
			0,
			npcModel
		)

		table.insert(cloakTatters, {
			part = tatter,
			angle = (i / tatterCount) * math.pi * 2,
			height = tatterHeight,
			offset = (i % 2 == 0) and 0.1 or -0.1
		})
	end

	-- SCYTHE
	local scytheFolder = Instance.new("Folder")
	scytheFolder.Name = "Scythe"
	scytheFolder.Parent = npcModel

	local scytheHandle = CreatePart(
		"Handle",
		Vector3.new(0.18, HARVESTER_CONFIG.SCYTHE_LENGTH, 0.18),
		HARVESTER_CONFIG.SCYTHE_HANDLE,
		Enum.Material.Wood,
		0,
		scytheFolder
	)
	CreateMesh(scytheHandle, Enum.MeshType.Cylinder)

	local handleWrap1 = CreatePart(
		"HandleWrap1",
		Vector3.new(0.22, 0.15, 0.22),
		HARVESTER_CONFIG.CLOAK_COLOR,
		Enum.Material.Fabric,
		0,
		scytheFolder
	)

	local handleWrap2 = CreatePart(
		"HandleWrap2",
		Vector3.new(0.22, 0.15, 0.22),
		HARVESTER_CONFIG.CLOAK_COLOR,
		Enum.Material.Fabric,
		0,
		scytheFolder
	)

	local handleCap = CreatePart(
		"HandleCap",
		Vector3.new(0.25, 0.3, 0.25),
		HARVESTER_CONFIG.SCYTHE_BLADE,
		Enum.Material.Metal,
		0,
		scytheFolder
	)
	CreateMesh(handleCap, Enum.MeshType.Sphere)

	local bladeCollar = CreatePart(
		"BladeCollar",
		Vector3.new(0.4, 0.5, 0.4),
		HARVESTER_CONFIG.SCYTHE_BLADE,
		Enum.Material.Metal,
		0,
		scytheFolder
	)
	CreateMesh(bladeCollar, Enum.MeshType.Cylinder)

	local bladeSpine = CreatePart(
		"BladeSpine",
		Vector3.new(3.2, 0.15, 0.25),
		HARVESTER_CONFIG.SCYTHE_BLADE,
		Enum.Material.Metal,
		0,
		scytheFolder
	)

	local blade = CreatePart(
		"Blade",
		Vector3.new(3.0, 0.06, 0.85),
		HARVESTER_CONFIG.SCYTHE_BLADE,
		Enum.Material.Metal,
		0,
		scytheFolder
	)

	local bladeEdge = CreatePart(
		"BladeEdge",
		Vector3.new(3.0, 0.025, 0.06),
		HARVESTER_CONFIG.SCYTHE_EDGE,
		Enum.Material.Neon,
		0,
		scytheFolder
	)

	local bladeLight = Instance.new("PointLight")
	bladeLight.Brightness = 2
	bladeLight.Color = HARVESTER_CONFIG.SCYTHE_EDGE
	bladeLight.Range = 10
	bladeLight.Shadows = true
	bladeLight.Parent = bladeEdge

	local bladeTip = CreatePart(
		"BladeTip",
		Vector3.new(0.5, 0.05, 0.4),
		HARVESTER_CONFIG.SCYTHE_BLADE,
		Enum.Material.Metal,
		0,
		scytheFolder
	)

	-- ---------------------------------------------------------------------------
	-- ABILITY VISUAL:  AURA FOR ABILITIES
	-- ---------------------------------------------------------------------------

	local abilityAura = CreatePart(
		"AbilityAura",
		Vector3.new(5, 8, 5),
		HARVESTER_CONFIG.ABILITY_GLOW,
		Enum.Material.ForceField,
		0.9,
		npcModel
	)
	abilityAura.Shape = Enum.PartType.Ball

	-- ---------------------------------------------------------------------------
	-- PARTICLE EFFECTS
	-- ---------------------------------------------------------------------------

	local auraEmitter = Instance.new("ParticleEmitter")
	auraEmitter.Texture = "rbxassetid://243098098"
	auraEmitter.Color = ColorSequence.new(HARVESTER_CONFIG.CLOAK_INNER)
	auraEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 2.5),
		NumberSequenceKeypoint.new(1, 4)
	})
	auraEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(1, 1)
	})
	auraEmitter.Lifetime = NumberRange.new(0.8, 1.5)
	auraEmitter.Rate = 12
	auraEmitter.Speed = NumberRange.new(0.5, 1.5)
	auraEmitter.SpreadAngle = Vector2.new(360, 360)
	auraEmitter.RotSpeed = NumberRange.new(-30, 30)
	auraEmitter.Parent = cloakLower

	local soulEmitter = Instance.new("ParticleEmitter")
	soulEmitter.Texture = "rbxassetid://243098098"
	soulEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, HARVESTER_CONFIG.SOUL_COLOR),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 220, 255))
	})
	soulEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.3, 0.4),
		NumberSequenceKeypoint.new(1, 0)
	})
	soulEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.7, 0.7),
		NumberSequenceKeypoint.new(1, 1)
	})
	soulEmitter.Lifetime = NumberRange.new(1.5, 3)
	soulEmitter.Rate = 3
	soulEmitter.Speed = NumberRange.new(1, 3)
	soulEmitter.SpreadAngle = Vector2.new(180, 180)
	soulEmitter.Acceleration = Vector3.new(0, 1, 0)
	soulEmitter.Parent = voidInterior

	local bladeTrail = Instance.new("ParticleEmitter")
	bladeTrail.Texture = "rbxassetid://243098098"
	bladeTrail.Color = ColorSequence.new(HARVESTER_CONFIG.SCYTHE_EDGE)
	bladeTrail.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 0)
	})
	bladeTrail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	bladeTrail.Lifetime = NumberRange.new(0.3, 0.6)
	bladeTrail.Rate = 8
	bladeTrail.Speed = NumberRange.new(0, 0.5)
	bladeTrail.Parent = bladeEdge

	-- Ability particles (for when abilities are used)
	local abilityEmitter = Instance.new("ParticleEmitter")
	abilityEmitter.Texture = "rbxassetid://243098098"
	abilityEmitter.Color = ColorSequence.new(HARVESTER_CONFIG.ABILITY_GLOW)
	abilityEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 3),
		NumberSequenceKeypoint.new(1, 0)
	})
	abilityEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	abilityEmitter.Lifetime = NumberRange.new(0.5, 1)
	abilityEmitter.Rate = 0  -- Disabled by default
	abilityEmitter.Speed = NumberRange.new(5, 10)
	abilityEmitter.SpreadAngle = Vector2.new(360, 360)
	abilityEmitter.Parent = cloakMiddle

	-- ---------------------------------------------------------------------------
	-- ANIMATION STATE
	-- ---------------------------------------------------------------------------

	local npcX = spawnPosition.X
	local npcZ = spawnPosition.Z
	local npcRotation = zDir > 0 and 0 or math.pi
	local hoverTime = 0
	local breathTime = 0
	local scytheSwingAngle = 0
	local isAttacking = false

	-- ---------------------------------------------------------------------------
	-- UPDATE POSITION FUNCTION
	-- ---------------------------------------------------------------------------

	local function UpdateNPCPosition(x, z, rotY, deltaTime)
		npcX = x
		npcZ = z
		npcRotation = rotY or npcRotation

		if deltaTime then
			hoverTime = hoverTime + deltaTime * HARVESTER_CONFIG.HOVER_SPEED
			breathTime = breathTime + deltaTime * HARVESTER_CONFIG.BREATH_SPEED
		end

		local hoverY = groundY + hoverHeight + math.sin(hoverTime * math.pi) * HARVESTER_CONFIG.HOVER_AMPLITUDE
		local swayX = math.sin(hoverTime * 0.7) * 0.08
		local swayZ = math.cos(hoverTime * 0.5) * 0.06

		local basePos = Vector3.new(x + swayX, hoverY, z + swayZ)
		local baseCFrame = CFrame.new(basePos) * CFrame.Angles(0, npcRotation, 0)

		local cloakLowerY = HEIGHT * 0.18
		local cloakMiddleY = HEIGHT * 0.45
		local shoulderY = HEIGHT * 0.58
		local hoodY = HEIGHT * 0.72
		local skullY = HEIGHT * 0.68

		cloakLower.CFrame = baseCFrame * CFrame.new(0, cloakLowerY, 0)
		cloakMiddle.CFrame = baseCFrame * CFrame.new(0, cloakMiddleY, 0)

		local shoulderOffset = 1.4
		shoulderLeft.CFrame = baseCFrame * CFrame.new(-shoulderOffset, shoulderY, -0.1)
		shoulderRight.CFrame = baseCFrame * CFrame.new(shoulderOffset, shoulderY, -0.1)

		local headBob = math.sin(hoverTime * 1.2) * 0.03
		local hoodTilt = math.sin(hoverTime * 0.8) * 0.02

		hoodBack.CFrame = baseCFrame * CFrame.new(0, hoodY + headBob, 0.15) 
			* CFrame.Angles(math.rad(-5) + hoodTilt, 0, 0)

		hoodTop.CFrame = baseCFrame * CFrame.new(0, hoodY + 1.0 + headBob, -0.1)
			* CFrame.Angles(math.rad(-15), 0, 0)

		local rimForward = -1.0
		hoodRimLeft.CFrame = baseCFrame * CFrame.new(-0.85, hoodY + headBob - 0.1, rimForward)
		hoodRimRight.CFrame = baseCFrame * CFrame.new(0.85, hoodY + headBob - 0.1, rimForward)
		hoodRimTop.CFrame = baseCFrame * CFrame.new(0, hoodY + 0.75 + headBob, rimForward - 0.1)

		voidInterior.CFrame = baseCFrame * CFrame.new(0, skullY + headBob, -0.6)
		skull.CFrame = baseCFrame * CFrame.new(0, skullY + headBob - 0.05, -0.4) * CFrame.Angles(math.rad(-3), 0, 0)

		cheekLeft.CFrame = skull.CFrame * CFrame.new(-0.35, -0.15, -0.35)
		cheekRight.CFrame = skull.CFrame * CFrame.new(0.35, -0.15, -0.35)
		jaw.CFrame = skull.CFrame * CFrame.new(0, -0.45, -0.15) * CFrame.Angles(math.rad(5), 0, 0)

		for _, eyeData in ipairs(eyes) do
			local eyeX = eyeData.side * 0.22
			local eyeY = 0.18
			local eyeZ = -0.48
			local eyeLookX = math.sin(hoverTime * 0.3) * 0.02
			local eyeLookY = math.cos(hoverTime * 0.4) * 0.01

			eyeData.socket.CFrame = skull.CFrame * CFrame.new(eyeX, eyeY, eyeZ)
			eyeData.glow.CFrame = skull.CFrame * CFrame.new(eyeX + eyeLookX, eyeY + eyeLookY, eyeZ - 0.05)
			eyeData.pupil.CFrame = skull.CFrame * CFrame.new(eyeX + eyeLookX, eyeY + eyeLookY, eyeZ - 0.08)

			if eyeData.light then
				local flicker = 2.5 + math.sin(hoverTime * 8 + eyeData.side) * 0.5
				if math.random() < 0.02 then
					flicker = flicker + math.random() * 2
				end
				eyeData.light.Brightness = flicker
			end
		end

		for _, armData in ipairs(arms) do
			local armSwing = math.sin(hoverTime + armData.side * 0.5) * 0.1
			local isRightArm = armData.side == 1

			local upperArmAngle, lowerArmAngle, handAngle

			if isRightArm then
				upperArmAngle = math.rad(-40) + scytheSwingAngle * 0.3
				lowerArmAngle = math.rad(-30) + scytheSwingAngle * 0.5
				handAngle = math.rad(-20) + scytheSwingAngle * 0.2
			else
				upperArmAngle = math.rad(15) + armSwing
				lowerArmAngle = math.rad(10) + armSwing * 0.5
				handAngle = math.rad(5)
			end

			local shoulderPos = armData.side == -1 and shoulderLeft.Position or shoulderRight.Position

			local upperArmCFrame = CFrame.new(shoulderPos) 
				* CFrame.Angles(0, npcRotation, 0)
				* CFrame.new(armData.side * 0.3, -0.3, 0)
				* CFrame.Angles(upperArmAngle, armData.side * math.rad(10), armData.side * math.rad(15))

			armData.upper.CFrame = upperArmCFrame * CFrame.new(0, -0.6, 0)

			local lowerArmCFrame = upperArmCFrame 
				* CFrame.new(0, -1.1, 0)
				* CFrame.Angles(lowerArmAngle, 0, 0)

			armData.lower.CFrame = lowerArmCFrame * CFrame.new(0, -0.5, 0)

			local handCFrame = lowerArmCFrame 
				* CFrame.new(0, -1.0, 0)
				* CFrame.Angles(handAngle, 0, 0)

			armData.hand.CFrame = handCFrame

			for f, finger in ipairs(armData.fingers) do
				local fingerOffset = (f - 2.5) * 0.09
				local fingerCurl = math.rad(30) + math.sin(hoverTime + f) * math.rad(5)
				finger.CFrame = handCFrame 
					* CFrame.new(fingerOffset, -0.35, 0)
					* CFrame.Angles(fingerCurl, 0, 0)
			end

			armData.thumb.CFrame = handCFrame 
				* CFrame.new(armData.side * 0.18, -0.15, -0.08)
				* CFrame.Angles(math.rad(20), armData.side * math.rad(30), 0)
		end

		local tatterBaseY = cloakLowerY - HEIGHT * 0.15
		for _, tatterData in ipairs(cloakTatters) do
			local tatterAngle = tatterData.angle + hoverTime * 0.15
			local radius = HARVESTER_CONFIG.CLOAK_WIDTH * 0.5
			local tatterX = math.cos(tatterAngle) * radius
			local tatterZ = math.sin(tatterAngle) * 0.6 + tatterData.offset
			local tatterWave = math.sin(hoverTime * 2 + tatterData.angle * 2) * 0.25
			local tatterSway = math.cos(hoverTime * 1.5 + tatterData.angle) * 0.15

			tatterData.part.CFrame = baseCFrame 
				* CFrame.new(tatterX, tatterBaseY - tatterData.height * 0.5, tatterZ)
				* CFrame.Angles(tatterWave, tatterAngle + tatterSway, tatterSway * 0.5)
		end

		-- SCYTHE
		local rightHand = arms[2].hand
		local scytheBaseAngle = math.rad(-55) + scytheSwingAngle

		local scythePivot = rightHand.CFrame 
			* CFrame.new(0, -0.2, 0)
			* CFrame.Angles(scytheBaseAngle, math.rad(5), math.rad(-10))

		local handleOffset = HARVESTER_CONFIG.SCYTHE_LENGTH * 0.3
		scytheHandle.CFrame = scythePivot * CFrame.new(0, -handleOffset, 0)
		handleWrap1.CFrame = scythePivot * CFrame.new(0, 0.5, 0)
		handleWrap2.CFrame = scythePivot * CFrame.new(0, -1.0, 0)
		handleCap.CFrame = scythePivot * CFrame.new(0, -HARVESTER_CONFIG.SCYTHE_LENGTH * 0.48, 0)

		local bladeAttach = scythePivot * CFrame.new(0, HARVESTER_CONFIG.SCYTHE_LENGTH * 0.48, 0)
		bladeCollar.CFrame = bladeAttach * CFrame.Angles(0, 0, math.rad(90))

		local bladeCurve = CFrame.Angles(0, math.rad(-20), math.rad(5))
		bladeSpine.CFrame = bladeAttach * CFrame.new(-1.5, 0.1, 0.1) * bladeCurve
		blade.CFrame = bladeAttach * CFrame.new(-1.4, 0, 0.35) * bladeCurve
		bladeEdge.CFrame = blade.CFrame * CFrame.new(0, -0.04, 0.42)
		bladeTip.CFrame = bladeAttach * CFrame.new(-2.9, 0, 0.5) * bladeCurve * CFrame.Angles(0, math.rad(-25), 0)

		-- Ability Aura position
		abilityAura.CFrame = baseCFrame * CFrame.new(0, HEIGHT * 0.4, 0)
	end

	UpdateNPCPosition(npcX, npcZ, npcRotation, 0)

	-- ---------------------------------------------------------------------------
	-- SOUNDS
	-- ---------------------------------------------------------------------------

	local spawnSound = Instance.new("Sound")
	spawnSound.SoundId = "rbxassetid://70599786387887"
	spawnSound.Volume = 0.5
	spawnSound.PlaybackSpeed = 1.5
	spawnSound.Parent = cloakLower
	spawnSound:Play()

	local whisperSound = Instance.new("Sound")
	whisperSound.SoundId = "rbxassetid://126156289311161"
	whisperSound.Volume = 0.5
	whisperSound.Looped = true
	whisperSound.PlaybackSpeed = 1.0
	whisperSound.Parent = cloakLower
	whisperSound:Play()

	-- Ability sounds
	local screamSound = Instance.new("Sound")
	screamSound.SoundId = "rbxassetid://70599786387887"
	screamSound.Volume = 0.5
	screamSound.PlaybackSpeed = 1.0
	screamSound.Parent = cloakLower

	local dashSound = Instance.new("Sound")
	dashSound.SoundId = "rbxassetid://80126562543070"
	dashSound.Volume = 0.4
	dashSound.PlaybackSpeed = 1.2
	dashSound.Parent = cloakLower

	-- ---------------------------------------------------------------------------
	-- ATTACK ANIMATION
	-- ---------------------------------------------------------------------------

	local function PlayAttackAnimation()
		if isAttacking then return end
		isAttacking = true

		for _, eyeData in ipairs(eyes) do
			if eyeData.light then
				TweenService:Create(eyeData.light, TweenInfo.new(0.15), {
					Brightness = 8,
					Range = 12
				}):Play()
			end
			TweenService:Create(eyeData.glow, TweenInfo.new(0.15), {
				Color = Color3.fromRGB(255, 100, 100)
			}):Play()
		end

		TweenService:Create(bladeEdge, TweenInfo.new(0.15), {
			Color = Color3.fromRGB(255, 120, 160)
		}):Play()
		TweenService:Create(bladeLight, TweenInfo.new(0.15), {
			Brightness = 5,
			Range = 18
		}):Play()
		bladeTrail.Rate = 30

		local raiseSound = Instance.new("Sound")
		raiseSound.SoundId = "rbxassetid://9114221890"
		raiseSound.Volume = 0.7
		raiseSound.PlaybackSpeed = 0.7
		raiseSound.Parent = cloakLower
		raiseSound:Play()

		for i = 1, 15 do
			scytheSwingAngle = math.rad(-100) * (i / 15)
			task.wait(0.02)
		end

		task.wait(0.06)

		local swingSound = Instance.new("Sound")
		swingSound.SoundId = "rbxassetid://5766332557"
		swingSound.Volume = 1.2
		swingSound.PlaybackSpeed = 0.8
		swingSound.Parent = cloakLower
		swingSound:Play()

		for i = 1, 10 do
			scytheSwingAngle = math.rad(-100) + math.rad(150) * (i / 10)
			task.wait(0.015)
		end

		for i = 10, 0, -1 do
			scytheSwingAngle = math.rad(50) * (i / 10)
			task.wait(0.025)
		end
		scytheSwingAngle = 0

		for _, eyeData in ipairs(eyes) do
			if eyeData.light then
				TweenService:Create(eyeData.light, TweenInfo.new(0.3), {
					Brightness = 3,
					Range = 6
				}):Play()
			end
			TweenService:Create(eyeData.glow, TweenInfo.new(0.3), {
				Color = HARVESTER_CONFIG.EYE_COLOR
			}):Play()
		end

		TweenService:Create(bladeEdge, TweenInfo.new(0.3), {
			Color = HARVESTER_CONFIG.SCYTHE_EDGE
		}):Play()
		TweenService:Create(bladeLight, TweenInfo.new(0.3), {
			Brightness = 2,
			Range = 10
		}):Play()
		bladeTrail.Rate = 8

		Debris:AddItem(raiseSound, 2)
		Debris:AddItem(swingSound, 2)

		isAttacking = false
	end

	-- ---------------------------------------------------------------------------
	-- ABILITY:  PHANTOM DASH
	-- ---------------------------------------------------------------------------

	local function PhantomDash(targetHrp)
		if not HARVESTER_CONFIG.PHANTOM_DASH.ENABLED then return false end
		if tick() < abilityCooldowns.phantomDash then return false end
		if abilityState.isDashing then return false end

		abilityState.isDashing = true
		abilityCooldowns.phantomDash = tick() + HARVESTER_CONFIG.PHANTOM_DASH.COOLDOWN

		local direction = (targetHrp.Position - Vector3.new(npcX, 0, npcZ)).Unit
		local dashDistance = math.min(
			HARVESTER_CONFIG.PHANTOM_DASH.DISTANCE,
			(targetHrp.Position - Vector3.new(npcX, 0, npcZ)).Magnitude - 3
		)

		if dashDistance < 5 then
			abilityState.isDashing = false
			return false
		end

		dashSound:Play()

		-- Visual effect
		abilityEmitter.Rate = 50
		TweenService:Create(abilityAura, TweenInfo.new(0.2), {
			Transparency = 0.5,
			Size = Vector3.new(8, 10, 8)
		}):Play()

		-- Dash movement
		local steps = 10
		local stepDist = dashDistance / steps

		for i = 1, steps do
			local newX = npcX + direction.X * stepDist
			local newZ = npcZ + direction.Z * stepDist

			if IsInLobby(newX) then break end

			npcX = newX
			npcZ = newZ

			-- Leave trail
			if HARVESTER_CONFIG.PHANTOM_DASH.LEAVES_TRAIL then
				local trailPart = CreatePart(
					"DashTrail",
					Vector3.new(1, 6, 1),
					HARVESTER_CONFIG.PHANTOM_DASH.TRAIL_COLOR,
					Enum.Material.Neon,
					0.5,
					workspace
				)
				trailPart.Position = Vector3.new(npcX, 3, npcZ)

				TweenService:Create(trailPart, TweenInfo.new(0.5), {
					Transparency = 1,
					Size = Vector3.new(0.1, 0.1, 0.1)
				}):Play()

				Debris:AddItem(trailPart, 0.6)
			end

			task.wait(0.02)
		end

		-- Check for damage on contact
		for _, player in pairs(Players:GetPlayers()) do
			local char = player.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChild("Humanoid")
				if hrp and hum and hum.Health > 0 then
					local dist = (hrp.Position - Vector3.new(npcX, 0, npcZ)).Magnitude
					if dist < 5 and not IsInLobby(hrp.Position.X) then
						hum: TakeDamage(HARVESTER_CONFIG.PHANTOM_DASH.DAMAGE_ON_CONTACT)
					end
				end
			end
		end
		-- Reset visual
		abilityEmitter.Rate = 0
		TweenService: Create(abilityAura, TweenInfo.new(0.3), {
			Transparency = 0.9,
			Size = Vector3.new(5, 8, 5)
		}):Play()

		abilityState.isDashing = false
		print("?? HARVESTER:  Phantom Dash completed!")
		return true
	end

	-- ---------------------------------------------------------------------------
	-- TELEPORT BEHIND PLAYER (MEJORADO)
	-- ---------------------------------------------------------------------------

	local function TeleportBehindPlayer(targetHrp)
		if not HARVESTER_CONFIG.TELEPORT_BEHIND.ENABLED then return false end
		if tick() < abilityCooldowns.teleportBehind then return false end

		local behindOffset = targetHrp.CFrame * CFrame.new(0, 0, HARVESTER_CONFIG.TELEPORT_BEHIND.DISTANCE_BEHIND)
		local newX = behindOffset.Position.X
		local newZ = behindOffset.Position.Z

		if IsInLobby(newX) then return false end

		abilityCooldowns.teleportBehind = tick() + HARVESTER_CONFIG.TELEPORT_BEHIND.COOLDOWN

		-- Whisper before teleport
		if HARVESTER_CONFIG.TELEPORT_BEHIND.WHISPER_BEFORE then
			local whisper = Instance.new("Sound")
			whisper.SoundId = "rbxassetid://80126562543070"
			whisper.Volume = 0.2
			whisper.PlaybackSpeed = 0.5
			whisper.Parent = cloakLower
			whisper: Play()
			Debris:AddItem(whisper, 2)
		end

		-- Gather all parts for fade
		local allParts = {}
		for _, part in pairs(npcModel:GetDescendants()) do
			if part:IsA("BasePart") then
				table.insert(allParts, {part = part, originalTrans = part.Transparency})
			end
		end

		-- Disable particles
		auraEmitter.Enabled = false
		soulEmitter.Enabled = false
		bladeTrail.Enabled = false

		-- Fade out with purple glow
		for _, data in ipairs(allParts) do
			TweenService:Create(data.part, TweenInfo.new(0.15), {
				Transparency = 1,
				Color = HARVESTER_CONFIG.ABILITY_GLOW
			}):Play()
		end

		local teleportSound = Instance.new("Sound")
		teleportSound.SoundId = "rbxassetid://80126562543070"
		teleportSound.Volume = 0.4
		teleportSound.PlaybackSpeed = 0.8
		teleportSound.Parent = cloakLower
		teleportSound:Play()

		task.wait(0.2)

		-- Update position
		npcX = newX
		npcZ = newZ
		npcRotation = math.atan2(-(targetHrp.Position.X - npcX), -(targetHrp.Position.Z - npcZ))

		-- Fade in
		for _, data in ipairs(allParts) do
			TweenService:Create(data.part, TweenInfo.new(0.15), {
				Transparency = data.originalTrans
			}):Play()
		end

		-- Re-enable particles
		task.delay(0.15, function()
			auraEmitter.Enabled = true
			soulEmitter.Enabled = true
			bladeTrail.Enabled = true
		end)

		Debris:AddItem(teleportSound, 2)
		print("?? HARVESTER: Teleported behind player!")
		return true
	end

	-- ---------------------------------------------------------------------------
	-- REAPER'S HARVEST WARNING VISUAL
	-- ---------------------------------------------------------------------------

	local function CreateHarvestWarning(position, radius, color)
		local warningCircle = Instance.new("Part")
		warningCircle.Name = "HarvestWarning"
		warningCircle.Shape = Enum.PartType.Cylinder
		warningCircle.Size = Vector3.new(0.2, radius * 2, radius * 2)
		warningCircle.CFrame = CFrame.new(position.X, 0.6, position.Z) * CFrame.Angles(0, 0, math.rad(90))
		warningCircle.Color = color
		warningCircle.Material = Enum.Material.Neon
		warningCircle.Transparency = 0.7
		warningCircle.Anchored = true
		warningCircle.CanCollide = false
		warningCircle.Parent = workspace

		-- Pulsing animation
		coroutine.wrap(function()
			for i = 1, 15 do
				TweenService:Create(warningCircle, TweenInfo.new(0.1), {
					Transparency = 0.3
				}):Play()
				task.wait(0.1)
				TweenService:Create(warningCircle, TweenInfo.new(0.1), {
					Transparency = 0.7
				}):Play()
				task.wait(0.1)
			end
		end)()

		-- Cleanup after charge time
		Debris: AddItem(warningCircle, HARVESTER_CONFIG.REAPERS_HARVEST.CHARGE_TIME + 0.5)

		return warningCircle
	end

	-- ---------------------------------------------------------------------------
	-- DEATH EFFECT
	-- ---------------------------------------------------------------------------

	local function PlayDeathEffect()
		auraEmitter.Enabled = false
		soulEmitter.Enabled = false
		bladeTrail.Enabled = false
		abilityEmitter.Enabled = false
		whisperSound: Stop()

		local deathSound = Instance.new("Sound")
		deathSound.SoundId = "rbxassetid://70599786387887"
		deathSound.Volume = 1.0
		deathSound.PlaybackSpeed = 0.8
		deathSound.Parent = cloakLower
		deathSound: Play()

		-- Collapse animation
		for _, part in pairs(npcModel:GetDescendants()) do
			if part:IsA("BasePart") then
				local randomX = (math.random() - 0.5) * 2
				local randomZ = (math.random() - 0.5) * 2
				TweenService:Create(part, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = Vector3.new(
						part.Position.X + randomX,
						groundY - 1,
						part.Position.Z + randomZ
					),
					Transparency = 1
				}):Play()
			end
		end

		-- Soul burst effect
		local soulBurst = Instance.new("Part")
		soulBurst.Size = Vector3.new(2, 2, 2)
		soulBurst.Shape = Enum.PartType.Ball
		soulBurst.Color = HARVESTER_CONFIG.SOUL_COLOR
		soulBurst.Material = Enum.Material.Neon
		soulBurst.Transparency = 0.4
		soulBurst.Anchored = true
		soulBurst.CanCollide = false
		soulBurst.Position = hoodBack.Position
		soulBurst.Parent = workspace

		local burstLight = Instance.new("PointLight")
		burstLight.Brightness = 5
		burstLight.Color = HARVESTER_CONFIG.SOUL_COLOR
		burstLight.Range = 20
		burstLight.Parent = soulBurst

		TweenService:Create(soulBurst, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
			Size = Vector3.new(15, 15, 15),
			Transparency = 1
		}):Play()

		TweenService:Create(burstLight, TweenInfo.new(0.6), {
			Brightness = 0,
			Range = 0
		}):Play()

		Debris:AddItem(soulBurst, 0.7)
		task.wait(0.9)
		Debris:AddItem(deathSound, 2)
	end

	-- ---------------------------------------------------------------------------
	-- AI BEHAVIOR LOOP
	-- ---------------------------------------------------------------------------

	local isAlive = true
	local lastAttackTime = 0
	local lastAbilityCheck = 0
	local darknessTriggeredOnSpawn = false

	local function FindNearestPlayer()
		local nearest, nearestDist = nil, HARVESTER_CONFIG.DETECTION_RANGE

		-- First check for priority target (Death Mark)
		if HARVESTER_CONFIG.DEATH_MARK.PRIORITY_TARGET then
			for _, data in pairs(abilityState.markedPlayers) do
				if data.player and data.player.Parent then
					local char = data.player.Character
					if char then
						local hrp = char:FindFirstChild("HumanoidRootPart")
						local hum = char: FindFirstChild("Humanoid")
						if hrp and hum and hum.Health > 0 and not IsInLobby(hrp.Position.X) then
							return data.player, (hrp.Position - Vector3.new(npcX, 0, npcZ)).Magnitude
						end
					end
				end
			end
		end

		-- Normal target finding
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

	local function CalculateDamage(baseDamage, targetPlayer)
		local finalDamage = baseDamage

		-- Check if player is marked
		local playerId = targetPlayer.UserId
		if abilityState.markedPlayers[playerId] then
			finalDamage = finalDamage * abilityState.markedPlayers[playerId].damageMultiplier
		end

		return finalDamage
	end

	local function AttackPlayer(player)
		if tick() - lastAttackTime < HARVESTER_CONFIG.ATTACK_COOLDOWN then return end
		if isAttacking then return end
		lastAttackTime = tick()

		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChild("Humanoid")
		local hrp = char: FindFirstChild("HumanoidRootPart")

		if hum and hum.Health > 0 and hrp then
			-- Chance to teleport behind
			if math.random() < HARVESTER_CONFIG.TELEPORT_BEHIND.CHANCE then
				if TeleportBehindPlayer(hrp) then
					task.wait(HARVESTER_CONFIG.TELEPORT_BEHIND.ATTACK_DELAY)
				end
			end

			coroutine.wrap(PlayAttackAnimation)()

			task.wait(0.45)

			-- Check if still in range after swing
			local dist = (hrp.Position - Vector3.new(npcX, 0, npcZ)).Magnitude
			if dist < HARVESTER_CONFIG.ATTACK_RANGE + 3 and hum.Health > 0 then
				local damage = CalculateDamage(HARVESTER_CONFIG.DAMAGE, player)
				hum: TakeDamage(damage)

				-- Chance for jumpscare on attack
				if HARVESTER_CONFIG.JUMPSCARE.ENABLED and math.random() < HARVESTER_CONFIG.JUMPSCARE.CHANCE_ON_ATTACK then
					AbilitySystem.TriggerJumpscare(HARVESTER_CONFIG.JUMPSCARE, player)
				end

				-- Check for low health jumpscare
				if HARVESTER_CONFIG.JUMPSCARE.ON_LOW_HEALTH then
					local healthPercent = hum.Health / hum.MaxHealth
					if healthPercent <= HARVESTER_CONFIG.JUMPSCARE.LOW_HEALTH_THRESHOLD then
						AbilitySystem.TriggerJumpscare(HARVESTER_CONFIG.JUMPSCARE, player)
					end
				end

				-- Check for kill
				if hum.Health <= 0 and HARVESTER_CONFIG.JUMPSCARE.ON_KILL then
					AbilitySystem.TriggerJumpscare(HARVESTER_CONFIG.JUMPSCARE, player)
				end

				-- Soul drain visual effect
				local soulDrain = Instance.new("Part")
				soulDrain.Size = Vector3.new(0.6, 0.6, 0.6)
				soulDrain.Shape = Enum.PartType.Ball
				soulDrain.Color = HARVESTER_CONFIG.SOUL_COLOR
				soulDrain.Material = Enum.Material.Neon
				soulDrain.Transparency = 0.2
				soulDrain.Anchored = true
				soulDrain.CanCollide = false
				soulDrain.Position = hrp.Position
				soulDrain.Parent = workspace

				local drainLight = Instance.new("PointLight")
				drainLight.Brightness = 3
				drainLight.Color = HARVESTER_CONFIG.SOUL_COLOR
				drainLight.Range = 8
				drainLight.Parent = soulDrain

				TweenService:Create(soulDrain, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = voidInterior.Position,
					Size = Vector3.new(0.1, 0.1, 0.1),
					Transparency = 1
				}):Play()

				Debris:AddItem(soulDrain, 0.6)
			end
		end
	end

	-- ---------------------------------------------------------------------------
	-- ABILITY DECISION SYSTEM
	-- ---------------------------------------------------------------------------

	local function CheckAndUseAbilities(target, distance)
		local currentTime = tick()

		-- Don't spam ability checks
		if currentTime - lastAbilityCheck < 1 then return end
		lastAbilityCheck = currentTime

		local char = target.Character
		if not char then return end
		local hum = char: FindFirstChild("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hum or not hrp then return end

		-- DARKNESS VEIL - Random trigger
		if HARVESTER_CONFIG.DARKNESS_VEIL.ENABLED then
			if currentTime > abilityCooldowns.darknessVeil then
				if math.random() < HARVESTER_CONFIG.DARKNESS_VEIL.RANDOM_TRIGGER_CHANCE then
					abilityCooldowns.darknessVeil = currentTime + HARVESTER_CONFIG.DARKNESS_VEIL.COOLDOWN
					AbilitySystem.DarknessVeil(HARVESTER_CONFIG.DARKNESS_VEIL, Vector3.new(npcX, 0, npcZ))
				end
			end
		end

		-- SOUL SCREAM - When multiple players nearby or player is close
		if HARVESTER_CONFIG.SOUL_SCREAM.ENABLED then
			if currentTime > abilityCooldowns.soulScream then
				local playersInRange = 0
				for _, p in pairs(Players: GetPlayers()) do
					local c = p.Character
					if c then
						local h = c:FindFirstChild("HumanoidRootPart")
						if h then
							local d = (h.Position - Vector3.new(npcX, 0, npcZ)).Magnitude
							if d <= HARVESTER_CONFIG.SOUL_SCREAM.RANGE and not IsInLobby(h.Position.X) then
								playersInRange = playersInRange + 1
							end
						end
					end
				end

				if playersInRange >= 2 or (distance < 20 and math.random() < 0.3) then
					abilityCooldowns.soulScream = currentTime + HARVESTER_CONFIG.SOUL_SCREAM.COOLDOWN
					screamSound:Play()
					AbilitySystem.SoulScream(HARVESTER_CONFIG.SOUL_SCREAM, npcX, npcZ)
				end
			end
		end

		-- PHANTOM DASH - When target is medium distance
		if HARVESTER_CONFIG.PHANTOM_DASH.ENABLED then
			if distance > 15 and distance < HARVESTER_CONFIG.PHANTOM_DASH.DISTANCE + 10 then
				if currentTime > abilityCooldowns.phantomDash then
					PhantomDash(hrp)
				end
			end
		end

		-- DEATH MARK - Apply to target if not marked
		if HARVESTER_CONFIG.DEATH_MARK.ENABLED then
			if currentTime > abilityCooldowns.deathMark then
				if not abilityState.markedPlayers[target.UserId] then
					if distance < 30 and math.random() < 0.25 then
						abilityCooldowns.deathMark = currentTime + HARVESTER_CONFIG.DEATH_MARK.COOLDOWN
						AbilitySystem.ApplyDeathMark(HARVESTER_CONFIG.DEATH_MARK, target, abilityState.markedPlayers)
					end
				end
			end
		end

		-- REAPER'S HARVEST - When surrounded or multiple players close
		if HARVESTER_CONFIG.REAPERS_HARVEST.ENABLED then
			if currentTime > abilityCooldowns.reapersHarvest then
				local closePlayersCount = 0
				for _, p in pairs(Players: GetPlayers()) do
					local c = p.Character
					if c then
						local h = c:FindFirstChild("HumanoidRootPart")
						if h then
							local d = (h.Position - Vector3.new(npcX, 0, npcZ)).Magnitude
							if d <= HARVESTER_CONFIG.REAPERS_HARVEST.RANGE and not IsInLobby(h.Position.X) then
								closePlayersCount = closePlayersCount + 1
							end
						end
					end
				end

				if closePlayersCount >= 2 or (closePlayersCount >= 1 and math.random() < 0.15) then
					abilityCooldowns.reapersHarvest = currentTime + HARVESTER_CONFIG.REAPERS_HARVEST.COOLDOWN
					abilityState.isChargingHarvest = true

					-- Play charge animation
					abilityEmitter.Rate = 100
					TweenService:Create(abilityAura, TweenInfo.new(0.3), {
						Transparency = 0.3,
						Size = Vector3.new(HARVESTER_CONFIG.REAPERS_HARVEST.RANGE, 10, HARVESTER_CONFIG.REAPERS_HARVEST.RANGE),
						Color = HARVESTER_CONFIG.REAPERS_HARVEST.WARNING_COLOR
					}):Play()

					for _, eyeData in ipairs(eyes) do
						TweenService:Create(eyeData.glow, TweenInfo.new(0.3), {
							Color = HARVESTER_CONFIG.RAGE_COLOR
						}):Play()
						if eyeData.light then
							TweenService:Create(eyeData.light, TweenInfo.new(0.3), {
								Brightness = 10,
								Color = HARVESTER_CONFIG.RAGE_COLOR
							}):Play()
						end
					end

					coroutine.wrap(function()
						AbilitySystem.ReapersHarvest(
							HARVESTER_CONFIG.REAPERS_HARVEST,
							npcX, npcZ,
							CreateHarvestWarning,
							function(hitPlayers)
								-- After harvest callback
								abilityEmitter.Rate = 0
								TweenService:Create(abilityAura, TweenInfo.new(0.5), {
									Transparency = 0.9,
									Size = Vector3.new(5, 8, 5),
									Color = HARVESTER_CONFIG.ABILITY_GLOW
								}):Play()

								for _, eyeData in ipairs(eyes) do
									TweenService:Create(eyeData.glow, TweenInfo.new(0.5), {
										Color = HARVESTER_CONFIG.EYE_COLOR
									}):Play()
									if eyeData.light then
										TweenService: Create(eyeData.light, TweenInfo.new(0.5), {
											Brightness = 3,
											Color = HARVESTER_CONFIG.EYE_COLOR
										}):Play()
									end
								end

								abilityState.isChargingHarvest = false
							end
						)
					end)()
				end
			end
		end
	end

	-- =========================================================================
	-- MAIN LOOP WITH LIFETIME CHECK
	-- =========================================================================

	local chaseConnection
	chaseConnection = RunService.Heartbeat:Connect(function(dt)
		if not isAlive or not cloakLower or not cloakLower.Parent then
			if chaseConnection then chaseConnection:Disconnect() end
			return
		end

		-- =====================================================================
		-- LIFETIME CHECK
		-- =====================================================================
		local elapsedTime = tick() - spawnTime
		if elapsedTime >= npcLifetime then
			print("? Harvester lifetime expired after "..string.format("%.1f", elapsedTime).." seconds")
			isAlive = false
			if chaseConnection then chaseConnection:Disconnect() end
			PlayDeathEffect()
			task.wait(0.9)
			if npcFolder and npcFolder.Parent then
				npcFolder:Destroy()
			end
			return
		end

		-- =====================================================================
		-- DARKNESS VEIL ON SPAWN
		-- =====================================================================
		if HARVESTER_CONFIG.DARKNESS_VEIL.TRIGGER_ON_SPAWN and not darknessTriggeredOnSpawn then
			if elapsedTime >= HARVESTER_CONFIG.DARKNESS_VEIL.SPAWN_DELAY then
				darknessTriggeredOnSpawn = true
				abilityCooldowns.darknessVeil = tick() + HARVESTER_CONFIG.DARKNESS_VEIL.COOLDOWN
				AbilitySystem.DarknessVeil(HARVESTER_CONFIG.DARKNESS_VEIL, Vector3.new(npcX, 0, npcZ))
			end
		end

		-- =====================================================================
		-- CHECK IF STUNNED
		-- =====================================================================
		if npcModel:GetAttribute("Stunned") then
			UpdateNPCPosition(npcX, npcZ, npcRotation, dt)
			return
		end

		-- =====================================================================
		-- CHECK IF CHARGING HARVEST (Can't move)
		-- =====================================================================
		if abilityState.isChargingHarvest then
			UpdateNPCPosition(npcX, npcZ, npcRotation, dt)
			return
		end

		-- =====================================================================
		-- CHECK IF IN .- DESTROY
		-- =====================================================================
		if IsInLobby(npcX) then
			print("?? Harvester entered .- destroying")
			isAlive = false
			if chaseConnection then chaseConnection: Disconnect() end
			PlayDeathEffect()
			task.wait(0.9)
			if npcFolder and npcFolder.Parent then
				npcFolder: Destroy()
			end
			return
		end

		local target, distance = FindNearestPlayer()

		if target then
			local char = target.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					local direction = Vector3.new(hrp.Position.X - npcX, 0, hrp.Position.Z - npcZ)

					-- Check and use abilities
					CheckAndUseAbilities(target, distance)

					if direction.Magnitude > 0.5 then
						local lookAngle = math.atan2(-direction.X, -direction.Z)

						if distance > HARVESTER_CONFIG.ATTACK_RANGE and not abilityState.isDashing then
							local moveDir = direction.Unit
							local newX = npcX + moveDir.X * HARVESTER_CONFIG.SPEED * dt
							local newZ = npcZ + moveDir.Z * HARVESTER_CONFIG.SPEED * dt

							if not IsInLobby(newX) then
								npcRotation = lookAngle
								UpdateNPCPosition(newX, newZ, lookAngle, dt)
							else
								UpdateNPCPosition(npcX, npcZ, lookAngle, dt)
							end
						else
							UpdateNPCPosition(npcX, npcZ, lookAngle, dt)
							AttackPlayer(target)
						end
					else
						UpdateNPCPosition(npcX, npcZ, npcRotation, dt)
					end
				else
					UpdateNPCPosition(npcX, npcZ, npcRotation, dt)
				end
			else
				UpdateNPCPosition(npcX, npcZ, npcRotation, dt)
			end
		else
			UpdateNPCPosition(npcX, npcZ, npcRotation, dt)
		end
	end)

	-- =========================================================================
	-- AMBIENT EFFECTS
	-- =========================================================================

	coroutine.wrap(function()
		while isAlive and cloakLower and cloakLower.Parent do
			task.wait(math.random(5, 12))
			if isAlive and cloakLower and cloakLower.Parent then
				local whisper = Instance.new("Sound")
				whisper.SoundId = "rbxassetid://80126562543070"
				whisper.Volume = 0.2
				whisper.PlaybackSpeed = 0.35 + math.random() * 0.25
				whisper.Parent = cloakLower
				whisper:Play()
				Debris:AddItem(whisper, 4)
			end
		end
	end)()

	-- Cleanup on destroy
	npcFolder.AncestryChanged: Connect(function()
		if not npcFolder.Parent then
			isAlive = false
			whisperSound:Stop()
			if chaseConnection then chaseConnection:Disconnect() end
		end
	end)

	return npcFolder
end

-- -------------------------------------------------------------------------------
-- EVENT LISTENER
-- -------------------------------------------------------------------------------

if SpawnHarvesterEvent then
	SpawnHarvesterEvent.Event:Connect(function(position, player, side, zDir, doorFrameInfo, lifetime)
		print("?? SpawnHarvesterEvent received - Lifetime: "..tostring(lifetime))
		task.wait(0.5)
		CreateHarvesterNPC(position, player, side, zDir, doorFrameInfo, lifetime)
	end)
end

print("=== NPC HARVESTER SYSTEM V5 - ULTIMATE ABILITIES ===")
print("   Abilities:")
print("     1.Darkness Veil - Oscurece pantalla")
print("     2.Soul Scream - Grito que ralentiza")
print("     3.Phantom Dash - Dash rápido")
print("     4.Death Mark - Marca de muerte")
print("     5.Reaper's Harvest - Ataque en área")
print("     6.Teleport Behind - Teletransporte mejorado")
print("     7.Jumpscare - Al matar/atacar")
print("=================================================")