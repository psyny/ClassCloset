-- CC_PickerUI.lua
-- "Configure" page: choose which sets are in the Tracking or Favorites list.
CC_PickerUI = {}

local Picker = CC_PickerUI
local Data = CC_Data
local Options = CC_Options
local Utils = CC_Utils
local Widgets = CC_Widgets
local Home = CC_HomeUI

local L = LibStub("AceLocale-3.0"):GetLocale("ClassCloset", false)

local ROW_HEIGHT = 38
local MODEL_WIDTH = 270

Picker.kind = "tracked" -- "tracked" | "favorites"
Picker.search = ""
Picker.expansion = "all"
Picker.selected = nil -- closet set key

---------------------------------------------------------
-- Preview: the player's class version of a set, else the first class.

function Picker.PreviewSources(group, tier)
    local playerClass = Utils.PlayerClassFile()
    local chosen
    for _, base in ipairs(group.bases) do
        for _, id in ipairs(base.classIDs) do
            local class = Utils.ClassByID(id)
            if class and class.file == playerClass then
                chosen = chosen or base
            end
        end
    end
    chosen = chosen or group.bases[1]
    if not chosen then
        return {}, ""
    end
    tier = tier or Options.db.tier_choice[group.key] or group.tiers[1]
    local variant = Data.VariantForTier(chosen, tier) or chosen.variants[1]
    local sources = {}
    for _, piece in pairs(Data.GetPieces(variant.setID)) do
        sources[#sources + 1] = piece.sourceID
    end
    local text = variant.name
    if variant.description and variant.description ~= "" then
        text = text .. " (" .. variant.description .. ")"
    end
    return sources, text
end

---------------------------------------------------------
-- Filtering

local function Matches(group)
    local db = Options.db
    if db.picker_class_sets_only and not group.isClassSet then
        return false
    end
    if Picker.expansion ~= "all" and tostring(group.expansionID) ~= Picker.expansion then
        return false
    end
    if Picker.search ~= "" then
        local found = group.name:lower():find(Picker.search, 1, true)
        if not found then
            for _, base in ipairs(group.bases) do
                if base.info.name and base.info.name:lower():find(Picker.search, 1, true) then
                    found = true
                    break
                end
            end
        end
        if not found then
            return false
        end
    end
    if db.picker_hide_complete then
        local have, total = Data.Progress(group, Options.ClassFilter)
        if total > 0 and have == total then
            return false
        end
    end
    return true
end

local function ExpansionList()
    local values, order, seen = { all = L["CC.picker.all_expansions"] }, { "all" }, {}
    local ids = {}
    for _, group in ipairs(Data.Groups()) do
        if group.expansionID and not seen[group.expansionID] then
            seen[group.expansionID] = true
            ids[#ids + 1] = group.expansionID
        end
    end
    table.sort(ids, function(a, b) return a > b end)
    for _, id in ipairs(ids) do
        values[tostring(id)] = Utils.ExpansionName(id)
        order[#order + 1] = tostring(id)
    end
    return values, order
end

local function ProfileList()
    local db = ClassCloset.db
    local values, order = {}, {}
    for _, name in ipairs(db:GetProfiles()) do
        values[name] = name
        order[#order + 1] = name
    end
    local charKey = db.keys.char
    if not values[charKey] then
        values[charKey] = charKey
        order[#order + 1] = charKey
    end
    return values, order
end

---------------------------------------------------------
-- Page

function Picker.Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    Picker.page = page

    -- Header: title and where the list is saved
    page.title = Widgets.Label(page, "GameFontNormalLarge")
    page.title:SetPoint("TOPLEFT", 4, 0)

    page.profileLabel = Widgets.Label(page, "GameFontHighlightSmall", L["CC.picker.saved_in"])
    page.profile = Widgets.Dropdown(page, 200, function(name)
        ClassCloset.db:SetProfile(name)
    end)
    page.profile.frame:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 6)
    page.profileLabel:SetPoint("RIGHT", page.profile.frame, "LEFT", -6, -8)
    page.profileHint = Widgets.Label(page, "GameFontDisableSmall", L["CC.picker.saved_in.hint"])
    page.profileHint:SetPoint("TOPRIGHT", page.profile.frame, "BOTTOMRIGHT", 0, 0)

    -- Filters
    page.search = Widgets.SearchBox(page, 180, function(text)
        Picker.search = text
        Picker.Refresh()
    end)
    page.search:SetPoint("TOPLEFT", 10, -44)

    page.expansion = Widgets.Dropdown(page, 170, function(key)
        Picker.expansion = key
        Picker.Refresh()
    end)
    page.expansion.frame:SetPoint("LEFT", page.search, "RIGHT", 10, -8)

    page.classSets = Widgets.Check(page, L["CC.picker.class_sets_only"], function(on)
        Options.db.picker_class_sets_only = on
        Picker.Refresh()
    end, L["CC.options.picker_class_sets_only.desc"])
    page.classSets:SetPoint("LEFT", page.expansion.frame, "RIGHT", 10, 8)

    page.hideComplete = Widgets.Check(page, L["CC.picker.hide_complete"], function(on)
        Options.db.picker_hide_complete = on
        Picker.Refresh()
    end)

    page.showModel = Widgets.Check(page, L["CC.picker.show_model"], function(on)
        Options.db.picker_model = on
        Picker.Refresh()
    end)

    -- List
    page.listPanel = Widgets.Panel(page)
    page.listPanel:SetPoint("TOPLEFT", 0, -74)
    page.listPanel:SetPoint("BOTTOM", 0, 0)

    page.count = Widgets.Label(page, "GameFontDisableSmall")
    page.count:SetPoint("BOTTOMRIGHT", page.listPanel, "TOPRIGHT", -4, 4)

    local function CreateRow(content)
        local row = Home.CreateSetRow(content, { check = true })
        row.check:SetScript("OnClick", function(self)
            local list = Options.db[Picker.kind]
            list[row.item.key] = self:GetChecked() and true or nil
            ClassCloset:OnListsChanged()
        end)
        row:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                CC_Window.OpenMatrix(self.item.key)
                return
            end
            Picker.Select(self.item.key)
        end)
        row:SetScript("OnDoubleClick", function(self)
            CC_Window.OpenMatrix(self.item.key)
        end)
        return row
    end
    page.list = Widgets.ScrollList(page.listPanel, ROW_HEIGHT, CreateRow, function(row, group)
        Home.UpdateSetRow(row, group)
        row.check:SetChecked(Options.db[Picker.kind][group.key] == true)
        row.selectedTexture:SetShown(Picker.selected == group.key)
    end)
    page.list:SetEmptyText(L["CC.picker.empty"])

    -- Preview
    page.model = CC_Model.Create(page)
    page.model:SetPoint("TOPRIGHT", 0, -74)
    page.model:SetPoint("BOTTOMRIGHT", 0, 30)
    page.model:SetWidth(MODEL_WIDTH)

    page.open = Widgets.Button(page, L["CC.picker.open_table"], MODEL_WIDTH, 22, function()
        if Picker.selected then
            CC_Window.OpenMatrix(Picker.selected)
        end
    end)
    page.open:SetPoint("BOTTOMRIGHT", 0, 2)

    page.noModelHint = Widgets.Label(page, "GameFontDisableSmall", L["CC.picker.hint"])
    page.noModelHint:SetPoint("BOTTOMLEFT", page.listPanel, "BOTTOMRIGHT", 10, 30)
    page.noModelHint:SetWidth(MODEL_WIDTH - 10)

    return page
end

function Picker.Show(kind)
    Picker.kind = kind or Picker.kind
    Picker.Refresh()
end

function Picker.Select(key)
    Picker.selected = key
    Picker.page.list:Refresh()
    Picker.UpdatePreview()
end

function Picker.UpdatePreview()
    local page = Picker.page
    local group = Picker.selected and Data.GetGroup(Picker.selected)
    page.open:SetEnabled(group ~= nil)
    if not Options.db.picker_model then
        return
    end
    if group then
        page.model:ShowSources(Picker.PreviewSources(group))
    else
        page.model:ShowSources({}, L["CC.picker.select_hint"])
    end
end

function Picker.Refresh()
    local page = Picker.page
    local db = Options.db
    page.title:SetText(L["CC.picker.title." .. Picker.kind])

    local values, order = ProfileList()
    page.profile:SetList(values, order)
    page.profile:SetValue(ClassCloset.db:GetCurrentProfile())

    values, order = ExpansionList()
    page.expansion:SetList(values, order)
    page.expansion:SetValue(Picker.expansion)

    page.classSets:SetChecked(db.picker_class_sets_only)
    page.hideComplete:SetChecked(db.picker_hide_complete)
    page.showModel:SetChecked(db.picker_model)
    page.hideComplete:ClearAllPoints()
    page.hideComplete:SetPoint("LEFT", page.classSets, "LEFT", page.classSets:FullWidth(), 0)
    page.showModel:ClearAllPoints()
    page.showModel:SetPoint("LEFT", page.hideComplete, "LEFT", page.hideComplete:FullWidth(), 0)

    -- Model on the right, or a wider list
    local showModel = db.picker_model
    page.model:SetShown(showModel)
    page.noModelHint:SetShown(not showModel)
    page.listPanel:SetPoint("RIGHT", page, "RIGHT", -(MODEL_WIDTH + 10), 0)

    local items = {}
    for _, group in ipairs(Data.Groups()) do
        if Matches(group) then
            items[#items + 1] = group
        end
    end
    page.list:SetItems(items)
    page.count:SetText(format(L["CC.picker.count"], #items, Utils.Count(db[Picker.kind])))
    Picker.UpdatePreview()
end
