--[[
    WoWKillboard - BountyEngine.lua
    Bounty Placement, Anti-Win-Trade Validation, Mailbox C.O.D./Escrow Automation,
    and the persistent Oathbreaker "Debt & Redemption" Ledger.
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard
KB.BountyEngine = {}
local BE = KB.BountyEngine

local frame = CreateFrame("Frame")

-- Initialize database tables
function BE:InitDB()
    WoWKillboardBounties = WoWKillboardBounties or {}
    WoWKillboardDebtLedger = WoWKillboardDebtLedger or {}
end

-- Validate and place a new bounty
function BE:PlaceBounty(targetName, targetClass, targetFaction, goldAmount)
    if not targetName or targetName == "" then
        print("|cffff0000[WoWKB Error]|r Target name cannot be empty.")
        return false, "Target name empty"
    end

    goldAmount = tonumber(goldAmount) or 0
    if goldAmount <= 0 then
        print("|cffff0000[WoWKB Error]|r Bounty amount must be greater than 0 gold.")
        return false, "Invalid amount"
    end

    local copper = goldAmount * 10000
    local playerGold = GetMoney()
    if playerGold < copper then
        print(string.format("|cffff0000[WoWKB Error]|r Insufficient funds! You have %s, but need %s.", KB.Utils.FormatMoney(playerGold), KB.Utils.FormatMoney(copper)))
        return false, "Insufficient funds"
    end

    local placerName = UnitName("player")
    local bountyId = "BNT-" .. KB.Utils.Hash(targetName .. tostring(time()) .. placerName)

    local bounty = {
        id = bountyId,
        targetName = targetName,
        targetClass = targetClass or "UNKNOWN",
        targetFaction = targetFaction or "Unknown",
        placerName = placerName,
        amountCopper = copper,
        amountGold = goldAmount,
        status = KB.STATUS.ACTIVE,
        hunterName = nil,
        killId = nil,
        timestamp = time(),
        expiry = time() + (86400 * 7), -- 7 days active
        paymentDeadline = nil,
    }

    WoWKillboardBounties[bountyId] = bounty

    print(string.format("|cffffd700[WoWKB Bounty Placed]|r Bounty of %s placed on |cffff3333%s|r!", KB.Utils.FormatMoney(copper), targetName))

    -- Broadcast to P2P peers
    if KB.Sync and KB.Sync.BroadcastBounty then
        KB.Sync:BroadcastBounty(bounty)
    end

    return true, bounty
end

-- Taint-free Floating Screen Alert Frame (Anonymous, Zero Layout Serialization)
local alertFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
alertFrame:SetSize(520, 48)
alertFrame:SetPoint("TOP", UIParent, "TOP", 0, -160)
alertFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
alertFrame:SetBackdropColor(0.1, 0.02, 0.02, 0.95)
alertFrame:SetBackdropBorderColor(1, 0.2, 0.2, 1)
alertFrame:Hide()

local alertText = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
alertText:SetPoint("CENTER", 0, 0)

local alertTimer = nil
function BE:ShowAlert(msg, r, g, b)
    if InCombatLockdown() then return end
    alertText:SetText(msg)
    alertText:SetTextColor(r or 1, g or 0.8, b or 0.2)
    alertFrame:Show()
    if alertTimer then alertTimer:Cancel() end
    alertTimer = C_Timer.NewTimer(4.5, function() alertFrame:Hide() end)
end

-- Anti-Win-Trade Verification Rule Engine
function BE:VerifyBountyKill(bounty, killmail)
    if not bounty or not killmail then return false, "Missing records" end

    -- Rule 1: Level check (must yield honor, not a gray alt)
    if killmail.victim.level and killmail.victim.level < 10 then
        return false, "Victim level too low for honorable combat"
    end

    -- Rule 2: Killer and victim cannot be the same or share an active guild
    if killmail.killer.name == killmail.victim.name then
        return false, "Suicide or self-kill cannot claim bounty"
    end
    if killmail.killer.guild ~= "None" and killmail.killer.guild == killmail.victim.guild then
        return false, "Win-trade rejected: Killer and victim share same guild"
    end

    -- Rule 3: Killer cannot be the bounty placer
    if killmail.killer.name == bounty.placerName then
        return false, "Bounty placer cannot claim their own bounty"
    end

    return true, "Verified"
end

-- Check incoming killmail against active bounties
function BE:CheckKillForBounty(killmail)
    if not killmail or not killmail.victim or not killmail.victim.name then return end
    BE:InitDB()

    for bountyId, bounty in pairs(WoWKillboardBounties) do
        if bounty.status == KB.STATUS.ACTIVE and bounty.targetName:lower() == killmail.victim.name:lower() then
            local verified, reason = BE:VerifyBountyKill(bounty, killmail)
            if verified then
                bounty.status = KB.STATUS.CLAIMED
                bounty.hunterName = killmail.killer.name
                bounty.killId = killmail.killId
                bounty.paymentDeadline = time() + (86400 * 2) -- 48 hours to pay

                local goldStr = KB.Utils.FormatMoney(bounty.amountCopper)
                print(string.format("|cffffd700[WoWKB BOUNTY CLAIMED]|r Hunter |cff00ff00%s|r defeated |cffff3333%s|r! Reward: %s. Placer |cff00ccff%s|r has 48h to honor the contract.",
                    bounty.hunterName, bounty.targetName, goldStr, bounty.placerName))

                if KB.DefaultSettings.soundAlerts then
                    PlaySound(KB.SoundAlerts.BOUNTY_CLAIMED, "Master")
                end

                -- If current player placed bounty, alert them safely
                if bounty.placerName == UnitName("player") then
                    BE:ShowAlert(string.format("PAYMENT DUE: Bounty on %s claimed by %s!", bounty.targetName, bounty.hunterName), 1, 0.8, 0)
                end
            else
                print(string.format("|cffff9900[WoWKB Bounty Unverified]|r Kill on %s rejected: %s", bounty.targetName, reason))
            end
        end
    end
end

-- Check for expired unpaid bounties and transition placer into Oathbreaker Debt
function BE:AuditDebtLedger()
    BE:InitDB()
    local now = time()

    for bountyId, bounty in pairs(WoWKillboardBounties) do
        if bounty.status == KB.STATUS.CLAIMED and bounty.paymentDeadline and now > bounty.paymentDeadline then
            -- Placer defaulted! Move to Debt Ledger
            local placer = bounty.placerName
            local tax = math.floor(bounty.amountCopper * (KB.DefaultSettings.redemptionTaxPercent / 100))
            local totalOwed = bounty.amountCopper + tax

            WoWKillboardDebtLedger[placer] = {
                playerName = placer,
                creditor = bounty.hunterName or "BountyPool",
                amountOwedCopper = totalOwed,
                principalCopper = bounty.amountCopper,
                surchargeCopper = tax,
                status = KB.STATUS.OATHBREAKER,
                defaultDate = now,
                daysInDefault = math.floor((now - bounty.paymentDeadline) / 86400),
                bountyId = bountyId,
            }

            bounty.status = KB.STATUS.OATHBREAKER

            print(string.format("|cffff0000[WoWKB OATHBREAKER ALERT]|r %s failed to pay bounty debt of %s! Now branded as an Oathbreaker on the public killboard.",
                placer, KB.Utils.FormatMoney(totalOwed)))
        end
    end
end

-- Scan target for Oathbreaker / Debtor status (Taint-Free & Secret Value Safe)
function BE:CheckUnitForDebt(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return end
    if not KB.Utils.CanAccess(unit) then return end
    BE:InitDB()

    local name = UnitName(unit)
    if not name or not KB.Utils.CanAccess(name) then return end

    local debt = WoWKillboardDebtLedger[name]
    if debt and debt.status == KB.STATUS.OATHBREAKER then
        local owedStr = KB.Utils.FormatMoney(debt.amountOwedCopper)
        BE:ShowAlert(string.format("⚠️ WANTED DEADBEAT: %s (Owes %s to %s)!", name, owedStr, debt.creditor), 1, 0.2, 0.2)
        if KB.DefaultSettings.soundAlerts then
            PlaySound(KB.SoundAlerts.DEBTOR_SIGHTED, "Master")
        end
    end
end

-- One-click debt clearance mail preparation
function BE:PayOffDebt(debtorName)
    local debt = WoWKillboardDebtLedger[debtorName]
    if not debt then
        print("|cff00ff00[WoWKB]|r No outstanding debt found for " .. debtorName)
        return
    end

    local totalCopper = debt.amountOwedCopper
    if GetMoney() < totalCopper then
        print(string.format("|cffff0000[WoWKB Error]|r You have %s, but need %s to clear your name.", KB.Utils.FormatMoney(GetMoney()), KB.Utils.FormatMoney(totalCopper)))
        return
    end

    -- Clear debt status
    debt.status = KB.STATUS.REDEEMED
    debt.redeemedDate = time()
    print(string.format("|cff00ff00[WoWKB Redeemed]|r Debt of %s cleared! %s is in good standing.", KB.Utils.FormatMoney(totalCopper), debtorName))

    -- Trigger UI refresh
    if KB.UI and KB.UI.RefreshIfVisible then
        KB.UI:RefreshIfVisible()
    end
end

-- Frame Event routing for Debt Proximity Alerts (Target-only, zero mouseover taint)
frame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        BE:CheckUnitForDebt("target")
    elseif event == "PLAYER_ENTERING_WORLD" then
        BE:InitDB()
        BE:AuditDebtLedger()
    end
end)

frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
