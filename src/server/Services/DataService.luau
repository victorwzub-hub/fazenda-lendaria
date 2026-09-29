local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local DataService = {}

local STORE_NAME = "FazendaLendaria_v1"
local AUTOSAVE_SECONDS = 60
local MAX_ATTEMPTS = 3

local ProfileRemote = Remotes.event("Profile")

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore indisponível:", result)
	end
end

local profiles: { [Player]: any } = {}
local canSave: { [Player]: boolean } = {}
local pendingPush: { [Player]: boolean } = {}

local function template()
	return {
		version = 1,
		coins = 0,
		materials = {},
		animals = {},
		nextAnimalId = 1,
		equipped = {},
		rebirths = 0,
		daily = { day = 0, streak = 0 },
		upgrades = { Sorte = 0, Fazenda = 0, Velocidade = 0, Pulo = 0, Rede = 0, Cesta = 0, Esteira = 0 },
		training = 0,
		eggs = {},
		nextEggId = 1,
		mission = { index = 1, base = 0 },
		routes = { Galinheiro = true },
		index = {},
		stats = { legendaries = 0, nests = 0, collected = 0, deposited = 0, evolved = 0, chests = 0, knockouts = 0, bosses = 0, hatched = 0, races = 0, stampedes = 0 },
		lastOnline = 0,
	}
end

local function reconcile(target, defaults)
	for key, value in defaults do
		if target[key] == nil then
			target[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil then
			reconcile(target[key], value)
		end
	end
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function createLeaderstats(player: Player, profile)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local coins = Instance.new("NumberValue")
	coins.Name = "Moedas"
	coins.Value = math.floor(profile.coins)
	coins.Parent = folder
	local legendaries = Instance.new("IntValue")
	legendaries.Name = "Lendários"
	legendaries.Value = profile.stats.legendaries
	legendaries.Parent = folder
	folder.Parent = player
end

-- Retorna (profile, isNew, loadedFromStore). Se o DataStore falhar, o jogador joga com um perfil
-- temporário que NUNCA é salvo, para não sobrescrever o progresso real.
function DataService.load(player: Player)
	local data = nil
	local loaded = false
	if store then
		for attempt = 1, MAX_ATTEMPTS do
			local ok, result = pcall(function()
				return (store :: DataStore):GetAsync(keyFor(player))
			end)
			if ok then
				data = result
				loaded = true
				break
			end
			warn(
				string.format(
					"[DataService] Falha ao carregar %s (tentativa %d): %s",
					player.Name,
					attempt,
					tostring(result)
				)
			)
			if RunService:IsStudio() and string.find(tostring(result), "Studio", 1, true) then
				break
			end
			task.wait(attempt * 2)
		end
	end

	if not player.Parent then
		return nil, false, false
	end

	local isNew = data == nil
	local profile = data or template()
	reconcile(profile, template())
	profiles[player] = profile
	canSave[player] = loaded
	createLeaderstats(player, profile)
	return profile, isNew, loaded
end

function DataService.get(player: Player)
	return profiles[player]
end

function DataService.all(): { [Player]: any }
	return profiles
end

function DataService.save(player: Player)
	local profile = profiles[player]
	if not profile or not canSave[player] or not store then
		return
	end
	profile.lastOnline = os.time()
	for attempt = 1, MAX_ATTEMPTS do
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(keyFor(player), function()
				return profile
			end)
		end)
		if ok then
			return
		end
		warn(string.format("[DataService] Falha ao salvar %s (tentativa %d): %s", player.Name, attempt, tostring(err)))
		task.wait(attempt * 2)
	end
end

function DataService.release(player: Player)
	DataService.save(player)
	profiles[player] = nil
	canSave[player] = nil
	pendingPush[player] = nil
end

-- Agrupa várias mudanças no mesmo frame em um único envio para o cliente.
function DataService.push(player: Player)
	if pendingPush[player] then
		return
	end
	pendingPush[player] = true
	task.defer(function()
		pendingPush[player] = nil
		local profile = profiles[player]
		if profile and player.Parent then
			ProfileRemote:FireClient(player, profile)
		end
	end)
end

local function syncCoins(player: Player, profile)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Moedas")
	if value then
		(value :: NumberValue).Value = math.floor(profile.coins)
	end
end

function DataService.addCoins(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.coins += amount
	syncCoins(player, profile)
end

function DataService.spendCoins(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or profile.coins < amount then
		return false
	end
	profile.coins -= amount
	syncCoins(player, profile)
	return true
end

function DataService.addMaterial(player: Player, materialId: string, amount: number)
	local profile = profiles[player]
	if profile then
		profile.materials[materialId] = (profile.materials[materialId] or 0) + amount
	end
end

function DataService.syncLegendaries(player: Player)
	local profile = profiles[player]
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Lendários")
	if profile and value then
		(value :: IntValue).Value = profile.stats.legendaries
	end
end

function DataService.init()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player in profiles do
				task.spawn(DataService.save, player)
			end
		end
	end)

	game:BindToClose(function()
		local remaining = 0
		for _, player in Players:GetPlayers() do
			if profiles[player] then
				remaining += 1
				task.spawn(function()
					DataService.save(player)
					remaining -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while remaining > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
