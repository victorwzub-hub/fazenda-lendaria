local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local State = require(script.State)
local World = require(script.World)
local Guide = require(script.Guide)
local Effects = require(script.Effects)
local DoubleJump = require(script.DoubleJump)
local Sfx = require(script.Sfx)
local Welcome = require(script.UI.Welcome)
local Hud = require(script.UI.Hud)
local Kit = require(script.UI.Kit)
local Notifications = require(script.UI.Notifications)
local Panel = require(script.UI.Panel)
local Pages = script.UI.Pages

local player = Players.LocalPlayer

local PAGES = {
	{ id = "Animais", title = "🐔 Meus Animais", color = Kit.colors.green, render = require(Pages.Animais) },
	{ id = "Rotas", title = "🗺️ Rotas", color = Kit.colors.blue, render = require(Pages.Rotas) },
	{ id = "Loja", title = "🛒 Loja", color = Kit.colors.yellow, render = require(Pages.Loja) },
	{ id = "Indice", title = "📖 Índice", color = Color3.fromRGB(165, 100, 225), render = require(Pages.Indice) },
	{ id = "Mochila", title = "🎒 Mochila", color = Color3.fromRGB(180, 120, 70), render = require(Pages.Mochila) },
}

local gui = Kit.new("ScreenGui", {
	Name = "FazendaUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local scales: { UIScale } = {}
local panels = {}
local renderers = {}
local current: string? = nil

local function closeAll()
	for _, panel in panels do
		panel:setVisible(false)
	end
	current = nil
end

local function act(action: string, arg: string?): (boolean, any)
	local ok, result = State.request(action, arg)
	if ok and (action == "BuyUpgrade" or action == "UnlockRoute" or action == "Sell") then
		Sfx.play("comprar")
	end
	if type(result) == "string" then
		Notifications.toast(result, if ok then Kit.colors.green else Kit.colors.red)
	end
	return ok, result
end

local baseCtx = { act = act, close = closeAll }

local function renderCurrent()
	if current and State.profile then
		panels[current]:render(renderers[current], State.profile, baseCtx, State.coins())
	end
end

local function open(id: string)
	if current == id then
		closeAll()
		return
	end
	closeAll()
	current = id
	panels[id]:setVisible(true)
	renderCurrent()
end

for _, page in PAGES do
	local panel = Panel.new(gui, page.title, page.color, closeAll)
	panels[page.id] = panel
	renderers[page.id] = page.render
	table.insert(scales, panel.scale)
end

Hud.mount(gui, scales, {
	{
		id = "Animais",
		emoji = "🐔",
		label = "Animais",
		color = Kit.colors.green,
		onClick = function()
			open("Animais")
		end,
	},
	{
		id = "Rotas",
		emoji = "🗺️",
		label = "Rotas",
		color = Kit.colors.blue,
		onClick = function()
			open("Rotas")
		end,
	},
	{
		id = "Loja",
		emoji = "🛒",
		label = "Loja",
		color = Kit.colors.yellow,
		onClick = function()
			open("Loja")
		end,
	},
	{
		id = "Indice",
		emoji = "📖",
		label = "Índice",
		color = Color3.fromRGB(165, 100, 225),
		onClick = function()
			open("Indice")
		end,
	},
	{
		id = "Mochila",
		emoji = "🎒",
		label = "Mochila",
		color = Color3.fromRGB(180, 120, 70),
		onClick = function()
			open("Mochila")
		end,
	},
	{
		id = "Fazenda",
		emoji = "🏡",
		label = "Fazenda",
		color = Color3.fromRGB(120, 170, 70),
		onClick = function()
			act("Travel", "Fazenda")
		end,
	},
})

Notifications.mount(gui, scales)

local camera = Workspace.CurrentCamera
local function rescale()
	local viewport = camera.ViewportSize
	local scale = math.clamp(math.min(viewport.X / 1000, viewport.Y / 640), 0.5, 1)
	for _, uiScale in scales do
		uiScale.Scale = scale
	end
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

Remotes.event("Notify").OnClientEvent:Connect(function(payload)
	Sfx.play(payload.sfx or (if payload.kind == "reveal" then "revelar" else nil))
	if payload.kind == "welcome" then
		Welcome.show(gui, scales, payload.amount, payload.seconds)
	elseif payload.kind == "toast" then
		Notifications.toast(payload.text, payload.color)
	elseif payload.kind == "big" then
		Notifications.big(payload.text, payload.sub, payload.color)
	elseif payload.kind == "reveal" then
		Notifications.reveal(payload)
	end
end)

State.onProfile(function()
	renderCurrent()
	Hud.tick()
end)

State.onCoins(function(coins)
	Hud.setCoins(coins)
	if current then
		panels[current]:refreshCosts(coins)
	end
end)

State.start()
World.start()
Guide.start()
Effects.start()
DoubleJump.start()
Sfx.start()

-- Galo cantando quando o Galo Bravo começa a correr atrás de você.
player:GetAttributeChangedSignal("Perseguido"):Connect(function()
	local chaser = player:GetAttribute("Perseguido")
	if chaser and string.find(chaser, "Galo", 1, true) then
		Sfx.play("galo")
	end
end)

while true do
	Hud.tick()
	Guide.update()
	task.wait(0.5)
end
