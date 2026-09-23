--[[
    init.lua
    Universal Master Initializer for Atomware (Trident Survival)
    Automatically detects platform (Mobile vs PC / Controller) and loads the dedicated UI + Features Backend
]]

local ALLOWED_PLACE_ID = 13253735473
local isAllowedGame = game.PlaceId == ALLOWED_PLACE_ID or game.GameId == ALLOWED_PLACE_ID
if not isAllowedGame then
    if _G.AtomwareUnload and (_G.AtomwareUILoaded or _G.AtomwareFeaturesLoaded) then
        pcall(_G.AtomwareUnload)
    end

    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            for _, name in ipairs({ "AtomwareUI", "AtomwareMobileUI" }) do
                local existing = playerGui:FindFirstChild(name)
                if existing then existing:Destroy() end
            end
        end
    end)

    local parent
    pcall(function()
        if type(gethui) == "function" then
            parent = gethui()
        else
            local player = game:GetService("Players").LocalPlayer
            parent = player and player:FindFirstChildOfClass("PlayerGui")
        end
    end)

    if parent then
        pcall(function()
            local existing = parent:FindFirstChild("AtomwareUnsupportedNotice")
            if existing then existing:Destroy() end

            local screen = Instance.new("ScreenGui")
            screen.Name = "AtomwareUnsupportedNotice"
            screen.ResetOnSpawn = false
            screen.IgnoreGuiInset = true
            screen.DisplayOrder = 10000

            local message = Instance.new("TextLabel")
            message.Name = "Message"
            message.AnchorPoint = Vector2.new(0.5, 0.5)
            message.Position = UDim2.fromScale(0.5, 0.5)
            message.Size = UDim2.new(0.8, 0, 0, 64)
            message.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
            message.BackgroundTransparency = 0.05
            message.BorderSizePixel = 0
            message.Text = "Atomware does not support the game you're in."
            message.TextColor3 = Color3.fromRGB(255, 255, 255)
            message.TextSize = 18
            message.TextWrapped = true
            message.Font = Enum.Font.GothamMedium
            message.Parent = screen

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 10)
            corner.Parent = message

            screen.Parent = parent
        end)
    end
    return
end

local UserInputService = game:GetService("UserInputService")
local BASE_URL = "https://raw.githubusercontent.com/redisaac758-art/RadiumCCpaste/main/"

-- If the initializer is run again, unload the previous UI/backend first.
if _G.AtomwareUnload and (_G.AtomwareUILoaded or _G.AtomwareFeaturesLoaded) then
    pcall(_G.AtomwareUnload)
end

-- Platform Detection
-- TouchEnabled alone is the correct signal for mobile/tablet — a tablet with a
-- Bluetooth keyboard or mouse still reports MouseEnabled/KeyboardEnabled as true,
-- so we must NOT use those to gate the check.
local IS_MOBILE = UserInputService.TouchEnabled
local targetUIFile = IS_MOBILE and "mobile_ui.lua" or "main_ui.lua"

local function loadRemote(path)
    local ok, source = pcall(function()
        return game:HttpGet(BASE_URL .. path)
    end)
    if not ok then
        warn("Atomware: failed to download " .. path .. ":", source)
        return false
    end

    local compileOk, chunk, compileErr = pcall(loadstring, source)
    if not compileOk or not chunk then
        warn("Atomware: failed to compile " .. path .. ":", compileErr or chunk)
        return false
    end

    local runOk, runErr = pcall(chunk)
    if not runOk then
        warn("Atomware: failed to run " .. path .. ":", runErr)
        return false
    end
    return true
end

-- 1. Load Targeted Platform UI
if not loadRemote("config.lua") then
    warn("Atomware: shared configuration could not be loaded; startup aborted.")
    return
end

_G.AtomwareUnload = function()
    local player = game:GetService("Players").LocalPlayer
    local playerGui = player and player:FindFirstChild("PlayerGui")
    local gui = playerGui and (playerGui:FindFirstChild("AtomwareUI") or playerGui:FindFirstChild("AtomwareMobileUI"))
    if _G.AtomwareConfig then
        _G.AtomwareConfig:Unload(gui)
    elseif gui then
        gui:Destroy()
    end
end

if not loadRemote(targetUIFile) then return end

-- 2. Wait for UI hooks to initialize (timeout after 15 s)
local uiWaitCount = 0
repeat
    task.wait()
    uiWaitCount = uiWaitCount + 1
    if uiWaitCount > 900 then
        warn("Atomware: UI failed to initialise after 15s — aborting.")
        return
    end
until _G.AtomwareUILoaded and _G.AtomwareEvents and _G.OnToggle

-- 3. Load Shared Features Engine
if not _G.AtomwareFeaturesLoaded then
    loadRemote("features.lua")
end

-- 4. Verify everything is online (timeout after 15 s)
local verifyCount = 0
repeat
    task.wait()
    verifyCount = verifyCount + 1
    if verifyCount > 900 then
        warn("Atomware: Features failed to mark loaded after 15s — check features.lua for errors.")
        break
    end
until _G.AtomwareUILoaded and _G.AtomwareFeaturesLoaded

-- 5. Confirmation Print
print("Fully Intalized")
