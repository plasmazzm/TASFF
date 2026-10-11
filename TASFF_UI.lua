-- // ============================================================ // --
-- //   TASFF_UI.lua                                             // --
-- //   Rayfield UI â€” structure identical to the original        // --
-- //   monolith. Callbacks write to _G.TASFF_State (S).        // --
-- //   Must be loaded AFTER TASFF_Core.lua.                    // --
-- // ============================================================ // --

local S           = _G.TASFF_State
local TASFFEnv     = (getgenv and getgenv().TASFF) or nil
if not TASFFEnv or not TASFFEnv.Rayfield then
    warn("[TASFF UI] Rayfield not ready — UI skipped.")
    return
end

local function SanitizeKeyName(k)
    if type(k) == "string" and k ~= "" then return k:gsub("Enum%.KeyCode%.", "")
    elseif typeof(k) == "EnumItem" then return k.Name end
    return nil
end
local Rayfield    = TASFFEnv.Rayfield
local Players     = game:GetService("Players")
local Player      = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

-- // â”€â”€ UI-Local Variables â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ // --

local SelectedPresetToManage = ""
local SelectedBlacklistTool  = ""
local BlacklistDropdown      = nil   -- tool weapons registry dropdown
local PriorityDropdownRef    = nil   -- priority players dropdown
local PresetDropdownRef      = nil   -- saved profiles dropdown
local PerformanceIndicator   = nil   -- paragraph element ref
local PriorityMonitorLabel   = nil   -- paragraph element ref
local ThreatListLabel        = nil   -- paragraph element ref
local PresetInputName        = ""

-- // â”€â”€ Theming Color Map â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ // --

local ColorPresetMap = {
    ["Purple"]  = Color3.fromRGB(138, 43,  226),
    ["Cyan"]    = Color3.fromRGB(0,   255, 255),
    ["Red"]     = Color3.fromRGB(255, 0,   0),
    ["Black"]   = Color3.fromRGB(0,   0,   0),
    ["Yellow"]  = Color3.fromRGB(255, 255, 0),
    ["Lime"]    = Color3.fromRGB(0,   255, 0),
    ["Green"]   = Color3.fromRGB(0,   128, 0),
    ["Orange"]  = Color3.fromRGB(255, 165, 0),
    ["White"]   = Color3.fromRGB(255, 255, 255),
    ["Blue"]    = Color3.fromRGB(0,   0,   255),
    ["Brown"]   = Color3.fromRGB(139, 69,  19),
    ["Pink"]    = Color3.fromRGB(255, 192, 203),
    ["Gray"]    = Color3.fromRGB(128, 128, 128),
    ["Maroon"]  = Color3.fromRGB(128, 0,   0),
    ["Tan"]     = Color3.fromRGB(210, 180, 140),
    ["Coral"]   = Color3.fromRGB(255, 127, 80),
    ["Banana"]  = Color3.fromRGB(250, 218, 94),
    ["Rose"]    = Color3.fromRGB(255, 0,   127),
}
local ColorDropdownOptions = {
    "Purple","Cyan","Red","Black","Yellow","Lime","Green","Orange",
    "White","Blue","Brown","Pink","Gray","Maroon","Tan","Coral","Banana","Rose"
}

local ColorFields = {
    "HighlightColor", "FOVColor", "CrosshairColor", "BoxColor", "SkeletonColor",
    "SnaplineColor", "OOFArrowColor", "PriorityHighlightColor", "ThreatHighlightColor",
    "NemesisHighlightColor", "BlacklistedTagColor", "KillFlashColor", "VisibleColor",
    "HiddenColor", "ChamsColor",
}
local ColorFlagMap = {
    HighlightColor = "HighlightColorPicker", FOVColor = "FOVCircleColorPicker",
    CrosshairColor = "CrosshairColorPicker", BoxColor = "BoxESPColorPicker",
    SkeletonColor = "SkeletonESPColorPicker", SnaplineColor = "SnaplineFineColorPicker",
    OOFArrowColor = "OOFArrowColorPicker", PriorityHighlightColor = "PriorityHighlightColorPicker",
    ThreatHighlightColor = "ThreatHighlightColorPicker", NemesisHighlightColor = "NemesisHighlightColorPicker",
    BlacklistedTagColor = "BlacklistedTagColorPicker", KillFlashColor = "KillFlashColorPicker",
    VisibleColor = "VisibleColorPicker", HiddenColor = "HiddenColorPicker", ChamsColor = "ChamsColorPicker",
}

local GlobalThemeOptions = {
    "Ocean", "AmberGlow", "Amethyst", "Green", "Bloom", "DarkBlue", "Serenity",
    "Light", "Cyberpunk", "Crimson Blood", "Emerald Forest", "Solaris Gold",
    "Retro Synth", "Dracula", "Monochrome Void", "Sakura", "Toxic Slime", "Glacier",
}
local selectedGlobalTheme = GlobalThemeOptions[1]
local GlobalThemePalettes = {
    Ocean = {Base="#D8F7FF", Overlay="#38DDF2", Drawing="#49B8D0", Priority="#FF5B6E", Threat="#FF965C", Nemesis="#B991FF", Blacklist="#FFB14A", Chams="#1EB9D4", Combat="#FFF1A8", Visible="#51E6A3", Hidden="#FF647C", UIBackground="#071923", UITopbar="#0D2532", UIAccent="#22D3EE", UIElement="#102D3A", UIText="#E4F7FA"},
    AmberGlow = {Base="#FFF0D6", Overlay="#FFC46B", Drawing="#E5A34A", Priority="#FF5555", Threat="#FF7A32", Nemesis="#C58BFF", Blacklist="#FFD166", Chams="#E58D2B", Combat="#FFF2A6", Visible="#8BE28B", Hidden="#FF6262", UIBackground="#1A1510", UITopbar="#292016", UIAccent="#F5A623", UIElement="#332719", UIText="#FFF1D6"},
    Amethyst = {Base="#F3E8FF", Overlay="#C4A1FF", Drawing="#A67DE8", Priority="#FF667D", Threat="#FF9D66", Nemesis="#E0A8FF", Blacklist="#FFC36E", Chams="#8B5CF6", Combat="#FFE6A6", Visible="#75E6B0", Hidden="#FF6685", UIBackground="#160F20", UITopbar="#21152F", UIAccent="#A855F7", UIElement="#2A1D3B", UIText="#F2E9FF"},
    Green = {Base="#E4FFE7", Overlay="#5CFF77", Drawing="#30D957", Priority="#FF5570", Threat="#FF9A45", Nemesis="#C58BFF", Blacklist="#FFD44D", Chams="#24C94B", Combat="#FFF06A", Visible="#7CFF5B", Hidden="#FF5460", UIBackground="#07140B", UITopbar="#0D2113", UIAccent="#39E75F", UIElement="#142B1A", UIText="#E7FFE9"},
    Bloom = {Base="#FFF1F7", Overlay="#FF91C8", Drawing="#EC91BE", Priority="#E85D75", Threat="#F49A59", Nemesis="#A987DC", Blacklist="#EAAE64", Chams="#D884B5", Combat="#FFE3A6", Visible="#7CCFA3", Hidden="#E66C80", UIBackground="#241923", UITopbar="#32212F", UIAccent="#E88BB9", UIElement="#3B2A38", UIText="#FFF0F6"},
    DarkBlue = {Base="#E2EDFF", Overlay="#5EA6FF", Drawing="#5487D6", Priority="#FF526A", Threat="#FF965C", Nemesis="#B48CFF", Blacklist="#FFC05C", Chams="#3978D6", Combat="#FFE99A", Visible="#59D7AA", Hidden="#FF617A", UIBackground="#08111F", UITopbar="#101D31", UIAccent="#438DFF", UIElement="#162640", UIText="#EAF2FF"},
    Serenity = {Base="#F0F1F6", Overlay="#AAB8D8", Drawing="#8796B5", Priority="#E87583", Threat="#E99A69", Nemesis="#A28BD0", Blacklist="#D6AD72", Chams="#778BAA", Combat="#F0DFA8", Visible="#81C6A7", Hidden="#E87C8C", UIBackground="#171A21", UITopbar="#222731", UIAccent="#8799C0", UIElement="#2B303B", UIText="#EEF0F6"},
    Light = {Base="#20242A", Overlay="#2878D0", Drawing="#51677D", Priority="#C93449", Threat="#D46A28", Nemesis="#7848B8", Blacklist="#B46A16", Chams="#347AB8", Combat="#C18A16", Visible="#178A52", Hidden="#C93449", UIBackground="#F4F5F7", UITopbar="#E5E8ED", UIAccent="#3478C8", UIElement="#FFFFFF", UIText="#20242A"},
    Cyberpunk = {Base="#F8F4FF", Overlay="#00F5FF", Drawing="#00BFCB", Priority="#FF2A8A", Threat="#FF7A18", Nemesis="#C357FF", Blacklist="#FFD400", Chams="#00D9E8", Combat="#FFE600", Visible="#39FF88", Hidden="#FF2A64", UIBackground="#05030A", UITopbar="#100817", UIAccent="#FF2EAA", UIElement="#160D20", UIText="#F8F4FF"},
    ["Crimson Blood"] = {Base="#F6E9EC", Overlay="#F05265", Drawing="#C9374B", Priority="#FF304A", Threat="#FF7A43", Nemesis="#B887D1", Blacklist="#E5A044", Chams="#A8112C", Combat="#FFD2A1", Visible="#63C994", Hidden="#FF3D55", UIBackground="#100609", UITopbar="#1D0A10", UIAccent="#C91E3A", UIElement="#2A1018", UIText="#F6E9EC"},
    ["Emerald Forest"] = {Base="#E8F5E9", Overlay="#63D99A", Drawing="#42B77A", Priority="#FF6675", Threat="#FF9A4D", Nemesis="#B992D6", Blacklist="#E9C46A", Chams="#178A55", Combat="#FFE08A", Visible="#75E6A1", Hidden="#F05B67", UIBackground="#07140F", UITopbar="#10231A", UIAccent="#29A96B", UIElement="#193326", UIText="#E9F6EE"},
    ["Solaris Gold"] = {Base="#FFF5D6", Overlay="#FFD45C", Drawing="#C7A64B", Priority="#FF5965", Threat="#FF8A3D", Nemesis="#BA91D7", Blacklist="#FFE27A", Chams="#C49A36", Combat="#FFF078", Visible="#80D6A1", Hidden="#FF5B61", UIBackground="#100E08", UITopbar="#1D190D", UIAccent="#D5A932", UIElement="#2A2415", UIText="#FFF4D5"},
    ["Retro Synth"] = {Base="#FFF0E4", Overlay="#FF9A56", Drawing="#E47A4C", Priority="#FF4D75", Threat="#FFB04A", Nemesis="#C174E8", Blacklist="#F3D05B", Chams="#D95B77", Combat="#FFE28A", Visible="#62D7A2", Hidden="#FF5870", UIBackground="#160D20", UITopbar="#251332", UIAccent="#FF784F", UIElement="#321C3C", UIText="#FFF0E4"},
    Dracula = {Base="#F8F8F2", Overlay="#BD93F9", Drawing="#A67AE8", Priority="#FF5C7A", Threat="#FF9E64", Nemesis="#D6A7FF", Blacklist="#F1C56B", Chams="#9C6ADE", Combat="#F1FA8C", Visible="#50FA7B", Hidden="#FF5555", UIBackground="#191622", UITopbar="#242133", UIAccent="#BD93F9", UIElement="#302C40", UIText="#F8F8F2"},
    ["Monochrome Void"] = {Base="#FFFFFF", Overlay="#FFFFFF", Drawing="#D0D0D0", Priority="#FFFFFF", Threat="#C4C4C4", Nemesis="#EEEEEE", Blacklist="#AAAAAA", Chams="#BDBDBD", Combat="#FFFFFF", Visible="#F2F2F2", Hidden="#888888", UIBackground="#000000", UITopbar="#080808", UIAccent="#FFFFFF", UIElement="#151515", UIText="#FFFFFF"},
    Sakura = {Base="#FFF0F5", Overlay="#F5A3C7", Drawing="#D77FA8", Priority="#FF547D", Threat="#FF976D", Nemesis="#B58AE0", Blacklist="#E9B45C", Chams="#C96F99", Combat="#FFE2A8", Visible="#71D5A2", Hidden="#F05472", UIBackground="#191419", UITopbar="#261D25", UIAccent="#E98DB4", UIElement="#30262F", UIText="#FFF0F5"},
    ["Toxic Slime"] = {Base="#F1FFD6", Overlay="#B6FF00", Drawing="#83D600", Priority="#FF3D67", Threat="#FF8F20", Nemesis="#C57AFF", Blacklist="#F4ED00", Chams="#66C900", Combat="#F4FF37", Visible="#62FF57", Hidden="#FF3355", UIBackground="#0A1005", UITopbar="#141F08", UIAccent="#A6E600", UIElement="#1E2B0D", UIText="#F2FFD9"},
    Glacier = {Base="#F2FAFF", Overlay="#B8E8FF", Drawing="#86C4E0", Priority="#F06A7C", Threat="#EFA16D", Nemesis="#A995D7", Blacklist="#E1BD78", Chams="#6AAFCB", Combat="#FFF0B0", Visible="#69D6B0", Hidden="#F06A7C", UIBackground="#11191F", UITopbar="#1C2931", UIAccent="#9ADCF5", UIElement="#263640", UIText="#F1FAFF"},
}
local GlobalThemeColorNames = {
    {"White", Color3.fromRGB(255,255,255)}, {"Soft White", Color3.fromRGB(235,240,245)},
    {"Black", Color3.fromRGB(8,8,8)}, {"Gray", Color3.fromRGB(128,128,128)},
    {"Silver", Color3.fromRGB(200,205,215)}, {"Slate", Color3.fromRGB(105,120,140)},
    {"Red", Color3.fromRGB(220,45,65)}, {"Crimson", Color3.fromRGB(160,20,45)},
    {"Orange", Color3.fromRGB(240,125,45)}, {"Amber", Color3.fromRGB(230,165,45)},
    {"Gold", Color3.fromRGB(210,175,65)}, {"Yellow", Color3.fromRGB(240,225,70)},
    {"Green", Color3.fromRGB(45,175,90)}, {"Emerald", Color3.fromRGB(35,145,100)},
    {"Lime", Color3.fromRGB(155,220,45)}, {"Cyan", Color3.fromRGB(45,200,220)},
    {"Ice Blue", Color3.fromRGB(145,215,245)}, {"Blue", Color3.fromRGB(55,125,220)},
    {"Navy", Color3.fromRGB(25,45,90)}, {"Teal", Color3.fromRGB(40,145,150)},
    {"Purple", Color3.fromRGB(130,75,190)}, {"Violet", Color3.fromRGB(155,80,220)},
    {"Lavender", Color3.fromRGB(185,155,225)}, {"Pink", Color3.fromRGB(230,135,180)},
    {"Hot Pink", Color3.fromRGB(245,55,150)},
}
local GlobalThemeColorFields = {
    {title="Default Highlight & Tags", field="HighlightColor", role="Base"},
    {title="FOV Circle", field="FOVColor", role="Overlay"},
    {title="Crosshair", field="CrosshairColor", role="Overlay"},
    {title="Box ESP", field="BoxColor", role="Drawing"},
    {title="Skeleton ESP", field="SkeletonColor", role="Drawing"},
    {title="Snaplines", field="SnaplineColor", role="Drawing"},
    {title="Off-Screen Arrows", field="OOFArrowColor", role="Drawing"},
    {title="Priority Players", field="PriorityHighlightColor", role="Priority"},
    {title="Threat Players", field="ThreatHighlightColor", role="Threat"},
    {title="Nemesis Players", field="NemesisHighlightColor", role="Nemesis"},
    {title="Blacklisted Players", field="BlacklistedTagColor", role="Blacklist"},
    {title="Chams", field="ChamsColor", role="Chams"},
    {title="Kill Flash", field="KillFlashColor", role="Combat"},
    {title="Visible Target", field="VisibleColor", role="Visible"},
    {title="Hidden Target", field="HiddenColor", role="Hidden"},
    {title="UI Background", themeField="Background", role="UIBackground"},
    {title="UI Topbar", themeField="Topbar", role="UITopbar"},
    {title="UI Selected Accent", themeField="TabBackgroundSelected", role="UIAccent"},
    {title="UI Element Background", themeField="ElementBackground", role="UIElement"},
    {title="UI Text", themeField="TextColor", role="UIText"},
}
local PersistedColorValues = {}

local ThemeColorDefaults = {
    Background = Color3.fromRGB(15, 15, 15),
    Topbar = Color3.fromRGB(20, 20, 20),
    TabBackgroundSelected = Color3.fromRGB(180, 40, 40),
    ElementBackground = Color3.fromRGB(25, 25, 25),
    TextColor = Color3.fromRGB(240, 240, 240),
}
local ThemeColors = table.clone(ThemeColorDefaults)

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

local function GetPresetNamesList()
    local t = {}
    for k, _ in pairs(S.SavedPresets) do table.insert(t, k) end
    return #t > 0 and t or {"No Profiles Found"}
end

-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                          WINDOW                              // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

local Window = Rayfield:CreateWindow({
    Name            = "TASFF 2.1.0 " .. selectedGlobalTheme,
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
        FolderName = "TASFF V2.1.0",
        FileName   = "MainConfig"
    }
})


-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                        1. COMBAT TAB                         // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

-- // ── HOME TAB ────────────────────────────────────────────────── // --

local HomeTab = Window:CreateTab("Home", "home")

HomeTab:CreateSection("Welcome")
HomeTab:CreateParagraph({
    Title   = "TASFF v2.1.0 — The Aimbot Script Final Form",
    Content = "Welcome back, " .. (Player and Player.DisplayName or "operator") .. ".\n"
           .. "Total features available: " .. tostring(S.FeatureCount > 0 and S.FeatureCount or "...") .. "\n"
           .. "Controls: " .. tostring(S.ToggleCount or 64) .. " Toggles | " .. tostring(S.SliderCount or 27) .. " Sliders | " .. tostring(S.DropdownCount or 27) .. " Dropdowns | " .. tostring(S.ButtonCount or 0) .. " Buttons\n"
           .. "Engine: 4-Slot Pipeline  |  Modules: State · Lists · Core · UI"
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
                Title   = "Game Server",
                Content = string.format(
                    "Game    : %s\nPlace   : %d\nJob     : %s...\nPlayers : %d / %d",
                    gameName, game.PlaceId, serverId, playerCount, maxPlayers
                )
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
    Title   = "How to Read",
    Content = "Select a category from the dropdown below. Enabled features appear first (✔), then disabled (✘). Changes made in other tabs are reflected on next category switch."
})

local function BuildStatusContent(category)
    local on, off = {}, {}
    local function check(label, flag)
        if flag then table.insert(on, "  \xE2\x9C\x94 " .. label)
        else table.insert(off, "  \xE2\x9C\x98 " .. label) end
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
    elseif category == "Visuals" then
        check("Highlights (Players)",   S.UseHighlight)
        check("Highlights (NPCs)",      S.UseNPCHighlight)
        check("Info Tags (Players)",    S.UseInfoTag)
        check("Info Tags (NPCs)",       S.UseNPCInfoTag)
        check("Snaplines",              S.SnaplinesEnabled)
        check("OOF Arrows",             S.OOFArrowsEnabled)
        check("Box ESP",                S.BoxModeEnabled)
        check("Skeleton ESP",           S.SkeletonModeEnabled)
        check("Chams",                  S.ChamsEnabled)
        check("Visibility Colors",      S.VisibilityColorsEnabled)
        check("Show Display Name",      S.ShowDisplayName)
        check("Show Tool Check",        S.ShowToolCheck)
    elseif category == "Intel" then
        check("Threat Detector",        S.ThreatDetectorEnabled)
        check("Nemesis System",         S.NemesisEnabled)
        check("Click-to-Mark",          S.ClickToMarkEnabled)
        check("Focus Mode ESP",         S.FocusMode)
        check("Wall Check",             S.WallCheck)
        check("Team Check",             S.TeamCheck)
        check("Target Players",         S.TargetPlayers)
        check("Target NPCs",            S.TargetNPCs)
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

-- // ── COMBAT TAB ──────────────────────────────────────────────── // --

local MainTab = Window:CreateTab("Combat", "crosshair")



MainTab:CreateSection("Command & Control")
MainTab:CreateParagraph({
    Title   = "TASFF â€” The Aimbot Script Final Form",
    Content = "The definitive combat suite. Master Switch is the global killswitch â€” nothing runs while it's off. Aimbot Engine controls active target acquisition and tracking independently."
})
MainTab:CreateToggle({Name = "Master Switch (Killswitch)", CurrentValue = S.MasterEnabled, Flag = "MasterSwitch", Callback = function(v)
    S.MasterEnabled = v
    if not v then
        S.AimbotActive = false; S.CurrentTarget = nil; S.AimbotCandidates = {}
        if S.SetADSState    then S.SetADSState(false)  end
        if S.ClearVisuals   then S.ClearVisuals()      end
        if S.ClearCrosshair then S.ClearCrosshair()    end
        if S.FOVCircle      then S.FOVCircle.Visible = false end
    end
end})
MainTab:CreateToggle({Name = "Enable Aimbot Engine", CurrentValue = S.TargetingEnabled, Flag = "TargetSystemToggle", Callback = function(v)
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
    Callback      = function(v) S.Mode = v[1] end
})

MainTab:CreateSection("Activation & Automation")
MainTab:CreateKeybind({
        Name            = "Aimbot Activation Key",
        CurrentKeybind  = S.AimbotKeybind or "E",
        Flag            = "AimbotKeybind",
        Callback        = function(key)
            local validKey = SanitizeKeyName(key)
            local isRebind = (validKey ~= nil and validKey ~= S.AimbotKeybind)
            if validKey then S.AimbotKeybind = validKey end
            if not isRebind and S.MasterEnabled and not S.PanicLocked then
            S.AimbotActive = not S.AimbotActive
            if not S.AimbotActive then
                S.CurrentTarget = nil
                S.AimbotCandidates = {}
                S.SilentAimTargetCache = nil
                S.LastCustomTargetData = nil
                S.SilentAimTargetCacheTime = 0
                if S.SetADSState then S.SetADSState(false) end
            end
        end
    end
})
MainTab:CreateToggle({Name = "Auto ADS (Automatic Scope)", CurrentValue = S.AutoADSEnabled, Flag = "AutoADS", Callback = function(v)
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

MainTab:CreateSection("Target Selection & Sorting")
MainTab:CreateDropdown({
    Name          = "Primary Hitbox (Bodypart)",
    Options       = {"Head", "HumanoidRootPart", "Torso", "Visible On Screen"},
    CurrentOption = {S.TargetPart},
    Flag          = "TargetPart",
    Callback      = function(v) S.TargetPart = v[1]; S.ActivePartName = v[1] end
})
MainTab:CreateToggle({Name = "Randomize Hitboxes (Legit Variance)", CurrentValue = S.RandomizeHitboxEnabled, Flag = "RandomizeHitbox", Callback = function(v)
    S.RandomizeHitboxEnabled = v
end})
MainTab:CreateDropdown({Name = "Distance Sorting", Options = {"None", "Closest", "Farthest"}, CurrentOption = {S.PriorityMode}, Flag = "PriorityMode", Callback = function(v)
    S.PriorityMode = v[1]
end})
MainTab:CreateDropdown({Name = "Health Sorting", Options = {"None", "Weakest (HP)", "Strongest (HP)"}, CurrentOption = {S.VitalityMode}, Flag = "VitalityMode", Callback = function(v)
    S.VitalityMode = v[1]
end})
MainTab:CreateToggle({Name = "Prioritize Targets Near Screen Center", CurrentValue = S.TargetNearCenter, Flag = "TargetNearCenter", Callback = function(v)
    S.TargetNearCenter = v
end})
MainTab:CreateSlider({Name = "Maximum Acquisition Range (Studs)", Range = {100, 1000}, Increment = 25, CurrentValue = S.AimbotRenderDistance, Flag = "AimbotRenderDist", Callback = function(v)
    S.AimbotRenderDistance = v
end})
MainTab:CreateToggle({Name = "Enable Health Threshold Gate", CurrentValue = S.HealthThresholdEnabled, Flag = "HealthThresholdEnabled", Callback = function(v) S.HealthThresholdEnabled = v end})
MainTab:CreateSlider({Name = "Minimum Target HP to Engage (%)", Range = {0, 100}, Increment = 1, CurrentValue = S.HealthThreshold or 0, Flag = "HealthThreshold", Callback = function(v) S.HealthThreshold = v end})

MainTab:CreateSection("Smoothing & Prediction")
MainTab:CreateSlider({Name = "Tracking Smoothness (Legit/Camera)", Range = {0.1, 5}, Increment = 0.1, CurrentValue = S.Smoothness, Flag = "SmoothSpeed", Callback = function(v)
    S.Smoothness = v
end})
MainTab:CreateSlider({Name = "Advanced Legit Smoothness X (Horizontal)", Range = {0.1, 5}, Increment = 0.1, CurrentValue = S.SmoothnessX, Flag = "SmoothnessX", Callback = function(v)
    S.SmoothnessX = v
end})
MainTab:CreateSlider({Name = "Advanced Legit Smoothness Y (Vertical)", Range = {0.1, 5}, Increment = 0.1, CurrentValue = S.SmoothnessY, Flag = "SmoothnessY", Callback = function(v)
    S.SmoothnessY = v
end})
MainTab:CreateSlider({Name = "Blatant Snap Speed (100 = Instant)", Range = {5, 100}, Increment = 5, CurrentValue = S.BlatantSnapSpeed, Flag = "BlatantSnapSpeed", Callback = function(v)
    S.BlatantSnapSpeed = v
end})
MainTab:CreateSlider({Name = "Velocity Prediction Intensity", Range = {0, 0.5}, Increment = 0.01, CurrentValue = S.PredictionAmount, Flag = "PredIntense", Callback = function(v)
    S.PredictionAmount = v
end})
MainTab:CreateToggle({Name = "Dynamic Recoil Control (DRC)", CurrentValue = S.DynamicRecoilEnabled, Flag = "DynamicRecoil", Callback = function(v)
    S.DynamicRecoilEnabled = v
end})



MainTab:CreateSection("Advanced Engagement Logic")
MainTab:CreateToggle({Name = "Universal Silent Aim (Magic Bullet)", CurrentValue = S.SilentAimEnabled, Flag = "SilentAimEnabled", Callback = function(v)
    S.SilentAimEnabled = v
    if S.Notify then
        S.Notify({Title = "Silent Aim", Content = v and "Silent Aim enabled." or "Silent Aim disabled.", Duration = 2, Image = v and "crosshair" or "x"})
    end
end})
MainTab:CreateToggle({Name = "Sticky Aim (Target Lock Retention)", CurrentValue = S.StickyAimEnabled, Flag = "StickyAim", Callback = function(v)
    S.StickyAimEnabled = v
    if not v then S.CurrentTarget = nil end
end})
MainTab:CreateToggle({Name = "Target Switch Delay (After Target Disappears)", CurrentValue = S.TargetSwitchDelayEnabled, Flag = "TargetSwitchDelay", Callback = function(v)
    S.TargetSwitchDelayEnabled = v
end})
MainTab:CreateSlider({Name = "Target-Loss Delay Duration (ms)", Range = {50, 1000}, Increment = 10, CurrentValue = S.SwitchDelayMs, Flag = "SwitchDelayMs", Callback = function(v)
    S.SwitchDelayMs = v
end})
MainTab:CreateToggle({Name = "Target Grace Period (Anti-Jitter)", CurrentValue = S.GracePeriodEnabled, Flag = "EnableGracePeriod", Callback = function(v)
    S.GracePeriodEnabled = v
end})
MainTab:CreateSlider({Name = "Grace Period Delay (ms)", Range = {1, 1000}, Increment = 1, CurrentValue = S.GracePeriodMs, Flag = "GracePeriodMs", Callback = function(v)
    S.GracePeriodMs = v
end})

-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                       2. VISUALS TAB                         // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

local VisualTab = Window:CreateTab("Visuals", "eye")

VisualTab:CreateSection("Global ESP Configurations")
VisualTab:CreateParagraph({
    Title   = "Focus Mode & Visual Rendering",
    Content = "Focus Mode isolates visual clutter by only drawing ESP on Priority Targets. Screen overlay tags use PlayerGui and are visible to Roblox's built-in recording. 3D chams use Roblox Highlight instances and may also appear in recordings and capture software."
})
VisualTab:CreateDropdown({Name = "ESP Target Mode", Options = {"Single", "Multiple", "All"}, CurrentOption = {S.VisualMode}, Flag = "VisualMode", Callback = function(v)
    S.VisualMode = type(v) == "table" and v[1] or v
    if S.ClearVisuals then S.ClearVisuals() end
end})
VisualTab:CreateToggle({Name = "Render Player ESP", CurrentValue = S.UseHighlight, Flag = "UseHighlight", Callback = function(v) S.UseHighlight = v end})
VisualTab:CreateToggle({Name = "Render NPC ESP", CurrentValue = S.UseNPCHighlight, Flag = "UseNPCHighlight", Callback = function(v) S.UseNPCHighlight = v end})
VisualTab:CreateToggle({Name = "Focus Mode (Isolate Priority Targets)", CurrentValue = S.FocusMode, Flag = "FocusMode", Callback = function(v) S.FocusMode = v end})
VisualTab:CreateToggle({Name = "Use Screen Overlay Tags", CurrentValue = S.StreamProofESP, Flag = "StreamProofESP", Callback = function(v)
    S.StreamProofESP = v
    if S.ClearVisuals then S.ClearVisuals() end
end})
VisualTab:CreateToggle({Name = "Dynamic Visibility Colors (Green/Red)", CurrentValue = S.VisibilityColorsEnabled, Flag = "VisibilityColorsEnabled", Callback = function(v)
    S.VisibilityColorsEnabled = v
end})
VisualTab:CreateSlider({Name = "Maximum ESP Distance (Studs)", Range = {100, 1000}, Increment = 25, CurrentValue = S.ESPRenderDistance, Flag = "ESPRenderDist", Callback = function(v)
    S.ESPRenderDistance = v
end})

VisualTab:CreateSection("Tactical Overlays (Geometries)")
VisualTab:CreateToggle({Name = "3D Chams (Roblox Highlight)", CurrentValue = S.ChamsEnabled, Flag = "EnableChamsMode", Callback = function(v) S.ChamsEnabled = v end})

VisualTab:CreateToggle({Name = "2D Bounding Boxes", CurrentValue = S.BoxModeEnabled, Flag = "EnableBoxMode", Callback = function(v) S.BoxModeEnabled = v end})
VisualTab:CreateToggle({Name = "Skeletal Mapping (R6/R15)", CurrentValue = S.SkeletonModeEnabled, Flag = "EnableSkeletonMode", Callback = function(v) S.SkeletonModeEnabled = v end})
VisualTab:CreateToggle({Name = "Distance Snaplines", CurrentValue = S.SnaplinesEnabled, Flag = "SnaplinesEnabled", Callback = function(v) S.SnaplinesEnabled = v end})
VisualTab:CreateDropdown({Name = "Snapline Origin Point", Options = {"Bottom", "Center"}, CurrentOption = {S.SnaplineOrigin}, Flag = "SnaplineOrigin", Callback = function(v)
    S.SnaplineOrigin = v[1]
end})
VisualTab:CreateToggle({Name = "Off-Screen Indicators (OOF Arrows)", CurrentValue = S.OOFArrowsEnabled, Flag = "OOFArrowsEnabled", Callback = function(v) S.OOFArrowsEnabled = v end})
VisualTab:CreateSlider({Name = "OOF Indicator Radius", Range = {50, 400}, Increment = 10, CurrentValue = S.OOFArrowRadius, Flag = "OOFArrowRadius", Callback = function(v) S.OOFArrowRadius = v end})

VisualTab:CreateSection("Target Intelligence Tags")
VisualTab:CreateToggle({Name = "Render Player Tags", CurrentValue = S.UseInfoTag, Flag = "UseInfoTag", Callback = function(v) S.UseInfoTag = v end})
VisualTab:CreateToggle({Name = "Render NPC Tags", CurrentValue = S.UseNPCInfoTag, Flag = "UseNPCInfoTag", Callback = function(v) S.UseNPCInfoTag = v end})
VisualTab:CreateToggle({Name = "Use Display Names (vs Usernames)", CurrentValue = S.ShowDisplayName, Flag = "ShowDisplay", Callback = function(v) S.ShowDisplayName = v end})
VisualTab:CreateToggle({Name = "Display Equipped Weapon/Tool", CurrentValue = S.ShowToolCheck, Flag = "UseToolCheck", Callback = function(v) S.ShowToolCheck = v end})
VisualTab:CreateToggle({Name = "Show [LOCKED] / [SILENT] on Tag", CurrentValue = S.ShowLockIndicators, Flag = "ShowLockIndicators", Callback = function(v) S.ShowLockIndicators = v end})
VisualTab:CreateToggle({Name = "Kill Confirmation Flash (Custom Color)", CurrentValue = S.KillConfirmFlashEnabled, Flag = "KillConfirmFlash", Callback = function(v) S.KillConfirmFlashEnabled = v end})
VisualTab:CreateSlider({Name = "Kill Flash Fade Duration", Range = {0.1, 3.0}, Increment = 0.1, CurrentValue = S.KillFlashDuration or 0.8, Flag = "KillFlashDuration", Callback = function(v) S.KillFlashDuration = v end})

VisualTab:CreateSection("Heads-Up Display (HUD)")
VisualTab:CreateParagraph({
    Title   = "Invisible FOV",
    Content = "The Invisible FOV toggle allows your aimbot to strictly respect the FOV boundary limit without actually drawing the circle on your screen."
})
VisualTab:CreateToggle({Name = "Render FOV Boundary (Circle)", CurrentValue = S.ShowFOV, Flag = "ShowFOV", Callback = function(v)
    S.ShowFOV = v
    if not v and S.FOVCircle then S.FOVCircle.Visible = false end
end})
VisualTab:CreateToggle({Name = "Invisible FOV Constraint", CurrentValue = S.InvisibleFOV, Flag = "InvisibleFOV", Callback = function(v) S.InvisibleFOV = v end})
VisualTab:CreateSlider({Name = "FOV Boundary Radius", Range = {30, 600}, Increment = 5, CurrentValue = S.FOVSize, Flag = "FOVSize", Callback = function(v) S.FOVSize = v end})
VisualTab:CreateToggle({Name = "Dynamic FOV Auto-Scale by Distance", CurrentValue = S.DynamicFOVEnabled, Flag = "DynamicFOVEnabled", Callback = function(v) S.DynamicFOVEnabled = v end})
VisualTab:CreateParagraph({
    Title   = "Dynamic FOV Scaling",
    Content = "When enabled, the FOV radius scales inversely with target distance: it grows as the target gets closer and shrinks as the target moves farther away. The configured radius is the scale at 100 studs; Dynamic FOV Max Radius caps the close-range size."
})
VisualTab:CreateSlider({Name = "Dynamic FOV Max Radius", Range = {30, 1000}, Increment = 10, CurrentValue = S.DynamicFOVMax or 400, Flag = "DynamicFOVMax", Callback = function(v) S.DynamicFOVMax = v end})
VisualTab:CreateDropdown({
    Name          = "FOV Tracking Origin",
    Options       = {"Screen Center", "Mouse Tracking"},
    CurrentOption = {S.AimReferenceMode},
    Flag          = "AimReferenceMode",
    Callback      = function(v) S.AimReferenceMode = v[1] end
})
VisualTab:CreateToggle({Name = "Render Vector Crosshair", CurrentValue = S.EnableCrosshair, Flag = "UseCrosshair", Callback = function(v)
    S.EnableCrosshair = v
    if not v and S.ClearCrosshair then S.ClearCrosshair() end
end})
VisualTab:CreateDropdown({Name = "Vector Crosshair Style", Options = {"Plus", "Square", "Circle"}, CurrentOption = {S.CrosshairStyle}, Flag = "CrossStyle", Callback = function(v)
    S.CrosshairStyle = type(v) == "table" and v[1] or v
    if S.ClearCrosshair then S.ClearCrosshair() end
end})
VisualTab:CreateSlider({Name = "Vector Crosshair Size", Range = {2, 50}, Increment = 1, CurrentValue = S.CrosshairSize, Flag = "CrossSize", Callback = function(v) S.CrosshairSize = v end})

VisualTab:CreateSection("Display Calibration")
VisualTab:CreateToggle({Name = "Enable Manual Axis Calibration", CurrentValue = S.ManualCalibrationEnabled, Flag = "EnableCalibration", Callback = function(v) S.ManualCalibrationEnabled = v end})
VisualTab:CreateSlider({Name = "Horizontal Axis Offset (Pixels)", Range = {-200, 200}, Increment = 1, CurrentValue = S.CalibrationOffsetX, Flag = "CalibrationX", Callback = function(v) S.CalibrationOffsetX = v end})
VisualTab:CreateSlider({Name = "Vertical Axis Offset (Pixels)", Range = {-200, 200}, Increment = 1, CurrentValue = S.CalibrationOffsetY, Flag = "CalibrationY", Callback = function(v) S.CalibrationOffsetY = v end})

-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                      3. TRIGGERBOT TAB                       // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

local TriggerbotTab = Window:CreateTab("Triggerbot", "mouse-pointer-click")

TriggerbotTab:CreateSection("Primary Trigger (Mouse)")
TriggerbotTab:CreateParagraph({
    Title   = "Simulation Engine & 3D Tracking",
    Content = "Virtual: Emulates driver-level mouse events.\nPhysical: Hooks into native executor click functions.\n3rd Person Tracking: Fires at the target's exact screen coordinate instead of center screen."
})
TriggerbotTab:CreateToggle({Name = "Enable Mouse Triggerbot", CurrentValue = S.AutoClickEnabled, Flag = "EnableTriggerbot", Callback = function(v)
    S.AutoClickEnabled = v
    if not v and S.IsHoldingClick then
        S.IsHoldingClick = false
        game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end
end})
TriggerbotTab:CreateDropdown({Name = "Click Simulation Engine", Options = {"Virtual", "Physical"}, CurrentOption = {S.TriggerbotClickMode}, Flag = "TriggerbotClickMode", Callback = function(v)
    S.TriggerbotClickMode = v[1]
end})
TriggerbotTab:CreateDropdown({Name = "Action Method", Options = {"Mash", "Hold"}, CurrentOption = {S.ClickMethod}, Flag = "ClickMethod", Callback = function(v)
    S.ClickMethod = v[1]
end})
TriggerbotTab:CreateSlider({Name = "Mash Interval (ms)", Range = {1, 1000}, Increment = 1, CurrentValue = S.ClickInterval, Flag = "ClickInterval", Callback = function(v)
    S.ClickInterval = v
end})
TriggerbotTab:CreateToggle({Name = "3rd Person Spatial Tracking", CurrentValue = S.ThirdPersonTriggerbot, Flag = "ThirdPersonTriggerbot", Callback = function(v)
    S.ThirdPersonTriggerbot = v
end})

TriggerbotTab:CreateSection("Secondary Trigger (Keybinds)")
TriggerbotTab:CreateParagraph({
    Title   = "Key Triggerbot",
    Content = "Automatically executes a custom keystroke (e.g., casting an ability, dashing, or swinging a sword) when the aimbot locks onto a valid target."
})
TriggerbotTab:CreateToggle({Name = "Enable Key Triggerbot", CurrentValue = S.KeyTriggerbotEnabled, Flag = "KeyTriggerbotToggle", Callback = function(v)
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
TriggerbotTab:CreateDropdown({Name = "Key Action Method", Options = {"Single Press", "Mash", "Hold"}, CurrentOption = {S.KeyTriggerMode}, Flag = "KeyTriggerMode", Callback = function(v)
    S.KeyTriggerMode = v[1]
end})

TriggerbotTab:CreateSection("Proximity Auto-Melee")
TriggerbotTab:CreateToggle({Name = "Enable Proximity Auto-Melee", CurrentValue = S.MeleeModeEnabled, Flag = "EnableMeleeMode", Callback = function(v) S.MeleeModeEnabled = v end})
TriggerbotTab:CreateSlider({Name = "Melee Engagement Range (Studs)", Range = {1, 10}, Increment = 1, CurrentValue = S.MeleeDetectionRange, Flag = "MeleeRange", Callback = function(v)
    S.MeleeDetectionRange = v
end})
TriggerbotTab:CreateSlider({Name = "Melee Strike Interval (ms)", Range = {1, 1000}, Increment = 1, CurrentValue = S.MeleeClickInterval, Flag = "MeleeClickInterval", Callback = function(v)
    S.MeleeClickInterval = v
end})

-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                       4. ADVANCED TAB                        // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --


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
        for name, data in pairs(S.IntelPlayers) do
            if not data.nemesis then
                S.IntelPlayers[name] = nil
                S.ThreatMemory[name] = nil
                local idx = table.find(S.PriorityPlayers, name)
                if idx then table.remove(S.PriorityPlayers, idx) end
            end
        end
        S.IntelSelected = ""
        if S.SyncPriorityUI then S.SyncPriorityUI() end
        if S.RebuildIntelMonitor then S.RebuildIntelMonitor() end
        if S.Notify then S.Notify({Title="Intel",Content="Cleared all non-Nemesis entries.",Duration=2,Image="trash-2"}) end
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
        local val = type(v) == "table" and v[1] or v
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
IntelTab:CreateToggle({Name = "Enable Live Kill Feed Notifications", CurrentValue = S.KillFeedEnabled, Flag = "KillFeedEnabled", Callback = function(v)
    S.KillFeedEnabled = v
end})
IntelTab:CreateToggle({Name = "Enable Kill-Count Threat Auto-Flag", CurrentValue = S.KillCountThreatEnabled, Flag = "KillCountThreat", Callback = function(v)
    S.KillCountThreatEnabled = v
end})
IntelTab:CreateSlider({Name = "Kills Before Threat Flag", Range = {1, 10}, Increment = 1, CurrentValue = S.KillsBeforeThreat, Flag = "KillsBeforeThreat", Callback = function(v)
    S.KillsBeforeThreat = v
end})
IntelTab:CreateToggle({Name = "Enable Threat Detector (Damage Tracking)", CurrentValue = S.ThreatDetectorEnabled, Flag = "ThreatDetector", Callback = function(v)
    S.ThreatDetectorEnabled = v
end})
IntelTab:CreateToggle({Name = "Threat Neutralization (Auto-expire on kill)", CurrentValue = S.ThreatNeutralizationEnabled, Flag = "ThreatNeutralization", Callback = function(v)
    S.ThreatNeutralizationEnabled = v
end})
IntelTab:CreateSlider({Name = "Threat Memory Expiration (Seconds)", Range = {1, 60}, Increment = 1, CurrentValue = S.ThreatTimeout, Flag = "ThreatTimeout", Callback = function(v)
    S.ThreatTimeout = v
end})
IntelTab:CreateSlider({Name = "Proximity Threat Radius (Studs)", Range = {20, 200}, Increment = 10, CurrentValue = S.ThreatProximityRadius or 80, Flag = "ThreatProximityRadius", Callback = function(v) S.ThreatProximityRadius = v end})
IntelTab:CreateSlider({Name = "False Positive Cooldown (Seconds)", Range = {0.5, 10}, Increment = 0.5, CurrentValue = S.ThreatFPCooldown or 1.5, Flag = "ThreatFPCooldown", Callback = function(v) S.ThreatFPCooldown = v end})
IntelTab:CreateToggle({Name = "Auto-Blacklist Expired Threats", CurrentValue = S.BlacklistExpiredThreats, Flag = "BlacklistExpiredThreats", Callback = function(v)
    S.BlacklistExpiredThreats = v
end})
IntelTab:CreateToggle({Name = "Auto-Expire Tracked Players on Disconnect", CurrentValue = S.AutoExpireOnDisconnect, Flag = "AutoExpireOnDisconnect", Callback = function(v)
    S.AutoExpireOnDisconnect = v
end})

IntelTab:CreateSection("Nemesis System")
IntelTab:CreateToggle({Name = "Enable Nemesis System (Death Tracking)", CurrentValue = S.NemesisEnabled, Flag = "NemesisEnabled", Callback = function(v)
    S.NemesisEnabled = v
end})
IntelTab:CreateSlider({Name = "Strikes Before Nemesis Flag", Range = {1, 10}, Increment = 1, CurrentValue = S.KillsBeforeNemesis, Flag = "KillsBeforeNemesis", Callback = function(v)
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

IntelTab:CreateSection("Spectator Mode")
local SpectateDropdown = IntelTab:CreateDropdown({
    Name            = "Spectate Target",
    Options         = S.GetPlayerNames and S.GetPlayerNames() or {},
    CurrentOption   = {S.SpectateTarget or ""},
    MultipleOptions = false,
    Flag            = "SpectateTargetDropdown",
    Callback        = function(v)
        local val = type(v) == "table" and v[1] or v
        S.SpectateTarget = val
    end
})
local SpectateToggle = IntelTab:CreateToggle({Name = "Spectate Player", CurrentValue = S.SpectatePlayerEnabled, Flag = "SpectatePlayer", Callback = function(v)
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
IntelTab:CreateToggle({Name = "Enable Target Marking", CurrentValue = S.ClickToMarkEnabled, Flag = "ClickToMark", Callback = function(v) S.ClickToMarkEnabled = v end})
IntelTab:CreateDropdown({Name = "Mark Activation Input", Options = {"Mouse Click Only", "Keybind Only", "Both"}, CurrentOption = {S.MarkMethod}, Flag = "MarkMethod", Callback = function(v)
    S.MarkMethod = type(v) == "table" and v[1] or v
end})
IntelTab:CreateKeybind({
    Name           = "Target Mark Keybind",
    CurrentKeybind = S.MarkKeybind or "T",
    Flag           = "MarkKeybind",
    Callback       = function(key)
        local validKey = SanitizeKeyName(key)
        local isRebind = (validKey ~= nil and validKey ~= S.MarkKeybind)
        if validKey then S.MarkKeybind = validKey end
        if not isRebind and S.ClickToMarkEnabled and (S.MarkMethod == "Keybind Only" or S.MarkMethod == "Both") then
            if S.MasterEnabled and S.AimbotActive and S.CurrentTarget ~= nil then return end
            local toolEquipped = Player.Character and Player.Character:FindFirstChildOfClass("Tool") ~= nil
            if toolEquipped then return end
            if S.HandleClickToMark then S.HandleClickToMark() end
        end
    end
})
IntelTab:CreateToggle({Name = "Focus Mode (Visual ESP Only on Priority Targets)", CurrentValue = S.FocusMode, Flag = "FocusMode", Callback = function(v)
    S.FocusMode = v
end})


local AdvancedTab = Window:CreateTab("Advanced", "cpu")

AdvancedTab:CreateSection("Target Marking (Legacy - See Intel Tab)")
-- (Mark/Priority controls moved to Intel tab)


AdvancedTab:CreateSection("Environment Penetration (Wallchecks)")
AdvancedTab:CreateToggle({Name = "Enforce Line of Sight (Wallcheck)", CurrentValue = S.WallCheck, Flag = "WallCheck", Callback = function(v) S.WallCheck = v end})
AdvancedTab:CreateToggle({Name = "Ignore Non-Collidable Objects (CanCollide = False)", CurrentValue = S.NoCollisionCheck, Flag = "NoCollisionCheck", Callback = function(v) S.NoCollisionCheck = v end})
AdvancedTab:CreateToggle({Name = "Ignore Transparent Objects (Glass/Tint)", CurrentValue = S.TransparencyCheck, Flag = "TransparencyCheck", Callback = function(v) S.TransparencyCheck = v end})
AdvancedTab:CreateSlider({Name = "Minimum Transparency Threshold", Range = {0.01, 1.0}, Increment = 0.05, CurrentValue = S.TransparencyThreshold, Flag = "TransparencyThreshold", Callback = function(v)
    S.TransparencyThreshold = v
end})
AdvancedTab:CreateToggle({Name = "Ignore Decals & Textures", CurrentValue = S.DecalsCheck, Flag = "DecalsCheck", Callback = function(v) S.DecalsCheck = v end})

-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                       5. SETTINGS TAB                        // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

local SettingsTab = Window:CreateTab("Settings", "filter")

SettingsTab:CreateSection("Entity & Team Filtering")
SettingsTab:CreateToggle({Name = "Target Players", CurrentValue = S.TargetPlayers, Flag = "TargetPlayers", Callback = function(v) S.TargetPlayers = v end})
SettingsTab:CreateToggle({Name = "Target NPCs (Mob/AI Support)", CurrentValue = S.TargetNPCs, Flag = "TargetNPCs", Callback = function(v) S.TargetNPCs = v end})
SettingsTab:CreateToggle({Name = "Enforce Team Check (Ignore Teammates)", CurrentValue = S.TeamCheck, Flag = "TeamCheck", Callback = function(v) S.TeamCheck = v end})


SettingsTab:CreateSection("Player Management Registry")
SettingsTab:CreateParagraph({
    Title   = "Blacklist & Priority",
    Content = "Blacklisted players are ignored by all targeting. Priority targets and Intel system controls have moved to the Intel tab."
})
SettingsTab:CreateDropdown({
    Name            = "Blacklist Registry (Ignored)",
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
    Name         = "Enable ESP Whitelist Filter",
    CurrentValue = S.ESPWhitelistEnabled,
    Flag         = "ESPWhitelistEnabled",
    Callback     = function(v) S.ESPWhitelistEnabled = v end
})
SettingsTab:CreateDropdown({
    Name            = "ESP Whitelist Registry (Only target & show these)",
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


SettingsTab:CreateSection("Weapon & Inventory Automation")
SettingsTab:CreateParagraph({
    Title   = "Smart Tool Management",
    Content = "Automatically toggle the aimbot based on what you are holding. Blacklist non-weapons (like food or potions) to prevent the aimbot from locking on while you are healing."
})
SettingsTab:CreateToggle({Name = "Auto-Engage Aimbot on Weapon Equip", CurrentValue = S.AutoEnableOnEquip, Flag = "AutoEquipAim", Callback = function(v)
    S.AutoEnableOnEquip = v
end})
SettingsTab:CreateToggle({Name = "Auto-Disable Aimbot on Death", CurrentValue = S.AutoDisableOnDeath, Flag = "AutoDisableOnDeath", Callback = function(v)
    S.AutoDisableOnDeath = v
end})
SettingsTab:CreateToggle({
    Name         = "Intelligent Equip Filter (Keyword Classifier)",
    CurrentValue = S.IntelligentEquipFilter,
    Flag         = "IntelligentEquipFilter",
    Callback     = function(v)
        S.IntelligentEquipFilter = v
        if S.Notify then S.Notify({Title="TASFF Intel",Content=v and "Equip filter ON — non-weapons will not trigger aimbot." or "Equip filter OFF — all tools trigger aimbot.",Duration=2,Image="cpu"}) end
    end
})
SettingsTab:CreateToggle({
    Name         = "Weapon-Type Gating (Triggerbot/Melee Smart Block)",
    CurrentValue = S.WeaponTypeGating,
    Flag         = "WeaponTypeGating",
    Callback     = function(v)
        S.WeaponTypeGating = v
        if S.Notify then S.Notify({Title="TASFF Intel",Content=v and "Type gating ON — melee won't triggerbot; ranged won't melee." or "Type gating OFF — all weapons use all features.",Duration=2,Image="cpu"}) end
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

-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                       6. PRESETS TAB                         // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

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
                TargetPart = S.TargetPart, PriorityMode = S.PriorityMode, VitalityMode = S.VitalityMode,
                TargetNearCenter = S.TargetNearCenter, Smoothness = S.Smoothness, PredictionAmount = S.PredictionAmount,
                SilentAimEnabled = S.SilentAimEnabled, DynamicRecoilEnabled = S.DynamicRecoilEnabled,
                RandomizeHitboxEnabled = S.RandomizeHitboxEnabled, TargetSwitchDelayEnabled = S.TargetSwitchDelayEnabled,
                SwitchDelayMs = S.SwitchDelayMs, GracePeriodEnabled = S.GracePeriodEnabled, GracePeriodMs = S.GracePeriodMs,
                AimbotRenderDistance = S.AimbotRenderDistance, StickyAimEnabled = S.StickyAimEnabled, AutoADSEnabled = S.AutoADSEnabled,
                -- Visuals & Overlays
                VisualMode = S.VisualMode, UseHighlight = S.UseHighlight, UseNPCHighlight = S.UseNPCHighlight,
                FocusMode = S.FocusMode, StreamProofESP = S.StreamProofESP, VisibilityColorsEnabled = S.VisibilityColorsEnabled,
                ESPRenderDistance = S.ESPRenderDistance, ChamsEnabled = S.ChamsEnabled, ChamsOpacity = S.ChamsOpacity,
                BoxModeEnabled = S.BoxModeEnabled, SkeletonModeEnabled = S.SkeletonModeEnabled, SnaplinesEnabled = S.SnaplinesEnabled,
                SnaplineOrigin = S.SnaplineOrigin, OOFArrowsEnabled = S.OOFArrowsEnabled, OOFArrowRadius = S.OOFArrowRadius,
                UseInfoTag = S.UseInfoTag, UseNPCInfoTag = S.UseNPCInfoTag, ShowDisplayName = S.ShowDisplayName, ShowToolCheck = S.ShowToolCheck,
                ShowFOV = S.ShowFOV, InvisibleFOV = S.InvisibleFOV, FOVSize = S.FOVSize, AimReferenceMode = S.AimReferenceMode,
                EnableCrosshair = S.EnableCrosshair, CrosshairStyle = S.CrosshairStyle, CrosshairSize = S.CrosshairSize,
                ManualCalibrationEnabled = S.ManualCalibrationEnabled, CalibrationOffsetX = S.CalibrationOffsetX, CalibrationOffsetY = S.CalibrationOffsetY,
                -- Triggerbot & Automation
                AutoClickEnabled = S.AutoClickEnabled, TriggerbotClickMode = S.TriggerbotClickMode, ClickMethod = S.ClickMethod,
                ClickInterval = S.ClickInterval, ThirdPersonTriggerbot = S.ThirdPersonTriggerbot, KeyTriggerbotEnabled = S.KeyTriggerbotEnabled,
                KeyTriggerMode = S.KeyTriggerMode, MeleeModeEnabled = S.MeleeModeEnabled, MeleeDetectionRange = S.MeleeDetectionRange,
                MeleeClickInterval = S.MeleeClickInterval,
                -- Advanced & Logic
                ThreatDetectorEnabled = S.ThreatDetectorEnabled, NemesisEnabled = S.NemesisEnabled, ThreatTimeout = S.ThreatTimeout,
                BlacklistExpiredThreats = S.BlacklistExpiredThreats, ClickToMarkEnabled = S.ClickToMarkEnabled, MarkMethod = S.MarkMethod,
                KillCountThreatEnabled = S.KillCountThreatEnabled, KillFeedEnabled = S.KillFeedEnabled, KillsBeforeThreat = S.KillsBeforeThreat, KillsBeforeNemesis = S.KillsBeforeNemesis, ThreatNeutralizationEnabled = S.ThreatNeutralizationEnabled, AutoExpireOnDisconnect = S.AutoExpireOnDisconnect,
                StrictPrioritize = S.StrictPrioritize, WallCheck = S.WallCheck, NoCollisionCheck = S.NoCollisionCheck,
                TransparencyCheck = S.TransparencyCheck, TransparencyThreshold = S.TransparencyThreshold, DecalsCheck = S.DecalsCheck,
                -- Settings & Entities
                TargetPlayers = S.TargetPlayers, TargetNPCs = S.TargetNPCs, TeamCheck = S.TeamCheck,
                AutoEnableOnEquip = S.AutoEnableOnEquip, IgnoreDead = S.IgnoreDead,
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
    Callback      = function(v) SelectedPresetToManage = type(v) == "table" and v[1] or v end
})

local STO_FLAG = {
    MasterEnabled = "MasterSwitch", TargetingEnabled = "TargetSystemToggle", Mode = "AimMethod",
    AimbotKeybind = "AimbotKeybind", TargetPart = "TargetPart", PriorityMode = "PriorityMode",
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
    CalibrationOffsetY = "CalibrationY", AutoClickEnabled = "EnableTriggerbot", TriggerbotClickMode = "TriggerbotClickMode",
    ClickMethod = "ClickMethod", ClickInterval = "ClickInterval", ThirdPersonTriggerbot = "ThirdPersonTriggerbot",
    KeyTriggerbotEnabled = "KeyTriggerbotToggle", KeyTriggerMode = "KeyTriggerMode", MeleeModeEnabled = "EnableMeleeMode",
    MeleeDetectionRange = "MeleeRange", MeleeClickInterval = "MeleeClickInterval", ThreatDetectorEnabled = "ThreatDetector",
    NemesisEnabled = "NemesisEnabled", ThreatTimeout = "ThreatTimeout", BlacklistExpiredThreats = "BlacklistExpiredThreats",
    ClickToMarkEnabled = "ClickToMark", MarkMethod = "MarkMethod", StrictPrioritize = "StrictPrioritize", WallCheck = "WallCheck",
    NoCollisionCheck = "NoCollisionCheck", TransparencyCheck = "TransparencyCheck", TransparencyThreshold = "TransparencyThreshold",
    DecalsCheck = "DecalsCheck", TargetPlayers = "TargetPlayers", TargetNPCs = "TargetNPCs", TeamCheck = "TeamCheck",
    AutoEnableOnEquip = "AutoEquipAim", IgnoreDead = "IgnoreDead"
}

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
            local data = S.SavedPresets[selected]
            for key, value in pairs(data) do 
                local color = table.find(ColorFields, key) and DecodeColor(value)
                local flag = STO_FLAG[key]
                if color then
                    SetColor(key, color)
                    local colorFlag = ColorFlagMap[key]
                    if colorFlag and Rayfield.Flags[colorFlag] then
                        pcall(function() Rayfield.Flags[colorFlag]:Set(color) end)
                    end
                elseif flag and Rayfield.Flags[flag] then
                    pcall(function() Rayfield.Flags[flag]:Set(value) end)
                else
                    S[key] = value
                end
            end
            if S.Notify then S.Notify({Title = "TASFF Presets", Content = "Successfully loaded profile: " .. selected .. "\nUI has been updated.", Duration = 4, Image = "folder-open"}) end
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

PresetsTab:CreateSection("Built-In Game Profiles")
PresetsTab:CreateParagraph({
    Title   = "Quick-Load Configs",
    Content = "Pre-configured profiles for popular games. Loading these will override your current settings."
})

PresetsTab:CreateButton({
    Name = "Load Da Hood Config (Legit)",
    Callback = function()
        pcall(function() Rayfield.Flags["AimMethod"]:Set("Legit (Camera)") end)
        pcall(function() Rayfield.Flags["TargetPart"]:Set("Head") end)
        pcall(function() Rayfield.Flags["PredIntense"]:Set(0.12) end)
        pcall(function() Rayfield.Flags["SmoothSpeed"]:Set(1.5) end)
        if S.Notify then S.Notify({Title="TASFF Presets", Content="Loaded Da Hood (Legit) profile.", Duration=2, Image="check"}) end
    end
})

PresetsTab:CreateButton({
    Name = "Load Phantom Forces Config (Blatant)",
    Callback = function()
        pcall(function() Rayfield.Flags["AimMethod"]:Set("Blatant") end)
        pcall(function() Rayfield.Flags["TargetPart"]:Set("Head") end)
        pcall(function() Rayfield.Flags["BlatantSnapSpeed"]:Set(100) end)
        pcall(function() Rayfield.Flags["WallCheck"]:Set(true) end)
        if S.Notify then S.Notify({Title="TASFF Presets", Content="Loaded Phantom Forces (Blatant) profile.", Duration=2, Image="check"}) end
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

-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                       7. THEMING TAB                         // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

local CustomizationTab = Window:CreateTab("Theming", "brush")

local GlobalThemeMonitor
local function UpdateWindowTitle(themeName)
    local main = Rayfield.Main
    local topbar = main and main:FindFirstChild("Topbar")
    local title = topbar and topbar:FindFirstChild("Title")
    if title and title:IsA("TextLabel") then
        title.Text = "TASFF 2.2.0 " .. themeName
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
        Title = "Preset Preview — " .. themeName,
        Content = table.concat(lines, "\n"),
    })
end
GlobalThemeMonitor = CustomizationTab:CreateParagraph({
    Title = "Preset Preview — " .. selectedGlobalTheme,
    Content = "Select a theme to preview its visual and interface colors.",
})
CustomizationTab:CreateDropdown({
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
        if _G.UpdateFOVCircleColor then _G.UpdateFOVCircleColor(S.FOVColor) end
        if _G.UpdateCrosshairColor then _G.UpdateCrosshairColor(S.CrosshairColor) end
        UpdateWindowTitle(selectedGlobalTheme)
        ScheduleColorSettingsSave()
        if S.Notify then
            S.Notify({
                Title = "Global Theme Applied",
                Content = selectedGlobalTheme .. " visuals applied. UI colors take effect the next time the interface loads.",
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

-- ─── Section: General Base Colors ───────────────────────────────────────────
CustomizationTab:CreateSection("General Base Colors - Default Highlight & Name Tags")
CustomizationTab:CreateToggle({Name = "Use Preset Color — Default Highlight & Tags", CurrentValue = false, Flag = "HighlightPresetToggle", Callback = function(v)
    applyPreset(v, "HighlightColorDd", nil, "HighlightColor")
end})
CustomizationTab:CreateDropdown({Name = "Preset — Default Highlight & Tags", Options = ColorDropdownOptions, CurrentOption = {"White"}, Flag = "HighlightColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["HighlightPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("HighlightColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Fine — Default Highlight & Tag Color", Color = S.HighlightColor or Color3.fromRGB(255,255,255), Flag = "HighlightColorPicker", Callback = function(Value) SetColor("HighlightColor", Value) end})

-- ─── Section: On-Screen Overlays (FOV Circle & Crosshair) ─────────────────
CustomizationTab:CreateSection("On-Screen Overlays — FOV & Crosshair")
CustomizationTab:CreateToggle({Name = "Use Preset Color — FOV Circle", CurrentValue = false, Flag = "FOVPresetToggle", Callback = function(v)
    applyPreset(v, "FOVCircleColorDd", _G.UpdateFOVCircleColor, "FOVColor")
end})
CustomizationTab:CreateDropdown({Name = "Preset — FOV Circle", Options = ColorDropdownOptions, CurrentOption = {"Tan"}, Flag = "FOVCircleColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["FOVPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]
    if rgb and _G.UpdateFOVCircleColor then _G.UpdateFOVCircleColor(rgb) end
    if rgb then SetColor("FOVColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Fine — FOV Circle Color", Color = S.FOVColor or Color3.fromRGB(255,200,120), Flag = "FOVCircleColorPicker", Callback = function(Value)
    SetColor("FOVColor", Value)
    if _G.UpdateFOVCircleColor then _G.UpdateFOVCircleColor(Value) end
end})

CustomizationTab:CreateToggle({Name = "Use Preset Color — Crosshair", CurrentValue = false, Flag = "CrosshairPresetToggle", Callback = function(v)
    applyPreset(v, "CrosshairColorDd", _G.UpdateCrosshairColor, "CrosshairColor")
end})
CustomizationTab:CreateDropdown({Name = "Preset — Crosshair", Options = ColorDropdownOptions, CurrentOption = {"Coral"}, Flag = "CrosshairColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["CrosshairPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]
    if rgb and _G.UpdateCrosshairColor then _G.UpdateCrosshairColor(rgb) end
    if rgb then SetColor("CrosshairColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Fine — Crosshair Color", Color = S.CrosshairColor or Color3.fromRGB(255,127,80), Flag = "CrosshairColorPicker", Callback = function(Value)
    SetColor("CrosshairColor", Value)
    if _G.UpdateCrosshairColor then _G.UpdateCrosshairColor(Value) end
end})

-- ─── Section: Drawing Visuals (Box, Skeleton, Snaplines) ──────────────────
CustomizationTab:CreateSection("Drawing Visuals — Box, Skeleton, Snaplines")
CustomizationTab:CreateToggle({Name = "Use Preset Color — Box ESP", CurrentValue = false, Flag = "BoxPresetToggle", Callback = function(v)
    applyPreset(v, "BoxColorDd", nil, "BoxColor")
end})
CustomizationTab:CreateDropdown({Name = "Preset — Box ESP", Options = ColorDropdownOptions, CurrentOption = {"Maroon"}, Flag = "BoxColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["BoxPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("BoxColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Fine — Box ESP Color", Color = S.BoxColor or Color3.fromRGB(200,40,40), Flag = "BoxESPColorPicker", Callback = function(Value) SetColor("BoxColor", Value) end})

CustomizationTab:CreateToggle({Name = "Use Preset Color — Skeleton ESP", CurrentValue = false, Flag = "SkelPresetToggle", Callback = function(v)
    applyPreset(v, "SkelColorDd", nil, "SkeletonColor")
end})
CustomizationTab:CreateDropdown({Name = "Preset — Skeleton ESP", Options = ColorDropdownOptions, CurrentOption = {"Maroon"}, Flag = "SkelColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["SkelPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("SkeletonColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Fine — Skeleton ESP Color", Color = S.SkeletonColor or Color3.fromRGB(200,40,40), Flag = "SkeletonESPColorPicker", Callback = function(Value) SetColor("SkeletonColor", Value) end})

CustomizationTab:CreateToggle({Name = "Use Preset Color — Snaplines & OOF Arrows", CurrentValue = false, Flag = "SnapPresetToggle", Callback = function(v)
    applyPreset(v, "SnapColorDd", nil, "SnaplineColor")
end})
CustomizationTab:CreateDropdown({Name = "Preset — Snaplines & OOF Arrows", Options = ColorDropdownOptions, CurrentOption = {"Red"}, Flag = "SnapColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["SnapPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("SnaplineColor", rgb); SetColor("OOFArrowColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Fine — Snapline Color", Color = S.SnaplineColor or Color3.fromRGB(255,0,0), Flag = "SnaplineFineColorPicker", Callback = function(Value) SetColor("SnaplineColor", Value) end})
CustomizationTab:CreateColorPicker({Name = "Fine — OOF Arrow Color", Color = S.OOFArrowColor or Color3.fromRGB(255,100,0), Flag = "OOFArrowColorPicker", Callback = function(Value) SetColor("OOFArrowColor", Value) end})

-- ─── Section: Intel / Target Category Colors ──────────────────────────────
CustomizationTab:CreateSection("Intel Category Colors — Priority, Threat, Nemesis")
CustomizationTab:CreateToggle({Name = "Use Preset Color — Priority Players", CurrentValue = false, Flag = "PrioPresetToggle", Callback = function(v)
    applyPreset(v, "PrioColorDd", nil, "PriorityHighlightColor")
end})
CustomizationTab:CreateDropdown({Name = "Preset — Priority Players", Options = ColorDropdownOptions, CurrentOption = {"Yellow"}, Flag = "PrioColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["PrioPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("PriorityHighlightColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Fine — Priority Player ESP Color", Color = S.PriorityHighlightColor or Color3.fromRGB(255,200,0), Flag = "PriorityHighlightColorPicker", Callback = function(Value) SetColor("PriorityHighlightColor", Value) end})

CustomizationTab:CreateToggle({Name = "Use Preset Color — Threat Players", CurrentValue = false, Flag = "ThreatPresetToggle", Callback = function(v)
    applyPreset(v, "ThreatColorDd", nil, "ThreatHighlightColor")
end})
CustomizationTab:CreateDropdown({Name = "Preset — Threat Players", Options = ColorDropdownOptions, CurrentOption = {"Orange"}, Flag = "ThreatColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["ThreatPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("ThreatHighlightColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Fine — Threat Player ESP Color", Color = S.ThreatHighlightColor or Color3.fromRGB(255,60,0), Flag = "ThreatHighlightColorPicker", Callback = function(Value) SetColor("ThreatHighlightColor", Value) end})

CustomizationTab:CreateToggle({Name = "Use Preset Color — Nemesis Players", CurrentValue = false, Flag = "NemesisPresetToggle", Callback = function(v)
    applyPreset(v, "NemesisColorDd", nil, "NemesisHighlightColor")
end})
CustomizationTab:CreateDropdown({Name = "Preset — Nemesis Players", Options = ColorDropdownOptions, CurrentOption = {"Purple"}, Flag = "NemesisColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["NemesisPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("NemesisHighlightColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Fine — Nemesis Player ESP Color", Color = S.NemesisHighlightColor or Color3.fromRGB(150,0,255), Flag = "NemesisHighlightColorPicker", Callback = function(Value) SetColor("NemesisHighlightColor", Value) end})

CustomizationTab:CreateToggle({Name = "Use Preset Color — Blacklisted Players", CurrentValue = false, Flag = "BlacklistPresetToggle", Callback = function(v)
    applyPreset(v, "BlacklistColorDd", nil, "BlacklistedTagColor")
end})
CustomizationTab:CreateDropdown({Name = "Preset — Blacklisted Players", Options = ColorDropdownOptions, CurrentOption = {"Orange"}, Flag = "BlacklistColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["BlacklistPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("BlacklistedTagColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Fine — Blacklisted Player Tag Color", Color = S.BlacklistedTagColor or Color3.fromRGB(255,140,0), Flag = "BlacklistedTagColorPicker", Callback = function(Value) SetColor("BlacklistedTagColor", Value) end})

-- ─── Section: Chams (Through-Wall) ────────────────────────────────────────
CustomizationTab:CreateSection("Through-Wall Visuals — Chams")
CustomizationTab:CreateToggle({Name = "Use Preset Color — Chams", CurrentValue = false, Flag = "ChamsPresetToggle", Callback = function(v)
    applyPreset(v, "ChamsColorDd", nil, "ChamsColor")
end})
CustomizationTab:CreateDropdown({Name = "Preset — Chams Color", Options = ColorDropdownOptions, CurrentOption = {"Red"}, Flag = "ChamsColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["ChamsPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("ChamsColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Fine — Chams Color", Color = S.ChamsColor or Color3.fromRGB(255,30,30), Flag = "ChamsColorPicker", Callback = function(Value) SetColor("ChamsColor", Value) end})
CustomizationTab:CreateSlider({Name = "Chams Opacity (0–100)", Range = {0, 100}, Increment = 1, CurrentValue = S.ChamsOpacity or 10, Flag = "ChamsOpacity", Callback = function(v) S.ChamsOpacity = v end})

-- ─── Section: Kill Flash ──────────────────────────────────────────────────
CustomizationTab:CreateSection("Combat Feedback — Kill Flash")
CustomizationTab:CreateToggle({Name = "Use Preset Color — Kill Confirmation Flash", CurrentValue = false, Flag = "KillFlashPresetToggle", Callback = function(v)
    applyPreset(v, "KillFlashColorDd", nil, "KillFlashColor")
end})
CustomizationTab:CreateDropdown({Name = "Preset — Kill Flash Color", Options = ColorDropdownOptions, CurrentOption = {"White"}, Flag = "KillFlashColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["KillFlashPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("KillFlashColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Fine — Kill Flash Color", Color = S.KillFlashColor or Color3.fromRGB(255,255,255), Flag = "KillFlashColorPicker", Callback = function(Value) SetColor("KillFlashColor", Value) end})


-- ─── Section: Visibility Indicator Colors ─────────────────────────────────
CustomizationTab:CreateSection("Visibility Indicator Colors")
CustomizationTab:CreateToggle({Name = "Use Preset Color — Visible Target", CurrentValue = false, Flag = "VisiblePresetToggle", Callback = function(v)
    applyPreset(v, "VisibleColorDd", nil, "VisibleColor")
end})
CustomizationTab:CreateDropdown({Name = "Preset — Visible Target Color", Options = ColorDropdownOptions, CurrentOption = {"Lime"}, Flag = "VisibleColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["VisiblePresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("VisibleColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Fine — Visible Target Color", Color = S.VisibleColor or Color3.fromRGB(0,255,0), Flag = "VisibleColorPicker", Callback = function(Value) SetColor("VisibleColor", Value) end})

CustomizationTab:CreateToggle({Name = "Use Preset Color — Hidden Target", CurrentValue = false, Flag = "HiddenPresetToggle", Callback = function(v)
    applyPreset(v, "HiddenColorDd", nil, "HiddenColor")
end})
CustomizationTab:CreateDropdown({Name = "Preset — Hidden Target Color", Options = ColorDropdownOptions, CurrentOption = {"Red"}, Flag = "HiddenColorDd", Callback = function(v)
    local f = Rayfield.Flags and Rayfield.Flags["HiddenPresetToggle"]
    if not (f and f.CurrentValue) then return end
    local rgb = ColorPresetMap[type(v)=="table" and v[1] or v]; if rgb then SetColor("HiddenColor", rgb) end
end})
CustomizationTab:CreateColorPicker({Name = "Fine — Hidden Target Color", Color = S.HiddenColor or Color3.fromRGB(255,0,0), Flag = "HiddenColorPicker", Callback = function(Value) SetColor("HiddenColor", Value) end})

-- ─── Section: UI Theme Editor ─────────────────────────────────────────────
CustomizationTab:CreateSection("UI Theme Editor (Next Load)")
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

local MiscTab = Window:CreateTab("System", "cog")


MiscTab:CreateSection("Performance Engine")
PerformanceIndicator = MiscTab:CreateParagraph({
    Title   = "Active Performance Profile",
    Content = "Current Mode: " .. (S.PerformanceMode or "Medium") ..
              " (Interval: " .. ((S.PerformanceIntervals or {})[S.PerformanceMode] or 3) .. " frames)"
})
S.PerformanceIndicator = PerformanceIndicator

MiscTab:CreateDropdown({
    Name            = "Core Frame-Skip Strategy",
    Options         = S.PerformanceModes or {"Ultra High", "High", "Medium", "Low", "Ultra Low"},
    CurrentOption   = {S.PerformanceMode},
    MultipleOptions = false,
    Flag            = "PerformanceMode",
    Callback        = function(v)
        S.PerformanceMode = v[1] or "Medium"
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

MiscTab:CreateSection("Security & Failsafes")
MiscTab:CreateParagraph({
    Title   = "Panic System & Clean Unload",
    Content = "Panic: Instantly suspends Master Switch, releases all virtual mouse/key inputs, and hides overlays.\nKill/Unload: Destroys the Rayfield GUI completely and terminates all backend memory connections."
})

MiscTab:CreateToggle({Name = "Silence All Notifications", CurrentValue = S.DisableNotifications, Flag = "DisableNotifications", Callback = function(v)
    S.DisableNotifications = v
end})
MiscTab:CreateSlider({Name = "Notification Duration (seconds)", Range = {1, 10}, Increment = 1, CurrentValue = S.NotificationDuration or 3, Flag = "NotificationDuration", Callback = function(v)
    S.NotificationDuration = v
end})
MiscTab:CreateSlider({Name = "Notification Throttle (Max per 3s)", Range = {1, 10}, Increment = 1, CurrentValue = S.NotifyMaxPer3s or 5, Flag = "NotifyThrottle", Callback = function(v) S.NotifyMaxPer3s = v end})
MiscTab:CreateToggle({Name = "Suppress Rayfield Advertising Notifications", CurrentValue = S.SuppressRayfieldAds, Flag = "SuppressRayfieldAds", Callback = function(v)
    S.SuppressRayfieldAds = v
end})

MiscTab:CreateToggle({Name = "Anti-AFK (Prevent Kick)", CurrentValue = S.AntiAFKEnabled, Flag = "AntiAFK", Callback = function(v) S.AntiAFKEnabled = v end})
MiscTab:CreateToggle({Name = "FPS Watcher (Auto-Tune Performance Mode)", CurrentValue = S.FPSWatcherEnabled, Flag = "FPSWatcher", Callback = function(v) S.FPSWatcherEnabled = v end})

MiscTab:CreateSection("Quick Controls")
MiscTab:CreateToggle({Name = "Rapid Aim Mode Cycle (Keybind)", CurrentValue = S.RapidModeCycleEnabled, Flag = "RapidModeCycle", Callback = function(v) S.RapidModeCycleEnabled = v end})
MiscTab:CreateKeybind({
    Name           = "Mode Cycle Key",
    CurrentKeybind = S.RapidModeCycleKey or "P",
    Flag           = "RapidModeCycleKey",
    Callback       = function(key)
        local validKey = SanitizeKeyName(key)
        if validKey then S.RapidModeCycleKey = validKey end
    end
})
MiscTab:CreateToggle({Name = "Debug Mode (Verbose Console Output)", CurrentValue = S.DebugMode, Flag = "DebugMode", Callback = function(v) S.DebugMode = v end})

MiscTab:CreateKeybind({
        Name           = "Global Panic Keybind",
        CurrentKeybind = S.PanicKeybind or "Delete",
        Flag           = "PanicKeybind",
        Callback       = function(key)
            local validKey = SanitizeKeyName(key)
            if validKey then S.PanicKeybind = validKey end
        end
    })

MiscTab:CreateButton({
    Name     = "Execute Panic Protocol",
    Callback = function()
        if S.TriggerPanic then S.TriggerPanic() end
    end
})

MiscTab:CreateButton({
    Name     = "Factory Reset (Restore All Defaults)",
    Callback = function()
        -- Exhaustive reset to prevent "frankenstein" states
        S.MasterEnabled = false;        S.TargetingEnabled = true;      S.Mode = "Legit (Camera)"
        S.TargetPart = "Head";          S.ActivePartName = "Head"
        S.PriorityMode = "None";        S.VitalityMode = "None";        S.TargetNearCenter = false
        S.Smoothness = 1.5;             S.PredictionAmount = 0.16
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
        S.OOFArrowsEnabled = false;     S.OOFArrowRadius = 150
        S.UseInfoTag = true;            S.UseNPCInfoTag = true
        S.ShowDisplayName = false;      S.ShowToolCheck = false
        S.ShowFOV = false;              S.InvisibleFOV = false;         S.FOVSize = 100
        S.AimReferenceMode = "Screen Center"
        S.EnableCrosshair = false;      S.CrosshairStyle = "Plus";      S.CrosshairSize = 10
        S.ManualCalibrationEnabled = false; S.CalibrationOffsetX = 0;   S.CalibrationOffsetY = 0
        S.AutoClickEnabled = false;     S.TriggerbotClickMode = "Virtual"; S.ClickMethod = "Mash"
        S.ClickInterval = 100;          S.ThirdPersonTriggerbot = false
        S.KeyTriggerbotEnabled = false; S.KeyTriggerMode = "Single Press"
        S.MeleeModeEnabled = false;     S.MeleeDetectionRange = 5;      S.MeleeClickInterval = 100
        S.ThreatDetectorEnabled = false; S.NemesisEnabled = true;       S.ThreatTimeout = 10
        S.BlacklistExpiredThreats = false
        S.KillCountThreatEnabled = false; S.KillFeedEnabled = false; S.KillsBeforeThreat = 3; S.KillsBeforeNemesis = 3
        S.ThreatNeutralizationEnabled = false; S.AutoExpireOnDisconnect = false
        S.ClickToMarkEnabled = false;   S.MarkMethod = "Both"
        S.StrictPrioritize = false;     S.WallCheck = true
        S.NoCollisionCheck = false;     S.TransparencyCheck = false;    S.TransparencyThreshold = 0.5
        S.DecalsCheck = false
        S.TargetPlayers = true;         S.TargetNPCs = false;           S.TeamCheck = false
        S.AutoEnableOnEquip = false;    S.IgnoreDead = true
        S.CurrentTarget = nil
        if S.SetADSState    then S.SetADSState(false) end
        if S.ClearVisuals   then S.ClearVisuals()     end
        if S.ClearCrosshair then S.ClearCrosshair()   end
        if S.Notify then S.Notify({Title = "TASFF System", Content = "Factory Reset complete. All modules restored to default.", Duration = 3, Image = "list-restart"}) end
    end
})

MiscTab:CreateButton({
    Name     = "Terminate Script & Unload Interface",
    Callback = function()
        if S.UnloadScript then S.UnloadScript() end
    end
})

-- // ══════════════════════════════════════════════════════════════ // --
-- //           SCREEN RECORDING CLOAKING SYSTEM (v2.2.0)          // --
-- // ══════════════════════════════════════════════════════════════ // --
-- Roblox's built-in screen recording captures:
--   ✗ Drawing API objects (Lines, Circles, Squares, Text) — VISIBLE
--   ✗ Roblox Highlight instances                          — VISIBLE
--   ✗ ScreenGui frames / TextLabels                       — VISIBLE
--   ✓ BillboardGui parented to workspace parts            — INVISIBLE
--   ✓ SurfaceGui parented to workspace parts              — INVISIBLE
-- This system lets you selectively redirect selected visuals to the
-- invisible-to-capture rendering mode at the press of a button.

MiscTab:CreateSection("Screen Recording Cloaking")
MiscTab:CreateParagraph({
    Title   = "About This System",
    Content = "TASFF maintains dual overlays to control recording visibility:\n" ..
              "  • TASFF_Overlay (PlayerGui) — captured by Roblox recording\n" ..
              "  • TASFF_CoreOverlay (CoreGui / Hidden UI) — NOT captured by Roblox recording\n\n" ..
              "✅ Drawing Visuals (Crosshair, FOV Circle, Box ESP, Skeleton, Snaplines, OOF Arrows):\n" ..
              "When set to Hide, frames are routed to TASFF_CoreOverlay. They stay fully visible on your screen, but Roblox's screen recorder cannot capture them.\n" ..
              "When set to Show, frames are routed to TASFF_Overlay so recordings can see them.\n\n" ..
              "✅ Tags / Nametags:\n" ..
              "When set to Hide, tags switch to BillboardGui (3D floating text attached to targets) parented to the protected container — visible to you, invisible to recordings.\n\n" ..
              "ℹ️ Chams / Highlights: Always rendered on screen for player tracking."
})

-- Status monitor: shows hidden/visible state per feature
local CloakStatusLabel = MiscTab:CreateParagraph({
    Title   = "Recording Cloak Status",
    Content = "No visuals hidden from recording."
})

-- List of cloakable visual feature names (must match render loop checks)
local CloakableFeatures = {
    "Crosshair",
    "FOV Circle",
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
        table.insert(lines, (hidden and "🔴 [HIDDEN] " or "🟢 [VISIBLE] ") .. feat)
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
MiscTab:CreateDropdown({
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
MiscTab:CreateButton({
    Name     = "🔴  Hide Selected from Roblox Screen Recording",
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
MiscTab:CreateButton({
    Name     = "🟢  Show Selected (Restore from Cloak)",
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

MiscTab:CreateButton({
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



-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                      9. UPDATE LOG TAB                       // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

local UpdateLogTab = Window:CreateTab("Update Log", "history")
UpdateLogTab:CreateSection("Unreleased Customization Improvements")
UpdateLogTab:CreateLabel("- Added 18 global color presets covering ESP, overlays, Intel categories, chams, combat feedback, visibility, and UI colors.")
UpdateLogTab:CreateLabel("- Added a preset color monitor showing category, nearest color name, and exact hex value before applying.")
UpdateLogTab:CreateLabel("- Applying or selecting a global preset updates the window title to include the selected theme.")
UpdateLogTab:CreateLabel("- UI palette colors persist and are applied on the next load because Rayfield does not support live theme changes.")
UpdateLogTab:CreateLabel("- Clarified that PlayerGui overlay tags and Roblox Highlight chams are visible to Roblox recording; retained the legacy StreamProofESP config flag for compatibility.")
UpdateLogTab:CreateLabel("- v2.2.0 control totals: 79 toggles, 29 sliders, 37 dropdowns, 24 buttons, 5 keybinds. Feature registry: " .. (S.FeatureCount or "?") .. " registered.")
UpdateLogTab:CreateSection("Version 2.2.0 (Screen Recording Cloaking Update)")
UpdateLogTab:CreateLabel("- NEW Screen Recording Cloaking System: selectively cloak visuals from Roblox's screen recording while keeping them visible on your own screen.")
UpdateLogTab:CreateLabel("- DUAL OVERLAY ARCHITECTURE: TASFF_Overlay (PlayerGui, captured by recordings) + TASFF_CoreOverlay (CoreGui / GetHiddenContainer, NOT captured).")
UpdateLogTab:CreateLabel("- Drawing ESP (Box, Skeleton, Snaplines, OOF Arrows, FOV Circle, Crosshair): When cloaked, frames dynamically route to TASFF_CoreOverlay — they stay fully visible on your monitor but vanish from recordings.")
UpdateLogTab:CreateLabel("- Tags / Nametags cloak: converts to 3D BillboardGui attached to targets and parented to the protected container — invisible to recordings, visible on screen.")
UpdateLogTab:CreateLabel("- 'Show Selected' button restores selected visuals to the standard recording-visible overlay.")
UpdateLogTab:CreateLabel("- Status display: live monitor in System tab shows 🟢 [VISIBLE] / 🔴 [HIDDEN] state per visual category.")
UpdateLogTab:CreateLabel("- Group key 'Drawing-Based ESP' cloaks Box + Skeleton + Snaplines + OOF Arrows in a single selection.")
UpdateLogTab:CreateLabel("- FIX ListenForTools: removed duplicate TrackConnection calls; IntelligentEquipFilter now also gates ToolAdded auto-enable.")
UpdateLogTab:CreateLabel("- FIX TriggerPanic: IsHoldingTriggerKey now released via VirtualInputManager on panic.")
UpdateLogTab:CreateLabel("- FIX UnloadScript: destroys all Drawing objects and cleans up both TASFF_Overlay and TASFF_CoreOverlay on unload.")
UpdateLogTab:CreateLabel("- FIX UpdateSpectator: camera subject guarded against nil when player dies during spectate-end.")
UpdateLogTab:CreateLabel("- FIX GetEffectiveFOV: DynamicFOVMax nil-guarded (math.min(n, nil) error after preset restore).")
UpdateLogTab:CreateLabel("- FIX ResolvePlayerName: returns nil on no-match; prevents phantom priority entries from stale labels.")
UpdateLogTab:CreateLabel("- FIX Blacklist / ESPWhitelist dropdowns: DisplayName labels resolved to real usernames before storing.")

UpdateLogTab:CreateSection("Version 2.1.2 (Refinement Update)")
UpdateLogTab:CreateLabel("- FIX VoS Wallcheck Locking: Visible On Screen mode now actively drops targets when they are fully occluded, fixing the stuck [LOCKED] tag issue.")
UpdateLogTab:CreateLabel("- FIX Missing Colors UI: Restored missing Customization options for Default Highlight & Name Tags.")
UpdateLogTab:CreateLabel("- FIX Aimbot Snap-Back: Fixed edge case where Visible On Screen targeting cached old dead limbs and snapped back instantly.")
UpdateLogTab:CreateLabel("- FIX Dead Target Filtering: Completely eliminated the Ignore Dead toggle - aimbot engine now permanently ignores corpses.")
UpdateLogTab:CreateLabel("- FIX Kill Flash Rendering: Fading sequence now renders correctly because corpses are briefly preserved for the ESP renderer.")
UpdateLogTab:CreateLabel("- FIX Threat Intelligence: Expanded kill feed parsing to detect 'creatorTag', 'Killer', and 'killer' object tags.")
UpdateLogTab:CreateLabel("- FIX Chams Color & Opacity: Custom colors now properly apply to Chams, and the opacity scale (0-100) works seamlessly.")
UpdateLogTab:CreateLabel("- FIX Blacklisted Tag Colors: Added missing preset toggle and dropdown options for blacklisted tags.")
UpdateLogTab:CreateLabel("- NEW Kill Flash Fade: The kill confirmation flash now smoothly fades out instead of abruptly disappearing.")
UpdateLogTab:CreateLabel("- NEW Kill Flash Duration: Added a slider to configure the exact duration of the kill confirmation fade.")
UpdateLogTab:CreateLabel("- FIX Lock-On Delay: Visibility precompute loop now restarts immediately (no gap wait). Sub-frame delay.")
UpdateLogTab:CreateLabel("- FIX Optimistic Nil Visibility: New players in FOV circle lock on instantly; background corrects within 1-2 frames.")
UpdateLogTab:CreateLabel("- NEW Server Info: Home tab shows game name, Place ID, Job ID, and live player count (refreshes every 10s).")
UpdateLogTab:CreateLabel("- NEW Theming Tab Redesign: All color controls split into logical sections (Overlays, Drawing, Intel, Chams, Combat).")
UpdateLogTab:CreateLabel("- NEW Per-Section Color System: Each visual category has its own preset toggle, preset dropdown, and fine picker.")
UpdateLogTab:CreateLabel("- NEW UI Theme Editor: Live color pickers for Rayfield window chrome (Background, Topbar, Accent, Text, Elements).")
UpdateLogTab:CreateLabel("- NEW Notification Duration Slider: Global control for how long all TASFF notifications are displayed.")
UpdateLogTab:CreateLabel("- NEW Suppress Rayfield Ads: Toggle to block Rayfield's periodic 'Loving this UI library?' advertising popup.")
UpdateLogTab:CreateLabel("- NEW Session User Kill Count: Tracks how many kills you (the local player) secured; shown in session stats.")
UpdateLogTab:CreateLabel("- NEW Priority Player Kill Count: Intel Monitor now shows ☠ N next to tracked players who scored kills.")
UpdateLogTab:CreateLabel("- NEW DisplayName in Dropdowns: Player dropdowns show 'DisplayName (username)' format for easier identification.")

UpdateLogTab:CreateSection("Version 2.1.1 (Hotfix Patch)")
UpdateLogTab:CreateLabel("- FIXED Panic Keybind: Panic now permanently locks TASFF. Only a full re-execute restores operation.")
UpdateLogTab:CreateLabel("- FIXED Silent Aim Camera Freeze: __index hook now only intercepts Mouse object queries, not all CFrame reads.")
UpdateLogTab:CreateLabel("- FIXED Silent Aim Camera Freeze: __namecall hook detects and ignores PopperCam/ZoomController raycasts.")
UpdateLogTab:CreateLabel("- FIXED Sticky Aim Snap-Back: SilentAimTargetCache and CurrentTarget cleared instantly on aimbot toggle-off.")
UpdateLogTab:CreateLabel("- FIXED Kill Intelligence: Creator tag detection now checks 'creator', 'Creator', and 'KilledBy' (string and obj).")
UpdateLogTab:CreateLabel("- FIXED Priority Point Tracking: Priority/Intel players now gain +15 points per kill.")
UpdateLogTab:CreateLabel("- NEW Disconnect Notification: Tracked players who leave now trigger a notification with their Intel category.")
UpdateLogTab:CreateLabel("- NEW Unload Notification: Termination now shows a native Roblox notification (Rayfield may be destroyed).")
UpdateLogTab:CreateLabel("- NEW Feature 17 — Rapid Aim Mode Cycle: Configurable keybind cycles Legit → Advanced Legit → Blatant.")
UpdateLogTab:CreateLabel("- NEW Feature 24 — Auto-Update Checker: Checks GitHub version.txt on load and notifies if newer version found.")
UpdateLogTab:CreateLabel("- NEW Feature 27 — Debug Mode: Toggle verbose console output for targeting, threats, and mode switches.")
UpdateLogTab:CreateLabel("- NEW Expanded Theming: 11 new color pickers covering Chams, OOF, Kill Flash, Priority, Threat, Nemesis, Blacklisted.")

UpdateLogTab:CreateSection("Version 2.1.0 (Current Release)")
UpdateLogTab:CreateLabel("- Performance Engine Rewrite: Replaced frame-skip monolith with a 4-slot rotating pipeline.")
UpdateLogTab:CreateLabel("- Pipeline Design: Each slot (ESP scan / Aimbot scan / VoS raycasts / Maintenance) fires one per frame.")
UpdateLogTab:CreateLabel("- Target selection and aim application now run every frame — aimbot is never delayed by performance mode.")
UpdateLogTab:CreateLabel("- Three background task.spawn loops (NPC cache / Workspace sweep / Cache cleanup) replace frame counters.")
UpdateLogTab:CreateLabel("- Silent Aim Fix: Mouse movement (Advanced Legit) is blocked when SA is on; camera modes still drive correctly.")
UpdateLogTab:CreateLabel("- Advanced Legit Rewrite: Smoothstep ease + independent X/Y smoothness sliders + micro-offset humanizer.")
UpdateLogTab:CreateLabel("- Blatant Snap Speed: Configurable 5-100 lerp speed slider (100 = instant, legacy behavior).")
UpdateLogTab:CreateLabel("- Panic Keybind Fix: Uses enum-to-enum comparison via GetKeyCode() — no longer breaks after config restore.")
UpdateLogTab:CreateLabel("- Intelligent Equip Filter: Keyword classifier prevents aimbot activation for non-weapon tools.")
UpdateLogTab:CreateLabel("- Weapon-Type Gating: Triggerbot blocked for classified melee weapons; proximity melee blocked for ranged.")
UpdateLogTab:CreateLabel("- Blacklisted Player ESP: Blacklisted players now show with [BLACKLISTED] tag in orange instead of disappearing.")
UpdateLogTab:CreateLabel("- Hide Blacklisted ESP toggle: Optionally fully hide blacklisted players from ESP instead of tagging them.")
UpdateLogTab:CreateLabel("- VoS Priority Parts: Configurable list of body parts checked first in Visible On Screen mode.")
UpdateLogTab:CreateLabel("- New TASFF_Lists.lua module: Keyword tables for weapons, melee, non-weapons; game configs; feature list.")
UpdateLogTab:CreateLabel("- Session statistics fields added: target locks, trigger fires, threats/nemeses added.")

UpdateLogTab:CreateSection("Version 2.1.0")
UpdateLogTab:CreateLabel("- Final Architecture Push: Consolidated performance, security, and rendering engines.")
UpdateLogTab:CreateLabel("- Aimbot Engine: Moved candidate scanning entirely out of pipeline for zero-delay lock-on.")
UpdateLogTab:CreateLabel("- Threat Neutralization: Instant target death detection added to render loop, fixing delayed threat removal.")
UpdateLogTab:CreateLabel("- Dynamic FOV Auto-Scale: FOV radius grows at close range and shrinks with distance.")
UpdateLogTab:CreateLabel("- Advanced Combat: Health Threshold Gating added to ignore players below specific HP ranges.")
UpdateLogTab:CreateLabel("- Advanced Automation: Auto-Disable Aimbot on Death added to prevent post-death buggy locks.")
UpdateLogTab:CreateLabel("- Threat Intelligence: FP Cooldowns, Prox Radius limits, Velocity direction checks, and Nemesis Decay added.")
UpdateLogTab:CreateLabel("- Security & Metrics: Integrated Anti-AFK watcher, FPS Auto-Tuner, and Notification Throttling.")
UpdateLogTab:CreateLabel("- Storage: Tool Registry Save/Load functionality and Game Config Quick-Load templates implemented.")

UpdateLogTab:CreateSection("Version 2.0.5")

UpdateLogTab:CreateLabel("- The 'Intel Update': Consolidated all player-tracking features into a new centralized Intel Tab.")
UpdateLogTab:CreateLabel("- Visible on Screen (VoS) Rewrite: Now raycasts 20 limbs independently and ignores own body parts.")
UpdateLogTab:CreateLabel("- Priority Behavior Overhaul: Replaced StrictPrioritize with Boost vs. Exclusive dropdown options.")
UpdateLogTab:CreateLabel("- Live Intel Monitor: Dynamic dashboard tracking Marked, Threats, and Nemeses with a points-based heatmap.")
UpdateLogTab:CreateLabel("- Auto-Flag Systems: Kill-Count Threat detection and automated Nemesis Strike system added.")
UpdateLogTab:CreateLabel("- Threat Neutralization: Automatically removes Threat tags when the enemy is neutralized (dies).")
UpdateLogTab:CreateLabel("- Spectator Mode: Bound your camera to any tracked target to monitor them remotely (fixed native conflicts).")
UpdateLogTab:CreateLabel("- Live Kill Feed: Built-in notification feed explicitly designed to debug Intel logic and false positives.")
UpdateLogTab:CreateLabel("- Assorted Bug Fixes: Fixed Sticky Aim gaps, Enum.KeyCode errors on mouse binds, and wallcheck conflicts.")

UpdateLogTab:CreateSection("Version 2.0.0")
UpdateLogTab:CreateLabel("- Version bump to V2.0.0 � modular refactor across 4 files (State/Core/UI/Loader)")
UpdateLogTab:CreateLabel("- Resolved the Lua 200-local engine limit via _G.TASFF_State shared module pattern")
UpdateLogTab:CreateLabel("- Restored the original TASFF black-and-red UI theme with complete monolith feature parity")
UpdateLogTab:CreateLabel("- Completely decoupled ESP rendering from heavy targeting math for butter-smooth 60+ FPS visuals")
UpdateLogTab:CreateLabel("- Multi-hop penetrative wallcheck (up to 15 hops) for advanced glass/decal penetration")
UpdateLogTab:CreateLabel("- Patched frustum culling bug where off-screen targets were dropped, fully restoring OOF Arrows")
UpdateLogTab:CreateLabel("- Fixed Rayfield array-unpacking bugs that previously broke Crosshairs and Visual Mode logic")
UpdateLogTab:CreateLabel("- Added Fine Control Color Pickers for precise Dynamic Visibility (Visible/Hidden) overrides")
UpdateLogTab:CreateLabel("- Frame-scope scalar caching in render loop for reduced overhead")
UpdateLogTab:CreateLabel("- Combined CharacterAdded handler (threat hook + tool observer in one connection)")
UpdateLogTab:CreateLabel("- Re-structured the rendering loop to ensure visual overlays persist accurately on dropped frames")
UpdateLogTab:CreateLabel("- Added UTF-8 BOM stripping and HTML error detection to the module loader")
UpdateLogTab:CreateLabel("- Corrected ConfigurationSaving folder path to match current version")

UpdateLogTab:CreateSection("Version 1.5.0")
UpdateLogTab:CreateLabel("- Completely overhauled the UI layout into professional, structured categories (HUD, Tactical Overlays, etc.)")
UpdateLogTab:CreateLabel("- Fixed a critical metamethod inversion that broke Silent Aim for native weapons and ruined wallchecks")
UpdateLogTab:CreateLabel("- Fixed a math bug where Distance Priority sorted by 2D screen distance instead of true 3D world distance")
UpdateLogTab:CreateLabel("- Fixed drawing persistence glitches (Invisible FOV) by bypassing backend geometry updates when hidden")
UpdateLogTab:CreateLabel("- Fixed missing variable serialization in the Preset Configuration Saver and Factory Reset protocols")
UpdateLogTab:CreateLabel("- Fixed rendering invisibility issues across all ESP geometries (Drawing API transparency mappings)")
UpdateLogTab:CreateLabel("- Added a missing Remove Tool registry function to the Weapon & Inventory Automation section")
UpdateLogTab:CreateLabel("- Patched multiple global scope leaks and a potential fatal crash in the Skeletal Mapping routine")

UpdateLogTab:CreateSection("Version 1.4.5")
UpdateLogTab:CreateLabel("- Added Advanced Legit Mode utilizing Bezier curves for humanized camera smoothing")
UpdateLogTab:CreateLabel("- Added Dynamic Recoil Control (DRC) to mimic natural human recoil compensation")
UpdateLogTab:CreateLabel("- Added Virtual Flickbot (Cursor Aim) to instantly teleport the invisible mouse cursor")
UpdateLogTab:CreateLabel("- Implemented Universal Silent Aim (Namecall Hooking) to redirect bullets silently")
UpdateLogTab:CreateLabel("- Added Target Switch Delay to pause target acquisition after kills (prevents robotic snapping)")
UpdateLogTab:CreateLabel("- Added Randomized Hitboxes to bypass statistical anti-cheats in Legit mode")
UpdateLogTab:CreateLabel("- Implemented The Nemesis System for tiered death tracking and targeted retaliation")
UpdateLogTab:CreateLabel("- Added Marking Input Modes (Mouse, Keybind, or Both) to prevent accidental priority marking")
UpdateLogTab:CreateLabel("- Added Dynamic Visibility Colors (Green=Visible, Red=Hidden) to ESP geometries")
UpdateLogTab:CreateLabel("- Info tag overlay rendering uses ScreenGui for reliable client visibility.")
UpdateLogTab:CreateLabel("- Added Off-Screen Indicators (OOF Arrows) to track targets located behind the camera")
UpdateLogTab:CreateLabel("- Added ESP Snaplines (Tracers) with configurable origin point positioning")
UpdateLogTab:CreateLabel("- Added Clipboard Preset Import & Export (JSON) for easy configuration sharing")
UpdateLogTab:CreateLabel("- Added Auto-Save Configuration protocol to preserve settings upon script unload")

UpdateLogTab:CreateSection("Version 1.4.0")
UpdateLogTab:CreateLabel("- Added Threat Detector & Threat Memory subsystem with configurable timeout")
UpdateLogTab:CreateLabel("- Implemented Strict Prioritize targeting mode")
UpdateLogTab:CreateLabel("- Added Invisible FOV mode (maintains lock boundary without rendering circle)")
UpdateLogTab:CreateLabel("- Added Penetrative Wallchecks (No Collision, Transparency Threshold & Decals)")
UpdateLogTab:CreateLabel("- Implemented Auto ADS (Aim Down Sights) automatic holding")
UpdateLogTab:CreateLabel("- Added Click-to-Mark / Keybind-to-Mark and Focus Mode ESP filtering")
UpdateLogTab:CreateLabel("- Added Triggerbot Click Modes (Virtual vs Physical) & 3rd Person coordinate support")
UpdateLogTab:CreateLabel("- Added Key Triggerbot with Single Press, Mash, and Hold modes")
UpdateLogTab:CreateLabel("- Added Dedicated Advanced Settings Tab and Misc utilities (Panic, Reset, Clean Unload)")
UpdateLogTab:CreateLabel("- Full frame-skipping Performance engine with runtime mode indicator")

UpdateLogTab:CreateSection("Version 1.3.5")
UpdateLogTab:CreateLabel("- Added Aimbot & ESP Render Distance culling sliders (100-1000 studs)")
UpdateLogTab:CreateLabel("- Implemented Target Grace Period delay timer before locking onto targets")
UpdateLogTab:CreateLabel("- Added Chams ESP mode featuring dynamic transparency/opacity controls")
UpdateLogTab:CreateLabel("- Added 2D Box ESP visual overlay")
UpdateLogTab:CreateLabel("- Added Skeleton ESP rendering with full support for R6 & R15 avatar joint structures")
UpdateLogTab:CreateLabel("- Fixed table reference mutation corruption on cached ignore list raycasts")
UpdateLogTab:CreateLabel("- Fixed Melee Mode execution structure to operate independently of Aimbot lock states")
UpdateLogTab:CreateLabel("- Added a brand new Presets Tab featuring profile saving, loading, renaming, and deletion")

UpdateLogTab:CreateSection("Version 1.3.0")
UpdateLogTab:CreateLabel("- Added Target Near Center crosshair prioritization to Combat options")
UpdateLogTab:CreateLabel("- Added Inventory Auto-Activation trigger system upon tool equipping features")
UpdateLogTab:CreateLabel("- Added Instant Tool-Instance Blacklist registration action buttons to Settings")
UpdateLogTab:CreateLabel("- Implemented advanced vector-rendered screen center Crosshairs (Plus, Square, Circle)")
UpdateLogTab:CreateLabel("- Added Crosshair color mapping configurations straight to Customization presets")
UpdateLogTab:CreateLabel("- Added character text extensions: Show Display Name and structural Tool Check tags")

UpdateLogTab:CreateSection("Version 1.2.5")
UpdateLogTab:CreateLabel("- Added full-screen targeting mechanics automatically when FOV visual elements are disabled")
UpdateLogTab:CreateLabel("- Added complete Autoclicker Tab featuring customizable speed interval mechanics")
UpdateLogTab:CreateLabel("- Implemented input options: Repeated rapid Mash triggers vs continuous input Hold states")
UpdateLogTab:CreateLabel("- Added Combat Melee Mode subsystem with independent range and interval calculations")
UpdateLogTab:CreateLabel("- Added fully separated Highlight NPCs and Show NPC Info toggle parameters")
UpdateLogTab:CreateLabel("- Added persistent Sticky Aim mechanics with automatic target validation filters")
UpdateLogTab:CreateLabel("- Fixed Sticky Aim wall clipping bugs by routing locks directly into visibility raycasts")

UpdateLogTab:CreateSection("Version 1.2.0")
UpdateLogTab:CreateLabel("- Added a brand new Customization Tab with color presets")
UpdateLogTab:CreateLabel("- Fixed the respawn bug where player highlights would vanish")
UpdateLogTab:CreateLabel("- Linked the Show Target Info text color directly to custom themes")
UpdateLogTab:CreateLabel("- Removed the broken dynamic interface theme reloader for stability")
UpdateLogTab:CreateLabel("- Added Visible On Screen, located in target bodypart dropdown")

-- // â”€â”€ Load Configuration â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ // --
-- MUST be called last. Restores all flagged values from disk and
-- fires each element's Callback, which writes them back into S.
local ConfigDefaults = {}
for key, value in pairs(S) do
    if typeof(value) ~= "table" and type(value) ~= "function" then
        ConfigDefaults[key] = value
    end
end

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
}
for _, key in ipairs(booleanSettings) do
    if type(S[key]) ~= "boolean" then
        S[key] = ConfigDefaults[key] == true
        correctedSettings = true
    end
end

local numericRanges = {
    FOVSize = {10, 2000}, SwitchDelayMs = {0, 2000}, PredictionAmount = {0, 5},
    Smoothness = {0.1, 100}, SmoothnessX = {0.1, 100}, SmoothnessY = {0.1, 100},
    BlatantSnapSpeed = {1, 100}, TransparencyThreshold = {0, 1},
    GracePeriodMs = {0, 2000}, AimbotRenderDistance = {1, 10000},
    ESPRenderDistance = {1, 10000}, ChamsOpacity = {0, 100}, CrosshairSize = {1, 100},
    OOFArrowRadius = {1, 1000}, ClickInterval = {1, 10000}, MeleeClickInterval = {1, 10000},
    MeleeDetectionRange = {1, 1000}, CalibrationOffsetX = {-2000, 2000},
    CalibrationOffsetY = {-2000, 2000}, DynamicFOVMax = {1, 2000},
    HealthThreshold = {0, 100}, NotifyMaxPer3s = {1, 100},
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
for _, key in ipairs({"BlacklistedPlayers", "PriorityPlayers", "ToolBlacklist", "VOSPriorityParts"}) do
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
        S[key] = clean
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

print("[TASFF UI] Interface constructed. Configuration loaded.")
