--[[
	INORHub UI Library  v2.0.0
	Library UI ringan untuk Roblox: tema gelap modern, animasi halus, dukungan mouse + touch.

	API:
		local Hub = loadstring(...)()            -- atau require
		local win = Hub:CreateWindow("Judul")
		win:AddLabel{text = "..."}
		win:AddToggle{text, state, flag, callback}
		win:AddButton{text, callback}
		win:AddBind{text, key, hold, callback}
		win:AddSlider{text, min, max, value, float, callback}
		win:AddList{text, values, value, callback}
		win:AddBox{text, value, placeholder, callback}
		win:AddColor{text, color, callback}
		local folder = win:AddFolder("Judul")    -- punya semua method Add* yang sama
		Hub:Init()
		Hub:Close()                              -- tampil / sembunyi semua window
		Hub:Notify{title, text, duration}
		Hub:SetToggleKey(Enum.KeyCode.RightShift)
		Hub:SetTheme{Accent = Color3.fromRGB(...)}  -- panggil SEBELUM Init
		Hub.flags[flag]                          -- nilai terkini semua elemen
]]

local INORHub = {flags = {}, windows = {}, open = true, version = "2.2.0", showAvatar = true, watermark = "tt: indr.ra_"}

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

--// Theme
local Theme = {
	Background   = Color3.fromRGB(17, 17, 23),
	Header       = Color3.fromRGB(23, 23, 31),
	Element      = Color3.fromRGB(30, 30, 40),
	ElementHover = Color3.fromRGB(39, 39, 52),
	Track        = Color3.fromRGB(46, 46, 60),
	Stroke       = Color3.fromRGB(54, 54, 70),
	Popup        = Color3.fromRGB(24, 24, 32),
	Text         = Color3.fromRGB(236, 236, 245),
	SubText      = Color3.fromRGB(148, 148, 168),
	Accent       = Color3.fromRGB(240, 60, 70),
	Font         = Enum.Font.GothamBlack,
	FontBold     = Enum.Font.GothamBlack,
	FontTitle    = Enum.Font.LuckiestGuy,
	FontCode     = Enum.Font.Code,
}
INORHub.Theme = Theme

local TWEEN_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_MED  = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_SLOW = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local WHITE = Color3.new(1, 1, 1)

--// State
local connections = {}
local activeDrag
local zCounter = 1

--// Helpers
local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
	return c
end

local function tween(obj, info, props)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

local function fire(callback, ...)
	local ok, err = pcall(callback, ...)
	if not ok then
		warn("[INORHub] callback error: " .. tostring(err))
	end
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

local function inside(gui, pos)
	local p, s = gui.AbsolutePosition, gui.AbsoluteSize
	return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
end

local function round(num, step)
	step = (type(step) == "number" and step > 0) and step or 1
	local v = math.floor(num / step + 0.5) * step
	return tonumber(string.format("%.8g", v)) or v
end

function INORHub:Create(class, properties)
	local inst = Instance.new(class)
	local parent
	for property, value in next, properties or {} do
		if property == "Parent" then
			parent = value
		else
			inst[property] = value
		end
	end
	inst.Parent = parent
	return inst
end

local function new(class, props)
	return INORHub:Create(class, props)
end

local function corner(parent, radius)
	return new("UICorner", {CornerRadius = UDim.new(0, radius), Parent = parent})
end

local function stroke(parent, color, thickness, transparency)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function label(props)
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.Font = props.Font or Theme.Font
	props.TextColor3 = props.TextColor3 or Theme.Text
	props.TextSize = props.TextSize or 17
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return new("TextLabel", props)
end

local function hover(row, normal, over)
	connect(row.MouseEnter, function()
		tween(row, TWEEN_FAST, {BackgroundColor3 = over or Theme.ElementHover})
	end)
	connect(row.MouseLeave, function()
		tween(row, TWEEN_FAST, {BackgroundColor3 = normal or Theme.Element})
	end)
end

local function newRow(option, parent, height, class)
	local props = {
		Name = option.type,
		LayoutOrder = option.position,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Theme.Element,
		BorderSizePixel = 0,
		Parent = parent.content,
	}
	if class == "TextButton" then
		props.Text = ""
		props.AutoButtonColor = false
	end
	local row = new(class or "Frame", props)
	corner(row, 8)
	return row
end

-- Drag generik (window, slider, color picker). Dipicu lewat InputBegan, dilanjut global.
local function startDrag(onMove, onEnd)
	activeDrag = {onMove = onMove, onEnd = onEnd}
end

--// Popup (dropdown & color picker)
local function createPopup(width, height)
	local holder = new("CanvasGroup", {
		Name = "Popup",
		ZIndex = 5000,
		Size = UDim2.new(0, width, 0, height),
		BackgroundColor3 = Theme.Popup,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
		Parent = INORHub.base,
	})
	corner(holder, 10)
	stroke(holder, Theme.Stroke, 1, 0.2)
	return holder
end

local function openPopup(option, holder, anchor)
	if INORHub.activePopup and INORHub.activePopup ~= option then
		INORHub.activePopup:Close()
	end
	local pos, size = anchor.AbsolutePosition, anchor.AbsoluteSize
	local screen = INORHub.base.AbsoluteSize
	local w, h = holder.Size.X.Offset, holder.Size.Y.Offset
	local x = math.clamp(pos.X, 0, math.max(screen.X - w, 0))
	local y = pos.Y + size.Y + 4
	if y + h > screen.Y then
		y = math.max(pos.Y - h - 4, 0)
	end
	holder.Position = UDim2.fromOffset(x, y - 6)
	holder.Visible = true
	option.open = true
	INORHub.activePopup = option
	tween(holder, TWEEN_SLOW, {GroupTransparency = 0, Position = UDim2.fromOffset(x, y)})
end

local function closePopup(option, holder)
	option.open = false
	if INORHub.activePopup == option then
		INORHub.activePopup = nil
	end
	tween(holder, TWEEN_FAST, {GroupTransparency = 1})
	task.delay(0.15, function()
		if not option.open then
			holder.Visible = false
		end
	end)
end

--// Window / Folder holder
local function createOptionHolder(holderTitle, parent, tbl, isFolder)
	local hasMark = (not isFolder) and INORHub.watermark and true or false
	local headerH = isFolder and 32 or (hasMark and 50 or 40)

	local main = new("Frame", {
		Name = tostring(holderTitle),
		LayoutOrder = isFolder and tbl.position or 0,
		Position = isFolder and UDim2.new() or UDim2.new(0, 20 + (250 * (tbl.position or 0)), 0, 20),
		Size = isFolder and UDim2.new(1, 0, 0, headerH) or UDim2.new(0, 230, 0, headerH),
		BackgroundColor3 = isFolder and Theme.Header or Theme.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = parent,
	})
	corner(main, isFolder and 8 or 12)
	if not isFolder then
		stroke(main, Theme.Stroke, 1, 0.3)
	end
	tbl.main = main

	local header = new("TextButton", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, headerH),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = main,
	})

	if not isFolder then
		local pill = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.new(0, 4, 0, 16),
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
			Parent = header,
		})
		corner(pill, 2)
	end

	local hasAvatar = (not isFolder) and INORHub.showAvatar
	if hasAvatar then
		local avatar = new("ImageLabel", {
			Name = "Avatar",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 24, 0.5, 0),
			Size = UDim2.new(0, 26, 0, 26),
			BackgroundColor3 = Theme.Element,
			BorderSizePixel = 0,
			Image = "",
			Parent = header,
		})
		corner(avatar, 13)
		stroke(avatar, Theme.Accent, 1.5, 0)
		task.spawn(function()
			local ok, content = pcall(function()
				return Players:GetUserThumbnailAsync(
					Players.LocalPlayer.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size48x48
				)
			end)
			if ok and content then
				avatar.Image = content
			end
		end)
	end

	local title = label({
		Name = "Title",
		Position = UDim2.new(0, isFolder and 12 or (hasAvatar and 58 or 26), 0, hasMark and 3 or 0),
		Size = hasMark and UDim2.new(1, hasAvatar and -90 or -50, 0, 28) or UDim2.new(1, hasAvatar and -90 or -50, 1, 0),
		Text = tostring(holderTitle),
		Font = Theme.FontTitle,
		TextSize = isFolder and 16 or 17,
		Parent = header,
	})

	if hasMark then
		label({
			Name = "Watermark",
			Position = UDim2.new(0, hasAvatar and 58 or 26, 0, 30),
			Size = UDim2.new(1, hasAvatar and -90 or -50, 0, 14),
			Text = tostring(INORHub.watermark),
			Font = Theme.FontBold,
			TextSize = 12,
			TextColor3 = Theme.Accent,
			Parent = header,
		})
	end

	local arrow = label({
		Name = "Arrow",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 16, 0, 16),
		Text = ">",
		Font = Theme.FontBold,
		TextSize = 14,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		Rotation = tbl.open and 90 or 0,
		Parent = header,
	})

	local divider = new("Frame", {
		Position = UDim2.new(0, 12, 0, headerH - 1),
		Size = UDim2.new(1, -24, 0, 1),
		BackgroundColor3 = Theme.Stroke,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = main,
	})

	local content = new("Frame", {
		Name = "Content",
		Position = UDim2.new(0, 0, 0, headerH),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		Parent = main,
	})
	tbl.content = content

	new("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = content,
	})

	local layout = new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = content,
	})

	local function refresh(animate)
		local hasContent = #tbl.options > 0
		content.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y + 12)
		local h = (tbl.open and hasContent) and (headerH + layout.AbsoluteContentSize.Y + 12) or headerH
		local size = isFolder and UDim2.new(1, 0, 0, h) or UDim2.new(0, 230, 0, h)
		tween(divider, TWEEN_MED, {BackgroundTransparency = (tbl.open and hasContent) and 0.4 or 1})
		if animate then
			main:TweenSize(size, "Out", "Quad", 0.2, true)
		else
			main.Size = size
		end
	end

	connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		refresh(false)
	end)

	local function toggle()
		tbl.open = not tbl.open
		tween(arrow, TWEEN_MED, {Rotation = tbl.open and 90 or 0})
		refresh(true)
	end

	if isFolder then
		connect(header.Activated, toggle)
	else
		local moved = false
		connect(header.InputBegan, function(input)
			if not isPress(input) then return end
			if INORHub.activePopup then INORHub.activePopup:Close() end
			moved = false
			zCounter = zCounter + 1
			main.ZIndex = zCounter
			local dragStart = input.Position
			local startPos = main.Position
			startDrag(function(move)
				local delta = move.Position - dragStart
				if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
					moved = true
				end
				main:TweenPosition(UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, math.max(startPos.Y.Offset + delta.Y, 0)), "Out", "Quint", 0.08, true)
			end)
		end)
		connect(header.Activated, function()
			if not moved then toggle() end
		end)
	end

	function tbl:SetTitle(newTitle)
		title.Text = tostring(newTitle)
	end

	refresh(false)
	return tbl
end

--// Elements
local function createLabel(option, parent)
	local main = label({
		Name = "Label",
		LayoutOrder = option.position,
		Size = UDim2.new(1, 0, 0, 26),
		Text = option.text,
		TextSize = 17,
		TextColor3 = Theme.Text,
		Parent = parent.content,
	})
	new("UIPadding", {PaddingLeft = UDim.new(0, 4), Parent = main})

	function option:SetText(text)
		main.Text = tostring(text)
	end

	setmetatable(option, {__newindex = function(t, k, v)
		if k == "Text" then
			main.Text = tostring(v)
		else
			rawset(t, k, v)
		end
	end})
end

local function createToggle(option, parent)
	local row = newRow(option, parent, 34, "TextButton")
	hover(row)

	label({
		Name = "Title",
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(1, -64, 1, 0),
		Text = option.text,
		Parent = row,
	})

	local track = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 36, 0, 20),
		BackgroundColor3 = option.state and Theme.Accent or Theme.Track,
		BorderSizePixel = 0,
		Parent = row,
	})
	corner(track, 10)

	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = option.state and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.new(0, 16, 0, 16),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = track,
	})
	corner(knob, 8)

	connect(row.Activated, function()
		option:SetState(not option.state)
	end)

	function option:SetState(state)
		state = state and true or false
		INORHub.flags[self.flag] = state
		self.state = state
		tween(track, TWEEN_MED, {BackgroundColor3 = state and Theme.Accent or Theme.Track})
		tween(knob, TWEEN_MED, {Position = state and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)})
		fire(self.callback, state)
	end

	function option:SetText(text)
		row.Title.Text = tostring(text)
	end

	if option.state then
		task.delay(1, function()
			fire(option.callback, true)
		end)
	end

	setmetatable(option, {__newindex = function(t, k, v)
		if k == "Text" then
			row.Title.Text = tostring(v)
		else
			rawset(t, k, v)
		end
	end})
end

local function createButton(option, parent)
	local row = newRow(option, parent, 34, "TextButton")
	row.Text = option.text
	row.Font = Theme.FontBold
	row.TextSize = 17
	row.TextColor3 = Theme.Text
	hover(row)

	connect(row.MouseButton1Down, function()
		tween(row, TWEEN_FAST, {BackgroundColor3 = Theme.Accent})
	end)
	connect(row.Activated, function()
		INORHub.flags[option.flag] = true
		tween(row, TWEEN_MED, {BackgroundColor3 = Theme.ElementHover})
		fire(option.callback)
	end)
end

local function keyLabel(key)
	if string.find(key, "Mouse") then
		return "MB" .. string.sub(key, -1)
	end
	return key
end

local function createBind(option, parent)
	local binding = false
	local loop

	local row = newRow(option, parent, 34, "TextButton")
	hover(row)

	label({
		Name = "Title",
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(1, -90, 1, 0),
		Text = option.text,
		Parent = row,
	})

	local keyBox = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 22),
		BackgroundColor3 = Theme.Track,
		BorderSizePixel = 0,
		Text = keyLabel(option.key),
		Font = Theme.FontBold,
		TextSize = 16,
		TextColor3 = Theme.SubText,
		Parent = row,
	})
	corner(keyBox, 6)
	new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = keyBox})

	connect(row.Activated, function()
		if binding then return end
		binding = true
		keyBox.Text = "..."
		tween(keyBox, TWEEN_FAST, {BackgroundColor3 = Theme.Accent, TextColor3 = WHITE})
	end)

	local function matches(input)
		return input.KeyCode.Name == option.key or input.UserInputType.Name == option.key
	end

	connect(UserInputService.InputBegan, function(input)
		if UserInputService:GetFocusedTextBox() then return end
		if binding then
			if isPress(input) then return end
			local newKey
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape then
					option:SetKey()
					return
				end
				newKey = input.KeyCode.Name
			elseif input.UserInputType == Enum.UserInputType.MouseButton2
				or input.UserInputType == Enum.UserInputType.MouseButton3 then
				newKey = input.UserInputType.Name
			end
			if newKey then option:SetKey(newKey) end
			return
		end
		if matches(input) then
			if option.hold then
				if loop then return end
				loop = RunService.Heartbeat:Connect(function()
					fire(option.callback)
				end)
			else
				fire(option.callback)
			end
		end
	end)

	connect(UserInputService.InputEnded, function(input)
		if loop and matches(input) then
			loop:Disconnect()
			loop = nil
			fire(option.callback, true)
		end
	end)

	function option:SetKey(key)
		binding = false
		if loop then
			loop:Disconnect()
			loop = nil
		end
		if typeof(key) == "EnumItem" then key = key.Name end
		self.key = key or self.key
		INORHub.flags[self.flag] = self.key
		keyBox.Text = keyLabel(self.key)
		tween(keyBox, TWEEN_FAST, {BackgroundColor3 = Theme.Track, TextColor3 = Theme.SubText})
	end
end

local function createSlider(option, parent)
	local row = newRow(option, parent, 50)

	label({
		Position = UDim2.new(0, 12, 0, 6),
		Size = UDim2.new(1, -84, 0, 22),
		Text = option.text,
		Parent = row,
	})

	local valueBox = new("TextBox", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 7),
		Size = UDim2.new(0, 60, 0, 22),
		BackgroundColor3 = Theme.Track,
		BorderSizePixel = 0,
		Text = tostring(option.value),
		TextColor3 = Theme.Text,
		Font = Theme.FontBold,
		TextSize = 15,
		ClearTextOnFocus = false,
		Parent = row,
	})
	corner(valueBox, 6)

	local track = new("Frame", {
		Position = UDim2.new(0, 12, 0, 36),
		Size = UDim2.new(1, -24, 0, 6),
		BackgroundColor3 = Theme.Track,
		BorderSizePixel = 0,
		Parent = row,
	})
	corner(track, 3)

	local fill = new("Frame", {
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = track,
	})
	corner(fill, 3)

	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 12, 0, 12),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = track,
	})
	corner(knob, 6)

	local function span()
		local s = option.max - option.min
		return s ~= 0 and s or 1
	end

	local function place(value, animate)
		local p = (value - option.min) / span()
		local fillPos, fillSize
		if option.min >= 0 then
			fillPos = UDim2.new(0, 0, 0, 0)
			fillSize = UDim2.new(p, 0, 1, 0)
		else
			local z = math.clamp((0 - option.min) / span(), 0, 1)
			local a, b = math.min(p, z), math.max(p, z)
			fillPos = UDim2.new(a, 0, 0, 0)
			fillSize = UDim2.new(b - a, 0, 1, 0)
		end
		local knobPos = UDim2.new(p, 0, 0.5, 0)
		if animate then
			tween(knob, TWEEN_FAST, {Position = knobPos})
			tween(fill, TWEEN_FAST, {Position = fillPos, Size = fillSize})
		else
			knob.Position = knobPos
			fill.Position = fillPos
			fill.Size = fillSize
		end
	end
	place(option.value, false)

	local function fromInput(input)
		local rel = (input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		option:SetValue(option.min + math.clamp(rel, 0, 1) * (option.max - option.min))
	end

	connect(row.InputBegan, function(input)
		if not isPress(input) or inside(valueBox, input.Position) then return end
		tween(knob, TWEEN_FAST, {Size = UDim2.new(0, 16, 0, 16)})
		fromInput(input)
		startDrag(fromInput, function()
			tween(knob, TWEEN_FAST, {Size = UDim2.new(0, 12, 0, 12)})
		end)
	end)

	connect(valueBox.FocusLost, function()
		option:SetValue(tonumber(valueBox.Text) or option.value)
	end)

	function option:SetValue(value)
		value = math.clamp(round(tonumber(value) or self.value, self.float), self.min, self.max)
		self.value = value
		INORHub.flags[self.flag] = value
		valueBox.Text = tostring(value)
		place(value, true)
		fire(self.callback, value)
	end
end

local function createList(option, parent)
	local count = 0
	local buttons = {}

	local row = newRow(option, parent, 52, "TextButton")
	hover(row)

	label({
		Position = UDim2.new(0, 12, 0, 7),
		Size = UDim2.new(1, -40, 0, 14),
		Text = option.text,
		TextSize = 14,
		TextColor3 = Theme.SubText,
		Parent = row,
	})

	local valueLabel = label({
		Position = UDim2.new(0, 12, 0, 24),
		Size = UDim2.new(1, -40, 0, 22),
		Text = option.value,
		TextSize = 18,
		Font = Theme.FontBold,
		Parent = row,
	})

	local arrow = label({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 16, 0, 16),
		Text = ">",
		Font = Theme.FontBold,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		Rotation = 90,
		Parent = row,
	})

	local holder = createPopup(row.AbsoluteSize.X > 0 and row.AbsoluteSize.X or 214, 38)
	option.mainHolder = holder
	option.anchor = row

	local scroller = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = holder,
	})
	new("UIPadding", {
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
		Parent = scroller,
	})
	new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = scroller})

	local function resize()
		holder.Size = UDim2.new(0, math.max(row.AbsoluteSize.X, 120), 0, math.min(count, 5) * 32 + 8)
	end

	local function highlight()
		for value, btn in next, buttons do
			btn.TextColor3 = (value == option.value) and Theme.Accent or Theme.Text
		end
	end

	function option:AddValue(value)
		value = tostring(value)
		if buttons[value] then return end
		count = count + 1
		local btn = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = Theme.Popup,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = value,
			Font = Theme.Font,
			TextSize = 14,
			TextColor3 = (value == self.value) and Theme.Accent or Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = count,
			Parent = scroller,
		})
		corner(btn, 6)
		new("UIPadding", {PaddingLeft = UDim.new(0, 10), Parent = btn})
		hover(btn, Theme.Popup, Theme.Element)
		buttons[value] = btn
		connect(btn.Activated, function()
			self:SetValue(value)
			self:Close()
		end)
	end

	function option:RemoveValue(value)
		value = tostring(value)
		local btn = buttons[value]
		if btn then
			btn:Destroy()
			buttons[value] = nil
			count = count - 1
		end
		if self.value == value then
			self:SetValue("")
		end
	end

	function option:SetValue(value)
		self.value = tostring(value)
		INORHub.flags[self.flag] = self.value
		valueLabel.Text = self.value
		highlight()
		fire(self.callback, value)
	end

	function option:Open()
		resize()
		tween(arrow, TWEEN_MED, {Rotation = -90})
		openPopup(self, holder, row)
	end

	function option:Close()
		if not self.open then return end
		tween(arrow, TWEEN_MED, {Rotation = 90})
		closePopup(self, holder)
	end

	connect(row.Activated, function()
		if option.open then option:Close() else option:Open() end
	end)

	if option.value ~= "" then
		option:AddValue(option.value)
	end
	for _, value in next, option.values do
		option:AddValue(value)
	end
	resize()

	return option
end

local function createBox(option, parent)
	local row = newRow(option, parent, 52)
	local outline = stroke(row, Theme.Stroke, 1, 0.5)

	label({
		Position = UDim2.new(0, 12, 0, 7),
		Size = UDim2.new(1, -24, 0, 14),
		Text = option.text,
		TextSize = 14,
		TextColor3 = Theme.SubText,
		Parent = row,
	})

	local input = new("TextBox", {
		Position = UDim2.new(0, 12, 0, 24),
		Size = UDim2.new(1, -24, 0, 22),
		BackgroundTransparency = 1,
		Text = option.value,
		PlaceholderText = option.placeholder or "",
		PlaceholderColor3 = Theme.SubText,
		TextColor3 = Theme.Text,
		Font = Theme.FontBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = row,
	})

	connect(row.InputBegan, function(i)
		if isPress(i) and not input:IsFocused() then
			input:CaptureFocus()
		end
	end)
	connect(input.Focused, function()
		tween(outline, TWEEN_MED, {Color = Theme.Accent, Transparency = 0})
	end)
	connect(input.FocusLost, function(enter)
		tween(outline, TWEEN_MED, {Color = Theme.Stroke, Transparency = 0.5})
		option:SetValue(input.Text, enter)
	end)

	function option:SetValue(value, enter)
		self.value = tostring(value)
		INORHub.flags[self.flag] = self.value
		input.Text = self.value
		fire(self.callback, value, enter)
	end
end

local function createColor(option, parent)
	local row = newRow(option, parent, 34, "TextButton")
	hover(row)

	label({
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(1, -64, 1, 0),
		Text = option.text,
		Parent = row,
	})

	local swatch = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 34, 0, 18),
		BackgroundColor3 = option.color,
		BorderSizePixel = 0,
		Parent = row,
	})
	corner(swatch, 5)
	stroke(swatch, Theme.Stroke, 1, 0)

	option.anchor = row

	local built = false
	local hue, sat, val = Color3.toHSV(option.color)
	local currentColor = option.color
	local originalColor = option.color
	local history = {option.color}
	local rainbowLoop

	local svBox, svKnob, hueKnob, preview, rainbowText

	local function applyVisual()
		currentColor = Color3.fromHSV(hue, sat, val)
		preview.BackgroundColor3 = currentColor
		svBox.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		svKnob.Position = UDim2.new(sat, 0, 1 - val, 0)
		hueKnob.Position = UDim2.new(hue, 0, 0.5, 0)
	end

	local function popupButton(text, y)
		local btn = new("TextButton", {
			Position = UDim2.new(0, 152, 0, y),
			Size = UDim2.new(0, 80, 0, 20),
			BackgroundColor3 = Theme.Element,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = text,
			Font = Theme.FontCode,
			TextSize = 15,
			TextColor3 = Theme.Text,
			Parent = option.mainHolder,
		})
		corner(btn, 6)
		hover(btn, Theme.Element, Theme.ElementHover)
		return btn
	end

	local function build()
		built = true
		local holder = createPopup(240, 170)
		option.mainHolder = holder

		svBox = new("Frame", {
			Position = UDim2.new(0, 8, 0, 8),
			Size = UDim2.new(0, 136, 0, 126),
			BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Parent = holder,
		})
		corner(svBox, 6)

		local white = new("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Parent = svBox,
		})
		new("UIGradient", {
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
			Parent = white,
		})
		local black = new("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Parent = svBox,
		})
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)}),
			Parent = black,
		})

		svKnob = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 10, 0, 10),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = svBox,
		})
		corner(svKnob, 5)
		stroke(svKnob, WHITE, 2, 0)

		local hueBar = new("Frame", {
			Position = UDim2.new(0, 8, 0, 142),
			Size = UDim2.new(0, 136, 0, 14),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Parent = holder,
		})
		corner(hueBar, 7)
		new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
				ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
				ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
				ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
				ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
				ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1)),
			}),
			Parent = hueBar,
		})
		hueKnob = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 6, 1, 4),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Parent = hueBar,
		})
		corner(hueKnob, 3)
		stroke(hueKnob, Color3.new(0, 0, 0), 1, 0.5)

		preview = new("Frame", {
			Position = UDim2.new(0, 152, 0, 8),
			Size = UDim2.new(0, 80, 0, 40),
			BackgroundColor3 = currentColor,
			BorderSizePixel = 0,
			Parent = holder,
		})
		corner(preview, 8)
		stroke(preview, Theme.Stroke, 1, 0)

		local function svInput(input)
			sat = math.clamp((input.Position.X - svBox.AbsolutePosition.X) / math.max(svBox.AbsoluteSize.X, 1), 0, 1)
			val = 1 - math.clamp((input.Position.Y - svBox.AbsolutePosition.Y) / math.max(svBox.AbsoluteSize.Y, 1), 0, 1)
			applyVisual()
		end
		local function hueInput(input)
			hue = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 0.999)
			applyVisual()
		end
		connect(svBox.InputBegan, function(input)
			if isPress(input) then
				svInput(input)
				startDrag(svInput)
			end
		end)
		connect(hueBar.InputBegan, function(input)
			if isPress(input) then
				hueInput(input)
				startDrag(hueInput)
			end
		end)

		local rainbowing = false
		local resetBtn = popupButton("Reset", 54)
		local undoBtn = popupButton("Undo", 78)
		local setBtn = popupButton("Set", 102)
		local rainbowBtn = popupButton("Rainbow", 126)
		rainbowText = rainbowBtn

		connect(resetBtn.Activated, function()
			if rainbowing then return end
			history = {originalColor}
			option:SetColor(originalColor)
		end)
		connect(undoBtn.Activated, function()
			if rainbowing then return end
			if #history > 1 then table.remove(history) end
			option:SetColor(history[#history])
		end)
		connect(setBtn.Activated, function()
			if rainbowing then return end
			table.insert(history, currentColor)
			option:SetColor(currentColor)
		end)
		connect(rainbowBtn.Activated, function()
			rainbowing = not rainbowing
			if rainbowing then
				rainbowLoop = RunService.Heartbeat:Connect(function()
					local c = Color3.fromHSV(tick() % 5 / 5, 1, 1)
					rainbowBtn.TextColor3 = c
					option:SetColor(c)
				end)
			else
				if rainbowLoop then rainbowLoop:Disconnect() rainbowLoop = nil end
				rainbowBtn.TextColor3 = Theme.Text
				option:SetColor(history[#history])
			end
		end)

		applyVisual()
	end

	connect(row.Activated, function()
		if option.open then
			option:Close()
			return
		end
		if not built then build() end
		hue, sat, val = Color3.toHSV(option.color)
		applyVisual()
		openPopup(option, option.mainHolder, row)
	end)

	function option:SetColor(newColor)
		self.color = newColor
		INORHub.flags[self.flag] = newColor
		swatch.BackgroundColor3 = newColor
		if built then
			hue, sat, val = Color3.toHSV(newColor)
			applyVisual()
		end
		fire(self.callback, newColor)
	end

	function option:Close()
		if not self.open or not self.mainHolder then return end
		closePopup(self, self.mainHolder)
	end
end

local function loadOptions(holder)
	for _, option in next, holder.options do
		if option.type == "label" then
			createLabel(option, holder)
		elseif option.type == "toggle" then
			createToggle(option, holder)
		elseif option.type == "button" then
			createButton(option, holder)
		elseif option.type == "list" then
			createList(option, holder)
		elseif option.type == "box" then
			createBox(option, holder)
		elseif option.type == "bind" then
			createBind(option, holder)
		elseif option.type == "slider" then
			createSlider(option, holder)
		elseif option.type == "color" then
			createColor(option, holder)
		elseif option.type == "folder" then
			option:init()
		end
	end
end

--// Option constructors
local function attachMethods(parent)
	function parent:AddLabel(option)
		option = typeof(option) == "table" and option or {}
		option.text = tostring(option.text)
		option.type = "label"
		option.position = #self.options
		table.insert(self.options, option)
		return option
	end

	function parent:AddToggle(option)
		option = typeof(option) == "table" and option or {}
		option.text = tostring(option.text)
		option.state = typeof(option.state) == "boolean" and option.state or false
		option.callback = typeof(option.callback) == "function" and option.callback or function() end
		option.type = "toggle"
		option.position = #self.options
		option.flag = option.flag or option.text
		INORHub.flags[option.flag] = option.state
		table.insert(self.options, option)
		return option
	end

	function parent:AddButton(option)
		option = typeof(option) == "table" and option or {}
		option.text = tostring(option.text)
		option.callback = typeof(option.callback) == "function" and option.callback or function() end
		option.type = "button"
		option.position = #self.options
		option.flag = option.flag or option.text
		table.insert(self.options, option)
		return option
	end

	function parent:AddBind(option)
		option = typeof(option) == "table" and option or {}
		option.text = tostring(option.text)
		local key = option.key
		option.key = typeof(key) == "EnumItem" and key.Name or (key and tostring(key)) or "F"
		option.hold = typeof(option.hold) == "boolean" and option.hold or false
		option.callback = typeof(option.callback) == "function" and option.callback or function() end
		option.type = "bind"
		option.position = #self.options
		option.flag = option.flag or option.text
		INORHub.flags[option.flag] = option.key
		table.insert(self.options, option)
		return option
	end

	function parent:AddSlider(option)
		option = typeof(option) == "table" and option or {}
		option.text = tostring(option.text)
		option.min = typeof(option.min) == "number" and option.min or 0
		option.max = typeof(option.max) == "number" and option.max or 0
		option.value = math.clamp(typeof(option.value) == "number" and option.value or option.min, option.min, option.max)
		option.callback = typeof(option.callback) == "function" and option.callback or function() end
		option.float = typeof(option.float) == "number" and option.float or 1
		option.type = "slider"
		option.position = #self.options
		option.flag = option.flag or option.text
		INORHub.flags[option.flag] = option.value
		table.insert(self.options, option)
		return option
	end

	function parent:AddList(option)
		option = typeof(option) == "table" and option or {}
		option.text = tostring(option.text)
		option.values = typeof(option.values) == "table" and option.values or {}
		option.value = tostring(option.value or option.values[1] or "")
		option.callback = typeof(option.callback) == "function" and option.callback or function() end
		option.open = false
		option.type = "list"
		option.position = #self.options
		option.flag = option.flag or option.text
		INORHub.flags[option.flag] = option.value
		table.insert(self.options, option)
		return option
	end

	function parent:AddBox(option)
		option = typeof(option) == "table" and option or {}
		option.text = tostring(option.text)
		option.value = tostring(option.value or "")
		option.callback = typeof(option.callback) == "function" and option.callback or function() end
		option.type = "box"
		option.position = #self.options
		option.flag = option.flag or option.text
		INORHub.flags[option.flag] = option.value
		table.insert(self.options, option)
		return option
	end

	function parent:AddColor(option)
		option = typeof(option) == "table" and option or {}
		option.text = tostring(option.text)
		local c = option.color
		if typeof(c) == "table" then
			c = Color3.new(tonumber(c[1]) or 1, tonumber(c[2]) or 1, tonumber(c[3]) or 1)
		elseif typeof(c) ~= "Color3" then
			c = Color3.new(1, 1, 1)
		end
		option.color = c
		option.callback = typeof(option.callback) == "function" and option.callback or function() end
		option.open = false
		option.type = "color"
		option.position = #self.options
		option.flag = option.flag or option.text
		INORHub.flags[option.flag] = option.color
		table.insert(self.options, option)
		return option
	end

	function parent:AddFolder(title)
		local option = {}
		option.title = tostring(title)
		option.options = {}
		option.open = false
		option.type = "folder"
		option.position = #self.options
		table.insert(self.options, option)

		attachMethods(option)

		function option:init()
			createOptionHolder(self.title, parent.content, self, true)
			loadOptions(self)
		end

		return option
	end
end

--// Public API
function INORHub:CreateWindow(title)
	local window = {
		title = tostring(title),
		options = {},
		open = true,
		canInit = true,
		init = false,
		position = #self.windows,
	}
	attachMethods(window)
	table.insert(self.windows, window)
	return window
end

function INORHub:SetTheme(overrides)
	for key, value in next, overrides or {} do
		Theme[key] = value
	end
end

function INORHub:SetToggleKey(keyCode)
	self.toggleKey = keyCode
end

function INORHub:Init(parent)
	if not (self.base and self.base.Parent) then
		self.base = self:Create("ScreenGui", {
			Name = "INORHub",
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 1000,
		})
		self.base.Parent = parent or Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	for _, window in next, self.windows do
		if window.canInit and not window.init then
			window.init = true
			createOptionHolder(window.title, self.base, window)
			loadOptions(window)
		end
	end
	return self.base
end

function INORHub:Close()
	self.open = not self.open
	if self.activePopup then
		self.activePopup:Close()
	end
	for _, window in next, self.windows do
		if window.main then
			window.main.Visible = self.open
		end
	end
end
INORHub.Toggle = INORHub.Close

function INORHub:Notify(options)
	if not self.base then return end
	options = typeof(options) == "table" and options or {text = tostring(options)}
	local duration = tonumber(options.duration) or 4

	local stack = self.base:FindFirstChild("Notifications")
	if not stack then
		stack = new("Frame", {
			Name = "Notifications",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -16),
			Size = UDim2.new(0, 260, 1, -32),
			BackgroundTransparency = 1,
			ZIndex = 6000,
			Parent = self.base,
		})
		new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
			Parent = stack,
		})
	end

	local toast = new("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = stack,
	})
	corner(toast, 10)
	stroke(toast, Theme.Stroke, 1, 0.2)

	local bar = new("Frame", {
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = toast,
	})

	local body = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = toast,
	})
	new("UIPadding", {
		PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 12),
		Parent = body,
	})
	new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = body})

	if options.title then
		label({
			Size = UDim2.new(1, 0, 0, 16),
			Text = tostring(options.title),
			Font = Theme.FontBold,
			TextSize = 14,
			LayoutOrder = 1,
			Parent = body,
		})
	end
	if options.text then
		label({
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = tostring(options.text),
			TextSize = 13,
			TextColor3 = Theme.SubText,
			TextWrapped = true,
			LayoutOrder = 2,
			Parent = body,
		})
	end

	tween(toast, TWEEN_MED, {GroupTransparency = 0})
	task.delay(duration, function()
		local t = tween(toast, TWEEN_MED, {GroupTransparency = 1})
		t.Completed:Wait()
		toast:Destroy()
	end)
end

function INORHub:Destroy()
	for _, c in next, connections do
		pcall(function() c:Disconnect() end)
	end
	connections = {}
	if self.base then
		self.base:Destroy()
		self.base = nil
	end
	self.windows = {}
	self.flags = {}
end

--// Global input
connect(UserInputService.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if INORHub.toggleKey and input.KeyCode == INORHub.toggleKey and not UserInputService:GetFocusedTextBox() then
			INORHub:Close()
		end
		return
	end
	if isPress(input) and INORHub.activePopup then
		local popup = INORHub.activePopup
		if popup.mainHolder and not inside(popup.mainHolder, input.Position)
			and not (popup.anchor and inside(popup.anchor, input.Position)) then
			popup:Close()
		end
	end
end)

connect(UserInputService.InputChanged, function(input)
	if activeDrag and isMove(input) then
		activeDrag.onMove(input)
	end
end)

connect(UserInputService.InputEnded, function(input)
	if activeDrag and isPress(input) then
		local drag = activeDrag
		activeDrag = nil
		if drag.onEnd then drag.onEnd() end
	end
end)

return INORHub
