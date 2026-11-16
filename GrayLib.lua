--[[
    GrayLib - UI Library simpel (gaya Tora Library, tema abu-abu gelap)
    Mendukung PC & Mobile (touch)

    CONTOH:
    local library = loadstring(readfile("GrayLib.lua"))()
    local win = library:CreateWindow("Main")
    win:AddLabel({text = "Halo"})
    win:AddToggle({text = "Auto Farm", flag = "farm", callback = function(v) print(v) end})
    win:AddButton({text = "Klik", callback = function() print("klik") end})
    win:AddSlider({text = "Speed", min = 0, max = 100, value = 16, callback = function(v) print(v) end})
    win:AddList({text = "Mode", values = {"A", "B", "C"}, callback = function(v) print(v) end})
    win:AddBox({text = "Nama", callback = function(t) print(t) end})
    win:AddBind({text = "Key", key = "F", callback = function() print("tekan") end})
    local f = win:AddFolder("Folder")
    f:AddToggle({text = "Di dalam folder"})
    library:Init()
]]

local library = {flags = {}, windows = {}, open = true}

local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")

local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

local theme = {
    header = Color3.fromRGB(20, 20, 22),
    bg = Color3.fromRGB(28, 28, 31),
    folder = Color3.fromRGB(34, 34, 38),
    item = Color3.fromRGB(44, 44, 49),
    hover = Color3.fromRGB(58, 58, 64),
    on = Color3.fromRGB(175, 175, 182),
    off = Color3.fromRGB(70, 70, 76),
    text = Color3.fromRGB(235, 235, 238),
    sub = Color3.fromRGB(140, 140, 148),
}

-- Helpers
local function new(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    return inst
end

local function corner(obj, r)
    return new("UICorner", {CornerRadius = UDim.new(0, r or 6), Parent = obj})
end

local function tween(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function hover(obj, base, over)
    obj.MouseEnter:Connect(function() tween(obj, {BackgroundColor3 = over}, 0.1) end)
    obj.MouseLeave:Connect(function() tween(obj, {BackgroundColor3 = base}, 0.1) end)
end

local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

local function prep(opt, kind)
    if type(opt) == "string" then opt = {text = opt} end
    opt = opt or {}
    opt.text = opt.text or kind
    opt.flag = opt.flag or opt.text
    opt.callback = opt.callback or function() end
    return opt
end

local function getParent()
    local ok, ui = pcall(function() return gethui and gethui() end)
    if ok and ui then return ui end
    ok, ui = pcall(function() return game:GetService("CoreGui") end)
    if ok and ui then return ui end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- Root GUI
local base = new("ScreenGui", {
    Name = "GrayLib",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
})
if not pcall(function() base.Parent = getParent() end) then
    base.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local root = new("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Parent = base,
})

-- Komponen
local function addMethods(holder)
    local function nextOrder()
        holder.count = holder.count + 1
        return holder.count
    end

    function holder:AddLabel(opt)
        opt = prep(opt, "Label")
        local label = new("TextLabel", {
            LayoutOrder = nextOrder(),
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            Text = opt.text,
            Font = FONT,
            TextSize = 14,
            TextColor3 = theme.sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = self.content,
        })
        new("UIPadding", {PaddingLeft = UDim.new(0, 10), Parent = label})
        function opt:SetText(t) label.Text = tostring(t) end
        return opt
    end

    function holder:AddToggle(opt)
        opt = prep(opt, "Toggle")
        opt.state = opt.state and true or false
        local row = new("TextButton", {
            LayoutOrder = nextOrder(),
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Parent = self.content,
        })
        new("TextLabel", {
            Position = UDim2.new(0, 10, 0, 0),
            Size = UDim2.new(1, -60, 1, 0),
            BackgroundTransparency = 1,
            Text = opt.text,
            Font = FONT,
            TextSize = 14,
            TextColor3 = theme.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })
        local track = new("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.new(0, 34, 0, 18),
            BackgroundColor3 = opt.state and theme.on or theme.off,
            Parent = row,
        })
        corner(track, 9)
        local knob = new("Frame", {
            Position = opt.state and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6),
            Size = UDim2.new(0, 12, 0, 12),
            BackgroundColor3 = opt.state and theme.header or theme.text,
            Parent = track,
        })
        corner(knob, 6)

        function opt:SetState(state)
            self.state = state and true or false
            library.flags[self.flag] = self.state
            tween(track, {BackgroundColor3 = self.state and theme.on or theme.off})
            tween(knob, {
                Position = self.state and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6),
                BackgroundColor3 = self.state and theme.header or theme.text,
            })
            self.callback(self.state)
        end

        row.Activated:Connect(function() opt:SetState(not opt.state) end)
        library.flags[opt.flag] = opt.state
        if opt.state then task.delay(0.5, function() opt.callback(true) end) end
        return opt
    end

    function holder:AddButton(opt)
        opt = prep(opt, "Button")
        local holderRow = new("Frame", {
            LayoutOrder = nextOrder(),
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 1,
            Parent = self.content,
        })
        local btn = new("TextButton", {
            Position = UDim2.new(0, 4, 0, 2),
            Size = UDim2.new(1, -8, 1, -4),
            BackgroundColor3 = theme.item,
            Text = opt.text,
            Font = FONT,
            TextSize = 14,
            TextColor3 = theme.text,
            AutoButtonColor = false,
            Parent = holderRow,
        })
        corner(btn, 6)
        hover(btn, theme.item, theme.hover)
        btn.Activated:Connect(function()
            library.flags[opt.flag] = true
            btn.BackgroundColor3 = theme.on
            tween(btn, {BackgroundColor3 = theme.item}, 0.25)
            opt.callback()
        end)
        return opt
    end

    function holder:AddBind(opt)
        opt = prep(opt, "Bind")
        opt.key = opt.key or "None"
        if typeof(opt.key) == "EnumItem" then opt.key = opt.key.Name end
        local binding = false
        local row = new("Frame", {
            LayoutOrder = nextOrder(),
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundTransparency = 1,
            Parent = self.content,
        })
        new("TextLabel", {
            Position = UDim2.new(0, 10, 0, 0),
            Size = UDim2.new(1, -90, 1, 0),
            BackgroundTransparency = 1,
            Text = opt.text,
            Font = FONT,
            TextSize = 14,
            TextColor3 = theme.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })
        local keyBtn = new("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0),
            Size = UDim2.new(0, 64, 0, 22),
            BackgroundColor3 = theme.item,
            Text = opt.key,
            Font = FONT,
            TextSize = 12,
            TextColor3 = theme.text,
            AutoButtonColor = false,
            Parent = row,
        })
        corner(keyBtn, 5)
        hover(keyBtn, theme.item, theme.hover)

        function opt:SetKey(key)
            binding = false
            self.key = key or self.key
            library.flags[self.flag] = self.key
            keyBtn.Text = self.key
            tween(keyBtn, {BackgroundColor3 = theme.item})
        end

        keyBtn.Activated:Connect(function()
            binding = true
            keyBtn.Text = "..."
            tween(keyBtn, {BackgroundColor3 = theme.on})
        end)

        UIS.InputBegan:Connect(function(input, processed)
            if binding then
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    opt:SetKey(input.KeyCode.Name)
                elseif input.UserInputType == Enum.UserInputType.MouseButton2
                    or input.UserInputType == Enum.UserInputType.MouseButton3 then
                    opt:SetKey(input.UserInputType.Name)
                end
                return
            end
            if processed then return end
            if input.KeyCode.Name == opt.key or input.UserInputType.Name == opt.key then
                opt.callback()
            end
        end)
        library.flags[opt.flag] = opt.key
        return opt
    end

    function holder:AddSlider(opt)
        opt = prep(opt, "Slider")
        opt.min = opt.min or 0
        opt.max = opt.max or 100
        opt.float = opt.float or 1
        opt.value = math.clamp(opt.value or opt.min, opt.min, opt.max)

        local row = new("Frame", {
            LayoutOrder = nextOrder(),
            Size = UDim2.new(1, 0, 0, 48),
            BackgroundTransparency = 1,
            Parent = self.content,
        })
        new("TextLabel", {
            Position = UDim2.new(0, 10, 0, 4),
            Size = UDim2.new(1, -90, 0, 20),
            BackgroundTransparency = 1,
            Text = opt.text,
            Font = FONT,
            TextSize = 14,
            TextColor3 = theme.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })
        local box = new("TextBox", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -8, 0, 4),
            Size = UDim2.new(0, 56, 0, 20),
            BackgroundColor3 = theme.item,
            Text = tostring(opt.value),
            Font = FONT,
            TextSize = 12,
            TextColor3 = theme.text,
            ClearTextOnFocus = false,
            Parent = row,
        })
        corner(box, 5)
        local track = new("Frame", {
            Position = UDim2.new(0, 10, 0, 34),
            Size = UDim2.new(1, -20, 0, 5),
            BackgroundColor3 = theme.item,
            BorderSizePixel = 0,
            Parent = row,
        })
        corner(track, 3)
        local fill = new("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = theme.on,
            BorderSizePixel = 0,
            Parent = track,
        })
        corner(fill, 3)
        local knob = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.new(0, 12, 0, 12),
            BackgroundColor3 = theme.text,
            Parent = track,
        })
        corner(knob, 6)
        local hit = new("TextButton", {
            Position = UDim2.new(0, 6, 0, 26),
            Size = UDim2.new(1, -12, 0, 22),
            BackgroundTransparency = 1,
            Text = "",
            Parent = row,
        })

        function opt:SetValue(v)
            v = tonumber(v) or self.value
            v = math.floor(v / self.float + 0.5) * self.float
            v = tonumber(string.format("%.4f", v))
            v = math.clamp(v, self.min, self.max)
            local a = (v - self.min) / (self.max - self.min)
            tween(fill, {Size = UDim2.new(a, 0, 1, 0)}, 0.08)
            tween(knob, {Position = UDim2.new(a, 0, 0.5, 0)}, 0.08)
            self.value = v
            library.flags[self.flag] = v
            box.Text = tostring(v)
            self.callback(v)
        end

        local function fromX(x)
            local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            opt:SetValue(opt.min + a * (opt.max - opt.min))
        end

        local sliding = false
        hit.InputBegan:Connect(function(input)
            if isPress(input) then
                sliding = true
                fromX(input.Position.X)
            end
        end)
        UIS.InputChanged:Connect(function(input)
            if sliding and isMove(input) then fromX(input.Position.X) end
        end)
        UIS.InputEnded:Connect(function(input)
            if isPress(input) then sliding = false end
        end)
        box.FocusLost:Connect(function() opt:SetValue(box.Text) end)

        local a0 = (opt.value - opt.min) / (opt.max - opt.min)
        fill.Size = UDim2.new(a0, 0, 1, 0)
        knob.Position = UDim2.new(a0, 0, 0.5, 0)
        library.flags[opt.flag] = opt.value
        return opt
    end

    function holder:AddList(opt)
        opt = prep(opt, "List")
        opt.values = opt.values or {}
        opt.value = opt.value ~= nil and tostring(opt.value) or (opt.values[1] and tostring(opt.values[1])) or ""
        opt.open = false

        local main = new("Frame", {
            LayoutOrder = nextOrder(),
            Size = UDim2.new(1, 0, 0, 46),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            Parent = self.content,
        })
        local row = new("TextButton", {
            Position = UDim2.new(0, 4, 0, 2),
            Size = UDim2.new(1, -8, 0, 42),
            BackgroundColor3 = theme.item,
            Text = "",
            AutoButtonColor = false,
            Parent = main,
        })
        corner(row, 6)
        hover(row, theme.item, theme.hover)
        new("TextLabel", {
            Position = UDim2.new(0, 10, 0, 4),
            Size = UDim2.new(1, -40, 0, 14),
            BackgroundTransparency = 1,
            Text = opt.text,
            Font = FONT,
            TextSize = 11,
            TextColor3 = theme.sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })
        local valueLabel = new("TextLabel", {
            Position = UDim2.new(0, 10, 0, 18),
            Size = UDim2.new(1, -40, 0, 20),
            BackgroundTransparency = 1,
            Text = opt.value,
            Font = FONT_BOLD,
            TextSize = 14,
            TextColor3 = theme.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row,
        })
        local arrow = new("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.new(0, 16, 0, 16),
            BackgroundTransparency = 1,
            Text = "v",
            Font = FONT_BOLD,
            TextSize = 12,
            TextColor3 = theme.sub,
            Parent = row,
        })
        local scroll = new("ScrollingFrame", {
            Position = UDim2.new(0, 4, 0, 48),
            Size = UDim2.new(1, -8, 0, 0),
            BackgroundColor3 = theme.header,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = theme.on,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Parent = main,
        })
        corner(scroll, 6)
        new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll})

        local items = {}
        local count = 0

        local function refresh()
            local h = math.min(count, 4) * 28
            scroll.Size = UDim2.new(1, -8, 0, h)
            tween(main, {Size = UDim2.new(1, 0, 0, opt.open and (48 + h + 6) or 46)})
            tween(arrow, {Rotation = opt.open and 180 or 0})
        end

        function opt:SetValue(v)
            self.value = tostring(v)
            library.flags[self.flag] = self.value
            valueLabel.Text = self.value
            self.callback(v)
        end

        function opt:AddValue(v)
            v = tostring(v)
            count = count + 1
            local b = new("TextButton", {
                LayoutOrder = count,
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundColor3 = theme.header,
                BorderSizePixel = 0,
                Text = "  " .. v,
                Font = FONT,
                TextSize = 13,
                TextColor3 = theme.text,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false,
                Parent = scroll,
            })
            hover(b, theme.header, theme.item)
            b.Activated:Connect(function()
                opt:SetValue(v)
                opt.open = false
                refresh()
            end)
            items[v] = b
            refresh()
        end

        function opt:RemoveValue(v)
            v = tostring(v)
            if items[v] then
                items[v]:Destroy()
                items[v] = nil
                count = count - 1
            end
            if self.value == v then self:SetValue("") end
            refresh()
        end

        row.Activated:Connect(function()
            opt.open = not opt.open
            refresh()
        end)

        local found = false
        for _, v in ipairs(opt.values) do
            if tostring(v) == opt.value then found = true end
        end
        if opt.value ~= "" and not found then opt:AddValue(opt.value) end
        for _, v in ipairs(opt.values) do opt:AddValue(v) end
        library.flags[opt.flag] = opt.value
        return opt
    end

    function holder:AddBox(opt)
        opt = prep(opt, "Box")
        opt.value = opt.value and tostring(opt.value) or ""
        local main = new("Frame", {
            LayoutOrder = nextOrder(),
            Size = UDim2.new(1, 0, 0, 50),
            BackgroundTransparency = 1,
            Parent = self.content,
        })
        local bg = new("Frame", {
            Position = UDim2.new(0, 4, 0, 2),
            Size = UDim2.new(1, -8, 0, 46),
            BackgroundColor3 = theme.item,
            Parent = main,
        })
        corner(bg, 6)
        new("TextLabel", {
            Position = UDim2.new(0, 10, 0, 4),
            Size = UDim2.new(1, -20, 0, 14),
            BackgroundTransparency = 1,
            Text = opt.text,
            Font = FONT,
            TextSize = 11,
            TextColor3 = theme.sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = bg,
        })
        local input = new("TextBox", {
            Position = UDim2.new(0, 10, 0, 18),
            Size = UDim2.new(1, -20, 0, 22),
            BackgroundTransparency = 1,
            Text = opt.value,
            PlaceholderText = opt.placeholder or "",
            PlaceholderColor3 = theme.off,
            Font = FONT_BOLD,
            TextSize = 14,
            TextColor3 = theme.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            Parent = bg,
        })
        function opt:SetValue(v)
            self.value = tostring(v)
            input.Text = self.value
            library.flags[self.flag] = self.value
        end
        input.FocusLost:Connect(function(enter)
            opt.value = input.Text
            library.flags[opt.flag] = opt.value
            opt.callback(opt.value, enter)
        end)
        library.flags[opt.flag] = opt.value
        return opt
    end

    function holder:AddFolder(title)
        return library:_container(self.content, title, true, nextOrder())
    end

    return holder
end

-- Container (window / folder)
function library:_container(parent, title, isFolder, order, index)
    local c = {open = true, count = 0}
    local headerH = isFolder and 30 or 36

    local frame = new("Frame", {
        LayoutOrder = order or 0,
        Position = isFolder and UDim2.new() or UDim2.new(0, 16 + 246 * (index or 0), 0, 16),
        Size = isFolder and UDim2.new(1, 0, 0, headerH) or UDim2.new(0, 230, 0, headerH),
        BackgroundColor3 = isFolder and theme.folder or theme.bg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = parent,
    })
    corner(frame, 8)

    local headerColor = isFolder and theme.item or theme.header
    local header = new("Frame", {
        Size = UDim2.new(1, 0, 0, headerH),
        BackgroundColor3 = headerColor,
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(header, 8)
    new("Frame", {
        Position = UDim2.new(0, 0, 1, -8),
        Size = UDim2.new(1, 0, 0, 8),
        BackgroundColor3 = headerColor,
        BorderSizePixel = 0,
        Parent = header,
    })

    local titleLabel = new("TextLabel", {
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -50, 1, 0),
        BackgroundTransparency = 1,
        Text = title,
        Font = FONT_BOLD,
        TextSize = isFolder and 13 or 15,
        TextColor3 = theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })

    local toggle = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -6, 0.5, 0),
        Size = UDim2.new(0, 30, 0, 24),
        BackgroundTransparency = 1,
        Text = "-",
        Font = FONT_BOLD,
        TextSize = 18,
        TextColor3 = theme.sub,
        Parent = header,
    })

    local content = new("Frame", {
        Position = UDim2.new(0, 0, 0, headerH),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = frame,
    })
    local layout = new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = content,
    })
    new("UIPadding", {
        PaddingTop = UDim.new(0, 3),
        PaddingLeft = UDim.new(0, 4),
        PaddingRight = UDim.new(0, 4),
        Parent = content,
    })

    local function resize()
        local h = headerH
        local inner = layout.AbsoluteContentSize.Y
        if c.open and inner > 0 then h = headerH + inner + 10 end
        tween(frame, {Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, h)})
    end
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)

    toggle.Activated:Connect(function()
        c.open = not c.open
        toggle.Text = c.open and "-" or "+"
        resize()
    end)

    -- Drag (hanya window)
    if not isFolder then
        local dragging, dragStart, startPos
        header.InputBegan:Connect(function(input)
            if isPress(input) then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position
            end
        end)
        UIS.InputChanged:Connect(function(input)
            if dragging and isMove(input) then
                local d = input.Position - dragStart
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        UIS.InputEnded:Connect(function(input)
            if isPress(input) then dragging = false end
        end)
    end

    c.frame = frame
    c.content = content
    function c:SetTitle(t) titleLabel.Text = tostring(t) end

    return addMethods(c)
end

function library:CreateWindow(title)
    local win = self:_container(root, title, false, 0, #self.windows)
    table.insert(self.windows, win)
    return win
end

function library:Close()
    self.open = not self.open
    root.Visible = self.open
end

function library:Init()
    if self.initialized then return end
    self.initialized = true

    -- Tombol buka/tutup (mobile friendly)
    local btn = new("TextButton", {
        Position = UDim2.new(0, 10, 0.5, -19),
        Size = UDim2.new(0, 38, 0, 38),
        BackgroundColor3 = theme.header,
        Text = "=",
        Font = FONT_BOLD,
        TextSize = 20,
        TextColor3 = theme.on,
        AutoButtonColor = false,
        Parent = base,
    })
    corner(btn, 19)
    btn.Activated:Connect(function() library:Close() end)

    UIS.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.RightShift then
            library:Close()
        end
    end)
end

function library:Unload()
    base:Destroy()
end

return library
