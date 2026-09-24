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

function renderSidebar(data) {
  const topList = document.getElementById("sidebar-top-killers");
  if (!topList) return;

  let html = "";
  (data.topKillers || []).slice(0, 8).forEach((p, idx) => {
    const guildHtml = (p.guild && p.guild !== 'None')
      ? `<div style="font-size:0.7rem;"><span class="clickable-guild" onclick="openGuildProfile('${p.guild}')">&lt;${p.guild}&gt;</span></div>`
      : '';
    html += `
      <div class="leader-item">
        <div style="display:flex; align-items:center; gap:8px;">
          <span class="leader-rank">#${idx + 1}</span>
          <div>
            <span class="clickable-player" onclick="openCharacterProfile('${p.name}')">${colorizeClass(p.name, p.class)}</span>
            ${guildHtml}
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
      const lastSeen = b.lastSeen || {};
      let lastSeenHtml = "";
      if (lastSeen.hasTelemetry) {
        lastSeenHtml = `
          <div style="font-size:0.75rem; color:#38bdf8; margin-top:8px; background:#07090e; padding:6px 10px; border-radius:4px; border:1px solid #1e293b; display:flex; justify-content:space-between; align-items:center;">
            <div>
              <span style="font-weight:700;">📍 Last Sighted:</span> ${lastSeen.displayText}
              <div style="font-size:0.7rem; color:#94a3b8;">~${lastSeen.minutesAgo}m ago &bull; <span style="color:#f59e0b; font-weight:700;">(Delayed Intel)</span></div>
            </div>
            <button class="radar-btn" onclick="openHeatmapModal('${b.target_name}')">📍 Heatmap</button>
          </div>
        `;
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
            Placed by: <strong style="color:#e2e8f0;">${b.placer_name}</strong>
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

  if (tab === "FEED") loadKills();
  else if (tab === "LEADERBOARDS") loadLeaderboards();
  else if (tab === "GUILDS") loadGuildsView();
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

// Tactical Heatmap & Recon Radar Modal Handlers
let radarAnimId = null;

function closeHeatmapModal() {
  document.getElementById("heatmap-modal").style.display = "none";
  if (radarAnimId) {
    cancelAnimationFrame(radarAnimId);
    radarAnimId = null;
  }
}

async function openHeatmapModal(targetName) {
  const modal = document.getElementById("heatmap-modal");
  const body = document.getElementById("heatmap-modal-body");
  const title = document.getElementById("heatmap-modal-title");
  if (!modal || !body) return;

  title.innerText = `Tactical Intel Radar: ${targetName}`;
  body.innerHTML = `<div style="text-align:center; padding:30px; color:#94a3b8;">Scanning tactical frequency for ${targetName}...</div>`;
  modal.style.display = "flex";

  try {
    const res = await fetch(`/api/bounty/intel/${encodeURIComponent(targetName)}`);
    const data = await res.json();

    if (!data.hasTelemetry) {
      body.innerHTML = `
        <div style="text-align:center; padding:40px; color:#94a3b8;">
          <h3 style="color:#ef4444; margin-bottom:8px;">Zero Combat Telemetry</h3>
          <p>No recent engagements or GPS pings have been recorded for <strong style="color:#fff;">${targetName}</strong>.</p>
        </div>
      `;
      return;
    }

    body.innerHTML = `
      <div style="display:flex; justify-content:space-between; align-items:center; background:#07090e; padding:12px 16px; border-radius:6px; border:1px solid #1e293b; font-size:0.85rem;">
        <div>
          <div style="font-weight:800; font-size:1.1rem; color:var(--accent-red);">${data.targetName}</div>
          <div style="color:#94a3b8; font-size:0.75rem; margin-top:2px;">
            Last Sighted: <strong style="color:#38bdf8;">${data.zone}</strong> (${data.subzone})
          </div>
        </div>
        <div style="text-align:right;">
          <div style="background:rgba(245, 158, 11, 0.15); border:1px solid #f59e0b; color:#fbbf24; font-size:0.75rem; font-weight:700; padding:3px 8px; border-radius:4px; display:inline-block;">
            ⏱️ ${data.tacticalDelayMinutes}m INTEL BUFFER
          </div>
          <div style="font-size:0.7rem; color:#94a3b8; margin-top:3px;">
            Reported: ~${data.minutesAgo} mins ago &bull; Sector: ${data.coordX}%, ${data.coordY}%
          </div>
        </div>
      </div>

      <div style="position:relative; width:100%; border-radius:8px; overflow:hidden; border:1px solid #1e293b; background:#040609;">
        <canvas id="heatmap-canvas" width="700" height="380" style="display:block; width:100%; height:auto;"></canvas>
      </div>

      <div style="background:#090d14; border:1px solid #1e293b; border-radius:6px; padding:10px 14px; font-size:0.75rem; color:#94a3b8; line-height:1.4;">
        <strong style="color:var(--accent-cyan);">🛡️ Anti-Griefing & Fair Play Guarantee:</strong>
        This radar view is intentionally delayed by at least 10 minutes and fuzzed to broad zone sectors (±500m).
        Real-time coordinates and stealth detection are strictly omitted to eliminate stream-sniping and uphold 100% compliance with Blizzard UI and Fair Play policies.
      </div>
    `;

    // Render Canvas Radar
    const canvas = document.getElementById("heatmap-canvas");
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    const width = canvas.width;
    const height = canvas.height;

    let scanAngle = 0;

    function renderRadarFrame() {
      ctx.clearRect(0, 0, width, height);

      // 1. Grid Background
      ctx.strokeStyle = "rgba(0, 229, 255, 0.12)";
      ctx.lineWidth = 1;
      const step = 40;
      for (let x = 0; x < width; x += step) {
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, height);
        ctx.stroke();
      }
      for (let y = 0; y < height; y += step) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(width, y);
        ctx.stroke();
      }

      // 2. Concentric Radar Rings
      const centerX = width / 2;
      const centerY = height / 2;
      const maxRadius = Math.min(centerX, centerY) - 20;

      for (let r = 50; r <= maxRadius; r += 50) {
        ctx.beginPath();
        ctx.arc(centerX, centerY, r, 0, Math.PI * 2);
        ctx.strokeStyle = "rgba(0, 229, 255, 0.18)";
        ctx.stroke();
      }

      // Radar Crosshairs
      ctx.beginPath();
      ctx.moveTo(centerX - maxRadius, centerY);
      ctx.lineTo(centerX + maxRadius, centerY);
      ctx.moveTo(centerX, centerY - maxRadius);
      ctx.lineTo(centerX, centerY + maxRadius);
      ctx.strokeStyle = "rgba(0, 229, 255, 0.25)";
      ctx.stroke();

      // 3. Combat Heatmap Blobs (Recent Kills in Zone)
      const heatKills = data.zoneHeat || [];
      heatKills.forEach(k => {
        const kx = (k.coord_x || 50) / 100 * width;
        const ky = (k.coord_y || 50) / 100 * height;
        const grad = ctx.createRadialGradient(kx, ky, 2, kx, ky, 35);
        grad.addColorStop(0, "rgba(239, 68, 68, 0.65)");
        grad.addColorStop(0.5, "rgba(249, 115, 22, 0.35)");
        grad.addColorStop(1, "rgba(239, 68, 68, 0)");
        ctx.fillStyle = grad;
        ctx.beginPath();
        ctx.arc(kx, ky, 35, 0, Math.PI * 2);
        ctx.fill();
      });

      // 4. Target Last-Seen Sector Ping
      const targetPx = (data.coordX / 100) * width;
      const targetPy = (data.coordY / 100) * height;

      // Pulsing outer ripple ring
      const pulse = (Date.now() / 400) % 3;
      ctx.beginPath();
      ctx.arc(targetPx, targetPy, 18 + pulse * 12, 0, Math.PI * 2);
      ctx.strokeStyle = `rgba(251, 191, 36, ${Math.max(0, 0.8 - pulse * 0.25)})`;
      ctx.lineWidth = 2;
      ctx.stroke();

      // Inner target circle
      ctx.beginPath();
      ctx.arc(targetPx, targetPy, 8, 0, Math.PI * 2);
      ctx.fillStyle = "#fbbf24";
      ctx.fill();

      // Target Label
      ctx.font = "bold 11px sans-serif";
      ctx.fillStyle = "#fff";
      ctx.fillText(`${data.targetName} [SECTOR LAST SEEN]`, targetPx + 14, targetPy + 4);
      ctx.font = "10px sans-serif";
      ctx.fillStyle = "#f59e0b";
      ctx.fillText(`~${data.minutesAgo}m ago (±500m)`, targetPx + 14, targetPy + 16);

      // 5. Radar Sweep Line
      scanAngle += 0.025;
      const sweepX = centerX + Math.cos(scanAngle) * maxRadius;
      const sweepY = centerY + Math.sin(scanAngle) * maxRadius;

      ctx.beginPath();
      ctx.moveTo(centerX, centerY);
      ctx.lineTo(sweepX, sweepY);
      ctx.strokeStyle = "rgba(0, 229, 255, 0.6)";
      ctx.lineWidth = 2;
      ctx.stroke();

      radarAnimId = requestAnimationFrame(renderRadarFrame);
    }

    if (radarAnimId) cancelAnimationFrame(radarAnimId);
    radarAnimId = requestAnimationFrame(renderRadarFrame);

  } catch (err) {
    body.innerHTML = `<div style="text-align:center; padding:30px; color:#ef4444;">Failed to compile tactical radar: ${err.message}</div>`;
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

  loadKills();
  loadSidebar();

  // Polling update every 6 seconds
  setInterval(() => {
    if (currentTab === "FEED") loadKills();
    loadSidebar();
  }, 6000);
});
