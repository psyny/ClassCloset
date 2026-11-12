-- ClassCloset.lua
ClassCloset = LibStub("AceAddon-3.0"):NewAddon("ClassCloset", "AceConsole-3.0", "AceEvent-3.0")

local Addon = ClassCloset
local Utils = CC_Utils
local Data = CC_Data
local Options = CC_Options
local Window = CC_Window

local L = LibStub("AceLocale-3.0"):GetLocale("ClassCloset", false)

-- Events that mean the collection changed.
local COLLECTION_EVENTS = {
    "TRANSMOG_COLLECTION_UPDATED",
    "TRANSMOG_COLLECTION_SOURCE_REMOVED",
}
-- Item data arrived: pieces that were still loading can be shown now.
local ITEM_EVENTS = { "GET_ITEM_INFO_RECEIVED", "TRANSMOG_COLLECTION_ITEM_UPDATE" }

---------------------------------------------------------
-- Addon events

function Addon:OnInitialize()
    -- true: the "Default" profile is shared by every character (account lists).
    self.db = LibStub("AceDB-3.0"):New("ClassClosetDB", Options.defaults, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
    Options.Migrate(self.db.profile)
    Options.db = self.db.profile
    CC_History.global = self.db.global
    CC_History.Trim()

    local options = Options.options
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    options.args.profiles.order = 100
    options.args.profiles.desc = L["CC.options.profiles.desc"]

    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(Options.APP_NAME, options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(Options.APP_NAME, Options.APP_NAME)

    self:RegisterChatCommand("cc", "SlashCommand")
    self:RegisterChatCommand("classcloset", "SlashCommand")
end

function Addon:OnEnable()
    for _, event in ipairs(COLLECTION_EVENTS) do
        self:SafeRegisterEvent(event, "OnCollectionChanged")
    end
    for _, event in ipairs(ITEM_EVENTS) do
        self:SafeRegisterEvent(event, "OnItemData")
    end
    self:SafeRegisterEvent("TRANSMOG_COLLECTION_SOURCE_ADDED", "OnSourceAdded")
end

-- A new appearance source was learned: remember it, then refresh.
function Addon:OnSourceAdded(_, sourceID)
    pcall(CC_History.OnSourceAdded, sourceID)
    self:OnCollectionChanged()
end

-- Unknown events (renamed by a patch) are skipped.
function Addon:SafeRegisterEvent(event, handler)
    pcall(self.RegisterEvent, self, event, handler)
end

function Addon:OnProfileChanged()
    Options.Migrate(self.db.profile)
    Options.db = self.db.profile
    LibStub("AceConfigRegistry-3.0"):NotifyChange(Options.APP_NAME)
    self:OnCollectionChanged() -- shown classes may differ
end

function Addon:SlashCommand(input)
    local cmd = strtrim(input or ""):lower()
    if cmd == "options" or cmd == "config" then
        Options.Open()
    elseif cmd == "debug" then
        self:PrintDebug()
    elseif cmd == "rebuild" then
        Data.Build()
        self:OnCollectionChanged()
        Utils.Print(L["CC.msg.rebuilt"])
    elseif cmd == "help" then
        Utils.Print(L["CC.msg.help"])
    else
        Window.Toggle()
    end
end

function Addon:ShowWindow()
    Window.Show()
end

---------------------------------------------------------
-- Refresh (batched)

local refreshQueued = false

function Addon:RefreshWindow()
    if refreshQueued then
        return
    end
    refreshQueued = true
    C_Timer.After(0.1, function()
        refreshQueued = false
        Window.Refresh()
    end)
end

function Addon:OnCollectionChanged()
    CC_HomeUI.Invalidate() -- before the running check is cancelled
    Data.InvalidateCollection()
    self:RefreshWindow()
end

function Addon:OnListsChanged()
    if Options.db.completed_scope == "lists" then
        CC_HomeUI.Invalidate()
    end
    self:RefreshWindow()
end

function Addon:OnItemData(_, itemID)
    if itemID and Data.IsPendingItem(itemID) then
        Data.ClearPending(itemID)
        if Window.IsShown() then
            self:RefreshWindow()
        end
    end
end

---------------------------------------------------------
-- /cc debug: what the game gave us.

function Addon:PrintDebug()
    local groups = Data.Build()
    local classSets, perClass = 0, {}
    for _, group in ipairs(groups) do
        if group.isClassSet then
            classSets = classSets + 1
        end
        for id in pairs(group.classIDs) do
            perClass[id] = (perClass[id] or 0) + 1
        end
    end
    Utils.Print(format("%d game sets, %d closet sets (%d with one version per class)", Data.numSets or 0, #groups, classSets))
    local parts = {}
    for _, class in ipairs(Utils.Classes()) do
        parts[#parts + 1] = format("%s %d", class.file, perClass[class.id] or 0)
    end
    Utils.Print("sets per class: " .. table.concat(parts, ", "))
    for i = 1, math.min(3, #groups) do
        local group = groups[i]
        local have, total = Data.Progress(group)
        Utils.Print(format("  %s [%s]: %d classes, tiers {%s}, %d/%d", group.name, group.key,
            group.numClasses, table.concat(group.tiers, ", "), have, total))
    end
end
