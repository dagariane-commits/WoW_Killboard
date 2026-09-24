/*
   WoWKillboard - web/static/app.js
   Frontend controller for live kill feeds, leaderboards, BG telemetry, and bounties.
*/

const CLASS_COLORS = {
  WARRIOR: "#c79c6e",
  PALADIN: "#f58cba",
  HUNTER: "#abd473",
  ROGUE: "#fff569",
  PRIEST: "#ffffff",
  DEATHKNIGHT: "#c41f3b",
  SHAMAN: "#0070de",
  MAGE: "#40c7eb",
  WARLOCK: "#8787ed",
  MONK: "#00ff96",
  DRUID: "#ff7d0a",
  DEMONHUNTER: "#a330c9",
  EVOKER: "#33937f",
  UNKNOWN: "#94a3b8"
};

let currentTab = "FEED";
let currentMode = "ALL";
let searchQuery = "";
let cachedKills = [];

function formatNumber(num) {
  num = Number(num) || 0;
  if (num >= 1000000) return (num / 1000000).toFixed(2) + "M";
  if (num >= 1000) return (num / 1000).toFixed(1) + "k";
  return Math.floor(num).toString();
}

function formatCopper(copper) {
  copper = Number(copper) || 0;
  const g = Math.floor(copper / 10000);
  const s = Math.floor((copper % 10000) / 100);
  if (g > 0) return `${g}g ${s}s`;
  return `${s}s`;
}

function timeAgo(epoch) {
  const diff = Math.max(0, Math.floor(Date.now() / 1000) - Number(epoch));
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

function colorizeClass(name, cls) {
  const color = CLASS_COLORS[(cls || "").toUpperCase()] || CLASS_COLORS.UNKNOWN;
  return `<span style="color: ${color}; font-weight: 700;">${name || "Unknown"}</span>`;
}

// Data Fetching
async function loadKills() {
  try {
    const res = await fetch(`/api/kills?mode=${currentMode}&search=${encodeURIComponent(searchQuery)}`);
    const data = await res.json();
    cachedKills = data.kills || [];
    renderStats(cachedKills);
    if (currentTab === "FEED") {
      renderFeed(cachedKills);
    }
  } catch (err) {
    console.error("Failed to load kills:", err);
  }
}

async function loadSidebar() {
  try {
    const res = await fetch(`/api/leaderboard?mode=${currentMode}`);
    const data = await res.json();
    renderSidebar(data);
  } catch (err) {
    console.error("Failed to load sidebar:", err);
  }
}

async function loadLeaderboards() {
  try {
    const res = await fetch(`/api/leaderboard?mode=${currentMode}`);
    const data = await res.json();
    renderLeaderboardView(data);
  } catch (err) {
    console.error("Failed to load leaderboards:", err);
  }
}

async function loadBgGladiators() {
  try {
    const res = await fetch(`/api/bg/stats`);
    const data = await res.json();
    renderBgGladiatorsView(data);
  } catch (err) {
    console.error("Failed to load BG stats:", err);
  }
}

async function loadBounties() {
  try {
    const [bntRes, debtRes] = await Promise.all([
      fetch(`/api/bounties`),
      fetch(`/api/bounties/debt-ledger`)
    ]);
    const bounties = await bntRes.json();
    const debts = await debtRes.json();
    renderBountiesView(bounties, debts);
  } catch (err) {
    console.error("Failed to load bounties:", err);
  }
}

// Rendering Functions
async function renderStats(kills) {
  const totalKills = kills.length;
  const soloKills = kills.filter(k => k.isSolo).length;
  const soloPercent = totalKills > 0 ? Math.round((soloKills / totalKills) * 100) : 0;

  const totalEl = document.getElementById("stat-total-kills");
  if (totalEl) totalEl.innerText = totalKills;
  const soloEl = document.getElementById("stat-solo-percent");
  if (soloEl) soloEl.innerText = `${soloPercent}%`;

  const modeNames = {
    ALL: "All PvP",
    WORLD: "World",
    BG: "Battlegrounds",
    ARENA: "Arenas",
    DUEL: "Duels"
  };
  const modeEl = document.getElementById("stat-active-mode");
  if (modeEl) modeEl.innerText = modeNames[currentMode] || currentMode;

  try {
    const statsRes = await fetch("/api/stats");
    if (statsRes.ok) {
      const statsData = await statsRes.json();
      const duels = statsData.duels || { wins: 0, losses: 0 };
      const bgs = statsData.bgs || { wins: 0, losses: 0 };
      const arenas = statsData.arenas || { wins: 0, losses: 0 };
      const wlEl = document.getElementById("stat-wl-record");
      if (wlEl) {
        if (currentMode === "DUEL") {
          wlEl.innerText = `Duels: ${duels.wins}W - ${duels.losses}L`;
        } else if (currentMode === "BG") {
          wlEl.innerText = `BGs: ${bgs.wins}W - ${bgs.losses}L`;
        } else if (currentMode === "ARENA") {
          wlEl.innerText = `Arenas: ${arenas.wins}W - ${arenas.losses}L`;
        } else {
          wlEl.innerText = `D: ${duels.wins}W-${duels.losses}L | BG: ${bgs.wins}W-${bgs.losses}L`;
        }
      }
    }
  } catch (e) {
    // Ignore stats network errors
  }
}

function renderFeed(kills) {
  const container = document.getElementById("main-content-area");
  if (!kills || kills.length === 0) {
    container.innerHTML = `
      <div style="text-align: center; padding: 40px; color: #64748b;">
        <h3>No PvP records found for mode: [${currentMode}].</h3>
        <p style="margin-top: 8px;">Engage in combat, duels, or battlegrounds to populate the feed.</p>
      </div>
    `;
    return;
  }

  let html = `<div style="display: flex; flex-direction: column; gap: 8px;">`;
  kills.forEach(km => {
    const badge = km.isSolo 
      ? `<span class="km-badge-solo">SOLO</span>` 
      : `<span class="km-badge-gang">GANG ${km.attackersCount}</span>`;

    let ctxBadge = "";
    if (km.isDuel) {
      ctxBadge = `<span style="font-size:0.65rem; color:#ffd700; border:1px solid #ffd700; padding:2px 4px; border-radius:4px; font-weight:700;">DUEL</span>`;
    } else if (km.isArena) {
      ctxBadge = `<span style="font-size:0.65rem; color:#a335ee; border:1px solid #a335ee; padding:2px 4px; border-radius:4px; font-weight:700;">ARENA</span>`;
    } else if (km.isBattleground) {
      ctxBadge = `<span class="km-badge-bg">BG: ${km.battlegroundName || "PVP"}</span>`;
    } else {
      ctxBadge = `<span style="font-size:0.65rem; color:#94a3b8; border:1px solid #334155; padding:2px 4px; border-radius:4px;">WORLD</span>`;
    }

    const killerSpan = colorizeClass(km.killer.name, km.killer.class);
    const victimSpan = colorizeClass(km.victim.name, km.victim.class);
    const actionVerb = km.isDuel ? "defeated" : "destroyed";

    html += `
      <div class="killmail-row" onclick="openKillModal('${km.killId}')">
        <div class="km-left">
          ${badge}
          ${ctxBadge}
          <div class="km-combatants">
            <span class="km-killer">${killerSpan} <small style="color:#94a3b8">(${km.killer.level})</small></span>
            <span class="km-versus">${actionVerb}</span>
            <span class="km-victim">${victimSpan} <small style="color:#94a3b8">(${km.victim.level})</small></span>
          </div>
        </div>
        <div class="km-right">
          <span class="km-zone">${km.location.zone}</span>
          <span style="font-size:0.75rem;">${timeAgo(km.timestamp)}</span>
        </div>
      </div>
    `;
  });
  html += `</div>`;
  container.innerHTML = html;
}

function renderSidebar(data) {
  const topList = document.getElementById("sidebar-top-killers");
  if (!topList) return;

  let html = "";
  (data.topKillers || []).slice(0, 8).forEach((p, idx) => {
    html += `
      <div class="leader-item">
        <div style="display:flex; align-items:center; gap:8px;">
          <span class="leader-rank">#${idx + 1}</span>
          <div>
            ${colorizeClass(p.name, p.class)}
            <div style="font-size:0.7rem; color:#64748b;">${p.guild !== 'None' ? '&lt;' + p.guild + '&gt;' : ''}</div>
          </div>
        </div>
        <div style="text-align:right;">
          <div style="font-weight:700; color:#10b981;">${p.kills} Kills</div>
          <div style="font-size:0.7rem; color:#00e5ff;">${p.solo_kills || 0} Solo</div>
        </div>
      </div>
    `;
  });
  topList.innerHTML = html || "<div style='color:#64748b;'>No rankings yet</div>";

  const topZones = document.getElementById("sidebar-top-zones");
  if (!topZones) return;

  let zHtml = "";
  (data.topZones || []).slice(0, 5).forEach((z, idx) => {
    zHtml += `
      <div class="leader-item">
        <span style="color:#e2e8f0;">${z.zone}</span>
        <span style="color:#ef4444; font-weight:700;">${z.kills} kills</span>
      </div>
    `;
  });
  topZones.innerHTML = zHtml || "<div style='color:#64748b;'>No zone data</div>";
}

function renderLeaderboardView(data) {
  const container = document.getElementById("main-content-area");
  let html = `
    <div style="display: flex; flex-direction: column; gap: 20px;">
      <h2 style="font-size: 1.2rem; color: var(--accent-cyan);">Top PvP Assassins [${currentMode}]</h2>
      <div style="background-color: var(--bg-card); border: 1px solid var(--border-color); border-radius: 8px; padding: 16px;">
        <table style="width: 100%; border-collapse: collapse; font-size: 0.85rem;">
          <thead>
            <tr style="border-bottom: 1px solid var(--border-color); color: #94a3b8; text-align: left; height: 32px;">
              <th>Rank</th>
              <th>Combatant</th>
              <th>Guild</th>
              <th>Faction</th>
              <th>Kills</th>
              <th>Solo Kills</th>
            </tr>
          </thead>
          <tbody>
  `;

  (data.topKillers || []).forEach((p, idx) => {
    html += `
      <tr style="border-bottom: 1px solid rgba(255,255,255,0.05); height: 38px;">
        <td style="color: var(--accent-gold); font-weight: 800;">#${idx + 1}</td>
        <td>${colorizeClass(p.name, p.class)}</td>
        <td style="color: #94a3b8;">${p.guild !== 'None' ? p.guild : '-'}</td>
        <td style="color: ${p.faction === 'Alliance' ? '#3b82f6' : '#ef4444'};">${p.faction}</td>
        <td style="color: #10b981; font-weight: 700;">${p.kills}</td>
        <td style="color: #00e5ff; font-weight: 700;">${p.solo_kills || 0}</td>
      </tr>
    `;
  });

  html += `
          </tbody>
        </table>
      </div>
    </div>
  `;
  container.innerHTML = html;
}

function renderBgGladiatorsView(data) {
  const container = document.getElementById("main-content-area");
  let html = `
    <div style="display: flex; flex-direction: column; gap: 20px;">
      <h2 style="font-size: 1.2rem; color: var(--accent-cyan);">Battleground Gladiators — Damage & Healing Telemetry</h2>
      
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;">
        <div style="background-color: var(--bg-card); border: 1px solid var(--border-color); border-radius: 8px; padding: 16px;">
          <h3 style="color: #f97316; font-size: 1rem; margin-bottom: 12px;">Top Damage Dealers</h3>
          ${(data.topDamage || []).map((p, i) => `
            <div class="leader-item">
              <span>#${i+1} ${colorizeClass(p.name, p.class)}</span>
              <span style="color:#f97316; font-weight:700;">${formatNumber(p.total_damage)} Dmg</span>
            </div>
          `).join('')}
        </div>

        <div style="background-color: var(--bg-card); border: 1px solid var(--border-color); border-radius: 8px; padding: 16px;">
          <h3 style="color: #10b981; font-size: 1rem; margin-bottom: 12px;">Combat Medics (Top Healing)</h3>
          ${(data.topHealing || []).map((p, i) => `
            <div class="leader-item">
              <span>#${i+1} ${colorizeClass(p.name, p.class)}</span>
              <span style="color:#10b981; font-weight:700;">${formatNumber(p.total_healing)} Heal</span>
            </div>
          `).join('')}
        </div>
      </div>
    </div>
  `;
  container.innerHTML = html;
}

function renderBountiesView(bounties, debts) {
  const container = document.getElementById("main-content-area");
  let html = `
    <div style="display: flex; flex-direction: column; gap: 24px;">
      <!-- Active Bounties -->
      <div>
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px;">
          <h2 style="font-size: 1.2rem; color: var(--accent-gold);">Active Bounty Contracts</h2>
          <button class="supporter-btn" onclick="openPlaceBountyModal()">+ Place Bounty</button>
        </div>
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 12px;">
  `;

  if (!bounties || bounties.length === 0) {
    html += `<div style="color: #64748b;">No active bounties right now. Place one to ignite a manhunt!</div>`;
  } else {
    bounties.forEach(b => {
      html += `
        <div class="stat-card" style="border-color: rgba(245, 158, 11, 0.4);">
          <div style="display:flex; justify-content:space-between; align-items:center;">
            <span style="color:var(--accent-red); font-weight:800; font-size:1.1rem;">${b.target_name}</span>
            <span style="color:var(--accent-gold); font-weight:800;">${b.amount_gold || Math.floor(b.amount_copper/10000)}g</span>
          </div>
          <div style="font-size:0.75rem; color:#94a3b8; margin-top:4px;">
            Placed by: <strong style="color:#e2e8f0;">${b.placer_name}</strong>
          </div>
          <div style="font-size:0.7rem; color:#64748b; margin-top:2px;">
            Status: <span style="color:#10b981;">${b.status}</span> ${b.hunter_name ? `(Claimed by ${b.hunter_name})` : ''}
          </div>
        </div>
      `;
    });
  }

  html += `
        </div>
      </div>

      <!-- Wall of Shame: Oathbreaker Debt Ledger -->
      <div>
        <h2 style="font-size: 1.2rem; color: var(--accent-red); margin-bottom: 12px;">
          ⚠️ Wall of Shame — Oathbreakers in Default
        </h2>
        <div style="display: flex; flex-direction: column; gap: 8px;">
  `;

  if (!debts || debts.length === 0) {
    html += `<div style="color: #10b981;">No active defaulters. The realm's honor is preserved!</div>`;
  } else {
    debts.forEach(d => {
      html += `
        <div class="debt-card">
          <div class="debt-header">
            <div>
              <span class="debt-badge">OATHBREAKER</span>
              <strong style="color:#fff; font-size:1rem; margin-left:8px;">${d.player_name}</strong>
            </div>
            <span style="color:var(--accent-red); font-weight:800; font-size:1.1rem;">${formatCopper(d.amount_owed_copper)} Owed</span>
          </div>
          <div style="font-size:0.8rem; color:#cbd5e1;">
            Defaulted on bounty owed to <strong style="color:var(--accent-cyan);">${d.creditor}</strong>.
            In default for <strong style="color:#f87171;">${d.days_in_default} days</strong>.
          </div>
          <div style="font-size:0.7rem; color:#94a3b8; margin-top:6px;">
            Target is marked server-wide. Hunters earn double points for slaying this oathbreaker.
          </div>
        </div>
      `;
    });
  }

  html += `
        </div>
      </div>
    </div>
  `;
  container.innerHTML = html;
}

// Modal Handlers
function openKillModal(killId) {
  const km = cachedKills.find(k => k.killId === killId);
  if (!km) return;

  const modal = document.getElementById("kill-modal");
  const body = document.getElementById("modal-body");

  body.innerHTML = `
    <div style="display:flex; justify-content:space-between; align-items:center;">
      <span style="font-size:0.8rem; color:#94a3b8;">${km.killId}</span>
      <span style="font-size:0.8rem; color:#94a3b8;">${new Date(km.timestamp * 1000).toLocaleString()}</span>
    </div>

    <div style="display:flex; justify-content:space-around; align-items:center; background:#07090e; padding:16px; border-radius:8px; border:1px solid #1e293b;">
      <div style="text-align:center;">
        <div style="font-size:0.75rem; color:#10b981; font-weight:700;">KILLER</div>
        <div style="font-size:1.2rem; font-weight:800;">${colorizeClass(km.killer.name, km.killer.class)}</div>
        <div style="font-size:0.8rem; color:#94a3b8;">Level ${km.killer.level} ${km.killer.class}</div>
        <div style="font-size:0.75rem; color:#64748b;">${km.killer.guild !== 'None' ? '&lt;' + km.killer.guild + '&gt;' : ''}</div>
        <div style="font-size:0.75rem; color:#00e5ff; margin-top:4px;">Party: ${km.killer.partySize} member(s)</div>
      </div>

      <div style="font-size:1.5rem; font-weight:800; color:#ef4444;">VS</div>

      <div style="text-align:center;">
        <div style="font-size:0.75rem; color:#ef4444; font-weight:700;">VICTIM</div>
        <div style="font-size:1.2rem; font-weight:800;">${colorizeClass(km.victim.name, km.victim.class)}</div>
        <div style="font-size:0.8rem; color:#94a3b8;">Level ${km.victim.level} ${km.victim.class}</div>
        <div style="font-size:0.75rem; color:#64748b;">${km.victim.guild !== 'None' ? '&lt;' + km.victim.guild + '&gt;' : ''}</div>
        <div style="font-size:0.75rem; color:#f97316; margin-top:4px;">Hostile Gang: ${km.victim.partySize} member(s)</div>
      </div>
    </div>

    <div style="display:grid; grid-template-columns:1fr 1fr; gap:12px; font-size:0.85rem;">
      <div style="background:#0e121a; padding:10px; border-radius:6px; border:1px solid #242b3d;">
        <strong style="color:var(--accent-gold);">Engagement Context</strong>
        <div style="color:#cbd5e1; margin-top:4px;">${km.isDuel ? '1v1 Duel' : (km.isArena ? 'Ranked Arena Match' : (km.isBattleground ? `Battleground [${km.battlegroundName || 'BG'}]` : 'Open World PvP'))}</div>
        <div style="color:#94a3b8;">Type: ${km.isDuel ? '<span style="color:#ffd700; font-weight:700;">1v1 Duel</span>' : (km.isSolo ? '<span style="color:#10b981; font-weight:700;">Solo Kill</span>' : '<span style="color:#f59e0b; font-weight:700;">Gang Kill</span>')}</div>
      </div>
      <div style="background:#0e121a; padding:10px; border-radius:6px; border:1px solid #242b3d;">
        <strong style="color:var(--accent-gold);">Location Coordinates</strong>
        <div style="color:#cbd5e1; margin-top:4px;">${km.location.zone} ${km.location.subZone ? `(${km.location.subZone})` : ''}</div>
        <div style="color:#94a3b8;">GPS: ${km.location.x.toFixed(1)}, ${km.location.y.toFixed(1)}</div>
      </div>
    </div>
  `;

  modal.style.display = "flex";
}

function closeModal() {
  document.getElementById("kill-modal").style.display = "none";
}

// Tab Switching
function switchTab(tab) {
  currentTab = tab;
  document.querySelectorAll(".nav-btn").forEach(b => b.classList.remove("active"));
  const activeBtn = document.getElementById(`nav-${tab.toLowerCase()}`);
  if (activeBtn) activeBtn.classList.add("active");

  if (tab === "FEED") loadKills();
  else if (tab === "LEADERBOARDS") loadLeaderboards();
  else if (tab === "BG_METRICS") loadBgGladiators();
  else if (tab === "BOUNTIES") loadBounties();
}

function setFilterMode(mode) {
  currentMode = mode;
  document.querySelectorAll(".pill-btn").forEach(b => b.classList.remove("active"));
  const activePill = document.getElementById(`pill-${mode.toLowerCase()}`);
  if (activePill) activePill.classList.add("active");

  loadKills();
  loadSidebar();
  if (currentTab === "LEADERBOARDS") loadLeaderboards();
}

function openPlaceBountyModal() {
  const target = prompt("Enter Target Player Name:");
  if (!target) return;
  const gold = prompt("Enter Gold Amount (e.g. 500):", "500");
  if (!gold) return;

  fetch("/api/bounties", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      targetName: target,
      amountGold: parseInt(gold),
      placerName: "WebUser"
    })
  }).then(() => {
    alert(`Bounty of ${gold}g placed on ${target}!`);
    loadBounties();
  });
}

// Initialization
document.addEventListener("DOMContentLoaded", () => {
  const searchEl = document.getElementById("search-box");
  if (searchEl) {
    searchEl.addEventListener("input", (e) => {
      searchQuery = e.target.value;
      loadKills();
    });
  }

  loadKills();
  loadSidebar();

  // Polling update every 6 seconds
  setInterval(() => {
    if (currentTab === "FEED") loadKills();
    loadSidebar();
  }, 6000);
});
