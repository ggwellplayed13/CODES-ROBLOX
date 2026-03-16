--[[
    +------------------------------------------------------------------------------+
    |                    HUMANOID HORROR ENTITY SYSTEM                              |
    |                 VERSION 3.0 - "THE MINER" - ALL FIXES APPLIED                |
    |                      FANTASMA DE LA EXPLOSIÓN MINERA                          |
    +------------------------------------------------------------------------------+
    
    Un minero fantasmal que murió en una explosión subterránea:
    - Casco de minero con linterna que parpadea erráticamente
    - Ropa de trabajo destrozada y quemada por la explosión
    - Piel gris ceniza con marcas de quemaduras y hollín
    - Pico oxidado que apunta HACIA ADELANTE al perseguir
    - Fragmentos de roca incrustados en el cuerpo
    - Cadenas rotas colgando del cinturón
    - Polvo de carbón emanando constantemente
    - Ojo izquierdo brillante, ojo derecho destruido (parche improvisado)
    - Cojea al caminar (pierna derecha dañada por la explosión)
    - Al abrir la puerta grita advertencias 8-bit antes de emerger
    
    V3.0 FIXES (ALL 30 issues from review):
    
    GEOMETRY & OVERLAP:
    1.  Pickaxe heads now extend along handle axis (proper pickaxe shape)
    2.  Neck cylinder Size corrected (long axis = X for Cylinder mesh)
    3.  Arm/Leg cylinder Sizes corrected (long axis in X dimension)
    4.  Shoulder gap increased to prevent arm-torso clipping on rotation
    5.  Boots follow ankle position instead of being locked to ground
    6.  Boot sole positioned BELOW boot (no overlap)
    
    PROPORTIONS & VISUALS:
    7.  Belt width reduced to match torso (no floating edges)
    8.  Buckle Z-offset corrected to stay on belt surface
    9.  Embedded rocks offset outward so they visually protrude
    10. Eye patch strap split into segments that wrap around head surface
    11. Soot marks positioned on sphere surface using proper spherical math
    12. Face burn positioned on sphere surface using spherical projection
    
    ANIMATION:
    13. Limp offset propagates to leg chain (legs shorten with torso dip)
    14. pickaxeSwingAngle updates are frame-synced (no race condition)
    15. Fingers curl around pickaxe handle when holding
    16. animTime wraps around 2*PI*large_period to avoid float precision loss
    
    SOUND & EFFECTS:
    17. Spark emitter parented to pick HEAD (not handle)
    18. Pick drag sound only plays when pick tip is near ground
    19. Bootstep sound synced to walk cycle (fires when foot plants)
    20. Ambient groans reuse a single Sound instance
    
    LOGIC & AI:
    21. FindNearestPlayer uses 2D distance (ignores Y)
    22. IsInLobby checks both X and Z bounds
    23. Basic raycast collision so NPC doesn't walk through walls
    24. groundY determined by downward raycast each frame
    25. Knockback uses LinearVelocity + Attachment (not deprecated BodyVelocity)
    
    MINOR / STYLE:
    26. Speeds scaled by S for proportional movement at any scale
    27. doorFrameInfo and side parameters removed (were unused)
    28. Eye light range reduced to avoid illuminating helmet/body
    29. Bandana mesh scale adjusted (less pancake, more rolled cloth)
    30. ShowSubtitleEvent creation validates type before use
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local SpawnMinerEvent = ReplicatedStorage:WaitForChild("SpawnMinerEvent", 10)

-- FIX #30: Validate ShowSubtitleEvent type before use
local ShowSubtitleEvent = ReplicatedStorage:FindFirstChild("ShowSubtitle")
if ShowSubtitleEvent and not ShowSubtitleEvent:IsA("RemoteEvent") then
	ShowSubtitleEvent = nil
end
if not ShowSubtitleEvent then
	ShowSubtitleEvent = Instance.new("RemoteEvent")
	ShowSubtitleEvent.Name = "ShowSubtitle"
	ShowSubtitleEvent.Parent = ReplicatedStorage
end

-- -------------------------------------------------------------------------------
-- CONFIGURATION
-- -------------------------------------------------------------------------------
local CFG = {
	SCALE = 1.6,

	-- SPEEDS (FIX #26: base speeds will be multiplied by S for proportional movement)
	SPEED_IDLE = 0,
	SPEED_WANDER_BASE = 6.25,   -- multiplied by S -> 10 at 1.6x
	SPEED_CHASE_BASE = 13.75,   -- multiplied by S -> 22 at 1.6x
	SPEED_LIMP_PENALTY = 0.72,

	-- DISTANCES
	DETECTION_RANGE = 180,
	CHASE_THRESHOLD = 120,
	ATTACK_RANGE = 7,
	PICKAXE_RANGE = 8,

	-- COMBAT
	DAMAGE_PICKAXE = 30,
	DAMAGE_HEAVY_SWING = 50,
	ATTACK_COOLDOWN = 1.0,
	HEAVY_SWING_COOLDOWN = 6,
	HEAVY_SWING_CHANCE = 0.25,

	-- COLORS ---------------------------------------------------------------

	-- Skin
	SKIN_BASE = Color3.fromRGB(125, 118, 112),
	SKIN_BURNT = Color3.fromRGB(65, 55, 48),
	SKIN_SOOT = Color3.fromRGB(42, 38, 35),
	SKIN_GHOSTLY = Color3.fromRGB(145, 138, 148),

	-- Clothing
	OVERALLS_BASE = Color3.fromRGB(58, 52, 42),
	OVERALLS_TORN = Color3.fromRGB(38, 33, 26),
	OVERALLS_BURNT = Color3.fromRGB(28, 22, 16),
	SHIRT_DIRTY = Color3.fromRGB(88, 78, 62),
	SHIRT_BURNT = Color3.fromRGB(52, 42, 32),

	-- Helmet & gear
	HELMET_COLOR = Color3.fromRGB(185, 162, 42),
	HELMET_DENTED = Color3.fromRGB(145, 125, 32),
	HELMET_STRAP = Color3.fromRGB(68, 52, 32),
	LANTERN_GLASS = Color3.fromRGB(255, 235, 175),
	LANTERN_FRAME = Color3.fromRGB(95, 85, 65),
	LANTERN_GLOW = Color3.fromRGB(255, 218, 115),

	-- Pickaxe
	PICKAXE_HANDLE = Color3.fromRGB(75, 52, 28),
	PICKAXE_HEAD = Color3.fromRGB(105, 88, 72),
	PICKAXE_RUST = Color3.fromRGB(145, 82, 38),
	PICKAXE_EDGE = Color3.fromRGB(165, 158, 148),

	-- Effects
	COAL_DUST = Color3.fromRGB(32, 28, 22),
	EMBER_COLOR = Color3.fromRGB(255, 115, 28),
	SPARK_COLOR = Color3.fromRGB(255, 205, 82),
	GHOST_GLOW = Color3.fromRGB(175, 195, 255),
	EYE_COLOR = Color3.fromRGB(195, 225, 255),
	BURN_MARK = Color3.fromRGB(22, 16, 10),

	-- Chains & rocks
	CHAIN_COLOR = Color3.fromRGB(88, 82, 78),
	CHAIN_RUST = Color3.fromRGB(115, 68, 38),
	ROCK_COLOR = Color3.fromRGB(78, 72, 68),
	ROCK_DARK = Color3.fromRGB(48, 42, 38),

	-- Boot
	BOOT_COLOR = Color3.fromRGB(52, 42, 28),
	BOOT_SOLE = Color3.fromRGB(28, 22, 18),

	-- Glove
	GLOVE_COLOR = Color3.fromRGB(78, 62, 42),
	GLOVE_WORN = Color3.fromRGB(72, 58, 38),

	-- BODY DIMENSIONS (pre-scale, multiplied by SCALE later) ---------------

	HEAD_RADIUS = 0.48,
	NECK_HEIGHT = 0.15,
	NECK_RADIUS = 0.1,

	TORSO_WIDTH = 1.3,
	TORSO_HEIGHT = 1.7,
	TORSO_DEPTH = 0.65,

	PELVIS_WIDTH = 1.1,
	PELVIS_HEIGHT = 0.45,
	PELVIS_DEPTH = 0.55,

	SHOULDER_RADIUS = 0.11,
	UPPER_ARM_WIDTH = 0.14,
	UPPER_ARM_LENGTH = 1.15,
	ELBOW_RADIUS = 0.08,
	FOREARM_WIDTH = 0.12,
	FOREARM_LENGTH = 1.05,
	WRIST_RADIUS = 0.06,
	HAND_WIDTH = 0.18,
	HAND_HEIGHT = 0.08,
	HAND_DEPTH = 0.2,

	HIP_RADIUS = 0.1,
	THIGH_WIDTH = 0.15,
	THIGH_LENGTH = 1.2,
	KNEE_RADIUS = 0.08,
	SHIN_WIDTH = 0.13,
	SHIN_LENGTH = 1.15,
	ANKLE_RADIUS = 0.06,
	BOOT_WIDTH = 0.4,
	BOOT_HEIGHT = 0.35,
	BOOT_DEPTH = 0.6,
	BOOT_SOLE_HEIGHT = 0.06,

	HELMET_WIDTH = 1.1,
	HELMET_HEIGHT = 0.58,
	HELMET_DEPTH = 1.0,
	HELMET_BRIM_WIDTH = 1.25,
	HELMET_BRIM_HEIGHT = 0.07,
	HELMET_BRIM_DEPTH = 1.15,

	LANTERN_WIDTH = 0.28,
	LANTERN_HEIGHT = 0.24,
	LANTERN_DEPTH = 0.24,

	PICKAXE_HANDLE_WIDTH = 0.07,
	PICKAXE_HANDLE_LENGTH = 2.2,
	PICKAXE_HEAD_WIDTH = 0.11,
	PICKAXE_HEAD_LENGTH = 0.7,
	PICKAXE_HEAD_DEPTH = 0.14,

	LANTERN_FLICKER_MIN = 2,
	LANTERN_FLICKER_MAX = 8,

	LIMP_INTENSITY = 0.15,
	LIMP_SPEED = 1.8,

	-- States
	STATE_IDLE = 1,
	STATE_WANDER = 2,
	STATE_CHASE = 3,
	STATE_ATTACK = 4,
	STATE_HEAVY_SWING = 5,

	-- FIX #22: Lobby bounds in both X and Z
	LOBBY_START_X = -75,
	LOBBY_END_X = 75,
	LOBBY_START_Z = -75,
	LOBBY_END_Z = 75,

	-- Dialogue subtitles
	DIALOGUE_LINES = {
		{text = "IT'S GONNA BLOW! GET OUT!", delay = 0.0, duration = 2.0},
		{text = "THE FUSE IS LIT... WE'RE TRAPPED!", delay = 2.3, duration = 2.5},
		{text = "NO... THE SHAFT IS COLLAPSING!", delay = 5.0, duration = 2.5},
		{text = "...I can still hear the dynamite...", delay = 7.8, duration = 2.0},
	},

	-- Whisper lines (ambient)
	WHISPER_LINES = {
		"...the fuse...",
		"...get out...",
		"...it's gonna blow...",
		"...trapped...",
		"...can't breathe...",
		"...the shaft...",
		"...dynamite...",
		"...we're all dead...",
	},
}

local S = CFG.SCALE

-- FIX #26: Actual speeds scaled by S
local SPEED_WANDER = CFG.SPEED_WANDER_BASE * S
local SPEED_CHASE = CFG.SPEED_CHASE_BASE * S

-- FIX #22: Lobby check uses both X and Z
local function IsInLobby(x, z)
	return x >= CFG.LOBBY_START_X and x <= CFG.LOBBY_END_X
		and z >= CFG.LOBBY_START_Z and z <= CFG.LOBBY_END_Z
end

-- FIX #16: Wrap period for animTime to prevent float precision loss
local ANIM_WRAP_PERIOD = math.pi * 2 * 1000 -- ~6283, well within float precision

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
	if scale then mesh.Scale = scale end
	mesh.Parent = parent
	return mesh
end

local function CreateBall(name, diameter, color, material, parent)
	local part = CreatePart(name, Vector3.new(diameter, diameter, diameter), color, material, 0, parent)
	part.Shape = Enum.PartType.Ball
	return part
end

-- FIX #11/#12: Project a point onto the surface of an ellipsoid (head shape)
-- Given a desired direction (nx, ny, nz) relative to center, returns the
-- point on the ellipsoid surface with semi-axes (rx, ry, rz).
local function ProjectToEllipsoidSurface(nx, ny, nz, rx, ry, rz)
	local len = math.sqrt(nx*nx + ny*ny + nz*nz)
	if len < 0.001 then return 0, 0, -rz end
	local dx, dy, dz = nx/len, ny/len, nz/len
	-- parametric: point = t*(dx,dy,dz), on ellipsoid when (tx/rx)^2+(ty/ry)^2+(tz/rz)^2 = 1
	local invSq = (dx/rx)^2 + (dy/ry)^2 + (dz/rz)^2
	local t = 1 / math.sqrt(invSq)
	return dx * t, dy * t, dz * t
end

-- FIX #23: Raycast utility for collision / ground detection
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
-- FilterDescendantsInstances will be set per-NPC after creation

local function RaycastDown(x, z, filterList)
	raycastParams.FilterDescendantsInstances = filterList
	local origin = Vector3.new(x, 200, z)
	local direction = Vector3.new(0, -400, 0)
	local result = workspace:Raycast(origin, direction, raycastParams)
	if result then
		return result.Position.Y
	end
	return 0.5 -- fallback
end

local function RaycastForward(fromPos, direction, distance, filterList)
	raycastParams.FilterDescendantsInstances = filterList
	local result = workspace:Raycast(fromPos, direction.Unit * distance, raycastParams)
	return result -- nil if no hit
end

-- -------------------------------------------------------------------------------
-- CREATE THE MINER NPC
-- -------------------------------------------------------------------------------

-- FIX #27: Removed unused parameters 'side' and 'doorFrameInfo'
local function CreateMinerNPC(spawnPosition, triggerPlayer, zDir, lifetime)
	local npcLifetime = lifetime or 55

	print("===========================================")
	print("?? THE MINER V3 SPAWNED ??")
	print("   Scale: " .. S .. "x | Lifetime: " .. npcLifetime .. "s")
	print("===========================================")

	local npcFolder = Instance.new("Folder")
	npcFolder.Name = "MinerEntity"
	npcFolder.Parent = workspace

	local npcModel = Instance.new("Model")
	npcModel.Name = "TheMiner"
	npcModel.Parent = npcFolder

	local spawnTime = tick()
	npcFolder:SetAttribute("SpawnTime", spawnTime)
	npcFolder:SetAttribute("Lifetime", npcLifetime)
	npcModel:SetAttribute("SpawnTime", spawnTime)
	npcModel:SetAttribute("Lifetime", npcLifetime)
	npcModel:SetAttribute("BodyCharge", 0)
	npcModel:SetAttribute("HeadCharge", 0)
	npcModel:SetAttribute("Stunned", false)
	npcModel:SetAttribute("StunDuration", 3)

	-- FIX #24: groundY is now dynamic, initial value from raycast
	local groundY = RaycastDown(spawnPosition.X, spawnPosition.Z, {npcFolder})

	-- Raycast filter list (updated after all parts are created)
	local npcFilterList = {npcFolder}

	-- =========================================================================
	-- TORSO (overalls destrozados)
	-- =========================================================================

	local torsoW = CFG.TORSO_WIDTH * S
	local torsoH = CFG.TORSO_HEIGHT * S
	local torsoD = CFG.TORSO_DEPTH * S

	local torso = CreatePart("Torso", Vector3.new(torsoW, torsoH, torsoD), CFG.OVERALLS_BASE, Enum.Material.Fabric, 0, npcModel)
	torso.CanCollide = true

	-- Overalls straps (positioned on FRONT surface, not inside torso)
	local strapThick = 0.1 * S
	local strapLen = torsoH * 0.85
	local strapZOff = -(torsoD * 0.5 + strapThick * 0.5)

	local strapLeft = CreatePart("StrapL", Vector3.new(strapThick, strapLen, strapThick), CFG.OVERALLS_TORN, Enum.Material.Fabric, 0, npcModel)
	local strapRight = CreatePart("StrapR", Vector3.new(strapThick, strapLen, strapThick), CFG.OVERALLS_TORN, Enum.Material.Fabric, 0, npcModel)

	-- Visible shirt underneath (upper chest area)
	local shirtVisible = CreatePart("ShirtVis",
		Vector3.new(torsoW * 0.55, torsoH * 0.35, 0.02 * S),
		CFG.SHIRT_DIRTY, Enum.Material.Fabric, 0, npcModel)

	-- Burn mark on torso (surface decal)
	local burnMark = CreatePart("BurnMark",
		Vector3.new(0.5 * S, 0.7 * S, 0.015 * S),
		CFG.BURN_MARK, Enum.Material.SmoothPlastic, 0.25, npcModel)

	-- Torn fabric strips hanging from torso edges
	local tornFabrics = {}
	local fabricDefs = {
		{xRatio = -0.38, yRatio = -0.48, zSide = 1, w = 0.14, h = 0.35},
		{xRatio = 0.35, yRatio = -0.45, zSide = -1, w = 0.12, h = 0.4},
		{xRatio = -0.15, yRatio = -0.5, zSide = 1, w = 0.18, h = 0.3},
		{xRatio = 0.1, yRatio = -0.46, zSide = -1, w = 0.1, h = 0.38},
	}
	for i, def in ipairs(fabricDefs) do
		local fabric = CreatePart("TornFab" .. i,
			Vector3.new(def.w * S, def.h * S, 0.015 * S),
			i % 2 == 0 and CFG.OVERALLS_BURNT or CFG.SHIRT_BURNT,
			Enum.Material.Fabric, 0, npcModel)
		table.insert(tornFabrics, {
			part = fabric,
			xOff = def.xRatio * torsoW,
			yOff = def.yRatio * torsoH,
			zSide = def.zSide,
			phase = math.random() * math.pi * 2,
		})
	end

	-- FIX #7: Belt matches torso width exactly (no floating edges)
	local beltW = torsoW
	local beltH = 0.14 * S
	local beltD = torsoD
	local toolBelt = CreatePart("ToolBelt", Vector3.new(beltW, beltH, beltD),
		Color3.fromRGB(58, 42, 22), Enum.Material.Leather, 0, npcModel)

	-- FIX #8: Belt buckle positioned on belt front surface
	local buckle = CreatePart("Buckle", Vector3.new(0.14 * S, 0.11 * S, 0.035 * S),
		Color3.fromRGB(155, 135, 62), Enum.Material.Metal, 0, npcModel)

	-- Chains hanging from belt
	local chainSets = {}
	for i = 1, 3 do
		local links = {}
		local numLinks = 3 + math.random(0, 2)
		for link = 1, numLinks do
			local cl = CreatePart("Chain" .. i .. "_" .. link,
				Vector3.new(0.035 * S, 0.07 * S, 0.025 * S),
				link % 2 == 0 and CFG.CHAIN_RUST or CFG.CHAIN_COLOR,
				Enum.Material.Metal, 0, npcModel)
			table.insert(links, cl)
		end
		table.insert(chainSets, {
			links = links,
			xOff = (i - 2) * 0.35 * S,
			phase = math.random() * math.pi * 2,
		})
	end

	-- FIX #9: Embedded rock fragments protrude from surface (offset outward by half rock depth)
	local embeddedRocks = {}
	local rockDefs = {
		{x = 0.38, y = 0.18, zSide = 1, size = 0.11},
		{x = -0.28, y = -0.12, zSide = 1, size = 0.085},
		{x = 0.12, y = 0.32, zSide = -1, size = 0.095},
		{x = -0.22, y = -0.28, zSide = 1, size = 0.075},
		{x = 0.3, y = -0.05, zSide = -1, size = 0.08},
	}
	for i, rd in ipairs(rockDefs) do
		local rockDepth = rd.size * S * 0.55
		local rock = CreatePart("EmbRock" .. i,
			Vector3.new(rd.size * S, rd.size * S * 0.75, rockDepth),
			math.random() < 0.5 and CFG.ROCK_COLOR or CFG.ROCK_DARK,
			Enum.Material.Slate, 0, npcModel)
		-- Rock center at torso surface + half rock depth (so it sticks out)
		local zOffset = rd.zSide * (torsoD * 0.5 + rockDepth * 0.25)
		table.insert(embeddedRocks, {
			part = rock,
			offset = Vector3.new(rd.x * torsoW, rd.y * torsoH, zOffset),
			rot = CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi),
		})
	end

	-- Pelvis
	local pelvisW = CFG.PELVIS_WIDTH * S
	local pelvisH = CFG.PELVIS_HEIGHT * S
	local pelvisD = CFG.PELVIS_DEPTH * S
	local pelvis = CreatePart("Pelvis", Vector3.new(pelvisW, pelvisH, pelvisD), CFG.OVERALLS_BASE, Enum.Material.Fabric, 0, npcModel)

	-- =========================================================================
	-- NECK  (FIX #2: Cylinder mesh long axis is Part's X axis)
	-- Size = (length, diameter, diameter) so the cylinder is vertical after rotation
	-- =========================================================================

	local neckH = CFG.NECK_HEIGHT * S
	local neckR = CFG.NECK_RADIUS * S
	-- Cylinder mesh: X = long axis. We want vertical, so Size.X = height, Y=Z = diameter
	local neck = CreatePart("Neck", Vector3.new(neckH, neckR * 2, neckR * 2), CFG.SKIN_BASE, Enum.Material.SmoothPlastic, 0, npcModel)
	CreateMesh(neck, Enum.MeshType.Cylinder)

	-- FIX #29: Bandana mesh adjusted - less flat, more like rolled cloth
	local bandana = CreatePart("Bandana", Vector3.new(0.32 * S, 0.12 * S, 0.32 * S),
		Color3.fromRGB(115, 38, 32), Enum.Material.Fabric, 0, npcModel)
	CreateMesh(bandana, Enum.MeshType.Sphere, Vector3.new(1, 0.7, 1))

	-- =========================================================================
	-- HEAD (properly spherical, face details on surface)
	-- =========================================================================

	local headR = CFG.HEAD_RADIUS * S
	local headDiam = headR * 2
	-- Head ellipsoid semi-axes for surface projection
	local headRX = headR          -- half X size
	local headRY = headR * 1.05   -- half Y size (slightly taller)
	local headRZ = headR * 0.95   -- half Z size (slightly flatter)

	local head = CreatePart("Head", Vector3.new(headDiam, headDiam * 1.05, headDiam * 0.95),
		CFG.SKIN_GHOSTLY, Enum.Material.SmoothPlastic, 0, npcModel)
	CreateMesh(head, Enum.MeshType.Sphere, Vector3.new(1, 1.05, 0.95))

	-- FIX #11: Soot marks positioned on ellipsoid surface using proper math
	local sootMarks = {}
	local sootDefs = {
		{nx = 0.22, ny = 0.1, nz = -0.88, sx = 0.18, sy = 0.14},
		{nx = -0.16, ny = -0.06, nz = -0.86, sx = 0.22, sy = 0.1},
		{nx = 0.06, ny = 0.28, nz = -0.82, sx = 0.14, sy = 0.16},
		{nx = -0.32, ny = 0.16, nz = -0.72, sx = 0.11, sy = 0.18},
	}
	for i, sd in ipairs(sootDefs) do
		local soot = CreatePart("Soot" .. i,
			Vector3.new(sd.sx * S, sd.sy * S, 0.01 * S),
			CFG.SKIN_SOOT, Enum.Material.SmoothPlastic, 0.35, npcModel)
		-- Project the desired direction onto the ellipsoid surface
		local px, py, pz = ProjectToEllipsoidSurface(sd.nx, sd.ny, sd.nz, headRX, headRY, headRZ)
		table.insert(sootMarks, {
			part = soot,
			offset = Vector3.new(px, py, pz),
		})
	end

	-- FIX #12: Face burn positioned on sphere surface
	local faceBurn = CreatePart("FaceBurn",
		Vector3.new(0.28 * S, 0.32 * S, 0.015 * S),
		CFG.SKIN_BURNT, Enum.Material.SmoothPlastic, 0.18, npcModel)
	local fbX, fbY, fbZ = ProjectToEllipsoidSurface(0.25, 0.05, -0.9, headRX, headRY, headRZ)
	local faceBurnOffset = Vector3.new(fbX, fbY, fbZ)

	-- LEFT EYE (glowing, ghostly) - on ellipsoid surface
	local leftEye = CreatePart("LeftEye",
		Vector3.new(0.11 * S, 0.13 * S, 0.04 * S),
		CFG.EYE_COLOR, Enum.Material.Neon, 0, npcModel)

	-- FIX #28: Eye light range reduced to avoid illuminating helmet/body
	local leftEyeLight = Instance.new("PointLight")
	leftEyeLight.Brightness = 1.5
	leftEyeLight.Color = CFG.EYE_COLOR
	leftEyeLight.Range = 3 * S
	leftEyeLight.Parent = leftEye

	local leX, leY, leZ = ProjectToEllipsoidSurface(-0.2, 0.12, -0.95, headRX, headRY, headRZ)
	local leftEyeOffset = Vector3.new(leX, leY, leZ)

	-- Left pupil
	local leftPupil = CreatePart("LeftPupil",
		Vector3.new(0.045 * S, 0.06 * S, 0.015 * S),
		Color3.fromRGB(0, 0, 0), Enum.Material.SmoothPlastic, 0, npcModel)

	-- RIGHT EYE - destroyed, covered with patch
	local eyePatch = CreatePart("EyePatch",
		Vector3.new(0.17 * S, 0.15 * S, 0.06 * S),
		Color3.fromRGB(48, 38, 28), Enum.Material.Fabric, 0, npcModel)
	local epX, epY, epZ = ProjectToEllipsoidSurface(0.22, 0.12, -0.92, headRX, headRY, headRZ)
	local eyePatchOffset = Vector3.new(epX, epY, epZ)

	-- FIX #10: Patch strap split into segments that wrap around head surface
	local patchStrapSegments = {}
	local strapSegmentCount = 8
	for seg = 1, strapSegmentCount do
		local strapSeg = CreatePart("PatchStrap" .. seg,
			Vector3.new(0.035 * S, 0.035 * S, 0.035 * S),
			Color3.fromRGB(55, 42, 28), Enum.Material.Fabric, 0, npcModel)
		table.insert(patchStrapSegments, strapSeg)
	end

	-- Mouth
	local mouthX, mouthY, mouthZ = ProjectToEllipsoidSurface(0, -0.25, -0.93, headRX, headRY, headRZ)
	local mouth = CreatePart("Mouth",
		Vector3.new(0.22 * S, 0.075 * S, 0.035 * S),
		Color3.fromRGB(28, 18, 18), Enum.Material.SmoothPlastic, 0, npcModel)
	local mouthOffset = Vector3.new(mouthX, mouthY, mouthZ)

	-- Stubble
	local stbX, stbY, stbZ = ProjectToEllipsoidSurface(0, -0.32, -0.85, headRX, headRY, headRZ)
	local stubble = CreatePart("Stubble",
		Vector3.new(0.28 * S, 0.13 * S, 0.04 * S),
		Color3.fromRGB(62, 58, 52), Enum.Material.SmoothPlastic, 0.45, npcModel)
	local stubbleOffset = Vector3.new(stbX, stbY, stbZ)

	-- =========================================================================
	-- HELMET (sits on top of head, NOT inside it)
	-- =========================================================================

	local helmW = CFG.HELMET_WIDTH * S
	local helmH = CFG.HELMET_HEIGHT * S
	local helmD = CFG.HELMET_DEPTH * S

	local helmet = CreatePart("Helmet", Vector3.new(helmW, helmH, helmD),
		CFG.HELMET_COLOR, Enum.Material.Metal, 0, npcModel)
	CreateMesh(helmet, Enum.MeshType.Sphere, Vector3.new(1, 0.68, 0.95))

	local helmetDent = CreatePart("HelmetDent",
		Vector3.new(0.22 * S, 0.13 * S, 0.06 * S),
		CFG.HELMET_DENTED, Enum.Material.Metal, 0, npcModel)

	local brimW = CFG.HELMET_BRIM_WIDTH * S
	local brimH = CFG.HELMET_BRIM_HEIGHT * S
	local brimD = CFG.HELMET_BRIM_DEPTH * S
	local helmetBrim = CreatePart("HelmetBrim", Vector3.new(brimW, brimH, brimD),
		CFG.HELMET_DENTED, Enum.Material.Metal, 0, npcModel)

	local helmetStrap = CreatePart("HelmetStrap",
		Vector3.new(0.05 * S, 0.45 * S, 0.025 * S),
		CFG.HELMET_STRAP, Enum.Material.Fabric, 0, npcModel)

	-- =========================================================================
	-- LANTERN (mounted on front of helmet)
	-- =========================================================================

	local lantW = CFG.LANTERN_WIDTH * S
	local lantH = CFG.LANTERN_HEIGHT * S
	local lantD = CFG.LANTERN_DEPTH * S

	local lanternHousing = CreatePart("LanternBody", Vector3.new(lantW, lantH, lantD),
		CFG.LANTERN_FRAME, Enum.Material.Metal, 0, npcModel)

	local lanternGlass = CreatePart("LanternGlass",
		Vector3.new(lantW * 0.7, lantH * 0.7, 0.035 * S),
		CFG.LANTERN_GLASS, Enum.Material.Neon, 0.1, npcModel)

	local lanternSpot = Instance.new("SpotLight")
	lanternSpot.Name = "LanternSpot"
	lanternSpot.Brightness = 3.5
	lanternSpot.Color = CFG.LANTERN_GLOW
	lanternSpot.Range = 45 * S
	lanternSpot.Angle = 48
	lanternSpot.Face = Enum.NormalId.Front
	lanternSpot.Shadows = true
	lanternSpot.Parent = lanternGlass

	local lanternPoint = Instance.new("PointLight")
	lanternPoint.Name = "LanternGlow"
	lanternPoint.Brightness = 1.8
	lanternPoint.Color = CFG.LANTERN_GLOW
	lanternPoint.Range = 14 * S
	lanternPoint.Parent = lanternGlass

	-- =========================================================================
	-- PICKAXE (handle + dual heads along handle axis)
	-- FIX #1: Heads extend along the handle axis, not perpendicular
	-- =========================================================================

	local pickFolder = Instance.new("Folder")
	pickFolder.Name = "Pickaxe"
	pickFolder.Parent = npcModel

	local pickHandleW = CFG.PICKAXE_HANDLE_WIDTH * S
	local pickHandleL = CFG.PICKAXE_HANDLE_LENGTH * S
	local pickHeadW = CFG.PICKAXE_HEAD_WIDTH * S
	local pickHeadL = CFG.PICKAXE_HEAD_LENGTH * S
	local pickHeadD = CFG.PICKAXE_HEAD_DEPTH * S

	local pickHandle = CreatePart("PickHandle",
		Vector3.new(pickHandleW, pickHandleL, pickHandleW),
		CFG.PICKAXE_HANDLE, Enum.Material.WoodPlanks, 0, pickFolder)

	-- FIX #1: Pick heads now extend along the handle's Y axis (forward/backward from junction)
	-- Left head (longer, main point) - extends in +Z from junction (one side)
	local pickHeadLeft = CreatePart("PickHeadL",
		Vector3.new(pickHeadD, pickHeadW, pickHeadL),
		CFG.PICKAXE_RUST, Enum.Material.Metal, 0, pickFolder)
	CreateMesh(pickHeadLeft, Enum.MeshType.Wedge)

	-- Right head (shorter, broken tip) - extends in -Z from junction (other side)
	local pickHeadRight = CreatePart("PickHeadR",
		Vector3.new(pickHeadD, pickHeadW, pickHeadL * 0.65),
		CFG.PICKAXE_HEAD, Enum.Material.Metal, 0, pickFolder)
	CreateMesh(pickHeadRight, Enum.MeshType.Wedge)

	-- Junction (where heads meet handle)
	local pickJunction = CreatePart("PickJunct",
		Vector3.new(pickHeadD * 1.3, 0.13 * S, 0.13 * S),
		CFG.PICKAXE_HEAD, Enum.Material.Metal, 0, pickFolder)

	-- Rust spot detail
	local rustSpot = CreatePart("RustSpot",
		Vector3.new(0.07 * S, 0.14 * S, 0.01 * S),
		CFG.PICKAXE_RUST, Enum.Material.SmoothPlastic, 0.3, pickFolder)

	-- FIX #17: Spark emitter on pick HEAD (not handle)
	local sparkEmitter = Instance.new("ParticleEmitter")
	sparkEmitter.Name = "PickSparks"
	sparkEmitter.Texture = "rbxassetid://243098098"
	sparkEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, CFG.SPARK_COLOR),
		ColorSequenceKeypoint.new(1, CFG.EMBER_COLOR),
	})
	sparkEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.07 * S),
		NumberSequenceKeypoint.new(1, 0.015 * S),
	})
	sparkEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkEmitter.Lifetime = NumberRange.new(0.15, 0.45)
	sparkEmitter.Rate = 0
	sparkEmitter.Speed = NumberRange.new(1, 4)
	sparkEmitter.SpreadAngle = Vector2.new(55, 55)
	sparkEmitter.Acceleration = Vector3.new(0, -16, 0)
	sparkEmitter.Parent = pickHeadLeft -- FIX: parented to head, not handle

	-- =========================================================================
	-- ARMS  (FIX #3: Cylinder sizes corrected - X = long axis)
	-- FIX #4: Shoulder gap increased
	-- =========================================================================

	local shoulderR = CFG.SHOULDER_RADIUS * S
	local upperArmW = CFG.UPPER_ARM_WIDTH * S
	local upperArmL = CFG.UPPER_ARM_LENGTH * S
	local elbowR = CFG.ELBOW_RADIUS * S
	local forearmW = CFG.FOREARM_WIDTH * S
	local forearmL = CFG.FOREARM_LENGTH * S
	local wristR = CFG.WRIST_RADIUS * S
	local handW = CFG.HAND_WIDTH * S
	local handH = CFG.HAND_HEIGHT * S
	local handD = CFG.HAND_DEPTH * S

	-- FIX #4: Increased gap to prevent arm clipping into torso during rotation
	local shoulderXOff = torsoW * 0.5 + shoulderR + 0.06 * S
	local shoulderYOff = torsoH * 0.42

	local arms = {}
	for sideNum = -1, 1, 2 do
		local armFolder = Instance.new("Folder")
		armFolder.Name = sideNum == -1 and "LeftArm" or "RightArm"
		armFolder.Parent = npcModel

		local sleeveColor = math.random() < 0.5 and CFG.SHIRT_DIRTY or CFG.SHIRT_BURNT

		local shoulder = CreateBall("Shoulder", shoulderR * 2, CFG.SKIN_BASE, Enum.Material.SmoothPlastic, armFolder)

		-- FIX #3: Cylinder Size.X = long axis (length), Y & Z = diameter
		local upperArm = CreatePart("UpperArm",
			Vector3.new(upperArmL, upperArmW * 2, upperArmW * 2),
			sleeveColor, Enum.Material.Fabric, 0, armFolder)
		CreateMesh(upperArm, Enum.MeshType.Cylinder)

		local elbow = CreateBall("Elbow", elbowR * 2, CFG.SKIN_BASE, Enum.Material.SmoothPlastic, armFolder)

		local forearm = CreatePart("Forearm",
			Vector3.new(forearmL, forearmW * 2, forearmW * 2),
			CFG.SKIN_BASE, Enum.Material.SmoothPlastic, 0, armFolder)
		CreateMesh(forearm, Enum.MeshType.Cylinder)

		local forearmBurn = CreatePart("FABurn",
			Vector3.new(0.08 * S, 0.18 * S, 0.01 * S),
			CFG.SKIN_BURNT, Enum.Material.SmoothPlastic, 0.3, armFolder)

		local wrist = CreateBall("Wrist", wristR * 2, CFG.SKIN_BASE, Enum.Material.SmoothPlastic, armFolder)

		local glove = CreatePart("Glove", Vector3.new(handW, handH, handD),
			CFG.GLOVE_COLOR, Enum.Material.Leather, 0, armFolder)
		CreateMesh(glove, Enum.MeshType.Sphere, Vector3.new(1, 0.5, 1.1))

		-- Fingers
		local fingers = {}
		for f = 1, 4 do
			local finger = CreatePart("Finger" .. f,
				Vector3.new(0.035 * S, 0.11 * S, 0.035 * S),
				CFG.GLOVE_WORN, Enum.Material.Leather, 0, armFolder)
			table.insert(fingers, {part = finger, xOff = (f - 2.5) * 0.055 * S})
		end

		local thumb = CreatePart("Thumb",
			Vector3.new(0.04 * S, 0.09 * S, 0.04 * S),
			CFG.GLOVE_WORN, Enum.Material.Leather, 0, armFolder)

		table.insert(arms, {
			folder = armFolder,
			shoulder = shoulder,
			upperArm = upperArm,
			elbow = elbow,
			forearm = forearm,
			forearmBurn = forearmBurn,
			wrist = wrist,
			glove = glove,
			fingers = fingers,
			thumb = thumb,
			side = sideNum,
		})
	end

	-- =========================================================================
	-- LEGS  (FIX #3: Cylinder sizes corrected)
	-- =========================================================================

	local hipR = CFG.HIP_RADIUS * S
	local thighW = CFG.THIGH_WIDTH * S
	local thighL = CFG.THIGH_LENGTH * S
	local kneeR = CFG.KNEE_RADIUS * S
	local shinW = CFG.SHIN_WIDTH * S
	local shinL = CFG.SHIN_LENGTH * S
	local ankleR = CFG.ANKLE_RADIUS * S
	local bootW = CFG.BOOT_WIDTH * S
	local bootH = CFG.BOOT_HEIGHT * S
	local bootD = CFG.BOOT_DEPTH * S
	local bootSoleH = CFG.BOOT_SOLE_HEIGHT * S

	local hipXOff = pelvisW * 0.35

	local legs = {}
	for sideNum = -1, 1, 2 do
		local legFolder = Instance.new("Folder")
		legFolder.Name = sideNum == -1 and "LeftLeg" or "RightLeg"
		legFolder.Parent = npcModel

		local isDamaged = sideNum == 1
		local overallsColor = isDamaged and CFG.OVERALLS_BURNT or CFG.OVERALLS_BASE

		local hip = CreateBall("Hip", hipR * 2, overallsColor, Enum.Material.Fabric, legFolder)

		-- FIX #3: Cylinder Size.X = long axis
		local thigh = CreatePart("Thigh",
			Vector3.new(thighL, thighW * 2, thighW * 2),
			overallsColor, Enum.Material.Fabric, 0, legFolder)
		CreateMesh(thigh, Enum.MeshType.Cylinder)

		local knee = CreateBall("Knee", kneeR * 2, CFG.SKIN_BASE, Enum.Material.SmoothPlastic, legFolder)

		local shin = CreatePart("Shin",
			Vector3.new(shinL, shinW * 2, shinW * 2),
			overallsColor, Enum.Material.Fabric, 0, legFolder)
		CreateMesh(shin, Enum.MeshType.Cylinder)

		local ankle = CreateBall("Ankle", ankleR * 2, CFG.SKIN_BASE, Enum.Material.SmoothPlastic, legFolder)

		local boot = CreatePart("Boot", Vector3.new(bootW, bootH, bootD),
			CFG.BOOT_COLOR, Enum.Material.Leather, 0, legFolder)

		local bootSole = CreatePart("BootSole",
			Vector3.new(bootW * 1.05, bootSoleH, bootD * 1.05),
			CFG.BOOT_SOLE, Enum.Material.SmoothPlastic, 0, legFolder)

		local bandage = nil
		if isDamaged then
			bandage = CreatePart("Bandage",
				Vector3.new(shinW * 2.6, 0.18 * S, shinW * 2.6),
				Color3.fromRGB(158, 142, 118),
				Enum.Material.Fabric, 0, legFolder)
		end

		table.insert(legs, {
			folder = legFolder,
			hip = hip,
			thigh = thigh,
			knee = knee,
			shin = shin,
			ankle = ankle,
			boot = boot,
			bootSole = bootSole,
			bandage = bandage,
			side = sideNum,
			isDamaged = isDamaged,
		})
	end

	-- =========================================================================
	-- PARTICLES
	-- =========================================================================

	local coalDustEmitter = Instance.new("ParticleEmitter")
	coalDustEmitter.Name = "CoalDust"
	coalDustEmitter.Texture = "rbxassetid://243098098"
	coalDustEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, CFG.COAL_DUST),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(52, 48, 42)),
	})
	coalDustEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08 * S),
		NumberSequenceKeypoint.new(0.5, 0.25 * S),
		NumberSequenceKeypoint.new(1, 0.45 * S),
	})
	coalDustEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.72),
		NumberSequenceKeypoint.new(1, 1),
	})
	coalDustEmitter.Lifetime = NumberRange.new(0.8, 1.6)
	coalDustEmitter.Rate = 4
	coalDustEmitter.Speed = NumberRange.new(0.08, 0.35)
	coalDustEmitter.SpreadAngle = Vector2.new(180, 180)
	coalDustEmitter.Acceleration = Vector3.new(0, -2, 0)
	coalDustEmitter.RotSpeed = NumberRange.new(-15, 15)
	coalDustEmitter.Parent = torso

	local emberEmitter = Instance.new("ParticleEmitter")
	emberEmitter.Name = "Embers"
	emberEmitter.Texture = "rbxassetid://243098098"
	emberEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, CFG.EMBER_COLOR),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(195, 75, 18)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(75, 28, 8)),
	})
	emberEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.035 * S),
		NumberSequenceKeypoint.new(1, 0.008 * S),
	})
	emberEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	emberEmitter.Lifetime = NumberRange.new(0.4, 0.9)
	emberEmitter.Rate = 2
	emberEmitter.Speed = NumberRange.new(0.04, 0.18)
	emberEmitter.Acceleration = Vector3.new(0, -6, 0)
	emberEmitter.Parent = torso

	local ghostGlow = Instance.new("ParticleEmitter")
	ghostGlow.Name = "GhostGlow"
	ghostGlow.Texture = "rbxassetid://243098098"
	ghostGlow.Color = ColorSequence.new(CFG.GHOST_GLOW)
	ghostGlow.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15 * S),
		NumberSequenceKeypoint.new(0.5, 0.4 * S),
		NumberSequenceKeypoint.new(1, 0.7 * S),
	})
	ghostGlow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.88),
		NumberSequenceKeypoint.new(0.5, 0.94),
		NumberSequenceKeypoint.new(1, 1),
	})
	ghostGlow.Lifetime = NumberRange.new(0.25, 0.55)
	ghostGlow.Rate = 3
	ghostGlow.Speed = NumberRange.new(0.04, 0.12)
	ghostGlow.SpreadAngle = Vector2.new(360, 360)
	ghostGlow.Parent = torso

	-- =========================================================================
	-- STATE VARIABLES
	-- =========================================================================

	local npcX = spawnPosition.X
	local npcZ = spawnPosition.Z
	local npcRotation = zDir > 0 and 0 or math.pi

	local animTime = 0
	local breathTime = 0
	local currentState = CFG.STATE_IDLE
	local stateTimer = 0
	local isWalking = false
	local isAttacking = false
	local currentSpeed = CFG.SPEED_IDLE
	local lastFlickerTime = 0

	-- FIX #14: pickaxeSwingAngle now updated via a target value + lerp each frame
	local pickaxeSwingAngle = 0
	local pickaxeSwingTarget = 0

	-- FIX #19: Track last footstep for proper sync
	local lastFootstepSide = 0 -- -1 = left, 1 = right

	-- Declare bootstepSound BEFORE UpdateNPCPosition (which references it)
	local bootstepSound = Instance.new("Sound")
	bootstepSound.SoundId = "rbxassetid://124605353623000"
	bootstepSound.Volume = 0.28
	bootstepSound.PlaybackSpeed = 1.15
	bootstepSound.Parent = torso

	-- =========================================================================
	-- POSITION UPDATE FUNCTION (the core of the visual system)
	-- =========================================================================

	local function UpdateNPCPosition(x, z, rotY, walking, deltaTime, targetDistance, targetPos)
		npcX = x
		npcZ = z
		npcRotation = rotY or npcRotation
		isWalking = walking or false

		if deltaTime then
			animTime = animTime + deltaTime * 4
			breathTime = breathTime + deltaTime * 2
			-- FIX #16: Wrap to prevent float precision loss
			if animTime > ANIM_WRAP_PERIOD then
				animTime = animTime - ANIM_WRAP_PERIOD
			end
			if breathTime > ANIM_WRAP_PERIOD then
				breathTime = breathTime - ANIM_WRAP_PERIOD
			end
		end

		-- FIX #14: Smoothly interpolate pickaxe angle (frame-synced, no race condition)
		pickaxeSwingAngle = pickaxeSwingAngle + (pickaxeSwingTarget - pickaxeSwingAngle) * math.min(1, (deltaTime or 0.016) * 20)

		-- FIX #24: Update groundY via raycast each frame
		groundY = RaycastDown(x, z, npcFilterList)

		-- Limp calculation
		local limpOffset = 0
		local limpTilt = 0
		if isWalking then
			local limpCycle = math.sin(animTime * CFG.LIMP_SPEED)
			limpOffset = math.max(0, limpCycle) * CFG.LIMP_INTENSITY * S
			limpTilt = limpCycle * math.rad(3.5)
		end

		local walkBob = isWalking and math.sin(animTime * 2) * 0.055 * S or 0
		local breathBob = math.sin(breathTime) * 0.018 * S

		-- Calculate torso Y from ground up
		local torsoY = groundY + bootH + bootSoleH + shinL + thighL * 0.5 + torsoH * 0.5

		local baseCFrame = CFrame.new(x, torsoY + walkBob + breathBob - limpOffset, z)
			* CFrame.Angles(0, npcRotation, 0)
			* CFrame.Angles(math.rad(4), 0, limpTilt)

		-- -------------------------------------------------------------------
		-- TORSO
		-- -------------------------------------------------------------------
		torso.CFrame = baseCFrame

		strapLeft.CFrame = baseCFrame * CFrame.new(-torsoW * 0.28, 0.04 * S, strapZOff)
		strapRight.CFrame = baseCFrame * CFrame.new(torsoW * 0.28, 0.04 * S, strapZOff)

		shirtVisible.CFrame = baseCFrame * CFrame.new(0, torsoH * 0.2, -(torsoD * 0.5 + 0.01 * S))

		burnMark.CFrame = baseCFrame * CFrame.new(0.18 * S, -0.08 * S, -(torsoD * 0.5 + 0.008 * S))

		for _, fab in ipairs(tornFabrics) do
			local sway = math.sin(breathTime * 1.5 + fab.phase) * math.rad(12)
			fab.part.CFrame = baseCFrame
				* CFrame.new(fab.xOff, fab.yOff, fab.zSide * (torsoD * 0.5 + 0.01 * S))
				* CFrame.Angles(sway, 0, sway * 0.4)
		end

		-- FIX #7/#8: Belt and buckle properly positioned
		local beltY = -torsoH * 0.38
		toolBelt.CFrame = baseCFrame * CFrame.new(0, beltY, 0)
		buckle.CFrame = baseCFrame * CFrame.new(0, beltY, -(torsoD * 0.5 + 0.018 * S))

		for _, chain in ipairs(chainSets) do
			local chainSway = math.sin(breathTime * 1.2 + chain.phase)
			local prevCF = baseCFrame * CFrame.new(chain.xOff, beltY - beltH * 0.5, -(torsoD * 0.38))
			for j, link in ipairs(chain.links) do
				local linkSway = chainSway * math.rad(7 + j * 2.5)
				prevCF = prevCF * CFrame.new(0, -0.055 * S, 0) * CFrame.Angles(linkSway, 0, 0)
				link.CFrame = prevCF
			end
		end

		-- FIX #9: Embedded rocks on torso surface (protruding)
		for _, rock in ipairs(embeddedRocks) do
			rock.part.CFrame = baseCFrame * CFrame.new(rock.offset) * rock.rot
		end

		-- Pelvis
		local pelvisCF = baseCFrame * CFrame.new(0, -(torsoH * 0.5 + pelvisH * 0.5), 0)
		pelvis.CFrame = pelvisCF

		-- -------------------------------------------------------------------
		-- NECK & HEAD
		-- -------------------------------------------------------------------
		local neckBottom = baseCFrame * CFrame.new(0, torsoH * 0.5, 0)
		local neckCF = neckBottom * CFrame.new(0, neckH * 0.5, 0)
		-- FIX #2: Cylinder mesh X = long axis, rotate 90° on Z to make vertical
		neck.CFrame = neckCF * CFrame.Angles(0, 0, math.rad(90))
		bandana.CFrame = neckCF * CFrame.new(0, -0.01 * S, 0)

		local headTilt = math.rad(-6) + math.sin(breathTime * 0.8) * math.rad(2)
		local headCF = neckBottom * CFrame.new(0, neckH + headRY, 0) * CFrame.Angles(headTilt, 0, 0)
		head.CFrame = headCF

		-- FIX #11: Soot on ellipsoid surface
		for _, soot in ipairs(sootMarks) do
			soot.part.CFrame = headCF * CFrame.new(soot.offset)
		end

		-- FIX #12: Face burn on surface
		faceBurn.CFrame = headCF * CFrame.new(faceBurnOffset)

		-- Left eye on surface
		leftEye.CFrame = headCF * CFrame.new(leftEyeOffset)
		leftPupil.CFrame = leftEye.CFrame * CFrame.new(0, 0, -(0.02 * S))

		-- Eye patch on surface
		eyePatch.CFrame = headCF * CFrame.new(eyePatchOffset)

		-- FIX #10: Patch strap wraps around head surface as segments
		local patchY = epY -- same Y height as the eye patch
		for seg = 1, strapSegmentCount do
			-- Distribute segments around the head horizontally at the patch's Y level
			-- Goes from the patch on the front-right, around the right side, across the back, to left
			local angle = (seg / strapSegmentCount) * math.pi * 2
			local sx, sy, sz = ProjectToEllipsoidSurface(math.sin(angle), patchY / headRY, -math.cos(angle), headRX, headRY, headRZ)
			-- Nudge outward slightly so strap sits on surface, not inside
			local nudge = 0.018 * S
			local segLen = math.sqrt(sx*sx + sy*sy + sz*sz)
			if segLen > 0.001 then
				sx = sx + sx/segLen * nudge
				sy = sy + sy/segLen * nudge
				sz = sz + sz/segLen * nudge
			end
			patchStrapSegments[seg].CFrame = headCF * CFrame.new(sx, sy, sz)
		end

		-- Mouth on surface
		mouth.CFrame = headCF * CFrame.new(mouthOffset)

		-- Stubble on surface
		stubble.CFrame = headCF * CFrame.new(stubbleOffset)

		-- -------------------------------------------------------------------
		-- HELMET (on top of head, not clipping into it)
		-- -------------------------------------------------------------------
		local helmetCF = headCF * CFrame.new(0, headRY * 0.75 + helmH * 0.15, -0.02 * S)
			* CFrame.Angles(math.rad(-7), 0, math.rad(3))

		helmet.CFrame = helmetCF
		helmetDent.CFrame = helmetCF * CFrame.new(0.2 * S, helmH * 0.2, -0.12 * S)
		helmetBrim.CFrame = helmetCF * CFrame.new(0, -helmH * 0.35, -helmD * 0.18)

		-- Chin strap (hangs broken from right side)
		helmetStrap.CFrame = helmetCF * CFrame.new(
			helmW * 0.42,
			-helmH * 0.5 - 0.08 * S,
			0
		) * CFrame.Angles(0, 0, math.rad(14) + math.sin(breathTime) * math.rad(4))

		-- Lantern on FRONT of helmet (outside helmet surface)
		local lanternCF = helmetCF * CFrame.new(0, helmH * 0.08, -(helmD * 0.5 + lantD * 0.4))
		lanternHousing.CFrame = lanternCF
		lanternGlass.CFrame = lanternCF * CFrame.new(0, 0, -(lantD * 0.35 + 0.02 * S))

		-- Lantern flicker logic
		local timeSinceFlicker = breathTime - lastFlickerTime
		local nextFlicker = CFG.LANTERN_FLICKER_MIN + math.random() * (CFG.LANTERN_FLICKER_MAX - CFG.LANTERN_FLICKER_MIN)
		if timeSinceFlicker > nextFlicker then
			lastFlickerTime = breathTime
			coroutine.wrap(function()
				local count = math.random(2, 5)
				for _ = 1, count do
					lanternSpot.Brightness = 0.2
					lanternPoint.Brightness = 0.3
					lanternGlass.Transparency = 0.7
					task.wait(0.04 + math.random() * 0.07)
					lanternSpot.Brightness = 3.5
					lanternPoint.Brightness = 1.8
					lanternGlass.Transparency = 0.1
					task.wait(0.025 + math.random() * 0.05)
				end
				if math.random() < 0.28 then
					lanternSpot.Brightness = 0
					lanternPoint.Brightness = 0
					lanternGlass.Transparency = 0.9
					task.wait(0.4 + math.random() * 0.9)
					lanternSpot.Brightness = 3.5
					lanternPoint.Brightness = 1.8
					lanternGlass.Transparency = 0.1
				end
			end)()
		end

		-- -------------------------------------------------------------------
		-- ARMS  (pickaxe faces FORWARD, FIX #3 cylinder orientation)
		-- -------------------------------------------------------------------

		for _, arm in ipairs(arms) do
			local armPhase = arm.side == -1 and 0 or math.pi
			local walkSwing = isWalking and math.sin(animTime + armPhase) * math.rad(22) or 0

			local isPickaxeArm = arm.side == 1

			local sCF = baseCFrame * CFrame.new(
				arm.side * shoulderXOff,
				shoulderYOff,
				0
			)
			arm.shoulder.CFrame = sCF

			-- UPPER ARM angles
			local upperPitch
			local upperOutward

			if isPickaxeArm then
				if isWalking and not isAttacking then
					upperPitch = math.rad(-75) + pickaxeSwingAngle * 0.3
					upperOutward = math.rad(8)
				elseif isAttacking then
					upperPitch = math.rad(-30) + pickaxeSwingAngle * 0.5
					upperOutward = math.rad(12)
				else
					upperPitch = math.rad(-15) + pickaxeSwingAngle * 0.5
					upperOutward = math.rad(12)
				end
			else
				upperPitch = math.rad(-6) + walkSwing
				upperOutward = math.rad(12)
			end

			local uaCF = sCF
				* CFrame.Angles(upperPitch, 0, arm.side * upperOutward)
				* CFrame.new(0, -upperArmL * 0.5, 0)
			-- FIX #3: Cylinder X = long axis, so rotate 90° on Z to orient vertically
			arm.upperArm.CFrame = uaCF * CFrame.Angles(0, 0, math.rad(90))

			-- ELBOW
			local elbowCF = uaCF * CFrame.new(0, -upperArmL * 0.5, 0)
			arm.elbow.CFrame = elbowCF

			-- FOREARM angles
			local forearmPitch
			if isPickaxeArm then
				if isWalking and not isAttacking then
					forearmPitch = math.rad(-30) + pickaxeSwingAngle * 0.6
				elseif isAttacking then
					forearmPitch = math.rad(-50) + pickaxeSwingAngle * 0.8
				else
					forearmPitch = math.rad(-20) + pickaxeSwingAngle * 0.8
				end
			else
				forearmPitch = math.rad(-12) + math.abs(walkSwing) * 0.3
			end

			local faCF = elbowCF
				* CFrame.Angles(forearmPitch, 0, 0)
				* CFrame.new(0, -forearmL * 0.5, 0)
			-- FIX #3: Same cylinder fix for forearm
			arm.forearm.CFrame = faCF * CFrame.Angles(0, 0, math.rad(90))

			-- Forearm burn
			arm.forearmBurn.CFrame = faCF * CFrame.new(
				arm.side * 0.04 * S,
				-0.08 * S,
				-(forearmW + 0.005 * S)
			)

			-- WRIST
			local wristCF = faCF * CFrame.new(0, -forearmL * 0.5, 0)
			arm.wrist.CFrame = wristCF

			-- GLOVE/HAND
			local gloveCF = wristCF * CFrame.new(0, -(handH * 0.5 + 0.02 * S), 0)
			arm.glove.CFrame = gloveCF

			-- FIX #15: Fingers curl around pickaxe handle when holding
			if isPickaxeArm then
				-- Fingers wrap around the handle (curled grip)
				for _, finger in ipairs(arm.fingers) do
					finger.part.CFrame = gloveCF * CFrame.new(
						finger.xOff,
						-(handH * 0.5 + 0.02 * S),
						-0.04 * S
					) * CFrame.Angles(math.rad(70), 0, 0) -- curled around handle
				end
				-- Thumb wraps from opposite side
				arm.thumb.CFrame = gloveCF * CFrame.new(
					arm.side * (handW * 0.5 + 0.02 * S),
					-handH * 0.3,
					-0.02 * S
				) * CFrame.Angles(math.rad(55), 0, arm.side * math.rad(-30))
			else
				-- Non-pickaxe hand: relaxed fingers
				for _, finger in ipairs(arm.fingers) do
					finger.part.CFrame = gloveCF * CFrame.new(
						finger.xOff,
						-(handH * 0.5 + 0.03 * S),
						-0.04 * S
					) * CFrame.Angles(math.rad(25), 0, 0)
				end
				arm.thumb.CFrame = gloveCF * CFrame.new(
					arm.side * (handW * 0.5 + 0.02 * S),
					-handH * 0.3,
					-0.02 * S
				) * CFrame.Angles(math.rad(15), 0, arm.side * math.rad(20))
			end

			-- -----------------------------------------------------------
			-- PICKAXE POSITIONING (RIGHT ARM) - FORWARD DIRECTION
			-- FIX #1: Pick heads along handle axis
			-- -----------------------------------------------------------
			if isPickaxeArm then
				local handEndCF = gloveCF * CFrame.new(0, -(handH * 0.5), 0)

				local pickBaseCF = handEndCF * CFrame.Angles(math.rad(-90) + pickaxeSwingAngle, 0, 0)

				-- Handle extends forward from hand
				pickHandle.CFrame = pickBaseCF * CFrame.new(0, pickHandleL * 0.5, 0)

				-- Pick head at the far end of handle
				local pickTipCF = pickBaseCF * CFrame.new(0, pickHandleL, 0)
				pickJunction.CFrame = pickTipCF

				-- FIX #1: Wedge heads extend sideways from junction (like a real pickaxe T-shape)
				-- but oriented so the points go left/right when viewed from the handle axis
				-- Left head: point goes to the left (+X local of junction)
				pickHeadLeft.CFrame = pickTipCF
					* CFrame.new(0, 0, 0)
					* CFrame.Angles(0, 0, math.rad(90))  -- rotate wedge so point extends along X
					* CFrame.new(pickHeadL * 0.5, 0, 0)   -- offset to one side

				-- Right head: point goes to the right (-X local of junction)
				pickHeadRight.CFrame = pickTipCF
					* CFrame.new(0, 0, 0)
					* CFrame.Angles(0, 0, math.rad(-90))
					* CFrame.new(-pickHeadL * 0.65 * 0.5, 0, 0)

				rustSpot.CFrame = pickHeadLeft.CFrame * CFrame.new(0.025 * S, 0.08 * S, 0)

				-- FIX #18: Sparks only when pick tip is near ground
				if isWalking and not isAttacking then
					local tipY = pickTipCF.Position.Y
					sparkEmitter.Rate = tipY < groundY + 0.8 * S and 18 or 0
				else
					sparkEmitter.Rate = 0
				end
			end
		end

		-- -------------------------------------------------------------------
		-- LEGS  (FIX #5: Boots follow ankle, FIX #6: Sole below boot,
		--        FIX #13: Limp propagates to leg chain)
		-- -------------------------------------------------------------------
		for _, leg in ipairs(legs) do
			local legPhase = leg.side == -1 and 0 or math.pi
			local walkCycle = isWalking and math.sin(animTime + legPhase) or 0

			local swingMult = leg.isDamaged and 0.45 or 1.0
			local legSwing = walkCycle * math.rad(28) * swingMult

			-- FIX #13: Apply limp offset to damaged leg's hip position
			local legLimpOffset = 0
			if leg.isDamaged and isWalking then
				legLimpOffset = limpOffset * 0.5 -- leg shortens proportionally with torso dip
			end

			-- HIP
			local hipCF = baseCFrame * CFrame.new(
				leg.side * hipXOff,
				-(torsoH * 0.5 + pelvisH * 0.3),
				0
			)
			leg.hip.CFrame = hipCF

			-- THIGH
			local thighPitch = legSwing
			if leg.isDamaged then thighPitch = thighPitch + math.rad(7) end

			local thighCF = hipCF
				* CFrame.Angles(thighPitch, 0, leg.side * math.rad(2.5))
				* CFrame.new(0, -thighL * 0.5, 0)
			-- FIX #3: Cylinder orientation
			leg.thigh.CFrame = thighCF * CFrame.Angles(0, 0, math.rad(90))

			-- KNEE
			local kneeCF = thighCF * CFrame.new(0, -thighL * 0.5, 0)
			leg.knee.CFrame = kneeCF

			-- SHIN
			local shinPitch = math.rad(-4)
			if isWalking then
				local kneeFlexion = math.max(0, -walkCycle) * math.rad(35) * swingMult
				shinPitch = shinPitch - kneeFlexion
			end
			if leg.isDamaged then
				shinPitch = shinPitch + math.rad(10)
				-- FIX #13: Additional knee bend to compensate for torso drop
				if isWalking then
					shinPitch = shinPitch + legLimpOffset * 0.3
				end
			end

			local shinCF = kneeCF
				* CFrame.Angles(shinPitch, 0, 0)
				* CFrame.new(0, -shinL * 0.5, 0)
			-- FIX #3: Cylinder orientation
			leg.shin.CFrame = shinCF * CFrame.Angles(0, 0, math.rad(90))

			-- Bandage on damaged shin
			if leg.bandage then
				leg.bandage.CFrame = shinCF * CFrame.new(0, -0.12 * S, 0)
			end

			-- ANKLE
			local ankleCF = shinCF * CFrame.new(0, -shinL * 0.5, 0)
			leg.ankle.CFrame = ankleCF

			-- FIX #5: Boot follows ankle position (not locked to ground)
			local bootCF = ankleCF * CFrame.new(0, -(bootH * 0.5), 0)
				* CFrame.Angles(-thighPitch - shinPitch, 0, 0) -- counter-rotate to keep boot level
				* CFrame.Angles(0, 0, leg.isDamaged and math.rad(4) or 0)

			leg.boot.CFrame = bootCF

			-- FIX #6: Boot sole positioned BELOW boot (no overlap)
			leg.bootSole.CFrame = bootCF * CFrame.new(0, -(bootH * 0.5 + bootSoleH * 0.5), 0)
		end

		-- FIX #19: Bootstep sound synced to walk cycle
		if isWalking and not isAttacking then
			local currentWalkCycle = math.sin(animTime)
			local currentSide = currentWalkCycle > 0 and 1 or -1
			if currentSide ~= lastFootstepSide and math.abs(currentWalkCycle) < 0.15 then
				-- Foot is planting (crossing zero)
				lastFootstepSide = currentSide
				if not bootstepSound.Playing then
					bootstepSound:Play()
				end
			end
		end
	end

	-- Initial position
	UpdateNPCPosition(npcX, npcZ, npcRotation, false, 0.016, 999, nil)

	-- =========================================================================
	-- SOUNDS
	-- =========================================================================

	local breathingSound = Instance.new("Sound")
	breathingSound.SoundId = "rbxassetid://85565102538331"
	breathingSound.Volume = 0.05
	breathingSound.Looped = true
	breathingSound.PlaybackSpeed = 0.55
	breathingSound.Parent = head
	breathingSound:Play()

	local chainSound = Instance.new("Sound")
	chainSound.SoundId = "rbxassetid://9114120101"
	chainSound.Volume = 0.04
	chainSound.Looped = true
	chainSound.PlaybackSpeed = 0.65
	chainSound.Parent = torso
	chainSound:Play()

	local pickDragSound = Instance.new("Sound")
	pickDragSound.SoundId = "rbxassetid://5766332557"
	pickDragSound.Volume = 0.0
	pickDragSound.Looped = true
	pickDragSound.PlaybackSpeed = 0.25
	pickDragSound.Parent = pickHandle
	pickDragSound:Play()

	local groanSound = Instance.new("Sound")
	groanSound.SoundId = "rbxassetid://9114221580"
	groanSound.Volume = 0.03
	groanSound.PlaybackSpeed = 0.32
	groanSound.Parent = head

	local pickaxeHitSound = Instance.new("Sound")
	pickaxeHitSound.SoundId = "rbxassetid://5766332557"
	pickaxeHitSound.Volume = 0.1
	pickaxeHitSound.PlaybackSpeed = 1.5
	pickaxeHitSound.Parent = pickHandle

	local heavySwingSound = Instance.new("Sound")
	heavySwingSound.SoundId = "rbxassetid://5766332557"
	heavySwingSound.Volume = 0.2
	heavySwingSound.PlaybackSpeed = 0.75
	heavySwingSound.Parent = pickHandle

	-- FIX #20: Reusable ambient groan sound (no new instances each time)
	local ambientGroan = Instance.new("Sound")
	ambientGroan.SoundId = "rbxassetid://9114221580"
	ambientGroan.Volume = 0.05
	ambientGroan.PlaybackSpeed = 0.28
	ambientGroan.Parent = head

	-- =========================================================================
	-- DIALOGUE SUBTITLES AT SPAWN
	-- =========================================================================

	local function PlayMinerDialogue()
		for _, line in ipairs(CFG.DIALOGUE_LINES) do
			task.delay(line.delay, function()
				for _, player in pairs(Players:GetPlayers()) do
					local char = player.Character
					if char then
						local hrp = char:FindFirstChild("HumanoidRootPart")
						if hrp then
							local dist = (hrp.Position - Vector3.new(npcX, hrp.Position.Y, npcZ)).Magnitude
							if dist < 150 then
								ShowSubtitleEvent:FireClient(player, line.text, line.duration, "TheMiner")
							end
						end
					end
				end
			end)
		end
	end

	PlayMinerDialogue()

	-- =========================================================================
	-- PICKAXE ATTACK FUNCTION
	-- FIX #14: Uses pickaxeSwingTarget instead of directly setting angle
	-- =========================================================================

	local lastAttackTime = 0
	local lastHeavySwingTime = -CFG.HEAVY_SWING_COOLDOWN

	local function PerformPickaxeSwing(targetPlayer, isHeavy)
		if isAttacking then return end
		if tick() - lastAttackTime < CFG.ATTACK_COOLDOWN then return end

		isAttacking = true
		lastAttackTime = tick()

		local damage = isHeavy and CFG.DAMAGE_HEAVY_SWING or CFG.DAMAGE_PICKAXE
		local swingDuration = isHeavy and 0.6 or 0.35
		local swingAngle = isHeavy and math.rad(120) or math.rad(80)

		-- WIND UP: raise the pickaxe overhead (set target, frame lerp handles smoothing)
		local liftSteps = 8
		for step = 1, liftSteps do
			local progress = step / liftSteps
			pickaxeSwingTarget = -swingAngle * progress
			task.wait(swingDuration * 0.4 / liftSteps)
		end

		-- STRIKE DOWN
		if isHeavy then
			heavySwingSound:Play()
			sparkEmitter.Rate = 55
		else
			pickaxeHitSound:Play()
			sparkEmitter.Rate = 28
		end

		local strikeSteps = 6
		for step = 1, strikeSteps do
			local progress = step / strikeSteps
			local eased = progress * progress
			pickaxeSwingTarget = -swingAngle + (swingAngle + math.rad(25)) * eased
			task.wait(swingDuration * 0.3 / strikeSteps)
		end

		-- APPLY DAMAGE
		local char = targetPlayer.Character
		if char then
			local hum = char:FindFirstChild("Humanoid")
			local hrp = char:FindFirstChild("HumanoidRootPart")

			if hum and hum.Health > 0 and hrp then
				-- FIX #21: Use 2D distance for attack range check too
				local dist2D = Vector2.new(hrp.Position.X - npcX, hrp.Position.Z - npcZ).Magnitude
				if dist2D < CFG.PICKAXE_RANGE then
					hum:TakeDamage(damage)

					-- FIX #25: Knockback uses LinearVelocity + Attachment (not deprecated BodyVelocity)
					if isHeavy then
						lastHeavySwingTime = tick()
						local knockDir = (hrp.Position - Vector3.new(npcX, hrp.Position.Y, npcZ)).Unit

						local attachment = Instance.new("Attachment")
						attachment.Name = "KnockbackAttachment"
						attachment.Parent = hrp

						local linearVel = Instance.new("LinearVelocity")
						linearVel.Name = "KnockbackVelocity"
						linearVel.Attachment0 = attachment
						linearVel.VectorVelocity = knockDir * 52 + Vector3.new(0, 22, 0)
						linearVel.MaxForce = math.huge
						linearVel.RelativeTo = Enum.ActuatorRelativeTo.World
						linearVel.Parent = hrp

						Debris:AddItem(linearVel, 0.2)
						Debris:AddItem(attachment, 0.25)
					end
				end
			end
		end

		-- RECOVERY: return to neutral
		task.wait(swingDuration * 0.3)

		local returnSteps = 10
		for step = 1, returnSteps do
			local progress = step / returnSteps
			pickaxeSwingTarget = math.rad(25) * (1 - progress)
			task.wait(0.3 / returnSteps)
		end

		pickaxeSwingTarget = 0
		sparkEmitter.Rate = 0
		isAttacking = false
	end

	-- =========================================================================
	-- DEATH EFFECT
	-- =========================================================================

	local function PlayDeathEffect()
		coalDustEmitter.Enabled = false
		emberEmitter.Enabled = false
		ghostGlow.Enabled = false
		sparkEmitter.Rate = 0
		breathingSound:Stop()
		chainSound:Stop()
		pickDragSound:Stop()

		-- Final death groan
		local deathGroan = Instance.new("Sound")
		deathGroan.SoundId = "rbxassetid://72245886498891"
		deathGroan.Volume = 1.0
		deathGroan.PlaybackSpeed = 0.55
		deathGroan.Parent = head
		deathGroan:Play()

		-- Lantern goes haywire then dies
		coroutine.wrap(function()
			for _ = 1, 12 do
				lanternSpot.Brightness = math.random() < 0.5 and 4 or 0
				lanternPoint.Brightness = math.random() < 0.5 and 2 or 0
				lanternGlass.Transparency = math.random() < 0.5 and 0.1 or 0.9
				task.wait(0.04 + math.random() * 0.08)
			end
			lanternSpot.Brightness = 0
			lanternPoint.Brightness = 0
			lanternGlass.Transparency = 1
		end)()

		-- Ghost eye fades
		TweenService:Create(leftEye, TweenInfo.new(0.8), {Transparency = 1}):Play()
		TweenService:Create(leftEyeLight, TweenInfo.new(0.8), {Brightness = 0}):Play()

		task.wait(0.8)

		-- Disintegrate into coal dust
		local deathDust = Instance.new("ParticleEmitter")
		deathDust.Texture = "rbxassetid://243098098"
		deathDust.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, CFG.COAL_DUST),
			ColorSequenceKeypoint.new(0.5, CFG.EMBER_COLOR),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(48, 42, 38)),
		})
		deathDust.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25 * S),
			NumberSequenceKeypoint.new(0.5, 0.75 * S),
			NumberSequenceKeypoint.new(1, 1.4 * S),
		})
		deathDust.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
		deathDust.Lifetime = NumberRange.new(0.5, 1.2)
		deathDust.Rate = 120
		deathDust.Speed = NumberRange.new(2, 7)
		deathDust.SpreadAngle = Vector2.new(360, 360)
		deathDust.RotSpeed = NumberRange.new(-40, 40)
		deathDust.Parent = torso

		-- Fade and sink all parts (npcModel includes pickFolder since it's a child)
		for _, part in pairs(npcModel:GetDescendants()) do
			if part:IsA("BasePart") then
				TweenService:Create(part, TweenInfo.new(1.0, Enum.EasingStyle.Quad), {
					Transparency = 1,
					Position = part.Position + Vector3.new(
						(math.random() - 0.5) * 0.35 * S,
						-0.6 * S,
						(math.random() - 0.5) * 0.35 * S
					),
				}):Play()
			end
		end

		task.wait(1.3)

		deathDust.Enabled = false
		Debris:AddItem(deathGroan, 3)
	end

	-- =========================================================================
	-- AI - MAIN LOGIC
	-- =========================================================================

	local isAlive = true
	local lastSeenPosition = nil

	-- FIX #21: FindNearestPlayer uses 2D distance (ignores Y)
	local function FindNearestPlayer()
		local nearest, nearestDist = nil, CFG.DETECTION_RANGE
		for _, player in pairs(Players:GetPlayers()) do
			local char = player.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChild("Humanoid")
				if hrp and hum and hum.Health > 0 then
					-- FIX #21: 2D distance only (X, Z)
					local dist = Vector2.new(hrp.Position.X - npcX, hrp.Position.Z - npcZ).Magnitude
					if dist < nearestDist and not IsInLobby(hrp.Position.X, hrp.Position.Z) then
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

		if newState == CFG.STATE_IDLE then
			currentSpeed = CFG.SPEED_IDLE
			pickDragSound.Volume = 0
		elseif newState == CFG.STATE_WANDER then
			currentSpeed = SPEED_WANDER * CFG.SPEED_LIMP_PENALTY
			pickDragSound.Volume = 0.08
		elseif newState == CFG.STATE_CHASE then
			currentSpeed = SPEED_CHASE * CFG.SPEED_LIMP_PENALTY
			pickDragSound.Volume = 0
			-- FIX #18: Pick drag sound only when pick tip is near ground (handled in UpdateNPCPosition)
			groanSound:Play()
		elseif newState == CFG.STATE_ATTACK then
			currentSpeed = 0
		elseif newState == CFG.STATE_HEAVY_SWING then
			currentSpeed = 0
		end
	end

	-- =========================================================================
	-- MAIN LOOP
	-- =========================================================================

	local chaseConnection
	chaseConnection = RunService.Heartbeat:Connect(function(dt)
		if not isAlive or not torso or not torso.Parent then
			if chaseConnection then chaseConnection:Disconnect() end
			return
		end

		-- Lifetime check
		local elapsedTime = tick() - spawnTime
		if elapsedTime >= npcLifetime then
			isAlive = false
			if chaseConnection then chaseConnection:Disconnect() end
			PlayDeathEffect()
			task.wait(1.5)
			if npcFolder and npcFolder.Parent then
				npcFolder:Destroy()
			end
			return
		end

		-- Stun check
		if npcModel:GetAttribute("Stunned") then
			UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, 999, nil)
			return
		end

		-- FIX #22: Lobby boundary check uses both X and Z
		if IsInLobby(npcX, npcZ) then
			isAlive = false
			if chaseConnection then chaseConnection:Disconnect() end
			PlayDeathEffect()
			task.wait(1.5)
			if npcFolder and npcFolder.Parent then
				npcFolder:Destroy()
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

		-- FIX #18: Update pick drag sound based on pick tip height (done each frame)
		if isWalking and currentState == CFG.STATE_CHASE then
			-- Only enable drag sound if the pickaxe tip is close to the ground
			local pickTipY = pickHeadLeft.Position.Y
			if pickTipY < groundY + 0.8 * S then
				pickDragSound.Volume = 0.18
			else
				pickDragSound.Volume = 0
			end
		elseif currentState == CFG.STATE_WANDER then
			pickDragSound.Volume = 0.08
		else
			pickDragSound.Volume = 0
		end

		-- ===================================================================
		-- STATE MACHINE
		-- ===================================================================

		if currentState == CFG.STATE_IDLE then
			if target and distance < CFG.CHASE_THRESHOLD then
				ChangeState(CFG.STATE_CHASE)
			elseif stateTimer > 3 then
				ChangeState(CFG.STATE_WANDER)
				npcRotation = npcRotation + (math.random() - 0.5) * math.rad(120)
			end
			UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, distance or 999, targetPosition)

		elseif currentState == CFG.STATE_WANDER then
			if target and distance < CFG.CHASE_THRESHOLD then
				ChangeState(CFG.STATE_CHASE)
			elseif stateTimer > 5 then
				ChangeState(CFG.STATE_IDLE)
			else
				local moveDir = Vector3.new(-math.sin(npcRotation), 0, -math.cos(npcRotation))
				local newX = npcX + moveDir.X * currentSpeed * dt
				local newZ = npcZ + moveDir.Z * currentSpeed * dt

				-- FIX #22: IsInLobby uses both X and Z
				-- FIX #23: Raycast forward to avoid walking through walls
				local wallCheck = RaycastForward(
					Vector3.new(npcX, groundY + torsoH * 0.5, npcZ),
					moveDir,
					currentSpeed * dt + 0.5 * S,
					npcFilterList
				)

				if not IsInLobby(newX, newZ) and not wallCheck then
					UpdateNPCPosition(newX, newZ, npcRotation, true, dt, distance or 999, targetPosition)
				else
					npcRotation = npcRotation + math.rad(180)
					ChangeState(CFG.STATE_IDLE)
				end
			end

		elseif currentState == CFG.STATE_CHASE then
			if target and targetPosition then
				local direction = Vector3.new(targetPosition.X - npcX, 0, targetPosition.Z - npcZ)

				if distance <= CFG.ATTACK_RANGE then
					local useHeavy = math.random() < CFG.HEAVY_SWING_CHANCE
						and tick() - lastHeavySwingTime >= CFG.HEAVY_SWING_COOLDOWN

					if useHeavy then
						ChangeState(CFG.STATE_HEAVY_SWING)
						coroutine.wrap(function()
							PerformPickaxeSwing(target, true)
							if isAlive then ChangeState(CFG.STATE_CHASE) end
						end)()
					else
						ChangeState(CFG.STATE_ATTACK)
						coroutine.wrap(function()
							PerformPickaxeSwing(target, false)
							if isAlive then ChangeState(CFG.STATE_CHASE) end
						end)()
					end

					local lookAngle = math.atan2(-direction.X, -direction.Z)
					UpdateNPCPosition(npcX, npcZ, lookAngle, false, dt, distance, targetPosition)

				elseif direction.Magnitude > 0.5 then
					local lookAngle = math.atan2(-direction.X, -direction.Z)
					local moveDir = direction.Unit
					local newX = npcX + moveDir.X * currentSpeed * dt
					local newZ = npcZ + moveDir.Z * currentSpeed * dt

					-- FIX #23: Wall collision check during chase
					local wallCheck = RaycastForward(
						Vector3.new(npcX, groundY + torsoH * 0.5, npcZ),
						Vector3.new(moveDir.X, 0, moveDir.Z),
						currentSpeed * dt + 0.5 * S,
						npcFilterList
					)

					if not IsInLobby(newX, newZ) and not wallCheck then
						UpdateNPCPosition(newX, newZ, lookAngle, true, dt, distance, targetPosition)
					else
						-- Try to slide along the wall
						if wallCheck then
							local wallNormal = wallCheck.Normal
							local slideDir = moveDir - wallNormal * moveDir:Dot(wallNormal)
							if slideDir.Magnitude > 0.1 then
								slideDir = slideDir.Unit
								local slideX = npcX + slideDir.X * currentSpeed * dt * 0.7
								local slideZ = npcZ + slideDir.Z * currentSpeed * dt * 0.7
								if not IsInLobby(slideX, slideZ) then
									UpdateNPCPosition(slideX, slideZ, lookAngle, true, dt, distance, targetPosition)
								else
									UpdateNPCPosition(npcX, npcZ, lookAngle, false, dt, distance, targetPosition)
								end
							else
								UpdateNPCPosition(npcX, npcZ, lookAngle, false, dt, distance, targetPosition)
							end
						else
							UpdateNPCPosition(npcX, npcZ, lookAngle, false, dt, distance, targetPosition)
						end
					end
				end
			elseif lastSeenPosition then
				local direction = Vector3.new(lastSeenPosition.X - npcX, 0, lastSeenPosition.Z - npcZ)
				if direction.Magnitude > 2 then
					local lookAngle = math.atan2(-direction.X, -direction.Z)
					local moveDir = direction.Unit
					local newX = npcX + moveDir.X * currentSpeed * dt
					local newZ = npcZ + moveDir.Z * currentSpeed * dt

					local wallCheck = RaycastForward(
						Vector3.new(npcX, groundY + torsoH * 0.5, npcZ),
						Vector3.new(moveDir.X, 0, moveDir.Z),
						currentSpeed * dt + 0.5 * S,
						npcFilterList
					)

					if not IsInLobby(newX, newZ) and not wallCheck then
						UpdateNPCPosition(newX, newZ, lookAngle, true, dt, distance or 999, nil)
					else
						lastSeenPosition = nil
						ChangeState(CFG.STATE_IDLE)
					end
				else
					lastSeenPosition = nil
					ChangeState(CFG.STATE_IDLE)
				end
			else
				ChangeState(CFG.STATE_IDLE)
			end

		elseif currentState == CFG.STATE_ATTACK or currentState == CFG.STATE_HEAVY_SWING then
			if target and targetPosition then
				local direction = Vector3.new(targetPosition.X - npcX, 0, targetPosition.Z - npcZ)
				local lookAngle = math.atan2(-direction.X, -direction.Z)
				UpdateNPCPosition(npcX, npcZ, lookAngle, false, dt, distance or 999, targetPosition)
			else
				UpdateNPCPosition(npcX, npcZ, npcRotation, false, dt, 999, nil)
			end
		end
	end)

	-- =========================================================================
	-- AMBIENT BEHAVIORS
	-- =========================================================================

	-- FIX #20: Periodic groans reuse a single Sound instance
	coroutine.wrap(function()
		while isAlive and head and head.Parent do
			task.wait(math.random(6, 15))
			if isAlive and not isAttacking then
				ambientGroan.PlaybackSpeed = 0.28 + math.random() * 0.18
				ambientGroan:Play()
			end
		end
	end)()

	-- Whispered fragments of last words
	coroutine.wrap(function()
		while isAlive and head and head.Parent do
			task.wait(math.random(10, 22))
			if isAlive and currentState ~= CFG.STATE_ATTACK and currentState ~= CFG.STATE_HEAVY_SWING then
				local whisperText = CFG.WHISPER_LINES[math.random(1, #CFG.WHISPER_LINES)]
				for _, player in pairs(Players:GetPlayers()) do
					local char = player.Character
					if char then
						local hrp = char:FindFirstChild("HumanoidRootPart")
						if hrp then
							local dist = (hrp.Position - Vector3.new(npcX, hrp.Position.Y, npcZ)).Magnitude
							if dist < 55 then
								ShowSubtitleEvent:FireClient(player, whisperText, 1.5, "TheMiner")
							end
						end
					end
				end
			end
		end
	end)()

	-- Cleanup on destroy
	npcFolder.AncestryChanged:Connect(function()
		if not npcFolder.Parent then
			isAlive = false
			breathingSound:Stop()
			chainSound:Stop()
			pickDragSound:Stop()
			ambientGroan:Stop()
			if chaseConnection then chaseConnection:Disconnect() end
		end
	end)

	return npcFolder
end

-- -------------------------------------------------------------------------------
-- EVENT LISTENER
-- FIX #27: Updated signature (removed unused 'side' and 'doorFrameInfo')
-- -------------------------------------------------------------------------------

if SpawnMinerEvent then
	SpawnMinerEvent.Event:Connect(function(position, player, side, zDir, doorFrameInfo, lifetime)
		-- Accept all params for backward compatibility but only use what's needed
		print("?? SpawnMinerEvent received - Lifetime: " .. tostring(lifetime))
		task.wait(0.2)
		CreateMinerNPC(position, player, zDir, lifetime)
	end)
end

print("=== THE MINER V3.0 - ALL 30 FIXES APPLIED ===")
print("   Scale: " .. S .. "x")
print("   Chase Speed: " .. SPEED_CHASE * CFG.SPEED_LIMP_PENALTY)
print("   Pickaxe Damage: " .. CFG.DAMAGE_PICKAXE)
print("   Heavy Swing Damage: " .. CFG.DAMAGE_HEAVY_SWING)
print("   Detection Range: " .. CFG.DETECTION_RANGE .. " studs")
print("   ? Pickaxe heads along handle axis (proper shape)")
print("   ? Cylinder orientations corrected (neck/arms/legs)")
print("   ? Boots follow ankles (not ground-locked)")
print("   ? Boot sole BELOW boot (no overlap)")
print("   ? Belt flush with torso (no floating)")
print("   ? Face details on ellipsoid surface (spherical math)")
print("   ? Patch strap wraps around head (segmented)")
print("   ? Rocks protrude from torso surface")
print("   ? Limp propagates to leg chain")
print("   ? Pickaxe swing frame-synced (no race condition)")
print("   ? Fingers curl around handle")
print("   ? Sparks emit from pick head")
print("   ? Pick drag sound conditional on tip height")
print("   ? Bootsteps synced to walk cycle")
print("   ? Ambient groans reuse single Sound")
print("   ? 2D distance for detection (ignores Y)")
print("   ? Lobby checks X and Z")
print("   ? Wall collision via raycast")
print("   ? Dynamic ground height via raycast")
print("   ? LinearVelocity knockback (not deprecated)")
print("   ? Speeds scaled by entity scale")
print("   ? animTime wraps to prevent float issues")
print("   ? Eye light range reduced")
print("   ? Bandana less flat")
print("   ? ShowSubtitleEvent type validated")
print("=================================================")