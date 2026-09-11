-- =====================================================================================
-- ADVANCED DRONE SYSTEM (FULL IMMERSION & CONTROLLER)
-- =====================================================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Змінні стану системи
local drone = nil
local isControlling = false
local dronePart = nil
local droneHumanoid = nil
local originalCFrame = nil
local skyBoxPart = nil

-- Компоненти візуалу дрона (лопаті)
local propellerParts = {}

-- Параметри польоту та фізики
local maxSpeed = 45
local acceleration = 12
local currentVelocity = Vector3.new(0, 0, 0)
local liftSpeed = 25
local currentRotationSpeed = 0

-- Змінні для керування камерою мишкою
local cameraAngleX = 0
local cameraAngleY = 0

-- GUI елементи керування (можна згорнути праворуч у меню)
local screenGui = nil
local mainControlFrame = nil
local isUIVisible = true

-- Створення або отримання безпечної коробки в небі для оригінального персонажа
local function getSkyBox()
	if skyBoxPart and skyBoxPart.Parent then 
		return skyBoxPart 
	end
	
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

-- Побудова візуального інтерфейсу (GUI) керування на екрані з можливістю згортання праворуч
local function setupDroneUI()
	if screenGui then 
		screenGui:Destroy() 
	end
	
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DroneControlGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100
	
	-- Перевірка куди безпечніше закинути GUI (PlayerGui чи CoreGui якщо дозволено)
	local targetParent = player:FindFirstChild("PlayerGui")
	if targetParent then
		screenGui.Parent = targetParent
	else
		screenGui.Parent = CoreGui
	end
	
	-- Головна панель керування (знизу по центру)
	mainControlFrame = Instance.new("Frame")
	mainControlFrame.Name = "ControlPanel"
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
	
	-- Заголовок панелі
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 30)
	titleLabel.Position = UDim2.new(0, 0, 0, 5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = 16
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = "КВАДРОКОПТЕР: ПОВНЕ ВСЕЛЕННЯ [M - Вихід]"
	titleLabel.Parent = mainControlFrame
	
	-- Підказка по управлінню
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, -20, 0, 85)
	infoLabel.Position = UDim2.new(0, 10, 0, 35)
	infoLabel.BackgroundTransparency = 1
	infoLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
	infoLabel.TextSize = 13
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextWrapped = true
	infoLabel.Text = "W A S D - Рух вперед/назад/вбік\nSpace - Зліт вище | Q - Опуститися вниз\nМиша / ПКМ - Огляд камерою\nE - Видалити дрон"
	infoLabel.Parent = mainControlFrame
	
	-- Кнопка згортання/вимкнення панелі справа в меню (як ви і просили)
	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ToggleUIMenuButton"
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
		if mainControlFrame then
			mainControlFrame.Visible = isUIVisible and isControlling
		end
		toggleButton.Text = isUIVisible ? "Сховати меню [UI]" "Відкрити меню [UI]"
	end)
end

-- Функція спавну дрона (на клавішу E)
local function spawnDrone()
	if drone and drone.Parent then
		-- Якщо керували ним в цей момент — виходимо
		if isControlling then
			exitDroneControl()
		end
		drone:Destroy()
		drone = nil
		dronePart = nil
		droneHumanoid = nil
		propellerParts = {}
		if screenGui then 
			screenGui:Destroy() 
			screenGui = nil 
		end
		print("Дрон успішно знищено.")
		return
	end
	
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then 
		return 
	end
	local rootPart = character.HumanoidRootPart
	
	-- Створюємо модель дрона з коду
	drone = Instance.new("Model")
	drone.Name = "AdvancedQuadcopterDrone"
	drone.Parent = Workspace
	
	-- Головна фізична частина (корпус)
	dronePart = Instance.new("Part")
	dronePart.Name = "HumanoidRootPart" -- Назва важлива для систем гри
	dronePart.Size = Vector3.new(2.8, 1.0, 2.8)
	dronePart.CFrame = rootPart.CFrame + rootPart.CFrame.LookVector * 6 + Vector3.new(0, 3, 0)
	dronePart.Material = Enum.Material.SmoothPlastic
	dronePart.BrickColor = BrickColor.new("Dark stone grey")
	dronePart.Shape = Enum.PartType.Cylinder
	dronePart.Anchored = false
	dronePart.CanCollide = true
	dronePart.RootPriority = 10
	dronePart.Parent = drone
	
	-- Додаємо Humanoid для того, щоб гра сприймала це як повноцінне тіло (працюють сенсори, тачі, TouchInterest тощо)
	droneHumanoid = Instance.new("Humanoid")
	droneHumanoid.MaxHealth = 100
	droneHumanoid.Health = 100
	droneHumanoid.PlatformStand = true
	droneHumanoid.Parent = drone
	
	-- Створюємо візуальні деталі (пропелери, які будуть крутитися)
	propellerParts = {}
	for i = 1, 4 do
		local prop = Instance.new("Part")
		prop.Name = "Propeller_" .. i
		prop.Size = Vector3.new(1.4, 0.1, 0.35)
		prop.BrickColor = BrickColor.new("Really black")
		prop.Material = Enum.Material.Neon
		prop.Anchored = false
		prop.CanCollide = false
		prop.Parent = drone
		
		-- Розставляємо хрест-навхрест навколо корпусу
		local angle = math.rad(i * 90)
		local offset = CFrame.new(math.cos(angle) * 1.3, 0.55, math.sin(angle) * 1.3)
		prop.CFrame = dronePart.CFrame * offset
		
		-- Жорстко зварюємо лопать із головним корпусом через WeldConstraint
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = dronePart
		weld.Part1 = prop
		weld.Parent = dronePart
		
		table.insert(propellerParts, {Part = prop, Offset = offset})
	end
	
	drone.PrimaryPart = dronePart
	setupDroneUI()
	print("Квадрокоптер заспавнено! Натисни M для вселення.")
end

-- Функція активації повного вселення (на клавішу M)
local function toggleDroneControl()
	if not drone or not dronePart or not droneHumanoid then 
		print("Спочатку спавни дрон на клавішу E!")
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
		-- 1. Ховаємо справжнього персонажа в безпечну коробку високо в небо
		originalCFrame = rootPart.CFrame
		local safeBox = getSkyBox()
		rootPart.CFrame = safeBox.CFrame + Vector3.new(0, 3, 0)
		rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		
		-- Відключаємо рух реального персонажа на час вселення
		if humanoid then
			humanoid.PlatformStand = true
		end
		
		-- 2. Переносимо камеру безпосередньо на гуманоїд дрона (повне вселення)
		camera.CameraSubject = droneHumanoid
		camera.CameraType = Enum.CameraType.Custom
		
		-- 3. Налаштовуємо управління мишкою
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		
		-- Показуємо UI панель
		if mainControlFrame then
			mainControlFrame.Visible = isUIVisible
		end
		
		print("Успішне вселення в квадрокоптер! Оригінальний персонаж надійно захований в небі.")
	else
		exitDroneControl()
	end
end

-- Функція виходу з режиму дрона та повернення тіла
function exitDroneControl()
	isControlling = false
	local character = player.Character
	
	if character and character:FindFirstChild("HumanoidRootPart") and originalCFrame then
		local rootPart = character.HumanoidRootPart
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		
		-- Повертаємо гравця на земну позицію
		rootPart.CFrame = originalCFrame
		rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		
		if humanoid then
			humanoid.PlatformStand = false
			camera.CameraSubject = humanoid
		end
		
		camera.CameraType = Enum.CameraType.Custom
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	
	-- Зупиняємо рух дрона
	if dronePart then
		dronePart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		dronePart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end
	currentVelocity = Vector3.new(0, 0, 0)
	
	if mainControlFrame then
		mainControlFrame.Visible = false
	end
	
	print("Вихід з квадрокоптера виконано. Ви повернулися в тіло.")
end

-- Відстеження натискання клавіш (E та M)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.E then
		spawnDrone()
	elseif input.KeyCode == Enum.KeyCode.M then
		toggleDroneControl()
	end
end)

-- Головний фізичний цикл польоту та анімації лопатей (працює кожний кадр)
RunService.RenderStepped:Connect(function(dt)
	-- Оновлюємо швидкість обертання візуальних пропелерів для крутого ефекту
	if drone and drone.Parent and #propellerParts > 0 then
		local targetRotSpeed = isControlling and 35 or 5
		currentRotationSpeed = currentRotationSpeed + (targetRotSpeed - currentRotationSpeed) * (dt * 5)
		
		for index, propData in ipairs(propellerParts) do
			if propData.Part and propData.Part.Parent then
				-- Крутимо лопаті навколо їх осі
				local spinAngle = tick() * currentRotationSpeed * (index % 2 == 0 and 1 or -1)
				local localSpin = CFrame.Angles(0, spinAngle, 0)
				propData.Part.CFrame = dronePart.CFrame * propData.Offset * localSpin
			end
		end
	end
	
	-- Якщо режим керування не активований — далі нічого не робимо
	if not isControlling or not drone or not dronePart or not dronePart.Parent then 
		return 
	end
	
	-- Зчитуємо напрямок камери
	local camLook = camera.CFrame.LookVector
	local camRight = camera.CFrame.RightVector
	local camFlatLook = Vector3.new(camLook.X, 0, camLook.Z).Unit
	local camFlatRight = Vector3.new(camRight.X, 0, camRight.Z).Unit
	
	-- Опитування клавіш руху (WASD)
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
	
	-- Висота польоту (Space — вверх, Q — вниз)
	local verticalMove = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		verticalMove = liftSpeed
	elseif UserInputService:IsKeyDown(Enum.KeyCode.Q) then
		verticalMove = -liftSpeed
	end
	
	-- Плавний розгін та інерція (реалістична фізика квадрокоптера)
	local targetVelocity = Vector3.new(moveDir.X * maxSpeed, verticalMove, moveDir.Z * maxSpeed)
	currentVelocity = currentVelocity:Lerp(targetVelocity, math.clamp(acceleration * dt, 0, 1))
	
	-- Застосовуємо швидкість безпосередньо до фізичного тіла дрона
	dronePart.AssemblyLinearVelocity = currentVelocity
	dronePart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	
	-- Нахиляємо корпус у бік руху для красивого ефекту під час польоту
	if moveDir.Magnitude > 0 then
		local targetCFrame = CFrame.new(dronePart.Position, dronePart.Position + moveDir)
		dronePart.CFrame = dronePart.CFrame:Lerp(targetCFrame, math.clamp(12 * dt, 0, 1))
	end
end)
