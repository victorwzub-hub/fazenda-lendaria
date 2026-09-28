-- Janela "Bem-vindo de volta!" com os ganhos offline (as moedas já entraram no servidor;
-- o botão só fecha a janela com festa).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Style = require(Shared.Style)

local Kit = require(script.Parent.Kit)

local Welcome = {}

local BLUE = Color3.fromRGB(70, 160, 245)
local MONEY = Color3.fromRGB(95, 235, 70)

local function outlined(props: { [string]: any }, thickness: number): TextLabel
	local label = Kit.label(props)
	label.Font = Enum.Font.FredokaOne
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextWrapped = false
	Style.outline(label, thickness)
	return label
end

function Welcome.show(gui: ScreenGui, scales: { UIScale }, amount: number, seconds: number)
	local shade = Kit.new("Frame", {
		Name = "BemVindo",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = gui,
	})
	local window = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(120, 40, 45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 420),
		ZIndex = 51,
		Parent = shade,
	}, { Kit.corner(18), Kit.stroke(Color3.fromRGB(40, 12, 14), 5) })
	local scale = Kit.new("UIScale", { Scale = 0.2, Parent = window })
	table.insert(scales, scale)

	local header = Kit.new("Frame", {
		BackgroundColor3 = BLUE,
		Size = UDim2.new(1, 0, 0, 74),
		ZIndex = 52,
		Parent = window,
	}, { Kit.corner(18), Kit.stroke(Color3.fromRGB(25, 70, 130), 4) })
	outlined({
		Text = "Bem-vindo de volta!",
		TextSize = 40,
		TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 53,
		Parent = header,
	}, 3.5)

	outlined({
		Text = "GANHOS OFFLINE",
		TextSize = 44,
		TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 50),
		ZIndex = 52,
		Parent = window,
	}, 4)
	outlined({
		Text = "💰",
		TextSize = 70,
		Position = UDim2.fromOffset(0, 146),
		Size = UDim2.new(1, 0, 0, 80),
		ZIndex = 52,
		Parent = window,
	}, 0)
	outlined({
		Text = "+" .. Format.number(amount),
		TextSize = 64,
		TextColor3 = MONEY,
		Position = UDim2.fromOffset(0, 226),
		Size = UDim2.new(1, 0, 0, 72),
		ZIndex = 52,
		Parent = window,
	}, 5)
	outlined({
		Text = "Sua fazenda trabalhou por " .. Format.time(seconds),
		TextSize = 20,
		TextColor3 = Color3.fromRGB(255, 230, 200),
		Position = UDim2.fromOffset(0, 296),
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 52,
		Parent = window,
	}, 2)

	local function close()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.1 }):Play()
		task.delay(0.2, function()
			local index = table.find(scales, scale)
			if index then
				table.remove(scales, index)
			end
			shade:Destroy()
		end)
	end
	local button = Kit.button("Resgatar!", Kit.colors.green, close, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 334),
		Size = UDim2.fromOffset(260, 66),
		TextSize = 34,
		ZIndex = 53,
		Parent = window,
	})
	Style.outline(button, 3)

	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

return Welcome
