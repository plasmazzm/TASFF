-- // ============================================================ // --
-- //   TASFF_Lists.lua                                           // --
-- //   Keyword lists, classifiers, feature list, game configs.  // --
-- //   Load order: State → Lists → Core → UI                   // --
-- //   Populates S.ClassifyTool and related slots.              // --
-- // ============================================================ // --

local S = _G.TASFF_State

-- // ── Weapon Classification Keywords ───────────────────────────── // --
-- Add your own keywords to any list. Matching is case-insensitive
-- substring search against the tool's Name property.

local WeaponKeywords = {
    "gun","rifle","pistol","sniper","shotgun","smg","ak","m4","mp5","awp",
    "deagle","revolver","cannon","blaster","laser","musket","carbine","uzi",
    "minigun","railgun","ar","lmg","dmr","burst","auto","semi","shoot",
    "fire","bullet","ammo","mag","clip","reload","scope","silencer",
    "suppressor","glock","p90","mp40","sten","bren","nade","grenade",
}

local MeleeKeywords = {
    "sword","knife","blade","katana","dagger","axe","bat","club","fist",
    "punch","slash","saber","machete","spear","lance","scythe","hammer",
    "mace","whip","claws","claw","melee","stab","shiv","cleave","bludgeon",
    "staff","wand","stick","bonk","slap","swing","hit","kunai","shuriken",
}

local NonWeaponKeywords = {
    "potion","food","medkit","heal","bandage","apple","pizza","tool",
    "pickaxe","shovel","build","place","rod","fishing","flashlight","torch",
    "key","book","map","bag","backpack","drink","water","juice","mushroom",
    "berry","fruit","vegetable","carrot","bread","coin","money","gold",
    "shield","detector","scanner","camera","paint","brush","wrench","saw",
}

-- // ── Classifier ───────────────────────────────────────────────── // --

local function ClassifyTool(toolName)
    if type(toolName) ~= "string" or toolName == "" then return "Unknown" end
    local lower = toolName:lower()
    -- Melee checked before weapon (more specific)
    for _, kw in ipairs(MeleeKeywords) do
        if lower:find(kw, 1, true) then return "Melee" end
    end
    -- Non-weapon before weapon (food/tools should never activate aimbot)
    for _, kw in ipairs(NonWeaponKeywords) do
        if lower:find(kw, 1, true) then return "NonWeapon" end
    end
    -- Weapon last — broadest match
    for _, kw in ipairs(WeaponKeywords) do
        if lower:find(kw, 1, true) then return "Weapon" end
    end
    return "Unknown"
end

local function IsRangedWeapon(toolName) return ClassifyTool(toolName) == "Weapon"   end
local function IsMeleeWeapon(toolName)  return ClassifyTool(toolName) == "Melee"    end
local function IsNonWeapon(toolName)    return ClassifyTool(toolName) == "NonWeapon" end

S.ClassifyTool   = ClassifyTool
S.IsRangedWeapon = IsRangedWeapon
S.IsMeleeWeapon  = IsMeleeWeapon
S.IsNonWeapon    = IsNonWeapon

-- // ── Feature List (Home tab counter + dashboard) ───────────────── // --

local FeatureList = {
    -- Combat
    "Master Switch", "Aimbot Engine", "Silent Aim", "Sticky Aim",
    "Wall Check", "Auto ADS", "Randomize Hitboxes", "Target Switch Delay",
    "Grace Period", "Health Threshold Gate", "Dynamic FOV Scaling",
    "Blatant Snap Speed", "Split X/Y Smoothness", "VoS Priority Parts",
    -- Triggerbot
    "Mouse Triggerbot", "Key Triggerbot", "Proximity Auto-Melee",
    "Weapon-Type Gating",
    -- Visuals
    "Player ESP", "NPC ESP", "Chams", "Stream-Proof Chams",
    "2D Box ESP", "Skeleton ESP", "Snaplines", "OOF Arrows",
    "Crosshair", "FOV Circle", "Dynamic Visibility Colors",
    "Stream-Proof Tags", "Kill Confirmation Flash",
    "Aim Lock Indicator", "Distance-Based ESP Fade",
    "Team-Colored ESP", "Blacklist ESP Tag",
    -- Intel
    "Threat Detector", "Nemesis System", "Kill-Count Threat Flag",
    "Kill Feed", "Threat Neutralization", "Auto-Expire on Disconnect",
    "Click-to-Mark", "Focus Mode", "Target Lock History",
    "Auto-Disable on Death", "ESP Whitelist",
    -- Automation
    "Auto-Engage on Equip", "Intelligent Equip Filter",
    "Tool Blacklist (Persistent)", "Rapid Aim Mode Hotkey",
    -- System
    "Performance Pipeline", "Performance Auto-Tune", "Anti-AFK",
    "Auto-Update Checker", "Panic System", "Panic on Focus Loss",
    "Notification Throttle", "Debug Mode", "Preset Profiles",
    "Quick-Load Game Configs", "UI Theme Editor",
    "Team Check", "Ignore Dead Targets",
}

S.FeatureCount = #FeatureList

-- // ── Preset Game Configurations ───────────────────────────────── // --
-- Applied via the Presets tab "Quick-Load Game Config" dropdown.
-- These are read-only reference configs. User presets are separate.

S.PresetGameConfigs = {
    ["Arsenal"] = {
        Mode = "Advanced Legit (Mouse)", TargetPart = "Head",
        SmoothnessX = 1.2, SmoothnessY = 1.2, PredictionAmount = 0.12,
        SilentAimEnabled = false, StickyAimEnabled = true, WallCheck = true,
        FOVSize = 120, ShowFOV = true, InvisibleFOV = false,
        AutoClickEnabled = true, ClickInterval = 100, ClickMethod = "Mash",
        TriggerbotClickMode = "Virtual", UseHighlight = true, UseInfoTag = true,
        ThreatDetectorEnabled = true, NemesisEnabled = true,
        PerformanceMode = "High",
    },
    ["Phantom Forces"] = {
        Mode = "Legit (Camera)", TargetPart = "Head",
        SmoothnessX = 2.0, SmoothnessY = 2.0, PredictionAmount = 0.20,
        SilentAimEnabled = false, StickyAimEnabled = false, WallCheck = true,
        FOVSize = 80, ShowFOV = false, InvisibleFOV = true,
        AutoClickEnabled = false, UseHighlight = true, UseInfoTag = true,
        PerformanceMode = "Medium",
    },
    ["BedWars"] = {
        Mode = "Blatant", TargetPart = "Head",
        SmoothnessX = 1.0, SmoothnessY = 1.0, PredictionAmount = 0.10,
        SilentAimEnabled = false, StickyAimEnabled = true, WallCheck = false,
        FOVSize = 200, ShowFOV = false,
        MeleeModeEnabled = true, MeleeDetectionRange = 7, MeleeClickInterval = 80,
        UseHighlight = true, UseInfoTag = true, TeamCheck = true,
        PerformanceMode = "High",
    },
    ["Criminality"] = {
        Mode = "Advanced Legit (Mouse)", TargetPart = "Head",
        SmoothnessX = 1.5, SmoothnessY = 1.5, PredictionAmount = 0.15,
        SilentAimEnabled = false, StickyAimEnabled = true, WallCheck = true,
        FOVSize = 150, ShowFOV = false,
        AutoClickEnabled = false,
        ThreatDetectorEnabled = true, NemesisEnabled = true,
        PerformanceMode = "Medium",
    },
    ["Da Hood"] = {
        Mode = "Advanced Legit (Mouse)", TargetPart = "Head",
        SmoothnessX = 1.8, SmoothnessY = 1.8, PredictionAmount = 0.18,
        SilentAimEnabled = false, StickyAimEnabled = true, WallCheck = true,
        FOVSize = 130, ShowFOV = false,
        ThreatDetectorEnabled = true, NemesisEnabled = true,
        AutoClickEnabled = true, ClickInterval = 120, ClickMethod = "Mash",
        PerformanceMode = "Medium",
    },
}

print("[TASFF Lists] Loaded. " .. S.FeatureCount .. " features registered. Classifiers active.")
