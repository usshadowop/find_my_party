-- Minimal fake WoW client to exercise the addon's logic outside the game.
-- Run from the repository root:  lua5.1 tests/harness.lua FindMyParty
local ADDON_DIR = arg[1] or "FindMyParty"
local PI = math.pi

---------------------------------------------------------------- widgets
local W = {}
local registry = {}      -- frames registered for events
local allFrames = {}

local function newObj(kind, parent)
    local o = { _kind = kind, _parent = parent, _shown = true, _alpha = 1, _scale = 1,
                _scripts = {}, _events = {}, _w = 0, _h = 0, _text = "", _rot = 0,
                _checked = false, _value = 0, _min = 0, _max = 1, _vscroll = 0, _points = {} }
    return setmetatable(o, { __index = function(t, k)
        if W[k] then return W[k] end
        if type(k) == "string" and k:match("^%u") then
            return function() end -- any other API method is a harmless no-op
        end
    end })
end

function W:SetScript(s, f) self._scripts[s] = f end
function W:GetScript(s) return self._scripts[s] end
function W:Show() local was = self._shown; self._shown = true; if not was and self._scripts.OnShow then self._scripts.OnShow(self) end end
function W:Hide() local was = self._shown; self._shown = false; if was and self._scripts.OnHide then self._scripts.OnHide(self) end end
function W:SetShown(v) if v then self:Show() else self:Hide() end end
function W:IsShown() return self._shown end
function W:IsVisible() local o = self; while o do if not o._shown then return false end o = o._parent end return true end
function W:SetAlpha(a) self._alpha = a end
function W:GetAlpha() return self._alpha end
function W:SetScale(s) self._scale = s end
function W:GetScale() return self._scale end
function W:GetEffectiveScale() return self._scale end
function W:SetSize(w, h) self._w, self._h = w, h end
function W:SetWidth(w) self._w = w end
function W:SetHeight(h) self._h = h end
function W:GetWidth() return self._w end
function W:GetHeight() return self._h end
function W:GetCenter() return 600, 400 end
function W:SetPoint(...) self._points[#self._points + 1] = { ... } end
function W:ClearAllPoints() self._points = {} end
function W:SetText(t) self._text = t == nil and "" or tostring(t) end
function W:GetText() return self._text end
function W:SetFormattedText(fmt, ...) self._text = fmt:format(...) end
function W:GetStringWidth() return #self._text * 7 end
function W:SetTextColor(r, g, b) self._color = { r, g, b } end
function W:SetVertexColor(r, g, b) self._vcolor = { r, g, b } end
function W:SetColorTexture(r, g, b, a) self._ccolor = { r, g, b, a } end
function W:SetFont(f, s, fl) assert(type(f) == "string" and type(s) == "number" and type(fl) == "string", "bad SetFont args"); self._font = { f, s, fl } end
function W:SetRotation(r) self._rot = r end
function W:SetChecked(c) self._checked = c and true or false end
function W:GetChecked() return self._checked end
function W:SetMinMaxValues(a, b) self._min, self._max = a, b end
function W:SetValue(v) v = math.max(self._min, math.min(self._max, v)); local changed = v ~= self._value; self._value = v; if changed and self._scripts.OnValueChanged then self._scripts.OnValueChanged(self, v, true) end end
function W:GetValue() return self._value end
function W:GetThumbTexture() self._thumb = self._thumb or newObj("Texture", self); return self._thumb end
function W:CreateTexture() return newObj("Texture", self) end
function W:CreateFontString() return newObj("FontString", self) end
function W:RegisterEvent(e) self._events[e] = true; registry[self] = true end
function W:UnregisterEvent(e) self._events[e] = nil end
function W:IsForbidden() return false end
function W:SetVerticalScroll(v) self._vscroll = v end
function W:GetVerticalScroll() return self._vscroll end
function W:EnableMouse(e) self._mouse = e end
function W:StartMoving() self._moving = true end
function W:StopMovingOrSizing() self._moving = false end
function W:Click() if self._kind == "CheckButton" then self._checked = not self._checked end; if self._scripts.OnClick then self._scripts.OnClick(self, "LeftButton") end end

function CreateFrame(kind, name, parent, template)
    local f = newObj(kind, parent)
    if name then _G[name] = f end
    if template == "UIPanelButtonTemplate" or template == "UIPanelCloseButton" then f._template = template end
    allFrames[#allFrames + 1] = f
    return f
end

local function FireEvent(event, ...)
    for f in pairs(registry) do
        if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
    end
end

---------------------------------------------------------------- timers
local timers, tickers = {}, {}
C_Timer = {
    After = function(_, fn) timers[#timers + 1] = fn end,
    NewTicker = function(_, fn) tickers[#tickers + 1] = fn; return {} end,
}
local function RunTimers()
    local list = timers; timers = {}
    for _, fn in ipairs(list) do fn() end
end
local function Tick() for _, fn in ipairs(tickers) do fn() end end

---------------------------------------------------------------- game state
local state = {
    cvars = { nameplateShowFriends = "0" },
    combat = false,
    raid = false,
    party = {},          -- array of { name=, realm=, class=, online=, pos={n,w,inst} }
    plates = {},         -- unit token -> { kind = "member"/"stranger"/"enemy", of = "party1" }
    playerPos = { 0, 0, 1 },
    facing = 0,
    inInstance = false,
}

local function partyIndex(unit) return tonumber(unit:match("^party(%d)$")) end
local function resolve(unit)
    if unit == "player" then return "player" end
    local i = partyIndex(unit)
    if i then return state.party[i] and unit or nil end
    local p = state.plates[unit]
    if p then
        if p.secret then error("attempt to compare a secret value") end
        return p.of or unit
    end
end

STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
UNKNOWNOBJECT = "Unknown"
BackdropTemplateMixin = {}
UISpecialFrames = {}
SlashCmdList = {}
RAID_CLASS_COLORS = { PRIEST = { r = 1, g = 1, b = 1 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1, IG_MAINMENU_OPTION_CHECKBOX_OFF = 2 }
function PlaySound() end
function tinsert(t, v) table.insert(t, v) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function BreakUpLargeNumbers(n) local s = tostring(n); return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")) end
local printed = {}
local realPrint = print
function print(msg) printed[#printed + 1] = msg end

UIParent = newObj("Frame")
function UIParent:GetCenter() return 600, 400 end
SettingsPanel = newObj("Frame"); SettingsPanel._shown = false
function HideUIPanel(f) f:Hide() end
local registeredCategory
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name) return { panel = panel, name = name } end,
    RegisterAddOnCategory = function(cat) registeredCategory = cat end,
}
ColorPickerFrame = newObj("Frame")
local pickerInfo
function ColorPickerFrame:SetupColorPickerAndShow(info) pickerInfo = info end
function ColorPickerFrame:GetColorRGB() return 0.2, 0.4, 0.6 end

C_CVar = {
    GetCVar = function(n) return state.cvars[n] end,
    SetCVar = function(n, v) assert(type(v) == "string"); state.cvars[n] = v; FireEvent("CVAR_UPDATE", n, v) end,
}
function InCombatLockdown() return state.combat end
function GetNormalizedRealmName() return "MyRealm" end
function GetRealmName() return "My Realm" end
function IsInRaid() return state.raid end
function GetNumSubgroupMembers() return #state.party end
function GetNumGroupMembers() return #state.party + 1 end
function IsInInstance() return state.inInstance end
function UnitExists(u) return resolve(u) ~= nil end
function UnitIsUnit(a, b) return resolve(a) == resolve(b) end
function UnitName(u)
    local r = resolve(u)
    if r == "player" then return "Me" end
    local i = r and partyIndex(r)
    if i then local p = state.party[i]; return p.name, p.realm end
    local p = state.plates[u]
    if p then return p.name or "Somebody" end
end
function UnitClass(u) local i = partyIndex(resolve(u) or ""); if i then return "x", state.party[i].class end end
function UnitIsConnected(u) local i = partyIndex(resolve(u) or ""); if i then return state.party[i].online ~= false end return true end
function UnitIsPlayer(u) local p = state.plates[u]; if p and p.npc then return false end return true end
function UnitInParty(u) local r = resolve(u); return r ~= nil and partyIndex(r) ~= nil end
function UnitInRaid() return nil end
function UnitIsFriend(_, u) local p = state.plates[u]; return not (p and p.kind == "enemy") end
function UnitPosition(u)
    local r = resolve(u)
    if r == "player" then return state.playerPos[1], state.playerPos[2], 0, state.playerPos[3] end
    local i = r and partyIndex(r)
    if i then
        local pos = state.party[i].pos
        if pos and not state.inInstance then return pos[1], pos[2], 0, pos[3] end
    end
end
function GetPlayerFacing() return state.facing end

local plateFrames = {}
C_NamePlate = {
    GetNamePlateForUnit = function(u)
        if not state.plates[u] then return nil end
        plateFrames[u] = plateFrames[u] or (function()
            local p = newObj("Frame"); p.UnitFrame = newObj("Frame", p); return p
        end)()
        return plateFrames[u]
    end,
}
C_Map = { GetBestMapForUnit = function() return nil end }

---------------------------------------------------------------- helpers
local passed, failed = 0, 0
local function check(cond, label)
    if cond then passed = passed + 1 else failed = failed + 1; realPrint("FAIL: " .. label) end
end
local function near(a, b) return math.abs(a - b) < 1e-6 end

---------------------------------------------------------------- load addon
local ns = {}
for _, file in ipairs({ "Core.lua", "Nameplates.lua", "Arrows.lua", "Options.lua" }) do
    local chunk = assert(loadfile(ADDON_DIR .. "/" .. file))
    chunk("FindMyParty", ns)
end

FireEvent("ADDON_LOADED", "SomethingElse")
check(ns.db == nil, "ignores other addons' ADDON_LOADED")
FireEvent("ADDON_LOADED", "FindMyParty")
check(FindMyPartyDB and FindMyPartyDB.names.size == 20, "defaults applied")
check(registeredCategory and registeredCategory.name == "Find My Party", "settings page registered")

FireEvent("PLAYER_LOGIN")
check(state.cvars.nameplateShowFriends == "1", "first login turns on friendly plates")
check(ns.db.setupDone == true, "setupDone recorded")
RunTimers()

---------------------------------------------------------------- group + nameplates
state.party = {
    { name = "Grandpa", realm = nil, class = "PRIEST", pos = { 0, 100, 1 } },
    { name = "Bob", realm = "Other Realm", class = "WARRIOR", pos = { 50, 0, 1 } },
}
FireEvent("GROUP_ROSTER_UPDATE")
RunTimers()

local members = ns.GetGroupMembers()
check(#members == 2, "two group members")
check(members[1].full == "Grandpa-MyRealm", "same-realm full name: " .. tostring(members[1].full))
check(members[2].full == "Bob-OtherRealm", "cross-realm full name: " .. tostring(members[2].full))

state.plates.nameplate1 = { kind = "member", of = "party1" }
state.plates.nameplate2 = { kind = "stranger", name = "Stranger" }
state.plates.nameplate3 = { kind = "enemy", name = "Orc" }
state.plates.nameplate4 = { kind = "stranger", name = "Hidden", secret = true }
for i = 1, 4 do FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate" .. i) end
local p1, p2, p3, p4 = plateFrames.nameplate1, plateFrames.nameplate2, plateFrames.nameplate3, plateFrames.nameplate4

local function labelOf(plate)
    for _, f in ipairs(allFrames) do if f._parent == plate and f.text then return f end end
end
local l1 = labelOf(p1)
check(p1.UnitFrame:GetAlpha() == 0, "party member's game plate hidden")
check(l1 and l1:IsShown() and l1.text:GetText() == "Grandpa", "party member gets our label")
check(l1 and l1.text._font[2] == 20, "label uses chosen size")
check(l1 and near(l1.text._color[1], 1) and near(l1.text._color[3], 0.85), "label uses chosen color")
check(l1 and near(l1.marker._rot, PI) and l1.marker:IsShown(), "marker points down")
check(p2.UnitFrame:GetAlpha() == 0, "stranger's plate hidden (hideOthers)")
check(labelOf(p2) == nil, "stranger gets no label")
check(p3.UnitFrame:GetAlpha() == 1, "enemy plate untouched")
check(p4.UnitFrame:GetAlpha() == 1, "plate with hidden info left alone (no error)")

ns.db.names.hideOthers = false
ns.RefreshAll()
check(p2.UnitFrame:GetAlpha() == 1, "stranger plate restored when hideOthers off")

ns.db.names.size = 32
ns.db.names.marker = false
Tick()
check(l1.text._font[2] == 32, "ticker restyles size")
check(not l1.marker:IsShown(), "marker can be hidden")

ns.db.names.enabled = false
ns.RefreshAll()
check(p1.UnitFrame:GetAlpha() == 1 and not l1:IsShown(), "disabling restores the game's plate")
ns.db.names.enabled = true
ns.RefreshAll()
check(p1.UnitFrame:GetAlpha() == 0 and l1:IsShown(), "re-enabling works")

FireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate1")
check(p1.UnitFrame:GetAlpha() == 1 and not l1:IsShown(), "removed plate cleaned up")
state.plates.nameplate1 = nil
Tick()

---------------------------------------------------------------- arrows
local container
for _, f in ipairs(allFrames) do if f._scripts.OnUpdate then container = f end end
check(container and not container:IsShown(), "no arrows until someone is picked")

ns.db.arrows.targets["Grandpa-MyRealm"] = true
ns.RefreshAll()
check(container:IsShown(), "arrow container shows for a picked member")

local function widget(i)
    local n = 0
    for _, f in ipairs(allFrames) do
        if f._parent == container and f.arrow and f._shown and f.name:GetText() ~= "Arrows go here" then
            n = n + 1
            if n == i then return f end
        end
    end
end
local function update() container._scripts.OnUpdate(container, 1) end

-- Grandpa at north=0, west=100 -> due west of us.
state.facing = 0                       -- facing north
update()
local w1 = widget(1)
check(w1.name:GetText() == "Grandpa", "arrow labelled with name")
check(near(w1.arrow._rot, PI / 2), "facing north, target west -> arrow points left (+90deg CCW), got " .. w1.arrow._rot)
check(w1.info:GetText() == "100 yds", "distance shown: " .. w1.info:GetText())

state.facing = PI / 2                  -- facing west
update()
check(near(w1.arrow._rot, 0), "facing west, target west -> straight ahead")

state.facing = PI                      -- facing south
update()
check(near(w1.arrow._rot, -PI / 2), "facing south, target west -> arrow points right")

state.party[1].pos = { -30, 0, 1 }     -- due south
state.facing = 0
update()
check(near(math.abs(w1.arrow._rot), PI), "facing north, target south -> behind you")

state.party[1].pos = { 0, -2000, 1 }   -- far east
update()
check(near(w1.arrow._rot, -PI / 2), "target east -> right")
check(w1.info:GetText() == "2,000 yds", "big distances get commas: " .. w1.info:GetText())

state.facing = nil
update()
check(not w1.arrow:IsShown() and w1.info:GetText() == "2,000 yds east", "no facing -> compass text: " .. w1.info:GetText())
state.party[1].pos = { 100, 100, 1 }
update()
check(w1.info:GetText() == "141 yds north-west", "compass north-west: " .. w1.info:GetText())
state.facing = 0

state.party[1].pos = { 1, 1, 1 }
update()
check(w1.info:GetText() == "Right next to you", "close by message")

state.party[1].pos = { 0, 100, 2 }
update()
check(not w1.arrow:IsShown() and w1.info:GetText() == "In a different area", "different continent")

state.inInstance = true
update()
check(w1.info:GetText() == "Arrows don't work in dungeons", "instance message: " .. w1.info:GetText())
state.inInstance = false

state.party[1].online = false
update()
check(w1.info:GetText() == "Offline", "offline message")
state.party[1].online = true
state.party[1].pos = { 0, 100, 1 }
update()
check(w1.arrow:IsShown(), "arrow returns")
check(near(w1.arrow._vcolor[1], 1) and near(w1.arrow._vcolor[3], 0.85), "arrow tinted with name color")

---------------------------------------------------------------- options window
SlashCmdList.FINDMYPARTY("")
local opts = FindMyPartyOptions
check(opts and opts:IsShown(), "/fmp opens the window")
check(UISpecialFrames[1] == "FindMyPartyOptions", "escape closes window")

-- find member rows: CheckButtons whose label has a member name
local function rows()
    local list = {}
    for _, f in ipairs(allFrames) do
        if f._kind == "CheckButton" and f.full and f._shown then list[#list + 1] = f end
    end
    return list
end
local r = rows()
check(#r == 2, "two rows in member list, got " .. #r)
check(r[1].label:GetText() == "Grandpa" and r[1]:GetChecked(), "Grandpa row checked")
check(r[2].label:GetText() == "Bob" and not r[2]:GetChecked(), "Bob row unchecked")
check(near(r[2].label._color[1], 0.78), "class colored name")

r[2]:Click()
check(ns.db.arrows.targets["Bob-OtherRealm"] == true, "ticking Bob saves him")
update()
local w2 = widget(2)
check(w2 and w2.name:GetText() == "Bob", "second arrow for Bob")
check(w1._mouse == true, "arrows draggable while window open")

-- Bob leaves the group: his row stays as "(not in group)"
table.remove(state.party, 2)
FireEvent("GROUP_ROSTER_UPDATE"); RunTimers()
r = rows()
check(#r == 2 and r[2].label:GetText():find("not in group"), "remembered person shown as not in group")
check(widget(2) == nil, "no arrow for someone not in the group")
r[2]:Click()
check(ns.db.arrows.targets["Bob-OtherRealm"] == nil, "unticking forgets them")
check(#rows() == 1, "row removed")

-- sliders, presets, color picker
local sliders = {}
for _, f in ipairs(allFrames) do if f._kind == "Slider" then sliders[#sliders + 1] = f end end
check(#sliders == 2, "two sliders")
sliders[1]:SetValue(27.4)
check(ns.db.names.size == 27, "size slider rounds and saves: " .. ns.db.names.size)
sliders[2]:SetValue(1.53)
check(near(ns.db.arrows.scale, 1.5), "arrow slider saves: " .. ns.db.arrows.scale)
check(container:GetScale() == ns.db.arrows.scale, "arrow scale applied")

local swatches = {}
for _, f in ipairs(allFrames) do if f._kind == "Button" and f.color and f._parent == opts then swatches[#swatches + 1] = f end end
check(#swatches == 8, "1 current + 7 preset swatches, got " .. #swatches)
swatches[3]:Click() -- orange
check(near(ns.db.names.color.g, 0.5), "preset sets color")
swatches[1]:Click() -- current swatch -> picker
check(pickerInfo and pickerInfo.swatchFunc, "color picker opened")
pickerInfo.swatchFunc()
check(near(ns.db.names.color.r, 0.2) and near(ns.db.names.color.b, 0.6), "picker changes color")
pickerInfo.cancelFunc()
check(near(ns.db.names.color.g, 0.5), "cancel restores previous color")

-- friendly plates checkbox mirrors the game setting
state.cvars.nameplateShowFriends = "0"
FireEvent("CVAR_UPDATE", "nameplateShowFriends", "0")
local friendlyBox
for _, f in ipairs(allFrames) do if f._kind == "CheckButton" and f.label and f.label:GetText():find("Friendly name plates") then friendlyBox = f end end
check(friendlyBox and not friendlyBox:GetChecked(), "checkbox follows Shift+V changes")
friendlyBox:Click()
check(state.cvars.nameplateShowFriends == "1" and friendlyBox:GetChecked(), "checkbox turns plates on")
state.combat = true
friendlyBox:Click()
check(state.cvars.nameplateShowFriends == "1" and friendlyBox:GetChecked(), "can't change in combat, box reverts")
state.combat = false

-- dragging the arrows
w1._scripts.OnDragStart(w1)
check(container._moving, "drag starts while window open")
opts:Hide()
check(not container._moving, "closing the window ends a drag")
check(w1._mouse == false, "arrows click-through once window closed")
check(container:IsShown(), "arrows stay up after closing window")

SlashCmdList.FINDMYPARTY("reset")
check(ns.db.arrows.x == 0 and ns.db.arrows.y == 150, "reset position")

-- placeholder when nobody is picked
wipe(ns.db.arrows.targets)
ns.RefreshAll()
check(not container:IsShown(), "hidden when nobody is picked")
SlashCmdList.FINDMYPARTY("")
check(container:IsShown(), "placeholder shown while setting up")
FindMyParty_OnAddonCompartmentClick()
check(not opts:IsShown(), "compartment click toggles window")

-- not in a group at all
state.party = {}
FireEvent("GROUP_ROSTER_UPDATE"); RunTimers()
SlashCmdList.FINDMYPARTY("")
check(#rows() == 0, "empty list when solo")

realPrint(("%d passed, %d failed"):format(passed, failed))
for _, m in ipairs(printed) do realPrint("  chat: " .. m) end
os.exit(failed == 0 and 0 or 1)
