-- Find My Party (WoW: Forever): shared setup, saved settings, group helpers and slash commands.
local ADDON_NAME, ns = ...

ns.TITLE = "Find My Party"
ns.ARROW_TEXTURE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Arrow"

ns.defaults = {
    names = {
        enabled = true,                          -- color the names over party members' heads
        color = { r = 1, g = 0.25, b = 0.85 },   -- hot pink: nothing else in the game uses it
        size = 20,                               -- font size of the name
        marker = true,                           -- small arrow above the name pointing down at them
        hideOthers = true,                       -- hide everyone else's friendly name plates
    },
    arrows = {
        enabled = true,
        scale = 1,
        x = 0,           -- arrow position, offset from the middle of the screen
        y = 150,
        targets = {},    -- [name] = true for each person to point at
    },
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function ns.Print(msg)
    print("|cffff40d9" .. ns.TITLE .. ":|r " .. msg)
end

---------------------------------------------------------------------------
-- Secret values. Forever runs on the Midnight client, where the game can
-- hand addons "secret" values (shown fine on screen, but Lua can't test or
-- compare them). Anything that might be one is checked before it's used.
---------------------------------------------------------------------------
local issecretvalue = issecretvalue

function ns.Readable(value)
    return not (issecretvalue and issecretvalue(value))
end

-- A font that draws every alphabet (Latin, Cyrillic, Korean, Chinese) with a
-- thick outline, at any size. SetFont with a single font file would drop the
-- non-Latin letters, so set the font object and change only its height.
function ns.SetBigFont(fontString, size)
    fontString:SetFontObject(SystemFont_OutlineThick_Huge2 or GameFontNormalHuge)
    if fontString.SetFontHeight then
        fontString:SetFontHeight(size)
    else
        fontString:SetTextHeight(size)
    end
end

---------------------------------------------------------------------------
-- Friendly name plates. The game only lets addons draw over people's heads
-- by using their name plate, so friendly player name plates must be on.
-- The setting was renamed in the Midnight client; use whichever name exists.
---------------------------------------------------------------------------
local GetCVarValue = (C_CVar and C_CVar.GetCVar) or GetCVar
local SetCVarValue = (C_CVar and C_CVar.SetCVar) or SetCVar
local FRIENDLY_PLATES_CVARS = { "nameplateShowFriendlyPlayers", "nameplateShowFriends" }

local function FriendlyPlatesCVar()
    for _, name in ipairs(FRIENDLY_PLATES_CVARS) do
        if GetCVarValue(name) ~= nil then return name end
    end
end

function ns.FriendlyPlatesSupported()
    return FriendlyPlatesCVar() ~= nil
end

function ns.FriendlyPlatesOn()
    local cvar = FriendlyPlatesCVar()
    return cvar ~= nil and GetCVarValue(cvar) == "1"
end

function ns.SetFriendlyPlates(on)
    local cvar = FriendlyPlatesCVar()
    if not cvar then return false end
    if InCombatLockdown() then
        ns.Print("Name plate settings can't be changed during combat. Try again after the fight.")
        return false
    end
    SetCVarValue(cvar, on and "1" or "0")
    return true
end

---------------------------------------------------------------------------
-- Group helpers
---------------------------------------------------------------------------

-- Everyone in the group except yourself, in group order. People are known by
-- their first name: Forever has no realms, and UnitName's second value is a
-- surname. The second return is false if the game is hiding someone's name
-- right now (it can in combat); callers then keep what they had.
function ns.GetGroupMembers()
    local members, complete = {}, true
    local prefix, count
    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    else
        prefix, count = "party", GetNumSubgroupMembers()
    end
    local myName = UnitName("player")
    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) then
            local name = UnitName(unit)
            if not ns.Readable(name) then
                complete = false
            elseif name and name ~= "" and name ~= UNKNOWNOBJECT and name ~= myName then
                local _, class = UnitClass(unit)
                if not ns.Readable(class) then class = nil end
                members[#members + 1] = { unit = unit, name = name, class = class }
            end
        end
    end
    return members, complete
end

-- Called whenever any setting or the group changes.
function ns.RefreshAll()
    ns.Names:RefreshAll()
    ns.Arrows:Rebuild()
    ns.Options:Refresh()
end

-- Roster events come in bursts; handle them once.
local groupUpdatePending = false
function ns.QueueGroupUpdate()
    if groupUpdatePending then return end
    groupUpdatePending = true
    C_Timer.After(0.2, function()
        groupUpdatePending = false
        ns.RefreshAll()
    end)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        self:UnregisterEvent("ADDON_LOADED")

        FindMyPartyDB = CopyDefaults(ns.defaults, FindMyPartyDB or {})
        ns.db = FindMyPartyDB

        ns.Names:Init()
        ns.Arrows:Init()
        ns.Options:Init()

        self:RegisterEvent("PLAYER_LOGIN")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("UNIT_NAME_UPDATE")
        self:RegisterEvent("UNIT_CONNECTION")
    elseif event == "PLAYER_LOGIN" then
        -- First time only: friendly name plates are needed for the colored names.
        if not ns.db.setupDone then
            if ns.FriendlyPlatesSupported() and not ns.FriendlyPlatesOn() then
                if ns.SetFriendlyPlates(true) then
                    ns.Print("Turned on friendly name plates so your party's names can be colored.")
                    ns.db.setupDone = true
                end
            else
                ns.db.setupDone = true
            end
            ns.Print("Type |cffffd200/fmp|r to pick name colors and arrows.")
        end
        ns.QueueGroupUpdate()
    elseif event == "UNIT_NAME_UPDATE" or event == "UNIT_CONNECTION" then
        if type(arg1) == "string" and (arg1:find("^party") or arg1:find("^raid")) then
            ns.QueueGroupUpdate()
        end
    else
        ns.QueueGroupUpdate()
    end
end)

---------------------------------------------------------------------------
-- Slash commands and the AddOns button under the minimap
---------------------------------------------------------------------------
SLASH_FINDMYPARTY1 = "/fmp"
SLASH_FINDMYPARTY2 = "/findmyparty"
SlashCmdList.FINDMYPARTY = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "reset" then
        ns.Arrows:ResetPosition()
        ns.Print("Arrow moved back to the middle of the screen.")
    else
        ns.Options:Toggle()
    end
end

function FindMyParty_OnAddonCompartmentClick()
    ns.Options:Toggle()
end
