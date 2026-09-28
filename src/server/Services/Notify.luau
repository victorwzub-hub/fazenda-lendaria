local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local NotifyRemote = Remotes.event("Notify")

local Notify = {}

function Notify.toast(player: Player, text: string, color: Color3?)
	NotifyRemote:FireClient(player, { kind = "toast", text = text, color = color })
end

function Notify.big(player: Player, title: string, subtitle: string?, color: Color3?)
	NotifyRemote:FireClient(player, { kind = "big", text = title, sub = subtitle, color = color })
end

function Notify.bigAll(title: string, subtitle: string?, color: Color3?)
	NotifyRemote:FireAllClients({ kind = "big", text = title, sub = subtitle, color = color })
end

function Notify.reveal(player: Player, payload)
	payload.kind = "reveal"
	NotifyRemote:FireClient(player, payload)
end

return Notify
