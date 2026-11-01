-- // ============================================================ // --
-- //   TASFF_Theme.lua  v2.3.0+                                   // --
-- //   Centralised theme, window config, AND Rayfield UI patches. // --
-- //   Load AFTER TASFF_State.lua, BEFORE TASFF_UI.lua.           // --
-- // ============================================================ // --

local S = _G.TASFF_State
if not S then warn("[TASFF Theme] State not ready."); return end

local TASFFEnv = (getgenv and getgenv().TASFF) or {}
local Connections = TASFFEnv.Connections or {}
local FindRayfieldGui = nil -- declared forward so early functions (e.g. UpdateDrawerPosition) can call it
local RayfieldWindow = nil

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
    local toggleKey = (typeof(S.MenuToggleKey) == "EnumItem" and S.MenuToggleKey)
        or (typeof(S.MenuToggleKey) == "string" and Enum.KeyCode[S.MenuToggleKey])
        or Enum.KeyCode.K
    return {
        Name            = "TASFF " .. (S.CurrentVersion or "2.3.0") .. " - " .. (selectedThemeName or "Default"),
        Icon            = 0,
        LoadingTitle    = "The Aimbot Script Final Form",
        LoadingSubtitle = "by Plasmazzm",
        ToggleUIKeybind = toggleKey,
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

local function HexToColor3(hex)
    if typeof(hex) == "Color3" then return hex end
    if type(hex) ~= "string" then return Color3.fromRGB(255, 255, 255) end
    hex = hex:gsub("#", "")
    if #hex < 6 then return Color3.fromRGB(255, 255, 255) end
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    return Color3.fromRGB(r, g, b)
end
TASFFEnv.Theme.HexToColor3 = HexToColor3

-- ── Visual Theme Showcase Gallery Previewer ──────────────────────
local function RenderThemePreviewCard(container, themeName)
    if not container then return end
    local existing = container:FindFirstChild("ThemePreviewCard")
    if existing then existing:Destroy() end

    local palette = GlobalThemePalettes[themeName] or GlobalThemePalettes.Default
    local uiBg = HexToColor3(palette.UIBackground)
    local uiTopbar = HexToColor3(palette.UITopbar)
    local uiAccent = HexToColor3(palette.UIAccent)
    local uiElem = HexToColor3(palette.UIElement)
    local uiText = HexToColor3(palette.UIText)

    local card = Instance.new("Frame")
    card.Name = "ThemePreviewCard"
    card.Size = UDim2.new(1, 0, 0, 145)
    card.BackgroundColor3 = uiBg
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local cardStroke = Instance.new("UIStroke", card)
    cardStroke.Color = uiAccent
    cardStroke.Thickness = 1.5

    -- Mini Topbar
    local topbar = Instance.new("Frame", card)
    topbar.Size = UDim2.new(1, 0, 0, 24)
    topbar.BackgroundColor3 = uiTopbar
    topbar.BorderSizePixel = 0
    Instance.new("UICorner", topbar).CornerRadius = UDim.new(0, 8)

    local topbarTitle = Instance.new("TextLabel", topbar)
    topbarTitle.Size = UDim2.new(1, -60, 1, 0)
    topbarTitle.Position = UDim2.new(0, 8, 0, 0)
    topbarTitle.BackgroundTransparency = 1
    topbarTitle.Font = Enum.Font.GothamBold
    topbarTitle.TextSize = 11
    topbarTitle.TextColor3 = uiText
    topbarTitle.TextXAlignment = Enum.TextXAlignment.Left
    topbarTitle.Text = "TASFF 2.3.0  |  Theme: " .. tostring(themeName)

    -- Window Action Dots
    local dots = {"#FF5555", "#FFBD2E", "#27C93F"}
    for i, hex in ipairs(dots) do
        local dot = Instance.new("Frame", topbar)
        dot.Size = UDim2.new(0, 7, 0, 7)
        dot.Position = UDim2.new(1, -12 - (3 - i) * 11, 0.5, -3)
        dot.BackgroundColor3 = HexToColor3(hex)
        dot.BorderSizePixel = 0
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    end

    -- Mini Active Tab indicator
    local tabPill = Instance.new("Frame", card)
    tabPill.Size = UDim2.new(0, 75, 0, 18)
    tabPill.Position = UDim2.new(0, 8, 0, 30)
    tabPill.BackgroundColor3 = uiAccent
    tabPill.BorderSizePixel = 0
    Instance.new("UICorner", tabPill).CornerRadius = UDim.new(0, 4)
    local tabLabel = Instance.new("TextLabel", tabPill)
    tabLabel.Size = UDim2.new(1, 0, 1, 0)
    tabLabel.BackgroundTransparency = 1
    tabLabel.Font = Enum.Font.GothamBold
    tabLabel.TextSize = 9
    tabLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    tabLabel.Text = "[*] Active Tab"

    -- Mini Element Card
    local elemCard = Instance.new("Frame", card)
    elemCard.Size = UDim2.new(1, -16, 0, 32)
    elemCard.Position = UDim2.new(0, 8, 0, 52)
    elemCard.BackgroundColor3 = uiElem
    elemCard.BorderSizePixel = 0
    Instance.new("UICorner", elemCard).CornerRadius = UDim.new(0, 6)
    local elemStroke = Instance.new("UIStroke", elemCard)
    elemStroke.Color = Color3.fromRGB(45, 45, 55)

    local elemText = Instance.new("TextLabel", elemCard)
    elemText.Size = UDim2.new(1, -55, 1, 0)
    elemText.Position = UDim2.new(0, 8, 0, 0)
    elemText.BackgroundTransparency = 1
    elemText.Font = Enum.Font.Gotham
    elemText.TextSize = 10
    elemText.TextColor3 = uiText
    elemText.TextXAlignment = Enum.TextXAlignment.Left
    elemText.Text = "Sample Feature Setting"

    -- Mini Toggle on the right
    local miniToggle = Instance.new("Frame", elemCard)
    miniToggle.Size = UDim2.new(0, 32, 0, 16)
    miniToggle.Position = UDim2.new(1, -38, 0.5, -8)
    miniToggle.BackgroundColor3 = uiAccent
    miniToggle.BorderSizePixel = 0
    Instance.new("UICorner", miniToggle).CornerRadius = UDim.new(1, 0)
    local toggleKnob = Instance.new("Frame", miniToggle)
    toggleKnob.Size = UDim2.new(0, 12, 0, 12)
    toggleKnob.Position = UDim2.new(1, -14, 0.5, -6)
    toggleKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    toggleKnob.BorderSizePixel = 0
    Instance.new("UICorner", toggleKnob).CornerRadius = UDim.new(1, 0)

    -- Combat Color Swatches Bar
    local swatchBar = Instance.new("Frame", card)
    swatchBar.Size = UDim2.new(1, -16, 0, 48)
    swatchBar.Position = UDim2.new(0, 8, 0, 88)
    swatchBar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    swatchBar.BackgroundTransparency = 0.4
    Instance.new("UICorner", swatchBar).CornerRadius = UDim.new(0, 6)

    local swatchTitle = Instance.new("TextLabel", swatchBar)
    swatchTitle.Size = UDim2.new(1, -10, 0, 14)
    swatchTitle.Position = UDim2.new(0, 6, 0, 2)
    swatchTitle.BackgroundTransparency = 1
    swatchTitle.Font = Enum.Font.GothamBold
    swatchTitle.TextSize = 9
    swatchTitle.TextColor3 = Color3.fromRGB(170, 170, 180)
    swatchTitle.TextXAlignment = Enum.TextXAlignment.Left
    swatchTitle.Text = "COMBAT & ESP PALETTE SWATCHES:"

    local combatItems = {
        {"VIS", palette.Visible, "Visible"},
        {"HID", palette.Hidden, "Hidden"},
        {"PRI", palette.Priority, "Priority"},
        {"THR", palette.Threat, "Threat"},
        {"NEM", palette.Nemesis, "Nemesis"},
        {"CHM", palette.Chams, "Chams"},
    }
    for i, item in ipairs(combatItems) do
        local swPill = Instance.new("Frame", swatchBar)
        swPill.Size = UDim2.new(0, 36, 0, 20)
        swPill.Position = UDim2.new(0, 6 + (i - 1) * 42, 0, 20)
        swPill.BackgroundColor3 = HexToColor3(item[2])
        swPill.BorderSizePixel = 0
        Instance.new("UICorner", swPill).CornerRadius = UDim.new(0, 4)

        local swLabel = Instance.new("TextLabel", swPill)
        swLabel.Size = UDim2.new(1, 0, 1, 0)
        swLabel.BackgroundTransparency = 1
        swLabel.Font = Enum.Font.GothamBold
        swLabel.TextSize = 8
        swLabel.TextColor3 = Color3.fromRGB(15, 15, 15)
        swLabel.Text = item[1]
    end

    card.Parent = container
    return card
end
TASFFEnv.Theme.RenderThemePreviewCard = RenderThemePreviewCard

local function ApplyRayfieldTheme(themeColors)
    if type(themeColors) ~= "table" then return false end
    TASFFEnv.Theme.ActiveThemeColors = themeColors

    local rGui = RayfieldWindow
    local mainFrame
    if rGui and typeof(rGui) == "Instance" then
        mainFrame = rGui:FindFirstChild("Main", true) or rGui:FindFirstChildOfClass("Frame")
    elseif type(rGui) == "table" then
        mainFrame = rGui.Main or rGui.main
    end
    if mainFrame and typeof(mainFrame) ~= "Instance" then
        mainFrame = nil
    end
    if not mainFrame then
        rGui = FindRayfieldGui and FindRayfieldGui()
        mainFrame = rGui and (rGui:FindFirstChild("Main", true) or rGui:FindFirstChildOfClass("Frame"))
    end
    if not rGui or not mainFrame or typeof(mainFrame) ~= "Instance" then return false end

    local function setColor(instance, property, color)
        if color and instance and instance:IsA("GuiObject") then
            instance[property] = color
        end
    end

    setColor(mainFrame, "BackgroundColor3", themeColors.Background)

    local topbar = mainFrame:FindFirstChild("Topbar", true)
    setColor(topbar, "BackgroundColor3", themeColors.Topbar)

    local elements = mainFrame:FindFirstChild("Elements", true)
    if elements and elements:IsA("ScrollingFrame") then
        elements.BackgroundColor3 = themeColors.Background
    end

    for _, descendant in ipairs(mainFrame:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
            descendant.TextColor3 = themeColors.TextColor
        elseif descendant:IsA("ScrollingFrame") then
            descendant.ScrollBarImageColor3 = themeColors.TabBackgroundSelected
        end

        if descendant.Name == "Tab" or descendant.Name == "TabButton" then
            descendant.BackgroundColor3 = themeColors.ElementBackground
        elseif descendant.Name == "Interact" or descendant.Name == "Switch" then
            descendant.BackgroundColor3 = themeColors.ElementBackground
        elseif descendant.Name == "Slider" or descendant.Name == "SliderBar" or descendant.Name == "Progress" then
            descendant.BackgroundColor3 = themeColors.TabBackgroundSelected
        end
    end

    return true
end
TASFFEnv.Theme.ApplyRayfieldTheme = ApplyRayfieldTheme
TASFFEnv.Theme.SetRayfieldWindow = function(window)
    RayfieldWindow = window
    return ApplyRayfieldTheme(TASFFEnv.Theme.ActiveThemeColors)
end

-- // ============================================================ // --
-- //   RUNTIME UI EXTENSIONS & OVERLAYS                          // --
-- // ============================================================ // --

local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local StatsService = game:GetService("Stats")
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer

-- Audio-Tactile Sound Feedback Helper
local function PlayUISound(soundType)
    if not (S.AudioFeedbackEnabled ~= false) then return end
    task.spawn(function()
        pcall(function()
            local soundId = "rbxassetid://6895079853"
            local pitch = 1.0
            if soundType == "toggle_on" then
                soundId = "rbxassetid://6895079853"
                pitch = 1.2
            elseif soundType == "toggle_off" then
                soundId = "rbxassetid://6895079853"
                pitch = 0.85
            elseif soundType == "tab" then
                soundId = "rbxassetid://9114223175"
                pitch = 1.05
            elseif soundType == "stepper" then
                soundId = "rbxassetid://9119713951"
                pitch = 1.35
            elseif soundType == "preset" then
                soundId = "rbxassetid://9114223175"
                pitch = 1.3
            end
            local snd = Instance.new("Sound")
            snd.SoundId = soundId
            snd.Volume = math.clamp((S.AudioFeedbackVolume or 0.5) * 0.45, 0, 1)
            snd.Pitch = pitch
            snd.Parent = SoundService
            snd:Play()
            snd.Ended:Connect(function()
                snd:Destroy()
            end)
            task.delay(1.5, function()
                if snd and snd.Parent then snd:Destroy() end
            end)
        end)
    end)
end
TASFFEnv.Theme.PlayUISound = PlayUISound

-- Draggable Overlay Helper (Alt-drag or direct handle drag with coordinate persistence)
local function MakeDraggable(frame, dragHandle, posKeyX, posKeyY)
    dragHandle = dragHandle or frame
    local isDragging = false
    local dragStart, frameStart
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStart = input.Position
            frameStart = frame.AbsolutePosition
        end
    end)
    dragHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if isDragging then
                isDragging = false
                if posKeyX and posKeyY then
                    S[posKeyX] = frame.Position.X.Offset
                    S[posKeyY] = frame.Position.Y.Offset
                end
            end
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local newX = frameStart.X + delta.X
            local newY = frameStart.Y + delta.Y
            frame.Position = UDim2.new(0, newX, 0, newY)
        end
    end)
    if posKeyX and posKeyY and S[posKeyX] and S[posKeyY] then
        frame.Position = UDim2.new(0, S[posKeyX], 0, S[posKeyY])
    end
end
TASFFEnv.Theme.MakeDraggable = MakeDraggable

-- Theme Color dynamic query helpers (syncs with user-selected UI theme)
local function GetThemeAccentColor()
    if TASFFEnv.Theme and TASFFEnv.Theme.ActiveThemeColors and TASFFEnv.Theme.ActiveThemeColors.TabBackgroundSelected then
        return TASFFEnv.Theme.ActiveThemeColors.TabBackgroundSelected
    end
    if S.CustomAccentColor then return S.CustomAccentColor end
    return Color3.fromRGB(0, 200, 255)
end

local function GetThemeTextColor()
    if TASFFEnv.Theme and TASFFEnv.Theme.ActiveThemeColors and TASFFEnv.Theme.ActiveThemeColors.TextColor then
        return TASFFEnv.Theme.ActiveThemeColors.TextColor
    end
    return Color3.fromRGB(240, 240, 245)
end

local function GetCurrentPing()
    local ping = 0
    pcall(function()
        local net = StatsService:FindFirstChild("Network")
        if net then
            local serverStats = net:FindFirstChild("ServerStatsItem")
            if serverStats then
                local dataPing = serverStats:FindFirstChild("Data Ping")
                if dataPing then
                    ping = math.floor(dataPing:GetValue())
                    return
                end
            end
        end
        local perf = StatsService:FindFirstChild("PerformanceStats")
        if perf then
            local pingStat = perf:FindFirstChild("Ping")
            if pingStat then
                ping = math.floor(pingStat:GetValue())
                return
            end
        end
    end)
    return ping
end

-- Master GUI container for TASFF Overlays
local OverlayGui = Instance.new("ScreenGui")
OverlayGui.Name = "TASFF_OverlayGui"
OverlayGui.ResetOnSpawn = false
OverlayGui.IgnoreGuiInset = true
OverlayGui.DisplayOrder = 999999999
OverlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function EnsureOverlayParented()
    if OverlayGui.Parent and OverlayGui.Parent.Parent then return true end

    -- 1. Try gethui()
    pcall(function()
        if typeof(gethui) == "function" then
            local h = gethui()
            if h then OverlayGui.Parent = h end
        end
    end)
    if OverlayGui.Parent then return true end

    -- 2. Try syn.protect_gui + CoreGui
    pcall(function()
        if syn and typeof(syn.protect_gui) == "function" then
            syn.protect_gui(OverlayGui)
            OverlayGui.Parent = CoreGui
        end
    end)
    if OverlayGui.Parent then return true end

    -- 3. Try CoreGui directly
    pcall(function()
        OverlayGui.Parent = CoreGui
    end)
    if OverlayGui.Parent then return true end

    -- 4. Try CoreGui.RobloxGui
    pcall(function()
        local rg = CoreGui:FindFirstChild("RobloxGui")
        if rg then OverlayGui.Parent = rg end
    end)
    if OverlayGui.Parent then return true end

    -- 5. Fallback to LocalPlayer.PlayerGui
    pcall(function()
        local lp = Players.LocalPlayer or game:GetService("Players").LocalPlayer
        local pg = lp and lp:FindFirstChildOfClass("PlayerGui")
        if pg then OverlayGui.Parent = pg end
    end)
    return (OverlayGui.Parent ~= nil)
end

EnsureOverlayParented()
if OverlayGui.Parent then
    print("[TASFF Theme] Overlay ScreenGui mounted to " .. tostring(OverlayGui.Parent.Name))
else
    warn("[TASFF Theme] Warning: Could not parent Overlay ScreenGui.")
end

-- ── 1. Persistent HUD Strip ──────────────────────────────────────
local HUDStrip = Instance.new("Frame")
HUDStrip.Name = "HUDStrip"
HUDStrip.Size = UDim2.new(0, 640, 0, 26)
HUDStrip.Position = UDim2.new(0.5, -320, 0, 4)
HUDStrip.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
HUDStrip.BackgroundTransparency = 0.25
HUDStrip.BorderSizePixel = 0
HUDStrip.Visible = (S.HUDStripEnabled ~= false)
HUDStrip.Parent = OverlayGui
MakeDraggable(HUDStrip, HUDStrip, "HUDStripPosX", "HUDStripPosY")

local HUDCorner = Instance.new("UICorner", HUDStrip)
HUDCorner.CornerRadius = UDim.new(0, 6)
local HUDStroke = Instance.new("UIStroke", HUDStrip)
HUDStroke.Color = Color3.fromRGB(45, 45, 55)
HUDStroke.Thickness = 1

local HUDLabel = Instance.new("TextLabel", HUDStrip)
HUDLabel.Size = UDim2.new(1, -72, 1, 0)
HUDLabel.Position = UDim2.new(0, 6, 0, 0)
HUDLabel.BackgroundTransparency = 1
HUDLabel.Font = Enum.Font.GothamMedium
HUDLabel.TextSize = 11
HUDLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
HUDLabel.TextXAlignment = Enum.TextXAlignment.Center
HUDLabel.Text = "[TASFF v2.3.0] Initializing..."

-- Real-time Sparkline Graph canvas inside HUD strip
local SparkCanvas = Instance.new("Frame", HUDStrip)
SparkCanvas.Name = "HUDSparkCanvas"
SparkCanvas.Size = UDim2.new(0, 56, 0, 18)
SparkCanvas.Position = UDim2.new(1, -62, 0.5, -9)
SparkCanvas.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
SparkCanvas.BackgroundTransparency = 0.4
SparkCanvas.BorderSizePixel = 0
Instance.new("UICorner", SparkCanvas).CornerRadius = UDim.new(0, 3)

local sparkBars = {}
for i = 1, 10 do
    local b = Instance.new("Frame", SparkCanvas)
    b.Size = UDim2.new(0, 4, 0, 8)
    b.Position = UDim2.new(0, 2 + (i - 1) * 5, 1, -10)
    b.BackgroundColor3 = Color3.fromRGB(0, 230, 120)
    b.BorderSizePixel = 0
    sparkBars[i] = b
end

-- Update HUD Strip & Sparkline on RenderStepped
local _lastFpsTime, _fpsFrames, _currFps = tick(), 0, 60
local _lastSparkUpdate = tick()
table.insert(Connections, RunService.RenderStepped:Connect(function()
    _fpsFrames = _fpsFrames + 1
    local now = tick()
    if now - _lastFpsTime >= 0.5 then
        _currFps = math.floor(_fpsFrames / (now - _lastFpsTime))
        _fpsFrames = 0
        _lastFpsTime = now
    end

    if now - _lastSparkUpdate >= 0.25 then
        _lastSparkUpdate = now
        for i = 1, 9 do
            sparkBars[i].Size = sparkBars[i + 1].Size
            sparkBars[i].Position = UDim2.new(0, 2 + (i - 1) * 5, 1, -sparkBars[i + 1].Size.Y.Offset - 1)
            sparkBars[i].BackgroundColor3 = sparkBars[i + 1].BackgroundColor3
        end
        local newH = math.clamp(math.floor((_currFps / 60) * 14), 2, 16)
        local barColor = (_currFps >= 50 and Color3.fromRGB(0, 230, 120))
            or (_currFps >= 30 and Color3.fromRGB(240, 200, 50))
            or Color3.fromRGB(255, 60, 60)
        sparkBars[10].Size = UDim2.new(0, 4, 0, newH)
        sparkBars[10].Position = UDim2.new(0, 2 + 9 * 5, 1, -newH - 1)
        sparkBars[10].BackgroundColor3 = barColor
    end

    if HUDStrip.Visible ~= (S.HUDStripEnabled ~= false) then
        HUDStrip.Visible = (S.HUDStripEnabled ~= false)
    end
    if not HUDStrip.Visible then return end

    local isAimActive = (S.MasterEnabled ~= false and S.TargetingEnabled == true)
    local aimbotStr = isAimActive and "<font color='#4DFF88'>AIM: ON</font>" or "<font color='#FF5555'>AIM: OFF</font>"
    local silentStr = S.SilentAimEnabled and " | <font color='#00F5FF'>SILENT</font>" or ""
    local humanStr = S.HumanizedAimEnabled and " | <font color='#FFD45C'>HUMAN</font>" or ""
    local threats = (S.ThreatPlayers and #S.ThreatPlayers or 0)
    local threatStr = threats > 0 and (" | <font color='#FF4444'>THREATS: " .. threats .. "</font>") or ""
    local tgtName = S.CurrentTarget and S.CurrentTarget.Name or "None"
    local presetStr = S.ActivePresetName or "Default"
    local pingMs = GetCurrentPing()

    HUDLabel.RichText = true
    HUDLabel.Text = string.format("[TASFF] %s%s%s | TGT: %s%s | P: %s | %d FPS | %dms",
        aimbotStr, silentStr, humanStr, tgtName, threatStr, presetStr, _currFps, pingMs)
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
MakeDraggable(RadarFrame, RadarFrame, "RadarPosX", "RadarPosY")

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

-- ── 2b. Floating Target Inspection Hologram Card ──────────────────
local TargetCardFrame = Instance.new("Frame")
TargetCardFrame.Name = "TargetCardFrame"
TargetCardFrame.Size = UDim2.new(0, 220, 0, 74)
TargetCardFrame.Position = UDim2.new(0.5, -110, 0, 36)
TargetCardFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
TargetCardFrame.BackgroundTransparency = 0.25
TargetCardFrame.BorderSizePixel = 0
TargetCardFrame.Visible = false
TargetCardFrame.Parent = OverlayGui
Instance.new("UICorner", TargetCardFrame).CornerRadius = UDim.new(0, 8)
local tcStroke = Instance.new("UIStroke", TargetCardFrame)
tcStroke.Color = GetThemeAccentColor()
tcStroke.Thickness = 1.2
MakeDraggable(TargetCardFrame, TargetCardFrame, "TargetCardPosX", "TargetCardPosY")

local tcAvatar = Instance.new("ImageLabel", TargetCardFrame)
tcAvatar.Size = UDim2.new(0, 48, 0, 48)
tcAvatar.Position = UDim2.new(0, 10, 0, 10)
tcAvatar.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
tcAvatar.BorderSizePixel = 0
tcAvatar.Image = ""
Instance.new("UICorner", tcAvatar).CornerRadius = UDim.new(0, 6)

local tcName = Instance.new("TextLabel", TargetCardFrame)
tcName.Size = UDim2.new(1, -70, 0, 16)
tcName.Position = UDim2.new(0, 64, 0, 8)
tcName.BackgroundTransparency = 1
tcName.Font = Enum.Font.GothamBold
tcName.TextSize = 12
tcName.TextColor3 = Color3.fromRGB(245, 245, 250)
tcName.TextXAlignment = Enum.TextXAlignment.Left
tcName.TextTruncate = Enum.TextTruncate.AtEnd
tcName.Text = "Target"

local tcSub = Instance.new("TextLabel", TargetCardFrame)
tcSub.Size = UDim2.new(1, -70, 0, 14)
tcSub.Position = UDim2.new(0, 64, 0, 26)
tcSub.BackgroundTransparency = 1
tcSub.Font = Enum.Font.Gotham
tcSub.TextSize = 10
tcSub.TextColor3 = Color3.fromRGB(180, 180, 195)
tcSub.TextXAlignment = Enum.TextXAlignment.Left
tcSub.TextTruncate = Enum.TextTruncate.AtEnd
tcSub.Text = "0 studs | Unarmed"

local tcHpBg = Instance.new("Frame", TargetCardFrame)
tcHpBg.Size = UDim2.new(1, -74, 0, 6)
tcHpBg.Position = UDim2.new(0, 64, 0, 46)
tcHpBg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
tcHpBg.BorderSizePixel = 0
Instance.new("UICorner", tcHpBg).CornerRadius = UDim.new(1, 0)

local tcHpFill = Instance.new("Frame", tcHpBg)
tcHpFill.Size = UDim2.new(1, 0, 1, 0)
tcHpFill.BackgroundColor3 = Color3.fromRGB(45, 220, 110)
tcHpFill.BorderSizePixel = 0
Instance.new("UICorner", tcHpFill).CornerRadius = UDim.new(1, 0)

local tcTag = Instance.new("TextLabel", TargetCardFrame)
tcTag.Size = UDim2.new(1, -74, 0, 12)
tcTag.Position = UDim2.new(0, 64, 0, 56)
tcTag.BackgroundTransparency = 1
tcTag.Font = Enum.Font.GothamBold
tcTag.TextSize = 9
tcTag.TextColor3 = Color3.fromRGB(0, 230, 255)
tcTag.TextXAlignment = Enum.TextXAlignment.Left
tcTag.Text = "[TARGET ACQUIRED]"

-- Live Target Card update loop
table.insert(Connections, RunService.RenderStepped:Connect(function()
    if not (S.TargetCardEnabled ~= false) then
        TargetCardFrame.Visible = false
        return
    end
    local tgt = S.CurrentTarget
    if not tgt then
        TargetCardFrame.Visible = false
        return
    end

    local tgtChar = nil
    if typeof(tgt) == "Instance" then
        if tgt:IsA("Player") then
            tgtChar = tgt.Character
        elseif tgt:IsA("Model") then
            tgtChar = tgt
        elseif tgt.Parent and tgt.Parent:IsA("Model") then
            tgtChar = tgt.Parent
        end
    elseif type(tgt) == "table" then
        local c = tgt.Character or tgt.Model or tgt.Instance or tgt.Player
        if typeof(c) == "Instance" then
            if c:IsA("Player") then
                tgtChar = c.Character
            elseif c:IsA("Model") then
                tgtChar = c
            end
        end
    end

    if not (tgtChar and typeof(tgtChar) == "Instance") then
        TargetCardFrame.Visible = false
        return
    end

    local tgtHum = tgtChar:FindFirstChildOfClass("Humanoid")
    local tgtRoot = tgtChar:FindFirstChild("HumanoidRootPart") or tgtChar:FindFirstChild("Head") or tgtChar.PrimaryPart
    local myChar = LocalPlayer.Character
    local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Head"))

    if not (tgtRoot and myRoot and tgtHum and tgtHum.Health > 0) then
        TargetCardFrame.Visible = false
        return
    end

    TargetCardFrame.Visible = true
    tcStroke.Color = GetThemeAccentColor()
    tcName.Text = (tgt.DisplayName and tgt.DisplayName ~= "") and (tgt.DisplayName .. " (@" .. tgt.Name .. ")") or tgt.Name

    local dist = math.floor((tgtRoot.Position - myRoot.Position).Magnitude)
    local tool = tgtChar:FindFirstChildOfClass("Tool")
    local toolName = tool and tool.Name or "Unarmed"
    tcSub.Text = string.format("%d studs  |  %s", dist, toolName)

    local hpPct = math.clamp(tgtHum.Health / math.max(1, tgtHum.MaxHealth), 0, 1)
    tcHpFill.Size = UDim2.new(hpPct, 0, 1, 0)
    tcHpFill.BackgroundColor3 = (hpPct > 0.6 and Color3.fromRGB(45, 220, 110))
        or (hpPct > 0.3 and Color3.fromRGB(240, 190, 50))
        or Color3.fromRGB(255, 60, 60)

    if S.NemesisMemory and S.NemesisMemory[tgt.Name] then
        tcTag.TextColor3 = Color3.fromRGB(180, 100, 255)
        tcTag.Text = "[NEMESIS TARGET]"
    elseif S.ThreatPlayers and table.find(S.ThreatPlayers, tgt.Name) then
        tcTag.TextColor3 = Color3.fromRGB(255, 120, 50)
        tcTag.Text = "[HIGH THREAT]"
    elseif S.PriorityPlayers and table.find(S.PriorityPlayers, tgt.Name) then
        tcTag.TextColor3 = Color3.fromRGB(255, 215, 0)
        tcTag.Text = "[PRIORITY TARGET]"
    else
        tcTag.TextColor3 = GetThemeAccentColor()
        tcTag.Text = "[TARGET ACQUIRED]"
    end

    local tgtPlayer = Players:GetPlayerFromCharacter(tgtChar) or tgt
    if tgtPlayer and tgtPlayer.UserId and tgtPlayer.UserId > 0 then
        tcAvatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(tgtPlayer.UserId) .. "&w=100&h=100"
    end
end))

-- ── 2c. Compact Floating HUD Pill (when main menu closed) ──────────
local CompactHUDFrame = Instance.new("Frame")
CompactHUDFrame.Name = "CompactHUDFrame"
CompactHUDFrame.Size = UDim2.new(0, 210, 0, 30)
CompactHUDFrame.Position = UDim2.new(0.5, -105, 0, 34)
CompactHUDFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
CompactHUDFrame.BackgroundTransparency = 0.25
CompactHUDFrame.BorderSizePixel = 0
CompactHUDFrame.Visible = false
CompactHUDFrame.Parent = OverlayGui
Instance.new("UICorner", CompactHUDFrame).CornerRadius = UDim.new(0, 6)
local chStroke = Instance.new("UIStroke", CompactHUDFrame)
chStroke.Color = GetThemeAccentColor()
chStroke.Thickness = 1
MakeDraggable(CompactHUDFrame, CompactHUDFrame, "CompactHUDPosX", "CompactHUDPosY")

local chMasterBtn = Instance.new("TextButton", CompactHUDFrame)
chMasterBtn.Size = UDim2.new(0, 20, 0, 20)
chMasterBtn.Position = UDim2.new(0, 6, 0.5, -10)
chMasterBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
chMasterBtn.Font = Enum.Font.GothamBold
chMasterBtn.TextSize = 12
chMasterBtn.Text = "[!]"
chMasterBtn.TextColor3 = Color3.fromRGB(0, 255, 120)
Instance.new("UICorner", chMasterBtn).CornerRadius = UDim.new(1, 0)
chMasterBtn.MouseButton1Click:Connect(function()
    if S.ToggleMasterSwitch then
        S.ToggleMasterSwitch()
    else
        S.MasterEnabled = not S.MasterEnabled
    end
    PlayUISound(S.MasterEnabled and "toggle_on" or "toggle_off")
end)

local chLabel = Instance.new("TextLabel", CompactHUDFrame)
chLabel.Size = UDim2.new(1, -62, 1, 0)
chLabel.Position = UDim2.new(0, 30, 0, 0)
chLabel.BackgroundTransparency = 1
chLabel.Font = Enum.Font.Gotham
chLabel.TextSize = 10
chLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
chLabel.TextXAlignment = Enum.TextXAlignment.Left
chLabel.Text = "AIM: ON | Tgt: None"

local chExpandBtn = Instance.new("TextButton", CompactHUDFrame)
chExpandBtn.Size = UDim2.new(0, 22, 0, 20)
chExpandBtn.Position = UDim2.new(1, -26, 0.5, -10)
chExpandBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
chExpandBtn.Font = Enum.Font.GothamBold
chExpandBtn.TextSize = 11
chExpandBtn.TextColor3 = Color3.fromRGB(200, 200, 215)
chExpandBtn.Text = "[+]"
Instance.new("UICorner", chExpandBtn).CornerRadius = UDim.new(0, 4)
chExpandBtn.MouseButton1Click:Connect(function()
    local rGui = FindRayfieldGui()
    local mFrame = rGui and (rGui:FindFirstChild("Main", true) or rGui:FindFirstChildOfClass("Frame"))
    if mFrame then
        mFrame.Visible = true
        mFrame.BackgroundTransparency = 1 - (S.UIOpacity or 1.0)
    end
    PlayUISound("click")
end)

-- ── 2d. Keystrokes Visualizer Widget ──────────────────────────────
local KeystrokesFrame = Instance.new("Frame")
KeystrokesFrame.Name = "KeystrokesFrame"
KeystrokesFrame.Size = UDim2.new(0, 110, 0, 80)
KeystrokesFrame.Position = UDim2.new(0, 20, 1, -120)
KeystrokesFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
KeystrokesFrame.BackgroundTransparency = 0.4
KeystrokesFrame.BorderSizePixel = 0
KeystrokesFrame.Visible = (S.KeystrokesEnabled == true)
KeystrokesFrame.Parent = OverlayGui
Instance.new("UICorner", KeystrokesFrame).CornerRadius = UDim.new(0, 6)
local ksStroke = Instance.new("UIStroke", KeystrokesFrame)
ksStroke.Color = Color3.fromRGB(45, 45, 55)
MakeDraggable(KeystrokesFrame, KeystrokesFrame, "KeystrokesPosX", "KeystrokesPosY")

local keyBoxes = {}
local function createKey(name, text, size, pos)
    local kf = Instance.new("Frame", KeystrokesFrame)
    kf.Name = "Key_" .. name
    kf.Size = size
    kf.Position = pos
    kf.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    kf.BorderSizePixel = 0
    Instance.new("UICorner", kf).CornerRadius = UDim.new(0, 4)
    local kl = Instance.new("TextLabel", kf)
    kl.Size = UDim2.new(1, 0, 1, 0)
    kl.BackgroundTransparency = 1
    kl.Font = Enum.Font.GothamBold
    kl.TextSize = 10
    kl.TextColor3 = Color3.fromRGB(200, 200, 210)
    kl.Text = text
    keyBoxes[name] = {Frame = kf, Label = kl}
end
createKey("W", "W", UDim2.new(0, 30, 0, 22), UDim2.new(0.5, -15, 0, 6))
createKey("A", "A", UDim2.new(0, 30, 0, 22), UDim2.new(0, 6, 0, 30))
createKey("S", "S", UDim2.new(0, 30, 0, 22), UDim2.new(0.5, -15, 0, 30))
createKey("D", "D", UDim2.new(0, 30, 0, 22), UDim2.new(1, -36, 0, 30))
createKey("LMB", "LMB", UDim2.new(0, 46, 0, 18), UDim2.new(0, 6, 0, 56))
createKey("RMB", "RMB", UDim2.new(0, 46, 0, 18), UDim2.new(1, -52, 0, 56))

local keyMap = {
    [Enum.KeyCode.W] = "W",
    [Enum.KeyCode.A] = "A",
    [Enum.KeyCode.S] = "S",
    [Enum.KeyCode.D] = "D",
    [Enum.UserInputType.MouseButton1] = "LMB",
    [Enum.UserInputType.MouseButton2] = "RMB",
}
UserInputService.InputBegan:Connect(function(input)
    local targetKey = keyMap[input.KeyCode] or keyMap[input.UserInputType]
    if targetKey and keyBoxes[targetKey] then
        local accent = GetThemeAccentColor()
        keyBoxes[targetKey].Frame.BackgroundColor3 = accent
        keyBoxes[targetKey].Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    local targetKey = keyMap[input.KeyCode] or keyMap[input.UserInputType]
    if targetKey and keyBoxes[targetKey] then
        keyBoxes[targetKey].Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
        keyBoxes[targetKey].Label.TextColor3 = Color3.fromRGB(200, 200, 210)
    end
end)

-- ── 2e. Notification Center Drawer ───────────────────────────────
local NotificationDrawer = Instance.new("Frame")
NotificationDrawer.Name = "NotificationDrawer"
NotificationDrawer.Size = UDim2.new(0, 240, 0, 320)
NotificationDrawer.Position = UDim2.new(1, -260, 0, 45)  -- default; repositioned on open
NotificationDrawer.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
NotificationDrawer.BackgroundTransparency = 0.15
NotificationDrawer.BorderSizePixel = 0
NotificationDrawer.Visible = false
NotificationDrawer.ZIndex = 120
NotificationDrawer.Parent = OverlayGui
Instance.new("UICorner", NotificationDrawer).CornerRadius = UDim.new(0, 8)
local ndStroke = Instance.new("UIStroke", NotificationDrawer)
ndStroke.Color = GetThemeAccentColor()  -- theme-synced, not hardcoded cyan
ndStroke.Thickness = 1.2
MakeDraggable(NotificationDrawer, NotificationDrawer, nil, nil)

local ndHeader = Instance.new("Frame", NotificationDrawer)
ndHeader.Size = UDim2.new(1, 0, 0, 28)
ndHeader.BackgroundTransparency = 1
local ndTitle = Instance.new("TextLabel", ndHeader)
ndTitle.Size = UDim2.new(1, -60, 1, 0)
ndTitle.Position = UDim2.new(0, 10, 0, 0)
ndTitle.BackgroundTransparency = 1
ndTitle.Font = Enum.Font.GothamBold
ndTitle.TextSize = 11
ndTitle.TextColor3 = Color3.fromRGB(240, 240, 245)
ndTitle.TextXAlignment = Enum.TextXAlignment.Left
ndTitle.Text = "Notification History"

local ndClearBtn = Instance.new("TextButton", ndHeader)
ndClearBtn.Size = UDim2.new(0, 45, 0, 18)
ndClearBtn.Position = UDim2.new(1, -52, 0.5, -9)
ndClearBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
ndClearBtn.Font = Enum.Font.Gotham
ndClearBtn.TextSize = 10
ndClearBtn.TextColor3 = Color3.fromRGB(190, 190, 200)
ndClearBtn.Text = "Clear"
Instance.new("UICorner", ndClearBtn).CornerRadius = UDim.new(0, 4)

local ndScroller = Instance.new("ScrollingFrame", NotificationDrawer)
ndScroller.Size = UDim2.new(1, -12, 1, -36)
ndScroller.Position = UDim2.new(0, 6, 0, 30)
ndScroller.BackgroundTransparency = 1
ndScroller.BorderSizePixel = 0
ndScroller.ScrollBarThickness = 3
ndScroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
ndScroller.CanvasSize = UDim2.new(0, 0, 0, 0)
local ndList = Instance.new("UIListLayout", ndScroller)
ndList.Padding = UDim.new(0, 4)
ndList.SortOrder = Enum.SortOrder.LayoutOrder

local function RefreshNotificationDrawer()
    for _, child in ipairs(ndScroller:GetChildren()) do
        if child:IsA("GuiObject") and child.Name ~= "UIListLayout" then child:Destroy() end
    end
    local hist = S.NotificationHistory or {}
    if #hist == 0 then
        local emptyLabel = Instance.new("TextLabel", ndScroller)
        emptyLabel.Size = UDim2.new(1, 0, 0, 40)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.TextSize = 10
        emptyLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
        emptyLabel.Text = "No notifications yet."
        return
    end
    for i = #hist, 1, -1 do
        local item = hist[i]
        local card = Instance.new("Frame", ndScroller)
        card.Size = UDim2.new(1, -6, 0, 44)
        card.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 4)
        local cardStroke = Instance.new("UIStroke", card)
        cardStroke.Color = Color3.fromRGB(42, 42, 54)
        cardStroke.Thickness = 1

        local t1 = Instance.new("TextLabel", card)
        t1.Size = UDim2.new(1, -8, 0, 14)
        t1.Position = UDim2.new(0, 6, 0, 4)
        t1.BackgroundTransparency = 1
        t1.Font = Enum.Font.GothamBold
        t1.TextSize = 10
        t1.TextColor3 = item.Color or GetThemeAccentColor()
        t1.TextXAlignment = Enum.TextXAlignment.Left
        t1.Text = string.format("[%s] %s", item.Time or "Now", item.Title or "Notice")
        local t2 = Instance.new("TextLabel", card)
        t2.Size = UDim2.new(1, -8, 0, 22)
        t2.Position = UDim2.new(0, 6, 0, 18)
        t2.BackgroundTransparency = 1
        t2.Font = Enum.Font.Gotham
        t2.TextSize = 9
        t2.TextColor3 = Color3.fromRGB(210, 210, 220)
        t2.TextXAlignment = Enum.TextXAlignment.Left
        t2.TextWrapped = true
        t2.Text = item.Message or ""
    end
end
ndClearBtn.MouseButton1Click:Connect(function()
    S.NotificationHistory = {}
    RefreshNotificationDrawer()
    PlayUISound("click")
end)

local function LogNotification(title, msg, color)
    S.NotificationHistory = S.NotificationHistory or {}
    local timeStr = os.date("%H:%M:%S")
    table.insert(S.NotificationHistory, {Title = title, Message = msg, Color = color, Time = timeStr})
    if #S.NotificationHistory > 50 then table.remove(S.NotificationHistory, 1) end

    -- Trigger unread indicator on bell button
    pcall(function()
        local rGui = FindRayfieldGui and FindRayfieldGui()
        if rGui then
            local topbar = rGui:FindFirstChild("Topbar", true)
            local bellBtn = topbar and topbar:FindFirstChild("NotifBellBtn")
            local bellDot = bellBtn and bellBtn:FindFirstChild("BellDot")
            if bellDot and not NotificationDrawer.Visible then
                bellDot.Visible = true
            end
        end
    end)

    if NotificationDrawer.Visible then RefreshNotificationDrawer() end
end
TASFFEnv.Theme.LogNotification = LogNotification

local function UpdateDrawerPosition()
    pcall(function()
        -- Re-sync stroke color to current theme on every open
        ndStroke.Color = GetThemeAccentColor()

        local rGui = FindRayfieldGui and FindRayfieldGui()
        if rGui then
            local mFrame = rGui:FindFirstChild("Main", true) or rGui:FindFirstChildOfClass("Frame")
            if mFrame then
                local mPos  = mFrame.AbsolutePosition
                local mSize = mFrame.AbsoluteSize
                -- Position the drawer flush against the RIGHT side of the menu, vertically centered-ish
                local drawerX = mPos.X + mSize.X + 8   -- 8px gap to the right of the menu
                local drawerY = mPos.Y + 45             -- align with topbar bottom
                -- Clamp so it stays on screen
                drawerX = math.clamp(drawerX, 0, math.max(0, workspace.CurrentCamera.ViewportSize.X - 248))
                drawerY = math.clamp(drawerY, 4, math.max(4, workspace.CurrentCamera.ViewportSize.Y - 324))
                NotificationDrawer.Position = UDim2.new(0, drawerX, 0, drawerY)
                return
            end
        end
        NotificationDrawer.Position = UDim2.new(1, -260, 0, 45)
    end)
end

TASFFEnv.Theme.ToggleNotificationDrawer = function()
    NotificationDrawer.Visible = not NotificationDrawer.Visible
    if NotificationDrawer.Visible then
        UpdateDrawerPosition()
        RefreshNotificationDrawer()
        pcall(function()
            local rGui = FindRayfieldGui and FindRayfieldGui()
            if rGui then
                local topbar = rGui:FindFirstChild("Topbar", true)
                local bellBtn = topbar and topbar:FindFirstChild("NotifBellBtn")
                local bellDot = bellBtn and bellBtn:FindFirstChild("BellDot")
                if bellDot then bellDot.Visible = false end
            end
        end)
    end
    PlayUISound("click")
end

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
    local accent = color or GetThemeAccentColor()
    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(1, 0, 0, 36)
    pill.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    pill.BackgroundTransparency = 0.2
    pill.BorderSizePixel = 0
    pill.Parent = SidebarFrame

    Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", pill)
    stroke.Color = accent
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
TooltipStroke.Color = GetThemeAccentColor()
TooltipStroke.Thickness = 1

local TooltipTitle = Instance.new("TextLabel", TooltipFrame)
TooltipTitle.Size = UDim2.new(1, -12, 0, 16)
TooltipTitle.Position = UDim2.new(0, 6, 0, 4)
TooltipTitle.BackgroundTransparency = 1
TooltipTitle.Font = Enum.Font.GothamBold
TooltipTitle.TextSize = 11
TooltipTitle.TextColor3 = GetThemeAccentColor()
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
    if not (OverlayGui and OverlayGui.Parent) then EnsureOverlayParented() end
    local accent = GetThemeAccentColor()
    TooltipStroke.Color = accent
    TooltipTitle.TextColor3 = accent
    TooltipTitle.Text = ctrlName
    TooltipBody.Text = desc
    local cam = workspace.CurrentCamera
    local vp = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
    local posX = math.clamp(mousePos.X + 15, 10, math.max(10, vp.X - 250))
    local posY = math.clamp(mousePos.Y + 10, 10, math.max(10, vp.Y - 65))
    TooltipFrame.Position = UDim2.new(0, posX, 0, posY)
    TooltipFrame.Visible = true
end
local function HideTooltip()
    TooltipFrame.Visible = false
end

-- ── 5. Rayfield DOM Tree Patch Engine ────────────────────────────
FindRayfieldGui = function()
    local containers = {}
    pcall(function()
        if typeof(gethui) == "function" then
            local h = gethui()
            if h then table.insert(containers, h) end
        end
    end)
    pcall(function()
        local cg = game:GetService("CoreGui")
        if cg then
            table.insert(containers, cg)
            local rg = cg:FindFirstChild("RobloxGui")
            if rg then table.insert(containers, rg) end
        end
    end)
    pcall(function()
        local lp = Players.LocalPlayer or game:GetService("Players").LocalPlayer
        local pg = lp and lp:FindFirstChildOfClass("PlayerGui")
        if pg then table.insert(containers, pg) end
    end)

    local function isRayfieldScreenGui(screenGui)
        if not screenGui or not screenGui:IsA("ScreenGui") then return false end
        if screenGui.Name == "TASFF_OverlayGui" or screenGui.Name == "TASFF_Overlay" then return false end

        local main = screenGui:FindFirstChild("Main", true)
        if not main or not main:IsA("GuiObject") then return false end

        local titleMatch = false
        for _, label in ipairs(main:GetDescendants()) do
            if (label:IsA("TextLabel") or label:IsA("TextButton")) and label.Text:find("TASFF", 1, true) then
                titleMatch = true
                break
            end
        end
        return titleMatch or main:FindFirstChild("Topbar", true) ~= nil or main:FindFirstChild("Elements", true) ~= nil
    end

    for _, container in ipairs(containers) do
        -- Prefer a named Rayfield/Sirius GUI when several ScreenGuis exist.
        for _, child in ipairs(container:GetChildren()) do
            if isRayfieldScreenGui(child) then
                local name = child.Name:lower()
                if name:find("rayfield") or name:find("sirius") then
                    return child
                end
            end
        end

        -- Rayfield versions and forks use different internal child layouts.
        for _, child in ipairs(container:GetChildren()) do
            if isRayfieldScreenGui(child) then return child end
        end

        -- Some executors place the ScreenGui below a non-ScreenGui wrapper.
        for _, descendant in ipairs(container:GetDescendants()) do
            if isRayfieldScreenGui(descendant) then
                return descendant
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

-- Universal Atmospheric Carbon Weave Texture & Control Hover Glow Helpers
-- Applies high-contrast diagonal carbon UIGradient directly onto the frame background.
local function AttachCarbonOverlay(targetFrame, _unused)
    if not targetFrame or targetFrame:FindFirstChild("CarbonOverlay") then return end
    local marker = Instance.new("BoolValue")
    marker.Name = "CarbonOverlay"
    marker.Parent = targetFrame

    local existing = targetFrame:FindFirstChildOfClass("UIGradient")
    if existing and existing.Name ~= "CyberGrad" then existing:Destroy() end

    local grad = Instance.new("UIGradient")
    grad.Name = "CarbonGradient"
    grad.Rotation = 45
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    Color3.fromRGB(16,  18,  26)),
        ColorSequenceKeypoint.new(0.25, Color3.fromRGB(65,  70,  95)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(16,  18,  26)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(65,  70,  95)),
        ColorSequenceKeypoint.new(1,    Color3.fromRGB(16,  18,  26)),
    })
    grad.Transparency = NumberSequence.new(0)
    grad.Parent = targetFrame
end

local function AttachHoverGlow(card)
    if not card or card:FindFirstChild("HoverGlowHooked") then return end
    local hHook = Instance.new("BoolValue", card)
    hHook.Name = "HoverGlowHooked"
    local stroke = card:FindFirstChildOfClass("UIStroke")
    if stroke then
        local origColor = stroke.Color
        card.MouseEnter:Connect(function()
            local acc = GetThemeAccentColor()
            TweenService:Create(stroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Color = Color3.fromRGB(
                    math.clamp(math.floor(origColor.R * 255 * 0.4 + acc.R * 255 * 0.6), 0, 255),
                    math.clamp(math.floor(origColor.G * 255 * 0.4 + acc.G * 255 * 0.6), 0, 255),
                    math.clamp(math.floor(origColor.B * 255 * 0.4 + acc.B * 255 * 0.6), 0, 255)
                )
            }):Play()
        end)
        card.MouseLeave:Connect(function()
            TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Color = origColor
            }):Play()
        end)
    end
end

-- Patch sections, tooltips, search bar, state dots, tab badges, and resize handle
local function PatchRayfieldDOM()
    if S.AdvancedThemePatchEnabled ~= true then
        local rGui = FindRayfieldGui()
        local mainFrame = rGui and rGui:FindFirstChild("Main", true)
        if not mainFrame or not mainFrame.Parent then return false end

        local parent = mainFrame.Parent
        mainFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 27)
        mainFrame.BackgroundTransparency = 0.03

        local oldGrid = mainFrame:FindFirstChild("SafeCarbonGrid")
        if oldGrid then
            oldGrid:Destroy()
        end

        local halo = parent:FindFirstChild("TASFF_AmbientHalo")
        if not halo then
            halo = Instance.new("Frame")
            halo.Name = "TASFF_AmbientHalo"
            halo.BackgroundColor3 = GetThemeAccentColor()
            halo.BackgroundTransparency = 0.88
            halo.BorderSizePixel = 0
            halo.ZIndex = math.max(0, mainFrame.ZIndex - 1)
            halo.Parent = parent
            local stroke = Instance.new("UIStroke")
            stroke.Name = "HaloStroke"
            stroke.Color = GetThemeAccentColor()
            stroke.Thickness = 8
            stroke.Transparency = 0.75
            stroke.Parent = halo
            Instance.new("UICorner", halo).CornerRadius = UDim.new(0, 10)
        end

        local bottomBar = parent:FindFirstChild("TASFF_BottomBar")
        if not bottomBar then
            bottomBar = Instance.new("Frame")
            bottomBar.Name = "TASFF_BottomBar"
            bottomBar.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
            bottomBar.BackgroundTransparency = 0.18
            bottomBar.BorderSizePixel = 0
            bottomBar.ZIndex = mainFrame.ZIndex + 10
            bottomBar.Parent = parent
            Instance.new("UICorner", bottomBar).CornerRadius = UDim.new(0, 6)
            local barStroke = Instance.new("UIStroke", bottomBar)
            barStroke.Color = GetThemeAccentColor()
            barStroke.Transparency = 0.45

            local label = Instance.new("TextLabel")
            label.Name = "SafeStatus"
            label.BackgroundTransparency = 1
            label.Size = UDim2.new(1, -220, 1, 0)
            label.Position = UDim2.fromOffset(32, 0)
            label.Font = Enum.Font.GothamBold
            label.TextSize = 10
            label.TextColor3 = Color3.fromRGB(220, 225, 235)
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Text = (LocalPlayer.DisplayName or LocalPlayer.Name) .. "  [TASFF]"
            label.Parent = bottomBar

            local avatar = Instance.new("ImageLabel")
            avatar.Name = "SafeAvatar"
            avatar.BackgroundTransparency = 1
            avatar.Size = UDim2.fromOffset(20, 20)
            avatar.Position = UDim2.fromOffset(7, 3)
            avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=48&h=48"
            avatar.ZIndex = bottomBar.ZIndex + 1
            avatar.Parent = bottomBar
            Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)

            local stats = Instance.new("TextLabel")
            stats.Name = "SafeStats"
            stats.BackgroundTransparency = 1
            stats.Size = UDim2.new(0, 170, 1, 0)
            stats.Position = UDim2.new(1, -178, 0, 0)
            stats.Font = Enum.Font.GothamBold
            stats.TextSize = 9
            stats.TextColor3 = Color3.fromRGB(180, 215, 220)
            stats.TextXAlignment = Enum.TextXAlignment.Right
            stats.Text = "TASFF  |  READY"
            stats.Parent = bottomBar
        end
        bottomBar.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
        bottomBar.BackgroundTransparency = 0.18
        bottomBar.ZIndex = math.max(bottomBar.ZIndex, mainFrame.ZIndex + 10)
        local bottomStroke = bottomBar:FindFirstChildOfClass("UIStroke")
        if bottomStroke then
            bottomStroke.Color = GetThemeAccentColor()
            bottomStroke.Transparency = 0
            bottomStroke.Thickness = 1
        end
        local statusLabel = bottomBar:FindFirstChild("SafeStatus")
        if statusLabel then
            statusLabel.TextColor3 = Color3.fromRGB(235, 240, 250)
            statusLabel.Text = (LocalPlayer.DisplayName or LocalPlayer.Name) .. "  [TASFF]"
        end
        local avatar = bottomBar:FindFirstChild("SafeAvatar")
        if avatar then
            avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=48&h=48"
        else
            avatar = Instance.new("ImageLabel")
            avatar.Name = "SafeAvatar"
            avatar.BackgroundTransparency = 1
            avatar.Size = UDim2.fromOffset(20, 20)
            avatar.Position = UDim2.fromOffset(7, 3)
            avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=48&h=48"
            avatar.ZIndex = bottomBar.ZIndex + 1
            avatar.Parent = bottomBar
            Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
        end
        if not bottomBar:FindFirstChild("SafeStats") then
            local stats = Instance.new("TextLabel")
            stats.Name = "SafeStats"
            stats.BackgroundTransparency = 1
            stats.Size = UDim2.new(0, 170, 1, 0)
            stats.Position = UDim2.new(1, -178, 0, 0)
            stats.Font = Enum.Font.GothamBold
            stats.TextSize = 9
            stats.TextColor3 = Color3.fromRGB(180, 215, 220)
            stats.TextXAlignment = Enum.TextXAlignment.Right
            stats.Text = "TASFF  |  READY"
            stats.Parent = bottomBar
        end

        local topbar = mainFrame:FindFirstChild("Topbar", true)
        if topbar then
            local accentLine = topbar:FindFirstChild("SafeAccentLine")
            if not accentLine then
                accentLine = Instance.new("Frame")
                accentLine.Name = "SafeAccentLine"
                accentLine.Size = UDim2.new(1, 0, 0, 1)
                accentLine.Position = UDim2.new(0, 0, 1, -1)
                accentLine.BorderSizePixel = 0
                accentLine.ZIndex = topbar.ZIndex + 1
                accentLine.Parent = topbar
            end
            accentLine.BackgroundColor3 = GetThemeAccentColor()

            local safeBell = topbar:FindFirstChild("SafeNotificationBell")
            if not safeBell then
                safeBell = Instance.new("TextButton")
                safeBell.Name = "SafeNotificationBell"
                safeBell.Size = UDim2.fromOffset(22, 22)
                safeBell.AnchorPoint = Vector2.new(1, 0.5)
                safeBell.Position = UDim2.new(1, -44, 0.5, 0)
                safeBell.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
                safeBell.BackgroundTransparency = 0.2
                safeBell.BorderSizePixel = 0
                safeBell.Font = Enum.Font.GothamBold
                safeBell.TextSize = 10
                safeBell.TextColor3 = Color3.fromRGB(220, 230, 240)
                safeBell.Text = "!"
                safeBell.ZIndex = topbar.ZIndex + 2
                safeBell.Parent = topbar
                Instance.new("UICorner", safeBell).CornerRadius = UDim.new(0, 5)
                local safeBellStroke = Instance.new("UIStroke", safeBell)
                safeBellStroke.Color = GetThemeAccentColor()
                safeBellStroke.Thickness = 1
                safeBell.MouseButton1Click:Connect(function()
                    if TASFFEnv.Theme.ToggleNotificationDrawer then
                        TASFFEnv.Theme.ToggleNotificationDrawer()
                    end
                end)
            end
            safeBell.Position = UDim2.new(1, -44, 0.5, 0)
            local safeBellStroke = safeBell:FindFirstChildOfClass("UIStroke")
            if safeBellStroke then safeBellStroke.Color = GetThemeAccentColor() end
        end

        -- Add decoration only to direct children of Rayfield's content list.
        -- No native visibility, size, parent, or layout properties are changed.
        local elements = mainFrame:FindFirstChild("Elements", true)
        if elements then
            for _, desc in ipairs(elements:GetChildren()) do
                if desc:IsA("Frame") and desc.Name ~= "Template" and
                    (desc:FindFirstChild("Title") or desc:FindFirstChild("Content") or
                     desc:FindFirstChild("Interact") or desc:FindFirstChild("Switch")) and
                    not desc:FindFirstChild("SafeCardDecoration") then
                local marker = Instance.new("BoolValue")
                marker.Name = "SafeCardDecoration"
                marker.Parent = desc
                local stroke = Instance.new("UIStroke")
                stroke.Name = "SafeCardStroke"
                stroke.Color = GetThemeAccentColor()
                stroke.Thickness = 1
                stroke.Transparency = 0.45
                stroke.Parent = desc
                local gradient = Instance.new("UIGradient")
                gradient.Name = "SafeCardGradient"
                gradient.Rotation = 35
                gradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 34, 46)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 18, 26)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 34, 46)),
                })
                gradient.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.35),
                    NumberSequenceKeypoint.new(0.5, 0.7),
                    NumberSequenceKeypoint.new(1, 0.35),
                })
                gradient.Parent = desc
                end

            end
        end

        local tracker = mainFrame:FindFirstChild("SafeVisualTracker")
        if not tracker then
            tracker = Instance.new("BoolValue")
            tracker.Name = "SafeVisualTracker"
            tracker.Parent = mainFrame
            table.insert(Connections, RunService.RenderStepped:Connect(function()
                if not mainFrame.Parent or not halo.Parent then return end
                local parentPosition = parent.AbsolutePosition
                local absolutePosition = mainFrame.AbsolutePosition
                local visible = mainFrame.Visible and rGui.Enabled ~= false
                OverlayGui.Enabled = visible
                HUDStrip.Visible = S.HUDStripEnabled ~= false
                halo.Visible = visible
                halo.Position = UDim2.fromOffset(
                    absolutePosition.X - parentPosition.X - 8,
                    absolutePosition.Y - parentPosition.Y - 8
                )
                halo.Size = UDim2.fromOffset(mainFrame.AbsoluteSize.X + 16, mainFrame.AbsoluteSize.Y + 16)
                bottomBar.Visible = visible
                bottomBar.BackgroundTransparency = 0.18
                bottomBar.Position = UDim2.fromOffset(
                    absolutePosition.X - parentPosition.X,
                    absolutePosition.Y - parentPosition.Y + mainFrame.AbsoluteSize.Y + 4
                )
                bottomBar.Size = UDim2.fromOffset(mainFrame.AbsoluteSize.X, 26)

            end))
        end
        return true
    end

    local rGui = FindRayfieldGui()
    if not rGui then return false end

    local mainFrame = rGui:FindFirstChild("Main", true) or rGui:FindFirstChildOfClass("Frame")
    if not mainFrame then return false end

    if S.UIOpacity and S.UIOpacity < 1.0 then
        mainFrame.BackgroundTransparency = 1 - S.UIOpacity
    end
    mainFrame.ClipsDescendants = false

    -- 0a. Atmospheric Scanline Grid on Window Background (directly on mainFrame — CAN NEVER COVER CARDS)
    local existingMesh = mainFrame:FindFirstChild("MainCarbonMesh")
    if existingMesh then existingMesh:Destroy() end

    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 16, 23)

    local scanGrad = mainFrame:FindFirstChild("MainScanlinesGrad")
    if not scanGrad then
        scanGrad = Instance.new("UIGradient", mainFrame)
        scanGrad.Name = "MainScanlinesGrad"
    end
    scanGrad.Rotation = 90
    scanGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,      Color3.fromRGB(12,  13,  19)),
        ColorSequenceKeypoint.new(0.05,   Color3.fromRGB(65,  72,  100)),
        ColorSequenceKeypoint.new(0.10,   Color3.fromRGB(12,  13,  19)),
        ColorSequenceKeypoint.new(0.15,   Color3.fromRGB(65,  72,  100)),
        ColorSequenceKeypoint.new(0.20,   Color3.fromRGB(12,  13,  19)),
        ColorSequenceKeypoint.new(0.25,   Color3.fromRGB(65,  72,  100)),
        ColorSequenceKeypoint.new(0.30,   Color3.fromRGB(12,  13,  19)),
        ColorSequenceKeypoint.new(0.35,   Color3.fromRGB(65,  72,  100)),
        ColorSequenceKeypoint.new(0.40,   Color3.fromRGB(12,  13,  19)),
        ColorSequenceKeypoint.new(0.45,   Color3.fromRGB(65,  72,  100)),
        ColorSequenceKeypoint.new(0.50,   Color3.fromRGB(12,  13,  19)),
        ColorSequenceKeypoint.new(0.55,   Color3.fromRGB(65,  72,  100)),
        ColorSequenceKeypoint.new(0.60,   Color3.fromRGB(12,  13,  19)),
        ColorSequenceKeypoint.new(0.65,   Color3.fromRGB(65,  72,  100)),
        ColorSequenceKeypoint.new(0.70,   Color3.fromRGB(12,  13,  19)),
        ColorSequenceKeypoint.new(0.75,   Color3.fromRGB(65,  72,  100)),
        ColorSequenceKeypoint.new(0.80,   Color3.fromRGB(12,  13,  19)),
        ColorSequenceKeypoint.new(0.85,   Color3.fromRGB(65,  72,  100)),
        ColorSequenceKeypoint.new(0.90,   Color3.fromRGB(12,  13,  19)),
        ColorSequenceKeypoint.new(1,      Color3.fromRGB(65,  72,  100)),
    })
    scanGrad.Transparency = NumberSequence.new(0)

    -- 0b. Animated Cyber Neon Border with Rotating Gradient
    local cyberStroke = mainFrame:FindFirstChild("CyberStroke")
    if not cyberStroke then
        cyberStroke = Instance.new("UIStroke")
        cyberStroke.Name = "CyberStroke"
        cyberStroke.Thickness = 1.5
        cyberStroke.Color = GetThemeAccentColor()
        cyberStroke.Parent = mainFrame

        local cyberGrad = Instance.new("UIGradient")
        cyberGrad.Name = "CyberGrad"
        cyberGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, GetThemeAccentColor()),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, GetThemeAccentColor())
        })
        cyberGrad.Rotation = 45
        cyberGrad.Parent = cyberStroke

        task.spawn(function()
            local rot = 45
            while cyberGrad and cyberGrad.Parent do
                rot = (rot + 2) % 360
                cyberGrad.Rotation = rot
                task.wait(0.04)
            end
        end)
    else
        cyberStroke.Color = GetThemeAccentColor()
    end

    -- 0c. Centered Ambient Halo Styling (Strictly in mainFrame.Parent with ZIndex 0 — 100% behind menu)
    local legacyShadow = mainFrame:FindFirstChild("GlassShadow")
    if legacyShadow then legacyShadow:Destroy() end
    local legacyAuraOverlay = OverlayGui:FindFirstChild("TASFF_AmbientAura")
    if legacyAuraOverlay then legacyAuraOverlay:Destroy() end
    if OverlayGui then
        local oldH = OverlayGui:FindFirstChild("TASFF_AmbientHalo")
        if oldH then oldH:Destroy() end
    end
    if mainFrame.Parent then
        local legacyAuraParent = mainFrame.Parent:FindFirstChild("TASFF_AmbientAura")
        if legacyAuraParent then legacyAuraParent:Destroy() end
    end

    -- Create genuine soft halo in mainFrame.Parent (the Rayfield ScreenGui) with ZIndex = 0
    local ambientHalo = mainFrame.Parent and mainFrame.Parent:FindFirstChild("TASFF_AmbientHalo")
    if not ambientHalo and mainFrame.Parent then
        ambientHalo = Instance.new("ImageLabel")
        ambientHalo.Name = "TASFF_AmbientHalo"
        ambientHalo.BackgroundTransparency = 1
        ambientHalo.Image = "rbxassetid://5028857084" -- Soft radial blur 9-slice glow
        ambientHalo.ScaleType = Enum.ScaleType.Slice
        ambientHalo.SliceCenter = Rect.new(24, 24, 276, 276)
        ambientHalo.ImageColor3 = GetThemeAccentColor()
        ambientHalo.ImageTransparency = 0.08
        ambientHalo.ZIndex = 0
        ambientHalo.Parent = mainFrame.Parent
    end

    if ambientHalo then
        ambientHalo.ImageColor3 = GetThemeAccentColor()
        ambientHalo.ImageTransparency = 0.08
        ambientHalo.AnchorPoint = mainFrame.AnchorPoint
        ambientHalo.Position = mainFrame.Position
        ambientHalo.Size = UDim2.new(mainFrame.Size.X.Scale, mainFrame.Size.X.Offset + 50, mainFrame.Size.Y.Scale, mainFrame.Size.Y.Offset + 50)
    end

    -- 0d. Topbar Clean Accent Line & Notification Center Bell (Shifted clear of Search)
    local topbar = mainFrame:FindFirstChild("Topbar", true)
    if topbar then
        -- Reset topbar to Rayfield default height once per patch — no lock (lock breaks Rayfield toggle animation)
        topbar.Size = UDim2.new(1, 0, 0, 45)
        local topbarLine = topbar:FindFirstChild("TopbarAccentLine")
        if not topbarLine then
            topbarLine = Instance.new("Frame", topbar)
            topbarLine.Name = "TopbarAccentLine"
            topbarLine.Size = UDim2.new(1, 0, 0, 1.5)
            topbarLine.Position = UDim2.new(0, 0, 1, -1.5)
            topbarLine.BorderSizePixel = 0
            topbarLine.BackgroundColor3 = GetThemeAccentColor()
            topbarLine.ZIndex = 35

            local lineGrad = Instance.new("UIGradient", topbarLine)
            lineGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 25)),
                ColorSequenceKeypoint.new(0.5, GetThemeAccentColor()),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 25))
            })
        else
            topbarLine.BackgroundColor3 = GetThemeAccentColor()
        end

        -- Clean up topbar: strictly remove StatusPill and UserProfileBanner so Title has 100% unobstructed room
        local oldPill = topbar:FindFirstChild("StatusPill")
        if oldPill then oldPill:Destroy() end
        local oldBanner = topbar:FindFirstChild("UserProfileBanner")
        if oldBanner then oldBanner:Destroy() end

        -- Sync notification drawer stroke to current theme accent
        if ndStroke then ndStroke.Color = GetThemeAccentColor() end

        local bellBtn = topbar:FindFirstChild("NotifBellBtn")
        if not bellBtn then
            bellBtn = Instance.new("TextButton", topbar)
            bellBtn.Name = "NotifBellBtn"
            bellBtn.Size = UDim2.new(0, 22, 0, 22)
            bellBtn.Position = UDim2.new(1, -170, 0.5, -11)
            bellBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
            bellBtn.BackgroundTransparency = 0.3
            bellBtn.BorderSizePixel = 0
            bellBtn.Font = Enum.Font.GothamBold
            bellBtn.TextSize = 12
            bellBtn.TextColor3 = Color3.fromRGB(230, 230, 240)
            bellBtn.Text = ""
            bellBtn.ZIndex = 40
            Instance.new("UICorner", bellBtn).CornerRadius = UDim.new(0, 5)
            local bellStroke = Instance.new("UIStroke", bellBtn)
            bellStroke.Color = Color3.fromRGB(50, 50, 65)
            bellStroke.Thickness = 1

            local bellIcon = Instance.new("ImageLabel", bellBtn)
            bellIcon.Name = "BellIcon"
            bellIcon.Size = UDim2.new(0, 14, 0, 14)
            bellIcon.Position = UDim2.new(0.5, -7, 0.5, -7)
            bellIcon.BackgroundTransparency = 1
            bellIcon.Image = "rbxassetid://6031075938"
            bellIcon.ImageColor3 = Color3.fromRGB(220, 220, 230)
            bellIcon.ZIndex = 41

            local bellDot = Instance.new("Frame", bellBtn)
            bellDot.Name = "BellDot"
            bellDot.Size = UDim2.new(0, 6, 0, 6)
            bellDot.Position = UDim2.new(1, -3, 0, -3)
            bellDot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
            bellDot.BorderSizePixel = 0
            bellDot.Visible = false
            bellDot.ZIndex = 42
            Instance.new("UICorner", bellDot).CornerRadius = UDim.new(1, 0)

            bellBtn.MouseEnter:Connect(function()
                bellIcon.ImageColor3 = GetThemeAccentColor()
            end)
            bellBtn.MouseLeave:Connect(function()
                bellIcon.ImageColor3 = Color3.fromRGB(220, 220, 230)
            end)

            bellBtn.MouseButton1Click:Connect(function()
                bellDot.Visible = false
                if TASFFEnv.Theme.ToggleNotificationDrawer then
                    TASFFEnv.Theme.ToggleNotificationDrawer()
                end
            end)
        else
            bellBtn.Position = UDim2.new(1, -170, 0.5, -11)
        end
    end

    -- Operator Profile & Live System Monitor: Attached Bottom Bar (parented to mainFrame.Parent in Rayfield ScreenGui)
    for _, child in ipairs(mainFrame:GetDescendants()) do
        if child.Name == "BottomDock" or child.Name == "TASFF_BottomBar" then child:Destroy() end
    end
    if OverlayGui then
        local oldOverlayBB = OverlayGui:FindFirstChild("TASFF_BottomBar")
        if oldOverlayBB then oldOverlayBB:Destroy() end
    end

    local bottomBar = mainFrame.Parent and mainFrame.Parent:FindFirstChild("TASFF_BottomBar")
    if not bottomBar and mainFrame.Parent then
        bottomBar = Instance.new("Frame", mainFrame.Parent)
        bottomBar.Name = "TASFF_BottomBar"
        bottomBar.AnchorPoint = Vector2.new(0, 0)
        bottomBar.Position = UDim2.new(0, mainFrame.AbsolutePosition.X, 0, mainFrame.AbsolutePosition.Y + mainFrame.AbsoluteSize.Y + 4)
        bottomBar.Size = UDim2.new(0, mainFrame.AbsoluteSize.X, 0, 26)
        bottomBar.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
        bottomBar.BackgroundTransparency = 0.10
        bottomBar.BorderSizePixel = 0
        bottomBar.ZIndex = 100
        Instance.new("UICorner", bottomBar).CornerRadius = UDim.new(0, 6)
        local barStroke = Instance.new("UIStroke", bottomBar)
        barStroke.Color = GetThemeAccentColor()
        barStroke.Thickness = 1
        barStroke.Transparency = 0.5

        -- Carbon texture on bottom bar (procedural diagonal stripe — no rbxassetid)
        local barCarbon = Instance.new("Frame", bottomBar)
        barCarbon.Name = "BarCarbon"
        barCarbon.Size = UDim2.new(1, 0, 1, 0)
        barCarbon.BackgroundColor3 = Color3.fromRGB(28, 30, 42)
        barCarbon.BackgroundTransparency = 0.82
        barCarbon.BorderSizePixel = 0
        barCarbon.ZIndex = 101
        Instance.new("UICorner", barCarbon).CornerRadius = UDim.new(0, 6)
        local barCarbGrad = Instance.new("UIGradient", barCarbon)
        barCarbGrad.Rotation = 45
        barCarbGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,    Color3.fromRGB(150, 155, 175)),
            ColorSequenceKeypoint.new(0.25, Color3.fromRGB(200, 205, 225)),
            ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(150, 155, 175)),
            ColorSequenceKeypoint.new(0.75, Color3.fromRGB(200, 205, 225)),
            ColorSequenceKeypoint.new(1,    Color3.fromRGB(150, 155, 175)),
        })
        barCarbGrad.Transparency = NumberSequence.new(0)

        -- Accent separator line at top of bar (mirrors topbar bottom line)
        local barLine = Instance.new("Frame", bottomBar)
        barLine.Name = "BarAccentLine"
        barLine.Size = UDim2.new(1, 0, 0, 1.5)
        barLine.Position = UDim2.new(0, 0, 0, 0)
        barLine.BorderSizePixel = 0
        barLine.BackgroundColor3 = GetThemeAccentColor()
        barLine.ZIndex = 102
        local barLineGrad = Instance.new("UIGradient", barLine)
        barLineGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(10, 10, 15)),
            ColorSequenceKeypoint.new(0.5, GetThemeAccentColor()),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(10, 10, 15)),
        })

        -- Left: Avatar + Player Name + Executor
        local opAvatar = Instance.new("ImageLabel", bottomBar)
        opAvatar.Name = "OpAvatar"
        opAvatar.Size = UDim2.new(0, 20, 0, 20)
        opAvatar.Position = UDim2.new(0, 6, 0.5, -10)
        opAvatar.BackgroundTransparency = 1
        opAvatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=48&h=48"
        opAvatar.ZIndex = 103
        Instance.new("UICorner", opAvatar).CornerRadius = UDim.new(1, 0)

        local opName = Instance.new("TextLabel", bottomBar)
        opName.Name = "OpName"
        opName.Size = UDim2.new(0, 260, 1, 0)
        opName.Position = UDim2.new(0, 30, 0, 0)
        opName.BackgroundTransparency = 1
        opName.Font = Enum.Font.GothamBold
        opName.TextSize = 10
        opName.TextColor3 = Color3.fromRGB(225, 225, 235)
        opName.TextXAlignment = Enum.TextXAlignment.Left
        opName.TextTruncate = Enum.TextTruncate.AtEnd
        opName.ZIndex = 103
        local exec = (identifyexecutor and identifyexecutor()) or "Client"
        opName.Text = (LocalPlayer.DisplayName or LocalPlayer.Name) .. "  [" .. exec .. "]"

        -- Right: FPS / Ping monitor
        local statContainer = Instance.new("Frame", bottomBar)
        statContainer.Name = "StatContainer"
        statContainer.Size = UDim2.new(0, 170, 1, 0)
        statContainer.Position = UDim2.new(1, -195, 0, 0)
        statContainer.BackgroundTransparency = 1
        statContainer.ZIndex = 103

        local led = Instance.new("Frame", statContainer)
        led.Name = "LED"
        led.Size = UDim2.new(0, 7, 0, 7)
        led.Position = UDim2.new(0, 4, 0.5, -3)
        led.BackgroundColor3 = Color3.fromRGB(0, 240, 130)
        led.BorderSizePixel = 0
        led.ZIndex = 104
        Instance.new("UICorner", led).CornerRadius = UDim.new(1, 0)

        local sText = Instance.new("TextLabel", statContainer)
        sText.Name = "StatusText"
        sText.Size = UDim2.new(1, -16, 1, 0)
        sText.Position = UDim2.new(0, 16, 0, 0)
        sText.BackgroundTransparency = 1
        sText.Font = Enum.Font.GothamBold
        sText.TextSize = 10
        sText.TextColor3 = Color3.fromRGB(190, 215, 220)
        sText.TextXAlignment = Enum.TextXAlignment.Left
        sText.Text = "60 FPS  |  0ms"
        sText.ZIndex = 104

        -- Resize grip at bottom-right corner of the bottom bar
        local resizeHandle = Instance.new("Frame", bottomBar)
        resizeHandle.Name = "ResizeHandle"
        resizeHandle.Size = UDim2.new(0, 22, 0, 22)
        resizeHandle.Position = UDim2.new(1, -22, 0, 0)
        resizeHandle.BackgroundTransparency = 1
        resizeHandle.BorderSizePixel = 0
        resizeHandle.ZIndex = 110

        local grip1 = Instance.new("Frame", resizeHandle)
        grip1.Name = "Grip1"
        grip1.Size = UDim2.new(0, 12, 0, 2)
        grip1.Position = UDim2.new(0, 5, 0, 12)
        grip1.Rotation = -45
        grip1.BackgroundColor3 = Color3.fromRGB(160, 160, 175)
        grip1.BorderSizePixel = 0
        grip1.ZIndex = 111

        local grip2 = Instance.new("Frame", resizeHandle)
        grip2.Name = "Grip2"
        grip2.Size = UDim2.new(0, 7, 0, 2)
        grip2.Position = UDim2.new(0, 10, 0, 16)
        grip2.Rotation = -45
        grip2.BackgroundColor3 = Color3.fromRGB(160, 160, 175)
        grip2.BorderSizePixel = 0
        grip2.ZIndex = 111

        local hitArea = Instance.new("TextButton", resizeHandle)
        hitArea.Name = "HitArea"
        hitArea.Size = UDim2.new(1, 0, 1, 0)
        hitArea.BackgroundTransparency = 1
        hitArea.Text = ""
        hitArea.ZIndex = 112

        hitArea.MouseEnter:Connect(function()
            local accent = GetThemeAccentColor()
            grip1.BackgroundColor3 = accent
            grip2.BackgroundColor3 = accent
        end)
        hitArea.MouseLeave:Connect(function()
            grip1.BackgroundColor3 = Color3.fromRGB(160, 160, 175)
            grip2.BackgroundColor3 = Color3.fromRGB(160, 160, 175)
        end)

        local _resizing = false
        local _rStart, _rSizeStart
        hitArea.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                _resizing = true
                _rStart = input.Position
                _rSizeStart = mainFrame.AbsoluteSize
            end
        end)
        hitArea.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                _resizing = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if _resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - _rStart
                local newW = math.clamp(_rSizeStart.X + delta.X, 480, 1000)
                local newH = math.clamp(_rSizeStart.Y + delta.Y, 340, 850)
                mainFrame.Size = UDim2.new(0, newW, 0, newH)
            end
        end)

        -- Live stats loop
        task.spawn(function()
            while bottomBar and bottomBar.Parent do
                local fps = math.floor(1 / math.max(0.001, RunService.RenderStepped:Wait()))
                if sText and sText.Parent then
                    local ping = 0
                    pcall(function()
                        ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
                    end)
                    sText.Text = tostring(math.clamp(fps, 0, 999)) .. " FPS  |  " .. tostring(ping) .. "ms"
                    if fps >= 50 then
                        led.BackgroundColor3 = Color3.fromRGB(0, 240, 130)
                    elseif fps >= 30 then
                        led.BackgroundColor3 = Color3.fromRGB(255, 185, 50)
                    else
                        led.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
                    end
                end
                task.wait(0.5)
            end
        end)
    end

    if S.AdvancedThemeLayoutPatchEnabled ~= true then
        if not mainFrame:FindFirstChild("SafeBottomBarTracker") then
            local tracker = Instance.new("BoolValue")
            tracker.Name = "SafeBottomBarTracker"
            tracker.Parent = mainFrame
            table.insert(Connections, RunService.RenderStepped:Connect(function()
                if not bottomBar or not bottomBar.Parent or not mainFrame.Parent then return end
                local visible = mainFrame.Visible and (not rGui or rGui.Enabled ~= false)
                bottomBar.Visible = visible and mainFrame.AbsoluteSize.Y > 60
                if bottomBar.Visible then
                    local parentPosition = mainFrame.Parent.AbsolutePosition
                    local absolutePosition = mainFrame.AbsolutePosition
                    bottomBar.AnchorPoint = Vector2.new(0, 0)
                    bottomBar.Position = UDim2.fromOffset(
                        absolutePosition.X - parentPosition.X,
                        absolutePosition.Y - parentPosition.Y + mainFrame.AbsoluteSize.Y + 4
                    )
                    bottomBar.Size = UDim2.fromOffset(mainFrame.AbsoluteSize.X, 26)
                end
            end))
        end
        return true
    end

    -- 1. Window Resize Handle is now on TASFF_BottomBar (external). Remove any legacy one inside mainFrame.
    local legacyResize = mainFrame:FindFirstChild("ResizeHandle")
    if legacyResize then legacyResize:Destroy() end

    -- 2. Inject Tab Notification Badges, Glowing Active Indicator & Tab Feedback
    local tabList = mainFrame:FindFirstChild("TabList", true)
    local tabContainer = tabList and tabList.Parent or mainFrame
    local legacyGlow = tabContainer:FindFirstChild("ActiveTabGlowBar") or (tabList and tabList:FindFirstChild("ActiveTabGlowBar"))
    if legacyGlow then legacyGlow:Destroy() end

    if tabList then
        for _, tabBtn in ipairs(tabList:GetChildren()) do
            if tabBtn:IsA("GuiObject") and tabBtn.Name ~= "Template" and tabBtn.Name ~= "UIListLayout" and tabBtn.Name ~= "UIPadding" then
                local tName = tabBtn.Name
                local tabPod = tabBtn:FindFirstChild("TabGlowPod")
                if not tabPod then
                    tabPod = Instance.new("Frame", tabBtn)
                    tabPod.Name = "TabGlowPod"
                    tabPod.Size = UDim2.new(1, -8, 0, 2)
                    tabPod.Position = UDim2.new(0, 4, 1, -2)
                    tabPod.BackgroundColor3 = GetThemeAccentColor()
                    tabPod.BackgroundTransparency = 1
                    tabPod.BorderSizePixel = 0
                    tabPod.ZIndex = tabBtn.ZIndex + 1
                    Instance.new("UICorner", tabPod).CornerRadius = UDim.new(1, 0)
                end

                if not tabBtn:FindFirstChild("BadgeFrame") then
                    local bFrame = Instance.new("Frame")
                    bFrame.Name = "BadgeFrame"
                    bFrame.Size = UDim2.new(0, 14, 0, 14)
                    bFrame.AnchorPoint = Vector2.new(1, 0)
                    bFrame.Position = UDim2.new(1, -2, 0, 2)
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
                    bLabel.TextSize = 8
                    bLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    bLabel.Text = "0"
                    _tabBadges[tName] = bLabel

                    tabBtn.InputBegan:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                            bFrame.Visible = false
                            PlayUISound("tab")
                            for _, otherTab in ipairs(tabList:GetChildren()) do
                                local oPod = otherTab:FindFirstChild("TabGlowPod")
                                if oPod then
                                    TweenService:Create(oPod, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
                                end
                            end
                            if tabPod then
                                tabPod.BackgroundColor3 = GetThemeAccentColor()
                                TweenService:Create(tabPod, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.2}):Play()
                            end
                        end
                    end)
                end
            end
        end
    end

    -- Centralized Full Fading & Window State Synchronizer
    local function SyncRayfieldFade()
        local topTrans = (topbar and topbar.BackgroundTransparency) or mainFrame.BackgroundTransparency
        local mainTrans = mainFrame.BackgroundTransparency
        local isVis = ((not rGui or rGui.Enabled) and mainFrame.Visible)
        local isExpanded = (mainFrame.AbsoluteSize.Y > 60)

        -- CyberStroke
        local cStroke = mainFrame:FindFirstChild("CyberStroke")
        if cStroke then
            cStroke.Transparency = math.clamp(mainTrans, 0, 1)
            cStroke.Enabled = (isVis and isExpanded)
        end

        -- Topbar Accent Line sync (no orphan lines when minimized or closed)
        local topbarLine = topbar and topbar:FindFirstChild("TopbarAccentLine")
        if topbarLine then
            topbarLine.Visible = (isVis and isExpanded)
            topbarLine.BackgroundTransparency = mainTrans
        end

        -- Ambient Halo Sync in mainFrame.Parent (100% strictly BEHIND mainFrame, perfectly centered)
        local ambientHalo = mainFrame.Parent and mainFrame.Parent:FindFirstChild("TASFF_AmbientHalo")
        if ambientHalo then
            ambientHalo.Visible = (isVis and isExpanded)
            if ambientHalo.Visible then
                ambientHalo.ImageColor3 = GetThemeAccentColor()
                ambientHalo.ImageTransparency = math.clamp(0.08 + mainTrans * 0.92, 0, 1)
                ambientHalo.AnchorPoint = mainFrame.AnchorPoint
                ambientHalo.Position = mainFrame.Position
                ambientHalo.Size = UDim2.new(mainFrame.Size.X.Scale, mainFrame.Size.X.Offset + 50, mainFrame.Size.Y.Scale, mainFrame.Size.Y.Offset + 50)
            end
        end

        -- Keep native shadow disabled so it NEVER obstructs text or controls
        local nativeShadow = mainFrame:FindFirstChild("Shadow")
        if nativeShadow then
            nativeShadow.Visible = false
        end

        -- Main Window Carbon Mesh (procedural Frame — stays behind elements at ZIndex 0)
        local mMesh = mainFrame:FindFirstChild("MainCarbonMesh")
        if mMesh then
            mMesh.Visible = (isVis and isExpanded)
            mMesh.BackgroundTransparency = mainTrans
        end

        -- Attached TASFF_BottomBar sync (physically glued directly below menu using exact anchor coordinates)
        local bBar = mainFrame.Parent and mainFrame.Parent:FindFirstChild("TASFF_BottomBar")
        if bBar then
            bBar.Visible = (isVis and isExpanded)
            if bBar.Visible then
                bBar.AnchorPoint = Vector2.new(0.5, 0)
                bBar.Size = UDim2.new(0, mainFrame.AbsoluteSize.X, 0, 26)
                bBar.Position = UDim2.new(
                    mainFrame.Position.X.Scale,
                    mainFrame.Position.X.Offset,
                    mainFrame.Position.Y.Scale,
                    mainFrame.Position.Y.Offset + (mainFrame.AbsoluteSize.Y * (1 - mainFrame.AnchorPoint.Y)) + 4
                )
                bBar.BackgroundTransparency = math.clamp(0.10 + mainTrans * 0.90, 0, 1)
                local bStroke2 = bBar:FindFirstChildOfClass("UIStroke")
                if bStroke2 then bStroke2.Transparency = math.clamp(0.5 + mainTrans * 0.5, 0, 1) end
                local opA = bBar:FindFirstChild("OpAvatar")
                if opA then opA.ImageTransparency = mainTrans end
                local opN = bBar:FindFirstChild("OpName")
                if opN then opN.TextTransparency = mainTrans end
                local sCont = bBar:FindFirstChild("StatContainer")
                if sCont then
                    local led = sCont:FindFirstChild("LED")
                    if led then led.BackgroundTransparency = mainTrans end
                    local st = sCont:FindFirstChild("StatusText")
                    if st then st.TextTransparency = mainTrans end
                end
                local rh = bBar:FindFirstChild("ResizeHandle")
                if rh then
                    rh.Visible = (isVis and isExpanded)
                    local g1 = rh:FindFirstChild("Grip1")
                    local g2 = rh:FindFirstChild("Grip2")
                    if g1 then g1.BackgroundTransparency = mainTrans end
                    if g2 then g2.BackgroundTransparency = mainTrans end
                end
            end
        end

        -- Topbar Bell Button
        local bBtn = topbar and topbar:FindFirstChild("NotifBellBtn")
        if bBtn then
            bBtn.Visible = isVis
            bBtn.BackgroundTransparency = math.clamp(0.3 + topTrans * 0.7, 0, 1)
            local bStroke = bBtn:FindFirstChildOfClass("UIStroke")
            if bStroke then bStroke.Transparency = topTrans end
            local bIcon = bBtn:FindFirstChild("BellIcon")
            if bIcon then bIcon.ImageTransparency = topTrans end
            local bDot = bBtn:FindFirstChild("BellDot")
            if bDot then bDot.BackgroundTransparency = topTrans end
        end

        -- Keep NotificationDrawer attached to the right of the menu when visible
        if isVis and isExpanded and NotificationDrawer and NotificationDrawer.Visible then
            UpdateDrawerPosition()
        end

        -- Drawer & Tooltip Auto-Hide on window hide/minimize
        if not isVis or not isExpanded then
            if NotificationDrawer then NotificationDrawer.Visible = false end
            if TooltipFrame then TooltipFrame.Visible = false end
        end
    end

    if not mainFrame:FindFirstChild("MasterFadeSyncHooked") then
        local fHook = Instance.new("BoolValue", mainFrame)
        fHook.Name = "MasterFadeSyncHooked"
        mainFrame:GetPropertyChangedSignal("Visible"):Connect(SyncRayfieldFade)
        mainFrame:GetPropertyChangedSignal("Position"):Connect(SyncRayfieldFade)
        if rGui then
            rGui:GetPropertyChangedSignal("Enabled"):Connect(SyncRayfieldFade)
        end
    end
    SyncRayfieldFade()

    -- 3. Walk Elements and inject Section collapse, Stepper Buttons, Keycaps, Definition Badges, and Live Dots
    local hotkeyNames = {
        ["Master Switch"] = "RightShift",
        ["Quick Preset Switch"] = "J",
        ["Rapid Mode Cycle"] = "P",
        ["Click to Mark"] = "T",
        ["Auto ADS"] = "RMB",
    }

    local hookedTooltips = 0
    for _, desc in ipairs(mainFrame:GetDescendants()) do
        -- STRICT: Skip Rayfield internal templates entirely
        if desc.Name == "Template" or desc:FindFirstAncestor("Template") then
            -- Skip uninstantiated template objects
        else
        -- Theme signature colors in global preset dropdown list
        local function DecorateThemeOption(opt)
            if not opt or not opt:IsA("GuiObject") then return end
            local tName = opt.Name
            local pal = GlobalThemePalettes[tName]
            local title = opt:FindFirstChild("Title") or opt:FindFirstChildOfClass("TextLabel")
            if not pal and title and GlobalThemePalettes[title.Text] then
                tName = title.Text
                pal = GlobalThemePalettes[tName]
            end
            if pal then
                local accCol = HexToColor3(pal.UIAccent or pal.Overlay)
                local baseCol = HexToColor3(pal.Base or pal.Drawing)
                local prioCol = HexToColor3(pal.Priority or "#FF5555")

                if title then
                    title.TextColor3 = accCol
                    title.Font = Enum.Font.GothamBold
                    if not title:FindFirstChild("ColorSyncHooked") then
                        Instance.new("BoolValue", title).Name = "ColorSyncHooked"
                        title:GetPropertyChangedSignal("TextColor3"):Connect(function()
                            if title.TextColor3 ~= accCol then
                                title.TextColor3 = accCol
                            end
                        end)
                    end
                elseif opt:IsA("TextLabel") or opt:IsA("TextButton") then
                    opt.TextColor3 = accCol
                    opt.Font = Enum.Font.GothamBold
                end

                local leftBar = opt:FindFirstChild("ThemeLeftBar")
                if not leftBar then
                    leftBar = Instance.new("Frame", opt)
                    leftBar.Name = "ThemeLeftBar"
                    leftBar.Size = UDim2.new(0, 3, 0.7, 0)
                    leftBar.Position = UDim2.new(0, 4, 0.15, 0)
                    leftBar.BackgroundColor3 = accCol
                    leftBar.BorderSizePixel = 0
                    leftBar.ZIndex = 65
                    Instance.new("UICorner", leftBar).CornerRadius = UDim.new(1, 0)
                else
                    leftBar.BackgroundColor3 = accCol
                end

                local swatch = opt:FindFirstChild("ThemeSwatch")
                if not swatch then
                    swatch = Instance.new("Frame", opt)
                    swatch.Name = "ThemeSwatch"
                    swatch.Size = UDim2.new(0, 38, 0, 14)
                    swatch.Position = UDim2.new(1, -44, 0.5, -7)
                    swatch.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
                    swatch.BackgroundTransparency = 0.2
                    swatch.BorderSizePixel = 0
                    swatch.ZIndex = 65
                    Instance.new("UICorner", swatch).CornerRadius = UDim.new(1, 0)
                    local sStroke = Instance.new("UIStroke", swatch)
                    sStroke.Color = Color3.fromRGB(50, 50, 65)
                    sStroke.Thickness = 1

                    local d1 = Instance.new("Frame", swatch)
                    d1.Size = UDim2.new(0, 8, 0, 8)
                    d1.Position = UDim2.new(0, 3, 0.5, -4)
                    d1.BackgroundColor3 = accCol
                    d1.BorderSizePixel = 0
                    d1.ZIndex = 66
                    Instance.new("UICorner", d1).CornerRadius = UDim.new(1, 0)

                    local d2 = Instance.new("Frame", swatch)
                    d2.Size = UDim2.new(0, 8, 0, 8)
                    d2.Position = UDim2.new(0, 15, 0.5, -4)
                    d2.BackgroundColor3 = baseCol
                    d2.BorderSizePixel = 0
                    d2.ZIndex = 66
                    Instance.new("UICorner", d2).CornerRadius = UDim.new(1, 0)

                    local d3 = Instance.new("Frame", swatch)
                    d3.Size = UDim2.new(0, 8, 0, 8)
                    d3.Position = UDim2.new(0, 27, 0.5, -4)
                    d3.BackgroundColor3 = prioCol
                    d3.BorderSizePixel = 0
                    d3.ZIndex = 66
                    Instance.new("UICorner", d3).CornerRadius = UDim.new(1, 0)
                end
            end
        end

        if GlobalThemePalettes[desc.Name] then
            DecorateThemeOption(desc)
        end

        if desc:IsA("GuiObject") and (desc.Name == "Dropdown" or desc:FindFirstChild("Dropdown") or desc.Name == "List" or desc:FindFirstChild("List")) then
            local listObj = (desc.Name == "List" and desc) or desc:FindFirstChild("List")
            if listObj then
                for _, opt in ipairs(listObj:GetChildren()) do
                    DecorateThemeOption(opt)
                end
                if not listObj:FindFirstChild("ThemeWatcherHooked") then
                    local wHook = Instance.new("BoolValue", listObj)
                    wHook.Name = "ThemeWatcherHooked"
                    listObj.ChildAdded:Connect(function(child)
                        task.wait(0.02)
                        DecorateThemeOption(child)
                    end)
                end
            end
            for _, opt in ipairs(desc:GetDescendants()) do
                if GlobalThemePalettes[opt.Name] then
                    DecorateThemeOption(opt)
                end
            end
            -- Tint the currently selected label to the theme's signature color
            local selLabel = desc:FindFirstChild("Selected")
            if selLabel and selLabel:IsA("TextLabel") and not selLabel:FindFirstChild("ThemeSyncHooked") then
                Instance.new("BoolValue", selLabel).Name = "ThemeSyncHooked"
                local function syncSelectedColor()
                    local tName = selLabel.Text
                    local pal = GlobalThemePalettes[tName]
                    if pal then
                        selLabel.TextColor3 = HexToColor3(pal.UIAccent or pal.Overlay)
                        selLabel.Font = Enum.Font.GothamBold
                    end
                end
                syncSelectedColor()
                selLabel:GetPropertyChangedSignal("Text"):Connect(syncSelectedColor)
            end
        end

        -- Section Header Collapse/Expand Injection. Native Rayfield owns layout
        -- and visibility by default; this opt-in path is intentionally isolated.
        if S.AdvancedThemeLayoutPatchEnabled == true and desc:IsA("GuiObject") and desc.Name == "SectionTitle" then
            local secFrame = desc
            if not secFrame:FindFirstChild("CollapseToggle") then
                local toggleBtn = Instance.new("TextButton")
                toggleBtn.Name = "CollapseToggle"
                toggleBtn.Size = UDim2.new(0, 26, 0, 20)
                toggleBtn.Position = UDim2.new(1, -32, 0.5, -10)
                toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
                toggleBtn.BackgroundTransparency = 0.3
                toggleBtn.BorderSizePixel = 0
                toggleBtn.Text = "" -- NO TEXT, 100% immune to character encoding corruption
                toggleBtn.ZIndex = 20
                Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 4)
                local btnStroke = Instance.new("UIStroke", toggleBtn)
                btnStroke.Color = Color3.fromRGB(50, 50, 65)
                btnStroke.Thickness = 1

                local arrowIcon = Instance.new("ImageLabel", toggleBtn)
                arrowIcon.Name = "ArrowIcon"
                arrowIcon.Size = UDim2.new(0, 12, 0, 12)
                arrowIcon.Position = UDim2.new(0.5, -6, 0.5, -6)
                arrowIcon.BackgroundTransparency = 1
                arrowIcon.Image = "rbxassetid://6031090990" -- Vector chevron down asset
                arrowIcon.ImageColor3 = Color3.fromRGB(180, 180, 195)
                arrowIcon.ZIndex = 21

                toggleBtn.Parent = secFrame

                secFrame:SetAttribute("IsCollapsed", false)
                local _tDebounce = false
                local function toggleCollapse()
                    if _tDebounce then return end
                    _tDebounce = true
                    task.delay(0.15, function() _tDebounce = false end)

                    local isCol = not (secFrame:GetAttribute("IsCollapsed") == true)
                    secFrame:SetAttribute("IsCollapsed", isCol)
                    local targetRot = isCol and -90 or 0
                    local targetCol = isCol and GetThemeAccentColor() or Color3.fromRGB(180, 180, 195)
                    TweenService:Create(arrowIcon, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Rotation = targetRot,
                        ImageColor3 = targetCol
                    }):Play()
                    PlayUISound(isCol and "toggle_off" or "toggle_on")

                    -- Collapsed rectangle indicator directly under the section header
                    local colRect = secFrame:FindFirstChild("CollapsedBar")
                    if not colRect then
                        colRect = Instance.new("Frame", secFrame)
                        colRect.Name = "CollapsedBar"
                        colRect.Size = UDim2.new(1, 0, 0, 8)
                        colRect.Position = UDim2.new(0, 0, 1, 3)
                        colRect.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
                        colRect.BorderSizePixel = 0
                        Instance.new("UICorner", colRect).CornerRadius = UDim.new(0, 4)
                        local crSt = Instance.new("UIStroke", colRect)
                        crSt.Color = Color3.fromRGB(0, 0, 0)
                        crSt.Thickness = 1.5
                    end
                    colRect.Visible = isCol

                    local container = secFrame.Parent
                    if container then
                        local pastSec = false
                        for _, child in ipairs(container:GetChildren()) do
                            if child == secFrame then
                                pastSec = true
                            elseif pastSec then
                                if child.Name == "SectionTitle" then break end
                                if child:IsA("GuiObject") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
                                    child.Visible = not isCol
                                end
                            end
                        end
                    end
                end

                toggleBtn.MouseButton1Click:Connect(toggleCollapse)

                -- Section Element Box: dark fill + black outline wrapping all elements in the section
                task.defer(function()
                    if not (secFrame and secFrame.Parent) then return end
                    local boxContainer = secFrame.Parent
                    if not boxContainer then return end

                    -- Clean up any residual CollapsedBar and hide any dividers to eliminate weird gray lines
                    for _, child in ipairs(boxContainer:GetChildren()) do
                        if child.Name:lower():find("divider") or child.Name:lower():find("line") or (child:IsA("Frame") and #child:GetChildren() == 0 and child.AbsoluteSize.Y <= 8) then
                            child.BackgroundTransparency = 1
                            child.Visible = false
                            local oldSt = child:FindFirstChildOfClass("UIStroke")
                            if oldSt then oldSt:Destroy() end
                        end
                    end

                    -- Inject a thin left accent bar on the secFrame
                    if not secFrame:FindFirstChild("SectionLeftBar") then
                        local leftBar = Instance.new("Frame", secFrame)
                        leftBar.Name = "SectionLeftBar"
                        leftBar.Size = UDim2.new(0, 2, 1, 0)
                        leftBar.Position = UDim2.new(0, 0, 0, 0)
                        leftBar.BackgroundColor3 = GetThemeAccentColor()
                        leftBar.BorderSizePixel = 0
                        leftBar.ZIndex = secFrame.ZIndex + 1
                        Instance.new("UICorner", leftBar).CornerRadius = UDim.new(0, 2)
                    end

                    -- Apply black outline box + dark filling background to configuration elements in section
                    local pastSec2 = false
                    for _, child in ipairs(boxContainer:GetChildren()) do
                        if child == secFrame then
                            pastSec2 = true
                        elseif pastSec2 then
                            if child.Name == "SectionTitle" then break end
                            if child:IsA("GuiObject") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
                                local isCard = child:FindFirstChild("Title") or child:FindFirstChild("Content") or child:FindFirstChild("Interact") or child:FindFirstChild("Switch") or child:FindFirstChild("Slider") or child:FindFirstChild("SliderBar")
                                if isCard then
                                    child.BackgroundColor3 = Color3.fromRGB(16, 17, 24)
                                    if not child:FindFirstChild("SectionBoxStroke") then
                                        local sboxStroke = Instance.new("UIStroke", child)
                                        sboxStroke.Name = "SectionBoxStroke"
                                        sboxStroke.Color = Color3.fromRGB(0, 0, 0)
                                        sboxStroke.Thickness = 1.5
                                        sboxStroke.Transparency = 0.1
                                    end
                                end
                            end
                        end
                    end
                end)

                -- Ensure all elements under this section start 100% visible and expanded upon initial load
                secFrame:SetAttribute("IsCollapsed", false)
                arrowIcon.Rotation = 0
                arrowIcon.ImageColor3 = Color3.fromRGB(180, 180, 195)
                local container = secFrame.Parent
                if container then
                    local pastSec = false
                    for _, child in ipairs(container:GetChildren()) do
                        if child == secFrame then
                            pastSec = true
                        elseif pastSec then
                            if child.Name == "SectionTitle" then break end
                            if child:IsA("GuiObject") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
                                child.Visible = true
                            end
                        end
                    end
                end

                local function syncCollapseFade()
                    local t = secFrame.BackgroundTransparency
                    toggleBtn.BackgroundTransparency = math.clamp(0.3 + t * 0.7, 0, 1)
                    arrowIcon.ImageTransparency = t
                    btnStroke.Transparency = t
                end
                secFrame:GetPropertyChangedSignal("BackgroundTransparency"):Connect(syncCollapseFade)
            end
        end

        -- Slider Precision Stepper Buttons & Live Value Enhancement
        local isSliderCard = desc:IsA("GuiObject") and (
            desc.Name == "Slider" or
            desc:FindFirstChild("Slider") or
            desc:FindFirstChild("SliderBar") or
            (desc:FindFirstChild("Main") and desc.Main:IsA("GuiObject") and desc.Main:FindFirstChild("Progress") and desc.Main:FindFirstChild("Information"))
        )
        if isSliderCard and not desc:FindFirstChild("StepperHooked") then
            local sHook = Instance.new("BoolValue", desc)
            sHook.Name = "StepperHooked"

            local stepMinus = Instance.new("TextButton", desc)
            stepMinus.Name = "StepMinus"
            stepMinus.Size = UDim2.new(0, 20, 0, 20)
            stepMinus.Position = UDim2.new(1, -52, 0, 5)
            stepMinus.BackgroundColor3 = Color3.fromRGB(30, 32, 44)
            stepMinus.BorderSizePixel = 0
            stepMinus.Font = Enum.Font.GothamBold
            stepMinus.TextSize = 13
            stepMinus.TextColor3 = GetThemeAccentColor()
            stepMinus.Text = "-"
            stepMinus.ZIndex = 35
            Instance.new("UICorner", stepMinus).CornerRadius = UDim.new(0, 4)
            local smStroke = Instance.new("UIStroke", stepMinus)
            smStroke.Color = Color3.fromRGB(65, 70, 90)
            smStroke.Thickness = 1

            local stepPlus = Instance.new("TextButton", desc)
            stepPlus.Name = "StepPlus"
            stepPlus.Size = UDim2.new(0, 20, 0, 20)
            stepPlus.Position = UDim2.new(1, -26, 0, 5)
            stepPlus.BackgroundColor3 = Color3.fromRGB(30, 32, 44)
            stepPlus.BorderSizePixel = 0
            stepPlus.Font = Enum.Font.GothamBold
            stepPlus.TextSize = 13
            stepPlus.TextColor3 = GetThemeAccentColor()
            stepPlus.Text = "+"
            stepPlus.ZIndex = 35
            Instance.new("UICorner", stepPlus).CornerRadius = UDim.new(0, 4)
            local spStroke = Instance.new("UIStroke", stepPlus)
            spStroke.Color = Color3.fromRGB(65, 70, 90)
            spStroke.Thickness = 1

            local function AdjustSlider(delta)
                PlayUISound("stepper")
                local titleLabel = desc:FindFirstChild("Title")
                local sliderTitle = (titleLabel and titleLabel.Text) or desc.Name

                -- Try to find matching flag in Rayfield.Flags
                local matchedFlagObj = nil
                local rLibrary = (TASFFEnv and TASFFEnv.Rayfield) or (getgenv and getgenv().Rayfield)
                if rLibrary and rLibrary.Flags then
                    for _, flagObj in pairs(rLibrary.Flags) do
                        if type(flagObj) == "table" and (flagObj.Name == sliderTitle or flagObj.Name == desc.Name) and flagObj.Set then
                            matchedFlagObj = flagObj
                            break
                        end
                    end
                end

                if matchedFlagObj then
                    local inc = matchedFlagObj.Increment or 1
                    local cur = matchedFlagObj.CurrentValue or 0
                    local min = (matchedFlagObj.Range and matchedFlagObj.Range[1]) or -math.huge
                    local max = (matchedFlagObj.Range and matchedFlagObj.Range[2]) or math.huge
                    local target = math.clamp(cur + delta * inc, min, max)
                    pcall(function() matchedFlagObj:Set(target) end)
                else
                    local mainBar = desc:FindFirstChild("Main")
                    local infoLabel = mainBar and mainBar:FindFirstChild("Information")
                    if infoLabel and infoLabel:IsA("TextLabel") then
                        local curNum = tonumber(infoLabel.Text:match("[%-%d%.]+"))
                        if curNum then
                            local target = curNum + delta * 1
                            infoLabel.Text = tostring(target)
                        end
                    end
                end
            end

            stepMinus.MouseButton1Click:Connect(function()
                AdjustSlider(-1)
            end)
            stepPlus.MouseButton1Click:Connect(function()
                AdjustSlider(1)
            end)
        end

        -- 1-Click Color Preset Swatches on ColorPickers (Strictly exclude Templates)
        if desc:IsA("GuiObject") and desc.Name ~= "Template" and not desc:FindFirstAncestor("Template") and desc:FindFirstChild("ColorPicker") and not desc:FindFirstChild("QuickSwatchesHooked") then
            local swHook = Instance.new("BoolValue", desc)
            swHook.Name = "QuickSwatchesHooked"
            local swRow = Instance.new("Frame", desc)
            swRow.Name = "QuickSwatches"
            swRow.Size = UDim2.new(0, 120, 0, 14)
            swRow.Position = UDim2.new(1, -130, 0, 4)
            swRow.BackgroundTransparency = 1

            local quickPal = {"#00F5FF", "#FF2A8A", "#39FF88", "#FFD400", "#BD93F9", "#FF304A", "#FFFFFF", "#86C4E0"}
            for i, hex in ipairs(quickPal) do
                local swDot = Instance.new("TextButton", swRow)
                swDot.Size = UDim2.new(0, 11, 0, 11)
                swDot.Position = UDim2.new(0, (i - 1) * 15, 0, 1)
                swDot.BackgroundColor3 = HexToColor3(hex)
                swDot.BorderSizePixel = 0
                swDot.Text = ""
                Instance.new("UICorner", swDot).CornerRadius = UDim.new(1, 0)
                swDot.MouseButton1Click:Connect(function()
                    PlayUISound("click")
                end)
            end
        end

        -- 3D Physical Keycap Styling on Keybinds
        if desc:IsA("GuiObject") and desc.Name ~= "Template" and not desc:FindFirstAncestor("Template") and desc:FindFirstChild("Keybind") and not desc:FindFirstChild("Keycap3DHooked") then
            local kbHook = Instance.new("BoolValue", desc)
            kbHook.Name = "Keycap3DHooked"
            local kbBtn = desc:FindFirstChild("Keybind")
            if kbBtn:IsA("GuiObject") then
                kbBtn.BackgroundColor3 = Color3.fromRGB(32, 34, 44)
                Instance.new("UICorner", kbBtn).CornerRadius = UDim.new(0, 4)
                local kbStroke = Instance.new("UIStroke", kbBtn)
                kbStroke.Color = Color3.fromRGB(60, 62, 75)
                kbStroke.Thickness = 1
            end
        end

        -- Tooltip & Definition attachment on interactive elements
        local titleLabel = desc:FindFirstChild("Title", true)
        if titleLabel and titleLabel:IsA("TextLabel") and titleLabel.Text ~= "" then
            local cleanName = titleLabel.Text:gsub("^%[KEY%]%s*", ""):gsub("^[^%a%d]+%s*", ""):gsub(":%s*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
            local def = ControlTooltips[cleanName] or ControlTooltips[desc.Name]
            if def and not desc:FindFirstChild("TooltipHooked") then
                local hookTag = Instance.new("BoolValue")
                hookTag.Name = "TooltipHooked"
                hookTag.Parent = desc
                hookedTooltips = hookedTooltips + 1

                if not titleLabel:FindFirstChild("DefBadge") then
                    local qBadge = Instance.new("TextLabel")
                    qBadge.Name = "DefBadge"
                    qBadge.Size = UDim2.new(0, 15, 0, 15)
                    local tw = TextService:GetTextSize(titleLabel.Text, titleLabel.TextSize, titleLabel.Font, Vector2.new(1000, 50)).X
                    qBadge.Position = UDim2.new(0, math.floor(tw + 8), 0.5, -7)
                    qBadge.BackgroundColor3 = Color3.fromRGB(35, 36, 45)
                    qBadge.BackgroundTransparency = 0.2
                    qBadge.Font = Enum.Font.GothamBold
                    qBadge.TextSize = 10
                    qBadge.TextColor3 = GetThemeAccentColor()
                    qBadge.Text = "?"
                    qBadge.ZIndex = 15
                    Instance.new("UICorner", qBadge).CornerRadius = UDim.new(1, 0)
                    local qStroke = Instance.new("UIStroke", qBadge)
                    qStroke.Color = GetThemeAccentColor()
                    qStroke.Thickness = 1
                    qStroke.Transparency = 0.4
                    qBadge.Parent = titleLabel

                    titleLabel:GetPropertyChangedSignal("Text"):Connect(function()
                        local ntw = TextService:GetTextSize(titleLabel.Text, titleLabel.TextSize, titleLabel.Font, Vector2.new(1000, 50)).X
                        qBadge.Position = UDim2.new(0, math.floor(ntw + 8), 0.5, -7)
                    end)
                end

                if hotkeyNames[cleanName] and not titleLabel:FindFirstChild("HotkeyBadge") then
                    local kBadge = Instance.new("TextLabel", titleLabel)
                    kBadge.Name = "HotkeyBadge"
                    kBadge.Size = UDim2.new(0, 36, 0, 15)
                    local tw = TextService:GetTextSize(titleLabel.Text, titleLabel.TextSize, titleLabel.Font, Vector2.new(1000, 50)).X
                    kBadge.Position = UDim2.new(0, math.floor(tw + 26), 0.5, -7)
                    kBadge.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
                    kBadge.Font = Enum.Font.GothamBold
                    kBadge.TextSize = 9
                    kBadge.TextColor3 = Color3.fromRGB(235, 205, 120)
                    kBadge.Text = "[" .. hotkeyNames[cleanName] .. "]"
                    Instance.new("UICorner", kBadge).CornerRadius = UDim.new(0, 3)
                    local kbStroke = Instance.new("UIStroke", kBadge)
                    kbStroke.Color = Color3.fromRGB(55, 55, 70)
                end

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

                if not desc:FindFirstChild("DefTooltipHooked") then
                    Instance.new("BoolValue", desc).Name = "DefTooltipHooked"
                    desc.MouseEnter:Connect(onHoverEnter)
                    desc.MouseLeave:Connect(onHoverLeave)
                end
            end
        end

        -- 3b. Atmospheric Carbon Weave & Card Hover Glow Injection
        -- Helper: identify a Rayfield Paragraph frame (has Title+Content, no interactive children)
        local function IsParagraphFrame(f)
            if not f or not f:IsA("Frame") then return false end
            if not f:FindFirstChild("Content") or not f:FindFirstChild("Title") then return false end
            if f:FindFirstChild("Switch") or f:FindFirstChild("Slider") or
               f:FindFirstChild("ColorPicker") or f:FindFirstChild("Keybind") or
               f:FindFirstChild("Dropdown") then return false end
            return true
        end

        if desc:IsA("GuiObject") and desc.Name ~= "Template" and not desc:FindFirstAncestor("Template") and desc.Parent and (desc.Parent.Name == "Elements" or desc.Parent:FindFirstChild("UIListLayout")) then
            AttachHoverGlow(desc)

            -- Clean and native Paragraph refinement
            if IsParagraphFrame(desc) then
                local oldBar = desc:FindFirstChild("ParaAccentBar")
                if oldBar then oldBar:Destroy() end
                -- Apply universal carbon texture to paragraph card (wrapped in Folder so UIListLayout ignores it!)
                AttachCarbonOverlay(desc, 0.38)

                if not desc:FindFirstChild("ParaBoxStroke") then
                    local pStroke = Instance.new("UIStroke", desc)
                    pStroke.Name = "ParaBoxStroke"
                    pStroke.Color = GetThemeAccentColor()
                    pStroke.Thickness = 1
                    pStroke.Transparency = 0.55
                end

                local title = desc:FindFirstChild("Title")
                local content = desc:FindFirstChild("Content")
                if title and content and title:IsA("TextLabel") and content:IsA("TextLabel") then
                    title.TextColor3 = GetThemeAccentColor()
                    title.Font = Enum.Font.GothamBold
                    content.TextColor3 = Color3.fromRGB(195, 200, 210)
                    content.Font = Enum.Font.GothamMedium
                end
            -- Attach universal carbon overlay to non-paragraph interactive elements
            elseif not IsParagraphFrame(desc.Parent) then
                if desc:FindFirstChild("Switch") or (desc:FindFirstChild("Interact") and not desc:FindFirstChild("Slider")) or desc:FindFirstChild("Dropdown") or desc:FindFirstChild("Slider") or desc:FindFirstChild("Keybind") or desc:FindFirstChild("ColorPicker") then
                    AttachCarbonOverlay(desc, 0.38)
                end
            end
        end

        -- Live State Dot on Toggles & Neon Glow Switch Track
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
                local isNowOn = ind and (ind.Position.X.Offset > -30)
                if isNowOn then
                    dot.BackgroundColor3 = Color3.fromRGB(0, 240, 130)
                    if switch then
                        switch.BackgroundColor3 = GetThemeAccentColor()
                        switch.BackgroundTransparency = 0.25
                    end
                else
                    dot.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
                    if switch then
                        switch.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
                        switch.BackgroundTransparency = 0
                    end
                end
            end
            task.delay(0.2, updateDot)
            local interact = desc:FindFirstChild("Interact")
            if interact and interact:IsA("GuiObject") then
                interact.InputEnded:Connect(function()
                    task.delay(0.1, function()
                        updateDot()
                        local ind = switch and switch:FindFirstChild("Indicator")
                        local isNowOn = ind and (ind.Position.X.Offset > -30)
                        PlayUISound(isNowOn and "toggle_on" or "toggle_off")
                    end)
                end)
            end
        end
        end
    end

    -- Update the Feature Overview paragraph with element counts pulled directly from TASFF_Lists.lua
    if S.FeatureOverviewParagraph and S.FeatureOverviewParagraph.Set then
        pcall(function()
            S.FeatureOverviewParagraph:Set({
                Title   = "UI Element Breakdown",
                Content = string.format(
                    "Toggles: %d  |  Buttons: %d  |  Sliders: %d\nDropdowns: %d  |  Keybinds: %d  |  Color Pickers: %d  |  Paragraphs: %d",
                    S.ToggleCount or 109,
                    S.ButtonCount or 36,
                    S.SliderCount or 40,
                    S.DropdownCount or 44,
                    S.KeybindCount or 6,
                    S.ColorPickerCount or 16,
                    S.ParagraphCount or 73
                )
            })
        end)
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



local RayfieldVisibilityConnections = {}
local RayfieldVisibilityBound = false

local function SyncRayfieldVisibility()
    local rGui = FindRayfieldGui and FindRayfieldGui()
    local mainFrame = rGui and (rGui:FindFirstChild("Main", true) or rGui:FindFirstChildOfClass("Frame"))
    if not rGui or not mainFrame then return end
    local isVisible = rGui.Enabled ~= false and mainFrame.Visible ~= false

    if OverlayGui then
        OverlayGui.Enabled = isVisible
    end

    local parent = mainFrame.Parent
    if parent then
        for _, name in ipairs({"TASFF_AmbientHalo", "TASFF_BottomBar"}) do
            local external = parent:FindFirstChild(name)
            if external and external:IsA("GuiObject") then
                external.Visible = isVisible
            end
        end
    end
end

local function BindRayfieldVisibility()
    if RayfieldVisibilityBound then
        SyncRayfieldVisibility()
        return
    end

    local rGui = FindRayfieldGui and FindRayfieldGui()
    local mainFrame = rGui and (rGui:FindFirstChild("Main", true) or rGui:FindFirstChildOfClass("Frame"))
    if not rGui or not mainFrame then
        return false
    end

    RayfieldVisibilityBound = true
    table.insert(RayfieldVisibilityConnections, rGui:GetPropertyChangedSignal("Enabled"):Connect(SyncRayfieldVisibility))
    table.insert(RayfieldVisibilityConnections, mainFrame:GetPropertyChangedSignal("Visible"):Connect(SyncRayfieldVisibility))
    table.insert(Connections, RayfieldVisibilityConnections[#RayfieldVisibilityConnections])
    table.insert(Connections, RayfieldVisibilityConnections[#RayfieldVisibilityConnections - 1])
    SyncRayfieldVisibility()
    return true
end

local function DestroyTheme()
    for _, conn in ipairs(RayfieldVisibilityConnections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(RayfieldVisibilityConnections)
    RayfieldVisibilityBound = false

    if OverlayGui then
        OverlayGui.Enabled = false
        pcall(function() OverlayGui:Destroy() end)
    end

    local parents = {}
    pcall(function()
        if typeof(gethui) == "function" then
            local h = gethui()
            if h then table.insert(parents, h) end
        end
    end)
    pcall(function() table.insert(parents, game:GetService("CoreGui")) end)
    pcall(function()
        local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pg then table.insert(parents, pg) end
    end)
    for _, parent in ipairs(parents) do
        for _, name in ipairs({
            "TASFF_AmbientHalo",
            "TASFF_BottomBar",
            "TASFF_AmbientAura",
        }) do
            local child = parent:FindFirstChild(name)
            if child then
                pcall(function() child:Destroy() end)
            end
        end
    end
end

TASFFEnv.Theme.BindRayfieldVisibility = BindRayfieldVisibility
TASFFEnv.Theme.SyncRayfieldVisibility = SyncRayfieldVisibility
TASFFEnv.Theme.Destroy = DestroyTheme

-- Defer initial DOM patch until UI is completely built by TASFF_UI.lua
task.spawn(function()
    while not (S.UIInitialized or S.ScriptInitialized) do
        task.wait(0.2)
    end
    task.wait(0.2)
    for i = 1, 2 do
        task.wait(0.4)
        local ok, res = pcall(PatchRayfieldDOM)
        if ok and res then
            S.ThemePatchDone = true
        elseif not ok then
            warn("[TASFF Theme] PatchRayfieldDOM error on pass " .. i .. ": " .. tostring(res))
        end
    end
end)

TASFFEnv.Theme.PatchRayfieldDOM = PatchRayfieldDOM

print("[TASFF Theme v" .. (S.CurrentVersion or "2.3.0") .. "] Theme module and extensions fully loaded.")
