-- CC_Data.lua
-- Reads the game's transmog sets and turns them into "closet sets":
-- one closet set = every class's version of the same set (e.g. a raid tier),
-- each with its tiers (difficulty variants) and pieces per slot.
CC_Data = {}

local Data = CC_Data
local Utils = CC_Utils
local Safe = Utils.Safe

---------------------------------------------------------
-- Slots (matrix columns, in this order)

Data.SLOTS = {
    { key = "HEAD",     slot = "HeadSlot" },
    { key = "SHOULDER", slot = "ShoulderSlot" },
    { key = "BACK",     slot = "BackSlot" },
    { key = "CHEST",    slot = "ChestSlot" },
    { key = "SHIRT",    slot = "ShirtSlot" },
    { key = "TABARD",   slot = "TabardSlot" },
    { key = "WRIST",    slot = "WristSlot" },
    { key = "HANDS",    slot = "HandsSlot" },
    { key = "WAIST",    slot = "WaistSlot" },
    { key = "LEGS",     slot = "LegsSlot" },
    { key = "FEET",     slot = "FeetSlot" },
    { key = "MAINHAND", slot = "MainHandSlot" },
    { key = "OFFHAND",  slot = "SecondaryHandSlot" },
}

local EQUIP_LOC_TO_SLOT = {
    INVTYPE_HEAD = "HEAD",
    INVTYPE_SHOULDER = "SHOULDER",
    INVTYPE_CLOAK = "BACK",
    INVTYPE_CHEST = "CHEST",
    INVTYPE_ROBE = "CHEST",
    INVTYPE_BODY = "SHIRT",
    INVTYPE_TABARD = "TABARD",
    INVTYPE_WRIST = "WRIST",
    INVTYPE_HAND = "HANDS",
    INVTYPE_WAIST = "WAIST",
    INVTYPE_LEGS = "LEGS",
    INVTYPE_FEET = "FEET",
    INVTYPE_WEAPON = "MAINHAND",
    INVTYPE_2HWEAPON = "MAINHAND",
    INVTYPE_WEAPONMAINHAND = "MAINHAND",
    INVTYPE_RANGED = "MAINHAND",
    INVTYPE_RANGEDRIGHT = "MAINHAND",
    INVTYPE_WEAPONOFFHAND = "OFFHAND",
    INVTYPE_SHIELD = "OFFHAND",
    INVTYPE_HOLDABLE = "OFFHAND",
}

-- Empty slot texture for a column header.
function Data.SlotTexture(slotKey)
    for _, s in ipairs(Data.SLOTS) do
        if s.key == slotKey then
            local _, texture = Safe(GetInventorySlotInfo, s.slot)
            return texture
        end
    end
end

---------------------------------------------------------
-- Building the closet sets

Data.groups = nil      -- list, sorted
Data.groupsByKey = nil -- key -> group
Data.setToGroup = nil  -- setID -> group

local function ClassIDsFromMask(mask)
    local ids = {}
    if not mask or mask == 0 then
        for _, class in ipairs(Utils.Classes()) do
            ids[#ids + 1] = class.id
        end
        return ids, true
    end
    for _, class in ipairs(Utils.Classes()) do
        if bit.band(mask, bit.lshift(1, class.id - 1)) ~= 0 then
            ids[#ids + 1] = class.id
        end
    end
    return ids, false
end

local function TierName(set)
    if set.description and set.description ~= "" then
        return set.description
    end
    return ""
end

function Data.Build()
    local all = Safe(C_TransmogSets and C_TransmogSets.GetAllSets) or {}
    local byID = {}
    for _, set in ipairs(all) do
        byID[set.setID] = set
    end

    -- Base set -> its variants (the base set is one of them).
    local bases = {}
    for _, set in ipairs(all) do
        local baseID = (set.baseSetID and set.baseSetID ~= 0 and byID[set.baseSetID]) and set.baseSetID or set.setID
        local base = bases[baseID]
        if not base then
            base = { setID = baseID, info = byID[baseID], variants = {} }
            bases[baseID] = base
        end
        base.variants[#base.variants + 1] = set
    end

    -- Base sets with the same source label (raid, season...) form one closet set.
    local groupsByKey, groups, setToGroup = {}, {}, {}
    for baseID, base in pairs(bases) do
        local info = base.info
        local label = info.label or ""
        local groupID = label ~= "" and format("%s|%s|%s", label, tostring(info.expansionID), tostring(info.patchID or 0))
            or ("set|" .. baseID)
        local group = groupsByKey[groupID]
        if not group then
            group = {
                id = groupID,
                name = label ~= "" and label or info.name,
                label = label,
                expansionID = info.expansionID,
                bases = {},
                tiers = {},
            }
            groupsByKey[groupID] = group
            groups[#groups + 1] = group
        end
        table.sort(base.variants, function(a, b)
            return (a.uiOrder or 0) < (b.uiOrder or 0)
        end)
        base.classIDs, base.anyClass = ClassIDsFromMask(info.classMask)
        group.bases[#group.bases + 1] = base
    end

    for _, group in ipairs(groups) do
        -- A stable key that does not depend on the game language: the lowest base set ID.
        local minID
        local tierOrder = {}
        local classes = {}
        local classSet = true
        for _, base in ipairs(group.bases) do
            minID = math.min(minID or base.setID, base.setID)
            if base.anyClass or #base.classIDs ~= 1 then
                classSet = false
            end
            for _, id in ipairs(base.classIDs) do
                classes[id] = true
            end
            for _, variant in ipairs(base.variants) do
                local tier = TierName(variant)
                local order = variant.uiOrder or 0
                if tierOrder[tier] == nil or order < tierOrder[tier] then
                    tierOrder[tier] = order
                end
                setToGroup[variant.setID] = group
            end
        end
        group.key = tostring(minID)
        group.classIDs = classes
        group.numClasses = Utils.Count(classes)
        group.isClassSet = classSet and group.numClasses >= 2
        for tier in pairs(tierOrder) do
            group.tiers[#group.tiers + 1] = tier
        end
        table.sort(group.tiers, function(a, b)
            if tierOrder[a] ~= tierOrder[b] then
                return tierOrder[a] < tierOrder[b]
            end
            return a < b
        end)
        table.sort(group.bases, function(a, b)
            return (a.classIDs[1] or 99) < (b.classIDs[1] or 99) or
                ((a.classIDs[1] or 99) == (b.classIDs[1] or 99) and a.setID < b.setID)
        end)
    end

    table.sort(groups, function(a, b)
        if (a.expansionID or -1) ~= (b.expansionID or -1) then
            return (a.expansionID or -1) > (b.expansionID or -1)
        end
        return a.name < b.name
    end)

    Data.groups = groups
    Data.groupsByKey = {}
    for _, group in ipairs(groups) do
        Data.groupsByKey[group.key] = group
    end
    Data.setToGroup = setToGroup
    Data.numSets = #all
    return groups
end

function Data.Groups()
    if not Data.groups or #Data.groups == 0 then
        Data.Build()
    end
    return Data.groups
end

function Data.GetGroup(key)
    Data.Groups()
    return Data.groupsByKey[key]
end

-- The variant of a base set for a tier name (nil if that class has no such tier).
function Data.VariantForTier(base, tier)
    for _, variant in ipairs(base.variants) do
        if TierName(variant) == tier then
            return variant
        end
    end
end

function Data.TierLabel(tier)
    if tier == "" then
        return LibStub("AceLocale-3.0"):GetLocale("ClassCloset")["CC.tier.default"]
    end
    return tier
end

---------------------------------------------------------
-- Pieces of one set

local pieceCache = {}   -- setID -> { [slotKey] = piece }
local pendingItems = {} -- itemID -> true (waiting for item data)

local function SlotForItem(itemID)
    if not itemID then
        return nil
    end
    local getInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    local _, _, _, equipLoc = Safe(getInstant, itemID)
    return equipLoc and EQUIP_LOC_TO_SLOT[equipLoc]
end

local function SourceIDs(setID)
    local ids = {}
    local primary = Safe(C_TransmogSets.GetSetPrimaryAppearances, setID)
    if primary and #primary > 0 then
        for _, p in ipairs(primary) do
            ids[#ids + 1] = p.appearanceID -- this field holds a source ID
        end
        return ids
    end
    return Safe(C_TransmogSets.GetAllSourceIDs, setID) or ids
end

-- Returns { [slotKey] = { sourceID, visualID, itemID, icon } }.
function Data.GetPieces(setID)
    local cached = pieceCache[setID]
    if cached then
        return cached
    end
    local pieces, incomplete = {}, false
    for _, sourceID in ipairs(SourceIDs(setID)) do
        local info = Safe(C_TransmogCollection.GetSourceInfo, sourceID)
        local slot = info and SlotForItem(info.itemID)
        if info and slot then
            if not pieces[slot] then
                pieces[slot] = {
                    slot = slot,
                    sourceID = sourceID,
                    visualID = info.visualID,
                    itemID = info.itemID,
                    name = info.name,
                    quality = info.quality,
                    icon = Safe(C_TransmogCollection.GetSourceIcon, sourceID)
                        or (info.itemID and Safe(C_Item.GetItemIconByID, info.itemID)),
                }
            end
        else
            incomplete = true
            if info and info.itemID then
                pendingItems[info.itemID] = true
                Safe(C_Item.RequestLoadItemDataByID, info.itemID)
            end
        end
    end
    if not incomplete then
        pieceCache[setID] = pieces
    end
    return pieces
end

function Data.IsPendingItem(itemID)
    return pendingItems[itemID]
end

function Data.ClearPending(itemID)
    pendingItems[itemID] = nil
end

---------------------------------------------------------
-- Collected (by appearance, not by item: any item with the same look counts)

local visualCache = {} -- visualID -> bool

function Data.IsPieceCollected(piece)
    local visualID = piece.visualID
    if visualID and visualCache[visualID] ~= nil then
        return visualCache[visualID]
    end
    local collected = false
    local info = Safe(C_TransmogCollection.GetAppearanceInfoBySource, piece.sourceID)
    if info and (info.appearanceIsCollected or info.sourceIsCollected) then
        collected = true
    elseif visualID then
        local sources = Safe(C_TransmogCollection.GetAllAppearanceSources, visualID)
        for _, sourceID in ipairs(sources or {}) do
            local s = Safe(C_TransmogCollection.GetSourceInfo, sourceID)
            if s and s.isCollected then
                collected = true
                break
            end
        end
    end
    if not collected then
        collected = Safe(C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance, piece.sourceID) or false
    end
    if visualID then
        visualCache[visualID] = collected
    end
    return collected
end

---------------------------------------------------------
-- Where an appearance comes from
-- Every item that gives the piece's appearance, with how to get it.
-- Returns a list of { name, quality, collected, how = { "line", ... } }.

local MAX_SOURCES = 10

local function ItemName(info)
    if info.name and info.name ~= "" then
        return info.name
    end
    local name = info.itemID and Safe(C_Item.GetItemNameByID, info.itemID)
    if not name and info.itemID then
        pendingItems[info.itemID] = true
        Safe(C_Item.RequestLoadItemDataByID, info.itemID)
    end
    return name
end

local function HowToGet(sourceID, info)
    local lines = {}
    local drops = Safe(C_TransmogCollection.GetAppearanceSourceDrops, sourceID)
    for _, drop in ipairs(drops or {}) do
        local text = drop.encounter or "?"
        if drop.instance and drop.instance ~= "" then
            text = text .. " - " .. drop.instance
        end
        if drop.difficulties and #drop.difficulties > 0 then
            text = text .. " (" .. table.concat(drop.difficulties, ", ") .. ")"
        end
        lines[#lines + 1] = text
    end
    if #lines == 0 then
        local typeName = info.sourceType and _G["TRANSMOG_SOURCE_" .. info.sourceType .. "_NAME"]
        if typeName then
            lines[#lines + 1] = typeName
        end
    end
    return lines
end

function Data.GetSources(piece)
    local ids = piece.visualID and Safe(C_TransmogCollection.GetAllAppearanceSources, piece.visualID)
    if not ids or #ids == 0 then
        ids = { piece.sourceID }
    end
    local list, byKey, more = {}, {}, 0
    for _, sourceID in ipairs(ids) do
        local info = Safe(C_TransmogCollection.GetSourceInfo, sourceID)
        if info then
            local name = ItemName(info) or ("item " .. tostring(info.itemID))
            local how = HowToGet(sourceID, info)
            -- The same item can be listed once per difficulty: merge identical lines.
            local key = name .. "|" .. table.concat(how, "|")
            local entry = byKey[key]
            if entry then
                entry.collected = entry.collected or info.isCollected
            elseif #list < MAX_SOURCES then
                entry = { name = name, quality = info.quality, collected = info.isCollected, how = how }
                byKey[key] = entry
                list[#list + 1] = entry
            else
                more = more + 1
            end
        end
    end
    return list, more
end

-- Call when the collection changes.
function Data.InvalidateCollection()
    wipe(visualCache)
    Data.CancelScan()
end

---------------------------------------------------------
-- Progress

-- Unique appearances of a closet set: { collected, total }.
-- classFilter(classID) -> bool limits which classes count; nil = all.
-- tier limits to one tier; nil = all tiers.
function Data.Progress(group, classFilter, tier)
    local seen = {}
    local collected, total = 0, 0
    for _, base in ipairs(group.bases) do
        local counts = false
        for _, id in ipairs(base.classIDs) do
            if not classFilter or classFilter(id) then
                counts = true
                break
            end
        end
        if counts then
            for _, variant in ipairs(base.variants) do
                if tier == nil or TierName(variant) == tier then
                    for _, piece in pairs(Data.GetPieces(variant.setID)) do
                        local id = piece.visualID or ("s" .. piece.sourceID)
                        if not seen[id] then
                            seen[id] = true
                            total = total + 1
                            if Data.IsPieceCollected(piece) then
                                collected = collected + 1
                            end
                        end
                    end
                end
            end
        end
    end
    return collected, total
end

---------------------------------------------------------
-- Completed sets scan (spread over several frames)

Data.completed = {} -- key -> true/false
local scan = nil

function Data.IsScanning()
    return scan ~= nil
end

function Data.CancelScan()
    scan = nil
end

-- Checks the given closet sets (all of them if nil).
-- onStep(done, total) is called while it runs, onDone() at the end.
function Data.StartScan(groups, classFilter, onStep, onDone)
    groups = groups or Data.Groups()
    local token = {}
    scan = token
    local results = {}
    local index = 0
    local perFrame = 15
    local function Step()
        if scan ~= token then
            return -- replaced by a newer scan
        end
        for _ = 1, perFrame do
            index = index + 1
            local group = groups[index]
            if not group then
                scan = nil
                Data.completed = results
                if onDone then
                    onDone()
                end
                return
            end
            local have, total = Data.Progress(group, classFilter)
            results[group.key] = total > 0 and have == total
        end
        if onStep then
            onStep(index, #groups)
        end
        C_Timer.After(0, Step)
    end
    C_Timer.After(0, Step)
end
