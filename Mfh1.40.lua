--========================================================--
-- MFH 脚本 v1.408.556 · 全面修复 + 超能包 + 自定义MFH
-- 保存传送 / 文字天空 / 模糊搜索 / 飞行 / 甩飞 / 伪装 全修复
-- 新增：自定义窗口大小 + 字体大小调节
-- 本次更新：甩飞判定改为"接触才甩" + 新增第三人称视角
-- 1. 【服务端执行】运行一次
-- 2. 【客户端执行】运行一次
--========================================================--
local RunService, Players, ReplicatedStorage, UserInputService
local TextChatService, TweenService, Lighting, Workspace
local HttpService, TeleportService, VirtualUser, VirtualInputManager
pcall(function() RunService = game:GetService("RunService") end)
pcall(function() Players = game:GetService("Players") end)
pcall(function() ReplicatedStorage = game:GetService("ReplicatedStorage") end)
pcall(function() UserInputService = game:GetService("UserInputService") end)
pcall(function() TextChatService = game:GetService("TextChatService") end)
pcall(function() TweenService = game:GetService("TweenService") end)
pcall(function() Lighting = game:GetService("Lighting") end)
pcall(function() Workspace = game:GetService("Workspace") end)
pcall(function() HttpService = game:GetService("HttpService") end)
pcall(function() TeleportService = game:GetService("TeleportService") end)
pcall(function() VirtualUser = game:GetService("VirtualUser") end)
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

if not RunService or not Players or not ReplicatedStorage or not UserInputService then
    warn("[MFH] 核心服务获取失败。")
    return
end

if not TweenService then
    TweenService = {
        Create = function()
            return { Play = function() end, Completed = { Connect = function() end } }
        end
    }
end

print("[MFH] 服务加载完成")

--========================================================--
-- ⚙ 配置
--========================================================--
local CONFIG = {
    VERSION = "v1.408.556",
    REMOTE_NAME = "MFH_Remote_v2",
    SPEAK_TAG = "MFH_Speak",
    BOMB_TAG = "MFH_Bomb",
    ESP_TAG = "MFH_ESP",
    MAX_TEXT_LEN = 200,
    MIN_DURATION = 1,
    MAX_DURATION = 60,
    DEFAULT_DUR = 3,
    COOLDOWN = 0.5,
    BOMB_TICK = 0.5,
    BUBBLE_BASE_W = 240,
    BUBBLE_BASE_H = 70,
    BUBBLE_OFFSET = Vector3.new(0, 2.8, 0),
    TEXT_SIZE_MIN = 1,
    TEXT_SIZE_MAX = 10,
    TEXT_SIZE_DEFAULT = 5,
    FLY_DEFAULT_SPEED = 60,
    FLY_MIN_SPEED = 10,
    FLY_MAX_SPEED = 500,
    HEAL_MIN_INTERVAL = 0.05,
    HEAL_MAX_INTERVAL = 60,
    HEAL_DEFAULT_INTERVAL = 0.5,
    FLING_RANGE = 10,          -- 旧值（保留兼容）
    FLING_TOUCH_RANGE = 4,     -- 新：接触判定距离（贴身即算碰到）
    FLING_HIT_COOLDOWN = 0.3,
    FLING_POWER_MIN = 100,
    FLING_POWER_MAX = 3000,
    FLING_POWER_DEFAULT = 800,
    SPEED_MIN = 16,
    SPEED_MAX = 500,
    SPEED_DEFAULT = 16,
    JUMP_MIN = 50,
    JUMP_MAX = 500,
    JUMP_DEFAULT = 50,
    KILL_AURA_RANGE = 15,
    HITBOX_SCALE = 3,
    AIMBOT_SMOOTH = 0.15,
    BASE_W = 580,
    BASE_H = 640,
    ITEM_REMOTE = "MFH_ItemRemote",
    ITEM_MAX = 200,
    GRAB_RANGE = 30,
    GRAB_SPEED = 8,
    THROW_POWER = 150,
    FREEZE_RANGE = 20,
}

--========================================================--
-- 🛠 工具
--========================================================--
local Util = {}

function Util.sanitizeText(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("%c", ""):gsub("<.->", "")
    text = text:match("^%s*(.-)%s*$") or ""
    if text == "" then return nil end
    if #text > CONFIG.MAX_TEXT_LEN then
        text = text:sub(1, CONFIG.MAX_TEXT_LEN)
    end
    return text
end

function Util.clampDuration(v)
    v = tonumber(v) or CONFIG.DEFAULT_DUR
    if v ~= v then v = CONFIG.DEFAULT_DUR end
    return math.clamp(v, CONFIG.MIN_DURATION, CONFIG.MAX_DURATION)
end

function Util.clampTextSize(v)
    v = tonumber(v) or CONFIG.TEXT_SIZE_DEFAULT
    if v ~= v then v = CONFIG.TEXT_SIZE_DEFAULT end
    return math.clamp(math.floor(v + 0.5), CONFIG.TEXT_SIZE_MIN, CONFIG.TEXT_SIZE_MAX)
end

function Util.clamp(v, min, max)
    v = tonumber(v)
    if not v or v ~= v then return min end
    return math.clamp(v, min, max)
end

function Util.safeDestroy(o)
    if o and typeof(o) == "Instance" and o.Parent then
        pcall(function() o:Destroy() end)
    end
end

function Util.getHead(c)
    if not c or not c.Parent then return nil end
    local h = c:FindFirstChild("Head")
    return h and h:IsA("BasePart") and h or nil
end

function Util.getRoot(c)
    if not c or not c.Parent then return nil end
    local r = c:FindFirstChild("HumanoidRootPart")
    return r and r:IsA("BasePart") and r or nil
end

function Util.getHumanoid(c)
    if not c or not c.Parent then return nil end
    return c:FindFirstChildOfClass("Humanoid")
end

function Util.createBubble(character, text, duration, tag, textSize)
    local head = Util.getHead(character)
    if not head then return nil end
    tag = tag or CONFIG.SPEAK_TAG
    duration = Util.clampDuration(duration)
    textSize = Util.clampTextSize(textSize)
    local old = head:FindFirstChild(tag)
    if old then Util.safeDestroy(old) end
    local scale = textSize / CONFIG.TEXT_SIZE_DEFAULT
    local bb = Instance.new("BillboardGui")
    bb.Name = tag
    bb.Size = UDim2.fromOffset(math.floor(CONFIG.BUBBLE_BASE_W * scale), math.floor(CONFIG.BUBBLE_BASE_H * scale))
    bb.StudsOffset = CONFIG.BUBBLE_OFFSET
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.Parent = head
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.RichText = false
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextWrapped = true
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = bb
    task.delay(duration, function() Util.safeDestroy(bb) end)
    return bb
end

--==========================================================--
-- 🖥 服务端
--==========================================================--
if RunService:IsServer() then
    if _G.MFH_SERVER_HOOKED then
        warn("[MFH] 服务端已挂载。")
        return
    end
    _G.MFH_SERVER_HOOKED = true

    local remote = ReplicatedStorage:FindFirstChild(CONFIG.REMOTE_NAME)
    if not remote then
        remote = Instance.new("RemoteEvent")
        remote.Name = CONFIG.REMOTE_NAME
        remote.Parent = ReplicatedStorage
    end

    local itemRemote = ReplicatedStorage:FindFirstChild(CONFIG.ITEM_REMOTE)
    if not itemRemote then
        itemRemote = Instance.new("RemoteEvent")
        itemRemote.Name = CONFIG.ITEM_REMOTE
        itemRemote.Parent = ReplicatedStorage
    end

    local lastSend = {}
    local activeBomb = nil

    local function tryBombPlayer(p, bomb)
        if not p or not p.Parent then return end
        local head = Util.getHead(p.Character)
        if not head then return end
        local remain = bomb.endTime - tick()
        if remain <= 0.1 then return end
        if head:FindFirstChild(CONFIG.BOMB_TAG) then return end
        Util.createBubble(p.Character, bomb.text, remain, CONFIG.BOMB_TAG, bomb.size)
    end

    local function startBomb(text, duration, size)
        duration = Util.clampDuration(duration)
        local token = {}
        activeBomb = { text = text, endTime = tick() + duration, size = size, token = token }
        for _, p in ipairs(Players:GetPlayers()) do
            tryBombPlayer(p, activeBomb)
        end
        task.spawn(function()
            while activeBomb and activeBomb.token == token and tick() < activeBomb.endTime do
                local bomb = activeBomb
                if not bomb then break end
                for _, p in ipairs(Players:GetPlayers()) do
                    tryBombPlayer(p, bomb)
                end
                task.wait(CONFIG.BOMB_TICK)
            end
            if activeBomb and activeBomb.token == token then
                activeBomb = nil
            end
        end)
    end

    local function setSky(skyId)
        skyId = tostring(skyId or "")
        if not skyId:match("^rbxassetid://%d+$") and not skyId:match("^%d+$") then return false end
        if skyId:match("^%d+$") then skyId = "rbxassetid://" .. skyId end
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if not sky then sky = Instance.new("Sky"); sky.Parent = Lighting end
        pcall(function()
            sky.SkyboxBk = skyId; sky.SkyboxDn = skyId
            sky.SkyboxFt = skyId; sky.SkyboxLf = skyId
            sky.SkyboxRt = skyId; sky.SkyboxUp = skyId
        end)
        return true
    end

    local function resetSky()
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if sky then Util.safeDestroy(sky) end
    end

    local function findToolContainer()
        local searchRoots = { ReplicatedStorage, game:GetService("ServerStorage"), Workspace }
        local folders = {}
        for _, root in ipairs(searchRoots) do
            for _, child in ipairs(root:GetChildren()) do
                if child:IsA("Folder") or child:IsA("Model") then
                    local name = child.Name:lower()
                    if name:find("tool") or name:find("item") or name:find("weapon")
                        or name:find("gear") or name:find("shop") or name:find("store")
                        or name:find("道具") or name:find("武器") or name:find("物品") then
                        table.insert(folders, child)
                    end
                end
            end
        end
        if #folders == 0 then
            for _, root in ipairs(searchRoots) do
                for _, child in ipairs(root:GetChildren()) do
                    if child:IsA("Tool") then
                        table.insert(folders, root)
                        break
                    end
                end
            end
        end
        return folders
    end

    local function getAllItems(targetPlayer)
        local items = {}
        local seen = {}
        local containers = findToolContainer()
        for _, container in ipairs(containers) do
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") and not seen[child.Name] then
                    seen[child.Name] = true
                    table.insert(items, child)
                end
            end
        end
        local backpack = targetPlayer and targetPlayer:FindFirstChild("Backpack")
        if backpack then
            for _, child in ipairs(backpack:GetChildren()) do
                if child:IsA("Tool") and not seen[child.Name] then
                    seen[child.Name] = true
                    table.insert(items, child)
                end
            end
        end
        return items
    end

    itemRemote.OnServerEvent:Connect(function(player, action, itemName)
        if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
        if type(action) ~= "string" or type(itemName) ~= "string" then return end
        if action == "refresh" then
            local items = getAllItems(player)
            local names = {}
            local seen = {}
            for _, item in ipairs(items) do
                if #names < CONFIG.ITEM_MAX and not seen[item.Name] then
                    seen[item.Name] = true
                    table.insert(names, item.Name)
                end
            end
            itemRemote:FireClient(player, "item_list", names)
        elseif action == "give" then
            local foundTool = nil
            local containers = findToolContainer()
            for _, container in ipairs(containers) do
                local tool = container:FindFirstChild(itemName)
                if tool and tool:IsA("Tool") then foundTool = tool; break end
            end
            if not foundTool then
                local t = ReplicatedStorage:FindFirstChild(itemName)
                if t and t:IsA("Tool") then foundTool = t end
            end
            if not foundTool then
                itemRemote:FireClient(player, "give_result", false, itemName)
                return
            end
            local char = player.Character
            if not char then
                itemRemote:FireClient(player, "give_result", false, itemName)
                return
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            local backpack = player:FindFirstChildOfClass("Backpack")
            if not backpack then
                local t = 0
                while not backpack and t < 5 do
                    task.wait(0.1); t = t + 0.1
                    backpack = player:FindFirstChildOfClass("Backpack")
                end
            end
            if not hum or not backpack then
                itemRemote:FireClient(player, "give_result", false, itemName)
                return
            end
            local clone = foundTool:Clone()
            clone.Parent = backpack
            task.wait(0.05)
            task.spawn(function()
                pcall(function() hum:EquipTool(clone) end)
            end)
            itemRemote:FireClient(player, "give_result", true, itemName)
        end
    end)

    local function hookChar(p)
        p.CharacterAdded:Connect(function()
            task.wait(0.3)
            if activeBomb then tryBombPlayer(p, activeBomb) end
        end)
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then hookChar(p) end
    end
    Players.PlayerAdded:Connect(hookChar)
    Players.PlayerRemoving:Connect(function(p) lastSend[p] = nil end)

    remote.OnServerEvent:Connect(function(player, action, rawText, rawDur, rawSize)
        if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
        if type(action) ~= "string" then return end
        if action == "sky" then
            pcall(function() setSky(rawText) end)
            return
        elseif action == "reset_sky" then
            pcall(resetSky)
            return
        end
        if action ~= "speak" and action ~= "bomb" then return end
        local now = tick()
        local last = lastSend[player] or 0
        if now - last < CONFIG.COOLDOWN then return end
        lastSend[player] = now
        local text = Util.sanitizeText(rawText)
        if not text then return end
        local duration = Util.clampDuration(rawDur)
        local size = Util.clampTextSize(rawSize)
        if not player.Character then return end
        if action == "speak" then
            pcall(function()
                Util.createBubble(player.Character, text, duration, CONFIG.SPEAK_TAG, size)
            end)
        elseif action == "bomb" then
            pcall(function() startBomb(text, duration, size) end)
        end
    end)

    print("[MFH " .. CONFIG.VERSION .. " - 服务端] 已挂载 ✔")
    return
end

--==========================================================--
-- 🎨 客户端
--==========================================================--
print("[MFH] 客户端模式")

local player = Players.LocalPlayer
if not player then
    local w = 0
    while not player and w < 5 do
        task.wait(0.1); w = w + 0.1
        player = Players.LocalPlayer
    end
end
if not player then
    warn("[MFH] 无法获取 LocalPlayer。"); return
end

local playerGui
do
    local ok, r = pcall(function() return player:WaitForChild("PlayerGui", 15) end)
    if ok and r then playerGui = r end
    if not playerGui then pcall(function() playerGui = player:FindFirstChild("PlayerGui") end) end
    if not playerGui then pcall(function() playerGui = player:FindFirstChildOfClass("PlayerGui") end) end
end
if not playerGui then warn("[MFH] 无法获取 PlayerGui。"); return end

do
    local old = playerGui:FindFirstChild("MFH_ScriptUI")
    if old then Util.safeDestroy(old) end
end

--========================================================--
-- 🎨 主题
--========================================================--
local THEME = {
    bg = Color3.fromRGB(18, 18, 26),
    panel = Color3.fromRGB(13, 13, 20),
    card = Color3.fromRGB(26, 27, 38),
    input = Color3.fromRGB(34, 36, 50),
    cardHover = Color3.fromRGB(32, 33, 46),
    accent = Color3.fromRGB(0, 170, 255),
    accentP = Color3.fromRGB(255, 80, 130),
    accentG = Color3.fromRGB(80, 220, 160),
    accentO = Color3.fromRGB(255, 170, 60),
    accentY = Color3.fromRGB(240, 220, 90),
    accentR = Color3.fromRGB(255, 90, 90),
    accentC = Color3.fromRGB(100, 200, 255),
    accentV = Color3.fromRGB(160, 80, 255),
    accentT = Color3.fromRGB(0, 220, 200),
    text = Color3.fromRGB(240, 240, 250),
    subtext = Color3.fromRGB(160, 160, 180),
    placeholder = Color3.fromRGB(110, 110, 130),
    stroke = Color3.fromRGB(255, 255, 255),
    closeBg = Color3.fromRGB(60, 30, 40),
    closeHover = Color3.fromRGB(90, 40, 55),
    tWin = 0.06, tTitleBar = 0.05, tSidebar = 0.35, tInput = 0.15,
    tButton = 0.10, tDot = 0.05,
}
local ANIM = {
    openTime = 0.26, closeTime = 0.18, tabTime = 0.16,
    openStyle = Enum.EasingStyle.Quart, closeStyle = Enum.EasingStyle.Quad, tabStyle = Enum.EasingStyle.Quart,
}
local ROUND = { win = 14, bar = 14, btn = 10, input = 10, tab = 8, card = 10 }

--========================================================--
-- 响应式尺寸
--========================================================--
local function getViewport()
    local cam = workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1920, 1080)
end

local customSize = { w = CONFIG.BASE_W, h = CONFIG.BASE_H }

local function calculateScale()
    local vp = getViewport()
    local sx = (vp.X * 0.90) / customSize.w
    local sy = (vp.Y * 0.88) / customSize.h
    return math.max(math.min(math.min(sx, sy, 1.30), 1.30), 0.55)
end

local uiScale = calculateScale()

--========================================================--
-- ScreenGui
--========================================================--
local gui = Instance.new("ScreenGui")
gui.Name = "MFH_ScriptUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 9999
gui.Parent = playerGui
if not gui.Parent then warn("[MFH] ScreenGui 挂载失败。"); return end

--========================================================--
-- 悬浮球
--========================================================--
local dotSize = math.floor(58 * math.max(uiScale, 0.8))
local dot = Instance.new("Frame")
dot.Name = "MFH_Dot"
dot.Size = UDim2.fromOffset(dotSize, dotSize)
dot.Position = UDim2.new(0, 24, 0.5, -dotSize / 2)
dot.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
dot.BackgroundTransparency = THEME.tDot
dot.BorderSizePixel = 0
dot.Active = true
dot.Parent = gui
local dotCorner = Instance.new("UICorner"); dotCorner.CornerRadius = UDim.new(1, 0); dotCorner.Parent = dot
local dotStroke = Instance.new("UIStroke"); dotStroke.Color = THEME.accent; dotStroke.Thickness = 2; dotStroke.Transparency = 0.15; dotStroke.Parent = dot
local dotGrad = Instance.new("UIGradient")
dotGrad.Color = ColorSequence.new {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 190, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 0, 255))
}
dotGrad.Rotation = 45
dotGrad.Parent = dot
local dotIcon = Instance.new("TextLabel")
dotIcon.Size = UDim2.fromScale(1, 1)
dotIcon.BackgroundTransparency = 1
dotIcon.Text = "M"
dotIcon.TextSize = math.floor(28 * math.max(uiScale, 0.8))
dotIcon.Font = Enum.Font.GothamBlack
dotIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
dotIcon.ZIndex = 2
dotIcon.Parent = dot

--========================================================--
-- 主窗口
--========================================================--
local vp0 = getViewport()
local visualW, visualH = customSize.w * uiScale, customSize.h * uiScale
local win = Instance.new("Frame")
win.Name = "MFH_Window"
win.Size = UDim2.fromOffset(customSize.w, customSize.h)
win.AnchorPoint = Vector2.new(0, 0)
win.Position = UDim2.fromOffset(math.floor((vp0.X - visualW) / 2), math.floor((vp0.Y - visualH) / 2))
win.BackgroundColor3 = THEME.bg
win.BackgroundTransparency = THEME.tWin
win.BorderSizePixel = 0
win.Active = true
win.Visible = false
win.ClipsDescendants = false
win.Parent = gui
local winCorner = Instance.new("UICorner"); winCorner.CornerRadius = UDim.new(0, ROUND.win); winCorner.Parent = win
local winStroke = Instance.new("UIStroke"); winStroke.Color = THEME.stroke; winStroke.Thickness = 1; winStroke.Transparency = 0.85; winStroke.Parent = win
local winGrad = Instance.new("UIGradient")
winGrad.Color = ColorSequence.new {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 38, 54)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 20))
}
winGrad.Rotation = 135
winGrad.Parent = win
local winScale = Instance.new("UIScale"); winScale.Scale = uiScale; winScale.Parent = win

local winClip = Instance.new("Frame")
winClip.Name = "WinClip"
winClip.Size = UDim2.fromScale(1, 1)
winClip.BackgroundTransparency = 1
winClip.ClipsDescendants = true
winClip.ZIndex = 1
winClip.Parent = win
local winClipCorner = Instance.new("UICorner"); winClipCorner.CornerRadius = UDim.new(0, ROUND.win); winClipCorner.Parent = winClip

--========================================================--
-- 窗口重算函数
--========================================================--
local function applyCustomWindowSize(w, h)
    w = math.clamp(math.floor(tonumber(w) or CONFIG.BASE_W), 320, 1920)
    h = math.clamp(math.floor(tonumber(h) or CONFIG.BASE_H), 240, 1080)
    customSize.w = w
    customSize.h = h
    win.Size = UDim2.fromOffset(w, h)
    local vp = getViewport()
    local sx = (vp.X * 0.90) / w
    local sy = (vp.Y * 0.88) / h
    local newScale = math.max(math.min(math.min(sx, sy, 1.30), 1.30), 0.55)
    uiScale = newScale
    winScale.Scale = newScale
    local visW, visH = w * newScale, h * newScale
    win.Position = UDim2.fromOffset(
        math.max(0, math.floor((vp.X - visW) / 2)),
        math.max(0, math.floor((vp.Y - visH) / 2))
    )
end

--========================================================--
-- 标题栏
--========================================================--
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(24, 26, 38)
titleBar.BackgroundTransparency = THEME.tTitleBar
titleBar.BorderSizePixel = 0
titleBar.Active = true
titleBar.Parent = winClip
local titleCorner = Instance.new("UICorner"); titleCorner.CornerRadius = UDim.new(0, ROUND.bar); titleCorner.Parent = titleBar
local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 14)
titleFix.Position = UDim2.new(0, 0, 1, -14)
titleFix.BackgroundColor3 = Color3.fromRGB(24, 26, 38)
titleFix.BackgroundTransparency = THEME.tTitleBar
titleFix.BorderSizePixel = 0
titleFix.ZIndex = 1
titleFix.Parent = titleBar
local titleGrad = Instance.new("UIGradient")
titleGrad.Color = ColorSequence.new {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(44, 48, 66)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 22, 34))
}
titleGrad.Rotation = 90
titleGrad.Parent = titleBar
local brandBar = Instance.new("Frame")
brandBar.Name = "BrandBar"
brandBar.Size = UDim2.new(0, 4, 0, 16)
brandBar.Position = UDim2.new(0, 14, 0.5, 0)
brandBar.AnchorPoint = Vector2.new(0, 0.5)
brandBar.BackgroundColor3 = THEME.accent
brandBar.BorderSizePixel = 0
brandBar.ZIndex = 3
brandBar.Parent = titleBar
local brandBarCorner = Instance.new("UICorner"); brandBarCorner.CornerRadius = UDim.new(1, 0); brandBarCorner.Parent = brandBar
local brandBarGrad = Instance.new("UIGradient")
brandBarGrad.Color = ColorSequence.new {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 190, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 0, 255))
}
brandBarGrad.Rotation = 90
brandBarGrad.Parent = brandBar
local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -260, 1, 0)
titleText.Position = UDim2.new(0, 26, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "MFH 脚本 " .. CONFIG.VERSION
titleText.TextColor3 = THEME.text
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 14
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.ZIndex = 3
titleText.Parent = titleBar
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -38, 0.5, -14)
closeBtn.BackgroundColor3 = THEME.closeBg
closeBtn.BorderSizePixel = 0
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(255, 160, 160)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 4
closeBtn.Parent = titleBar
local closeCorner = Instance.new("UICorner"); closeCorner.CornerRadius = UDim.new(0, 8); closeCorner.Parent = closeBtn
local closeStroke = Instance.new("UIStroke"); closeStroke.Color = Color3.fromRGB(180, 80, 100); closeStroke.Thickness = 1; closeStroke.Transparency = 0.6; closeStroke.Parent = closeBtn
closeBtn.MouseEnter:Connect(function()
    pcall(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.12), { BackgroundColor3 = THEME.closeHover }):Play()
        TweenService:Create(closeStroke, TweenInfo.new(0.12), { Transparency = 0.2 }):Play()
    end)
end)
closeBtn.MouseLeave:Connect(function()
    pcall(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.12), { BackgroundColor3 = THEME.closeBg }):Play()
        TweenService:Create(closeStroke, TweenInfo.new(0.12), { Transparency = 0.6 }):Play()
    end)
end)

--========================================================--
-- 搜索框
--========================================================--
local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(0, 160, 0, 26)
searchBox.Position = UDim2.new(1, -206, 0.5, -13)
searchBox.BackgroundColor3 = THEME.input
searchBox.BackgroundTransparency = 0.3
searchBox.BorderSizePixel = 0
searchBox.Text = ""
searchBox.PlaceholderText = "🔍 搜索功能..."
searchBox.PlaceholderColor3 = THEME.placeholder
searchBox.TextColor3 = THEME.text
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 12
searchBox.ClearTextOnFocus = false
searchBox.ZIndex = 3
searchBox.Parent = titleBar
local searchCorner = Instance.new("UICorner"); searchCorner.CornerRadius = UDim.new(0, 7); searchCorner.Parent = searchBox
local searchStroke = Instance.new("UIStroke"); searchStroke.Color = THEME.stroke; searchStroke.Thickness = 1; searchStroke.Transparency = 0.9; searchStroke.Parent = searchBox
local searchPad = Instance.new("UIPadding"); searchPad.PaddingLeft = UDim.new(0, 10); searchPad.PaddingRight = UDim.new(0, 10); searchPad.Parent = searchBox
searchBox.Focused:Connect(function()
    pcall(function()
        TweenService:Create(searchStroke, TweenInfo.new(0.15), { Color = THEME.accent, Transparency = 0.3 }):Play()
        TweenService:Create(searchBox, TweenInfo.new(0.15), { BackgroundTransparency = 0.1 }):Play()
    end)
end)
searchBox.FocusLost:Connect(function()
    pcall(function()
        TweenService:Create(searchStroke, TweenInfo.new(0.15), { Color = THEME.stroke, Transparency = 0.9 }):Play()
        TweenService:Create(searchBox, TweenInfo.new(0.15), { BackgroundTransparency = 0.3 }):Play()
    end)
end)

--========================================================--
-- 侧边栏
--========================================================--
local SIDEBAR_W = 128
local sidebar = Instance.new("ScrollingFrame")
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, -40)
sidebar.Position = UDim2.new(0, 0, 0, 40)
sidebar.BackgroundColor3 = THEME.panel
sidebar.BackgroundTransparency = THEME.tSidebar
sidebar.BorderSizePixel = 0
sidebar.ScrollBarThickness = 3
sidebar.ScrollBarImageColor3 = THEME.accent
sidebar.ScrollBarImageTransparency = 0.5
sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
sidebar.ScrollingDirection = Enum.ScrollingDirection.Y
sidebar.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
sidebar.Parent = winClip
local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.Padding = UDim.new(0, 4)
sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
sidebarLayout.Parent = sidebar
local sidebarPad = Instance.new("UIPadding")
sidebarPad.PaddingTop = UDim.new(0, 8)
sidebarPad.PaddingBottom = UDim.new(0, 8)
sidebarPad.PaddingLeft = UDim.new(0, 6)
sidebarPad.PaddingRight = UDim.new(0, 6)
sidebarPad.Parent = sidebar

--========================================================--
-- 内容区
--========================================================--
local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, -SIDEBAR_W, 1, -40)
content.Position = UDim2.new(0, SIDEBAR_W, 0, 40)
content.BackgroundTransparency = 1
content.ClipsDescendants = true
content.Parent = winClip
print("[MFH] 主窗口已创建")

--========================================================--
-- UI 工具
--========================================================--
local function makeLabel(parent, text, y, h)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -28, 0, h or 18)
    l.Position = UDim2.new(0, 14, 0, y)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = THEME.subtext
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.Parent = parent
    return l
end

local function makeInput(parent, placeholder, y, default, h)
    h = h or 42
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -28, 0, h)
    box.Position = UDim2.new(0, 14, 0, y)
    box.BackgroundColor3 = THEME.input
    box.BackgroundTransparency = THEME.tInput
    box.BorderSizePixel = 0
    box.Text = default or ""
    box.PlaceholderText = placeholder
    box.PlaceholderColor3 = THEME.placeholder
    box.TextColor3 = THEME.text
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    box.ClearTextOnFocus = false
    box.RichText = false
    box.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, ROUND.input); c.Parent = box
    local s = Instance.new("UIStroke"); s.Color = THEME.stroke; s.Thickness = 1; s.Transparency = 0.88; s.Parent = box
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 14); pad.PaddingRight = UDim.new(0, 14)
    pad.Parent = box
    box.Focused:Connect(function()
        pcall(function()
            TweenService:Create(s, TweenInfo.new(0.15), { Color = THEME.accent, Transparency = 0.25 }):Play()
            TweenService:Create(box, TweenInfo.new(0.15), { BackgroundTransparency = math.max(THEME.tInput - 0.15, 0.05) }):Play()
        end)
    end)
    box.FocusLost:Connect(function()
        pcall(function()
            TweenService:Create(s, TweenInfo.new(0.15), { Color = THEME.stroke, Transparency = 0.88 }):Play()
            TweenService:Create(box, TweenInfo.new(0.15), { BackgroundTransparency = THEME.tInput }):Play()
        end)
    end)
    return box
end

local function makeButton(parent, text, y, color, h)
    color = color or THEME.accent
    h = h or 42
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -28, 0, h)
    b.Position = UDim2.new(0, 14, 0, y)
    b.BackgroundColor3 = color
    b.BackgroundTransparency = THEME.tButton
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 15
    b.AutoButtonColor = false
    b.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, ROUND.btn); c.Parent = b
    local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = 1.5; s.Transparency = 0.55; s.Parent = b
    local base = THEME.tButton
    b.MouseEnter:Connect(function()
        pcall(function()
            TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = math.max(base - 0.15, 0) }):Play()
            TweenService:Create(s, TweenInfo.new(0.12), { Transparency = 0.2 }):Play()
        end)
    end)
    b.MouseLeave:Connect(function()
        pcall(function()
            TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = base }):Play()
            TweenService:Create(s, TweenInfo.new(0.12), { Transparency = 0.55 }):Play()
        end)
    end)
    b.MouseButton1Down:Connect(function()
        pcall(function()
            TweenService:Create(b, TweenInfo.new(0.06), { BackgroundTransparency = 0 }):Play()
        end)
    end)
    b.MouseButton1Up:Connect(function()
        pcall(function()
            TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = math.max(base - 0.15, 0) }):Play()
        end)
    end)
    return b
end

local function makeStatus(parent, y)
    local s = Instance.new("TextLabel")
    s.Size = UDim2.new(1, -28, 0, 32)
    s.Position = UDim2.new(0, 14, 0, y)
    s.BackgroundColor3 = THEME.card
    s.BackgroundTransparency = 0.4
    s.BorderSizePixel = 0
    s.Text = "状态：已关闭"
    s.TextColor3 = THEME.subtext
    s.Font = Enum.Font.GothamBold
    s.TextSize = 13
    s.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, ROUND.card); c.Parent = s
    local st = Instance.new("UIStroke"); st.Color = THEME.stroke; st.Thickness = 1; st.Transparency = 0.9; st.Parent = s
    return s
end

local function bindNumericOnly(box, maxLen, allowDot)
    maxLen = maxLen or 3
    box:GetPropertyChangedSignal("Text"):Connect(function()
        local pattern = allowDot and "[^%d%.]" or "[^%d]"
        local clean = box.Text:gsub(pattern, "")
        if allowDot then
            local fd = clean:find("%.")
            if fd then
                clean = clean:sub(1, fd) .. clean:sub(fd + 1):gsub("%.", "")
            end
        end
        if #clean > maxLen then clean = clean:sub(1, maxLen) end
        if clean ~= box.Text then box.Text = clean end
    end)
end

--========================================================--
-- 标签页系统
--========================================================--
local allTabs, allPanels, currentTab, tabAnimating = {}, {}, nil, false
local tabOrder = 0

local function switchTab(key)
    if currentTab == key or tabAnimating then return end
    tabAnimating = true
    local oldKey = currentTab
    currentTab = key
    local btnInfo = TweenInfo.new(ANIM.tabTime, ANIM.tabStyle, Enum.EasingDirection.Out)
    for k, data in pairs(allTabs) do
        if k == key then
            TweenService:Create(data.btn, btnInfo, {
                BackgroundTransparency = 0.15,
                BackgroundColor3 = THEME.accent,
                TextColor3 = Color3.fromRGB(255, 255, 255),
            }):Play()
            TweenService:Create(data.indicator, btnInfo, { Size = UDim2.new(0, 3, 0, 18) }):Play()
        else
            TweenService:Create(data.btn, btnInfo, {
                BackgroundTransparency = 1,
                TextColor3 = THEME.subtext,
            }):Play()
            TweenService:Create(data.indicator, btnInfo, { Size = UDim2.new(0, 3, 0, 0) }):Play()
        end
    end
    local newPanel = allPanels[key]
    if not newPanel then tabAnimating = false; return end
    if oldKey and allPanels[oldKey] and allPanels[oldKey] ~= newPanel then
        local oldPanel = allPanels[oldKey]
        local tg = TweenService:Create(oldPanel, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(-0.03, 0, 0, 0) })
        tg:Play()
        tg.Completed:Connect(function()
            oldPanel.Visible = false
            oldPanel.Position = UDim2.fromScale(0, 0)
        end)
    end
    newPanel.Visible = true
    newPanel.Position = UDim2.new(0.03, 0, 0, 0)
    if newPanel:IsA("ScrollingFrame") then newPanel.CanvasPosition = Vector2.zero end
    local inTween = TweenService:Create(newPanel, TweenInfo.new(ANIM.tabTime, ANIM.tabStyle, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0, 0) })
    inTween:Play()
    inTween.Completed:Connect(function() tabAnimating = false end)
end

local function createTab(key, name)
    tabOrder = tabOrder + 1
    local container = Instance.new("Frame")
    container.Name = "TabContainer_" .. key
    container.Size = UDim2.new(1, 0, 0, 32)
    container.BackgroundTransparency = 1
    container.LayoutOrder = tabOrder
    container.Parent = sidebar
    local btn = Instance.new("TextButton")
    btn.Name = "Tab_" .. key
    btn.Size = UDim2.fromScale(1, 1)
    btn.BackgroundColor3 = THEME.accent
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = THEME.subtext
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.Parent = container
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, ROUND.tab); c.Parent = btn
    local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 18); pad.Parent = btn
    local indicator = Instance.new("Frame")
    indicator.Name = "Indicator"
    indicator.Size = UDim2.new(0, 3, 0, 0)
    indicator.Position = UDim2.new(0, 6, 0.5, 0)
    indicator.AnchorPoint = Vector2.new(0, 0.5)
    indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    indicator.BorderSizePixel = 0
    indicator.ZIndex = 2
    indicator.Parent = container
    local indCorner = Instance.new("UICorner"); indCorner.CornerRadius = UDim.new(1, 0); indCorner.Parent = indicator
    local data = { btn = btn, indicator = indicator, container = container, keywords = "" }
    allTabs[key] = data
    btn.MouseEnter:Connect(function()
        if currentTab ~= key then
            pcall(function()
                TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundTransparency = 0.9, TextColor3 = THEME.text }):Play()
            end)
        end
    end)
    btn.MouseLeave:Connect(function()
        if currentTab ~= key then
            pcall(function()
                TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundTransparency = 1, TextColor3 = THEME.subtext }):Play()
            end)
        end
    end)
    btn.MouseButton1Click:Connect(function() pcall(switchTab, key) end)
    return btn
end

local function createPanel(key)
    local p = Instance.new("ScrollingFrame")
    p.Name = "Panel_" .. key
    p.Size = UDim2.fromScale(1, 1)
    p.Position = UDim2.fromScale(0, 0)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 4
    p.ScrollBarImageColor3 = THEME.accent
    p.ScrollBarImageTransparency = 0.4
    p.CanvasSize = UDim2.new(0, 0, 0, 0)
    p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.ScrollingDirection = Enum.ScrollingDirection.Y
    p.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
    p.Visible = false
    p.Parent = content
    allPanels[key] = p
    return p
end

local buildErrors = {}
local function safeBuild(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        warn("[MFH] 构建 " .. name .. " 失败: " .. tostring(err))
        table.insert(buildErrors, name)
    end
end

--========================================================--
-- 创建所有面板
--========================================================--
safeBuild("speak", function()
    local p = createPanel("speak")
    makeLabel(p, "💬 说话（头顶气泡 · 所有人可见）", 14, 24)
    local input = makeInput(p, "输入你想说的话...", 42)
    makeLabel(p, "消失时长（秒，1 - 60）", 92)
    local dur = makeInput(p, "默认 3", 108, "3", 36)
    makeLabel(p, "文字大小（1 - 10，默认 5）", 152)
    local size = makeInput(p, "默认 5", 168, "5", 36)
    local btn = makeButton(p, "发送到头顶", 216, THEME.accent)
    bindNumericOnly(dur, 3); bindNumericOnly(size, 2)
    _G.MFH_speakInput = input; _G.MFH_speakDur = dur; _G.MFH_speakSize = size
    _G.MFH_speakBtn = btn
end)

safeBuild("bomb", function()
    local p = createPanel("bomb")
    makeLabel(p, "💥 霸屏（所有玩家头顶同时刷屏）", 14, 24)
    local input = makeInput(p, "输入要霸屏的内容...", 42)
    makeLabel(p, "消失时长（秒，1 - 60）", 92)
    local dur = makeInput(p, "默认 5", 108, "5", 36)
    makeLabel(p, "文字大小（1 - 10，默认 5）", 152)
    local size = makeInput(p, "默认 5", 168, "5", 36)
    local btn = makeButton(p, "开始霸屏", 216, THEME.accentP)
    bindNumericOnly(dur, 3); bindNumericOnly(size, 2)
    _G.MFH_bombInput = input; _G.MFH_bombDur = dur; _G.MFH_bombSize = size
    _G.MFH_bombBtn = btn
end)

safeBuild("saveTP", function()
    local p = createPanel("saveTP")
    makeLabel(p, "📍 保存传送（保存位置 · 随时传送）", 14, 24)
    local status = makeStatus(p, 44)
    status.Text = "尚未保存位置"
    local saveBtn = makeButton(p, "💾 保存当前位置", 84, THEME.accentG)
    local tpBtn = makeButton(p, "🚀 传送到保存位置", 130, THEME.accent)
    local clearBtn = makeButton(p, "❌ 清除保存的位置", 176, THEME.accentP)
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, -28, 0, 60)
    infoLabel.Position = UDim2.new(0, 14, 0, 228)
    infoLabel.BackgroundColor3 = THEME.card
    infoLabel.BackgroundTransparency = 0.4
    infoLabel.BorderSizePixel = 0
    infoLabel.Text = "位置信息：未保存"
    infoLabel.TextColor3 = THEME.text
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 12
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top
    infoLabel.TextWrapped = true
    infoLabel.Parent = p
    local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(0, ROUND.card); ic.Parent = infoLabel
    local ist = Instance.new("UIStroke"); ist.Color = THEME.stroke; ist.Thickness = 1; ist.Transparency = 0.9; ist.Parent = infoLabel
    local ip = Instance.new("UIPadding")
    ip.PaddingLeft = UDim.new(0, 12); ip.PaddingTop = UDim.new(0, 8); ip.PaddingRight = UDim.new(0, 12)
    ip.Parent = infoLabel
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -28, 0, 100)
    hint.Position = UDim2.new(0, 14, 0, 298)
    hint.BackgroundTransparency = 1
    hint.Text = "使用方法：\n· 站在想要保存的位置，点击「保存当前位置」\n· 之后无论走到哪里，点击「传送到保存位置」\n· 位置数据会一直保留，除非点击清除"
    hint.TextColor3 = THEME.subtext
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.TextWrapped = true
    hint.Parent = p

    local saveTPState = { savedCFrame = nil, savedPos = nil }
    local function updateSaveTPStatus()
        if saveTPState.savedCFrame then
            status.Text = "✅ 已保存位置，可以随时传送"
            status.TextColor3 = THEME.accentG
            infoLabel.Text = string.format("位置信息：\nX: %.1f\nY: %.1f\nZ: %.1f",
                saveTPState.savedPos.X, saveTPState.savedPos.Y, saveTPState.savedPos.Z)
        else
            status.Text = "尚未保存位置"
            status.TextColor3 = THEME.subtext
            infoLabel.Text = "位置信息：未保存"
        end
    end

    saveBtn.MouseButton1Click:Connect(function()
        local char = player.Character
        if not char then status.Text = "❌ 角色不存在"; status.TextColor3 = THEME.accentR; return end
        local root = Util.getRoot(char)
        if not root then status.Text = "❌ 无法获取位置"; status.TextColor3 = THEME.accentR; return end
        saveTPState.savedCFrame = root.CFrame
        saveTPState.savedPos = root.Position
        updateSaveTPStatus()
    end)

    tpBtn.MouseButton1Click:Connect(function()
        if not saveTPState.savedCFrame then
            status.Text = "❌ 请先保存位置"
            status.TextColor3 = THEME.accentR
            return
        end
        task.spawn(function()
            for i = 1, 5 do
                local char = player.Character
                if not char then break end
                local root = Util.getRoot(char)
                if root then
                    pcall(function()
                        root.CFrame = saveTPState.savedCFrame + Vector3.new(0, 0.5, 0)
                    end)
                end
                task.wait(0.05)
            end
        end)
        status.Text = "✅ 已传送到保存位置"
        status.TextColor3 = THEME.accentG
        task.delay(2, function()
            if saveTPState.savedCFrame then
                status.Text = "✅ 已保存位置，可以随时传送"
                status.TextColor3 = THEME.accentG
            end
        end)
    end)

    clearBtn.MouseButton1Click:Connect(function()
        saveTPState.savedCFrame = nil
        saveTPState.savedPos = nil
        updateSaveTPStatus()
    end)
    _G.MFH_saveTPStatus = status
end)

safeBuild("items", function()
    local p = createPanel("items")
    makeLabel(p, "🎁 道具获取（选择想要的道具）", 14, 24)
    local status = makeStatus(p, 44)
    status.Text = "点击「刷新道具」获取可用道具列表"
    local refreshBtn = makeButton(p, "🔄 刷新道具列表", 84, THEME.accentT)
    local listContainer = Instance.new("Frame")
    listContainer.Size = UDim2.new(1, -28, 0, 340)
    listContainer.Position = UDim2.new(0, 14, 0, 132)
    listContainer.BackgroundColor3 = THEME.card
    listContainer.BackgroundTransparency = 0.4
    listContainer.BorderSizePixel = 0
    listContainer.Parent = p
    local lc = Instance.new("UICorner"); lc.CornerRadius = UDim.new(0, ROUND.card); lc.Parent = listContainer
    local lst = Instance.new("UIStroke"); lst.Color = THEME.stroke; lst.Thickness = 1; lst.Transparency = 0.9; lst.Parent = listContainer
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.fromScale(1, 1)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = THEME.accentT
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = listContainer
    local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 6); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = scroll
    local spad = Instance.new("UIPadding")
    spad.PaddingLeft = UDim.new(0, 8); spad.PaddingTop = UDim.new(0, 8)
    spad.PaddingRight = UDim.new(0, 8); spad.PaddingBottom = UDim.new(0, 8)
    spad.Parent = scroll
    local itemRemote = ReplicatedStorage:FindFirstChild(CONFIG.ITEM_REMOTE)
    local itemList = {}
    local function clearList()
        for _, c in ipairs(scroll:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then Util.safeDestroy(c) end
        end
    end
    local function renderItems(names)
        clearList()
        if #names == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1, 0, 0, 40)
            empty.BackgroundTransparency = 1
            empty.Text = "未找到道具，请确认服务端已运行"
            empty.TextColor3 = THEME.subtext
            empty.Font = Enum.Font.Gotham
            empty.TextSize = 12
            empty.Parent = scroll
            return
        end
        for i, name in ipairs(names) do
            local btn = Instance.new("TextButton")
            btn.Name = "Item_" .. name
            btn.Size = UDim2.new(1, -8, 0, 34)
            btn.BackgroundColor3 = THEME.accentT
            btn.BackgroundTransparency = 0.35
            btn.BorderSizePixel = 0
            btn.Text = "🎁 " .. name
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 13
            btn.AutoButtonColor = false
            btn.LayoutOrder = i
            btn.Parent = scroll
            local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 6); bc.Parent = btn
            local bs = Instance.new("UIStroke"); bs.Color = THEME.accentT; bs.Thickness = 1; bs.Transparency = 0.6; bs.Parent = btn
            btn.MouseEnter:Connect(function()
                pcall(function()
                    TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundTransparency = 0.1 }):Play()
                end)
            end)
            btn.MouseLeave:Connect(function()
                pcall(function()
                    TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundTransparency = 0.35 }):Play()
                end)
            end)
            btn.MouseButton1Click:Connect(function()
                if itemRemote then
                    itemRemote:FireServer("give", name)
                    status.Text = "⏳ 正在获取：" .. name
                    status.TextColor3 = THEME.accentY
                end
            end)
        end
    end
    if itemRemote then
        itemRemote.OnClientEvent:Connect(function(action, arg1, arg2)
            if action == "item_list" then
                itemList = arg1 or {}
                renderItems(itemList)
                status.Text = "✅ 已刷新，共 " .. #itemList .. " 个道具"
                status.TextColor3 = THEME.accentG
            elseif action == "give_result" then
                if arg1 then
                    status.Text = "✅ 已获得道具：" .. tostring(arg2)
                    status.TextColor3 = THEME.accentG
                else
                    status.Text = "❌ 获取失败：" .. tostring(arg2)
                    status.TextColor3 = THEME.accentR
                end
            end
        end)
    end
    refreshBtn.MouseButton1Click:Connect(function()
        if itemRemote then
            itemRemote:FireServer("refresh")
            status.Text = "⏳ 正在刷新道具列表..."
            status.TextColor3 = THEME.accentY
        else
            status.Text = "❌ 未找到道具远程事件，请先运行服务端"
            status.TextColor3 = THEME.accentR
        end
    end)
    _G.MFH_itemStatus = status
end)

safeBuild("fly", function()
    local p = createPanel("fly")
    makeLabel(p, "✈ 飞行模式（摇杆 + 键盘）", 14, 24)
    local status = makeStatus(p, 44)
    makeLabel(p, "飞行速度（10 - 500）", 82)
    local spd = makeInput(p, "默认 60", 100, tostring(CONFIG.FLY_DEFAULT_SPEED), 38)
    local btn = makeButton(p, "开启飞行", 152, THEME.accentG)
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -28, 0, 160)
    hint.Position = UDim2.new(0, 14, 0, 208)
    hint.BackgroundTransparency = 1
    hint.Text = "· 手机：用游戏原生摇杆移动\n· 上升：右下角 ⬆ 按钮\n· 下降：右下角 ⬇ 按钮\n· 键盘：WASD + 空格 + 左Ctrl"
    hint.TextColor3 = THEME.subtext
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.TextWrapped = true
    hint.Parent = p
    _G.MFH_flyStatus = status; _G.MFH_flySpeedInput = spd; _G.MFH_flyToggleBtn = btn
end)

safeBuild("revive", function()
    local p = createPanel("revive")
    makeLabel(p, "♻ 原地复活（死亡位置重生）", 14, 24)
    local status = makeStatus(p, 44)
    local btn = makeButton(p, "开启原地复活", 84, THEME.accentO)
    _G.MFH_reviveStatus = status; _G.MFH_reviveToggleBtn = btn
end)

safeBuild("heal", function()
    local p = createPanel("heal")
    makeLabel(p, "❤ 循环回血（间隔恢复满血）", 14, 24)
    local status = makeStatus(p, 44)
    makeLabel(p, "回血间隔（秒，0.05 - 60）", 82)
    local iv = makeInput(p, "默认 0.5", 100, tostring(CONFIG.HEAL_DEFAULT_INTERVAL), 38)
    local btn = makeButton(p, "开启循环回血", 152, THEME.accentG)
    bindNumericOnly(iv, 5, true)
    _G.MFH_healStatus = status; _G.MFH_healIntervalInput = iv; _G.MFH_healToggleBtn = btn
end)

safeBuild("anti", function()
    local p = createPanel("anti")
    makeLabel(p, "🛡 防甩飞（关闭碰撞箱）", 14, 24)
    local status = makeStatus(p, 44)
    local btn = makeButton(p, "开启防甩飞", 84, THEME.accentY)
    _G.MFH_antiStatus = status; _G.MFH_antiToggleBtn = btn
end)

safeBuild("fling", function()
    local p = createPanel("fling")
    makeLabel(p, "💫 甩飞（碰到谁就甩谁）", 14, 24)
    local status = makeStatus(p, 44)
    makeLabel(p, "甩飞力度（100 - 3000）", 82)
    local pw = makeInput(p, "默认 800", 100, tostring(CONFIG.FLING_POWER_DEFAULT), 38)
    local btn = makeButton(p, "开启甩飞模式", 152, THEME.accentR)
    bindNumericOnly(pw, 4)
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -28, 0, 100)
    hint.Position = UDim2.new(0, 14, 0, 208)
    hint.BackgroundTransparency = 1
    hint.Text = "· 触碰检测：只有真的碰到人，他才会被甩飞\n· 使用贴身距离判定（4 studs）\n· 你自己不会被甩\n· 冷却 0.3 秒，避免同一个人被连续甩飞"
    hint.TextColor3 = THEME.subtext
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.TextWrapped = true
    hint.Parent = p
    _G.MFH_flingStatus = status; _G.MFH_flingPowerInput = pw; _G.MFH_flingToggleBtn = btn
end)

safeBuild("fling2", function()
    local p = createPanel("fling2")
    makeLabel(p, "🌀 甩飞2（旋转甩飞 · 碰到谁甩谁）", 14, 24)
    local status = makeStatus(p, 44)
    makeLabel(p, "甩飞力度（100 - 3000）", 82)
    local pw = makeInput(p, "默认 1200", 100, "1200", 38)
    makeLabel(p, "旋转速度（10 - 500）", 144)
    local spin = makeInput(p, "默认 100", 162, "100", 38)
    local btn = makeButton(p, "开启甩飞2", 214, THEME.accentV)
    bindNumericOnly(pw, 4); bindNumericOnly(spin, 3)
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -28, 0, 100)
    hint.Position = UDim2.new(0, 14, 0, 270)
    hint.BackgroundTransparency = 1
    hint.Text = "· 触碰检测：真的碰到才触发\n· 附带旋转力矩，甩飞效果更强\n· 角速度每次清零避免乱转\n· 你自己不会被甩"
    hint.TextColor3 = THEME.subtext
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.TextWrapped = true
    hint.Parent = p
    _G.MFH_fling2Status = status; _G.MFH_fling2PowerInput = pw
    _G.MFH_fling2SpinInput = spin; _G.MFH_fling2ToggleBtn = btn
end)

safeBuild("esp", function()
    local p = createPanel("esp")
    makeLabel(p, "👁 ESP 透视（穿墙看到玩家）", 14, 24)
    local status = makeStatus(p, 44)
    local btn = makeButton(p, "开启 ESP", 84, THEME.accentC)
    _G.MFH_espStatus = status; _G.MFH_espToggleBtn = btn
end)

safeBuild("move", function()
    local p = createPanel("move")
    makeLabel(p, "🏃 移动增强", 14, 24)
    makeLabel(p, "移动速度（16 - 500）", 44)
    local spd = makeInput(p, "默认 16", 60, tostring(CONFIG.SPEED_DEFAULT), 36)
    makeLabel(p, "跳跃力（50 - 500）", 104)
    local jp = makeInput(p, "默认 50", 120, tostring(CONFIG.JUMP_DEFAULT), 36)
    local sBtn = makeButton(p, "应用速度", 166, THEME.accentG)
    local jBtn = makeButton(p, "应用跳跃力", 212, THEME.accentG)
    local rBtn = makeButton(p, "重置为默认", 258, THEME.accentP)
    bindNumericOnly(spd, 3); bindNumericOnly(jp, 3)
    _G.MFH_speedInput = spd; _G.MFH_jumpInput = jp
    _G.MFH_speedApplyBtn = sBtn; _G.MFH_jumpApplyBtn = jBtn; _G.MFH_speedResetBtn = rBtn
end)

safeBuild("noclip", function()
    local p = createPanel("noclip")
    makeLabel(p, "🧱 穿墙 Noclip（穿透墙壁）", 14, 24)
    local status = makeStatus(p, 44)
    local btn = makeButton(p, "开启穿墙", 84, THEME.accentO)
    _G.MFH_noclipStatus = status; _G.MFH_noclipToggleBtn = btn
end)

safeBuild("utility", function()
    local p = createPanel("utility")
    makeLabel(p, "🔧 工具与实用功能", 14, 24)
    local b1 = makeButton(p, "开启无限体力", 50, THEME.accentG)
    local b2 = makeButton(p, "开启全亮模式", 96, THEME.accentY)
    local b3 = makeButton(p, "开启无重力", 142, THEME.accentO)
    local b4 = makeButton(p, "开启自动重连", 188, THEME.accentC)
    local b5 = makeButton(p, "开启反挂机", 234, THEME.accentC)
    local status = makeStatus(p, 282)
    _G.MFH_infiniteStaminaBtn = b1; _G.MFH_fullbrightBtn = b2
    _G.MFH_noGravityBtn = b3; _G.MFH_autoRejoinBtn = b4
    _G.MFH_antiAfkBtn = b5; _G.MFH_utilityStatus = status
end)

safeBuild("tracker", function()
    local p = createPanel("tracker")
    makeLabel(p, "📍 玩家追踪", 14, 24)
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -28, 0, 100)
    info.Position = UDim2.new(0, 14, 0, 44)
    info.BackgroundColor3 = THEME.card
    info.BackgroundTransparency = 0.4
    info.BorderSizePixel = 0
    info.Text = "加载中..."
    info.TextColor3 = THEME.text
    info.Font = Enum.Font.Gotham
    info.TextSize = 12
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextYAlignment = Enum.TextYAlignment.Top
    info.TextWrapped = true
    info.Parent = p
    local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(0, ROUND.card); ic.Parent = info
    local ist = Instance.new("UIStroke"); ist.Color = THEME.stroke; ist.Thickness = 1; ist.Transparency = 0.9; ist.Parent = info
    local ip = Instance.new("UIPadding")
    ip.PaddingLeft = UDim.new(0, 12); ip.PaddingTop = UDim.new(0, 10); ip.PaddingRight = UDim.new(0, 12)
    ip.Parent = info
    local refreshBtn = makeButton(p, "刷新玩家列表", 156, THEME.accent)
    local tpContainer = Instance.new("Frame")
    tpContainer.Size = UDim2.new(1, -28, 0, 260)
    tpContainer.Position = UDim2.new(0, 14, 0, 206)
    tpContainer.BackgroundColor3 = THEME.card
    tpContainer.BackgroundTransparency = 0.4
    tpContainer.BorderSizePixel = 0
    tpContainer.Parent = p
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, ROUND.card); tc.Parent = tpContainer
    local tst = Instance.new("UIStroke"); tst.Color = THEME.stroke; tst.Thickness = 1; tst.Transparency = 0.9; tst.Parent = tpContainer
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.fromScale(1, 1)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = THEME.accent
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = tpContainer
    local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 4); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = scroll
    local tpad = Instance.new("UIPadding")
    tpad.PaddingLeft = UDim.new(0, 8); tpad.PaddingTop = UDim.new(0, 8)
    tpad.PaddingRight = UDim.new(0, 8); tpad.PaddingBottom = UDim.new(0, 8)
    tpad.Parent = scroll
    _G.MFH_trackerInfo = info; _G.MFH_trackerRefreshBtn = refreshBtn; _G.MFH_tpScroll = scroll
end)

safeBuild("combat", function()
    local p = createPanel("combat")
    makeLabel(p, "⚔️ 战斗辅助", 14, 24)
    local b1 = makeButton(p, "开启自动格挡", 50, THEME.accentR)
    local b2 = makeButton(p, "开启自动闪避", 96, THEME.accentR)
    local b3 = makeButton(p, "开启自动招架", 142, THEME.accentR)
    local b4 = makeButton(p, "开启击杀光环", 188, THEME.accentR)
    local b5 = makeButton(p, "开启命中框扩展", 234, THEME.accentR)
    local status = makeStatus(p, 282)
    _G.MFH_autoBlockBtn = b1; _G.MFH_autoDodgeBtn = b2
    _G.MFH_autoParryBtn = b3; _G.MFH_killAuraBtn = b4
    _G.MFH_hitboxExpanderBtn = b5; _G.MFH_combatStatus = status
end)

safeBuild("server", function()
    local p = createPanel("server")
    makeLabel(p, "🖥️ 服务器功能", 14, 24)
    local b1 = makeButton(p, "传送所有人到我身边", 50, THEME.accentC)
    local b2 = makeButton(p, "召集所有人到我身边", 96, THEME.accentC)
    local b3 = makeButton(p, "冻结所有玩家", 142, THEME.accentC)
    local b4 = makeButton(p, "解冻所有玩家", 188, THEME.accentG)
    local b5 = makeButton(p, "服务器跳跃", 234, THEME.accentY)
    _G.MFH_teleportAllBtn = b1; _G.MFH_bringAllBtn = b2
    _G.MFH_freezeAllBtn = b3; _G.MFH_unfreezeAllBtn = b4; _G.MFH_serverHopBtn = b5
end)

safeBuild("exploits", function()
    local p = createPanel("exploits")
    makeLabel(p, "🛠 漏洞利用区", 14, 24)
    local b1 = makeButton(p, "开启无限跳跃", 50, THEME.accentG)
    local b2 = makeButton(p, "开启点击传送", 96, THEME.accentO)
    local b3 = makeButton(p, "开启无敌模式（本地）", 142, THEME.accentR)
    local b4 = makeButton(p, "开启隐身（本地）", 188, THEME.accentC)
    local status = makeStatus(p, 240)
    _G.MFH_infJumpBtn = b1; _G.MFH_clickTPBtn = b2
    _G.MFH_godModeBtn = b3; _G.MFH_invisBtn = b4
    _G.MFH_exploitsStatus = status
end)

safeBuild("objectcontrol", function()
    local p = createPanel("objectcontrol")
    makeLabel(p, "🖐 控制物体（抓取 / 移动 / 投掷）", 14, 24)
    local status = makeStatus(p, 44)
    status.Text = "点击「开启控制物体」后点击物体进行抓取"
    local grabBtn = makeButton(p, "开启控制物体", 84, THEME.accentT)
    makeLabel(p, "抓取范围（10 - 100 studs）", 132)
    local rangeInput = makeInput(p, "默认 30", 150, tostring(CONFIG.GRAB_RANGE), 36)
    makeLabel(p, "投掷力度（10 - 1000）", 194)
    local throwInput = makeInput(p, "默认 150", 212, tostring(CONFIG.THROW_POWER), 36)
    bindNumericOnly(rangeInput, 3); bindNumericOnly(throwInput, 4)
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -28, 0, 120)
    hint.Position = UDim2.new(0, 14, 0, 262)
    hint.BackgroundTransparency = 1
    hint.Text = "操作说明：\n· 点击「开启控制物体」后，鼠标点击任意物体即可抓取\n· 抓取后物体跟随鼠标移动\n· 再次点击鼠标即可投掷物体\n· 靠近玩家时也可以抓取玩家\n· 按 Q 键释放物体"
    hint.TextColor3 = THEME.subtext
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.TextWrapped = true
    hint.Parent = p
    _G.MFH_grabStatus = status
    _G.MFH_grabToggleBtn = grabBtn
    _G.MFH_grabRangeInput = rangeInput
    _G.MFH_grabThrowInput = throwInput
end)

safeBuild("fe", function()
    local p = createPanel("fe")
    makeLabel(p, "⚡ FE 功能（过滤启用绕过）", 14, 24)
    local status = makeStatus(p, 44)
    status.Text = "FE 功能：让客户端效果影响服务器"
    local b1 = makeButton(p, "FE 无重力（所有人可见）", 84, THEME.accentT)
    local b2 = makeButton(p, "FE 角色飞升（拉高角色）", 130, THEME.accentT)
    local b3 = makeButton(p, "FE 强制跳舞（所有人可见）", 176, THEME.accentT)
    local b4 = makeButton(p, "FE 无限跳跃（所有人可见）", 222, THEME.accentT)
    local b5 = makeButton(p, "FE 火焰特效（所有人可见）", 268, THEME.accentT)
    local b6 = makeButton(p, "FE 冰霜特效（所有人可见）", 314, THEME.accentT)
    local b7 = makeButton(p, "FE 时间加速（所有人可见）", 360, THEME.accentT)
    local b8 = makeButton(p, "FE 角色放大（所有人可见）", 406, THEME.accentT)
    local b9 = makeButton(p, "FE 拖尾特效（所有人可见）", 452, THEME.accentT)
    local b10 = makeButton(p, "FE 高空传送（瞬移到高空）", 498, THEME.accentT)
    local b11 = makeButton(p, "FE 冻结周围玩家（20 studs）", 544, THEME.accentT)
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -28, 0, 80)
    hint.Position = UDim2.new(0, 14, 0, 596)
    hint.BackgroundTransparency = 1
    hint.Text = "· FE 功能通过远程事件影响服务器状态\n· 部分功能需服务端脚本配合\n· 效果持续时间因游戏而异"
    hint.TextColor3 = THEME.subtext
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.TextWrapped = true
    hint.Parent = p
    _G.MFH_feStatus = status
    _G.MFH_feNoGravityBtn = b1; _G.MFH_feLiftBtn = b2
    _G.MFH_feDanceBtn = b3; _G.MFH_feInfJumpBtn = b4
    _G.MFH_feFireBtn = b5; _G.MFH_feFrostBtn = b6
    _G.MFH_feTimeBtn = b7; _G.MFH_feScaleBtn = b8
    _G.MFH_feTrailBtn = b9; _G.MFH_feSkyTPBtn = b10; _G.MFH_feFreezeBtn = b11
end)

safeBuild("textsky", function()
    local p = createPanel("textsky")
    makeLabel(p, "🌌 文字天空（天空变成文字）", 14, 24)
    local status = makeStatus(p, 44)
    status.Text = "输入文字后点击「设置文字天空」"
    makeLabel(p, "输入显示在天空的文字：", 82)
    local textInput = makeInput(p, "输入天空文字...", 102, "", 38)
    local applyBtn = makeButton(p, "☁ 设置文字天空", 154, THEME.accentV)
    local resetBtn = makeButton(p, "🔙 恢复默认天空", 200, THEME.accentP)
    makeLabel(p, "文字颜色：", 258)
    local colorRow = Instance.new("Frame")
    colorRow.Size = UDim2.new(1, -28, 0, 40)
    colorRow.Position = UDim2.new(0, 14, 0, 278)
    colorRow.BackgroundTransparency = 1
    colorRow.Parent = p
    local colorLayout = Instance.new("UIListLayout")
    colorLayout.FillDirection = Enum.FillDirection.Horizontal
    colorLayout.Padding = UDim.new(0, 8)
    colorLayout.Parent = colorRow
    local textSkyColor = Color3.fromRGB(255, 255, 255)
    local colorDefs = {
        { Color3.fromRGB(255, 255, 255), "⚪" },
        { Color3.fromRGB(255, 90, 90), "🔴" },
        { Color3.fromRGB(100, 200, 255), "🔵" },
        { Color3.fromRGB(80, 220, 160), "🟢" },
        { Color3.fromRGB(240, 220, 90), "🟡" },
        { Color3.fromRGB(160, 80, 255), "🟣" },
    }
    for _, cd in ipairs(colorDefs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.fromOffset(40, 40)
        btn.BackgroundColor3 = cd[1]
        btn.BackgroundTransparency = 0.3
        btn.BorderSizePixel = 0
        btn.Text = cd[2]
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 18
        btn.AutoButtonColor = false
        btn.Parent = colorRow
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = btn
        local s = Instance.new("UIStroke"); s.Color = THEME.stroke; s.Thickness = 1; s.Transparency = 0.7; s.Parent = btn
        btn.MouseButton1Click:Connect(function()
            textSkyColor = cd[1]
            for _, b in ipairs(colorRow:GetChildren()) do
                if b:IsA("TextButton") then
                    TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0.3 }):Play()
                end
            end
            TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundTransparency = 0 }):Play()
        end)
    end
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -28, 0, 100)
    hint.Position = UDim2.new(0, 14, 0, 330)
    hint.BackgroundTransparency = 1
    hint.Text = "说明：\n· 输入文字后点击设置，天空将显示你的文字\n· 支持中文、英文、数字\n· 点击「恢复默认天空」可清除\n· 文字跟随相机，抬头看向天空即可"
    hint.TextColor3 = THEME.subtext
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.TextWrapped = true
    hint.Parent = p
    _G.MFH_textSkyStatus = status
    _G.MFH_textSkyInput = textInput
    _G.MFH_textSkyApplyBtn = applyBtn
    _G.MFH_textSkyResetBtn = resetBtn
    _G.MFH_textSkyGetColor = function() return textSkyColor end
end)

safeBuild("beautify", function()
    local p = createPanel("beautify")
    makeLabel(p, "🎨 美化包（天空盒 + 自定义）", 14, 24)
    makeLabel(p, "预设天空盒：", 44)
    local presets = {
        { name = "🌅 黄昏", id = "rbxassetid://169210090" },
        { name = "🌙 夜晚", id = "rbxassetid://169210121" },
        { name = "🌌 太空", id = "rbxassetid://169210133" },
        { name = "🌸 动漫", id = "rbxassetid://196263782" },
    }
    local y = 62
    for _, preset in ipairs(presets) do
        local btn = makeButton(p, preset.name, y, THEME.accentC, 34)
        btn.MouseButton1Click:Connect(function()
            local remote = ReplicatedStorage:FindFirstChild(CONFIG.REMOTE_NAME)
            if remote then
                pcall(function() remote:FireServer("sky", preset.id, 0, 0) end)
            else
                pcall(function()
                    local sky = Lighting:FindFirstChildOfClass("Sky")
                    if not sky then sky = Instance.new("Sky"); sky.Parent = Lighting end
                    sky.SkyboxBk = preset.id; sky.SkyboxDn = preset.id
                    sky.SkyboxFt = preset.id; sky.SkyboxLf = preset.id
                    sky.SkyboxRt = preset.id; sky.SkyboxUp = preset.id
                end)
            end
            if _G.MFH_beautifyStatus then
                _G.MFH_beautifyStatus.Text = "✅ 已应用：" .. preset.name
                _G.MFH_beautifyStatus.TextColor3 = THEME.accentG
            end
        end)
        y = y + 38
    end
    makeLabel(p, "━━━ 自定义天空 ID ━━━", y + 8)
    y = y + 30
    local skyInput = makeInput(p, "输入天空 ID（如 169210090）", y, "", 38)
    y = y + 44
    local applySkyBtn = makeButton(p, "应用自定义天空（所有人可见）", y, THEME.accentV, 38)
    y = y + 46
    local resetSkyBtn = makeButton(p, "恢复默认天空", y, THEME.accentP, 38)
    y = y + 46
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -28, 0, 60)
    hint.Position = UDim2.new(0, 14, 0, y)
    hint.BackgroundTransparency = 1
    hint.Text = "提示：\n· 输入纯数字 ID 或完整 rbxassetid://\n· 需先运行服务端才能让所有人看到"
    hint.TextColor3 = THEME.subtext
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.TextWrapped = true
    hint.Parent = p
    y = y + 66
    local status = makeStatus(p, y)
    status.Text = "输入天空 ID 后点击应用"
    _G.MFH_beautifyStatus = status
    local function applySky()
        local raw = skyInput.Text or ""
        raw = raw:gsub("%s", "")
        if raw == "" then
            status.Text = "❌ 请输入天空 ID"
            status.TextColor3 = THEME.accentR
            return
        end
        local skyId = raw
        if skyId:match("^%d+$") then skyId = "rbxassetid://" .. skyId end
        if not skyId:match("^rbxassetid://%d+$") then
            status.Text = "❌ 格式错误，应为纯数字或 rbxassetid://"
            status.TextColor3 = THEME.accentR
            return
        end
        local remote = ReplicatedStorage:FindFirstChild(CONFIG.REMOTE_NAME)
        if remote then
            pcall(function() remote:FireServer("sky", skyId, 0, 0) end)
            status.Text = "✅ 已发送到服务器（所有人可见）"
            status.TextColor3 = THEME.accentG
        else
            pcall(function()
                local sky = Lighting:FindFirstChildOfClass("Sky")
                if not sky then sky = Instance.new("Sky"); sky.Parent = Lighting end
                sky.SkyboxBk = skyId; sky.SkyboxDn = skyId
                sky.SkyboxFt = skyId; sky.SkyboxLf = skyId
                sky.SkyboxRt = skyId; sky.SkyboxUp = skyId
            end)
            status.Text = "⚠ 仅本地生效（未运行服务端）"
            status.TextColor3 = THEME.accentY
        end
    end
    applySkyBtn.MouseButton1Click:Connect(applySky)
    skyInput.FocusLost:Connect(function(ep) if ep then pcall(applySky) end end)
    resetSkyBtn.MouseButton1Click:Connect(function()
        local remote = ReplicatedStorage:FindFirstChild(CONFIG.REMOTE_NAME)
        if remote then
            pcall(function() remote:FireServer("reset_sky", "", 0, 0) end)
        else
            local sky = Lighting:FindFirstChildOfClass("Sky")
            if sky then Util.safeDestroy(sky) end
        end
        status.Text = "✅ 已恢复默认天空"
        status.TextColor3 = THEME.accentG
    end)
end)

safeBuild("disguise", function()
    local p = createPanel("disguise")
    makeLabel(p, "🎭 伪装玩家（仅本地可见）", 14, 24)
    makeLabel(p, "输入要伪装成的玩家名字：", 44)
    local nameInput = makeInput(p, "输入玩家名字", 64)
    local applyBtn = makeButton(p, "应用伪装", 116, THEME.accentV)
    local resetBtn = makeButton(p, "恢复原样", 162, THEME.accentP)
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -28, 0, 100)
    hint.Position = UDim2.new(0, 14, 0, 216)
    hint.BackgroundTransparency = 1
    hint.Text = "说明：\n伪装仅在你自己的客户端生效，\n其他玩家看到的是你的真实名字。"
    hint.TextColor3 = THEME.subtext
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.TextWrapped = true
    hint.Parent = p
    local status = makeStatus(p, 326)
    _G.MFH_disguiseStatus = status
    _G.MFH_disguiseInput = nameInput
end)

safeBuild("customMFH", function()
    local p = createPanel("customMFH")
    makeLabel(p, "🛠 自定义 MFH（窗口大小 / 字体大小）", 14, 24)
    local status = makeStatus(p, 44)
    status.Text = "修改后点击对应按钮应用"
    makeLabel(p, "🪟 窗口大小", 84, 20)
    makeLabel(p, "宽度（320 - 1920）", 106)
    local widthInput = makeInput(p, "默认 " .. CONFIG.BASE_W, 124, tostring(CONFIG.BASE_W), 36)
    makeLabel(p, "高度（240 - 1080）", 168)
    local heightInput = makeInput(p, "默认 " .. CONFIG.BASE_H, 186, tostring(CONFIG.BASE_H), 36)
    local applySizeBtn = makeButton(p, "应用窗口大小", 232, THEME.accent, 38)
    makeLabel(p, "🔤 字体大小", 280, 20)
    makeLabel(p, "字体大小倍率（0.5 - 2.0）", 302)
    local fontInput = makeInput(p, "默认 1.0", 320, "1.0", 36)
    local applyFontBtn = makeButton(p, "应用字体大小", 366, THEME.accentV, 38)
    local resetAllBtn = makeButton(p, "♻ 全部恢复默认", 414, THEME.accentP, 38)
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -28, 0, 100)
    hint.Position = UDim2.new(0, 14, 0, 466)
    hint.BackgroundTransparency = 1
    hint.Text = "提示：\n· 修改窗口宽高后会自动重新适配屏幕\n· 字体倍率会应用到所有 UI 文字（包含按钮、输入框、标签等）\n· 点击「全部恢复默认」可重置所有内容"
    hint.TextColor3 = THEME.subtext
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.TextWrapped = true
    hint.Parent = p
    bindNumericOnly(widthInput, 4)
    bindNumericOnly(heightInput, 4)
    fontInput:GetPropertyChangedSignal("Text"):Connect(function()
        local clean = fontInput.Text:gsub("[^%d%.]", "")
        local fd = clean:find("%.")
        if fd then clean = clean:sub(1, fd) .. clean:sub(fd + 1):gsub("%.", "") end
        if #clean > 4 then clean = clean:sub(1, 4) end
        if clean ~= fontInput.Text then fontInput.Text = clean end
    end)
    applySizeBtn.MouseButton1Click:Connect(function()
        local w = tonumber(widthInput.Text)
        local h = tonumber(heightInput.Text)
        if not w or not h then
            status.Text = "❌ 请输入有效的宽高"
            status.TextColor3 = THEME.accentR
            return
        end
        applyCustomWindowSize(w, h)
        status.Text = string.format("✅ 已应用窗口大小：%d × %d", math.floor(w), math.floor(h))
        status.TextColor3 = THEME.accentG
    end)
    applyFontBtn.MouseButton1Click:Connect(function()
        local s = tonumber(fontInput.Text)
        if not s then
            status.Text = "❌ 请输入有效的字体倍率"
            status.TextColor3 = THEME.accentR
            return
        end
        if _G.MFH_applyFontScale then
            _G.MFH_applyFontScale(s)
            status.Text = string.format("✅ 已应用字体大小：%.2fx", s)
            status.TextColor3 = THEME.accentG
        end
    end)
    resetAllBtn.MouseButton1Click:Connect(function()
        widthInput.Text = tostring(CONFIG.BASE_W)
        heightInput.Text = tostring(CONFIG.BASE_H)
        fontInput.Text = "1.0"
        applyCustomWindowSize(CONFIG.BASE_W, CONFIG.BASE_H)
        if _G.MFH_applyFontScale then _G.MFH_applyFontScale(1.0) end
        status.Text = "✅ 已全部恢复默认"
        status.TextColor3 = THEME.accentG
    end)
    _G.MFH_customMFHStatus = status
end)

safeBuild("aimbot", function()
    local p = createPanel("aimbot")
    makeLabel(p, "🎯 子弹追踪（自动瞄准最近玩家）", 14, 24)
    local status = makeStatus(p, 44)
    makeLabel(p, "瞄准平滑度（0.01 - 1，越低越平滑）", 82)
    local smooth = makeInput(p, "默认 0.15", 100, "0.15", 38)
    local toggleBtn = makeButton(p, "开启子弹追踪", 152, THEME.accentP)
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -28, 0, 140)
    hint.Position = UDim2.new(0, 14, 0, 208)
    hint.BackgroundTransparency = 1
    hint.Text = "说明：\n开启后相机自动对准最近的玩家。\n· 平滑度越低瞄准越慢但更隐蔽\n· 部分游戏有反作弊可能被检测"
    hint.TextColor3 = THEME.subtext
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.TextWrapped = true
    hint.Parent = p
    _G.MFH_aimbotStatus = status
    _G.MFH_aimbotSmoothInput = smooth
    _G.MFH_aimbotToggleBtn = toggleBtn
end)

-- ========================================================
-- 新增：第三人称视角面板
-- ========================================================
safeBuild("thirdperson", function()
    local p = createPanel("thirdperson")
    makeLabel(p, "🎥 第三人称视角（强制 + 缩放 + 旋转）", 14, 24)
    local status = makeStatus(p, 44)
    status.Text = "点击下方按钮开启强制第三人称视角"
    local toggleBtn = makeButton(p, "开启强制第三人称", 84, THEME.accentC)
    makeLabel(p, "视角距离（5 - 100）", 132)
    local distanceInput = makeInput(p, "默认 15", 150, "15", 36)
    bindNumericOnly(distanceInput, 3)
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -28, 0, 160)
    hint.Position = UDim2.new(0, 14, 0, 200)
    hint.BackgroundTransparency = 1
    hint.Text = "功能说明：\n· 强制将第一人称游戏切换到第三人称视角\n· 鼠标滚轮可以缩放视角远近\n· 鼠标右键拖动可以旋转视角\n· 视角距离越大，看到的范围越广\n· 关闭后恢复游戏默认视角"
    hint.TextColor3 = THEME.subtext
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.TextWrapped = true
    hint.Parent = p
    _G.MFH_thirdPersonStatus = status
    _G.MFH_thirdPersonToggleBtn = toggleBtn
    _G.MFH_thirdPersonDistanceInput = distanceInput
end)

safeBuild("otherscripts", function()
    local p = createPanel("otherscripts")
    makeLabel(p, "📦 其他脚本（点击复制）", 14, 24)
    local copyStatus = Instance.new("TextLabel")
    copyStatus.Size = UDim2.new(1, -28, 0, 28)
    copyStatus.Position = UDim2.new(0, 14, 0, 42)
    copyStatus.BackgroundColor3 = THEME.card
    copyStatus.BackgroundTransparency = 0.5
    copyStatus.BorderSizePixel = 0
    copyStatus.Text = "点击下方按钮复制脚本链接"
    copyStatus.TextColor3 = THEME.subtext
    copyStatus.Font = Enum.Font.Gotham
    copyStatus.TextSize = 12
    copyStatus.Parent = p
    local csCorner = Instance.new("UICorner"); csCorner.CornerRadius = UDim.new(0, 7); csCorner.Parent = copyStatus
    local csStroke = Instance.new("UIStroke"); csStroke.Color = THEME.stroke; csStroke.Thickness = 1; csStroke.Transparency = 0.9; csStroke.Parent = copyStatus
    makeLabel(p, "🎨 黑白脚本", 82)
    local blackWhiteBtn = makeButton(p, "📋 复制黑白脚本加载器", 102, Color3.fromRGB(180, 180, 180))
    makeLabel(p, "🍊 皮脚本", 158)
    local piBtn = makeButton(p, "📋 复制皮脚本加载器", 178, Color3.fromRGB(255, 160, 60))

    local BLACKWHITE_SCRIPT = [[loadstring(game:HttpGet('https://raw.githubusercontent.com/tfcygvunbind/Apple/main/黑白脚本加载器'))()]]
    local PI_SCRIPT = [[getgenv().XiaoPi="皮脚本QQ群1002100032" loadstring(game:HttpGet("https://raw.githubusercontent.com/xiaopi77/xiaopi77/main/QQ1002100032-Roblox-Pi-script.lua"))()]]

    local function tryCopy(text, label)
        local copied = false
        if setclipboard then
            local ok = pcall(setclipboard, text)
            if ok then copied = true end
        end
        if copied then
            copyStatus.Text = "✅ " .. label .. " 已复制！"
            copyStatus.TextColor3 = THEME.accentG
        else
            copyStatus.Text = "❌ 复制失败，请手动复制"
            copyStatus.TextColor3 = THEME.accentR
        end
        task.delay(3, function()
            if copyStatus and copyStatus.Parent then
                copyStatus.Text = "点击下方按钮复制脚本链接"
                copyStatus.TextColor3 = THEME.subtext
            end
        end)
    end

    blackWhiteBtn.MouseButton1Click:Connect(function() tryCopy(BLACKWHITE_SCRIPT, "黑白脚本") end)
    piBtn.MouseButton1Click:Connect(function() tryCopy(PI_SCRIPT, "皮脚本") end)
    _G.MFH_copyStatus = copyStatus
end)

safeBuild("superpack", function()
    local p = createPanel("superpack")
    makeLabel(p, "🚀 超级功能包（14 项）", 14, 24)
    local status = makeStatus(p, 44)
    status.Text = "点击下方按钮启用对应功能"
    local y = 84
    local speedAuraBtn = makeButton(p, "🚀 速度光环（自动加速）", y, THEME.accentG, 34); y = y + 38
    local superJumpBtn = makeButton(p, "👟 超级跳跃（多段跳）", y, THEME.accentG, 34); y = y + 38
    local glideBtn = makeButton(p, "🪂 滑翔翼（下坠减速）", y, THEME.accentG, 34); y = y + 38
    local spiderBtn = makeButton(p, "🕸 蜘蛛侠（爬墙）", y, THEME.accentY, 34); y = y + 38
    local touchKillBtn = makeButton(p, "💥 触碰即杀", y, THEME.accentR, 34); y = y + 38
    local dropBtn = makeButton(p, "🪁 坠落玩家（拉下来）", y, THEME.accentR, 34); y = y + 38
    local orbitBtn = makeButton(p, "🎢 环绕旋转（绕你转圈）", y, THEME.accentV, 34); y = y + 38
    local autoclickBtn = makeButton(p, "🖱 自动点击器", y, THEME.accentT, 34); y = y + 38
    local suctionBtn = makeButton(p, "🧲 吸附玩家（拉面前）", y, THEME.accentC, 34); y = y + 38
    local antiTPBtn = makeButton(p, "🕶 反传送（防被传）", y, THEME.accentO, 34); y = y + 38
    local crosshairBtn = makeButton(p, "🎯 准星加强（屏幕中央）", y, THEME.accentY, 34); y = y + 38
    local pingBtn = makeButton(p, "🌐 网络延迟显示", y, THEME.accentC, 34); y = y + 38
    local animSpeedBtn = makeButton(p, "🎬 动画加速（3x）", y, THEME.accentV, 34); y = y + 38
    local godPlusBtn = makeButton(p, "🛡 无敌+（服务端尝试）", y, THEME.accentG, 34); y = y + 38
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, -28, 0, 60)
    infoLabel.Position = UDim2.new(0, 14, 0, y + 6)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "提示：部分功能依赖游戏机制，若无效说明游戏未开放对应接口"
    infoLabel.TextColor3 = THEME.subtext
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 11
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top
    infoLabel.TextWrapped = true
    infoLabel.Parent = p
    _G.MFH_superStatus = status
    _G.MFH_speedAuraBtn = speedAuraBtn
    _G.MFH_superJumpBtn = superJumpBtn
    _G.MFH_glideBtn = glideBtn
    _G.MFH_spiderBtn = spiderBtn
    _G.MFH_touchKillBtn = touchKillBtn
    _G.MFH_dropBtn = dropBtn
    _G.MFH_orbitBtn = orbitBtn
    _G.MFH_autoclickBtn = autoclickBtn
    _G.MFH_suctionBtn = suctionBtn
    _G.MFH_antiTPBtn = antiTPBtn
    _G.MFH_crosshairBtn = crosshairBtn
    _G.MFH_pingBtn = pingBtn
    _G.MFH_animSpeedBtn = animSpeedBtn
    _G.MFH_godPlusBtn = godPlusBtn
end)

safeBuild("about", function()
    local p = createPanel("about")
    makeLabel(p, "ℹ 关于 MFH 脚本", 14, 24)
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -28, 0, 480)
    info.Position = UDim2.new(0, 14, 0, 44)
    info.BackgroundColor3 = THEME.card
    info.BackgroundTransparency = 0.4
    info.BorderSizePixel = 0
    info.Text = "加载中..."
    info.TextColor3 = THEME.text
    info.Font = Enum.Font.Gotham
    info.TextSize = 12
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextYAlignment = Enum.TextYAlignment.Top
    info.TextWrapped = true
    info.Parent = p
    local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(0, ROUND.card); ic.Parent = info
    local ist = Instance.new("UIStroke"); ist.Color = THEME.stroke; ist.Thickness = 1; ist.Transparency = 0.9; ist.Parent = info
    local ip = Instance.new("UIPadding")
    ip.PaddingLeft = UDim.new(0, 14); ip.PaddingTop = UDim.new(0, 12); ip.PaddingRight = UDim.new(0, 14)
    ip.Parent = info
    local btn = makeButton(p, "刷新信息", 536, THEME.accent)
    _G.MFH_aboutInfo = info; _G.MFH_refreshAboutBtn = btn
end)

--========================================================--
-- 创建所有标签（含搜索关键词）
--========================================================--
local tabDefs = {
    {"items", " 🎁 道具", "道具 物品 获取 装备 工具 item tool give"},
    {"speak", " 💬 说话", "说话 聊天 气泡 头顶 speak chat bubble"},
    {"bomb", " 💥 霸屏", "霸屏 刷屏 气泡 全体 bomb spam"},
    {"fly", " ✈ 飞行", "飞行 飞 飞天 飘 fly"},
    {"saveTP", " 📍 保存传送", "保存 传送 位置 定位 记录 save teleport pos"},
    {"revive", " ♻ 复活", "复活 重生 死亡 revive respawn"},
    {"heal", " ❤ 治疗", "治疗 回血 生命 血量 heal health"},
    {"anti", " 🛡 防甩", "防甩 防甩飞 防护 防止 anti"},
    {"fling", " 💫 甩飞", "甩飞 甩 飞 抛 碰 接触 fling"},
    {"fling2", " 🌀 甩飞2", "甩飞 甩 飞 旋转 接触 fling2 spin"},
    {"esp", " 👁 透视", "透视 看穿 穿墙 看到 esp wallhack"},
    {"move", " 🏃 移动", "移动 速度 跳跃 走路 speed jump"},
    {"noclip", " 🧱 穿墙", "穿墙 穿透 noclip wall"},
    {"utility", " 🔧 工具", "工具 实用 功能 utility tools"},
    {"tracker", " 📍 追踪", "追踪 跟踪 定位 玩家 tracker"},
    {"combat", " ⚔️ 战斗", "战斗 打斗 攻击 格挡 闪避 combat"},
    {"server", " 🖥️ 服务器", "服务器 全体 冻结 server"},
    {"exploits"," 🛠 漏洞", "漏洞 作弊 利用 exploits"},
    {"objectcontrol", " 🖐 控制物体", "控制 物体 抓取 抓 抛 投掷 抓人 object grab"},
    {"fe", " ⚡ FE", "fe 过滤 绕过 filter enable 无重力 飞升 跳舞 火焰 冰霜 拖尾 冻结 传送"},
    {"textsky", " 🌌 文字天空", "文字 天空 文字天空 自定义 显示 textsky skytext"},
    {"beautify"," 🎨 美化", "美化 天空盒 天空 自定义 美化包 beautify sky"},
    {"disguise"," 🎭 伪装", "伪装 假名 改名 disguise name"},
    {"thirdperson", " 🎥 第三人称", "第三人称 视角 强制 相机 camera third person view"},
    {"customMFH", " 🛠 自定义MFH", "自定义 定制 mfh custom diy 窗口 大小 字体"},
    {"aimbot", " 🎯 追踪", "追踪 瞄准 自动 瞄准器 aimbot"},
    {"superpack", " 🚀 超能包", "超能 超级 速度 跳跃 滑翔 蜘蛛 触碰 坠落 环绕 点击 吸附 传送 准星 延迟 动画 无敌 super pack"},
    {"otherscripts", " 📦 其他脚本", "其他 脚本 复制 加载 other scripts copy"},
    {"about", " ℹ 关于", "关于 信息 版本 about info version"},
}
for _, def in ipairs(tabDefs) do
    pcall(createTab, def[1], def[2])
    if allTabs[def[1]] and def[3] then
        allTabs[def[1]].keywords = def[3]
    end
end
pcall(switchTab, "items")
print("[MFH] 标签已创建（" .. #tabDefs .. " 个）")

--========================================================--
-- 全局字体缩放系统
--========================================================--
local fontScaleState = { current = 1.0 }
local function applyGlobalFontScale(scale)
    scale = math.clamp(tonumber(scale) or 1.0, 0.5, 2.0)
    fontScaleState.current = scale
    for _, d in ipairs(win:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            if not d:GetAttribute("MFH_OrigTextSize") then
                d:SetAttribute("MFH_OrigTextSize", d.TextSize)
            end
            local orig = d:GetAttribute("MFH_OrigTextSize") or d.TextSize
            d.TextSize = math.clamp(math.floor(orig * scale + 0.5), 6, 80)
        end
    end
end
_G.MFH_applyFontScale = applyGlobalFontScale

--========================================================--
-- 🔍 模糊搜索（多关键词 AND 匹配）
--========================================================--
local function performSearch()
    local raw = searchBox.Text:lower()
    local keywords = {}
    for word in raw:gmatch("%S+") do
        keywords[#keywords + 1] = word
    end
    for _, def in ipairs(tabDefs) do
        local data = allTabs[def[1]]
        if data then
            if #keywords == 0 then
                data.container.Visible = true
            else
                local searchText = (data.btn.Text:lower() .. " " .. (data.keywords or "")):gsub("%s", "")
                local matched = true
                for _, kw in ipairs(keywords) do
                    local kwClean = kw:gsub("%s", "")
                    if #kwClean > 0 and not searchText:find(kwClean, 1, true) then
                        matched = false
                        break
                    end
                end
                data.container.Visible = matched
            end
        end
    end
    task.defer(function()
        if sidebar and sidebar.Parent then
            sidebar.CanvasPosition = sidebar.CanvasPosition
        end
    end)
end
searchBox:GetPropertyChangedSignal("Text"):Connect(performSearch)
print("[MFH] 搜索就绪（模糊多关键词）")

--========================================================--
-- 拖动
--========================================================--
local function setupDrag(frame, handle, onClick)
    local dragging, moved, dragStart, startAbs, activeTouch = false, false, nil, nil, nil
    handle.InputBegan:Connect(function(inputObj)
        if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            dragStart, startAbs = inputObj.Position, frame.AbsolutePosition
            activeTouch = inputObj
        end
    end)
    UserInputService.InputChanged:Connect(function(inputObj)
        if not dragging or (activeTouch and inputObj ~= activeTouch) then return end
        if inputObj.UserInputType ~= Enum.UserInputType.MouseMovement and inputObj.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = inputObj.Position - dragStart
        if math.abs(delta.X) > 3 or math.abs(delta.Y) > 3 then moved = true end
        local vp, size = getViewport(), frame.AbsoluteSize
        local newX = math.clamp(startAbs.X + delta.X, -(size.X - 40), vp.X - 40)
        local newY = math.clamp(startAbs.Y + delta.Y, 0, vp.Y - 40)
        frame.Position = UDim2.fromOffset(newX, newY)
    end)
    UserInputService.InputEnded:Connect(function(inputObj)
        if not dragging or (activeTouch and inputObj ~= activeTouch) then return end
        if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
            dragging, activeTouch = false, nil
            if not moved and onClick then
                local ok, err = pcall(onClick)
                if not ok then warn("[MFH] onClick:", err) end
            end
        end
    end)
end

--========================================================--
-- 窗口动画
--========================================================--
local isOpen, isAnimating, winTargetScale = false, false, uiScale

local function openWin()
    if isOpen or isAnimating then return end
    isAnimating, isOpen = true, true
    win.Visible = true
    winScale.Scale = winTargetScale * 0.94
    win.BackgroundTransparency = 1
    winStroke.Transparency = 1
    local info = TweenInfo.new(ANIM.openTime, ANIM.openStyle, Enum.EasingDirection.Out)
    TweenService:Create(winScale, info, { Scale = winTargetScale }):Play()
    TweenService:Create(win, info, { BackgroundTransparency = THEME.tWin }):Play()
    TweenService:Create(winStroke, info, { Transparency = 0.85 }):Play()
    TweenService:Create(dotStroke, TweenInfo.new(0.08), { Thickness = 3.5 }):Play()
    task.delay(0.08, function()
        if dotStroke and dotStroke.Parent then
            TweenService:Create(dotStroke, TweenInfo.new(0.16), { Thickness = 2 }):Play()
        end
    end)
    task.delay(ANIM.openTime, function() isAnimating = false end)
end

local function closeWin()
    if not isOpen or isAnimating then return end
    isAnimating, isOpen = true, false
    local info = TweenInfo.new(ANIM.closeTime, ANIM.closeStyle, Enum.EasingDirection.In)
    local t1 = TweenService:Create(winScale, info, { Scale = winTargetScale * 0.94 })
    local t2 = TweenService:Create(win, info, { BackgroundTransparency = 1 })
    local t3 = TweenService:Create(winStroke, info, { Transparency = 1 })
    t1:Play(); t2:Play(); t3:Play()
    t2.Completed:Connect(function()
        win.Visible = false
        isAnimating = false
    end)
    TweenService:Create(dotStroke, TweenInfo.new(0.08), { Thickness = 3.5 }):Play()
    task.delay(0.08, function()
        if dotStroke and dotStroke.Parent then
            TweenService:Create(dotStroke, TweenInfo.new(0.16), { Thickness = 2 }):Play()
        end
    end)
end

setupDrag(dot, dot, function()
    if isOpen then closeWin() else openWin() end
end)
setupDrag(win, titleBar, nil)
closeBtn.MouseButton1Click:Connect(function() closeWin() end)
print("[MFH] 拖动与动画就绪")

--========================================================--
-- 发送逻辑
--========================================================--
local function getTextChannel()
    local ok, r = pcall(function()
        if not TextChatService then return nil end
        local ch = TextChatService:FindFirstChild("TextChannels")
        if not ch then return nil end
        return ch:FindFirstChild("RBXGeneral") or ch:FindFirstChildWhichIsA("TextChannel")
    end)
    return ok and r or nil
end

local function sendToChatService(text)
    local channel = getTextChannel()
    if not channel then return false end
    return pcall(function() channel:SendAsync(text) end)
end

local function sendAction(action, text, duration, size)
    text = Util.sanitizeText(text)
    if not text then return false end
    duration = Util.clampDuration(duration)
    size = Util.clampTextSize(size)
    local remote = ReplicatedStorage:FindFirstChild(CONFIG.REMOTE_NAME)
    if remote and remote:IsA("RemoteEvent") then
        local ok = pcall(function() remote:FireServer(action, text, duration, size) end)
        if ok then return true end
    end
    if action == "speak" then
        if sendToChatService(text) then
            Util.createBubble(player.Character, text, duration, CONFIG.SPEAK_TAG, size)
            return true
        end
        Util.createBubble(player.Character, text, duration, CONFIG.SPEAK_TAG, size)
        return false
    elseif action == "bomb" then
        if sendToChatService("[霸屏] " .. text) then
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character then
                    Util.createBubble(p.Character, text, duration, CONFIG.BOMB_TAG, size)
                end
            end
            return true
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                Util.createBubble(p.Character, text, duration, CONFIG.BOMB_TAG, size)
            end
        end
        return false
    end
    return false
end

if _G.MFH_speakBtn and _G.MFH_speakInput then
    pcall(function()
        local function doSpeak()
            local t = _G.MFH_speakInput.Text
            if not t or t:gsub("%s", "") == "" then return end
            if sendAction("speak", t, _G.MFH_speakDur.Text, _G.MFH_speakSize.Text) then
                _G.MFH_speakInput.Text = ""
            end
        end
        _G.MFH_speakBtn.MouseButton1Click:Connect(doSpeak)
        _G.MFH_speakInput.FocusLost:Connect(function(ep) if ep then pcall(doSpeak) end end)
    end)
end
if _G.MFH_bombBtn and _G.MFH_bombInput then
    pcall(function()
        local function doBomb()
            local t = _G.MFH_bombInput.Text
            if not t or t:gsub("%s", "") == "" then return end
            if sendAction("bomb", t, _G.MFH_bombDur.Text, _G.MFH_bombSize.Text) then
                _G.MFH_bombInput.Text = ""
            end
        end
        _G.MFH_bombBtn.MouseButton1Click:Connect(doBomb)
        _G.MFH_bombInput.FocusLost:Connect(function(ep) if ep then pcall(doBomb) end end)
    end)
end
print("[MFH] 说话/霸屏就绪")

--========================================================--
-- 飞行（修复版）
--========================================================--
local PlayerModule, Controls
pcall(function()
    local ps = player:FindFirstChild("PlayerScripts")
    if ps then
        local pm = ps:FindFirstChild("PlayerModule")
        if pm then
            local ok, mod = pcall(require, pm)
            if ok and mod then
                PlayerModule = mod
                Controls = mod:GetControls()
            end
        end
    end
end)

local flyState = {
    active = false, speed = CONFIG.FLY_DEFAULT_SPEED, conn = nil,
    bv = nil, bg = nil, upward = 0, lastChar = nil, lastRoot = nil,
}

local flyHUD = Instance.new("Frame")
flyHUD.Name = "MFH_FlyHUD"
flyHUD.Size = UDim2.fromScale(1, 1)
flyHUD.BackgroundTransparency = 1
flyHUD.Visible = false
flyHUD.ZIndex = 5
flyHUD.Parent = gui

local function makeFlyBtn(text, pos, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(72, 72)
    b.AnchorPoint = Vector2.new(1, 1)
    b.Position = pos
    b.BackgroundColor3 = color
    b.BackgroundTransparency = 0.25
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBlack
    b.TextSize = 24
    b.AutoButtonColor = false
    b.Parent = flyHUD
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = b
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(255, 255, 255); s.Thickness = 2; s.Transparency = 0.5; s.Parent = b
    return b
end

local upBtn = makeFlyBtn("⬆", UDim2.new(1, -30, 1, -140), THEME.accentG)
local downBtn = makeFlyBtn("⬇", UDim2.new(1, -30, 1, -50), THEME.accentP)

local function bindHold(btn, onPress, onRelease)
    local at = nil
    btn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            at = i
            onPress()
        end
    end)
    btn.InputEnded:Connect(function(i)
        if at and i ~= at then return end
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            at = nil
            onRelease()
        end
    end)
    btn.MouseLeave:Connect(function() at = nil; onRelease() end)
end
bindHold(upBtn, function() flyState.upward = 1 end, function() if flyState.upward == 1 then flyState.upward = 0 end end)
bindHold(downBtn, function() flyState.upward = -1 end, function() if flyState.upward == -1 then flyState.upward = 0 end end)

local function updateFlyUI()
    if not _G.MFH_flyStatus then return end
    if flyState.active then
        _G.MFH_flyStatus.Text = "状态：飞行中 ✈"
        _G.MFH_flyStatus.TextColor3 = THEME.accentG
        _G.MFH_flyToggleBtn.Text = "关闭飞行"
        _G.MFH_flyToggleBtn.BackgroundColor3 = THEME.accentP
        flyHUD.Visible = true
    else
        _G.MFH_flyStatus.Text = "状态：已关闭"
        _G.MFH_flyStatus.TextColor3 = THEME.subtext
        _G.MFH_flyToggleBtn.Text = "开启飞行"
        _G.MFH_flyToggleBtn.BackgroundColor3 = THEME.accentG
        flyHUD.Visible = false
        flyState.upward = 0
    end
end

local function clearFlyObjects()
    if flyState.bv then Util.safeDestroy(flyState.bv); flyState.bv = nil end
    if flyState.bg then Util.safeDestroy(flyState.bg); flyState.bg = nil end
end

local function stopFly()
    if not flyState.active then return end
    flyState.active = false
    if flyState.conn then
        pcall(function() flyState.conn:Disconnect() end)
        flyState.conn = nil
    end
    clearFlyObjects()
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()
                hum.PlatformStand = false
                if hum.WalkSpeed < 16 then hum.WalkSpeed = 16 end
            end)
        end
    end
    updateFlyUI()
end

local function safeGetMoveVector()
    if Controls then
        local ok, mv = pcall(function() return Controls:GetMoveVector() end)
        if ok and typeof(mv) == "Vector3" and (math.abs(mv.X) > 0.05 or math.abs(mv.Z) > 0.05) then
            return mv
        end
    end
    local x, z = 0, 0
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then z = z - 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then z = z + 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then x = x - 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then x = x + 1 end
    return Vector3.new(x, 0, z)
end

local function startFly()
    if flyState.active then return end
    flyState.active = true
    flyState.lastChar = player.Character
    updateFlyUI()
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum.PlatformStand = true end)
        end
    end
    flyState.conn = RunService.RenderStepped:Connect(function()
        if not flyState.active then return end
        local char = player.Character
        if not char then return end
        if char ~= flyState.lastChar then
            flyState.lastChar = char
            clearFlyObjects()
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root or not root:IsA("BasePart") then return end
        flyState.lastRoot = root
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and not hum.PlatformStand then
            pcall(function() hum.PlatformStand = true end)
        end
        if not flyState.bv or flyState.bv.Parent ~= root then
            clearFlyObjects()
            local bv = Instance.new("BodyVelocity")
            bv.Name = "MFH_FlyVelocity"
            bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            bv.Velocity = Vector3.zero
            bv.P = 1250
            bv.Parent = root
            flyState.bv = bv
            local bg = Instance.new("BodyGyro")
            bg.Name = "MFH_FlyGyro"
            bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
            bg.P = 5000
            bg.D = 500
            bg.CFrame = root.CFrame
            bg.Parent = root
            flyState.bg = bg
        end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local dir = Vector3.zero
        local mv = safeGetMoveVector()
        if mv and (math.abs(mv.X) > 0.05 or math.abs(mv.Z) > 0.05) then
            dir = dir + (cam.CFrame.LookVector * (-mv.Z)) + (cam.CFrame.RightVector * mv.X)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            dir = dir + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            dir = dir - Vector3.new(0, 1, 0)
        end
        if flyState.upward ~= 0 then
            dir = dir + Vector3.new(0, flyState.upward, 0)
        end
        local speed = flyState.speed
        if dir.Magnitude > 0 then dir = dir.Unit * speed end
        local bv = flyState.bv
        local bg = flyState.bg
        if bv and bv.Parent == root then
            pcall(function() bv.Velocity = dir end)
        end
        if bg and bg.Parent == root then
            pcall(function() bg.CFrame = CFrame.new(root.Position, root.Position + cam.CFrame.LookVector) end)
        end
    end)
end

if _G.MFH_flyToggleBtn then
    _G.MFH_flyToggleBtn.MouseButton1Click:Connect(function()
        if flyState.active then
            stopFly()
        else
            local spd = tonumber(_G.MFH_flySpeedInput.Text) or CONFIG.FLY_DEFAULT_SPEED
            flyState.speed = math.clamp(spd, CONFIG.FLY_MIN_SPEED, CONFIG.FLY_MAX_SPEED)
            startFly()
        end
    end)
end
if _G.MFH_flySpeedInput then
    _G.MFH_flySpeedInput:GetPropertyChangedSignal("Text"):Connect(function()
        local spd = tonumber(_G.MFH_flySpeedInput.Text)
        if spd then
            flyState.speed = math.clamp(spd, CONFIG.FLY_MIN_SPEED, CONFIG.FLY_MAX_SPEED)
        end
    end)
end
updateFlyUI()
print("[MFH] 飞行就绪（修复版）")

--========================================================--
-- 复活
--========================================================--
local reviveState = { enabled = false, lastDeathCFrame = nil, spawnPart = nil, deathHook = nil, hpHook = nil }

local function updateReviveUI()
    if not _G.MFH_reviveStatus then return end
    if reviveState.enabled then
        _G.MFH_reviveStatus.Text = "状态：已开启 ♻"
        _G.MFH_reviveStatus.TextColor3 = THEME.accentO
        _G.MFH_reviveToggleBtn.Text = "关闭原地复活"
        _G.MFH_reviveToggleBtn.BackgroundColor3 = THEME.accentP
    else
        _G.MFH_reviveStatus.Text = "状态：已关闭"
        _G.MFH_reviveStatus.TextColor3 = THEME.subtext
        _G.MFH_reviveToggleBtn.Text = "开启原地复活"
        _G.MFH_reviveToggleBtn.BackgroundColor3 = THEME.accentO
    end
end

local function ensureSpawnPart(cf)
    if not cf then return end
    if not reviveState.spawnPart or not reviveState.spawnPart.Parent then
        local sp = Instance.new("SpawnLocation")
        sp.Name = "MFH_ReviveSpawn"
        sp.Size = Vector3.new(4, 1, 4)
        sp.Transparency = 1
        sp.CanCollide = false
        sp.Anchored = true
        sp.Neutral = true
        sp.Duration = 0
        sp.Parent = workspace
        reviveState.spawnPart = sp
    end
    pcall(function() reviveState.spawnPart.CFrame = CFrame.new(cf.Position + Vector3.new(0, 4, 0)) end)
    pcall(function() player.RespawnLocation = reviveState.spawnPart end)
end

local function detachReviveHooks()
    if reviveState.deathHook then
        pcall(function() reviveState.deathHook:Disconnect() end); reviveState.deathHook = nil
    end
    if reviveState.hpHook then
        pcall(function() reviveState.hpHook:Disconnect() end); reviveState.hpHook = nil
    end
end

local function attachReviveHooks(char)
    detachReviveHooks()
    if not char then return end
    task.spawn(function()
        local hum = char:WaitForChild("Humanoid", 10)
        if not hum then return end
        local function onDeath()
            local root = char:FindFirstChild("HumanoidRootPart")
            if root and root:IsA("BasePart") then
                reviveState.lastDeathCFrame = root.CFrame
                if reviveState.enabled then
                    ensureSpawnPart(reviveState.lastDeathCFrame)
                end
            end
        end
        reviveState.deathHook = hum.Died:Connect(onDeath)
        reviveState.hpHook = hum.HealthChanged:Connect(function(h)
            if h > 0 and h < 20 then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root and root:IsA("BasePart") then
                    reviveState.lastDeathCFrame = root.CFrame
                end
            end
        end)
    end)
end

local function forceResumeCharacter(char)
    if not char then return end
    task.spawn(function()
        local hum = char:WaitForChild("Humanoid", 10)
        local root = char:WaitForChild("HumanoidRootPart", 10)
        if not hum or not root then return end
        task.wait(0.15)
        pcall(function()
            hum.PlatformStand = false
            hum.Sit = false
            hum.AutoRotate = true
            if hum.WalkSpeed < 16 then hum.WalkSpeed = 16 end
            if hum.UseJumpPower and hum.JumpPower and hum.JumpPower < 50 then
                hum.JumpPower = 50
            end
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end)
        task.wait(0.3)
        pcall(function()
            if hum.PlatformStand then hum.PlatformStand = false end
            if hum.Sit then hum.Sit = false end
            if hum.WalkSpeed < 16 then hum.WalkSpeed = 16 end
        end)
    end)
end

local function handleRevive(char)
    if not reviveState.enabled or not reviveState.lastDeathCFrame then return end
    task.spawn(function()
        local root = char:WaitForChild("HumanoidRootPart", 15)
        if not root then return end
        local target = reviveState.lastDeathCFrame + Vector3.new(0, 3, 0)
        for i = 1, 3 do
            task.wait(0.08)
            if not root.Parent then return end
            pcall(function() root.CFrame = target end)
        end
        forceResumeCharacter(char)
    end)
end

if _G.MFH_reviveToggleBtn then
    _G.MFH_reviveToggleBtn.MouseButton1Click:Connect(function()
        reviveState.enabled = not reviveState.enabled
        if reviveState.enabled then
            if reviveState.lastDeathCFrame then ensureSpawnPart(reviveState.lastDeathCFrame) end
        else
            if reviveState.spawnPart then
                Util.safeDestroy(reviveState.spawnPart); reviveState.spawnPart = nil
            end
            pcall(function() player.RespawnLocation = nil end)
            if player.Character then forceResumeCharacter(player.Character) end
        end
        updateReviveUI()
    end)
end
updateReviveUI()
print("[MFH] 复活就绪")

--========================================================--
-- 治疗
--========================================================--
local healState = { active = false, interval = CONFIG.HEAL_DEFAULT_INTERVAL, token = nil, acc = 0 }

local function updateHealUI()
    if not _G.MFH_healStatus then return end
    if healState.active then
        _G.MFH_healStatus.Text = "状态：回血中 ❤"
        _G.MFH_healStatus.TextColor3 = THEME.accentG
        _G.MFH_healToggleBtn.Text = "关闭循环回血"
        _G.MFH_healToggleBtn.BackgroundColor3 = THEME.accentP
    else
        _G.MFH_healStatus.Text = "状态：已关闭"
        _G.MFH_healStatus.TextColor3 = THEME.subtext
        _G.MFH_healToggleBtn.Text = "开启循环回血"
        _G.MFH_healToggleBtn.BackgroundColor3 = THEME.accentG
    end
end

local function applyHeal()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 or hum.Health >= hum.MaxHealth then return end
    pcall(function() hum.Health = hum.MaxHealth end)
end

local function startHeal()
    healState.active = true
    healState.acc = 0
    local token = {}
    healState.token = token
    updateHealUI()
    task.spawn(function()
        local last = tick()
        while healState.active and healState.token == token do
            local now = tick()
            local dt = now - last
            last = now
            healState.acc = healState.acc + dt
            if healState.acc >= healState.interval then
                healState.acc = 0
                applyHeal()
            end
            RunService.Heartbeat:Wait()
        end
    end)
    applyHeal()
end

local function stopHeal()
    healState.active = false
    healState.token = nil
    updateHealUI()
end

if _G.MFH_healToggleBtn then
    _G.MFH_healToggleBtn.MouseButton1Click:Connect(function()
        if healState.active then
            stopHeal()
        else
            local iv = tonumber(_G.MFH_healIntervalInput.Text) or CONFIG.HEAL_DEFAULT_INTERVAL
            healState.interval = math.clamp(iv, CONFIG.HEAL_MIN_INTERVAL, CONFIG.HEAL_MAX_INTERVAL)
            startHeal()
        end
    end)
end
if _G.MFH_healIntervalInput then
    _G.MFH_healIntervalInput:GetPropertyChangedSignal("Text"):Connect(function()
        local iv = tonumber(_G.MFH_healIntervalInput.Text)
        if iv then
            healState.interval = math.clamp(iv, CONFIG.HEAL_MIN_INTERVAL, CONFIG.HEAL_MAX_INTERVAL)
        end
    end)
end
updateHealUI()

--========================================================--
-- 防甩飞
--========================================================--
local antiState = {
    active = false,
    originalStates = setmetatable({}, {__mode = "k"}),
    descendantConn = nil,
    heartbeatConn = nil
}

local function disableCharCollision(char)
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then
            if antiState.originalStates[d] == nil then
                antiState.originalStates[d] = d.CanCollide
            end
            pcall(function() d.CanCollide = false end)
        end
    end
end

local function restoreCharCollision(char)
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then
            local orig = antiState.originalStates[d]
            if orig ~= nil then
                pcall(function() d.CanCollide = orig end)
            else
                pcall(function() d.CanCollide = true end)
            end
        end
    end
end

local function updateAntiUI()
    if not _G.MFH_antiStatus then return end
    if antiState.active then
        _G.MFH_antiStatus.Text = "状态：防护中 🛡"
        _G.MFH_antiStatus.TextColor3 = THEME.accentY
        _G.MFH_antiToggleBtn.Text = "关闭防甩飞"
        _G.MFH_antiToggleBtn.BackgroundColor3 = THEME.accentP
    else
        _G.MFH_antiStatus.Text = "状态：已关闭"
        _G.MFH_antiStatus.TextColor3 = THEME.subtext
        _G.MFH_antiToggleBtn.Text = "开启防甩飞"
        _G.MFH_antiToggleBtn.BackgroundColor3 = THEME.accentY
    end
end

local function hookAntiChar(char)
    if not char then return end
    if antiState.descendantConn then
        pcall(function() antiState.descendantConn:Disconnect() end)
    end
    disableCharCollision(char)
    antiState.descendantConn = char.DescendantAdded:Connect(function(d)
        if not antiState.active then return end
        if d:IsA("BasePart") then
            antiState.originalStates[d] = d.CanCollide
            pcall(function() d.CanCollide = false end)
        end
    end)
end

local function startAnti()
    antiState.active = true
    antiState.originalStates = setmetatable({}, {__mode = "k"})
    updateAntiUI()
    if player.Character then hookAntiChar(player.Character) end
    if antiState.heartbeatConn then
        pcall(function() antiState.heartbeatConn:Disconnect() end)
    end
    antiState.heartbeatConn = RunService.Heartbeat:Connect(function()
        if not antiState.active then return end
        local char = player.Character
        if not char then return end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") and d.CanCollide then
                if antiState.originalStates[d] == nil then
                    antiState.originalStates[d] = true
                end
                pcall(function() d.CanCollide = false end)
            end
        end
    end)
end

local function stopAnti()
    antiState.active = false
    if antiState.descendantConn then
        pcall(function() antiState.descendantConn:Disconnect() end); antiState.descendantConn = nil
    end
    if antiState.heartbeatConn then
        pcall(function() antiState.heartbeatConn:Disconnect() end); antiState.heartbeatConn = nil
    end
    if player.Character then restoreCharCollision(player.Character) end
    antiState.originalStates = setmetatable({}, {__mode = "k"})
    updateAntiUI()
end

if _G.MFH_antiToggleBtn then
    _G.MFH_antiToggleBtn.MouseButton1Click:Connect(function()
        if antiState.active then stopAnti() else startAnti() end
    end)
end
updateAntiUI()

--========================================================--
-- 甩飞（接触版修复 - 只有真正碰到才会甩飞对方）
--========================================================--
local flingState = {
    active = false,
    power = CONFIG.FLING_POWER_DEFAULT,
    heartbeatConn = nil,
    lastHit = {},
}

local function updateFlingUI()
    if not _G.MFH_flingStatus then return end
    if flingState.active then
        _G.MFH_flingStatus.Text = "状态：甩飞中（碰到就甩）💫"
        _G.MFH_flingStatus.TextColor3 = THEME.accentR
        _G.MFH_flingToggleBtn.Text = "关闭甩飞模式"
        _G.MFH_flingToggleBtn.BackgroundColor3 = THEME.accentP
    else
        _G.MFH_flingStatus.Text = "状态：已关闭"
        _G.MFH_flingStatus.TextColor3 = THEME.subtext
        _G.MFH_flingToggleBtn.Text = "开启甩飞模式"
        _G.MFH_flingToggleBtn.BackgroundColor3 = THEME.accentR
    end
end

local function getHorizontalDist(a, b)
    local dx, dz = a.X - b.X, a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

-- 核心甩飞函数：只甩飞被碰到的那个目标玩家，自己不会被甩
local function doFling(targetPlayer, targetRoot, fromPos, power)
    -- 严格校验：目标必须是一个真实存在的玩家，且不是自己
    if not targetPlayer or targetPlayer == player then return end
    if not targetPlayer.Parent then return end
    if not targetRoot or not targetRoot.Parent then return end
    if not targetRoot:IsA("BasePart") then return end

    -- 验证 root 真的属于这个目标玩家
    local targetChar = targetRoot.Parent
    if not targetChar or not targetChar:IsA("Model") then return end
    local verified = Players:GetPlayerFromCharacter(targetChar)
    if verified ~= targetPlayer then return end

    -- 验证 Humanoid 还活着
    local hum = targetChar:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    local dir = targetRoot.Position - fromPos
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude < 0.1 then
        -- 完全重合时，随机方向
        local angle = math.random() * math.pi * 2
        dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
    end
    dir = dir.Unit
    local velocity = dir * power + Vector3.new(0, power * 0.6, 0)

    pcall(function()
        targetRoot.AssemblyLinearVelocity = velocity
    end)

    local bv = Instance.new("BodyVelocity")
    bv.Name = "MFH_FlingBV_" .. targetPlayer.Name
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Velocity = velocity
    bv.P = 5000
    bv.Parent = targetRoot

    local bav = Instance.new("BodyAngularVelocity")
    bav.Name = "MFH_FlingBAV_" .. targetPlayer.Name
    bav.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bav.AngularVelocity = Vector3.new(math.random(-20, 20), math.random(-20, 20), math.random(-20, 20))
    bav.Parent = targetRoot

    task.delay(0.4, function()
        Util.safeDestroy(bv)
        Util.safeDestroy(bav)
    end)
end

local function startFling()
    flingState.active = true
    flingState.lastHit = {}
    updateFlingUI()
    if flingState.heartbeatConn then
        pcall(function() flingState.heartbeatConn:Disconnect() end)
    end
    flingState.heartbeatConn = RunService.Heartbeat:Connect(function()
        if not flingState.active then return end
        local myChar = player.Character
        if not myChar then return end
        local myRoot = Util.getRoot(myChar)
        if not myRoot then return end
        local myPos = myRoot.Position
        local now = tick()

        -- 只检测真正"贴身碰到"的玩家（4 studs 内算接触）
        for _, other in ipairs(Players:GetPlayers()) do
            -- 严格跳过自己
            if other ~= player and other.Character then
                local oRoot = Util.getRoot(other.Character)
                local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                if oRoot and oHum and oHum.Health > 0 then
                    -- 再次确认角色模型属于该玩家
                    if Players:GetPlayerFromCharacter(oRoot.Parent) == other then
                        local dist = getHorizontalDist(oRoot.Position, myPos)
                        -- 使用接触距离：只有真的碰到才会甩飞
                        if dist <= CONFIG.FLING_TOUCH_RANGE and dist > 0 then
                            local last = flingState.lastHit[other] or 0
                            if now - last >= CONFIG.FLING_HIT_COOLDOWN then
                                flingState.lastHit[other] = now
                                -- 只甩飞对方，自己不会被甩
                                pcall(doFling, other, oRoot, myPos, flingState.power)
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function stopFling()
    flingState.active = false
    if flingState.heartbeatConn then
        pcall(function() flingState.heartbeatConn:Disconnect() end)
        flingState.heartbeatConn = nil
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "MFH_FlingBV" or obj.Name == "MFH_FlingBAV"
            or obj.Name:match("^MFH_FlingBV_") or obj.Name:match("^MFH_FlingBAV_") then
            Util.safeDestroy(obj)
        end
    end
    flingState.lastHit = {}
    updateFlingUI()
end

if _G.MFH_flingToggleBtn then
    _G.MFH_flingToggleBtn.MouseButton1Click:Connect(function()
        if flingState.active then
            stopFling()
        else
            local pw = tonumber(_G.MFH_flingPowerInput.Text) or CONFIG.FLING_POWER_DEFAULT
            flingState.power = math.clamp(pw, CONFIG.FLING_POWER_MIN, CONFIG.FLING_POWER_MAX)
            startFling()
        end
    end)
end
if _G.MFH_flingPowerInput then
    _G.MFH_flingPowerInput:GetPropertyChangedSignal("Text"):Connect(function()
        local pw = tonumber(_G.MFH_flingPowerInput.Text)
        if pw then
            flingState.power = math.clamp(pw, CONFIG.FLING_POWER_MIN, CONFIG.FLING_POWER_MAX)
        end
    end)
end
updateFlingUI()

--========================================================--
-- 甩飞2（接触版修复 - 只有真正碰到才会甩飞对方）
--========================================================--
local fling2State = {
    active = false,
    power = 1200,
    spin = 100,
    heartbeatConn = nil,
    lastHit = {},
}

local function updateFling2UI()
    if not _G.MFH_fling2Status then return end
    if fling2State.active then
        _G.MFH_fling2Status.Text = "状态：甩飞2中（碰到就甩）🌀"
        _G.MFH_fling2Status.TextColor3 = THEME.accentV
        _G.MFH_fling2ToggleBtn.Text = "关闭甩飞2"
        _G.MFH_fling2ToggleBtn.BackgroundColor3 = THEME.accentP
    else
        _G.MFH_fling2Status.Text = "状态：已关闭"
        _G.MFH_fling2Status.TextColor3 = THEME.subtext
        _G.MFH_fling2ToggleBtn.Text = "开启甩飞2"
        _G.MFH_fling2ToggleBtn.BackgroundColor3 = THEME.accentV
    end
end

local function doFling2(targetPlayer, targetRoot, fromPos, power, spin)
    if not targetPlayer or targetPlayer == player then return end
    if not targetPlayer.Parent then return end
    if not targetRoot or not targetRoot.Parent then return end
    if not targetRoot:IsA("BasePart") then return end
    local targetChar = targetRoot.Parent
    if not targetChar or not targetChar:IsA("Model") then return end
    if Players:GetPlayerFromCharacter(targetChar) ~= targetPlayer then return end
    local hum = targetChar:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    local dir = targetRoot.Position - fromPos
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude < 0.1 then
        local angle = math.random() * math.pi * 2
        dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
    end
    dir = dir.Unit
    local velocity = dir * power + Vector3.new(0, power * 0.9, 0)

    pcall(function()
        targetRoot.AssemblyLinearVelocity = velocity
    end)

    local bv = Instance.new("BodyVelocity")
    bv.Name = "MFH_Fling2BV_" .. targetPlayer.Name
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Velocity = velocity
    bv.P = 6000
    bv.Parent = targetRoot

    pcall(function() targetRoot.AssemblyAngularVelocity = Vector3.zero end)

    local bav = Instance.new("BodyAngularVelocity")
    bav.Name = "MFH_Fling2BAV_" .. targetPlayer.Name
    bav.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bav.P = 8000
    bav.AngularVelocity = Vector3.new(
        math.random(-spin, spin) * 0.3,
        spin,
        math.random(-spin, spin) * 0.3
    )
    bav.Parent = targetRoot

    task.delay(0.5, function()
        Util.safeDestroy(bv)
        Util.safeDestroy(bav)
    end)
end

local function startFling2()
    fling2State.active = true
    fling2State.lastHit = {}
    updateFling2UI()
    if fling2State.heartbeatConn then
        pcall(function() fling2State.heartbeatConn:Disconnect() end)
    end
    fling2State.heartbeatConn = RunService.Heartbeat:Connect(function()
        if not fling2State.active then return end
        local myChar = player.Character
        if not myChar then return end
        local myRoot = Util.getRoot(myChar)
        if not myRoot then return end
        local myPos = myRoot.Position
        local now = tick()

        -- 只检测真正贴身的玩家（4 studs 内算接触）
        for _, other in ipairs(Players:GetPlayers()) do
            if other ~= player and other.Character then
                local oRoot = Util.getRoot(other.Character)
                local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                if oRoot and oHum and oHum.Health > 0 then
                    if Players:GetPlayerFromCharacter(oRoot.Parent) == other then
                        local dist = getHorizontalDist(oRoot.Position, myPos)
                        if dist <= CONFIG.FLING_TOUCH_RANGE and dist > 0 then
                            local last = fling2State.lastHit[other] or 0
                            if now - last >= 0.6 then
                                fling2State.lastHit[other] = now
                                -- 只甩飞对方，自己不会被甩
                                pcall(doFling2, other, oRoot, myPos, fling2State.power, fling2State.spin)
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function stopFling2()
    fling2State.active = false
    if fling2State.heartbeatConn then
        pcall(function() fling2State.heartbeatConn:Disconnect() end)
        fling2State.heartbeatConn = nil
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "MFH_Fling2BV" or obj.Name == "MFH_Fling2BAV"
            or obj.Name:match("^MFH_Fling2BV_") or obj.Name:match("^MFH_Fling2BAV_") then
            Util.safeDestroy(obj)
        end
    end
    fling2State.lastHit = {}
    updateFling2UI()
end

if _G.MFH_fling2ToggleBtn then
    _G.MFH_fling2ToggleBtn.MouseButton1Click:Connect(function()
        if fling2State.active then
            stopFling2()
        else
            local pw = tonumber(_G.MFH_fling2PowerInput.Text) or 1200
            local spin = tonumber(_G.MFH_fling2SpinInput.Text) or 100
            fling2State.power = math.clamp(pw, 100, 3000)
            fling2State.spin = math.clamp(spin, 10, 500)
            startFling2()
        end
    end)
end
if _G.MFH_fling2PowerInput then
    _G.MFH_fling2PowerInput:GetPropertyChangedSignal("Text"):Connect(function()
        local pw = tonumber(_G.MFH_fling2PowerInput.Text)
        if pw then fling2State.power = math.clamp(pw, 100, 3000) end
    end)
end
if _G.MFH_fling2SpinInput then
    _G.MFH_fling2SpinInput:GetPropertyChangedSignal("Text"):Connect(function()
        local sp = tonumber(_G.MFH_fling2SpinInput.Text)
        if sp then fling2State.spin = math.clamp(sp, 10, 500) end
    end)
end
updateFling2UI()
print("[MFH] 甩飞/甩飞2就绪（接触版修复）")

--========================================================--
-- ESP
--========================================================--
local espState = { active = false, heartbeatConn = nil, billboards = {} }

local function updateESPUI()
    if not _G.MFH_espStatus then return end
    if espState.active then
        _G.MFH_espStatus.Text = "状态：透视中 👁"
        _G.MFH_espStatus.TextColor3 = THEME.accentC
        _G.MFH_espToggleBtn.Text = "关闭 ESP"
        _G.MFH_espToggleBtn.BackgroundColor3 = THEME.accentP
    else
        _G.MFH_espStatus.Text = "状态：已关闭"
        _G.MFH_espStatus.TextColor3 = THEME.subtext
        _G.MFH_espToggleBtn.Text = "开启 ESP"
        _G.MFH_espToggleBtn.BackgroundColor3 = THEME.accentC
    end
end

local function createESPForPlayer(p)
    if not p or p == player or not p.Character then return end
    local head = p.Character:FindFirstChild("Head")
    if not head then return end
    if espState.billboards[p] then Util.safeDestroy(espState.billboards[p]) end
    local bb = Instance.new("BillboardGui")
    bb.Name = CONFIG.ESP_TAG
    bb.Size = UDim2.fromOffset(220, 70)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.Parent = head
    local nameL = Instance.new("TextLabel")
    nameL.Name = "NameLabel"
    nameL.Size = UDim2.new(1, 0, 0.4, 0)
    nameL.BackgroundTransparency = 1
    nameL.Text = p.Name
    nameL.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameL.TextStrokeTransparency = 0
    nameL.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameL.Font = Enum.Font.GothamBold
    nameL.TextSize = 14
    nameL.Parent = bb
    local infoL = Instance.new("TextLabel")
    infoL.Name = "InfoLabel"
    infoL.Size = UDim2.new(1, 0, 0.35, 0)
    infoL.Position = UDim2.new(0, 0, 0.4, 0)
    infoL.BackgroundTransparency = 1
    infoL.Text = "0 studs"
    infoL.TextColor3 = Color3.fromRGB(255, 255, 200)
    infoL.TextStrokeTransparency = 0
    infoL.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    infoL.Font = Enum.Font.Gotham
    infoL.TextSize = 12
    infoL.Parent = bb
    local hpL = Instance.new("TextLabel")
    hpL.Name = "HpLabel"
    hpL.Size = UDim2.new(1, 0, 0.25, 0)
    hpL.Position = UDim2.new(0, 0, 0.75, 0)
    hpL.BackgroundTransparency = 1
    hpL.Text = "HP: 100"
    hpL.TextColor3 = Color3.fromRGB(120, 255, 120)
    hpL.TextStrokeTransparency = 0
    hpL.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    hpL.Font = Enum.Font.Gotham
    hpL.TextSize = 11
    hpL.Parent = bb
    espState.billboards[p] = bb
end

local function updateESP()
    if not espState.active then return end
    local myRoot = player.Character and Util.getRoot(player.Character)
    for _, p in ipairs(Players:GetPlayers()) do
        if p == player then
            if espState.billboards[p] then
                Util.safeDestroy(espState.billboards[p])
                espState.billboards[p] = nil
            end
        else
            local head = p.Character and p.Character:FindFirstChild("Head")
            local existing = espState.billboards[p]
            if (not existing or not existing.Parent) and head then
                createESPForPlayer(p)
                existing = espState.billboards[p]
            end
            if existing and existing.Parent and head and existing.Parent ~= head then
                Util.safeDestroy(existing)
                espState.billboards[p] = nil
                createESPForPlayer(p)
            end
            local bb = espState.billboards[p]
            if bb and bb.Parent then
                local oRoot = p.Character and Util.getRoot(p.Character)
                local oHum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
                if oRoot and myRoot then
                    local dist = (oRoot.Position - myRoot.Position).Magnitude
                    local iL = bb:FindFirstChild("InfoLabel")
                    if iL then iL.Text = string.format("%.0f studs", dist) end
                end
                if oHum then
                    local hL = bb:FindFirstChild("HpLabel")
                    if hL then
                        local pct = math.floor((oHum.Health / oHum.MaxHealth) * 100)
                        hL.Text = string.format("HP: %d%%", pct)
                        hL.TextColor3 = pct > 60 and Color3.fromRGB(120, 255, 120)
                            or pct > 30 and Color3.fromRGB(255, 220, 100)
                            or Color3.fromRGB(255, 100, 100)
                    end
                end
            end
        end
    end
end

local function startESP()
    espState.active = true
    updateESPUI()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then createESPForPlayer(p) end
    end
    if espState.heartbeatConn then
        pcall(function() espState.heartbeatConn:Disconnect() end)
    end
    espState.heartbeatConn = RunService.Heartbeat:Connect(function() updateESP() end)
end

local function stopESP()
    espState.active = false
    if espState.heartbeatConn then
        pcall(function() espState.heartbeatConn:Disconnect() end); espState.heartbeatConn = nil
    end
    for _, bb in pairs(espState.billboards) do
        Util.safeDestroy(bb)
    end
    espState.billboards = {}
    updateESPUI()
end

if _G.MFH_espToggleBtn then
    _G.MFH_espToggleBtn.MouseButton1Click:Connect(function()
        if espState.active then stopESP() else startESP() end
    end)
end
updateESPUI()
Players.PlayerAdded:Connect(function(p)
    if espState.active and p ~= player then
        task.wait(1)
        createESPForPlayer(p)
    end
end)
Players.PlayerRemoving:Connect(function(p)
    if espState.billboards[p] then
        Util.safeDestroy(espState.billboards[p])
        espState.billboards[p] = nil
    end
end)

--========================================================--
-- 移动
--========================================================--
local function applySpeed()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local spd = tonumber(_G.MFH_speedInput.Text) or CONFIG.SPEED_DEFAULT
    spd = Util.clamp(spd, CONFIG.SPEED_MIN, CONFIG.SPEED_MAX)
    pcall(function() hum.WalkSpeed = spd end)
end

local function applyJump()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local jp = tonumber(_G.MFH_jumpInput.Text) or CONFIG.JUMP_DEFAULT
    jp = Util.clamp(jp, CONFIG.JUMP_MIN, CONFIG.JUMP_MAX)
    pcall(function()
        if hum.UseJumpPower then hum.JumpPower = jp end
    end)
end

local function resetMove()
    _G.MFH_speedInput.Text = tostring(CONFIG.SPEED_DEFAULT)
    _G.MFH_jumpInput.Text = tostring(CONFIG.JUMP_DEFAULT)
    applySpeed(); applyJump()
end

if _G.MFH_speedApplyBtn then _G.MFH_speedApplyBtn.MouseButton1Click:Connect(applySpeed) end
if _G.MFH_jumpApplyBtn then _G.MFH_jumpApplyBtn.MouseButton1Click:Connect(applyJump) end
if _G.MFH_speedResetBtn then _G.MFH_speedResetBtn.MouseButton1Click:Connect(resetMove) end

if _G.MFH_speedInput then
    _G.MFH_speedInput:GetPropertyChangedSignal("Text"):Connect(function()
        local spd = tonumber(_G.MFH_speedInput.Text)
        if not spd then return end
        spd = Util.clamp(spd, CONFIG.SPEED_MIN, CONFIG.SPEED_MAX)
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.WalkSpeed = spd end) end
        end
    end)
end
if _G.MFH_jumpInput then
    _G.MFH_jumpInput:GetPropertyChangedSignal("Text"):Connect(function()
        local jp = tonumber(_G.MFH_jumpInput.Text)
        if not jp then return end
        jp = Util.clamp(jp, CONFIG.JUMP_MIN, CONFIG.JUMP_MAX)
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.UseJumpPower then
                pcall(function() hum.JumpPower = jp end)
            end
        end
    end)
end

--========================================================--
-- 穿墙
--========================================================--
local noclipState = { active = false, heartbeatConn = nil }

local function updateNoclipUI()
    if not _G.MFH_noclipStatus then return end
    if noclipState.active then
        _G.MFH_noclipStatus.Text = "状态：穿墙中 🧱"
        _G.MFH_noclipStatus.TextColor3 = THEME.accentO
        _G.MFH_noclipToggleBtn.Text = "关闭穿墙"
        _G.MFH_noclipToggleBtn.BackgroundColor3 = THEME.accentP
    else
        _G.MFH_noclipStatus.Text = "状态：已关闭"
        _G.MFH_noclipStatus.TextColor3 = THEME.subtext
        _G.MFH_noclipToggleBtn.Text = "开启穿墙"
        _G.MFH_noclipToggleBtn.BackgroundColor3 = THEME.accentO
    end
end

local function startNoclip()
    noclipState.active = true
    updateNoclipUI()
    if noclipState.heartbeatConn then
        pcall(function() noclipState.heartbeatConn:Disconnect() end)
    end
    noclipState.heartbeatConn = RunService.Stepped:Connect(function()
        if not noclipState.active then return end
        local char = player.Character
        if not char then return end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then
                pcall(function() d.CanCollide = false end)
            end
        end
    end)
end

local function stopNoclip()
    noclipState.active = false
    if noclipState.heartbeatConn then
        pcall(function() noclipState.heartbeatConn:Disconnect() end); noclipState.heartbeatConn = nil
    end
    local char = player.Character
    if char then
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                pcall(function() d.CanCollide = true end)
            end
        end
    end
    updateNoclipUI()
end

if _G.MFH_noclipToggleBtn then
    _G.MFH_noclipToggleBtn.MouseButton1Click:Connect(function()
        if noclipState.active then stopNoclip() else startNoclip() end
    end)
end
updateNoclipUI()

--========================================================--
-- 工具
--========================================================--
local utilityState = {
    infiniteStamina = false, fullbright = false, noGravity = false,
    autoRejoin = false, antiAfk = false,
    staminaConn = nil, originalLighting = nil, originalGravity = nil, idledConn = nil,
}

local function updateUtilityUI()
    if not _G.MFH_utilityStatus then return end
    _G.MFH_utilityStatus.Text = table.concat({
        "体力:" .. (utilityState.infiniteStamina and "开" or "关"),
        "全亮:" .. (utilityState.fullbright and "开" or "关"),
        "重力:" .. (utilityState.noGravity and "关" or "开"),
        "重连:" .. (utilityState.autoRejoin and "开" or "关"),
        "反挂:" .. (utilityState.antiAfk and "开" or "关"),
    }, " ")
end

if _G.MFH_infiniteStaminaBtn then
    _G.MFH_infiniteStaminaBtn.MouseButton1Click:Connect(function()
        utilityState.infiniteStamina = not utilityState.infiniteStamina
        if utilityState.infiniteStamina then
            _G.MFH_infiniteStaminaBtn.Text = "关闭无限体力"
            _G.MFH_infiniteStaminaBtn.BackgroundColor3 = THEME.accentP
            if utilityState.staminaConn then
                pcall(function() utilityState.staminaConn:Disconnect() end)
            end
            utilityState.staminaConn = RunService.Heartbeat:Connect(function()
                local char = player.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 and hum.Health < hum.MaxHealth then
                    pcall(function() hum.Health = hum.MaxHealth end)
                end
            end)
        else
            _G.MFH_infiniteStaminaBtn.Text = "开启无限体力"
            _G.MFH_infiniteStaminaBtn.BackgroundColor3 = THEME.accentG
            if utilityState.staminaConn then
                pcall(function() utilityState.staminaConn:Disconnect() end)
                utilityState.staminaConn = nil
            end
        end
        updateUtilityUI()
    end)
end

if _G.MFH_fullbrightBtn then
    _G.MFH_fullbrightBtn.MouseButton1Click:Connect(function()
        utilityState.fullbright = not utilityState.fullbright
        if utilityState.fullbright and Lighting then
            utilityState.originalLighting = {
                Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
                GlobalShadows = Lighting.GlobalShadows, FogEnd = Lighting.FogEnd,
                FogStart = Lighting.FogStart, Ambient = Lighting.Ambient,
            }
            _G.MFH_fullbrightBtn.Text = "关闭全亮模式"
            _G.MFH_fullbrightBtn.BackgroundColor3 = THEME.accentP
            pcall(function()
                Lighting.Brightness = 3; Lighting.ClockTime = 12
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 100000; Lighting.FogStart = 0
                Lighting.Ambient = Color3.fromRGB(200, 200, 200)
            end)
        else
            _G.MFH_fullbrightBtn.Text = "开启全亮模式"
            _G.MFH_fullbrightBtn.BackgroundColor3 = THEME.accentY
            if utilityState.originalLighting and Lighting then
                pcall(function()
                    Lighting.Brightness = utilityState.originalLighting.Brightness
                    Lighting.ClockTime = utilityState.originalLighting.ClockTime
                    Lighting.GlobalShadows = utilityState.originalLighting.GlobalShadows
                    Lighting.FogEnd = utilityState.originalLighting.FogEnd
                    Lighting.FogStart = utilityState.originalLighting.FogStart
                    Lighting.Ambient = utilityState.originalLighting.Ambient
                end)
            end
        end
        updateUtilityUI()
    end)
end

if _G.MFH_noGravityBtn then
    _G.MFH_noGravityBtn.MouseButton1Click:Connect(function()
        utilityState.noGravity = not utilityState.noGravity
        if utilityState.noGravity then
            utilityState.originalGravity = Workspace.Gravity
            _G.MFH_noGravityBtn.Text = "关闭无重力"
            _G.MFH_noGravityBtn.BackgroundColor3 = THEME.accentP
            pcall(function() Workspace.Gravity = 0 end)
        else
            _G.MFH_noGravityBtn.Text = "开启无重力"
            _G.MFH_noGravityBtn.BackgroundColor3 = THEME.accentO
            pcall(function() Workspace.Gravity = utilityState.originalGravity or 196.2 end)
        end
        updateUtilityUI()
    end)
end

if _G.MFH_autoRejoinBtn then
    _G.MFH_autoRejoinBtn.MouseButton1Click:Connect(function()
        utilityState.autoRejoin = not utilityState.autoRejoin
        _G.MFH_autoRejoinBtn.Text = utilityState.autoRejoin and "关闭自动重连" or "开启自动重连"
        _G.MFH_autoRejoinBtn.BackgroundColor3 = utilityState.autoRejoin and THEME.accentP or THEME.accentC
        updateUtilityUI()
    end)
end

if _G.MFH_antiAfkBtn then
    _G.MFH_antiAfkBtn.MouseButton1Click:Connect(function()
        utilityState.antiAfk = not utilityState.antiAfk
        if utilityState.antiAfk then
            _G.MFH_antiAfkBtn.Text = "关闭反挂机"
            _G.MFH_antiAfkBtn.BackgroundColor3 = THEME.accentP
            if utilityState.idledConn then
                pcall(function() utilityState.idledConn:Disconnect() end)
            end
            utilityState.idledConn = player.Idled:Connect(function()
                if VirtualUser then
                    pcall(function()
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton2(Vector2.new())
                    end)
                end
            end)
        else
            _G.MFH_antiAfkBtn.Text = "开启反挂机"
            _G.MFH_antiAfkBtn.BackgroundColor3 = THEME.accentC
            if utilityState.idledConn then
                pcall(function() utilityState.idledConn:Disconnect() end); utilityState.idledConn = nil
            end
        end
        updateUtilityUI()
    end)
end

pcall(function()
    player.OnTeleport:Connect(function(state)
        if state == Enum.TeleportState.Started and utilityState.autoRejoin and TeleportService then
            task.wait(2)
            pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
        end
    end)
end)
updateUtilityUI()

--========================================================--
-- 追踪
--========================================================--
local function refreshTracker()
    if not _G.MFH_trackerInfo then return end
    local sorted = {}
    local myRoot = player.Character and Util.getRoot(player.Character)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local r = Util.getRoot(p.Character)
            if r and myRoot then
                table.insert(sorted, { player = p, dist = (r.Position - myRoot.Position).Magnitude })
            end
        end
    end
    table.sort(sorted, function(a, b) return a.dist < b.dist end)
    local lines = { "当前服务器玩家：" .. #Players:GetPlayers() .. " 人", "" }
    for _, e in ipairs(sorted) do
        table.insert(lines, string.format("%s | %.0f studs", e.player.Name, e.dist))
    end
    _G.MFH_trackerInfo.Text = table.concat(lines, "\n")
    if not _G.MFH_tpScroll then return end
    for _, c in ipairs(_G.MFH_tpScroll:GetChildren()) do
        if c:IsA("TextButton") then Util.safeDestroy(c) end
    end
    for _, e in ipairs(sorted) do
        local p = e.player
        local btn = Instance.new("TextButton")
        btn.Name = "TP_" .. p.Name
        btn.Size = UDim2.new(1, -8, 0, 30)
        btn.BackgroundColor3 = THEME.accent
        btn.BackgroundTransparency = 0.35
        btn.BorderSizePixel = 0
        btn.Text = "→ " .. p.Name
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.AutoButtonColor = true
        btn.Parent = _G.MFH_tpScroll
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
        btn.MouseButton1Click:Connect(function()
            local tr = p.Character and Util.getRoot(p.Character)
            local mr = player.Character and Util.getRoot(player.Character)
            if tr and mr then
                pcall(function() mr.CFrame = tr.CFrame + Vector3.new(0, 2, 0) end)
            end
        end)
    end
end

if _G.MFH_trackerRefreshBtn then
    _G.MFH_trackerRefreshBtn.MouseButton1Click:Connect(function() pcall(refreshTracker) end)
end
task.spawn(function()
    while gui and gui.Parent do
        task.wait(1)
        if allPanels.tracker and allPanels.tracker.Visible then pcall(refreshTracker) end
    end
end)

--========================================================--
-- 战斗
--========================================================--
local combatState = {
    autoBlock = false, autoDodge = false, autoParry = false,
    killAura = false, hitboxExpander = false,
    blockConn = nil, dodgeConn = nil, parryConn = nil,
    killAuraConn = nil, originalSizes = {}, hitboxConn = nil,
}

local function updateCombatUI()
    if not _G.MFH_combatStatus then return end
    _G.MFH_combatStatus.Text = table.concat({
        "格挡:" .. (combatState.autoBlock and "开" or "关"),
        "闪避:" .. (combatState.autoDodge and "开" or "关"),
        "招架:" .. (combatState.autoParry and "开" or "关"),
        "光环:" .. (combatState.killAura and "开" or "关"),
        "扩框:" .. (combatState.hitboxExpander and "开" or "关"),
    }, " ")
end

local function tryFireCombatRemote(keywords)
    local fired = false
    pcall(function()
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                local lower = obj.Name:lower()
                for _, kw in ipairs(keywords) do
                    if lower:find(kw) then
                        pcall(function() obj:FireServer() end)
                        fired = true
                        break
                    end
                end
            elseif obj:IsA("RemoteFunction") then
                local lower = obj.Name:lower()
                for _, kw in ipairs(keywords) do
                    if lower:find(kw) then
                        pcall(function() obj:InvokeServer() end)
                        fired = true
                        break
                    end
                end
            end
        end
    end)
    return fired
end

if _G.MFH_autoBlockBtn then
    _G.MFH_autoBlockBtn.MouseButton1Click:Connect(function()
        combatState.autoBlock = not combatState.autoBlock
        if combatState.autoBlock then
            _G.MFH_autoBlockBtn.Text = "关闭自动格挡"
            _G.MFH_autoBlockBtn.BackgroundColor3 = THEME.accentP
            if combatState.blockConn then pcall(function() combatState.blockConn:Disconnect() end) end
            combatState.blockConn = RunService.Heartbeat:Connect(function()
                if not combatState.autoBlock then return end
                local char = player.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 and hum.Health < hum.MaxHealth * 0.95 then
                    tryFireCombatRemote({"block", "guard", "shield", "defend"})
                end
            end)
        else
            _G.MFH_autoBlockBtn.Text = "开启自动格挡"
            _G.MFH_autoBlockBtn.BackgroundColor3 = THEME.accentR
            if combatState.blockConn then pcall(function() combatState.blockConn:Disconnect() end); combatState.blockConn = nil end
        end
        updateCombatUI()
    end)
end

if _G.MFH_autoDodgeBtn then
    _G.MFH_autoDodgeBtn.MouseButton1Click:Connect(function()
        combatState.autoDodge = not combatState.autoDodge
        if combatState.autoDodge then
            _G.MFH_autoDodgeBtn.Text = "关闭自动闪避"
            _G.MFH_autoDodgeBtn.BackgroundColor3 = THEME.accentP
            if combatState.dodgeConn then pcall(function() combatState.dodgeConn:Disconnect() end) end
            combatState.dodgeConn = RunService.Heartbeat:Connect(function()
                if not combatState.autoDodge then return end
                local char = player.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 and hum.Health < hum.MaxHealth * 0.95 then
                    tryFireCombatRemote({"dodge", "dash", "evade", "roll"})
                end
            end)
        else
            _G.MFH_autoDodgeBtn.Text = "开启自动闪避"
            _G.MFH_autoDodgeBtn.BackgroundColor3 = THEME.accentR
            if combatState.dodgeConn then pcall(function() combatState.dodgeConn:Disconnect() end); combatState.dodgeConn = nil end
        end
        updateCombatUI()
    end)
end

if _G.MFH_autoParryBtn then
    _G.MFH_autoParryBtn.MouseButton1Click:Connect(function()
        combatState.autoParry = not combatState.autoParry
        if combatState.autoParry then
            _G.MFH_autoParryBtn.Text = "关闭自动招架"
            _G.MFH_autoParryBtn.BackgroundColor3 = THEME.accentP
            if combatState.parryConn then pcall(function() combatState.parryConn:Disconnect() end) end
            combatState.parryConn = RunService.Heartbeat:Connect(function()
                if not combatState.autoParry then return end
                local char = player.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 and hum.Health < hum.MaxHealth * 0.9 then
                    tryFireCombatRemote({"parry", "counter", "blockperfect"})
                end
            end)
        else
            _G.MFH_autoParryBtn.Text = "开启自动招架"
            _G.MFH_autoParryBtn.BackgroundColor3 = THEME.accentR
            if combatState.parryConn then pcall(function() combatState.parryConn:Disconnect() end); combatState.parryConn = nil end
        end
        updateCombatUI()
    end)
end

if _G.MFH_killAuraBtn then
    _G.MFH_killAuraBtn.MouseButton1Click:Connect(function()
        combatState.killAura = not combatState.killAura
        if combatState.killAura then
            _G.MFH_killAuraBtn.Text = "关闭击杀光环"
            _G.MFH_killAuraBtn.BackgroundColor3 = THEME.accentP
            if combatState.killAuraConn then pcall(function() combatState.killAuraConn:Disconnect() end) end
            combatState.killAuraConn = RunService.Heartbeat:Connect(function()
                if not combatState.killAura then return end
                local char = player.Character
                if not char then return end
                local myRoot = Util.getRoot(char)
                if not myRoot then return end
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character then
                        local or_ = Util.getRoot(other.Character)
                        local oh = other.Character:FindFirstChildOfClass("Humanoid")
                        if or_ and oh and oh.Health > 0 then
                            if (or_.Position - myRoot.Position).Magnitude <= CONFIG.KILL_AURA_RANGE then
                                tryFireCombatRemote({"attack", "hit", "damage", "punch", "swing"})
                            end
                        end
                    end
                end
            end)
        else
            _G.MFH_killAuraBtn.Text = "开启击杀光环"
            _G.MFH_killAuraBtn.BackgroundColor3 = THEME.accentR
            if combatState.killAuraConn then pcall(function() combatState.killAuraConn:Disconnect() end); combatState.killAuraConn = nil end
        end
        updateCombatUI()
    end)
end

if _G.MFH_hitboxExpanderBtn then
    _G.MFH_hitboxExpanderBtn.MouseButton1Click:Connect(function()
        combatState.hitboxExpander = not combatState.hitboxExpander
        if combatState.hitboxExpander then
            _G.MFH_hitboxExpanderBtn.Text = "关闭命中框扩展"
            _G.MFH_hitboxExpanderBtn.BackgroundColor3 = THEME.accentP
            if combatState.hitboxConn then pcall(function() combatState.hitboxConn:Disconnect() end) end
            combatState.hitboxConn = RunService.Heartbeat:Connect(function()
                if not combatState.hitboxExpander then return end
                local char = player.Character
                if not char then return end
                for _, d in ipairs(char:GetDescendants()) do
                    if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Name ~= "Head" then
                        if combatState.originalSizes[d] == nil then
                            combatState.originalSizes[d] = d.Size
                        end
                        local orig = combatState.originalSizes[d]
                        pcall(function()
                            d.Size = Vector3.new(orig.X * CONFIG.HITBOX_SCALE, orig.Y * CONFIG.HITBOX_SCALE, orig.Z * CONFIG.HITBOX_SCALE)
                            d.Transparency = 0.7
                            d.CanCollide = false
                        end)
                    end
                end
            end)
        else
            _G.MFH_hitboxExpanderBtn.Text = "开启命中框扩展"
            _G.MFH_hitboxExpanderBtn.BackgroundColor3 = THEME.accentR
            if combatState.hitboxConn then pcall(function() combatState.hitboxConn:Disconnect() end); combatState.hitboxConn = nil end
            local char = player.Character
            if char then
                for d, orig in pairs(combatState.originalSizes) do
                    if d and d.Parent then
                        pcall(function() d.Size = orig; d.Transparency = 0 end)
                    end
                end
            end
            combatState.originalSizes = {}
        end
        updateCombatUI()
    end)
end
updateCombatUI()

--========================================================--
-- 服务器功能
--========================================================--
local function teleportAllToMe()
    local myRoot = Util.getRoot(player.Character)
    if not myRoot then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local r = Util.getRoot(p.Character)
            if r then
                pcall(function() r.CFrame = myRoot.CFrame + Vector3.new(0, 2, 0) end)
            end
        end
    end
end

local function freezeAllPlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local hum = Util.getHumanoid(p.Character)
            if hum then
                pcall(function()
                    hum.WalkSpeed = 0
                    if hum.UseJumpPower then hum.JumpPower = 0 end
                end)
            end
        end
    end
end

local function unfreezeAllPlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local hum = Util.getHumanoid(p.Character)
            if hum then
                pcall(function()
                    hum.WalkSpeed = 16
                    if hum.UseJumpPower then hum.JumpPower = 50 end
                end)
            end
        end
    end
end

local function serverHop()
    if not HttpService or not TeleportService then return end
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local ok, result = pcall(function() return game:HttpGet(url) end)
        if not ok or not result then return end
        local data = HttpService:JSONDecode(result)
        if not data or not data.data then return end
        local cj = game.JobId
        local candidates = {}
        for _, s in ipairs(data.data) do
            if s.id ~= cj and s.playing < s.maxPlayers then
                table.insert(candidates, s)
            end
        end
        if #candidates > 0 then
            local chosen = candidates[math.random(1, #candidates)]
            pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen.id, player) end)
        end
    end)
end

if _G.MFH_teleportAllBtn then _G.MFH_teleportAllBtn.MouseButton1Click:Connect(teleportAllToMe) end
if _G.MFH_bringAllBtn then _G.MFH_bringAllBtn.MouseButton1Click:Connect(teleportAllToMe) end
if _G.MFH_freezeAllBtn then _G.MFH_freezeAllBtn.MouseButton1Click:Connect(freezeAllPlayers) end
if _G.MFH_unfreezeAllBtn then _G.MFH_unfreezeAllBtn.MouseButton1Click:Connect(unfreezeAllPlayers) end
if _G.MFH_serverHopBtn then _G.MFH_serverHopBtn.MouseButton1Click:Connect(serverHop) end

--========================================================--
-- 漏洞利用区
--========================================================--
local exploitState = {
    infJump = false, clickTP = false, godMode = false, invis = false,
    infJumpConn = nil, godConn = nil, clickTPConn = nil
}

if _G.MFH_infJumpBtn then
    _G.MFH_infJumpBtn.MouseButton1Click:Connect(function()
        exploitState.infJump = not exploitState.infJump
        if exploitState.infJump then
            _G.MFH_infJumpBtn.Text = "关闭无限跳跃"
            _G.MFH_infJumpBtn.BackgroundColor3 = THEME.accentP
            if exploitState.infJumpConn then pcall(function() exploitState.infJumpConn:Disconnect() end) end
            exploitState.infJumpConn = UserInputService.JumpRequest:Connect(function()
                if not exploitState.infJump then return end
                local char = player.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
                end
            end)
        else
            _G.MFH_infJumpBtn.Text = "开启无限跳跃"
            _G.MFH_infJumpBtn.BackgroundColor3 = THEME.accentG
            if exploitState.infJumpConn then pcall(function() exploitState.infJumpConn:Disconnect() end); exploitState.infJumpConn = nil end
        end
    end)
end

if _G.MFH_clickTPBtn then
    _G.MFH_clickTPBtn.MouseButton1Click:Connect(function()
        exploitState.clickTP = not exploitState.clickTP
        if exploitState.clickTP then
            _G.MFH_clickTPBtn.Text = "关闭点击传送"
            _G.MFH_clickTPBtn.BackgroundColor3 = THEME.accentP
            if exploitState.clickTPConn then pcall(function() exploitState.clickTPConn:Disconnect() end) end
            exploitState.clickTPConn = UserInputService.InputBegan:Connect(function(input, gp)
                if gp or not exploitState.clickTP then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    local mouse = player:GetMouse()
                    local char = player.Character
                    if not char then return end
                    local root = Util.getRoot(char)
                    if not root then return end
                    pcall(function() root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0)) end)
                end
            end)
        else
            _G.MFH_clickTPBtn.Text = "开启点击传送"
            _G.MFH_clickTPBtn.BackgroundColor3 = THEME.accentO
            if exploitState.clickTPConn then pcall(function() exploitState.clickTPConn:Disconnect() end); exploitState.clickTPConn = nil end
        end
    end)
end

if _G.MFH_godModeBtn then
    _G.MFH_godModeBtn.MouseButton1Click:Connect(function()
        exploitState.godMode = not exploitState.godMode
        if exploitState.godMode then
            _G.MFH_godModeBtn.Text = "关闭无敌模式"
            _G.MFH_godModeBtn.BackgroundColor3 = THEME.accentP
            if exploitState.godConn then pcall(function() exploitState.godConn:Disconnect() end) end
            exploitState.godConn = RunService.Heartbeat:Connect(function()
                if not exploitState.godMode then return end
                local char = player.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health < hum.MaxHealth then
                    pcall(function() hum.Health = hum.MaxHealth end)
                end
            end)
        else
            _G.MFH_godModeBtn.Text = "开启无敌模式（本地）"
            _G.MFH_godModeBtn.BackgroundColor3 = THEME.accentR
            if exploitState.godConn then pcall(function() exploitState.godConn:Disconnect() end); exploitState.godConn = nil end
        end
    end)
end

if _G.MFH_invisBtn then
    _G.MFH_invisBtn.MouseButton1Click:Connect(function()
        exploitState.invis = not exploitState.invis
        local char = player.Character
        if not char then return end
        if exploitState.invis then
            _G.MFH_invisBtn.Text = "关闭隐身"
            _G.MFH_invisBtn.BackgroundColor3 = THEME.accentP
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                    pcall(function() d.Transparency = 1 end)
                elseif d:IsA("Accessory") and d:FindFirstChild("Handle") then
                    pcall(function() d.Handle.Transparency = 1 end)
                end
            end
        else
            _G.MFH_invisBtn.Text = "开启隐身（本地）"
            _G.MFH_invisBtn.BackgroundColor3 = THEME.accentC
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                    pcall(function() d.Transparency = 0 end)
                elseif d:IsA("Accessory") and d:FindFirstChild("Handle") then
                    pcall(function() d.Handle.Transparency = 0 end)
                end
            end
        end
    end)
end

--========================================================--
-- 🖐 控制物体（修复版）
--========================================================--
local grabState = {
    active = false, grabbed = nil, grabbedRoot = nil,
    bodyPos = nil, bodyGyro = nil, wasAnchored = false,
    mouseConn = nil, inputConn = nil, renderConn = nil,
    range = CONFIG.GRAB_RANGE, throwPower = CONFIG.THROW_POWER,
}

local function updateGrabUI()
    if not _G.MFH_grabStatus then return end
    if grabState.active then
        _G.MFH_grabStatus.Text = "状态：控制中 🖐（点击物体抓取）"
        _G.MFH_grabStatus.TextColor3 = THEME.accentT
        _G.MFH_grabToggleBtn.Text = "关闭控制物体"
        _G.MFH_grabToggleBtn.BackgroundColor3 = THEME.accentP
    else
        _G.MFH_grabStatus.Text = "状态：已关闭"
        _G.MFH_grabStatus.TextColor3 = THEME.subtext
        _G.MFH_grabToggleBtn.Text = "开启控制物体"
        _G.MFH_grabToggleBtn.BackgroundColor3 = THEME.accentT
    end
end

local function releaseGrabbed()
    if grabState.bodyPos then Util.safeDestroy(grabState.bodyPos); grabState.bodyPos = nil end
    if grabState.bodyGyro then Util.safeDestroy(grabState.bodyGyro); grabState.bodyGyro = nil end
    if grabState.grabbedRoot and grabState.grabbedRoot.Parent then
        pcall(function() grabState.grabbedRoot.Anchored = grabState.wasAnchored end)
    end
    grabState.grabbed = nil
    grabState.grabbedRoot = nil
    grabState.wasAnchored = false
end

local function grabObject(target)
    if not target or not target:IsA("BasePart") then return end
    if target:IsDescendantOf(player.Character) then return end
    releaseGrabbed()
    local finalTarget = target
    local char = target:FindFirstAncestorOfClass("Model")
    if char and Players:GetPlayerFromCharacter(char) then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then
            finalTarget = root
        end
    end
    grabState.grabbed = finalTarget
    grabState.grabbedRoot = finalTarget
    grabState.wasAnchored = finalTarget.Anchored
    pcall(function() finalTarget.Anchored = false end)
    local bp = Instance.new("BodyPosition")
    bp.Name = "MFH_GrabBodyPos"
    bp.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bp.P = 20000; bp.D = 2000
    bp.Position = finalTarget.Position
    bp.Parent = finalTarget
    grabState.bodyPos = bp
    local bg = Instance.new("BodyGyro")
    bg.Name = "MFH_GrabBodyGyro"
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.P = 10000; bg.D = 500
    bg.CFrame = finalTarget.CFrame
    bg.Parent = finalTarget
    grabState.bodyGyro = bg
    if _G.MFH_grabStatus then
        _G.MFH_grabStatus.Text = "状态：已抓取 " .. finalTarget.Name .. " 🖐"
        _G.MFH_grabStatus.TextColor3 = THEME.accentT
    end
end

local function throwObject()
    if not grabState.grabbedRoot or not grabState.grabbedRoot.Parent then
        releaseGrabbed()
        return
    end
    local root = grabState.grabbedRoot
    local cam = workspace.CurrentCamera
    if not cam then releaseGrabbed(); return end
    local throwDir = cam.CFrame.LookVector
    local power = grabState.throwPower
    releaseGrabbed()
    pcall(function()
        root.AssemblyLinearVelocity = throwDir * power + Vector3.new(0, power * 0.3, 0)
    end)
    local bv = Instance.new("BodyVelocity")
    bv.Name = "MFH_ThrowVelocity"
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Velocity = throwDir * power + Vector3.new(0, power * 0.3, 0)
    bv.Parent = root
    task.delay(0.3, function() Util.safeDestroy(bv) end)
    if _G.MFH_grabStatus then
        _G.MFH_grabStatus.Text = "状态：已投掷 💨"
        _G.MFH_grabStatus.TextColor3 = THEME.accentY
        task.delay(1, function()
            if grabState.active and _G.MFH_grabStatus then
                _G.MFH_grabStatus.Text = "状态：控制中 🖐（点击物体抓取）"
                _G.MFH_grabStatus.TextColor3 = THEME.accentT
            end
        end)
    end
end

local function startGrab()
    if grabState.active then return end
    grabState.active = true
    grabState.range = tonumber(_G.MFH_grabRangeInput.Text) or CONFIG.GRAB_RANGE
    grabState.throwPower = tonumber(_G.MFH_grabThrowInput.Text) or CONFIG.THROW_POWER
    updateGrabUI()
    local mouse = player:GetMouse()
    grabState.inputConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp or not grabState.active then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if grabState.grabbedRoot then
                throwObject()
            else
                local target = mouse.Target
                if target and target:IsA("BasePart") then
                    local myRoot = player.Character and Util.getRoot(player.Character)
                    if myRoot then
                        local dist = (target.Position - myRoot.Position).Magnitude
                        if dist <= grabState.range then
                            grabObject(target)
                        end
                    end
                end
            end
        end
    end)
    grabState.mouseConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp or not grabState.active then return end
        if input.KeyCode == Enum.KeyCode.Q then releaseGrabbed() end
    end)
    grabState.renderConn = RunService.RenderStepped:Connect(function()
        if not grabState.active then return end
        if grabState.grabbedRoot and grabState.grabbedRoot.Parent then
            local cam = workspace.CurrentCamera
            if not cam then return end
            local targetPos = mouse.Hit.Position + Vector3.new(0, 2, 0)
            local myRoot = player.Character and Util.getRoot(player.Character)
            if myRoot then
                local dist = (targetPos - myRoot.Position).Magnitude
                if dist > grabState.range * 1.5 then
                    releaseGrabbed()
                    return
                end
            end
            pcall(function()
                if grabState.bodyPos and grabState.bodyPos.Parent then
                    grabState.bodyPos.Position = targetPos
                end
                if grabState.bodyGyro and grabState.bodyGyro.Parent then
                    grabState.bodyGyro.CFrame = CFrame.new(targetPos, targetPos + cam.CFrame.LookVector)
                end
            end)
        end
    end)
end

local function stopGrab()
    grabState.active = false
    releaseGrabbed()
    if grabState.inputConn then pcall(function() grabState.inputConn:Disconnect() end); grabState.inputConn = nil end
    if grabState.mouseConn then pcall(function() grabState.mouseConn:Disconnect() end); grabState.mouseConn = nil end
    if grabState.renderConn then pcall(function() grabState.renderConn:Disconnect() end); grabState.renderConn = nil end
    updateGrabUI()
end

if _G.MFH_grabToggleBtn then
    _G.MFH_grabToggleBtn.MouseButton1Click:Connect(function()
        if grabState.active then stopGrab() else startGrab() end
    end)
end
if _G.MFH_grabRangeInput then
    _G.MFH_grabRangeInput:GetPropertyChangedSignal("Text"):Connect(function()
        local r = tonumber(_G.MFH_grabRangeInput.Text)
        if r then grabState.range = math.clamp(r, 10, 100) end
    end)
end
if _G.MFH_grabThrowInput then
    _G.MFH_grabThrowInput:GetPropertyChangedSignal("Text"):Connect(function()
        local p = tonumber(_G.MFH_grabThrowInput.Text)
        if p then grabState.throwPower = math.clamp(p, 10, 1000) end
    end)
end
updateGrabUI()
print("[MFH] 控制物体就绪")

--========================================================--
-- ⚡ FE 功能（11 项）
--========================================================--
local feState = {
    noGravity = false, lift = false, dance = false, infJump = false,
    fire = false, frost = false, timeScale = false, scale = false,
    trailOn = false, gravityConn = nil, liftConn = nil, danceConn = nil,
    infJumpConn = nil, fireConn = nil, frostConn = nil, timeConn = nil,
    scaleConn = nil, trailConn = nil, danceTrack = nil, trailInstance = nil,
    skyTPConn = nil, freezeConn = nil, freeze = false,
}

local function updateFEUI()
    if not _G.MFH_feStatus then return end
    _G.MFH_feStatus.Text = table.concat({
        "无重力:" .. (feState.noGravity and "开" or "关"),
        "飞升:" .. (feState.lift and "开" or "关"),
        "跳舞:" .. (feState.dance and "开" or "关"),
        "跳高:" .. (feState.infJump and "开" or "关"),
        "火焰:" .. (feState.fire and "开" or "关"),
        "冰霜:" .. (feState.frost and "开" or "关"),
        "时间:" .. (feState.timeScale and "开" or "关"),
        "放大:" .. (feState.scale and "开" or "关"),
        "拖尾:" .. (feState.trailOn and "开" or "关"),
        "冻结:" .. (feState.freeze and "开" or "关"),
    }, " ")
end

if _G.MFH_feNoGravityBtn then
    _G.MFH_feNoGravityBtn.MouseButton1Click:Connect(function()
        feState.noGravity = not feState.noGravity
        if feState.noGravity then
            _G.MFH_feNoGravityBtn.Text = "关闭 FE 无重力"
            _G.MFH_feNoGravityBtn.BackgroundColor3 = THEME.accentP
            local fired = false
            pcall(function()
                for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
                    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                        local name = obj.Name:lower()
                        if name:find("gravity") or name:find("physics") or name:find("anti") then
                            pcall(function()
                                if obj:IsA("RemoteEvent") then obj:FireServer(0) else obj:InvokeServer(0) end
                            end)
                            fired = true
                        end
                    end
                end
            end)
            Workspace.Gravity = 0
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "⚡ FE 无重力已启用（" .. (fired and "远程事件" or "本地") .. "）"
                _G.MFH_feStatus.TextColor3 = THEME.accentT
            end
        else
            _G.MFH_feNoGravityBtn.Text = "FE 无重力（所有人可见）"
            _G.MFH_feNoGravityBtn.BackgroundColor3 = THEME.accentT
            Workspace.Gravity = 196.2
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "FE 无重力已关闭"
                _G.MFH_feStatus.TextColor3 = THEME.subtext
            end
        end
        updateFEUI()
    end)
end

if _G.MFH_feLiftBtn then
    _G.MFH_feLiftBtn.MouseButton1Click:Connect(function()
        feState.lift = not feState.lift
        if feState.lift then
            _G.MFH_feLiftBtn.Text = "关闭 FE 飞升"
            _G.MFH_feLiftBtn.BackgroundColor3 = THEME.accentP
            if feState.liftConn then pcall(function() feState.liftConn:Disconnect() end) end
            feState.liftConn = RunService.Heartbeat:Connect(function()
                if not feState.lift then return end
                local char = player.Character
                if not char then return end
                local root = Util.getRoot(char)
                if not root then return end
                local bv = root:FindFirstChild("MFH_FE_Lift")
                if not bv then
                    bv = Instance.new("BodyVelocity")
                    bv.Name = "MFH_FE_Lift"
                    bv.MaxForce = Vector3.new(0, 1e5, 0)
                    bv.Velocity = Vector3.new(0, 30, 0)
                    bv.Parent = root
                end
                bv.Velocity = Vector3.new(0, 30, 0)
            end)
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "⚡ FE 飞升已启用"
                _G.MFH_feStatus.TextColor3 = THEME.accentT
            end
        else
            _G.MFH_feLiftBtn.Text = "FE 角色飞升（拉高角色）"
            _G.MFH_feLiftBtn.BackgroundColor3 = THEME.accentT
            if feState.liftConn then pcall(function() feState.liftConn:Disconnect() end); feState.liftConn = nil end
            local char = player.Character
            if char then
                local root = Util.getRoot(char)
                if root then
                    local bv = root:FindFirstChild("MFH_FE_Lift")
                    if bv then Util.safeDestroy(bv) end
                end
            end
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "FE 飞升已关闭"
                _G.MFH_feStatus.TextColor3 = THEME.subtext
            end
        end
        updateFEUI()
    end)
end

if _G.MFH_feDanceBtn then
    _G.MFH_feDanceBtn.MouseButton1Click:Connect(function()
        feState.dance = not feState.dance
        if feState.dance then
            _G.MFH_feDanceBtn.Text = "关闭 FE 跳舞"
            _G.MFH_feDanceBtn.BackgroundColor3 = THEME.accentP
            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    local anim = Instance.new("Animation")
                    anim.AnimationId = "rbxassetid://507771019"
                    local track = hum:LoadAnimation(anim)
                    track:Play()
                    feState.danceTrack = track
                end
            end
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "⚡ FE 跳舞已启用"
                _G.MFH_feStatus.TextColor3 = THEME.accentT
            end
        else
            _G.MFH_feDanceBtn.Text = "FE 强制跳舞（所有人可见）"
            _G.MFH_feDanceBtn.BackgroundColor3 = THEME.accentT
            if feState.danceTrack then
                pcall(function() feState.danceTrack:Stop() end)
                feState.danceTrack = nil
            end
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "FE 跳舞已关闭"
                _G.MFH_feStatus.TextColor3 = THEME.subtext
            end
        end
        updateFEUI()
    end)
end

if _G.MFH_feInfJumpBtn then
    _G.MFH_feInfJumpBtn.MouseButton1Click:Connect(function()
        feState.infJump = not feState.infJump
        if feState.infJump then
            _G.MFH_feInfJumpBtn.Text = "关闭 FE 跳高"
            _G.MFH_feInfJumpBtn.BackgroundColor3 = THEME.accentP
            if feState.infJumpConn then pcall(function() feState.infJumpConn:Disconnect() end) end
            feState.infJumpConn = UserInputService.JumpRequest:Connect(function()
                if not feState.infJump then return end
                local char = player.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
                end
            end)
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "⚡ FE 无限跳跃已启用"
                _G.MFH_feStatus.TextColor3 = THEME.accentT
            end
        else
            _G.MFH_feInfJumpBtn.Text = "FE 无限跳跃（所有人可见）"
            _G.MFH_feInfJumpBtn.BackgroundColor3 = THEME.accentT
            if feState.infJumpConn then pcall(function() feState.infJumpConn:Disconnect() end); feState.infJumpConn = nil end
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "FE 无限跳跃已关闭"
                _G.MFH_feStatus.TextColor3 = THEME.subtext
            end
        end
        updateFEUI()
    end)
end

if _G.MFH_feFireBtn then
    _G.MFH_feFireBtn.MouseButton1Click:Connect(function()
        feState.fire = not feState.fire
        local char = player.Character
        if not char then return end
        if feState.fire then
            _G.MFH_feFireBtn.Text = "关闭 FE 火焰"
            _G.MFH_feFireBtn.BackgroundColor3 = THEME.accentP
            local root = Util.getRoot(char)
            if root then
                local fire = Instance.new("Fire")
                fire.Name = "MFH_FE_Fire"
                fire.Size = 8; fire.Heat = 10
                fire.Color = Color3.fromRGB(255, 100, 0)
                fire.SecondaryColor = Color3.fromRGB(255, 200, 0)
                fire.Parent = root
            end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    local fire = Instance.new("Fire")
                    fire.Name = "MFH_FE_Fire"
                    fire.Size = 4; fire.Heat = 5
                    fire.Parent = part
                end
            end
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "⚡ FE 火焰已启用"
                _G.MFH_feStatus.TextColor3 = THEME.accentT
            end
        else
            _G.MFH_feFireBtn.Text = "FE 火焰特效（所有人可见）"
            _G.MFH_feFireBtn.BackgroundColor3 = THEME.accentT
            for _, d in ipairs(char:GetDescendants()) do
                if d.Name == "MFH_FE_Fire" then Util.safeDestroy(d) end
            end
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "FE 火焰已关闭"
                _G.MFH_feStatus.TextColor3 = THEME.subtext
            end
        end
        updateFEUI()
    end)
end

if _G.MFH_feFrostBtn then
    _G.MFH_feFrostBtn.MouseButton1Click:Connect(function()
        feState.frost = not feState.frost
        local char = player.Character
        if not char then return end
        if feState.frost then
            _G.MFH_feFrostBtn.Text = "关闭 FE 冰霜"
            _G.MFH_feFrostBtn.BackgroundColor3 = THEME.accentP
            local root = Util.getRoot(char)
            if root then
                local frost = Instance.new("Fire")
                frost.Name = "MFH_FE_Frost"
                frost.Size = 6; frost.Heat = 0
                frost.Color = Color3.fromRGB(100, 200, 255)
                frost.SecondaryColor = Color3.fromRGB(200, 240, 255)
                frost.Parent = root
            end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    local frost = Instance.new("Fire")
                    frost.Name = "MFH_FE_Frost"
                    frost.Size = 3; frost.Heat = 0
                    frost.Color = Color3.fromRGB(150, 220, 255)
                    frost.Parent = part
                end
            end
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "⚡ FE 冰霜已启用"
                _G.MFH_feStatus.TextColor3 = THEME.accentT
            end
        else
            _G.MFH_feFrostBtn.Text = "FE 冰霜特效（所有人可见）"
            _G.MFH_feFrostBtn.BackgroundColor3 = THEME.accentT
            for _, d in ipairs(char:GetDescendants()) do
                if d.Name == "MFH_FE_Frost" then Util.safeDestroy(d) end
            end
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "FE 冰霜已关闭"
                _G.MFH_feStatus.TextColor3 = THEME.subtext
            end
        end
        updateFEUI()
    end)
end

if _G.MFH_feTimeBtn then
    _G.MFH_feTimeBtn.MouseButton1Click:Connect(function()
        feState.timeScale = not feState.timeScale
        if feState.timeScale then
            _G.MFH_feTimeBtn.Text = "关闭 FE 时间加速"
            _G.MFH_feTimeBtn.BackgroundColor3 = THEME.accentP
            if feState.timeConn then pcall(function() feState.timeConn:Disconnect() end) end
            feState.timeConn = RunService.Heartbeat:Connect(function()
                if not feState.timeScale then return end
                local char = player.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    pcall(function()
                        for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                            track:AdjustSpeed(3)
                        end
                    end)
                    pcall(function()
                        if hum.WalkSpeed > 0 and hum.WalkSpeed < 200 then hum.WalkSpeed = 50 end
                    end)
                end
            end)
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "⚡ FE 时间加速已启用（3x）"
                _G.MFH_feStatus.TextColor3 = THEME.accentT
            end
        else
            _G.MFH_feTimeBtn.Text = "FE 时间加速（所有人可见）"
            _G.MFH_feTimeBtn.BackgroundColor3 = THEME.accentT
            if feState.timeConn then pcall(function() feState.timeConn:Disconnect() end); feState.timeConn = nil end
            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum.WalkSpeed = 16 end) end
            end
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "FE 时间加速已关闭"
                _G.MFH_feStatus.TextColor3 = THEME.subtext
            end
        end
        updateFEUI()
    end)
end

if _G.MFH_feScaleBtn then
    _G.MFH_feScaleBtn.MouseButton1Click:Connect(function()
        feState.scale = not feState.scale
        local char = player.Character
        if not char then return end
        if feState.scale then
            _G.MFH_feScaleBtn.Text = "关闭 FE 放大"
            _G.MFH_feScaleBtn.BackgroundColor3 = THEME.accentP
            local scaleFactor = 3
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                    if not d:GetAttribute("MFH_OrigSize") then
                        d:SetAttribute("MFH_OrigSize", d.Size)
                    end
                    local orig = d:GetAttribute("MFH_OrigSize")
                    if orig then
                        pcall(function()
                            d.Size = Vector3.new(orig.X * scaleFactor, orig.Y * scaleFactor, orig.Z * scaleFactor)
                        end)
                    end
                end
            end
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "⚡ FE 角色放大已启用（3x）"
                _G.MFH_feStatus.TextColor3 = THEME.accentT
            end
        else
            _G.MFH_feScaleBtn.Text = "FE 角色放大（所有人可见）"
            _G.MFH_feScaleBtn.BackgroundColor3 = THEME.accentT
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                    local orig = d:GetAttribute("MFH_OrigSize")
                    if orig then
                        pcall(function() d.Size = orig end)
                        d:SetAttribute("MFH_OrigSize", nil)
                    end
                end
            end
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "FE 角色放大已关闭"
                _G.MFH_feStatus.TextColor3 = THEME.subtext
            end
        end
        updateFEUI()
    end)
end

if _G.MFH_feTrailBtn then
    _G.MFH_feTrailBtn.MouseButton1Click:Connect(function()
        feState.trailOn = not feState.trailOn
        local char = player.Character
        if not char then return end
        if feState.trailOn then
            _G.MFH_feTrailBtn.Text = "关闭 FE 拖尾"
            _G.MFH_feTrailBtn.BackgroundColor3 = THEME.accentP
            local root = Util.getRoot(char)
            if root then
                local a0 = Instance.new("Attachment"); a0.Name = "MFH_TrailA0"; a0.Position = Vector3.new(0, 0.5, 0); a0.Parent = root
                local a1 = Instance.new("Attachment"); a1.Name = "MFH_TrailA1"; a1.Position = Vector3.new(0, -0.5, 0); a1.Parent = root
                local trail = Instance.new("Trail")
                trail.Name = "MFH_FE_Trail"
                trail.Attachment0 = a0
                trail.Attachment1 = a1
                trail.Color = ColorSequence.new {
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 200, 255)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 80, 255)),
                }
                trail.Transparency = NumberSequence.new {
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 1),
                }
                trail.Lifetime = 1.5
                trail.MinLength = 0.1
                trail.WidthScale = NumberSequence.new(1)
                trail.Parent = root
                feState.trailInstance = trail
            end
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "⚡ FE 拖尾已启用"
                _G.MFH_feStatus.TextColor3 = THEME.accentT
            end
        else
            _G.MFH_feTrailBtn.Text = "FE 拖尾特效（所有人可见）"
            _G.MFH_feTrailBtn.BackgroundColor3 = THEME.accentT
            for _, d in ipairs(char:GetDescendants()) do
                if d.Name == "MFH_FE_Trail" or d.Name == "MFH_TrailA0" or d.Name == "MFH_TrailA1" then
                    Util.safeDestroy(d)
                end
            end
            feState.trailInstance = nil
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "FE 拖尾已关闭"
                _G.MFH_feStatus.TextColor3 = THEME.subtext
            end
        end
        updateFEUI()
    end)
end

if _G.MFH_feSkyTPBtn then
    _G.MFH_feSkyTPBtn.MouseButton1Click:Connect(function()
        local char = player.Character
        if not char then
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "❌ 角色不存在"
                _G.MFH_feStatus.TextColor3 = THEME.accentR
            end
            return
        end
        local root = Util.getRoot(char)
        if not root then return end
        local targetPos = root.Position + Vector3.new(0, 500, 0)
        pcall(function() root.CFrame = CFrame.new(targetPos) end)
        if _G.MFH_feStatus then
            _G.MFH_feStatus.Text = "⚡ FE 高空传送完成（+500 studs）"
            _G.MFH_feStatus.TextColor3 = THEME.accentT
        end
    end)
end

if _G.MFH_feFreezeBtn then
    _G.MFH_feFreezeBtn.MouseButton1Click:Connect(function()
        feState.freeze = not feState.freeze
        if feState.freeze then
            _G.MFH_feFreezeBtn.Text = "❄ 关闭 FE 冻结周围"
            _G.MFH_feFreezeBtn.BackgroundColor3 = THEME.accentP
            if feState.freezeConn then pcall(function() feState.freezeConn:Disconnect() end) end
            feState.freezeConn = RunService.Heartbeat:Connect(function()
                if not feState.freeze then return end
                local char = player.Character
                if not char then return end
                local myRoot = Util.getRoot(char)
                if not myRoot then return end
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character then
                        local or_ = Util.getRoot(other.Character)
                        if or_ and (or_.Position - myRoot.Position).Magnitude <= CONFIG.FREEZE_RANGE then
                            local hum = Util.getHumanoid(other.Character)
                            if hum then
                                pcall(function()
                                    hum.WalkSpeed = 0
                                    if hum.UseJumpPower then hum.JumpPower = 0 end
                                end)
                            end
                        end
                    end
                end
            end)
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "⚡ FE 冻结周围玩家已启用（20 studs）"
                _G.MFH_feStatus.TextColor3 = THEME.accentT
            end
        else
            _G.MFH_feFreezeBtn.Text = "FE 冻结周围玩家（20 studs）"
            _G.MFH_feFreezeBtn.BackgroundColor3 = THEME.accentT
            if feState.freezeConn then pcall(function() feState.freezeConn:Disconnect() end); feState.freezeConn = nil end
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local hum = Util.getHumanoid(other.Character)
                    if hum then
                        pcall(function()
                            if hum.WalkSpeed < 16 then hum.WalkSpeed = 16 end
                            if hum.UseJumpPower and hum.JumpPower and hum.JumpPower < 50 then hum.JumpPower = 50 end
                        end)
                    end
                end
            end
            if _G.MFH_feStatus then
                _G.MFH_feStatus.Text = "FE 冻结周围玩家已关闭"
                _G.MFH_feStatus.TextColor3 = THEME.subtext
            end
        end
        updateFEUI()
    end)
end
updateFEUI()
print("[MFH] FE 功能就绪（11 项）")

--========================================================--
-- 🌌 文字天空（跟随相机）
--========================================================--
local textSkyState = { part = nil, billboard = nil, label = nil, active = false, conn = nil }

local function clearTextSky()
    if textSkyState.conn then
        pcall(function() textSkyState.conn:Disconnect() end); textSkyState.conn = nil
    end
    if textSkyState.part then Util.safeDestroy(textSkyState.part) end
    textSkyState.part = nil
    textSkyState.billboard = nil
    textSkyState.label = nil
    textSkyState.active = false
end

local function createTextSky(text, color)
    clearTextSky()
    if not text or text:gsub("%s", "") == "" then return end
    color = color or Color3.fromRGB(255, 255, 255)
    local part = Instance.new("Part")
    part.Name = "MFH_TextSky"
    part.Size = Vector3.new(1, 1, 1)
    part.Transparency = 1
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Anchored = true
    local cam = workspace.CurrentCamera
    part.Position = cam and (cam.CFrame.Position + Vector3.new(0, 800, 0)) or Vector3.new(0, 800, 0)
    part.Parent = workspace
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MFH_TextSkyGui"
    billboard.Size = UDim2.fromOffset(3000, 800)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = math.huge
    billboard.Adornee = part
    billboard.Parent = part
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextScaled = true
    label.TextColor3 = color
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Font = Enum.Font.GothamBlack
    label.Parent = billboard
    textSkyState.part = part
    textSkyState.billboard = billboard
    textSkyState.label = label
    textSkyState.active = true
    textSkyState.conn = RunService.RenderStepped:Connect(function()
        if not textSkyState.active then return end
        local c = workspace.CurrentCamera
        if c and textSkyState.part then
            textSkyState.part.CFrame = CFrame.new(c.CFrame.Position + Vector3.new(0, 800, 0))
        end
    end)
end

if _G.MFH_textSkyApplyBtn then
    _G.MFH_textSkyApplyBtn.MouseButton1Click:Connect(function()
        local text = _G.MFH_textSkyInput and _G.MFH_textSkyInput.Text or ""
        if text:gsub("%s", "") == "" then
            if _G.MFH_textSkyStatus then
                _G.MFH_textSkyStatus.Text = "❌ 请输入文字"
                _G.MFH_textSkyStatus.TextColor3 = THEME.accentR
            end
            return
        end
        local color = _G.MFH_textSkyGetColor and _G.MFH_textSkyGetColor() or Color3.fromRGB(255, 255, 255)
        pcall(createTextSky, text, color)
        if _G.MFH_textSkyStatus then
            _G.MFH_textSkyStatus.Text = "✅ 已设置文字天空：" .. text
            _G.MFH_textSkyStatus.TextColor3 = THEME.accentG
        end
    end)
end
if _G.MFH_textSkyResetBtn then
    _G.MFH_textSkyResetBtn.MouseButton1Click:Connect(function()
        clearTextSky()
        if _G.MFH_textSkyStatus then
            _G.MFH_textSkyStatus.Text = "✅ 已恢复默认天空"
            _G.MFH_textSkyStatus.TextColor3 = THEME.accentG
        end
    end)
end

--========================================================--
-- 子弹追踪
--========================================================--
local aimbotState = { active = false, smooth = 0.15, heartbeatConn = nil }

local function updateAimbotUI()
    if not _G.MFH_aimbotStatus then return end
    if aimbotState.active then
        _G.MFH_aimbotStatus.Text = "状态：追踪中 🎯"
        _G.MFH_aimbotStatus.TextColor3 = THEME.accentP
        _G.MFH_aimbotToggleBtn.Text = "关闭子弹追踪"
        _G.MFH_aimbotToggleBtn.BackgroundColor3 = THEME.accentP
    else
        _G.MFH_aimbotStatus.Text = "状态：已关闭"
        _G.MFH_aimbotStatus.TextColor3 = THEME.subtext
        _G.MFH_aimbotToggleBtn.Text = "开启子弹追踪"
        _G.MFH_aimbotToggleBtn.BackgroundColor3 = THEME.accentP
    end
end

local function getNearestPlayer()
    local myRoot = player.Character and Util.getRoot(player.Character)
    if not myRoot then return nil end
    local nearest, nearestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local or_ = Util.getRoot(p.Character)
            local oh = p.Character:FindFirstChildOfClass("Humanoid")
            if or_ and oh and oh.Health > 0 then
                local dist = (or_.Position - myRoot.Position).Magnitude
                if dist < nearestDist then
                    nearest, nearestDist = or_, dist
                end
            end
        end
    end
    return nearest
end

local function startAimbot()
    aimbotState.active = true
    updateAimbotUI()
    if aimbotState.heartbeatConn then
        pcall(function() aimbotState.heartbeatConn:Disconnect() end)
    end
    aimbotState.heartbeatConn = RunService.RenderStepped:Connect(function()
        if not aimbotState.active then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local target = getNearestPlayer()
        if not target then return end
        local targetPos = target.Position + Vector3.new(0, 1.5, 0)
        local currentCF = cam.CFrame
        local targetCF = CFrame.new(currentCF.Position, targetPos)
        local newCF = currentCF:Lerp(targetCF, aimbotState.smooth)
        pcall(function() cam.CFrame = newCF end)
    end)
end

local function stopAimbot()
    aimbotState.active = false
    if aimbotState.heartbeatConn then
        pcall(function() aimbotState.heartbeatConn:Disconnect() end); aimbotState.heartbeatConn = nil
    end
    updateAimbotUI()
end

if _G.MFH_aimbotToggleBtn then
    _G.MFH_aimbotToggleBtn.MouseButton1Click:Connect(function()
        if aimbotState.active then
            stopAimbot()
        else
            local s = tonumber(_G.MFH_aimbotSmoothInput.Text) or 0.15
            aimbotState.smooth = math.clamp(s, 0.01, 1)
            startAimbot()
        end
    end)
end
if _G.MFH_aimbotSmoothInput then
    _G.MFH_aimbotSmoothInput:GetPropertyChangedSignal("Text"):Connect(function()
        local s = tonumber(_G.MFH_aimbotSmoothInput.Text)
        if s then aimbotState.smooth = math.clamp(s, 0.01, 1) end
    end)
end
updateAimbotUI()

--========================================================--
-- 🎥 第三人称视角（强制 + 缩放 + 旋转）
--========================================================--
local thirdPersonState = {
    active = false,
    distance = 15,
    minDistance = 5,
    conn = nil,
}

local function updateThirdPersonUI()
    if not _G.MFH_thirdPersonStatus then return end
    if thirdPersonState.active then
        _G.MFH_thirdPersonStatus.Text = "状态：强制第三人称中 🎥"
        _G.MFH_thirdPersonStatus.TextColor3 = THEME.accentC
        _G.MFH_thirdPersonToggleBtn.Text = "关闭强制第三人称"
        _G.MFH_thirdPersonToggleBtn.BackgroundColor3 = THEME.accentP
    else
        _G.MFH_thirdPersonStatus.Text = "状态：已关闭（使用游戏默认视角）"
        _G.MFH_thirdPersonStatus.TextColor3 = THEME.subtext
        _G.MFH_thirdPersonToggleBtn.Text = "开启强制第三人称"
        _G.MFH_thirdPersonToggleBtn.BackgroundColor3 = THEME.accentC
    end
end

local function startThirdPerson()
    thirdPersonState.active = true
    updateThirdPersonUI()
    if thirdPersonState.conn then
        pcall(function() thirdPersonState.conn:Disconnect() end)
    end
    thirdPersonState.conn = RunService.Heartbeat:Connect(function()
        if not thirdPersonState.active then return end
        pcall(function()
            -- 强制 Classic 模式（会禁用 LockFirstPerson）
            player.CameraMode = Enum.CameraMode.Classic
            local minD = math.max(thirdPersonState.minDistance, 1)
            local maxD = math.max(thirdPersonState.distance, minD + 1)
            -- 强制最小缩放距离 > 0，这样就没法进入第一人称
            if player.CameraMinZoomDistance < minD then
                player.CameraMinZoomDistance = minD
            end
            if player.CameraMaxZoomDistance < maxD then
                player.CameraMaxZoomDistance = maxD
            end
        end)
    end)
end

local function stopThirdPerson()
    thirdPersonState.active = false
    if thirdPersonState.conn then
        pcall(function() thirdPersonState.conn:Disconnect() end)
        thirdPersonState.conn = nil
    end
    pcall(function()
        player.CameraMode = Enum.CameraMode.Classic
        player.CameraMaxZoomDistance = 128
        player.CameraMinZoomDistance = 0.5
    end)
    updateThirdPersonUI()
end

if _G.MFH_thirdPersonToggleBtn then
    _G.MFH_thirdPersonToggleBtn.MouseButton1Click:Connect(function()
        if thirdPersonState.active then
            stopThirdPerson()
        else
            local d = tonumber(_G.MFH_thirdPersonDistanceInput.Text) or 15
            thirdPersonState.distance = math.clamp(d, 5, 100)
            thirdPersonState.minDistance = math.max(5, math.floor(thirdPersonState.distance * 0.3))
            startThirdPerson()
        end
    end)
end
if _G.MFH_thirdPersonDistanceInput then
    _G.MFH_thirdPersonDistanceInput:GetPropertyChangedSignal("Text"):Connect(function()
        local d = tonumber(_G.MFH_thirdPersonDistanceInput.Text)
        if d then
            thirdPersonState.distance = math.clamp(d, 5, 100)
            thirdPersonState.minDistance = math.max(5, math.floor(thirdPersonState.distance * 0.3))
        end
    end)
end
updateThirdPersonUI()
print("[MFH] 第三人称视角就绪")

--========================================================--
-- 🎭 伪装玩家（修复版）
--========================================================--
local disguiseState = { originalName = player.Name, current = nil }

local function applyDisguise(newName)
    if not newName or newName:gsub("%s", "") == "" then return false end
    newName = newName:sub(1, 20)
    if not disguiseState.current then
        disguiseState.originalName = player.Name
    end
    disguiseState.current = newName
    pcall(function() player.DisplayName = newName end)
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum.DisplayName = newName end)
        end
        pcall(function() char.Name = newName end)
        local head = char:FindFirstChild("Head")
        if head then
            local overhead = head:FindFirstChild("HumanoidDisplayName")
            if overhead and overhead:IsA("BillboardGui") then
                local label = overhead:FindFirstChildWhichIsA("TextLabel")
                if label then
                    pcall(function() label.Text = newName end)
                end
            end
        end
    end
    return true
end

local function restoreDisguise()
    disguiseState.current = nil
    pcall(function() player.DisplayName = disguiseState.originalName end)
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum.DisplayName = disguiseState.originalName end)
        end
        pcall(function() char.Name = disguiseState.originalName end)
    end
end

if _G.MFH_disguiseInput then
    local dp = allPanels["disguise"]
    if dp then
        for _, child in ipairs(dp:GetChildren()) do
            if child:IsA("TextButton") then
                if child.Text == "应用伪装" then
                    child.MouseButton1Click:Connect(function()
                        local n = _G.MFH_disguiseInput.Text
                        if not n or n:gsub("%s", "") == "" then
                            if _G.MFH_disguiseStatus then
                                _G.MFH_disguiseStatus.Text = "❌ 请输入玩家名字"
                                _G.MFH_disguiseStatus.TextColor3 = THEME.accentR
                            end
                            return
                        end
                        local ok = applyDisguise(n)
                        if _G.MFH_disguiseStatus then
                            if ok then
                                _G.MFH_disguiseStatus.Text = "✅ 已伪装为：" .. n
                                _G.MFH_disguiseStatus.TextColor3 = THEME.accentV
                            else
                                _G.MFH_disguiseStatus.Text = "❌ 伪装失败"
                                _G.MFH_disguiseStatus.TextColor3 = THEME.accentR
                            end
                        end
                    end)
                elseif child.Text == "恢复原样" then
                    child.MouseButton1Click:Connect(function()
                        restoreDisguise()
                        if _G.MFH_disguiseStatus then
                            _G.MFH_disguiseStatus.Text = "✅ 已恢复原名：" .. disguiseState.originalName
                            _G.MFH_disguiseStatus.TextColor3 = THEME.accentG
                        end
                    end)
                end
            end
        end
    end
end

player.CharacterAdded:Connect(function()
    task.wait(1)
    if disguiseState.current then applyDisguise(disguiseState.current) end
end)

--========================================================--
-- 🚀 超级功能包（14 项）
--========================================================--

-- 1. 速度光环
local speedAuraState = { active = false, conn = nil }
if _G.MFH_speedAuraBtn then
    _G.MFH_speedAuraBtn.MouseButton1Click:Connect(function()
        speedAuraState.active = not speedAuraState.active
        if speedAuraState.active then
            _G.MFH_speedAuraBtn.Text = "🚀 速度光环（已开启）"
            _G.MFH_speedAuraBtn.BackgroundColor3 = THEME.accentP
            if speedAuraState.conn then speedAuraState.conn:Disconnect() end
            speedAuraState.conn = RunService.Heartbeat:Connect(function()
                if not speedAuraState.active then return end
                local char = player.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.MoveDirection.Magnitude > 0.1 then
                    pcall(function() hum.WalkSpeed = math.max(hum.WalkSpeed, 60) end)
                end
            end)
        else
            _G.MFH_speedAuraBtn.Text = "🚀 速度光环（自动加速）"
            _G.MFH_speedAuraBtn.BackgroundColor3 = THEME.accentG
            if speedAuraState.conn then speedAuraState.conn:Disconnect(); speedAuraState.conn = nil end
        end
    end)
end

-- 2. 超级跳跃（多段跳）
local superJumpState = { active = false, conn = nil }
if _G.MFH_superJumpBtn then
    _G.MFH_superJumpBtn.MouseButton1Click:Connect(function()
        superJumpState.active = not superJumpState.active
        if superJumpState.active then
            _G.MFH_superJumpBtn.Text = "👟 超级跳跃（已开启）"
            _G.MFH_superJumpBtn.BackgroundColor3 = THEME.accentP
            if superJumpState.conn then superJumpState.conn:Disconnect() end
            superJumpState.conn = UserInputService.JumpRequest:Connect(function()
                if not superJumpState.active then return end
                local char = player.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    local st = hum:GetState()
                    if st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall then
                        task.wait(0.05)
                        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
                        task.wait(0.05)
                        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
                        task.wait(0.05)
                        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
                    end
                end
            end)
        else
            _G.MFH_superJumpBtn.Text = "👟 超级跳跃（多段跳）"
            _G.MFH_superJumpBtn.BackgroundColor3 = THEME.accentG
            if superJumpState.conn then superJumpState.conn:Disconnect(); superJumpState.conn = nil end
        end
    end)
end

-- 3. 滑翔翼
local glideState = { active = false, conn = nil }
if _G.MFH_glideBtn then
    _G.MFH_glideBtn.MouseButton1Click:Connect(function()
        glideState.active = not glideState.active
        if glideState.active then
            _G.MFH_glideBtn.Text = "🪂 滑翔翼（已开启）"
            _G.MFH_glideBtn.BackgroundColor3 = THEME.accentP
            if glideState.conn then glideState.conn:Disconnect() end
            glideState.conn = RunService.Heartbeat:Connect(function()
                if not glideState.active then return end
                local char = player.Character
                if not char then return end
                local root = Util.getRoot(char)
                if not root then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum:GetState() == Enum.HumanoidStateType.Freefall then
                    local v = root.AssemblyLinearVelocity
                    if v.Y < -20 then
                        pcall(function() root.AssemblyLinearVelocity = Vector3.new(v.X, -20, v.Z) end)
                    end
                end
            end)
        else
            _G.MFH_glideBtn.Text = "🪂 滑翔翼（下坠减速）"
            _G.MFH_glideBtn.BackgroundColor3 = THEME.accentG
            if glideState.conn then glideState.conn:Disconnect(); glideState.conn = nil end
        end
    end)
end

-- 4. 蜘蛛侠
local spiderState = { active = false, conn = nil }
if _G.MFH_spiderBtn then
    _G.MFH_spiderBtn.MouseButton1Click:Connect(function()
        spiderState.active = not spiderState.active
        if spiderState.active then
            _G.MFH_spiderBtn.Text = "🕸 蜘蛛侠（已开启）"
            _G.MFH_spiderBtn.BackgroundColor3 = THEME.accentP
            if spiderState.conn then spiderState.conn:Disconnect() end
            spiderState.conn = RunService.Heartbeat:Connect(function()
                if not spiderState.active then return end
                local char = player.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, true) end)
                end
            end)
        else
            _G.MFH_spiderBtn.Text = "🕸 蜘蛛侠（爬墙）"
            _G.MFH_spiderBtn.BackgroundColor3 = THEME.accentY
            if spiderState.conn then spiderState.conn:Disconnect(); spiderState.conn = nil end
        end
    end)
end

-- 5. 触碰即杀
local touchKillState = { active = false, conn = nil }
if _G.MFH_touchKillBtn then
    _G.MFH_touchKillBtn.MouseButton1Click:Connect(function()
        touchKillState.active = not touchKillState.active
        if touchKillState.active then
            _G.MFH_touchKillBtn.Text = "💥 触碰即杀（已开启）"
            _G.MFH_touchKillBtn.BackgroundColor3 = THEME.accentP
            if touchKillState.conn then touchKillState.conn:Disconnect() end
            touchKillState.conn = RunService.Heartbeat:Connect(function()
                if not touchKillState.active then return end
                local char = player.Character
                if not char then return end
                local myRoot = Util.getRoot(char)
                if not myRoot then return end
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character then
                        local oRoot = Util.getRoot(other.Character)
                        local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                        if oRoot and oHum and oHum.Health > 0 then
                            if (oRoot.Position - myRoot.Position).Magnitude < 3 then
                                pcall(function()
                                    local tool = char:FindFirstChildOfClass("Tool")
                                    if tool then
                                        local handle = tool:FindFirstChild("Handle")
                                        if handle then handle.Touched:Fire(oRoot) end
                                    end
                                    oHum.Health = 0
                                end)
                            end
                        end
                    end
                end
            end)
        else
            _G.MFH_touchKillBtn.Text = "💥 触碰即杀"
            _G.MFH_touchKillBtn.BackgroundColor3 = THEME.accentR
            if touchKillState.conn then touchKillState.conn:Disconnect(); touchKillState.conn = nil end
        end
    end)
end

-- 6. 坠落玩家
local dropState = { active = false, conn = nil }
if _G.MFH_dropBtn then
    _G.MFH_dropBtn.MouseButton1Click:Connect(function()
        dropState.active = not dropState.active
        if dropState.active then
            _G.MFH_dropBtn.Text = "🪁 坠落玩家（已开启）"
            _G.MFH_dropBtn.BackgroundColor3 = THEME.accentP
            if dropState.conn then dropState.conn:Disconnect() end
            dropState.conn = RunService.Heartbeat:Connect(function()
                if not dropState.active then return end
                local char = player.Character
                if not char then return end
                local myRoot = Util.getRoot(char)
                if not myRoot then return end
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character then
                        local oRoot = Util.getRoot(other.Character)
                        local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                        if oRoot and oHum and oHum.Health > 0 then
                            if (oRoot.Position - myRoot.Position).Magnitude < 15 then
                                pcall(function()
                                    local v = oRoot.AssemblyLinearVelocity
                                    oRoot.AssemblyLinearVelocity = Vector3.new(v.X, -300, v.Z)
                                end)
                            end
                        end
                    end
                end
            end)
        else
            _G.MFH_dropBtn.Text = "🪁 坠落玩家（拉下来）"
            _G.MFH_dropBtn.BackgroundColor3 = THEME.accentR
            if dropState.conn then dropState.conn:Disconnect(); dropState.conn = nil end
        end
    end)
end

-- 7. 环绕旋转
local orbitState = { active = false, conn = nil, angle = 0, orbitDist = 8 }
if _G.MFH_orbitBtn then
    _G.MFH_orbitBtn.MouseButton1Click:Connect(function()
        orbitState.active = not orbitState.active
        if orbitState.active then
            _G.MFH_orbitBtn.Text = "🎢 环绕旋转（已开启）"
            _G.MFH_orbitBtn.BackgroundColor3 = THEME.accentP
            orbitState.angle = 0
            if orbitState.conn then orbitState.conn:Disconnect() end
            orbitState.conn = RunService.Heartbeat:Connect(function(dt)
                if not orbitState.active then return end
                local char = player.Character
                if not char then return end
                local myRoot = Util.getRoot(char)
                if not myRoot then return end
                orbitState.angle = orbitState.angle + dt * 2
                local idx = 0
                local total = 0
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character and Util.getRoot(other.Character) then
                        total = total + 1
                    end
                end
                if total == 0 then return end
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character then
                        local oRoot = Util.getRoot(other.Character)
                        if oRoot then
                            idx = idx + 1
                            local a = orbitState.angle + (idx / total) * math.pi * 2
                            local targetPos = myRoot.Position + Vector3.new(math.cos(a) * orbitState.orbitDist, 2, math.sin(a) * orbitState.orbitDist)
                            pcall(function()
                                oRoot.AssemblyLinearVelocity = (targetPos - oRoot.Position) * 5
                            end)
                        end
                    end
                end
            end)
        else
            _G.MFH_orbitBtn.Text = "🎢 环绕旋转（绕你转圈）"
            _G.MFH_orbitBtn.BackgroundColor3 = THEME.accentV
            if orbitState.conn then orbitState.conn:Disconnect(); orbitState.conn = nil end
        end
    end)
end

-- 8. 自动点击器
local autoclickState = { active = false, thread = nil, interval = 0.05 }
if _G.MFH_autoclickBtn then
    _G.MFH_autoclickBtn.MouseButton1Click:Connect(function()
        autoclickState.active = not autoclickState.active
        if autoclickState.active then
            _G.MFH_autoclickBtn.Text = "🖱 自动点击器（已开启）"
            _G.MFH_autoclickBtn.BackgroundColor3 = THEME.accentP
            autoclickState.thread = task.spawn(function()
                while autoclickState.active do
                    pcall(function()
                        if VirtualInputManager then
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                        end
                    end)
                    task.wait(autoclickState.interval)
                end
            end)
        else
            _G.MFH_autoclickBtn.Text = "🖱 自动点击器"
            _G.MFH_autoclickBtn.BackgroundColor3 = THEME.accentT
            if autoclickState.thread then
                pcall(function() task.cancel(autoclickState.thread) end)
                autoclickState.thread = nil
            end
        end
    end)
end

-- 9. 吸附玩家
local suctionState = { active = false, conn = nil }
if _G.MFH_suctionBtn then
    _G.MFH_suctionBtn.MouseButton1Click:Connect(function()
        suctionState.active = not suctionState.active
        if suctionState.active then
            _G.MFH_suctionBtn.Text = "🧲 吸附玩家（已开启）"
            _G.MFH_suctionBtn.BackgroundColor3 = THEME.accentP
            if suctionState.conn then suctionState.conn:Disconnect() end
            suctionState.conn = RunService.Heartbeat:Connect(function()
                if not suctionState.active then return end
                local char = player.Character
                if not char then return end
                local myRoot = Util.getRoot(char)
                if not myRoot then return end
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character then
                        local oRoot = Util.getRoot(other.Character)
                        local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                        if oRoot and oHum and oHum.Health > 0 then
                            local dist = (oRoot.Position - myRoot.Position).Magnitude
                            if dist < 60 and dist > 4 then
                                local dir = (myRoot.Position - oRoot.Position).Unit
                                pcall(function()
                                    oRoot.AssemblyLinearVelocity = dir * 80 + Vector3.new(0, 10, 0)
                                end)
                            end
                        end
                    end
                end
            end)
        else
            _G.MFH_suctionBtn.Text = "🧲 吸附玩家（拉面前）"
            _G.MFH_suctionBtn.BackgroundColor3 = THEME.accentC
            if suctionState.conn then suctionState.conn:Disconnect(); suctionState.conn = nil end
        end
    end)
end

-- 10. 反传送
local antiTPState = { active = false, conn = nil, lastPos = nil }
if _G.MFH_antiTPBtn then
    _G.MFH_antiTPBtn.MouseButton1Click:Connect(function()
        antiTPState.active = not antiTPState.active
        if antiTPState.active then
            _G.MFH_antiTPBtn.Text = "🕶 反传送（已开启）"
            _G.MFH_antiTPBtn.BackgroundColor3 = THEME.accentP
            antiTPState.lastPos = nil
            if antiTPState.conn then antiTPState.conn:Disconnect() end
            antiTPState.conn = RunService.Heartbeat:Connect(function()
                if not antiTPState.active then return end
                local char = player.Character
                if not char then return end
                local root = Util.getRoot(char)
                if not root then return end
                if antiTPState.lastPos then
                    local dist = (root.Position - antiTPState.lastPos).Magnitude
                    if dist > 50 then
                        pcall(function() root.CFrame = CFrame.new(antiTPState.lastPos) end)
                    end
                end
                antiTPState.lastPos = root.Position
            end)
        else
            _G.MFH_antiTPBtn.Text = "🕶 反传送（防被传）"
            _G.MFH_antiTPBtn.BackgroundColor3 = THEME.accentO
            if antiTPState.conn then antiTPState.conn:Disconnect(); antiTPState.conn = nil end
        end
    end)
end

-- 11. 准星加强
local crosshairState = { active = false, gui = nil }
if _G.MFH_crosshairBtn then
    _G.MFH_crosshairBtn.MouseButton1Click:Connect(function()
        crosshairState.active = not crosshairState.active
        if crosshairState.active then
            _G.MFH_crosshairBtn.Text = "🎯 准星加强（已开启）"
            _G.MFH_crosshairBtn.BackgroundColor3 = THEME.accentP
            local cg = Instance.new("ScreenGui")
            cg.Name = "MFH_Crosshair"
            cg.IgnoreGuiInset = true
            cg.ResetOnSpawn = false
            cg.Parent = playerGui
            local cdot = Instance.new("Frame")
            cdot.Size = UDim2.fromOffset(6, 6)
            cdot.Position = UDim2.new(0.5, -3, 0.5, -3)
            cdot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
            cdot.BorderSizePixel = 0
            cdot.Parent = cg
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = cdot
            local line = Instance.new("Frame")
            line.Size = UDim2.fromOffset(40, 2)
            line.Position = UDim2.new(0.5, -20, 0.5, -1)
            line.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
            line.BorderSizePixel = 0
            line.BackgroundTransparency = 0.3
            line.Parent = cg
            crosshairState.gui = cg
        else
            _G.MFH_crosshairBtn.Text = "🎯 准星加强（屏幕中央）"
            _G.MFH_crosshairBtn.BackgroundColor3 = THEME.accentY
            if crosshairState.gui then
                Util.safeDestroy(crosshairState.gui); crosshairState.gui = nil
            end
        end
    end)
end

-- 12. 网络延迟显示
local pingState = { active = false, label = nil, conn = nil }
if _G.MFH_pingBtn then
    _G.MFH_pingBtn.MouseButton1Click:Connect(function()
        pingState.active = not pingState.active
        if pingState.active then
            _G.MFH_pingBtn.Text = "🌐 网络延迟（已开启）"
            _G.MFH_pingBtn.BackgroundColor3 = THEME.accentP
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.fromOffset(180, 32)
            lbl.Position = UDim2.new(0, 12, 0, 60)
            lbl.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
            lbl.BackgroundTransparency = 0.3
            lbl.BorderSizePixel = 0
            lbl.Text = "Ping: --"
            lbl.TextColor3 = Color3.fromRGB(0, 220, 200)
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 14
            lbl.Parent = gui
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = lbl
            pingState.label = lbl
            if pingState.conn then pingState.conn:Disconnect() end
            pingState.conn = RunService.Heartbeat:Connect(function()
                if not pingState.active then return end
                local ping = math.floor(player:GetNetworkPing() * 1000)
                if pingState.label then
                    pingState.label.Text = "🌐 Ping: " .. ping .. " ms"
                end
            end)
        else
            _G.MFH_pingBtn.Text = "🌐 网络延迟显示"
            _G.MFH_pingBtn.BackgroundColor3 = THEME.accentC
            if pingState.label then Util.safeDestroy(pingState.label); pingState.label = nil end
            if pingState.conn then pingState.conn:Disconnect(); pingState.conn = nil end
        end
    end)
end

-- 13. 动画加速
local animSpeedState = { active = false, conn = nil }
if _G.MFH_animSpeedBtn then
    _G.MFH_animSpeedBtn.MouseButton1Click:Connect(function()
        animSpeedState.active = not animSpeedState.active
        if animSpeedState.active then
            _G.MFH_animSpeedBtn.Text = "🎬 动画加速（已开启）"
            _G.MFH_animSpeedBtn.BackgroundColor3 = THEME.accentP
            if animSpeedState.conn then animSpeedState.conn:Disconnect() end
            animSpeedState.conn = RunService.Heartbeat:Connect(function()
                if not animSpeedState.active then return end
                local char = player.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    pcall(function()
                        for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                            if track.Speed < 3 then track:AdjustSpeed(3) end
                        end
                    end)
                end
            end)
        else
            _G.MFH_animSpeedBtn.Text = "🎬 动画加速（3x）"
            _G.MFH_animSpeedBtn.BackgroundColor3 = THEME.accentV
            if animSpeedState.conn then animSpeedState.conn:Disconnect(); animSpeedState.conn = nil end
        end
    end)
end

-- 14. 无敌+
local godPlusState = { active = false, conn = nil }
if _G.MFH_godPlusBtn then
    _G.MFH_godPlusBtn.MouseButton1Click:Connect(function()
        godPlusState.active = not godPlusState.active
        if godPlusState.active then
            _G.MFH_godPlusBtn.Text = "🛡 无敌+（已开启）"
            _G.MFH_godPlusBtn.BackgroundColor3 = THEME.accentP
            if godPlusState.conn then godPlusState.conn:Disconnect() end
            godPlusState.conn = RunService.Heartbeat:Connect(function()
                if not godPlusState.active then return end
                local char = player.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health < hum.MaxHealth then
                    pcall(function() hum.Health = hum.MaxHealth end)
                end
            end)
        else
            _G.MFH_godPlusBtn.Text = "🛡 无敌+（服务端尝试）"
            _G.MFH_godPlusBtn.BackgroundColor3 = THEME.accentG
            if godPlusState.conn then godPlusState.conn:Disconnect(); godPlusState.conn = nil end
        end
    end)
end
print("[MFH] 超级功能包就绪（14 项）")

--========================================================--
-- 关于
--========================================================--
local function refreshAbout()
    if not _G.MFH_aboutInfo then return end
    local lines = {
        "📜 脚本名称：MFH 脚本",
        "📌 脚本版本：" .. CONFIG.VERSION,
        "🖥 执行模式：客户端" .. (ReplicatedStorage:FindFirstChild(CONFIG.REMOTE_NAME) and " + 服务端已挂载" or "（仅客户端）"),
        "",
        "👥 服务器玩家数：" .. #Players:GetPlayers() .. " 人",
        "🆔 服务器 JobId：",
        " " .. tostring(game.JobId),
        "🎮 游戏 PlaceId：" .. tostring(game.PlaceId),
        "👤 用户名：" .. player.Name,
        "📛 显示名：" .. player.DisplayName,
        "🏓 延迟：" .. math.floor(player:GetNetworkPing() * 1000) .. " ms",
        "",
        "🤖 已加载模块：",
        " · 道具获取系统",
        " · 说话/霸屏",
        " · 飞行（修复版）",
        " · 保存传送",
        " · 原地复活/循环回血",
        " · 防甩飞/甩飞/甩飞2（接触版修复）",
        " · ESP 透视",
        " · 移动增强/穿墙",
        " · 工具/追踪/战斗/服务器/漏洞",
        " · 🖐 控制物体",
        " · FE 功能（11 项）",
        " · 🌌 文字天空（跟随相机）",
        " · 美化包/伪装（修复版）",
        " · 🎥 第三人称视角（新增）",
        " · 🛠 自定义 MFH（窗口/字体）",
        " · 子弹追踪",
        " · 🚀 超级功能包（14 项）",
        " · 🔍 模糊搜索（多关键词）",
    }
    _G.MFH_aboutInfo.Text = table.concat(lines, "\n")
end

if _G.MFH_refreshAboutBtn then
    _G.MFH_refreshAboutBtn.MouseButton1Click:Connect(function() pcall(refreshAbout) end)
end
pcall(refreshAbout)
task.spawn(function()
    while gui and gui.Parent do
        task.wait(3)
        if allPanels.about and allPanels.about.Visible then pcall(refreshAbout) end
    end
end)

--========================================================--
-- 角色生命周期
--========================================================--
local function onCharacter(char)
    attachReviveHooks(char)

    if reviveState.enabled and reviveState.lastDeathCFrame then
        handleRevive(char)
    else
        task.spawn(function()
            task.wait(0.5)
            if flyState.active then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                pcall(function()
                    if hum.PlatformStand then hum.PlatformStand = false end
                    if hum.WalkSpeed < 16 then hum.WalkSpeed = 16 end
                end)
            end
        end)
    end

    if antiState.active then
        antiState.originalStates = setmetatable({}, {__mode = "k"})
        hookAntiChar(char)
    end
    if flingState.active then flingState.lastHit = {} end
    if fling2State.active then fling2State.lastHit = {} end
    if espState.active then
        task.spawn(function()
            task.wait(0.5)
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player then createESPForPlayer(p) end
            end
        end)
    end
    if flyState.active then
        task.spawn(function()
            task.wait(0.3)
            if flyState.conn then
                pcall(function() flyState.conn:Disconnect() end); flyState.conn = nil
            end
            flyState.bv = nil; flyState.bg = nil; flyState.active = false
            startFly()
        end)
    end
    if noclipState.active then task.wait(0.3); startNoclip() end
    if feState.lift then
        task.spawn(function()
            task.wait(0.5)
            if feState.liftConn then pcall(function() feState.liftConn:Disconnect() end) end
            feState.lift = false
            if _G.MFH_feLiftBtn then pcall(function() _G.MFH_feLiftBtn:Fire("MouseButton1Click") end) end
        end)
    end
    if feState.trailOn then
        task.spawn(function()
            task.wait(0.5)
            feState.trailOn = false
            if _G.MFH_feTrailBtn then pcall(function() _G.MFH_feTrailBtn:Fire("MouseButton1Click") end) end
        end)
    end
    task.wait(0.5)
    if gui and gui.Parent ~= playerGui then
        pcall(function() gui.Parent = playerGui end)
    end
end

player.CharacterAdded:Connect(function(char)
    local ok, err = pcall(onCharacter, char)
    if not ok then warn("[MFH] onCharacter:", err) end
end)
if player.Character then
    task.spawn(function() pcall(onCharacter, player.Character) end)
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    task.wait(0.5)
    local newScale = calculateScale()
    if math.abs(newScale - winTargetScale) > 0.05 then
        winTargetScale = newScale
        uiScale = newScale
        if isOpen then winScale.Scale = newScale end
    end
end)

Players.PlayerAdded:Connect(function()
    if allPanels.about and allPanels.about.Visible then pcall(refreshAbout) end
end)
Players.PlayerRemoving:Connect(function(p)
    flingState.lastHit[p] = nil
    fling2State.lastHit[p] = nil
    if allPanels.about and allPanels.about.Visible then pcall(refreshAbout) end
end)

--========================================================--
-- 启动完成
--========================================================--
print("[MFH " .. CONFIG.VERSION .. " - 客户端] 已加载 ✔")
print(" 模块：道具/说话/霸屏/飞行(修复)/保存传送/复活/治疗/防甩/甩飞(接触版修复)/甩飞2(接触版修复)/ESP/移动/穿墙/工具/追踪/战斗/服务器/漏洞/控制物体/FE(11项)/文字天空(跟随)/美化/伪装(修复)/第三人称(新增)/自定义MFH(窗口+字体)/追踪/超能包(14项)/关于")
if #buildErrors > 0 then
    warn("[MFH] 以下面板构建失败：" .. table.concat(buildErrors, ", "))
end
task.delay(0.5, function() pcall(openWin) end)
