--// PAINEL ESP: Saint + Fragment + DogBane + Rokakaka + Players + Horse Speed + Anti Lag
--// LocalScript em StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

--// CONFIG
local CONFIG = {
	PANEL_KEY = Enum.KeyCode.K,

	SAINT_KEYWORD = "saint",
	SAINT_COLOR = Color3.fromRGB(0, 200, 255),       -- ESP da peça saint (ciano)

	FRAGMENT_KEYWORD = "fragment",
	FRAGMENT_EXCLUDE = "meteor",                     -- ignora nomes com essa palavra
	FRAGMENT_COLOR = Color3.fromRGB(255, 140, 0),    -- ESP fragment (laranja)

	DOGBANE_KEYWORD = "dogbane",
	DOGBANE_COLOR = Color3.fromRGB(60, 220, 90),     -- ESP dogbane (verde)

	ROKAKAKA_KEYWORD = "rokakaka",
	ROKAKAKA_COLOR = Color3.fromRGB(180, 90, 255),   -- ESP rokakaka (roxo)

	PLAYER_COLOR = Color3.fromRGB(255, 40, 40),      -- jogadores normais (vermelho)
	GOLD_COLOR = Color3.fromRGB(255, 215, 0),        -- jogador com a saint (dourado)

	--// HORSE SPEED
	HORSE_KEYWORDS = { "horse", "cavalo" },          -- nomes que identificam o cavalo
	HORSE_MAX_SPEED = 150,                           -- velocidade aplicada enquanto está no cavalo
	HORSE_APPLY_INTERVAL = 1,                        -- a cada quantos segundos aplica a velocidade
	HORSE_RAY_DISTANCE = 10,                         -- distância pra baixo pra detectar "em cima do cavalo"

	--// ANTI LAG
	ANTILAG_MATERIAL = Enum.Material.SmoothPlastic,  -- material "lego" aplicado em tudo
	ANTILAG_PARTICLE_KEEP = 0.15,                    -- fração da taxa de partículas que continua (0 = remove todas)
	ANTILAG_BATCH = 400,                             -- objetos processados por frame (evita travada ao ligar)
}

local player = Players.LocalPlayer

--// GUI base
local gui = Instance.new("ScreenGui")
gui.Name = "ESPPanelGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

--// Helpers de ESP
local function makeHighlight(target, color)
	local h = Instance.new("Highlight")
	h.Name = "ESP_Highlight"
	h.FillColor = color
	h.FillTransparency = 0.6
	h.OutlineColor = color
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee = target
	h.Parent = target
	return h
end

local function makeLabel(adornee, text, color, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ESP_Label"
	billboard.Size = UDim2.fromOffset(220, 30)
	billboard.StudsOffset = offset
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = math.huge
	billboard.Adornee = adornee
	billboard.Parent = gui

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.Text = text
	label.Parent = billboard

	return billboard, label
end

local function distanceTo(part)
	local cam = workspace.CurrentCamera
	if not cam then return 0 end
	return math.floor((part.Position - cam.CFrame.Position).Magnitude)
end

local function isInsideCharacter(inst)
	local m = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
	while m do
		if Players:GetPlayerFromCharacter(m) then return true end
		m = m:FindFirstAncestorOfClass("Model")
	end
	return false
end

-- minúsculo e sem espaço/_/- (pega "DogBane", "Dog Bane", "dog_bane"...)
local function normalize(name)
	return (name:lower():gsub("[%s_%-]", ""))
end

----------------------------------------------------------------
--// FUNÇÃO 1: ESP SAINT (peça no mapa)
----------------------------------------------------------------
local SaintESP = { Enabled = false }
local saintTracked = {}   -- [inst] = {highlight, billboard, label, adornee}
local saintConns = {}

local function saintMatches(inst)
	return (inst:IsA("BasePart") or inst:IsA("Model"))
		and inst.Name:lower():find(CONFIG.SAINT_KEYWORD, 1, true) ~= nil
		and not isInsideCharacter(inst)
end

local function saintAdornee(inst)
	if inst:IsA("BasePart") then return inst end
	return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
end

local function saintHasTrackedAncestor(inst)
	local p = inst.Parent
	while p and p ~= workspace do
		if saintTracked[p] then return true end
		p = p.Parent
	end
	return false
end

local function saintRemove(inst)
	local d = saintTracked[inst]
	if not d then return end
	if d.highlight then d.highlight:Destroy() end
	if d.billboard then d.billboard:Destroy() end
	saintTracked[inst] = nil
end

local function saintAdd(inst)
	if saintTracked[inst] or not saintMatches(inst) or saintHasTrackedAncestor(inst) then return end
	local adornee = saintAdornee(inst)
	if not adornee then return end

	local billboard, label = makeLabel(adornee, inst.Name, CONFIG.SAINT_COLOR, Vector3.new(0, 2, 0))
	saintTracked[inst] = {
		highlight = makeHighlight(inst, CONFIG.SAINT_COLOR),
		billboard = billboard,
		label = label,
		adornee = adornee,
	}
end

function SaintESP.Enable()
	if SaintESP.Enabled then return end
	SaintESP.Enabled = true

	for _, inst in ipairs(workspace:GetDescendants()) do
		saintAdd(inst)
	end

	table.insert(saintConns, workspace.DescendantAdded:Connect(function(inst)
		task.defer(saintAdd, inst)
	end))
	table.insert(saintConns, workspace.DescendantRemoving:Connect(saintRemove))
	table.insert(saintConns, RunService.RenderStepped:Connect(function()
		for inst, d in pairs(saintTracked) do
			if d.adornee and d.adornee:IsDescendantOf(workspace) and not isInsideCharacter(inst) then
				d.label.Text = string.format("%s [%d]", inst.Name, distanceTo(d.adornee))
			else
				saintRemove(inst)
			end
		end
	end))
end

function SaintESP.Disable()
	if not SaintESP.Enabled then return end
	SaintESP.Enabled = false

	for _, c in ipairs(saintConns) do c:Disconnect() end
	table.clear(saintConns)
	for inst in pairs(saintTracked) do saintRemove(inst) end
end

function SaintESP.Set(state)
	if state then SaintESP.Enable() else SaintESP.Disable() end
end

----------------------------------------------------------------
--// FUNÇÃO 2: ESP FRAGMENT (laranja, ignora "meteor")
----------------------------------------------------------------
local FragmentESP = { Enabled = false }
local fragmentTracked = {}   -- [inst] = {highlight, billboard, label, adornee}
local fragmentConns = {}

local function fragmentNameHasExcluded(name)
	return name:lower():find(CONFIG.FRAGMENT_EXCLUDE, 1, true) ~= nil
end

local function fragmentHasExcludedAncestor(inst)
	local p = inst.Parent
	while p and p ~= workspace do
		if fragmentNameHasExcluded(p.Name) then return true end
		p = p.Parent
	end
	return false
end

local function fragmentMatches(inst)
	return (inst:IsA("BasePart") or inst:IsA("Model"))
		and inst.Name:lower():find(CONFIG.FRAGMENT_KEYWORD, 1, true) ~= nil
		and not fragmentNameHasExcluded(inst.Name)
		and not fragmentHasExcludedAncestor(inst)
		and not isInsideCharacter(inst)
end

local function fragmentAdornee(inst)
	if inst:IsA("BasePart") then return inst end
	return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
end

local function fragmentHasTrackedAncestor(inst)
	local p = inst.Parent
	while p and p ~= workspace do
		if fragmentTracked[p] then return true end
		p = p.Parent
	end
	return false
end

local function fragmentRemove(inst)
	local d = fragmentTracked[inst]
	if not d then return end
	if d.highlight then d.highlight:Destroy() end
	if d.billboard then d.billboard:Destroy() end
	fragmentTracked[inst] = nil
end

local function fragmentAdd(inst)
	if fragmentTracked[inst] or not fragmentMatches(inst) or fragmentHasTrackedAncestor(inst) then return end
	local adornee = fragmentAdornee(inst)
	if not adornee then return end

	local billboard, label = makeLabel(adornee, inst.Name, CONFIG.FRAGMENT_COLOR, Vector3.new(0, 2, 0))
	fragmentTracked[inst] = {
		highlight = makeHighlight(inst, CONFIG.FRAGMENT_COLOR),
		billboard = billboard,
		label = label,
		adornee = adornee,
	}
end

function FragmentESP.Enable()
	if FragmentESP.Enabled then return end
	FragmentESP.Enabled = true

	for _, inst in ipairs(workspace:GetDescendants()) do
		fragmentAdd(inst)
	end

	table.insert(fragmentConns, workspace.DescendantAdded:Connect(function(inst)
		task.defer(fragmentAdd, inst)
	end))
	table.insert(fragmentConns, workspace.DescendantRemoving:Connect(fragmentRemove))
	table.insert(fragmentConns, RunService.RenderStepped:Connect(function()
		for inst, d in pairs(fragmentTracked) do
			if d.adornee and d.adornee:IsDescendantOf(workspace) and not isInsideCharacter(inst) then
				d.label.Text = string.format("%s [%d]", inst.Name, distanceTo(d.adornee))
			else
				fragmentRemove(inst)
			end
		end
	end))
end

function FragmentESP.Disable()
	if not FragmentESP.Enabled then return end
	FragmentESP.Enabled = false

	for _, c in ipairs(fragmentConns) do c:Disconnect() end
	table.clear(fragmentConns)
	for inst in pairs(fragmentTracked) do fragmentRemove(inst) end
end

function FragmentESP.Set(state)
	if state then FragmentESP.Enable() else FragmentESP.Disable() end
end

----------------------------------------------------------------
--// FUNÇÃO 3: ESP DOGBANE (verde)
----------------------------------------------------------------
local DogBaneESP = { Enabled = false }
local dogbaneTracked = {}   -- [inst] = {highlight, billboard, label, adornee}
local dogbaneConns = {}

local function dogbaneMatches(inst)
	return (inst:IsA("BasePart") or inst:IsA("Model"))
		and normalize(inst.Name):find(CONFIG.DOGBANE_KEYWORD, 1, true) ~= nil
		and not isInsideCharacter(inst)
end

local function dogbaneAdornee(inst)
	if inst:IsA("BasePart") then return inst end
	return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
end

local function dogbaneHasTrackedAncestor(inst)
	local p = inst.Parent
	while p and p ~= workspace do
		if dogbaneTracked[p] then return true end
		p = p.Parent
	end
	return false
end

local function dogbaneRemove(inst)
	local d = dogbaneTracked[inst]
	if not d then return end
	if d.highlight then d.highlight:Destroy() end
	if d.billboard then d.billboard:Destroy() end
	dogbaneTracked[inst] = nil
end

local function dogbaneAdd(inst)
	if dogbaneTracked[inst] or not dogbaneMatches(inst) or dogbaneHasTrackedAncestor(inst) then return end
	local adornee = dogbaneAdornee(inst)
	if not adornee then return end

	local billboard, label = makeLabel(adornee, inst.Name, CONFIG.DOGBANE_COLOR, Vector3.new(0, 2, 0))
	dogbaneTracked[inst] = {
		highlight = makeHighlight(inst, CONFIG.DOGBANE_COLOR),
		billboard = billboard,
		label = label,
		adornee = adornee,
	}
end

function DogBaneESP.Enable()
	if DogBaneESP.Enabled then return end
	DogBaneESP.Enabled = true

	for _, inst in ipairs(workspace:GetDescendants()) do
		dogbaneAdd(inst)
	end

	table.insert(dogbaneConns, workspace.DescendantAdded:Connect(function(inst)
		task.defer(dogbaneAdd, inst)
	end))
	table.insert(dogbaneConns, workspace.DescendantRemoving:Connect(dogbaneRemove))
	table.insert(dogbaneConns, RunService.RenderStepped:Connect(function()
		for inst, d in pairs(dogbaneTracked) do
			if d.adornee and d.adornee:IsDescendantOf(workspace) and not isInsideCharacter(inst) then
				d.label.Text = string.format("%s [%d]", inst.Name, distanceTo(d.adornee))
			else
				dogbaneRemove(inst)
			end
		end
	end))
end

function DogBaneESP.Disable()
	if not DogBaneESP.Enabled then return end
	DogBaneESP.Enabled = false

	for _, c in ipairs(dogbaneConns) do c:Disconnect() end
	table.clear(dogbaneConns)
	for inst in pairs(dogbaneTracked) do dogbaneRemove(inst) end
end

function DogBaneESP.Set(state)
	if state then DogBaneESP.Enable() else DogBaneESP.Disable() end
end

----------------------------------------------------------------
--// FUNÇÃO 4: ESP ROKAKAKA (roxo)
----------------------------------------------------------------
local RokakakaESP = { Enabled = false }
local rokakakaTracked = {}   -- [inst] = {highlight, billboard, label, adornee}
local rokakakaConns = {}

local function rokakakaMatches(inst)
	return (inst:IsA("BasePart") or inst:IsA("Model"))
		and normalize(inst.Name):find(CONFIG.ROKAKAKA_KEYWORD, 1, true) ~= nil
		and not isInsideCharacter(inst)
end

local function rokakakaAdornee(inst)
	if inst:IsA("BasePart") then return inst end
	return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
end

local function rokakakaHasTrackedAncestor(inst)
	local p = inst.Parent
	while p and p ~= workspace do
		if rokakakaTracked[p] then return true end
		p = p.Parent
	end
	return false
end

local function rokakakaRemove(inst)
	local d = rokakakaTracked[inst]
	if not d then return end
	if d.highlight then d.highlight:Destroy() end
	if d.billboard then d.billboard:Destroy() end
	rokakakaTracked[inst] = nil
end

local function rokakakaAdd(inst)
	if rokakakaTracked[inst] or not rokakakaMatches(inst) or rokakakaHasTrackedAncestor(inst) then return end
	local adornee = rokakakaAdornee(inst)
	if not adornee then return end

	local billboard, label = makeLabel(adornee, inst.Name, CONFIG.ROKAKAKA_COLOR, Vector3.new(0, 2, 0))
	rokakakaTracked[inst] = {
		highlight = makeHighlight(inst, CONFIG.ROKAKAKA_COLOR),
		billboard = billboard,
		label = label,
		adornee = adornee,
	}
end

function RokakakaESP.Enable()
	if RokakakaESP.Enabled then return end
	RokakakaESP.Enabled = true

	for _, inst in ipairs(workspace:GetDescendants()) do
		rokakakaAdd(inst)
	end

	table.insert(rokakakaConns, workspace.DescendantAdded:Connect(function(inst)
		task.defer(rokakakaAdd, inst)
	end))
	table.insert(rokakakaConns, workspace.DescendantRemoving:Connect(rokakakaRemove))
	table.insert(rokakakaConns, RunService.RenderStepped:Connect(function()
		for inst, d in pairs(rokakakaTracked) do
			if d.adornee and d.adornee:IsDescendantOf(workspace) and not isInsideCharacter(inst) then
				d.label.Text = string.format("%s [%d]", inst.Name, distanceTo(d.adornee))
			else
				rokakakaRemove(inst)
			end
		end
	end))
end

function RokakakaESP.Disable()
	if not RokakakaESP.Enabled then return end
	RokakakaESP.Enabled = false

	for _, c in ipairs(rokakakaConns) do c:Disconnect() end
	table.clear(rokakakaConns)
	for inst in pairs(rokakakaTracked) do rokakakaRemove(inst) end
end

function RokakakaESP.Set(state)
	if state then RokakakaESP.Enable() else RokakakaESP.Disable() end
end

----------------------------------------------------------------
--// FUNÇÃO 5: ESP PLAYERS (vermelho; dourado se estiver com a saint)
----------------------------------------------------------------
local PlayerESP = { Enabled = false }
local playerData = {}    -- [plr] = {char, head, highlight, billboard, label, hasSaint, conns}
local playerConns = {}   -- [plr] = {conexões}
local playerGlobalConns = {}

local function charHasSaint(char)
	for _, inst in ipairs(char:GetDescendants()) do
		if inst.Name:lower():find(CONFIG.SAINT_KEYWORD, 1, true) then
			return true
		end
	end
	return false
end

local function playerRefresh(plr)
	local d = playerData[plr]
	if not d or not d.char.Parent then return end

	d.hasSaint = charHasSaint(d.char)
	local color = d.hasSaint and CONFIG.GOLD_COLOR or CONFIG.PLAYER_COLOR

	d.highlight.FillColor = color
	d.highlight.OutlineColor = color
	d.label.TextColor3 = color
end

local function playerClear(plr)
	local d = playerData[plr]
	if not d then return end
	for _, c in ipairs(d.conns) do c:Disconnect() end
	if d.highlight then d.highlight:Destroy() end
	if d.billboard then d.billboard:Destroy() end
	playerData[plr] = nil
end

local function playerApply(plr, char)
	playerClear(plr)
	if not PlayerESP.Enabled then return end

	local head = char:WaitForChild("Head", 5)
	if not head or not PlayerESP.Enabled or not char.Parent then return end

	local billboard, label = makeLabel(head, plr.Name, CONFIG.PLAYER_COLOR, Vector3.new(0, 2.5, 0))
	local d = {
		char = char,
		head = head,
		highlight = makeHighlight(char, CONFIG.PLAYER_COLOR),
		billboard = billboard,
		label = label,
		hasSaint = false,
		conns = {},
	}
	playerData[plr] = d

	-- reavalia sempre que algo entra/sai do personagem (equipar, largar, pegar)
	local function schedule()
		task.defer(playerRefresh, plr)
	end
	table.insert(d.conns, char.DescendantAdded:Connect(schedule))
	table.insert(d.conns, char.DescendantRemoving:Connect(schedule))

	playerRefresh(plr)
end

local function playerWatch(plr)
	if plr == player or playerConns[plr] then return end

	local conns = {}
	playerConns[plr] = conns

	table.insert(conns, plr.CharacterAdded:Connect(function(char)
		playerApply(plr, char)
	end))
	table.insert(conns, plr.CharacterRemoving:Connect(function()
		playerClear(plr)
	end))

	if plr.Character then
		task.spawn(playerApply, plr, plr.Character)
	end
end

local function playerUnwatch(plr)
	playerClear(plr)
	local conns = playerConns[plr]
	if conns then
		for _, c in ipairs(conns) do c:Disconnect() end
		playerConns[plr] = nil
	end
end

function PlayerESP.Enable()
	if PlayerESP.Enabled then return end
	PlayerESP.Enabled = true

	for _, plr in ipairs(Players:GetPlayers()) do
		playerWatch(plr)
	end

	table.insert(playerGlobalConns, Players.PlayerAdded:Connect(playerWatch))
	table.insert(playerGlobalConns, Players.PlayerRemoving:Connect(playerUnwatch))
	table.insert(playerGlobalConns, RunService.RenderStepped:Connect(function()
		for plr, d in pairs(playerData) do
			if d.head and d.head.Parent then
				d.label.Text = string.format(
					"%s%s [%d]",
					d.hasSaint and "[SAINT] " or "",
					plr.Name,
					distanceTo(d.head)
				)
			else
				playerClear(plr)
			end
		end
	end))
end

function PlayerESP.Disable()
	if not PlayerESP.Enabled then return end
	PlayerESP.Enabled = false

	for _, c in ipairs(playerGlobalConns) do c:Disconnect() end
	table.clear(playerGlobalConns)

	for plr in pairs(playerConns) do playerUnwatch(plr) end
	for plr in pairs(playerData) do playerClear(plr) end
end

function PlayerESP.Set(state)
	if state then PlayerESP.Enable() else PlayerESP.Disable() end
end

----------------------------------------------------------------
--// FUNÇÃO 6: HORSE SPEED (no cavalo: aplica 150 a cada 1 segundo)
----------------------------------------------------------------
local HorseSpeed = { Enabled = false }

local horseState = {
	model = nil,      -- cavalo detectado (nil = não está montado)
	targets = {},     -- {inst, prop, orig, cur}
	timer = 0,        -- timer da detecção
	applyTimer = 0,   -- timer da aplicação da velocidade
}

local function horseNameMatches(name)
	name = name:lower()
	for _, kw in ipairs(CONFIG.HORSE_KEYWORDS) do
		if name:find(kw, 1, true) then return true end
	end
	return false
end

-- acha o Model do cavalo a partir de uma parte (ignora personagens de jogadores)
local function getHorseModel(part)
	local m = part:FindFirstAncestorOfClass("Model")
	while m and m ~= workspace do
		if not Players:GetPlayerFromCharacter(m) and horseNameMatches(m.Name) then
			return m
		end
		m = m:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- detecta se o player está no cavalo: sentado, preso por solda, ou em cima (raycast)
local function horseDetect(char, hum, root)
	-- 1) sentado num assento do cavalo
	local seat = hum.SeatPart
	if seat then
		local m = getHorseModel(seat)
		if m then return m, seat end
		if horseNameMatches(seat.Name) and seat.Parent and seat.Parent:IsA("Model") then
			return seat.Parent, seat
		end
	end

	-- 2) personagem ligado ao cavalo por solda/joint
	for _, part in ipairs(root:GetConnectedParts(true)) do
		if not part:IsDescendantOf(char) then
			local m = getHorseModel(part)
			if m then return m, nil end
		end
	end

	-- 3) em cima do cavalo (raio pra baixo)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local result = workspace:Raycast(root.Position, Vector3.new(0, -CONFIG.HORSE_RAY_DISTANCE, 0), params)
	if result then
		local m = getHorseModel(result.Instance)
		if m then return m, nil end
	end

	return nil, nil
end

local function horseAddTarget(inst, prop)
	local v = inst[prop]
	if type(v) == "number" and v > 0 then
		table.insert(horseState.targets, { inst = inst, prop = prop, orig = v, cur = v })
	end
end

-- aplica a velocidade (150) em tudo que está sendo controlado
local function horseApply()
	for _, t in ipairs(horseState.targets) do
		if t.inst.Parent then
			t.cur = CONFIG.HORSE_MAX_SPEED
			t.inst[t.prop] = t.cur
		end
	end
end

local function horseMount(hum, model, seat)
	horseState.model = model
	table.clear(horseState.targets)

	-- velocidade do próprio player
	horseAddTarget(hum, "WalkSpeed")

	-- VehicleSeat (velocidade máxima do assento)
	local vseat = (seat and seat:IsA("VehicleSeat")) and seat or model:FindFirstChildWhichIsA("VehicleSeat", true)
	if vseat then
		horseAddTarget(vseat, "MaxSpeed")
	end

	-- Humanoid do próprio cavalo (se tiver)
	local horseHum = model:FindFirstChildWhichIsA("Humanoid", true)
	if horseHum and horseHum ~= hum then
		horseAddTarget(horseHum, "WalkSpeed")
	end

	-- aplica na hora que monta; depois repete a cada HORSE_APPLY_INTERVAL
	horseState.applyTimer = 0
	horseApply()
end

local function horseRestore()
	for _, t in ipairs(horseState.targets) do
		-- só restaura se o jogo não mudou o valor por conta própria
		if t.inst.Parent and math.abs(t.inst[t.prop] - t.cur) < 1 then
			t.inst[t.prop] = t.orig
		end
	end
	table.clear(horseState.targets)
	horseState.model = nil
	horseState.applyTimer = 0
end

local function horseStep(dt)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		horseRestore()
		return
	end

	-- detecta 10x por segundo (não precisa ser todo frame)
	horseState.timer += dt
	if horseState.timer >= 0.1 then
		horseState.timer = 0

		local model, seat = horseDetect(char, hum, root)
		if not model then
			horseRestore()
		elseif model ~= horseState.model then
			horseRestore()
			horseMount(hum, model, seat)
		end
	end

	-- enquanto estiver no cavalo, aplica a velocidade a cada 1 segundo
	if horseState.model then
		horseState.applyTimer += dt
		if horseState.applyTimer >= CONFIG.HORSE_APPLY_INTERVAL then
			horseState.applyTimer = 0
			horseApply()
		end
	end
end

function HorseSpeed.Enable()
	if HorseSpeed.Enabled then return end
	HorseSpeed.Enabled = true

	horseState.timer = 1 -- detecta já no primeiro frame
	RunService:BindToRenderStep("ESPHorseSpeed", Enum.RenderPriority.Last.Value, horseStep)
end

function HorseSpeed.Disable()
	if not HorseSpeed.Enabled then return end
	HorseSpeed.Enabled = false

	RunService:UnbindFromRenderStep("ESPHorseSpeed")
	horseRestore()
end

function HorseSpeed.Set(state)
	if state then HorseSpeed.Enable() else HorseSpeed.Disable() end
end

----------------------------------------------------------------
--// FUNÇÃO 7: ANTI LAG (tudo vira "lego" liso + efeitos pesados removidos)
----------------------------------------------------------------
local AntiLag = { Enabled = false }
local antilagOriginal = setmetatable({}, { __mode = "k" })   -- [inst] = {propriedade = valor original}
local antilagConns = {}
local antilagRun = 0   -- muda a cada liga/desliga pra cancelar processamentos em andamento

-- muda uma propriedade guardando o valor original (pra poder restaurar)
local function antilagSet(inst, prop, value)
	local ok, current = pcall(function()
		return inst[prop]
	end)
	if not ok then return end

	local saved = antilagOriginal[inst]
	if not saved then
		saved = {}
		antilagOriginal[inst] = saved
	end
	if saved[prop] == nil then
		saved[prop] = current
	end

	pcall(function()
		inst[prop] = value
	end)
end

local function antilagProcess(inst)
	if antilagOriginal[inst] or inst:IsA("Terrain") then return end

	if inst:IsA("BasePart") then
		-- peça lisa, sem brilho, sem sombra
		antilagSet(inst, "Material", CONFIG.ANTILAG_MATERIAL)
		antilagSet(inst, "Reflectance", 0)
		antilagSet(inst, "CastShadow", false)
		if inst:IsA("MeshPart") then
			antilagSet(inst, "TextureID", "")
			antilagSet(inst, "RenderFidelity", Enum.RenderFidelity.Performance)
		end

	elseif inst:IsA("Decal") or inst:IsA("Texture") then
		antilagSet(inst, "Transparency", 1)

	elseif inst:IsA("SurfaceAppearance") then
		antilagSet(inst, "ColorMap", "")
		antilagSet(inst, "NormalMap", "")
		antilagSet(inst, "MetalnessMap", "")
		antilagSet(inst, "RoughnessMap", "")

	elseif inst:IsA("SpecialMesh") then
		antilagSet(inst, "TextureId", "")

	elseif inst:IsA("Shirt") then
		antilagSet(inst, "ShirtTemplate", "")
	elseif inst:IsA("Pants") then
		antilagSet(inst, "PantsTemplate", "")
	elseif inst:IsA("ShirtGraphic") then
		antilagSet(inst, "Graphic", "")

	elseif inst:IsA("ParticleEmitter") then
		if CONFIG.ANTILAG_PARTICLE_KEEP <= 0 then
			antilagSet(inst, "Enabled", false)
		else
			antilagSet(inst, "Rate", inst.Rate * CONFIG.ANTILAG_PARTICLE_KEEP)
		end

	elseif inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("Fire")
		or inst:IsA("Smoke") or inst:IsA("Sparkles") then
		antilagSet(inst, "Enabled", false)

	elseif inst:IsA("Explosion") then
		antilagSet(inst, "Visible", false)

	elseif inst:IsA("Light") then
		antilagSet(inst, "Enabled", false)

	elseif inst:IsA("PostEffect") then
		-- Blur, Bloom, SunRays, ColorCorrection, DepthOfField
		antilagSet(inst, "Enabled", false)

	elseif inst:IsA("Atmosphere") then
		antilagSet(inst, "Density", 0)
		antilagSet(inst, "Haze", 0)
		antilagSet(inst, "Glare", 0)
	end
end

local function antilagGlobal()
	antilagSet(Lighting, "GlobalShadows", false)

	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		antilagSet(terrain, "WaterWaveSize", 0)
		antilagSet(terrain, "WaterWaveSpeed", 0)
		antilagSet(terrain, "WaterReflectance", 0)
	end

	for _, inst in ipairs(Lighting:GetDescendants()) do
		antilagProcess(inst)
	end

	-- qualidade gráfica no mínimo (o Roblox pode não permitir, por isso o pcall)
	pcall(function()
		antilagSet(settings().Rendering, "QualityLevel", Enum.QualityLevel.Level01)
	end)
end

function AntiLag.Enable()
	if AntiLag.Enabled then return end
	AntiLag.Enabled = true
	antilagRun += 1
	local run = antilagRun

	antilagGlobal()

	-- objetos que aparecerem depois também são simplificados
	table.insert(antilagConns, workspace.DescendantAdded:Connect(function(inst)
		task.defer(antilagProcess, inst)
	end))
	table.insert(antilagConns, Lighting.DescendantAdded:Connect(function(inst)
		task.defer(antilagProcess, inst)
	end))

	-- processa o mapa todo aos poucos (sem travar o jogo)
	task.spawn(function()
		local count = 0
		for _, inst in ipairs(workspace:GetDescendants()) do
			if not AntiLag.Enabled or run ~= antilagRun then return end
			antilagProcess(inst)
			count += 1
			if count % CONFIG.ANTILAG_BATCH == 0 then
				task.wait()
			end
		end
	end)
end

function AntiLag.Disable()
	if not AntiLag.Enabled then return end
	AntiLag.Enabled = false
	antilagRun += 1

	for _, c in ipairs(antilagConns) do c:Disconnect() end
	table.clear(antilagConns)

	-- restaura tudo aos poucos
	local items = {}
	for inst, props in pairs(antilagOriginal) do
		table.insert(items, { inst, props })
	end
	table.clear(antilagOriginal)

	task.spawn(function()
		for i, item in ipairs(items) do
			local inst, props = item[1], item[2]
			for prop, value in pairs(props) do
				pcall(function()
					inst[prop] = value
				end)
			end
			if i % CONFIG.ANTILAG_BATCH == 0 then
				task.wait()
			end
		end
	end)
end

function AntiLag.Set(state)
	if state then AntiLag.Enable() else AntiLag.Disable() end
end

----------------------------------------------------------------
--// PAINEL (UI)
----------------------------------------------------------------
local panel = Instance.new("CanvasGroup")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(260, 390)
panel.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
panel.GroupTransparency = 1
panel.Visible = false
panel.Parent = gui

Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(70, 70, 85)
stroke.Thickness = 1
stroke.Parent = panel

local panelScale = Instance.new("UIScale")
panelScale.Scale = 0.85
panelScale.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -24, 0, 30)
title.Position = UDim2.fromOffset(12, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Painel ESP"
title.Parent = panel

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -24, 0, 16)
hint.Position = UDim2.new(0, 12, 1, -22)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextColor3 = Color3.fromRGB(140, 140, 155)
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Text = "Pressione " .. CONFIG.PANEL_KEY.Name .. " para abrir/fechar"
hint.Parent = panel

local list = Instance.new("Frame")
list.Size = UDim2.new(1, -24, 0, 314)
list.Position = UDim2.fromOffset(12, 44)
list.BackgroundTransparency = 1
list.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

--// Interruptor animado
local TOGGLE_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local COLOR_OFF = Color3.fromRGB(70, 70, 82)
local COLOR_ON = Color3.fromRGB(50, 190, 90)

local function createToggle(text, order, onChange)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, 0, 0, 38)
	row.BackgroundColor3 = Color3.fromRGB(36, 36, 44)
	row.AutoButtonColor = false
	row.Text = ""
	row.LayoutOrder = order
	row.Parent = list
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -70, 1, 0)
	label.Position = UDim2.fromOffset(12, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = row

	local track = Instance.new("Frame")
	track.Size = UDim2.fromOffset(42, 22)
	track.Position = UDim2.new(1, -54, 0.5, -11)
	track.BackgroundColor3 = COLOR_OFF
	track.Parent = row
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(18, 18)
	knob.Position = UDim2.fromOffset(2, 2)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Parent = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local state = false

	local function render()
		TweenService:Create(track, TOGGLE_TWEEN, {
			BackgroundColor3 = state and COLOR_ON or COLOR_OFF,
		}):Play()
		TweenService:Create(knob, TOGGLE_TWEEN, {
			Position = state and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2),
		}):Play()
	end

	row.MouseButton1Click:Connect(function()
		state = not state
		render()
		onChange(state)
	end)
end

createToggle("ESP Saint", 1, SaintESP.Set)
createToggle("ESP Fragment", 2, FragmentESP.Set)
createToggle("ESP DogBane", 3, DogBaneESP.Set)
createToggle("ESP Rokakaka", 4, RokakakaESP.Set)
createToggle("ESP Players", 5, PlayerESP.Set)
createToggle("Horse Speed", 6, HorseSpeed.Set)
createToggle("Anti Lag", 7, AntiLag.Set)

--// Abrir/fechar painel com animação
local isOpen = false

local function setPanel(open)
	isOpen = open

	if open then
		panel.Visible = true
		TweenService:Create(panel, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
		TweenService:Create(panelScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	else
		local fade = TweenService:Create(panel, TweenInfo.new(0.15), { GroupTransparency = 1 })
		TweenService:Create(panelScale, TweenInfo.new(0.15), { Scale = 0.85 }):Play()
		fade.Completed:Connect(function()
			if not isOpen then panel.Visible = false end
		end)
		fade:Play()
	end
end

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == CONFIG.PANEL_KEY then
		setPanel(not isOpen)
	end
end)

--// Botão pra abrir o painel (mobile)
local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.fromOffset(56, 32)
openBtn.Position = UDim2.new(0, 10, 0.5, 0)
openBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 13
openBtn.Text = "ESP"
openBtn.Parent = gui
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 8)
openBtn.MouseButton1Click:Connect(function()
	setPanel(not isOpen)
end)
