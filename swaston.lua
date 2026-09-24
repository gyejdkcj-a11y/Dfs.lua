-- Defusal Universal Cheat | Rayfield UI
-- ESP + Silent Aim + Wallhack (Chams)

local Rayfield = loadstring(game:HttpGet(
    "https://sirius.menu/rayfield"
))()

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ──────────────────────────────────────────────────────────────
-- STATE
-- ──────────────────────────────────────────────────────────────
local cfg = {
    esp_enabled    = true,
    aim_enabled    = false,
    aim_fov        = 150,
    aim_smoothness = 0.15,    -- 0.0 = instant, 1.0 = very slow
    aim_part       = "Head",
    wallhack       = true,
    esp_boxes      = true,
    esp_names      = true,
    esp_distance   = true,
    esp_tracers    = false,
    esp_skeletons  = true,
    team_check     = true,
    esp_color_enemy = Color3.fromRGB(255, 60, 60),
    esp_color_team  = Color3.fromRGB(60, 255, 120),
    max_distance   = 1000,
}

local drawings   = {}  -- [Player] = { box, name, dist, lines[] }
local highlights = {}  -- [Player] = Highlight instance
local connections = {}

-- ──────────────────────────────────────────────────────────────
-- UTIL
-- ──────────────────────────────────────────────────────────────
local function isEnemy(player)
    if not cfg.team_check then return true end
    return player.Team ~= LocalPlayer.Team
end

local function getChar(player)
    return player.Character
end

local function getRootPart(player)
    local c = getChar(player)
    return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso"))
end

local function getHead(player)
    local c = getChar(player)
    return c and c:FindFirstChild("Head")
end

local function getHumanoid(player)
    local c = getChar(player)
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function isAlive(player)
    local h = getHumanoid(player)
    return h and h.Health > 0
end

local function worldToViewport(pos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), screenPos.Z, onScreen
end

local function distance(player)
    local root = getRootPart(player)
    local lroot = getRootPart(LocalPlayer)
    if not root or not lroot then return math.huge end
    return (root.Position - lroot.Position).Magnitude
end

-- ──────────────────────────────────────────────────────────────
-- DRAWING HELPERS
-- ──────────────────────────────────────────────────────────────
local function newDrawing(type, props)
    local d = Drawing.new(type)
    for k, v in pairs(props) do d[k] = v end
    return d
end

local function removeDrawings(player)
    local d = drawings[player]
    if not d then return end
    for _, obj in pairs(d) do
        if typeof(obj) == "table" then
            for _, line in pairs(obj) do
                pcall(function() line:Remove() end)
            end
        else
            pcall(function() obj:Remove() end)
        end
    end
    drawings[player] = nil
end

local function removeHighlight(player)
    local h = highlights[player]
    if h then
        h:Destroy()
        highlights[player] = nil
    end
end

-- ──────────────────────────────────────────────────────────────
-- WALLHACK / CHAMS  (Highlight instance per character)
-- ──────────────────────────────────────────────────────────────
local function applyHighlight(player)
    removeHighlight(player)
    if not cfg.wallhack then return end
    local char = getChar(player)
    if not char then return end
    if cfg.team_check and not isEnemy(player) then return end

    local h = Instance.new("Highlight")
    h.Adornee         = char
    h.FillColor        = cfg.esp_color_enemy
    h.FillTransparency = 0.45
    h.OutlineColor     = cfg.esp_color_enemy
    h.OutlineTransparency = 0
    h.DepthMode        = Enum.HighlightDepthMode.AlwaysOnTop  -- сквозь стены
    h.Parent           = char
    highlights[player] = h
end

-- ──────────────────────────────────────────────────────────────
-- ESP SKELETON
-- ──────────────────────────────────────────────────────────────
-- Стандартная R6/R15 иерархия костей для линий
local SKELETON_R6 = {
    {"Head",         "Torso"},
    {"Torso",        "Left Arm"},
    {"Torso",        "Right Arm"},
    {"Torso",        "Left Leg"},
    {"Torso",        "Right Leg"},
}
local SKELETON_R15 = {
    {"Head",             "UpperTorso"},
    {"UpperTorso",       "LowerTorso"},
    {"UpperTorso",       "LeftUpperArm"},
    {"LeftUpperArm",     "LeftLowerArm"},
    {"LeftLowerArm",     "LeftHand"},
    {"UpperTorso",       "RightUpperArm"},
    {"RightUpperArm",    "RightLowerArm"},
    {"RightLowerArm",    "RightHand"},
    {"LowerTorso",       "LeftUpperLeg"},
    {"LeftUpperLeg",     "LeftLowerLeg"},
    {"LeftLowerLeg",     "LeftFoot"},
    {"LowerTorso",       "RightUpperLeg"},
    {"RightUpperLeg",    "RightLowerLeg"},
    {"RightLowerLeg",    "RightFoot"},
}

local function getSkeletonDef(char)
    if char:FindFirstChild("UpperTorso") then
        return SKELETON_R15
    end
    return SKELETON_R6
end

local function buildSkeletonLines(color)
    local lines = {}
    for i = 1, 14 do  -- max R15 bones
        lines[i] = newDrawing("Line", {
            Visible   = false,
            Color     = color,
            Thickness = 1,
        })
    end
    return lines
end

local function updateSkeletonLines(player, lines, color)
    local char = getChar(player)
    if not char or not cfg.esp_skeletons then
        for _, l in ipairs(lines) do l.Visible = false end
        return
    end
    local def = getSkeletonDef(char)
    for i, bone in ipairs(def) do
        local partA = char:FindFirstChild(bone[1])
        local partB = char:FindFirstChild(bone[2])
        local line  = lines[i]
        if line and partA and partB then
            local sA, _, onA = worldToViewport(partA.Position)
            local sB, _, onB = worldToViewport(partB.Position)
            if onA and onB then
                line.From    = sA
                line.To      = sB
                line.Color   = color
                line.Visible = true
            else
                line.Visible = false
            end
        elseif line then
            line.Visible = false
        end
    end
    -- скрыть лишние линии если R6 (меньше костей)
    for i = #def + 1, #lines do
        if lines[i] then lines[i].Visible = false end
    end
end

-- ──────────────────────────────────────────────────────────────
-- ESP BOX + NAME + DISTANCE
-- ──────────────────────────────────────────────────────────────
local function initDrawings(player)
    removeDrawings(player)
    local color = isEnemy(player) and cfg.esp_color_enemy or cfg.esp_color_team

    drawings[player] = {
        box = newDrawing("Square", {
            Visible     = false,
            Color       = color,
            Thickness   = 1.5,
            Filled      = false,
        }),
        name = newDrawing("Text", {
            Visible  = false,
            Color    = Color3.new(1,1,1),
            Size     = 13,
            Center   = true,
            Outline  = true,
        }),
        dist = newDrawing("Text", {
            Visible  = false,
            Color    = Color3.fromRGB(200,200,200),
            Size     = 11,
            Center   = true,
            Outline  = true,
        }),
        tracer = newDrawing("Line", {
            Visible   = false,
            Color     = color,
            Thickness = 1,
        }),
        skeleton = buildSkeletonLines(color),
    }
end

local function updateESP(player)
    local d = drawings[player]
    if not d then return end

    local char = getChar(player)
    local root = getRootPart(player)
    local head = getHead(player)

    local color = isEnemy(player) and cfg.esp_color_enemy or cfg.esp_color_team
    local alive = isAlive(player)
    local dist  = distance(player)

    -- скелет всегда обновляем (внутри проверка флага)
    updateSkeletonLines(player, d.skeleton, color)

    if not cfg.esp_enabled or not char or not root or not head
       or not alive or dist > cfg.max_distance then
        d.box.Visible    = false
        d.name.Visible   = false
        d.dist.Visible   = false
        d.tracer.Visible = false
        return
    end

    -- bounding box через Character:GetBoundingBox
    local cf, size = char:GetBoundingBox()
    local corners = {
        cf * CFrame.new( size.X/2,  size.Y/2, 0),
        cf * CFrame.new(-size.X/2,  size.Y/2, 0),
        cf * CFrame.new( size.X/2, -size.Y/2, 0),
        cf * CFrame.new(-size.X/2, -size.Y/2, 0),
    }

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local allVisible = true

    for _, c in ipairs(corners) do
        local s, _, onScreen = worldToViewport(c.Position)
        if not onScreen then allVisible = false end
        minX = math.min(minX, s.X)
        minY = math.min(minY, s.Y)
        maxX = math.max(maxX, s.X)
        maxY = math.max(maxY, s.Y)
    end

    if not allVisible and dist > 80 then
        -- частично за экраном — скрываем бокс, оставляем имя
        d.box.Visible = false
    else
        d.box.Visible    = cfg.esp_boxes
        d.box.Position   = Vector2.new(minX, minY)
        d.box.Size       = Vector2.new(maxX - minX, maxY - minY)
        d.box.Color      = color
    end

    -- имя над головой
    local headScreen, _, headOn = worldToViewport(head.Position + Vector3.new(0, 0.5, 0))
    d.name.Visible  = cfg.esp_names and headOn
    d.name.Position = Vector2.new(headScreen.X, headScreen.Y - 18)
    d.name.Text     = player.DisplayName
    d.name.Color    = color

    -- дистанция
    d.dist.Visible  = cfg.esp_distance and headOn
    d.dist.Position = Vector2.new(headScreen.X, headScreen.Y - 6)
    d.dist.Text     = string.format("[%.0fm]", dist * 0.0254)  -- studs → метры
    d.dist.Color    = Color3.fromRGB(180, 180, 180)

    -- трейсер
    local viewCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
    local rootScreen, _, rootOn = worldToViewport(root.Position)
    d.tracer.Visible = cfg.esp_tracers and rootOn
    d.tracer.From    = viewCenter
    d.tracer.To      = Vector2.new(rootScreen.X, rootScreen.Y)
    d.tracer.Color   = color
end

-- ──────────────────────────────────────────────────────────────
-- SILENT AIM
local function getBestTarget()
    local best, bestDist = nil, math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isAlive(player) then
            if not cfg.team_check or isEnemy(player) then
                local char = getChar(player)
                local head = char and char:FindFirstChild("Head")
                if head then
                    local screen, depth, onScreen = worldToViewport(head.Position)
                    if onScreen and depth > 0 then
                        local d2 = (screen - center).Magnitude
                        if d2 < cfg.aim_fov and d2 < bestDist then
                            bestDist = d2
                            best     = head
                        end
                    end
                end
            end
        end
    end
    return best
end

local aimConnection
local function startAim()
    if aimConnection then aimConnection:Disconnect() end
    aimConnection = RunService.RenderStepped:Connect(function()
        if not cfg.aim_enabled then return end
        local target = getBestTarget()
        if not target then return end
        local camPos   = Camera.CFrame.Position
        local direction = (target.Position - camPos).Unit
        Camera.CFrame  = Camera.CFrame:Lerp(
            CFrame.new(camPos, camPos + direction),
            cfg.aim_smoothness
        )
    end)
end
-- ──────────────────────────────────────────────────────────────
-- PLAYER LIFECYCLE
-- ──────────────────────────────────────────────────────────────
local function onCharacterAdded(player)
    task.wait(0.5)  -- ждём загрузку персонажа
    applyHighlight(player)
    initDrawings(player)
end

local function onPlayerAdded(player)
    if player == LocalPlayer then return end
    initDrawings(player)
    applyHighlight(player)

    player.CharacterAdded:Connect(function()
        onCharacterAdded(player)
    end)
    if player.Character then
        onCharacterAdded(player)
    end
end

local function onPlayerRemoving(player)
    removeDrawings(player)
    removeHighlight(player)
end

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- главный цикл обновления ESP
connections.espLoop = RunService.RenderStepped:Connect(function()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            updateESP(player)
        end
    end
end)

startAim()

-- ──────────────────────────────────────────────────────────────
-- RAYFIELD UI
-- ──────────────────────────────────────────────────────────────
local Window = Rayfield:CreateWindow({
    Name             = "Defusal Cheat",
    LoadingTitle     = "Loading...",
    LoadingSubtitle  = "universal edition",
    ConfigurationSaving = {
        Enabled  = true,
        FileName = "DefusalCFG",
    },
    KeySystem = false,
})

-- ── TAB: ESP ──────────────────────────────────────────────────
local EspTab = Window:CreateTab("ESP", "eye")

EspTab:CreateToggle({
    Name         = "Enable ESP",
    CurrentValue = cfg.esp_enabled,
    Flag         = "esp_enabled",
    Callback     = function(v) cfg.esp_enabled = v end,
})

EspTab:CreateToggle({
    Name         = "Boxes",
    CurrentValue = cfg.esp_boxes,
    Flag         = "esp_boxes",
    Callback     = function(v) cfg.esp_boxes = v end,
})

EspTab:CreateToggle({
    Name         = "Skeletons",
    CurrentValue = cfg.esp_skeletons,
    Flag         = "esp_skeletons",
    Callback     = function(v) cfg.esp_skeletons = v end,
})

EspTab:CreateToggle({
    Name         = "Names",
    CurrentValue = cfg.esp_names,
    Flag         = "esp_names",
    Callback     = function(v) cfg.esp_names = v end,
})

EspTab:CreateToggle({
    Name         = "Distance",
    CurrentValue = cfg.esp_distance,
    Flag         = "esp_distance",
    Callback     = function(v) cfg.esp_distance = v end,
})

EspTab:CreateToggle({
    Name         = "Tracers",
    CurrentValue = cfg.esp_tracers,
    Flag         = "esp_tracers",
    Callback     = function(v) cfg.esp_tracers = v end,
})

EspTab:CreateSlider({
    Name         = "Max Distance (studs)",
    Range        = {100, 2000},
    Increment    = 50,
    CurrentValue = cfg.max_distance,
    Flag         = "max_distance",
    Callback     = function(v) cfg.max_distance = v end,
})

EspTab:CreateColorPicker({
    Name         = "Enemy Color",
    Color        = cfg.esp_color_enemy,
    Flag         = "enemy_color",
    Callback     = function(v)
        cfg.esp_color_enemy = v
        -- обновить хайлайты
        for player, h in pairs(highlights) do
            if isEnemy(player) then
                h.FillColor    = v
                h.OutlineColor = v
            end
        end
    end,
})

-- ── TAB: Wallhack ─────────────────────────────────────────────
local WallTab = Window:CreateTab("Wallhack", "layers")

WallTab:CreateToggle({
    Name         = "Enable Wallhack (Chams)",
    CurrentValue = cfg.wallhack,
    Flag         = "wallhack",
    Callback     = function(v)
        cfg.wallhack = v
        if v then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    applyHighlight(player)
                end
            end
        else
            for player in pairs(highlights) do
                removeHighlight(player)
            end
        end
    end,
})

WallTab:CreateToggle({
    Name         = "Team Check",
    CurrentValue = cfg.team_check,
    Flag         = "team_check",
    Callback     = function(v)
        cfg.team_check = v
        -- пересоздать хайлайты под новую настройку
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                removeHighlight(player)
                applyHighlight(player)
            end
        end
    end,
})

-- ── TAB: Aimbot ───────────────────────────────────────────────
local AimTab = Window:CreateTab("Aimbot", "crosshair")

AimTab:CreateToggle({
    Name         = "Enable Silent Aim (hold RMB)",
    CurrentValue = cfg.aim_enabled,
    Flag         = "aim_enabled",
    Callback     = function(v) cfg.aim_enabled = v end,
})

AimTab:CreateDropdown({
    Name         = "Aim Part",
    Options      = {"Head", "HumanoidRootPart", "UpperTorso", "Torso"},
    CurrentOption = {cfg.aim_part},
    Flag         = "aim_part",
    Callback     = function(v) cfg.aim_part = v[1] end,
})

AimTab:CreateSlider({
    Name         = "FOV Radius (px)",
    Range        = {30, 500},
    Increment    = 5,
    CurrentValue = cfg.aim_fov,
    Flag         = "aim_fov",
    Callback     = function(v) cfg.aim_fov = v end,
})

AimTab:CreateSlider({
    Name         = "Smoothness",
    Range        = {1, 100},
    Increment    = 1,
    CurrentValue = math.floor(cfg.aim_smoothness * 100),
    Flag         = "aim_smooth",
    Callback     = function(v)
        cfg.aim_smoothness = v / 100
    end,
})

-- FOV circle (Drawing)
local fovCircle = newDrawing("Circle", {
    Visible   = false,
    Radius    = cfg.aim_fov,
    Color     = Color3.fromRGB(255, 255, 255),
    Thickness = 1,
    Filled    = false,
})

AimTab:CreateToggle({
    Name         = "Show FOV Circle",
    CurrentValue = false,
    Flag         = "fov_circle",
    Callback     = function(v) fovCircle.Visible = v end,
})

RunService.RenderStepped:Connect(function()
    fovCircle.Position = Vector2.new(
        Camera.ViewportSize.X / 2,
        Camera.ViewportSize.Y / 2
    )
    fovCircle.Radius = cfg.aim_fov
end)

-- ── TAB: Misc ─────────────────────────────────────────────────
local MiscTab = Window:CreateTab("Misc", "settings")

MiscTab:CreateButton({
    Name     = "Destroy Script",
    Callback = function()
        -- очистка
        for _, player in ipairs(Players:GetPlayers()) do
            removeDrawings(player)
            removeHighlight(player)
        end
        fovCircle:Remove()
        if aimConnection then aimConnection:Disconnect() end
        for _, c in pairs(connections) do
            pcall(function() c:Disconnect() end)
        end
        Rayfield:Destroy()
    end,
})

-- ──────────────────────────────────────────────────────────────
Rayfield:LoadConfiguration()
Rayfield:Notify({
    Title    = "Defusal Cheat",
    Content  = "Loaded — ESP / WH / Silent Aim ready",
    Duration = 4,
    Image    = "check",
})
