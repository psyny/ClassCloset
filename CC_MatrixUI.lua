-- CC_MatrixUI.lua
-- Set table: one row per class (and per tier, optionally), one column per slot.
-- Collected pieces are in full color, missing pieces are under a dark veil.
CC_MatrixUI = {}

local Matrix = CC_MatrixUI
local Data = CC_Data
local Options = CC_Options
local Utils = CC_Utils
local Widgets = CC_Widgets

local L = LibStub("AceLocale-3.0"):GetLocale("ClassCloset", false)

local MODEL_WIDTH = 270
local STAR_WIDTH = 20
local LABEL_WIDTH = 170
local COUNT_WIDTH = 50
local GAP = 4

Matrix.key = nil
Matrix.previewRow = nil -- { classFile, baseSetID, setID } of the row on the model

---------------------------------------------------------
-- Rows and columns

local function SelectedTier(group)
    local tier = Options.db.tier_choice[group.key]
    for _, t in ipairs(group.tiers) do
        if t == tier then
            return tier
        end
    end
    return group.tiers[1]
end

local function Columns(group)
    local used = {}
    for _, base in ipairs(group.bases) do
        for _, variant in ipairs(base.variants) do
            for slot in pairs(Data.GetPieces(variant.setID)) do
                used[slot] = true
            end
        end
    end
    local columns = {}
    for _, slot in ipairs(Data.SLOTS) do
        if used[slot.key] then
            columns[#columns + 1] = slot.key
        end
    end
    return columns
end

local function RowProgress(variant, columns)
    local have, total = 0, 0
    if not variant then
        return 0, 0
    end
    local pieces = Data.GetPieces(variant.setID)
    for _, slot in ipairs(columns) do
        local piece = pieces[slot]
        if piece then
            total = total + 1
            if Data.IsPieceCollected(piece) then
                have = have + 1
            end
        end
    end
    return have, total
end

local function BuildRows(group, columns)
    local db = Options.db
    local entries = {}
    for _, base in ipairs(group.bases) do
        for _, id in ipairs(base.classIDs) do
            local class = Utils.ClassByID(id)
            if class and Options.IsClassShown(class.file) then
                entries[#entries + 1] = { class = class, base = base }
            end
        end
    end
    table.sort(entries, function(a, b)
        local fa = Options.IsFavClass(group.key, a.class.file) and 0 or 1
        local fb = Options.IsFavClass(group.key, b.class.file) and 0 or 1
        if fa ~= fb then
            return fa < fb
        end
        if a.class.id ~= b.class.id then
            return a.class.id < b.class.id
        end
        return a.base.setID < b.base.setID
    end)

    -- Same class twice (faction or extra versions): tell them apart by set name.
    local perClass = {}
    for _, e in ipairs(entries) do
        perClass[e.class.id] = (perClass[e.class.id] or 0) + 1
    end

    local rows = {}
    local tiers = db.show_tiers and group.tiers or { SelectedTier(group) }
    for _, e in ipairs(entries) do
        for t, tier in ipairs(tiers) do
            local variant = Data.VariantForTier(e.base, tier)
            if variant or not db.show_tiers then
                local have, total = RowProgress(variant, columns)
                local done = total > 0 and have == total
                if not (db.hide_complete_rows and done) then
                    rows[#rows + 1] = {
                        class = e.class,
                        base = e.base,
                        variant = variant,
                        tier = tier,
                        firstOfClass = (t == 1),
                        extraName = perClass[e.class.id] > 1 and e.base.info.name or nil,
                        have = have,
                        total = total,
                    }
                end
            end
        end
    end
    return rows
end

---------------------------------------------------------
-- Cells

local function QualityColor(quality)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

local function CellTooltip(cell)
    local piece = cell.piece
    if not piece then
        return
    end
    GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
    local sources, more = Data.GetSources(piece)
    local first = sources[1]
    local r, g, b = QualityColor(piece.quality or (first and first.quality))
    GameTooltip:SetText(piece.name or (first and first.name) or "?", r, g, b)

    local slot = L["CC.slot." .. (piece.slot or "")] or ""
    if Data.IsPieceCollected(piece) then
        GameTooltip:AddDoubleLine(slot, L["CC.matrix.collected"], 0.8, 0.8, 0.8, 0.25, 0.85, 0.3)
        local at = CC_History.AcquiredAt(piece.visualID)
        if at then
            GameTooltip:AddLine(format(L["CC.matrix.collected_ago"], CC_History.AgoText(at)), 1, 0.82, 0)
        end
    else
        GameTooltip:AddDoubleLine(slot, L["CC.matrix.missing"], 0.8, 0.8, 0.8, 1, 0.3, 0.3)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["CC.matrix.sources"], 1, 0.82, 0)
    if #sources == 0 then
        GameTooltip:AddLine(L["CC.matrix.no_sources"], 0.6, 0.6, 0.6)
    end
    for _, source in ipairs(sources) do
        local qr, qg, qb = QualityColor(source.quality)
        local mark = source.collected and "|A:common-icon-checkmark:12:12|a " or "|A:common-icon-redx:12:12|a "
        GameTooltip:AddLine(mark .. source.name, qr, qg, qb)
        for _, line in ipairs(source.how) do
            GameTooltip:AddLine("      " .. line, 0.85, 0.85, 0.85, true)
        end
    end
    if more > 0 then
        GameTooltip:AddLine(format(L["CC.matrix.more_sources"], more), 0.6, 0.6, 0.6)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["CC.matrix.cell_hint"], 0.5, 0.5, 0.5, true)
    GameTooltip:Show()
end

local function CreateCell(parent)
    local cell = CreateFrame("Button", nil, parent)
    cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetPoint("TOPLEFT", 1, -1)
    cell.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    cell.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    cell.veil = cell:CreateTexture(nil, "OVERLAY")
    cell.veil:SetAllPoints(cell.icon)
    cell.veil:SetColorTexture(0, 0, 0, 0.9)
    cell.border = cell:CreateTexture(nil, "BACKGROUND")
    cell.border:SetAllPoints()
    cell.border:SetColorTexture(0.3, 0.3, 0.3, 1)
    cell.check = cell:CreateTexture(nil, "OVERLAY", nil, 2)
    cell.check:SetAtlas("common-icon-checkmark")
    cell.check:SetSize(12, 12)
    cell.check:SetPoint("BOTTOMRIGHT", 0, 0)
    local highlight = cell:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(cell.icon)
    highlight:SetColorTexture(1, 1, 1, 0.2)

    -- Glow for pieces collected recently: the classic action button glow border.
    local glow = cell:CreateTexture(nil, "OVERLAY", nil, 4)
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetPoint("CENTER")
    glow:Hide()
    cell.glow = glow
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.3)
    fade:SetDuration(0.7)
    fade:SetSmoothing("IN_OUT")
    cell.pulse = pulse

    cell:SetScript("OnEnter", CellTooltip)
    cell:SetScript("OnLeave", GameTooltip_Hide)
    cell:SetScript("OnClick", function(self, button)
        local piece = self.piece
        if not piece then
            return
        end
        if IsModifiedClick("CHATLINK") and piece.itemID then
            local _, link = Utils.Safe(C_Item.GetItemInfo, piece.itemID)
            if link then
                ChatEdit_InsertLink(link)
            end
            return
        end
        if button == "RightButton" then
            Matrix.PreviewRow(self.row)
        else
            Matrix.TryOnPiece(piece)
        end
    end)
    return cell
end

-- recency: "day" (gold), "week" (silver) or nil.
local function UpdateGlow(cell, recency, size)
    local db = Options.db
    if not recency or not db.glow_enabled then
        cell.glow:Hide()
        cell.pulse:Stop()
        return
    end
    local c = recency == "day" and db.glow_day_color or db.glow_week_color
    cell.glow:SetVertexColor(c.r, c.g, c.b)
    cell.glow:SetSize(size * 1.75, size * 1.75)
    cell.border:SetColorTexture(c.r, c.g, c.b, 1)
    cell.glow:Show()
    if db.glow_animated then
        if not cell.pulse:IsPlaying() then
            cell.pulse:Play()
        end
    else
        cell.pulse:Stop()
        cell.glow:SetAlpha(1)
    end
end

local function UpdateCell(cell, piece, size)
    cell:SetSize(size, size)
    cell.piece = piece
    if not piece then
        UpdateGlow(cell, nil, size)
        cell.icon:SetTexture(nil)
        cell.icon:SetColorTexture(0.08, 0.08, 0.08, 0.6)
        cell.veil:Hide()
        cell.check:Hide()
        cell.border:SetColorTexture(0.15, 0.15, 0.15, 1)
        cell:EnableMouse(false)
        return
    end
    cell:EnableMouse(true)
    cell.icon:SetTexture(piece.icon or 134400) -- question mark
    local collected = Data.IsPieceCollected(piece)
    cell.veil:SetColorTexture(0, 0, 0, Options.db.veil_alpha)
    cell.veil:SetShown(not collected)
    cell.check:SetShown(collected)
    if collected then
        cell.border:SetColorTexture(0.25, 0.75, 0.3, 1)
    else
        cell.border:SetColorTexture(0.3, 0.3, 0.3, 1)
    end
    UpdateGlow(cell, collected and CC_History.Recency(piece.visualID), size)
end

---------------------------------------------------------
-- Row frames

local function CreateRowFrame(content)
    local row = CreateFrame("Button", nil, content)
    row:RegisterForClicks("LeftButtonUp")
    Widgets.AddRowTextures(row)

    row.star = Widgets.IconButton(row, 16, nil, "PetJournal-FavoritesIcon")
    row.star:SetPoint("LEFT", 2, 0)
    row.star:SetScript("OnClick", function(self)
        Options.ToggleFavClass(Matrix.key, self:GetParent().data.class.file)
        Matrix.Refresh()
    end)
    row.star:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["CC.matrix.fav_class"], 1, 1, 1)
        GameTooltip:AddLine(L["CC.matrix.fav_class.desc"], nil, nil, nil, true)
        GameTooltip:Show()
    end)
    row.star:SetScript("OnLeave", GameTooltip_Hide)

    row.label = Widgets.Label(row, "GameFontHighlight")
    row.label:SetPoint("LEFT", STAR_WIDTH + 2, 0)
    row.label:SetWidth(LABEL_WIDTH - 4)
    row.label:SetWordWrap(false)

    row.count = Widgets.Label(row, "GameFontHighlightSmall")
    row.count:SetJustifyH("RIGHT")
    row.count:SetWidth(COUNT_WIDTH)

    row.cells = {}
    row:SetScript("OnClick", function(self)
        Matrix.PreviewRow(self.data)
    end)
    row:SetScript("OnEnter", function(self)
        local d = self.data
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(d.variant and d.variant.name or d.base.info.name, Utils.ClassColor(d.class.file))
        if d.variant and d.variant.description and d.variant.description ~= "" then
            GameTooltip:AddLine(d.variant.description, 0.8, 0.8, 0.8)
        end
        if not d.variant then
            GameTooltip:AddLine(L["CC.matrix.no_tier"], 0.6, 0.6, 0.6)
        end
        GameTooltip:AddLine(L["CC.matrix.row_hint"], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function UpdateRowFrame(row, data, columns, size)
    row.data = data
    local db = Options.db
    local isFav = Options.IsFavClass(Matrix.key, data.class.file)
    Widgets.SetStar(row.star, isFav)
    row.star:SetShown(data.firstOfClass)

    local text
    if data.firstOfClass or not db.show_tiers then
        text = Utils.ClassIconMarkup(data.class.file, 16) .. " " .. Utils.ClassColorCode(data.class.file) .. data.class.name .. "|r"
        if data.extraName then
            text = text .. " |cff999999" .. data.extraName .. "|r"
        end
    else
        text = "    "
    end
    if db.show_tiers then
        text = text .. "  |cffbbbbbb" .. Data.TierLabel(data.tier) .. "|r"
    end
    row.label:SetText(text)

    local pieces = data.variant and Data.GetPieces(data.variant.setID) or {}
    local x = STAR_WIDTH + LABEL_WIDTH
    for i, slot in ipairs(columns) do
        local cell = row.cells[i]
        if not cell then
            cell = CreateCell(row)
            row.cells[i] = cell
        end
        cell.row = data
        cell:ClearAllPoints()
        cell:SetPoint("LEFT", x, 0)
        UpdateCell(cell, pieces[slot], size)
        cell:Show()
        x = x + size + GAP
    end
    for i = #columns + 1, #row.cells do
        row.cells[i]:Hide()
    end
    row.count:ClearAllPoints()
    row.count:SetPoint("LEFT", x, 0)
    if data.total > 0 and data.have == data.total then
        row.count:SetText("|cff40d040" .. data.have .. "/" .. data.total .. "|r")
    else
        row.count:SetText(data.have .. "/" .. data.total)
    end
    local preview = Matrix.previewRow
    row.selectedTexture:SetShown(preview ~= nil and data.variant ~= nil
        and preview.setID == data.variant.setID and preview.classFile == data.class.file)
end

---------------------------------------------------------
-- Preview

function Matrix.PreviewRow(data)
    if not data or not data.variant then
        return
    end
    Matrix.previewRow = { classFile = data.class.file, baseSetID = data.base.setID, setID = data.variant.setID }
    local sources = {}
    for _, piece in pairs(Data.GetPieces(data.variant.setID)) do
        sources[#sources + 1] = piece.sourceID
    end
    local text = data.variant.name
    if data.variant.description and data.variant.description ~= "" then
        text = text .. " (" .. data.variant.description .. ")"
    end
    Matrix.page.model:ShowSources(sources, text)
    Matrix.RefreshRows()
end

function Matrix.TryOnPiece(piece)
    local model = Matrix.page.model
    if not model:IsShown() then
        return
    end
    local sources = model.sources
    sources[#sources + 1] = piece.sourceID
    model:ShowSources(sources, model.title:GetText())
end

-- Default preview: the player's class, else the first row.
local function DefaultPreview(rows)
    local playerClass = Utils.PlayerClassFile()
    for _, data in ipairs(rows) do
        if data.class.file == playerClass and data.variant then
            return data
        end
    end
    for _, data in ipairs(rows) do
        if data.variant then
            return data
        end
    end
end

---------------------------------------------------------
-- Page

function Matrix.Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    Matrix.page = page

    page.title = Widgets.Label(page, "GameFontNormalLarge")
    page.title:SetPoint("TOPLEFT", 4, 0)
    page.title:SetPoint("RIGHT", page, "RIGHT", -430, 0)
    page.title:SetWordWrap(false)

    page.sub = Widgets.Label(page, "GameFontDisableSmall")
    page.sub:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -3)

    page.bar = Widgets.ProgressBar(page, 6)
    page.bar:SetPoint("TOPLEFT", page.sub, "BOTTOMLEFT", 0, -4)
    page.bar:SetWidth(250)

    -- List membership
    page.tracked = Widgets.Check(page, L["CC.matrix.tracked"], function(on)
        Options.db.tracked[Matrix.key] = on or nil
        ClassCloset:OnListsChanged()
    end)
    page.tracked:SetPoint("TOPLEFT", page, "TOPRIGHT", -420, 2)
    page.favorite = Widgets.Check(page, L["CC.matrix.favorite"], function(on)
        Options.db.favorites[Matrix.key] = on or nil
        ClassCloset:OnListsChanged()
    end)
    page.favorite:SetPoint("TOPLEFT", page.tracked, "BOTTOMLEFT", 0, 2)

    -- Tier
    page.tierLabel = Widgets.Label(page, "GameFontHighlightSmall", L["CC.matrix.tier"])
    page.tier = Widgets.Dropdown(page, 150, function(tier)
        Options.db.tier_choice[Matrix.key] = tier
        Matrix.retier = true -- keep the class on the model, show its new tier
        Matrix.Refresh()
    end)
    page.tier.frame:SetPoint("TOPRIGHT", page, "TOPRIGHT", -130, 6)
    page.tierLabel:SetPoint("RIGHT", page.tier.frame, "LEFT", -4, -8)

    -- Display options
    page.showTiers = Widgets.Check(page, L["CC.matrix.show_tiers"], function(on)
        Options.db.show_tiers = on
        Matrix.Refresh()
    end, L["CC.options.show_tiers.desc"])
    page.showTiers:SetPoint("TOPLEFT", page, "TOPRIGHT", -120, 2)
    page.showModel = Widgets.Check(page, L["CC.matrix.show_model"], function(on)
        Options.db.matrix_model = on
        Matrix.Refresh()
    end)
    page.showModel:SetPoint("TOPLEFT", page.showTiers, "BOTTOMLEFT", 0, 2)
    page.hideComplete = Widgets.Check(page, L["CC.matrix.hide_complete"], function(on)
        Options.db.hide_complete_rows = on
        Matrix.Refresh()
    end)
    page.hideComplete:SetPoint("TOPLEFT", page, "TOPRIGHT", -280, -26)

    -- Table
    page.tablePanel = Widgets.Panel(page)
    page.tablePanel:SetPoint("TOPLEFT", 0, -72)
    page.tablePanel:SetPoint("BOTTOM", 0, 0)

    page.header = CreateFrame("Frame", nil, page.tablePanel)
    page.header:SetPoint("TOPLEFT", 4, -4)
    page.header:SetPoint("RIGHT", -26, 0)
    page.header:SetHeight(24)
    page.header.icons = {}

    local scroll = CreateFrame("ScrollFrame", nil, page.tablePanel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -30)
    scroll:SetPoint("BOTTOMRIGHT", -26, 4)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(10, 10)
    scroll:SetScrollChild(content)
    page.scroll = scroll
    page.content = content
    page.rows = {}

    page.empty = Widgets.Label(page.tablePanel, "GameFontDisable", L["CC.matrix.empty"])
    page.empty:SetPoint("TOP", 0, -50)

    page.legend = Widgets.Label(page, "GameFontDisableSmall", L["CC.matrix.legend"])
    page.legend:SetPoint("BOTTOMLEFT", page.tablePanel, "BOTTOMLEFT", 6, -14)

    -- Model
    page.model = CC_Model.Create(page)
    page.model:SetPoint("TOPRIGHT", 0, -72)
    page.model:SetPoint("BOTTOMRIGHT", 0, 0)
    page.model:SetWidth(MODEL_WIDTH)

    return page
end

function Matrix.Show(key)
    if Matrix.key ~= key then
        Matrix.previewRow = nil
    end
    Matrix.key = key
    Matrix.Refresh()
end

local function UpdateHeader(columns, size)
    local header = Matrix.page.header
    local x = STAR_WIDTH + LABEL_WIDTH
    for i, slot in ipairs(columns) do
        local icon = header.icons[i]
        if not icon then
            icon = CreateFrame("Frame", nil, header)
            icon.tex = icon:CreateTexture(nil, "ARTWORK")
            icon.tex:SetAllPoints()
            icon:EnableMouse(true)
            icon:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(L["CC.slot." .. self.slot])
                GameTooltip:Show()
            end)
            icon:SetScript("OnLeave", GameTooltip_Hide)
            header.icons[i] = icon
        end
        icon.slot = slot
        icon:SetSize(math.min(size, 22), math.min(size, 22))
        icon:ClearAllPoints()
        icon:SetPoint("BOTTOM", header, "BOTTOMLEFT", x + size / 2, 0)
        icon.tex:SetTexture(Data.SlotTexture(slot) or 136516)
        icon:Show()
        x = x + size + GAP
    end
    for i = #columns + 1, #header.icons do
        header.icons[i]:Hide()
    end
end

function Matrix.RefreshRows()
    local page = Matrix.page
    if not page.data then
        return
    end
    local rowsData, columns, size = page.data.rows, page.data.columns, page.data.size
    local rowHeight = size + 4
    page.content:SetWidth(STAR_WIDTH + LABEL_WIDTH + #columns * (size + GAP) + COUNT_WIDTH)
    for i, data in ipairs(rowsData) do
        local row = page.rows[i]
        if not row then
            row = CreateRowFrame(page.content)
            page.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
        row:SetPoint("RIGHT", page.content, "RIGHT")
        row:SetHeight(rowHeight)
        UpdateRowFrame(row, data, columns, size)
        row:Show()
    end
    for i = #rowsData + 1, #page.rows do
        page.rows[i]:Hide()
    end
    page.content:SetHeight(math.max(1, #rowsData * rowHeight))
    page.empty:SetShown(#rowsData == 0)
end

function Matrix.Refresh()
    local page = Matrix.page
    local group = Matrix.key and Data.GetGroup(Matrix.key)
    if not group then
        page.data = nil
        page.title:SetText(L["CC.matrix.missing_set"])
        return
    end
    local db = Options.db

    page.title:SetText(group.name)
    local have, total = Data.Progress(group, Options.ClassFilter)
    page.sub:SetText(format("%s · " .. L["CC.row.progress"], Utils.ExpansionName(group.expansionID), have, total))
    page.bar:SetProgress(have, total)

    page.tracked:SetChecked(db.tracked[group.key] == true)
    page.favorite:SetChecked(db.favorites[group.key] == true)

    local values, order = {}, {}
    for _, tier in ipairs(group.tiers) do
        values[tier] = Data.TierLabel(tier)
        order[#order + 1] = tier
    end
    page.tier:SetList(values, order)
    page.tier:SetValue(SelectedTier(group))
    page.tier:SetDisabled(db.show_tiers or #group.tiers < 2)

    page.showTiers:SetChecked(db.show_tiers)
    page.showTiers:SetEnabled(#group.tiers > 1)
    page.showModel:SetChecked(db.matrix_model)
    page.hideComplete:SetChecked(db.hide_complete_rows)

    page.model:SetShown(db.matrix_model)
    page.tablePanel:SetPoint("RIGHT", page, "RIGHT", db.matrix_model and -(MODEL_WIDTH + 10) or 0, 0)

    local columns = Columns(group)
    local size = db.icon_size
    local rows = BuildRows(group, columns)
    page.data = { rows = rows, columns = columns, size = size }
    UpdateHeader(columns, size)

    -- After a tier change: the same class (and set version) in the new tier.
    if Matrix.retier then
        Matrix.retier = false
        local previous = Matrix.previewRow
        if previous then
            for _, data in ipairs(rows) do
                if data.variant and data.class.file == previous.classFile and data.base.setID == previous.baseSetID then
                    Matrix.PreviewRow(data)
                    return
                end
            end
        end
    end

    if db.matrix_model and not Matrix.previewRow then
        local first = DefaultPreview(rows)
        if first then
            Matrix.PreviewRow(first) -- also draws the rows
            return
        end
        page.model:ShowSources({}, "")
    end
    Matrix.RefreshRows()
end
