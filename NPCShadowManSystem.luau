--[[
    +------------------------------------------------------------------------------+
    |                    HUMANOID HORROR ENTITY SYSTEM                              |
    |                 "THE SHADOW MAN" - NPC FÍSICO v1.0                            |
    |                      SOMBRA VIVIENTE CON FUEGO NEGRO                          |
    +------------------------------------------------------------------------------+
    
    FEATURES:
    - Figura completamente negra, silueta de sombra pura
    - Aura de fuego negro/violeta oscuro constante
    - Apaga las lámparas de la calle al pasar cerca
    - Se teletransporta detrás del jugador o a zonas oscuras
    - Ataques: Shadow Claw, Tendril Grab, Darkness Burst
    - Figura original: cabeza sin rostro, cuerpo etéreo que se 
      desvanece hacia abajo, brazos largos con garras de humo
    - Trail de oscuridad donde camina
    - Ojos que aparecen/desaparecen (parpadeo inverso)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local SpawnShadowManEvent = ReplicatedStorage:FindFirstChild("SpawnShadowManEvent")
if not SpawnShadowManEvent then
	SpawnShadowManEvent = Instance.new("BindableEvent")
	SpawnShadowManEvent.Name = "SpawnShadowManEvent"
	SpawnShadowManEvent.Parent = ReplicatedStorage
end

-- -------------------------------------------------------------------------------
-- CONFIGURACIÓN
-- -------------------------------------------------------------------------------
local CFG = {
	SCALE = 1.4,

	SPEED_IDLE = 0,
	SPEED_STALK = 14,
	SPEED_WALK = 22,
	SPEED_CHARGE = 32,
	SPEED_BURST = 38,

	DETECT_RANGE = 300,
	STALK_DIST = 130,
	CHASE_DIST = 65,
	CHARGE_DIST = 35,
	ATTACK_RANGE = 10,
	TENDRIL_RANGE = 18,

	DMG_CLAW = 30,
	DMG_TENDRIL = 45,
	DMG_BURST = 55,
	CD_ATTACK = 0.8,
	CD_TENDRIL = 6,
	CD_BURST = 14,

	-- Teleport
	TELEPORT_CD = 5,
	TELEPORT_BEHIND_DIST = 12,
	TELEPORT_CHANCE = 0.03,        -- per frame chance when chasing
	TELEPORT_CHARGE_CHANCE = 0.06, -- higher when charging

	-- Lamp extinguish
	LAMP_KILL_RANGE = 25,
	LAMP_KILL_SPEED = 0.3,         -- seconds to fade a lamp
	LAMP_RESTORE_DELAY = 15,       -- seconds after death to restore lamps
	LAMP_RESTORE_RANGE = 40,      -- Distancia a la que las lámparas se re-encienden
	LAMP_RESTORE_SPEED = 1.0,     -- Velocidad de fade-in (segundos)

	-- Colors - ALL BLACK/DARK
	SHADOW_CORE = Color3.fromRGB(3, 2, 5),
	SHADOW_BODY = Color3.fromRGB(8, 5, 12),
	SHADOW_EDGE = Color3.fromRGB(15, 10, 20),
	SHADOW_MIST = Color3.fromRGB(5, 3, 8),
	SHADOW_FIRE = Color3.fromRGB(20, 8, 35),
	SHADOW_FIRE_TIP = Color3.fromRGB(40, 15, 60),
	SHADOW_FIRE_CORE = Color3.fromRGB(10, 3, 18),
	EYE_COLOR = Color3.fromRGB(120, 0, 180),
	EYE_FLASH = Color3.fromRGB(180, 30, 255),
	EYE_DIM = Color3.fromRGB(60, 0, 100),
	CLAW_COLOR = Color3.fromRGB(25, 12, 40),
	TRAIL_COLOR = Color3.fromRGB(5, 2, 10),
	TENDRIL_COLOR = Color3.fromRGB(12, 5, 22),

	-- Body dimensions
	HEAD_SIZE = Vector3.new(0.55, 0.70, 0.55),
	TORSO_SIZE = Vector3.new(0.50, 2.2, 0.28),
	PELVIS_SIZE = Vector3.new(0.40, 0.35, 0.24),

	U_ARM_LEN = 1.6,
	U_ARM_THICK = 0.12,
	F_ARM_LEN = 1.9,
	F_ARM_THICK = 0.09,

	HAND_SIZE = Vector3.new(0.40, 0.12, 0.50),
	CLAW_LEN = 0.55,
	CLAW_SEGS = 5,

	THIGH_LEN = 1.5,
	THIGH_THICK = 0.16,
	SHIN_LEN = 1.8,
	SHIN_THICK = 0.11,

	-- Ethereal lower body (fades into mist)
	MIST_SEGMENTS = 8,
	MIST_BASE_SIZE = 0.4,

	-- Head tendrils (shadow wisps coming off head)
	HEAD_WISPS = 6,

	TILT_MAX = 60,
	TILT_SPEED = 3.0,
	TWITCH_FREQ = 0.04,

	ARM_IDLE = 5,
	ARM_STALK = 20,
	ARM_CHASE = 50,
	ARM_CHARGE = 70,
	ARM_SPEED = 3.5,

	ST_IDLE = 1,
	ST_STALK = 2,
	ST_WALK = 3,
	ST_CHARGE = 4,
	ST_ATTACK = 5,
	ST_TELEPORT = 6,

	LOBBY_MIN_X = -75,
	LOBBY_MAX_X = 75,

	ATTACK_WINDUP = 0.25,
	ATTACK_SWING = 0.12,
	ATTACK_RECOVER = 0.20,
}

local S = CFG.SCALE
local function Sc(v) return v * S end

-- Scale dimensions
CFG.HEAD_SIZE = CFG.HEAD_SIZE * S
CFG.TORSO_SIZE = CFG.TORSO_SIZE * S
CFG.PELVIS_SIZE = CFG.PELVIS_SIZE * S
CFG.HAND_SIZE = CFG.HAND_SIZE * S
CFG.U_ARM_LEN = CFG.U_ARM_LEN * S
CFG.U_ARM_THICK = CFG.U_ARM_THICK * S
CFG.F_ARM_LEN = CFG.F_ARM_LEN * S
CFG.F_ARM_THICK = CFG.F_ARM_THICK * S
CFG.THIGH_LEN = CFG.THIGH_LEN * S
CFG.THIGH_THICK = CFG.THIGH_THICK * S
CFG.SHIN_LEN = CFG.SHIN_LEN * S
CFG.SHIN_THICK = CFG.SHIN_THICK * S
CFG.CLAW_LEN = CFG.CLAW_LEN * S

local function InLobby(x)
	return x >= CFG.LOBBY_MIN_X and x <= CFG.LOBBY_MAX_X
end

-- -------------------------------------------------------------------------------
-- UTILIDADES
-- -------------------------------------------------------------------------------
local function MkPart(name, size, color, mat, trans, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Transparency = trans or 0
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = true
	p.Parent = parent
	return p
end

local function MkMesh(parent, mtype, scale)
	local m = Instance.new("SpecialMesh")
	m.MeshType = mtype or Enum.MeshType.Brick
	if scale then m.Scale = scale end
	m.Parent = parent
	return m
end

local function MkBall(name, diam, color, mat, parent)
	local p = MkPart(name, Vector3.new(diam, diam, diam), color, mat, 0, parent)
	p.Shape = Enum.PartType.Ball
	return p
end

local function MkLimb(name, length, thickness, color, parent)
	local p = MkPart(name, Vector3.new(thickness, length, thickness), color, nil, 0, parent)
	MkMesh(p, Enum.MeshType.Sphere, Vector3.new(1, 1, 1))
	return p
end

local function MkJoint(name, thickness, color, parent)
	local d = thickness * 1.5
	return MkBall(name, d, color, nil, parent)
end

local function Lerp(a, b, t) return a + (b - a) * t end

local function LerpCol(c1, c2, t)
	return Color3.new(c1.R + (c2.R - c1.R) * t, c1.G + (c2.G - c1.G) * t, c1.B + (c2.B - c1.B) * t)
end

local function LerpAng(a, b, t)
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * t
end

local function SmoothLerp(a, b, speed, dt)
	local t = math.clamp(speed * dt, 0, 1)
	return Lerp(a, b, t)
end

-- -------------------------------------------------------------------------------
-- CREACIÓN DEL NPC
-- -------------------------------------------------------------------------------
local function CreateShadowManNPC(spawnPos, triggerPlayer, side, zDir, doorFrameInfo, lifetime)
	local npcLife = (lifetime and lifetime > 0) and lifetime or 50

	print("========= THE SHADOW MAN V1.0 SPAWNED =========")
	print("  Scale:", S, " Lifetime:", npcLife)

	local folder = Instance.new("Folder")
	folder.Name = "HorrorEntity"
	folder.Parent = workspace

	local model = Instance.new("Model")
	model.Name = "TheShadowMan"
	model.Parent = folder

	local t0 = tick()
	folder:SetAttribute("SpawnTime", t0)
	folder:SetAttribute("Lifetime", npcLife)
	model:SetAttribute("SpawnTime", t0)
	model:SetAttribute("Lifetime", npcLife)
	model:SetAttribute("BodyCharge", 0)
	model:SetAttribute("HeadCharge", 0)
	model:SetAttribute("Stunned", false)
	model:SetAttribute("StunDuration", 3)

	local GY = 0.5

	-- Track extinguished lamps for restoration
	local extinguishedLamps = {}

	-- =========================================================================
	-- TORSO - Ethereal shadow body
	-- =========================================================================
	local torso = MkPart("Torso", CFG.TORSO_SIZE, CFG.SHADOW_CORE, nil, 0.1, model)
	torso.CanCollide = true
	MkMesh(torso, Enum.MeshType.Sphere, Vector3.new(0.80, 1, 0.45))

	-- Inner shadow glow
	local innerGlow = MkPart("InnerGlow",
		Vector3.new(CFG.TORSO_SIZE.X * 0.6, CFG.TORSO_SIZE.Y * 0.8, CFG.TORSO_SIZE.Z * 0.3),
		CFG.SHADOW_FIRE, Enum.Material.Neon, 0.7, model)
	MkMesh(innerGlow, Enum.MeshType.Sphere)

	local pelvis = MkPart("Pelvis", CFG.PELVIS_SIZE, CFG.SHADOW_CORE, nil, 0.15, model)
	MkMesh(pelvis, Enum.MeshType.Sphere, Vector3.new(1, 0.8, 0.9))

	-- Shadow wisps on body (floating dark fragments)
	local bodyWisps = {}
	for i = 1, 12 do
		local wSize = (0.04 + math.random() * 0.08) * S
		local wisp = MkPart("BodyWisp" .. i,
			Vector3.new(wSize, wSize * (1.5 + math.random() * 2), wSize),
			LerpCol(CFG.SHADOW_CORE, CFG.SHADOW_FIRE, math.random() * 0.3),
			Enum.Material.Neon, 0.3 + math.random() * 0.3, model)
		table.insert(bodyWisps, {
			part = wisp,
			off = Vector3.new(
				(math.random() - 0.5) * CFG.TORSO_SIZE.X * 0.8,
				(math.random() - 0.5) * CFG.TORSO_SIZE.Y * 0.8,
				(math.random() > 0.5 and 1 or -1) * CFG.TORSO_SIZE.Z * 0.4),
			phase = math.random() * math.pi * 2,
			speed = 1.5 + math.random() * 2,
			drift = Vector3.new(
				(math.random() - 0.5) * 0.3,
				0.2 + math.random() * 0.4,
				(math.random() - 0.5) * 0.3),
		})
	end

	-- =========================================================================
	-- LOWER BODY - Ethereal mist (no legs, fades into smoke)
	-- =========================================================================
	local mistSegments = {}
	for i = 1, CFG.MIST_SEGMENTS do
		local frac = i / CFG.MIST_SEGMENTS
		local segSize = CFG.MIST_BASE_SIZE * S * (1 - frac * 0.3)
		local segH = (0.3 + (1 - frac) * 0.2) * S
		local seg = MkPart("Mist" .. i,
			Vector3.new(segSize, segH, segSize),
			LerpCol(CFG.SHADOW_CORE, CFG.SHADOW_MIST, frac * 0.5),
			nil, 0.1 + frac * 0.6, model)
		MkMesh(seg, Enum.MeshType.Sphere, Vector3.new(1 + frac * 0.5, 0.8, 1 + frac * 0.5))
		table.insert(mistSegments, {
			part = seg, idx = i, frac = frac,
			phase = math.random() * math.pi * 2,
			sway = (math.random() - 0.5) * 0.5,
		})
	end

	-- Ground shadow pool
	local groundPool = MkPart("GroundPool",
		Vector3.new(Sc(2.0), Sc(0.05), Sc(2.0)),
		CFG.SHADOW_CORE, nil, 0.3, model)
	MkMesh(groundPool, Enum.MeshType.Cylinder, Vector3.new(1, 0.1, 1))

	-- =========================================================================
	-- HEAD - Featureless shadow with occasional eye flashes
	-- =========================================================================
	local head = MkPart("Head", CFG.HEAD_SIZE, CFG.SHADOW_CORE, nil, 0.05, model)
	MkMesh(head, Enum.MeshType.Sphere, Vector3.new(1, 1.2, 0.9))

	-- Shadow hood/cowl effect
	local hood = MkPart("Hood",
		Vector3.new(CFG.HEAD_SIZE.X * 1.3, CFG.HEAD_SIZE.Y * 0.8, CFG.HEAD_SIZE.Z * 1.2),
		CFG.SHADOW_BODY, nil, 0.15, model)
	MkMesh(hood, Enum.MeshType.Sphere, Vector3.new(1, 0.6, 1))

	-- Eyes that phase in and out
	local eyes = {}
	local eyePositions = {
		{ x = -0.18, y = 0.12, z = -0.42 },
		{ x = 0.18, y = 0.12, z = -0.42 },
	}
	for i, ep in ipairs(eyePositions) do
		local eyePart = MkPart("Eye" .. i,
			Vector3.new(Sc(0.08), Sc(0.04), Sc(0.03)),
			CFG.EYE_COLOR, Enum.Material.Neon, 1, model) -- Start invisible
		local eyeLight = Instance.new("PointLight")
		eyeLight.Brightness = 0
		eyeLight.Color = CFG.EYE_COLOR
		eyeLight.Range = Sc(2.0)
		eyeLight.Parent = eyePart
		table.insert(eyes, {
			part = eyePart, light = eyeLight,
			cx = ep.x * CFG.HEAD_SIZE.X,
			cy = ep.y * CFG.HEAD_SIZE.Y,
			cz = ep.z * CFG.HEAD_SIZE.Z,
			visible = false,
		})
	end

	-- Head wisps (shadow tendrils from head)
	local headWisps = {}
	for i = 1, CFG.HEAD_WISPS do
		local angle = (i / CFG.HEAD_WISPS) * math.pi * 2
		local wLen = (0.3 + math.random() * 0.4) * S
		local wisp = MkPart("HeadWisp" .. i,
			Vector3.new(Sc(0.03), wLen, Sc(0.03)),
			LerpCol(CFG.SHADOW_CORE, CFG.SHADOW_FIRE, math.random() * 0.2),
			Enum.Material.Neon, 0.2 + math.random() * 0.3, model)
		table.insert(headWisps, {
			part = wisp, angle = angle, baseLen = wLen,
			phase = math.random() * math.pi * 2,
			speed = 2 + math.random() * 3,
		})
	end

	-- =========================================================================
	-- ARMS - Long shadow arms with smoke claws
	-- =========================================================================
	local arms = {}
	for as = -1, 1, 2 do
		local af = Instance.new("Folder")
		af.Name = as == -1 and "LeftArm" or "RightArm"
		af.Parent = model

		local shoulder = MkJoint("Shoulder", CFG.U_ARM_THICK, CFG.SHADOW_CORE, af)
		shoulder.Transparency = 0.2
		local uArm = MkLimb("UArm", CFG.U_ARM_LEN, CFG.U_ARM_THICK, CFG.SHADOW_CORE, af)
		uArm.Transparency = 0.1
		local elbow = MkJoint("Elbow", math.max(CFG.U_ARM_THICK, CFG.F_ARM_THICK), CFG.SHADOW_CORE, af)
		elbow.Transparency = 0.2
		local fArm = MkLimb("FArm", CFG.F_ARM_LEN, CFG.F_ARM_THICK, CFG.SHADOW_CORE, af)
		fArm.Transparency = 0.15
		local wrist = MkJoint("Wrist", CFG.F_ARM_THICK, CFG.SHADOW_CORE, af)
		wrist.Transparency = 0.2
		local hand = MkPart("Hand", CFG.HAND_SIZE, CFG.SHADOW_BODY, nil, 0.1, af)
		MkMesh(hand, Enum.MeshType.Sphere, Vector3.new(1, 0.4, 1.2))

		-- Smoke claws (5 per hand)
		local claws = {}
		for c = 1, 5 do
			local segs = {}
			local segLens = { 0.30, 0.28, 0.25, 0.22, 0.18 }
			for sg = 1, CFG.CLAW_SEGS do
				local sw = (0.020 - sg * 0.002) * S
				local sh = CFG.CLAW_LEN * segLens[sg]
				local segP = MkLimb("C" .. c .. "S" .. sg, sh, sw,
					LerpCol(CFG.SHADOW_CORE, CFG.CLAW_COLOR, sg / CFG.CLAW_SEGS * 0.6), af)
				segP.Transparency = 0.1 + sg * 0.08
				local jt = MkBall("CJ" .. c .. "_" .. sg, sw * 1.3, CFG.SHADOW_CORE, nil, af)
				jt.Transparency = 0.3
				table.insert(segs, { part = segP, joint = jt, w = sw, h = sh })
			end
			-- Claw tip (neon smoke point)
			local tip = MkPart("Tip" .. c, Vector3.new(Sc(0.012), Sc(0.08), Sc(0.02)),
				CFG.EYE_COLOR, Enum.Material.Neon, 0.3, af)
			MkMesh(tip, Enum.MeshType.Wedge)
			table.insert(claws, {
				segs = segs, tip = tip, idx = c,
				xo = (c - 3) * Sc(0.07), thumb = c == 1,
				curlPh = math.random() * math.pi,
				twitchPh = math.random() * math.pi * 2,
			})
		end

		-- Arm smoke trail
		local armSmoke = Instance.new("ParticleEmitter")
		armSmoke.Texture = "rbxassetid://243098098"
		armSmoke.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, CFG.SHADOW_FIRE),
			ColorSequenceKeypoint.new(1, CFG.SHADOW_CORE)
		})
		armSmoke.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, Sc(0.05)),
			NumberSequenceKeypoint.new(0.5, Sc(0.15)),
			NumberSequenceKeypoint.new(1, Sc(0.3))
		})
		armSmoke.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(1, 1)
		})
		armSmoke.Lifetime = NumberRange.new(0.3, 0.6)
		armSmoke.Rate = 8
		armSmoke.Speed = NumberRange.new(0.1, 0.4)
		armSmoke.SpreadAngle = Vector2.new(360, 360)
		armSmoke.Parent = hand

		table.insert(arms, {
			folder = af, shoulder = shoulder, uArm = uArm, elbow = elbow,
			fArm = fArm, wrist = wrist, hand = hand, claws = claws, side = as,
			smoke = armSmoke,
		})
	end

	-- =========================================================================
	-- PARTÍCULAS - Black fire aura
	-- =========================================================================
	local darkFireAura = Instance.new("ParticleEmitter")
	darkFireAura.Texture = "rbxassetid://243098098"
	darkFireAura.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, CFG.SHADOW_FIRE_CORE),
		ColorSequenceKeypoint.new(0.3, CFG.SHADOW_FIRE),
		ColorSequenceKeypoint.new(0.7, CFG.SHADOW_FIRE_TIP),
		ColorSequenceKeypoint.new(1, CFG.SHADOW_CORE)
	})
	darkFireAura.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, Sc(0.1)),
		NumberSequenceKeypoint.new(0.2, Sc(0.5)),
		NumberSequenceKeypoint.new(0.5, Sc(0.9)),
		NumberSequenceKeypoint.new(1, Sc(1.8))
	})
	darkFireAura.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.3, 0.4),
		NumberSequenceKeypoint.new(0.7, 0.7),
		NumberSequenceKeypoint.new(1, 1)
	})
	darkFireAura.Lifetime = NumberRange.new(0.4, 0.9)
	darkFireAura.Rate = 30
	darkFireAura.Speed = NumberRange.new(0.5, 2.0)
	darkFireAura.SpreadAngle = Vector2.new(30, 360)
	darkFireAura.EmissionDirection = Enum.NormalId.Top
	darkFireAura.Acceleration = Vector3.new(0, 2, 0)
	darkFireAura.RotSpeed = NumberRange.new(-200, 200)
	darkFireAura.Rotation = NumberRange.new(0, 360)
	darkFireAura.Parent = torso

	-- Head dark fire (smaller, more intense)
	local headFire = Instance.new("ParticleEmitter")
	headFire.Texture = "rbxassetid://243098098"
	headFire.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, CFG.SHADOW_FIRE),
		ColorSequenceKeypoint.new(1, CFG.SHADOW_CORE)
	})
	headFire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, Sc(0.05)),
		NumberSequenceKeypoint.new(0.5, Sc(0.3)),
		NumberSequenceKeypoint.new(1, Sc(0.6))
	})
	headFire.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	headFire.Lifetime = NumberRange.new(0.3, 0.6)
	headFire.Rate = 15
	headFire.Speed = NumberRange.new(0.3, 1.0)
	headFire.SpreadAngle = Vector2.new(40, 360)
	headFire.EmissionDirection = Enum.NormalId.Top
	headFire.Parent = head

	-- Ground darkness pool particles
	local groundSmoke = Instance.new("ParticleEmitter")
	groundSmoke.Texture = "rbxassetid://243098098"
	groundSmoke.Color = ColorSequence.new(CFG.SHADOW_CORE)
	groundSmoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, Sc(0.5)),
		NumberSequenceKeypoint.new(1, Sc(3.0))
	})
	groundSmoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1)
	})
	groundSmoke.Lifetime = NumberRange.new(0.6, 1.2)
	groundSmoke.Rate = 12
	groundSmoke.Speed = NumberRange.new(0.05, 0.2)
	groundSmoke.SpreadAngle = Vector2.new(180, 180)
	groundSmoke.EmissionDirection = Enum.NormalId.Top
	groundSmoke.Parent = groundPool

	-- =========================================================================
	-- ESTADO
	-- =========================================================================
	local nX = spawnPos.X
	local nZ = spawnPos.Z
	local nRot = zDir > 0 and 0 or math.pi
	local animT, breathT = 0, 0
	local curState = CFG.ST_IDLE
	local stateT = 0
	local walking = false
	local attacking = false
	local curSpeed = CFG.SPEED_IDLE
	local headTilt, tgtTilt, tiltCD = 0, 0, 0
	local armReach, tgtReach = 0, 0
	local bodySway, swayTgt, swayTimer = 0, 0, 0

	-- Eye visibility state
	local eyeVisible = false
	local eyeTimer = 0
	local eyeShowDuration = 0
	local eyeHideDuration = 0

	-- Attack animation state
	local attackPhase = 0
	local attackArmPitch = 0

	-- Teleport state
	local lastTeleport = 0
	local isTeleporting = false

	local totalH = GY + CFG.SHIN_LEN + CFG.THIGH_LEN + CFG.TORSO_SIZE.Y * 0.3
	-- =========================================================================
	-- LAMP EXTINGUISHING SYSTEM (CORRECTED - re-lights when NPC moves away)
	-- =========================================================================

	-- Replace these two values in CFG:
	-- CFG.LAMP_KILL_RANGE = 25        (distance to extinguish)
	-- CFG.LAMP_RESTORE_RANGE = 40     (distance to restore - must be > KILL_RANGE to avoid flicker)
	-- CFG.LAMP_KILL_SPEED = 0.3       (fade out speed)
	-- CFG.LAMP_RESTORE_SPEED = 1.0    (fade in speed - slower for atmospheric effect)

	-- Add this new config value after LAMP_RESTORE_DELAY in CFG:
	-- LAMP_RESTORE_RANGE = 40,        -- Distance at which lamps re-ignite (hysteresis band)
	-- LAMP_RESTORE_SPEED = 1.0,       -- Seconds to fade a lamp back on

	-- Track extinguished lamps for restoration
	local extinguishedLamps = {}

	local function UpdateLampSystem()
		local pos = Vector3.new(nX, totalH, nZ)
		local killRange = CFG.LAMP_KILL_RANGE
		-- Use a larger restore range to create a hysteresis band
		-- This prevents lamps from flickering on/off at the boundary
		local restoreRange = CFG.LAMP_RESTORE_RANGE or (killRange * 1.6)
		local restoreSpeed = CFG.LAMP_RESTORE_SPEED or 1.0

		-- STEP 1: Find and extinguish lamps that are NOW within kill range
		for _, desc in pairs(workspace:GetDescendants()) do
			if (desc:IsA("PointLight") or desc:IsA("SpotLight") or desc:IsA("SurfaceLight")) then
				local par = desc.Parent
				if par and par:IsA("BasePart") and not par:IsDescendantOf(model) then
					local dd = (par.Position - pos).Magnitude
					local lampKey = tostring(desc:GetFullName())

					if dd < killRange then
						-- Within kill range: extinguish if not already
						if not extinguishedLamps[lampKey] then
							local origBrightness = desc.Brightness
							if origBrightness > 0.05 then
								extinguishedLamps[lampKey] = {
									light = desc,
									originalBrightness = origBrightness,
									parent = par,
									originalParentTransparency = par.Transparency,
									isExtinguished = true,
								}

								-- Fade out the lamp
								TweenService:Create(desc,
									TweenInfo.new(CFG.LAMP_KILL_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
									{ Brightness = 0 }
								):Play()

								-- Also dim any neon bulb parts nearby
								if par.Material == Enum.Material.Neon then
									TweenService:Create(par,
										TweenInfo.new(CFG.LAMP_KILL_SPEED),
										{ Transparency = 0.8 }
									):Play()
								end
							end
						end
					end
				end
			end
		end

		-- STEP 2: Check all extinguished lamps - restore those that are now OUTSIDE restore range
		local lampsToRemove = {}

		for lampKey, lampData in pairs(extinguishedLamps) do
			-- Verify the lamp still exists in the game
			if not lampData.light or not lampData.light.Parent then
				table.insert(lampsToRemove, lampKey)
				continue
			end

			local par = lampData.parent
			if not par or not par.Parent then
				table.insert(lampsToRemove, lampKey)
				continue
			end

			local dd = (par.Position - pos).Magnitude

			-- If the NPC has moved far enough away, restore the lamp
			if dd > restoreRange and lampData.isExtinguished then
				lampData.isExtinguished = false

				-- Fade the lamp back on
				TweenService:Create(lampData.light,
					TweenInfo.new(restoreSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Brightness = lampData.originalBrightness }
				):Play()

				-- Restore neon bulb transparency
				if par.Material == Enum.Material.Neon then
					local origTrans = lampData.originalParentTransparency or 0.15
					TweenService:Create(par,
						TweenInfo.new(restoreSpeed),
						{ Transparency = origTrans }
					):Play()
				end

				-- Mark for removal from tracking after tween completes
				task.delay(restoreSpeed + 0.1, function()
					extinguishedLamps[lampKey] = nil
				end)
			end
		end

		-- Clean up invalid references
		for _, key in ipairs(lampsToRemove) do
			extinguishedLamps[key] = nil
		end
	end

	-- RestoreAllLamps stays the same but now also handles the isExtinguished flag
	local function RestoreAllLamps()
		for _, lampData in pairs(extinguishedLamps) do
			if lampData.light and lampData.light.Parent then
				TweenService:Create(lampData.light,
					TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Brightness = lampData.originalBrightness }
				):Play()

				if lampData.parent and lampData.parent.Parent and lampData.parent.Material == Enum.Material.Neon then
					local origTrans = lampData.originalParentTransparency or 0.15
					TweenService:Create(lampData.parent,
						TweenInfo.new(1.5),
						{ Transparency = origTrans }
					):Play()
				end
			end
		end
		extinguishedLamps = {}
	end

	-- =========================================================================
	-- TRAIL SYSTEM - Leave darkness where it walks
	-- =========================================================================
	local lastTrailPos = Vector3.new(nX, GY, nZ)
	local trailCooldown = 0

	local function LeaveTrail(dt)
		trailCooldown = trailCooldown - dt
		if trailCooldown > 0 then return end
		if not walking then return end

		local curPos = Vector3.new(nX, GY, nZ)
		if (curPos - lastTrailPos).Magnitude < 3 then return end

		trailCooldown = 0.2
		lastTrailPos = curPos

		local trailPart = MkPart("ShadowTrail",
			Vector3.new(Sc(1.2), 0.02, Sc(1.2)),
			CFG.TRAIL_COLOR, Enum.Material.Neon, 0.5, workspace)
		trailPart.CFrame = CFrame.new(nX, GY + 0.02, nZ)

		-- Fade and destroy
		task.spawn(function()
			task.wait(0.5)
			if trailPart and trailPart.Parent then
				TweenService:Create(trailPart,
					TweenInfo.new(2.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Transparency = 1, Size = Vector3.new(Sc(0.3), 0.01, Sc(0.3)) }
				):Play()
				Debris:AddItem(trailPart, 2.5)
			end
		end)
	end

	-- =========================================================================
	-- POSICIONAMIENTO
	-- =========================================================================
	local function UpdatePos(x, z, rot, walk, dt, dist, tgtPos)
		nX, nZ = x, z
		nRot = rot or nRot
		walking = walk or false
		if dt then animT = animT + dt * 5; breathT = breathT + dt * 2 end

		local effDt = dt or 0.016

		-- Eye phasing (appear/disappear)
		if dt then
			eyeTimer = eyeTimer - dt
			if eyeTimer <= 0 then
				eyeVisible = not eyeVisible
				if eyeVisible then
					eyeShowDuration = 0.5 + math.random() * 2.0
					eyeTimer = eyeShowDuration
				else
					eyeHideDuration = 1.0 + math.random() * 4.0
					eyeTimer = eyeHideDuration
				end
			end
		end

		-- Tilt
		if dt then tiltCD = tiltCD - dt end
		if dist and dist < CFG.CHASE_DIST and tiltCD <= 0 then
			if math.random() < 0.03 then
				tgtTilt = (math.random() > 0.5 and 1 or -1) * math.rad(CFG.TILT_MAX * (0.3 + math.random() * 0.5))
				tiltCD = 1.5 + math.random() * 3
			end
		elseif dist and dist > CFG.CHASE_DIST then
			tgtTilt = SmoothLerp(tgtTilt, 0, 1.0, effDt)
		end
		if dt then headTilt = SmoothLerp(headTilt, tgtTilt, CFG.TILT_SPEED, dt) end

		-- Arm reach
		if curState == CFG.ST_IDLE then tgtReach = math.rad(CFG.ARM_IDLE)
		elseif curState == CFG.ST_STALK then tgtReach = math.rad(CFG.ARM_STALK)
		elseif curState == CFG.ST_WALK then tgtReach = math.rad(CFG.ARM_CHASE)
		elseif curState == CFG.ST_CHARGE or curState == CFG.ST_ATTACK then tgtReach = math.rad(CFG.ARM_CHARGE) end
		if dt then armReach = SmoothLerp(armReach, tgtReach, CFG.ARM_SPEED, dt) end

		-- Body sway
		if dt then swayTimer = swayTimer - dt end
		if swayTimer <= 0 then swayTgt = (math.random() - 0.5) * math.rad(5); swayTimer = 2 + math.random() * 4 end
		if dt then bodySway = SmoothLerp(bodySway, swayTgt, 0.8, dt) end

		-- Movement bob (ethereal floating)
		local floatBob = math.sin(animT * 1.5) * Sc(0.08) -- gentle float
		local floatSway = math.sin(animT * 0.7) * Sc(0.03)

		local twX, twY = 0, 0
		if math.random() < CFG.TWITCH_FREQ * effDt * 60 then
			twX = (math.random() - 0.5) * Sc(0.03)
			twY = (math.random() - 0.5) * Sc(0.02)
		end

		local baseY = totalH + floatBob
		local baseCF = CFrame.new(x + floatSway + twX, baseY + twY, z)
			* CFrame.Angles(0, nRot, 0)
			* CFrame.Angles(0, 0, bodySway)

		-- Lean
		local chaseLean = 0
		if curState == CFG.ST_WALK then chaseLean = math.rad(6)
		elseif curState == CFG.ST_CHARGE then chaseLean = math.rad(12) end
		local breathSway = math.sin(breathT * 0.5) * math.rad(2)
		local torsoCF = baseCF * CFrame.Angles(breathSway + chaseLean, 0, 0)

		-- TORSO
		torso.CFrame = torsoCF
		innerGlow.CFrame = torsoCF * CFrame.new(0, 0, -CFG.TORSO_SIZE.Z * 0.1)
		pelvis.CFrame = torsoCF * CFrame.new(0, -CFG.TORSO_SIZE.Y * 0.47, 0)

		-- Body wisps
		for _, w in ipairs(bodyWisps) do
			local driftT = animT * w.speed + w.phase
			local dOff = Vector3.new(
				math.sin(driftT) * w.drift.X,
				math.sin(driftT * 0.7) * w.drift.Y,
				math.cos(driftT * 1.3) * w.drift.Z)
			w.part.CFrame = torsoCF * CFrame.new(w.off + dOff)
			w.part.Transparency = 0.3 + math.sin(driftT * 2) * 0.2
		end

		-- MIST LOWER BODY (replaces legs)
		local mistBase = torsoCF * CFrame.new(0, -CFG.TORSO_SIZE.Y * 0.5, 0)
		for _, ms in ipairs(mistSegments) do
			local frac = ms.frac
			local yOff = -frac * (CFG.THIGH_LEN + CFG.SHIN_LEN) * 0.6
			local xSway = math.sin(animT * 1.5 + ms.phase) * Sc(0.15) * frac
			local zSway = math.cos(animT * 1.2 + ms.phase) * Sc(0.1) * frac
			ms.part.CFrame = mistBase * CFrame.new(xSway + ms.sway * math.sin(animT), yOff, zSway)
			ms.part.Transparency = 0.1 + frac * 0.65 + math.sin(animT * 2 + ms.phase) * 0.1
		end

		-- Ground pool
		groundPool.CFrame = CFrame.new(x, GY + 0.03, z) * CFrame.Angles(0, 0, math.rad(90))
		local poolScale = 1 + math.sin(animT * 2) * 0.15
		groundPool.Size = Vector3.new(Sc(2.0) * poolScale, Sc(0.05), Sc(2.0) * poolScale)

		-- HEAD
		local neckTop = torsoCF * CFrame.new(0, CFG.TORSO_SIZE.Y * 0.48, 0)
		local headCF = neckTop * CFrame.new(0, CFG.HEAD_SIZE.Y * 0.3, 0) * CFrame.Angles(0, 0, headTilt)
		head.CFrame = headCF
		hood.CFrame = headCF * CFrame.new(0, CFG.HEAD_SIZE.Y * 0.15, CFG.HEAD_SIZE.Z * 0.1)

		-- Eyes
		for _, ey in ipairs(eyes) do
			ey.part.CFrame = headCF * CFrame.new(ey.cx, ey.cy, ey.cz)
			local targetTr = eyeVisible and 0.1 or 1
			local targetBr = eyeVisible and (0.3 + math.random() * 0.2) or 0
			ey.part.Transparency = Lerp(ey.part.Transparency, targetTr, math.clamp(effDt * 8, 0, 1))
			ey.light.Brightness = Lerp(ey.light.Brightness, targetBr, math.clamp(effDt * 8, 0, 1))

			-- Flash eyes during attack
			if attackPhase == 2 then
				ey.part.Color = CFG.EYE_FLASH
				ey.light.Color = CFG.EYE_FLASH
				ey.part.Transparency = 0
				ey.light.Brightness = 1.0
			else
				ey.part.Color = CFG.EYE_COLOR
				ey.light.Color = CFG.EYE_COLOR
			end
		end

		-- Head wisps
		for _, hw in ipairs(headWisps) do
			local wAngle = hw.angle + animT * hw.speed * 0.3
			local wLen = hw.baseLen * (1 + math.sin(animT * hw.speed + hw.phase) * 0.3)
			local wX = math.cos(wAngle) * CFG.HEAD_SIZE.X * 0.5
			local wZ = math.sin(wAngle) * CFG.HEAD_SIZE.Z * 0.5
			hw.part.Size = Vector3.new(Sc(0.03), wLen, Sc(0.03))
			hw.part.CFrame = headCF
				* CFrame.new(wX, CFG.HEAD_SIZE.Y * 0.3, wZ)
				* CFrame.Angles(math.sin(animT * hw.speed) * math.rad(30), 0, math.cos(animT * hw.speed) * math.rad(20))
			hw.part.Transparency = 0.2 + math.sin(animT * 3 + hw.phase) * 0.2
		end

		-- ARMS
		for _, arm in ipairs(arms) do
			local ph = arm.side == -1 and 0 or math.pi
			local wSwing = walking and math.sin(animT + ph) * math.rad(10) or 0
			local iSway = math.sin(animT * 0.4 + arm.side * 0.7) * math.rad(3)

			local shX = arm.side * (CFG.TORSO_SIZE.X * 0.42)
			local shY = CFG.TORSO_SIZE.Y * 0.36
			local shCF = torsoCF * CFrame.new(shX, shY, 0)
			arm.shoulder.CFrame = shCF

			local rPitch = 0
			local fBend = math.rad(-15)
			local aOut = arm.side * math.rad(6)

			if attackPhase > 0 then
				rPitch = attackArmPitch
				fBend = math.rad(-8)
				aOut = arm.side * math.rad(10)
				wSwing = 0; iSway = 0
			elseif curState == CFG.ST_WALK or curState == CFG.ST_CHARGE then
				rPitch = -armReach
				fBend = Lerp(math.rad(-15), math.rad(-5), armReach / math.rad(70))
				aOut = arm.side * Lerp(math.rad(6), math.rad(14), armReach / math.rad(70))
				wSwing = wSwing * (1 - armReach / math.rad(70) * 0.6)
			else
				rPitch = -armReach + iSway
				fBend = math.rad(-15) - math.abs(wSwing) * 0.3
			end

			local uaCF = shCF * CFrame.Angles(rPitch + wSwing, 0, aOut) * CFrame.new(0, -CFG.U_ARM_LEN * 0.5, 0)
			arm.uArm.CFrame = uaCF

			local elbCF = uaCF * CFrame.new(0, -CFG.U_ARM_LEN * 0.5, 0)
			arm.elbow.CFrame = elbCF

			local faCF = elbCF * CFrame.Angles(fBend, 0, 0) * CFrame.new(0, -CFG.F_ARM_LEN * 0.5, 0)
			arm.fArm.CFrame = faCF

			local wrCF = faCF * CFrame.new(0, -CFG.F_ARM_LEN * 0.5, 0)
			arm.wrist.CFrame = wrCF

			local hCurl = math.rad(5) + iSway * 0.5
			if attackPhase == 2 then hCurl = math.rad(30) end
			if armReach > math.rad(30) then hCurl = hCurl + math.rad(12) end
			local haCF = wrCF * CFrame.Angles(hCurl, 0, 0) * CFrame.new(0, -CFG.HAND_SIZE.Y * 0.3, 0)
			arm.hand.CFrame = haCF

			-- Claws
			local bCurl = math.rad(20)
			if attackPhase == 1 then bCurl = math.rad(5)
			elseif attackPhase == 2 then bCurl = math.rad(50)
			elseif attackPhase == 3 then bCurl = math.rad(28) end
			if armReach > math.rad(35) then bCurl = math.rad(8) end

			for _, claw in ipairs(arm.claws) do
				local fCurl = bCurl + math.sin(breathT * 1.8 + claw.curlPh) * math.rad(4)
				local fTw = math.sin(animT * 3 + claw.twitchPh) * math.rad(2)
				local fSpread = (claw.idx - 3) * math.rad(10)
				if armReach > math.rad(30) or attackPhase == 1 then fSpread = fSpread * 1.6 end

				local fbX = claw.xo
				if claw.thumb then fbX = arm.side * CFG.HAND_SIZE.X * 0.35 end

				local pCF = haCF * CFrame.new(fbX, -CFG.HAND_SIZE.Y * 0.25, -Sc(0.01)) * CFrame.Angles(0, fSpread, 0)
				for si, sg in ipairs(claw.segs) do
					local sc = fCurl * (0.22 + si * 0.20) + fTw
					if claw.thumb then sc = sc * 0.45 end
					sg.joint.CFrame = pCF
					local sCF = pCF * CFrame.Angles(sc, 0, 0) * CFrame.new(0, -sg.h * 0.5, 0)
					sg.part.CFrame = sCF
					pCF = sCF * CFrame.new(0, -sg.h * 0.5, 0)
				end
				claw.tip.CFrame = pCF * CFrame.Angles(math.rad(25), 0, 0) * CFrame.new(0, -Sc(0.04), 0)
			end
		end

		-- Lamp extinguishing
		if dt then UpdateLampSystem() end

		-- Trail
		if dt then LeaveTrail(dt) end
	end

	UpdatePos(nX, nZ, nRot, false, 0.016, 999, nil)

	-- =========================================================================
	-- SONIDOS
	-- =========================================================================
	local ambientSnd = Instance.new("Sound")
	ambientSnd.SoundId = "rbxassetid://"
	ambientSnd.Volume = 0.2; ambientSnd.Looped = true; ambientSnd.PlaybackSpeed = 0.15
	ambientSnd.Parent = head; ambientSnd:Play()

	local whisperSnd = Instance.new("Sound")
	whisperSnd.SoundId = "rbxassetid://105646873561926"
	whisperSnd.Volume = 0.15; whisperSnd.Looped = true; whisperSnd.PlaybackSpeed = 0.3
	whisperSnd.Parent = torso; whisperSnd:Play()

	-- =========================================================================
	-- TELEPORT SYSTEM
	-- =========================================================================
	local function TeleportBehindPlayer(player)
		if isTeleporting then return end
		if tick() - lastTeleport < CFG.TELEPORT_CD then return end

		local ch = player.Character
		if not ch then return end
		local hrp = ch:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		isTeleporting = true
		lastTeleport = tick()

		-- Teleport out effect (fade to invisible)
		local fadeOutDur = 0.3
		for _, desc in pairs(model:GetDescendants()) do
			if desc:IsA("BasePart") then
				TweenService:Create(desc,
					TweenInfo.new(fadeOutDur),
					{ Transparency = 1 }
				):Play()
			end
		end
		darkFireAura.Rate = 80 -- burst of particles

		-- Teleport sound
		local tpSnd = Instance.new("Sound")
		tpSnd.SoundId = "rbxassetid://9114221580"
		tpSnd.Volume = 0.5; tpSnd.PlaybackSpeed = 2.0
		tpSnd.Parent = head; tpSnd:Play()
		Debris:AddItem(tpSnd, 2)

		task.wait(fadeOutDur)

		-- Calculate position behind player
		local lookDir = hrp.CFrame.LookVector
		local behindPos = hrp.Position - lookDir * CFG.TELEPORT_BEHIND_DIST
		local newX = behindPos.X
		local newZ = behindPos.Z

		-- Don't teleport into lobby
		if InLobby(newX) then
			isTeleporting = false
			darkFireAura.Rate = 30
			return
		end

		nX = newX
		nZ = newZ
		nRot = math.atan2(-(hrp.Position.X - nX), -(hrp.Position.Z - nZ))

		-- Leave shadow residue at old position
		local residue = MkPart("ShadowResidue",
			Vector3.new(Sc(2), Sc(3), Sc(0.5)),
			CFG.SHADOW_CORE, Enum.Material.Neon, 0.3, workspace)
		residue.CFrame = CFrame.new(nX, totalH, nZ) * CFrame.Angles(0, nRot, 0)
		task.spawn(function()
			task.wait(0.5)
			if residue and residue.Parent then
				TweenService:Create(residue, TweenInfo.new(1.5), { Transparency = 1 }):Play()
				Debris:AddItem(residue, 2)
			end
		end)

		task.wait(0.15)

		-- Teleport in effect (fade back)
		darkFireAura.Rate = 30
		UpdatePos(nX, nZ, nRot, false, 0.016, nil, nil)

		for _, desc in pairs(model:GetDescendants()) do
			if desc:IsA("BasePart") and not desc.Name:find("Eye") then
				local origTr = 0
				if desc.Name:find("Mist") then origTr = 0.1 + (tonumber(desc.Name:match("%d+")) or 1) / CFG.MIST_SEGMENTS * 0.65 end
				if desc.Name:find("Wisp") then origTr = 0.3 end
				if desc.Name:find("Joint") or desc.Name:find("Shoulder") or desc.Name:find("Elbow") or desc.Name:find("Wrist") then origTr = 0.2 end
				TweenService:Create(desc,
					TweenInfo.new(0.2),
					{ Transparency = origTr }
				):Play()
			end
		end

		-- Arrive sound
		local arrSnd = Instance.new("Sound")
		arrSnd.SoundId = "rbxassetid://5766332557"
		arrSnd.Volume = 0.4; arrSnd.PlaybackSpeed = 0.4
		arrSnd.Parent = head; arrSnd:Play()
		Debris:AddItem(arrSnd, 2)

		task.wait(0.3)
		isTeleporting = false
	end

	-- =========================================================================
	-- ATAQUES
	-- =========================================================================
	local lastAtk = 0
	local lastTendril = -CFG.CD_TENDRIL
	local lastBurst = -CFG.CD_BURST

	-- Shadow Claw Attack (fast swipe)
	local function ShadowClawAttack(player)
		if tick() - lastAtk < CFG.CD_ATTACK or attacking then return end
		lastAtk = tick(); attacking = true
		local ch = player.Character
		if not ch then attacking = false return end
		local hum, hrp = ch:FindFirstChild("Humanoid"), ch:FindFirstChild("HumanoidRootPart")
		if not (hum and hum.Health > 0 and hrp) then attacking = false return end

		-- WINDUP
		attackPhase = 1
		local startTime = tick()
		while tick() - startTime < CFG.ATTACK_WINDUP do
			local progress = (tick() - startTime) / CFG.ATTACK_WINDUP
			attackArmPitch = Lerp(0, math.rad(-140), progress * progress)
			task.wait()
		end
		attackArmPitch = math.rad(-140)

		-- SWING
		attackPhase = 2
		local hitSnd = Instance.new("Sound")
		hitSnd.SoundId = "rbxassetid://5766332557"; hitSnd.Volume = 0.8; hitSnd.PlaybackSpeed = 1.5
		hitSnd.Parent = head; hitSnd:Play()

		startTime = tick()
		while tick() - startTime < CFG.ATTACK_SWING do
			local progress = (tick() - startTime) / CFG.ATTACK_SWING
			attackArmPitch = Lerp(math.rad(-140), math.rad(25), 1 - (1 - progress) * (1 - progress))
			task.wait()
		end
		attackArmPitch = math.rad(25)

		-- DAMAGE
		if hum and hum.Parent and hum.Health > 0 and hrp then
			local distToTarget = (hrp.Position - Vector3.new(nX, hrp.Position.Y, nZ)).Magnitude
			if distToTarget < CFG.ATTACK_RANGE + 2 then
				hum:TakeDamage(CFG.DMG_CLAW)
			end
		end

		-- RECOVER
		attackPhase = 3
		startTime = tick()
		while tick() - startTime < CFG.ATTACK_RECOVER do
			local progress = (tick() - startTime) / CFG.ATTACK_RECOVER
			attackArmPitch = Lerp(math.rad(25), 0, progress)
			task.wait()
		end

		attackArmPitch = 0
		attackPhase = 0
		Debris:AddItem(hitSnd, 2)
		attacking = false
	end

	-- Tendril Grab (shadow tendrils from ground)
	local function TendrilAttack(player)
		if tick() - lastTendril < CFG.CD_TENDRIL or attacking then return end
		lastTendril = tick(); attacking = true
		local ch = player.Character
		if not ch then attacking = false return end
		local hum, hrp = ch:FindFirstChild("Humanoid"), ch:FindFirstChild("HumanoidRootPart")
		if not (hum and hum.Health > 0 and hrp) then attacking = false return end

		if (hrp.Position - Vector3.new(nX, hrp.Position.Y, nZ)).Magnitude > CFG.TENDRIL_RANGE then
			attacking = false return
		end

		-- Create shadow tendrils at player's feet
		local tSnd = Instance.new("Sound")
		tSnd.SoundId = "rbxassetid://9114221580"; tSnd.Volume = 0.6; tSnd.PlaybackSpeed = 0.5
		tSnd.Parent = head; tSnd:Play()

		local tendrils = {}
		local targetPos = hrp.Position
		for i = 1, 5 do
			local angle = (i / 5) * math.pi * 2
			local dist = Sc(1.5)
			local tX = targetPos.X + math.cos(angle) * dist
			local tZ = targetPos.Z + math.sin(angle) * dist

			local tendril = MkPart("Tendril" .. i,
				Vector3.new(Sc(0.08), Sc(0.1), Sc(0.08)),
				CFG.TENDRIL_COLOR, Enum.Material.Neon, 0.3, workspace)
			tendril.CFrame = CFrame.new(tX, GY, tZ)
			table.insert(tendrils, tendril)
		end

		-- Animate tendrils rising
		for step = 1, 15 do
			local progress = step / 15
			for _, t in ipairs(tendrils) do
				local h = Sc(3.0) * progress
				t.Size = Vector3.new(Sc(0.08), h, Sc(0.08))
				t.CFrame = CFrame.new(t.Position.X, GY + h / 2, t.Position.Z)
			end
			task.wait(0.02)
		end

		-- Damage
		if hum and hum.Parent and hum.Health > 0 and hrp then
			local distToTarget = (hrp.Position - targetPos).Magnitude
			if distToTarget < 4 then
				hum:TakeDamage(CFG.DMG_TENDRIL)
				-- Brief slow
				local oS = hum.WalkSpeed
				hum.WalkSpeed = 4
				task.delay(0.8, function()
					if hum and hum.Parent then hum.WalkSpeed = oS end
				end)
			end
		end

		-- Fade tendrils
		task.wait(0.3)
		for _, t in ipairs(tendrils) do
			TweenService:Create(t, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			Debris:AddItem(t, 1)
		end

		Debris:AddItem(tSnd, 3)
		task.wait(0.2)
		attacking = false
	end

	-- Darkness Burst (AOE darkness explosion)
	local function DarknessBurst(player)
		if tick() - lastBurst < CFG.CD_BURST or attacking then return end
		lastBurst = tick(); attacking = true
		local ch = player.Character
		if not ch then attacking = false return end
		local hum, hrp = ch:FindFirstChild("Humanoid"), ch:FindFirstChild("HumanoidRootPart")
		if not (hum and hum.Health > 0 and hrp) then attacking = false return end

		-- Charge up (draw in darkness)
		local chargeSnd = Instance.new("Sound")
		chargeSnd.SoundId = "rbxassetid://9114221580"; chargeSnd.Volume = 0.7; chargeSnd.PlaybackSpeed = 0.3
		chargeSnd.Parent = head; chargeSnd:Play()

		darkFireAura.Rate = 80
		for _, ey in ipairs(eyes) do
			ey.part.Transparency = 0
			ey.light.Brightness = 1.5
			ey.part.Color = CFG.EYE_FLASH
			ey.light.Color = CFG.EYE_FLASH
		end

		task.wait(0.6)

		-- BURST
		local burstSnd = Instance.new("Sound")
		burstSnd.SoundId = "rbxassetid://5766332557"; burstSnd.Volume = 1.0; burstSnd.PlaybackSpeed = 0.6
		burstSnd.Parent = head; burstSnd:Play()

		-- Visual burst sphere
		local burstPart = MkPart("DarkBurst",
			Vector3.new(Sc(0.5), Sc(0.5), Sc(0.5)),
			CFG.SHADOW_FIRE, Enum.Material.Neon, 0.2, workspace)
		burstPart.Shape = Enum.PartType.Ball
		burstPart.CFrame = CFrame.new(nX, totalH, nZ)

		TweenService:Create(burstPart,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(Sc(16), Sc(16), Sc(16)), Transparency = 1 }
		):Play()
		Debris:AddItem(burstPart, 1)

		-- Damage all nearby players
		for _, pl in pairs(Players:GetPlayers()) do
			local pCh = pl.Character
			if pCh then
				local pHrp = pCh:FindFirstChild("HumanoidRootPart")
				local pHum = pCh:FindFirstChild("Humanoid")
				if pHrp and pHum and pHum.Health > 0 then
					local d = (pHrp.Position - Vector3.new(nX, pHrp.Position.Y, nZ)).Magnitude
					if d < Sc(8) then
						pHum:TakeDamage(CFG.DMG_BURST)
					end
				end
			end
		end

		darkFireAura.Rate = 30
		for _, ey in ipairs(eyes) do
			ey.part.Color = CFG.EYE_COLOR
			ey.light.Color = CFG.EYE_COLOR
		end

		Debris:AddItem(chargeSnd, 3)
		Debris:AddItem(burstSnd, 3)
		task.wait(0.5)
		attacking = false
	end

	-- =========================================================================
	-- MUERTE
	-- =========================================================================
	local function DeathEffect()
		darkFireAura.Enabled = false
		headFire.Enabled = false
		groundSmoke.Enabled = false
		ambientSnd:Stop(); whisperSnd:Stop()

		-- Death scream
		local snd = Instance.new("Sound")
		snd.SoundId = "rbxassetid://72245886498891"; snd.Volume = 1.0; snd.PlaybackSpeed = 0.4
		snd.Parent = head; snd:Play()

		-- Eye flash on death
		for _, ey in ipairs(eyes) do
			ey.part.Transparency = 0
			ey.light.Brightness = 2.0
			ey.part.Color = CFG.EYE_FLASH
		end

		task.wait(0.5)

		-- Dissolve into shadow
		for _, p in pairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				task.delay(math.random() * 0.3, function()
					TweenService:Create(p, TweenInfo.new(1.0 + math.random() * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Transparency = 1,
						Position = p.Position + Vector3.new((math.random() - 0.5) * Sc(0.5), Sc(1.5), (math.random() - 0.5) * Sc(0.5)),
						Color = CFG.SHADOW_CORE,
					}):Play()
				end)
			end
		end

		-- Restore lamps after delay
		task.delay(CFG.LAMP_RESTORE_DELAY, function()
			RestoreAllLamps()
		end)

		task.wait(1.5)
		Debris:AddItem(snd, 3)
	end

	-- =========================================================================
	-- IA
	-- =========================================================================
	local alive = true
	local lastSeen = nil
	local lastFootT = 0

	local function FindTarget()
		local best, bestD = nil, CFG.DETECT_RANGE
		for _, pl in pairs(Players:GetPlayers()) do
			local ch = pl.Character
			if ch then
				local hrp, hum = ch:FindFirstChild("HumanoidRootPart"), ch:FindFirstChild("Humanoid")
				if hrp and hum and hum.Health > 0 then
					local d = (hrp.Position - Vector3.new(nX, 0, nZ)).Magnitude
					if d < bestD and not InLobby(hrp.Position.X) then bestD = d; best = pl end
				end
			end
		end
		return best, bestD
	end

	local function SetState(st)
		if curState == st then return end
		curState = st; stateT = 0
		if st == CFG.ST_IDLE then curSpeed = CFG.SPEED_IDLE
		elseif st == CFG.ST_STALK then curSpeed = CFG.SPEED_STALK
		elseif st == CFG.ST_WALK then curSpeed = CFG.SPEED_WALK
		elseif st == CFG.ST_CHARGE then curSpeed = CFG.SPEED_CHARGE
		elseif st == CFG.ST_ATTACK then curSpeed = 0
		elseif st == CFG.ST_TELEPORT then curSpeed = 0 end
	end

	local function MoveToward(targetPos, speed, dt2, dist2, tgtP2)
		local dir = Vector3.new(targetPos.X - nX, 0, targetPos.Z - nZ)
		if dir.Magnitude > 0.5 then
			local look = math.atan2(-dir.X, -dir.Z)
			local smoothRot = LerpAng(nRot, look, math.clamp(dt2 * 6, 0, 1))
			local mv = dir.Unit
			local nx = nX + mv.X * speed * dt2
			local nz = nZ + mv.Z * speed * dt2
			if not InLobby(nx) then UpdatePos(nx, nz, smoothRot, true, dt2, dist2, tgtP2)
			else UpdatePos(nX, nZ, smoothRot, false, dt2, dist2, tgtP2) end
		end
	end

	-- =========================================================================
	-- HEARTBEAT
	-- =========================================================================
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not alive or not torso or not torso.Parent then
			if conn then conn:Disconnect() end; return
		end
		if tick() - t0 >= npcLife then
			alive = false; if conn then conn:Disconnect() end
			DeathEffect(); task.wait(1.5)
			if folder and folder.Parent then folder:Destroy() end; return
		end
		if model:GetAttribute("Stunned") then UpdatePos(nX, nZ, nRot, false, dt, 999, nil); return end
		if InLobby(nX) then
			alive = false; if conn then conn:Disconnect() end
			DeathEffect(); task.wait(1.5)
			if folder and folder.Parent then folder:Destroy() end; return
		end
		if isTeleporting then return end

		stateT = stateT + dt
		local tgt, dist = FindTarget()
		local tgtP = nil
		if tgt and tgt.Character then
			local hrp = tgt.Character:FindFirstChild("HumanoidRootPart")
			if hrp then tgtP = hrp.Position; lastSeen = tgtP end
		end

		if curState == CFG.ST_IDLE then
			if tgt and dist < CFG.STALK_DIST then SetState(CFG.ST_STALK)
			elseif tgt and dist < CFG.DETECT_RANGE and tgtP then
				local dir = Vector3.new(tgtP.X - nX, 0, tgtP.Z - nZ)
				if dir.Magnitude > 1 then nRot = LerpAng(nRot, math.atan2(-dir.X, -dir.Z), dt * 0.5) end
				UpdatePos(nX, nZ, nRot, false, dt, dist, tgtP)
				if stateT > 3 then SetState(CFG.ST_STALK) end
			else
				if stateT > 5 then nRot = nRot + (math.random() - 0.5) * math.rad(120); stateT = 0 end
				UpdatePos(nX, nZ, nRot, false, dt, dist, tgtP)
			end

		elseif curState == CFG.ST_STALK then
			if tgt and dist < CFG.CHASE_DIST then SetState(CFG.ST_WALK)
			elseif tgtP then MoveToward(tgtP, curSpeed, dt, dist, tgtP)
			elseif lastSeen then
				local dir = Vector3.new(lastSeen.X - nX, 0, lastSeen.Z - nZ)
				if dir.Magnitude > 2 then MoveToward(lastSeen, curSpeed, dt, dist or 999, nil)
				else lastSeen = nil; SetState(CFG.ST_IDLE) end
			else SetState(CFG.ST_IDLE) end

		elseif curState == CFG.ST_WALK then
			-- Chance to teleport
			if tgt and not attacking and math.random() < CFG.TELEPORT_CHANCE then
				coroutine.wrap(function() TeleportBehindPlayer(tgt) end)()
			end

			if tgt and dist < CFG.CHARGE_DIST then SetState(CFG.ST_CHARGE)
			elseif tgt and tgtP then
				if dist <= CFG.ATTACK_RANGE then
					local dir = Vector3.new(tgtP.X - nX, 0, tgtP.Z - nZ)
					UpdatePos(nX, nZ, math.atan2(-dir.X, -dir.Z), false, dt, dist, tgtP)
					-- Choose attack
					if tick() - lastTendril >= CFG.CD_TENDRIL and math.random() < 0.25 then
						coroutine.wrap(function() TendrilAttack(tgt) end)()
					else
						coroutine.wrap(function() ShadowClawAttack(tgt) end)()
					end
				else MoveToward(tgtP, curSpeed, dt, dist, tgtP) end
			else SetState(CFG.ST_STALK) end

		elseif curState == CFG.ST_CHARGE then
			-- Higher teleport chance when charging
			if tgt and not attacking and math.random() < CFG.TELEPORT_CHARGE_CHANCE then
				coroutine.wrap(function() TeleportBehindPlayer(tgt) end)()
			end

			if tgt and tgtP then
				local dir = Vector3.new(tgtP.X - nX, 0, tgtP.Z - nZ)
				if dist <= CFG.ATTACK_RANGE then
					UpdatePos(nX, nZ, math.atan2(-dir.X, -dir.Z), false, dt, dist, tgtP)
					-- Darkness burst when close enough and cooldown ready
					if tick() - lastBurst >= CFG.CD_BURST and math.random() < 0.15 then
						coroutine.wrap(function() DarknessBurst(tgt) end)()
					elseif tick() - lastTendril >= CFG.CD_TENDRIL and math.random() < 0.3 then
						coroutine.wrap(function() TendrilAttack(tgt) end)()
					else
						coroutine.wrap(function() ShadowClawAttack(tgt) end)()
					end
				elseif dist <= CFG.TENDRIL_RANGE and tick() - lastTendril >= CFG.CD_TENDRIL and math.random() < 0.05 then
					coroutine.wrap(function() TendrilAttack(tgt) end)()
					MoveToward(tgtP, curSpeed, dt, dist, tgtP)
				else
					local spd = curSpeed
					if math.random() < 0.06 then spd = CFG.SPEED_BURST end
					MoveToward(tgtP, spd, dt, dist, tgtP)
				end
			else SetState(CFG.ST_WALK) end

		elseif curState == CFG.ST_ATTACK then
			UpdatePos(nX, nZ, nRot, false, dt, dist, tgtP)
			if not attacking then
				if tgt and dist and dist < CFG.CHARGE_DIST then SetState(CFG.ST_CHARGE)
				elseif tgt then SetState(CFG.ST_WALK)
				else SetState(CFG.ST_IDLE) end
			end
		end
	end)

	-- =========================================================================
	-- AMBIENTALES
	-- =========================================================================
	-- Random whisper sounds
	coroutine.wrap(function()
		while alive and head and head.Parent do
			task.wait(math.random(5, 15))
			if alive then
				local w = Instance.new("Sound")
				w.SoundId = "rbxassetid://80126562543070"; w.Volume = 0.12; w.PlaybackSpeed = 0.2 + math.random() * 0.15
				w.Parent = head; w:Play(); Debris:AddItem(w, 4)
			end
		end
	end)()

	-- Random body sway/twitch
	coroutine.wrap(function()
		while alive and torso and torso.Parent do
			task.wait(math.random(6, 18))
			if alive then
				swayTgt = (math.random() > 0.5 and 1 or -1) * math.rad(6 + math.random() * 4)
				task.wait(0.06 + math.random() * 0.04); swayTgt = 0
			end
		end
	end)()

	-- Random teleport while stalking
	coroutine.wrap(function()
		while alive and torso and torso.Parent do
			task.wait(math.random(8, 20))
			if alive and curState == CFG.ST_STALK then
				local tgt = FindTarget()
				if tgt and not attacking and not isTeleporting then
					TeleportBehindPlayer(tgt)
				end
			end
		end
	end)()

	-- Cleanup
	folder.AncestryChanged:Connect(function()
		if not folder.Parent then
			alive = false; ambientSnd:Stop(); whisperSnd:Stop()
			if conn then conn:Disconnect() end
			RestoreAllLamps()
		end
	end)

	return folder
end

-- -------------------------------------------------------------------------------
-- LISTENER
-- -------------------------------------------------------------------------------
if SpawnShadowManEvent then
	SpawnShadowManEvent.Event:Connect(function(pos, player, side, zDir, doorInfo, lifetime)
		print("SpawnShadowManEvent received - Lifetime:", tostring(lifetime))
		task.wait(0.2)
		CreateShadowManNPC(pos, player, side, zDir, doorInfo, lifetime)
	end)
end

print("=== THE SHADOW MAN V1.0 - LIVING SHADOW ===")
print("  Pure black shadow entity")
print("  Black fire aura")
print("  Extinguishes street lamps")
print("  Teleports behind players")
print("  Attacks: Shadow Claw, Tendril Grab, Darkness Burst")
print("  Eyes phase in/out")
print("  Scale:", S .. "x")
print("=============================================")