local Players = game:GetService("Players")


local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local InsertService = game:GetService("InsertService")

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

-- ID твоєї моделі дрона
local droneAssetId = 3465260740

-- Спавн дрона на E та перемикання на M
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
		
		-- Завантажуємо модель із Toolbox
		local success, result = pcall(function()
			return InsertService:LoadAsset(droneAssetId)
		end)
		
		if success and result then
			drone = result
			drone.Name = "AttackDrone"
			drone.Parent = Workspace
			
			if drone.PrimaryPart then
				dronePart = drone.PrimaryPart
			else
				dronePart = drone:FindFirstChildWhichIsA("BasePart", true)
			end
			
			if dronePart then
				for _, part in ipairs(drone:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = false
						part.CanCollide = true
					end
				end
				
				if drone.PrimaryPart then
					drone:SetPrimaryPartCFrame(rootPart.CFrame + rootPart.CFrame.LookVector * 5 + Vector3.new(0, 3, 0))
				else
					dronePart.CFrame = rootPart.CFrame + rootPart.CFrame.LookVector * 5 + Vector3.new(0, 3, 0)
				end
				
				dronePart.RootPriority = 10
				print("Дрон успішно завантажено! Натисни M для керування.")
			else
				warn("У моделі не знайдено жодної детальки (BasePart)!")
				drone:Destroy()
				drone = nil
			end
		else
			warn("Не вдалося завантажити дрон за ID: " .. tostring(result))
		end
		
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
