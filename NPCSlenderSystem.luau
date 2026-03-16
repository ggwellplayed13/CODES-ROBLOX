--[[
    +------------------------------------------------------------------------------+
    |                    HUMANOID HORROR ENTITY SYSTEM                              |
    |                 "THE SLENDER" - NPC FÍSICO v3.1                               |
    |                      EXTREMIDADES SIN GAPS                                    |
    +------------------------------------------------------------------------------+
    
    CAMBIOS CLAVE v3.1:
    - Movimientos suavizados: menos twitches aleatorios, freeze reducido
    - Brazos se extienden hacia el jugador durante persecución
    - Ataque de doble brazo: sube ambos brazos y los baja golpeando
    - Sin knockback que levante al jugador, solo daño directo
    - Animación de ataque visible con timing correcto
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local SpawnSlenderEvent = ReplicatedStorage:FindFirstChild("SpawnSlenderEvent")
if not SpawnSlenderEvent then
	SpawnSlenderEvent = Instance.new("BindableEvent")
	SpawnSlenderEvent.Name = "SpawnSlenderEvent"
	SpawnSlenderEvent.Parent = ReplicatedStorage
end

-- -------------------------------------------------------------------------------
-- CONFIGURACIÓN
-- -------------------------------------------------------------------------------
local CFG = {
	SCALE = 1.6,

	SPEED_IDLE = 0,
	SPEED_STALK = 12,
	SPEED_WALK = 24,
	SPEED_CHARGE = 36,
	SPEED_BURST = 40,

	DETECT_RANGE = 280,
	STALK_DIST = 120,
	CHASE_DIST = 60,
	CHARGE_DIST = 30,
	ATTACK_RANGE = 9,
	LUNGE_RANGE = 16,

	DMG_CLAW = 35,
	DMG_GRAB = 50,
	DMG_LUNGE = 60,
	CD_ATTACK = 0.7,
	CD_LUNGE = 8,
	CD_GRAB = 12,

	SKIN = Color3.fromRGB(190, 182, 174),
	SKIN_MID = Color3.fromRGB(175, 168, 162),
	SKIN_DARK = Color3.fromRGB(150, 143, 138),
	SKIN_SHADOW = Color3.fromRGB(125, 120, 115),
	SKIN_VEIN = Color3.fromRGB(155, 135, 150),
	MOUTH_VOID = Color3.fromRGB(15, 8, 12),
	MOUTH_DEEP = Color3.fromRGB(5, 2, 5),
	TEETH = Color3.fromRGB(240, 235, 225),
	TEETH_SHARP = Color3.fromRGB(230, 220, 200),
	GUM = Color3.fromRGB(50, 25, 35),
	LIP = Color3.fromRGB(100, 70, 80),
	LIP_CRACK = Color3.fromRGB(70, 45, 55),
	EYE_VOID = Color3.fromRGB(3, 2, 3),
	EYE_EDGE = Color3.fromRGB(25, 20, 23),
	EYE_DEEP = Color3.fromRGB(8, 5, 8),
	NAIL = Color3.fromRGB(20, 15, 12),
	AURA = Color3.fromRGB(10, 5, 15),
	AURA_IN = Color3.fromRGB(25, 15, 35),

	HEAD = Vector3.new(0.65, 0.85, 0.65),
	TORSO = Vector3.new(0.55, 2.4, 0.30),
	PELVIS = Vector3.new(0.50, 0.45, 0.28),

	U_ARM_LEN = 1.8,
	U_ARM_THICK = 0.16,
	F_ARM_LEN = 2.1,
	F_ARM_THICK = 0.13,

	HAND = Vector3.new(0.50, 0.16, 0.58),
	FINGER_LEN = 0.75,
	FINGER_SEGS = 4,

	THIGH_LEN = 2.0,
	THIGH_THICK = 0.20,
	SHIN_LEN = 2.3,
	SHIN_THICK = 0.16,

	FOOT = Vector3.new(0.18, 0.12, 0.45),
	NECK_LEN = 0.50,
	NECK_SEGS = 3,
	SMILE_W = 0.85,
	SMILE_W_MAX = 1.5,
	SMILE_H = 0.25,
	TEETH_N = 16,

	JOINT_SCALE = 1.4,

	-- Reducidos para menos bugs visuales
	TWITCH_FREQ = 0.08,        -- era 0.35, mucho menos twitch
	FREEZE_CHANCE = 0.02,      -- era 0.15, casi nunca se congela
	TILT_MAX = 45,             -- era 90, menos extremo
	TILT_SPEED = 2.5,          -- era 3.5, más suave
	SMILE_SPEED = 2.5,
	DARK_RANGE = 25,
	DIM_AMT = 0.7,
	CRACK_CHANCE = 0.35,
	SCREAM_CHANCE = 0.15,
	SUDDEN_CHANCE = 0.08,

	ARM_IDLE = 0,
	ARM_STALK = 15,
	ARM_CHASE = 55,
	ARM_CHARGE = 80,
	ARM_SPEED = 3.0,

	ST_IDLE = 1,
	ST_STALK = 2,
	ST_WALK = 3,
	ST_CHARGE = 4,
	ST_ATTACK = 5,

	LOBBY_MIN_X = -75,
	LOBBY_MAX_X = 75,

	-- NUEVO: Parámetros de ataque animado
	ATTACK_WINDUP = 0.3,       -- tiempo subiendo brazos
	ATTACK_SWING = 0.15,       -- tiempo bajando brazos (rápido)
	ATTACK_RECOVER = 0.25,     -- tiempo recuperándose
}

local S = CFG.SCALE
local function Sc(v) return v * S end

CFG.HEAD = CFG.HEAD * S
CFG.TORSO = CFG.TORSO * S
CFG.PELVIS = CFG.PELVIS * S
CFG.HAND = CFG.HAND * S
CFG.FOOT = CFG.FOOT * S
CFG.U_ARM_LEN = CFG.U_ARM_LEN * S
CFG.U_ARM_THICK = CFG.U_ARM_THICK * S
CFG.F_ARM_LEN = CFG.F_ARM_LEN * S
CFG.F_ARM_THICK = CFG.F_ARM_THICK * S
CFG.THIGH_LEN = CFG.THIGH_LEN * S
CFG.THIGH_THICK = CFG.THIGH_THICK * S
CFG.SHIN_LEN = CFG.SHIN_LEN * S
CFG.SHIN_THICK = CFG.SHIN_THICK * S
CFG.NECK_LEN = CFG.NECK_LEN * S
CFG.FINGER_LEN = CFG.FINGER_LEN * S
CFG.SMILE_W = CFG.SMILE_W * S
CFG.SMILE_W_MAX = CFG.SMILE_W_MAX * S
CFG.SMILE_H = CFG.SMILE_H * S

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
	local d = thickness * CFG.JOINT_SCALE
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

-- Smooth lerp que nunca salta (clamp dt)
local function SmoothLerp(a, b, speed, dt)
	local t = math.clamp(speed * dt, 0, 1)
	return Lerp(a, b, t)
end

-- -------------------------------------------------------------------------------
-- CREACIÓN DEL NPC
-- -------------------------------------------------------------------------------
local function CreateSlenderNPC(spawnPos, triggerPlayer, side, zDir, doorFrameInfo, lifetime)
	local npcLife = (lifetime and lifetime > 0) and lifetime or 55

	print("========= THE SLENDER V3.1 SPAWNED =========")
	print("  Scale:", S, " Lifetime:", npcLife)

	local folder = Instance.new("Folder")
	folder.Name = "SlenderEntity"
	folder.Parent = workspace

	local model = Instance.new("Model")
	model.Name = "TheSlender"
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

	-- =========================================================================
	-- TORSO
	-- =========================================================================
	local torso = MkPart("Torso", CFG.TORSO, CFG.SKIN, nil, 0, model)
	torso.CanCollide = true
	MkMesh(torso, Enum.MeshType.Sphere, Vector3.new(0.85, 1, 0.55))

	local chest = MkPart("Chest",
		Vector3.new(CFG.TORSO.X * 0.75, CFG.TORSO.Y * 0.45, CFG.TORSO.Z * 0.35),
		CFG.SKIN, nil, 0, model)
	MkMesh(chest, Enum.MeshType.Sphere, Vector3.new(1, 0.9, 0.5))

	local pelvis = MkPart("Pelvis", CFG.PELVIS, CFG.SKIN, nil, 0, model)
	MkMesh(pelvis, Enum.MeshType.Sphere, Vector3.new(1, 0.8, 0.9))

	local ribs = {}
	for i = 1, 8 do
		for rs = -1, 1, 2 do
			local rw = (0.20 + (4 - math.abs(i - 4)) * 0.012) * S
			local rib = MkPart("Rib" .. i .. "_" .. rs,
				Vector3.new(rw, Sc(0.012), Sc(0.025)),
				CFG.SKIN_MID, nil, 0.4, model)
			table.insert(ribs, { part = rib, idx = i, side = rs })
		end
	end

	local spine = {}
	for i = 1, 10 do
		local v = MkPart("Vert" .. i, Vector3.new(Sc(0.05), Sc(0.07), Sc(0.08)), CFG.SKIN_MID, nil, 0.3, model)
		MkMesh(v, Enum.MeshType.Sphere)
		table.insert(spine, { part = v, idx = i })
	end

	local veins = {}
	for i = 1, 5 do
		local vn = MkPart("Vein" .. i,
			Vector3.new(Sc(0.01), Sc(0.2 + math.random() * 0.3), Sc(0.01)),
			CFG.SKIN_VEIN, nil, 0.4, model)
		table.insert(veins, {
			part = vn,
			off = Vector3.new(
				(math.random() - 0.5) * CFG.TORSO.X * 0.6,
				(math.random() - 0.5) * CFG.TORSO.Y * 0.6,
				(math.random() > 0.5 and 1 or -1) * CFG.TORSO.Z * 0.3),
			phase = math.random() * math.pi * 2,
		})
	end

	-- =========================================================================
	-- CUELLO
	-- =========================================================================
	local neckSegs = {}
	local neckSegH = CFG.NECK_LEN / CFG.NECK_SEGS
	for i = 1, CFG.NECK_SEGS do
		local d = (0.13 - (i - 1) * 0.008) * S
		local seg = MkLimb("Neck" .. i, neckSegH * 1.3, d,
			LerpCol(CFG.SKIN, CFG.SKIN_MID, i / CFG.NECK_SEGS * 0.4), model)
		table.insert(neckSegs, { part = seg, idx = i })
	end

	-- =========================================================================
	-- CABEZA
	-- =========================================================================
	local head = MkPart("Head", CFG.HEAD, CFG.SKIN, nil, 0, model)
	MkMesh(head, Enum.MeshType.Sphere, Vector3.new(1, 1.35, 0.85))

	local cheeks = {}
	for cs = -1, 1, 2 do
		local ch = MkPart("Cheek" .. cs, Vector3.new(Sc(0.14), Sc(0.20), Sc(0.10)), CFG.SKIN_SHADOW, nil, 0.1, model)
		MkMesh(ch, Enum.MeshType.Sphere, Vector3.new(1, 1, 0.35))
		table.insert(cheeks, { part = ch, side = cs })
	end

	local brow = MkPart("Brow", Vector3.new(CFG.HEAD.X * 0.7, Sc(0.05), Sc(0.10)), CFG.SKIN_SHADOW, nil, 0.1, model)
	MkMesh(brow, Enum.MeshType.Sphere, Vector3.new(1, 0.4, 0.6))

	-- =========================================================================
	-- OJOS
	-- =========================================================================
	local eyes = {}
	local eyeCfgs = {
		{ x = -0.22, y = 0.18, z = -0.42, sz = Sc(0.14) },
		{ x = 0.22, y = 0.18, z = -0.42, sz = Sc(0.14) },
	}
	for i, ec in ipairs(eyeCfgs) do
		local outer = MkPart("EO" .. i,
			Vector3.new(ec.sz * 1.8, ec.sz * 1.4, ec.sz * 0.6),
			CFG.EYE_EDGE, nil, 0, model)
		MkMesh(outer, Enum.MeshType.Sphere)
		local void = MkBall("EV" .. i, ec.sz * 0.9, CFG.EYE_VOID, nil, model)
		local deep = MkBall("ED" .. i, ec.sz * 0.45, CFG.EYE_DEEP, Enum.Material.Neon, model)
		deep.Transparency = 0.3
		local trails = {}
		for t = 1, 2 do
			local tr = MkPart("ET" .. i .. "_" .. t,
				Vector3.new(Sc(0.008), Sc(0.08 + math.random() * 0.10), Sc(0.005)),
				CFG.EYE_VOID, nil, 0.2, model)
			table.insert(trails, { part = tr, xo = (t - 1.5) * Sc(0.015), len = tr.Size.Y })
		end
		local lt = Instance.new("PointLight")
		lt.Brightness = 0.04
		lt.Color = Color3.fromRGB(70, 0, 0)
		lt.Range = Sc(1.2)
		lt.Parent = void
		table.insert(eyes, {
			outer = outer, void = void, deep = deep, trails = trails, light = lt,
			cx = ec.x * CFG.HEAD.X, cy = ec.y * CFG.HEAD.Y, cz = ec.z * CFG.HEAD.Z, sz = ec.sz,
		})
	end

	-- =========================================================================
	-- SONRISA
	-- =========================================================================
	local uLip = MkPart("ULip", Vector3.new(CFG.SMILE_W, Sc(0.04), Sc(0.1)), CFG.LIP_CRACK, nil, 0, model)
	MkMesh(uLip, Enum.MeshType.Sphere, Vector3.new(1, 0.4, 0.6))
	local lLip = MkPart("LLip", Vector3.new(CFG.SMILE_W * 0.95, Sc(0.035), Sc(0.08)), CFG.LIP, nil, 0, model)
	MkMesh(lLip, Enum.MeshType.Sphere, Vector3.new(1, 0.35, 0.5))
	local mouthIn = MkPart("MIn", Vector3.new(CFG.SMILE_W * 0.85, CFG.SMILE_H, Sc(0.2)), CFG.MOUTH_VOID, nil, 0, model)
	local mouthDeep = MkPart("MDp", Vector3.new(CFG.SMILE_W * 0.6, CFG.SMILE_H * 0.7, Sc(0.25)), CFG.MOUTH_DEEP, nil, 0, model)

	local corners = {}
	for cs = -1, 1, 2 do
		local cn = MkPart("Cn" .. cs, Vector3.new(Sc(0.05), Sc(0.04), Sc(0.04)), CFG.LIP_CRACK, nil, 0, model)
		MkMesh(cn, Enum.MeshType.Sphere)
		table.insert(corners, { part = cn, side = cs })
	end

	local teethU, teethL = {}, {}
	for t = 1, CFG.TEETH_N do
		local xp = (t - (CFG.TEETH_N + 1) / 2) * (CFG.SMILE_W * 0.85 / CFG.TEETH_N)
		local sharp = math.abs(xp) < CFG.SMILE_W * 0.3
		local th = (sharp and 0.10 or 0.06) * S
		table.insert(teethU, { part = MkPart("TU" .. t, Vector3.new(Sc(0.020), th, Sc(0.016)), sharp and CFG.TEETH_SHARP or CFG.TEETH, nil, 0, model), xp = xp, h = th, ang = (math.random() - 0.5) * math.rad(10) })
		table.insert(teethL, { part = MkPart("TL" .. t, Vector3.new(Sc(0.018), th * 0.7, Sc(0.014)), CFG.TEETH, nil, 0, model), xp = xp, ang = (math.random() - 0.5) * math.rad(12) })
	end
	local gumU = MkPart("GU", Vector3.new(CFG.SMILE_W * 0.8, Sc(0.04), Sc(0.08)), CFG.GUM, nil, 0, model)
	local gumL = MkPart("GL", Vector3.new(CFG.SMILE_W * 0.75, Sc(0.035), Sc(0.07)), CFG.GUM, nil, 0, model)

	-- =========================================================================
	-- BRAZOS
	-- =========================================================================
	local arms = {}
	for as = -1, 1, 2 do
		local af = Instance.new("Folder")
		af.Name = as == -1 and "LeftArm" or "RightArm"
		af.Parent = model

		local shoulder = MkJoint("Shoulder", CFG.U_ARM_THICK, CFG.SKIN, af)
		local uArm = MkLimb("UArm", CFG.U_ARM_LEN, CFG.U_ARM_THICK, CFG.SKIN, af)
		local elbow = MkJoint("Elbow", math.max(CFG.U_ARM_THICK, CFG.F_ARM_THICK), CFG.SKIN, af)
		local fArm = MkLimb("FArm", CFG.F_ARM_LEN, CFG.F_ARM_THICK, CFG.SKIN, af)
		local wrist = MkJoint("Wrist", CFG.F_ARM_THICK, CFG.SKIN, af)
		local hand = MkPart("Hand", CFG.HAND, CFG.SKIN_MID, nil, 0, af)
		MkMesh(hand, Enum.MeshType.Sphere, Vector3.new(1, 0.45, 1.1))

		local fingers = {}
		for f = 1, 5 do
			local segs = {}
			local sLens = { 0.28, 0.26, 0.24, 0.20 }
			local sWids = { 0.026, 0.022, 0.018, 0.014 }
			for sg = 1, CFG.FINGER_SEGS do
				local sw = sWids[sg] * S
				local sh = CFG.FINGER_LEN * sLens[sg]
				local segP = MkLimb("F" .. f .. "S" .. sg, sh, sw,
					LerpCol(CFG.SKIN, CFG.SKIN_DARK, (sg - 1) / CFG.FINGER_SEGS * 0.7), af)
				local jt = MkBall("FJ" .. f .. "_" .. sg, sw * 1.2, CFG.SKIN, nil, af)
				jt.Transparency = 0.2
				table.insert(segs, { part = segP, joint = jt, w = sw, h = sh })
			end
			local claw = MkPart("Claw" .. f, Vector3.new(Sc(0.016), Sc(0.14), Sc(0.028)), CFG.NAIL, nil, 0, af)
			MkMesh(claw, Enum.MeshType.Wedge)
			table.insert(fingers, {
				segs = segs, claw = claw, idx = f,
				xo = (f - 3) * Sc(0.08), thumb = f == 1,
				curlPh = math.random() * math.pi,
				twitchPh = math.random() * math.pi * 2,
			})
		end

		table.insert(arms, {
			folder = af, shoulder = shoulder, uArm = uArm, elbow = elbow,
			fArm = fArm, wrist = wrist, hand = hand, fingers = fingers, side = as,
		})
	end

	-- =========================================================================
	-- PIERNAS
	-- =========================================================================
	local legs = {}
	for ls = -1, 1, 2 do
		local lf = Instance.new("Folder")
		lf.Name = ls == -1 and "LeftLeg" or "RightLeg"
		lf.Parent = model

		local hip = MkJoint("Hip", CFG.THIGH_THICK, CFG.SKIN, lf)
		local thigh = MkLimb("Thigh", CFG.THIGH_LEN, CFG.THIGH_THICK, CFG.SKIN, lf)
		local knee = MkJoint("Knee", math.max(CFG.THIGH_THICK, CFG.SHIN_THICK), CFG.SKIN, lf)
		local shin = MkLimb("Shin", CFG.SHIN_LEN, CFG.SHIN_THICK, CFG.SKIN, lf)
		local ankle = MkJoint("Ankle", CFG.SHIN_THICK * 0.8, CFG.SKIN, lf)
		local foot = MkPart("Foot", CFG.FOOT, CFG.SKIN_DARK, nil, 0, lf)
		MkMesh(foot, Enum.MeshType.Sphere, Vector3.new(0.5, 0.4, 1.3))

		table.insert(legs, {
			folder = lf, hip = hip, thigh = thigh, knee = knee,
			shin = shin, ankle = ankle, foot = foot, side = ls,
		})
	end

	-- =========================================================================
	-- PARTÍCULAS
	-- =========================================================================
	local darkAura = Instance.new("ParticleEmitter")
	darkAura.Texture = "rbxassetid://243098098"
	darkAura.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, CFG.AURA_IN), ColorSequenceKeypoint.new(1, CFG.AURA) })
	darkAura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, Sc(0.15)), NumberSequenceKeypoint.new(0.5, Sc(0.6)), NumberSequenceKeypoint.new(1, Sc(1.2)) })
	darkAura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 1) })
	darkAura.Lifetime = NumberRange.new(0.5, 1.0)
	darkAura.Rate = 10
	darkAura.Speed = NumberRange.new(0.2, 0.8)
	darkAura.SpreadAngle = Vector2.new(360, 360)
	darkAura.Parent = torso

	local groundFog = Instance.new("ParticleEmitter")
	groundFog.Texture = "rbxassetid://243098098"
	groundFog.Color = ColorSequence.new(Color3.fromRGB(5, 3, 8))
	groundFog.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, Sc(0.3)), NumberSequenceKeypoint.new(1, Sc(2.0)) })
	groundFog.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	groundFog.Lifetime = NumberRange.new(0.8, 1.5)
	groundFog.Rate = 5
	groundFog.Speed = NumberRange.new(0.1, 0.3)
	groundFog.SpreadAngle = Vector2.new(180, 0)
	groundFog.EmissionDirection = Enum.NormalId.Bottom
	groundFog.Parent = pelvis

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
	local frozen = false
	local curSmile = CFG.SMILE_W
	local tgtSmile = CFG.SMILE_W
	local headTilt, tgtTilt, tiltCD = 0, 0, 0
	local armReach, tgtReach = 0, 0
	local bodySway, swayTgt, swayTimer = 0, 0, 0

	-- NUEVO: Estado de animación de ataque
	-- attackPhase: 0 = ninguno, 1 = windup (subir brazos), 2 = swing (bajar), 3 = recover
	local attackPhase = 0
	local attackTimer = 0
	-- attackArmAngle: ángulo adicional de los brazos durante ataque (-= arriba, += abajo)
	local attackArmPitch = 0

	local totalH = GY + CFG.FOOT.Y + CFG.SHIN_LEN + CFG.THIGH_LEN + CFG.TORSO.Y * 0.3

	-- =========================================================================
	-- POSICIONAMIENTO
	-- =========================================================================
	local function UpdatePos(x, z, rot, walk, dt, dist, tgtPos)
		nX, nZ = x, z
		nRot = rot or nRot
		walking = walk or false
		if dt then animT = animT + dt * 5; breathT = breathT + dt * 2 end

		-- Freeze mucho menos frecuente y más corto
		if not frozen and dt and math.random() < CFG.FREEZE_CHANCE * dt * 60 then
			frozen = true
			task.delay(0.02 + math.random() * 0.05, function() frozen = false end)
		end
		if frozen then return end

		if dist and dt then
			local close = 1 - math.clamp(dist / CFG.DETECT_RANGE, 0, 1)
			tgtSmile = Lerp(CFG.SMILE_W, CFG.SMILE_W_MAX, close * close)
		end
		if dt then curSmile = SmoothLerp(curSmile, tgtSmile, CFG.SMILE_SPEED, dt) end

		if dt then tiltCD = tiltCD - dt end
		if dist and dist < CFG.CHASE_DIST and tiltCD <= 0 then
			if math.random() < 0.02 then -- reducido de 0.04
				tgtTilt = (math.random() > 0.5 and 1 or -1) * math.rad(CFG.TILT_MAX * (0.3 + math.random() * 0.5))
				tiltCD = 2.0 + math.random() * 4
			end
		elseif dist and dist > CFG.CHASE_DIST then
			tgtTilt = SmoothLerp(tgtTilt, 0, 1.0, dt or 0.016)
		end
		if dt then headTilt = SmoothLerp(headTilt, tgtTilt, CFG.TILT_SPEED, dt) end

		-- Arm reach target basado en estado
		if curState == CFG.ST_IDLE then tgtReach = math.rad(CFG.ARM_IDLE)
		elseif curState == CFG.ST_STALK then tgtReach = math.rad(CFG.ARM_STALK)
		elseif curState == CFG.ST_WALK then tgtReach = math.rad(CFG.ARM_CHASE)
		elseif curState == CFG.ST_CHARGE or curState == CFG.ST_ATTACK then tgtReach = math.rad(CFG.ARM_CHARGE) end
		if dt then armReach = SmoothLerp(armReach, tgtReach, CFG.ARM_SPEED, dt) end

		if dt then swayTimer = swayTimer - dt end
		if swayTimer <= 0 then swayTgt = (math.random() - 0.5) * math.rad(4); swayTimer = 3 + math.random() * 5 end
		if dt then bodySway = SmoothLerp(bodySway, swayTgt, 0.6, dt) end

		local effDt = dt or 0.016

		-- Reducir bob y sway para movimiento más fluido
		local wBob = walking and math.sin(animT * 2.0) * Sc(0.03) or 0 -- era 0.05
		local wSway = walking and math.sin(animT * 1.0) * Sc(0.015) or 0 -- era 0.03

		-- Twitch mucho más sutil
		local twX, twY = 0, 0
		if math.random() < CFG.TWITCH_FREQ * effDt * 60 then
			twX = (math.random() - 0.5) * Sc(0.02) -- era 0.06
			twY = (math.random() - 0.5) * Sc(0.015) -- era 0.04
		end

		local baseY = totalH + wBob
		local baseCF = CFrame.new(x + wSway + twX, baseY + twY, z) * CFrame.Angles(0, nRot, 0) * CFrame.Angles(0, 0, bodySway)

		local chaseLean = 0
		if curState == CFG.ST_WALK then chaseLean = math.rad(8)
		elseif curState == CFG.ST_CHARGE then chaseLean = math.rad(15) end
		local torsoLean = walking and math.sin(animT * 0.9) * math.rad(3) or math.sin(breathT * 0.5) * math.rad(1.5)
		local torsoCF = baseCF * CFrame.Angles(torsoLean + chaseLean, 0, 0)

		local bExp = math.sin(breathT * math.pi) * Sc(0.008)
		torso.CFrame = torsoCF
		chest.CFrame = torsoCF * CFrame.new(0, CFG.TORSO.Y * 0.1, -CFG.TORSO.Z * 0.1 + bExp)
		pelvis.CFrame = torsoCF * CFrame.new(0, -CFG.TORSO.Y * 0.47, 0)

		for _, r in ipairs(ribs) do
			local ry = CFG.TORSO.Y * 0.30 - (r.idx - 1) * Sc(0.14)
			r.part.CFrame = torsoCF * CFrame.new(r.side * (CFG.TORSO.X * 0.28 + bExp), ry, -CFG.TORSO.Z * 0.18) * CFrame.Angles(0, r.side * math.rad(20), r.side * math.rad(12))
		end
		for i, sg in ipairs(spine) do
			sg.part.CFrame = torsoCF * CFrame.new(0, CFG.TORSO.Y * 0.35 - (i - 1) * Sc(0.17), CFG.TORSO.Z * 0.25)
		end
		for _, vn in ipairs(veins) do
			local pulse = 1 + math.sin(breathT * 3.5 + vn.phase) * 0.12
			vn.part.Size = Vector3.new(Sc(0.01) * pulse, vn.part.Size.Y, Sc(0.01) * pulse)
			vn.part.CFrame = torsoCF * CFrame.new(vn.off)
		end

		-- CUELLO
		local neckBase = torsoCF * CFrame.new(0, CFG.TORSO.Y * 0.46, 0)
		local segLen = CFG.NECK_LEN / CFG.NECK_SEGS
		local prevCF = neckBase
		for i, sg in ipairs(neckSegs) do
			local wave = math.sin(animT * 1.3 + i * 0.6) * math.rad(1.5) -- reducido de 2.5
			prevCF = prevCF * CFrame.new(0, segLen * 0.5, 0) * CFrame.Angles(wave, 0, 0)
			sg.part.CFrame = prevCF
			prevCF = prevCF * CFrame.new(0, segLen * 0.5, 0)
		end

		-- CABEZA
		local headCF = prevCF * CFrame.new(0, CFG.HEAD.Y * 0.22, 0) * CFrame.Angles(0, 0, headTilt)
		head.CFrame = headCF
		for _, ck in ipairs(cheeks) do
			ck.part.CFrame = headCF * CFrame.new(ck.side * CFG.HEAD.X * 0.32, -CFG.HEAD.Y * 0.08, -CFG.HEAD.Z * 0.22)
		end
		brow.CFrame = headCF * CFrame.new(0, CFG.HEAD.Y * 0.28, -CFG.HEAD.Z * 0.38)

		-- OJOS
		for _, ey in ipairs(eyes) do
			ey.outer.CFrame = headCF * CFrame.new(ey.cx, ey.cy, ey.cz)
			ey.void.CFrame = ey.outer.CFrame * CFrame.new(0, 0, ey.sz * 0.1)
			ey.deep.CFrame = ey.outer.CFrame * CFrame.new(0, 0, ey.sz * 0.3)
			ey.light.Brightness = 0.03 + math.random() * 0.04
			for _, tr in ipairs(ey.trails) do
				tr.part.CFrame = headCF * CFrame.new(ey.cx + tr.xo, ey.cy - ey.sz * 0.5 - tr.len * 0.5, ey.cz + Sc(0.006))
			end
		end

		-- SONRISA
		local mY = -CFG.HEAD.Y * 0.3
		local mZ = -CFG.HEAD.Z * 0.42
		uLip.Size = Vector3.new(curSmile, Sc(0.04), Sc(0.1))
		uLip.CFrame = headCF * CFrame.new(0, mY + CFG.SMILE_H * 0.4, mZ)
		lLip.Size = Vector3.new(curSmile * 0.95, Sc(0.035), Sc(0.08))
		lLip.CFrame = headCF * CFrame.new(0, mY - CFG.SMILE_H * 0.3, mZ)
		mouthIn.Size = Vector3.new(curSmile * 0.85, CFG.SMILE_H, Sc(0.2))
		mouthIn.CFrame = headCF * CFrame.new(0, mY, mZ + Sc(0.05))
		mouthDeep.Size = Vector3.new(curSmile * 0.6, CFG.SMILE_H * 0.7, Sc(0.25))
		mouthDeep.CFrame = headCF * CFrame.new(0, mY, mZ + Sc(0.12))
		for _, cn in ipairs(corners) do
			cn.part.CFrame = headCF * CFrame.new(cn.side * curSmile * 0.52, mY, mZ - Sc(0.02))
		end
		gumU.Size = Vector3.new(curSmile * 0.8, Sc(0.04), Sc(0.08))
		gumU.CFrame = headCF * CFrame.new(0, mY + CFG.SMILE_H * 0.25, mZ + Sc(0.02))
		gumL.Size = Vector3.new(curSmile * 0.75, Sc(0.035), Sc(0.07))
		gumL.CFrame = headCF * CFrame.new(0, mY - CFG.SMILE_H * 0.2, mZ + Sc(0.02))
		for _, t in ipairs(teethU) do
			t.part.CFrame = gumU.CFrame * CFrame.new(t.xp * (curSmile / CFG.SMILE_W), -Sc(0.02), -Sc(0.012)) * CFrame.Angles(math.rad(180) + t.ang, 0, 0)
		end
		for _, t in ipairs(teethL) do
			t.part.CFrame = gumL.CFrame * CFrame.new(t.xp * (curSmile / CFG.SMILE_W), Sc(0.012), -Sc(0.012)) * CFrame.Angles(t.ang, 0, 0)
		end

		-- =====================================================================
		-- BRAZOS - NUEVO: persecución con brazos al frente + ataque animado
		-- =====================================================================
		for _, arm in ipairs(arms) do
			local ph = arm.side == -1 and 0 or math.pi

			-- Swing de caminar suavizado
			local wSwing = walking and math.sin(animT + ph) * math.rad(12) or 0 -- reducido de 15
			local iSway = math.sin(animT * 0.4 + arm.side * 0.7) * math.rad(2) -- reducido de 3
			local fInt = (dist and dist < CFG.CHASE_DIST) and 1.5 or 1.0 -- reducido de 2.5

			local shX = arm.side * (CFG.TORSO.X * 0.40)
			local shY = CFG.TORSO.Y * 0.38
			local shCF = torsoCF * CFrame.new(shX, shY, 0)
			arm.shoulder.CFrame = shCF

			-- === CÁLCULO DEL PITCH DEL BRAZO ===
			local rPitch = 0
			local fBend = math.rad(-15)
			local aOut = arm.side * math.rad(5)

			if attackPhase > 0 then
				-- ANIMACIÓN DE ATAQUE: ambos brazos hacen lo mismo
				-- attackArmPitch: negativo = arriba, positivo = abajo/adelante
				rPitch = attackArmPitch
				fBend = math.rad(-10) -- codos más rectos durante ataque
				aOut = arm.side * math.rad(8) -- brazos un poco más abiertos
				-- Sin wSwing durante ataque
				wSwing = 0
				iSway = 0
			elseif curState == CFG.ST_WALK or curState == CFG.ST_CHARGE then
				-- PERSECUCIÓN: brazos extendidos al frente hacia el jugador
				-- armReach ya va de 0 a ~80 grados
				rPitch = -armReach -- negativo = hacia adelante/arriba
				-- Codos más rectos cuando los brazos están al frente
				fBend = Lerp(math.rad(-15), math.rad(-5), armReach / math.rad(80))
				aOut = arm.side * Lerp(math.rad(5), math.rad(12), armReach / math.rad(80))
				-- Reducir swing de caminar cuando brazos al frente
				wSwing = wSwing * (1 - armReach / math.rad(80) * 0.7)
			else
				-- IDLE/STALK: brazos cuelgan naturalmente
				rPitch = -armReach + iSway
				fBend = math.rad(-15) - math.abs(wSwing) * 0.3
			end

			local rIn = math.sin(math.abs(rPitch)) * arm.side * -Sc(0.03)

			-- Centro del brazo superior
			local uaCF = shCF * CFrame.new(rIn, 0, 0) * CFrame.Angles(rPitch + wSwing, 0, aOut) * CFrame.new(0, -CFG.U_ARM_LEN * 0.5, 0)
			arm.uArm.CFrame = uaCF

			-- Codo
			local elbCF = uaCF * CFrame.new(0, -CFG.U_ARM_LEN * 0.5, 0)
			arm.elbow.CFrame = elbCF

			-- Antebrazo
			local faCF = elbCF * CFrame.Angles(fBend, 0, 0) * CFrame.new(0, -CFG.F_ARM_LEN * 0.5, 0)
			arm.fArm.CFrame = faCF

			-- Muñeca
			local wrCF = faCF * CFrame.new(0, -CFG.F_ARM_LEN * 0.5, 0)
			arm.wrist.CFrame = wrCF

			-- Mano
			local hCurl = math.rad(5) + iSway * 0.5
			if attackPhase == 2 then hCurl = math.rad(25) end -- garras tensas al golpear
			if armReach > math.rad(30) then hCurl = hCurl + math.rad(10) end
			local haCF = wrCF * CFrame.Angles(hCurl, 0, 0) * CFrame.new(0, -CFG.HAND.Y * 0.3, 0)
			arm.hand.CFrame = haCF

			-- Dedos
			local bCurl = math.rad(18)
			if attackPhase == 1 then bCurl = math.rad(5) -- dedos abiertos al subir
			elseif attackPhase == 2 then bCurl = math.rad(45) -- garras cerradas al bajar
			elseif attackPhase == 3 then bCurl = math.rad(25) end
			if armReach > math.rad(40) then bCurl = math.rad(8) end -- dedos abiertos persiguiendo

			for _, fg in ipairs(arm.fingers) do
				local fCurl = bCurl + math.sin(breathT * 1.4 * fInt + fg.curlPh) * math.rad(3 * fInt)
				local fTw = math.sin(animT * 2.5 * fInt + fg.twitchPh) * math.rad(1.5 * fInt) -- reducido
				local fSpread = (fg.idx - 3) * math.rad(9)
				if armReach > math.rad(30) or attackPhase == 1 then fSpread = fSpread * 1.8 end

				local fbX = fg.xo
				if fg.thumb then fbX = arm.side * CFG.HAND.X * 0.35 end

				local pCF = haCF * CFrame.new(fbX, -CFG.HAND.Y * 0.25, -Sc(0.01)) * CFrame.Angles(0, fSpread, 0)
				for si, sg in ipairs(fg.segs) do
					local sc = fCurl * (0.22 + si * 0.20) + fTw
					if fg.thumb then sc = sc * 0.45 end
					sg.joint.CFrame = pCF
					local sCF = pCF * CFrame.Angles(sc, 0, 0) * CFrame.new(0, -sg.h * 0.5, 0)
					sg.part.CFrame = sCF
					pCF = sCF * CFrame.new(0, -sg.h * 0.5, 0)
				end
				fg.claw.CFrame = pCF * CFrame.Angles(math.rad(25), 0, 0) * CFrame.new(0, -Sc(0.07), 0)
			end
		end

		-- =====================================================================
		-- PIERNAS
		-- =====================================================================
		for _, leg in ipairs(legs) do
			local ph = leg.side == -1 and 0 or math.pi
			local wCyc = walking and math.sin(animT + ph) or 0

			local hipCF = torsoCF * CFrame.new(leg.side * CFG.PELVIS.X * 0.38, -CFG.TORSO.Y * 0.47, 0)
			leg.hip.CFrame = hipCF

			local tPitch = math.rad(2) + wCyc * math.rad(28)
			local thCF = hipCF * CFrame.Angles(tPitch, 0, leg.side * math.rad(1.5)) * CFrame.new(0, -CFG.THIGH_LEN * 0.5, 0)
			leg.thigh.CFrame = thCF

			local knCF = thCF * CFrame.new(0, -CFG.THIGH_LEN * 0.5, 0)
			leg.knee.CFrame = knCF

			local sPitch = math.rad(-6) - math.abs(wCyc) * math.rad(22)
			local shCF = knCF * CFrame.Angles(sPitch, 0, 0) * CFrame.new(0, -CFG.SHIN_LEN * 0.5, 0)
			leg.shin.CFrame = shCF

			local anCF = shCF * CFrame.new(0, -CFG.SHIN_LEN * 0.5, 0)
			leg.ankle.CFrame = anCF

			leg.foot.CFrame = anCF * CFrame.Angles(math.rad(-75) + wCyc * math.rad(10), 0, 0) * CFrame.new(0, 0, -CFG.FOOT.Z * 0.3)
		end
	end

	UpdatePos(nX, nZ, nRot, false, 0.016, 999, nil)

	-- =========================================================================
	-- SONIDOS
	-- =========================================================================
	local breathSnd = Instance.new("Sound")
	breathSnd.SoundId = "rbxassetid://139271799915451"
	breathSnd.Volume = 0.3; breathSnd.Looped = true; breathSnd.PlaybackSpeed = 2.5
	breathSnd.Parent = head; breathSnd:Play()

	local staticSnd = Instance.new("Sound")
	staticSnd.SoundId = "rbxassetid://"
	staticSnd.Volume = 0.12; staticSnd.Looped = true; staticSnd.PlaybackSpeed = 0.2
	staticSnd.Parent = torso; staticSnd:Play()

	local footSnd = Instance.new("Sound")
	footSnd.SoundId = "rbxassetid://124605353623000"
	footSnd.Volume = 0.1; footSnd.PlaybackSpeed = 0.5
	footSnd.Parent = torso

	-- =========================================================================
	-- ATAQUES - NUEVO: Animación de golpe con ambos brazos
	-- =========================================================================
	local lastAtk = 0
	local lastLunge = -CFG.CD_LUNGE
	local lastGrab = -CFG.CD_GRAB

	-- Ataque principal: subir ambos brazos y bajarlos golpeando
	local function SlamAttack(player)
		if tick() - lastAtk < CFG.CD_ATTACK or attacking then return end
		lastAtk = tick(); attacking = true
		local ch = player.Character
		if not ch then attacking = false return end
		local hum, hrp = ch:FindFirstChild("Humanoid"), ch:FindFirstChild("HumanoidRootPart")
		if not (hum and hum.Health > 0 and hrp) then attacking = false return end

		-- FASE 1: WINDUP - subir brazos arriba de la cabeza
		attackPhase = 1
		attackTimer = 0
		local windupDur = CFG.ATTACK_WINDUP

		-- Sonido de preparación
		local windSnd = Instance.new("Sound")
		windSnd.SoundId = "rbxassetid://9114221580"; windSnd.Volume = 0.3; windSnd.PlaybackSpeed = 1.2
		windSnd.Parent = head; windSnd:Play()

		-- Interpolar brazos hacia arriba durante windup
		local startTime = tick()
		while tick() - startTime < windupDur do
			local progress = (tick() - startTime) / windupDur
			-- Easing: empieza lento, acelera
			local eased = progress * progress
			-- Brazos suben: pitch negativo grande = brazos arriba/atrás
			attackArmPitch = Lerp(0, math.rad(-160), eased)
			task.wait()
		end
		attackArmPitch = math.rad(-160)

		-- FASE 2: SWING - bajar brazos rápido golpeando
		attackPhase = 2
		local swingDur = CFG.ATTACK_SWING

		-- Sonido de golpe
		local hitSnd = Instance.new("Sound")
		hitSnd.SoundId = "rbxassetid://5766332557"; hitSnd.Volume = 1.0; hitSnd.PlaybackSpeed = 1.8
		hitSnd.Parent = head; hitSnd:Play()

		startTime = tick()
		while tick() - startTime < swingDur do
			local progress = (tick() - startTime) / swingDur
			-- Easing inverso: empieza rápido, desacelera al final
			local eased = 1 - (1 - progress) * (1 - progress)
			-- Brazos bajan de arriba (-160°) a adelante/abajo (+30°)
			attackArmPitch = Lerp(math.rad(-160), math.rad(30), eased)
			task.wait()
		end
		attackArmPitch = math.rad(30)

		-- APLICAR DAÑO en el momento del impacto (sin knockback)
		if hum and hum.Parent and hum.Health > 0 and hrp then
			local distToTarget = (hrp.Position - Vector3.new(nX, hrp.Position.Y, nZ)).Magnitude
			if distToTarget < CFG.ATTACK_RANGE + 2 then
				hum:TakeDamage(CFG.DMG_CLAW)
			end
		end

		-- FASE 3: RECOVER - brazos vuelven a posición normal
		attackPhase = 3
		local recoverDur = CFG.ATTACK_RECOVER
		startTime = tick()
		while tick() - startTime < recoverDur do
			local progress = (tick() - startTime) / recoverDur
			local eased = progress
			attackArmPitch = Lerp(math.rad(30), 0, eased)
			task.wait()
		end

		attackArmPitch = 0
		attackPhase = 0
		Debris:AddItem(windSnd, 2)
		Debris:AddItem(hitSnd, 2)
		attacking = false
	end

	-- Grab ahora también usa animación (sin paralizar tanto)
	local function GrabAttack(player)
		if tick() - lastGrab < CFG.CD_GRAB or attacking then return end
		lastGrab = tick(); attacking = true
		local ch = player.Character
		if not ch then attacking = false return end
		local hum, hrp = ch:FindFirstChild("Humanoid"), ch:FindFirstChild("HumanoidRootPart")
		if hum and hum.Health > 0 and hrp then
			if (hrp.Position - Vector3.new(nX, hrp.Position.Y, nZ)).Magnitude < CFG.ATTACK_RANGE + 3 then
				local snd = Instance.new("Sound")
				snd.SoundId = "rbxassetid://9114221580"; snd.Volume = 0.6; snd.PlaybackSpeed = 0.6
				snd.Parent = head; snd:Play()

				-- Brazos se cierran al frente (agarrar)
				attackPhase = 2
				attackArmPitch = math.rad(-70) -- brazos al frente

				local oS, oJ = hum.WalkSpeed, hum.JumpPower
				hum.WalkSpeed = 2; hum.JumpPower = 0 -- no paralizar completamente
				task.wait(0.6)
				if hum and hum.Parent and hum.Health > 0 then
					hum:TakeDamage(CFG.DMG_GRAB)
					hum.WalkSpeed = oS; hum.JumpPower = oJ
				end

				-- Soltar
				attackPhase = 3
				attackArmPitch = Lerp(math.rad(-70), 0, 0.5)
				task.wait(0.2)
				attackArmPitch = 0
				attackPhase = 0

				Debris:AddItem(snd, 2)
			end
		end
		task.wait(0.2); attacking = false
	end

	-- =========================================================================
	-- MUERTE
	-- =========================================================================
	local function DeathEffect()
		darkAura.Enabled = false; groundFog.Enabled = false
		breathSnd:Stop(); staticSnd:Stop()
		local snd = Instance.new("Sound")
		snd.SoundId = "rbxassetid://72245886498891"; snd.Volume = 1.2; snd.PlaybackSpeed = 0.6
		snd.Parent = head; snd:Play()
		for _, p in pairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				task.delay(math.random() * 0.4, function()
					TweenService:Create(p, TweenInfo.new(0.8 + math.random() * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Transparency = 1,
						Position = p.Position + Vector3.new((math.random() - 0.5) * Sc(0.5), -Sc(1.0), (math.random() - 0.5) * Sc(0.5)),
						Color = Color3.fromRGB(5, 2, 5),
					}):Play()
				end)
			end
		end
		task.wait(1.5); Debris:AddItem(snd, 3)
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
		elseif st == CFG.ST_ATTACK then curSpeed = 0 end
	end

	local function UpdateDarkAura()
		local pos = Vector3.new(nX, totalH, nZ)
		local rng = CFG.DARK_RANGE * S
		for _, d in pairs(workspace:GetDescendants()) do
			if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
				local lp = d.Parent
				if lp and lp:IsA("BasePart") and not lp:IsDescendantOf(model) then
					local dd = (lp.Position - pos).Magnitude
					if dd < rng then
						if not d:GetAttribute("OB") then d:SetAttribute("OB", d.Brightness) end
						d.Brightness = d:GetAttribute("OB") * (1 - ((rng - dd) / rng) * CFG.DIM_AMT)
					else
						local ob = d:GetAttribute("OB")
						if ob then d.Brightness = ob; d:SetAttribute("OB", nil) end
					end
				end
			end
		end
	end

	local function MoveToward(targetPos, speed, dt2, dist2, tgtP2)
		local dir = Vector3.new(targetPos.X - nX, 0, targetPos.Z - nZ)
		if dir.Magnitude > 0.5 then
			-- Rotación suavizada hacia el objetivo (no snap instantáneo)
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

		stateT = stateT + dt
		local tgt, dist = FindTarget()
		local tgtP = nil
		if tgt and tgt.Character then
			local hrp = tgt.Character:FindFirstChild("HumanoidRootPart")
			if hrp then tgtP = hrp.Position; lastSeen = tgtP end
		end

		if walking and tick() - lastFootT > (0.5 / math.max(curSpeed / CFG.SPEED_WALK, 0.5)) then
			lastFootT = tick(); footSnd.PlaybackSpeed = 0.4 + (curSpeed / CFG.SPEED_CHARGE) * 0.4; footSnd:Play()
		end
		if math.floor((tick() - t0) * 2) % 2 == 0 then UpdateDarkAura() end

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
			if tgt and dist < CFG.CHARGE_DIST then SetState(CFG.ST_CHARGE)
			elseif tgt and tgtP then
				if dist <= CFG.ATTACK_RANGE then
					-- Mirar al jugador y atacar con slam
					local dir = Vector3.new(tgtP.X - nX, 0, tgtP.Z - nZ)
					UpdatePos(nX, nZ, math.atan2(-dir.X, -dir.Z), false, dt, dist, tgtP)
					if math.random() < 0.2 and tick() - lastGrab >= CFG.CD_GRAB then
						coroutine.wrap(function() GrabAttack(tgt) end)()
					else
						coroutine.wrap(function() SlamAttack(tgt) end)()
					end
				else MoveToward(tgtP, curSpeed, dt, dist, tgtP) end
			else SetState(CFG.ST_STALK) end

		elseif curState == CFG.ST_CHARGE then
			if tgt and tgtP then
				local dir = Vector3.new(tgtP.X - nX, 0, tgtP.Z - nZ)
				if dist <= CFG.ATTACK_RANGE then
					-- Atacar con slam
					UpdatePos(nX, nZ, math.atan2(-dir.X, -dir.Z), false, dt, dist, tgtP)
					coroutine.wrap(function() SlamAttack(tgt) end)()
				elseif dist <= CFG.LUNGE_RANGE and tick() - lastLunge >= CFG.CD_LUNGE then
					-- LUNGE: ahora sin BodyVelocity, solo daño directo
					lastLunge = tick(); attacking = true
					local look = math.atan2(-dir.X, -dir.Z)
					local lDir = dir.Unit

					-- Subir brazos rápido durante lunge
					attackPhase = 1
					attackArmPitch = math.rad(-140)

					local snd = Instance.new("Sound")
					snd.SoundId = "rbxassetid://9114221580"; snd.Volume = 0.8; snd.PlaybackSpeed = 0.8
					snd.Parent = head; snd:Play()

					-- Avanzar rápido
					for _ = 1, 8 do
						local step = CFG.SPEED_BURST * 0.03
						local nx = nX + lDir.X * step; local nz = nZ + lDir.Z * step
						if not InLobby(nx) then UpdatePos(nx, nz, look, true, dt, dist, tgtP) end
						task.wait(0.02)
					end

					-- Bajar brazos para golpear
					attackPhase = 2
					attackArmPitch = math.rad(20)

					-- Daño sin knockback
					if tgt.Character then
						local hrp = tgt.Character:FindFirstChild("HumanoidRootPart")
						local hum = tgt.Character:FindFirstChild("Humanoid")
						if hrp and hum and hum.Health > 0 then
							if (hrp.Position - Vector3.new(nX, hrp.Position.Y, nZ)).Magnitude < CFG.ATTACK_RANGE + 4 then
								hum:TakeDamage(CFG.DMG_LUNGE)
								-- NO BodyVelocity - solo golpea, no lanza
							end
						end
					end

					-- Recuperar
					attackPhase = 3
					task.wait(0.15)
					attackArmPitch = 0
					attackPhase = 0

					Debris:AddItem(snd, 2); attacking = false
				else
					local spd = curSpeed
					if math.random() < CFG.SUDDEN_CHANCE then spd = CFG.SPEED_BURST end
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
	coroutine.wrap(function()
		while alive and head and head.Parent do
			task.wait(math.random(4, 12))
			if alive and curState ~= CFG.ST_IDLE and math.random() < CFG.CRACK_CHANCE then
				local snd = Instance.new("Sound")
				snd.SoundId = "rbxassetid://5766332557"; snd.Volume = 0.4; snd.PlaybackSpeed = 0.6 + math.random() * 0.3
				snd.Parent = head; snd:Play(); Debris:AddItem(snd, 2)
				tgtTilt = (math.random() > 0.5 and 1 or -1) * math.rad(CFG.TILT_MAX)
				task.wait(0.6 + math.random()); tgtTilt = 0
			end
		end
	end)()

	coroutine.wrap(function()
		while alive and head and head.Parent do
			task.wait(math.random(7, 18))
			if alive then
				local w = Instance.new("Sound")
				w.SoundId = "rbxassetid://80126562543070"; w.Volume = 0.15; w.PlaybackSpeed = 0.3 + math.random() * 0.2
				w.Parent = head; w:Play(); Debris:AddItem(w, 4)
			end
		end
	end)()

	coroutine.wrap(function()
		while alive and head and head.Parent do
			task.wait(math.random(12, 25))
			if alive and (curState == CFG.ST_WALK or curState == CFG.ST_CHARGE) and math.random() < CFG.SCREAM_CHANCE then
				local snd = Instance.new("Sound")
				snd.SoundId = "rbxassetid://9114221580"; snd.Volume = 0.5; snd.PlaybackSpeed = 0.15
				snd.Parent = head; snd:Play(); Debris:AddItem(snd, 5)
				local prev = curSpeed; curSpeed = CFG.SPEED_BURST; task.wait(1.5); curSpeed = prev
			end
		end
	end)()

	coroutine.wrap(function()
		while alive and torso and torso.Parent do
			task.wait(math.random(8, 20))
			if alive then
				swayTgt = (math.random() > 0.5 and 1 or -1) * math.rad(8 + math.random() * 5) -- reducido
				task.wait(0.08 + math.random() * 0.06); swayTgt = 0
			end
		end
	end)()

	folder.AncestryChanged:Connect(function()
		if not folder.Parent then
			alive = false; breathSnd:Stop(); staticSnd:Stop()
			if conn then conn:Disconnect() end
			for _, d in pairs(workspace:GetDescendants()) do
				if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
					local ob = d:GetAttribute("OB")
					if ob then d.Brightness = ob; d:SetAttribute("OB", nil) end
				end
			end
		end
	end)

	return folder
end

-- -------------------------------------------------------------------------------
-- LISTENER
-- -------------------------------------------------------------------------------
if SpawnSlenderEvent then
	SpawnSlenderEvent.Event:Connect(function(pos, player, side, zDir, doorInfo, lifetime)
		print("SpawnSlenderEvent received - Lifetime:", tostring(lifetime))
		task.wait(0.2)
		CreateSlenderNPC(pos, player, side, zDir, doorInfo, lifetime)
	end)
end

print("=== THE SLENDER V3.1 - SMOOTH SLAM ATTACK ===")
print("  Smoother movement, less twitching")
print("  Arms extend toward player during chase")
print("  Two-handed overhead slam attack")
print("  No knockback launch - direct hit only")
print("  Scale:", S .. "x")
print("==============================================")