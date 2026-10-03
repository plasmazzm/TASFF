-- // ============================================================ // --
-- //   TASFF_State.lua                                            // --
-- //   Shared state table. Loaded first by TASFF_Loader.lua.     // --
-- //   All other modules access state via:                        // --
-- //       local S = _G.TASFF_State                              // --
-- // ============================================================ // --

_G.TASFF_State = {

    -- // ── Combat Core ────────────────────────────────────────── // --
    MasterEnabled               = false,
    AimbotActive                = false,
    TargetingEnabled            = true,
    StickyAimEnabled            = false,
    TeamCheck                   = false,
    WallCheck                   = true,
    IgnoreDead                  = true,
    ShowFOV                     = false,
    InvisibleFOV                = false,
    FOVSize                     = 100,
    TargetPart                  = "Head",
    VOSPriorityParts            = {},            -- parts to prefer first in VoS scan (e.g. {"Head","UpperTorso"})
    Mode                        = "Legit (Camera)",
    Smoothness                  = 1.5,           -- used by Legit (Camera) and as fallback
    SmoothnessX                 = 1.5,           -- horizontal smoothness for Advanced Legit (Mouse)
    SmoothnessY                 = 1.5,           -- vertical smoothness for Advanced Legit (Mouse)
    BlatantSnapSpeed            = 100,           -- 100 = instant snap; <100 = lerp fraction
    PredictionAmount            = 0.16,

    -- // ── v1.5.0 Combat Upgrades ─────────────────────────────── // --
    TargetSwitchDelayEnabled    = false,
    SwitchDelayMs               = 200,
    LastKillTime                = 0,
    DynamicRecoilEnabled        = false,
    SilentAimEnabled            = false,
    RandomizeHitboxEnabled      = false,
    PriorityMode                = "None",
    VitalityMode                = "None",
    StrictPrioritize            = false,   -- kept for preset backward compat; use PriorityBehavior instead

    -- // ── Threat System ──────────────────────────────────────── // --
    ThreatDetectorEnabled       = false,
    ThreatMemory                = {},
    ThreatTimeout               = 10,
    BlacklistExpiredThreats     = false,
    NemesisEnabled              = true,
    NemesisMemory               = {},

    -- // -- Intel System (v2.0.5) ------------------------------------ // --
    IntelPlayers                = {},
    IntelSelected               = "",
    PriorityBehavior            = "Boost",
    ThreatNeutralizationEnabled = false,
    AutoExpireOnDisconnect      = false,
    
    -- // -- Intel System Features (v2.0.5) --------------------------- // --
    KillCountThreatEnabled      = false,
    KillFeedEnabled             = false,
    KillsBeforeThreat           = 3,
    PlayerKillCounts            = {},
    KillsBeforeNemesis          = 3,
    PlayerNemesisStrikes        = {},
    SpectatePlayerEnabled       = false,
    SpectateTarget              = "",

    -- // ── Auto ADS ───────────────────────────────────────────── // --
    AutoADSEnabled              = false,
    AutoADSKeybind              = "MouseButton2",
    IsHoldingADS                = false,

    -- // ── Click-to-Mark & Focus ──────────────────────────────── // --
    ClickToMarkEnabled          = false,
    MarkKeybind                 = "T",
    MarkMethod                  = "Both",
    FocusMode                   = false,

    -- // ── Mouse Triggerbot ───────────────────────────────────── // --
    AutoClickEnabled            = false,
    ClickInterval               = 100,
    ClickMethod                 = "Mash",
    TriggerbotClickMode         = "Virtual",
    ThirdPersonTriggerbot       = false,
    LastClickTime               = 0,
    IsHoldingClick              = false,

    -- // ── Key Triggerbot ─────────────────────────────────────── // --
    KeyTriggerbotEnabled        = false,
    KeyTriggerbotKey            = "F",
    KeyTriggerMode              = "Single Press",
    IsHoldingTriggerKey         = false,
    LastKeyTriggerTime          = 0,

    -- // ── Melee Mode ─────────────────────────────────────────── // --
    MeleeModeEnabled            = false,
    MeleeDetectionRange         = 5,
    MeleeClickInterval          = 100,

    -- // ── Wallcheck & Penetration ────────────────────────────── // --
    NoCollisionCheck            = false,
    TransparencyCheck           = false,
    TransparencyThreshold       = 0.5,
    DecalsCheck                 = false,

    -- // ── Target Lists & Active State ────────────────────────── // --
    BlacklistedPlayers          = {},
    PriorityPlayers             = {},
    CurrentTarget               = nil,
    ActivePartName              = "Head",

    -- // ── Visual Targeting Flags ─────────────────────────────── // --
    VisualMode                  = "Single",
    TargetPlayers               = true,
    TargetNPCs                  = false,
    UseHighlight                = true,
    UseInfoTag                  = true,
    UseNPCHighlight             = true,
    UseNPCInfoTag               = true,
    TargetNearCenter            = false,
    AutoEnableOnEquip           = false,
    ToolBlacklist               = {},
    EnableCrosshair             = false,
    CrosshairStyle              = "Plus",
    CrosshairSize               = 10,
    ShowToolCheck               = false,
    ShowDisplayName             = false,
    UsePresetColors             = false,

    -- // ── Range & Grace Period ───────────────────────────────── // --
    AimbotRenderDistance        = 1000,
    GracePeriodEnabled          = false,
    GracePeriodMs               = 150,

    -- // ── Runtime Caches ─────────────────────────────────────── // --
    TargetFirstSeenTimestamps   = {},
    VisibilityCache             = {},
    VisibilityCacheTime         = {},
    SilentAimTargetCache        = nil,
    SilentAimTargetCacheTime    = 0,
    LastVisualList              = {},
    LastCustomTargetData    = nil,

    -- // ── ESP Visual Settings ────────────────────────────────── // --
    ESPRenderDistance           = 1000,
    ChamsEnabled                = false,
    ChamsOpacity                = 10,
    BoxModeEnabled              = false,
    SkeletonModeEnabled         = false,

    -- // ── v1.5.0 Visual Additions ────────────────────────────── // --
    SnaplinesEnabled            = false,
    SnaplineOrigin              = "Bottom",
    StreamProofESP              = true,
    OOFArrowsEnabled            = false,
    OOFArrowRadius              = 150,
    VisibilityColorsEnabled     = false,
    VisibleColor                = Color3.fromRGB(0, 255, 0),
    HiddenColor                 = Color3.fromRGB(255, 0, 0),

    -- // ── ESP Drawing Caches ─────────────────────────────────── // --
    SnaplineCache               = {},
    OOFArrowCache               = {},
    BoxCache                    = {},
    SkeletonCache               = {},
    HighlightCache              = {},
    TagCache                    = {},
    CachedNPCs                  = {},
    CachedWorkspaceIgnores      = {},

    -- // ── Drawing Objects ────────────────────────────────────── // --
    DrawingsReady               = false,
    FOVCircle                   = nil,
    CrosshairElements           = {
        Dot    = nil,
        Top    = nil,
        Bottom = nil,
        Left   = nil,
        Right  = nil,
        Square = nil,
        Circle = nil,
    },

    -- // ── Script Meta ────────────────────────────────────────── // --
    AimbotKeybind               = "E",
    PanicKeybind                = "Delete",
    ScriptInitialized           = false,
    DisableNotifications        = false,
    PresetFileName              = "TASFF_V1.5.5_Presets.json",
    ToolBlacklistFileName       = "TASFF_ToolBlacklist.json",
    CurrentVersion              = "2.1.0",

    -- // ── Session Statistics (v2.1.0) ─────────────────────────── // --
    SessionStartTime            = 0,
    SessionTargetLocks          = 0,
    SessionTriggerFires         = 0,
    SessionThreatsAdded         = 0,
    SessionNemesesAdded         = 0,

    -- // ── v2.1.0 Feature Flags ─────────────────────────────────── // --
    HideBlacklistedESP          = false,     -- false = show [BLACKLISTED] tag; true = fully hide
    IntelligentEquipFilter      = true,      -- use keyword classifier before auto-enabling aimbot
    WeaponTypeGating            = true,      -- gate triggerbot/melee by classified weapon type
    DashboardCategory           = "Combat",  -- home tab status panel active tab
    LockHistory                 = {},        -- circular buffer [{name,time}], max 5 entries

    -- // ── Performance Engine (v2.1.0 Pipeline) ────────────────── // --
    PerformanceMode             = "Medium",
    PerformanceModes            = {"Ultra High", "High", "Medium", "Low", "Ultra Low"},

    -- Legacy tables kept for UI backward compat (updated in v2.2.0)
    PerformanceIntervals        = {["Ultra High"]=1, ["High"]=2, ["Medium"]=3, ["Low"]=5, ["Ultra Low"]=10},
    NPCIntervals                = {["Ultra High"]=2, ["High"]=3, ["Medium"]=5, ["Low"]=8, ["Ultra Low"]=12},
    SweepIntervals              = {["Ultra High"]=1, ["High"]=2, ["Medium"]=3, ["Low"]=5, ["Ultra Low"]=8},
    CacheIntervals              = {["Ultra High"]=15,["High"]=20,["Medium"]=30,["Low"]=45,["Ultra Low"]=60},
    FrameCounters               = {HeavySystems=0, NPCs=0, WorkspaceSweep=0, CacheCleanup=0},

    -- v2.1.0 Pipeline: one scanning slot per frame, rest frames between slots
    PipelineSlot                = 0,
    PipelineRestCount           = 0,
    PipelineRestFrames          = {["Ultra High"]=0, ["High"]=1, ["Medium"]=2, ["Low"]=4, ["Ultra Low"]=7},

    -- v2.1.0 Background task intervals (seconds) — replaces frame-counter loops
    BackgroundIntervals = {
        ["Ultra High"] = { NPC=0.3,  Sweep=0.2,  Cache=3  },
        ["High"]       = { NPC=0.5,  Sweep=0.4,  Cache=5  },
        ["Medium"]     = { NPC=0.8,  Sweep=0.6,  Cache=8  },
        ["Low"]        = { NPC=1.2,  Sweep=1.0,  Cache=12 },
        ["Ultra Low"]  = { NPC=2.0,  Sweep=1.5,  Cache=20 },
    },

    -- Aimbot candidate cache: written by pipeline Slot 1, sorted every frame
    AimbotCandidates            = {},



    -- // ── Calibration ────────────────────────────────────────── // --
    AimReferenceMode            = "Screen Center",
    ManualCalibrationEnabled    = false,
    CalibrationOffsetX          = 0,
    CalibrationOffsetY          = 0,

    -- // ── Presets ────────────────────────────────────────────── // --
    SavedPresets                = {},
    SelectedPresetToManage      = "",

    -- // ── Static Joint Data (shared by DrawSkeleton) ─────────── // --
    R15Joints = {
        {"Head","UpperTorso"},
        {"UpperTorso","LowerTorso"},
        {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
        {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
        {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
        {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    },
    R6Joints = {
        {"Head","Torso"},
        {"Torso","Left Arm"},
        {"Torso","Right Arm"},
        {"Torso","Left Leg"},
        {"Torso","Right Leg"},
    },

    -- // ── Tool Observer Connection Handles ───────────────────── // --
    ToolAddedConnection         = nil,
    ToolRemovedConnection       = nil,

    -- // ── UI Element References (set by TASFF_UI.lua) ────────── // --
    PriorityDropdownRef         = nil,
    PriorityMonitorLabel        = nil,
    IntelMonitorLabel           = nil,   -- unified Intel Monitor paragraph ref
    PerformanceIndicator        = nil,

    -- // ── Cross-Chunk Function Slots (set by Core / UI) ──────── // --
    TriggerPanic                = nil,
    UnloadScript                = nil,
    ClearVisuals                = nil,
    ClearCrosshair              = nil,
    SyncPriorityUI              = nil,
    AddToIntel                  = nil,   -- function(name, source, extraPoints)
    RemoveFromIntel             = nil,   -- function(name, forceRemoveNemesis)
    RebuildIntelMonitor         = nil,   -- function() rebuilds the paragraph text
    GetIntelSortedList          = nil,
    SyncSpectatorUI             = nil,   -- function(state) updates UI toggle if core forces it off
    SetADSState                 = nil,
    GetPlayerNames              = nil,
    HandleClickToMark           = nil,
    UpdateWorkspaceIgnores      = nil,
    IsVisibleWallcheck          = nil,
    IsVisibleCachedWrapper      = nil,
    NewDrawing                  = nil,
    PrepareDrawing              = nil,
    EnsureDrawings              = nil,
    Notify                      = nil,
    GetIgnoreList               = nil,
    GetAimPosition              = nil,
    ApplyScreenCalibration      = nil,
    GetPotentialTargets         = nil,
    CleanupCaches               = nil,
    UpdateNPCs                  = nil,
    ShouldRunSubsystem          = nil,
    NormalizePerformanceMode    = nil,
    GetVisualAssets             = nil,
    DrawSkeleton                = nil,
    LoadPresetsFromFile         = nil,
    SavePresetsToFile           = nil,

    -- // ── v2.1.0 Function Slots (set by TASFF_Lists.lua) ──────── // --
    ClassifyTool                = nil,   -- ClassifyTool(name) → "Weapon"|"Melee"|"NonWeapon"|"Unknown"
    IsRangedWeapon              = nil,
    IsMeleeWeapon               = nil,
    IsNonWeapon                 = nil,
    FeatureCount                = 0,     -- populated by TASFF_Lists.lua on load
    PresetGameConfigs           = {},    -- populated by TASFF_Lists.lua on load
}


print("[TASFF State] Shared state table initialised.")
