--[[
    FeaturesScript.lua (features.lua)
    Optimized Backend Features Engine for Atomware (Trident Survival)
    Contains Complete Radium.cc Port, Advanced Mobile/Controller Aimbot, ESPs & Performance Caching
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera", 10)
if not Camera then error("Atomware: CurrentCamera was unavailable after 10 seconds") end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if Workspace.CurrentCamera then Camera = Workspace.CurrentCamera end
end)

--//==================================================
--// EVENT HOOK WAITER
--//==================================================

repeat task.wait() until _G.OnToggle and _G.OnSlider and _G.OnDropdown and _G.OnColorPicker

--//==================================================
--// AIMBOT & AIMLOCK ENGINE (DESKTOP, CONTROLLER & MOBILE)
--//==================================================

local AimbotConfig = {
    Enabled = false,
    Mode = "Controller Bind", -- "Controller Bind" | "Always On" | "Hold Toggle"
    ShowFOV = true,
    FOV = 130,
    Smoothing = 0.15,
    HitPart = "Head",
    TeamCheck = true,
    AimKey = Enum.UserInputType.MouseButton2,
    AimKeyName = "MouseButton2",
    Active = false,
    ToggleState = false
}

local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Thickness = 1.5
FOVCircle.Color = Color3.fromRGB(184, 73, 255)
FOVCircle.Filled = false
FOVCircle.NumSides = 64

local function getTargetHitPart(model)
    local part = model:FindFirstChild(AimbotConfig.HitPart)
    if not part then
        part = model:FindFirstChild("Head") or model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart")
    end
    return part
end

local function getClosestTargetInFOV()
    local closestPart = nil
    local shortestDistance = AimbotConfig.FOV
    local viewportCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    -- 1. Check Player Characters
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not (AimbotConfig.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team) then
                local char = player.Character
                if char then
                    local part = getTargetHitPart(char)
                    if part then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if onScreen then
                            local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - viewportCenter).Magnitude
                            if screenDist <= shortestDistance then
                                shortestDistance = screenDist
                                closestPart = part
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. Check Custom Workspace Character Models (Trident Survival)
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and model ~= LocalPlayer.Character and not Players:GetPlayerFromCharacter(model) then
            local part = getTargetHitPart(model)
            if part then
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - viewportCenter).Magnitude
                    if screenDist <= shortestDistance then
                        shortestDistance = screenDist
                        closestPart = part
                    end
                end
            end
        end
    end

    return closestPart
end

-- Input Listeners for Aimbot
-- NOTE: For mouse buttons, AimKey is a UserInputType (e.g. MouseButton2).
--       For keyboard/gamepad buttons, AimKey is a KeyCode (e.g. ButtonR2, E).
--       We must check BOTH independently because gamepad input reports Gamepad1
--       as UserInputType and the actual button (such as ButtonR2) as KeyCode.
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe and input.UserInputType ~= Enum.UserInputType.Gamepad1 then return end
    local keyMatch = (input.UserInputType == AimbotConfig.AimKey)
        or (input.KeyCode == AimbotConfig.AimKey)
    if not keyMatch then return end

    if AimbotConfig.Mode == "Hold Toggle" then
        AimbotConfig.ToggleState = not AimbotConfig.ToggleState
    else
        -- "Controller Bind" and any other mode: hold-to-aim
        AimbotConfig.Active = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    local keyMatch = (input.UserInputType == AimbotConfig.AimKey)
        or (input.KeyCode == AimbotConfig.AimKey)
    if not keyMatch then return end

    -- Only release aim on key-up for hold-style modes
    if AimbotConfig.Mode == "Controller Bind" then
        AimbotConfig.Active = false
    end
    -- "Hold Toggle" and "Always On" are unaffected by key release
end)

-- Mobile & Controller Global Aim Triggers
_G.OnToggle("MobileAimTrigger", function(state)
    AimbotConfig.Active = state
    AimbotConfig.ToggleState = state
end)

-- ControllerAimToggle fires from the RB button in main_ui or from mobile UI.
-- Behaviour depends on the active mode so the right state variable is flipped.
_G.OnToggle("ControllerAimToggle", function()
    if AimbotConfig.Mode == "Hold Toggle" then
        AimbotConfig.ToggleState = not AimbotConfig.ToggleState
    elseif AimbotConfig.Mode == "Controller Bind" then
        -- In Controller Bind mode the RB shortcut acts as a software toggle
        AimbotConfig.Active = not AimbotConfig.Active
    end
    -- "Always On" needs no toggle — aim is driven by AimbotConfig.Enabled alone
end)

RunService.RenderStepped:Connect(function()
    local viewportCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Position = viewportCenter
    FOVCircle.Radius = AimbotConfig.FOV
    FOVCircle.Visible = AimbotConfig.Enabled and AimbotConfig.ShowFOV

    if AimbotConfig.Enabled then
        local shouldAim = false
        if AimbotConfig.Mode == "Always On" then
            shouldAim = true
        elseif AimbotConfig.Mode == "Hold Toggle" then
            shouldAim = AimbotConfig.ToggleState
        else
            shouldAim = AimbotConfig.Active
        end

        if shouldAim then
            local target = getClosestTargetInFOV()
            if target then
                local currentCF = Camera.CFrame
                local targetCF = CFrame.new(currentCF.Position, target.Position)
                Camera.CFrame = currentCF:Lerp(targetCF, math.clamp(AimbotConfig.Smoothing, 0.01, 1))
            end
        end
    end
end)

_G.OnToggle("Aimbot Enabled", function(s) AimbotConfig.Enabled = s end)
_G.OnDropdown("Aimbot Mode", function(m) AimbotConfig.Mode = m end)
_G.OnToggle("Show FOV Circle", function(s) AimbotConfig.ShowFOV = s end)
_G.OnSlider("Aimbot FOV", function(v) AimbotConfig.FOV = v end)
_G.OnSlider("Aimbot Smoothing", function(v) AimbotConfig.Smoothing = v end)
_G.OnDropdown("Aim Hit Part", function(p) AimbotConfig.HitPart = p end)
_G.OnToggle("Aimbot Team Check", function(s) AimbotConfig.TeamCheck = s end)
_G.OnKeybind("Aim Key", function(keyName)
    AimbotConfig.AimKeyName = keyName
    if Enum.UserInputType[keyName] then
        AimbotConfig.AimKey = Enum.UserInputType[keyName]
    elseif Enum.KeyCode[keyName] then
        AimbotConfig.AimKey = Enum.KeyCode[keyName]
    end
end)

--//==================================================
--// BIG HEAD HITBOX MODIFIER
--//==================================================

local HeadSizeEnabled = false
local headScale = Vector3.new(2, 2, 2)
local headTransparency = 0
local originalHeadStats = {}

local function applyBigHead(model)
    local head = model:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        if HeadSizeEnabled then
            if not originalHeadStats[head] then
                originalHeadStats[head] = { Size = head.Size, Transparency = head.Transparency }
            end
            head.Size = headScale
            head.Transparency = headTransparency
        elseif originalHeadStats[head] then
            head.Size = originalHeadStats[head].Size
            head.Transparency = originalHeadStats[head].Transparency
            originalHeadStats[head] = nil
        end
    end
end

task.spawn(function()
    while true do
        if HeadSizeEnabled then
            for _, model in ipairs(Workspace:GetChildren()) do
                if model:IsA("Model") and model ~= LocalPlayer.Character then
                    applyBigHead(model)
                end
            end
        end
        task.wait(1.5)
    end
end)

_G.OnToggle("Big Head", function(s)
    HeadSizeEnabled = s
    if not s then
        for head, stats in pairs(originalHeadStats) do
            if head and head.Parent then
                head.Size = stats.Size
                head.Transparency = stats.Transparency
            end
        end
        originalHeadStats = {}
    end
end)

_G.OnSlider("Head Size", function(v) headScale = Vector3.new(v, v, v) end)
_G.OnSlider("Head Transparency", function(v) headTransparency = v end)

--//==================================================
--// PLAYER DRAWING-BASED ESP & SKELETON
--//==================================================

local ESP_Master = false
local ESP_Box = false
local ESP_Distance = false
local ESP_Type = false
local ESP_SleeperCheck = false
local ESP_Weapon = false
local ESP_Skeleton = false

local Color_Box = Color3.fromRGB(255, 255, 255)
local Color_Skeleton = Color3.fromRGB(255, 255, 255)
local Color_Text = Color3.fromRGB(255, 255, 255)

local espCache = {}
local cachedWeapons = {}

local skeletonBones = {
    { "Head", "Torso" }, { "Torso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" },
    { "Torso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" },
    { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" },
    { "Torso", "LowerTorso" }, { "RightUpperLeg", "RightLowerLeg" },
    { "LowerTorso", "RightUpperLeg" }, { "LeftLowerLeg", "LeftFoot" },
    { "RightLowerLeg", "RightFoot" }, { "RightLowerArm", "RightHand" },
    { "LeftLowerArm", "LeftHand" }
}

local weaponDefinitions = {
    Bow = { "Arrow", "Handle" }, AR15 = { "Barrel", "Body", "Handle" },
    AdminMinigun = { "Body", "Handle" }, Bandage = { "Handle", "Bandage" },
    C4 = { "Handle", "Timer" }, C9 = { "Body", "Handle", "Slide" },
    CrossBow = { "Arrow", "Handle" }, Dynamite = { "Handle", "Fuse" },
    HMAR = { "Body", "Handle" }, M4A1 = { "Body", "Handle" },
    Minigun = { "Body", "Handle" }, PipePistol = { "Body", "Handle" },
    PumpShotgun = { "Barrel", "Body", "Handle" }, RPG = { "Body", "Handle" },
    SCAR = { "Body", "Handle" }, SVD = { "Body", "Handle" },
    USP9 = { "Body", "Handle" }, UZI = { "Body", "Handle" }
}

local function getPlayerParts(model)
    local head = model:FindFirstChild("Head")
    local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("LowerTorso")
    return head, torso
end

local function isPlayerModel(model)
    local torso = model:FindFirstChild("Torso")
    return torso and torso:FindFirstChild("LeftBooster") ~= nil
end

local function detectWeapon(model)
    local handModel = model:FindFirstChild("HandModel")
    if not handModel then return "None" end
    local bestMatch = "None"
    local highest = 0
    for wName, parts in pairs(weaponDefinitions) do
        local c = 0
        for _, p in ipairs(parts) do
            if handModel:FindFirstChild(p, true) then c = c + 1 end
        end
        if c > highest then highest = c bestMatch = wName end
    end
    return bestMatch
end

local function registerESP(model)
    if espCache[model] then return end
    -- Never draw ESP on the local player's own character
    if model == LocalPlayer.Character then return end
    -- Also skip if model is the local player character by player check
    if Players:GetPlayerFromCharacter(model) == LocalPlayer then return end
    local head, torso = getPlayerParts(model)
    if not head or not torso then return end

    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Color = Color_Box
    box.Visible = false

    local outline = Drawing.new("Square")
    outline.Thickness = 1
    outline.Filled = false
    outline.Color = Color3.fromRGB(0, 0, 0)
    outline.Visible = false

    local txt = Drawing.new("Text")
    txt.Size = 14
    txt.Center = true
    txt.Outline = true
    txt.OutlineColor = Color3.fromRGB(0, 0, 0)
    txt.Visible = false

    local weaponTxt = Drawing.new("Text")
    weaponTxt.Size = 13
    weaponTxt.Center = true
    weaponTxt.Outline = true
    weaponTxt.OutlineColor = Color3.fromRGB(0, 0, 0)
    weaponTxt.Visible = false

    local skelLines = {}
    for _, pair in ipairs(skeletonBones) do
        local line = Drawing.new("Line")
        line.Color = isPlayerModel(model) and Color_Skeleton or Color3.fromRGB(0, 150, 255)
        line.Thickness = 1.5
        line.Visible = false
        table.insert(skelLines, { line = line, a = pair[1], b = pair[2] })
    end

    espCache[model] = {
        box = box, outline = outline, text = txt,
        weaponText = weaponTxt, head = head, torso = torso,
        skeletonLines = skelLines
    }

    model.Destroying:Connect(function()
        pcall(function() box:Remove() end)
        pcall(function() outline:Remove() end)
        pcall(function() txt:Remove() end)
        pcall(function() weaponTxt:Remove() end)
        for _, l in ipairs(skelLines) do pcall(function() l.line:Remove() end) end
        espCache[model] = nil
    end)
end

for _, m in ipairs(Workspace:GetChildren()) do
    if m:IsA("Model") then registerESP(m) end
end
Workspace.ChildAdded:Connect(function(c)
    if c:IsA("Model") then registerESP(c) end
end)

-- Ensure local player's character is never kept in espCache across respawns
LocalPlayer.CharacterAdded:Connect(function(char)
    if espCache[char] then
        local d = espCache[char]
        pcall(function() d.box:Remove() end)
        pcall(function() d.outline:Remove() end)
        pcall(function() d.text:Remove() end)
        pcall(function() d.weaponText:Remove() end)
        for _, l in ipairs(d.skeletonLines) do pcall(function() l.line:Remove() end) end
        espCache[char] = nil
    end
end)

task.spawn(function()
    while true do
        for _, model in ipairs(Workspace:GetChildren()) do
            if model:IsA("Model") and not espCache[model] then registerESP(model) end
        end
        for m in pairs(espCache) do
            cachedWeapons[m] = detectWeapon(m)
        end
        task.wait(1.5)
    end
end)

RunService.RenderStepped:Connect(function()
    if not ESP_Master then
        for _, d in pairs(espCache) do
            d.box.Visible = false
            d.outline.Visible = false
            d.text.Visible = false
            d.weaponText.Visible = false
            for _, sk in ipairs(d.skeletonLines) do sk.line.Visible = false end
        end
        return
    end

    local camPos = Camera.CFrame.Position
    for model, d in pairs(espCache) do
        -- Skip local player's own character
        if model == LocalPlayer.Character or Players:GetPlayerFromCharacter(model) == LocalPlayer then
            d.box.Visible = false
            d.outline.Visible = false
            d.text.Visible = false
            d.weaponText.Visible = false
            for _, sk in ipairs(d.skeletonLines) do sk.line.Visible = false end
            continue
        end
        local valid = true
        local head, torso = d.head, d.torso
        if not head or not torso or not head.Parent or not torso.Parent then
            head, torso = getPlayerParts(model)
            d.head, d.torso = head, torso
            if not head or not torso then valid = false end
        end

        if valid and ESP_SleeperCheck then
            local lowerTorso = model:FindFirstChild("LowerTorso")
            if lowerTorso then
                local rootRig = lowerTorso:FindFirstChild("RootRig")
                if rootRig and typeof(rootRig.CurrentAngle) == "number" and rootRig.CurrentAngle ~= 0 then
                    valid = false
                end
            end
        end

        local dist = 0
        if valid then
            local mid = (head.Position + torso.Position) * 0.5
            dist = (mid - camPos).Magnitude
            if dist >= 3000 then valid = false end
        end

        local screenPos, onScreen = nil, false
        if valid then
            screenPos, onScreen = Camera:WorldToViewportPoint((head.Position + torso.Position) * 0.5)
            if not onScreen then valid = false end
        end

        if not valid then
            d.box.Visible = false
            d.outline.Visible = false
            d.text.Visible = false
            d.weaponText.Visible = false
            for _, sk in ipairs(d.skeletonLines) do sk.line.Visible = false end
        else
            local scale = 1000 / (dist * 2) / math.tan(math.rad(Camera.FieldOfView / 1.7))
            local w = math.clamp(math.floor(6.5 * scale), 10, 600)
            local h = math.clamp(math.floor(9.5 * scale), 14, 800)
            local bx = screenPos.X - w / 2
            local by = screenPos.Y - h / 3.5

            if ESP_Box then
                d.outline.Size = Vector2.new(w + 2, h + 2)
                d.outline.Position = Vector2.new(bx - 1, by - 1)
                d.outline.Visible = true

                d.box.Size = Vector2.new(w, h)
                d.box.Position = Vector2.new(bx, by)
                d.box.Color = isPlayerModel(model) and Color_Box or Color3.fromRGB(0, 150, 255)
                d.box.Visible = true
            else
                d.outline.Visible = false
                d.box.Visible = false
            end

            local lbls = {}
            if ESP_Type then table.insert(lbls, isPlayerModel(model) and "Player" or "Bot") end
            if ESP_Distance then table.insert(lbls, math.floor(dist) .. "m") end
            local txtStr = table.concat(lbls, " | ")

            if txtStr ~= "" then
                d.text.Color = isPlayerModel(model) and Color_Text or Color3.fromRGB(0, 150, 255)
                d.text.Text = txtStr
                d.text.Position = Vector2.new(screenPos.X, by - 16)
                d.text.Visible = true
            else
                d.text.Visible = false
            end

            if ESP_Weapon then
                d.weaponText.Color = isPlayerModel(model) and Color_Text or Color3.fromRGB(0, 150, 255)
                d.weaponText.Text = cachedWeapons[model] or "None"
                d.weaponText.Position = Vector2.new(screenPos.X, by + h)
                d.weaponText.Visible = true
            else
                d.weaponText.Visible = false
            end

            if ESP_Skeleton then
                for _, sk in ipairs(d.skeletonLines) do
                    local pA = model:FindFirstChild(sk.a)
                    local pB = model:FindFirstChild(sk.b)
                    if pA and pB then
                        local posA, visA = Camera:WorldToViewportPoint(pA.Position)
                        local posB, visB = Camera:WorldToViewportPoint(pB.Position)
                        if visA and visB then
                            sk.line.From = Vector2.new(posA.X, posA.Y)
                            sk.line.To = Vector2.new(posB.X, posB.Y)
                            sk.line.Color = Color_Skeleton
                            sk.line.Visible = true
                        else
                            sk.line.Visible = false
                        end
                    else
                        sk.line.Visible = false
                    end
                end
            else
                for _, sk in ipairs(d.skeletonLines) do sk.line.Visible = false end
            end
        end
    end
end)

_G.OnToggle("Enable ESP", function(s) ESP_Master = s end)
_G.OnToggle("Box Esp", function(s) ESP_Box = s end)
_G.OnToggle("Distance Esp", function(s) ESP_Distance = s end)
_G.OnToggle("Player/Bot Esp", function(s) ESP_Type = s end)
_G.OnToggle("Sleeper Check", function(s) ESP_SleeperCheck = s end)
_G.OnToggle("Weapon Esp", function(s) ESP_Weapon = s end)
_G.OnToggle("Skeleton Esp", function(s) ESP_Skeleton = s end)

_G.OnColorPicker("Box Color", function(c) Color_Box = c end)
_G.OnColorPicker("Skeleton Color", function(c) Color_Skeleton = c end)
_G.OnColorPicker("Text Color", function(c) Color_Text = c end)

--//==================================================
--// ARMOR ESP
--//==================================================

local ArmorESP_Enabled = false
local ArmorFOV_Radius = 220

-- FOV circle for Armor ESP (green, separate from the aimbot purple circle)
local ArmorFOVCircle = Drawing.new("Circle")
ArmorFOVCircle.Visible = false
ArmorFOVCircle.Thickness = 1.5
ArmorFOVCircle.Color = Color3.fromRGB(0, 255, 0)
ArmorFOVCircle.Filled = false
ArmorFOVCircle.NumSides = 64

-- Line drawn from screen center to the closest armored target
local ArmorSnapLine = Drawing.new("Line")
ArmorSnapLine.Visible = false
ArmorSnapLine.Thickness = 1.5
ArmorSnapLine.Color = Color3.fromRGB(255, 75, 125)

-- Find the closest model with an "Armor" child that is inside the FOV radius
local function getClosestArmoredTarget()
    local closest = nil
    local closestDist = math.huge
    local viewCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, m in ipairs(Workspace:GetChildren()) do
        if m:IsA("Model") and m:FindFirstChild("Armor") then
            local head = m:FindFirstChild("Head")
            if head then
                local sp, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local screenDist = (Vector2.new(sp.X, sp.Y) - viewCenter).Magnitude
                    if screenDist <= ArmorFOV_Radius and screenDist < closestDist then
                        closestDist = screenDist
                        closest = m
                    end
                end
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    local viewCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    ArmorFOVCircle.Position = viewCenter
    ArmorFOVCircle.Radius = ArmorFOV_Radius
    ArmorFOVCircle.Visible = ArmorESP_Enabled

    if not ArmorESP_Enabled then
        ArmorSnapLine.Visible = false
        return
    end

    local target = getClosestArmoredTarget()
    if target then
        local head = target:FindFirstChild("Head")
        if head then
            local sp, onScreen = Camera:WorldToViewportPoint(head.Position)
            if onScreen then
                ArmorSnapLine.From = viewCenter
                ArmorSnapLine.To   = Vector2.new(sp.X, sp.Y)
                ArmorSnapLine.Visible = true
                return
            end
        end
    end
    ArmorSnapLine.Visible = false
end)

_G.OnToggle("Armor Esp", function(s) ArmorESP_Enabled = s end)
_G.OnSlider("Fov Slider", function(v) ArmorFOV_Radius = v end)

--//==================================================
--// ADVANCED MATERIAL CHAMS SYSTEM
--//==================================================

local MatState = {
    Enabled    = false,
    Material   = "ForceField",
    TeamCheck  = false,
    SeeThrough = true,
    Color      = Color3.fromRGB(120, 200, 255),
}

local MatApplied = {}

local MatPresets = {
    ["ForceField"] = { material = Enum.Material.ForceField,  reflectance = 0,   transparency = 0,   tint = true  },
    ["Neon"]       = { material = Enum.Material.Neon,         reflectance = 0,   transparency = 0,   tint = true  },
    ["Glass"]      = { material = Enum.Material.Glass,        reflectance = 0.3, transparency = 0.4, tint = true  },
    ["Marble"]     = { material = Enum.Material.Marble,       reflectance = 0,   transparency = 0,   tint = false },
    ["Foil"]       = { material = Enum.Material.Foil,         reflectance = 0.4, transparency = 0,   tint = false },
    ["Metal"]      = { material = Enum.Material.DiamondPlate, reflectance = 0.5, transparency = 0,   tint = false },
    ["Wood"]       = { material = Enum.Material.WoodPlanks,   reflectance = 0,   transparency = 0,   tint = false },
    ["Ice"]        = { material = Enum.Material.Ice,          reflectance = 0.2, transparency = 0.2, tint = true  },
}

local function isBodyPart(inst)
    return inst:IsA("BasePart") and inst.Name ~= "HumanoidRootPart"
end

local function restoreMatPlayer(plr)
    local rec = MatApplied[plr]
    if not rec then return end
    for part, orig in pairs(rec.originals) do
        if part and part.Parent then
            part.Material     = orig.Material
            part.Reflectance  = orig.Reflectance
            part.Color        = orig.Color
            part.Transparency = orig.Transparency
            if orig.TextureID ~= nil and part:IsA("MeshPart") then
                part.TextureID = orig.TextureID
            end
        end
    end
    for inst, parentRef in pairs(rec.hidden) do
        if inst then pcall(function() inst.Parent = parentRef end) end
    end
    if rec.highlight then pcall(function() rec.highlight:Destroy() end) end
    MatApplied[plr] = nil
end

local function hideOverlay(rec, inst)
    if rec.hidden[inst] == nil and inst.Parent then
        rec.hidden[inst] = inst.Parent
        pcall(function() inst.Parent = nil end)
    end
end

local function applyMatPlayer(plr)
    if plr == LocalPlayer then return end
    if MatState.TeamCheck and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then
        restoreMatPlayer(plr)
        return
    end

    local char = plr.Character
    if not char then return end

    local preset = MatPresets[MatState.Material]
    if not preset then return end

    local rec = MatApplied[plr]
    if not rec then
        rec = { originals = {}, hidden = {}, highlight = nil }
        MatApplied[plr] = rec
    end

    for _, inst in ipairs(char:GetDescendants()) do
        if isBodyPart(inst) then
            local part = inst
            if not rec.originals[part] then
                rec.originals[part] = {
                    Material     = part.Material,
                    Reflectance  = part.Reflectance,
                    Color        = part.Color,
                    Transparency = part.Transparency,
                    TextureID    = part:IsA("MeshPart") and part.TextureID or nil,
                }
            end
            part.Material     = preset.material
            part.Reflectance  = preset.reflectance
            part.Transparency = preset.transparency or 0
            if part:IsA("MeshPart") then part.TextureID = "" end
            if preset.tint then part.Color = MatState.Color end
        elseif inst:IsA("Shirt") or inst:IsA("Pants") or inst:IsA("ShirtGraphic")
            or inst:IsA("Decal") or inst:IsA("Texture") or inst:IsA("SurfaceAppearance") then
            hideOverlay(rec, inst)
        end
    end

    if MatState.SeeThrough then
        if not rec.highlight or not rec.highlight.Parent then
            local hl = Instance.new("Highlight")
            hl.Name = "MatChamsGlow"
            hl.FillTransparency = 1
            hl.OutlineTransparency = 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Adornee = char
            pcall(function() hl.Parent = game:GetService("CoreGui") end)
            if not hl.Parent then hl.Parent = char end
            rec.highlight = hl
        end
        rec.highlight.Adornee = char
        rec.highlight.OutlineColor = MatState.Color
    elseif rec.highlight then
        rec.highlight:Destroy()
        rec.highlight = nil
    end
end

local function restoreAllMat()
    for plr in pairs(MatApplied) do restoreMatPlayer(plr) end
end

local function refreshAllMat()
    if not MatState.Enabled then restoreAllMat() return end
    for _, plr in ipairs(Players:GetPlayers()) do applyMatPlayer(plr) end
end

RunService.RenderStepped:Connect(function()
    if not MatState.Enabled then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then applyMatPlayer(plr) end
    end
end)

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(0.3)
        if MatState.Enabled then applyMatPlayer(plr) end
    end)
end)
Players.PlayerRemoving:Connect(function(plr) restoreMatPlayer(plr) end)

_G.OnToggle("Enable Material Chams", function(v) MatState.Enabled = v refreshAllMat() end)
_G.OnDropdown("Chams Material", function(sel)
    if MatPresets[sel] then restoreAllMat() MatState.Material = sel refreshAllMat() end
end)
_G.OnColorPicker("Chams Color", function(c) MatState.Color = c refreshAllMat() end)
_G.OnToggle("Chams See Through", function(v) MatState.SeeThrough = v refreshAllMat() end)
_G.OnToggle("Chams Team Check", function(v) MatState.TeamCheck = v refreshAllMat() end)

--//==================================================
--// ITEM, CORPSE, RAID & AIRDROP ESP
--//==================================================

local ItemESP_Enabled = false
local CorpseESP_Enabled = false
local RaidESP_Enabled = false
local AirdropESP_Enabled = false

local ItemCache = {}
local CorpseCache = {}
local RaidCache = {}
local AirdropCache = {}

-- Helper: make a simple ESP text drawing
local function makeESPText(label, color)
    local t = Drawing.new("Text")
    t.Text = label
    t.Size = 14
    t.Center = true
    t.Outline = true
    t.OutlineColor = Color3.new(0, 0, 0)
    t.Color = color
    t.Visible = false
    return t
end

local function getESPAnchor(object)
    if object:IsA("BasePart") then return object end
    if object:IsA("Model") and object.PrimaryPart then return object.PrimaryPart end
    return object:FindFirstChildWhichIsA("BasePart", true)
end

-- ---- ITEM ESP ----
-- Items are models that have a Union, a Display, AND a Part child.
local function registerItem(m)
    if ItemCache[m] then return end
    local hasUnion   = m:FindFirstChild("Union")
    local hasDisplay = m:FindFirstChild("Display")
    local hasPart    = m:FindFirstChild("Part")
    if not hasUnion or not hasDisplay or not hasPart then return end
    local anchor = getESPAnchor(hasUnion or hasDisplay or hasPart)
    if not anchor then return end
    local txt = makeESPText("Item", Color3.fromRGB(255, 215, 0))
    ItemCache[m] = { drawing = txt, part = anchor }
    m.Destroying:Connect(function()
        if ItemCache[m] then
            pcall(function() ItemCache[m].drawing:Remove() end)
            ItemCache[m] = nil
        end
    end)
end

local function scanItems()
    for _, m in ipairs(Workspace:GetChildren()) do
        if m:IsA("Model") then registerItem(m) end
    end
end

Workspace.ChildAdded:Connect(function(c)
    if c:IsA("Model") then task.wait(0.05); registerItem(c) end
end)

-- ---- CORPSE ESP ----
-- Corpses are models with exactly 2 BasePart children — one Fabric, one Metal.
local function isCorpse(m)
    local parts = {}
    for _, c in ipairs(m:GetChildren()) do
        if c:IsA("BasePart") then table.insert(parts, c) end
    end
    if #parts ~= 2 then return false end
    local m1, m2 = parts[1].Material, parts[2].Material
    return (m1 == Enum.Material.Fabric and m2 == Enum.Material.Metal)
        or (m1 == Enum.Material.Metal  and m2 == Enum.Material.Fabric)
end

local function registerCorpse(m)
    if CorpseCache[m] then return end
    if not isCorpse(m) then return end
    local txt = makeESPText("Corpse", Color3.fromRGB(255, 75, 75))
    CorpseCache[m] = { drawing = txt, model = m }
    m.Destroying:Connect(function()
        if CorpseCache[m] then
            pcall(function() CorpseCache[m].drawing:Remove() end)
            CorpseCache[m] = nil
        end
    end)
end

local function scanCorpses()
    for _, m in ipairs(Workspace:GetChildren()) do
        if m:IsA("Model") then registerCorpse(m) end
    end
end

Workspace.ChildAdded:Connect(function(c)
    if c:IsA("Model") then task.wait(0.05); registerCorpse(c) end
end)

-- ---- AIRDROP ESP ----
-- Airdrops are models that contain a child named "Crates" or "Cables".
local function registerAirdrop(m)
    if AirdropCache[m] then return end
    if not m or not m.Parent then return end
    local container = m:FindFirstChild("Crates") or m:FindFirstChild("Cables")
    local anchor = container and getESPAnchor(container)
    if not anchor then return end
    local txt = makeESPText("Airdrop", Color3.fromRGB(255, 255, 0))
    AirdropCache[m] = { drawing = txt, part = anchor }
    m.Destroying:Connect(function()
        if AirdropCache[m] then
            pcall(function() AirdropCache[m].drawing:Remove() end)
            AirdropCache[m] = nil
        end
    end)
end

local function scanAirdrops()
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") then registerAirdrop(model) end
    end
end

Workspace.ChildAdded:Connect(function(c)
    if c:IsA("Model") then task.wait(0.05); registerAirdrop(c) end
end)

-- ---- RAID ESP ----
-- Triggered by explosion sounds. Entries expire after 300 seconds.
local hitSoundNames = { Explosion = true, Explosion_Muffled = true }
local function registerSound(sound)
    sound.Played:Connect(function()
        if RaidESP_Enabled and sound.Parent and sound.Parent:IsA("BasePart") then
            local txt = makeESPText("Raid", Color3.fromRGB(255, 75, 125))
            table.insert(RaidCache, { text = txt, position = sound.Parent.Position, startTime = tick() })
        end
    end)
end

for _, desc in ipairs(Workspace:GetDescendants()) do
    if desc:IsA("Sound") and hitSoundNames[desc.Name] then registerSound(desc) end
end
Workspace.DescendantAdded:Connect(function(desc)
    if desc:IsA("Sound") and hitSoundNames[desc.Name] then registerSound(desc) end
end)

-- ---- TOGGLE HANDLERS ----
_G.OnToggle("Item ESP", function(s)
    ItemESP_Enabled = s
    if s then
        scanItems()
    else
        for _, i in pairs(ItemCache) do pcall(function() i.drawing:Remove() end) end
        ItemCache = {}
    end
end)
_G.OnToggle("Corpse ESP", function(s)
    CorpseESP_Enabled = s
    if s then
        scanCorpses()
    else
        for _, c in pairs(CorpseCache) do pcall(function() c.drawing:Remove() end) end
        CorpseCache = {}
    end
end)
_G.OnToggle("Raid ESP", function(s)
    RaidESP_Enabled = s
    if not s then
        for _, r in pairs(RaidCache) do pcall(function() r.text:Remove() end) end
        RaidCache = {}
    end
end)
_G.OnToggle("Airdrop ESP", function(s)
    AirdropESP_Enabled = s
    if s then
        scanAirdrops()
    else
        for _, a in pairs(AirdropCache) do pcall(function() a.drawing:Remove() end) end
        AirdropCache = {}
    end
end)

-- ---- RENDER LOOP (all four in one connection) ----
local worldESPScanElapsed = 0
RunService.RenderStepped:Connect(function(dt)
    if ItemESP_Enabled or CorpseESP_Enabled or AirdropESP_Enabled then
        worldESPScanElapsed = worldESPScanElapsed + dt
        if worldESPScanElapsed >= 1 then
            worldESPScanElapsed = 0
            if ItemESP_Enabled then scanItems() end
            if CorpseESP_Enabled then scanCorpses() end
            if AirdropESP_Enabled then scanAirdrops() end
        end
    else
        worldESPScanElapsed = 0
    end

    -- Item ESP
    if ItemESP_Enabled then
        for m, d in pairs(ItemCache) do
            if d.part and d.part.Parent then
                local sp, vis = Camera:WorldToViewportPoint(d.part.Position)
                d.drawing.Visible = vis
                if vis then d.drawing.Position = Vector2.new(sp.X, sp.Y - 20) end
            else
                pcall(function() d.drawing:Remove() end)
                ItemCache[m] = nil
            end
        end
    else
        for _, d in pairs(ItemCache) do d.drawing.Visible = false end
    end

    -- Corpse ESP
    if CorpseESP_Enabled then
        for m, d in pairs(CorpseCache) do
            local anchor = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
            if anchor then
                local sp, vis = Camera:WorldToViewportPoint(anchor.Position)
                d.drawing.Visible = vis
                if vis then d.drawing.Position = Vector2.new(sp.X, sp.Y - 20) end
            else
                d.drawing.Visible = false
            end
        end
    else
        for _, d in pairs(CorpseCache) do d.drawing.Visible = false end
    end

    -- Raid ESP — project, show distance+elapsed, expire after 300 s
    if RaidESP_Enabled then
        for i = #RaidCache, 1, -1 do
            local entry = RaidCache[i]
            local elapsed = tick() - entry.startTime
            if elapsed > 300 then
                pcall(function() entry.text:Remove() end)
                table.remove(RaidCache, i)
            else
                local sp, vis = Camera:WorldToViewportPoint(entry.position)
                entry.text.Visible = vis
                if vis then
                    local dist = math.floor((entry.position - Camera.CFrame.Position).Magnitude)
                    entry.text.Text = string.format("Raid | %dm | %ds", dist, math.floor(elapsed))
                    entry.text.Position = Vector2.new(sp.X, sp.Y)
                end
            end
        end
    else
        for _, r in pairs(RaidCache) do r.text.Visible = false end
    end

    -- Airdrop ESP — render cached drops and discard stale anchors
    if AirdropESP_Enabled then
        for m, d in pairs(AirdropCache) do
            if not m.Parent or not d.part or not d.part.Parent then
                pcall(function() d.drawing:Remove() end)
                AirdropCache[m] = nil
            else
                local sp, vis = Camera:WorldToViewportPoint(d.part.Position)
                d.drawing.Visible = vis
                if vis then d.drawing.Position = Vector2.new(sp.X, sp.Y - 20) end
            end
        end
    else
        for _, d in pairs(AirdropCache) do d.drawing.Visible = false end
    end
end)
--//==================================================
--// ORE ESP
--//==================================================

local OreESPConfig = { Stone = false, Iron = false, Nitrate = false, ShowDistance = false, RenderDistance = 750 }
local oreCache = {}

local oreColors = {
    Stone = { Color3.fromRGB(72, 72, 72) },
    Iron = { Color3.fromRGB(72, 72, 72), Color3.fromRGB(199, 172, 120) },
    Nitrate = { Color3.fromRGB(248, 248, 248), Color3.fromRGB(72, 72, 72) }
}
local oreLabelColors = {
    Stone = Color3.fromRGB(160, 160, 160),
    Iron = Color3.fromRGB(255, 215, 0),
    Nitrate = Color3.fromRGB(180, 255, 200)
}

local function matchColor(c1, c2)
    return math.abs(c1.R - c2.R) < 0.03 and math.abs(c1.G - c2.G) < 0.03 and math.abs(c1.B - c2.B) < 0.03
end

local function identifyOre(model)
    local meshes = {}
    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("MeshPart") then table.insert(meshes, child) end
    end
    if #meshes == 1 and matchColor(meshes[1].Color, oreColors.Stone[1]) then
        return "Stone", meshes[1]
    elseif #meshes == 2 then
        local c1, c2 = meshes[1].Color, meshes[2].Color
        if (matchColor(c1, oreColors.Iron[1]) and matchColor(c2, oreColors.Iron[2])) or (matchColor(c1, oreColors.Iron[2]) and matchColor(c2, oreColors.Iron[1])) then
            return "Iron", meshes[1]
        elseif (matchColor(c1, oreColors.Nitrate[1]) and matchColor(c2, oreColors.Nitrate[2])) or (matchColor(c1, oreColors.Nitrate[2]) and matchColor(c2, oreColors.Nitrate[1])) then
            return "Nitrate", meshes[1]
        end
    end
    return nil, nil
end

-- Register an ore drawing unconditionally once identified.
-- Visibility is controlled per-frame in RenderStepped based on OreESPConfig flags,
-- so ores that were scanned before the toggle was enabled will still appear.
local function registerOre(m)
    if oreCache[m] then return end
    local oType, oPart = identifyOre(m)
    if not oType then return end
    local txt = Drawing.new("Text")
    txt.Size = 13
    txt.Center = true
    txt.Outline = true
    txt.OutlineColor = Color3.fromRGB(0, 0, 0)
    txt.Color = oreLabelColors[oType]
    txt.Visible = false
    oreCache[m] = { Text = txt, OreType = oType, Part = oPart }
    -- Clean up drawing when the ore model is destroyed
    m.Destroying:Connect(function()
        if oreCache[m] then
            pcall(function() oreCache[m].Text:Remove() end)
            oreCache[m] = nil
        end
    end)
end

task.spawn(function()
    while true do
        for _, m in ipairs(Workspace:GetChildren()) do
            if m:IsA("Model") then registerOre(m) end
        end
        -- Also prune stale entries (destroyed without firing Destroying)
        for model, d in pairs(oreCache) do
            if not model.Parent then
                pcall(function() d.Text:Remove() end)
                oreCache[model] = nil
            end
        end
        task.wait(2)
    end
end)

-- Register newly added workspace children as ores immediately
Workspace.ChildAdded:Connect(function(c)
    if c:IsA("Model") then
        task.wait(0.1) -- brief wait for children to populate
        registerOre(c)
    end
end)

RunService.RenderStepped:Connect(function()
    for model, d in pairs(oreCache) do
        if d.Part and d.Part.Parent then
            local dist = (Camera.CFrame.Position - d.Part.Position).Magnitude
            local screenPos, onScreen = Camera:WorldToViewportPoint(d.Part.Position)
            if onScreen and dist <= OreESPConfig.RenderDistance and OreESPConfig[d.OreType] then
                d.Text.Text = OreESPConfig.ShowDistance and string.format("%s | %.0fm", d.OreType, dist) or d.OreType
                d.Text.Position = Vector2.new(screenPos.X, screenPos.Y)
                d.Text.Visible = true
            else
                d.Text.Visible = false
            end
        else
            d.Text:Remove()
            oreCache[model] = nil
        end
    end
end)

_G.OnToggle("Stone Esp", function(s) OreESPConfig.Stone = s end)
_G.OnToggle("Iron Esp", function(s) OreESPConfig.Iron = s end)
_G.OnToggle("Nitrate Esp", function(s) OreESPConfig.Nitrate = s end)
_G.OnToggle("Show Distance", function(s) OreESPConfig.ShowDistance = s end)
_G.OnSlider("Ore Distance Esp", function(v) OreESPConfig.RenderDistance = v end)

--//==================================================
--// VEHICLE ESP
--//==================================================

local VehicleESP_Config = { ATV = false, Boat = false, Helicopter = false, Trolly = false, Distance = false }
local VehicleESP_Cache = {}

local function getVehicleBlueprints()
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local entities = shared and shared:FindFirstChild("entities")
    local folder = entities and entities:FindFirstChild("vehicles")
    if not folder then return nil end

    local blueprints = {}
    for _, name in ipairs({ "ATV", "Boat", "Helicopter", "Trolly" }) do
        local entry = folder:FindFirstChild(name)
        local blueprint = entry and entry:FindFirstChild("Model")
        if blueprint then blueprints[name] = blueprint end
    end
    return next(blueprints) and blueprints or nil
end

local function matchesVehicle(model, blueprint)
    local childCount = 0
    for _, child in ipairs(blueprint:GetChildren()) do
        childCount = childCount + 1
        if not model:FindFirstChild(child.Name) then return false end
    end
    return childCount > 0
end

local function registerVehicle(model)
    if VehicleESP_Cache[model] then return end
    local blueprints = getVehicleBlueprints()
    if not blueprints then return end
    for name, blueprint in pairs(blueprints) do
        if VehicleESP_Config[name] and matchesVehicle(model, blueprint) then
            local drawing = Drawing.new("Text")
            drawing.Size = 18
            drawing.Color = Color3.fromRGB(0, 255, 0)
            drawing.Center = true
            drawing.Outline = true
            drawing.OutlineColor = Color3.new(0, 0, 0)
            drawing.Visible = false
            VehicleESP_Cache[model] = { Drawing = drawing, Name = name }
            model.Destroying:Connect(function()
                local entry = VehicleESP_Cache[model]
                if entry then
                    pcall(function() entry.Drawing:Remove() end)
                    VehicleESP_Cache[model] = nil
                end
            end)
            return
        end
    end
end

local function anyVehicleESPEnabled()
    return VehicleESP_Config.ATV or VehicleESP_Config.Boat
        or VehicleESP_Config.Helicopter or VehicleESP_Config.Trolly
end

Workspace.ChildAdded:Connect(function(child)
    if child:IsA("Model") then task.defer(registerVehicle, child) end
end)

local vehicleScanElapsed = 0
RunService.RenderStepped:Connect(function(dt)
    if anyVehicleESPEnabled() then
        vehicleScanElapsed = vehicleScanElapsed + dt
        if vehicleScanElapsed >= 2 then
            vehicleScanElapsed = 0
            for _, model in ipairs(Workspace:GetChildren()) do
                if model:IsA("Model") then registerVehicle(model) end
            end
        end
    else
        vehicleScanElapsed = 0
    end

    for model, entry in pairs(VehicleESP_Cache) do
        local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        if not model.Parent then
            pcall(function() entry.Drawing:Remove() end)
            VehicleESP_Cache[model] = nil
        elseif VehicleESP_Config[entry.Name] and primary then
            local screen, visible = Camera:WorldToViewportPoint(primary.Position)
            entry.Drawing.Visible = visible
            if visible then
                local distance = math.floor((primary.Position - Camera.CFrame.Position).Magnitude)
                entry.Drawing.Text = VehicleESP_Config.Distance
                    and string.format("%s | %dm", entry.Name, distance) or entry.Name
                entry.Drawing.Position = Vector2.new(screen.X, screen.Y)
            end
        else
            entry.Drawing.Visible = false
        end
    end
end)

_G.OnToggle("ATV", function(s) VehicleESP_Config.ATV = s end)
_G.OnToggle("Boat", function(s) VehicleESP_Config.Boat = s end)
_G.OnToggle("Helicopter", function(s) VehicleESP_Config.Helicopter = s end)
_G.OnToggle("Trolly", function(s) VehicleESP_Config.Trolly = s end)
_G.OnToggle("Vehicle Distance Esp", function(s) VehicleESP_Config.Distance = s end)

--//==================================================
--// WORLD ENVIRONMENT & LIGHTING MODS
--//==================================================

_G.OnColorPicker("Water Color", function(col) Workspace.Terrain.WaterColor = col end)
_G.OnToggle("Water Reflectance", function(s) Workspace.Terrain.WaterReflectance = s and 1 or 0 end)
_G.OnSlider("Water speed", function(v) Workspace.Terrain.WaterWaveSpeed = v end)
_G.OnSlider("Wave size", function(v) Workspace.Terrain.WaterWaveSize = v end)

_G.OnColorPicker("Cloud Color", function(col) pcall(function() Workspace.Terrain.Clouds.Color = col end) end)
_G.OnSlider("Clouds Cover", function(v) pcall(function() Workspace.Terrain.Clouds.Cover = v end) end)

local originalSkies = {}
for _, child in ipairs(Lighting:GetChildren()) do
    if child:IsA("Sky") then table.insert(originalSkies, child:Clone()) end
end
local currentSkyType = "Default"

_G.OnDropdown("Sky Changer", function(skyType)
    if skyType == currentSkyType then return end
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("Sky") then child:Destroy() end
    end
    if skyType == "Default" then
        for _, sky in ipairs(originalSkies) do sky:Clone().Parent = Lighting end
        currentSkyType = "Default"
        return
    end
    local textures = {
        Magma = "rbxassetid://16468735533", Water = "rbxassetid://17253866105",
        Obsidian = "rbxassetid://17253878595", Galaxy = "rbxassetid://13726625670",
        Void = "rbxassetid://16666915143"
    }
    local tex = textures[skyType]
    if tex then
        local newSky = Instance.new("Sky")
        newSky.Name = "AtomwareSky"
        newSky.SkyboxBk, newSky.SkyboxDn, newSky.SkyboxFt = tex, tex, tex
        newSky.SkyboxLf, newSky.SkyboxRt, newSky.SkyboxUp = tex, tex, tex
        newSky.Parent = Lighting
        currentSkyType = skyType
    end
end)

_G.OnToggle("Shadows", function(s) Lighting.GlobalShadows = s end)
_G.OnToggle("Grass", function(s)
    if sethiddenproperty then
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then pcall(function() sethiddenproperty(terrain, "Decoration", s) end) end
    end
end)
_G.OnToggle("Tree Leaves", function(s)
    local leafNames = { Fir3_Leaves = true, Elm1_Leaves = true, Birch1_Leaves = true }
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("BasePart") and leafNames[desc.Name] then
            desc.Transparency = s and 0 or 1
            desc.CanCollide = s
        end
    end
end)

local BrightNightEnabled = false
-- Time-aware Bright Night: only boosts exposure during night hours (18:30 – 06:30).
-- Gradually ramps up/down at dusk and dawn instead of a flat override.
local BrightNight_MaxExposure = 2.5
local BrightNight_NightStart  = 18.5  -- 18:30
local BrightNight_DawnEnd     = 6.5   -- 06:30
local BrightNight_OriginalExposure = Lighting.ExposureCompensation

local function getBrightNightHour()
    local ok, tod = pcall(function() return Lighting.TimeOfDay end)
    if not ok then return 12 end
    local h, m, s = string.match(tod, "(%d+):(%d+):(%d+)")
    return tonumber(h) + tonumber(m) / 60 + (tonumber(s) or 0) / 3600
end

_G.OnToggle("Bright Night", function(s)
    BrightNightEnabled = s
    if s then
        BrightNight_OriginalExposure = Lighting.ExposureCompensation
    else
        Lighting.ExposureCompensation = BrightNight_OriginalExposure
    end
end)
RunService.RenderStepped:Connect(function()
    if not BrightNightEnabled then return end
    local hour = getBrightNightHour()
    local exposure = 0
    -- Treat night as one interval from dusk through the following dawn.
    local nightHour = hour < BrightNight_DawnEnd and hour + 24 or hour
    local dawnHour = BrightNight_DawnEnd + 24
    if hour >= BrightNight_NightStart or hour < BrightNight_DawnEnd then
        local duskFade = math.clamp((nightHour - BrightNight_NightStart) / 3, 0, 1)
        local dawnFade = math.clamp((dawnHour - nightHour) / 3, 0, 1)
        exposure = BrightNight_MaxExposure * math.min(duskFade, dawnFade)
    end
    Lighting.ExposureCompensation = exposure
end)

local stimEffect = Lighting:FindFirstChild("StimEffect") or Instance.new("ColorCorrectionEffect", Lighting)
stimEffect.Name = "StimEffect"
stimEffect.Enabled = false

_G.OnToggle("Stim Effect", function(s) stimEffect.Enabled = s end)
_G.OnColorPicker("TintColor", function(col) stimEffect.TintColor = col end)
_G.OnSlider("Brightness", function(v) stimEffect.Brightness = v end)
_G.OnSlider("Contrast", function(v) stimEffect.Contrast = v end)
_G.OnSlider("Saturation", function(v) stimEffect.Saturation = v end)

--//==================================================
--// PLAYER MODS (X-Ray, Zoom, Hit Sounds, Trails, Chams, FreeCam)
--//==================================================

local XRayEnabled = false
local originalTransparencies = {}
local xrayMaterials = { Enum.Material.Cobblestone, Enum.Material.WoodPlanks, Enum.Material.Metal, Enum.Material.CorrodedMetal }

local function setXRay(state)
    XRayEnabled = state
    for _, m in ipairs(Workspace:GetChildren()) do
        if m:IsA("Model") then
            for _, p in ipairs(m:GetDescendants()) do
                if p:IsA("BasePart") and table.find(xrayMaterials, p.Material) then
                    if state then
                        if not originalTransparencies[p] then originalTransparencies[p] = p.Transparency end
                        p.Transparency = 0.5
                    elseif originalTransparencies[p] ~= nil then
                        p.Transparency = originalTransparencies[p]
                    end
                end
            end
        end
    end
end

_G.OnToggle("Xray Pressed", function() setXRay(not XRayEnabled) end)
_G.OnToggle("X-Ray Active", function(s) setXRay(s) end)

local defaultFOV = 70
local isZooming = false
local zoomKeyHeld = false
local zoomToggleEnabled = false
-- Store the active zoom key so rebinding actually takes effect
local zoomKey = Enum.KeyCode.X

local function updateZoomState()
    isZooming = zoomKeyHeld or zoomToggleEnabled
    Camera.FieldOfView = isZooming and 20 or defaultFOV
end

_G.OnSlider("FOV Changer", function(v)
    defaultFOV = v
    if not isZooming then Camera.FieldOfView = v end
end)
_G.OnToggle("Zoom Active", function(state)
    zoomToggleEnabled = state
    updateZoomState()
end)
_G.OnKeybind("Zoom", function(keyName)
    if Enum.KeyCode[keyName] then
        zoomKey = Enum.KeyCode[keyName]
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == zoomKey then
        zoomKeyHeld = true
        updateZoomState()
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == zoomKey then
        zoomKeyHeld = false
        updateZoomState()
    end
end)

local hitSoundAudioIds = {
    Default = "rbxassetid://9119561046", Rust = "rbxassetid://5043539486",
    Gamesense = "rbxassetid://4817809188", Magic = "rbxassetid://182765513",
    Firework = "rbxassetid://269146157", Lazer = "rbxassetid://360661189",
    Pop = "rbxassetid://127231141534262", Zap = "rbxassetid://9119594928"
}
local currentHitSound = "Default"
local currentHitVolume = 1

_G.OnDropdown("Hit sound", function(sndName)
    local changed = sndName ~= currentHitSound
    currentHitSound = sndName
    local snd = SoundService:FindFirstChild("PlayerHitHeadshot")
    if snd then
        snd.SoundId = hitSoundAudioIds[sndName] or hitSoundAudioIds.Default
        if changed then snd:Play() end
    end
end)
_G.OnSlider("Hit sound Volume", function(vol)
    currentHitVolume = vol
    local snd = SoundService:FindFirstChild("PlayerHitHeadshot")
    if snd then snd.Volume = vol end
end)

--//==================================================
--// ARM CHAMS (FPSArms parts: hands + lower arms)
--//==================================================

local ArmChams = {
    Enabled  = false,
    Color    = Color3.fromRGB(255, 255, 255),
    Material = "ForceField",
}
local ArmChams_OrigMaterial = {}  -- [part] = original material
local ArmChams_OrigColor    = {}  -- [part] = original color

-- Paths to every FPSArms BasePart we care about (matches old script exactly)
local armPartPaths = {
    {"Const","Ignore","FPSArms","RightHand"},
    {"Const","Ignore","FPSArms","RightLowerArm"},
    {"Const","Ignore","FPSArms","LeftLowerArm"},
    {"Const","Ignore","FPSArms","LeftHand"},
    {"Const","Ignore","FPSArms","Fake","c_RightLowerArm"},
    {"Const","Ignore","FPSArms","Fake","c_LeftLowerArm"},
}

local function armFindPath(paths)
    local cur = Workspace
    for _, name in ipairs(paths) do
        cur = cur:FindFirstChild(name)
        if not cur then return nil end
    end
    return cur
end

local function armGetParts()
    local parts = {}
    for _, paths in ipairs(armPartPaths) do
        local p = armFindPath(paths)
        if p and p:IsA("BasePart") then
            table.insert(parts, p)
        end
    end
    return parts
end

local function armRecacheOriginals()
    ArmChams_OrigMaterial = {}
    ArmChams_OrigColor    = {}
    for _, p in ipairs(armGetParts()) do
        ArmChams_OrigMaterial[p] = p.Material
        ArmChams_OrigColor[p]    = p.Color
    end
end

local function armApply()
    local mat = pcall(function() return Enum.Material[ArmChams.Material] end)
        and Enum.Material[ArmChams.Material] or Enum.Material.ForceField
    for _, p in ipairs(armGetParts()) do
        if p and p.Parent then
            p.Material = mat
            p.Color    = ArmChams.Color
        end
    end
end

local function armRestore()
    for _, p in ipairs(armGetParts()) do
        if p and p.Parent then
            p.Material = ArmChams_OrigMaterial[p] or Enum.Material.Plastic
            p.Color    = ArmChams_OrigColor[p]    or Color3.fromRGB(163, 162, 165)
        end
    end
end

-- Re-cache whenever FPSArms children change (weapon switches, etc.)
local fpsArmsFolder = Workspace:FindFirstChild("Const")
    and Workspace.Const:FindFirstChild("Ignore")
    and Workspace.Const.Ignore:FindFirstChild("FPSArms")

if fpsArmsFolder then
    fpsArmsFolder.ChildAdded:Connect(function()
        task.wait(0.2)
        armRecacheOriginals()
        if ArmChams.Enabled then armApply() end
    end)
    fpsArmsFolder.ChildRemoved:Connect(function()
        task.wait(0.1)
        armRecacheOriginals()
    end)
end

-- Heartbeat loop keeps chams applied even when game scripts try to reset material
RunService.Heartbeat:Connect(function()
    if not ArmChams.Enabled then return end
    local mat = pcall(function() return Enum.Material[ArmChams.Material] end)
        and Enum.Material[ArmChams.Material] or Enum.Material.ForceField
    for _, p in ipairs(armGetParts()) do
        if p and p.Parent then
            p.Material = mat
            p.Color    = ArmChams.Color
        end
    end
end)

armRecacheOriginals()

_G.OnDropdown("Hand Cham Material", function(v)
    if v == "Default" then
        ArmChams.Enabled  = false
        ArmChams.Material = "Default"
        armRestore()
    else
        ArmChams.Enabled  = true
        ArmChams.Material = v
        armRecacheOriginals()
        armApply()
    end
end)
_G.OnColorPicker("Hand cham color", function(c)
    ArmChams.Color = c
    if ArmChams.Enabled then armApply() end
end)

--//==================================================
--// WEAPON CHAMS (ReplicatedStorage.HandModels parts)
--//==================================================

local WeaponChams = {
    Enabled  = false,
    Color    = Color3.fromRGB(255, 255, 255),
    Material = "ForceField",
}
local WeaponChams_OrigMaterial = {}  -- [part] = original material
local WeaponChams_OrigColor    = {}  -- [part] = original color

local HandModelsFolder = nil
pcall(function()
    HandModelsFolder = ReplicatedStorage:WaitForChild("HandModels", 5)
end)

local function weaponGetParts()
    local parts = {}
    if not HandModelsFolder then return parts end
    for _, child in ipairs(HandModelsFolder:GetChildren()) do
        if child:IsA("Model") then
            for _, p in ipairs(child:GetDescendants()) do
                if p:IsA("BasePart") then
                    table.insert(parts, p)
                end
            end
        end
    end
    return parts
end

local function weaponRecacheOriginals()
    WeaponChams_OrigMaterial = {}
    WeaponChams_OrigColor    = {}
    for _, p in ipairs(weaponGetParts()) do
        WeaponChams_OrigMaterial[p] = p.Material
        WeaponChams_OrigColor[p]    = p.Color
    end
end

local function weaponApply()
    local mat = pcall(function() return Enum.Material[WeaponChams.Material] end)
        and Enum.Material[WeaponChams.Material] or Enum.Material.ForceField
    for _, p in ipairs(weaponGetParts()) do
        if p and p.Parent then
            p.Material = mat
            p.Color    = WeaponChams.Color
        end
    end
end

local function weaponRestore()
    for _, p in ipairs(weaponGetParts()) do
        if p and p.Parent then
            p.Material = WeaponChams_OrigMaterial[p] or Enum.Material.Plastic
            p.Color    = WeaponChams_OrigColor[p]    or Color3.fromRGB(163, 162, 165)
        end
    end
end

-- Re-apply when a new weapon model is loaded into HandModels
if HandModelsFolder then
    HandModelsFolder.ChildAdded:Connect(function()
        task.wait(0.5)
        weaponRecacheOriginals()
        if WeaponChams.Enabled then weaponApply() end
    end)
end

weaponRecacheOriginals()

_G.OnDropdown("Weapon Cham Material", function(v)
    if v == "Default" then
        WeaponChams.Enabled  = false
        WeaponChams.Material = "Default"
        weaponRestore()
    else
        WeaponChams.Enabled  = true
        WeaponChams.Material = v
        weaponRecacheOriginals()
        weaponApply()
    end
end)
_G.OnColorPicker("Weapon Cham Color", function(c)
    WeaponChams.Color = c
    if WeaponChams.Enabled then weaponApply() end
end)

--//==================================================
--// ENHANCED BULLET & PROJECTILE TRACERS
-- Covers: Bullet, BlueBullet, Projectile, Rocket, Missile, Grenade, Arrow
-- Uses Neon material, validates distance, skips local player's own arrows
--//==================================================

local TracerBullet = {
    Enabled   = false,
    Color     = Color3.fromRGB(255, 255, 255),
    Thickness = 0.2,
    Length    = 10,
    Lifetime  = 0.1,
}

-- Names of projectiles we trace (from old script exactly)
local tracerProjectileNames = {
    Bullet = true, BlueBullet = true, Projectile = true,
    Rocket = true, Missile = true, Grenade = true,
}

-- Returns true if this is the local player's own FPSArms arrow (skip it)
local function isLocalArrow(obj)
    local ok, result = pcall(function()
        local fps = Workspace:FindFirstChild("Const")
            and Workspace.Const:FindFirstChild("Ignore")
            and Workspace.Const.Ignore:FindFirstChild("FPSArms")
        if fps then
            local hm = fps:FindFirstChild("HandModel")
            return hm and hm:FindFirstChild("Arrow") == obj
        end
        return false
    end)
    return ok and result
end

local function createTracer(proj)
    -- Don't trace our own arrows
    if proj.Name == "Arrow" and isLocalArrow(proj) then return end

    local lastPos = proj.Position or proj.CFrame.Position
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not TracerBullet.Enabled or not proj or not proj.Parent then
            conn:Disconnect()
            return
        end
        if proj.Name == "Arrow" and isLocalArrow(proj) then
            conn:Disconnect()
            return
        end

        local currentPos = proj.Position or proj.CFrame.Position
        local distance = (currentPos - lastPos).Magnitude

        -- Only draw if moved a meaningful amount but not teleported (sanity cap 500)
        if distance > 0.5 and distance < 500 then
            local beam = Instance.new("Part")
            beam.Anchored    = true
            beam.CanCollide  = false
            beam.CanQuery    = false
            beam.CanTouch    = false
            beam.Size        = Vector3.new(TracerBullet.Thickness, TracerBullet.Thickness, distance)
            beam.CFrame      = CFrame.new(lastPos, currentPos) * CFrame.new(0, 0, -distance / 2)
            beam.Color       = TracerBullet.Color
            beam.Material    = Enum.Material.Neon  -- Neon, not ForceField (matches old script)
            beam.Transparency = 0
            beam.Parent      = Workspace
            Debris:AddItem(beam, TracerBullet.Lifetime)
        end
        lastPos = currentPos
    end)
end

Workspace.DescendantAdded:Connect(function(desc)
    if desc:IsDescendantOf(ReplicatedStorage) then return end
    task.wait()  -- one frame for position to initialise
    if not TracerBullet.Enabled then return end

    if tracerProjectileNames[desc.Name] then
        createTracer(desc)
        return
    end
    -- Enemy arrows (not local FPSArms arrow)
    if desc.Name == "Arrow" and not isLocalArrow(desc) then
        createTracer(desc)
    end
end)

_G.OnToggle("Bullet Trail", function(s) TracerBullet.Enabled = s end)
_G.OnColorPicker("Bullet Trail Color", function(c) TracerBullet.Color = c end)
_G.OnSlider("Trail Thickness", function(v) TracerBullet.Thickness = v end)
_G.OnSlider("Bullet Trail Length", function(v) TracerBullet.Length = v end)
_G.OnSlider("Trail LifeTime", function(v) TracerBullet.Lifetime = v end)

-- Arrow Trail — modifies the Bow arrow's built-in Trail object in ReplicatedStorage
_G.OnColorPicker("Arrow Trailcolor", function(c)
    local ok, arrow = pcall(function() return ReplicatedStorage:WaitForChild("Arrow", 2) end)
    if ok and arrow then
        local trail = arrow:FindFirstChild("Trail")
        if trail then pcall(function() trail.Color = ColorSequence.new(c) end) end
    end
end)
_G.OnSlider("Arrow Trail lifespan", function(v)
    local ok, arrow = pcall(function() return ReplicatedStorage:WaitForChild("Arrow", 2) end)
    if ok and arrow then
        local trail = arrow:FindFirstChild("Trail")
        if trail then pcall(function() trail.Lifetime = v end) end
    end
end)

--//==================================================
--// HITMARKER + HIT SOUND
-- Triggers on any Sound whose name contains "head" firing/being added.
-- hookfunction is wrapped in pcall — falls back to DescendantAdded only.
--//==================================================

local HitmarkerConfig = {
    Enabled   = false,
    Color     = Color3.fromRGB(255, 255, 255),
    Thickness = 2,
    Size      = 20,
    Duration  = 0.3,
    Active    = false,
    Timer     = 0,
}

local HitSoundConfig = {
    Enabled  = false,
    SoundId  = "rbxassetid://4764109000",
    Volume   = 1,
    Pitch    = 1,
}

-- Four corner lines forming an X hitmarker (matches old script exactly)
local HitmarkerLines = {
    Drawing.new("Line"),
    Drawing.new("Line"),
    Drawing.new("Line"),
    Drawing.new("Line"),
}
for _, line in ipairs(HitmarkerLines) do
    line.Visible   = false
    line.Color     = HitmarkerConfig.Color
    line.Thickness = HitmarkerConfig.Thickness
    line.ZIndex    = 999
end

local function playHitSound()
    if not HitSoundConfig.Enabled then return end
    local snd = Instance.new("Sound")
    snd.SoundId = HitSoundConfig.SoundId
    snd.Volume  = HitSoundConfig.Volume
    snd.Pitch   = HitSoundConfig.Pitch
    snd.Parent  = SoundService
    snd:Play()
    Debris:AddItem(snd, 0.5)
end

local function showHitmarker()
    if not HitmarkerConfig.Enabled and not HitSoundConfig.Enabled then return end
    HitmarkerConfig.Active = true
    HitmarkerConfig.Timer  = tick()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local s = HitmarkerConfig.Size

    -- Top-left corner line
    HitmarkerLines[1].From    = Vector2.new(center.X - s, center.Y - s)
    HitmarkerLines[1].To      = Vector2.new(center.X - s/3, center.Y - s/3)
    HitmarkerLines[1].Visible = HitmarkerConfig.Enabled
    -- Bottom-left corner line
    HitmarkerLines[2].From    = Vector2.new(center.X - s, center.Y + s)
    HitmarkerLines[2].To      = Vector2.new(center.X - s/3, center.Y + s/3)
    HitmarkerLines[2].Visible = HitmarkerConfig.Enabled
    -- Top-right corner line
    HitmarkerLines[3].From    = Vector2.new(center.X + s, center.Y - s)
    HitmarkerLines[3].To      = Vector2.new(center.X + s/3, center.Y - s/3)
    HitmarkerLines[3].Visible = HitmarkerConfig.Enabled
    -- Bottom-right corner line
    HitmarkerLines[4].From    = Vector2.new(center.X + s, center.Y + s)
    HitmarkerLines[4].To      = Vector2.new(center.X + s/3, center.Y + s/3)
    HitmarkerLines[4].Visible = HitmarkerConfig.Enabled

    playHitSound()
end

-- Primary trigger: watch for headshot sounds being added to workspace
local function checkHitSound(obj)
    if not HitmarkerConfig.Enabled and not HitSoundConfig.Enabled then return end
    if obj:IsA("Sound") and obj.Name:lower():find("head") then
        showHitmarker()
    end
end
Workspace.DescendantAdded:Connect(checkHitSound)

-- Bonus trigger: hookfunction so we catch sounds that were already in the tree
-- Wrapped in pcall — silently skipped if executor doesn't support hookfunction
pcall(function()
    local oldPlay = Instance.new("Sound").Play
    hookfunction(oldPlay, newcclosure(function(self, ...)
        if (HitmarkerConfig.Enabled or HitSoundConfig.Enabled)
            and self.Name:lower():find("head") then
            showHitmarker()
        end
        return oldPlay(self, ...)
    end))
end)

-- RenderStepped: expire the hitmarker and keep colour/thickness live
RunService.RenderStepped:Connect(function()
    if HitmarkerConfig.Active
        and tick() - HitmarkerConfig.Timer > HitmarkerConfig.Duration then
        HitmarkerConfig.Active = false
        for _, line in ipairs(HitmarkerLines) do
            line.Visible = false
        end
    end
    for _, line in ipairs(HitmarkerLines) do
        line.Color     = HitmarkerConfig.Color
        line.Thickness = HitmarkerConfig.Thickness
    end
end)

_G.OnToggle("Hitmarker Enabled", function(s) HitmarkerConfig.Enabled = s end)
_G.OnColorPicker("Hitmarker Color", function(c) HitmarkerConfig.Color = c end)
_G.OnSlider("Hitmarker Size", function(v) HitmarkerConfig.Size = v end)
_G.OnSlider("Hitmarker Thickness", function(v) HitmarkerConfig.Thickness = v end)
_G.OnSlider("Hitmarker Duration", function(v) HitmarkerConfig.Duration = v end)
_G.OnToggle("Hit Sound Enabled", function(s) HitSoundConfig.Enabled = s end)
_G.OnDropdown("Hit Sound Type", function(id) HitSoundConfig.SoundId = id end)
_G.OnSlider("Hit Sound Volume", function(v) HitSoundConfig.Volume = v end)
_G.OnSlider("Hit Sound Pitch", function(v) HitSoundConfig.Pitch = v end)

--//==================================================
--// OVERRIDE HITBOX
-- Creates a named fake part anchored to each character's HumanoidRootPart
-- each frame — server registers hits against it instead of the real head.
-- Matches old script's approach: inserts a Part + "Fake" marker child.
--//==================================================

local OverrideHitbox = {
    Enabled      = false,
    SizeX        = 3,
    SizeY        = 5,
    SizeZ        = 3,
    Transparency = 0.5,
    Color        = Color3.fromRGB(148, 0, 211),
    Material     = "Neon",
    PartName     = "Head",
}

-- Track every fake part we've spawned so we can clean up cleanly
local OverrideHitboxParts = {}

local function isOHCandidate(model)
    return model ~= LocalPlayer.Character
        and model:IsA("Model")
        and model:FindFirstChild("HumanoidRootPart") ~= nil
end

local function removeOHFromModel(model)
    -- Remove fake marker
    local fake = model:FindFirstChild("Fake")
    if fake then fake:Destroy() end
    -- Remove our injected part (only the one that isn't the real Head)
    for i = #OverrideHitboxParts, 1, -1 do
        local p = OverrideHitboxParts[i]
        if not p or not p.Parent then
            table.remove(OverrideHitboxParts, i)
        elseif p:IsDescendantOf(model) then
            p:Destroy()
            table.remove(OverrideHitboxParts, i)
        end
    end
end

local function createOHForModel(model)
    if not isOHCandidate(model) then return end
    if model:FindFirstChild("Fake") then return end  -- already has one

    local mat = pcall(function() return Enum.Material[OverrideHitbox.Material] end)
        and Enum.Material[OverrideHitbox.Material] or Enum.Material.Neon

    local fakePart = Instance.new("Part")
    fakePart.Name         = OverrideHitbox.PartName
    fakePart.Size         = Vector3.new(OverrideHitbox.SizeX, OverrideHitbox.SizeY, OverrideHitbox.SizeZ)
    fakePart.CFrame       = model.HumanoidRootPart.CFrame
    fakePart.Anchored     = true
    fakePart.CanCollide   = false
    fakePart.Transparency = OverrideHitbox.Transparency
    fakePart.Color        = OverrideHitbox.Color
    fakePart.Material     = mat
    fakePart.Parent       = model
    table.insert(OverrideHitboxParts, fakePart)

    -- Invisible marker so we know we already processed this model
    local marker = Instance.new("Part")
    marker.Name        = "Fake"
    marker.Anchored    = true
    marker.CanCollide  = false
    marker.Transparency = 1
    marker.Size        = Vector3.new(0.1, 0.1, 0.1)
    marker.Parent      = model
    table.insert(OverrideHitboxParts, marker)
end

-- Keep fake part welded to HumanoidRootPart every frame
RunService.Heartbeat:Connect(function()
    if not OverrideHitbox.Enabled then return end
    for _, p in ipairs(OverrideHitboxParts) do
        if p and p.Parent then
            local hrp = p.Parent:FindFirstChild("HumanoidRootPart")
            if hrp and p.Name == OverrideHitbox.PartName then
                p.CFrame = hrp.CFrame
            end
        end
    end
end)

-- Scan loop: create for new models while enabled
task.spawn(function()
    while true do
        task.wait(0.5)
        if OverrideHitbox.Enabled then
            for _, m in ipairs(Workspace:GetChildren()) do
                if isOHCandidate(m) then createOHForModel(m) end
            end
        end
    end
end)

Workspace.ChildAdded:Connect(function(child)
    if OverrideHitbox.Enabled and isOHCandidate(child) then
        task.wait(0.1)
        createOHForModel(child)
    end
end)
Workspace.ChildRemoved:Connect(function(child)
    if child:IsA("Model") then removeOHFromModel(child) end
end)

_G.OnToggle("Override Hitbox", function(s)
    OverrideHitbox.Enabled = s
    if s then
        for _, m in ipairs(Workspace:GetChildren()) do
            if isOHCandidate(m) then createOHForModel(m) end
        end
    else
        -- Remove every fake part we inserted
        for _, p in ipairs(OverrideHitboxParts) do
            if p and p.Parent then pcall(function() p:Destroy() end) end
        end
        OverrideHitboxParts = {}
    end
end)
_G.OnSlider("OH Size X", function(v) OverrideHitbox.SizeX = v end)
_G.OnSlider("OH Size Y", function(v) OverrideHitbox.SizeY = v end)
_G.OnSlider("OH Size Z", function(v) OverrideHitbox.SizeZ = v end)
_G.OnSlider("OH Transparency", function(v) OverrideHitbox.Transparency = v end)
_G.OnColorPicker("OH Color", function(c) OverrideHitbox.Color = c end)
_G.OnDropdown("OH Material", function(v) OverrideHitbox.Material = v end)

--//==================================================
--// FORCE HEADSHOTS
-- Hooks FireServer to redirect any hit body-part string to "Head".
-- Wrapped in pcall+task.spawn — silently skipped if hookfunction unavailable.
--//==================================================

local ForceHeadshots = { Enabled = false }

task.spawn(function()
    pcall(function()
        local oldFireServer
        oldFireServer = hookfunction(
            Instance.new("RemoteEvent").FireServer,
            newcclosure(function(self, ...)
                local args = { ... }
                if ForceHeadshots.Enabled then
                    for _, v in pairs(args) do
                        if type(v) == "table" then
                            for _, val in pairs(v) do
                                if type(val) == "table" then
                                    for key2, val2 in pairs(val) do
                                        if type(val2) == "string" then
                                            local lower = val2:lower()
                                            if lower == "torso" or lower == "uppertorso"
                                                or lower == "lowertorso" or lower == "leftupperarm"
                                                or lower == "rightupperarm" then
                                                val[key2] = "Head"
                                            end
                                        end
                                    end
                                elseif type(val) == "string" then
                                    local lower = val:lower()
                                    if lower == "torso" or lower == "uppertorso"
                                        or lower == "lowertorso" then
                                        -- top-level string args — replace key in parent table
                                        for k2, v2 in pairs(v) do
                                            if v2 == val and lower ~= "head" then
                                                v[k2] = "Head"
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                return oldFireServer(self, ...)
            end)
        )
    end)
end)

_G.OnToggle("Force Headshots", function(s) ForceHeadshots.Enabled = s end)

--//==================================================
--// LONG NECK
-- Offsets the local character's Prism1 (neck/camera pivot) downward,
-- making the camera sit higher relative to the body (looks like long neck).
-- Path: workspace.Const.Ignore.LocalCharacter.Top.Prism1
--//==================================================

local LongNeck = { Enabled = false, Strength = 5 }
local longNeckPart    = nil
local longNeckOrigCF  = nil

local function longNeckGetPart()
    local ok, part = pcall(function()
        return Workspace.Const.Ignore.LocalCharacter.Top.Prism1
    end)
    return ok and part or nil
end

local function longNeckApply(state)
    if not longNeckPart then
        longNeckPart   = longNeckGetPart()
        longNeckOrigCF = longNeckPart and longNeckPart.CFrame or nil
    end
    if not longNeckPart or not longNeckOrigCF then return end
    if state then
        -- Move pivot down by Strength studs (camera appears higher)
        longNeckPart.CFrame = CFrame.new(
            longNeckOrigCF.Position - Vector3.new(0, LongNeck.Strength, 0)
        ) * (longNeckOrigCF - longNeckOrigCF.Position)
    else
        longNeckPart.CFrame = longNeckOrigCF
    end
end

_G.OnToggle("Long Neck", function(s)
    LongNeck.Enabled = s
    longNeckApply(s)
end)
_G.OnSlider("Long Neck Strength", function(v)
    LongNeck.Strength = v
    if LongNeck.Enabled then longNeckApply(true) end
end)

-- FreeCam
local FreeCamEnabled = false
local FreeCamSpeed = 150
local freecamCamPos = nil
local pitch, yaw = 0, 0
local activeKeys = {}
-- Saved humanoid speeds so we can restore them when FreeCam is disabled
local freecamSavedWalkSpeed = nil
local freecamSavedJumpPower = nil
local freecamOriginalCameraType = nil
local freecamOriginalCameraSubject = nil

local function setFreeCam(state)
    if state == FreeCamEnabled then return end
    FreeCamEnabled = state
    if FreeCamEnabled then
        local cf = Camera.CFrame
        freecamOriginalCameraType = Camera.CameraType
        freecamOriginalCameraSubject = Camera.CameraSubject
        freecamCamPos = cf.Position
        local look = cf.LookVector
        pitch = math.asin(-look.Y)
        yaw = math.atan2(-look.X, -look.Z)
        Camera.CameraType = Enum.CameraType.Scriptable

        -- Freeze the character so it doesn't wander while camera is free
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                freecamSavedWalkSpeed = hum.WalkSpeed
                freecamSavedJumpPower = hum.JumpPower
                hum.WalkSpeed = 0
                hum.JumpPower = 0
            end
        end

        RunService:BindToRenderStep("FreeCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
            local delta = UserInputService:GetMouseDelta()
            yaw = yaw - delta.X * 0.002
            pitch = math.clamp(pitch - delta.Y * 0.002, -math.rad(80), math.rad(80))
            local rotCF = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)

            local moveVec = Vector3.zero
            if activeKeys[Enum.KeyCode.W] then moveVec = moveVec + Vector3.new(0, 0, -1) end
            if activeKeys[Enum.KeyCode.S] then moveVec = moveVec + Vector3.new(0, 0, 1) end
            if activeKeys[Enum.KeyCode.A] then moveVec = moveVec + Vector3.new(-1, 0, 0) end
            if activeKeys[Enum.KeyCode.D] then moveVec = moveVec + Vector3.new(1, 0, 0) end
            if activeKeys[Enum.KeyCode.Space] then moveVec = moveVec + Vector3.new(0, 1, 0) end
            if activeKeys[Enum.KeyCode.LeftShift] then moveVec = moveVec + Vector3.new(0, -1, 0) end

            if moveVec.Magnitude > 0 then
                moveVec = rotCF:VectorToWorldSpace(moveVec).Unit
                freecamCamPos = freecamCamPos + moveVec * FreeCamSpeed * dt
            end
            Camera.CFrame = CFrame.new(freecamCamPos) * rotCF
        end)
    else
        RunService:UnbindFromRenderStep("FreeCam")
        Camera.CameraType = freecamOriginalCameraType or Enum.CameraType.Custom
        if freecamOriginalCameraSubject and freecamOriginalCameraSubject.Parent then
            Camera.CameraSubject = freecamOriginalCameraSubject
        end

        -- Restore character movement
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                if freecamSavedWalkSpeed then hum.WalkSpeed = freecamSavedWalkSpeed end
                if freecamSavedJumpPower then hum.JumpPower = freecamSavedJumpPower end
            end
        end
        freecamSavedWalkSpeed = nil
        freecamSavedJumpPower = nil
        freecamOriginalCameraType = nil
        freecamOriginalCameraSubject = nil
    end
end

LocalPlayer.CharacterAdded:Connect(function(character)
    if not FreeCamEnabled then return end
    task.wait()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        freecamSavedWalkSpeed = humanoid.WalkSpeed
        freecamSavedJumpPower = humanoid.JumpPower
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
    end
    if Camera then Camera.CameraType = Enum.CameraType.Scriptable end
end)

_G.OnToggle("Free Cam Pressed", function() setFreeCam(not FreeCamEnabled) end)
_G.OnToggle("Free Cam Toggle", setFreeCam)
_G.OnToggle("Free Cam Input", function(keyName, pressed)
    local key = Enum.KeyCode[keyName]
    if key then activeKeys[key] = pressed and true or nil end
end)
_G.OnToggle("Free Cam Look", function(x, y)
    if not FreeCamEnabled then return end
    yaw = yaw - (x or 0) * 0.002
    pitch = math.clamp(pitch - (y or 0) * 0.002, -math.rad(80), math.rad(80))
end)

_G.OnSlider("FreeCam Speed", function(v) FreeCamSpeed = v end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe then activeKeys[input.KeyCode] = true end
end)
UserInputService.InputEnded:Connect(function(input)
    activeKeys[input.KeyCode] = nil
end)

_G.AtomwareFeaturesLoaded = true
print("Good to go")
