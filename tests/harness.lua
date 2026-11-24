-- Minimal fake WoW: Forever client to exercise the addon's logic outside the game.
-- Run from the repository root:  lua5.1 tests/harness.lua FindMyParty
--
-- It copies the Forever behaviours the addon depends on (taken from Blizzard's
-- Forever UI source and API docs): the renamed friendly name plate CVar,
-- UnitName's second value being a surname, plates whose base frame must never
-- be anchored to, and "secret" values that Lua can't test.
local ADDON_DIR = arg[1] or "FindMyParty"
local PI = math.pi

---------------------------------------------------------------- secrets
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
function issecretvalue(v) return v == SECRET end

---------------------------------------------------------------- widgets
local W = {}
local registry = {}      -- frames registered for events
local allFrames = {}

local function newObj(kind, parent)
    if parent and parent._isBasePlate and kind ~= "PlateUnitFrame" then
        error("addon frame parented to a name plate's base frame", 2)
    end
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

local function checkAnchor(rel)
    if type(rel) == "table" and rel._isBasePlate then
        error("SetPoint would result in anchor family connection (anchored to a name plate's base frame)", 3)
    end
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
function W:SetPoint(point, rel, ...) checkAnchor(rel); self._points[#self._points + 1] = { point, rel, ... } end
function W:SetAllPoints(rel) checkAnchor(rel); self._points[#self._points + 1] = { "ALL", rel } end
function W:ClearAllPoints() self._points = {} end
function W:SetText(t) self._text = t end
function W:GetText() return self._text end
function W:SetFormattedText(fmt, ...) self._text = fmt:format(...) end
function W:GetStringWidth() return #tostring(self._text) * 7 end
function W:SetTextColor(r, g, b) self._color = { r, g, b } end
function W:SetVertexColor(r, g, b) self._vcolor = { r, g, b } end
function W:SetColorTexture(r, g, b, a) self._ccolor = { r, g, b, a } end
function W:SetFont() error("SetFont with one font file drops non-Latin letters; use SetFontObject", 2) end
function W:SetFontObject(o) assert(o ~= nil, "nil font object"); self._fontObject = o end
function W:SetFontHeight(h) assert(type(h) == "number"); self._fontHeight = h end
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
function W:Raise() self._raised = (self._raised or 0) + 1 end
function W:GetFrameLevel() return self._level or 1 end
function W:SetFrameLevel(l) self._level = l end
function W:Click() if self._kind == "CheckButton" then self._checked = not self._checked end; if self._scripts.OnClick then self._scripts.OnClick(self, "LeftButton") end end

function CreateFrame(kind, name, parent, template)
    local f = newObj(kind, parent)
    if name then _G[name] = f end
    f._template = template
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
    for _ = 1, 3 do
        local list = timers; timers = {}
        for _, fn in ipairs(list) do fn() end
    end
end
local function Tick() for _, fn in ipairs(tickers) do fn() end end

---------------------------------------------------------------- game state
local state = {
    -- Forever only knows the new name of the friendly player plates setting.
    cvars = { nameplateShowFriendlyPlayers = "0" },
    combat = false,
    raid = false,
    party = {},          -- array of { name=, surname=, class=, online=, pos={n,w,inst}, mapPos={x,y} }
    plates = {},         -- unit token -> { kind = "member"/"stranger"/"enemy", of = "party1" }
    playerPos = { 0, 0, 1 },
    facing = 0,
    inInstance = false,
    secretNames = false, -- the game hiding group members' names (combat)
    noUnitPosition = false,
}

local function partyIndex(unit) return tonumber(unit:match("^party(%d)$")) end
local function resolve(unit)
    if unit == "player" then return "player" end
    local i = partyIndex(unit)
    if i then return state.party[i] and unit or nil end
    local p = state.plates[unit]
    if p then return p.of or unit end
end

UNKNOWNOBJECT = "Unknown"
BackdropTemplateMixin = {}
SystemFont_OutlineThick_Huge2 = { _font = "outline thick, every alphabet" }
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
    SetCVar = function(n, v) assert(type(v) == "string"); assert(state.cvars[n] ~= nil, "unknown CVar " .. n); state.cvars[n] = v; FireEvent("CVAR_UPDATE", n, v) end,
}
function InCombatLockdown() return state.combat end
function IsInRaid() return state.raid end
function GetNumSubgroupMembers() return #state.party end
function GetNumGroupMembers() return #state.party + 1 end
function IsInInstance() return state.inInstance end
function UnitExists(u) return resolve(u) ~= nil end
function UnitIsUnit(a, b)
    -- Forever: comparing a name plate unit can be secret
    if state.plates[a] and state.plates[a].secretCompare then return SECRET end
    return resolve(a) == resolve(b)
end
function UnitName(u)
    local r = resolve(u)
    if r == "player" then return "Me", "Myself" end
    local i = r and partyIndex(r)
    if i then
        if state.secretNames then return SECRET, SECRET end
        local p = state.party[i]; return p.name, p.surname
    end
    local p = state.plates[u]
    if p then return p.name or "Somebody", "Surname" end
end
function UnitClass(u) local i = partyIndex(resolve(u) or ""); if i then return "x", state.party[i].class end end
function UnitIsConnected(u) local i = partyIndex(resolve(u) or ""); if i then return state.party[i].online ~= false end return true end
function UnitIsPlayer(u) local p = state.plates[u]; if p and p.npc then return false end return true end
function UnitInParty(u) local r = resolve(u); return r ~= nil and partyIndex(r) ~= nil end
function UnitInRaid(u) local p = state.plates[u]; if p and p.secretRaid then return SECRET end return nil end
function UnitIsFriend(_, u) local p = state.plates[u]; return not (p and p.kind == "enemy") end
function UnitPosition(u)
    if state.noUnitPosition then return nil end
    local r = resolve(u)
    if r == "player" then return state.playerPos[1], state.playerPos[2], 0, state.playerPos[3] end
    local i = r and partyIndex(r)
    if i then
        local pos = state.party[i].pos
        if pos and not state.inInstance then return pos[1], pos[2], 0, pos[3] end
    end
end
function GetPlayerFacing() return state.facing end

-- Map fallback: positions are plain {x, y} tables (no GetXY), like some Forever returns.
C_Map = {
    GetBestMapForUnit = function() return 1429 end,
    GetPlayerMapPosition = function(_, u)
        local r = resolve(u)
        if r == "player" then return { x = 0.5, y = 0.5 } end
        local i = r and partyIndex(r)
        if i and state.party[i].mapPos then return { x = state.party[i].mapPos[1], y = state.party[i].mapPos[2] } end
    end,
    GetWorldPosFromMapPos = function(_, pos)
        -- 1000 x 1000 yard map; north decreases with y, west decreases with x
        return 0, { x = (0.5 - pos.y) * 1000, y = (0.5 - pos.x) * 1000 }
    end,
}

-- Name plates: a base frame (never to be anchored to) holding Blizzard's UnitFrame.
local plateFrames = {}
local function newPlate(unit)
    local base = newObj("Frame"); base._isBasePlate = true
    local uf = newObj("PlateUnitFrame", base)
    uf.name = newObj("FontString", uf)
    uf.HealthBarsContainer = newObj("Frame", uf)
    uf.showOnlyName = false
    function uf:IsShowOnlyName() return self.showOnlyName == true end
    base.UnitFrame = uf
    return base
end
C_NamePlate = {
    GetNamePlateForUnit = function(u)
        if not state.plates[u] then return nil end
        plateFrames[u] = plateFrames[u] or newPlate(u)
        return plateFrames[u]
    end,
}

-- Minimap, tooltip, cursor, and Blizzard's Edit Mode (announced through EventRegistry)
Minimap = newObj("Frame"); Minimap._w = 198; Minimap._level = 2
function Minimap:GetCenter() return 1700, 900 end
local cursor = { 1700, 1100 }
function GetCursorPosition() return cursor[1], cursor[2] end
GameTooltip = newObj("Frame"); GameTooltip._lines = {}
function GameTooltip:SetOwner(o) self._owner = o; self._lines = {} end
function GameTooltip:IsOwned(o) return self._owner == o end
function GameTooltip:AddLine(t) self._lines[#self._lines + 1] = t end
local editModeCallbacks = {}
function hooksecurefunc(t, name, fn)
    local orig = t[name]
    t[name] = function(...) local r = orig(...); fn(...); return r end
end
-- Blizzard's party frames: PartyFrame.MemberFrame1-4, secure unit buttons from a pool
PartyFrame = newObj("Frame")
local function newMemberFrame(i)
    local mf = newObj("Button", PartyFrame)
    mf.layoutIndex, mf.unitToken, mf._level = i, "party" .. i, 5
    PartyFrame["MemberFrame" .. i] = mf
    return mf
end
for i = 1, 4 do newMemberFrame(i) end
function PartyFrame:UpdatePartyFrames() self._updates = (self._updates or 0) + 1 end
EventRegistry = { RegisterCallback = function(_, event, fn, owner) editModeCallbacks[event] = function() fn(owner) end end }

---------------------------------------------------------------- helpers
local passed, failed = 0, 0
local function check(cond, label)
    if cond then passed = passed + 1 else failed = failed + 1; realPrint("FAIL: " .. label) end
end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end
local function isTeal(r, g, b)
    if type(r) == "table" then r, g, b = r[1] or r.r, r[2] or r.g, r[3] or r.b end
    return near(r, 0) and near(g, 0.85) and near(b, 0.8)
end

---------------------------------------------------------------- load addon
local ns = {}
for _, file in ipairs({ "Core.lua", "Nameplates.lua", "Arrows.lua", "Options.lua", "MinimapButton.lua", "PartyFrames.lua" }) do
    local chunk = assert(loadfile(ADDON_DIR .. "/" .. file))
    chunk("FindMyParty", ns)
end

FireEvent("ADDON_LOADED", "SomethingElse")
check(ns.db == nil, "ignores other addons' ADDON_LOADED")
FireEvent("ADDON_LOADED", "FindMyParty")
check(FindMyPartyDB and FindMyPartyDB.names.size == 20, "defaults applied")
check(isTeal(FindMyPartyDB.names.color), "default color is teal")
check(FindMyPartyDB.names.hideOthers == false, "other people's plates are not hidden by default")
check(FindMyPartyDB.names.markerSize == 24 and FindMyPartyDB.arrows.unlocked == false, "head arrow size and lock defaults")
check(FindMyPartyDB.version == 2, "fresh install marked as current settings version")
check(registeredCategory and registeredCategory.name == "Find My Party", "settings page registered")

FireEvent("PLAYER_LOGIN")
check(state.cvars.nameplateShowFriendlyPlayers == "1", "first login turns on friendly player plates (Forever CVar name)")
check(ns.db.setupDone == true, "setupDone recorded")
RunTimers()

---------------------------------------------------------------- group + nameplates
state.party = {
    { name = "Grandpa", surname = "Oakheart", class = "PRIEST", pos = { 0, 100, 1 } },
    { name = "Bob", surname = "Stone", class = "WARRIOR", pos = { 50, 0, 1 } },
}
FireEvent("GROUP_ROSTER_UPDATE")
RunTimers()

local members = ns.GetGroupMembers()
check(#members == 2, "two group members")
check(members[1].name == "Grandpa", "known by first name, not 'Name-Surname': " .. tostring(members[1].name))

state.plates.nameplate1 = { kind = "member", of = "party1" }
state.plates.nameplate2 = { kind = "stranger", name = "Stranger" }
state.plates.nameplate3 = { kind = "enemy", name = "Orc" }
state.plates.nameplate4 = { kind = "stranger", name = "Hidden", secretRaid = true }
state.plates.nameplate5 = { kind = "member", of = "party2", secretCompare = true }
for i = 1, 5 do
    local plate = C_NamePlate.GetNamePlateForUnit("nameplate" .. i)
    plate.UnitFrame.name:SetText(i == 1 and "Grandpa Oakheart" or "")
    FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate" .. i)
end
RunTimers()
local p1, p2, p3, p4, p5 = plateFrames.nameplate1, plateFrames.nameplate2, plateFrames.nameplate3, plateFrames.nameplate4, plateFrames.nameplate5
local uf1 = p1.UnitFrame

local function labelOf(uf)
    for _, f in ipairs(allFrames) do if f._parent == uf and f.text then return f end end
end
local l1 = labelOf(uf1)
check(l1 ~= nil, "party member gets our label, parented to plate.UnitFrame")
check(l1 and l1:IsShown() and l1.text:GetText() == "Grandpa Oakheart", "label copies Blizzard's name text (with surname)")
check(uf1.name:GetAlpha() == 0, "only Blizzard's name text is hidden")
check(uf1:GetAlpha() == 1 and uf1.HealthBarsContainer:GetAlpha() == 1, "party member's health bar and plate stay visible")
check(l1 and l1.text._fontObject == SystemFont_OutlineThick_Huge2 and l1.text._fontHeight == 20, "label uses outlined multi-alphabet font at chosen size")
check(l1 and isTeal(l1.text._color), "label uses chosen color (teal)")
check(l1 and l1.marker._w == 24 and l1.marker._h == 24, "head arrow uses its own size setting")
check(l1 and near(l1.marker._rot, PI) and l1.marker:IsShown(), "marker points down")
check(l1 and l1.text._points[1][1] == "BOTTOM" and l1.text._points[1][3] == "TOP", "name drawn just above the health bar")
check(p2.UnitFrame:GetAlpha() == 1, "stranger's plate left alone by default")
check(labelOf(p2.UnitFrame) == nil, "stranger gets no label")
check(p3.UnitFrame:GetAlpha() == 1, "enemy plate untouched")
check(p4.UnitFrame:GetAlpha() == 1, "plate whose group membership is secret is left alone")
check(labelOf(p5.UnitFrame) and labelOf(p5.UnitFrame):IsShown(), "secret UnitIsUnit doesn't stop a member's label")
check(labelOf(p5.UnitFrame).text:GetText() == "Bob", "falls back to UnitName before Blizzard fills the plate in")

-- Blizzard's "show only name" mode: our name sits where the bar would be
uf1.showOnlyName = true
Tick()
check(l1.text._points[1][1] == "CENTER", "name-only mode centers the name")
uf1.showOnlyName = false
Tick()

ns.db.names.hideOthers = true
ns.RefreshAll()
check(p2.UnitFrame:GetAlpha() == 0 and labelOf(p2.UnitFrame) == nil, "stranger plate hidden when hideOthers on")
ns.db.names.hideOthers = false
ns.RefreshAll()
check(p2.UnitFrame:GetAlpha() == 1, "stranger plate restored when hideOthers off")

ns.db.names.size = 32
ns.db.names.markerSize = 40
Tick()
check(l1.text._fontHeight == 32, "ticker restyles size")
check(l1.marker._w == 40, "head arrow resizes on its own")
ns.db.names.marker = false
Tick()
check(not l1.marker:IsShown(), "marker can be hidden")

ns.db.names.enabled = false
ns.RefreshAll()
check(uf1.name:GetAlpha() == 1 and not l1:IsShown(), "disabling puts Blizzard's name back")
ns.db.names.enabled = true
ns.RefreshAll()
check(uf1.name:GetAlpha() == 0 and l1:IsShown(), "re-enabling works")

FireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate1")
check(uf1.name:GetAlpha() == 1 and not l1:IsShown(), "removed plate cleaned up for reuse")
-- the pooled plate is reused for a stranger
state.plates.nameplate1 = nil
state.plates.nameplate6 = { kind = "stranger", name = "Passerby" }
plateFrames.nameplate6 = p1
ns.db.names.hideOthers = true
FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate6")
check(uf1:GetAlpha() == 0 and not l1:IsShown() and uf1.name:GetAlpha() == 1, "reused plate shows no stale label")
FireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate6")
check(uf1:GetAlpha() == 1, "reused plate fully restored")
state.plates.nameplate6 = nil
Tick()

---------------------------------------------------------------- arrows
local container
for _, f in ipairs(allFrames) do if f._scripts.OnUpdate then container = f end end
check(container and not container:IsShown(), "no arrows until someone is picked")

ns.db.arrows.targets["Grandpa"] = true
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
state.facing = 0
update()
local w1 = widget(1)
check(w1.name:GetText() == "Grandpa", "arrow labelled with name")
check(w1.name._fontObject == SystemFont_OutlineThick_Huge2, "arrow name uses multi-alphabet font")
check(near(w1.arrow._rot, PI / 2), "facing north, target west -> arrow points left (+90deg CCW), got " .. tostring(w1.arrow._rot))
check(w1.info:GetText() == "100 yds", "distance shown: " .. tostring(w1.info:GetText()))

state.facing = PI / 2
update()
check(near(w1.arrow._rot, 0), "facing west, target west -> straight ahead")

state.facing = PI
update()
check(near(w1.arrow._rot, -PI / 2), "facing south, target west -> arrow points right")

state.party[1].pos = { -30, 0, 1 }
state.facing = 0
update()
check(near(math.abs(w1.arrow._rot), PI), "facing north, target south -> behind you")

state.party[1].pos = { 0, -2000, 1 }
update()
check(near(w1.arrow._rot, -PI / 2), "target east -> right")
check(w1.info:GetText() == "2,000 yds", "big distances get commas: " .. tostring(w1.info:GetText()))

state.facing = nil
update()
check(not w1.arrow:IsShown() and w1.info:GetText() == "2,000 yds east", "no facing -> compass text: " .. tostring(w1.info:GetText()))
state.facing = SECRET
state.party[1].pos = { 100, 100, 1 }
update()
check(w1.info:GetText() == "141 yds north-west", "secret facing -> compass text: " .. tostring(w1.info:GetText()))
state.facing = 0

state.party[1].pos = { 1, 1, 1 }
update()
check(w1.info:GetText() == "Right next to you", "close by message")

state.party[1].pos = { 0, 100, 2 }
update()
check(not w1.arrow:IsShown() and w1.info:GetText() == "In a different area", "different continent")

-- UnitPosition unavailable: fall back to map positions (plain x/y tables)
state.noUnitPosition = true
state.party[1].mapPos = { 0.4, 0.5 }   -- 100 yards west of the player (map x smaller = west)
update()
check(w1.arrow:IsShown() and near(w1.arrow._rot, PI / 2), "map fallback points west, got " .. tostring(w1.arrow._rot))
check(w1.info:GetText() == "100 yds", "map fallback distance: " .. tostring(w1.info:GetText()))
state.party[1].mapPos = nil
update()
check(w1.info:GetText() == "Can't tell where they are", "no position at all: " .. tostring(w1.info:GetText()))
state.noUnitPosition = false
state.party[1].pos = { 0, 100, 1 }

state.inInstance = true
update()
check(w1.info:GetText() == "Arrows don't work in dungeons", "instance message: " .. tostring(w1.info:GetText()))
state.inInstance = false

state.party[1].online = false
update()
check(w1.info:GetText() == "Offline", "offline message")
state.party[1].online = true
update()
check(w1.arrow:IsShown(), "arrow returns")
check(isTeal(w1.arrow._vcolor), "arrow tinted with name color")

-- names hidden by the game mid-combat: arrows stay as they were
state.secretNames = true
FireEvent("GROUP_ROSTER_UPDATE"); RunTimers()
check(widget(1) and widget(1).name:GetText() == "Grandpa", "secret names in combat keep existing arrows")
state.secretNames = false
FireEvent("PLAYER_REGEN_ENABLED"); RunTimers()
check(widget(1) and widget(1).name:GetText() == "Grandpa", "arrows rebuilt after combat")

---------------------------------------------------------------- options window
SlashCmdList.FINDMYPARTY("")
local opts = FindMyPartyOptions
check(opts and opts:IsShown(), "/fmp opens the window")
check(opts._raised and opts._raised > 0, "window raised above other HIGH windows")
check(UISpecialFrames[1] == "FindMyPartyOptions", "escape closes window")

local function rows()
    local list = {}
    for _, f in ipairs(allFrames) do
        if f._kind == "CheckButton" and f.key and f._shown then list[#list + 1] = f end
    end
    return list
end
local r = rows()
check(#r == 2, "two rows in member list, got " .. #r)
check(r[1].label:GetText() == "Grandpa" and r[1]:GetChecked(), "Grandpa row checked")
check(r[2].label:GetText() == "Bob" and not r[2]:GetChecked(), "Bob row unchecked")
check(near(r[2].label._color[1], 0.78), "class colored name")

-- arrow checkboxes on Blizzard's party frames
local function boxOn(mf)
    for _, f in ipairs(allFrames) do if f._parent == mf and f._kind == "CheckButton" then return f end end
end
local b1, b2, b3 = boxOn(PartyFrame.MemberFrame1), boxOn(PartyFrame.MemberFrame2), boxOn(PartyFrame.MemberFrame3)
check(b1 and b2, "checkboxes made on the party frames")
check(b1 and b1._shown and b1:GetChecked() and b1.name == "Grandpa", "Grandpa's party frame box is ticked")
check(b2 and b2._shown and not b2:GetChecked(), "Bob's party frame box is unticked")
check(b3 and not b3._shown, "no box on an empty party frame")
check(b1._points[1][2] == PartyFrame.MemberFrame1 and b1._points[1][3] == "RIGHT", "box sits just right of its member frame")
check(b1._level > PartyFrame.MemberFrame1._level, "box drawn above the frame")
check(isTeal(b1.icon._vcolor), "box's arrow icon in the name color")
b2:Click()
check(ns.db.arrows.targets.Bob == true and rows()[2]:GetChecked(), "ticking a party frame box picks them, settings list follows")
update()
check(widget(2) and widget(2).name:GetText() == "Bob", "an arrow appears for them")
b2:Click()
check(ns.db.arrows.targets.Bob == nil and not rows()[2]:GetChecked(), "unticking the box stops it")
update()
check(widget(2) == nil, "their arrow goes away")
rows()[1]:Click()
check(not b1:GetChecked(), "party frame box follows the settings list")
rows()[1]:Click()
check(b1:GetChecked(), "and back again")
b1._scripts.OnEnter(b1)
check(tostring(GameTooltip._lines[2]):find("Grandpa"), "box tooltip names the party member")
local pbBox
for _, f in ipairs(allFrames) do if f._kind == "CheckButton" and f.label and tostring(f.label:GetText()):find("checkboxes on the party frames") then pbBox = f end end
check(pbBox and pbBox:GetChecked(), "party frame checkboxes on by default")
pbBox:Click()
check(not ns.db.arrows.partyBoxes and not b1._shown and not b2._shown, "the option hides the boxes")
pbBox:Click()
check(b1._shown and b2._shown, "and shows them again")
ns.db.arrows.enabled = false; ns.RefreshAll()
check(not b1._shown, "no boxes while arrows are turned off")
ns.db.arrows.enabled = true; ns.RefreshAll()
-- Blizzard sets the frames up again with the members swapped round
PartyFrame.MemberFrame1.unitToken, PartyFrame.MemberFrame2.unitToken = "party2", "party1"
PartyFrame:UpdatePartyFrames()
check(b1.name == "Bob" and not b1:GetChecked() and b2.name == "Grandpa" and b2:GetChecked(), "boxes follow Blizzard re-assigning its frames")
PartyFrame.MemberFrame1.unitToken, PartyFrame.MemberFrame2.unitToken = "party1", "party2"
PartyFrame:UpdatePartyFrames()
-- a member frame Blizzard makes during combat gets its box after the fight
local oldFour = PartyFrame.MemberFrame4
state.combat = true
local fresh = newMemberFrame(4)
ns.RefreshAll()
check(boxOn(fresh) == nil, "no new checkboxes made during combat")
state.combat = false
FireEvent("PLAYER_REGEN_ENABLED"); RunTimers()
check(boxOn(fresh) ~= nil, "made once combat ends")
PartyFrame.MemberFrame4 = oldFour

r[2]:Click()
check(ns.db.arrows.targets["Bob"] == true, "ticking Bob saves him")
update()
local w2 = widget(2)
check(w2 and w2.name:GetText() == "Bob", "second arrow for Bob")
check(w1._mouse == false, "arrows stay locked while the window is open")
local unlockBox
for _, f in ipairs(allFrames) do if f._kind == "CheckButton" and f.label and tostring(f.label:GetText()):find("Unlock the arrows") then unlockBox = f end end
unlockBox:Click()
check(ns.db.arrows.unlocked and w1._mouse == true and container.editBackground:IsShown(), "unlock checkbox makes arrows draggable")
unlockBox:Click()
check(not ns.db.arrows.unlocked and w1._mouse == false and not container.editBackground:IsShown(), "unticking locks them again")

table.remove(state.party, 2)
state.plates.nameplate5 = nil
FireEvent("GROUP_ROSTER_UPDATE"); RunTimers()
r = rows()
check(#r == 2 and r[2].label:GetText():find("not in group"), "remembered person shown as not in group")
check(widget(2) == nil, "no arrow for someone not in the group")
r[2]:Click()
check(ns.db.arrows.targets["Bob"] == nil, "unticking forgets them")
check(#rows() == 1, "row removed")

local sliders = {}
for _, f in ipairs(allFrames) do if f._kind == "Slider" then sliders[#sliders + 1] = f end end
check(#sliders == 3, "three sliders")
sliders[1]:SetValue(27.4)
check(ns.db.names.size == 27, "size slider rounds and saves: " .. ns.db.names.size)
sliders[2]:SetValue(51)
check(ns.db.names.markerSize == 52, "head arrow slider saves in steps of 2: " .. ns.db.names.markerSize)
sliders[3]:SetValue(1.53)
check(near(ns.db.arrows.scale, 1.5), "arrow slider saves: " .. ns.db.arrows.scale)
check(container:GetScale() == ns.db.arrows.scale, "arrow scale applied")

local swatches = {}
for _, f in ipairs(allFrames) do if f._kind == "Button" and f.color and f._parent == opts then swatches[#swatches + 1] = f end end
check(#swatches == 8, "1 current + 7 preset swatches, got " .. #swatches)
swatches[2]:Click()
check(isTeal(ns.db.names.color), "first preset is teal")
swatches[4]:Click()
check(near(ns.db.names.color.g, 0.5), "preset sets color (orange)")
swatches[1]:Click()
check(pickerInfo and pickerInfo.swatchFunc and pickerInfo.hasOpacity == false, "color picker opened with Forever's SetupColorPickerAndShow")
pickerInfo.swatchFunc()
check(near(ns.db.names.color.r, 0.2) and near(ns.db.names.color.b, 0.6), "picker changes color")
pickerInfo.cancelFunc()
check(near(ns.db.names.color.g, 0.5), "cancel restores previous color")

state.cvars.nameplateShowFriendlyPlayers = "0"
FireEvent("CVAR_UPDATE", "nameplateShowFriendlyPlayers", "0")
local friendlyBox
for _, f in ipairs(allFrames) do if f._kind == "CheckButton" and f.label and tostring(f.label:GetText()):find("Friendly name plates") then friendlyBox = f end end
check(friendlyBox and not friendlyBox:GetChecked(), "checkbox follows the game setting")
friendlyBox:Click()
check(state.cvars.nameplateShowFriendlyPlayers == "1" and friendlyBox:GetChecked(), "checkbox turns plates on")
state.combat = true
friendlyBox:Click()
check(state.cvars.nameplateShowFriendlyPlayers == "1" and friendlyBox:GetChecked(), "can't change in combat, box reverts")
state.combat = false

w1._scripts.OnDragStart(w1)
check(not container._moving, "locked arrows can't be dragged")
local mmb = FindMyPartyMinimapButton
check(mmb and mmb._shown, "minimap button exists and shows")
mmb._scripts.OnClick(mmb, "RightButton")
check(ns.db.arrows.unlocked and w1._mouse == true, "minimap right-click unlocks the arrows")
check(unlockBox:GetChecked(), "window checkbox follows the minimap button")
w1._scripts.OnDragStart(w1)
check(container._moving, "drag starts while unlocked")
mmb._scripts.OnClick(mmb, "RightButton")
check(not ns.db.arrows.unlocked and not container._moving and w1._mouse == false, "minimap right-click locks and ends a drag")
opts:Hide()
check(container:IsShown(), "arrows stay up after closing window")

-- Blizzard's Edit Mode
editModeCallbacks["EditMode.Enter"]()
check(w1._mouse == true and container.editBackground:IsShown(), "Edit Mode makes the arrows draggable")
w1._scripts.OnDragStart(w1)
check(container._moving, "drag starts in Edit Mode")
editModeCallbacks["EditMode.Exit"]()
check(not container._moving and w1._mouse == false and not ns.db.arrows.unlocked, "leaving Edit Mode locks them again")

SlashCmdList.FINDMYPARTY("reset")
check(ns.db.arrows.x == 0 and ns.db.arrows.y == 150, "reset position")

wipe(ns.db.arrows.targets)
ns.RefreshAll()
check(not container:IsShown(), "hidden when nobody is picked")
SlashCmdList.FINDMYPARTY("unlock")
check(container:IsShown(), "placeholder shown while unlocked so it can be placed")
editModeCallbacks["EditMode.Enter"]()
SlashCmdList.FINDMYPARTY("lock")
check(container:IsShown(), "placeholder still shown in Edit Mode")
editModeCallbacks["EditMode.Exit"]()
check(not container:IsShown(), "placeholder gone once locked and out of Edit Mode")
SlashCmdList.FINDMYPARTY("")
FindMyParty_OnAddonCompartmentClick()
check(not opts:IsShown(), "compartment click toggles window")

-- minimap button: left-click, tooltip, drag around the edge, hide option
mmb:Click()
check(opts:IsShown(), "minimap left-click opens the settings")
mmb:Click()
check(not opts:IsShown(), "minimap left-click closes them again")
mmb._scripts.OnEnter(mmb)
check(GameTooltip._lines[1] == "Find My Party" and tostring(GameTooltip._lines[3]):find("unlock"), "minimap tooltip explains the clicks")
cursor[1], cursor[2] = 1700, 1100   -- straight above the minimap's center
mmb._scripts.OnDragStart(mmb)
mmb._scripts.OnUpdate(mmb)
mmb._scripts.OnDragStop(mmb)
check(ns.db.minimap.angle == 90, "dragging moves the button around the edge: " .. tostring(ns.db.minimap.angle))
local pt = mmb._points[#mmb._points]
check(pt[2] == Minimap and math.abs(pt[4]) < 1e-9 and near(pt[5], 109), "button sits just outside the minimap's edge")
check(mmb._scripts.OnUpdate == nil, "drag stops following the cursor")
SlashCmdList.FINDMYPARTY("")
local mmBox
for _, f in ipairs(allFrames) do if f._kind == "CheckButton" and f.label and tostring(f.label:GetText()):find("minimap button") then mmBox = f end end
check(mmBox and mmBox:GetChecked(), "show minimap button ticked by default")
mmBox:Click()
check(ns.db.minimap.hide and not mmb._shown, "unticking hides the minimap button")
mmBox:Click()
check(not ns.db.minimap.hide and mmb._shown, "ticking shows it again")
opts:Hide()

state.party = {}
FireEvent("GROUP_ROSTER_UPDATE"); RunTimers()
SlashCmdList.FINDMYPARTY("")
check(#rows() == 0, "empty list when solo")

-- the settings page button just opens our window
opts:Hide()
local openButton
for _, f in ipairs(allFrames) do if f._kind == "Button" and f._template == "UIPanelButtonTemplate" and f._parent == registeredCategory.panel then openButton = f end end
check(openButton ~= nil, "settings page has an open button")
openButton:Click()
check(opts:IsShown(), "settings page button opens the window")

---------------------------------------------------------------- settings saved by version 1.1
local function loadWith(saved)
    FindMyPartyDB = saved
    local ns2 = {}
    for _, file in ipairs({ "Core.lua", "Nameplates.lua", "Arrows.lua", "Options.lua", "MinimapButton.lua", "PartyFrames.lua" }) do
        assert(loadfile(ADDON_DIR .. "/" .. file))("FindMyParty", ns2)
    end
    FireEvent("ADDON_LOADED", "FindMyParty")
    return ns2.db
end
local old = loadWith({ names = { color = { r = 1, g = 0.25, b = 0.85 }, hideOthers = true, size = 30 }, arrows = { targets = { Grandpa = true } } })
check(isTeal(old.names.color), "old pink default becomes teal")
check(old.names.hideOthers == false and old.names.size == 30 and old.arrows.targets.Grandpa, "old defaults updated, own choices kept")
check(old.version == 2 and old.names.markerSize == 24, "new settings added to old saved settings")
local custom = loadWith({ names = { color = { r = 1, g = 0.5, b = 0 } } })
check(near(custom.names.color.g, 0.5), "a color picked on purpose is kept")

realPrint(("%d passed, %d failed"):format(passed, failed))
for _, m in ipairs(printed) do realPrint("  chat: " .. m) end
os.exit(failed == 0 and 0 or 1)
