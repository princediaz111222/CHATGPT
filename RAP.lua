-- RIDEAPET SCRIPT — FULLY FORMATTED
-- Original code preserved; indentation & organization only

-- SERVICES
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- PLAYER & CONFIGURATION
local LocalPlayer = Players.LocalPlayer
local URL_DISCORD = "https://discord.gg/ekhgEzZQx"

-- COLOR PALETTE
local C_SUCCESS = Color3.fromRGB(0, 255, 136)
local C_PRIMARY = Color3.fromRGB(0, 170, 85)
local C_DARK = Color3.fromRGB(3, 10, 5)
local C_BG = Color3.fromRGB(5, 14, 8)
local C_WARN = Color3.fromRGB(255, 176, 0)
local C_ERROR = Color3.fromRGB(255, 60, 60)

-- SETTINGS
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
    rescanInterval = 0.75,
    flightTimeout = 8,
    eggClaimRadius = 8,
    reserveDuration = 12,
    antiIdleInterval = 5.0,
    sortInterval = 3.0,
    debug = false
}

-- EGG DATABASE
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

-- TIER COLOR MAPPING
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

-- GLOBAL STATE
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
    orderSnapshot = nil
}

-- INITIAL WATCHED EGGS
for _, eggName in ipairs({
    "Aurora Egg", "Galaxy Egg", "Blackhole Egg",
    "Solaris Egg", "Cherub Egg"
}) do
    if EGG_DATA[eggName] then
        STATE.watched[eggName] = true
    end
end

-- ==========================================
-- NETWORK / FILE HELPERS
-- ==========================================
local function fetchUrl(url)
    local success, result = pcall(function()
        return HttpService:GetAsync(url)
    end)
    if success and result then return result end

    if request then
        success, result = pcall(function()
            return request({Url = url, Method = "GET"})
        end)
        if success and result.Body then return result.Body end
    end

    if http_request then
        success, result = pcall(function()
            return http_request({Url = url, Method = "GET"})
        end)
        if success and result.Body then return result.Body end
    end

    if syn and syn.request then
        success, result = pcall(function()
            return syn.request({Url = url, Method = "GET"})
        end)
        if success and result.Body then return result.Body end
    end

    return nil
end


local function copyDiscordLink(uiTextLabel)
    if setclipboard then
        pcall(setclipboard, URL_DISCORD)
        if uiTextLabel then
            uiTextLabel.Text = "// Discord link copied"
            uiTextLabel.TextColor3 = C_PRIMARY
        end
    end
    if request then
        pcall(function() request({Url = URL_DISCORD, Method = "GET"}) end)
    end
end

-- ==========================================
-- FORMATTING HELPERS
-- ==========================================
local function formatNumber(num)
    if num >= 1000000000000.0 then return string.format("%.2fT", num / 1000000000000.0) end
    if num >= 1000000000.0 then return string.format("%.2fB", num / 1000000000.0) end
    if num >= 1000000.0 then return string.format("%.2fM", num / 1000000.0) end
    if num >= 1000.0 then return string.format("%.1fK", num / 1000.0) end
    return tostring(num)
end

local function debugLog(...)
    if SETTINGS.debug then
        print("[steal]", ...)
    end
end

-- ==========================================
-- RESERVATION SYSTEM
-- ==========================================
local function reserveEgg(eggKey, duration)
    STATE.reserved[eggKey] = tick() + (duration or SETTINGS.reserveDuration)
end

local function isReserved(eggKey)
    local reservedUntil = STATE.reserved[eggKey]
    if not reservedUntil then return false end
    if tick() > reservedUntil then
        STATE.reserved[eggKey] = nil
        return false
    end
    return true
end

-- ==========================================
-- HOME POSITION
-- ==========================================
local function saveHomePosition()
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    STATE.homeCFrame = CFrame.new(rootPart.Position + Vector3.new(0, SETTINGS.homeOffsetY, 0))
    return true
end

-- ==========================================
-- ANTI-IDLE
-- ==========================================
local function triggerAntiIdle()
    local VirtualUser = rawget(getfenv(), "VirtualUser") or (getgenv and getgenv().VirtualUser)
    if type(VirtualUser) == "userdata" or type(VirtualUser) == "table" then
        pcall(function() VirtualUser:CaptureController() end)
        pcall(function() VirtualUser:ClickButton2(Vector2.new(0, 0)) end)
        pcall(function() VirtualUser:ClickButton1(Vector2.new(0, 0)) end)
        pcall(function() VirtualUser:SetKeyDown("\r") end)
        pcall(function() VirtualUser:SetKeyUp("\r") end)
        return
    end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightShift, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightShift, false, game)
    end)
end

task.spawn(function()
    while true do
        task.wait(SETTINGS.antiIdleInterval)
        if STATE.antiIdle then
            pcall(triggerAntiIdle)
        end
    end
end)

-- ==========================================
-- TIMER / BREAK DISABLING
-- ==========================================
local breakTimerScript = nil
local originalTimerDisabled = nil
local eggBreakingGui = nil
local originalGuiEnabled = nil

local function disableBreakTimer()
    local characterScripts = LocalPlayer:FindFirstChild("PlayerScripts")
    if characterScripts then
        local gameScript = characterScripts:FindFirstChild("Game")
        if gameScript then
            local eggSpawning = gameScript:FindFirstChild("EggSpawning")
            if eggSpawning then
                breakTimerScript = eggSpawning:FindFirstChild("BreakTimer")
            end
        end
    end
    if not breakTimerScript and characterScripts then
        for _, descendant in ipairs(characterScripts:GetDescendants()) do
            if descendant:IsA("LocalScript") and descendant.Name == "BreakTimer" then
                breakTimerScript = descendant
                break
            end
        end
    end
    if breakTimerScript then
        if originalTimerDisabled == nil then
            originalTimerDisabled = breakTimerScript.Disabled
        end
        pcall(function() breakTimerScript.Disabled = true end)
    end
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        eggBreakingGui = playerGui:FindFirstChild("EggBreaking")
        if eggBreakingGui then
            if originalGuiEnabled == nil then
                originalGuiEnabled = eggBreakingGui.Enabled
            end
            pcall(function() eggBreakingGui.Enabled = false end)
        end
    end
    STATE.timerDisabled = true
    return breakTimerScript ~= nil
end

local function restoreBreakTimer()
    if breakTimerScript then
        pcall(function()
            breakTimerScript.Disabled = originalTimerDisabled or false
        end)
    end
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        eggBreakingGui = playerGui:FindFirstChild("EggBreaking")
        if eggBreakingGui and originalGuiEnabled ~= nil then
            pcall(function() eggBreakingGui.Enabled = originalGuiEnabled end)
        end
    end
    STATE.timerDisabled = false
end

-- ==========================================
-- VALUE PARSING & EGG DETECTION
-- ==========================================
local function parseNumberFromText(text)
    text = text:lower():gsub(",", ""):gsub("%s", "")
    local numStr, suffix = text:match("([%d%.]+)([kmbt]?)")
    if not numStr then return nil end
    local value = tonumber(numStr)
    if not value then return nil end
    if suffix == "k" then value = value * 1000.0
    elseif suffix == "m" then value = value * 1000000.0
    elseif suffix == "b" then value = value * 1000000000.0
    elseif suffix == "t" then value = value * 1000000000000.0 end
    return value
end

local function getEggValueAndTier(eggInstance)
    local info = EGG_DATA[eggInstance.Name]
    if info then
        return info.value, info.tier, "table"
    end
    for _, attrName in ipairs({"Value", "EggValue", "Worth", "Price"}) do
        local value = eggInstance:GetAttribute(attrName)
        if typeof(value) == "number" then
            local tier = eggInstance:GetAttribute("Tier") or eggInstance:GetAttribute("Rarity") or "Unknown"
            return value, tier, "attr:" .. attrName
        end
    end
    for _, descendant in ipairs(eggInstance:GetDescendants()) do
        if (descendant:IsA("NumberValue") or descendant:IsA("IntValue"))
          and descendant.Name:lower():find("value") then
            return descendant.Value, eggInstance:GetAttribute("Tier") or "Unknown", "numvalue:" .. descendant.Name
        end
    end
    for _, descendant in ipairs(eggInstance:GetDescendants()) do
        if descendant:IsA("TextLabel") then
            local parsed = parseNumberFromText(descendant.Text)
            if parsed and parsed > 0 then
                return parsed, eggInstance:GetAttribute("Tier") or "Unknown", "billboard"
            end
        end
    end
    return 0, "Unknown", "none"
end

-- ==========================================
-- UI BUILDING HELPERS
-- ==========================================
local function createMainGui()
    local parent = gethui and gethui() or game:GetService("CoreGui")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RideAPetSteal_" .. tostring(math.random(100000, 999999))
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = parent
    return screenGui
end

local function makeInstance(className, properties, parent)
    local instance = Instance.new(className)
    for prop, value in pairs(properties) do
        instance[prop] = value
    end
    if parent then instance.Parent = parent end
    return instance
end

local mainGui = createMainGui()

-- UI COLORS
local UI_BG_DARK = Color3.fromRGB(14, 14, 18)
local UI_BG_SECTION = Color3.fromRGB(20, 20, 26)
local UI_BG_BUTTON = Color3.fromRGB(24, 24, 30)
local UI_BG_HOVER = Color3.fromRGB(32, 32, 42)
local UI_BORDER = Color3.fromRGB(46, 46, 58)
local UI_TEXT_MAIN = Color3.fromRGB(232, 232, 238)
local UI_TEXT_SECONDARY = Color3.fromRGB(140, 144, 156)
local UI_ACCENT_GREEN = Color3.fromRGB(0, 220, 120)
local UI_ACCENT_GREEN_DARK = Color3.fromRGB(0, 140, 80)

-- MAIN FRAME
local MainFrame = makeInstance("Frame", {
    Name = "Main",
    Size = UDim2.new(0, 760, 0, 660),
    Position = UDim2.new(0, 60, 0, 60),
    BackgroundColor3 = UI_BG_DARK,
    Active = true
}, mainGui)
makeInstance("UICorner", {CornerRadius = UDim.new(0, 12)}, MainFrame)
makeInstance("UIStroke", {Color = UI_BORDER, Thickness = 1, Transparency = 0.3}, MainFrame)

-- TITLE BAR
local TitleBar = makeInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 54),
    BackgroundColor3 = UI_BG_SECTION
}, MainFrame)
makeInstance("UICorner", {CornerRadius = UDim.new(0, 12)}, TitleBar)
makeInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 12),
    Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = UI_BG_SECTION
}, TitleBar)

local StatusIndicator = makeInstance("Frame", {
    Size = UDim2.new(0, 10, 0, 10),
    Position = UDim2.new(0, 20, 0.5, -5),
    BackgroundColor3 = UI_ACCENT_GREEN
}, TitleBar)
makeInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, StatusIndicator)

local TitleLabel = makeInstance("TextLabel", {
    Size = UDim2.new(0, 300, 1, 0),
    Position = UDim2.new(0, 42, 0, 0),
    BackgroundTransparency = 1,
    Text = "WxyneLuvsU",
    TextColor3 = UI_TEXT_MAIN,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold,
    TextSize = 16
}, TitleBar)

local SubtitleLabel = makeInstance("TextLabel", {
    Size = UDim2.new(0, 300, 1, 0),
    Position = UDim2.new(0, 128, 0, 0),
    BackgroundTransparency = 1,
    Text = "/ ride a pet",
    TextColor3 = UI_TEXT_SECONDARY,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.Gotham,
    TextSize = 13
}, TitleBar)

-- CLOSE & MINIMIZE
local CloseButton = makeInstance("TextButton", {
    Size = UDim2.new(0, 32, 0, 32),
    Position = UDim2.new(1, -44, 0.5, -16),
    BackgroundColor3 = UI_BG_BUTTON,
    Text = "×",
    TextColor3 = UI_TEXT_SECONDARY,
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    AutoButtonColor = false
}, TitleBar)
makeInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, CloseButton)
CloseButton.MouseEnter:Connect(function()
    CloseButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
end)
CloseButton.MouseLeave:Connect(function()
    CloseButton.BackgroundColor3 = UI_BG_BUTTON
    CloseButton.TextColor3 = UI_TEXT_SECONDARY
end)
CloseButton.MouseButton1Click:Connect(function()
    mainGui.Enabled = false
end)

local MinimizeButton = makeInstance("TextButton", {
    Size = UDim2.new(0, 32, 0, 32),
    Position = UDim2.new(1, -84, 0.5, -16),
    BackgroundColor3 = UI_BG_BUTTON,
    Text = "−",
    TextColor3 = UI_TEXT_SECONDARY,
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    AutoButtonColor = false
}, TitleBar)
makeInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, MinimizeButton)
MinimizeButton.MouseEnter:Connect(function()
    MinimizeButton.BackgroundColor3 = UI_BG_HOVER
    MinimizeButton.TextColor3 = UI_TEXT_MAIN
end)
MinimizeButton.MouseLeave:Connect(function()
    MinimizeButton.BackgroundColor3 = UI_BG_BUTTON
    MinimizeButton.TextColor3 = UI_TEXT_SECONDARY
end)
MinimizeButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- DRAG HANDLING
local dragStartPos, frameStartPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragStartPos = input.Position
        frameStartPos = MainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragStartPos and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStartPos
        MainFrame.Position = UDim2.new(
            frameStartPos.X.Scale, frameStartPos.X.Offset + delta.X,
            frameStartPos.Y.Scale, frameStartPos.Y.Offset + delta.Y
        )
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragStartPos = nil
    end
end)

-- STATUS LABEL
local StatusLabel = makeInstance("TextLabel", {
    Size = UDim2.new(1, -40, 0, 20),
    Position = UDim2.new(0, 20, 0, 62),
    BackgroundTransparency = 1,
    Text = "ready",
    TextColor3 = UI_TEXT_SECONDARY,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.Code,
    TextSize = 11
}, MainFrame)

local function setStatus(text, color)
    StatusLabel.Text = "● " .. text
    StatusLabel.TextColor3 = color or UI_TEXT_SECONDARY
end

-- BUTTON FACTORY
local function createButton(parent, x, width, y, label, textColor, bgColor)
    local btn = makeInstance("TextButton", {
        Size = UDim2.new(0, width, 0, 28),
        Position = UDim2.new(0, x, 0, y),
        BackgroundColor3 = bgColor or UI_BG_BUTTON,
        Text = label,
        TextColor3 = textColor or UI_TEXT_MAIN,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        AutoButtonColor = false
    }, parent)
    makeInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, btn)
    local stroke = makeInstance("UIStroke", {
        Color = UI_BORDER,
        Thickness = 1,
        Transparency = 0.4
    }, btn)
    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = UI_BG_HOVER
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = bgColor or UI_BG_BUTTON
    end)
    return btn, stroke
end

-- CONTROL BUTTONS
local AutoFarmBtn, AutoFarmStroke = createButton(MainFrame, 20, 160, 90, "auto-farm • off")
local CheckAllBtn = createButton(MainFrame, 190, 100, 90, "check all")
local UncheckAllBtn = createButton(MainFrame, 300, 110, 90, "uncheck all")
local TopTiersBtn = createButton(MainFrame, 420, 160, 90, "top tiers", Color3.fromRGB(200, 200, 255))
local AntiIdleBtn, AntiIdleStroke = createButton(MainFrame, 590, 130, 90, "anti-idle • off")

local RefreshBtn = createButton(MainFrame, 20, 80, 126, "refresh")
local SetHomeBtn = createButton(MainFrame, 110, 100, 126, "set home", Color3.fromRGB(200, 200, 255))
local GoHomeBtn = createButton(MainFrame, 220, 90, 126, "go home", Color3.fromRGB(190, 230, 190))
local RejoinBtn = createButton(MainFrame, 320, 110, 126, "rejoin", Color3.fromRGB(255, 210, 210))

local DiscordBtn = makeInstance("TextButton", {
    Size = UDim2.new(0, 110, 0, 28),
    Position = UDim2.new(0, 440, 0, 126),
    BackgroundColor3 = Color3.fromRGB(88, 101, 242),
    Text = "discord",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    AutoButtonColor = false
}, MainFrame)
makeInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, DiscordBtn)
DiscordBtn.MouseButton1Click:Connect(function()
    copyDiscordLink()
    setStatus("discord link copied", Color3.fromRGB(120, 180, 255))
end)

local WatchCountLabel = makeInstance("TextLabel", {
    Size = UDim2.new(0, 80, 0, 28),
    Position = UDim2.new(0, 560, 0, 126),
    BackgroundTransparency = 1,
    Text = "watch 5",
    TextColor3 = UI_TEXT_SECONDARY,
    TextXAlignment = Enum.TextXAlignment.Right,
    Font = Enum.Font.Code,
    TextSize = 11
}, MainFrame)

local EspBtn, EspStroke = createButton(MainFrame, 650, 90, 126, "esp • off")

local HomePosLabel = makeInstance("TextLabel", {
    Size = UDim2.new(0, 400, 0, 14),
    Position = UDim2.new(0, 340, 0, 158),
    BackgroundTransparency = 1,
    Text = "home • not set",
    TextColor3 = UI_TEXT_SECONDARY,
    TextXAlignment = Enum.TextXAlignment.Right,
    Font = Enum.Font.Code,
    TextSize = 10
}, MainFrame)

local function updateHomeLabel()
    if STATE.homeCFrame then
        local pos = STATE.homeCFrame.Position
        HomePosLabel.Text = string.format("home • %.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z)
        HomePosLabel.TextColor3 = Color3.fromRGB(140, 220, 140)
    else
        HomePosLabel.Text = "home • not set"
        HomePosLabel.TextColor3 = Color3.fromRGB(255, 160, 100)
    end
end

local function updateWatchCount()
    local count = 0
    for _ in pairs(STATE.watched) do count = count + 1 end
    WatchCountLabel.Text = "watch " .. count
end

-- SCROLLING FRAMES
makeInstance("TextLabel", {
    Size = UDim2.new(0, 356, 0, 16),
    Position = UDim2.new(0, 20, 0, 176),
    BackgroundTransparency = 1,
    Text = "CATALOG",
    TextColor3 = UI_TEXT_SECONDARY,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold,
    TextSize = 10
}, MainFrame)

makeInstance("TextLabel", {
    Size = UDim2.new(0, 340, 0, 16),
    Position = UDim2.new(0, 384, 0, 176),
    BackgroundTransparency = 1,
    Text = "LIVE",
    TextColor3 = UI_TEXT_SECONDARY,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold,
    TextSize = 10
}, MainFrame)

local CatalogFrame = makeInstance("ScrollingFrame", {
    Size = UDim2.new(0, 356, 1, -214),
    Position = UDim2.new(0, 20, 0, 196),
    BackgroundColor3 = UI_BG_SECTION,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = UI_BORDER,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y
}, MainFrame)
makeInstance("UICorner", {CornerRadius = UDim.new(0, 10)}, CatalogFrame)
makeInstance("UIStroke", {Color = UI_BORDER, Thickness = 1, Transparency = 0.6}, CatalogFrame)
makeInstance("UIPadding", {
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6)
}, CatalogFrame)
makeInstance("UIListLayout", {
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder
}, CatalogFrame)

local LiveFrame = makeInstance("ScrollingFrame", {
    Size = UDim2.new(0, 340, 1, -214),
    Position = UDim2.new(0, 384, 0, 196),
    BackgroundColor3 = UI_BG_SECTION,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = UI_BORDER,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y
}, MainFrame)
makeInstance("UICorner", {CornerRadius = UDim.new(0, 10)}, LiveFrame)
makeInstance("UIStroke", {Color = UI_BORDER, Thickness = 1, Transparency = 0.6}, LiveFrame)
makeInstance("UIPadding", {
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6)
}, LiveFrame)
makeInstance("UIListLayout", {
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder
}, LiveFrame)

-- ==========================================
-- CHARACTER / MOVEMENT HELPERS
-- ==========================================
local ALLOWED_PROMPTS = {
    Hatch = true,
    ["Skip Growth"] = true,
    ["Skip All"] = true,
    Unlock = true,
    Talk = true,
    Shop = true,
    Claim = true,
    ["Join Event"] = true,
    ["Pick Up"] = true
}

local function findNearbyPrompt(position, range)
    range = range or 40
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") and descendant.Enabled and not ALLOWED_PROMPTS[descendant.ActionText] then
            local part = descendant.Parent
            if part and part:IsA("BasePart") and (part.Position - position).Magnitude <= range then
                return descendant
            end
        end
    end
    return nil
end

local function setCollisionEnabled(enable)
    local character = LocalPlayer.Character
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if enable then
                if part:GetAttribute("_rap_origCanCollide") ~= nil then
                    part.CanCollide = part:GetAttribute("_rap_origCanCollide")
                    part:SetAttribute("_rap_origCanCollide", nil)
                end
            else
                if part:GetAttribute("_rap_origCanCollide") == nil then
                    part:SetAttribute("_rap_origCanCollide", part.CanCollide)
                end
                part.CanCollide = false
            end
        end
    end
end

local function setMovementLocked(lock)
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end

    if lock then
        humanoid:SetAttribute("_rap_origWS", humanoid.WalkSpeed)
        humanoid:SetAttribute("_rap_origJP", humanoid.JumpPower)
        humanoid:SetAttribute("_rap_origJH", humanoid.JumpHeight)
        humanoid.WalkSpeed = 0
        if humanoid.UseJumpPower then
            humanoid.JumpPower = 0
        else
            humanoid.JumpHeight = 0
        end
        rootPart:SetAttribute("_rap_origAnchored", rootPart.Anchored)
        rootPart.Anchored = true
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        end)
    else
        local savedWS = humanoid:GetAttribute("_rap_origWS")
        if savedWS then humanoid.WalkSpeed = savedWS end
        local savedJP = humanoid:GetAttribute("_rap_origJP")
        if savedJP then humanoid.JumpPower = savedJP end
        local savedJH = humanoid:GetAttribute("_rap_origJH")
        if savedJH then humanoid.JumpHeight = savedJH end
        local savedAnchored = rootPart:GetAttribute("_rap_origAnchored")
        if savedAnchored ~= nil then rootPart.Anchored = savedAnchored end
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
        end)
    end
end

-- ==========================================
-- FLIGHT / MOVEMENT
-- ==========================================
local function flyToPoint(targetPosition, speed)
    speed = speed or SETTINGS.flySpeedToEgg
    local character = LocalPlayer.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    local arrived = false
    local startTime = tick()
    local connection
    connection = RunService.Heartbeat:Connect(function(deltaTime)
        if not rootPart.Parent then
            arrived = true
            return
        end
        local currentPos = rootPart.Position
        local direction = targetPosition - currentPos
        local distance = direction.Magnitude

        if distance < 2 then
            rootPart.CFrame = CFrame.new(targetPosition)
            arrived = true
            return
        end

        local moveSpeed = math.min(speed * deltaTime, distance)
        rootPart.CFrame = CFrame.new(currentPos + direction.Unit * moveSpeed)

        if tick() - startTime > SETTINGS.flightTimeout then
            arrived = true
        end
    end)

    while not arrived do task.wait() end
    connection:Disconnect()
    return true
end

local function returnToHome(originRootPart, character)
    if not STATE.homeCFrame then return false end
    local targetPos = STATE.homeCFrame.Position
    local speed = SETTINGS.flySpeedHome or SETTINGS.flySpeedToEgg

    local arrived = false
    local startTime = tick()
    local connection
    connection = RunService.Heartbeat:Connect(function(deltaTime)
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then
            arrived = true
            return
        end
        pcall(function() root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)

        local direction = targetPos - root.Position
        local distance = direction.Magnitude

        if distance < 3 then
            root.CFrame = CFrame.new(targetPos)
            arrived = true
            return
        end

        local moveSpeed = math.min(speed * deltaTime, distance)
        root.CFrame = CFrame.new(root.Position + direction.Unit * moveSpeed)

        if tick() - startTime > SETTINGS.flightTimeout then
            pcall(function() root.CFrame = CFrame.new(targetPos) end)
            arrived = true
        end
    end)

    while not arrived do task.wait() end
    connection:Disconnect()
    task.wait(SETTINGS.postFlyWait)

    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root then
        local prompt = findNearbyPrompt(root.Position, 40)
        if prompt and prompt.Parent:IsA("BasePart") then
            local part = prompt.Parent
            if (part.Position - root.Position).Magnitude > 3 then
                local chaseStart = tick()
                local chaseConn
                chaseConn = RunService.Heartbeat:Connect(function(dt)
                    local r = character and character:FindFirstChild("HumanoidRootPart")
                    if not r or (part.Position - r.Position).Magnitude < 3 or tick() - chaseStart > 1.5 then
                        chaseConn:Disconnect()
                        return
                    end
                    local chaseDir = part.Position - r.Position
                    local chaseSpeed = math.min(80 * dt, chaseDir.Magnitude)
                    r.CFrame = CFrame.new(r.Position + chaseDir.Unit * chaseSpeed)
                end)
                while chaseConn do task.wait() end
            end
        end
    end
    return true
end

-- ==========================================
-- EGG SCANNING
-- ==========================================
local function isValidEgg(instance)
    if instance.Parent ~= workspace.RenderedEggs then return false end
    local check = instance
    while check do
        if check.Name == "HeldEggDisplay" then return false end
        if Players:GetPlayerFromCharacter(check) then return false end
        check = check.Parent
    end
    return true
end

local function findPickupPrompt(egg)
    for _, descendant in ipairs(egg:GetDescendants()) do
        if descendant:IsA("ProximityPrompt")
          and descendant.ActionText == "Pick Up"
          and descendant.Enabled
          and descendant.Parent:IsA("BasePart") then
            return descendant.Parent, descendant
        end
    end
    return nil, nil
end

local function isClaimedByOther(eggPart)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local otherRoot = player.Character:FindFirstChild("HumanoidRootPart")
            if otherRoot and (otherRoot.Position - eggPart.Position).Magnitude < SETTINGS.eggClaimRadius then
                return true
            end
        end
    end
    return false
end

local function scanEggs()
    local results = {}
    local eggContainer = workspace:FindFirstChild("RenderedEggs")
    if not eggContainer then return results end

    for _, egg in ipairs(eggContainer:GetChildren()) do
        if isValidEgg(egg) then
            local part, prompt = findPickupPrompt(egg)
            if part then
                local value, tier, source = getEggValueAndTier(egg)
                results[egg] = {
                    name = egg.Name,
                    value = value,
                    tier = tier,
                    source = source,
                    part = part,
                    prompt = prompt,
                    free = not isClaimedByOther(part)
                }
            end
        end
    end
    return results
end

-- ==========================================
-- ESP SYSTEM
-- ==========================================
local function removeEsp(instance)
    local obj = STATE.espObjects[instance]
    if not obj then return end
    if obj.highlight then pcall(function() obj.highlight:Destroy() end) end
    if obj.billboard then pcall(function() obj.billboard:Destroy() end) end
    STATE.espObjects[instance] = nil
end

local function addEsp(instance, info)
    if STATE.espObjects[instance] then return end
    local tierColor = TIER_COLORS[info.tier] or TIER_COLORS.Unknown

    local highlight = Instance.new("Highlight")
    highlight.Name = "_rap_esp_hl"
    highlight.Adornee = instance
    highlight.FillColor = tierColor
    highlight.FillTransparency = 0.55
    highlight.OutlineColor = tierColor
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = instance

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "_rap_esp_bb"
    billboard.Adornee = instance
    billboard.Size = UDim2.new(0, 200, 0, 40)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 5000
    billboard.LightInfluence = 0
    billboard.Parent = instance

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "_nameLbl"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 0, 22)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.TextColor3 = tierColor
    nameLabel.TextStrokeTransparency = 0
    nameLabel.Text = info.name
    nameLabel.Parent = billboard

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "_infoLbl"
    infoLabel.BackgroundTransparency = 1
    infoLabel.Size = UDim2.new(1, 0, 0, 16)
    infoLabel.Position = UDim2.new(0, 0, 0, 22)
    infoLabel.Font = Enum.Font.Code
    infoLabel.TextSize = 11
    infoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    infoLabel.TextStrokeTransparency = 0
    infoLabel.Text = formatNumber(info.value) .. " • " .. info.tier
    infoLabel.Parent = billboard

    STATE.espObjects[instance] = {
        highlight = highlight,
        billboard = billboard
    }
end

local function shouldShowEsp(info)
    if STATE.espState == "all" then return true end
    if STATE.espState == "watched" then return STATE.watched[info.name] end
    return false
end

local function updateEsp()
    for inst in pairs(STATE.espObjects) do
        if not inst.Parent or not STATE.eggs[inst] then
            removeEsp(inst)
        end
    end
    if STATE.espState == "off" then
        for inst in pairs(STATE.espObjects) do removeEsp(inst) end
        return
    end
    for inst, info in pairs(STATE.eggs) do
        if shouldShowEsp(info) then
            if not STATE.espObjects[inst] then
                addEsp(inst, info)
            else
                local tierColor = TIER_COLORS[info.tier] or TIER_COLORS.Unknown
                local hl = STATE.espObjects[inst].highlight
                if hl then
                    hl.FillColor = tierColor
                    hl.OutlineColor = tierColor
                end
                local bb = STATE.espObjects[inst].billboard
                if bb then
                    local nl = bb:FindFirstChild("_nameLbl")
                    if nl then nl.Text = info.name end
                    local il = bb:FindFirstChild("_infoLbl")
                    if il then il.Text = formatNumber(info.value) .. " • " .. info.tier end
                end
            end
        else
            removeEsp(inst)
        end
    end
end

local function cycleEspMode()
    if STATE.espState == "off" then
        STATE.espState = "all"
        EspBtn.Text = "esp • all"
        EspStroke.Color = UI_ACCENT_GREEN
        setStatus("esp • all eggs", UI_ACCENT_GREEN)
    elseif STATE.espState == "all" then
        STATE.espState = "watched"
        EspBtn.Text = "esp • watched"
        EspStroke.Color = Color3.fromRGB(255, 200, 100)
        setStatus("esp • watched only", Color3.fromRGB(255, 200, 100))
    else
        STATE.espState = "off"
        EspBtn.Text = "esp • off"
        EspStroke.Color = UI_BORDER
        setStatus("esp • off")
    end
    updateEsp()
end
EspBtn.MouseButton1Click:Connect(cycleEspMode)

-- ==========================================
-- CATALOG & LIVE ROWS
-- ==========================================

local function renderCatalogRow(eggName, info, index)
    if STATE.catalogRows[eggName] then
        STATE.catalogRows[eggName]:Destroy()
    end
    local tierColor = TIER_COLORS[info.tier] or TIER_COLORS.Unknown

    local row = makeInstance("Frame", {
        Size = UDim2.new(1, -8, 0, 34),
        BackgroundColor3 = UI_BG_BUTTON,
        LayoutOrder = index
    }, CatalogFrame)
    makeInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, row)
    makeInstance("Frame", {
        Size = UDim2.new(0, 3, 1, -12),
        Position = UDim2.new(0, 0, 0, 6),
        BackgroundColor3 = tierColor
    }, row)

    local watchBtn = makeInstance("TextButton", {
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(0, 12, 0.5, -11),
        BackgroundColor3 = UI_BG_SECTION,
        Text = "",
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        AutoButtonColor = false
    }, row)
    makeInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, watchBtn)
    local watchStroke = makeInstance("UIStroke", {Color = UI_BORDER, Thickness = 1, Transparency = 0.4}, watchBtn)

    local function updateWatchIcon()
        if STATE.watched[eggName] then
            watchBtn.Text = "✓"
            watchBtn.BackgroundColor3 = UI_ACCENT_GREEN_DARK
            watchStroke.Color = UI_ACCENT_GREEN
        else
            watchBtn.Text = ""
            watchBtn.BackgroundColor3 = UI_BG_SECTION
            watchStroke.Color = UI_BORDER
        end
    end
    updateWatchIcon()
    watchBtn.MouseButton1Click:Connect(function()
        STATE.watched[eggName] = not STATE.watched[eggName] or nil
        updateWatchIcon()
        updateWatchCount()
        updateEsp()
    end)

        makeInstance("TextLabel", {
        Size = UDim2.new(1, -100, 0, 14),
        Position = UDim2.new(0, 44, 0, 4),
        BackgroundTransparency = 1,
        Text = eggName,
        TextColor3 = tierColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold,
        TextSize = 12
    }, row)

    makeInstance("TextLabel", {
        Size = UDim2.new(1, -100, 0, 12),
        Position = UDim2.new(0, 44, 0, 18),
        BackgroundTransparency = 1,
        Text = formatNumber(info.value) .. "  •  " .. info.tier,
        TextColor3 = UI_TEXT_SECONDARY,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Code,
        TextSize = 10
    }, row)

    STATE.catalogRows[eggName] = row
end

local function buildCatalog()
    for _, row in pairs(STATE.catalogRows) do
        row:Destroy()
    end
    STATE.catalogRows = {}

    local sorted = {}
    for name, info in pairs(EGG_DATA) do
        table.insert(sorted, {name = name, data = info})
    end
    table.sort(sorted, function(a, b)
        return a.data.value < b.data.value
    end)

    for index, entry in ipairs(sorted) do
        renderCatalogRow(entry.name, entry.data, index)
    end
end
-- ==========================================
-- GRAB / STEAL LOGIC
-- ==========================================
function grabEgg(eggInfo, eggKey)
    if STATE.busy then return end
    STATE.busy = true

    reserveEgg(eggKey)

    local function cleanup()
        setCollisionEnabled(true)
        setMovementLocked(false)
        STATE.busy = false
    end

    local function fail(msg)
        setStatus(msg, Color3.fromRGB(255, 120, 120))
        cleanup()
    end

    local character = LocalPlayer.Character
    local myRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not myRoot then
        fail("no character")
        return
    end

    if not eggInfo.part or not eggInfo.part.Parent then
        fail("egg gone")
        return
    end

    if not STATE.homeCFrame then
        fail("home not set")
        return
    end

    setStatus("● " .. eggInfo.name .. " • " .. formatNumber(eggInfo.value), UI_ACCENT_GREEN)

    disableBreakTimer()
    setCollisionEnabled(false)
    setMovementLocked(true)

    local targetPos = eggInfo.part.Position + Vector3.new(0, SETTINGS.landOffsetY, 0)
    flyToPoint(targetPos, SETTINGS.flySpeedToEgg)

    setMovementLocked(false)
    setCollisionEnabled(true)

    task.wait(SETTINGS.settleDelay)

    local prompt = eggInfo.prompt
    if eggInfo.part then
        for _, desc in ipairs(eggInfo.part:GetChildren()) do
            if desc:IsA("ProximityPrompt")
              and desc.ActionText == "Pick Up"
              and desc.Enabled then
                prompt = desc
                break
            end
        end
    end

    local grabbed = false
    for attempt = 1, SETTINGS.grabMaxTries do
        pcall(fireproximityprompt, prompt)
        if not eggKey or not eggKey.Parent or eggKey.Parent ~= workspace.RenderedEggs then
            grabbed = true
            break
        end
        task.wait(SETTINGS.grabTryDelay)
    end

    if not grabbed then
        restoreBreakTimer()
        fail("could not pick up " .. eggInfo.name)
        return
    end

    setStatus("grabbed " .. eggInfo.name .. " • returning", UI_ACCENT_GREEN)

    disableBreakTimer()
    setCollisionEnabled(false)
    pcall(function()
        returnToHome(myRoot, character)
    end)
    setMovementLocked(false)
    setCollisionEnabled(true)

    -- wait until grounded
    local hum = character:FindFirstChildOfClass("Humanoid")
    local landStart = tick()
    while tick() - landStart < 1.5 do
        if hum and hum.FloorMaterial ~= Enum.Material.Air then break end
        task.wait(0.05)
    end

    disableBreakTimer()

    local depositPrompt = findNearbyPrompt(myRoot.Position, 40)
    if depositPrompt then
        pcall(fireproximityprompt, depositPrompt)
        setStatus("deposited " .. eggInfo.name, UI_ACCENT_GREEN)
    else
        setStatus("home • walk in to deposit", Color3.fromRGB(255, 200, 100))
    end

    task.wait(0.4)
    restoreBreakTimer()
    cleanup()
end
-- ==========================================
-- LIVE EGG ROWS
-- ==========================================
local function renderLiveRow(eggKey, info)
    if STATE.rows[eggKey] then
        STATE.rows[eggKey]:Destroy()
    end

    local tierColor = TIER_COLORS[info.tier] or TIER_COLORS.Unknown
    local row = makeInstance("Frame", {
        Size = UDim2.new(1, -8, 0, 42),
        BackgroundColor3 = UI_BG_BUTTON,
        LayoutOrder = 0
    }, LiveFrame)
    makeInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, row)

    makeInstance("Frame", {
        Size = UDim2.new(0, 3, 1, -12),
        Position = UDim2.new(0, 0, 0, 6),
        BackgroundColor3 = tierColor
    }, row)

    makeInstance("TextLabel", {
        Name = "_nameLbl",
        Size = UDim2.new(1, -130, 0, 16),
        Position = UDim2.new(0, 12, 0, 4),
        BackgroundTransparency = 1,
        Text = info.name,
        TextColor3 = tierColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold,
        TextSize = 12
    }, row)

    local statusText = formatNumber(info.value) .. "  •  " .. info.tier
    if not info.free then
        statusText = statusText .. "  •  contested"
    end
    makeInstance("TextLabel", {
        Name = "_infoLbl",
        Size = UDim2.new(1, -130, 0, 14),
        Position = UDim2.new(0, 12, 0, 22),
        BackgroundTransparency = 1,
        Text = statusText,
        TextColor3 = UI_TEXT_SECONDARY,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Code,
        TextSize = 10
    }, row)

    local stealBtn = makeInstance("TextButton", {
        Name = "_stealBtn",
        Size = UDim2.new(0, 90, 0, 28),
        Position = UDim2.new(1, -100, 0.5, -14),
        BackgroundColor3 = info.free and Color3.fromRGB(180, 40, 40) or Color3.fromRGB(60, 40, 40),
        Text = info.free and "steal" or "wait",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        AutoButtonColor = false
    }, row)
    makeInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, stealBtn)

    stealBtn.MouseButton1Click:Connect(function()
        if STATE.busy then return end
        local freshInfo = STATE.eggs[eggKey]
        if freshInfo and freshInfo.free then
            task.spawn(function()
                grabEgg(freshInfo, eggKey)
            end)
        end
    end)

    STATE.rows[eggKey] = row
end



-- ==========================================
-- SCAN & UPDATE LOOP
-- ==========================================
local function refreshLiveEggs()
    -- remove rows for eggs that no longer exist
    for key, row in pairs(STATE.rows) do
        if not STATE.eggs[key] then
            row:Destroy()
            STATE.rows[key] = nil
        end
    end

    local eggList = {}
    for model, info in pairs(STATE.eggs) do
        table.insert(eggList, {model = model, info = info})
    end

    local needSort = (tick() - (STATE.lastSort or 0)) >= SETTINGS.sortInterval
    if needSort then
        table.sort(eggList, function(a, b)
            if a.info.value ~= b.info.value then
                return a.info.value > b.info.value
            end
            if a.info.name ~= b.info.name then
                return a.info.name < b.info.name
            end
            return tostring(a.model) < tostring(b.model)
        end)
        STATE.lastSort = tick()
        STATE.orderSnapshot = eggList
    else
        local preserved = STATE.orderSnapshot or {}
        local rebuilt = {}
        local seen = {}
        for _, entry in ipairs(preserved) do
            if STATE.eggs[entry.model] then
                table.insert(rebuilt, {model = entry.model, info = STATE.eggs[entry.model]})
                seen[entry.model] = true
            end
        end
        for model, info in pairs(STATE.eggs) do
            if not seen[model] then
                table.insert(rebuilt, {model = model, info = info})
            end
        end
        eggList = rebuilt
    end

    local scrollPos = LiveFrame.CanvasPosition
    local shouldRestoreScroll = scrollPos.Y > 5

    for idx, entry in ipairs(eggList) do
        local existingRow = STATE.rows[entry.model]
        if not existingRow then
            renderLiveRow(entry.model, entry.info)
            existingRow = STATE.rows[entry.model]
        else
            local infoLabel = existingRow:FindFirstChild("_infoLbl")
            if infoLabel then
                local newText = formatNumber(entry.info.value) .. "  •  " .. entry.info.tier
                if not entry.info.free then
                    newText = newText .. "  •  contested"
                end
                if infoLabel.Text ~= newText then
                    infoLabel.Text = newText
                end
            end

            local btn = existingRow:FindFirstChild("_stealBtn")
            if btn then
                local newColor = entry.info.free and Color3.fromRGB(180, 40, 40) or Color3.fromRGB(60, 40, 40)
                local newLabel = entry.info.free and "steal" or "wait"
                if btn.BackgroundColor3 ~= newColor then
                    btn.BackgroundColor3 = newColor
                end
                if btn.Text ~= newLabel then
                    btn.Text = newLabel
                end
            end
        end

        if existingRow and existingRow.LayoutOrder ~= idx then
            existingRow.LayoutOrder = idx
        end
    end

    if shouldRestoreScroll then
        task.defer(function()
            pcall(function() LiveFrame.CanvasPosition = scrollPos end)
        end)
        task.delay(0.05, function()
            pcall(function() LiveFrame.CanvasPosition = scrollPos end)
        end)
    end

    updateEsp()
end

-- main scanner loop
task.spawn(function()
    while mainGui.Parent do
        STATE.eggs = scanEggs()
        refreshLiveEggs()
        task.wait(SETTINGS.rescanInterval)
    end
end)

-- auto-farm loop
task.spawn(function()
    while mainGui.Parent do
        pcall(function()
            if not STATE.autoFarm or STATE.busy then return end
            if tick() - STATE.lastAutoSteal < SETTINGS.autoFarmCooldown then return end

            local bestEgg, bestKey
            for key, info in pairs(STATE.eggs) do
                if STATE.watched[info.name] and info.free and not isReserved(key) then
                    if not bestEgg or info.value > bestEgg.value then
                        bestEgg = info
                        bestKey = key
                    end
                end
            end

            if bestEgg and bestKey then
                STATE.lastAutoSteal = tick()
                reserveEgg(bestKey)
                task.spawn(function()
                    grabEgg(bestEgg, bestKey)
                end)
            end
        end)
        task.wait(0.5)
    end
end)

-- ==========================================
-- BUTTON ACTIONS
-- ==========================================
AutoFarmBtn.MouseButton1Click:Connect(function()
    STATE.autoFarm = not STATE.autoFarm
    if STATE.autoFarm then
        AutoFarmBtn.Text = "auto-farm • on"
        AutoFarmStroke.Color = UI_ACCENT_GREEN
        setStatus("auto-farm on", UI_ACCENT_GREEN)
    else
        AutoFarmBtn.Text = "auto-farm • off"
        AutoFarmStroke.Color = UI_BORDER
        setStatus("auto-farm off")
    end
end)

AntiIdleBtn.MouseButton1Click:Connect(function()
    STATE.antiIdle = not STATE.antiIdle
    if STATE.antiIdle then
        AntiIdleBtn.Text = "anti-idle • on"
        AntiIdleStroke.Color = UI_ACCENT_GREEN
        setStatus("anti-idle on", UI_ACCENT_GREEN)
    else
        AntiIdleBtn.Text = "anti-idle • off"
        AntiIdleStroke.Color = UI_BORDER
        setStatus("anti-idle off")
    end
end)

CheckAllBtn.MouseButton1Click:Connect(function()
    for name in pairs(EGG_DATA) do
        STATE.watched[name] = true
    end
    buildCatalog()
    updateWatchCount()
    updateEsp()
    setStatus("all checked")
end)

UncheckAllBtn.MouseButton1Click:Connect(function()
    STATE.watched = {}
    buildCatalog()
    updateWatchCount()
    updateEsp()
    setStatus("all unchecked")
end)

TopTiersBtn.MouseButton1Click:Connect(function()
    STATE.watched = {}
    local topTiers = {
        "Aurora Egg", "Galaxy Egg", "Blackhole Egg",
        "Solaris Egg", "Cherub Egg", "Soul Egg",
        "Sinister Egg", "Flaming Egg"
    }
    for _, name in ipairs(topTiers) do
        if EGG_DATA[name] then
            STATE.watched[name] = true
        end
    end
    buildCatalog()
    updateWatchCount()
    updateEsp()
    setStatus("top tiers checked", Color3.fromRGB(200, 200, 255))
end)

RefreshBtn.MouseButton1Click:Connect(function()
    STATE.eggs = scanEggs()
    refreshLiveEggs()
    local count = 0
    for _ in pairs(STATE.eggs) do count = count + 1 end
    setStatus("refreshed • " .. count .. " eggs")
end)

SetHomeBtn.MouseButton1Click:Connect(function()
    if saveHomePosition() then
        setStatus("home set", UI_ACCENT_GREEN)
        updateHomeLabel()
    else
        setStatus("could not capture position", Color3.fromRGB(255, 150, 100))
    end
end)

GoHomeBtn.MouseButton1Click:Connect(function()
    if not STATE.homeCFrame then
        setStatus("home not set", Color3.fromRGB(255, 200, 100))
        return
    end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        setStatus("returning home…")
        pcall(function()
            returnToHome(root, char)
        end)
        setStatus("home", UI_ACCENT_GREEN)
    end
end)

RejoinBtn.MouseButton1Click:Connect(function()
    setStatus("rejoining…", Color3.fromRGB(255, 200, 100))

    -- save watch list & home
    if writefile then
        local watchList = {}
        for name in pairs(STATE.watched) do
            table.insert(watchList, name)
        end
        pcall(writefile, "rideapet_watch.txt", table.concat(watchList, "\n"))

        if STATE.homeCFrame then
            local p = STATE.homeCFrame.Position
            pcall(writefile, "rideapet_home.txt",
                string.format("%f,%f,%f", p.X, p.Y, p.Z))
        end
    end

    if queue_on_teleport then
        pcall(function()
            queue_on_teleport([[print("[RideAPetSteal] rejoined — reload the script manually")]])
        end)
    end

    task.wait(0.3)
    local TeleportService = game:GetService("TeleportService")
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
    if not ok then
        ok, err = pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer, {JobId = game.JobId})
        end)
    end
    if not ok then
        setStatus("rejoin failed: " .. tostring(err), Color3.fromRGB(255, 120, 120))
    end
end)

-- ==========================================
-- KEYBOARD TOGGLES
-- ==========================================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == SETTINGS.toggleKey then
        mainGui.Enabled = not mainGui.Enabled
    elseif input.KeyCode == SETTINGS.espToggleKey then
        cycleEspMode()
    end
end)

-- ==========================================
-- INITIALIZATION
-- ==========================================
task.spawn(function()
    task.wait(0.5)
    local homeOk = saveHomePosition()
    updateHomeLabel()
    buildCatalog()
    STATE.eggs = scanEggs()
    refreshLiveEggs()
    updateWatchCount()

    local eggCount = 0
    for _ in pairs(STATE.eggs) do eggCount = eggCount + 1 end

    if homeOk then
        setStatus("loaded • home captured • " .. eggCount .. " eggs", UI_ACCENT_GREEN)
    else
        setStatus("loaded • click set home • " .. eggCount .. " eggs")
    end
end)

print("[RideAPetSteal] loaded")
