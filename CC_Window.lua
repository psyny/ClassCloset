-- CC_Window.lua
-- The ClassCloset window: movable, resizable, closes with Escape.
-- It shows one page at a time: home, set lists (Configure) or a set table.
CC_Window = {}

local Window = CC_Window
local Options = CC_Options
local Widgets = CC_Widgets

local L = LibStub("AceLocale-3.0"):GetLocale("ClassCloset", false)

local DEFAULT_WIDTH, DEFAULT_HEIGHT = 1000, 600
local MIN_WIDTH, MIN_HEIGHT = 820, 420
local PADDING = 14

local frame
local pages = {}
local current = nil  -- { name, arg }
local history = {}   -- previous pages, for the Back button

local BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 26,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
}

local function SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    ClassCloset.db.global.window = {
        point = point, relPoint = relPoint, x = x, y = y,
        width = frame:GetWidth(), height = frame:GetHeight(),
    }
end

local function RestorePosition()
    local saved = ClassCloset.db.global.window
    frame:ClearAllPoints()
    if saved and saved.point then
        frame:SetPoint(saved.point, UIParent, saved.relPoint or saved.point, saved.x or 0, saved.y or 0)
        frame:SetSize(math.max(MIN_WIDTH, saved.width or DEFAULT_WIDTH), math.max(MIN_HEIGHT, saved.height or DEFAULT_HEIGHT))
    else
        frame:SetPoint("CENTER")
        frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    end
end

local function Create()
    frame = CreateFrame("Frame", "ClassClosetFrame", UIParent, "BackdropTemplate")
    frame:SetBackdrop(BACKDROP)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT)
    end
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    frame:Hide()
    tinsert(UISpecialFrames, "ClassClosetFrame") -- Escape closes it

    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -16)
    frame.title:SetText(L["CC.title"])

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    frame.back = Widgets.Button(frame, L["CC.window.back"], 80, 22, function()
        Window.Back()
    end)
    frame.back:SetPoint("TOPLEFT", PADDING, -12)

    frame.home = Widgets.Button(frame, L["CC.window.home"], 80, 22, function()
        wipe(history)
        Window.ShowPage("home")
    end)
    frame.home:SetPoint("LEFT", frame.back, "RIGHT", 4, 0)

    frame.options = Widgets.Button(frame, L["CC.window.options"], 80, 22, function()
        Options.Open()
    end)
    frame.options:SetPoint("TOPRIGHT", -36, -12)

    frame.profile = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.profile:SetPoint("RIGHT", frame.options, "LEFT", -10, 0)

    -- Pages area
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", PADDING, -44)
    body:SetPoint("BOTTOMRIGHT", -PADDING, PADDING + 4)
    frame.body = body

    pages.home = CC_HomeUI.Create(body)
    pages.picker = CC_PickerUI.Create(body)
    pages.matrix = CC_MatrixUI.Create(body)
    pages.newest = CC_NewestUI.Create(body)
    for _, page in pairs(pages) do
        page:Hide()
    end

    -- Resize grip
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -6, 6)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        SavePosition()
        Window.Refresh()
    end)

    frame:SetScript("OnShow", function()
        if Options.db.play_sound and SOUNDKIT then
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        end
    end)
    frame:SetScript("OnHide", function()
        if Options.db.play_sound and SOUNDKIT then
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        end
    end)

    RestorePosition()
end

function Window.Frame()
    if not frame then
        Create()
    end
    return frame
end

function Window.IsShown()
    return frame ~= nil and frame:IsShown()
end

function Window.Show()
    Window.Frame():Show()
    if not current then
        Window.ShowPage("home")
    else
        Window.Refresh()
    end
end

function Window.Toggle()
    if Window.IsShown() then
        frame:Hide()
    else
        Window.Show()
    end
end

local function Display(name, arg)
    for key, page in pairs(pages) do
        page:SetShown(key == name)
    end
    current = { name = name, arg = arg }
    Window.Refresh()
end

-- Opens a page; the page we leave goes to the Back history.
function Window.ShowPage(name, arg)
    Window.Frame():Show()
    if current and (current.name ~= name or current.arg ~= arg) then
        history[#history + 1] = current
    end
    if name == "home" then
        wipe(history)
    end
    Display(name, arg)
end

function Window.Back()
    local previous = table.remove(history)
    Display(previous and previous.name or "home", previous and previous.arg)
end

function Window.OpenPicker(kind)
    Window.ShowPage("picker", kind)
end

function Window.OpenNewest()
    Window.ShowPage("newest")
end

function Window.OpenMatrix(key)
    Window.ShowPage("matrix", key)
end

-- Redraws the page on screen.
function Window.Refresh()
    if not Window.IsShown() or not current then
        return
    end
    frame.back:SetEnabled(current.name ~= "home")
    frame.home:SetEnabled(current.name ~= "home")
    frame.profile:SetText(format(L["CC.window.profile"], ClassCloset.db:GetCurrentProfile()))
    if current.name == "home" then
        CC_HomeUI.Refresh()
    elseif current.name == "picker" then
        CC_PickerUI.Show(current.arg)
    elseif current.name == "newest" then
        CC_NewestUI.Refresh()
    elseif current.name == "matrix" then
        CC_MatrixUI.Show(current.arg)
    end
end
