-- // ============================================================ // --
-- //   TASFF_loader.lua                                         // --
-- //   Entry point. Run this file in your executor.             // --
-- //   Load order: State → Core → UI                           // --
-- // ============================================================ // --

if not game:IsLoaded() then game.Loaded:Wait() end

-- // ── Module Source Configuration ──────────────────────────────── // --
-- Set your preferred loading method below.
-- Method A (recommended): Host files on GitHub and use raw URLs.
-- Method B: Load from executor filesystem (if executor supports readfile).

local USE_HTTP   = true      -- true = Method A (HttpGet), false = Method B (readfile)
local BASE_URL   = "https://raw.githubusercontent.com/plasmazzm/TASFF/refs/heads/main/"
-- ^ Replace with your actual GitHub raw base URL, e.g.:
-- "https://raw.githubusercontent.com/tasf/TASFF/main/"
-- Each file will be fetched as BASE_URL .. "TASFF_State.lua" etc.

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

if getgenv().TASFF then
    warn("[TASFF] Previous instance detected — performing clean shutdown.")
    getgenv().TASFF.Running = false

    -- Give background loops one tick to read the flag and exit
    task.wait(0.1)

    -- Restore metamethod hooks + remove drawings + disconnect connections
    if getgenv().TASFF.Cleanup then
        pcall(getgenv().TASFF.Cleanup)
    end

    -- Belt-and-suspenders: also iterate connections directly
    if getgenv().TASFF.Connections then
        for _, conn in pairs(getgenv().TASFF.Connections) do
            if typeof(conn) == "RBXScriptConnection" and conn.Connected then
                pcall(function() conn:Disconnect() end)
            end
        end
    end

    -- Belt-and-suspenders: also iterate drawings directly
    if getgenv().TASFF.Drawings then
        for _, d in ipairs(getgenv().TASFF.Drawings) do
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
    Cleanup              = nil,    -- assigned by Core after hooks are set up
    ThreatMonitorRunning = false,
    Rayfield             = nil,    -- assigned below after Rayfield loads
}

-- // ── Load Rayfield (once) ────────────────────────────────────── // --
-- Rayfield is loaded here and stored in getgenv().TASFF.Rayfield.
-- Core reads it as: local Rayfield = getgenv().TASFF.Rayfield
-- UI reads it the same way. This ensures only ONE Rayfield instance exists.

print("[TASFF Loader] Loading Rayfield...")
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
getgenv().TASFF.Rayfield = Rayfield
print("[TASFF Loader] Rayfield loaded.")

-- // ── Module Loader Helper ────────────────────────────────────── // --

local function LoadModule(filename)
    local source
    if USE_HTTP then
        local url = BASE_URL .. filename
        local ok, result = pcall(function()
            return game:HttpGet(url)
        end)
        if not ok or not result or result == "" then
            error("[TASFF Loader] Failed to fetch " .. filename .. ". Check BASE_URL and that the repo is Public.")
        end
        source = result
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
--   2. Core   — reads S, defines all logic functions and starts loops
--   3. UI     — reads S, builds Rayfield window, sets S.ThreatListLabel etc.,
--               calls Rayfield:LoadConfiguration() at the very end

print("[TASFF Loader] Loading modules...")

LoadModule("TASFF_State.lua")   -- _G.TASFF_State = {...}
LoadModule("TASFF_Core.lua")    -- S.FunctionSlots = ..., render loop starts
LoadModule("TASFF_UI.lua")      -- Window created, LoadConfiguration() called

-- // ── Post-Init ───────────────────────────────────────────────── // --
-- At this point:
--   • _G.TASFF_State is fully populated with function slots from Core
--   • All UI elements exist and have set their S.* refs (ThreatListLabel, etc.)
--   • Rayfield:LoadConfiguration() has run and callbacks restored S.* values
--   • Core's task.defer will set S.ScriptInitialized = true after ~0.2s
--   • S.SavedPresets was already loaded by Core (LoadPresetsFromFile)

local S = _G.TASFF_State

-- Final notify (fires after ScriptInitialized is set by Core's deferred task)
task.delay(0.4, function()
    if S.Notify then
        S.Notify({
            Title    = "TASFF v2.0.0",
            Content  = "Script loaded successfully. Master Switch to begin.",
            Duration = 4,
            Image    = "shield-check"
        })
    end
end)

print("[TASFF Loader] ══ All modules loaded. TASFF v2.0.0 is running. ══")
