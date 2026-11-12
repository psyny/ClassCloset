-- CC_Model.lua
-- Your character, wearing a set. Drag to turn, mouse wheel to zoom.
CC_Model = {}

local Model = CC_Model
local Widgets = CC_Widgets

local L = LibStub("AceLocale-3.0"):GetLocale("ClassCloset", false)

local ZOOM_MIN, ZOOM_MAX = 0, 0.9

function Model.Create(parent)
    local panel = Widgets.Panel(parent)

    local model = CreateFrame("DressUpModel", nil, panel)
    model:SetPoint("TOPLEFT", 4, -4)
    model:SetPoint("BOTTOMRIGHT", -4, 24)
    model:EnableMouse(true)
    model:EnableMouseWheel(true)
    panel.model = model
    panel.sources = {}
    panel.zoom = 0
    panel.facing = 0

    local title = Widgets.Label(panel, "GameFontHighlightSmall")
    title:SetPoint("BOTTOMLEFT", 8, 7)
    title:SetPoint("BOTTOMRIGHT", -8, 7)
    title:SetJustifyH("CENTER")
    title:SetWordWrap(false)
    panel.title = title

    local hint = Widgets.Label(panel, "GameFontDisableSmall", L["CC.model.hint"])
    hint:SetPoint("TOP", 0, -8)

    local function Apply()
        model:SetUnit("player")
        model:SetSheathed(true)
        model:Undress()
        for _, sourceID in ipairs(panel.sources) do
            pcall(model.TryOn, model, sourceID)
        end
        model:SetFacing(panel.facing)
        model:SetPosition(panel.zoom * 3, 0, 0)
    end
    panel.Apply = Apply

    -- The model can still be loading right after SetUnit: dress it again next frame.
    local function ApplySoon()
        Apply()
        C_Timer.After(0.05, function()
            if panel:IsVisible() then
                Apply()
            end
        end)
    end

    -- sources: list of source IDs; text: shown under the model.
    function panel:ShowSources(sources, text)
        self.sources = sources or {}
        title:SetText(text or "")
        if self:IsVisible() then
            ApplySoon()
        end
    end

    panel:SetScript("OnShow", ApplySoon)

    -- Turning
    model:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.dragX = GetCursorPosition()
        end
    end)
    model:SetScript("OnMouseUp", function(self)
        self.dragX = nil
    end)
    model:SetScript("OnUpdate", function(self)
        if self.dragX then
            local x = GetCursorPosition()
            panel.facing = panel.facing + (x - self.dragX) * 0.02
            self.dragX = x
            self:SetFacing(panel.facing)
        end
    end)
    model:SetScript("OnMouseWheel", function(self, delta)
        panel.zoom = math.min(ZOOM_MAX, math.max(ZOOM_MIN, panel.zoom + delta * 0.1))
        self:SetPosition(panel.zoom * 3, 0, 0)
    end)

    return panel
end
