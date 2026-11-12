-- CC_Widgets.lua
-- Small building blocks for the ClassCloset windows.
CC_Widgets = {}

local Widgets = CC_Widgets
local AceGUI = LibStub("AceGUI-3.0")

local PANEL_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- A dark box with a thin border.
function Widgets.Panel(parent)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetBackdrop(PANEL_BACKDROP)
    panel:SetBackdropColor(0, 0, 0, 0.45)
    panel:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    return panel
end

function Widgets.Label(parent, font, text)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    label:SetJustifyH("LEFT")
    if text then
        label:SetText(text)
    end
    return label
end

function Widgets.Button(parent, text, width, height, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 100, height or 22)
    button:SetText(text)
    if onClick then
        button:SetScript("OnClick", onClick)
    end
    return button
end

-- Check box with a label; onChange(checked).
function Widgets.Check(parent, text, onChange, tooltip)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    local label = check.Text or check.text
    if not label then
        label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", check, "RIGHT", 2, 1)
    end
    label:SetFontObject("GameFontHighlightSmall")
    label:SetText(text)
    check.label = label
    check:SetHitRectInsets(0, -(label:GetStringWidth() + 4), 0, 0)
    check:SetScript("OnClick", function(self)
        onChange(self:GetChecked() and true or false)
    end)
    if tooltip then
        check:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(text, 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        check:SetScript("OnLeave", GameTooltip_Hide)
    end
    -- Total width, for placing the next control.
    function check:FullWidth()
        return 24 + label:GetStringWidth() + 8
    end
    return check
end

-- AceGUI dropdown placed on a plain frame. onChange(key).
function Widgets.Dropdown(parent, width, onChange)
    local dropdown = AceGUI:Create("Dropdown")
    dropdown.frame:SetParent(parent)
    dropdown:SetWidth(width)
    dropdown:SetCallback("OnValueChanged", function(_, _, key)
        onChange(key)
    end)
    dropdown.frame:Show()
    return dropdown
end

function Widgets.SearchBox(parent, width, onChange)
    local box = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:HookScript("OnTextChanged", function(self)
        onChange(strtrim(self:GetText() or ""):lower())
    end)
    return box
end

function Widgets.ProgressBar(parent, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetHeight(height or 6)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)
    function bar:SetProgress(have, total)
        local value = total > 0 and have / total or 0
        self:SetValue(value)
        if total > 0 and have == total then
            self:SetStatusBarColor(0.25, 0.85, 0.3)
        else
            self:SetStatusBarColor(0.75, 0.55, 1)
        end
    end
    return bar
end

---------------------------------------------------------
-- Scroll list
-- createRow(content) -> row frame; updateRow(row, item, index).
-- Rows are reused; the list only builds as many rows as it ever needed.

function Widgets.ScrollList(parent, rowHeight, createRow, updateRow)
    local list = {}
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -26, 4)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(10, 10)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, w)
        content:SetWidth(w)
    end)

    local empty = Widgets.Label(parent, "GameFontDisable")
    empty:SetPoint("TOP", 0, -20)
    empty:SetWidth(200)
    empty:SetJustifyH("CENTER")
    empty:Hide()

    local rows = {}
    list.scroll = scroll
    list.content = content
    list.rows = rows

    function list:SetEmptyText(text)
        empty:SetText(text)
    end

    function list:SetItems(items)
        content:SetWidth(scroll:GetWidth() > 0 and scroll:GetWidth() or 200)
        for i, item in ipairs(items) do
            local row = rows[i]
            if not row then
                row = createRow(content)
                rows[i] = row
                row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
                row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
                row:SetHeight(rowHeight)
            end
            row.item = item
            row.index = i
            updateRow(row, item, i)
            row:Show()
        end
        for i = #items + 1, #rows do
            rows[i]:Hide()
            rows[i].item = nil
        end
        content:SetHeight(math.max(1, #items * rowHeight))
        empty:SetShown(#items == 0)
        list.items = items
    end

    function list:Refresh()
        if list.items then
            list:SetItems(list.items)
        end
    end

    return list
end

-- Highlight + selected textures for list rows.
function Widgets.AddRowTextures(row)
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    local selected = row:CreateTexture(nil, "BACKGROUND")
    selected:SetAllPoints()
    selected:SetColorTexture(0.75, 0.55, 1, 0.2)
    selected:Hide()
    row.selectedTexture = selected
end

-- Small icon button (star, gear...). Texture or atlas.
function Widgets.IconButton(parent, size, texture, atlas)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    if atlas then
        icon:SetAtlas(atlas)
    else
        icon:SetTexture(texture)
    end
    button.icon = icon
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.15)
    return button
end

-- Favorite star. Uses the textures the game uses for favorites.
function Widgets.SetStar(button, on)
    button.icon:SetAtlas("PetJournal-FavoritesIcon")
    button.icon:SetDesaturated(not on)
    button.icon:SetAlpha(on and 1 or 0.35)
end
