-- The minimap button: yellow party silhouettes on the edge of the minimap.
--   Left-click   opens or closes the settings window.
--   Right-click  unlocks or locks the on-screen arrows for moving.
--   Drag         moves the button around the minimap's edge.
--
-- Built like the standard round minimap button other Forever addons use
-- (LibDBIcon's layout on the Mainline client): Blizzard's tracking border
-- around a small icon, kept just outside the minimap's edge.
local _, ns = ...

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local button

local function Place()
    local angle = math.rad(ns.db.minimap.angle or 200)
    local x, y = math.cos(angle), math.sin(angle)
    -- Square-minimap addons say so with GetMinimapShape; then keep to the square's edge.
    if GetMinimapShape and GetMinimapShape() == "SQUARE" then
        local far = math.max(math.abs(x), math.abs(y))
        x, y = x / far, y / far
    end
    local radius = Minimap:GetWidth() / 2 + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x * radius, y * radius)
end

-- While dragging, the button follows the cursor around the minimap's edge.
local function FollowCursor()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale
    ns.db.minimap.angle = math.floor(math.deg(math.atan2(cy - my, cx - mx)) % 360 + 0.5)
    Place()
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(ns.TITLE)
    GameTooltip:AddLine("Left-click: open the settings", 1, 1, 1)
    if ns.db.arrows.unlocked then
        GameTooltip:AddLine("Right-click: lock the arrows in place", 1, 1, 1)
    else
        GameTooltip:AddLine("Right-click: unlock the arrows to move them", 1, 1, 1)
    end
    GameTooltip:AddLine("Drag: move this button", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function OnClick(self, mouseButton)
    if mouseButton == "RightButton" then
        ns.SetArrowsUnlocked(not ns.db.arrows.unlocked)
        if GameTooltip:IsOwned(self) then ShowTooltip(self) end
    else
        ns.Options:Toggle()
    end
end

local function Create()
    local b = CreateFrame("Button", "FindMyPartyMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = b:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(24, 24)
    background:SetPoint("CENTER")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ns.ICON_TEXTURE)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT")

    b:SetScript("OnClick", OnClick)
    b:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", FollowCursor)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    b:SetScript("OnEnter", ShowTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

function MinimapButton:Refresh()
    if not button then return end
    button:SetShown(not ns.db.minimap.hide)
end

function MinimapButton:Init()
    if not Minimap then return end
    button = Create()
    Place()
    self:Refresh()
end
