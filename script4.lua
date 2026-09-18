--// PAINEL ESP: Saint + Fragment + Players + Mapa
--// LocalScript em StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--// CONFIG
local CONFIG = {
	PANEL_KEY = Enum.KeyCode.K,

	SAINT_KEYWORD = "saint",
	SAINT_COLOR = Color3.fromRGB(0, 200, 255),     -- ESP da peça saint (ciano)

	FRAGMENT_KEYWORD = "fragment",
	FRAGMENT_EXCLUDE = "meteor",                   -- ignora nomes com essa palavra
	FRAGMENT_COLOR = Color3.fromRGB(255, 140, 0),  -- ESP fragment (laranja)

	PLAYER_COLOR = Color3.fromRGB(255, 40, 40),    -- jogadores normais (vermelho)
	GOLD_COLOR = Color3.fromRGB(255, 215, 0),      -- jogador com a saint (dourado)

	--// MAPA
	MAP_IMAGE = "rbxassetid://122870101584231",                  -- << COLOQUE O ID DA IMAGEM DO MAPA AQUI
	MAP_IMAGE_SIZE = Vector2.new(1600, 839),       -- tamanho em pixels da imagem que você subiu

	-- Região da imagem que é o mapa de verdade (sem a legenda da direita), em pixels
	MAP_AREA_PX_MIN = Vector2.new(110, 0),         -- canto superior esquerdo do mapa
	MAP_AREA_PX_MAX = Vector2.new(1285, 839),      -- canto inferior direito do mapa

	-- Coordenadas do MUNDO (X, Z) que correspondem a esses dois cantos do mapa
	-- Vector2.new(X, Z)  << CALIBRE ISSO (veja as notas)
	MAP_WORLD_TOPLEFT = Vector2.new(-1000, -1000),
	MAP_WORLD_BOTTOMRIGHT = Vector2.new(1000, 1000),

	MAP_SHOW_COORDS = true,                        -- mostra X/Z no mapa pra calibrar (depois põe false)
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
--// FUNÇÃO 3: ESP PLAYERS (vermelho; dourado se estiver com a saint)
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
--// PAINEL (UI)
----------------------------------------------------------------
local panel = Instance.new("CanvasGroup")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(260, 256)
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
list.Size = UDim2.new(1, -24, 0, 176)
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

--// Botão simples (sem interruptor), usado pelo MAPA
local function createButton(text, order, onClick)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, 0, 0, 38)
	row.BackgroundColor3 = Color3.fromRGB(36, 36, 44)
	row.AutoButtonColor = false
	row.Text = ""
	row.LayoutOrder = order
	row.Parent = list
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -50, 1, 0)
	label.Position = UDim2.fromOffset(12, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = row

	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.fromOffset(30, 38)
	arrow.Position = UDim2.new(1, -38, 0, 0)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBold
	arrow.TextSize = 16
	arrow.TextColor3 = Color3.fromRGB(140, 140, 155)
	arrow.Text = ">"
	arrow.Parent = row

	row.MouseEnter:Connect(function()
		TweenService:Create(row, TOGGLE_TWEEN, { BackgroundColor3 = Color3.fromRGB(48, 48, 58) }):Play()
	end)
	row.MouseLeave:Connect(function()
		TweenService:Create(row, TOGGLE_TWEEN, { BackgroundColor3 = Color3.fromRGB(36, 36, 44) }):Play()
	end)
	row.MouseButton1Click:Connect(onClick)
end

----------------------------------------------------------------
--// MAPA (janela com a imagem + ponto branco da sua posição)
----------------------------------------------------------------
local mapWindow = Instance.new("CanvasGroup")
mapWindow.Name = "MapWindow"
mapWindow.AnchorPoint = Vector2.new(0.5, 0.5)
mapWindow.Position = UDim2.fromScale(0.5, 0.5)
mapWindow.Size = UDim2.fromScale(0.8, 0.8)
mapWindow.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
mapWindow.GroupTransparency = 1
mapWindow.Visible = false
mapWindow.ZIndex = 20
mapWindow.Parent = gui

Instance.new("UICorner", mapWindow).CornerRadius = UDim.new(0, 12)

local mapAspect = Instance.new("UIAspectRatioConstraint")
mapAspect.AspectRatio = CONFIG.MAP_IMAGE_SIZE.X / CONFIG.MAP_IMAGE_SIZE.Y
mapAspect.AspectType = Enum.AspectType.FitWithinMaxSize
mapAspect.Parent = mapWindow

local mapStroke = Instance.new("UIStroke")
mapStroke.Color = Color3.fromRGB(70, 70, 85)
mapStroke.Thickness = 1
mapStroke.Parent = mapWindow

local mapScale = Instance.new("UIScale")
mapScale.Scale = 0.85
mapScale.Parent = mapWindow

local mapImage = Instance.new("ImageLabel")
mapImage.Name = "MapImage"
mapImage.Size = UDim2.fromScale(1, 1)
mapImage.BackgroundTransparency = 1
mapImage.Image = CONFIG.MAP_IMAGE
mapImage.ScaleType = Enum.ScaleType.Stretch
mapImage.ZIndex = 21
mapImage.Parent = mapWindow

if CONFIG.MAP_IMAGE == "rbxassetid://122870101584231" or CONFIG.MAP_IMAGE == "" then
	local warn = Instance.new("TextLabel")
	warn.Size = UDim2.fromScale(1, 1)
	warn.BackgroundTransparency = 1
	warn.Font = Enum.Font.GothamBold
	warn.TextSize = 16
	warn.TextColor3 = Color3.fromRGB(255, 200, 80)
	warn.Text = "Defina MAP_IMAGE no CONFIG do script"
	warn.ZIndex = 22
	warn.Parent = mapWindow
end

-- Ponto branco (sua posição)
local mapDot = Instance.new("Frame")
mapDot.Name = "PlayerDot"
mapDot.AnchorPoint = Vector2.new(0.5, 0.5)
mapDot.Size = UDim2.fromOffset(14, 14)
mapDot.BackgroundColor3 = Color3.new(1, 1, 1)
mapDot.ZIndex = 24
mapDot.Visible = false
mapDot.Parent = mapImage
Instance.new("UICorner", mapDot).CornerRadius = UDim.new(1, 0)

local dotStroke = Instance.new("UIStroke")
dotStroke.Color = Color3.new(0, 0, 0)
dotStroke.Thickness = 2
dotStroke.Parent = mapDot

-- Coordenadas (pra calibrar)
local coordsLabel = Instance.new("TextLabel")
coordsLabel.Size = UDim2.fromOffset(220, 22)
coordsLabel.Position = UDim2.new(0, 8, 1, -28)
coordsLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
coordsLabel.BackgroundTransparency = 0.4
coordsLabel.Font = Enum.Font.GothamMedium
coordsLabel.TextSize = 12
coordsLabel.TextColor3 = Color3.new(1, 1, 1)
coordsLabel.Text = ""
coordsLabel.Visible = CONFIG.MAP_SHOW_COORDS
coordsLabel.ZIndex = 25
coordsLabel.Parent = mapWindow
Instance.new("UICorner", coordsLabel).CornerRadius = UDim.new(0, 6)

-- Botão X (fechar)
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Size = UDim2.fromOffset(30, 30)
closeBtn.Position = UDim2.new(1, -38, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Text = "X"
closeBtn.AutoButtonColor = true
closeBtn.ZIndex = 26
closeBtn.Parent = mapWindow
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

local mapOpen = false
local mapConn

local function updateMapDot()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		mapDot.Visible = false
		return
	end

	local pos = root.Position
	if CONFIG.MAP_SHOW_COORDS then
		coordsLabel.Text = string.format("  X: %d   Z: %d", pos.X, pos.Z)
	end

	local tl = CONFIG.MAP_WORLD_TOPLEFT
	local br = CONFIG.MAP_WORLD_BOTTOMRIGHT

	local u = math.clamp((pos.X - tl.X) / (br.X - tl.X), 0, 1)
	local v = math.clamp((pos.Z - tl.Y) / (br.Y - tl.Y), 0, 1)

	local pMin = CONFIG.MAP_AREA_PX_MIN
	local pMax = CONFIG.MAP_AREA_PX_MAX
	local px = pMin.X + u * (pMax.X - pMin.X)
	local py = pMin.Y + v * (pMax.Y - pMin.Y)

	mapDot.Position = UDim2.fromScale(px / CONFIG.MAP_IMAGE_SIZE.X, py / CONFIG.MAP_IMAGE_SIZE.Y)
	mapDot.Visible = true
end

local function setMap(open)
	mapOpen = open

	if open then
		mapWindow.Visible = true
		TweenService:Create(mapWindow, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
		TweenService:Create(mapScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()

		if mapConn then mapConn:Disconnect() end
		mapConn = RunService.RenderStepped:Connect(updateMapDot)
	else
		if mapConn then
			mapConn:Disconnect()
			mapConn = nil
		end

		local fade = TweenService:Create(mapWindow, TweenInfo.new(0.15), { GroupTransparency = 1 })
		TweenService:Create(mapScale, TweenInfo.new(0.15), { Scale = 0.85 }):Play()
		fade.Completed:Connect(function()
			if not mapOpen then mapWindow.Visible = false end
		end)
		fade:Play()
	end
end

closeBtn.MouseButton1Click:Connect(function()
	setMap(false)
end)

--// Itens do painel
createToggle("ESP Saint", 1, SaintESP.Set)
createToggle("ESP Fragment", 2, FragmentESP.Set)
createToggle("ESP Players", 3, PlayerESP.Set)
createButton("MAPA", 4, function()
	setMap(not mapOpen)
end)

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
