# Bounty Escrow & Oathbreaker Debt Ledger

## 1. The Bounty Ecosystem

The WoW Killboard bounty system brings real player-driven economic assassination contracts to Azeroth, complete with anti-fraud safeguards and automated debt enforcement.

```mermaid
stateDiagram-v2
    [*] --> ActiveBounty: Player places bounty (/kb bounty <Target> <Gold>)
    ActiveBounty --> Fulfilled: Target killed by certified hunter
    ActiveBounty --> Defaulted: Poster fails to pay escrow within grace period
    Defaulted --> Oathbreaker: Poster permanently branded on Wall of Shame
    Oathbreaker --> Redeemed: Debtor repays principal + 10% penalty
    Redeemed --> [*]
    Fulfilled --> [*]
```

---

## 2. Anti-Win-Trade & Anti-Exploit Rules

To prevent players from laundering gold or colluding with friends to collect fake bounties, [`BountyEngine.lua`](file:///c:/Users/SQUICK/WoW_Killboard/Addon/WoWKillboard/BountyEngine.lua) enforces strict validation heuristics:

1. **Self-Bounty Prohibition**: A player cannot place a bounty on themselves or members of their own active party/raid.
2. **Guild Collusion Filter**: Kills where the killer and victim share the same guild are disqualified from bounty payouts.
3. **Level Disparity Ceiling**:
   - Victims must be within an honorable level threshold of the hunter ($\Delta \text{Level} \le 7$ or grey level threshold).
   - Low-level "grief farming" for bounties is blocked.
4. **Duplicate Kill Cooldown**:
   - Multiple kills of the same victim by the same hunter within a 1-hour window yield no additional bounty payout.
5. **Liquid Gold Verification**:
   - Placing a bounty checks local player funds (`GetMoney()`) before broadcasting the contract.

---

## 3. The Oathbreaker Debt State Machine & "Wall of Shame"

When a player promises a bounty payout or participates in an escrow contract that goes unfulfilled, their record transitions to default:

### State Transitions
1. **Active Default**: The contract enters default status. The poster is designated an **Oathbreaker**.
2. **P2P & Web Propagation**:
   - Addon broadcasts the debt status across party, raid, and guild channels using `Sync.lua`.
   - The desktop watcher pushes the debt record to the web platform's **Wall of Shame** ledger.
3. **Public Stigmatization**:
   - The debtor's name, defaulted gold amount, and timestamp are displayed on the public web ledger and in-game Bounties tab.

---

## 4. Proximity Wanted Debtor Radar

The addon maintains an active proximity radar hooked into nameplate creation and mouseover events:

```mermaid
flowchart LR
    NAMEPLATE["Nameplate / Mouseover Detected\n(UnitScanner.lua)"] --> CHECK{"Is Unit in\nWoWKillboardDebtLedger?"}
    CHECK -- Yes --> ALARM["Trigger Wanted Radar!\n- Play Sound Siren (SoundKit 8959)\n- Flash Red Banner on Screen\n- Announce to Party/Raid"]
    CHECK -- No --> PASS["Ignore Unit"]
```

### In-Game Alarm Execution
- **Visual Alert**: Flashes a high-visibility warning banner:
  ```text
  [!] WANTED OATHBREAKER DETECTED: <PlayerName> [Debt: 500g] [!]
  ```
- **Auditory Alert**: Triggers a distinctive raid siren sound kit (`PlaySound(8959)`).

---

## 5. Redemption & Debt Clearance Workflow

Debtors can clear their name and restore their reputation via the in-game Redemption Portal:

1. **Administrative Surcharge**: Repaying a defaulted debt requires paying the principal plus a **10% administrative fee** (e.g., a 500g default costs 550g to redeem).
2. **Automated Postal Payment**:
   - When the debtor targets a mailbox, the addon auto-fills a C.O.D. or gold-attached payment letter addressed to the creditor.
3. **Receipt Generation**:
   - Once mailed, the local debt record is updated to `PAID`.
   - P2P sync broadcasts the clearance across the network.
   - The web platform moves the record from the active Wall of Shame to the Historical Redemption Archive.

---

## 6. Bounty Hall of Fame & Supporter Subzone Recon

### 4-Card Bounty Records Grid
The platform automatically aggregates real-time bounty metrics into four distinct Hall of Fame leaderboards (`GET /api/bounties/leaderboards`):
1. **🎯 Top Bounty Hunters**: Ranked by total contracts successfully claimed and total gold bounty rewards earned.
2. **💰 Highest Bounty Contracts**: Ranked by highest escrowed reward amounts.
3. **⏳ Most Elusive Outlaws**: Ranked by survival duration under active bounty contracts without falling.
4. **⚡ Fastest Collected Manhunts**: Record execution times measuring the interval from contract creation to confirmed target slaying.

### Vicinity Recon & Tiered Supporter Access
To guarantee fair play and prevent stream-sniping or targeted harassment:
- **Public / Free Tier**: Displays confirmed combat **Zone** only (e.g. `Last Sighted: Stranglethorn Vale ~14m ago`).
- **Supporter Perk**: Unlocks exact **Subzone** intelligence (e.g. `Booty Bay`) as a quality-of-life benefit for supporters of **Forged By Valor (501(c)(3))**.
- **100% Ad-Free Experience**: The platform contains zero third-party commercial advertisements, operating entirely through community and non-profit veteran support.

