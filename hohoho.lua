-- =====================================================================================
-- REALISTIC ADVANCED DRONE SYSTEM (VECTORFORCE PHYSICS & SOUNDS)33
-- =====================================================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Змінні стану
local drone = nil
local isControlling = false
local dronePart = nil
local droneHumanoid = nil
local originalCFrame = nil
local skyBoxPart = nil

-- Фізичні об'єкти для реалістичної фізики
local attachment = nil
local vectorForce = nil
local alignOrientation = nil
local droneSound = nil

-- Компоненти візуалу (лопаті)
local propellerParts = {}
local currentRotationSpeed = 0

-- Налаштування реалістичної фізики дрона
local droneMass = 5 -- вага в кг
local maxThrust = droneMass * Workspace.Gravity * 2.2 -- максимальна тяга вгору
local horizontalForceMagnitude = droneMass * 25 -- сила розгону в сторони
local currentYaw = 0 -- поворот камери

-- UI
local screenGui = nil
local mainControlFrame = nil
local isUIVisible = true

local function getSkyBox()
	if skyBoxPart and skyBoxPart.Parent then return skyBoxPart end
	skyBoxPart = Instance.new("Part")
	skyBoxPart.Name = "PlayerSkyBoxSafeZone"
	skyBoxPart.Size = Vector3.new(20, 2, 20)
	skyBoxPart.Position = Vector3.new(0, 5000, 0)
	skyBoxPart.Anchored = true
	skyBoxPart.Transparency = 1
	skyBoxPart.CanCollide = true
	skyBoxPart.Parent = Workspace
	return skyBoxPart
end

local function setupDroneUI()
	if screenGui then screenGui:Destroy() end
	
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DroneControlGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100
	
	local targetParent = player:FindFirstChild("PlayerGui") or CoreGui
	screenGui.Parent = targetParent
	
	mainControlFrame = Instance.new("Frame")
	mainControlFrame.Size = UDim2.new(0, 420, 0, 140)
	mainControlFrame.Position = UDim2.new(0.5, -210, 1, -160)
	mainControlFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	mainControlFrame.BackgroundTransparency = 0.3
	mainControlFrame.BorderSizePixel = 0
	mainControlFrame.Visible = false
	mainControlFrame.Parent = screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = mainControlFrame
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 170, 255)
	stroke.Thickness = 2
	stroke.Parent = mainControlFrame
	
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 30)
	titleLabel.Position = UDim2.new(0, 0, 0, 5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = 16
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = "РЕАЛІСТИЧНИЙ ДРОН [M - Вихід]"
	titleLabel.Parent = mainControlFrame
	
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, -20, 0, 85)
	infoLabel.Position = UDim2.new(0, 10, 0, 35)
	infoLabel.BackgroundTransparency = 1
	infoLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
	infoLabel.TextSize = 13
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextWrapped = true
	infoLabel.Text = "W A SD - Плавний політ (Інерція)\nSpace - Зліт | Q - Спуск\nМиша - Поворот та оберт дрона\nE - Видалити дрон"
	infoLabel.Parent = mainControlFrame
	
	local toggleButton = Instance.new("TextButton")
	toggleButton.Size = UDim2.new(0, 140, 0, 35)
	toggleButton.Position = UDim2.new(1, -150, 0, 15)
	toggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleButton.TextSize = 12
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.Text = "Сховати меню [UI]"
	toggleButton.Parent = screenGui
	
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = toggleButton
	
	toggleButton.MouseButton1Click:Connect(function()
		isUIVisible = not isUIVisible
		if mainControlFrame then mainControlFrame.Visible = isUIVisible and isControlling end
		toggleButton.Text = isUIVisible and "Сховати меню [UI]" or "Відкрити меню [UI]"
	end)
end

local exitDroneControl

local function spawnDrone()
	if drone and drone.Parent then
		if isControlling then exitDroneControl() end
		drone:Destroy()
		drone = nil
		dronePart = nil
		if screenGui then screenGui:Destroy() screenGui = nil end
		return
	end
	
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart
	
	drone = Instance.new("Model")
	drone.Name = "RealisticQuadcopter"
	drone.Parent = Workspace
	
	dronePart = Instance.new("Part")
	dronePart.Name = "HumanoidRootPart"
	dronePart.Size = Vector3.new(2.6, 0.8, 2.6)
	dronePart.CFrame = rootPart.CFrame + rootPart.CFrame.LookVector * 6 + Vector3.new(0, 3, 0)
	dronePart.Material = Enum.Material.Neon
	dronePart.BrickColor = BrickColor.new("Black")
	dronePart.Shape = Enum.PartType.Cylinder
	dronePart.Anchored = false
	dronePart.CanCollide = true
	dronePart.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.2, 1, 1)
	dronePart.Parent = drone
	
	droneHumanoid = Instance.new("Humanoid")
	droneHumanoid.MaxHealth = 100
	droneHumanoid.Health = 100
	droneHumanoid.PlatformStand = true
	droneHumanoid.Parent = drone
	
	-- Додаємо фізичні об'єкти для управління вагою та тягою через VectorForce
	attachment = Instance.new("Attachment")
	attachment.Parent = dronePart
	
	vectorForce = Instance.new("VectorForce")
	vectorForce.Attachment0 = attachment
	vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
	vectorForce.Force = Vector3.new(0, droneMass * Workspace.Gravity, 0) -- Компенсація гравітації спочатку
	vectorForce.Parent = dronePart
	
	alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Attachment0 = attachment
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.MaxTorque = 50000
	alignOrientation.Responsiveness = 15
	alignOrientation.Parent = dronePart
	
	-- Звук двигуна дрона
	droneSound = Instance.new("Sound")
	droneSound.SoundId = "rbxassetid://9114223207" -- Реалістичний гул мотора
	droneSound.Looped = true
	droneSound.Volume = 0
	droneSound.Parent = dronePart
	droneSound:Play()
	
	propellerParts = {}
	for i = 1, 4 do
		local prop = Instance.new("Part")
		prop.Size = Vector3.new(1.5, 0.08, 0.3)
		prop.BrickColor = BrickColor.new("Institutional white")
		prop.Material = Enum.Material.SmoothPlastic
		prop.Anchored = false
		prop.CanCollide = false
		prop.Parent = drone
		
		local angle = math.rad(i * 90)
		local offset = CFrame.new(math.cos(angle) * 1.2, 0.45, math.sin(angle) * 1.2)
		prop.CFrame = dronePart.CFrame * offset
		
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = dronePart
		weld.Part1 = prop
		weld.Parent = dronePart
		
		table.insert(propellerParts, {Part = prop, Offset = offset})
	end
	
	drone.PrimaryPart = dronePart
	setupDroneUI()
	print("Реалістичний дрон створено!")
end

exitDroneControl = function()
	isControlling = false
	local character = player.Character
	
	if character and character:FindFirstChild("HumanoidRootPart") and originalCFrame then
		local rootPart = character.HumanoidRootPart
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		rootPart.CFrame = originalCFrame
		rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		if humanoid then
			humanoid.PlatformStand = false
			camera.CameraSubject = humanoid
		end
		camera.CameraType = Enum.CameraType.Custom
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	
	if vectorForce then
		vectorForce.Force = Vector3.new(0, droneMass * Workspace.Gravity, 0)
	end
	if droneSound then
		droneSound.Volume = 0
	end
	
	if mainControlFrame then mainControlFrame.Visible = false end
end

local function toggleDroneControl()
	if not drone or not dronePart then return end
	isControlling = not isControlling
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then 
		isControlling = false 
		return 
	end
	
	local rootPart = character.HumanoidRootPart
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	
	if isControlling then
		originalCFrame = rootPart.CFrame
		rootPart.CFrame = getSkyBox().CFrame + Vector3.new(0, 3, 0)
		rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		if humanoid then humanoid.PlatformStand = true end
		
		camera.CameraSubject = droneHumanoid
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		if mainControlFrame then mainControlFrame.Visible = isUIVisible end
		
		-- Ініціалізація повороту камери
		local look = camera.CFrame.LookVector
		currentYaw = math.atan2(-look.X, -look.Z)
	else
		exitDroneControl()
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.E then
		spawnDrone()
	elseif input.KeyCode == Enum.KeyCode.M then
		toggleDroneControl()
	end
end)

-- Поворот камери мишкою для реалістичного управління обертанням дрона
UserInputService.InputChanged:Connect(function(input)
	if isControlling and input.UserInputType == Enum.UserInputType.MouseMovement then
		currentYaw = currentYaw - input.Delta.X * 0.003
	end
end)

-- ГОЛОВНИЙ ФІЗИЧНИЙ ЦИКЛ (Реалістична інерція, тяга та нахили)
RunService.RenderStepped:Connect(function(dt)
	-- Обертання лопатей (швидкість залежить від режиму)
	if drone and drone.Parent and #propellerParts > 0 then
		local targetRotSpeed = isControlling and 55 or 8
		currentRotationSpeed = currentRotationSpeed + (targetRotSpeed - currentRotationSpeed) * (dt * 6)
		
		for index, propData in ipairs(propellerParts) do
			if propData.Part and propData.Part.Parent then
				local spinAngle = tick() * currentRotationSpeed * (index % 2 == 0 ? 1 : -1)
				propData.Part.CFrame = dronePart.CFrame * propData.Offset * CFrame.Angles(0, spinAngle, 0)
			end
		end
	end
	
	if not isControlling or not dronePart or not dronePart.Parent then return end
	
	-- Звук мотора при польоті
	droneSound.Volume = 0.7
	droneSound.Pitch = 1.2 + math.min(dronePart.AssemblyLinearVelocity.Magnitude / 30, 0.8)
	
	-- Напрямки на основі погляду мишки
	local baseRotation = CFrame.Angles(0, currentYaw, 0)
	local forwardDir = baseRotation * Vector3.new(0, 0, -1)
	local rightDir = baseRotation * Vector3.new(1, 0, 0)
	
	-- Зчитування клавіш руху
	local moveInput = Vector3.new(0, 0, 0)
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveInput = moveInput + forwardDir end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveInput = moveInput - forwardDir end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveInput = moveInput - rightDir end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveInput = moveInput + rightDir end
	
	local verticalInput = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		verticalInput = maxThrust * 0.65 -- Додаткова тяга вгору
	elseif UserInputService:IsKeyDown(Enum.KeyCode.Q) then
		verticalInput = -maxThrust * 0.4 -- Спуск вниз
	end
	
	-- Розрахунок загальної сили (Гравітація + Тяга + Інерція руху вбік)
	local gravityCompensation = Vector3.new(0, droneMass * Workspace.Gravity, 0)
	local targetForce = gravityCompensation + Vector3.new(0, verticalInput, 0) + (moveInput * horizontalForceMagnitude)
	
	-- Плавне застосування фізичної сили (інерція розгону та гальмування)
	vectorForce.Force = vectorForce.Force:Lerp(targetForce, math.clamp(dt * 8, 0, 1))
	
	-- Реалістичний нахил корпусу дрона в бік руху
	local tiltAngleX = moveInput:Dot(forwardDir) * 0.25
	local tiltAngleZ = -moveInput:Dot(rightDir) * 0.25
	local targetCFrame = CFrame.new(dronePart.Position) * baseRotation * CFrame.Angles(tiltAngleX, 0, tiltAngleZ)
	
	alignOrientation.CFrame = targetCFrame
end)
