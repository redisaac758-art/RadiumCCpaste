--[[
    init.lua
    Master initialization loader for Atomware UI & Features (Trident Survival)
]]

local BASE_URL = "https://raw.githubusercontent.com/redisaac758-art/RadiumCCpaste/main/"

-- 1. Load Main UI Shell
local uiCode = game:HttpGet(BASE_URL .. "main_ui.lua")
local uiFunc, uiErr = loadstring(uiCode)
if uiFunc then
    uiFunc()
else
    warn("Failed to load main_ui.lua:", uiErr)
end

-- 2. Wait for UI event hooks to initialize
repeat task.wait() until _G.AtomwareUILoaded and _G.AtomwareEvents and _G.OnToggle

-- 3. Load Features Engine (if not already loaded by UI bootstrap)
if not _G.AtomwareFeaturesLoaded then
    local featuresCode = game:HttpGet(BASE_URL .. "features.lua")
    local featuresFunc, featuresErr = loadstring(featuresCode)
    if featuresFunc then
        featuresFunc()
    else
        warn("Failed to load features.lua:", featuresErr)
    end
end

-- 4. Verify all components are online and active
repeat task.wait() until _G.AtomwareUILoaded and _G.AtomwareFeaturesLoaded

-- 5. Final Confirmation Print
print("Fully Intalized")
