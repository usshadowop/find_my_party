-- Colored, resizable names over party members' heads.
--
-- Addons can't recolor the game's own floating names, but they can draw on
-- name plates. On each party member's friendly name plate we hide only
-- Blizzard's small name text and draw our own big, colored name in the same
-- spot; the health bar and everything else stay as they are. Optionally the
-- plates of everyone else are hidden, so in a crowded city only your party
-- stands out.
--
-- Forever rules followed here (from its UI source and other Forever addons):
--  * Never anchor to the name plate's base frame (it errors with "anchor
--    family connection" and breaks Blizzard's own plates). Everything is
--    parented and anchored to plate.UnitFrame and its parts instead.
--  * Plates are pooled, so everything changed is put back when one goes away.
--  * Friendly plates inside dungeons and raids belong to Blizzard alone;
--    C_NamePlate never hands them to addons, so they're simply never seen.
local _, ns = ...

local Names = {}
ns.Names = Names

local Readable = ns.Readable
local GetNamePlateForUnit = C_NamePlate and C_NamePlate.GetNamePlateForUnit

local records = {}  -- [unit token] = { frame = plate.UnitFrame, ... } while on screen
local labels = {}   -- [plate.UnitFrame] = our label, reused as plates are pooled

local function UnitFrameFor(unit)
    local plate = GetNamePlateForUnit(unit)
    return plate and plate.UnitFrame
end

-- "member", "other" (friendly, not in the group), "enemy", "self",
-- or nil when the game won't say right now.
local function Classify(unit)
    local isMe = UnitIsUnit(unit, "player")      -- may be secret
    if Readable(isMe) and isMe then return "self" end
    if UnitIsPlayer(unit) then
        if UnitInParty(unit) then return "member" end
        local raidIndex = UnitInRaid(unit)        -- may be secret
        if not Readable(raidIndex) then return nil end
        if raidIndex then return "member" end
    end
    if UnitIsFriend("player", unit) then return "other" end
    return "enemy"
end

---------------------------------------------------------------------------
-- Our label
---------------------------------------------------------------------------
local function GetLabel(frame)
    local label = labels[frame]
    if label then return label end

    label = CreateFrame("Frame", nil, frame)
    label:SetAllPoints(frame)
    -- A row as wide as the plate and as tall as the health bar, so the name is
    -- centered on the plate (the bar itself sits a little left of center).
    label.row = CreateFrame("Frame", nil, label)
    label.text = label:CreateFontString(nil, "OVERLAY")
    label.text:SetJustifyH("CENTER")
    label.text:SetWordWrap(false)
    label.marker = label:CreateTexture(nil, "OVERLAY")
    label.marker:SetTexture(ns.ARROW_TEXTURE)
    label.marker:SetRotation(math.pi) -- point down at the player
    label.marker:SetPoint("BOTTOM", label.text, "TOP", 0, 2)

    labels[frame] = label
    return label
end

local function PlaceLabel(label, frame)
    local container = frame.HealthBarsContainer or frame.healthBar
    local row, text = label.row, label.text
    row:ClearAllPoints()
    text:ClearAllPoints()
    if container then
        row:SetPoint("TOP", container, "TOP")
        row:SetPoint("BOTTOM", container, "BOTTOM")
        row:SetPoint("LEFT", label, "LEFT")
        row:SetPoint("RIGHT", label, "RIGHT")
        local onlyName = frame.IsShowOnlyName and frame:IsShowOnlyName()
        if onlyName then
            -- Blizzard's "show only name" mode: the name sits where the bar would be.
            text:SetPoint("CENTER", row, "CENTER", 0, 0)
        else
            text:SetPoint("BOTTOM", row, "TOP", 0, 2)
        end
    else
        text:SetPoint("CENTER", label, "CENTER", 0, 0)
    end
end

-- The name exactly as Blizzard writes it on the plate (with a surname, if the
-- game shows those), or the unit's name until the plate has filled in.
local function NameText(record, unit)
    local blizzardName = record.name
    local text = blizzardName and blizzardName:GetText()
    if not Readable(text) then return text end  -- a secret name still draws fine
    if text and text ~= "" then return text end
    return UnitName(unit)
end

local function StyleLabel(record, unit)
    local db = ns.db.names
    local c = db.color
    local label = GetLabel(record.frame)
    PlaceLabel(label, record.frame)
    ns.SetBigFont(label.text, db.size)
    label.text:SetTextColor(c.r, c.g, c.b)
    label.text:SetText(NameText(record, unit))
    label.marker:SetSize(db.markerSize, db.markerSize)
    label.marker:SetVertexColor(c.r, c.g, c.b)
    label.marker:SetShown(db.marker)
    label:Show()
end

local function HideLabel(record)
    local label = labels[record.frame]
    if label then label:Hide() end
end

---------------------------------------------------------------------------
-- Blizzard's parts: hidden with alpha and put back exactly as they were
---------------------------------------------------------------------------
local function SetNameHidden(record, hide)
    local name = record.name
    if not name then return end
    if hide then
        name:SetAlpha(0)
        record.nameHidden = true
    elseif record.nameHidden then
        name:SetAlpha(1)
        record.nameHidden = nil
    end
end

local function SetPlateHidden(record, hide)
    if hide then
        record.frame:SetAlpha(0)
        record.plateHidden = true
    elseif record.plateHidden then
        record.frame:SetAlpha(1)
        record.plateHidden = nil
    end
end

local function Restore(record)
    HideLabel(record)
    SetNameHidden(record, false)
    SetPlateHidden(record, false)
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
function Names:Update(unit)
    local record = records[unit]
    if not record then return end
    local db = ns.db.names
    if not db.enabled then
        Restore(record)
        return
    end

    local ok, kind = pcall(Classify, unit)
    -- Can't tell who this is right now: leave the plate as it is.
    if not ok or kind == nil then return end

    if kind == "member" then
        SetPlateHidden(record, false)
        if pcall(StyleLabel, record, unit) then
            SetNameHidden(record, true)
        else
            Restore(record)
        end
    else
        HideLabel(record)
        SetNameHidden(record, false)
        SetPlateHidden(record, kind == "other" and db.hideOthers)
    end
end

-- Whether another unit's record is using this plate (plates are pooled).
local function InUseElsewhere(frame, exceptUnit)
    for unit, record in pairs(records) do
        if unit ~= exceptUnit and record.frame == frame then return true end
    end
    return false
end

function Names:Remove(unit)
    local record = records[unit]
    if not record then return end
    records[unit] = nil
    if not InUseElsewhere(record.frame, unit) then Restore(record) end
end

function Names:Add(unit)
    local frame = UnitFrameFor(unit)
    if not frame then return end
    local old = records[unit]
    if not (old and old.frame == frame) then
        if old then self:Remove(unit) end
        records[unit] = { frame = frame, name = frame.name or frame.Name }
    end
    self:Update(unit)
end

function Names:RefreshAll()
    for unit, record in pairs(records) do
        if UnitFrameFor(unit) == record.frame then
            self:Update(unit)
        else
            self:Remove(unit)
        end
    end
end

function Names:Init()
    if not GetNamePlateForUnit then return end

    local f = CreateFrame("Frame")
    f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    f:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            Names:Add(unit)
            -- On Forever a plate can arrive before its unit is filled in; look again shortly.
            C_Timer.After(0.1, function()
                if records[unit] then Names:Update(unit) end
            end)
        else
            Names:Remove(unit)
        end
    end)

    -- Re-check now and then: people join and leave, and names load late.
    C_Timer.NewTicker(0.5, function() Names:RefreshAll() end)
end
