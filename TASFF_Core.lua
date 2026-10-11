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
local Rayfield = (getgenv and getgenv().TASFF and getgenv().TASFF.Rayfield) or nil
local Player  = Players.LocalPlayer
local Camera  = workspace.CurrentCamera

local function GetTASFFEnv()
    return (getgenv and type(getgenv) == "function") and getgenv().TASFF or nil
end

local function TrackConnection(conn)
    local env = GetTASFFEnv()
    if not env or type(env.Connections) ~= "table" or not conn then return end
    if typeof(conn) == "RBXScriptConnection" then
        for i = #env.Connections, 1, -1 do
            local existing = env.Connections[i]
            if not existing or typeof(existing) ~= "RBXScriptConnection" or not existing.Connected then
                table.remove(env.Connections, i)
            elseif existing == conn then
                return
            end
        end
        table.insert(env.Connections, conn)
    end
end

local function TrackDrawing(obj)
    local env = GetTASFFEnv()
    if not env or type(env.Drawings) ~= "table" or not obj then return end
    table.insert(env.Drawings, obj)
end

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
local OverlayGui

TrackConnection(
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

local _notifyCount = 0
local _notifyWindowStart = tick()
local function Notify(options)
    if S.DisableNotifications then return end
    options = options or {}
    -- Feature 23: Notification Throttle
    local now = tick()
    if now - _notifyWindowStart >= 3 then
        _notifyWindowStart = now; _notifyCount = 0
    end
    local limit = S.NotifyMaxPer3s or 5
    if _notifyCount >= limit then return end  -- drop excess
    _notifyCount = _notifyCount + 1
    -- Apply global notification duration override
    if S.NotificationDuration and S.NotificationDuration > 0 then
        options = setmetatable({}, {__index = options})
        options.Duration = S.NotificationDuration
    end
    if Rayfield and Rayfield.Notify then
        pcall(function() Rayfield:Notify(options) end)
    end
end
S.Notify = Notify

-- Suppress Rayfield's periodic advertising notification (the "Loving this UI library?" popup)
-- We do this by hooking the existing Notify method after Rayfield loads.
task.spawn(function()
    task.wait(2)   -- give Rayfield time to fully init before we patch
    if not Rayfield then return end
    local origNotify = Rayfield.Notify
    if not origNotify then return end
    Rayfield.Notify = function(self, opts)
        -- Block notifications that originate from Rayfield's own advertising
        if S.SuppressRayfieldAds then
            local t = (opts and opts.Title) or ""
            local c = (opts and opts.Content) or ""
            if t:find("Rayfield") or t:find("sirius") or t:find("advertisement") or
               c:find("sirius.menu") or c:find("Loving this") or c:find("ui library") then
                return
            end
        end
        return origNotify(self, opts)
    end
end)



local CoreOverlayGui = nil   -- ScreenGui in hidden container / CoreGui (recording-invisible)
local OverlayGui = nil       -- ScreenGui in PlayerGui (recording-visible)

local function GetHiddenContainer()
    if type(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return nil
end

local function EnsureOverlayGui()
    local playerGui = Player and Player:FindFirstChildOfClass("PlayerGui")
    if not (OverlayGui and OverlayGui.Parent) then
        if playerGui then
            local existing = playerGui:FindFirstChild("TASFF_Overlay")
            if existing then existing:Destroy() end
            OverlayGui = Instance.new("ScreenGui")
            OverlayGui.Name = "TASFF_Overlay"
            OverlayGui.IgnoreGuiInset = true
            OverlayGui.ResetOnSpawn = false
            OverlayGui.DisplayOrder = 10000
            OverlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
            OverlayGui.Parent = playerGui
        end
    end

    local hidden = GetHiddenContainer()
    if not (CoreOverlayGui and CoreOverlayGui.Parent) then
        if hidden then
            local existing = hidden:FindFirstChild("TASFF_CoreOverlay")
            if existing then existing:Destroy() end
            CoreOverlayGui = Instance.new("ScreenGui")
            CoreOverlayGui.Name = "TASFF_CoreOverlay"
            CoreOverlayGui.IgnoreGuiInset = true
            CoreOverlayGui.ResetOnSpawn = false
            CoreOverlayGui.DisplayOrder = 10001
            CoreOverlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
            CoreOverlayGui.Parent = hidden
        else
            CoreOverlayGui = OverlayGui
        end
    end

    return OverlayGui or CoreOverlayGui
end

local function SetDrawingCloaked(drawingObj, cloaked)
    if not drawingObj or not drawingObj.Frame then return end
    EnsureOverlayGui()
    local target = (cloaked and CoreOverlayGui) or OverlayGui
    if target and drawingObj.Frame.Parent ~= target then
        drawingObj.Frame.Parent = target
    end
end

local function SetOverlayLine(frame, from, to, thickness, color, transparency, zIndex)
    local delta = to - from
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromOffset((from.X + to.X) * 0.5, (from.Y + to.Y) * 0.5)
    frame.Size = UDim2.fromOffset(delta.Magnitude, math.max(1, thickness))
    frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    frame.BackgroundColor3 = color
    frame.BackgroundTransparency = 1 - transparency
    frame.ZIndex = zIndex
end

local function UpdateOverlayDrawing(object)
    local values = object.Values
    local frame = object.Frame
    local visible = values.Visible == true
    local alpha = math.clamp(tonumber(values.Transparency) or 1, 0, 1)
    local color = typeof(values.Color) == "Color3" and values.Color or Color3.new(1, 1, 1)
    local thickness = math.max(1, tonumber(values.Thickness) or 1)
    local zIndex = math.clamp(math.floor(tonumber(values.ZIndex) or 60), 1, 100)

    frame.Visible = visible
    frame.ZIndex = zIndex
    if object.Kind == "Line" then
        if typeof(values.From) == "Vector2" and typeof(values.To) == "Vector2" then
            SetOverlayLine(frame, values.From, values.To, thickness, color, alpha, zIndex)
        end
    elseif object.Kind == "Circle" then
        local radius = math.max(0, tonumber(values.Radius) or 0)
        local position = typeof(values.Position) == "Vector2" and values.Position or Vector2.zero
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.Position = UDim2.fromOffset(position.X, position.Y)
        frame.Size = UDim2.fromOffset(radius * 2, radius * 2)
        frame.BackgroundColor3 = color
        frame.BackgroundTransparency = values.Filled and (1 - alpha) or 1
        frame.ZIndex = zIndex
        object.Stroke.Color = color
        object.Stroke.Thickness = thickness
        object.Stroke.Transparency = 1 - alpha
        object.Stroke.Enabled = not values.Filled
    elseif object.Kind == "Square" then
        local position = typeof(values.Position) == "Vector2" and values.Position or Vector2.zero
        local size = typeof(values.Size) == "Vector2" and values.Size or Vector2.zero
        frame.AnchorPoint = Vector2.zero
        frame.Position = UDim2.fromOffset(position.X, position.Y)
        frame.Size = UDim2.fromOffset(size.X, size.Y)
        frame.BackgroundColor3 = color
        frame.BackgroundTransparency = values.Filled and (1 - alpha) or 1
        object.Stroke.Color = color
        object.Stroke.Thickness = thickness
        object.Stroke.Transparency = 1 - alpha
        object.Stroke.Enabled = not values.Filled
    elseif object.Kind == "Text" then
        local position = typeof(values.Position) == "Vector2" and values.Position or Vector2.zero
        frame.AnchorPoint = values.Center and Vector2.new(0.5, 0.5) or Vector2.zero
        frame.Position = UDim2.fromOffset(position.X, position.Y)
        frame.Size = UDim2.fromOffset(320, math.max(24, (tonumber(values.Size) or 16) * 3))
        frame.BackgroundTransparency = 1
        frame.Text = tostring(values.Text or "")
        frame.TextSize = math.max(1, tonumber(values.Size) or 16)
        frame.TextColor3 = color
        frame.TextTransparency = 1 - alpha
        frame.TextStrokeColor3 = values.OutlineColor or Color3.new(0, 0, 0)
        frame.TextStrokeTransparency = values.Outline and (1 - alpha) or 1
        frame.TextXAlignment = values.Center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
        frame.TextYAlignment = Enum.TextYAlignment.Center
    elseif object.Kind == "Triangle" then
        local a, b, c = values.PointA, values.PointB, values.PointC
        if typeof(a) == "Vector2" and typeof(b) == "Vector2" and typeof(c) == "Vector2" then
            local center = (a + b + c) / 3
            local tip = a
            if (b - center).Magnitude > (tip - center).Magnitude then tip = b end
            if (c - center).Magnitude > (tip - center).Magnitude then tip = c end
            frame.AnchorPoint = Vector2.new(0.5, 0.5)
            frame.Position = UDim2.fromOffset(center.X, center.Y)
            frame.Size = UDim2.fromOffset(math.max(24, (tip - center).Magnitude * 2), math.max(24, (a - b).Magnitude))
            frame.BackgroundTransparency = 1
            frame.Text = "▲"
            frame.TextSize = math.max(16, (tip - center).Magnitude * 1.5)
            frame.TextColor3 = color
            frame.TextTransparency = 1 - alpha
            frame.Rotation = math.deg(math.atan2(tip.Y - center.Y, tip.X - center.X)) + 90
        end
    end
end

local function NewDrawing(className)
    local overlay = EnsureOverlayGui()
    if not overlay then return nil end

    local kind = className
    local frame
    if kind == "Text" or kind == "Triangle" then
        frame = Instance.new("TextLabel")
        frame.Font = Enum.Font.Code
        frame.TextWrapped = true
        frame.RichText = false
    else
        frame = Instance.new("Frame")
        frame.BorderSizePixel = 0
        frame.BackgroundTransparency = 1
    end
    frame.Name = "TASFF_" .. kind
    frame.Visible = false
    frame.Parent = overlay

    local stroke
    if kind == "Circle" or kind == "Square" then
        if kind == "Circle" then
            Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)
        end
        stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = frame
    end

    local object = {
        Kind = kind,
        Frame = frame,
        Stroke = stroke,
        Values = {
            Visible = false,
            Transparency = 1,
            ZIndex = 60,
            Color = Color3.new(1, 1, 1),
            Thickness = 1,
            Filled = false,
            Center = false,
            Outline = false,
            Text = "",
            Size = 16,
            Radius = 0,
        },
    }
    setmetatable(object, {
        __index = function(self, key)
            if key == "Remove" then
                return function(instance)
                    if instance.Frame then instance.Frame:Destroy() end
                    instance.Frame = nil
                end
            end
            return self.Values[key]
        end,
        __newindex = function(self, key, value)
            self.Values[key] = value
            UpdateOverlayDrawing(self)
        end,
    })
    TrackDrawing(object)
    return object
end
S.NewDrawing = NewDrawing

local function PrepareDrawing(obj)
    if not obj then return end
    obj.ZIndex = 60
    obj.Transparency = 1
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
        local inset = GuiService:GetGuiInset()
        position = UserInputService:GetMouseLocation() - inset
    else
        position = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
    end
    if S.ManualCalibrationEnabled then
        position = position + Vector2.new(S.CalibrationOffsetX, S.CalibrationOffsetY)
    end
    return position
end
S.GetAimPosition = GetAimPosition

local function GetEffectiveFOV(distance)
    local baseFOV = tonumber(S.FOVSize) or 100
    if not S.DynamicFOVEnabled or type(distance) ~= "number" or distance < 0 then
        return baseFOV
    end

    local scaledFOV = baseFOV * (100 / math.max(distance, 1))
    local maxFOV = tonumber(S.DynamicFOVMax) or 400   -- Bug Fix #9: guard nil
    scaledFOV = math.min(scaledFOV, maxFOV)
    return math.max(1, scaledFOV)
end

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
    S.PanicLocked   = true   -- permanent lock — only cleared by re-execution
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
    -- Bug Fix #3: also release Key Triggerbot hold if active
    S.SilentAimTargetCache = nil
    ClearVisuals()
    ClearCrosshair()
    if S.FOVCircle then S.FOVCircle.Visible = false end
    -- Use Roblox StarterGui notification — Rayfield may already be destroyed at this point
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title    = "TASFF PANIC",
            Text     = "All routines halted. Re-execute to restore.",
            Duration = 6,
        })
    end)
end
S.TriggerPanic = TriggerPanic

local function UnloadScript()
    TriggerPanic()
    if getgenv().TASFF then getgenv().TASFF.Running = false end
    if getgenv().TASFF and getgenv().TASFF.Cleanup then getgenv().TASFF.Cleanup() end
    if getgenv().TASFF and getgenv().TASFF.Connections then
        for _, conn in ipairs(getgenv().TASFF.Connections) do pcall(function() conn:Disconnect() end) end
    end
    -- Bug Fix #4: clean up all tracked drawings and destroy the overlay ScreenGui
    if getgenv().TASFF and getgenv().TASFF.Drawings then
        for _, d in ipairs(getgenv().TASFF.Drawings) do
            pcall(function() if d and d.Frame then d.Frame:Destroy() end end)
        end
        getgenv().TASFF.Drawings = {}
    end
    -- Remove TASFF_Overlay and TASFF_CoreOverlay from their containers
    local hidden = GetHiddenContainer()
    if hidden then
        local o1 = hidden:FindFirstChild("TASFF_Overlay")
        local o2 = hidden:FindFirstChild("TASFF_CoreOverlay")
        if o1 then pcall(function() o1:Destroy() end) end
        if o2 then pcall(function() o2:Destroy() end) end
    end
    local playerGui = game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        local overlay = playerGui:FindFirstChild("TASFF_Overlay")
        if overlay then pcall(function() overlay:Destroy() end) end
        local coreOverlay = playerGui:FindFirstChild("TASFF_CoreOverlay")
        if coreOverlay then pcall(function() coreOverlay:Destroy() end) end
    end
    -- Native Roblox notification — fired before Rayfield GUI is destroyed
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title    = "TASFF Unloaded",
            Text     = "Script and interface fully terminated.",
            Duration = 5,
        })
    end)
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
        if v ~= Player then
            -- Show DisplayName alongside username if they differ
            local label = v.Name
            if v.DisplayName and v.DisplayName ~= v.Name then
                label = v.DisplayName .. " (" .. v.Name .. ")"
            end
            table.insert(names, label)
        end
    end
    return names
end
-- Helper: resolve a dropdown label back to the actual username
local function ResolvePlayerName(label)
    for _, v in ipairs(Players:GetPlayers()) do
        if v ~= Player then
            if v.Name == label then return v.Name end
            local expected = v.DisplayName .. " (" .. v.Name .. ")"
            if expected == label then return v.Name end
        end
    end
    return nil  -- Bug Fix #10: return nil instead of raw label to prevent phantom entries
end
S.GetPlayerNames   = GetPlayerNames
S.ResolvePlayerName = ResolvePlayerName

local function SyncPriorityUI()
    if S.PriorityDropdownRef and S.PriorityDropdownRef.Refresh then
        pcall(function() S.PriorityDropdownRef:Refresh(GetPlayerNames(), S.PriorityPlayers) end)
    end
    if S.PriorityMonitorLabel then
        local text = ""
        for _, name in ipairs(S.PriorityPlayers) do
            local po = Players:FindFirstChild(name)
            local dn = po and po.DisplayName ~= name and (" (" .. po.DisplayName .. ")") or ""
            local kills = (S.PriorityPlayerKills or {})[name]
            local killStr = kills and kills > 0 and ("  ☠ " .. kills) or ""
            text = text .. "★ " .. name .. dn .. killStr .. "\n"
        end
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
        -- Show recorded kill count for this intel player
        local pkills = (S.PriorityPlayerKills or {})[name]
        local killSuffix = pkills and pkills > 0 and ("  ☠ " .. pkills .. "k") or ""
        table.insert(lines, name .. displaySuffix .. "  [" .. src .. "]  " .. pts .. " pts" .. killSuffix .. selected)
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
    if data and data.nemesis and not forceRemoveNemesis then
        Notify({Title="Intel",Content="Use 'Remove Nemesis' to remove a Nemesis player.",Duration=2,Image="shield-off"})
        return
    end
    if data then
        S.IntelPlayers[name] = nil
    end
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
    local boundsOk, boundsCFrame, boundsSize = pcall(function()
        return model:GetBoundingBox()
    end)
    if boundsOk and boundsCFrame and boundsSize then
        local localOrigin = boundsCFrame:PointToObjectSpace(origin)
        local halfSize = boundsSize * 0.5
        local cameraInsideTarget = math.abs(localOrigin.X) <= halfSize.X
            and math.abs(localOrigin.Y) <= halfSize.Y
            and math.abs(localOrigin.Z) <= halfSize.Z
        if cameraInsideTarget then
            local localCharacter = Player and Player.Character
            local localHead = localCharacter and localCharacter:FindFirstChild("Head")
            local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
            local fallbackOrigin = localHead and localHead.Position or (localRoot and localRoot.Position)
            if fallbackOrigin then
                local fallbackLocal = boundsCFrame:PointToObjectSpace(fallbackOrigin)
                local fallbackInsideTarget = math.abs(fallbackLocal.X) <= halfSize.X
                    and math.abs(fallbackLocal.Y) <= halfSize.Y
                    and math.abs(fallbackLocal.Z) <= halfSize.Z
                if not fallbackInsideTarget then
                    origin = fallbackOrigin
                else
                    origin = boundsCFrame.Position - unitDir * (boundsSize.Magnitude * 0.5 + 0.05)
                end
            else
                origin = boundsCFrame.Position - unitDir * (boundsSize.Magnitude * 0.5 + 0.05)
            end
            direction = destination - origin
            maxDist = direction.Magnitude
            if maxDist <= 0.01 then return true end
            unitDir = direction.Unit
        end
    end
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

local function FindVisibleOnScreenPart(model, ignoreList)
    if not model or not model.Parent then return nil end
    if not Camera then Camera = workspace.CurrentCamera end
    if not Camera then return nil end

    local partNames = {}
    for _, name in ipairs(S.VOSPriorityParts or {}) do
        if type(name) == "string" and not table.find(partNames, name) then
            table.insert(partNames, name)
        end
    end
    for _, name in ipairs({
        "Head", "Torso", "UpperTorso", "LowerTorso",
        "Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "Right Arm", "RightUpperArm", "RightLowerArm", "RightHand",
        "Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot",
    }) do
        if not table.find(partNames, name) then
            table.insert(partNames, name)
        end
    end

    local aimPosition = GetAimPosition()
    local bestPart, bestDistance = nil, math.huge
    for _, name in ipairs(partNames) do
        local part = model:FindFirstChild(name)
        local ok, isVisible = false, false
        if part and part:IsA("BasePart") then
            ok, isVisible = pcall(IsVisibleWallcheck, model, name, ignoreList)
        end
        if ok and isVisible then
            local point, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local distance = (ApplyScreenCalibration(Vector2.new(point.X, point.Y)) - aimPosition).Magnitude
                if distance < bestDistance then
                    bestPart, bestDistance = part, distance
                end
            end
        end
    end
    return bestPart
end

local _lastFP = {}
local function RegisterThreat(attackerName, isKill)
    if not attackerName or attackerName == Player.Name then return end
    if isKill then
        if S.NemesisEnabled then
            S.PlayerNemesisStrikes[attackerName] = (S.PlayerNemesisStrikes[attackerName] or 0) + 1
            if not S.PlayerNemesisStrikeTimes then S.PlayerNemesisStrikeTimes = {} end
            S.PlayerNemesisStrikeTimes[attackerName] = tick()
            local strikes = S.PlayerNemesisStrikes[attackerName]
            local req = S.KillsBeforeNemesis or 3
            if strikes >= req then
                NemesisMemory[attackerName] = tick()
                S.SessionNemesesAdded = (S.SessionNemesesAdded or 0) + 1
                if S.AddToIntel then S.AddToIntel(attackerName, "Nemesis", 25) end
                Notify({Title="TASFF Nemesis",Content="🔴 "..attackerName.." is now your Nemesis.",Duration=3,Image="flame"})
            else
                local strikeMsg = "⚠ Strike "..strikes.." — "..attackerName.." has killed you."
                if strikes == 2 then strikeMsg = "⚠ Strike 2 — "..attackerName.." is on a streak against you." end
                Notify({Title="TASFF Nemesis",Content=strikeMsg,Duration=3,Image="flame"})
            end
        else
            S.SessionThreatsAdded = (S.SessionThreatsAdded or 0) + 1
            if S.AddToIntel then S.AddToIntel(attackerName, "Threat", 25) end
        end
    else
        -- FP Cooldown Check
        local cd = S.ThreatFPCooldown or 1.5
        if tick() - (_lastFP[attackerName] or 0) < cd then return end
        _lastFP[attackerName] = tick()

        ThreatMemory[attackerName] = tick()
        local isNew = not table.find(S.PriorityPlayers, attackerName)
        S.SessionThreatsAdded = (S.SessionThreatsAdded or 0) + 1
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
    TrackConnection(humanoid.HealthChanged:Connect(function(newHealth)
        if S.ThreatDetectorEnabled and newHealth < lastHealth then
            local isKill = (newHealth <= 0)
            local creator = humanoid:FindFirstChild("creator") or humanoid:FindFirstChild("creatorTag")
            if creator and creator:IsA("ObjectValue") and creator.Value and creator.Value:IsA("Player") then
                RegisterThreat(creator.Value.Name, isKill)
            else
                local myPos = char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position
                if myPos then
                    local nearestAttacker, nearestDist = nil, S.ThreatProximityRadius or 80
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                            local root = p.Character.HumanoidRootPart
                            local d = (root.Position - myPos).Magnitude
                            if d < nearestDist then
                                local vel = root.AssemblyLinearVelocity
                                if vel.Magnitude < 5 or vel.Unit:Dot((myPos - root.Position).Unit) > 0.3 then
                                    nearestDist = d; nearestAttacker = p.Name
                                end
                            end
                        end
                    end
                    if nearestAttacker then RegisterThreat(nearestAttacker, isKill) end
                end
            end
        end
        lastHealth = newHealth
    end))
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

        -- Feature 18: Nemesis Strike Decay
        for name, timestamp in pairs(S.PlayerNemesisStrikeTimes or {}) do
            if now - timestamp >= 120 then
                if (S.PlayerNemesisStrikes[name] or 0) > 0 then
                    S.PlayerNemesisStrikes[name] = S.PlayerNemesisStrikes[name] - 1
                    S.PlayerNemesisStrikeTimes[name] = tick()
                else
                    S.PlayerNemesisStrikeTimes[name] = nil
                    S.PlayerNemesisStrikes[name] = nil
                end
            end
        end
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
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        -- Still process mouse-button marks below
    end
    if input.KeyCode ~= Enum.KeyCode.Unknown then
        local panicKey = GetKeyCode(S.PanicKeybind)
        if panicKey and input.KeyCode == panicKey then
            TriggerPanic(); return
        end
        -- Feature 17: Rapid Aim Mode Cycle
        if not gpe and S.RapidModeCycleEnabled then
            local cycleKey = GetKeyCode(S.RapidModeCycleKey)
            if cycleKey and input.KeyCode == cycleKey then
                local modes = {"Legit (Camera)", "Advanced Legit (Mouse)", "Blatant"}
                local cur = S.Mode or "Legit (Camera)"
                local idx = table.find(modes, cur) or 1
                S.Mode = modes[(idx % #modes) + 1]
                Notify({Title="TASFF Mode", Content="Aim mode → "..S.Mode, Duration=1.5, Image="refresh-cw"})
                if S.DebugMode then print("[TASFF Debug] Aim mode cycled to: "..S.Mode) end
            end
        end
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
-- v2.1.0: ShouldRunSubsystem removed — replaced by the 4-slot pipeline in the render loop
-- and time-based background task.spawn loops (see below).

local function UpdateNPCs()
    -- Use GetChildren() not GetDescendants() — far cheaper; NPCs sit directly in workspace
    local temp = {}
    for _, v in ipairs(workspace:GetChildren()) do
        if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") then
            if not Players:GetPlayerFromCharacter(v) and v ~= Player.Character then
                table.insert(temp, v)
            end
        end
    end
    S.CachedNPCs = temp
end
S.UpdateNPCs = UpdateNPCs

-- // ── v2.1.0 Background Tasks (time-based, staggered start) ───── // --
-- All heavy per-entity work runs here, NOT in the render thread.
-- Staggered delays prevent all loops from waking up simultaneously.

-- ① NPC cache refresh
task.spawn(function()
    while getgenv().TASFF and getgenv().TASFF.Running do
        pcall(UpdateNPCs)
        local biv = (S.BackgroundIntervals or {})[S.PerformanceMode or "Medium"] or {}
        task.wait(biv.NPC or 0.8)
    end
end)

-- ② Workspace model sweep (viewmodel / gun ignore list)
task.spawn(function()
    task.wait(0.3)
    while getgenv().TASFF and getgenv().TASFF.Running do
        pcall(UpdateWorkspaceIgnores)
        local biv = (S.BackgroundIntervals or {})[S.PerformanceMode or "Medium"] or {}
        task.wait(biv.Sweep or 0.6)
    end
end)

-- ③ Visibility Precompute — THE KEY FIX for stutter
-- Runs IsVisibleWallcheck for every player + NPC one-by-one with a task.wait() between each.
-- The render pipeline reads S.VisibilityPrecomputed[model] (a simple bool lookup — no raycasts).
-- This completely moves all multi-hop raycast cost off the render thread.
-- No gap wait at end — loop restarts immediately so data stays fresher with many players.
task.spawn(function()
    task.wait(0.5)   -- slight stagger so ignore list is already built
    while getgenv().TASFF and getgenv().TASFF.Running do
        if S.WallCheck and S.MasterEnabled then
            local ignoreList = GetIgnoreList()
            local partName   = S.ActivePartName or "HumanoidRootPart"

            -- Players
            if S.TargetPlayers then
                local checkParts = {partName}
                if S.TargetPart == "Visible On Screen" then
                    checkParts = {"HumanoidRootPart", "Head", "UpperTorso", "LeftUpperArm", "RightUpperArm"}
                end
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= Player and p.Character then
                        local isVis
                        if S.TargetPart == "Visible On Screen" then
                            isVis = FindVisibleOnScreenPart(p.Character, ignoreList) ~= nil
                        else
                            local ok, result = pcall(IsVisibleWallcheck, p.Character, checkParts[1], ignoreList)
                            isVis = ok and result
                        end
                        S.VisibilityPrecomputed[p.Character] = isVis
                        task.wait()   -- yield for exactly 1 frame between each raycast burst
                    end
                end
            end

            -- NPCs
            if S.TargetNPCs then
                local checkParts = {partName}
                if S.TargetPart == "Visible On Screen" then
                    checkParts = {"HumanoidRootPart", "Head", "UpperTorso", "LeftUpperArm", "RightUpperArm"}
                end
                local npcs = S.CachedNPCs or {}
                for _, npc in ipairs(npcs) do
                    if npc and npc.Parent then
                        local isVis
                        if S.TargetPart == "Visible On Screen" then
                            isVis = FindVisibleOnScreenPart(npc, ignoreList) ~= nil
                        else
                            local ok, result = pcall(IsVisibleWallcheck, npc, checkParts[1], ignoreList)
                            isVis = ok and result
                        end
                        S.VisibilityPrecomputed[npc] = isVis
                        task.wait()
                    end
                end
            end

            -- Evict stale entries (disconnected players / despawned NPCs)
            for model, _ in pairs(S.VisibilityPrecomputed) do
                if not model or not model.Parent then
                    S.VisibilityPrecomputed[model] = nil
                end
            end
        else
            -- Wallcheck off: treat everyone as visible so aimbot works normally
            S.VisibilityPrecomputed = {}
        end
        task.wait(0.05)
    end
end)

pcall(UpdateWorkspaceIgnores)
pcall(UpdateNPCs)


-- // ── v2.1.0 Feature 10: ToolBlacklist Save/Load ──────────────── // --
local BLFILE = "TASFF_ToolBlacklist.json"
local function SaveToolBlacklist()
    local env = GetTASFFEnv()
    if not (env and env.Capabilities and env.Capabilities.FileWrite)
        or type(writefile) ~= "function" then
        warn("[TASFF Core] Cannot save tool blacklist: filesystem write API is unavailable.")
        return false
    end
    local ok, err = pcall(function()
        local json = HttpService:JSONEncode(S.ToolBlacklist or {})
        writefile(BLFILE, json)
    end)
    if not ok then
        warn("[TASFF Core] Failed to save tool blacklist: " .. tostring(err))
        return false
    end
    return true
end
local function LoadToolBlacklist()
    local env = GetTASFFEnv()
    if not (env and env.Capabilities and env.Capabilities.FileRead)
        or type(isfile) ~= "function" or type(readfile) ~= "function" then
        return false
    end
    pcall(function()
        if isfile and isfile(BLFILE) then
            local raw = readfile(BLFILE)
            local ok, tbl = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok and type(tbl) == "table" then
                S.ToolBlacklist = tbl
                if S.BlacklistDropdownRef then
                    local lst = #S.ToolBlacklist > 0 and S.ToolBlacklist or {"No Registry Items Found"}
                    pcall(function() S.BlacklistDropdownRef:Refresh(lst, true) end)
                end
            end
        end
    end)
end
S.SaveToolBlacklist = SaveToolBlacklist
S.LoadToolBlacklist = LoadToolBlacklist
pcall(LoadToolBlacklist)   -- load on startup

-- // ── v2.1.0 Feature 8: Focus-Loss Panic ──────────────────────── // --
table.insert(getgenv().TASFF.Connections, game:GetService("UserInputService").WindowFocusReleased:Connect(function()
    if S.PanicOnFocusLoss and S.MasterEnabled then
        if S.TriggerPanic then S.TriggerPanic() end
    end
end))

-- // ── v2.1.0 Feature 20: Auto-Disable on Death ─────────────────── // --
local function HookAutoDisableOnDeath(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local conn; conn = hum.Died:Connect(function()
        if S.AutoDisableOnDeath then
            S.AimbotActive = false; S.CurrentTarget = nil
            if S.SetADSState then S.SetADSState(false) end
            Notify({Title="TASFF",Content="Aimbot disabled — you died.",Duration=2,Image="x"})
        end
        if conn then conn:Disconnect() end
    end)
    TrackConnection(conn)
end
if Player.Character then task.defer(HookAutoDisableOnDeath, Player.Character) end
TrackConnection(Player.CharacterAdded:Connect(function(char)
    task.wait(1)   -- wait for Humanoid to replicate
    HookAutoDisableOnDeath(char)
end))

-- // ── v2.1.0 Feature 25: Anti-AFK ─────────────────────────────── // --
task.spawn(function()
    while getgenv().TASFF and getgenv().TASFF.Running do
        task.wait(55)
        if S.AntiAFKEnabled then
            pcall(function()
                local VIM = game:GetService("VirtualInputManager")
                VIM:SendMouseMoveEvent(1, 0, game)
                task.wait(0.05)
                VIM:SendMouseMoveEvent(-1, 0, game)
            end)
        end
    end
end)

-- // ── v2.1.0 Feature 26: FPS Watcher / Auto-Tune ───────────────── // --
task.spawn(function()
    task.wait(3)   -- let game settle first
    local lastManualMode = S.PerformanceMode or "Medium"
    local autoDowngraded  = false
    while getgenv().TASFF and getgenv().TASFF.Running do
        task.wait(2)
        if not S.FPSWatcherEnabled then
            -- If we previously auto-downgraded, restore user's setting
            if autoDowngraded then
                S.PerformanceMode = lastManualMode; autoDowngraded = false
                Notify({Title="TASFF FPS",Content="FPS stable — restored to "..lastManualMode..".",Duration=2,Image="cpu"})
            end
        else
            local fps = math.floor(1 / (S._lastDeltaTime or 0.0167))
            -- Save user's current mode before any auto-change
            if not autoDowngraded then lastManualMode = S.PerformanceMode or "Medium" end
            local order = {"Ultra High","High","Medium","Low","Ultra Low"}
            local curIdx = table.find(order, S.PerformanceMode or "Medium") or 3
            if fps < 30 and curIdx < #order then
                -- FPS too low — step down one level
                S.PerformanceMode = order[curIdx + 1]; autoDowngraded = true
                Notify({Title="TASFF FPS",Content="Low FPS ("..fps..") — stepped to "..S.PerformanceMode..".",Duration=2,Image="cpu"})
            elseif fps > 55 and autoDowngraded and curIdx > 1 then
                -- FPS recovered — step back up
                S.PerformanceMode = order[curIdx - 1]
                if S.PerformanceMode == lastManualMode then autoDowngraded = false end
                Notify({Title="TASFF FPS",Content="FPS recovered — stepped to "..S.PerformanceMode..".",Duration=2,Image="cpu"})
            end
        end
    end
end)


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
    for model in pairs(S.VisibilityPrecomputed) do
        if not IsModelValid(model) then
            S.VisibilityPrecomputed[model] = nil
        end
    end
    for model, _ in pairs(TargetFirstSeenTimestamps) do
        if not IsModelValid(model) then TargetFirstSeenTimestamps[model] = nil end
    end
end
S.CleanupCaches = CleanupCaches

task.spawn(function()
    -- Cache cleanup: 0.7s stagger, runs infrequently based on BackgroundIntervals.Cache
    task.wait(0.7)
    while getgenv().TASFF and getgenv().TASFF.Running do
        pcall(CleanupCaches)
        local biv = (S.BackgroundIntervals or {})[S.PerformanceMode or "Medium"] or {}
        task.wait(biv.Cache or 8)
    end
end)


local function GetVisualAssets(model, forceBillboard)
    local h = HighlightCache[model]
    if not h or not h.Parent or not h:IsDescendantOf(model) then
        if h and h.Parent then h:Destroy() end
        h = Instance.new("Highlight")
        h.Parent = model
        h.FillTransparency = 1
        HighlightCache[model] = h
    end
    local tag = TagCache[model]
    local wantDrawing = S.StreamProofESP and not forceBillboard
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
            tag = Instance.new("BillboardGui")
            local hidden = forceBillboard and GetHiddenContainer()
            tag.Parent = hidden or model
            tag.Size=UDim2.new(0,200,0,70); tag.AlwaysOnTop=true; tag.StudsOffset=Vector3.new(0,3,0)
            local l = Instance.new("TextLabel", tag)
            l.Size=UDim2.new(1,0,1,0); l.BackgroundTransparency=1; l.Font=Enum.Font.Code; l.TextSize=14
        end
        TagCache[model] = tag
    else
        if isInstance and tag:IsA("BillboardGui") then
            local hidden = forceBillboard and GetHiddenContainer()
            local targetParent = hidden or model
            if tag.Parent ~= targetParent then
                tag.Parent = targetParent
            end
        end
    end
    return h, tag
end
S.GetVisualAssets = GetVisualAssets

local SCREEN_ANCHOR_PARTS = {
    "Head", "UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart",
    "LeftUpperArm", "Left Arm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "Right Arm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "Left Leg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "Right Leg", "RightLowerLeg", "RightFoot",
}

local function GetScreenAnchor(model, root, aimPosition)
    local names, seenNames = {}, {}
    local function addName(name)
        if type(name) == "string" and name ~= "" and not seenNames[name] then
            seenNames[name] = true
            table.insert(names, name)
        end
    end
    local configuredPart = S.TargetPart
    if type(configuredPart) == "string" and configuredPart ~= "" and configuredPart ~= "Visible On Screen" then
        addName(configuredPart)
    end
    for _, name in ipairs(S.VOSPriorityParts or {}) do
        addName(name)
    end
    for _, name in ipairs(SCREEN_ANCHOR_PARTS) do
        addName(name)
    end

    local bestPart, bestPosition, bestDistance = nil, nil, math.huge
    for _, name in ipairs(names) do
        local part = model:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            local point, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen and point.Z > 0 then
                local screenPosition = ApplyScreenCalibration(Vector2.new(point.X, point.Y))
                local distance = (screenPosition - aimPosition).Magnitude
                if distance < bestDistance then
                    bestPart, bestPosition, bestDistance = part, screenPosition, distance
                end
            end
        end
    end

    if bestPart then return bestPart, bestPosition, bestDistance end
    if root then
        local point, onScreen = Camera:WorldToViewportPoint(root.Position)
        if onScreen and point.Z > 0 then
            local screenPosition = ApplyScreenCalibration(Vector2.new(point.X, point.Y))
            return root, screenPosition, (screenPosition - aimPosition).Magnitude
        end
    end
    return nil, nil, math.huge
end

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
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not character.Parent or not humanoid or humanoid.Health <= 0 then
        for _, limb in ipairs(limbs) do
            if limb.Line then limb.Line.Visible = false end
        end
        return
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

local function GetPotentialTargets(ignoreFOV, performWallCheck, customIgnoreList, maxDistance, isForESP)
    local results = {}
    local screenCenter = GetAimPosition()
    local function Process(model, isPlayer, pObj)
        if not model then return end
        local targetName = isPlayer and pObj.Name or model.Name
        local isBlacklisted = isPlayer and table.find(S.BlacklistedPlayers or {}, targetName) ~= nil
        -- Feature 21: ESP Whitelist
        if isForESP and isPlayer and S.ESPWhitelistEnabled and not isBlacklisted then
            if not table.find(S.ESPWhitelist or {}, targetName) then return end
        end
        -- Blacklisted players remain visible in ESP unless explicitly hidden, but can never be aim targets.
        if isBlacklisted then
            if not isForESP or S.HideBlacklistedESP then return end
        end
        if not isForESP and S.PriorityBehavior == "Exclusive" and not isBlacklisted
            and not table.find(S.PriorityPlayers or {}, targetName) then return end
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
        if not root then return end
        local hum = model:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health <= 0 then
            if S.ThreatNeutralizationEnabled then
                local data = S.IntelPlayers and S.IntelPlayers[targetName]
                local isPrio = table.find(S.PriorityPlayers or {}, targetName)
                if (data and not data.nemesis) or isPrio then
                    if S.RemoveFromIntel then S.RemoveFromIntel(targetName, false) end
                    if S.Notify then S.Notify({Title="Intel",Content="Neutralized: "..targetName.." removed from Intel.",Duration=2,Image="check-circle"}) end
                end
            end
        end
        if not hum then return end
        if hum.Health <= 0 then
            if not S.DeadTargetsCache then S.DeadTargetsCache = {} end
            if not S.DeadTargetsCache[model] then S.DeadTargetsCache[model] = tick() end
            if (tick() - S.DeadTargetsCache[model]) > (S.KillFlashDuration or 0.8) then return end
        end
        local isTeammate = isPlayer and Player.Team and pObj.Team and pObj.Team == Player.Team
        if S.TeamCheck and isTeammate then return end
        -- v2.1.0 Render-thread wallcheck elimination:
        -- Read from S.VisibilityPrecomputed (set by background loop ③, one yield per entity).
        -- Falls back to live raycast ONLY on cold start (entry is nil before first sweep completes).
        if performWallCheck then
            local precomp = S.VisibilityPrecomputed[model]
            if precomp == nil then
                if S.TargetPart == "Visible On Screen" then
                    precomp = FindVisibleOnScreenPart(model, customIgnoreList) ~= nil
                else
                    precomp = IsVisibleCachedWrapper(model, S.ActivePartName, customIgnoreList)
                end
                S.VisibilityPrecomputed[model] = precomp
            end
            if not precomp then return end
        end

        local pos = root.Position
        local distFromCam = (pos - Camera.CFrame.Position).Magnitude
        if distFromCam > (maxDistance or S.AimbotRenderDistance) then return end
        local sPos, onScreen = Camera:WorldToViewportPoint(pos)
        local screenAnchor, screenPos, distFromCenter
        if ignoreFOV then
            screenPos = ApplyScreenCalibration(Vector2.new(sPos.X, sPos.Y))
            distFromCenter = (screenPos - screenCenter).Magnitude
        else
            screenAnchor, screenPos, distFromCenter = GetScreenAnchor(model, root, screenCenter)
            onScreen = screenAnchor ~= nil
        end
        
        -- Feature 6: Dynamic FOV
        local currentFov = GetEffectiveFOV(distFromCam)

        if ignoreFOV or (onScreen and (not S.ShowFOV or distFromCenter <= currentFov)) then
            table.insert(results, {
                Instance=model, Root=root, Name=targetName, IsPlayer=isPlayer,
                Player=pObj,
                IsTeammate=isTeammate, IsBlacklisted=isBlacklisted,
                ScreenAnchor=screenAnchor,
                DistFromCenter=distFromCenter, Distance=distFromCam,
                Position=pos, ScreenPos=screenPos,
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
    if not writefile then
        warn("[TASFF Core] Cannot save presets: writefile is unavailable.")
        return false
    end
    local env = GetTASFFEnv()
    if not (env and env.Capabilities and env.Capabilities.FileWrite) then
        warn("[TASFF Core] Cannot save presets: filesystem write API is unavailable.")
        return false
    end
    local ok, err = pcall(function()
        writefile(S.PresetFileName, HttpService:JSONEncode(S.SavedPresets))
    end)
    if not ok then
        warn("[TASFF Core] Failed to save presets: " .. tostring(err))
        return false
    end
    return true
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
                if S.IntelligentEquipFilter and S.ClassifyTool then
                    local class = S.ClassifyTool(child.Name)
                    if class == "NonWeapon" then return end
                end
                if S.MasterEnabled then S.AimbotActive = true end
            end
        end
    end)
    -- Bug Fix #1: do NOT call TrackConnection here — managed manually via S.ToolAddedConnection
    S.ToolRemovedConnection = char.ChildRemoved:Connect(function(child)
        if S.AutoEnableOnEquip and child:IsA("Tool") then
            S.AimbotActive = false; S.CurrentTarget = nil; SetADSState(false)
        end
    end)
    -- Bug Fix #1: do NOT call TrackConnection here — managed manually via S.ToolRemovedConnection
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
        TrackConnection(hum.Died:Connect(function()
            local killerName = "Unknown"
            local killerObj = nil
            
            -- Detect creator (covers ObjectValue and StringValue variants)
            local creator = hum:FindFirstChild("creator") or hum:FindFirstChild("Creator") or hum:FindFirstChild("KilledBy") or hum:FindFirstChild("creatorTag") or hum:FindFirstChild("Killer") or hum:FindFirstChild("killer")
            if creator then
                if creator:IsA("ObjectValue") and creator.Value and creator.Value:IsA("Player") then
                    killerObj = creator.Value
                    killerName = killerObj.Name
                elseif creator:IsA("StringValue") and creator.Value ~= "" then
                    local pObj = Players:FindFirstChild(creator.Value)
                    if pObj then
                        killerObj = pObj
                        killerName = pObj.Name
                    end
                end
            end

            if S.KillFeedEnabled and killerName ~= "Unknown" and killerName ~= p.Name then
                Notify({Title="TASFF Intel", Content=killerName.." killed "..p.Name, Duration=2, Image="crosshair"})
            end

            -- Session User Kill Count: track if WE killed this player
            local localPlayerKilled = (killerObj == Player)
            if localPlayerKilled then
                S.SessionUserKills = (S.SessionUserKills or 0) + 1
                if S.DebugMode then print("[TASFF Debug] Session kill #"..S.SessionUserKills.." on "..p.Name) end
            end

            if killerObj and killerObj ~= Player and killerObj ~= p then
                -- Add to global kill count for auto-flagging
                if S.KillCountThreatEnabled then
                    S.PlayerKillCounts[killerName] = (S.PlayerKillCounts[killerName] or 0) + 1
                    if S.PlayerKillCounts[killerName] >= (S.KillsBeforeThreat or 3) then
                        local kData = S.IntelPlayers and S.IntelPlayers[killerName]
                        local isTracked = kData and (kData.nemesis or kData.source == "Threat" or kData.source == "Registry")
                        if not isTracked then
                            if S.AddToIntel then S.AddToIntel(killerName, "Threat", 30) end
                            Notify({Title="TASFF Threat", Content=killerName.." flagged as Threat (Kill Streak).", Duration=2, Image="alert-circle"})
                        end
                    end
                end

                -- Track per-priority-player kill counts for Intel Monitor display
                local isPrio = table.find(S.PriorityPlayers or {}, killerName)
                local kData = S.IntelPlayers and S.IntelPlayers[killerName]
                if isPrio or kData then
                    if not S.PriorityPlayerKills then S.PriorityPlayerKills = {} end
                    S.PriorityPlayerKills[killerName] = (S.PriorityPlayerKills[killerName] or 0) + 1
                    if S.AddToIntel then S.AddToIntel(killerName, (kData and kData.source) or "Registry", 15) end
                end
            end

            if not S.ThreatNeutralizationEnabled then return end
            local data = S.IntelPlayers and S.IntelPlayers[p.Name]
            local isPrio = table.find(S.PriorityPlayers or {}, p.Name)
            if (data and not data.nemesis) or isPrio then
                if S.RemoveFromIntel then S.RemoveFromIntel(p.Name, false) end
                Notify({Title="Intel",Content="Neutralized: "..p.Name.." removed from Intel.",Duration=2,Image="check-circle"})
            end
        end))
    end
    -- Hook current character (if already spawned)
    if p.Character then task.spawn(hookHum, p.Character) end

    -- Hook all future respawns
    TrackConnection(p.CharacterAdded:Connect(hookHum))
end
table.insert(getgenv().TASFF.Connections, Players.PlayerAdded:Connect(HookNeutralization))
for _, ep in ipairs(Players:GetPlayers()) do pcall(HookNeutralization, ep) end

-- Auto-Expire on Disconnect
table.insert(getgenv().TASFF.Connections, Players.PlayerRemoving:Connect(function(p)
    local wasPrio = table.find(S.PriorityPlayers or {}, p.Name)
    local wasIntel = S.IntelPlayers and S.IntelPlayers[p.Name]
    if S.AutoExpireOnDisconnect and wasIntel and not wasIntel.nemesis then
        if S.RemoveFromIntel then S.RemoveFromIntel(p.Name, false) end
    end
    -- Notify regardless of auto-expire if the player was tracked
    if wasPrio or wasIntel then
        local label = wasIntel and (wasIntel.nemesis and "Nemesis" or wasIntel.source) or "Priority"
        Notify({Title="TASFF Intel", Content="["..label.."] "..p.Name.." left the game.", Duration=4, Image="user-minus"})
    end
end))

task.defer(function()
    task.wait(0.2)
    S.CurrentTarget = nil
    S.ScriptInitialized = true
    print("[TASFF v2.2.0] Core initialized.")
end)

-- // ══════════════════════════════════════════════════════════════ // --
-- //                      MAIN RENDER LOOP                        // --
-- // ══════════════════════════════════════════════════════════════ // --

local function UpdateSpectator()
    if S.SpectatePlayerEnabled and S.SpectateTarget and S.SpectateTarget ~= "" then
        local p = Players:FindFirstChild(S.SpectateTarget)
        if p and p.Character and p.Character:FindFirstChild("Humanoid") then
            workspace.CurrentCamera.CameraSubject = p.Character.Humanoid
            S.WasSpectating = true
            return
        else
            S.SpectatePlayerEnabled = false
            if S.SyncSpectatorUI then S.SyncSpectatorUI(false) end
        end
    end
    if S.WasSpectating then
        -- Bug Fix #12: guard against nil when player just died during spectate-end
        local selfChar = Player.Character
        local selfHum = selfChar and selfChar:FindFirstChild("Humanoid")
        if selfHum then
            workspace.CurrentCamera.CameraSubject = selfHum
        end
        -- leave camera subject unchanged if selfHum is nil — Roblox will recover on respawn
        S.WasSpectating = false
    end
end

local visualsWereEnabled = false
-- // ── Screen Recording Cloaking System helper ──────────────────── // --
-- Returns true if the named feature should be hidden from Roblox recording.
-- When hidden, that visual is suppressed entirely (the render loop skips it).
-- The BillboardGui/SurfaceGui "invisible-to-recording" redirect is handled by
-- making the feature simply not render on the Drawing/Highlight layer; the
-- blank BillboardGui that already exists on models (from GetVisualAssets) is
-- already invisible to recordings by nature.
local function IsHiddenFromRecording(featureName)
    if not S.RecordingCloakEnabled then return false end
    local hfr = S.HiddenFromRecording
    if not hfr then return false end
    return hfr[featureName] == true
end

local RenderConnection = RunService.RenderStepped:Connect(function(deltaTime)
    if not S.ScriptInitialized then return end
    S._lastDeltaTime = deltaTime   -- v2.1.0: FPS watcher reads this
    UpdateSpectator()
    EnsureDrawings()
    local cachedIgnoreList = GetIgnoreList()

    local MasterEnabled    = S.MasterEnabled and not S.PanicLocked
    local AimbotActive     = S.AimbotActive  and not S.PanicLocked
    local TargetingEnabled = S.TargetingEnabled
    local heldTool          = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
    local isToolBlacklisted = heldTool and table.find(S.ToolBlacklist, heldTool.Name)
    -- v2.1.0: Intelligent Equip Filter — classify held tool, block aimbot for non-weapons
    local heldToolClass = heldTool and S.ClassifyTool and S.ClassifyTool(heldTool.Name) or "Unknown"
    local isNonWeaponEquipped = S.IntelligentEquipFilter and heldTool and heldToolClass == "NonWeapon"
    local canAimWithTool    = not S.AutoEnableOnEquip or (heldTool and not isToolBlacklisted and not isNonWeaponEquipped)
    -- v2.1.0 Feature 5: Health Threshold Gate
    local healthThreshold   = S.HealthThresholdEnabled and (S.HealthThreshold or 0) or 0


    local screenCenter  = GetAimPosition()
    local shouldShowFOV = S.ShowFOV and not S.InvisibleFOV
        and MasterEnabled and AimbotActive and TargetingEnabled
    if S.FOVCircle then
        SetDrawingCloaked(S.FOVCircle, IsHiddenFromRecording("FOV Circle"))
        if shouldShowFOV then
            PrepareDrawing(S.FOVCircle)
            S.FOVCircle.Position = screenCenter
            pcall(function() S.FOVCircle.Point = screenCenter end)
            local targetRoot = S.CurrentTarget and S.CurrentTarget.Root
            local drawDistance = targetRoot and targetRoot.Parent
                and (targetRoot.Position - Camera.CFrame.Position).Magnitude
                or nil
            local drawFov = GetEffectiveFOV(drawDistance)
            S.FOVCircle.Radius  = drawFov
            S.FOVCircle.Color   = S.FOVColor or S.FOVCircle.Color
            S.FOVCircle.Visible = true
        else
            S.FOVCircle.Visible = false
        end
    end
    ClearCrosshair()
    if S.EnableCrosshair then
        local crosshairCloaked = IsHiddenFromRecording("Crosshair")
        local color = S.CrosshairColor or Color3.fromRGB(0, 255, 255)
        for _, el in pairs(CrosshairElements) do
            SetDrawingCloaked(el, crosshairCloaked)
            PrepareDrawing(el)
        end
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
    -- // ── v2.1.0 Pipeline: Scanning Slots (one per frame) ─────── // --
    -- Slot 1 (aimbot candidate scan) moved OUTSIDE the pipeline — runs every frame.
    -- Since visibility is now precomputed (background loop ③), GetPotentialTargets
    -- has ZERO raycasts and costs only table lookups + WorldToViewportPoint — negligible.
    -- Pipeline now handles: Slot 0 = ESP list, Slot 1 = VoS, Slot 2 = Maintenance.
    do
        local pm = S.PerformanceMode or "Medium"
        local prf = S.PipelineRestFrames
        local restTarget = (prf and prf[pm]) or 2

        if (S.PipelineRestCount or 0) > 0 then
            S.PipelineRestCount = S.PipelineRestCount - 1
        else
            local slot = S.PipelineSlot or 0

            if slot == 0 then
                -- Slot 0: Build visual list for ESP rendering
                if MasterEnabled then
                    S.LastVisualList = GetPotentialTargets(
                        S.VisualMode == "All",
                        false,
                        cachedIgnoreList,
                        S.ESPRenderDistance,
                        true
                    )
                else
                    S.LastVisualList = {}
                end

            elseif slot == 1 then
                -- Slot 1: VoS scan — raycasts on current target limbs (still expensive enough to gate)
                if S.TargetPart == "Visible On Screen" and S.CurrentTarget and S.CurrentTarget.Instance and S.CurrentTarget.Instance.Parent then
                    local bPart = FindVisibleOnScreenPart(S.CurrentTarget.Instance, cachedIgnoreList)
                    if bPart then
                        S.LastCustomTargetData = {Part = bPart, Position = bPart.Position}
                    else
                        S.LastCustomTargetData = nil; S.CurrentTarget = nil
                    end
                elseif S.TargetPart ~= "Visible On Screen" then
                    S.LastCustomTargetData = nil
                end

            elseif slot == 2 then
                -- Slot 2: Timestamp pruning + AutoADS + Silent Aim cache expiry
                for model, _ in pairs(TargetFirstSeenTimestamps) do
                    if not model or not model.Parent or not model:FindFirstChildOfClass("Humanoid") then
                        TargetFirstSeenTimestamps[model] = nil
                    end
                end
                if S.AutoADSEnabled then SetADSState(S.CurrentTarget ~= nil and AimbotActive and canAimWithTool) end
                if (not S.SilentAimEnabled or not S.CurrentTarget) and (tick() - (S.SilentAimTargetCacheTime or 0) > 0.1) then
                    S.SilentAimTargetCache = nil
                end
            end

            S.PipelineSlot = (slot + 1) % 3
            S.PipelineRestCount = restTarget
        end
    end

    -- // ── Aimbot Candidate Scan (every frame — zero raycasts) ─── // --
    -- Now that visibility is precomputed in background loop ③, this is pure
    -- table lookups. Running every frame eliminates the FOV-entry lock delay.
    if MasterEnabled and AimbotActive and TargetingEnabled then
        local bypassWC = S.WallCheck or false
        S.AimbotCandidates = GetPotentialTargets(false, bypassWC, cachedIgnoreList, S.AimbotRenderDistance)
    else
        S.AimbotCandidates = {}
    end



    -- // ── v2.1.0 Every-Frame: Target Selection (full FPS, no gating) // --
    -- Reads S.AimbotCandidates (written by Slot 1), sorts and picks target
    -- every frame so aimbot responsiveness is independent of performance mode.
    if MasterEnabled and AimbotActive and TargetingEnabled then
        local TargetPart = S.TargetPart; local WallCheck = S.WallCheck
        local previousTarget = S.CurrentTarget
        if previousTarget then
            local targetModel = previousTarget.Instance
            local targetHumanoid = targetModel and targetModel:FindFirstChildOfClass("Humanoid")
            local targetDisappeared = not targetModel or not targetModel.Parent
                or not targetHumanoid or targetHumanoid.Health <= 0
                or (previousTarget.IsPlayer and previousTarget.Player
                    and (previousTarget.Player.Parent ~= Players or previousTarget.Player.Character ~= targetModel))
            if targetDisappeared then
                S.LastTargetLostTime = tick()
                S.CurrentTarget = nil
                S.LastCustomTargetData = nil
            end
        end

        -- Range cull on current target
        if S.CurrentTarget and S.CurrentTarget.Root then
            if (S.CurrentTarget.Root.Position - Camera.CFrame.Position).Magnitude > S.AimbotRenderDistance then
                S.CurrentTarget = nil
            end
        end

        -- Sticky aim validation
        local StickyLockActive = false
        if S.StickyAimEnabled and S.CurrentTarget and S.CurrentTarget.Instance and S.CurrentTarget.Instance.Parent then
            local hum = S.CurrentTarget.Instance:FindFirstChildOfClass("Humanoid")
            local typeMismatch = (S.CurrentTarget.IsPlayer and not S.TargetPlayers) or (not S.CurrentTarget.IsPlayer and not S.TargetNPCs)
            local wallCheckFailed = false
            if TargetPart ~= "Visible On Screen" and WallCheck then
                -- Use precomputed table — avoids any raycast on the render thread
                local precomp = S.VisibilityPrecomputed[S.CurrentTarget.Instance]
                if precomp == nil then
                    -- Cold start only: compute once, background takes over after
                    precomp = IsVisibleCachedWrapper(S.CurrentTarget.Instance, S.ActivePartName, cachedIgnoreList)
                    S.VisibilityPrecomputed[S.CurrentTarget.Instance] = precomp
                end
                if not precomp then wallCheckFailed = true end
            end

            local outOfBounds = false
            if S.CurrentTarget.Root then
                local d = (S.CurrentTarget.Root.Position - Camera.CFrame.Position).Magnitude
                if d > S.AimbotRenderDistance then outOfBounds = true end
                local anchor, _, anchorDistance = GetScreenAnchor(
                    S.CurrentTarget.Instance,
                    S.CurrentTarget.Root,
                    screenCenter
                )
                local currentFov = GetEffectiveFOV(d)
                if not anchor or (S.ShowFOV and anchorDistance > currentFov) then
                    outOfBounds = true
                end
            end
            if hum and hum.Health > 0 and not typeMismatch and not wallCheckFailed and not outOfBounds then
                StickyLockActive = true
            else
                S.CurrentTarget = nil
            end
        end

        -- Select new target from candidates (every frame — sort is cheap, no raycasts)
        if not StickyLockActive then
            local candidates = S.AimbotCandidates or {}
            local filtered = {}
            local now = tick()
            local graceCondition = WallCheck or (TargetPart == "Visible On Screen")
            for _, c in ipairs(candidates) do
                if not c.Instance or not c.Instance.Parent then continue end
                local hum = c.Instance:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health <= 0 then continue end
                -- Feature 5: Health Threshold Gate
                if healthThreshold > 0 and hum.MaxHealth > 0 and ((hum.Health / hum.MaxHealth) * 100 < healthThreshold) then continue end
                if S.GracePeriodEnabled and graceCondition then
                    if not TargetFirstSeenTimestamps[c.Instance] then TargetFirstSeenTimestamps[c.Instance] = now end
                    if (now - TargetFirstSeenTimestamps[c.Instance]) * 1000 < S.GracePeriodMs then continue end
                end
                -- Refresh live screen-distance + health for accurate sorting each frame
                if c.Root and c.Root.Parent then
                    local anchor, screenPosition, screenDistance = GetScreenAnchor(c.Instance, c.Root, screenCenter)
                    c.ScreenAnchor = anchor
                    c.DistFromCenter = screenDistance
                    c.Distance = (c.Root.Position - Camera.CFrame.Position).Magnitude
                    c.Health = hum.Health
                    c.ScreenPos = screenPosition
                    if not anchor then continue end
                end
                table.insert(filtered, c)
            end
            local lastTargetLostTime = S.LastTargetLostTime or 0
            local delayActive = S.TargetSwitchDelayEnabled and lastTargetLostTime > 0
                and (now - lastTargetLostTime) < ((S.SwitchDelayMs or 0) / 1000)
            if not delayActive then
                local PP = S.PriorityPlayers or {}; local VM = S.VitalityMode; local PM = S.PriorityMode; local TNC = S.TargetNearCenter
                table.sort(filtered, function(a, b)
                    local aPrio = table.find(PP, a.Name); local bPrio = table.find(PP, b.Name)
                    if aPrio and not bPrio then return true end
                    if bPrio and not aPrio then return false end
                    if VM == "Weakest (HP)"  then return a.Health < b.Health end
                    if VM == "Strongest (HP)" then return a.Health > b.Health end
                    local aDC = a.DistFromCenter or 999999; local bDC = b.DistFromCenter or 999999
                    if TNC then return aDC < bDC end
                    if PM == "Closest"  then return (a.Distance or 999999) < (b.Distance or 999999) end
                    if PM == "Farthest" then return (a.Distance or 999999) > (b.Distance or 999999) end
                    return aDC < bDC
                end)
                -- v2.1.0: track new target lock for session stats
                local prev = S.CurrentTarget
                S.CurrentTarget = filtered[1]
                if S.CurrentTarget and (not prev or prev.Instance ~= S.CurrentTarget.Instance) then
                    if TargetPart == "Visible On Screen" then
                        local part = FindVisibleOnScreenPart(S.CurrentTarget.Instance, cachedIgnoreList)
                        S.LastCustomTargetData = part and {Part = part, Position = part.Position} or nil
                        if not part then S.CurrentTarget = nil end
                    end
                end
                if S.CurrentTarget and (not prev or prev.Instance ~= S.CurrentTarget.Instance) then
                    S.SessionTargetLocks = (S.SessionTargetLocks or 0) + 1
                    -- Feature 19: Lock History
                    if not S.LockHistory then S.LockHistory = {} end
                    table.insert(S.LockHistory, 1, {name=S.CurrentTarget.Name, time=tick()})
                    if #S.LockHistory > 5 then table.remove(S.LockHistory) end
                end
            end
        end


        -- Silent aim target cache update (every frame)
        if S.SilentAimEnabled and S.CurrentTarget then
            S.SilentAimTargetCache = S.CurrentTarget; S.SilentAimTargetCacheTime = tick()
        end
    else
        if not MasterEnabled then S.LastVisualList = {}; S.LastCustomTargetData = nil end
        if tick() - (S.SilentAimTargetCacheTime or 0) > 0.1 then S.SilentAimTargetCache = nil end
    end

    if MasterEnabled then
        visualsWereEnabled = true
    elseif visualsWereEnabled then
        ClearVisuals()
        visualsWereEnabled = false
    end

    local skeletonsRenderedThisFrame = {}
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
            local isBlacklisted=t.IsBlacklisted==true
            local inFocus=not FM or isPriority
            local isPrimary=S.CurrentTarget and t.Instance==S.CurrentTarget.Instance
            if isPrimary and S.TargetPart == "Visible On Screen" then
                local part = S.LastCustomTargetData and S.LastCustomTargetData.Part
                isPrimary = part ~= nil and part.Parent ~= nil and part:IsDescendantOf(t.Instance)
                    and IsVisibleCachedWrapper(t.Instance, part.Name, cachedIgnoreList)
            end
            local show=inFocus and (VM=="All" or VM=="Multiple" or (VM=="Single" and isPrimary)) or isBlacklisted

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
            -- Cloak: Tags / Nametags — compute BEFORE GetVisualAssets so forcebillboard redirects
            -- the tag type. BillboardGui is player-visible but invisible to Roblox recording.
            local cloakTags = IsHiddenFromRecording("Tags / Nametags")
            local h,tag=GetVisualAssets(t.Instance, cloakTags)
            if not (h and tag) then continue end
            local isVisNow=true
            if VCE then isVisNow=IsVisibleCachedWrapper(t.Instance,"HumanoidRootPart",cachedIgnoreList) end
            
            -- Feature 15: Kill Confirm Flash
            local isRecentlyDead = false
            local fadeFactor = 0
            if S.KillConfirmFlashEnabled then
                local hum = t.Instance:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health <= 0 then
                    if not S.DeadTargetsCache then S.DeadTargetsCache = {} end
                    if not S.DeadTargetsCache[t.Instance] then S.DeadTargetsCache[t.Instance] = tick() end
                    local deadTime = tick() - S.DeadTargetsCache[t.Instance]
                    local flashDur = S.KillFlashDuration or 0.8
                    if deadTime < flashDur then 
                        isRecentlyDead = true 
                        fadeFactor = 1 - (deadTime / flashDur)
                    end
                end
            end

            local bc=HLC or t.TeamColor
            if isBlacklisted then bc = S.BlacklistedTagColor or Color3.fromRGB(255, 140, 0)
            elseif isNemesis then bc = S.NemesisHighlightColor or Color3.fromRGB(150, 0, 255)
            elseif isPriority then bc = S.PriorityHighlightColor or Color3.fromRGB(255, 50, 50)
            elseif VCE then
                local isThreat = S.IntelPlayers and S.IntelPlayers[t.Name] and (S.IntelPlayers[t.Name].source == "Threat")
                if isThreat then bc = S.ThreatHighlightColor or Color3.fromRGB(255, 60, 0)
                else bc = isVisNow and VC or HC end
            end

            if isRecentlyDead then 
                local kfc = S.KillFlashColor or Color3.fromRGB(255, 255, 255)
                bc = bc:Lerp(kfc, fadeFactor)
            end
            local statusESPColor = (isBlacklisted or isNemesis or isPriority or VCE) and bc or nil

            -- ESP Highlights / Chams always render — cloaking does not suppress Highlight
            -- instances since user wants chams visible even when other ESP is cloaked.
            h.Adornee=t.Instance
            if t.IsPlayer then h.Enabled=UH else h.Enabled=UNH end
            h.OutlineColor=bc
            local rootPart=t.Instance:FindFirstChild("HumanoidRootPart")
            local headPart=t.Instance:FindFirstChild("Head")
            if not rootPart then continue end
            local pos,onScreen=Camera:WorldToViewportPoint(rootPart.Position)
            local headPos=headPart and Camera:WorldToViewportPoint(headPart.Position+Vector3.new(0,0.5,0)) or pos
            -- Cloak: OOF Arrows — reparent to CoreOverlayGui when cloaked (recording-invisible)
            local cloakOOF = IsHiddenFromRecording("OOF Arrows")
                or IsHiddenFromRecording("Drawing-Based ESP (Box, Skeleton, Snaplines, OOF Arrows)")
            if OOFE and not onScreen then
                if not OOFArrowCache[t.Instance] then
                    local arrow=NewDrawing("Triangle")
                    if arrow then arrow.Thickness=2;arrow.Filled=true;OOFArrowCache[t.Instance]=arrow end
                end
                local arrow=OOFArrowCache[t.Instance]
                if arrow then
                    SetDrawingCloaked(arrow, cloakOOF)
                    local center=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
                    local relX,relY=pos.X-center.X,pos.Y-center.Y
                    if pos.Z<0 then relX=-relX;relY=-relY end
                    local angle=math.atan2(relY,relX); local r=OOFR
                    arrow.PointA=center+Vector2.new(math.cos(angle),math.sin(angle))*r
                    arrow.PointB=center+Vector2.new(math.cos(angle-0.2),math.sin(angle-0.2))*(r-20)
                    arrow.PointC=center+Vector2.new(math.cos(angle+0.2),math.sin(angle+0.2))*(r-20)
                    arrow.Color=statusESPColor or S.OOFArrowColor or SLC or bc; arrow.Visible=true
                end
            else if OOFArrowCache[t.Instance] then OOFArrowCache[t.Instance].Visible=false end end
            if onScreen then
                local hs=ApplyScreenCalibration(Vector2.new(headPos.X,headPos.Y))
                -- Tags: BillboardGui when cloaked (in hidden container; 3D floating appearance like Image 2)
                -- or Drawing text when not cloaked. Both remain visible to local player.
                if (t.IsPlayer and UIT) or (not t.IsPlayer and UNIT) then
                    local hdr=""
                    local at=t.Instance:FindFirstChildOfClass("Tool")
                    if STC and at then hdr="["..at.Name:upper().."] " end
                    if isBlacklisted then hdr=hdr.."[BLACKLISTED] "
                    elseif isNemesis then hdr=hdr.."[NEMESIS] " elseif isPriority then hdr=hdr.."[PRIORITY] " end
                    if t.IsTeammate then hdr=hdr.."[TEAM] " end
                    if S.ShowLockIndicators and isPrimary then
                        if S.SilentAimEnabled then hdr=hdr.."[SILENT] " else hdr=hdr.."[LOCKED] " end
                    end
                    local ns=""
                    if t.IsPlayer and SDisp then local po=Players:FindFirstChild(t.Name); if po then ns="("..po.DisplayName..") " end end
                    local fs=string.format("%s%s%s\nHP: %d | Dist: %d",hdr,ns,t.Name,math.floor(t.Health),dist)
                    if typeof(tag)=="Instance" and tag:IsA("BillboardGui") then
                        local lbl=tag:FindFirstChildOfClass("TextLabel")
                        if lbl then lbl.Text=fs;lbl.TextColor3=bc end
                        tag.Adornee=t.Instance:FindFirstChild("Head") or rootPart; tag.Enabled=true
                    else
                        tag.Text=fs;tag.Position=Vector2.new(hs.X,hs.Y-35);tag.Color=bc;tag.Visible=true
                        SetDrawingCloaked(tag, cloakTags)
                    end
                else if typeof(tag)=="Instance" then tag.Enabled=false else pcall(function() tag.Visible=false end) end end
                -- Cloak: Snaplines — reparent to CoreOverlayGui when cloaked (recording-invisible)
                local cloakSnap = IsHiddenFromRecording("Snaplines")
                    or IsHiddenFromRecording("Drawing-Based ESP (Box, Skeleton, Snaplines, OOF Arrows)")
                if SE then
                    if not SnaplineCache[t.Instance] then local line=NewDrawing("Line"); if line then line.Thickness=1.5;SnaplineCache[t.Instance]=line end end
                    local sl=SnaplineCache[t.Instance]
                    if sl then
                        SetDrawingCloaked(sl, cloakSnap)
                        PrepareDrawing(sl)
                        local o2=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y)
                        if SO=="Center" then o2=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2) end
                        sl.From=o2;sl.To=Vector2.new(pos.X,pos.Y);sl.Color=statusESPColor or SLC or bc;sl.Visible=true
                    end
                else if SnaplineCache[t.Instance] then SnaplineCache[t.Instance].Visible=false end end
                -- Cloak: Box ESP — reparent to CoreOverlayGui when cloaked
                local cloakBox = IsHiddenFromRecording("Box ESP")
                    or IsHiddenFromRecording("Drawing-Based ESP (Box, Skeleton, Snaplines, OOF Arrows)")
                if BME then
                    local lp=Camera:WorldToViewportPoint(rootPart.Position-Vector3.new(0,3,0))
                    local bH=math.abs(headPos.Y-lp.Y); local bW=bH*0.65
                    if not BoxCache[t.Instance] then local box=NewDrawing("Square"); if box then box.Thickness=1.5;box.Filled=false;BoxCache[t.Instance]=box end end
                    if BoxCache[t.Instance] then
                        SetDrawingCloaked(BoxCache[t.Instance], cloakBox)
                        PrepareDrawing(BoxCache[t.Instance])
                        BoxCache[t.Instance].Size=Vector2.new(bW,bH)
                        BoxCache[t.Instance].Position=Vector2.new(hs.X-(bW/2),hs.Y)
                        BoxCache[t.Instance].Color=statusESPColor or S.BoxColor or bc; BoxCache[t.Instance].Visible=true
                    end
                else if BoxCache[t.Instance] then BoxCache[t.Instance].Visible=false end end
                -- Cloak: Skeleton ESP — reparent to CoreOverlayGui when cloaked
                local cloakSkel = IsHiddenFromRecording("Skeleton ESP")
                    or IsHiddenFromRecording("Drawing-Based ESP (Box, Skeleton, Snaplines, OOF Arrows)")
                if SkME then
                    local isR15=t.Instance:FindFirstChild("UpperTorso")~=nil
                    if SkeletonCache[t.Instance] then
                        for _,l in ipairs(SkeletonCache[t.Instance]) do
                            if l and l.Line then SetDrawingCloaked(l.Line, cloakSkel) end
                        end
                    end
                    DrawSkeleton(t.Instance, isR15 and R15Joints or R6Joints, statusESPColor or S.SkeletonColor or bc)
                    skeletonsRenderedThisFrame[t.Instance] = true
                else if SkeletonCache[t.Instance] then for _,l in ipairs(SkeletonCache[t.Instance]) do if l and l.Line then l.Line.Visible=false end end end end
            else
                if typeof(tag)=="Instance" then tag.Enabled=false else pcall(function() tag.Visible=false end) end
                if BoxCache[t.Instance] then BoxCache[t.Instance].Visible=false end
                if SnaplineCache[t.Instance] then SnaplineCache[t.Instance].Visible=false end
                if SkeletonCache[t.Instance] then for _,l in ipairs(SkeletonCache[t.Instance]) do if l and l.Line then l.Line.Visible=false end end end
            end
            if ChE then
                h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
                h.FillColor=statusESPColor or S.ChamsColor or bc
                h.FillTransparency=1-(math.clamp(ChO,0,100)/100)
                h.OutlineTransparency = 0
            else
                h.DepthMode=Enum.HighlightDepthMode.Occluded
                h.FillTransparency=1
            end
        end
    end
    for model, limbs in pairs(SkeletonCache) do
        if not skeletonsRenderedThisFrame[model] then
            for _, limb in ipairs(limbs) do
                if limb.Line then limb.Line.Visible = false end
            end
        end
    end
    if MasterEnabled then
        local CT=S.CurrentTarget; local TP=S.TargetPart
        if CT and TargetingEnabled and AimbotActive and canAimWithTool then
            local TWP=nil
            local tv=CT.Root and CT.Root.AssemblyLinearVelocity or Vector3.new(0,0,0)
            local isM=tv.Magnitude>1.5; local Mode=S.Mode; local PA=S.PredictionAmount
            if TP=="Visible On Screen" then
                if S.LastCustomTargetData and S.LastCustomTargetData.Part and S.LastCustomTargetData.Part.Parent and S.LastCustomTargetData.Part:IsDescendantOf(CT.Instance) then
                    local lvPart = S.LastCustomTargetData.Part
                    local screenPoint, onScreen = Camera:WorldToViewportPoint(lvPart.Position)
                    if onScreen and IsVisibleCachedWrapper(CT.Instance, lvPart.Name, cachedIgnoreList) then
                        TWP = lvPart.Position + (lvPart.AssemblyLinearVelocity * PA)
                    end
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
            -- v2.1.0: Silent Aim — only block MOUSE movement (mousemoverel/abs).
            -- Camera CFrame writes still happen so the engine doesn't freeze the camera.
            -- The __index/__namecall hooks handle actual bullet/raycast redirection.
            if TWP then
                local tcf=CFrame.new(Camera.CFrame.Position,TWP)
                local sp,os=Camera:WorldToViewportPoint(TWP)
                local tsp=os and ApplyScreenCalibration(Vector2.new(sp.X,sp.Y)) or nil
                local Sm=S.Smoothness
                if Mode=="Legit (Camera)" then
                    Camera.CFrame=Camera.CFrame:Lerp(tcf,math.clamp(deltaTime*(6/math.max(0.1,Sm)),0.01,1))
                elseif Mode=="Advanced Legit (Mouse)" then
                    -- v2.1.0 fix: smoothstep approach + split X/Y smoothness + micro-offset humanization
                    -- SA on: skip mouse movement entirely — hook handles bullet redirect
                    if not S.SilentAimEnabled and tsp then
                        local mp=UserInputService:GetMouseLocation()
                        local diff=tsp-mp; local d2=diff.Magnitude
                        if d2 > 0.5 then
                            local Sx=math.max(0.1, S.SmoothnessX or Sm)
                            local Sy=math.max(0.1, S.SmoothnessY or Sm)
                            -- Ease: approaches fast when far, decelerates near target
                            local ease=math.clamp(d2/150, 0.05, 1.0)
                            local stepX=math.clamp(deltaTime*(20/Sx)*ease, 0.005, 0.7)
                            local stepY=math.clamp(deltaTime*(20/Sy)*ease, 0.005, 0.7)
                            -- Subtle random micro-offset for human feel (only when not locked in)
                            local microX=d2>10 and (math.random()-0.5)*2.0 or 0
                            local microY=d2>10 and (math.random()-0.5)*2.0 or 0
                            local mvX=(diff.X+microX)*stepX
                            local mvY=(diff.Y+microY)*stepY
                            if UserInputService.MouseBehavior==Enum.MouseBehavior.LockCenter then
                                mousemoverel(mvX, mvY)
                            else
                                mousemoveabs(mp.X+mvX, mp.Y+mvY)
                            end
                        end
                    end
                elseif Mode=="Blatant" then
                    -- v2.1.0: Blatant snap speed — 100=instant, <100=lerp
                    local snap=S.BlatantSnapSpeed or 100
                    if snap < 100 then
                        Camera.CFrame=Camera.CFrame:Lerp(tcf, math.clamp(snap/100, 0.01, 1))
                    else
                        Camera.CFrame=tcf
                    end
                end
            end


        end
        local MME=S.MeleeModeEnabled; local eMR=false
        if MME and Player.Character then
            local mr2=Player.Character:FindFirstChild("HumanoidRootPart")
            if mr2 then local mr=S.MeleeDetectionRange; for _,t in ipairs(S.LastVisualList) do if t.Instance and t.Root and (mr2.Position-t.Root.Position).Magnitude<=mr then eMR=true;break end end end
        end
        local CT2=S.CurrentTarget; local CM=S.ClickMethod; local TCM=S.TriggerbotClickMode
        local CI=S.ClickInterval; local MCI=S.MeleeClickInterval
        -- v2.1.0 Weapon-Type Gating: triggerbot blocked for melee tools; melee blocked for ranged
        local wgEnabled = S.WeaponTypeGating and heldToolClass ~= "Unknown"
        local triggerAllowed = not wgEnabled or (heldToolClass ~= "Melee")
        local meleeAllowed   = not wgEnabled or (heldToolClass ~= "Weapon")
        local tbA=S.AutoClickEnabled and CT2~=nil and TargetingEnabled and AimbotActive and canAimWithTool and triggerAllowed
        local mA=MME and eMR and meleeAllowed

        if tbA or mA then
            local coord; if S.ThirdPersonTriggerbot and CT2 and CT2.ScreenPos then coord=CT2.ScreenPos else coord=UserInputService:GetMouseLocation() end
            local aI=mA and MCI or CI
            if CM=="Hold" then
                if not S.IsHoldingClick then
                    S.IsHoldingClick=true
                    S.SessionTriggerFires = (S.SessionTriggerFires or 0) + 1
                    if TCM=="Physical" and mouse1press then mouse1press() else VirtualInputManager:SendMouseButtonEvent(coord.X,coord.Y,0,true,game,0) end
                end
            elseif CM=="Mash" then
                if (tick()-S.LastClickTime)>=(aI/1000) then
                    S.LastClickTime=tick()
                    S.SessionTriggerFires = (S.SessionTriggerFires or 0) + 1
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

local function GetSilentAimPart(target)
    if S.TargetPart == "Visible On Screen" then
        local customTarget = S.LastCustomTargetData
        if customTarget and customTarget.Part and customTarget.Part.Parent
            and customTarget.Part:IsDescendantOf(target) then
            return customTarget.Part
        end
    end
    return target:FindFirstChild(S.TargetPart) or target:FindFirstChild("HumanoidRootPart")
end

local oldIndex
oldIndex = hookmetamethod(game, "__index", function(t, k)
    if k~="Hit" and k~="Target" and k~="UnitRay" then return oldIndex(t,k) end
    if checkcaller() then return oldIndex(t,k) end
    if S.SilentAimEnabled and S.MasterEnabled and S.SilentAimTargetCache and S.SilentAimTargetCache.Instance then
        if t and (t:IsA("Mouse") or t:IsA("PlayerMouse") or t:IsA("PluginMouse")) then
            local bone=GetSilentAimPart(S.SilentAimTargetCache.Instance)
            if bone then
                if k=="Hit" then return bone.CFrame end
                if k=="Target" then return bone end
                if k=="UnitRay" then local o=workspace.CurrentCamera.CFrame.Position; return Ray.new(o,(bone.Position-o).Unit) end
            end
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
        local bone=GetSilentAimPart(S.SilentAimTargetCache.Instance)
        if bone and typeof(self)=="Instance" and (self==workspace or self:IsA("Workspace")) then
            local origin, ov
            if method=="Raycast" then
                origin, ov = args[1], args[2]
            elseif method=="Spherecast" then
                origin, ov = args[1], args[3]
            elseif method=="Blockcast" then
                origin = typeof(args[1]) == "CFrame" and args[1].Position or nil
                ov = args[3]
            elseif method=="Shapecast" then
                local shape = args[1]
                origin = typeof(shape) == "Instance" and shape:IsA("BasePart") and shape.Position or nil
                ov = args[2]
            elseif typeof(args[1]) == "Ray" then
                origin, ov = args[1].Origin, args[1].Direction
            end
            if typeof(origin) ~= "Vector3" or typeof(ov) ~= "Vector3" then
                return oldNamecall(self,...)
            end
            
            -- Camera freeze prevention (PopperCam raycast bypass)
            local camPos = workspace.CurrentCamera.CFrame.Position
            local toCam = camPos - origin
            local dirVec = typeof(ov)=="Vector3" and ov or (ov and ov.Unit)
            if toCam.Magnitude > 0.5 and dirVec and dirVec.Magnitude > 0.1 then
                if dirVec.Unit:Dot(toCam.Unit) > 0.99 then
                    return oldNamecall(self,...) -- Ignore camera script raycasts
                end
            end
            
            -- Also ignore if calling script is clearly the camera
            if getcallingscript then
                local cs = getcallingscript()
                if cs and (cs.Name == "CameraModule" or cs.Name == "ZoomController" or cs.Name == "Popper") then
                    return oldNamecall(self,...)
                end
            end

            local cL=ov.Magnitude
            local dir=(bone.Position-origin).Unit*cL
            if method=="Raycast" then args[2]=dir
            elseif method=="Spherecast" or method=="Blockcast" then args[3]=dir
            elseif method=="Shapecast" then args[2]=dir
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
    if OverlayGui then OverlayGui:Destroy(); OverlayGui = nil end
    for _,child in ipairs(CoreGui:GetChildren()) do if child.Name=="TASFF_UI" or child.Name=="Rayfield" then child:Destroy() end end
end

print("[TASFF Core] All function slots registered. Render loop active.")
