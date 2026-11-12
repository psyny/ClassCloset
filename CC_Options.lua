-- CC_Options.lua
CC_Options = {}

local Options = CC_Options
local Utils = CC_Utils

local L = LibStub("AceLocale-3.0"):GetLocale("ClassCloset", false)

Options.APP_NAME = "ClassCloset"
Options.db = nil -- profile
Options.options = nil

---------------------------------------------------------
-- Defaults
-- The lists live in the profile. The "Default" profile is shared by every
-- character (account list); pick a character profile for a list of its own.

Options.defaults = {
    profile = {
        tracked = {},     -- closet set key -> true
        favorites = {},   -- closet set key -> true
        hidden_classes = {}, -- classFile -> true: left out of tables and progress
        fav_classes = {}, -- closet set key -> { classFile -> true }: listed first in that set's table
        tier_choice = {}, -- closet set key -> last selected tier

        -- Main window
        completed_scope = "all", -- "all" | "lists"

        -- Set lists (Configure)
        picker_model = true,
        picker_class_sets_only = true,
        picker_hide_complete = false,

        -- Set table
        matrix_model = true,
        show_tiers = false,
        hide_complete_rows = false,
        icon_size = 30,
        veil_alpha = 0.9,
        play_sound = true,

        -- Glow on pieces collected recently
        glow_enabled = true,
        glow_animated = true,
        glow_day_color = { r = 1, g = 0.82, b = 0.15 },  -- gold: last 24 hours
        glow_week_color = { r = 0.8, g = 0.85, b = 0.95 }, -- silver: last 7 days
    },
    global = {
        window = nil, -- { point, x, y }
        -- Newest appearances: account wide, not per profile.
        history = {},
        history_max = 200,
        history_new_only = true,
    },
}

function Options.Migrate(profile)
    -- 0.1.0 saved favorite classes for every set at once (classFile -> true).
    for key, value in pairs(profile.fav_classes) do
        if type(value) ~= "table" then
            profile.fav_classes[key] = nil
        end
    end
end

-- Favorite classes of one set.
function Options.IsFavClass(setKey, classFile)
    local favs = Options.db.fav_classes[setKey]
    return favs ~= nil and favs[classFile] == true
end

function Options.ToggleFavClass(setKey, classFile)
    local all = Options.db.fav_classes
    local favs = all[setKey] or {}
    favs[classFile] = (not favs[classFile]) or nil
    all[setKey] = next(favs) and favs or nil
end

---------------------------------------------------------
-- Helpers used by the windows

function Options.IsClassShown(classFile)
    return not Options.db.hidden_classes[classFile]
end

-- classID -> bool, for CC_Data.Progress.
function Options.ClassFilter(classID)
    local class = Utils.ClassByID(classID)
    return class ~= nil and Options.IsClassShown(class.file)
end

function Options.Open()
    LibStub("AceConfigDialog-3.0"):Open(Options.APP_NAME)
end

---------------------------------------------------------
-- Changes

local function OnChanged()
    ClassCloset:RefreshWindow()
end

local function OnCollectionRuleChanged()
    ClassCloset:OnCollectionChanged()
end

local function ColorGet(tbl)
    return tbl.r, tbl.g, tbl.b
end

local function ColorSet(tbl, r, g, b)
    tbl.r, tbl.g, tbl.b = r, g, b
end

local function Get(info)
    return Options.db[info.arg]
end

local function Set(info, value)
    Options.db[info.arg] = value
    OnChanged()
end

---------------------------------------------------------
-- Options table

local function ClassValues()
    local values = {}
    for _, class in ipairs(Utils.Classes()) do
        values[class.file] = Utils.ClassIconMarkup(class.file, 16) .. " " .. Utils.ClassColorCode(class.file) .. class.name .. "|r"
    end
    return values
end

Options.options = {
    type = "group",
    name = L["CC.title"],
    childGroups = "tab",
    get = Get,
    set = Set,
    args = {
        open = {
            type = "execute",
            name = L["CC.options.open"],
            func = function()
                LibStub("AceConfigDialog-3.0"):Close(Options.APP_NAME)
                ClassCloset:ShowWindow()
            end,
            order = 1,
        },
        tab_general = {
            type = "group",
            name = L["CC.options.tab_general"],
            order = 10,
            args = {
                header_main = { type = "header", name = L["CC.options.header_main"], order = 1 },
                completed_scope = {
                    type = "select",
                    name = L["CC.options.completed_scope"],
                    desc = L["CC.options.completed_scope.desc"],
                    values = {
                        all = L["CC.list.completed_scope.all"],
                        lists = L["CC.list.completed_scope.lists"],
                    },
                    sorting = { "all", "lists" },
                    arg = "completed_scope",
                    set = function(_, value)
                        Options.db.completed_scope = value
                        CC_HomeUI.ResetScan()
                        OnChanged()
                    end,
                    order = 2,
                    width = "double",
                },
                header_picker = { type = "header", name = L["CC.options.header_picker"], order = 10 },
                picker_model = {
                    type = "toggle",
                    name = L["CC.options.picker_model"],
                    desc = L["CC.options.picker_model.desc"],
                    arg = "picker_model",
                    order = 11,
                    width = "full",
                },
                picker_class_sets_only = {
                    type = "toggle",
                    name = L["CC.options.picker_class_sets_only"],
                    desc = L["CC.options.picker_class_sets_only.desc"],
                    arg = "picker_class_sets_only",
                    order = 12,
                    width = "full",
                },
                picker_hide_complete = {
                    type = "toggle",
                    name = L["CC.options.picker_hide_complete"],
                    arg = "picker_hide_complete",
                    order = 13,
                    width = "full",
                },
                header_matrix = { type = "header", name = L["CC.options.header_matrix"], order = 20 },
                matrix_model = {
                    type = "toggle",
                    name = L["CC.options.matrix_model"],
                    desc = L["CC.options.matrix_model.desc"],
                    arg = "matrix_model",
                    order = 21,
                    width = "full",
                },
                show_tiers = {
                    type = "toggle",
                    name = L["CC.options.show_tiers"],
                    desc = L["CC.options.show_tiers.desc"],
                    arg = "show_tiers",
                    order = 22,
                    width = "full",
                },
                hide_complete_rows = {
                    type = "toggle",
                    name = L["CC.options.hide_complete_rows"],
                    arg = "hide_complete_rows",
                    order = 23,
                    width = "full",
                },
                icon_size = {
                    type = "range",
                    name = L["CC.options.icon_size"],
                    min = 18, max = 48, step = 1,
                    arg = "icon_size",
                    order = 24,
                },
                veil_alpha = {
                    type = "range",
                    name = L["CC.options.veil_alpha"],
                    desc = L["CC.options.veil_alpha.desc"],
                    min = 0, max = 1, step = 0.05, isPercent = true,
                    arg = "veil_alpha",
                    order = 25,
                },
                play_sound = {
                    type = "toggle",
                    name = L["CC.options.play_sound"],
                    arg = "play_sound",
                    order = 26,
                    width = "full",
                },
                header_glow = { type = "header", name = L["CC.options.header_glow"], order = 30 },
                glow_help = {
                    type = "description",
                    name = L["CC.options.glow.help"],
                    order = 31,
                },
                glow_enabled = {
                    type = "toggle",
                    name = L["CC.options.glow_enabled"],
                    arg = "glow_enabled",
                    order = 32,
                },
                glow_animated = {
                    type = "toggle",
                    name = L["CC.options.glow_animated"],
                    desc = L["CC.options.glow_animated.desc"],
                    arg = "glow_animated",
                    order = 33,
                    disabled = function() return not Options.db.glow_enabled end,
                },
                glow_day_color = {
                    type = "color",
                    name = L["CC.options.glow_day_color"],
                    order = 34,
                    get = function() return ColorGet(Options.db.glow_day_color) end,
                    set = function(_, r, g, b)
                        ColorSet(Options.db.glow_day_color, r, g, b)
                        OnChanged()
                    end,
                    disabled = function() return not Options.db.glow_enabled end,
                },
                glow_week_color = {
                    type = "color",
                    name = L["CC.options.glow_week_color"],
                    order = 35,
                    get = function() return ColorGet(Options.db.glow_week_color) end,
                    set = function(_, r, g, b)
                        ColorSet(Options.db.glow_week_color, r, g, b)
                        OnChanged()
                    end,
                    disabled = function() return not Options.db.glow_enabled end,
                },
                header_history = { type = "header", name = L["CC.options.header_history"], order = 40 },
                history_help = {
                    type = "description",
                    name = L["CC.options.history.help"],
                    order = 41,
                },
                history_max = {
                    type = "range",
                    name = L["CC.options.history_max"],
                    desc = L["CC.options.history_max.desc"],
                    min = 10, max = 2000, softMax = 1000, step = 10,
                    order = 42,
                    get = function() return ClassCloset.db.global.history_max end,
                    set = function(_, value)
                        ClassCloset.db.global.history_max = value
                        CC_History.Trim()
                        OnChanged()
                    end,
                },
                history_new_only = {
                    type = "toggle",
                    name = L["CC.options.history_new_only"],
                    desc = L["CC.options.history_new_only.desc"],
                    order = 43,
                    width = "full",
                    get = function() return ClassCloset.db.global.history_new_only end,
                    set = function(_, value)
                        ClassCloset.db.global.history_new_only = value
                    end,
                },
            },
        },
        tab_classes = {
            type = "group",
            name = L["CC.options.tab_classes"],
            order = 20,
            args = {
                help = {
                    type = "description",
                    name = L["CC.options.classes.help"],
                    fontSize = "medium",
                    order = 0,
                },
                shown = {
                    type = "multiselect",
                    name = L["CC.options.classes.shown"],
                    values = ClassValues,
                    get = function(_, key)
                        return Options.IsClassShown(key)
                    end,
                    set = function(_, key, value)
                        Options.db.hidden_classes[key] = (not value) or nil
                        OnCollectionRuleChanged()
                    end,
                    order = 1,
                },
            },
        },
    },
}
