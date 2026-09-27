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

local SafePrint = function(...)
    if KB.Utils and KB.Utils.SafePrint then
        KB.Utils.SafePrint(...)
    elseif not InCombatLockdown() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        local pieces = {}
        for i = 1, select("#", ...) do table.insert(pieces, tostring(select(i, ...))) end
        DEFAULT_CHAT_FRAME:AddMessage(table.concat(pieces, " "))
    end
end

local mainFrame = nil
local activeTab = "FEED"   -- "FEED", "LEADERBOARD", "BOUNTIES", "RALLIES", "ZONES"
local currentMode = "WORLD"  -- "WORLD", "BG", "DUEL", "ARENA"
local hlSubTab = "PLAYERS"   -- "PLAYERS" (Player Ranks), "GUILDS" (Guild Ranks)
local marksSubTab = "ACTIVE" -- "ACTIVE" (Execution List), "RECORDS" (Hall of Fame), "DEBTORS" (Wall of Shame)

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
    SafePrint(string.format("|cff00ccff[WoWKB]|r Theme switched to: |cffffd100%s|r", th.name))
end

function UI:ApplyButtonStyle(btn, theme)
    if not btn then return end
    theme = theme or UI:GetTheme()

    local nt = btn:GetNormalTexture()
    if nt then nt:SetTexture(nil) nt:Hide() end
    local pt = btn:GetPushedTexture()
    if pt then pt:SetTexture(nil) pt:Hide() end
    local ht = btn:GetHighlightTexture()
    if ht then ht:SetTexture(nil) ht:Hide() end

    if theme.btnBackdrop then
        btn:SetBackdrop(theme.btnBackdrop)
        if btn.isActive then
            btn:SetBackdropColor(unpack(theme.btnActiveBg or {0.32, 0.22, 0.10, 1.0}))
            btn:SetBackdropBorderColor(unpack(theme.btnActiveBorder or {1.0, 0.84, 0.0, 1.0}))
        else
            btn:SetBackdropColor(unpack(theme.btnBg))
            btn:SetBackdropBorderColor(unpack(theme.btnBorder))
        end
    end

    if btn.Label then
        if theme.id == "classic" then
            btn.Label:SetTextColor(1.0, 0.82, 0.0)
            btn.Label:SetShadowOffset(1, -1)
            btn.Label:SetShadowColor(0, 0, 0, 1)
        else
            btn.Label:SetTextColor(1.0, 1.0, 1.0)
            btn.Label:SetShadowOffset(1, -1)
            btn.Label:SetShadowColor(0, 0, 0, 1)
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
                UI.ContentInset.BgArt:SetTexture("Interface\\AddOns\\WoWKillboard\\Textures\\dark_war_bg.tga")
                UI.ContentInset.BgArt:SetTexCoord(0, 1, 0, 1)
                UI.ContentInset.BgArt:SetAlpha(0.40)
                if UI.ContentInset.Vignette then
                    UI.ContentInset.Vignette:SetColorTexture(0.06, 0.05, 0.04, 0.65)
                    UI.ContentInset.Vignette:SetAlpha(0.65)
                    UI.ContentInset.Vignette:Show()
                end
            else
                UI.ContentInset.BgArt:SetTexture("Interface\\AddOns\\WoWKillboard\\Textures\\dark_war_bg.tga")
                UI.ContentInset.BgArt:SetTexCoord(0, 1, 0, 1)
                UI.ContentInset.BgArt:SetAlpha(0.65)
                if UI.ContentInset.Vignette then
                    UI.ContentInset.Vignette:SetColorTexture(0.015, 0.02, 0.035, 0.40)
                    UI.ContentInset.Vignette:SetAlpha(0.40)
                    UI.ContentInset.Vignette:Show()
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
                UI.TitleText:SetPoint("TOP", UI.HeaderPlate, "TOP", 0, -10)
                UI.TitleText:SetFontObject("GameFontNormalLarge")
                UI.TitleText:SetText("|cffffd100WoW Killboard|r")
            end
            if UI.SubtitleText and UI.TitleText then
                UI.SubtitleText:ClearAllPoints()
                UI.SubtitleText:SetPoint("TOP", UI.TitleText, "BOTTOM", 0, -2)
                local sub = KB.Utils and KB.Utils.GetClientFlavorSubtitle and KB.Utils.GetClientFlavorSubtitle()
                UI.SubtitleText:SetText(sub or string.format("|cff00e5ffWoW Forever|r • |cffc7b28c%s|r • |cff888888v%s|r", (GetRealmName and GetRealmName()) or "PvP", KB.Version))
            end
        else
            UI.HeaderPlate:Hide()
            if UI.TitleText and UI.Medallion then
                UI.TitleText:ClearAllPoints()
                UI.TitleText:SetPoint("LEFT", UI.Medallion, "RIGHT", 14, 6)
                UI.TitleText:SetFontObject("GameFontNormalLarge")
                UI.TitleText:SetText(theme.titleText or "|cffffd100WoW Killboard|r")
            end
            if UI.SubtitleText and UI.TitleText then
                UI.SubtitleText:ClearAllPoints()
                UI.SubtitleText:SetPoint("TOPLEFT", UI.TitleText, "BOTTOMLEFT", 0, -3)
                local sub = KB.Utils and KB.Utils.GetClientFlavorSubtitle and KB.Utils.GetClientFlavorSubtitle()
                UI.SubtitleText:SetText(sub or string.format("|cff00e5ffWoW Forever|r • |cffc7b28c%s|r • |cff888888v%s|r", (GetRealmName and GetRealmName()) or "PvP", KB.Version))
            end
        end
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
    if UI.WebProfileButton then
        UI:ApplyButtonStyle(UI.WebProfileButton, theme)
        if theme.id == "classic" then UI.WebProfileButton:SetHeight(22) else UI.WebProfileButton:SetHeight(20) end
    end
    if UI.ExportButton then
        UI:ApplyButtonStyle(UI.ExportButton, theme)
        if theme.id == "classic" then UI.ExportButton:SetHeight(22) else UI.ExportButton:SetHeight(20) end
    end
    if UI.WireButton then
        UI:ApplyButtonStyle(UI.WireButton, theme)
        if theme.id == "classic" then UI.WireButton:SetHeight(22) else UI.WireButton:SetHeight(20) end
    end
    if UI.RegisteredButtons then
        for _, b in ipairs(UI.RegisteredButtons) do
            UI:ApplyButtonStyle(b, theme)
        end
    end
    if UI.CloseButton then
        UI.CloseButton:SetSize(22, 22)
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
        if theme.id == "classic" then
            UI.CloseButton:SetBackdropColor(0.14, 0.10, 0.07, 1.0)
            UI.CloseButton:SetBackdropBorderColor(0.60, 0.48, 0.22, 1.0)
        else
            UI.CloseButton:SetBackdropColor(0.10, 0.10, 0.12, 1.0)
            UI.CloseButton:SetBackdropBorderColor(0.0, 0.0, 0.0, 1.0)
        end
        if UI.CloseButton.Label then
            UI.CloseButton.Label:SetFontObject("GameFontHighlightSmall")
            UI.CloseButton.Label:SetText("|cffff3333X|r")
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
        if not self.isActive and t.btnHoverBg then
            self:SetBackdropColor(unpack(t.btnHoverBg))
            self:SetBackdropBorderColor(unpack(t.btnHoverBorder or {1.0, 0.85, 0.3, 1.0}))
        end
    end)
    btn:SetScript("OnLeave", function(self)
        local t = UI:GetTheme()
        if not self.isActive and t.btnBg then
            self:SetBackdropColor(unpack(t.btnBg))
            self:SetBackdropBorderColor(unpack(t.btnBorder))
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
        SetPortraitTexture(UI.Medallion.Portrait, "player")
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
        SafePrint("|cffff9900[WoWKB]|r Cannot toggle Killboard during combat.")
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

-- Pending frames to hide once combat lockdown lifts
UI.PendingHides = UI.PendingHides or {}

function UI:OnPlayerRegenDisabled()
    -- Guardrail 1: Safely hide any open interactive frames before lockdown takes hold
    if mainFrame and mainFrame:IsShown() then
        mainFrame:Hide()
    end
    if UI.AlertsDialog and UI.AlertsDialog:IsShown() then
        UI.AlertsDialog:Hide()
    end
    if UI.KOSDialog and UI.KOSDialog:IsShown() then
        UI.KOSDialog:Hide()
    end
    if UI.DeathBountyDialog and UI.DeathBountyDialog:IsShown() then
        UI.DeathBountyDialog:Hide()
    end
    if UI.BountyDialog and UI.BountyDialog:IsShown() then
        UI.BountyDialog:Hide()
    end
    if UI.WebProfileDialog and UI.WebProfileDialog:IsShown() then
        UI.WebProfileDialog:Hide()
    end
    if UI.ReinforcementDialog and UI.ReinforcementDialog:IsShown() then
        UI.ReinforcementDialog:Hide()
    end
    if UI.ExportDialog and UI.ExportDialog:IsShown() then
        UI.ExportDialog:Hide()
    end
    if UI.RallyDialog and UI.RallyDialog:IsShown() then
        UI.RallyDialog:Hide()
    end
    if UI.PrivateTooltipFrame and UI.PrivateTooltipFrame:IsShown() then
        UI.PrivateTooltipFrame:Hide()
    end
    -- Make HUD click-through during active combat so targeting is never obstructed
    if UI.RadarHUD then
        UI.RadarHUD:EnableMouse(false)
        if UI.RadarHUD.header then UI.RadarHUD.header:EnableMouse(false) end
    end
    if UI.CombatWireHUD then
        UI.CombatWireHUD:EnableMouse(false)
        if UI.CombatWireHUD.header then UI.CombatWireHUD.header:EnableMouse(false) end
    end
    if UI.KillBanner then
        UI.KillBanner:EnableMouse(false)
    end
end

function UI:OnPlayerRegenEnabled()
    -- Guardrail 1: Process deferred hides for frames whose timers expired during combat
    if UI.PendingHides and #UI.PendingHides > 0 then
        for _, f in ipairs(UI.PendingHides) do
            if f then
                if f.Hide then f:Hide() end
                if f.SetAlpha then f:SetAlpha(1.0) end
            end
        end
        UI.PendingHides = {}
    end
    -- Restore mouse interaction on HUD out of combat
    if UI.RadarHUD and not InCombatLockdown() then
        UI.RadarHUD:EnableMouse(true)
        if UI.RadarHUD.header then UI.RadarHUD.header:EnableMouse(true) end
    end
    if UI.CombatWireHUD and not InCombatLockdown() then
        UI.CombatWireHUD:EnableMouse(true)
        if UI.CombatWireHUD.header then UI.CombatWireHUD.header:EnableMouse(true) end
    end
    if UI.KillBanner and not InCombatLockdown() then
        UI.KillBanner:EnableMouse(UI.bannerUnlocked or false)
    end
    -- Flush pending combat wire entries outside combat lockdown
    if UI.PendingWireEntries and #UI.PendingWireEntries > 0 and not InCombatLockdown() then
        if not combatWireHUD then UI:InitializeCombatWire() end
        if combatWireHUD and combatWireHUD.msgFrame then
            for _, line in ipairs(UI.PendingWireEntries) do
                combatWireHUD.msgFrame:AddMessage(line)
            end
            local s = WoWKillboardSettings or KB.DefaultSettings
            if (not s or s.showCombatWire ~= false) and not combatWireHUD:IsShown() then
                combatWireHUD:Show()
            end
        end
        UI.PendingWireEntries = {}
    end
    -- Deliver pending death bounty prompt outside combat lockdown
    if UI.PendingDeathBountyKiller and not InCombatLockdown() then
        local k = UI.PendingDeathBountyKiller
        UI.PendingDeathBountyKiller = nil
        UI:ShowDeathBountyPrompt(k)
    end
end

-- Dedicated Private Tooltip (100% Taint-Free, Zero GameTooltip Touching, Anonymous Frame)
function UI:GetOrCreatePrivateTooltip()
    if UI.PrivateTooltipFrame then return UI.PrivateTooltipFrame end
    local tip = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    tip:SetSize(280, 60)
    tip:SetFrameStrata("TOOLTIP")
    tip:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    tip:SetBackdropColor(0.04, 0.05, 0.08, 0.96)
    tip:SetBackdropBorderColor(0.85, 0.65, 0.20, 0.90)
    tip:EnableMouse(false)
    tip:Hide()

    local title = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", 8, -6)
    title:SetPoint("TOPRIGHT", -8, -6)
    title:SetJustifyH("LEFT")
    tip.Title = title

    local desc = tip:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    desc:SetPoint("RIGHT", -8, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    tip.Desc = desc

    UI.PrivateTooltipFrame = tip
    return tip
end

function UI:ShowPrivateTooltip(owner, point, relPoint, x, y, titleText, descText)
    if InCombatLockdown() then return end
    local tip = UI:GetOrCreatePrivateTooltip()
    if not tip then return end
    tip:ClearAllPoints()
    tip:SetPoint(point or "BOTTOM", owner, relPoint or "TOP", x or 0, y or 4)
    tip.Title:SetText(titleText or "")
    tip.Desc:SetText(descText or "")
    local descH = tip.Desc:GetStringHeight() or 14
    tip:SetHeight(math.max(48, 22 + descH))
    tip:Show()
end

function UI:HidePrivateTooltip()
    if UI.PrivateTooltipFrame then
        UI.PrivateTooltipFrame:Hide()
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
    medallion:SetSize(46, 46)
    medallion:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14, -8)
    medallion:SetFrameLevel(mainFrame:GetFrameLevel() + 5)

    local portBg = medallion:CreateTexture(nil, "BACKGROUND")
    portBg:SetSize(40, 40)
    portBg:SetPoint("CENTER", medallion, "CENTER", 0, 0)
    portBg:SetColorTexture(0.02, 0.02, 0.03, 1.0)

    local portrait = medallion:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(40, 40)
    portrait:SetPoint("CENTER", medallion, "CENTER", 0, 0)
    if SetPortraitTexture then
        SetPortraitTexture(portrait, "player")
    end
    if not portrait:GetTexture() then
        portrait:SetTexture("Interface\\Icons\\Achievement_PVP_P_01")
    end
    portrait:SetTexCoord(0, 1, 0, 1) -- Blizzard SetPortraitTexture already handles exact headshot framing
    medallion.Portrait = portrait

    local ring = medallion:CreateTexture(nil, "OVERLAY")
    ring:SetSize(46, 46)
    ring:SetPoint("CENTER", medallion, "CENTER", 0, 0)
    ring:SetTexture("Interface\\AddOns\\WoWKillboard\\Textures\\medallion_border.tga")
    medallion.Ring = ring

    -- Circular Level Plate Backing
    local lvlFrame = CreateFrame("Frame", nil, medallion, "BackdropTemplate")
    lvlFrame:SetSize(18, 16)
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

    -- Clickable Character Medallion for Web Profile Link
    medallion:EnableMouse(true)
    medallion:SetScript("OnEnter", function(self)
        local pName = UnitName("player") or "Player"
        local knownCount = KB.UnitScanner and KB.UnitScanner.GetKnownCharactersCount and KB.UnitScanner:GetKnownCharactersCount() or 0
        local title = string.format("|cffffd100%s — Web Profile|r", pName)
        local desc = "Click to copy your character's public web profile link.\nView detailed combat dossier, kill timeline, and charts outside the game."
        if knownCount > 0 then
            desc = desc .. string.format("\n|cff94a3b8Known Realm Characters Tracked:|r |cff00e5ff%d|r", knownCount)
        end
        UI:ShowPrivateTooltip(self, "BOTTOM", "TOP", 0, 4, title, desc)
    end)
    medallion:SetScript("OnLeave", function() UI:HidePrivateTooltip() end)
    medallion:SetScript("OnMouseDown", function()
        UI:ShowCharacterWebLink(UnitName("player"))
    end)
    -- Template-Free Character Web Profile Link Button (Positioned cleanly on Left next to Medallion)
    local webBtn = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
    webBtn:SetSize(86, 20)
    webBtn:SetPoint("LEFT", medallion, "RIGHT", 10, 0)
    webBtn:EnableMouse(true)
    local webLabel = webBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    webLabel:SetPoint("CENTER", 0, 0)
    webLabel:SetText("|cff00e5ffWeb Profile|r")
    webBtn.Label = webLabel
    webBtn:SetScript("OnClick", function()
        UI:ShowCharacterWebLink(UnitName("player"))
    end)
    webBtn:SetScript("OnEnter", function(self)
        local t = UI:GetTheme()
        if t and t.btnHoverBg then
            self:SetBackdropColor(unpack(t.btnHoverBg))
            self:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
        end
        UI:ShowPrivateTooltip(self, "BOTTOM", "TOP", 0, 4, "|cff00e5ffCharacter Web Profile|r", "Click to copy your character's public web profile link.\nView detailed combat dossier, kill timeline, and charts outside the game.")
    end)
    webBtn:SetScript("OnLeave", function(self)
        local t = UI:GetTheme()
        if t and t.btnBg then
            self:SetBackdropColor(unpack(t.btnBg))
            self:SetBackdropBorderColor(unpack(t.btnBorder))
        end
        UI:HidePrivateTooltip()
    end)
    UI.WebProfileButton = webBtn

    -- Template-Free In-Game Combat Export Button
    local exportBtn = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
    exportBtn:SetSize(64, 20)
    exportBtn:SetPoint("LEFT", webBtn, "RIGHT", 6, 0)
    exportBtn:EnableMouse(true)
    local exportLabel = exportBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    exportLabel:SetPoint("CENTER", 0, 0)
    exportLabel:SetText("|cffffd100Export|r")
    exportBtn.Label = exportLabel
    exportBtn:SetScript("OnClick", function()
        UI:ShowExportDialog()
    end)
    exportBtn:SetScript("OnEnter", function(self)
        local t = UI:GetTheme()
        if t and t.btnHoverBg then
            self:SetBackdropColor(unpack(t.btnHoverBg))
            self:SetBackdropBorderColor(1.0, 0.85, 0.0, 1.0)
        end
        UI:ShowPrivateTooltip(self, "BOTTOM", "TOP", 0, 4, "|cffffd100Combat Data Export|r", "Click to open the in-game combat export window.\nCopy your combat records to paste directly into the website uploader.")
    end)
    exportBtn:SetScript("OnLeave", function(self)
        local t = UI:GetTheme()
        if t and t.btnBg then
            self:SetBackdropColor(unpack(t.btnBg))
            self:SetBackdropBorderColor(unpack(t.btnBorder))
        end
        UI:HidePrivateTooltip()
    end)
    UI.ExportButton = exportBtn

    -- Template-Free Combat Wire Pop-Out Toggle Button
    local wireBtn = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
    wireBtn:SetSize(54, 20)
    wireBtn:SetPoint("LEFT", exportBtn, "RIGHT", 6, 0)
    wireBtn:EnableMouse(true)
    local wireLabel = wireBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    wireLabel:SetPoint("CENTER", 0, 0)
    wireLabel:SetText("|cff00e5ffWire|r")
    wireBtn.Label = wireLabel
    wireBtn:SetScript("OnClick", function()
        UI:ToggleCombatWire()
    end)
    wireBtn:SetScript("OnEnter", function(self)
        local t = UI:GetTheme()
        if t and t.btnHoverBg then
            self:SetBackdropColor(unpack(t.btnHoverBg))
            self:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
        end
        UI:ShowPrivateTooltip(self, "BOTTOM", "TOP", 0, 4, "|cff00e5ffCombat Wire Pop-Out|r", "Click to toggle the floating Combat Wire pop-out window.\nLive combat notifications stream here instead of cluttering your main chat.")
    end)
    wireBtn:SetScript("OnLeave", function(self)
        local t = UI:GetTheme()
        if t and t.btnBg then
            self:SetBackdropColor(unpack(t.btnBg))
            self:SetBackdropBorderColor(unpack(t.btnBorder))
        end
        UI:HidePrivateTooltip()
    end)
    UI.WireButton = wireBtn

    -- Authentic Classic Dialog Arched Header Crest (Centered at top)
    local headerPlate = mainFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    headerPlate:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    headerPlate:SetSize(320, 56)
    headerPlate:SetPoint("TOP", mainFrame, "TOP", 0, -2)
    UI.HeaderPlate = headerPlate

    -- Window Title Header (Centered cleanly inside the Arched Header Plate)
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", headerPlate, "TOP", 0, -10)
    title:SetText("|cffffd100WoW Killboard|r")
    title:SetShadowOffset(1, -1)
    title:SetShadowColor(0, 0, 0, 1)
    UI.TitleText = title

    local subtitle = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    local realm = (GetRealmName and GetRealmName()) or "PvP"
    local sub = (KB.Utils and KB.Utils.GetClientFlavorSubtitle and KB.Utils.GetClientFlavorSubtitle())
             or string.format("|cffffd100WoW|r / |cff00e5ffForever|r / |cffc7b28c%s|r / |cff00ff88Beta|r / |cff888888v%s|r", realm, KB.Version)
    subtitle:SetText(sub)
    subtitle:SetShadowOffset(1, -1)
    subtitle:SetShadowColor(0, 0, 0, 1)
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
    themeBtn:SetSize(105, 20)
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
    alertsBtn:SetSize(76, 20)
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
        UI:ShowPrivateTooltip(self, "BOTTOM", "TOP", 0, 4, "|cffffd100Combat Alert Settings|r", "Configure Kill Banner, Sound Alerts, Raid Warnings & Position.")
    end)
    alertsBtn:SetScript("OnLeave", function(self)
        local t = UI:GetTheme()
        if t and t.btnBg then
            self:SetBackdropColor(unpack(t.btnBg))
            self:SetBackdropBorderColor(unpack(t.btnBorder))
        end
        UI:HidePrivateTooltip()
    end)
    UI.AlertsButton = alertsBtn

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
            local title, desc
            if cardId == "KD" then
                title = "|cffffd100Session Combat K/D|r"
                desc = "Personal session combat record (You) and total open-world PvP kills logged."
            elseif cardId == "DUELS" then
                title = "|cffffb82e1v1 Duels Record|r"
                desc = "Personal duel record (You) and total witnessed realm duels logged on board."
            elseif cardId == "BGS" then
                title = "|cff00e5ffBattlegrounds Record|r"
                desc = "Personal battleground record (You) and total battleground matches logged."
            end
            UI:ShowPrivateTooltip(self, "BOTTOM", "TOP", 0, 4, title, desc)
        end)
        card:SetScript("OnLeave", function(self)
            UI:HidePrivateTooltip()
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
        { id = "FEED",        text = "Intel",           w = 72 },
        { id = "LEADERBOARD", text = "Hall of Legends", w = 118 },
        { id = "BOUNTIES",    text = "Marks of Spite",  w = 114 },
        { id = "RALLIES",     text = "Rallies",         w = 80 },
        { id = "ZONES",       text = "Zone Intel",      w = 86 },
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

    -- 4-Way Mode Filter Pills (World | BGs | Duels | Arenas [Disabled / Greyed Out])
    local filterConfigs = {
        { id = "ARENA", text = "Arenas", w = 58, disabled = true, color = {0.5, 0.5, 0.5}, tooltip = "Arenas (Coming Soon - Season Telemetry Pending)" },
        { id = "DUEL",  text = "Duels",  w = 52, color = {1.0, 0.84, 0.0} },
        { id = "BG",    text = "BGs",    w = 48, color = {0.3, 0.65, 1.0} },
        { id = "WORLD", text = "World",  w = 54, color = {0.2, 0.85, 0.3} },
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
        pill.BaseColor = f.color
        if f.disabled then
            pill.isDisabled = true
            pill.tooltipText = f.tooltip
            pill:EnableMouse(true)
            pill:SetScript("OnClick", function() end)
            pill:SetScript("OnEnter", function(self)
                UI:ShowPrivateTooltip(self, "BOTTOM", "TOP", 0, 4, "|cff888888" .. f.text .. "|r", f.tooltip or "Not available in this client flavor.")
            end)
            pill:SetScript("OnLeave", function() UI:HidePrivateTooltip() end)
        else
            local modeId = f.id
            pill:SetScript("OnClick", function()
                currentMode = modeId
                UI:Refresh()
            end)
        end
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

    -- Tactical Radar HUD Frame
    UI:InitializeRadarHUD()

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
    local histKills, histDeaths = 0, 0
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
                if pName then
                    local isK = (km.killer and km.killer.name and (km.killer.name:lower() == pName:lower() or km.killer.name:lower():find(pName:lower(), 1, true) ~= nil))
                    local isV = (km.victim and km.victim.name and (km.victim.name:lower() == pName:lower() or km.victim.name:lower():find(pName:lower(), 1, true) ~= nil))
                    if isK then histKills = histKills + 1 end
                    if isV then histDeaths = histDeaths + 1 end
                end
            else
                worldKills = worldKills + 1
                if pName then
                    local isK = (km.killer and km.killer.name and (km.killer.name:lower() == pName:lower() or km.killer.name:lower():find(pName:lower(), 1, true) ~= nil))
                    local isV = (km.victim and km.victim.name and (km.victim.name:lower() == pName:lower() or km.victim.name:lower():find(pName:lower(), 1, true) ~= nil))
                    if isK then histKills = histKills + 1 end
                    if isV then histDeaths = histDeaths + 1 end
                end
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

    local myKills = math.max(s.kills or 0, histKills)
    local myDeaths = math.max(s.deaths or 0, histDeaths)

    local dW = st.duels and st.duels.wins or 0
    local dL = st.duels and st.duels.losses or 0
    local dTot = dW + dL
    local dRate = dTot > 0 and math.floor((dW / dTot) * 100) or 0

    local bgW = st.bgs and st.bgs.wins or 0
    local bgL = st.bgs and st.bgs.losses or 0
    local bgTot = bgW + bgL
    local bgRate = bgTot > 0 and math.floor((bgW / bgTot) * 100) or 0

    local kd = (myDeaths > 0) and string.format("%.2f", myKills / myDeaths) or tostring(myKills)

    if UI.StatCards then
        if UI.StatCards.KD and UI.StatCards.KD.ValueLabel then
            UI.StatCards.KD.ValueLabel:SetText(string.format(
                "|cffffffff%d|rK / |cffff4444%d|rD |cff64748b(You)|r  |cff64748b•|r  |cffffd100%d|r |cff94a3b8Logged|r",
                myKills, myDeaths, totalKillsCount
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
            if theme.btnBackdrop then btn:SetBackdrop(theme.btnBackdrop) end
            btn:SetBackdropColor(unpack(theme.btnActiveBg or {0.32, 0.22, 0.10, 1.0}))
            btn:SetBackdropBorderColor(unpack(theme.btnActiveBorder or {1.0, 0.84, 0.0, 1.0}))
            btn.Label:SetTextColor(1.0, 0.85, 0.0)
        else
            btn.isActive = false
            if theme.btnBackdrop then btn:SetBackdrop(theme.btnBackdrop) end
            btn:SetBackdropColor(unpack(theme.btnBg))
            btn:SetBackdropBorderColor(unpack(theme.btnBorder))
            if theme.id == "classic" then
                btn.Label:SetTextColor(0.85, 0.75, 0.60)
            else
                btn.Label:SetTextColor(0.65, 0.65, 0.65)
            end
        end
    end

    -- Update Filter Pill Active Glow
    for fid, pill in pairs(filterButtons) do
        local c = pill.BaseColor or {1.0, 0.82, 0.0}
        if pill.isDisabled then
            pill.isActive = false
            if theme.btnBackdrop then pill:SetBackdrop(theme.btnBackdrop) end
            pill:SetBackdropColor(0.08, 0.08, 0.08, 0.6)
            pill:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
            pill.Label:SetTextColor(0.45, 0.45, 0.45)
        elseif fid == currentMode then
            pill.isActive = true
            if theme.btnBackdrop then pill:SetBackdrop(theme.btnBackdrop) end
            if theme.id == "classic" then
                pill:SetBackdropColor(0.30, 0.22, 0.10, 1.0)
                pill:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0)
                pill.Label:SetTextColor(1.0, 0.85, 0.0)
            elseif theme.id == "elvui" then
                pill:SetBackdropColor(0.20, 0.20, 0.20, 1.0)
                pill:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                pill.Label:SetTextColor(1.0, 0.82, 0.0)
            else
                pill:SetBackdropColor(c[1] * 0.35, c[2] * 0.35, c[3] * 0.35, 1.0)
                pill:SetBackdropBorderColor(c[1], c[2], c[3], 1.0)
                pill.Label:SetTextColor(c[1], c[2], c[3])
            end
        else
            pill.isActive = false
            if theme.btnBackdrop then pill:SetBackdrop(theme.btnBackdrop) end
            pill:SetBackdropColor(unpack(theme.btnBg))
            pill:SetBackdropBorderColor(unpack(theme.btnBorder))
            if theme.id == "classic" then
                pill.Label:SetTextColor(0.80, 0.70, 0.55)
            else
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
    elseif activeTab == "RALLIES" then
        UI:RenderRallies()
    elseif activeTab == "ZONES" then
        UI:RenderZones()
    else
        activeTab = "FEED"
        UI:RenderLiveFeed()
    end
end

-- 1. Render Live Killmail Feed (Tactical Intel)
function UI:RenderLiveFeed()
    local kills = KB.Leaderboard:GetRecentKills(currentMode, 40)
    local theme = UI:GetTheme()

    -- Top Section Header
    local title = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("|cff00e5ffREALM TELEMETRY & TACTICAL INTEL|r")
    title:SetShadowOffset(1, -1)
    title:SetShadowColor(0, 0, 0, 1)

    local subtitle = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    subtitle:SetText("|cffb8a080Live battlefield killfeed, spatial GPS coordinates, and threat alerts.|r")
    subtitle:SetShadowOffset(1, -1)
    subtitle:SetShadowColor(0, 0, 0, 1)

    -- Realm Telemetry KPI Summary Bar (matching website image 3)
    local sum = KB.Leaderboard and KB.Leaderboard.GetModeSummary and KB.Leaderboard:GetModeSummary(currentMode) or { totalKills = 0, soloPct = 0, alliancePct = 50, hordePct = 50 }
    local kpiPlate = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
    kpiPlate:SetSize(820, 26)
    kpiPlate:SetPoint("TOPLEFT", 0, -46)
    kpiPlate:SetBackdrop(theme.rowBackdrop)
    kpiPlate:SetBackdropColor(0.04, 0.04, 0.05, 0.95)
    kpiPlate:SetBackdropBorderColor(0.45, 0.35, 0.18, 0.85)

    local kpiText = kpiPlate:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    kpiText:SetPoint("CENTER", 0, 0)
    kpiText:SetText(string.format(
        "REALM CARNAGE: |cffffffff%d|r   |cff64748b•|r   1V1 SOLO RATIO: |cff00e5ff%d%%|r   |cff64748b•|r   FACTION WAR: |cff3b82f6A %d%%|r / |cffef4444H %d%%|r   |cff64748b•|r   FILTER: |cffffd100[%s]|r",
        sum.totalKills, sum.soloPct, sum.alliancePct, sum.hordePct, currentMode
    ))
    kpiText:SetShadowOffset(1, -1)
    kpiText:SetShadowColor(0, 0, 0, 1)

    local yOffset = -78

    if #kills == 0 then
        if not UI.EmptyFeedText then
            UI.EmptyFeedText = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            UI.EmptyFeedText:SetPoint("TOP", UI.ContentFrame, "TOP", 0, -110)
            UI.EmptyFeedText:SetJustifyH("CENTER")
            UI.EmptyFeedText:SetSpacing(4)
        end
        local currentZone = (GetZoneText and GetZoneText() ~= "") and GetZoneText() or "Azeroth"
        UI.EmptyFeedText:SetText(string.format(
            "|cffffd100● FRONTLINE COMBAT RADAR ONLINE|r\n\n" ..
            "|cffcbd5e1Sector Surveillance:|r |cffffffff%s|r   |cff64748b•|r   |cffcbd5e1Filter Mode:|r |cffffd100[%s]|r\n" ..
            "|cffcbd5e1Combat Engine Status:|r |cff10b981ARMED & RECORDING COMBAT|r |cff94a3b8(Zero confirmed deaths in this filter)|r\n\n" ..
            "|cff94a3b8Killmails are automatically recorded upon confirming an open-world player kill,\n" ..
            "battleground victory, or sanctioned 1v1 duel.|r\n\n" ..
            "|cff00e5ffQuick Verification:|r |cffccccccType |cffffd100/wowkb testkill|r to simulate a live killmail and preview the feed.|r",
            currentZone, currentMode
        ))
        UI.EmptyFeedText:SetShadowOffset(1, -1)
        UI.EmptyFeedText:SetShadowColor(0, 0, 0, 1)
        UI.EmptyFeedText:Show()
        UI.ContentFrame:SetHeight(280)
        return
    elseif UI.EmptyFeedText then
        UI.EmptyFeedText:Hide()
    end

    for idx, km in ipairs(kills) do
        local row = CreateFrame("Button", nil, UI.ContentFrame, "BackdropTemplate")
        row:SetSize(820, 36)
        row:SetPoint("TOPLEFT", 0, yOffset)
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
        badgeText:SetShadowOffset(1, -1)
        badgeText:SetShadowColor(0, 0, 0, 1)

        -- Killer Class Icon
        local kIcon = UI:CreateClassIcon(row, km.killer.class, 22)
        kIcon:SetPoint("LEFT", 78, 0)

        -- Killer Level Pill
        local kLvl = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        kLvl:SetPoint("LEFT", kIcon, "RIGHT", 4, 0)
        local kLvlVal = km.killer.level or 0
        kLvl:SetText((kLvlVal > 0) and string.format("|cffffd100%d|r", kLvlVal) or "|cff8899aa??|r")
        kLvl:SetShadowOffset(1, -1)
        kLvl:SetShadowColor(0, 0, 0, 1)

        -- Action Verb Separator (Center)
        local actionVerb = km.isDuel and "defeated" or "destroyed"
        local sep = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        sep:SetPoint("LEFT", 305, 0)
        sep:SetText(string.format("|cffe2d4c0%s|r", actionVerb))
        sep:SetShadowOffset(1, -1)
        sep:SetShadowColor(0, 0, 0, 1)

        -- Killer Name & Guild (Bounded cleanly before separator)
        local killerStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        killerStr:SetPoint("LEFT", kLvl, "RIGHT", 5, 0)
        killerStr:SetPoint("RIGHT", sep, "LEFT", -6, 0)
        killerStr:SetJustifyH("LEFT")
        killerStr:SetWordWrap(false)
        local kGuildStr = (km.killer.guild and km.killer.guild ~= "None" and km.killer.guild ~= "") and string.format(" |cffc0a080<%s>|r", km.killer.guild) or ""
        killerStr:SetText(KB.Utils.ColorizeByClass(km.killer.name, km.killer.class) .. kGuildStr)
        killerStr:SetShadowOffset(1, -1)
        killerStr:SetShadowColor(0, 0, 0, 1)

        -- Victim Class Icon
        local vIcon = UI:CreateClassIcon(row, km.victim.class, 22)
        vIcon:SetPoint("LEFT", 365, 0)

        -- Victim Level Pill
        local vLvl = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        vLvl:SetPoint("LEFT", vIcon, "RIGHT", 4, 0)
        local vLvlVal = km.victim.level or 0
        vLvl:SetText((vLvlVal > 0) and string.format("|cffffd100%d|r", vLvlVal) or "|cff8899aa??|r")
        vLvl:SetShadowOffset(1, -1)
        vLvl:SetShadowColor(0, 0, 0, 1)

        -- Location & Timestamp (Right-Aligned)
        local infoStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        infoStr:SetPoint("RIGHT", -12, 0)
        local locName = km.isBattleground and (km.battlegroundName or "Battleground") or km.location.zone
        infoStr:SetText(string.format("|cffcbd5e1%s|r  |cff64748b•|r  |cffa0aab8%s|r", locName, KB.Utils.FormatTimeAgo(km.timestamp)))
        infoStr:SetShadowOffset(1, -1)
        infoStr:SetShadowColor(0, 0, 0, 1)

        -- Victim Name & Guild (Bounded cleanly before location info)
        local victimStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        victimStr:SetPoint("LEFT", vLvl, "RIGHT", 5, 0)
        victimStr:SetPoint("RIGHT", infoStr, "LEFT", -10, 0)
        victimStr:SetJustifyH("LEFT")
        victimStr:SetWordWrap(false)
        local vGuildStr = (km.victim.guild and km.victim.guild ~= "None" and km.victim.guild ~= "") and string.format(" |cffc0a080<%s>|r", km.victim.guild) or ""
        victimStr:SetText(KB.Utils.ColorizeByClass(km.victim.name, km.victim.class) .. vGuildStr)
        victimStr:SetShadowOffset(1, -1)
        victimStr:SetShadowColor(0, 0, 0, 1)

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

-- 2. Render Leaderboard Tab (Hall of Legends)
function UI:RenderLeaderboard()
    local theme = UI:GetTheme()

    -- Top Section Header (Website style)
    local title = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("|cffffd100HALL OF LEGENDS|r")
    title:SetShadowOffset(1, -1)
    title:SetShadowColor(0, 0, 0, 1)

    local subtitle = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    subtitle:SetText("|cffb8a080Most lethal combatants, rank efficiency, and certified executions across Azeroth.|r")
    subtitle:SetShadowOffset(1, -1)
    subtitle:SetShadowColor(0, 0, 0, 1)

    -- Sub-navigation Toggle Bar: [Player Ranks] | [Guild Ranks] (matching website image 2)
    local btnPlayers = UI:CreateButton(UI.ContentFrame, 114, 22, "Player Ranks")
    btnPlayers:SetPoint("TOPLEFT", 10, -46)
    btnPlayers.isActive = (hlSubTab == "PLAYERS")
    UI:ApplyButtonStyle(btnPlayers, theme)
    if btnPlayers.Label then
        btnPlayers.Label:SetTextColor(btnPlayers.isActive and 1.0 or 0.80, btnPlayers.isActive and 0.84 or 0.70, btnPlayers.isActive and 0.0 or 0.55)
    end
    btnPlayers:SetScript("OnClick", function()
        hlSubTab = "PLAYERS"
        UI:Refresh()
    end)

    local btnGuilds = UI:CreateButton(UI.ContentFrame, 104, 22, "Guild Ranks")
    btnGuilds:SetPoint("LEFT", btnPlayers, "RIGHT", 6, 0)
    btnGuilds.isActive = (hlSubTab == "GUILDS")
    UI:ApplyButtonStyle(btnGuilds, theme)
    if btnGuilds.Label then
        btnGuilds.Label:SetTextColor(btnGuilds.isActive and 1.0 or 0.80, btnGuilds.isActive and 0.84 or 0.70, btnGuilds.isActive and 0.0 or 0.55)
    end
    btnGuilds:SetScript("OnClick", function()
        hlSubTab = "GUILDS"
        UI:Refresh()
    end)

    local yOffset = -76

    if hlSubTab == "PLAYERS" then
        local topKillers = KB.Leaderboard:GetTopKillers(currentMode, 10)
        local pName = UnitName("player")
        local pRank, pStats, totalPlayers = KB.Leaderboard:GetPlayerRankAndStats(pName, currentMode)
        local playerInTop10 = (pRank and pRank <= 10)

        if #topKillers == 0 then
            local empty = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            empty:SetPoint("TOPLEFT", 14, yOffset)
            empty:SetText("No player combat telemetry recorded for this filter mode yet.")
            empty:SetShadowOffset(1, -1)
            empty:SetShadowColor(0, 0, 0, 1)
            yOffset = yOffset - 30
        else
            for rank, p in ipairs(topKillers) do
                local row = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
                row:SetSize(820, 32)
                row:SetPoint("TOPLEFT", 0, yOffset)
                local isEven = (rank % 2 == 0)
                local isPlayer = (pName and p.name == pName)

                row:SetBackdrop(theme.rowBackdrop)
                if isPlayer then
                    row:SetBackdropColor(0.24, 0.17, 0.06, 0.95)
                    row:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0)
                else
                    row:SetBackdropColor(unpack(isEven and theme.rowBgAlt or theme.rowBg))
                    row:SetBackdropBorderColor(unpack(theme.rowBorder))
                end

                -- Rank Medal / Badge
                local rankColor = (rank == 1 and "ffd700") or (rank == 2 and "c0c0c0") or (rank == 3 and "cd7f32") or "94a3b8"
                local rankText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                rankText:SetPoint("LEFT", 12, 0)
                rankText:SetText(string.format("|cff%s#%d|r", rankColor, rank))
                rankText:SetShadowOffset(1, -1)
                rankText:SetShadowColor(0, 0, 0, 1)

                local pIcon = UI:CreateClassIcon(row, p.class, 22)
                pIcon:SetPoint("LEFT", rankText, "RIGHT", 10, 0)

                local statsText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                statsText:SetPoint("RIGHT", -15, 0)
                local kd = (p.deaths and p.deaths > 0) and string.format("%.2f", p.kills / p.deaths) or tostring(p.kills or 0)
                statsText:SetText(string.format(
                    "|cff10b981%d Kills|r   |cff64748b•|r   |cff00e5ff%d Solo|r   |cff64748b•|r   |cffef4444%d Deaths|r   |cff64748b•|r   K/D: |cffffd100%s|r",
                    p.kills or 0, p.soloKills or 0, p.deaths or 0, kd
                ))
                statsText:SetShadowOffset(1, -1)
                statsText:SetShadowColor(0, 0, 0, 1)

                local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                nameText:SetPoint("LEFT", pIcon, "RIGHT", 8, 0)
                nameText:SetPoint("RIGHT", statsText, "LEFT", -10, 0)
                nameText:SetJustifyH("LEFT")
                nameText:SetWordWrap(false)
                local guildStr = (p.guild and p.guild ~= "None" and p.guild ~= "") and string.format("  |cff8899aa<%s>|r", p.guild) or ""
                local youBadge = isPlayer and " |cffffd100[YOU]|r" or ""
                nameText:SetText(KB.Utils.ColorizeByClass(p.name, p.class) .. youBadge .. guildStr)
                nameText:SetShadowOffset(1, -1)
                nameText:SetShadowColor(0, 0, 0, 1)

                yOffset = yOffset - 36
            end
        end

        -- Bottom Pinned Player Row (Always show your position)
        if not playerInTop10 then
            yOffset = yOffset - 10

            -- Elegant Divider
            local div = UI.ContentFrame:CreateTexture(nil, "ARTWORK")
            div:SetPoint("TOPLEFT", 14, yOffset)
            div:SetPoint("TOPRIGHT", -14, yOffset)
            div:SetHeight(1)
            div:SetColorTexture(0.55, 0.42, 0.18, 0.8)

            local divLabel = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            divLabel:SetPoint("CENTER", div, "CENTER", 0, 0)
            divLabel:SetText("|cffffd100— YOUR STANDING —|r")
            divLabel:SetShadowOffset(1, -1)
            divLabel:SetShadowColor(0, 0, 0, 1)

            yOffset = yOffset - 22

            local pRow = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
            pRow:SetSize(820, 34)
            pRow:SetPoint("TOPLEFT", 0, yOffset)
            pRow:SetBackdrop(theme.rowBackdrop)
            pRow:SetBackdropColor(0.20, 0.15, 0.05, 0.95)
            pRow:SetBackdropBorderColor(1.0, 0.84, 0.0, 0.95)

            local rankStr = (pRank and pRank > 0) and string.format("|cffffd100#%d|r", pRank) or "|cff888888#--|r"
            local pRankText = pRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            pRankText:SetPoint("LEFT", 12, 0)
            pRankText:SetText(rankStr)
            pRankText:SetShadowOffset(1, -1)
            pRankText:SetShadowColor(0, 0, 0, 1)

            local myClass = select(2, UnitClass("player")) or "WARRIOR"
            local pIcon = UI:CreateClassIcon(pRow, myClass, 22)
            pIcon:SetPoint("LEFT", pRankText, "RIGHT", 10, 0)

            local pStatsText = pRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            pStatsText:SetPoint("RIGHT", -15, 0)
            if pStats then
                local kd = (pStats.deaths and pStats.deaths > 0) and string.format("%.2f", pStats.kills / pStats.deaths) or tostring(pStats.kills or 0)
                pStatsText:SetText(string.format(
                    "|cff10b981%d Kills|r   |cff64748b•|r   |cff00e5ff%d Solo|r   |cff64748b•|r   |cffef4444%d Deaths|r   |cff64748b•|r   K/D: |cffffd100%s|r",
                    pStats.kills or 0, pStats.soloKills or 0, pStats.deaths or 0, kd
                ))
            else
                pStatsText:SetText("|cff94a3b80 Kills  •  0 Solo  •  0 Deaths  •  Unranked in this filter mode|r")
            end
            pStatsText:SetShadowOffset(1, -1)
            pStatsText:SetShadowColor(0, 0, 0, 1)

            local myGuild = GetGuildInfo("player")
            local myGuildStr = (myGuild and myGuild ~= "") and string.format("  |cff8899aa<%s>|r", myGuild) or ""
            local pNameText = pRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            pNameText:SetPoint("LEFT", pIcon, "RIGHT", 8, 0)
            pNameText:SetPoint("RIGHT", pStatsText, "LEFT", -10, 0)
            pNameText:SetJustifyH("LEFT")
            pNameText:SetWordWrap(false)
            pNameText:SetText(KB.Utils.ColorizeByClass(pName or "Player", myClass) .. " |cffffd100[YOU]|r" .. myGuildStr)
            pNameText:SetShadowOffset(1, -1)
            pNameText:SetShadowColor(0, 0, 0, 1)

            yOffset = yOffset - 38
        end

    elseif hlSubTab == "GUILDS" then
        local topGuilds = KB.Leaderboard:GetTopGuilds(currentMode, 10)
        local myGuild = GetGuildInfo("player")
        local gRank, gStats, totalGuilds = KB.Leaderboard:GetGuildRankAndStats(myGuild, currentMode)
        local guildInTop10 = (gRank and gRank <= 10)

        if #topGuilds == 0 then
            local empty = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            empty:SetPoint("TOPLEFT", 14, yOffset)
            empty:SetText("No guild PvP telemetry recorded for this filter mode yet.")
            empty:SetShadowOffset(1, -1)
            empty:SetShadowColor(0, 0, 0, 1)
            yOffset = yOffset - 30
        else
            for gIdx, g in ipairs(topGuilds) do
                local row = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
                row:SetSize(820, 32)
                row:SetPoint("TOPLEFT", 0, yOffset)
                local isEven = (gIdx % 2 == 0)
                local isMyGuild = (myGuild and myGuild ~= "" and g.guild == myGuild)

                row:SetBackdrop(theme.rowBackdrop)
                if isMyGuild then
                    row:SetBackdropColor(0.24, 0.17, 0.06, 0.95)
                    row:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0)
                else
                    row:SetBackdropColor(unpack(isEven and theme.rowBgAlt or theme.rowBg))
                    row:SetBackdropBorderColor(unpack(theme.rowBorder))
                end

                local rankColor = (gIdx == 1 and "ffd700") or (gIdx == 2 and "c0c0c0") or (gIdx == 3 and "cd7f32") or "94a3b8"
                local gRankText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                gRankText:SetPoint("LEFT", 12, 0)
                gRankText:SetText(string.format("|cff%s#%d|r", rankColor, gIdx))
                gRankText:SetShadowOffset(1, -1)
                gRankText:SetShadowColor(0, 0, 0, 1)

                local gKills = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                gKills:SetPoint("RIGHT", -15, 0)
                gKills:SetText(string.format("|cff10b981%d Kills Logged|r", g.kills or 0))
                gKills:SetShadowOffset(1, -1)
                gKills:SetShadowColor(0, 0, 0, 1)

                local gNameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                gNameText:SetPoint("LEFT", 50, 0)
                gNameText:SetPoint("RIGHT", gKills, "LEFT", -10, 0)
                gNameText:SetJustifyH("LEFT")
                gNameText:SetWordWrap(false)
                local guildBadge = isMyGuild and " |cffffd100[YOUR GUILD]|r" or ""
                gNameText:SetText(string.format("|cffffd700<%s>|r%s", g.guild, guildBadge))
                gNameText:SetShadowOffset(1, -1)
                gNameText:SetShadowColor(0, 0, 0, 1)

                yOffset = yOffset - 36
            end
        end

        -- Bottom Pinned Guild Standing
        if not guildInTop10 then
            yOffset = yOffset - 10

            local div = UI.ContentFrame:CreateTexture(nil, "ARTWORK")
            div:SetPoint("TOPLEFT", 14, yOffset)
            div:SetPoint("TOPRIGHT", -14, yOffset)
            div:SetHeight(1)
            div:SetColorTexture(0.55, 0.42, 0.18, 0.8)

            local divLabel = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            divLabel:SetPoint("CENTER", div, "CENTER", 0, 0)
            divLabel:SetText("|cffffd100— YOUR GUILD STANDING —|r")
            divLabel:SetShadowOffset(1, -1)
            divLabel:SetShadowColor(0, 0, 0, 1)

            yOffset = yOffset - 22

            local gRow = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
            gRow:SetSize(820, 34)
            gRow:SetPoint("TOPLEFT", 0, yOffset)
            gRow:SetBackdrop(theme.rowBackdrop)
            gRow:SetBackdropColor(0.20, 0.15, 0.05, 0.95)
            gRow:SetBackdropBorderColor(1.0, 0.84, 0.0, 0.95)

            if myGuild and myGuild ~= "" and myGuild ~= "None" then
                local rankStr = (gRank and gRank > 0) and string.format("|cffffd100#%d|r", gRank) or "|cff888888#--|r"
                local gRankText = gRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                gRankText:SetPoint("LEFT", 12, 0)
                gRankText:SetText(rankStr)
                gRankText:SetShadowOffset(1, -1)
                gRankText:SetShadowColor(0, 0, 0, 1)

                local gKillsText = gRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                gKillsText:SetPoint("RIGHT", -15, 0)
                gKillsText:SetText(gStats and string.format("|cff10b981%d Kills Logged|r", gStats.kills) or "|cff8888880 Kills Logged (Unranked)|r")
                gKillsText:SetShadowOffset(1, -1)
                gKillsText:SetShadowColor(0, 0, 0, 1)

                local gNameText = gRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                gNameText:SetPoint("LEFT", 50, 0)
                gNameText:SetPoint("RIGHT", gKillsText, "LEFT", -10, 0)
                gNameText:SetJustifyH("LEFT")
                gNameText:SetWordWrap(false)
                gNameText:SetText(string.format("|cffffd700<%s>|r |cffffd100[YOUR GUILD]|r", myGuild))
                gNameText:SetShadowOffset(1, -1)
                gNameText:SetShadowColor(0, 0, 0, 1)
            else
                local unguilded = gRow:CreateFontString(nil, "OVERLAY", "GameFontDisable")
                unguilded:SetPoint("CENTER", 0, 0)
                unguilded:SetText("|cff94a3b8<Guildless Operative> — Join a guild to compete on the War Guild Leaderboard|r")
                unguilded:SetShadowOffset(1, -1)
                unguilded:SetShadowColor(0, 0, 0, 1)
            end

            yOffset = yOffset - 38
        end
    end

    UI.ContentFrame:SetHeight(math.abs(yOffset) + 40)
end

-- 3. Render Bounties & Debt Ledger (Wall of Shame)
function UI:RenderBounties()
    local theme = UI:GetTheme()
    local yOffset = -8

    -- Header Title
    local bntTitle = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    bntTitle:SetPoint("TOPLEFT", 10, yOffset)
    bntTitle:SetText("⚔️ |cffffd100MARKS OF SPITE & EXECUTION CONTRACTS|r")
    bntTitle:SetShadowOffset(1, -1)
    bntTitle:SetShadowColor(0, 0, 0, 1)

    -- Place Bounty Button
    local placeBtn = UI:CreateButton(UI.ContentFrame, 158, 22, "+ Issue Mark of Spite")
    placeBtn:SetPoint("TOPRIGHT", -14, yOffset)
    placeBtn:SetScript("OnClick", function()
        UI:ShowBountyPrompt()
    end)

    -- Subtitle
    local subtitle = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", bntTitle, "BOTTOMLEFT", 0, -2)
    subtitle:SetText("|cffb8a080Sanctioned execution contracts, outlaw manhunts, and debt ledgers across Azeroth.|r")
    subtitle:SetShadowOffset(1, -1)
    subtitle:SetShadowColor(0, 0, 0, 1)

    -- Sub-navigation Toggle Bar: [Active Marks] | [Hall of Fame] | [Wall of Shame]
    local btnActive = UI:CreateButton(UI.ContentFrame, 106, 22, "Active Marks")
    btnActive:SetPoint("TOPLEFT", 10, -46)
    btnActive.isActive = (marksSubTab == "ACTIVE")
    UI:ApplyButtonStyle(btnActive, theme)
    if btnActive.Label then
        btnActive.Label:SetTextColor(btnActive.isActive and 1.0 or 0.80, btnActive.isActive and 0.84 or 0.70, btnActive.isActive and 0.0 or 0.55)
    end
    btnActive:SetScript("OnClick", function()
        marksSubTab = "ACTIVE"
        UI:Refresh()
    end)

    local btnRecords = UI:CreateButton(UI.ContentFrame, 106, 22, "Hall of Fame")
    btnRecords:SetPoint("LEFT", btnActive, "RIGHT", 6, 0)
    btnRecords.isActive = (marksSubTab == "RECORDS")
    UI:ApplyButtonStyle(btnRecords, theme)
    if btnRecords.Label then
        btnRecords.Label:SetTextColor(btnRecords.isActive and 1.0 or 0.80, btnRecords.isActive and 0.84 or 0.70, btnRecords.isActive and 0.0 or 0.55)
    end
    btnRecords:SetScript("OnClick", function()
        marksSubTab = "RECORDS"
        UI:Refresh()
    end)

    local btnDebtors = UI:CreateButton(UI.ContentFrame, 114, 22, "Wall of Shame")
    btnDebtors:SetPoint("LEFT", btnRecords, "RIGHT", 6, 0)
    btnDebtors.isActive = (marksSubTab == "DEBTORS")
    UI:ApplyButtonStyle(btnDebtors, theme)
    if btnDebtors.Label then
        btnDebtors.Label:SetTextColor(btnDebtors.isActive and 1.0 or 0.80, btnDebtors.isActive and 0.84 or 0.70, btnDebtors.isActive and 0.0 or 0.55)
    end
    btnDebtors:SetScript("OnClick", function()
        marksSubTab = "DEBTORS"
        UI:Refresh()
    end)

    -- Personal Marks Dossier Banner Card (mimicking website layout)
    local pCard = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
    pCard:SetSize(820, 26)
    pCard:SetPoint("TOPLEFT", 0, -74)
    pCard:SetBackdrop(theme.rowBackdrop)
    pCard:SetBackdropColor(0.12, 0.09, 0.06, 0.95)
    pCard:SetBackdropBorderColor(0.55, 0.42, 0.18, 0.9)

    local pMarks = (KB.BountyEngine and KB.BountyEngine.GetPersonalMarks) and KB.BountyEngine:GetPersonalMarks() or { issued = 0, onHead = 0 }
    local pMarksTxt = pCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pMarksTxt:SetPoint("LEFT", 12, 0)
    pMarksTxt:SetText(string.format(
        "|cffffd100YOUR MARK DOSSIER:|r   |cff38bdf8%d Contracts Issued by You|r   |cff64748b•|r   |cff%s%d Active Marks Placed on Your Head|r",
        pMarks.issued or 0,
        (pMarks.onHead and pMarks.onHead > 0) and "ef4444" or "10b981",
        pMarks.onHead or 0
    ))
    pMarksTxt:SetShadowOffset(1, -1)
    pMarksTxt:SetShadowColor(0, 0, 0, 1)

    local yOffset = -108

    if marksSubTab == "ACTIVE" then
        -- 1. Active Marks List
        local activeHeader = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        activeHeader:SetPoint("TOPLEFT", 10, yOffset)
        activeHeader:SetText("|cffffd100ACTIVE HUNT CONTRACTS|r — High Command Marked Targets")
        activeHeader:SetShadowOffset(1, -1)
        activeHeader:SetShadowColor(0, 0, 0, 1)
        yOffset = yOffset - 24

        WoWKillboardBounties = WoWKillboardBounties or {}
        local hasBounties = false
        for _, b in pairs(WoWKillboardBounties) do
            if b.status == KB.STATUS.ACTIVE then
                hasBounties = true
                local row = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
                row:SetSize(820, 32)
                row:SetPoint("TOPLEFT", 0, yOffset)
                row:SetBackdrop(theme.rowBackdrop)
                row:SetBackdropColor(0.14, 0.08, 0.07, 0.92)
                row:SetBackdropBorderColor(0.65, 0.28, 0.20, 0.85)

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

                local targetColored = KB.Utils and KB.Utils.ColorizeByClass and KB.Utils.ColorizeByClass(b.targetName, b.targetClass) or ("|cffff3333" .. (b.targetName or "Target") .. "|r")
                local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                txt:SetPoint("LEFT", icon, "RIGHT", 8, 0)
                txt:SetText(string.format("MARK: %s  |  Reward: |cffffd700%s|r  |  Issued by: |cffcbd5e1%s|r%s",
                    targetColored, KB.Utils.FormatMoney(b.amountCopper), b.placerName or "Unknown", lastSeenStr))
                txt:SetShadowOffset(1, -1)
                txt:SetShadowColor(0, 0, 0, 1)

                local bId = b.id
                local isAccepted = KB.BountyEngine and KB.BountyEngine.IsBountyAccepted and KB.BountyEngine:IsBountyAccepted(bId)
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
            emptyB:SetPoint("TOPLEFT", 14, yOffset)
            emptyB:SetText("No active blood bounties. Declare one upon an enemy to ignite the manhunt!")
            emptyB:SetShadowOffset(1, -1)
            emptyB:SetShadowColor(0, 0, 0, 1)
            yOffset = yOffset - 25
        end

        -- Archived Cold Cases Section (>30 Days Uncollected)
        yOffset = yOffset - 16
        local coldTitle = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        coldTitle:SetPoint("TOPLEFT", 10, yOffset)
        coldTitle:SetText("📜 |cff94a3b8ARCHIVED COLD CASES|r — Escaped Targets (>30 Days Unclaimed)")
        coldTitle:SetShadowOffset(1, -1)
        coldTitle:SetShadowColor(0, 0, 0, 1)
        yOffset = yOffset - 24

        local hasCold = false
        for _, b in pairs(WoWKillboardBounties) do
            if b.status == "COLD_CASE" then
                hasCold = true
                local row = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
                row:SetSize(820, 30)
                row:SetPoint("TOPLEFT", 0, yOffset)
                row:SetBackdrop(theme.rowBackdrop)
                row:SetBackdropColor(0.09, 0.08, 0.07, 0.90)
                row:SetBackdropBorderColor(0.40, 0.35, 0.22, 0.70)

                local icon = UI:CreateClassIcon(row, b.targetClass, 20)
                icon:SetPoint("LEFT", 12, 0)

                local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                txt:SetPoint("LEFT", icon, "RIGHT", 8, 0)
                txt:SetText(string.format("|cff888888[ESCAPED]|r |cffffffff%s|r (%s)  |  Unclaimed Reward: |cffffd700%s|r  |  Contractor: %s",
                    b.targetName or "Target", b.targetClass or "Unknown", KB.Utils.FormatMoney(b.amountCopper), b.placerName or "Unknown"))
                txt:SetShadowOffset(1, -1)
                txt:SetShadowColor(0, 0, 0, 1)

                yOffset = yOffset - 34
            end
        end

        if not hasCold then
            local emptyC = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            emptyC:SetPoint("TOPLEFT", 14, yOffset)
            emptyC:SetText("No archived bounties. All execution contracts remain actively pursued.")
            emptyC:SetShadowOffset(1, -1)
            emptyC:SetShadowColor(0, 0, 0, 1)
            yOffset = yOffset - 25
        end

    elseif marksSubTab == "RECORDS" then
        local records = (KB.BountyEngine and KB.BountyEngine.GetBountyRecords) and KB.BountyEngine:GetBountyRecords() or { topHunters = {}, highestRewards = {}, longestSurviving = {} }

        -- Section A: Top Mark Hunters
        local hTitle = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hTitle:SetPoint("TOPLEFT", 10, yOffset)
        hTitle:SetText("🏆 |cffffd100TOP MARK HUNTERS|r — Sanctioned Contract Executions")
        hTitle:SetShadowOffset(1, -1)
        hTitle:SetShadowColor(0, 0, 0, 1)
        yOffset = yOffset - 24

        if not records.topHunters or #records.topHunters == 0 then
            local emptyH = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            emptyH:SetPoint("TOPLEFT", 14, yOffset)
            emptyH:SetText("No mark executions claimed yet in realm history.")
            emptyH:SetShadowOffset(1, -1)
            emptyH:SetShadowColor(0, 0, 0, 1)
            yOffset = yOffset - 25
        else
            for hIdx = 1, math.min(#records.topHunters, 5) do
                local h = records.topHunters[hIdx]
                local row = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
                row:SetSize(820, 28)
                row:SetPoint("TOPLEFT", 0, yOffset)
                row:SetBackdrop(theme.rowBackdrop)
                row:SetBackdropColor(unpack(hIdx % 2 == 0 and theme.rowBgAlt or theme.rowBg))
                row:SetBackdropBorderColor(unpack(theme.rowBorder))

                local rankColor = (hIdx == 1 and "ffd700") or (hIdx == 2 and "c0c0c0") or (hIdx == 3 and "cd7f32") or "94a3b8"
                local rankText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                rankText:SetPoint("LEFT", 12, 0)
                rankText:SetText(string.format("|cff%s#%d|r", rankColor, hIdx))
                rankText:SetShadowOffset(1, -1)
                rankText:SetShadowColor(0, 0, 0, 1)

                local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                nameText:SetPoint("LEFT", rankText, "RIGHT", 14, 0)
                nameText:SetText(string.format("|cffffffff%s|r", h.name or "Hunter"))
                nameText:SetShadowOffset(1, -1)
                nameText:SetShadowColor(0, 0, 0, 1)

                local countText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                countText:SetPoint("RIGHT", -14, 0)
                countText:SetText(string.format("|cff10b981%d Sanctioned Executions Claimed|r", h.count or 0))
                countText:SetShadowOffset(1, -1)
                countText:SetShadowColor(0, 0, 0, 1)

                yOffset = yOffset - 32
            end
        end

        -- Section B: Highest Mark Rewards
        yOffset = yOffset - 12
        local rTitle = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rTitle:SetPoint("TOPLEFT", 10, yOffset)
        rTitle:SetText("💰 |cffffd100RICHEST BOUNTY PURSUITS|r — Highest Placed Stakes")
        rTitle:SetShadowOffset(1, -1)
        rTitle:SetShadowColor(0, 0, 0, 1)
        yOffset = yOffset - 24

        if not records.highestRewards or #records.highestRewards == 0 then
            local emptyR = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            emptyR:SetPoint("TOPLEFT", 14, yOffset)
            emptyR:SetText("No bounties recorded in realm history.")
            emptyR:SetShadowOffset(1, -1)
            emptyR:SetShadowColor(0, 0, 0, 1)
            yOffset = yOffset - 25
        else
            for rIdx = 1, math.min(#records.highestRewards, 5) do
                local r = records.highestRewards[rIdx]
                local row = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
                row:SetSize(820, 28)
                row:SetPoint("TOPLEFT", 0, yOffset)
                row:SetBackdrop(theme.rowBackdrop)
                row:SetBackdropColor(unpack(rIdx % 2 == 0 and theme.rowBgAlt or theme.rowBg))
                row:SetBackdropBorderColor(unpack(theme.rowBorder))

                local icon = UI:CreateClassIcon(row, r.targetClass, 20)
                icon:SetPoint("LEFT", 12, 0)

                local targetText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                targetText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
                targetText:SetText(string.format("TARGET: %s  |  Contractor: |cffcbd5e1%s|r",
                    KB.Utils and KB.Utils.ColorizeByClass and KB.Utils.ColorizeByClass(r.targetName, r.targetClass) or (r.targetName or "Target"),
                    r.placerName or "Unknown"
                ))
                targetText:SetShadowOffset(1, -1)
                targetText:SetShadowColor(0, 0, 0, 1)

                local statusColor = (r.status == KB.STATUS.ACTIVE and "38bdf8") or (r.status == KB.STATUS.CLAIMED and "10b981") or (r.status == KB.STATUS.OATHBREAKER and "ef4444") or "94a3b8"
                local rewardText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                rewardText:SetPoint("RIGHT", -14, 0)
                rewardText:SetText(string.format("Reward: |cffffd700%s|r  |  |cff%s[%s]|r", KB.Utils.FormatMoney(r.amountCopper), statusColor, r.status or "UNKNOWN"))
                rewardText:SetShadowOffset(1, -1)
                rewardText:SetShadowColor(0, 0, 0, 1)

                yOffset = yOffset - 32
            end
        end

        -- Section C: Most Elusive Outlaws
        yOffset = yOffset - 12
        local eTitle = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        eTitle:SetPoint("TOPLEFT", 10, yOffset)
        eTitle:SetText("⏳ |cffffd100MOST ELUSIVE OUTLAWS|r — Evading Active Pursuit")
        eTitle:SetShadowOffset(1, -1)
        eTitle:SetShadowColor(0, 0, 0, 1)
        yOffset = yOffset - 24

        if not records.longestSurviving or #records.longestSurviving == 0 then
            local emptyE = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            emptyE:SetPoint("TOPLEFT", 14, yOffset)
            emptyE:SetText("No active outlaws evading capture.")
            emptyE:SetShadowOffset(1, -1)
            emptyE:SetShadowColor(0, 0, 0, 1)
            yOffset = yOffset - 25
        else
            for eIdx = 1, math.min(#records.longestSurviving, 5) do
                local e = records.longestSurviving[eIdx]
                local row = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
                row:SetSize(820, 28)
                row:SetPoint("TOPLEFT", 0, yOffset)
                row:SetBackdrop(theme.rowBackdrop)
                row:SetBackdropColor(unpack(eIdx % 2 == 0 and theme.rowBgAlt or theme.rowBg))
                row:SetBackdropBorderColor(unpack(theme.rowBorder))

                local icon = UI:CreateClassIcon(row, e.class, 20)
                icon:SetPoint("LEFT", 12, 0)

                local targetText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                targetText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
                targetText:SetText(string.format("OUTLAW: %s",
                    KB.Utils and KB.Utils.ColorizeByClass and KB.Utils.ColorizeByClass(e.target, e.class) or (e.target or "Target")
                ))
                targetText:SetShadowOffset(1, -1)
                targetText:SetShadowColor(0, 0, 0, 1)

                local timeText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                timeText:SetPoint("RIGHT", -14, 0)
                timeText:SetText(string.format("|cffef4444%d Days on the Run|r  |  Bounty: |cffffd700%s|r", e.days or 1, KB.Utils.FormatMoney(e.copper)))
                timeText:SetShadowOffset(1, -1)
                timeText:SetShadowColor(0, 0, 0, 1)

                yOffset = yOffset - 32
            end
        end

    elseif marksSubTab == "DEBTORS" then
        local debtTitle = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        debtTitle:SetPoint("TOPLEFT", 10, yOffset)
        debtTitle:SetText("⛓️ |cffff2222THE TRAITOR'S GIBBET|r — Oathbreakers & Defaulted Debts")
        debtTitle:SetShadowOffset(1, -1)
        debtTitle:SetShadowColor(0, 0, 0, 1)

        local debtSub = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        debtSub:SetPoint("TOPLEFT", debtTitle, "BOTTOMLEFT", 0, -2)
        debtSub:SetText("|cffb8a080Combatants who defaulted on sanctioned gold stakes or dishonored wagers.|r")
        debtSub:SetShadowOffset(1, -1)
        debtSub:SetShadowColor(0, 0, 0, 1)
        yOffset = yOffset - 36

        WoWKillboardDebtLedger = WoWKillboardDebtLedger or {}
        local hasDebts = false

        for playerName, debt in pairs(WoWKillboardDebtLedger) do
            if debt.status == KB.STATUS.OATHBREAKER then
                hasDebts = true
                local row = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
                row:SetSize(820, 36)
                row:SetPoint("TOPLEFT", 0, yOffset)
                row:SetBackdrop(theme.rowBackdrop)
                row:SetBackdropColor(0.20, 0.05, 0.05, 0.94)
                row:SetBackdropBorderColor(0.75, 0.25, 0.25, 0.85)

                local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                txt:SetPoint("LEFT", 14, 0)
                txt:SetText(string.format("|cffff2222[TRAITOR]|r |cffffffff%s|r defaulted on |cffffd700%s|r owed to %s (%d days in default)",
                    playerName, KB.Utils.FormatMoney(debt.amountOwedCopper), debt.creditor or "Creditor", debt.daysInDefault or 1))
                txt:SetShadowOffset(1, -1)
                txt:SetShadowColor(0, 0, 0, 1)

                -- If player is the debtor, show redemption button
                if playerName == UnitName("player") then
                    local payBtn = UI:CreateButton(row, 130, 24, "⚔️ Settle Debt")
                    payBtn:SetPoint("RIGHT", -10, 0)
                    local pName = playerName
                    payBtn:SetScript("OnClick", function()
                        if KB.BountyEngine and KB.BountyEngine.PayOffDebt then
                            KB.BountyEngine:PayOffDebt(pName)
                        end
                    end)
                end

                yOffset = yOffset - 40
            end
        end

        if not hasDebts then
            local emptyD = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            emptyD:SetPoint("TOPLEFT", 14, yOffset)
            emptyD:SetText("No players currently in default. The realm's honor is intact.")
            emptyD:SetShadowOffset(1, -1)
            emptyD:SetShadowColor(0, 0, 0, 1)
            yOffset = yOffset - 25
        end
    end

    UI.ContentFrame:SetHeight(math.abs(yOffset) + 40)
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
    title:SetShadowOffset(1, -1)
    title:SetShadowColor(0, 0, 0, 1)

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
        txt:SetShadowOffset(1, -1)
        txt:SetShadowColor(0, 0, 0, 1)

        local countTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        countTxt:SetPoint("RIGHT", -15, 0)
        countTxt:SetText(string.format("|cffff4444%d Confirmed Kills|r", z.kills or 0))
        countTxt:SetShadowOffset(1, -1)
        countTxt:SetShadowColor(0, 0, 0, 1)

        yOffset = yOffset - 34
    end

    if #zones == 0 then
        local emptyZ = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        emptyZ:SetPoint("TOPLEFT", 10, yOffset)
        emptyZ:SetText("No zone casualty telemetry recorded yet. Engage in combat to populate!")
        emptyZ:SetShadowOffset(1, -1)
        emptyZ:SetShadowColor(0, 0, 0, 1)
        yOffset = yOffset - 30
    end

    UI.ContentFrame:SetHeight(math.abs(yOffset) + 30)
end

-- 6. Render Faction War Rallies & Call to Arms
function UI:RenderRallies()
    local theme = UI:GetTheme()
    local yOffset = -8

    -- Header Title
    local title = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, yOffset)
    title:SetText("📯 |cffffd100FACTION WAR RALLIES & CALL TO ARMS|r")
    title:SetShadowOffset(1, -1)
    title:SetShadowColor(0, 0, 0, 1)

    local myFaction = UnitFactionGroup("player") or "Faction"
    local subtitle = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    subtitle:SetText(string.format("|cffb8a080Open %s Vanguard rallies and squad recruitment across Azeroth. Click to join or sound the War Horn.|r", myFaction))
    subtitle:SetShadowOffset(1, -1)
    subtitle:SetShadowColor(0, 0, 0, 1)

    yOffset = yOffset - 42

    -- Call for Backup / War Horn Action Card
    local hornCard = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
    hornCard:SetSize(820, 38)
    hornCard:SetPoint("TOPLEFT", 0, yOffset)
    hornCard:SetBackdrop(theme.rowBackdrop)

    local isMyBeaconActive = KB.Reinforcements and KB.Reinforcements.IsBeaconActive and KB.Reinforcements:IsBeaconActive()
    if isMyBeaconActive then
        hornCard:SetBackdropColor(0.06, 0.18, 0.08, 0.95)
        hornCard:SetBackdropBorderColor(0.2, 0.8, 0.3, 0.95)
    else
        hornCard:SetBackdropColor(0.12, 0.09, 0.06, 0.95)
        hornCard:SetBackdropBorderColor(0.55, 0.42, 0.18, 0.9)
    end

    local hornTxt = hornCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hornTxt:SetPoint("LEFT", 14, 0)
    if isMyBeaconActive then
        local locStr = (KB.Reinforcements and KB.Reinforcements.GetBeaconLocationStr) and KB.Reinforcements:GetBeaconLocationStr() or "Frontline"
        hornTxt:SetText(string.format("|cff00ff00● YOUR WAR HORN IS ACTIVE|r  |  Broadcasting in |cffffffff%s|r  |  Auto-Invite Open", locStr))
    else
        hornTxt:SetText("|cffffd100Under siege in Open World PvP?|r  |cffb8a080Sound the War Horn to broadcast coordinates and rally faction allies.|r")
    end
    hornTxt:SetShadowOffset(1, -1)
    hornTxt:SetShadowColor(0, 0, 0, 1)

    local hornBtn = UI:CreateButton(hornCard, 150, 24, isMyBeaconActive and "|cffff4444Close Rally|r" or "📯 Sound War Horn")
    hornBtn:SetPoint("RIGHT", -10, 0)
    hornBtn:SetScript("OnClick", function()
        if isMyBeaconActive then
            if KB.Reinforcements and KB.Reinforcements.ResolveBeacon then
                KB.Reinforcements:ResolveBeacon(false)
            end
            UI:Refresh()
        else
            UI:ShowRallyDialog()
        end
    end)

    yOffset = yOffset - 50

    -- Section Title: Open Rallies
    local listTitle = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", 10, yOffset)
    listTitle:SetText(string.format("⚔️ |cffffd100OPEN %s RALLIES|r — Join Vanguard Strike Teams", myFaction:upper()))
    listTitle:SetShadowOffset(1, -1)
    listTitle:SetShadowColor(0, 0, 0, 1)

    yOffset = yOffset - 26

    local rallies = (KB.Reinforcements and KB.Reinforcements.GetOpenRallies) and KB.Reinforcements:GetOpenRallies() or {}

    if #rallies == 0 then
        local empty = UI.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        empty:SetPoint("TOPLEFT", 14, yOffset)
        empty:SetText("No active faction rallies currently underway on your realm.\nSound your War Horn above to muster a Vanguard Strike Team or Raid!")
        empty:SetShadowOffset(1, -1)
        empty:SetShadowColor(0, 0, 0, 1)
        yOffset = yOffset - 40
    else
        for rIdx, r in ipairs(rallies) do
            local row = CreateFrame("Frame", nil, UI.ContentFrame, "BackdropTemplate")
            row:SetSize(820, 46)
            row:SetPoint("TOPLEFT", 0, yOffset)
            row:SetBackdrop(theme.rowBackdrop)

            local isSelf = r.isSelf
            if isSelf then
                row:SetBackdropColor(0.08, 0.18, 0.10, 0.95)
                row:SetBackdropBorderColor(0.2, 0.8, 0.3, 0.95)
            else
                local isEven = (rIdx % 2 == 0)
                row:SetBackdropColor(unpack(isEven and theme.rowBgAlt or theme.rowBg))
                row:SetBackdropBorderColor(unpack(theme.rowBorder))
            end

            -- Commander Icon & Level (Top Line)
            local cIcon = UI:CreateClassIcon(row, r.character_class, 20)
            cIcon:SetPoint("TOPLEFT", 10, -6)

            local cLvl = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            cLvl:SetPoint("LEFT", cIcon, "RIGHT", 4, 0)
            cLvl:SetText(string.format("|cffffd100%d|r", r.character_level or 60))
            cLvl:SetShadowOffset(1, -1)
            cLvl:SetShadowColor(0, 0, 0, 1)

            -- Action Button (Right side, centered vertically)
            local joinBtn
            if isSelf then
                joinBtn = UI:CreateButton(row, 110, 24, "|cffff4444Close Rally|r")
                joinBtn:SetPoint("RIGHT", -10, 0)
                joinBtn:SetScript("OnClick", function()
                    if KB.Reinforcements and KB.Reinforcements.ResolveBeacon then
                        KB.Reinforcements:ResolveBeacon(false)
                    end
                    UI:Refresh()
                end)
            else
                local targetLeader = r.character_name
                joinBtn = UI:CreateButton(row, 115, 24, "⚔️ Join Rally")
                joinBtn:SetPoint("RIGHT", -10, 0)
                joinBtn:SetScript("OnClick", function(self)
                    if KB.Reinforcements and KB.Reinforcements.RequestJoinRally then
                        local ok = KB.Reinforcements:RequestJoinRally(targetLeader)
                        if ok then
                            if self.Label then self.Label:SetText("|cff00ff00Requested!|r") end
                            self:Disable()
                        end
                    end
                end)
            end

            -- Top Line Badges & Commander Info
            local grpBadge = (r.group_type == "RAID") and "|cffa855f7[40-RAID]|r " or "|cff10b981[5-PARTY]|r "
            local cntBadge = (r.content_type == "BG") and "|cffff4444[BG]|r " or "|cffffd100[WORLD]|r "
            local gStr = (r.guild_name and r.guild_name ~= "None" and r.guild_name ~= "") and string.format(" |cff8899aa<%s>|r", r.guild_name) or ""
            local selfTag = isSelf and " |cffffd100[YOU]|r" or ""
            local nameStr = KB.Utils.ColorizeByClass(r.character_name or "Commander", r.character_class) .. selfTag .. gStr

            local topTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            topTxt:SetPoint("LEFT", cLvl, "RIGHT", 8, 0)
            topTxt:SetPoint("RIGHT", joinBtn, "LEFT", -10, 0)
            topTxt:SetJustifyH("LEFT")
            topTxt:SetWordWrap(false)
            topTxt:SetText(grpBadge .. cntBadge .. nameStr)
            topTxt:SetShadowOffset(1, -1)
            topTxt:SetShadowColor(0, 0, 0, 1)

            -- Bottom Line: Location, Level Bracket, Roles Needed, Message & Age
            local diffMin = math.max(1, math.floor((time() - (r.timestamp or time())) / 60))
            local locStr = string.format("📍 |cffffffff%s|r", r.zone or "Wilderness")
            local lvlBracket = string.format("• |cffffd100Lvl %d-%d|r", r.min_level or 1, r.max_level or 60)

            local roleParts = {}
            local roles = r.roles or { tank = true, heal = true, dps = true }
            if roles.tank then table.insert(roleParts, "Tank") end
            if roles.heal then table.insert(roleParts, "Heal") end
            if roles.dps then table.insert(roleParts, "DPS") end
            local roleStr = #roleParts > 0 and table.concat(roleParts, "/") or "Any"
            local rolesNeeded = string.format("• |cff67e8f9Roles: %s|r", roleStr)

            local msg = r.message or "Muster Vanguard!"
            if #msg > 36 then msg = msg:sub(1, 34) .. ".." end
            local msgStr = string.format("• |cffffffff\"%s\"|r", msg)
            local timeStr = string.format("• |cff8899aa~%dm ago|r", diffMin)

            local botTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            botTxt:SetPoint("BOTTOMLEFT", 12, 6)
            botTxt:SetPoint("RIGHT", joinBtn, "LEFT", -10, 0)
            botTxt:SetJustifyH("LEFT")
            botTxt:SetWordWrap(false)
            botTxt:SetText(string.format("%s  %s  %s  %s  %s", locStr, lvlBracket, rolesNeeded, msgStr, timeStr))
            botTxt:SetShadowOffset(1, -1)
            botTxt:SetShadowColor(0, 0, 0, 1)

            yOffset = yOffset - 50
        end
    end

    UI.ContentFrame:SetHeight(math.abs(yOffset) + 40)
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

    local kWebBtn = UI:CreateButton(killerCard, 76, 18, "Web Profile", "GameFontHighlightSmall")
    kWebBtn:SetPoint("BOTTOMRIGHT", -6, 6)
    kWebBtn:SetScript("OnClick", function()
        if modal.currentKillmail and modal.currentKillmail.killer and modal.currentKillmail.killer.name then
            UI:ShowCharacterWebLink(modal.currentKillmail.killer.name)
        end
    end)
    killerCard.WebBtn = kWebBtn
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

    local vWebBtn = UI:CreateButton(victimCard, 76, 18, "Web Profile", "GameFontHighlightSmall")
    vWebBtn:SetPoint("BOTTOMRIGHT", -6, 6)
    vWebBtn:SetScript("OnClick", function()
        if modal.currentKillmail and modal.currentKillmail.victim and modal.currentKillmail.victim.name then
            UI:ShowCharacterWebLink(modal.currentKillmail.victim.name)
        end
    end)
    victimCard.WebBtn = vWebBtn
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
    m.currentKillmail = km

    -- Update Killer Card
    local kCoords = CLASS_COORDS[(km.killer.class or ""):upper()] or {0, 0.25, 0, 0.25}
    m.KillerCard.Icon:SetTexCoord(kCoords[1], kCoords[2], kCoords[3], kCoords[4])
    m.KillerCard.Name:SetText(KB.Utils.ColorizeByClass(km.killer.name, km.killer.class))
    local kLvlStr = (km.killer.level and km.killer.level > 0) and tostring(km.killer.level) or "??"
    local kGuildStr = (km.killer.guild and km.killer.guild ~= "None") and ("<" .. km.killer.guild .. ">") or "Guildless"
    m.KillerCard.Info:SetText(string.format("Level %s %s\n%s\nParty Size: %d\nDamage: %s",
        kLvlStr, km.killer.class or "UNKNOWN", kGuildStr, km.killer.partySize or 1, KB.Utils.FormatNumber(km.killer.damageDone or 0)))

    -- Update Victim Card
    local vCoords = CLASS_COORDS[(km.victim.class or ""):upper()] or {0, 0.25, 0, 0.25}
    m.VictimCard.Icon:SetTexCoord(vCoords[1], vCoords[2], vCoords[3], vCoords[4])
    m.VictimCard.Name:SetText(KB.Utils.ColorizeByClass(km.victim.name, km.victim.class))
    local vLvlStr = (km.victim.level and km.victim.level > 0) and tostring(km.victim.level) or "??"
    local vGuildStr = (km.victim.guild and km.victim.guild ~= "None") and ("<" .. km.victim.guild .. ">") or "Guildless"
    m.VictimCard.Info:SetText(string.format("Level %s %s\n%s\nHostile Gang: %d\nVictim Faction: %s",
        vLvlStr, km.victim.class or "UNKNOWN", vGuildStr, km.victim.partySize or 1, km.victim.faction or "Unknown"))

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

-- Template-Free External Web Profile Link Dialog (Anonymous, 100% Zero Blizzard Taint)
function UI:ShowCharacterWebLink(charName)
    if InCombatLockdown and InCombatLockdown() then
        SafePrint("|cffff9900[WoWKB]|r Cannot open web profile link dialog during combat.")
        return
    end

    charName = charName or UnitName("player") or "Player"
    local rawUrl = string.format("http://13.216.102.148/?character=%s", charName)

    if not UI.WebLinkDialog then
        local dlg = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        dlg:SetSize(480, 160)
        dlg:SetPoint("CENTER")
        dlg:SetFrameStrata("DIALOG")
        dlg:SetFrameLevel(UIParent:GetFrameLevel() + 60)
        dlg:EnableMouse(true)
        dlg:SetClampedToScreen(true)

        -- Theme-aware backdrop
        local theme = UI:GetTheme()
        if theme.id == "classic" then
            dlg:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 24,
                insets = { left = 6, right = 6, top = 6, bottom = 6 }
            })
            dlg:SetBackdropColor(1.0, 1.0, 1.0, 1.0)
            dlg:SetBackdropBorderColor(1.0, 1.0, 1.0, 1.0)
        else
            dlg:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            dlg:SetBackdropColor(0.06, 0.07, 0.10, 0.98)
            dlg:SetBackdropBorderColor(0.0, 0.85, 1.0, 0.8)
        end

        local title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -18)
        title:SetText("|cff00e5ffExternal Web Profile Link|r")
        dlg.Title = title

        local desc = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("TOP", 0, -44)
        desc:SetText("Press |cffffd100Ctrl+C|r to copy your public dossier URL to view or share online:")
        dlg.Desc = desc

        -- EditBox container plate
        local ebPlate = CreateFrame("Frame", nil, dlg, "BackdropTemplate")
        ebPlate:SetSize(430, 30)
        ebPlate:SetPoint("TOP", 0, -68)
        ebPlate:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        ebPlate:SetBackdropColor(0.02, 0.03, 0.05, 0.95)
        ebPlate:SetBackdropBorderColor(0.35, 0.28, 0.16, 0.9)

        local eb = CreateFrame("EditBox", nil, ebPlate)
        eb:SetPoint("LEFT", ebPlate, "LEFT", 10, 0)
        eb:SetPoint("RIGHT", ebPlate, "RIGHT", -10, 0)
        eb:SetHeight(24)
        eb:SetAutoFocus(false)
        eb:SetFontObject("GameFontHighlight")
        eb:SetScript("OnEscapePressed", function() dlg:Hide() end)
        eb:SetScript("OnEnterPressed", function() dlg:Hide() end)
        eb:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
        eb:SetScript("OnChar", function(self)
            if dlg.currentUrl then
                self:SetText(dlg.currentUrl)
                self:HighlightText()
            end
        end)
        dlg.EditBox = eb

        -- Bottom Done Button
        local doneBtn = UI:CreateButton(dlg, 90, 24, "Done")
        doneBtn:SetPoint("BOTTOM", 0, 16)
        doneBtn:SetScript("OnClick", function()
            dlg:Hide()
        end)
        dlg.DoneBtn = doneBtn

        -- Safe ESC key listener without UISpecialFrames (Zero Taint Standard)
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

        UI.WebLinkDialog = dlg
    end

    local dlg = UI.WebLinkDialog
    dlg.currentUrl = rawUrl
    dlg.Title:SetText(string.format("|cff00e5ffWeb Profile — %s|r", charName))
    dlg.EditBox:SetText(rawUrl)
    dlg:Show()
    dlg.EditBox:SetFocus()
    dlg.EditBox:HighlightText()
    if dlg.Raise then dlg:Raise() end
end

-- Template-Free In-Game Combat Export Dialog (Anonymous, 100% Zero Blizzard Taint)
function UI:ShowExportDialog()
    if InCombatLockdown and InCombatLockdown() then
        SafePrint("|cffff9900[WoWKB]|r Cannot open combat export dialog during combat.")
        return
    end

    if not UI.ExportDialog then
        local dlg = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        dlg:SetSize(520, 340)
        dlg:SetPoint("CENTER")
        dlg:SetFrameStrata("DIALOG")
        dlg:SetFrameLevel(100)
        dlg:EnableMouse(true)
        dlg:SetClampedToScreen(true)

        dlg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        dlg:SetBackdropColor(0.06, 0.07, 0.10, 0.98)
        dlg:SetBackdropBorderColor(0.85, 0.65, 0.15, 1.0)

        local title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        title:SetText("|cffffd100WoW Killboard — Combat Data Export|r")
        dlg.Title = title

        local desc = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("TOP", 0, -40)
        desc:SetText("Press |cffffd100Ctrl+A|r then |cffffd100Ctrl+C|r to copy. Paste into the web uploader at |cff00e5ff/upload|r:")
        dlg.Desc = desc

        local inset = CreateFrame("Frame", nil, dlg, "BackdropTemplate")
        inset:SetPoint("TOPLEFT", dlg, "TOPLEFT", 18, -62)
        inset:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -18, 52)
        inset:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        inset:SetBackdropColor(0.02, 0.03, 0.05, 0.95)
        inset:SetBackdropBorderColor(0.35, 0.28, 0.16, 0.9)

        local scrollFrame = CreateFrame("ScrollFrame", nil, inset)
        scrollFrame:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -8)
        scrollFrame:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -8, 8)
        scrollFrame:EnableMouseWheel(true)

        local eb = CreateFrame("EditBox", nil, scrollFrame)
        eb:SetMultiLine(true)
        eb:SetMaxLetters(999999)
        eb:EnableMouse(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject("ChatFontNormal")
        eb:SetWidth(460)
        eb:SetScript("OnEscapePressed", function() dlg:Hide() end)
        scrollFrame:SetScrollChild(eb)
        scrollFrame:SetScript("OnMouseWheel", function(self, delta)
            local current = self:GetVerticalScroll()
            local maxScroll = math.max(0, eb:GetHeight() - self:GetHeight())
            local newScroll = math.max(0, math.min(maxScroll, current - (delta * 30)))
            self:SetVerticalScroll(newScroll)
        end)
        dlg.EditBox = eb

        -- Safe ESC key listener without UISpecialFrames (Zero Taint Standard)
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

        local selectBtn = UI:CreateButton(dlg, 110, 24, "Select All")
        selectBtn:SetPoint("BOTTOMLEFT", 24, 16)
        selectBtn:SetScript("OnClick", function()
            dlg.EditBox:SetFocus()
            dlg.EditBox:HighlightText()
        end)

        local doneBtn = UI:CreateButton(dlg, 90, 24, "Close")
        doneBtn:SetPoint("BOTTOMRIGHT", -24, 16)
        doneBtn:SetScript("OnClick", function() dlg:Hide() end)

        UI.ExportDialog = dlg
    end

    local dlg = UI.ExportDialog
    -- Serialize WoWKillboardDB combat records
    local lines = {}
    table.insert(lines, "WoWKillboardDB = {")
    table.insert(lines, "  [\"kills\"] = {")
    if WoWKillboardDB and WoWKillboardDB.kills then
        for kId, kData in pairs(WoWKillboardDB.kills) do
            table.insert(lines, string.format("    [%q] = {", tostring(kId)))
            table.insert(lines, string.format("      [\"killId\"] = %q,", tostring(kData.killId or kId)))
            table.insert(lines, string.format("      [\"timestamp\"] = %s,", tostring(kData.timestamp or 0)))
            table.insert(lines, string.format("      [\"isSolo\"] = %s,", tostring(kData.isSolo and true or false)))
            table.insert(lines, string.format("      [\"attackersCount\"] = %s,", tostring(kData.attackersCount or 1)))
            table.insert(lines, string.format("      [\"totalDamage\"] = %s,", tostring(kData.totalDamage or 0)))
            if kData.killer then
                table.insert(lines, string.format("      [\"killer\"] = { [\"name\"] = %q, [\"guid\"] = %q, [\"class\"] = %q, [\"level\"] = %s, [\"guild\"] = %q, [\"faction\"] = %q, [\"damageDone\"] = %s },",
                    kData.killer.name or "Unknown", kData.killer.guid or "UNKNOWN", kData.killer.class or "UNKNOWN", tostring(kData.killer.level or 0), kData.killer.guild or "None", kData.killer.faction or "Unknown", tostring(kData.killer.damageDone or 0)))
            end
            if kData.victim then
                table.insert(lines, string.format("      [\"victim\"] = { [\"name\"] = %q, [\"guid\"] = %q, [\"class\"] = %q, [\"level\"] = %s, [\"guild\"] = %q, [\"faction\"] = %q },",
                    kData.victim.name or "Unknown", kData.victim.guid or "UNKNOWN", kData.victim.class or "UNKNOWN", tostring(kData.victim.level or 0), kData.victim.guild or "None", kData.victim.faction or "Unknown"))
            end
            if kData.location then
                table.insert(lines, string.format("      [\"location\"] = { [\"zone\"] = %q, [\"subZone\"] = %q, [\"x\"] = %s, [\"y\"] = %s, [\"mapId\"] = %s },",
                    kData.location.zone or "Wilderness", kData.location.subZone or "", tostring(kData.location.x or 0), tostring(kData.location.y or 0), tostring(kData.location.mapId or 0)))
            end
            table.insert(lines, "    },")
        end
    end
    table.insert(lines, "  },")
    table.insert(lines, "}")

    local exportStr = table.concat(lines, "\n")
    dlg.EditBox:SetText(exportStr)
    dlg:Show()
    dlg.EditBox:SetFocus()
    dlg.EditBox:HighlightText()
    if dlg.Raise then dlg:Raise() end
end

-- Isolated, Taint-Free Bounty Dialog Frame (Anonymous, 100% Template-Free)
function UI:ShowBountyPrompt()
    if InCombatLockdown() then
        SafePrint("|cffff9900[WoWKB]|r Cannot open Mark of Spite dialog during combat.")
        return
    end

    if IsInInstance then
        local inInst, instType = IsInInstance()
        if inInst or (instType and instType ~= "none") then
            SafePrint("|cffff0000[WoWKB Error]|r Marks of Spite can only be declared upon the open battlefields of Azeroth (Open World PvP only).")
            return
        end
    end

    if not UI.BountyDialog then
        local dlg = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        dlg:SetSize(420, 205)
        dlg:SetPoint("CENTER")
        dlg:SetFrameStrata("DIALOG")
        dlg:EnableMouse(true)
        dlg:SetClampedToScreen(true)
        dlg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        dlg:SetBackdropColor(0.08, 0.09, 0.12, 0.98)
        dlg:SetBackdropBorderColor(1.0, 0.84, 0.0, 0.8)

        local t = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        t:SetPoint("TOP", 0, -14)
        t:SetText("|cffff3333Declare Mark of Spite|r")

        local desc = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("TOP", 0, -36)
        desc:SetText("Sanction an open-world hunt on a hostile adversary.")

        -- Target Name Row
        local targetLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        targetLabel:SetPoint("TOPLEFT", 28, -66)
        targetLabel:SetText("Target Name:")

        local ebName = CreateFrame("EditBox", nil, dlg, "BackdropTemplate")
        ebName:SetSize(220, 24)
        ebName:SetPoint("LEFT", targetLabel, "RIGHT", 14, 0)
        ebName:SetAutoFocus(false)
        ebName:SetFontObject("GameFontHighlight")
        ebName:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        ebName:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
        ebName:SetBackdropBorderColor(0.3, 0.35, 0.45, 1)
        ebName:SetTextInsets(6, 6, 0, 0)
        dlg.targetBox = ebName

        -- Mark Amount Row (Gold, Silver, Copper)
        local amtLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        amtLabel:SetPoint("TOPLEFT", 28, -104)
        amtLabel:SetText("Mark Amount:")

        -- Gold Box
        local ebGold = CreateFrame("EditBox", nil, dlg, "BackdropTemplate")
        ebGold:SetSize(54, 24)
        ebGold:SetPoint("LEFT", amtLabel, "RIGHT", 14, 0)
        ebGold:SetAutoFocus(false)
        ebGold:SetNumeric(true)
        ebGold:SetNumber(10)
        ebGold:SetFontObject("GameFontHighlight")
        ebGold:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        ebGold:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
        ebGold:SetBackdropBorderColor(0.3, 0.35, 0.45, 1)
        ebGold:SetTextInsets(4, 4, 0, 0)
        dlg.goldBox = ebGold

        local gIcon = dlg:CreateTexture(nil, "ARTWORK")
        gIcon:SetSize(14, 14)
        gIcon:SetPoint("LEFT", ebGold, "RIGHT", 4, 0)
        gIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")

        -- Silver Box
        local ebSilver = CreateFrame("EditBox", nil, dlg, "BackdropTemplate")
        ebSilver:SetSize(40, 24)
        ebSilver:SetPoint("LEFT", gIcon, "RIGHT", 8, 0)
        ebSilver:SetAutoFocus(false)
        ebSilver:SetNumeric(true)
        ebSilver:SetNumber(0)
        ebSilver:SetFontObject("GameFontHighlight")
        ebSilver:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        ebSilver:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
        ebSilver:SetBackdropBorderColor(0.3, 0.35, 0.45, 1)
        ebSilver:SetTextInsets(4, 4, 0, 0)
        dlg.silverBox = ebSilver

        local sIcon = dlg:CreateTexture(nil, "ARTWORK")
        sIcon:SetSize(14, 14)
        sIcon:SetPoint("LEFT", ebSilver, "RIGHT", 4, 0)
        sIcon:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")

        -- Copper Box
        local ebCopper = CreateFrame("EditBox", nil, dlg, "BackdropTemplate")
        ebCopper:SetSize(40, 24)
        ebCopper:SetPoint("LEFT", sIcon, "RIGHT", 8, 0)
        ebCopper:SetAutoFocus(false)
        ebCopper:SetNumeric(true)
        ebCopper:SetNumber(0)
        ebCopper:SetFontObject("GameFontHighlight")
        ebCopper:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        ebCopper:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
        ebCopper:SetBackdropBorderColor(0.3, 0.35, 0.45, 1)
        ebCopper:SetTextInsets(4, 4, 0, 0)
        dlg.copperBox = ebCopper

        local cIcon = dlg:CreateTexture(nil, "ARTWORK")
        cIcon:SetSize(14, 14)
        cIcon:SetPoint("LEFT", ebCopper, "RIGHT", 4, 0)
        cIcon:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")

        local note = dlg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        note:SetPoint("TOP", 0, -140)
        note:SetText("|cff888888Awarded to the hunter who delivers the final killing blow (Open World only).|r")

        -- Buttons: Declare Mark and Cancel
        local okBtn = UI:CreateButton(dlg, 130, 26, "Declare Mark")
        okBtn:SetPoint("BOTTOMLEFT", 45, 16)
        okBtn:SetScript("OnClick", function()
            local targetName = (ebName:GetText() or ""):match("^%s*(.-)%s*$")
            if not targetName or targetName == "" then
                SafePrint("|cffff0000[WoWKB Error]|r Target Name cannot be empty.")
                return
            end
            local gold = tonumber(ebGold:GetText()) or 0
            local silver = tonumber(ebSilver:GetText()) or 0
            local copper = tonumber(ebCopper:GetText()) or 0
            local totalCopper = (gold * 10000) + (silver * 100) + copper
            if totalCopper <= 0 then
                SafePrint("|cffff0000[WoWKB Error]|r Mark amount must be greater than 0.")
                return
            end

            local success = KB.BountyEngine:PlaceBounty(targetName, "UNKNOWN", "Unknown", totalCopper, nil, true)
            if success then
                dlg:Hide()
                if UI.RefreshIfVisible then UI:RefreshIfVisible() end
            end
        end)

        local cancelBtn = UI:CreateButton(dlg, 110, 26, "Cancel")
        cancelBtn:SetPoint("BOTTOMRIGHT", -45, 16)
        cancelBtn:SetScript("OnClick", function() dlg:Hide() end)

        UI.BountyDialog = dlg
    end

    UI.BountyDialog.targetBox:SetText("")
    UI.BountyDialog.goldBox:SetText("10")
    UI.BountyDialog.silverBox:SetText("0")
    UI.BountyDialog.copperBox:SetText("0")
    UI.BountyDialog:Show()
    UI.BountyDialog.targetBox:SetFocus()
end

-- Death Bounty Prompt Dialog: Triggered when player is slain in PvP (Open World Only)
function UI:ShowDeathBountyPrompt(killerData)
    if not killerData or not killerData.name then return end
    local s = WoWKillboardSettings or KB.DefaultSettings or {}
    if s.promptMarkOnDeath == false or s.promptBountyOnDeath == false then
        return
    end
    if InCombatLockdown() then
        UI.PendingDeathBountyKiller = killerData
        return
    end

    if IsInInstance then
        local inInst, instType = IsInInstance()
        if inInst or (instType and instType ~= "none") then return end
    end

    if not UI.DeathBountyDialog then
        local dlg = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        dlg:SetSize(440, 220)
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
        title:SetText("|cffff2222FALLEN IN BATTLE — DECLARE MARK OF SPITE|r")

        local desc = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        desc:SetPoint("TOP", 0, -46)
        desc:SetJustifyH("CENTER")
        dlg.DescText = desc

        local amtLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        amtLabel:SetPoint("TOPLEFT", 48, -96)
        amtLabel:SetText("Mark Amount:")

        -- Gold Box
        local ebGold = CreateFrame("EditBox", nil, dlg, "BackdropTemplate")
        ebGold:SetSize(54, 24)
        ebGold:SetPoint("LEFT", amtLabel, "RIGHT", 14, 0)
        ebGold:SetAutoFocus(false)
        ebGold:SetNumeric(true)
        ebGold:SetNumber(50)
        ebGold:SetFontObject("GameFontHighlight")
        ebGold:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        ebGold:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
        ebGold:SetBackdropBorderColor(0.3, 0.35, 0.45, 1)
        ebGold:SetTextInsets(4, 4, 0, 0)
        dlg.goldBox = ebGold

        local gIcon = dlg:CreateTexture(nil, "ARTWORK")
        gIcon:SetSize(14, 14)
        gIcon:SetPoint("LEFT", ebGold, "RIGHT", 4, 0)
        gIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")

        -- Silver Box
        local ebSilver = CreateFrame("EditBox", nil, dlg, "BackdropTemplate")
        ebSilver:SetSize(40, 24)
        ebSilver:SetPoint("LEFT", gIcon, "RIGHT", 8, 0)
        ebSilver:SetAutoFocus(false)
        ebSilver:SetNumeric(true)
        ebSilver:SetNumber(0)
        ebSilver:SetFontObject("GameFontHighlight")
        ebSilver:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        ebSilver:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
        ebSilver:SetBackdropBorderColor(0.3, 0.35, 0.45, 1)
        ebSilver:SetTextInsets(4, 4, 0, 0)
        dlg.silverBox = ebSilver

        local sIcon = dlg:CreateTexture(nil, "ARTWORK")
        sIcon:SetSize(14, 14)
        sIcon:SetPoint("LEFT", ebSilver, "RIGHT", 4, 0)
        sIcon:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")

        -- Copper Box
        local ebCopper = CreateFrame("EditBox", nil, dlg, "BackdropTemplate")
        ebCopper:SetSize(40, 24)
        ebCopper:SetPoint("LEFT", sIcon, "RIGHT", 8, 0)
        ebCopper:SetAutoFocus(false)
        ebCopper:SetNumeric(true)
        ebCopper:SetNumber(0)
        ebCopper:SetFontObject("GameFontHighlight")
        ebCopper:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        ebCopper:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
        ebCopper:SetBackdropBorderColor(0.3, 0.35, 0.45, 1)
        ebCopper:SetTextInsets(4, 4, 0, 0)
        dlg.copperBox = ebCopper

        local cIcon = dlg:CreateTexture(nil, "ARTWORK")
        cIcon:SetSize(14, 14)
        cIcon:SetPoint("LEFT", ebCopper, "RIGHT", 4, 0)
        cIcon:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")

        local note = dlg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        note:SetPoint("TOP", 0, -136)
        note:SetText("|cff888888Execution contract awarded only to the hunter who lands the final blow (Open World only).|r")

        local okBtn = UI:CreateButton(dlg, 140, 26, "Declare Mark")
        okBtn:SetPoint("BOTTOMLEFT", 45, 16)
        okBtn:SetScript("OnClick", function()
            local gold = tonumber(ebGold:GetText()) or 0
            local silver = tonumber(ebSilver:GetText()) or 0
            local copper = tonumber(ebCopper:GetText()) or 0
            local totalCopper = (gold * 10000) + (silver * 100) + copper
            if totalCopper > 0 and dlg.CurrentKiller then
                local k = dlg.CurrentKiller
                local success = KB.BountyEngine:PlaceBounty(k.name, k.class or "UNKNOWN", k.faction or "Unknown", totalCopper, k.guid, true)
                if success then
                    dlg:Hide()
                    if UI.RefreshIfVisible then UI:RefreshIfVisible() end
                end
            end
        end)

        local cancelBtn = UI:CreateButton(dlg, 130, 26, "Cancel")
        cancelBtn:SetPoint("BOTTOMRIGHT", -45, 16)
        cancelBtn:SetScript("OnClick", function()
            dlg:Hide()
        end)

        UI.DeathBountyDialog = dlg
    end

    UI.DeathBountyDialog.CurrentKiller = killerData
    UI.DeathBountyDialog.DescText:SetText(string.format("The soil drinks your blood! |cffff3333%s|r has slain you in open combat.\nDeclare a Mark of Spite for their head upon a pike!", killerData.name))
    UI.DeathBountyDialog.goldBox:SetText("50")
    UI.DeathBountyDialog.silverBox:SetText("0")
    UI.DeathBountyDialog.copperBox:SetText("0")
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
                SafePrint(string.format("|cff00ff00[WoWKB]|r Answering the call for |cffffd100%s|r! Marching to reinforce in %s!", target, dlg.CurrentBeacon.zone or "Wilderness"))
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
            if InCombatLockdown() then
                raidNoticeFrame:SetAlpha(0)
                UI.PendingHides = UI.PendingHides or {}
                table.insert(UI.PendingHides, raidNoticeFrame)
            else
                raidNoticeFrame:Hide()
            end
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
    killBanner:SetBackdropColor(0.04, 0.06, 0.09, 0.60)
    killBanner:SetBackdropBorderColor(0, 0, 0, 0)
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

    -- 1. If killmail is a 1v1 duel or alerts are completely disabled, exit immediately (unless explicit test)
    if not isTest and killmail.isDuel then return end
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
            PlaySound(soundId, "Master")
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
            banner:SetBackdropBorderColor(0, 0, 0, 0)
        elseif killmail.isArena then
            banner.CenterAction:SetText("|cffa335eeARENA EXECUTION|r")
            banner.ModeTag:SetText("|cffa335eeRATED ARENA MATCH|r")
            banner.TopAccent:SetColorTexture(0.64, 0.21, 0.93, 1.0)
            banner:SetBackdropBorderColor(0, 0, 0, 0)
        elseif killmail.isBattleground then
            banner.CenterAction:SetText("|cff00ccffWARFRONT EXECUTION|r")
            banner.ModeTag:SetText(string.format("|cff00ccff%s (x%d)|r", killmail.battlegroundName or "Battleground", killmail.attackersCount or 1))
            banner.TopAccent:SetColorTexture(0.0, 0.8, 1.0, 1.0)
            banner:SetBackdropBorderColor(0, 0, 0, 0)
        elseif killmail.isSolo then
            banner.CenterAction:SetText("|cff00ff00SOLO DESTROYED|r")
            banner.ModeTag:SetText("|cff00ff00CERTIFIED 1v1 OPEN WORLD|r")
            banner.TopAccent:SetColorTexture(0.0, 1.0, 0.4, 1.0)
            banner:SetBackdropBorderColor(0, 0, 0, 0)
        else
            banner.CenterAction:SetText("|cffff9900TARGET ELIMINATED|r")
            banner.ModeTag:SetText(string.format("|cffff9900GANG COMBAT (x%d Attackers)|r", killmail.attackersCount or 2))
            banner.TopAccent:SetColorTexture(1.0, 0.6, 0.0, 1.0)
            banner:SetBackdropBorderColor(0, 0, 0, 0)
        end

        -- Location Subtitle
        local loc = killmail.location or {}
        local zoneStr = loc.zone or "Azeroth"
        if loc.subZone and loc.subZone ~= "" then
            zoneStr = zoneStr .. " - " .. loc.subZone
        end
        banner.LocText:SetText(string.format("|cff888888%s  |  %.1f, %.1f|r", zoneStr, loc.x or 0, loc.y or 0))

        banner:SetAlpha(1.0)
        banner:Show()
        if not UI.bannerUnlocked then
            if killBannerTimer then killBannerTimer:Cancel() end
            killBannerTimer = C_Timer.NewTimer(4.5, function()
                if banner and not UI.bannerUnlocked then
                    if InCombatLockdown() then
                        banner:SetAlpha(0)
                        UI.PendingHides = UI.PendingHides or {}
                        table.insert(UI.PendingHides, banner)
                    else
                        banner:Hide()
                    end
                end
            end)
        end
    end
end

-- Toggle Banner Drag / Positioning Mode
function UI:ToggleBannerLock(explicitState)
    if InCombatLockdown() then
        SafePrint("|cffff9900[WoWKB]|r Cannot move alert banner during combat.")
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
        banner:RegisterForDrag("LeftButton")
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
        banner.TopAccent:SetColorTexture(0, 0, 0, 0)
        banner:SetBackdropColor(0.04, 0.06, 0.09, 0.60)
        banner:SetBackdropBorderColor(0, 0, 0, 0)
        banner:Show()

        UI:ShowRaidNotice("|cffff3333[WoWKB RAID WARNING PREVIEW]|r Enemy Target Destroyed", "Raid Warning Style Text will display here", 1.0, 0.28, 0.0)

        SafePrint("|cff00ccff[WoWKB Alert]|r Alert Anchor unlocked! Click and drag with |cffffd100Left-Click|r anywhere on your screen. Type |cffffd100/wowkb move|r again or click Lock to save.")
    else
        banner:EnableMouse(false) -- Revert to click-through immediately
        banner:RegisterForDrag()  -- Unregister drag listeners
        banner:Hide()
        if raidNoticeFrame then raidNoticeFrame:Hide() end
        local pos = WoWKillboardSettings and WoWKillboardSettings.bannerPosition or { point = "TOP", x = 0, y = -135 }
        SafePrint(string.format("|cff00ccff[WoWKB Alert]|r Alert Anchor locked at %s (X: %d, Y: %d). Saved across reloads!", pos.point or "TOP", pos.x or 0, pos.y or -135))
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
    SafePrint("|cff00ccff[WoWKB Alert]|r Alert position reset to default screen coordinates (Center-Top).")
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
        SafePrint("|cffff9900[WoWKB]|r Cannot open configuration during combat.")
        return
    end

    if not UI.AlertsDialog then
        local dlg = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        dlg:SetSize(520, 630)
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

        -- Section 5: Mark of Spite Death Popup
        local sec5Title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec5Title:SetPoint("TOPLEFT", 24, -374)
        sec5Title:SetText("|cffffffff5. MARK OF SPITE DEATH POPUP|r")

        local btnMarkPromptOn = UI:CreateButton(dlg, 230, 24, "Prompt on Death", "GameFontHighlightSmall")
        btnMarkPromptOn:SetPoint("TOPLEFT", 24, -394)
        StyleSegmentButton(btnMarkPromptOn, "Prompt on Death")
        dlg.BtnMarkPromptOn = btnMarkPromptOn

        local btnMarkPromptOff = UI:CreateButton(dlg, 230, 24, "Never Prompt / Muted", "GameFontHighlightSmall")
        btnMarkPromptOff:SetPoint("LEFT", btnMarkPromptOn, "RIGHT", 12, 0)
        StyleSegmentButton(btnMarkPromptOff, "Never Prompt / Muted")
        dlg.BtnMarkPromptOff = btnMarkPromptOff

        local markHint = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        markHint:SetPoint("TOPLEFT", 24, -422)
        dlg.MarkHint = markHint

        -- Section 6: Combat Feed Destination (Pop-Out Wire vs Main Chat)
        local sec6Title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec6Title:SetPoint("TOPLEFT", 24, -446)
        sec6Title:SetText("|cffffffff6. COMBAT FEED DESTINATION|r")

        local btnFeedWire = UI:CreateButton(dlg, 150, 24, "Pop-Out Wire", "GameFontHighlightSmall")
        btnFeedWire:SetPoint("TOPLEFT", 24, -466)
        StyleSegmentButton(btnFeedWire, "Pop-Out Wire")
        dlg.BtnFeedWire = btnFeedWire

        local btnFeedChat = UI:CreateButton(dlg, 150, 24, "Main Chat Frame", "GameFontHighlightSmall")
        btnFeedChat:SetPoint("LEFT", btnFeedWire, "RIGHT", 11, 0)
        StyleSegmentButton(btnFeedChat, "Main Chat Frame")
        dlg.BtnFeedChat = btnFeedChat

        local btnFeedOff = UI:CreateButton(dlg, 150, 24, "Muted / Off", "GameFontHighlightSmall")
        btnFeedOff:SetPoint("LEFT", btnFeedChat, "RIGHT", 11, 0)
        StyleSegmentButton(btnFeedOff, "Muted / Off")
        dlg.BtnFeedOff = btnFeedOff

        local feedHint = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        feedHint:SetPoint("TOPLEFT", 24, -494)
        dlg.FeedHint = feedHint

        -- Bottom Divider
        local bDiv = dlg:CreateTexture(nil, "ARTWORK")
        bDiv:SetHeight(1)
        bDiv:SetPoint("TOPLEFT", 18, -522)
        bDiv:SetPoint("TOPRIGHT", -18, -522)
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

            -- Section 5: Mark of Spite Death Popup
            local promptEnabled = (s.promptMarkOnDeath ~= false and s.promptBountyOnDeath ~= false)
            ApplySegmentState(dlg.BtnMarkPromptOn, promptEnabled)
            ApplySegmentState(dlg.BtnMarkPromptOff, not promptEnabled)

            if promptEnabled then
                dlg.MarkHint:SetText("|cff00ff00● Enabled:|r |cff94a3b8Prompts revenge Mark of Spite contract upon dying in Open World.|r")
            else
                dlg.MarkHint:SetText("|cffff3333● Disabled:|r |cff94a3b8Suppresses popup upon PvP death. Mark contracts can still be set in War Room.|r")
            end

            -- Section 6: Combat Feed Destination
            local feedMode = s.combatFeedMode or "POPOUT"
            ApplySegmentState(dlg.BtnFeedWire, feedMode == "POPOUT")
            ApplySegmentState(dlg.BtnFeedChat, feedMode == "CHAT")
            ApplySegmentState(dlg.BtnFeedOff, feedMode == "OFF")

            if feedMode == "POPOUT" then
                dlg.FeedHint:SetText("|cff00e5ff● Pop-Out Wire:|r |cff94a3b8Routes combat events to floating Combat Wire window. Zero chat spam.|r")
            elseif feedMode == "CHAT" then
                dlg.FeedHint:SetText("|cffffd100● Main Chat:|r |cff94a3b8Prints combat records directly to your standard General chat frame.|r")
            else
                dlg.FeedHint:SetText("|cffff3333● Muted:|r |cff94a3b8Suppresses both chat and wire feed. Combat is recorded silently.|r")
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

        -- Section 5 Event Handlers
        btnMarkPromptOn:SetScript("OnClick", function()
            local s = WoWKillboardSettings or KB.DefaultSettings
            s.promptMarkOnDeath = true
            s.promptBountyOnDeath = true
            UpdateControls()
        end)
        btnMarkPromptOff:SetScript("OnClick", function()
            local s = WoWKillboardSettings or KB.DefaultSettings
            s.promptMarkOnDeath = false
            s.promptBountyOnDeath = false
            UpdateControls()
        end)

        -- Section 6 Event Handlers
        btnFeedWire:SetScript("OnClick", function()
            local s = WoWKillboardSettings or KB.DefaultSettings
            s.combatFeedMode = "POPOUT"
            s.showCombatWire = true
            if not InCombatLockdown() then UI:InitializeCombatWire() end
            if UI.CombatWireHUD then UI.CombatWireHUD:Show() end
            UpdateControls()
        end)
        btnFeedChat:SetScript("OnClick", function()
            local s = WoWKillboardSettings or KB.DefaultSettings
            s.combatFeedMode = "CHAT"
            UpdateControls()
        end)
        btnFeedOff:SetScript("OnClick", function()
            local s = WoWKillboardSettings or KB.DefaultSettings
            s.combatFeedMode = "OFF"
            UpdateControls()
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

--------------------------------------------------------------------------------
-- Tactical Radar HUD (Moveable, Togglable Floating Hostile Scanner Window)
--------------------------------------------------------------------------------
local radarHUD = nil
local radarEntries = {}

function UI:InitializeRadarHUD()
    if radarHUD or InCombatLockdown() then return end

    local hud = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    hud:SetSize(270, 114)
    hud:SetFrameStrata("MEDIUM")
    hud:SetClampedToScreen(true)
    hud:SetMovable(true)
    hud:EnableMouse(true)
    hud:RegisterForDrag("LeftButton")

    -- Restore saved position or default to TOPRIGHT, -220, -160
    local pos = WoWKillboardSettings and WoWKillboardSettings.radarPos
    if pos and pos.point and pos.relPoint and pos.x and pos.y then
        hud:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        hud:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -220, -160)
    end

    hud:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    hud:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        WoWKillboardSettings = WoWKillboardSettings or {}
        WoWKillboardSettings.radarPos = { point = p, relPoint = rp, x = math.floor(x), y = math.floor(y) }
    end)

    -- Sleek dark tactical gunmetal backdrop
    hud:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    hud:SetBackdropColor(0.035, 0.045, 0.065, 0.94)
    hud:SetBackdropBorderColor(0.0, 0.85, 1.0, 0.75)

    -- Header Drag Bar
    local header = CreateFrame("Frame", nil, hud, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(20)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    header:SetBackdropColor(0.07, 0.10, 0.15, 0.98)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() if not InCombatLockdown() then hud:StartMoving() end end)
    header:SetScript("OnDragStop", function()
        hud:StopMovingOrSizing()
        local p, _, rp, x, y = hud:GetPoint()
        WoWKillboardSettings = WoWKillboardSettings or {}
        WoWKillboardSettings.radarPos = { point = p, relPoint = rp, x = math.floor(x), y = math.floor(y) }
    end)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("LEFT", 6, 0)
    title:SetText("|cff00e5ffKB RADAR|r  |cff64748b(Tactical HUD)|r")

    -- Close Button
    local close = CreateFrame("Button", nil, header)
    close:SetSize(16, 16)
    close:SetPoint("RIGHT", -2, 0)
    local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    closeText:SetPoint("CENTER", 0, 0)
    closeText:SetText("|cffff4444X|r")
    close:SetScript("OnClick", function()
        hud:Hide()
        SafePrint("|cff00ccff[WoWKB]|r Tactical Radar HUD hidden. Type |cffffff00/kb radar|r to show.")
    end)

    -- Hostile Entry Rows (Up to 3 hostiles displayed cleanly)
    hud.rows = {}
    for i = 1, 3 do
        local row = CreateFrame("Frame", nil, hud)
        row:SetSize(262, 28)
        row:SetPoint("TOPLEFT", 4, -22 - (i - 1) * 30)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", 4, 0)
        row.icon = icon

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameText:SetPoint("LEFT", icon, "RIGHT", 6, 4)
        nameText:SetJustifyH("LEFT")
        row.nameText = nameText

        local subText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        subText:SetPoint("LEFT", icon, "RIGHT", 6, -8)
        subText:SetJustifyH("LEFT")
        row.subText = subText

        local timeText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        timeText:SetPoint("RIGHT", -6, 4)
        timeText:SetJustifyH("RIGHT")
        row.timeText = timeText

        row:Hide()
        table.insert(hud.rows, row)
    end

    local emptyText = hud:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("CENTER", 0, -8)
    emptyText:SetText("|cff64748bNo hostiles in immediate proximity|r")
    hud.emptyText = emptyText

    radarHUD = hud
    UI.RadarHUD = hud
    hud:Hide()
end

function UI:RefreshRadarHUD()
    if not radarHUD then return end
    local count = #radarEntries
    if count == 0 then
        radarHUD.emptyText:Show()
        for _, row in ipairs(radarHUD.rows) do row:Hide() end
        radarHUD:SetHeight(54)
    else
        radarHUD.emptyText:Hide()
        for i = 1, 3 do
            local row = radarHUD.rows[i]
            local entry = radarEntries[i]
            if entry then
                local col = (KB.ClassColors and KB.ClassColors[entry.class]) or "FFFFFF"
                local lvlStr = (entry.level and entry.level > 0 and entry.level <= 85) and string.format("[%d] ", entry.level) or ""
                row.nameText:SetText(string.format("|cff%s%s%s|r", col, lvlStr, entry.name))

                local guildStr = (entry.guild and entry.guild ~= "None" and entry.guild ~= "") and (" <" .. entry.guild .. ">") or ""
                local zoneShort = entry.zone or "Wilderness"
                if #zoneShort > 22 then zoneShort = zoneShort:sub(1, 20) .. ".." end
                row.subText:SetText(string.format("|cff94a3b8%s%s|r", zoneShort, guildStr))

                local diff = math.max(0, time() - (entry.time or time()))
                local timeStr = (diff < 60) and string.format("%ds ago", diff) or string.format("%dm ago", math.floor(diff / 60))
                row.timeText:SetText(string.format("|cff64748b%s|r", timeStr))

                local coords = CLASS_COORDS and CLASS_COORDS[entry.class]
                if coords then
                    row.icon:SetTexture(CLASS_ICON_TEXTURE or "Interface\\TargetingFrame\\UI-Classes-Circles")
                    row.icon:SetTexCoord(unpack(coords))
                    row.icon:Show()
                else
                    row.icon:Hide()
                end

                row:Show()
            else
                row:Hide()
            end
        end
        radarHUD:SetHeight(24 + count * 30)
    end
end

function UI:UpdateRadarHUD(info)
    if InCombatLockdown() then return end
    if not radarHUD then UI:InitializeRadarHUD() end
    if not radarHUD then return end

    local s = WoWKillboardSettings or KB.DefaultSettings
    if s and s.showRadarHUD == false then return end

    -- Check if hostile already in radarEntries and update
    local found = nil
    for idx, e in ipairs(radarEntries) do
        if e.name == info.name then
            found = idx
            break
        end
    end
    if found then
        table.remove(radarEntries, found)
    end
    table.insert(radarEntries, 1, {
        name = info.name,
        class = (info.class or "UNKNOWN"):upper(),
        level = info.level or 0,
        guild = info.guild,
        zone = GetZoneText() or "Wilderness",
        time = time(),
    })
    while #radarEntries > 3 do
        table.remove(radarEntries)
    end

    UI:RefreshRadarHUD()
    radarHUD:SetAlpha(1.0)
    radarHUD:Show()

    -- Auto-dismiss timer after 15 seconds of inactivity if not hovered
    if radarHUD.fadeTimer then
        radarHUD.fadeTimer:Cancel()
    end
    if C_Timer and C_Timer.NewTimer then
        radarHUD.fadeTimer = C_Timer.NewTimer(15, function()
            if radarHUD and not radarHUD:IsMouseOver() then
                if InCombatLockdown() then
                    radarHUD:SetAlpha(0)
                    UI.PendingHides = UI.PendingHides or {}
                    table.insert(UI.PendingHides, radarHUD)
                else
                    radarHUD:Hide()
                end
            end
        end)
    end
end

function UI:ToggleRadarHUD()
    if InCombatLockdown() then
        SafePrint("|cffff9900[WoWKB]|r Cannot toggle Tactical Radar HUD during combat.")
        return
    end
    if not radarHUD then UI:InitializeRadarHUD() end
    if not radarHUD then return end
    if radarHUD:IsShown() then
        radarHUD:Hide()
        SafePrint("|cff00ccff[WoWKB]|r Tactical Radar HUD: |cffff4444Hidden|r.")
    else
        UI:RefreshRadarHUD()
        radarHUD:SetAlpha(1.0)
        radarHUD:Show()
        SafePrint("|cff00ccff[WoWKB]|r Tactical Radar HUD: |cff00ff00Shown|r (Click & drag header to reposition).")
    end
end

--------------------------------------------------------------------------------
-- War Council Rally Muster Dialog (Vanguard Squad & Raid Recruitment Panel)
--------------------------------------------------------------------------------
function UI:ShowRallyDialog()
    if InCombatLockdown() then
        SafePrint("|cffff0000[WoWKB]|r Cannot muster war rally during combat lockdown.")
        return
    end

    if not UI.RallyDialog then
        local dlg = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        dlg:SetSize(480, 480)
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

        -- ESC Key Handling
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

        -- Header
        local title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        title:SetText("📯 |cffffd100MUSTER FACTION VANGUARD RALLY|r")
        dlg.TitleText = title

        local subtitle = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subtitle:SetPoint("TOP", 0, -38)
        subtitle:SetText("|cff94a3b8Sound the War Horn to assemble allies for coordinated PvP engagements.|r")
        dlg.SubtitleText = subtitle

        local div = dlg:CreateTexture(nil, "ARTWORK")
        div:SetHeight(1)
        div:SetPoint("TOPLEFT", 18, -56)
        div:SetPoint("TOPRIGHT", -18, -56)
        dlg.Divider = div

        -- Helper to style segment buttons
        local function StyleChip(btn, text)
            btn.baseText = text
            btn.Label:SetText(text)
        end
        local function SetChipActive(btn, isActive)
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

        -- State variables
        dlg.selectedGroupType = "PARTY"
        dlg.selectedContentType = "WORLD"
        dlg.selectedRoles = { tank = true, heal = true, dps = true }

        -- 1. Group Size
        local sec1Title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec1Title:SetPoint("TOPLEFT", 24, -68)
        sec1Title:SetText("|cffffffff1. SQUAD CAPACITY / GROUP SIZE|r")

        local btnParty = UI:CreateButton(dlg, 210, 24, "5-Man Squad (Party)", "GameFontHighlightSmall")
        btnParty:SetPoint("TOPLEFT", 24, -88)
        StyleChip(btnParty, "5-Man Squad (Party)")
        dlg.BtnParty = btnParty

        local btnRaid = UI:CreateButton(dlg, 210, 24, "40-Man Strike Team (Raid)", "GameFontHighlightSmall")
        btnRaid:SetPoint("LEFT", btnParty, "RIGHT", 12, 0)
        StyleChip(btnRaid, "40-Man Strike Team (Raid)")
        dlg.BtnRaid = btnRaid

        btnParty:SetScript("OnClick", function()
            dlg.selectedGroupType = "PARTY"
            SetChipActive(dlg.BtnParty, true)
            SetChipActive(dlg.BtnRaid, false)
        end)
        btnRaid:SetScript("OnClick", function()
            dlg.selectedGroupType = "RAID"
            SetChipActive(dlg.BtnParty, false)
            SetChipActive(dlg.BtnRaid, true)
        end)

        -- 2. Content Type
        local sec2Title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec2Title:SetPoint("TOPLEFT", 24, -122)
        sec2Title:SetText("|cffffffff2. THEATRE / CONTENT TYPE|r")

        local btnWorld = UI:CreateButton(dlg, 210, 24, "Open World PvP", "GameFontHighlightSmall")
        btnWorld:SetPoint("TOPLEFT", 24, -142)
        StyleChip(btnWorld, "Open World PvP")
        dlg.BtnWorld = btnWorld

        local btnBG = UI:CreateButton(dlg, 210, 24, "Battleground", "GameFontHighlightSmall")
        btnBG:SetPoint("LEFT", btnWorld, "RIGHT", 12, 0)
        StyleChip(btnBG, "Battleground")
        dlg.BtnBG = btnBG

        btnWorld:SetScript("OnClick", function()
            dlg.selectedContentType = "WORLD"
            SetChipActive(dlg.BtnWorld, true)
            SetChipActive(dlg.BtnBG, false)
            if dlg.ebLocation and (dlg.ebLocation:GetText() == "" or dlg.ebLocation:GetText():find("Warsong") or dlg.ebLocation:GetText():find("Arathi") or dlg.ebLocation:GetText():find("Alterac")) then
                dlg.ebLocation:SetText(GetZoneText() or "Azeroth")
            end
        end)
        btnBG:SetScript("OnClick", function()
            dlg.selectedContentType = "BG"
            SetChipActive(dlg.BtnWorld, false)
            SetChipActive(dlg.BtnBG, true)
            if dlg.ebLocation and (dlg.ebLocation:GetText() == "" or dlg.ebLocation:GetText() == GetZoneText()) then
                dlg.ebLocation:SetText("Warsong Gulch")
            end
        end)

        -- 3. Location / Zone
        local sec3Title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec3Title:SetPoint("TOPLEFT", 24, -176)
        sec3Title:SetText("|cffffffff3. TARGET LOCATION / ZONE / BATTLEGROUND|r")

        local ebLocation = CreateFrame("EditBox", nil, dlg, "BackdropTemplate")
        ebLocation:SetSize(432, 24)
        ebLocation:SetPoint("TOPLEFT", 24, -196)
        ebLocation:SetAutoFocus(false)
        ebLocation:SetFontObject("GameFontHighlightSmall")
        ebLocation:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        ebLocation:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
        ebLocation:SetBackdropBorderColor(0.3, 0.35, 0.45, 1)
        ebLocation:SetTextInsets(8, 8, 0, 0)
        dlg.ebLocation = ebLocation

        -- 4. Preferred Level Range
        local sec4Title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec4Title:SetPoint("TOPLEFT", 24, -230)
        sec4Title:SetText("|cffffffff4. PREFERRED LEVEL BRACKET (MIN / MAX)|r")

        local ebMinLevel = CreateFrame("EditBox", nil, dlg, "BackdropTemplate")
        ebMinLevel:SetSize(80, 24)
        ebMinLevel:SetPoint("TOPLEFT", 24, -250)
        ebMinLevel:SetAutoFocus(false)
        ebMinLevel:SetNumeric(true)
        ebMinLevel:SetFontObject("GameFontHighlightSmall")
        ebMinLevel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        ebMinLevel:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
        ebMinLevel:SetBackdropBorderColor(0.3, 0.35, 0.45, 1)
        ebMinLevel:SetTextInsets(8, 8, 0, 0)
        dlg.ebMinLevel = ebMinLevel

        local toLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        toLabel:SetPoint("LEFT", ebMinLevel, "RIGHT", 10, 0)
        toLabel:SetText("to")

        local ebMaxLevel = CreateFrame("EditBox", nil, dlg, "BackdropTemplate")
        ebMaxLevel:SetSize(80, 24)
        ebMaxLevel:SetPoint("LEFT", toLabel, "RIGHT", 10, 0)
        ebMaxLevel:SetAutoFocus(false)
        ebMaxLevel:SetNumeric(true)
        ebMaxLevel:SetFontObject("GameFontHighlightSmall")
        ebMaxLevel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        ebMaxLevel:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
        ebMaxLevel:SetBackdropBorderColor(0.3, 0.35, 0.45, 1)
        ebMaxLevel:SetTextInsets(8, 8, 0, 0)
        dlg.ebMaxLevel = ebMaxLevel

        local lvlHint = dlg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        lvlHint:SetPoint("LEFT", ebMaxLevel, "RIGHT", 14, 0)
        lvlHint:SetText("|cff64748b(e.g., 20 to 29 for Twink bracket or 1 to 60)|r")

        -- 5. Requested Roles
        local sec5Title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec5Title:SetPoint("TOPLEFT", 24, -284)
        sec5Title:SetText("|cffffffff5. REQUESTED COMBAT ROLES / SPECS|r")

        local btnTank = UI:CreateButton(dlg, 136, 24, "🛡️ Tank", "GameFontHighlightSmall")
        btnTank:SetPoint("TOPLEFT", 24, -304)
        StyleChip(btnTank, "🛡️ Tank")
        dlg.BtnTank = btnTank

        local btnHeal = UI:CreateButton(dlg, 136, 24, "💚 Healer", "GameFontHighlightSmall")
        btnHeal:SetPoint("LEFT", btnTank, "RIGHT", 12, 0)
        StyleChip(btnHeal, "💚 Healer")
        dlg.BtnHeal = btnHeal

        local btnDPS = UI:CreateButton(dlg, 136, 24, "⚔️ DPS", "GameFontHighlightSmall")
        btnDPS:SetPoint("LEFT", btnHeal, "RIGHT", 12, 0)
        StyleChip(btnDPS, "⚔️ DPS")
        dlg.BtnDPS = btnDPS

        btnTank:SetScript("OnClick", function()
            dlg.selectedRoles.tank = not dlg.selectedRoles.tank
            SetChipActive(dlg.BtnTank, dlg.selectedRoles.tank)
        end)
        btnHeal:SetScript("OnClick", function()
            dlg.selectedRoles.heal = not dlg.selectedRoles.heal
            SetChipActive(dlg.BtnHeal, dlg.selectedRoles.heal)
        end)
        btnDPS:SetScript("OnClick", function()
            dlg.selectedRoles.dps = not dlg.selectedRoles.dps
            SetChipActive(dlg.BtnDPS, dlg.selectedRoles.dps)
        end)

        -- 6. Rally Message / Battle Cry
        local sec6Title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sec6Title:SetPoint("TOPLEFT", 24, -338)
        sec6Title:SetText("|cffffffff6. BATTLE CRY / MISSION DIRECTIVE|r")

        local ebMsg = CreateFrame("EditBox", nil, dlg, "BackdropTemplate")
        ebMsg:SetSize(432, 24)
        ebMsg:SetPoint("TOPLEFT", 24, -358)
        ebMsg:SetAutoFocus(false)
        ebMsg:SetFontObject("GameFontHighlightSmall")
        ebMsg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        ebMsg:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
        ebMsg:SetBackdropBorderColor(0.3, 0.35, 0.45, 1)
        ebMsg:SetTextInsets(8, 8, 0, 0)
        dlg.ebMsg = ebMsg

        -- Bottom Divider
        local bDiv = dlg:CreateTexture(nil, "ARTWORK")
        bDiv:SetHeight(1)
        bDiv:SetPoint("TOPLEFT", 18, -394)
        bDiv:SetPoint("TOPRIGHT", -18, -394)
        dlg.BottomDivider = bDiv

        -- Submit Button
        local submitBtn = UI:CreateButton(dlg, 240, 30, "📯 Muster Vanguard Rally", "GameFontNormal")
        submitBtn:SetPoint("BOTTOMLEFT", 24, 20)
        submitBtn:SetScript("OnClick", function()
            local groupType = dlg.selectedGroupType or "PARTY"
            local contentType = dlg.selectedContentType or "WORLD"
            local locText = dlg.ebLocation:GetText() or GetZoneText() or "Azeroth"
            local minLvl = tonumber(dlg.ebMinLevel:GetText()) or 1
            local maxLvl = tonumber(dlg.ebMaxLevel:GetText()) or 60
            local msgText = dlg.ebMsg:GetText() or "Muster Vanguard Strike Team!"
            local roles = {
                tank = dlg.selectedRoles.tank,
                heal = dlg.selectedRoles.heal,
                dps = dlg.selectedRoles.dps,
            }

            if KB.Reinforcements and KB.Reinforcements.CreateCustomRally then
                KB.Reinforcements:CreateCustomRally({
                    groupType = groupType,
                    contentType = contentType,
                    zone = locText,
                    minLevel = minLvl,
                    maxLevel = maxLvl,
                    roles = roles,
                    message = msgText,
                })
            end

            dlg:Hide()
            UI:Refresh()
        end)
        dlg.SubmitBtn = submitBtn

        local cancelBtn = UI:CreateButton(dlg, 120, 30, "Cancel", "GameFontHighlight")
        cancelBtn:SetPoint("BOTTOMRIGHT", -24, 20)
        cancelBtn:SetScript("OnClick", function()
            dlg:Hide()
        end)
        dlg.CancelBtn = cancelBtn

        dlg.SetChipActive = SetChipActive
        UI.RallyDialog = dlg
    end

    -- Update active theme and reset fields to sensible defaults
    local theme = UI:GetTheme()
    UI.RallyDialog:SetBackdrop(theme.modalBackdrop or {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    UI.RallyDialog:SetBackdropColor(unpack(theme.modalBg or { 0.035, 0.045, 0.07, 1.0 }))
    UI.RallyDialog:SetBackdropBorderColor(unpack(theme.modalBorder or { 0.45, 0.35, 0.18, 0.95 }))
    if UI.RallyDialog.Divider and theme.dividerColor then
        UI.RallyDialog.Divider:SetColorTexture(unpack(theme.dividerColor))
    end
    if UI.RallyDialog.BottomDivider and theme.dividerColor then
        UI.RallyDialog.BottomDivider:SetColorTexture(unpack(theme.dividerColor))
    end

    -- Pre-populate defaults
    local pLevel = UnitLevel("player") or 20
    local pZone = GetZoneText() or "Azeroth"
    UI.RallyDialog.selectedGroupType = "PARTY"
    UI.RallyDialog.selectedContentType = "WORLD"
    UI.RallyDialog.selectedRoles = { tank = true, heal = true, dps = true }

    UI.RallyDialog.SetChipActive(UI.RallyDialog.BtnParty, true)
    UI.RallyDialog.SetChipActive(UI.RallyDialog.BtnRaid, false)
    UI.RallyDialog.SetChipActive(UI.RallyDialog.BtnWorld, true)
    UI.RallyDialog.SetChipActive(UI.RallyDialog.BtnBG, false)
    UI.RallyDialog.SetChipActive(UI.RallyDialog.BtnTank, true)
    UI.RallyDialog.SetChipActive(UI.RallyDialog.BtnHeal, true)
    UI.RallyDialog.SetChipActive(UI.RallyDialog.BtnDPS, true)

    UI.RallyDialog.ebLocation:SetText(pZone)
    local minL = math.max(1, pLevel - 5)
    local maxL = math.min(60, pLevel + 5)
    UI.RallyDialog.ebMinLevel:SetNumber(minL)
    UI.RallyDialog.ebMaxLevel:SetNumber(maxL)
    UI.RallyDialog.ebMsg:SetText(string.format("Muster Vanguard in %s! Whisper 'rally' to join.", pZone))

    UI.RallyDialog:Show()
    if UI.RallyDialog.Raise then UI.RallyDialog:Raise() end
end

--------------------------------------------------------------------------------
-- Tactical Combat Wire (Floating, Moveable Live Combat Pop-Out Window)
--------------------------------------------------------------------------------
local combatWireHUD = nil

function UI:InitializeCombatWire()
    if combatWireHUD or InCombatLockdown() then return end

    local hud = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    hud:SetSize(440, 180)
    hud:SetFrameStrata("MEDIUM")
    hud:SetClampedToScreen(true)
    hud:SetMovable(true)
    hud:EnableMouse(true)
    hud:RegisterForDrag("LeftButton")

    -- Restore saved position or default to TOPLEFT, 24, -180
    local pos = WoWKillboardSettings and WoWKillboardSettings.combatWirePos
    if pos and pos.point and pos.relPoint and pos.x and pos.y then
        hud:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        hud:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -180)
    end

    hud:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    hud:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        WoWKillboardSettings = WoWKillboardSettings or {}
        WoWKillboardSettings.combatWirePos = { point = p, relPoint = rp, x = math.floor(x), y = math.floor(y) }
    end)

    -- Sleek dark tactical gunmetal backdrop
    hud:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    hud:SetBackdropColor(0.03, 0.04, 0.05, 0.94)
    hud:SetBackdropBorderColor(0.0, 0.85, 1.0, 0.75)

    -- Header Drag Bar
    local header = CreateFrame("Frame", nil, hud, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(22)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    header:SetBackdropColor(0.06, 0.09, 0.14, 0.98)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() if not InCombatLockdown() then hud:StartMoving() end end)
    header:SetScript("OnDragStop", function()
        hud:StopMovingOrSizing()
        local p, _, rp, x, y = hud:GetPoint()
        WoWKillboardSettings = WoWKillboardSettings or {}
        WoWKillboardSettings.combatWirePos = { point = p, relPoint = rp, x = math.floor(x), y = math.floor(y) }
    end)
    hud.header = header

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("LEFT", 8, 0)
    title:SetText("|cff00e5ffKB COMBAT WIRE|r  |cff64748b(Pop-Out Live Feed)|r")

    -- Close Button [X]
    local close = CreateFrame("Button", nil, header)
    close:SetSize(18, 18)
    close:SetPoint("RIGHT", -3, 0)
    local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    closeText:SetPoint("CENTER", 0, 0)
    closeText:SetText("|cffff4444X|r")
    close:SetScript("OnClick", function()
        hud:Hide()
        WoWKillboardSettings = WoWKillboardSettings or {}
        WoWKillboardSettings.showCombatWire = false
        SafePrint("|cff00ccff[WoWKB]|r Combat Wire hidden. Click |cffffd100[Wire]|r in header or type |cffffff00/kb wire|r to restore.")
    end)

    -- Clear Button [Clear]
    local clearBtn = CreateFrame("Button", nil, header)
    clearBtn:SetSize(42, 18)
    clearBtn:SetPoint("RIGHT", close, "LEFT", -4, 0)
    local clearText = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clearText:SetPoint("CENTER", 0, 0)
    clearText:SetText("|cff94a3b8Clear|r")
    clearBtn:SetScript("OnClick", function()
        if hud.msgFrame and hud.msgFrame.Clear then
            hud.msgFrame:Clear()
            hud.msgFrame:AddMessage("|cff64748b[Combat Wire cleared — listening for live combat records...]|r")
        end
    end)

    -- Scrolling Combat Message Frame
    local msgFrame = CreateFrame("ScrollingMessageFrame", nil, hud)
    msgFrame:SetPoint("TOPLEFT", 8, -26)
    msgFrame:SetPoint("BOTTOMRIGHT", -8, 8)
    msgFrame:SetFontObject("GameFontHighlightSmall")
    msgFrame:SetJustifyH("LEFT")
    msgFrame:SetMaxLines(100)
    msgFrame:SetFading(false)
    msgFrame:EnableMouseWheel(true)
    msgFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            self:ScrollUp()
        else
            self:ScrollDown()
        end
    end)

    msgFrame:AddMessage("|cff00e5ff[WoWKB Wire Initialized]|r |cff64748bCombat events stream here. Chat is clean.|r")

    hud.msgFrame = msgFrame
    combatWireHUD = hud
    UI.CombatWireHUD = hud

    -- Honor saved show setting
    local s = WoWKillboardSettings or KB.DefaultSettings
    if s and s.showCombatWire == false then
        hud:Hide()
    else
        hud:Show()
    end
end

function UI:AddCombatWireEntry(killmail, chatMsg)
    local s = WoWKillboardSettings or KB.DefaultSettings
    local feedMode = (s and s.combatFeedMode) or "POPOUT"
    if feedMode == "OFF" then return end

    local tStr = date("%H:%M:%S", (killmail and killmail.timestamp) or time())
    local line = string.format("|cff64748b[%s]|r %s", tStr, chatMsg or "")

    if InCombatLockdown() then
        UI.PendingWireEntries = UI.PendingWireEntries or {}
        table.insert(UI.PendingWireEntries, line)
        return
    end

    if not combatWireHUD then
        UI:InitializeCombatWire()
    end
    if not combatWireHUD then return end

    if combatWireHUD.msgFrame then
        combatWireHUD.msgFrame:AddMessage(line)
    end

    if (not s or s.showCombatWire ~= false) and not combatWireHUD:IsShown() then
        combatWireHUD:Show()
    end
end

function UI:ToggleCombatWire()
    if InCombatLockdown() then
        SafePrint("|cffff9900[WoWKB]|r Cannot toggle Combat Wire during combat.")
        return
    end
    if not combatWireHUD then UI:InitializeCombatWire() end
    if not combatWireHUD then return end

    WoWKillboardSettings = WoWKillboardSettings or {}
    if combatWireHUD:IsShown() then
        combatWireHUD:Hide()
        WoWKillboardSettings.showCombatWire = false
        SafePrint("|cff00ccff[WoWKB]|r Combat Wire: |cffff4444Hidden|r.")
    else
        combatWireHUD:Show()
        WoWKillboardSettings.showCombatWire = true
        SafePrint("|cff00ccff[WoWKB]|r Combat Wire: |cff00ff00Shown|r (Click & drag header to reposition).")
    end
end


