-- // ============================================================ // --
-- //   TASFF_Lists.lua                                           // --
-- //   Keyword lists, classifiers, feature list, game configs.  // --
-- //   Load order: State → Lists → Core → UI                   // --
-- //   Populates S.ClassifyTool and related slots.              // --
-- // ============================================================ // --

local S = _G.TASFF_State

-- // ── Weapon Classification Keywords ───────────────────────────── // --
-- Smart case-insensitive matching. Short abbreviations (<= 3 chars) use word-boundary
-- checks to prevent false positives (e.g. "ar" will not match "star fruit").
-- Specific compound weapons (e.g. "sawblade", "chainsaw") are protected from tool keywords ("saw").

local WeaponKeywords = {
    -- Assault Rifles / Carbines / Battle Rifles
    "assault rifle","rifle","carbine","ar-15","m4a1","m16","scar","galil","tar-21","aug",
    "famas","g36","hk416","ak47","ak-47","ak74","ak-74","ak12","fal","acr","badger",
    "g3","val","an-94","groza","sa-58","m14","socom","m1 garand","stg","stg44",
    -- Submachine Guns
    "submachine","smg","mp5","mp7","mp9","ump","p90","vector","kriss","mac-10","mac-11",
    "uzi","ppsh","scorp","bizon","sten","mp40","thompson","tommy gun","grease gun",
    -- Shotguns
    "shotgun","spas","remington","mossberg","saiga","benelli","striker","trench gun",
    "sawed-off","sawed off","sawnoff","double barrel","pump action","blunderbuss","super shorty",
    "aa-12","origin-12","coach gun","scattergun",
    -- Snipers & DMRs
    "sniper","awp","awm","barrett","mosin","kar98","kar98k","springfield","dragunov","svd",
    "scout","dmr","marksman","hunting rifle","railgun","intervention","hecate","wa2000",
    -- Handguns / Pistols / Revolvers
    "pistol","handgun","glock","deagle","desert eagle","beretta","m1911","colt","luger",
    "usp","p250","p226","p320","revolver","magnum","derringer","python","anaconda","peacekeeper",
    "flintlock","zip 22","tec-9","five-seven","makarov","tokarev",
    -- Heavy & Machine Guns
    "minigun","gatling","lmg","rpk","m249","negev","mg42","bren","lewis","m60","pkm","dp-27",
    "chaingun","vulcan",
    -- Launchers, Projectiles & Special
    "rocket launcher","rpg","bazooka","grenade launcher","cannon","mortar","blaster","laser",
    "plasma","raygun","crossbow","longbow","compound bow","blowpipe","slingshot",
    -- Short identifiers (evaluated strictly via word-boundaries)
    "ar","ak","m4","awp","dmr","lmg","rpg","gun","bow",
}

local MeleeKeywords = {
    -- Swords & Blades
    "sword","katana","broadsword","longsword","claymore","rapier","scimitar","cutlass",
    "saber","sabre","blade","greatsword","zweihander","falchion","machete","nodachi",
    "wakizashi","tanto","gladius","shortsword","bastard sword","excalibur","dao","jian",
    -- Knives & Daggers
    "knife","dagger","karambit","kunai","butterfly knife","balisong","bowie","hunting knife",
    "shiv","switchblade","push dagger","trench knife","stiletto","dirk","kris","cleaver",
    -- Axes, Saws & Polearms
    "axe","battleaxe","hatchet","tomahawk","halberd","bardiche","chainsaw","sawblade",
    "buzzsaw","bonesaw","scythe","spear","lance","pike","trident","javelin","glaive","naginata",
    -- Blunt, Impact & Brawling
    "hammer","warhammer","mace","club","baseball bat","bat","flail","morningstar","crowbar",
    "pipe","lead pipe","brass knuckles","knuckles","fist","cestus","gauntlet","sledgehammer",
    "blackjack","cudgel","baton","nightstick","tonfa",
    -- Martial Arts & Thrown
    "staff","quarterstaff","bo staff","nunchaku","nunchuck","shuriken","kama","sai","whip",
    "claws","claw",
}

local NonWeaponKeywords = {
    -- Consumables & Food
    "potion","elixir","flask","food","apple","banana","pizza","bread","burger","cake",
    "cookie","donut","sandwich","pie","meat","steak","chicken","star fruit","fruit",
    "berry","mushroom","carrot","potato","vegetable","candy","chocolate","taco",
    "drink","water","soda","juice","bottle","cup","mug","coffee","tea","milk",
    -- Medical & Healing
    "medkit","first aid","bandage","gauze","heal","syringe","pill","injection","splint",
    "adrenaline","defibrillator","health pack","blood bag",
    -- Building, Utilities, Tools & Mining
    "pickaxe","shovel","hoe","rake","fishing rod","rod","flashlight","torch","lantern",
    "lighter","match","compass","map","radio","walkie","camera","binoculars","telescope",
    "detector","scanner","key","keycard","lockpick","briefcase","backpack","bag","umbrella",
    "paint","paintbrush","brush","spray","spray can","build","placemat","wrench","saw",
    "coin","money","gold","cash","card","ticket","balloon","popper","confetti",
}

-- // ── Classifier Helper ────────────────────────────────────────── // --

local function MatchesKeyword(str, kw)
    if #kw <= 3 then
        if kw:match("^%a+$") then
            return str:match("%f[%a]" .. kw .. "%f[%A]") ~= nil
        else
            return (str:match("%f[%w]" .. kw .. "%f[%W]") ~= nil) or (str:match("%f[%a]" .. kw) ~= nil)
        end
    else
        return str:find(kw, 1, true) ~= nil
    end
end

local function ClassifyTool(toolName)
    if type(toolName) ~= "string" or toolName == "" then return "Unknown" end
    local lower = toolName:lower()
    -- Melee checked before weapon (more specific, e.g. "chainsaw", "sawblade", "knife")
    for _, kw in ipairs(MeleeKeywords) do
        if MatchesKeyword(lower, kw) then return "Melee" end
    end
    -- Non-weapon before weapon (food/medical/utility should never trigger weapon engagement)
    for _, kw in ipairs(NonWeaponKeywords) do
        if MatchesKeyword(lower, kw) then return "NonWeapon" end
    end
    -- Weapon last — broadest match with smart word boundary checks for short abbreviations
    for _, kw in ipairs(WeaponKeywords) do
        if MatchesKeyword(lower, kw) then return "Weapon" end
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
    "Player ESP", "NPC ESP", "3D Chams",
    "2D Box ESP", "Skeleton ESP", "Snaplines", "OOF Arrows",
    "Crosshair", "FOV Circle", "Dynamic Visibility Colors",
    "Screen Overlay Tags", "Kill Confirmation Flash",
    "Aim Lock Indicator", "Distance-Based ESP Fade",
    "Team-Colored ESP", "Blacklist ESP Tag",
    -- Intel
    "Threat Detector", "Nemesis System", "Kill-Count Threat Flag",
    "Kill Feed", "Threat Neutralization", "Auto-Expire on Disconnect",
    "Click-to-Mark", "Focus Mode", "Target Lock History",
    "Auto-Disable on Death", "ESP Whitelist",
    "Disconnect Notification",
    -- Automation
    "Auto-Engage on Equip", "Intelligent Equip Filter",
    "Tool Blacklist (Persistent)", "Rapid Aim Mode Hotkey",
    -- System
    "Performance Pipeline", "Performance Auto-Tune", "Anti-AFK",
    "Auto-Update Checker", "Panic System (Permanent)", "Panic on Focus Loss",
    "Notification Throttle", "Debug Mode", "Preset Profiles",
    "Quick-Load Game Configs", "UI Theme Editor",
    "Team Check", "Ignore Dead Targets",
    -- Customization
    "Custom ESP Colors (per category)", "Custom OOF Arrow Color",
    "Custom Chams Color", "Custom Kill Flash Color",
    -- v2.1.2 Additions
    "Session User Kill Count", "Priority Player Kill Tracking",
    "DisplayName in Dropdowns", "Server Info Panel",
    "Notification Duration Control", "Suppress Rayfield Ads",
    "UI Theme Editor (Persisted)", "Per-Section Theming Controls",
    "18 Global UI Theme Presets", "Theme-Aware Window Title",
    -- v2.2.0 Additions
    "Screen Recording Cloaking System",
    "High-Contrast ESP Tag Outlines",
    "Restart Script Engine",
    "Per-Game Autosaving",
    "Preset Feature Inspection Status Display",
    "Override Selected Profile",
    -- v2.2.5 Additions
    "Enhanced Threat Intelligence Engine",
    "Deep Tag & Attribute Scanner",
    "Leaderboard Stat Correlator",
    "Threat Victim Kill Bypass",
    "Priority-Target OOF Arrows",
    "Humanized Legit Dynamics",
    "Aim Path Wrist Curvature",
    "Target Deadzone Slack",
    "Physiological Hand Tremor & Sway",
    "Human Reaction Inertia Tracking",
    "Hitbox Surface Drift",
    "Ambush Latency Eliminator",
    "Distance-Based Auto Prediction",
    "Universal Player Damage Tracking",
    "Expert Instincts (Instant Counter-Lock)",
    "Configurable Expert Instincts Intensity",
    "Expert Instincts Inventory Defense Check",
    "Smart Weapon Keyword Classifier",
    "Continuous Kills Permanent Priority",
    "Dedicated Misc & System Tab Separation",
    "Legacy Changelog Archive",
    "Continuous Expert Instincts Tracking",
    "Concealment & Foliage Check",
    "Humanized Cover Anticipation",
    "Environmental Awareness ESP",
    "Triggerbot Priority Target Filter",
    "Environmental ESP Distance Fade",
    "Quick Preset Profile Switching",
    "Expert Instincts Auto-Equip",
    "Expert Instincts First Person Camera",
}

S.FeatureCount = #FeatureList
-- Control totals reflect the Create* declarations in TASFF_UI.lua.
S.ToggleCount         = 102  -- +2 (InstinctsAutoEquip, InstinctsFirstPersonCamera)
S.SliderCount         = 38   -- (EnvironmentalESPTransparency)
S.DropdownCount       = 43   -- (VOSPriorityParts)
S.ButtonCount         = 29   -- (Check for Updates Now, Instincts Blacklist Add/Remove, Instincts Priority Add/Remove)
S.KeybindCount        = 8    -- +1 (Master Switch Keybind in CombatTab)
S.StatusDisplayCount  = 7    -- Server Info, Quick Feature Status, Session Stats, Priority/Intel Monitor, Preset Status, Cloak Status, Repository Status
S.ParagraphCount      = 35   -- +1 (Quick Profile Switcher in PresetsTab)

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
