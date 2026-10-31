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
    DynamicFOVEnabled           = false,
    DynamicFOVMax                = 400,
    TargetPart                  = "Head",
    VOSPriorityParts            = {"Head", "Torso"}, -- parts to prefer first in VoS scan
    Mode                        = "Legit (Camera)",
    Smoothness                  = 1.5,           -- used by Legit (Camera) and as fallback
    SmoothnessX                 = 1.5,           -- horizontal smoothness for Advanced Legit (Mouse)
    SmoothnessY                 = 1.5,           -- vertical smoothness for Advanced Legit (Mouse)
    BlatantSnapSpeed            = 100,           -- 100 = instant snap; <100 = lerp fraction
    PredictionAmount            = 0.16,
    DistancePredictionAdjustEnabled = false,
    MaxAutoPrediction           = 0.45,

    -- // ── v2.2.5 Humanized Legit Aim Engine ────────────────────── // --
    HumanizedAimEnabled         = true,          -- master switch for natural human-like aiming dynamics
    AimPathCurvature            = 0.45,         -- wrist/arm arc curvature (0 = straight line, 1.0 = organic arc)
    AimDeadzoneRadius           = 6,            -- pixel deadzone slack: relaxes lock when already on target
    HumanTremorEnabled          = true,          -- organic physiological muscle tremor & breathing sway
    HumanTremorIntensity       = 0.6,          -- tremor intensity scale (0.1 to 2.0)
    TargetInertiaTracking       = true,          -- reaction inertia: dampens impossible 0ms strafe reaction snaps
    TargetReactionRate          = 14,           -- reaction rate speed (lower = more human inertia, higher = faster response)
    HitboxOffsetDrift           = true,          -- wanders smoothly within hitbox boundary instead of locking center point
    CoverAnticipationEnabled    = true,          -- maintains aim on target's cover point like a human expecting a peek
    CoverAnticipationDuration   = 0.8,           -- seconds to hold pre-aim on cover before gracefully releasing

    -- // ── v1.5.0 Combat Upgrades ─────────────────────────────── // --
    TargetSwitchDelayEnabled    = false,
    SwitchDelayMs               = 200,
    LastTargetLostTime          = 0,
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
    ThreatFPCooldown            = 1.5,           -- false-positive cooldown between threat detections (seconds)
    ThreatProximityRadius       = 80,            -- studs radius used by proximity-based threat scanner
    BlacklistExpiredThreats     = false,
    NemesisEnabled              = true,
    NemesisMemory               = {},

    -- // -- Intel System (v2.0.5) ------------------------------------ // --
    IntelPlayers                = {},
    IntelSelected               = "",
    PriorityBehavior            = "Boost",
    ThreatNeutralizationEnabled = false,
    IgnoreThreatVictims         = true,          -- if true, killing a threat/intel target does NOT count towards the killer's threat/nemesis triggers
    AutoExpireOnDisconnect      = false,
    DeepThreatScanEnabled       = true,
    StatCorrelatorEnabled       = true,
    OtherPlayersDamageTracking  = true,          -- tracks non-lethal damage between any players; flags aggressors as Threats
    ExpertInstinctsEnabled      = false,         -- instant counter-snap and target lock when attacked
    ExpertInstinctsIntensity    = 60,            -- 0=very smooth, 100=instant snap (see InstinctsMode)
    InstinctsMode               = "Blatant",     -- "Blatant" = direct CFrame snap/lerp; "Legit" = humanized smooth lerp (like aimbot)
    InstinctsInventoryCheck     = false,         -- scan inventory for defending weapons; suppress instincts if unarmed/fleeing
    InstinctsAutoEquip          = false,         -- auto-equips defending weapon on instincts trigger
    InstinctsFirstPersonCamera  = false,         -- forces camera into first person when instincts engages
    InstinctsBlacklist          = {},            -- list of tool names treated as non-weapons (ignored by instincts scan)
    InstinctsPrioritizedTools   = {},            -- list of tool names that immediately engage instincts
    InstinctsBlacklistFileName  = "TASFF_InstinctsBlacklist.json",
    InstinctsPriorityFileName   = "TASFF_InstinctsPriority.json",
    
    -- // -- Intel System Features (v2.0.5) --------------------------- // --
    KillCountThreatEnabled      = false,
    KillFeedEnabled             = false,
    KillsBeforeThreat           = 3,
    ContinuousKillsPermanent    = 5,             -- continuous kills required to make a threat permanent until neutralized
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
    TriggerbotPriorityOnly      = false,
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
    FoliageConcealmentCheck     = true,          -- prevents aiming through bushes, foliage, or opaque non-collidable cover

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
    OOFArrowsPriorityOnly       = false,         -- if true, OOF arrows only render for priority/intel targets
    OOFArrowRadius              = 150,
    EnvironmentalESPEnabled     = false,         -- highlights surrounding props and environment near players
    EnvironmentalESPPriorityOnly= false,         -- restricts environmental ESP to priority/intel targets only
    EnvironmentalESPRange       = 15,            -- radius around players to highlight environment
    EnvironmentalESPDistanceFade= false,         -- dynamic fade: parts fade to invisible as distance reaches max range
    EnvironmentalESPColor       = Color3.fromRGB(0, 200, 255),
    EnvironmentalESPTransparency= 0.95,          -- baseline transparency (0.95 = 95% invisible chams fill)
    EnvironmentalESPAutoScaling = true,          -- dynamically scales max parts pool based on active Performance Mode
    EnvironmentalESPMaxParts    = 160,           -- maximum parts/adornments limit (configurable 20-500)
    EnvironmentalESPScaleTable  = {
        ["Ultra High"] = 400,
        ["High"]       = 260,
        ["Medium"]     = 160,
        ["Low"]        = 90,
        ["Ultra Low"]  = 45,
    },
    EnvironmentalESPAdornments  = {},            -- runtime pool of adornment objects
    HighlightColor              = Color3.fromRGB(240, 240, 240),
    FOVColor                    = Color3.fromRGB(240, 240, 240),
    CrosshairColor              = Color3.fromRGB(240, 240, 240),
    SnaplineColor               = Color3.fromRGB(200, 200, 200),
    VisibilityColorsEnabled     = false,
    VisibleColor                = Color3.fromRGB(80, 220, 120),
    HiddenColor                 = Color3.fromRGB(220, 60, 80),
    BlacklistedTagColor         = Color3.fromRGB(255, 160, 60),   -- amber
    PriorityHighlightColor      = Color3.fromRGB(255, 75, 75),    -- marked
    ThreatHighlightColor        = Color3.fromRGB(255, 120, 60),   -- threat
    NemesisHighlightColor       = Color3.fromRGB(180, 100, 255),  -- nemesis
    KillFlashColor              = Color3.fromRGB(255, 255, 255),  -- white flash on kill
    KillFlashDuration           = 0.8,                            -- seconds for flash to fade
    KillConfirmFlashEnabled     = false,                          -- enable kill-confirmation screen flash
    ShowLockIndicators          = false,                          -- show [LOCKED]/[SILENT] tag on ESP info-tag
    OOFArrowColor               = Color3.fromRGB(200, 200, 200),
    ChamsColor                  = Color3.fromRGB(180, 180, 180),
    BoxColor                    = Color3.fromRGB(200, 200, 200),
    SkeletonColor               = Color3.fromRGB(200, 200, 200),

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
    MenuToggleKey               = "K", -- default Rayfield toggle keybind (avoids conflict with RightShift)
    MasterSwitchKeybind         = "RightShift", -- keybind to toggle master switch on/off
    AimbotKeybind               = "E",
    PanicKeybind                = "Delete",
    PanicLocked                 = false,     -- set true by TriggerPanic; only cleared by re-exec
    RapidModeCycleEnabled       = false,     -- rapid aim mode cycle toggle
    RapidModeCycleKey           = "P",       -- Feature 17: cycles aim mode on press
    QuickPresetSwitchEnabled    = false,     -- rapid profile/preset switching toggle
    QuickPresetSwitchKey        = "J",       -- keybind to cycle saved profiles/presets
    ActivePresetName            = "",        -- currently active profile/preset name
    ScriptInitialized           = false,
    DisableNotifications        = false,
    NotificationDuration        = 3,     -- global notification duration override (seconds)
    NotifyMaxPer3s              = 5,     -- max notifications shown per 3-second window (throttle)
    SuppressRayfieldAds         = false, -- hide Rayfield periodic ad notifications
    AntiAFKEnabled              = false, -- anti-AFK auto-jump to prevent idle kick
    FPSWatcherEnabled           = false, -- auto-tune PerformanceMode based on live FPS
    _LoadingPreset              = false, -- true while preset data is applying; silences noisy UI callback notifications
    _CurrentActiveTab           = "Home",-- tracks active Rayfield tab to prevent container overlap
    _PrevCameraMode             = nil,   -- restores previous camera mode after Expert Instincts expires
    DebugMode                   = false,     -- Feature 27: verbose console output
    PresetFileName              = "TASFF_V1.5.5_Presets.json",
    ColorSettingsFileName       = "TASFF_ColorSettings.json",
    ToolBlacklistFileName       = "TASFF_ToolBlacklist.json",
    CurrentVersion              = "2.3.0",
    AutoUpdateCheckerEnabled    = true,      -- automatically check repository for updates
    UpdateAvailable             = false,     -- set true when a newer version or commit is detected
    RemoteVersion               = nil,       -- remote version string if detected
    _SessionBaselineCommitSHA   = nil,       -- baseline commit SHA of current running session
    UpdateCheckInterval         = 180,       -- periodic check interval in seconds (3 minutes)

    -- // ── Key System (v2.3.0) ──────────────────────────────────── // --
    -- KeyStatus: "none" | "verifying" | "valid" | "invalid"
    TASFFKey                    = "",        -- stored key string
    KeyStatus                   = "none",   -- current verification state
    KeyVerified                 = false,    -- true when key is confirmed valid
    KeyFileName                 = "TASFF_Key.dat", -- file to persist key across sessions

    -- // ── Session Statistics (v2.1.0) ─────────────────────────── // --
    SessionStartTime            = 0,
    SessionTargetLocks          = 0,
    SessionTriggerFires         = 0,
    SessionThreatsAdded         = 0,
    SessionNemesesAdded         = 0,
    SessionUserKills            = 0,     -- kills where local player was confirmed killer

    -- // ── Intel Kill Tracking ─────────────────────────────────── // --
    PriorityPlayerKills         = {},    -- {[playerName] = killCount} for priority/intel players

    -- // ── v2.1.0 Feature Flags ─────────────────────────────────── // --
    HideBlacklistedESP          = false,     -- false = show [BLACKLISTED] tag; true = fully hide
    ESPWhitelistEnabled         = false,     -- when true: only ESP-render players in the whitelist
    AutoDisableOnDeath          = false,     -- auto-disable aimbot toggle when local player dies
    HealthThresholdEnabled      = false,     -- skip targets below a minimum HP percentage
    HealthThreshold             = 0,         -- minimum HP percentage threshold (0 = disabled)
    IntelligentEquipFilter      = true,      -- use keyword classifier before auto-enabling aimbot
    WeaponTypeGating            = true,      -- gate triggerbot/melee by classified weapon type
    DashboardCategory           = "Combat",  -- home tab status panel active tab
    LockHistory                 = {},        -- circular buffer [{name,time}], max 5 entries

    -- // ── Screen Recording Cloaking System (v2.2.0) ───────────────── // --
    -- Visuals listed here are redirected from Drawing/Highlight/ScreenGui
    -- to BillboardGui/SurfaceGui, which Roblox's recording system does not capture.
    -- Keys match the dropdown options defined in the System tab UI.
    HiddenFromRecording         = {},        -- set: { ["Crosshair"]=true, ["FOV Circle"]=true, ... }
    RecordingCloakEnabled       = true,      -- master gate; false = cloak has no effect

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

    -- v2.1.0 Visibility precompute: written by background loop ③, read by GetPotentialTargets
    -- Key = character model, Value = bool. Eliminates raycasts from the render thread entirely.
    VisibilityPrecomputed       = {},


    -- // ── Calibration ────────────────────────────────────────── // --
    AimReferenceMode            = "Screen Center",
    ManualCalibrationEnabled    = false,
    CalibrationOffsetX          = 0,
    CalibrationOffsetY          = 0,

    -- // ── Overlay & Interface Modifiers (v2.3.0+) ─────────────── // --
    HUDStripEnabled             = true,      -- persistent HUD strip at top of screen
    RadarEnabled                = false,     -- threat radar mini-map overlay
    SidebarEnabled              = true,      -- notification history feed
    KeyboardNavEnabled          = true,      -- keyboard navigation (arrows/enter)
    CompactModeEnabled          = false,     -- compact UI mode
    MobileModeEnabled           = false,     -- mobile touch mode
    UIOpacity                   = 1.0,       -- window opacity (0.3 to 1.0)
    EventLog                    = {},        -- session event log entries
    LastTouchedDef              = "Master Switch",
    LastTouchedDefText          = "Global killswitch for all combat systems.",
    ThemeBadgeCounts            = {},
    DynamicFOVEnabled           = false,
    DynamicFOVMax               = 400,
    HealthThresholdEnabled      = false,
    HealthThreshold             = 0,
    SmoothnessX                 = 0.1,
    SmoothnessY                 = 0.1,
    BlatantSnapSpeed            = 15,

    -- // ── Modern Suite Additions (v2.3.0+) ───────────────────── // --
    AudioFeedbackEnabled        = true,      -- tactile UI click / toggle sound effects
    AudioFeedbackVolume         = 0.5,       -- volume scale (0.0 to 1.0)
    TargetCardEnabled           = true,      -- floating target inspection hologram card
    CompactHUDEnabled           = false,     -- compact floating pill when main UI is closed
    KeystrokesEnabled           = false,     -- live combat keystroke visualizer widget
    SparklineGraphEnabled       = true,      -- real-time FPS/ping sparkline in HUD strip
    LiveFOVPulseEnabled         = true,      -- temporary FOV pulse while dragging slider
    HUDStripPosX                = nil,       -- custom draggable X offset
    HUDStripPosY                = nil,       -- custom draggable Y offset
    RadarPosX                   = nil,       -- custom draggable radar X offset
    RadarPosY                   = nil,       -- custom draggable radar Y offset
    TargetCardPosX              = nil,
    TargetCardPosY              = nil,
    KeystrokesPosX              = nil,
    KeystrokesPosY              = nil,
    CompactHUDPosX              = nil,
    CompactHUDPosY              = nil,
    NotificationDrawerOpen      = false,
    NotificationHistory         = {},        -- persistent notification drawer entries
    SessionStartTime            = tick(),
    SessionTargetsNeutralized   = 0,
    SessionTotalLockTime        = 0,

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
    ToggleMasterSwitch          = nil,   -- function(forcedState) toggles master switch
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
    RestartScript               = nil,

    -- // ── v2.1.0 Function Slots (set by TASFF_Lists.lua) ──────── // --
    ClassifyTool                = nil,   -- ClassifyTool(name) → "Weapon"|"Melee"|"NonWeapon"|"Unknown"
    IsRangedWeapon              = nil,
    IsMeleeWeapon               = nil,
    IsNonWeapon                 = nil,
    FeatureCount                = 0,     -- populated by TASFF_Lists.lua on load
    StatusDisplayCount          = 6,     -- populated by TASFF_Lists.lua on load
}


print("[TASFF State] Shared state table initialised.")
