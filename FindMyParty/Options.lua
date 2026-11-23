-- The settings window (/fmp): name color and size on the left, arrows on the right.
local _, ns = ...

local Options = {}
ns.Options = Options

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local ROW_HEIGHT = 24
local LEFT, RIGHT = 24, 350          -- x position of the two columns
local COLUMN_WIDTH = 290

local PRESETS = {
    { 1.00, 0.25, 0.85 }, -- pink
    { 1.00, 0.50, 0.00 }, -- orange
    { 1.00, 0.95, 0.10 }, -- yellow
    { 1.00, 0.15, 0.15 }, -- red
    { 0.70, 0.35, 1.00 }, -- purple
    { 0.10, 1.00, 1.00 }, -- cyan
    { 1.00, 1.00, 1.00 }, -- white
}

local frame
local ui = {}           -- widgets that Refresh() updates
local memberRows = {}

---------------------------------------------------------------------------
-- Small widget builders (no Blizzard templates, so they work in every version)
---------------------------------------------------------------------------
local function PlayClick(on)
    if PlaySound and SOUNDKIT then
        PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end
end

local function Text(parent, template, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", template)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function CheckBox(parent, label, onClick)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(26, 26)
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    cb.label = Text(cb, "GameFontHighlight", "")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    function cb:SetLabel(text)
        self.label:SetText(text)
        -- make the label clickable too
        self:SetHitRectInsets(0, -(self.label:GetStringWidth() + 6), 0, 0)
    end
    cb:SetLabel(label)
    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        PlayClick(checked)
        onClick(checked)
    end)
    return cb
end

local function Slider(parent, label, minValue, maxValue, step, formatValue, onChange)
    local s = CreateFrame("Slider", nil, parent, BACKDROP_TEMPLATE)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(200, 17)
    s:SetHitRectInsets(0, 0, -8, -8)
    if s.SetBackdrop then
        s:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 3, right = 3, top = 6, bottom = 6 },
        })
    end
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:GetThumbTexture():SetSize(32, 32)
    s:SetMinMaxValues(minValue, maxValue)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:EnableMouse(true)

    s.label = Text(s, "GameFontHighlight", label)
    s.label:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 4)
    s.valueText = Text(s, "GameFontHighlight", "")
    s.valueText:SetPoint("LEFT", s, "RIGHT", 10, 0)

    function s:SetDisplayedValue(value)
        self.updating = true
        if math.abs(self:GetValue() - value) >= step / 2 then self:SetValue(value) end
        self.valueText:SetText(formatValue(value))
        self.updating = false
    end

    s:SetScript("OnValueChanged", function(self, value)
        if self.updating then return end
        value = math.floor(value / step + 0.5) * step
        self.valueText:SetText(formatValue(value))
        onChange(value)
    end)
    return s
end

local function Swatch(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local border = b:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 1)
    local frameLine = b:CreateTexture(nil, "BORDER")
    frameLine:SetPoint("TOPLEFT", 1, -1)
    frameLine:SetPoint("BOTTOMRIGHT", -1, 1)
    frameLine:SetColorTexture(0.8, 0.8, 0.8, 1)
    b.color = b:CreateTexture(nil, "ARTWORK")
    b.color:SetPoint("TOPLEFT", 3, -3)
    b.color:SetPoint("BOTTOMRIGHT", -3, 3)
    local highlight = b:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.3)
    return b
end

local function Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

---------------------------------------------------------------------------
-- Color handling
---------------------------------------------------------------------------
local function SetNameColor(r, g, b)
    local c = ns.db.names.color
    c.r, c.g, c.b = r, g, b
    ns.RefreshAll()
end

local function OpenColorPicker()
    local c = ns.db.names.color
    local previous = { r = c.r, g = c.g, b = c.b }
    local function onChange()
        SetNameColor(ColorPickerFrame:GetColorRGB())
    end
    local function onCancel()
        SetNameColor(previous.r, previous.g, previous.b)
    end

    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r, g = c.g, b = c.b,
            hasOpacity = false,
            swatchFunc = onChange,
            cancelFunc = onCancel,
        })
    else
        -- older game versions
        ColorPickerFrame:Hide()
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.previousValues = previous
        ColorPickerFrame.func = onChange
        ColorPickerFrame.cancelFunc = onCancel
        ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
        ColorPickerFrame:Show()
    end
end

---------------------------------------------------------------------------
-- Party member list (who gets an arrow)
---------------------------------------------------------------------------
local function GetRow(i)
    local row = memberRows[i]
    if row then return row end
    row = CheckBox(ui.listChild, "", function(checked)
        if row.full then
            ns.db.arrows.targets[row.full] = checked or nil
            ns.RefreshAll()
        end
    end)
    row:SetPoint("TOPLEFT", ui.listChild, "TOPLEFT", 2, -(i - 1) * ROW_HEIGHT)
    memberRows[i] = row
    return row
end

local function RefreshMembers()
    local targets = ns.db.arrows.targets
    local entries, inGroup = {}, {}

    for _, m in ipairs(ns.GetGroupMembers()) do
        local classColor = m.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
        entries[#entries + 1] = { full = m.full, text = m.name, color = classColor }
        inGroup[m.full] = true
    end

    -- People picked earlier who aren't in the group right now. Their arrow
    -- comes back automatically when they rejoin; untick to forget them.
    local away = {}
    for full in pairs(targets) do
        if not inGroup[full] then away[#away + 1] = full end
    end
    table.sort(away)
    for _, full in ipairs(away) do
        local short = full:match("^(.-)%-") or full
        entries[#entries + 1] = { full = full, text = short .. " |cff909090(not in group)|r" }
    end

    for i, entry in ipairs(entries) do
        local row = GetRow(i)
        row.full = entry.full
        row:SetLabel(entry.text)
        local cc = entry.color
        if cc then
            row.label:SetTextColor(cc.r, cc.g, cc.b)
        else
            row.label:SetTextColor(1, 1, 1)
        end
        row:SetChecked(targets[entry.full] and true or false)
        row:Show()
    end
    for i = #entries + 1, #memberRows do
        memberRows[i].full = nil
        memberRows[i]:Hide()
    end

    local contentHeight = math.max(#entries * ROW_HEIGHT, 1)
    ui.listChild:SetHeight(contentHeight)
    local overflow = contentHeight - ui.listScroll:GetHeight()
    if overflow <= 0 then
        ui.listScroll:SetVerticalScroll(0)
    elseif ui.listScroll:GetVerticalScroll() > overflow then
        ui.listScroll:SetVerticalScroll(overflow)
    end
    ui.moreText:SetShown(overflow > 0)
    ui.emptyText:SetShown(#entries == 0)
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function CreateWindow()
    frame = CreateFrame("Frame", "FindMyPartyOptions", UIParent, BACKDROP_TEMPLATE)
    frame:SetSize(660, 470)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 16, edgeSize = 32,
            insets = { left = 11, right = 11, top = 11, bottom = 11 },
        })
        frame:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
    end
    frame:Hide()
    tinsert(UISpecialFrames, "FindMyPartyOptions") -- Escape closes it

    local title = Text(frame, "GameFontNormalLarge", ns.TITLE)
    title:SetPoint("TOP", frame, "TOP", 0, -20)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.15)
    divider:SetSize(1, 390)
    divider:SetPoint("TOP", frame, "TOPLEFT", 330, -50)

    local function Place(widget, x, y)
        widget:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        return widget
    end

    -------------------------------------------------------------------
    -- Left column: names
    -------------------------------------------------------------------
    Place(Text(frame, "GameFontNormal", "Names over your party's heads"), LEFT, -52)

    ui.namesEnabled = Place(CheckBox(frame, "Color my party's names", function(checked)
        ns.db.names.enabled = checked
        ns.RefreshAll()
    end), LEFT, -72)

    Place(Text(frame, "GameFontHighlight", "Color:"), LEFT + 4, -114)
    ui.swatch = Place(Swatch(frame, 30), LEFT + 56, -106)
    ui.swatch:SetScript("OnClick", OpenColorPicker)
    Place(Button(frame, "Pick any color...", 140, OpenColorPicker), LEFT + 98, -109)

    for i, preset in ipairs(PRESETS) do
        local s = Place(Swatch(frame, 24), LEFT + 4 + (i - 1) * 32, -146)
        s.color:SetColorTexture(preset[1], preset[2], preset[3])
        s:SetScript("OnClick", function()
            PlayClick(true)
            SetNameColor(preset[1], preset[2], preset[3])
        end)
    end

    ui.sizeSlider = Place(Slider(frame, "Name size", 10, 40, 1,
        function(v) return tostring(v) end,
        function(v)
            ns.db.names.size = v
            ns.RefreshAll()
        end), LEFT + 4, -206)

    ui.marker = Place(CheckBox(frame, "Show an arrow above their names", function(checked)
        ns.db.names.marker = checked
        ns.RefreshAll()
    end), LEFT, -236)

    ui.hideOthers = Place(CheckBox(frame, "Hide everyone else's name plates", function(checked)
        ns.db.names.hideOthers = checked
        ns.RefreshAll()
    end), LEFT, -262)

    ui.friendly = Place(CheckBox(frame, "Friendly name plates on (needed)", function(checked)
        ns.SetFriendlyPlates(checked)
        ns.RefreshAll()
    end), LEFT, -288)

    local hint = Place(Text(frame, "GameFontDisableSmall",
        "Shift+V also turns friendly name plates on and off. The game doesn't allow "
        .. "changing them inside dungeons and raids."), LEFT + 4, -318)
    hint:SetWidth(COLUMN_WIDTH - 8)

    -- Preview of what the name will look like
    local preview = Place(CreateFrame("Frame", nil, frame), LEFT, -350)
    preview:SetSize(COLUMN_WIDTH, 96)
    local previewBg = preview:CreateTexture(nil, "BACKGROUND")
    previewBg:SetAllPoints()
    previewBg:SetColorTexture(0.16, 0.22, 0.16, 1)
    local previewCaption = Text(preview, "GameFontDisableSmall", "Preview")
    previewCaption:SetPoint("TOPLEFT", preview, "TOPLEFT", 6, -5)
    ui.previewText = preview:CreateFontString(nil, "OVERLAY")
    ui.previewText:SetPoint("BOTTOM", preview, "BOTTOM", 0, 8)
    ui.previewMarker = preview:CreateTexture(nil, "OVERLAY")
    ui.previewMarker:SetTexture(ns.ARROW_TEXTURE)
    ui.previewMarker:SetRotation(math.pi)
    ui.previewMarker:SetPoint("BOTTOM", ui.previewText, "TOP", 0, 2)

    -------------------------------------------------------------------
    -- Right column: arrows
    -------------------------------------------------------------------
    Place(Text(frame, "GameFontNormal", "Arrows that point to party members"), RIGHT, -52)

    ui.arrowsEnabled = Place(CheckBox(frame, "Show arrows", function(checked)
        ns.db.arrows.enabled = checked
        ns.RefreshAll()
    end), RIGHT, -72)

    Place(Text(frame, "GameFontHighlight", "Point an arrow at:"), RIGHT + 4, -108)

    local listBox = Place(CreateFrame("Frame", nil, frame), RIGHT, -126)
    listBox:SetSize(COLUMN_WIDTH - 10, 200)
    local listBg = listBox:CreateTexture(nil, "BACKGROUND")
    listBg:SetAllPoints()
    listBg:SetColorTexture(0, 0, 0, 0.35)

    ui.listScroll = CreateFrame("ScrollFrame", nil, listBox)
    ui.listScroll:SetPoint("TOPLEFT", listBox, "TOPLEFT", 4, -4)
    ui.listScroll:SetPoint("BOTTOMRIGHT", listBox, "BOTTOMRIGHT", -4, 4)
    ui.listChild = CreateFrame("Frame", nil, ui.listScroll)
    ui.listChild:SetSize(COLUMN_WIDTH - 18, 1)
    ui.listScroll:SetScrollChild(ui.listChild)
    ui.listScroll:EnableMouseWheel(true)
    ui.listScroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, ui.listChild:GetHeight() - self:GetHeight())
        local value = self:GetVerticalScroll() - delta * ROW_HEIGHT * 2
        self:SetVerticalScroll(math.min(maxScroll, math.max(0, value)))
    end)

    ui.emptyText = Text(listBox, "GameFontDisable",
        "You're not in a group right now.\n\nOnce you are, your party members will show up here.")
    ui.emptyText:SetPoint("CENTER", listBox, "CENTER", 0, 0)
    ui.emptyText:SetWidth(COLUMN_WIDTH - 40)
    ui.emptyText:SetJustifyH("CENTER")

    ui.moreText = Text(frame, "GameFontDisableSmall", "Scroll for more")
    ui.moreText:SetPoint("TOPRIGHT", listBox, "BOTTOMRIGHT", 0, -3)

    ui.arrowSlider = Place(Slider(frame, "Arrow size", 0.5, 2.5, 0.1,
        function(v) return math.floor(v * 100 + 0.5) .. "%" end,
        function(v)
            ns.db.arrows.scale = v
            ns.Arrows:ApplyPosition()
        end), RIGHT + 4, -366)

    local dragHint = Place(Text(frame, "GameFontDisableSmall",
        "While this window is open you can drag the arrows to move them."), RIGHT + 4, -394)
    dragHint:SetWidth(COLUMN_WIDTH - 8)

    Place(Button(frame, "Reset arrow position", 170, function()
        ns.Arrows:ResetPosition()
    end), RIGHT, -418)

    -------------------------------------------------------------------
    frame:SetScript("OnShow", function() ns.RefreshAll() end)
    frame:SetScript("OnHide", function() ns.Arrows:Rebuild() end)
    frame:RegisterEvent("CVAR_UPDATE")
    frame:SetScript("OnEvent", function() Options:Refresh() end)
end

function Options:Refresh()
    if not frame or not frame:IsShown() then return end
    local names, arrows = ns.db.names, ns.db.arrows
    local c = names.color

    ui.namesEnabled:SetChecked(names.enabled)
    ui.swatch.color:SetColorTexture(c.r, c.g, c.b)
    ui.sizeSlider:SetDisplayedValue(names.size)
    ui.marker:SetChecked(names.marker)
    ui.hideOthers:SetChecked(names.hideOthers)

    if ns.FriendlyPlatesSupported() then
        ui.friendly:Enable()
        ui.friendly.label:SetTextColor(1, 1, 1)
        ui.friendly:SetChecked(ns.FriendlyPlatesOn())
    else
        ui.friendly:Disable()
        ui.friendly.label:SetTextColor(0.5, 0.5, 0.5)
    end

    ui.previewText:SetFont(ns.FONT, names.size, "THICKOUTLINE")
    ui.previewText:SetTextColor(c.r, c.g, c.b)
    ui.previewText:SetText("Party Member")
    local markerSize = math.floor(names.size * 1.2 + 0.5)
    ui.previewMarker:SetSize(markerSize, markerSize)
    ui.previewMarker:SetVertexColor(c.r, c.g, c.b)
    ui.previewMarker:SetShown(names.marker)

    ui.arrowsEnabled:SetChecked(arrows.enabled)
    ui.arrowSlider:SetDisplayedValue(arrows.scale)
    RefreshMembers()
end

function Options:IsShown()
    return frame ~= nil and frame:IsShown()
end

function Options:Show()
    if not frame then CreateWindow() end
    frame:Show()
end

function Options:Toggle()
    if self:IsShown() then frame:Hide() else self:Show() end
end

-- A page under Options > AddOns with a button that opens the window.
local function RegisterSettingsPage()
    local panel = CreateFrame("Frame")
    panel.name = ns.TITLE

    local title = Text(panel, "GameFontNormalLarge", ns.TITLE)
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    local about = Text(panel, "GameFontHighlight",
        "Colored names over your party's heads, and arrows that point to them.\n"
        .. "Everything is set up in its own window. You can also type /fmp.")
    about:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

    local open = Button(panel, "Open Find My Party", 200, function()
        if not InCombatLockdown() then
            if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
            if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
            if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
        end
        Options:Show()
    end)
    open:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -12)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, panel.name))
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function Options:Init()
    pcall(RegisterSettingsPage)
end
