-- // ============================================================ // --
-- //   TASFF_UI.lua                                             // --
-- //   Rayfield UI — structure identical to the original        // --
-- //   monolith. Callbacks write to _G.TASFF_State (S).        // --
-- //   Must be loaded AFTER TASFF_Core.lua.                    // --
-- // ============================================================ // --

local S           = _G.TASFF_State
local TASFFEnv     = (getgenv and getgenv().TASFF) or nil
if not TASFFEnv or not TASFFEnv.Rayfield then
    warn("[TASFF UI] Rayfield not ready — UI skipped.")
    return
end

local digitMap = {
    ["0"] = "Zero", ["1"] = "One", ["2"] = "Two", ["3"] = "Three", ["4"] = "Four",
    ["5"] = "Five", ["6"] = "Six", ["7"] = "Seven", ["8"] = "Eight", ["9"] = "Nine"
}

local function SanitizeKeyName(k)
    if type(k) == "string" and k ~= "" then
        local cleaned = k:gsub("Enum%.KeyCode%.", "")
        return digitMap[cleaned] or cleaned
    elseif typeof(k) == "EnumItem" then
        return k.Name
    end
    return nil
end

local function UnpackOption(v, fallback)
    if type(v) == "table" then
        if v[1] ~= nil and v[1] ~= "" then return v[1] end
        for _, val in pairs(v) do
            if type(val) == "string" and val ~= "" then return val end
        end
        return fallback
    elseif type(v) == "string" and v ~= "" then
        return v
    end
    return fallback
end

-- // -- Theme Module Wiring ------------------------------------  // --
local TASFFTheme = TASFFEnv.Theme or {}

-- KeyName(str): Prefixes key-gated feature names with a lock emoji.
-- In open-source builds, KeyVerified is always false, so all gated
-- controls will display the lock prefix. In the key build this is
-- identical behavior — the UI just shows the name once verified.
local function KeyName(name)
    return "🔒 " .. name
end

-- Forward-declared references populated in their respective sections
local Rayfield    = TASFFEnv.Rayfield
local Players     = game:GetService("Players")
local Player      = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

-- // ------------------------------------------------------------ // --
-- //                       UI-Local Variables
-- // ------------------------------------------------------------ // --

local SelectedPresetToManage = ""
local SelectedBlacklistTool  = ""
local BlacklistDropdown      = nil   -- tool weapons registry dropdown
local PriorityDropdownRef    = nil   -- priority players dropdown
local PresetDropdownRef      = nil   -- saved profiles dropdown
local PerformanceIndicator   = nil   -- paragraph element ref
local PriorityMonitorLabel   = nil   -- paragraph element ref
local ThreatListLabel        = nil   -- paragraph element ref
local PresetInputName        = ""
local UpdatePresetStatusDisplay  -- forward declaration (defined in Presets section below)

-- // ------------------------------------------------------------ // --
-- //                       Theming Color Map
-- // ------------------------------------------------------------ // --

-- Color/theme data sourced from TASFF_Theme.lua (reduces UI file size)
local ColorPresetMap       = TASFFTheme.ColorPresetMap       or {}
local ColorDropdownOptions = TASFFTheme.ColorDropdownOptions  or {}
local GlobalThemeOptions   = TASFFTheme.GlobalThemeOptions    or {"Default"}
local GlobalThemePalettes  = TASFFTheme.GlobalThemePalettes   or {}
local GlobalThemeColorNames= TASFFTheme.GlobalThemeColorNames or {}
local GlobalThemeColorFields=TASFFTheme.GlobalThemeColorFields or {}
local PersistedColorValues = {}
local selectedGlobalTheme  = "Default"

local ColorFields = {
    "HighlightColor",
    "FOVColor",
    "CrosshairColor",
    "BoxColor",
    "SkeletonColor",
    "SnaplineColor",
    "OOFArrowColor",
    "PriorityHighlightColor",
    "ThreatHighlightColor",
    "NemesisHighlightColor",
    "BlacklistedTagColor",
    "ChamsColor",
    "KillFlashColor",
    "VisibleColor",
    "HiddenColor",
    "EnvironmentalESPColor",
}

local ColorFlagMap = {
    HighlightColor         = "HighlightColorPicker",
    FOVColor               = "FOVCircleColorPicker",
    CrosshairColor         = "CrosshairColorPicker",
    BoxColor               = "BoxESPColorPicker",
    SkeletonColor          = "SkeletonESPColorPicker",
    SnaplineColor          = "SnaplineFineColorPicker",
    OOFArrowColor          = "OOFArrowColorPicker",
    PriorityHighlightColor = "PriorityHighlightColorPicker",
    ThreatHighlightColor   = "ThreatHighlightColorPicker",
    NemesisHighlightColor  = "NemesisHighlightColorPicker",
    BlacklistedTagColor    = "BlacklistedTagColorPicker",
    ChamsColor             = "ChamsColorPicker",
    KillFlashColor         = "KillFlashColorPicker",
    VisibleColor           = "VisibleColorPicker",
    HiddenColor            = "HiddenColorPicker",
    EnvironmentalESPColor  = "EnvironmentalESPColorPicker",
}

-- ThemeColorDefaults: fallback if Theme module unavailable
local ThemeColorDefaults = (TASFFTheme and TASFFTheme.Defaults) or {Background=Color3.fromRGB(15,15,15),Topbar=Color3.fromRGB(20,20,20),TabBackgroundSelected=Color3.fromRGB(60,60,60),ElementBackground=Color3.fromRGB(28,28,28),TextColor=Color3.fromRGB(240,240,240)}

local ThemeColors = (TASFFTheme.Defaults and table.clone(TASFFTheme.Defaults)) or table.clone(ThemeColorDefaults)
if TASFFTheme then TASFFTheme.ActiveThemeColors = ThemeColors end

local function DecodeColor(value)
    if type(value) ~= "table" then return nil end
    local r, g, b = tonumber(value[1]), tonumber(value[2]), tonumber(value[3])
    if not r or not g or not b or r ~= r or g ~= g or b ~= b then return nil end
    if r < 0 or r > 255 or g < 0 or g > 255 or b < 0 or b > 255 then return nil end
    return Color3.fromRGB(math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5))
end

local function EncodeColor(color)
    return {
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5),
    }
end

local function LoadColorSettings()
    local capabilities = TASFFEnv.Capabilities or {}
    if not (capabilities.FileRead and capabilities.FileWrite) then
        warn("[TASFF UI] Color settings will not persist: executor filesystem read/write APIs are unavailable.")
        return
    end
    local fileName = S.ColorSettingsFileName or "TASFF_ColorSettings.json"
    if not isfile(fileName) then return end
    local ok, result = pcall(function()
        return HttpService:JSONDecode(readfile(fileName))
    end)
    if not ok or type(result) ~= "table" then
        warn("[TASFF UI] Ignoring invalid color settings file: " .. tostring(result))
        return
    end
    for _, field in ipairs(ColorFields) do
        local color = DecodeColor(result[field])
        if color then
            S[field] = color
            PersistedColorValues[field] = color
        end
    end
    if type(result.GlobalTheme) == "string" and table.find(GlobalThemeOptions, result.GlobalTheme) then
        selectedGlobalTheme = result.GlobalTheme
    end
    if type(result.Theme) == "table" then
        for field in pairs(ThemeColorDefaults) do
            local color = DecodeColor(result.Theme[field])
            ThemeColors[field] = color or ThemeColorDefaults[field]
            if color then PersistedColorValues["Theme." .. field] = color end
        end
    end
end

local function SaveColorSettings()
    local capabilities = TASFFEnv.Capabilities or {}
    if not (capabilities.FileRead and capabilities.FileWrite) then return false end
    local data = {Version = 1, Theme = {}}
    for _, field in ipairs(ColorFields) do
        local color = S[field]
        if typeof(color) == "Color3" then data[field] = EncodeColor(color) end
    end
    for field in pairs(ThemeColorDefaults) do
        data.Theme[field] = EncodeColor(ThemeColors[field])
    end
    data.GlobalTheme = selectedGlobalTheme
    local ok, err = pcall(function()
        writefile(S.ColorSettingsFileName or "TASFF_ColorSettings.json", HttpService:JSONEncode(data))
    end)
    if not ok then
        warn("[TASFF UI] Failed to save color settings: " .. tostring(err))
        return false
    end
    return true
end

local colorSaveGeneration = 0
local function ScheduleColorSettingsSave()
    if not ((TASFFEnv.Capabilities or {}).FileRead and (TASFFEnv.Capabilities or {}).FileWrite) then return end
    colorSaveGeneration = colorSaveGeneration + 1
    local generation = colorSaveGeneration
    task.delay(0.35, function()
        if generation == colorSaveGeneration then
            SaveColorSettings()
        end
    end)
end

local function SetColor(field, color)
    if not table.find(ColorFields, field) or typeof(color) ~= "Color3" then return end
    S[field] = color
    ScheduleColorSettingsSave()
end

LoadColorSettings()

-- Auto-load persisted key on startup
if (TASFFEnv.Capabilities or {}).FileRead then
    local kf = S.KeyFileName or "TASFF_Key.dat"
    pcall(function()
        if isfile(kf) then
            local ok, key = pcall(readfile, kf)
            if ok and type(key) == "string" and key ~= "" then
                S.TASFFKey = key
                if S.VerifyKey then S.KeyVerified = S.VerifyKey(key) end
            end
        end
    end)
end
local function GetPresetNamesList()
    local t = {}
    for k, _ in pairs(S.SavedPresets) do table.insert(t, k) end
    return #t > 0 and t or {"No Profiles Found"}
end

-- // ============================================================ // --
-- //                          WINDOW                              // --
-- // ============================================================ // --

local _windowCfg = (TASFFTheme.GetWindowConfig and TASFFTheme.GetWindowConfig(ThemeColors, selectedGlobalTheme))
    or nil  -- nil = fallback to the inline config below
local Window = Rayfield:CreateWindow(_windowCfg or {
    Name            = "TASFF 2.3.0 " .. selectedGlobalTheme,
    Icon            = 7488932264,
    LoadingTitle    = "The Aimbot Script Final Form",
    LoadingSubtitle = "by Plasmazzm",
    Theme = {
        TextColor                     = ThemeColors.TextColor,
        Background                    = ThemeColors.Background,
        Topbar                        = ThemeColors.Topbar,
        Shadow                        = Color3.fromRGB(10,  10,  10),
        NotificationBackground        = Color3.fromRGB(15,  15,  15),
        NotificationActionsBackground = Color3.fromRGB(35,  35,  35),
        TabBackground                 = Color3.fromRGB(25,  25,  25),
        TabStroke                     = ThemeColors.ElementBackground,
        TabBackgroundSelected         = ThemeColors.TabBackgroundSelected,
        TabTextColor                  = ThemeColors.TextColor,
        SelectedTabTextColor          = Color3.fromRGB(255, 255, 255),
        ElementBackground             = ThemeColors.ElementBackground,
        ElementBackgroundHover        = Color3.fromRGB(35,  35,  35),
        SecondaryElementBackground    = Color3.fromRGB(20,  20,  20),
        ElementStroke                 = Color3.fromRGB(40,  40,  40),
        SecondaryElementStroke        = Color3.fromRGB(35,  35,  35),
        SliderBackground              = ThemeColors.ElementBackground,
        SliderProgress                = ThemeColors.TabBackgroundSelected,
        SliderStroke                  = ThemeColors.TabBackgroundSelected,
        ToggleBackground              = ThemeColors.ElementBackground,
        ToggleEnabled                 = ThemeColors.TabBackgroundSelected,
        ToggleDisabled                = Color3.fromRGB(60,  60,  60),
        ToggleEnabledStroke           = ThemeColors.TabBackgroundSelected,
        ToggleDisabledStroke          = Color3.fromRGB(80,  80,  80),
        ToggleEnabledOuterStroke      = ThemeColors.TabBackgroundSelected,
        ToggleDisabledOuterStroke     = Color3.fromRGB(45,  45,  45),
        DropdownSelected              = ThemeColors.TabBackgroundSelected,
        DropdownUnselected            = Color3.fromRGB(25,  25,  25),
        InputBackground               = Color3.fromRGB(20,  20,  20),
        InputStroke                   = ThemeColors.TabBackgroundSelected,
        PlaceholderColor              = Color3.fromRGB(150, 150, 150),
    },
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "TASFF V2.3.0",
        FileName   = "Config_Place_" .. tostring(game.PlaceId or "Global")
    }
})


-- // ============================================================ // --
-- //                        1. COMBAT TAB                         // --
-- // ============================================================ // --

-- // ------------------------------------------------------------ // --
-- //                       HOME TAB
-- // ------------------------------------------------------------ // --

local HomeTab = Window:CreateTab("Home", "home")

HomeTab:CreateSection("Welcome")
HomeTab:CreateParagraph({
    Title   = "Operator: " .. (Player and Player.DisplayName or "Operator") .. " (@" .. (Player and Player.Name or "User") .. ")",
    Content = "Pipeline active: " .. tostring(S.FeatureCount > 0 and S.FeatureCount or 123) .. " features  |  Tier: " .. (S.KeyVerified and "Full Access (Key Active)" or "Free Tier") .. "  |  Engine: 4-Slot Pipeline"
})

HomeTab:CreateSection("Server Info")
local serverInfoLabel = HomeTab:CreateParagraph({
    Title   = "Game Server",
    Content = "Fetching server info..."
})
task.spawn(function()
    -- Fetch game name via MarketplaceService
    local gameName = tostring(game.PlaceId)
    pcall(function()
        local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        if info and info.Name then gameName = info.Name end
    end)
    -- Initial render
    local function refreshServerInfo()
        local playerCount = #Players:GetPlayers()
        local maxPlayers  = game:GetService("Players").MaxPlayers
        local serverId    = tostring(game.JobId):sub(1, 8)
        local region      = "Unknown"
        pcall(function()
            local rs = game:GetService("LocalizationService").RobloxLocaleId
            if rs and rs ~= "" then region = rs end
        end)
        pcall(function()
            serverInfoLabel:Set({
                Title   = "Game Server (" .. tostring(playerCount) .. "/" .. tostring(maxPlayers) .. " Players)",
                Content = string.format("%s  |  Place: %d  |  Server: %s", gameName, game.PlaceId, serverId)
            })
        end)
    end
    refreshServerInfo()
    -- Refresh player count every 10s
    while getgenv().TASFF and getgenv().TASFF.Running do
        task.wait(10)
        refreshServerInfo()
    end
end)

HomeTab:CreateSection("Quick Feature Status")
HomeTab:CreateParagraph({
    Title   = "Feature Overview",
    Content = "Active features are marked [V], inactive [X]. Select a category from the dropdown below."
})

local function BuildStatusContent(category)
    local on, off = {}, {}
    local function check(label, flag)
        if flag then table.insert(on, "  [V] " .. label)
        else table.insert(off, "  [X] " .. label) end
    end
    if category == "Combat" then
        check("Master Switch",          S.MasterEnabled)
        check("Aimbot Engine",          S.TargetingEnabled)
        check("Silent Aim",             S.SilentAimEnabled)
        check("Sticky Aim",             S.StickyAimEnabled)
        check("Dynamic Recoil (DRC)",   S.DynamicRecoilEnabled)
        check("Auto ADS",               S.AutoADSEnabled)
        check("Randomize Hitboxes",     S.RandomizeHitboxEnabled)
        check("Target Near Center",     S.TargetNearCenter)
        check("Target Switch Delay",    S.TargetSwitchDelayEnabled)
        check("Grace Period",           S.GracePeriodEnabled)
        check("Triggerbot",             S.AutoClickEnabled)
        check("Melee Mode",             S.MeleeModeEnabled)
        check("Distance Auto-Prediction", S.DistancePredictionAdjustEnabled)
    elseif category == "Visuals" then
        check("Highlights (Players)",   S.UseHighlight)
        check("Highlights (NPCs)",      S.UseNPCHighlight)
        check("Info Tags (Players)",    S.UseInfoTag)
        check("Info Tags (NPCs)",       S.UseNPCInfoTag)
        check("Snaplines",              S.SnaplinesEnabled)
        check("OOF Arrows",             S.OOFArrowsEnabled)
        check("OOF Arrows (Priority)",  S.OOFArrowsPriorityOnly)
        check("Box ESP",                S.BoxModeEnabled)
        check("Skeleton ESP",           S.SkeletonModeEnabled)
        check("Chams",                  S.ChamsEnabled)
        check("Visibility Colors",      S.VisibilityColorsEnabled)
        check("Show Display Name",      S.ShowDisplayName)
        check("Show Tool Check",        S.ShowToolCheck)
    elseif category == "Intel" then
        check("Threat Detector",        S.ThreatDetectorEnabled)
        check("Universal Damage Track", S.OtherPlayersDamageTracking)
        check("Expert Instincts",       S.ExpertInstinctsEnabled)
        check("Instincts Auto-Equip",   S.InstinctsAutoEquip)
        check("Instincts First-Person", S.InstinctsFirstPersonCamera)
        check("Nemesis System",         S.NemesisEnabled)
        check("Click-to-Mark",          S.ClickToMarkEnabled)
        check("Focus Mode ESP",         S.FocusMode)
        check("Wall Check",             S.WallCheck)
        check("Team Check",             S.TeamCheck)
        check("Target Players",         S.TargetPlayers)
        check("Target NPCs",            S.TargetNPCs)
        check("Ignore Threat Victims",  S.IgnoreThreatVictims)
    elseif category == "Automation" then
        check("Auto-Engage on Equip",   S.AutoEnableOnEquip)
        check("Intelligent Equip Filter", S.IntelligentEquipFilter)
        check("Weapon-Type Gating",     S.WeaponTypeGating)
        check("FOV Circle",             S.ShowFOV)
        check("Invisible FOV",          S.InvisibleFOV)
        check("Hide Blacklisted ESP",   S.HideBlacklistedESP)
    end
    local lines = {}
    if #on > 0 then
        table.insert(lines, "ENABLED"); for _, l in ipairs(on) do table.insert(lines, l) end
    end
    if #off > 0 then
        if #on > 0 then table.insert(lines, "") end
        table.insert(lines, "DISABLED"); for _, l in ipairs(off) do table.insert(lines, l) end
    end
    if #lines == 0 then return "No features in this category." end
    return table.concat(lines, "\n")
end

local DashboardParagraph = HomeTab:CreateParagraph({
    Title   = "Status — Combat",
    Content = BuildStatusContent("Combat")
})
S.DashboardParagraph = DashboardParagraph

HomeTab:CreateDropdown({
    Name          = "Status Category",
    Options       = {"Combat", "Visuals", "Intel", "Automation"},
    CurrentOption = {"Combat"},
    Flag          = "DashboardCategory",
    Callback      = function(v)
        local cat = v[1] or "Combat"
        S.DashboardCategory = cat
        if DashboardParagraph then
            pcall(function()
                DashboardParagraph:Set({Title = "Status — " .. cat, Content = BuildStatusContent(cat)})
            end)
        end
    end
})

HomeTab:CreateSection("Session Statistics")
local SessionStatsLabel = HomeTab:CreateParagraph({
    Title   = "Current Session",
    Content = "Locks: 0  |  Kills: 0  |  Fires: 0  |  Threats: 0  |  Nemeses: 0"
})
S.SessionStatsLabel = SessionStatsLabel

task.spawn(function()
    S.SessionStartTime = tick()
    task.wait(3)
    while getgenv().TASFF and getgenv().TASFF.Running do
        if SessionStatsLabel then
            pcall(function()
                local uptime = math.floor(tick() - (S.SessionStartTime or tick()))
                local mins, secs = math.floor(uptime / 60), uptime % 60
                SessionStatsLabel:Set({
                    Title   = "Current Session (up " .. mins .. "m " .. secs .. "s)",
                    Content = string.format(
                        "Target Locks: %d  |  Your Kills: %d  |  Trigger Fires: %d\nThreats: +%d  |  Nemeses: +%d",
                        S.SessionTargetLocks  or 0,
                        S.SessionUserKills    or 0,
                        S.SessionTriggerFires or 0,
                        S.SessionThreatsAdded or 0,
                        S.SessionNemesesAdded or 0
                    )
                })
            end)
        end
        task.wait(5)
    end
end)

-- ── Quick Actions ────────────────────────────────────────────────
HomeTab:CreateSection("Quick Actions")
HomeTab:CreateParagraph({
    Title   = "Operational Shortcuts",
    Content = "Instant administrative controls for reset, target clearing, and data synchronization."
})
HomeTab:CreateButton({
    Name = "Clear All Threats",
    Callback = function()
        S.ThreatPlayers = {}
        if S.Notify then S.Notify({Title="Quick Actions", Content="Threat list cleared.", Duration=2, Image="shield"}) end
        if S.LogEvent then S.LogEvent("Threat list reset.") end
    end
})
HomeTab:CreateButton({
    Name = "Reset Active Target",
    Callback = function()
        S.CurrentTarget = nil
        if S.Notify then S.Notify({Title="Quick Actions", Content="Active target released.", Duration=2, Image="crosshair"}) end
        if S.LogEvent then S.LogEvent("Target cleared manually.") end
    end
})
HomeTab:CreateButton({
    Name = "Refresh Player Registry",
    Callback = function()
        if S.GetPlayerNames then
            local n = S.GetPlayerNames()
            if S.PriorityDropdownRef and S.PriorityDropdownRef.Refresh then pcall(function() S.PriorityDropdownRef:Refresh(n, true) end) end
        end
        if S.Notify then S.Notify({Title="Quick Actions", Content="Player registry synchronized.", Duration=2, Image="users"}) end
        if S.LogEvent then S.LogEvent("Player list synchronized.") end
    end
})
HomeTab:CreateButton({
    Name = "Copy Session Summary",
    Callback = function()
        local stats = string.format("TASFF Session Summary:\nLocks: %d | Kills: %d | Fires: %d | Nemeses: %d",
            S.SessionTargetLocks or 0, S.SessionUserKills or 0, S.SessionTriggerFires or 0, S.SessionNemesesAdded or 0)
        pcall(function() if setclipboard then setclipboard(stats) end end)
        if S.Notify then S.Notify({Title="Quick Actions", Content="Stats copied to clipboard.", Duration=2, Image="clipboard"}) end
    end
})

-- ── Definitions Panel ────────────────────────────────────────────
HomeTab:CreateSection("Definitions & Glossary")
local DefinitionsParagraph = HomeTab:CreateParagraph({
    Title   = "Control Definition",
    Content = "Hover over or interact with any configuration control to view its detailed documentation here."
})
S.DefinitionsParagraph = DefinitionsParagraph

-- ── Session Event Log ────────────────────────────────────────────
HomeTab:CreateSection("Session Event Log")
local EventLogParagraph = HomeTab:CreateParagraph({
    Title   = "Recent Events (0)",
    Content = "No events logged yet."
})
S.EventLogParagraph = EventLogParagraph

S.LogEvent = function(msg)
    if not S.EventLog then S.EventLog = {} end
    local timeStr = os.date and os.date("%X") or tostring(math.floor(tick() % 1000))
    table.insert(S.EventLog, 1, string.format("[%s] %s", timeStr, tostring(msg)))
    if #S.EventLog > 8 then table.remove(S.EventLog, 9) end
    if S.EventLogParagraph and S.EventLogParagraph.Set then
        pcall(function()
            S.EventLogParagraph:Set({
                Title = "Recent Events (" .. #S.EventLog .. ")",
                Content = table.concat(S.EventLog, "\n")
            })
        end)
    end
    if TASFFEnv.Theme and TASFFEnv.Theme.PushSidebarNotification then
        pcall(function() TASFFEnv.Theme.PushSidebarNotification("TASFF Event", msg) end)
    end
end

-- // ------------------------------------------------------------ // --
-- //                       COMBAT TAB
-- // ------------------------------------------------------------ // --

local MainTab = Window:CreateTab("Combat", "crosshair")



local function ToggleMasterSwitch(forcedState)
    local newState = (forcedState ~= nil) and forcedState or (not S.MasterEnabled)
    if Rayfield and Rayfield.Flags and Rayfield.Flags["MasterSwitch"] and Rayfield.Flags["MasterSwitch"].Set then
        pcall(function()
            Rayfield.Flags["MasterSwitch"]:Set(newState)
        end)
    else
        S.MasterEnabled = newState
        if not newState then
            S.AimbotActive = false; S.CurrentTarget = nil; S.AimbotCandidates = {}
            if S.SetADSState    then S.SetADSState(false)  end
            if S.ClearVisuals   then S.ClearVisuals()      end
            if S.ClearCrosshair then S.ClearCrosshair()    end
            if S.FOVCircle      then S.FOVCircle.Visible = false end
        end
    end
    if S.Notify then
        S.Notify({
            Title    = "TASFF System",
            Content  = S.MasterEnabled and "Master Switch ENABLED" or "Master Switch DISABLED",
            Duration = 1.5,
            Image    = S.MasterEnabled and "power" or "power-off",
        })
    end
end
S.ToggleMasterSwitch = ToggleMasterSwitch

MainTab:CreateSection("Master Controls")
MainTab:CreateParagraph({
    Title   = "TASFF — The Aimbot Script Final Form",
    Content = "The definitive combat suite. Master Switch is the global killswitch — nothing runs while it's off. Aimbot Engine controls active target acquisition and tracking independently."
})
MainTab:CreateToggle({Name = "Master Switch", CurrentValue = S.MasterEnabled, Flag = "MasterSwitch", Callback = function(v)
    S.MasterEnabled = v
    if not v then
        S.AimbotActive = false; S.CurrentTarget = nil; S.AimbotCandidates = {}
        if S.SetADSState    then S.SetADSState(false)  end
        if S.ClearVisuals   then S.ClearVisuals()      end
        if S.ClearCrosshair then S.ClearCrosshair()    end
        if S.FOVCircle      then S.FOVCircle.Visible = false end
    end
end})
MainTab:CreateKeybind({
    Name           = "Master Switch Key",
    CurrentKeybind = S.MasterSwitchKeybind or "RightShift",
    HoldToInteract = false,
    CallOnChange   = true,
    Flag           = "MasterSwitchKeybind",
    Callback       = function(key)
        local validKey = SanitizeKeyName(key)
        if validKey then
            S.MasterSwitchKeybind = validKey
            if S.Notify then
                S.Notify({
                    Title    = "TASFF Keybind",
                    Content  = "Master Switch key set to [" .. tostring(validKey) .. "]",
                    Duration = 2,
                    Image    = "keyboard"
                })
            end
        end
    end
})
MainTab:CreateToggle({Name = "Aimbot Engine", CurrentValue = S.TargetingEnabled, Flag = "TargetSystemToggle", Callback = function(v)
    S.TargetingEnabled = v
    if not v then
        S.AimbotActive = false
        S.CurrentTarget = nil
        S.AimbotCandidates = {}
        S.SilentAimTargetCache = nil
        S.LastCustomTargetData = nil
    end
end})
MainTab:CreateDropdown({
    Name          = "Primary Aim Method",
    Options       = {"Legit (Camera)", "Advanced Legit (Mouse)", "Blatant", "Flickbot (Click-Teleport)"},
    CurrentOption = {S.Mode},
    Flag          = "AimMethod",
    Callback      = function(v)
        S.Mode = UnpackOption(v, "Legit (Camera)")
    end
})

MainTab:CreateSection("Activation")
MainTab:CreateParagraph({Title = "Activation", Content = "The Aimbot Activation Key holds the aimbot active while pressed. Auto-Engage activates on tool equip. Auto-ADS and Auto-Disable on Death handle lifecycle events."})
MainTab:CreateKeybind({
        Name            = "Activation Key",
        CurrentKeybind  = S.AimbotKeybind or "E",
        HoldToInteract  = false,
        CallOnChange    = true,
        Flag            = "AimbotKeybind",
        Callback        = function(key)
            local validKey = SanitizeKeyName(key)
            if validKey then
                S.AimbotKeybind = validKey
                if S.Notify then
                    S.Notify({
                        Title    = "TASFF Keybind",
                        Content  = "Aimbot key set to [" .. tostring(validKey) .. "]",
                        Duration = 2,
                        Image    = "keyboard"
                    })
                end
            end
        end
})
MainTab:CreateToggle({Name = "Auto-ADS", CurrentValue = S.AutoADSEnabled, Flag = "AutoADS", Callback = function(v)
    S.AutoADSEnabled = v
    if not v and S.SetADSState then S.SetADSState(false) end
end})
MainTab:CreateInput({
        Name = "Auto ADS Input Key (Text)",
        PlaceholderText = "e.g. MouseButton2, F",
        RemoveTextAfterFocusLost = false,
        Flag = "AutoADSKeyInput",
        Callback = function(text)
            if text and text ~= "" then S.AutoADSKeybind = text end
        end
    })

MainTab:CreateSection("Target Selection")
MainTab:CreateParagraph({
    Title   = "Target Selection",
    Content = "Controls which body part is locked onto and how targets are ranked. VOS (Visible On Screen) mode dynamically picks the most exposed limb.",
})
MainTab:CreateDropdown({
    Name          = "Primary Hitbox (Bodypart)",
    Options       = {"Head", "HumanoidRootPart", "Torso", "Visible On Screen"},
    CurrentOption = {S.TargetPart},
    Flag          = "TargetPart",
    Callback      = function(v)
        local opt = UnpackOption(v, "Head")
        S.TargetPart = opt
        S.ActivePartName = (opt ~= "Visible On Screen") and opt or "Head"
    end
})
MainTab:CreateSection("VOS Priority Parts")
MainTab:CreateParagraph({Title = "VOS Priority Parts", Content = "When Visible On Screen targeting is active, these body parts are prioritised in order. Falls back to any visible part if none match."})
MainTab:CreateDropdown({
    Name            = "VOS Priority Parts",
    Options         = {"Head", "Torso", "Right and Left Arm", "Leg"},
    CurrentOption   = (type(S.VOSPriorityParts) == "table" and #S.VOSPriorityParts > 0) and S.VOSPriorityParts or {"Head", "Torso"},
    MultipleOptions = true,
    Flag            = "VOSPriorityParts",
    Callback        = function(v)
        local selected = {}
        if type(v) == "table" then
            if #v > 0 then
                for _, name in ipairs(v) do
                    if type(name) == "string" and name ~= "" and not table.find(selected, name) then
                        table.insert(selected, name)
                    end
                end
            else
                for k, val in pairs(v) do
                    if type(val) == "boolean" and val then
                        if type(k) == "string" and k ~= "" and not table.find(selected, k) then
                            table.insert(selected, k)
                        end
                    elseif type(val) == "string" and val ~= "" and not table.find(selected, val) then
                        table.insert(selected, val)
                    end
                end
            end
        elseif type(v) == "string" and v ~= "" then
            table.insert(selected, v)
        end
        if #selected == 0 then
            selected = {"Head", "Torso"}
        end
        S.VOSPriorityParts = selected
    end
})
MainTab:CreateSection("Filters & Sorting")
MainTab:CreateParagraph({Title = "Filters & Sorting", Content = "Controls which targets are eligible and how they are ranked when multiple are in range."})
MainTab:CreateToggle({Name = "Randomize Hitbox", CurrentValue = S.RandomizeHitboxEnabled, Flag = "RandomizeHitbox", Callback = function(v)
    S.RandomizeHitboxEnabled = v
end})
MainTab:CreateDropdown({Name = "Sort by Distance", Options = {"None", "Closest", "Farthest"}, CurrentOption = {S.PriorityMode}, Flag = "PriorityMode", Callback = function(v)
    S.PriorityMode = UnpackOption(v, "None")
end})
MainTab:CreateDropdown({Name = "Sort by Health", Options = {"None", "Weakest (HP)", "Strongest (HP)"}, CurrentOption = {S.VitalityMode}, Flag = "VitalityMode", Callback = function(v)
    S.VitalityMode = UnpackOption(v, "None")
end})
MainTab:CreateToggle({Name = "Center-Screen Priority", CurrentValue = S.TargetNearCenter, Flag = "TargetNearCenter", Callback = function(v)
    S.TargetNearCenter = v
end})
MainTab:CreateSlider({Name = "Max Range (studs)", Range = {100, 1000}, Increment = 25, CurrentValue = S.AimbotRenderDistance, Flag = "AimbotRenderDist", Callback = function(v)
    S.AimbotRenderDistance = v
end})
MainTab:CreateToggle({Name = "Health Gate", CurrentValue = S.HealthThresholdEnabled, Flag = "HealthThresholdEnabled", Callback = function(v) S.HealthThresholdEnabled = v end})
MainTab:CreateSlider({Name = "Min Target HP (%)", Range = {0, 100}, Increment = 1, CurrentValue = S.HealthThreshold or 0, Flag = "HealthThreshold", Callback = function(v) S.HealthThreshold = v end})

MainTab:CreateSection("Smoothing")
MainTab:CreateParagraph({Title = "Smoothing & Prediction", Content = "Controls aim interpolation speed and trajectory prediction. Higher smoothness feels more natural but reacts slower. Humanized Aim adds deliberate imperfections to avoid spectator flags."})
MainTab:CreateSlider({Name = "Smoothness", Range = {0.1, 5}, Increment = 0.1, CurrentValue = S.Smoothness, Flag = "SmoothSpeed", Callback = function(v)
    S.Smoothness = v
end})
MainTab:CreateSlider({Name = "Mouse Smoothness X", Range = {0.1, 5}, Increment = 0.1, CurrentValue = S.SmoothnessX, Flag = "SmoothnessX", Callback = function(v)
    S.SmoothnessX = v
end})
MainTab:CreateSlider({Name = "Mouse Smoothness Y", Range = {0.1, 5}, Increment = 0.1, CurrentValue = S.SmoothnessY, Flag = "SmoothnessY", Callback = function(v)
    S.SmoothnessY = v
end})
MainTab:CreateSlider({Name = "Snap Speed", Range = {5, 100}, Increment = 5, CurrentValue = S.BlatantSnapSpeed, Flag = "BlatantSnapSpeed", Callback = function(v)
    S.BlatantSnapSpeed = v
end})
MainTab:CreateSlider({Name = "Prediction Intensity", Range = {0, 0.5}, Increment = 0.01, CurrentValue = S.PredictionAmount, Flag = "PredIntense", Callback = function(v)
    S.PredictionAmount = v
end})
MainTab:CreateToggle({Name = "Auto Prediction Adjust", CurrentValue = S.DistancePredictionAdjustEnabled, Flag = "DistancePredictionAdjustEnabled", Callback = function(v)
    S.DistancePredictionAdjustEnabled = v
end})
MainTab:CreateSlider({Name = "Max Auto Prediction", Range = {0.16, 1.0}, Increment = 0.01, CurrentValue = S.MaxAutoPrediction or 0.45, Flag = "MaxAutoPrediction", Callback = function(v)
    S.MaxAutoPrediction = v
end})
MainTab:CreateToggle({Name = "Dynamic Recoil", CurrentValue = S.DynamicRecoilEnabled, Flag = "DynamicRecoil", Callback = function(v)
    S.DynamicRecoilEnabled = v
end})
MainTab:CreateSection("[KEY] Humanized Aim")
MainTab:CreateParagraph({Title = "Humanized Aim Suite", Content = "Simulates natural human aim imperfections — path curvature, micro-tremor, target inertia, hitbox drift, and cover anticipation. Requires a TASFF Key. All sub-options only take effect when Humanized Aim is on."})
MainTab:CreateToggle({Name = KeyName("Humanized Aim"), CurrentValue = S.HumanizedAimEnabled, Flag = "HumanizedAim", Callback = function(v)
    S.HumanizedAimEnabled = v
end})
MainTab:CreateSlider({Name = KeyName("Aim Arc"), Range = {0, 1}, Increment = 0.05, CurrentValue = S.AimPathCurvature or 0.45, Flag = "AimCurvature", Callback = function(v)
    S.AimPathCurvature = v
end})
MainTab:CreateSlider({Name = KeyName("Aim Deadzone (px)"), Range = {0, 20}, Increment = 1, CurrentValue = S.AimDeadzoneRadius or 6, Flag = "AimDeadzone", Callback = function(v)
    S.AimDeadzoneRadius = v
end})
MainTab:CreateToggle({Name = KeyName("Hand Tremor"), CurrentValue = S.HumanTremorEnabled, Flag = "HumanTremor", Callback = function(v)
    S.HumanTremorEnabled = v
end})
MainTab:CreateSlider({Name = KeyName("Tremor Intensity"), Range = {0.1, 2}, Increment = 0.1, CurrentValue = S.HumanTremorIntensity or 0.6, Flag = "TremorIntensity", Callback = function(v)
    S.HumanTremorIntensity = v
end})
MainTab:CreateToggle({Name = KeyName("Target Inertia"), CurrentValue = S.TargetInertiaTracking, Flag = "TargetInertia", Callback = function(v)
    S.TargetInertiaTracking = v
end})
MainTab:CreateToggle({Name = KeyName("Hitbox Drift"), CurrentValue = S.HitboxOffsetDrift, Flag = "HitboxDrift", Callback = function(v)
    S.HitboxOffsetDrift = v
end})
MainTab:CreateToggle({Name = KeyName("Cover Anticipation"), CurrentValue = S.CoverAnticipationEnabled, Flag = "CoverAnticipationEnabled", Callback = function(v)
    S.CoverAnticipationEnabled = v
end})
MainTab:CreateSlider({Name = KeyName("Cover Hold (s)"), Range = {0.1, 3.0}, Increment = 0.1, CurrentValue = S.CoverAnticipationDuration or 0.8, Flag = "CoverAnticipationDuration", Callback = function(v)
    S.CoverAnticipationDuration = v
end})



MainTab:CreateSection("Engagement Logic")
MainTab:CreateParagraph({Title = "Engagement Logic", Content = "Fine-tunes how the aimbot holds and releases locks. Affects jitter, switch delay, and target retention duration."})
MainTab:CreateToggle({Name = "Silent Aim", CurrentValue = S.SilentAimEnabled, Flag = "SilentAimEnabled", Callback = function(v)
    S.SilentAimEnabled = v
    if not S._LoadingPreset and S.Notify then
        S.Notify({Title = "Silent Aim", Content = v and "Silent Aim enabled." or "Silent Aim disabled.", Duration = 2, Image = v and "crosshair" or "x"})
    end
end})
MainTab:CreateToggle({Name = "Sticky Aim", CurrentValue = S.StickyAimEnabled, Flag = "StickyAim", Callback = function(v)
    S.StickyAimEnabled = v
    if not v then S.CurrentTarget = nil end
end})
MainTab:CreateToggle({Name = "Switch Delay", CurrentValue = S.TargetSwitchDelayEnabled, Flag = "TargetSwitchDelay", Callback = function(v)
    S.TargetSwitchDelayEnabled = v
end})
MainTab:CreateSlider({Name = "Switch Delay (ms)", Range = {50, 1000}, Increment = 10, CurrentValue = S.SwitchDelayMs, Flag = "SwitchDelayMs", Callback = function(v)
    S.SwitchDelayMs = v
end})
MainTab:CreateToggle({Name = "Grace Period", CurrentValue = S.GracePeriodEnabled, Flag = "EnableGracePeriod", Callback = function(v)
    S.GracePeriodEnabled = v
end})
MainTab:CreateSlider({Name = "Grace Duration (ms)", Range = {1, 1000}, Increment = 1, CurrentValue = S.GracePeriodMs, Flag = "GracePeriodMs", Callback = function(v)
    S.GracePeriodMs = v
end})

-- // ============================================================ // --
-- //                       2. VISUALS TAB                         // --
-- // ============================================================ // --

local VisualTab = Window:CreateTab("Visuals", "eye")

VisualTab:CreateSection("ESP Configuration")
VisualTab:CreateParagraph({
    Title   = "Focus Mode & Visual Rendering",
    Content = "Focus Mode isolates visual clutter by only drawing ESP on Priority Targets. Screen overlay tags use PlayerGui and are visible to Roblox's built-in recording. 3D chams use Roblox Highlight instances and may also appear in recordings and capture software."
})
VisualTab:CreateDropdown({Name = "ESP Mode", Options = {"Single", "Multiple", "All"}, CurrentOption = {S.VisualMode}, Flag = "VisualMode", Callback = function(v)
    S.VisualMode = type(v) == "table" and v[1] or v
    if S.ClearVisuals then S.ClearVisuals() end
end})
VisualTab:CreateToggle({Name = "Player ESP", CurrentValue = S.UseHighlight, Flag = "UseHighlight", Callback = function(v) S.UseHighlight = v end})
VisualTab:CreateToggle({Name = "NPC ESP", CurrentValue = S.UseNPCHighlight, Flag = "UseNPCHighlight", Callback = function(v) S.UseNPCHighlight = v end})
VisualTab:CreateToggle({Name = "Focus Mode", CurrentValue = S.FocusMode, Flag = "FocusMode", Callback = function(v) S.FocusMode = v end})
VisualTab:CreateToggle({Name = "Info Tags", CurrentValue = S.StreamProofESP, Flag = "StreamProofESP", Callback = function(v)
    S.StreamProofESP = v
    if S.ClearVisuals then S.ClearVisuals() end
end})
VisualTab:CreateToggle({Name = "Visibility Colors", CurrentValue = S.VisibilityColorsEnabled, Flag = "VisibilityColorsEnabled", Callback = function(v)
    S.VisibilityColorsEnabled = v
end})
VisualTab:CreateSlider({Name = "ESP Range (studs)", Range = {100, 1000}, Increment = 25, CurrentValue = S.ESPRenderDistance, Flag = "ESPRenderDist", Callback = function(v)
    S.ESPRenderDistance = v
end})

VisualTab:CreateSection("Tactical Overlays")
VisualTab:CreateParagraph({Title = "Tactical Overlays", Content = "Geometric overlays drawn around targets in 2D or 3D space. Chams renders through walls. Box and Skeleton trace bodypart structure. Snaplines and OOF arrows track off-screen targets."})
VisualTab:CreateToggle({Name = "Chams", CurrentValue = S.ChamsEnabled, Flag = "EnableChamsMode", Callback = function(v) S.ChamsEnabled = v end})

VisualTab:CreateToggle({Name = "Box ESP", CurrentValue = S.BoxModeEnabled, Flag = "EnableBoxMode", Callback = function(v) S.BoxModeEnabled = v end})
VisualTab:CreateToggle({Name = "Skeleton ESP", CurrentValue = S.SkeletonModeEnabled, Flag = "EnableSkeletonMode", Callback = function(v) S.SkeletonModeEnabled = v end})
VisualTab:CreateToggle({Name = "Snaplines", CurrentValue = S.SnaplinesEnabled, Flag = "SnaplinesEnabled", Callback = function(v) S.SnaplinesEnabled = v end})
VisualTab:CreateDropdown({Name = "Snapline Origin Point", Options = {"Bottom", "Center"}, CurrentOption = {S.SnaplineOrigin}, Flag = "SnaplineOrigin", Callback = function(v)
    S.SnaplineOrigin = UnpackOption(v, "Bottom")
end})
VisualTab:CreateToggle({Name = "OOF Arrows", CurrentValue = S.OOFArrowsEnabled, Flag = "OOFArrowsEnabled", Callback = function(v) S.OOFArrowsEnabled = v end})
VisualTab:CreateSlider({Name = "OOF Radius", Range = {50, 400}, Increment = 10, CurrentValue = S.OOFArrowRadius, Flag = "OOFArrowRadius", Callback = function(v) S.OOFArrowRadius = v end})
VisualTab:CreateToggle({Name = "OOF — Priority Only", CurrentValue = S.OOFArrowsPriorityOnly, Flag = "OOFArrowsPriorityOnly", Callback = function(v) S.OOFArrowsPriorityOnly = v end})

VisualTab:CreateSection("[KEY] Environmental ESP")
VisualTab:CreateParagraph({
    Title   = "Environmental ESP",
    Content = "Dynamically highlights surrounding objects and terrain near players. Small props (tables, chairs, obstacles) are fully outlined, while large structures (floors, walls, ceilings) display a focused square slice directly around the player."
})
VisualTab:CreateToggle({Name = KeyName("Environmental ESP"), CurrentValue = S.EnvironmentalESPEnabled, Flag = "EnvironmentalESPEnabled", Callback = function(v)
    S.EnvironmentalESPEnabled = v
    if not v and S.ClearEnvironmentalESP then S.ClearEnvironmentalESP() end
end})
VisualTab:CreateToggle({Name = "Env ESP — Priority Only", CurrentValue = S.EnvironmentalESPPriorityOnly, Flag = "EnvironmentalESPPriorityOnly", Callback = function(v)
    S.EnvironmentalESPPriorityOnly = v
    if S.ClearEnvironmentalESP then S.ClearEnvironmentalESP() end
end})
VisualTab:CreateToggle({Name = "Env ESP — Distance Fade", CurrentValue = S.EnvironmentalESPDistanceFade, Flag = "EnvironmentalESPDistanceFade", Callback = function(v)
    S.EnvironmentalESPDistanceFade = v
end})
VisualTab:CreateSlider({Name = KeyName("Env ESP Range (studs)"), Range = {5, 50}, Increment = 1, CurrentValue = S.EnvironmentalESPRange or 15, Flag = "EnvironmentalESPRange", Callback = function(v)
    S.EnvironmentalESPRange = v
end})
VisualTab:CreateSlider({Name = KeyName("Env ESP Transparency"), Range = {0, 1}, Increment = 0.01, CurrentValue = S.EnvironmentalESPTransparency or 0.95, Flag = "EnvironmentalESPTransparency", Callback = function(v)
    S.EnvironmentalESPTransparency = v
end})
VisualTab:CreateToggle({Name = "Env ESP — Auto-Scale", CurrentValue = S.EnvironmentalESPAutoScaling, Flag = "EnvironmentalESPAutoScaling", Callback = function(v)
    S.EnvironmentalESPAutoScaling = v
end})
VisualTab:CreateSlider({Name = KeyName("Env ESP Max Parts"), Range = {20, 500}, Increment = 10, CurrentValue = S.EnvironmentalESPMaxParts or 160, Flag = "EnvironmentalESPMaxParts", Callback = function(v)
    S.EnvironmentalESPMaxParts = v
end})

VisualTab:CreateSection("Target Tags")
VisualTab:CreateParagraph({Title = "Target Tags", Content = "Text labels rendered above each target showing name, HP, equipped tool, and lock status. Kill Flash briefly flashes the screen on a confirmed kill."})
VisualTab:CreateToggle({Name = "Player Tags", CurrentValue = S.UseInfoTag, Flag = "UseInfoTag", Callback = function(v) S.UseInfoTag = v end})
VisualTab:CreateToggle({Name = "NPC Tags", CurrentValue = S.UseNPCInfoTag, Flag = "UseNPCInfoTag", Callback = function(v) S.UseNPCInfoTag = v end})
VisualTab:CreateToggle({Name = "Show Display Names", CurrentValue = S.ShowDisplayName, Flag = "ShowDisplay", Callback = function(v) S.ShowDisplayName = v end})
VisualTab:CreateToggle({Name = "Show Equipped Tool", CurrentValue = S.ShowToolCheck, Flag = "UseToolCheck", Callback = function(v) S.ShowToolCheck = v end})
VisualTab:CreateToggle({Name = "Lock Status on Tag", CurrentValue = S.ShowLockIndicators, Flag = "ShowLockIndicators", Callback = function(v) S.ShowLockIndicators = v end})
VisualTab:CreateToggle({Name = "Kill Flash", CurrentValue = S.KillConfirmFlashEnabled, Flag = "KillConfirmFlash", Callback = function(v) S.KillConfirmFlashEnabled = v end})
VisualTab:CreateSlider({Name = "Flash Duration (s)", Range = {0.1, 3.0}, Increment = 0.1, CurrentValue = S.KillFlashDuration or 0.8, Flag = "KillFlashDuration", Callback = function(v) S.KillFlashDuration = v end})

VisualTab:CreateSection("HUD")
VisualTab:CreateParagraph({
    Title   = "Invisible FOV",
    Content = "The Invisible FOV toggle allows your aimbot to strictly respect the FOV boundary limit without actually drawing the circle on your screen."
})
VisualTab:CreateToggle({Name = "FOV Circle", CurrentValue = S.ShowFOV, Flag = "ShowFOV", Callback = function(v)
    S.ShowFOV = v
    if not v and S.FOVCircle then S.FOVCircle.Visible = false end
end})
VisualTab:CreateToggle({Name = "Silent FOV", CurrentValue = S.InvisibleFOV, Flag = "InvisibleFOV", Callback = function(v) S.InvisibleFOV = v end})
VisualTab:CreateSlider({Name = "FOV Size", Range = {30, 600}, Increment = 5, CurrentValue = S.FOVSize, Flag = "FOVSize", Callback = function(v)
    S.FOVSize = v
    S.LiveFOVPulseActive = true
    task.delay(1.2, function()
        S.LiveFOVPulseActive = false
    end)
end})
VisualTab:CreateToggle({Name = KeyName("Dynamic FOV"), CurrentValue = S.DynamicFOVEnabled, Flag = "DynamicFOVEnabled", Callback = function(v) S.DynamicFOVEnabled = v end})
VisualTab:CreateParagraph({
    Title   = "Dynamic FOV Scaling",
    Content = "When enabled, the FOV radius scales inversely with target distance: it grows as the target gets closer and shrinks as the target moves farther away. The configured radius is the scale at 100 studs; Dynamic FOV Max Radius caps the close-range size."
})
VisualTab:CreateSlider({Name = KeyName("Dynamic FOV Max"), Range = {30, 1000}, Increment = 10, CurrentValue = S.DynamicFOVMax or 400, Flag = "DynamicFOVMax", Callback = function(v) S.DynamicFOVMax = v end})
VisualTab:CreateDropdown({
    Name          = "FOV Tracking Origin",
    Options       = {"Screen Center", "Mouse Tracking"},
    CurrentOption = {S.AimReferenceMode},
    Flag          = "AimReferenceMode",
    Callback      = function(v)
        S.AimReferenceMode = UnpackOption(v, "Screen Center")
    end
})
VisualTab:CreateSection("Crosshair")
VisualTab:CreateParagraph({
    Title   = "Crosshair",
    Content = "Renders an on-screen vector crosshair indicator at your screen center or target reference point."
})
VisualTab:CreateToggle({Name = "Crosshair", CurrentValue = S.EnableCrosshair, Flag = "UseCrosshair", Callback = function(v)
    S.EnableCrosshair = v
    if not v and S.ClearCrosshair then S.ClearCrosshair() end
end})
VisualTab:CreateDropdown({Name = "Crosshair Style", Options = {"Plus", "Square", "Circle"}, CurrentOption = {S.CrosshairStyle}, Flag = "CrossStyle", Callback = function(v)
    S.CrosshairStyle = type(v) == "table" and v[1] or v
    if S.ClearCrosshair then S.ClearCrosshair() end
end})
VisualTab:CreateSlider({Name = "Crosshair Size", Range = {2, 50}, Increment = 1, CurrentValue = S.CrosshairSize, Flag = "CrossSize", Callback = function(v) S.CrosshairSize = v end})

local crosshairPreviewPara = VisualTab:CreateParagraph({
    Title = "Interactive Reticle Preview",
    Content = "Simulating real-time reticle geometry, color, and dynamic spread."
})
task.spawn(function()
    pcall(function()
        task.wait(1)
        local pFrame = crosshairPreviewPara and (crosshairPreviewPara.Paragraph or crosshairPreviewPara.Object)
        if pFrame then
            local pBox = Instance.new("Frame", pFrame)
            pBox.Name = "CrosshairPreviewBox"
            pBox.Size = UDim2.new(0, 100, 0, 70)
            pBox.Position = UDim2.new(1, -110, 0.5, -35)
            pBox.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
            pBox.BorderSizePixel = 0
            Instance.new("UICorner", pBox).CornerRadius = UDim.new(0, 6)
            local pBoxStroke = Instance.new("UIStroke", pBox)
            pBoxStroke.Color = Color3.fromRGB(45, 45, 55)

            local retCenter = Instance.new("Frame", pBox)
            retCenter.Name = "ReticleCenter"
            retCenter.Size = UDim2.new(0, 4, 0, 4)
            retCenter.Position = UDim2.new(0.5, -2, 0.5, -2)
            retCenter.BackgroundColor3 = S.CrosshairColor or Color3.fromRGB(0, 255, 200)
            Instance.new("UICorner", retCenter).CornerRadius = UDim.new(1, 0)

            local lineTop = Instance.new("Frame", pBox)
            local lineBot = Instance.new("Frame", pBox)
            local lineLeft = Instance.new("Frame", pBox)
            local lineRight = Instance.new("Frame", pBox)
            local allLines = {lineTop, lineBot, lineLeft, lineRight}
            for _, l in ipairs(allLines) do
                l.BorderSizePixel = 0
                l.BackgroundColor3 = S.CrosshairColor or Color3.fromRGB(0, 255, 200)
            end

            task.spawn(function()
                while pBox and pBox.Parent do
                    local sz = math.clamp(S.CrosshairSize or 10, 4, 25)
                    local col = S.CrosshairColor or Color3.fromRGB(0, 255, 200)
                    retCenter.BackgroundColor3 = col
                    for _, l in ipairs(allLines) do l.BackgroundColor3 = col end

                    lineTop.Size = UDim2.new(0, 2, 0, sz)
                    lineTop.Position = UDim2.new(0.5, -1, 0.5, -sz - 3)

                    lineBot.Size = UDim2.new(0, 2, 0, sz)
                    lineBot.Position = UDim2.new(0.5, -1, 0.5, 3)

                    lineLeft.Size = UDim2.new(0, sz, 0, 2)
                    lineLeft.Position = UDim2.new(0.5, -sz - 3, 0.5, -1)

                    lineRight.Size = UDim2.new(0, sz, 0, 2)
                    lineRight.Position = UDim2.new(0.5, 3, 0.5, -1)

                    task.wait(0.25)
                end
            end)
        end
    end)
end)

VisualTab:CreateSection("Calibration")
VisualTab:CreateParagraph({Title = "Calibration", Content = "Apply fixed pixel offsets to compensate for monitor or camera misalignment. Only used when Manual Calibration is enabled."})
VisualTab:CreateToggle({Name = "Manual Calibration", CurrentValue = S.ManualCalibrationEnabled, Flag = "EnableCalibration", Callback = function(v) S.ManualCalibrationEnabled = v end})
VisualTab:CreateSlider({Name = "Offset X (px)", Range = {-200, 200}, Increment = 1, CurrentValue = S.CalibrationOffsetX, Flag = "CalibrationX", Callback = function(v) S.CalibrationOffsetX = v end})
VisualTab:CreateSlider({Name = "Offset Y (px)", Range = {-200, 200}, Increment = 1, CurrentValue = S.CalibrationOffsetY, Flag = "CalibrationY", Callback = function(v) S.CalibrationOffsetY = v end})

-- // ============================================================ // --
-- //           SCREEN RECORDING CLOAKING SYSTEM (v2.2.0)          // --
-- // ============================================================ // --
-- Roblox's built-in screen recording captures:
--   [X] Drawing API objects (Lines, Circles, Squares, Text) — VISIBLE
--   [X] Roblox Highlight instances — VISIBLE
--   [X] ScreenGui frames / TextLabels — VISIBLE
--   [V] BillboardGui parented to workspace parts — INVISIBLE
--   [V] SurfaceGui parented to workspace parts — INVISIBLE
-- This system lets you selectively redirect selected visuals to the
-- invisible-to-capture rendering mode at the press of a button.

VisualTab:CreateSection("[KEY] Screen Cloaking")
VisualTab:CreateParagraph({
    Title   = "About This System (Work in Progress)",
    Content = "[WORK IN PROGRESS]: Due to recent Roblox capture system updates and executor rendering implementations (Xeno / Real Executor lacking direct DirectX/Vulkan hooked Drawing overlays), true streamproof cloaking is currently undergoing testing and refinement.\n\n" ..
              "• Tag cloaking via BillboardGui/SurfaceGui and 2D Drawing overlays may still be captured or fail to render depending on your executor environment.\n" ..
              "• Full suppression options hide elements from both the screen and recording.\n\n" ..
              "This feature is temporarily marked as Work in Progress while executor developers update their native overlay rendering hooks."
})

-- Status monitor: shows hidden/visible state per feature
local CloakStatusLabel = VisualTab:CreateParagraph({
    Title   = "Recording Cloak Status",
    Content = "No visuals hidden from recording."
})

-- List of cloakable visual feature names (must match render loop checks)
local CloakableFeatures = {
    "Crosshair",
    "FOV Circle",
    "ESP Highlights (Chams)",
    "Drawing-Based ESP (Box, Skeleton, Snaplines, OOF Arrows)",
    "Tags / Nametags",
    "Snaplines",
    "OOF Arrows",
    "Box ESP",
    "Skeleton ESP",
}

-- Rebuild the status paragraph from S.HiddenFromRecording
local function RebuildCloakStatus()
    if not CloakStatusLabel then return end
    local lines = {}
    for _, feat in ipairs(CloakableFeatures) do
        local hidden = S.HiddenFromRecording and S.HiddenFromRecording[feat]
        table.insert(lines, (hidden and "[HIDDEN] " or "[VISIBLE] ") .. feat)
    end
    local anyHidden = false
    if S.HiddenFromRecording then
        for _ in pairs(S.HiddenFromRecording) do anyHidden = true; break end
    end
    pcall(function()
        CloakStatusLabel:Set({
            Title   = "Recording Cloak Status" .. (anyHidden and " — ACTIVE" or " — Inactive"),
            Content = table.concat(lines, "\n"),
        })
    end)
end

-- Multi-select dropdown: pick which features to cloak
local SelectedCloakFeatures = {}
VisualTab:CreateDropdown({
    Name            = "Select Visuals to Hide from Recording",
    Options         = CloakableFeatures,
    CurrentOption   = {},
    MultipleOptions = true,
    Flag            = "RecordingCloakDropdown",
    Callback        = function(v)
        SelectedCloakFeatures = type(v) == "table" and v or {}
    end
})

-- Button: Hide selected from recording
VisualTab:CreateButton({
    Name     = "[HIDE] Hide Selected from Screen Recording",
    Callback = function()
        if #SelectedCloakFeatures == 0 then
            if S.Notify then S.Notify({Title="Cloaking", Content="No visuals selected. Use the dropdown above.", Duration=2, Image="alert-circle"}) end
            return
        end
        if not S.HiddenFromRecording then S.HiddenFromRecording = {} end
        for _, feat in ipairs(SelectedCloakFeatures) do
            S.HiddenFromRecording[feat] = true
        end
        RebuildCloakStatus()
        if S.Notify then
            S.Notify({
                Title   = "Cloaking Active",
                Content = table.concat(SelectedCloakFeatures, ", ") .. " hidden from Roblox recording.",
                Duration = 3,
                Image   = "eye-off"
            })
        end
    end
})

-- Button: Show selected (remove from cloak)
VisualTab:CreateButton({
    Name     = "[RESTORE] Show Selected (Restore from Cloak)",
    Callback = function()
        if #SelectedCloakFeatures == 0 then
            if S.Notify then S.Notify({Title="Cloaking", Content="No visuals selected. Use the dropdown above.", Duration=2, Image="alert-circle"}) end
            return
        end
        if not S.HiddenFromRecording then S.HiddenFromRecording = {} end
        for _, feat in ipairs(SelectedCloakFeatures) do
            S.HiddenFromRecording[feat] = nil
        end
        -- If any cloaked features involved Drawing objects, ensure they are re-enabled via normal render path
        -- (the render loop reads S.HiddenFromRecording before deciding visibility)
        RebuildCloakStatus()
        if S.Notify then
            S.Notify({
                Title   = "Cloaking Removed",
                Content = table.concat(SelectedCloakFeatures, ", ") .. " restored to normal rendering.",
                Duration = 3,
                Image   = "eye"
            })
        end
    end
})

VisualTab:CreateButton({
    Name     = "Clear All Cloak Overrides",
    Callback = function()
        S.HiddenFromRecording = {}
        RebuildCloakStatus()
        if S.Notify then S.Notify({Title="Cloaking", Content="All visual cloak overrides cleared.", Duration=2, Image="refresh-cw"}) end
    end
})

-- Auto-refresh status every 2s while tab is open
task.spawn(function()
    task.wait(1)
    while getgenv().TASFF and getgenv().TASFF.Running do
        pcall(RebuildCloakStatus)
        task.wait(2)
    end
end)
-- Initial build
task.defer(RebuildCloakStatus)


-- // ============================================================ // --
-- //                      3. TRIGGERBOT TAB                       // --
-- // ============================================================ // --

local TriggerbotTab = Window:CreateTab("Triggerbot", "mouse-pointer-click")

TriggerbotTab:CreateSection("Mouse Triggerbot")
TriggerbotTab:CreateParagraph({
    Title   = "Simulation Engine & 3D Tracking",
    Content = "Virtual: Emulates driver-level mouse events.\nPhysical: Hooks into native executor click functions.\n3rd Person Tracking: Fires at the target's exact screen coordinate instead of center screen."
})
TriggerbotTab:CreateToggle({Name = "Mouse Triggerbot", CurrentValue = S.AutoClickEnabled, Flag = "EnableTriggerbot", Callback = function(v)
    S.AutoClickEnabled = v
    if not v and S.IsHoldingClick then
        S.IsHoldingClick = false
        game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end
end})
TriggerbotTab:CreateDropdown({Name = "Click Engine", Options = {"Virtual", "Physical"}, CurrentOption = {S.TriggerbotClickMode}, Flag = "TriggerbotClickMode", Callback = function(v)
    S.TriggerbotClickMode = UnpackOption(v, "Virtual")
end})
TriggerbotTab:CreateDropdown({Name = "Click Method", Options = {"Mash", "Hold"}, CurrentOption = {S.ClickMethod}, Flag = "ClickMethod", Callback = function(v)
    S.ClickMethod = UnpackOption(v, "Mash")
end})
TriggerbotTab:CreateSlider({Name = "Click Interval (ms)", Range = {1, 1000}, Increment = 1, CurrentValue = S.ClickInterval, Flag = "ClickInterval", Callback = function(v)
    S.ClickInterval = v
end})
TriggerbotTab:CreateToggle({Name = "3rd Person Mode", CurrentValue = S.ThirdPersonTriggerbot, Flag = "ThirdPersonTriggerbot", Callback = function(v)
    S.ThirdPersonTriggerbot = v
end})
TriggerbotTab:CreateToggle({Name = "Priority Targets Only", CurrentValue = S.TriggerbotPriorityOnly, Flag = "TriggerbotPriorityOnly", Callback = function(v)
    S.TriggerbotPriorityOnly = v
end})

TriggerbotTab:CreateSection("Key Triggerbot")
TriggerbotTab:CreateParagraph({
    Title   = "Key Triggerbot",
    Content = "Automatically executes a custom keystroke (e.g., casting an ability, dashing, or swinging a sword) when the aimbot locks onto a valid target."
})
TriggerbotTab:CreateToggle({Name = "Key Triggerbot", CurrentValue = S.KeyTriggerbotEnabled, Flag = "KeyTriggerbotToggle", Callback = function(v)
    S.KeyTriggerbotEnabled = v
    if not v and S.IsHoldingTriggerKey then
        S.IsHoldingTriggerKey = false
        pcall(function()
            local key = S.GetKeyCode and S.GetKeyCode(S.KeyTriggerbotKey)
            if key then game:GetService("VirtualInputManager"):SendKeyEvent(false, key, false, game) end
        end)
    end
end})
TriggerbotTab:CreateInput({
    Name                    = "Target Action Key (e.g. F, Q, E)",
    PlaceholderText         = "F",
    RemoveTextAfterFocusLost = false,
    Flag                    = "KeyTriggerKeyInput",
    Callback                = function(text)
        if text and text ~= "" then S.KeyTriggerbotKey = text:upper() end
    end
})
TriggerbotTab:CreateDropdown({Name = "Key Method", Options = {"Single Press", "Mash", "Hold"}, CurrentOption = {S.KeyTriggerMode}, Flag = "KeyTriggerMode", Callback = function(v)
    S.KeyTriggerMode = UnpackOption(v, "Single Press")
end})

TriggerbotTab:CreateSection("Auto-Melee")
TriggerbotTab:CreateParagraph({Title = "Auto-Melee", Content = "Automatically performs a melee attack when a valid target enters range. Works independently of the aimbot engine."})
TriggerbotTab:CreateToggle({Name = "Auto-Melee", CurrentValue = S.MeleeModeEnabled, Flag = "EnableMeleeMode", Callback = function(v) S.MeleeModeEnabled = v end})
TriggerbotTab:CreateSlider({Name = "Melee Range (studs)", Range = {1, 10}, Increment = 1, CurrentValue = S.MeleeDetectionRange, Flag = "MeleeRange", Callback = function(v)
    S.MeleeDetectionRange = v
end})
TriggerbotTab:CreateSlider({Name = "Melee Interval (ms)", Range = {1, 1000}, Increment = 1, CurrentValue = S.MeleeClickInterval, Flag = "MeleeClickInterval", Callback = function(v)
    S.MeleeClickInterval = v
end})

-- // ============================================================ // --
-- //                       4. ADVANCED TAB                        // --
-- // ============================================================ // --


-- Intel Tab block to INSERT before local AdvancedTab
local IntelTab = Window:CreateTab("Intel", "shield-alert")

IntelTab:CreateSection("Intel Monitor")
IntelTab:CreateParagraph({
    Title   = "How It Works",
    Content = "All tracked players (marked, threats, nemeses, registry) appear here sorted by threat score. Select a name then use the action buttons below."
})

local IntelMonitorLabel = IntelTab:CreateParagraph({
    Title   = "Intel Monitor (0 tracked)",
    Content = "No tracked players."
})
S.IntelMonitorLabel = IntelMonitorLabel

IntelTab:CreateInput({
    Name                  = "Select Player by Name",
    PlaceholderText       = "Enter exact username...",
    RemoveTextAfterFocusLost = false,
    Flag                  = "IntelSelectInput",
    Callback              = function(text)
        if text and text ~= "" then
            S.IntelSelected = text
            if S.RebuildIntelMonitor then S.RebuildIntelMonitor() end
        end
    end
})

IntelTab:CreateButton({
    Name     = "Remove Selected",
    Callback = function()
        if S.IntelSelected == "" then
            if S.Notify then S.Notify({Title="Intel",Content="No player selected.",Duration=2,Image="alert-circle"}) end
            return
        end
        if S.RemoveFromIntel then S.RemoveFromIntel(S.IntelSelected, false) end
    end
})

IntelTab:CreateButton({
    Name     = "Remove Selected (Nemesis)",
    Callback = function()
        if S.IntelSelected == "" then
            if S.Notify then S.Notify({Title="Intel",Content="No player selected.",Duration=2,Image="alert-circle"}) end
            return
        end
        if S.RemoveFromIntel then S.RemoveFromIntel(S.IntelSelected, true) end
    end
})

IntelTab:CreateButton({
    Name     = "Clear All Non-Nemesis",
    Callback = function()
        -- Pass 1: collect names to remove (safe — avoids modifying table while iterating)
        local toRemove = {}
        for name, data in pairs(S.IntelPlayers) do
            if not data.nemesis then
                table.insert(toRemove, name)
            end
        end
        -- Pass 2: remove collected entries
        for _, name in ipairs(toRemove) do
            S.IntelPlayers[name] = nil
            S.ThreatMemory[name] = nil
        end
        -- Pass 3: rebuild PriorityPlayers keeping only confirmed Nemeses
        -- (also catches players added directly via dropdown without going through Intel)
        local nemesisSet = {}
        for name, data in pairs(S.IntelPlayers) do
            if data.nemesis then nemesisSet[name] = true end
        end
        local kept = {}
        for _, name in ipairs(S.PriorityPlayers) do
            if nemesisSet[name] then table.insert(kept, name) end
        end
        S.PriorityPlayers = kept
        S.IntelSelected = ""
        -- Force ESP highlights to recolor immediately (don't wait for next render frame)
        if S.ClearVisuals then S.ClearVisuals() end
        if S.SyncPriorityUI then S.SyncPriorityUI() end
        if S.RebuildIntelMonitor then S.RebuildIntelMonitor() end
        if S.Notify then S.Notify({Title="Intel", Content="Cleared all non-Nemesis entries.", Duration=2, Image="trash-2"}) end
    end
})

local LockHistoryLabel = IntelTab:CreateParagraph({
    Title   = "Target Lock History",
    Content = "No locks yet."
})
S.LockHistoryLabel = LockHistoryLabel
task.spawn(function()
    while getgenv().TASFF and getgenv().TASFF.Running do
        task.wait(1)
        if S.LockHistoryLabel and S.LockHistory then
            local lines = {}
            for i, log in ipairs(S.LockHistory) do
                local ago = math.floor(tick() - log.time)
                table.insert(lines, i .. ". " .. log.name .. " (" .. ago .. "s ago)")
            end
            if #lines > 0 then
                pcall(function() S.LockHistoryLabel:Set({Title="Target Lock History", Content=table.concat(lines, "\n")}) end)
            end
        end
    end
end)

IntelTab:CreateSection("Priority Settings")
IntelTab:CreateParagraph({
    Title   = "Priority Behavior Mode",
    Content = "Boost: Priority players are sorted first but aimbot still targets others when none are available. Exclusive: Aimbot ONLY targets priority-listed players (old StrictPrioritize behavior)."
})
IntelTab:CreateDropdown({
    Name          = "Priority Behavior",
    Options       = {"Boost", "Exclusive"},
    CurrentOption = {S.PriorityBehavior or "Boost"},
    Flag          = "PriorityBehavior",
    Callback      = function(v)
        local val = UnpackOption(v, "Boost")
        S.PriorityBehavior = val
        S.StrictPrioritize = (val == "Exclusive")
    end
})

local IntelPriorityDropdown = IntelTab:CreateDropdown({
    Name            = "Priority Registry (Preferred Targets)",
    Options         = S.GetPlayerNames and S.GetPlayerNames() or {},
    CurrentOption   = {},
    MultipleOptions = true,
    Flag            = "IntelPriorityPlayers",
    Callback        = function(v)
        -- Resolve display-name labels to real usernames
        local resolved = {}
        for _, label in ipairs(v) do
            local name = (S.ResolvePlayerName and S.ResolvePlayerName(label)) or label
            table.insert(resolved, name)
        end
        local removed = {}
        for _, oldName in ipairs(S.PriorityPlayers) do
            if not table.find(resolved, oldName) then table.insert(removed, oldName) end
        end
        for _, remName in ipairs(removed) do
            S.ThreatMemory[remName] = nil
            S.NemesisMemory[remName] = nil
            S.IntelPlayers[remName] = nil
        end
        for _, newName in ipairs(resolved) do
            if not S.IntelPlayers[newName] then
                if S.AddToIntel then S.AddToIntel(newName, "Registry", 0) end
            end
        end
        S.PriorityPlayers = resolved
        if S.SyncPriorityUI then S.SyncPriorityUI() end
    end
})
S.PriorityDropdownRef = IntelPriorityDropdown

IntelTab:CreateSection("Threat Intelligence")
IntelTab:CreateParagraph({Title = "Threat Intelligence", Content = "Multi-source system that identifies hostile players. Kill-Count Flag is the most reliable method. Damage Tracking and Expert Instincts cast a wider but less certain net — use sensitivity sliders to tune false-positive rate."})
IntelTab:CreateToggle({Name = "Kill Feed", CurrentValue = S.KillFeedEnabled, Flag = "KillFeedEnabled", Callback = function(v)
    S.KillFeedEnabled = v
end})
IntelTab:CreateToggle({Name = "Kill-Count Threat Flag", CurrentValue = S.KillCountThreatEnabled, Flag = "KillCountThreat", Callback = function(v)
    S.KillCountThreatEnabled = v
end})
IntelTab:CreateSlider({Name = "Kills to Flag", Range = {1, 10}, Increment = 1, CurrentValue = S.KillsBeforeThreat, Flag = "KillsBeforeThreat", Callback = function(v)
    S.KillsBeforeThreat = v
end})
IntelTab:CreateSlider({Name = "Kills for Permanent", Range = {2, 15}, Increment = 1, CurrentValue = S.ContinuousKillsPermanent or 5, Flag = "ContinuousKillsPermanent", Callback = function(v)
    S.ContinuousKillsPermanent = v
end})
IntelTab:CreateToggle({Name = "Threat Detector", CurrentValue = S.ThreatDetectorEnabled, Flag = "ThreatDetector", Callback = function(v)
    S.ThreatDetectorEnabled = v
end})
IntelTab:CreateToggle({Name = "Damage Tracking", CurrentValue = S.OtherPlayersDamageTracking, Flag = "OtherPlayersDamageTracking", Callback = function(v)
    S.OtherPlayersDamageTracking = v
end})
IntelTab:CreateToggle({Name = KeyName("Expert Instincts"), CurrentValue = S.ExpertInstinctsEnabled, Flag = "ExpertInstinctsEnabled", Callback = function(v)
    S.ExpertInstinctsEnabled = v
end})
IntelTab:CreateSlider({Name = KeyName("Instincts Lock Speed"), Range = {0, 100}, Increment = 5, CurrentValue = S.ExpertInstinctsIntensity or 60, Flag = "ExpertInstinctsIntensity", Callback = function(v)
    S.ExpertInstinctsIntensity = v
end})
IntelTab:CreateDropdown({
    Name = "Expert Instincts Mode",
    Options = {"Blatant", "Legit"},
    CurrentOption = {S.InstinctsMode or "Blatant"},
    Flag = "InstinctsMode",
    Callback = function(v)
        S.InstinctsMode = (type(v) == "table") and v[1] or v
    end
})
IntelTab:CreateToggle({Name = KeyName("Instincts Weapon Check"), CurrentValue = S.InstinctsInventoryCheck, Flag = "InstinctsInventoryCheck", Callback = function(v)
    S.InstinctsInventoryCheck = v
end})
IntelTab:CreateToggle({Name = KeyName("Instincts Auto-Equip"), CurrentValue = S.InstinctsAutoEquip, Flag = "InstinctsAutoEquip", Callback = function(v)
    S.InstinctsAutoEquip = v
end})
IntelTab:CreateToggle({Name = KeyName("Instincts Auto First-Person"), CurrentValue = S.InstinctsFirstPersonCamera, Flag = "InstinctsFirstPersonCamera", Callback = function(v)
    S.InstinctsFirstPersonCamera = v
end})

local SelectedInstinctsBlacklistTool = nil
local InstinctsBlacklistDropdownRef = nil

IntelTab:CreateButton({
    Name = "Blacklist Currently Held Tool from Instincts",
    Callback = function()
        local char = Player and Player.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then
            if not table.find(S.InstinctsBlacklist, tool.Name) then
                table.insert(S.InstinctsBlacklist, tool.Name)
                if InstinctsBlacklistDropdownRef and InstinctsBlacklistDropdownRef.Refresh then
                    pcall(function() InstinctsBlacklistDropdownRef:Refresh(#S.InstinctsBlacklist > 0 and S.InstinctsBlacklist or {"No Items Blacklisted"}, true) end)
                end
                if S.SaveInstinctsLists then S.SaveInstinctsLists() end
                if S.Notify then S.Notify({Title = "TASFF Instincts", Content = "Blacklisted from instincts: " .. tool.Name .. " (seen as non-weapon)", Duration = 3, Image = "shield-off"}) end
            else
                if S.Notify then S.Notify({Title = "TASFF Instincts", Content = tool.Name .. " is already blacklisted.", Duration = 2, Image = "alert-circle"}) end
            end
        else
            if S.Notify then S.Notify({Title = "TASFF Instincts", Content = "Equip a tool first to blacklist it.", Duration = 2, Image = "alert-circle"}) end
        end
    end
})

InstinctsBlacklistDropdownRef = IntelTab:CreateDropdown({
    Name = "Instincts Blacklist (Seen as Non-Weapons)",
    Options = #S.InstinctsBlacklist > 0 and S.InstinctsBlacklist or {"No Items Blacklisted"},
    CurrentOption = {"No Items Blacklisted"},
    Flag = "InstinctsBlacklistDropdown",
    Callback = function(v)
        SelectedInstinctsBlacklistTool = type(v) == "table" and v[1] or v
    end
})
S.InstinctsBlacklistDropdownRef = InstinctsBlacklistDropdownRef

IntelTab:CreateButton({
    Name = "Remove Selected from Instincts Blacklist",
    Callback = function()
        if SelectedInstinctsBlacklistTool and SelectedInstinctsBlacklistTool ~= "No Items Blacklisted" then
            local idx = table.find(S.InstinctsBlacklist, SelectedInstinctsBlacklistTool)
            if idx then
                table.remove(S.InstinctsBlacklist, idx)
                if InstinctsBlacklistDropdownRef and InstinctsBlacklistDropdownRef.Refresh then
                    pcall(function() InstinctsBlacklistDropdownRef:Refresh(#S.InstinctsBlacklist > 0 and S.InstinctsBlacklist or {"No Items Blacklisted"}, true) end)
                end
                if S.SaveInstinctsLists then S.SaveInstinctsLists() end
                if S.Notify then S.Notify({Title = "TASFF Instincts", Content = "Removed: " .. SelectedInstinctsBlacklistTool, Duration = 2, Image = "check"}) end
            end
        end
    end
})

local SelectedInstinctsPriorityTool = nil
local InstinctsPriorityDropdownRef = nil

IntelTab:CreateButton({
    Name = "Prioritize Currently Held Tool for Instincts",
    Callback = function()
        local char = Player and Player.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then
            if not table.find(S.InstinctsPrioritizedTools, tool.Name) then
                table.insert(S.InstinctsPrioritizedTools, tool.Name)
                if InstinctsPriorityDropdownRef and InstinctsPriorityDropdownRef.Refresh then
                    pcall(function() InstinctsPriorityDropdownRef:Refresh(#S.InstinctsPrioritizedTools > 0 and S.InstinctsPrioritizedTools or {"No Items Prioritized"}, true) end)
                end
                if S.SaveInstinctsLists then S.SaveInstinctsLists() end
                if S.Notify then S.Notify({Title = "TASFF Instincts", Content = "Prioritized for instincts: " .. tool.Name .. " (immediate engage)", Duration = 3, Image = "zap"}) end
            else
                if S.Notify then S.Notify({Title = "TASFF Instincts", Content = tool.Name .. " is already prioritized.", Duration = 2, Image = "alert-circle"}) end
            end
        else
            if S.Notify then S.Notify({Title = "TASFF Instincts", Content = "Equip a tool first to prioritize it.", Duration = 2, Image = "alert-circle"}) end
        end
    end
})

InstinctsPriorityDropdownRef = IntelTab:CreateDropdown({
    Name = "Instincts Priority Tools (Immediate Engage)",
    Options = #S.InstinctsPrioritizedTools > 0 and S.InstinctsPrioritizedTools or {"No Items Prioritized"},
    CurrentOption = {"No Items Prioritized"},
    Flag = "InstinctsPriorityDropdown",
    Callback = function(v)
        SelectedInstinctsPriorityTool = type(v) == "table" and v[1] or v
    end
})
S.InstinctsPriorityDropdownRef = InstinctsPriorityDropdownRef

IntelTab:CreateButton({
    Name = "Remove Selected from Instincts Priority",
    Callback = function()
        if SelectedInstinctsPriorityTool and SelectedInstinctsPriorityTool ~= "No Items Prioritized" then
            local idx = table.find(S.InstinctsPrioritizedTools, SelectedInstinctsPriorityTool)
            if idx then
                table.remove(S.InstinctsPrioritizedTools, idx)
                if InstinctsPriorityDropdownRef and InstinctsPriorityDropdownRef.Refresh then
                    pcall(function() InstinctsPriorityDropdownRef:Refresh(#S.InstinctsPrioritizedTools > 0 and S.InstinctsPrioritizedTools or {"No Items Prioritized"}, true) end)
                end
                if S.SaveInstinctsLists then S.SaveInstinctsLists() end
                if S.Notify then S.Notify({Title = "TASFF Instincts", Content = "Removed: " .. SelectedInstinctsPriorityTool, Duration = 2, Image = "check"}) end
            end
        end
    end
})
IntelTab:CreateToggle({Name = "Threat Neutralization", CurrentValue = S.ThreatNeutralizationEnabled, Flag = "ThreatNeutralization", Callback = function(v)
    S.ThreatNeutralizationEnabled = v
end})
IntelTab:CreateToggle({Name = "Ignore Threat Victims", CurrentValue = S.IgnoreThreatVictims ~= false, Flag = "IgnoreThreatVictims", Callback = function(v)
    S.IgnoreThreatVictims = v
end})
IntelTab:CreateSlider({Name = "Threat Memory Expiration (Seconds)", Range = {1, 60}, Increment = 1, CurrentValue = S.ThreatTimeout, Flag = "ThreatTimeout", Callback = function(v)
    S.ThreatTimeout = v
end})
IntelTab:CreateSlider({Name = "Scan Radius (studs)", Range = {20, 200}, Increment = 10, CurrentValue = S.ThreatProximityRadius or 80, Flag = "ThreatProximityRadius", Callback = function(v) S.ThreatProximityRadius = v end})
IntelTab:CreateSlider({Name = "FP Cooldown (s)", Range = {0.5, 10}, Increment = 0.5, CurrentValue = S.ThreatFPCooldown or 1.5, Flag = "ThreatFPCooldown", Callback = function(v) S.ThreatFPCooldown = v end})
IntelTab:CreateToggle({Name = "Auto-Blacklist on Expire", CurrentValue = S.BlacklistExpiredThreats, Flag = "BlacklistExpiredThreats", Callback = function(v)
    S.BlacklistExpiredThreats = v
end})
IntelTab:CreateToggle({Name = "Auto-Expire on Disconnect", CurrentValue = S.AutoExpireOnDisconnect, Flag = "AutoExpireOnDisconnect", Callback = function(v)
    S.AutoExpireOnDisconnect = v
end})
IntelTab:CreateToggle({Name = KeyName("Deep Tag Scanner"), CurrentValue = S.DeepThreatScanEnabled ~= false, Flag = "DeepThreatScan", Callback = function(v)
    S.DeepThreatScanEnabled = v
end})
IntelTab:CreateToggle({Name = KeyName("Stat Correlator"), CurrentValue = S.StatCorrelatorEnabled ~= false, Flag = "StatCorrelator", Callback = function(v)
    S.StatCorrelatorEnabled = v
end})

IntelTab:CreateSection("Nemesis System")
IntelTab:CreateParagraph({Title = "Nemesis System", Content = "Tracks players who have killed you repeatedly. Once the strike threshold is reached, that player is permanently stored as a nemesis and boosted in priority targeting."})
IntelTab:CreateToggle({Name = "Nemesis System", CurrentValue = S.NemesisEnabled, Flag = "NemesisEnabled", Callback = function(v)
    S.NemesisEnabled = v
end})
IntelTab:CreateSlider({Name = "Strikes to Nemesis", Range = {1, 10}, Increment = 1, CurrentValue = S.KillsBeforeNemesis, Flag = "KillsBeforeNemesis", Callback = function(v)
    S.KillsBeforeNemesis = v
end})
local NemesisViewer = IntelTab:CreateParagraph({
    Title   = "Permanent Nemesis Roster",
    Content = "No nemeses."
})
local function RefreshNemesisViewer()
    local names = {}
    for n, _ in pairs(S.NemesisMemory or {}) do table.insert(names, n) end
    if #names == 0 then
        pcall(function() NemesisViewer:Set({Title="Permanent Nemesis Roster", Content="No permanent nemeses."}) end)
    else
        pcall(function() NemesisViewer:Set({Title="Permanent Nemesis Roster", Content=table.concat(names, "\n")}) end)
    end
end
IntelTab:CreateButton({Name="Refresh Nemesis Roster", Callback=RefreshNemesisViewer})
task.spawn(RefreshNemesisViewer)

IntelTab:CreateSection("Threat Leaderboard")
local LeaderboardParagraph = IntelTab:CreateParagraph({
    Title   = "Top Threats This Session",
    Content = "Scanning threat scores..."
})
S.LeaderboardParagraph = LeaderboardParagraph

local function RefreshLeaderboard()
    if not LeaderboardParagraph then return end
    local list = {}
    if S.NemesisMemory then
        for n, count in pairs(S.NemesisMemory) do
            table.insert(list, {Name = n, Tier = "NEMESIS", Score = 100 + (tonumber(count) or 1) * 10})
        end
    end
    if S.ThreatPlayers then
        for _, n in ipairs(S.ThreatPlayers) do
            local found = false
            for _, item in ipairs(list) do if item.Name == n then found = true break end end
            if not found then
                local k = (S.PlayerKillCounts and S.PlayerKillCounts[n]) or 0
                table.insert(list, {Name = n, Tier = "THREAT", Score = 50 + k * 5})
            end
        end
    end
    if S.PriorityPlayers then
        for _, n in ipairs(S.PriorityPlayers) do
            local found = false
            for _, item in ipairs(list) do if item.Name == n then found = true break end end
            if not found then
                table.insert(list, {Name = n, Tier = "PRIORITY", Score = 25})
            end
        end
    end
    table.sort(list, function(a, b) return a.Score > b.Score end)
    local lines = {}
    for i = 1, math.min(#list, 5) do
        local entry = list[i]
        table.insert(lines, string.format("#%d  [%s] %s  (Score: %d)", i, entry.Tier, entry.Name, entry.Score))
    end
    local body = #lines > 0 and table.concat(lines, "\n") or "No active threats recorded."
    pcall(function()
        LeaderboardParagraph:Set({
            Title   = "Top Threats This Session (" .. #list .. ")",
            Content = body
        })
    end)
end
task.spawn(function()
    while getgenv().TASFF and getgenv().TASFF.Running do
        task.wait(6)
        RefreshLeaderboard()
    end
end)

IntelTab:CreateSection("Spectator Mode")
IntelTab:CreateParagraph({Title = "Spectator Mode", Content = "Lock your camera to follow a target player in third-person. Select the player, then toggle Spectate Player to activate."})
local SpectateDropdown = IntelTab:CreateDropdown({
    Name            = "Spectate Target",
    Options         = S.GetPlayerNames and S.GetPlayerNames() or {},
    CurrentOption   = {S.SpectateTarget or ""},
    MultipleOptions = false,
    Flag            = "SpectateTargetDropdown",
    Callback        = function(v)
        local val = type(v) == "table" and v[1] or v
        local realName = (S.ResolvePlayerName and S.ResolvePlayerName(val)) or val
        S.SpectateTarget = realName
    end
})
local SpectateToggle = IntelTab:CreateToggle({Name = "Spectate Player", CurrentValue = S.SpectatePlayerEnabled, Flag = "SpectatePlayer", Callback = function(v)
    if v then
        local targetName = (S.ResolvePlayerName and S.ResolvePlayerName(S.SpectateTarget)) or S.SpectateTarget
        if not targetName or targetName == "" then
            S.SpectatePlayerEnabled = false
            pcall(function() SpectateToggle:Set(false) end)
            if S.Notify then
                S.Notify({
                    Title    = "TASFF Spectator",
                    Content  = "Please select a target player from the dropdown first.",
                    Duration = 3,
                    Image    = "alert-circle"
                })
            end
            return
        end
        S.SpectateTarget = targetName
    end
    S.SpectatePlayerEnabled = v
end})
S.SyncSpectatorUI = function(state) pcall(function() SpectateToggle:Set(state) end) end
IntelTab:CreateButton({Name="Refresh Player List", Callback=function()
    if S.GetPlayerNames then
        local names = S.GetPlayerNames()
        pcall(function() SpectateDropdown:Refresh(names, true) end)
        if S.PriorityDropdownRef and S.PriorityDropdownRef.Refresh then pcall(function() S.PriorityDropdownRef:Refresh(names, true) end) end
    end
end})

IntelTab:CreateSection("Click-to-Mark")
IntelTab:CreateParagraph({Title = "Click-to-Mark", Content = "Instantly marks clicked or keybind-targeted players as priority targets. Marked players are highlighted and boosted above auto-detected threats."})
IntelTab:CreateToggle({Name = "Target Marking", CurrentValue = S.ClickToMarkEnabled, Flag = "ClickToMark", Callback = function(v) S.ClickToMarkEnabled = v end})
IntelTab:CreateDropdown({Name = "Mark Activation Input", Options = {"Mouse Click Only", "Keybind Only", "Both"}, CurrentOption = {S.MarkMethod}, Flag = "MarkMethod", Callback = function(v)
    S.MarkMethod = type(v) == "table" and v[1] or v
end})
IntelTab:CreateKeybind({
    Name           = "Target Mark Keybind",
    CurrentKeybind = S.MarkKeybind or "T",
    HoldToInteract = false,
    CallOnChange   = true,
    Flag           = "MarkKeybind",
    Callback       = function(key)
        local validKey = SanitizeKeyName(key)
        if validKey then
            S.MarkKeybind = validKey
            if S.Notify then
                S.Notify({
                    Title    = "TASFF Keybind",
                    Content  = "Target Mark key set to [" .. tostring(validKey) .. "]",
                    Duration = 2,
                    Image    = "keyboard"
                })
            end
        end
    end
})
IntelTab:CreateToggle({Name = "Focus Mode", CurrentValue = S.FocusMode, Flag = "FocusMode", Callback = function(v)
    S.FocusMode = v
end})


-- [v2.3.0] Advanced tab removed; contents redistributed to Settings

-- [v2.3.0] Advanced tab removed; marking controls are in Intel tab
-- (Mark/Priority controls moved to Intel tab)

-- // ============================================================ // --
-- //                       5. SETTINGS TAB                        // --
-- // ============================================================ // --

local SettingsTab = Window:CreateTab("Settings", "filter")

SettingsTab:CreateSection("Entity Filtering")
SettingsTab:CreateParagraph({Title = "Entity Filtering", Content = "Controls which entity types the aimbot and ESP systems interact with. Team Check ignores players on the same team."})
SettingsTab:CreateToggle({Name = "Target Players", CurrentValue = S.TargetPlayers, Flag = "TargetPlayers", Callback = function(v) S.TargetPlayers = v end})
SettingsTab:CreateToggle({Name = "Target NPCs", CurrentValue = S.TargetNPCs, Flag = "TargetNPCs", Callback = function(v) S.TargetNPCs = v end})
SettingsTab:CreateToggle({Name = "Team Check", CurrentValue = S.TeamCheck, Flag = "TeamCheck", Callback = function(v) S.TeamCheck = v end})


SettingsTab:CreateSection("Player Registry")
SettingsTab:CreateParagraph({
    Title   = "Blacklist & Priority",
    Content = "Blacklisted players are ignored by all targeting. Priority targets and Intel system controls have moved to the Intel tab."
})
SettingsTab:CreateDropdown({
    Name            = "Blacklist",
    Options         = S.GetPlayerNames and S.GetPlayerNames() or {},
    CurrentOption   = {},
    MultipleOptions = true,
    Flag            = "BlacklistPlayers",
    Callback        = function(v)
        -- Bug Fix #17: resolve display-name labels to real usernames
        local resolved = {}
        for _, label in ipairs(v) do
            local name = (S.ResolvePlayerName and S.ResolvePlayerName(label)) or label
            if name then table.insert(resolved, name) end
        end
        S.BlacklistedPlayers = resolved
        if S.CurrentTarget and S.CurrentTarget.Name and table.find(resolved, S.CurrentTarget.Name) then
            S.CurrentTarget = nil
        end
    end
})
SettingsTab:CreateToggle({
    Name         = "Hide Blacklisted Player ESP (off = show [BLACKLISTED] tag)",
    CurrentValue = S.HideBlacklistedESP,
    Flag         = "HideBlacklistedESP",
    Callback     = function(v) S.HideBlacklistedESP = v end
})
SettingsTab:CreateToggle({
    Name         = "ESP Whitelist",
    CurrentValue = S.ESPWhitelistEnabled,
    Flag         = "ESPWhitelistEnabled",
    Callback     = function(v) S.ESPWhitelistEnabled = v end
})
SettingsTab:CreateDropdown({
    Name            = "Whitelist Players",
    Options         = S.GetPlayerNames and S.GetPlayerNames() or {},
    CurrentOption   = {},
    MultipleOptions = true,
    Flag            = "ESPWhitelistDropdown",
    Callback        = function(v)
        -- Bug Fix #18: resolve display-name labels to real usernames
        local resolved = {}
        for _, label in ipairs(v) do
            local name = (S.ResolvePlayerName and S.ResolvePlayerName(label)) or label
            if name then table.insert(resolved, name) end
        end
        S.ESPWhitelist = resolved
    end
})


-- Wallcheck section moved to Settings tab below
SettingsTab:CreateSection("Targeting Constraints")
SettingsTab:CreateParagraph({Title = "Targeting Constraints", Content = "Environmental and geometry checks that gate whether a target can be locked. Line of Sight performs a raycast; foliage and transparency checks handle partial occlusion."})
SettingsTab:CreateToggle({Name = "Line of Sight", CurrentValue = S.WallCheck, Flag = "WallCheck", Callback = function(v) S.WallCheck = v end})
SettingsTab:CreateToggle({Name = "Skip Non-Collidable", CurrentValue = S.NoCollisionCheck, Flag = "NoCollisionCheck", Callback = function(v) S.NoCollisionCheck = v end})
SettingsTab:CreateToggle({Name = "Foliage Check", CurrentValue = S.FoliageConcealmentCheck, Flag = "FoliageConcealmentCheck", Callback = function(v) S.FoliageConcealmentCheck = v end})
SettingsTab:CreateToggle({Name = "Transparency Check", CurrentValue = S.TransparencyCheck, Flag = "TransparencyCheck", Callback = function(v) S.TransparencyCheck = v end})
SettingsTab:CreateSlider({Name = "Transparency Threshold", Range = {0.01, 1.0}, Increment = 0.05, CurrentValue = S.TransparencyThreshold, Flag = "TransparencyThreshold", Callback = function(v)
    S.TransparencyThreshold = v
end})
SettingsTab:CreateToggle({Name = "Ignore Decals", CurrentValue = S.DecalsCheck, Flag = "DecalsCheck", Callback = function(v) S.DecalsCheck = v end})

SettingsTab:CreateSection("Weapon Automation")
SettingsTab:CreateParagraph({
    Title   = "Smart Tool Management",
    Content = "Automatically toggle the aimbot based on what you are holding. Blacklist non-weapons (like food or potions) to prevent the aimbot from locking on while you are healing."
})
SettingsTab:CreateToggle({Name = "Auto-Engage on Equip", CurrentValue = S.AutoEnableOnEquip, Flag = "AutoEquipAim", Callback = function(v)
    S.AutoEnableOnEquip = v
end})
SettingsTab:CreateToggle({Name = "Auto-Disable on Death", CurrentValue = S.AutoDisableOnDeath, Flag = "AutoDisableOnDeath", Callback = function(v)
    S.AutoDisableOnDeath = v
end})
SettingsTab:CreateToggle({
    Name         = "Smart Equip Filter",
    CurrentValue = S.IntelligentEquipFilter,
    Flag         = "IntelligentEquipFilter",
    Callback     = function(v)
        S.IntelligentEquipFilter = v
        if not S._LoadingPreset and S.Notify then S.Notify({Title="TASFF Intel",Content=v and "Equip filter ON — non-weapons will not trigger aimbot." or "Equip filter OFF — all tools trigger aimbot.",Duration=2,Image="cpu"}) end
    end
})
SettingsTab:CreateToggle({
    Name         = "Weapon-Type Gating (Triggerbot/Melee Smart Block)",
    CurrentValue = S.WeaponTypeGating,
    Flag         = "WeaponTypeGating",
    Callback     = function(v)
        S.WeaponTypeGating = v
        if not S._LoadingPreset and S.Notify then S.Notify({Title="TASFF Intel",Content=v and "Type gating ON — melee won't triggerbot; ranged won't melee." or "Type gating OFF — all weapons use all features.",Duration=2,Image="cpu"}) end
    end
})



SettingsTab:CreateButton({
    Name     = "Blacklist Currently Equipped Tool",
    Callback = function()
        local char = Player.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then
            if not table.find(S.ToolBlacklist, tool.Name) then
                table.insert(S.ToolBlacklist, tool.Name)
                if BlacklistDropdown then
                    local newList = #S.ToolBlacklist > 0 and S.ToolBlacklist or {"No Registry Items Found"}
                    pcall(function() BlacklistDropdown:Refresh(newList, true) end)
                end
                if S.Notify then S.Notify({Title = "TASFF Arsenal", Content = "Blacklisted tool: " .. tool.Name, Duration = 3, Image = "ban"}) end
            else
                if S.Notify then S.Notify({Title = "TASFF Arsenal", Content = tool.Name .. " is already blacklisted.", Duration = 2, Image = "info"}) end
            end
        else
            if S.Notify then S.Notify({Title = "TASFF Arsenal", Content = "You are not holding a tool.", Duration = 2, Image = "alert-circle"}) end
        end
    end
})

BlacklistDropdown = SettingsTab:CreateDropdown({
    Name          = "Blacklisted Weapons Registry",
    Options       = #S.ToolBlacklist > 0 and S.ToolBlacklist or {"No Registry Items Found"},
    CurrentOption = {"No Registry Items Found"},
    Flag          = "ToolBlacklistDropdown",
    Callback      = function(v) SelectedBlacklistTool = type(v) == "table" and v[1] or v end
})
S.BlacklistDropdownRef = BlacklistDropdown

SettingsTab:CreateButton({
    Name     = "Remove Selected Tool from Registry",
    Callback = function()
        if SelectedBlacklistTool and SelectedBlacklistTool ~= "No Registry Items Found" then
            local idx = table.find(S.ToolBlacklist, SelectedBlacklistTool)
            if idx then
                table.remove(S.ToolBlacklist, idx)
                local newList = #S.ToolBlacklist > 0 and S.ToolBlacklist or {"No Registry Items Found"}
                if BlacklistDropdown then pcall(function() BlacklistDropdown:Refresh(newList, true) end) end
                if S.Notify then S.Notify({Title = "TASFF Arsenal", Content = "Removed tool: " .. SelectedBlacklistTool, Duration = 3, Image = "check"}) end
                SelectedBlacklistTool = ""
            end
        else
            if S.Notify then S.Notify({Title = "TASFF Arsenal", Content = "Select a valid tool to remove.", Duration = 2, Image = "alert-triangle"}) end
        end
    end
})

SettingsTab:CreateButton({
    Name     = "Save Tool Registry to Disk",
    Callback = function()
        local saved = S.SaveToolBlacklist and S.SaveToolBlacklist()
        if S.Notify then
            S.Notify({
                Title = "TASFF Arsenal",
                Content = saved and "Tool registry saved to disk." or "Tool registry is active for this session, but could not be saved to disk.",
                Duration = 3,
                Image = saved and "save" or "alert-triangle",
            })
        end
    end
})

SettingsTab:CreateButton({
    Name     = "Clear Tool Registry",
    Callback = function()
        S.ToolBlacklist = {}
        if BlacklistDropdown then pcall(function() BlacklistDropdown:Refresh({"No Registry Items Found"}, true) end) end
        local saved = S.SaveToolBlacklist and S.SaveToolBlacklist()
        if S.Notify then
            S.Notify({
                Title = "TASFF Arsenal",
                Content = saved and "Tool registry cleared and saved." or "Tool registry cleared for this session; disk save failed.",
                Duration = 3,
                Image = saved and "trash" or "alert-triangle",
            })
        end
    end
})

-- // ============================================================ // --
-- //                       6. PRESETS TAB                         // --
-- // ============================================================ // --

local PresetsTab = Window:CreateTab("Presets", "folder-sync")

PresetsTab:CreateSection("Local Profile Management")
PresetsTab:CreateParagraph({
    Title   = "Configuration Profiles",
    Content = "Save your current setup (Aimbot, Visuals, Filtering, Logic) into a named preset. This allows you to rapidly swap between playstyles (e.g., 'Legit', 'Blatant', 'Rage')."
})
PresetsTab:CreateInput({
    Name                     = "Preset Name",
    PlaceholderText          = "Enter preset name...",
    RemoveTextAfterFocusLost = false,
    Flag                     = "PresetInputFlag",
    Callback                 = function(text) PresetInputName = text end
})

PresetsTab:CreateButton({
    Name     = "Save Current Configuration to Preset",
    Callback = function()
        if PresetInputName and PresetInputName ~= "" then
            S.SavedPresets[PresetInputName] = {
                -- Core & Combat
                MasterEnabled = S.MasterEnabled, TargetingEnabled = S.TargetingEnabled, Mode = S.Mode,
                TargetPart = S.TargetPart, VOSPriorityParts = S.VOSPriorityParts, PriorityMode = S.PriorityMode, VitalityMode = S.VitalityMode,
                TargetNearCenter = S.TargetNearCenter, Smoothness = S.Smoothness, PredictionAmount = S.PredictionAmount,
                SilentAimEnabled = S.SilentAimEnabled, DynamicRecoilEnabled = S.DynamicRecoilEnabled,
                RandomizeHitboxEnabled = S.RandomizeHitboxEnabled, TargetSwitchDelayEnabled = S.TargetSwitchDelayEnabled,
                SwitchDelayMs = S.SwitchDelayMs, GracePeriodEnabled = S.GracePeriodEnabled, GracePeriodMs = S.GracePeriodMs,
                AimbotRenderDistance = S.AimbotRenderDistance, StickyAimEnabled = S.StickyAimEnabled, AutoADSEnabled = S.AutoADSEnabled,
                HumanizedAimEnabled = S.HumanizedAimEnabled, AimPathCurvature = S.AimPathCurvature,
                AimDeadzoneRadius = S.AimDeadzoneRadius, HumanTremorEnabled = S.HumanTremorEnabled,
                HumanTremorIntensity = S.HumanTremorIntensity, TargetInertiaTracking = S.TargetInertiaTracking,
                HitboxOffsetDrift = S.HitboxOffsetDrift,
                DistancePredictionAdjustEnabled = S.DistancePredictionAdjustEnabled, MaxAutoPrediction = S.MaxAutoPrediction,
                CoverAnticipationEnabled = S.CoverAnticipationEnabled, CoverAnticipationDuration = S.CoverAnticipationDuration,
                -- Visuals & Overlays
                VisualMode = S.VisualMode, UseHighlight = S.UseHighlight, UseNPCHighlight = S.UseNPCHighlight,
                FocusMode = S.FocusMode, StreamProofESP = S.StreamProofESP, VisibilityColorsEnabled = S.VisibilityColorsEnabled,
                ESPRenderDistance = S.ESPRenderDistance, ChamsEnabled = S.ChamsEnabled, ChamsOpacity = S.ChamsOpacity,
                BoxModeEnabled = S.BoxModeEnabled, SkeletonModeEnabled = S.SkeletonModeEnabled, SnaplinesEnabled = S.SnaplinesEnabled,
                SnaplineOrigin = S.SnaplineOrigin, OOFArrowsEnabled = S.OOFArrowsEnabled, OOFArrowRadius = S.OOFArrowRadius, OOFArrowsPriorityOnly = S.OOFArrowsPriorityOnly,
                EnvironmentalESPEnabled = S.EnvironmentalESPEnabled, EnvironmentalESPPriorityOnly = S.EnvironmentalESPPriorityOnly, EnvironmentalESPRange = S.EnvironmentalESPRange,
                EnvironmentalESPDistanceFade = S.EnvironmentalESPDistanceFade, EnvironmentalESPTransparency = S.EnvironmentalESPTransparency,
                EnvironmentalESPAutoScaling = S.EnvironmentalESPAutoScaling, EnvironmentalESPMaxParts = S.EnvironmentalESPMaxParts,
                UseInfoTag = S.UseInfoTag, UseNPCInfoTag = S.UseNPCInfoTag, ShowDisplayName = S.ShowDisplayName, ShowToolCheck = S.ShowToolCheck,
                ShowFOV = S.ShowFOV, InvisibleFOV = S.InvisibleFOV, FOVSize = S.FOVSize, AimReferenceMode = S.AimReferenceMode,
                EnableCrosshair = S.EnableCrosshair, CrosshairStyle = S.CrosshairStyle, CrosshairSize = S.CrosshairSize,
                ManualCalibrationEnabled = S.ManualCalibrationEnabled, CalibrationOffsetX = S.CalibrationOffsetX, CalibrationOffsetY = S.CalibrationOffsetY,
                -- Triggerbot & Automation
                AutoClickEnabled = S.AutoClickEnabled, TriggerbotPriorityOnly = S.TriggerbotPriorityOnly, TriggerbotClickMode = S.TriggerbotClickMode, ClickMethod = S.ClickMethod,
                ClickInterval = S.ClickInterval, ThirdPersonTriggerbot = S.ThirdPersonTriggerbot, KeyTriggerbotEnabled = S.KeyTriggerbotEnabled,
                KeyTriggerMode = S.KeyTriggerMode, MeleeModeEnabled = S.MeleeModeEnabled, MeleeDetectionRange = S.MeleeDetectionRange,
                MeleeClickInterval = S.MeleeClickInterval,
                -- Advanced & Logic
                ThreatDetectorEnabled = S.ThreatDetectorEnabled, NemesisEnabled = S.NemesisEnabled, ThreatTimeout = S.ThreatTimeout,
                BlacklistExpiredThreats = S.BlacklistExpiredThreats, ClickToMarkEnabled = S.ClickToMarkEnabled, MarkMethod = S.MarkMethod,
                KillCountThreatEnabled = S.KillCountThreatEnabled, KillFeedEnabled = S.KillFeedEnabled, KillsBeforeThreat = S.KillsBeforeThreat, ContinuousKillsPermanent = S.ContinuousKillsPermanent, KillsBeforeNemesis = S.KillsBeforeNemesis, ThreatNeutralizationEnabled = S.ThreatNeutralizationEnabled, AutoExpireOnDisconnect = S.AutoExpireOnDisconnect,
                DeepThreatScanEnabled = S.DeepThreatScanEnabled, StatCorrelatorEnabled = S.StatCorrelatorEnabled, IgnoreThreatVictims = S.IgnoreThreatVictims,
                OtherPlayersDamageTracking = S.OtherPlayersDamageTracking, ExpertInstinctsEnabled = S.ExpertInstinctsEnabled, ExpertInstinctsIntensity = S.ExpertInstinctsIntensity,
                InstinctsMode = S.InstinctsMode,
                InstinctsInventoryCheck = S.InstinctsInventoryCheck,
                InstinctsAutoEquip = S.InstinctsAutoEquip,
                InstinctsFirstPersonCamera = S.InstinctsFirstPersonCamera,
                AutoUpdateCheckerEnabled = S.AutoUpdateCheckerEnabled,
                PriorityBehavior = S.PriorityBehavior or (S.StrictPrioritize and "Exclusive" or "Boost"),
                StrictPrioritize = S.StrictPrioritize, WallCheck = S.WallCheck, NoCollisionCheck = S.NoCollisionCheck,
                FoliageConcealmentCheck = S.FoliageConcealmentCheck,
                TransparencyCheck = S.TransparencyCheck, TransparencyThreshold = S.TransparencyThreshold, DecalsCheck = S.DecalsCheck,
                -- Settings & Entities
                TargetPlayers = S.TargetPlayers, TargetNPCs = S.TargetNPCs, TeamCheck = S.TeamCheck,
                AutoEnableOnEquip = S.AutoEnableOnEquip, IgnoreDead = S.IgnoreDead,
                RapidModeCycleEnabled = S.RapidModeCycleEnabled, RapidModeCycleKey = S.RapidModeCycleKey,
                QuickPresetSwitchEnabled = S.QuickPresetSwitchEnabled, QuickPresetSwitchKey = S.QuickPresetSwitchKey,
                MasterSwitchKeybind = S.MasterSwitchKeybind,
                -- Advanced aim parameters
                SmoothnessX = S.SmoothnessX, SmoothnessY = S.SmoothnessY, BlatantSnapSpeed = S.BlatantSnapSpeed,
                DynamicFOVEnabled = S.DynamicFOVEnabled, DynamicFOVMax = S.DynamicFOVMax,
                -- Health gating
                HealthThresholdEnabled = S.HealthThresholdEnabled, HealthThreshold = S.HealthThreshold,
                -- Visual feedback
                ShowLockIndicators = S.ShowLockIndicators, KillFlashDuration = S.KillFlashDuration,
                KillConfirmFlashEnabled = S.KillConfirmFlashEnabled,
                AutoDisableOnDeath = S.AutoDisableOnDeath,
                HideBlacklistedESP = S.HideBlacklistedESP,
                -- Equip intelligence
                IntelligentEquipFilter = S.IntelligentEquipFilter, WeaponTypeGating = S.WeaponTypeGating,
                ESPWhitelistEnabled = S.ESPWhitelistEnabled,
                ThreatProximityRadius = S.ThreatProximityRadius, ThreatFPCooldown = S.ThreatFPCooldown,
                DisableNotifications = S.DisableNotifications, NotificationDuration = S.NotificationDuration,
                NotifyMaxPer3s = S.NotifyMaxPer3s, SuppressRayfieldAds = S.SuppressRayfieldAds,
            }
            for _, field in ipairs(ColorFields) do
                if typeof(S[field]) == "Color3" then
                    S.SavedPresets[PresetInputName][field] = EncodeColor(S[field])
                end
            end
            local saved = S.SavePresetsToFile and S.SavePresetsToFile()
            if PresetDropdownRef and PresetDropdownRef.Refresh then
                pcall(function() PresetDropdownRef:Refresh(GetPresetNamesList(), true) end)
            end
            if S.Notify then
                S.Notify({
                    Title = "TASFF Presets",
                    Content = saved and ("Saved profile: " .. PresetInputName)
                        or ("Profile added for this session, but could not be saved to disk: " .. PresetInputName),
                    Duration = 4,
                    Image = saved and "folder-plus" or "alert-triangle",
                })
            end
        end
    end
})

PresetDropdownRef = PresetsTab:CreateDropdown({
    Name          = "Saved Profiles Database",
    Options       = GetPresetNamesList(),
    CurrentOption = {"No Profiles Found"},
    Flag          = "PresetSelectDropdown",
    Callback      = function(v)
        SelectedPresetToManage = type(v) == "table" and v[1] or v
        if UpdatePresetStatusDisplay then pcall(UpdatePresetStatusDisplay) end
    end
})

local STO_FLAG = {
    MasterEnabled = "MasterSwitch", TargetingEnabled = "TargetSystemToggle", Mode = "AimMethod",
    AimbotKeybind = "AimbotKeybind", TargetPart = "TargetPart", VOSPriorityParts = "VOSPriorityParts", PriorityMode = "PriorityMode",
    VitalityMode = "VitalityMode", TargetNearCenter = "TargetNearCenter", Smoothness = "SmoothSpeed",
    PredictionAmount = "PredIntense", SilentAimEnabled = "SilentAimEnabled", DynamicRecoilEnabled = "DynamicRecoil",
    RandomizeHitboxEnabled = "RandomizeHitbox", TargetSwitchDelayEnabled = "TargetSwitchDelay", SwitchDelayMs = "SwitchDelayMs",
    GracePeriodEnabled = "EnableGracePeriod", GracePeriodMs = "GracePeriodMs", AimbotRenderDistance = "AimbotRenderDist",
    StickyAimEnabled = "StickyAim", AutoADSEnabled = "AutoADS", VisualMode = "VisualMode", UseHighlight = "UseHighlight",
    UseNPCHighlight = "UseNPCHighlight", FocusMode = "FocusMode", StreamProofESP = "StreamProofESP",
    VisibilityColorsEnabled = "VisibilityColorsEnabled", ESPRenderDistance = "ESPRenderDist", ChamsEnabled = "EnableChamsMode",
    ChamsOpacity = "ChamsOpacity", BoxModeEnabled = "EnableBoxMode", SkeletonModeEnabled = "EnableSkeletonMode",
    SnaplinesEnabled = "SnaplinesEnabled", SnaplineOrigin = "SnaplineOrigin", OOFArrowsEnabled = "OOFArrowsEnabled",
    OOFArrowRadius = "OOFArrowRadius", UseInfoTag = "UseInfoTag", UseNPCInfoTag = "UseNPCInfoTag", ShowDisplayName = "ShowDisplay",
    ShowToolCheck = "UseToolCheck", ShowFOV = "ShowFOV", InvisibleFOV = "InvisibleFOV", FOVSize = "FOVSize",
    AimReferenceMode = "AimReferenceMode", EnableCrosshair = "UseCrosshair", CrosshairStyle = "CrossStyle",
    CrosshairSize = "CrossSize", ManualCalibrationEnabled = "EnableCalibration", CalibrationOffsetX = "CalibrationX",
    CalibrationOffsetY = "CalibrationY", AutoClickEnabled = "EnableTriggerbot", TriggerbotPriorityOnly = "TriggerbotPriorityOnly",
    TriggerbotClickMode = "TriggerbotClickMode",
    ClickMethod = "ClickMethod", ClickInterval = "ClickInterval", ThirdPersonTriggerbot = "ThirdPersonTriggerbot",
    KeyTriggerbotEnabled = "KeyTriggerbotToggle", KeyTriggerMode = "KeyTriggerMode", MeleeModeEnabled = "EnableMeleeMode",
    MeleeDetectionRange = "MeleeRange", MeleeClickInterval = "MeleeClickInterval", ThreatDetectorEnabled = "ThreatDetector",
    NemesisEnabled = "NemesisEnabled", ThreatTimeout = "ThreatTimeout", BlacklistExpiredThreats = "BlacklistExpiredThreats",
    ClickToMarkEnabled = "ClickToMark", MarkMethod = "MarkMethod", PriorityBehavior = "PriorityBehavior", StrictPrioritize = "StrictPrioritize", WallCheck = "WallCheck",
    KillCountThreatEnabled = "KillCountThreat", KillFeedEnabled = "KillFeedEnabled", KillsBeforeThreat = "KillsBeforeThreat",
    ContinuousKillsPermanent = "ContinuousKillsPermanent", KillsBeforeNemesis = "KillsBeforeNemesis", ThreatNeutralizationEnabled = "ThreatNeutralization",
    NoCollisionCheck = "NoCollisionCheck", TransparencyCheck = "TransparencyCheck", TransparencyThreshold = "TransparencyThreshold",
    DecalsCheck = "DecalsCheck", TargetPlayers = "TargetPlayers", TargetNPCs = "TargetNPCs", TeamCheck = "TeamCheck",
    AutoEnableOnEquip = "AutoEquipAim", IgnoreDead = "IgnoreDead",
    DeepThreatScanEnabled = "DeepThreatScan", StatCorrelatorEnabled = "StatCorrelator",
    IgnoreThreatVictims = "IgnoreThreatVictims", OOFArrowsPriorityOnly = "OOFArrowsPriorityOnly",
    HumanizedAimEnabled = "HumanizedAim", AimPathCurvature = "AimCurvature", AimDeadzoneRadius = "AimDeadzone",
    HumanTremorEnabled = "HumanTremor", HumanTremorIntensity = "TremorIntensity",
    TargetInertiaTracking = "TargetInertia", HitboxOffsetDrift = "HitboxDrift",
    DistancePredictionAdjustEnabled = "DistancePredictionAdjustEnabled", MaxAutoPrediction = "MaxAutoPrediction",
    CoverAnticipationEnabled = "CoverAnticipationEnabled", CoverAnticipationDuration = "CoverAnticipationDuration",
    EnvironmentalESPEnabled = "EnvironmentalESPEnabled", EnvironmentalESPPriorityOnly = "EnvironmentalESPPriorityOnly",
    EnvironmentalESPDistanceFade = "EnvironmentalESPDistanceFade", EnvironmentalESPTransparency = "EnvironmentalESPTransparency",
    EnvironmentalESPRange = "EnvironmentalESPRange", EnvironmentalESPAutoScaling = "EnvironmentalESPAutoScaling",
    EnvironmentalESPMaxParts = "EnvironmentalESPMaxParts", FoliageConcealmentCheck = "FoliageConcealmentCheck",
    OtherPlayersDamageTracking = "OtherPlayersDamageTracking", ExpertInstinctsEnabled = "ExpertInstinctsEnabled",
    ExpertInstinctsIntensity = "ExpertInstinctsIntensity", InstinctsInventoryCheck = "InstinctsInventoryCheck",
    InstinctsAutoEquip = "InstinctsAutoEquip", InstinctsFirstPersonCamera = "InstinctsFirstPersonCamera",
    InstinctsMode = "InstinctsMode",
    AutoUpdateCheckerEnabled = "AutoUpdateChecker",
    RapidModeCycleEnabled = "RapidModeCycle",
    RapidModeCycleKey = "RapidModeCycleKey",
    QuickPresetSwitchEnabled = "QuickPresetSwitchToggle",
    QuickPresetSwitchKey = "QuickPresetSwitchKey",
    MasterSwitchKeybind = "MasterSwitchKeybind",
    -- Combat/Visual/Settings flags whose Rayfield Flag name matches the state key exactly (previously missing)
    SmoothnessX = "SmoothnessX", SmoothnessY = "SmoothnessY", BlatantSnapSpeed = "BlatantSnapSpeed",
    DynamicFOVEnabled = "DynamicFOVEnabled", DynamicFOVMax = "DynamicFOVMax",
    HealthThresholdEnabled = "HealthThresholdEnabled", HealthThreshold = "HealthThreshold",
    ShowLockIndicators = "ShowLockIndicators", KillFlashDuration = "KillFlashDuration",
    KillConfirmFlashEnabled = "KillConfirmFlash",
    AutoDisableOnDeath = "AutoDisableOnDeath", AutoExpireOnDisconnect = "AutoExpireOnDisconnect",
    HideBlacklistedESP = "HideBlacklistedESP", IntelligentEquipFilter = "IntelligentEquipFilter",
    WeaponTypeGating = "WeaponTypeGating",
    ESPWhitelistEnabled = "ESPWhitelistEnabled",
    ThreatProximityRadius = "ThreatProximityRadius", ThreatFPCooldown = "ThreatFPCooldown",
    DisableNotifications = "DisableNotifications", NotificationDuration = "NotificationDuration",
    NotifyMaxPer3s = "NotifyThrottle",
    SuppressRayfieldAds = "SuppressRayfieldAds",
    HUDStripEnabled = "HUDStripEnabled", RadarEnabled = "RadarEnabled",
    SidebarEnabled = "SidebarEnabled", KeyboardNavEnabled = "KeyboardNavEnabled",
    CompactModeEnabled = "CompactModeEnabled", MobileModeEnabled = "MobileModeEnabled",
    UIOpacity = "WindowOpacity",
}

local DROPDOWN_FLAGS = {
    AimMethod = true, TargetPart = true, VOSPriorityParts = true, PriorityMode = true,
    VitalityMode = true, VisualMode = true, SnaplineOrigin = true,
    AimReferenceMode = true, CrossStyle = true, TriggerbotClickMode = true,
    ClickMethod = true, KeyTriggerMode = true, MarkMethod = true,
    InstinctsMode = true, PerformanceMode = true, PriorityBehavior = true,
}

local function LoadPresetByName(presetName, silent)
    if not presetName or type(presetName) ~= "string" then return false end
    local data = S.SavedPresets and S.SavedPresets[presetName]
    if not data then return false end

    S._LoadingPreset = true

    for key, value in pairs(data) do 
        local color = table.find(ColorFields, key) and DecodeColor(value)
        local flag = STO_FLAG[key]
        if color then
            SetColor(key, color)
            local colorFlag = ColorFlagMap[key]
            if colorFlag and Rayfield.Flags[colorFlag] then
                pcall(function() Rayfield.Flags[colorFlag]:Set(color) end)
            end
        else
            -- 1. Always assign state directly so backend logic receives valid value immediately
            S[key] = value

            -- 2. Synchronize UI element safely
            if flag and Rayfield.Flags[flag] then
                pcall(function()
                    local flagObj = Rayfield.Flags[flag]
                    if DROPDOWN_FLAGS[flag] or (flagObj and type(flagObj.CurrentOption) == "table") then
                        local opt = type(value) == "table" and value or {tostring(value)}
                        flagObj:Set(opt)
                    else
                        flagObj:Set(value)
                    end
                end)
            end
        end
    end

    -- 3. Explicitly maintain ActivePartName consistency
    if type(S.TargetPart) == "string" and S.TargetPart ~= "" and S.TargetPart ~= "Visible On Screen" then
        S.ActivePartName = S.TargetPart
    else
        S.ActivePartName = "Head"
    end

    -- 4. Ensure Mode is always valid
    if type(S.Mode) ~= "string" or S.Mode == "" then
        S.Mode = "Legit (Camera)"
    end

    -- 5. Ensure VOSPriorityParts is always valid
    if type(S.VOSPriorityParts) ~= "table" or #S.VOSPriorityParts == 0 then
        S.VOSPriorityParts = {"Head", "Torso"}
    end

    -- 6. Ensure PriorityBehavior & StrictPrioritize synchronization
    if S.PriorityBehavior then
        S.StrictPrioritize = (S.PriorityBehavior == "Exclusive")
    elseif S.StrictPrioritize ~= nil then
        S.PriorityBehavior = S.StrictPrioritize and "Exclusive" or "Boost"
    else
        S.PriorityBehavior = "Boost"
        S.StrictPrioritize = false
    end
    if Rayfield and Rayfield.Flags then
        if Rayfield.Flags["PriorityBehavior"] then
            pcall(function() Rayfield.Flags["PriorityBehavior"]:Set({S.PriorityBehavior}) end)
        end
        if Rayfield.Flags["StrictPrioritize"] then
            pcall(function() Rayfield.Flags["StrictPrioritize"]:Set(S.StrictPrioritize) end)
        end
    end

    -- 7. Invalidate runtime targeting & visibility caches so the new preset settings apply instantly
    S.CurrentTarget = nil
    S.LastCustomTargetData = nil
    S.SilentAimTargetCache = nil
    if S.VisibilityPrecomputed then table.clear(S.VisibilityPrecomputed) end
    if S.VisibilityCache then table.clear(S.VisibilityCache) end
    if S.VisibilityCacheTime then table.clear(S.VisibilityCacheTime) end
    if S.AimbotCandidates then table.clear(S.AimbotCandidates) end
    if S.TargetFirstSeenTimestamps then table.clear(S.TargetFirstSeenTimestamps) end

    S.ActivePresetName = presetName
    SelectedPresetToManage = presetName
    if PresetDropdownRef and PresetDropdownRef.Set then
        pcall(function() PresetDropdownRef:Set({presetName}) end)
    end
    if UpdatePresetStatusDisplay then
        pcall(UpdatePresetStatusDisplay)
    end

    S._LoadingPreset = false

    if not silent then
        if S.Notify then
            S.Notify({
                Title          = "TASFF Presets",
                Content        = "Loaded profile: " .. presetName,
                Duration       = 3,
                Image          = "folder",
                BypassThrottle = true,
                Important      = true,
                BypassSilence  = true,
            })
        else
            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title    = "Profile Loaded",
                    Text     = presetName,
                    Duration = 3,
                })
            end)
        end
    end
    return true
end
S.LoadPresetByName = LoadPresetByName

local function CycleToNextPreset()
    local names = {}
    if S.SavedPresets then
        for k, _ in pairs(S.SavedPresets) do
            if type(k) == "string" and k ~= "No Profiles Found" and k ~= "" then
                table.insert(names, k)
            end
        end
    end
    table.sort(names)

    if #names == 0 then
        if S.Notify then
            S.Notify({
                Title          = "TASFF Presets",
                Content        = "No saved profiles available to switch between.",
                Duration       = 2.5,
                Image          = "alert-circle",
                BypassThrottle = true,
                Important      = true,
                BypassSilence  = true,
            })
        end
        return
    end

    local cur = S.ActivePresetName or ""
    local idx = table.find(names, cur) or 0
    local nextIdx = (idx % #names) + 1
    local nextName = names[nextIdx]

    LoadPresetByName(nextName, false)
end
S.CycleToNextPreset = CycleToNextPreset

PresetsTab:CreateButton({
    Name     = "Load Selected Profile",
    Callback = function()
        local selected = PresetDropdownRef and PresetDropdownRef.CurrentOption
        if type(selected) == "table" then
            local k,v = next(selected)
            selected = (type(v) == "boolean" and v) and k or (type(v) == "string" and v) or selected[1]
        end
        if not selected or selected == "" then selected = SelectedPresetToManage end
        
        if selected and S.SavedPresets[selected] then
            LoadPresetByName(selected, false)
        else
            if S.Notify then S.Notify({Title = "TASFF Presets", Content = "No valid profile selected.", Duration = 2, Image = "alert-circle"}) end
        end
    end
})

PresetsTab:CreateButton({
    Name     = "Delete Selected Profile",
    Callback = function()
        local selected = PresetDropdownRef and PresetDropdownRef.CurrentOption
        if type(selected) == "table" then
            local k,v = next(selected)
            selected = (type(v) == "boolean" and v) and k or (type(v) == "string" and v) or selected[1]
        end
        if not selected or selected == "" then selected = SelectedPresetToManage end

        if selected and selected ~= "No Profiles Found" and S.SavedPresets[selected] then
            S.SavedPresets[selected] = nil
            local saved = S.SavePresetsToFile and S.SavePresetsToFile()
            if PresetDropdownRef and PresetDropdownRef.Refresh then
                local list = GetPresetNamesList()
                pcall(function() PresetDropdownRef:Refresh(list, true) end)
            end
            if S.Notify then
                S.Notify({
                    Title = "TASFF Presets",
                    Content = saved and ("Deleted profile: " .. selected)
                        or ("Profile deleted for this session, but the disk save failed: " .. selected),
                    Duration = 4,
                    Image = saved and "folder-minus" or "alert-triangle",
                })
            end
            SelectedPresetToManage = ""
        else
            if S.Notify then S.Notify({Title = "TASFF Presets", Content = "No valid profile selected to delete.", Duration = 2, Image = "alert-triangle"}) end
        end
    end
})

PresetsTab:CreateButton({
    Name     = "Override Selected Profile with Current Settings",
    Callback = function()
        local selected = PresetDropdownRef and PresetDropdownRef.CurrentOption
        if type(selected) == "table" then
            local k,v = next(selected)
            selected = (type(v) == "boolean" and v) and k or (type(v) == "string" and v) or selected[1]
        end
        if not selected or selected == "" then selected = SelectedPresetToManage end

        if selected and selected ~= "No Profiles Found" and S.SavedPresets[selected] then
            S.SavedPresets[selected] = {
                -- Core & Combat
                MasterEnabled = S.MasterEnabled, TargetingEnabled = S.TargetingEnabled, Mode = S.Mode,
                TargetPart = S.TargetPart, VOSPriorityParts = S.VOSPriorityParts, PriorityMode = S.PriorityMode, VitalityMode = S.VitalityMode,
                TargetNearCenter = S.TargetNearCenter, Smoothness = S.Smoothness, PredictionAmount = S.PredictionAmount,
                SilentAimEnabled = S.SilentAimEnabled, DynamicRecoilEnabled = S.DynamicRecoilEnabled,
                RandomizeHitboxEnabled = S.RandomizeHitboxEnabled, TargetSwitchDelayEnabled = S.TargetSwitchDelayEnabled,
                SwitchDelayMs = S.SwitchDelayMs, GracePeriodEnabled = S.GracePeriodEnabled, GracePeriodMs = S.GracePeriodMs,
                AimbotRenderDistance = S.AimbotRenderDistance, StickyAimEnabled = S.StickyAimEnabled, AutoADSEnabled = S.AutoADSEnabled,
                HumanizedAimEnabled = S.HumanizedAimEnabled, AimPathCurvature = S.AimPathCurvature,
                AimDeadzoneRadius = S.AimDeadzoneRadius, HumanTremorEnabled = S.HumanTremorEnabled,
                HumanTremorIntensity = S.HumanTremorIntensity, TargetInertiaTracking = S.TargetInertiaTracking,
                HitboxOffsetDrift = S.HitboxOffsetDrift,
                DistancePredictionAdjustEnabled = S.DistancePredictionAdjustEnabled, MaxAutoPrediction = S.MaxAutoPrediction,
                CoverAnticipationEnabled = S.CoverAnticipationEnabled, CoverAnticipationDuration = S.CoverAnticipationDuration,
                -- Visuals & Overlays
                VisualMode = S.VisualMode, UseHighlight = S.UseHighlight, UseNPCHighlight = S.UseNPCHighlight,
                FocusMode = S.FocusMode, StreamProofESP = S.StreamProofESP, VisibilityColorsEnabled = S.VisibilityColorsEnabled,
                ESPRenderDistance = S.ESPRenderDistance, ChamsEnabled = S.ChamsEnabled, ChamsOpacity = S.ChamsOpacity,
                BoxModeEnabled = S.BoxModeEnabled, SkeletonModeEnabled = S.SkeletonModeEnabled, SnaplinesEnabled = S.SnaplinesEnabled,
                SnaplineOrigin = S.SnaplineOrigin, OOFArrowsEnabled = S.OOFArrowsEnabled, OOFArrowRadius = S.OOFArrowRadius, OOFArrowsPriorityOnly = S.OOFArrowsPriorityOnly,
                EnvironmentalESPEnabled = S.EnvironmentalESPEnabled, EnvironmentalESPPriorityOnly = S.EnvironmentalESPPriorityOnly, EnvironmentalESPRange = S.EnvironmentalESPRange,
                EnvironmentalESPDistanceFade = S.EnvironmentalESPDistanceFade, EnvironmentalESPTransparency = S.EnvironmentalESPTransparency,
                EnvironmentalESPAutoScaling = S.EnvironmentalESPAutoScaling, EnvironmentalESPMaxParts = S.EnvironmentalESPMaxParts,
                UseInfoTag = S.UseInfoTag, UseNPCInfoTag = S.UseNPCInfoTag, ShowDisplayName = S.ShowDisplayName, ShowToolCheck = S.ShowToolCheck,
                ShowFOV = S.ShowFOV, InvisibleFOV = S.InvisibleFOV, FOVSize = S.FOVSize, AimReferenceMode = S.AimReferenceMode,
                EnableCrosshair = S.EnableCrosshair, CrosshairStyle = S.CrosshairStyle, CrosshairSize = S.CrosshairSize,
                ManualCalibrationEnabled = S.ManualCalibrationEnabled, CalibrationOffsetX = S.CalibrationOffsetX, CalibrationOffsetY = S.CalibrationOffsetY,
                -- Triggerbot & Automation
                AutoClickEnabled = S.AutoClickEnabled, TriggerbotPriorityOnly = S.TriggerbotPriorityOnly, TriggerbotClickMode = S.TriggerbotClickMode, ClickMethod = S.ClickMethod,
                ClickInterval = S.ClickInterval, ThirdPersonTriggerbot = S.ThirdPersonTriggerbot, KeyTriggerbotEnabled = S.KeyTriggerbotEnabled,
                KeyTriggerMode = S.KeyTriggerMode, MeleeModeEnabled = S.MeleeModeEnabled, MeleeDetectionRange = S.MeleeDetectionRange,
                MeleeClickInterval = S.MeleeClickInterval,
                -- Advanced & Logic
                ThreatDetectorEnabled = S.ThreatDetectorEnabled, NemesisEnabled = S.NemesisEnabled, ThreatTimeout = S.ThreatTimeout,
                BlacklistExpiredThreats = S.BlacklistExpiredThreats, ClickToMarkEnabled = S.ClickToMarkEnabled, MarkMethod = S.MarkMethod,
                KillCountThreatEnabled = S.KillCountThreatEnabled, KillFeedEnabled = S.KillFeedEnabled, KillsBeforeThreat = S.KillsBeforeThreat, ContinuousKillsPermanent = S.ContinuousKillsPermanent, KillsBeforeNemesis = S.KillsBeforeNemesis, ThreatNeutralizationEnabled = S.ThreatNeutralizationEnabled, AutoExpireOnDisconnect = S.AutoExpireOnDisconnect,
                DeepThreatScanEnabled = S.DeepThreatScanEnabled, StatCorrelatorEnabled = S.StatCorrelatorEnabled, IgnoreThreatVictims = S.IgnoreThreatVictims,
                OtherPlayersDamageTracking = S.OtherPlayersDamageTracking, ExpertInstinctsEnabled = S.ExpertInstinctsEnabled, ExpertInstinctsIntensity = S.ExpertInstinctsIntensity,
                InstinctsMode = S.InstinctsMode,
                InstinctsInventoryCheck = S.InstinctsInventoryCheck,
                InstinctsAutoEquip = S.InstinctsAutoEquip,
                InstinctsFirstPersonCamera = S.InstinctsFirstPersonCamera,
                AutoUpdateCheckerEnabled = S.AutoUpdateCheckerEnabled,
                PriorityBehavior = S.PriorityBehavior or (S.StrictPrioritize and "Exclusive" or "Boost"),
                StrictPrioritize = S.StrictPrioritize, WallCheck = S.WallCheck, NoCollisionCheck = S.NoCollisionCheck,
                FoliageConcealmentCheck = S.FoliageConcealmentCheck,
                TransparencyCheck = S.TransparencyCheck, TransparencyThreshold = S.TransparencyThreshold, DecalsCheck = S.DecalsCheck,
                -- Settings & Entities
                TargetPlayers = S.TargetPlayers, TargetNPCs = S.TargetNPCs, TeamCheck = S.TeamCheck,
                AutoEnableOnEquip = S.AutoEnableOnEquip, IgnoreDead = S.IgnoreDead,
                RapidModeCycleEnabled = S.RapidModeCycleEnabled, RapidModeCycleKey = S.RapidModeCycleKey,
                QuickPresetSwitchEnabled = S.QuickPresetSwitchEnabled, QuickPresetSwitchKey = S.QuickPresetSwitchKey,
                MasterSwitchKeybind = S.MasterSwitchKeybind,
                -- Advanced aim parameters
                SmoothnessX = S.SmoothnessX, SmoothnessY = S.SmoothnessY, BlatantSnapSpeed = S.BlatantSnapSpeed,
                DynamicFOVEnabled = S.DynamicFOVEnabled, DynamicFOVMax = S.DynamicFOVMax,
                -- Health gating
                HealthThresholdEnabled = S.HealthThresholdEnabled, HealthThreshold = S.HealthThreshold,
                -- Visual feedback
                ShowLockIndicators = S.ShowLockIndicators, KillFlashDuration = S.KillFlashDuration,
                KillConfirmFlashEnabled = S.KillConfirmFlashEnabled,
                AutoDisableOnDeath = S.AutoDisableOnDeath,
                HideBlacklistedESP = S.HideBlacklistedESP,
                -- Equip intelligence
                IntelligentEquipFilter = S.IntelligentEquipFilter, WeaponTypeGating = S.WeaponTypeGating,
                ESPWhitelistEnabled = S.ESPWhitelistEnabled,
                ThreatProximityRadius = S.ThreatProximityRadius, ThreatFPCooldown = S.ThreatFPCooldown,
                DisableNotifications = S.DisableNotifications, NotificationDuration = S.NotificationDuration,
                NotifyMaxPer3s = S.NotifyMaxPer3s, SuppressRayfieldAds = S.SuppressRayfieldAds,
            }
            for _, field in ipairs(ColorFields) do
                if typeof(S[field]) == "Color3" then
                    S.SavedPresets[selected][field] = EncodeColor(S[field])
                end
            end
            local saved = S.SavePresetsToFile and S.SavePresetsToFile()
            if UpdatePresetStatusDisplay then pcall(UpdatePresetStatusDisplay) end
            if S.Notify then
                S.Notify({
                    Title = "TASFF Presets",
                    Content = saved and ("Overwrote profile: " .. selected)
                        or ("Profile overridden in memory, but could not be saved to disk: " .. selected),
                    Duration = 4,
                    Image = saved and "save" or "alert-triangle",
                })
            end
        else
            if S.Notify then S.Notify({Title = "TASFF Presets", Content = "No valid profile selected to override.", Duration = 2, Image = "alert-triangle"}) end
        end
    end
})

PresetsTab:CreateSection("Quick Profile Switching")
PresetsTab:CreateParagraph({
    Title   = "Rapid Profile Switcher",
    Content = "Cycle through all saved presets on the fly using a customizable keybind without opening the menu."
})
PresetsTab:CreateToggle({
    Name         = "Quick Preset Switching",
    CurrentValue = S.QuickPresetSwitchEnabled,
    Flag         = "QuickPresetSwitchToggle",
    Callback     = function(v) S.QuickPresetSwitchEnabled = v end
})
PresetsTab:CreateKeybind({
    Name           = "Quick Preset Switch Keybind",
    CurrentKeybind = S.QuickPresetSwitchKey or "J",
    HoldToInteract = false,
    CallOnChange   = true,
    Flag           = "QuickPresetSwitchKey",
    Callback       = function(key)
        local validKey = SanitizeKeyName(key)
        if validKey then
            S.QuickPresetSwitchKey = validKey
            if not S._LoadingPreset and S.Notify then
                S.Notify({
                    Title    = "TASFF Presets",
                    Content  = "Preset switch key set to [" .. tostring(validKey) .. "]",
                    Duration = 2,
                    Image    = "keyboard"
                })
            end
        end
    end
})

PresetsTab:CreateSection("Profile Feature Inspection")
local selectedPresetCategory = "Combat"
local PresetStatusParagraph = PresetsTab:CreateParagraph({
    Title   = "Preset Status — Combat",
    Content = "Select a profile from the dropdown above to view its configuration."
})

local function BuildPresetStatusContent(profileName, category)
    local data = profileName and S.SavedPresets and S.SavedPresets[profileName]
    if not data then return "No profile selected or profile data is empty." end

    local on, off = {}, {}
    local function check(label, flagVal)
        if flagVal == true then table.insert(on, "  [V] " .. label)
        else table.insert(off, "  [X] " .. label) end
    end

    if category == "Combat" then
        check("Master Switch",          data.MasterEnabled)
        check("Aimbot Engine",          data.TargetingEnabled)
        check("Silent Aim",             data.SilentAimEnabled)
        check("Sticky Aim",             data.StickyAimEnabled)
        check("Dynamic Recoil (DRC)",   data.DynamicRecoilEnabled)
        check("Auto ADS",               data.AutoADSEnabled)
        check("Randomize Hitboxes",     data.RandomizeHitboxEnabled)
        check("Target Near Center",     data.TargetNearCenter)
        check("Target Switch Delay",    data.TargetSwitchDelayEnabled)
        check("Grace Period",           data.GracePeriodEnabled)
        check("Triggerbot",             data.AutoClickEnabled)
        check("Triggerbot (Priority)",  data.TriggerbotPriorityOnly)
        check("Melee Mode",             data.MeleeModeEnabled)
        check("Humanized Legit Aim",    data.HumanizedAimEnabled)
        check("Physiological Tremor",   data.HumanTremorEnabled)
        check("Reaction Inertia",       data.TargetInertiaTracking)
        check("Hitbox Drift",           data.HitboxOffsetDrift)
        check("Distance Auto-Prediction", data.DistancePredictionAdjustEnabled)
    elseif category == "Visuals" then
        check("Highlights (Players)",   data.UseHighlight)
        check("Highlights (NPCs)",      data.UseNPCHighlight)
        check("Info Tags (Players)",    data.UseInfoTag)
        check("Info Tags (NPCs)",       data.UseNPCInfoTag)
        check("Snaplines",              data.SnaplinesEnabled)
        check("OOF Arrows",             data.OOFArrowsEnabled)
        check("OOF Arrows (Priority)",  data.OOFArrowsPriorityOnly)
        check("Box ESP",                data.BoxModeEnabled)
        check("Skeleton ESP",           data.SkeletonModeEnabled)
        check("Chams",                  data.ChamsEnabled)
        check("Visibility Colors",      data.VisibilityColorsEnabled)
        check("Show Display Name",      data.ShowDisplayName)
        check("Show Tool Check",        data.ShowToolCheck)
    elseif category == "Intel" then
        check("Threat Detector",        data.ThreatDetectorEnabled)
        check("Universal Damage Track", data.OtherPlayersDamageTracking)
        check("Expert Instincts",       data.ExpertInstinctsEnabled)
        if data.InstinctsMode then
            contentLines[#contentLines + 1] = "  Instincts Mode: " .. tostring(data.InstinctsMode)
        end
        check("Instincts Auto-Equip",   data.InstinctsAutoEquip)
        check("Instincts First-Person", data.InstinctsFirstPersonCamera)
        check("Nemesis System",         data.NemesisEnabled)
        check("Click-to-Mark",          data.ClickToMarkEnabled)
        check("Focus Mode ESP",         data.FocusMode)
        check("Wall Check",             data.WallCheck)
        check("Team Check",             data.TeamCheck)
        check("Target Players",         data.TargetPlayers)
        check("Target NPCs",            data.TargetNPCs)
        check("Deep Tag Scanner",       data.DeepThreatScanEnabled)
        check("Stat Correlator",        data.StatCorrelatorEnabled)
        check("Ignore Threat Victims",  data.IgnoreThreatVictims)
    elseif category == "Automation" then
        check("Auto-Engage on Equip",   data.AutoEnableOnEquip)
        check("FOV Circle",             data.ShowFOV)
        check("Invisible FOV",          data.InvisibleFOV)
    end

    local lines = {}
    if #on > 0 then
        table.insert(lines, "ENABLED (" .. profileName .. "):")
        for _, l in ipairs(on) do table.insert(lines, l) end
    end
    if #off > 0 then
        if #on > 0 then table.insert(lines, "") end
        table.insert(lines, "DISABLED (" .. profileName .. "):")
        for _, l in ipairs(off) do table.insert(lines, l) end
    end
    if #lines == 0 then return "No features in this category." end
    return table.concat(lines, "\n")
end

UpdatePresetStatusDisplay = function()  -- assigns to the forward-declared upvalue at the top of the file
    local selected = PresetDropdownRef and PresetDropdownRef.CurrentOption
    if type(selected) == "table" then
        local k,v = next(selected)
        selected = (type(v) == "boolean" and v) and k or (type(v) == "string" and v) or selected[1]
    end
    if not selected or selected == "" then selected = SelectedPresetToManage end
    local content = BuildPresetStatusContent(selected, selectedPresetCategory)
    local title = "Preset Status — " .. selectedPresetCategory .. (selected and selected ~= "" and (" (" .. selected .. ")") or "")
    pcall(function()
        PresetStatusParagraph:Set({Title = title, Content = content})
    end)
end

PresetsTab:CreateDropdown({
    Name          = "Inspect Preset Category",
    Options       = {"Combat", "Visuals", "Intel", "Automation"},
    CurrentOption = {"Combat"},
    Flag          = "InspectPresetCategory",
    Callback      = function(v)
        selectedPresetCategory = type(v) == "table" and v[1] or v or "Combat"
        UpdatePresetStatusDisplay()
    end
})

PresetsTab:CreateSection("Clipboard & Cloud Sharing")
PresetsTab:CreateParagraph({
    Title   = "Share Your Configurations",
    Content = "Export your entire preset database to your clipboard as a JSON string to share with friends, or paste their string below to import their setups."
})

PresetsTab:CreateButton({
    Name     = "Export Database to Clipboard",
    Callback = function()
        local sc = setclipboard or (getgenv and getgenv().setclipboard)
        if sc then
            sc(HttpService:JSONEncode(S.SavedPresets))
            if S.Notify then S.Notify({Title = "TASFF Configs", Content = "Saved all presets to clipboard! You can now paste and share.", Duration = 3, Image = "clipboard-copy"}) end
        else
            if S.Notify then S.Notify({Title = "TASFF Configs", Content = "Your executor does not support setclipboard.", Duration = 3, Image = "alert-octagon"}) end
        end
    end
})

PresetsTab:CreateButton({
    Name     = "Import Database from Clipboard",
    Callback = function()
        local gc = getclipboard or (getgenv and getgenv().getclipboard)
        if gc then
            local clipData = gc()
            if type(clipData) ~= "string" or clipData == "" then
                if S.Notify then S.Notify({Title = "Import Failed", Content = "Clipboard is empty or contains no text.", Duration = 3, Image = "file-warning"}) end
                return
            end
            local success, decoded = pcall(function() return HttpService:JSONDecode(clipData) end)
            if success and type(decoded) == "table" then
                for k, v in pairs(decoded) do S.SavedPresets[k] = v end
                local saved = S.SavePresetsToFile and S.SavePresetsToFile()
                if PresetDropdownRef and PresetDropdownRef.Refresh then
                    pcall(function() PresetDropdownRef:Refresh(GetPresetNamesList(), true) end)
                end
                if S.Notify then
                    S.Notify({
                        Title = "TASFF Configs",
                        Content = saved and "Presets added to disk database! Select from dropdown to load."
                            or "Presets added for this session, but could not be saved to disk.",
                        Duration = 4,
                        Image = saved and "clipboard-check" or "alert-triangle",
                    })
                end
            else
                if S.Notify then S.Notify({Title = "Import Failed", Content = "Invalid JSON string format in clipboard.", Duration = 3, Image = "file-warning"}) end
            end
        else
            if S.Notify then S.Notify({Title = "TASFF Configs", Content = "Your executor does not support getclipboard.", Duration = 3, Image = "alert-octagon"}) end
        end
    end
})

PresetsTab:CreateInput({
    Name                     = "Manual JSON Database Import",
    PlaceholderText          = "Paste raw JSON data here...",
    RemoveTextAfterFocusLost = true,
    Callback                 = function(text)
        if text and text ~= "" then
            local success, decoded = pcall(function() return HttpService:JSONDecode(text) end)
            if success and type(decoded) == "table" then
                for k, v in pairs(decoded) do S.SavedPresets[k] = v end
                local saved = S.SavePresetsToFile and S.SavePresetsToFile()
                if PresetDropdownRef and PresetDropdownRef.Refresh then
                    pcall(function() PresetDropdownRef:Refresh(GetPresetNamesList(), true) end)
                end
                if S.Notify then
                    S.Notify({
                        Title = "TASFF Configs",
                        Content = saved and "Profiles imported and saved! Select them from the dropdown above to load."
                            or "Profiles imported for this session, but could not be saved to disk.",
                        Duration = 4,
                        Image = saved and "file-check" or "alert-triangle",
                    })
                end
            else
                if S.Notify then S.Notify({Title = "Import Failed", Content = "Syntax Error: Invalid JSON structure.", Duration = 3, Image = "file-x"}) end
            end
        end
    end
})

-- // ============================================================ // --
-- //                       7. THEMING TAB                         // --
-- // ============================================================ // --

local CustomizationTab = Window:CreateTab("Theming", "brush")

local GlobalThemeMonitor
local function UpdateWindowTitle(themeName)
    local main = Rayfield.Main
    local topbar = main and main:FindFirstChild("Topbar")
    local title = topbar and topbar:FindFirstChild("Title")
    if title and title:IsA("TextLabel") then
        title.Text = "TASFF 2.2.6 " .. themeName
    end
end
local function ColorFromHex(hex)
    local value = tonumber(string.gsub(hex, "^#", ""), 16)
    if not value then error("Invalid preset color: " .. tostring(hex)) end
    return Color3.fromRGB(bit32.band(bit32.rshift(value, 16), 255), bit32.band(bit32.rshift(value, 8), 255), bit32.band(value, 255))
end
local function GetGlobalThemeColorName(color)
    local bestName, bestDistance, r, g, b = nil, math.huge, color.R, color.G, color.B
    for _, item in ipairs(GlobalThemeColorNames) do
        local swatch = item[2]
        local dr, dg, db = r - swatch.R, g - swatch.G, b - swatch.B
        local distance = dr * dr + dg * dg + db * db
        if distance < bestDistance then
            bestName, bestDistance = item[1], distance
        end
    end
    return bestName
end
local function FormatGlobalThemeColor(color)
    local r = math.floor(color.R * 255 + 0.5)
    local g = math.floor(color.G * 255 + 0.5)
    local b = math.floor(color.B * 255 + 0.5)
    return string.format("%s | #%02X%02X%02X", GetGlobalThemeColorName(color), r, g, b)
end
local function UpdateGlobalThemeMonitor(themeName)
    local palette = GlobalThemePalettes[themeName]
    if not palette then return end
    local lines = {}
    for _, entry in ipairs(GlobalThemeColorFields) do
        local color = ColorFromHex(palette[entry.role])
        table.insert(lines, entry.title .. " | " .. FormatGlobalThemeColor(color))
    end
    GlobalThemeMonitor:Set({
        Title = "Preset Preview - " .. themeName,
        Content = table.concat(lines, "\n"),
    })
    task.spawn(function()
        pcall(function()
            local pFrame = GlobalThemeMonitor and (GlobalThemeMonitor.Paragraph or GlobalThemeMonitor.Object)
            if pFrame and TASFFTheme and TASFFTheme.RenderThemePreviewCard then
                TASFFTheme.RenderThemePreviewCard(pFrame, themeName)
            end
        end)
    end)
end
GlobalThemeMonitor = CustomizationTab:CreateParagraph({
    Title = "Preset Preview — " .. selectedGlobalTheme,
    Content = "Select a theme to preview its visual and interface colors.",
})
local ThemeDropdown = CustomizationTab:CreateDropdown({
    Name = "Preset global UI themes",
    Options = GlobalThemeOptions,
    CurrentOption = {selectedGlobalTheme},
    Flag = "GlobalThemePreset",
    Callback = function(value)
        local themeName = type(value) == "table" and value[1] or value
        if type(themeName) ~= "string" or not GlobalThemePalettes[themeName] then
            warn("[TASFF UI] Ignoring unknown global theme selection: " .. tostring(themeName))
            return
        end
        selectedGlobalTheme = themeName
        UpdateGlobalThemeMonitor(selectedGlobalTheme)
        UpdateWindowTitle(selectedGlobalTheme)
        ScheduleColorSettingsSave()
    end,
})

-- Immediately trigger DOM styling on the global theme dropdown options
task.spawn(function()
    task.wait(0.2)
    pcall(function()
        if TASFFEnv and TASFFEnv.Theme and TASFFEnv.Theme.PatchRayfieldDOM then
            TASFFEnv.Theme.PatchRayfieldDOM()
        end
    end)
end)
UpdateGlobalThemeMonitor(selectedGlobalTheme)
UpdateWindowTitle(selectedGlobalTheme)
CustomizationTab:CreateButton({
    Name = "Apply Chosen Preset",
    Callback = function()
        local palette = GlobalThemePalettes[selectedGlobalTheme]
        if not palette then
            warn("[TASFF UI] Cannot apply unknown global theme: " .. tostring(selectedGlobalTheme))
            return
        end
        local themeFlagMap = {
            Background = "UIThemeBg",
            Topbar = "UIThemeTopbar",
            TabBackgroundSelected = "UIThemeAccent",
            ElementBackground = "UIThemeElemBg",
            TextColor = "UIThemeText",
        }
        for _, entry in ipairs(GlobalThemeColorFields) do
            local color = ColorFromHex(palette[entry.role])
            if entry.field then
                S[entry.field] = color
                local flag = ColorFlagMap[entry.field]
                local control = flag and Rayfield.Flags and Rayfield.Flags[flag]
                if control then control:Set(color) end
            elseif entry.themeField then
                ThemeColors[entry.themeField] = color
                local flag = themeFlagMap[entry.themeField]
                local control = Rayfield.Flags and Rayfield.Flags[flag]
                if control then control:Set(color) end
            end
        end
        -- Turn off all individual preset override toggles so the chosen theme's colors are active without override conflicts
        local PresetOverrideFlags = {
            "HighlightPresetToggle", "FOVPresetToggle", "CrosshairPresetToggle",
            "BoxPresetToggle", "SkelPresetToggle", "SnapPresetToggle",
            "PrioPresetToggle", "ThreatPresetToggle", "NemesisPresetToggle",
            "BlacklistPresetToggle", "ChamsPresetToggle", "KillFlashPresetToggle",
            "VisiblePresetToggle", "HiddenPresetToggle", "EnvESPPresetToggle",
        }
        for _, flag in ipairs(PresetOverrideFlags) do
            local ctrl = Rayfield.Flags and Rayfield.Flags[flag]
            if ctrl and ctrl.Set then
                pcall(function() ctrl:Set(false) end)
            end
        end

        if _G.UpdateFOVCircleColor then _G.UpdateFOVCircleColor(S.FOVColor) end
        if _G.UpdateCrosshairColor then _G.UpdateCrosshairColor(S.CrosshairColor) end
        UpdateWindowTitle(selectedGlobalTheme)
        ScheduleColorSettingsSave()

        -- Dynamic live theme repaint
        if Window and Window.ModifyTheme then
            pcall(function()
                Window.ModifyTheme({
                    TextColor                     = ThemeColors.TextColor,
                    Background                    = ThemeColors.Background,
                    Topbar                        = ThemeColors.Topbar,
                    Shadow                        = Color3.fromRGB(10, 10, 10),
                    NotificationBackground        = Color3.fromRGB(15, 15, 15),
                    NotificationActionsBackground = Color3.fromRGB(35, 35, 35),
                    TabBackground                 = Color3.fromRGB(25, 25, 25),
                    TabStroke                     = ThemeColors.ElementBackground,
                    TabBackgroundSelected         = ThemeColors.TabBackgroundSelected,
                    TabTextColor                  = ThemeColors.TextColor,
                    SelectedTabTextColor          = Color3.fromRGB(255, 255, 255),
                    ElementBackground             = ThemeColors.ElementBackground,
                    ElementBackgroundHover        = Color3.fromRGB(35, 35, 35),
                    SecondaryElementBackground    = Color3.fromRGB(20, 20, 20),
                    ElementStroke                 = Color3.fromRGB(40, 40, 40),
                    SecondaryElementStroke        = Color3.fromRGB(35, 35, 35),
                    SliderBackground              = ThemeColors.ElementBackground,
                    SliderProgress                = ThemeColors.TabBackgroundSelected,
                    SliderStroke                  = ThemeColors.TabBackgroundSelected,
                    ToggleBackground              = ThemeColors.ElementBackground,
                    ToggleEnabled                 = ThemeColors.TabBackgroundSelected,
                    ToggleDisabled                = Color3.fromRGB(60, 60, 60),
                    ToggleEnabledStroke           = ThemeColors.TabBackgroundSelected,
                    ToggleDisabledStroke          = Color3.fromRGB(80, 80, 80),
                    ToggleEnabledOuterStroke      = ThemeColors.TabBackgroundSelected,
                    ToggleDisabledOuterStroke     = Color3.fromRGB(45, 45, 45),
                    DropdownSelected              = ThemeColors.TabBackgroundSelected,
                    DropdownUnselected            = Color3.fromRGB(25, 25, 25),
                    InputBackground               = Color3.fromRGB(20, 20, 20),
                    InputStroke                   = ThemeColors.TabBackgroundSelected,
                    PlaceholderColor              = Color3.fromRGB(150, 150, 150),
                })
            end)
        end

        if S.Notify then
            S.Notify({
                Title = "Global Theme Applied",
                Content = selectedGlobalTheme .. " theme and visual colors applied live.",
                Duration = 4,
                Image = "palette",
            })
        end
    end,
})

-- Local helper: resolve preset color or keep nil if not using preset
local function applyPreset(useFlag, ddFlag, updater, field)
    if not useFlag then return end
    pcall(function()
        local f = Rayfield.Flags and Rayfield.Flags[ddFlag]
        if not f then return end
        local sel = type(f.CurrentOption) == "table" and f.CurrentOption[1] or f.CurrentOption
        local rgb = ColorPresetMap[sel]
        if rgb then
            if updater then updater(rgb) end
            if field then SetColor(field, rgb) end
        end
    end)
end

-- --- Section: General Base Colors -------------------------------------------
CustomizationTab:CreateSection("Base Colors")
CustomizationTab:CreateParagraph({Title = "Base Colors", Content = "Core color slots used for player highlights and info tags. Toggle the Preset switch to use a named swatch; use Custom (color picker) for full precision."})
CustomizationTab:CreateToggle({Name = "Preset Color: — Default Highlight & Tags", CurrentValue = false, Flag = "HighlightPresetToggle", Callback = function(v)
    applyPreset(v, "HighlightColorDd", nil, "HighlightColor")
end})
CustomizationTab:CreateDropdown({Name = "Color Preset: Default Highlight & Tags", Options = ColorDropdownOptions, CurrentOption = {"White"}, Flag = "HighlightColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["HighlightPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("HighlightColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Custom: Default Highlight & Tag Color", Color = S.HighlightColor or Color3.fromRGB(255,255,255), Flag = "HighlightColorPicker", Callback = function(Value) SetColor("HighlightColor", Value) end})

-- --- Section: On-Screen Overlays (FOV Circle & Crosshair) -----------------
CustomizationTab:CreateSection("Overlay Colors")
CustomizationTab:CreateParagraph({Title = "On-Screen Overlays", Content = "Color slots for the FOV circle and crosshair."})
CustomizationTab:CreateToggle({Name = "Preset Color: — FOV Circle", CurrentValue = false, Flag = "FOVPresetToggle", Callback = function(v)
    applyPreset(v, "FOVCircleColorDd", _G.UpdateFOVCircleColor, "FOVColor")
end})
CustomizationTab:CreateDropdown({Name = "Color Preset: FOV Circle", Options = ColorDropdownOptions, CurrentOption = {"White"}, Flag = "FOVCircleColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["FOVPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]
    if rgb and _G.UpdateFOVCircleColor then _G.UpdateFOVCircleColor(rgb) end
    if rgb then SetColor("FOVColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Custom: FOV Circle Color", Color = S.FOVColor or Color3.fromRGB(240,240,240), Flag = "FOVCircleColorPicker", Callback = function(Value)
    SetColor("FOVColor", Value)
    if _G.UpdateFOVCircleColor then _G.UpdateFOVCircleColor(Value) end
end})

CustomizationTab:CreateToggle({Name = "Preset Color: — Crosshair", CurrentValue = false, Flag = "CrosshairPresetToggle", Callback = function(v)
    applyPreset(v, "CrosshairColorDd", _G.UpdateCrosshairColor, "CrosshairColor")
end})
CustomizationTab:CreateDropdown({Name = "Color Preset: Crosshair", Options = ColorDropdownOptions, CurrentOption = {"White"}, Flag = "CrosshairColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["CrosshairPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]
    if rgb and _G.UpdateCrosshairColor then _G.UpdateCrosshairColor(rgb) end
    if rgb then SetColor("CrosshairColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Custom: Crosshair Color", Color = S.CrosshairColor or Color3.fromRGB(240,240,240), Flag = "CrosshairColorPicker", Callback = function(Value)
    SetColor("CrosshairColor", Value)
    if _G.UpdateCrosshairColor then _G.UpdateCrosshairColor(Value) end
end})

-- --- Section: Drawing Visuals (Box, Skeleton, Snaplines) ------------------
CustomizationTab:CreateSection("Drawing Colors")
CustomizationTab:CreateParagraph({Title = "Drawing Visuals", Content = "Color slots for Box ESP, Skeleton ESP, Snaplines, and OOF direction arrows."})
CustomizationTab:CreateToggle({Name = "Preset Color: — Box ESP", CurrentValue = false, Flag = "BoxPresetToggle", Callback = function(v)
    applyPreset(v, "BoxColorDd", nil, "BoxColor")
end})
CustomizationTab:CreateDropdown({Name = "Color Preset: Box ESP", Options = ColorDropdownOptions, CurrentOption = {"White"}, Flag = "BoxColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["BoxPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("BoxColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Custom: Box ESP Color", Color = S.BoxColor or Color3.fromRGB(200,200,200), Flag = "BoxESPColorPicker", Callback = function(Value) SetColor("BoxColor", Value) end})

CustomizationTab:CreateToggle({Name = "Preset Color: — Skeleton ESP", CurrentValue = false, Flag = "SkelPresetToggle", Callback = function(v)
    applyPreset(v, "SkelColorDd", nil, "SkeletonColor")
end})
CustomizationTab:CreateDropdown({Name = "Color Preset: Skeleton ESP", Options = ColorDropdownOptions, CurrentOption = {"White"}, Flag = "SkelColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["SkelPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("SkeletonColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Custom: Skeleton ESP Color", Color = S.SkeletonColor or Color3.fromRGB(200,200,200), Flag = "SkeletonESPColorPicker", Callback = function(Value) SetColor("SkeletonColor", Value) end})

CustomizationTab:CreateToggle({Name = "Preset Color: — Snaplines & OOF Arrows", CurrentValue = false, Flag = "SnapPresetToggle", Callback = function(v)
    applyPreset(v, "SnapColorDd", nil, "SnaplineColor")
end})
CustomizationTab:CreateDropdown({Name = "Color Preset: Snaplines & OOF Arrows", Options = ColorDropdownOptions, CurrentOption = {"White"}, Flag = "SnapColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["SnapPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("SnaplineColor", rgb); SetColor("OOFArrowColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Custom: Snapline Color", Color = S.SnaplineColor or Color3.fromRGB(200,200,200), Flag = "SnaplineFineColorPicker", Callback = function(Value) SetColor("SnaplineColor", Value) end})
CustomizationTab:CreateColorPicker({Name = "Custom: OOF Arrow Color", Color = S.OOFArrowColor or Color3.fromRGB(200,200,200), Flag = "OOFArrowColorPicker", Callback = function(Value) SetColor("OOFArrowColor", Value) end})

-- --- Section: Intel / Target Category Colors ------------------------------
CustomizationTab:CreateSection("Intel Colors")
CustomizationTab:CreateParagraph({Title = "Intel Category Colors", Content = "Distinct color slots for Priority, Threat, Nemesis, and Blacklisted player classifications."})
CustomizationTab:CreateToggle({Name = "Preset Color: — Priority Players", CurrentValue = false, Flag = "PrioPresetToggle", Callback = function(v)
    applyPreset(v, "PrioColorDd", nil, "PriorityHighlightColor")
end})
CustomizationTab:CreateDropdown({Name = "Color Preset: Priority Players", Options = ColorDropdownOptions, CurrentOption = {"Yellow"}, Flag = "PrioColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["PrioPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("PriorityHighlightColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Custom: Priority Player ESP Color", Color = S.PriorityHighlightColor or Color3.fromRGB(255,75,75), Flag = "PriorityHighlightColorPicker", Callback = function(Value) SetColor("PriorityHighlightColor", Value) end})

CustomizationTab:CreateToggle({Name = "Preset Color: — Threat Players", CurrentValue = false, Flag = "ThreatPresetToggle", Callback = function(v)
    applyPreset(v, "ThreatColorDd", nil, "ThreatHighlightColor")
end})
CustomizationTab:CreateDropdown({Name = "Color Preset: Threat Players", Options = ColorDropdownOptions, CurrentOption = {"Orange"}, Flag = "ThreatColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["ThreatPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("ThreatHighlightColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Custom: Threat Player ESP Color", Color = S.ThreatHighlightColor or Color3.fromRGB(255,120,60), Flag = "ThreatHighlightColorPicker", Callback = function(Value) SetColor("ThreatHighlightColor", Value) end})

CustomizationTab:CreateToggle({Name = "Preset Color: — Nemesis Players", CurrentValue = false, Flag = "NemesisPresetToggle", Callback = function(v)
    applyPreset(v, "NemesisColorDd", nil, "NemesisHighlightColor")
end})
CustomizationTab:CreateDropdown({Name = "Color Preset: Nemesis Players", Options = ColorDropdownOptions, CurrentOption = {"Purple"}, Flag = "NemesisColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["NemesisPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("NemesisHighlightColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Custom: Nemesis Player ESP Color", Color = S.NemesisHighlightColor or Color3.fromRGB(180,100,255), Flag = "NemesisHighlightColorPicker", Callback = function(Value) SetColor("NemesisHighlightColor", Value) end})

CustomizationTab:CreateToggle({Name = "Preset Color: — Blacklisted Players", CurrentValue = false, Flag = "BlacklistPresetToggle", Callback = function(v)
    applyPreset(v, "BlacklistColorDd", nil, "BlacklistedTagColor")
end})
CustomizationTab:CreateDropdown({Name = "Color Preset: Blacklisted Players", Options = ColorDropdownOptions, CurrentOption = {"Orange"}, Flag = "BlacklistColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["BlacklistPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("BlacklistedTagColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Custom: Blacklisted Player Tag Color", Color = S.BlacklistedTagColor or Color3.fromRGB(255,160,60), Flag = "BlacklistedTagColorPicker", Callback = function(Value) SetColor("BlacklistedTagColor", Value) end})

-- --- Section: Chams (Through-Wall) ----------------------------------------
CustomizationTab:CreateSection("Chams Color")
CustomizationTab:CreateParagraph({Title = "Chams Colors", Content = "Color for the Chams (through-wall) overlay. Chams applies a SelectionBox on the target visible through geometry."})
CustomizationTab:CreateToggle({Name = "Preset Color: — Chams", CurrentValue = false, Flag = "ChamsPresetToggle", Callback = function(v)
    applyPreset(v, "ChamsColorDd", nil, "ChamsColor")
end})
CustomizationTab:CreateDropdown({Name = "Color Preset: Chams Color", Options = ColorDropdownOptions, CurrentOption = {"White"}, Flag = "ChamsColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["ChamsPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("ChamsColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Custom: Chams Color", Color = S.ChamsColor or Color3.fromRGB(180,180,180), Flag = "ChamsColorPicker", Callback = function(Value) SetColor("ChamsColor", Value) end})
CustomizationTab:CreateSlider({Name = "Chams Opacity (0-100)", Range = {0, 100}, Increment = 1, CurrentValue = S.ChamsOpacity or 10, Flag = "ChamsOpacity", Callback = function(v) S.ChamsOpacity = v end})

-- --- Section: Kill Flash --------------------------------------------------
CustomizationTab:CreateSection("Kill Flash Color")
CustomizationTab:CreateParagraph({Title = "Kill Flash", Content = "Screen flash color triggered on confirmed kill. Enable Kill Flash in the Visuals tab; configure duration from there."})
CustomizationTab:CreateToggle({Name = "Preset Color: — Kill Confirmation Flash", CurrentValue = false, Flag = "KillFlashPresetToggle", Callback = function(v)
    applyPreset(v, "KillFlashColorDd", nil, "KillFlashColor")
end})
CustomizationTab:CreateDropdown({Name = "Color Preset: Kill Flash Color", Options = ColorDropdownOptions, CurrentOption = {"White"}, Flag = "KillFlashColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["KillFlashPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("KillFlashColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Custom: Kill Flash Color", Color = S.KillFlashColor or Color3.fromRGB(255,255,255), Flag = "KillFlashColorPicker", Callback = function(Value) SetColor("KillFlashColor", Value) end})


-- --- Section: Visibility Indicator Colors ---------------------------------
CustomizationTab:CreateSection("Visibility Colors")
CustomizationTab:CreateParagraph({Title = "Visibility Colors", Content = "Separate color slots for visible vs. hidden targets. Enables at-a-glance line-of-sight status from ESP overlays."})
CustomizationTab:CreateToggle({Name = "Preset Color: — Visible Target", CurrentValue = false, Flag = "VisiblePresetToggle", Callback = function(v)
    applyPreset(v, "VisibleColorDd", nil, "VisibleColor")
end})
CustomizationTab:CreateDropdown({Name = "Color Preset: Visible Target Color", Options = ColorDropdownOptions, CurrentOption = {"Lime"}, Flag = "VisibleColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["VisiblePresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("VisibleColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Custom: Visible Target Color", Color = S.VisibleColor or Color3.fromRGB(0,255,0), Flag = "VisibleColorPicker", Callback = function(Value) SetColor("VisibleColor", Value) end})

CustomizationTab:CreateToggle({Name = "Preset Color: — Hidden Target", CurrentValue = false, Flag = "HiddenPresetToggle", Callback = function(v)
    applyPreset(v, "HiddenColorDd", nil, "HiddenColor")
end})
CustomizationTab:CreateDropdown({Name = "Color Preset: Hidden Target Color", Options = ColorDropdownOptions, CurrentOption = {"Red"}, Flag = "HiddenColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["HiddenPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("HiddenColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Custom: Hidden Target Color", Color = S.HiddenColor or Color3.fromRGB(255,0,0), Flag = "HiddenColorPicker", Callback = function(Value) SetColor("HiddenColor", Value) end})

-- --- Section: Environmental ESP -------------------------------------------
CustomizationTab:CreateSection("Environmental ESP Color")
CustomizationTab:CreateParagraph({Title = "Environmental ESP Colors", Content = "Color for the Environmental ESP outline. Only shown when Environmental ESP is enabled (requires Key)."})
CustomizationTab:CreateToggle({Name = "Preset Color: — Environmental ESP", CurrentValue = false, Flag = "EnvESPPresetToggle", Callback = function(v)
    applyPreset(v, "EnvESPColorDd", nil, "EnvironmentalESPColor")
end})
CustomizationTab:CreateDropdown({Name = "Color Preset: Environmental ESP Color", Options = ColorDropdownOptions, CurrentOption = {"Cyan"}, Flag = "EnvESPColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["EnvESPPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("EnvironmentalESPColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Custom: Environmental ESP Color", Color = S.EnvironmentalESPColor or Color3.fromRGB(0,200,255), Flag = "EnvironmentalESPColorPicker", Callback = function(Value) SetColor("EnvironmentalESPColor", Value) end})

-- --- Section: UI Theme Editor ---------------------------------------------
CustomizationTab:CreateSection("UI Theme")
CustomizationTab:CreateParagraph({Title = "About UI Theme Editor", Content = "Theme colors are saved immediately and applied when the UI is next loaded. Rayfield does not expose a live theme update method."})
local function ApplyThemeColor(field, value)
    if typeof(value) ~= "Color3" then return end
    ThemeColors[field] = value
    ScheduleColorSettingsSave()
end
CustomizationTab:CreateColorPicker({Name = "UI — Background", Color = ThemeColors.Background, Flag = "UIThemeBg", Callback = function(v)
    ApplyThemeColor("Background", v)
end})
CustomizationTab:CreateColorPicker({Name = "UI — Topbar", Color = ThemeColors.Topbar, Flag = "UIThemeTopbar", Callback = function(v)
    ApplyThemeColor("Topbar", v)
end})
CustomizationTab:CreateColorPicker({Name = "UI — Tab Selected Accent", Color = ThemeColors.TabBackgroundSelected, Flag = "UIThemeAccent", Callback = function(v)
    ThemeColors.TabBackgroundSelected = v
    ScheduleColorSettingsSave()
end})
CustomizationTab:CreateColorPicker({Name = "UI — Element Background", Color = ThemeColors.ElementBackground, Flag = "UIThemeElemBg", Callback = function(v)
    ApplyThemeColor("ElementBackground", v)
end})
CustomizationTab:CreateColorPicker({Name = "UI — Text Color", Color = ThemeColors.TextColor, Flag = "UIThemeText", Callback = function(v)
    ApplyThemeColor("TextColor", v)
end})
CustomizationTab:CreateButton({Name = "Reset UI Theme to Default", Callback = function()
    pcall(function()
        ThemeColors = table.clone(ThemeColorDefaults)
        local defaults = {
            UIThemeBg = ThemeColorDefaults.Background,
            UIThemeTopbar = ThemeColorDefaults.Topbar,
            UIThemeAccent = ThemeColorDefaults.TabBackgroundSelected,
            UIThemeElemBg = ThemeColorDefaults.ElementBackground,
            UIThemeText = ThemeColorDefaults.TextColor,
        }
        for flag, value in pairs(defaults) do
            local control = Rayfield.Flags and Rayfield.Flags[flag]
            if control then control:Set(value) end
        end
    end)
    ScheduleColorSettingsSave()
end})

-- Misc tab removed in v2.3.0; contents moved to Settings tab

CustomizationTab:CreateSection("Tactile Audio Feedback")
CustomizationTab:CreateToggle({
    Name = "Audio-Tactile Feedback (Clicks & Switches)",
    CurrentValue = (S.AudioFeedbackEnabled ~= false),
    Flag = "AudioFeedbackEnabled",
    Callback = function(v)
        S.AudioFeedbackEnabled = v
        if TASFFTheme and TASFFTheme.PlayUISound then
            TASFFTheme.PlayUISound(v and "toggle_on" or "toggle_off")
        end
    end
})
CustomizationTab:CreateSlider({
    Name = "Audio Feedback Volume",
    Range = {10, 100},
    Increment = 5,
    Suffix = "%",
    CurrentValue = math.floor((S.AudioFeedbackVolume or 0.5) * 100),
    Flag = "AudioFeedbackVolume",
    Callback = function(v)
        S.AudioFeedbackVolume = v / 100
    end
})

CustomizationTab:CreateSection("Tactical Interface Overlays")
CustomizationTab:CreateToggle({
    Name = "Target Inspection Hologram",
    CurrentValue = (S.TargetCardEnabled ~= false),
    Flag = "TargetCardEnabled",
    Callback = function(v)
        S.TargetCardEnabled = v
    end
})
CustomizationTab:CreateToggle({
    Name = "Compact Floating HUD Mode (When Closed)",
    CurrentValue = (S.CompactHUDEnabled == true),
    Flag = "CompactHUDEnabled",
    Callback = function(v)
        S.CompactHUDEnabled = v
    end
})
CustomizationTab:CreateToggle({
    Name = "Combat Keystrokes Visualizer",
    CurrentValue = (S.KeystrokesEnabled == true),
    Flag = "KeystrokesEnabled",
    Callback = function(v)
        S.KeystrokesEnabled = v
    end
})
CustomizationTab:CreateToggle({
    Name = "Live Performance Sparkline Graph",
    CurrentValue = (S.SparklineGraphEnabled ~= false),
    Flag = "SparklineGraphEnabled",
    Callback = function(v)
        S.SparklineGraphEnabled = v
    end
})

CustomizationTab:CreateSection("System Diagnostics & Memory")
local diagParagraph = CustomizationTab:CreateParagraph({
    Title = "Client Diagnostics",
    Content = "Collecting memory and runtime telemetry..."
})
task.spawn(function()
    while task.wait(2.5) do
        if diagParagraph and diagParagraph.Set then
            local memMb = math.floor(collectgarbage("count") / 1024)
            local drwCount = (TASFFEnv.Drawings and #TASFFEnv.Drawings) or 0
            local connCount = (TASFFEnv.Connections and #TASFFEnv.Connections) or 0
            pcall(function()
                diagParagraph:Set({
                    Title = "Client Diagnostics",
                    Content = string.format("Script Memory: ~%d MB  |  Drawings: %d  |  Connections: %d", memMb, drwCount, connCount)
                })
            end)
        end
    end
end)
CustomizationTab:CreateButton({
    Name = "Purge Stale Cache & Garbage Collect",
    Callback = function()
        if S.CleanupCaches then S.CleanupCaches() end
        collectgarbage("collect")
        if S.Notify then
            S.Notify({
                Title = "Diagnostics",
                Content = "Purged stale target caches & performed GC sweep.",
                Duration = 3,
                Image = "trash-2"
            })
        end
    end
})

SettingsTab:CreateSection("Notifications")
SettingsTab:CreateParagraph({Title = "Notifications", Content = "Controls how and when TASFF sends in-game Rayfield notifications. Mute disables all. Max per 3s throttles burst spam."})
SettingsTab:CreateToggle({Name = "Mute Notifications", CurrentValue = S.DisableNotifications, Flag = "DisableNotifications", Callback = function(v)
    S.DisableNotifications = v
end})
SettingsTab:CreateSlider({Name = "Notification Duration (s)", Range = {1, 10}, Increment = 1, CurrentValue = S.NotificationDuration or 3, Flag = "NotificationDuration", Callback = function(v)
    S.NotificationDuration = v
end})
SettingsTab:CreateSlider({Name = "Max Notifications / 3s", Range = {1, 10}, Increment = 1, CurrentValue = S.NotifyMaxPer3s or 5, Flag = "NotifyThrottle", Callback = function(v) S.NotifyMaxPer3s = v end})
SettingsTab:CreateToggle({Name = "Suppress Rayfield Ads", CurrentValue = S.SuppressRayfieldAds, Flag = "SuppressRayfieldAds", Callback = function(v)
    S.SuppressRayfieldAds = v
end})

SettingsTab:CreateSection("Utilities")
SettingsTab:CreateParagraph({Title = "Utilities", Content = "Standalone helper tools with no dependency on the aimbot engine."})
SettingsTab:CreateToggle({Name = "Anti-AFK", CurrentValue = S.AntiAFKEnabled, Flag = "AntiAFK", Callback = function(v) S.AntiAFKEnabled = v end})
SettingsTab:CreateToggle({Name = "Mode Cycle", CurrentValue = S.RapidModeCycleEnabled, Flag = "RapidModeCycle", Callback = function(v) S.RapidModeCycleEnabled = v end})
SettingsTab:CreateKeybind({
    Name           = "Mode Cycle Key",
    CurrentKeybind = S.RapidModeCycleKey or "P",
    HoldToInteract = false,
    CallOnChange   = true,
    Flag           = "RapidModeCycleKey",
    Callback       = function(key)
        local validKey = SanitizeKeyName(key)
        if validKey then
            S.RapidModeCycleKey = validKey
            if not S._LoadingPreset and S.Notify then
                S.Notify({
                    Title    = "TASFF Keybind",
                    Content  = "Mode cycle key set to [" .. tostring(validKey) .. "]",
                    Duration = 2,
                    Image    = "keyboard"
                })
            end
        end
    end
})

-- ── Overlay & Interface Modifiers ────────────────────────────────
SettingsTab:CreateSection("Overlay & Interface Modifiers")
SettingsTab:CreateParagraph({
    Title   = "UI Extensions & Overlays",
    Content = "Advanced visual layers drawn independently of Rayfield, including persistent status HUD, radar minimap, notification sidebar, and keyboard navigation."
})
SettingsTab:CreateToggle({
    Name = "HUD Status Strip",
    CurrentValue = (S.HUDStripEnabled ~= false),
    Flag = "HUDStripEnabled",
    Callback = function(v)
        S.HUDStripEnabled = v
        if S.LogEvent then S.LogEvent("HUD Strip: " .. (v and "ON" or "OFF")) end
    end
})
SettingsTab:CreateToggle({
    Name = "Threat Radar Mini-Map",
    CurrentValue = (S.RadarEnabled == true),
    Flag = "RadarEnabled",
    Callback = function(v)
        S.RadarEnabled = v
        if S.LogEvent then S.LogEvent("Threat Radar: " .. (v and "ON" or "OFF")) end
    end
})
SettingsTab:CreateToggle({
    Name = "Notification Sidebar Strip",
    CurrentValue = (S.SidebarEnabled ~= false),
    Flag = "SidebarEnabled",
    Callback = function(v)
        S.SidebarEnabled = v
    end
})
SettingsTab:CreateToggle({
    Name = "Keyboard Navigation",
    CurrentValue = (S.KeyboardNavEnabled ~= false),
    Flag = "KeyboardNavEnabled",
    Callback = function(v)
        S.KeyboardNavEnabled = v
    end
})
SettingsTab:CreateToggle({
    Name = "Compact Mode (Hide Descriptions)",
    CurrentValue = (S.CompactModeEnabled == true),
    Flag = "CompactModeEnabled",
    Callback = function(v)
        S.CompactModeEnabled = v
        local rGui = (TASFFEnv.Theme and TASFFEnv.Theme.FindRayfieldGui and TASFFEnv.Theme.FindRayfieldGui())
        if not rGui then
            local cg = game:GetService("CoreGui")
            pcall(function() if gethui then cg = gethui() end end)
            for _, c in ipairs(cg:GetChildren()) do
                if c:IsA("ScreenGui") and (c.Name:find("Rayfield") or c:FindFirstChild("Main")) then rGui = c break end
            end
        end
        if rGui then
            for _, desc in ipairs(rGui:GetDescendants()) do
                if desc:IsA("Frame") and desc.Name == "Paragraph" then
                    desc.Visible = not v
                end
            end
        end
        if S.LogEvent then S.LogEvent("Compact Mode: " .. (v and "ON" or "OFF")) end
    end
})
SettingsTab:CreateToggle({
    Name = "Mobile Mode Layout",
    CurrentValue = (S.MobileModeEnabled == true),
    Flag = "MobileModeEnabled",
    Callback = function(v)
        S.MobileModeEnabled = v
        if S.Notify then S.Notify({Title="Mobile Mode", Content=v and "Mobile layout enabled." or "Mobile layout disabled.", Duration=2, Image="smartphone"}) end
    end
})
SettingsTab:CreateSlider({
    Name = "Window Opacity",
    Range = {0.2, 1.0},
    Increment = 0.05,
    CurrentValue = S.UIOpacity or 1.0,
    Flag = "WindowOpacity",
    Callback = function(v)
        S.UIOpacity = v
        local cg = game:GetService("CoreGui")
        pcall(function() if gethui then cg = gethui() end end)
        for _, c in ipairs(cg:GetChildren()) do
            if c:IsA("ScreenGui") and (c.Name:find("Rayfield") or c:FindFirstChild("Main")) then
                local main = c:FindFirstChild("Main", true) or c:FindFirstChildOfClass("Frame")
                if main then main.BackgroundTransparency = 1 - v end
            end
        end
    end
})



-- // ============================================================ // --
-- //                       SYSTEM TAB (v2.2.6)                     // --
-- // ============================================================ // --

local SystemTab = Window:CreateTab("System", "cog")

-- // Key System UI
SystemTab:CreateSection("Key System")
local KeyStatusLabel = SystemTab:CreateParagraph({
    Title   = "Access Tier",
    Content = S.KeyVerified and "🔓 Full Access — Key verified." or "🔑 Free Tier — Enter a key to unlock advanced features.",
})
S.KeyStatusLabel = KeyStatusLabel
SystemTab:CreateInput({
    Name                     = "Enter Key",
    PlaceholderText          = "Paste your TASFF key here...",
    RemoveTextAfterFocusLost = false,
    Flag                     = "TASFFKeyInput",
    Callback                 = function(text) S.TASFFKey = text end,
})
SystemTab:CreateButton({
    Name     = "Verify Key",
    Callback = function()
        if not S.TASFFKey or S.TASFFKey == "" then
            if S.Notify then S.Notify({Title="Key System", Content="Enter a key first.", Duration=2, Image="alert-triangle"}) end
            return
        end
        S.KeyStatus = "verifying"
        pcall(function() KeyStatusLabel:Set({Title="Access Tier", Content="⏳ Verifying..."}) end)
        -- Stub: replace with real HTTP verification in obfuscated build
        task.delay(1.5, function()
            local valid = (S.VerifyKey and S.VerifyKey(S.TASFFKey)) or false
            S.KeyVerified = valid
            S.KeyStatus = valid and "valid" or "invalid"
            local msg = valid and "🔓 Key accepted. Advanced features unlocked." or "❌ Invalid key. Check your key and try again."
            pcall(function() KeyStatusLabel:Set({Title="Access Tier", Content=msg}) end)
            if S.Notify then S.Notify({Title="TASFF Key", Content=msg, Duration=4, Image=valid and "check-circle" or "x-circle"}) end
            if valid and (TASFFEnv.Capabilities or {}).FileWrite then
                pcall(function() writefile(S.KeyFileName or "TASFF_Key.dat", S.TASFFKey) end)
            end
        end)
    end,
})
SystemTab:CreateButton({
    Name     = "Clear Key",
    Callback = function()
        S.TASFFKey = ""; S.KeyVerified = false; S.KeyStatus = "none"
        pcall(function() KeyStatusLabel:Set({Title="Access Tier", Content="🔑 Free Tier — Enter a key to unlock advanced features."}) end)
        if (TASFFEnv.Capabilities or {}).FileWrite then
            pcall(function()
                if isfile(S.KeyFileName or "TASFF_Key.dat") then delfile(S.KeyFileName or "TASFF_Key.dat") end
            end)
        end
        if S.Notify then S.Notify({Title="TASFF Key", Content="Key cleared.", Duration=2, Image="trash"}) end
    end,
})

SystemTab:CreateSection("Performance Engine")
PerformanceIndicator = SystemTab:CreateParagraph({
    Title   = "Active Performance Profile",
    Content = "Current Mode: " .. (S.PerformanceMode or "Medium") ..
              " (Interval: " .. ((S.PerformanceIntervals or {})[S.PerformanceMode] or 3) .. " frames)"
})
S.PerformanceIndicator = PerformanceIndicator

SystemTab:CreateDropdown({
    Name            = "Core Frame-Skip Strategy",
    Options         = S.PerformanceModes or {"Ultra High", "High", "Medium", "Low", "Ultra Low"},
    CurrentOption   = {S.PerformanceMode},
    MultipleOptions = false,
    Flag            = "PerformanceMode",
    Callback        = function(v)
        S.PerformanceMode = UnpackOption(v, "Medium")
        S.FrameCounters.HeavySystems = 0
        S.FrameCounters.NPCs         = 0
        S.FrameCounters.WorkspaceSweep = 0
        S.FrameCounters.CacheCleanup = 0
        pcall(function()
            PerformanceIndicator:Set({
                Title   = "Active Performance Profile",
                Content = "Current Mode: " .. S.PerformanceMode ..
                          " (Interval: " .. ((S.PerformanceIntervals or {})[S.PerformanceMode] or 3) .. " frames)"
            })
        end)
    end
})

SystemTab:CreateToggle({Name = "FPS Auto-Tuner", CurrentValue = S.FPSWatcherEnabled, Flag = "FPSWatcher", Callback = function(v) S.FPSWatcherEnabled = v end})

SystemTab:CreateSection("Security & Failsafes")
SystemTab:CreateParagraph({
    Title   = "Panic System & Clean Unload",
    Content = "Panic: Instantly suspends Master Switch, releases all virtual mouse/key inputs, and hides overlays.\nKill/Unload: Destroys the Rayfield GUI completely and terminates all backend memory connections."
})

SystemTab:CreateToggle({Name = "Debug Mode", CurrentValue = S.DebugMode, Flag = "DebugMode", Callback = function(v) S.DebugMode = v end})

SystemTab:CreateKeybind({
    Name           = "Global Panic Keybind",
    CurrentKeybind = S.PanicKeybind or "Delete",
    HoldToInteract = false,
    CallOnChange   = true,
    Flag           = "PanicKeybind",
    Callback       = function(key)
        local validKey = SanitizeKeyName(key)
        if validKey then
            S.PanicKeybind = validKey
            if S.Notify then
                S.Notify({
                    Title    = "TASFF Keybind",
                    Content  = "Panic key set to [" .. tostring(validKey) .. "]",
                    Duration = 2,
                    Image    = "keyboard"
                })
            end
        end
    end
})

SystemTab:CreateButton({
    Name     = "Execute Panic Protocol",
    Callback = function()
        if S.TriggerPanic then S.TriggerPanic() end
    end
})

SystemTab:CreateButton({
    Name     = "Factory Reset (Restore All Defaults)",
    Callback = function()
        -- Exhaustive reset to prevent "frankenstein" states
        S.MasterEnabled = false;        S.TargetingEnabled = true;      S.Mode = "Legit (Camera)"
        S.TargetPart = "Head";          S.ActivePartName = "Head"
        S.PriorityMode = "None";        S.VitalityMode = "None";        S.TargetNearCenter = false
        S.Smoothness = 1.5;             S.PredictionAmount = 0.16
        S.DistancePredictionAdjustEnabled = false; S.MaxAutoPrediction = 0.45
        S.SilentAimEnabled = false;     S.DynamicRecoilEnabled = false
        S.RandomizeHitboxEnabled = false
        S.TargetSwitchDelayEnabled = false; S.SwitchDelayMs = 200
        S.GracePeriodEnabled = false;   S.GracePeriodMs = 150
        S.AimbotRenderDistance = 1000;  S.StickyAimEnabled = false;     S.AutoADSEnabled = false
        S.VisualMode = "Single";        S.UseHighlight = true;          S.UseNPCHighlight = true
        S.FocusMode = false;            S.StreamProofESP = true;        S.VisibilityColorsEnabled = false
        S.ESPRenderDistance = 1000;     S.ChamsEnabled = false;         S.ChamsOpacity = 10
        S.BoxModeEnabled = false;       S.SkeletonModeEnabled = false
        S.SnaplinesEnabled = false;     S.SnaplineOrigin = "Bottom"
        S.OOFArrowsEnabled = false;     S.OOFArrowRadius = 150;         S.OOFArrowsPriorityOnly = false
        S.UseInfoTag = true;            S.UseNPCInfoTag = true
        S.ShowDisplayName = false;      S.ShowToolCheck = false
        S.ShowFOV = false;              S.InvisibleFOV = false;         S.FOVSize = 100
        S.AimReferenceMode = "Screen Center"
        S.EnableCrosshair = false;      S.CrosshairStyle = "Plus";      S.CrosshairSize = 10
        S.ManualCalibrationEnabled = false; S.CalibrationOffsetX = 0;   S.CalibrationOffsetY = 0
        S.AutoClickEnabled = false;     S.TriggerbotPriorityOnly = false; S.TriggerbotClickMode = "Virtual"; S.ClickMethod = "Mash"
        S.ClickInterval = 100;          S.ThirdPersonTriggerbot = false
        S.KeyTriggerbotEnabled = false; S.KeyTriggerMode = "Single Press"
        S.MeleeModeEnabled = false;     S.MeleeDetectionRange = 5;      S.MeleeClickInterval = 100
        S.ThreatDetectorEnabled = false; S.NemesisEnabled = true;       S.ThreatTimeout = 10
        S.BlacklistExpiredThreats = false
        S.OtherPlayersDamageTracking = true; S.ExpertInstinctsEnabled = false; S.ExpertInstinctsIntensity = 60; S.InstinctsMode = "Blatant"
        S.InstinctsInventoryCheck = false; S.InstinctsBlacklist = {}; S.InstinctsPrioritizedTools = {}
        S.AutoUpdateCheckerEnabled = true
        S.KillCountThreatEnabled = false; S.KillFeedEnabled = false; S.KillsBeforeThreat = 3; S.ContinuousKillsPermanent = 5; S.KillsBeforeNemesis = 3
        S.ThreatNeutralizationEnabled = false; S.AutoExpireOnDisconnect = false
        S.IgnoreThreatVictims = true
        S.ClickToMarkEnabled = false;   S.MarkMethod = "Both"
        S.StrictPrioritize = false;     S.WallCheck = true
        S.NoCollisionCheck = false;     S.FoliageConcealmentCheck = true; S.TransparencyCheck = false;    S.TransparencyThreshold = 0.5
        S.DecalsCheck = false
        S.CoverAnticipationEnabled = true; S.CoverAnticipationDuration = 0.8
        S.EnvironmentalESPEnabled = false; S.EnvironmentalESPPriorityOnly = false; S.EnvironmentalESPRange = 15
        S.EnvironmentalESPDistanceFade = false; S.EnvironmentalESPTransparency = 0.95
        S.EnvironmentalESPAutoScaling = true; S.EnvironmentalESPMaxParts = 160
        S.EnvironmentalESPColor = Color3.fromRGB(0, 200, 255)
        S.TargetPlayers = true;         S.TargetNPCs = false;           S.TeamCheck = false
        S.AutoEnableOnEquip = false;    S.IgnoreDead = true
        S.MasterSwitchKeybind = "RightShift"
        S.RapidModeCycleEnabled = false; S.RapidModeCycleKey = "P"
        S.QuickPresetSwitchEnabled = false; S.QuickPresetSwitchKey = "J"
        S.ActivePresetName = ""
        S.CurrentTarget = nil
        if S.ClearEnvironmentalESP then S.ClearEnvironmentalESP() end
        if S.SetADSState    then S.SetADSState(false) end
        if S.ClearVisuals   then S.ClearVisuals()     end
        if S.ClearCrosshair then S.ClearCrosshair()   end
        if S.Notify then S.Notify({Title = "TASFF System", Content = "Factory Reset complete. All modules restored to default.", Duration = 3, Image = "list-restart"}) end
    end
})

SystemTab:CreateSection("Keybind Overview")
local KeybindOverviewParagraph = SystemTab:CreateParagraph({
    Title   = "Registered Keybinds",
    Content = "Compiling keybind registry..."
})
S.KeybindOverviewParagraph = KeybindOverviewParagraph

local function RefreshKeybindOverview()
    if not KeybindOverviewParagraph then return end
    local binds = {
        string.format("Aimbot Hold Key:        [%s]", tostring(S.AimbotKeybind or "None")),
        string.format("Master Switch Key:      [%s]", tostring(S.MasterSwitchKeybind or "None")),
        string.format("Mode Cycle Key:         [%s]", tostring(S.RapidModeCycleKey or "None")),
        string.format("Preset Switch Key:      [%s]", tostring(S.QuickPresetSwitchKey or "None")),
        string.format("Target Mark Key:        [%s]", tostring(S.MarkKeybind or "None")),
        string.format("Panic Keybind:          [Delete]"),
        string.format("Keyboard Nav:           [Up / Down / Enter]"),
    }
    pcall(function()
        KeybindOverviewParagraph:Set({
            Title   = "Registered Keybinds",
            Content = table.concat(binds, "\n")
        })
    end)
end
task.spawn(function()
    task.wait(2)
    RefreshKeybindOverview()
end)
SystemTab:CreateButton({
    Name = "Refresh Keybind Overview",
    Callback = RefreshKeybindOverview
})

SystemTab:CreateSection("Updates")

local UpdateStatusDisplay = SystemTab:CreateParagraph({
    Title   = "Repository Status",
    Content = "Running TASFF v" .. (S.CurrentVersion or "?") .. ".\nClick 'Check for Updates' to verify repository sync."
})
S.UpdateStatusDisplay = UpdateStatusDisplay

SystemTab:CreateToggle({
    Name = "Auto-Check for Updates",
    CurrentValue = S.AutoUpdateCheckerEnabled ~= false,
    Flag = "AutoUpdateChecker",
    Callback = function(v)
        S.AutoUpdateCheckerEnabled = v
    end
})

SystemTab:CreateButton({
    Name     = "Check for Updates Now",
    Callback = function()
        if S.CheckForUpdates then
            S.CheckForUpdates(true)
        else
            if S.Notify then S.Notify({Title = "TASFF Update Checker", Content = "Update checker engine initializing...", Duration = 2, Image = "loader"}) end
        end
    end
})

SystemTab:CreateButton({
    Name     = "Restart Script & Reload Interface",
    Callback = function()
        if S.RestartScript then
            S.RestartScript()
        elseif getgenv and getgenv().TASFF and getgenv().TASFF.RestartScript then
            getgenv().TASFF.RestartScript()
        else
            if S.Notify then S.Notify({Title = "TASFF System", Content = "Restart function unavailable. Re-execute via executor.", Duration = 3, Image = "alert-triangle"}) end
        end
    end
})

SystemTab:CreateButton({
    Name     = "Terminate Script & Unload Interface",
    Callback = function()
        if S.UnloadScript then S.UnloadScript() end
    end
})



-- // ============================================================ // --
-- //                      9. UPDATE LOG TAB                       // --
-- // ============================================================ // --

local UpdateLogTab = Window:CreateTab("Update Log", "history")
UpdateLogTab:CreateSection("Recent Releases & Updates")

UpdateLogTab:CreateParagraph({
    Title   = "Version 2.3.0 (Comprehensive UI Redesign, Overlays & Architecture Overhaul)",
    Content = "• Complete UI Redesign: restructured interface into 9 clean tabs (Home, Combat, Triggerbot, Visuals, Intel, Settings, Theming, Presets, Update Log); retired deprecated Advanced and Misc tabs into Settings and Visuals.\n" ..
              "• Runtime GUI Tree Engine (TASFF_Theme): real-time search filter injected into every tab container; accordion-style section collapse/expand buttons; live state dot indicators on all toggle controls; interactive cursor-anchored hover tooltips on controls with live definitions.\n" ..
              "• Window Controls & Opacity: bottom-right window resize grip (⇲) supporting custom window scaling (440x340 to 1000x850); dynamic window opacity slider (0.3–1.0) with Ctrl+MouseWheel shortcut; tab notification badge counters wired to active threats.\n" ..
              "• Standalone Overlays (TASFF_OverlayGui): persistent HUD Status Strip (aim status, silent/human mode, active target, threat count, active profile, live FPS); draggable circular Threat Radar Mini-Map with camera-relative blips; draggable Notification Sidebar Feed with auto-fading pills.\n" ..
              "• Combat & Aim Engine: independent horizontal (SmoothnessX) and vertical (SmoothnessY) aim smoothness axes; blatant snap speed slider; dynamic inverse-distance FOV scaling; health threshold gating; auto-disable on player death; intelligent equip filter and weapon-type gating.\n" ..
              "• Visuals & Tactical Overlays: dedicated Crosshair section with multiple geometry styles and sizing; screen cloaking controls unified under Visuals; kill confirmation screen flash with duration tuning; frustum-culled OOF directional arrows with smoothed angles.\n" ..
              "• Threat Intelligence & Leaderboard: Threat Leaderboard panel ranking active threats by score and kills; 4-tier threat confidence badges (●●●● to ●○○○); lowered damage tracking threshold to 4 HP for accurate hit detection.\n" ..
              "• Preset Engine & Schema v2.3.0: 29 new configuration keys synchronized across profiles; live Configuration Diff Viewer comparing active settings against loaded profiles; eliminated duplicate native Roblox notifications during preset cycling.\n" ..
              "• Theming & Home Suite: 19 global theme palettes with live Window.ModifyTheme repainting; Definitions & Glossary inspector on Home tab; Quick Actions row (Emergency Panic, Reload Presets, Clear Caches); Session Event Log tracking combat milestones.\n" ..
              "• Pipeline & Memory Optimization: active tab container watchdog preventing element bleeding; drawing wrapper cleanup explicitly disposing dead drawings; state table reference stability using table.clear."
})

UpdateLogTab:CreateParagraph({
    Title   = "Version 2.2.6 (Environmental ESP Rewrite, Stability & Instincts Polish)",
    Content = "• Environmental ESP Dual Architecture: combines BoxHandleAdornment (for 95% invisible chams fill) with SelectionBox (for sharp corner & edge outlines) — highlights small objects fully while maintaining total visibility of player ESP.\n" ..
              "• Environmental ESP 2D Surface Plane Slices: dynamic normal-axis detection projects flat 0.15-stud thin proxy slabs directly onto the surface of large floors, walls, and ceilings around players instead of engulfing them in 3D cubes.\n" ..
              "• Environmental ESP Distance Fade Toggle: dynamically scales both chams fill transparency and outline thickness based on distance from the target player, smoothly fading to invisible at maximum range.\n" ..
              "• Environmental ESP Baseline Transparency Slider: configurable baseline transparency slider (default 0.95 = 95% invisible) for precise chams fill customization.\n" ..
              "• Environmental ESP Character & Accessory Filter: humanoids, character models, and accessories are strictly excluded from environmental ESP processing.\n" ..
              "• OOF Arrow Angle Smoothing: added per-arrow exponential moving-average filter (shortest-arc lerp at ~12x deltaTime) stored in S._OOFAngleSmooth. Smooths out HumanoidRootPart animation bob and camera wobble without affecting directional accuracy. Angle cache is cleared when an arrow hides so the next appearance starts from scratch.\n" ..
              "• Environmental ESP Priority Fix: priority-only toggle now queries all players directly instead of LastVisualList, correctly showing or hiding overlays for all players when priority filter is disabled.\n" ..
              "• OOF Arrow Direction Fix (Round 2): replaced PointToObjectSpace atan2 with RightVector/UpVector dot products — arrows now point in the correct screen direction with no z-boundary discontinuity.\n" ..
              "• Expert Instincts Last-Known-Position Steering: camera now continues steering towards the attacker's last known world position when they duck behind cover mid-reaction, instead of stopping mid-turn.\n" ..
              "• Expert Instincts Live Position Update: last-known-position is refreshed every frame while the attacker is visible, ensuring the held angle is always current before they take cover.\n" ..
              "• Expert Instincts Blatant/Legit Mode Dropdown: mirrors the aimbot's mode system — Blatant does a direct per-intensity CFrame lerp (100=instant, 0=very smooth), Legit uses the humanized smoothstep pipeline.\n" ..
              "• Expert Instincts Lock Speed Range: extended slider range to 0-100 (was 5-100) for full smooth range.\n" ..
              "• Permanent Priority Notification Dedup: 'Killer is now PERMANENT' notification now fires only once per unique killer upon first reaching the continuous kill threshold; resets on neutralization.\n" ..
              "• Home Tab Paragraph Count: replaced Status Displays counter with accurate Paragraph count (34) in the home tab controls summary.\n" ..
              "• Quick Preset Profile Switching: rapid cycle between saved configuration presets using a customizable keybind (default J) without opening the menu.\n" ..
              "• Master Switch Keybind: added a customizable keybind (default RightShift) to toggle the Master Switch on and off instantly without opening the menu.\n" ..
              "• Version bump to v2.2.6."
})

UpdateLogTab:CreateParagraph({
    Title   = "Version 2.2.5 (Threat Intelligence & Humanized Legit Aim Engine)",
    Content = "• Ambush Latency Fix: real-time visibility fallback for close (<120 studs) and threat targets completely eliminates background raycast loop delay.\n" ..
              "• Distance-Based Auto Prediction: dynamically scales velocity lead with target distance, preventing crosshair trailing and missed shots at range.\n" ..
              "• Universal Player Damage Tracking: tracks non-lethal damage between any players in the server, automatically labeling aggressors as Threats.\n" ..
              "• Expert Instincts & Configurable Lock Speed: counter-reacts and locks onto attackers with configurable swivel speed slider (5-100) and smooth active lerp acquisition.\n" ..
              "• Threat Priority Integrity: manual Marked and Registry priorities are strictly preserved and never overwritten by automatic threat damage/kill detections.\n" ..
              "• Calibrated Hand Tremor & Sway: re-tuned physiological micro-tremor and breathing sway to produce organic, visually perceptible movement in Camera and Mouse aiming.\n" ..
              "• Dedicated Misc & System Tab Separation: clean separation of Notification controls, Utilities, and Cloaking (Misc) from Performance, Security, and Failsafes (System).\n" ..
              "• Enhanced Threat Intelligence Engine: multi-tier killer attribution with deep 22-tag/13-attribute scans and leaderstats delta correlation for zero-tag games.\n" ..
              "• Proximity Attributor Filter: leaderstats kill correlations filtered within proximity radius to eliminate false positives.\n" ..
              "• Threat Victim Kill Protection: optional toggle ensures killing an existing threat does not credit the killer towards threat streaks or nemesis triggers.\n" ..
              "• Detailed Neutralization Killfeed: displays contextual intel registry reasons in killfeed notifications (e.g. 'Killer neutralized Victim (nemesis/threat/click to mark)').\n" ..
              "• Priority-Filtered OOF Indicators: toggle to isolate off-screen arrow indicators to only point towards priority/intel targets.\n" ..
              "• High-Compatibility Status Display Icons: replaced unrendered box Unicode symbols with clean universal [V] and [X] indicators across all status monitors.\n" ..
              "• Humanized Legit Dynamics: anti-spectator organic aiming mimicking realistic human biomechanics (Aim Arc Curvature, Target Deadzone Slack, Reaction Inertia, Hitbox Volume Surface Drift).\n" ..
              "• Auto-Update Checker & Repository Sync: background watcher and manual repository polling checks for committed updates and notifies when new builds are live.\n" ..
              "• Legacy Releases Changelog Archive: interactive version dropdown allowing users to explore full changelogs for builds v1.2.0 through v1.5.5.\n" ..
              "• Expert Instincts Pursuit & Defense Check: scans inventory for defense weapons when attacked, suppressing instincts if unarmed/fleeing with dedicated blacklist and priority registries.\n" ..
              "• Smart Weapon Keyword Classifier: word-boundary filtering and compound keyword resolution eliminating false positives across extensive Roblox weapon and consumable libraries.\n" ..
              "• Threat Expiry & Monitor Clean-up: Expired threats are cleanly pruned from the Intel Monitor; click-to-mark toggle logic restored for prioritized targets.\n" ..
              "• Continuous Kills For Permanent Priority: Configurable slider (2-15) permanently locks killers on the Intel Monitor and priority targeting until neutralized.\n" ..
              "• Crowd Attributor & Damage Tracking Hardening: Replaced flawed velocity proximity heuristics with weapon classification, directional aim alignment, and raycast line-of-sight checks, eliminating crowd false positives.\n" ..
              "• Continuous Expert Instincts Tracking: Continuously swivels camera towards the attacker every frame damage is sustained, pinning aimbot lock onto the attacker.\n" ..
              "• Concealment & Foliage Check (Anti-Bush Snapping): Intelligent foliage and obstacle detector prevents aimbot and triggerbot from locking onto enemies hidden in non-collidable foliage/bushes.\n" ..
              "• Humanized Cover Anticipation (Corner Hold): Maintains crosshair on cover edges and corners when a target breaks line-of-sight for a configurable duration (0.1-3.0s), holding triggerbot fire until re-peek.\n" ..
              "• Environmental Awareness ESP: Highlights surrounding objects and obstacles near players with configurable radius (5-50 studs), fully outlining small props and rendering bounding square slices on large floors, walls, and ceilings with priority-only filter.\n" ..
              "• Triggerbot Priority Target Filter: Optional toggle ensures Triggerbot (both Mouse and Keybind simulation) exclusively engages targets labeled as Threats, Nemesis, or Marked in Intel."
})

UpdateLogTab:CreateParagraph({
    Title   = "Version 2.2.0 (Screen Recording Cloaking & Profile Architecture Update)",
    Content = "• Screen Recording Cloaking System: selectively cloak visuals from Roblox recording (WIP).\n" ..
              "• High-Contrast ESP Tag Outlines: black text stroke border prevents camouflage through same-colored geometry.\n" ..
              "• Restart Script Engine: reload interface and re-initialize without re-injecting in your executor.\n" ..
              "• Per-Game Autosaving: configs auto-save into PlaceId-specific profiles (Config_Place_<PlaceId>).\n" ..
              "• Preset Feature Inspection Status Display: inspect enabled/disabled features of any saved profile with category dropdown.\n" ..
              "• Override Selected Profile: overwrite any existing profile with current configuration in 1 click.\n" ..
              "• Streamlined Presets: removed deprecated hardcoded quick-loads in favor of dynamic profile management.\n" ..
              "• System Metrics: Home tab displays total status displays count alongside UI controls.\n" ..
              "• Staged Loading Sequence: 4-stage unbundled module pipeline with progress notifications to prevent post-execution crashes."
})

UpdateLogTab:CreateParagraph({
    Title   = "Version 2.1.2 (Refinement Update)",
    Content = "• Fixed VoS Wallcheck Locking: Visible On Screen drops occluded targets cleanly.\n" ..
              "• Restored missing customization options for Default Highlight & Name Tags.\n" ..
              "• Corpses permanently ignored by aimbot engine.\n" ..
              "• Added Server Info monitor on Home tab.\n" ..
              "• Redesigned Theming Tab with 18 global presets and UI theme editor."
})

UpdateLogTab:CreateParagraph({
    Title   = "Version 2.1.0 & 2.1.1 (Pipeline & Intel Overhaul)",
    Content = "• 4-Slot rotating performance pipeline decoupled targeting from FPS.\n" ..
              "• Target selection and aim application run every frame with sub-frame delay.\n" ..
              "• Centralized Intel Tab with Threat Detector, Nemesis System, and Spectator Mode.\n" ..
              "• Intelligent Equip Filter and Weapon-Type gating.\n" ..
              "• 15-hop penetrative wallcheck and frustum-culled OOF arrows."
})

UpdateLogTab:CreateSection("Legacy Releases Archive (v1.2.0 - v1.5.5)")
UpdateLogTab:CreateParagraph({Title = "Legacy Archive", Content = "Historical release notes from v1.2.0 through v1.5.5. Expand entries below to read full changelogs."})

local LegacyReleaseLogs = {
    ["Version 1.5.5"] = "• Version bump to V1.5.5 — hardening, bug fixes, and UI polish pass\n" ..
                        "• Fixed TargetFirstSeenTimestamps cleanup using pcall-guarded IsModelValid to prevent destroyed-model errors\n" ..
                        "• Added independent Snapline & OOF Arrow color control to the Theming tab\n" ..
                        "• Branded all notification titles under TASFF namespace (removed bare Error titles)\n" ..
                        "• Corrected ConfigurationSaving folder path to match current version",

    ["Version 1.5.0"] = "• Completely overhauled the UI layout into professional, structured categories (HUD, Tactical Overlays, etc.)\n" ..
                        "• Fixed a critical metamethod inversion that broke Silent Aim for native weapons and ruined wallchecks\n" ..
                        "• Fixed a math bug where 'Distance Priority' sorted by 2D screen distance instead of true 3D world distance\n" ..
                        "• Fixed drawing persistence glitches (Invisible FOV) by bypassing backend geometry updates when hidden\n" ..
                        "• Fixed missing variable serialization in the Preset Configuration Saver and Factory Reset protocols\n" ..
                        "• Fixed rendering invisibility issues across all ESP geometries (Drawing API transparency mappings)\n" ..
                        "• Added a missing 'Remove Tool' registry function to the Weapon & Inventory Automation section\n" ..
                        "• Patched multiple global scope leaks and a potential fatal crash in the Skeletal Mapping routine",

    ["Version 1.4.5"] = "• Added Advanced Legit Mode utilizing Bezier curves for humanized camera smoothing\n" ..
                        "• Added Dynamic Recoil Control (DRC) to mimic natural human recoil compensation\n" ..
                        "• Added Virtual Flickbot (Cursor Aim) to instantly teleport the invisible mouse cursor\n" ..
                        "• Implemented Universal Silent Aim (Namecall Hooking) to redirect bullets silently\n" ..
                        "• Added Target Switch Delay to pause target acquisition after kills (prevents robotic snapping)\n" ..
                        "• Added Randomized Hitboxes to bypass statistical anti-cheats in Legit mode\n" ..
                        "• Implemented The Nemesis System for tiered death tracking and targeted retaliation\n" ..
                        "• Added Marking Input Modes (Mouse, Keybind, or Both) to prevent accidental priority marking\n" ..
                        "• Added Dynamic Visibility Colors (Green=Visible, Red=Hidden) to ESP geometries\n" ..
                        "• Upgraded all Info Tags to Drawing API for complete Stream-Proofing (OBS bypass)\n" ..
                        "• Added Off-Screen Indicators (OOF Arrows) to track targets located behind the camera\n" ..
                        "• Added ESP Snaplines (Tracers) with configurable origin point positioning\n" ..
                        "• Added Clipboard Preset Import & Export (JSON) for easy configuration sharing\n" ..
                        "• Added Auto-Save Configuration protocol to preserve settings upon script unload",

    ["Version 1.4.0"] = "• Added Threat Detector & Threat Memory subsystem with configurable timeout\n" ..
                        "• Implemented Strict Prioritize targeting mode\n" ..
                        "• Added Invisible FOV mode (maintains lock boundary without rendering circle)\n" ..
                        "• Added Penetrative Wallchecks (No Collision, Transparency Threshold & Decals)\n" ..
                        "• Implemented Auto ADS (Aim Down Sights) automatic holding\n" ..
                        "• Added Click-to-Mark / Keybind-to-Mark and Focus Mode ESP filtering\n" ..
                        "• Added Triggerbot Click Modes (Virtual vs Physical) & 3rd Person coordinate support\n" ..
                        "• Added Key Triggerbot with Single Press, Mash, and Hold modes\n" ..
                        "• Added Dedicated Advanced Settings Tab and Misc utilities (Panic, Reset, Clean Unload)\n" ..
                        "• Full frame-skipping Performance engine with runtime mode indicator",

    ["Version 1.3.5"] = "• Added Aimbot & ESP Render Distance culling sliders (100-1000 studs)\n" ..
                        "• Implemented Target Grace Period delay timer before locking onto targets\n" ..
                        "• Added Chams ESP mode featuring dynamic transparency/opacity controls\n" ..
                        "• Added 2D Box ESP visual overlay\n" ..
                        "• Added Skeleton ESP rendering with full support for R6 & R15 avatar joint structures\n" ..
                        "• Fixed table reference mutation corruption on cached ignore list raycasts\n" ..
                        "• Fixed Melee Mode execution structure to operate independently of Aimbot lock states\n" ..
                        "• Added a brand new 'Presets' Tab featuring profile saving, loading, renaming, and deletion\n" ..
                        "• Fixed FOV Circle persistence bug when auto-disable suspends aimbot on unequipped tools\n" ..
                        "• Fixed Sticky Aim over-attachment issue by validating target FOV and render distance bounds",

    ["Version 1.3.0"] = "• Added Target Near Center crosshair prioritization to Combat options\n" ..
                        "• Added Inventory Auto-Activation trigger system upon tool equipping features\n" ..
                        "• Added Instant Tool-Instance Blacklist registration action buttons to Settings\n" ..
                        "• Implemented advanced vector-rendered screen center Crosshairs (Plus, Square, Circle)\n" ..
                        "• Implemented relative line tracking offsets for Plus style crosshair dimensions\n" ..
                        "• Added Crosshair color mapping configurations straight to Customization presets\n" ..
                        "• Added character text extensions: Show Display Name and structural Tool Check tags",

    ["Version 1.2.5"] = "• Added full-screen targeting mechanics automatically when FOV visual elements are disabled\n" ..
                        "• Added complete Autoclicker Tab featuring customizable speed interval mechanics\n" ..
                        "• Implemented input options: Repeated rapid 'Mash' triggers vs continuous input 'Hold' states\n" ..
                        "• Added Combat Melee Mode subsystem with independent range and interval calculations\n" ..
                        "• Added fully separated 'Highlight NPCs' and 'Show NPC Info' toggle parameters\n" ..
                        "• Added persistent Sticky Aim mechanics with automatic target validation filters\n" ..
                        "• Fixed Sticky Aim wall clipping bugs by routing locks directly into visibility raycasts\n" ..
                        "• Fixed target acquisition memory retention anomalies on active system or configuration switches",

    ["Version 1.2.0"] = "• Added a brand new Customization Tab with color presets\n" ..
                        "• Fixed the respawn bug where player highlights would vanish\n" ..
                        "• Linked the Show Target Info text color directly to custom themes\n" ..
                        "• Removed the broken dynamic interface theme reloader for stability\n" ..
                        "• Added Visible On Screen, located in target bodypart dropdown"
}

local legacyVersionList = {
    "Version 1.5.5", "Version 1.5.0", "Version 1.4.5", "Version 1.4.0",
    "Version 1.3.5", "Version 1.3.0", "Version 1.2.5", "Version 1.2.0"
}

local LegacyLogDisplay = UpdateLogTab:CreateParagraph({
    Title   = "Legacy Changelog — Version 1.5.5",
    Content = LegacyReleaseLogs["Version 1.5.5"]
})

UpdateLogTab:CreateDropdown({
    Name            = "Select Legacy Version",
    Options         = legacyVersionList,
    CurrentOption   = {"Version 1.5.5"},
    Flag            = "LegacyVersionDropdown",
    Callback        = function(selected)
        local ver = (type(selected) == "table" and selected[1]) or selected
        if ver and LegacyReleaseLogs[ver] then
            LegacyLogDisplay:Set({
                Title   = "Legacy Changelog — " .. ver,
                Content = LegacyReleaseLogs[ver]
            })
        end
    end
})

-- // ============================================================ // --
-- MUST be called last. Restores all flagged values from disk and
-- fires each element's Callback, which writes them back into S.
local ConfigDefaults = {}
for key, value in pairs(S) do
    if typeof(value) ~= "table" and type(value) ~= "function" then
        ConfigDefaults[key] = value
    end
end

-- Let UI elements settle and allow Roblox engine to render a frame before triggering configuration callbacks
task.wait(0.1)

local loaded, loadError = pcall(function()
    Rayfield:LoadConfiguration()
end)
if not loaded then
    warn("[TASFF UI] Configuration loading failed; continuing with validated defaults: " .. tostring(loadError))
end

local correctedSettings = false
local booleanSettings = {
    "MasterEnabled", "TargetingEnabled", "AimbotActive", "StickyAimEnabled", "TeamCheck",
    "WallCheck", "IgnoreDead", "ShowFOV", "InvisibleFOV", "TargetSwitchDelayEnabled",
    "SilentAimEnabled", "DynamicRecoilEnabled", "RandomizeHitboxEnabled", "ThreatDetectorEnabled",
    "NemesisEnabled", "AutoADSEnabled", "ClickToMarkEnabled", "FocusMode", "AutoClickEnabled",
    "KeyTriggerbotEnabled", "MeleeModeEnabled", "NoCollisionCheck", "TransparencyCheck",
    "DecalsCheck", "TargetPlayers", "TargetNPCs", "UseHighlight", "UseInfoTag",
    "UseNPCHighlight", "UseNPCInfoTag", "TargetNearCenter", "AutoEnableOnEquip",
    "EnableCrosshair", "ShowToolCheck", "ShowDisplayName", "VisibilityColorsEnabled",
    "ChamsEnabled", "BoxModeEnabled", "SkeletonModeEnabled", "SnaplinesEnabled",
    "OOFArrowsEnabled", "GracePeriodEnabled", "ThreatNeutralizationEnabled",
    "AutoExpireOnDisconnect", "KillCountThreatEnabled", "KillFeedEnabled",
    "DeepThreatScanEnabled", "StatCorrelatorEnabled", "HumanizedAimEnabled",
    "HumanTremorEnabled", "TargetInertiaTracking", "HitboxOffsetDrift",
    "IgnoreThreatVictims", "OOFArrowsPriorityOnly",
    "DistancePredictionAdjustEnabled", "OtherPlayersDamageTracking", "ExpertInstinctsEnabled",
    "AutoUpdateCheckerEnabled", "InstinctsInventoryCheck", "InstinctsAutoEquip", "InstinctsFirstPersonCamera",
    "CoverAnticipationEnabled", "FoliageConcealmentCheck",
    "EnvironmentalESPEnabled", "EnvironmentalESPPriorityOnly",
    "EnvironmentalESPDistanceFade", "EnvironmentalESPAutoScaling",
    "TriggerbotPriorityOnly", "RapidModeCycleEnabled", "QuickPresetSwitchEnabled",
}
for _, key in ipairs(booleanSettings) do
    if type(S[key]) ~= "boolean" then
        S[key] = ConfigDefaults[key] == true
        correctedSettings = true
    end
end

local numericRanges = {
    FOVSize = {10, 2000}, SwitchDelayMs = {0, 2000}, PredictionAmount = {0, 5},
    MaxAutoPrediction = {0.16, 2}, ExpertInstinctsIntensity = {0, 100},
    ContinuousKillsPermanent = {2, 15}, KillsBeforeThreat = {1, 10},
    CoverAnticipationDuration = {0.1, 3}, EnvironmentalESPRange = {5, 50},
    EnvironmentalESPTransparency = {0, 1}, EnvironmentalESPMaxParts = {20, 500},
    Smoothness = {0.1, 100}, SmoothnessX = {0.1, 100}, SmoothnessY = {0.1, 100},
    BlatantSnapSpeed = {1, 100}, TransparencyThreshold = {0, 1},
    GracePeriodMs = {0, 2000}, AimbotRenderDistance = {1, 10000},
    ESPRenderDistance = {1, 10000}, ChamsOpacity = {0, 100}, CrosshairSize = {1, 100},
    OOFArrowRadius = {1, 1000}, ClickInterval = {1, 10000}, MeleeClickInterval = {1, 10000},
    MeleeDetectionRange = {1, 1000}, CalibrationOffsetX = {-2000, 2000},
    CalibrationOffsetY = {-2000, 2000}, DynamicFOVMax = {1, 2000},
    HealthThreshold = {0, 100}, NotifyMaxPer3s = {1, 10},
    ThreatProximityRadius = {20, 200}, ThreatFPCooldown = {0.5, 10},
    AimPathCurvature = {0, 1}, AimDeadzoneRadius = {0, 50},
    HumanTremorIntensity = {0.1, 5}, TargetReactionRate = {1, 50},
}
for key, bounds in pairs(numericRanges) do
    local value = S[key]
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        S[key] = ConfigDefaults[key]
        correctedSettings = true
    else
        local bounded = math.clamp(value, bounds[1], bounds[2])
        if bounded ~= value then correctedSettings = true end
        S[key] = bounded
    end
end

local enumSettings = {
    TargetPart = {Head=true, HumanoidRootPart=true, Torso=true, ["Visible On Screen"]=true},
    Mode = {["Legit (Camera)"]=true, ["Advanced Legit (Mouse)"]=true, Blatant=true, ["Flickbot (Click-Teleport)"]=true},
    PriorityMode = {None=true, Closest=true, Farthest=true},
    VitalityMode = {None=true, ["Weakest (HP)"]=true, ["Strongest (HP)"]=true},
    VisualMode = {Single=true, Multiple=true, All=true},
    SnaplineOrigin = {Bottom=true, Center=true},
    CrosshairStyle = {Plus=true, Square=true, Circle=true},
    TriggerbotClickMode = {Virtual=true, Physical=true},
    ClickMethod = {Mash=true, Hold=true},
    KeyTriggerMode = {["Single Press"]=true, Mash=true, Hold=true},
    MarkMethod = {["Mouse Click Only"]=true, ["Keybind Only"]=true, Both=true},
    AimReferenceMode = {["Screen Center"]=true, ["Mouse Tracking"]=true},
    PriorityBehavior = {Boost=true, Exclusive=true},
}
for key, allowed in pairs(enumSettings) do
    if type(S[key]) ~= "string" or not allowed[S[key]] then
        S[key] = ConfigDefaults[key]
        correctedSettings = true
    end
end
S.ActivePartName = S.TargetPart == "Visible On Screen" and "Head" or S.TargetPart
S.PerformanceMode = S.NormalizePerformanceMode and S.NormalizePerformanceMode(S.PerformanceMode) or "Medium"

for key, default in pairs(ConfigDefaults) do
    if typeof(default) == "Color3" and typeof(S[key]) ~= "Color3" then
        S[key] = default
        correctedSettings = true
    end
end
for _, key in ipairs({"BlacklistedPlayers", "PriorityPlayers", "ToolBlacklist", "VOSPriorityParts", "InstinctsBlacklist", "InstinctsPrioritizedTools"}) do
    local current = S[key]
    if type(current) ~= "table" then
        S[key] = {}
        correctedSettings = true
    else
        local clean, seen = {}, {}
        for _, value in ipairs(current) do
            if type(value) == "string" and value ~= "" and not seen[value] then
                seen[value] = true
                table.insert(clean, value)
            else
                correctedSettings = true
            end
        end
        if key == "VOSPriorityParts" and #clean == 0 then
            S[key] = {"Head", "Torso"}
        else
            S[key] = clean
        end
    end
end

if correctedSettings then
    warn("[TASFF UI] Invalid or out-of-range settings were reset or clamped to safe values.")
end

for key, color in pairs(PersistedColorValues) do
    local field, flag
    if key:sub(1, 6) == "Theme." then
        field = key:sub(7)
        flag = ({Background="UIThemeBg", Topbar="UIThemeTopbar", TabBackgroundSelected="UIThemeAccent",
            ElementBackground="UIThemeElemBg", TextColor="UIThemeText"})[field]
        if flag then
            local control = Rayfield.Flags and Rayfield.Flags[flag]
            if control then control:Set(color) end
            ThemeColors[field] = color
        end
    else
        flag = ColorFlagMap[key]
        if flag and Rayfield.Flags and Rayfield.Flags[flag] then
            Rayfield.Flags[flag]:Set(color)
        end
    end
end

-- // ============================================================ // --
-- Replaces the old push-based EnforceActiveTabState approach, which had two bugs:
--  1. Tab button clicks were tracked via MouseButton1Click — Rayfield may use Activated
--     or overlay frames, so the click often didn't register, leaving CurrentActiveTabName
--     permanently stuck on "Home".
--  2. On window reopen, the Visible handler immediately forced "Home" visible and hid
--     whatever tab Rayfield had natively selected, causing the wrong-tab symptom.
--
-- New approach: we attach a Visible observer to EACH tab container. Whenever Rayfield
-- itself shows a container (via its own internal routing), we record that as the active
-- tab and hide any others that leaked visibility. This is purely reactive — no timer
-- polls, no forced overrides on window open.

local TabRegistry = {
    { Name = "Home",       Tab = HomeTab         },
    { Name = "Combat",     Tab = MainTab         },
    { Name = "Visuals",    Tab = VisualTab       },
    { Name = "Triggerbot", Tab = TriggerbotTab   },
    { Name = "Intel",      Tab = IntelTab        },
    { Name = "Advanced",   Tab = AdvancedTab     },
    { Name = "Settings",   Tab = SettingsTab     },
    { Name = "Presets",    Tab = PresetsTab      },
    { Name = "Theming",    Tab = CustomizationTab},
    { Name = "Misc",       Tab = MiscTab         },
    { Name = "System",     Tab = SystemTab       },
    { Name = "Update Log", Tab = UpdateLogTab    },
}

local function ResolveTabContainer(tabObj)
    if type(tabObj) ~= "table" then return nil end
    return tabObj.Container or tabObj.ElementsFrame or tabObj.Frame or tabObj.Page or tabObj.Scroller
end

-- Observe each tab container. When Rayfield makes a container Visible, record it as the
-- canonical active tab and collapse any other container that incorrectly became visible
-- at the same time (e.g. due to animation or Rayfield re-render).
local _tabSyncGuard = false  -- prevents re-entrant chained callbacks

for _, entry in ipairs(TabRegistry) do
    local c = ResolveTabContainer(entry.Tab)
    if c and typeof(c) == "Instance" then
        table.insert(getgenv().TASFF.Connections, c:GetPropertyChangedSignal("Visible"):Connect(function()
            if _tabSyncGuard then return end
            if not c.Visible then return end  -- only care about containers becoming visible
            -- This container just became visible — it is now the active tab
            local activeName = entry.Name
            S._CurrentActiveTab = activeName
            -- Collapse all other tab containers that might also be showing
            _tabSyncGuard = true
            for _, other in ipairs(TabRegistry) do
                if other.Name ~= activeName then
                    local oc = ResolveTabContainer(other.Tab)
                    if oc and typeof(oc) == "Instance" and oc.Visible then
                        pcall(function() oc.Visible = false end)
                    end
                end
            end
            _tabSyncGuard = false
            if TASFFTheme and TASFFTheme.PatchRayfieldDOM then
                task.defer(TASFFTheme.PatchRayfieldDOM)
            end
        end))
    end
end

S.UIInitialized = true
print("[TASFF UI] Interface constructed. Configuration loaded.")

-- Trigger theme runtime patch immediately upon UI creation
if TASFFTheme and TASFFTheme.PatchRayfieldDOM then
    task.spawn(function()
        task.wait(0.15)
        TASFFTheme.PatchRayfieldDOM()
    end)
end







