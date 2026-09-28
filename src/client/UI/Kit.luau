local TweenService = game:GetService("TweenService")

local Kit = {}

Kit.colors = {
	panel = Color3.fromRGB(255, 248, 232),
	card = Color3.fromRGB(246, 234, 208),
	border = Color3.fromRGB(122, 80, 42),
	text = Color3.fromRGB(78, 50, 26),
	muted = Color3.fromRGB(145, 115, 85),
	green = Color3.fromRGB(92, 192, 88),
	yellow = Color3.fromRGB(255, 192, 55),
	red = Color3.fromRGB(232, 88, 72),
	blue = Color3.fromRGB(78, 148, 238),
	gray = Color3.fromRGB(168, 158, 148),
	white = Color3.new(1, 1, 1),
	good = Color3.fromRGB(45, 150, 60),
	bad = Color3.fromRGB(200, 60, 50),
}

function Kit.new(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Kit.corner(radius: number?): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Kit.stroke(color: Color3?, thickness: number?): UIStroke
	return Kit.new("UIStroke", {
		Color = color or Kit.colors.border,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.padding(pixels: number): UIPadding
	local p = UDim.new(0, pixels)
	return Kit.new("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p })
end

function Kit.list(spacing: number, horizontal: boolean?): UIListLayout
	return Kit.new("UIListLayout", {
		Padding = UDim.new(0, spacing),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
end

function Kit.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Kit.colors.text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Kit.new("TextLabel", defaults)
end

function Kit.darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

function Kit.hex(color: Color3, text: string): string
	return string.format('<font color="#%s">%s</font>', color:ToHex(), text)
end

function Kit.button(text: string, color: Color3, onClick: () -> (), props: { [string]: any }?): TextButton
	local button = Kit.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Font = Enum.Font.FredokaOne,
		Text = text,
		TextColor3 = Kit.colors.white,
		TextSize = 18,
		TextStrokeTransparency = 0.6,
		Size = UDim2.fromOffset(140, 40),
	}, { Kit.corner(10), Kit.stroke(Kit.darken(color, 0.35), 2) })
	if props then
		for key, value in props do
			(button :: any)[key] = value
		end
	end
	local scale = Kit.new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		scale.Scale = 0.92
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		onClick()
	end)
	return button
end

function Kit.paint(button: TextButton, color: Color3)
	button.BackgroundColor3 = color
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Kit.darken(color, 0.35)
	end
end

function Kit.card(height: number, order: number, accent: Color3?): Frame
	return Kit.new("Frame", {
		BackgroundColor3 = Kit.colors.card,
		Size = UDim2.new(1, -8, 0, height),
		LayoutOrder = order,
	}, { Kit.corner(12), Kit.stroke(accent or Kit.colors.border, 2) })
end

function Kit.section(text: string, order: number): TextLabel
	return Kit.label({
		Text = text,
		Font = Enum.Font.FredokaOne,
		TextSize = 22,
		Size = UDim2.new(1, -8, 0, 30),
		LayoutOrder = order,
	})
end

return Kit
