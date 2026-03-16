--[[
    +------------------------------------------------------------------------------+
    |                     INFINITE STREET - MAIN SERVER SCRIPT                       |
    |                     VERSION 34 - DOOR EVENTS + NEW PROBABILITIES              |
    +------------------------------------------------------------------------------+
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local ServerScriptService = game: GetService("ServerScriptService")


-- Load Modules
local AnimationsModule = require(ServerScriptService:WaitForChild("AnimationsModule"))
local WizardNPCModule = require(ServerScriptService:WaitForChild("WizardNPC"))
local ChestRewardsModule = require(ServerScriptService:WaitForChild("ChestRewardsModule"))
local DoorAntiExploitModule = require(ServerScriptService:WaitForChild("DoorAntiExploitModule"))
local MagicalBookModule = require(ServerScriptService:WaitForChild("MagicalBookModule"))


local WizardNPCData = nil


-- Load Horror Details Module
local HorrorDetailsModule = nil
local success, result = pcall(function()
	return require(ServerScriptService:WaitForChild("HorrorDetailsModule"))
end)
if success and result then
	HorrorDetailsModule = result
	print("[MainGameServer] ? HorrorDetailsModule loaded!")
else
	warn("[MainGameServer] ?? Failed to load HorrorDetailsModule:  " ..tostring(result))
end

-- Load Door Events Module
local DoorEventsModule = nil
local successEvents, resultEvents = pcall(function()
	return require(ServerScriptService:WaitForChild("DoorEventsModule"))
end)
if successEvents and resultEvents then
	DoorEventsModule = resultEvents
	print("[MainGameServer] ? DoorEventsModule loaded!")
else
	warn("[MainGameServer] ?? Failed to load DoorEventsModule:  " ..tostring(resultEvents))
end

-- -------------------------------------------------------------------------------
-- REMOTE EVENTS AND BINDABLES
-- -------------------------------------------------------------------------------

-- Add this after the CurrencyRemotes section
local CinematicReadySignal = ReplicatedStorage:FindFirstChild("CinematicReadySignal")
if not CinematicReadySignal then
	CinematicReadySignal = Instance.new("RemoteEvent")
	CinematicReadySignal.Name = "CinematicReadySignal"
	CinematicReadySignal.Parent = ReplicatedStorage
end

local EventsFolder = ReplicatedStorage:FindFirstChild("Events") or Instance.new("Folder")
EventsFolder.Name = "Events"
EventsFolder.Parent = ReplicatedStorage

local function CreateBindableEvent(name)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then return existing end
	local event = Instance.new("BindableEvent")
	event.Name = name
	event.Parent = ReplicatedStorage
	return event
end

-- 6 NPC SPAWN EVENTS
local SpawnHollowManEvent = CreateBindableEvent("SpawnHollowManEvent")
local SpawnScreamerEvent = CreateBindableEvent("SpawnScreamerEvent")
local SpawnCrawlerEvent = CreateBindableEvent("SpawnCrawlerEvent")
local SpawnPhantomEvent = CreateBindableEvent("SpawnPhantomEvent")
local SpawnWatcherEvent = CreateBindableEvent("SpawnWatcherEvent")
local SpawnHarvesterEvent = CreateBindableEvent("SpawnHarvesterEvent")
local SpawnStitcherEvent = CreateBindableEvent("SpawnStitcherEvent")
local SpawnMinerEvent = CreateBindableEvent("SpawnMinerEvent")
local SpawnSlenderEvent = CreateBindableEvent("SpawnSlenderEvent")
local SpawnShadowManEvent = CreateBindableEvent("SpawnShadowManEvent")

local CurrencyRemotes = ReplicatedStorage:FindFirstChild("CurrencyRemotes") or Instance.new("Folder")
CurrencyRemotes.Name = "CurrencyRemotes"
CurrencyRemotes.Parent = ReplicatedStorage

local function GetOrCreateRemote(name)
	local existing = CurrencyRemotes: FindFirstChild(name)
	if existing then return existing end
	local new = Instance.new("RemoteEvent")
	new.Name = name
	new.Parent = CurrencyRemotes
	return new
end

local UpdateCurrencyEvent = GetOrCreateRemote("UpdateCurrency")
local DoorOpenedEvent = GetOrCreateRemote("DoorOpened")
local SurvivedDoorEvent = GetOrCreateRemote("SurvivedDoor")
local PlayerDiedEvent = GetOrCreateRemote("PlayerDied")
local OpenShopEvent = GetOrCreateRemote("OpenShop")
local SyncDataEvent = GetOrCreateRemote("SyncData")
local PurchaseItemEvent = GetOrCreateRemote("PurchaseItem")
local UseItemEvent = GetOrCreateRemote("UseItem")
local BoostUpdateEvent = GetOrCreateRemote("BoostUpdate")
local DoorLockedEvent = GetOrCreateRemote("DoorLocked")
local RooftopRunnerEvent = GetOrCreateRemote("RooftopRunnerSound")
local ChestOpenedEvent = GetOrCreateRemote("ChestOpened")
local ChestRewardEvent = GetOrCreateRemote("ChestReward")
local RewardCancelledEvent = GetOrCreateRemote("RewardCancelled")
local ShowSubtitleEvent = GetOrCreateRemote("ShowSubtitle")

-- -------------------------------------------------------------------------------
-- CINEMATIC VISIBILITY SYSTEM
-- Hide players from each other during cinematics
-- -------------------------------------------------------------------------------

local CinematicVisibilitySystem = {}
local playersInCinematic = {} -- [userId] = true

function CinematicVisibilitySystem.HidePlayerFromEveryone(targetPlayer)
	local userId = targetPlayer.UserId
	playersInCinematic[userId] = true

	local character = targetPlayer.Character
	if not character then return end

	-- Make the character invisible to everyone else
	-- by setting all parts to LocalTransparencyModifier on clients
	-- We use a server-side approach: move character to a collision group
	-- and make parts transparent via attributes

	-- Set attribute so clients know this player is in cinematic
	targetPlayer:SetAttribute("InCinematic", true)

	-- Force character fully invisible on server side for all other players
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part:SetAttribute("PreCinematicTransparency", part.Transparency)
			part.Transparency = 1
		elseif part:IsA("Decal") or part:IsA("Texture") then
			part:SetAttribute("PreCinematicTransparency", part.Transparency)
			part.Transparency = 1
		elseif part:IsA("BillboardGui") or part:IsA("SurfaceGui") then
			part:SetAttribute("PreCinematicEnabled", part.Enabled)
			part.Enabled = false
		end
	end

	-- Disable character collision so others can't interact
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part:SetAttribute("PreCinematicCanCollide", part.CanCollide)
			part.CanCollide = false
		end
	end

	-- Also handle the Humanoid nametag
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid.NameDisplayDistance = 0
		humanoid.HealthDisplayDistance = 0
	end

	print("[CinematicVisibility] Hidden player: " .. targetPlayer.Name)
end

function CinematicVisibilitySystem.ShowPlayerToEveryone(targetPlayer)
	local userId = targetPlayer.UserId
	playersInCinematic[userId] = nil

	-- Remove cinematic attribute
	targetPlayer:SetAttribute("InCinematic", false)

	local character = targetPlayer.Character
	if not character then return end

	-- Restore all parts to original transparency
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			local original = part:GetAttribute("PreCinematicTransparency")
			if original ~= nil then
				part.Transparency = original
				part:SetAttribute("PreCinematicTransparency", nil)
			end
			local originalCollide = part:GetAttribute("PreCinematicCanCollide")
			if originalCollide ~= nil then
				part.CanCollide = originalCollide
				part:SetAttribute("PreCinematicCanCollide", nil)
			end
		elseif part:IsA("Decal") or part:IsA("Texture") then
			local original = part:GetAttribute("PreCinematicTransparency")
			if original ~= nil then
				part.Transparency = original
				part:SetAttribute("PreCinematicTransparency", nil)
			end
		elseif part:IsA("BillboardGui") or part:IsA("SurfaceGui") then
			local originalEnabled = part:GetAttribute("PreCinematicEnabled")
			if originalEnabled ~= nil then
				part.Enabled = originalEnabled
				part:SetAttribute("PreCinematicEnabled", nil)
			end
		end
	end

	-- Restore Humanoid display
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid.NameDisplayDistance = 100
		humanoid.HealthDisplayDistance = 100
	end

	print("[CinematicVisibility] Revealed player: " .. targetPlayer.Name)
end

function CinematicVisibilitySystem.IsInCinematic(targetPlayer)
	return playersInCinematic[targetPlayer.UserId] == true
end

-- Make it globally accessible so IntroCinematicModule can use it
_G.CinematicVisibilitySystem = CinematicVisibilitySystem

-- -------------------------------------------------------------------------------
-- LAMP CONFIGURATION - HORROR STREET LIGHTS
-- -------------------------------------------------------------------------------

local LAMP_HORROR_CONFIG = {
	-- Colores de luz amarilla horror
	LIGHT_COLOR = Color3.fromRGB(255, 180, 50),        -- Amarillo c?lido/horror
	LIGHT_COLOR_DIM = Color3.fromRGB(200, 140, 30),    -- Amarillo m?s oscuro para parpadeo

	-- Tama?o del foco (m?s peque?o y realista)
	BULB_SIZE = Vector3.new(0.8, 1.0, 0.8),            -- Foco m?s peque?o
	HOUSING_SIZE = Vector3.new(1.2, 0.3, 1.2),         -- Carcasa m?s peque?a

	-- Intensidad de luz
	BULB_BRIGHTNESS = 0.5,                              -- Brillo del foco (neon)
	BULB_TRANSPARENCY = 0.15,                           -- Transparencia del foco

	-- Luz principal
	MAIN_LIGHT_BRIGHTNESS = 4.0,                        -- Brillo de la luz principal
	MAIN_LIGHT_RANGE = 45,                              -- Rango de luz principal

	-- Luz del suelo (ambiente horror)
	GROUND_LIGHT_BRIGHTNESS = 3.4,                      -- Brillo luz suelo
	GROUND_LIGHT_RANGE = 30,                            -- Rango luz suelo

	-- -------------------------------------------------------------------
	-- CONFIGURACI?N DE PARPADEO - MODIFICA ESTOS VALORES
	-- -------------------------------------------------------------------
	FLICKER_CHANCE = 0.15,                              -- 15% probabilidad de que una luz parpadee (0.0 a 1.0)
	FLICKER_INTERVAL_MIN = 8,                           -- M?nimo segundos entre parpadeos
	FLICKER_INTERVAL_MAX = 25,                          -- M?ximo segundos entre parpadeos
	FLICKER_COUNT = 3,                                  -- N?mero de parpadeos
	FLICKER_SPEED = 0.12,                               -- Velocidad de cada parpadeo (segundos)
	FLICKER_OFF_BRIGHTNESS = 0.1,                       -- Brillo cuando est? "apagado"
	-- -------------------------------------------------------------------
}

-- -------------------------------------------------------------------------------
-- NPC CONFIGURATION - ALL 6 NPCs WITH FULL STATS
-- -------------------------------------------------------------------------------

local NPC_STATS = {
	HOLLOW = {
		NAME = "Hollow Man",
		SPAWN_EVENT = SpawnHollowManEvent,
		RARITY = "Common",
		SPAWN_WEIGHT = 22.5,
		REWARD_DOOR_OPEN = 5,
		REWARD_SURVIVAL = 15,
		SURVIVAL_TIME = 40,
		SPEED = 18,
		DAMAGE = 20,
		ATTACK_COOLDOWN = 0.8,
		ATTACK_RANGE = 5,
		DETECTION_RANGE = 200,
		LIFETIME = 40,
		USES_LARGE_DOOR = false,
		EYE_COLOR = Color3.new(1, 1, 1),
		EYE_TYPE = "HOLLOW_MAN",
		DESCRIPTION = "A void-like humanoid figure with glowing white eyes and an unsettling smile",
		DANGER_LEVEL = 1,
	},

	MINER = {
		NAME = "The Miner",
		SPAWN_EVENT = SpawnMinerEvent,
		RARITY = "Uncommon",
		SPAWN_WEIGHT = 12.5,
		REWARD_DOOR_OPEN = 5,
		REWARD_SURVIVAL = 25,
		SURVIVAL_TIME = 5,
		SPEED = 22,
		DAMAGE = 30,
		ATTACK_COOLDOWN = 1.0,
		ATTACK_RANGE = 8,
		DETECTION_RANGE = 180,
		LIFETIME = 5,
		USES_LARGE_DOOR = false,
		EYE_COLOR = Color3.fromRGB(200, 230, 255),
		EYE_TYPE = "MINER",
		DESCRIPTION = "A ghostly miner killed in an explosion, limps with a rusty pickaxe and a flickering helmet lantern",
		DANGER_LEVEL = 2,
	},

	SLENDER = {
		NAME = "The Slender",
		SPAWN_EVENT = SpawnSlenderEvent,
		RARITY = "Rare",
		SPAWN_WEIGHT = 7.5,
		REWARD_DOOR_OPEN = 5,
		REWARD_SURVIVAL = 60,
		SURVIVAL_TIME = 55,
		SPEED = 28,
		DAMAGE = 35,
		ATTACK_COOLDOWN = 0.7,
		ATTACK_RANGE = 9,
		DETECTION_RANGE = 280,
		LIFETIME = 55,
		USES_LARGE_DOOR = true,
		EYE_COLOR = Color3.fromRGB(5, 5, 5),
		EYE_TYPE = "SLENDER",
		DESCRIPTION = "An impossibly tall, thin creature with enormous clawed hands and a smile wider than its face",
		DANGER_LEVEL = 4,
	},

	CRAWLER = {
		NAME = "Crawler",
		SPAWN_EVENT = SpawnCrawlerEvent,
		RARITY = "Uncommon",
		SPAWN_WEIGHT = 12.5,
		REWARD_DOOR_OPEN = 5,
		REWARD_SURVIVAL = 20,
		SURVIVAL_TIME = 45,
		SPEED = 24,
		DAMAGE = 25,
		ATTACK_COOLDOWN = 0.5,
		ATTACK_RANGE = 6,
		DETECTION_RANGE = 250,
		LIFETIME = 45,
		USES_LARGE_DOOR = false,
		EYE_COLOR = Color3.fromRGB(0, 255, 150),
		EYE_TYPE = "CRAWLER_8EYES",
		DESCRIPTION = "An 8-legged spider-like creature with multiple green eyes",
		DANGER_LEVEL = 2,
	},

	PHANTOM = {
		NAME = "Phantom",
		SPAWN_EVENT = SpawnPhantomEvent,
		RARITY = "Uncommon",
		SPAWN_WEIGHT = 12.5,
		REWARD_DOOR_OPEN = 5,
		REWARD_SURVIVAL = 30,
		SURVIVAL_TIME = 50,
		SPEED = 20,
		DAMAGE = 35,
		ATTACK_COOLDOWN = 1.5,
		ATTACK_RANGE = 8,
		DETECTION_RANGE = 280,
		LIFETIME = 50,
		USES_LARGE_DOOR = false,
		EYE_COLOR = Color3.fromRGB(0, 200, 200),
		EYE_TYPE = "PHANTOM_GLOW",
		TELEPORT_COOLDOWN = 5,
		FREEZE_DURATION = 1.5,
		DESCRIPTION = "A floating ethereal ghost that can teleport and freeze players",
		DANGER_LEVEL = 3,
	},

	STITCHER = {
		NAME = "Stitcher",
		SPAWN_EVENT = SpawnStitcherEvent,
		RARITY = "Rare",
		SPAWN_WEIGHT = 7.5,
		REWARD_DOOR_OPEN = 5,
		REWARD_SURVIVAL = 50,
		SURVIVAL_TIME = 50,
		SPEED = 28,
		DAMAGE = 30,
		ATTACK_COOLDOWN = 0.6,
		ATTACK_RANGE = 6,
		DETECTION_RANGE = 220,
		LIFETIME = 50,
		USES_LARGE_DOOR = false,
		EYE_COLOR = Color3.fromRGB(255, 240, 200),
		EYE_TYPE = "STITCHER",
		DESCRIPTION = "A horrifying doll-like creature made of sewn-together fabric with needle fingers and mismatched button eyes",
		DANGER_LEVEL = 3,
	},

	SCREAMER = {
		NAME = "Screamer",
		SPAWN_EVENT = SpawnScreamerEvent,
		RARITY = "Rare",
		SPAWN_WEIGHT = 7.5,
		REWARD_DOOR_OPEN = 5,
		REWARD_SURVIVAL = 40,
		SURVIVAL_TIME = 50,
		SPEED = 20,
		DAMAGE = 65,
		ATTACK_COOLDOWN = 1.2,
		ATTACK_RANGE = 12,
		DETECTION_RANGE = 300,
		LIFETIME = 50,
		USES_LARGE_DOOR = true,
		EYE_COLOR = Color3.fromRGB(255, 0, 0),
		EYE_TYPE = "SCREAMER",
		DESCRIPTION = "A massive humanoid with a screaming mouth and brutal double-swipe attacks",
		DANGER_LEVEL = 4,
	},

	WATCHER = {
		NAME = "Watcher",
		SPAWN_EVENT = SpawnWatcherEvent,
		RARITY = "Rare",
		SPAWN_WEIGHT = 7.5,
		REWARD_DOOR_OPEN = 5,
		REWARD_SURVIVAL = 100,
		SURVIVAL_TIME = 60,
		SPEED = 24,
		DAMAGE = 40,
		ATTACK_COOLDOWN = 2.5,
		ATTACK_RANGE = 25,
		DETECTION_RANGE = 350,
		LIFETIME = 60,
		USES_LARGE_DOOR = true,
		EYE_COLOR = Color3.fromRGB(255, 255, 255),
		EYE_TYPE = "WATCHER",
		BEAM_CHARGE_TIME = 1.0,
		PARALYZE_DURATION = 1.5,
		DESCRIPTION = "A giant floating eyeball with tentacles that shoots paralyzing beams",
		DANGER_LEVEL = 4,
	},

	HARVESTER = {
		NAME = "Harvester",
		SPAWN_EVENT = SpawnHarvesterEvent,
		RARITY = "Legendary",
		SPAWN_WEIGHT = 2000.5,
		REWARD_DOOR_OPEN = 5,
		REWARD_SURVIVAL = 15000,
		SURVIVAL_TIME = 6,
		SPEED = 26,
		DAMAGE = 55,
		ATTACK_COOLDOWN = 1.8,
		ATTACK_RANGE = 10,
		DETECTION_RANGE = 320,
		LIFETIME = 6,
		USES_LARGE_DOOR = true,
		EYE_COLOR = Color3.fromRGB(255, 150, 150),
		EYE_TYPE = "HARVESTER_REAPER",
		TELEPORT_BEHIND_CHANCE = 0.2,
		SOUL_DRAIN_PERCENT = 0.1,
		DESCRIPTION = "A grim reaper with a massive scythe that can teleport behind you",
		DANGER_LEVEL = 5,
	},

	SHADOW_MAN = {
		NAME = "Shadow Man",
		SPAWN_EVENT = SpawnShadowManEvent,
		RARITY = "Rare",
		SPAWN_WEIGHT = 7.5,
		REWARD_DOOR_OPEN = 5,
		REWARD_SURVIVAL = 55,
		SURVIVAL_TIME = 50,
		SPEED = 22,
		DAMAGE = 30,
		ATTACK_COOLDOWN = 0.8,
		ATTACK_RANGE = 10,
		DETECTION_RANGE = 300,
		LIFETIME = 50,
		USES_LARGE_DOOR = false,
		EYE_COLOR = Color3.fromRGB(120, 0, 180),
		EYE_TYPE = "SHADOW_MAN",
		DESCRIPTION = "A living shadow wreathed in black fire that extinguishes lights and teleports through darkness",
		DANGER_LEVEL = 4,
	},
}

local TOTAL_NPC_WEIGHT = 0
for _, npcData in pairs(NPC_STATS) do
	TOTAL_NPC_WEIGHT = TOTAL_NPC_WEIGHT + npcData.SPAWN_WEIGHT
end

-- -------------------------------------------------------------------------------
-- DOOR OUTCOME CONFIGURATION - NEW PROBABILITY SYSTEM V2
-- -------------------------------------------------------------------------------

local DOOR_CONFIG = {
	-- Main probabilities (must sum to 100)
	DOOR_OPENS_CHANCE = 85,        -- 85% door opens
	DOOR_LOCKED_CHANCE = 15,       -- 15% door stays locked

	-- Of the 85% that opens (these percentages are OF THE TOTAL 100%):
	BAD_OUTCOME_CHANCE = 50,       -- 50% = NPC spawns (bad)
	GOOD_OUTCOME_CHANCE = 20,      -- 20% = Treasure chest (good)
	EVENT_OUTCOME_CHANCE = 15,     -- 15% = Random event (neutral)
	-- Note: 50 + 20 + 15 = 85, which equals DOOR_OPENS_CHANCE

	-- Good outcome settings
	GOOD_DOOR_OPEN_DURATION = 30,  -- Door stays open 30 seconds for good outcome
	CHEST_CLAIM_TIME = 30,         -- Players have 30 seconds to claim chest
}

-- -------------------------------------------------------------------------------
-- SOUND CONFIGURATION
-- -------------------------------------------------------------------------------

local DOOR_SOUNDS = {
	KNOCK = {
		id = "rbxassetid://75890067861325",
		volume = 0.9,
		duration = 1,
	},
	OPEN = {
		id = "rbxassetid://125335848390963",
		volume = 0.9,
		duration = 1.5,
	},
	CLOSE = {
		id = "rbxassetid://111817951216044",
		volume = 0.8,
		duration = 1.0,
	},
	CHEST_OPEN = {
		id = "rbxassetid://113890702074571",
		volume = 0.8,
		duration = 1.0,
	},
	CHEST_REVEAL = {
		id = "rbxassetid://",
		volume = 0.7,
		duration = 0.5,
	},
}

local NPC_SOUNDS = {
	HOLLOW = {
		id = "rbxassetid://138943631473339",
		volume = 0.1,
		duration = 3.6,
	},
	SCREAMER = {
		id = "rbxassetid://101616656965701",
		volume = 0.7,
		duration = 3.6,
	},
	CRAWLER = {
		id = "rbxassetid://122922351443677",
		volume = 0.5,
		duration = 3.0,
	},
	PHANTOM = {
		id = "rbxassetid://84942852431417",
		volume = 0.6,
		duration = 2.0,
	},
	WATCHER = {
		id = "rbxassetid://116711110416425",
		volume = 0.7,
		duration = 2.0,
	},
	HARVESTER = {
		id = "rbxassetid://131322398837604",
		volume = 0.8,
		duration = 3.0,
	},
	STITCHER = {
		id = "rbxassetid://9114120101",
		volume = 0.5,
		duration = 2.5,
	},
	MINER = {
		id = "rbxassetid://9114221580",
		volume = 0.4,
		duration = 3.0,
	},
	SLENDER = {
		id = "rbxassetid://9114221580",
		volume = 0.5,
		duration = 3.0,
	},
	SHADOW_MAN = {
		id = "rbxassetid://84942852431417",
		volume = 0.4,
		duration = 3.0,
	},
}

-- Rooftop runner sound config
local ROOFTOP_RUNNER_CONFIG = {
	MIN_INTERVAL = 120,
	MAX_INTERVAL = 300,
	SOUND_ID = "rbxassetid://9114488653",
	VOLUME = 0.4,
	DURATION = 3.5,
}

local DOOR_MASTER_VOLUME = 1.0
local NPC_MASTER_VOLUME = 1.0

local function CreateDoorSound(soundConfig, parent)
	local sound = Instance.new("Sound")
	sound.SoundId = soundConfig.id
	sound.Volume = soundConfig.volume * DOOR_MASTER_VOLUME
	sound.RollOffMaxDistance = 50
	sound.RollOffMinDistance = 5
	sound.Parent = parent
	return sound
end

local function CreateNPCSound(soundConfig, parent)
	local sound = Instance.new("Sound")
	sound.SoundId = soundConfig.id
	sound.Volume = soundConfig.volume * NPC_MASTER_VOLUME
	sound.RollOffMaxDistance = 60
	sound.RollOffMinDistance = 5
	sound.Parent = parent
	return sound
end

-- -------------------------------------------------------------------------------
-- GENERAL CONFIGURATION (STREET 15% NARROWER)
-- -------------------------------------------------------------------------------

-- Original street width was 50, now 15% narrower = 42.5
local STREET_NARROW_FACTOR = 0.85 -- 15% narrower

local CONFIG = {
	LOBBY_LENGTH = 150,
	LOBBY_START_X = -75,
	LOBBY_END_X = 75,

	-- Street dimensions (15% narrower)
	STREET_WIDTH = 50 * STREET_NARROW_FACTOR,           -- Was 50, now ~42.5
	STREET_SEGMENT_LENGTH = 100,
	SIDEWALK_WIDTH = 10 * STREET_NARROW_FACTOR,         -- Was 10, now ~8.5
	GENERATION_DISTANCE = 300,
	CLEANUP_DISTANCE = 500,

	-- Building dimensions (adjusted for closer buildings)
	BUILDING_WIDTH = 25,
	BUILDING_MIN_HEIGHT = 30,
	BUILDING_MAX_HEIGHT = 75,                           -- Slightly taller for more horror
	BUILDING_DEPTH = 15 * STREET_NARROW_FACTOR,         -- Was 15, now ~12.75

	DOOR_CHANCE = 0.28,                                 -- Slightly higher door chance
	DOOR_WIDTH = 5,
	DOOR_HEIGHT = 8,

	SURVIVAL_SHARE_RADIUS = 100,  -- distancia (studs) para que otros jugadores reciban la recompensa si sobreviven

	HOLE_WIDTH_NORMAL = 7,
	HOLE_HEIGHT_NORMAL = 10,
	HOLE_WIDTH_LARGE = 10,
	HOLE_HEIGHT_LARGE = 12,

	SIGN_WIDTH = 8,
	SIGN_HEIGHT = 3,

	COLORS = {
		STREET = Color3.fromRGB(40, 40, 45),
		SIDEWALK = Color3.fromRGB(70, 70, 75),
		BUILDING_1 = Color3.fromRGB(55, 50, 60),
		BUILDING_2 = Color3.fromRGB(65, 60, 70),
		BUILDING_3 = Color3.fromRGB(50, 55, 65),
		BUILDING_4 = Color3.fromRGB(70, 65, 75),
		BUILDING_TRIM = Color3.fromRGB(35, 33, 40),
		DOOR = Color3.fromRGB(100, 70, 35),
		DOOR_FRAME = Color3.fromRGB(140, 95, 50),
		DOOR_LIGHT = Color3.fromRGB(255, 200, 150),
		SIGN_BG = Color3.fromRGB(12, 10, 18),
		SIGN_TEXT = Color3.fromRGB(200, 180, 160),
		SIGN_BORDER = Color3.fromRGB(100, 80, 60),
		WINDOW_DARK = Color3.fromRGB(8, 8, 15),
		WINDOW_LIT = Color3.fromRGB(255, 200, 100),
		STREET_LINES = Color3.fromRGB(170, 170, 110),
		LAMP_POST = Color3.fromRGB(40, 40, 45),
		LAMP_LIGHT = Color3.fromRGB(255, 220, 180),
		VOID = Color3.fromRGB(0, 0, 0),
		LOBBY_FLOOR = Color3.fromRGB(65, 65, 70),
		LOBBY_ACCENT = Color3.fromRGB(75, 115, 170),
		SAFE_ZONE = Color3.fromRGB(45, 140, 95),
		-- Horror colors
		WINDOW_BROKEN_EDGE = Color3.fromRGB(20, 20, 30),
		WEATHERED_DOOR = Color3.fromRGB(70, 45, 25),
		SCRATCH_MARKS = Color3.fromRGB(35, 25, 15),
	},

	DOOR_NAMES = {
		"The Void", "No Return", "Shadows", "Oblivion", "Eternal Fog",
		"Whispers", "The Nothing", "Specters", "Abyss", "Twilight",
		"Silence", "Ghosts", "Darkness", "The End", "Mist",
		"Secrets", "Mystery", "Hidden", "Perdition", "Eternal",
		"Dark Caf?", "Fog Hotel", "Eclipse Bar", "Midnight Club",
		"Closed Shop", "Office 404", "Empty Studio", "Warehouse X",
		"Room 13", "Suite Omega", "Clinic", "Dead Archive",
		"??? ", "ERROR", "NULL", "VOID", "2: 47 AM", "For Rent", "5:05",
		"3:33", "CLOSED", "Nothing", "Gone", "Lost", "Forgotten",
		"Nightmare", "Dream", "Echo", "Static", "Glitch",
		"Don't Enter", "Help Me", "They Watch", "Run", "Behind You",
		"Too Late", "No Exit", "Stay Away", "Listen", "Scream",
		"Treasure? ", "Fortune", "Lucky", "Riches", "Hidden Gold",
	},

	LAMP_SPACING = 35,  -- Slightly closer lamps for narrower street
	LAMP_HEIGHT = 16,   -- Slightly shorter
}

-- -------------------------------------------------------------------------------
-- BUILDING AMBIENT SOUNDS - FALLING/CREAKING SOUNDS INSIDE BUILDINGS
-- -------------------------------------------------------------------------------

local BUILDING_SOUNDS_CONFIG = {
	-- Sound IDs for falling/creaking sounds inside buildings (ADD YOUR IDS HERE)
	FALLING_SOUNDS = {
		"rbxassetid://120192106656879",
		"rbxassetid://9120833712",
		"rbxassetid://9114120101",
	},

	MIN_INTERVAL = 30,
	MAX_INTERVAL = 90,
	MIN_VOLUME = 0.15,
	MAX_VOLUME = 0.4,
	MIN_PITCH = 0.8,
	MAX_PITCH = 1.2,
	ROLLOFF_MIN = 10,
	ROLLOFF_MAX = 80,
	PLAYER_DETECTION_RANGE = 200,
	SOUND_HEIGHT_MIN = 5,
	SOUND_HEIGHT_MAX = 40,
}

local BuildingSoundSystem = {
	activeSounds = {},
	isRunning = false,
}

function BuildingSoundSystem:GetRandomBuildingPosition()
	local players = Players:GetPlayers()
	if #players == 0 then return nil end

	local targetPlayer = players[math.random(1, #players)]
	local char = targetPlayer.Character
	if not char then return nil end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local playerX = hrp.Position.X

	if playerX >= CONFIG.LOBBY_START_X and playerX <= CONFIG.LOBBY_END_X then
		return nil
	end

	local side = math.random(1, 2) == 1 and "left" or "right"
	local streetEdge = CONFIG.STREET_WIDTH / 2 + CONFIG.SIDEWALK_WIDTH
	local buildingCenterZ

	if side == "left" then
		buildingCenterZ = -(streetEdge + CONFIG.BUILDING_DEPTH / 2)
	else
		buildingCenterZ = streetEdge + CONFIG.BUILDING_DEPTH / 2
	end

	local buildingWidth = CONFIG.BUILDING_WIDTH
	local nearestBuildingX = math.floor(playerX / buildingWidth) * buildingWidth + buildingWidth / 2
	local offsetX = math.random(-1, 1) * buildingWidth
	local soundX = nearestBuildingX + offsetX

	local soundY = math.random(BUILDING_SOUNDS_CONFIG.SOUND_HEIGHT_MIN, BUILDING_SOUNDS_CONFIG.SOUND_HEIGHT_MAX)
	local zOffset = (math.random() - 0.5) * CONFIG.BUILDING_DEPTH * 0.6
	local soundZ = buildingCenterZ + zOffset

	return Vector3.new(soundX, soundY, soundZ), side
end

function BuildingSoundSystem:PlayBuildingSound(position)
	if #BUILDING_SOUNDS_CONFIG.FALLING_SOUNDS == 0 then
		warn("[BuildingSoundSystem] No sound IDs configured!")
		return
	end

	local soundPart = Instance.new("Part")
	soundPart.Name = "BuildingSound"
	soundPart.Size = Vector3.new(0.5, 0.5, 0.5)
	soundPart.Position = position
	soundPart.Anchored = true
	soundPart.CanCollide = false
	soundPart.Transparency = 1
	soundPart.Parent = workspace

	local sound = Instance.new("Sound")
	sound.SoundId = BUILDING_SOUNDS_CONFIG.FALLING_SOUNDS[math.random(1, #BUILDING_SOUNDS_CONFIG.FALLING_SOUNDS)]
	sound.Volume = BUILDING_SOUNDS_CONFIG.MIN_VOLUME + math.random() * (BUILDING_SOUNDS_CONFIG.MAX_VOLUME - BUILDING_SOUNDS_CONFIG.MIN_VOLUME)
	sound.PlaybackSpeed = BUILDING_SOUNDS_CONFIG.MIN_PITCH + math.random() * (BUILDING_SOUNDS_CONFIG.MAX_PITCH - BUILDING_SOUNDS_CONFIG.MIN_PITCH)
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = BUILDING_SOUNDS_CONFIG.ROLLOFF_MIN
	sound.RollOffMaxDistance = BUILDING_SOUNDS_CONFIG.ROLLOFF_MAX
	sound.Parent = soundPart

	sound:Play()

	sound.Ended:Connect(function()
		if soundPart and soundPart.Parent then
			soundPart:Destroy()
		end
	end)

	Debris:AddItem(soundPart, 10)
end

function BuildingSoundSystem:Start()
	if self.isRunning then return end
	self.isRunning = true

	coroutine.wrap(function()
		task.wait(math.random(10, 30))

		while self.isRunning do
			local position = self:GetRandomBuildingPosition()

			if position then
				self:PlayBuildingSound(position)
			end

			local waitTime = math.random(BUILDING_SOUNDS_CONFIG.MIN_INTERVAL, BUILDING_SOUNDS_CONFIG.MAX_INTERVAL)
			task.wait(waitTime)
		end
	end)()

	print("[BuildingSoundSystem] Building ambient sounds started")
end

function BuildingSoundSystem:Stop()
	self.isRunning = false
end

-- Make it globally accessible
_G.BuildingSoundSystem = BuildingSoundSystem

-- Global variables
local streetSegments = {}
local generatedSegments = {}
local worldFolder = Instance.new("Folder")
worldFolder.Name = "InfiniteStreetWorld"
worldFolder.Parent = workspace

local lobbyFolder = Instance.new("Folder")
lobbyFolder.Name = "LobbyArea"
lobbyFolder.Parent = workspace

local buildingColors = {CONFIG.COLORS.BUILDING_1, CONFIG.COLORS.BUILDING_2, CONFIG.COLORS.BUILDING_3, CONFIG.COLORS.BUILDING_4}
local doorsBeingUsed = {}
local playerDoorSurvival = {}
local activeDoorOutcomes = {} -- Track door outcomes that reset after closing

-- -------------------------------------------------------------------------------
-- AMBASSADOR TRACKING - Per-player door open counter
-- -------------------------------------------------------------------------------

local AMBASSADOR_DOOR_NUMBER = 2 -- Ambassador appears on the 2nd door (for testing; change to 10 for production)
local playerDoorOpenCount = {} -- [userId] = number of doors opened
local playerHasSeenAmbassador = {} -- [userId] = true/false

-- Load EndgameCinematicModule to check if ambassador should appear
local EndgameCinematicModule = nil
pcall(function()
	EndgameCinematicModule = require(ServerScriptService:WaitForChild("EndgameCinematicModule", 5))
end)
if EndgameCinematicModule then
	print("[MainGameServer] ? EndgameCinematicModule loaded!")
else
	warn("[MainGameServer] ?? EndgameCinematicModule not loaded")
end
_G.IsInSafeZone = function(position)
	return position.X >= CONFIG.LOBBY_START_X and position.X <= CONFIG.LOBBY_END_X
end

_G.SafeZoneBounds = {
	minX = CONFIG.LOBBY_START_X,
	maxX = CONFIG.LOBBY_END_X
}

-- -------------------------------------------------------------------------------
-- TRUE RANDOM GENERATOR
-- -------------------------------------------------------------------------------

local randomGenerator = Random.new()

local function TrueRandom(min, max)
	return randomGenerator:NextInteger(min, max)
end

local function TrueRandomFloat()
	return randomGenerator:NextNumber()
end

local function SeededRandom(seed, min, max)
	local x = math.sin(seed * 12.9898 + seed * 78.233) * 43758.5453
	local normalized = x - math.floor(x)
	return math.floor(min + normalized * (max - min + 1))
end

local function SeededRandomFloat(seed)
	local x = math.sin(seed * 12.9898 + seed * 78.233) * 43758.5453
	return x - math.floor(x)
end

-- -------------------------------------------------------------------------------
-- DOOR OUTCOME SYSTEM - NEW PROBABILITY LOGIC WITH EVENTS
-- -------------------------------------------------------------------------------

local function GetDoorOutcome(doorId)
	-- Check if we should use cached outcome or generate new one
	if doorId and activeDoorOutcomes[doorId] and not DoorAntiExploitModule.ShouldRerollDoor(doorId) then
		return activeDoorOutcomes[doorId].outcome, activeDoorOutcomes[doorId].npcType, activeDoorOutcomes[doorId].eventId
	end

	local roll = TrueRandomFloat() * 100

	-- 15% chance door stays locked
	if roll < DOOR_CONFIG.DOOR_LOCKED_CHANCE then
		return "nothing", nil, nil
	end

	-- Door opens (85% chance)
	-- Calculate which outcome based on the roll
	local openingRoll = roll - DOOR_CONFIG.DOOR_LOCKED_CHANCE

	if openingRoll < DOOR_CONFIG.BAD_OUTCOME_CHANCE then
		-- Bad outcome - NPC spawns (50% of total)
		local npcRoll = TrueRandomFloat() * TOTAL_NPC_WEIGHT
		local accumulated = 0

		for npcType, npcData in pairs(NPC_STATS) do
			accumulated = accumulated + npcData.SPAWN_WEIGHT
			if npcRoll <= accumulated then
				return "npc", npcType, nil
			end
		end

		return "npc", "HOLLOW", nil

	elseif openingRoll < DOOR_CONFIG.BAD_OUTCOME_CHANCE + DOOR_CONFIG.GOOD_OUTCOME_CHANCE then
		-- Good outcome - treasure chest (20% of total)
		return "treasure", nil, nil

	else
		-- Event outcome - random special event (15% of total)
		if DoorEventsModule then
			local eventId, eventData = DoorEventsModule.SelectRandomEvent()
			return "event", nil, eventId
		else
			-- Fallback to treasure if events module not loaded
			return "treasure", nil, nil
		end
	end
end

local function GetRandomDoorName()
	return CONFIG.DOOR_NAMES[TrueRandom(1, #CONFIG.DOOR_NAMES)]
end

-- -------------------------------------------------------------------------------
-- UTILITIES
-- -------------------------------------------------------------------------------

local function LerpColor(c1, c2, t)
	return Color3.new(c1.R + (c2.R - c1.R) * t, c1.G + (c2.G - c1.G) * t, c1.B + (c2.B - c1.B) * t)
end

local function MakePart(name, size, position, color, material, parent, canCollide, castShadow, transparency)
	local part = Instance.new("Part")
	part.Name = name or "Part"
	part.Size = size or Vector3.new(1, 1, 1)
	part.Position = position or Vector3.new(0, 0, 0)
	part.Color = color or Color3.new(1, 1, 1)
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = canCollide ~= false
	part.CastShadow = castShadow ~= false
	part.Transparency = transparency or 0
	part.Parent = parent or workspace
	return part
end

local function GetPlayersNearPosition(position, radius)
	local nearbyPlayers = {}
	for _, player in pairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local distance = (hrp.Position - position).Magnitude
				if distance <= radius then
					table.insert(nearbyPlayers, player)
				end
			end
		end
	end
	return nearbyPlayers
end

-- -------------------------------------------------------------------------------
-- LIGHTING
-- -------------------------------------------------------------------------------

local function SetupAtmosphere()
	Lighting.Brightness = 0.6
	Lighting.Ambient = Color3.fromRGB(35, 35, 45)
	Lighting.OutdoorAmbient = Color3.fromRGB(50, 45, 60)
	Lighting.ClockTime = 4.2
	Lighting.GeographicLatitude = 45
	Lighting.FogColor = Color3.fromRGB(15, 13, 25)
	Lighting.FogEnd = 450
	Lighting.FogStart = 60
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35

	local atm = Lighting: FindFirstChild("Atmosphere") or Instance.new("Atmosphere")
	atm.Name = "Atmosphere"
	atm.Density = 0.4
	atm.Offset = 0.1
	atm.Color = Color3.fromRGB(45, 40, 60)
	atm.Decay = Color3.fromRGB(35, 30, 50)
	atm.Glare = 0.08
	atm.Haze = 6
	atm.Parent = Lighting

	local bloom = Lighting:FindFirstChild("BloomEffect") or Instance.new("BloomEffect")
	bloom.Name = "BloomEffect"
	bloom.Intensity = 0.45
	bloom.Size = 45
	bloom.Threshold = 1.05
	bloom.Parent = Lighting

	local cc = Lighting:FindFirstChild("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	cc.Name = "ColorCorrectionEffect"
	cc.Brightness = 0.03
	cc.Contrast = 0.18
	cc.Saturation = -0.25
	cc.TintColor = Color3.fromRGB(215, 205, 225)
	cc.Parent = Lighting

	local sky = Lighting:FindFirstChild("Sky") or Instance.new("Sky")
	sky.Name = "Sky"
	sky.StarCount = 1800
	sky.MoonAngularSize = 12
	sky.SunAngularSize = 0
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting
end

-- -------------------------------------------------------------------------------
-- WINDOWS WITH ENHANCED HORROR EFFECTS
-- -------------------------------------------------------------------------------

local function CreateWindows(centerX, centerY, faceZ, width, height, zDir, parent, doorCenterX, holeWidth)
	local winW, winH = 2.2, 3.2
	local gapH, gapV = 5.0, 5.5
	local startY = 5.5
	local hw = holeWidth or CONFIG.HOLE_WIDTH_NORMAL

	local cols = math.floor((width - 5) / gapH)
	local rows = math.floor((height - startY - 3) / gapV)

	for row = 1, rows do
		for col = 1, cols do
			local offX = -width/2 + 3.5 + (col - 0.5) * gapH
			local offY = -height/2 + startY + (row - 0.5) * gapV
			local winX = centerX + offX
			local winY = centerY + offY

			local nearDoor = doorCenterX and math.abs(winX - doorCenterX) < (hw/2 + 0.8)
			if nearDoor and row <= 2 then
				continue
			end

			local windowSeed = winX * 100 + winY + centerX * 7
			local lit = SeededRandomFloat(windowSeed) < 0.06

			-- Determine if this is a high window (for shadow figure)
			local isHighWindow = row >= rows - 2

			-- Window frame
			MakePart("WinFrame", Vector3.new(winW + 0.35, winH + 0.35, 0.12),
				Vector3.new(winX, winY, faceZ + zDir * 0.06),
				CONFIG.COLORS.BUILDING_TRIM, Enum.Material.Concrete, parent, false, false)

			-- Base window
			local winColor = lit and CONFIG.COLORS.WINDOW_LIT or CONFIG.COLORS.WINDOW_DARK
			local winMat = lit and Enum.Material.Neon or Enum.Material.Glass
			local winTrans = lit and 0 or 0.85

			local win = MakePart("Window", Vector3.new(winW, winH, 0.06),
				Vector3.new(winX, winY, faceZ + zDir * 0.12),
				winColor, winMat, parent, false, false, winTrans)

			if lit then
				local light = Instance.new("PointLight")
				light.Brightness = 0.35
				light.Color = CONFIG.COLORS.WINDOW_LIT
				light.Range = 10
				light.Shadows = false
				light.Parent = win
			end

			-- Apply horror effects using the module
			if HorrorDetailsModule and not lit then
				HorrorDetailsModule.ApplyWindowHorror(
					winX, winY, faceZ, zDir, winW, winH, 
					parent, windowSeed, height, isHighWindow
				)
			end
		end
	end
end

-- -------------------------------------------------------------------------------
-- DOOR SYSTEM WITH VOID, TREASURE, EVENTS, AND ANTI-EXPLOIT
-- -------------------------------------------------------------------------------

local function CreateDoorWithVoid(doorX, faceZ, backZ, zDir, side, parent, buildingColor)
	local doorFolder = Instance.new("Folder")
	doorFolder.Name = "DoorSystem"
	doorFolder.Parent = parent

	-- Generate unique door ID based on position
	local doorId = string.format("door_%.0f_%.0f_%s", doorX, faceZ, side)

	local floorY = 0.5
	local doorCenterY = floorY + CONFIG.DOOR_HEIGHT / 2

	-- Default hole size (will be updated if NPC outcome)
	local holeW = CONFIG.HOLE_WIDTH_NORMAL
	local holeH = CONFIG.HOLE_HEIGHT_NORMAL

	local voidDepth = math.abs(backZ - faceZ)
	local voidCenterZ = (faceZ + backZ) / 2

	-- Void parts
	MakePart("VoidBack", Vector3.new(holeW, holeH, 1),
		Vector3.new(doorX, floorY + holeH/2 - 0.5, backZ + zDir * 0.5),
		CONFIG.COLORS.VOID, Enum.Material.SmoothPlastic, doorFolder, true, false)

	MakePart("VoidLeft", Vector3.new(0.3, holeH, voidDepth),
		Vector3.new(doorX - holeW/2 + 0.15, floorY + holeH/2 - 0.5, voidCenterZ),
		CONFIG.COLORS.VOID, Enum.Material.SmoothPlastic, doorFolder, true, false)

	MakePart("VoidRight", Vector3.new(0.3, holeH, voidDepth),
		Vector3.new(doorX + holeW/2 - 0.15, floorY + holeH/2 - 0.5, voidCenterZ),
		CONFIG.COLORS.VOID, Enum.Material.SmoothPlastic, doorFolder, true, false)

	MakePart("VoidTop", Vector3.new(holeW, 0.3, voidDepth),
		Vector3.new(doorX, floorY + holeH - 0.65, voidCenterZ),
		CONFIG.COLORS.VOID, Enum.Material.SmoothPlastic, doorFolder, true, false)

	MakePart("VoidFloor", Vector3.new(holeW, 0.3, voidDepth),
		Vector3.new(doorX, floorY - 0.35, voidCenterZ),
		CONFIG.COLORS.VOID, Enum.Material.SmoothPlastic, doorFolder, true, false)

	-- Door frame
	local frameT = 0.4
	local frameZ = faceZ + zDir * 0.05

	MakePart("FrameTop", Vector3.new(CONFIG.DOOR_WIDTH + frameT*2, frameT, 0.4),
		Vector3.new(doorX, floorY + CONFIG.DOOR_HEIGHT + frameT/2, frameZ),
		CONFIG.COLORS.DOOR_FRAME, Enum.Material.Wood, doorFolder, false)

	MakePart("FrameLeft", Vector3.new(frameT, CONFIG.DOOR_HEIGHT, 0.4),
		Vector3.new(doorX - CONFIG.DOOR_WIDTH/2 - frameT/2, doorCenterY, frameZ),
		CONFIG.COLORS.DOOR_FRAME, Enum.Material.Wood, doorFolder, false)

	MakePart("FrameRight", Vector3.new(frameT, CONFIG.DOOR_HEIGHT, 0.4),
		Vector3.new(doorX + CONFIG.DOOR_WIDTH/2 + frameT/2, doorCenterY, frameZ),
		CONFIG.COLORS.DOOR_FRAME, Enum.Material.Wood, doorFolder, false)

	-- Cover gaps
	local totalFrameW = CONFIG.DOOR_WIDTH + frameT * 2
	local sideGap = (holeW - totalFrameW) / 2

	if sideGap > 0.05 then
		MakePart("CoverL", Vector3.new(sideGap, holeH, 0.25),
			Vector3.new(doorX - totalFrameW/2 - sideGap/2, floorY + holeH/2 - 0.5, faceZ),
			buildingColor, Enum.Material.Concrete, doorFolder, false, false)

		MakePart("CoverR", Vector3.new(sideGap, holeH, 0.25),
			Vector3.new(doorX + totalFrameW/2 + sideGap/2, floorY + holeH/2 - 0.5, faceZ),
			buildingColor, Enum.Material.Concrete, doorFolder, false, false)
	end

	local topGap = holeH - CONFIG.DOOR_HEIGHT - frameT
	if topGap > 0.05 then
		MakePart("CoverT", Vector3.new(holeW, topGap, 0.25),
			Vector3.new(doorX, floorY + CONFIG.DOOR_HEIGHT + frameT + topGap/2, faceZ),
			buildingColor, Enum.Material.Concrete, doorFolder, false, false)
	end

	-- Door model
	local doorModel = Instance.new("Model")
	doorModel.Name = "DoorModel"
	doorModel.Parent = doorFolder

	local hingeX = doorX - CONFIG.DOOR_WIDTH / 2
	local doorZ = faceZ + zDir * 0.1
	local doorThick = 0.25

	local door = Instance.new("Part")
	door.Name = "Door"
	door.Size = Vector3.new(CONFIG.DOOR_WIDTH, CONFIG.DOOR_HEIGHT, doorThick)
	door.Position = Vector3.new(doorX, doorCenterY, doorZ)
	door.Color = CONFIG.COLORS.DOOR
	door.Material = Enum.Material.Wood
	door.Anchored = true
	door.CanCollide = true
	door.Parent = doorModel

	-- Apply weathering using HorrorDetailsModule
	local isWeathered = TrueRandomFloat() < 0.25
	if isWeathered and HorrorDetailsModule then
		HorrorDetailsModule.ApplyDoorWeathering(door, doorFolder, CONFIG.DOOR_WIDTH, CONFIG.DOOR_HEIGHT)
	end

	-- Door panels
	local panelColor = LerpColor(CONFIG.COLORS.DOOR, Color3.fromRGB(75, 45, 25), 0.15)
	if isWeathered then
		panelColor = LerpColor(panelColor, Color3.fromRGB(45, 30, 15), 0.3)
	end
	local panels = {}

	for py = 1, 2 do
		for px = 1, 2 do
			local pw = CONFIG.DOOR_WIDTH/2 - 0.5
			local ph = CONFIG.DOOR_HEIGHT/2 - 0.8
			local ox = (px - 1.5) * (CONFIG.DOOR_WIDTH/2 - 0.15)
			local oy = (py - 1.5) * (CONFIG.DOOR_HEIGHT/2 - 0.25)

			local panel = Instance.new("Part")
			panel.Name = "Panel"
			panel.Size = Vector3.new(pw, ph, 0.08)
			panel.Position = door.Position + Vector3.new(ox, oy, zDir * (doorThick/2 + 0.04))
			panel.Color = panelColor
			panel.Material = isWeathered and Enum.Material.WoodPlanks or Enum.Material.Wood
			panel.Anchored = true
			panel.CanCollide = false
			panel.Parent = doorModel
			table.insert(panels, {part = panel, offset = Vector3.new(ox, oy, zDir * (doorThick/2 + 0.04))})
		end
	end

	-- Handle
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.15, 0.7, 0.15)
	handle.Position = door.Position + Vector3.new(CONFIG.DOOR_WIDTH/2 - 0.5, -0.15, zDir * (doorThick/2 + 0.08))
	handle.Color = isWeathered and Color3.fromRGB(110, 90, 50) or Color3.fromRGB(180, 160, 80)
	handle.Material = Enum.Material.Metal
	handle.Anchored = true
	handle.CanCollide = false
	handle.Parent = doorModel

	-- Interaction
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 10
	click.Parent = door

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Knock"
	prompt.ObjectText = "Door"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = door

	-- Door light
	local doorLight = MakePart("DoorLight", Vector3.new(0.6, 0.3, 0.3),
		Vector3.new(doorX, floorY + CONFIG.DOOR_HEIGHT + 1, faceZ + zDir * 0.5),
		CONFIG.COLORS.DOOR_LIGHT, Enum.Material.Neon, doorFolder, false, false, 0.1)
	local dl = Instance.new("PointLight")
	dl.Brightness = 0.65
	dl.Color = CONFIG.COLORS.DOOR_LIGHT
	dl.Range = 9
	dl.Shadows = false
	dl.Parent = doorLight

	-- Sign
	local signZ = faceZ + zDir * 1.2
	local signBG = MakePart("SignBG", Vector3.new(CONFIG.SIGN_WIDTH, CONFIG.SIGN_HEIGHT, 0.12),
		Vector3.new(doorX, floorY + CONFIG.DOOR_HEIGHT + CONFIG.SIGN_HEIGHT/2 + 2, signZ),
		CONFIG.COLORS.SIGN_BG, Enum.Material.SmoothPlastic, doorFolder, false)

	MakePart("SignBorderT", Vector3.new(CONFIG.SIGN_WIDTH + 0.2, 0.08, 0.2),
		signBG.Position + Vector3.new(0, CONFIG.SIGN_HEIGHT/2 + 0.04, 0),
		CONFIG.COLORS.SIGN_BORDER, Enum.Material.Metal, doorFolder, false)

	MakePart("SignBorderB", Vector3.new(CONFIG.SIGN_WIDTH + 0.2, 0.08, 0.2),
		signBG.Position + Vector3.new(0, -CONFIG.SIGN_HEIGHT/2 - 0.04, 0),
		CONFIG.COLORS.SIGN_BORDER, Enum.Material.Metal, doorFolder, false)

	local doorName = GetRandomDoorName()
	for _, f in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = f
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 45
		gui.Parent = signBG

		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.new(1, 0, 1, 0)
		txt.BackgroundTransparency = 1
		txt.Text = doorName
		txt.TextColor3 = CONFIG.COLORS.SIGN_TEXT
		txt.TextScaled = true
		txt.Font = Enum.Font.Antique
		txt.Parent = gui
	end

	local signL = Instance.new("PointLight")
	signL.Brightness = 0.2
	signL.Color = Color3.fromRGB(190, 170, 140)
	signL.Range = 4
	signL.Parent = signBG

	-- Create door animator using AnimationsModule
	local doorAnimator = AnimationsModule.CreateDoorAnimator(
		door, panels, handle, hingeX, doorCenterY, doorZ, CONFIG.DOOR_WIDTH, zDir
	)

	-- Active chest data for this door
	local activeChest = nil
	local chestReward = nil

	-- Interaction handler
	local function OnInteract(player)
		-- =====================================================================
		-- CHECK IF PLAYER HAS ALREADY OPENED THIS DOOR
		-- =====================================================================
		if DoorAntiExploitModule.HasPlayerOpenedDoor(doorId, player) then
			DoorLockedEvent:FireClient(player, "You've already opened this door...")
			return
		end

		local id = tostring(door:GetFullName())
		if doorsBeingUsed[id] then return end
		doorsBeingUsed[id] = true

		local char = player.Character
		if not char then doorsBeingUsed[id] = nil return end

		local hum = char:FindFirstChild("Humanoid")
		if not hum then doorsBeingUsed[id] = nil return end

		-- =====================================================================
		-- MARK DOOR AS OPENED BY THIS PLAYER (Before any rewards)
		-- =====================================================================
		DoorAntiExploitModule.MarkDoorAsOpened(doorId, player)

		-- =====================================================================
		-- REGISTER DOOR ZONE FOR TRAPPED PLAYER DETECTION
		-- =====================================================================
		DoorAntiExploitModule.RegisterDoorZone(doorId, doorX, faceZ, backZ, zDir)

		-- =====================================================================
		-- INCREMENT PLAYER DOOR COUNTER
		-- =====================================================================
		local userId = player.UserId
		playerDoorOpenCount[userId] = (playerDoorOpenCount[userId] or 0) + 1
		local currentDoorCount = playerDoorOpenCount[userId]

		print("[MainGameServer] Player " .. player.Name .. " opened door #" .. currentDoorCount)

		-- =====================================================================
		-- CHECK IF THIS IS THE AMBASSADOR DOOR (AND IF PLAYER SHOULD SEE IT)
		-- =====================================================================
		local forceAmbassador = false
		if currentDoorCount == AMBASSADOR_DOOR_NUMBER and not playerHasSeenAmbassador[userId] then
			-- Check if player already completed the endgame (persistent)
			local shouldShowAmbassador = true
			if EndgameCinematicModule and EndgameCinematicModule.HasCompletedEndgame then
				shouldShowAmbassador = EndgameCinematicModule.ShouldShowAmbassador(player)
			end

			if shouldShowAmbassador then
				forceAmbassador = true
				playerHasSeenAmbassador[userId] = true
				print("[MainGameServer] ??? AMBASSADOR EVENT TRIGGERED for " .. player.Name .. " (Door #" .. currentDoorCount .. ")")
			else
				print("[MainGameServer] ??? Ambassador skipped for " .. player.Name .. " (endgame already completed)")
			end
		end

		local origSpeed = hum.WalkSpeed
		local origJump = hum.JumpPower
		hum.WalkSpeed = 0
		hum.JumpPower = 0

		-- Generate outcome for this player's interaction
		local outcome, npcType, eventId

		if forceAmbassador then
			-- FORCE Ambassador event
			outcome = "forced_event"
			npcType = nil
			eventId = "ambassador"
		else
			outcome, npcType, eventId = GetDoorOutcome(doorId)
		end

		local npcData = npcType and NPC_STATS[npcType] or nil

		-- Store the outcome for this door
		activeDoorOutcomes[doorId] = {outcome = outcome, npcType = npcType, eventId = eventId}
		DoorAntiExploitModule.SetDoorState(doorId, outcome, npcType)

		-- =====================================================================
		-- GIVE $5 VC REWARD FOR OPENING ANY DOOR (except locked doors)
		-- =====================================================================
		if outcome ~= "nothing" then
			DoorOpenedEvent:FireClient(player, 5)
			if _G.CurrencySystem and _G.CurrencySystem.OnDoorOpened then
				_G.CurrencySystem.OnDoorOpened(player, 5)
			end
		end

		-- Knock animation
		local knockSound = CreateDoorSound(DOOR_SOUNDS.KNOCK, door)
		knockSound:Play()
		AnimationsModule.PlayKnockVibration(door, zDir)
		task.wait(DOOR_SOUNDS.KNOCK.duration + 0.2)
		knockSound:Destroy()

		-- =====================================================================
		-- OUTCOME: FORCED EVENT (AMBASSADOR - 10th door)
		-- =====================================================================
		if outcome == "forced_event" and eventId and DoorEventsModule then
			print("? [MainGameServer] Forcing Ambassador event for " .. player.Name)

			local eventResult = DoorEventsModule.ForceExecuteEvent(
				eventId,
				doorX,
				faceZ,
				backZ,
				zDir,
				doorFolder,
				doorAnimator,
				player,
				DOOR_SOUNDS,
				CreateDoorSound
			)

			if eventResult and eventResult.success then
				print("? [MainGameServer] Ambassador event completed successfully for " .. player.Name)
			else
				warn("? [MainGameServer] Ambassador event failed for " .. player.Name)
			end

			DoorAntiExploitModule.OnDoorClosed(doorId)
			DoorAntiExploitModule.ResetDoorState(doorId)
			activeDoorOutcomes[doorId] = nil

			-- =====================================================================
			-- OUTCOME: EVENT (15% of total when door opens)
			-- =====================================================================
		elseif outcome == "event" and eventId and DoorEventsModule then
			print("?? Executing door event: " .. eventId)

			local eventResult = DoorEventsModule.ExecuteEvent(
				eventId,
				doorX,
				faceZ,
				backZ,
				zDir,
				doorFolder,
				doorAnimator,
				player,
				DOOR_SOUNDS,
				CreateDoorSound
			)

			if eventResult and eventResult.success then
				print("? [MainGameServer] Event '" .. eventId .. "' completed successfully")
			end

			DoorAntiExploitModule.OnDoorClosed(doorId)
			DoorAntiExploitModule.ResetDoorState(doorId)
			activeDoorOutcomes[doorId] = nil

			-- =====================================================================
			-- OUTCOME: NPC (BAD - 50% of total when door opens)
			-- =====================================================================
		elseif outcome == "npc" and npcData then
			-- Update hole size for large NPCs
			if npcData.USES_LARGE_DOOR then
				holeW = CONFIG.HOLE_WIDTH_LARGE
				holeH = CONFIG.HOLE_HEIGHT_LARGE
			end

			local openSound = CreateDoorSound(DOOR_SOUNDS.OPEN, door)
			openSound:Play()

			local openAng = zDir * -80
			doorAnimator.OpenDoor(openAng, DOOR_SOUNDS.OPEN.duration)
			task.wait(0.3)

			local npcSoundConfig = NPC_SOUNDS[npcType] or NPC_SOUNDS.HOLLOW
			local npcSound = CreateNPCSound(npcSoundConfig, door)
			npcSound:Play()

			-- Create eyes for NPC
			local eyeY = floorY + CONFIG.DOOR_HEIGHT/2 + 1.5
			local eyeZ = voidCenterZ

			local eyeType = npcData.EYE_TYPE or "STANDARD"
			local eyeColor = npcData.EYE_COLOR or Color3.new(1, 1, 1)

			local eyeParts, eyeLights, eyeAnimator = AnimationsModule.CreateEyesForNPC(
				eyeType, eyeColor, doorX, eyeY, eyeZ, doorFolder, MakePart,
				voidCenterZ, holeW, holeH, zDir
			)

			local horrorDuration = 0
			if eyeAnimator.GetHorrorDuration then
				horrorDuration = eyeAnimator.GetHorrorDuration()
			end

			eyeAnimator.FadeInEyes()

			if horrorDuration > 0 then
				task.wait(0.5)
			else
				task.wait(AnimationsModule.TIMING.EYES_VISIBLE_DURATION)
				eyeAnimator.BlinkEyes()
				eyeAnimator.FadeOutEyes()
			end

			local spawnPos = Vector3.new(doorX, 0, faceZ - zDir * 1.2)
			local doorFrameInfo = {
				faceZ = faceZ,
				holeWidth = holeW,
				holeHeight = holeH
			}

			-- SHARE SURVIVAL REWARDS WITH NEARBY PLAYERS
			local shareRadius = CONFIG.SURVIVAL_SHARE_RADIUS or 45
			local nearbyPlayers = GetPlayersNearPosition(Vector3.new(doorX, floorY, faceZ), shareRadius)

			for i, p in ipairs(nearbyPlayers) do
				if p and p.Parent then
					local existingKey = nil
					for key, data in pairs(playerDoorSurvival) do
						if data.player == p then
							existingKey = key
							break
						end
					end
					if existingKey then
						DoorAntiExploitModule.StopTracking(existingKey)
						playerDoorSurvival[existingKey] = nil
					end

					local survivalKey = tostring(p.UserId) .. "_" .. tostring(npcType) .. "_" .. tostring(math.floor(tick())) .. "_" .. tostring(i)

					playerDoorSurvival[survivalKey] = {
						player = p,
						startTime = tick(),
						reward = npcData.REWARD_SURVIVAL,
						npcType = npcType,
						survivalTime = npcData.SURVIVAL_TIME,
						notified = false
					}

					DoorAntiExploitModule.StartTrackingPlayer(
						survivalKey,
						p,
						doorX,
						npcData.REWARD_SURVIVAL,
						npcData.SURVIVAL_TIME,
						function(pCancelled, reason)
							if reason == "ENTERED_LOBBY" then
								RewardCancelledEvent:FireClient(pCancelled, "You entered the safe zone! Survival reward cancelled.")
								playerDoorSurvival[survivalKey] = nil
							end
						end
					)

					coroutine.wrap(function()
						task.wait(npcData.SURVIVAL_TIME)
						local data = playerDoorSurvival[survivalKey]

						if DoorAntiExploitModule.IsRewardCancelled(survivalKey) then
							playerDoorSurvival[survivalKey] = nil
							DoorAntiExploitModule.StopTracking(survivalKey)
							return
						end

						if data and not data.notified and data.player and data.player.Parent then
							local pChar = data.player.Character
							if pChar then
								local pHum = pChar:FindFirstChild("Humanoid")
								if pHum and pHum.Health > 0 then
									data.notified = true
									SurvivedDoorEvent:FireClient(data.player, data.reward, data.npcType)
									if _G.CurrencySystem and _G.CurrencySystem.OnSurvived then
										_G.CurrencySystem.OnSurvived(data.player, data.reward, data.npcType)
									end
								end
							end
						end

						playerDoorSurvival[survivalKey] = nil
						DoorAntiExploitModule.StopTracking(survivalKey)
					end)()
				end
			end

			if npcData.SPAWN_EVENT then
				local npcLifetime = npcData.LIFETIME
				print("?? Spawning " .. npcData.NAME .. " with LIFETIME: " .. npcLifetime .. " seconds")
				npcData.SPAWN_EVENT:Fire(spawnPos, player, side, zDir, doorFrameInfo, npcLifetime)
			end
			task.wait(0.5)

			doorAnimator.CloseDoor(openAng, 0.4)

			local closeSound = CreateDoorSound(DOOR_SOUNDS.CLOSE, door)
			closeSound:Play()

			DoorAntiExploitModule.OnDoorClosed(doorId)

			Debris:AddItem(openSound, 3)
			Debris:AddItem(closeSound, 2)
			Debris:AddItem(npcSound, 5)

			DoorAntiExploitModule.ResetDoorState(doorId)
			activeDoorOutcomes[doorId] = nil

			-- =====================================================================
			-- OUTCOME: TREASURE (GOOD - 20% of total when door opens)
			-- =====================================================================
		elseif outcome == "treasure" then
			local openSound = CreateDoorSound(DOOR_SOUNDS.OPEN, door)
			openSound:Play()

			local openAng = zDir * -80
			doorAnimator.OpenDoor(openAng, DOOR_SOUNDS.OPEN.duration)
			task.wait(0.3)

			local lightPart, revealLight = ChestRewardsModule.CreateDoorLight(
				Vector3.new(doorX, floorY + 4, voidCenterZ), 
				doorFolder
			)

			ChestRewardsModule.FlashLight(revealLight, 2, 0.4, 0.3)

			local chestPosition = Vector3.new(doorX, floorY, voidCenterZ)
			activeChest = ChestRewardsModule.CreateChest(chestPosition, doorFolder, zDir)

			local nearbyPlayers = GetPlayersNearPosition(Vector3.new(doorX, floorY, faceZ), 600)
			local chestId = doorId .. "_chest_" .. tick()

			DoorAntiExploitModule.RegisterChestClaimRights(chestId, nearbyPlayers, DOOR_CONFIG.CHEST_CLAIM_TIME)

			local playersClaimed = {}

			local function OnChestOpen(claimingPlayer)
				if playersClaimed[claimingPlayer.UserId] then return end
				if not activeChest then return end

				if not DoorAntiExploitModule.CanPlayerClaimChest(chestId, claimingPlayer) then
					return
				end

				playersClaimed[claimingPlayer.UserId] = true

				local playerReward = ChestRewardsModule.GenerateReward()

				if not activeChest.isOpen then
					activeChest.isOpen = true

					local chestOpenSound = CreateDoorSound(DOOR_SOUNDS.CHEST_OPEN, activeChest.base)
					chestOpenSound:Play()

					ChestRewardsModule.AnimateChestOpen(activeChest, playerReward)

					task.wait(0.5)

					local revealSound = CreateDoorSound(DOOR_SOUNDS.CHEST_REVEAL, activeChest.base)
					revealSound:Play()

					Debris:AddItem(chestOpenSound, 2)
					Debris:AddItem(revealSound, 2)

					task.spawn(function()
						task.wait(5)
						if activeChest and activeChest.folder then
							activeChest.rewardDisplayActive = false
							local rewardDisplay = activeChest.folder:FindFirstChild("RewardDisplay")
							if rewardDisplay then
								TweenService:Create(rewardDisplay, TweenInfo.new(0.5), {Transparency = 1}):Play()
								local billboard = rewardDisplay:FindFirstChild("RewardBillboard")
								if billboard then
									for _, child in pairs(billboard:GetDescendants()) do
										if child:IsA("TextLabel") or child:IsA("Frame") then
											pcall(function()
												TweenService:Create(child, TweenInfo.new(0.5), {
													BackgroundTransparency = 1,
													TextTransparency = 1
												}):Play()
											end)
										end
									end
								end
								task.wait(0.6)
								if rewardDisplay and rewardDisplay.Parent then
									rewardDisplay:Destroy()
								end
							end
						end
					end)
				end

				task.spawn(function()
					local waitStart = tick()
					local maxWait = 10

					while not _G.CurrencySystem and (tick() - waitStart) < maxWait do
						task.wait(0.1)
					end

					if not _G.CurrencySystem then
						warn("[MainGameServer] ERROR: _G.CurrencySystem is nil after " .. maxWait .. " seconds!")
						return
					end

					if not _G.CurrencySystem.AddChestItem then
						warn("[MainGameServer] ERROR: AddChestItem function is nil!")
						return
					end

					if not _G.CurrencySystem.AddMoney then
						warn("[MainGameServer] ERROR: AddMoney function is nil!")
						return
					end

					if playerReward.type == "item" then
						print("?? [Chest] Processing item reward for " .. claimingPlayer.Name .. ": " .. playerReward.name)

						local success = _G.CurrencySystem.AddChestItem(claimingPlayer, playerReward.itemId)

						if success then
							print("? [Chest] " .. claimingPlayer.Name .. " received item: " .. playerReward.name .. " (" .. playerReward.rarity .. ")")
						else
							print("?? [Chest] " .. claimingPlayer.Name .. " inventory full, gave money instead")
						end

						ChestRewardEvent:FireClient(claimingPlayer, playerReward)

					elseif playerReward.type == "money" then
						print("?? [Chest] Processing money reward for " .. claimingPlayer.Name .. ": $" .. playerReward.amount)

						local success = _G.CurrencySystem.AddMoney(claimingPlayer, playerReward.amount, "Treasure chest (" .. playerReward.rarity .. ")")

						if success then
							print("? [Chest] " .. claimingPlayer.Name .. " received $" .. playerReward.amount .. " USD (" .. playerReward.rarity .. ")")
						else
							warn("? [Chest] Failed to add money to " .. claimingPlayer.Name)
						end

						ChestRewardEvent:FireClient(claimingPlayer, playerReward)
					end

					ChestOpenedEvent:FireAllClients(doorX, playerReward, claimingPlayer.Name)
				end)
			end

			if activeChest and activeChest.prompt then
				activeChest.prompt.Triggered:Connect(OnChestOpen)
			end

			task.spawn(function()
				task.wait(DOOR_CONFIG.GOOD_DOOR_OPEN_DURATION)

				doorAnimator.CloseDoor(openAng, 0.6)

				local closeSound = CreateDoorSound(DOOR_SOUNDS.CLOSE, door)
				closeSound:Play()
				Debris:AddItem(closeSound, 2)

				DoorAntiExploitModule.OnDoorClosed(doorId)

				if activeChest then
					ChestRewardsModule.DestroyChest(activeChest)
					activeChest = nil
				end

				if lightPart and lightPart.Parent then
					lightPart:Destroy()
				end

				DoorAntiExploitModule.RevokeChestClaimRights(chestId)

				DoorAntiExploitModule.ResetDoorState(doorId)
				activeDoorOutcomes[doorId] = nil
			end)

			Debris:AddItem(openSound, 3)

			-- =====================================================================
			-- OUTCOME: NOTHING (LOCKED - 15% total)
			-- =====================================================================
		else
			task.wait(1)
			DoorLockedEvent:FireClient(player, "The door remains closed...")

			local amb = Instance.new("Sound")
			amb.SoundId = "rbxassetid://9114221580"
			amb.Volume = 0.1 * DOOR_MASTER_VOLUME
			amb.Parent = door
			amb:Play()
			Debris:AddItem(amb, 3)

			DoorAntiExploitModule.ResetDoorState(doorId)
			activeDoorOutcomes[doorId] = nil
		end

		hum.WalkSpeed = origSpeed
		hum.JumpPower = origJump
		task.wait(4)
		doorsBeingUsed[id] = nil
	end

	click.MouseClick:Connect(OnInteract)
	prompt.Triggered:Connect(OnInteract)

	return holeW, holeH
end

-- -------------------------------------------------------------------------------
-- BUILDING WITH ENHANCED HORROR
-- -------------------------------------------------------------------------------

local function CreateBuilding(buildingIndex, xCenter, faceZ, backZ, zDir, width, side, parent)
	local folder = Instance.new("Folder")
	folder.Name = "Building_" ..buildingIndex
	folder.Parent = parent

	local heightSeed = xCenter * 100 + (side == "left" and 1 or 2)
	local height = SeededRandom(heightSeed, CONFIG.BUILDING_MIN_HEIGHT, CONFIG.BUILDING_MAX_HEIGHT)

	local colorIndex = SeededRandom(xCenter * 50, 1, #buildingColors)
	local color = buildingColors[colorIndex]
	color = LerpColor(color, Color3.new(1, 1, 1), SeededRandomFloat(xCenter * 33) * 0.06)

	local depth = math.abs(backZ - faceZ)
	local zCenter = (faceZ + backZ) / 2
	local floorY = 0.5

	local doorX = nil
	local holeW, holeH

	local isInLobby = xCenter >= CONFIG.LOBBY_START_X and xCenter <= CONFIG.LOBBY_END_X

	local hasDoor = not isInLobby and TrueRandomFloat() < CONFIG.DOOR_CHANCE

	if hasDoor then
		doorX = xCenter
		holeW = CONFIG.HOLE_WIDTH_NORMAL
		holeH = CONFIG.HOLE_HEIGHT_NORMAL

		local leftW = (width - holeW) / 2
		if leftW > 0.5 then
			MakePart("Left", Vector3.new(leftW, height, depth),
				Vector3.new(xCenter - holeW/2 - leftW/2, height/2, zCenter),
				color, Enum.Material.Concrete, folder)
		end

		local rightW = (width - holeW) / 2
		if rightW > 0.5 then
			MakePart("Right", Vector3.new(rightW, height, depth),
				Vector3.new(xCenter + holeW/2 + rightW/2, height/2, zCenter),
				color, Enum.Material.Concrete, folder)
		end

		local topH = height - holeH - floorY + 0.5
		if topH > 0.5 then
			MakePart("Top", Vector3.new(holeW, topH, depth),
				Vector3.new(xCenter, floorY + holeH + topH/2 - 0.5, zCenter),
				color, Enum.Material.Concrete, folder)
		end

		CreateDoorWithVoid(xCenter, faceZ, backZ, zDir, side, folder, color)
	else
		holeW = CONFIG.HOLE_WIDTH_NORMAL
		holeH = CONFIG.HOLE_HEIGHT_NORMAL

		MakePart("Body", Vector3.new(width, height, depth),
			Vector3.new(xCenter, height/2, zCenter),
			color, Enum.Material.Concrete, folder)
	end

	-- Cornice
	MakePart("Cornice", Vector3.new(width + 0.4, 1, depth + 0.2),
		Vector3.new(xCenter, height + 0.5, zCenter),
		LerpColor(color, CONFIG.COLORS.BUILDING_TRIM, 0.25),
		Enum.Material.Concrete, folder)

	-- Base
	MakePart("Base", Vector3.new(width + 0.15, 1.2, depth + 0.15),
		Vector3.new(xCenter, 0.6, zCenter),
		LerpColor(color, Color3.new(0, 0, 0), 0.1),
		Enum.Material.Slate, folder)

	-- Windows with horror details
	CreateWindows(xCenter, height/2, faceZ, width, height, zDir, folder, doorX, holeW)

	-- Apply wall horror effects using HorrorDetailsModule
	local buildingSeed = xCenter * 77 + (side == "left" and 100 or 200)
	if HorrorDetailsModule then
		HorrorDetailsModule.ApplyBuildingWallHorror(
			xCenter, height/2, faceZ, width, height, zDir, folder, buildingSeed
		)
	end

	-- Roof structure
	if SeededRandomFloat(xCenter * 77) > 0.5 then
		local rh = SeededRandom(xCenter * 88, 2, 5)
		MakePart("Roof", Vector3.new(width * 0.35, rh, depth * 0.35),
			Vector3.new(xCenter, height + 1 + rh/2, zCenter),
			CONFIG.COLORS.BUILDING_TRIM, Enum.Material.Concrete, folder)
	end
end

-- -------------------------------------------------------------------------------
-- LAMP POSTS - HORROR STYLE WITH FLICKERING
-- -------------------------------------------------------------------------------

local function CreateLamp(x, side, parent)
	local folder = Instance.new("Folder")
	folder.Name = "Lamp"
	folder.Parent = parent

	local zOff = side == "left" and -(CONFIG.STREET_WIDTH/2 + 1.2) or (CONFIG.STREET_WIDTH/2 + 1.2)
	local zDir = side == "left" and 1 or -1

	-- Poste principal
	MakePart("Post", Vector3.new(0.3, CONFIG.LAMP_HEIGHT, 0.3),
		Vector3.new(x, CONFIG.LAMP_HEIGHT/2, zOff),
		CONFIG.COLORS.LAMP_POST, Enum.Material.Metal, folder)

	-- Base del poste
	MakePart("Base", Vector3.new(0.8, 0.4, 0.8),
		Vector3.new(x, 0.2, zOff),
		CONFIG.COLORS.LAMP_POST, Enum.Material.Metal, folder)

	-- Brazo de la l?mpara (m?s delgado)
	local armL = 3.0
	MakePart("Arm", Vector3.new(0.18, 0.18, armL),
		Vector3.new(x, CONFIG.LAMP_HEIGHT - 0.3, zOff + zDir * armL/2),
		CONFIG.COLORS.LAMP_POST, Enum.Material.Metal, folder)

	-- Carcasa de la l?mpara (m?s peque?a)
	local housing = MakePart("Housing", LAMP_HORROR_CONFIG.HOUSING_SIZE,
		Vector3.new(x, CONFIG.LAMP_HEIGHT - 0.4, zOff + zDir * armL),
		Color3.fromRGB(30, 30, 35), Enum.Material.Metal, folder, false, false, 0)

	-- Foco (m?s peque?o y amarillo)
	local bulb = MakePart("Bulb", LAMP_HORROR_CONFIG.BULB_SIZE,
		Vector3.new(x, CONFIG.LAMP_HEIGHT - 1.0, zOff + zDir * armL),
		LAMP_HORROR_CONFIG.LIGHT_COLOR, Enum.Material.Neon, folder, false, false, LAMP_HORROR_CONFIG.BULB_TRANSPARENCY)

	-- Luz principal (amarilla horror)
	local mainLight = Instance.new("PointLight")
	mainLight.Name = "MainLight"
	mainLight.Brightness = LAMP_HORROR_CONFIG.MAIN_LIGHT_BRIGHTNESS
	mainLight.Color = LAMP_HORROR_CONFIG.LIGHT_COLOR
	mainLight.Range = LAMP_HORROR_CONFIG.MAIN_LIGHT_RANGE
	mainLight.Shadows = true
	mainLight.Parent = bulb

	-- Luz del suelo (crea sombras dram?ticas)
	local groundLight = MakePart("GroundLight", Vector3.new(0.1, 0.1, 0.1),
		Vector3.new(x, 2.5, zOff + zDir * (armL - 0.8)),
		LAMP_HORROR_CONFIG.LIGHT_COLOR, Enum.Material.SmoothPlastic, folder, false, false, 1)

	local groundPointLight = Instance.new("PointLight")
	groundPointLight.Name = "GroundLight"
	groundPointLight.Brightness = LAMP_HORROR_CONFIG.GROUND_LIGHT_BRIGHTNESS
	groundPointLight.Color = LAMP_HORROR_CONFIG.LIGHT_COLOR
	groundPointLight.Range = LAMP_HORROR_CONFIG.GROUND_LIGHT_RANGE
	groundPointLight.Shadows = false
	groundPointLight.Parent = groundLight

	-- Tapa superior de la l?mpara
	MakePart("Top", Vector3.new(1.4, 0.2, 1.4),
		bulb.Position + Vector3.new(0, 0.7, 0),
		CONFIG.COLORS.LAMP_POST, Enum.Material.Metal, folder)

	-- -------------------------------------------------------------------
	-- SISTEMA DE PARPADEO HORROR
	-- -------------------------------------------------------------------

	-- Determinar si esta l?mpara parpadear?
	local willFlicker = TrueRandomFloat() < LAMP_HORROR_CONFIG.FLICKER_CHANCE

	if willFlicker then
		-- Guardar valores originales
		local originalBulbColor = bulb.Color
		local originalBulbTransparency = bulb.Transparency
		local originalMainBrightness = mainLight.Brightness
		local originalGroundBrightness = groundPointLight.Brightness

		-- Funci?n para hacer parpadear la luz
		local function FlickerLight()
			for i = 1, LAMP_HORROR_CONFIG.FLICKER_COUNT do
				-- Apagar
				bulb.Color = LAMP_HORROR_CONFIG.LIGHT_COLOR_DIM
				bulb.Transparency = 0.7
				mainLight.Brightness = LAMP_HORROR_CONFIG.FLICKER_OFF_BRIGHTNESS
				groundPointLight.Brightness = LAMP_HORROR_CONFIG.FLICKER_OFF_BRIGHTNESS * 0.5

				task.wait(LAMP_HORROR_CONFIG.FLICKER_SPEED)

				-- Encender
				bulb.Color = originalBulbColor
				bulb.Transparency = originalBulbTransparency
				mainLight.Brightness = originalMainBrightness
				groundPointLight.Brightness = originalGroundBrightness

				task.wait(LAMP_HORROR_CONFIG.FLICKER_SPEED * 0.8)
			end
		end

		-- Coroutine para parpadeo continuo
		coroutine.wrap(function()
			-- Esperar un tiempo aleatorio inicial para que no todas parpadeen a la vez
			task.wait(TrueRandom(1, 10))

			while bulb and bulb.Parent do
				-- Esperar intervalo aleatorio
				local waitTime = TrueRandom(
					LAMP_HORROR_CONFIG.FLICKER_INTERVAL_MIN,
					LAMP_HORROR_CONFIG.FLICKER_INTERVAL_MAX
				)
				task.wait(waitTime)

				-- Verificar que la l?mpara a?n existe
				if bulb and bulb.Parent then
					FlickerLight()
				else
					break
				end
			end
		end)()
	end
end
-- -------------------------------------------------------------------------------
-- ROOFTOP RUNNER SOUND SYSTEM
-- -------------------------------------------------------------------------------

local function StartRooftopRunnerSystem()
	coroutine.wrap(function()
		while true do
			local waitTime = TrueRandom(ROOFTOP_RUNNER_CONFIG.MIN_INTERVAL, ROOFTOP_RUNNER_CONFIG.MAX_INTERVAL)
			task.wait(waitTime)

			local players = Players:GetPlayers()
			if #players > 0 then
				local targetPlayer = players[TrueRandom(1, #players)]
				local char = targetPlayer.Character

				if char then
					local hrp = char:FindFirstChild("HumanoidRootPart")
					if hrp then
						local side = TrueRandom(1, 2) == 1 and "left" or "right"
						local sideZ = side == "left" and -(CONFIG.STREET_WIDTH/2 + CONFIG.BUILDING_DEPTH/2) or (CONFIG.STREET_WIDTH/2 + CONFIG.BUILDING_DEPTH/2)

						local soundX = hrp.Position.X + TrueRandom(-30, 30)
						local soundY = TrueRandom(CONFIG.BUILDING_MIN_HEIGHT, CONFIG.BUILDING_MAX_HEIGHT) + 5
						local soundPos = Vector3.new(soundX, soundY, sideZ)

						local soundPart = Instance.new("Part")
						soundPart.Name = "RooftopRunnerSound"
						soundPart.Size = Vector3.new(1, 1, 1)
						soundPart.Position = soundPos
						soundPart.Anchored = true
						soundPart.CanCollide = false
						soundPart.Transparency = 1
						soundPart.Parent = workspace

						local runSound = Instance.new("Sound")
						runSound.SoundId = ROOFTOP_RUNNER_CONFIG.SOUND_ID
						runSound.Volume = ROOFTOP_RUNNER_CONFIG.VOLUME
						runSound.RollOffMaxDistance = 100
						runSound.RollOffMinDistance = 10
						runSound.PlaybackSpeed = 0.9 + TrueRandomFloat() * 0.3
						runSound.Parent = soundPart

						runSound:Play()

						local direction = TrueRandom(1, 2) == 1 and 1 or -1
						local moveDistance = 60 + TrueRandom(0, 40)
						local moveDuration = ROOFTOP_RUNNER_CONFIG.DURATION
						local startX = soundPart.Position.X
						local startTime = tick()

						coroutine.wrap(function()
							while tick() - startTime < moveDuration do
								local progress = (tick() - startTime) / moveDuration
								local newX = startX + (direction * moveDistance * progress)
								local jumpOffset = math.sin(progress * math.pi * 4) * 2
								soundPart.Position = Vector3.new(newX, soundY + jumpOffset, sideZ)
								task.wait(0.05)
							end
							soundPart: Destroy()
						end)()

						for _, player in pairs(players) do
							local pChar = player.Character
							if pChar then
								local pHrp = pChar: FindFirstChild("HumanoidRootPart")
								if pHrp and (pHrp.Position - soundPos).Magnitude < 150 then
									RooftopRunnerEvent:FireClient(player, soundPos, side, direction)
								end
							end
						end

						print("?? Rooftop runner sound played on "..side.." side near player "..targetPlayer.Name)
					end
				end
			end
		end
	end)()
end

-- -------------------------------------------------------------------------------
-- LOBBY / SAFE ZONE
-- -------------------------------------------------------------------------------

local function CreateLobby()
	local shopFolder = Instance.new("Folder")
	shopFolder.Name = "ShopArea"
	shopFolder.Parent = lobbyFolder

	local totalWidth = CONFIG.STREET_WIDTH + CONFIG.SIDEWALK_WIDTH * 2 + CONFIG.BUILDING_DEPTH * 2 + 8
	local lobbyFloorY = 0.02
	local streetEdge = CONFIG.STREET_WIDTH/2 + CONFIG.SIDEWALK_WIDTH

	local lobbyFloor = MakePart("LobbyFloor", 
		Vector3.new(CONFIG.LOBBY_LENGTH, 1, totalWidth),
		Vector3.new(0, lobbyFloorY, 0),
		CONFIG.COLORS.LOBBY_FLOOR, Enum.Material.Concrete, lobbyFolder)

	MakePart("LeftCover",
		Vector3.new(CONFIG.LOBBY_LENGTH, 1, CONFIG.BUILDING_DEPTH + 4),
		Vector3.new(0, lobbyFloorY, -(streetEdge + CONFIG.BUILDING_DEPTH/2)),
		CONFIG.COLORS.LOBBY_FLOOR, Enum.Material.Concrete, lobbyFolder)

	MakePart("RightCover",
		Vector3.new(CONFIG.LOBBY_LENGTH, 1, CONFIG.BUILDING_DEPTH + 4),
		Vector3.new(0, lobbyFloorY, streetEdge + CONFIG.BUILDING_DEPTH/2),
		CONFIG.COLORS.LOBBY_FLOOR, Enum.Material.Concrete, lobbyFolder)

	MakePart("LobbyEdgeTrimLeft",
		Vector3.new(0.5, 0.2, totalWidth + 16),
		Vector3.new(CONFIG.LOBBY_START_X, 0.6, 0),
		Color3.fromRGB(45, 50, 55), Enum.Material.Metal, lobbyFolder)

	MakePart("LobbyEdgeTrimRight",
		Vector3.new(0.5, 0.2, totalWidth + 16),
		Vector3.new(CONFIG.LOBBY_END_X, 0.6, 0),
		Color3.fromRGB(45, 50, 55), Enum.Material.Metal, lobbyFolder)

	-- TRANSITIONS LEFT
	local transitionLength = 28
	local transitionY = -0.02
	local transitionGap = 0.5
	local leftTransitionX = CONFIG.LOBBY_START_X - transitionLength/2 - transitionGap

	MakePart("TransitionStreetLeft",
		Vector3.new(transitionLength, 1, CONFIG.STREET_WIDTH),
		Vector3.new(leftTransitionX, transitionY, 0),
		CONFIG.COLORS.STREET, Enum.Material.Asphalt, lobbyFolder)

	MakePart("TransitionSidewalkLeftL",
		Vector3.new(transitionLength, 1, CONFIG.SIDEWALK_WIDTH),
		Vector3.new(leftTransitionX, 0.23, -(CONFIG.STREET_WIDTH/2 + CONFIG.SIDEWALK_WIDTH/2)),
		CONFIG.COLORS.SIDEWALK, Enum.Material.Concrete, lobbyFolder)

	MakePart("TransitionSidewalkLeftR",
		Vector3.new(transitionLength, 1, CONFIG.SIDEWALK_WIDTH),
		Vector3.new(leftTransitionX, 0.23, (CONFIG.STREET_WIDTH/2 + CONFIG.SIDEWALK_WIDTH/2)),
		CONFIG.COLORS.SIDEWALK, Enum.Material.Concrete, lobbyFolder)

	MakePart("TransitionCurbLeftL",
		Vector3.new(transitionLength, 0.5, 0.35),
		Vector3.new(leftTransitionX, 0.73, -(CONFIG.STREET_WIDTH/2 + 0.18)),
		LerpColor(CONFIG.COLORS.SIDEWALK, Color3.new(0.12, 0.12, 0.12), 0.2),
		Enum.Material.Concrete, lobbyFolder)

	MakePart("TransitionCurbLeftR",
		Vector3.new(transitionLength, 0.5, 0.35),
		Vector3.new(leftTransitionX, 0.73, (CONFIG.STREET_WIDTH/2 + 0.18)),
		LerpColor(CONFIG.COLORS.SIDEWALK, Color3.new(0.12, 0.12, 0.12), 0.2),
		Enum.Material.Concrete, lobbyFolder)

	MakePart("TransitionBuildingFloorLeftL",
		Vector3.new(transitionLength, 1, CONFIG.BUILDING_DEPTH + 8),
		Vector3.new(leftTransitionX, transitionY, -(streetEdge + CONFIG.BUILDING_DEPTH/2 + 1.5)),
		CONFIG.COLORS.SIDEWALK, Enum.Material.Concrete, lobbyFolder)

	MakePart("TransitionBuildingFloorLeftR",
		Vector3.new(transitionLength, 1, CONFIG.BUILDING_DEPTH + 8),
		Vector3.new(leftTransitionX, transitionY, (streetEdge + CONFIG.BUILDING_DEPTH/2 + 1.5)),
		CONFIG.COLORS.SIDEWALK, Enum.Material.Concrete, lobbyFolder)

	MakePart("CornerFillLeftFront",
		Vector3.new(8, 1, CONFIG.STREET_WIDTH + CONFIG.SIDEWALK_WIDTH * 2 + 16),
		Vector3.new(CONFIG.LOBBY_START_X - transitionLength - 4 - transitionGap, transitionY, 0),
		CONFIG.COLORS.STREET, Enum.Material.Asphalt, lobbyFolder)

	-- TRANSITIONS RIGHT
	local rightTransitionX = CONFIG.LOBBY_END_X + transitionLength/2 + transitionGap

	MakePart("TransitionStreetRight",
		Vector3.new(transitionLength, 1, CONFIG.STREET_WIDTH),
		Vector3.new(rightTransitionX, transitionY, 0),
		CONFIG.COLORS.STREET, Enum.Material.Asphalt, lobbyFolder)

	MakePart("TransitionSidewalkRightL",
		Vector3.new(transitionLength, 1, CONFIG.SIDEWALK_WIDTH),
		Vector3.new(rightTransitionX, 0.23, -(CONFIG.STREET_WIDTH/2 + CONFIG.SIDEWALK_WIDTH/2)),
		CONFIG.COLORS.SIDEWALK, Enum.Material.Concrete, lobbyFolder)

	MakePart("TransitionSidewalkRightR",
		Vector3.new(transitionLength, 1, CONFIG.SIDEWALK_WIDTH),
		Vector3.new(rightTransitionX, 0.23, (CONFIG.STREET_WIDTH/2 + CONFIG.SIDEWALK_WIDTH/2)),
		CONFIG.COLORS.SIDEWALK, Enum.Material.Concrete, lobbyFolder)

	MakePart("TransitionCurbRightL",
		Vector3.new(transitionLength, 0.5, 0.35),
		Vector3.new(rightTransitionX, 0.73, -(CONFIG.STREET_WIDTH/2 + 0.18)),
		LerpColor(CONFIG.COLORS.SIDEWALK, Color3.new(0.12, 0.12, 0.12), 0.2),
		Enum.Material.Concrete, lobbyFolder)

	MakePart("TransitionCurbRightR",
		Vector3.new(transitionLength, 0.5, 0.35),
		Vector3.new(rightTransitionX, 0.73, (CONFIG.STREET_WIDTH/2 + 0.18)),
		LerpColor(CONFIG.COLORS.SIDEWALK, Color3.new(0.12, 0.12, 0.12), 0.2),
		Enum.Material.Concrete, lobbyFolder)

	MakePart("TransitionBuildingFloorRightL",
		Vector3.new(transitionLength, 1, CONFIG.BUILDING_DEPTH + 8),
		Vector3.new(rightTransitionX, transitionY, -(streetEdge + CONFIG.BUILDING_DEPTH/2 + 1.5)),
		CONFIG.COLORS.SIDEWALK, Enum.Material.Concrete, lobbyFolder)

	MakePart("TransitionBuildingFloorRightR",
		Vector3.new(transitionLength, 1, CONFIG.BUILDING_DEPTH + 8),
		Vector3.new(rightTransitionX, transitionY, (streetEdge + CONFIG.BUILDING_DEPTH/2 + 1.5)),
		CONFIG.COLORS.SIDEWALK, Enum.Material.Concrete, lobbyFolder)

	MakePart("CornerFillRightFront",
		Vector3.new(8, 1, CONFIG.STREET_WIDTH + CONFIG.SIDEWALK_WIDTH * 2 + 16),
		Vector3.new(CONFIG.LOBBY_END_X + transitionLength + 4 + transitionGap, transitionY, 0),
		CONFIG.COLORS.STREET, Enum.Material.Asphalt, lobbyFolder)

	-- SAFE ZONE INDICATORS
	MakePart("SafeIndicatorL",
		Vector3.new(0.9, 0.15, totalWidth),
		Vector3.new(CONFIG.LOBBY_START_X, 0.6, 0),
		CONFIG.COLORS.SAFE_ZONE, Enum.Material.Neon, lobbyFolder, false, false, 0.4)

	MakePart("SafeIndicatorR",
		Vector3.new(0.9, 0.15, totalWidth),
		Vector3.new(CONFIG.LOBBY_END_X, 0.6, 0),
		CONFIG.COLORS.SAFE_ZONE, Enum.Material.Neon, lobbyFolder, false, false, 0.4)

	-- STREET ENTRANCE SIGNS
	local signHeight = 12

	local function CreateStreetSign(xPosition, arrowDir)
		local signFolder = Instance.new("Folder")
		signFolder.Name = "StreetSign_"..(xPosition < 0 and "Left" or "Right")
		signFolder.Parent = lobbyFolder

		MakePart("SignPost", Vector3.new(0.3, signHeight + 2, 0.3),
			Vector3.new(xPosition, (signHeight + 2)/2, 0),
			Color3.fromRGB(45, 45, 50), Enum.Material.Metal, signFolder)

		MakePart("SignArm", Vector3.new(3, 0.2, 0.2),
			Vector3.new(xPosition, signHeight, 0),
			Color3.fromRGB(45, 45, 50), Enum.Material.Metal, signFolder)

		local streetSign = MakePart("StreetSign", Vector3.new(12, 2.2, 0.35),
			Vector3.new(xPosition, signHeight - 2, 0),
			Color3.fromRGB(22, 22, 32), Enum.Material.SmoothPlastic, signFolder)

		MakePart("SignFrameTop", Vector3.new(12.4, 0.18, 0.45),
			Vector3.new(xPosition, signHeight - 0.8, 0),
			Color3.fromRGB(170, 140, 45), Enum.Material.Metal, signFolder)

		MakePart("SignFrameBottom", Vector3.new(12.4, 0.18, 0.45),
			Vector3.new(xPosition, signHeight - 3.2, 0),
			Color3.fromRGB(170, 140, 45), Enum.Material.Metal, signFolder)

		MakePart("SignFrameLeft", Vector3.new(0.18, 2.55, 0.45),
			Vector3.new(xPosition - 6.15, signHeight - 2, 0),
			Color3.fromRGB(170, 140, 45), Enum.Material.Metal, signFolder)

		MakePart("SignFrameRight", Vector3.new(0.18, 2.55, 0.45),
			Vector3.new(xPosition + 6.15, signHeight - 2, 0),
			Color3.fromRGB(170, 140, 45), Enum.Material.Metal, signFolder)

		for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
			local signGui = Instance.new("SurfaceGui")
			signGui.Face = face
			signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			signGui.PixelsPerStud = 40
			signGui.Parent = streetSign

			local signText = Instance.new("TextLabel")
			signText.Size = UDim2.new(1, 0, 1, 0)
			signText.BackgroundTransparency = 1
			signText.Text = "THE STREET"
			signText.TextColor3 = Color3.fromRGB(255, 200, 100)
			signText.TextScaled = true
			signText.Font = Enum.Font.GothamBlack
			signText.Parent = signGui
		end

		local signLightLeft = MakePart("SignLightLeft", Vector3.new(0.28, 0.28, 0.28),
			Vector3.new(xPosition - 4.8, signHeight, 0.22),
			Color3.fromRGB(255, 220, 150), Enum.Material.Neon, signFolder, false, false, 0.5)

		local sll = Instance.new("PointLight")
		sll.Brightness = 0.35
		sll.Color = Color3.fromRGB(255, 220, 150)
		sll.Range = 5
		sll.Shadows = false
		sll.Parent = signLightLeft

		local signLightRight = MakePart("SignLightRight", Vector3.new(0.28, 0.28, 0.28),
			Vector3.new(xPosition + 4.8, signHeight, 0.22),
			Color3.fromRGB(255, 220, 150), Enum.Material.Neon, signFolder, false, false, 0.5)

		local slr = Instance.new("PointLight")
		slr.Brightness = 0.35
		slr.Color = Color3.fromRGB(255, 220, 150)
		slr.Range = 5
		slr.Shadows = false
		slr.Parent = signLightRight

		local arrowSign = MakePart("ArrowSign", Vector3.new(2.2, 1.6, 0.28),
			Vector3.new(xPosition, signHeight - 5, 0),
			Color3.fromRGB(18, 18, 22), Enum.Material.SmoothPlastic, signFolder)

		MakePart("ArrowFrame", Vector3.new(2.4, 1.8, 0.22),
			Vector3.new(xPosition, signHeight - 5, -0.04),
			Color3.fromRGB(90, 35, 35), Enum.Material.Metal, signFolder)

		for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
			local arrowGui = Instance.new("SurfaceGui")
			arrowGui.Face = face
			arrowGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			arrowGui.PixelsPerStud = 50
			arrowGui.Parent = arrowSign

			local arrowText = Instance.new("TextLabel")
			arrowText.Size = UDim2.new(1, 0, 1, 0)
			arrowText.BackgroundTransparency = 1
			arrowText.Text = arrowDir
			arrowText.TextColor3 = Color3.fromRGB(255, 75, 75)
			arrowText.TextScaled = true
			arrowText.Font = Enum.Font.GothamBlack
			arrowText.Parent = arrowGui
		end

		local arrowGlow = MakePart("ArrowGlow", Vector3.new(1.8, 0.1, 0.1),
			Vector3.new(xPosition, signHeight - 6, 0.18),
			Color3.fromRGB(255, 75, 75), Enum.Material.Neon, signFolder, false, false, 0.3)

		local arrowLight = Instance.new("PointLight")
		arrowLight.Brightness = 0.55
		arrowLight.Color = Color3.fromRGB(255, 75, 75)
		arrowLight.Range = 8
		arrowLight.Parent = arrowGlow

		return signFolder
	end

	CreateStreetSign(CONFIG.LOBBY_START_X + 7, "?")
	CreateStreetSign(CONFIG.LOBBY_END_X - 7, "?")

	-- SHOP AREA
	local wallZ = -(CONFIG.STREET_WIDTH/2 + CONFIG.SIDEWALK_WIDTH - 1.5)
	local shopX = 0

	local shopBackWall = MakePart("ShopBackWall", Vector3.new(14, 11, 0.45),
		Vector3.new(shopX, 5.5, wallZ),
		Color3.fromRGB(32, 28, 38), Enum.Material.SmoothPlastic, shopFolder)
	shopBackWall.Reflectance = 0

	local shopLeftWall = MakePart("ShopLeftWall", Vector3.new(0.45, 11, 9),
		Vector3.new(shopX - 7, 5.5, wallZ + 4.5),
		Color3.fromRGB(38, 33, 43), Enum.Material.SmoothPlastic, shopFolder)
	shopLeftWall.Reflectance = 0

	local shopRightWall = MakePart("ShopRightWall", Vector3.new(0.45, 11, 9),
		Vector3.new(shopX + 7, 5.5, wallZ + 4.5),
		Color3.fromRGB(38, 33, 43), Enum.Material.SmoothPlastic, shopFolder)
	shopRightWall.Reflectance = 0

	local shopFloor = MakePart("ShopFloor", Vector3.new(14, 0.28, 9),
		Vector3.new(shopX, 0.64, wallZ + 4.5),
		Color3.fromRGB(42, 38, 48), Enum.Material.SmoothPlastic, shopFolder)
	shopFloor.Reflectance = 0

	local floorBorderFront = MakePart("FloorBorderFront", Vector3.new(14, 0.1, 0.28),
		Vector3.new(shopX, 0.83, wallZ + 9),
		Color3.fromRGB(110, 90, 65), Enum.Material.SmoothPlastic, shopFolder)
	floorBorderFront.Reflectance = 0

	local floorBorderLeft = MakePart("FloorBorderLeft", Vector3.new(0.28, 0.1, 9),
		Vector3.new(shopX - 6.85, 0.83, wallZ + 4.5),
		Color3.fromRGB(110, 90, 65), Enum.Material.SmoothPlastic, shopFolder)
	floorBorderLeft.Reflectance = 0

	local floorBorderRight = MakePart("FloorBorderRight", Vector3.new(0.28, 0.1, 9),
		Vector3.new(shopX + 6.85, 0.83, wallZ + 4.5),
		Color3.fromRGB(110, 90, 65), Enum.Material.SmoothPlastic, shopFolder)
	floorBorderRight.Reflectance = 0

	local shopCounterBase = MakePart("ShopCounterBase", Vector3.new(11, 3, 1.8),
		Vector3.new(shopX, 2, wallZ + 6.5),
		Color3.fromRGB(65, 45, 32), Enum.Material.SmoothPlastic, shopFolder)
	shopCounterBase.Reflectance = 0

	local counterTop = MakePart("CounterTop", Vector3.new(11.4, 0.22, 2.2),
		Vector3.new(shopX, 3.6, wallZ + 6.5),
		Color3.fromRGB(48, 33, 23), Enum.Material.SmoothPlastic, shopFolder)
	counterTop.Reflectance = 0

	local counterFrontPanel = MakePart("CounterFrontPanel", Vector3.new(10, 2.3, 0.1),
		Vector3.new(shopX, 1.65, wallZ + 7.45),
		Color3.fromRGB(52, 38, 28), Enum.Material.SmoothPlastic, shopFolder)
	counterFrontPanel.Reflectance = 0

	local counterTrimTop = MakePart("CounterTrimTop", Vector3.new(11.4, 0.12, 0.18),
		Vector3.new(shopX, 2.9, wallZ + 7.4),
		Color3.fromRGB(95, 75, 48), Enum.Material.SmoothPlastic, shopFolder)
	counterTrimTop.Reflectance = 0

	local counterTrimBottom = MakePart("CounterTrimBottom", Vector3.new(11.4, 0.08, 0.12),
		Vector3.new(shopX, 0.52, wallZ + 7.4),
		Color3.fromRGB(95, 75, 48), Enum.Material.SmoothPlastic, shopFolder)
	counterTrimBottom.Reflectance = 0

	local shopRoof = MakePart("ShopRoof", Vector3.new(16, 0.55, 11),
		Vector3.new(shopX, 11, wallZ + 4.5),
		Color3.fromRGB(28, 23, 33), Enum.Material.SmoothPlastic, shopFolder)
	shopRoof.Reflectance = 0

	for beamX = -5.5, 5.5, 5.5 do
		local beam = MakePart("RoofBeam", Vector3.new(0.35, 0.75, 11),
			Vector3.new(shopX + beamX, 10.5, wallZ + 4.5),
			Color3.fromRGB(48, 33, 23), Enum.Material.SmoothPlastic, shopFolder)
		beam.Reflectance = 0
	end

	for _, xOff in pairs({-7, 7}) do
		local pillar = MakePart("Pillar", Vector3.new(0.7, 11, 0.7),
			Vector3.new(shopX + xOff, 5.5, wallZ + 9),
			Color3.fromRGB(42, 38, 48), Enum.Material.SmoothPlastic, shopFolder)
		pillar.Reflectance = 0

		local pillarBase = MakePart("PillarBase", Vector3.new(1.1, 0.45, 1.1),
			Vector3.new(shopX + xOff, 0.73, wallZ + 9),
			Color3.fromRGB(55, 48, 53), Enum.Material.SmoothPlastic, shopFolder)
		pillarBase.Reflectance = 0

		local pillarCapital = MakePart("PillarCapital", Vector3.new(1.0, 0.35, 1.0),
			Vector3.new(shopX + xOff, 10.7, wallZ + 9),
			Color3.fromRGB(55, 48, 53), Enum.Material.SmoothPlastic, shopFolder)
		pillarCapital.Reflectance = 0
	end

	local shopSignBack = MakePart("ShopSignBack", Vector3.new(10, 2.8, 0.35),
		Vector3.new(shopX, 9, wallZ + 9.5),
		Color3.fromRGB(18, 13, 23), Enum.Material.SmoothPlastic, shopFolder)

	MakePart("ShopSignFrame", Vector3.new(10.35, 3.15, 0.28),
		Vector3.new(shopX, 9, wallZ + 9.3),
		Color3.fromRGB(95, 75, 48), Enum.Material.Metal, shopFolder)

	for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
		local signGui = Instance.new("SurfaceGui")
		signGui.Face = face
		signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		signGui.PixelsPerStud = 50
		signGui.Parent = shopSignBack

		local signText = Instance.new("TextLabel")
		signText.Size = UDim2.new(1, 0, 1, 0)
		signText.BackgroundTransparency = 1
		signText.Text = "SHOP"
		signText.TextColor3 = Color3.fromRGB(255, 200, 100)
		signText.TextScaled = true
		signText.Font = Enum.Font.GothamBlack
		signText.Parent = signGui
	end

	local signLightLeft = MakePart("SignLightLeft", Vector3.new(0.28, 0.28, 0.28),
		Vector3.new(shopX - 4.8, 9, wallZ + 9.7),
		Color3.fromRGB(255, 220, 150), Enum.Material.Neon, shopFolder, false, false, 0.3)

	local sll = Instance.new("PointLight")
	sll.Brightness = 0.35
	sll.Color = Color3.fromRGB(255, 220, 150)
	sll.Range = 5
	sll.Shadows = false
	sll.Parent = signLightLeft

	local signLightRight = MakePart("SignLightRight", Vector3.new(0.28, 0.28, 0.28),
		Vector3.new(shopX + 4.8, 9, wallZ + 9.7),
		Color3.fromRGB(255, 220, 150), Enum.Material.Neon, shopFolder, false, false, 0.3)

	local slr = Instance.new("PointLight")
	slr.Brightness = 0.35
	slr.Color = Color3.fromRGB(255, 220, 150)
	slr.Range = 5
	slr.Shadows = false
	slr.Parent = signLightRight

	-- LANTERNS
	for lx = -3.5, 3.5, 3.5 do
		MakePart("LanternChain", Vector3.new(0.04, 1.4, 0.04),
			Vector3.new(shopX + lx, 10.2, wallZ + 4.5),
			Color3.fromRGB(55, 48, 38), Enum.Material.Metal, shopFolder)

		MakePart("LanternFrame", Vector3.new(0.7, 1.1, 0.7),
			Vector3.new(shopX + lx, 9.3, wallZ + 4.5),
			Color3.fromRGB(48, 38, 33), Enum.Material.Metal, shopFolder)

		local lanternGlass = MakePart("LanternGlass", Vector3.new(0.45, 0.7, 0.45),
			Vector3.new(shopX + lx, 9.3, wallZ + 4.5),
			Color3.fromRGB(255, 200, 120), Enum.Material.Glass, shopFolder, false, false, 0.4)

		local lanternLight = Instance.new("PointLight")
		lanternLight.Brightness = 0.7
		lanternLight.Color = Color3.fromRGB(255, 200, 120)
		lanternLight.Range = 14
		lanternLight.Shadows = false
		lanternLight.Parent = lanternGlass
	end

	-- SHELVES WITH GLOWING POTION BOTTLES
	local potionColors = {
		{color = Color3.fromRGB(255, 50, 80), name = "Red"},
		{color = Color3.fromRGB(50, 255, 120), name = "Green"},
		{color = Color3.fromRGB(80, 150, 255), name = "Blue"},
		{color = Color3.fromRGB(255, 180, 50), name = "Orange"},
		{color = Color3.fromRGB(200, 80, 255), name = "Purple"},
		{color = Color3.fromRGB(255, 255, 100), name = "Yellow"},
		{color = Color3.fromRGB(100, 255, 255), name = "Cyan"},
		{color = Color3.fromRGB(255, 100, 200), name = "Pink"},
	}

	local bottleIndex = 1
	for shelfY = 3.8, 7.4, 1.8 do
		MakePart("Shelf", Vector3.new(9, 0.18, 0.9),
			Vector3.new(shopX, shelfY, wallZ + 0.65),
			Color3.fromRGB(55, 42, 33), Enum.Material.Wood, shopFolder)

		for bx = -3.5, 3.5, 3.5 do
			MakePart("ShelfBracket", Vector3.new(0.12, 0.45, 0.7),
				Vector3.new(shopX + bx, shelfY - 0.28, wallZ + 0.48),
				Color3.fromRGB(75, 60, 48), Enum.Material.Metal, shopFolder)
		end

		for itemX = -3.2, 3.2, 1.3 do
			local bottleHeight = 0.5 + math.random() * 0.3
			local potionData = potionColors[((bottleIndex - 1) % #potionColors) + 1]

			local bottle = Instance.new("Part")
			bottle.Name = "GlowingPotion"..bottleIndex
			bottle.Size = Vector3.new(0.35, bottleHeight, 0.35)
			bottle.Position = Vector3.new(
				shopX + itemX + (math.random() - 0.5) * 0.3, 
				shelfY + bottleHeight/2 + 0.12, 
				wallZ + 0.65
			)
			bottle.Color = potionData.color
			bottle.Material = Enum.Material.Neon
			bottle.Transparency = 0.2
			bottle.Anchored = true
			bottle.CanCollide = false
			bottle.CastShadow = false
			bottle.Parent = shopFolder

			local potionLight = Instance.new("PointLight")
			potionLight.Brightness = 0.6
			potionLight.Color = potionData.color
			potionLight.Range = 6
			potionLight.Shadows = false
			potionLight.Parent = bottle

			local cap = Instance.new("Part")
			cap.Name = "PotionCap"..bottleIndex
			cap.Size = Vector3.new(0.2, 0.12, 0.2)
			cap.Position = bottle.Position + Vector3.new(0, bottleHeight/2 + 0.06, 0)
			cap.Color = Color3.fromRGB(139, 90, 43)
			cap.Material = Enum.Material.Wood
			cap.Anchored = true
			cap.CanCollide = false
			cap.Parent = shopFolder

			bottleIndex = bottleIndex + 1
		end
	end

	-- SHOP TRIGGER
	local shopTrigger = MakePart("ShopTrigger", Vector3.new(12, 4.5, 11),
		Vector3.new(shopX, 2.8, wallZ + 5.5),
		Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, shopFolder, false, false, 1)

	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.Name = "ShopPrompt"
	shopPrompt.ActionText = "Open Shop"
	shopPrompt.ObjectText = "Shop"
	shopPrompt.KeyboardKeyCode = Enum.KeyCode.E
	shopPrompt.HoldDuration = 0
	shopPrompt.MaxActivationDistance = 9
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.Parent = shopTrigger

	shopPrompt.Triggered:Connect(function(player)
		OpenShopEvent:FireClient(player)
	end)

	-- WIZARD NPC (Store globally for cinematic)
	local wizardPosition = Vector3.new(shopX, 0.78, wallZ + 3.8)
	WizardNPCData = WizardNPCModule.Create(wizardPosition, shopFolder)
	print("[Lobby] ?? Wizard NPC created with dialogue system!")


	-- MAGICAL SPELL BOOK ON COUNTER
	-- Counter top is at Y=3.6, shopX=0, counterZ = wallZ + 6.5
	local bookX = shopX                  -- Centered on the counter (same X as wizard)
	local bookY = 3.72                   -- Slightly above counter top (3.6 + offset)
	local bookZ = wallZ + 6.2            -- On the counter, between wizard and front edge
	local bookPosition = Vector3.new(bookX, bookY, bookZ)
	-- Rotate so the open pages face toward the player (front of counter = +Z direction)
	-- The book's local X axis is left-right across the pages, Z axis is along the spine
	-- We rotate 90 degrees so the spine runs left-right and pages face the player
	local bookCFrame = CFrame.new(bookPosition) * CFrame.Angles(0, math.rad(0), 0)
	local MagicalBookData = MagicalBookModule.Create(bookPosition, shopFolder, bookCFrame)
	print("[Lobby] ? Magical spell book placed on shop counter (centered)!")

	-- =========================================================================
	-- HORROR CLOCK ON LEFT WALL (reconstruido desde 0) - SEGUNDO TRABADO EN XII
	-- =========================================================================
	local clockFolder = Instance.new("Folder")
	clockFolder.Name = "HorrorClock"
	clockFolder.Parent = shopFolder

	local WALL_INNER_X = shopX - 6.78
	local CLOCK_Y = 6.8
	local CLOCK_Z = wallZ + 4.0
	local CLOCK_RADIUS = 2.0

	local function PlaceCylinderFrontOnWall(part, frontSurfaceX, zRotation)
		zRotation = zRotation or math.rad(-90)
		local thickness = part.Size.Y
		local centerX = frontSurfaceX - (thickness / 2)
		part.CFrame = CFrame.new(centerX, CLOCK_Y, CLOCK_Z) * CFrame.Angles(0, 0, zRotation)
	end

	local function PlacePlateRightFaceOnWall(part, frontSurfaceX)
		local thickness = part.Size.X
		local centerX = frontSurfaceX - (thickness / 2)
		part.CFrame = CFrame.new(centerX, CLOCK_Y, CLOCK_Z)
	end

	-- Rim / face / glass / hub (igual que antes)
	local clockRim = Instance.new("Part")
	clockRim.Name = "ClockRim"
	clockRim.Shape = Enum.PartType.Cylinder
	clockRim.Size = Vector3.new(CLOCK_RADIUS * 2.2, 0.35, CLOCK_RADIUS * 2.2)
	clockRim.Color = Color3.fromRGB(120, 90, 45)
	clockRim.Material = Enum.Material.Metal
	clockRim.Anchored = true
	clockRim.CanCollide = false
	clockRim.CastShadow = false
	clockRim.Reflectance = 0.05
	clockRim.Parent = clockFolder
	PlaceCylinderFrontOnWall(clockRim, WALL_INNER_X)

	local clockInnerRim = Instance.new("Part")
	clockInnerRim.Name = "ClockInnerRim"
	clockInnerRim.Shape = Enum.PartType.Cylinder
	clockInnerRim.Size = Vector3.new(CLOCK_RADIUS * 2.08, 0.32, CLOCK_RADIUS * 2.08)
	clockInnerRim.Color = Color3.fromRGB(75, 55, 30)
	clockInnerRim.Material = Enum.Material.Metal
	clockInnerRim.Anchored = true
	clockInnerRim.CanCollide = false
	clockInnerRim.CastShadow = false
	clockInnerRim.Parent = clockFolder
	PlaceCylinderFrontOnWall(clockInnerRim, WALL_INNER_X)

	local clockBack = Instance.new("Part")
	clockBack.Name = "ClockBack"
	clockBack.Shape = Enum.PartType.Cylinder
	clockBack.Size = Vector3.new(CLOCK_RADIUS * 2.0, 0.20, CLOCK_RADIUS * 2.0)
	clockBack.Color = Color3.fromRGB(12, 10, 18)
	clockBack.Material = Enum.Material.SmoothPlastic
	clockBack.Anchored = true
	clockBack.CanCollide = false
	clockBack.CastShadow = false
	clockBack.Parent = clockFolder
	PlaceCylinderFrontOnWall(clockBack, WALL_INNER_X)

	local clockFace = Instance.new("Part")
	clockFace.Name = "ClockFace"
	clockFace.Shape = Enum.PartType.Cylinder
	clockFace.Size = Vector3.new(CLOCK_RADIUS * 1.85, 0.08, CLOCK_RADIUS * 1.85)
	clockFace.Color = Color3.fromRGB(32, 28, 40)
	clockFace.Material = Enum.Material.SmoothPlastic
	clockFace.Anchored = true
	clockFace.CanCollide = false
	clockFace.CastShadow = false
	clockFace.Parent = clockFolder
	PlaceCylinderFrontOnWall(clockFace, WALL_INNER_X)

	local innerRing = Instance.new("Part")
	innerRing.Name = "InnerRing"
	innerRing.Shape = Enum.PartType.Cylinder
	innerRing.Size = Vector3.new(CLOCK_RADIUS * 1.92, 0.10, CLOCK_RADIUS * 1.92)
	innerRing.Color = Color3.fromRGB(95, 72, 38)
	innerRing.Material = Enum.Material.Metal
	innerRing.Anchored = true
	innerRing.CanCollide = false
	innerRing.CastShadow = false
	innerRing.Parent = clockFolder
	PlaceCylinderFrontOnWall(innerRing, WALL_INNER_X)

	local clockGlass = Instance.new("Part")
	clockGlass.Name = "ClockGlass"
	clockGlass.Shape = Enum.PartType.Cylinder
	clockGlass.Size = Vector3.new(CLOCK_RADIUS * 1.95, 0.06, CLOCK_RADIUS * 1.95)
	clockGlass.Color = Color3.fromRGB(180, 200, 220)
	clockGlass.Material = Enum.Material.Glass
	clockGlass.Transparency = 0.85
	clockGlass.Anchored = true
	clockGlass.CanCollide = false
	clockGlass.CastShadow = false
	clockGlass.Parent = clockFolder
	PlaceCylinderFrontOnWall(clockGlass, WALL_INNER_X)

	local clockHub = Instance.new("Part")
	clockHub.Name = "ClockHub"
	clockHub.Shape = Enum.PartType.Cylinder
	clockHub.Size = Vector3.new(0.35, 0.12, 0.35)
	clockHub.Color = Color3.fromRGB(130, 100, 55)
	clockHub.Material = Enum.Material.Metal
	clockHub.Anchored = true
	clockHub.CanCollide = false
	clockHub.CastShadow = false
	clockHub.Reflectance = 0.1
	clockHub.Parent = clockFolder
	PlaceCylinderFrontOnWall(clockHub, WALL_INNER_X)

	local clockLight = Instance.new("PointLight")
	clockLight.Brightness = 0.28
	clockLight.Color = Color3.fromRGB(210, 180, 110)
	clockLight.Range = 5.5
	clockLight.Parent = clockHub

	-- Hour markers (convention CLOCKWISE visible desde +X)
	local MARKER_DIST = CLOCK_RADIUS * 0.78
	local MARKER_INSET = 0.015
	local MARKER_X = WALL_INNER_X + MARKER_INSET

	for i = 1, 12 do
		local angle = math.rad((i - 1) * 30)
		local markerY = CLOCK_Y + math.cos(angle) * MARKER_DIST
		local markerZ = CLOCK_Z - math.sin(angle) * MARKER_DIST

		local isMain = (i % 3 == 0)
		local mLen = isMain and 0.35 or 0.20
		local mWidth = isMain and 0.10 or 0.06

		local marker = Instance.new("Part")
		marker.Name = "HourMark_" .. i
		marker.Size = Vector3.new(0.05, mLen, mWidth)
		marker.CFrame = CFrame.new(MARKER_X, markerY, markerZ) * CFrame.Angles(-angle, 0, 0)
		marker.Color = isMain and Color3.fromRGB(210, 180, 105) or Color3.fromRGB(160, 140, 90)
		marker.Material = Enum.Material.Metal
		marker.Anchored = true
		marker.CanCollide = false
		marker.CastShadow = false
		marker.Parent = clockFolder
	end

	-- Roman numerals (SurfaceGui on right face)
	local plate = Instance.new("Part")
	plate.Name = "ClockLabelPlate"
	plate.Size = Vector3.new(0.02, CLOCK_RADIUS * 1.7, CLOCK_RADIUS * 1.7)
	plate.Transparency = 1
	plate.Anchored = true
	plate.CanCollide = false
	plate.CastShadow = false
	plate.Parent = clockFolder
	PlacePlateRightFaceOnWall(plate, WALL_INNER_X)

	local clockGui = Instance.new("SurfaceGui")
	clockGui.Name = "ClockNumbersGui"
	clockGui.Face = Enum.NormalId.Right
	clockGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	clockGui.PixelsPerStud = 60
	clockGui.Parent = plate

	local guiContainer = Instance.new("Frame")
	guiContainer.Name = "Container"
	guiContainer.Size = UDim2.new(1,0,1,0)
	guiContainer.BackgroundTransparency = 1
	guiContainer.Parent = clockGui

	local romanNumerals = {"XII","I","II","III","IV","V","VI","VII","VIII","IX","X","XI"}
	local NUMERAL_DIST = 0.38

	for i = 1, 12 do
		local angle = math.rad((i - 1) * 30)
		local normDeltaY = math.cos(angle) * NUMERAL_DIST
		local normDeltaZ = math.sin(angle) * NUMERAL_DIST
		local gx = 0.5 + normDeltaZ
		local gy = 0.5 - normDeltaY

		local numLabel = Instance.new("TextLabel")
		numLabel.Name = "Num_" .. i
		numLabel.Size = UDim2.new(0.14, 0, 0.09, 0)
		numLabel.Position = UDim2.new(gx - 0.07, 0, gy - 0.045, 0)
		numLabel.BackgroundTransparency = 1
		numLabel.Text = romanNumerals[i]
		numLabel.TextColor3 = Color3.fromRGB(195, 170, 105)
		numLabel.TextScaled = true
		numLabel.Font = Enum.Font.Antique
		numLabel.Parent = guiContainer
	end

	-- Hands (hour/minute fixed at 3:33 as before)
	local function CreateClockHand(name, length, width, thickness, color)
		local hand = Instance.new("Part")
		hand.Name = name
		hand.Size = Vector3.new(thickness, length, width)
		hand.Color = color
		hand.Material = Enum.Material.Metal
		hand.Anchored = true
		hand.CanCollide = false
		hand.CastShadow = false
		hand.Parent = clockFolder
		return hand
	end

	local hourHandLength = CLOCK_RADIUS * 0.45
	local minuteHandLength = CLOCK_RADIUS * 0.65
	local secondsHandLength = CLOCK_RADIUS * 0.72
	local secondsTailLength = CLOCK_RADIUS * 0.20

	local hourHand = CreateClockHand("HourHand", hourHandLength, 0.16, 0.06, Color3.fromRGB(185,160,95))
	local minuteHand = CreateClockHand("MinuteHand", minuteHandLength, 0.10, 0.05, Color3.fromRGB(175,150,88))
	local secondsHand = CreateClockHand("SecondsHand", secondsHandLength, 0.04, 0.04, Color3.fromRGB(185,55,55))
	local secondsTail = CreateClockHand("SecondsTail", secondsTailLength, 0.06, 0.04, Color3.fromRGB(185,55,55))

	local HAND_FRONT_OFFSET = 0.025
	local HAND_X = WALL_INNER_X + HAND_FRONT_OFFSET

	local function SetClockHandCFrame(hand, angle, handLength, xPos)
		local halfLen = handLength / 2
		local cy = CLOCK_Y + math.cos(angle) * halfLen
		local cz = CLOCK_Z - math.sin(angle) * halfLen
		hand.CFrame = CFrame.new(xPos, cy, cz) * CFrame.Angles(-angle, 0, 0)
	end

	local function SetClockTailCFrame(tail, angle, tailLength, xPos)
		local oppAngle = angle + math.pi
		local halfLen = tailLength / 2
		local cy = CLOCK_Y + math.cos(oppAngle) * halfLen
		local cz = CLOCK_Z - math.sin(oppAngle) * halfLen
		tail.CFrame = CFrame.new(xPos, cy, cz) * CFrame.Angles(-oppAngle, 0, 0)
	end

	-- Fixed hour/minute unchanged
	local fixedHourAngle = math.rad((3.55 / 12) * 360)
	local fixedMinuteAngle = math.rad((33 / 60) * 360)
	-- We'll still use a nominal fixedSecondsAngle=0 for initial placement (XII)
	local fixedSecondsAngle = 0

	SetClockHandCFrame(hourHand, fixedHourAngle, hourHandLength, HAND_X)
	SetClockHandCFrame(minuteHand, fixedMinuteAngle, minuteHandLength, HAND_X + 0.004)
	-- Initialize seconds visually at XII (will be adjusted by coroutine to oscillate)
	SetClockHandCFrame(secondsHand, fixedSecondsAngle, secondsHandLength, HAND_X + 0.008)
	SetClockTailCFrame(secondsTail, fixedSecondsAngle, secondsTailLength, HAND_X + 0.008)

	-- =====================================================
	-- SECONDS HAND ANIMATION: oscillate around XII (simulate "about to change minute, then retreat")
	-- from -3? to +3? (half-tick before/after XII) and back continuously.
	-- =====================================================
	coroutine.wrap(function()
		local oneTickAngle = math.rad(6)  -- full tick = 6?
		-- baseAngle chosen so that animation goes from -3? to +3? (i.e. centered on 0)
		local baseAngle = -oneTickAngle / 2
		local secX = HAND_X + 0.008

		-- start at baseAngle to avoid sudden jump
		SetClockHandCFrame(secondsHand, baseAngle, secondsHandLength, secX)
		SetClockTailCFrame(secondsTail, baseAngle, secondsTailLength, secX)

		local advancing = true
		while clockFolder and clockFolder.Parent do
			local fromAngle, toAngle
			if advancing then
				fromAngle = baseAngle
				toAngle = baseAngle + oneTickAngle -- equals +oneTickAngle/2 (i.e. +3?)
			else
				fromAngle = baseAngle + oneTickAngle
				toAngle = baseAngle
			end

			local tweenDuration = 0.35
			local steps = 14
			for step = 1, steps do
				local alpha = step / steps
				local eased
				if alpha < 0.5 then
					eased = 2 * alpha * alpha
				else
					eased = 1 - 2 * (1 - alpha) * (1 - alpha)
				end
				local interpAngle = fromAngle + (toAngle - fromAngle) * eased
				SetClockHandCFrame(secondsHand, interpAngle, secondsHandLength, secX)
				SetClockTailCFrame(secondsTail, interpAngle, secondsTailLength, secX)
				task.wait(tweenDuration / steps)
			end

			if advancing then
				task.wait(0.2)
			else
				task.wait(0.45)
			end
			advancing = not advancing
		end
	end)()

	print("[Lobby] Horror clock (segundero trabado en XII, oscilando alrededor de 12) colocado.")

	-- LOBBY LIGHTING
	local mainLightPositions = {
		Vector3.new(0, 15, 0),
		Vector3.new(-50, 12, 0),
		Vector3.new(50, 12, 0),
		Vector3.new(0, 10, -15),
		Vector3.new(0, 10, 15),
	}

	for i, pos in ipairs(mainLightPositions) do
		local lightPart = Instance.new("Part")
		lightPart.Name = "LobbyLight_"..i
		lightPart.Size = Vector3.new(1, 1, 1)
		lightPart.Position = pos
		lightPart.Anchored = true
		lightPart.CanCollide = false
		lightPart.Transparency = 1
		lightPart.Parent = lobbyFolder

		local pointLight = Instance.new("PointLight")
		pointLight.Brightness = 1.5
		pointLight.Range = 80
		pointLight.Color = Color3.fromRGB(180, 170, 200)
		pointLight.Shadows = false
		pointLight.Parent = lightPart
	end

	local floorLight = Instance.new("Part")
	floorLight.Name = "LobbyFloorLight"
	floorLight.Size = Vector3.new(CONFIG.LOBBY_LENGTH, 1, 60)
	floorLight.Position = Vector3.new(0, 8, 0)
	floorLight.Anchored = true
	floorLight.CanCollide = false
	floorLight.Transparency = 1
	floorLight.Parent = lobbyFolder

	local floorPointLight = Instance.new("PointLight")
	floorPointLight.Brightness = 2
	floorPointLight.Range = 100
	floorPointLight.Color = Color3.fromRGB(150, 145, 170)
	floorPointLight.Shadows = true
	floorPointLight.Parent = floorLight

	local cornerPositions = {
		Vector3.new(CONFIG.LOBBY_START_X + 10, 6, -20),
		Vector3.new(CONFIG.LOBBY_START_X + 10, 6, 20),
		Vector3.new(CONFIG.LOBBY_END_X - 10, 6, -20),
		Vector3.new(CONFIG.LOBBY_END_X - 10, 6, 20),
	}

	for i, pos in ipairs(cornerPositions) do
		local cornerPart = Instance.new("Part")
		cornerPart.Name = "CornerLight_"..i
		cornerPart.Size = Vector3.new(1, 1, 1)
		cornerPart.Position = pos
		cornerPart.Anchored = true
		cornerPart.CanCollide = false
		cornerPart.Transparency = 1
		cornerPart.Parent = lobbyFolder

		local cornerLight = Instance.new("PointLight")
		cornerLight.Brightness = 1.2
		cornerLight.Range = 50
		cornerLight.Color = Color3.fromRGB(160, 150, 180)
		cornerLight.Shadows = false
		cornerLight.Parent = cornerPart
	end

	local shopAreaLight = Instance.new("Part")
	shopAreaLight.Name = "ShopAreaLight"
	shopAreaLight.Size = Vector3.new(1, 1, 1)
	shopAreaLight.Position = Vector3.new(0, 8, wallZ + 5)
	shopAreaLight.Anchored = true
	shopAreaLight.CanCollide = false
	shopAreaLight.Transparency = 1
	shopAreaLight.Parent = shopFolder

	local shopLight = Instance.new("PointLight")
	shopLight.Brightness = 2.5
	shopLight.Range = 40
	shopLight.Color = Color3.fromRGB(220, 190, 140)
	shopLight.Shadows = false
	shopLight.Parent = shopAreaLight

	local edgeLeft = Instance.new("Part")
	edgeLeft.Name = "EdgeLightLeft"
	edgeLeft.Size = Vector3.new(1, 1, 1)
	edgeLeft.Position = Vector3.new(CONFIG.LOBBY_START_X, 5, 0)
	edgeLeft.Anchored = true
	edgeLeft.CanCollide = false
	edgeLeft.Transparency = 1
	edgeLeft.Parent = lobbyFolder

	local edgeLightL = Instance.new("PointLight")
	edgeLightL.Brightness = 0.8
	edgeLightL.Range = 30
	edgeLightL.Color = Color3.fromRGB(120, 80, 150)
	edgeLightL.Shadows = false
	edgeLightL.Parent = edgeLeft

	local edgeRight = edgeLeft:Clone()
	edgeRight.Name = "EdgeLightRight"
	edgeRight.Position = Vector3.new(CONFIG.LOBBY_END_X, 5, 0)
	edgeRight.Parent = lobbyFolder

	print("[Lobby] ?? Lighting system initialized - Horror atmosphere with visibility")
	print("? Lobby created with glowing potions and magical staff orb")
end

-- -------------------------------------------------------------------------------
-- STREET SEGMENT
-- -------------------------------------------------------------------------------

local function CreateSegment(startX)
	local key = tostring(math.floor(startX / CONFIG.STREET_SEGMENT_LENGTH))
	if generatedSegments[key] then return end
	generatedSegments[key] = true

	local folder = Instance.new("Folder")
	folder.Name = "Segment_"..key
	folder.Parent = worldFolder

	streetSegments[key] = {folder = folder, startX = startX, endX = startX + CONFIG.STREET_SEGMENT_LENGTH}

	local centerX = startX + CONFIG.STREET_SEGMENT_LENGTH / 2
	local segLen = CONFIG.STREET_SEGMENT_LENGTH

	local segmentEnd = startX + segLen
	local overlapsLobby = not (segmentEnd < CONFIG.LOBBY_START_X or startX > CONFIG.LOBBY_END_X)

	if not overlapsLobby then
		MakePart("Street", Vector3.new(segLen + 0.5, 1, CONFIG.STREET_WIDTH),
			Vector3.new(centerX, 0, 0),
			CONFIG.COLORS.STREET, Enum.Material.Asphalt, folder)

		local lineGap = 9
		for i = 1, math.floor(segLen / lineGap) do
			if i % 2 == 0 then
				MakePart("Line", Vector3.new(4.5, 0.02, 0.32),
					Vector3.new(startX + (i - 0.5) * lineGap, 0.51, 0),
					CONFIG.COLORS.STREET_LINES, Enum.Material.Neon, folder, false, false, 0.2)
			end
		end

		for s = -1, 1, 2 do
			local swZ = s * (CONFIG.STREET_WIDTH/2 + CONFIG.SIDEWALK_WIDTH/2)

			MakePart(s == -1 and "SidewalkL" or "SidewalkR",
				Vector3.new(segLen + 0.5, 1, CONFIG.SIDEWALK_WIDTH),
				Vector3.new(centerX, 0.25, swZ),
				CONFIG.COLORS.SIDEWALK, Enum.Material.Concrete, folder)

			MakePart("Curb", Vector3.new(segLen + 0.5, 0.5, 0.35),
				Vector3.new(centerX, 0.75, s * (CONFIG.STREET_WIDTH/2 + 0.18)),
				LerpColor(CONFIG.COLORS.SIDEWALK, Color3.new(0.12, 0.12, 0.12), 0.2),
				Enum.Material.Concrete, folder)
		end

		for i = 1, math.floor(segLen / CONFIG.LAMP_SPACING) do
			local lampX = startX + (i - 0.5) * CONFIG.LAMP_SPACING
			CreateLamp(lampX, (i % 2 == 0) and "left" or "right", folder)
		end
	end

	local bDepth = CONFIG.BUILDING_DEPTH
	local bWidth = CONFIG.BUILDING_WIDTH
	local swEdge = CONFIG.STREET_WIDTH/2 + CONFIG.SIDEWALK_WIDTH

	local numBuildings = math.floor(segLen / bWidth)

	local leftFaceZ = -swEdge
	local leftBackZ = leftFaceZ - bDepth

	for i = 1, numBuildings do
		local xPos = startX + (i - 0.5) * bWidth
		CreateBuilding(i, xPos, leftFaceZ, leftBackZ, 1, bWidth, "left", folder)
	end

	local rightFaceZ = swEdge
	local rightBackZ = rightFaceZ + bDepth

	for i = 1, numBuildings do
		local xPos = startX + (i - 0.5) * bWidth
		CreateBuilding(i, xPos, rightFaceZ, rightBackZ, -1, bWidth, "right", folder)
	end
end

-- -------------------------------------------------------------------------------
-- GENERATION AND CLEANUP
-- -------------------------------------------------------------------------------

local function Generate()
	for _, player in pairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local px = hrp.Position.X
				local s1 = math.floor((px - CONFIG.GENERATION_DISTANCE) / CONFIG.STREET_SEGMENT_LENGTH)
				local s2 = math.floor((px + CONFIG.GENERATION_DISTANCE) / CONFIG.STREET_SEGMENT_LENGTH)
				for s = s1, s2 do
					CreateSegment(s * CONFIG.STREET_SEGMENT_LENGTH)
				end
			end
		end
	end
end

local function Cleanup()
	local minX = math.huge
	for _, player in pairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp and hrp.Position.X < minX then
				minX = hrp.Position.X
			end
		end
	end
	for key, data in pairs(streetSegments) do
		if data.endX < minX - CONFIG.CLEANUP_DISTANCE then
			if data.folder then data.folder:Destroy() end
			streetSegments[key] = nil
			generatedSegments[key] = nil
		end
	end
end

-- -------------------------------------------------------------------------------
-- PLAYER SETUP
-- -------------------------------------------------------------------------------
local function SetupPlayer(player)
	local function OnChar(char)
		local hum = char:WaitForChild("Humanoid", 10)
		local hrp = char:WaitForChild("HumanoidRootPart", 10)

		if hum and hrp then
			player.CameraMode = Enum.CameraMode.LockFirstPerson
			task.wait(0.3)
			Generate()

			-- =====================================================
			-- INTRO CINEMATIC SYSTEM (WITH VISIBILITY HIDING)
			-- =====================================================
			task.spawn(function()
				local IntroCinematicModule = nil
				local cinematicSuccess, cinematicError = pcall(function()
					IntroCinematicModule = require(ServerScriptService:WaitForChild("IntroCinematicModule", 10))
				end)

				if not cinematicSuccess or not IntroCinematicModule then
					warn("[MainGameServer] Failed to load IntroCinematicModule: " .. tostring(cinematicError))
					player:SetAttribute("CinematicReady", true)
					CinematicReadySignal:FireClient(player)
					hrp.CFrame = CFrame.new(0, 4, 0)
					hum.WalkSpeed = 16
					hum.JumpPower = 50
					return
				end

				local shouldPlayIntro = IntroCinematicModule.ShouldPlayIntro(player)

				if shouldPlayIntro then
					-- =====================================================
					-- HIDE PLAYER BEFORE CINEMATIC STARTS
					-- =====================================================
					CinematicVisibilitySystem.HidePlayerFromEveryone(player)

					print("[MainGameServer] Pre-building cinematic neighborhood for: " .. player.Name)

					player:SetAttribute("CinematicReady", true)
					CinematicReadySignal:FireClient(player)

					local waitStart = tick()
					local maxWait = 10

					repeat
						task.wait(0.05)
					until player:GetAttribute("FullyLoaded") or (tick() - waitStart) >= maxWait

					task.wait(0.2)

					print("[MainGameServer] Starting intro cinematic for: " .. player.Name)

					player:SetAttribute("CinematicReady", true)
					local cinematicReadyEvent = ReplicatedStorage:FindFirstChild("CinematicReadySignal")
					if cinematicReadyEvent then
						cinematicReadyEvent:FireClient(player)
					end

					local savedWalk = nil
					local savedJump = nil
					if player.Character then
						local h = player.Character:FindFirstChildOfClass("Humanoid")
						if h then
							savedWalk = h.WalkSpeed
							savedJump = h.JumpPower
							h.WalkSpeed = 0
							h.JumpPower = 0
						end
					end

					local cinematicResult = IntroCinematicModule.PlayIntro(player, WizardNPCData)

					-- =====================================================
					-- SHOW PLAYER AFTER CINEMATIC ENDS
					-- =====================================================
					CinematicVisibilitySystem.ShowPlayerToEveryone(player)

					if not cinematicResult then
						hrp.CFrame = CFrame.new(0, 4, 0)
						hum.WalkSpeed = 16
						hum.JumpPower = 50
					end
				else
					player:SetAttribute("CinematicReady", true)
					CinematicReadySignal:FireClient(player)
					hrp.CFrame = CFrame.new(0, 4, 0)
					hum.WalkSpeed = 16
					hum.JumpPower = 50
				end
			end)

			hum.Died:Connect(function()
				-- If player dies during cinematic, make sure to restore visibility
				if CinematicVisibilitySystem.IsInCinematic(player) then
					CinematicVisibilitySystem.ShowPlayerToEveryone(player)
				end
				PlayerDiedEvent:FireClient(player)
			end)
		end
	end

	if player.Character then OnChar(player.Character) end
	player.CharacterAdded:Connect(OnChar)
end
-- -------------------------------------------------------------------------------
-- INITIALIZATION
-- -------------------------------------------------------------------------------
-- -------------------------------------------------------------------------------
-- CLEANUP AMBASSADOR TRACKING ON PLAYER LEAVE
-- -------------------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	-- Clean up cinematic visibility state
	if CinematicVisibilitySystem.IsInCinematic(player) then
		CinematicVisibilitySystem.ShowPlayerToEveryone(player)
	end
end)

local function Init()
	print("---------------------------------------------------------------")
	print("       INFINITE STREET V34 - DOOR EVENTS + NEW PROBABILITIES  ")
	print("---------------------------------------------------------------")
	print("")
	print("Door Probability System V2:")
	print("  - Door Opens:               "..DOOR_CONFIG.DOOR_OPENS_CHANCE.."%")
	print("  - Door Locked:             "..DOOR_CONFIG.DOOR_LOCKED_CHANCE.."%")
	print("")
	print("When Door Opens (85%):")
	print("  - Bad (NPC):               "..DOOR_CONFIG.BAD_OUTCOME_CHANCE.."% of total")
	print("  - Good (Treasure):         "..DOOR_CONFIG.GOOD_OUTCOME_CHANCE.."% of total")
	print("  - Event (Random):          "..DOOR_CONFIG.EVENT_OUTCOME_CHANCE.."% of total")
	print("")
	print("Treasure Chest Settings:")
	print("  - Door stays open:         "..DOOR_CONFIG.GOOD_DOOR_OPEN_DURATION.." seconds")
	print("  - Claim time limit:        "..DOOR_CONFIG.CHEST_CLAIM_TIME.." seconds")
	print("")
	print("Anti-Exploit Features:")
	print("  - Lobby entry cancels NPC survival reward")
	print("  - Only players present when door opens can claim chest")
	print("  - Door outcomes reroll after closing")
	print("")

	if DoorEventsModule then
		print("Door Events System:  ? LOADED")
		local eventCount = DoorEventsModule.GetEventCount and DoorEventsModule.GetEventCount() or "Unknown"
		print("  - Available Events: " ..tostring(eventCount))
	else
		print("Door Events System: ? NOT LOADED")
	end
	print("")

	if HorrorDetailsModule then
		print("Horror Building Features (Module Loaded ?):")
		print("  - Window Eyes Chance:     "..HorrorDetailsModule.CONFIG.WINDOW_EYES_CHANCE * 100 .."%")
		print("  - Broken Window Chance:   "..HorrorDetailsModule.CONFIG.WINDOW_BROKEN_CHANCE * 100 .."%")
	else
		print("Horror Building Features:     MODULE NOT LOADED")
	end
	print("")
	print("NPC Spawn Weights (within "..DOOR_CONFIG.BAD_OUTCOME_CHANCE.."% bad chance):")
	print("  Total Weight: "..TOTAL_NPC_WEIGHT)
	print("")

	for npcType, npcData in pairs(NPC_STATS) do
		local spawnPercent = (npcData.SPAWN_WEIGHT / TOTAL_NPC_WEIGHT) * DOOR_CONFIG.BAD_OUTCOME_CHANCE
		print(string.format("  %s [%s]:", npcData.NAME, npcData.RARITY))
		print(string.format("    - Weight: %d (%.1f%% total chance)", npcData.SPAWN_WEIGHT, spawnPercent))
		print(string.format("    - Damage: %d | Speed: %d | Range: %d", npcData.DAMAGE, npcData.SPEED, npcData.ATTACK_RANGE))
		print(string.format("    - Rewards: Door $%d | Survive $%d", npcData.REWARD_DOOR_OPEN, npcData.REWARD_SURVIVAL))
		print(string.format("    - LIFETIME: %d seconds", npcData.LIFETIME))
		print("")
	end

	print("Treasure Chest Rewards:")
	print("  Item Chance:   40%")
	print("  Money Chance: 60%")
	print("  Money Ranges:")
	print("    - Common:      $20-50   (weight 100)")
	print("    - Uncommon:   $51-100  (weight 60)")
	print("    - Rare:        $101-200 (weight 30)")
	print("    - Epic:       $201-350 (weight 12)")
	print("    - Legendary:   $351-500 (weight 3)")
	print("")
	print("Safe Zone:      X="..CONFIG.LOBBY_START_X.." to X="..CONFIG.LOBBY_END_X)
	print("---------------------------------------------------------------")

	SetupAtmosphere()
	CreateLobby()

	-- SPAWN INVISIBLE
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.Duration = 0
	spawn.Parent = lobbyFolder

	for _, child in pairs(spawn:GetChildren()) do
		if child: IsA("Decal") then
			child: Destroy()
		end
	end

	for i = -3, 3 do
		CreateSegment(i * CONFIG.STREET_SEGMENT_LENGTH)
	end

	for _, p in pairs(Players: GetPlayers()) do SetupPlayer(p) end
	Players.PlayerAdded:Connect(SetupPlayer)

	local lastGen = 0
	RunService.Heartbeat:Connect(function()
		local t = tick()
		if t - lastGen > 0.5 then
			lastGen = t
			Generate()
		end
	end)

	coroutine.wrap(function()
		while true do
			task.wait(5)
			Cleanup()
		end
	end)()

	StartRooftopRunnerSystem()
	-- Start building ambient sounds
	BuildingSoundSystem:Start()

	print("---------------------------------------------------------------")
	print("                         READY                                  ")
	print("---------------------------------------------------------------")

	print("")
	print("Cinematic System:")
	local cinematicLoaded = pcall(function()
		require(ServerScriptService:WaitForChild("IntroCinematicModule", 1))
	end)
	if cinematicLoaded then
		print("  - Intro Cinematic: ? LOADED")
		print("  - Loading Screen:  ? ENABLED")
		print("  - Duration:        ~60 seconds")
	else
		print("  - Intro Cinematic: ? NOT LOADED")
	end
	print("")
end

-- -------------------------------------------------------------------------------
-- THROWABLE SYSTEM INTEGRATION
-- -------------------------------------------------------------------------------

local function OnSegmentCreated(segmentFolder, startX, segmentLength)
	if _G.ThrowableSystem and _G.ThrowableSystem.SpawnThrowablesInSegment then
		_G.ThrowableSystem.SpawnThrowablesInSegment(segmentFolder, startX, segmentLength)
	end
end

local OriginalCreateSegment = CreateSegment

CreateSegment = function(startX)
	OriginalCreateSegment(startX)

	local key = tostring(math.floor(startX / CONFIG.STREET_SEGMENT_LENGTH))
	local segmentData = streetSegments[key]

	if segmentData and segmentData.folder then
		OnSegmentCreated(segmentData.folder, startX, CONFIG.STREET_SEGMENT_LENGTH)
	end
end

-- -------------------------------------------------------------------------------
-- START
-- -------------------------------------------------------------------------------

Init()