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

const CLASS_SYMBOLS = {
  WARRIOR: "⚔️",
  PALADIN: "🛡️",
  HUNTER: "🏹",
  ROGUE: "🗡️",
  PRIEST: "☀️",
  DEATHKNIGHT: "💀",
  SHAMAN: "⚡",
  MAGE: "🔮",
  WARLOCK: "🔥",
  MONK: "🥋",
  DRUID: "🐾",
  DEMONHUNTER: "👁️",
  EVOKER: "🐉",
  UNKNOWN: "👤"
};

let currentTab = "FEED";
let currentMode = "ALL";
let searchQuery = "";
let cachedKills = [];

// Bounty Acceptance & Opt-In Helpers
function isBountyAcceptedLocally(bountyId) {
  try {
    const list = JSON.parse(localStorage.getItem("wow_killboard_accepted_bounties") || "[]");
    return list.includes(bountyId);
  } catch (e) {
    return false;
  }
}

function markBountyAcceptedLocally(bountyId) {
  try {
    let list = JSON.parse(localStorage.getItem("wow_killboard_accepted_bounties") || "[]");
    if (!list.includes(bountyId)) {
      list.push(bountyId);
      localStorage.setItem("wow_killboard_accepted_bounties", JSON.stringify(list));
    }
  } catch (e) {}
}

async function acceptBountyContract(bountyId, targetName) {
  let hunter = localStorage.getItem("wow_killboard_hunter_name");
  if (!hunter) {
    hunter = prompt(`Accept Bounty Contract on ${targetName}?\nEnter your Hunter Character Name:`);
    if (!hunter || !hunter.trim()) return;
    localStorage.setItem("wow_killboard_hunter_name", hunter.trim());
  }

  try {
    const res = await fetch("/api/bounties/accept", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        bountyId: bountyId,
        hunterName: hunter.trim()
      })
    });
    if (res.ok) {
      markBountyAcceptedLocally(bountyId);
      alert(`Contract accepted! You are now tracking ${targetName}. Deliver the certified killing blow to claim the reward!`);
      loadMostWanted();
    } else {
      alert("Failed to accept bounty contract.");
    }
  } catch (err) {
    console.error("Failed to accept contract:", err);
  }
}

// Purge any legacy toggle state so Most Wanted is always static
try {
  localStorage.removeItem("wow_killboard_bounty_mode");
} catch (e) {}

async function loadMostWanted() {
  const container = document.getElementById("most-wanted-cards-container");
  if (!container) return;

  try {
    const isSupporter = isSupporterActive();
    const res = await fetch(`/api/bounties/most-wanted?supporter=${isSupporter ? '1' : '0'}`);
    if (!res.ok) return;
    const outlaws = await res.json();
    renderMostWanted(outlaws);
  } catch (err) {
    console.error("Failed to load Most Wanted:", err);
  }
}

function renderMostWanted(outlaws) {
  const container = document.getElementById("most-wanted-cards-container");
  if (!container) return;

  if (!outlaws || outlaws.length === 0) {
    container.innerHTML = `
      <div style="grid-column: 1/-1; text-align:center; padding:20px; color:#64748b; font-size:0.85rem;">
        No active wanted contracts currently registered. Slay enemy outlaws to issue bounties!
      </div>
    `;
    return;
  }

  let html = "";
  outlaws.slice(0, 10).forEach((b, idx) => {
    const cls = (b.target_class || "WARRIOR").toUpperCase();
    const clsColor = CLASS_COLORS[cls] || CLASS_COLORS.UNKNOWN;
    const symbol = CLASS_SYMBOLS[cls] || "👤";
    const accepted = isBountyAcceptedLocally(b.id);
    const lastSeenText = b.lastSeen && b.lastSeen.hasTelemetry 
      ? `📍 ${b.lastSeen.displayText}` 
      : "📍 Last Seen: Unknown";

    const btnHtml = accepted 
      ? `<button class="wanted-btn accepted" disabled>✓ Tracking Contract</button>`
      : `<button class="wanted-btn" onclick="acceptBountyContract('${b.id}', '${b.target_name}')">🎯 Accept Contract</button>`;

    html += `
      <div class="wanted-card">
        <span class="wanted-stamp">#${idx + 1} WANTED</span>
        <div class="wanted-avatar-wrap" style="border: 2px solid ${clsColor}; box-shadow: 0 0 10px ${clsColor}33;">
          <span class="wanted-avatar-symbol">${symbol}</span>
        </div>
        <div class="wanted-name" onclick="openCharacterProfile('${b.target_name}')">
          ${colorizeClass(b.target_name, cls)}
        </div>
        <div class="wanted-guild">&lt;${b.target_faction || 'Neutral'}&gt;</div>
        <div class="wanted-reward">💰 ${formatNumber(b.amount_gold)} Gold</div>
        <div class="wanted-lastseen" title="${lastSeenText}">${lastSeenText}</div>
        ${btnHtml}
      </div>
    `;
  });

  container.innerHTML = html;
}

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

function formatDuration(sec) {
  sec = Math.max(0, Number(sec) || 0);
  if (sec < 60) return `${sec}s`;
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  if (sec < 3600) return `${m}m ${s}s`;
  const h = Math.floor(sec / 3600);
  const remM = Math.floor((sec % 3600) / 60);
  if (h < 24) return `${h}h ${remM}m`;
  const d = Math.floor(h / 24);
  const remH = h % 24;
  return `${d}d ${remH}h`;
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
    const res = await fetch("/api/stats/activity-7d");
    if (!res.ok) return;
    const data = await res.json();
    renderSidebarActivity(data);
  } catch (err) {
    console.error("Failed to load 7d activity sidebar:", err);
  }
}

function renderSidebarActivity(data) {
  // 1. Current Activity Table Numbers
  const charsEl = document.getElementById("act-7d-chars");
  if (charsEl) charsEl.innerText = formatNumber(data.characters || 0);

  const guildsEl = document.getElementById("act-7d-guilds");
  if (guildsEl) guildsEl.innerText = formatNumber(data.guilds || 0);

  const killsEl = document.getElementById("act-7d-kills");
  if (killsEl) killsEl.innerText = formatNumber(data.kills || 0);

  const allEl = document.getElementById("act-7d-alliance");
  if (allEl) allEl.innerText = formatNumber(data.allianceKills || 0);

  const hordeEl = document.getElementById("act-7d-horde");
  if (hordeEl) hordeEl.innerText = formatNumber(data.hordeKills || 0);

  const zonesEl = document.getElementById("act-7d-zones");
  if (zonesEl) zonesEl.innerText = formatNumber(data.zones || 0);

  // 2. Top Characters (7 Days)
  const charListEl = document.getElementById("sidebar-7d-characters");
  if (charListEl) {
    if (!data.topCharacters || data.topCharacters.length === 0) {
      charListEl.innerHTML = `<div style="color:#64748b; font-size:0.75rem;">No character kills logged in last 7 days</div>`;
    } else {
      charListEl.innerHTML = data.topCharacters.map((c, i) => {
        const guildPart = (c.guild && c.guild !== 'None') 
          ? `<span class="clickable-guild" onclick="openGuildProfile('${c.guild}')">&lt;${c.guild}&gt;</span>`
          : '';
        return `
          <div class="sidebar-rank-item">
            <div style="display:flex; align-items:center; gap:8px;">
              <span class="rank-badge">#${i + 1}</span>
              <div>
                <span class="clickable-player" onclick="openCharacterProfile('${c.name}')">${colorizeClass(c.name, c.class)}</span>
                <div style="font-size:0.7rem; color:#94a3b8;">${guildPart}</div>
              </div>
            </div>
            <span style="color:#10b981; font-weight:800; font-size:0.85rem;">${c.kills} kills</span>
          </div>
        `;
      }).join('');
    }
  }

  // 3. Top Guilds (7 Days)
  const guildListEl = document.getElementById("sidebar-7d-guilds");
  if (guildListEl) {
    if (!data.topGuilds || data.topGuilds.length === 0) {
      guildListEl.innerHTML = `<div style="color:#64748b; font-size:0.75rem;">No active guild combat in last 7 days</div>`;
    } else {
      guildListEl.innerHTML = data.topGuilds.map((g, i) => {
        const factionColor = g.faction === 'Alliance' ? 'var(--alliance-blue)' : (g.faction === 'Horde' ? 'var(--horde-red)' : '#94a3b8');
        return `
          <div class="sidebar-rank-item">
            <div style="display:flex; align-items:center; gap:8px;">
              <span class="rank-badge">#${i + 1}</span>
              <div>
                <span class="clickable-guild" onclick="openGuildProfile('${g.guild}')" style="font-weight:700;">&lt;${g.guild}&gt;</span>
                <div style="font-size:0.68rem; color:${factionColor};">${g.faction || 'Neutral'}</div>
              </div>
            </div>
            <span style="color:var(--accent-gold); font-weight:800; font-size:0.85rem;">${g.kills} kills</span>
          </div>
        `;
      }).join('');
    }
  }

  // 4. Top Classes (7 Days)
  const classListEl = document.getElementById("sidebar-7d-classes");
  if (classListEl) {
    if (!data.topClasses || data.topClasses.length === 0) {
      classListEl.innerHTML = `<div style="color:#64748b; font-size:0.75rem;">No class telemetry logged</div>`;
    } else {
      classListEl.innerHTML = data.topClasses.map(cls => {
        const color = CLASS_COLORS[cls.class] || CLASS_COLORS.UNKNOWN;
        return `
          <div style="display:flex; justify-content:space-between; align-items:center; background:#07090e; padding:5px 8px; border-radius:4px; font-size:0.75rem; border:1px solid #1e293b;">
            <span style="color:${color}; font-weight:700;">${cls.class}</span>
            <span style="color:#e2e8f0; font-weight:700;">${cls.kills} kills</span>
          </div>
        `;
      }).join('');
    }
  }

  // 5. Top Zones (7 Days)
  const zoneListEl = document.getElementById("sidebar-7d-zones-list");
  if (zoneListEl) {
    if (!data.topZones || data.topZones.length === 0) {
      zoneListEl.innerHTML = `<div style="color:#64748b; font-size:0.75rem;">No conflict zones logged</div>`;
    } else {
      zoneListEl.innerHTML = data.topZones.map(z => `
        <div style="display:flex; justify-content:space-between; align-items:center; background:#07090e; padding:5px 8px; border-radius:4px; font-size:0.75rem; border:1px solid #1e293b;">
          <span style="color:#e2e8f0;">${z.zone}</span>
          <span style="color:#ef4444; font-weight:700;">${z.kills} kills</span>
        </div>
      `).join('');
    }
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
  const container = document.getElementById("main-content-area");
  if (container) {
    container.innerHTML = `<div style="text-align:center; padding:40px; color:#94a3b8;">Gathering active bounty contracts and debt ledger...</div>`;
  }
  try {
    const isSupporter = isSupporterActive();
    const [bntRes, debtRes, lbRes] = await Promise.all([
      fetch(`/api/bounties?supporter=${isSupporter ? '1' : '0'}`),
      fetch(`/api/bounties/debt-ledger`),
      fetch(`/api/bounties/leaderboards`)
    ]);
    const bounties = await bntRes.json();
    const debts = await debtRes.json();
    const leaderboards = await lbRes.json();
    renderBountiesView(bounties, debts, leaderboards);
  } catch (err) {
    console.error("Failed to load bounties:", err);
    if (container) {
      container.innerHTML = `<div style="text-align:center; padding:40px; color:#ef4444;">Failed to load bounties: ${err.message}</div>`;
    }
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

  let html = `
    <div style="display: flex; flex-direction: column; gap: 8px;">
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:4px; padding-bottom:8px; border-bottom:1px solid #1e293b;">
        <div style="display:flex; align-items:center; gap:8px;">
          <span style="font-size:1.1rem;">⚔️</span>
          <span style="font-size:1.05rem; font-weight:800; color:var(--accent-cyan); letter-spacing:-0.3px;">Most Recent Kills</span>
        </div>
        <span style="font-size:0.75rem; color:#94a3b8;">${kills.length} recent combat events</span>
      </div>
  `;
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
            <span class="km-killer"><span class="clickable-player" onclick="event.stopPropagation(); openCharacterProfile('${km.killer.name}')">${killerSpan}</span> <small style="color:#94a3b8">(${km.killer.level})</small></span>
            <span class="km-versus">${actionVerb}</span>
            <span class="km-victim"><span class="clickable-player" onclick="event.stopPropagation(); openCharacterProfile('${km.victim.name}')">${victimSpan}</span> <small style="color:#94a3b8">(${km.victim.level})</small></span>
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
    const guildHtml = (p.guild && p.guild !== 'None')
      ? `<span class="clickable-guild" onclick="openGuildProfile('${p.guild}')">${p.guild}</span>`
      : '-';
    html += `
      <tr style="border-bottom: 1px solid rgba(255,255,255,0.05); height: 38px;">
        <td style="color: var(--accent-gold); font-weight: 800;">#${idx + 1}</td>
        <td><span class="clickable-player" onclick="openCharacterProfile('${p.name}')">${colorizeClass(p.name, p.class)}</span></td>
        <td>${guildHtml}</td>
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

function renderBountiesView(bounties, debts, leaderboards) {
  const container = document.getElementById("main-content-area");
  leaderboards = leaderboards || {};
  const isSupporter = isSupporterActive();

  let html = `
    <div style="display: flex; flex-direction: column; gap: 24px;">
      <!-- Active Bounties Section -->
      <div>
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px;">
          <div>
            <h2 style="font-size: 1.2rem; color: var(--accent-gold);">Active Bounty Contracts</h2>
            <div style="font-size:0.75rem; color:#94a3b8; margin-top:2px;">Track and execute targets to claim escrowed gold.</div>
          </div>
          <button class="supporter-btn" onclick="openPlaceBountyModal()">+ Place Bounty</button>
        </div>
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 12px;">
  `;

  if (!bounties || bounties.length === 0) {
    html += `<div style="color: #64748b; padding:16px;">No active bounties right now. Place one to ignite a manhunt!</div>`;
  } else {
    bounties.forEach(b => {
      const lastSeen = b.lastSeen || {};
      let lastSeenHtml = "";
      if (lastSeen.hasTelemetry) {
        if (isSupporter && lastSeen.subzone) {
          lastSeenHtml = `
            <div style="font-size:0.75rem; color:#38bdf8; margin-top:8px; background:#07090e; padding:6px 10px; border-radius:4px; border:1px solid #1e293b;">
              <span style="font-weight:700;">📍 Last Sighted:</span> ${lastSeen.zone} <span style="color:#fbbf24;">(${lastSeen.subzone})</span>
              <div style="font-size:0.7rem; color:#94a3b8; margin-top:2px;">
                ~${lastSeen.minutesAgo}m ago &bull; <span style="color:#fbbf24; font-weight:700;">⭐ Subzone Intel</span>
              </div>
            </div>
          `;
        } else {
          lastSeenHtml = `
            <div style="font-size:0.75rem; color:#38bdf8; margin-top:8px; background:#07090e; padding:6px 10px; border-radius:4px; border:1px solid #1e293b; display:flex; justify-content:space-between; align-items:center;">
              <div>
                <span style="font-weight:700;">📍 Last Sighted:</span> ${lastSeen.zone}
                <div style="font-size:0.7rem; color:#94a3b8; margin-top:2px;">~${lastSeen.minutesAgo}m ago</div>
              </div>
              <span style="color:#64748b; font-size:0.7rem; cursor:pointer;" onclick="toggleSupporterMode()" title="Toggle Supporter Mode to unlock Subzone Recon">[🔒 Subzone]</span>
            </div>
          `;
        }
      } else {
        lastSeenHtml = `
          <div style="font-size:0.72rem; color:#64748b; margin-top:8px; background:#07090e; padding:6px 10px; border-radius:4px; border:1px solid #1e293b;">
            📍 Last Sighted: <em>No recent combat logged</em>
          </div>
        `;
      }

      html += `
        <div class="stat-card" style="border-color: rgba(245, 158, 11, 0.4);">
          <div style="display:flex; justify-content:space-between; align-items:center;">
            <span class="clickable-player" onclick="openCharacterProfile('${b.target_name}')" style="color:var(--accent-red); font-weight:800; font-size:1.15rem;">${b.target_name}</span>
            <span style="color:var(--accent-gold); font-weight:800; font-size:1.1rem;">${b.amount_gold || Math.floor(b.amount_copper/10000)}g</span>
          </div>
          <div style="font-size:0.75rem; color:#94a3b8; margin-top:4px;">
            Target: <span style="color:#cbd5e1;">Level ${b.target_class || 'UNKNOWN'}</span> &bull; Placer: <strong style="color:#e2e8f0;">${b.placer_name}</strong>
          </div>
          <div style="font-size:0.7rem; color:#64748b; margin-top:2px;">
            Status: <span style="color:#10b981; font-weight:700;">${b.status}</span> ${b.hunter_name ? `(Claimed by ${b.hunter_name})` : ''}
          </div>
          ${lastSeenHtml}
        </div>
      `;
    });
  }

  html += `
        </div>
      </div>

      <!-- Bounty Leaderboards: Hall of Fame -->
      <div>
        <h2 style="font-size: 1.2rem; color: var(--accent-gold); margin-bottom: 12px;">🏆 Bounty Hall of Fame &amp; Records</h2>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;">
          
          <!-- 1. Top Bounty Hunters -->
          <div style="background-color: var(--bg-card); border: 1px solid var(--border-color); border-radius: 8px; padding: 14px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;">
              <h3 style="color:#10b981; font-size:0.95rem;">🎯 Top Bounty Hunters</h3>
              <span style="font-size:0.7rem; color:#64748b;">Most Bounties Claimed</span>
            </div>
            <div style="display:flex; flex-direction:column; gap:6px;">
              ${(leaderboards.topHunters && leaderboards.topHunters.length > 0) 
                ? leaderboards.topHunters.map((h, i) => `
                  <div class="leader-item">
                    <span>#${i+1} <span class="clickable-player" onclick="openCharacterProfile('${h.hunter_name}')">${h.hunter_name}</span></span>
                    <span style="text-align:right;">
                      <span style="color:#10b981; font-weight:700;">${h.claimed_count} Claimed</span>
                      <small style="color:var(--accent-gold); margin-left:6px;">(${h.total_gold}g)</small>
                    </span>
                  </div>
                `).join('')
                : '<div style="color:#64748b; font-size:0.8rem;">No bounties claimed yet.</div>'
              }
            </div>
          </div>

          <!-- 2. Highest Bounty Contracts -->
          <div style="background-color: var(--bg-card); border: 1px solid var(--border-color); border-radius: 8px; padding: 14px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;">
              <h3 style="color:var(--accent-gold); font-size:0.95rem;">💰 Highest Bounty Contracts</h3>
              <span style="font-size:0.7rem; color:#64748b;">Biggest Escrow Rewards</span>
            </div>
            <div style="display:flex; flex-direction:column; gap:6px;">
              ${(leaderboards.highestBounties && leaderboards.highestBounties.length > 0)
                ? leaderboards.highestBounties.map((b, i) => `
                  <div class="leader-item">
                    <span>#${i+1} <span class="clickable-player" onclick="openCharacterProfile('${b.target_name}')">${b.target_name}</span></span>
                    <span style="text-align:right;">
                      <span style="color:var(--accent-gold); font-weight:800;">${b.amount_gold}g</span>
                      <small style="color:${b.status === 'CLAIMED' ? '#10b981' : '#f59e0b'}; margin-left:6px;">[${b.status}]</small>
                    </span>
                  </div>
                `).join('')
                : '<div style="color:#64748b; font-size:0.8rem;">No bounty records found.</div>'
              }
            </div>
          </div>

          <!-- 3. Longest Outstanding (Most Elusive Outlaws) -->
          <div style="background-color: var(--bg-card); border: 1px solid var(--border-color); border-radius: 8px; padding: 14px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;">
              <h3 style="color:#f97316; font-size:0.95rem;">⏳ Most Elusive Outlaws</h3>
              <span style="font-size:0.7rem; color:#64748b;">Longest Surviving Bounties</span>
            </div>
            <div style="display:flex; flex-direction:column; gap:6px;">
              ${(leaderboards.longestOutstanding && leaderboards.longestOutstanding.length > 0)
                ? leaderboards.longestOutstanding.map((o, i) => `
                  <div class="leader-item">
                    <span>#${i+1} <span class="clickable-player" onclick="openCharacterProfile('${o.target_name}')">${o.target_name}</span></span>
                    <span style="text-align:right;">
                      <span style="color:#f97316; font-weight:700;">Survived ${formatDuration(o.elapsed_seconds)}</span>
                      <small style="color:var(--accent-gold); margin-left:6px;">(${o.amount_gold}g)</small>
                    </span>
                  </div>
                `).join('')
                : '<div style="color:#64748b; font-size:0.8rem;">No active outstanding bounties.</div>'
              }
            </div>
          </div>

          <!-- 4. Fastest Collected Manhunts -->
          <div style="background-color: var(--bg-card); border: 1px solid var(--border-color); border-radius: 8px; padding: 14px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;">
              <h3 style="color:var(--accent-cyan); font-size:0.95rem;">⚡ Fastest Collected Manhunts</h3>
              <span style="font-size:0.7rem; color:#64748b;">Record Execution Times</span>
            </div>
            <div style="display:flex; flex-direction:column; gap:6px;">
              ${(leaderboards.fastestCollected && leaderboards.fastestCollected.length > 0)
                ? leaderboards.fastestCollected.map((f, i) => `
                  <div class="leader-item">
                    <span>#${i+1} <span class="clickable-player" onclick="openCharacterProfile('${f.target_name}')">${f.target_name}</span></span>
                    <span style="text-align:right;">
                      <span style="color:var(--accent-cyan); font-weight:700;">${formatDuration(f.duration_seconds)}</span>
                      <small style="color:#94a3b8; margin-left:4px;">by ${f.hunter_name || 'Hunter'}</small>
                    </span>
                  </div>
                `).join('')
                : '<div style="color:#64748b; font-size:0.8rem;">No timed executions on record.</div>'
              }
            </div>
          </div>

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
    html += `<div style="color: #10b981; padding:12px;">No active defaulters. The realm's honor is preserved!</div>`;
  } else {
    debts.forEach(d => {
      html += `
        <div class="debt-card">
          <div class="debt-header">
            <div>
              <span class="debt-badge">OATHBREAKER</span>
              <strong style="color:#fff; font-size:1rem; margin-left:8px;" class="clickable-player" onclick="openCharacterProfile('${d.player_name}')">${d.player_name}</strong>
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

  const killerGuild = (km.killer.guild && km.killer.guild !== 'None') 
    ? `<span class="clickable-guild" onclick="openGuildProfile('${km.killer.guild}')">&lt;${km.killer.guild}&gt;</span>` 
    : '';
  const victimGuild = (km.victim.guild && km.victim.guild !== 'None') 
    ? `<span class="clickable-guild" onclick="openGuildProfile('${km.victim.guild}')">&lt;${km.victim.guild}&gt;</span>` 
    : '';

  body.innerHTML = `
    <div style="display:flex; justify-content:space-between; align-items:center;">
      <span style="font-size:0.8rem; color:#94a3b8;">${km.killId}</span>
      <span style="font-size:0.8rem; color:#94a3b8;">${new Date(km.timestamp * 1000).toLocaleString()}</span>
    </div>

    <div style="display:flex; justify-content:space-around; align-items:center; background:#07090e; padding:16px; border-radius:8px; border:1px solid #1e293b;">
      <div style="text-align:center;">
        <div style="font-size:0.75rem; color:#10b981; font-weight:700;">KILLER</div>
        <div style="font-size:1.2rem; font-weight:800;"><span class="clickable-player" onclick="openCharacterProfile('${km.killer.name}')">${colorizeClass(km.killer.name, km.killer.class)}</span></div>
        <div style="font-size:0.8rem; color:#94a3b8;">Level ${km.killer.level} ${km.killer.class}</div>
        <div style="font-size:0.75rem; color:#64748b;">${killerGuild}</div>
        <div style="font-size:0.75rem; color:#00e5ff; margin-top:4px;">Party: ${km.killer.partySize} member(s)</div>
      </div>

      <div style="font-size:1.5rem; font-weight:800; color:#ef4444;">VS</div>

      <div style="text-align:center;">
        <div style="font-size:0.75rem; color:#ef4444; font-weight:700;">VICTIM</div>
        <div style="font-size:1.2rem; font-weight:800;"><span class="clickable-player" onclick="openCharacterProfile('${km.victim.name}')">${colorizeClass(km.victim.name, km.victim.class)}</span></div>
        <div style="font-size:0.8rem; color:#94a3b8;">Level ${km.victim.level} ${km.victim.class}</div>
        <div style="font-size:0.75rem; color:#64748b;">${victimGuild}</div>
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

// Character Profile Modal Handlers
async function openCharacterProfile(charName) {
  const modal = document.getElementById("character-modal");
  const body = document.getElementById("character-modal-body");
  const title = document.getElementById("character-modal-title");
  if (!modal || !body) return;

  title.innerText = `Character Dossier: ${charName}`;
  body.innerHTML = `<div style="text-align:center; padding:30px; color:#94a3b8;">Decrypting combat dossier for ${charName}...</div>`;
  modal.style.display = "flex";

  try {
    const res = await fetch(`/api/character/${encodeURIComponent(charName)}`);
    if (!res.ok) {
      body.innerHTML = `<div style="text-align:center; padding:30px; color:#ef4444;">Character telemetry not found.</div>`;
      return;
    }
    const data = await res.json();
    const stats = data.stats || {};
    const guildText = (data.currentGuild && data.currentGuild !== 'None') 
      ? `<span class="clickable-guild" onclick="openGuildProfile('${data.currentGuild}')">&lt;${data.currentGuild}&gt;</span>` 
      : '<span style="color:#64748b;">No Guild</span>';

    const factionColor = data.faction === 'Alliance' ? '#3b82f6' : (data.faction === 'Horde' ? '#ef4444' : '#94a3b8');

    let historyHtml = "";
    if (data.guildHistory && data.guildHistory.length > 0) {
      historyHtml = `
        <div style="margin-top:12px;">
          <h4 style="color:var(--accent-gold); font-size:0.9rem; margin-bottom:8px;">Guild Affiliation History</h4>
          <div class="timeline-list">
            ${data.guildHistory.map(g => {
              const firstSeenStr = g.first_seen ? new Date(g.first_seen * 1000).toLocaleDateString() : "Unknown";
              const lastSeenStr = g.last_seen ? new Date(g.last_seen * 1000).toLocaleDateString() : "Active";
              return `
                <div class="timeline-row">
                  <div>
                    <span class="clickable-guild" onclick="openGuildProfile('${g.guild_name}')">&lt;${g.guild_name}&gt;</span>
                    <span style="font-size:0.7rem; color:${g.faction === 'Alliance' ? '#3b82f6' : '#ef4444'}; margin-left:6px;">(${g.faction || 'Neutral'})</span>
                  </div>
                  <span style="color:#94a3b8; font-size:0.75rem;">${firstSeenStr} — ${lastSeenStr}</span>
                </div>
              `;
            }).join("")}
          </div>
        </div>
      `;
    }

    let killsHtml = "";
    if (data.recentKills && data.recentKills.length > 0) {
      killsHtml = `
        <div style="margin-top:12px;">
          <h4 style="color:#10b981; font-size:0.9rem; margin-bottom:8px;">Recent Slain Enemies (${data.recentKills.length})</h4>
          <div style="display:flex; flex-direction:column; gap:4px; max-height:160px; overflow-y:auto;">
            ${data.recentKills.map(k => `
              <div style="display:flex; justify-content:space-between; align-items:center; background:#07090e; padding:6px 10px; border-radius:4px; font-size:0.75rem; border:1px solid #1e293b;">
                <div>
                  <span class="clickable-player" onclick="openCharacterProfile('${k.victim_name}')">${colorizeClass(k.victim_name, k.victim_class)}</span>
                  <small style="color:#64748b;">(Lvl ${k.victim_level})</small>
                  ${k.victim_guild && k.victim_guild !== 'None' ? `<span class="clickable-guild" onclick="openGuildProfile('${k.victim_guild}')">&lt;${k.victim_guild}&gt;</span>` : ''}
                </div>
                <div style="text-align:right; color:#94a3b8;">
                  <span>${k.zone}</span> &bull; <span>${timeAgo(k.timestamp)}</span>
                </div>
              </div>
            `).join("")}
          </div>
        </div>
      `;
    }

    let deathsHtml = "";
    if (data.recentDeaths && data.recentDeaths.length > 0) {
      deathsHtml = `
        <div style="margin-top:12px;">
          <h4 style="color:#ef4444; font-size:0.9rem; margin-bottom:8px;">Recent Deaths In Combat (${data.recentDeaths.length})</h4>
          <div style="display:flex; flex-direction:column; gap:4px; max-height:160px; overflow-y:auto;">
            ${data.recentDeaths.map(d => `
              <div style="display:flex; justify-content:space-between; align-items:center; background:#07090e; padding:6px 10px; border-radius:4px; font-size:0.75rem; border:1px solid #1e293b;">
                <div>
                  Killed by: <span class="clickable-player" onclick="openCharacterProfile('${d.killer_name}')">${colorizeClass(d.killer_name, d.killer_class)}</span>
                  <small style="color:#64748b;">(Lvl ${d.killer_level})</small>
                  ${d.killer_guild && d.killer_guild !== 'None' ? `<span class="clickable-guild" onclick="openGuildProfile('${d.killer_guild}')">&lt;${d.killer_guild}&gt;</span>` : ''}
                </div>
                <div style="text-align:right; color:#94a3b8;">
                  <span>${d.zone}</span> &bull; <span>${timeAgo(d.timestamp)}</span>
                </div>
              </div>
            `).join("")}
          </div>
        </div>
      `;
    }

    body.innerHTML = `
      <div style="display:flex; justify-content:space-between; align-items:center; background:#07090e; padding:16px; border-radius:8px; border:1px solid #1e293b;">
        <div>
          <div style="font-size:1.4rem; font-weight:800;">${colorizeClass(data.name, data.class)}</div>
          <div style="font-size:0.85rem; color:#94a3b8; margin-top:2px;">
            Level ${data.level} ${data.class} &bull; <span style="color:${factionColor}; font-weight:700;">${data.faction}</span> &bull; ${guildText}
          </div>
        </div>
        <div class="armory-group">
          <a class="armory-btn" href="${data.armoryUrls.official}" target="_blank" rel="noopener">⚔️ Blizzard Armory</a>
          <a class="armory-btn" href="${data.armoryUrls.ironforge}" target="_blank" rel="noopener">🛡️ Classic Armory</a>
          <a class="armory-btn" href="${data.armoryUrls.warcraftlogs}" target="_blank" rel="noopener">📜 Warcraft Logs</a>
        </div>
      </div>

      <div class="dossier-grid">
        <div class="dossier-stat">
          <div style="font-size:0.7rem; color:#94a3b8;">KILLS</div>
          <div style="font-size:1.2rem; font-weight:800; color:#10b981;">${stats.kills || 0}</div>
        </div>
        <div class="dossier-stat">
          <div style="font-size:0.7rem; color:#94a3b8;">DEATHS</div>
          <div style="font-size:1.2rem; font-weight:800; color:#ef4444;">${stats.deaths || 0}</div>
        </div>
        <div class="dossier-stat">
          <div style="font-size:0.7rem; color:#94a3b8;">K/D RATIO</div>
          <div style="font-size:1.2rem; font-weight:800; color:var(--accent-gold);">${stats.kd || 0}</div>
        </div>
        <div class="dossier-stat">
          <div style="font-size:0.7rem; color:#94a3b8;">SOLO KILLS</div>
          <div style="font-size:1.2rem; font-weight:800; color:#00e5ff;">${stats.soloKills || 0}</div>
        </div>
        <div class="dossier-stat">
          <div style="font-size:0.7rem; color:#94a3b8;">DUEL WINS</div>
          <div style="font-size:1.2rem; font-weight:800; color:#ffd700;">${stats.duelKills || 0}</div>
        </div>
        <div class="dossier-stat">
          <div style="font-size:0.7rem; color:#94a3b8;">BG KILLS</div>
          <div style="font-size:1.2rem; font-weight:800; color:#3b82f6;">${stats.bgKills || 0}</div>
        </div>
        <div class="dossier-stat">
          <div style="font-size:0.7rem; color:#94a3b8;">TOTAL DAMAGE</div>
          <div style="font-size:1.2rem; font-weight:800; color:#f97316;">${formatNumber(stats.totalDamage || 0)}</div>
        </div>
        <div class="dossier-stat">
          <div style="font-size:0.7rem; color:#94a3b8;">TOTAL HEALING</div>
          <div style="font-size:1.2rem; font-weight:800; color:#10b981;">${formatNumber(stats.totalHealing || 0)}</div>
        </div>
      </div>

      ${historyHtml}
      ${killsHtml}
      ${deathsHtml}
    `;
  } catch (err) {
    body.innerHTML = `<div style="text-align:center; padding:30px; color:#ef4444;">Error retrieving character profile: ${err.message}</div>`;
  }
}

function closeCharacterModal() {
  document.getElementById("character-modal").style.display = "none";
}

// Guild Profile Modal Handlers
async function openGuildProfile(guildName) {
  const modal = document.getElementById("guild-modal");
  const body = document.getElementById("guild-modal-body");
  const title = document.getElementById("guild-modal-title");
  if (!modal || !body) return;

  title.innerText = `Guild Intelligence: <${guildName}>`;
  body.innerHTML = `<div style="text-align:center; padding:30px; color:#94a3b8;">Compiling war telemetry for <${guildName}>...</div>`;
  modal.style.display = "flex";

  try {
    const res = await fetch(`/api/guild/${encodeURIComponent(guildName)}`);
    if (!res.ok) {
      body.innerHTML = `<div style="text-align:center; padding:30px; color:#ef4444;">Guild telemetry record not found.</div>`;
      return;
    }
    const data = await res.json();
    const factionColor = data.faction === 'Alliance' ? '#3b82f6' : (data.faction === 'Horde' ? '#ef4444' : '#94a3b8');

    let rosterHtml = "";
    if (data.members && data.members.length > 0) {
      rosterHtml = `
        <div style="margin-top:12px;">
          <h4 style="color:var(--accent-cyan); font-size:0.9rem; margin-bottom:8px;">Active War Roster (${data.members.length})</h4>
          <div style="background:#07090e; border:1px solid #1e293b; border-radius:6px; overflow:hidden;">
            <table style="width:100%; border-collapse:collapse; font-size:0.8rem;">
              <thead>
                <tr style="border-bottom:1px solid #1e293b; color:#94a3b8; text-align:left; height:28px;">
                  <th style="padding-left:12px;">Member</th>
                  <th>Level</th>
                  <th>Kills</th>
                  <th>Solo Kills</th>
                  <th style="padding-right:12px; text-align:right;">Last Seen</th>
                </tr>
              </thead>
              <tbody>
                ${data.members.map(m => `
                  <tr style="border-bottom:1px solid rgba(255,255,255,0.04); height:32px;">
                    <td style="padding-left:12px;"><span class="clickable-player" onclick="openCharacterProfile('${m.name}')">${colorizeClass(m.name, m.class)}</span></td>
                    <td style="color:#94a3b8;">${m.level || 60}</td>
                    <td style="color:#10b981; font-weight:700;">${m.kills}</td>
                    <td style="color:#00e5ff; font-weight:700;">${m.solo_kills || 0}</td>
                    <td style="padding-right:12px; text-align:right; color:#64748b;">${m.last_seen ? timeAgo(m.last_seen) : 'Recent'}</td>
                  </tr>
                `).join("")}
              </tbody>
            </table>
          </div>
        </div>
      `;
    }

    let killsHtml = "";
    if (data.recentKills && data.recentKills.length > 0) {
      killsHtml = `
        <div style="margin-top:12px;">
          <h4 style="color:#10b981; font-size:0.9rem; margin-bottom:8px;">Recent Guild Victories (${data.recentKills.length})</h4>
          <div style="display:flex; flex-direction:column; gap:4px; max-height:160px; overflow-y:auto;">
            ${data.recentKills.map(k => `
              <div style="display:flex; justify-content:space-between; align-items:center; background:#07090e; padding:6px 10px; border-radius:4px; font-size:0.75rem; border:1px solid #1e293b;">
                <div>
                  <span class="clickable-player" onclick="openCharacterProfile('${k.killer_name}')">${colorizeClass(k.killer_name, k.killer_class)}</span>
                  slayed
                  <span class="clickable-player" onclick="openCharacterProfile('${k.victim_name}')">${colorizeClass(k.victim_name, k.victim_class)}</span>
                  ${k.victim_guild && k.victim_guild !== 'None' ? `<span class="clickable-guild" onclick="openGuildProfile('${k.victim_guild}')">&lt;${k.victim_guild}&gt;</span>` : ''}
                </div>
                <div style="text-align:right; color:#94a3b8;">
                  <span>${k.zone}</span> &bull; <span>${timeAgo(k.timestamp)}</span>
                </div>
              </div>
            `).join("")}
          </div>
        </div>
      `;
    }

    body.innerHTML = `
      <div style="display:flex; justify-content:space-between; align-items:center; background:#07090e; padding:16px; border-radius:8px; border:1px solid #1e293b;">
        <div>
          <div style="font-size:1.4rem; font-weight:800; color:var(--accent-gold);">&lt;${data.guild}&gt;</div>
          <div style="font-size:0.85rem; color:#94a3b8; margin-top:2px;">
            Faction: <strong style="color:${factionColor};">${data.faction}</strong> &bull; Active Combatants: <strong style="color:#fff;">${data.memberCount}</strong>
          </div>
        </div>
      </div>

      <div class="dossier-grid">
        <div class="dossier-stat">
          <div style="font-size:0.7rem; color:#94a3b8;">TOTAL GUILD KILLS</div>
          <div style="font-size:1.3rem; font-weight:800; color:#10b981;">${data.kills}</div>
        </div>
        <div class="dossier-stat">
          <div style="font-size:0.7rem; color:#94a3b8;">TOTAL LOSSES</div>
          <div style="font-size:1.3rem; font-weight:800; color:#ef4444;">${data.deaths}</div>
        </div>
        <div class="dossier-stat">
          <div style="font-size:0.7rem; color:#94a3b8;">K/D RATIO</div>
          <div style="font-size:1.3rem; font-weight:800; color:var(--accent-gold);">${data.kd}</div>
        </div>
        <div class="dossier-stat">
          <div style="font-size:0.7rem; color:#94a3b8;">SOLO KILLS</div>
          <div style="font-size:1.3rem; font-weight:800; color:#00e5ff;">${data.soloKills}</div>
        </div>
      </div>

      ${rosterHtml}
      ${killsHtml}
    `;
  } catch (err) {
    body.innerHTML = `<div style="text-align:center; padding:30px; color:#ef4444;">Error retrieving guild profile: ${err.message}</div>`;
  }
}

function closeGuildModal() {
  document.getElementById("guild-modal").style.display = "none";
}

// Guild Leaderboard Tab
async function loadGuildsView() {
  const container = document.getElementById("main-content-area");
  container.innerHTML = `<div style="text-align:center; padding:40px; color:#94a3b8;">Gathering guild war rankings...</div>`;

  try {
    const res = await fetch("/api/guilds");
    const data = await res.json();
    const guilds = data.guilds || [];

    if (guilds.length === 0) {
      container.innerHTML = `
        <div style="text-align:center; padding:40px; color:#64748b;">
          <h3>No Guild PvP telemetry recorded yet.</h3>
          <p style="margin-top:8px;">Engage in combat while wearing a guild tabard to populate the rankings.</p>
        </div>
      `;
      return;
    }

    let html = `
      <div style="display:flex; flex-direction:column; gap:20px;">
        <h2 style="font-size: 1.2rem; color: var(--accent-gold);">Realm Guild War Leaderboards</h2>
        <div style="background-color: var(--bg-card); border: 1px solid var(--border-color); border-radius: 8px; padding: 16px;">
          <table style="width: 100%; border-collapse: collapse; font-size: 0.85rem;">
            <thead>
              <tr style="border-bottom: 1px solid var(--border-color); color: #94a3b8; text-align: left; height: 32px;">
                <th>Rank</th>
                <th>Guild</th>
                <th>Faction</th>
                <th>Combatants</th>
                <th>Kills</th>
                <th>Deaths</th>
                <th>K/D</th>
                <th>Top Assassin</th>
              </tr>
            </thead>
            <tbody>
    `;

    guilds.forEach((g, idx) => {
      const topMemberHtml = g.topMember 
        ? `<span class="clickable-player" onclick="openCharacterProfile('${g.topMember.name}')">${colorizeClass(g.topMember.name, g.topMember.class)}</span> <small style="color:#10b981;">(${g.topMember.kills}k)</small>`
        : '-';

      html += `
        <tr style="border-bottom: 1px solid rgba(255,255,255,0.05); height: 38px;">
          <td style="color: var(--accent-gold); font-weight: 800;">#${idx + 1}</td>
          <td><span class="clickable-guild" onclick="openGuildProfile('${g.guild}')">&lt;${g.guild}&gt;</span></td>
          <td style="color: ${g.faction === 'Alliance' ? '#3b82f6' : '#ef4444'};">${g.faction || 'Neutral'}</td>
          <td style="color: #e2e8f0;">${g.members_count || 1}</td>
          <td style="color: #10b981; font-weight: 700;">${g.kills}</td>
          <td style="color: #ef4444; font-weight: 700;">${g.deaths || 0}</td>
          <td style="color: var(--accent-gold); font-weight: 700;">${g.kd}</td>
          <td>${topMemberHtml}</td>
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
  } catch (err) {
    container.innerHTML = `<div style="text-align:center; padding:40px; color:#ef4444;">Failed to load guild leaderboards: ${err.message}</div>`;
  }
}

// Tab Switching
function switchTab(tab) {
  currentTab = tab;
  document.querySelectorAll(".nav-btn").forEach(b => b.classList.remove("active"));
  const activeBtn = document.getElementById(`nav-${tab.toLowerCase()}`);
  if (activeBtn) activeBtn.classList.add("active");

  const mwSection = document.getElementById("most-wanted-section");
  if (mwSection) mwSection.style.display = (tab === "FEED") ? "block" : "none";

  if (tab === "FEED") {
    loadKills();
    loadMostWanted();
  }
  else if (tab === "LEADERBOARDS") loadLeaderboards();
  else if (tab === "GUILDS") loadGuildsView();
  else if (tab === "DEFENSE") loadDefenseView();
  else if (tab === "BG_METRICS") loadBgGladiators();
  else if (tab === "BOUNTIES") loadBounties();
  else if (tab === "INFO") loadInfoView();
}

function openInfoPage(subpage) {
  switchTab("INFO");
  loadInfoView(subpage);
}

function loadInfoView(subpage = "about") {
  const container = document.getElementById("main-content-area");
  if (!container) return;

  const tabs = [
    { id: "about", label: "📖 About" },
    { id: "features", label: "⚡ Features" },
    { id: "faq", label: "❓ FAQ" },
    { id: "delayed", label: "⏱️ Delayed Intel" },
    { id: "payments", label: "⭐ Supporter Perks" },
    { id: "streambox", label: "📺 StreamBox (OBS)" },
    { id: "legal", label: "⚖️ Legal & Compliance" }
  ];

  let tabsHtml = `<div class="info-nav-bar">`;
  tabs.forEach(t => {
    const activeCls = (t.id === subpage) ? "active" : "";
    tabsHtml += `<button class="info-subtab-btn ${activeCls}" onclick="loadInfoView('${t.id}')">${t.label}</button>`;
  });
  tabsHtml += `</div>`;

  let contentHtml = "";
  if (subpage === "about") {
    contentHtml = `
      <div class="info-card">
        <h1>📖 About WoW Killboard</h1>
        <p><strong>WoW Killboard</strong> is the premier open-source combat intelligence, ranking, and bounty platform for World of Warcraft PvP, engineered to mirror the analytical depth of EVE Online's legendary zKillboard.</p>

        <div class="info-callout">
          <strong>Mission &amp; Non-Profit Vision:</strong><br>
          Founded by <strong>Scott Quick</strong>, Founder &amp; Executive Director of <strong>Forged By Valor (501(c)(3))</strong>, WoW Killboard is dedicated to empowering veteran mental health, camaraderie, and suicide prevention through competitive gaming communities. 100% free of charge and 100% ad-free.
        </div>

        <h2>🛡️ The 5 Non-Negotiable Engineering Guardrails</h2>
        <ol>
          <li><strong>Zero Blizzard UI Taint:</strong> Anonymous pure Lua frames using <code>BackdropTemplate</code>, custom ESC key propagation, and strict <code>InCombatLockdown()</code> gating. Never triggers protected Blizzard UI action blocked popups.</li>
          <li><strong>Cross-Client Parity:</strong> Single unified codebase operating cleanly across <strong>WoW Forever Beta</strong> (<code>_classic_beta_</code>), <strong>Classic Era</strong> (<code>_classic_era_</code>), <strong>Anniversary</strong> (<code>_anniversary_</code>), and <strong>Modern Retail</strong> (<code>_retail_</code>).</li>
          <li><strong>Zero Documentation Drift:</strong> Code and documentation are twin artifacts. Every commit updates semantic changelogs and architectural specifications.</li>
          <li><strong>Telemetry-First &amp; Cryptographic Determinism:</strong> Every combat engagement generates a deterministic 32-bit FNV-1a hash Kill ID based on timestamp, participant GUIDs, and map coordinates for zero-duplicate distributed ingestion.</li>
          <li><strong>Zero-Barrier Player UX:</strong> Desktop ingestion runs via a single self-contained binary (<code>WoWKillboardSync.exe</code>) with automated multi-drive auto-discovery across <code>C:</code>, <code>D:</code>, and <code>E:</code> drives. No Python or terminal required.</li>
        </ol>

        <h2>🏛️ Technology Stack</h2>
        <ul>
          <li><strong>In-Game Client:</strong> Pure Lua 5.1 / World of Warcraft Addon Engine with Classic &amp; ElvUI theme parity.</li>
          <li><strong>Sync Pipeline:</strong> Standalone Python 3.12 / PyInstaller multi-threaded SavedVariables directory watcher.</li>
          <li><strong>Backend Engine:</strong> Python Flask REST API with SQLite WAL journal mode and FNV-1a hash indexing.</li>
          <li><strong>Web Platform:</strong> High-performance, zero-framework CSS Grid / Vanilla JavaScript client.</li>
        </ul>
      </div>
    `;
  } else if (subpage === "features") {
    contentHtml = `
      <div class="info-card">
        <h1>⚡ Comprehensive Feature Matrix</h1>
        <p>Explore the full suite of combat analytics, tournament-grade dueling, battleground metrics, and outlaw contracts built into WoW Killboard.</p>

        <h2>⚔️ Core Combat Intelligence</h2>
        <ul>
          <li><strong>Deterministic Killmail Generation:</strong> Microsecond combat log parsing via <code>COMBAT_LOG_EVENT_UNFILTERED</code> with full damage, healing, and overkill calculations.</li>
          <li><strong>Solo vs. Gang Temporal Clustering:</strong> 15-second sliding temporal window strictly distinguishes certified 1v1 solo triumphs from group gang ganks.</li>
          <li><strong>Clickable Character Combat Dossiers:</strong> Interactive modals displaying lifetime kills, deaths, K/D, solo kills, and recent combat histories.</li>
          <li><strong>Everywhere-Clickable Armory Links:</strong> 1-click external intelligence links to the Official Blizzard Armory, Ironforge.pro (Classic), and Warcraft Logs.</li>
        </ul>

        <h2>🏆 Dueling &amp; Battleground Gladiators</h2>
        <ul>
          <li><strong>1v1 Duel Match Engine:</strong> Hooks into system duel messages to track knockouts, forfeits ("fled"), and duel win/loss records.</li>
          <li><strong>Battleground Scoreboards:</strong> Damage done, healing done, and objective caps tracked in Warsong Gulch, Arathi Basin, and Alterac Valley.</li>
          <li><strong>5-Way Multi-Mode Filtering:</strong> Instant switching between <code>ALL</code>, <code>WORLD</code>, <code>BG</code>, <code>ARENA</code>, and <code>DUEL</code> telemetry.</li>
        </ul>

        <h2>🎯 Bounty Contracts &amp; Oathbreaker Debt Ledger</h2>
        <ul>
          <li><strong>In-Game Post-Death Bounty Prompt:</strong> Safe prompt outside combat lockdown asking players if they wish to place a bounty upon falling to an enemy.</li>
          <li><strong>Anti-Name Change Evasion:</strong> Contracts bound to immutable character <code>Player-GUID</code>. Renaming character in Blizzard shop preserves active debt contracts.</li>
          <li><strong>Contract Acceptance &amp; Killing Blow Exclusivity:</strong> Only hunters who accept the contract and land the certified killing blow collect the gold.</li>
          <li><strong>Cold Cases Archival:</strong> Uncollected bounties > 30 days automatically archive to prevent backlog clutter.</li>
          <li><strong>Proximity Wanted Debtor Radar:</strong> In-game audio sirens (SoundKit 8959) and visual alerts trigger when an Oathbreaker debtor is nearby.</li>
        </ul>
      </div>
    `;
  } else if (subpage === "faq") {
    contentHtml = `
      <div class="info-card">
        <h1>❓ Frequently Asked Questions</h1>

        <h2>General &amp; Installation</h2>
        <h3>How do I install the addon?</h3>
        <p>Extract <code>WoWKillboard-v1.0.0.zip</code> into your World of Warcraft <code>Interface/AddOns/</code> directory. Run <code>WoWKillboardSync.exe</code> in the background to automatically synchronize your combat logs to the web killboard.</p>

        <h3>Do I need to install Python or use the command line?</h3>
        <p>No. <code>WoWKillboardSync.exe</code> is a self-contained zero-Python Windows binary with automated drive scanning across C:, D:, and E: drives.</p>

        <h2>Combat &amp; Scoring</h2>
        <h3>Why didn't my kill register as a Solo Kill?</h3>
        <p>If another player damaged or debuffed the victim within 15 seconds prior to death, our temporal clustering algorithm classifies the kill as a <strong>Gang</strong> kill to protect competitive integrity.</p>

        <h3>Why did a kill not appear on the board?</h3>
        <p>Kills against "grey" trivial low-level characters or honorless targets are filtered out to prevent grief-farming from polluting realm leaderboards.</p>

        <h2>Bounties &amp; Contracts</h2>
        <h3>Can players without the addon claim bounties?</h3>
        <p>No. Bounties require active contract acceptance. Only an addon hunter who accepted the contract and landed the certified killing blow can collect the bounty gold.</p>

        <h3>Can a bounty target avoid their bounty by changing character names?</h3>
        <p>No. All contracts and debts are permanently bound to the character's internal <code>Player-XXXX-XXXXXXXX</code> GUID. When a player renames, their existing bounty contracts immediately update to their new name.</p>

        <h3>What happens if a bounty goes unclaimed for a long time?</h3>
        <p>Bounties active for over 30 days are automatically archived into the <strong>Cold Cases</strong> register.</p>
      </div>
    `;
  } else if (subpage === "delayed") {
    contentHtml = `
      <div class="info-card">
        <h1>⏱️ Delayed Combat Telemetry &amp; OpSec</h1>
        <p>In competitive PvP, real-time spatial coordinates can inadvertently enable stream-sniping, flight-path camping, and unfair griefing. WoW Killboard implements strict vicinity telemetry delays to safeguard operational security (OpSec).</p>

        <h2>🔒 The Telemetry Gating Framework</h2>
        <ul>
          <li><strong>Public / Free Tier:</strong> Displays confirmed combat <strong>Zone</strong> only with temporal delay (e.g. <code>Last Sighted: Stranglethorn Vale ~14m ago</code>). Exact subzone landmarks and micro-coordinates are masked.</li>
          <li><strong>Supporter Perk (Subzone Recon Intel):</strong> Quality-of-life benefit unlocking exact subzone telemetry (e.g. <code>Booty Bay</code>) for community donors supporting <strong>Forged By Valor (501(c)(3))</strong>.</li>
          <li><strong>Anti-Camping Offset:</strong> In-game killmail broadcasting does not leak real-time player GPS coordinates to public chat channels.</li>
        </ul>

        <div class="info-callout">
          <strong>Cold Cases Archival:</strong><br>
          To maintain active board responsiveness, bounty contracts remaining uncollected for more than 30 days transition from <code>ACTIVE</code> to <code>COLD_CASE</code> status.
        </div>
      </div>
    `;
  } else if (subpage === "payments") {
    contentHtml = `
      <div class="info-card">
        <h1>⭐ Supporter Perks &amp; 100% Ad-Free Experience</h1>
        <p>WoW Killboard operates under a strict <strong>100% Ad-Free Guarantee</strong>. We display zero commercial advertisements, popups, or user-tracking scripts.</p>

        <div class="info-callout" style="border-left-color: var(--accent-gold);">
          <strong>🎖️ Forged By Valor (501(c)(3)) Community Support:</strong><br>
          WoW Killboard is built and maintained as a non-profit technology project. All financial contributions directly fund realm server infrastructure and Forged By Valor's charitable veteran mental health initiatives.
        </div>

        <h2>🌟 Supporter Perks &amp; Recognition</h2>
        <ul>
          <li><strong>⭐ Subzone Recon Intel:</strong> Unlocks exact landmark subzone coordinates across active bounty contracts.</li>
          <li><strong>👑 Golden Champion Crest:</strong> Supporter badges and shiny cosmetic glows rendered on character dossiers.</li>
          <li><strong>🎯 Killmail Sponsorship:</strong> Sponsor epic world PvP battles to pin them to the top of realm highlights.</li>
          <li><strong>100% Tax-Deductible:</strong> Donations to Forged By Valor are fully deductible under IRS Section 501(c)(3).</li>
        </ul>
      </div>
    `;
  } else if (subpage === "streambox") {
    contentHtml = `
      <div class="info-card">
        <h1>📺 StreamBox — Live OBS Streamer Overlay</h1>
        <p>Inspired by zKillboard's popular streamer tool, <strong>StreamBox</strong> is a lightweight, zero-configuration HUD overlay built specifically for Twitch and YouTube World of Warcraft PvP streamers.</p>

        <div class="streambox-generator">
          <h3 style="color:var(--accent-cyan); margin-bottom:6px;">🚀 Quick StreamBox URL Builder</h3>
          <p style="font-size:0.8rem; color:#94a3b8;">Enter your character name to generate an instant OBS Studio Browser Source URL:</p>
          <div class="streambox-input-group">
            <input type="text" id="sb-input-char" class="search-input" placeholder="Character Name (e.g. Hawkeye)" style="max-width:240px;">
            <button class="nav-btn active" onclick="generateStreamBoxUrl()">Generate OBS URL</button>
          </div>
          <div id="sb-url-result" style="margin-top:10px; font-size:0.8rem; display:none;">
            <span style="color:#10b981; font-weight:700;">OBS Browser Source URL:</span><br>
            <code id="sb-url-text" style="background:#000; padding:4px 8px; border-radius:4px; border:1px solid #334155; display:inline-block; margin-top:4px; color:var(--accent-cyan);"></code>
            <button class="nav-btn" style="padding:4px 8px; font-size:0.75rem; margin-left:8px;" onclick="copyStreamBoxUrl()">📋 Copy</button>
          </div>
        </div>

        <h2>⚙️ How to Add to OBS Studio or Streamlabs</h2>
        <ol>
          <li>In OBS Studio, click <strong>+ (Add Source)</strong> in your Sources dock.</li>
          <li>Select <strong>Browser</strong>.</li>
          <li>Paste your StreamBox URL (e.g. <code>http://localhost:8080/streambox/YourCharacterName</code>).</li>
          <li>Set Width: <strong>800</strong>, Height: <strong>140</strong> (or Width: <strong>320</strong>, Height: <strong>480</strong> for vertical with <code>?vertical=1</code>).</li>
          <li>Check <strong>"Shutdown source when not visible"</strong> and click OK.</li>
        </ol>

        <h2>💡 StreamBox Features</h2>
        <ul>
          <li><strong>Transparent HUD:</strong> Blends cleanly into any game stream layout with sleek glassmorphism cards.</li>
          <li><strong>Automatic Live Updates:</strong> Polls every 5 seconds to display your latest kills, deaths, and K/D ratio without requiring any interaction.</li>
          <li><strong>Solo &amp; Gang Badges:</strong> Distinguishes certified 1v1 solo kills from group skirmishes.</li>
        </ul>
      </div>
    `;
  } else if (subpage === "legal") {
    contentHtml = `
      <div class="info-card">
        <h1>⚖️ Legal, Copyright &amp; Blizzard Policy Compliance</h1>

        <h2>Blizzard Entertainment Trademark &amp; IP Notice</h2>
        <p>World of Warcraft®, Warcraft®, and Blizzard Entertainment® are trademarks or registered trademarks of Blizzard Entertainment, Inc. in the U.S. and/or other countries.</p>
        <p>WoW Killboard is an independent open-source combat analysis tool created by <strong>Scott Quick</strong> and supported by <strong>Forged By Valor (501(c)(3))</strong>. It is not affiliated with, endorsed, sponsored, or specifically approved by Blizzard Entertainment, Inc. Blizzard Entertainment is not responsible for the content or operation of this software.</p>

        <h2>Strict Compliance with Blizzard's UI Add-On Development Policy</h2>
        <ul>
          <li><strong>100% Free of Charge:</strong> The addon and web platform are free for all players. We charge zero subscription fees, paywalls, or fees to download or use the software.</li>
          <li><strong>Zero In-Game Commercial Advertising:</strong> The addon displays zero third-party commercial advertisements, popups, or marketing inside the World of Warcraft client.</li>
          <li><strong>Non-Obfuscated Open Source Code:</strong> All addon Lua code and web backend code are 100% human-readable and licensed under the <strong>AGPLv3</strong> open-source license.</li>
          <li><strong>Zero Game Automation (No Taint):</strong> The addon never automates gameplay, triggers protected spells, or circumvents game mechanics. It strictly observes public combat log events.</li>
        </ul>

        <h2>Privacy &amp; Data Protection</h2>
        <ul>
          <li><strong>Zero Personally Identifiable Information (PII):</strong> We never collect, store, or transmit real names, email addresses, IP addresses, or Blizzard Battle.net account credentials.</li>
          <li><strong>Public Telemetry Only:</strong> The software exclusively records publicly broadcast combat log event strings (character names, combat damage, zone names) generated during gameplay.</li>
        </ul>
      </div>
    `;
  }

  container.innerHTML = `
    <div class="info-hub">
      ${tabsHtml}
      ${contentHtml}
    </div>
  `;
}

function generateStreamBoxUrl() {
  const charInput = document.getElementById("sb-input-char");
  if (!charInput || !charInput.value.trim()) {
    alert("Please enter a character name.");
    return;
  }
  const name = charInput.value.trim();
  const url = `${window.location.origin}/streambox/${encodeURIComponent(name)}`;
  const resEl = document.getElementById("sb-url-result");
  const textEl = document.getElementById("sb-url-text");
  if (resEl && textEl) {
    textEl.innerText = url;
    resEl.style.display = "block";
  }
}

function copyStreamBoxUrl() {
  const textEl = document.getElementById("sb-url-text");
  if (!textEl) return;
  navigator.clipboard.writeText(textEl.innerText).then(() => {
    alert("StreamBox OBS URL copied to clipboard!");
  });
}

// ----------------- Guild Defense, SOS Beacons & Discord -----------------

async function loadDefenseView() {
  const container = document.getElementById("main-content-area");
  if (!container) return;
  container.innerHTML = `<div style="text-align:center; padding:40px; color:#94a3b8;">Scanning tactical defense frequencies and guild operations...</div>`;

  try {
    const [distressRes, eventsRes, cfgRes] = await Promise.all([
      fetch("/api/backup/distress"),
      fetch("/api/events"),
      fetch("/api/discord/config")
    ]);
    const beacons = await distressRes.json();
    const events = await eventsRes.json();
    const discordCfg = await cfgRes.json();

    // 1. Distress Beacons HTML
    let beaconsHtml = "";
    if (!beacons || beacons.length === 0) {
      beaconsHtml = `
        <div style="background:#07090e; border:1px solid #1e293b; border-radius:8px; padding:24px; text-align:center; color:#64748b;">
          <div style="font-size:1.5rem; margin-bottom:8px;">🛡️</div>
          <div style="color:#10b981; font-weight:700; font-size:1rem;">All Defense Sectors Secure</div>
          <p style="font-size:0.8rem; margin-top:4px;">No active distress beacons. Guildmates under attack can trigger Call for Backup in-game via <code>/kb backup</code>, <code>/kbsos</code>, or the header button.</p>
        </div>
      `;
    } else {
      beaconsHtml = `
        <div class="distress-grid">
          ${beacons.map(b => {
            const classColor = CLASS_COLORS[(b.character_class || "").toUpperCase()] || CLASS_COLORS.UNKNOWN;
            return `
              <div class="distress-beacon-card">
                <div class="distress-header">
                  <div class="distress-badge">
                    <span class="distress-dot"></span> CALL FOR BACKUP
                  </div>
                  <span style="font-size:0.75rem; color:#94a3b8;">${timeAgo(b.timestamp)}</span>
                </div>
                <div class="distress-body">
                  <div style="font-size:1.1rem; font-weight:800;">
                    <span style="color:${classColor};" class="clickable-player" onclick="openCharacterProfile('${b.character_name}')">${b.character_name}</span>
                    <span style="font-size:0.8rem; color:#94a3b8; font-weight:normal;">(Lvl ${b.character_level} ${b.character_class})</span>
                  </div>
                  <div>
                    Guild: <strong style="color:var(--accent-gold);">${b.guild_name && b.guild_name !== 'None' ? '&lt;' + b.guild_name + '&gt;' : 'Unaligned'}</strong>
                    &bull; Faction: <span style="color:${b.faction === 'Alliance' ? '#3b82f6' : '#ef4444'}; font-weight:700;">${b.faction}</span>
                  </div>
                  <div>
                    📍 Location: <strong style="color:#fff;">${b.zone}</strong> ${b.subzone ? '(' + b.subzone + ')' : ''}
                    <code style="color:var(--accent-cyan); font-size:0.75rem; margin-left:4px;">(${b.coord_x.toFixed(1)}, ${b.coord_y.toFixed(1)})</code>
                  </div>
                  <div class="distress-threat">
                    <span style="color:#f87171; font-weight:700;">⚠️ Threat Level: ${b.hostile_count} Hostile(s)</span><br>
                    <span style="color:#e2e8f0; font-size:0.75rem;">${b.hostile_names}</span>
                  </div>
                </div>
                <div class="distress-actions">
                  <button class="nav-btn active" style="flex:1; font-size:0.75rem; padding:6px 10px; background:var(--accent-cyan); color:#000; font-weight:700;" onclick="copyWhisperCommand('${b.character_name}')">
                    📋 Whisper Auto-Invite
                  </button>
                  <button class="nav-btn" style="font-size:0.75rem; padding:6px 10px;" onclick="resolveDistressBeacon('${b.id}')">
                    ✅ Clear
                  </button>
                </div>
              </div>
            `;
          }).join('')}
        </div>
      `;
    }

    // 2. Guild Events HTML
    let eventsHtml = "";
    if (!events || events.length === 0) {
      eventsHtml = `
        <div style="background:#07090e; border:1px solid #1e293b; border-radius:8px; padding:20px; text-align:center; color:#64748b;">
          <p>No upcoming guild rallies or defense operations scheduled.</p>
        </div>
      `;
    } else {
      eventsHtml = `
        <div class="events-grid">
          ${events.map(e => `
            <div class="event-card">
              <div class="event-card-header">
                <div>
                  <h3 style="color:var(--accent-cyan); font-size:1rem; margin-bottom:2px;">${e.title}</h3>
                  <div style="font-size:0.75rem; color:#94a3b8;">
                    Guild: <strong style="color:var(--accent-gold);">&lt;${e.guild_name}&gt;</strong> &bull; Lead: <strong>${e.creator_name}</strong>
                  </div>
                </div>
                <span style="font-size:0.7rem; background:rgba(0,229,255,0.15); color:var(--accent-cyan); border:1px solid var(--accent-cyan); padding:2px 6px; border-radius:4px; font-weight:700;">
                  ${e.time_str}
                </span>
              </div>
              <p style="font-size:0.8rem; color:#cbd5e1; margin:8px 0;">${e.description}</p>
              <div style="font-size:0.75rem; color:#94a3b8; display:flex; justify-content:space-between; align-items:center; border-top:1px solid #1e293b; padding-top:8px; margin-top:8px;">
                <span>📍 Rally Zone: <strong style="color:#fff;">${e.zone}</strong></span>
                <button class="nav-btn" style="font-size:0.7rem; padding:2px 8px;" onclick="copyWhisperCommand('${e.creator_name}', 'invite')">
                  Join / Whisper
                </button>
              </div>
            </div>
          `).join('')}
        </div>
      `;
    }

    // 3. Discord Gateway HTML
    const isConfigured = discordCfg && discordCfg.configured;
    const discordHtml = `
      <div class="discord-config-card">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px;">
          <div style="display:flex; align-items:center; gap:8px;">
            <span class="discord-badge">DISCORD INTEGRATION</span>
            <span style="font-size:1rem; font-weight:700; color:#fff;">Guild Announcement &amp; Distress Gateway</span>
          </div>
          <span style="font-size:0.75rem; color:${isConfigured ? '#10b981' : '#f59e0b'}; font-weight:700;">
            ${isConfigured ? '● GATEWAY ACTIVE (' + discordCfg.masked_url + ')' : '○ NOT CONFIGURED'}
          </span>
        </div>
        <p style="font-size:0.8rem; color:#94a3b8; margin-bottom:12px;">
          Automatically forward in-game <strong>Call for Backup (SOS)</strong> beacons and <strong>Guild Rally Announcements</strong> to your guild's Discord channel via Webhook.
        </p>

        <div style="display:grid; grid-template-columns: 2fr 1fr; gap:12px; margin-bottom:12px;">
          <div>
            <label style="font-size:0.75rem; color:#94a3b8; display:block; margin-bottom:4px;">Discord Channel Webhook URL:</label>
            <input type="text" id="discord-webhook-url" class="search-input" style="width:100%;" placeholder="https://discord.com/api/webhooks/..." value="">
          </div>
          <div>
            <label style="font-size:0.75rem; color:#94a3b8; display:block; margin-bottom:4px;">Target Guild Tag / Scope:</label>
            <input type="text" id="discord-guild-name" class="search-input" style="width:100%;" placeholder="e.g. Forged By Valor or default" value="${discordCfg && discordCfg.guild_name ? discordCfg.guild_name : 'default'}">
          </div>
        </div>

        <div style="display:flex; justify-content:space-between; align-items:center;">
          <div style="display:flex; gap:16px; font-size:0.8rem; color:#cbd5e1;">
            <label><input type="checkbox" id="discord-chk-alerts" checked> Broadcast Distress Beacons (SOS)</label>
            <label><input type="checkbox" id="discord-chk-events" checked> Broadcast Guild Rallies &amp; Events</label>
          </div>
          <div style="display:flex; gap:8px;">
            <button class="nav-btn" onclick="testDiscordWebhook()">🔔 Test Ping</button>
            <button class="nav-btn active" style="background:#5865f2; color:#fff; border-color:#5865f2;" onclick="saveDiscordConfig()">💾 Save Webhook</button>
          </div>
        </div>
      </div>
    `;

    container.innerHTML = `
      <div style="display: flex; flex-direction: column; gap: 24px;">
        <!-- Top Section: Active SOS Calls -->
        <div>
          <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px;">
            <div>
              <h2 style="font-size: 1.2rem; color: #f87171; display:flex; align-items:center; gap:8px;">
                <span>🚨</span> Real-Time Distress Beacons (Call for Backup)
              </h2>
              <div style="font-size:0.75rem; color:#94a3b8; margin-top:2px;">Live SOS signals dispatched from in-game combat. Whisper players for auto-invite.</div>
            </div>
            <button class="nav-btn" style="border-color:#ef4444; color:#f87171;" onclick="loadDefenseView()">🔄 Refresh Beacons</button>
          </div>
          ${beaconsHtml}
        </div>

        <!-- Middle Section: Guild Rallies and Events -->
        <div>
          <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px;">
            <div>
              <h2 style="font-size: 1.2rem; color: var(--accent-cyan); display:flex; align-items:center; gap:8px;">
                <span>⚔️</span> Guild Defense Operations &amp; Rallies
              </h2>
              <div style="font-size:0.75rem; color:#94a3b8; margin-top:2px;">Coordinated guild strikes, zone defense, and bounty manhunts.</div>
            </div>
            <button class="supporter-btn" onclick="openEventModal()">➕ Schedule Guild Event</button>
          </div>
          ${eventsHtml}
        </div>

        <!-- Bottom Section: Discord Integration -->
        ${discordHtml}
      </div>
    `;
  } catch (err) {
    container.innerHTML = `<div style="text-align:center; padding:40px; color:#ef4444;">Failed to load defense platform: ${err.message}</div>`;
  }
}

function copyWhisperCommand(playerName, keyword = "backup") {
  const cmd = `/w ${playerName} ${keyword}`;
  navigator.clipboard.writeText(cmd).then(() => {
    alert(`Copied in-game command: "${cmd}"\nPaste into World of Warcraft to trigger auto-invite!`);
  });
}

async function resolveDistressBeacon(beaconId) {
  try {
    const res = await fetch(`/api/backup/resolve/${encodeURIComponent(beaconId)}`, { method: "POST" });
    if (res.ok) {
      alert("Distress beacon marked as RESOLVED.");
      loadDefenseView();
      checkGlobalSosBeacons();
    }
  } catch (e) {
    console.error("Failed to resolve beacon:", e);
  }
}

function openEventModal() {
  const modal = document.getElementById("event-modal");
  if (modal) modal.style.display = "flex";
}

function closeEventModal() {
  const modal = document.getElementById("event-modal");
  if (modal) modal.style.display = "none";
}

async function submitGuildEvent() {
  const title = document.getElementById("event-input-title")?.value.trim();
  const zone = document.getElementById("event-input-zone")?.value.trim();
  const timeStr = document.getElementById("event-input-time")?.value.trim() || "NOW";
  const creator = document.getElementById("event-input-creator")?.value.trim() || "Officer";
  const guild = document.getElementById("event-input-guild")?.value.trim() || "Forged By Valor";
  const desc = document.getElementById("event-input-desc")?.value.trim() || "Guild PvP Operation";

  if (!title || !zone) {
    alert("Please provide an Event Title and Rally Zone.");
    return;
  }

  try {
    const res = await fetch("/api/events", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        title, zone, time_str: timeStr, creator_name: creator, guild_name: guild, description: desc
      })
    });
    if (res.ok) {
      alert("Guild Event announced and broadcasted to Discord!");
      closeEventModal();
      loadDefenseView();
    } else {
      alert("Failed to submit event.");
    }
  } catch (e) {
    console.error("Failed to publish event:", e);
  }
}

async function saveDiscordConfig() {
  const url = document.getElementById("discord-webhook-url")?.value.trim();
  const guild = document.getElementById("discord-guild-name")?.value.trim() || "default";
  const alerts = document.getElementById("discord-chk-alerts")?.checked;
  const events = document.getElementById("discord-chk-events")?.checked;

  if (!url) {
    alert("Please enter a valid Discord Webhook URL.");
    return;
  }

  try {
    const res = await fetch("/api/discord/config", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        webhook_url: url,
        guild_name: guild,
        alerts_enabled: alerts,
        events_enabled: events
      })
    });
    if (res.ok) {
      alert("Discord Webhook configuration saved!");
      loadDefenseView();
    } else {
      alert("Failed to save Discord config.");
    }
  } catch (e) {
    console.error("Failed to save discord config:", e);
  }
}

async function testDiscordWebhook() {
  const url = document.getElementById("discord-webhook-url")?.value.trim();
  const guild = document.getElementById("discord-guild-name")?.value.trim() || "default";
  try {
    const res = await fetch("/api/discord/test", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ webhook_url: url, guild_name: guild })
    });
    const d = await res.json();
    if (res.ok) {
      alert("Test ping successfully sent to your Discord channel!");
    } else {
      alert(d.error || "Failed to send test ping.");
    }
  } catch (e) {
    alert("Error sending test webhook: " + e.message);
  }
}

async function checkGlobalSosBeacons() {
  const banner = document.getElementById("global-sos-banner");
  if (!banner) return;
  try {
    const res = await fetch("/api/backup/distress");
    if (!res.ok) return;
    const beacons = await res.json();
    if (beacons && beacons.length > 0) {
      const topB = beacons[0];
      banner.style.display = "flex";
      banner.innerHTML = `
        <div style="display:flex; align-items:center; gap:10px;">
          <span style="font-size:1.4rem;">🚨</span>
          <div>
            <div style="font-size:0.95rem; font-weight:800; color:#fff;">
              CALL FOR BACKUP: <span style="color:#f87171;">${topB.character_name}</span> is Taking Fire in ${topB.zone}!
            </div>
            <div style="font-size:0.75rem; color:#cbd5e1;">
              Engaged by ${topB.hostile_count} hostile(s) &bull; Coordinates: (${topB.coord_x.toFixed(1)}, ${topB.coord_y.toFixed(1)}) &bull; Auto-Invite is LIVE
            </div>
          </div>
        </div>
        <div style="display:flex; gap:8px;">
          <button class="nav-btn active" style="background:var(--accent-cyan); color:#000; font-weight:700; font-size:0.75rem; padding:4px 10px;" onclick="copyWhisperCommand('${topB.character_name}')">
            📋 Whisper '/w ${topB.character_name} backup'
          </button>
          <button class="nav-btn" style="font-size:0.75rem; padding:4px 10px;" onclick="switchTab('DEFENSE')">
            View Defense Hub
          </button>
        </div>
      `;
    } else {
      banner.style.display = "none";
    }
  } catch (e) {
    banner.style.display = "none";
  }
}

function setFilterMode(mode) {
  currentMode = mode;
  document.querySelectorAll(".pill-btn").forEach(b => b.classList.remove("active"));
  const activePill = document.getElementById(`pill-${mode.toLowerCase()}`);
  if (activePill) activePill.classList.add("active");

  loadKills();
  loadSidebar();
  if (currentTab === "FEED") loadMostWanted();
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
    loadMostWanted();
  });
}

// Supporter Mode & Subzone Intel Helpers
function isSupporterActive() {
  const val = localStorage.getItem("fbv_supporter");
  return val !== "0"; // Default to active (1) unless explicitly disabled (0)
}

function toggleSupporterMode() {
  const current = isSupporterActive();
  localStorage.setItem("fbv_supporter", current ? "0" : "1");
  updateSupporterButton();
  if (currentTab === "BOUNTIES") {
    loadBounties();
  }
  if (currentTab === "FEED") {
    loadMostWanted();
  }
}

function updateSupporterButton() {
  const btn = document.getElementById("supporter-toggle-btn");
  if (!btn) return;
  const active = isSupporterActive();
  if (active) {
    btn.innerText = "⭐ Supporter: ON";
    btn.style.background = "linear-gradient(135deg, #10b981 0%, #059669 100%)";
    btn.style.color = "#ffffff";
    btn.title = "Supporter Perks Active (Subzone Intel Unlocked)";
  } else {
    btn.innerText = "🔒 Unlock Subzones";
    btn.style.background = "#1e293b";
    btn.style.color = "#94a3b8";
    btn.title = "Click to activate Supporter Mode";
  }
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

  updateSupporterButton();
  loadKills();
  loadMostWanted();
  loadSidebar();
  checkGlobalSosBeacons();

  // Polling update every 6 seconds
  setInterval(() => {
    if (currentTab === "FEED") {
      loadKills();
      loadMostWanted();
    }
    loadSidebar();
    checkGlobalSosBeacons();
  }, 6000);
});
