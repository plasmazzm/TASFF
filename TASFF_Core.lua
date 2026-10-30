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
    for i = #env.Connections, 1, -1 do
        local existing = env.Connections[i]
        if existing == conn then return end
    end
    table.insert(env.Connections, conn)
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

local digitMap = {
    ["0"] = "Zero", ["1"] = "One", ["2"] = "Two", ["3"] = "Three", ["4"] = "Four",
    ["5"] = "Five", ["6"] = "Six", ["7"] = "Seven", ["8"] = "Eight", ["9"] = "Nine"
}

local function GetKeyCode(name)
    if type(name) ~= "string" or name == "" then return nil end
    if name:match("^MouseButton") then return nil end
    if digitMap[name] then name = digitMap[name] end
    local ok, result = pcall(function()
        return Enum.KeyCode[name] or Enum.KeyCode[name:upper()]
    end)
    return (ok and result) or nil
end
S.GetKeyCode = GetKeyCode

local _notifyCount = 0
local _notifyWindowStart = tick()
local function Notify(options)
    options = options or {}
    local isBypass = (options.BypassThrottle == true) or (options.Important == true)
    if S.DisableNotifications and not options.BypassSilence and not isBypass then return end

    -- Feature 23: Notification Throttle (bypassed for critical/profile notifications)
    local now = tick()
    if now - _notifyWindowStart >= 3 then
        _notifyWindowStart = now; _notifyCount = 0
    end
    local limit = S.NotifyMaxPer3s or 5
    if not isBypass then
        if _notifyCount >= limit then return end  -- drop excess non-critical notifications
        _notifyCount = _notifyCount + 1
    end

    -- Build a clean, fully materialized options table so Rayfield's internal
    -- builder (which may use pairs/ipairs or table.clone) receives all keys directly
    -- instead of resolving through a __index metatable chain.
    local mat = {
        Title          = options.Title          or "",
        Content        = options.Content        or "",
        Duration       = options.Duration,
        Image          = options.Image,
        BypassThrottle = options.BypassThrottle,
        Important      = options.Important,
        BypassSilence  = options.BypassSilence,
    }
    -- Apply global notification duration override
    if S.NotificationDuration and S.NotificationDuration > 0 and not mat.Duration then
        mat.Duration = S.NotificationDuration
    end

    -- Primary: Rayfield notification
    local rayfieldOk = false
    if Rayfield and Rayfield.Notify then
        local ok = pcall(function() Rayfield:Notify(mat) end)
        rayfieldOk = ok
    end

    -- Secondary fallback: when Rayfield notification fails or is unavailable,
    -- surface through the native Roblox HUD notification as a fail-safe.
    if not rayfieldOk then
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title    = mat.Title,
                Text     = mat.Content,
                Duration = mat.Duration or 3,
            })
        end)
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
        -- Support both Rayfield:Notify(opts) and Rayfield.Notify(opts)
        local options = opts
        local target = self
        if opts == nil and type(self) == "table" and (self.Title or self.Content) then
            options = self
            target = Rayfield
        end

        -- Block notifications that originate from Rayfield's own advertising
        if S.SuppressRayfieldAds and options then
            local t = tostring(options.Title or "")
            local c = tostring(options.Content or "")
            if t:find("Rayfield") or t:find("sirius") or t:find("advertisement") or
               c:find("sirius.menu") or c:find("Loving this") or c:find("ui library") then
                return
            end
        end
        return origNotify(target, options)
    end
end)



-- TASFF_Overlay lives in CoreGui so all drawing-based ESP is permanently recording-invisible.
-- Roblox's screen recording does not capture CoreGui ScreenGui content.
-- Falls back to PlayerGui only when the executor blocks CoreGui access.
local function EnsureOverlayGui()
    if OverlayGui and OverlayGui.Parent then return OverlayGui end
    -- Try CoreGui first (recording-invisible)
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    local parent = (ok and cg) or (Player and Player:FindFirstChildOfClass("PlayerGui"))
    if not parent then return nil end
    local existing = parent:FindFirstChild("TASFF_Overlay")
    if existing then existing:Destroy() end
    OverlayGui = Instance.new("ScreenGui")
    OverlayGui.Name = "TASFF_Overlay"
    OverlayGui.IgnoreGuiInset = true
    OverlayGui.ResetOnSpawn = false
    OverlayGui.DisplayOrder = 10000
    OverlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    OverlayGui.Parent = parent
    return OverlayGui
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
                    if instance.Frame then pcall(function() instance.Frame:Destroy() end) end
                    instance.Frame = nil
                    local env = GetTASFFEnv()
                    if env and type(env.Drawings) == "table" then
                        local idx = table.find(env.Drawings, instance)
                        if idx then table.remove(env.Drawings, idx) end
                    end
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

-- // Environmental ESP — Adornment Pool (BoxHandleAdornment for 95% chams fill + SelectionBox for edge/corner outlines) // --
local EnvESPFolder = nil
local function GetEnvESPFolder()
    if EnvESPFolder and EnvESPFolder.Parent then return EnvESPFolder end
    local ok2, cg2 = pcall(function() return game:GetService("CoreGui") end)
    local parent2 = (ok2 and cg2) or workspace
    local ex = parent2:FindFirstChild("TASFF_EnvESP")
    if ex then pcall(function() ex:Destroy() end) end
    EnvESPFolder = Instance.new("Folder")
    EnvESPFolder.Name = "TASFF_EnvESP"
    EnvESPFolder.Parent = parent2
    if getgenv().TASFF and getgenv().TASFF.Drawings then
        table.insert(getgenv().TASFF.Drawings, EnvESPFolder)
    end
    return EnvESPFolder
end

local EnvAdornmentPool = {} -- BoxHandleAdornment pool for chams fill
local EnvBoxPool       = {} -- SelectionBox pool for crisp corner & edge outlines
local EnvProxyPool     = {} -- Part proxies for large-part surface slices

local function GetEnvAdornment(index)
    if not EnvAdornmentPool[index] then
        local adorn = Instance.new("BoxHandleAdornment")
        adorn.Name = "TASFF_EnvAdorn_" .. index
        adorn.AlwaysOnTop = true
        adorn.ZIndex = 1
        adorn.Color3 = S.EnvironmentalESPColor or Color3.fromRGB(0, 200, 255)
        adorn.Transparency = S.EnvironmentalESPTransparency or 0.95
        adorn.Visible = false
        adorn.Parent = GetEnvESPFolder()
        EnvAdornmentPool[index] = adorn
    end
    return EnvAdornmentPool[index]
end

local function GetEnvBox(index)
    if not EnvBoxPool[index] then
        local box = Instance.new("SelectionBox")
        box.Name = "TASFF_EnvBox_" .. index
        box.LineThickness = 0.04
        box.SurfaceTransparency = 1 -- BoxHandleAdornment handles the fill
        box.Visible = false
        box.Parent = GetEnvESPFolder()
        EnvBoxPool[index] = box
    end
    return EnvBoxPool[index]
end

local function GetEnvProxy(index)
    if not EnvProxyPool[index] then
        local proxy = Instance.new("Part")
        proxy.Name         = "TASFF_EnvProxy_" .. index
        proxy.Anchored     = true
        proxy.CanCollide   = false
        proxy.CanQuery     = false
        proxy.CanTouch     = false
        proxy.CastShadow   = false
        proxy.Transparency = 1
        proxy.Size         = Vector3.new(1, 0.15, 1)
        proxy.Parent       = GetEnvESPFolder()
        EnvProxyPool[index] = proxy
    end
    return EnvProxyPool[index]
end

local lastEnvScanTime = 0
local lastEnvScanRadius = 0
local lastEnvTargetPositions = {}
local cachedSelectedItems = {}

local function ClearEnvironmentalESP()
    for _, adorn in ipairs(EnvAdornmentPool) do
        if adorn then
            adorn.Visible = false
            adorn.Adornee = nil
        end
    end
    for _, box in ipairs(EnvBoxPool) do
        if box then
            box.Visible = false
            box.Adornee = nil
        end
    end
    for _, proxy in ipairs(EnvProxyPool) do
        if proxy and proxy.Parent then
            proxy.Size = Vector3.new(1, 0.15, 1)
        end
    end
    cachedSelectedItems = {}
    lastEnvTargetPositions = {}
end
S.ClearEnvironmentalESP = ClearEnvironmentalESP

local envOverlap = OverlapParams.new()
envOverlap.FilterType = Enum.RaycastFilterType.Exclude

-- Accurate distance to the closest point on the part's surface/boundary (OBB)
-- Ensures large parts like floors and walls calculate distance to the player's feet, NOT the part's center 100 studs away!
local function GetDistanceToPart(pPos, part, sz)
    local localPos = part.CFrame:PointToObjectSpace(pPos)
    local halfSize = sz * 0.5
    local cx = math.clamp(localPos.X, -halfSize.X, halfSize.X)
    local cy = math.clamp(localPos.Y, -halfSize.Y, halfSize.Y)
    local cz = math.clamp(localPos.Z, -halfSize.Z, halfSize.Z)
    local closestPt = part.CFrame:PointToWorldSpace(Vector3.new(cx, cy, cz))
    return (closestPt - pPos).Magnitude
end

local function UpdateEnvironmentalESP()
    if not (S.MasterEnabled and S.EnvironmentalESPEnabled) then
        if #EnvAdornmentPool > 0 or #EnvBoxPool > 0 then ClearEnvironmentalESP() end
        return
    end

    local radius = S.EnvironmentalESPRange or 15
    local targets = {}
    local PP = S.PriorityPlayers or {}

    -- Direct query ensures priority-only toggle correctly displays for all players when disabled
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            local hum  = p.Character:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                local isPrio = table.find(PP, p.Name) ~= nil
                    or (S.IntelPlayers and S.IntelPlayers[p.Name] ~= nil)
                if not S.EnvironmentalESPPriorityOnly or isPrio then
                    table.insert(targets, { Root = root, Player = p })
                end
            end
        end
    end

    if #targets == 0 then
        ClearEnvironmentalESP()
        return
    end

    local maxAdornments = S.EnvironmentalESPMaxParts or 160
    if S.EnvironmentalESPAutoScaling then
        local scaleTable = S.EnvironmentalESPScaleTable or {
            ["Ultra High"] = 400,
            ["High"]       = 260,
            ["Medium"]     = 160,
            ["Low"]        = 90,
            ["Ultra Low"]  = 45,
        }
        maxAdornments = scaleTable[S.PerformanceMode or "Medium"] or maxAdornments
    end
    local maxPartsPerTarget = math.clamp(math.floor(maxAdornments * 0.7), 40, 250)

    -- Throttle heavy workspace spatial queries to ~20 Hz or on player movement (eliminates FPS drop at large radius)
    local now = tick()
    local needScan = (now - lastEnvScanTime >= 0.05) or (#cachedSelectedItems == 0) or (lastEnvScanRadius ~= radius)
    if not needScan then
        for _, t in ipairs(targets) do
            local lastPos = lastEnvTargetPositions[t.Player]
            if not lastPos or (t.Root.Position - lastPos).Magnitude > 1.2 then
                needScan = true
                break
            end
        end
    end

    if needScan then
        lastEnvScanTime = now
        lastEnvScanRadius = radius
        lastEnvTargetPositions = {}
        for _, t in ipairs(targets) do
            lastEnvTargetPositions[t.Player] = t.Root.Position
        end

        local excludeList = {Camera}
        if Player and Player.Character then table.insert(excludeList, Player.Character) end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then table.insert(excludeList, p.Character) end
        end
        for _, npc in ipairs(S.CachedNPCs or {}) do table.insert(excludeList, npc) end
        for _, item in ipairs(S.CachedWorkspaceIgnores or {}) do table.insert(excludeList, item) end
        envOverlap.FilterDescendantsInstances = excludeList

        local targetPartLists = {}

        -- 1. Collect candidate parts per target sorted by surface proximity
        for _, t in ipairs(targets) do
            local pPos = t.Root.Position
            local ok, parts = pcall(function()
                return workspace:GetPartBoundsInRadius(pPos, radius, envOverlap)
            end)
            if ok and parts then
                local validList = {}
                for _, part in ipairs(parts) do
                    if part:IsA("BasePart") then
                        -- Never highlight character models, humanoids, or accessories
                        if not part:FindFirstAncestorOfClass("Accessory") then
                            local modelAnc = part:FindFirstAncestorOfClass("Model")
                            if not (modelAnc and modelAnc:FindFirstChildOfClass("Humanoid")) then
                                local sz = part.Size
                                local isLarge = (sz.X > 20 or sz.Y > 20 or sz.Z > 20)
                                -- Measure true distance to closest surface point so floors/walls under feet get top priority
                                local dist = GetDistanceToPart(pPos, part, sz)
                                table.insert(validList, {
                                    part = part,
                                    dist = dist,
                                    target = t,
                                    isLarge = isLarge,
                                    sz = sz
                                })
                            end
                        end
                    end
                end

                -- Sort closest to player surface first
                table.sort(validList, function(a, b) return a.dist < b.dist end)
                if #validList > maxPartsPerTarget then
                    local trimmed = {}
                    for i = 1, maxPartsPerTarget do trimmed[i] = validList[i] end
                    validList = trimmed
                end
                table.insert(targetPartLists, validList)
            end
        end

        -- 2. Interleaved round-robin selection across all targets
        local selected = {}
        local processedSmallParts = {}
        local processedLargeParts = {} -- [part] = { [targetPlayer] = true }
        local anyLeft = true
        local round = 1

        while anyLeft and #selected < maxAdornments do
            anyLeft = false
            for _, list in ipairs(targetPartLists) do
                if #selected >= maxAdornments then break end
                if round <= #list then
                    anyLeft = true
                    local item = list[round]
                    if item.isLarge then
                        local targetPlayer = item.target.Player or "P"
                        local map = processedLargeParts[item.part]
                        if not map then
                            map = {}
                            processedLargeParts[item.part] = map
                        end
                        if not map[targetPlayer] then
                            map[targetPlayer] = true
                            table.insert(selected, item)
                        end
                    else
                        if not processedSmallParts[item.part] then
                            processedSmallParts[item.part] = true
                            table.insert(selected, item)
                        end
                    end
                end
            end
            round = round + 1
        end

        cachedSelectedItems = selected
    end

    -- 3. Render adornments and wireframe boxes every frame
    local baseColor = S.EnvironmentalESPColor or Color3.fromRGB(0, 200, 255)
    local trans     = S.EnvironmentalESPTransparency or 0.95
    local usedCount = 0

    for _, item in ipairs(cachedSelectedItems) do
        local part = item.part
        if not (part and part.Parent) then continue end
        local t = item.target
        local pPos = (t and t.Root and t.Root.Parent) and t.Root.Position or item.part.Position
        local sz = item.sz
        local isLarge = item.isLarge

        usedCount = usedCount + 1
        if usedCount > maxAdornments then break end

        local adorn = GetEnvAdornment(usedCount)
        local box   = GetEnvBox(usedCount)

        adorn.Color3 = baseColor
        box.Color3   = baseColor

        local targetPartPos
        local sliceSize, sliceCenter

        if isLarge then
            -- True 2D surface slice on large parts (floors, walls, ceilings) centered on this target
            local localPos = part.CFrame:PointToObjectSpace(pPos)
            local halfSize = sz * 0.5

            -- Determine the surface normal axis the player is closest to
            local normalAxis = "Y"
            if sz.Y <= sz.X and sz.Y <= sz.Z then
                normalAxis = "Y" -- Flat floor or ceiling
            elseif sz.Z <= sz.X and sz.Z <= sz.Y then
                normalAxis = "Z" -- Z-aligned wall
            elseif sz.X <= sz.Y and sz.X <= sz.Z then
                normalAxis = "X" -- X-aligned wall
            else
                local dx = math.abs(math.abs(localPos.X) - halfSize.X)
                local dy = math.abs(math.abs(localPos.Y) - halfSize.Y)
                local dz = math.abs(math.abs(localPos.Z) - halfSize.Z)
                if dy <= dx and dy <= dz then normalAxis = "Y"
                elseif dz <= dx and dz <= dy then normalAxis = "Z"
                else normalAxis = "X" end
            end

            -- Slice covers the diameter of the configured radius around the player (visibly expands as radius slider increases)
            local sliceExtent = radius * 2.0

            if normalAxis == "Y" then
                local sx = math.min(sliceExtent, sz.X)
                local sz_len = math.min(sliceExtent, sz.Z)
                local sy = math.min(sz.Y, 0.15)
                local signY = (localPos.Y >= 0) and 1 or -1
                local cy = (halfSize.Y - (sy * 0.5)) * signY
                local minX = -halfSize.X + sx * 0.5
                local maxX = halfSize.X - sx * 0.5
                local cx = (minX < maxX) and math.clamp(localPos.X, minX, maxX) or 0
                local minZ = -halfSize.Z + sz_len * 0.5
                local maxZ = halfSize.Z - sz_len * 0.5
                local cz = (minZ < maxZ) and math.clamp(localPos.Z, minZ, maxZ) or 0
                sliceSize = Vector3.new(sx, sy, sz_len)
                sliceCenter = Vector3.new(cx, cy, cz)
            elseif normalAxis == "Z" then
                local sx = math.min(sliceExtent, sz.X)
                local sy = math.min(sliceExtent, sz.Y)
                local sz_len = math.min(sz.Z, 0.15)
                local signZ = (localPos.Z >= 0) and 1 or -1
                local cz = (halfSize.Z - (sz_len * 0.5)) * signZ
                local minX = -halfSize.X + sx * 0.5
                local maxX = halfSize.X - sx * 0.5
                local cx = (minX < maxX) and math.clamp(localPos.X, minX, maxX) or 0
                local minY = -halfSize.Y + sy * 0.5
                local maxY = halfSize.Y - sy * 0.5
                local cy = (minY < maxY) and math.clamp(localPos.Y, minY, maxY) or 0
                sliceSize = Vector3.new(sx, sy, sz_len)
                sliceCenter = Vector3.new(cx, cy, cz)
            else -- normalAxis == "X"
                local sy = math.min(sliceExtent, sz.Y)
                local sz_len = math.min(sliceExtent, sz.Z)
                local sx = math.min(sz.X, 0.15)
                local signX = (localPos.X >= 0) and 1 or -1
                local cx = (halfSize.X - (sx * 0.5)) * signX
                local minY = -halfSize.Y + sy * 0.5
                local maxY = halfSize.Y - sy * 0.5
                local cy = (minY < maxY) and math.clamp(localPos.Y, minY, maxY) or 0
                local minZ = -halfSize.Z + sz_len * 0.5
                local maxZ = halfSize.Z - sz_len * 0.5
                local cz = (minZ < maxZ) and math.clamp(localPos.Z, minZ, maxZ) or 0
                sliceSize = Vector3.new(sx, sy, sz_len)
                sliceCenter = Vector3.new(cx, cy, cz)
            end

            targetPartPos = (part.CFrame * CFrame.new(sliceCenter)).Position
        else
            targetPartPos = part.Position
        end

        -- Compute distance-based fade if enabled
        local partTrans = trans
        local lineThick = 0.04
        local isVisible = true

        if S.EnvironmentalESPDistanceFade then
            local dist = (targetPartPos - pPos).Magnitude
            local distFrac = math.clamp(dist / math.max(radius, 1), 0, 1)
            partTrans = trans + (1 - trans) * distFrac
            lineThick = math.clamp(0.04 * (1 - distFrac), 0, 0.04)
            if distFrac >= 0.98 or partTrans >= 0.999 then
                isVisible = false
            end
        end

        adorn.Transparency = math.clamp(partTrans, 0, 1)
        box.LineThickness  = lineThick

        if isLarge then
            local proxy = GetEnvProxy(usedCount)
            if proxy then
                proxy.CFrame = part.CFrame * CFrame.new(sliceCenter)
                proxy.Size   = sliceSize

                adorn.Adornee = proxy
                adorn.CFrame  = CFrame.new(0, 0, 0)
                adorn.Size    = sliceSize
                adorn.Visible = isVisible

                box.Adornee = proxy
                box.Visible = isVisible
            end
        else
            -- Small parts: fully highlight the part with chams fill and edge outlines
            adorn.Adornee = part
            adorn.CFrame  = CFrame.new(0, 0, 0)
            adorn.Size    = sz + Vector3.new(0.04, 0.04, 0.04)
            adorn.Visible = isVisible

            box.Adornee = part
            box.Visible = isVisible
        end
    end

    -- 4. Hide unused pool entries
    for i = usedCount + 1, #EnvAdornmentPool do
        local adorn = EnvAdornmentPool[i]
        if adorn and adorn.Visible then
            adorn.Visible = false
            adorn.Adornee = nil
        end
    end
    for i = usedCount + 1, #EnvBoxPool do
        local box = EnvBoxPool[i]
        if box and box.Visible then
            box.Visible = false
            box.Adornee = nil
        end
        local proxy = EnvProxyPool[i]
        if proxy then proxy.Size = Vector3.new(1, 0.15, 1) end
    end
end
S.UpdateEnvironmentalESP = UpdateEnvironmentalESP

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
    ClearEnvironmentalESP()
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
    if S._PrevCameraMode then
        pcall(function() Player.CameraMode = S._PrevCameraMode end)
        S._PrevCameraMode = nil
    end
    S._ExpertInstinctsActive = false
    S._ExpertInstinctsAttacker = nil
    S._ExpertInstinctsTargetChar = nil
    if S.IsHoldingClick then
        S.IsHoldingClick = false
        pcall(function()
            local loc = UserInputService:GetMouseLocation()
            VirtualInputManager:SendMouseButtonEvent(loc.X, loc.Y, 0, false, game, 0)
        end)
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

local function UnloadScript(isRestarting)
    if not isRestarting then
        TriggerPanic()
    else
        S.MasterEnabled = false
        S.AimbotActive  = false
        S.CurrentTarget = nil
        SetADSState(false)
        if S._PrevCameraMode then
            pcall(function() Player.CameraMode = S._PrevCameraMode end)
            S._PrevCameraMode = nil
        end
        S._ExpertInstinctsActive = false
        S._ExpertInstinctsAttacker = nil
        S._ExpertInstinctsTargetChar = nil
        if S.IsHoldingClick then
            S.IsHoldingClick = false
            pcall(function()
                local loc = UserInputService:GetMouseLocation()
                VirtualInputManager:SendMouseButtonEvent(loc.X, loc.Y, 0, false, game, 0)
            end)
        end
        if S.IsHoldingTriggerKey then
            S.IsHoldingTriggerKey = false
            pcall(function()
                local key = GetKeyCode(S.KeyTriggerbotKey)
                if key then VirtualInputManager:SendKeyEvent(false, key, false, game) end
            end)
        end
        S.SilentAimTargetCache = nil
        ClearVisuals()
        ClearCrosshair()
        if S.FOVCircle then S.FOVCircle.Visible = false end
    end

    if getgenv().TASFF then getgenv().TASFF.Running = false end
    if S.ToolAddedConnection then pcall(function() S.ToolAddedConnection:Disconnect() end); S.ToolAddedConnection = nil end
    if S.ToolRemovedConnection then pcall(function() S.ToolRemovedConnection:Disconnect() end); S.ToolRemovedConnection = nil end
    if getgenv().TASFF and getgenv().TASFF.Cleanup then pcall(getgenv().TASFF.Cleanup) end
    if getgenv().TASFF and getgenv().TASFF.Connections then
        for _, conn in pairs(getgenv().TASFF.Connections) do
            pcall(function() conn:Disconnect() end)
        end
        pcall(function() table.clear(getgenv().TASFF.Connections) end)
    end
    -- Clean up all tracked drawings and destroy the overlay ScreenGui
    if getgenv().TASFF and getgenv().TASFF.Drawings then
        for _, d in pairs(getgenv().TASFF.Drawings) do
            pcall(function()
                if d and d.Frame then d.Frame:Destroy()
                elseif d and d.Remove then d:Remove()
                elseif d and d.Destroy then d:Destroy() end
            end)
        end
        pcall(function() table.clear(getgenv().TASFF.Drawings) end)
    end

    -- Thorough cleanup across gethui(), CoreGui, and PlayerGui
    local parentsToClean = {}
    local okHui, hui = pcall(gethui)
    if okHui and hui then table.insert(parentsToClean, hui) end
    local okCg, cg = pcall(function() return game:GetService("CoreGui") end)
    if okCg and cg then table.insert(parentsToClean, cg) end
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

    -- Native Roblox notification — fired before Rayfield GUI is destroyed (skip if restarting)
    if not isRestarting then
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title    = "TASFF Unloaded",
                Text     = "Script and interface fully terminated.",
                Duration = 5,
            })
        end)
    end
    pcall(function() if Rayfield and Rayfield.Destroy then Rayfield:Destroy() end end)
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
    local envTheme = (getgenv and getgenv().TASFF and getgenv().TASFF.Theme)
    if envTheme and envTheme.SetTabBadge then
        pcall(function() envTheme.SetTabBadge("Intel", #sorted) end)
    end
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
        local permSuffix = data.permanent and " [PERM]" or ""
        local conf = "●●○○"
        if src == "Kill Count" or src == "Nemesis" or data.permanent then
            conf = "●●●●"
        elseif src == "Damage" or src:find("Damage") then
            conf = "●●●○"
        elseif src == "Instincts" or src:find("Instinct") then
            conf = "●●○○"
        else
            conf = "●○○○"
        end
        table.insert(lines, string.format("%s %s%s  [%s]%s  %d pts%s%s", conf, name, displaySuffix, src, permSuffix, pts, killSuffix, selected))
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
    -- Priority hierarchy: Manual/Explicit actions supersede auto-detections.
    -- Nemesis (4) > Marked (3) > Registry (2) > Threat (1)
    local srcPriority = {Nemesis=4, Marked=3, Registry=2, Threat=1}
    if S.IntelPlayers[name] then
        local curSrc = S.IntelPlayers[name].source or "Marked"
        if (srcPriority[source] or 0) > (srcPriority[curSrc] or 0) then
            S.IntelPlayers[name].source = source
        end
        S.IntelPlayers[name].points = (S.IntelPlayers[name].points or 0) + pts
        if source == "Nemesis" then S.IntelPlayers[name].nemesis = true end
        if source ~= "Nemesis" and not table.find(S.PriorityPlayers or {}, name) then
            table.insert(S.PriorityPlayers, name)
            SyncPriorityUI()
        end
    else
        local isAlreadyPriority = table.find(S.PriorityPlayers or {}, name) ~= nil
        local effectiveSource = source
        if isAlreadyPriority and source == "Threat" then
            effectiveSource = "Registry"
        end
        S.IntelPlayers[name] = { source=effectiveSource, points=pts, nemesis=(source=="Nemesis") }
        if source ~= "Nemesis" and not isAlreadyPriority then
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
    if S.PlayerKillCounts then S.PlayerKillCounts[name] = 0 end
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

        -- Foliage & Concealment Check:
        -- Prevents targeting through bushes, foliage, leaves, shrubs, hedges, or opaque non-collidable cover
        local isFoliage = false
        if S.FoliageConcealmentCheck ~= false then
            local mat = hit.Material
            if mat == Enum.Material.Leaves or mat == Enum.Material.Grass then
                isFoliage = true
            else
                local hn = hit.Name:lower()
                if hn:find("bush") or hn:find("leaf") or hn:find("leaves") or hn:find("foliage")
                    or hn:find("shrub") or hn:find("hedge") or hn:find("grass") or hn:find("tree")
                    or hn:find("plant") or hn:find("vine") or hn:find("branch") then
                    isFoliage = true
                end
            end
        end

        if isFoliage then
            -- Opaque foliage/bush blocks visual sight even if CanCollide is false!
            return false
        end

        local canPass = false
        if S.NoCollisionCheck and not hit.CanCollide then
            -- If non-collidable part is visually opaque (< threshold), human eyes cannot see through it
            if S.FoliageConcealmentCheck ~= false and (hit.Transparency < (S.TransparencyThreshold or 0.5)) then
                canPass = false
            else
                canPass = true
            end
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

local VOS_PART_GROUPS = {
    ["Head"] = { "Head" },
    ["Torso"] = { "Torso", "UpperTorso", "LowerTorso" },
    ["Right and Left Arm"] = {
        "Right Arm", "RightUpperArm", "RightLowerArm", "RightHand",
        "Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand"
    },
    ["Leg"] = {
        "Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot",
        "Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"
    },
    ["Right Arm"] = { "Right Arm", "RightUpperArm", "RightLowerArm", "RightHand" },
    ["Left Arm"]  = { "Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand" },
    ["Right Leg"] = { "Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot" },
    ["Left Leg"]  = { "Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" },
}

local ALL_VOS_PARTS = {
    "Head", "Torso", "UpperTorso", "LowerTorso",
    "Right Arm", "RightUpperArm", "RightLowerArm", "RightHand",
    "Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot",
    "Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
}

local function FindVisibleOnScreenPart(model, ignoreList)
    if not model or not model.Parent then return nil end
    if not Camera then Camera = workspace.CurrentCamera end
    if not Camera then return nil end

    local priorityNames = {}
    local prioritySet = {}
    local configured = (type(S.VOSPriorityParts) == "table" and #S.VOSPriorityParts > 0) and S.VOSPriorityParts or { "Head", "Torso" }
    for _, item in ipairs(configured) do
        local subParts = VOS_PART_GROUPS[item] or { item }
        for _, partName in ipairs(subParts) do
            if not prioritySet[partName] then
                prioritySet[partName] = true
                table.insert(priorityNames, partName)
            end
        end
    end

    local fallbackNames = {}
    for _, partName in ipairs(ALL_VOS_PARTS) do
        if not prioritySet[partName] then
            table.insert(fallbackNames, partName)
        end
    end

    local aimPosition = GetAimPosition()

    -- Phase 1: Scan prioritized body parts first. If any priority part is visible, aim at the best priority part!
    local bestPriorityPart, bestPriorityDistance = nil, math.huge
    for _, name in ipairs(priorityNames) do
        local part = model:FindFirstChild(name)
        local ok, isVisible = false, false
        if part and part:IsA("BasePart") then
            ok, isVisible = pcall(IsVisibleWallcheck, model, name, ignoreList)
        end
        if ok and isVisible then
            local point, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local distance = (ApplyScreenCalibration(Vector2.new(point.X, point.Y)) - aimPosition).Magnitude
                if distance < bestPriorityDistance then
                    bestPriorityPart, bestPriorityDistance = part, distance
                end
            end
        end
    end

    if bestPriorityPart then
        return bestPriorityPart
    end

    -- Phase 2: If none of the prioritized parts are visible, aim at any remaining visible body part (limbs)
    local bestFallbackPart, bestFallbackDistance = nil, math.huge
    for _, name in ipairs(fallbackNames) do
        local part = model:FindFirstChild(name)
        local ok, isVisible = false, false
        if part and part:IsA("BasePart") then
            ok, isVisible = pcall(IsVisibleWallcheck, model, name, ignoreList)
        end
        if ok and isVisible then
            local point, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local distance = (ApplyScreenCalibration(Vector2.new(point.X, point.Y)) - aimPosition).Magnitude
                if distance < bestFallbackDistance then
                    bestFallbackPart, bestFallbackDistance = part, distance
                end
            end
        end
    end

    return bestFallbackPart
end

local _lastFP = {}
local function RegisterThreat(attackerName, isKill)
    if not attackerName or attackerName == Player.Name then return end
    if S.TeamCheck and Player and Player.Team then
        local pObj = Players:FindFirstChild(attackerName)
        if pObj and pObj.Team and pObj.Team == Player.Team then
            return
        end
    end
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

        local intelEntry = S.IntelPlayers and S.IntelPlayers[attackerName]
        local isManualOrRegistry = (intelEntry and (intelEntry.source == "Marked" or intelEntry.source == "Registry" or intelEntry.permanent))
            or (not intelEntry and table.find(S.PriorityPlayers or {}, attackerName) ~= nil)

        if not isManualOrRegistry then
            ThreatMemory[attackerName] = tick()
        end
        local isAlreadyPrioritized = (intelEntry ~= nil) or (table.find(S.PriorityPlayers or {}, attackerName) ~= nil)
        S.SessionThreatsAdded = (S.SessionThreatsAdded or 0) + 1
        if S.AddToIntel then S.AddToIntel(attackerName, "Threat", 5) end
        if not isAlreadyPrioritized then
            Notify({Title="TASFF Threat",Content="Registered Threat: "..attackerName,Duration=2,Image="alert-circle"})
        end
    end
end


-- // ── Enhanced Threat Intelligence Engine (v2.2.5) ────────────── // --
local RecentStatKills = {} -- [Player] = { delta = number, time = number }

local function ExtractPlayerFromValue(val)
    if not val then return nil end
    if typeof(val) == "Instance" then
        if val:IsA("Player") then return val end
        if val:IsA("Model") then
            local p = Players:GetPlayerFromCharacter(val)
            if p then return p end
        end
        if val:IsA("ObjectValue") and val.Value then
            if val.Value:IsA("Player") then return val.Value end
            if val.Value:IsA("Model") then
                local p = Players:GetPlayerFromCharacter(val.Value)
                if p then return p end
            end
        elseif (val:IsA("StringValue") or val:IsA("TextValue")) and val.Value ~= "" then
            local p = Players:FindFirstChild(val.Value)
            if p then return p end
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl.DisplayName:lower() == val.Value:lower() or pl.Name:lower() == val.Value:lower() then
                    return pl
                end
            end
        elseif (val:IsA("IntValue") or val:IsA("NumberValue")) and val.Value > 1000 then
            local p = Players:GetPlayerByUserId(val.Value)
            if p then return p end
        end
    elseif type(val) == "string" and val ~= "" then
        local p = Players:FindFirstChild(val)
        if p then return p end
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl.DisplayName:lower() == val:lower() or pl.Name:lower() == val:lower() then
                return pl
            end
        end
    elseif type(val) == "number" and val > 1000 then
        local p = Players:GetPlayerByUserId(val)
        if p then return p end
    end
    return nil
end

local ThreatTagNames = {
    "creator", "Creator", "creatorTag", "CreatorTag", "KilledBy", "killedBy",
    "Killer", "killer", "Attacker", "attacker", "LastAttacker", "lastAttacker",
    "DamageTag", "damageTag", "LastDamagedBy", "lastDamagedBy", "HitBy", "hitBy",
    "tag", "Tag", "KillCredit", "killCredit"
}

local ThreatAttributeNames = {
    "creator", "Creator", "Killer", "killer", "KilledBy", "killedBy",
    "Attacker", "attacker", "LastDamagedBy", "lastDamagedBy", "LastAttacker",
    "lastAttacker", "KillCredit"
}

local function ScanForKillerTag(char, hum)
    if not (char or hum) then return nil end
    local containers = {}
    if hum then table.insert(containers, hum) end
    if char then table.insert(containers, char) end
    if hum then
        local t = hum:FindFirstChild("Tags") or hum:FindFirstChild("Damage")
        if t then table.insert(containers, t) end
    end
    if char then
        local t = char:FindFirstChild("Tags") or char:FindFirstChild("Damage")
        if t then table.insert(containers, t) end
    end

    -- 1. Check child value objects
    for _, container in ipairs(containers) do
        for _, tagName in ipairs(ThreatTagNames) do
            local child = container:FindFirstChild(tagName)
            if child then
                local p = ExtractPlayerFromValue(child)
                if p then return p end
            end
        end
    end

    -- 2. Check Luau attributes
    for _, container in ipairs(containers) do
        for _, attrName in ipairs(ThreatAttributeNames) do
            local attrVal = container:GetAttribute(attrName)
            if attrVal ~= nil then
                local p = ExtractPlayerFromValue(attrVal)
                if p then return p end
            end
        end
    end

    return nil
end

-- Hook Leaderstats for a player to track kill deltas
local function HookPlayerLeaderstats(p)
    if not p then return end
    local function hookFolder(folder)
        if not folder then return end
        for _, item in ipairs(folder:GetChildren()) do
            local name = item.Name:lower()
            if name:find("kill") or name:find("ko") or name:find("frag") or name:find("elim") or name == "score" or name == "points" then
                if item:IsA("IntValue") or item:IsA("NumberValue") then
                    local lastVal = item.Value
                    TrackConnection(item.Changed:Connect(function(newVal)
                        if typeof(newVal) == "number" and newVal > lastVal then
                            RecentStatKills[p] = { delta = newVal - lastVal, time = tick() }
                        end
                        lastVal = newVal
                    end))
                end
            end
        end
        TrackConnection(folder.ChildAdded:Connect(function(item)
            local name = item.Name:lower()
            if name:find("kill") or name:find("ko") or name:find("frag") or name:find("elim") or name == "score" or name == "points" then
                if item:IsA("IntValue") or item:IsA("NumberValue") then
                    local lastVal = item.Value
                    TrackConnection(item.Changed:Connect(function(newVal)
                        if typeof(newVal) == "number" and newVal > lastVal then
                            RecentStatKills[p] = { delta = newVal - lastVal, time = tick() }
                        end
                        lastVal = newVal
                    end))
                end
            end
        end))
    end

    local ls = p:FindFirstChild("leaderstats") or p:FindFirstChild("Stats") or p:FindFirstChild("stats")
    if ls then hookFolder(ls) end
    TrackConnection(p.ChildAdded:Connect(function(child)
        local n = child.Name:lower()
        if n == "leaderstats" or n == "stats" then hookFolder(child) end
    end))
end

for _, pl in ipairs(Players:GetPlayers()) do HookPlayerLeaderstats(pl) end
TrackConnection(Players.PlayerAdded:Connect(HookPlayerLeaderstats))

-- Advanced Asynchronous Killer Resolution
local function ResolveKiller(victimPlayer, victimChar, victimHum, onResolved)
    task.spawn(function()
        local killer = nil
        local victimName = victimPlayer and victimPlayer.Name or "?"
        local victimRoot = victimChar and victimChar:FindFirstChild("HumanoidRootPart")
        local victimPos  = victimRoot and victimRoot.Position

        -- Tier 1: Immediate tag scan
        if S.DeepThreatScanEnabled ~= false then
            killer = ScanForKillerTag(victimChar, victimHum)
        else
            local creator = victimHum and (victimHum:FindFirstChild("creator") or victimHum:FindFirstChild("creatorTag"))
            killer = ExtractPlayerFromValue(creator)
        end
        if killer and killer ~= victimPlayer then
            if S.DebugMode then print("[TASFF Intel] Killer resolved via Tier 1 (immediate tag) for victim " .. victimName .. ": " .. killer.Name) end
            onResolved(killer)
            return
        end

        -- Tier 1.5: Micro-yield retry (handles network replication lag of tags)
        task.wait(0.04)
        if S.DeepThreatScanEnabled ~= false then
            killer = ScanForKillerTag(victimChar, victimHum)
            if killer and killer ~= victimPlayer then
                if S.DebugMode then print("[TASFF Intel] Killer resolved via Tier 1.5 (delayed tag) for victim " .. victimName .. ": " .. killer.Name) end
                onResolved(killer)
                return
            end
        end

        -- Tier 2: Leaderstats Delta Correlator (with optional proximity filter)
        if S.StatCorrelatorEnabled ~= false then
            local now = tick()
            local bestCandidate = nil
            local bestTimeDiff = 999
            local proximityLimit = (S.ThreatProximityRadius or 80) * 2
            for pl, statData in pairs(RecentStatKills) do
                if pl ~= victimPlayer then
                    local diff = now - statData.time
                    if diff >= 0 and diff <= 0.35 and diff < bestTimeDiff then
                        -- Proximity filter: skip candidates too far away to be the killer
                        local plRoot = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
                        if victimPos and plRoot then
                            if (plRoot.Position - victimPos).Magnitude <= proximityLimit then
                                bestCandidate = pl
                                bestTimeDiff = diff
                            elseif S.DebugMode then
                                print("[TASFF Intel] Tier 2 skipped " .. pl.Name .. " (too far: " .. math.floor((plRoot.Position - victimPos).Magnitude) .. " studs)")
                            end
                        else
                            -- No position data — accept without proximity filter
                            bestCandidate = pl
                            bestTimeDiff = diff
                        end
                    end
                end
            end
            if bestCandidate then
                if S.DebugMode then print("[TASFF Intel] Killer resolved via Tier 2 (stat delta) for victim " .. victimName .. ": " .. bestCandidate.Name) end
                onResolved(bestCandidate)
                return
            end
        end

        -- Tier 2.5: Secondary yield for slower leaderstats sync (with proximity filter)
        if S.StatCorrelatorEnabled ~= false then
            task.wait(0.06)
            local now = tick()
            local proximityLimit = (S.ThreatProximityRadius or 80) * 2
            for pl, statData in pairs(RecentStatKills) do
                if pl ~= victimPlayer then
                    local diff = now - statData.time
                    if diff >= 0 and diff <= 0.45 then
                        local plRoot = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
                        if victimPos and plRoot then
                            if (plRoot.Position - victimPos).Magnitude <= proximityLimit then
                                if S.DebugMode then print("[TASFF Intel] Killer resolved via Tier 2.5 (delayed stat delta) for victim " .. victimName .. ": " .. pl.Name) end
                                onResolved(pl)
                                return
                            elseif S.DebugMode then
                                print("[TASFF Intel] Tier 2.5 skipped " .. pl.Name .. " (too far: " .. math.floor((plRoot.Position - victimPos).Magnitude) .. " studs)")
                            end
                        else
                            if S.DebugMode then print("[TASFF Intel] Killer resolved via Tier 2.5 (delayed stat delta) for victim " .. victimName .. ": " .. pl.Name) end
                            onResolved(pl)
                            return
                        end
                    end
                end
            end
        end

        -- Unresolved / Environment / Suicide
        if S.DebugMode then print("[TASFF Intel] Killer UNRESOLVED for victim " .. victimName .. " (no tag, no stat delta, or out of range)") end
        onResolved(nil)
    end)
end

local function HasDefendingWeapon()
    if not Player then return true end
    local backpack = Player:FindFirstChildOfClass("Backpack")
    local char = Player.Character
    local tools = {}
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then table.insert(tools, item) end
        end
    end
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then table.insert(tools, item) end
        end
    end

    if #tools == 0 then
        -- Completely unarmed (no tools in hands or backpack)
        return false
    end

    -- Priority check: if any tool is in InstinctsPrioritizedTools, immediately engage!
    for _, tool in ipairs(tools) do
        if table.find(S.InstinctsPrioritizedTools or {}, tool.Name) then
            return true
        end
    end

    -- General check: is there at least one tool that is NOT blacklisted and qualifies as Weapon or Melee?
    for _, tool in ipairs(tools) do
        local isBlacklisted = (table.find(S.InstinctsBlacklist or {}, tool.Name) ~= nil)
            or (table.find(S.ToolBlacklist or {}, tool.Name) ~= nil)
        if not isBlacklisted then
            local classification = S.ClassifyTool and S.ClassifyTool(tool.Name) or "Unknown"
            if classification == "Weapon" or classification == "Melee" then
                return true
            end
        end
    end

    return false
end
S.HasDefendingWeapon = HasDefendingWeapon

local function EquipDefendingWeapon()
    if not Player or not Player.Character then return false end
    local hum = Player.Character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local backpack = Player:FindFirstChildOfClass("Backpack")
    local char = Player.Character

    -- First, check if currently equipped tool is already a prioritized tool
    local currentTool = char:FindFirstChildOfClass("Tool")
    if currentTool and table.find(S.InstinctsPrioritizedTools or {}, currentTool.Name) then
        return true -- already holding top priority weapon
    end

    -- Check Backpack for a prioritized tool first
    if backpack and S.InstinctsPrioritizedTools then
        for _, toolName in ipairs(S.InstinctsPrioritizedTools) do
            local found = backpack:FindFirstChild(toolName)
            if found and found:IsA("Tool") then
                pcall(function() hum:EquipTool(found) end)
                return true
            end
        end
    end

    -- If currently holding a valid (non-blacklisted) weapon or melee tool, keep it
    if currentTool then
        local isBlacklisted = (table.find(S.InstinctsBlacklist or {}, currentTool.Name) ~= nil)
            or (table.find(S.ToolBlacklist or {}, currentTool.Name) ~= nil)
        if not isBlacklisted then
            local classification = S.ClassifyTool and S.ClassifyTool(currentTool.Name) or "Unknown"
            if classification == "Weapon" or classification == "Melee" then
                return true
            end
        end
    end

    -- Otherwise, find best weapon or melee in Backpack that isn't blacklisted
    if backpack then
        local candidate = nil
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local isBlacklisted = (table.find(S.InstinctsBlacklist or {}, tool.Name) ~= nil)
                    or (table.find(S.ToolBlacklist or {}, tool.Name) ~= nil)
                if not isBlacklisted then
                    local classification = S.ClassifyTool and S.ClassifyTool(tool.Name) or "Unknown"
                    if classification == "Weapon" then
                        candidate = tool
                        break -- prioritize ranged Weapon over Melee
                    elseif classification == "Melee" and not candidate then
                        candidate = tool
                    end
                end
            end
        end
        if candidate then
            pcall(function() hum:EquipTool(candidate) end)
            return true
        end
    end

    return false
end
S.EquipDefendingWeapon = EquipDefendingWeapon

local function FindLikelyAttacker(victimChar, victimPlayer)
    if not victimChar then return nil end
    local victimRoot = victimChar:FindFirstChild("HumanoidRootPart") or victimChar:FindFirstChild("Torso") or victimChar:FindFirstChild("UpperTorso")
    if not victimRoot then return nil end
    local victimPos = victimRoot.Position
    local maxScanRadius = S.ThreatProximityRadius or 80

    local bestCandidate = nil
    local bestScore = 0

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local ignoreList = {victimChar}
    if Camera then table.insert(ignoreList, Camera) end
    raycastParams.FilterDescendantsInstances = ignoreList
    raycastParams.IgnoreWater = true

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= victimPlayer and p.Character then
            -- Team check: candidate must not be a teammate of victim OR local player if TeamCheck is active
            local skipCandidate = false
            if S.TeamCheck then
                if victimPlayer and victimPlayer.Team and p.Team and p.Team == victimPlayer.Team then
                    skipCandidate = true
                elseif Player and Player.Team and p.Team and p.Team == Player.Team then
                    skipCandidate = true
                elseif Player and p.Neutral == false and Player.Neutral == false and p.TeamColor == Player.TeamColor then
                    skipCandidate = true
                end
            end

            if not skipCandidate then
                local pChar = p.Character
                local pHum = pChar:FindFirstChildOfClass("Humanoid")
                local pRoot = pChar:FindFirstChild("HumanoidRootPart") or pChar:FindFirstChild("Torso")
                if pHum and pHum.Health > 0 and pRoot then
                    local dist = (pRoot.Position - victimPos).Magnitude
                    if dist <= maxScanRadius and dist > 0.1 then
                        local heldTool = pChar:FindFirstChildOfClass("Tool")
                        local hasWeapon = false
                        local isRanged = false
                        local isMelee = false
                        if heldTool then
                            local toolName = heldTool.Name
                            local classification = S.ClassifyTool and S.ClassifyTool(toolName) or "Unknown"
                            if classification == "Weapon" then
                                hasWeapon = true
                                isRanged = true
                            elseif classification == "Melee" then
                                hasWeapon = true
                                isMelee = true
                            elseif classification ~= "NonWeapon" then
                                if heldTool:FindFirstChild("Handle") or heldTool:FindFirstChildWhichIsA("BasePart") then
                                    hasWeapon = true
                                end
                            end
                        end

                        local lookDir = pRoot.CFrame.LookVector
                        local dirToVictim = (victimPos - pRoot.Position).Unit
                        local dotAim = lookDir:Dot(dirToVictim)

                        local isPlausible = false
                        if isRanged and dist <= maxScanRadius then
                            -- Require weapon + tight aim alignment for ranged attribution (>= 0.82)
                            isPlausible = hasWeapon and (dotAim >= 0.82)
                        elseif isMelee and dist <= 18 then
                            isPlausible = (dotAim >= 0.50)
                        elseif hasWeapon and dist <= maxScanRadius then
                            isPlausible = (dotAim >= 0.82)
                        elseif not hasWeapon and dist <= 6 then
                            -- Unarmed: must be in extreme point-blank range (<= 6 studs) and directly facing victim (>= 0.85)
                            isPlausible = (dotAim >= 0.85)
                        end

                        if isPlausible then
                            local pHead = pChar:FindFirstChild("Head") or pRoot
                            local rayOrigin = pHead.Position
                            local rayDir = (victimPos - rayOrigin)
                            local rayResult = workspace:Raycast(rayOrigin, rayDir, raycastParams)
                            local losClear = false
                            if not rayResult then
                                losClear = true
                            else
                                local hitInstance = rayResult.Instance
                                if hitInstance:IsDescendantOf(victimChar) or hitInstance:IsDescendantOf(pChar) or hitInstance.Transparency > 0.7 or not hitInstance.CanCollide then
                                    losClear = true
                                end
                            end

                            if losClear then
                                local score = 0
                                score = score + math.clamp(dotAim * 50, 0, 50)
                                score = score + math.clamp((1 - (dist / maxScanRadius)) * 40, 0, 40)
                                if hasWeapon then score = score + 40 end
                                if isMelee and dist <= 12 then score = score + 30 end

                                -- Require strong confidence (score >= 95) before registering heuristic threat
                                if score >= 95 and score > bestScore then
                                    bestScore = score
                                    bestCandidate = p
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return bestCandidate
end
S.FindLikelyAttacker = FindLikelyAttacker

local function HookThreatHealth(char)
    if not char then return end
    local humanoid = char:WaitForChild("Humanoid", 3)
    if not humanoid then return end
    local lastHealth = humanoid.Health
    local diedHandled = false

    local function handleLocalDeath()
        if diedHandled then return end
        diedHandled = true
        if S._PrevCameraMode then
            pcall(function() Player.CameraMode = S._PrevCameraMode end)
            S._PrevCameraMode = nil
        end
        S._ExpertInstinctsActive = false
        S._ExpertInstinctsAttacker = nil
        S._ExpertInstinctsTargetChar = nil
        ResolveKiller(Player, char, humanoid, function(killer)
            if killer then
                RegisterThreat(killer.Name, true)
            else
                local likelyAttacker = FindLikelyAttacker(char, Player)
                if likelyAttacker then
                    RegisterThreat(likelyAttacker.Name, true)
                end
            end
        end)
    end

    TrackConnection(humanoid.HealthChanged:Connect(function(newHealth)
        if (S.ThreatDetectorEnabled or S.ExpertInstinctsEnabled) and newHealth < lastHealth then
            if newHealth <= 0 then
                handleLocalDeath()
            else
                local healthDrop = lastHealth - newHealth
                local creator = (S.DeepThreatScanEnabled ~= false and ScanForKillerTag(char, humanoid))
                    or humanoid:FindFirstChild("creator") or humanoid:FindFirstChild("creatorTag")
                local pObj = ExtractPlayerFromValue(creator)
                local attackerName = nil
                local attackerObj = nil
                if pObj and pObj ~= Player then
                    local isTeammate = false
                    if S.TeamCheck and Player and Player.Team and pObj.Team and pObj.Team == Player.Team then
                        isTeammate = true
                    elseif S.TeamCheck and Player and pObj.Neutral == false and Player.Neutral == false and pObj.TeamColor == Player.TeamColor then
                        isTeammate = true
                    end
                    if not isTeammate then
                        attackerName = pObj.Name
                        attackerObj = pObj
                        if S.ThreatDetectorEnabled then
                            RegisterThreat(pObj.Name, false)
                        end
                    end
                elseif healthDrop >= 6 then
                    -- Only run heuristic scan if health drop is substantial (>= 6 HP) to prevent false positives from fall/chip damage
                    local likelyAttacker = FindLikelyAttacker(char, Player)
                    if likelyAttacker then
                        attackerName = likelyAttacker.Name
                        attackerObj = likelyAttacker
                        if S.ThreatDetectorEnabled then
                            RegisterThreat(likelyAttacker.Name, false)
                        end
                    end
                end

                -- v2.2.5 Expert Instincts: Instant counter-reaction camera snap & lock-on
                if S.ExpertInstinctsEnabled and attackerObj and attackerObj.Character then
                    -- Verify attacker is not a teammate
                    local isTeammate = false
                    if S.TeamCheck and Player and Player.Team and attackerObj.Team and attackerObj.Team == Player.Team then
                        isTeammate = true
                    elseif S.TeamCheck and Player and attackerObj.Neutral == false and Player.Neutral == false and attackerObj.TeamColor == Player.TeamColor then
                        isTeammate = true
                    end
                    if isTeammate then
                        lastHealth = newHealth
                        return
                    end

                    -- Instincts Inventory Defense Check: suppress lock if unarmed/fleeing
                    if S.InstinctsInventoryCheck and not HasDefendingWeapon() then
                        if S.DebugMode then
                            print("[TASFF Instincts] Suppressed counter-lock: No defending weapon found in inventory (fleeing).")
                        end
                        lastHealth = newHealth
                        return
                    end

                    -- Auto-Equip Defending Weapon if enabled
                    if S.InstinctsAutoEquip then
                        EquipDefendingWeapon()
                    end

                    -- Auto First-Person Camera if enabled
                    if S.InstinctsFirstPersonCamera and Player then
                        if not S._PrevCameraMode then
                            S._PrevCameraMode = Player.CameraMode
                        end
                        pcall(function()
                            Player.CameraMode = Enum.CameraMode.LockFirstPerson
                        end)
                    end

                    local aChar = attackerObj.Character
                    local aRoot = aChar:FindFirstChild("HumanoidRootPart")
                    local aHum = aChar:FindFirstChildOfClass("Humanoid")
                    if aRoot and aHum and aHum.Health > 0 then
                        S.VisibilityPrecomputed[aChar] = true
                        if S.DeadTargetsCache then S.DeadTargetsCache[aChar] = nil end
                        local targetPart = aChar:FindFirstChild(S.TargetPart) or aChar:FindFirstChild("Head") or aRoot
                        local aimPos = targetPart.Position
                        local intensity = math.clamp(S.ExpertInstinctsIntensity or 60, 0, 100)
                        local iMode = S.InstinctsMode or "Blatant"
                        S._ExpertInstinctsActive = true
                        S._ExpertInstinctsExpiry = tick() + 0.75
                        S._ExpertInstinctsAttacker = attackerObj
                        S._ExpertInstinctsTargetChar = aChar
                        S._ExpertInstinctsIntensity = intensity
                        S._ExpertInstinctsLastKnownPos = aimPos  -- persist for cover-hidden steering
                        -- Initial trigger snap: Blatant does immediate partial snap; Legit defers to per-frame lerp
                        if iMode == "Blatant" then
                            if intensity >= 100 then
                                Camera.CFrame = CFrame.new(Camera.CFrame.Position, aimPos)
                            else
                                local targetCF = CFrame.new(Camera.CFrame.Position, aimPos)
                                local initialFraction = math.clamp(intensity / 100, 0.02, 0.98)
                                Camera.CFrame = Camera.CFrame:Lerp(targetCF, initialFraction)
                            end
                        end
                        -- (Legit mode: no immediate snap — per-frame steering handles it smoothly)
                        S.CurrentTarget = {
                            Instance = aChar,
                            Root = aRoot,
                            Name = attackerName or attackerObj.Name,
                            IsPlayer = true,
                            Player = attackerObj,
                            ScreenAnchor = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2),
                            DistFromCenter = 0,
                            Distance = (aimPos - Camera.CFrame.Position).Magnitude,
                            Position = aimPos,
                            ScreenPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2),
                            Health = aHum.Health,
                            TeamColor = attackerObj.TeamColor and attackerObj.TeamColor.Color or Color3.fromRGB(255, 60, 60)
                        }
                        if S.MasterEnabled then
                            S.AimbotActive = true
                        end
                        if S.Notify then
                            S.Notify({Title = "Expert Instincts", Content = "Counter-locked onto attacker: " .. (attackerName or attackerObj.Name), Duration = 2, Image = "zap"})
                        end
                    end
                end
            end
        end
        lastHealth = newHealth
    end))

    TrackConnection(humanoid.Died:Connect(handleLocalDeath))
end


task.spawn(function()
    while getgenv().TASFF and getgenv().TASFF.Running do
        task.wait(0.5)
        local now = tick(); local changed = false
        for name, timestamp in pairs(ThreatMemory) do
            local intelEntry = S.IntelPlayers and S.IntelPlayers[name]
            if intelEntry and intelEntry.permanent then
                ThreatMemory[name] = now -- keep permanent threats alive until neutralized
            elseif intelEntry and (intelEntry.source == "Marked" or intelEntry.source == "Registry") then
                ThreatMemory[name] = nil -- preserve manual marks without expiry
            elseif now - timestamp >= S.ThreatTimeout then
                ThreatMemory[name] = nil
                local idx = table.find(S.PriorityPlayers, name)
                if idx then table.remove(S.PriorityPlayers, idx); changed = true end
                if intelEntry and intelEntry.source == "Threat" then
                    S.IntelPlayers[name] = nil
                    changed = true
                end
                if S.BlacklistExpiredThreats and not table.find(S.BlacklistedPlayers, name) then
                    table.insert(S.BlacklistedPlayers, name)
                    Notify({Title="TASFF Threat Memory",Content=name.." expired -> Moved to Blacklist",Duration=2,Image="ban"})
                else
                    Notify({Title="TASFF Threat Memory",Content="Threat Expired: "..name,Duration=2,Image="hourglass"})
                end
            end
        end
        if changed then
            SyncPriorityUI()
            RebuildIntelMonitor()
        end

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

        -- RecentStatKills GC: prune entries older than 2 seconds to prevent memory leak
        for pl, statData in pairs(RecentStatKills) do
            if now - statData.time > 2 then
                RecentStatKills[pl] = nil
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
            local intelEntry = S.IntelPlayers and S.IntelPlayers[name]
            if intelEntry and intelEntry.permanent then
                text = text .. "* " .. name .. " [PERMANENT until neutralized]\n"
            else
                local rem = math.max(0, math.floor(S.ThreatTimeout - (now - ts)))
                text = text .. "* " .. name .. " (" .. rem .. "s remaining)\n"
            end
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
        local isPriority = table.find(S.PriorityPlayers or {}, targetName) ~= nil
        local hasIntel = (S.IntelPlayers and S.IntelPlayers[targetName] ~= nil)
        if isPriority or hasIntel then
            if S.RemoveFromIntel then
                S.RemoveFromIntel(targetName, false)
            else
                local idx = table.find(S.PriorityPlayers or {}, targetName)
                if idx then table.remove(S.PriorityPlayers, idx) end
                if S.IntelPlayers then S.IntelPlayers[targetName] = nil end
                SyncPriorityUI()
            end
            Notify({Title="TASFF Mark",Content="Unmarked "..targetName.." from Intel.",Duration=2,Image="minus-circle"})
        else
            if S.AddToIntel then
                S.AddToIntel(targetName, "Marked", 0)
            else
                table.insert(S.PriorityPlayers, targetName)
                SyncPriorityUI()
            end
            Notify({Title="TASFF Mark",Content="Marked "..targetName.." as Priority!",Duration=2,Image="crosshair"})
        end
    else
        Notify({Title="TASFF Mark",Content="No target detected near cursor.",Duration=1.5,Image="locate-off"})
    end
end
S.HandleClickToMark = HandleClickToMark

table.insert(getgenv().TASFF.Connections, UserInputService.InputBegan:Connect(function(input, gpe)
    if not (getgenv().TASFF and getgenv().TASFF.Running and S.ScriptInitialized) then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        -- Still process mouse-button marks below
    end
    if input.KeyCode ~= Enum.KeyCode.Unknown then
        -- Panic key (always highest priority, ignores gpe)
        local panicKey = GetKeyCode(S.PanicKeybind)
        if panicKey and input.KeyCode == panicKey then
            TriggerPanic(); return
        end

        -- Master Switch toggle keybind
        if not gpe and not S.PanicLocked and S.MasterSwitchKeybind and S.MasterSwitchKeybind ~= "None" and S.MasterSwitchKeybind ~= "" then
            local masterKey = GetKeyCode(S.MasterSwitchKeybind)
            if masterKey and input.KeyCode == masterKey then
                if S.ToggleMasterSwitch then
                    S.ToggleMasterSwitch()
                else
                    S.MasterEnabled = not S.MasterEnabled
                    if not S.MasterEnabled then
                        S.AimbotActive = false; S.CurrentTarget = nil; S.AimbotCandidates = {}
                        if S.SetADSState    then S.SetADSState(false)  end
                        if S.ClearVisuals   then S.ClearVisuals()      end
                        if S.ClearCrosshair then S.ClearCrosshair()    end
                        if S.FOVCircle      then S.FOVCircle.Visible = false end
                    end
                    Notify({
                        Title    = "TASFF System",
                        Content  = S.MasterEnabled and "Master Switch ENABLED" or "Master Switch DISABLED",
                        Duration = 1.5,
                        Image    = S.MasterEnabled and "power" or "power-off",
                    })
                end
            end
        end

        -- Aimbot activation toggle
        if not gpe and S.MasterEnabled and not S.PanicLocked then
            local aimKey = GetKeyCode(S.AimbotKeybind)
            if aimKey and input.KeyCode == aimKey then
                S.AimbotActive = not S.AimbotActive
                if not S.AimbotActive then
                    S.CurrentTarget = nil
                    S.AimbotCandidates = {}
                    S.SilentAimTargetCache = nil
                    S.LastCustomTargetData = nil
                    S.SilentAimTargetCacheTime = 0
                    if S.SetADSState then S.SetADSState(false) end
                end
                Notify({
                    Title   = "TASFF Aimbot",
                    Content = S.AimbotActive and "Aimbot ACTIVE" or "Aimbot PAUSED",
                    Duration = 1.5,
                    Image   = S.AimbotActive and "crosshair" or "crosshair-off",
                })
            end
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

        -- Quick Preset Switching Keybind — debounced to prevent double-fire on key repeat
        if not gpe and S.QuickPresetSwitchEnabled then
            local switchKey = GetKeyCode(S.QuickPresetSwitchKey)
            if switchKey and input.KeyCode == switchKey then
                local now2 = tick()
                if not S._LastPresetSwitchTime or (now2 - S._LastPresetSwitchTime) >= 0.35 then
                    S._LastPresetSwitchTime = now2
                    if S.CycleToNextPreset then
                        task.spawn(S.CycleToNextPreset)
                    end
                end
            end
        end

        -- Target Mark Keybind
        if not gpe and S.ClickToMarkEnabled and (S.MarkMethod == "Keybind Only" or S.MarkMethod == "Both") then
            local markKey = GetKeyCode(S.MarkKeybind)
            if markKey and input.KeyCode == markKey then
                if not (S.MasterEnabled and S.AimbotActive and S.CurrentTarget ~= nil) then
                    local toolEquipped = Player.Character and Player.Character:FindFirstChildOfClass("Tool") ~= nil
                    if not toolEquipped then
                        HandleClickToMark()
                    end
                end
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
            table.clear(S.VisibilityPrecomputed)
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

-- // ── Instincts Defense Blacklist & Priority Save/Load ─────────── // --
local IBLFILE = S.InstinctsBlacklistFileName or "TASFF_InstinctsBlacklist.json"
local IPRIFILE = S.InstinctsPriorityFileName or "TASFF_InstinctsPriority.json"

local function SaveInstinctsLists()
    local env = GetTASFFEnv()
    if not (env and env.Capabilities and env.Capabilities.FileWrite) or type(writefile) ~= "function" then
        return false
    end
    pcall(function()
        writefile(IBLFILE, HttpService:JSONEncode(S.InstinctsBlacklist or {}))
        writefile(IPRIFILE, HttpService:JSONEncode(S.InstinctsPrioritizedTools or {}))
    end)
    return true
end

local function LoadInstinctsLists()
    local env = GetTASFFEnv()
    if not (env and env.Capabilities and env.Capabilities.FileRead) or type(isfile) ~= "function" or type(readfile) ~= "function" then
        return false
    end
    pcall(function()
        if isfile and isfile(IBLFILE) then
            local raw = readfile(IBLFILE)
            local ok, tbl = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok and type(tbl) == "table" then
                S.InstinctsBlacklist = tbl
                if S.InstinctsBlacklistDropdownRef and S.InstinctsBlacklistDropdownRef.Refresh then
                    local lst = #tbl > 0 and tbl or {"No Items Blacklisted"}
                    pcall(function() S.InstinctsBlacklistDropdownRef:Refresh(lst, true) end)
                end
            end
        end
        if isfile and isfile(IPRIFILE) then
            local raw = readfile(IPRIFILE)
            local ok, tbl = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok and type(tbl) == "table" then
                S.InstinctsPrioritizedTools = tbl
                if S.InstinctsPriorityDropdownRef and S.InstinctsPriorityDropdownRef.Refresh then
                    local lst = #tbl > 0 and tbl or {"No Items Prioritized"}
                    pcall(function() S.InstinctsPriorityDropdownRef:Refresh(lst, true) end)
                end
            end
        end
    end)
    return true
end

S.SaveInstinctsLists = SaveInstinctsLists
S.LoadInstinctsLists = LoadInstinctsLists
pcall(LoadInstinctsLists)

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
            tag.Parent = model
            tag.Size=UDim2.new(0,200,0,70); tag.AlwaysOnTop=true; tag.StudsOffset=Vector3.new(0,3,0)
            local l = Instance.new("TextLabel", tag)
            l.Size=UDim2.new(1,0,1,0); l.BackgroundTransparency=1; l.Font=Enum.Font.Code; l.TextSize=14
            l.TextStrokeTransparency=0
            l.TextStrokeColor3=Color3.fromRGB(0,0,0)
        end
        TagCache[model] = tag
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
        local subParts = VOS_PART_GROUPS[name] or { name }
        for _, sp in ipairs(subParts) do
            addName(sp)
        end
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

        local pos = root.Position
        local distFromCam = (pos - Camera.CFrame.Position).Magnitude
        if distFromCam > (maxDistance or S.AimbotRenderDistance) then return end

        -- v2.1.0 Render-thread wallcheck elimination with v2.2.5 Ambush Latency Fix:
        -- Read from S.VisibilityPrecomputed (background loop ③).
        -- If nil (cold start), do live check.
        -- If false, but target is close (< 120 studs), in Intel, or in Priority list,
        -- perform an immediate live check to eliminate the 300-600ms background sweep delay on surprise attacks!
        if performWallCheck then
            local precomp = S.VisibilityPrecomputed[model]
            if precomp == nil then
                if S.TargetPart == "Visible On Screen" then
                    precomp = FindVisibleOnScreenPart(model, customIgnoreList) ~= nil
                else
                    precomp = IsVisibleCachedWrapper(model, S.ActivePartName, customIgnoreList)
                end
                S.VisibilityPrecomputed[model] = precomp
            elseif not precomp then
                local isPriorityOrClose = (distFromCam < 120) or (S.IntelPlayers and S.IntelPlayers[targetName] ~= nil) or (table.find(S.PriorityPlayers or {}, targetName) ~= nil)
                if isPriorityOrClose then
                    local liveVis
                    if S.TargetPart == "Visible On Screen" then
                        liveVis = FindVisibleOnScreenPart(model, customIgnoreList) ~= nil
                    else
                        liveVis = IsVisibleCachedWrapper(model, S.ActivePartName, customIgnoreList)
                    end
                    if liveVis then
                        precomp = true
                        S.VisibilityPrecomputed[model] = true
                    end
                end
            end
            if not precomp then return end
        end
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
        local diedHandled = false

        local function handlePlayerDeath()
            if diedHandled then return end
            diedHandled = true

            ResolveKiller(p, char, hum, function(killerObj)
                local killerName = killerObj and killerObj.Name or "Unknown"

                -- Check if the victim was a threat or priority target in Intel
                local victimIntel = S.IntelPlayers and S.IntelPlayers[p.Name]
                local victimIsPrio = table.find(S.PriorityPlayers or {}, p.Name) ~= nil
                local isThreatVictim = (victimIntel ~= nil) or victimIsPrio
                local priorityReason = ""
                if isThreatVictim then
                    local src = victimIntel and victimIntel.source
                    if src == "Nemesis" or (victimIntel and victimIntel.nemesis) then
                        priorityReason = "nemesis"
                    elseif src == "Threat" then
                        priorityReason = "threat"
                    elseif src == "Marked" then
                        priorityReason = "click to mark"
                    elseif src == "Registry" then
                        priorityReason = "registry"
                    elseif victimIsPrio then
                        priorityReason = "priority"
                    else
                        priorityReason = "priority"
                    end
                end

                if S.KillFeedEnabled and killerName ~= "Unknown" and killerName ~= p.Name then
                    local feedContent
                    if isThreatVictim and priorityReason ~= "" then
                        feedContent = killerName .. " neutralized " .. p.Name .. " (" .. priorityReason .. ")"
                    else
                        feedContent = killerName .. " killed " .. p.Name
                    end
                    Notify({Title="TASFF Intel", Content=feedContent, Duration=2, Image="crosshair"})
                end

                -- Session User Kill Count: track if WE killed this player
                local localPlayerKilled = (killerObj == Player)
                if localPlayerKilled then
                    S.SessionUserKills = (S.SessionUserKills or 0) + 1
                    if S.DebugMode then print("[TASFF Debug] Session kill #"..S.SessionUserKills.." on "..p.Name) end
                end

                -- If victim was a threat/priority player and IgnoreThreatVictims is enabled,
                -- killing them does NOT count towards the killer's killstreak, nemesis, or threat auto-flagging.
                local skipThreatAttribution = (S.IgnoreThreatVictims ~= false and isThreatVictim)

                if killerObj and killerObj ~= Player and killerObj ~= p and not skipThreatAttribution then
                    -- Add to global kill count for auto-flagging
                    if S.KillCountThreatEnabled then
                        S.PlayerKillCounts[killerName] = (S.PlayerKillCounts[killerName] or 0) + 1
                        local streak = S.PlayerKillCounts[killerName]
                        local permReq = S.ContinuousKillsPermanent or 5
                        local threatReq = S.KillsBeforeThreat or 3
                        local kData = S.IntelPlayers and S.IntelPlayers[killerName]

                        if streak >= permReq then
                            if S.AddToIntel then S.AddToIntel(killerName, "Threat", 30) end
                            if S.IntelPlayers and S.IntelPlayers[killerName] then
                                S.IntelPlayers[killerName].permanent = true
                            end
                            -- Only notify once per killer reaching permanent status
                            if not S._PermanentPriorityNotified then S._PermanentPriorityNotified = {} end
                            if not S._PermanentPriorityNotified[killerName] then
                                S._PermanentPriorityNotified[killerName] = true
                                Notify({Title="TASFF Threat", Content="💀 " .. killerName .. " is now PERMANENT (Streak: " .. streak .. ") until neutralized!", Duration=3, Image="alert-triangle"})
                            end
                        elseif streak >= threatReq then
                            local isTracked = (kData and (kData.nemesis or kData.source == "Threat" or kData.source == "Registry" or kData.source == "Marked")) or (table.find(S.PriorityPlayers or {}, killerName) ~= nil)
                            if not isTracked then
                                if S.AddToIntel then S.AddToIntel(killerName, "Threat", 30) end
                                Notify({Title="TASFF Threat", Content=killerName.." flagged as Threat (Kill Streak: "..streak..").", Duration=2, Image="alert-circle"})
                            else
                                if S.AddToIntel then S.AddToIntel(killerName, (kData and kData.source) or "Registry", 15) end
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

                -- Reset kill streak upon death/neutralization
                S.PlayerKillCounts[p.Name] = 0
                if S.PriorityPlayerKills and S.PriorityPlayerKills[p.Name] then
                    S.PriorityPlayerKills[p.Name] = 0
                end
                if S.IntelPlayers and S.IntelPlayers[p.Name] then
                    S.IntelPlayers[p.Name].permanent = nil
                end
                -- Reset permanent notification dedup so future streaks can notify again
                if S._PermanentPriorityNotified then
                    S._PermanentPriorityNotified[p.Name] = nil
                end

                if not S.ThreatNeutralizationEnabled then return end
                local data = S.IntelPlayers and S.IntelPlayers[p.Name]
                local isPrio = table.find(S.PriorityPlayers or {}, p.Name)
                if (data and not data.nemesis) or isPrio then
                    if S.RemoveFromIntel then S.RemoveFromIntel(p.Name, false) end
                    Notify({Title="Intel",Content="Neutralized: "..p.Name.." removed from Intel.",Duration=2,Image="check-circle"})
                end
            end)
        end

        local lastHealth = hum.Health
        TrackConnection(hum.Died:Connect(function()
            lastHealth = 0 -- keep lastHealth in sync so respawn doesn't misfire
            handlePlayerDeath()
        end))
        TrackConnection(hum.HealthChanged:Connect(function(newHealth)
            if newHealth <= 0 then
                lastHealth = 0
                handlePlayerDeath()
            elseif S.OtherPlayersDamageTracking and newHealth < lastHealth then
                local healthDrop = lastHealth - newHealth
                -- Attempt to read a creator/attacker tag written by the game's damage script
                local creator = (S.DeepThreatScanEnabled ~= false and ScanForKillerTag(char, hum))
                    or hum:FindFirstChild("creator") or hum:FindFirstChild("creatorTag")
                local attacker = ExtractPlayerFromValue(creator)
                -- Heuristic proximity fallback: used when no damage tag exists.
                -- Threshold lowered to 4 HP (from 12) so single-bullet hits are captured;
                -- FindLikelyAttacker already has its own proximity/line-of-sight filter to
                -- suppress environmental or distant false positives.
                if not attacker and healthDrop >= 4 then
                    attacker = FindLikelyAttacker(char, p)
                end
                if attacker and attacker ~= p and attacker ~= Player then
                    local isTeammate = false
                    if S.TeamCheck and Player and Player.Team and attacker.Team and attacker.Team == Player.Team then
                        isTeammate = true
                    elseif S.TeamCheck and Player and attacker.Neutral == false and Player.Neutral == false and attacker.TeamColor == Player.TeamColor then
                        isTeammate = true
                    end
                    if not isTeammate then
                        local victimIntel = S.IntelPlayers and S.IntelPlayers[p.Name]
                        local victimIsPrio = table.find(S.PriorityPlayers or {}, p.Name) ~= nil
                        local isThreatVictim = (victimIntel ~= nil) or victimIsPrio
                        local skipThreat = (S.IgnoreThreatVictims ~= false and isThreatVictim)
                        if not skipThreat then
                            RegisterThreat(attacker.Name, false)
                        end
                    end
                end
            end
            lastHealth = newHealth
        end))
        TrackConnection(char.AncestryChanged:Connect(function(_, parent)
            if not parent and hum.Health < 20 then handlePlayerDeath() end
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
    -- Prune per-player runtime tables on disconnect to prevent stale key accumulation
    if S._PermanentPriorityNotified then S._PermanentPriorityNotified[p.Name] = nil end
    if S.PlayerNemesisStrikes then S.PlayerNemesisStrikes[p.Name] = nil end
    if S.PlayerNemesisStrikeTimes then S.PlayerNemesisStrikeTimes[p.Name] = nil end
    if S.PlayerKillCounts then S.PlayerKillCounts[p.Name] = nil end
    if S.PriorityPlayerKills then S.PriorityPlayerKills[p.Name] = nil end
end))

task.defer(function()
    -- Render loop remains idle until UI loading sequence completes and explicitly sets S.ScriptInitialized = true
    S.CurrentTarget = nil
    print("[TASFF Core v" .. tostring(S and S.CurrentVersion or "?") .. "] Core function slots registered. Awaiting UI sequence...")
end)

-- // ══════════════════════════════════════════════════════════════ // --
-- //                      MAIN RENDER LOOP                        // --
-- // ══════════════════════════════════════════════════════════════ // --

local function UpdateSpectator()
    if S.SpectatePlayerEnabled and S.SpectateTarget and S.SpectateTarget ~= "" then
        local targetName = (S.ResolvePlayerName and S.ResolvePlayerName(S.SpectateTarget)) or S.SpectateTarget
        local p = Players:FindFirstChild(targetName)
        if p then
            if p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                workspace.CurrentCamera.CameraSubject = p.Character.Humanoid
                S.WasSpectating = true
                return
            elseif p.Character and p.Character:FindFirstChild("Head") then
                workspace.CurrentCamera.CameraSubject = p.Character.Head
                S.WasSpectating = true
                return
            end
            -- Player is still in server but currently respawning/waiting for character
            -- Keep spectating active without resetting the toggle
            return
        else
            -- Player left the server
            S.SpectatePlayerEnabled = false
            if S.SyncSpectatorUI then S.SyncSpectatorUI(false) end
            if S.Notify then
                S.Notify({
                    Title    = "TASFF Spectator",
                    Content  = "Spectate target left the server.",
                    Duration = 3,
                    Image    = "user-x"
                })
            end
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

-- // ── v2.2.5 Humanized Legit Aim Engine Helpers ────────────────── // --
local currentHitboxDrift    = Vector3.new(0, 0, 0)
local targetHitboxDrift     = Vector3.new(0, 0, 0)
local lastDriftPickTime     = 0
local smoothedAimPos        = nil
local lastTrackedTargetChar = nil

-- Multi-harmonic organic physiological tremor (breathing + muscle micro-oscillation)
local function GetHumanTremor(dt)
    local t = tick()
    -- Slow natural breathing / wrist posture drift (0.6 - 0.9 Hz)
    local swayX = math.sin(t * 1.5) * 1.8 + math.cos(t * 2.1) * 1.0
    local swayY = math.cos(t * 1.3) * 1.5 + math.sin(t * 1.8) * 0.8
    -- Physiological muscle tremor (9 - 13 Hz micro-tremor)
    local tremorX = math.sin(t * 9.6) * 1.2 + math.cos(t * 14.1) * 0.6
    local tremorY = math.cos(t * 10.2) * 1.0 + math.sin(t * 15.3) * 0.5
    local intensity = S.HumanTremorIntensity or 0.6
    return Vector2.new(swayX + tremorX, swayY + tremorY) * intensity
end

local RenderConnection = RunService.RenderStepped:Connect(function(deltaTime)
    if not (getgenv().TASFF and getgenv().TASFF.Running and S.ScriptInitialized) then return end
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
        and ((MasterEnabled and AimbotActive and TargetingEnabled) or (S.LiveFOVPulseActive and S.LiveFOVPulseEnabled ~= false))
        and not IsHiddenFromRecording("FOV Circle")   -- Cloak: suppress when hidden from recording
    if S.FOVCircle then
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
    if S.EnableCrosshair and not IsHiddenFromRecording("Crosshair") then   -- Cloak: suppress crosshair
        local color = S.CrosshairColor or Color3.fromRGB(240, 240, 240)
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
                -- DeadTargetsCache cap: prune entries whose flash has already expired to prevent unbounded growth
                if S.DeadTargetsCache then
                    local now2 = tick()
                    local flashDur = S.KillFlashDuration or 0.8
                    for model, ts in pairs(S.DeadTargetsCache) do
                        if (now2 - ts) > flashDur + 1 then
                            S.DeadTargetsCache[model] = nil
                        end
                    end
                end
                -- OOF Angle Smooth cache cap: prune stale model entries
                if S._OOFAngleSmooth then
                    for model, _ in pairs(S._OOFAngleSmooth) do
                        if not model or not model.Parent then
                            S._OOFAngleSmooth[model] = nil
                        end
                    end
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
        if not Camera or not Camera.Parent then Camera = workspace.CurrentCamera end
        if not Camera then return end
        local TargetPart = (type(S.TargetPart) == "string" and S.TargetPart ~= "") and S.TargetPart or "Head"
        local WallCheck = S.WallCheck
        if not S.ActivePartName or S.ActivePartName == "" then
            S.ActivePartName = (TargetPart ~= "Visible On Screen") and TargetPart or "Head"
        end
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
                if S._ExpertInstinctsActive then
                    if (now < (S._ExpertInstinctsExpiry or 0)) and S._ExpertInstinctsTargetChar and S._ExpertInstinctsTargetChar.Parent then
                        local aChar = S._ExpertInstinctsTargetChar
                        local aHum = aChar:FindFirstChildOfClass("Humanoid")
                        local aRoot = aChar:FindFirstChild("HumanoidRootPart")
                        if aHum and aHum.Health > 0 and aRoot then
                            local aimPos = (aChar:FindFirstChild(TargetPart) or aChar:FindFirstChild("Head") or aRoot).Position
                            S.CurrentTarget = {
                                Instance = aChar,
                                Root = aRoot,
                                Name = S._ExpertInstinctsAttacker and S._ExpertInstinctsAttacker.Name or aChar.Name,
                                IsPlayer = true,
                                Player = S._ExpertInstinctsAttacker,
                                ScreenAnchor = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2),
                                DistFromCenter = 0,
                                Distance = (aimPos - Camera.CFrame.Position).Magnitude,
                                Position = aimPos,
                                ScreenPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2),
                                Health = aHum.Health,
                                TeamColor = S._ExpertInstinctsAttacker and S._ExpertInstinctsAttacker.TeamColor and S._ExpertInstinctsAttacker.TeamColor.Color or Color3.fromRGB(255, 60, 60)
                            }
                        else
                            S._ExpertInstinctsActive = false
                            S._ExpertInstinctsAttacker = nil
                            S._ExpertInstinctsTargetChar = nil
                            if S._PrevCameraMode then
                                pcall(function() Player.CameraMode = S._PrevCameraMode end)
                                S._PrevCameraMode = nil
                            end
                            S.CurrentTarget = filtered[1]
                        end
                    else
                        S._ExpertInstinctsActive = false
                        S._ExpertInstinctsAttacker = nil
                        S._ExpertInstinctsTargetChar = nil
                        if S._PrevCameraMode then
                            pcall(function() Player.CameraMode = S._PrevCameraMode end)
                            S._PrevCameraMode = nil
                        end
                        S.CurrentTarget = filtered[1]
                    end
                else
                    S.CurrentTarget = filtered[1]
                end
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

            -- Cloak: gate ESP Highlights / Chams from Roblox recording
            local cloakHighlight = IsHiddenFromRecording("ESP Highlights (Chams)")
                or IsHiddenFromRecording("Drawing-Based ESP (Box, Skeleton, Snaplines, OOF Arrows)")
            h.Adornee=t.Instance
            if cloakHighlight then
                h.Enabled = false
                h.FillTransparency = 1
                h.OutlineTransparency = 1
            else
                if t.IsPlayer then h.Enabled=UH else h.Enabled=UNH end
            end
            h.OutlineColor=bc
            local rootPart=t.Instance:FindFirstChild("HumanoidRootPart")
            local headPart=t.Instance:FindFirstChild("Head")
            if not rootPart then continue end
            local pos,onScreen=Camera:WorldToViewportPoint(rootPart.Position)
            local headPos=headPart and Camera:WorldToViewportPoint(headPart.Position+Vector3.new(0,0.5,0)) or pos
            -- Cloak: OOF Arrows
            local cloakOOF = IsHiddenFromRecording("OOF Arrows")
                or IsHiddenFromRecording("Drawing-Based ESP (Box, Skeleton, Snaplines, OOF Arrows)")
            local oofTargetValid = not S.OOFArrowsPriorityOnly or isPriority
            if OOFE and not onScreen and not cloakOOF and oofTargetValid then
                if not OOFArrowCache[t.Instance] then
                    local arrow=NewDrawing("Triangle")
                    if arrow then arrow.Thickness=2;arrow.Filled=true;OOFArrowCache[t.Instance]=arrow end
                end
                local arrow=OOFArrowCache[t.Instance]
                if arrow then
                    local center=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
                    -- Project world direction onto camera right/up axes for a fully stable angle.
                    -- Dot products never have z-sign discontinuity and work correctly whether the
                    -- target is in front of or behind the camera.
                    local worldDir = (rootPart.Position - Camera.CFrame.Position)
                    local screenX = worldDir:Dot(Camera.CFrame.RightVector)
                    local screenY = -worldDir:Dot(Camera.CFrame.UpVector) -- screen Y is inverted
                    local rawAngle = math.atan2(screenY, screenX)
                    -- Exponential moving-average smoothing per arrow to eliminate jitter
                    -- from HumanoidRootPart animation bob and camera wobble.
                    if not S._OOFAngleSmooth then S._OOFAngleSmooth = {} end
                    local prev = S._OOFAngleSmooth[t.Instance]
                    local angle
                    if prev then
                        -- Shortest arc interpolation to avoid 2π wrap-around snapping
                        local diff = ((rawAngle - prev + math.pi) % (2 * math.pi)) - math.pi
                        angle = prev + diff * math.min(1, deltaTime * 12)
                    else
                        angle = rawAngle
                    end
                    S._OOFAngleSmooth[t.Instance] = angle
                    local r=OOFR
                    arrow.PointA=center+Vector2.new(math.cos(angle),math.sin(angle))*r
                    arrow.PointB=center+Vector2.new(math.cos(angle-0.2),math.sin(angle-0.2))*(r-20)
                    arrow.PointC=center+Vector2.new(math.cos(angle+0.2),math.sin(angle+0.2))*(r-20)
                    arrow.Color=statusESPColor or S.OOFArrowColor or SLC or bc; arrow.Visible=true
                end
            else
                if OOFArrowCache[t.Instance] then OOFArrowCache[t.Instance].Visible=false end
                -- Clear smoothed angle when arrow hides so next appearance starts fresh
                if S._OOFAngleSmooth then S._OOFAngleSmooth[t.Instance] = nil end
            end
            if onScreen then
                local hs=ApplyScreenCalibration(Vector2.new(headPos.X,headPos.Y))
                -- Tags: when cloakTags=true, GetVisualAssets already returned a BillboardGui
                -- (recording-invisible). Render into it exactly as normal — you see it, recording doesn't.
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
                        if lbl then
                            lbl.Text=fs
                            lbl.TextColor3=bc
                            lbl.TextStrokeTransparency=0
                            lbl.TextStrokeColor3=Color3.fromRGB(0,0,0)
                        end
                        tag.Adornee=t.Instance:FindFirstChild("Head") or rootPart; tag.Enabled=true
                    else
                        tag.Text=fs;tag.Position=Vector2.new(hs.X,hs.Y-35);tag.Color=bc;tag.Outline=true;tag.Visible=true
                    end
                else if typeof(tag)=="Instance" then tag.Enabled=false else pcall(function() tag.Visible=false end) end end
                -- Cloak: Snaplines
                local cloakSnap = IsHiddenFromRecording("Snaplines")
                    or IsHiddenFromRecording("Drawing-Based ESP (Box, Skeleton, Snaplines, OOF Arrows)")
                if SE and not cloakSnap then
                    if not SnaplineCache[t.Instance] then local line=NewDrawing("Line"); if line then line.Thickness=1.5;SnaplineCache[t.Instance]=line end end
                    local sl=SnaplineCache[t.Instance]
                    if sl then
                        PrepareDrawing(sl)
                        local o2=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y)
                        if SO=="Center" then o2=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2) end
                        sl.From=o2;sl.To=Vector2.new(pos.X,pos.Y);sl.Color=statusESPColor or SLC or bc;sl.Visible=true
                    end
                else if SnaplineCache[t.Instance] then SnaplineCache[t.Instance].Visible=false end end
                -- Cloak: Box ESP
                local cloakBox = IsHiddenFromRecording("Box ESP")
                    or IsHiddenFromRecording("Drawing-Based ESP (Box, Skeleton, Snaplines, OOF Arrows)")
                if BME and not cloakBox then
                    local lp=Camera:WorldToViewportPoint(rootPart.Position-Vector3.new(0,3,0))
                    local bH=math.abs(headPos.Y-lp.Y); local bW=bH*0.65
                    if not BoxCache[t.Instance] then local box=NewDrawing("Square"); if box then box.Thickness=1.5;box.Filled=false;BoxCache[t.Instance]=box end end
                    if BoxCache[t.Instance] then
                        PrepareDrawing(BoxCache[t.Instance])
                        BoxCache[t.Instance].Size=Vector2.new(bW,bH)
                        BoxCache[t.Instance].Position=Vector2.new(hs.X-(bW/2),hs.Y)
                        BoxCache[t.Instance].Color=statusESPColor or S.BoxColor or bc; BoxCache[t.Instance].Visible=true
                    end
                else if BoxCache[t.Instance] then BoxCache[t.Instance].Visible=false end end
                -- Cloak: Skeleton ESP
                local cloakSkel = IsHiddenFromRecording("Skeleton ESP")
                    or IsHiddenFromRecording("Drawing-Based ESP (Box, Skeleton, Snaplines, OOF Arrows)")
                if SkME and not cloakSkel then
                    local isR15=t.Instance:FindFirstChild("UpperTorso")~=nil
                    DrawSkeleton(t.Instance, isR15 and R15Joints or R6Joints, statusESPColor or S.SkeletonColor or bc)
                    skeletonsRenderedThisFrame[t.Instance] = true
                else if SkeletonCache[t.Instance] then for _,l in ipairs(SkeletonCache[t.Instance]) do if l and l.Line then l.Line.Visible=false end end end end
            else
                if typeof(tag)=="Instance" then tag.Enabled=false else pcall(function() tag.Visible=false end) end
                if BoxCache[t.Instance] then BoxCache[t.Instance].Visible=false end
                if SnaplineCache[t.Instance] then SnaplineCache[t.Instance].Visible=false end
                if SkeletonCache[t.Instance] then for _,l in ipairs(SkeletonCache[t.Instance]) do if l and l.Line then l.Line.Visible=false end end end
            end
            if cloakHighlight then
                -- Cloak: force chams invisible when ESP Highlights are hidden from recording
                h.DepthMode = Enum.HighlightDepthMode.Occluded
                h.FillTransparency = 1
                h.OutlineTransparency = 1
            elseif ChE then
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
    UpdateEnvironmentalESP()
    if MasterEnabled then
        local CT = S.CurrentTarget
        local TP = (type(S.TargetPart) == "string" and S.TargetPart ~= "") and S.TargetPart or "Head"
        if CT and TargetingEnabled and AimbotActive and canAimWithTool then
            local TWP=nil
            local tv=CT.Root and CT.Root.AssemblyLinearVelocity or Vector3.new(0,0,0)
            local isM = tv.Magnitude > 1.5
            local Mode = (type(S.Mode) == "string" and S.Mode ~= "") and S.Mode or "Legit (Camera)"
            local PA = S.PredictionAmount or 0.16
            if S.DistancePredictionAdjustEnabled and CT.Root then
                local targetDist = (CT.Root.Position - Camera.CFrame.Position).Magnitude
                local maxPA = S.MaxAutoPrediction or 0.45
                local distFactor = math.clamp((targetDist - 40) / 360, 0, 1)
                PA = PA + (maxPA - PA) * distFactor
            end
            if TP=="Visible On Screen" then
                local lvPart = S.LastCustomTargetData and S.LastCustomTargetData.Part
                if not (lvPart and lvPart.Parent and lvPart:IsDescendantOf(CT.Instance)) then
                    lvPart = FindVisibleOnScreenPart(CT.Instance, cachedIgnoreList)
                    if lvPart then
                        S.LastCustomTargetData = {Part = lvPart, Position = lvPart.Position}
                    end
                end
                if lvPart and lvPart.Parent then
                    local screenPoint, onScreen = Camera:WorldToViewportPoint(lvPart.Position)
                    if onScreen and IsVisibleCachedWrapper(CT.Instance, lvPart.Name, cachedIgnoreList) then
                        TWP = lvPart.Position + (lvPart.AssemblyLinearVelocity * PA)
                    end
                end
            else
                local bn=TP
                if Mode=="Legit (Camera)" or Mode=="Advanced Legit (Mouse)" then
                    bn=isM and (CT.Instance:FindFirstChild("Torso") and "Torso" or "UpperTorso") or "Head"
                    if S.RandomizeHitboxEnabled then local opts={"Head","UpperTorso","LowerTorso"};bn=opts[math.random(1,#opts)] end
                end
                local bone=CT.Instance:FindFirstChild(bn) or CT.Root
                if bone then
                    local rawPos = bone.Position + (bone.AssemblyLinearVelocity * PA)
                    if S.HumanizedAimEnabled and (Mode == "Legit (Camera)" or Mode == "Advanced Legit (Mouse)") then
                        -- 1. Hitbox Volume Surface Drift: wander naturally within bone boundaries
                        if S.HitboxOffsetDrift then
                            local now = tick()
                            if CT.Instance ~= lastTrackedTargetChar or (now - lastDriftPickTime) > 0.7 then
                                lastDriftPickTime = now
                                if bn == "Head" then
                                    targetHitboxDrift = Vector3.new((math.random() - 0.5) * 0.45, (math.random() - 0.5) * 0.35, (math.random() - 0.5) * 0.45)
                                elseif bn:find("Torso") then
                                    targetHitboxDrift = Vector3.new((math.random() - 0.5) * 0.8, (math.random() - 0.5) * 0.9, (math.random() - 0.5) * 0.8)
                                else
                                    targetHitboxDrift = Vector3.new((math.random() - 0.5) * 0.35, (math.random() - 0.5) * 0.35, (math.random() - 0.5) * 0.35)
                                end
                            end
                            currentHitboxDrift = currentHitboxDrift:Lerp(targetHitboxDrift, math.clamp(deltaTime * 3.5, 0.05, 1))
                            rawPos = rawPos + currentHitboxDrift
                        end

                        -- 2. Target Inertia Tracking: dampen rapid strafing direction flips (AD-AD spam)
                        if S.TargetInertiaTracking then
                            if CT.Instance ~= lastTrackedTargetChar or not smoothedAimPos then
                                smoothedAimPos = rawPos
                            else
                                local reactRate = S.TargetReactionRate or 14
                                smoothedAimPos = smoothedAimPos:Lerp(rawPos, math.clamp(deltaTime * reactRate, 0.05, 1))
                            end
                            TWP = smoothedAimPos
                        else
                            TWP = rawPos
                        end
                    else
                        TWP = rawPos
                    end
                    lastTrackedTargetChar = CT.Instance
                end
            end
            if TWP and S.WallCheck and TP~="Visible On Screen" then
                local ti={}; for _,v in ipairs(cachedIgnoreList) do table.insert(ti,v) end; table.insert(ti,CT.Instance)
                local isVisible = IsVisibleCachedWrapper(CT.Instance,S.ActivePartName,ti)
                if not isVisible then
                    if S.CoverAnticipationEnabled and CT and CT.Instance then
                        local nowHold = tick()
                        if not S._CoverHoldData or S._CoverHoldData.target ~= CT.Instance then
                            S._CoverHoldData = { target = CT.Instance, startTime = nowHold, lastPos = TWP }
                        end
                        local holdTime = nowHold - S._CoverHoldData.startTime
                        local maxHold = S.CoverAnticipationDuration or 0.8
                        if holdTime <= maxHold then
                            TWP = S._CoverHoldData.lastPos
                            S._IsHoldingCover = true
                        else
                            S._CoverHoldData = nil
                            S._IsHoldingCover = false
                            TWP = nil
                        end
                    else
                        TWP = nil
                        S._IsHoldingCover = false
                    end
                else
                    S._CoverHoldData = nil
                    S._IsHoldingCover = false
                end
            else
                S._IsHoldingCover = false
            end
            -- v2.1.0: Silent Aim — only block MOUSE movement (mousemoverel/abs).
            -- Camera CFrame writes still happen so the engine doesn't freeze the camera.
            -- The __index/__namecall hooks handle actual bullet/raycast redirection.

            -- Expert Instincts: update last-known-pos each frame while attacker is visible,
            -- then fall back to it when attacker hides (TWP == nil but instincts still active).
            if S._ExpertInstinctsActive then
                if tick() >= (S._ExpertInstinctsExpiry or 0) then
                    S._ExpertInstinctsActive = false
                    S._ExpertInstinctsAttacker = nil
                    S._ExpertInstinctsTargetChar = nil
                    if S._PrevCameraMode then
                        pcall(function() Player.CameraMode = S._PrevCameraMode end)
                        S._PrevCameraMode = nil
                    end
                else
                    local aChar = S._ExpertInstinctsTargetChar
                    if aChar then
                        local liveRoot = aChar:FindFirstChild("HumanoidRootPart")
                        local livePart = (S.TargetPart and aChar:FindFirstChild(S.TargetPart)) or aChar:FindFirstChild("Head") or liveRoot
                        if livePart then
                            S._ExpertInstinctsLastKnownPos = livePart.Position
                        end
                    end
                    if TWP == nil and S._ExpertInstinctsLastKnownPos then
                        TWP = S._ExpertInstinctsLastKnownPos
                    end
                end
            end

            if TWP then
                local tcf=CFrame.new(Camera.CFrame.Position,TWP)
                local sp,os=Camera:WorldToViewportPoint(TWP)
                local tsp=os and ApplyScreenCalibration(Vector2.new(sp.X,sp.Y)) or nil
                local Sm=S.Smoothness
                local instinctAlpha = nil
                if S._ExpertInstinctsActive then
                    if tick() < (S._ExpertInstinctsExpiry or 0) then
                        local intensity  = math.clamp(S.ExpertInstinctsIntensity or 60, 0, 100)
                        local iMode      = S.InstinctsMode or "Blatant"

                        if iMode == "Blatant" then
                            -- Blatant: direct CFrame lerp. 100 = instant snap; 0 = very smooth.
                            -- Map intensity 0-100 → alpha 0.02-1.0 (never quite 0 so it always moves)
                            if intensity >= 100 then
                                Camera.CFrame = tcf
                                instinctAlpha = 1
                            else
                                local alpha = math.clamp(intensity / 100, 0.02, 0.98)
                                Camera.CFrame = Camera.CFrame:Lerp(tcf, alpha)
                                instinctAlpha = alpha
                            end
                        else
                            -- Legit: humanized smoothstep lerp matching the aimbot legit pipeline.
                            -- intensity 0-100 acts as a speed multiplier on top of the aimbot smoothness.
                            local Sm = math.max(0.01, S.Smoothness or 0.5)
                            local speedMult = 0.15 + (intensity / 100) * 2.5  -- 0.15x at 0, 2.65x at 100
                            local sp2, os2 = Camera:WorldToViewportPoint(TWP)
                            local tsp2 = os2 and ApplyScreenCalibration(Vector2.new(sp2.X, sp2.Y)) or nil
                            local screenCenter = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
                            local diff = tsp2 and (tsp2 - screenCenter) or Vector2.new(0, 0)
                            local pixDist = diff.Magnitude
                            local ease = math.clamp(pixDist / 140, 0.06, 1.0)
                            local alpha = math.clamp(deltaTime * (5.5 / Sm) * ease * speedMult, 0.002, 0.92)
                            Camera.CFrame = Camera.CFrame:Lerp(tcf, alpha)
                            instinctAlpha = alpha
                        end
                    else
                        S._ExpertInstinctsActive = false
                        S._ExpertInstinctsAttacker = nil
                        S._ExpertInstinctsTargetChar = nil
                        if S._PrevCameraMode then
                            pcall(function() Player.CameraMode = S._PrevCameraMode end)
                            S._PrevCameraMode = nil
                        end
                    end
                end
                if Mode=="Legit (Camera)" then
                    if S.HumanizedAimEnabled and tsp then
                        local screenCenter = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
                        local diff = tsp - screenCenter
                        local dist = diff.Magnitude
                        local deadzone = S.AimDeadzoneRadius or 6

                        -- Target Deadzone Slack: relaxes pull force when crosshair is already resting on target
                        local deadzoneFactor = (dist <= deadzone) and math.clamp(dist / math.max(1, deadzone), 0, 1) or 1.0

                        -- Wrist Arc Curvature: natural curved trajectory
                        local curveFactor = S.AimPathCurvature or 0.45
                        local perp = Vector2.new(-diff.Y, diff.X)
                        if perp.Magnitude > 0.001 then perp = perp.Unit else perp = Vector2.new(0, 0) end
                        local progress = math.clamp(dist / 220, 0, 1) * math.clamp((450 - dist) / 220, 0, 1)
                        local arcOffset = perp * (dist * 0.16 * curveFactor * progress)

                        -- Physiological Muscle Tremor & Sway
                        local tremor = (S.HumanTremorEnabled and GetHumanTremor(deltaTime)) or Vector2.new(0, 0)
                        local tremorAngleY = math.rad(-tremor.X * 0.08)
                        local tremorAngleX = math.rad(tremor.Y * 0.08)

                        -- Natural Smoothstep Ease (acceleration and deceleration curve)
                        local ease = math.clamp(dist / 140, 0.06, 1.0)
                        local alpha = math.clamp(deltaTime * (5.5 / math.max(0.1, Sm)) * ease * deadzoneFactor, 0.002, 0.75)
                        if instinctAlpha then
                            alpha = math.max(alpha, instinctAlpha)
                        end

                        -- Reconstruct curved world point for CFrame interpolation (with screen-space tremor)
                        local curvedScreen = tsp + arcOffset + tremor
                        local curvedRay = Camera:ViewportPointToRay(curvedScreen.X, curvedScreen.Y)
                        local camDist = (TWP - Camera.CFrame.Position).Magnitude
                        local humanAimPoint = curvedRay.Origin + (curvedRay.Direction * camDist)

                        local targetCF = CFrame.new(Camera.CFrame.Position, humanAimPoint) * CFrame.Angles(tremorAngleX, tremorAngleY, 0)
                        Camera.CFrame = Camera.CFrame:Lerp(targetCF, alpha)
                    else
                        local camLerpAlpha = math.clamp(deltaTime*(6/math.max(0.1,Sm)),0.01,1)
                        if instinctAlpha then
                            camLerpAlpha = math.max(camLerpAlpha, instinctAlpha)
                        end
                        Camera.CFrame=Camera.CFrame:Lerp(tcf, camLerpAlpha)
                    end
                elseif Mode=="Advanced Legit (Mouse)" then
                    -- v2.2.5 Humanized dynamics: curved wrist arc + deadzone slack + organic tremor
                    if not S.SilentAimEnabled and tsp then
                        local mp=UserInputService:GetMouseLocation()
                        local diff=tsp-mp; local d2=diff.Magnitude
                        if d2 > 0.5 then
                            local Sx=math.max(0.1, S.SmoothnessX or Sm)
                            local Sy=math.max(0.1, S.SmoothnessY or Sm)
                            if S.HumanizedAimEnabled then
                                local deadzone = S.AimDeadzoneRadius or 6
                                local deadzoneFactor = (d2 <= deadzone) and math.clamp(d2 / math.max(1, deadzone), 0, 1) or 1.0

                                -- Wrist Arc Curvature
                                local curveFactor = S.AimPathCurvature or 0.45
                                local perp = Vector2.new(-diff.Y, diff.X)
                                if perp.Magnitude > 0.001 then perp = perp.Unit else perp = Vector2.new(0, 0) end
                                progress = math.clamp(d2 / 200, 0, 1) * math.clamp((420 - d2) / 200, 0, 1)
                                local arcOffset = perp * (d2 * 0.16 * curveFactor * progress)

                                -- Organic Physiological Tremor
                                local tremor = (S.HumanTremorEnabled and GetHumanTremor(deltaTime)) or Vector2.new(0, 0)

                                -- Natural Ease: smooth acceleration and deceleration
                                local ease = math.clamp(d2 / 140, 0.06, 1.0)
                                local stepX = math.clamp(deltaTime * (20 / Sx) * ease * deadzoneFactor, 0.003, 0.7)
                                local stepY = math.clamp(deltaTime * (20 / Sy) * ease * deadzoneFactor, 0.003, 0.7)
                                if instinctAlpha then
                                    stepX = math.max(stepX, instinctAlpha)
                                    stepY = math.max(stepY, instinctAlpha)
                                end

                                local effectiveDiff = diff + arcOffset
                                local mvX = (effectiveDiff.X * stepX) + (tremor.X * 0.85)
                                local mvY = (effectiveDiff.Y * stepY) + (tremor.Y * 0.85)
                                if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
                                    mousemoverel(mvX, mvY)
                                else
                                    mousemoveabs(mp.X + mvX, mp.Y + mvY)
                                end
                            else
                                local ease=math.clamp(d2/150, 0.05, 1.0)
                                local stepX=math.clamp(deltaTime*(20/Sx)*ease, 0.005, 0.7)
                                local stepY=math.clamp(deltaTime*(20/Sy)*ease, 0.005, 0.7)
                                if instinctAlpha then
                                    stepX = math.max(stepX, instinctAlpha)
                                    stepY = math.max(stepY, instinctAlpha)
                                end
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
                        elseif S.HumanizedAimEnabled and S.HumanTremorEnabled then
                            local tremor = GetHumanTremor(deltaTime) * 0.4
                            if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
                                mousemoverel(tremor.X, tremor.Y)
                            else
                                mousemoveabs(mp.X + tremor.X, mp.Y + tremor.Y)
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
        else
            smoothedAimPos = nil
            lastTrackedTargetChar = nil
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
        local ct2Name = CT2 and CT2.Name
        local isCT2Priority = ct2Name and (
            (table.find(S.PriorityPlayers or {}, ct2Name) ~= nil) or
            (S.IntelPlayers and S.IntelPlayers[ct2Name] ~= nil) or
            (NemesisMemory and NemesisMemory[ct2Name] ~= nil)
        )
        local priorityTriggerAllowed = not S.TriggerbotPriorityOnly or isCT2Priority
        local triggerAllowed = (not wgEnabled or (heldToolClass ~= "Melee")) and not S._IsHoldingCover and priorityTriggerAllowed
        local meleeAllowed   = not wgEnabled or (heldToolClass ~= "Weapon")
        local tbA=S.AutoClickEnabled and CT2~=nil and TargetingEnabled and AimbotActive and canAimWithTool and triggerAllowed
        local mA=MME and eMR and meleeAllowed

        if tbA or mA then
            -- Safe coordinate: ThirdPersonTriggerbot uses CT2.ScreenPos; fall back to mouse location
            -- to avoid nil errors if the target loses visibility on the click frame.
            local coord
            if S.ThirdPersonTriggerbot and CT2 and CT2.ScreenPos then
                coord = CT2.ScreenPos
            end
            if not coord or not coord.X then
                coord = UserInputService:GetMouseLocation()
            end
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
        local ct3Name = CT3 and CT3.Name
        local isCT3Priority = ct3Name and (
            (table.find(S.PriorityPlayers or {}, ct3Name) ~= nil) or
            (S.IntelPlayers and S.IntelPlayers[ct3Name] ~= nil) or
            (NemesisMemory and NemesisMemory[ct3Name] ~= nil)
        )
        local keyPriorityAllowed = not S.TriggerbotPriorityOnly or isCT3Priority
        if S.KeyTriggerbotEnabled and CT3~=nil and TargetingEnabled and AimbotActive and canAimWithTool and keyPriorityAllowed and not S._IsHoldingCover then
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
            
            -- Additional bypass: if the RaycastParams filter explicitly includes the local character
            -- (weapon hit-detection and viewmodel scripts use this pattern), pass through untouched
            -- to prevent camera hitching and silent aim interfering with the weapon's own logic.
            if method == "Raycast" and typeof(args[3]) == "Instance" then
                local rp = args[3]
                local ok3, fdi = pcall(function() return rp.FilterDescendantsInstances end)
                if ok3 and type(fdi) == "table" and Player and Player.Character then
                    for _, inst in ipairs(fdi) do
                        if inst == Player.Character then
                            return oldNamecall(self,...)
                        end
                    end
                end
            end
            
            -- Also ignore if calling script is clearly the camera
            if getcallingscript then
                local cs = getcallingscript()
                if cs and (cs.Name == "CameraModule" or cs.Name == "ZoomController" or cs.Name == "Popper") then
                    return oldNamecall(self,...)
                end
                -- Also bypass raycasts from scripts parented inside the LocalPlayer's character
                -- (FPS viewmodel scripts, weapon animations, etc.) to prevent camera hitching.
                if cs and Player and Player.Character and cs:IsDescendantOf(Player.Character) then
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

-- // ── Feature 24: Repository Update Checker ────────────────────────────── // --
local function FetchRemoteText(url)
    local ok, res = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(res) == "string" and #res > 0 then
        return res
    end
    local req = (type(request) == "function" and request)
        or (type(http_request) == "function" and http_request)
        or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
    if req then
        local ok2, res2 = pcall(function()
            return req({Url = url, Method = "GET"})
        end)
        if ok2 and type(res2) == "table" and res2.Body and #res2.Body > 0 then
            return res2.Body
        end
    end
    return nil
end

local function ParseVersionParts(vStr)
    if not vStr or type(vStr) ~= "string" then return nil end
    local clean = vStr:match("([%d]+%.[%d%.]+)")
    if not clean then return nil end
    local parts = {}
    for num in clean:gmatch("(%d+)") do
        table.insert(parts, tonumber(num) or 0)
    end
    return (#parts >= 2) and parts or nil
end

local function IsVersionNewer(remote, current)
    local rParts = ParseVersionParts(remote)
    local cParts = ParseVersionParts(current)
    if not rParts or not cParts then return false end
    local maxLen = math.max(#rParts, #cParts)
    for i = 1, maxLen do
        local r = rParts[i] or 0
        local c = cParts[i] or 0
        if r > c then return true end
        if r < c then return false end
    end
    return false
end

local function CleanRemoteText(text)
    if not text or type(text) ~= "string" or #text == 0 then return nil end
    local lower = text:lower()
    if lower:find("404") or lower:find("not found") or lower:find("<html") or lower:find("<!doctype") then
        return nil
    end
    return text
end

local lastNotifiedUpdateVer = nil
function S.CheckForUpdates(manual)
    local repoBase = "https://raw.githubusercontent.com/plasmazzm/TASFF/refs/heads/main/"
    local currentVer = S.CurrentVersion or "?"
    local cacheBust = "?t=" .. tostring(tick())

    -- Step 1: Query version.txt
    local remoteVer = nil
    local vText = CleanRemoteText(FetchRemoteText(repoBase .. "version.txt" .. cacheBust))
    if not vText then
        vText = CleanRemoteText(FetchRemoteText(repoBase .. "version.txt"))
    end
    if vText then
        local candidate = vText:match("([%d]+%.[%d%.]+)")
        if candidate and ParseVersionParts(candidate) then
            remoteVer = candidate
        end
    end

    -- Step 2: Fallback query to TASFF_State.lua if version.txt not found or invalid
    if not remoteVer then
        local stateText = CleanRemoteText(FetchRemoteText(repoBase .. "TASFF_State.lua" .. cacheBust))
        if not stateText then
            stateText = CleanRemoteText(FetchRemoteText(repoBase .. "TASFF_State.lua"))
        end
        if stateText then
            local candidate = stateText:match('CurrentVersion%s*=%s*"([^"]+)"')
            if candidate and ParseVersionParts(candidate) then
                remoteVer = candidate
            end
        end
    end

    local isNewer = (remoteVer ~= nil) and IsVersionNewer(remoteVer, currentVer)

    -- Step 3 (SHA Tier): Query the GitHub Commits API to detect any new commit
    -- even when the version string hasn't changed (new toggles, content additions, etc).
    -- Logic: first successful fetch this session sets a per-session baseline SHA without
    -- flagging an update. Subsequent fetches compare against that baseline.
    local commitSHAChanged = false
    local commitApiUrl = "https://api.github.com/repos/plasmazzm/TASFF/commits?per_page=1"
    local commitJson = CleanRemoteText(FetchRemoteText(commitApiUrl .. "&t=" .. tostring(tick())))
    if not commitJson then
        commitJson = CleanRemoteText(FetchRemoteText(commitApiUrl))
    end
    local remoteSHA = nil
    if commitJson then
        remoteSHA = commitJson:match('"sha"%s*:%s*"([%w]+)"')
        if remoteSHA then
            if S._SessionBaselineCommitSHA == nil then
                -- First successful fetch this session: store as baseline, no update
                S._SessionBaselineCommitSHA = remoteSHA
                S._LastKnownCommitSHA = remoteSHA
            elseif S._SessionBaselineCommitSHA ~= remoteSHA then
                -- Remote commit is different from our session baseline: an update has been committed
                commitSHAChanged = true
                S._LastKnownCommitSHA = remoteSHA
            end
        end
    end

    -- If already flagged as available, keep true unless a definitive check proves remote equals baseline
    if not isNewer and not commitSHAChanged and S.UpdateAvailable then
        if remoteSHA and S._SessionBaselineCommitSHA and remoteSHA ~= S._SessionBaselineCommitSHA then
            commitSHAChanged = true
        end
    end

    if isNewer then
        S.UpdateAvailable = true
        S.RemoteVersion = remoteVer
        if S.UpdateStatusDisplay and S.UpdateStatusDisplay.Set then
            pcall(function()
                S.UpdateStatusDisplay:Set({
                    Title = "Update Available: v" .. remoteVer,
                    Content = "A new update has been detected in the repository.\nClick 'Restart Script & Reload Interface' below to apply changes."
                })
            end)
        end
        if manual or (lastNotifiedUpdateVer ~= remoteVer) then
            lastNotifiedUpdateVer = remoteVer
            if S.Notify then
                S.Notify({
                    Title    = "TASFF Update Checker",
                    Content  = "Update available (v" .. remoteVer .. "), restart for it to take changes.",
                    Duration = 8,
                    Image    = "arrow-up-circle"
                })
            end
        end
        return true, remoteVer
    elseif commitSHAChanged then
        -- New commit pushed but version string unchanged (content / feature additions)
        S.UpdateAvailable = true
        if S.UpdateStatusDisplay and S.UpdateStatusDisplay.Set then
            pcall(function()
                S.UpdateStatusDisplay:Set({
                    Title   = "Module Update Detected",
                    Content = "New changes committed to the repository (same version).\nRestart to apply updated modules."
                })
            end)
        end
        if S.Notify then
            S.Notify({
                Title    = "TASFF Update Checker",
                Content  = "Module update detected — new commit pushed. Restart for changes to take effect.",
                Duration = 8,
                Image    = "arrow-up-circle"
            })
        end
        return true, remoteVer or currentVer
    else
        S.UpdateAvailable = false
        if S.UpdateStatusDisplay and S.UpdateStatusDisplay.Set then
            pcall(function()
                S.UpdateStatusDisplay:Set({
                    Title   = "Update Status — Up to Date",
                    Content = "Running TASFF v" .. currentVer .. ".\nRepository is fully in sync."
                })
            end)
        end
        if manual and S.Notify then
            S.Notify({
                Title    = "TASFF Update Checker",
                Content  = "You are up to date! (v" .. currentVer .. ")",
                Duration = 4,
                Image    = "check-circle"
            })
        end
        return false, currentVer
    end
end

-- Periodic Background Update Checker Worker
task.spawn(function()
    task.wait(6)
    while getgenv().TASFF and getgenv().TASFF.Running do
        if S.AutoUpdateCheckerEnabled then
            pcall(function()
                S.CheckForUpdates(false)
            end)
        end
        task.wait(math.clamp(S.UpdateCheckInterval or 180, 30, 3600))
    end
end)

getgenv().TASFF.Cleanup = function()
    pcall(function() hookmetamethod(game,"__index",oldIndex) end)
    pcall(function() hookmetamethod(game,"__namecall",oldNamecall) end)
    if getgenv().TASFF.Drawings then
        for _, d in ipairs(getgenv().TASFF.Drawings) do
            pcall(function()
                if d and d.Frame then d.Frame:Destroy()      -- overlay ScreenGui frame
                elseif d and d.Remove then d:Remove()        -- legacy Drawing API object
                elseif d and d.Destroy then d:Destroy() end
            end)
        end
        table.clear(getgenv().TASFF.Drawings)
    end
    if getgenv().TASFF and getgenv().TASFF.Connections then
        for _, conn in pairs(getgenv().TASFF.Connections) do
            pcall(function() conn:Disconnect() end)
        end
        pcall(function() table.clear(getgenv().TASFF.Connections) end)
    end
    pcall(function() if OverlayGui then OverlayGui:Destroy(); OverlayGui = nil end end)
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
                if child.Name == "TASFF_UI" or child.Name:find("Rayfield") or child.Name:find("Sirius") then
                    pcall(function() child:Destroy() end)
                end
            end
        end)
    end
end

-- [v2.3.0] Key system stub — real HTTP verification wired in obfuscated build
if not S.VerifyKey then
    S.VerifyKey = function(key)
        -- Stub: always returns false in open-source build.
        -- Replace with actual verification endpoint in obfuscated release.
        return false
    end
end
print("[TASFF Core] All function slots registered. Render loop active.")
