local Teleport = {}

Teleport.beforeTeleport = nil :: ((Player) -> ())?

function Teleport.to(player: Player, target: CFrame): boolean
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return false
	end
	pcall(function()
		player:RequestStreamAroundAsync(target.Position, 3)
	end)
	if player.Character ~= character then
		return false
	end
	if Teleport.beforeTeleport then
		Teleport.beforeTeleport(player)
	end
	character:PivotTo(target + Vector3.new(0, 3, 0))
	return true
end

return Teleport
