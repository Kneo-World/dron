local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local drone = nil
local isControlling = false
local dronePart = nil
local originalCFrame = nil
local skyBoxPart = nil

-- Параметри польоту
local maxSpeed = 35
local acceleration = 10
local currentVelocity = Vector3.new(0, 0, 0)
local liftSpeed = 20

-- Створюємо «коробку в небі» для оригінального персонажа, щоб він там сидів
local function getSkyBox()
	if skyBoxPart and skyBoxPart.Parent then return skyBoxPart end
	skyBoxPart = Instance.new("Part")
	skyBoxPart.Name = "PlayerSkyBox"
	skyBoxPart.Size = Vector3.new(10, 1, 10)
	skyBoxPart.Position = Vector3.new(0, 5000, 0)
	skyBoxPart.Anchored = true
	skyBoxPart.Transparency = 1
	skyBoxPart.CanCollide = true
	skyBoxPart.Parent = Workspace
	return skyBoxPart
end

-- Спавн дрона на E та вселення на M
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.E then
		if drone and drone.Parent then
			-- Виходимо з режиму дрона при видаленні
			if isControlling then
				local character = player.Character
				if character and character:FindFirstChild("HumanoidRootPart") and originalCFrame then
					character.HumanoidRootPart.CFrame = originalCFrame
					camera.CameraSubject = character:FindFirstChildOfClass("Humanoid")
					camera.CameraType = Enum.CameraType.Custom
				end
				isControlling = false
			end
			drone:Destroy()
			drone = nil
			dronePart = nil
			return
		end
		
		local character = player.Character
		if not character or not character:FindFirstChild("HumanoidRootPart") then return end
		local rootPart = character.HumanoidRootPart
		
		originalCFrame = rootPart.CFrame
		
		-- Створюємо дрон із коду (з підтримкою тачів та взаємодій)
		drone = Instance.new("Model")
		drone.Name = "FullControlDrone"
		drone.Parent = Workspace
		
		dronePart = Instance.new("Part")
		dronePart.Name = "HumanoidRootPart" -- Називаємо як головну частину, щоб гра сприймала її коректно
		dronePart.Size = Vector3.new(2.5, 0.8, 2.5)
		dronePart.CFrame = rootPart.CFrame + rootPart.CFrame.LookVector * 5 + Vector3.new(0, 3, 0)
		dronePart.Material = Enum.Material.SmoothPlastic
		dronePart.BrickColor = BrickColor.new("Dark stone grey")
		dronePart.Shape = Enum.PartType.Cylinder
		dronePart.Anchored = false
		dronePart.CanCollide = true
		dronePart.RootPriority = 10
		dronePart.Parent = drone
		
		-- Додаємо Humanoid до дрона, щоб гра вважала його повноцінним живим об'єктом (працюють тачі, сенсори, тулки тощо)
		local humanoid = Instance.new("Humanoid")
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		humanoid.PlatformStand = true -- Щоб гуманоїд не падав сам по собі
		humanoid.Parent = drone
		
		drone.PrimaryPart = dronePart
		print("Дрон заспавнено! Натисни M для вселення.")
		
	elseif input.KeyCode == Enum.KeyCode.M then
		if not drone or not dronePart then return end
		
		isControlling = not isControlling
		local character = player.Character
		if not character or not character:FindFirstChild("HumanoidRootPart") then return end
		local rootPart = character.HumanoidRootPart
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		
		if isControlling then
			-- Ховаємо реального персонажа в коробку високо в небо
			originalCFrame = rootPart.CFrame
			local box = getSkyBox()
			rootPart.CFrame = box.CFrame + Vector3.new(0, 3, 0)
			rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			
			-- Перемикаємо камеру на дрон
			camera.CameraSubject = drone:FindFirstChildOfClass("Humanoid")
			camera.CameraType = Enum.CameraType.Custom
			
			-- Вмикаємо стандартний режим керування камерою Роблокса (можна крутити мишкою)
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			print("Повне вселення в дрон активовано! Персонаж надійно схований в небі.")
		else
			-- Повертаємо персонажа на місце
			rootPart.CFrame = originalCFrame
			rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			
			camera.CameraSubject = humanoid
			camera.CameraType = Enum.CameraType.Custom
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			
			dronePart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			currentVelocity = Vector3.new(0, 0, 0)
			print("Вселення вимкнено, ви повернені в тіло.")
		end
	end
end)

-- Головний цикл фізики польоту дрона
RunService.RenderStepped:Connect(function(dt)
	if not isControlling or not drone or not dronePart or not dronePart.Parent then return end
	
	-- Беремо напрямок камери поточного виду
	local camLook = camera.CFrame.LookVector
	local camRight = camera.CFrame.RightVector
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
	
	-- Розрахунок інерції та фізики польоту
	local targetVelocity = Vector3.new(moveDir.X * maxSpeed, verticalMove, moveDir.Z * maxSpeed)
	currentVelocity = currentVelocity:Lerp(targetVelocity, math.clamp(acceleration * dt, 0, 1))
	
	dronePart.AssemblyLinearVelocity = currentVelocity
	dronePart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	
	-- Плавний нахил у бік руху
	if moveDir.Magnitude > 0 then
		local targetCFrame = CFrame.new(dronePart.Position, dronePart.Position + moveDir)
		dronePart.CFrame = dronePart.CFrame:Lerp(targetCFrame, math.clamp(10 * dt, 0, 1))
	end
end)
