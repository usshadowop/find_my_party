-- On-screen arrows that point toward the party members you picked.
--
-- Uses the same idea as a GPS arrow: where you are, where they are, and which
-- way your character is facing. "Up" on the arrow means "straight ahead".
local _, ns = ...

local Arrows = {}
ns.Arrows = Arrows

local ARROW_SIZE = 72
local WIDGET_WIDTH = 140
local WIDGET_HEIGHT = ARROW_SIZE + 40
local SPACING = 10
local UPDATE_INTERVAL = 0.03

local floor, sqrt, atan2, pi = math.floor, math.sqrt, math.atan2, math.pi
local COMPASS = { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" }

local container, placeholder
local widgets = {}  -- reusable arrow frames
local tracked = {}  -- { unit =, name = } for each arrow currently shown
local moving = false
local elapsedSinceUpdate = 0

---------------------------------------------------------------------------
-- Positions
---------------------------------------------------------------------------

-- World coordinates from the map (fallback for when UnitPosition gives nothing).
local function MapWorldPosition(unit, mapID)
    local pos = C_Map.GetPlayerMapPosition(mapID, unit)
    if not pos then return end
    local x, y = pos:GetXY()
    if not x or (x == 0 and y == 0) then return end
    local continent, world = C_Map.GetWorldPosFromMapPos(mapID, pos)
    if not world then return end
    local north, west = world:GetXY()
    return north, west, continent
end

-- Returns playerNorth, playerWest, targetNorth, targetWest (in yards),
-- or nil plus a reason: "area" = on another continent, "hidden" = the game won't say.
local function GetPositions(unit)
    local pN, pW, _, pInstance = UnitPosition("player")
    local tN, tW, _, tInstance = UnitPosition(unit)
    if pN and tN then
        if pInstance ~= tInstance then return nil, "area" end
        return pN, pW, tN, tW
    end

    if C_Map and C_Map.GetBestMapForUnit then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local mpN, mpW, pContinent = MapWorldPosition("player", mapID)
            local mtN, mtW, tContinent = MapWorldPosition(unit, mapID)
            if mpN and mtN and pContinent == tContinent then
                return mpN, mpW, mtN, mtW
            end
        end
    end
    return nil, "hidden"
end

-- Angle from you to them, counter-clockwise from north (same as GetPlayerFacing).
local function Bearing(pN, pW, tN, tW)
    local dN, dW = tN - pN, tW - pW
    return atan2(dW, dN), sqrt(dN * dN + dW * dW)
end

local function CompassWord(bearing)
    local clockwiseDegrees = (-bearing * 180 / pi) % 360
    return COMPASS[floor((clockwiseDegrees + 22.5) / 45) % 8 + 1]
end

local function FormatYards(yards)
    local n = floor(yards + 0.5)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) .. " yds" end
    return n .. " yds"
end

---------------------------------------------------------------------------
-- Arrow frames
---------------------------------------------------------------------------
local function StartMove()
    if ns.Options:IsShown() then
        moving = true
        container:StartMoving()
    end
end

local function StopMove()
    if not moving then return end
    moving = false
    container:StopMovingOrSizing()
    -- Save the center relative to the middle of the screen, independent of scale.
    local scale = container:GetScale()
    local cx, cy = container:GetCenter()
    local ux, uy = UIParent:GetCenter()
    ns.db.arrows.x = cx * scale - ux
    ns.db.arrows.y = cy * scale - uy
    Arrows:ApplyPosition()
end

local function CreateWidget()
    local w = CreateFrame("Frame", nil, container)
    w:SetSize(WIDGET_WIDTH, WIDGET_HEIGHT)

    w.arrow = w:CreateTexture(nil, "ARTWORK")
    w.arrow:SetTexture(ns.ARROW_TEXTURE)
    w.arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    w.arrow:SetPoint("TOP", w, "TOP", 0, 0)

    w.name = w:CreateFontString(nil, "OVERLAY")
    w.name:SetFont(ns.FONT, 15, "OUTLINE")
    w.name:SetPoint("TOP", w.arrow, "BOTTOM", 0, -2)

    w.info = w:CreateFontString(nil, "OVERLAY")
    w.info:SetFont(ns.FONT, 13, "OUTLINE")
    w.info:SetTextColor(1, 1, 1)
    w.info:SetPoint("TOP", w.name, "BOTTOM", 0, -2)

    w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", StartMove)
    w:SetScript("OnDragStop", StopMove)
    return w
end

local function ShowMessage(w, text)
    w.arrow:Hide()
    w.info:SetText(text)
end

local function UpdateWidget(w, unit)
    if not UnitExists(unit) then return ShowMessage(w, "Not in your group") end
    if not UnitIsConnected(unit) then return ShowMessage(w, "Offline") end

    local pN, pW, tN, tW = GetPositions(unit)
    if not pN then
        if pW == "area" then return ShowMessage(w, "In a different area") end
        if IsInInstance() then return ShowMessage(w, "Arrows don't work in dungeons") end
        return ShowMessage(w, "Can't tell where they are")
    end

    local bearing, distance = Bearing(pN, pW, tN, tW)
    if distance < 4 then
        w.arrow:SetRotation(0)
        w.arrow:SetAlpha(0.35)
        w.arrow:Show()
        w.info:SetText("Right next to you")
        return
    end

    local facing = GetPlayerFacing()
    if facing then
        w.arrow:SetRotation(bearing - facing)
        w.arrow:SetAlpha(1)
        w.arrow:Show()
        w.info:SetText(FormatYards(distance))
    else
        -- The game won't say which way you're facing here; give a compass direction instead.
        w.arrow:Hide()
        w.info:SetText(FormatYards(distance) .. " " .. CompassWord(bearing))
    end
end

local function OnUpdate(_, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if elapsedSinceUpdate < UPDATE_INTERVAL then return end
    elapsedSinceUpdate = 0
    for i, info in ipairs(tracked) do
        local w = widgets[i]
        if not pcall(UpdateWidget, w, info.unit) then
            ShowMessage(w, "Can't tell where they are right now")
        end
    end
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
function Arrows:ApplyPosition()
    local db = ns.db.arrows
    local scale = db.scale
    container:SetScale(scale)
    container:ClearAllPoints()
    container:SetPoint("CENTER", UIParent, "CENTER", db.x / scale, db.y / scale)
end

function Arrows:ResetPosition()
    ns.db.arrows.x = ns.defaults.arrows.x
    ns.db.arrows.y = ns.defaults.arrows.y
    self:ApplyPosition()
end

-- Rebuild the list of arrows after group or setting changes.
function Arrows:Rebuild()
    local db = ns.db.arrows
    local c = ns.db.names.color
    local editing = ns.Options:IsShown()
    if moving and not editing then StopMove() end

    wipe(tracked)
    if db.enabled then
        for _, member in ipairs(ns.GetGroupMembers()) do
            if db.targets[member.full] then
                tracked[#tracked + 1] = { unit = member.unit, name = member.name }
            end
        end
    end

    local shown = math.max(#tracked, 1)
    container:SetSize(shown * WIDGET_WIDTH + (shown - 1) * SPACING, WIDGET_HEIGHT)

    for i, info in ipairs(tracked) do
        local w = widgets[i] or CreateWidget()
        widgets[i] = w
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", container, "TOPLEFT", (i - 1) * (WIDGET_WIDTH + SPACING), 0)
        w.arrow:SetVertexColor(c.r, c.g, c.b)
        w.name:SetTextColor(c.r, c.g, c.b)
        w.name:SetText(info.name)
        w:EnableMouse(editing)
        w:Show()
    end
    for i = #tracked + 1, #widgets do
        widgets[i]:Hide()
    end

    -- While the settings window is open the arrows can be dragged around;
    -- if nobody is picked yet, show a sample arrow so there's something to drag.
    placeholder.arrow:SetVertexColor(c.r, c.g, c.b)
    placeholder:EnableMouse(editing)
    placeholder:SetShown(editing and #tracked == 0)
    container.editBackground:SetShown(editing)

    elapsedSinceUpdate = UPDATE_INTERVAL
    container:SetShown(#tracked > 0 or (editing and db.enabled))
end

function Arrows:Init()
    container = CreateFrame("Frame", nil, UIParent)
    container:SetFrameStrata("MEDIUM")
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    container:SetScript("OnUpdate", OnUpdate)
    container:Hide()

    container.editBackground = container:CreateTexture(nil, "BACKGROUND")
    container.editBackground:SetAllPoints()
    container.editBackground:SetColorTexture(0.1, 0.5, 1, 0.25)

    placeholder = CreateWidget()
    placeholder:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    placeholder.name:SetText("Arrows go here")
    placeholder.info:SetText("Drag to move")

    self:ApplyPosition()
end
