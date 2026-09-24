--[[
    WoWKillboard - UI.lua
    In-game graphical dashboard modeled after EVE Online's zKillboard.com.
    Features:
    - Dark Tactical Glassmorphic Theme with clean 1px gunmetal borders.
    - Real-time KPI Stat Cards Header (K/D, Duels W/L, BGs W/L, Arenas W/L).
    - Dynamic 5-Way Mode Filter Pills (All PvP, World, BGs, Arenas, Duels) with active glow states.
    - Embedded High-Resolution Blizzard Class Icons on combatants.
    - Left-edge colored engagement accent bars (Gold = Duel, Purple = Arena, Cyan = BG, Green = Solo, Orange = Gang).
    - Alternating Zebra Striping and smooth row hover highlights.
    - Split Dossier Killmail Detail Modal with dual combatant cards.
    - 100% Template-Free & Secure: Zero UIPanel templates, zero UISpecialFrames,
      zero anonymous frame churning, zero combat lockdown taint.
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard
KB.UI = {}
local UI = KB.UI

local mainFrame = nil
local activeTab = "FEED"   -- "FEED", "LEADERBOARD", "BOUNTIES", "BG_METRICS", "ZONES"
local currentMode = "ALL"  -- "ALL", "WORLD", "BG", "ARENA", "DUEL"

local tabButtons = {}
local filterButtons = {}

-- Standard Blizzard Class Coordinates (safe fallback for all WoW versions)
local CLASS_ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local CLASS_COORDS = CLASS_ICON_TCOORDS or {
    WARRIOR     = {0, 0.25, 0, 0.25},
    MAGE        = {0.25, 0.49609375, 0, 0.25},
    ROGUE       = {0.49609375, 0.7421875, 0, 0.25},
    DRUID       = {0.7421875, 0.98828125, 0, 0.25},
    HUNTER      = {0, 0.25, 0.25, 0.5},
    SHAMAN      = {0.25, 0.49609375, 0.25, 0.5},
    PRIEST      = {0.49609375, 0.7421875, 0.25, 0.5},
    WARLOCK     = {0.7421875, 0.98828125, 0.25, 0.5},
    PALADIN     = {0, 0.25, 0.5, 0.75},
    DEATHKNIGHT = {0.25, 0.49609375, 0.5, 0.75},
    MONK        = {0.49609375, 0.7421875, 0.5, 0.75},
    DEMONHUNTER = {0.7421875, 0.98828125, 0.5, 0.75},
    EVOKER      = {0, 0.25, 0.75, 1.0},
}

-- Theme Engine: Classic WoW UI vs ElvUI Minimalist
function UI:GetCurrentThemeName()
    if WoWKillboardSettings and WoWKillboardSettings.theme then
        local t = WoWKillboardSettings.theme:lower()
        if KB.Themes and KB.Themes[t] then return t end
    end
    return "elvui"
end

function UI:GetTheme()
    local name = UI:GetCurrentThemeName()
    return (KB.Themes and KB.Themes[name]) or (KB.Themes and KB.Themes["elvui"]) or {}
end

function UI:SetTheme(themeName)
    themeName = (themeName or ""):lower()
    if not KB.Themes or not KB.Themes[themeName] then
        print(string.format("|cffff9900[WoWKB]|r Unknown theme '%s'. Available: 'classic', 'elvui'.", tostring(themeName)))
        return
    end

    WoWKillboardSettings = WoWKillboardSettings or {}
    WoWKillboardSettings.theme = themeName

    UI:ApplyTheme()
    if mainFrame and mainFrame:IsShown() then
        UI:Refresh()
    end

    local th = KB.Themes[themeName]
    print(string.format("|cff00ccff[WoWKB]|r Theme switched to: |cffffd100%s|r", th.name))
end

function UI:ApplyTheme()
    if not mainFrame then return end
    local theme = UI:GetTheme()
    if not theme or not theme.mainBackdrop then return end

    mainFrame:SetBackdrop(theme.mainBackdrop)
    mainFrame:SetBackdropColor(unpack(theme.mainBg))
    mainFrame:SetBackdropBorderColor(unpack(theme.mainBorder))

    if UI.TitleText then
        UI.TitleText:SetText(theme.titleText)
    end
    if UI.SubtitleText then
        UI.SubtitleText:SetText(string.format(theme.subtitleText, KB.Version))
    end
    if UI.ThemeButton and UI.ThemeButton.Label then
        UI.ThemeButton:SetBackdrop(theme.btnBackdrop)
        UI.ThemeButton:SetBackdropColor(unpack(theme.btnBg))
        UI.ThemeButton:SetBackdropBorderColor(unpack(theme.btnBorder))
        UI.ThemeButton.Label:SetText(theme.themeBtnText)
    end
    if UI.CloseButton then
        UI.CloseButton:SetBackdrop(theme.btnBackdrop)
    end
    if UI.Divider then
        UI.Divider:SetColorTexture(unpack(theme.dividerColor))
    end
    if UI.StatCards then
        for _, card in pairs(UI.StatCards) do
            card:SetBackdrop(theme.cardBackdrop)
            card:SetBackdropColor(unpack(theme.cardBg))
            card:SetBackdropBorderColor(unpack(theme.cardBorder))
        end
    end
    if UI.DetailModal then
        UI.DetailModal:SetBackdrop(theme.modalBackdrop)
        UI.DetailModal:SetBackdropColor(unpack(theme.modalBg))
        UI.DetailModal:SetBackdropBorderColor(unpack(theme.modalBorder))
    end
end

-- Standalone Tactical Button (Zero UIPanelButtonTemplate or sound XML taint)
function UI:CreateButton(parent, w, h, text, fontSize)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w, h)
    local theme = UI:GetTheme()
    if theme and theme.btnBackdrop then
        btn:SetBackdrop(theme.btnBackdrop)
        btn:SetBackdropColor(unpack(theme.btnBg))
        btn:SetBackdropBorderColor(unpack(theme.btnBorder))
    end

    local label = btn:CreateFontString(nil, "OVERLAY", fontSize or "GameFontHighlightSmall")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text or "")
    btn.Label = label

    btn:SetScript("OnEnter", function(self)
        if not self.isActive then
            local t = UI:GetTheme()
            if t and t.btnHoverBg then
                self:SetBackdropColor(unpack(t.btnHoverBg))
                self:SetBackdropBorderColor(unpack(t.btnHoverBorder))
            end
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if not self.isActive then
            local t = UI:GetTheme()
            if t and t.btnBg then
                self:SetBackdropColor(unpack(t.btnBg))
                self:SetBackdropBorderColor(unpack(t.btnBorder))
            end
        end
    end)

    return btn
end

-- Helper: Create a Class Icon Texture
function UI:CreateClassIcon(parent, classFilename, size)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetSize(size or 18, size or 18)
    tex:SetTexture(CLASS_ICON_TEXTURE)
    local coords = CLASS_COORDS[(classFilename or ""):upper()] or {0, 0.25, 0, 0.25}
    tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    return tex
end

-- Create or show main window
function UI:Toggle()
    if InCombatLockdown() then
        print("|cffff9900[WoWKB]|r Cannot toggle Killboard during combat.")
        return
    end

    if not mainFrame then
        UI:CreateMainWindow()
    end

    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        UI:Refresh()
    end
end

function UI:RefreshIfVisible()
    if mainFrame and mainFrame:IsShown() and not InCombatLockdown() then
        UI:Refresh()
    end
end

-- Construct the main frame
function UI:CreateMainWindow()
    if mainFrame then return end

    -- Anonymous frame to prevent Blizzard AccountData UI_LAYOUT tracking
    mainFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    mainFrame:SetSize(860, 560)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    mainFrame:SetClampedToScreen(true)

    -- Custom ESC key handling (100% taint-free, zero UISpecialFrames global pollution)
    mainFrame:EnableKeyboard(true)
    mainFrame:SetPropagateKeyboardInput(true)
    mainFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    -- Modern Dark Gunmetal Framing (1px razor border)
    mainFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    mainFrame:SetBackdropColor(0.06, 0.07, 0.10, 0.97)
    mainFrame:SetBackdropBorderColor(0.18, 0.22, 0.28, 1.0)

    -- Window Title Header
    local titleIcon = mainFrame:CreateTexture(nil, "OVERLAY")
    titleIcon:SetSize(18, 18)
    titleIcon:SetPoint("TOPLEFT", 14, -12)
    titleIcon:SetTexture("Interface\\Icons\\Achievement_PVP_P_01")

    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", titleIcon, "RIGHT", 8, 0)
    title:SetText("|cff00e5ffWoW Killboard|r |cffffd100[zKillboard]|r")
    UI.TitleText = title

    local subtitle = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("LEFT", title, "RIGHT", 10, 0)
    subtitle:SetText("|cff64748bv" .. KB.Version .. " | PvP Intelligence & Telemetry|r")
    UI.SubtitleText = subtitle

    -- Template-Free Close Button
    local closeBtn = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -10, -10)
    closeBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    closeBtn:SetBackdropColor(0.15, 0.08, 0.08, 0.9)
    closeBtn:SetBackdropBorderColor(0.35, 0.15, 0.15, 0.9)

    local closeLabel = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeLabel:SetPoint("CENTER", 0, 0)
    closeLabel:SetText("|cffff5555✕|r")
    closeBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.35, 0.10, 0.10, 1.0)
        self:SetBackdropBorderColor(1.0, 0.2, 0.2, 1.0)
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.08, 0.08, 0.9)
        self:SetBackdropBorderColor(0.35, 0.15, 0.15, 0.9)
    end)
    closeBtn:SetScript("OnClick", function()
        mainFrame:Hide()
    end)
    UI.CloseButton = closeBtn

    -- Template-Free Theme Switcher Button
    local themeBtn = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
    themeBtn:SetSize(108, 20)
    themeBtn:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)
    local themeLabel = themeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    themeLabel:SetPoint("CENTER", 0, 0)
    themeBtn.Label = themeLabel
    themeBtn:SetScript("OnClick", function()
        local cur = UI:GetCurrentThemeName()
        local nextTheme = (cur == "elvui") and "classic" or "elvui"
        UI:SetTheme(nextTheme)
    end)
    themeBtn:SetScript("OnEnter", function(self)
        local t = UI:GetTheme()
        if t and t.btnHoverBg then
            self:SetBackdropColor(unpack(t.btnHoverBg))
            self:SetBackdropBorderColor(unpack(t.btnHoverBorder))
        end
    end)
    themeBtn:SetScript("OnLeave", function(self)
        local t = UI:GetTheme()
        if t and t.btnBg then
            self:SetBackdropColor(unpack(t.btnBg))
            self:SetBackdropBorderColor(unpack(t.btnBorder))
        end
    end)
    UI.ThemeButton = themeBtn

    -- 3 KPI Tactical Header Stat Cards (K/D, Duels, Battlegrounds) - Clean & Balanced
    local cardConfigs = {
        { id = "KD",    title = "SESSION COMBAT K/D",   color = "00e5ff", w = 268 },
        { id = "DUELS", title = "1v1 DUELS RECORD",     color = "ffd700", w = 268 },
        { id = "BGS",   title = "BATTLEGROUNDS RECORD", color = "00ccff", w = 268 },
    }

    UI.StatCards = {}
    local prevCard = nil
    for _, cfg in ipairs(cardConfigs) do
        local card = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
        card:SetSize(cfg.w, 36)
        if not prevCard then
            card:SetPoint("TOPLEFT", 14, -36)
        else
            card:SetPoint("LEFT", prevCard, "RIGHT", 14, 0)
        end
        card:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        card:SetBackdropColor(0.08, 0.10, 0.14, 0.95)
        card:SetBackdropBorderColor(0.16, 0.20, 0.28, 0.8)

        local topLabel = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        topLabel:SetPoint("TOPLEFT", 8, -4)
        topLabel:SetText(string.format("|cff%s%s|r", cfg.color, cfg.title))

        local valLabel = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        valLabel:SetPoint("BOTTOMLEFT", 8, 4)
        valLabel:SetText("0 / 0")
        card.ValueLabel = valLabel

        UI.StatCards[cfg.id] = card
        prevCard = card
    end

    -- 1px Dividing Rule
    local divider = mainFrame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 14, -80)
    divider:SetPoint("TOPRIGHT", -14, -80)
    divider:SetHeight(1)
    divider:SetColorTexture(0.16, 0.20, 0.28, 0.8)
    UI.Divider = divider

    -- Navigation Bar (Tabs on Left, Filter Pills on Right - Zero Overlap)
    local tabs = {
        { id = "FEED",        text = "Live Feed",       w = 95 },
        { id = "LEADERBOARD", text = "Leaderboards",    w = 105 },
        { id = "BOUNTIES",    text = "Bounties & Debt", w = 110 },
        { id = "BG_METRICS",  text = "BG Gladiators",   w = 100 },
        { id = "ZONES",       text = "Zone Intel",      w = 88 },
    }

    tabButtons = {}
    local prevTab = nil
    for _, t in ipairs(tabs) do
        local btn = UI:CreateButton(mainFrame, t.w, 24, t.text, "GameFontHighlightSmall")
        if not prevTab then
            btn:SetPoint("TOPLEFT", 14, -88)
        else
            btn:SetPoint("LEFT", prevTab, "RIGHT", 4, 0)
        end
        local tabId = t.id
        btn:SetScript("OnClick", function()
            activeTab = tabId
            UI:Refresh()
        end)
        tabButtons[t.id] = btn
        prevTab = btn
    end

    -- 4-Way Mode Filter Pills (Duels | BGs | World | All PvP - Arenas Removed for Vanilla/Forever)
    local filterConfigs = {
        { id = "DUEL",  text = "Duels",   w = 54, color = {1.0, 0.84, 0.0} },
        { id = "BG",    text = "BGs",     w = 50, color = {0.0, 0.8, 1.0} },
        { id = "WORLD", text = "World",   w = 56, color = {0.0, 0.9, 0.4} },
        { id = "ALL",   text = "All PvP", w = 62, color = {0.0, 0.9, 1.0} },
    }

    filterButtons = {}
    local prevPill = nil
    for _, f in ipairs(filterConfigs) do
        local pill = UI:CreateButton(mainFrame, f.w, 22, f.text, "GameFontHighlightSmall")
        if not prevPill then
            pill:SetPoint("TOPRIGHT", -14, -89)
        else
            pill:SetPoint("RIGHT", prevPill, "LEFT", -4, 0)
        end
        local modeId = f.id
        pill:SetScript("OnClick", function()
            currentMode = modeId
            UI:Refresh()
        end)
        pill.BaseColor = f.color
        filterButtons[f.id] = pill
        prevPill = pill
    end

    -- Scroll Area Container
    local container = CreateFrame("ScrollFrame", nil, mainFrame)
    container:SetPoint("TOPLEFT", 14, -120)
    container:SetPoint("BOTTOMRIGHT", -16, 14)
    container:EnableMouseWheel(true)
    container:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = math.max(0, (UI.ContentFrame:GetHeight() or 400) - self:GetHeight())
        local newScroll = math.max(0, math.min(maxScroll, current - (delta * 36)))
        self:SetVerticalScroll(newScroll)
    end)

    local content = CreateFrame("Frame", nil, container)
    content:SetSize(826, 400)
    container:SetScrollChild(content)
    UI.ContentFrame = content
    UI.ScrollContainer = container

    -- Detail Modal Frame
    UI:CreateDetailModal()

    UI:ApplyTheme()
    mainFrame:Hide()
end

-- Refresh UI content based on activeTab and currentMode
function UI:Refresh()
    if not UI.ContentFrame or InCombatLockdown() then return end
    KB.Leaderboard:Rebuild()

    -- Update KPI Header Cards
    local s = KB.CombatTracker.SessionStats
    local st = WoWKillboardDB and WoWKillboardDB.stats or {}
    local dW = st.duels and st.duels.wins or 0
    local dL = st.duels and st.duels.losses or 0
    local dTot = dW + dL
    local dRate = dTot > 0 and math.floor((dW / dTot) * 100) or 0

    local bgW = st.bgs and st.bgs.wins or 0
    local bgL = st.bgs and st.bgs.losses or 0
    local bgTot = bgW + bgL
    local bgRate = bgTot > 0 and math.floor((bgW / bgTot) * 100) or 0

    local kd = (s.deaths > 0) and string.format("%.2f", s.kills / s.deaths) or tostring(s.kills)

    if UI.StatCards then
        if UI.StatCards.KD and UI.StatCards.KD.ValueLabel then
            UI.StatCards.KD.ValueLabel:SetText(string.format("|cffffffff%d|r K  |cff64748b/|r  |cffff4444%d|r D  (|cff00ff66%s|r)", s.kills, s.deaths, kd))
        end
        if UI.StatCards.DUELS and UI.StatCards.DUELS.ValueLabel then
            UI.StatCards.DUELS.ValueLabel:SetText(string.format("|cffffffff%d|rW - |cffff4444%d|rL  (|cffffd700%d%%|r)", dW, dL, dRate))
        end
        if UI.StatCards.BGS and UI.StatCards.BGS.ValueLabel then
            UI.StatCards.BGS.ValueLabel:SetText(string.format("|cffffffff%d|rW - |cffff4444%d|rL  (|cff00ccff%d%%|r)", bgW, bgL, bgRate))
        end
    end

    local theme = UI:GetTheme()

    -- Update Tab Button Highlights
    for tid, btn in pairs(tabButtons) do
        if theme.btnBackdrop then btn:SetBackdrop(theme.btnBackdrop) end
        if tid == activeTab then
            btn.isActive = true
            btn:SetBackdropColor(unpack(theme.btnActiveBg))
            btn:SetBackdropBorderColor(unpack(theme.btnActiveBorder))
            local activeColor = (theme.id == "classic") and "|cffffd100" or "|cff00ffff"
            btn.Label:SetText(activeColor .. btn.Label:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "|r")
        else
            btn.isActive = false
            btn:SetBackdropColor(unpack(theme.btnBg))
            btn:SetBackdropBorderColor(unpack(theme.btnBorder))
            local normalColor = (theme.id == "classic") and "|cffd0c0a0" or "|cff94a3b8"
            btn.Label:SetText(normalColor .. btn.Label:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "|r")
        end
    end

    -- Update Filter Pill Active Glow
    for fid, pill in pairs(filterButtons) do
        if theme.btnBackdrop then pill:SetBackdrop(theme.btnBackdrop) end
        local c = pill.BaseColor or {0, 0.8, 1}
        if fid == currentMode then
            pill.isActive = true
            pill:SetBackdropColor(c[1] * 0.35, c[2] * 0.35, c[3] * 0.35, 1.0)
            pill:SetBackdropBorderColor(c[1], c[2], c[3], 1.0)
            pill.Label:SetText(string.format("|cff%02x%02x%02x%s|r", math.floor(c[1]*255), math.floor(c[2]*255), math.floor(c[3]*255), pill.Label:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
        else
            pill.isActive = false
            pill:SetBackdropColor(unpack(theme.btnBg))
            pill:SetBackdropBorderColor(unpack(theme.btnBorder))
            local pillNormal = (theme.id == "classic") and "|cffa09080" or "|cff64748b"
            pill.Label:SetText(pillNormal .. pill.Label:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "|r")
        end
    end

    if UI.ScrollContainer then
        UI.ScrollContainer:SetVerticalScroll(0)
    end

    -- Clear previous rows safely
    local children = { UI.ContentFrame:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
    end
    local regions = { UI.ContentFrame:GetRegions() }
    for _, region in ipairs(regions) do
        region:Hide()
    end

    if activeTab == "FEED" then
        UI:RenderLiveFeed()
    elseif activeTab == "LEADERBOARD" then
        UI:RenderLeaderboard()
    elseif activeTab == "BOUNTIES" then
        UI:RenderBounties()
    elseif activeTab == "BG_METRICS" then
        UI:RenderBGMetrics()
    elseif activeTab == "ZONES" then
        UI:RenderZones()
    end
end

-- 1. Render Live Killmail Feed
function UI:RenderLiveFeed()
    local kills = KB.Leaderboard:GetRecentKills(currentMode, 40)
    local yOffset = 0

    if #kills == 0 then
        if not UI.EmptyFeedText then
            UI.EmptyFeedText = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            UI.EmptyFeedText:SetPoint("TOP", 0, -40)
        end
        UI.EmptyFeedText:SetText(string.format("|cff94a3b8No PvP kill records under mode:|r |cff00e5ff[%s]|r\n|cff64748bEngage in world PvP, 1v1 duels, or battlegrounds to populate the feed.|r", currentMode))
        UI.EmptyFeedText:Show()
        return
    elseif UI.EmptyFeedText then
        UI.EmptyFeedText:Hide()
    end

    for idx, km in ipairs(kills) do
        local row = CreateFrame("Button", nil, UI.ContentFrame, "BackdropTemplate")
        row:SetSize(820, 36)
        row:SetPoint("TOPLEFT", 0, yOffset)
        local theme = UI:GetTheme()
        local isEven = (idx % 2 == 0)
        local baseBg = isEven and theme.rowBgAlt or theme.rowBg
        row:SetBackdrop(theme.rowBackdrop)
        row:SetBackdropColor(unpack(baseBg))
        row:SetBackdropBorderColor(unpack(theme.rowBorder))

        -- Left Accent Bar (Colored by engagement category)
        local accent = row:CreateTexture(nil, "ARTWORK")
        accent:SetPoint("TOPLEFT", 0, 0)
        accent:SetPoint("BOTTOMLEFT", 0, 0)
        accent:SetWidth(4)

        local badgeStr = ""
        if km.isDuel then
            accent:SetColorTexture(1.0, 0.84, 0.0, 1.0) -- Gold
            badgeStr = "|cffffd700[DUEL]|r"
        elseif km.isBattleground then
            accent:SetColorTexture(0.0, 0.8, 1.0, 1.0) -- Cyan
            badgeStr = string.format("|cff00ccff[BG x%d]|r", km.attackersCount or 1)
        elseif km.isSolo then
            accent:SetColorTexture(0.0, 1.0, 0.4, 1.0) -- Emerald
            badgeStr = "|cff00ff66[SOLO]|r"
        else
            accent:SetColorTexture(1.0, 0.6, 0.0, 1.0) -- Orange
            badgeStr = string.format("|cffffaa00[GANG x%d]|r", km.attackersCount or 1)
        end

        -- Category Badge
        local badgeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        badgeText:SetPoint("LEFT", 12, 0)
        badgeText:SetText(badgeStr)

        -- Killer Class Icon
        local kIcon = UI:CreateClassIcon(row, km.killer.class, 20)
        kIcon:SetPoint("LEFT", 78, 0)

        -- Killer Level Pill
        local kLvl = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        kLvl:SetPoint("LEFT", kIcon, "RIGHT", 4, 0)
        kLvl:SetText(string.format("|cff94a3b8%d|r", km.killer.level or 0))

        -- Killer Name & Guild
        local killerStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        killerStr:SetPoint("LEFT", kLvl, "RIGHT", 5, 0)
        local kGuildStr = (km.killer.guild and km.killer.guild ~= "None") and string.format(" |cff64748b<%s>|r", km.killer.guild) or ""
        killerStr:SetText(KB.Utils.ColorizeByClass(km.killer.name, km.killer.class) .. kGuildStr)

        -- Action Verb Separator (Center)
        local actionVerb = km.isDuel and "defeated" or "destroyed"
        local sep = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        sep:SetPoint("LEFT", 330, 0)
        sep:SetText(string.format("|cff64748b%s|r", actionVerb))

        -- Victim Class Icon
        local vIcon = UI:CreateClassIcon(row, km.victim.class, 20)
        vIcon:SetPoint("LEFT", 390, 0)

        -- Victim Level Pill
        local vLvl = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        vLvl:SetPoint("LEFT", vIcon, "RIGHT", 4, 0)
        vLvl:SetText(string.format("|cff94a3b8%d|r", km.victim.level or 0))

        -- Victim Name & Guild
        local victimStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        victimStr:SetPoint("LEFT", vLvl, "RIGHT", 5, 0)
        local vGuildStr = (km.victim.guild and km.victim.guild ~= "None") and string.format(" |cff64748b<%s>|r", km.victim.guild) or ""
        victimStr:SetText(KB.Utils.ColorizeByClass(km.victim.name, km.victim.class) .. vGuildStr)

        -- Location & Timestamp (Right-Aligned)
        local infoStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        infoStr:SetPoint("RIGHT", -12, 0)
        local locName = km.isBattleground and (km.battlegroundName or "Battleground") or km.location.zone
        infoStr:SetText(string.format("|cffcbd5e1%s|r  |cff64748b• %s|r", locName, KB.Utils.FormatTimeAgo(km.timestamp)))

        -- Interactive Hover
        row:SetScript("OnEnter", function(self)
            local t = UI:GetTheme()
            if t and t.btnHoverBg then
                self:SetBackdropColor(unpack(t.btnHoverBg))
                self:SetBackdropBorderColor(unpack(t.btnHoverBorder))
            end
        end)
        row:SetScript("OnLeave", function(self)
            local t = UI:GetTheme()
            self:SetBackdropColor(unpack(baseBg))
            if t and t.rowBorder then
                self:SetBackdropBorderColor(unpack(t.rowBorder))
            end
        end)

        -- Click handler to open killmail detail
        local targetKM = km
        row:SetScript("OnClick", function()
            UI:ShowKillDetail(targetKM)
        end)

        yOffset = yOffset - 40
    end

    UI.ContentFrame:SetHeight(math.abs(yOffset) + 20)
end

-- 2. Render Leaderboard Tab
function UI:RenderLeaderboard()
    local topKillers = KB.Leaderboard:GetTopKillers(currentMode, 15)

    local header = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 10, -10)
    header:SetText(string.format("Top PvP Assassins & Solo Kings — Mode: |cff00e5ff[%s]|r", currentMode))

    local yOffset = -40
    for rank, p in ipairs(topKillers) do
        local row = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
        row:SetSize(820, 30)
        row:SetPoint("TOPLEFT", 0, yOffset)
        local theme = UI:GetTheme()
        local isEven = (rank % 2 == 0)
        local baseBg = isEven and theme.rowBgAlt or theme.rowBg
        row:SetBackdrop(theme.rowBackdrop)
        row:SetBackdropColor(unpack(baseBg))
        row:SetBackdropBorderColor(unpack(theme.rowBorder))

        -- Rank Medal Color
        local rankColor = (rank == 1 and "ffd700") or (rank == 2 and "c0c0c0") or (rank == 3 and "cd7f32") or "8899aa"
        local rankText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rankText:SetPoint("LEFT", 12, 0)
        rankText:SetText(string.format("|cff%s#%d|r", rankColor, rank))

        local pIcon = UI:CreateClassIcon(row, p.class, 20)
        pIcon:SetPoint("LEFT", rankText, "RIGHT", 10, 0)

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameText:SetPoint("LEFT", pIcon, "RIGHT", 8, 0)
        local guildStr = (p.guild and p.guild ~= "None") and string.format("  |cff64748b<%s>|r", p.guild) or ""
        nameText:SetText(KB.Utils.ColorizeByClass(p.name, p.class) .. guildStr)

        local statsText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statsText:SetPoint("RIGHT", -15, 0)
        local kd = (p.deaths > 0) and string.format("%.2f", p.kills / p.deaths) or tostring(p.kills)
        statsText:SetText(string.format("|cff00ff66%d Kills|r  |  |cff00e5ff%d Solo|r  |  |cffff4444%d Deaths|r  |  K/D: |cffffd100%s|r",
            p.kills, p.soloKills, p.deaths, kd))

        yOffset = yOffset - 34
    end

    UI.ContentFrame:SetHeight(math.abs(yOffset) + 30)
end

-- 3. Render Bounties & Debt Ledger (Wall of Shame)
function UI:RenderBounties()
    local yOffset = -10

    local bntTitle = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    bntTitle:SetPoint("TOPLEFT", 10, yOffset)
    bntTitle:SetText("Active Bounty Contracts")

    -- Place Bounty Button
    local placeBtn = UI:CreateButton(UI.ContentFrame, 140, 24, "+ Place Bounty")
    placeBtn:SetPoint("TOPRIGHT", -20, yOffset)
    placeBtn:SetScript("OnClick", function()
        UI:ShowBountyPrompt()
    end)

    yOffset = yOffset - 36

    WoWKillboardBounties = WoWKillboardBounties or {}
    local hasBounties = false
    for _, b in pairs(WoWKillboardBounties) do
        if b.status == KB.STATUS.ACTIVE then
            hasBounties = true
            local row = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
            row:SetSize(820, 32)
            row:SetPoint("TOPLEFT", 0, yOffset)
            local theme = UI:GetTheme()
            row:SetBackdrop(theme.rowBackdrop)
            row:SetBackdropColor(0.18, 0.08, 0.08, 0.9)
            row:SetBackdropBorderColor(0.50, 0.18, 0.18, 0.8)

            local icon = UI:CreateClassIcon(row, b.targetClass, 20)
            icon:SetPoint("LEFT", 12, 0)

            local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            txt:SetPoint("LEFT", icon, "RIGHT", 8, 0)
            txt:SetText(string.format("WANTED: |cffff3333%s|r (%s)  |  Reward: |cffffd700%s|r  |  Placed by: |cffcbd5e1%s|r",
                b.targetName, b.targetClass, KB.Utils.FormatMoney(b.amountCopper), b.placerName))

            yOffset = yOffset - 36
        end
    end

    if not hasBounties then
        local emptyB = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        emptyB:SetPoint("TOPLEFT", 10, yOffset)
        emptyB:SetText("No active bounties. Be the first to place one on an enemy!")
        yOffset = yOffset - 25
    end

    -- Wall of Shame (Oathbreaker Debt Ledger)
    yOffset = yOffset - 24
    local debtTitle = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    debtTitle:SetPoint("TOPLEFT", 10, yOffset)
    debtTitle:SetText("⚠️ Wall of Shame — Oathbreakers in Default")

    yOffset = yOffset - 36
    WoWKillboardDebtLedger = WoWKillboardDebtLedger or {}
    local hasDebts = false

    for playerName, debt in pairs(WoWKillboardDebtLedger) do
        if debt.status == KB.STATUS.OATHBREAKER then
            hasDebts = true
            local row = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
            row:SetSize(820, 36)
            row:SetPoint("TOPLEFT", 0, yOffset)
            local theme = UI:GetTheme()
            row:SetBackdrop(theme.rowBackdrop)
            row:SetBackdropColor(0.24, 0.06, 0.06, 0.92)
            row:SetBackdropBorderColor(0.60, 0.15, 0.15, 0.9)

            local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            txt:SetPoint("LEFT", 14, 0)
            txt:SetText(string.format("|cffff2222[OATHBREAKER]|r |cffffffff%s|r owes |cffffd700%s|r to %s (%d days unpaid)",
                playerName, KB.Utils.FormatMoney(debt.amountOwedCopper), debt.creditor, debt.daysInDefault or 1))

            -- If player is the debtor, show redemption button
            if playerName == UnitName("player") then
                local payBtn = UI:CreateButton(row, 120, 24, "Pay Off Debt")
                payBtn:SetPoint("RIGHT", -10, 0)
                local pName = playerName
                payBtn:SetScript("OnClick", function()
                    KB.BountyEngine:PayOffDebt(pName)
                end)
            end

            yOffset = yOffset - 40
        end
    end

    if not hasDebts then
        local emptyD = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        emptyD:SetPoint("TOPLEFT", 10, yOffset)
        emptyD:SetText("No players currently in default. The realm's honor is intact.")
        yOffset = yOffset - 25
    end

    UI.ContentFrame:SetHeight(math.abs(yOffset) + 30)
end

-- 4. Render Battleground Gladiator Telemetry
function UI:RenderBGMetrics()
    local gladiators = KB.Leaderboard:GetBattlegroundGladiators(15)
    local yOffset = -10

    local title = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, yOffset)
    title:SetText("Battleground Gladiators — Damage, Healing, and Efficiency")

    yOffset = yOffset - 40
    for rank, g in ipairs(gladiators) do
        local row = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
        row:SetSize(820, 30)
        row:SetPoint("TOPLEFT", 0, yOffset)
        local theme = UI:GetTheme()
        local isEven = (rank % 2 == 0)
        local baseBg = isEven and theme.rowBgAlt or theme.rowBg
        row:SetBackdrop(theme.rowBackdrop)
        row:SetBackdropColor(unpack(baseBg))
        row:SetBackdropBorderColor(unpack(theme.rowBorder))

        local rankColor = (rank == 1 and "ffd700") or (rank == 2 and "c0c0c0") or (rank == 3 and "cd7f32") or "8899aa"
        local rankText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rankText:SetPoint("LEFT", 12, 0)
        rankText:SetText(string.format("|cff%s#%d|r", rankColor, rank))

        local icon = UI:CreateClassIcon(row, g.class, 20)
        icon:SetPoint("LEFT", rankText, "RIGHT", 10, 0)

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        nameText:SetText(KB.Utils.ColorizeByClass(g.name, g.class))

        local statsText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statsText:SetPoint("RIGHT", -15, 0)
        statsText:SetText(string.format("Damage: |cffff7700%s|r  |  Healing: |cff00ff00%s|r  |  Score: |cff00e5ff%s|r",
            KB.Utils.FormatNumber(g.damageDone), KB.Utils.FormatNumber(g.healingDone), KB.Utils.FormatNumber(g.bgScore)))

        yOffset = yOffset - 34
    end

    UI.ContentFrame:SetHeight(math.abs(yOffset) + 30)
end

-- 5. Render Zone Intel
function UI:RenderZones()
    local zones = (KB.Leaderboard.GetTopZones and KB.Leaderboard:GetTopZones(currentMode, 15))
               or (KB.Leaderboard.GetDeadliestZones and KB.Leaderboard:GetDeadliestZones(15))
               or {}
    local yOffset = -10

    local title = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, yOffset)
    title:SetText(string.format("Hotspot Conflict Zones & Bloodshed Rankings — [%s]", currentMode))

    yOffset = yOffset - 40
    for rank, z in ipairs(zones) do
        local row = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
        row:SetSize(820, 30)
        row:SetPoint("TOPLEFT", 0, yOffset)
        local theme = UI:GetTheme()
        local isEven = (rank % 2 == 0)
        local baseBg = isEven and theme.rowBgAlt or theme.rowBg
        row:SetBackdrop(theme.rowBackdrop)
        row:SetBackdropColor(unpack(baseBg))
        row:SetBackdropBorderColor(unpack(theme.rowBorder))

        local rankColor = (rank == 1 and "ffd700") or (rank == 2 and "c0c0c0") or (rank == 3 and "cd7f32") or "8899aa"
        local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        txt:SetPoint("LEFT", 14, 0)
        txt:SetText(string.format("|cff%s#%d|r  |cffffffff%s|r", rankColor, rank, z.zone or "Unknown"))

        local countTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        countTxt:SetPoint("RIGHT", -15, 0)
        countTxt:SetText(string.format("|cffff4444%d Confirmed Kills|r", z.kills or 0))

        yOffset = yOffset - 34
    end

    if #zones == 0 then
        local emptyZ = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        emptyZ:SetPoint("TOPLEFT", 10, yOffset)
        emptyZ:SetText("No zone casualty telemetry recorded yet. Engage in combat to populate!")
        yOffset = yOffset - 30
    end

    UI.ContentFrame:SetHeight(math.abs(yOffset) + 30)
end

-- Detail Modal Frame: Classified Killmail Dossier (Anonymous, 100% template-free)
function UI:CreateDetailModal()
    local modal = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    UI.DetailModal = modal
    modal:SetSize(480, 320)
    modal:SetPoint("CENTER")
    local theme = UI:GetTheme()
    modal:SetBackdrop(theme.modalBackdrop or {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    modal:SetBackdropColor(unpack(theme.modalBg or {0.05, 0.06, 0.08, 0.98}))
    modal:SetBackdropBorderColor(unpack(theme.modalBorder or {0.0, 0.8, 1.0, 0.9}))
    modal:Hide()

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("|cff00e5ffKILLMAIL DOSSIER|r")

    -- Left Card: Killer Dossier
    local killerCard = CreateFrame("Frame", nil, modal, "BackdropTemplate")
    killerCard:SetSize(215, 115)
    killerCard:SetPoint("TOPLEFT", 18, -42)
    killerCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    killerCard:SetBackdropColor(0.08, 0.12, 0.10, 0.95)
    killerCard:SetBackdropBorderColor(0.1, 0.7, 0.3, 0.8)

    local kCardTitle = killerCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    kCardTitle:SetPoint("TOPLEFT", 8, -6)
    kCardTitle:SetText("|cff00ff66KILLER|r")

    local kIcon = UI:CreateClassIcon(killerCard, "WARRIOR", 28)
    kIcon:SetPoint("TOPLEFT", 8, -24)
    killerCard.Icon = kIcon

    local kName = killerCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    kName:SetPoint("TOPLEFT", kIcon, "TOPRIGHT", 8, 0)
    killerCard.Name = kName

    local kInfo = killerCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    kInfo:SetPoint("TOPLEFT", kName, "BOTTOMLEFT", 0, -3)
    killerCard.Info = kInfo
    modal.KillerCard = killerCard

    -- Right Card: Victim Dossier
    local victimCard = CreateFrame("Frame", nil, modal, "BackdropTemplate")
    victimCard:SetSize(215, 115)
    victimCard:SetPoint("TOPRIGHT", -18, -42)
    victimCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    victimCard:SetBackdropColor(0.14, 0.08, 0.08, 0.95)
    victimCard:SetBackdropBorderColor(0.8, 0.2, 0.2, 0.8)

    local vCardTitle = victimCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    vCardTitle:SetPoint("TOPLEFT", 8, -6)
    vCardTitle:SetText("|cffff4444VICTIM|r")

    local vIcon = UI:CreateClassIcon(victimCard, "WARRIOR", 28)
    vIcon:SetPoint("TOPLEFT", 8, -24)
    victimCard.Icon = vIcon

    local vName = victimCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    vName:SetPoint("TOPLEFT", vIcon, "TOPRIGHT", 8, 0)
    victimCard.Name = vName

    local vInfo = victimCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    vInfo:SetPoint("TOPLEFT", vName, "BOTTOMLEFT", 0, -3)
    victimCard.Info = vInfo
    modal.VictimCard = victimCard

    -- Context & GPS Info Bar
    local infoPanel = CreateFrame("Frame", nil, modal, "BackdropTemplate")
    infoPanel:SetPoint("TOPLEFT", 18, -165)
    infoPanel:SetPoint("BOTTOMRIGHT", -18, 50)
    infoPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    infoPanel:SetBackdropColor(0.08, 0.09, 0.12, 0.9)
    infoPanel:SetBackdropBorderColor(0.18, 0.22, 0.28, 0.8)

    local details = infoPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    details:SetPoint("TOPLEFT", 10, -8)
    details:SetPoint("BOTTOMRIGHT", -10, 8)
    details:SetJustifyH("LEFT")
    details:SetJustifyV("TOP")
    modal.DetailsText = details

    local close = UI:CreateButton(modal, 100, 26, "Dismiss")
    close:SetPoint("BOTTOM", 0, 14)
    close:SetScript("OnClick", function() modal:Hide() end)

    UI.DetailModal = modal
end

function UI:ShowKillDetail(km)
    if not UI.DetailModal or not km then return end
    local m = UI.DetailModal

    -- Update Killer Card
    local kCoords = CLASS_COORDS[(km.killer.class or ""):upper()] or {0, 0.25, 0, 0.25}
    m.KillerCard.Icon:SetTexCoord(kCoords[1], kCoords[2], kCoords[3], kCoords[4])
    m.KillerCard.Name:SetText(KB.Utils.ColorizeByClass(km.killer.name, km.killer.class))
    local kGuildStr = (km.killer.guild and km.killer.guild ~= "None") and ("<" .. km.killer.guild .. ">") or "Guildless"
    m.KillerCard.Info:SetText(string.format("Level %d %s\n%s\nParty Size: %d\nDamage: %s",
        km.killer.level or 0, km.killer.class or "UNKNOWN", kGuildStr, km.killer.partySize or 1, KB.Utils.FormatNumber(km.killer.damageDone or 0)))

    -- Update Victim Card
    local vCoords = CLASS_COORDS[(km.victim.class or ""):upper()] or {0, 0.25, 0, 0.25}
    m.VictimCard.Icon:SetTexCoord(vCoords[1], vCoords[2], vCoords[3], vCoords[4])
    m.VictimCard.Name:SetText(KB.Utils.ColorizeByClass(km.victim.name, km.victim.class))
    local vGuildStr = (km.victim.guild and km.victim.guild ~= "None") and ("<" .. km.victim.guild .. ">") or "Guildless"
    m.VictimCard.Info:SetText(string.format("Level %d %s\n%s\nHostile Gang: %d\nVictim Faction: %s",
        km.victim.level or 0, km.victim.class or "UNKNOWN", vGuildStr, km.victim.partySize or 1, km.victim.faction or "Unknown"))

    -- Engagement and GPS Info
    local modeStr
    if km.isDuel then
        modeStr = "|cffffd7001v1 Duel Match|r"
    elseif km.isBattleground then
        modeStr = string.format("|cff00ccffBattleground [%s]|r", km.battlegroundName or "BG")
    else
        modeStr = "|cff00ff66Open World PvP|r"
    end

    local soloStr = km.isSolo and "|cff00ff66Certified Solo Kill|r" or string.format("|cffffaa00Gang Engagement (%d Attackers)|r", km.attackersCount or 1)
    local subzoneStr = (km.location.subZone and km.location.subZone ~= "") and (" (" .. km.location.subZone .. ")") or ""

    m.DetailsText:SetText(string.format(
        "|cffffd100Engagement:|r %s  •  %s\n|cffffd100Location:|r %s%s  (GPS: %.1f, %.1f | MapID: %s)\n|cffffd100Timestamp:|r %s  (|cff64748b%s|r)\n|cffffd100Kill ID:|r %s",
        modeStr, soloStr, km.location.zone or "Unknown", subzoneStr, km.location.x or 0, km.location.y or 0, tostring(km.location.mapId or 0),
        date("%Y-%m-%d %H:%M:%S", km.timestamp), KB.Utils.FormatTimeAgo(km.timestamp), km.killId
    ))

    m:Show()
end

-- Isolated, Taint-Free Bounty Dialog Frame (Anonymous, 100% Template-Free)
function UI:ShowBountyPrompt()
    if InCombatLockdown() then
        print("|cffff9900[WoWKB]|r Cannot open bounty dialog during combat.")
        return
    end

    if not UI.BountyDialog then
        local dlg = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        dlg:SetSize(400, 160)
        dlg:SetPoint("CENTER")
        dlg:SetFrameStrata("DIALOG")
        dlg:EnableMouse(true)
        dlg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        dlg:SetBackdropColor(0.08, 0.09, 0.12, 0.98)
        dlg:SetBackdropBorderColor(1.0, 0.84, 0.0, 0.8)

        local t = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        t:SetPoint("TOP", 0, -16)
        t:SetText("|cffffd100Place Gold Bounty|r")

        local desc = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("TOP", 0, -42)
        desc:SetText("Enter: <TargetName> <GoldAmount> (e.g. 'Thrall 500')")

        local eb = CreateFrame("EditBox", nil, dlg, "BackdropTemplate")
        eb:SetSize(260, 26)
        eb:SetPoint("TOP", 0, -70)
        eb:SetAutoFocus(false)
        eb:SetFontObject("GameFontHighlight")
        eb:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        eb:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
        eb:SetBackdropBorderColor(0.3, 0.35, 0.45, 1)
        eb:SetTextInsets(6, 6, 0, 0)
        dlg.editBox = eb

        local okBtn = UI:CreateButton(dlg, 110, 24, "Place Bounty")
        okBtn:SetPoint("BOTTOMLEFT", 40, 18)
        okBtn:SetScript("OnClick", function()
            local text = eb:GetText()
            local name, gold = text:match("^(%S+)%s+(%d+)$")
            if name and gold then
                KB.BountyEngine:PlaceBounty(name, "UNKNOWN", "Unknown", tonumber(gold))
                dlg:Hide()
                UI:RefreshIfVisible()
            else
                print("|cffff0000[WoWKB Error]|r Format: <PlayerName> <GoldAmount> (e.g. 'Thrallkiller 500')")
            end
        end)

        local cancelBtn = UI:CreateButton(dlg, 110, 24, "Cancel")
        cancelBtn:SetPoint("BOTTOMRIGHT", -40, 18)
        cancelBtn:SetScript("OnClick", function() dlg:Hide() end)

        UI.BountyDialog = dlg
    end

    UI.BountyDialog.editBox:SetText("")
    UI.BountyDialog:Show()
    UI.BountyDialog.editBox:SetFocus()
end
