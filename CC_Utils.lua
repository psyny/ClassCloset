-- CC_Utils.lua
CC_Utils = {}

local Utils = CC_Utils

-- Calls fn safely: returns nil (instead of an error) if the API is missing or fails.
function Utils.Safe(fn, ...)
    if not fn then
        return nil
    end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then
        return nil
    end
    return a, b, c, d
end

---------------------------------------------------------
-- Classes

local classes -- { { id, file, name }, ... } in class ID order

function Utils.Classes()
    if classes then
        return classes
    end
    classes = {}
    local count = Utils.Safe(GetNumClasses) or 13
    for id = 1, math.max(count, 13) do
        local name, file = Utils.Safe(GetClassInfo, id)
        if name and file then
            classes[#classes + 1] = { id = id, file = file, name = name }
        end
    end
    return classes
end

function Utils.ClassByID(id)
    for _, class in ipairs(Utils.Classes()) do
        if class.id == id then
            return class
        end
    end
end

function Utils.PlayerClassFile()
    local _, file = UnitClass("player")
    return file
end

function Utils.ClassColorCode(file)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
    if color and color.colorStr then
        return "|c" .. color.colorStr
    end
    return "|cffffffff"
end

function Utils.ClassColor(file)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

-- Inline class icon (texture markup).
function Utils.ClassIconMarkup(file, size)
    size = size or 14
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[file]
    if not coords then
        return ""
    end
    return format("|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:%d:%d:0:0:256:256:%d:%d:%d:%d|t",
        size, size, coords[1] * 256, coords[2] * 256, coords[3] * 256, coords[4] * 256)
end

---------------------------------------------------------
-- Misc

function Utils.ExpansionName(id)
    if id == nil then
        return ""
    end
    return _G["EXPANSION_NAME" .. id] or ("Expansion " .. id)
end

function Utils.Print(msg)
    print("|cffd9a6ffClassCloset|r: " .. tostring(msg))
end

function Utils.Count(tbl)
    local n = 0
    for _ in pairs(tbl) do
        n = n + 1
    end
    return n
end
