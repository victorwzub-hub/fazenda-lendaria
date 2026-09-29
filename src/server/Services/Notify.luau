local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local NotifyRemote = Remotes.event("Notify")

local Notify = {}

-- `sfx` é o nome de um som de Config.Sounds (opcional).
function Notify.toast(player: Player, text: string, color: Color3?, sfx: string?)
	NotifyRemote:FireClient(player, { kind = "toast", text = text, color = color, sfx = sfx })
end

function Notify.big(player: Player, title: string, subtitle: string?, color: Color3?, sfx: string?)
	NotifyRemote:FireClient(player, { kind = "big", text = title, sub = subtitle, color = color, sfx = sfx })
end

-- Janela "Bem-vindo de volta!" com o que a fazenda rendeu offline.
function Notify.welcome(player: Player, amount: number, seconds: number)
	NotifyRemote:FireClient(player, { kind = "welcome", amount = amount, seconds = seconds, sfx = "guardar" })
end

function Notify.bigAll(title: string, subtitle: string?, color: Color3?, sfx: string?)
	NotifyRemote:FireAllClients({ kind = "big", text = title, sub = subtitle, color = color, sfx = sfx })
end

function Notify.reveal(player: Player, payload)
	payload.kind = "reveal"
	NotifyRemote:FireClient(player, payload)
end

return Notify
