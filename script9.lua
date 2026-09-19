--// XHUB: Saint + Fragment + DogBane + Rokakaka + Players + Speed + Anti Lag
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

	-- casa qualquer variante: "DogbaneSeed", "dogbane seed", "seed_dogban"...
	-- se o nome no jogo não contiver "dogban", adicione a palavra aqui (ex: "seed", "sprout")
	DOGBANE_KEYWORDS = { "dogban" },
	DOGBANE_COLOR = Color3.fromRGB(60, 220, 90),     -- ESP dogbane (verde)

	-- casa "rokakaka", "rokaka", "rokakaka-seed", "seed_rokaka"...
	ROKAKAKA_KEYWORDS = { "roka" },
	ROKAKAKA_COLOR = Color3.fromRGB(180, 90, 255),   -- ESP rokakaka (roxo)

	PLAYER_COLOR = Color3.fromRGB(255, 40, 40),      -- jogadores normais (vermelho)
	GOLD_COLOR = Color3.fromRGB(255, 215, 0),        -- jogador com a saint (dourado)

	--// SPEED (aplicado direto no player)
	SPEED_VALUE = 150,                               -- WalkSpeed enquanto estiver ligado
	SPEED_APPLY_INTERVAL = 1,                        -- a cada quantos segundos reaplica (o jogo costuma resetar)

	--// ANTI LAG
	ANTILAG_MATERIAL = Enum.Material.SmoothPlastic,  -- material "lego" aplicado em tudo
	ANTILAG_PARTICLE_KEEP = 0.15,                    -- fração da taxa de partículas que continua (0 = remove todas)
	ANTILAG_BATCH = 400,                             -- objetos processados por frame (evita travada ao ligar)
}

local player = Players.LocalPlayer

--// GUI base
local gui = Instance.new("ScreenGui")
gui.Name = "XhubGui"
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

-- true se o nome (normalizado) contiver qualquer keyword da lista
local function matchesAny(name, keywords)
	local n = normalize(name)
	for _, kw in ipairs(keywords) do
		if n:find(kw, 1, true) then return true end
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
--// FUNÇÃO 3: ESP DOGBANE (verde)
----------------------------------------------------------------
local DogBaneESP = { Enabled = false }
local dogbaneTracked = {}   -- [inst] = {highlight, billboard, label, adornee}
local dogbaneConns = {}

local function dogbaneMatches(inst)
	return (inst:IsA("BasePart") or inst:IsA("Model"))
		and matchesAny(inst.Name, CONFIG.DOGBANE_KEYWORDS)
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
		and matchesAny(inst.Name, CONFIG.ROKAKAKA_KEYWORDS)
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
--// FUNÇÃO 6: PLAYER SPEED (aplica WalkSpeed direto no player)
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

-- ícone do Xhub: X vermelho desenhado com texto (sem imagem externa)
local function makeXIcon(parent, size, textSize)
	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Text = "✕"
	icon.Font = Enum.Font.GothamBlack
	icon.TextSize = textSize
	icon.TextColor3 = ACCENT
	icon.Size = size
	icon.Parent = parent
	return icon
end

local panel = Instance.new("CanvasGroup")
panel.Name = "XhubPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(280, 430)
panel.BackgroundColor3 = BG_PANEL
panel.GroupTransparency = 1
panel.Visible = false
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

local headerIcon = makeXIcon(header, UDim2.fromOffset(36, 36), 22)
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

--// Lista de toggles
local list = Instance.new("Frame")
list.Size = UDim2.new(1, -24, 0, 332)
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

createToggle("ESP Saint", 1, SaintESP.Set)
createToggle("ESP Fragment", 2, FragmentESP.Set)
createToggle("ESP DogBane", 3, DogBaneESP.Set)
createToggle("ESP Rokakaka", 4, RokakakaESP.Set)
createToggle("ESP Players", 5, PlayerESP.Set)
createToggle("Speed", 6, SpeedHack.Set)
createToggle("Anti Lag", 7, AntiLag.Set)

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

local ballIcon = makeXIcon(ball, UDim2.fromScale(1, 1), 26)

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

-- animação de hover (mouse)
local ballHover = false
ball.MouseEnter:Connect(function()
	ballHover = true
	TweenService:Create(ballScale, FAST_TWEEN, { Scale = 1.15 }):Play()
	TweenService:Create(ball, FAST_TWEEN, { BackgroundColor3 = BG_HEADER }):Play()
	TweenService:Create(ballIcon, FAST_TWEEN, { TextColor3 = ACCENT_SOFT }):Play()
end)
ball.MouseLeave:Connect(function()
	ballHover = false
	TweenService:Create(ballScale, FAST_TWEEN, { Scale = 1 }):Play()
	TweenService:Create(ball, FAST_TWEEN, { BackgroundColor3 = BG_PANEL }):Play()
	TweenService:Create(ballIcon, FAST_TWEEN, { TextColor3 = ACCENT }):Play()
end)

-- arrastar + clique
local dragging = false
local dragMoved = false
local dragInput, dragStart, dragOrigPos

local function clampBall(pos)
	local vp = workspace.CurrentCamera.ViewportSize
	local x = vp.X * pos.X.Scale + pos.X.Offset
	local y = vp.Y * pos.Y.Scale + pos.Y.Offset
	x = math.clamp(x, 4, math.max(4, vp.X - BALL_SIZE - 4))
	y = math.clamp(y, 4, math.max(4, vp.Y - BALL_SIZE - 4))
	return UDim2.fromOffset(x, y)
end

ball.InputBegan:Connect(function(input)
	if dragging then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragMoved = false
		dragInput = input
		dragStart = input.Position
		dragOrigPos = ball.Position
	end
end)

UIS.InputChanged:Connect(function(input)
	if not dragging or input ~= dragInput then return end
	local delta = input.Position - dragStart
	if delta.Magnitude > DRAG_THRESHOLD then dragMoved = true end
	ball.Position = clampBall(UDim2.new(
		dragOrigPos.X.Scale, dragOrigPos.X.Offset + delta.X,
		dragOrigPos.Y.Scale, dragOrigPos.Y.Offset + delta.Y
	))
end)

UIS.InputEnded:Connect(function(input)
	if input ~= dragInput then return end
	dragging = false
	dragInput = nil

	if not dragMoved then
		-- clique: "apertadinha" de feedback + abre/fecha o painel
		TweenService:Create(ballScale, TweenInfo.new(0.08), { Scale = 0.85 }):Play()
		task.delay(0.08, function()
			TweenService:Create(ballScale, FAST_TWEEN, { Scale = ballHover and 1.15 or 1 }):Play()
		end)
		setPanel(not isOpen)
	end
end)
