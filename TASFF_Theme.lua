-- // ============================================================ // --
-- //   TASFF_Theme.lua  v2.3.0+                                   // --
-- //   Centralised theme, window config, AND Rayfield UI patches. // --
-- //   Load AFTER TASFF_State.lua, BEFORE TASFF_UI.lua.           // --
-- // ============================================================ // --

local S = _G.TASFF_State
if not S then warn("[TASFF Theme] State not ready."); return end

local TASFFEnv = (getgenv and getgenv().TASFF) or {}
local Connections = TASFFEnv.Connections or {}

-- ── Base Theme Defaults ──────────────────────────────────────────
local ThemeColorDefaults = {
    Background            = Color3.fromRGB(15,  15,  15),
    Topbar                = Color3.fromRGB(20,  20,  20),
    TabBackgroundSelected = Color3.fromRGB(60,  60,  60),
    ElementBackground     = Color3.fromRGB(28,  28,  28),
    TextColor             = Color3.fromRGB(240, 240, 240),
}

-- ── Global Theme Options ─────────────────────────────────────────
local GlobalThemeOptions = {
    "Default","Ocean","AmberGlow","Amethyst","Green","Bloom",
    "DarkBlue","Serenity","Light","Cyberpunk","Crimson Blood",
    "Emerald Forest","Solaris Gold","Retro Synth","Dracula",
    "Monochrome Void","Sakura","Toxic Slime","Glacier",
}

local GlobalThemePalettes = {
    Default         = {Base="#F0F0F0",Overlay="#F0F0F0",Drawing="#C8C8C8",Priority="#FF4D4D",Threat="#FF884D",Nemesis="#B366FF",Blacklist="#FFB347",Chams="#B4B4B4",Combat="#FFFFFF",Visible="#4DFFA6",Hidden="#FF4D6D",UIBackground="#0F0F0F",UITopbar="#141414",UIAccent="#3C3C3C",UIElement="#1C1C1C",UIText="#F0F0F0"},
    Ocean           = {Base="#D8F7FF",Overlay="#38DDF2",Drawing="#49B8D0",Priority="#FF5B6E",Threat="#FF965C",Nemesis="#B991FF",Blacklist="#FFB14A",Chams="#1EB9D4",Combat="#FFF1A8",Visible="#51E6A3",Hidden="#FF647C",UIBackground="#071923",UITopbar="#0D2532",UIAccent="#22D3EE",UIElement="#102D3A",UIText="#E4F7FA"},
    AmberGlow       = {Base="#FFF0D6",Overlay="#FFC46B",Drawing="#E5A34A",Priority="#FF5555",Threat="#FF7A32",Nemesis="#C58BFF",Blacklist="#FFD166",Chams="#E58D2B",Combat="#FFF2A6",Visible="#8BE28B",Hidden="#FF6262",UIBackground="#1A1510",UITopbar="#292016",UIAccent="#F5A623",UIElement="#332719",UIText="#FFF1D6"},
    Amethyst        = {Base="#F3E8FF",Overlay="#C4A1FF",Drawing="#A67DE8",Priority="#FF667D",Threat="#FF9D66",Nemesis="#E0A8FF",Blacklist="#FFC36E",Chams="#8B5CF6",Combat="#FFE6A6",Visible="#75E6B0",Hidden="#FF6685",UIBackground="#160F20",UITopbar="#21152F",UIAccent="#A855F7",UIElement="#2A1D3B",UIText="#F2E9FF"},
    Green           = {Base="#E4FFE7",Overlay="#5CFF77",Drawing="#30D957",Priority="#FF5570",Threat="#FF9A45",Nemesis="#C58BFF",Blacklist="#FFD44D",Chams="#24C94B",Combat="#FFF06A",Visible="#7CFF5B",Hidden="#FF5460",UIBackground="#07140B",UITopbar="#0D2113",UIAccent="#39E75F",UIElement="#142B1A",UIText="#E7FFE9"},
    Bloom           = {Base="#FFF1F7",Overlay="#FF91C8",Drawing="#EC91BE",Priority="#E85D75",Threat="#F49A59",Nemesis="#A987DC",Blacklist="#EAAE64",Chams="#D884B5",Combat="#FFE3A6",Visible="#7CCFA3",Hidden="#E66C80",UIBackground="#241923",UITopbar="#32212F",UIAccent="#E88BB9",UIElement="#3B2A38",UIText="#FFF0F6"},
    DarkBlue        = {Base="#E2EDFF",Overlay="#5EA6FF",Drawing="#5487D6",Priority="#FF526A",Threat="#FF965C",Nemesis="#B48CFF",Blacklist="#FFC05C",Chams="#3978D6",Combat="#FFE99A",Visible="#59D7AA",Hidden="#FF617A",UIBackground="#08111F",UITopbar="#101D31",UIAccent="#438DFF",UIElement="#162640",UIText="#EAF2FF"},
    Serenity        = {Base="#F0F1F6",Overlay="#AAB8D8",Drawing="#8796B5",Priority="#E87583",Threat="#E99A69",Nemesis="#A28BD0",Blacklist="#D6AD72",Chams="#778BAA",Combat="#F0DFA8",Visible="#81C6A7",Hidden="#E87C8C",UIBackground="#171A21",UITopbar="#222731",UIAccent="#8799C0",UIElement="#2B303B",UIText="#EEF0F6"},
    Light           = {Base="#20242A",Overlay="#2878D0",Drawing="#51677D",Priority="#C93449",Threat="#D46A28",Nemesis="#7848B8",Blacklist="#B46A16",Chams="#347AB8",Combat="#C18A16",Visible="#178A52",Hidden="#C93449",UIBackground="#F4F5F7",UITopbar="#E5E8ED",UIAccent="#3478C8",UIElement="#FFFFFF",UIText="#20242A"},
    Cyberpunk       = {Base="#F8F4FF",Overlay="#00F5FF",Drawing="#00BFCB",Priority="#FF2A8A",Threat="#FF7A18",Nemesis="#C357FF",Blacklist="#FFD400",Chams="#00D9E8",Combat="#FFE600",Visible="#39FF88",Hidden="#FF2A64",UIBackground="#05030A",UITopbar="#100817",UIAccent="#FF2EAA",UIElement="#160D20",UIText="#F8F4FF"},
    ["Crimson Blood"]   = {Base="#F6E9EC",Overlay="#F05265",Drawing="#C9374B",Priority="#FF304A",Threat="#FF7A43",Nemesis="#B887D1",Blacklist="#E5A044",Chams="#A8112C",Combat="#FFD2A1",Visible="#63C994",Hidden="#FF3D55",UIBackground="#100609",UITopbar="#1D0A10",UIAccent="#C91E3A",UIElement="#2A1018",UIText="#F6E9EC"},
    ["Emerald Forest"]  = {Base="#E8F5E9",Overlay="#63D99A",Drawing="#42B77A",Priority="#FF6675",Threat="#FF9A4D",Nemesis="#B992D6",Blacklist="#E9C46A",Chams="#178A55",Combat="#FFE08A",Visible="#75E6A1",Hidden="#F05B67",UIBackground="#07140F",UITopbar="#10231A",UIAccent="#29A96B",UIElement="#193326",UIText="#E9F6EE"},
    ["Solaris Gold"]    = {Base="#FFF5D6",Overlay="#FFD45C",Drawing="#C7A64B",Priority="#FF5965",Threat="#FF8A3D",Nemesis="#BA91D7",Blacklist="#FFE27A",Chams="#C49A36",Combat="#FFF078",Visible="#80D6A1",Hidden="#FF5B61",UIBackground="#100E08",UITopbar="#1D190D",UIAccent="#D5A932",UIElement="#2A2415",UIText="#FFF4D5"},
    ["Retro Synth"]     = {Base="#FFF0E4",Overlay="#FF9A56",Drawing="#E47A4C",Priority="#FF4D75",Threat="#FFB04A",Nemesis="#C174E8",Blacklist="#F3D05B",Chams="#D95B77",Combat="#FFE28A",Visible="#62D7A2",Hidden="#FF5870",UIBackground="#160D20",UITopbar="#251332",UIAccent="#FF784F",UIElement="#321C3C",UIText="#FFF0E4"},
    Dracula         = {Base="#F8F8F2",Overlay="#BD93F9",Drawing="#A67AE8",Priority="#FF5C7A",Threat="#FF9E64",Nemesis="#D6A7FF",Blacklist="#F1C56B",Chams="#9C6ADE",Combat="#F1FA8C",Visible="#50FA7B",Hidden="#FF5555",UIBackground="#191622",UITopbar="#242133",UIAccent="#BD93F9",UIElement="#302C40",UIText="#F8F8F2"},
    ["Monochrome Void"] = {Base="#FFFFFF",Overlay="#FFFFFF",Drawing="#D0D0D0",Priority="#FFFFFF",Threat="#C4C4C4",Nemesis="#EEEEEE",Blacklist="#AAAAAA",Chams="#BDBDBD",Combat="#FFFFFF",Visible="#F2F2F2",Hidden="#888888",UIBackground="#000000",UITopbar="#080808",UIAccent="#FFFFFF",UIElement="#151515",UIText="#FFFFFF"},
    Sakura          = {Base="#FFF0F5",Overlay="#F5A3C7",Drawing="#D77FA8",Priority="#FF547D",Threat="#FF976D",Nemesis="#B58AE0",Blacklist="#E9B45C",Chams="#C96F99",Combat="#FFE2A8",Visible="#71D5A2",Hidden="#F05472",UIBackground="#191419",UITopbar="#261D25",UIAccent="#E98DB4",UIElement="#30262F",UIText="#FFF0F5"},
    ["Toxic Slime"]     = {Base="#F1FFD6",Overlay="#B6FF00",Drawing="#83D600",Priority="#FF3D67",Threat="#FF8F20",Nemesis="#C57AFF",Blacklist="#F4ED00",Chams="#66C900",Combat="#F4FF37",Visible="#62FF57",Hidden="#FF3355",UIBackground="#0A1005",UITopbar="#141F08",UIAccent="#A6E600",UIElement="#1E2B0D",UIText="#F2FFD9"},
    Glacier         = {Base="#F2FAFF",Overlay="#B8E8FF",Drawing="#86C4E0",Priority="#F06A7C",Threat="#EFA16D",Nemesis="#A995D7",Blacklist="#E1BD78",Chams="#6AAFCB",Combat="#FFF0B0",Visible="#69D6B0",Hidden="#F06A7C",UIBackground="#11191F",UITopbar="#1C2931",UIAccent="#9ADCF5",UIElement="#263640",UIText="#F1FAFF"},
}

local ColorPresetMap = {
    ["Purple"]="#8A2BE2",["Cyan"]="#00FFFF",["Red"]="#FF0000",["Black"]="#000000",
    ["Yellow"]="#FFFF00",["Lime"]="#00FF00",["Green"]="#008000",["Orange"]="#FFA500",
    ["White"]="#FFFFFF",["Blue"]="#0000FF",["Brown"]="#8B4513",["Pink"]="#FFC0CB",
    ["Gray"]="#808080",["Maroon"]="#800000",["Tan"]="#D2B48C",["Coral"]="#FF7F50",
    ["Banana"]="#FADA5E",["Rose"]="#FF007F",
}
-- Convert hex strings to Color3
for k, hex in pairs(ColorPresetMap) do
    local r = tonumber(hex:sub(2,3),16)/255
    local g = tonumber(hex:sub(4,5),16)/255
    local b = tonumber(hex:sub(6,7),16)/255
    ColorPresetMap[k] = Color3.new(r,g,b)
end

local ColorDropdownOptions = {
    "Purple","Cyan","Red","Black","Yellow","Lime","Green","Orange",
    "White","Blue","Brown","Pink","Gray","Maroon","Tan","Coral","Banana","Rose",
}

local GlobalThemeColorNames = {
    {"White",Color3.fromRGB(255,255,255)},{"Soft White",Color3.fromRGB(235,240,245)},
    {"Black",Color3.fromRGB(8,8,8)},{"Gray",Color3.fromRGB(128,128,128)},
    {"Silver",Color3.fromRGB(200,205,215)},{"Slate",Color3.fromRGB(105,120,140)},
    {"Red",Color3.fromRGB(220,45,65)},{"Crimson",Color3.fromRGB(160,20,45)},
    {"Orange",Color3.fromRGB(240,125,45)},{"Amber",Color3.fromRGB(230,165,45)},
    {"Gold",Color3.fromRGB(210,175,65)},{"Yellow",Color3.fromRGB(240,225,70)},
    {"Green",Color3.fromRGB(45,175,90)},{"Emerald",Color3.fromRGB(35,145,100)},
    {"Lime",Color3.fromRGB(155,220,45)},{"Cyan",Color3.fromRGB(45,200,220)},
    {"Ice Blue",Color3.fromRGB(145,215,245)},{"Blue",Color3.fromRGB(55,125,220)},
    {"Navy",Color3.fromRGB(25,45,90)},{"Teal",Color3.fromRGB(40,145,150)},
    {"Purple",Color3.fromRGB(130,75,190)},{"Violet",Color3.fromRGB(155,80,220)},
    {"Lavender",Color3.fromRGB(185,155,225)},{"Pink",Color3.fromRGB(230,135,180)},
    {"Hot Pink",Color3.fromRGB(245,55,150)},
}

local GlobalThemeColorFields = {
    {title="Default Highlight & Tags",  field="HighlightColor",         role="Base"},
    {title="FOV Circle",                field="FOVColor",               role="Overlay"},
    {title="Crosshair",                 field="CrosshairColor",         role="Overlay"},
    {title="Box ESP",                   field="BoxColor",               role="Drawing"},
    {title="Skeleton ESP",              field="SkeletonColor",          role="Drawing"},
    {title="Snaplines",                 field="SnaplineColor",          role="Drawing"},
    {title="Off-Screen Arrows",         field="OOFArrowColor",          role="Drawing"},
    {title="Priority Players",          field="PriorityHighlightColor", role="Priority"},
    {title="Threat Players",            field="ThreatHighlightColor",   role="Threat"},
    {title="Nemesis Players",           field="NemesisHighlightColor",  role="Nemesis"},
    {title="Blacklisted Players",       field="BlacklistedTagColor",    role="Blacklist"},
    {title="Chams",                     field="ChamsColor",             role="Chams"},
    {title="Kill Flash",                field="KillFlashColor",         role="Combat"},
    {title="Visible Target",            field="VisibleColor",           role="Visible"},
    {title="Hidden Target",             field="HiddenColor",            role="Hidden"},
    {title="Environmental ESP",         field="EnvironmentalESPColor",  role="Drawing"},
    {title="UI Background",     themeField="Background",                role="UIBackground"},
    {title="UI Topbar",         themeField="Topbar",                    role="UITopbar"},
    {title="UI Selected Accent",themeField="TabBackgroundSelected",     role="UIAccent"},
    {title="UI Element BG",     themeField="ElementBackground",         role="UIElement"},
    {title="UI Text",           themeField="TextColor",                 role="UIText"},
}
-- ── Tooltip / Glossary Definitions Map ───────────────────────────
local ControlTooltips = {
    ["Master Switch"] = "Global killswitch for all combat systems. When off, no aimbot, triggerbot, or locks run.",
    ["Silent Aim"] = "Redirects weapon projectiles or raycasts toward the target without moving your camera.",
    ["Sticky Aim"] = "Prevents switching targets until the current target is dead or completely out of range/view.",
    ["Humanized Aim"] = "Simulates human motor imperfections (curved paths, tremor, inertia) to bypass spectator scrutiny.",
    ["Aim Arc"] = "Curvature intensity of the aim path towards the target instead of a straight line.",
    ["Aim Deadzone (px)"] = "Pixel radius around crosshair where aimbot applies zero adjustment to eliminate micro-jitter.",
    ["Hand Tremor"] = "Injects microscopic involuntary hand tremor oscillations into mouse movements.",
    ["Target Inertia"] = "Accounts for target velocity damping, leading shots smoothly during momentum changes.",
    ["Hitbox Drift"] = "Slowly wanders lock position across the target's torso/head instead of pinning to an exact joint center.",
    ["Cover Anticipation"] = "Temporarily keeps aiming at cover edge when a target ducks behind geometry, waiting for repassing.",
    ["VOS Priority Parts"] = "Visible On Screen body parts order: selects highest priority visible part before falling back.",
    ["Randomize Hitbox"] = "Randomly cycles between eligible body parts on each target acquisition.",
    ["Center-Screen Priority"] = "Prioritizes targets closest to screen center over nearest distance.",
    ["Dynamic FOV"] = "Scales FOV radius inversely with target distance (larger close-up, tighter at long range).",
    ["Chams"] = "Draws highlighted visual boxes around character limbs that remain visible through solid geometry.",
    ["Environmental ESP"] = "Highlights world props, terrain slices, and cover objects near targets.",
    ["OOF Arrows"] = "Off-screen indicators that point in the direction of out-of-view enemies.",
    ["Threat Detector"] = "Monitors who is aiming at or damaging you and flags them as active threats.",
    ["Kill Feed"] = "Scans game kill feeds and damage tags to attribute kills and threat rankings.",
    ["Nemesis System"] = "Tracks repeat attackers; permanently marks frequent killers with distinct visual cues.",
    ["Click-to-Mark"] = "Allows manual target tagging by clicking or pressing a hotkey while looking at a player.",
    ["Focus Mode"] = "Suppresses non-priority ESP elements when engaging priority or nemesis targets.",
    ["Screen Cloaking"] = "Hides all TASFF overlays from OBS, Discord, and screen capture software.",
    ["Performance Mode"] = "Adjusts frame-skipping intervals to maximize performance on low-end hardware.",
}

--- Returns Rayfield Window Config
local function GetWindowConfig(themeColors, selectedThemeName)
    local tc = themeColors or ThemeColorDefaults
    return {
        Name            = "TASFF " .. (S.CurrentVersion or "2.3.0") .. " — " .. (selectedThemeName or "Default"),
        Icon            = 7488932264,
        LoadingTitle    = "The Aimbot Script Final Form",
        LoadingSubtitle = "by Plasmazzm",
        Theme = {
            TextColor                     = tc.TextColor,
            Background                    = tc.Background,
            Topbar                        = tc.Topbar,
            Shadow                        = Color3.fromRGB(10,  10,  10),
            NotificationBackground        = Color3.fromRGB(15,  15,  15),
            NotificationActionsBackground = Color3.fromRGB(35,  35,  35),
            TabBackground                 = Color3.fromRGB(25,  25,  25),
            TabStroke                     = tc.ElementBackground,
            TabBackgroundSelected         = tc.TabBackgroundSelected,
            TabTextColor                  = tc.TextColor,
            SelectedTabTextColor          = Color3.fromRGB(255, 255, 255),
            ElementBackground             = tc.ElementBackground,
            ElementBackgroundHover        = Color3.fromRGB(35,  35,  35),
            SecondaryElementBackground    = Color3.fromRGB(20,  20,  20),
            ElementStroke                 = Color3.fromRGB(40,  40,  40),
            SecondaryElementStroke        = Color3.fromRGB(35,  35,  35),
            SliderBackground              = tc.ElementBackground,
            SliderProgress                = tc.TabBackgroundSelected,
            SliderStroke                  = tc.TabBackgroundSelected,
            ToggleBackground              = tc.ElementBackground,
            ToggleEnabled                 = tc.TabBackgroundSelected,
            ToggleDisabled                = Color3.fromRGB(60,  60,  60),
            ToggleEnabledStroke           = tc.TabBackgroundSelected,
            ToggleDisabledStroke          = Color3.fromRGB(80,  80,  80),
            ToggleEnabledOuterStroke      = tc.TabBackgroundSelected,
            ToggleDisabledOuterStroke     = Color3.fromRGB(45,  45,  45),
            DropdownSelected              = tc.TabBackgroundSelected,
            DropdownUnselected            = Color3.fromRGB(25,  25,  25),
            InputBackground               = Color3.fromRGB(20,  20,  20),
            InputStroke                   = tc.TabBackgroundSelected,
            PlaceholderColor              = Color3.fromRGB(150, 150, 150),
        },
        ConfigurationSaving = {
            Enabled    = true,
            FolderName = "TASFF V" .. (S.CurrentVersion or "2.3.0"),
            FileName   = "Config_Place_" .. tostring(game.PlaceId or "Global")
        }
    }
end

local function GetDefaultThemeColors()
    return table.clone(ThemeColorDefaults)
end

-- Export module functions & tables
TASFFEnv.Theme = TASFFEnv.Theme or {}
TASFFEnv.Theme.GetWindowConfig        = GetWindowConfig
TASFFEnv.Theme.GetDefaultThemeColors  = GetDefaultThemeColors
TASFFEnv.Theme.ColorPresetMap         = ColorPresetMap
TASFFEnv.Theme.ColorDropdownOptions   = ColorDropdownOptions
TASFFEnv.Theme.GlobalThemeOptions     = GlobalThemeOptions
TASFFEnv.Theme.GlobalThemePalettes    = GlobalThemePalettes
TASFFEnv.Theme.GlobalThemeColorNames  = GlobalThemeColorNames
TASFFEnv.Theme.GlobalThemeColorFields = GlobalThemeColorFields
TASFFEnv.Theme.ColorFields            = {
    "HighlightColor", "FOVColor", "CrosshairColor", "BoxColor", "SkeletonColor",
    "SnaplineColor", "OOFArrowColor", "PriorityHighlightColor", "ThreatHighlightColor",
    "NemesisHighlightColor", "BlacklistedTagColor", "ChamsColor", "KillFlashColor",
    "VisibleColor", "HiddenColor", "EnvironmentalESPColor"
}
TASFFEnv.Theme.ColorFlagMap           = {
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
TASFFEnv.Theme.Defaults               = ThemeColorDefaults
TASFFEnv.Theme.ControlTooltips        = ControlTooltips
-- // ============================================================ // --
-- //   RUNTIME UI EXTENSIONS & OVERLAYS                          // --
-- // ============================================================ // --

local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Master GUI container for TASFF Overlays
local OverlayGui = Instance.new("ScreenGui")
OverlayGui.Name = "TASFF_OverlayGui"
OverlayGui.ResetOnSpawn = false
OverlayGui.DisplayOrder = 999999999
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(OverlayGui); OverlayGui.Parent = CoreGui
    elseif gethui then OverlayGui.Parent = gethui()
    else OverlayGui.Parent = CoreGui end
end)

-- ── 1. Persistent HUD Strip ──────────────────────────────────────
local HUDStrip = Instance.new("Frame")
HUDStrip.Name = "HUDStrip"
HUDStrip.Size = UDim2.new(0, 520, 0, 26)
HUDStrip.Position = UDim2.new(0.5, -260, 0, 4)
HUDStrip.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
HUDStrip.BackgroundTransparency = 0.25
HUDStrip.BorderSizePixel = 0
HUDStrip.Visible = (S.HUDStripEnabled ~= false)
HUDStrip.Parent = OverlayGui

local HUDCorner = Instance.new("UICorner", HUDStrip)
HUDCorner.CornerRadius = UDim.new(0, 6)
local HUDStroke = Instance.new("UIStroke", HUDStrip)
HUDStroke.Color = Color3.fromRGB(45, 45, 55)
HUDStroke.Thickness = 1

local HUDLabel = Instance.new("TextLabel", HUDStrip)
HUDLabel.Size = UDim2.new(1, -12, 1, 0)
HUDLabel.Position = UDim2.new(0, 6, 0, 0)
HUDLabel.BackgroundTransparency = 1
HUDLabel.Font = Enum.Font.GothamMedium
HUDLabel.TextSize = 12
HUDLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
HUDLabel.TextXAlignment = Enum.TextXAlignment.Center
HUDLabel.Text = "[TASFF v2.3.0] Initializing..."

-- Update HUD Strip on RenderStepped
local _lastFpsTime, _fpsFrames, _currFps = tick(), 0, 60
table.insert(Connections, RunService.RenderStepped:Connect(function()
    _fpsFrames = _fpsFrames + 1
    local now = tick()
    if now - _lastFpsTime >= 0.5 then
        _currFps = math.floor(_fpsFrames / (now - _lastFpsTime))
        _fpsFrames = 0
        _lastFpsTime = now
    end

    if HUDStrip.Visible ~= (S.HUDStripEnabled ~= false) then
        HUDStrip.Visible = (S.HUDStripEnabled ~= false)
    end
    if not HUDStrip.Visible then return end

    local aimbotStr = S.AimbotEnabled and "<font color='#4DFF88'>AIM: ON</font>" or "<font color='#FF5555'>AIM: OFF</font>"
    local silentStr = S.SilentAimEnabled and " | <font color='#00F5FF'>SILENT</font>" or ""
    local humanStr = S.HumanizedAimEnabled and " | <font color='#FFD45C'>HUMAN</font>" or ""
    local threats = (S.ThreatPlayers and #S.ThreatPlayers or 0)
    local threatStr = threats > 0 and (" | <font color='#FF4444'>THREATS: " .. threats .. "</font>") or ""
    local tgtName = S.CurrentTarget and S.CurrentTarget.Name or "None"
    local presetStr = S.ActivePresetName or "Default"

    HUDLabel.RichText = true
    HUDLabel.Text = string.format("[TASFF] %s%s%s | TGT: %s%s | P: %s | %d FPS",
        aimbotStr, silentStr, humanStr, tgtName, threatStr, presetStr, _currFps)
end))

-- ── 2. Threat Radar Mini-Map ─────────────────────────────────────
local RadarFrame = Instance.new("Frame")
RadarFrame.Name = "RadarFrame"
RadarFrame.Size = UDim2.new(0, 140, 0, 140)
RadarFrame.Position = UDim2.new(0, 20, 0.5, -70)
RadarFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
RadarFrame.BackgroundTransparency = 0.35
RadarFrame.BorderSizePixel = 0
RadarFrame.Visible = (S.RadarEnabled == true)
RadarFrame.ClipsDescendants = true
RadarFrame.Parent = OverlayGui

local RadarCorner = Instance.new("UICorner", RadarFrame)
RadarCorner.CornerRadius = UDim.new(1, 0)
local RadarStroke = Instance.new("UIStroke", RadarFrame)
RadarStroke.Color = Color3.fromRGB(60, 60, 75)
RadarStroke.Thickness = 1.5

-- Center Crosshair for Radar
local RadarCenter = Instance.new("Frame", RadarFrame)
RadarCenter.Size = UDim2.new(0, 4, 0, 4)
RadarCenter.Position = UDim2.new(0.5, -2, 0.5, -2)
RadarCenter.BackgroundColor3 = Color3.fromRGB(0, 255, 200)
Instance.new("UICorner", RadarCenter).CornerRadius = UDim.new(1, 0)

-- Dragging for Radar
local _draggingRadar, _dragStart, _startPos = false, nil, nil
RadarFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        _draggingRadar = true
        _dragStart = input.Position
        _startPos = RadarFrame.Position
    end
end)
RadarFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        _draggingRadar = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if _draggingRadar and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - _dragStart
        RadarFrame.Position = UDim2.new(_startPos.X.Scale, _startPos.X.Offset + delta.X, _startPos.Y.Scale, _startPos.Y.Offset + delta.Y)
    end
end)

local RadarBlips = {}
table.insert(Connections, RunService.RenderStepped:Connect(function()
    RadarFrame.Visible = (S.RadarEnabled == true)
    if not RadarFrame.Visible then
        for _, b in pairs(RadarBlips) do b.Visible = false end
        return
    end

    local char = LocalPlayer and LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local cam = workspace.CurrentCamera
    local camCFrame = cam and cam.CFrame or root.CFrame
    local maxDist = S.AimbotRenderDistance or 300
    local halfSize = 70

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local pRoot = p.Character.HumanoidRootPart
            local relPos = camCFrame:PointToObjectSpace(pRoot.Position)
            -- X is right, -Z is forward
            local mapX = (relPos.X / maxDist) * halfSize
            local mapY = (-relPos.Z / maxDist) * halfSize
            local distFromCenter = math.sqrt(mapX*mapX + mapY*mapY)

            local blip = RadarBlips[p]
            if not blip then
                blip = Instance.new("Frame", RadarFrame)
                blip.Size = UDim2.new(0, 5, 0, 5)
                Instance.new("UICorner", blip).CornerRadius = UDim.new(1, 0)
                RadarBlips[p] = blip
            end

            if distFromCenter <= (halfSize - 4) then
                blip.Position = UDim2.new(0.5, mapX - 2.5, 0.5, mapY - 2.5)
                blip.Visible = true
                -- Color coding
                if S.NemesisMemory and S.NemesisMemory[p.Name] then
                    blip.BackgroundColor3 = S.NemesisHighlightColor or Color3.fromRGB(180, 100, 255)
                elseif S.ThreatPlayers and table.find(S.ThreatPlayers, p.Name) then
                    blip.BackgroundColor3 = S.ThreatHighlightColor or Color3.fromRGB(255, 60, 60)
                elseif S.PriorityPlayers and table.find(S.PriorityPlayers, p.Name) then
                    blip.BackgroundColor3 = S.PriorityHighlightColor or Color3.fromRGB(255, 215, 0)
                else
                    blip.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
                end
            else
                blip.Visible = false
            end
        else
            if RadarBlips[p] then RadarBlips[p].Visible = false end
        end
    end
end))

-- ── 3. Notification Sidebar Strip ────────────────────────────────
local SidebarFrame = Instance.new("Frame")
SidebarFrame.Name = "SidebarFrame"
SidebarFrame.Size = UDim2.new(0, 220, 0, 300)
SidebarFrame.Position = UDim2.new(1, -230, 0.5, -150)
SidebarFrame.BackgroundTransparency = 1
SidebarFrame.Visible = (S.SidebarEnabled ~= false)
SidebarFrame.Parent = OverlayGui

local SidebarList = Instance.new("UIListLayout", SidebarFrame)
SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
SidebarList.Padding = UDim.new(0, 6)
SidebarList.VerticalAlignment = Enum.VerticalAlignment.Bottom

local function PushSidebarNotification(title, msg, color)
    if not (S.SidebarEnabled ~= false) then return end
    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(1, 0, 0, 36)
    pill.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    pill.BackgroundTransparency = 0.2
    pill.BorderSizePixel = 0
    pill.Parent = SidebarFrame

    Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", pill)
    stroke.Color = color or Color3.fromRGB(0, 200, 255)
    stroke.Thickness = 1

    local tLabel = Instance.new("TextLabel", pill)
    tLabel.Size = UDim2.new(1, -12, 0, 16)
    tLabel.Position = UDim2.new(0, 8, 0, 2)
    tLabel.BackgroundTransparency = 1
    tLabel.Font = Enum.Font.GothamBold
    tLabel.TextSize = 11
    tLabel.TextColor3 = stroke.Color
    tLabel.TextXAlignment = Enum.TextXAlignment.Left
    tLabel.Text = title or "TASFF"

    local mLabel = Instance.new("TextLabel", pill)
    mLabel.Size = UDim2.new(1, -12, 0, 14)
    mLabel.Position = UDim2.new(0, 8, 0, 18)
    mLabel.BackgroundTransparency = 1
    mLabel.Font = Enum.Font.Gotham
    mLabel.TextSize = 10
    mLabel.TextColor3 = Color3.fromRGB(215, 215, 220)
    mLabel.TextXAlignment = Enum.TextXAlignment.Left
    mLabel.TextTruncate = Enum.TextTruncate.AtEnd
    mLabel.Text = msg or ""

    task.delay(6, function()
        TweenService:Create(pill, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
        TweenService:Create(tLabel, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
        TweenService:Create(mLabel, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.5), {Transparency = 1}):Play()
        task.wait(0.5)
        pill:Destroy()
    end)
end
TASFFEnv.Theme.PushSidebarNotification = PushSidebarNotification

-- ── 4. Floating Hover Tooltips for Controls ──────────────────────
local TooltipFrame = Instance.new("Frame")
TooltipFrame.Name = "TooltipFrame"
TooltipFrame.Size = UDim2.new(0, 240, 0, 50)
TooltipFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
TooltipFrame.BackgroundTransparency = 0.1
TooltipFrame.BorderSizePixel = 0
TooltipFrame.Visible = false
TooltipFrame.ZIndex = 1000
TooltipFrame.Parent = OverlayGui

Instance.new("UICorner", TooltipFrame).CornerRadius = UDim.new(0, 6)
local TooltipStroke = Instance.new("UIStroke", TooltipFrame)
TooltipStroke.Color = Color3.fromRGB(0, 200, 255)
TooltipStroke.Thickness = 1

local TooltipTitle = Instance.new("TextLabel", TooltipFrame)
TooltipTitle.Size = UDim2.new(1, -12, 0, 16)
TooltipTitle.Position = UDim2.new(0, 6, 0, 4)
TooltipTitle.BackgroundTransparency = 1
TooltipTitle.Font = Enum.Font.GothamBold
TooltipTitle.TextSize = 11
TooltipTitle.TextColor3 = Color3.fromRGB(0, 200, 255)
TooltipTitle.TextXAlignment = Enum.TextXAlignment.Left

local TooltipBody = Instance.new("TextLabel", TooltipFrame)
TooltipBody.Size = UDim2.new(1, -12, 1, -22)
TooltipBody.Position = UDim2.new(0, 6, 0, 20)
TooltipBody.BackgroundTransparency = 1
TooltipBody.Font = Enum.Font.Gotham
TooltipBody.TextSize = 10
TooltipBody.TextColor3 = Color3.fromRGB(220, 220, 225)
TooltipBody.TextWrapped = true
TooltipBody.TextXAlignment = Enum.TextXAlignment.Left
TooltipBody.TextYAlignment = Enum.TextYAlignment.Top

local function ShowTooltip(ctrlName, desc, mousePos)
    TooltipTitle.Text = ctrlName
    TooltipBody.Text = desc
    TooltipFrame.Position = UDim2.new(0, mousePos.X + 15, 0, mousePos.Y + 10)
    TooltipFrame.Visible = true
end
local function HideTooltip()
    TooltipFrame.Visible = false
end
-- ── 5. Rayfield DOM Tree Patch Engine ────────────────────────────
local function FindRayfieldGui()
    local candidates = {}
    pcall(function()
        if typeof(gethui) == "function" then
            local h = gethui()
            if h then table.insert(candidates, h) end
        end
    end)
    local ok1, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok1 and cg then table.insert(candidates, cg) end
    local ok2, pg = pcall(function() return Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") end)
    if ok2 and pg then table.insert(candidates, pg) end

    for _, container in ipairs(candidates) do
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("ScreenGui") and child.Name ~= "TASFF_OverlayGui" then
                if child:FindFirstChild("Main") and child.Main:FindFirstChild("Topbar") and child.Main:FindFirstChild("Elements") then
                    return child
                end
            end
        end
    end
    for _, container in ipairs(candidates) do
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("ScreenGui") and child.Name ~= "TASFF_OverlayGui" then
                local n = child.Name:lower()
                if n:find("rayfield") or n:find("sirius") or n:find("tasff") then
                    return child
                end
            end
        end
    end
    return nil
end

local function PulseTopbar(color)
    local rGui = FindRayfieldGui()
    if not rGui then return end
    local topbar = rGui:FindFirstChild("Topbar", true)
    if topbar and topbar:IsA("GuiObject") then
        local origColor = topbar.BackgroundColor3
        local pulseColor = color or Color3.fromRGB(0, 255, 170)
        TweenService:Create(topbar, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = pulseColor}):Play()
        task.delay(0.25, function()
            TweenService:Create(topbar, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundColor3 = origColor}):Play()
        end)
    end
end
TASFFEnv.Theme.PulseTopbar = PulseTopbar

local function HighlightChangedControls(changedNames)
    local rGui = FindRayfieldGui()
    if not rGui or not changedNames then return end
    for _, name in ipairs(changedNames) do
        for _, desc in ipairs(rGui:GetDescendants()) do
            if desc:IsA("TextLabel") and (desc.Text == name or desc.Text:find(name, 1, true)) then
                local parent = desc.Parent
                if parent and parent:IsA("GuiObject") then
                    local stroke = parent:FindFirstChildOfClass("UIStroke")
                    if stroke then
                        local origColor = stroke.Color
                        stroke.Color = Color3.fromRGB(255, 215, 0)
                        task.delay(1.2, function()
                            TweenService:Create(stroke, TweenInfo.new(0.5), {Color = origColor}):Play()
                        end)
                    end
                end
            end
        end
    end
end
TASFFEnv.Theme.HighlightChangedControls = HighlightChangedControls

-- Tab Badge Storage
local _tabBadges = {}
local function SetTabBadge(tabName, count)
    local badge = _tabBadges[tabName]
    if badge and badge.Parent then
        if count and count > 0 then
            badge.Text = tostring(count)
            badge.Parent.Visible = true
        else
            badge.Parent.Visible = false
        end
    end
end
TASFFEnv.Theme.SetTabBadge = SetTabBadge

-- Patch sections, tooltips, search bar, state dots, tab badges, and resize handle
local function PatchRayfieldDOM()
    local rGui = FindRayfieldGui()
    if not rGui then return false end

    local mainFrame = rGui:FindFirstChild("Main", true) or rGui:FindFirstChildOfClass("Frame")
    if not mainFrame then return false end

    if S.UIOpacity and S.UIOpacity < 1.0 then
        mainFrame.BackgroundTransparency = 1 - S.UIOpacity
    end

    -- 1. Window Resize Handle (Bottom-Right Grip)
    if not mainFrame:FindFirstChild("ResizeHandle") then
        local resizeHandle = Instance.new("TextButton")
        resizeHandle.Name = "ResizeHandle"
        resizeHandle.Size = UDim2.new(0, 18, 0, 18)
        resizeHandle.Position = UDim2.new(1, -18, 1, -18)
        resizeHandle.BackgroundTransparency = 1
        resizeHandle.Font = Enum.Font.GothamBold
        resizeHandle.TextSize = 12
        resizeHandle.TextColor3 = Color3.fromRGB(150, 150, 160)
        resizeHandle.Text = "⇲"
        resizeHandle.ZIndex = 50
        resizeHandle.Parent = mainFrame

        local _resizing = false
        local _rStart, _rSizeStart
        resizeHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                _resizing = true
                _rStart = input.Position
                _rSizeStart = mainFrame.AbsoluteSize
            end
        end)
        resizeHandle.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                _resizing = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if _resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - _rStart
                local newW = math.clamp(_rSizeStart.X + delta.X, 440, 1000)
                local newH = math.clamp(_rSizeStart.Y + delta.Y, 340, 850)
                mainFrame.Size = UDim2.new(0, newW, 0, newH)
            end
        end)
    end

    -- 2. Inject Tab Notification Badges
    local tabList = mainFrame:FindFirstChild("TabList", true)
    if tabList then
        for _, tabBtn in ipairs(tabList:GetChildren()) do
            if tabBtn:IsA("GuiObject") and tabBtn.Name ~= "Template" and tabBtn.Name ~= "UIListLayout" and tabBtn.Name ~= "UIPadding" then
                local tName = tabBtn.Name
                if not tabBtn:FindFirstChild("BadgeFrame") then
                    local bFrame = Instance.new("Frame")
                    bFrame.Name = "BadgeFrame"
                    bFrame.Size = UDim2.new(0, 16, 0, 16)
                    bFrame.Position = UDim2.new(1, -20, 0.5, -8)
                    bFrame.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
                    bFrame.BorderSizePixel = 0
                    bFrame.Visible = false
                    bFrame.ZIndex = 25
                    bFrame.Parent = tabBtn

                    Instance.new("UICorner", bFrame).CornerRadius = UDim.new(1, 0)
                    local bLabel = Instance.new("TextLabel", bFrame)
                    bLabel.Size = UDim2.new(1, 0, 1, 0)
                    bLabel.BackgroundTransparency = 1
                    bLabel.Font = Enum.Font.GothamBold
                    bLabel.TextSize = 9
                    bLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    bLabel.Text = "0"
                    _tabBadges[tName] = bLabel

                    tabBtn.InputBegan:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                            bFrame.Visible = false
                        end
                    end)
                end
            end
        end
    end

    -- 3. Inject Search Bar into Element Scrollers
    local elementsHolder = mainFrame:FindFirstChild("Elements", true)
    if elementsHolder then
        for _, page in ipairs(elementsHolder:GetChildren()) do
            if page:IsA("ScrollingFrame") and page.Name ~= "Template" and page.Name ~= "UIListLayout" and page.Name ~= "UIPadding" then
                if not page:FindFirstChild("ControlSearchBar") then
                    local searchBox = Instance.new("TextBox")
                    searchBox.Name = "ControlSearchBar"
                    searchBox.Size = UDim2.new(1, -16, 0, 26)
                    searchBox.Position = UDim2.new(0, 8, 0, 4)
                    searchBox.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
                    searchBox.BorderSizePixel = 0
                    searchBox.Font = Enum.Font.Gotham
                    searchBox.TextSize = 11
                    searchBox.TextColor3 = Color3.fromRGB(240, 240, 245)
                    searchBox.PlaceholderText = "🔍 Filter controls in " .. page.Name .. "..."
                    searchBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 135)
                    searchBox.LayoutOrder = -9999
                    searchBox.Parent = page

                    Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 5)
                    local sStroke = Instance.new("UIStroke", searchBox)
                    sStroke.Color = Color3.fromRGB(45, 45, 55)

                    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                        local query = searchBox.Text:lower():gsub("%s+", "")
                        for _, child in ipairs(page:GetChildren()) do
                            if child ~= searchBox and child:IsA("GuiObject") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
                                if query == "" then
                                    child.Visible = true
                                else
                                    local tLabel = child:FindFirstChild("Title", true) or child:FindFirstChildOfClass("TextLabel")
                                    local labelText = (tLabel and tLabel.Text or child.Name):lower():gsub("%s+", "")
                                    child.Visible = (labelText:find(query, 1, true) ~= nil)
                                end
                            end
                        end
                    end)
                end
            end
        end
    end

    -- 4. Walk Elements and inject Section collapse, Tooltips, and Live Dots
    for _, desc in ipairs(mainFrame:GetDescendants()) do
        -- Section Header Collapse/Expand Injection
        if desc:IsA("GuiObject") and (desc.Name == "SectionTitle" or desc.Name:find("Section")) then
            local secFrame = desc
            if not secFrame:FindFirstChild("CollapseToggle") then
                local toggleBtn = Instance.new("TextButton")
                toggleBtn.Name = "CollapseToggle"
                toggleBtn.Size = UDim2.new(0, 22, 0, 22)
                toggleBtn.Position = UDim2.new(1, -26, 0.5, -11)
                toggleBtn.BackgroundTransparency = 1
                toggleBtn.Font = Enum.Font.GothamBold
                toggleBtn.TextSize = 12
                toggleBtn.TextColor3 = Color3.fromRGB(150, 150, 160)
                toggleBtn.Text = "▼"
                toggleBtn.ZIndex = 15
                toggleBtn.Parent = secFrame

                local isCollapsed = false
                toggleBtn.MouseButton1Click:Connect(function()
                    isCollapsed = not isCollapsed
                    toggleBtn.Text = isCollapsed and "▶" or "▼"
                    local container = secFrame.Parent
                    if container then
                        local pastSec = false
                        for _, child in ipairs(container:GetChildren()) do
                            if child == secFrame then
                                pastSec = true
                            elseif pastSec then
                                if child.Name == "SectionTitle" or child.Name:find("Section") then break end
                                if child:IsA("GuiObject") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" and child.Name ~= "ControlSearchBar" then
                                    child.Visible = not isCollapsed
                                end
                            end
                        end
                    end
                end)
            end
        end

        -- Tooltip & Definition attachment on interactive elements
        local titleLabel = desc:FindFirstChild("Title", true)
        if titleLabel and titleLabel:IsA("TextLabel") and titleLabel.Text ~= "" then
            local cleanName = titleLabel.Text:gsub("^🔒%s*", ""):gsub(":%s*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
            local def = ControlTooltips[cleanName] or ControlTooltips[desc.Name]
            if def and not desc:FindFirstChild("TooltipHooked") then
                local hookTag = Instance.new("BoolValue")
                hookTag.Name = "TooltipHooked"
                hookTag.Parent = desc

                local function onHoverEnter()
                    local mPos = UserInputService:GetMouseLocation()
                    ShowTooltip(cleanName, def, mPos)
                    S.LastTouchedDef = cleanName
                    S.LastTouchedDefText = def
                    if S.DefinitionsParagraph and S.DefinitionsParagraph.Set then
                        pcall(function()
                            S.DefinitionsParagraph:Set({
                                Title = "Definition: " .. cleanName,
                                Content = def
                            })
                        end)
                    end
                end
                local function onHoverLeave()
                    HideTooltip()
                end

                desc.MouseEnter:Connect(onHoverEnter)
                desc.MouseLeave:Connect(onHoverLeave)

                local interact = desc:FindFirstChild("Interact")
                if interact and interact:IsA("GuiObject") then
                    interact.MouseEnter:Connect(onHoverEnter)
                    interact.MouseLeave:Connect(onHoverLeave)
                end
            end
        end

        -- Live State Dot on Toggles
        if desc:IsA("GuiObject") and desc:FindFirstChild("Switch") and not desc:FindFirstChild("LiveDot") then
            local dot = Instance.new("Frame")
            dot.Name = "LiveDot"
            dot.Size = UDim2.new(0, 6, 0, 6)
            dot.Position = UDim2.new(0, 5, 0.5, -3)
            dot.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
            dot.BorderSizePixel = 0
            Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
            dot.Parent = desc

            local switch = desc:FindFirstChild("Switch")
            local function updateDot()
                local ind = switch and switch:FindFirstChild("Indicator")
                if ind and ind.Position.X.Offset > -30 then
                    dot.BackgroundColor3 = Color3.fromRGB(0, 230, 100)
                else
                    dot.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
                end
            end
            task.delay(0.2, updateDot)
            local interact = desc:FindFirstChild("Interact")
            if interact and interact:IsA("GuiObject") then
                interact.InputEnded:Connect(function()
                    task.delay(0.1, updateDot)
                end)
            end
        end
    end

    return true
end

-- Keyboard Navigation Hook
local _navElements = {}
local _currentNavIndex = 1
local function RefreshNavElements()
    _navElements = {}
    local rGui = FindRayfieldGui()
    if not rGui then return end
    for _, d in ipairs(rGui:GetDescendants()) do
        if d:IsA("TextButton") or d:IsA("TextBox") then
            if d.Visible and d.AbsolutePosition.Y > 0 then
                table.insert(_navElements, d)
            end
        end
    end
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if not (S.KeyboardNavEnabled ~= false) then return end
    if input.KeyCode == Enum.KeyCode.Down then
        RefreshNavElements()
        if #_navElements > 0 then
            _currentNavIndex = (_currentNavIndex % #_navElements) + 1
            local elem = _navElements[_currentNavIndex]
            if elem then
                local s = elem:FindFirstChildOfClass("UIStroke")
                if s then
                    local oc = s.Color
                    s.Color = Color3.fromRGB(0, 255, 200)
                    task.delay(0.5, function() s.Color = oc end)
                end
            end
        end
    elseif input.KeyCode == Enum.KeyCode.Up then
        RefreshNavElements()
        if #_navElements > 0 then
            _currentNavIndex = _currentNavIndex - 1
            if _currentNavIndex < 1 then _currentNavIndex = #_navElements end
            local elem = _navElements[_currentNavIndex]
            if elem then
                local s = elem:FindFirstChildOfClass("UIStroke")
                if s then
                    local oc = s.Color
                    s.Color = Color3.fromRGB(0, 255, 200)
                    task.delay(0.5, function() s.Color = oc end)
                end
            end
        end
    elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
        if #_navElements > 0 and _navElements[_currentNavIndex] then
            local elem = _navElements[_currentNavIndex]
            if elem:IsA("TextButton") then
                pcall(function() elem.MouseButton1Click:Fire() end)
            end
        end
    end
end)

-- Defer initial DOM patch until Rayfield creates its window
task.spawn(function()
    for i = 1, 20 do
        task.wait(0.5)
        if PatchRayfieldDOM() then
            S.ThemePatchDone = true
            break
        end
    end
end)

TASFFEnv.Theme.PatchRayfieldDOM = PatchRayfieldDOM

print("[TASFF Theme v" .. (S.CurrentVersion or "2.3.0") .. "] Theme module and extensions fully loaded.")
