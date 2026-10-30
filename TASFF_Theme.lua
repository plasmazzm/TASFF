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
        Name            = "TASFF " .. (S.CurrentVersion or "2.3.0") .. " - " .. (selectedThemeName or "Default"),
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

    local tgtChar = tgt.Character or (tgt.Parent and tgt.Parent:IsA("Model") and tgt.Parent) or tgt
    local tgtHum = tgtChar and tgtChar:FindFirstChildOfClass("Humanoid")
    local tgtRoot = tgtChar and (tgtChar:FindFirstChild("HumanoidRootPart") or tgtChar:FindFirstChild("Head") or tgtChar.PrimaryPart)
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
NotificationDrawer.Position = UDim2.new(1, -260, 0, 45)
NotificationDrawer.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
NotificationDrawer.BackgroundTransparency = 0.15
NotificationDrawer.BorderSizePixel = 0
NotificationDrawer.Visible = false
NotificationDrawer.ZIndex = 120
NotificationDrawer.Parent = OverlayGui
Instance.new("UICorner", NotificationDrawer).CornerRadius = UDim.new(0, 8)
local ndStroke = Instance.new("UIStroke", NotificationDrawer)
ndStroke.Color = GetThemeAccentColor()
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
        local rGui = FindRayfieldGui and FindRayfieldGui()
        if rGui then
            local topbar = rGui:FindFirstChild("Topbar", true)
            local bellBtn = topbar and topbar:FindFirstChild("NotifBellBtn")
            if bellBtn then
                local bPos = bellBtn.AbsolutePosition
                local bSize = bellBtn.AbsoluteSize
                NotificationDrawer.Position = UDim2.new(0, math.clamp(bPos.X + bSize.X - 240, 10, 3000), 0, bPos.Y + bSize.Y + 8)
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
local function FindRayfieldGui()
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

    for _, container in ipairs(containers) do
        -- 1. Try finding Main frame recursively
        local main = container:FindFirstChild("Main", true)
        if main and main:IsA("GuiObject") and main:FindFirstChild("Topbar") and main:FindFirstChild("Elements") then
            local sg = main:FindFirstAncestorWhichIsA("ScreenGui")
            if sg and sg.Name ~= "TASFF_OverlayGui" and sg.Name ~= "TASFF_Overlay" then
                return sg
            end
            if main.Parent and main.Parent:IsA("ScreenGui") then return main.Parent end
        end
        -- 2. Try by direct child
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("ScreenGui") and child.Name ~= "TASFF_OverlayGui" and child.Name ~= "TASFF_Overlay" then
                local m = child:FindFirstChild("Main")
                if m and m:IsA("GuiObject") and m:FindFirstChild("Topbar") and m:FindFirstChild("Elements") then
                    return child
                end
            end
        end
        -- 3. Try by name
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("ScreenGui") and child.Name ~= "TASFF_OverlayGui" and child.Name ~= "TASFF_Overlay" then
                local n = child.Name:lower()
                if n:find("rayfield") or n:find("sirius") then
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

-- Carbon Weave Texture & Control Hover Glow Helpers
local function AttachCarbonOverlay(targetFrame, transparency)
    if not targetFrame or targetFrame:FindFirstChild("CarbonOverlay") then return end
    local carbon = Instance.new("ImageLabel")
    carbon.Name = "CarbonOverlay"
    carbon.Size = UDim2.new(1, 0, 1, 0)
    carbon.Position = UDim2.new(0, 0, 0, 0)
    carbon.BackgroundTransparency = 1
    carbon.Image = "rbxassetid://2151741365"
    carbon.ImageColor3 = Color3.fromRGB(240, 240, 255)
    carbon.ScaleType = Enum.ScaleType.Tile
    carbon.TileSize = UDim2.new(0, 16, 0, 16)
    carbon.ImageTransparency = transparency or 0.80
    carbon.ZIndex = math.max(1, targetFrame.ZIndex)
    Instance.new("UICorner", carbon).CornerRadius = UDim.new(0, 6)
    carbon.Parent = targetFrame
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
    local rGui = FindRayfieldGui()
    if not rGui then return false end

    local mainFrame = rGui:FindFirstChild("Main", true) or rGui:FindFirstChildOfClass("Frame")
    if not mainFrame then return false end

    if S.UIOpacity and S.UIOpacity < 1.0 then
        mainFrame.BackgroundTransparency = 1 - S.UIOpacity
    end

    -- 0. Window Dimensions State & Persistent Size Preserver across Open/Close
    S.DesiredWindowWidth = S.DesiredWindowWidth or 640
    S.DesiredWindowHeight = S.DesiredWindowHeight or 480

    if mainFrame.AbsoluteSize.X < 600 and mainFrame.AbsoluteSize.Y > 100 then
        mainFrame.Size = UDim2.new(0, S.DesiredWindowWidth, 0, math.max(S.DesiredWindowHeight, mainFrame.AbsoluteSize.Y))
    end

    if not mainFrame:FindFirstChild("SizePreserverHooked") then
        local spHook = Instance.new("BoolValue", mainFrame)
        spHook.Name = "SizePreserverHooked"

        local _sizeDebounce = false
        mainFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            if _resizing or _sizeDebounce then return end
            -- Rayfield resets to 500px width whenever user toggles/opens the window
            if mainFrame.Visible and mainFrame.AbsoluteSize.Y > 120 and mainFrame.AbsoluteSize.X < 590 then
                _sizeDebounce = true
                task.defer(function()
                    if mainFrame and mainFrame.Parent and mainFrame.Visible and mainFrame.AbsoluteSize.Y > 120 then
                        local tw = S.DesiredWindowWidth or 640
                        local th = S.DesiredWindowHeight or math.max(480, mainFrame.AbsoluteSize.Y)
                        mainFrame.Size = UDim2.new(0, tw, 0, th)
                    end
                    task.wait(0.2)
                    _sizeDebounce = false
                end)
            end
        end)
    end

    -- 0a. Tactical Carbon Mesh on Window Background
    if not mainFrame:FindFirstChild("MainCarbonMesh") then
        local mCarbon = Instance.new("ImageLabel")
        mCarbon.Name = "MainCarbonMesh"
        mCarbon.Size = UDim2.new(1, 0, 1, 0)
        mCarbon.Position = UDim2.new(0, 0, 0, 0)
        mCarbon.BackgroundTransparency = 1
        mCarbon.Image = "rbxassetid://2151741365"
        mCarbon.ImageColor3 = Color3.fromRGB(240, 240, 255)
        mCarbon.ScaleType = Enum.ScaleType.Tile
        mCarbon.TileSize = UDim2.new(0, 16, 0, 16)
        mCarbon.ImageTransparency = 0.80
        mCarbon.ZIndex = 1
        Instance.new("UICorner", mCarbon).CornerRadius = UDim.new(0, 8)
        mCarbon.Parent = mainFrame
    end

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

    -- 0c. Centered Ambient Halo Styling (Native Rayfield Shadow Glow - 100% Centered & Symmetrical)
    if mainFrame.Parent then
        local residualAura = mainFrame.Parent:FindFirstChild("TASFF_AmbientAura")
        if residualAura then residualAura:Destroy() end
    end
    local legacyShadow = mainFrame:FindFirstChild("GlassShadow")
    if legacyShadow then legacyShadow:Destroy() end

    local nativeShadow = mainFrame:FindFirstChild("Shadow")
    if nativeShadow then
        -- Center the Shadow frame on mainFrame so glow is symmetrical on all 4 sides
        nativeShadow.AnchorPoint = Vector2.new(0.5, 0.5)
        nativeShadow.Position    = UDim2.new(0.5, 0, 0.5, 0)
        nativeShadow.Size        = UDim2.new(1, 80, 1, 80) -- 40px bleed each side
        local sImg = nativeShadow:FindFirstChild("Image") or (nativeShadow:IsA("ImageLabel") and nativeShadow)
        if sImg and sImg:IsA("ImageLabel") then
            -- Keep the inner image filling the Shadow container symmetrically
            sImg.AnchorPoint        = Vector2.new(0.5, 0.5)
            sImg.Position           = UDim2.new(0.5, 0, 0.5, 0)
            sImg.Size               = UDim2.new(1, 0, 1, 0)
            sImg.ImageColor3        = GetThemeAccentColor()
            sImg.ImageTransparency  = 0.50
        end
    end

    -- 0d. Topbar Clean Accent Line & Notification Center Bell (Shifted clear of Search)
    local topbar = mainFrame:FindFirstChild("Topbar", true)
    if topbar then
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

    -- Relocated Operator Profile & Live System Monitor into Sleek Bottom Dock
    local bottomDock = mainFrame:FindFirstChild("BottomDock")
    if not bottomDock then
        bottomDock = Instance.new("Frame", mainFrame)
        bottomDock.Name = "BottomDock"
        bottomDock.Size = UDim2.new(1, -36, 0, 22)
        bottomDock.Position = UDim2.new(0, 10, 1, -25)
        bottomDock.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
        bottomDock.BackgroundTransparency = 0.35
        bottomDock.BorderSizePixel = 0
        bottomDock.ZIndex = 50
        Instance.new("UICorner", bottomDock).CornerRadius = UDim.new(0, 5)
        local dockStroke = Instance.new("UIStroke", bottomDock)
        dockStroke.Color = Color3.fromRGB(42, 42, 54)
        dockStroke.Thickness = 1

        AttachCarbonOverlay(bottomDock, 0.74)

        -- Left: Operator Avatar & Identity Badge
        local opAvatar = Instance.new("ImageLabel", bottomDock)
        opAvatar.Name = "OpAvatar"
        opAvatar.Size = UDim2.new(0, 16, 0, 16)
        opAvatar.Position = UDim2.new(0, 4, 0.5, -8)
        opAvatar.BackgroundTransparency = 1
        opAvatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=48&h=48"
        opAvatar.ZIndex = 51
        Instance.new("UICorner", opAvatar).CornerRadius = UDim.new(1, 0)

        local opName = Instance.new("TextLabel", bottomDock)
        opName.Name = "OpName"
        opName.Size = UDim2.new(0, 220, 1, 0)
        opName.Position = UDim2.new(0, 25, 0, 0)
        opName.BackgroundTransparency = 1
        opName.Font = Enum.Font.GothamBold
        opName.TextSize = 9
        opName.TextColor3 = Color3.fromRGB(220, 220, 230)
        opName.TextXAlignment = Enum.TextXAlignment.Left
        opName.TextTruncate = Enum.TextTruncate.AtEnd
        opName.ZIndex = 51
        local exec = (identifyexecutor and identifyexecutor()) or "Client"
        opName.Text = (LocalPlayer.DisplayName or LocalPlayer.Name) .. " (" .. exec .. ")"

        -- Right: Live Status Monitor (FPS & Latency Ping)
        local statContainer = Instance.new("Frame", bottomDock)
        statContainer.Name = "StatContainer"
        statContainer.Size = UDim2.new(0, 150, 1, 0)
        statContainer.Position = UDim2.new(1, -155, 0, 0)
        statContainer.BackgroundTransparency = 1
        statContainer.ZIndex = 51

        local led = Instance.new("Frame", statContainer)
        led.Name = "LED"
        led.Size = UDim2.new(0, 6, 0, 6)
        led.Position = UDim2.new(0, 4, 0.5, -3)
        led.BackgroundColor3 = Color3.fromRGB(0, 240, 130)
        led.BorderSizePixel = 0
        led.ZIndex = 52
        Instance.new("UICorner", led).CornerRadius = UDim.new(1, 0)

        local sText = Instance.new("TextLabel", statContainer)
        sText.Name = "StatusText"
        sText.Size = UDim2.new(1, -14, 1, 0)
        sText.Position = UDim2.new(0, 14, 0, 0)
        sText.BackgroundTransparency = 1
        sText.Font = Enum.Font.GothamBold
        sText.TextSize = 9
        sText.TextColor3 = Color3.fromRGB(190, 215, 220)
        sText.TextXAlignment = Enum.TextXAlignment.Left
        sText.Text = "60 FPS  |  Ping: 0ms"
        sText.ZIndex = 52

        task.spawn(function()
            while bottomDock and bottomDock.Parent do
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

    -- 1. Window Resize Handle (Modern Vector Grip with Smooth Fade Sync)
    if not mainFrame:FindFirstChild("ResizeHandle") then
        local resizeHandle = Instance.new("Frame")
        resizeHandle.Name = "ResizeHandle"
        resizeHandle.Size = UDim2.new(0, 20, 0, 20)
        resizeHandle.Position = UDim2.new(1, -20, 1, -20)
        resizeHandle.BackgroundTransparency = 1
        resizeHandle.BorderSizePixel = 0
        resizeHandle.ZIndex = 60
        resizeHandle.Parent = mainFrame

        local grip1 = Instance.new("Frame", resizeHandle)
        grip1.Name = "Grip1"
        grip1.Size = UDim2.new(0, 11, 0, 2)
        grip1.Position = UDim2.new(0, 6, 0, 12)
        grip1.Rotation = -45
        grip1.BackgroundColor3 = Color3.fromRGB(160, 160, 175)
        grip1.BorderSizePixel = 0
        grip1.ZIndex = 61

        local grip2 = Instance.new("Frame", resizeHandle)
        grip2.Name = "Grip2"
        grip2.Size = UDim2.new(0, 6, 0, 2)
        grip2.Position = UDim2.new(0, 11, 0, 15)
        grip2.Rotation = -45
        grip2.BackgroundColor3 = Color3.fromRGB(160, 160, 175)
        grip2.BorderSizePixel = 0
        grip2.ZIndex = 61

        local hitArea = Instance.new("TextButton", resizeHandle)
        hitArea.Name = "HitArea"
        hitArea.Size = UDim2.new(1, 0, 1, 0)
        hitArea.BackgroundTransparency = 1
        hitArea.Text = ""
        hitArea.ZIndex = 62

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
                S.DesiredWindowWidth = newW
                S.DesiredWindowHeight = newH
            end
        end)
    end

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
        local isVis = (mainFrame.Visible and topTrans < 0.95 and mainTrans < 0.95)
        local isExpanded = (mainFrame.AbsoluteSize.Y > 60)

        -- CyberStroke
        local cStroke = mainFrame:FindFirstChild("CyberStroke")
        if cStroke then
            cStroke.Transparency = math.clamp(mainTrans, 0, 1)
            cStroke.Enabled = isVis
        end

        -- Clean up residual TASFF_AmbientAura
        if mainFrame.Parent then
            local aAura = mainFrame.Parent:FindFirstChild("TASFF_AmbientAura")
            if aAura then aAura:Destroy() end
        end

        -- Native Rayfield Centered Shadow Glow Sync (keep centered every fade cycle)
        local nativeShadow = mainFrame:FindFirstChild("Shadow")
        if nativeShadow then
            nativeShadow.AnchorPoint = Vector2.new(0.5, 0.5)
            nativeShadow.Position    = UDim2.new(0.5, 0, 0.5, 0)
            nativeShadow.Size        = UDim2.new(1, 80, 1, 80)
            local sImg = nativeShadow:FindFirstChild("Image") or (nativeShadow:IsA("ImageLabel") and nativeShadow)
            if sImg and sImg:IsA("ImageLabel") then
                sImg.AnchorPoint       = Vector2.new(0.5, 0.5)
                sImg.Position          = UDim2.new(0.5, 0, 0.5, 0)
                sImg.Size              = UDim2.new(1, 0, 1, 0)
                sImg.ImageColor3       = GetThemeAccentColor()
                sImg.ImageTransparency = math.clamp(0.50 + mainTrans * 0.50, 0, 1)
            end
        end

        -- Main Window Carbon Mesh
        local mMesh = mainFrame:FindFirstChild("MainCarbonMesh")
        if mMesh then
            mMesh.Visible = (isVis and isExpanded)
            mMesh.ImageTransparency = math.clamp(0.80 + mainTrans * 0.20, 0, 1)
        end

        -- Relocated Tactical Bottom Dock Sync
        local bDock = mainFrame:FindFirstChild("BottomDock")
        if bDock then
            bDock.Visible = (isVis and isExpanded)
            bDock.BackgroundTransparency = math.clamp(0.35 + mainTrans * 0.65, 0, 1)
            local dStroke = bDock:FindFirstChildOfClass("UIStroke")
            if dStroke then dStroke.Transparency = mainTrans end
            local opA = bDock:FindFirstChild("OpAvatar")
            if opA then opA.ImageTransparency = mainTrans end
            local opN = bDock:FindFirstChild("OpName")
            if opN then opN.TextTransparency = mainTrans end
            local sCont = bDock:FindFirstChild("StatContainer")
            if sCont then
                local led = sCont:FindFirstChild("LED")
                if led then led.BackgroundTransparency = mainTrans end
                local st = sCont:FindFirstChild("StatusText")
                if st then st.TextTransparency = mainTrans end
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

        -- Resize Handle
        local rHandle = mainFrame:FindFirstChild("ResizeHandle")
        if rHandle then
            rHandle.Visible = (isVis and isExpanded)
            local g1 = rHandle:FindFirstChild("Grip1")
            local g2 = rHandle:FindFirstChild("Grip2")
            if g1 then g1.BackgroundTransparency = mainTrans end
            if g2 then g2.BackgroundTransparency = mainTrans end
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
        mainFrame:GetPropertyChangedSignal("BackgroundTransparency"):Connect(SyncRayfieldFade)
        mainFrame:GetPropertyChangedSignal("Visible"):Connect(SyncRayfieldFade)
        mainFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(SyncRayfieldFade)
        mainFrame:GetPropertyChangedSignal("Position"):Connect(SyncRayfieldFade)
        if topbar then
            topbar:GetPropertyChangedSignal("BackgroundTransparency"):Connect(SyncRayfieldFade)
            topbar:GetPropertyChangedSignal("Visible"):Connect(SyncRayfieldFade)
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

        -- Section Header Collapse/Expand Injection
        if desc:IsA("GuiObject") and desc.Name == "SectionTitle" then
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
        if desc:IsA("GuiObject") and desc:FindFirstChild("Slider") and not desc:FindFirstChild("StepperHooked") then
            local sHook = Instance.new("BoolValue", desc)
            sHook.Name = "StepperHooked"

            local stepMinus = Instance.new("TextButton", desc)
            stepMinus.Name = "StepMinus"
            stepMinus.Size = UDim2.new(0, 16, 0, 16)
            stepMinus.Position = UDim2.new(1, -135, 0.5, -8)
            stepMinus.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
            stepMinus.BorderSizePixel = 0
            stepMinus.Font = Enum.Font.GothamBold
            stepMinus.TextSize = 11
            stepMinus.TextColor3 = Color3.fromRGB(200, 200, 215)
            stepMinus.Text = "-"
            Instance.new("UICorner", stepMinus).CornerRadius = UDim.new(0, 3)

            local stepPlus = Instance.new("TextButton", desc)
            stepPlus.Name = "StepPlus"
            stepPlus.Size = UDim2.new(0, 16, 0, 16)
            stepPlus.Position = UDim2.new(1, -22, 0.5, -8)
            stepPlus.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
            stepPlus.BorderSizePixel = 0
            stepPlus.Font = Enum.Font.GothamBold
            stepPlus.TextSize = 11
            stepPlus.TextColor3 = Color3.fromRGB(200, 200, 215)
            stepPlus.Text = "+"
            Instance.new("UICorner", stepPlus).CornerRadius = UDim.new(0, 3)

            stepMinus.MouseButton1Click:Connect(function()
                PlayUISound("stepper")
            end)
            stepPlus.MouseButton1Click:Connect(function()
                PlayUISound("stepper")
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

                desc.MouseEnter:Connect(onHoverEnter)
                desc.MouseLeave:Connect(onHoverLeave)

                for _, child in ipairs(desc:GetDescendants()) do
                    if child:IsA("GuiObject") then
                        child.MouseEnter:Connect(onHoverEnter)
                        child.MouseLeave:Connect(onHoverLeave)
                    end
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

            -- Clean and native Paragraph refinement (destroy any legacy pBar or carbon overlays)
            if IsParagraphFrame(desc) then
                local oldBar = desc:FindFirstChild("ParaAccentBar")
                if oldBar then oldBar:Destroy() end
                local oldCarbon = desc:FindFirstChild("CarbonOverlay")
                if oldCarbon then oldCarbon:Destroy() end

                local title = desc:FindFirstChild("Title")
                local content = desc:FindFirstChild("Content")
                if title and content and title:IsA("TextLabel") and content:IsA("TextLabel") then
                    title.TextColor3 = GetThemeAccentColor()
                    title.Font = Enum.Font.GothamBold
                    content.TextColor3 = Color3.fromRGB(195, 200, 210)
                    content.Font = Enum.Font.GothamMedium
                end
            -- Only attach carbon overlays to non-paragraph interactive elements
            -- AND skip if this desc is a child of a paragraph frame (to avoid UIListLayout corruption)
            elseif not IsParagraphFrame(desc.Parent) then
                -- Toggle Carbon Background
                if desc:FindFirstChild("Switch") then
                    AttachCarbonOverlay(desc, 0.82)
                end

                -- Button Carbon Weave
                if desc:FindFirstChild("Interact") and not desc:FindFirstChild("Switch") and not desc:FindFirstChild("Slider") then
                    AttachCarbonOverlay(desc, 0.80)
                end

                -- Slider Carbon Weave
                if desc:FindFirstChild("Slider") then
                    AttachCarbonOverlay(desc, 0.82)
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

-- Defer initial DOM patch until UI is completely built by TASFF_UI.lua
task.spawn(function()
    while not (S.UIInitialized or S.ScriptInitialized) do
        task.wait(0.2)
    end
    task.wait(0.2)
    for i = 1, 10 do
        task.wait(0.5)
        if PatchRayfieldDOM() then
            S.ThemePatchDone = true
        end
    end
end)

TASFFEnv.Theme.PatchRayfieldDOM = PatchRayfieldDOM

print("[TASFF Theme v" .. (S.CurrentVersion or "2.3.0") .. "] Theme module and extensions fully loaded.")
