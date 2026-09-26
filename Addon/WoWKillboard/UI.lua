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

-- Theme Engine: Aegis Tactical vs ElvUI Minimalist vs Classic WoW UI
function UI:GetCurrentThemeName()
    if WoWKillboardSettings and WoWKillboardSettings.theme then
        local t = WoWKillboardSettings.theme:lower()
        if KB.Themes and KB.Themes[t] then return t end
    end
    return "tactical"
end

function UI:GetTheme()
    local name = UI:GetCurrentThemeName()
    return (KB.Themes and KB.Themes[name]) or (KB.Themes and KB.Themes["tactical"]) or (KB.Themes and KB.Themes["elvui"]) or {}
end

function UI:SetTheme(themeName)
    themeName = (themeName or ""):lower()
    if not KB.Themes or not KB.Themes[themeName] then
        print(string.format("|cffff9900[WoWKB]|r Unknown theme '%s'. Available: 'tactical', 'elvui', 'classic'.", tostring(themeName)))
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
    if UI.AlertsButton then
        UI.AlertsButton:SetBackdrop(theme.btnBackdrop)
        UI.AlertsButton:SetBackdropColor(unpack(theme.btnBg))
        UI.AlertsButton:SetBackdropBorderColor(unpack(theme.btnBorder))
    end
    if UI.CallBackupButton then
        UI.CallBackupButton:SetBackdrop(theme.btnBackdrop)
        UI.CallBackupButton:SetBackdropColor(unpack(theme.btnBg))
        UI.CallBackupButton:SetBackdropBorderColor(unpack(theme.btnBorder))
    end
    if UI.CloseButton then
        if theme.id == "classic" then
            UI.CloseButton:SetSize(28, 28)
            UI.CloseButton:ClearAllPoints()
            UI.CloseButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -4, -4)
            UI.CloseButton:SetBackdrop(nil)
            local nt = UI.CloseButton:GetNormalTexture()
            if nt then nt:Show() end
            local pt = UI.CloseButton:GetPushedTexture()
            if pt then pt:Show() end
            local ht = UI.CloseButton:GetHighlightTexture()
            if ht then ht:Show() end
            UI.CloseButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
            UI.CloseButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
            UI.CloseButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
            if UI.CloseButton.Label then UI.CloseButton.Label:SetText("") end
        else
            UI.CloseButton:SetSize(18, 18)
            UI.CloseButton:ClearAllPoints()
            UI.CloseButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -8, -8)
            local nt = UI.CloseButton:GetNormalTexture()
            if nt then nt:SetTexture(nil) nt:Hide() end
            local pt = UI.CloseButton:GetPushedTexture()
            if pt then pt:SetTexture(nil) pt:Hide() end
            local ht = UI.CloseButton:GetHighlightTexture()
            if ht then ht:SetTexture(nil) ht:Hide() end
            UI.CloseButton:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            UI.CloseButton:SetBackdropColor(0.10, 0.10, 0.12, 1.0)
            local closeBorder = (theme.id == "tactical") and { 0.45, 0.35, 0.18, 1.0 } or { 0.0, 0.0, 0.0, 1.0 }
            UI.CloseButton:SetBackdropBorderColor(unpack(closeBorder))
            if UI.CloseButton.Label then
                UI.CloseButton.Label:SetFontObject("GameFontHighlightSmall")
                UI.CloseButton.Label:SetText("|cffff3333X|r")
            end
        end
    end
    if UI.Divider then
        UI.Divider:SetColorTexture(unpack(theme.dividerColor))
    end
    if UI.StatCards then
        for _, card in pairs(UI.StatCards) do
            card:SetBackdrop(theme.cardBackdrop)
            card:SetBackdropColor(unpack(theme.cardBg))
            card:SetBackdropBorderColor(unpack(theme.cardBorder))
            if card.TitleLabel and card.rawTitle then
                local tColor = (theme.id == "classic") and "|cffffd100" or "|cffffffff"
                card.TitleLabel:SetText(tColor .. card.rawTitle .. "|r")
            end
        end
    end
    if UI.DetailModal then
        UI.DetailModal:SetBackdrop(theme.modalBackdrop)
        UI.DetailModal:SetBackdropColor(unpack(theme.modalBg))
        UI.DetailModal:SetBackdropBorderColor(unpack(theme.modalBorder))
        if UI.DetailModal.Title then
            local mColor = (theme.id == "classic") and "|cffffd100" or "|cffffffff"
            UI.DetailModal.Title:SetText(mColor .. "KILLMAIL INTELLIGENCE DOSSIER|r")
        end
        if UI.DetailModal.CloseBtn then
            if theme.id == "classic" then
                UI.DetailModal.CloseBtn:SetSize(24, 24)
                UI.DetailModal.CloseBtn:ClearAllPoints()
                UI.DetailModal.CloseBtn:SetPoint("TOPRIGHT", UI.DetailModal, "TOPRIGHT", -4, -4)
                UI.DetailModal.CloseBtn:SetBackdrop(nil)
                local nt = UI.DetailModal.CloseBtn:GetNormalTexture()
                if nt then nt:Show() end
                local pt = UI.DetailModal.CloseBtn:GetPushedTexture()
                if pt then pt:Show() end
                local ht = UI.DetailModal.CloseBtn:GetHighlightTexture()
                if ht then ht:Show() end
                UI.DetailModal.CloseBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
                UI.DetailModal.CloseBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
                UI.DetailModal.CloseBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
                if UI.DetailModal.CloseBtn.Label then UI.DetailModal.CloseBtn.Label:SetText("") end
            else
                UI.DetailModal.CloseBtn:SetSize(18, 18)
                UI.DetailModal.CloseBtn:ClearAllPoints()
                UI.DetailModal.CloseBtn:SetPoint("TOPRIGHT", UI.DetailModal, "TOPRIGHT", -8, -8)
                local nt = UI.DetailModal.CloseBtn:GetNormalTexture()
                if nt then nt:SetTexture(nil) nt:Hide() end
                local pt = UI.DetailModal.CloseBtn:GetPushedTexture()
                if pt then pt:SetTexture(nil) pt:Hide() end
                local ht = UI.DetailModal.CloseBtn:GetHighlightTexture()
                if ht then ht:SetTexture(nil) ht:Hide() end
                UI.DetailModal.CloseBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
                UI.DetailModal.CloseBtn:SetBackdropColor(0.10, 0.10, 0.12, 1.0)
                local closeBorder = (theme.id == "tactical") and { 0.45, 0.35, 0.18, 1.0 } or { 0.0, 0.0, 0.0, 1.0 }
                UI.DetailModal.CloseBtn:SetBackdropBorderColor(unpack(closeBorder))
                if UI.DetailModal.CloseBtn.Label then UI.DetailModal.CloseBtn.Label:SetText("|cffff3333X|r") end
            end
        end
        if UI.DetailModal.DismissBtn then
            UI.DetailModal.DismissBtn:SetBackdrop(theme.btnBackdrop)
            UI.DetailModal.DismissBtn:SetBackdropColor(unpack(theme.btnBg))
            UI.DetailModal.DismissBtn:SetBackdropBorderColor(unpack(theme.btnBorder))
        end
        if UI.DetailModal.KillerCard then
            if theme.id == "classic" then
                UI.DetailModal.KillerCard:SetBackdrop(theme.cardBackdrop)
                UI.DetailModal.KillerCard:SetBackdropColor(0.08, 0.14, 0.10, 0.95)
                UI.DetailModal.KillerCard:SetBackdropBorderColor(0.2, 0.7, 0.3, 0.9)
            else
                UI.DetailModal.KillerCard:SetBackdrop(theme.cardBackdrop)
                UI.DetailModal.KillerCard:SetBackdropColor(0.08, 0.12, 0.09, 0.95)
                UI.DetailModal.KillerCard:SetBackdropBorderColor(0.0, 0.0, 0.0, 1.0)
            end
        end
        if UI.DetailModal.VictimCard then
            if theme.id == "classic" then
                UI.DetailModal.VictimCard:SetBackdrop(theme.cardBackdrop)
                UI.DetailModal.VictimCard:SetBackdropColor(0.14, 0.08, 0.08, 0.95)
                UI.DetailModal.VictimCard:SetBackdropBorderColor(0.8, 0.25, 0.25, 0.9)
            else
                UI.DetailModal.VictimCard:SetBackdrop(theme.cardBackdrop)
                UI.DetailModal.VictimCard:SetBackdropColor(0.12, 0.07, 0.07, 0.95)
                UI.DetailModal.VictimCard:SetBackdropBorderColor(0.0, 0.0, 0.0, 1.0)
            end
        end
        if UI.DetailModal.InfoPanel then
            if theme.id == "classic" then
                UI.DetailModal.InfoPanel:SetBackdrop(theme.cardBackdrop)
                UI.DetailModal.InfoPanel:SetBackdropColor(0.08, 0.07, 0.05, 0.95)
                UI.DetailModal.InfoPanel:SetBackdropBorderColor(unpack(theme.cardBorder))
            else
                UI.DetailModal.InfoPanel:SetBackdrop(theme.cardBackdrop)
                UI.DetailModal.InfoPanel:SetBackdropColor(0.07, 0.07, 0.07, 0.95)
                UI.DetailModal.InfoPanel:SetBackdropBorderColor(0.0, 0.0, 0.0, 1.0)
            end
        end
    end
end

-- Standalone Tactical Button (Zero UIPanelButtonTemplate or sound XML taint)
function UI:CreateButton(parent, w, h, text, fontSize)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w, h)
    btn:EnableMouse(true)
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
            if UI.DetailModal and UI.DetailModal:IsShown() then
                self:SetPropagateKeyboardInput(false)
                UI.DetailModal:Hide()
                return
            end
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
    local initTheme = UI:GetTheme()
    mainFrame:SetBackdropColor(unpack(initTheme.mainBg or {0.035, 0.045, 0.07, 0.98}))
    mainFrame:SetBackdropBorderColor(unpack(initTheme.mainBorder or {0.45, 0.35, 0.18, 0.95}))

    -- Window Title Header
    local titleIcon = mainFrame:CreateTexture(nil, "OVERLAY")
    titleIcon:SetSize(18, 18)
    titleIcon:SetPoint("TOPLEFT", 14, -12)
    titleIcon:SetTexture("Interface\\Icons\\INV_Sword_27")

    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", titleIcon, "RIGHT", 8, 0)
    title:SetText("|cffffffffWoW Killboard|r |cffff3333[Frontline War Room]|r")
    UI.TitleText = title

    local subtitle = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("LEFT", title, "RIGHT", 10, 0)
    subtitle:SetText("|cff888888v" .. KB.Version .. " | Blood & Iron: Open World PvP Carnage & Telemetry|r")
    UI.SubtitleText = subtitle

    -- Template-Free Close Button
    local closeBtn = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:EnableMouse(true)
    local closeLabel = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    closeLabel:SetPoint("CENTER", 0, 0)
    closeLabel:SetText("|cffff3333X|r")
    closeBtn.Label = closeLabel
    closeBtn:SetScript("OnClick", function()
        mainFrame:Hide()
    end)
    UI.CloseButton = closeBtn

    -- Template-Free Theme Switcher Button
    local themeBtn = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
    themeBtn:SetSize(116, 20)
    themeBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    themeBtn:EnableMouse(true)
    local themeLabel = themeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    themeLabel:SetPoint("CENTER", 0, 0)
    themeBtn.Label = themeLabel
    themeBtn:SetScript("OnClick", function()
        local cur = UI:GetCurrentThemeName()
        local nextTheme = (cur == "tactical") and "elvui" or ((cur == "elvui") and "classic" or "tactical")
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

    -- Template-Free Alerts Configuration Button
    local alertsBtn = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
    alertsBtn:SetSize(78, 20)
    alertsBtn:SetPoint("RIGHT", themeBtn, "LEFT", -6, 0)
    alertsBtn:EnableMouse(true)
    local alertsLabel = alertsBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    alertsLabel:SetPoint("CENTER", 0, 0)
    alertsLabel:SetText("|cffffd100Alerts|r")
    alertsBtn.Label = alertsLabel
    alertsBtn:SetScript("OnClick", function()
        UI:ShowAlertsConfig()
    end)
    alertsBtn:SetScript("OnEnter", function(self)
        local t = UI:GetTheme()
        if t and t.btnHoverBg then
            self:SetBackdropColor(unpack(t.btnHoverBg))
            self:SetBackdropBorderColor(unpack(t.btnHoverBorder))
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cffffd100Combat Alert Settings|r", 1, 1, 1)
        GameTooltip:AddLine("Configure Kill Banner, Sound Alerts, Raid Warnings & Position.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    alertsBtn:SetScript("OnLeave", function(self)
        local t = UI:GetTheme()
        if t and t.btnBg then
            self:SetBackdropColor(unpack(t.btnBg))
            self:SetBackdropBorderColor(unpack(t.btnBorder))
        end
        GameTooltip:Hide()
    end)
    UI.AlertsButton = alertsBtn

    -- Template-Free War Horn / Call to Arms Button (Open World PvP Only)
    local backupBtn = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
    backupBtn:SetSize(125, 20)
    backupBtn:SetPoint("RIGHT", alertsBtn, "LEFT", -6, 0)
    backupBtn:EnableMouse(true)
    local backupLabel = backupBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    backupLabel:SetPoint("CENTER", 0, 0)
    backupLabel:SetText("|cffff4444WAR HORN|r")
    backupBtn.Label = backupLabel
    backupBtn:SetScript("OnClick", function()
        if KB.Reinforcements and KB.Reinforcements.IsBeaconActive and KB.Reinforcements:IsBeaconActive() then
            KB.Reinforcements:ResolveBeacon(false)
            backupLabel:SetText("|cffff4444WAR HORN|r")
        else
            if IsInInstance then
                local inInst, instType = IsInInstance()
                if inInst or (instType and instType ~= "none") then
                    print("|cffff0000[WoWKB Error]|r The War Horn can only be sounded upon the open battlefields of Azeroth (Open World PvP only).")
                    return
                end
            end
            if KB.Reinforcements and KB.Reinforcements.TriggerCallForBackup then
                local ok, _ = KB.Reinforcements:TriggerCallForBackup()
                if ok then
                    backupLabel:SetText("|cff00ff00RALLY ACTIVE|r")
                end
            end
        end
    end)
    backupBtn:SetScript("OnEnter", function(self)
        local t = UI:GetTheme()
        if t and t.btnHoverBg then
            self:SetBackdropColor(unpack(t.btnHoverBg))
            self:SetBackdropBorderColor(1.0, 0.3, 0.3, 1.0)
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if KB.Reinforcements and KB.Reinforcements.IsBeaconActive and KB.Reinforcements:IsBeaconActive() then
            GameTooltip:AddLine("|cff00ff00War Horn & Rally Active|r", 1, 1, 1)
            GameTooltip:AddLine("Click to dismiss War Horn and close war party recruitment.", 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine("|cffff3333📯 War Horn: Call to Arms|r", 1, 1, 1)
            GameTooltip:AddLine("Sounds the War Horn across Guild, Group & P2P network.", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Broadcasts emergency coordinates, zone & threat telemetry.", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Activates 10-minute Auto-Invite squad recruitment (Open World only).", 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    backupBtn:SetScript("OnLeave", function(self)
        local t = UI:GetTheme()
        if t and t.btnBg then
            self:SetBackdropColor(unpack(t.btnBg))
            self:SetBackdropBorderColor(unpack(t.btnBorder))
        end
        GameTooltip:Hide()
    end)
    UI.CallBackupButton = backupBtn

    -- 3 KPI Tactical Header Stat Cards (K/D, Duels, Battlegrounds) - Clean & Balanced
    local cardConfigs = {
        { id = "KD",    title = "SESSION COMBAT K/D",   color = "ffd100", w = 268 },
        { id = "DUELS", title = "1v1 DUELS RECORD",     color = "ffd700", w = 268 },
        { id = "BGS",   title = "BATTLEGROUNDS RECORD", color = "69ccf0", w = 268 },
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
        card.rawTitle = cfg.title

        local topLabel = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        topLabel:SetPoint("TOPLEFT", 8, -4)
        topLabel:SetText(string.format("|cff%s%s|r", cfg.color, cfg.title))
        card.TitleLabel = topLabel

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
    divider:SetColorTexture(0.0, 0.0, 0.0, 1.0)
    UI.Divider = divider

    -- Navigation Bar (Tabs on Left, Filter Pills on Right - Zero Overlap)
    local tabs = {
        { id = "FEED",        text = "Intel",           w = 70 },
        { id = "LEADERBOARD", text = "Hall of Legends", w = 112 },
        { id = "BOUNTIES",    text = "Marks of Spite",  w = 108 },
        { id = "BG_METRICS",  text = "Warfronts",       w = 88 },
        { id = "ZONES",       text = "Zone Intel",      w = 84 },
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
        { id = "BG",    text = "BGs",     w = 50, color = {0.3, 0.65, 1.0} },
        { id = "WORLD", text = "World",   w = 56, color = {0.2, 0.85, 0.3} },
        { id = "ALL",   text = "All PvP", w = 62, color = {1.0, 0.82, 0.0} },
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

    -- Frontline Kill Banner
    UI:InitializeKillBanner()

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
            UI.StatCards.BGS.ValueLabel:SetText(string.format("|cffffffff%d|rW - |cffff4444%d|rL  (|cff69ccf0%d%%|r)", bgW, bgL, bgRate))
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
            local activeColor = (theme.id == "classic") and "|cffffd100" or "|cffffd100"
            btn.Label:SetText(activeColor .. btn.Label:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "|r")
        else
            btn.isActive = false
            btn:SetBackdropColor(unpack(theme.btnBg))
            btn:SetBackdropBorderColor(unpack(theme.btnBorder))
            local normalColor = (theme.id == "classic") and "|cffc7b28c" or "|cffa0a0a0"
            btn.Label:SetText(normalColor .. btn.Label:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "|r")
        end
    end

    -- Update Filter Pill Active Glow
    for fid, pill in pairs(filterButtons) do
        if theme.btnBackdrop then pill:SetBackdrop(theme.btnBackdrop) end
        local c = pill.BaseColor or {1.0, 0.82, 0.0}
        if fid == currentMode then
            pill.isActive = true
            if theme.id == "elvui" then
                pill:SetBackdropColor(0.20, 0.20, 0.20, 1.0)
                pill:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                pill.Label:SetText(string.format("|cffffd100%s|r", pill.Label:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
            else
                pill:SetBackdropColor(c[1] * 0.35, c[2] * 0.35, c[3] * 0.35, 1.0)
                pill:SetBackdropBorderColor(c[1], c[2], c[3], 1.0)
                pill.Label:SetText(string.format("|cff%02x%02x%02x%s|r", math.floor(c[1]*255), math.floor(c[2]*255), math.floor(c[3]*255), pill.Label:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
            end
        else
            pill.isActive = false
            pill:SetBackdropColor(unpack(theme.btnBg))
            pill:SetBackdropBorderColor(unpack(theme.btnBorder))
            local pillNormal = (theme.id == "classic") and "|cffc7b28c" or "|cffa0a0a0"
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
        UI.EmptyFeedText:SetText(string.format("|cff94a3b8No PvP kill records under mode:|r |cffffd100[%s]|r\n|cff888888Engage in world PvP, 1v1 duels, or battlegrounds to populate the feed.|r", currentMode))
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
            accent:SetColorTexture(0.3, 0.65, 1.0, 1.0) -- Soft Blue
            badgeStr = string.format("|cff69ccf0[BG x%d]|r", km.attackersCount or 1)
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
    header:SetText(string.format("Top PvP Assassins & Solo Kings — Mode: |cffffd100[%s]|r", currentMode))

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
        statsText:SetText(string.format("|cff00ff66%d Kills|r  |  |cffffd100%d Solo|r  |  |cffff4444%d Deaths|r  |  K/D: |cffffd100%s|r",
            p.kills, p.soloKills, p.deaths, kd))

        yOffset = yOffset - 34
    end

    -- Top War Guilds Section
    yOffset = yOffset - 15
    local guildHeader = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    guildHeader:SetPoint("TOPLEFT", 10, yOffset)
    guildHeader:SetText(string.format("Top War Guilds — Mode: |cffffd100[%s]|r", currentMode))

    yOffset = yOffset - 30
    local topGuilds = KB.Leaderboard:GetTopGuilds(currentMode, 8)
    if #topGuilds == 0 then
        local emptyGuildText = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        emptyGuildText:SetPoint("TOPLEFT", 15, yOffset)
        emptyGuildText:SetText("No guild PvP telemetry recorded for this filter mode.")
        yOffset = yOffset - 25
    else
        for gRank, g in ipairs(topGuilds) do
            local gRow = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
            gRow:SetSize(820, 28)
            gRow:SetPoint("TOPLEFT", 0, yOffset)
            local theme = UI:GetTheme()
            local isEven = (gRank % 2 == 0)
            local baseBg = isEven and theme.rowBgAlt or theme.rowBg
            gRow:SetBackdrop(theme.rowBackdrop)
            gRow:SetBackdropColor(unpack(baseBg))
            gRow:SetBackdropBorderColor(unpack(theme.rowBorder))

            local gRankColor = (gRank == 1 and "ffd700") or (gRank == 2 and "c0c0c0") or (gRank == 3 and "cd7f32") or "8899aa"
            local gRankText = gRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            gRankText:SetPoint("LEFT", 12, 0)
            gRankText:SetText(string.format("|cff%s#%d|r", gRankColor, gRank))

            local gName = gRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            gName:SetPoint("LEFT", 45, 0)
            gName:SetText(string.format("|cffffd700<%s>|r", g.guild))

            local gKills = gRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            gKills:SetPoint("RIGHT", -15, 0)
            gKills:SetText(string.format("|cff00ff66%d Kills Logged|r", g.kills))

            yOffset = yOffset - 32
        end
    end

    UI.ContentFrame:SetHeight(math.abs(yOffset) + 40)
end

-- 3. Render Bounties & Debt Ledger (Wall of Shame)
function UI:RenderBounties()
    local yOffset = -10

    local bntTitle = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    bntTitle:SetPoint("TOPLEFT", 10, yOffset)
    bntTitle:SetText("⚔️ Active Marks of Spite & Execution Contracts")

    -- Place Bounty Button
    local placeBtn = UI:CreateButton(UI.ContentFrame, 150, 24, "+ Issue Mark of Spite")
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

            -- Lookup last known sighting in SavedVariables
            local lastSeenStr = ""
            if WoWKillboardDB and WoWKillboardDB.kills then
                local latestTime = 0
                local latestZone = nil
                for _, km in pairs(WoWKillboardDB.kills) do
                    if km.killer and km.victim and (km.killer.name == b.targetName or km.victim.name == b.targetName) then
                        if (km.timestamp or 0) > latestTime then
                            latestTime = km.timestamp
                            latestZone = km.location and km.location.zone
                        end
                    end
                end
                if latestZone and latestTime > 0 then
                    local diffMin = math.max(1, math.floor((time() - latestTime) / 60))
                    lastSeenStr = string.format("  |  |cff38bdf8Last Sighted: %s (~%dm ago)|r", latestZone, diffMin)
                end
            end

            local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            txt:SetPoint("LEFT", icon, "RIGHT", 8, 0)
            txt:SetText(string.format("MARK OF SPITE: |cffff3333%s|r (%s)  |  Reward: |cffffd700%s|r  |  Issued by: |cffcbd5e1%s|r%s",
                b.targetName, b.targetClass, KB.Utils.FormatMoney(b.amountCopper), b.placerName, lastSeenStr))

            local bId = b.id
            local isAccepted = KB.BountyEngine and KB.BountyEngine:IsBountyAccepted(bId)
            local acceptBtn = UI:CreateButton(row, 115, 22, isAccepted and "|cff00ff66Tracking|r" or "Accept Contract")
            acceptBtn:SetPoint("RIGHT", -8, 0)
            if not isAccepted then
                acceptBtn:SetScript("OnClick", function()
                    if KB.BountyEngine and KB.BountyEngine.AcceptBounty then
                        KB.BountyEngine:AcceptBounty(bId)
                    end
                end)
            end

            yOffset = yOffset - 36
        end
    end

    if not hasBounties then
        local emptyB = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        emptyB:SetPoint("TOPLEFT", 10, yOffset)
        emptyB:SetText("No active blood bounties. Declare one upon an enemy to ignite the manhunt!")
        yOffset = yOffset - 25
    end

    -- Archived Cold Cases Section (>30 Days Uncollected)
    yOffset = yOffset - 20
    local coldTitle = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    coldTitle:SetPoint("TOPLEFT", 10, yOffset)
    coldTitle:SetText("📜 Archive of Unclaimed Bounties — Escaped Targets (>30 Days)")

    yOffset = yOffset - 32
    local hasCold = false
    for _, b in pairs(WoWKillboardBounties) do
        if b.status == "COLD_CASE" then
            hasCold = true
            local row = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
            row:SetSize(820, 30)
            row:SetPoint("TOPLEFT", 0, yOffset)
            local theme = UI:GetTheme()
            row:SetBackdrop(theme.rowBackdrop)
            row:SetBackdropColor(0.08, 0.08, 0.10, 0.85)
            row:SetBackdropBorderColor(0.25, 0.25, 0.30, 0.7)

            local icon = UI:CreateClassIcon(row, b.targetClass, 20)
            icon:SetPoint("LEFT", 12, 0)

            local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", icon, "RIGHT", 8, 0)
            txt:SetText(string.format("|cff888888[ESCAPED]|r |cffffffff%s|r (%s)  |  Unclaimed Reward: |cffffd700%s|r  |  Contractor: %s",
                b.targetName, b.targetClass, KB.Utils.FormatMoney(b.amountCopper), b.placerName))

            yOffset = yOffset - 34
        end
    end

    if not hasCold then
        local emptyC = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        emptyC:SetPoint("TOPLEFT", 10, yOffset)
        emptyC:SetText("No archived bounties. All execution contracts remain actively pursued.")
        yOffset = yOffset - 25
    end

    -- The Traitor's Gibbet (Oathbreaker Debt Ledger)
    yOffset = yOffset - 24
    local debtTitle = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    debtTitle:SetPoint("TOPLEFT", 10, yOffset)
    debtTitle:SetText("⛓️ The Traitor's Gibbet — Oathbreakers & Defaulted Debts")

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
            txt:SetText(string.format("|cffff2222[TRAITOR]|r |cffffffff%s|r defaulted on |cffffd700%s|r owed to %s (%d days in default)",
                playerName, KB.Utils.FormatMoney(debt.amountOwedCopper), debt.creditor, debt.daysInDefault or 1))

            -- If player is the debtor, show redemption button
            if playerName == UnitName("player") then
                local payBtn = UI:CreateButton(row, 130, 24, "⚔️ Settle Debt")
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
        statsText:SetText(string.format("Damage: |cffff7700%s|r  |  Healing: |cff00ff00%s|r  |  Score: |cffffd100%s|r",
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
    modal:SetSize(520, 360)
    modal:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
    modal:SetFrameStrata("DIALOG")
    modal:SetFrameLevel(mainFrame:GetFrameLevel() + 50)
    modal:EnableMouse(true)
    modal:SetClampedToScreen(true)

    local theme = UI:GetTheme()
    modal:SetBackdrop(theme.modalBackdrop or {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    modal:SetBackdropColor(unpack(theme.modalBg or {0.05, 0.05, 0.05, 0.98}))
    modal:SetBackdropBorderColor(unpack(theme.modalBorder or {0.0, 0.0, 0.0, 1.0}))
    modal:Hide()

    -- Title Bar
    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    local mColor = (theme.id == "classic") and "|cffffd100" or "|cffffffff"
    title:SetText(mColor .. "KILLMAIL INTELLIGENCE DOSSIER|r")
    modal.Title = title

    -- Top-Right Close Button
    local closeBtn = CreateFrame("Button", nil, modal, "BackdropTemplate")
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetFrameStrata("DIALOG")
    closeBtn:SetFrameLevel(modal:GetFrameLevel() + 10)
    closeBtn:EnableMouse(true)
    local closeLabel = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    closeLabel:SetPoint("CENTER", 0, 0)
    closeBtn.Label = closeLabel
    closeBtn:SetScript("OnClick", function()
        modal:Hide()
    end)
    modal.CloseBtn = closeBtn

    -- Left Card: Killer Dossier
    local killerCard = CreateFrame("Frame", nil, modal, "BackdropTemplate")
    killerCard:SetSize(236, 118)
    killerCard:SetPoint("TOPLEFT", 16, -38)
    killerCard:SetFrameStrata("DIALOG")
    killerCard:SetFrameLevel(modal:GetFrameLevel() + 2)
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
    victimCard:SetSize(236, 118)
    victimCard:SetPoint("TOPRIGHT", -16, -38)
    victimCard:SetFrameStrata("DIALOG")
    victimCard:SetFrameLevel(modal:GetFrameLevel() + 2)
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
    infoPanel:SetPoint("TOPLEFT", 16, -164)
    infoPanel:SetPoint("BOTTOMRIGHT", -16, 48)
    infoPanel:SetFrameStrata("DIALOG")
    infoPanel:SetFrameLevel(modal:GetFrameLevel() + 2)
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
    modal.InfoPanel = infoPanel

    -- Dismiss Button (Elevated frame level and strata so it's impossible to intercept)
    local dismiss = UI:CreateButton(modal, 120, 26, "Dismiss")
    dismiss:SetPoint("BOTTOM", 0, 14)
    dismiss:SetFrameStrata("DIALOG")
    dismiss:SetFrameLevel(modal:GetFrameLevel() + 10)
    dismiss:EnableMouse(true)
    dismiss:SetScript("OnClick", function()
        modal:Hide()
    end)
    modal.DismissBtn = dismiss

    -- Apply current theme styling
    UI:ApplyTheme()
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
        modeStr = string.format("|cff69ccf0Battleground [%s]|r", km.battlegroundName or "BG")
    else
        modeStr = "|cff00ff66Open World PvP|r"
    end

    local soloStr = km.isSolo and "|cff00ff66Certified Solo Kill|r" or string.format("|cffffaa00Gang Engagement (%d Attackers)|r", km.attackersCount or 1)
    local subzoneStr = (km.location.subZone and km.location.subZone ~= "") and (" (" .. km.location.subZone .. ")") or ""

    m.DetailsText:SetText(string.format(
        "|cffffd100Engagement:|r %s  •  %s\n|cffffd100Location:|r %s%s  (GPS: %.1f, %.1f | MapID: %s)\n|cffffd100Timestamp:|r %s  (|cff888888%s|r)\n|cffffd100Kill ID:|r %s",
        modeStr, soloStr, km.location.zone or "Unknown", subzoneStr, km.location.x or 0, km.location.y or 0, tostring(km.location.mapId or 0),
        date("%Y-%m-%d %H:%M:%S", km.timestamp), KB.Utils.FormatTimeAgo(km.timestamp), km.killId
    ))

    UI:ApplyTheme()
    m:Show()
    if m.Raise then m:Raise() end
end

-- Isolated, Taint-Free Bounty Dialog Frame (Anonymous, 100% Template-Free)
function UI:ShowBountyPrompt()
    if InCombatLockdown() then
        print("|cffff9900[WoWKB]|r Cannot open bounty dialog during combat.")
        return
    end

    if IsInInstance then
        local inInst, instType = IsInInstance()
        if inInst or (instType and instType ~= "none") then
            print("|cffff0000[WoWKB Error]|r Blood bounties can only be declared upon the open battlefields of Azeroth (Open World PvP only).")
            return
        end
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
        t:SetText("|cffff3333Issue Mark of Spite|r")

        local desc = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("TOP", 0, -42)
        desc:SetText("Enter: <TargetName> <RewardGold> (e.g. 'Thrall 500')")

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

        local okBtn = UI:CreateButton(dlg, 120, 24, "Declare Bounty")
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

-- Death Bounty Prompt Dialog: Triggered when player is slain in PvP (Open World Only)
function UI:ShowDeathBountyPrompt(killerData)
    if not killerData or not killerData.name then return end
    if InCombatLockdown() then return end

    if IsInInstance then
        local inInst, instType = IsInInstance()
        if inInst or (instType and instType ~= "none") then return end
    end

    if not UI.DeathBountyDialog then
        local dlg = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        dlg:SetSize(440, 210)
        dlg:SetPoint("CENTER", 0, 80)
        dlg:SetFrameStrata("DIALOG")
        dlg:SetFrameLevel(100)
        dlg:EnableMouse(true)
        dlg:SetClampedToScreen(true)

        local theme = UI:GetTheme()
        dlg:SetBackdrop(theme and theme.modalBackdrop or {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        dlg:SetBackdropColor(0.08, 0.05, 0.05, 0.98)
        dlg:SetBackdropBorderColor(1.0, 0.25, 0.25, 1.0)

        local title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        title:SetText("|cffff2222FALLEN IN BATTLE — DECLARE BLOOD BOUNTY|r")

        local desc = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        desc:SetPoint("TOP", 0, -46)
        desc:SetJustifyH("CENTER")
        dlg.DescText = desc

        local goldLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        goldLabel:SetPoint("TOPLEFT", 60, -96)
        goldLabel:SetText("Bounty Gold Amount:")

        local eb = CreateFrame("EditBox", nil, dlg, "BackdropTemplate")
        eb:SetSize(140, 26)
        eb:SetPoint("LEFT", goldLabel, "RIGHT", 12, 0)
        eb:SetAutoFocus(false)
        eb:SetNumeric(true)
        eb:SetNumber(50)
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

        local note = dlg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        note:SetPoint("TOP", 0, -132)
        note:SetText("|cff888888Execution contract awarded only to the hunter who lands the final blow (Open World only).|r")

        local okBtn = UI:CreateButton(dlg, 140, 26, "⚔️ Declare Bounty")
        okBtn:SetPoint("BOTTOMLEFT", 45, 16)
        okBtn:SetScript("OnClick", function()
            local gold = tonumber(eb:GetText()) or 50
            if gold > 0 and dlg.CurrentKiller then
                local k = dlg.CurrentKiller
                KB.BountyEngine:PlaceBounty(k.name, k.class or "UNKNOWN", k.faction or "Unknown", gold, k.guid)
                dlg:Hide()
                if UI.RefreshIfVisible then UI:RefreshIfVisible() end
            end
        end)

        local cancelBtn = UI:CreateButton(dlg, 130, 26, "Decline")
        cancelBtn:SetPoint("BOTTOMRIGHT", -45, 16)
        cancelBtn:SetScript("OnClick", function()
            dlg:Hide()
        end)

        UI.DeathBountyDialog = dlg
    end

    UI.DeathBountyDialog.CurrentKiller = killerData
    UI.DeathBountyDialog.DescText:SetText(string.format("The soil drinks your blood! |cffff3333%s|r has slain you in open combat.\nDeclare a blood bounty for their head upon a pike!", killerData.name))
    UI.DeathBountyDialog.editBox:SetText("50")
    UI.DeathBountyDialog:Show()
    if UI.DeathBountyDialog.Raise then UI.DeathBountyDialog:Raise() end
end

-- Reinforcement Alert Dialog: Displayed to guildmates and allies when a War Horn is sounded
function UI:ShowReinforcementAlert(beaconData)
    if not beaconData or not beaconData.character_name then return end
    if InCombatLockdown() then return end

    if not UI.ReinforcementDialog then
        local dlg = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        dlg:SetSize(460, 230)
        dlg:SetPoint("CENTER", 0, 100)
        dlg:SetFrameStrata("DIALOG")
        dlg:SetFrameLevel(110)
        dlg:EnableMouse(true)
        dlg:SetClampedToScreen(true)

        dlg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
        })
        dlg:SetBackdropColor(0.08, 0.04, 0.04, 0.98)
        dlg:SetBackdropBorderColor(1.0, 0.2, 0.2, 1.0)

        -- Safe ESC key handling (100% taint-free)
        dlg:EnableKeyboard(true)
        dlg:SetPropagateKeyboardInput(true)
        dlg:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput(false)
                self:Hide()
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)

        local title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        title:SetText("|cffff2222📯 WAR HORN: CALL TO ARMS!|r")

        local body = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        body:SetPoint("TOP", 0, -48)
        body:SetJustifyH("CENTER")
        dlg.BodyText = body

        local threat = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        threat:SetPoint("TOP", 0, -100)
        threat:SetJustifyH("CENTER")
        dlg.ThreatText = threat

        local gps = dlg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        gps:SetPoint("TOP", 0, -140)
        dlg.GpsText = gps

        local joinBtn = UI:CreateButton(dlg, 180, 28, "⚔️ Answer the Call")
        joinBtn:SetPoint("BOTTOMLEFT", 30, 20)
        joinBtn:SetScript("OnClick", function()
            if dlg.CurrentBeacon and dlg.CurrentBeacon.character_name then
                local target = dlg.CurrentBeacon.character_name
                SendChatMessage("rally", "WHISPER", nil, target)
                print(string.format("|cff00ff00[WoWKB]|r Answering the call for |cffffd100%s|r! Marching to reinforce in %s!", target, dlg.CurrentBeacon.zone or "Wilderness"))
                dlg:Hide()
            end
        end)

        local dismissBtn = UI:CreateButton(dlg, 130, 28, "Dismiss")
        dismissBtn:SetPoint("BOTTOMRIGHT", -30, 20)
        dismissBtn:SetScript("OnClick", function()
            dlg:Hide()
        end)

        UI.ReinforcementDialog = dlg
    end

    UI.ReinforcementDialog.CurrentBeacon = beaconData
    local classColor = "00ccff"
    if KB.Config and KB.Config.ClassColors and beaconData.character_class then
        local c = KB.Config.ClassColors[beaconData.character_class:upper()]
        if c then classColor = string.format("%02x%02x%02x", math.floor(c[1]*255), math.floor(c[2]*255), math.floor(c[3]*255)) end
    end

    UI.ReinforcementDialog.BodyText:SetText(string.format(
        "Blood calls to blood! Ally |cff%s%s|r (Lvl %d %s) is taking fire in |cffffd100%s|r%s!",
        classColor,
        beaconData.character_name,
        beaconData.character_level or 60,
        beaconData.character_class or "WARRIOR",
        beaconData.zone or "Wilderness",
        (beaconData.subzone and beaconData.subzone ~= "") and string.format(" (|cffaaaaaa%s|r)", beaconData.subzone) or ""
    ))

    UI.ReinforcementDialog.ThreatText:SetText(string.format(
        "Ambushed by: |cffff4444%d Enemy Player(s)|r\n|cffffaa00%s|r",
        beaconData.hostile_count or 1,
        beaconData.hostile_names or "Unknown Hostiles"
    ))

    UI.ReinforcementDialog.GpsText:SetText(string.format(
        "GPS Telemetry: (%.1f, %.1f) | Guild: <%s>",
        beaconData.coord_x or 0,
        beaconData.coord_y or 0,
        beaconData.guild_name or "Unaligned"
    ))

    UI.ReinforcementDialog:Show()
    if UI.ReinforcementDialog.Raise then UI.ReinforcementDialog:Raise() end
end

-- KOS Blacklist & Deserter Alert Dialog
function UI:ShowKOSAlert(targetName, guildOrFormer, alertType, reason)
    if InCombatLockdown() then return end
    if not targetName then return end

    if not UI.KOSDialog then
        local dlg = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        dlg:SetSize(460, 210)
        dlg:SetPoint("CENTER", 0, 160)
        dlg:SetFrameStrata("DIALOG")
        dlg:SetFrameLevel(115)
        dlg:EnableMouse(true)
        dlg:SetClampedToScreen(true)

        dlg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
        })
        dlg:SetBackdropColor(0.12, 0.02, 0.02, 0.98)
        dlg:SetBackdropBorderColor(1.0, 0.0, 0.0, 1.0)

        dlg:EnableKeyboard(true)
        dlg:SetPropagateKeyboardInput(true)
        dlg:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput(false)
                self:Hide()
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)

        local title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        dlg.TitleText = title

        local body = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        body:SetPoint("TOP", 0, -48)
        body:SetJustifyH("CENTER")
        dlg.BodyText = body

        local sub = dlg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        sub:SetPoint("TOP", 0, -110)
        dlg.SubText = sub

        local spotBtn = UI:CreateButton(dlg, 180, 28, "👁️ Broadcast Spot")
        spotBtn:SetPoint("BOTTOMLEFT", 30, 20)
        spotBtn:SetScript("OnClick", function()
            if KB.IntelScanner then
                KB.IntelScanner:SpotTarget("KOS Target Spotted!")
            end
            dlg:Hide()
        end)

        local dismissBtn = UI:CreateButton(dlg, 130, 28, "Dismiss")
        dismissBtn:SetPoint("BOTTOMRIGHT", -30, 20)
        dismissBtn:SetScript("OnClick", function()
            dlg:Hide()
        end)

        UI.KOSDialog = dlg
    end

    if alertType == "DESERTER" then
        UI.KOSDialog.TitleText:SetText("|cffff0000🚨 KOS DESERTER DETECTED!|r")
        UI.KOSDialog.BodyText:SetText(string.format("Enemy |cffffd100%s|r is serving a |cffff333330-Day Deserter Penance|r!\nFormer Guild: |cffff5555<%s>|r", targetName, guildOrFormer or "Unknown"))
        UI.KOSDialog.SubText:SetText("Branded for deserting a defeated guild. Kill on sight with zero mercy!")
    elseif alertType == "GUILD_KOS" then
        UI.KOSDialog.TitleText:SetText("|cffff0000🚨 GUILD KOS BLACKLIST!|r")
        UI.KOSDialog.BodyText:SetText(string.format("Enemy |cffffd100%s|r (<%s>) belongs to a |cffff3333Blacklisted Guild|r!\nReason: %s", targetName, guildOrFormer or "Unknown", reason or "Realm Feud Defeat"))
        UI.KOSDialog.SubText:SetText("The entire guild is marked for eradication across all territories.")
    else
        UI.KOSDialog.TitleText:SetText("|cffff0000🚨 KOS BLACKLIST TARGET!|r")
        UI.KOSDialog.BodyText:SetText(string.format("Hostile |cffffd100%s|r is officially branded on the |cffff3333KOS Blacklist|r!", targetName))
        UI.KOSDialog.SubText:SetText(reason or "Realm KOS Order")
    end

    UI.KOSDialog:Show()
    if UI.KOSDialog.Raise then UI.KOSDialog:Raise() end
end

-- ----------------------------------------------------------------------------
-- Frontline Kill Banner & Combat Toast (100% Template-Free, InCombat Safe)
-- ----------------------------------------------------------------------------
local killBanner = nil
local killBannerTimer = nil

function UI:InitializeKillBanner()
    if killBanner or InCombatLockdown() then return end

    killBanner = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    killBanner:SetSize(540, 54)
    killBanner:SetFrameStrata("HIGH")
    killBanner:SetClampedToScreen(true)
    killBanner:SetMovable(true)
    killBanner:EnableMouse(true)
    killBanner:RegisterForDrag("LeftButton")

    -- Restore saved position or default to TOP, 0, -135
    local pos = WoWKillboardSettings and WoWKillboardSettings.bannerPosition
    if pos and pos.point and pos.relPoint and pos.x and pos.y then
        killBanner:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        killBanner:SetPoint("TOP", UIParent, "TOP", 0, -135)
    end

    killBanner:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    killBanner:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        WoWKillboardSettings = WoWKillboardSettings or {}
        WoWKillboardSettings.bannerPosition = {
            point = point or "TOP",
            relPoint = relPoint or "TOP",
            x = x or 0,
            y = y or -135,
        }
    end)

    killBanner:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    killBanner:SetBackdropColor(0.035, 0.045, 0.07, 0.96)
    killBanner:SetBackdropBorderColor(0.85, 0.65, 0.20, 1.0)
    killBanner:Hide()

    -- 2px Top Accent Rule (Dynamic engagement colored)
    local topAccent = killBanner:CreateTexture(nil, "OVERLAY")
    topAccent:SetHeight(2)
    topAccent:SetPoint("TOPLEFT", killBanner, "TOPLEFT", 0, 0)
    topAccent:SetPoint("TOPRIGHT", killBanner, "TOPRIGHT", 0, 0)
    topAccent:SetColorTexture(0.96, 0.72, 0.20, 1.0)
    killBanner.TopAccent = topAccent

    -- Killer Class Icon
    local killerIcon = killBanner:CreateTexture(nil, "ARTWORK")
    killerIcon:SetSize(26, 26)
    killerIcon:SetPoint("LEFT", 12, 4)
    killBanner.KillerIcon = killerIcon

    -- Killer Text
    local killerText = killBanner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    killerText:SetPoint("LEFT", killerIcon, "RIGHT", 8, 0)
    killBanner.KillerText = killerText

    -- Center Combat Action
    local centerAction = killBanner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    centerAction:SetPoint("CENTER", 0, 8)
    centerAction:SetText("|cffff3333DESTROYED|r")
    killBanner.CenterAction = centerAction

    -- Engagement Tag (Solo 1v1, Duel, BG, Gang)
    local modeTag = killBanner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    modeTag:SetPoint("TOP", centerAction, "BOTTOM", 0, -2)
    killBanner.ModeTag = modeTag

    -- Victim Class Icon
    local victimIcon = killBanner:CreateTexture(nil, "ARTWORK")
    victimIcon:SetSize(26, 26)
    victimIcon:SetPoint("RIGHT", -12, 4)
    killBanner.VictimIcon = victimIcon

    -- Victim Text
    local victimText = killBanner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    victimText:SetPoint("RIGHT", victimIcon, "LEFT", -8, 0)
    killBanner.VictimText = victimText

    -- Location Subtitle
    local locText = killBanner:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    locText:SetPoint("BOTTOM", 0, 5)
    killBanner.LocText = locText

    UI.KillBanner = killBanner
end

function UI:ShowKillBanner(killmail, isTest)
    if not killmail or not killmail.killer or not killmail.victim then return end

    local settings = WoWKillboardSettings or KB.DefaultSettings
    local alertMode = settings.alertMode or "SOUND_AND_BANNER"
    local alertScope = settings.alertScope or "ZONE"
    local alertRaidWarning = settings.alertRaidWarning ~= false

    -- 1. If alerts are completely disabled, exit immediately (unless explicit test)
    if alertMode == "OFF" and not isTest then return end

    -- 2. Scope & Proximity Filter (bypassed if explicit test)
    if not isTest then
        local myName = UnitName("player")
        if alertScope == "MINE" then
            local isMyCombat = (killmail.killer.name and killmail.killer.name == myName) or
                               (killmail.victim.name and killmail.victim.name == myName)
            if not isMyCombat then return end
        elseif alertScope == "ZONE" then
            local myZone = GetZoneText and GetZoneText() or ""
            local killZone = (killmail.location and killmail.location.zone) or ""
            if myZone ~= "" and killZone ~= "" and myZone:lower() ~= killZone:lower() then
                return
            end
        end
    end

    -- 3. Audio Dispatch (Sound + Banner mode only)
    if alertMode == "SOUND_AND_BANNER" then
        if PlaySound then
            local soundId = (KB.SoundAlerts and KB.SoundAlerts.SOLO_KILL) or 8959
            pcall(PlaySound, soundId, "Master")
        end
    end

    -- 4. Raid Warning On-Screen Combat Notice
    if alertRaidWarning and RaidNotice_AddMessage and RaidWarningFrame then
        local kName = killmail.killer.name or "Unknown"
        local vName = killmail.victim.name or "Unknown"
        local loc = killmail.location or {}
        local zName = (loc.zone and loc.zone ~= "") and loc.zone or (GetZoneText and GetZoneText()) or "Azeroth"
        local rwMsg = string.format("|cffff3333[WoWKB]|r %s destroyed %s (%s)", kName, vName, zName)
        local rwColor = (ChatTypeInfo and ChatTypeInfo["RAID_WARNING"]) or { r = 1.0, g = 0.28, b = 0.0 }
        pcall(RaidNotice_AddMessage, RaidWarningFrame, rwMsg, rwColor)
    end

    -- 5. Frontline Kill Banner Frame
    if not UI.KillBanner then
        UI:InitializeKillBanner()
    end

    local banner = UI.KillBanner
    if not banner then return end

    -- Restore saved position if not currently unlocked/dragged
    if not UI.bannerUnlocked then
        local pos = WoWKillboardSettings and WoWKillboardSettings.bannerPosition
        if pos and pos.point and pos.relPoint and pos.x and pos.y then
            banner:ClearAllPoints()
            banner:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
        end
    end

    -- Setup Killer Icon & Name
    local kClass = (killmail.killer.class or ""):upper()
    local kCoords = CLASS_COORDS[kClass] or {0, 0.25, 0, 0.25}
    banner.KillerIcon:SetTexture(CLASS_ICON_TEXTURE)
    banner.KillerIcon:SetTexCoord(kCoords[1], kCoords[2], kCoords[3], kCoords[4])
    banner.KillerText:SetText(KB.Utils.ColorizeByClass(string.format("[%d] %s", killmail.killer.level or 0, killmail.killer.name or "Unknown"), killmail.killer.class))

    -- Setup Victim Icon & Name
    local vClass = (killmail.victim.class or ""):upper()
    local vCoords = CLASS_COORDS[vClass] or {0, 0.25, 0, 0.25}
    banner.VictimIcon:SetTexture(CLASS_ICON_TEXTURE)
    banner.VictimIcon:SetTexCoord(vCoords[1], vCoords[2], vCoords[3], vCoords[4])
    banner.VictimText:SetText(KB.Utils.ColorizeByClass(string.format("[%d] %s", killmail.victim.level or 0, killmail.victim.name or "Unknown"), killmail.victim.class))

    -- Setup Engagement Theme & Accents
    if killmail.isDuel then
        banner.CenterAction:SetText("|cffffd100DUEL VICTORY|r")
        banner.ModeTag:SetText("|cffffd7001v1 CERTIFIED DUEL|r")
        banner.TopAccent:SetColorTexture(1.0, 0.84, 0.0, 1.0)
        banner:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0)
    elseif killmail.isArena then
        banner.CenterAction:SetText("|cffa335eeARENA EXECUTION|r")
        banner.ModeTag:SetText("|cffa335eeRATED ARENA MATCH|r")
        banner.TopAccent:SetColorTexture(0.64, 0.21, 0.93, 1.0)
        banner:SetBackdropBorderColor(0.64, 0.21, 0.93, 1.0)
    elseif killmail.isBattleground then
        banner.CenterAction:SetText("|cff00ccffWARFRONT EXECUTION|r")
        banner.ModeTag:SetText(string.format("|cff00ccff%s (x%d)|r", killmail.battlegroundName or "Battleground", killmail.attackersCount or 1))
        banner.TopAccent:SetColorTexture(0.0, 0.8, 1.0, 1.0)
        banner:SetBackdropBorderColor(0.0, 0.8, 1.0, 1.0)
    elseif killmail.isSolo then
        banner.CenterAction:SetText("|cff00ff00SOLO DESTROYED|r")
        banner.ModeTag:SetText("|cff00ff00CERTIFIED 1v1 OPEN WORLD|r")
        banner.TopAccent:SetColorTexture(0.0, 1.0, 0.4, 1.0)
        banner:SetBackdropBorderColor(0.0, 1.0, 0.4, 1.0)
    else
        banner.CenterAction:SetText("|cffff9900TARGET ELIMINATED|r")
        banner.ModeTag:SetText(string.format("|cffff9900GANG COMBAT (x%d Attackers)|r", killmail.attackersCount or 2))
        banner.TopAccent:SetColorTexture(1.0, 0.6, 0.0, 1.0)
        banner:SetBackdropBorderColor(1.0, 0.6, 0.0, 1.0)
    end

    -- Location Subtitle
    local loc = killmail.location or {}
    local zoneStr = loc.zone or "Azeroth"
    if loc.subZone and loc.subZone ~= "" then
        zoneStr = zoneStr .. " - " .. loc.subZone
    end
    banner.LocText:SetText(string.format("|cff888888%s  |  %.1f, %.1f|r", zoneStr, loc.x or 0, loc.y or 0))

    banner:Show()
    if not UI.bannerUnlocked then
        if killBannerTimer then killBannerTimer:Cancel() end
        killBannerTimer = C_Timer.NewTimer(4.5, function()
            if banner and banner:IsShown() and not UI.bannerUnlocked then
                banner:Hide()
            end
        end)
    end
end

-- Toggle Banner Drag / Positioning Mode
function UI:ToggleBannerLock(explicitState)
    if InCombatLockdown() then
        print("|cffff9900[WoWKB]|r Cannot move banner during combat.")
        return
    end
    if not UI.KillBanner then
        UI:InitializeKillBanner()
    end
    local banner = UI.KillBanner
    if not banner then return end

    if explicitState ~= nil then
        UI.bannerUnlocked = explicitState
    else
        UI.bannerUnlocked = not UI.bannerUnlocked
    end

    if UI.bannerUnlocked then
        if killBannerTimer then killBannerTimer:Cancel() end
        banner.KillerIcon:SetTexture("Interface\\Icons\\INV_Sword_27")
        banner.KillerIcon:SetTexCoord(0, 1, 0, 1)
        banner.KillerText:SetText("|cff00ff00[60] Killer (You)|r")
        banner.VictimIcon:SetTexture("Interface\\Icons\\Achievement_PVP_P_01")
        banner.VictimIcon:SetTexCoord(0, 1, 0, 1)
        banner.VictimText:SetText("|cffff3333[60] Hostile Victim|r")
        banner.CenterAction:SetText("|cffffd100[DRAG TO MOVE]|r")
        banner.ModeTag:SetText("|cffffffffClick 'Lock Banner' or /wowkb move to save|r")
        banner.LocText:SetText("|cff888888Drag anywhere with Left-Click • Position is auto-saved|r")
        banner.TopAccent:SetColorTexture(1.0, 0.84, 0.0, 1.0)
        banner:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0)
        banner:Show()
        print("|cff00ccff[WoWKB Alert]|r Kill Banner unlocked. Drag with |cffffd100Left-Click|r. Type |cffffd100/wowkb move|r again or click Lock to save.")
    else
        banner:Hide()
        print("|cff00ccff[WoWKB Alert]|r Kill Banner position locked and saved.")
    end

    if UI.AlertsDialog and UI.AlertsDialog.UpdateControls then
        UI.AlertsDialog:UpdateControls()
    end
end

-- Reset Banner to Default Center-Top Position
function UI:ResetBannerPosition()
    if InCombatLockdown() then return end
    if not UI.KillBanner then
        UI:InitializeKillBanner()
    end
    if WoWKillboardSettings then
        WoWKillboardSettings.bannerPosition = nil
    end
    if UI.KillBanner then
        UI.KillBanner:ClearAllPoints()
        UI.KillBanner:SetPoint("TOP", UIParent, "TOP", 0, -135)
    end
    print("|cff00ccff[WoWKB Alert]|r Kill Banner position reset to default screen coordinates.")
end

-- Fire Test Banner Preview
function UI:TestKillBanner()
    local myName = UnitName("player") or "Player"
    local _, pClass = UnitClass("player")
    local currentZone = (GetZoneText and GetZoneText() ~= "") and GetZoneText() or "Stranglethorn Vale"
    local testKM = {
        killId = "TEST-" .. tostring(time()),
        timestamp = time(),
        isSolo = true,
        isBattleground = false,
        isArena = false,
        isDuel = false,
        attackersCount = 1,
        killer = {
            name = myName,
            class = pClass or "WARRIOR",
            level = UnitLevel("player") or 60,
        },
        victim = {
            name = "EnemyScout",
            class = "ROGUE",
            level = 60,
        },
        location = {
            zone = currentZone,
            subZone = "Gurubashi Arena",
            x = 45.2,
            y = 38.6,
        },
    }
    UI:ShowKillBanner(testKM, true)
end

-- Alerts & Radar Configuration Modal Dialog (100% Template-Free, Zero-Taint)
function UI:ShowAlertsConfig()
    if InCombatLockdown() then
        print("|cffff9900[WoWKB]|r Cannot open configuration during combat.")
        return
    end

    if not UI.AlertsDialog then
        local dlg = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        dlg:SetSize(480, 440)
        dlg:SetPoint("CENTER", 0, 30)
        dlg:SetFrameStrata("DIALOG")
        dlg:SetFrameLevel(120)
        dlg:EnableMouse(true)
        dlg:SetClampedToScreen(true)
        dlg:SetMovable(true)
        dlg:RegisterForDrag("LeftButton")
        dlg:SetScript("OnDragStart", function(self)
            if not InCombatLockdown() then self:StartMoving() end
        end)
        dlg:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
        end)

        -- ESC Key Handling
        dlg:EnableKeyboard(true)
        dlg:SetPropagateKeyboardInput(true)
        dlg:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                if UI.bannerUnlocked then UI:ToggleBannerLock(false) end
                self:SetPropagateKeyboardInput(false)
                self:Hide()
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)

        -- Header
        local title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        title:SetText("|cffffd100FRONTLINE COMBAT ALERTS & RADAR|r")
        dlg.TitleText = title

        local subtitle = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subtitle:SetPoint("TOP", 0, -38)
        subtitle:SetText("|cff94a3b8Configure on-screen kill banners, audio feedback, raid warnings & positioning|r")
        dlg.SubtitleText = subtitle

        local div = dlg:CreateTexture(nil, "ARTWORK")
        div:SetHeight(1)
        div:SetPoint("TOPLEFT", 18, -56)
        div:SetPoint("TOPRIGHT", -18, -56)
        dlg.Divider = div

        -- Section 1: Alert Mode (Audio & Visual)
        local sec1Title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec1Title:SetPoint("TOPLEFT", 24, -68)
        sec1Title:SetText("|cffffffff1. DISPLAY & AUDIO FEEDBACK|r")

        local modeBtn = UI:CreateButton(dlg, 280, 24, "Sound + Banner", "GameFontHighlightSmall")
        modeBtn:SetPoint("TOPLEFT", 24, -88)
        dlg.ModeBtn = modeBtn

        local modeHint = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        modeHint:SetPoint("TOPLEFT", 24, -116)
        dlg.ModeHint = modeHint

        -- Section 2: Proximity & Scope Filter (Radar)
        local sec2Title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec2Title:SetPoint("TOPLEFT", 24, -138)
        sec2Title:SetText("|cffffffff2. RADAR & PROXIMITY SCOPE|r")

        local scopeBtn = UI:CreateButton(dlg, 280, 24, "Same Zone Only", "GameFontHighlightSmall")
        scopeBtn:SetPoint("TOPLEFT", 24, -158)
        dlg.ScopeBtn = scopeBtn

        local scopeHint = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        scopeHint:SetPoint("TOPLEFT", 24, -186)
        dlg.ScopeHint = scopeHint

        -- Section 3: Raid Warning Screen Combat Notice
        local sec3Title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec3Title:SetPoint("TOPLEFT", 24, -208)
        sec3Title:SetText("|cffffffff3. RAID WARNING COMBAT NOTICE|r")

        local rwBtn = UI:CreateButton(dlg, 280, 24, "[ON] RAID WARNING", "GameFontHighlightSmall")
        rwBtn:SetPoint("TOPLEFT", 24, -228)
        dlg.RwBtn = rwBtn

        local rwHint = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rwHint:SetPoint("TOPLEFT", 24, -256)
        dlg.RwHint = rwHint

        -- Section 4: Banner Position & Repositioning
        local sec4Title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec4Title:SetPoint("TOPLEFT", 24, -278)
        sec4Title:SetText("|cffffffff4. SCREEN POSITIONING & CALIBRATION|r")

        local unlockBtn = UI:CreateButton(dlg, 200, 24, "Move / Unlock Banner", "GameFontHighlightSmall")
        unlockBtn:SetPoint("TOPLEFT", 24, -298)
        dlg.UnlockBtn = unlockBtn

        local resetBtn = UI:CreateButton(dlg, 140, 24, "Reset Position", "GameFontHighlightSmall")
        resetBtn:SetPoint("LEFT", unlockBtn, "RIGHT", 10, 0)
        dlg.ResetBtn = resetBtn

        local posHint = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        posHint:SetPoint("TOPLEFT", 24, -326)
        posHint:SetText("|cff94a3b8Unlock to drag banner anywhere on screen. Position is auto-saved.|r")
        dlg.PosHint = posHint

        -- Bottom Divider
        local bDiv = dlg:CreateTexture(nil, "ARTWORK")
        bDiv:SetHeight(1)
        bDiv:SetPoint("TOPLEFT", 18, -350)
        bDiv:SetPoint("TOPRIGHT", -18, -350)
        dlg.BottomDivider = bDiv

        -- Footer Action Buttons
        local testBtn = UI:CreateButton(dlg, 180, 28, "Test Alert Preview", "GameFontNormal")
        testBtn:SetPoint("BOTTOMLEFT", 24, 20)
        dlg.TestBtn = testBtn

        local closeBtn = UI:CreateButton(dlg, 120, 28, "Close", "GameFontHighlight")
        closeBtn:SetPoint("BOTTOMRIGHT", -24, 20)
        dlg.CloseBtn = closeBtn

        -- Synchronize Controls
        local function UpdateControls()
            local s = WoWKillboardSettings or KB.DefaultSettings
            local mode = s.alertMode or "SOUND_AND_BANNER"
            local scope = s.alertScope or "ZONE"
            local rw = s.alertRaidWarning ~= false

            if mode == "SOUND_AND_BANNER" then
                dlg.ModeBtn.Label:SetText("|cff00ff00[ACTIVE] Sound + Banner|r")
                dlg.ModeHint:SetText("|cff94a3b8Plays audio alert and displays on-screen kill banner.|r")
            elseif mode == "BANNER_ONLY" then
                dlg.ModeBtn.Label:SetText("|cffffd100[MUTED] Banner Only|r")
                dlg.ModeHint:SetText("|cff94a3b8Displays on-screen kill banner with zero audio feedback.|r")
            else
                dlg.ModeBtn.Label:SetText("|cffff3333[DISABLED] Alerts Off|r")
                dlg.ModeHint:SetText("|cff94a3b8Suppresses all kill banners, sounds, and raid warnings.|r")
            end

            if scope == "ZONE" then
                dlg.ScopeBtn.Label:SetText("|cff00e5ff[RADAR] Same Zone Only|r")
                dlg.ScopeHint:SetText("|cff94a3b8Alerts only when combat occurs in your current zone.|r")
            elseif scope == "ALL" then
                dlg.ScopeBtn.Label:SetText("|cffffd700[BROADCAST] All Realm Kills|r")
                dlg.ScopeHint:SetText("|cff94a3b8Alerts for all kills broadcasted across realm network.|r")
            else
                dlg.ScopeBtn.Label:SetText("|cff10b981[SOLO] My Kills & Deaths Only|r")
                dlg.ScopeHint:SetText("|cff94a3b8Only triggers when you personally kill or are killed.|r")
            end

            if rw then
                dlg.RwBtn.Label:SetText("|cff00ff00[ON] RAID WARNING|r")
                dlg.RwHint:SetText("|cff94a3b8Flashes large Raid Warning text in screen center on kill.|r")
            else
                dlg.RwBtn.Label:SetText("|cffff3333[OFF] RAID WARNING|r")
                dlg.RwHint:SetText("|cff94a3b8Suppresses screen-center Raid Warning combat notice.|r")
            end

            if UI.bannerUnlocked then
                dlg.UnlockBtn.Label:SetText("|cffff3333Lock Banner Position|r")
            else
                dlg.UnlockBtn.Label:SetText("|cffffd100Move / Unlock Banner|r")
            end
        end
        dlg.UpdateControls = UpdateControls

        -- Button Event Handlers
        modeBtn:SetScript("OnClick", function()
            local s = WoWKillboardSettings or KB.DefaultSettings
            if s.alertMode == "SOUND_AND_BANNER" then
                s.alertMode = "BANNER_ONLY"
                s.soundAlerts = false
            elseif s.alertMode == "BANNER_ONLY" then
                s.alertMode = "OFF"
                s.soundAlerts = false
            else
                s.alertMode = "SOUND_AND_BANNER"
                s.soundAlerts = true
            end
            UpdateControls()
        end)

        scopeBtn:SetScript("OnClick", function()
            local s = WoWKillboardSettings or KB.DefaultSettings
            if s.alertScope == "ZONE" then
                s.alertScope = "ALL"
            elseif s.alertScope == "ALL" then
                s.alertScope = "MINE"
            else
                s.alertScope = "ZONE"
            end
            UpdateControls()
        end)

        rwBtn:SetScript("OnClick", function()
            local s = WoWKillboardSettings or KB.DefaultSettings
            s.alertRaidWarning = not (s.alertRaidWarning ~= false)
            UpdateControls()
        end)

        unlockBtn:SetScript("OnClick", function()
            UI:ToggleBannerLock()
            UpdateControls()
        end)

        resetBtn:SetScript("OnClick", function()
            UI:ResetBannerPosition()
        end)

        testBtn:SetScript("OnClick", function()
            UI:TestKillBanner()
        end)

        closeBtn:SetScript("OnClick", function()
            if UI.bannerUnlocked then UI:ToggleBannerLock(false) end
            dlg:Hide()
        end)

        UI.AlertsDialog = dlg
    end

    -- Theme Backdrop Styling
    local theme = UI:GetTheme()
    UI.AlertsDialog:SetBackdrop(theme.modalBackdrop or {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    UI.AlertsDialog:SetBackdropColor(unpack(theme.modalBg or {0.035, 0.045, 0.07, 0.98}))
    UI.AlertsDialog:SetBackdropBorderColor(unpack(theme.modalBorder or {0.45, 0.35, 0.18, 0.95}))
    if UI.AlertsDialog.Divider and theme.dividerColor then
        UI.AlertsDialog.Divider:SetColorTexture(unpack(theme.dividerColor))
    end
    if UI.AlertsDialog.BottomDivider and theme.dividerColor then
        UI.AlertsDialog.BottomDivider:SetColorTexture(unpack(theme.dividerColor))
    end

    UI.AlertsDialog.UpdateControls()
    UI.AlertsDialog:Show()
    if UI.AlertsDialog.Raise then UI.AlertsDialog:Raise() end
end


