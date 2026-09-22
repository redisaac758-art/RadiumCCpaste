--[[
    Atomware UI (main_ui.lua)
    Full Responsive UI Framework with Xbox Controller, Mobile Support & Dynamic Feature Binding System
    Target Game: Trident Survival
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

--//==================================================
--// GLOBAL EVENT & BINDING SYSTEM
--//==================================================

_G.AtomwareEvents = _G.AtomwareEvents or {}

_G.OnToggle = function(settingName, callback)
    _G.AtomwareEvents[settingName] = callback
end

_G.OnSlider = function(settingName, callback)
    _G.AtomwareEvents[settingName] = callback
end

_G.OnDropdown = function(settingName, callback)
    _G.AtomwareEvents[settingName] = callback
end

_G.OnColorPicker = function(settingName, callback)
    _G.AtomwareEvents[settingName] = callback
end

_G.OnKeybind = function(settingName, callback)
    _G.AtomwareEvents[settingName] = callback
end

_G.FireEvent = function(settingName, ...)
    if _G.AtomwareEvents[settingName] then
        task.spawn(_G.AtomwareEvents[settingName], ...)
    end
end

--//==================================================
--// DEVICE DETECTION & THEME
--//==================================================

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local THEME = {
    Background      = Color3.fromRGB(5, 4, 10),
    Window          = Color3.fromRGB(8, 6, 15),
    Header          = Color3.fromRGB(10, 7, 19),
    Card            = Color3.fromRGB(13, 9, 24),
    CardAlt         = Color3.fromRGB(17, 11, 31),
    CardHover       = Color3.fromRGB(22, 13, 39),

    Border          = Color3.fromRGB(83, 35, 150),
    BorderDim       = Color3.fromRGB(42, 23, 75),
    Accent          = Color3.fromRGB(157, 48, 255),
    AccentBright    = Color3.fromRGB(205, 104, 255),
    AccentDark      = Color3.fromRGB(66, 22, 116),
    AccentGlow      = Color3.fromRGB(184, 73, 255),

    Text            = Color3.fromRGB(245, 241, 255),
    TextMuted       = Color3.fromRGB(143, 130, 169),
    TextDim         = Color3.fromRGB(91, 79, 116),

    Green           = Color3.fromRGB(42, 255, 157),
    Red             = Color3.fromRGB(255, 75, 125),
}

local FONT = Enum.Font.Gotham

--//==================================================
--// HELPERS
--//==================================================

local function tween(instance, info, props)
    local t = TweenService:Create(instance, info, props)
    t:Play()
    return t
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.Border
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function padding(parent, left, right, top, bottom)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, left or 0)
    p.PaddingRight = UDim.new(0, right or 0)
    p.PaddingTop = UDim.new(0, top or 0)
    p.PaddingBottom = UDim.new(0, bottom or 0)
    p.Parent = parent
    return p
end

local function label(parent, text, size, position, textSize, color, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.Size = size
    l.Position = position or UDim2.fromOffset(0, 0)
    l.TextSize = textSize or 12
    l.TextColor3 = color or THEME.Text
    l.Font = font or FONT
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Center
    l.Parent = parent
    return l
end

local function makeButton(parent, text, size, position)
    local b = Instance.new("TextButton")
    b.AutoButtonColor = false
    b.Text = text
    b.Size = size
    b.Position = position or UDim2.fromOffset(0, 0)
    b.BackgroundColor3 = THEME.Card
    b.TextColor3 = THEME.Text
    b.TextSize = 11
    b.Font = FONT
    b.Parent = parent
    corner(b, 6)
    stroke(b, THEME.BorderDim, 1)
    return b
end

local function addHover(button, normal, hover)
    button.MouseEnter:Connect(function()
        tween(button, TweenInfo.new(0.12), {
            BackgroundColor3 = hover or THEME.CardHover
        })
    end)

    button.MouseLeave:Connect(function()
        tween(button, TweenInfo.new(0.12), {
            BackgroundColor3 = normal or THEME.Card
        })
    end)
end

--//==================================================
--// GUI ROOT & MOBILE TOGGLE
--//==================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AtomwareUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 100

pcall(function()
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end)

local MobileToggle = Instance.new("TextButton")
MobileToggle.Name = "MobileToggle"
MobileToggle.AnchorPoint = Vector2.new(1, 1)
MobileToggle.Position = UDim2.new(1, -16, 1, -16)
MobileToggle.Size = UDim2.fromOffset(54, 54)
MobileToggle.BackgroundColor3 = THEME.Window
MobileToggle.Text = "A"
MobileToggle.TextColor3 = THEME.AccentBright
MobileToggle.TextSize = 22
MobileToggle.Font = Enum.Font.GothamBold
MobileToggle.AutoButtonColor = false
MobileToggle.Visible = IS_MOBILE
MobileToggle.Parent = ScreenGui
corner(MobileToggle, 16)
stroke(MobileToggle, THEME.Accent, 1.5)

local mobileGlow = Instance.new("UIStroke")
mobileGlow.Color = THEME.Accent
mobileGlow.Thickness = 5
mobileGlow.Transparency = 0.72
mobileGlow.Parent = MobileToggle

--//==================================================
--// MAIN WINDOW & LAYOUT
--//==================================================

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.fromScale(0.5, 0.5)
MainFrame.Size = UDim2.fromOffset(900, 570)
MainFrame.BackgroundColor3 = THEME.Window
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
corner(MainFrame, 10)

stroke(MainFrame, THEME.Border, 1.5)

local OuterGlow = Instance.new("UIStroke")
OuterGlow.Color = THEME.Accent
OuterGlow.Thickness = 8
OuterGlow.Transparency = 0.86
OuterGlow.Parent = MainFrame

local Header, DesktopSidebar, TopTabs, ContentArea, MobileTabBar
local desktopMode = true
local Pages = {}
local InteractiveElements = {}

local function getViewport()
    local camera = workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1920, 1080)
end

local function updateResponsiveLayout()
    local viewport = getViewport()
    local mobile = viewport.X < 720 or IS_MOBILE
    desktopMode = not mobile

    if mobile then
        MainFrame.Size = UDim2.new(0.96, 0, 0.90, 0)
        if DesktopSidebar then DesktopSidebar.Visible = false end
        if TopTabs then TopTabs.Visible = false end
        if MobileTabBar then MobileTabBar.Visible = true end
        if ContentArea then
            ContentArea.Position = UDim2.new(0, 8, 0, 108)
            ContentArea.Size = UDim2.new(1, -16, 1, -116)
        end
        for _, page in pairs(Pages) do
            local grid = page:FindFirstChildOfClass("UIGridLayout")
            if grid then
                grid.CellSize = UDim2.new(1, -8, 0, 240)
                grid.CellPadding = UDim2.fromOffset(8, 8)
            end
        end
        if Header then Header.Size = UDim2.new(1, 0, 0, 52) end
    else
        MainFrame.Size = UDim2.fromOffset(900, 570)
        if DesktopSidebar then DesktopSidebar.Visible = true end
        if TopTabs then TopTabs.Visible = true end
        if MobileTabBar then MobileTabBar.Visible = false end
        if ContentArea then
            ContentArea.Position = UDim2.fromOffset(200, 55)
            ContentArea.Size = UDim2.new(1, -210, 1, -65)
        end
        if Header then Header.Size = UDim2.new(1, 0, 0, 48) end
    end
end

-- Window Dragging
local dragging, dragStart, startPosition
local function beginDrag(input)
    dragging = true
    dragStart = input.Position
    startPosition = MainFrame.Position
    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then dragging = false end
    end)
end

local function updateDrag(input)
    if not dragging then return end
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(
        startPosition.X.Scale, startPosition.X.Offset + delta.X,
        startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
    )
end

--//==================================================
--// HEADER
--//==================================================

Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 48)
Header.BackgroundColor3 = THEME.Header
Header.BorderSizePixel = 0
Header.Parent = MainFrame
stroke(Header, THEME.BorderDim, 1)

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        beginDrag(input)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        updateDrag(input)
    end
end)

local HeaderAccent = Instance.new("Frame")
HeaderAccent.Size = UDim2.fromOffset(3, 32)
HeaderAccent.Position = UDim2.fromOffset(8, 8)
HeaderAccent.BackgroundColor3 = THEME.Accent
HeaderAccent.BorderSizePixel = 0
HeaderAccent.Parent = Header
corner(HeaderAccent, 2)

label(Header, "atomware", UDim2.fromOffset(180, 48), UDim2.fromOffset(20, 0), 20, THEME.Text, Enum.Font.GothamBold)

local Minimize = makeButton(Header, "—", UDim2.fromOffset(30, 28), UDim2.new(1, -70, 0, 10))
local Close = makeButton(Header, "×", UDim2.fromOffset(30, 28), UDim2.new(1, -36, 0, 10))

addHover(Minimize, THEME.Card, THEME.CardHover)
addHover(Close, THEME.Card, Color3.fromRGB(55, 18, 38))

local UIVisible = true
local function setUIVisible(state)
    UIVisible = state
    if state then
        MainFrame.Visible = true
        tween(MainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = desktopMode and UDim2.fromOffset(900, 570) or UDim2.new(0.96, 0, 0.90, 0)
        })
    else
        tween(MainFrame, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.fromOffset(0, 0)
        }).Completed:Once(function()
            if not UIVisible then MainFrame.Visible = false end
        end)
    end
end

Close.MouseButton1Click:Connect(function() setUIVisible(false) end)
Minimize.MouseButton1Click:Connect(function() setUIVisible(false) end)
MobileToggle.MouseButton1Click:Connect(function() setUIVisible(not UIVisible) end)

TopTabs = Instance.new("Frame")
TopTabs.Name = "TopTabs"
TopTabs.BackgroundTransparency = 1
TopTabs.Size = UDim2.new(0, 500, 1, 0)
TopTabs.Position = UDim2.fromOffset(190, 0)
TopTabs.Parent = Header

local TopTabLayout = Instance.new("UIListLayout")
TopTabLayout.FillDirection = Enum.FillDirection.Horizontal
TopTabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TopTabLayout.Padding = UDim.new(0, 5)
TopTabLayout.Parent = TopTabs

--//==================================================
--// PAGE & CONTAINER SETUP
--//==================================================

MobileTabBar = Instance.new("ScrollingFrame")
MobileTabBar.Name = "MobileTabBar"
MobileTabBar.BackgroundColor3 = THEME.Header
MobileTabBar.BorderSizePixel = 0
MobileTabBar.Position = UDim2.fromOffset(0, 52)
MobileTabBar.Size = UDim2.new(1, 0, 0, 48)
MobileTabBar.ScrollBarThickness = 0
MobileTabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
MobileTabBar.Parent = MainFrame

local MobileTabLayout = Instance.new("UIListLayout")
MobileTabLayout.FillDirection = Enum.FillDirection.Horizontal
MobileTabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
MobileTabLayout.Padding = UDim.new(0, 6)
MobileTabLayout.Parent = MobileTabBar
padding(MobileTabBar, 8, 8, 6, 6)

DesktopSidebar = Instance.new("Frame")
DesktopSidebar.Name = "Sidebar"
DesktopSidebar.BackgroundColor3 = THEME.Header
DesktopSidebar.Size = UDim2.new(0, 180, 1, -65)
DesktopSidebar.Position = UDim2.fromOffset(10, 55)
DesktopSidebar.Parent = MainFrame
corner(DesktopSidebar, 8)
stroke(DesktopSidebar, THEME.BorderDim, 1)

local SidebarList = Instance.new("UIListLayout")
SidebarList.Padding = UDim.new(0, 6)
SidebarList.Parent = DesktopSidebar
padding(DesktopSidebar, 8, 8, 10, 10)

ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.BackgroundTransparency = 1
ContentArea.Position = UDim2.fromOffset(200, 55)
ContentArea.Size = UDim2.new(1, -210, 1, -65)
ContentArea.Parent = MainFrame

local PageButtons = {}
local CurrentPageName = "Visuals"

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Size = UDim2.new(1, 0, 1, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = THEME.Accent
    page.Visible = false
    page.Parent = ContentArea
    padding(page, 4, 8, 4, 10)

    local grid = Instance.new("UIGridLayout")
    grid.CellPadding = UDim2.fromOffset(10, 10)
    grid.CellSize = UDim2.new(0.5, -5, 0, 240)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = page

    Pages[name] = page
    return page
end

local function switchPage(name)
    CurrentPageName = name
    for pageName, page in pairs(Pages) do
        page.Visible = pageName == name
    end
    for pageName, button in pairs(PageButtons) do
        local active = pageName == name or pageName == "Mobile" .. name or pageName == "Sidebar" .. name
        tween(button, TweenInfo.new(0.16), {
            BackgroundColor3 = active and THEME.AccentDark or THEME.Card,
            TextColor3 = active and THEME.AccentBright or THEME.Text
        })
    end
end

--//==================================================
--// WIDGET BUILDERS
--//==================================================

local function createSection(parent, title, height)
    local section = Instance.new("Frame")
    section.BackgroundColor3 = THEME.Card
    section.Size = UDim2.new(1, 0, 0, height or 220)
    section.Parent = parent
    corner(section, 7)
    stroke(section, THEME.BorderDim, 1)

    local accent = Instance.new("Frame")
    accent.Size = UDim2.fromOffset(3, 18)
    accent.Position = UDim2.fromOffset(9, 10)
    accent.BackgroundColor3 = THEME.Accent
    accent.BorderSizePixel = 0
    accent.Parent = section
    corner(accent, 2)

    label(section, title, UDim2.new(1, -30, 0, 32), UDim2.fromOffset(20, 3), 11, THEME.Text, Enum.Font.GothamBold)

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, -24, 0, 1)
    divider.Position = UDim2.fromOffset(12, 38)
    divider.BackgroundColor3 = THEME.BorderDim
    divider.BorderSizePixel = 0
    divider.Parent = section

    local body = Instance.new("ScrollingFrame")
    body.Name = "Body"
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    body.Position = UDim2.fromOffset(12, 44)
    body.Size = UDim2.new(1, -24, 1, -50)
    body.AutomaticCanvasSize = Enum.AutomaticSize.Y
    body.ScrollBarThickness = 2
    body.ScrollBarImageColor3 = THEME.Border
    body.Parent = section
    padding(body, 0, 4, 2, 6)

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 6)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = body

    return section, body
end

local function createToggle(parent, setting, defaultState)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.Parent = parent

    label(row, setting, UDim2.new(1, -52, 1, 0), UDim2.fromOffset(0, 0), 11, THEME.TextMuted, FONT)

    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(40, 20)
    button.Position = UDim2.new(1, -40, 0.5, -10)
    button.BackgroundColor3 = defaultState and THEME.Accent or THEME.CardAlt
    button.Text = ""
    button.AutoButtonColor = false
    button.Parent = row
    corner(button, 10)
    stroke(button, defaultState and THEME.AccentBright or THEME.BorderDim, 1)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.Position = defaultState and UDim2.new(1, -17, 0.5, -7) or UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = THEME.Text
    knob.Parent = button
    corner(knob, 7)

    local glow = Instance.new("UIStroke")
    glow.Color = THEME.AccentBright
    glow.Thickness = 3
    glow.Transparency = defaultState and 0.65 or 1
    glow.Parent = button

    local state = defaultState

    local function fireCallback(newState)
        if _G.AtomwareEvents and _G.AtomwareEvents[setting] then
            task.spawn(_G.AtomwareEvents[setting], newState)
        end
    end

    button.MouseButton1Click:Connect(function()
        state = not state
        tween(button, TweenInfo.new(0.14), { BackgroundColor3 = state and THEME.Accent or THEME.CardAlt })
        tween(knob, TweenInfo.new(0.14), { Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.fromOffset(3, 3) })
        tween(glow, TweenInfo.new(0.14), { Transparency = state and 0.65 or 1 })
        
        fireCallback(state)
    end)

    if defaultState then
        task.defer(function() fireCallback(true) end)
    end

    table.insert(InteractiveElements, {
        Frame = row,
        Action = function()
            state = not state
            tween(button, TweenInfo.new(0.14), { BackgroundColor3 = state and THEME.Accent or THEME.CardAlt })
            tween(knob, TweenInfo.new(0.14), { Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.fromOffset(3, 3) })
            tween(glow, TweenInfo.new(0.14), { Transparency = state and 0.65 or 1 })
            fireCallback(state)
        end
    })

    return row
end

local function createSlider(parent, setting, min, max, default, step, suffix)
    step = step or 1
    suffix = suffix or ""
    
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local titleLbl = label(row, setting, UDim2.new(0.6, 0, 0, 18), UDim2.fromOffset(0, 0), 11, THEME.TextMuted, FONT)
    local valLbl = label(row, tostring(default) .. suffix, UDim2.new(0.4, 0, 0, 18), UDim2.new(0.6, 0, 0, 0), 11, THEME.AccentBright, FONT)
    valLbl.TextXAlignment = Enum.TextXAlignment.Right

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 8)
    track.Position = UDim2.fromOffset(0, 26)
    track.BackgroundColor3 = THEME.CardAlt
    track.Parent = row
    corner(track, 4)
    stroke(track, THEME.BorderDim, 1)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = THEME.Accent
    fill.Parent = track
    corner(fill, 4)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((default - min) / (max - min), 0, 0.5, 0)
    knob.BackgroundColor3 = THEME.Text
    knob.Parent = track
    corner(knob, 7)
    stroke(knob, THEME.AccentBright, 1)

    local val = default
    local draggingSlider = false

    local function updateValue(inputPos)
        local relX = math.clamp((inputPos.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local rawVal = min + (relX * (max - min))
        val = math.floor(rawVal / step + 0.5) * step
        val = math.clamp(val, min, max)

        local percent = (val - min) / (max - min)
        fill.Size = UDim2.new(percent, 0, 1, 0)
        knob.Position = UDim2.new(percent, 0, 0.5, 0)
        valLbl.Text = tostring(val) .. suffix

        if _G.AtomwareEvents and _G.AtomwareEvents[setting] then
            task.spawn(_G.AtomwareEvents[setting], val)
        end
    end

    row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true
            updateValue(input.Position)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateValue(input.Position)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = false
        end
    end)

    task.defer(function()
        if _G.AtomwareEvents and _G.AtomwareEvents[setting] then
            task.spawn(_G.AtomwareEvents[setting], val)
        end
    end)

    table.insert(InteractiveElements, {
        Frame = row,
        Adjust = function(delta)
            val = math.clamp(val + (delta * step), min, max)
            local percent = (val - min) / (max - min)
            fill.Size = UDim2.new(percent, 0, 1, 0)
            knob.Position = UDim2.new(percent, 0, 0.5, 0)
            valLbl.Text = tostring(val) .. suffix
            if _G.AtomwareEvents and _G.AtomwareEvents[setting] then
                task.spawn(_G.AtomwareEvents[setting], val)
            end
        end
    })

    return row
end

local function createDropdown(parent, setting, options, default)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 52)
    row.BackgroundTransparency = 1
    row.Parent = parent

    label(row, setting, UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 0), 11, THEME.TextMuted, FONT)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 26)
    btn.Position = UDim2.fromOffset(0, 22)
    btn.BackgroundColor3 = THEME.CardAlt
    btn.Text = "  " .. tostring(default or options[1])
    btn.TextColor3 = THEME.Text
    btn.TextSize = 11
    btn.Font = FONT
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.Parent = row
    corner(btn, 6)
    stroke(btn, THEME.BorderDim, 1)

    local arrow = label(btn, "▼", UDim2.fromOffset(24, 26), UDim2.new(1, -24, 0, 0), 10, THEME.AccentBright, FONT)
    arrow.TextXAlignment = Enum.TextXAlignment.Center

    local dropFrame = Instance.new("Frame")
    dropFrame.Size = UDim2.new(1, 0, 0, #options * 26 + 6)
    dropFrame.Position = UDim2.new(0, 0, 1, 4)
    dropFrame.BackgroundColor3 = THEME.Header
    dropFrame.Visible = false
    dropFrame.ZIndex = 50
    dropFrame.Parent = btn
    corner(dropFrame, 6)
    stroke(dropFrame, THEME.Accent, 1)

    local dropList = Instance.new("UIListLayout")
    dropList.Padding = UDim.new(0, 2)
    dropList.Parent = dropFrame
    padding(dropFrame, 4, 4, 4, 4)

    local selected = default or options[1]
    local open = false

    local function toggleDrop()
        open = not open
        dropFrame.Visible = open
        arrow.Text = open and "▲" or "▼"
    end

    btn.MouseButton1Click:Connect(toggleDrop)

    for _, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 24)
        optBtn.BackgroundColor3 = THEME.Card
        optBtn.Text = "  " .. tostring(opt)
        optBtn.TextColor3 = opt == selected and THEME.AccentBright or THEME.TextMuted
        optBtn.TextSize = 11
        optBtn.Font = FONT
        optBtn.TextXAlignment = Enum.TextXAlignment.Left
        optBtn.ZIndex = 51
        optBtn.Parent = dropFrame
        corner(optBtn, 4)

        optBtn.MouseButton1Click:Connect(function()
            selected = opt
            btn.Text = "  " .. tostring(opt)
            toggleDrop()

            for _, child in ipairs(dropFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    child.TextColor3 = child.Text == ("  " .. tostring(selected)) and THEME.AccentBright or THEME.TextMuted
                end
            end

            if _G.AtomwareEvents and _G.AtomwareEvents[setting] then
                task.spawn(_G.AtomwareEvents[setting], selected)
            end
        end)
    end

    task.defer(function()
        if _G.AtomwareEvents and _G.AtomwareEvents[setting] then
            task.spawn(_G.AtomwareEvents[setting], selected)
        end
    end)

    table.insert(InteractiveElements, {
        Frame = row,
        Action = toggleDrop
    })

    return row
end

local function createColorPicker(parent, setting, defaultColor)
    defaultColor = defaultColor or Color3.fromRGB(157, 48, 255)
    
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.Parent = parent

    label(row, setting, UDim2.new(1, -52, 1, 0), UDim2.fromOffset(0, 0), 11, THEME.TextMuted, FONT)

    local preview = Instance.new("TextButton")
    preview.Size = UDim2.fromOffset(36, 20)
    preview.Position = UDim2.new(1, -36, 0.5, -10)
    preview.BackgroundColor3 = defaultColor
    preview.Text = ""
    preview.AutoButtonColor = false
    preview.Parent = row
    corner(preview, 6)
    stroke(preview, THEME.BorderDim, 1)

    local palettePresets = {
        Color3.fromRGB(255, 255, 255),
        Color3.fromRGB(157, 48, 255),
        Color3.fromRGB(205, 104, 255),
        Color3.fromRGB(42, 255, 157),
        Color3.fromRGB(255, 75, 125),
        Color3.fromRGB(255, 215, 0),
        Color3.fromRGB(0, 150, 255),
        Color3.fromRGB(72, 72, 72)
    }

    local popover = Instance.new("Frame")
    popover.Size = UDim2.fromOffset(170, 70)
    popover.Position = UDim2.new(1, -170, 1, 4)
    popover.BackgroundColor3 = THEME.Header
    popover.Visible = false
    popover.ZIndex = 60
    popover.Parent = preview
    corner(popover, 8)
    stroke(popover, THEME.Accent, 1)

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.fromOffset(34, 26)
    grid.CellPadding = UDim2.fromOffset(4, 4)
    grid.Parent = popover
    padding(popover, 6, 6, 6, 6)

    local open = false
    preview.MouseButton1Click:Connect(function()
        open = not open
        popover.Visible = open
    end)

    local curColor = defaultColor

    for _, color in ipairs(palettePresets) do
        local pBtn = Instance.new("TextButton")
        pBtn.BackgroundColor3 = color
        pBtn.Text = ""
        pBtn.ZIndex = 61
        pBtn.Parent = popover
        corner(pBtn, 4)

        pBtn.MouseButton1Click:Connect(function()
            curColor = color
            preview.BackgroundColor3 = color
            open = false
            popover.Visible = false

            if _G.AtomwareEvents and _G.AtomwareEvents[setting] then
                task.spawn(_G.AtomwareEvents[setting], curColor)
            end
        end)
    end

    table.insert(InteractiveElements, {
        Frame = row,
        Action = function()
            open = not open
            popover.Visible = open
        end
    })

    return row
end

local function createKeybind(parent, setting, defaultKey)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.Parent = parent

    label(row, setting, UDim2.new(1, -70, 1, 0), UDim2.fromOffset(0, 0), 11, THEME.TextMuted, FONT)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(60, 22)
    btn.Position = UDim2.new(1, -60, 0.5, -11)
    btn.BackgroundColor3 = THEME.CardAlt
    btn.Text = defaultKey or "None"
    btn.TextColor3 = THEME.AccentBright
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.Parent = row
    corner(btn, 6)
    stroke(btn, THEME.BorderDim, 1)

    local currentKey = defaultKey
    local listening = false

    btn.MouseButton1Click:Connect(function()
        listening = true
        btn.Text = "..."
        btn.TextColor3 = THEME.Red
    end)

    UserInputService.InputBegan:Connect(function(input, gpe)
        if listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                currentKey = input.KeyCode.Name
                listening = false
                btn.Text = currentKey
                btn.TextColor3 = THEME.AccentBright
                if _G.AtomwareEvents and _G.AtomwareEvents[setting] then
                    task.spawn(_G.AtomwareEvents[setting], currentKey)
                end
            elseif input.UserInputType == Enum.UserInputType.Gamepad1 then
                currentKey = input.KeyCode.Name
                listening = false
                btn.Text = currentKey
                btn.TextColor3 = THEME.AccentBright
                if _G.AtomwareEvents and _G.AtomwareEvents[setting] then
                    task.spawn(_G.AtomwareEvents[setting], currentKey)
                end
            end
        end
    end)

    table.insert(InteractiveElements, {
        Frame = row,
        Action = function()
            listening = true
            btn.Text = "..."
            btn.TextColor3 = THEME.Red
        end
    })

    return row
end

--//==================================================
--// BUILD PAGES & POPULATE UI
--//==================================================

local tabsData = {
    { Name = "Visuals",  Icon = "👁️" },
    { Name = "Combat",   Icon = "🎯" },
    { Name = "World",    Icon = "🌍" },
    { Name = "Player",   Icon = "🧍" },
    { Name = "Settings", Icon = "⚙️" }
}

for i, tabInfo in ipairs(tabsData) do
    local pageName = tabInfo.Name
    local page = createPage(pageName)

    -- Populate Desktop Sidebar Buttons
    local sideBtn = makeButton(DesktopSidebar, "  " .. tabInfo.Icon .. "  " .. pageName, UDim2.new(1, 0, 0, 36))
    sideBtn.LayoutOrder = i
    sideBtn.TextXAlignment = Enum.TextXAlignment.Left
    PageButtons["Sidebar" .. pageName] = sideBtn
    sideBtn.MouseButton1Click:Connect(function() switchPage(pageName) end)
    addHover(sideBtn, THEME.Card, THEME.CardHover)

    -- Populate Top Header Buttons
    local topBtn = makeButton(TopTabs, pageName, UDim2.fromOffset(80, 31))
    topBtn.LayoutOrder = i
    PageButtons[pageName] = topBtn
    topBtn.MouseButton1Click:Connect(function() switchPage(pageName) end)
    addHover(topBtn, THEME.Card, THEME.CardHover)

    -- Populate Mobile Tab Buttons
    local mobileBtn = makeButton(MobileTabBar, pageName, UDim2.fromOffset(90, 34))
    mobileBtn.LayoutOrder = i
    PageButtons["Mobile" .. pageName] = mobileBtn
    mobileBtn.MouseButton1Click:Connect(function() switchPage(pageName) end)
    addHover(mobileBtn, THEME.Card, THEME.CardHover)
end

-- ---------------------------------------------------
-- TAB 1: VISUALS
-- ---------------------------------------------------
local pageVisuals = Pages["Visuals"]

local sPlayerESP, bPlayerESP = createSection(pageVisuals, "Player ESP", 220)
createToggle(bPlayerESP, "Enable ESP", false)
createToggle(bPlayerESP, "Box Esp", false)
createToggle(bPlayerESP, "Distance Esp", false)
createToggle(bPlayerESP, "Player/Bot Esp", false)
createToggle(bPlayerESP, "Sleeper Check", false)
createToggle(bPlayerESP, "Weapon Esp", false)
createToggle(bPlayerESP, "Skeleton Esp", false)

local sESPColors, bESPColors = createSection(pageVisuals, "ESP Customization", 180)
createColorPicker(bESPColors, "Box Color", Color3.fromRGB(255, 255, 255))
createColorPicker(bESPColors, "Skeleton Color", Color3.fromRGB(255, 255, 255))
createColorPicker(bESPColors, "Text Color", Color3.fromRGB(255, 255, 255))

local sArmorESP, bArmorESP = createSection(pageVisuals, "Armor ESP", 160)
createToggle(bArmorESP, "Armor Esp", false)
createSlider(bArmorESP, "Fov Slider", 10, 500, 220, 5, "px")

local sOtherESP, bOtherESP = createSection(pageVisuals, "World Items ESP", 200)
createToggle(bOtherESP, "Item ESP", false)
createToggle(bOtherESP, "Corpse ESP", false)
createToggle(bOtherESP, "Raid ESP", false)
createToggle(bOtherESP, "Airdrop ESP", false)

local sOreESP, bOreESP = createSection(pageVisuals, "Ore ESP", 220)
createToggle(bOreESP, "Stone Esp", false)
createToggle(bOreESP, "Iron Esp", false)
createToggle(bOreESP, "Nitrate Esp", false)
createToggle(bOreESP, "Show Distance", false)
createSlider(bOreESP, "Ore Distance Esp", 10, 1000, 750, 10, "m")

local sVehicleESP, bVehicleESP = createSection(pageVisuals, "Vehicle ESP", 220)
createToggle(bVehicleESP, "ATV", false)
createToggle(bVehicleESP, "Boat", false)
createToggle(bVehicleESP, "Helicopter", false)
createToggle(bVehicleESP, "Trolly", false)
createToggle(bVehicleESP, "Vehicle Distance Esp", false)

local sMatChams, bMatChams = createSection(pageVisuals, "Player Material Chams", 240)
createToggle(bMatChams, "Enable Material Chams", false)
createDropdown(bMatChams, "Chams Material", { "ForceField", "Neon", "Glass", "Ice", "Marble", "Foil", "Metal", "Wood" }, "ForceField")
createColorPicker(bMatChams, "Chams Color", Color3.fromRGB(120, 200, 255))
createToggle(bMatChams, "Chams See Through", true)
createToggle(bMatChams, "Chams Team Check", false)

-- ---------------------------------------------------
-- TAB 2: COMBAT
-- ---------------------------------------------------
local pageCombat = Pages["Combat"]

local sAimbot, bAimbot = createSection(pageCombat, "Aimbot Settings", 240)
createToggle(bAimbot, "Aimbot Enabled", false)
createToggle(bAimbot, "Show FOV Circle", true)
createSlider(bAimbot, "Aimbot FOV", 10, 500, 120, 5, "px")
createSlider(bAimbot, "Aimbot Smoothing", 0.01, 1, 0.15, 0.01, "")
createDropdown(bAimbot, "Aim Hit Part", { "Head", "UpperTorso", "HumanoidRootPart" }, "Head")
createToggle(bAimbot, "Aimbot Team Check", true)
createKeybind(bAimbot, "Aim Key", "MouseButton2")

local sBigHead, bBigHead = createSection(pageCombat, "Big Head Hitbox", 160)
createToggle(bBigHead, "Big Head", false)
createSlider(bBigHead, "Head Size", 1, 10, 2, 1, "x")
createSlider(bBigHead, "Head Transparency", 0, 1, 0, 0.1, "")

-- ---------------------------------------------------
-- TAB 3: WORLD
-- ---------------------------------------------------
local pageWorld = Pages["World"]

local sWater, bWater = createSection(pageWorld, "Water Customization", 200)
createColorPicker(bWater, "Water Color", Color3.fromRGB(12, 84, 92))
createToggle(bWater, "Water Reflectance", true)
createSlider(bWater, "Water speed", 1, 100, 10, 1, "")
createSlider(bWater, "Wave size", 0, 1, 0.5, 0.1, "")

local sClouds, bClouds = createSection(pageWorld, "Clouds & Sky", 220)
createColorPicker(bClouds, "Cloud Color", Color3.fromRGB(255, 255, 255))
createSlider(bClouds, "Clouds Cover", 0, 1, 0.6, 0.1, "")
createDropdown(bClouds, "Sky Changer", { "Default", "Magma", "Water", "Obsidian", "Galaxy", "Void" }, "Default")

local sWorldEnv, bWorldEnv = createSection(pageWorld, "Environment & Night", 220)
createToggle(bWorldEnv, "Shadows", true)
createToggle(bWorldEnv, "Grass", true)
createToggle(bWorldEnv, "Tree Leaves", true)
createToggle(bWorldEnv, "Bright Night", false)

local sLighting, bLighting = createSection(pageWorld, "Lighting Effects", 220)
createToggle(bLighting, "Stim Effect", false)
createColorPicker(bLighting, "TintColor", Color3.fromRGB(255, 255, 255))
createSlider(bLighting, "Brightness", 0.1, 100, 0.1, 0.5, "")
createSlider(bLighting, "Contrast", 0, 20, 1, 0.1, "")
createSlider(bLighting, "Saturation", 0, 100, 10, 1, "")

-- ---------------------------------------------------
-- TAB 4: PLAYER
-- ---------------------------------------------------
local pagePlayer = Pages["Player"]

local sCamera, bCamera = createSection(pagePlayer, "Camera & FOV", 180)
createKeybind(bCamera, "Xray", "V")
createKeybind(bCamera, "Zoom", "X")
createSlider(bCamera, "FOV Changer", 50, 120, 70, 1, "°")

local sAudio, bAudio = createSection(pagePlayer, "Hit Sounds", 180)
createDropdown(bAudio, "Hit sound", { "Default", "Rust", "Gamesense", "Magic", "Firework", "Lazer", "Pop", "Zap" }, "Default")
createSlider(bAudio, "Hit sound Volume", 0.1, 5, 1, 0.1, "")

local sTrails, bTrails = createSection(pagePlayer, "Weapon & Bullet Trails", 240)
createColorPicker(bTrails, "Arrow Trailcolor", Color3.fromRGB(255, 255, 255))
createSlider(bTrails, "Arrow Trail lifespan", 0.15, 20, 0.15, 0.1, "s")
createToggle(bTrails, "Bullet Trail", false)
createColorPicker(bTrails, "Bullet Trail Color", Color3.fromRGB(255, 255, 255))
createSlider(bTrails, "Trail Thickness", 0.1, 1, 0.2, 0.1, "")
createSlider(bTrails, "Bullet Trail Length", 1, 25, 10, 1, "")
createSlider(bTrails, "Trail LifeTime", 0.01, 5, 0.1, 0.05, "s")

local sChams, bChams = createSection(pagePlayer, "Hand & Weapon Chams", 220)
createDropdown(bChams, "Hand Cham Material", { "Default", "ForceField", "Neon", "Asphalt" }, "Default")
createColorPicker(bChams, "Hand cham color", Color3.fromRGB(255, 255, 255))
createDropdown(bChams, "Weapon Cham Material", { "Default", "ForceField", "Neon", "Asphalt" }, "Default")
createColorPicker(bChams, "Weapon Cham Color", Color3.fromRGB(255, 255, 255))

local sFreeCam, bFreeCam = createSection(pagePlayer, "Free Camera", 160)
createKeybind(bFreeCam, "Free Cam", "Z")
createSlider(bFreeCam, "FreeCam Speed", 1, 500, 150, 5, "")

-- ---------------------------------------------------
-- TAB 5: SETTINGS
-- ---------------------------------------------------
local pageSettings = Pages["Settings"]

local sController, bController = createSection(pageSettings, "Xbox Controller Support", 160)
label(bController, "• LB : Toggle UI Window", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 0), 11, THEME.TextMuted, FONT)
label(bController, "• RB : Toggle Aimbot Lock", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 20), 11, THEME.TextMuted, FONT)
label(bController, "• D-Pad Left/Right : Switch Tabs", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 40), 11, THEME.TextMuted, FONT)
label(bController, "• D-Pad Up/Down : Navigate Items", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 60), 11, THEME.TextMuted, FONT)
label(bController, "• A Button : Select / Toggle Option", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 80), 11, THEME.TextMuted, FONT)

local sUISettings, bUISettings = createSection(pageSettings, "UI & Keybinds", 160)
createKeybind(bUISettings, "Toggle Menu Key", "Insert")
local closeBtnRow = Instance.new("Frame")
closeBtnRow.Size = UDim2.new(1, 0, 0, 36)
closeBtnRow.BackgroundTransparency = 1
closeBtnRow.Parent = bUISettings

local destroyBtn = makeButton(closeBtnRow, "Close Atomware UI", UDim2.new(1, 0, 1, 0))
destroyBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
destroyBtn.TextColor3 = THEME.Red
destroyBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

switchPage("Visuals")

--//==================================================
--// CONTROLLER NAVIGATION SYSTEM
--//==================================================

local focusedIndex = 1
local cursorHighlight = Instance.new("UIStroke")
cursorHighlight.Color = THEME.AccentBright
cursorHighlight.Thickness = 2
cursorHighlight.Enabled = false

local function updateControllerNavigation()
    local validElements = {}
    for _, item in ipairs(InteractiveElements) do
        if item.Frame and item.Frame:IsDescendantOf(Pages[CurrentPageName]) and item.Frame.Visible then
            table.insert(validElements, item)
        end
    end

    if #validElements == 0 then return end
    focusedIndex = math.clamp(focusedIndex, 1, #validElements)

    local target = validElements[focusedIndex]
    if target and target.Frame then
        cursorHighlight.Parent = target.Frame
        cursorHighlight.Enabled = true
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.UserInputType == Enum.UserInputType.Gamepad1 then
        if input.KeyCode == Enum.KeyCode.ButtonLB then
            setUIVisible(not UIVisible)
        elseif input.KeyCode == Enum.KeyCode.DPadDown then
            focusedIndex = focusedIndex + 1
            updateControllerNavigation()
        elseif input.KeyCode == Enum.KeyCode.DPadUp then
            focusedIndex = math.max(1, focusedIndex - 1)
            updateControllerNavigation()
        elseif input.KeyCode == Enum.KeyCode.DPadRight then
            local currentIndex = 1
            for idx, tab in ipairs(tabsData) do
                if tab.Name == CurrentPageName then currentIndex = idx break end
            end
            local nextIndex = (currentIndex % #tabsData) + 1
            switchPage(tabsData[nextIndex].Name)
            focusedIndex = 1
            updateControllerNavigation()
        elseif input.KeyCode == Enum.KeyCode.DPadLeft then
            local currentIndex = 1
            for idx, tab in ipairs(tabsData) do
                if tab.Name == CurrentPageName then currentIndex = idx break end
            end
            local prevIndex = (currentIndex - 2) % #tabsData + 1
            switchPage(tabsData[prevIndex].Name)
            focusedIndex = 1
            updateControllerNavigation()
        elseif input.KeyCode == Enum.KeyCode.ButtonA then
            local validElements = {}
            for _, item in ipairs(InteractiveElements) do
                if item.Frame and item.Frame:IsDescendantOf(Pages[CurrentPageName]) then
                    table.insert(validElements, item)
                end
            end
            local currentItem = validElements[focusedIndex]
            if currentItem and currentItem.Action then
                currentItem.Action()
            end
        end
    elseif not IS_MOBILE and input.KeyCode == Enum.KeyCode.Insert then
        setUIVisible(not UIVisible)
    end
end)

workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
updateResponsiveLayout()

_G.AtomwareUILoaded = true
print("Good to go")

--//==================================================
--// BOOTSTRAP EXTERNAL FEATURES SCRIPT FROM GITHUB (IF NOT LOADED)
--//==================================================

task.spawn(function()
    task.wait(0.1)
    if not _G.AtomwareFeaturesLoaded then
        local url = "https://raw.githubusercontent.com/redisaac758-art/RadiumCCpaste/main/features.lua"
        local success, scriptContent = pcall(function()
            return game:HttpGet(url)
        end)

        if success and scriptContent then
            local fn, err = loadstring(scriptContent)
            if fn then
                fn()
            else
                warn("Failed to compile features.lua:", err)
            end
        else
            warn("Failed to fetch features.lua from GitHub repository:", url)
        end
    end
end)
