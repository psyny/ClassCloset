-- CC_NewestUI.lua
-- "Newest" page: the latest appearances you collected, with when, where and who.
CC_NewestUI = {}

local Newest = CC_NewestUI
local History = CC_History
local Utils = CC_Utils
local Widgets = CC_Widgets

local L = LibStub("AceLocale-3.0"):GetLocale("ClassCloset", false)

local ROW_HEIGHT = 40

Newest.onlyMe = false

local function QualityColor(quality)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

---------------------------------------------------------
-- Rows

local function ShowTooltip(row)
    local entry = row.item
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(History.ItemName(entry), QualityColor(entry.quality))
    GameTooltip:AddDoubleLine(L["CC.newest.when"], History.DateText(entry.time), 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["CC.newest.who"], History.WhoText(entry), 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["CC.newest.where"], History.PlaceText(entry), 0.7, 0.7, 0.7, 1, 1, 1)
    if row.group then
        GameTooltip:AddDoubleLine(L["CC.newest.set"], row.group.name, 0.7, 0.7, 0.7, 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["CC.newest.click_hint"], 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
end

local function CreateRow(content)
    local row = CreateFrame("Button", nil, content)
    Widgets.AddRowTextures(row)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(32, 32)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    row.name = Widgets.Label(row, "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
    row.name:SetPoint("RIGHT", -110, 0)
    row.name:SetWordWrap(false)

    row.sub = Widgets.Label(row, "GameFontHighlightSmall")
    row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 1)
    row.sub:SetPoint("RIGHT", -110, 0)
    row.sub:SetWordWrap(false)

    row.ago = Widgets.Label(row, "GameFontHighlightSmall")
    row.ago:SetPoint("RIGHT", -8, 0)
    row.ago:SetJustifyH("RIGHT")

    row:SetScript("OnEnter", ShowTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self)
        if self.group then
            CC_Window.OpenMatrix(self.group.key)
        end
    end)
    return row
end

local function UpdateRow(row, entry)
    row.group = History.GroupFor(entry)
    local icon = Utils.Safe(C_TransmogCollection.GetSourceIcon, entry.sourceID)
        or (entry.itemID and Utils.Safe(C_Item.GetItemIconByID, entry.itemID)) or 134400
    row.icon:SetTexture(icon)

    local r, g, b = QualityColor(entry.quality)
    local name = format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, History.ItemName(entry))
    if row.group then
        name = name .. "  |cffaaaaaa" .. row.group.name .. "|r"
    end
    row.name:SetText(name)
    row.sub:SetText(History.WhoText(entry) .. "  |cff999999·|r  " .. History.PlaceText(entry))

    local recency = History.Recency(entry.visualID)
    local ago = History.AgoText(entry.time)
    if recency == "day" then
        ago = "|cffffd100" .. ago .. "|r"
    elseif recency == "week" then
        ago = "|cffd0d8e8" .. ago .. "|r"
    end
    row.ago:SetText(ago)
end

---------------------------------------------------------
-- Page

function Newest.Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    Newest.page = page

    page.title = Widgets.Label(page, "GameFontNormalLarge", L["CC.newest.title"])
    page.title:SetPoint("TOPLEFT", 4, 0)

    page.count = Widgets.Label(page, "GameFontDisableSmall")
    page.count:SetPoint("LEFT", page.title, "RIGHT", 12, -1)

    page.clear = Widgets.Button(page, L["CC.newest.clear"], 110, 22, function()
        StaticPopup_Show("CLASSCLOSET_CLEAR_HISTORY")
    end)
    page.clear:SetPoint("TOPRIGHT", 0, 2)

    page.onlyMe = Widgets.Check(page, L["CC.newest.only_me"], function(on)
        Newest.onlyMe = on
        Newest.Refresh()
    end)
    page.onlyMe:SetPoint("RIGHT", page.clear, "LEFT", -150, 0)

    local panel = Widgets.Panel(page)
    panel:SetPoint("TOPLEFT", 0, -28)
    panel:SetPoint("BOTTOMRIGHT", 0, 0)
    page.list = Widgets.ScrollList(panel, ROW_HEIGHT, CreateRow, UpdateRow)
    page.list:SetEmptyText(L["CC.newest.empty"])

    StaticPopupDialogs["CLASSCLOSET_CLEAR_HISTORY"] = {
        text = L["CC.newest.clear_confirm"],
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            History.Clear()
            ClassCloset:RefreshWindow()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    return page
end

function Newest.Refresh()
    local page = Newest.page
    local me = UnitName("player")
    local realm = Utils.Safe(GetNormalizedRealmName) or Utils.Safe(GetRealmName)
    local items = {}
    for _, entry in ipairs(History.Entries()) do
        if not Newest.onlyMe or (entry.char == me and (entry.realm == nil or entry.realm == realm)) then
            items[#items + 1] = entry
        end
    end
    page.onlyMe:SetChecked(Newest.onlyMe)
    page.count:SetText(format(L["CC.newest.count"], #History.Entries(), History.Max(),
        History.CountSince(History.DAY), History.CountSince(History.WEEK)))
    page.clear:SetEnabled(#History.Entries() > 0)
    page.list:SetItems(items)
end
