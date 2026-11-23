-- Colored, resizable names over party members' heads.
--
-- Addons can't recolor the game's own floating names, but they can draw on
-- name plates. For each party member's (friendly) name plate we hide the
-- game's small blue/green plate and put our own big, colored name there
-- instead. Optionally everyone else's friendly plate is hidden too, so in a
-- crowded city only your party stands out.
local _, ns = ...

local Names = {}
ns.Names = Names

local plateUnits = {}  -- [plate] = unit token shown on it
local labels = {}      -- [plate] = our label frame
local hidden = {}      -- [plate] = true while we have hidden the game's plate graphics

local GetNamePlateForUnit = C_NamePlate and C_NamePlate.GetNamePlateForUnit

local function Classify(unit)
    if UnitIsUnit(unit, "player") then return "self" end
    if UnitIsPlayer(unit) and (UnitInParty(unit) or UnitInRaid(unit)) then return "member" end
    if UnitIsFriend("player", unit) then return "other" end
    return "enemy"
end

local function SetGamePlateHidden(plate, hide)
    local unitFrame = plate.UnitFrame
    if not unitFrame then return end
    if hide then
        if unitFrame:GetAlpha() ~= 0 then unitFrame:SetAlpha(0) end
        hidden[plate] = true
    elseif hidden[plate] then
        unitFrame:SetAlpha(1)
        hidden[plate] = nil
    end
end

local function HideLabel(plate)
    local label = labels[plate]
    if label then label:Hide() end
end

local function GetLabel(plate)
    local label = labels[plate]
    if label then return label end

    label = CreateFrame("Frame", nil, plate)
    label:SetSize(1, 1)
    label:SetPoint("BOTTOM", plate, "CENTER", 0, 0)
    -- Keep our size and brightness no matter how far away they are.
    if label.SetIgnoreParentScale then label:SetIgnoreParentScale(true) end
    if label.SetIgnoreParentAlpha then label:SetIgnoreParentAlpha(true) end

    label.text = label:CreateFontString(nil, "OVERLAY")
    label.text:SetPoint("BOTTOM", label, "BOTTOM", 0, 0)

    label.marker = label:CreateTexture(nil, "OVERLAY")
    label.marker:SetTexture(ns.ARROW_TEXTURE)
    label.marker:SetRotation(math.pi) -- point down at the player
    label.marker:SetPoint("BOTTOM", label.text, "TOP", 0, 2)

    labels[plate] = label
    return label
end

local function StyleLabel(label, unit)
    local db = ns.db.names
    local c = db.color
    local name = UnitName(unit)
    label.text:SetFont(ns.FONT, db.size, "THICKOUTLINE")
    label.text:SetTextColor(c.r, c.g, c.b)
    label.text:SetText(name)
    local markerSize = math.floor(db.size * 1.2 + 0.5)
    label.marker:SetSize(markerSize, markerSize)
    label.marker:SetVertexColor(c.r, c.g, c.b)
    label.marker:SetShown(db.marker)
    label:Show()
end

function Names:UpdatePlate(plate, unit)
    if plate.IsForbidden and plate:IsForbidden() then return end
    local db = ns.db.names

    local kind
    if db.enabled then
        local ok, result = pcall(Classify, unit)
        -- The game sometimes hides who a plate belongs to (for example in
        -- combat in newer versions). Leave the plate as it is until it can tell.
        if not ok then return end
        kind = result
    end

    if kind == "member" then
        SetGamePlateHidden(plate, true)
        if not pcall(StyleLabel, GetLabel(plate), unit) then
            HideLabel(plate)
            SetGamePlateHidden(plate, false)
        end
    else
        HideLabel(plate)
        SetGamePlateHidden(plate, kind == "other" and db.hideOthers)
    end
end

function Names:ReleasePlate(plate)
    HideLabel(plate)
    if not (plate.IsForbidden and plate:IsForbidden()) then
        pcall(SetGamePlateHidden, plate, false)
    end
    hidden[plate] = nil
    plateUnits[plate] = nil
end

function Names:RefreshAll()
    for plate, unit in pairs(plateUnits) do
        if GetNamePlateForUnit(unit) == plate then
            self:UpdatePlate(plate, unit)
        else
            self:ReleasePlate(plate)
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
            local plate = GetNamePlateForUnit(unit)
            if plate then
                plateUnits[plate] = unit
                Names:UpdatePlate(plate, unit)
            end
        else
            for plate, plateUnit in pairs(plateUnits) do
                if plateUnit == unit then Names:ReleasePlate(plate) end
            end
        end
    end)

    -- Re-check now and then: people join/leave, names load late, and the
    -- game sometimes resets a plate's look on its own.
    C_Timer.NewTicker(0.5, function() Names:RefreshAll() end)
end
