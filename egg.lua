--// XHUB: Secret (ESP + teleporte 1x) + Players + Speed + Ponto de Teleporte
--// LocalScript em StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--// CONFIG
local CONFIG = {
	PANEL_KEY = Enum.KeyCode.X,

	-- ESP do item "secret" (rosa); ao detectar o item, teleporta 1x em cima dele
	SECRET_KEYWORDS = { "secret" },
	SECRET_COLOR = Color3.fromRGB(255, 60, 170),

	-- usado só pra pintar de dourado o jogador que estiver com a saint
	SAINT_KEYWORD = "saint",

	PLAYER_COLOR = Color3.fromRGB(255, 40, 40),      -- jogadores normais (vermelho)
	GOLD_COLOR = Color3.fromRGB(255, 215, 0),        -- jogador com a saint (dourado)

	--// SPEED (aplicado direto no player)
	SPEED_VALUE = 150,                               -- WalkSpeed enquanto estiver ligado
	SPEED_APPLY_INTERVAL = 1,                        -- a cada quantos segundos reaplica (o jogo costuma resetar)

	--// DEBUG: true = imprime no console (F9) os nomes de objetos parecidos com itens
	DEBUG_SCAN = false,
	SCAN_WORDS = { "secret", "seed", "sprout", "plant", "fruit", "roka", "dogban", "broto", "flower" },
}

local player = Players.LocalPlayer

--// GUI base
local gui = Instance.new("ScreenGui")
gui.Name = "XhubGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
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

-- true se o nome (normalizado) contiver qualquer keyword da lista
local function matchesAny(name, keywords)
	local n = normalize(name)
	for _, kw in ipairs(keywords) do
		if n:find(kw, 1, true) then return true end
	end
	return false
end

----------------------------------------------------------------
--// FUNÇÃO 1: ESP SECRET (rosa; teleporta 1x em cima do item achado)
----------------------------------------------------------------
local SecretESP = { Enabled = false }
local secretTracked = {}   -- [inst] = {highlight, billboard, label, adornee}
local secretConns = {}
local secretTimer = 0

local function secretMatches(inst)
	if not (inst:IsA("BasePart") or inst:IsA("Model")) then return false end
	if isInsideCharacter(inst) then return false end
	return matchesAny(inst.Name, CONFIG.SECRET_KEYWORDS)
end

local function secretAdornee(inst)
	if inst:IsA("BasePart") then return inst end
	return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
end

local function secretHasTrackedAncestor(inst)
	local p = inst.Parent
	while p and p ~= workspace do
		if secretTracked[p] then return true end
		p = p.Parent
	end
	return false
end

local function secretRemove(inst)
	local d = secretTracked[inst]
	if not d then return end
	if d.highlight then d.highlight:Destroy() end
	if d.billboard then d.billboard:Destroy() end
	secretTracked[inst] = nil
end

-- sobe em cima do item (centro + meia altura + 3 studs) e zera a velocidade
local function secretTeleportOnce(inst)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local cf, size
	if inst:IsA("Model") then
		cf, size = inst:GetBoundingBox()
	else
		cf, size = inst.CFrame, inst.Size
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.5 + 3, 0))
end

local function secretAdd(inst)
	if secretTracked[inst] or not secretMatches(inst) or secretHasTrackedAncestor(inst) then return end
	local adornee = secretAdornee(inst)
	if not adornee then return end

	local billboard, label = makeLabel(adornee, inst.Name, CONFIG.SECRET_COLOR, Vector3.new(0, 2, 0))
	secretTracked[inst] = {
		highlight = makeHighlight(inst, CONFIG.SECRET_COLOR),
		billboard = billboard,
		label = label,
		adornee = adornee,
	}
	secretTeleportOnce(inst)   -- 1 teleporte por item encontrado
end

function SecretESP.Enable()
	if SecretESP.Enabled then return end
	SecretESP.Enabled = true

	for _, inst in ipairs(workspace:GetDescendants()) do
		secretAdd(inst)
	end

	table.insert(secretConns, workspace.DescendantAdded:Connect(function(inst)
		task.defer(secretAdd, inst)
	end))
	table.insert(secretConns, workspace.DescendantRemoving:Connect(secretRemove))
	table.insert(secretConns, RunService.RenderStepped:Connect(function(dt)
		secretTimer += dt
		if secretTimer < 0.1 then return end
		secretTimer = 0
		for inst, d in pairs(secretTracked) do
			if d.adornee and d.adornee:IsDescendantOf(workspace) and not isInsideCharacter(inst) then
				d.label.Text = string.format("%s [%d]", inst.Name, distanceTo(d.adornee))
			else
				secretRemove(inst)
			end
		end
	end))
end

function SecretESP.Disable()
	if not SecretESP.Enabled then return end
	SecretESP.Enabled = false

	for _, c in ipairs(secretConns) do c:Disconnect() end
	table.clear(secretConns)
	for inst in pairs(secretTracked) do secretRemove(inst) end
end

function SecretESP.Set(state)
	if state then SecretESP.Enable() else SecretESP.Disable() end
end

----------------------------------------------------------------
--// FUNÇÃO 2: ESP PLAYERS (vermelho; dourado se estiver com a saint)
----------------------------------------------------------------
local PlayerESP = { Enabled = false }
local playerData = {}    -- [plr] = {char, head, highlight, billboard, label, hasSaint, conns}
local playerConns = {}   -- [plr] = {conexões}
local playerGlobalConns = {}
local playerTimer = 0

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
	table.insert(playerGlobalConns, RunService.RenderStepped:Connect(function(dt)
		playerTimer += dt
		if playerTimer < 0.1 then return end
		playerTimer = 0
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
--// FUNÇÃO 3: PLAYER SPEED (aplica WalkSpeed direto no player)
----------------------------------------------------------------
local SpeedHack = { Enabled = false }
local speedState = { hum = nil, orig = 16 }

local function speedApply()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	-- guarda a velocidade original do personagem atual (pra restaurar ao desligar)
	if speedState.hum ~= hum then
		speedState.hum = hum
		speedState.orig = hum.WalkSpeed
	end
	hum.WalkSpeed = CONFIG.SPEED_VALUE
end

local function speedRestore()
	if speedState.hum and speedState.hum.Parent then
		speedState.hum.WalkSpeed = speedState.orig
	end
	speedState.hum = nil
end

function SpeedHack.Enable()
	if SpeedHack.Enabled then return end
	SpeedHack.Enabled = true

	-- reaplica de tempos em tempos (o jogo costuma resetar o WalkSpeed)
	task.spawn(function()
		while SpeedHack.Enabled do
			speedApply()
			task.wait(CONFIG.SPEED_APPLY_INTERVAL)
		end
	end)
end

function SpeedHack.Disable()
	if not SpeedHack.Enabled then return end
	SpeedHack.Enabled = false
	speedRestore()
end

function SpeedHack.Set(state)
	if state then SpeedHack.Enable() else SpeedHack.Disable() end
end

----------------------------------------------------------------
--// PAINEL (UI) — XHUB
----------------------------------------------------------------
local ACCENT = Color3.fromRGB(235, 45, 45)          -- vermelho Xhub
local ACCENT_SOFT = Color3.fromRGB(255, 95, 95)
local BG_PANEL = Color3.fromRGB(16, 16, 22)
local BG_HEADER = Color3.fromRGB(22, 22, 30)
local BG_ROW = Color3.fromRGB(28, 28, 36)
local BG_ROW_HOVER = Color3.fromRGB(40, 40, 50)
local TEXT_DIM = Color3.fromRGB(130, 130, 145)
local COLOR_OFF = Color3.fromRGB(60, 60, 72)

local FAST_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ícone do Xhub: X vermelho desenhado com duas barras giradas
-- (o glifo "✕" em texto vira quadrado nas fontes do Roblox)
local function makeXIcon(parent, size, thickness)
	local icon = Instance.new("Frame")
	icon.Name = "XIcon"
	icon.BackgroundTransparency = 1
	icon.Size = size
	icon.Parent = parent
	for _, rot in ipairs({ 45, -45 }) do
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(0.92, 0, 0, thickness or 3)
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Rotation = rot
		bar.BackgroundColor3 = ACCENT
		bar.BorderSizePixel = 0
		bar.Parent = icon
		Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
	end
	return icon
end

local panel = Instance.new("CanvasGroup")
panel.Name = "XhubPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(280, 384)
panel.BackgroundColor3 = BG_PANEL
panel.GroupTransparency = 1
panel.Visible = false
panel.Active = true
panel.Parent = gui

Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(65, 65, 80)
stroke.Thickness = 1
stroke.Parent = panel

local panelScale = Instance.new("UIScale")
panelScale.Scale = 0.85
panelScale.Parent = panel

--// Header com o ícone Xhub
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 54)
header.BackgroundColor3 = BG_HEADER
header.BorderSizePixel = 0
header.Active = true
header.Parent = panel
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 16)

-- deixa a parte de baixo do header reta (cobre os cantos arredondados)
local headerFix = Instance.new("Frame")
headerFix.AnchorPoint = Vector2.new(0, 1)
headerFix.Position = UDim2.new(0, 0, 1, 0)
headerFix.Size = UDim2.new(1, 0, 0, 18)
headerFix.BackgroundColor3 = BG_HEADER
headerFix.BorderSizePixel = 0
headerFix.Parent = header

-- linha vermelha embaixo do header
local accentLine = Instance.new("Frame")
accentLine.AnchorPoint = Vector2.new(0, 1)
accentLine.Position = UDim2.new(0, 0, 1, 0)
accentLine.Size = UDim2.new(1, 0, 0, 2)
accentLine.BackgroundColor3 = ACCENT
accentLine.BorderSizePixel = 0
accentLine.Parent = header

local headerIcon = makeXIcon(header, UDim2.fromOffset(36, 36), 4)
headerIcon.Position = UDim2.fromOffset(12, 7)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -96, 0, 24)
title.Position = UDim2.fromOffset(50, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 20
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Xhub"
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -96, 0, 14)
subtitle.Position = UDim2.fromOffset(51, 31)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 10
subtitle.TextColor3 = TEXT_DIM
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Text = "painel esp"
subtitle.Parent = header

--// Arrastar o painel pelo header (mouse e touch), preso dentro da tela
do
	local draggingPanel = false
	local dragStart, panelStartPos

	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			draggingPanel = true
			dragStart = input.Position
			panelStartPos = panel.Position
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if not draggingPanel then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local vp = workspace.CurrentCamera.ViewportSize
		local size = panel.AbsoluteSize
		local d = input.Position - dragStart
		local x = vp.X * panelStartPos.X.Scale + panelStartPos.X.Offset + d.X
		local y = vp.Y * panelStartPos.Y.Scale + panelStartPos.Y.Offset + d.Y
		-- AnchorPoint é 0.5,0.5: Position = centro do painel
		x = math.clamp(x, size.X * 0.5, math.max(size.X * 0.5, vp.X - size.X * 0.5))
		y = math.clamp(y, size.Y * 0.5, math.max(size.Y * 0.5, vp.Y - size.Y * 0.5))
		panel.Position = UDim2.new(0, x, 0, y)
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			draggingPanel = false
		end
	end)
end

--// Lista de toggles
local list = Instance.new("Frame")
list.Size = UDim2.new(1, -24, 0, 290)
list.Position = UDim2.fromOffset(12, 62)
list.BackgroundTransparency = 1
list.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -24, 0, 16)
hint.Position = UDim2.new(0, 12, 1, -24)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextColor3 = TEXT_DIM
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Text = CONFIG.PANEL_KEY.Name .. " para abrir/fechar"
hint.Parent = panel

local toggleRows = {}

--// Interruptor animado (com hover)
local function createToggle(text, order, onChange)
	-- CanvasGroup pra linha inteira aparecer/desaparecer com fade
	local holder = Instance.new("CanvasGroup")
	holder.Size = UDim2.new(1, 0, 0, 40)
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = order
	holder.Parent = list
	table.insert(toggleRows, holder)

	local row = Instance.new("TextButton")
	row.Size = UDim2.fromScale(1, 1)
	row.BackgroundColor3 = BG_ROW
	row.AutoButtonColor = false
	row.Text = ""
	row.Parent = holder
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

	-- detalhe vermelho na esquerda
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromOffset(3, 16)
	bar.Position = UDim2.new(0, 6, 0.5, -8)
	bar.BackgroundColor3 = ACCENT
	bar.BorderSizePixel = 0
	bar.Parent = row
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -84, 1, 0)
	label.Position = UDim2.fromOffset(16, 0)
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
	track.BorderSizePixel = 0
	track.Parent = row
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(18, 18)
	knob.Position = UDim2.fromOffset(2, 2)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local state = false

	local function render()
		TweenService:Create(track, FAST_TWEEN, {
			BackgroundColor3 = state and ACCENT or COLOR_OFF,
		}):Play()
		TweenService:Create(knob, FAST_TWEEN, {
			Position = state and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2),
		}):Play()
	end

	row.MouseEnter:Connect(function()
		TweenService:Create(row, FAST_TWEEN, { BackgroundColor3 = BG_ROW_HOVER }):Play()
	end)
	row.MouseLeave:Connect(function()
		TweenService:Create(row, FAST_TWEEN, { BackgroundColor3 = BG_ROW }):Play()
	end)
	row.MouseButton1Click:Connect(function()
		state = not state
		render()
		onChange(state)
	end)
end

createToggle("ESP Secret", 1, SecretESP.Set)
createToggle("ESP Players", 2, PlayerESP.Set)
createToggle("Speed", 3, SpeedHack.Set)

--// Slider bonitinho (reguladores do Speed): arrasta o knob, bolha mostra o valor
local function createSlider(text, min, max, step, default, unit, onChange, order)
	local holder = Instance.new("CanvasGroup")
	holder.Size = UDim2.new(1, 0, 0, 34)
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = order
	holder.Parent = list
	table.insert(toggleRows, holder)

	local row = Instance.new("Frame")
	row.Size = UDim2.fromScale(1, 1)
	row.BackgroundColor3 = BG_ROW
	row.BorderSizePixel = 0
	row.Parent = holder
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

	row.MouseEnter:Connect(function()
		TweenService:Create(row, FAST_TWEEN, { BackgroundColor3 = BG_ROW_HOVER }):Play()
	end)
	row.MouseLeave:Connect(function()
		TweenService:Create(row, FAST_TWEEN, { BackgroundColor3 = BG_ROW }):Play()
	end)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(92, 14)
	label.Position = UDim2.fromOffset(14, 10)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 12
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = row

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.fromOffset(40, 14)
	valueLabel.Position = UDim2.new(1, -50, 0, 10)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextSize = 12
	valueLabel.TextColor3 = ACCENT_SOFT
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.Parent = row

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -170, 0, 8)
	track.Position = UDim2.fromOffset(106, 13)
	track.BackgroundColor3 = COLOR_OFF
	track.BorderSizePixel = 0
	track.Parent = row
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = ACCENT
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0.5, 1)
	fill.Parent = track
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	local fillGrad = Instance.new("UIGradient")
	fillGrad.Color = ColorSequence.new(ACCENT, ACCENT_SOFT)
	fillGrad.Parent = fill

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(16, 16)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
	local knobStroke = Instance.new("UIStroke")
	knobStroke.Color = ACCENT
	knobStroke.Thickness = 2
	knobStroke.Parent = knob
	local knobScale = Instance.new("UIScale")
	knobScale.Parent = knob

	-- bolha com o valor, aparece em cima do knob enquanto arrasta
	local bubble = Instance.new("Frame")
	bubble.Size = UDim2.fromOffset(40, 18)
	bubble.AnchorPoint = Vector2.new(0.5, 1)
	bubble.Position = UDim2.new(0.5, 0, 0, -8)
	bubble.BackgroundColor3 = ACCENT
	bubble.BorderSizePixel = 0
	bubble.BackgroundTransparency = 1
	bubble.Parent = track
	Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 6)
	local bubbleScale = Instance.new("UIScale")
	bubbleScale.Scale = 0.6
	bubbleScale.Parent = bubble
	local bubbleText = Instance.new("TextLabel")
	bubbleText.Size = UDim2.fromScale(1, 1)
	bubbleText.BackgroundTransparency = 1
	bubbleText.Font = Enum.Font.GothamBold
	bubbleText.TextSize = 11
	bubbleText.TextColor3 = Color3.new(1, 1, 1)
	bubbleText.TextTransparency = 1
	bubbleText.Parent = bubble

	local value = default
	local draggingSlider = false
	local hoverSlider = false

	local function fmt(v)
		if step < 1 then return string.format("%.1f", v) .. unit end
		return tostring(math.floor(v)) .. unit
	end

	local function render()
		local t = math.clamp((value - min) / (max - min), 0, 1)
		fill.Size = UDim2.fromScale(math.clamp(t, 0.06, 1), 1)
		knob.Position = UDim2.fromScale(t, 0.5)
		bubble.Position = UDim2.new(t, 0, 0, -8)
		valueLabel.Text = fmt(value)
		bubbleText.Text = fmt(value)
	end

	local function setKnobPop()
		local s = draggingSlider and 1.3 or (hoverSlider and 1.15 or 1)
		TweenService:Create(knobScale, FAST_TWEEN, { Scale = s }):Play()
	end

	local function showBubble(on)
		TweenService:Create(bubble, FAST_TWEEN, { BackgroundTransparency = on and 0 or 1 }):Play()
		TweenService:Create(bubbleText, FAST_TWEEN, { TextTransparency = on and 0 or 1 }):Play()
		TweenService:Create(bubbleScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = on and 1 or 0.6,
		}):Play()
	end

	local function setFromX(x)
		local t = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local v = math.clamp(math.floor((min + (max - min) * t) / step + 0.5) * step, min, max)
		if v ~= value then
			value = v
			render()
			onChange(value)
		end
	end

	local function beginDrag(input)
		draggingSlider = true
		setKnobPop()
		showBubble(true)
		setFromX(input.Position.X)
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag(input)
		end
	end)
	knob.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag(input)
		end
	end)
	track.MouseEnter:Connect(function()
		hoverSlider = true
		setKnobPop()
	end)
	track.MouseLeave:Connect(function()
		hoverSlider = false
		setKnobPop()
	end)
	UIS.InputChanged:Connect(function(input)
		if not draggingSlider then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			setFromX(input.Position.X)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			if draggingSlider then
				draggingSlider = false
				setKnobPop()
				showBubble(false)
			end
		end
	end)

	render()
end

createSlider("Velocidade", 16, 500, 2, CONFIG.SPEED_VALUE, "", function(v)
	CONFIG.SPEED_VALUE = v
end, 4)
createSlider("Intervalo", 0.1, 5, 0.1, CONFIG.SPEED_APPLY_INTERVAL, "s", function(v)
	CONFIG.SPEED_APPLY_INTERVAL = v
end, 5)

--// Seção: Ponto de Teleporte (Salvar / Ir lado a lado)
local TP_SAVE_COLOR = Color3.fromRGB(46, 125, 210)
local TP_GO_COLOR = Color3.fromRGB(46, 160, 90)

local tpHolder = Instance.new("CanvasGroup")
tpHolder.Size = UDim2.new(1, 0, 0, 62)
tpHolder.BackgroundTransparency = 1
tpHolder.LayoutOrder = 6
tpHolder.Parent = list
table.insert(toggleRows, tpHolder)

local tpRow = Instance.new("Frame")
tpRow.Size = UDim2.fromScale(1, 1)
tpRow.BackgroundColor3 = BG_ROW
tpRow.BorderSizePixel = 0
tpRow.Parent = tpHolder
Instance.new("UICorner", tpRow).CornerRadius = UDim.new(0, 10)

tpRow.MouseEnter:Connect(function()
	TweenService:Create(tpRow, FAST_TWEEN, { BackgroundColor3 = BG_ROW_HOVER }):Play()
end)
tpRow.MouseLeave:Connect(function()
	TweenService:Create(tpRow, FAST_TWEEN, { BackgroundColor3 = BG_ROW }):Play()
end)

local savedPoint = nil   -- CFrame do ponto salvo

local function getRoot()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local tpStatus = Instance.new("TextLabel")
tpStatus.Size = UDim2.new(1, -16, 0, 14)
tpStatus.Position = UDim2.fromOffset(8, 44)
tpStatus.BackgroundTransparency = 1
tpStatus.Font = Enum.Font.Gotham
tpStatus.TextSize = 11
tpStatus.TextColor3 = TEXT_DIM
tpStatus.TextXAlignment = Enum.TextXAlignment.Left
tpStatus.Text = "Nenhum ponto salvo"
tpStatus.Parent = tpRow

local function makeTpButton(text, xScale, xOffset, color)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.5, -12, 0, 30)
	btn.Position = UDim2.new(xScale, xOffset, 0, 8)
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 13
	btn.AutoButtonColor = false
	btn.Parent = tpRow
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, FAST_TWEEN, { BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.15) }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, FAST_TWEEN, { BackgroundColor3 = color }):Play()
	end)
	return btn
end

local savePointBtn = makeTpButton("Salvar Ponto", 0, 8, TP_SAVE_COLOR)
local goPointBtn = makeTpButton("Ir ao Ponto", 0.5, 4, TP_GO_COLOR)

savePointBtn.MouseButton1Click:Connect(function()
	local root = getRoot()
	if not root then
		tpStatus.Text = "Personagem não encontrado"
		tpStatus.TextColor3 = Color3.fromRGB(230, 90, 90)
		return
	end
	savedPoint = root.CFrame
	local p = root.Position
	tpStatus.Text = string.format("Salvo: %d, %d, %d", p.X, p.Y, p.Z)
	tpStatus.TextColor3 = Color3.fromRGB(90, 200, 120)
end)

goPointBtn.MouseButton1Click:Connect(function()
	if not savedPoint then
		tpStatus.Text = "Salve um ponto primeiro"
		tpStatus.TextColor3 = Color3.fromRGB(230, 90, 90)
		return
	end
	local root = getRoot()
	if not root then
		tpStatus.Text = "Personagem não encontrado"
		tpStatus.TextColor3 = Color3.fromRGB(230, 90, 90)
		return
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = savedPoint
	tpStatus.Text = "Teleportado!"
	tpStatus.TextColor3 = Color3.fromRGB(90, 200, 120)
end)

--// Abrir/fechar painel com animação (linhas aparecem uma a uma)
local isOpen = false

local function setPanel(open)
	isOpen = open

	if open then
		panel.Visible = true
		TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()
		TweenService:Create(panelScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()

		for i, row in ipairs(toggleRows) do
			row.GroupTransparency = 1
			task.delay(0.05 * i, function()
				if not isOpen then return end
				TweenService:Create(row, TweenInfo.new(0.22, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()
			end)
		end
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

----------------------------------------------------------------
--// BOLA XHUB (abre o painel; arrastável pela tela)
----------------------------------------------------------------
local BALL_SIZE = 58
local DRAG_THRESHOLD = 6   -- passou disso, é arrasto e não clique

local ball = Instance.new("TextButton")
ball.Name = "XhubBall"
ball.Size = UDim2.fromOffset(BALL_SIZE, BALL_SIZE)
ball.Position = UDim2.new(0, 12, 0.5, -BALL_SIZE / 2)
ball.BackgroundColor3 = BG_PANEL
ball.AutoButtonColor = false
ball.Text = ""
ball.Parent = gui
Instance.new("UICorner", ball).CornerRadius = UDim.new(1, 0)

local ballStroke = Instance.new("UIStroke")
ballStroke.Color = ACCENT
ballStroke.Thickness = 2
ballStroke.Parent = ball

local ballScale = Instance.new("UIScale")
ballScale.Parent = ball

local ballIcon = makeXIcon(ball, UDim2.fromScale(1, 1), 5)

-- pulso suave na borda (idle)
task.spawn(function()
	local pulse = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	while ball.Parent == gui do
		TweenService:Create(ballStroke, pulse, { Thickness = 3.5, Color = ACCENT_SOFT }):Play()
		task.wait(1.1)
		TweenService:Create(ballStroke, pulse, { Thickness = 2, Color = ACCENT }):Play()
		task.wait(1.1)
	end
end)

local function tweenXIcon(icon, color)
	for _, b in ipairs(icon:GetChildren()) do
		if b:IsA("Frame") then
			TweenService:Create(b, FAST_TWEEN, { BackgroundColor3 = color }):Play()
		end
	end
end

-- animação de hover (mouse)
local ballHover = false
ball.MouseEnter:Connect(function()
	ballHover = true
	TweenService:Create(ballScale, FAST_TWEEN, { Scale = 1.15 }):Play()
	TweenService:Create(ball, FAST_TWEEN, { BackgroundColor3 = BG_HEADER }):Play()
	tweenXIcon(ballIcon, ACCENT_SOFT)
end)
ball.MouseLeave:Connect(function()
	ballHover = false
	TweenService:Create(ballScale, FAST_TWEEN, { Scale = 1 }):Play()
	TweenService:Create(ball, FAST_TWEEN, { BackgroundColor3 = BG_PANEL }):Play()
	tweenXIcon(ballIcon, ACCENT)
end)

-- arrastar + clique
local dragging = false
local dragMoved = false
local dragStart, dragOrigPos

local function clampBall(pos)
	local vp = workspace.CurrentCamera.ViewportSize
	local x = vp.X * pos.X.Scale + pos.X.Offset
	local y = vp.Y * pos.Y.Scale + pos.Y.Offset
	x = math.clamp(x, 4, math.max(4, vp.X - BALL_SIZE - 4))
	y = math.clamp(y, 4, math.max(4, vp.Y - BALL_SIZE - 4))
	return UDim2.fromOffset(x, y)
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

ball.InputBegan:Connect(function(input)
	if dragging or not isPress(input) then return end
	dragging = true
	dragMoved = false
	dragStart = input.Position
	dragOrigPos = ball.Position
end)

-- o movimento chega como MouseMovement (ou o mesmo Touch), não como o input do clique
UIS.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement
		and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local delta = input.Position - dragStart
	if delta.Magnitude > DRAG_THRESHOLD then dragMoved = true end
	ball.Position = clampBall(UDim2.new(
		dragOrigPos.X.Scale, dragOrigPos.X.Offset + delta.X,
		dragOrigPos.Y.Scale, dragOrigPos.Y.Offset + delta.Y
	))
end)

UIS.InputEnded:Connect(function(input)
	if not dragging or not isPress(input) then return end
	dragging = false

	if not dragMoved then
		-- clique: "apertadinha" de feedback + abre/fecha o painel
		TweenService:Create(ballScale, TweenInfo.new(0.08), { Scale = 0.85 }):Play()
		task.delay(0.08, function()
			TweenService:Create(ballScale, FAST_TWEEN, { Scale = ballHover and 1.15 or 1 }):Play()
		end)
		setPanel(not isOpen)
	end
end)

--// DEBUG: mostra no console (F9) nomes de objetos parecidos com itens
if CONFIG.DEBUG_SCAN then
	task.delay(5, function()
		print("[Xhub] scan de nomes no workspace:")
		for _, inst in ipairs(workspace:GetDescendants()) do
			if inst:IsA("BasePart") or inst:IsA("Model") or inst:IsA("Folder") then
				local n = normalize(inst.Name)
				for _, w in ipairs(CONFIG.SCAN_WORDS) do
					if n:find(w, 1, true) then
						print("[Xhub]", inst.ClassName, inst:GetFullName())
						break
					end
				end
			end
		end
	end)
end
