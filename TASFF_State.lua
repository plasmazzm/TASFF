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
    Mode                        = "Legit (Camera)",
    Smoothness                  = 1.5,
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
    StrictPrioritize            = false,

    -- // ── Threat System ──────────────────────────────────────── // --
    ThreatDetectorEnabled       = false,
    ThreatMemory                = {},
    ThreatTimeout               = 10,
    BlacklistExpiredThreats     = false,
    NemesisEnabled              = true,
    NemesisMemory               = {},

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
    LastCustomTargetPosition    = nil,

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

    -- // ── Performance Engine ─────────────────────────────────── // --
    PerformanceMode             = "Medium",
    PerformanceModes            = {"Ultra High", "High", "Medium", "Low", "Ultra Low"},
    PerformanceIntervals        = {["Ultra High"]=1, ["High"]=2, ["Medium"]=3, ["Low"]=5, ["Ultra Low"]=10},
    NPCIntervals                = {["Ultra High"]=2, ["High"]=3, ["Medium"]=5, ["Low"]=8, ["Ultra Low"]=12},
    SweepIntervals              = {["Ultra High"]=1, ["High"]=2, ["Medium"]=3, ["Low"]=5, ["Ultra Low"]=8},
    CacheIntervals              = {["Ultra High"]=15,["High"]=20,["Medium"]=30,["Low"]=45,["Ultra Low"]=60},
    FrameCounters               = {HeavySystems=0, NPCs=0, WorkspaceSweep=0, CacheCleanup=0},

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
    -- These are nil at init. TASFF_UI.lua assigns them after
    -- creating the Rayfield elements so Core can update them.
    PriorityDropdownRef         = nil,
    PriorityMonitorLabel        = nil,
    PerformanceIndicator        = nil,  -- for Factory Reset flash

    -- // ── Cross-Chunk Function Slots (set by Core / UI) ──────── // --
    -- Core sets these after defining each function so UI callbacks
    -- can call them without creating a circular dependency.
    TriggerPanic                = nil,
    UnloadScript                = nil,
    ClearVisuals                = nil,
    ClearCrosshair              = nil,
    SyncPriorityUI              = nil,
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
}

print("[TASFF State] Shared state table initialised.")
