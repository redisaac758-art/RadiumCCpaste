--[[
    FeaturesScript.lua (features.lua)
    Backend features engine for Atomware UI (Trident Survival)
    Contains ported Radium.cc features + Custom Aimbot + ESP + World + Player Mods
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

repeat task.wait() until _G.OnToggle and _G.OnSlider and _G.OnDropdown and _G.OnColorPicker and _G.OnKeybind

--//==================================================
--// AIMBOT SYSTEM
--//==================================================

local AimbotConfig = {
    Enabled = false,
    ShowFOV = true,
    FOV = 120,
    Smoothing = 0.15,
    HitPart = "Head",
    TeamCheck = true,
    AimKey = Enum.UserInputType.MouseButton2,
    AimKeyName = "MouseButton2",
    Active = false
}

local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Thickness = 1.5
FOVCircle.Color = Color3.fromRGB(184, 73, 255)
FOVCircle.Filled = false
FOVCircle.NumSides = 64

local function getClosestEnemyInFOV()
    local closestTarget = nil
    local shortestDist = AimbotConfig.FOV
    local viewportCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not (AimbotConfig.TeamCheck and player.Team and player.Team == LocalPlayer.Team) then
                local char = player.Character
                if char then
                    local targetPart = char:FindFirstChild(AimbotConfig.HitPart) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
                    local humanoid = char:FindFirstChildOfClass("Humanoid")

                    if targetPart and humanoid and humanoid.Health > 0 then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen then
                            local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - viewportCenter).Magnitude
                            if screenDist <= shortestDist then
                                shortestDist = screenDist
                                closestTarget = targetPart
                            end
                        end
                    end
                end
            end
        end
    end

    return closestTarget
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == AimbotConfig.AimKey or input.KeyCode == AimbotConfig.AimKey or input.KeyCode == Enum.KeyCode.ButtonRT then
        AimbotConfig.Active = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == AimbotConfig.AimKey or input.KeyCode == AimbotConfig.AimKey or input.KeyCode == Enum.KeyCode.ButtonRT then
        AimbotConfig.Active = false
    end
end)

RunService.RenderStepped:Connect(function()
    local viewportCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Position = viewportCenter
    FOVCircle.Radius = AimbotConfig.FOV
    FOVCircle.Visible = AimbotConfig.Enabled and AimbotConfig.ShowFOV

    if AimbotConfig.Enabled and AimbotConfig.Active then
        local targetPart = getClosestEnemyInFOV()
        if targetPart then
            local currentCFrame = Camera.CFrame
            local targetCFrame = CFrame.new(currentCFrame.Position, targetPart.Position)
            Camera.CFrame = currentCFrame:Lerp(targetCFrame, math.clamp(AimbotConfig.Smoothing, 0.01, 1))
        end
    end
end)

_G.OnToggle("Aimbot Enabled", function(state) AimbotConfig.Enabled = state end)
_G.OnToggle("Show FOV Circle", function(state) AimbotConfig.ShowFOV = state end)
_G.OnSlider("Aimbot FOV", function(val) AimbotConfig.FOV = val end)
_G.OnSlider("Aimbot Smoothing", function(val) AimbotConfig.Smoothing = val end)
_G.OnDropdown("Aim Hit Part", function(part) AimbotConfig.HitPart = part end)
_G.OnToggle("Aimbot Team Check", function(state) AimbotConfig.TeamCheck = state end)
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
                originalHeadStats[head] = {
                    Size = head.Size,
                    Transparency = head.Transparency
                }
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
            for _, model in pairs(Workspace:GetChildren()) do
                if model:IsA("Model") and model ~= LocalPlayer.Character then
                    applyBigHead(model)
                end
            end
        end
        task.wait(1)
    end
end)

_G.OnToggle("Big Head", function(state)
    HeadSizeEnabled = state
    if not state then
        for head, stats in pairs(originalHeadStats) do
            if head and head.Parent then
                head.Size = stats.Size
                head.Transparency = stats.Transparency
            end
        end
        originalHeadStats = {}
    end
end)

_G.OnSlider("Head Size", function(val)
    headScale = Vector3.new(val, val, val)
end)

_G.OnSlider("Head Transparency", function(val)
    headTransparency = val
end)

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

local function getPlayerMainParts(model)
    local head = model:FindFirstChild("Head")
    local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("LowerTorso")
    return head, torso
end

local function isPlayerModel(model)
    local torso = model:FindFirstChild("Torso")
    return torso and torso:FindFirstChild("LeftBooster") ~= nil
end

local function detectEquippedWeapon(model)
    local handModel = model:FindFirstChild("HandModel")
    if not handModel then return "None" end
    local matchedName = "None"
    local highestCount = 0

    for wName, parts in pairs(weaponDefinitions) do
        local count = 0
        for _, pName in ipairs(parts) do
            if handModel:FindFirstChild(pName, true) then count = count + 1 end
        end
        if count > highestCount then
            highestCount = count
            matchedName = wName
        end
    end
    return matchedName
end

local function registerESPModel(model)
    if espCache[model] then return end
    local head, torso = getPlayerMainParts(model)
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
    txt.Size = 15
    txt.Center = true
    txt.Outline = true
    txt.OutlineColor = Color3.fromRGB(0, 0, 0)
    txt.Visible = false

    local weaponTxt = Drawing.new("Text")
    weaponTxt.Size = 14
    weaponTxt.Center = true
    weaponTxt.Outline = true
    weaponTxt.OutlineColor = Color3.fromRGB(0, 0, 0)
    weaponTxt.Visible = false

    local skelLines = {}
    for _, bonePair in ipairs(skeletonBones) do
        local line = Drawing.new("Line")
        line.Color = isPlayerModel(model) and Color_Skeleton or Color3.fromRGB(0, 150, 255)
        line.Thickness = 1.5
        line.Visible = false
        table.insert(skelLines, { line = line, a = bonePair[1], b = bonePair[2] })
    end

    espCache[model] = {
        box = box,
        outline = outline,
        text = txt,
        weaponText = weaponTxt,
        head = head,
        torso = torso,
        skeletonLines = skelLines
    }

    model.Destroying:Connect(function()
        pcall(function() box:Remove() end)
        pcall(function() outline:Remove() end)
        pcall(function() txt:Remove() end)
        pcall(function() weaponTxt:Remove() end)
        for _, skLine in ipairs(skelLines) do
            pcall(function() skLine.line:Remove() end)
        end
        espCache[model] = nil
    end)
end

for _, m in ipairs(Workspace:GetChildren()) do
    if m:IsA("Model") then registerESPModel(m) end
end

Workspace.ChildAdded:Connect(function(child)
    if child:IsA("Model") then registerESPModel(child) end
end)

task.spawn(function()
    while true do
        for model in pairs(espCache) do
            cachedWeapons[model] = detectEquippedWeapon(model)
        end
        task.wait(1)
    end
end)

RunService.RenderStepped:Connect(function()
    if not ESP_Master then
        for _, data in pairs(espCache) do
            data.box.Visible = false
            data.outline.Visible = false
            data.text.Visible = false
            data.weaponText.Visible = false
            for _, sk in ipairs(data.skeletonLines) do sk.line.Visible = false end
        end
        return
    end

    local camPos = Camera.CFrame.Position
    for model, data in pairs(espCache) do
        local valid = true
        local head, torso = data.head, data.torso
        if not head or not torso or not head.Parent or not torso.Parent then
            head, torso = getPlayerMainParts(model)
            data.head, data.torso = head, torso
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

        local distance = 0
        if valid then
            local midPos = (head.Position + torso.Position) * 0.5
            distance = (midPos - camPos).Magnitude
            if distance >= 3000 then valid = false end
        end

        local screenPos, onScreen = nil, false
        if valid then
            screenPos, onScreen = Camera:WorldToViewportPoint((head.Position + torso.Position) * 0.5)
            if not onScreen then valid = false end
        end

        if not valid then
            data.box.Visible = false
            data.outline.Visible = false
            data.text.Visible = false
            data.weaponText.Visible = false
            for _, sk in ipairs(data.skeletonLines) do sk.line.Visible = false end
        else
            local fovScale = 1000 / (distance * 2) / math.tan(math.rad(Camera.FieldOfView / 1.7))
            local boxWidth = math.clamp(math.floor(6.5 * fovScale), 10, 600)
            local boxHeight = math.clamp(math.floor(9.5 * fovScale), 14, 800)
            local boxX = screenPos.X - boxWidth / 2
            local boxY = screenPos.Y - boxHeight / 3.5

            if ESP_Box then
                data.outline.Size = Vector2.new(boxWidth + 2, boxHeight + 2)
                data.outline.Position = Vector2.new(boxX - 1, boxY - 1)
                data.outline.Visible = true

                data.box.Size = Vector2.new(boxWidth, boxHeight)
                data.box.Position = Vector2.new(boxX, boxY)
                data.box.Color = isPlayerModel(model) and Color_Box or Color3.fromRGB(0, 150, 255)
                data.box.Visible = true
            else
                data.outline.Visible = false
                data.box.Visible = false
            end

            local labels = {}
            if ESP_Type then table.insert(labels, isPlayerModel(model) and "Player" or "Bot") end
            if ESP_Distance then table.insert(labels, math.floor(distance) .. "m") end
            local labelStr = table.concat(labels, " | ")

            if labelStr ~= "" then
                data.text.Color = isPlayerModel(model) and Color_Text or Color3.fromRGB(0, 150, 255)
                data.text.Text = labelStr
                data.text.Position = Vector2.new(screenPos.X, boxY - 16)
                data.text.Visible = true
            else
                data.text.Visible = false
            end

            if ESP_Weapon then
                data.weaponText.Color = isPlayerModel(model) and Color_Text or Color3.fromRGB(0, 150, 255)
                data.weaponText.Text = cachedWeapons[model] or "None"
                data.weaponText.Position = Vector2.new(screenPos.X, boxY + boxHeight)
                data.weaponText.Visible = true
            else
                data.weaponText.Visible = false
            end

            if ESP_Skeleton then
                for _, sk in ipairs(data.skeletonLines) do
                    local partA = model:FindFirstChild(sk.a)
                    local partB = model:FindFirstChild(sk.b)
                    if partA and partB then
                        local posA, visA = Camera:WorldToViewportPoint(partA.Position)
                        local posB, visB = Camera:WorldToViewportPoint(partB.Position)
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
                for _, sk in ipairs(data.skeletonLines) do sk.line.Visible = false end
            end
        end
    end
end)

_G.OnToggle("Enable ESP", function(state) ESP_Master = state end)
_G.OnToggle("Box Esp", function(state) ESP_Box = state end)
_G.OnToggle("Distance Esp", function(state) ESP_Distance = state end)
_G.OnToggle("Player/Bot Esp", function(state) ESP_Type = state end)
_G.OnToggle("Sleeper Check", function(state) ESP_SleeperCheck = state end)
_G.OnToggle("Weapon Esp", function(state) ESP_Weapon = state end)
_G.OnToggle("Skeleton Esp", function(state) ESP_Skeleton = state end)

_G.OnColorPicker("Box Color", function(col) Color_Box = col end)
_G.OnColorPicker("Skeleton Color", function(col) Color_Skeleton = col end)
_G.OnColorPicker("Text Color", function(col) Color_Text = col end)

--//==================================================
--// ARMOR ESP
--//==================================================

local ArmorESP_Enabled = false
local ArmorFOV_Radius = 220

local ArmorTargetCircle = Drawing.new("Circle")
ArmorTargetCircle.Visible = false
ArmorTargetCircle.Thickness = 1.5
ArmorTargetCircle.Radius = 220
ArmorTargetCircle.Color = Color3.fromRGB(42, 255, 157)
ArmorTargetCircle.Filled = false

local ArmorTargetLine = Drawing.new("Line")
ArmorTargetLine.Visible = false
ArmorTargetLine.Thickness = 1.5
ArmorTargetLine.Color = Color3.fromRGB(255, 75, 125)

_G.OnToggle("Armor Esp", function(state) ArmorESP_Enabled = state end)
_G.OnSlider("Fov Slider", function(val)
    ArmorFOV_Radius = val
    ArmorTargetCircle.Radius = val
end)

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

_G.OnToggle("Item ESP", function(state)
    ItemESP_Enabled = state
    if not state then
        for _, item in pairs(ItemCache) do item.drawing:Remove() end
        ItemCache = {}
    end
end)

_G.OnToggle("Corpse ESP", function(state)
    CorpseESP_Enabled = state
    if not state then
        for _, corpse in pairs(CorpseCache) do corpse.drawing:Remove() end
        CorpseCache = {}
    end
end)

_G.OnToggle("Raid ESP", function(state)
    RaidESP_Enabled = state
    if not state then
        for _, raid in pairs(RaidCache) do raid.text:Remove() end
        RaidCache = {}
    end
end)

_G.OnToggle("Airdrop ESP", function(state)
    AirdropESP_Enabled = state
    if not state then
        for _, drop in pairs(AirdropCache) do drop.drawing:Remove() end
        AirdropCache = {}
    end
end)

-- Sound detector for Raid ESP
local hitSoundNames = { Explosion = true, Explosion_Muffled = true }
local function registerRaidSound(sound)
    sound.Played:Connect(function()
        if RaidESP_Enabled and sound.Parent and sound.Parent:IsA("BasePart") then
            local txt = Drawing.new("Text")
            txt.Text = "Raid"
            txt.Size = 15
            txt.Center = true
            txt.Outline = true
            txt.OutlineColor = Color3.new(0, 0, 0)
            txt.Color = Color3.fromRGB(255, 75, 125)
            table.insert(RaidCache, { text = txt, position = sound.Parent.Position, startTime = tick() })
        end
    end)
end

for _, desc in ipairs(Workspace:GetDescendants()) do
    if desc:IsA("Sound") and hitSoundNames[desc.Name] then registerRaidSound(desc) end
end
Workspace.DescendantAdded:Connect(function(desc)
    if desc:IsA("Sound") and hitSoundNames[desc.Name] then registerRaidSound(desc) end
end)

--//==================================================
--// ORE ESP
--//==================================================

local OreESPConfig = {
    Stone = false,
    Iron = false,
    Nitrate = false,
    ShowDistance = false,
    RenderDistance = 750
}

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

local function identifyOreModel(model)
    local meshes = {}
    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("MeshPart") then table.insert(meshes, child) end
    end

    if #meshes == 1 then
        if matchColor(meshes[1].Color, oreColors.Stone[1]) then return "Stone", meshes[1] end
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
                local oreType, orePart = identifyOreModel(m)
                if oreType and OreESPConfig[oreType] then
                    local txt = Drawing.new("Text")
                    txt.Size = 14
                    txt.Center = true
                    txt.Outline = true
                    txt.OutlineColor = Color3.fromRGB(0, 0, 0)
                    txt.Color = oreLabelColors[oreType]
                    oreCache[m] = { Text = txt, OreType = oreType, Part = orePart }
                end
            end
        end
        for model, data in pairs(oreCache) do
            if not model.Parent then
                data.Text:Remove()
                oreCache[model] = nil
            end
        end
        task.wait(2)
    end
end)

RunService.RenderStepped:Connect(function()
    for model, data in pairs(oreCache) do
        if data.Part and data.Part.Parent then
            local dist = (Camera.CFrame.Position - data.Part.Position).Magnitude
            local screenPos, onScreen = Camera:WorldToViewportPoint(data.Part.Position)

            if onScreen and dist <= OreESPConfig.RenderDistance and OreESPConfig[data.OreType] then
                if OreESPConfig.ShowDistance then
                    data.Text.Text = string.format("%s | %.0fm", data.OreType, dist)
                else
                    data.Text.Text = data.OreType
                end
                data.Text.Position = Vector2.new(screenPos.X, screenPos.Y)
                data.Text.Visible = true
            else
                data.Text.Visible = false
            end
        else
            data.Text:Remove()
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
local vehicleCache = {}

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

_G.OnColorPicker("Cloud Color", function(col)
    pcall(function() Workspace.Terrain.Clouds.Color = col end)
end)
_G.OnSlider("Clouds Cover", function(v)
    pcall(function() Workspace.Terrain.Clouds.Cover = v end)
end)

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
    if BrightNightEnabled then
        Lighting.ExposureCompensation = 2.5
    end
end)

-- Stim Effect
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

-- X-Ray
local XRayEnabled = false
local originalPartTransparencies = {}
local xrayMaterials = { Enum.Material.Cobblestone, Enum.Material.WoodPlanks, Enum.Material.Metal, Enum.Material.CorrodedMetal }

local function setXRayState(state)
    XRayEnabled = state
    for _, m in ipairs(Workspace:GetChildren()) do
        if m:IsA("Model") then
            for _, p in ipairs(m:GetDescendants()) do
                if p:IsA("BasePart") and table.find(xrayMaterials, p.Material) then
                    if state then
                        if not originalPartTransparencies[p] then originalPartTransparencies[p] = p.Transparency end
                        p.Transparency = 0.5
                    elseif originalPartTransparencies[p] ~= nil then
                        p.Transparency = originalPartTransparencies[p]
                    end
                end
            end
        end
    end
end

_G.OnKeybind("Xray", function()
    setXRayState(not XRayEnabled)
end)

-- Zoom & FOV Metatable Hook
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

-- Hit Sounds
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

-- Bullet Trails
local BulletTrailEnabled = false
local BulletTrailColor = Color3.fromRGB(255, 255, 255)
local BulletTrailThickness = 0.2
local BulletTrailLength = 10
local BulletTrailLifetime = 0.1

_G.OnToggle("Bullet Trail", function(s) BulletTrailEnabled = s end)
_G.OnColorPicker("Bullet Trail Color", function(col) BulletTrailColor = col end)
_G.OnSlider("Trail Thickness", function(v) BulletTrailThickness = v end)
_G.OnSlider("Bullet Trail Length", function(v) BulletTrailLength = v end)
_G.OnSlider("Trail LifeTime", function(v) BulletTrailLifetime = v end)

Workspace.DescendantAdded:Connect(function(desc)
    if desc.Name == "Bullet" and not desc:IsDescendantOf(ReplicatedStorage) and BulletTrailEnabled then
        local points = {}
        local conn
        conn = RunService.RenderStepped:Connect(function()
            if not BulletTrailEnabled or not desc or not desc.Parent then
                conn:Disconnect()
                return
            end
            local pos = desc.Position
            table.insert(points, 1, pos)
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

-- Hand & Weapon Chams
local handMaterial = "Default"
local handColor = Color3.fromRGB(255, 255, 255)
local weaponMaterial = "Default"
local weaponColor = Color3.fromRGB(255, 255, 255)

_G.OnDropdown("Hand Cham Material", function(mat) handMaterial = mat end)
_G.OnColorPicker("Hand cham color", function(col) handColor = col end)
_G.OnDropdown("Weapon Cham Material", function(mat) weaponMaterial = mat end)
_G.OnColorPicker("Weapon Cham Color", function(col) weaponColor = col end)

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

print("Atomware Features Script Engine Loaded & Bound.")
