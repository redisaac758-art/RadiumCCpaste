--[[
    init.lua
    Universal Master Initializer for Atomware (Trident Survival)
    Automatically detects platform (Mobile vs PC / Controller) and loads the dedicated UI + Features Backend
]]

local UserInputService = game:GetService("UserInputService")
local BASE_URL = "https://raw.githubusercontent.com/redisaac758-art/RadiumCCpaste/main/"

-- Platform Detection
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local targetUIFile = IS_MOBILE and "mobile_ui.lua" or "main_ui.lua"

-- 1. Load Targeted Platform UI
local uiCode = game:HttpGet(BASE_URL .. targetUIFile)
local uiFunc, uiErr = loadstring(uiCode)
if uiFunc then
    uiFunc()
else
    warn("Failed to load " .. targetUIFile .. ":", uiErr)
end

-- 2. Wait for UI hooks to initialize
repeat task.wait() until _G.AtomwareUILoaded and _G.AtomwareEvents and _G.OnToggle

-- 3. Load Shared Features Engine
if not _G.AtomwareFeaturesLoaded then
    local featuresCode = game:HttpGet(BASE_URL .. "features.lua")
    local featuresFunc, featuresErr = loadstring(featuresCode)
    if featuresFunc then
        featuresFunc()
    else
        warn("Failed to load features.lua:", featuresErr)
    end
end

-- 4. Verify everything is online
repeat task.wait() until _G.AtomwareUILoaded and _G.AtomwareFeaturesLoaded

-- 5. Confirmation Print
print("Fully Intalized")
