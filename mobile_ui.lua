--[[
    mobile_ui.lua
    Ultra-Polished Mobile UI for Atomware (Trident Survival)
    Two-column compact layout with draggable mobile controls
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local function trackConnection(connection)
    if _G.AtomwareConfig then return _G.AtomwareConfig:TrackConnection(connection) end
    return connection
end

--//==================================================
--// GLOBAL EVENT BINDING SYSTEM
--//==================================================

_G.AtomwareEvents = _G.AtomwareEvents or {}
_G.AtomwarePendingEvents = {}

local function registerAtomwareEvent(name, callback)
    _G.AtomwareEvents[name] = callback
    local pending = _G.AtomwarePendingEvents[name]
    if pending then
        _G.AtomwarePendingEvents[name] = nil
        task.spawn(function()
            local ok, err = pcall(callback, table.unpack(pending, 1, pending.n))
            if not ok then warn("Atomware: event '" .. name .. "' failed: " .. tostring(err)) end
        end)
    end
end

_G.OnToggle = function(name, callback)
    registerAtomwareEvent(name, callback)
end

_G.OnSlider = function(name, callback)
    registerAtomwareEvent(name, callback)
end

_G.OnDropdown = function(name, callback)
    registerAtomwareEvent(name, callback)
end

_G.OnColorPicker = function(name, callback)
    registerAtomwareEvent(name, callback)
end

_G.OnKeybind = function(name, callback)
    registerAtomwareEvent(name, callback)
end

_G.FireEvent = function(name, ...)
    if _G.AtomwareConfig and select("#", ...) == 1 then
        _G.AtomwareConfig:Store(name, (...))
    end
    local callback = _G.AtomwareEvents[name]
    if callback then
        local args = { ... }
        local count = select("#", ...)
        task.spawn(function()
            local ok, err = pcall(callback, table.unpack(args, 1, count))
            if not ok then warn("Atomware: event '" .. name .. "' failed: " .. tostring(err)) end
        end)
        return
    end
    local args = { ... }
    args.n = select("#", ...)
    _G.AtomwarePendingEvents[name] = args
end

local function bindSetting(name, default, apply, validate)
    if _G.AtomwareConfig then return _G.AtomwareConfig:Register(name, default, apply, validate) end
    return default
end

--//==================================================
--// MOBILE THEME & STYLING
--//==================================================

local THEME = {
    Background      = Color3.fromRGB(8, 6, 15),
    Header          = Color3.fromRGB(13, 9, 24),
    Card            = Color3.fromRGB(16, 11, 30),
    CardAlt         = Color3.fromRGB(24, 16, 44),
    CardHover       = Color3.fromRGB(32, 20, 56),

    Border          = Color3.fromRGB(105, 45, 195),
    BorderDim       = Color3.fromRGB(55, 30, 95),
    Accent          = Color3.fromRGB(157, 48, 255),
    AccentBright    = Color3.fromRGB(205, 104, 255),
    AccentDark      = Color3.fromRGB(80, 26, 142),

    Text            = Color3.fromRGB(245, 241, 255),
    TextMuted       = Color3.fromRGB(170, 155, 205),
    TextDim         = Color3.fromRGB(110, 95, 140),

    Green           = Color3.fromRGB(42, 255, 157),
    Red             = Color3.fromRGB(255, 75, 125),
}

local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

local function tween(inst, info, props)
    local t = TweenService:Create(inst, info, props)
    t:Play()
    return t
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.Border
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function padding(parent, l, r, t, b)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, l or 0)
    p.PaddingRight = UDim.new(0, r or 0)
    p.PaddingTop = UDim.new(0, t or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.Parent = parent
    return p
end

--//==================================================
--// SCREEN GUI ROOT
--//==================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AtomwareMobileUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 100

local playerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
if not playerGui then error("Atomware: PlayerGui was unavailable after 10 seconds") end
local existingGui = playerGui:FindFirstChild("AtomwareMobileUI")
if existingGui then existingGui:Destroy() end
ScreenGui.Parent = playerGui
if _G.AtomwareConfig then _G.AtomwareConfig:AttachUI(ScreenGui, "Mobile") end

--//==================================================
--// FLOATING ACTION BUTTONS (MOBILE DRAGGABLE)
--//==================================================

local mobileLayoutEditing = false
local mobileControlScale = 1
local mobileLayoutControls = {}
local mobileLayoutHandles = {}
local freeCamTouchPad
local freeCamEnabled = false

local function configureMobileControl(frame, name, defaultX, defaultY)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    local function setX(value) frame.Position = UDim2.new(value, 0, frame.Position.Y.Scale, 0) end
    local function setY(value) frame.Position = UDim2.new(frame.Position.X.Scale, 0, value, 0) end
    local config = _G.AtomwareConfig
    local storedX = config and config.Values[name .. " X"]
    local storedY = config and config.Values[name .. " Y"]
    local validatePosition = function(v) return type(v) == "number" and v >= 0.03 and v <= 0.97 end
    local x = bindSetting(name .. " X", storedX or defaultX, setX, validatePosition)
    local y = bindSetting(name .. " Y", storedY or defaultY, setY, validatePosition)
    frame.Position = UDim2.fromScale(x, y)
    local scale = Instance.new("UIScale")
    scale.Scale = mobileControlScale
    scale.Parent = frame
    table.insert(mobileLayoutControls, {
        frame = frame, scale = scale, name = name,
        defaultX = defaultX, defaultY = defaultY,
    })

    local grip = Instance.new("TextButton")
    grip.Name = "LayoutDragHandle"
    grip.Size = UDim2.new(1, 0, 0, 24)
    grip.BackgroundColor3 = THEME.Accent
    grip.BackgroundTransparency = 0.15
    grip.Text = "DRAG"
    grip.TextSize = 9
    grip.TextColor3 = THEME.Text
    grip.Font = FONT_BOLD
    grip.Visible = mobileLayoutEditing
    grip.ZIndex = 150
    grip.Parent = frame
    corner(grip, 6)
    local dragging, dragInput, dragStart = false, nil, nil
    trackConnection(grip.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, dragInput, dragStart = true, input, input.Position
        end
    end))
    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if not dragging or (input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseMovement) then return end
        if dragInput and dragInput.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then return end
        local camera = workspace.CurrentCamera
        if not camera then return end
        local delta = input.Position - dragStart
        local center = frame.AbsolutePosition + Vector2.new(
            frame.AbsoluteSize.X * frame.AnchorPoint.X,
            frame.AbsoluteSize.Y * frame.AnchorPoint.Y
        ) + delta
        local halfWidth = frame.AbsoluteSize.X * 0.5
        local halfHeight = frame.AbsoluteSize.Y * 0.5
        local minX, maxX = halfWidth / camera.ViewportSize.X, 1 - halfWidth / camera.ViewportSize.X
        local minY, maxY = halfHeight / camera.ViewportSize.Y, 1 - halfHeight / camera.ViewportSize.Y
        if minX > maxX then minX, maxX = 0.5, 0.5 end
        if minY > maxY then minY, maxY = 0.5, 0.5 end
        local nx = math.clamp(center.X / camera.ViewportSize.X, minX, maxX)
        local ny = math.clamp(center.Y / camera.ViewportSize.Y, minY, maxY)
        frame.Position = UDim2.fromScale(nx, ny)
        if _G.AtomwareConfig then
            _G.AtomwareConfig:Store(name .. " X", nx)
            _G.AtomwareConfig:Store(name .. " Y", ny)
        end
        dragStart = input.Position
    end))
    trackConnection(UserInputService.InputEnded:Connect(function(input)
        if dragging and dragInput then
            local released = input == dragInput
                or (dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)
            if released then dragging, dragInput = false, nil end
        end
    end))
    return function(editing) grip.Visible = editing end
end

local function setMobileLayoutEditing(enabled)
    mobileLayoutEditing = enabled == true
    for _, setVisible in ipairs(mobileLayoutHandles) do setVisible(mobileLayoutEditing) end
    if freeCamTouchPad then freeCamTouchPad.Visible = freeCamEnabled or mobileLayoutEditing end
end

local function setMobileControlScale(value)
    mobileControlScale = math.clamp(value, 0.7, 1.5)
    for _, item in ipairs(mobileLayoutControls) do item.scale.Scale = mobileControlScale end
end

local function resetMobileLayout()
    for _, item in ipairs(mobileLayoutControls) do
        local x, y = item.defaultX, item.defaultY
        item.frame.Position = UDim2.fromScale(x, y)
        if _G.AtomwareConfig then
            _G.AtomwareConfig:Store(item.name .. " X", x)
            _G.AtomwareConfig:Store(item.name .. " Y", y)
        end
    end
end

local function makeFloatingButton(name, text, iconColor, initPos, onClick)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.fromOffset(52, 52)
    btn.Position = initPos
    btn.BackgroundColor3 = THEME.Header
    btn.Text = text
    btn.TextColor3 = iconColor or THEME.AccentBright
    btn.TextSize = 20
    btn.Font = FONT_BOLD
    btn.AutoButtonColor = false
    btn.Parent = ScreenGui
    corner(btn, 16)
    stroke(btn, THEME.Accent, 1.5)
    table.insert(mobileLayoutHandles, configureMobileControl(btn, name, 0.92, 0.84))

    trackConnection(btn.MouseButton1Click:Connect(function()
        if onClick then onClick(btn) end
    end))

    return btn
end

-- Floating Menu Toggle
local MobileToggleBtn

--//==================================================
--// MAIN WINDOW CONTAINER (FIXED NON-SCROLLING HEADER & TABS)
--//==================================================

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.fromScale(0.5, 0.5)
MainFrame.Size = UDim2.new(0.97, 0, 0.90, 0)
MainFrame.BackgroundColor3 = THEME.Background
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
corner(MainFrame, 12)
stroke(MainFrame, THEME.Border, 1.5)

local UIVisible = true
local function setUIVisible(state)
    UIVisible = state
    if state then
        MainFrame.Visible = true
        tween(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0.97, 0, 0.90, 0)
        })
    else
        tween(MainFrame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.fromOffset(0, 0)
        }).Completed:Once(function()
            if not UIVisible then MainFrame.Visible = false end
        end)
    end
end

MobileToggleBtn = makeFloatingButton("MobileToggle", "A", THEME.AccentBright, UDim2.new(1, -66, 1, -130), function()
    setUIVisible(not UIVisible)
end)

-- Fixed Header (Never Scrolls)
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 46)
Header.BackgroundColor3 = THEME.Header
Header.BorderSizePixel = 0
Header.Parent = MainFrame
stroke(Header, THEME.BorderDim, 1)

local HeaderAccent = Instance.new("Frame")
HeaderAccent.Size = UDim2.fromOffset(4, 24)
HeaderAccent.Position = UDim2.fromOffset(12, 11)
HeaderAccent.BackgroundColor3 = THEME.Accent
HeaderAccent.BorderSizePixel = 0
HeaderAccent.Parent = Header
corner(HeaderAccent, 2)

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Text = "atomware  <font color=\"#cd68ff\">mobile</font>"
Title.RichText = true
Title.Size = UDim2.new(0.6, 0, 1, 0)
Title.Position = UDim2.fromOffset(24, 0)
Title.TextSize = 18
Title.TextColor3 = THEME.Text
Title.Font = FONT_BOLD
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(34, 28)
CloseBtn.Position = UDim2.new(1, -42, 0, 9)
CloseBtn.BackgroundColor3 = THEME.Card
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = THEME.Red
CloseBtn.TextSize = 13
CloseBtn.Font = FONT_BOLD
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Header
corner(CloseBtn, 6)
stroke(CloseBtn, THEME.BorderDim, 1)
trackConnection(CloseBtn.MouseButton1Click:Connect(function() setUIVisible(false) end))

-- Navigation Tab Bar (Fixed, Stays Locked Under Header)
local TabBar = Instance.new("ScrollingFrame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, 0, 0, 42)
TabBar.Position = UDim2.fromOffset(0, 46)
TabBar.BackgroundColor3 = THEME.Header
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 0
TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
TabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
TabBar.Parent = MainFrame
padding(TabBar, 8, 8, 4, 4)

local TabListLayout = Instance.new("UIListLayout")
TabListLayout.FillDirection = Enum.FillDirection.Horizontal
TabListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabListLayout.Padding = UDim.new(0, 6)
TabListLayout.Parent = TabBar

-- Content Viewport (Scrollable Content Container)
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.BackgroundTransparency = 1
ContentArea.Position = UDim2.fromOffset(0, 88)
ContentArea.Size = UDim2.new(1, 0, 1, -88)
ContentArea.Parent = MainFrame

local Pages = {}
local TabButtons = {}
local CurrentPageName = "Visuals"
local responsiveLayouts = {}

--//==================================================
--// TWO-COLUMN PAGE CREATOR
--//==================================================

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Size = UDim2.new(1, 0, 1, 0)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = THEME.Accent
    page.Visible = false
    page.Parent = ContentArea
    padding(page, 8, 8, 8, 20)

    -- Horizontal two-column container
    local colContainer = Instance.new("Frame")
    colContainer.Name = "ColContainer"       -- named so getCols() can find it reliably
    colContainer.BackgroundTransparency = 1
    colContainer.Size = UDim2.new(1, 0, 0, 0)
    colContainer.AutomaticSize = Enum.AutomaticSize.Y
    colContainer.Parent = page

    local hList = Instance.new("UIListLayout")
    hList.FillDirection = Enum.FillDirection.Horizontal
    hList.VerticalAlignment = Enum.VerticalAlignment.Top
    hList.HorizontalAlignment = Enum.HorizontalAlignment.Left
    hList.Padding = UDim.new(0, 8)
    hList.SortOrder = Enum.SortOrder.LayoutOrder
    hList.Parent = colContainer

    local leftCol = Instance.new("Frame")
    leftCol.BackgroundTransparency = 1
    leftCol.Size = UDim2.new(0.5, -4, 0, 0)
    leftCol.AutomaticSize = Enum.AutomaticSize.Y
    leftCol.LayoutOrder = 1
    leftCol.Parent = colContainer

    local leftList = Instance.new("UIListLayout")
    leftList.Padding = UDim.new(0, 8)
    leftList.SortOrder = Enum.SortOrder.LayoutOrder
    leftList.Parent = leftCol

    local rightCol = Instance.new("Frame")
    rightCol.BackgroundTransparency = 1
    rightCol.Size = UDim2.new(0.5, -4, 0, 0)
    rightCol.AutomaticSize = Enum.AutomaticSize.Y
    rightCol.LayoutOrder = 2
    rightCol.Parent = colContainer

    local rightList = Instance.new("UIListLayout")
    rightList.Padding = UDim.new(0, 8)
    rightList.SortOrder = Enum.SortOrder.LayoutOrder
    rightList.Parent = rightCol

    table.insert(responsiveLayouts, { layout = hList, left = leftCol, right = rightCol })

    Pages[name] = page
    return page, leftCol, rightCol
end

local function switchPage(name)
    CurrentPageName = name
    for pName, pFrame in pairs(Pages) do
        pFrame.Visible = (pName == name)
    end
    for pName, btn in pairs(TabButtons) do
        local active = (pName == name)
        tween(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = active and THEME.AccentDark or THEME.Card,
            TextColor3 = active and THEME.AccentBright or THEME.TextMuted
        })
    end
end

--//==================================================
--// ROBUST CARD CONTAINER WIDGET BUILDER
--//==================================================

local function createCard(parent, title)
    local card = Instance.new("Frame")
    card.Name = title .. "Card"
    card.BackgroundColor3 = THEME.Card
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Parent = parent
    corner(card, 10)
    stroke(card, THEME.BorderDim, 1)
    padding(card, 10, 10, 8, 10)

    local cardLayout = Instance.new("UIListLayout")
    cardLayout.Padding = UDim.new(0, 6)
    cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
    cardLayout.Parent = card

    -- Card Header
    local head = Instance.new("Frame")
    head.Name = "CardHeader"
    head.LayoutOrder = 1
    head.Size = UDim2.new(1, 0, 0, 20)
    head.BackgroundTransparency = 1
    head.Parent = card

    local acc = Instance.new("Frame")
    acc.Size = UDim2.fromOffset(3, 14)
    acc.Position = UDim2.fromOffset(0, 3)
    acc.BackgroundColor3 = THEME.Accent
    acc.BorderSizePixel = 0
    acc.Parent = head
    corner(acc, 2)

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.Size = UDim2.new(1, -10, 1, 0)
    lbl.Position = UDim2.fromOffset(9, 0)
    lbl.TextSize = 12
    lbl.TextColor3 = THEME.Text
    lbl.Font = FONT_BOLD
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Parent = head

    -- Divider
    local div = Instance.new("Frame")
    div.Name = "Divider"
    div.LayoutOrder = 2
    div.Size = UDim2.new(1, 0, 0, 1)
    div.BackgroundColor3 = THEME.BorderDim
    div.BorderSizePixel = 0
    div.Parent = card

    -- Card Body
    local body = Instance.new("Frame")
    body.Name = "Body"
    body.LayoutOrder = 3
    body.BackgroundTransparency = 1
    body.Size = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.Parent = card

    local bodyLayout = Instance.new("UIListLayout")
    bodyLayout.Padding = UDim.new(0, 6)
    bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bodyLayout.Parent = body

    return card, body
end

local function createToggle(parent, setting, defaultState, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text = setting
    lbl.Size = UDim2.new(1, -56, 1, 0)
    lbl.TextSize = 11
    lbl.TextColor3 = THEME.Text
    lbl.Font = FONT
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(44, 22)
    btn.Position = UDim2.new(1, -44, 0.5, -11)
    btn.BackgroundColor3 = defaultState and THEME.Accent or THEME.CardAlt
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = row
    corner(btn, 11)
    stroke(btn, defaultState and THEME.AccentBright or THEME.BorderDim, 1)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(16, 16)
    knob.Position = defaultState and UDim2.new(1, -19, 0.5, -8) or UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = THEME.Text
    knob.Parent = btn
    corner(knob, 8)

    local state = defaultState
    local function apply(v)
        if type(v) ~= "boolean" then return end
        state = v
        tween(btn, TweenInfo.new(0.14), { BackgroundColor3 = state and THEME.Accent or THEME.CardAlt })
        tween(knob, TweenInfo.new(0.14), { Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.fromOffset(3, 3) })
        _G.FireEvent(setting, state)
        if onChange then onChange(state) end
    end
    state = bindSetting(setting, defaultState, apply, function(v) return type(v) == "boolean" end)
    apply(state)

    trackConnection(btn.MouseButton1Click:Connect(function()
        apply(not state)
    end))
    return row
end

local function createFreeCamTouchPad()
    local pad = Instance.new("Frame")
    pad.Name = "FreeCamTouchControls"
    pad.Size = UDim2.fromOffset(224, 142)
    pad.Position = UDim2.fromScale(0.36, 0.90)
    pad.BackgroundTransparency = 1
    pad.Visible = false
    pad.ZIndex = 30
    pad.Parent = ScreenGui
    table.insert(mobileLayoutHandles, configureMobileControl(pad, "Free Camera Pad", 0.36, 0.90))

    local function addButton(name, text, x, y, onStart, onStop)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Size = UDim2.fromOffset(42, 38)
        button.Position = UDim2.fromOffset(x, y)
        button.BackgroundColor3 = THEME.Header
        button.BackgroundTransparency = 0.12
        button.Text = text
        button.TextColor3 = THEME.Text
        button.TextSize = 16
        button.Font = FONT_BOLD
        button.AutoButtonColor = false
        button.ZIndex = 31
        button.Parent = pad
        corner(button, 8)
        stroke(button, THEME.Accent, 1)
        trackConnection(button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                onStart()
            end
        end))
        trackConnection(button.InputEnded:Connect(function(input)
            if onStop and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
                onStop()
            end
        end))
    end

    local function movementButton(name, text, x, y, keyName)
        addButton(name, text, x, y,
            function() _G.FireEvent("Free Cam Input", keyName, true) end,
            function() _G.FireEvent("Free Cam Input", keyName, false) end)
    end
    movementButton("FreeCamForward", "▲", 46, 0, "W")
    movementButton("FreeCamLeft", "◀", 0, 42, "A")
    movementButton("FreeCamBack", "▼", 46, 42, "S")
    movementButton("FreeCamRight", "▶", 92, 42, "D")
    movementButton("FreeCamUp", "+", 46, 84, "Space")
    movementButton("FreeCamDown", "−", 92, 84, "LeftShift")

    addButton("FreeCamLookLeft", "⟲", 150, 20,
        function() _G.FireEvent("Free Cam Look", -0.12, 0) end)
    addButton("FreeCamLookRight", "⟳", 150, 62,
        function() _G.FireEvent("Free Cam Look", 0.12, 0) end)
    return pad
end

freeCamTouchPad = createFreeCamTouchPad()

local function createSlider(parent, setting, min, max, default, step, suffix)
    step = step or 1
    suffix = suffix or ""

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 46)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = setting
    titleLbl.Size = UDim2.new(0.6, 0, 0, 16)
    titleLbl.TextSize = 11
    titleLbl.TextColor3 = THEME.Text
    titleLbl.Font = FONT
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
    titleLbl.Parent = row

    local valLbl = Instance.new("TextLabel")
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(default) .. suffix
    valLbl.Size = UDim2.new(0.4, 0, 0, 16)
    valLbl.Position = UDim2.new(0.6, 0, 0, 0)
    valLbl.TextSize = 11
    valLbl.TextColor3 = THEME.AccentBright
    valLbl.Font = FONT_BOLD
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 10)
    track.Position = UDim2.fromOffset(0, 24)
    track.BackgroundColor3 = THEME.CardAlt
    track.Parent = row
    corner(track, 5)
    stroke(track, THEME.BorderDim, 1)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = THEME.Accent
    fill.Parent = track
    corner(fill, 5)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(16, 16)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((default - min) / (max - min), 0, 0.5, 0)
    knob.BackgroundColor3 = THEME.Text
    knob.Parent = track
    corner(knob, 8)
    stroke(knob, THEME.AccentBright, 1)

    local val = default
    local dragging = false

    local function apply(value)
        if type(value) ~= "number" then return end
        val = math.clamp(math.floor(value / step + 0.5) * step, min, max)
        local pct = (val - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        valLbl.Text = tostring(val) .. suffix
        _G.FireEvent(setting, val)
    end
    val = bindSetting(setting, default, apply, function(v) return type(v) == "number" and v >= min and v <= max end)
    apply(val)

    local function update(inputPos)
        local relX = math.clamp((inputPos.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        apply(min + (relX * (max - min)))
    end

    trackConnection(row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            update(input.Position)
        end
    end))

    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            update(input.Position)
        end
    end))

    trackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))

    return row
end

-- createDropdown accepts an optional onChange callback for local UI logic
local function createDropdown(parent, setting, options, default, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 52)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = setting
    titleLbl.Size = UDim2.new(1, 0, 0, 16)
    titleLbl.TextSize = 11
    titleLbl.TextColor3 = THEME.Text
    titleLbl.Font = FONT
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
    titleLbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.Position = UDim2.fromOffset(0, 20)
    btn.BackgroundColor3 = THEME.CardAlt
    btn.Text = "  " .. tostring(default or options[1])
    btn.TextColor3 = THEME.AccentBright
    btn.TextSize = 11
    btn.Font = FONT_BOLD
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.Parent = row
    corner(btn, 6)
    stroke(btn, THEME.BorderDim, 1)

    local arrow = Instance.new("TextLabel")
    arrow.BackgroundTransparency = 1
    arrow.Text = "▼"
    arrow.Size = UDim2.fromOffset(22, 28)
    arrow.Position = UDim2.new(1, -22, 0, 0)
    arrow.TextColor3 = THEME.AccentBright
    arrow.TextSize = 9
    arrow.Parent = btn

    local dropFrame = Instance.new("Frame")
    dropFrame.Size = UDim2.new(1, 0, 0, #options * 30 + 8)
    dropFrame.Position = UDim2.new(0, 0, 1, 4)
    dropFrame.BackgroundColor3 = THEME.Header
    dropFrame.Visible = false
    dropFrame.ZIndex = 80
    dropFrame.Parent = btn
    corner(dropFrame, 8)
    stroke(dropFrame, THEME.Accent, 1)
    padding(dropFrame, 4, 4, 4, 4)

    local dropList = Instance.new("UIListLayout")
    dropList.Padding = UDim.new(0, 3)
    dropList.Parent = dropFrame

    local selected = default or options[1]
    local open = false

    local function toggle()
        open = not open
        dropFrame.Visible = open
        arrow.Text = open and "▲" or "▼"
    end

    trackConnection(btn.MouseButton1Click:Connect(toggle))

    local optionButtons = {}
    local function apply(value)
        if not table.find(options, value) then return end
        selected = value
        btn.Text = "  " .. tostring(selected)
        for _, optionButton in ipairs(optionButtons) do
            optionButton.TextColor3 = optionButton.Text == "  " .. tostring(selected) and THEME.AccentBright or THEME.TextMuted
        end
        if _G.AtomwareConfig then _G.AtomwareConfig:Store(setting, selected) end
        _G.FireEvent(setting, selected)
        if onChange then onChange(selected) end
    end

    for _, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 26)
        optBtn.BackgroundColor3 = THEME.Card
        optBtn.Text = "  " .. tostring(opt)
        optBtn.TextColor3 = (opt == selected) and THEME.AccentBright or THEME.TextMuted
        optBtn.TextSize = 11
        optBtn.Font = FONT
        optBtn.TextXAlignment = Enum.TextXAlignment.Left
        optBtn.ZIndex = 81
        optBtn.Parent = dropFrame
        corner(optBtn, 4)
        table.insert(optionButtons, optBtn)

        trackConnection(optBtn.MouseButton1Click:Connect(function()
            apply(opt)
            toggle()
        end))
    end

    selected = bindSetting(setting, selected, apply, function(v) return table.find(options, v) ~= nil end)
    apply(selected)

    return row
end

local function createColorPicker(parent, setting, defaultColor, onChange)
    defaultColor = defaultColor or Color3.fromRGB(157, 48, 255)

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text = setting
    lbl.Size = UDim2.new(1, -56, 1, 0)
    lbl.TextSize = 11
    lbl.TextColor3 = THEME.Text
    lbl.Font = FONT
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Parent = row

    local preview = Instance.new("TextButton")
    preview.Size = UDim2.fromOffset(44, 22)
    preview.Position = UDim2.new(1, -44, 0.5, -11)
    preview.BackgroundColor3 = defaultColor
    preview.Text = ""
    preview.AutoButtonColor = false
    preview.Parent = row
    corner(preview, 6)
    stroke(preview, THEME.BorderDim, 1)

    local palette = {
        Color3.fromRGB(255, 255, 255), Color3.fromRGB(157, 48, 255),
        Color3.fromRGB(205, 104, 255), Color3.fromRGB(42, 255, 157),
        Color3.fromRGB(255, 75, 125),  Color3.fromRGB(255, 215, 0),
        Color3.fromRGB(0, 150, 255),   Color3.fromRGB(72, 72, 72)
    }

    local popover = Instance.new("Frame")
    popover.Size = UDim2.fromOffset(176, 78)
    popover.Position = UDim2.new(1, -176, 1, 4)
    popover.BackgroundColor3 = THEME.Header
    popover.Visible = false
    popover.ZIndex = 90
    popover.Parent = preview
    corner(popover, 8)
    stroke(popover, THEME.Accent, 1)
    padding(popover, 6, 6, 6, 6)

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.fromOffset(36, 28)
    grid.CellPadding = UDim2.fromOffset(4, 4)
    grid.Parent = popover

    local open = false
    local function apply(value)
        if typeof(value) ~= "Color3" then return end
        preview.BackgroundColor3 = value
        _G.FireEvent(setting, value)
        if onChange then onChange(value) end
    end
    defaultColor = bindSetting(setting, defaultColor, apply, function(v) return typeof(v) == "Color3" end)
    apply(defaultColor)
    trackConnection(preview.MouseButton1Click:Connect(function()
        open = not open
        popover.Visible = open
    end))

    for _, col in ipairs(palette) do
        local pBtn = Instance.new("TextButton")
        pBtn.BackgroundColor3 = col
        pBtn.Text = ""
        pBtn.ZIndex = 91
        pBtn.Parent = popover
        corner(pBtn, 4)
        trackConnection(pBtn.MouseButton1Click:Connect(function()
            open = false
            popover.Visible = false
            apply(col)
        end))
    end

    return row
end

--//==================================================
--// POPULATE ALL TABS & SECTIONS
--//==================================================

local tabsData = {
    { Name = "Visuals",  Icon = "👁️" },
    { Name = "Combat",   Icon = "🎯" },
    { Name = "World",    Icon = "🌍" },
    { Name = "Player",   Icon = "🧍" },
    { Name = "Settings", Icon = "⚙️" }
}

for _, t in ipairs(tabsData) do
    local pName = t.Name
    createPage(pName)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(94, 32)
    btn.BackgroundColor3 = THEME.Card
    btn.Text = t.Icon .. "  " .. pName
    btn.TextColor3 = THEME.TextMuted
    btn.TextSize = 11
    btn.Font = FONT_BOLD
    btn.AutoButtonColor = false
    btn.Parent = TabBar
    corner(btn, 6)
    stroke(btn, THEME.BorderDim, 1)

    TabButtons[pName] = btn
    trackConnection(btn.MouseButton1Click:Connect(function()
        switchPage(pName)
    end))
end

-- Helper to get both columns of a page.
-- Uses the named "ColContainer" child set in createPage() — robust against
-- other Frame children that may exist on the ScrollingFrame.
local function getCols(pageName)
    local page = Pages[pageName]
    local col = page:FindFirstChild("ColContainer")
    if not col then
        -- Fallback: scan for the Frame that owns a horizontal UIListLayout
        for _, c in ipairs(page:GetChildren()) do
            if c:IsA("Frame") then
                local layout = c:FindFirstChildOfClass("UIListLayout")
                if layout and layout.FillDirection == Enum.FillDirection.Horizontal then
                    col = c
                    break
                end
            end
        end
    end
    local left, right
    if col then
        for _, c in ipairs(col:GetChildren()) do
            if c:IsA("Frame") then
                if c.LayoutOrder == 1 then left = c
                elseif c.LayoutOrder == 2 then right = c
                end
            end
        end
    end
    return left, right
end

local function updateResponsiveColumns()
    local camera = workspace.CurrentCamera
    local isNarrow = camera and camera.ViewportSize.X < 640
    for _, entry in ipairs(responsiveLayouts) do
        if isNarrow then
            entry.layout.FillDirection = Enum.FillDirection.Vertical
            entry.left.Size = UDim2.new(1, 0, 0, 0)
            entry.right.Size = UDim2.new(1, 0, 0, 0)
        else
            entry.layout.FillDirection = Enum.FillDirection.Horizontal
            entry.left.Size = UDim2.new(0.5, -4, 0, 0)
            entry.right.Size = UDim2.new(0.5, -4, 0, 0)
        end
    end
end

-- ---------------------------------------------------
-- TAB 1: VISUALS
-- ---------------------------------------------------
local lVisuals, rVisuals = getCols("Visuals")

-- LEFT COLUMN
local _, bPlayerESP = createCard(lVisuals, "Player ESP")
createToggle(bPlayerESP, "Enable ESP", false)
createToggle(bPlayerESP, "Box Esp", false)
createToggle(bPlayerESP, "Distance Esp", false)
createToggle(bPlayerESP, "Player/Bot Esp", false)
createToggle(bPlayerESP, "Sleeper Check", false)
createToggle(bPlayerESP, "Weapon Esp", false)
createToggle(bPlayerESP, "Skeleton Esp", false)

local _, bESPColors = createCard(lVisuals, "ESP Colors")
createColorPicker(bESPColors, "Box Color", Color3.fromRGB(255, 255, 255))
createColorPicker(bESPColors, "Skeleton Color", Color3.fromRGB(255, 255, 255))
createColorPicker(bESPColors, "Text Color", Color3.fromRGB(255, 255, 255))

local _, bOtherESP = createCard(lVisuals, "World Items & Raids")
createToggle(bOtherESP, "Item ESP", false)
createToggle(bOtherESP, "Corpse ESP", false)
createToggle(bOtherESP, "Raid ESP", false)
createToggle(bOtherESP, "Airdrop ESP", false)

-- RIGHT COLUMN
local _, bArmorESP = createCard(rVisuals, "Armor ESP")
createToggle(bArmorESP, "Armor Esp", false)
createSlider(bArmorESP, "Fov Slider", 10, 500, 220, 5, "px")

local _, bMatChams = createCard(rVisuals, "Player Chams")
createToggle(bMatChams, "Enable Material Chams", false)
createDropdown(bMatChams, "Chams Material", { "ForceField", "Neon", "Glass", "Ice", "Marble", "Foil", "Metal", "Wood" }, "ForceField")
createColorPicker(bMatChams, "Chams Color", Color3.fromRGB(120, 200, 255))
createToggle(bMatChams, "Chams See Through", true)
createToggle(bMatChams, "Chams Team Check", false)

local _, bOreESP = createCard(rVisuals, "Ore ESP")
createToggle(bOreESP, "Stone Esp", false)
createToggle(bOreESP, "Iron Esp", false)
createToggle(bOreESP, "Nitrate Esp", false)
createToggle(bOreESP, "Show Distance", false)
createSlider(bOreESP, "Ore Distance Esp", 10, 1000, 750, 10, "m")

local _, bVehicles = createCard(rVisuals, "Vehicle ESP")
createToggle(bVehicles, "ATV", false)
createToggle(bVehicles, "Boat", false)
createToggle(bVehicles, "Helicopter", false)
createToggle(bVehicles, "Trolly", false)
createToggle(bVehicles, "Vehicle Distance Esp", false)

-- ---------------------------------------------------
-- TAB 2: COMBAT
-- ---------------------------------------------------
local lCombat, rCombat = getCols("Combat")

-- RIGHT COLUMN: Big Head
local _, bBigHead = createCard(rCombat, "Big Head Hitbox")
createToggle(bBigHead, "Big Head", false)
createSlider(bBigHead, "Head Size", 1, 10, 2, 1, "x")
createSlider(bBigHead, "Head Transparency", 0, 1, 0, 0.1, "")

local _, bOverrideHB = createCard(rCombat, "Override Hitbox")
createToggle(bOverrideHB, "Override Hitbox", false)
createSlider(bOverrideHB, "OH Size X", 1, 25, 3, 0.5, "st")
createSlider(bOverrideHB, "OH Size Y", 1, 25, 5, 0.5, "st")
createSlider(bOverrideHB, "OH Size Z", 1, 25, 3, 0.5, "st")
createSlider(bOverrideHB, "OH Transparency", 0, 1, 0.5, 0.05, "")
createColorPicker(bOverrideHB, "OH Color", Color3.fromRGB(148, 0, 211))
createDropdown(bOverrideHB, "OH Material", { "Neon", "ForceField", "Plastic", "SmoothPlastic" }, "Neon")

local _, bForceHS = createCard(rCombat, "Force Headshots")
createToggle(bForceHS, "Force Headshots", false)

-- ---------------------------------------------------
-- TAB 3: WORLD
-- ---------------------------------------------------
local lWorld, rWorld = getCols("World")

-- LEFT COLUMN
local _, bWater = createCard(lWorld, "Water")
createColorPicker(bWater, "Water Color", Color3.fromRGB(12, 84, 92))
createToggle(bWater, "Water Reflectance", true)
createSlider(bWater, "Water speed", 1, 100, 10, 1, "")
createSlider(bWater, "Wave size", 0, 1, 0.5, 0.1, "")

local _, bWorldEnv = createCard(lWorld, "Environment")
createToggle(bWorldEnv, "Shadows", true)
createToggle(bWorldEnv, "Grass", true)
createToggle(bWorldEnv, "Tree Leaves", true)
createToggle(bWorldEnv, "Bright Night", false)

-- RIGHT COLUMN
local _, bClouds = createCard(rWorld, "Clouds & Skybox")
createColorPicker(bClouds, "Cloud Color", Color3.fromRGB(255, 255, 255))
createSlider(bClouds, "Clouds Cover", 0, 1, 0.6, 0.1, "")
createDropdown(bClouds, "Sky Changer", { "Default", "Magma", "Water", "Obsidian", "Galaxy", "Void" }, "Default")

local _, bLighting = createCard(rWorld, "Lighting Effects")
createToggle(bLighting, "Stim Effect", false)
createColorPicker(bLighting, "TintColor", Color3.fromRGB(255, 255, 255))
createSlider(bLighting, "Brightness", 0.1, 100, 0.1, 0.5, "")
createSlider(bLighting, "Contrast", 0, 20, 1, 0.1, "")
createSlider(bLighting, "Saturation", 0, 100, 10, 1, "")

-- ---------------------------------------------------
-- TAB 4: PLAYER
-- ---------------------------------------------------
local lPlayer, rPlayer = getCols("Player")

-- LEFT COLUMN
local _, bCam = createCard(lPlayer, "Camera & Visual")
createSlider(bCam, "FOV Changer", 50, 120, 70, 1, "°")
createToggle(bCam, "Zoom Active", false)
createToggle(bCam, "X-Ray Active", false)

local _, bTrails = createCard(lPlayer, "Bullet & Arrow Trails")
createToggle(bTrails, "Bullet Trail", false)
createColorPicker(bTrails, "Bullet Trail Color", Color3.fromRGB(255, 255, 255))
createSlider(bTrails, "Trail Thickness", 0.1, 1, 0.2, 0.1, "")
createSlider(bTrails, "Bullet Trail Length", 1, 25, 10, 1, "")
createSlider(bTrails, "Trail LifeTime", 0.01, 5, 0.1, 0.05, "s")     -- M2: was missing
createColorPicker(bTrails, "Arrow Trailcolor", Color3.fromRGB(255, 255, 255)) -- M3: was missing
createSlider(bTrails, "Arrow Trail lifespan", 0.15, 20, 0.15, 0.1, "s")      -- M3: was missing

-- RIGHT COLUMN
local _, bHitSounds = createCard(rPlayer, "Hit Sounds")
createDropdown(bHitSounds, "Hit sound", { "Default", "Rust", "Gamesense", "Magic", "Firework", "Lazer", "Pop", "Zap" }, "Default")
createSlider(bHitSounds, "Hit sound Volume", 0.1, 5, 1, 0.1, "")

local _, bChams = createCard(rPlayer, "Hand & Weapon Chams")
createDropdown(bChams, "Hand Cham Material", { "Default", "ForceField", "Neon", "Asphalt" }, "Default")
createColorPicker(bChams, "Hand cham color", Color3.fromRGB(255, 255, 255))
createDropdown(bChams, "Weapon Cham Material", { "Default", "ForceField", "Neon", "Asphalt" }, "Default")
createColorPicker(bChams, "Weapon Cham Color", Color3.fromRGB(255, 255, 255))

-- M5: FreeCam controls — missing from mobile but present in desktop + features.lua
local _, bFreeCam = createCard(rPlayer, "Free Camera")
createToggle(bFreeCam, "Free Cam Toggle", false, function(enabled)
    freeCamEnabled = enabled
    freeCamTouchPad.Visible = enabled or mobileLayoutEditing
end)
createSlider(bFreeCam, "FreeCam Speed", 1, 500, 150, 5, "")

local _, bHitmarker = createCard(rPlayer, "Hitmarker")
createToggle(bHitmarker, "Hitmarker Enabled", false)
createColorPicker(bHitmarker, "Hitmarker Color", Color3.fromRGB(255, 255, 255))
createSlider(bHitmarker, "Hitmarker Size", 5, 50, 20, 1, "px")
createSlider(bHitmarker, "Hitmarker Thickness", 1, 5, 2, 0.5, "")
createSlider(bHitmarker, "Hitmarker Duration", 0.1, 1, 0.3, 0.05, "s")

local _, bHitSoundNew = createCard(rPlayer, "Hit Sound")
createToggle(bHitSoundNew, "Hit Sound Enabled", false)
createDropdown(bHitSoundNew, "Hit Sound Type", {
    "rbxassetid://4764109000",
    "rbxassetid://9119561046",
    "rbxassetid://5043539486",
    "rbxassetid://4817809188",
    "rbxassetid://182765513",
    "rbxassetid://269146157",
    "rbxassetid://360661189",
}, "rbxassetid://4764109000")
createSlider(bHitSoundNew, "Hit Sound Volume", 0.1, 5, 1, 0.1, "")
createSlider(bHitSoundNew, "Hit Sound Pitch", 0.1, 5, 1, 0.1, "")

local _, bLongNeck = createCard(rPlayer, "Long Neck")
createToggle(bLongNeck, "Long Neck", false)
createSlider(bLongNeck, "Long Neck Strength", 1, 20, 5, 0.5, "st")

-- ---------------------------------------------------
-- TAB 5: SETTINGS
-- ---------------------------------------------------
local lSettings, rSettings = getCols("Settings")

-- LEFT COLUMN
local _, bMobileSet = createCard(lSettings, "Mobile Controls")
createToggle(bMobileSet, "Edit Mobile Layout", false, setMobileLayoutEditing)
_G.OnSlider("Mobile Control Scale", setMobileControlScale)
createSlider(bMobileSet, "Mobile Control Scale", 0.7, 1.5, 1, 0.1, "x")
local resetLayoutButton = Instance.new("TextButton")
resetLayoutButton.Size = UDim2.new(1, 0, 0, 30)
resetLayoutButton.BackgroundColor3 = THEME.CardAlt
resetLayoutButton.Text = "Reset Control Positions"
resetLayoutButton.TextColor3 = THEME.AccentBright
resetLayoutButton.TextSize = 11
resetLayoutButton.Font = FONT_BOLD
resetLayoutButton.AutoButtonColor = false
resetLayoutButton.Parent = bMobileSet
corner(resetLayoutButton, 6)
trackConnection(resetLayoutButton.MouseButton1Click:Connect(resetMobileLayout))
local infoLbl = Instance.new("TextLabel")
infoLbl.BackgroundTransparency = 1
infoLbl.Text = "• Turn on Edit Mobile Layout, then drag the DRAG handles\n• Control positions and scale save with profiles\n• Reset Control Positions restores the defaults"
infoLbl.Size = UDim2.new(1, 0, 0, 72)
infoLbl.TextSize = 11
infoLbl.TextColor3 = THEME.TextMuted
infoLbl.Font = FONT
infoLbl.TextXAlignment = Enum.TextXAlignment.Left
infoLbl.TextWrapped = true
infoLbl.Parent = bMobileSet

-- RIGHT COLUMN
local _, bClose = createCard(rSettings, "Manage UI")
createToggle(bClose, "Show Keybind List", false, function(v)
    if _G.AtomwareConfig then _G.AtomwareConfig:SetKeybindListVisible(v) end
end)
createToggle(bClose, "Show Watermark", false, function(v)
    if _G.AtomwareConfig then _G.AtomwareConfig:SetWatermarkVisible(v) end
end)
createToggle(bClose, "Show FPS Counter", false, function(v)
    if _G.AtomwareConfig then _G.AtomwareConfig:SetFPSCounterVisible(v) end
end)
createToggle(bClose, "Raid Alerts", false)
createToggle(bClose, "Airdrop Alerts", false)
createSlider(bClose, "Alert Duration", 1, 10, 3, 1, "s")
createColorPicker(bClose, "Watermark Color", Color3.fromRGB(205, 104, 255), function(v)
    if _G.AtomwareConfig then _G.AtomwareConfig:SetWatermarkColor(v) end
end)
createDropdown(bClose, "Notification Corner", { "TopRight", "TopLeft", "BottomRight", "BottomLeft" }, "TopRight", function(v)
    if _G.AtomwareConfig then _G.AtomwareConfig:SetNotificationCorner(v) end
end)
createToggle(bClose, "Use Custom Cursor", false, function(v)
    if _G.AtomwareConfig then _G.AtomwareConfig:SetCustomCursorVisible(v) end
end)

local destBtn = Instance.new("TextButton")
destBtn.Size = UDim2.new(1, 0, 0, 36)
destBtn.BackgroundColor3 = Color3.fromRGB(70, 20, 35)
destBtn.Text = "Unload Atomware"
destBtn.TextColor3 = THEME.Red
destBtn.TextSize = 12
destBtn.Font = FONT_BOLD
destBtn.Parent = bClose
corner(destBtn, 6)
trackConnection(destBtn.MouseButton1Click:Connect(function()
    if _G.AtomwareUnload then _G.AtomwareUnload() else ScreenGui:Destroy() end
end))

local _, bProfiles = createCard(rSettings, "Profiles")
local profileName = Instance.new("TextBox")
profileName.Size = UDim2.new(1, 0, 0, 34)
profileName.BackgroundColor3 = THEME.CardAlt
profileName.TextColor3 = THEME.Text
profileName.PlaceholderColor3 = THEME.TextDim
profileName.PlaceholderText = "Profile name"
profileName.Text = (_G.AtomwareConfig and _G.AtomwareConfig.Profile) or "Default"
profileName.ClearTextOnFocus = false
profileName.TextSize = 12
profileName.Font = FONT
profileName.Parent = bProfiles
corner(profileName, 6)

local function makeProfileButton(text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 34)
    button.BackgroundColor3 = THEME.CardAlt
    button.Text = text
    button.TextColor3 = THEME.AccentBright
    button.TextSize = 12
    button.Font = FONT_BOLD
    button.AutoButtonColor = false
    button.Parent = bProfiles
    corner(button, 6)
    trackConnection(button.MouseButton1Click:Connect(callback))
end

makeProfileButton("Save Profile", function()
    local ok, message = _G.AtomwareConfig:Save(profileName.Text)
    _G.AtomwareConfig:Notify(ok and "Profile saved." or (message or "Profile save failed."))
end)
makeProfileButton("Load Profile", function()
    local ok, message = _G.AtomwareConfig:Load(profileName.Text)
    _G.AtomwareConfig:Notify(ok and "Profile loaded." or (message or "Profile load failed."))
end)
makeProfileButton("Use at Startup", function()
    local ok, message = _G.AtomwareConfig:SetAutoload(profileName.Text)
    _G.AtomwareConfig:Notify(ok and "Startup profile set." or (message or "Could not set startup profile."))
end)

switchPage("Visuals")

updateResponsiveColumns()
local viewportConnection
local function observeCurrentCamera()
    if viewportConnection then viewportConnection:Disconnect() end
    local camera = workspace.CurrentCamera
    if camera then
        viewportConnection = trackConnection(camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveColumns))
    end
    updateResponsiveColumns()
end
observeCurrentCamera()
trackConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(observeCurrentCamera))

trackConnection(UserInputService.InputBegan:Connect(function(input, gpe)
    if input.UserInputType ~= Enum.UserInputType.Gamepad1 then return end
    if input.KeyCode == Enum.KeyCode.ButtonL1 then
        setUIVisible(not UIVisible)
    end
end))

_G.AtomwareUILoaded = true
print("Good to go")
