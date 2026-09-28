local Kit = require(script.Parent.Kit)

export type Context = {
	act: (action: string, arg: string?) -> (boolean, any),
	track: (target: GuiObject, cost: number, apply: (affordable: boolean) -> ()) -> (),
	close: () -> (),
}

export type Renderer = (content: Frame, profile: any, ctx: Context) -> ()

local Panel = {}
Panel.__index = Panel

function Panel.new(parent: Instance, title: string, accent: Color3, onClose: () -> ())
	local self = setmetatable({}, Panel)
	self.costs = {} :: { { cost: number, apply: (boolean) -> () } }
	self.content = nil :: Frame?

	self.frame = Kit.new("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(640, 470),
		BackgroundColor3 = Kit.colors.panel,
		Visible = false,
		Parent = parent,
	}, { Kit.corner(18), Kit.stroke(Kit.colors.border, 4) })
	self.scale = Kit.new("UIScale", { Parent = self.frame })

	local header = Kit.new("Frame", {
		BackgroundColor3 = accent,
		Size = UDim2.new(1, 0, 0, 58),
		Parent = self.frame,
	}, { Kit.corner(18) })
	Kit.new("Frame", {
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -18),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = header,
	})
	Kit.label({
		Text = title,
		Font = Enum.Font.FredokaOne,
		TextSize = 30,
		TextColor3 = Kit.colors.white,
		TextStrokeTransparency = 0.5,
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -90, 1, 0),
		ZIndex = 2,
		Parent = header,
	})
	Kit.button("X", Kit.colors.red, onClose, {
		Size = UDim2.fromOffset(42, 42),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		TextSize = 22,
		ZIndex = 2,
		Parent = header,
	})

	self.body = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 68),
		Size = UDim2.new(1, -24, 1, -80),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Kit.colors.border,
		Parent = self.frame,
	})
	return self
end

function Panel:isOpen(): boolean
	return self.frame.Visible
end

function Panel:setVisible(visible: boolean)
	self.frame.Visible = visible
end

function Panel:render(renderer: Renderer, profile, baseCtx, coins: number)
	local scroll = self.body.CanvasPosition
	if self.content then
		self.content:Destroy()
	end
	self.costs = {}
	local content = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = self.body,
	}, {
		Kit.list(10),
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10) }),
	})
	self.content = content

	local ctx: Context = {
		act = baseCtx.act,
		close = baseCtx.close,
		track = function(_target, cost, apply)
			table.insert(self.costs, { cost = cost, apply = apply })
			apply(coins >= cost)
		end,
	}
	renderer(content, profile, ctx)
	task.defer(function()
		self.body.CanvasPosition = scroll
	end)
end

function Panel:refreshCosts(coins: number)
	for _, entry in self.costs do
		entry.apply(coins >= entry.cost)
	end
end

return Panel
