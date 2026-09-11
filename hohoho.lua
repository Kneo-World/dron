local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local drone = nil
local isControlling = false
local dronePart = nil

-- Параметри польоту
local maxSpeed = 35
local acceleration = 10
local currentVelocity = Vector3.new(0, 0, 0)
local liftSpeed = 20

-- Змінні для керування камерою мишкою
local cameraAngleX = 0
local cameraAngleY = 0

-- Спавн простого дрона на E та перемикання на M
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.E then
		if drone and drone.Parent then
			drone:Destroy()
			drone = nil
			dronePart = nil
			isControlling = false
			camera.CameraType = Enum.CameraType.Custom
			return
		end
		
		local character = player.Character
		if not character or not character:FindFirstChild("HumanoidRootPart") then return end
		local rootPart = character.HumanoidRootPart
		
		-- Програмно створюємо модель дрона прямо в клієнтському скрипті
		drone = Instance.new("Model")
		drone.Name = "CodeDrone"
		drone.Parent = Workspace
		
		-- Головна частина (корпус)
		dronePart = Instance.new("Part")
		dronePart.Name = "DroneRoot"
		dronePart.Size = Vector3.new(2.5, 0.8, 2.5)
		dronePart.CFrame = rootPart.CFrame + rootPart.CFrame.LookVector * 5 + Vector3.new(0, 3, 0)
		dronePart.Material = Enum.Material.SmoothPlastic
		dronePart.BrickColor = BrickColor.new("Dark stone grey")
		dronePart.Shape = Enum.PartType.Cylinder
		dronePart.Anchored = false
		dronePart.CanCollide = true
		dronePart.RootPriority = 10
		dronePart.Parent = drone
		
		-- Додаємо візуальні "пропелери" для краси
		for i = 1, 4 do
			local prop = Instance.new("Part")
			prop.Size = Vector3.new(1.2, 0.1, 0.3)
			prop.BrickColor = BrickColor.new("Really black")
			prop.Anchored = false
			prop.CanCollide = false
			prop.Parent = drone
			
			-- Розставляємо їх навколо корпусу
			local angle = math.rad(i * 90)
			local offset = CFrame.new(math.cos(angle) * 1.2, 0.5, math.sin(angle) * 1.2)
			prop.CFrame = dronePart.CFrame * offset
			
			-- Зварюємо деталі з головним корпусом через WeldConstraint
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = dronePart
			weld.Part1 = prop
			weld.Parent = dronePart
		end
		
		drone.PrimaryPart = dronePart
		print("Дрон успішно створено з коду! Натисни M для керування.")
		
	elseif input.KeyCode == Enum.KeyCode.M then
		if not drone or not dronePart then return end
		
		isControlling = not isControlling
		
		if isControlling then
			camera.CameraType = Enum.CameraType.Scriptable
			local camLook = camera.CFrame.LookVector
			cameraAngleX = math.atan2(-camLook.X, -camLook.Z)
			cameraAngleY = math.asin(camLook.Y)
			
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			print("Керування дроном активовано.")
		else
			camera.CameraType = Enum.CameraType.Custom
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			dronePart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			currentVelocity = Vector3.new(0, 0, 0)
			print("Керування дроном вимкнено.")
		end
	end
end)

-- Обертання камери мишкою
UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if not isControlling then return end
	
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Delta
		cameraAngleX = cameraAngleX - delta.X * 0.003
		cameraAngleY = math.clamp(cameraAngleY - delta.Y * 0.003, -math.rad(80), math.rad(80))
	end
end)

-- Головний цикл фізики польоту
RunService.RenderStepped:Connect(function(dt)
	if not isControlling or not drone or not dronePart or not dronePart.Parent then return end
	
	local rotCFrame = CFrame.Angles(0, cameraAngleX, 0) * CFrame.Angles(cameraAngleY, 0, 0)
	local camLook = rotCFrame.LookVector
	local camRight = rotCFrame.RightVector
	local camFlatLook = Vector3.new(camLook.X, 0, camLook.Z).Unit
	local camFlatRight = Vector3.new(camRight.X, 0, camRight.Z).Unit
	
	-- Керування рухом (WASD)
	local moveDir = Vector3.new(0, 0, 0)
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		moveDir = moveDir + camFlatLook
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		moveDir = moveDir - camFlatLook
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		moveDir = moveDir - camFlatRight
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		moveDir = moveDir + camFlatRight
	end
	
	-- Висота (Space — вверх, Q — вниз)
	local verticalMove = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		verticalMove = liftSpeed
	elseif UserInputService:IsKeyDown(Enum.KeyCode.Q) then
		verticalMove = -liftSpeed
	end
	
	-- Розрахунок інерції
	local targetVelocity = Vector3.new(moveDir.X * maxSpeed, verticalMove, moveDir.Z * maxSpeed)
	currentVelocity = currentVelocity:Lerp(targetVelocity, math.clamp(acceleration * dt, 0, 1))
	
	dronePart.AssemblyLinearVelocity = currentVelocity
	dronePart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	
	-- Повертаємо дрон у напрямку руху
	if moveDir.Magnitude > 0 then
		local targetCFrame = CFrame.new(dronePart.Position, dronePart.Position + moveDir)
		dronePart.CFrame = dronePart.CFrame:Lerp(targetCFrame, math.clamp(10 * dt, 0, 1))
	end
	
	-- Фіксуємо камеру за дроном
	local camPos = dronePart.Position - (camLook * 8) + Vector3.new(0, 2.5, 0)
	camera.CFrame = CFrame.new(camPos, dronePart.Position + Vector3.new(0, 1, 0))
end)
