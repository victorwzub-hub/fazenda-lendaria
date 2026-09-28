local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.Kit)

local Notifications = {}

local TOAST_SECONDS = 2.6
local MAX_TOASTS = 5
local BIG_SECONDS = 3.8
local REVEAL_SECONDS = 3.2

local toastList: Frame
local toastCount = 0
local bigLabel: TextLabel
local bigSub: TextLabel
local bigToken = 0
local revealFrame: TextButton
local revealTitle: TextLabel
local revealName: TextLabel
local revealSub: TextLabel
local revealGradient: UIGradient
local revealQueue = {}
local revealing = false

function Notifications.mount(gui: ScreenGui, scales: { UIScale })
	local toastLayout = Kit.list(6)
	toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	toastList = Kit.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(460, 260),
		Parent = gui,
	}, { toastLayout })
	table.insert(scales, Kit.new("UIScale", { Parent = toastList }))

	local big = Kit.new("Frame", {
		Name = "Aviso",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(820, 110),
		Parent = gui,
	})
	table.insert(scales, Kit.new("UIScale", { Parent = big }))
	bigLabel = Kit.label({
		Font = Enum.Font.FredokaOne,
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.fromRGB(60, 35, 15),
		Size = UDim2.new(1, 0, 0, 60),
		Parent = big,
	})
	bigSub = Kit.label({
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = Kit.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.2,
		TextTransparency = 1,
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 44),
		Parent = big,
	})

	revealGradient = Kit.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 240, 200)),
	})
	revealFrame = Kit.new("TextButton", {
		Name = "Revelacao",
		AutoButtonColor = false,
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 230),
		BackgroundColor3 = Kit.colors.panel,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	}, { Kit.corner(22), Kit.stroke(Kit.colors.border, 5), revealGradient })
	local revealScale = Kit.new("UIScale", { Parent = revealFrame })
	table.insert(scales, revealScale)
	revealTitle = Kit.label({
		Font = Enum.Font.FredokaOne,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 34),
		ZIndex = 11,
		Parent = revealFrame,
	})
	revealName = Kit.label({
		Font = Enum.Font.FredokaOne,
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Color3.fromRGB(60, 35, 15),
		Position = UDim2.fromOffset(10, 64),
		Size = UDim2.new(1, -20, 0, 90),
		TextScaled = true,
		ZIndex = 11,
		Parent = revealFrame,
	})
	revealSub = Kit.label({
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Kit.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(16, 166),
		Size = UDim2.new(1, -32, 0, 48),
		ZIndex = 11,
		Parent = revealFrame,
	})
	revealFrame.Activated:Connect(function()
		revealFrame.Visible = false
	end)
end

function Notifications.toast(text: string, color: Color3?)
	local accent = color or Kit.colors.yellow
	local toasts = {}
	for _, child in toastList:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts >= MAX_TOASTS then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
	toastCount += 1

	local toast = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 30, 20),
		BackgroundTransparency = 0.25,
		Size = UDim2.fromOffset(440, 38),
		LayoutOrder = toastCount,
		Parent = toastList,
	}, { Kit.corner(10), Kit.stroke(accent, 2) })
	local label = Kit.label({
		Text = text,
		Font = Enum.Font.FredokaOne,
		TextSize = 19,
		TextColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.35),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.5,
		Size = UDim2.fromScale(1, 1),
		Parent = toast,
	})
	task.delay(TOAST_SECONDS, function()
		if not toast.Parent then
			return
		end
		local info = TweenInfo.new(0.4)
		TweenService:Create(toast, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.4)
		toast:Destroy()
	end)
end

function Notifications.big(title: string, subtitle: string?, color: Color3?)
	bigToken += 1
	local token = bigToken
	bigLabel.Text = title
	bigLabel.TextColor3 = color or Kit.colors.yellow
	bigSub.Text = subtitle or ""
	bigLabel.TextTransparency = 0
	bigLabel.TextStrokeTransparency = 0
	bigSub.TextTransparency = 0
	bigSub.TextStrokeTransparency = 0.2
	bigLabel.TextSize = 20
	TweenService:Create(bigLabel, TweenInfo.new(0.35, Enum.EasingStyle.Back), { TextSize = 44 }):Play()
	task.delay(BIG_SECONDS, function()
		if token ~= bigToken then
			return
		end
		local info = TweenInfo.new(0.6)
		TweenService:Create(bigLabel, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(bigSub, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

local function showNextReveal()
	local payload = table.remove(revealQueue, 1)
	if not payload then
		revealing = false
		return
	end
	revealing = true
	local color: Color3 = payload.color or Kit.colors.yellow
	revealTitle.Text = payload.title or ""
	revealName.Text = payload.name or ""
	revealName.TextColor3 = color
	revealSub.Text = payload.sub or ""
	revealGradient.Color = ColorSequence.new(Kit.colors.panel, Kit.colors.panel:Lerp(color, 0.35))
	revealGradient.Rotation = 0
	revealFrame.Size = UDim2.fromOffset(300, 150)
	revealFrame.Visible = true
	TweenService:Create(revealFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(460, 230) })
		:Play()
	TweenService:Create(revealGradient, TweenInfo.new(REVEAL_SECONDS), { Rotation = 180 }):Play()

	local started = os.clock()
	while revealFrame.Visible and os.clock() - started < REVEAL_SECONDS do
		task.wait(0.1)
	end
	revealFrame.Visible = false
	task.wait(0.15)
	showNextReveal()
end

function Notifications.reveal(payload)
	table.insert(revealQueue, payload)
	if not revealing then
		task.spawn(showNextReveal)
	end
end

return Notifications
