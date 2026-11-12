-- CC_History.lua
-- The latest appearances you collected: when, where and on which character.
-- Saved account wide (db.global), not per profile.
CC_History = {}

local History = CC_History
local Utils = CC_Utils
local Safe = Utils.Safe

History.DAY = 24 * 60 * 60
History.WEEK = 7 * History.DAY

History.global = nil -- ClassCloset.db.global, set on load

local newestByVisual = nil -- visualID -> newest time (built when needed)

local function List()
    return History.global.history
end

function History.Entries()
    return List()
end

function History.Max()
    return History.global.history_max
end

function History.Trim()
    local list = List()
    local max = math.max(1, History.Max())
    for i = #list, max + 1, -1 do
        list[i] = nil
    end
    newestByVisual = nil
end

function History.Clear()
    wipe(List())
    newestByVisual = nil
end

---------------------------------------------------------
-- Recording

-- Another source with the same look was already collected: the appearance is not new.
local function OtherSourceCollected(sourceID, visualID)
    local sources = Safe(C_TransmogCollection.GetAllAppearanceSources, visualID)
    for _, id in ipairs(sources or {}) do
        if id ~= sourceID then
            local info = Safe(C_TransmogCollection.GetSourceInfo, id)
            if info and info.isCollected then
                return true
            end
        end
    end
    return false
end

local function Where()
    local where = {}
    local mapID = Safe(C_Map.GetBestMapForUnit, "player")
    local mapInfo = mapID and Safe(C_Map.GetMapInfo, mapID)
    where.zone = mapInfo and mapInfo.name or Safe(GetRealZoneText)
    local sub = Safe(GetSubZoneText)
    if sub and sub ~= "" and sub ~= where.zone then
        where.subzone = sub
    end
    local inInstance = Safe(IsInInstance)
    if inInstance then
        local name, _, _, difficultyName = Safe(GetInstanceInfo)
        where.instance = name
        if difficultyName and difficultyName ~= "" then
            where.difficulty = difficultyName
        end
    end
    return where
end

-- TRANSMOG_COLLECTION_SOURCE_ADDED: sourceID was just learned.
function History.OnSourceAdded(sourceID)
    if not sourceID then
        return
    end
    local info = Safe(C_TransmogCollection.GetSourceInfo, sourceID)
    if not info then
        return
    end
    if History.global.history_new_only and info.visualID and OtherSourceCollected(sourceID, info.visualID) then
        return
    end
    local list = List()
    for i = 1, math.min(#list, 30) do
        if list[i].sourceID == sourceID then
            return -- the game sent it twice
        end
    end
    local name = info.name
    if (not name or name == "") and info.itemID then
        name = Safe(C_Item.GetItemNameByID, info.itemID)
    end
    local where = Where()
    table.insert(list, 1, {
        time = time(),
        sourceID = sourceID,
        visualID = info.visualID,
        itemID = info.itemID,
        name = name,
        quality = info.quality,
        char = UnitName("player"),
        realm = Safe(GetNormalizedRealmName) or Safe(GetRealmName),
        class = Utils.PlayerClassFile(),
        zone = where.zone,
        subzone = where.subzone,
        instance = where.instance,
        difficulty = where.difficulty,
    })
    History.Trim()
end

---------------------------------------------------------
-- Reading

-- Newest time an appearance was collected, or nil if not in the history.
function History.AcquiredAt(visualID)
    if not visualID then
        return nil
    end
    if not newestByVisual then
        newestByVisual = {}
        for _, entry in ipairs(List()) do
            if entry.visualID and not newestByVisual[entry.visualID] then
                newestByVisual[entry.visualID] = entry.time -- the list is newest first
            end
        end
    end
    return newestByVisual[visualID]
end

-- "day", "week" or nil.
function History.Recency(visualID)
    local at = History.AcquiredAt(visualID)
    if not at then
        return nil
    end
    local age = time() - at
    if age < History.DAY then
        return "day"
    elseif age < History.WEEK then
        return "week"
    end
end

function History.CountSince(seconds)
    local since, n = time() - seconds, 0
    for _, entry in ipairs(List()) do
        if entry.time < since then
            break
        end
        n = n + 1
    end
    return n
end

-- "Zone - Subzone (Instance, Difficulty)"
function History.PlaceText(entry)
    local text = entry.zone or "?"
    if entry.subzone then
        text = text .. " - " .. entry.subzone
    end
    if entry.instance and entry.instance ~= entry.zone then
        text = text .. " (" .. entry.instance .. (entry.difficulty and (", " .. entry.difficulty) or "") .. ")"
    elseif entry.difficulty then
        text = text .. " (" .. entry.difficulty .. ")"
    end
    return text
end

function History.WhoText(entry)
    local name = entry.char or "?"
    if entry.realm and entry.realm ~= (Safe(GetNormalizedRealmName) or "") then
        name = name .. "-" .. entry.realm
    end
    if entry.class then
        return Utils.ClassColorCode(entry.class) .. name .. "|r"
    end
    return name
end

function History.AgoText(t)
    local L = LibStub("AceLocale-3.0"):GetLocale("ClassCloset")
    local age = math.max(0, time() - t)
    if age < 60 then
        return L["CC.time.now"]
    elseif age < 3600 then
        return format(L["CC.time.minutes"], math.floor(age / 60))
    elseif age < History.DAY then
        return format(L["CC.time.hours"], math.floor(age / 3600))
    elseif age < 30 * History.DAY then
        return format(L["CC.time.days"], math.floor(age / History.DAY))
    end
    return date("%Y-%m-%d", t)
end

function History.DateText(t)
    return date("%Y-%m-%d %H:%M", t)
end

function History.ItemName(entry)
    if entry.name and entry.name ~= "" then
        return entry.name
    end
    local name = entry.itemID and Safe(C_Item.GetItemNameByID, entry.itemID)
    if name then
        entry.name = name
    end
    return name or ("item " .. tostring(entry.itemID))
end

-- The ClassCloset set this piece belongs to, if any.
function History.GroupFor(entry)
    local setIDs = Safe(C_TransmogSets.GetSetsContainingSourceID, entry.sourceID)
    CC_Data.Groups()
    for _, setID in ipairs(setIDs or {}) do
        local group = CC_Data.setToGroup[setID]
        if group then
            return group
        end
    end
end
