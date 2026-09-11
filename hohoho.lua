-- =====================================================================================
-- ULTIMATE DRONE SYSTEM WITH WORKING RMB CAMERA
-- =====================================================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

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

-- Змінні камери (як у робочому коді з ПКМ)
local cameraAngleX = 0
local cameraAngleY = 0.3
local isRightMouseDown = false
local cameraDistance = 14

local currentRotationSpeed = 0
local propellerParts = {}

-- UI елементи
local screenGui = nil
local mainControlFrame = nil
local speedLabel = nil
local heightLabel = nil
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
	desc.Text = "• WASD — Плавний рух у боки\n• Space / Q — Набір висоти / Спуск\n• ПКМ (Затиснути) + Рух мишею — Поворот камери\n• Коліщатко миші — Зум камери\n• E — Спавн або знищення дрона"
	desc.Parent = mainControlFrame
	
	-- Телеметрія у верхньому кутку
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
	
	linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Attachment0 = attachment
	linearVelocity.MaxForce = 35000
	linearVelocity.VectorVelocity = Vector3.new(0, 0, 0)
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Enabled = false
	linearVelocity.Parent = dronePart
	
	alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Attachment0 = attachment
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.MaxTorque = 60000
	alignOrientation.Responsiveness = 30
	alignOrientation.Parent = dronePart
	
	droneSound = Instance.new("Sound")
	droneSound.SoundId = "rbxassetid://9114223207"
	droneSound.Looped = true
	droneSound.Volume = 0
	droneSound.Parent = dronePart
	droneSound:Play()
	
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
	
	isRightMouseDown = false
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
		
		if mainControlFrame then mainControlFrame.Visible = isUIVisible end
		local tele = screenGui and screenGui:FindFirstChild("TelemetryFrame")
		if tele then tele.Visible = true end
		
		if linearVelocity then linearVelocity.Enabled = true end
		
		-- Синхронізація кутів камери
		local camLook = camera.CFrame.LookVector
		cameraAngleX = math.atan2(-camLook.X, -camLook.Z)
		cameraAngleY = math.asin(math.clamp(camLook.Y, -1, 1))
	else
		exitDroneControl()
	end
end

-- Обробка клавіш E та M
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.E then
		spawnDrone()
	elseif input.KeyCode == Enum.KeyCode.M then
		toggleDroneControl()
	end
end)

-- Відстеження ПКМ для обертання камери (як у твоєму коді)
UserInputService.InputBegan:Connect(function(input)
	if isControlling and input.UserInputType == Enum.UserInputType.MouseButton2 then
		isRightMouseDown = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isRightMouseDown = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

-- Плавне обертання камери мишкою при затиснутій ПКМ та зум коліщатком
UserInputService.InputChanged:Connect(function(input)
	if not isControlling then return end
	
	if isRightMouseDown and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Delta
		cameraAngleX = cameraAngleX - delta.X * 0.004
		cameraAngleY = math.clamp(cameraAngleY - delta.Y * 0.004, -math.rad(80), math.rad(80))
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		cameraDistance = math.clamp(cameraDistance - input.Position.Z * 2.5, 6, 28)
	end
end)

-- Головний цикл фізики, звуків, пропелерів та камери
RunService.RenderStepped:Connect(function(dt)
	-- Лопаті пропелерів
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
	
	-- Звук двигуна
	droneSound.Volume = 0.85
	droneSound.Pitch = 1.0 + math.min(dronePart.AssemblyLinearVelocity.Magnitude / 35, 1.0)
	
	-- Розрахунок орієнтації камери з твого коду
	local rotCFrame = CFrame.Angles(0, cameraAngleX, 0) * CFrame.Angles(cameraAngleY, 0, 0)
	local camLook = rotCFrame.LookVector
	local camRight = rotCFrame.RightVector
	local camFlatLook = Vector3.new(camLook.X, 0, camLook.Z).Unit
	local camFlatRight = Vector3.new(camRight.X, 0, camRight.Z).Unit
	
	-- Керування рухом WASD відносно камери
	local moveDir = Vector3.new(0, 0, 0)
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camFlatLook end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camFlatLook end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camFlatRight end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camFlatRight end
	
	local verticalSpeed = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		verticalSpeed = LIFT_SPEED
	elseif UserInputService:IsKeyDown(Enum.KeyCode.Q) then
		verticalSpeed = -LIFT_SPEED
	end
	
	-- Плавний рух через LinearVelocity
	local targetVelocity = (moveDir * MAX_SPEED) + Vector3.new(0, verticalSpeed, 0)
	linearVelocity.VectorVelocity = linearVelocity.VectorVelocity:Lerp(targetVelocity, math.clamp(dt * ACCELERATION, 0, 1))
	
	-- Нахил дрона у бік руху
	local flatRot = CFrame.Angles(0, cameraAngleX, 0)
	local forward = flatRot * Vector3.new(0, 0, -1)
	local right = flatRot * Vector3.new(1, 0, 0)
	local tiltX = moveDir:Dot(forward) * 0.3
	local tiltZ = -moveDir:Dot(right) * 0.3
	alignOrientation.CFrame = CFrame.new(dronePart.Position) * flatRot * CFrame.Angles(tiltX, 0, tiltZ)
	
	-- Фіксуємо камеру за дроном з урахуванням дистанції та зуму коліщатком
	local camPos = dronePart.Position - (camLook * cameraDistance) + Vector3.new(0, 2.5, 0)
	camera.CFrame = CFrame.new(camPos, dronePart.Position + Vector3.new(0, 1, 0))
	
	-- Оновлення телеметрії на екрані
	if speedLabel and heightLabel then
		local currentSpeed = math.floor(dronePart.AssemblyLinearVelocity.Magnitude * 1.5)
		local currentHeight = math.floor(dronePart.Position.Y)
		speedLabel.Text = "Швидкість: " .. currentSpeed .. " км/год"
		heightLabel.Text = "Висота: " .. currentHeight .. " м"
	end
end)
