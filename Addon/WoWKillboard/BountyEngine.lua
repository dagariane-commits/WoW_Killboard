--[[
    WoWKillboard - BountyEngine.lua
    Bounty Placement, Anti-Win-Trade Validation, Mailbox C.O.D./Escrow Automation,
    and the persistent Oathbreaker "Debt & Redemption" Ledger.
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard
KB.BountyEngine = {}
local BE = KB.BountyEngine

local SafePrint = function(...)
    if KB.Utils and KB.Utils.SafePrint then
        KB.Utils.SafePrint(...)
    elseif not InCombatLockdown() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        local pieces = {}
        for i = 1, select("#", ...) do table.insert(pieces, tostring(select(i, ...))) end
        DEFAULT_CHAT_FRAME:AddMessage(table.concat(pieces, " "))
    end
end

local frame = CreateFrame("Frame")

-- Initialize database tables
function BE:InitDB()
    WoWKillboardBounties = WoWKillboardBounties or {}
    WoWKillboardDebtLedger = WoWKillboardDebtLedger or {}
    WoWKillboardAcceptedBounties = WoWKillboardAcceptedBounties or {}
end

-- Validate and place a new Mark of Spite (with permanent Character GUID binding)
function BE:PlaceBounty(targetName, targetClass, targetFaction, amountInput, targetGUID, isCopper)
    -- Guard: Open World PvP only!
    if IsInInstance then
        local inInstance, instanceType = IsInInstance()
        if inInstance or (instanceType and instanceType ~= "none") then
            SafePrint("|cffff0000[WoWKB Error]|r Marks of Spite can only be declared upon the open battlefields of Azeroth (Open World PvP only).")
            return false, "Instances prohibited"
        end
    end

    if not targetName or targetName == "" then
        SafePrint("|cffff0000[WoWKB Error]|r Target name cannot be empty.")
        return false, "Target name empty"
    end

    local copper = 0
    local goldAmount = 0
    if isCopper then
        copper = math.floor(tonumber(amountInput) or 0)
        goldAmount = math.floor(copper / 10000)
    else
        goldAmount = tonumber(amountInput) or 0
        copper = math.floor(goldAmount * 10000)
    end

    if copper <= 0 then
        SafePrint("|cffff0000[WoWKB Error]|r Mark amount must be greater than 0.")
        return false, "Invalid amount"
    end

    local playerGold = GetMoney()
    if playerGold < copper then
        SafePrint(string.format("|cffff0000[WoWKB Error]|r Insufficient funds! You have %s, but need %s.", KB.Utils.FormatMoney(playerGold), KB.Utils.FormatMoney(copper)))
        return false, "Insufficient funds"
    end

    local placerName = UnitName("player")
    local bountyId = "BNT-" .. KB.Utils.Hash(targetName .. tostring(time()) .. placerName)

    local bounty = {
        id = bountyId,
        targetName = targetName,
        targetGUID = targetGUID or "UNKNOWN",
        targetClass = targetClass or "UNKNOWN",
        targetFaction = targetFaction or "Unknown",
        placerName = placerName,
        amountCopper = copper,
        amountGold = goldAmount,
        status = KB.STATUS.ACTIVE,
        hunterName = nil,
        killId = nil,
        timestamp = time(),
        expiry = time() + (86400 * 30), -- 30 days active before Cold Case archive
        paymentDeadline = nil,
        aliasHistory = {},
    }

    BE:InitDB()
    WoWKillboardBounties[bountyId] = bounty

    SafePrint(string.format("|cffffd700[WoWKB Mark Declared]|r Mark of Spite of %s declared on |cffff3333%s|r!", KB.Utils.FormatMoney(copper), targetName))

    -- Broadcast to P2P peers
    if KB.Sync and KB.Sync.BroadcastBounty then
        KB.Sync:BroadcastBounty(bounty)
    end

    return true, bounty
end

-- Hunter Bounty Contract Acceptance (Opt-In Requirement)
function BE:AcceptBounty(bountyId)
    BE:InitDB()
    if not WoWKillboardBounties or not WoWKillboardBounties[bountyId] then return false end
    WoWKillboardAcceptedBounties[bountyId] = time()
    local b = WoWKillboardBounties[bountyId]
    SafePrint(string.format("|cff00ff00[WoWKB Contract Accepted]|r Tracking Mark of Spite on |cffff3333%s|r! Deliver the final killing blow to claim %s.",
        b.targetName, KB.Utils.FormatMoney(b.amountCopper)))
    if KB.UI and KB.UI.RefreshIfVisible then KB.UI:RefreshIfVisible() end
    return true
end

function BE:IsBountyAccepted(bountyId)
    BE:InitDB()
    return WoWKillboardAcceptedBounties and (WoWKillboardAcceptedBounties[bountyId] ~= nil)
end

-- Taint-free Floating Screen Alert Frame (Lazy instantiation on demand)
local alertFrame = nil
local alertText = nil
local alertTimer = nil

local function EnsureAlertFrame()
    if alertFrame or InCombatLockdown() then return end
    alertFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
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

    alertText = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    alertText:SetPoint("CENTER", 0, 0)
end

function BE:ShowAlert(msg, r, g, b)
    if InCombatLockdown() then return end
    EnsureAlertFrame()
    if not alertFrame then return end
    alertText:SetText(msg)
    alertText:SetTextColor(r or 1, g or 0.8, b or 0.2)
    alertFrame:SetAlpha(1.0)
    alertFrame:Show()
    if alertTimer then alertTimer:Cancel() end
    alertTimer = C_Timer.NewTimer(4.5, function()
        if alertFrame then
            if InCombatLockdown() then
                alertFrame:SetAlpha(0)
                if KB.UI then
                    KB.UI.PendingHides = KB.UI.PendingHides or {}
                    table.insert(KB.UI.PendingHides, alertFrame)
                end
            else
                alertFrame:Hide()
            end
        end
    end)
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
        -- Check if target matches name OR permanent character GUID (Anti-Name Change Evasion)
        local targetMatches = (bounty.targetName:lower() == killmail.victim.name:lower())
        if not targetMatches and bounty.targetGUID and killmail.victim.guid and bounty.targetGUID ~= "UNKNOWN" and bounty.targetGUID == killmail.victim.guid then
            targetMatches = true
            bounty.aliasHistory = bounty.aliasHistory or {}
            table.insert(bounty.aliasHistory, bounty.targetName)
            SafePrint(string.format("|cffff9900[WoWKB Retribution Tracked]|r Outlaw %s renamed to %s! Blood contract locked to permanent character GUID.",
                bounty.targetName, killmail.victim.name))
            bounty.targetName = killmail.victim.name
        end

        if bounty.status == KB.STATUS.ACTIVE and targetMatches then
            -- Killing Blow Eligibility: Hunter must have accepted the contract
            local isPlayerKiller = (killmail.killer.name == UnitName("player"))
            if isPlayerKiller and not BE:IsBountyAccepted(bountyId) then
                SafePrint(string.format("|cffff9900[WoWKB Blood Debt Unclaimed]|r Slain enemy %s had an active execution contract of %s, but you had not accepted the contract!",
                    bounty.targetName, KB.Utils.FormatMoney(bounty.amountCopper)))
            else
                local verified, reason = BE:VerifyBountyKill(bounty, killmail)
                if verified then
                    bounty.status = KB.STATUS.CLAIMED
                    bounty.hunterName = killmail.killer.name
                    bounty.killId = killmail.killId
                    bounty.paymentDeadline = time() + (86400 * 2) -- 48 hours to pay

                    local goldStr = KB.Utils.FormatMoney(bounty.amountCopper)
                    SafePrint(string.format("|cffffd700[WoWKB CONTRACT EXECUTED]|r Vanguard Hunter |cff00ff00%s|r executed |cffff3333%s|r! Reward: %s. Contractor |cff00ccff%s|r has 48h to honor the blood debt.",
                        bounty.hunterName, bounty.targetName, goldStr, bounty.placerName))

                    local s = WoWKillboardSettings or KB.DefaultSettings
                    if (s.alertMode == "SOUND_AND_BANNER" or (s.alertMode ~= "BANNER_ONLY" and s.alertMode ~= "OFF" and s.soundAlerts ~= false)) then
                        PlaySound(KB.SoundAlerts.BOUNTY_CLAIMED, "Master")
                    end

                    -- If current player placed bounty, alert them safely
                    if bounty.placerName == UnitName("player") then
                        BE:ShowAlert(string.format("BLOOD DEBT DUE: Contract on %s executed by %s!", bounty.targetName, bounty.hunterName), 1, 0.8, 0)
                    end
                else
                    SafePrint(string.format("|cffff9900[WoWKB Bounty Unverified]|r Kill on %s rejected: %s", bounty.targetName, reason))
                end
            end
        end
    end
end

-- Check for expired unpaid bounties and transition placer into Oathbreaker Debt
function BE:AuditDebtLedger()
    BE:InitDB()
    local now = time()

    -- Audit for 30-day uncollected bounties (Move to Cold Case Archive)
    for bountyId, bounty in pairs(WoWKillboardBounties) do
        if bounty.status == KB.STATUS.ACTIVE and (now - (bounty.timestamp or now)) > (86400 * 30) then
            bounty.status = "COLD_CASE"
            bounty.archivedAt = now
        end
    end

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

            SafePrint(string.format("|cffff0000[WoWKB THE MARKED ALERT]|r %s defaulted on blood debt of %s! Now condemned to The Marked on the realm killboard.",
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
        BE:ShowAlert(string.format("[!] CONDEMNED TRAITOR SIGHTED: %s (Owes %s to %s)!", name, owedStr, debt.creditor), 1, 0.2, 0.2)
        local s = WoWKillboardSettings or KB.DefaultSettings
        if (s.alertMode == "SOUND_AND_BANNER" or (s.alertMode ~= "BANNER_ONLY" and s.alertMode ~= "OFF" and s.soundAlerts ~= false)) then
            PlaySound(KB.SoundAlerts.DEBTOR_SIGHTED, "Master")
        end
    end
end

-- One-click debt clearance mail preparation
function BE:PayOffDebt(debtorName)
    local debt = WoWKillboardDebtLedger[debtorName]
    if not debt then
        SafePrint("|cff00ff00[WoWKB]|r No outstanding debt found for " .. debtorName)
        return
    end

    local totalCopper = debt.amountOwedCopper
    if GetMoney() < totalCopper then
        SafePrint(string.format("|cffff0000[WoWKB Error]|r You have %s, but need %s to clear your name.", KB.Utils.FormatMoney(GetMoney()), KB.Utils.FormatMoney(totalCopper)))
        return
    end

    -- Clear debt status
    debt.status = KB.STATUS.REDEEMED
    debt.redeemedDate = time()
    SafePrint(string.format("|cff00ff00[WoWKB Redeemed]|r Debt of %s cleared! %s is in good standing.", KB.Utils.FormatMoney(totalCopper), debtorName))

    -- Trigger UI refresh
    if KB.UI and KB.UI.RefreshIfVisible then
        KB.UI:RefreshIfVisible()
    end
end

-- Get Marks of Spite Records (Hall of Fame)
function BE:GetBountyRecords()
    BE:InitDB()
    local topHunters = {}
    local highestRewards = {}
    local longestSurviving = {}

    -- Hunter tallies from claimed bounties
    local hunterCounts = {}
    for _, b in pairs(WoWKillboardBounties) do
        if b.status == KB.STATUS.CLAIMED and b.hunterName then
            hunterCounts[b.hunterName] = (hunterCounts[b.hunterName] or 0) + 1
        end
    end
    for hName, count in pairs(hunterCounts) do
        table.insert(topHunters, { name = hName, count = count })
    end
    table.sort(topHunters, function(a, b) return a.count > b.count end)

    -- Highest Rewards
    for _, b in pairs(WoWKillboardBounties) do
        table.insert(highestRewards, b)
    end
    table.sort(highestRewards, function(a, b) return (a.amountCopper or 0) > (b.amountCopper or 0) end)

    -- Longest Surviving Active Outlaws
    local now = time()
    for _, b in pairs(WoWKillboardBounties) do
        if b.status == KB.STATUS.ACTIVE then
            local age = now - (b.timestamp or now)
            table.insert(longestSurviving, { target = b.targetName, class = b.targetClass, days = math.max(1, math.floor(age / 86400)), copper = b.amountCopper })
        end
    end
    table.sort(longestSurviving, function(a, b) return a.days > b.days end)

    return {
        topHunters = topHunters,
        highestRewards = highestRewards,
        longestSurviving = longestSurviving,
    }
end

-- Get Personal Marks (Issued by player, or active on player's head)
function BE:GetPersonalMarks()
    BE:InitDB()
    local playerName = UnitName("player")
    local issuedCount = 0
    local onHeadCount = 0
    for _, b in pairs(WoWKillboardBounties) do
        if b.status == KB.STATUS.ACTIVE then
            if b.placerName == playerName then
                issuedCount = issuedCount + 1
            end
            if b.targetName == playerName then
                onHeadCount = onHeadCount + 1
            end
        end
    end
    return { issued = issuedCount, onHead = onHeadCount }
end

-- Frame Event routing for Debt Proximity Alerts (Target-only, zero mouseover taint)
frame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        if not InCombatLockdown() then
            BE:CheckUnitForDebt("target")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        BE:InitDB()
        BE:AuditDebtLedger()
    end
end)

frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
