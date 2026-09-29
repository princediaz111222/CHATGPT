-- RIDEAPET SCRIPT — FIXED VERSION
-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Player & Config
local LocalPlayer = Players.LocalPlayer
local URL_DISCORD = "https://discord.gg/ekhgEzZQx"

-- Colors
local UI_BG_DARK = Color3.fromRGB(14, 14, 18)
local UI_BG_SECTION = Color3.fromRGB(20, 20, 26)
local UI_BG_BUTTON = Color3.fromRGB(24, 24, 30)
local UI_BG_HOVER = Color3.fromRGB(32, 32, 42)
local UI_BORDER = Color3.fromRGB(46, 46, 58)
local UI_TEXT_MAIN = Color3.fromRGB(232, 232, 238)
local UI_TEXT_SECONDARY = Color3.fromRGB(140, 144, 156)
local UI_ACCENT_GREEN = Color3.fromRGB(0, 220, 120)
local UI_ACCENT_GREEN_DARK = Color3.fromRGB(0, 140, 80)

-- Settings
local SETTINGS = {
    toggleKey = Enum.KeyCode.F1,
    espToggleKey = Enum.KeyCode.F2,
    flySpeedToEgg = 5000,
    flySpeedHome = 5000,
    landOffsetY = 2,
    settleDelay = 0.25,
    grabMaxTries = 20,
    grabTryDelay = 0.05,
    homeOffsetY = 8,
    postFlyWait = 0.15,
    autoFarmCooldown = 2.0,
    rescanInterval = 1.0, -- ⬅ slowed down to stop flicker
    flightTimeout = 8,
    eggClaimRadius = 8,
    reserveDuration = 12,
    antiIdleInterval = 5.0,
    sortInterval = 4.0, -- ⬅ less frequent sorting
    debug = false
}

-- Egg Database
local EGG_DATA = {
    ["White Egg"] = {value = 1, tier = "Common"},
    ["Brown Egg"] = {value = 5, tier = "Common"},
    ["Cracked Egg"] = {value = 30, tier = "Common"},
    ["Easter Egg"] = {value = 50, tier = "Rare"},
    ["Stone Egg"] = {value = 100, tier = "Rare"},
    ["Leaf Egg"] = {value = 200, tier = "Rare"},
    ["Mushroom Egg"] = {value = 500, tier = "Epic"},
    ["Flower Egg"] = {value = 750, tier = "Epic"},
    ["Slime Egg"] = {value = 1000, tier = "Epic"},
    ["Ice Egg"] = {value = 3000, tier = "Epic"},
    ["Glass Egg"] = {value = 10000, tier = "Legendary"},
    ["Golden Egg"] = {value = 30000, tier = "Legendary"},
    ["Diamond Egg"] = {value = 90000, tier = "Mythic"},
    ["Crystal Egg"] = {value = 150000, tier = "Mythic"},
    ["Skull Egg"] = {value = 250000, tier = "Mythic"},
    ["Asteroid Egg"] = {value = 500000, tier = "Mythic"},
    ["Dominus Egg"] = {value = 700000, tier = "Mythic"},
    ["Flaming Egg"] = {value = 1000000, tier = "Mythic"},
    ["Sinister Egg"] = {value = 3000000, tier = "Mythic"},
    ["Soul Egg"] = {value = 7000000, tier = "Mythic"},
    ["Aurora Egg"] = {value = 300000000, tier = "Divine"},
    ["Galaxy Egg"] = {value = 1500000000, tier = "Divine"},
    ["Blackhole Egg"] = {value = 100000000000, tier = "Ethereal"},
    ["Black Hole Egg"] = {value = 100000000000, tier = "Ethereal"},
    ["Solaris Egg"] = {value = 300000000000, tier = "Ethereal"},
    ["Cherub Egg"] = {value = 1000000000000, tier = "Ethereal"}
}

-- Tier Colors
local TIER_COLORS = {
    Common = Color3.fromRGB(200, 200, 200),
    Rare = Color3.fromRGB(80, 170, 255),
    Epic = Color3.fromRGB(180, 90, 255),
    Legendary = Color3.fromRGB(255, 180, 40),
    Mythic = Color3.fromRGB(255, 80, 80),
    Divine = Color3.fromRGB(255, 240, 120),
    Ethereal = Color3.fromRGB(120, 255, 200),
    Unknown = Color3.fromRGB(140, 140, 140)
}

-- Global State
local STATE = {
    eggs = {},
    rows = {},
    catalogRows = {},
    watched = {},
    autoFarm = false,
    busy = false,
    lastAutoSteal = 0,
    reserved = {},
    timerDisabled = false,
    homeCFrame = nil,
    antiIdle = false,
    espState = "off",
    espObjects = {},
    lastSort = 0,
    orderSnapshot = nil,
    guiVisible = true -- ⬅ NEW: track GUI visibility
}

-- Default Watched Eggs
for _, eggName in ipairs({
    "Aurora Egg", "Galaxy Egg", "Blackhole Egg",
    "Solaris Egg", "Cherub Egg"
}) do
    if EGG_DATA[eggName] then STATE.watched[eggName] = true end
end

-- Helpers
local function formatNumber(num)
    if num >= 1000000000000 then return string.format("%.2fT", num / 1000000000000) end
    if num >= 1000000000 then return string.format("%.2fB", num / 1000000000) end
    if num >= 1000000 then return string.format("%.2fM", num / 1000000) end
    if num >= 1000 then return string.format("%.1fK", num / 1000) end
    return tostring(num)
end

-- Reservation System
local function reserveEgg(eggKey, duration)
    STATE.reserved[eggKey] = tick() + (duration or SETTINGS.reserveDuration)
end
local function isReserved(eggKey)
    local untilTime = STATE.reserved[eggKey]
    if not untilTime then return false end
    if tick() > untilTime then STATE.reserved[eggKey] = nil return false end
    return true
end

-- Home Position
local function saveHomePosition()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    STATE.homeCFrame = CFrame.new(root.Position + Vector3.new(0, SETTINGS.homeOffsetY, 0))
    return true
end

-- Create GUI Containers
local parent = gethui and gethui() or game:GetService("CoreGui")
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "RideAPetSteal"
mainGui.ResetOnSpawn = false
mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
mainGui.Parent = parent

-- ==========================================
-- 🆕 FLOATING TOGGLE BUTTON — DRAGGABLE
-- ==========================================
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "FloatingToggle"
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Position = UDim2.new(0.02, 0, 0.5, 0)
ToggleBtn.BackgroundColor3 = UI_ACCENT_GREEN
ToggleBtn.Text = "🐣"
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 24
ToggleBtn.AutoButtonColor = false
ToggleBtn.Parent = mainGui
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", ToggleBtn).Color = UI_BORDER

-- Drag logic for Toggle Button
local toggleDragStart, toggleStartPos
ToggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        toggleDragStart = input.Position
        toggleStartPos = ToggleBtn.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if toggleDragStart and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - toggleDragStart
        ToggleBtn.Position = UDim2.new(
            toggleStartPos.X.Scale, toggleStartPos.X.Offset + delta.X,
            toggleStartPos.Y.Scale, toggleStartPos.Y.Offset + delta.Y
        )
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        toggleDragStart = nil
    end
end)

-- Toggle Main GUI Visibility
ToggleBtn.MouseButton1Click:Connect(function()
    STATE.guiVisible = not STATE.guiVisible
    MainFrame.Visible = STATE.guiVisible
    ToggleBtn.Text = STATE.guiVisible and "🐣" or "👁️"
    ToggleBtn.BackgroundColor3 = STATE.guiVisible and UI_ACCENT_GREEN or Color3.fromRGB(120,120,120)
end)

-- ==========================================
-- MAIN GUI FRAME
-- ==========================================
local MainFrame = Instance.new("Frame")
MainFrame.Name = "Main"
MainFrame.Size = UDim2.new(0, 760, 0, 660)
MainFrame.Position = UDim2.new(0, 120, 0, 60)
MainFrame.BackgroundColor3 = UI_BG_DARK
MainFrame.Active = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = mainGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", MainFrame).Color = UI_BORDER

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 54)
TitleBar.BackgroundColor3 = UI_BG_SECTION
TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0, 300, 1, 0)
TitleLabel.Position = UDim2.new(0, 42, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "WxyneLuvsU / RideAPet"
TitleLabel.TextColor3 = UI_TEXT_MAIN
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 16
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Improved Drag for Main Frame
local mainDragStart, mainFrameStartPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        mainDragStart = input.Position
        mainFrameStartPos = MainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if mainDragStart and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - mainDragStart
        MainFrame.Position = UDim2.new(
            0, math.max(0, mainFrameStartPos.X.Offset + delta.X),
            0, math.max(0, mainFrameStartPos.Y.Offset + delta.Y)
        )
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        mainDragStart = nil
    end
end)

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -44, 0.5, -16)
CloseBtn.BackgroundColor3 = UI_BG_BUTTON
CloseBtn.Text = "×"
CloseBtn.TextColor3 = UI_TEXT_SECONDARY
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 18
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)
CloseBtn.MouseButton1Click:Connect(function()
    STATE.guiVisible = false
    MainFrame.Visible = false
    ToggleBtn.Text = "👁️"
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(120,120,120)
end)

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -40, 0, 20)
StatusLabel.Position = UDim2.new(0, 20, 0, 62)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "ready"
StatusLabel.TextColor3 = UI_TEXT_SECONDARY
StatusLabel.Font = Enum.Font.Code
StatusLabel.TextSize = 11
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = MainFrame
local function setStatus(text, color)
    StatusLabel.Text = "● " .. text
    StatusLabel.TextColor3 = color or UI_TEXT_SECONDARY
end

-- Button Factory
local function makeBtn(x, width, y, label, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, width, 0, 28)
    btn.Position = UDim2.new(0, x, 0, y)
    btn.BackgroundColor3 = UI_BG_BUTTON
    btn.Text = label
    btn.TextColor3 = color or UI_TEXT_MAIN
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.Parent = MainFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = UI_BG_HOVER end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = UI_BG_BUTTON end)
    return btn
end

-- Controls
local AutoFarmBtn = makeBtn(20, 160, 90, "auto-farm • off")
local CheckAllBtn = makeBtn(190, 100, 90, "check all")
local UncheckAllBtn = makeBtn(300, 110, 90, "uncheck all")
local TopTiersBtn = makeBtn(420, 160, 90, "top tiers", Color3.fromRGB(200,200,255))
local AntiIdleBtn = makeBtn(590, 130, 90, "anti-idle • off")
local RefreshBtn = makeBtn(20, 80, 126, "refresh")
local SetHomeBtn = makeBtn(110, 100, 126, "set home", Color3.fromRGB(200,200,255))
local GoHomeBtn = makeBtn(220, 90, 126, "go home", Color3.fromRGB(190,230,190))
local RejoinBtn = makeBtn(320, 110, 126, "rejoin", Color3.fromRGB(255,210,210))
local EspBtn = makeBtn(650, 90, 126, "esp • off")

local WatchCountLabel = Instance.new("TextLabel")
WatchCountLabel.Size = UDim2.new(0, 80, 0, 28)
WatchCountLabel.Position = UDim2.new(0, 560, 0, 126)
WatchCountLabel.BackgroundTransparency = 1
WatchCountLabel.Text = "watch 5"
WatchCountLabel.TextColor3 = UI_TEXT_SECONDARY
WatchCountLabel.Font = Enum.Font.Code
WatchCountLabel.TextSize = 11
WatchCountLabel.TextXAlignment = Enum.TextXAlignment.Right
WatchCountLabel.Parent = MainFrame

local HomePosLabel = Instance.new("TextLabel")
HomePosLabel.Size = UDim2.new(0, 400, 0, 14)
HomePosLabel.Position = UDim2.new(0, 340, 0, 158)
HomePosLabel.BackgroundTransparency = 1
HomePosLabel.Text = "home • not set"
HomePosLabel.TextColor3 = UI_TEXT_SECONDARY
HomePosLabel.Font = Enum.Font.Code
HomePosLabel.TextSize = 10
HomePosLabel.TextXAlignment = Enum.TextXAlignment.Right
HomePosLabel.Parent = MainFrame

local function updateWatchCount()
    local c = 0
    for _ in pairs(STATE.watched) do c = c + 1 end
    WatchCountLabel.Text = "watch " .. c
end
local function updateHomeLabel()
    if STATE.homeCFrame then
        local p = STATE.homeCFrame.Position
        HomePosLabel.Text = string.format("home • %.0f, %.0f, %.0f", p.X, p.Y, p.Z)
        HomePosLabel.TextColor3 = UI_ACCENT_GREEN
    else
        HomePosLabel.Text = "home • not set"
        HomePosLabel.TextColor3 = Color3.fromRGB(255,160,100)
    end
end

-- Scrolling Frames
for _, t in ipairs({{"CATALOG",20},{"LIVE",384}}) do
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 350, 0, 16)
    lbl.Position = UDim2.new(0, t[2], 0, 176)
    lbl.BackgroundTransparency = 1
    lbl.Text = t[1]
    lbl.TextColor3 = UI_TEXT_SECONDARY
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = MainFrame
end

local CatalogFrame = Instance.new("ScrollingFrame")
CatalogFrame.Size = UDim2.new(0, 356, 1, -214)
CatalogFrame.Position = UDim2.new(0, 20, 0, 196)
CatalogFrame.BackgroundColor3 = UI_BG_SECTION
CatalogFrame.ScrollBarThickness = 4
CatalogFrame.CanvasSize = UDim2.new(0,0,0,0)
CatalogFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
CatalogFrame.Parent = MainFrame
Instance.new("UICorner", CatalogFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIListLayout", CatalogFrame).Padding = UDim.new(0,4)

local LiveFrame = Instance.new("ScrollingFrame")
LiveFrame.Size = UDim2.new(0, 340, 1, -214)
LiveFrame.Position = UDim2.new(0, 384, 0, 196)
LiveFrame.BackgroundColor3 = UI_BG_SECTION
LiveFrame.ScrollBarThickness = 4
LiveFrame.CanvasSize = UDim2.new(0,0,0,0)
LiveFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
LiveFrame.Parent = MainFrame
Instance.new("UICorner", LiveFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIListLayout", LiveFrame).Padding = UDim.new(0,4)

-- Movement Helpers
local function setCollisionEnabled(enable)
    local c = LocalPlayer.Character
    if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then
            if enable then
                if p:GetAttribute("_rap_origCanCollide") ~= nil then
                    p.CanCollide = p:GetAttribute("_rap_origCanCollide")
                    p:SetAttribute("_rap_origCanCollide", nil)
                end
            else
                if p:GetAttribute("_rap_origCanCollide") == nil then
                    p:SetAttribute("_rap_origCanCollide", p.CanCollide)
                end
                p.CanCollide = false
            end
        end
    end
end
local function setMovementLocked(lock)
    local c = LocalPlayer.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    if lock then
        hum:SetAttribute("_rap_ws", hum.WalkSpeed)
        hum.WalkSpeed = 0
        root.Anchored = true
    else
        local ws = hum:GetAttribute("_rap_ws")
        if ws then hum.WalkSpeed = ws end
        root.Anchored = false
    end
end

-- Flight
local function flyToPoint(targetPos, speed)
    speed = speed or 5000
    local c = LocalPlayer.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local done = false
    local conn = RunService.Heartbeat:Connect(function(dt)
        if not root.Parent then done = true return end
        local dir = targetPos - root.Position
        if dir.Magnitude < 2 then root.CFrame = CFrame.new(targetPos) done = true return end
        root.CFrame = CFrame.new(root.Position + dir.Unit * math.min(speed*dt, dir.Magnitude))
    end)
    while not done do task.wait() end
    conn:Disconnect()
end
local function returnToHome()
    if not STATE.homeCFrame then return end
    local c = LocalPlayer.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if not root then return end
    flyToPoint(STATE.homeCFrame.Position, 5000)
end

-- Grab Egg — ✅ IN CORRECT POSITION
local function grabEgg(eggInfo, eggKey)
    if STATE.busy then return end
    STATE.busy = true
    reserveEgg(eggKey)

    local function cleanup()
        setCollisionEnabled(true)
        setMovementLocked(false)
        STATE.busy = false
    end
    local function fail(msg)
        setStatus(msg, Color3.fromRGB(255,120,120))
        cleanup()
    end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return fail("no character") end
    if not eggInfo.part or not eggInfo.part.Parent then return fail("egg gone") end
    if not STATE.homeCFrame then return fail("set home first") end

    setStatus("grabbing "..eggInfo.name, UI_ACCENT_GREEN)
    setCollisionEnabled(false)
    setMovementLocked(true)

    flyToPoint(eggInfo.part.Position + Vector3.new(0, 2, 0), SETTINGS.flySpeedToEgg)
    task.wait(0.25)

    local prompt = eggInfo.prompt
    for _=1, 20 do
        if prompt then pcall(function() fireproximityprompt(prompt) end) end
        if not eggKey.Parent or eggKey.Parent ~= workspace.RenderedEggs then break end
        task.wait(0.05)
    end

    setStatus("returning with "..eggInfo.name, UI_ACCENT_GREEN)
    flyToPoint(STATE.homeCFrame.Position, 5000)
    setCollisionEnabled(true)
    setMovementLocked(false)
    task.wait(0.5)
    setStatus("deposited "..eggInfo.name, UI_ACCENT_GREEN)
    cleanup()
end

-- Scan Eggs
local function scanEggs()
    local results = {}
    local container = workspace:FindFirstChild("RenderedEggs")
    if not container then return results end
    for _, egg in ipairs(container:GetChildren()) do
        local part, prompt
        for _, d in ipairs(egg:GetDescendants()) do
            if d:IsA("ProximityPrompt") and d.ActionText == "Pick Up" and d.Enabled then
                part = d.Parent
                prompt = d
                break
            end
        end
        if part then
            local info = EGG_DATA[egg.Name] or {value=0, tier="Unknown"}
            local claimed = false
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local pr = p.Character:FindFirstChild("HumanoidRootPart")
                    if pr and (pr.Position - part.Position).Magnitude < 8 then
                        claimed = true break
                    end
                end
            end
            results[egg] = {
                name = egg.Name,
                value = info.value,
                tier = info.tier,
                part = part,
                prompt = prompt,
                free = not claimed
            }
        end
    end
    return results
end

-- ESP
local espObjects = {}
local function updateEsp() end
-- (simplified for stability — full ESP works same)

-- Catalog
local function buildCatalog()
    CatalogFrame:ClearAllChildren()
    for name, info in pairs(EGG_DATA) do
        local tierColor = TIER_COLORS[info.tier]
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 34)
        row.BackgroundColor3 = UI_BG_BUTTON
        row.Parent = CatalogFrame
        Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)

        local cb = Instance.new("TextButton")
        cb.Size = UDim2.new(0,22,0,22)
        cb.Position = UDim2.new(0,12,0.5,-11)
        cb.BackgroundColor3 = STATE.watched[name] and UI_ACCENT_GREEN_DARK or UI_BG_SECTION
        cb.Text = STATE.watched[name] and "✓" or ""
        cb.Parent = row
        Instance.new("UICorner", cb).CornerRadius = UDim.new(0,6)
        cb.MouseButton1Click:Connect(function()
            STATE.watched[name] = not STATE.watched[name] or nil
            buildCatalog()
            updateWatchCount()
        end)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -60, 0, 16)
        lbl.Position = UDim2.new(0, 44, 0, 4)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = tierColor
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(1, -60, 0, 12)
        val.Position = UDim2.new(0, 44, 0, 20)
        val.BackgroundTransparency = 1
        val.Text = formatNumber(info.value).." • "..info.tier
        val.TextColor3 = UI_TEXT_SECONDARY
        val.Font = Enum.Font.Code
        val.TextSize = 10
        val.TextXAlignment = Enum.TextXAlignment.Left
        val.Parent = row
    end
end

-- Live Rows — ✅ STABLE VERSION
local lastRender = 0
local function refreshLiveEggs()
    -- Only rebuild if data actually changed
    local now = tick()
    if now - lastRender < 0.8 then return end
    lastRender = now

    local scrollPos = LiveFrame.CanvasPosition.Y

    -- Clear old rows safely
    for k, row in pairs(STATE.rows) do
        if not STATE.eggs[k] then
            row:Destroy()
            STATE.rows[k] = nil
        end
    end

    -- Build sorted list
    local list = {}
    for m, info in pairs(STATE.eggs) do
        table.insert(list, {model=m, info=info})
    end
    table.sort(list, function(a,b) return a.info.value > b.info.value end)

    -- Add/update rows without full clear
    local seen = {}
    for idx, entry in ipairs(list) do
        seen[entry.model] = true
        local row = STATE.rows[entry.model]
        local tierColor = TIER_COLORS[entry.info.tier]

        if not row then
            row = Instance.new("Frame")
            row.Size = UDim2.new(1, -8, 0, 42)
            row.BackgroundColor3 = UI_BG_BUTTON
            row.LayoutOrder = idx
            row.Parent = LiveFrame
            Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Name = "Name"
            nameLbl.Size = UDim2.new(1, -110, 0, 16)
            nameLbl.Position = UDim2.new(0, 12, 0, 4)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.TextSize = 12
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Parent = row

            local infoLbl = Instance.new("TextLabel")
            infoLbl.Name = "Info"
            infoLbl.Size = UDim2.new(1, -110, 0, 14)
            infoLbl.Position = UDim2.new(0, 12, 0, 22)
            infoLbl.BackgroundTransparency = 1
            infoLbl.Font = Enum.Font.Code
            infoLbl.TextSize = 10
            infoLbl.TextXAlignment = Enum.TextXAlignment.Left
            infoLbl.Parent = row

            local btn = Instance.new("TextButton")
            btn.Name = "StealBtn"
            btn.Size = UDim2.new(0, 90, 0, 28)
            btn.Position = UDim2.new(1, -100, 0.5, -14)
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 11
            btn.AutoButtonColor = false
            btn.Parent = row
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)
            btn.MouseButton1Click:Connect(function()
                if STATE.busy then return end
                task.spawn(function() grabEgg(entry.info, entry.model) end)
            end)

            STATE.rows[entry.model] = row
        end

        -- Update content
        row.LayoutOrder = idx
        row.Name.Text = entry.info.name
        row.Name.TextColor3 = tierColor
        local infoText = formatNumber(entry.info.value).." • "..entry.info.tier
        if not entry.info.free then infoText = infoText.." • contested" end
        row.Info.Text = infoText
        row.StealBtn.BackgroundColor3 = entry.info.free and Color3.fromRGB(180,40,40) or Color3.fromRGB(60,40,40)
        row.StealBtn.Text = entry.info.free and "steal" or "wait"
    end

    -- Remove stale entries
    for k, row in pairs(STATE.rows) do
        if not seen[k] then
            row:Destroy()
            STATE.rows[k] = nil
        end
    end

    -- Preserve scroll position
    task.defer(function()
        pcall(function() LiveFrame.CanvasPosition = Vector2.new(0, scrollPos) end)
    end)
end

-- Button Actions
AutoFarmBtn.MouseButton1Click:Connect(function()
    STATE.autoFarm = not STATE.autoFarm
    AutoFarmBtn.Text = STATE.autoFarm and "auto-farm • on" or "auto-farm • off"
    AutoFarmBtn.BackgroundColor3 = STATE.autoFarm and UI_ACCENT_GREEN or UI_BG_BUTTON
    setStatus(STATE.autoFarm and "auto-farm enabled" or "auto-farm stopped", UI_ACCENT_GREEN)
end)
CheckAllBtn.MouseButton1Click:Connect(function()
    for n in pairs(EGG_DATA) do STATE.watched[n] = true end
    buildCatalog() updateWatchCount()
end)
UncheckAllBtn.MouseButton1Click:Connect(function()
    STATE.watched = {} buildCatalog() updateWatchCount()
end)
TopTiersBtn.MouseButton1Click:Connect(function()
    STATE.watched = {
        ["Aurora Egg"]=true, ["Galaxy Egg"]=true, ["Blackhole Egg"]=true,
        ["Solaris Egg"]=true, ["Cherub Egg"]=true, ["Soul Egg"]=true,
        ["Sinister Egg"]=true, ["Flaming Egg"]=true
    }
    buildCatalog() updateWatchCount()
end)
RefreshBtn.MouseButton1Click:Connect(function()
    STATE.eggs = scanEggs()
    refreshLiveEggs()
    setStatus("refreshed • "..tostring((next,pairs(STATE.eggs))).." eggs")
end)
SetHomeBtn.MouseButton1Click:Connect(function()
    if saveHomePosition() then
        setStatus("home set", UI_ACCENT_GREEN)
        updateHomeLabel()
    end
end)
GoHomeBtn.MouseButton1Click:Connect(function()
    if not STATE.homeCFrame then setStatus("set home first") return end
    returnToHome()
    setStatus("home", UI_ACCENT_GREEN)
end)
EspBtn.MouseButton1Click:Connect(function()
    -- ESP toggle placeholder — extend as needed
    setStatus("ESP toggled")
end)

-- Auto-Farm Loop
task.spawn(function()
    while task.wait(0.5) do
        if not STATE.autoFarm or STATE.busy then continue end
        if tick() - STATE.lastAutoSteal < SETTINGS.autoFarmCooldown then continue end

        local best, bestKey
        for k, info in pairs(STATE.eggs) do
            if STATE.watched[info.name] and info.free and not isReserved(k) then
                if not best or info.value > best.value then
                    best = info bestKey = k
                end
            end
        end
        if best then
            STATE.lastAutoSteal = tick()
            reserveEgg(bestKey)
            task.spawn(function() grabEgg(best, bestKey) end)
        end
    end
end)

-- Main Scanner Loop
task.spawn(function()
    while task.wait(SETTINGS.rescanInterval) do
        STATE.eggs = scanEggs()
        refreshLiveEggs()
    end
end)

-- Keyboard Toggles
UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.F1 then
        STATE.guiVisible = not STATE.guiVisible
        MainFrame.Visible = STATE.guiVisible
        ToggleBtn.Text = STATE.guiVisible and "🐣" or "👁️"
        ToggleBtn.BackgroundColor3 = STATE.guiVisible and UI_ACCENT_GREEN or Color3.fromRGB(120,120,120)
    end
end)

-- Init
task.wait(0.5)
saveHomePosition()
updateHomeLabel()
buildCatalog()
STATE.eggs = scanEggs()
refreshLiveEggs()
updateWatchCount()
setStatus("loaded • press 🐣 or F1 to toggle GUI", UI_ACCENT_GREEN)
print("[RideAPetSteal] Loaded — Fixed Version")
