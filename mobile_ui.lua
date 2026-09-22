--[[
    mobile_ui.lua
    Ultra-Polished Mobile UI for Atomware (Trident Survival)
    Two-column compact layout, dynamic aim toggle, controller bind selector
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

--//==================================================
--// GLOBAL EVENT BINDING SYSTEM
--//==================================================

_G.AtomwareEvents = _G.AtomwareEvents or {}

_G.OnToggle = function(name, callback)
    _G.AtomwareEvents[name] = callback
end

_G.OnSlider = function(name, callback)
    _G.AtomwareEvents[name] = callback
end

_G.OnDropdown = function(name, callback)
    _G.AtomwareEvents[name] = callback
end

_G.OnColorPicker = function(name, callback)
    _G.AtomwareEvents[name] = callback
end

_G.OnKeybind = function(name, callback)
    _G.AtomwareEvents[name] = callback
end

_G.FireEvent = function(name, ...)
    if _G.AtomwareEvents[name] then
        task.spawn(_G.AtomwareEvents[name], ...)
    end
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

pcall(function()
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end)

--//==================================================
--// FLOATING ACTION BUTTONS (MOBILE DRAGGABLE)
--//==================================================

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

    local isDragging = false
    local dragStart, startPos

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStart = input.Position
            startPos = btn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            btn.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    btn.MouseButton1Click:Connect(function()
        if onClick then onClick(btn) end
    end)

    return btn
end

-- Floating Menu Toggle only (the aim toggle is created dynamically per mode)
local MobileToggleBtn

--//==================================================
--// HOLD TOGGLE AIM BUTTON (Dynamic — only for "Hold Toggle" mode)
--//==================================================

local mobileAimActive = false
local holdToggleBtn = nil

local function createHoldToggleBtn()
    if holdToggleBtn then
        holdToggleBtn:Destroy()
        holdToggleBtn = nil
    end
    holdToggleBtn = makeFloatingButton("HoldToggleAim", "🎯", THEME.Green, UDim2.new(1, -66, 1, -195), function()
        mobileAimActive = not mobileAimActive
        _G.FireEvent("MobileAimTrigger", mobileAimActive)
        holdToggleBtn.TextColor3 = mobileAimActive and THEME.Red or THEME.Green
        holdToggleBtn.Text = mobileAimActive and "🔒" or "🎯"
    end)
end

local function destroyHoldToggleBtn()
    if holdToggleBtn then
        holdToggleBtn:Destroy()
        holdToggleBtn = nil
        mobileAimActive = false
        _G.FireEvent("MobileAimTrigger", false)
    end
end

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
CloseBtn.MouseButton1Click:Connect(function() setUIVisible(false) end)

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

local function createToggle(parent, setting, defaultState)
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
    local function fire(v)
        if _G.AtomwareEvents and _G.AtomwareEvents[setting] then
            task.spawn(_G.AtomwareEvents[setting], v)
        end
    end

    btn.MouseButton1Click:Connect(function()
        state = not state
        tween(btn, TweenInfo.new(0.14), { BackgroundColor3 = state and THEME.Accent or THEME.CardAlt })
        tween(knob, TweenInfo.new(0.14), { Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.fromOffset(3, 3) })
        fire(state)
    end)

    if defaultState then task.defer(function() fire(true) end) end
    return row
end

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

    local function update(inputPos)
        local relX = math.clamp((inputPos.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local raw = min + (relX * (max - min))
        val = math.floor(raw / step + 0.5) * step
        val = math.clamp(val, min, max)

        local pct = (val - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        valLbl.Text = tostring(val) .. suffix

        if _G.AtomwareEvents and _G.AtomwareEvents[setting] then
            task.spawn(_G.AtomwareEvents[setting], val)
        end
    end

    row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            update(input.Position)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            update(input.Position)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    task.defer(function()
        if _G.AtomwareEvents and _G.AtomwareEvents[setting] then
            task.spawn(_G.AtomwareEvents[setting], val)
        end
    end)

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

    btn.MouseButton1Click:Connect(toggle)

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

        optBtn.MouseButton1Click:Connect(function()
            selected = opt
            btn.Text = "  " .. tostring(opt)
            toggle()
            for _, c in ipairs(dropFrame:GetChildren()) do
                if c:IsA("TextButton") then
                    c.TextColor3 = (c.Text == "  " .. tostring(selected)) and THEME.AccentBright or THEME.TextMuted
                end
            end
            if _G.AtomwareEvents and _G.AtomwareEvents[setting] then
                task.spawn(_G.AtomwareEvents[setting], selected)
            end
            if onChange then onChange(selected) end
        end)
    end

    task.defer(function()
        if _G.AtomwareEvents and _G.AtomwareEvents[setting] then
            task.spawn(_G.AtomwareEvents[setting], selected)
        end
        if onChange then onChange(selected) end
    end)

    return row
end

local function createColorPicker(parent, setting, defaultColor)
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
    preview.MouseButton1Click:Connect(function()
        open = not open
        popover.Visible = open
    end)

    for _, col in ipairs(palette) do
        local pBtn = Instance.new("TextButton")
        pBtn.BackgroundColor3 = col
        pBtn.Text = ""
        pBtn.ZIndex = 91
        pBtn.Parent = popover
        corner(pBtn, 4)
        pBtn.MouseButton1Click:Connect(function()
            preview.BackgroundColor3 = col
            open = false
            popover.Visible = false
            if _G.AtomwareEvents and _G.AtomwareEvents[setting] then
                task.spawn(_G.AtomwareEvents[setting], col)
            end
        end)
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
    btn.MouseButton1Click:Connect(function()
        switchPage(pName)
    end)
end

-- Helper to get both columns of a page
local function getCols(pageName)
    local page = Pages[pageName]
    -- colContainer is the first child that has UIListLayout (Horizontal)
    local col = page:FindFirstChild("Frame") -- colContainer
    if not col then
        -- fallback: iterate children
        for _, c in ipairs(page:GetChildren()) do
            if c:IsA("Frame") then col = c break end
        end
    end
    local left, right
    for _, c in ipairs(col:GetChildren()) do
        if c:IsA("Frame") then
            if c.LayoutOrder == 1 then left = c
            elseif c.LayoutOrder == 2 then right = c
            end
        end
    end
    return left, right
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

-- LEFT COLUMN: Aimbot
local _, bAimbot = createCard(lCombat, "Aimbot & Aimlock")
createToggle(bAimbot, "Aimbot Enabled", false)

-- Controller bind selector row (hidden unless "Controller Bind" mode is active)
local ctrlBindRow = createDropdown(bAimbot, "Controller Bind",
    { "ButtonRT", "ButtonLT", "ButtonR2", "ButtonL2", "ButtonRB", "ButtonLB" }, "ButtonRT",
    function(bind)
        -- Fire "Aim Key" event so features.lua updates AimbotConfig.AimKey
        _G.FireEvent("Aim Key", bind)
    end
)
ctrlBindRow.Visible = false

-- Aimbot Mode dropdown — onChange updates UI (ctrl bind row + hold toggle button)
createDropdown(bAimbot, "Aimbot Mode",
    { "Always On", "Hold Toggle", "Controller Bind" },
    "Always On",
    function(mode)
        -- Show/hide controller bind row
        ctrlBindRow.Visible = (mode == "Controller Bind")

        -- Show/destroy dynamic hold-toggle floating button
        if mode == "Hold Toggle" then
            createHoldToggleBtn()
        else
            destroyHoldToggleBtn()
        end
    end
)

createToggle(bAimbot, "Show FOV Circle", true)
createSlider(bAimbot, "Aimbot FOV", 10, 500, 140, 5, "px")
createSlider(bAimbot, "Aimbot Smoothing", 0.01, 1, 0.20, 0.01, "")
createDropdown(bAimbot, "Aim Hit Part", { "Head", "UpperTorso", "HumanoidRootPart" }, "Head")
createToggle(bAimbot, "Aimbot Team Check", true)

-- RIGHT COLUMN: Big Head
local _, bBigHead = createCard(rCombat, "Big Head Hitbox")
createToggle(bBigHead, "Big Head", false)
createSlider(bBigHead, "Head Size", 1, 10, 2, 1, "x")
createSlider(bBigHead, "Head Transparency", 0, 1, 0, 0.1, "")

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
createToggle(bCam, "X-Ray Active", false)

local _, bTrails = createCard(lPlayer, "Bullet & Arrow Trails")
createToggle(bTrails, "Bullet Trail", false)
createColorPicker(bTrails, "Bullet Trail Color", Color3.fromRGB(255, 255, 255))
createSlider(bTrails, "Trail Thickness", 0.1, 1, 0.2, 0.1, "")
createSlider(bTrails, "Bullet Trail Length", 1, 25, 10, 1, "")

-- RIGHT COLUMN
local _, bHitSounds = createCard(rPlayer, "Hit Sounds")
createDropdown(bHitSounds, "Hit sound", { "Default", "Rust", "Gamesense", "Magic", "Firework", "Lazer", "Pop", "Zap" }, "Default")
createSlider(bHitSounds, "Hit sound Volume", 0.1, 5, 1, 0.1, "")

local _, bChams = createCard(rPlayer, "Hand & Weapon Chams")
createDropdown(bChams, "Hand Cham Material", { "Default", "ForceField", "Neon", "Asphalt" }, "Default")
createColorPicker(bChams, "Hand cham color", Color3.fromRGB(255, 255, 255))
createDropdown(bChams, "Weapon Cham Material", { "Default", "ForceField", "Neon", "Asphalt" }, "Default")
createColorPicker(bChams, "Weapon Cham Color", Color3.fromRGB(255, 255, 255))

-- ---------------------------------------------------
-- TAB 5: SETTINGS
-- ---------------------------------------------------
local lSettings, rSettings = getCols("Settings")

-- LEFT COLUMN
local _, bMobileSet = createCard(lSettings, "Mobile Controls")
local infoLbl = Instance.new("TextLabel")
infoLbl.BackgroundTransparency = 1
infoLbl.Text = "• Tap 'A' to Toggle UI\n• Hold Toggle mode shows aim button on screen\n• Drag floating buttons to reposition"
infoLbl.Size = UDim2.new(1, 0, 0, 56)
infoLbl.TextSize = 11
infoLbl.TextColor3 = THEME.TextMuted
infoLbl.Font = FONT
infoLbl.TextXAlignment = Enum.TextXAlignment.Left
infoLbl.TextWrapped = true
infoLbl.Parent = bMobileSet

-- RIGHT COLUMN
local _, bClose = createCard(rSettings, "Manage UI")
local destBtn = Instance.new("TextButton")
destBtn.Size = UDim2.new(1, 0, 0, 36)
destBtn.BackgroundColor3 = Color3.fromRGB(70, 20, 35)
destBtn.Text = "Close Atomware UI"
destBtn.TextColor3 = THEME.Red
destBtn.TextSize = 12
destBtn.Font = FONT_BOLD
destBtn.Parent = bClose
corner(destBtn, 6)
destBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

switchPage("Visuals")

_G.AtomwareUILoaded = true
print("Good to go")
