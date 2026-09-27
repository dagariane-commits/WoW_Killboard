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
local activeTab = "FEED"   -- "FEED", "LEADERBOARD", "BOUNTIES", "ZONES"
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
        if t == "classic" or t == "elvui" then return t end
    end
    return "classic"
end

function UI:GetTheme()
    local name = UI:GetCurrentThemeName()
    return (KB.Themes and KB.Themes[name]) or (KB.Themes and KB.Themes["classic"]) or (KB.Themes and KB.Themes["elvui"]) or {}
end

function UI:SetTheme(themeName)
    themeName = (themeName or ""):lower()
    if themeName ~= "classic" and themeName ~= "elvui" then
        themeName = "classic"
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

function UI:ApplyButtonStyle(btn, theme)
    if not btn then return end
    theme = theme or UI:GetTheme()
    if theme.id == "classic" then
        btn:SetBackdrop(nil)
        btn:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
        btn:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
        btn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight", "ADD")
        btn:SetDisabledTexture("Interface\\Buttons\\UI-Panel-Button-Disabled")
        local nt = btn:GetNormalTexture()
        if nt then nt:Show() end
        local pt = btn:GetPushedTexture()
        if pt then pt:Show() end
        local ht = btn:GetHighlightTexture()
        if ht then ht:Show() end
        if btn.Label then
            btn.Label:SetTextColor(1.0, 0.82, 0.0)
        end
    else
        local nt = btn:GetNormalTexture()
        if nt then nt:SetTexture(nil) nt:Hide() end
        local pt = btn:GetPushedTexture()
        if pt then pt:SetTexture(nil) pt:Hide() end
        local ht = btn:GetHighlightTexture()
        if ht then ht:SetTexture(nil) ht:Hide() end
        if theme.btnBackdrop then
            btn:SetBackdrop(theme.btnBackdrop)
            btn:SetBackdropColor(unpack(theme.btnBg))
            btn:SetBackdropBorderColor(unpack(theme.btnBorder))
        end
        if btn.Label then
            btn.Label:SetTextColor(1.0, 1.0, 1.0)
        end
    end
end

function UI:ApplyTheme()
    if not mainFrame then return end
    local theme = UI:GetTheme()
    if not theme or not theme.mainBackdrop then return end

    if UI.SolidBg then
        if theme.id == "classic" then
            UI.SolidBg:Hide()
        else
            UI.SolidBg:Show()
            UI.SolidBg:SetColorTexture(unpack(theme.solidBg or theme.mainBg))
        end
    end

    mainFrame:SetBackdrop(theme.mainBackdrop)
    mainFrame:SetBackdropColor(unpack(theme.mainBg))
    mainFrame:SetBackdropBorderColor(unpack(theme.mainBorder))

    if UI.ContentInset then
        UI.ContentInset:SetBackdrop(theme.insetBackdrop or theme.cardBackdrop)
        UI.ContentInset:SetBackdropColor(unpack(theme.insetBg or theme.cardBg))
        UI.ContentInset:SetBackdropBorderColor(unpack(theme.insetBorder or theme.cardBorder))
        if UI.ContentInset.BgArt then
            if theme.id == "classic" then
                UI.ContentInset.BgArt:SetTexture("Interface\\QuestFrame\\QuestBG")
                UI.ContentInset.BgArt:SetTexCoord(0, 0.586, 0.02, 0.655)
                UI.ContentInset.BgArt:SetAlpha(1.0)
                if UI.ContentInset.Vignette then UI.ContentInset.Vignette:Hide() end
            else
                UI.ContentInset.BgArt:SetTexture("Interface\\AddOns\\WoWKillboard\\Textures\\dark_war_bg.tga")
                UI.ContentInset.BgArt:SetTexCoord(0, 1, 0, 1)
                UI.ContentInset.BgArt:SetAlpha(0.65)
                if UI.ContentInset.Vignette then
                    UI.ContentInset.Vignette:Show()
                    UI.ContentInset.Vignette:SetAlpha(0.40)
                end
            end
            UI.ContentInset.BgArt:Show()
        end
    end

    if UI.HeaderPlate then
        if theme.id == "classic" then
            UI.HeaderPlate:Show()
            if UI.TitleText then
                UI.TitleText:ClearAllPoints()
                UI.TitleText:SetPoint("TOP", mainFrame, "TOP", 0, -2)
                UI.TitleText:SetFontObject("GameFontNormalLarge")
            end
            if UI.SubtitleText and UI.TitleText then
                UI.SubtitleText:ClearAllPoints()
                UI.SubtitleText:SetPoint("TOP", UI.TitleText, "BOTTOM", 0, -2)
            end
        else
            UI.HeaderPlate:Hide()
            if UI.TitleText and UI.Medallion then
                UI.TitleText:ClearAllPoints()
                UI.TitleText:SetPoint("LEFT", UI.Medallion, "RIGHT", 14, 6)
                UI.TitleText:SetFontObject("GameFontNormalLarge")
            end
            if UI.SubtitleText and UI.TitleText then
                UI.SubtitleText:ClearAllPoints()
                UI.SubtitleText:SetPoint("TOPLEFT", UI.TitleText, "BOTTOMLEFT", 0, -3)
            end
        end
    end

    if UI.TitleText and KB.Utils and KB.Utils.GetClientFlavorTitle then
        UI.TitleText:SetText(KB.Utils.GetClientFlavorTitle())
    elseif UI.TitleText then
        UI.TitleText:SetText(theme.titleText)
    end
    if UI.SubtitleText then
        UI.SubtitleText:SetText(string.format("|cffc7b28cv%s|r", KB.Version))
    end
    if UI.ThemeButton then
        UI:ApplyButtonStyle(UI.ThemeButton, theme)
        if UI.ThemeButton.Label then UI.ThemeButton.Label:SetText(theme.themeBtnText) end
        if theme.id == "classic" then UI.ThemeButton:SetHeight(22) else UI.ThemeButton:SetHeight(20) end
    end
    if UI.AlertsButton then
        UI:ApplyButtonStyle(UI.AlertsButton, theme)
        if theme.id == "classic" then UI.AlertsButton:SetHeight(22) else UI.AlertsButton:SetHeight(20) end
    end
    if UI.CallBackupButton then
        UI:ApplyButtonStyle(UI.CallBackupButton, theme)
        if theme.id == "classic" then UI.CallBackupButton:SetHeight(22) else UI.CallBackupButton:SetHeight(20) end
    end
    if UI.RegisteredButtons then
        for _, b in ipairs(UI.RegisteredButtons) do
            UI:ApplyButtonStyle(b, theme)
        end
    end
    if UI.CloseButton then
        if theme.id == "classic" then
            UI.CloseButton:SetSize(32, 32)
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
            UI.CloseButton:SetDisabledTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Disabled")
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
            UI.CloseButton:SetBackdropBorderColor(0.0, 0.0, 0.0, 1.0)
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
            if card.HeaderStrip then
                card.HeaderStrip:SetColorTexture(unpack(theme.cardHeaderBg or {0.09, 0.12, 0.17, 1.0}))
            end
            if card.HeaderDivider then
                card.HeaderDivider:SetColorTexture(unpack(theme.cardHeaderBorder or {0.35, 0.28, 0.16, 0.8}))
            end
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
                UI.DetailModal.CloseBtn:SetBackdropBorderColor(0.0, 0.0, 0.0, 1.0)
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

    local label = btn:CreateFontString(nil, "OVERLAY", fontSize or "GameFontHighlightSmall")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text or "")
    btn.Label = label

    UI:ApplyButtonStyle(btn, UI:GetTheme())

    UI.RegisteredButtons = UI.RegisteredButtons or {}
    table.insert(UI.RegisteredButtons, btn)

    btn:SetScript("OnEnter", function(self)
        local t = UI:GetTheme()
        if t.id ~= "classic" then
            if not self.isActive and t.btnHoverBg then
                self:SetBackdropColor(unpack(t.btnHoverBg))
                self:SetBackdropBorderColor(unpack(t.btnHoverBorder))
            end
        end
    end)
    btn:SetScript("OnLeave", function(self)
        local t = UI:GetTheme()
        if t.id ~= "classic" then
            if not self.isActive and t.btnBg then
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

-- Helper: Update circular portrait medallion and player level
function UI:UpdatePortrait()
    if not UI.Medallion then return end
    if UI.Medallion.Portrait and SetPortraitTexture then
        pcall(SetPortraitTexture, UI.Medallion.Portrait, "player")
        if not UI.Medallion.Portrait:GetTexture() then
            UI.Medallion.Portrait:SetTexture("Interface\\Icons\\Achievement_PVP_P_01")
        end
    end
    if UI.Medallion.LevelBadge and UnitLevel then
        local pLvl = UnitLevel("player")
        if pLvl and pLvl > 0 then
            UI.Medallion.LevelBadge:SetText(string.format("|cffffd100%d|r", pLvl))
        end
    end
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
        UI:UpdatePortrait()
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
    mainFrame:SetSize(860, 580)
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

    -- Custom ESC key handling (100% taint-free, active strictly when shown)
    mainFrame:EnableKeyboard(false)
    mainFrame:SetScript("OnShow", function(self)
        if self.EnableKeyboard then self:EnableKeyboard(true) end
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
        UI:UpdatePortrait()
    end)
    mainFrame:SetScript("OnHide", function(self)
        if self.EnableKeyboard then self:EnableKeyboard(false) end
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
    end)
    mainFrame:SetScript("OnKeyDown", function(self, key)
        if not self:IsShown() then
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
            return
        end
        if key == "ESCAPE" then
            if UI.DetailModal and UI.DetailModal:IsShown() then
                if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
                UI.DetailModal:Hide()
                return
            end
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
            self:Hide()
        else
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
        end
    end)

    -- Opaque Base Layer (Active in ElvUI, Hidden in Classic to expose Blizzard Stone)
    local initTheme = UI:GetTheme()
    local solidBg = mainFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    solidBg:SetAllPoints(mainFrame)
    if initTheme.id == "classic" then
        solidBg:Hide()
    else
        solidBg:SetColorTexture(unpack(initTheme.solidBg or initTheme.mainBg or {0.045, 0.055, 0.08, 1.0}))
        solidBg:Show()
    end
    UI.SolidBg = solidBg

    -- Frame Backdrop from Active Theme (Blizzard Stone Dialog or ElvUI Minimalist)
    mainFrame:SetBackdrop(initTheme.mainBackdrop)
    mainFrame:SetBackdropColor(unpack(initTheme.mainBg or {1.0, 1.0, 1.0, 1.0}))
    mainFrame:SetBackdropBorderColor(unpack(initTheme.mainBorder or {1.0, 1.0, 1.0, 1.0}))

    -- Iconic Blizzard Circular Medallion Frame (Concentric & Grand in Header)
    local medallion = CreateFrame("Frame", nil, mainFrame)
    medallion:SetSize(60, 60)
    medallion:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 12, -6)
    medallion:SetFrameLevel(mainFrame:GetFrameLevel() + 5)

    local portBg = medallion:CreateTexture(nil, "BACKGROUND")
    portBg:SetSize(48, 48)
    portBg:SetPoint("CENTER", medallion, "CENTER", 0, 0)
    portBg:SetColorTexture(0.02, 0.02, 0.03, 1.0)

    local portrait = medallion:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(48, 48)
    portrait:SetPoint("CENTER", medallion, "CENTER", 0, 0)
    if SetPortraitTexture then
        pcall(SetPortraitTexture, portrait, "player")
    end
    if not portrait:GetTexture() then
        portrait:SetTexture("Interface\\Icons\\Achievement_PVP_P_01")
    end
    portrait:SetTexCoord(0.12, 0.88, 0.12, 0.88) -- Concentric circular crop to prevent square corner bleed
    medallion.Portrait = portrait

    local ring = medallion:CreateTexture(nil, "OVERLAY")
    ring:SetSize(60, 60)
    ring:SetPoint("CENTER", medallion, "CENTER", 0, 0)
    ring:SetTexture("Interface\\AddOns\\WoWKillboard\\Textures\\medallion_border.tga")
    medallion.Ring = ring

    -- Circular Level Plate Backing
    local lvlFrame = CreateFrame("Frame", nil, medallion, "BackdropTemplate")
    lvlFrame:SetSize(20, 20)
    lvlFrame:SetPoint("BOTTOMRIGHT", medallion, "BOTTOMRIGHT", 2, -2)
    lvlFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    lvlFrame:SetBackdropColor(0.04, 0.05, 0.08, 0.95)
    lvlFrame:SetBackdropBorderColor(0.45, 0.35, 0.18, 0.95)

    local lvlBadge = lvlFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lvlBadge:SetPoint("CENTER", lvlFrame, "CENTER", 0, 0)
    if UnitLevel then
        local pLvl = UnitLevel("player")
        if pLvl and pLvl > 0 then
            lvlBadge:SetText(string.format("|cffffd100%d|r", pLvl))
        end
    end
    medallion.LevelBadge = lvlBadge
    -- Authentic Classic Dialog Arched Header Crest
    local headerPlate = mainFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    headerPlate:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    headerPlate:SetSize(340, 68)
    headerPlate:SetPoint("TOP", mainFrame, "TOP", 0, 14)
    UI.HeaderPlate = headerPlate

    -- Window Title Header (Dynamic Flavor & Realm Detection)
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", medallion, "RIGHT", 14, 6)
    if KB.Utils and KB.Utils.GetClientFlavorTitle then
        title:SetText(KB.Utils.GetClientFlavorTitle())
    else
        title:SetText("|cffffffffWoW Killboard|r |cff00e5ff[WoW Forever • PvP Realm]|r")
    end
    UI.TitleText = title

    local subtitle = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    subtitle:SetText("|cffc7b28cv" .. KB.Version .. "|r")
    UI.SubtitleText = subtitle

    -- Template-Free Close Button
    local closeBtn = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
    closeBtn:SetSize(26, 26)
    closeBtn:SetPoint("TOPRIGHT", -8, -10)
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
        local nextTheme = (cur == "classic") and "elvui" or "classic"
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
            GameTooltip:AddLine("|cffff3333WAR HORN: Call to Arms|r", 1, 1, 1)
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

    -- 3 KPI Stat Cards (Authentic Warcraft Attribute Plate Style - Clean Vertical Separation)
    local cardConfigs = {
        { id = "KD",    title = "SESSION COMBAT K/D",   color = "ffd100", w = 268 },
        { id = "DUELS", title = "1v1 DUELS RECORD",     color = "ffb82e", w = 268 },
        { id = "BGS",   title = "BATTLEGROUNDS RECORD", color = "00e5ff", w = 268 },
    }

    UI.StatCards = {}
    local prevCard = nil
    for _, cfg in ipairs(cardConfigs) do
        local card = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
        card:SetSize(cfg.w, 42)
        if not prevCard then
            card:SetPoint("TOPLEFT", 14, -70)
        else
            card:SetPoint("LEFT", prevCard, "RIGHT", 14, 0)
        end
        card.rawTitle = cfg.title

        -- Header Strip Bar (Character Attribute Ribbon)
        local hStrip = card:CreateTexture(nil, "BACKGROUND", nil, -5)
        hStrip:SetPoint("TOPLEFT", 2, -2)
        hStrip:SetPoint("TOPRIGHT", -2, -2)
        hStrip:SetHeight(16)
        hStrip:SetColorTexture(0.09, 0.12, 0.17, 1.0)
        card.HeaderStrip = hStrip

        local hDiv = card:CreateTexture(nil, "BACKGROUND", nil, -4)
        hDiv:SetPoint("TOPLEFT", hStrip, "BOTTOMLEFT", 0, 0)
        hDiv:SetPoint("TOPRIGHT", hStrip, "BOTTOMRIGHT", 0, 0)
        hDiv:SetHeight(1)
        hDiv:SetColorTexture(0.35, 0.28, 0.16, 0.8)
        card.HeaderDivider = hDiv

        local topLabel = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        topLabel:SetPoint("CENTER", hStrip, "CENTER", 0, 0)
        topLabel:SetText(string.format("|cff%s%s|r", cfg.color, cfg.title))
        card.TitleLabel = topLabel

        local valLabel = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        valLabel:SetPoint("CENTER", card, "CENTER", 0, -8)
        valLabel:SetText("0 / 0")
        card.ValueLabel = valLabel

        card:EnableMouse(true)
        local cardId = cfg.id
        card:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if cardId == "KD" then
                GameTooltip:AddLine("|cffffd100Session Combat K/D|r", 1, 1, 1)
                GameTooltip:AddLine("Personal session combat record (You) and total open-world PvP kills logged.", 0.8, 0.8, 0.8)
            elseif cardId == "DUELS" then
                GameTooltip:AddLine("|cffffb82e1v1 Duels Record|r", 1, 1, 1)
                GameTooltip:AddLine("Personal duel record (You) and total witnessed realm duels logged on board.", 0.8, 0.8, 0.8)
            elseif cardId == "BGS" then
                GameTooltip:AddLine("|cff00e5ffBattlegrounds Record|r", 1, 1, 1)
                GameTooltip:AddLine("Personal battleground record (You) and total battleground matches logged.", 0.8, 0.8, 0.8)
            end
            GameTooltip:Show()
        end)
        card:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        UI.StatCards[cfg.id] = card
        prevCard = card
    end

    -- 1px Dividing Rule
    local divider = mainFrame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 14, -118)
    divider:SetPoint("TOPRIGHT", -14, -118)
    divider:SetHeight(1)
    divider:SetColorTexture(0.35, 0.28, 0.16, 0.9)
    UI.Divider = divider

    -- Navigation Bar (Tabs on Left, Filter Pills on Right - Zero Overlap)
    local tabs = {
        { id = "FEED",        text = "Intel",           w = 70 },
        { id = "LEADERBOARD", text = "Hall of Legends", w = 112 },
        { id = "BOUNTIES",    text = "Marks of Spite",  w = 108 },
        { id = "ZONES",       text = "Zone Intel",      w = 84 },
    }

    tabButtons = {}
    local prevTab = nil
    for _, t in ipairs(tabs) do
        local btn = UI:CreateButton(mainFrame, t.w, 24, t.text, "GameFontHighlightSmall")
        if not prevTab then
            btn:SetPoint("TOPLEFT", 14, -124)
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
            pill:SetPoint("TOPRIGHT", -14, -125)
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

    -- Dedicated Content Inset Panel (Sunken Vault Plate with Website Battlefield Artwork)
    local inset = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    inset:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14, -154)
    inset:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -14, 14)
    inset:SetFrameLevel(mainFrame:GetFrameLevel() + 1)
    UI.ContentInset = inset

    -- Website Dark War Battlefield Artwork Layer
    local bgArt = inset:CreateTexture(nil, "BACKGROUND", nil, -5)
    bgArt:SetAllPoints(inset)
    bgArt:SetTexture("Interface\\AddOns\\WoWKillboard\\Textures\\dark_war_bg.tga")
    bgArt:SetTexCoord(0, 1, 0, 1)
    bgArt:SetAlpha(0.65)
    inset.BgArt = bgArt

    -- Soft dark gradient vignette so kill rows remain 100% readable
    local vignette = inset:CreateTexture(nil, "BACKGROUND", nil, -4)
    vignette:SetAllPoints(inset)
    vignette:SetColorTexture(0.015, 0.02, 0.035, 0.40)
    inset.Vignette = vignette

    -- Scroll Area Container (Anchored securely inside ContentInset)
    local container = CreateFrame("ScrollFrame", nil, inset)
    container:SetPoint("TOPLEFT", inset, "TOPLEFT", 6, -6)
    container:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -6, 6)
    container:EnableMouseWheel(true)
    container:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = math.max(0, (UI.ContentFrame:GetHeight() or 400) - self:GetHeight())
        local newScroll = math.max(0, math.min(maxScroll, current - (delta * 36)))
        self:SetVerticalScroll(newScroll)
    end)

    local content = CreateFrame("Frame", nil, container)
    content:SetSize(820, 390)
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

    -- Calculate total activity across the board and reconcile player stats
    local totalKillsCount = 0
    local totalDuelsCount = (st.duels and st.duels.total) or 0
    local totalBgsCount = (st.bgs and st.bgs.total) or 0
    if WoWKillboardDB and WoWKillboardDB.kills then
        local pName = UnitName("player")
        local histWins, histLosses = 0, 0
        local duelKills, bgKills, worldKills = 0, 0, 0
        for _, km in pairs(WoWKillboardDB.kills) do
            if km.isDuel then
                duelKills = duelKills + 1
                if pName then
                    local isW = (km.killer and km.killer.name and (km.killer.name:lower():find(pName:lower(), 1, true) ~= nil))
                    local isL = (km.victim and km.victim.name and (km.victim.name:lower():find(pName:lower(), 1, true) ~= nil))
                    if isW then histWins = histWins + 1 end
                    if isL then histLosses = histLosses + 1 end
                end
            elseif km.isBattleground then
                bgKills = bgKills + 1
            else
                worldKills = worldKills + 1
            end
        end
        if st.duels then
            st.duels.wins = math.max(st.duels.wins or 0, histWins)
            st.duels.losses = math.max(st.duels.losses or 0, histLosses)
            st.duels.total = math.max(st.duels.total or 0, duelKills)
        end
        totalDuelsCount = math.max(totalDuelsCount, duelKills)
        totalBgsCount = math.max(totalBgsCount, bgKills)
        totalKillsCount = worldKills
    end

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
            UI.StatCards.KD.ValueLabel:SetText(string.format(
                "|cffffffff%d|rK / |cffff4444%d|rD |cff64748b(You)|r  |cff64748b•|r  |cffffd100%d|r |cff94a3b8Logged|r",
                s.kills, s.deaths, totalKillsCount
            ))
        end
        if UI.StatCards.DUELS and UI.StatCards.DUELS.ValueLabel then
            if dTot > 0 then
                UI.StatCards.DUELS.ValueLabel:SetText(string.format(
                    "|cffffffff%d|rW - |cffff4444%d|rL |cff64748b(%d%%)|r  |cff64748b•|r  |cffffd100%d|r |cff94a3b8Logged|r",
                    dW, dL, dRate, totalDuelsCount
                ))
            else
                UI.StatCards.DUELS.ValueLabel:SetText(string.format(
                    "|cffffffff0|rW - |cffff44440|rL |cff64748b(You)|r  |cff64748b•|r  |cffffd100%d|r |cff94a3b8Logged|r",
                    totalDuelsCount
                ))
            end
        end
        if UI.StatCards.BGS and UI.StatCards.BGS.ValueLabel then
            if bgTot > 0 then
                UI.StatCards.BGS.ValueLabel:SetText(string.format(
                    "|cffffffff%d|rW - |cffff4444%d|rL |cff64748b(%d%%)|r  |cff64748b•|r  |cff00e5ff%d|r |cff94a3b8Logged|r",
                    bgW, bgL, bgRate, totalBgsCount
                ))
            else
                UI.StatCards.BGS.ValueLabel:SetText(string.format(
                    "|cffffffff0|rW - |cffff44440|rL |cff64748b(You)|r  |cff64748b•|r  |cff00e5ff%d|r |cff94a3b8Logged|r",
                    totalBgsCount
                ))
            end
        end
    end

    local theme = UI:GetTheme()

    -- Update Tab Button Highlights
    for tid, btn in pairs(tabButtons) do
        if tid == activeTab then
            btn.isActive = true
            if theme.id == "classic" then
                btn:SetButtonState("PUSHED", true)
                btn.Label:SetTextColor(1.0, 0.82, 0.0)
            else
                if theme.btnBackdrop then btn:SetBackdrop(theme.btnBackdrop) end
                btn:SetBackdropColor(unpack(theme.btnActiveBg))
                btn:SetBackdropBorderColor(unpack(theme.btnActiveBorder))
                btn.Label:SetTextColor(1.0, 0.82, 0.0)
            end
        else
            btn.isActive = false
            if theme.id == "classic" then
                btn:SetButtonState("NORMAL", false)
                btn.Label:SetTextColor(0.85, 0.75, 0.60)
            else
                if theme.btnBackdrop then btn:SetBackdrop(theme.btnBackdrop) end
                btn:SetBackdropColor(unpack(theme.btnBg))
                btn:SetBackdropBorderColor(unpack(theme.btnBorder))
                btn.Label:SetTextColor(0.65, 0.65, 0.65)
            end
        end
    end

    -- Update Filter Pill Active Glow
    for fid, pill in pairs(filterButtons) do
        local c = pill.BaseColor or {1.0, 0.82, 0.0}
        if fid == currentMode then
            pill.isActive = true
            if theme.id == "classic" then
                pill:SetButtonState("PUSHED", true)
                pill.Label:SetTextColor(c[1], c[2], c[3])
            elseif theme.id == "elvui" then
                if theme.btnBackdrop then pill:SetBackdrop(theme.btnBackdrop) end
                pill:SetBackdropColor(0.20, 0.20, 0.20, 1.0)
                pill:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                pill.Label:SetTextColor(1.0, 0.82, 0.0)
            else
                if theme.btnBackdrop then pill:SetBackdrop(theme.btnBackdrop) end
                pill:SetBackdropColor(c[1] * 0.35, c[2] * 0.35, c[3] * 0.35, 1.0)
                pill:SetBackdropBorderColor(c[1], c[2], c[3], 1.0)
                pill.Label:SetTextColor(c[1], c[2], c[3])
            end
        else
            pill.isActive = false
            if theme.id == "classic" then
                pill:SetButtonState("NORMAL", false)
                pill.Label:SetTextColor(0.80, 0.70, 0.55)
            else
                if theme.btnBackdrop then pill:SetBackdrop(theme.btnBackdrop) end
                pill:SetBackdropColor(unpack(theme.btnBg))
                pill:SetBackdropBorderColor(unpack(theme.btnBorder))
                pill.Label:SetTextColor(0.65, 0.65, 0.65)
            end
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

    if activeTab == "FEED" or activeTab == "BG_METRICS" then
        activeTab = "FEED"
        UI:RenderLiveFeed()
    elseif activeTab == "LEADERBOARD" then
        UI:RenderLeaderboard()
    elseif activeTab == "BOUNTIES" then
        UI:RenderBounties()
    elseif activeTab == "ZONES" then
        UI:RenderZones()
    else
        activeTab = "FEED"
        UI:RenderLiveFeed()
    end
end

-- 1. Render Live Killmail Feed
function UI:RenderLiveFeed()
    local kills = KB.Leaderboard:GetRecentKills(currentMode, 40)
    local yOffset = 0

    if #kills == 0 then
        if not UI.EmptyFeedText then
            UI.EmptyFeedText = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            UI.EmptyFeedText:SetPoint("TOP", UI.ContentFrame, "TOP", 0, -50)
            UI.EmptyFeedText:SetJustifyH("CENTER")
            UI.EmptyFeedText:SetSpacing(4)
        end
        local currentZone = (GetZoneText and GetZoneText() ~= "") and GetZoneText() or "Azeroth"
        local theme = UI:GetTheme()
        if theme and theme.id == "classic" then
            UI.EmptyFeedText:SetText(string.format(
                "|cff5a3205● FRONTLINE COMBAT RADAR ACTIVE|r\n\n" ..
                "|cff3d2817Sector Surveillance:|r |cff1a0f00%s|r   |cff7a5530•|r   |cff3d2817Filter Mode:|r |cff5a3205[%s]|r\n" ..
                "|cff3d2817Combat Engine Status:|r |cff006622RECORDING COMBAT|r |cff5c4028(No confirmed kills logged yet)|r\n\n" ..
                "|cff4a3520Killmails are automatically recorded upon confirming an open-world player kill,\n" ..
                "battleground victory, or sanctioned 1v1 duel.|r\n\n" ..
                "|cff5a3205Quick Test:|r |cff3d2817Type |cff804000/wowkb testkill|r to simulate a live combat encounter.|r",
                currentZone, currentMode
            ))
        else
            UI.EmptyFeedText:SetText(string.format(
                "|cffffd100● FRONTLINE COMBAT RADAR ONLINE|r\n\n" ..
                "|cff94a3b8Sector Surveillance:|r |cffffffff%s|r   |cff64748b•|r   |cff94a3b8Filter Mode:|r |cffffd100[%s]|r\n" ..
                "|cff94a3b8Combat Engine Status:|r |cff00ff00ARMED & LISTENING|r |cff64748b(Zero confirmed combat deaths yet)|r\n\n" ..
                "|cff888888Killmails are automatically recorded upon confirming an open-world player kill,\n" ..
                "battleground victory, or sanctioned 1v1 duel.|r\n\n" ..
                "|cff00e5ffQuick Verification:|r |cffccccccType |cffffd100/wowkb testkill|r to simulate a live killmail and preview the feed.|r",
                currentZone, currentMode
            ))
        end
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
        local kLvlVal = km.killer.level or 0
        local lvlColor = (theme.id == "classic") and "4a3520" or "94a3b8"
        kLvl:SetText((kLvlVal > 0) and string.format("|cff%s%d|r", lvlColor, kLvlVal) or "|cff64748b??|r")

        -- Killer Name & Guild
        local killerStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        killerStr:SetPoint("LEFT", kLvl, "RIGHT", 5, 0)
        local kGuildColor = (theme.id == "classic") and "5c4028" or "64748b"
        local kGuildStr = (km.killer.guild and km.killer.guild ~= "None") and string.format(" |cff%s<%s>|r", kGuildColor, km.killer.guild) or ""
        killerStr:SetText(KB.Utils.ColorizeByClass(km.killer.name, km.killer.class) .. kGuildStr)

        -- Action Verb Separator (Center)
        local actionVerb = km.isDuel and "defeated" or "destroyed"
        local sep = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        sep:SetPoint("LEFT", 330, 0)
        local verbColor = (theme.id == "classic") and "4a3520" or "64748b"
        sep:SetText(string.format("|cff%s%s|r", verbColor, actionVerb))

        -- Victim Class Icon
        local vIcon = UI:CreateClassIcon(row, km.victim.class, 20)
        vIcon:SetPoint("LEFT", 390, 0)

        -- Victim Level Pill
        local vLvl = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        vLvl:SetPoint("LEFT", vIcon, "RIGHT", 4, 0)
        local vLvlVal = km.victim.level or 0
        vLvl:SetText((vLvlVal > 0) and string.format("|cff%s%d|r", lvlColor, vLvlVal) or "|cff64748b??|r")

        -- Victim Name & Guild
        local victimStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        victimStr:SetPoint("LEFT", vLvl, "RIGHT", 5, 0)
        local vGuildColor = (theme.id == "classic") and "5c4028" or "64748b"
        local vGuildStr = (km.victim.guild and km.victim.guild ~= "None") and string.format(" |cff%s<%s>|r", vGuildColor, km.victim.guild) or ""
        victimStr:SetText(KB.Utils.ColorizeByClass(km.victim.name, km.victim.class) .. vGuildStr)

        -- Location & Timestamp (Right-Aligned)
        local infoStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        infoStr:SetPoint("RIGHT", -12, 0)
        local locName = km.isBattleground and (km.battlegroundName or "Battleground") or km.location.zone
        local locColor = (theme.id == "classic") and "1a0f00" or "cbd5e1"
        local timeColor = (theme.id == "classic") and "5c4028" or "64748b"
        infoStr:SetText(string.format("|cff%s%s|r  |cff%s• %s|r", locColor, locName, timeColor, KB.Utils.FormatTimeAgo(km.timestamp)))

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
            if theme.id == "classic" then
                row:SetBackdropColor(0.35, 0.15, 0.12, 0.35)
                row:SetBackdropBorderColor(0.70, 0.30, 0.20, 0.65)
            else
                row:SetBackdropColor(0.18, 0.08, 0.08, 0.9)
                row:SetBackdropBorderColor(0.50, 0.18, 0.18, 0.8)
            end

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
            if theme.id == "classic" then
                row:SetBackdropColor(0.20, 0.16, 0.12, 0.30)
                row:SetBackdropBorderColor(0.55, 0.45, 0.22, 0.60)
            else
                row:SetBackdropColor(0.08, 0.08, 0.10, 0.85)
                row:SetBackdropBorderColor(0.25, 0.25, 0.30, 0.7)
            end

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
            if theme.id == "classic" then
                row:SetBackdropColor(0.40, 0.12, 0.12, 0.40)
                row:SetBackdropBorderColor(0.75, 0.25, 0.25, 0.70)
            else
                row:SetBackdropColor(0.24, 0.06, 0.06, 0.92)
                row:SetBackdropBorderColor(0.60, 0.15, 0.15, 0.9)
            end

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
    local modalSolid = modal:CreateTexture(nil, "BACKGROUND", nil, -8)
    modalSolid:SetAllPoints(modal)
    modalSolid:SetColorTexture(0.04, 0.05, 0.07, 1.0)
    modal.SolidBg = modalSolid

    modal:SetBackdrop(theme.modalBackdrop or {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    modal:SetBackdropColor(unpack(theme.modalBg or {0.05, 0.05, 0.05, 1.0}))
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

        -- Safe ESC key handling (100% taint-free, only active when shown)
        dlg:EnableKeyboard(false)
        dlg:SetScript("OnShow", function(self)
            if self.EnableKeyboard then self:EnableKeyboard(true) end
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
        end)
        dlg:SetScript("OnHide", function(self)
            if self.EnableKeyboard then self:EnableKeyboard(false) end
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
        end)
        dlg:SetScript("OnKeyDown", function(self, key)
            if not self:IsShown() then
                if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
                return
            end
            if key == "ESCAPE" then
                if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
                self:Hide()
            else
                if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
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

        dlg:EnableKeyboard(false)
        dlg:SetScript("OnShow", function(self)
            if self.EnableKeyboard then self:EnableKeyboard(true) end
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
        end)
        dlg:SetScript("OnHide", function(self)
            if self.EnableKeyboard then self:EnableKeyboard(false) end
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
        end)
        dlg:SetScript("OnKeyDown", function(self, key)
            if not self:IsShown() then
                if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
                return
            end
            if key == "ESCAPE" then
                if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
                self:Hide()
            else
                if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
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
-- Frontline Combat Alerts & Raid Warning Notice (100% Template-Free, Taint-Free)
-- ----------------------------------------------------------------------------
local killBanner = nil
local killBannerTimer = nil
local raidNoticeFrame = nil
local raidNoticeTimer = nil

function UI:InitializeRaidNotice()
    if raidNoticeFrame or InCombatLockdown() then return end

    raidNoticeFrame = CreateFrame("Frame", nil, UIParent)
    raidNoticeFrame:SetSize(860, 80)
    raidNoticeFrame:SetFrameStrata("HIGH")
    raidNoticeFrame:SetClampedToScreen(true)
    raidNoticeFrame:EnableMouse(false)

    -- Anchor relative to UIParent
    local pos = WoWKillboardSettings and WoWKillboardSettings.bannerPosition
    if pos and pos.point and pos.relPoint and pos.x and pos.y then
        raidNoticeFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y - 65)
    else
        raidNoticeFrame:SetPoint("TOP", UIParent, "TOP", 0, -200)
    end

    local mainText = raidNoticeFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    mainText:SetPoint("TOP", 0, 0)
    local fontFile, fontSize = mainText:GetFont()
    if fontFile then
        mainText:SetFont(fontFile, math.max(fontSize or 20, 22), "THICKOUTLINE")
    end
    mainText:SetJustifyH("CENTER")
    raidNoticeFrame.MainText = mainText

    local subText = raidNoticeFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subText:SetPoint("TOP", mainText, "BOTTOM", 0, -4)
    local sFontFile, sFontSize = subText:GetFont()
    if sFontFile then
        subText:SetFont(sFontFile, math.max(sFontSize or 14, 15), "OUTLINE")
    end
    subText:SetJustifyH("CENTER")
    raidNoticeFrame.SubText = subText

    raidNoticeFrame:Hide()
    UI.RaidNoticeFrame = raidNoticeFrame
end

function UI:ShowRaidNotice(mainMsg, subMsg, r, g, b)
    if not raidNoticeFrame then
        UI:InitializeRaidNotice()
    end
    if not raidNoticeFrame then return end

    raidNoticeFrame.MainText:SetText(mainMsg or "")
    if r and g and b then
        raidNoticeFrame.MainText:SetTextColor(r, g, b, 1.0)
    else
        raidNoticeFrame.MainText:SetTextColor(1.0, 0.28, 0.0, 1.0)
    end

    if subMsg and subMsg ~= "" then
        raidNoticeFrame.SubText:SetText(subMsg)
        raidNoticeFrame.SubText:Show()
    else
        raidNoticeFrame.SubText:Hide()
    end

    raidNoticeFrame:SetAlpha(1.0)
    raidNoticeFrame:Show()

    if raidNoticeTimer then raidNoticeTimer:Cancel() end
    raidNoticeTimer = C_Timer.NewTimer(4.5, function()
        if raidNoticeFrame and raidNoticeFrame:IsShown() then
            raidNoticeFrame:Hide()
        end
    end)
end

function UI:InitializeKillBanner()
    if killBanner or InCombatLockdown() then return end

    killBanner = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    killBanner:SetSize(540, 54)
    killBanner:SetFrameStrata("HIGH")
    killBanner:SetClampedToScreen(true)
    killBanner:SetMovable(true)
    killBanner:EnableMouse(false) -- Guardrail 1: Click-through during combat to prevent taint
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
            x = math.floor((x or 0) + 0.5),
            y = math.floor((y or -135) + 0.5),
        }
        if self.LocText then
            self.LocText:SetText(string.format("|cff00e5ffCurrent Anchor: %s (X: %d, Y: %d)|r", point or "TOP", math.floor((x or 0) + 0.5), math.floor((y or -135) + 0.5)))
        end
        if raidNoticeFrame then
            raidNoticeFrame:ClearAllPoints()
            raidNoticeFrame:SetPoint(point or "TOP", UIParent, relPoint or "TOP", math.floor((x or 0) + 0.5), math.floor((y or -135) + 0.5) - 65)
        end
        if UI.AlertsDialog and UI.AlertsDialog.UpdateControls then
            UI.AlertsDialog:UpdateControls()
        end
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
    local alertStyle = settings.alertStyle or "BOTH"

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

    -- 4. Taint-Free Raid Warning Screen Combat Notice (Zero Blizzard FrameXML taint)
    if alertStyle == "BOTH" or alertStyle == "RAID_WARNING" then
        local kName = killmail.killer.name or "Unknown"
        local vName = killmail.victim.name or "Unknown"
        local loc = killmail.location or {}
        local zName = (loc.zone and loc.zone ~= "") and loc.zone or (GetZoneText and GetZoneText()) or "Azeroth"
        local rwMain = string.format("|cffff3333[WoWKB]|r %s destroyed %s", kName, vName)
        local rwSub = string.format("|cffffd100%s|r", zName)
        if loc.subZone and loc.subZone ~= "" then
            rwSub = rwSub .. " - " .. loc.subZone
        end
        if killmail.isSolo then
            rwSub = rwSub .. " • |cff00ff00Certified 1v1 Solo Kill|r"
        elseif killmail.isDuel then
            rwSub = rwSub .. " • |cffffd7001v1 Certified Duel|r"
        elseif killmail.isBattleground then
            rwSub = rwSub .. string.format(" • |cff00ccff%s|r", killmail.battlegroundName or "Battleground")
        elseif killmail.attackersCount and killmail.attackersCount > 1 then
            rwSub = rwSub .. string.format(" • |cffff9900Gang Combat (x%d)|r", killmail.attackersCount)
        end
        UI:ShowRaidNotice(rwMain, rwSub, 1.0, 0.28, 0.0)
    end

    -- 5. Frontline Kill Banner Frame
    if alertStyle == "BOTH" or alertStyle == "BANNER" then
        if not UI.KillBanner then
            UI:InitializeKillBanner()
        end

        local banner = UI.KillBanner
        if not banner then return end

        -- Setup Killer Icon & Name
        local kClass = (killmail.killer.class or ""):upper()
        local kCoords = CLASS_COORDS[kClass] or {0, 0.25, 0, 0.25}
        banner.KillerIcon:SetTexture(CLASS_ICON_TEXTURE)
        banner.KillerIcon:SetTexCoord(kCoords[1], kCoords[2], kCoords[3], kCoords[4])
        local kLevelStr = (killmail.killer.level and killmail.killer.level > 0) and tostring(killmail.killer.level) or "??"
        banner.KillerText:SetText(KB.Utils.ColorizeByClass(string.format("[%s] %s", kLevelStr, killmail.killer.name or "Unknown"), killmail.killer.class))

        -- Setup Victim Icon & Name
        local vClass = (killmail.victim.class or ""):upper()
        local vCoords = CLASS_COORDS[vClass] or {0, 0.25, 0, 0.25}
        banner.VictimIcon:SetTexture(CLASS_ICON_TEXTURE)
        banner.VictimIcon:SetTexCoord(vCoords[1], vCoords[2], vCoords[3], vCoords[4])
        local vLevelStr = (killmail.victim.level and killmail.victim.level > 0) and tostring(killmail.victim.level) or "??"
        banner.VictimText:SetText(KB.Utils.ColorizeByClass(string.format("[%s] %s", vLevelStr, killmail.victim.name or "Unknown"), killmail.victim.class))

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
end

-- Toggle Banner Drag / Positioning Mode
function UI:ToggleBannerLock(explicitState)
    if InCombatLockdown() then
        print("|cffff9900[WoWKB]|r Cannot move alert banner during combat.")
        return
    end
    if not UI.KillBanner then
        UI:InitializeKillBanner()
    end
    if not UI.RaidNoticeFrame then
        UI:InitializeRaidNotice()
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
        banner:EnableMouse(true) -- Enable mouse interaction only while repositioning
        banner.KillerIcon:SetTexture("Interface\\Icons\\INV_Sword_27")
        banner.KillerIcon:SetTexCoord(0, 1, 0, 1)
        banner.KillerText:SetText("|cff00ff00[60] Killer (You)|r")
        banner.VictimIcon:SetTexture("Interface\\Icons\\Achievement_PVP_P_01")
        banner.VictimIcon:SetTexCoord(0, 1, 0, 1)
        banner.VictimText:SetText("|cffff3333[60] Hostile Victim|r")
        banner.CenterAction:SetText("|cffffd100[DRAG TO MOVE ALERT ANCHOR]|r")
        banner.ModeTag:SetText("|cffffffffClick 'Lock Position' or type /wowkb move to save|r")
        local pos = WoWKillboardSettings and WoWKillboardSettings.bannerPosition or { point = "TOP", x = 0, y = -135 }
        banner.LocText:SetText(string.format("|cff00e5ffCurrent Anchor: %s (X: %d, Y: %d)|r", pos.point or "TOP", pos.x or 0, pos.y or -135))
        banner.TopAccent:SetColorTexture(1.0, 0.84, 0.0, 1.0)
        banner:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0)
        banner:Show()

        UI:ShowRaidNotice("|cffff3333[WoWKB RAID WARNING PREVIEW]|r Enemy Target Destroyed", "Raid Warning Style Text will display here", 1.0, 0.28, 0.0)

        print("|cff00ccff[WoWKB Alert]|r Alert Anchor unlocked! Click and drag with |cffffd100Left-Click|r anywhere on your screen. Type |cffffd100/wowkb move|r again or click Lock to save.")
    else
        banner:EnableMouse(false) -- Revert to click-through immediately
        banner:Hide()
        if raidNoticeFrame then raidNoticeFrame:Hide() end
        local pos = WoWKillboardSettings and WoWKillboardSettings.bannerPosition or { point = "TOP", x = 0, y = -135 }
        print(string.format("|cff00ccff[WoWKB Alert]|r Alert Anchor locked at %s (X: %d, Y: %d). Saved across reloads!", pos.point or "TOP", pos.x or 0, pos.y or -135))
    end

    if UI.AlertsDialog and UI.AlertsDialog.UpdateControls then
        UI.AlertsDialog:UpdateControls()
    end
end

-- Reset Banner to Default Center-Top Position
function UI:ResetBannerPosition()
    if InCombatLockdown() then return end
    if not UI.KillBanner then UI:InitializeKillBanner() end
    if not UI.RaidNoticeFrame then UI:InitializeRaidNotice() end

    if WoWKillboardSettings then
        WoWKillboardSettings.bannerPosition = nil
    end
    if UI.KillBanner then
        UI.KillBanner:ClearAllPoints()
        UI.KillBanner:SetPoint("TOP", UIParent, "TOP", 0, -135)
    end
    if UI.RaidNoticeFrame then
        UI.RaidNoticeFrame:ClearAllPoints()
        UI.RaidNoticeFrame:SetPoint("TOP", UIParent, "TOP", 0, -200)
    end
    print("|cff00ccff[WoWKB Alert]|r Alert position reset to default screen coordinates (Center-Top).")
    if UI.AlertsDialog and UI.AlertsDialog.UpdateControls then
        UI.AlertsDialog:UpdateControls()
    end
end

-- Fire Test Banner Preview
function UI:TestKillBanner()
    local myName = UnitName("player") or "Player"
    local _, pClass = UnitClass("player")
    local currentZone = (GetZoneText and GetZoneText() ~= "") and GetZoneText() or "Arathi Highlands"
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
            class = pClass or "PALADIN",
            level = UnitLevel("player") or 20,
        },
        victim = {
            name = "Shadowstalker",
            class = "ROGUE",
            level = 21,
        },
        location = {
            zone = currentZone,
            subZone = "Refuge Pointe",
            x = 45.2,
            y = 47.1,
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
        dlg:SetSize(520, 500)
        dlg:SetPoint("CENTER", 0, 20)
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

        -- ESC Key Handling (only active when shown)
        dlg:EnableKeyboard(false)
        dlg:SetScript("OnShow", function(self)
            if self.EnableKeyboard then self:EnableKeyboard(true) end
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
        end)
        dlg:SetScript("OnHide", function(self)
            if self.EnableKeyboard then self:EnableKeyboard(false) end
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
        end)
        dlg:SetScript("OnKeyDown", function(self, key)
            if not self:IsShown() then
                if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
                return
            end
            if key == "ESCAPE" then
                if UI.bannerUnlocked then UI:ToggleBannerLock(false) end
                if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
                self:Hide()
            else
                if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
            end
        end)

        -- Header
        local title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        title:SetText("|cffffd100FRONTLINE COMBAT ALERTS & RADAR|r")
        dlg.TitleText = title

        local subtitle = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subtitle:SetPoint("TOP", 0, -38)
        subtitle:SetText("|cff94a3b8Configure on-screen kill notifications, audio feedback, raid warnings & positioning|r")
        dlg.SubtitleText = subtitle

        local div = dlg:CreateTexture(nil, "ARTWORK")
        div:SetHeight(1)
        div:SetPoint("TOPLEFT", 18, -56)
        div:SetPoint("TOPRIGHT", -18, -56)
        dlg.Divider = div

        -- Helper to style segmented buttons
        local function StyleSegmentButton(btn, text)
            btn.baseText = text
            btn.Label:SetText(text)
        end

        -- Section 1: Alert Mode (Display & Sound)
        local sec1Title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec1Title:SetPoint("TOPLEFT", 24, -68)
        sec1Title:SetText("|cffffffff1. DISPLAY & AUDIO FEEDBACK|r")

        local btnModeSound = UI:CreateButton(dlg, 150, 24, "Sound + Alert", "GameFontHighlightSmall")
        btnModeSound:SetPoint("TOPLEFT", 24, -88)
        StyleSegmentButton(btnModeSound, "Sound + Alert")
        dlg.BtnModeSound = btnModeSound

        local btnModeMute = UI:CreateButton(dlg, 150, 24, "Alert Only", "GameFontHighlightSmall")
        btnModeMute:SetPoint("LEFT", btnModeSound, "RIGHT", 11, 0)
        StyleSegmentButton(btnModeMute, "Alert Only")
        dlg.BtnModeMute = btnModeMute

        local btnModeOff = UI:CreateButton(dlg, 150, 24, "Turn Off", "GameFontHighlightSmall")
        btnModeOff:SetPoint("LEFT", btnModeMute, "RIGHT", 11, 0)
        StyleSegmentButton(btnModeOff, "Turn Off")
        dlg.BtnModeOff = btnModeOff

        local modeHint = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        modeHint:SetPoint("TOPLEFT", 24, -116)
        dlg.ModeHint = modeHint

        -- Section 2: Proximity & Scope Filter (Radar)
        local sec2Title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec2Title:SetPoint("TOPLEFT", 24, -140)
        sec2Title:SetText("|cffffffff2. RADAR & PROXIMITY SCOPE|r")

        local btnScopeZone = UI:CreateButton(dlg, 150, 24, "Same Zone Only", "GameFontHighlightSmall")
        btnScopeZone:SetPoint("TOPLEFT", 24, -160)
        StyleSegmentButton(btnScopeZone, "Same Zone Only")
        dlg.BtnScopeZone = btnScopeZone

        local btnScopeAll = UI:CreateButton(dlg, 150, 24, "Entire Realm", "GameFontHighlightSmall")
        btnScopeAll:SetPoint("LEFT", btnScopeZone, "RIGHT", 11, 0)
        StyleSegmentButton(btnScopeAll, "Entire Realm")
        dlg.BtnScopeAll = btnScopeAll

        local btnScopeMine = UI:CreateButton(dlg, 150, 24, "Personal Only", "GameFontHighlightSmall")
        btnScopeMine:SetPoint("LEFT", btnScopeAll, "RIGHT", 11, 0)
        StyleSegmentButton(btnScopeMine, "Personal Only")
        dlg.BtnScopeMine = btnScopeMine

        local scopeHint = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        scopeHint:SetPoint("TOPLEFT", 24, -188)
        dlg.ScopeHint = scopeHint

        -- Section 3: Visual Alert Style (Raid Warning vs Tactical Banner)
        local sec3Title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec3Title:SetPoint("TOPLEFT", 24, -212)
        sec3Title:SetText("|cffffffff3. VISUAL ALERT STYLE|r")

        local btnStyleBoth = UI:CreateButton(dlg, 150, 24, "Both Displays", "GameFontHighlightSmall")
        btnStyleBoth:SetPoint("TOPLEFT", 24, -232)
        StyleSegmentButton(btnStyleBoth, "Both Displays")
        dlg.BtnStyleBoth = btnStyleBoth

        local btnStyleRW = UI:CreateButton(dlg, 150, 24, "Raid Warning", "GameFontHighlightSmall")
        btnStyleRW:SetPoint("LEFT", btnStyleBoth, "RIGHT", 11, 0)
        StyleSegmentButton(btnStyleRW, "Raid Warning")
        dlg.BtnStyleRW = btnStyleRW

        local btnStyleBanner = UI:CreateButton(dlg, 150, 24, "Tactical Banner", "GameFontHighlightSmall")
        btnStyleBanner:SetPoint("LEFT", btnStyleRW, "RIGHT", 11, 0)
        StyleSegmentButton(btnStyleBanner, "Tactical Banner")
        dlg.BtnStyleBanner = btnStyleBanner

        local styleHint = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        styleHint:SetPoint("TOPLEFT", 24, -260)
        dlg.StyleHint = styleHint

        -- Section 4: Screen Positioning & Calibration
        local sec4Title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec4Title:SetPoint("TOPLEFT", 24, -284)
        sec4Title:SetText("|cffffffff4. SCREEN POSITIONING & CALIBRATION|r")

        local unlockBtn = UI:CreateButton(dlg, 230, 24, "Move / Unlock Alert Anchor", "GameFontHighlightSmall")
        unlockBtn:SetPoint("TOPLEFT", 24, -304)
        dlg.UnlockBtn = unlockBtn

        local resetBtn = UI:CreateButton(dlg, 230, 24, "Reset to Center", "GameFontHighlightSmall")
        resetBtn:SetPoint("LEFT", unlockBtn, "RIGHT", 12, 0)
        dlg.ResetBtn = resetBtn

        local posHint = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        posHint:SetPoint("TOPLEFT", 24, -332)
        posHint:SetText("|cff94a3b8Click 'Move / Unlock' or type |cffffd100/wowkb move|r to drag alert anywhere on screen.|r")
        dlg.PosHint = posHint

        local posCoords = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        posCoords:SetPoint("TOPLEFT", 24, -348)
        dlg.PosCoords = posCoords

        -- Bottom Divider
        local bDiv = dlg:CreateTexture(nil, "ARTWORK")
        bDiv:SetHeight(1)
        bDiv:SetPoint("TOPLEFT", 18, -370)
        bDiv:SetPoint("TOPRIGHT", -18, -370)
        dlg.BottomDivider = bDiv

        -- Footer Action Buttons
        local testBtn = UI:CreateButton(dlg, 190, 28, "Test Alert Preview", "GameFontNormal")
        testBtn:SetPoint("BOTTOMLEFT", 24, 18)
        dlg.TestBtn = testBtn

        local closeBtn = UI:CreateButton(dlg, 120, 28, "Close", "GameFontHighlight")
        closeBtn:SetPoint("BOTTOMRIGHT", -24, 18)
        dlg.CloseBtn = closeBtn

        -- Helper to apply active/inactive visual state to segmented buttons
        local function ApplySegmentState(btn, isActive)
            btn.isActive = isActive
            local theme = UI:GetTheme()
            if isActive then
                btn:SetBackdropColor(unpack(theme.btnActiveBg or { 0.25, 0.18, 0.07, 1.0 }))
                btn:SetBackdropBorderColor(unpack(theme.btnActiveBorder or { 1.0, 0.82, 0.0, 1.0 }))
                btn.Label:SetText(string.format("|cff00ff00●|r |cffffd100%s|r", btn.baseText or ""))
            else
                btn:SetBackdropColor(unpack(theme.btnBg or { 0.08, 0.10, 0.15, 1.0 }))
                btn:SetBackdropBorderColor(unpack(theme.btnBorder or { 0.45, 0.35, 0.18, 0.95 }))
                btn.Label:SetText(string.format("|cff888888%s|r", btn.baseText or ""))
            end
        end

        -- Synchronize Controls
        local function UpdateControls()
            local s = WoWKillboardSettings or KB.DefaultSettings
            local mode = s.alertMode or "SOUND_AND_BANNER"
            local scope = s.alertScope or "ZONE"
            local style = s.alertStyle or "BOTH"

            -- Section 1: Display & Audio
            ApplySegmentState(dlg.BtnModeSound, mode == "SOUND_AND_BANNER")
            ApplySegmentState(dlg.BtnModeMute, mode == "BANNER_ONLY")
            ApplySegmentState(dlg.BtnModeOff, mode == "OFF")

            if mode == "SOUND_AND_BANNER" then
                dlg.ModeHint:SetText("|cff00ff00● Active:|r |cff94a3b8Plays combat sound alert and displays visual notification.|r")
            elseif mode == "BANNER_ONLY" then
                dlg.ModeHint:SetText("|cffffd100● Muted:|r |cff94a3b8Displays visual notification silently with sound muted.|r")
            else
                dlg.ModeHint:SetText("|cffff3333● Off:|r |cff94a3b8Suppresses all kill banners, sounds, and raid warnings.|r")
            end

            -- Section 2: Proximity Scope
            ApplySegmentState(dlg.BtnScopeZone, scope == "ZONE")
            ApplySegmentState(dlg.BtnScopeAll, scope == "ALL")
            ApplySegmentState(dlg.BtnScopeMine, scope == "MINE")

            if scope == "ZONE" then
                dlg.ScopeHint:SetText("|cff00e5ff● Radar:|r |cff94a3b8Alerts only when combat occurs in your current zone.|r")
            elseif scope == "ALL" then
                dlg.ScopeHint:SetText("|cffffd700● Broadcast:|r |cff94a3b8Alerts for all kills broadcasted across realm network.|r")
            else
                dlg.ScopeHint:SetText("|cff10b981● Solo:|r |cff94a3b8Only triggers when you personally kill or are killed.|r")
            end

            -- Section 3: Visual Alert Style
            ApplySegmentState(dlg.BtnStyleBoth, style == "BOTH")
            ApplySegmentState(dlg.BtnStyleRW, style == "RAID_WARNING")
            ApplySegmentState(dlg.BtnStyleBanner, style == "BANNER")

            if style == "BOTH" then
                dlg.StyleHint:SetText("|cff00e5ff● Dual Display:|r |cff94a3b8Flashes large Raid Warning text AND Tactical Kill Banner.|r")
            elseif style == "RAID_WARNING" then
                dlg.StyleHint:SetText("|cffff3333● Raid Warning:|r |cff94a3b8Flashes high-visibility cinematic text across screen center.|r")
            else
                dlg.StyleHint:SetText("|cffffd100● Tactical Banner:|r |cff94a3b8Displays compact banner with combatant class icons & GPS.|r")
            end

            -- Section 4: Screen Positioning
            local pos = s.bannerPosition or { point = "TOP", x = 0, y = -135 }
            dlg.PosCoords:SetText(string.format("|cff00e5ffCurrent Anchor:|r |cffffffff%s (X: %d, Y: %d)|r", pos.point or "TOP", pos.x or 0, pos.y or -135))

            if UI.bannerUnlocked then
                dlg.UnlockBtn.Label:SetText("|cffff3333Lock Anchor Position|r")
            else
                dlg.UnlockBtn.Label:SetText("|cffffd100Move / Unlock Alert Anchor|r")
            end
        end
        dlg.UpdateControls = UpdateControls

        -- Section 1 Event Handlers
        btnModeSound:SetScript("OnClick", function()
            local s = WoWKillboardSettings or KB.DefaultSettings
            s.alertMode = "SOUND_AND_BANNER"
            s.soundAlerts = true
            UpdateControls()
        end)
        btnModeMute:SetScript("OnClick", function()
            local s = WoWKillboardSettings or KB.DefaultSettings
            s.alertMode = "BANNER_ONLY"
            s.soundAlerts = false
            UpdateControls()
        end)
        btnModeOff:SetScript("OnClick", function()
            local s = WoWKillboardSettings or KB.DefaultSettings
            s.alertMode = "OFF"
            s.soundAlerts = false
            UpdateControls()
        end)

        -- Section 2 Event Handlers
        btnScopeZone:SetScript("OnClick", function()
            local s = WoWKillboardSettings or KB.DefaultSettings
            s.alertScope = "ZONE"
            UpdateControls()
        end)
        btnScopeAll:SetScript("OnClick", function()
            local s = WoWKillboardSettings or KB.DefaultSettings
            s.alertScope = "ALL"
            UpdateControls()
        end)
        btnScopeMine:SetScript("OnClick", function()
            local s = WoWKillboardSettings or KB.DefaultSettings
            s.alertScope = "MINE"
            UpdateControls()
        end)

        -- Section 3 Event Handlers
        btnStyleBoth:SetScript("OnClick", function()
            local s = WoWKillboardSettings or KB.DefaultSettings
            s.alertStyle = "BOTH"
            s.alertRaidWarning = true
            UpdateControls()
        end)
        btnStyleRW:SetScript("OnClick", function()
            local s = WoWKillboardSettings or KB.DefaultSettings
            s.alertStyle = "RAID_WARNING"
            s.alertRaidWarning = true
            UpdateControls()
        end)
        btnStyleBanner:SetScript("OnClick", function()
            local s = WoWKillboardSettings or KB.DefaultSettings
            s.alertStyle = "BANNER"
            s.alertRaidWarning = false
            UpdateControls()
        end)

        -- Section 4 Event Handlers
        unlockBtn:SetScript("OnClick", function()
            UI:ToggleBannerLock()
            UpdateControls()
        end)
        resetBtn:SetScript("OnClick", function()
            UI:ResetBannerPosition()
        end)

        -- Footer Event Handlers
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
    if not UI.AlertsDialog.SolidBg then
        local solid = UI.AlertsDialog:CreateTexture(nil, "BACKGROUND", nil, -8)
        solid:SetAllPoints(UI.AlertsDialog)
        UI.AlertsDialog.SolidBg = solid
    end
    if theme.id == "classic" then
        UI.AlertsDialog.SolidBg:Hide()
    else
        UI.AlertsDialog.SolidBg:Show()
        UI.AlertsDialog.SolidBg:SetColorTexture(unpack(theme.solidBg or theme.modalBg or {0.04, 0.05, 0.07, 1.0}))
    end

    UI.AlertsDialog:SetBackdrop(theme.modalBackdrop or {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    UI.AlertsDialog:SetBackdropColor(unpack(theme.modalBg or {0.035, 0.045, 0.07, 1.0}))
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


