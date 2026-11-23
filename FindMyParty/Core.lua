-- Find My Party: shared setup, saved settings, group helpers and slash commands.
local ADDON_NAME, ns = ...

ns.TITLE = "Find My Party"
ns.ARROW_TEXTURE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Arrow"
ns.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

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
        targets = {},    -- ["Name-Realm"] = true for each person to point at
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
-- Friendly name plates. The game only lets addons draw over people's heads
-- by using their name plate, so friendly name plates have to be turned on.
---------------------------------------------------------------------------
local GetCVarValue = (C_CVar and C_CVar.GetCVar) or GetCVar
local SetCVarValue = (C_CVar and C_CVar.SetCVar) or SetCVar
local FRIENDLY_PLATES_CVAR = "nameplateShowFriends"

function ns.FriendlyPlatesSupported()
    return GetCVarValue(FRIENDLY_PLATES_CVAR) ~= nil
end

function ns.FriendlyPlatesOn()
    return GetCVarValue(FRIENDLY_PLATES_CVAR) == "1"
end

function ns.SetFriendlyPlates(on)
    if InCombatLockdown() then
        ns.Print("Name plate settings can't be changed during combat. Try again after the fight.")
        return false
    end
    SetCVarValue(FRIENDLY_PLATES_CVAR, on and "1" or "0")
    return true
end

---------------------------------------------------------------------------
-- Group helpers
---------------------------------------------------------------------------
local function PlayerRealm()
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if not realm or realm == "" then
        realm = (GetRealmName() or ""):gsub("[%s%-]", "")
    end
    return realm
end

-- "Name-Realm" key used to remember who to point at, plus the short name.
function ns.GetFullName(unit)
    local name, realm = UnitName(unit)
    if not name or name == "" or name == UNKNOWNOBJECT then return nil end
    if realm and realm ~= "" then
        realm = realm:gsub("[%s%-]", "")
    else
        realm = PlayerRealm()
    end
    return name .. "-" .. realm, name
end

-- Everyone in the group except yourself, in group order.
function ns.GetGroupMembers()
    local members = {}
    local prefix, count
    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    else
        prefix, count = "party", GetNumSubgroupMembers()
    end
    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local full, name = ns.GetFullName(unit)
            if full then
                local _, class = UnitClass(unit)
                members[#members + 1] = { unit = unit, full = full, name = name, class = class }
            end
        end
    end
    return members
end

-- Called whenever any setting changes.
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
        if arg1 and (arg1:find("^party") or arg1:find("^raid")) then
            ns.QueueGroupUpdate()
        end
    else
        ns.QueueGroupUpdate()
    end
end)

---------------------------------------------------------------------------
-- Slash commands and the AddOns menu button (minimap compartment in retail)
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
