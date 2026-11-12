-- CC_HomeUI.lua
-- Main page: Tracking, Favorites and Completed lists.
CC_HomeUI = {}

local Home = CC_HomeUI
local Data = CC_Data
local Options = CC_Options
local Utils = CC_Utils
local Widgets = CC_Widgets

local L = LibStub("AceLocale-3.0"):GetLocale("ClassCloset", false)

local ROW_HEIGHT = 38
local TOP_BAR = 32 -- room for the Newest button

---------------------------------------------------------
-- Set row (also used by the set lists page)

local function ShowSetTooltip(owner, group)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(group.name, 1, 1, 1)
    GameTooltip:AddLine(Utils.ExpansionName(group.expansionID), 0.7, 0.7, 0.7)
    local have, total = Data.Progress(group, Options.ClassFilter)
    GameTooltip:AddLine(format(L["CC.row.progress"], have, total), 1, 0.82, 0)
    local tiers = {}
    for _, tier in ipairs(group.tiers) do
        tiers[#tiers + 1] = Data.TierLabel(tier)
    end
    if #group.tiers > 1 then
        GameTooltip:AddLine(format(L["CC.row.tiers"], table.concat(tiers, ", ")), 0.8, 0.8, 0.8, true)
    end
    local classes = {}
    for _, class in ipairs(Utils.Classes()) do
        if group.classIDs[class.id] then
            classes[#classes + 1] = Utils.ClassIconMarkup(class.file, 14)
        end
    end
    GameTooltip:AddLine(table.concat(classes, " "))
    GameTooltip:Show()
end
Home.ShowSetTooltip = ShowSetTooltip

-- opts.check = true adds a check box on the left (row.check).
function Home.CreateSetRow(content, opts)
    local row = CreateFrame("Button", nil, content)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    Widgets.AddRowTextures(row)

    local left = 4
    if opts and opts.check then
        local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        check:SetSize(22, 22)
        check:SetPoint("LEFT", 2, 0)
        row.check = check
        left = 28
    end

    row.name = Widgets.Label(row, "GameFontNormal")
    row.name:SetPoint("TOPLEFT", left, -4)
    row.name:SetPoint("RIGHT", -60, 0)
    row.name:SetWordWrap(false)

    row.sub = Widgets.Label(row, "GameFontDisableSmall")
    row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
    row.sub:SetPoint("RIGHT", -60, 0)
    row.sub:SetWordWrap(false)

    row.count = Widgets.Label(row, "GameFontHighlightSmall")
    row.count:SetPoint("TOPRIGHT", -6, -5)
    row.count:SetJustifyH("RIGHT")

    row.bar = Widgets.ProgressBar(row, 4)
    row.bar:SetPoint("BOTTOMLEFT", left, 4)
    row.bar:SetPoint("BOTTOMRIGHT", -6, 4)

    row:SetScript("OnEnter", function(self)
        if self.item then
            ShowSetTooltip(self, self.item)
        end
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

function Home.UpdateSetRow(row, group)
    local have, total = Data.Progress(group, Options.ClassFilter)
    local done = total > 0 and have == total
    row.name:SetText(done and ("|cff40d040" .. group.name .. "|r") or group.name)
    local sub = Utils.ExpansionName(group.expansionID)
    if #group.tiers > 1 then
        sub = sub .. " · " .. format(L["CC.row.num_tiers"], #group.tiers)
    end
    if group.numClasses > 1 then
        sub = sub .. " · " .. format(L["CC.row.num_classes"], group.numClasses)
    end
    row.sub:SetText(sub)
    row.count:SetText(format("%d/%d", have, total))
    row.bar:SetProgress(have, total)
end

---------------------------------------------------------
-- Page

local function ItemsFor(keys)
    local items = {}
    for _, group in ipairs(Data.Groups()) do
        if keys[group.key] then
            items[#items + 1] = group
        end
    end
    return items
end

-- Three columns of the same width.
function Home.Layout()
    local page = Home.page
    local width = page:GetWidth()
    if not width or width <= 0 then
        return
    end
    local gap = 12
    local w = (width - gap * 2) / 3
    for i, column in ipairs({ page.tracked, page.favorites, page.completed }) do
        column:ClearAllPoints()
        column:SetPoint("TOPLEFT", (i - 1) * (w + gap), -TOP_BAR)
        column:SetPoint("BOTTOM", 0, 0)
        column:SetWidth(w)
    end
end

local function Column(page, titleKey, onConfigure)
    local column = CreateFrame("Frame", nil, page)

    column.title = Widgets.Label(column, "GameFontNormalLarge", L[titleKey])
    column.title:SetPoint("TOPLEFT", 4, 0)

    column.status = Widgets.Label(column, "GameFontDisableSmall")
    column.status:SetPoint("TOPRIGHT", -4, -4)
    column.status:SetJustifyH("RIGHT")

    local panel = Widgets.Panel(column)
    panel:SetPoint("TOPLEFT", 0, -22)
    panel:SetPoint("BOTTOMRIGHT", 0, onConfigure and 30 or 0)

    column.list = Widgets.ScrollList(panel, ROW_HEIGHT, Home.CreateSetRow, function(row, group)
        Home.UpdateSetRow(row, group)
        row:SetScript("OnClick", function()
            CC_Window.OpenMatrix(group.key)
        end)
    end)

    if onConfigure then
        column.configure = Widgets.Button(column, L["CC.home.configure"], 120, 22, onConfigure)
        column.configure:SetPoint("BOTTOMLEFT", 0, 2)
    end
    return column
end

function Home.Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    Home.page = page

    page.newest = Widgets.Button(page, L["CC.home.newest"], 120, 22, function()
        CC_Window.OpenNewest()
    end)
    page.newest:SetPoint("TOPLEFT", 0, 0)
    page.newestInfo = Widgets.Label(page, "GameFontHighlightSmall")
    page.newestInfo:SetPoint("LEFT", page.newest, "RIGHT", 10, 0)

    page.tracked = Column(page, "CC.home.tracked", function()
        CC_Window.OpenPicker("tracked")
    end)
    page.favorites = Column(page, "CC.home.favorites", function()
        CC_Window.OpenPicker("favorites")
    end)
    page.completed = Column(page, "CC.home.completed")

    page.tracked.list:SetEmptyText(L["CC.home.tracked.empty"])
    page.favorites.list:SetEmptyText(L["CC.home.favorites.empty"])
    page.completed.list:SetEmptyText(L["CC.home.completed.empty"])

    page:SetScript("OnSizeChanged", Home.Layout)

    page.completed.rescan = Widgets.Button(page.completed, L["CC.home.rescan"], 120, 22, function()
        Home.StartScan()
    end)
    page.completed.rescan:SetPoint("BOTTOMRIGHT", 0, 2)
    page.completed.list.scroll:GetParent():SetPoint("BOTTOMRIGHT", 0, 30)

    page.completed.scope = Widgets.Label(page.completed, "GameFontDisableSmall")
    page.completed.scope:SetPoint("BOTTOMLEFT", 2, 8)
    page.completed.scope:SetPoint("RIGHT", page.completed.rescan, "LEFT", -6, 0)
    page.completed.scope:SetWordWrap(false)

    return page
end

local function CompletedItems()
    local db = Options.db
    local items = {}
    for _, group in ipairs(Data.Groups()) do
        if Data.completed[group.key] then
            local inLists = db.tracked[group.key] or db.favorites[group.key]
            if db.completed_scope == "all" or inLists then
                items[#items + 1] = group
            end
        end
    end
    return items
end

-- Completed list state: "none" (never checked), "done", or "stale" (the collection
-- changed since). Checking every set is heavy, so it only runs when asked; with the
-- "lists" scope it only checks the sets in Tracking and Favorites, which is quick.
Home.scanState = "none"

local function ScanTargets()
    local db = Options.db
    if db.completed_scope == "all" then
        return nil -- every set
    end
    local groups = {}
    for _, group in ipairs(Data.Groups()) do
        if db.tracked[group.key] or db.favorites[group.key] then
            groups[#groups + 1] = group
        end
    end
    return groups
end

function Home.StartScan()
    local page = Home.page
    page.completed.rescan:Disable()
    Data.StartScan(ScanTargets(), Options.ClassFilter, function(done, total)
        if page:IsVisible() then
            page.completed.status:SetText(format(L["CC.home.scanning"], done, total))
        end
    end, function()
        Home.scanState = "done"
        if page:IsVisible() then
            Home.Refresh()
        end
    end)
    Home.Refresh()
end

function Home.Refresh()
    local page = Home.page
    local db = Options.db
    Home.Layout()
    local today, week = CC_History.CountSince(CC_History.DAY), CC_History.CountSince(CC_History.WEEK)
    page.newestInfo:SetText(format(L["CC.home.newest_info"], today, week))
    page.tracked.list:SetItems(ItemsFor(db.tracked))
    page.favorites.list:SetItems(ItemsFor(db.favorites))
    page.tracked.status:SetText(Utils.Count(db.tracked))
    page.favorites.status:SetText(Utils.Count(db.favorites))

    local all = db.completed_scope == "all"
    page.completed.scope:SetText(all and L["CC.home.completed.scope_all"] or L["CC.home.completed.scope_lists"])
    page.completed.rescan:SetText(Home.scanState == "none" and L["CC.home.check"] or L["CC.home.rescan"])

    if not all and Home.scanState ~= "done" and not Data.IsScanning() then
        Home.StartScan() -- quick: only the sets in the two lists
        return
    end

    local completed = page.completed
    if Data.IsScanning() then
        completed.rescan:Disable()
        completed.list:SetEmptyText(L["CC.home.completed.wait"])
        completed.list:SetItems({})
        return
    end
    completed.rescan:Enable()
    if Home.scanState == "none" then
        completed.status:SetText("")
        completed.list:SetEmptyText(L["CC.home.completed.not_checked"])
        completed.list:SetItems({})
        return
    end
    local items = CompletedItems()
    completed.list:SetEmptyText(L["CC.home.completed.empty"])
    completed.list:SetItems(items)
    if Home.scanState == "stale" then
        completed.status:SetText("|cffff9933" .. L["CC.home.completed.stale"] .. "|r " .. #items)
    else
        completed.status:SetText(#items)
    end
end

-- The collection or the shown classes changed: the results may be out of date.
function Home.Invalidate()
    if Home.scanState == "done" then
        Home.scanState = "stale"
    elseif Data.IsScanning() then
        Home.scanState = Data.completed and next(Data.completed) and "stale" or "none"
    end
end

-- What counts as completed changed: forget the results.
function Home.ResetScan()
    Data.CancelScan()
    Data.completed = {}
    Home.scanState = "none"
end
