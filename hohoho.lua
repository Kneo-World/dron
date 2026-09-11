-- =====================================================================================
-- ULTIMATE FULL-FEATURED DRONE SYSTEM (NO CUTS, FULLY FIXED CAMERA & PHYSICS)
-- =====================================================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Константи управління та фізики
local DRONE_MASS = 6
local MAX_SPEED = 40
local LIFT_SPEED = 25
local ACCELERATION = 10

-- Змінні стану
local drone = nil
local isControlling = false
local dronePart = nil
local droneHumanoid = nil
local originalCFrame = nil
local skyBoxPart = nil

-- Фізичні об'єкти
local attachment = nil
local linearVelocity = nil
local alignOrientation = nil
local droneSound = nil
local windSound = nil

-- Кути огляду та камера
local currentYaw = 0
local currentPitch = 0.4
local cameraDistance = 14
local currentRotationSpeed = 0
local propellerParts = {}

-- UI елементи
local screenGui = nil
local mainControlFrame = nil
local speedLabel = nil
local heightLabel = nil
local statusLabel = nil
local isUIVisible = true

local function getSkyBox()
	if skyBoxPart and skyBoxPart.Parent then return skyBoxPart end
	skyBoxPart = Instance.new("Part")
	skyBoxPart.Name = "PlayerSkyBoxSafeZone"
	skyBoxPart.Size = Vector3.new(40, 4, 40)
	skyBoxPart.Position = Vector3.new(0, 6000, 0)
	skyBoxPart.Anchored = true
	skyBoxPart.Transparency = 1
	skyBoxPart.CanCollide = true
	skyBoxPart.Parent = Workspace
	return skyBoxPart
end

local function setupUI()
	if screenGui then screenGui:Destroy() end
	
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "UltimateDroneSystemGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100
	
	local targetParent = player:FindFirstChild("PlayerGui") or CoreGui
	screenGui.Parent = targetParent
	
	-- Головна панель інструкцій
	mainControlFrame = Instance.new("Frame")
	mainControlFrame.Size = UDim2.new(0, 420, 0, 180)
	mainControlFrame.Position = UDim2.new(0.5, -210, 1, -200)
	mainControlFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
	mainControlFrame.BackgroundTransparency = 0.2
	mainControlFrame.BorderSizePixel = 0
	mainControlFrame.Visible = false
	mainControlFrame.Parent = screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = mainControlFrame
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 160, 255)
	stroke.Thickness = 2
	stroke.Parent = mainControlFrame
	
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 35)
	title.Position = UDim2.new(0, 0, 0, 5)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.Text = "КЕРУВАННЯ ДРОНОМ [M - Вихід]"
	title.Parent = mainControlFrame
	
	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -20, 0, 110)
	desc.Position = UDim2.new(0, 10, 0, 45)
	desc.BackgroundTransparency = 1
	desc.TextColor3 = Color3.fromRGB(200, 215, 240)
	desc.TextSize = 13
	desc.Font = Enum.Font.Gotham
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextWrapped = true
	desc.Text = "• WASD — Плавний рух у боки\n• Space / Q — Набір висоти / Спуск\n• Рух мишею — Поворот камери та курсу\n• Коліщатко миші — Зум камери\n• E — Спавн або знищення дрона"
	desc.Parent = mainControlFrame
	
	-- Телеметрія у верхньому кутку (швидкість та висота)
	local teleFrame = Instance.new("Frame")
	teleFrame.Name = "TelemetryFrame"
	teleFrame.Size = UDim2.new(0, 220, 0, 90)
	teleFrame.Position = UDim2.new(0, 20, 0, 20)
	teleFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
	teleFrame.BackgroundTransparency = 0.3
	teleFrame.Visible = false
	teleFrame.Parent = screenGui
	
	local teleCorner = Instance.new("UICorner")
	teleCorner.CornerRadius = UDim.new(0, 10)
	teleCorner.Parent = teleFrame
	
	speedLabel = Instance.new("TextLabel")
	speedLabel.Size = UDim2.new(1, -20, 0, 35)
	speedLabel.Position = UDim2.new(0, 10, 0, 10)
	speedLabel.BackgroundTransparency = 1
	speedLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
	speedLabel.TextSize = 14
	speedLabel.Font = Enum.Font.GothamBold
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedLabel.Text = "Швидкість: 0 км/год"
	speedLabel.Parent = teleFrame
	
	heightLabel = Instance.new("TextLabel")
	heightLabel.Size = UDim2.new(1, -20, 0, 35)
	heightLabel.Position = UDim2.new(0, 10, 0, 45)
	heightLabel.BackgroundTransparency = 1
	heightLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
	heightLabel.TextSize = 14
	heightLabel.Font = Enum.Font.GothamBold
	heightLabel.TextXAlignment = Enum.TextXAlignment.Left
	heightLabel.Text = "Висота: 0 м"
	heightLabel.Parent = teleFrame
end

local exitDroneControl

local function spawnDrone()
	if drone and drone.Parent then
		if isControlling then exitDroneControl() end
		drone:Destroy()
		drone = nil
		dronePart = nil
		if screenGui then screenGui:Destroy() screenGui = nil end
		print("[Drone]: Дрон повністю видалено.")
		return
	end
	
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart
	
	drone = Instance.new("Model")
	drone.Name = "ProfessionalQuadcopter"
	drone.Parent = Workspace
	
	-- Корпус дрона
	dronePart = Instance.new("Part")
	dronePart.Name = "HumanoidRootPart"
	dronePart.Size = Vector3.new(3, 1, 3)
	dronePart.CFrame = rootPart.CFrame + rootPart.CFrame.LookVector * 6 + Vector3.new(0, 3, 0)
	dronePart.Material = Enum.Material.SmoothPlastic
	dronePart.BrickColor = BrickColor.new("Dark stone grey")
	dronePart.Shape = Enum.PartType.Cylinder
	dronePart.Anchored = false
	dronePart.CanCollide = true
	dronePart.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, 0.1, 1, 1)
	dronePart.Parent = drone
	
	droneHumanoid = Instance.new("Humanoid")
	droneHumanoid.MaxHealth = 100
	droneHumanoid.Health = 100
	droneHumanoid.PlatformStand = true
	droneHumanoid.Parent = drone
	
	attachment = Instance.new("Attachment")
	attachment.Parent = dronePart
	
	-- Точний стабільний контролер швидкості
	linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Attachment0 = attachment
	linearVelocity.MaxForce = 35000
	linearVelocity.VectorVelocity = Vector3.new(0, 0, 0)
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Enabled = false
	linearVelocity.Parent = dronePart
	
	-- Орієнтація корпусу
	alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Attachment0 = attachment
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.MaxTorque = 60000
	alignOrientation.Responsiveness = 30
	alignOrientation.Parent = dronePart
	
	-- Звук мотора
	droneSound = Instance.new("Sound")
	droneSound.SoundId = "rbxassetid://9114223207"
	droneSound.Looped = true
	droneSound.Volume = 0
	droneSound.Parent = dronePart
	droneSound:Play()
	
	-- Пропелери (4 штуки по кутах)
	propellerParts = {}
	for i = 1, 4 do
		local prop = Instance.new("Part")
		prop.Size = Vector3.new(1.8, 0.08, 0.4)
		prop.BrickColor = BrickColor.new("Really black")
		prop.Material = Enum.Material.Neon
		prop.Anchored = false
		prop.CanCollide = false
		prop.Parent = drone
		
		local angle = math.rad(i * 90)
		local offset = CFrame.new(math.cos(angle) * 1.4, 0.55, math.sin(angle) * 1.4)
		prop.CFrame = dronePart.CFrame * offset
		
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = dronePart
		weld.Part1 = prop
		weld.Parent = dronePart
		
		table.insert(propellerParts, {Part = prop, Offset = offset})
	end
	
	drone.PrimaryPart = dronePart
	setupUI()
	print("[Drone]: Дрон успішно створено. Натисни M для керування.")
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
	
	if linearVelocity then linearVelocity.Enabled = false end
	if droneSound then droneSound.Volume = 0 end
	if mainControlFrame then mainControlFrame.Visible = false end
	local tele = screenGui and screenGui:FindFirstChild("TelemetryFrame")
	if tele then tele.Visible = false end
end

local function toggleDroneControl()
	if not drone or not dronePart then 
		print("[Drone]: Спочатку заспавни дрон клавішею E!")
		return 
	end
	
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
		
		camera.CameraType = Enum.CameraType.Scriptable
		-- ПОВЕРТАЄМО LOCKCENTER для коректної роботи миші та огляду на 360 градусів
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		
		if mainControlFrame then mainControlFrame.Visible = isUIVisible end
		local tele = screenGui and screenGui:FindFirstChild("TelemetryFrame")
		if tele then tele.Visible = true end
		
		if linearVelocity then linearVelocity.Enabled = true end
		
		-- Синхронізуємо початковий погляд камери
		local look = camera.CFrame.LookVector
		currentYaw = math.atan2(-look.X, -look.Z)
	else
		exitDroneControl()
	end
end

-- Обробка клавіш
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.E then
		spawnDrone()
	elseif input.KeyCode == Enum.KeyCode.M then
		toggleDroneControl()
	end
end)

-- РЕАЛЬНИЙ ОБЕРТ КАМЕРИ МИШЕЮ ЧЕРЕЗ DELTA
UserInputService.InputChanged:Connect(function(input)
	if not isControlling then return end
	
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		-- Чутливість миші налаштована ідеально для плавного огляду
		currentYaw = currentYaw - input.Delta.X * 0.0035
		currentPitch = math.clamp(currentPitch - input.Delta.Y * 0.0035, -0.4, 1.4)
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		cameraDistance = math.clamp(cameraDistance - input.Position.Z * 2.5, 6, 28)
	end
end)

-- Головний цикл фізики, звуків, пропелерів та камери
RunService.RenderStepped:Connect(function(dt)
	-- Обертання лопатей (крутяться швидше, коли дрон у режимі польоту)
	if drone and drone.Parent and #propellerParts > 0 then
		local targetRotSpeed = isControlling and 80 or 8
		currentRotationSpeed = currentRotationSpeed + (targetRotSpeed - currentRotationSpeed) * (dt * 6)
		
		for index, propData in ipairs(propellerParts) do
			if propData.Part and propData.Part.Parent then
				local spinAngle = tick() * currentRotationSpeed * (index % 2 == 0 and 1 or -1)
				propData.Part.CFrame = dronePart.CFrame * propData.Offset * CFrame.Angles(0, spinAngle, 0)
			end
		end
	end
	
	if not isControlling or not dronePart or not dronePart.Parent then return end
	
	-- Звукові ефекти двигуна
	droneSound.Volume = 0.85
	droneSound.Pitch = 1.0 + math.min(dronePart.AssemblyLinearVelocity.Magnitude / 35, 1.0)
	
	-- Оновлення позиції камери навколо дрона
	local rotCF = CFrame.Angles(0, currentYaw, 0) * CFrame.Angles(currentPitch, 0, 0)
	local camPos = dronePart.Position + (rotCF * Vector3.new(0, 0, cameraDistance))
	camera.CFrame = CFrame.new(camPos, dronePart.Position + Vector3.new(0, 0.6, 0))
	
	-- Розрахунок векторів руху відносно камери
	local flatRot = CFrame.Angles(0, currentYaw, 0)
	local forward = flatRot * Vector3.new(0, 0, -1)
	local right = flatRot * Vector3.new(1, 0, 0)
	
	local moveDir = Vector3.new(0, 0, 0)
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + forward end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - forward end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - right end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + right end
	
	local verticalSpeed = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		verticalSpeed = LIFT_SPEED
	elseif UserInputService:IsKeyDown(Enum.KeyCode.Q) then
		verticalSpeed = -LIFT_SPEED
	end
	
	-- Плавна зміна швидкості (інерція)
	local targetVelocity = (moveDir * MAX_SPEED) + Vector3.new(0, verticalSpeed, 0)
	linearVelocity.VectorVelocity = linearVelocity.VectorVelocity:Lerp(targetVelocity, math.clamp(dt * ACCELERATION, 0, 1))
	
	-- Нахил дрона у бік руху для красивої фізики
	local tiltX = moveDir:Dot(forward) * 0.3
	local tiltZ = -moveDir:Dot(right) * 0.3
	alignOrientation.CFrame = CFrame.new(dronePart.Position) * flatRot * CFrame.Angles(tiltX, 0, tiltZ)
	
	-- Оновлення телеметрії на екрані
	if speedLabel and heightLabel then
		local currentSpeed = math.floor(dronePart.AssemblyLinearVelocity.Magnitude * 1.5)
		local currentHeight = math.floor(dronePart.Position.Y)
		speedLabel.Text = "Швидкість: " .. currentSpeed .. " км/год"
		heightLabel.Text = "Висота: " .. currentHeight .. " м"
	end
end)
