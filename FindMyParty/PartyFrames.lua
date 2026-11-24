-- Checkboxes on Blizzard's party frames (the portrait, health and mana frames
-- that show when you're in a party): tick one to point an arrow at that party
-- member, untick to stop. They stay in step with the list in /fmp.
--
-- On Forever the party frames are PartyFrame.MemberFrame1-4, secure unit
-- buttons taken from a pool when the party frame first shows (so they may not
-- exist yet when this addon loads). Each checkbox is our own frame, parented
-- to a member frame so it shows and hides with it; nothing of Blizzard's is
-- changed. New checkboxes are only made out of combat, to stay clear of the
-- game's combat restrictions on its secure frames.
local _, ns = ...

local PartyBoxes = {}
ns.PartyBoxes = PartyBoxes

local MAX_MEMBERS = 4
local boxes = {}  -- [member frame] = our checkbox
local hooked = false

local function MemberUnit(memberFrame)
    return memberFrame.unitToken or (memberFrame.layoutIndex and ("party" .. memberFrame.layoutIndex))
end

-- The member's first name (how the addon remembers people), or nil when there's
-- nobody there or the game is hiding the name right now.
local function MemberName(unit)
    if not unit or not UnitExists(unit) then return nil end
    local name = UnitName(unit)
    if not ns.Readable(name) or not name or name == "" or name == UNKNOWNOBJECT then return nil end
    return name
end

local function ShowTooltip(box)
    GameTooltip:SetOwner(box, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ns.TITLE)
    if box:GetChecked() then
        GameTooltip:AddLine("An arrow points at " .. box.name .. ". Untick to stop.", 1, 1, 1, true)
    else
        GameTooltip:AddLine("Tick to point an arrow at " .. box.name .. ".", 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function CreateBox(memberFrame)
    local box = CreateFrame("CheckButton", nil, memberFrame)
    box:SetSize(22, 22)
    box:SetFrameLevel(memberFrame:GetFrameLevel() + 10)
    -- Just right of the health bar; party buffs sit inside the frame along its bottom.
    box:SetPoint("LEFT", memberFrame, "RIGHT", 2, 8)
    box:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    box:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    box:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

    -- A small arrow in the name color, so it's clear what the box is for.
    box.icon = box:CreateTexture(nil, "ARTWORK")
    box.icon:SetTexture(ns.ARROW_TEXTURE)
    box.icon:SetSize(16, 16)
    box.icon:SetPoint("LEFT", box, "RIGHT", -2, 0)

    box:SetScript("OnClick", function(self)
        if not self.name then
            self:SetChecked(false)
            return
        end
        local checked = self:GetChecked() and true or false
        if PlaySound and SOUNDKIT then
            PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        end
        ns.db.arrows.targets[self.name] = checked or nil
        ns.RefreshAll()
        if GameTooltip:IsOwned(self) then ShowTooltip(self) end
    end)
    box:SetScript("OnEnter", function(self)
        if self.name then ShowTooltip(self) end
    end)
    box:SetScript("OnLeave", function() GameTooltip:Hide() end)
    box:Hide()
    return box
end

function PartyBoxes:Refresh()
    local party = PartyFrame
    if not party then return end
    if not hooked then self:Hook() end

    local db = ns.db.arrows
    local wanted = db.enabled and db.partyBoxes
    local c = ns.db.names.color
    for i = 1, MAX_MEMBERS do
        local memberFrame = party["MemberFrame" .. i]
        if memberFrame then
            local box = boxes[memberFrame]
            if not box and wanted and not InCombatLockdown() then
                box = CreateBox(memberFrame)
                boxes[memberFrame] = box
            end
            if box then
                local name = wanted and MemberName(MemberUnit(memberFrame))
                box.name = name or nil
                if name then
                    box:SetChecked(db.targets[name] and true or false)
                    box.icon:SetVertexColor(c.r, c.g, c.b)
                    box:Show()
                else
                    box:Hide()
                end
            end
        end
    end
end

-- Blizzard sets the party frames up again whenever they show (and on roster
-- changes); follow along afterwards. A plain post-hook: Blizzard's code runs
-- untouched first.
function PartyBoxes:Hook()
    if hooked or not PartyFrame or not hooksecurefunc then return end
    hooked = true
    if type(PartyFrame.UpdatePartyFrames) == "function" then
        hooksecurefunc(PartyFrame, "UpdatePartyFrames", function()
            pcall(PartyBoxes.Refresh, PartyBoxes)
        end)
    end
end

function PartyBoxes:Init()
    self:Hook()
end
