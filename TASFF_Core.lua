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

table.insert(getgenv().TASFF.Connections,
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        Camera = workspace.CurrentCamera
    end)
)

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
    if getgenv().TASFF and getgenv().TASFF.Cleanup then getgenv().TASFF.Cleanup() end
    if getgenv().TASFF and getgenv().TASFF.Connections then
        for _, conn in ipairs(getgenv().TASFF.Connections) do pcall(function() conn:Disconnect() end) end
    end
    Notify({Title = "TASFF", Content = "Script and interface fully unloaded.", Duration = 2, Image = "log-out"})
    pcall(function() if Rayfield and Rayfield.Destroy then Rayfield:Destroy() end end)
    pcall(function()
        for _, gui in ipairs(CoreGui:GetChildren()) do
            if gui.Name:find("Rayfield") or gui.Name:find("Sirius") then gui:Destroy() end
        end
    end)
end
S.UnloadScript = UnloadScript

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
        pcall(function() S.PriorityDropdownRef:Refresh(GetPlayerNames(), S.PriorityPlayers) end)
    end
    if S.PriorityMonitorLabel then
        local text = ""
        for _, name in ipairs(S.PriorityPlayers) do text = text .. "* " .. name .. "\n" end
        if text == "" then text = "No priority targets currently selected." end
        pcall(function()
            S.PriorityMonitorLabel:Set({Title = "Active Priority Targets (" .. #S.PriorityPlayers .. ")", Content = text})
        end)
    end
end
S.SyncPriorityUI = SyncPriorityUI

-- INTEL_INJECT: This file is injected by the patcher into TASFF_Core.lua after SyncPriorityUI

-- // ── Intel System (v2.0.5) ─────────────────────────────────────── // --

local IntelPointValues = {
    Marked   = 15,
    Threat   = 30,
    Registry = 20,
    Nemesis  = 50,
    Damaged  = 5,
    Killed   = 25,
}

local function GetIntelSortedList()
    local list = {}
    for name, data in pairs(S.IntelPlayers) do
        table.insert(list, {Name=name, Data=data})
    end
    table.sort(list, function(a,b) return (a.Data.points or 0) > (b.Data.points or 0) end)
    return list
end
S.GetIntelSortedList = GetIntelSortedList

local function RebuildIntelMonitor()
    if not S.IntelMonitorLabel then return end
    local sorted = GetIntelSortedList()
    if #sorted == 0 then
        pcall(function() S.IntelMonitorLabel:Set({Title="Intel Monitor (0 tracked)", Content="No tracked players."}) end)
        return
    end
    local lines = {}
    local mostDangerousName, mostDangerousPts = nil, 0
    for _, entry in ipairs(sorted) do
        local name = entry.Name
        local data = entry.Data
        local pts  = data.points or 0
        local src  = data.source or "Marked"
        local po   = Players:FindFirstChild(name)
        local displaySuffix = (po and po.DisplayName ~= name) and (" (" .. po.DisplayName .. ")") or ""
        local selected = (S.IntelSelected == name) and " [SELECTED]" or ""
        table.insert(lines, name .. displaySuffix .. "  [" .. src .. "]  " .. pts .. " pts" .. selected)
        if pts > mostDangerousPts then mostDangerousPts = pts; mostDangerousName = name end
    end
    local heatmap = ""
    if mostDangerousName then
        local po2 = Players:FindFirstChild(mostDangerousName)
        local dn2 = (po2 and po2.DisplayName ~= mostDangerousName) and (" (" .. po2.DisplayName .. ")") or ""
        heatmap = "\n\n★ Most Dangerous: " .. mostDangerousName .. dn2 .. " — " .. mostDangerousPts .. " pts"
    end
    local body = table.concat(lines, "\n") .. heatmap
    pcall(function() S.IntelMonitorLabel:Set({Title="Intel Monitor (" .. #sorted .. " tracked)", Content=body}) end)
end
S.RebuildIntelMonitor = RebuildIntelMonitor

local function AddToIntel(name, source, extraPoints)
    if not name or name == "" or name == Player.Name then return end
    local pts = (IntelPointValues[source] or 0) + (extraPoints or 0)
    local srcPriority = {Nemesis=4, Registry=3, Threat=2, Marked=1}
    if S.IntelPlayers[name] then
        local curSrc = S.IntelPlayers[name].source or "Marked"
        if (srcPriority[source] or 0) > (srcPriority[curSrc] or 0) then
            S.IntelPlayers[name].source = source
        end
        S.IntelPlayers[name].points = (S.IntelPlayers[name].points or 0) + pts
        if source == "Nemesis" then S.IntelPlayers[name].nemesis = true end
    else
        S.IntelPlayers[name] = { source=source, points=pts, nemesis=(source=="Nemesis") }
        if source ~= "Nemesis" and not table.find(S.PriorityPlayers, name) then
            table.insert(S.PriorityPlayers, name)
            SyncPriorityUI()
        end
    end
    RebuildIntelMonitor()
end
S.AddToIntel = AddToIntel

local function RemoveFromIntel(name, forceRemoveNemesis)
    if not name or name == "" then return end
    local data = S.IntelPlayers[name]
    if not data then return end
    if data.nemesis and not forceRemoveNemesis then
        Notify({Title="Intel",Content="Use 'Remove Nemesis' to remove a Nemesis player.",Duration=2,Image="shield-off"})
        return
    end
    S.IntelPlayers[name] = nil
    S.ThreatMemory[name] = nil
    S.NemesisMemory[name] = nil
    local idx = table.find(S.PriorityPlayers, name)
    if idx then table.remove(S.PriorityPlayers, idx) end
    SyncPriorityUI()
    if S.IntelSelected == name then S.IntelSelected = "" end
    RebuildIntelMonitor()
end
S.RemoveFromIntel = RemoveFromIntel


table.insert(getgenv().TASFF.Connections, Players.PlayerAdded:Connect(function() task.defer(SyncPriorityUI) end))
table.insert(getgenv().TASFF.Connections, Players.PlayerRemoving:Connect(function() task.defer(SyncPriorityUI) end))

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
                if heldTool and nameLower:find(heldTool.Name:lower(), 1, true) then shouldIgnore = true end
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
        if obj and not ignoreSet[obj] then ignoreSet[obj] = true; table.insert(ignoreList, obj) end
    end
    add(Camera); add(CoreGui)
    if Player and Player.Character then
        add(Player.Character)
        local heldTool = Player.Character:FindFirstChildOfClass("Tool")
        if heldTool then add(heldTool) end
    end
    for _, item in ipairs(S.CachedWorkspaceIgnores) do add(item) end
    return ignoreList
end
S.GetIgnoreList = GetIgnoreList

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
        if S.NoCollisionCheck and not hit.CanCollide then canPass = true
        elseif S.TransparencyCheck and hit.Transparency >= S.TransparencyThreshold then canPass = true
        elseif S.DecalsCheck and (hit:FindFirstChildOfClass("Decal") or hit:FindFirstChildOfClass("Texture")) then canPass = true
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
local function RegisterThreat(attackerName, isKill)
    if not attackerName or attackerName == Player.Name then return end
    if isKill then
        if S.NemesisEnabled then
            S.PlayerNemesisStrikes[attackerName] = (S.PlayerNemesisStrikes[attackerName] or 0) + 1
            local strikes = S.PlayerNemesisStrikes[attackerName]
            local req = S.KillsBeforeNemesis or 3
            if strikes >= req then
                NemesisMemory[attackerName] = tick()
                if S.AddToIntel then S.AddToIntel(attackerName, "Nemesis", 25) end
                Notify({Title="TASFF Nemesis",Content="🔴 "..attackerName.." is now your Nemesis.",Duration=3,Image="flame"})
            else
                local strikeMsg = "⚠ Strike "..strikes.." — "..attackerName.." has killed you."
                if strikes == 2 then strikeMsg = "⚠ Strike 2 — "..attackerName.." is on a streak against you." end
                Notify({Title="TASFF Nemesis",Content=strikeMsg,Duration=3,Image="flame"})
            end
        else
            if S.AddToIntel then S.AddToIntel(attackerName, "Threat", 25) end
        end
    else
        ThreatMemory[attackerName] = tick()
        local isNew = not table.find(S.PriorityPlayers, attackerName)
        if S.AddToIntel then S.AddToIntel(attackerName, "Threat", 5) end
        if isNew then
            Notify({Title="TASFF Threat",Content="Registered Threat: "..attackerName,Duration=2,Image="alert-circle"})
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
                S.LastKillTime = tick(); S.CurrentTarget = nil
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

task.spawn(function()
    while getgenv().TASFF and getgenv().TASFF.Running do
        task.wait(0.5)
        local now = tick(); local changed = false
        for name, timestamp in pairs(ThreatMemory) do
            if now - timestamp >= S.ThreatTimeout then
                ThreatMemory[name] = nil
                local idx = table.find(S.PriorityPlayers, name)
                if idx then table.remove(S.PriorityPlayers, idx); changed = true end
                if S.BlacklistExpiredThreats and not table.find(S.BlacklistedPlayers, name) then
                    table.insert(S.BlacklistedPlayers, name)
                    Notify({Title="TASFF Threat Memory",Content=name.." expired -> Moved to Blacklist",Duration=2,Image="ban"})
                else
                    Notify({Title="TASFF Threat Memory",Content="Threat Expired: "..name,Duration=2,Image="hourglass"})
                end
            end
        end
        if changed then SyncPriorityUI() end
    end
end)

task.spawn(function()
    if getgenv().TASFF then getgenv().TASFF.ThreatMonitorRunning = true end
    while getgenv().TASFF and getgenv().TASFF.Running and getgenv().TASFF.ThreatMonitorRunning do
        task.wait(1)
        local now = tick(); local text = ""
        for name, ts in pairs(ThreatMemory) do
            local rem = math.max(0, math.floor(S.ThreatTimeout - (now - ts)))
            text = text .. "* " .. name .. " (" .. rem .. "s remaining)\n"
        end
        if text == "" then text = "No active threats detected." end
        if S.ThreatListLabel then
            pcall(function() S.ThreatListLabel:Set({Title="Live Threat Monitor",Content=text}) end)
        end
    end
end)

local function HandleClickToMark()
    local mouse    = Player:GetMouse()
    local rawLoc   = UserInputService:GetMouseLocation()
    local inset    = GuiService:GetGuiInset()
    local mouseLoc = rawLoc - inset
    local targetName = nil
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
    if not targetName then
        local ray = Camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
        local bestScore = 999999
        local function checkModel(model, name)
            if not model then return end
            for _, pn in ipairs({"Head","HumanoidRootPart","Torso","UpperTorso"}) do
                local part = model:FindFirstChild(pn)
                if part and part:IsA("BasePart") then
                    local dir = ray.Direction.Unit
                    local toPoint = part.Position - ray.Origin
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
            if S.RemoveFromIntel then S.RemoveFromIntel(targetName, false)
            else table.remove(S.PriorityPlayers, idx); SyncPriorityUI() end
            Notify({Title="TASFF Mark",Content="Unmarked "..targetName.." from Intel.",Duration=2,Image="minus-circle"})
        else
            if S.AddToIntel then S.AddToIntel(targetName, "Marked", 0)
            else table.insert(S.PriorityPlayers, targetName); SyncPriorityUI() end
            Notify({Title="TASFF Mark",Content="Marked "..targetName.." as Priority!",Duration=2,Image="crosshair"})
        end
    else
        Notify({Title="TASFF Mark",Content="No target detected near cursor.",Duration=1.5,Image="locate-off"})
    end
end
S.HandleClickToMark = HandleClickToMark

table.insert(getgenv().TASFF.Connections, UserInputService.InputBegan:Connect(function(input, gpe)
    if input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode.Name == S.PanicKeybind then
        TriggerPanic(); return
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
        if fc.HeavySystems >= (PerformanceIntervals[S.PerformanceMode] or 3) then fc.HeavySystems = 0; return true end
    elseif subsystem == "NPCs" then
        fc.NPCs = fc.NPCs + 1
        if fc.NPCs >= (NPCIntervals[S.PerformanceMode] or 5) then fc.NPCs = 0; return true end
    elseif subsystem == "WorkspaceSweep" then
        fc.WorkspaceSweep = fc.WorkspaceSweep + 1
        if fc.WorkspaceSweep >= (SweepIntervals[S.PerformanceMode] or 3) then fc.WorkspaceSweep = 0; return true end
    elseif subsystem == "CacheCleanup" then
        fc.CacheCleanup = fc.CacheCleanup + 1
        if fc.CacheCleanup >= (CacheIntervals[S.PerformanceMode] or 30) then fc.CacheCleanup = 0; return true end
    end
    return false
end
S.ShouldRunSubsystem = ShouldRunSubsystem

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

local function CleanupCaches()
    local now = tick()
    local function IsModelValid(m)
        if not m then return false end
        local ok, has = pcall(function() return m.Parent ~= nil and m:FindFirstChildOfClass("Humanoid") ~= nil end)
        return ok and has
    end
    for model, h in pairs(HighlightCache) do
        if not IsModelValid(model) then
            if h and h.Parent then h:Destroy() end; HighlightCache[model] = nil
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
            if box and box.Remove then pcall(function() box:Remove() end) end; BoxCache[model] = nil
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
            if line and line.Remove then pcall(function() line:Remove() end) end; SnaplineCache[model] = nil
        end
    end
    for model, arrow in pairs(OOFArrowCache) do
        if not IsModelValid(model) then
            if arrow and arrow.Remove then pcall(function() arrow:Remove() end) end; OOFArrowCache[model] = nil
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

local function GetVisualAssets(model)
    local h = HighlightCache[model]
    if not h or not h.Parent or not h:IsDescendantOf(game) then
        if h and h.Parent then h:Destroy() end
        h = Instance.new("Highlight", CoreGui)
        h.FillTransparency = 1
        HighlightCache[model] = h
    end
    local tag = TagCache[model]
    local wantDrawing = S.StreamProofESP
    local isInstance  = typeof(tag) == "Instance"
    local isDrawing   = tag ~= nil and not isInstance
    if not tag or (wantDrawing and not isDrawing) or (not wantDrawing and not isInstance) then
        if tag then
            if isInstance then tag:Destroy() else pcall(function() tag:Remove() end) end
        end
        if wantDrawing then
            tag = NewDrawing("Text")
            if tag then tag.Size=16; tag.Center=true; tag.Outline=true; tag.Color=S.HighlightColor or Color3.fromRGB(255,255,255)
            else wantDrawing = false end
        end
        if not wantDrawing then
            tag = Instance.new("BillboardGui", CoreGui)
            tag.Size=UDim2.new(0,200,0,70); tag.AlwaysOnTop=true; tag.StudsOffset=Vector3.new(0,3,0)
            local l = Instance.new("TextLabel", tag)
            l.Size=UDim2.new(1,0,1,0); l.BackgroundTransparency=1; l.Font=Enum.Font.Code; l.TextSize=14
        end
        TagCache[model] = tag
    end
    return h, tag
end
S.GetVisualAssets = GetVisualAssets

local function DrawSkeleton(character, jointsTable, color)
    local limbs = SkeletonCache[character]
    if not limbs then
        limbs = {}
        for _, pair in ipairs(jointsTable) do
            local line = NewDrawing("Line")
            if not line then continue end
            line.Thickness = 1; line.Visible = false
            table.insert(limbs, {Line=line, PartA=pair[1], PartB=pair[2]})
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
                limb.Line.From=Vector2.new(posA.X,posA.Y); limb.Line.To=Vector2.new(posB.X,posB.Y)
                limb.Line.Color=color; limb.Line.Visible=true
            else limb.Line.Visible=false end
        else limb.Line.Visible=false end
    end
end
S.DrawSkeleton = DrawSkeleton

local function GetPotentialTargets(ignoreFOV, performWallCheck, customIgnoreList, maxDistance)
    local results = {}
    local screenCenter = GetAimPosition()
    local function Process(model, isPlayer, pObj)
        if not model then return end
        local targetName = isPlayer and pObj.Name or model.Name
        if isPlayer and table.find(S.BlacklistedPlayers or {}, targetName) then return end
        if S.PriorityBehavior == "Exclusive" and not table.find(S.PriorityPlayers or {}, targetName) then return end
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
        if not root then return end
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum or (S.IgnoreDead and hum.Health <= 0) then return end
        local isTeammate = isPlayer and Player.Team and pObj.Team and pObj.Team == Player.Team
        if S.TeamCheck and isTeammate then return end
        if performWallCheck and not IsVisibleCachedWrapper(model, S.ActivePartName, customIgnoreList) then return end
        local pos = root.Position
        local distFromCam = (pos - Camera.CFrame.Position).Magnitude
        if distFromCam > (maxDistance or S.AimbotRenderDistance) then return end
        local sPos, onScreen = Camera:WorldToViewportPoint(pos)
        local screenPos = ApplyScreenCalibration(Vector2.new(sPos.X, sPos.Y))
        local distFromCenter = (screenPos - screenCenter).Magnitude
        if ignoreFOV or (onScreen and (not S.ShowFOV or distFromCenter <= S.FOVSize)) then
            table.insert(results, {
                Instance=model, Root=root, Name=targetName, IsPlayer=isPlayer,
                IsTeammate=isTeammate, DistFromCenter=distFromCenter, Distance=distFromCam,
                Position=pos, ScreenPos=Vector2.new(sPos.X,sPos.Y),
                Health=hum.Health, TeamColor=isPlayer and pObj.TeamColor.Color or Color3.fromRGB(255,255,255)
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

local function LoadPresetsFromFile()
    local ok, result = pcall(function()
        if isfile and isfile(S.PresetFileName) then return HttpService:JSONDecode(readfile(S.PresetFileName)) end
    end)
    if ok and type(result) == "table" then return result end
    return {}
end
S.LoadPresetsFromFile = LoadPresetsFromFile

local function SavePresetsToFile()
    pcall(function()
        if writefile then writefile(S.PresetFileName, HttpService:JSONEncode(S.SavedPresets)) end
    end)
end
S.SavePresetsToFile = SavePresetsToFile

S.SavedPresets = LoadPresetsFromFile()

local function ListenForTools(char)
    if not char then return end
    if S.ToolAddedConnection then S.ToolAddedConnection:Disconnect(); S.ToolAddedConnection = nil end
    if S.ToolRemovedConnection then S.ToolRemovedConnection:Disconnect(); S.ToolRemovedConnection = nil end
    S.ToolAddedConnection = char.ChildAdded:Connect(function(child)
        if S.AutoEnableOnEquip and child:IsA("Tool") then
            if not table.find(S.ToolBlacklist, child.Name) then
                if S.MasterEnabled then S.AimbotActive = true end
            end
        end
    end)
    S.ToolRemovedConnection = char.ChildRemoved:Connect(function(child)
        if S.AutoEnableOnEquip and child:IsA("Tool") then
            S.AimbotActive = false; S.CurrentTarget = nil; SetADSState(false)
        end
    end)
end

local CharacterConnection = Player.CharacterAdded:Connect(function(char)
    HookThreatHealth(char); ListenForTools(char)
end)
table.insert(getgenv().TASFF.Connections, CharacterConnection)

if Player.Character then HookThreatHealth(Player.Character); ListenForTools(Player.Character) end

-- Threat Neutralization: hooks a player's current and future humanoids
local function HookNeutralization(p)
    if not p or p == Player then return end
    local function hookHum(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        hum.Died:Connect(function()
            if S.KillCountThreatEnabled then
                local creator = hum:FindFirstChild("creator")
                if creator and creator:IsA("ObjectValue") and creator.Value and creator.Value:IsA("Player") then
                    local killer = creator.Value
                    if killer ~= Player and killer ~= p then
                        S.PlayerKillCounts[killer.Name] = (S.PlayerKillCounts[killer.Name] or 0) + 1
                        if S.PlayerKillCounts[killer.Name] >= (S.KillsBeforeThreat or 3) then
                            local kData = S.IntelPlayers and S.IntelPlayers[killer.Name]
                            local isTracked = kData and (kData.nemesis or kData.source == "Threat" or kData.source == "Registry")
                            if not isTracked then
                                if S.AddToIntel then S.AddToIntel(killer.Name, "Threat", 30) end
                                Notify({Title="TASFF Threat", Content=killer.Name.." flagged as Threat (Kill Streak).", Duration=2, Image="alert-circle"})
                            end
                        end
                    end
                end
            end

            if not S.ThreatNeutralizationEnabled then return end
            local data = S.IntelPlayers and S.IntelPlayers[p.Name]
            if data and not data.nemesis and S.RemoveFromIntel then
                S.RemoveFromIntel(p.Name, false)
                Notify({Title="Intel",Content="Neutralized: "..p.Name.." removed from Intel.",Duration=2,Image="check-circle"})
            end
        end)
    end
    -- Hook current character (if already spawned)
    if p.Character then task.spawn(hookHum, p.Character) end
    -- Hook all future respawns
    p.CharacterAdded:Connect(hookHum)
end
table.insert(getgenv().TASFF.Connections, Players.PlayerAdded:Connect(HookNeutralization))
for _, ep in ipairs(Players:GetPlayers()) do pcall(HookNeutralization, ep) end

-- Auto-Expire on Disconnect
table.insert(getgenv().TASFF.Connections, Players.PlayerRemoving:Connect(function(p)
    if S.AutoExpireOnDisconnect and S.IntelPlayers and S.IntelPlayers[p.Name] and not S.IntelPlayers[p.Name].nemesis then
        if S.RemoveFromIntel then S.RemoveFromIntel(p.Name, false) end
    end
end))

task.defer(function()
    task.wait(0.2)
    S.CurrentTarget = nil
    S.ScriptInitialized = true
    print("[TASFF v2.0.0] Core initialized.")
end)

-- // ══════════════════════════════════════════════════════════════ // --
-- //                      MAIN RENDER LOOP                        // --
-- // ══════════════════════════════════════════════════════════════ // --

local function UpdateSpectator()
    if S.SpectatePlayerEnabled and S.SpectateTarget and S.SpectateTarget ~= "" then
        local p = Players:FindFirstChild(S.SpectateTarget)
        if p and p.Character and p.Character:FindFirstChild("Humanoid") then
            workspace.CurrentCamera.CameraSubject = p.Character.Humanoid
            return
        end
    end
    local selfHum = Player.Character and Player.Character:FindFirstChild("Humanoid")
    if workspace.CurrentCamera.CameraSubject ~= selfHum then
        workspace.CurrentCamera.CameraSubject = selfHum or nil
    end
end

local RenderConnection = RunService.RenderStepped:Connect(function(deltaTime)
    if not S.ScriptInitialized then return end
    UpdateSpectator()
    EnsureDrawings()
    local RunHeavySystems  = ShouldRunSubsystem("HeavySystems")
    local cachedIgnoreList = GetIgnoreList()
    local MasterEnabled    = S.MasterEnabled
    local AimbotActive     = S.AimbotActive
    local TargetingEnabled = S.TargetingEnabled
    local heldTool          = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
    local isToolBlacklisted = heldTool and table.find(S.ToolBlacklist, heldTool.Name)
    local canAimWithTool    = not S.AutoEnableOnEquip or (heldTool and not isToolBlacklisted)
    local screenCenter  = GetAimPosition()
    local shouldShowFOV = S.ShowFOV and not S.InvisibleFOV and MasterEnabled and AimbotActive
    if S.FOVCircle then
        if shouldShowFOV then
            PrepareDrawing(S.FOVCircle)
            S.FOVCircle.Position = screenCenter
            pcall(function() S.FOVCircle.Point = screenCenter end)
            S.FOVCircle.Radius  = S.FOVSize
            S.FOVCircle.Color   = S.FOVColor or S.FOVCircle.Color
            S.FOVCircle.Visible = true
        else
            S.FOVCircle.Visible = false
        end
    end
    ClearCrosshair()
    if S.EnableCrosshair and MasterEnabled then
        local color = S.CrosshairColor or Color3.fromRGB(0, 255, 255)
        for _, el in pairs(CrosshairElements) do PrepareDrawing(el) end
        local CE = CrosshairElements; local sz = S.CrosshairSize
        if CE.Dot then
            CE.Dot.Position = screenCenter
            pcall(function() CE.Dot.Point = screenCenter end)
            CE.Dot.Color = color; CE.Dot.Visible = true
        end
        local style = S.CrosshairStyle
        if style == "Plus" and CE.Top then
            CE.Top.From=Vector2.new(screenCenter.X,screenCenter.Y-sz); CE.Top.To=Vector2.new(screenCenter.X,screenCenter.Y-(sz+10)); CE.Top.Color=color; CE.Top.Visible=true
            CE.Bottom.From=Vector2.new(screenCenter.X,screenCenter.Y+sz); CE.Bottom.To=Vector2.new(screenCenter.X,screenCenter.Y+(sz+10)); CE.Bottom.Color=color; CE.Bottom.Visible=true
            CE.Left.From=Vector2.new(screenCenter.X-sz,screenCenter.Y); CE.Left.To=Vector2.new(screenCenter.X-(sz+10),screenCenter.Y); CE.Left.Color=color; CE.Left.Visible=true
            CE.Right.From=Vector2.new(screenCenter.X+sz,screenCenter.Y); CE.Right.To=Vector2.new(screenCenter.X+(sz+10),screenCenter.Y); CE.Right.Color=color; CE.Right.Visible=true
        elseif style == "Square" and CE.Square then
            CE.Square.Size=Vector2.new(sz*2,sz*2); CE.Square.Position=Vector2.new(screenCenter.X-sz,screenCenter.Y-sz); CE.Square.Color=color; CE.Square.Visible=true
        elseif style == "Circle" and CE.Circle then
            CE.Circle.Position=screenCenter; CE.Circle.Radius=sz; CE.Circle.Color=color; CE.Circle.Visible=true
        end
    end
    if RunHeavySystems then
        if MasterEnabled then
            local TargetPart      = S.TargetPart; local WallCheck = S.WallCheck
            local bypassWallCheck = (TargetPart ~= "Visible On Screen") and WallCheck or false
            local VisualList = GetPotentialTargets(S.VisualMode=="All", false, cachedIgnoreList, S.ESPRenderDistance)
            local AimbotList = {}
            if AimbotActive and TargetingEnabled then
                local raw = GetPotentialTargets(false, bypassWallCheck, cachedIgnoreList, S.AimbotRenderDistance)
                for i,v in ipairs(raw) do AimbotList[i]=v end
            end
            for model,_ in pairs(TargetFirstSeenTimestamps) do
                if not model or not model.Parent or not model:FindFirstChildOfClass("Humanoid") then TargetFirstSeenTimestamps[model]=nil end
            end
            if S.CurrentTarget and S.CurrentTarget.Root then
                if (S.CurrentTarget.Root.Position-Camera.CFrame.Position).Magnitude > S.AimbotRenderDistance then S.CurrentTarget=nil end
            end
            local StickyLockActive = false
            if S.StickyAimEnabled and S.CurrentTarget and S.CurrentTarget.Instance and S.CurrentTarget.Instance.Parent then
                local hum = S.CurrentTarget.Instance:FindFirstChildOfClass("Humanoid")
                local typeMismatch = (S.CurrentTarget.IsPlayer and not S.TargetPlayers) or (not S.CurrentTarget.IsPlayer and not S.TargetNPCs)
                local wallCheckFailed = false
                if TargetPart == "Visible On Screen" then
                    -- for VoS: mark failed if the upcoming CustomTargetData scan returns nothing (handled below)
                    -- we conservatively let it pass here; the nil-target clear below handles it
                elseif WallCheck then
                    if not IsVisibleCachedWrapper(S.CurrentTarget.Instance, S.ActivePartName, cachedIgnoreList) then wallCheckFailed=true end
                end
                local outOfBounds = false
                if S.CurrentTarget.Root then
                    local d=(S.CurrentTarget.Root.Position-Camera.CFrame.Position).Magnitude
                    if d>S.AimbotRenderDistance then outOfBounds=true end
                    local sp,os=Camera:WorldToViewportPoint(S.CurrentTarget.Root.Position)
                    if S.ShowFOV and os and (Vector2.new(sp.X,sp.Y)-screenCenter).Magnitude>S.FOVSize then outOfBounds=true end
                end
                if hum and hum.Health>0 and not typeMismatch and not wallCheckFailed and not outOfBounds and AimbotActive then
                    StickyLockActive=true
                else S.CurrentTarget=nil end
            end
            if not StickyLockActive then
                if S.TargetSwitchDelayEnabled and (tick()-S.LastKillTime)<(S.SwitchDelayMs/1000) then AimbotList={} end
                local graceCondition = WallCheck or (TargetPart=="Visible On Screen")
                if S.GracePeriodEnabled and graceCondition then
                    local now=tick()
                    for i=#AimbotList,1,-1 do
                        local m=AimbotList[i].Instance
                        if not TargetFirstSeenTimestamps[m] then TargetFirstSeenTimestamps[m]=now end
                        if (now-TargetFirstSeenTimestamps[m])*1000 < S.GracePeriodMs then table.remove(AimbotList,i) end
                    end
                end
                local PP=S.PriorityPlayers or {}; local VM=S.VitalityMode; local PM=S.PriorityMode; local TNC=S.TargetNearCenter
                table.sort(AimbotList, function(a,b)
                    local aPrio=table.find(PP,a.Name); local bPrio=table.find(PP,b.Name)
                    if aPrio and not bPrio then return true end
                    if bPrio and not aPrio then return false end
                    if VM=="Weakest (HP)" then return a.Health<b.Health end
                    if VM=="Strongest (HP)" then return a.Health>b.Health end
                    local aDC=a.DistFromCenter or 999999; local bDC=b.DistFromCenter or 999999
                    if TNC then return aDC<bDC end
                    if PM=="Closest"  then return (a.Distance or 999999)<(b.Distance or 999999) end
                    if PM=="Farthest" then return (a.Distance or 999999)>(b.Distance or 999999) end
                    return aDC<bDC
                end)
                S.CurrentTarget = AimbotList[1]
            end
            if S.AutoADSEnabled then SetADSState(S.CurrentTarget~=nil and AimbotActive and canAimWithTool) end
            if S.SilentAimEnabled and S.CurrentTarget then
                S.SilentAimTargetCache=S.CurrentTarget; S.SilentAimTargetCacheTime=tick()
            elseif tick()-S.SilentAimTargetCacheTime>0.1 then S.SilentAimTargetCache=nil end
            local CustomTargetData = nil
            if TargetPart=="Visible On Screen" and S.CurrentTarget then
                local rigParts={"Head","Torso","UpperTorso","LowerTorso","Left Arm","LeftUpperArm","LeftLowerArm","LeftHand","Right Arm","RightUpperArm","RightLowerArm","RightHand","Left Leg","LeftUpperLeg","LeftLowerLeg","LeftFoot","Right Leg","RightUpperLeg","RightLowerLeg","RightFoot"}
                local camPos=Camera.CFrame.Position
                local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Exclude
                local ignList={}; for _,v in ipairs(cachedIgnoreList) do table.insert(ignList,v) end
                table.insert(ignList, S.CurrentTarget.Instance)
                rp.FilterDescendantsInstances=ignList; rp.IgnoreWater=true
                local bDist=999999; local bPart=nil; local sc=GetAimPosition()
                for _,pn in ipairs(rigParts) do
                    local part=S.CurrentTarget.Instance:FindFirstChild(pn)
                    if part and part:IsA("BasePart") then
                        local dir=part.Position-camPos; local res=workspace:Raycast(camPos,dir,rp)
                        if not res or res.Instance:IsDescendantOf(S.CurrentTarget.Instance) then
                            local sp,os=Camera:WorldToViewportPoint(part.Position)
                            if os then
                                local sPos=ApplyScreenCalibration(Vector2.new(sp.X,sp.Y))
                                local d=(sPos-sc).Magnitude
                                if d<bDist then bDist=d; bPart=part end
                            end
                        end
                    end
                end
                if bPart then CustomTargetData={Part=bPart, Position=bPart.Position} else S.CurrentTarget=nil end
            end
            S.LastVisualList=VisualList; S.LastCustomTargetData=CustomTargetData
        else S.LastVisualList={}; S.LastCustomTargetData=nil end
    end
    ClearVisuals()
    if MasterEnabled and S.LastVisualList then
        local NE=S.NemesisEnabled; local FM=S.FocusMode; local VM=S.VisualMode
        local VCE=S.VisibilityColorsEnabled
        local VC=S.VisibleColor or Color3.fromRGB(0,255,0); local HC=S.HiddenColor or Color3.fromRGB(255,0,0)
        local ERD=S.ESPRenderDistance; local UH=S.UseHighlight; local UNH=S.UseNPCHighlight
        local UIT=S.UseInfoTag; local UNIT=S.UseNPCInfoTag
        local SDisp=S.ShowDisplayName; local STC=S.ShowToolCheck
        local SE=S.SnaplinesEnabled; local SO=S.SnaplineOrigin
        local OOFE=S.OOFArrowsEnabled; local OOFR=S.OOFArrowRadius
        local BME=S.BoxModeEnabled; local SkME=S.SkeletonModeEnabled
        local ChE=S.ChamsEnabled; local ChO=S.ChamsOpacity
        local HLC=S.HighlightColor or Color3.fromRGB(255,255,255)
        local SLC=S.SnaplineColor or Color3.fromRGB(255,50,50)
        local PP=S.PriorityPlayers or {}
        local myRoot=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        local myPos=myRoot and myRoot.Position or Vector3.new(0,0,0)
        for _,t in ipairs(S.LastVisualList) do
            local isPriority=table.find(PP,t.Name)~=nil
            local isNemesis=NE and NemesisMemory[t.Name]~=nil
            local inFocus=not FM or isPriority
            local isPrimary=S.CurrentTarget and t.Instance==S.CurrentTarget.Instance
            local show=inFocus and (VM=="All" or VM=="Multiple" or (VM=="Single" and isPrimary))
            local dist=math.floor((myPos-t.Position).Magnitude)
            if not show or not t.Instance or dist>ERD then
                local tc=TagCache[t.Instance]
                if tc then if typeof(tc)=="Instance" then tc.Enabled=false else pcall(function() tc.Visible=false end) end end
                if BoxCache[t.Instance] then BoxCache[t.Instance].Visible=false end
                if SnaplineCache[t.Instance] then SnaplineCache[t.Instance].Visible=false end
                if OOFArrowCache[t.Instance] then OOFArrowCache[t.Instance].Visible=false end
                if SkeletonCache[t.Instance] then for _,l in pairs(SkeletonCache[t.Instance]) do if l and l.Line then l.Line.Visible=false end end end
                continue
            end
            local h,tag=GetVisualAssets(t.Instance)
            if not (h and tag) then continue end
            local isVisNow=true
            if VCE then isVisNow=IsVisibleCachedWrapper(t.Instance,"HumanoidRootPart",cachedIgnoreList) end
            local bc=HLC or t.TeamColor
            if isNemesis then bc=Color3.fromRGB(150,0,255)
            elseif isPriority then bc=Color3.fromRGB(255,50,50)
            elseif VCE then bc=isVisNow and VC or HC end
            h.Adornee=t.Instance
            if t.IsPlayer then h.Enabled=UH else h.Enabled=UNH end
            h.OutlineColor=bc
            local rootPart=t.Instance:FindFirstChild("HumanoidRootPart")
            local headPart=t.Instance:FindFirstChild("Head")
            if not rootPart then continue end
            local pos,onScreen=Camera:WorldToViewportPoint(rootPart.Position)
            local headPos=headPart and Camera:WorldToViewportPoint(headPart.Position+Vector3.new(0,0.5,0)) or pos
            if OOFE and not onScreen then
                if not OOFArrowCache[t.Instance] then
                    local ok,arrow=pcall(Drawing.new,"Triangle")
                    if ok and arrow then arrow.Thickness=2;arrow.Filled=true;OOFArrowCache[t.Instance]=arrow end
                end
                local arrow=OOFArrowCache[t.Instance]
                if arrow then
                    local center=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
                    local relX,relY=pos.X-center.X,pos.Y-center.Y
                    if pos.Z<0 then relX=-relX;relY=-relY end
                    local angle=math.atan2(relY,relX); local r=OOFR
                    arrow.PointA=center+Vector2.new(math.cos(angle),math.sin(angle))*r
                    arrow.PointB=center+Vector2.new(math.cos(angle-0.2),math.sin(angle-0.2))*(r-20)
                    arrow.PointC=center+Vector2.new(math.cos(angle+0.2),math.sin(angle+0.2))*(r-20)
                    arrow.Color=SLC or bc; arrow.Visible=true
                end
            else if OOFArrowCache[t.Instance] then OOFArrowCache[t.Instance].Visible=false end end
            if onScreen then
                local hs=ApplyScreenCalibration(Vector2.new(headPos.X,headPos.Y))
                if (t.IsPlayer and UIT) or (not t.IsPlayer and UNIT) then
                    local hdr=""
                    local at=t.Instance:FindFirstChildOfClass("Tool")
                    if STC and at then hdr="["..at.Name:upper().."] " end
                    if isNemesis then hdr=hdr.."[NEMESIS] " elseif isPriority then hdr=hdr.."[PRIORITY] " end
                    if t.IsTeammate then hdr=hdr.."[TEAM] " end
                    local ns=""
                    if t.IsPlayer and SDisp then local po=Players:FindFirstChild(t.Name); if po then ns="("..po.DisplayName..") " end end
                    local fs=string.format("%s%s%s\nHP: %d | Dist: %d",hdr,ns,t.Name,math.floor(t.Health),dist)
                    if typeof(tag)=="Instance" and tag:IsA("BillboardGui") then
                        local lbl=tag:FindFirstChildOfClass("TextLabel")
                        if lbl then lbl.Text=fs;lbl.TextColor3=bc end
                        tag.Adornee=t.Instance:FindFirstChild("Head") or rootPart; tag.Enabled=true
                    else tag.Text=fs;tag.Position=Vector2.new(hs.X,hs.Y-35);tag.Color=bc;tag.Visible=true end
                else if typeof(tag)=="Instance" then tag.Enabled=false else pcall(function() tag.Visible=false end) end end
                if SE then
                    if not SnaplineCache[t.Instance] then local line=NewDrawing("Line"); if line then line.Thickness=1.5;SnaplineCache[t.Instance]=line end end
                    local sl=SnaplineCache[t.Instance]
                    if sl then
                        PrepareDrawing(sl)
                        local o2=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y)
                        if SO=="Center" then o2=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2) end
                        sl.From=o2;sl.To=Vector2.new(pos.X,pos.Y);sl.Color=SLC or bc;sl.Visible=true
                    end
                else if SnaplineCache[t.Instance] then SnaplineCache[t.Instance].Visible=false end end
                if BME then
                    local lp=Camera:WorldToViewportPoint(rootPart.Position-Vector3.new(0,3,0))
                    local bH=math.abs(headPos.Y-lp.Y); local bW=bH*0.65
                    if not BoxCache[t.Instance] then local box=NewDrawing("Square"); if box then box.Thickness=1.5;box.Filled=false;BoxCache[t.Instance]=box end end
                    if BoxCache[t.Instance] then
                        PrepareDrawing(BoxCache[t.Instance])
                        BoxCache[t.Instance].Size=Vector2.new(bW,bH)
                        BoxCache[t.Instance].Position=Vector2.new(hs.X-(bW/2),hs.Y)
                        BoxCache[t.Instance].Color=bc; BoxCache[t.Instance].Visible=true
                    end
                else if BoxCache[t.Instance] then BoxCache[t.Instance].Visible=false end end
                if SkME then
                    local isR15=t.Instance:FindFirstChild("UpperTorso")~=nil
                    DrawSkeleton(t.Instance, isR15 and R15Joints or R6Joints, bc)
                else if SkeletonCache[t.Instance] then for _,l in ipairs(SkeletonCache[t.Instance]) do if l and l.Line then l.Line.Visible=false end end end end
            else
                if typeof(tag)=="Instance" then tag.Enabled=false else pcall(function() tag.Visible=false end) end
                if BoxCache[t.Instance] then BoxCache[t.Instance].Visible=false end
                if SnaplineCache[t.Instance] then SnaplineCache[t.Instance].Visible=false end
                if SkeletonCache[t.Instance] then for _,l in ipairs(SkeletonCache[t.Instance]) do if l and l.Line then l.Line.Visible=false end end end
            end
            if ChE then h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop;h.FillColor=bc;h.FillTransparency=1-(math.clamp(ChO,1,10)/10)
            else h.DepthMode=Enum.HighlightDepthMode.Occluded;h.FillTransparency=1 end
        end
    end
    if MasterEnabled then
        local CT=S.CurrentTarget; local TP=S.TargetPart
        if CT and TargetingEnabled and AimbotActive and canAimWithTool then
            local TWP=nil
            local tv=CT.Root and CT.Root.AssemblyLinearVelocity or Vector3.new(0,0,0)
            local isM=tv.Magnitude>1.5; local Mode=S.Mode; local PA=S.PredictionAmount
            if TP=="Visible On Screen" then
                if S.LastCustomTargetData and S.LastCustomTargetData.Part and S.LastCustomTargetData.Part.Parent then
                    local lvPart = S.LastCustomTargetData.Part
                    TWP = lvPart.Position + (lvPart.AssemblyLinearVelocity * PA)
                else TWP=nil end
            else
                local bn=TP
                if Mode=="Legit (Camera)" or Mode=="Advanced Legit (Mouse)" then
                    bn=isM and (CT.Instance:FindFirstChild("Torso") and "Torso" or "UpperTorso") or "Head"
                    if S.RandomizeHitboxEnabled then local opts={"Head","UpperTorso","LowerTorso"};bn=opts[math.random(1,#opts)] end
                end
                local bone=CT.Instance:FindFirstChild(bn) or CT.Root
                if bone then TWP=bone.Position+(bone.AssemblyLinearVelocity*PA) end
            end
            if TWP and S.WallCheck and TP~="Visible On Screen" then
                local ti={}; for _,v in ipairs(cachedIgnoreList) do table.insert(ti,v) end; table.insert(ti,CT.Instance)
                if not IsVisibleCachedWrapper(CT.Instance,S.ActivePartName,ti) then TWP=nil end
            end
            if TWP then
                local tcf=CFrame.new(Camera.CFrame.Position,TWP)
                local sp,os=Camera:WorldToViewportPoint(TWP)
                local tsp=os and ApplyScreenCalibration(Vector2.new(sp.X,sp.Y)) or nil
                local Sm=S.Smoothness
                if Mode=="Legit (Camera)" then
                    Camera.CFrame=Camera.CFrame:Lerp(tcf,math.clamp(deltaTime*(6/math.max(0.1,Sm)),0.01,1))
                elseif Mode=="Advanced Legit (Mouse)" then
                    if tsp then
                        local mp=UserInputService:GetMouseLocation(); local d2=(tsp-mp).Magnitude
                        local fr=math.max(1.0,Sm*(1+(150/math.max(d2,1)))); local tv2=tick()*6
                        local sx=math.sin(tv2)*(d2*0.012); local sy=math.cos(tv2*1.3)*(d2*0.012)
                        local mv=Vector2.new(tsp.X+sx,tsp.Y+sy)-mp
                        local step=math.clamp(deltaTime*(25/fr),0.01,1)
                        if UserInputService.MouseBehavior==Enum.MouseBehavior.LockCenter then mousemoverel(mv.X*step,mv.Y*step)
                        else mousemoveabs(mp.X+mv.X*step,mp.Y+mv.Y*step) end
                    end
                elseif Mode=="Blatant" then Camera.CFrame=tcf end
            end
        end
        local MME=S.MeleeModeEnabled; local eMR=false
        if MME and Player.Character then
            local mr2=Player.Character:FindFirstChild("HumanoidRootPart")
            if mr2 then local mr=S.MeleeDetectionRange; for _,t in ipairs(S.LastVisualList) do if t.Instance and t.Root and (mr2.Position-t.Root.Position).Magnitude<=mr then eMR=true;break end end end
        end
        local CT2=S.CurrentTarget; local CM=S.ClickMethod; local TCM=S.TriggerbotClickMode
        local CI=S.ClickInterval; local MCI=S.MeleeClickInterval
        local tbA=S.AutoClickEnabled and CT2~=nil and TargetingEnabled and AimbotActive and canAimWithTool
        local mA=MME and eMR
        if tbA or mA then
            local coord; if S.ThirdPersonTriggerbot and CT2 and CT2.ScreenPos then coord=CT2.ScreenPos else coord=UserInputService:GetMouseLocation() end
            local aI=mA and MCI or CI
            if CM=="Hold" then
                if not S.IsHoldingClick then S.IsHoldingClick=true; if TCM=="Physical" and mouse1press then mouse1press() else VirtualInputManager:SendMouseButtonEvent(coord.X,coord.Y,0,true,game,0) end end
            elseif CM=="Mash" then
                if (tick()-S.LastClickTime)>=(aI/1000) then
                    S.LastClickTime=tick()
                    task.spawn(function() if TCM=="Physical" and mouse1click then mouse1click() else VirtualInputManager:SendMouseButtonEvent(coord.X,coord.Y,0,true,game,0); task.wait(0.01); VirtualInputManager:SendMouseButtonEvent(coord.X,coord.Y,0,false,game,0) end end)
                end
            end
        else
            if S.IsHoldingClick then
                S.IsHoldingClick=false; local c2=UserInputService:GetMouseLocation()
                if TCM=="Physical" and mouse1release then mouse1release() else VirtualInputManager:SendMouseButtonEvent(c2.X,c2.Y,0,false,game,0) end
            end
        end
        local CT3=S.CurrentTarget
        if S.KeyTriggerbotEnabled and CT3~=nil and TargetingEnabled and AimbotActive and canAimWithTool then
            pcall(function()
                local key=GetKeyCode(S.KeyTriggerbotKey); local KTM=S.KeyTriggerMode
                if key then
                    if KTM=="Hold" then if not S.IsHoldingTriggerKey then S.IsHoldingTriggerKey=true;VirtualInputManager:SendKeyEvent(true,key,false,game) end
                    elseif KTM=="Mash" then if (tick()-S.LastKeyTriggerTime)>=0.1 then S.LastKeyTriggerTime=tick(); task.spawn(function() VirtualInputManager:SendKeyEvent(true,key,false,game);task.wait(0.02);VirtualInputManager:SendKeyEvent(false,key,false,game) end) end
                    elseif KTM=="Single Press" then if not S.IsHoldingTriggerKey then S.IsHoldingTriggerKey=true; task.spawn(function() VirtualInputManager:SendKeyEvent(true,key,false,game);task.wait(0.02);VirtualInputManager:SendKeyEvent(false,key,false,game) end) end
                    end
                end
            end)
        else
            if S.IsHoldingTriggerKey then
                S.IsHoldingTriggerKey=false
                pcall(function() local key=GetKeyCode(S.KeyTriggerbotKey); if key then VirtualInputManager:SendKeyEvent(false,key,false,game) end end)
            end
        end
    end
end)

table.insert(getgenv().TASFF.Connections, RenderConnection)

local oldIndex
oldIndex = hookmetamethod(game, "__index", function(t, k)
    if k~="Hit" and k~="Target" and k~="UnitRay" then return oldIndex(t,k) end
    if checkcaller() then return oldIndex(t,k) end
    if S.SilentAimEnabled and S.MasterEnabled and S.SilentAimTargetCache and S.SilentAimTargetCache.Instance then
        local bone=S.SilentAimTargetCache.Instance:FindFirstChild(S.TargetPart) or S.SilentAimTargetCache.Instance:FindFirstChild("HumanoidRootPart")
        if bone then
            if k=="Hit" then return bone.CFrame end
            if k=="Target" then return bone end
            if k=="UnitRay" then local o=Camera.CFrame.Position; return Ray.new(o,(bone.Position-o).Unit) end
        end
    end
    return oldIndex(t,k)
end)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method=getnamecallmethod()
    local vm={Raycast=true,Blockcast=true,Spherecast=true,Shapecast=true,FindPartOnRayWithIgnoreList=true,FindPartOnRayWithWhitelist=true,FindPartOnRay=true}
    if not vm[method] then return oldNamecall(self,...) end
    if checkcaller() then return oldNamecall(self,...) end
    if S.SilentAimEnabled and S.MasterEnabled and S.SilentAimTargetCache and S.SilentAimTargetCache.Instance then
        local args={...}
        local root=S.SilentAimTargetCache.Instance:FindFirstChild("HumanoidRootPart")
        local bone=S.SilentAimTargetCache.Instance:FindFirstChild(S.TargetPart) or root
        if bone and typeof(self)=="Instance" and (self==workspace or self:IsA("Workspace")) then
            local origin
            if method=="Raycast" or method=="Spherecast" then origin=args[1]
            elseif method=="Blockcast" then origin=args[1].Position
            elseif method=="Shapecast" then origin=args[2].Position
            else origin=args[1].Origin end
            local ov
            if method=="Raycast" then ov=args[2]
            elseif method=="Blockcast" or method=="Spherecast" or method=="Shapecast" then ov=args[3]
            else ov=args[1].Direction end
            local cL=(typeof(ov)=="Vector3" and ov.Magnitude) or 1000
            local dir=(bone.Position-origin).Unit*cL
            if method=="Raycast" then args[2]=dir
            elseif method=="Blockcast" or method=="Spherecast" or method=="Shapecast" then args[3]=dir
            else args[1]=Ray.new(origin,dir) end
            return oldNamecall(self,unpack(args))
        end
    end
    return oldNamecall(self,...)
end)

getgenv().TASFF.Cleanup = function()
    pcall(function() hookmetamethod(game,"__index",oldIndex) end)
    pcall(function() hookmetamethod(game,"__namecall",oldNamecall) end)
    if getgenv().TASFF.Drawings then for _,d in ipairs(getgenv().TASFF.Drawings) do pcall(function() d:Remove() end) end; table.clear(getgenv().TASFF.Drawings) end
    if getgenv().TASFF.Connections then
        for _,conn in pairs(getgenv().TASFF.Connections) do if typeof(conn)=="RBXScriptConnection" and conn.Connected then conn:Disconnect() end end
        table.clear(getgenv().TASFF.Connections)
    end
    for _,child in ipairs(CoreGui:GetChildren()) do if child.Name=="TASFF_UI" or child.Name=="Rayfield" then child:Destroy() end end
end

print("[TASFF Core] All function slots registered. Render loop active.")
