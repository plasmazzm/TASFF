-- // ============================================================ // --
-- //   TASFF_loader.lua                                         // --
-- //   Entry point. Run this file in your executor.             // --
-- //   Load order: State → Core → UI                           // --
-- // ============================================================ // --

if not game:IsLoaded() then game.Loaded:Wait() end

local executorCapabilities = {
    FileRead = type(readfile) == "function" and type(isfile) == "function",
    FileWrite = type(writefile) == "function",
    LoadString = type(loadstring) == "function",
    HookMetamethod = type(hookmetamethod) == "function",
    MouseMoveRelative = type(mousemoverel) == "function",
    MouseMoveAbsolute = type(mousemoveabs) == "function",
}

-- // ── Module Source Configuration ──────────────────────────────── // --
-- Set your preferred loading method below.
-- Method A (recommended): Host files on GitHub and use raw URLs.
-- Method B: Load from executor filesystem (if executor supports readfile).

local USE_HTTP   = true      -- true = Method A (HttpGet), false = Method B (readfile)
local BASE_URL   = "https://raw.githubusercontent.com/plasmazzm/TASFF/refs/heads/main/"
-- ^ Replace with your actual GitHub raw base URL, e.g.:
-- "https://raw.githubusercontent.com/tasf/TASFF/main/"
-- Each file will be fetched as BASE_URL .. "TASFF_State.lua" etc.

local function SafeHttpGet(url, label)
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or type(result) ~= "string" or result == "" then
        error("[TASFF Loader] Unable to fetch " .. label .. " from " .. tostring(url))
    end
    return result
end

-- // ── Executor Compatibility Guards ────────────────────────────── // --
-- Stub out functions that may not exist on every executor.
-- These prevent runtime errors on executors missing certain APIs.

if not mousemoveabs then
    function mousemoveabs(x, y) end
end
if not mousemoverel then
    function mousemoverel(x, y) end
end
if not mouse1press then
    function mouse1press() end
end
if not mouse1release then
    function mouse1release() end
end
if not mouse1click then
    function mouse1click()
        mouse1press()
        task.wait(0.01)
        mouse1release()
    end
end

-- Silent aim requires these — stub them if missing (silent aim simply won't work)
if not hookmetamethod then
    warn("[TASFF] hookmetamethod not found — Silent Aim will be unavailable.")
    function hookmetamethod(obj, method, hook) return hook end
end
if not checkcaller then
    function checkcaller() return false end
end
if not getnamecallmethod then
    function getnamecallmethod() return "" end
end

-- Filesystem stubs (preset save/load will be silently disabled if missing)
if not isfile then
    function isfile(path) return false end
end
if not readfile then
    function readfile(path) return "{}" end
end
if not writefile then
    function writefile(path, content) end
end

-- // ── Re-inject Safety ────────────────────────────────────────── // --
-- If TASFF is already running (re-injection), gracefully shut down
-- the previous instance before starting a fresh one.

local previousTASFF = getgenv() and getgenv().TASFF or nil
if previousTASFF and type(previousTASFF) == "table" then
    warn("[TASFF] Previous instance detected — performing clean shutdown.")
    -- Atomically clear the running flag so every loop guard exits on their very next iteration
    previousTASFF.Running = false
    -- Immediately nil the global so no new code can observe the old instance
    getgenv().TASFF = nil

    -- Give background loops two ticks to observe the flag and exit cleanly
    task.wait(0.15)

    -- Restore metamethod hooks + remove drawings + disconnect connections
    if previousTASFF.Cleanup then
        pcall(previousTASFF.Cleanup)
    end

    -- Belt-and-suspenders: also iterate connections directly
    if previousTASFF.Connections then
        for _, conn in pairs(previousTASFF.Connections) do
            pcall(function() conn:Disconnect() end)
        end
    end

    -- Belt-and-suspenders: also iterate drawings directly
    if previousTASFF.Drawings then
        for _, d in pairs(previousTASFF.Drawings) do
            pcall(function()
                if d and d.Frame then d.Frame:Destroy()
                elseif d and d.Remove then d:Remove()
                elseif d and d.Destroy then d:Destroy() end
            end)
        end
    end

    if previousTASFF.Rayfield and previousTASFF.Rayfield.Destroy then
        pcall(function() previousTASFF.Rayfield:Destroy() end)
    end

    local parentsToClean = {}
    pcall(function()
        if typeof(gethui) == "function" then
            local h = gethui()
            if h then table.insert(parentsToClean, h) end
        end
    end)
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then table.insert(parentsToClean, cg) end
    local pg = game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then table.insert(parentsToClean, pg) end

    for _, parent in ipairs(parentsToClean) do
        pcall(function()
            for _, child in ipairs(parent:GetChildren()) do
                if child.Name:find("TASFF") or child.Name:find("Rayfield") or child.Name:find("Sirius") then
                    pcall(function() child:Destroy() end)
                end
            end
        end)
    end

    -- Reset shared state so Core rebuilds everything cleanly
    _G.TASFF_State = nil

    task.wait(0.05)
    warn("[TASFF] Previous instance cleaned up. Restarting...")
end

-- // ── Initialize Runtime Environment ──────────────────────────── // --

getgenv().TASFF = {
    Running              = true,
    Connections          = {},
    Drawings             = {},
    Capabilities         = executorCapabilities,
    Cleanup              = nil,    -- assigned by Core after hooks are set up
    ThreatMonitorRunning = false,
    Rayfield             = nil,    -- assigned below after Rayfield loads
}

local function CleanupPartialRuntime()
    local runtime = getgenv().TASFF
    if not runtime then return end
    runtime.Running = false
    if type(runtime.Cleanup) == "function" then
        pcall(runtime.Cleanup)
    end
    for _, conn in pairs(runtime.Connections or {}) do
        pcall(function() conn:Disconnect() end)
    end
    pcall(function()
        if runtime.Connections then table.clear(runtime.Connections) end
    end)
    for _, drawing in pairs(runtime.Drawings or {}) do
        pcall(function()
            if drawing and drawing.Frame then drawing.Frame:Destroy()
            elseif drawing and drawing.Remove then drawing:Remove()
            elseif drawing and drawing.Destroy then drawing:Destroy() end
        end)
    end
    pcall(function()
        if runtime.Drawings then table.clear(runtime.Drawings) end
    end)
    if runtime.Rayfield and runtime.Rayfield.Destroy then
        pcall(function() runtime.Rayfield:Destroy() end)
    end
    local parentsToClean = {}
    pcall(function()
        if typeof(gethui) == "function" then
            local h = gethui()
            if h then table.insert(parentsToClean, h) end
        end
    end)
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then table.insert(parentsToClean, cg) end
    local pg = game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then table.insert(parentsToClean, pg) end

    for _, parent in ipairs(parentsToClean) do
        pcall(function()
            for _, child in ipairs(parent:GetChildren()) do
                if child.Name:find("TASFF") or child.Name:find("Rayfield") or child.Name:find("Sirius") then
                    pcall(function() child:Destroy() end)
                end
            end
        end)
    end
end

-- // ── Load Rayfield (once) ────────────────────────────────────── // --
-- Rayfield is loaded here and stored in getgenv().TASFF.Rayfield.
-- Core reads it as: local Rayfield = getgenv().TASFF.Rayfield
-- UI reads it the same way. This ensures only ONE Rayfield instance exists.

print("[TASFF Loader] Loading Rayfield...")
if not executorCapabilities.LoadString then
    CleanupPartialRuntime()
    error("[TASFF Loader] This executor does not provide loadstring; modules cannot be compiled.")
end
local cachedRayfieldFactory = nil

local function PlainReplaceFirst(src, target, repl)
    local s, e = string.find(src, target, 1, true)
    if s then
        return string.sub(src, 1, s - 1) .. repl .. string.sub(src, e + 1)
    end
    return src
end

local function PlainReplaceAll(src, target, repl)
    local pos = 1
    while true do
        local s, e = string.find(src, target, pos, true)
        if not s then break end
        src = string.sub(src, 1, s - 1) .. repl .. string.sub(src, e + 1)
        pos = s + #repl
    end
    return src
end

local function PatchRayfieldSource(src)
    if type(src) ~= "string" then return src end
    -- 1. Guard setElementsVisible against missing UIStroke or Title so Hide/Unhide NEVER crashes (Line 1768-1769)
    local t1 = "TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = show and strokeTarget or 1}):Play()"
    local r1 = "local _elStroke = element:FindFirstChildOfClass('UIStroke') or element:FindFirstChild('UIStroke'); if _elStroke then TweenService:Create(_elStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = show and strokeTarget or 1}):Play() end"
    src = PlainReplaceFirst(src, t1, r1)

    local t1_title = "TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = show and titleTarget or 1}):Play()"
    local r1_title = "local _elTitle = element:FindFirstChild('Title') or element:FindFirstChildOfClass('TextLabel'); if _elTitle then TweenService:Create(_elTitle, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = show and titleTarget or 1}):Play() end"
    src = PlainReplaceFirst(src, t1_title, r1_title)

    -- 2. Guard element stroke update on theme switch (Line 1355)
    local t2 = "Element.UIStroke.Color = SelectedTheme.ElementStroke"
    local r2 = "local _elSt2 = Element:FindFirstChildOfClass('UIStroke') or Element:FindFirstChild('UIStroke'); if _elSt2 then _elSt2.Color = SelectedTheme.ElementStroke end"
    src = PlainReplaceFirst(src, t2, r2)

    -- 3. Guard dropdown option stroke updates on theme change when options have been refreshed (Line 3452)
    local t3 = "DropdownOption.UIStroke.Color = SelectedTheme.ElementStroke"
    local r3 = "if DropdownOption and DropdownOption.Parent then local _dSt = DropdownOption:FindFirstChildOfClass('UIStroke') or DropdownOption:FindFirstChild('UIStroke'); if _dSt then _dSt.Color = SelectedTheme.ElementStroke end end"
    src = PlainReplaceFirst(src, t3, r3)

    -- 4. Expose Object/Paragraph reference from CreateParagraph so modules can style preview cards
    src = PlainReplaceFirst(src, "return ParagraphValue", "ParagraphValue.Object = Paragraph; ParagraphValue.Paragraph = Paragraph; return ParagraphValue")

    -- 5. Guard notification Icon so missing or cleaned up notifications never throw (Line 1670)
    local t5 = "newNotification.Icon.Visible = false"
    local r5 = "if newNotification and newNotification.Parent then local _nIcon = newNotification:FindFirstChild('Icon') or newNotification:FindFirstChildOfClass('ImageLabel'); if _nIcon then _nIcon.Visible = false end end"
    src = PlainReplaceFirst(src, t5, r5)

    -- 6. Guard setElementsVisible invocations across Hide, Unhide, Minimise, Maximise with pcall so that
    -- even if any rogue element throws, Debounce and Visible state are 100% guaranteed to reset cleanly.
    src = PlainReplaceAll(src, "setElementsVisible(false)", "pcall(function() setElementsVisible(false) end)")
    src = PlainReplaceAll(src, "setElementsVisible(true)", "pcall(function() setElementsVisible(true) end)")

    -- 7. Patch Tab active & inactive styling so tabs never blackout, active tab borders light up with the active theme accent, and unselected tabs stay bright and readable
    local t7_act_stroke = "TweenService:Create(TabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()"
    local r7_act_stroke = "local _tabAcc = SelectedTheme.SliderProgress or SelectedTheme.ToggleEnabled or SelectedTheme.TabStroke or Color3.fromRGB(240, 175, 50); TabButton.UIStroke.Color = _tabAcc; TabButton.UIStroke.Thickness = 1.5; TweenService:Create(TabButton.UIStroke, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), {Transparency = 0, Color = _tabAcc}):Play()"
    src = PlainReplaceFirst(src, t7_act_stroke, r7_act_stroke)

    local t7_act_txt = "TweenService:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextColor3 = SelectedTheme.SelectedTabTextColor}):Play()"
    local r7_act_txt = "TweenService:Create(TabButton.Title, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), {TextColor3 = Color3.fromRGB(255, 255, 255), TextTransparency = 0}):Play()"
    src = PlainReplaceFirst(src, t7_act_txt, r7_act_txt)

    local t7_act_img = "TweenService:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageColor3 = SelectedTheme.SelectedTabTextColor}):Play()"
    local r7_act_img = "TweenService:Create(TabButton.Image, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), {ImageColor3 = Color3.fromRGB(255, 255, 255), ImageTransparency = 0}):Play()"
    src = PlainReplaceFirst(src, t7_act_img, r7_act_img)

    local t7_oth_txt = "TweenService:Create(OtherTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()"
    local r7_oth_txt = "TweenService:Create(OtherTabButton.Title, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()"
    src = PlainReplaceAll(src, t7_oth_txt, r7_oth_txt)

    local t7_oth_img = "TweenService:Create(OtherTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()"
    local r7_oth_img = "TweenService:Create(OtherTabButton.Image, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()"
    src = PlainReplaceAll(src, t7_oth_img, r7_oth_img)

    local t7_oth_st = "TweenService:Create(OtherTabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()"
    local r7_oth_st = "OtherTabButton.UIStroke.Thickness = 1; TweenService:Create(OtherTabButton.UIStroke, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), {Transparency = 0.65, Color = Color3.fromRGB(50, 50, 62)}):Play()"
    src = PlainReplaceAll(src, t7_oth_st, r7_oth_st)

    local t7_tab_txt = "TweenService:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()"
    local r7_tab_txt = "TweenService:Create(TabButton.Title, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()"
    src = PlainReplaceAll(src, t7_tab_txt, r7_tab_txt)

    local t7_tab_img = "TweenService:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()"
    local r7_tab_img = "TweenService:Create(TabButton.Image, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()"
    src = PlainReplaceAll(src, t7_tab_img, r7_tab_img)

    -- Force SelectedTabTextColor across all internal Rayfield theme definitions to pure white
    src = PlainReplaceAll(src, "SelectedTabTextColor = Color3.fromRGB(50, 50, 50)", "SelectedTabTextColor = Color3.fromRGB(255, 255, 255)")
    src = PlainReplaceAll(src, "SelectedTabTextColor = Color3.fromRGB(20, 50, 50)", "SelectedTabTextColor = Color3.fromRGB(255, 255, 255)")
    src = PlainReplaceAll(src, "SelectedTabTextColor = Color3.fromRGB(50, 30, 10)", "SelectedTabTextColor = Color3.fromRGB(255, 255, 255)")
    src = PlainReplaceAll(src, "SelectedTabTextColor = Color3.fromRGB(0, 0, 0)", "SelectedTabTextColor = Color3.fromRGB(255, 255, 255)")
    src = PlainReplaceAll(src, "SelectedTabTextColor = Color3.fromRGB(50, 20, 50)", "SelectedTabTextColor = Color3.fromRGB(255, 255, 255)")
    src = PlainReplaceAll(src, "SelectedTabTextColor = Color3.fromRGB(20, 60, 20)", "SelectedTabTextColor = Color3.fromRGB(255, 255, 255)")
    src = PlainReplaceAll(src, "SelectedTabTextColor = Color3.fromRGB(50, 30, 50)", "SelectedTabTextColor = Color3.fromRGB(255, 255, 255)")
    src = PlainReplaceAll(src, "SelectedTabTextColor = Color3.fromRGB(30, 35, 40)", "SelectedTabTextColor = Color3.fromRGB(255, 255, 255)")

    -- 8. Patch setTabButtonsVisible (tabbtn, 0.3s tweens) so tabs stay bright on Unhide/Maximise/Minimise
    -- Active tab: UIStroke must light up with accent color (not hide with Transparency=1)
    -- Use multi-line context to target ONLY the "active tab show" case (preceded by TextTransparency=0)
    -- and avoid the "hide all" cases (preceded by ImageTransparency=1)
    local t8_act_stroke = "TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()\n\t\t\t\tTweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()"
    local r8_act_stroke = "TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()\n\t\t\t\tdo local _tbAcc = SelectedTheme.SliderProgress or SelectedTheme.ToggleEnabled or SelectedTheme.TabStroke or Color3.fromRGB(240, 175, 50); tabbtn.UIStroke.Color = _tbAcc; tabbtn.UIStroke.Thickness = 1.5; TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0, Color = _tbAcc}):Play() end"
    src = PlainReplaceFirst(src, t8_act_stroke, r8_act_stroke)
    -- Second occurrence (setTabButtonsVisible function - uses 5-tab indent)
    local t8_act_stroke2 = "TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()\n\t\t\t\t\tTweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()"
    local r8_act_stroke2 = "TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()\n\t\t\t\t\tdo local _tbAcc = SelectedTheme.SliderProgress or SelectedTheme.ToggleEnabled or SelectedTheme.TabStroke or Color3.fromRGB(240, 175, 50); tabbtn.UIStroke.Color = _tbAcc; tabbtn.UIStroke.Thickness = 1.5; TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0, Color = _tbAcc}):Play() end"
    src = PlainReplaceFirst(src, t8_act_stroke2, r8_act_stroke2)

    -- Inactive tab: image stays fully visible (0 instead of 0.2)
    local t8_inactive_img = "TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()"
    local r8_inactive_img = "TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()"
    src = PlainReplaceAll(src, t8_inactive_img, r8_inactive_img)

    -- Inactive tab: title text stays fully visible (0 instead of 0.2)
    local t8_inactive_txt = "TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()"
    local r8_inactive_txt = "TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()"
    src = PlainReplaceAll(src, t8_inactive_txt, r8_inactive_txt)

    -- Inactive tab: UIStroke stays dim but visible (0.65 instead of 0.5, with neutral color)
    local t8_inactive_stroke = "TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()"
    local r8_inactive_stroke = "tabbtn.UIStroke.Thickness = 1; TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0.65, Color = Color3.fromRGB(50, 50, 62)}):Play()"
    src = PlainReplaceAll(src, t8_inactive_stroke, r8_inactive_stroke)

    return src
end

local rayfieldOk, RayfieldOrError = pcall(function()
    local cacheBust = "?t=" .. tostring(tick()) .. "&r=" .. tostring(math.random(100000, 999999))
    local rayfieldSource = SafeHttpGet("https://sirius.menu/rayfield" .. cacheBust, "Rayfield")
    rayfieldSource = PatchRayfieldSource(rayfieldSource)
    local rayfieldFactory, compileError = loadstring(rayfieldSource)
    if type(rayfieldFactory) ~= "function" then
        error("[TASFF Loader] Failed to compile Rayfield bootstrap: " .. tostring(compileError))
    end
    cachedRayfieldFactory = rayfieldFactory
    local instance = rayfieldFactory()
    if type(instance) ~= "table" then
        error("[TASFF Loader] Rayfield bootstrap returned an invalid instance.")
    end
    return instance
end)
if not rayfieldOk then
    CleanupPartialRuntime()
    error("[TASFF Loader] Rayfield initialization failed:\n" .. tostring(RayfieldOrError))
end
local Rayfield = RayfieldOrError
getgenv().TASFF.Rayfield = Rayfield
print("[TASFF Loader] Rayfield loaded.")

-- // ── Module Loader Helper ────────────────────────────────────── // --

local function LoadModule(filename)
    local source
    if USE_HTTP then
        local sep = filename:find("%?") and "&" or "?"
        local cacheBust = sep .. "t=" .. tostring(tick()) .. "&r=" .. tostring(math.random(100000, 999999))
        local url = BASE_URL .. filename .. cacheBust
        source = SafeHttpGet(url, filename)
    else
        -- Method B: load from executor filesystem
        if not isfile(filename) then
            error("[TASFF Loader] File not found: " .. filename .. " — place all TASFF .lua files in your executor workspace folder.")
        end
        source = readfile(filename)
    end

    -- Strip UTF-8 BOM (\xEF\xBB\xBF) — common when files are saved on Windows.
    -- If present it causes "Expected ident" on line 1 since Lua sees garbage bytes first.
    if source:sub(1, 3) == "\239\187\191" then
        source = source:sub(4)
        warn("[TASFF Loader] Stripped UTF-8 BOM from " .. filename)
    end

    -- Guard: if the URL was wrong we might have received an HTML error page.
    local peek = source:sub(1, 20):lower()
    if peek:find("<!doctype") or peek:find("<html") or peek:find("404") then
        error("[TASFF Loader] " .. filename .. " returned an HTML/error page. Check BASE_URL is correct and the repo is Public.")
    end

    -- Note: second arg (chunk name) intentionally omitted — some executors
    -- mishandle it and append the level number to error messages.
    local fn, compileErr = loadstring(source)
    if not fn then
        error("[TASFF Loader] Compile error in " .. filename .. ":\n" .. tostring(compileErr))
    end

    local ok2, runErr = pcall(fn)
    if not ok2 then
        error("[TASFF Loader] Runtime error in " .. filename .. ":\n" .. tostring(runErr))
    end

    print("[TASFF Loader] OK: " .. filename)
end

-- // ── Load Modules in Order ───────────────────────────────────── // --
-- Order is critical:
--   1. State  — defines _G.TASFF_State (all other modules depend on this)
--   2. Lists  — keyword classifiers, feature list, game configs (depends on State)
--   3. Core   — reads S, defines all logic functions and starts loops
--   4. UI     — reads S, builds Rayfield window, sets S.ThreatListLabel etc.,
--               calls Rayfield:LoadConfiguration() at the very end

-- Helper notification for early stages before S.Notify is bound
local function SendLoaderNotify(title, message, icon, duration)
    pcall(function()
        if Rayfield and Rayfield.Notify then
            Rayfield:Notify({
                Title = title or "TASFF Loader",
                Content = message or "",
                Duration = duration or 2.5,
                Image = icon or "info"
            })
        end
    end)
end

local function StartLoadingSequence()
    print("[TASFF Loader] Starting staged initialization sequence...")
    SendLoaderNotify("TASFF Initializing", "Step 1/4: Loading Core State & Classifiers...", "layers", 2)

    local loadOk, loadError = pcall(function()
        -- Stage 1: State & Classifiers
        LoadModule("TASFF_State.lua")   -- _G.TASFF_State = {...}
        LoadModule("TASFF_Lists.lua")   -- classifiers, feature list, game configs
        task.wait(0.08)

        -- Stage 2: Core targeting engine & background workers
        SendLoaderNotify("TASFF Initializing", "Step 2/4: Initializing Targeting Engine & Core...", "cpu", 2)
        LoadModule("TASFF_Core.lua")    -- S.FunctionSlots = ..., registers loops
        task.wait(0.08)

        -- Stage 3: User Interface — theme module first, then controls
        SendLoaderNotify("TASFF Initializing", "Step 3/4: Building Interface Elements...", "layout-grid", 2)
        LoadModule("TASFF_Theme.lua")   -- theme config, window config, palette data
        task.wait(0.03)
        LoadModule("TASFF_UI.lua")      -- Window created, controls rendered, LoadConfiguration() completed
        task.wait(0.1)
    end)
    if not loadOk then
        CleanupPartialRuntime()
        _G.TASFF_State = nil
        SendLoaderNotify("TASFF Error", "Initialization aborted: see console.", "alert-triangle", 5)
        error("[TASFF Loader] Startup aborted and partial runtime was cleaned up:\n" .. tostring(loadError))
    end

    local S = _G.TASFF_State
    S.ScriptInitialized = true

    -- Stage 4: Ready notification
    -- Version is read exclusively from TASFF_State (single source of truth); never hardcoded here.
    task.delay(0.2, function()
        local ver = (S and S.CurrentVersion) or "?"
        if S and S.Notify then
            S.Notify({
                Title    = "TASFF v" .. ver .. " Ready",
                Content  = "All modules loaded stably! Master Switch to begin.",
                Duration = 4,
                Image    = "shield-check",
                BypassThrottle = true,
                Important      = true
            })
        elseif Rayfield and Rayfield.Notify then
            Rayfield:Notify({
                Title    = "TASFF v" .. ver .. " Ready",
                Content  = "All modules loaded stably! Master Switch to begin.",
                Duration = 4,
                Image    = "shield-check"
            })
        end
    end)

    -- Wire restart function
    local function RestartScript()
        if S and S.Notify then
            S.Notify({Title="TASFF System", Content="Restarting script & reloading UI...", Duration=2, Image="refresh-cw"})
        elseif Rayfield and Rayfield.Notify then
            pcall(function() Rayfield:Notify({Title="TASFF System", Content="Restarting script & reloading UI...", Duration=2, Image="refresh-cw"}) end)
        end

        task.delay(0.2, function()
            -- Step 1: Fully unload previous running instance
            if S and S.UnloadScript then
                pcall(function() S.UnloadScript(true) end)
            else
                CleanupPartialRuntime()
            end

            -- Step 2: Ensure old Rayfield window is destroyed
            pcall(function()
                if Rayfield and Rayfield.Destroy then Rayfield:Destroy() end
            end)

            local parentsToClean = {}
            pcall(function()
                if typeof(gethui) == "function" then
                    local h = gethui()
                    if h then table.insert(parentsToClean, h) end
                end
            end)
            local ok, cg = pcall(function() return game:GetService("CoreGui") end)
            if ok and cg then table.insert(parentsToClean, cg) end
            local pg = game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if pg then table.insert(parentsToClean, pg) end

            for _, parent in ipairs(parentsToClean) do
                pcall(function()
                    for _, child in ipairs(parent:GetChildren()) do
                        if child.Name:find("TASFF") or child.Name:find("Rayfield") or child.Name:find("Sirius") then
                            pcall(function() child:Destroy() end)
                        end
                    end
                end)
            end

            _G.TASFF_State = nil
            task.wait(0.25)

            -- Step 3: Re-instantiate Rayfield.
            -- Try the cached factory first (instant, no HTTP round-trip) so that
            -- restarting is offline-safe and near-instantaneous. Only fall back to a
            -- fresh HTTP download if the cached factory itself fails.
            local freshRayfield = nil
            if cachedRayfieldFactory then
                local ok, inst = pcall(cachedRayfieldFactory)
                if ok and type(inst) == "table" then
                    freshRayfield = inst
                end
            end
            if not freshRayfield then
                pcall(function()
                    local cacheBust = "?t=" .. tostring(tick()) .. "&r=" .. tostring(math.random(100000, 999999))
                    local rfSource = SafeHttpGet("https://sirius.menu/rayfield" .. cacheBust, "Rayfield")
                    rfSource = PatchRayfieldSource(rfSource)
                    local fac = loadstring(rfSource)
                    if type(fac) == "function" then
                        cachedRayfieldFactory = fac
                        freshRayfield = fac()
                    end
                end)
            end

            Rayfield = freshRayfield
            getgenv().TASFF = {
                Running              = true,
                Connections          = {},
                Drawings             = {},
                Capabilities         = executorCapabilities,
                Cleanup              = nil,
                ThreatMonitorRunning = false,
                Rayfield             = Rayfield,
                RestartScript        = nil,
            }

            -- Step 4: Re-run staged loading sequence
            StartLoadingSequence()
        end)
    end
    getgenv().TASFF.RestartScript = RestartScript
    S.RestartScript = RestartScript
end

StartLoadingSequence()

local S = _G.TASFF_State

-- Feature 24: Auto-Update Version Checker
task.spawn(function()
    task.wait(2)  -- let game fully settle
    if S and S.CheckForUpdates then
        pcall(function()
            S.CheckForUpdates(false)
        end)
    end
end)

print("[TASFF Loader] ══ All modules loaded. TASFF v" .. tostring(S and S.CurrentVersion or "?") .. " is running. ══")
