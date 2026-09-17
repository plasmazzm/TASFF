-- // ============================================================ // --
-- //   TASFF_Core.lua                                            // --
-- //   All logic, rendering, and combat functions.               // --
-- //   Reads/writes shared state via:                            // --
-- //       local S = _G.TASFF_State                             // --
-- //   Rayfield is injected by the Loader:                       // --
-- //       local Rayfield = getgenv().TASFF.Rayfield             // --
-- // ============================================================ // --

-- // Services // --
local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService          = game:GetService("GuiService")
local HttpService         = game:GetService("HttpService")
local CoreGui             = game:GetService("CoreGui")

-- // Shared State & Runtime References // --
local S       = _G.TASFF_State
do
    local part = S.TargetPart
    if type(part) ~= "string" or part == "" or part == "Visible On Screen" then
        S.ActivePartName = (type(S.ActivePartName) == "string" and S.ActivePartName) or "Head"
    else
        S.ActivePartName = S.ActivePartName or part
    end
end
local Rayfield = getgenv().TASFF and getgenv().TASFF.Rayfield or nil
local Player  = Players.LocalPlayer
local Camera  = workspace.CurrentCamera

-- // Local Table Aliases // --
-- Safe to alias: these tables are only ever mutated (key/value set),
-- never reassigned. Aliasing avoids repeated _G lookups every frame.
local HighlightCache            = S.HighlightCache
local TagCache                  = S.TagCache
local BoxCache                  = S.BoxCache
local SkeletonCache             = S.SkeletonCache
local SnaplineCache             = S.SnaplineCache
local OOFArrowCache             = S.OOFArrowCache
local ThreatMemory              = S.ThreatMemory
local NemesisMemory             = S.NemesisMemory
local FrameCounters             = S.FrameCounters
local PerformanceIntervals      = S.PerformanceIntervals
local NPCIntervals              = S.NPCIntervals
local SweepIntervals            = S.SweepIntervals
local CacheIntervals            = S.CacheIntervals
local R15Joints                 = S.R15Joints
local R6Joints                  = S.R6Joints
local CrosshairElements         = S.CrosshairElements
local TargetFirstSeenTimestamps = S.TargetFirstSeenTimestamps
local VisibilityCache           = S.VisibilityCache
local VisibilityCacheTime       = S.VisibilityCacheTime

-- Keep Camera reference live across workspace camera switches
table.insert(getgenv().TASFF.Connections,
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        Camera = workspace.CurrentCamera
    end)
)

-- // ── Utility ────────────────────────────────────────────────── // --

local function GetKeyCode(name)
    if type(name) ~= "string" or name == "" then return nil end
    if name:match("^MouseButton") then return nil end
    local ok, result = pcall(function()
        return Enum.KeyCode[name] or Enum.KeyCode[name:upper()]
    end)
    return (ok and result) or nil
end
S.GetKeyCode = GetKeyCode

local function Notify(options)
    if not S.DisableNotifications and Rayfield and Rayfield.Notify then
        pcall(function() Rayfield:Notify(options) end)
    end
end
S.Notify = Notify

-- // ── Drawing Helpers ─────────────────────────────────────────── // --

local function NewDrawing(className)
    if not (Drawing and Drawing.new) then return nil end
    local ok, obj = pcall(Drawing.new, className)
    if not ok or obj == nil then return nil end
    pcall(function()
        obj.Visible = false
        obj.ZIndex  = 60
        obj.Transparency = 1
        if obj.Opacity ~= nil then obj.Opacity = 1 end
    end)
    if getgenv().TASFF and type(getgenv().TASFF.Drawings) == "table" then
        table.insert(getgenv().TASFF.Drawings, obj)
    end
    return obj
end
S.NewDrawing = NewDrawing

local function PrepareDrawing(obj)
    if not obj then return end
    pcall(function()
        obj.ZIndex = 60
        obj.Transparency = 1
        if obj.Opacity ~= nil then obj.Opacity = 1 end
    end)
end
S.PrepareDrawing = PrepareDrawing

-- // ── Visual Cleanup ──────────────────────────────────────────── // --

local function ClearVisuals()
    for _, h in pairs(HighlightCache) do
        if h and typeof(h) == "Instance" and h.Parent then h.Enabled = false end
    end
    for _, t in pairs(TagCache) do
        if t then
            if typeof(t) == "Instance" and t:IsA("BillboardGui") then
                t.Enabled = false
            elseif typeof(t) ~= "Instance" then
                pcall(function() t.Visible = false end)
            end
        end
    end
    for _, box in pairs(BoxCache) do if box then box.Visible = false end end
    for _, lines in pairs(SkeletonCache) do
        if type(lines) == "table" then
            for _, limb in pairs(lines) do
                if limb and limb.Line then pcall(function() limb.Line.Visible = false end) end
            end
        end
    end
    for _, line in pairs(SnaplineCache) do if line then pcall(function() line.Visible = false end) end end
    for _, arrow in pairs(OOFArrowCache) do if arrow then pcall(function() arrow.Visible = false end) end end
end
S.ClearVisuals = ClearVisuals

local function ClearCrosshair()
    for _, element in pairs(CrosshairElements) do
        if element then element.Visible = false end
    end
end
S.ClearCrosshair = ClearCrosshair

local function InitializeCrosshair()
    CrosshairElements.Dot = NewDrawing("Circle")
    if CrosshairElements.Dot then
        CrosshairElements.Dot.Filled    = true
        CrosshairElements.Dot.Thickness = 1
        CrosshairElements.Dot.Radius    = 2
    end
    CrosshairElements.Top    = NewDrawing("Line")
    CrosshairElements.Bottom = NewDrawing("Line")
    CrosshairElements.Left   = NewDrawing("Line")
    CrosshairElements.Right  = NewDrawing("Line")
    for _, k in ipairs({"Top","Bottom","Left","Right"}) do
        if CrosshairElements[k] then CrosshairElements[k].Thickness = 2 end
    end
    CrosshairElements.Square = NewDrawing("Square")
    if CrosshairElements.Square then
        CrosshairElements.Square.Filled    = false
        CrosshairElements.Square.Thickness = 2
    end
    CrosshairElements.Circle = NewDrawing("Circle")
    if CrosshairElements.Circle then
        CrosshairElements.Circle.Filled    = false
        CrosshairElements.Circle.Thickness = 2
    end
end

local function EnsureDrawings()
    if S.DrawingsReady then
        PrepareDrawing(S.FOVCircle)
        return S.FOVCircle ~= nil
    end
    S.FOVCircle = NewDrawing("Circle")
    if not S.FOVCircle then return false end
    S.FOVCircle.Thickness = 2
    S.FOVCircle.Filled    = false
    S.FOVCircle.Color     = S.FOVColor or Color3.fromRGB(0, 255, 255)
    InitializeCrosshair()
    S.DrawingsReady = true
    return true
end
S.EnsureDrawings = EnsureDrawings

-- Color updater helpers (called by TASFF_UI.lua Theming tab callbacks)
_G.UpdateCrosshairColor = function(newColor)
    S.CrosshairColor = newColor
    for _, el in pairs(CrosshairElements) do
        if el then el.Color = newColor end
    end
end
_G.UpdateFOVCircleColor = function(newColor)
    S.FOVColor = newColor
    if S.FOVCircle then S.FOVCircle.Color = newColor end
end

-- // ── Calibration & Aim Origin ────────────────────────────────── // --

local function ApplyScreenCalibration(point)
    if not S.ManualCalibrationEnabled then return point end
    return point + Vector2.new(S.CalibrationOffsetX, S.CalibrationOffsetY)
end
S.ApplyScreenCalibration = ApplyScreenCalibration

local function GetAimPosition()
    local position
    if S.AimReferenceMode == "Mouse Tracking" then
        position = UserInputService:GetMouseLocation()
    else
        position = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
    end
    if S.ManualCalibrationEnabled then
        position = position + Vector2.new(S.CalibrationOffsetX, S.CalibrationOffsetY)
    end
    return position
end
S.GetAimPosition = GetAimPosition

-- // ── Auto ADS ────────────────────────────────────────────────── // --

local function GetMouseButtonIndex(name)
    if name == "MouseButton1" then return 0 end
    if name == "MouseButton2" then return 1 end
    if name == "MouseButton3" then return 2 end
    return nil
end

local function SetADSState(state)
    local mouseBtn = GetMouseButtonIndex(S.AutoADSKeybind)
    local function press(down)
        if mouseBtn ~= nil then
            VirtualInputManager:SendMouseButtonEvent(0, 0, mouseBtn, down, game, 0)
        else
            pcall(function()
                local key = GetKeyCode(S.AutoADSKeybind)
                if key then VirtualInputManager:SendKeyEvent(down, key, false, game) end
            end)
        end
    end
    if state and not S.IsHoldingADS then
        S.IsHoldingADS = true
        press(true)
    elseif not state and S.IsHoldingADS then
        S.IsHoldingADS = false
        press(false)
    end
end
S.SetADSState = SetADSState

-- // ── Panic & Unload ──────────────────────────────────────────── // --

local function TriggerPanic()
    S.MasterEnabled = false
    S.AimbotActive  = false
    S.CurrentTarget = nil
    SetADSState(false)
    if S.IsHoldingClick then
        S.IsHoldingClick = false
        local loc = UserInputService:GetMouseLocation()
        VirtualInputManager:SendMouseButtonEvent(loc.X, loc.Y, 0, false, game, 0)
    end
    if S.IsHoldingTriggerKey then
        S.IsHoldingTriggerKey = false
        pcall(function()
            local key = GetKeyCode(S.KeyTriggerbotKey)
            if key then VirtualInputManager:SendKeyEvent(false, key, false, game) end
        end)
    end
    ClearVisuals()
    ClearCrosshair()
    if S.FOVCircle then S.FOVCircle.Visible = false end
    Notify({Title = "TASFF Panic", Content = "All combat & visual routines halted.", Duration = 3, Image = "octagon-pause"})
end
S.TriggerPanic = TriggerPanic

local function UnloadScript()
    TriggerPanic()
    if getgenv().TASFF then getgenv().TASFF.Running = false end
    if getgenv().TASFF and getgenv().TASFF.Cleanup then
        getgenv().TASFF.Cleanup()
    end
    if getgenv().TASFF and getgenv().TASFF.Connections then
        for _, conn in ipairs(getgenv().TASFF.Connections) do
            pcall(function() conn:Disconnect() end)
        end
    end
    Notify({Title = "TASFF", Content = "Script and interface fully unloaded.", Duration = 2, Image = "log-out"})
    pcall(function()
        if Rayfield and Rayfield.Destroy then Rayfield:Destroy() end
    end)
    pcall(function()
        for _, gui in ipairs(CoreGui:GetChildren()) do
            if gui.Name:find("Rayfield") or gui.Name:find("Sirius") then
                gui:Destroy()
            end
        end
    end)
end
S.UnloadScript = UnloadScript

-- // ── Player Names & Priority UI Sync ─────────────────────────── // --

local function GetPlayerNames()
    local names = {}
    for _, v in ipairs(Players:GetPlayers()) do
        if v ~= Player then table.insert(names, v.Name) end
    end
    return names
end
S.GetPlayerNames = GetPlayerNames

local function SyncPriorityUI()
    if S.PriorityDropdownRef and S.PriorityDropdownRef.Refresh then
        pcall(function()
            S.PriorityDropdownRef:Refresh(GetPlayerNames(), S.PriorityPlayers)
        end)
    end
    if S.PriorityMonitorLabel then
        local text = ""
        for _, name in ipairs(S.PriorityPlayers) do
            text = text .. "• " .. name .. "\n"
        end
        if text == "" then text = "No priority targets currently selected." end
        pcall(function()
            S.PriorityMonitorLabel:Set({
                Title   = "Active Priority Targets (" .. #S.PriorityPlayers .. ")",
                Content = text
            })
        end)
    end
end
S.SyncPriorityUI = SyncPriorityUI

-- Player join/leave: refresh dropdowns
table.insert(getgenv().TASFF.Connections, Players.PlayerAdded:Connect(function()
    task.defer(SyncPriorityUI)
end))
table.insert(getgenv().TASFF.Connections, Players.PlayerRemoving:Connect(function()
    task.defer(SyncPriorityUI)
end))

-- // ── Workspace Cache & Ignore List ───────────────────────────── // --

local function UpdateWorkspaceIgnores()
    local temp = {}
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and not Players:GetPlayerFromCharacter(child) then
            local nameLower = child.Name:lower()
            local shouldIgnore = nameLower:find("viewmodel") or nameLower:find("arms")
                              or nameLower:find("weapon")    or nameLower:find("gun")
                              or nameLower:find("scope")     or nameLower:find("lens")
            if Player and Player.Character then
                local heldTool = Player.Character:FindFirstChildOfClass("Tool")
                if heldTool and nameLower:find(heldTool.Name:lower(), 1, true) then
                    shouldIgnore = true
                end
            end
            if shouldIgnore then table.insert(temp, child) end
        end
    end
    S.CachedWorkspaceIgnores = temp
end
S.UpdateWorkspaceIgnores = UpdateWorkspaceIgnores

local function GetIgnoreList()
    local ignoreSet  = {}
    local ignoreList = {}
    local function add(obj)
        if obj and not ignoreSet[obj] then
            ignoreSet[obj] = true
            table.insert(ignoreList, obj)
        end
    end
    add(Camera)
    add(CoreGui)
    if Player and Player.Character then
        add(Player.Character)
        local heldTool = Player.Character:FindFirstChildOfClass("Tool")
        if heldTool then add(heldTool) end
    end
    for _, item in ipairs(S.CachedWorkspaceIgnores) do add(item) end
    return ignoreList
end
S.GetIgnoreList = GetIgnoreList

-- // ── Multi-Hop Penetrative Wallcheck ─────────────────────────── // --

local IsVisibleWallcheck
IsVisibleWallcheck = function(model, partName, customIgnoreList)
    if not model then return false end
    local resolvedName = (type(partName) == "string" and partName ~= "" and partName ~= "Visible On Screen")
        and partName or "HumanoidRootPart"
    local targetPart = model:FindFirstChild(resolvedName) or model:FindFirstChild("HumanoidRootPart")
    if not targetPart then return false end
    if not Camera then Camera = workspace.CurrentCamera end

    local origin      = Camera.CFrame.Position
    local destination = targetPart.Position
    local direction   = destination - origin
    local maxDist     = direction.Magnitude
    if maxDist <= 0.01 then return true end
    local unitDir = direction.Unit

    -- Avoid cloning unless a penetrable object is actually hit
    local baseIgnoreList    = customIgnoreList or GetIgnoreList()
    local currentIgnoreList = baseIgnoreList
    local hasClonedList     = false
    local currentOrigin     = origin
    local hops    = 0
    local maxHops = (S.NoCollisionCheck or S.TransparencyCheck or S.DecalsCheck) and 15 or 1

    while hops < maxHops do
        local remainingDist = (destination - currentOrigin).Magnitude
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = currentIgnoreList
        rp.IgnoreWater = true

        local result = workspace:Raycast(currentOrigin, unitDir * remainingDist, rp)
        if not result then return true end

        local hit = result.Instance
        if hit == targetPart or hit:IsDescendantOf(model) then return true end

        local canPass = false
        if S.NoCollisionCheck and not hit.CanCollide then
            canPass = true
        elseif S.TransparencyCheck and hit.Transparency >= S.TransparencyThreshold then
            canPass = true
        elseif S.DecalsCheck and (hit:FindFirstChildOfClass("Decal") or hit:FindFirstChildOfClass("Texture")) then
            canPass = true
        end

        if canPass then
            if not hasClonedList then
                local newList = {}
                for _, v in ipairs(baseIgnoreList) do table.insert(newList, v) end
                currentIgnoreList = newList
                hasClonedList = true
            end
            table.insert(currentIgnoreList, hit)
            currentOrigin = result.Position + (unitDir * 0.05)
            hops = hops + 1
        else
            return false
        end
    end
    return false
end
S.IsVisibleWallcheck = IsVisibleWallcheck

-- Visibility cache wrapper (50ms TTL)
local function IsVisibleCachedWrapper(model, partName, ignoreList)
    local now = tick()
    if VisibilityCache[model] and VisibilityCache[model].Part == partName
       and (now - (VisibilityCacheTime[model] or 0) < 0.05) then
        return VisibilityCache[model].Result
    end
    local result = IsVisibleWallcheck(model, partName, ignoreList)
    VisibilityCache[model]     = {Part = partName, Result = result}
    VisibilityCacheTime[model] = now
    return result
end
S.IsVisibleCachedWrapper = IsVisibleCachedWrapper

-- // ── Threat System ────────────────────────────────────────────── // --

local function RegisterThreat(attackerName, isKill)
    if not attackerName or attackerName == Player.Name then return end
    if isKill then
        if S.NemesisEnabled then
            NemesisMemory[attackerName] = tick()
            Notify({Title = "TASFF Nemesis", Content = attackerName .. " killed you. Added to Nemesis List.", Duration = 3, Image = "flame"})
        end
    else
        ThreatMemory[attackerName] = tick()
    end
    if not table.find(S.PriorityPlayers, attackerName) then
        table.insert(S.PriorityPlayers, attackerName)
        SyncPriorityUI()
        if not isKill then
            Notify({Title = "TASFF Threat", Content = "Registered Threat: " .. attackerName, Duration = 2, Image = "alert-circle"})
        end
    end
end

local function HookThreatHealth(char)
    if not char then return end
    local humanoid = char:WaitForChild("Humanoid", 3)
    if not humanoid then return end
    local lastHealth = humanoid.Health
    humanoid.HealthChanged:Connect(function(newHealth)
        if S.ThreatDetectorEnabled and newHealth < lastHealth then
            local isKill = (newHealth <= 0)
            if isKill and S.CurrentTarget and char == S.CurrentTarget.Instance then
                S.LastKillTime  = tick()
                S.CurrentTarget = nil
            end
            local creator = humanoid:FindFirstChild("creator") or humanoid:FindFirstChild("creatorTag")
            if creator and creator:IsA("ObjectValue") and creator.Value and creator.Value:IsA("Player") then
                RegisterThreat(creator.Value.Name, isKill)
            else
                local myPos = char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position
                if myPos then
                    local nearestAttacker, nearestDist = nil, 250
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                            local d = (p.Character.HumanoidRootPart.Position - myPos).Magnitude
                            if d < nearestDist then nearestDist = d; nearestAttacker = p.Name end
                        end
                    end
                    if nearestAttacker then RegisterThreat(nearestAttacker, isKill) end
                end
            end
        end
        lastHealth = newHealth
    end)
end

-- Threat expiry background loop
task.spawn(function()
    while getgenv().TASFF and getgenv().TASFF.Running do
        task.wait(0.5)
        local now     = tick()
        local changed = false
        for name, timestamp in pairs(ThreatMemory) do
            if now - timestamp >= S.ThreatTimeout then
                ThreatMemory[name] = nil
                local idx = table.find(S.PriorityPlayers, name)
                if idx then
                    table.remove(S.PriorityPlayers, idx)
                    changed = true
                end
                if S.BlacklistExpiredThreats and not table.find(S.BlacklistedPlayers, name) then
                    table.insert(S.BlacklistedPlayers, name)
                    Notify({Title = "TASFF Threat Memory", Content = name .. " expired -> Moved to Blacklist", Duration = 2, Image = "ban"})
                else
                    Notify({Title = "TASFF Threat Memory", Content = "Threat Expired: " .. name, Duration = 2, Image = "hourglass"})
                end
            end
        end
        if changed then SyncPriorityUI() end
    end
end)

-- Threat monitor label update loop (reads S.ThreatListLabel assigned by TASFF_UI.lua)
task.spawn(function()
    if getgenv().TASFF then getgenv().TASFF.ThreatMonitorRunning = true end
    while getgenv().TASFF and getgenv().TASFF.Running and getgenv().TASFF.ThreatMonitorRunning do
        task.wait(1)
        local now  = tick()
        local text = ""
        for name, ts in pairs(ThreatMemory) do
            local rem = math.max(0, math.floor(S.ThreatTimeout - (now - ts)))
            text = text .. "• " .. name .. " (" .. rem .. "s remaining)\n"
        end
        if text == "" then text = "No active threats detected." end
        if S.ThreatListLabel then
            pcall(function()
                S.ThreatListLabel:Set({Title = "Live Threat Monitor", Content = text})
            end)
        end
    end
end)

-- // ── Click-to-Mark ────────────────────────────────────────────── // --

local function HandleClickToMark()
    local mouse      = Player:GetMouse()
    local rawLoc     = UserInputService:GetMouseLocation()
    local inset      = GuiService:GetGuiInset()
    local mouseLoc   = rawLoc - inset
    local targetName = nil

    -- Pass 1: Direct 3D mouse target (most accurate)
    if mouse and mouse.Target then
        local hitModel = mouse.Target:FindFirstAncestorOfClass("Model")
        if hitModel then
            local p = Players:GetPlayerFromCharacter(hitModel)
            if p and p ~= Player then
                targetName = p.Name
            elseif S.TargetNPCs and hitModel:FindFirstChildOfClass("Humanoid") and hitModel ~= Player.Character then
                targetName = hitModel.Name
            end
        end
    end

    -- Pass 2: Hybrid ray + 2D proximity fallback
    if not targetName then
        local ray       = Camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
        local bestScore = 999999
        local function checkModel(model, name)
            if not model then return end
            for _, pn in ipairs({"Head","HumanoidRootPart","Torso","UpperTorso"}) do
                local part = model:FindFirstChild(pn)
                if part and part:IsA("BasePart") then
                    local dir       = ray.Direction.Unit
                    local toPoint   = part.Position - ray.Origin
                    local distToRay = (toPoint - dir * toPoint:Dot(dir)).Magnitude
                    local sPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen and sPos.Z > 0 then
                        local dist2D = (Vector2.new(sPos.X, sPos.Y) - mouseLoc).Magnitude
                        if distToRay <= 15 or dist2D <= 180 then
                            local score = dist2D + (distToRay * 10)
                            if score < bestScore then bestScore = score; targetName = name end
                        end
                    end
                end
            end
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Player and p.Character then checkModel(p.Character, p.Name) end
        end
        if S.TargetNPCs then
            for _, npc in ipairs(S.CachedNPCs) do checkModel(npc, npc.Name) end
        end
    end

    if targetName then
        local idx = table.find(S.PriorityPlayers or {}, targetName)
        if idx then
            table.remove(S.PriorityPlayers, idx)
            SyncPriorityUI()
            Notify({Title = "TASFF Mark", Content = "Unmarked " .. targetName .. " from Priority.", Duration = 2, Image = "minus-circle"})
        else
            table.insert(S.PriorityPlayers, targetName)
            SyncPriorityUI()
            Notify({Title = "TASFF Mark", Content = "Marked " .. targetName .. " as Priority!", Duration = 2, Image = "crosshair"})
        end
    else
        Notify({Title = "TASFF Mark", Content = "No target detected near cursor.", Duration = 1.5, Image = "locate-off"})
    end
end
S.HandleClickToMark = HandleClickToMark

-- Universal input listener: Panic + Click-to-Mark
table.insert(getgenv().TASFF.Connections, UserInputService.InputBegan:Connect(function(input, gpe)
    if input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode.Name == S.PanicKeybind then
        TriggerPanic()
        return
    end
    if S.ClickToMarkEnabled
       and (S.MarkMethod == "Mouse Click Only" or S.MarkMethod == "Both")
       and input.UserInputType == Enum.UserInputType.MouseButton1 then
        if UserInputService:GetFocusedTextBox() then return end
        if S.MasterEnabled and S.AimbotActive and S.CurrentTarget ~= nil then return end
        local toolEquipped = Player.Character and Player.Character:FindFirstChildOfClass("Tool") ~= nil
        if toolEquipped then return end
        HandleClickToMark()
    end
end))

-- // ── Performance Scheduler ────────────────────────────────────── // --

local function NormalizePerformanceMode(mode)
    if type(mode) ~= "string" then return "Medium" end
    mode = mode:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
    local valid = {["Ultra High"]=true,["High"]=true,["Medium"]=true,["Low"]=true,["Ultra Low"]=true}
    return valid[mode] and mode or "Medium"
end
S.NormalizePerformanceMode = NormalizePerformanceMode

local function ShouldRunSubsystem(subsystem)
    S.PerformanceMode = NormalizePerformanceMode(S.PerformanceMode)
    local fc = FrameCounters
    if subsystem == "HeavySystems" then
        fc.HeavySystems = fc.HeavySystems + 1
        if fc.HeavySystems >= (PerformanceIntervals[S.PerformanceMode] or 3) then
            fc.HeavySystems = 0; return true
        end
    elseif subsystem == "NPCs" then
        fc.NPCs = fc.NPCs + 1
        if fc.NPCs >= (NPCIntervals[S.PerformanceMode] or 5) then
            fc.NPCs = 0; return true
        end
    elseif subsystem == "WorkspaceSweep" then
        fc.WorkspaceSweep = fc.WorkspaceSweep + 1
        if fc.WorkspaceSweep >= (SweepIntervals[S.PerformanceMode] or 3) then
            fc.WorkspaceSweep = 0; return true
        end
    elseif subsystem == "CacheCleanup" then
        fc.CacheCleanup = fc.CacheCleanup + 1
        if fc.CacheCleanup >= (CacheIntervals[S.PerformanceMode] or 30) then
            fc.CacheCleanup = 0; return true
        end
    end
    return false
end
S.ShouldRunSubsystem = ShouldRunSubsystem

-- // ── NPC & Workspace Background Loops ────────────────────────── // --

local function UpdateNPCs()
    local temp = {}
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") then
            if not Players:GetPlayerFromCharacter(v) and v ~= Player.Character then
                table.insert(temp, v)
            end
        end
    end
    S.CachedNPCs = temp
end
S.UpdateNPCs = UpdateNPCs

task.spawn(function()
    while getgenv().TASFF and getgenv().TASFF.Running do
        if ShouldRunSubsystem("NPCs") then pcall(UpdateNPCs) end
        task.wait(0.15)
    end
end)

task.spawn(function()
    while getgenv().TASFF and getgenv().TASFF.Running do
        if ShouldRunSubsystem("WorkspaceSweep") then pcall(UpdateWorkspaceIgnores) end
        task.wait(0.15)
    end
end)

pcall(UpdateWorkspaceIgnores)
pcall(UpdateNPCs)

-- // ── Cache Cleanup ───────────────────────────────────────────── // --

local function CleanupCaches()
    local now = tick()
    local function IsModelValid(m)
        if not m then return false end
        local ok, has = pcall(function()
            return m.Parent ~= nil and m:FindFirstChildOfClass("Humanoid") ~= nil
        end)
        return ok and has
    end

    for model, h in pairs(HighlightCache) do
        if not IsModelValid(model) then
            if h and h.Parent then h:Destroy() end
            HighlightCache[model] = nil
        end
    end
    for model, t in pairs(TagCache) do
        if not IsModelValid(model) then
            if typeof(t) == "Instance" then pcall(function() t:Destroy() end)
            else pcall(function() t:Remove() end) end
            TagCache[model] = nil
        end
    end
    for model, box in pairs(BoxCache) do
        if not IsModelValid(model) then
            if box and box.Remove then pcall(function() box:Remove() end) end
            BoxCache[model] = nil
        end
    end
    for model, lines in pairs(SkeletonCache) do
        if not IsModelValid(model) then
            if type(lines) == "table" then
                for _, limb in pairs(lines) do
                    if limb and limb.Line and typeof(limb.Line.Remove) == "function" then
                        pcall(function() limb.Line:Remove() end)
                    end
                end
            end
            SkeletonCache[model] = nil
        end
    end
    for model, line in pairs(SnaplineCache) do
        if not IsModelValid(model) then
            if line and line.Remove then pcall(function() line:Remove() end) end
            SnaplineCache[model] = nil
        end
    end
    for model, arrow in pairs(OOFArrowCache) do
        if not IsModelValid(model) then
            if arrow and arrow.Remove then pcall(function() arrow:Remove() end) end
            OOFArrowCache[model] = nil
        end
    end
    for k, t in pairs(VisibilityCacheTime) do
        if now - t > 1 then VisibilityCache[k] = nil; VisibilityCacheTime[k] = nil end
    end
    for model, _ in pairs(TargetFirstSeenTimestamps) do
        if not IsModelValid(model) then TargetFirstSeenTimestamps[model] = nil end
    end
end
S.CleanupCaches = CleanupCaches

task.spawn(function()
    while getgenv().TASFF and getgenv().TASFF.Running do
        if ShouldRunSubsystem("CacheCleanup") then pcall(CleanupCaches) end
        task.wait(0.15)
    end
end)

-- // ── Visual Assets Builder ────────────────────────────────────── // --

local function GetVisualAssets(model)
    local h = HighlightCache[model]
    if not h or not h.Parent or not h:IsDescendantOf(game) then
        if h and h.Parent then h:Destroy() end
        h = Instance.new("Highlight", CoreGui)
        h.FillTransparency = 1
        HighlightCache[model] = h
    end

    local tag         = TagCache[model]
    local wantDrawing = S.StreamProofESP
    local isInstance  = typeof(tag) == "Instance"
    local isDrawing   = tag ~= nil and not isInstance

    if not tag or (wantDrawing and not isDrawing) or (not wantDrawing and not isInstance) then
        if tag then
            if isInstance then tag:Destroy() else pcall(function() tag:Remove() end) end
        end
        if wantDrawing then
            tag = NewDrawing("Text")
            if tag then
                tag.Size    = 16
                tag.Center  = true
                tag.Outline = true
                tag.Color   = S.HighlightColor or Color3.fromRGB(255, 255, 255)
            else
                wantDrawing = false
            end
        end
        if not wantDrawing then
            tag = Instance.new("BillboardGui", CoreGui)
            tag.Size         = UDim2.new(0, 200, 0, 70)
            tag.AlwaysOnTop  = true
            tag.StudsOffset  = Vector3.new(0, 3, 0)
            local l = Instance.new("TextLabel", tag)
            l.Size = UDim2.new(1, 0, 1, 0); l.BackgroundTransparency = 1
            l.Font = Enum.Font.Code; l.TextSize = 14
        end
        TagCache[model] = tag
    end
    return h, tag
end
S.GetVisualAssets = GetVisualAssets

-- // ── Skeleton Renderer ────────────────────────────────────────── // --

local function DrawSkeleton(character, jointsTable, color)
    local limbs = SkeletonCache[character]
    if not limbs then
        limbs = {}
        for _, pair in ipairs(jointsTable) do
            local line = NewDrawing("Line")
            if not line then continue end
            line.Thickness = 1
            line.Visible   = false
            table.insert(limbs, {Line = line, PartA = pair[1], PartB = pair[2]})
        end
        SkeletonCache[character] = limbs
    end
    for _, limb in ipairs(limbs) do
        local partA = character:FindFirstChild(limb.PartA)
        local partB = character:FindFirstChild(limb.PartB)
        if partA and partB then
            local posA, onA = workspace.CurrentCamera:WorldToViewportPoint(partA.Position)
            local posB, onB = workspace.CurrentCamera:WorldToViewportPoint(partB.Position)
            if (onA or onB) and posA.Z > 0 and posB.Z > 0 then
                limb.Line.From    = Vector2.new(posA.X, posA.Y)
                limb.Line.To      = Vector2.new(posB.X, posB.Y)
                limb.Line.Color   = color
                limb.Line.Visible = true
            else
                limb.Line.Visible = false
            end
        else
            limb.Line.Visible = false
        end
    end
end
S.DrawSkeleton = DrawSkeleton

-- // ── Target Search Engine ─────────────────────────────────────── // --

local function GetPotentialTargets(ignoreFOV, performWallCheck, customIgnoreList, maxDistance)
    local results      = {}
    local screenCenter = GetAimPosition()

    local function Process(model, isPlayer, pObj)
        if not model then return end
        local targetName = isPlayer and pObj.Name or model.Name
        if isPlayer and table.find(S.BlacklistedPlayers or {}, targetName) then return end
        if S.StrictPrioritize and not table.find(S.PriorityPlayers or {}, targetName) then return end

        local root = model:FindFirstChild("HumanoidRootPart")
                  or model:FindFirstChild("Torso")
                  or model:FindFirstChild("UpperTorso")
        if not root then return end

        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum or (S.IgnoreDead and hum.Health <= 0) then return end

        local isTeammate = isPlayer and Player.Team and pObj.Team and pObj.Team == Player.Team
        if S.TeamCheck and isTeammate then return end

        if performWallCheck and not IsVisibleCachedWrapper(model, S.ActivePartName, customIgnoreList) then return end

        local pos         = root.Position
        local distFromCam = (pos - Camera.CFrame.Position).Magnitude
        if distFromCam > (maxDistance or S.AimbotRenderDistance) then return end

        local sPos, onScreen = Camera:WorldToViewportPoint(pos)
        local screenPos   = ApplyScreenCalibration(Vector2.new(sPos.X, sPos.Y))
        local distFromCenter = (screenPos - screenCenter).Magnitude

        if ignoreFOV or (onScreen and (not S.ShowFOV or distFromCenter <= S.FOVSize)) then
            table.insert(results, {
                Instance       = model,
                Root           = root,
                Name           = targetName,
                IsPlayer       = isPlayer,
                IsTeammate     = isTeammate,
                DistFromCenter = distFromCenter,
                Distance       = distFromCam,
                Position       = pos,
                ScreenPos      = Vector2.new(sPos.X, sPos.Y),
                Health         = hum.Health,
                TeamColor      = isPlayer and pObj.TeamColor.Color or Color3.fromRGB(255, 255, 255)
            })
        end
    end

    if S.TargetPlayers then
        for _, v in ipairs(Players:GetPlayers()) do
            if v ~= Player and v.Character then Process(v.Character, true, v) end
        end
    end
    if S.TargetNPCs then
        for _, npc in ipairs(S.CachedNPCs) do Process(npc, false) end
    end
    return results
end
S.GetPotentialTargets = GetPotentialTargets

-- // ── Presets ─────────────────────────────────────────────────── // --

local function LoadPresetsFromFile()
    local ok, result = pcall(function()
        if isfile and isfile(S.PresetFileName) then
            return HttpService:JSONDecode(readfile(S.PresetFileName))
        end
    end)
    if ok and type(result) == "table" then return result end
    return {}
end
S.LoadPresetsFromFile = LoadPresetsFromFile

local function SavePresetsToFile()
    pcall(function()
        if writefile then
            writefile(S.PresetFileName, HttpService:JSONEncode(S.SavedPresets))
        end
    end)
end
S.SavePresetsToFile = SavePresetsToFile

-- Load presets immediately after defining the function
S.SavedPresets = LoadPresetsFromFile()

-- // ── Tool Observer ────────────────────────────────────────────── // --

local function ListenForTools(char)
    if not char then return end
    if S.ToolAddedConnection then
        S.ToolAddedConnection:Disconnect()
        S.ToolAddedConnection = nil
    end
    if S.ToolRemovedConnection then
        S.ToolRemovedConnection:Disconnect()
        S.ToolRemovedConnection = nil
    end
    S.ToolAddedConnection = char.ChildAdded:Connect(function(child)
        if S.AutoEnableOnEquip and child:IsA("Tool") then
            if not table.find(S.ToolBlacklist, child.Name) then
                if S.MasterEnabled then S.AimbotActive = true end
            end
        end
    end)
    S.ToolRemovedConnection = char.ChildRemoved:Connect(function(child)
        if S.AutoEnableOnEquip and child:IsA("Tool") then
            S.AimbotActive  = false
            S.CurrentTarget = nil
            SetADSState(false)
        end
    end)
end

-- Single CharacterAdded connection handles both threat-hook and tool-observer
local CharacterConnection = Player.CharacterAdded:Connect(function(char)
    HookThreatHealth(char)
    ListenForTools(char)
end)
table.insert(getgenv().TASFF.Connections, CharacterConnection)

-- Hook existing character on inject
if Player.Character then
    HookThreatHealth(Player.Character)
    ListenForTools(Player.Character)
end

-- // ── Startup ──────────────────────────────────────────────────── // --

task.defer(function()
    task.wait(0.2)
    S.CurrentTarget     = nil
    S.ScriptInitialized = true
    print("[TASFF v2.0.0] Core initialized.")
end)

-- // ══════════════════════════════════════════════════════════════ // --
-- //                      MAIN RENDER LOOP                        // --
-- // ══════════════════════════════════════════════════════════════ // --

local RenderConnection = RunService.RenderStepped:Connect(function(deltaTime)
    if not S.ScriptInitialized then return end

    EnsureDrawings()

    local RunHeavySystems  = ShouldRunSubsystem("HeavySystems")
    local cachedIgnoreList = GetIgnoreList()

    -- Cache hot scalar reads for this frame (avoids repeated table lookups in tight loops)
    local MasterEnabled    = S.MasterEnabled
    local AimbotActive     = S.AimbotActive
    local TargetingEnabled = S.TargetingEnabled

    local heldTool          = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
    local isToolBlacklisted = heldTool and table.find(S.ToolBlacklist, heldTool.Name)
    local canAimWithTool    = not S.AutoEnableOnEquip or (heldTool and not isToolBlacklisted)

    -- // FOV Circle // --
    local screenCenter  = GetAimPosition()
    local shouldShowFOV = S.ShowFOV and not S.InvisibleFOV and MasterEnabled and AimbotActive
    if S.FOVCircle then
        if shouldShowFOV then
            PrepareDrawing(S.FOVCircle)
            S.FOVCircle.Position = screenCenter
            pcall(function() S.FOVCircle.Point = screenCenter end)
            S.FOVCircle.Radius   = S.FOVSize
            S.FOVCircle.Color    = S.FOVColor or S.FOVCircle.Color
            S.FOVCircle.Visible  = true
        else
            S.FOVCircle.Visible = false
        end
    end

    -- // Crosshair // --
    ClearCrosshair()
    if S.EnableCrosshair and MasterEnabled then
        local color = S.CrosshairColor or Color3.fromRGB(0, 255, 255)
        for _, el in pairs(CrosshairElements) do PrepareDrawing(el) end
        local CE = CrosshairElements
        local sz = S.CrosshairSize
        if CE.Dot then
            CE.Dot.Position = screenCenter
            pcall(function() CE.Dot.Point = screenCenter end)
            CE.Dot.Color = color; CE.Dot.Visible = true
        end
        local style = S.CrosshairStyle
        if style == "Plus" and CE.Top then
            CE.Top.From = Vector2.new(screenCenter.X, screenCenter.Y - sz)
            CE.Top.To   = Vector2.new(screenCenter.X, screenCenter.Y - (sz + 10))
            CE.Top.Color = color; CE.Top.Visible = true
            CE.Bottom.From = Vector2.new(screenCenter.X, screenCenter.Y + sz)
            CE.Bottom.To   = Vector2.new(screenCenter.X, screenCenter.Y + (sz + 10))
            CE.Bottom.Color = color; CE.Bottom.Visible = true
            CE.Left.From  = Vector2.new(screenCenter.X - sz, screenCenter.Y)
            CE.Left.To    = Vector2.new(screenCenter.X - (sz + 10), screenCenter.Y)
            CE.Left.Color = color; CE.Left.Visible = true
            CE.Right.From = Vector2.new(screenCenter.X + sz, screenCenter.Y)
            CE.Right.To   = Vector2.new(screenCenter.X + (sz + 10), screenCenter.Y)
            CE.Right.Color = color; CE.Right.Visible = true
        elseif style == "Square" and CE.Square then
            CE.Square.Size     = Vector2.new(sz * 2, sz * 2)
            CE.Square.Position = Vector2.new(screenCenter.X - sz, screenCenter.Y - sz)
            CE.Square.Color    = color; CE.Square.Visible = true
        elseif style == "Circle" and CE.Circle then
            CE.Circle.Position = screenCenter
            CE.Circle.Radius   = sz
            CE.Circle.Color    = color; CE.Circle.Visible = true
        end
    end

    -- // ── Heavy: Target Acquisition + ESP ──────────────────────── // --
    if RunHeavySystems then

        if MasterEnabled then
            local TargetPart      = S.TargetPart
            local WallCheck       = S.WallCheck
            local bypassWallCheck = (TargetPart ~= "Visible On Screen") and WallCheck or false

            local VisualList = GetPotentialTargets(S.VisualMode == "All", false, cachedIgnoreList, S.ESPRenderDistance)
            local AimbotList = {}
            if AimbotActive and TargetingEnabled then
                local raw = GetPotentialTargets(false, bypassWallCheck, cachedIgnoreList, S.AimbotRenderDistance)
                for i, v in ipairs(raw) do AimbotList[i] = v end
            end

            -- Purge stale grace timestamps
            for model, _ in pairs(TargetFirstSeenTimestamps) do
                if not model or not model.Parent or not model:FindFirstChildOfClass("Humanoid") then
                    TargetFirstSeenTimestamps[model] = nil
                end
            end

            -- Distance-cull current target
            if S.CurrentTarget and S.CurrentTarget.Root then
                if (S.CurrentTarget.Root.Position - Camera.CFrame.Position).Magnitude > S.AimbotRenderDistance then
                    S.CurrentTarget = nil
                end
            end

            -- Sticky Aim validation
            local StickyLockActive = false
            if S.StickyAimEnabled and S.CurrentTarget and S.CurrentTarget.Instance and S.CurrentTarget.Instance.Parent then
                local hum = S.CurrentTarget.Instance:FindFirstChildOfClass("Humanoid")
                local typeMismatch = (S.CurrentTarget.IsPlayer and not S.TargetPlayers)
                                  or (not S.CurrentTarget.IsPlayer and not S.TargetNPCs)
                local wallCheckFailed = false
                if WallCheck and TargetPart ~= "Visible On Screen" then
                    if not IsVisibleCachedWrapper(S.CurrentTarget.Instance, S.ActivePartName, cachedIgnoreList) then
                        wallCheckFailed = true
                    end
                end
                local outOfBounds = false
                if S.CurrentTarget.Root then
                    local d = (S.CurrentTarget.Root.Position - Camera.CFrame.Position).Magnitude
                    if d > S.AimbotRenderDistance then outOfBounds = true end
                    local sp, os = Camera:WorldToViewportPoint(S.CurrentTarget.Root.Position)
                    if S.ShowFOV and os and (Vector2.new(sp.X, sp.Y) - screenCenter).Magnitude > S.FOVSize then
                        outOfBounds = true
                    end
                end
                if hum and hum.Health > 0 and not typeMismatch and not wallCheckFailed and not outOfBounds and AimbotActive then
                    StickyLockActive = true
                else
                    S.CurrentTarget = nil
                end
            end

            if not StickyLockActive then
                -- Target switch delay
                if S.TargetSwitchDelayEnabled and (tick() - S.LastKillTime) < (S.SwitchDelayMs / 1000) then
                    AimbotList = {}
                end

                -- Grace period filter
                local graceCondition = WallCheck or (TargetPart == "Visible On Screen")
                if S.GracePeriodEnabled and graceCondition then
                    local now = tick()
                    for i = #AimbotList, 1, -1 do
                        local m = AimbotList[i].Instance
                        if not TargetFirstSeenTimestamps[m] then TargetFirstSeenTimestamps[m] = now end
                        if (now - TargetFirstSeenTimestamps[m]) * 1000 < S.GracePeriodMs then
                            table.remove(AimbotList, i)
                        end
                    end
                end

                -- Cache sort-hot values for this frame
                local PriorityPlayers         = S.PriorityPlayers or {}
                local VitalityMode     = S.VitalityMode
                local PriorityMode     = S.PriorityMode
                local TargetNearCenter = S.TargetNearCenter

                table.sort(AimbotList, function(a, b)
                    local aPrio = table.find(PriorityPlayers, a.Name)
                    local bPrio = table.find(PriorityPlayers, b.Name)
                    if aPrio and not bPrio then return true end
                    if bPrio and not aPrio then return false end
                    if VitalityMode == "Weakest (HP)"   then return a.Health < b.Health end
                    if VitalityMode == "Strongest (HP)" then return a.Health > b.Health end
                    local aDC = a.DistFromCenter or 999999
                    local bDC = b.DistFromCenter or 999999
                    if TargetNearCenter then return aDC < bDC end
                    if PriorityMode == "Closest"  then return (a.Distance or 999999) < (b.Distance or 999999) end
                    if PriorityMode == "Farthest" then return (a.Distance or 999999) > (b.Distance or 999999) end
                    return aDC < bDC
                end)

                S.CurrentTarget = AimbotList[1]
            end

            -- Auto ADS
            if S.AutoADSEnabled then
                SetADSState(S.CurrentTarget ~= nil and AimbotActive and canAimWithTool)
            end

            -- Silent Aim target cache
            if S.SilentAimEnabled and S.CurrentTarget then
                S.SilentAimTargetCache     = S.CurrentTarget
                S.SilentAimTargetCacheTime = tick()
            elseif tick() - S.SilentAimTargetCacheTime > 0.1 then
                S.SilentAimTargetCache = nil
            end

            -- Visible On Screen position resolution
            local CustomTargetPosition = nil
            if TargetPart == "Visible On Screen" and S.CurrentTarget then
                local rigParts = {
                    "Head","Torso","UpperTorso","LowerTorso",
                    "Left Arm","LeftUpperArm","LeftLowerArm","LeftHand",
                    "Right Arm","RightUpperArm","RightLowerArm","RightHand",
                    "Left Leg","LeftUpperLeg","LeftLowerLeg","LeftFoot",
                    "Right Leg","RightUpperLeg","RightLowerLeg","RightFoot",
                }
                local visPositions = {}
                local headVisPos   = nil
                local camPos       = Camera.CFrame.Position
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Exclude
                local ignList = {}
                for _, v in ipairs(cachedIgnoreList) do table.insert(ignList, v) end
                local tr = S.CurrentTarget.Instance:FindFirstChild("HumanoidRootPart")
                if tr then table.insert(ignList, tr) end
                rp.FilterDescendantsInstances = ignList
                rp.IgnoreWater = true
                for _, pn in ipairs(rigParts) do
                    local part = S.CurrentTarget.Instance:FindFirstChild(pn)
                    if part and part:IsA("BasePart") then
                        local dir = part.Position - camPos
                        local res = workspace:Raycast(camPos, dir, rp)
                        if not res or res.Instance:IsDescendantOf(S.CurrentTarget.Instance) then
                            if pn == "Head" then headVisPos = part.Position end
                            table.insert(visPositions, part.Position)
                        end
                    end
                end
                if headVisPos then
                    CustomTargetPosition = headVisPos
                elseif #visPositions > 0 then
                    local sum = Vector3.new(0, 0, 0)
                    for _, p in ipairs(visPositions) do sum = sum + p end
                    CustomTargetPosition = sum / #visPositions
                else
                    if not S.StickyAimEnabled then S.CurrentTarget = nil end
                end
            end

            S.LastVisualList          = VisualList
            S.LastCustomTargetPosition = CustomTargetPosition

        else
            S.LastVisualList           = {}
            S.LastCustomTargetPosition = nil
        end
    end -- RunHeavySystems
    ClearVisuals()
    if MasterEnabled and S.LastVisualList then
            -- // ESP Render Loop // --

            -- Cache ESP-hot scalars for this frame
            local NemesisEnabled          = S.NemesisEnabled
            local FocusMode               = S.FocusMode
            local VisualMode              = S.VisualMode
            local VisibilityColorsEnabled = S.VisibilityColorsEnabled
            local VisibleColor            = S.VisibleColor or Color3.fromRGB(0, 255, 0)
            local HiddenColor             = S.HiddenColor or Color3.fromRGB(255, 0, 0)
            local ESPRenderDistance       = S.ESPRenderDistance
            local UseHighlight            = S.UseHighlight
            local UseNPCHighlight         = S.UseNPCHighlight
            local UseInfoTag              = S.UseInfoTag
            local UseNPCInfoTag           = S.UseNPCInfoTag
            local ShowDisplayName         = S.ShowDisplayName
            local ShowToolCheck           = S.ShowToolCheck
            local SnaplinesEnabled        = S.SnaplinesEnabled
            local SnaplineOrigin          = S.SnaplineOrigin
            local OOFArrowsEnabled        = S.OOFArrowsEnabled
            local OOFArrowRadius          = S.OOFArrowRadius
            local BoxModeEnabled          = S.BoxModeEnabled
            local SkeletonModeEnabled     = S.SkeletonModeEnabled
            local ChamsEnabled            = S.ChamsEnabled
            local ChamsOpacity            = S.ChamsOpacity
            local HighlightColor          = S.HighlightColor or Color3.fromRGB(255, 255, 255)
            local SnaplineColor           = S.SnaplineColor or Color3.fromRGB(255, 50, 50)
            local PriorityPlayers         = S.PriorityPlayers or {}

            local myRoot = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            local myPos  = myRoot and myRoot.Position or Vector3.new(0, 0, 0)

            for _, t in ipairs(S.LastVisualList) do
                local isPriority = table.find(PriorityPlayers, t.Name) ~= nil
                local isNemesis  = NemesisEnabled and NemesisMemory[t.Name] ~= nil
                local inFocus    = not FocusMode or isPriority
                local isPrimary  = S.CurrentTarget and t.Instance == S.CurrentTarget.Instance
                local show = inFocus and (
                    VisualMode == "All" or VisualMode == "Multiple" or
                    (VisualMode == "Single" and isPrimary)
                )
                local dist = math.floor((myPos - t.Position).Magnitude)

                if not show or not t.Instance or dist > ESPRenderDistance then
                    local tc = TagCache[t.Instance]
                    if tc then
                        if typeof(tc) == "Instance" then tc.Enabled = false
                        else pcall(function() tc.Visible = false end) end
                    end
                    if BoxCache[t.Instance]      then BoxCache[t.Instance].Visible      = false end
                    if SnaplineCache[t.Instance] then SnaplineCache[t.Instance].Visible  = false end
                    if OOFArrowCache[t.Instance] then OOFArrowCache[t.Instance].Visible  = false end
                    if SkeletonCache[t.Instance] then
                        for _, limb in pairs(SkeletonCache[t.Instance]) do
                            if limb and limb.Line then limb.Line.Visible = false end
                        end
                    end
                    continue
                end

                local h, tag = GetVisualAssets(t.Instance)
                if not (h and tag) then continue end

                local isVisibleNow = true
                if VisibilityColorsEnabled then
                    isVisibleNow = IsVisibleCachedWrapper(t.Instance, "HumanoidRootPart", cachedIgnoreList)
                end
                local baseColor = HighlightColor or t.TeamColor
                if isNemesis      then baseColor = Color3.fromRGB(150, 0, 255)
                elseif isPriority then baseColor = Color3.fromRGB(255, 50, 50)
                elseif VisibilityColorsEnabled then baseColor = isVisibleNow and VisibleColor or HiddenColor end

                h.Adornee      = t.Instance
                h.Enabled      = t.IsPlayer and UseHighlight or UseNPCHighlight
                h.OutlineColor = baseColor

                local rootPart = t.Instance:FindFirstChild("HumanoidRootPart")
                local headPart = t.Instance:FindFirstChild("Head")
                if not rootPart then continue end

                local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                local headPos = headPart
                    and Camera:WorldToViewportPoint(headPart.Position + Vector3.new(0, 0.5, 0))
                    or pos

                -- OOF Arrows (off-screen targets)
                if OOFArrowsEnabled and not onScreen then
                    if not OOFArrowCache[t.Instance] then
                        local ok, arrow = pcall(Drawing.new, "Triangle")
                        if ok and arrow then
                            arrow.Thickness = 2; arrow.Filled = true
                            OOFArrowCache[t.Instance] = arrow
                        end
                    end
                    local arrow = OOFArrowCache[t.Instance]
                    if arrow then
                        local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                        local relX, relY = pos.X - center.X, pos.Y - center.Y
                        if pos.Z < 0 then relX = -relX; relY = -relY end
                        local angle = math.atan2(relY, relX)
                        local r     = OOFArrowRadius
                        arrow.PointA  = center + Vector2.new(math.cos(angle),       math.sin(angle))       * r
                        arrow.PointB  = center + Vector2.new(math.cos(angle - 0.2), math.sin(angle - 0.2)) * (r - 20)
                        arrow.PointC  = center + Vector2.new(math.cos(angle + 0.2), math.sin(angle + 0.2)) * (r - 20)
                        arrow.Color   = SnaplineColor or baseColor
                        arrow.Visible = true
                    end
                else
                    if OOFArrowCache[t.Instance] then OOFArrowCache[t.Instance].Visible = false end
                end

                if onScreen then
                    local headScreen = ApplyScreenCalibration(Vector2.new(headPos.X, headPos.Y))

                    -- Info Tags
                    if (t.IsPlayer and UseInfoTag) or (not t.IsPlayer and UseNPCInfoTag) then
                        local header     = ""
                        local activeTool = t.Instance:FindFirstChildOfClass("Tool")
                        if ShowToolCheck and activeTool then header = "[" .. activeTool.Name:upper() .. "] " end
                        if isNemesis      then header = header .. "[NEMESIS] "
                        elseif isPriority then header = header .. "[PRIORITY] " end
                        if t.IsTeammate   then header = header .. "[TEAM] " end
                        local nSeg = ""
                        if t.IsPlayer and ShowDisplayName then
                            local pObj = Players:FindFirstChild(t.Name)
                            if pObj then nSeg = "(" .. pObj.DisplayName .. ") " end
                        end
                        local finalStr = string.format("%s%s%s\nHP: %d | Dist: %d",
                            header, nSeg, t.Name, math.floor(t.Health), dist)
                        if typeof(tag) == "Instance" and tag:IsA("BillboardGui") then
                            local lbl = tag:FindFirstChildOfClass("TextLabel")
                            if lbl then lbl.Text = finalStr; lbl.TextColor3 = baseColor end
                            tag.Adornee = t.Instance:FindFirstChild("Head") or rootPart
                            tag.Enabled = true
                        else
                            tag.Text     = finalStr
                            tag.Position = Vector2.new(headScreen.X, headScreen.Y - 35)
                            tag.Color    = baseColor
                            tag.Visible  = true
                        end
                    else
                        if typeof(tag) == "Instance" then tag.Enabled = false
                        else pcall(function() tag.Visible = false end) end
                    end

                    -- Snaplines
                    if SnaplinesEnabled then
                        if not SnaplineCache[t.Instance] then
                            local line = NewDrawing("Line")
                            if line then line.Thickness = 1.5; SnaplineCache[t.Instance] = line end
                        end
                        local sLine = SnaplineCache[t.Instance]
                        if sLine then
                            PrepareDrawing(sLine)
                            local origin2 = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                            if SnaplineOrigin == "Center" then
                                origin2 = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                            end
                            sLine.From = origin2; sLine.To = Vector2.new(pos.X, pos.Y)
                            sLine.Color = SnaplineColor or baseColor; sLine.Visible = true
                        end
                    else
                        if SnaplineCache[t.Instance] then SnaplineCache[t.Instance].Visible = false end
                    end

                    -- 2D Bounding Boxes
                    if BoxModeEnabled then
                        local legPos  = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
                        local boxH    = math.abs(headPos.Y - legPos.Y)
                        local boxW    = boxH * 0.65
                        if not BoxCache[t.Instance] then
                            local box = NewDrawing("Square")
                            if box then box.Thickness = 1.5; box.Filled = false; BoxCache[t.Instance] = box end
                        end
                        if BoxCache[t.Instance] then
                            PrepareDrawing(BoxCache[t.Instance])
                            BoxCache[t.Instance].Size     = Vector2.new(boxW, boxH)
                            BoxCache[t.Instance].Position = Vector2.new(headScreen.X - (boxW / 2), headScreen.Y)
                            BoxCache[t.Instance].Color    = baseColor
                            BoxCache[t.Instance].Visible  = true
                        end
                    else
                        if BoxCache[t.Instance] then BoxCache[t.Instance].Visible = false end
                    end

                    -- Skeleton
                    if SkeletonModeEnabled then
                        local isR15  = t.Instance:FindFirstChild("UpperTorso") ~= nil
                        DrawSkeleton(t.Instance, isR15 and R15Joints or R6Joints, baseColor)
                    else
                        if SkeletonCache[t.Instance] then
                            for _, limb in ipairs(SkeletonCache[t.Instance]) do
                                if limb and limb.Line then limb.Line.Visible = false end
                            end
                        end
                    end
                else
                    -- Off-screen: hide all screen-space visuals
                    if typeof(tag) == "Instance" then tag.Enabled = false
                    else pcall(function() tag.Visible = false end) end
                    if BoxCache[t.Instance]      then BoxCache[t.Instance].Visible      = false end
                    if SnaplineCache[t.Instance] then SnaplineCache[t.Instance].Visible  = false end
                    if SkeletonCache[t.Instance] then
                        for _, limb in ipairs(SkeletonCache[t.Instance]) do
                            if limb and limb.Line then limb.Line.Visible = false end
                        end
                    end
                end

                -- Chams
                if ChamsEnabled then
                    h.DepthMode        = Enum.HighlightDepthMode.AlwaysOnTop
                    h.FillColor        = baseColor
                    h.FillTransparency = 1 - (math.clamp(ChamsOpacity, 1, 10) / 10)
                else
                    h.DepthMode        = Enum.HighlightDepthMode.Occluded
                    h.FillTransparency = 1
                end
            end
    end

    -- // ── Light: Aimbot + Triggerbot (every frame) ──────────────── // --
    if MasterEnabled then
        local CurrentTarget    = S.CurrentTarget
        local TargetPart       = S.TargetPart

        -- Aimbot tracking
        if CurrentTarget and TargetingEnabled and AimbotActive and canAimWithTool then
            local TargetWorldPos   = nil
            local targetVelocity   = CurrentTarget.Root and CurrentTarget.Root.AssemblyLinearVelocity or Vector3.new(0,0,0)
            local isMoving         = targetVelocity.Magnitude > 1.5
            local Mode             = S.Mode
            local PredictionAmount = S.PredictionAmount

            if TargetPart == "Visible On Screen" and S.LastCustomTargetPosition then
                TargetWorldPos = S.LastCustomTargetPosition
            else
                local boneName = TargetPart
                if Mode == "Legit (Camera)" or Mode == "Advanced Legit (Mouse)" then
                    boneName = isMoving
                        and (CurrentTarget.Instance:FindFirstChild("Torso") and "Torso" or "UpperTorso")
                        or "Head"
                    if S.RandomizeHitboxEnabled then
                        local opts = {"Head","UpperTorso","LowerTorso"}
                        boneName = opts[math.random(1, #opts)]
                    end
                end
                local bone = CurrentTarget.Instance:FindFirstChild(boneName) or CurrentTarget.Root
                if bone then
                    TargetWorldPos = bone.Position + (bone.AssemblyLinearVelocity * PredictionAmount)
                end
            end

            if TargetWorldPos and S.WallCheck then
                local trkIgnore = {}
                for _, v in ipairs(cachedIgnoreList) do table.insert(trkIgnore, v) end
                table.insert(trkIgnore, CurrentTarget.Instance)
                if not IsVisibleCachedWrapper(CurrentTarget.Instance, S.ActivePartName, trkIgnore) then
                    TargetWorldPos = nil
                end
            end

            if TargetWorldPos then
                local targetCFrame = CFrame.new(Camera.CFrame.Position, TargetWorldPos)
                local sp, os = Camera:WorldToViewportPoint(TargetWorldPos)
                local targetScreenPos = os and ApplyScreenCalibration(Vector2.new(sp.X, sp.Y)) or nil
                local Smoothness = S.Smoothness

                if Mode == "Legit (Camera)" then
                    Camera.CFrame = Camera.CFrame:Lerp(
                        targetCFrame,
                        math.clamp(deltaTime * (6 / math.max(0.1, Smoothness)), 0.01, 1)
                    )
                elseif Mode == "Advanced Legit (Mouse)" then
                    if targetScreenPos then
                        local mousePos = UserInputService:GetMouseLocation()
                        local d2       = (targetScreenPos - mousePos).Magnitude
                        local friction = math.max(1.0, Smoothness * (1 + (150 / math.max(d2, 1))))
                        local tVal     = tick() * 6
                        local swayX    = math.sin(tVal) * (d2 * 0.012)
                        local swayY    = math.cos(tVal * 1.3) * (d2 * 0.012)
                        local moveVec  = Vector2.new(targetScreenPos.X + swayX, targetScreenPos.Y + swayY) - mousePos
                        local step     = math.clamp(deltaTime * (25 / friction), 0.01, 1)
                        if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
                            mousemoverel(moveVec.X * step, moveVec.Y * step)
                        else
                            mousemoveabs(mousePos.X + moveVec.X * step, mousePos.Y + moveVec.Y * step)
                        end
                    end
                elseif Mode == "Blatant" then
                    Camera.CFrame = targetCFrame
                end
            end
        end

        -- Melee range check
        local MeleeModeEnabled = S.MeleeModeEnabled
        local enemyInMeleeRange = false
        if MeleeModeEnabled and Player.Character then
            local myRootPart2 = Player.Character:FindFirstChild("HumanoidRootPart")
            if myRootPart2 then
                local meleeRange = S.MeleeDetectionRange
                for _, t in ipairs(S.LastVisualList) do
                    if t.Instance and t.Root and
                       (myRootPart2.Position - t.Root.Position).Magnitude <= meleeRange then
                        enemyInMeleeRange = true; break
                    end
                end
            end
        end

        -- Triggerbot (re-read CurrentTarget in case aimbot above nulled it)
        local CurrentTarget2      = S.CurrentTarget
        local ClickMethod         = S.ClickMethod
        local TriggerbotClickMode = S.TriggerbotClickMode
        local ClickInterval       = S.ClickInterval
        local MeleeClickInterval  = S.MeleeClickInterval
        local triggerbotActive    = S.AutoClickEnabled and CurrentTarget2 ~= nil
                                 and TargetingEnabled and AimbotActive and canAimWithTool
        local meleeActive         = MeleeModeEnabled and enemyInMeleeRange

        if triggerbotActive or meleeActive then
            local coord
            if S.ThirdPersonTriggerbot and CurrentTarget2 and CurrentTarget2.ScreenPos then
                coord = CurrentTarget2.ScreenPos
            else
                coord = UserInputService:GetMouseLocation()
            end
            local activeInterval = meleeActive and MeleeClickInterval or ClickInterval

            if ClickMethod == "Hold" then
                if not S.IsHoldingClick then
                    S.IsHoldingClick = true
                    if TriggerbotClickMode == "Physical" and mouse1press then mouse1press()
                    else VirtualInputManager:SendMouseButtonEvent(coord.X, coord.Y, 0, true, game, 0) end
                end
            elseif ClickMethod == "Mash" then
                if (tick() - S.LastClickTime) >= (activeInterval / 1000) then
                    S.LastClickTime = tick()
                    task.spawn(function()
                        if TriggerbotClickMode == "Physical" and mouse1click then mouse1click()
                        else
                            VirtualInputManager:SendMouseButtonEvent(coord.X, coord.Y, 0, true, game, 0)
                            task.wait(0.01)
                            VirtualInputManager:SendMouseButtonEvent(coord.X, coord.Y, 0, false, game, 0)
                        end
                    end)
                end
            end
        else
            if S.IsHoldingClick then
                S.IsHoldingClick = false
                local coord2 = UserInputService:GetMouseLocation()
                if TriggerbotClickMode == "Physical" and mouse1release then mouse1release()
                else VirtualInputManager:SendMouseButtonEvent(coord2.X, coord2.Y, 0, false, game, 0) end
            end
        end

        -- Key Triggerbot
        local CurrentTarget3 = S.CurrentTarget
        if S.KeyTriggerbotEnabled and CurrentTarget3 ~= nil and TargetingEnabled and AimbotActive and canAimWithTool then
            pcall(function()
                local key            = GetKeyCode(S.KeyTriggerbotKey)
                local KeyTriggerMode = S.KeyTriggerMode
                if key then
                    if KeyTriggerMode == "Hold" then
                        if not S.IsHoldingTriggerKey then
                            S.IsHoldingTriggerKey = true
                            VirtualInputManager:SendKeyEvent(true, key, false, game)
                        end
                    elseif KeyTriggerMode == "Mash" then
                        if (tick() - S.LastKeyTriggerTime) >= 0.1 then
                            S.LastKeyTriggerTime = tick()
                            task.spawn(function()
                                VirtualInputManager:SendKeyEvent(true,  key, false, game)
                                task.wait(0.02)
                                VirtualInputManager:SendKeyEvent(false, key, false, game)
                            end)
                        end
                    elseif KeyTriggerMode == "Single Press" then
                        if not S.IsHoldingTriggerKey then
                            S.IsHoldingTriggerKey = true
                            task.spawn(function()
                                VirtualInputManager:SendKeyEvent(true,  key, false, game)
                                task.wait(0.02)
                                VirtualInputManager:SendKeyEvent(false, key, false, game)
                            end)
                        end
                    end
                end
            end)
        else
            if S.IsHoldingTriggerKey then
                S.IsHoldingTriggerKey = false
                pcall(function()
                    local key = GetKeyCode(S.KeyTriggerbotKey)
                    if key then VirtualInputManager:SendKeyEvent(false, key, false, game) end
                end)
            end
        end
    end -- MasterEnabled
end)

table.insert(getgenv().TASFF.Connections, RenderConnection)

-- // ── Universal Silent Aim (Metamethod Hooks) ─────────────────── // --

local oldIndex
oldIndex = hookmetamethod(game, "__index", function(t, k)
    if k ~= "Hit" and k ~= "Target" and k ~= "UnitRay" then return oldIndex(t, k) end
    if checkcaller() then return oldIndex(t, k) end
    if S.SilentAimEnabled and S.MasterEnabled and S.SilentAimTargetCache and S.SilentAimTargetCache.Instance then
        local bone = S.SilentAimTargetCache.Instance:FindFirstChild(S.TargetPart)
                  or S.SilentAimTargetCache.Instance:FindFirstChild("HumanoidRootPart")
        if bone then
            if k == "Hit"     then return bone.CFrame end
            if k == "Target"  then return bone end
            if k == "UnitRay" then
                local origin = Camera.CFrame.Position
                return Ray.new(origin, (bone.Position - origin).Unit)
            end
        end
    end
    return oldIndex(t, k)
end)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local validMethods = {
        Raycast=true, Blockcast=true, Spherecast=true, Shapecast=true,
        FindPartOnRayWithIgnoreList=true, FindPartOnRayWithWhitelist=true, FindPartOnRay=true
    }
    if not validMethods[method] then return oldNamecall(self, ...) end
    if checkcaller() then return oldNamecall(self, ...) end
    if S.SilentAimEnabled and S.MasterEnabled and S.SilentAimTargetCache and S.SilentAimTargetCache.Instance then
        local args = {...}
        local root = S.SilentAimTargetCache.Instance:FindFirstChild("HumanoidRootPart")
        local bone = S.SilentAimTargetCache.Instance:FindFirstChild(S.TargetPart) or root
        if bone and typeof(self) == "Instance" and (self == workspace or self:IsA("Workspace")) then
            local origin
            if     method == "Raycast" or method == "Spherecast" then origin = args[1]
            elseif method == "Blockcast"                         then origin = args[1].Position
            elseif method == "Shapecast"                         then origin = args[2].Position
            else                                                      origin = args[1].Origin end
            local origVec
            if     method == "Raycast"                                                          then origVec = args[2]
            elseif method == "Blockcast" or method == "Spherecast" or method == "Shapecast"    then origVec = args[3]
            else                                                                                     origVec = args[1].Direction end
            local castLen = (typeof(origVec) == "Vector3" and origVec.Magnitude) or 1000
            local dir     = (bone.Position - origin).Unit * castLen
            if     method == "Raycast"                                                          then args[2] = dir
            elseif method == "Blockcast" or method == "Spherecast" or method == "Shapecast"    then args[3] = dir
            else                                                                                     args[1] = Ray.new(origin, dir) end
            return oldNamecall(self, unpack(args))
        end
    end
    return oldNamecall(self, ...)
end)

-- // ── Cleanup Handler ──────────────────────────────────────────── // --

getgenv().TASFF.Cleanup = function()
    -- 1. Restore metamethod hooks first
    pcall(function() hookmetamethod(game, "__index",    oldIndex)    end)
    pcall(function() hookmetamethod(game, "__namecall", oldNamecall) end)

    -- 2. Destroy all tracked Drawing objects
    if getgenv().TASFF.Drawings then
        for _, d in ipairs(getgenv().TASFF.Drawings) do pcall(function() d:Remove() end) end
        table.clear(getgenv().TASFF.Drawings)
    end

    -- 3. Disconnect all tracked RBXScriptConnections
    if getgenv().TASFF.Connections then
        for _, conn in pairs(getgenv().TASFF.Connections) do
            if typeof(conn) == "RBXScriptConnection" and conn.Connected then
                conn:Disconnect()
            end
        end
        table.clear(getgenv().TASFF.Connections)
    end

    -- 4. Destroy UI containers
    for _, child in ipairs(CoreGui:GetChildren()) do
        if child.Name == "TASFF_UI" or child.Name == "Rayfield" then
            child:Destroy()
        end
    end
end

print("[TASFF Core] All function slots registered. Render loop active.")


