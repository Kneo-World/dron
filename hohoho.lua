local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local drone = nil
local isControlling = false
local droneBody = nil
local droneBodyGyro = nil
local droneBodyVelocity = nil

-- Параметри польоту дрона
local maxSpeed = 35
local acceleration = 8
local currentVelocity = Vector3.new(0, 0, 0)
local liftSpeed = 20

-- Спавн дрона на клавішу E
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.E then
		if drone and drone.Parent then
			drone:Destroy()
			drone = nil
			isControlling = false
			camera.CameraType = Enum.CameraType.Custom
			return
		end
		
		local character = player.Character
		if not character or not character:FindFirstChild("HumanoidRootPart") then return end
		local rootPart = character.HumanoidRootPart
		
		-- Створюємо модель дрона
		drone = Instance.new("Model")
		drone.Name = "PlayerDrone"
		drone.Parent = Workspace
		
		local mainPart = Instance.new("Part")
		mainPart.Name = "HumanoidRootPart"
		mainPart.Size = Vector3.new(2, 0.8, 2)
		mainPart.Position = rootPart.Position + rootPart.CFrame.LookVector * 5 + Vector3.new(0, 3, 0)
		mainPart.Material = Enum.Material.SmoothPlastic
		mainPart.BrickColor = BrickColor.new("Dark stone grey")
		mainPart.Shape = Enum.PartType.Cylinder
		mainPart.Parent = drone
		
		drone.PrimaryPart = mainPart
		
		-- Додаємо BodyVelocity та BodyGyro для плавного керування
		droneBodyVelocity = Instance.new("BodyVelocity")
		droneBodyVelocity.MaxForce = Vector3.new(40000, 40000, 40000)
		droneBodyVelocity.Velocity = Vector3.new(0, 0, 0)
		droneBodyVelocity.Parent = mainPart
		
		droneBodyGyro = Instance.new("BodyGyro")
		droneBodyGyro.MaxTorque = Vector3.new(40000, 40000, 40000)
		droneBodyGyro.P = 3000
		droneBodyGyro.Parent = mainPart
		
		print("Дрон заспавнено! Натисни M для керування.")
		
	elseif input.KeyCode == Enum.KeyCode.M then
		if not drone or not drone.PrimaryPart then return end
		
		isControlling = not isControlling
		
		if isControlling then
			camera.CameraType = Enum.CameraType.Scriptable
			print("Керування дроном активовано.")
		else
			camera.CameraType = Enum.CameraType.Custom
			droneBodyVelocity.Velocity = Vector3.new(0, 0, 0)
			currentVelocity = Vector3.new(0, 0, 0)
			print("Керування дроном вимкнено.")
		end
	end
end)

-- Головний цикл фізики та польоту
RunService.RenderStepped:Connect(function(dt)
	if not isControlling or not drone or not drone.PrimaryPart then return end
	
	local mainPart = drone.PrimaryPart
	
	-- Напрямок камери
	local camLook = camera.CFrame.LookVector
	local camRight = camera.CFrame.RightVector
	
	-- Визначаємо натиснуті клавіши (WASD + Space / LeftControl)
	local moveDir = Vector3.new(0, 0, 0)
	
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		moveDir = moveDir + camLook
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		moveDir = moveDir - camLook
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		moveDir = moveDir - camRight
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		moveDir = moveDir + camRight
	end
	
	-- Висота (Space - вверх, LeftControl - вниз)
	local verticalMove = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		verticalMove = liftSpeed
	elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		verticalMove = -liftSpeed
	end
	
	-- Розрахунок реалістичної інерції (плавний розгін та гальмування)
	local targetVelocity = Vector3.new(moveDir.X * maxSpeed, verticalMove, moveDir.Z * maxSpeed)
	currentVelocity = currentVelocity:Lerp(targetVelocity, math.clamp(acceleration * dt, 0, 1))
	
	droneBodyVelocity.Velocity = currentVelocity
	
	-- Нахил дрона в бік руху для ефекту реалізму
	local tiltLook = Vector3.new(camLook.X, 0, camLook.Z).Unit
	if moveDir.Magnitude > 0 then
		tiltLook = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
	end
	
	droneBodyGyro.CFrame = CFrame.new(mainPart.Position, mainPart.Position + tiltLook) * CFrame.Angles(0, 0, -currentVelocity.X * 0.03)
	
	-- Тримаємо камеру позаду/зверху дрона
	camera.CFrame = CFrame.new(mainPart.Position - camLook * 8 + Vector3.new(0, 3, 0), mainPart.Position + Vector3.new(0, 1, 0))
end)
