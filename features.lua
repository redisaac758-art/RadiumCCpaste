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
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera")

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
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == AimbotConfig.AimKey or input.KeyCode == AimbotConfig.AimKey then
        if AimbotConfig.Mode == "Hold Toggle" then
            AimbotConfig.ToggleState = not AimbotConfig.ToggleState
        else
            AimbotConfig.Active = true
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == AimbotConfig.AimKey or input.KeyCode == AimbotConfig.AimKey then
        if AimbotConfig.Mode == "Controller Bind" then
            AimbotConfig.Active = false
        end
    end
end)

-- Mobile & Controller Global Aim Triggers
_G.OnToggle("MobileAimTrigger", function(state)
    AimbotConfig.Active = state
    AimbotConfig.ToggleState = state
end)

_G.OnToggle("ControllerAimToggle", function()
    AimbotConfig.ToggleState = not AimbotConfig.ToggleState
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

_G.OnToggle("Item ESP", function(s)
    ItemESP_Enabled = s
    if not s then for _, i in pairs(ItemCache) do i.drawing:Remove() end ItemCache = {} end
end)
_G.OnToggle("Corpse ESP", function(s)
    CorpseESP_Enabled = s
    if not s then for _, c in pairs(CorpseCache) do c.drawing:Remove() end CorpseCache = {} end
end)
_G.OnToggle("Raid ESP", function(s)
    RaidESP_Enabled = s
    if not s then for _, r in pairs(RaidCache) do r.text:Remove() end RaidCache = {} end
end)
_G.OnToggle("Airdrop ESP", function(s)
    AirdropESP_Enabled = s
    if not s then for _, a in pairs(AirdropCache) do a.drawing:Remove() end AirdropCache = {} end
end)

local hitSoundNames = { Explosion = true, Explosion_Muffled = true }
local function registerSound(sound)
    sound.Played:Connect(function()
        if RaidESP_Enabled and sound.Parent and sound.Parent:IsA("BasePart") then
            local txt = Drawing.new("Text")
            txt.Text = "Raid"
            txt.Size = 14
            txt.Center = true
            txt.Outline = true
            txt.OutlineColor = Color3.new(0, 0, 0)
            txt.Color = Color3.fromRGB(255, 75, 125)
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

task.spawn(function()
    while true do
        for _, m in ipairs(Workspace:GetChildren()) do
            if m:IsA("Model") and not oreCache[m] then
                local oType, oPart = identifyOre(m)
                if oType and OreESPConfig[oType] then
                    local txt = Drawing.new("Text")
                    txt.Size = 13
                    txt.Center = true
                    txt.Outline = true
                    txt.OutlineColor = Color3.fromRGB(0, 0, 0)
                    txt.Color = oreLabelColors[oType]
                    oreCache[m] = { Text = txt, OreType = oType, Part = oPart }
                end
            end
        end
        for model, d in pairs(oreCache) do
            if not model.Parent then d.Text:Remove() oreCache[model] = nil end
        end
        task.wait(2)
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

_G.OnDropdown("Sky Changer", function(skyType)
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("Sky") then child:Destroy() end
    end
    if skyType == "Default" then return end
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
_G.OnToggle("Bright Night", function(s)
    BrightNightEnabled = s
    if not s then Lighting.ExposureCompensation = 0 end
end)
RunService.RenderStepped:Connect(function()
    if BrightNightEnabled then Lighting.ExposureCompensation = 2.5 end
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

_G.OnKeybind("Xray", function() setXRay(not XRayEnabled) end)
_G.OnToggle("X-Ray Active", function(s) setXRay(s) end)

local defaultFOV = 70
local isZooming = false
_G.OnSlider("FOV Changer", function(v)
    defaultFOV = v
    if not isZooming then Camera.FieldOfView = v end
end)
_G.OnKeybind("Zoom", function() end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.X then
        isZooming = true
        Camera.FieldOfView = 20
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.X then
        isZooming = false
        Camera.FieldOfView = defaultFOV
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
    currentHitSound = sndName
    local snd = SoundService:FindFirstChild("PlayerHitHeadshot")
    if snd then
        snd.SoundId = hitSoundAudioIds[sndName] or hitSoundAudioIds.Default
        snd:Play()
    end
end)
_G.OnSlider("Hit sound Volume", function(vol)
    currentHitVolume = vol
    local snd = SoundService:FindFirstChild("PlayerHitHeadshot")
    if snd then snd.Volume = vol end
end)

local BulletTrailEnabled = false
local BulletTrailColor = Color3.fromRGB(255, 255, 255)
local BulletTrailThickness = 0.2
local BulletTrailLength = 10
local BulletTrailLifetime = 0.1

_G.OnToggle("Bullet Trail", function(s) BulletTrailEnabled = s end)
_G.OnColorPicker("Bullet Trail Color", function(c) BulletTrailColor = c end)
_G.OnSlider("Trail Thickness", function(v) BulletTrailThickness = v end)
_G.OnSlider("Bullet Trail Length", function(v) BulletTrailLength = v end)
_G.OnSlider("Trail LifeTime", function(v) BulletTrailLifetime = v end)

_G.OnColorPicker("Arrow Trailcolor", function() end)
_G.OnSlider("Arrow Trail lifespan", function() end)
_G.OnDropdown("Hand Cham Material", function() end)
_G.OnColorPicker("Hand cham color", function() end)
_G.OnDropdown("Weapon Cham Material", function() end)
_G.OnColorPicker("Weapon Cham Color", function() end)

Workspace.DescendantAdded:Connect(function(desc)
    if desc.Name == "Bullet" and not desc:IsDescendantOf(ReplicatedStorage) and BulletTrailEnabled then
        local points = {}
        local conn
        conn = RunService.RenderStepped:Connect(function()
            if not BulletTrailEnabled or not desc or not desc.Parent then
                conn:Disconnect()
                return
            end
            table.insert(points, 1, desc.Position)
            if #points > BulletTrailLength then table.remove(points) end

            for i = 1, #points - 1 do
                local p1, p2 = points[i], points[i + 1]
                local beam = Instance.new("Part")
                beam.Anchored = true
                beam.CanCollide = false
                beam.Size = Vector3.new(BulletTrailThickness, BulletTrailThickness, (p1 - p2).Magnitude)
                beam.CFrame = CFrame.new(p1, p2) * CFrame.new(0, 0, -beam.Size.Z / 2)
                beam.Color = BulletTrailColor
                beam.Material = Enum.Material.ForceField
                beam.Parent = Workspace
                Debris:AddItem(beam, BulletTrailLifetime)
            end
        end)
    end
end)

-- FreeCam
local FreeCamEnabled = false
local FreeCamSpeed = 150
local freecamCamPos = nil
local pitch, yaw = 0, 0
local activeKeys = {}

_G.OnKeybind("Free Cam", function()
    FreeCamEnabled = not FreeCamEnabled
    if FreeCamEnabled then
        local cf = Camera.CFrame
        freecamCamPos = cf.Position
        local look = cf.LookVector
        pitch = math.asin(-look.Y)
        yaw = math.atan2(-look.X, -look.Z)
        Camera.CameraType = Enum.CameraType.Scriptable

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
        Camera.CameraType = Enum.CameraType.Custom
    end
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
