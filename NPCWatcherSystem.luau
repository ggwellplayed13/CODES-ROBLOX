--[[
    +------------------------------------------------------------------------------+
    |                    HUMANOID HORROR ENTITY SYSTEM (V2)                         |
    |                 "THE WATCHER" - OCULAR NIGHTMARE - ENHANCED                   |
    +------------------------------------------------------------------------------+
    
    Mejoras:
    - Anatomía mejorada: core orgánico pulsante con capas de carne
    - Ojos con reacciones a distancia (pupilas se dilatan, iris cambia)
    - Tentáculos con IK y ondulación orgánica mejorada
    - Piernas arácnidas con mejor animación de caminar
    - Respiro orgánico sincronizado en todo el cuerpo
    - Sonido direccional según estado de IA
    - Habilidades con feedback visual mejorado
    - Frame-skip inteligente por prioridad de componente
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local SpawnWatcherEvent = ReplicatedStorage:WaitForChild("SpawnWatcherEvent", 10)

-- -------------------------------------------------------------------------------
-- REMOTE EVENTS
-- -------------------------------------------------------------------------------

local WatcherRemotes = ReplicatedStorage:FindFirstChild("WatcherRemotes") or Instance.new("Folder")
WatcherRemotes.Name = "WatcherRemotes"
WatcherRemotes.Parent = ReplicatedStorage

local function GetOrCreateRemote(name)
	local existing = WatcherRemotes:FindFirstChild(name)
	if existing then return existing end
	local new = Instance.new("RemoteEvent")
	new.Name = name
	new.Parent = WatcherRemotes
	return new
end

local ThousandStareEvent = GetOrCreateRemote("ThousandStare")
local WitnessEffectEvent = GetOrCreateRemote("WitnessEffect")
local PupilDilationEvent = GetOrCreateRemote("PupilDilation")
local TerrifyingLeapEvent = GetOrCreateRemote("TerrifyingLeap")
local EyeHarvestEvent = GetOrCreateRemote("EyeHarvest")
local ParanoiaEvent = GetOrCreateRemote("Paranoia")
local ParalysisEvent = GetOrCreateRemote("Paralysis")

-- -------------------------------------------------------------------------------
-- CONFIGURATION
-- -------------------------------------------------------------------------------

local WATCHER_CONFIG = {
	SCALE = 1.8,
	SPEED_NORMAL = 22,
	SPEED_STALKING = 28,
	SPEED_HUNTING = 34,
	SPEED_SPRINTING = 40,
	DAMAGE = 45,
	ATTACK_COOLDOWN = 1.2,
	ATTACK_RANGE = 9,
	DETECTION_RANGE = 350,

	-- Colors
	FLESH_PALE = Color3.fromRGB(200, 180, 175),
	FLESH_SICK = Color3.fromRGB(180, 160, 150),
	FLESH_VEINY = Color3.fromRGB(160, 130, 135),
	FLESH_ROT = Color3.fromRGB(120, 100, 95),
	FLESH_WET = Color3.fromRGB(140, 110, 120),

	SCLERA_WHITE = Color3.fromRGB(245, 240, 235),
	SCLERA_BLOODSHOT = Color3.fromRGB(255, 200, 195),

	IRIS_COLORS = {
		Color3.fromRGB(80, 150, 200),
		Color3.fromRGB(150, 80, 80),
		Color3.fromRGB(50, 50, 50),
		Color3.fromRGB(255, 50, 50),
		Color3.fromRGB(200, 170, 50),
	},

	PUPIL_BLACK = Color3.fromRGB(5, 5, 8),
	VEIN_COLOR = Color3.fromRGB(180, 60, 70),
	EYELID_COLOR = Color3.fromRGB(170, 150, 145),
	TENTACLE_BASE = Color3.fromRGB(180, 160, 155),
	TENTACLE_TIP = Color3.fromRGB(220, 200, 195),
	LEG_BONE = Color3.fromRGB(230, 220, 200),
	LEG_JOINT = Color3.fromRGB(150, 100, 90),

	CORE_SIZE = Vector3.new(2.5, 3.0, 2.2),

	NUM_BODY_EYES = 40,
	NUM_LARGE_EYES = 10,
	NUM_TENTACLE_EYES = 6,
	NUM_FLOATING_EYES = 5,

	EYE_SIZE_MIN = 0.1,
	EYE_SIZE_MAX = 0.25,
	LARGE_EYE_SIZE = 0.45,

	TENTACLE_COUNT = 6,
	TENTACLE_SEGMENTS = 7,
	TENTACLE_LENGTH = 4.5,

	LEG_COUNT = 4,
	LEG_TOTAL_LENGTH = 8.0,
	LEG_UPPER_LENGTH = 3.5,
	LEG_LOWER_LENGTH = 4.5,
	LEG_THICKNESS = 0.25,
	LEG_JOINT_SIZE = 0.4,
	LEG_WALK_SPEED = 3.5,
	LEG_STEP_HEIGHT = 1.2,
	LEG_STEP_LENGTH = 2.5,

	-- Abilities
	EYEBALL_BARRAGE = {
		ENABLED = true, COOLDOWN = 12, NUM_EYES = 10, EYE_SIZE = 0.45,
		EYE_SPEED = 45, EYE_DAMAGE = 18, BOUNCE_COUNT = 3, LIFETIME = 6,
		TRACKING_STRENGTH = 0.4,
	},
	THOUSAND_STARE = {
		ENABLED = true, COOLDOWN = 20, RANGE = 70, DURATION = 5,
		PARALYSIS_DURATION = 3.5, DAMAGE_PER_SECOND = 8,
	},
	TERRIFYING_LEAP = {
		ENABLED = true, COOLDOWN = 8, LEAP_HEIGHT = 8, LEAP_DURATION = 0.6,
		PREDICTION_DISTANCE = 4, LANDING_DAMAGE = 25, LANDING_RADIUS = 5,
	},
	EYE_HARVEST = {
		ENABLED = true, COOLDOWN = 25, NUM_GROUND_EYES = 12, RANGE = 35,
		GRAB_DURATION = 4, DAMAGE_ON_GRAB = 15, ROOT_DURATION = 2.0,
	},
	THE_WITNESS = {
		ENABLED = true, INTERVAL = 15, DURATION = 8, PARANOIA_LEVEL = 0.8,
	},
	PUPIL_DILATION = {
		ENABLED = true, COOLDOWN = 18, DURATION = 5, DARKNESS_LEVEL = 0.85,
		RANGE = 55,
	},

	PULSE_SPEED = 1.5,
	EYE_LOOK_SPEED = 2.5,

	LOBBY_START_X = -75,
	LOBBY_END_X = 75,
}

local S = WATCHER_CONFIG.SCALE
WATCHER_CONFIG.CORE_SIZE = WATCHER_CONFIG.CORE_SIZE * S
WATCHER_CONFIG.EYE_SIZE_MIN = WATCHER_CONFIG.EYE_SIZE_MIN * S
WATCHER_CONFIG.EYE_SIZE_MAX = WATCHER_CONFIG.EYE_SIZE_MAX * S
WATCHER_CONFIG.LARGE_EYE_SIZE = WATCHER_CONFIG.LARGE_EYE_SIZE * S
WATCHER_CONFIG.TENTACLE_LENGTH = WATCHER_CONFIG.TENTACLE_LENGTH * S
WATCHER_CONFIG.EYEBALL_BARRAGE.EYE_SIZE = WATCHER_CONFIG.EYEBALL_BARRAGE.EYE_SIZE * S
WATCHER_CONFIG.LEG_TOTAL_LENGTH = WATCHER_CONFIG.LEG_TOTAL_LENGTH * S
WATCHER_CONFIG.LEG_UPPER_LENGTH = WATCHER_CONFIG.LEG_UPPER_LENGTH * S
WATCHER_CONFIG.LEG_LOWER_LENGTH = WATCHER_CONFIG.LEG_LOWER_LENGTH * S
WATCHER_CONFIG.LEG_THICKNESS = WATCHER_CONFIG.LEG_THICKNESS * S
WATCHER_CONFIG.LEG_JOINT_SIZE = WATCHER_CONFIG.LEG_JOINT_SIZE * S
WATCHER_CONFIG.LEG_STEP_HEIGHT = WATCHER_CONFIG.LEG_STEP_HEIGHT * S
WATCHER_CONFIG.LEG_STEP_LENGTH = WATCHER_CONFIG.LEG_STEP_LENGTH * S

local function IsInLobby(x)
	return x >= WATCHER_CONFIG.LOBBY_START_X and x <= WATCHER_CONFIG.LOBBY_END_X
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
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function CreateBallPart(name, diameter, color, material, parent)
	local part = CreatePart(name, Vector3.new(diameter, diameter, diameter), color, material, 0, parent)
	part.Shape = Enum.PartType.Ball
	return part
end

local function Lerp(a, b, t) return a + (b - a) * t end

local function LerpColor(c1, c2, t)
	return Color3.new(c1.R + (c2.R - c1.R) * t, c1.G + (c2.G - c1.G) * t, c1.B + (c2.B - c1.B) * t)
end

local function GetRandomIrisColor()
	return WATCHER_CONFIG.IRIS_COLORS[math.random(1, #WATCHER_CONFIG.IRIS_COLORS)]
end

-- -------------------------------------------------------------------------------
-- EYE CREATION (with iris ring for large eyes)
-- -------------------------------------------------------------------------------

local function CreateEye(name, size, parent, isLarge)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent

	local sclera = CreateBallPart("Sclera", size,
		math.random() > 0.3 and WATCHER_CONFIG.SCLERA_WHITE or WATCHER_CONFIG.SCLERA_BLOODSHOT,
		Enum.Material.SmoothPlastic, folder)

	local irisSize = size * 0.55
	local irisColor = GetRandomIrisColor()
	local iris = CreatePart("Iris", Vector3.new(irisSize, irisSize, size * 0.1),
		irisColor, Enum.Material.SmoothPlastic, 0, folder)
	local irisMesh = Instance.new("SpecialMesh")
	irisMesh.MeshType = Enum.MeshType.Cylinder
	irisMesh.Parent = iris

	-- Iris ring (outer ring for detail, only on large eyes)
	local irisRing = nil
	if isLarge then
		local ringSize = size * 0.62
		irisRing = CreatePart("IrisRing", Vector3.new(ringSize, ringSize, size * 0.08),
			LerpColor(irisColor, WATCHER_CONFIG.PUPIL_BLACK, 0.4),
			Enum.Material.SmoothPlastic, 0, folder)
		local ringMesh = Instance.new("SpecialMesh")
		ringMesh.MeshType = Enum.MeshType.Cylinder
		ringMesh.Parent = irisRing
	end

	local pupilSize = size * 0.25
	local pupil = CreatePart("Pupil", Vector3.new(pupilSize, pupilSize, size * 0.12),
		WATCHER_CONFIG.PUPIL_BLACK, Enum.Material.SmoothPlastic, 0, folder)
	local pupilMesh = Instance.new("SpecialMesh")
	pupilMesh.MeshType = Enum.MeshType.Cylinder
	pupilMesh.Parent = pupil

	local upperLid = CreatePart("UpperLid", Vector3.new(size * 1.1, size * 0.6, size * 0.5),
		WATCHER_CONFIG.EYELID_COLOR, Enum.Material.SmoothPlastic, 0, folder)
	local lidMesh = Instance.new("SpecialMesh")
	lidMesh.MeshType = Enum.MeshType.Sphere
	lidMesh.Scale = Vector3.new(1, 0.5, 0.8)
	lidMesh.Parent = upperLid

	-- Bloodshot veins (only large eyes)
	local bloodVeins = {}
	if isLarge then
		for v = 1, 4 do
			local vein = CreatePart("BloodVein" .. v,
				Vector3.new(0.02 * S, size * 0.3, 0.015 * S),
				WATCHER_CONFIG.VEIN_COLOR, Enum.Material.SmoothPlastic, 0.3, folder)
			table.insert(bloodVeins, {part = vein, angle = (v / 4) * math.pi * 2})
		end
	end

	return {
		folder = folder,
		sclera = sclera,
		iris = iris,
		irisRing = irisRing,
		pupil = pupil,
		upperLid = upperLid,
		bloodVeins = bloodVeins,
		size = size,
		irisColor = irisColor,
		lookOffset = Vector2.new(0, 0),
		targetLookOffset = Vector2.new(0, 0),
		blinkProgress = 0,
		isBlinking = false,
		pupilDilation = 1.0,
		targetPupilDilation = 1.0,
		isLarge = isLarge or false,
	}
end

-- -------------------------------------------------------------------------------
-- EYE POSITION UPDATE
-- -------------------------------------------------------------------------------

local function UpdateEyePosition(eyeData, baseCFrame, localOffset, lookAtPosition, deltaTime)
	local eyeWorldPos = baseCFrame * CFrame.new(localOffset)
	local size = eyeData.size

	if lookAtPosition then
		local toTarget = (lookAtPosition - eyeWorldPos.Position)
		if toTarget.Magnitude > 0.5 then
			local localLook = eyeWorldPos:VectorToObjectSpace(toTarget.Unit)
			eyeData.targetLookOffset = Vector2.new(
				math.clamp(localLook.X * 0.3, -0.4, 0.4),
				math.clamp(localLook.Y * 0.3, -0.3, 0.3)
			)
		end
	end

	eyeData.lookOffset = Vector2.new(
		Lerp(eyeData.lookOffset.X, eyeData.targetLookOffset.X, deltaTime * WATCHER_CONFIG.EYE_LOOK_SPEED),
		Lerp(eyeData.lookOffset.Y, eyeData.targetLookOffset.Y, deltaTime * WATCHER_CONFIG.EYE_LOOK_SPEED)
	)

	-- Blinking
	if not eyeData.isBlinking and math.random() < 0.02 * deltaTime * 60 then
		eyeData.isBlinking = true
		eyeData.blinkProgress = 0
	end

	if eyeData.isBlinking then
		eyeData.blinkProgress = eyeData.blinkProgress + deltaTime * 8
		if eyeData.blinkProgress >= 1 then
			eyeData.isBlinking = false
			eyeData.blinkProgress = 0
		end
	end

	-- Pupil dilation smooth
	eyeData.pupilDilation = Lerp(eyeData.pupilDilation, eyeData.targetPupilDilation, deltaTime * 2)

	local blinkClose = math.sin(eyeData.blinkProgress * math.pi)

	-- Position parts
	eyeData.sclera.CFrame = eyeWorldPos

	local lookOffset3D = Vector3.new(eyeData.lookOffset.X * size, eyeData.lookOffset.Y * size, -size * 0.4)
	local irisCFrame = eyeWorldPos * CFrame.new(lookOffset3D) * CFrame.Angles(0, 0, math.rad(90))
	eyeData.iris.CFrame = irisCFrame

	-- Iris ring follows iris
	if eyeData.irisRing then
		eyeData.irisRing.CFrame = irisCFrame * CFrame.new(0, 0, 0.01)
	end

	local pupilScale = eyeData.pupilDilation
	eyeData.pupil.Size = Vector3.new(size * 0.25 * pupilScale, size * 0.25 * pupilScale, size * 0.12)
	eyeData.pupil.CFrame = irisCFrame * CFrame.new(0, 0, -0.02 * S)

	-- Eyelid
	local upperLidClose = size * 0.35 * blinkClose
	eyeData.upperLid.CFrame = eyeWorldPos * CFrame.new(0, size * 0.35 - upperLidClose, -size * 0.15)

	-- Bloodshot veins follow sclera
	if eyeData.bloodVeins then
		for _, veinData in ipairs(eyeData.bloodVeins) do
			local vAngle = veinData.angle
			local vX = math.cos(vAngle) * size * 0.35
			local vY = math.sin(vAngle) * size * 0.35
			veinData.part.CFrame = eyeWorldPos * CFrame.new(vX, vY, -size * 0.1)
				* CFrame.Angles(0, 0, vAngle)
		end
	end
end

-- -------------------------------------------------------------------------------
-- LEG CREATION (4 spider legs)
-- -------------------------------------------------------------------------------

local function CreateSpiderLeg(name, side, index, parent)
	local legFolder = Instance.new("Folder")
	legFolder.Name = name
	legFolder.Parent = parent

	local sideMultiplier = side == "left" and -1 or 1

	-- Hip joint
	local hipJoint = CreateBallPart("HipJoint", WATCHER_CONFIG.LEG_JOINT_SIZE * 0.8,
		WATCHER_CONFIG.LEG_JOINT, Enum.Material.SmoothPlastic, legFolder)

	-- Upper leg (coxa)
	local upperLeg = CreatePart("UpperLeg",
		Vector3.new(WATCHER_CONFIG.LEG_THICKNESS, WATCHER_CONFIG.LEG_UPPER_LENGTH, WATCHER_CONFIG.LEG_THICKNESS * 0.8),
		WATCHER_CONFIG.LEG_BONE, Enum.Material.SmoothPlastic, 0, legFolder)
	local upperMesh = Instance.new("SpecialMesh")
	upperMesh.MeshType = Enum.MeshType.Cylinder
	upperMesh.Parent = upperLeg

	-- Small spines on upper leg
	local upperSpines = {}
	for sp = 1, 3 do
		local spine = CreatePart("Spine" .. sp,
			Vector3.new(0.04 * S, 0.2 * S, 0.03 * S),
			WATCHER_CONFIG.LEG_JOINT, Enum.Material.SmoothPlastic, 0, legFolder)
		table.insert(upperSpines, {part = spine, offset = (sp / 4) })
	end

	-- Knee joint (larger, bulbous)
	local kneeJoint = CreateBallPart("KneeJoint", WATCHER_CONFIG.LEG_JOINT_SIZE,
		WATCHER_CONFIG.LEG_JOINT, Enum.Material.SmoothPlastic, legFolder)

	-- Small eye on knee
	local kneeEye = nil
	if index == 1 then -- only first pair gets knee eyes
		kneeEye = CreateEye("KneeEye", WATCHER_CONFIG.EYE_SIZE_MIN * 1.5, legFolder, false)
	end

	-- Lower leg (tibia)
	local lowerLeg = CreatePart("LowerLeg",
		Vector3.new(WATCHER_CONFIG.LEG_THICKNESS * 0.7, WATCHER_CONFIG.LEG_LOWER_LENGTH, WATCHER_CONFIG.LEG_THICKNESS * 0.6),
		WATCHER_CONFIG.LEG_BONE, Enum.Material.SmoothPlastic, 0, legFolder)
	local lowerMesh = Instance.new("SpecialMesh")
	lowerMesh.MeshType = Enum.MeshType.Cylinder
	lowerMesh.Parent = lowerLeg

	-- Ankle
	local ankle = CreateBallPart("Ankle", WATCHER_CONFIG.LEG_JOINT_SIZE * 0.6,
		WATCHER_CONFIG.LEG_JOINT, Enum.Material.SmoothPlastic, legFolder)

	-- Foot (claw-like tarsus)
	local foot = CreatePart("Foot",
		Vector3.new(WATCHER_CONFIG.LEG_JOINT_SIZE * 1.2, WATCHER_CONFIG.LEG_JOINT_SIZE * 0.4, WATCHER_CONFIG.LEG_JOINT_SIZE * 1.8),
		Color3.fromRGB(60, 40, 35), Enum.Material.SmoothPlastic, 0, legFolder)
	local footMesh = Instance.new("SpecialMesh")
	footMesh.MeshType = Enum.MeshType.Sphere
	footMesh.Scale = Vector3.new(0.6, 0.3, 1.5)
	footMesh.Parent = foot

	-- Claw tips
	local claws = {}
	for c = 1, 2 do
		local claw = CreatePart("Claw" .. c,
			Vector3.new(0.03 * S, 0.15 * S, 0.06 * S),
			Color3.fromRGB(40, 25, 20), Enum.Material.SmoothPlastic, 0, legFolder)
		local clawMesh = Instance.new("SpecialMesh")
		clawMesh.MeshType = Enum.MeshType.Wedge
		clawMesh.Parent = claw
		table.insert(claws, claw)
	end

	return {
		folder = legFolder,
		hipJoint = hipJoint,
		upperLeg = upperLeg,
		upperSpines = upperSpines,
		kneeJoint = kneeJoint,
		kneeEye = kneeEye,
		lowerLeg = lowerLeg,
		ankle = ankle,
		foot = foot,
		claws = claws,
		side = side,
		index = index,
		sideMultiplier = sideMultiplier,
		stepPhase = side == "left" and (index - 1) * math.pi * 0.5 or math.pi + (index - 1) * math.pi * 0.5,
		currentFootPos = Vector3.new(0, 0, 0),
		targetFootPos = Vector3.new(0, 0, 0),
		isGrounded = true,
	}
end

-- -------------------------------------------------------------------------------
-- LEG POSITION UPDATE (improved IK)
-- -------------------------------------------------------------------------------

local function UpdateLegPosition(legData, bodyPosition, bodyRotation, isWalking, walkSpeed, deltaTime, pulseTime)
	local sideOffset = legData.sideMultiplier * WATCHER_CONFIG.CORE_SIZE.X * 0.55
	local forwardOffset = legData.index == 1 and WATCHER_CONFIG.CORE_SIZE.Z * 0.25 or -WATCHER_CONFIG.CORE_SIZE.Z * 0.25
	local spreadAngle = math.rad(40 + (legData.index - 1) * 15) * legData.sideMultiplier

	local hipPos = bodyPosition + CFrame.Angles(0, bodyRotation, 0) * Vector3.new(
		sideOffset,
		-WATCHER_CONFIG.CORE_SIZE.Y * 0.3,
		forwardOffset
	)

	if isWalking then
		legData.stepPhase = legData.stepPhase + deltaTime * WATCHER_CONFIG.LEG_WALK_SPEED * walkSpeed * 0.1
	end

	local stepCycle = math.sin(legData.stepPhase)
	local stepHeight = math.max(0, stepCycle) * WATCHER_CONFIG.LEG_STEP_HEIGHT * (isWalking and 1 or 0.15)
	local stepForward = math.cos(legData.stepPhase) * WATCHER_CONFIG.LEG_STEP_LENGTH * (isWalking and 1 or 0)

	local footDirection = CFrame.Angles(0, bodyRotation + spreadAngle, 0).LookVector
	local footTargetPos = hipPos + Vector3.new(
		footDirection.X * WATCHER_CONFIG.LEG_TOTAL_LENGTH * 0.65 + CFrame.Angles(0, bodyRotation, 0).LookVector.X * stepForward,
		-WATCHER_CONFIG.LEG_TOTAL_LENGTH * 0.55 + stepHeight,
		footDirection.Z * WATCHER_CONFIG.LEG_TOTAL_LENGTH * 0.65 + CFrame.Angles(0, bodyRotation, 0).LookVector.Z * stepForward
	)

	-- Smooth foot movement
	local lerpSpeed = isWalking and 10 or 6
	legData.currentFootPos = Vector3.new(
		Lerp(legData.currentFootPos.X, footTargetPos.X, deltaTime * lerpSpeed),
		Lerp(legData.currentFootPos.Y, footTargetPos.Y, deltaTime * lerpSpeed * 1.5),
		Lerp(legData.currentFootPos.Z, footTargetPos.Z, deltaTime * lerpSpeed)
	)

	local footPos = legData.currentFootPos
	legData.isGrounded = stepHeight < 0.1 * S

	-- IK solve
	local hipToFoot = footPos - hipPos
	local hipToFootDist = hipToFoot.Magnitude
	local upperLen = WATCHER_CONFIG.LEG_UPPER_LENGTH
	local lowerLen = WATCHER_CONFIG.LEG_LOWER_LENGTH

	local kneeBendAmount = math.clamp(1 - hipToFootDist / (upperLen + lowerLen), 0, 0.5)
	local kneeOutward = legData.sideMultiplier * kneeBendAmount * upperLen * 0.9
	local kneeUp = kneeBendAmount * upperLen * 0.6

	local kneePos = hipPos + hipToFoot * 0.45 + Vector3.new(
		CFrame.Angles(0, bodyRotation + math.pi / 2, 0).LookVector.X * kneeOutward,
		kneeUp,
		CFrame.Angles(0, bodyRotation + math.pi / 2, 0).LookVector.Z * kneeOutward
	)

	-- Hip joint
	legData.hipJoint.CFrame = CFrame.new(hipPos)

	-- Upper leg
	local upperMid = (hipPos + kneePos) / 2
	local upperDir = (kneePos - hipPos)
	legData.upperLeg.CFrame = CFrame.new(upperMid, kneePos) * CFrame.Angles(math.rad(90), 0, 0)
	legData.upperLeg.Size = Vector3.new(WATCHER_CONFIG.LEG_THICKNESS, upperDir.Magnitude, WATCHER_CONFIG.LEG_THICKNESS * 0.8)

	-- Upper spines
	for i, spineData in ipairs(legData.upperSpines) do
		local t = spineData.offset
		local spinePos = hipPos + (kneePos - hipPos) * t
		local outward = CFrame.Angles(0, bodyRotation + spreadAngle, 0).LookVector * 0.12 * S
		spineData.part.CFrame = CFrame.new(spinePos + outward, spinePos + outward + (kneePos - hipPos).Unit)
			* CFrame.Angles(math.rad(90), 0, legData.sideMultiplier * math.rad(30))
	end

	-- Knee joint
	legData.kneeJoint.CFrame = CFrame.new(kneePos)

	-- Knee eye
	if legData.kneeEye then
		local kneeOutDir = CFrame.Angles(0, bodyRotation + spreadAngle, 0).LookVector * 0.15 * S
		UpdateEyePosition(legData.kneeEye, CFrame.new(kneePos + kneeOutDir), Vector3.new(0, 0, 0), nil, deltaTime)
	end

	-- Lower leg
	local lowerMid = (kneePos + footPos) / 2
	legData.lowerLeg.CFrame = CFrame.new(lowerMid, footPos) * CFrame.Angles(math.rad(90), 0, 0)
	legData.lowerLeg.Size = Vector3.new(WATCHER_CONFIG.LEG_THICKNESS * 0.7, (footPos - kneePos).Magnitude, WATCHER_CONFIG.LEG_THICKNESS * 0.6)

	-- Ankle
	legData.ankle.CFrame = CFrame.new(footPos + Vector3.new(0, 0.05 * S, 0))

	-- Foot
	local footDir = CFrame.Angles(0, bodyRotation, 0).LookVector
	legData.foot.CFrame = CFrame.new(footPos, footPos + footDir) * CFrame.Angles(math.rad(-15), 0, 0)

	-- Claws
	for c, claw in ipairs(legData.claws) do
		local clawSide = c == 1 and -1 or 1
		local clawOffset = CFrame.Angles(0, bodyRotation, 0) * Vector3.new(clawSide * 0.06 * S, -0.03 * S, 0.1 * S)
		claw.CFrame = CFrame.new(footPos + clawOffset, footPos + clawOffset + footDir)
			* CFrame.Angles(math.rad(25), 0, 0)
	end
end

-- -------------------------------------------------------------------------------
-- CREATE THE WATCHER NPC
-- -------------------------------------------------------------------------------

local function CreateWatcherNPC(spawnPosition, triggerPlayer, side, zDir, doorFrameInfo, lifetime)
	local npcLifetime = lifetime or 80

	print("===========================================")
	print("THE WATCHER V2 SPAWNED")
	print("   Eyes: " .. (WATCHER_CONFIG.NUM_BODY_EYES + WATCHER_CONFIG.NUM_LARGE_EYES + WATCHER_CONFIG.NUM_FLOATING_EYES))
	print("   Tentacles: " .. WATCHER_CONFIG.TENTACLE_COUNT)
	print("   Legs: " .. WATCHER_CONFIG.LEG_COUNT)
	print("===========================================")

	local npcFolder = Instance.new("Folder")
	npcFolder.Name = "WatcherEntity"
	npcFolder.Parent = workspace

	local npcModel = Instance.new("Model")
	npcModel.Name = "TheWatcher"
	npcModel.Parent = npcFolder

	local spawnTime = tick()
	npcFolder:SetAttribute("SpawnTime", spawnTime)
	npcFolder:SetAttribute("Lifetime", npcLifetime)
	npcModel:SetAttribute("Stunned", false)

	local groundY = 0.5

	-- Ability cooldowns
	local abilityCooldowns = {
		eyeballBarrage = 0,
		thousandStare = 0,
		terrifyingLeap = 0,
		eyeHarvest = 0,
		pupilDilation = 0,
		witness = 0,
	}

	local abilityState = {
		isStaring = false,
		isLeaping = false,
		paralyzedPlayers = {},
	}

	-- ---------------------------------------------------------------------------
	-- CENTRAL BODY (layered organic mass)
	-- ---------------------------------------------------------------------------

	local coreBody = CreatePart("CoreBody", WATCHER_CONFIG.CORE_SIZE,
		WATCHER_CONFIG.FLESH_PALE, Enum.Material.SmoothPlastic, 0, npcModel)
	coreBody.CanCollide = true
	coreBody.CastShadow = true
	local coreMesh = Instance.new("SpecialMesh")
	coreMesh.MeshType = Enum.MeshType.Sphere
	coreMesh.Scale = Vector3.new(1, 1.15, 0.9)
	coreMesh.Parent = coreBody

	-- Organic layers
	local fleshLayers = {}
	local layerDefs = {
		{pos = Vector3.new(0.3, 0.2, 0.1), size = Vector3.new(0.7, 0.8, 0.6), color = WATCHER_CONFIG.FLESH_SICK, meshScale = Vector3.new(1, 1.1, 0.8)},
		{pos = Vector3.new(-0.25, -0.15, 0.2), size = Vector3.new(0.6, 0.7, 0.5), color = WATCHER_CONFIG.FLESH_VEINY, meshScale = Vector3.new(1, 1, 0.7)},
		{pos = Vector3.new(0, -0.35, 0), size = Vector3.new(0.55, 0.45, 0.55), color = WATCHER_CONFIG.FLESH_ROT, meshScale = Vector3.new(1, 0.8, 1)},
		{pos = Vector3.new(0.15, 0.4, -0.1), size = Vector3.new(0.5, 0.6, 0.45), color = WATCHER_CONFIG.FLESH_WET, meshScale = Vector3.new(1, 1.2, 0.6)},
	}

	for i, def in ipairs(layerDefs) do
		local layer = CreatePart("FleshLayer" .. i, def.size * S, def.color, Enum.Material.SmoothPlastic, 0, npcModel)
		local lMesh = Instance.new("SpecialMesh")
		lMesh.MeshType = Enum.MeshType.Sphere
		lMesh.Scale = def.meshScale
		lMesh.Parent = layer
		table.insert(fleshLayers, {part = layer, offset = def.pos * S, pulsePhase = math.random() * math.pi * 2})
	end

	-- Surface veins on core
	local coreVeins = {}
	for i = 1, 8 do
		local vein = CreatePart("CoreVein" .. i,
			Vector3.new(0.04 * S, (0.4 + math.random() * 0.6) * S, 0.03 * S),
			WATCHER_CONFIG.VEIN_COLOR, Enum.Material.SmoothPlastic, 0.2, npcModel)
		local angle = (i / 8) * math.pi * 2
		local radius = WATCHER_CONFIG.CORE_SIZE.X * 0.4
		table.insert(coreVeins, {
			part = vein,
			offset = Vector3.new(math.cos(angle) * radius, (math.random() - 0.5) * WATCHER_CONFIG.CORE_SIZE.Y * 0.5, math.sin(angle) * radius * 0.9),
			angle = angle,
			pulsePhase = math.random() * math.pi * 2,
		})
	end

	-- Wet membrane patches
	local membranes = {}
	for i = 1, 6 do
		local membrane = CreatePart("Membrane" .. i,
			Vector3.new((0.3 + math.random() * 0.3) * S, (0.25 + math.random() * 0.2) * S, 0.08 * S),
			LerpColor(WATCHER_CONFIG.FLESH_WET, WATCHER_CONFIG.FLESH_VEINY, math.random()),
			Enum.Material.SmoothPlastic, 0.15, npcModel)
		CreatePart("MembraneSheen" .. i, -- wet sheen
			Vector3.new(0.15 * S, 0.1 * S, 0.02 * S),
			Color3.fromRGB(255, 245, 240), Enum.Material.SmoothPlastic, 0.7, npcModel)
		local angle = (i / 6) * math.pi * 2
		local phi = math.acos(2 * math.random() - 1)
		table.insert(membranes, {
			part = membrane,
			theta = angle,
			phi = phi,
			pulsePhase = math.random() * math.pi * 2,
		})
	end

	-- ---------------------------------------------------------------------------
	-- LEGS (4 spider legs)
	-- ---------------------------------------------------------------------------

	local legs = {}
	local legSides = {"left", "right", "left", "right"}
	local legIndices = {1, 1, 2, 2}
	for i = 1, WATCHER_CONFIG.LEG_COUNT do
		table.insert(legs, CreateSpiderLeg("Leg" .. i, legSides[i], legIndices[i], npcModel))
	end

	-- ---------------------------------------------------------------------------
	-- BODY EYES
	-- ---------------------------------------------------------------------------

	local bodyEyes = {}
	for i = 1, WATCHER_CONFIG.NUM_BODY_EYES do
		local eyeSize = WATCHER_CONFIG.EYE_SIZE_MIN + math.random() * (WATCHER_CONFIG.EYE_SIZE_MAX - WATCHER_CONFIG.EYE_SIZE_MIN)
		local eyeData = CreateEye("BodyEye" .. i, eyeSize, npcModel, false)

		local theta = math.random() * math.pi * 2
		local phi = math.acos(2 * math.random() - 1)
		local radius = WATCHER_CONFIG.CORE_SIZE.X * 0.5 + math.random() * 0.05 * S

		eyeData.surfaceOffset = Vector3.new(
			radius * math.sin(phi) * math.cos(theta),
			radius * 1.15 * math.sin(phi) * math.sin(theta),
			radius * 0.9 * math.cos(phi)
		)
		table.insert(bodyEyes, eyeData)
	end

	-- Large eyes (with lights and iris rings)
	local largeEyes = {}
	local largePositions = {
		Vector3.new(0, 0.45, -0.52),
		Vector3.new(0.38, 0.3, -0.4),
		Vector3.new(-0.38, 0.3, -0.4),
		Vector3.new(0.5, 0, 0),
		Vector3.new(-0.5, 0, 0),
		Vector3.new(0, 0.5, 0),
		Vector3.new(0.3, -0.3, -0.35),
		Vector3.new(-0.3, -0.3, -0.35),
		Vector3.new(0, -0.45, -0.3),
		Vector3.new(0, 0.2, 0.5),
	}

	for i, pos in ipairs(largePositions) do
		if i <= WATCHER_CONFIG.NUM_LARGE_EYES then
			local eyeSize = WATCHER_CONFIG.LARGE_EYE_SIZE * (0.9 + math.random() * 0.2)
			local eyeData = CreateEye("LargeEye" .. i, eyeSize, npcModel, true)
			eyeData.surfaceOffset = pos * WATCHER_CONFIG.CORE_SIZE.X

			local eyeLight = Instance.new("PointLight")
			eyeLight.Brightness = 0.5
			eyeLight.Color = eyeData.irisColor
			eyeLight.Range = 5 * S
			eyeLight.Shadows = i <= 3
			eyeLight.Parent = eyeData.pupil
			eyeData.light = eyeLight

			table.insert(largeEyes, eyeData)
		end
	end

	-- ---------------------------------------------------------------------------
	-- TENTACLES
	-- ---------------------------------------------------------------------------

	local tentacles = {}
	for t = 1, WATCHER_CONFIG.TENTACLE_COUNT do
		local tentFolder = Instance.new("Folder")
		tentFolder.Name = "Tentacle" .. t
		tentFolder.Parent = npcModel

		local segments = {}
		local segLength = WATCHER_CONFIG.TENTACLE_LENGTH / WATCHER_CONFIG.TENTACLE_SEGMENTS

		for seg = 1, WATCHER_CONFIG.TENTACLE_SEGMENTS do
			local progress = (seg - 1) / WATCHER_CONFIG.TENTACLE_SEGMENTS
			local segWidth = 0.15 * S * (1 - progress * 0.6)
			local segment = CreatePart("Seg" .. seg,
				Vector3.new(segWidth, segLength, segWidth),
				LerpColor(WATCHER_CONFIG.TENTACLE_BASE, WATCHER_CONFIG.TENTACLE_TIP, progress),
				Enum.Material.SmoothPlastic, 0, tentFolder)
			local segMesh = Instance.new("SpecialMesh")
			segMesh.MeshType = Enum.MeshType.Sphere
			segMesh.Scale = Vector3.new(1, 2.5, 1)
			segMesh.Parent = segment

			-- Suckers on every other segment
			local sucker = nil
			if seg % 2 == 0 and seg < WATCHER_CONFIG.TENTACLE_SEGMENTS then
				sucker = CreatePart("Sucker" .. seg,
					Vector3.new(segWidth * 0.6, segWidth * 0.6, segWidth * 0.3),
					WATCHER_CONFIG.FLESH_WET, Enum.Material.SmoothPlastic, 0, tentFolder)
				local suckerMesh = Instance.new("SpecialMesh")
				suckerMesh.MeshType = Enum.MeshType.Sphere
				suckerMesh.Parent = sucker
			end

			table.insert(segments, {part = segment, width = segWidth, sucker = sucker})
		end

		-- Tip eye
		local tipEye = nil
		if t <= WATCHER_CONFIG.NUM_TENTACLE_EYES then
			tipEye = CreateEye("TipEye" .. t, 0.35 * S, tentFolder, true)
			local tipLight = Instance.new("PointLight")
			tipLight.Brightness = 0.8
			tipLight.Color = tipEye.irisColor
			tipLight.Range = 4 * S
			tipLight.Parent = tipEye.sclera
			tipEye.light = tipLight
		end

		table.insert(tentacles, {
			folder = tentFolder,
			segments = segments,
			tipEye = tipEye,
			baseAngle = (t / WATCHER_CONFIG.TENTACLE_COUNT) * math.pi * 2,
			waveOffset = math.random() * math.pi * 2,
			waveSpeed = 1.5 + math.random() * 0.8,
			reachAmount = 0,
			targetReach = 0,
		})
	end

	-- ---------------------------------------------------------------------------
	-- FLOATING EYES (with nerve cords)
	-- ---------------------------------------------------------------------------

	local floatingEyes = {}
	for i = 1, WATCHER_CONFIG.NUM_FLOATING_EYES do
		local eyeSize = WATCHER_CONFIG.LARGE_EYE_SIZE * 0.7
		local eyeData = CreateEye("FloatingEye" .. i, eyeSize, npcModel, true)

		eyeData.orbitAngle = (i / WATCHER_CONFIG.NUM_FLOATING_EYES) * math.pi * 2
		eyeData.orbitRadius = WATCHER_CONFIG.CORE_SIZE.X * (0.85 + math.random() * 0.3)
		eyeData.orbitHeight = (math.random() - 0.5) * WATCHER_CONFIG.CORE_SIZE.Y * 0.6
		eyeData.orbitSpeed = 0.3 + math.random() * 0.4

		-- Nerve cord
		local nerve = CreatePart("Nerve" .. i,
			Vector3.new(0.035 * S, 1, 0.025 * S),
			WATCHER_CONFIG.VEIN_COLOR, Enum.Material.SmoothPlastic, 0.1, npcModel)
		eyeData.nerve = nerve

		-- Nerve drip particles
		local nerveDrip = Instance.new("ParticleEmitter")
		nerveDrip.Texture = "rbxassetid://243098098"
		nerveDrip.Color = ColorSequence.new(WATCHER_CONFIG.VEIN_COLOR)
		nerveDrip.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.03 * S), NumberSequenceKeypoint.new(1, 0)})
		nerveDrip.Transparency = NumberSequence.new(0.4, 1)
		nerveDrip.Lifetime = NumberRange.new(0.3, 0.6)
		nerveDrip.Rate = 1
		nerveDrip.Speed = NumberRange.new(0.2, 0.5)
		nerveDrip.Acceleration = Vector3.new(0, -3, 0)
		nerveDrip.Parent = nerve
		eyeData.nerveDrip = nerveDrip

		table.insert(floatingEyes, eyeData)
	end

	-- ---------------------------------------------------------------------------
	-- PARTICLES
	-- ---------------------------------------------------------------------------

	local gazeParticles = Instance.new("ParticleEmitter")
	gazeParticles.Texture = "rbxassetid://243098098"
	gazeParticles.Color = ColorSequence.new(Color3.fromRGB(255, 200, 200), Color3.fromRGB(150, 100, 100))
	gazeParticles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1 * S), NumberSequenceKeypoint.new(1, 0)})
	gazeParticles.Transparency = NumberSequence.new(0.5, 1)
	gazeParticles.Lifetime = NumberRange.new(0.5, 1)
	gazeParticles.Rate = 6
	gazeParticles.Speed = NumberRange.new(1, 3)
	gazeParticles.SpreadAngle = Vector2.new(180, 180)
	gazeParticles.Parent = coreBody

	local wetParticles = Instance.new("ParticleEmitter")
	wetParticles.Texture = "rbxassetid://243098098"
	wetParticles.Color = ColorSequence.new(WATCHER_CONFIG.FLESH_WET)
	wetParticles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.04 * S), NumberSequenceKeypoint.new(1, 0)})
	wetParticles.Transparency = NumberSequence.new(0.5, 1)
	wetParticles.Lifetime = NumberRange.new(0.3, 0.8)
	wetParticles.Rate = 3
	wetParticles.Speed = NumberRange.new(0.2, 0.8)
	wetParticles.Acceleration = Vector3.new(0, -4, 0)
	wetParticles.SpreadAngle = Vector2.new(180, 180)
	wetParticles.Parent = coreBody

	-- Negative light (absorbs light around)
	local negLight = Instance.new("PointLight")
	negLight.Color = Color3.fromRGB(50, 20, 30)
	negLight.Brightness = -0.3
	negLight.Range = 12 * S
	negLight.Shadows = false
	negLight.Parent = coreBody

	-- ---------------------------------------------------------------------------
	-- STATE
	-- ---------------------------------------------------------------------------

	local npcX = spawnPosition.X
	local npcZ = spawnPosition.Z
	local npcY = groundY + WATCHER_CONFIG.LEG_TOTAL_LENGTH * 0.6
	local npcRotation = zDir > 0 and 0 or math.pi

	local pulseTime = 0
	local currentSpeed = WATCHER_CONFIG.SPEED_NORMAL
	local isWalking = false
	local breathPhase = 0

	local frameCounter = 0
	local UPDATE_SKIP = 2

	-- ---------------------------------------------------------------------------
	-- POSITION UPDATE
	-- ---------------------------------------------------------------------------

	local function UpdateNPCPosition(x, z, y, rotY, walking, deltaTime, targetPosition)
		npcX = x
		npcZ = z
		npcY = y or npcY
		npcRotation = rotY or npcRotation
		isWalking = walking or false
		frameCounter = frameCounter + 1

		if deltaTime then
			pulseTime = pulseTime + deltaTime * WATCHER_CONFIG.PULSE_SPEED
			breathPhase = breathPhase + deltaTime * 1.2
		end

		-- Organic breathing
		local breathScale = 1 + math.sin(breathPhase * math.pi) * 0.04
		local hoverBob = math.sin(pulseTime * 2.5) * 0.1 * S
		local baseY = npcY + hoverBob
		local baseCFrame = CFrame.new(x, baseY, z) * CFrame.Angles(0, npcRotation, 0)

		-- Core body pulses with breathing
		local pulseScale = breathScale * (1 + math.sin(pulseTime * 3) * 0.02)
		coreBody.Size = WATCHER_CONFIG.CORE_SIZE * pulseScale
		coreBody.CFrame = baseCFrame

		-- Flesh layers breathe
		if frameCounter % UPDATE_SKIP == 0 then
			for _, layer in ipairs(fleshLayers) do
				local layerPulse = breathScale * (1 + math.sin(pulseTime * 2.5 + layer.pulsePhase) * 0.05)
				layer.part.CFrame = baseCFrame * CFrame.new(layer.offset * layerPulse)
			end

			-- Core veins throb
			for _, vein in ipairs(coreVeins) do
				local throb = math.sin(pulseTime * 4 + vein.pulsePhase) > 0.6
				vein.part.Color = throb and WATCHER_CONFIG.VEIN_COLOR or LerpColor(WATCHER_CONFIG.VEIN_COLOR, WATCHER_CONFIG.FLESH_ROT, 0.4)
				vein.part.CFrame = baseCFrame * CFrame.new(vein.offset) * CFrame.Angles(vein.angle, 0, 0)
			end

			-- Membranes
			for _, mem in ipairs(membranes) do
				local mPulse = 1 + math.sin(pulseTime * 3 + mem.pulsePhase) * 0.08
				local r = WATCHER_CONFIG.CORE_SIZE.X * 0.48 * mPulse
				local mx = math.sin(mem.phi) * math.cos(mem.theta) * r
				local my = math.sin(mem.phi) * math.sin(mem.theta) * r * 1.15
				local mz = math.cos(mem.phi) * r * 0.9
				mem.part.CFrame = baseCFrame * CFrame.new(mx, my, mz)
					* CFrame.Angles(mem.theta, mem.phi, pulseTime * 0.05)
			end
		end

		-- Legs (always update for smooth walk)
		local bodyPos = Vector3.new(x, baseY, z)
		for _, legData in ipairs(legs) do
			UpdateLegPosition(legData, bodyPos, npcRotation, isWalking, currentSpeed, deltaTime, pulseTime)
		end

		-- Body eyes (batched)
		local batchSize = math.ceil(#bodyEyes / 3)
		local batchIdx = frameCounter % 3
		local startIdx = batchIdx * batchSize + 1
		local endIdx = math.min((batchIdx + 1) * batchSize, #bodyEyes)

		for i = startIdx, endIdx do
			local eyeData = bodyEyes[i]
			if eyeData then
				UpdateEyePosition(eyeData, baseCFrame, eyeData.surfaceOffset * pulseScale, targetPosition, deltaTime * 3)
			end
		end

		-- Large eyes (always update)
		for _, eyeData in ipairs(largeEyes) do
			UpdateEyePosition(eyeData, baseCFrame, eyeData.surfaceOffset * pulseScale, targetPosition, deltaTime)

			-- Distance-reactive pupil dilation
			if targetPosition then
				local dist = (targetPosition - Vector3.new(x, baseY, z)).Magnitude
				if dist < 20 then
					eyeData.targetPupilDilation = Lerp(1.0, 0.4, (20 - dist) / 20) -- constrict when close
				elseif dist < 50 then
					eyeData.targetPupilDilation = 1.0
				else
					eyeData.targetPupilDilation = 1.5 -- dilate when far (searching)
				end
			end

			-- Light intensity reacts to distance
			if eyeData.light and targetPosition then
				local dist = (targetPosition - Vector3.new(x, baseY, z)).Magnitude
				eyeData.light.Brightness = Lerp(0.5, 3, math.clamp((50 - dist) / 50, 0, 1))
			end
		end

		-- Tentacles
		if frameCounter % UPDATE_SKIP == 0 then
			for _, tent in ipairs(tentacles) do
				local tentBaseAngle = tent.baseAngle + pulseTime * 0.2
				local tentBaseCF = baseCFrame * CFrame.new(
					math.cos(tentBaseAngle) * WATCHER_CONFIG.CORE_SIZE.X * 0.4,
					-WATCHER_CONFIG.CORE_SIZE.Y * 0.3,
					math.sin(tentBaseAngle) * WATCHER_CONFIG.CORE_SIZE.Z * 0.4
				)

				-- Reach toward target
				if targetPosition then
					local toTarget = (targetPosition - baseCFrame.Position)
					if toTarget.Magnitude < 30 then
						tent.targetReach = 0.3
					else
						tent.targetReach = 0
					end
				end
				tent.reachAmount = Lerp(tent.reachAmount, tent.targetReach, deltaTime * 2 * UPDATE_SKIP)

				local prevCF = tentBaseCF
				local segLen = WATCHER_CONFIG.TENTACLE_LENGTH / WATCHER_CONFIG.TENTACLE_SEGMENTS

				for seg, segData in ipairs(tent.segments) do
					local waveAmp = math.sin(pulseTime * tent.waveSpeed + tent.waveOffset + seg * 0.5) * 0.3
					local reachPitch = -tent.reachAmount * 0.2 * (seg / #tent.segments)
					local breathWave = math.sin(breathPhase * math.pi + seg * 0.3) * 0.05

					local segCF = prevCF * CFrame.Angles(waveAmp + reachPitch + breathWave, 0, waveAmp * 0.5) * CFrame.new(0, -segLen * 0.5, 0)
					segData.part.CFrame = segCF

					-- Suckers
					if segData.sucker then
						segData.sucker.CFrame = segCF * CFrame.new(segData.width * 0.5, 0, 0)
					end

					prevCF = segCF * CFrame.new(0, -segLen * 0.5, 0)
				end

				if tent.tipEye then
					UpdateEyePosition(tent.tipEye, prevCF, Vector3.new(0, -0.1 * S, 0), targetPosition, deltaTime * UPDATE_SKIP)
				end
			end
		end

		-- Floating eyes
		if frameCounter % UPDATE_SKIP == 0 then
			for _, eyeData in ipairs(floatingEyes) do
				eyeData.orbitAngle = eyeData.orbitAngle + deltaTime * eyeData.orbitSpeed * UPDATE_SKIP

				local floatBob = math.sin(pulseTime * 2 + eyeData.orbitAngle) * 0.2 * S
				local orbitPos = baseCFrame * CFrame.new(
					math.cos(eyeData.orbitAngle) * eyeData.orbitRadius,
					eyeData.orbitHeight + floatBob,
					math.sin(eyeData.orbitAngle) * eyeData.orbitRadius
				)

				UpdateEyePosition(eyeData, orbitPos, Vector3.new(0, 0, 0), targetPosition, deltaTime * UPDATE_SKIP)

				-- Nerve cord
				if eyeData.nerve then
					local nerveStart = baseCFrame.Position
					local nerveEnd = orbitPos.Position
					local nerveLen = (nerveEnd - nerveStart).Magnitude
					eyeData.nerve.Size = Vector3.new(0.035 * S, nerveLen, 0.025 * S)
					eyeData.nerve.CFrame = CFrame.new((nerveStart + nerveEnd) / 2, nerveEnd) * CFrame.Angles(math.rad(90), 0, 0)
				end
			end
		end
	end

	-- Initial position
	UpdateNPCPosition(npcX, npcZ, npcY, npcRotation, false, 0.016, nil)

	-- ---------------------------------------------------------------------------
	-- SOUNDS
	-- ---------------------------------------------------------------------------

	local ambientSound = Instance.new("Sound")
	ambientSound.SoundId = "rbxassetid://116711110416425"
	ambientSound.Volume = 0.5
	ambientSound.Looped = true
	ambientSound.PlaybackSpeed = 1.2
	ambientSound.Parent = coreBody
	ambientSound:Play()

	local wetSound = Instance.new("Sound")
	wetSound.SoundId = "rbxassetid://"
	wetSound.Volume = 0.15
	wetSound.Looped = true
	wetSound.PlaybackSpeed = 0.3
	wetSound.Parent = coreBody
	wetSound:Play()

	-- ---------------------------------------------------------------------------
	-- ABILITIES
	-- ---------------------------------------------------------------------------

	local function EyeballBarrage(targetHRP)
		if not WATCHER_CONFIG.EYEBALL_BARRAGE.ENABLED then return end
		if tick() < abilityCooldowns.eyeballBarrage then return end
		abilityCooldowns.eyeballBarrage = tick() + WATCHER_CONFIG.EYEBALL_BARRAGE.COOLDOWN

		local basePos = coreBody.Position
		local baseDir = (targetHRP.Position - basePos).Unit

		-- Visual: all pupils constrict before firing
		for _, eyeData in ipairs(largeEyes) do
			eyeData.targetPupilDilation = 0.2
		end

		task.delay(0.3, function()
			for _, eyeData in ipairs(largeEyes) do
				eyeData.targetPupilDilation = 1.0
			end
		end)

		for i = 1, WATCHER_CONFIG.EYEBALL_BARRAGE.NUM_EYES do
			task.delay(i * 0.08, function()
				local eyeSize = WATCHER_CONFIG.EYEBALL_BARRAGE.EYE_SIZE
				local projectile = CreateBallPart("ProjEye", eyeSize,
					WATCHER_CONFIG.SCLERA_WHITE, Enum.Material.SmoothPlastic, workspace)
				projectile.Position = basePos + baseDir * WATCHER_CONFIG.CORE_SIZE.X * 0.6
				projectile.Anchored = false
				projectile.CanCollide = true

				-- Iris on projectile
				local projIris = CreatePart("ProjIris",
					Vector3.new(eyeSize * 0.4, eyeSize * 0.4, eyeSize * 0.08),
					GetRandomIrisColor(), Enum.Material.SmoothPlastic, 0, projectile)
				local piMesh = Instance.new("SpecialMesh")
				piMesh.MeshType = Enum.MeshType.Cylinder
				piMesh.Parent = projIris

				-- Trail
				local projTrail = Instance.new("ParticleEmitter")
				projTrail.Color = ColorSequence.new(WATCHER_CONFIG.VEIN_COLOR)
				projTrail.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, eyeSize * 0.3), NumberSequenceKeypoint.new(1, 0)})
				projTrail.Transparency = NumberSequence.new(0.3, 1)
				projTrail.Lifetime = NumberRange.new(0.2, 0.4)
				projTrail.Rate = 30
				projTrail.Speed = NumberRange.new(0.1, 0.3)
				projTrail.Parent = projectile

				local bodyVel = Instance.new("BodyVelocity")
				bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
				local spreadAngle = math.rad(40)
				local spreadDir = CFrame.new(Vector3.zero, baseDir) * CFrame.Angles((math.random() - 0.5) * spreadAngle * 0.5, (math.random() - 0.5) * spreadAngle, 0)
				bodyVel.Velocity = spreadDir.LookVector * WATCHER_CONFIG.EYEBALL_BARRAGE.EYE_SPEED
				bodyVel.Parent = projectile

				local hitPlayers = {}
				projectile.Touched:Connect(function(hit)
					if hit.Parent == npcModel or hit.Parent == npcFolder then return end
					local hum = hit.Parent:FindFirstChild("Humanoid")
					if hum and not hitPlayers[hit.Parent] then
						hitPlayers[hit.Parent] = true
						hum:TakeDamage(WATCHER_CONFIG.EYEBALL_BARRAGE.EYE_DAMAGE)
					end
				end)

				Debris:AddItem(projectile, WATCHER_CONFIG.EYEBALL_BARRAGE.LIFETIME)
			end)
		end
	end

	local function ThousandStare()
		if not WATCHER_CONFIG.THOUSAND_STARE.ENABLED then return end
		if tick() < abilityCooldowns.thousandStare then return end
		if abilityState.isStaring then return end
		abilityCooldowns.thousandStare = tick() + WATCHER_CONFIG.THOUSAND_STARE.COOLDOWN
		abilityState.isStaring = true

		for _, eyeData in ipairs(largeEyes) do eyeData.targetPupilDilation = 0.2 end

		local affected = {}
		for _, player in pairs(Players:GetPlayers()) do
			local char = player.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChild("Humanoid")
				if hrp and hum and hum.Health > 0 then
					local dist = (hrp.Position - Vector3.new(npcX, hrp.Position.Y, npcZ)).Magnitude
					if dist <= WATCHER_CONFIG.THOUSAND_STARE.RANGE and not IsInLobby(hrp.Position.X) then
						table.insert(affected, {
							player = player, humanoid = hum,
							ws = hum.WalkSpeed, jp = hum.JumpPower, jh = hum.JumpHeight,
						})
						ThousandStareEvent:FireClient(player, {
							duration = WATCHER_CONFIG.THOUSAND_STARE.DURATION,
							paralysis = WATCHER_CONFIG.THOUSAND_STARE.PARALYSIS_DURATION,
							watcherPosition = Vector3.new(npcX, npcY, npcZ),
						})
						hum.WalkSpeed = 0
						hum.JumpPower = 0
						hum.JumpHeight = 0
						ParalysisEvent:FireClient(player, {paralyzed = true, duration = WATCHER_CONFIG.THOUSAND_STARE.PARALYSIS_DURATION})
					end
				end
			end
		end

		local startTime = tick()
		local dmgConn
		dmgConn = RunService.Heartbeat:Connect(function(dt)
			if tick() - startTime > WATCHER_CONFIG.THOUSAND_STARE.DURATION then dmgConn:Disconnect() return end
			for _, data in ipairs(affected) do
				if data.humanoid and data.humanoid.Health > 0 then
					data.humanoid:TakeDamage(WATCHER_CONFIG.THOUSAND_STARE.DAMAGE_PER_SECOND * dt)
				end
			end
		end)

		task.delay(WATCHER_CONFIG.THOUSAND_STARE.PARALYSIS_DURATION, function()
			for _, data in ipairs(affected) do
				if data.humanoid and data.humanoid.Parent then
					data.humanoid.WalkSpeed = data.ws
					data.humanoid.JumpPower = data.jp
					data.humanoid.JumpHeight = data.jh
				end
				if data.player then ParalysisEvent:FireClient(data.player, {paralyzed = false}) end
			end
		end)

		task.delay(WATCHER_CONFIG.THOUSAND_STARE.DURATION, function()
			abilityState.isStaring = false
			for _, eyeData in ipairs(largeEyes) do eyeData.targetPupilDilation = 1.0 end
		end)
	end

	local function TerrifyingLeap(targetHRP)
		if not WATCHER_CONFIG.TERRIFYING_LEAP.ENABLED then return false end
		if tick() < abilityCooldowns.terrifyingLeap then return false end
		if abilityState.isLeaping then return false end

		local playerVel = targetHRP.AssemblyLinearVelocity
		local moveDir = playerVel.Magnitude > 1 and playerVel.Unit or targetHRP.CFrame.LookVector
		local landingPos = targetHRP.Position + moveDir * WATCHER_CONFIG.TERRIFYING_LEAP.PREDICTION_DISTANCE
		if IsInLobby(landingPos.X) then return false end

		abilityCooldowns.terrifyingLeap = tick() + WATCHER_CONFIG.TERRIFYING_LEAP.COOLDOWN
		abilityState.isLeaping = true

		for _, player in pairs(Players:GetPlayers()) do
			local char = player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				TerrifyingLeapEvent:FireClient(player, {leaping = true, landingPosition = landingPos})
			end
		end

		local startPos = Vector3.new(npcX, npcY, npcZ)
		local endPos = Vector3.new(landingPos.X, groundY + WATCHER_CONFIG.LEG_TOTAL_LENGTH * 0.6, landingPos.Z)
		local leapHeight = WATCHER_CONFIG.TERRIFYING_LEAP.LEAP_HEIGHT * S
		local leapDuration = WATCHER_CONFIG.TERRIFYING_LEAP.LEAP_DURATION
		local leapStart = tick()

		local leapConn
		leapConn = RunService.Heartbeat:Connect(function(dt)
			local t = math.clamp((tick() - leapStart) / leapDuration, 0, 1)
			if t >= 1 then
				leapConn:Disconnect()
				abilityState.isLeaping = false
				npcX = endPos.X
				npcZ = endPos.Z
				npcY = endPos.Y
				npcRotation = math.atan2(-(targetHRP.Position.X - npcX), -(targetHRP.Position.Z - npcZ))

				-- Landing shockwave
				for _, player in pairs(Players:GetPlayers()) do
					local char = player.Character
					if char then
						local hrp = char:FindFirstChild("HumanoidRootPart")
						local hum = char:FindFirstChild("Humanoid")
						if hrp and hum and hum.Health > 0 then
							if (hrp.Position - endPos).Magnitude <= WATCHER_CONFIG.TERRIFYING_LEAP.LANDING_RADIUS then
								hum:TakeDamage(WATCHER_CONFIG.TERRIFYING_LEAP.LANDING_DAMAGE)
							end
						end
					end
				end

				-- Landing visual
				local shockwave = CreatePart("Shockwave", Vector3.new(1, 0.1, 1),
					WATCHER_CONFIG.VEIN_COLOR, Enum.Material.Neon, 0.3, workspace)
				shockwave.Shape = Enum.PartType.Cylinder
				shockwave.CFrame = CFrame.new(endPos.X, groundY + 0.1, endPos.Z) * CFrame.Angles(0, 0, math.rad(90))
				TweenService:Create(shockwave, TweenInfo.new(0.5), {
					Size = Vector3.new(0.1, WATCHER_CONFIG.TERRIFYING_LEAP.LANDING_RADIUS * 2, WATCHER_CONFIG.TERRIFYING_LEAP.LANDING_RADIUS * 2),
					Transparency = 1,
				}):Play()
				Debris:AddItem(shockwave, 0.6)
				return
			end

			npcX = Lerp(startPos.X, endPos.X, t)
			npcZ = Lerp(startPos.Z, endPos.Z, t)
			npcY = Lerp(startPos.Y, endPos.Y, t) + math.sin(t * math.pi) * leapHeight
			npcRotation = math.atan2(-(endPos.X - npcX), -(endPos.Z - npcZ))
			UpdateNPCPosition(npcX, npcZ, npcY, npcRotation, false, dt, targetHRP.Position)
		end)

		return true
	end

	local function EyeHarvest(targetHRP)
		if not WATCHER_CONFIG.EYE_HARVEST.ENABLED then return end
		if tick() < abilityCooldowns.eyeHarvest then return end
		abilityCooldowns.eyeHarvest = tick() + WATCHER_CONFIG.EYE_HARVEST.COOLDOWN

		local targetPos = targetHRP.Position
		for i = 1, WATCHER_CONFIG.EYE_HARVEST.NUM_GROUND_EYES do
			local angle = (i / WATCHER_CONFIG.EYE_HARVEST.NUM_GROUND_EYES) * math.pi * 2
			local radius = 5 + math.random() * (WATCHER_CONFIG.EYE_HARVEST.RANGE - 5)
			local eyeX = targetPos.X + math.cos(angle) * radius
			local eyeZ = targetPos.Z + math.sin(angle) * radius

			if not IsInLobby(eyeX) then
				task.delay(i * 0.1, function()
					local gEye = CreateBallPart("GroundEye" .. i, 0.4 * S,
						WATCHER_CONFIG.SCLERA_WHITE, Enum.Material.SmoothPlastic, workspace)
					gEye.Position = Vector3.new(eyeX, groundY - 1, eyeZ)

					-- Iris
					local gIris = CreatePart("GIris", Vector3.new(0.2 * S, 0.2 * S, 0.05 * S),
						GetRandomIrisColor(), Enum.Material.SmoothPlastic, 0, gEye)
					local giMesh = Instance.new("SpecialMesh")
					giMesh.MeshType = Enum.MeshType.Cylinder
					giMesh.Parent = gIris

					-- Emerge
					local emergeStart = tick()
					local emergeConn
					emergeConn = RunService.Heartbeat:Connect(function()
						local t = math.clamp((tick() - emergeStart) / 0.5, 0, 1)
						gEye.Position = Vector3.new(eyeX, Lerp(groundY - 1, groundY + 0.15 * S, t), eyeZ)
						gIris.CFrame = gEye.CFrame * CFrame.new(0, 0, -0.18 * S) * CFrame.Angles(0, 0, math.rad(90))
						if t >= 1 then emergeConn:Disconnect() end
					end)

					gEye.Touched:Connect(function(hit)
						local hum = hit.Parent:FindFirstChild("Humanoid")
						if hum and hum.Health > 0 then
							hum:TakeDamage(WATCHER_CONFIG.EYE_HARVEST.DAMAGE_ON_GRAB)
							local p = Players:GetPlayerFromCharacter(hit.Parent)
							if p then
								EyeHarvestEvent:FireClient(p, {
									grabbed = true,
									duration = WATCHER_CONFIG.EYE_HARVEST.GRAB_DURATION,
									rootDuration = WATCHER_CONFIG.EYE_HARVEST.ROOT_DURATION,
								})
							end
							local origSpeed = hum.WalkSpeed
							hum.WalkSpeed = 0
							task.delay(WATCHER_CONFIG.EYE_HARVEST.ROOT_DURATION, function()
								if hum and hum.Parent then hum.WalkSpeed = origSpeed * 0.3 end
							end)
							task.delay(WATCHER_CONFIG.EYE_HARVEST.GRAB_DURATION, function()
								if hum and hum.Parent then hum.WalkSpeed = origSpeed end
							end)
						end
					end)

					Debris:AddItem(gEye, WATCHER_CONFIG.EYE_HARVEST.GRAB_DURATION + 1)
				end)
			end
		end
	end

	local function TriggerWitness()
		if not WATCHER_CONFIG.THE_WITNESS.ENABLED then return end
		if tick() < abilityCooldowns.witness then return end
		abilityCooldowns.witness = tick() + WATCHER_CONFIG.THE_WITNESS.INTERVAL

		for _, player in pairs(Players:GetPlayers()) do
			local char = player.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp and not IsInLobby(hrp.Position.X) then
					local dist = (hrp.Position - Vector3.new(npcX, hrp.Position.Y, npcZ)).Magnitude
					if dist < WATCHER_CONFIG.DETECTION_RANGE then
						WitnessEffectEvent:FireClient(player, {
							duration = WATCHER_CONFIG.THE_WITNESS.DURATION,
							paranoiaLevel = WATCHER_CONFIG.THE_WITNESS.PARANOIA_LEVEL,
							hallucinate = math.random() < 0.3,
						})
					end
				end
			end
		end
	end

	local function PupilDilation()
		if not WATCHER_CONFIG.PUPIL_DILATION.ENABLED then return end
		if tick() < abilityCooldowns.pupilDilation then return end
		abilityCooldowns.pupilDilation = tick() + WATCHER_CONFIG.PUPIL_DILATION.COOLDOWN

		for _, eyeData in ipairs(largeEyes) do
			eyeData.targetPupilDilation = 3.5
		end

		for _, player in pairs(Players:GetPlayers()) do
			local char = player.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp and not IsInLobby(hrp.Position.X) then
					local dist = (hrp.Position - Vector3.new(npcX, hrp.Position.Y, npcZ)).Magnitude
					if dist <= WATCHER_CONFIG.PUPIL_DILATION.RANGE then
						PupilDilationEvent:FireClient(player, {
							duration = WATCHER_CONFIG.PUPIL_DILATION.DURATION,
							darknessLevel = WATCHER_CONFIG.PUPIL_DILATION.DARKNESS_LEVEL,
							blindnessDuration = 1.2,
						})
					end
				end
			end
		end

		task.delay(WATCHER_CONFIG.PUPIL_DILATION.DURATION, function()
			for _, eyeData in ipairs(largeEyes) do
				eyeData.targetPupilDilation = 1.0
			end
		end)
	end

	-- ---------------------------------------------------------------------------
	-- ATTACK
	-- ---------------------------------------------------------------------------

	local lastAttackTime = 0
	local isAttacking = false

	local function PlayAttackAnimation(targetPos)
		if isAttacking then return end
		isAttacking = true

		-- All eyes snap to target and pupils constrict
		for _, eyeData in ipairs(largeEyes) do
			eyeData.targetPupilDilation = 0.2
			if eyeData.light then
				TweenService:Create(eyeData.light, TweenInfo.new(0.1), {
					Color = Color3.fromRGB(255, 50, 50),
					Brightness = 5,
				}):Play()
			end
		end

		-- Tentacles lash forward
		for _, tent in ipairs(tentacles) do
			tent.targetReach = 0.8
		end

		local attackSound = Instance.new("Sound")
		attackSound.SoundId = "rbxassetid://80126562543070"
		attackSound.Volume = 0.8
		attackSound.PlaybackSpeed = 1.7
		attackSound.Parent = coreBody
		attackSound:Play()

		-- Slash particles
		local slashEffect = CreatePart("SlashEffect", Vector3.new(0.1, 0.1, 0.1),
			WATCHER_CONFIG.VEIN_COLOR, Enum.Material.Neon, 0.3, workspace)
		slashEffect.Position = Vector3.new(npcX, npcY, npcZ) + (CFrame.Angles(0, npcRotation, 0).LookVector * 2 * S)

		local slashParticles = Instance.new("ParticleEmitter")
		slashParticles.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, WATCHER_CONFIG.VEIN_COLOR),
			ColorSequenceKeypoint.new(1, WATCHER_CONFIG.FLESH_ROT),
		})
		slashParticles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5 * S),
			NumberSequenceKeypoint.new(0.5, 1.5 * S),
			NumberSequenceKeypoint.new(1, 0),
		})
		slashParticles.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		slashParticles.Lifetime = NumberRange.new(0.15, 0.3)
		slashParticles.Rate = 100
		slashParticles.Speed = NumberRange.new(15, 30)
		slashParticles.SpreadAngle = Vector2.new(60, 60)
		slashParticles.Parent = slashEffect

		Debris:AddItem(slashEffect, 0.5)

		task.wait(0.15)
		slashParticles.Enabled = false

		task.wait(0.2)

		-- Restore
		for _, eyeData in ipairs(largeEyes) do
			eyeData.targetPupilDilation = 1.0
			if eyeData.light then
				TweenService:Create(eyeData.light, TweenInfo.new(0.3), {
					Color = eyeData.irisColor,
					Brightness = 0.5,
				}):Play()
			end
		end

		for _, tent in ipairs(tentacles) do
			tent.targetReach = 0
		end

		Debris:AddItem(attackSound, 2)
		isAttacking = false
	end

	local function AttackPlayer(player)
		if tick() - lastAttackTime < WATCHER_CONFIG.ATTACK_COOLDOWN then return end
		lastAttackTime = tick()

		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChild("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")

		if hum and hum.Health > 0 and hrp then
			coroutine.wrap(function() PlayAttackAnimation(hrp.Position) end)()
			task.wait(0.2)

			local dist = (hrp.Position - Vector3.new(npcX, hrp.Position.Y, npcZ)).Magnitude
			if dist < WATCHER_CONFIG.ATTACK_RANGE + 2 and hum.Health > 0 then
				hum:TakeDamage(WATCHER_CONFIG.DAMAGE)

				-- Hit visual
				local hitEffect = CreateBallPart("HitEffect", 0.5,
					WATCHER_CONFIG.VEIN_COLOR, Enum.Material.Neon, workspace)
				hitEffect.Position = hrp.Position
				TweenService:Create(hitEffect, TweenInfo.new(0.25), {
					Size = Vector3.new(3, 3, 3),
					Transparency = 1,
				}):Play()
				Debris:AddItem(hitEffect, 0.4)
			end
		end
	end

	-- ---------------------------------------------------------------------------
	-- DEATH EFFECT
	-- ---------------------------------------------------------------------------

	local function PlayDeathEffect()
		gazeParticles.Enabled = false
		wetParticles.Enabled = false
		ambientSound:Stop()
		wetSound:Stop()

		-- All eyes dilate maximally (death stare)
		for _, eyeData in ipairs(largeEyes) do
			eyeData.targetPupilDilation = 4.0
			if eyeData.light then
				TweenService:Create(eyeData.light, TweenInfo.new(0.5), {Brightness = 0}):Play()
			end
		end

		-- Floating eye nerves snap
		for _, eyeData in ipairs(floatingEyes) do
			if eyeData.nerveDrip then eyeData.nerveDrip.Enabled = false end
		end

		-- Death sound
		local deathSound = Instance.new("Sound")
		deathSound.SoundId = "rbxassetid://120923220505708"
		deathSound.Volume = 1.5
		deathSound.PlaybackSpeed = 0.3
		deathSound.Parent = coreBody
		deathSound:Play()

		-- Death burst particles
		local deathBurst = Instance.new("ParticleEmitter")
		deathBurst.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, WATCHER_CONFIG.VEIN_COLOR),
			ColorSequenceKeypoint.new(1, WATCHER_CONFIG.FLESH_ROT),
		})
		deathBurst.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 * S),
			NumberSequenceKeypoint.new(0.5, 2 * S),
			NumberSequenceKeypoint.new(1, 0),
		})
		deathBurst.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		deathBurst.Lifetime = NumberRange.new(0.5, 1)
		deathBurst.Rate = 80
		deathBurst.Speed = NumberRange.new(3, 8)
		deathBurst.SpreadAngle = Vector2.new(180, 180)
		deathBurst.Parent = coreBody

		-- Fade all parts
		for _, part in pairs(npcModel:GetDescendants()) do
			if part:IsA("BasePart") then
				TweenService:Create(part, TweenInfo.new(0.8), {Transparency = 1}):Play()
			end
		end

		task.wait(0.9)
		deathBurst.Enabled = false
		Debris:AddItem(deathSound, 3)
	end

	-- ---------------------------------------------------------------------------
	-- AI
	-- ---------------------------------------------------------------------------

	local isAlive = true
	local lastAbilityCheck = 0

	local function FindNearestPlayer()
		local nearest, nearestDist = nil, WATCHER_CONFIG.DETECTION_RANGE
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

	local function CheckAndUseAbilities(target, distance)
		if tick() - lastAbilityCheck < 0.5 then return end
		lastAbilityCheck = tick()

		local char = target.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		-- Witness
		if tick() > abilityCooldowns.witness then
			TriggerWitness()
		end

		-- Eyeball Barrage (medium range)
		if distance > 20 and distance < 60 and tick() > abilityCooldowns.eyeballBarrage and math.random() < 0.3 then
			task.spawn(function() EyeballBarrage(hrp) end)
		end

		-- Thousand Stare (close-medium)
		if distance < WATCHER_CONFIG.THOUSAND_STARE.RANGE and tick() > abilityCooldowns.thousandStare and math.random() < 0.2 then
			task.spawn(function() ThousandStare() end)
		end

		-- Terrifying Leap (when player runs away)
		if distance > 15 and distance < 45 then
			local playerVel = hrp.AssemblyLinearVelocity
			local toWatcher = (Vector3.new(npcX, 0, npcZ) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z))
			if toWatcher.Magnitude > 0.5 then
				local playerDir = playerVel.Magnitude > 2 and playerVel.Unit or Vector3.zero
				local runningAway = playerDir:Dot(toWatcher.Unit) < -0.3
				if runningAway and tick() > abilityCooldowns.terrifyingLeap and math.random() < 0.35 then
					task.spawn(function() TerrifyingLeap(hrp) end)
				end
			end
		end

		-- Eye Harvest (medium range)
		if distance < WATCHER_CONFIG.EYE_HARVEST.RANGE and distance > 10 and tick() > abilityCooldowns.eyeHarvest and math.random() < 0.15 then
			task.spawn(function() EyeHarvest(hrp) end)
		end

		-- Pupil Dilation (close)
		if distance < WATCHER_CONFIG.PUPIL_DILATION.RANGE and tick() > abilityCooldowns.pupilDilation and math.random() < 0.1 then
			PupilDilation()
		end
	end

	-- ---------------------------------------------------------------------------
	-- MAIN LOOP
	-- ---------------------------------------------------------------------------

	local chaseConnection
	chaseConnection = RunService.Heartbeat:Connect(function(dt)
		if not isAlive or not coreBody or not coreBody.Parent then
			if chaseConnection then chaseConnection:Disconnect() end
			return
		end

		-- Lifetime
		if tick() - spawnTime >= npcLifetime then
			isAlive = false
			if chaseConnection then chaseConnection:Disconnect() end
			PlayDeathEffect()
			task.wait(1.0)
			if npcFolder and npcFolder.Parent then npcFolder:Destroy() end
			return
		end

		-- Stunned
		if npcModel:GetAttribute("Stunned") then
			UpdateNPCPosition(npcX, npcZ, npcY, npcRotation, false, dt, nil)
			return
		end

		-- Lobby check
		if IsInLobby(npcX) then
			isAlive = false
			if chaseConnection then chaseConnection:Disconnect() end
			PlayDeathEffect()
			task.wait(1.0)
			if npcFolder and npcFolder.Parent then npcFolder:Destroy() end
			return
		end

		local target, distance = FindNearestPlayer()
		local targetPosition = nil

		if target then
			local char = target.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					targetPosition = hrp.Position

					CheckAndUseAbilities(target, distance)

					local direction = Vector3.new(hrp.Position.X - npcX, 0, hrp.Position.Z - npcZ)

					if direction.Magnitude > 0.5 then
						local lookAngle = math.atan2(-direction.X, -direction.Z)

						-- Speed based on distance
						if distance > 50 then
							currentSpeed = WATCHER_CONFIG.SPEED_NORMAL
						elseif distance > 25 then
							currentSpeed = WATCHER_CONFIG.SPEED_STALKING
						elseif distance > 12 then
							currentSpeed = WATCHER_CONFIG.SPEED_HUNTING
						else
							currentSpeed = WATCHER_CONFIG.SPEED_SPRINTING
						end

						if distance > WATCHER_CONFIG.ATTACK_RANGE and not abilityState.isStaring and not abilityState.isLeaping then
							local moveDir = direction.Unit
							local newX = npcX + moveDir.X * currentSpeed * dt
							local newZ = npcZ + moveDir.Z * currentSpeed * dt

							if not IsInLobby(newX) then
								npcRotation = lookAngle
								UpdateNPCPosition(newX, newZ, npcY, lookAngle, true, dt, targetPosition)
							else
								UpdateNPCPosition(npcX, npcZ, npcY, lookAngle, false, dt, targetPosition)
							end
						else
							UpdateNPCPosition(npcX, npcZ, npcY, lookAngle, false, dt, targetPosition)
							if not abilityState.isStaring and not abilityState.isLeaping then
								AttackPlayer(target)
							end
						end
					else
						UpdateNPCPosition(npcX, npcZ, npcY, npcRotation, false, dt, targetPosition)
					end
				else
					UpdateNPCPosition(npcX, npcZ, npcY, npcRotation, false, dt, nil)
				end
			else
				UpdateNPCPosition(npcX, npcZ, npcY, npcRotation, false, dt, nil)
			end
		else
			UpdateNPCPosition(npcX, npcZ, npcY, npcRotation, false, dt, nil)
		end
	end)

	-- ---------------------------------------------------------------------------
	-- AMBIENT EFFECTS
	-- ---------------------------------------------------------------------------

	-- Random eye blink wave
	coroutine.wrap(function()
		while isAlive and coreBody and coreBody.Parent do
			task.wait(math.random(4, 8))
			if isAlive then
				-- Wave of blinks across body eyes
				for i, eyeData in ipairs(bodyEyes) do
					if i % 3 == 0 then
						eyeData.isBlinking = true
						eyeData.blinkProgress = 0
					end
				end
			end
		end
	end)()

	-- Random whisper sounds
	coroutine.wrap(function()
		while isAlive and coreBody and coreBody.Parent do
			task.wait(math.random(6, 14))
			if isAlive and not isAttacking then
				local whisper = Instance.new("Sound")
				whisper.SoundId = "rbxassetid://9114221580"
				whisper.Volume = 0.12
				whisper.PlaybackSpeed = 0.1 + math.random() * 0.15
				whisper.Parent = coreBody
				whisper:Play()
				Debris:AddItem(whisper, 4)
			end
		end
	end)()

	-- Cleanup on destroy
	npcFolder.AncestryChanged:Connect(function()
		if not npcFolder.Parent then
			isAlive = false
			ambientSound:Stop()
			wetSound:Stop()
			if chaseConnection then chaseConnection:Disconnect() end
		end
	end)

	return npcFolder
end

-- ===============================================================================
-- EVENT LISTENER
-- ===============================================================================

if SpawnWatcherEvent then
	SpawnWatcherEvent.Event:Connect(function(position, player, side, zDir, doorFrameInfo, lifetime)
		print("SpawnWatcherEvent received")
		task.wait(0.3)
		CreateWatcherNPC(position, player, side, zDir, doorFrameInfo, lifetime)
	end)
end

print("=== THE WATCHER V2 (ENHANCED) LOADED ===")
print("   Improvements:")
print("     - 4 spider legs with IK, claws, spines, knee eyes")
print("     - Iris rings + bloodshot veins on large eyes")
print("     - Distance-reactive pupil dilation")
print("     - Tentacles with suckers and reach-toward-target")
print("     - Organic breathing synchronized across body")
print("     - Core veins that throb, wet membranes")
print("     - Nerve cord drip particles on floating eyes")
print("     - Projectile eyes with iris and particle trails")
print("     - Landing shockwave visual on leap")
print("     - Attack animation with eye color flash")
print("     - Batched eye updates for performance")
print("==========================================")