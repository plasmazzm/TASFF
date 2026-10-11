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
    previousTASFF.Running = false

    -- Give background loops one tick to read the flag and exit
    task.wait(0.1)

    -- Restore metamethod hooks + remove drawings + disconnect connections
    if previousTASFF.Cleanup then
        pcall(previousTASFF.Cleanup)
    end

    -- Belt-and-suspenders: also iterate connections directly
    if previousTASFF.Connections then
        for _, conn in pairs(previousTASFF.Connections) do
            if conn and typeof(conn) == "RBXScriptConnection" and conn.Connected then
                pcall(function() conn:Disconnect() end)
            end
        end
    end

    -- Belt-and-suspenders: also iterate drawings directly
    if previousTASFF.Drawings then
        for _, d in ipairs(previousTASFF.Drawings) do
            pcall(function() d:Remove() end)
        end
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
    for _, conn in ipairs(runtime.Connections or {}) do
        if conn and typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    for _, drawing in ipairs(runtime.Drawings or {}) do
        pcall(function() drawing:Remove() end)
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
local rayfieldOk, RayfieldOrError = pcall(function()
    local rayfieldSource = SafeHttpGet("https://sirius.menu/rayfield", "Rayfield")
    local rayfieldFactory, compileError = loadstring(rayfieldSource)
    if type(rayfieldFactory) ~= "function" then
        error("[TASFF Loader] Failed to compile Rayfield bootstrap: " .. tostring(compileError))
    end
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
        local url = BASE_URL .. filename
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

    -- Stage 3: User Interface & controls
    SendLoaderNotify("TASFF Initializing", "Step 3/4: Building Interface Elements...", "layout-grid", 2)
    LoadModule("TASFF_UI.lua")      -- Window created, controls rendered, LoadConfiguration() completed
    task.wait(0.1)
end)
if not loadOk then
    CleanupPartialRuntime()
    _G.TASFF_State = nil
    SendLoaderNotify("TASFF Error", "Initialization aborted: see console.", "alert-triangle", 5)
    error("[TASFF Loader] Startup aborted and partial runtime was cleaned up:\n" .. tostring(loadError))
end

-- // ── Post-Init ───────────────────────────────────────────────── // --
-- At this point:
--   • _G.TASFF_State is fully populated with function slots from Core
--   • All UI elements exist and have set their S.* refs (ThreatListLabel, etc.)
--   • Rayfield:LoadConfiguration() has run and callbacks restored S.* values
--   • Mark S.ScriptInitialized = true now that all modules have settled
--   • S.SavedPresets was already loaded by Core (LoadPresetsFromFile)

local S = _G.TASFF_State
S.ScriptInitialized = true

-- Stage 4: Ready notification
task.delay(0.2, function()
    if S.Notify then
        S.Notify({
            Title    = "TASFF v2.2.0 Ready",
            Content  = "All modules loaded stably! Master Switch to begin.",
            Duration = 4,
            Image    = "shield-check"
        })
    elseif Rayfield and Rayfield.Notify then
        Rayfield:Notify({
            Title    = "TASFF v2.2.0 Ready",
            Content  = "All modules loaded stably! Master Switch to begin.",
            Duration = 4,
            Image    = "shield-check"
        })
    end
end)

-- Feature 24: Auto-Update Version Checker
task.spawn(function()
    task.wait(2)  -- let game fully settle
    local ok, result = pcall(function()
        return game:GetService("HttpService"):GetAsync(
            "https://raw.githubusercontent.com/plasmazzm/TASFF/refs/heads/main/version.txt", true)
    end)
    if ok and result then
        local remote = result:match("([%d%.]+)")
        local current = S.CurrentVersion or "2.2.0"
        if remote and remote ~= current then
            if S.Notify then
                S.Notify({Title="TASFF Update", Content="v"..remote.." available! Re-execute to update.", Duration=8, Image="arrow-up-circle"})
            end
        end
    end
end)

print("[TASFF Loader] ══ All modules loaded. TASFF v2.2.0 is running. ══")
