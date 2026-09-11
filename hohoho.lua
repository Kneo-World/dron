-- =====================================================================================
-- ULTIMATE PROFESSIONAL DRONE SYSTEM (FULL PHYSICS, STABILIZATION & SOUNDS)
-- =====================================================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Константи управління
local DRONE_MASS = 6
local MAX_SPEED = 50
local LIFT_SPEED = 30
local ROTATION_SPEED = 2.5

-- Змінні стану
local drone = nil
local isControlling = false
local dronePart = nil
local droneHumanoid = nil
local originalCFrame = nil
local skyBoxPart = nil

-- Фізичні об'єкти
local attachment = nil
local vectorForce = nil
local alignOrientation = nil
local droneSound = nil
local windSound = nil

-- Обертання і кути
local currentYaw = 0
local currentPitch = 0
local cameraDistance = 12
local currentRotationSpeed = 0
local propellerParts = {}

-- UI
local screenGui = nil
local mainControlFrame = nil
local isUIVisible = true

local function getSkyBox()
	if skyBoxPart and skyBoxPart.Parent then return skyBoxPart end
	skyBoxPart = Instance.new("Part")
	skyBoxPart.Name = "PlayerSkyBoxSafeZone"
	skyBoxPart.Size = Vector3.new(30, 3, 30)
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
	screenGui.Name = "UltimateDroneGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100
	
	local targetParent = player:FindFirstChild("PlayerGui") or CoreGui
	screenGui.Parent = targetParent
	
	mainControlFrame = Instance.new("Frame")
	mainControlFrame.Size = UDim2.new(0, 450, 0, 160)
	mainControlFrame.Position = UDim2.new(0.5, -225, 1, -180)
	mainControlFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	mainControlFrame.BackgroundTransparency = 0.25
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
	title.TextSize = 15
	title.Font = Enum.Font.GothamBold
	title.Text = "ULTIMATE DRONE SYSTEM [M - Вихід]"
	title.Parent = mainControlFrame
	
	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -20, 0, 100)
	desc.Position = UDim2.new(0, 10, 0, 40)
	desc.BackgroundTransparency = 1
	desc.TextColor3 = Color3.fromRGB(200, 210, 230)
	desc.TextSize = 13
	desc.Font = Enum.Font.Gotham
	desc.TextWrapped = true
	desc.Text = "WASD - Рух з урахуванням інерції\nSpace / Q - Зліт та спуск у висоту\nКоліщатко миші - Зум камери\nE - Спавн / Знищення дрона"
	desc.Parent = mainControlFrame
	
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Size = UDim2.new(0, 130, 0, 30)
	toggleBtn.Position = UDim2.new(1, -140, 0, 12)
	toggleBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleBtn.TextSize = 12
	toggleBtn.Font = Enum.Font.GothamBold
	toggleBtn.Text = "Сховати UI"
	toggleBtn.Parent = screenGui
	
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = toggleBtn
	
	toggleBtn.MouseButton1Click:Connect(function()
		isUIVisible = not isUIVisible
		if mainControlFrame then mainControlFrame.Visible = isUIVisible and isControlling end
		toggleBtn.Text = isUIVisible and "Сховати UI" or "Відкрити UI"
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
		print("Дрон знищено.")
		return
	end
	
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart
	
	drone = Instance.new("Model")
	drone.Name = "UltimateQuadcopter"
	drone.Parent = Workspace
	
	dronePart = Instance.new("Part")
	dronePart.Name = "HumanoidRootPart"
	dronePart.Size = Vector3.new(2.8, 0.9, 2.8)
	dronePart.CFrame = rootPart.CFrame + rootPart.CFrame.LookVector * 6 + Vector3.new(0, 3, 0)
	dronePart.Material = Enum.Material.SmoothPlastic
	dronePart.BrickColor = BrickColor.new("Dark stone grey")
	dronePart.Shape = Enum.PartType.Cylinder
	dronePart.Anchored = false
	dronePart.CanCollide = true
	dronePart.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.3, 0.1, 1, 1)
	dronePart.Parent = drone
	
	droneHumanoid = Instance.new("Humanoid")
	droneHumanoid.MaxHealth = 100
	droneHumanoid.Health = 100
	droneHumanoid.PlatformStand = true
	droneHumanoid.Parent = drone
	
	attachment = Instance.new("Attachment")
	attachment.Parent = dronePart
	
	vectorForce = Instance.new("VectorForce")
	vectorForce.Attachment0 = attachment
	vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
	vectorForce.Force = Vector3.new(0, DRONE_MASS * Workspace.Gravity, 0)
	vectorForce.Parent = dronePart
	
	alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Attachment0 = attachment
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.MaxTorque = 100000
	alignOrientation.Responsiveness = 20
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
		prop.Size = Vector3.new(1.6, 0.08, 0.35)
		prop.BrickColor = BrickColor.new("Really black")
		prop.Material = Enum.Material.Neon
		prop.Anchored = false
		prop.CanCollide = false
		prop.Parent = drone
		
		local angle = math.rad(i * 90)
		local offset = CFrame.new(math.cos(angle) * 1.3, 0.5, math.sin(angle) * 1.3)
		prop.CFrame = dronePart.CFrame * offset
		
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = dronePart
		weld.Part1 = prop
		weld.Parent = dronePart
		
		table.insert(propellerParts, {Part = prop, Offset = offset})
	end
	
	drone.PrimaryPart = dronePart
	setupUI()
	print("Ультимативний дрон створено успішно!")
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
		vectorForce.Force = Vector3.new(0, DRONE_MASS * Workspace.Gravity, 0)
	end
	if droneSound then
		droneSound.Volume = 0
	end
	if mainControlFrame then mainControlFrame.Visible = false end
end

local function toggleDroneControl()
	if not drone or not dronePart then 
		print("Спочатку заспавни дрон клавішею E!")
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
		
		local look = camera.CFrame.LookVector
		currentYaw = math.atan2(-look.X, -look.Z)
		currentPitch = 0.3
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

UserInputService.InputChanged:Connect(function(input)
	if not isControlling then return end
	
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		currentYaw = currentYaw - input.Delta.X * 0.003
		currentPitch = math.clamp(currentPitch - input.Delta.Y * 0.003, -0.2, 1.4)
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		cameraDistance = math.clamp(cameraDistance - input.Position.Z * 2, 6, 25)
	end
end)

-- Рендер-цикл обробки фізики, звуків та плавної камери
RunService.RenderStepped:Connect(function(dt)
	if drone and drone.Parent and #propellerParts > 0 then
		local targetRotSpeed = isControlling and 60 or 5
		currentRotationSpeed = currentRotationSpeed + (targetRotSpeed - currentRotationSpeed) * (dt * 5)
		
		for index, propData in ipairs(propellerParts) do
			if propData.Part and propData.Part.Parent then
				local spinAngle = tick() * currentRotationSpeed * (index % 2 == 0 and 1 or -1)
				propData.Part.CFrame = dronePart.CFrame * propData.Offset * CFrame.Angles(0, spinAngle, 0)
			end
		end
	end
	
	if not isControlling or not dronePart or not dronePart.Parent then return end
	
	droneSound.Volume = 0.8
	droneSound.Pitch = 1.1 + math.min(dronePart.AssemblyLinearVelocity.Magnitude / 35, 0.9)
	
	local rotCF = CFrame.Angles(0, currentYaw, 0) * CFrame.Angles(currentPitch, 0, 0)
	local camPos = dronePart.Position + (rotCF * Vector3.new(0, 0, cameraDistance))
	camera.CFrame = CFrame.new(camPos, dronePart.Position + Vector3.new(0, 0.5, 0))
	
	local moveDir = Vector3.new(0, 0, 0)
	local flatRot = CFrame.Angles(0, currentYaw, 0)
	local forward = flatRot * Vector3.new(0, 0, -1)
	local right = flatRot * Vector3.new(1, 0, 0)
	
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + forward end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - forward end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - right end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + right end
	
	local verticalForce = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		verticalForce = DRONE_MASS * Workspace.Gravity * 0.9
	elseif UserInputService:IsKeyDown(Enum.KeyCode.Q) then
		verticalForce = -DRONE_MASS * Workspace.Gravity * 0.5
	end
	
	local targetForce = Vector3.new(0, DRONE_MASS * Workspace.Gravity + verticalForce, 0) + (moveDir * (DRONE_MASS * 30))
	vectorForce.Force = vectorForce.Force:Lerp(targetForce, math.clamp(dt * 10, 0, 1))
	
	local tiltX = moveDir:Dot(forward) * 0.3
	local tiltZ = -moveDir:Dot(right) * 0.3
	alignOrientation.CFrame = CFrame.new(dronePart.Position) * flatRot * CFrame.Angles(tiltX, 0, tiltZ)
end)
