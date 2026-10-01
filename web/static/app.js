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

function escapeHtml(str) {
  if (str === null || str === undefined) return "";
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function getClassIconSvg(cls) {
  cls = (cls || "").toUpperCase();
  switch (cls) {
    case "WARRIOR":
      return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M14.5 17.5L3 6V3h3l11.5 11.5M13 19l6-6M16 16l4 4M9.5 17.5L21 6V3h-3L6.5 14.5M11 19l-6-6M8 16l-4 4"/></svg>`;
    case "PALADIN":
      return `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M11 2h2v4h-2zM4 6h16v4H4zm2 4h12v2H6zm3 2h6v2H9zm1 2h4v8h-4z"/></svg>`;
    case "HUNTER":
      return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="8"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4"/><circle cx="12" cy="12" r="2.5" fill="currentColor"/></svg>`;
    case "ROGUE":
      return `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 2l3 3-5 9 3 3 9-5 3 3 2-2-15-11zm12 10l-2 2 3 3 2-2-3-3z"/></svg>`;
    case "PRIEST":
      return `<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="6" r="3" fill="none" stroke="currentColor" stroke-width="2"/><path d="M11 11h2v11h-2z"/><path d="M7 14h10v2H7z"/></svg>`;
    case "DEATHKNIGHT":
      return `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a8 8 0 00-8 8c0 3.2 1.9 6 4.7 7.3L8 22h8l-.7-4.7c2.8-1.3 4.7-4.1 4.7-7.3a8 8 0 00-8-8zm-3 8a1.5 1.5 0 110-3 1.5 1.5 0 010 3zm6 0a1.5 1.5 0 110-3 1.5 1.5 0 010 3z"/></svg>`;
    case "SHAMAN":
      return `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M13 2L4 14h7v8l9-12h-7z"/></svg>`;
    case "MAGE":
      return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="12 2 15 8 22 9 17 14 18 21 12 17 6 21 7 14 2 9 9 8 12 2"/><circle cx="12" cy="12" r="3" fill="currentColor"/></svg>`;
    case "WARLOCK":
      return `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C8 6 6 9 6 13a6 6 0 0012 0c0-4-2-7-6-11zm0 15a3 3 0 01-3-3c0-1.5 1-2.5 3-4.5 2 2 3 3 3 4.5a3 3 0 01-3 3z"/></svg>`;
    case "MONK":
      return `<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 3a9 9 0 010 18c-2.5 0-4.5-2-4.5-4.5s2-4.5 4.5-4.5 4.5-2 4.5-4.5S14.5 3 12 3z"/><circle cx="12" cy="7.5" r="1.5"/><circle cx="12" cy="16.5" r="1.5" fill="none" stroke="currentColor" stroke-width="1.5"/></svg>`;
    case "DRUID":
      return `<svg viewBox="0 0 24 24" fill="currentColor"><ellipse cx="6" cy="7" rx="1.5" ry="3"/><ellipse cx="10" cy="5" rx="1.5" ry="3"/><ellipse cx="14" cy="5" rx="1.5" ry="3"/><ellipse cx="18" cy="7" rx="1.5" ry="3"/><path d="M6 14c0 4 3 7 6 7s6-3 6-7c0-2-2-4-6-4s-6 2-6 4z"/></svg>`;
    case "DEMONHUNTER":
      return `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M2 16c4-1 8-5 10-14 2 9 6 13 10 14-4 2-8 3-10 1-2 2-6 1-10-1z"/></svg>`;
    case "EVOKER":
      return `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2L4 7v6c0 5 3.5 9.5 8 11 4.5-1.5 8-6 8-11V7l-8-5zm0 4a4 4 0 014 4c0 3-4 6-4 6s-4-3-4-6a4 4 0 014-4z"/></svg>`;
    default:
      return `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 12c2.2 0 4-1.8 4-4s-1.8-4-4-4-4 1.8-4 4 1.8 4 4 4zm0 2c-2.7 0-8 1.3-8 4v2h16v-2c0-2.7-5.3-4-8-4z"/></svg>`;
  }
}

function renderClassBadge(cls, size = 20) {
  const clsLower = (cls || "").toLowerCase();
  const clsUpper = (cls || "").toUpperCase();
  const color = CLASS_COLORS[clsUpper] || "#94a3b8";
  const svg = getClassIconSvg(clsUpper);
  return `<span class="wow-class-icon" style="width:${size}px; height:${size}px; border-color:${color};" title="${clsUpper}">
    <img src="/static/icons/classes/${clsLower}.jpg" alt="${clsUpper}" style="width:100%; height:100%; object-fit:cover; display:block;" onerror="this.style.display='none'; if(this.nextElementSibling) this.nextElementSibling.style.display='block';">
    <span style="display:none; width:100%; height:100%; color:${color};">${svg}</span>
  </span>`;
}

function renderWowCoin(type) {
  return `<span class="wow-coin ${type}" title="${type.charAt(0).toUpperCase() + type.slice(1)}"></span>`;
}

function inferSpec(cls, spellName) {
  cls = (cls || "").toUpperCase();
  const spell = (spellName || "").toLowerCase();
  if (cls === "WARRIOR") {
    if (spell.includes("mortal") || spell.includes("overpower") || spell.includes("colossus") || spell.includes("slam") || spell.includes("rend")) return { name: "Arms", id: "warrior_arms" };
    if (spell.includes("bloodthirst") || spell.includes("raging") || spell.includes("rampage") || spell.includes("whirlwind") || spell.includes("fury")) return { name: "Fury", id: "warrior_fury" };
    if (spell.includes("shield") || spell.includes("devastate") || spell.includes("revenge") || spell.includes("taunt")) return { name: "Protection", id: "warrior_protection" };
    return { name: "Arms", id: "warrior_arms" };
  }
  if (cls === "MAGE") {
    if (spell.includes("fire") || spell.includes("pyro") || spell.includes("scorch") || spell.includes("combust") || spell.includes("blast wave")) return { name: "Fire", id: "mage_fire" };
    if (spell.includes("frost") || spell.includes("ice") || spell.includes("blizzard") || spell.includes("flurry") || spell.includes("cone of cold")) return { name: "Frost", id: "mage_frost" };
    if (spell.includes("arcane")) return { name: "Arcane", id: "mage_arcane" };
    return { name: "Frost", id: "mage_frost" };
  }
  if (cls === "ROGUE") {
    if (spell.includes("mutilate") || spell.includes("envenom") || spell.includes("garrote") || spell.includes("rupture") || spell.includes("poison")) return { name: "Assassination", id: "rogue_assassination" };
    if (spell.includes("shadow") || spell.includes("backstab") || spell.includes("eviscerate") || spell.includes("ambush") || spell.includes("cheapshot")) return { name: "Subtlety", id: "rogue_subtlety" };
    if (spell.includes("sinister") || spell.includes("pistol") || spell.includes("blade") || spell.includes("adrenaline")) return { name: "Outlaw", id: "rogue_outlaw" };
    return { name: "Subtlety", id: "rogue_subtlety" };
  }
  if (cls === "PRIEST") {
    if (spell.includes("shadow") || spell.includes("mind") || spell.includes("plague") || spell.includes("void") || spell.includes("pain")) return { name: "Shadow", id: "priest_shadow" };
    if (spell.includes("penance") || spell.includes("shield") || spell.includes("radiance") || spell.includes("smite")) return { name: "Discipline", id: "priest_discipline" };
    if (spell.includes("heal") || spell.includes("serenity") || spell.includes("prayer") || spell.includes("holy") || spell.includes("renew")) return { name: "Holy", id: "priest_holy" };
    return { name: "Shadow", id: "priest_shadow" };
  }
  if (cls === "PALADIN") {
    if (spell.includes("verdict") || spell.includes("crusader") || spell.includes("blade") || spell.includes("judgment") || spell.includes("retribution") || spell.includes("hammer of wrath")) return { name: "Retribution", id: "paladin_retribution" };
    if (spell.includes("avenger") || spell.includes("righteous") || spell.includes("consecrat")) return { name: "Protection", id: "paladin_protection" };
    if (spell.includes("shock") || spell.includes("flash") || spell.includes("beacon") || spell.includes("holy light")) return { name: "Holy", id: "paladin_holy" };
    return { name: "Retribution", id: "paladin_retribution" };
  }
  if (cls === "HUNTER") {
    if (spell.includes("kill command") || spell.includes("beast") || spell.includes("barbed") || spell.includes("claw") || spell.includes("bite") || spell.includes("wrath")) return { name: "Beast Mastery", id: "hunter_beastmastery" };
    if (spell.includes("aimed") || spell.includes("rapid") || spell.includes("arcane shot") || spell.includes("chimaera") || spell.includes("steady") || spell.includes("multishot")) return { name: "Marksmanship", id: "hunter_marksmanship" };
    if (spell.includes("mongoose") || spell.includes("raptor") || spell.includes("bomb") || spell.includes("harpoon") || spell.includes("flanking")) return { name: "Survival", id: "hunter_survival" };
    return { name: "Marksmanship", id: "hunter_marksmanship" };
  }
  if (cls === "WARLOCK") {
    if (spell.includes("agony") || spell.includes("corruption") || spell.includes("affliction") || spell.includes("drain") || spell.includes("siphon") || spell.includes("unstable")) return { name: "Affliction", id: "warlock_affliction" };
    if (spell.includes("chaos") || spell.includes("incinerate") || spell.includes("conflagrate") || spell.includes("immolate") || spell.includes("rain of fire")) return { name: "Destruction", id: "warlock_destruction" };
    if (spell.includes("demon") || spell.includes("gul'dan") || spell.includes("felguard") || spell.includes("dreadstalker") || spell.includes("shadowbolt")) return { name: "Demonology", id: "warlock_demonology" };
    return { name: "Affliction", id: "warlock_affliction" };
  }
  if (cls === "DRUID") {
    if (spell.includes("star") || spell.includes("moonfire") || spell.includes("sunfire") || spell.includes("wrath") || spell.includes("eclipse")) return { name: "Balance", id: "druid_balance" };
    if (spell.includes("shred") || spell.includes("bite") || spell.includes("rip") || spell.includes("rake") || spell.includes("cat") || spell.includes("swipe")) return { name: "Feral", id: "druid_feral" };
    if (spell.includes("mangle") || spell.includes("bear") || spell.includes("ironfur") || spell.includes("frenzied") || spell.includes("growl")) return { name: "Guardian", id: "druid_guardian" };
    if (spell.includes("rejuvenation") || spell.includes("growth") || spell.includes("lifebloom") || spell.includes("swiftmend") || spell.includes("nourish")) return { name: "Restoration", id: "druid_restoration" };
    return { name: "Feral", id: "druid_feral" };
  }
  if (cls === "SHAMAN") {
    if (spell.includes("stormstrike") || spell.includes("lava lash") || spell.includes("windfury") || spell.includes("crash") || spell.includes("sunder")) return { name: "Enhancement", id: "shaman_enhancement" };
    if (spell.includes("lava burst") || spell.includes("earth shock") || spell.includes("chain lightning") || spell.includes("lightning bolt") || spell.includes("elemental")) return { name: "Elemental", id: "shaman_elemental" };
    if (spell.includes("riptide") || spell.includes("healing") || spell.includes("rain") || spell.includes("water") || spell.includes("chain heal")) return { name: "Restoration", id: "shaman_restoration" };
    return { name: "Enhancement", id: "shaman_enhancement" };
  }
  if (cls === "DEATHKNIGHT") {
    if (spell.includes("frost") || spell.includes("obliterate") || spell.includes("howling") || spell.includes("glacial")) return { name: "Frost", id: "deathknight_frost" };
    if (spell.includes("blood") || spell.includes("marrow") || spell.includes("heart strike") || spell.includes("death strike")) return { name: "Blood", id: "deathknight_blood" };
    if (spell.includes("unholy") || spell.includes("scourge") || spell.includes("festering") || spell.includes("apocalypse") || spell.includes("death coil") || spell.includes("epidemic")) return { name: "Unholy", id: "deathknight_unholy" };
    return { name: "Frost", id: "deathknight_frost" };
  }
  if (cls === "MONK") {
    if (spell.includes("rising sun") || spell.includes("fists of fury") || spell.includes("tiger palm") || spell.includes("blackout") || spell.includes("spinning crane")) return { name: "Windwalker", id: "monk_windwalker" };
    if (spell.includes("keg") || spell.includes("brew") || spell.includes("breath of fire") || spell.includes("purifying")) return { name: "Brewmaster", id: "monk_brewmaster" };
    if (spell.includes("mist") || spell.includes("vivify") || spell.includes("enveloping") || spell.includes("renewing")) return { name: "Mistweaver", id: "monk_mistweaver" };
    return { name: "Windwalker", id: "monk_windwalker" };
  }
  if (cls === "DEMONHUNTER") {
    if (spell.includes("chaos") || spell.includes("eye beam") || spell.includes("blade dance") || spell.includes("fel rush") || spell.includes("annihilation")) return { name: "Havoc", id: "demonhunter_havoc" };
    return { name: "Vengeance", id: "demonhunter_vengeance" };
  }
  return { name: "Combatant", id: (cls || "warrior").toLowerCase() + "_arms" };
}

function renderSpecBadge(specId, specName, size = 18) {
  return `<span class="wow-spec-badge" style="width:${size}px; height:${size}px;" title="Specialization: ${specName}">
    <img src="/static/icons/specs/${specId}.jpg" alt="${specName}" style="width:100%; height:100%; object-fit:cover; border-radius:2px; display:block;" onerror="this.style.display='none';">
  </span>`;
}

let currentTab = "FEED";
let currentMode = "WORLD";
let searchQuery = "";
let cachedKills = [];

let currentFlavor = "FOREVER";

const FLAVOR_CONFIGS = {
  RETAIL: {
    name: "Modern Retail (Dragonflight / War Within)",
    shortName: "RETAIL",
    tag: "RETAIL",
    portalDescription: "The War Within, Cross-Faction Arenas, Rated Solo Shuffle & modern World PvP bounty hunts.",
    maxLevel: 80,
    iconColor: "#f59e0b",
    availableClasses: ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER"],
    disabledClasses: {},
    disabledModes: {}
  },
  FOREVER: {
    name: "WoW Forever Beta (1.15)",
    shortName: "FOREVER",
    tag: "BETA",
    portalDescription: "Custom Rebalanced Classic Vanilla, enhanced talent trees, custom balance & experimental arena ladder.",
    maxLevel: 60,
    iconColor: "#00e5ff",
    availableClasses: ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"],
    disabledClasses: {
      DEATHKNIGHT: "WotLK 3.0+",
      MONK: "MoP 5.0+",
      DEMONHUNTER: "Legion 7.0+",
      EVOKER: "DF 10.0+"
    },
    disabledModes: {
      ARENA: "Introduced in TBC (Patch 2.0)"
    }
  },
  CLASSIC_ERA: {
    name: "Classic Era (1.15)",
    shortName: "CLASSIC",
    tag: "ERA",
    portalDescription: "Original World PvP, Tarren Mill vs Southshore & Stranglethorn Vale, Vanilla Rank 14 Honor System.",
    maxLevel: 60,
    iconColor: "#eab308",
    availableClasses: ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"],
    disabledClasses: {
      DEATHKNIGHT: "WotLK 3.0+",
      MONK: "MoP 5.0+",
      DEMONHUNTER: "Legion 7.0+",
      EVOKER: "DF 10.0+"
    },
    disabledModes: {
      ARENA: "Introduced in TBC (Patch 2.0)"
    }
  },
  ANNIVERSARY: {
    name: "20th Anniversary Edition (1.15)",
    shortName: "ANNIV",
    tag: "ANNIV",
    portalDescription: "Fresh 20th Anniversary Progression Realms, active leveling skirmishes, Hardcore & PvP warfare.",
    maxLevel: 60,
    iconColor: "#d97706",
    availableClasses: ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"],
    disabledClasses: {
      DEATHKNIGHT: "WotLK 3.0+",
      MONK: "MoP 5.0+",
      DEMONHUNTER: "Legion 7.0+",
      EVOKER: "DF 10.0+"
    },
    disabledModes: {
      ARENA: "Introduced in TBC (Patch 2.0)"
    }
  },
  TBC: {
    name: "The Burning Crusade (2.4.3)",
    shortName: "TBC",
    tag: "TBC",
    portalDescription: "Outland World PvP, Hellfire Peninsula, Halaa, Terokkar Towers & Arena Seasons 1–4.",
    maxLevel: 70,
    iconColor: "#22c55e",
    availableClasses: ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"],
    disabledClasses: {
      DEATHKNIGHT: "WotLK 3.0+",
      MONK: "MoP 5.0+",
      DEMONHUNTER: "Legion 7.0+",
      EVOKER: "DF 10.0+"
    },
    disabledModes: {}
  },
  WOTLK: {
    name: "Wrath of the Lich King (3.3.5)",
    shortName: "WOTLK",
    tag: "WOTLK",
    portalDescription: "Northrend Warfare, Death Knight introduction, epic Lake Wintergrasp fortress siege battles.",
    maxLevel: 80,
    iconColor: "#38bdf8",
    availableClasses: ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID"],
    disabledClasses: {
      MONK: "MoP 5.0+",
      DEMONHUNTER: "Legion 7.0+",
      EVOKER: "DF 10.0+"
    },
    disabledModes: {}
  }
};

async function initClientFlavor() {
  try {
    const res = await fetch("/api/system/flavor");
    if (res.ok) {
      const data = await res.json();
      if (data.flavor) {
        currentFlavor = data.flavor;
        localStorage.setItem("wowkb_client_flavor", currentFlavor);
      }
    }
  } catch (e) {}
  updateFlavorUi();
}

async function handleFlavorChange(newFlavor, newServer) {
  currentFlavor = newFlavor;
  localStorage.setItem("wowkb_client_flavor", currentFlavor);
  const srv = newServer || (localStorage.getItem("wowkb_forever_server") || "PVP");
  if (newFlavor === "FOREVER") {
    localStorage.setItem("wowkb_forever_server", srv);
  }
  try {
    await fetch("/api/system/flavor", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ flavor: newFlavor, server: srv })
    });
  } catch (e) {}
  updateFlavorUi();
  updateTheaterNavLabel();
  if (typeof updateNavigationLabels === "function") {
    updateNavigationLabels();
  }
  if (typeof reloadActiveView === "function") {
    reloadActiveView();
  } else if (currentTab === "ARMORY") {
    loadArmoryView();
  }
}

function updateFlavorUi() {
  const cfg = FLAVOR_CONFIGS[currentFlavor] || FLAVOR_CONFIGS.CLASSIC_ERA;

  // 1. Update active tab in Wowhead-style top bar
  document.querySelectorAll(".wh-tab-btn").forEach(btn => {
    const flv = btn.getAttribute("data-flavor");
    if (flv === currentFlavor) {
      btn.classList.add("active");
      btn.style.setProperty("--active-tab-color", cfg.iconColor || "#f59e0b");
      btn.style.color = "#ffffff";
    } else {
      btn.classList.remove("active");
      btn.style.removeProperty("--active-tab-color");
      btn.style.color = "";
    }
  });

  // 2. Update active pill in Mobile drawer
  document.querySelectorAll(".m-flavor-btn").forEach(btn => {
    const flv = btn.getAttribute("data-flavor");
    if (flv === currentFlavor) {
      btn.classList.add("active");
      btn.style.borderColor = cfg.iconColor || "#f59e0b";
      btn.style.color = "#ffffff";
    } else {
      btn.classList.remove("active");
      btn.style.borderColor = "";
      btn.style.color = "";
    }
  });

  // 3. Update status indicator text on top right
  const statusText = document.getElementById("wh-active-flavor-name");
  if (statusText) {
    statusText.innerText = `${cfg.shortName} (${cfg.maxLevel} MAX)`;
    statusText.style.color = cfg.iconColor || "#94a3b8";
  }
  updateTheaterNavLabel();

  // 3b. Update mobile header flavor indicator badge
  const mBadgeText = document.getElementById("mobile-flavor-badge-text");
  const mWBadge = document.getElementById("mobile-flavor-w-badge");
  if (mBadgeText) {
    mBadgeText.innerText = `${cfg.shortName} ${cfg.maxLevel}`;
  }
  if (mWBadge) {
    const badgeCls = currentFlavor === "FOREVER" ? "forever"
      : currentFlavor === "RETAIL" ? "retail"
      : currentFlavor === "TBC" ? "tbc"
      : currentFlavor === "WOTLK" ? "wotlk"
      : currentFlavor === "ANNIVERSARY" ? "anniversary"
      : "classic";
    mWBadge.className = `wh-w-badge ${badgeCls}`;
    mWBadge.style.borderColor = cfg.iconColor || "#f59e0b";
    mWBadge.style.color = cfg.iconColor || "#f59e0b";
  }

  // 4. Update mode pills (e.g. Arenas disabled in Classic Era / Forever Beta)
  const arenaPill = document.getElementById("pill-arena");
  const mArenaPill = document.getElementById("m-pill-arena");
  if (cfg.disabledModes && cfg.disabledModes.ARENA) {
    if (arenaPill) {
      arenaPill.classList.add("disabled");
      arenaPill.title = `🔒 Arenas Unavailable in ${cfg.name} (${cfg.disabledModes.ARENA})`;
      arenaPill.onclick = (e) => {
        e.preventDefault();
        alert(`🔒 Arenas are unavailable in ${cfg.name} (${cfg.disabledModes.ARENA}). Switch the flavor in the top bar to TBC, WotLK, or Retail to enable Arena ladders.`);
      };
    }
    if (mArenaPill) {
      mArenaPill.classList.add("disabled");
      mArenaPill.title = `🔒 Arenas Unavailable in ${cfg.name} (${cfg.disabledModes.ARENA})`;
      mArenaPill.onclick = (e) => {
        e.preventDefault();
        alert(`🔒 Arenas are unavailable in ${cfg.name} (${cfg.disabledModes.ARENA}). Switch the flavor in the top bar to TBC, WotLK, or Retail to enable Arena ladders.`);
      };
    }
    if (currentMode === "ARENA") {
      setFilterMode("WORLD");
    }
  } else {
    if (arenaPill) {
      arenaPill.classList.remove("disabled");
      arenaPill.title = "View Arena Matches";
      arenaPill.onclick = () => setFilterMode("ARENA");
    }
    if (mArenaPill) {
      mArenaPill.classList.remove("disabled");
      mArenaPill.title = "View Arena Matches";
      mArenaPill.onclick = () => { setFilterMode("ARENA"); toggleMobileDrawer(false); };
    }
  }
}

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
    hunter = prompt(`Declare Hunt: Accept Execution Contract on ${targetName}?\nEnter your Vanguard Hunter Character Name:`);
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
      alert(`Blood contract accepted! You are now hunting ${targetName}. Deliver the certified killing blow in open combat to claim the gold!`);
      loadMostWanted();
    } else {
      alert("Failed to accept blood bounty contract.");
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

  const isPve = (currentFlavor === "FOREVER" && typeof getCurrentForeverServer === "function" && getCurrentForeverServer() === "PVE");
  const mwTitle = document.querySelector(".most-wanted-title");
  const mwSub = document.querySelector(".most-wanted-subtitle");
  const mwBtn = document.querySelector(".see-all-marks-btn");

  if (isPve) {
    if (mwTitle) mwTitle.innerText = "THE BESTIARY — AZEROTH'S DEADLIEST MONSTERS";
    if (mwSub) mwSub.innerText = "Wilderness Executioners & World Bosses • Highest confirmed mortal kill counts";
    if (mwBtn) {
      mwBtn.innerText = "View Bestiary Records →";
      mwBtn.onclick = () => switchTab('HAZARDS');
    }

    try {
      const res = await fetch("/api/pve/leaderboard");
      if (!res.ok) return;
      const lb = await res.json();
      renderPveMostWanted(lb.topDeadlyNpcs || []);
    } catch (e) {
      console.error("Failed to load PvE Deadly NPCs:", e);
    }
    return;
  }

  if (mwTitle) mwTitle.innerText = "THE BLOOD LEDGER — AZEROTH'S MOST WANTED";
  if (mwSub) mwSub.innerText = "Open World Execution Contracts & Certified Outlaws • Deliver the final blow to claim the bounty";
  if (mwBtn) {
    mwBtn.innerText = "View The Marked →";
    mwBtn.onclick = () => switchTab('BOUNTIES');
  }

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

function renderPveMostWanted(npcs) {
  const container = document.getElementById("most-wanted-cards-container");
  if (!container) return;

  const safeNpcs = Array.isArray(npcs) ? npcs : [];
  const totalSlots = safeNpcs.length > 5 ? 10 : 5;
  let html = "";

  for (let idx = 0; idx < totalSlots; idx++) {
    const npc = safeNpcs[idx];
    if (npc) {
      const isRank1 = idx === 0;
      const rank1Class = isRank1 ? "rank-1-card" : "";
      const stampRankClass = isRank1 ? "rank-1" : "";
      const maxHit = formatNumber(npc.max_damage || 0);

      html += `
        <div class="wanted-card compact horde ${rank1Class}" style="border-color:#ef4444;">
          <div class="wanted-card-top">
            <span class="wanted-stamp ${stampRankClass}">#${idx + 1} DEADLIEST</span>
            <span class="wanted-reward-pill gold-pot" style="color:#ef4444; border-color:#7f1d1d;">💀 ${npc.kills} Slain</span>
          </div>
          <div class="wanted-avatar-wrap compact" style="border-color:#ef4444; background:rgba(239,68,68,0.15); display:flex; align-items:center; justify-content:center; font-size:1.8rem;">
            💀
          </div>
          <div class="wanted-name-row">
            <span class="wanted-level-badge" style="background:#7f1d1d; color:#fca5a5;">ELITE</span>
            <div class="wanted-name" style="color:#ef4444;" title="${escapeHtml(npc.npc_name)}">
              ${escapeHtml(npc.npc_name)}
            </div>
          </div>
          <div class="wanted-guild" style="color:#f87171;">&lt;Wilderness Boss&gt;</div>
          <div class="wanted-lastseen">💥 Max Hit: ${maxHit} dmg</div>
          <div class="wanted-action-wrap">
            <button class="wanted-btn compact" onclick="switchTab('HAZARDS')" style="background:rgba(239,68,68,0.15); border-color:#ef4444; color:#fca5a5;">Inspect Threat &rarr;</button>
          </div>
        </div>
      `;
    } else {
      html += `
        <div class="wanted-card compact blank">
          <div class="wanted-card-top">
            <span class="wanted-stamp muted">#${idx + 1} DEADLIEST</span>
            <span class="wanted-reward-pill muted">CLEAR</span>
          </div>
          <div class="wanted-avatar-wrap compact blank">
            <span class="wanted-blank-icon"></span>
          </div>
          <div class="wanted-name muted">Sector Clear</div>
          <div class="wanted-guild muted">&lt;No Hazard&gt;</div>
          <div class="wanted-lastseen muted">Wilderness Nominal</div>
          <div class="wanted-action-wrap">
            <button class="wanted-btn compact blank-issue-btn" disabled>Secured</button>
          </div>
        </div>
      `;
    }
  }

  container.innerHTML = html;
}

function renderMostWanted(outlaws) {
  const container = document.getElementById("most-wanted-cards-container");
  if (!container) return;

  const safeOutlaws = Array.isArray(outlaws) ? outlaws : [];
  // Show 1 clean row (5 slots) if 5 or fewer bounties exist, expand to 10 only when crowded
  const totalSlots = safeOutlaws.length > 5 ? 10 : 5;
  let html = "";

  for (let idx = 0; idx < totalSlots; idx++) {
    const b = safeOutlaws[idx];
    if (b) {
      const cls = (b.target_class || "WARRIOR").toUpperCase();
      const clsColor = CLASS_COLORS[cls] || CLASS_COLORS.UNKNOWN;
      const accepted = isBountyAcceptedLocally(b.id);
      const lastSeenText = b.lastSeen && b.lastSeen.hasTelemetry 
        ? b.lastSeen.displayText 
        : "Unknown Location";

      // Format reward accurately for gold, silver, or copper
      const copper = Number(b.amount_copper) || (Number(b.amount_gold) * 10000) || 0;
      let rewardText = "";
      if (copper >= 10000) {
        rewardText = `${(copper / 10000).toFixed(copper % 10000 === 0 ? 0 : 1)}g`;
      } else if (copper >= 100) {
        rewardText = `${Math.floor(copper / 100)}s ${copper % 100 > 0 ? (copper % 100) + 'c' : ''}`.trim();
      } else {
        rewardText = `${copper}c`;
      }

      // Contracts are accepted exclusively in-game in World of Warcraft; website displays tactical dossier link
      const btnHtml = `<button class="wanted-btn compact" onclick="openCharacterProfile('${escapeHtml(b.target_name)}')" title="Inspect Outlaw Dossier (Marks Accepted In-Game Only)">Target Intel &rarr;</button>`;

      let targetFaction = (b.target_faction || "").trim();
      if (!targetFaction && cls) {
        if (cls === "PALADIN") targetFaction = "Alliance";
        else if (cls === "SHAMAN") targetFaction = "Horde";
      }
      const factionClass = targetFaction.toLowerCase() === "alliance" ? "alliance" : (targetFaction.toLowerCase() === "horde" ? "horde" : "");

      const isRank1 = idx === 0;
      const rank1Class = isRank1 ? "rank-1-card" : "";
      const stampRankClass = isRank1 ? "rank-1" : "";
      const targetLevel = b.target_level || b.level || 60;
      const goldPotHtml = `<span class="wanted-reward-pill gold-pot">💰 ${rewardText}</span>`;

      html += `
        <div class="wanted-card compact ${factionClass} ${rank1Class}">
          <div class="wanted-card-top">
            <span class="wanted-stamp ${stampRankClass}">#${idx + 1} WANTED</span>
            ${goldPotHtml}
          </div>
          <div class="wanted-avatar-wrap compact" style="border-color: ${clsColor};">
            <img src="/static/icons/classes/${cls.toLowerCase()}.jpg" class="wanted-avatar-img" alt="${cls}" onerror="this.src='/static/icons/classes/warrior.jpg'">
          </div>
          <div class="wanted-name-row">
            <span class="wanted-level-badge">Lv ${targetLevel}</span>
            <div class="wanted-name" onclick="openCharacterProfile('${b.target_name}')" title="${b.target_name}">
              ${colorizeClass(b.target_name, cls)}
            </div>
          </div>
          <div class="wanted-guild" title="${targetFaction || 'Neutral'}">&lt;${targetFaction || 'Neutral'}&gt;</div>
          <div class="wanted-lastseen" title="Last Seen: ${lastSeenText}">📍 ${lastSeenText}</div>
          <div class="wanted-action-wrap">
            ${btnHtml}
          </div>
        </div>
      `;
    } else {
      html += `
        <div class="wanted-card compact blank" onclick="switchTab('BOUNTIES')" title="Click to place a Blood Bounty and fill this execution slot">
          <div class="wanted-card-top">
            <span class="wanted-stamp muted">#${idx + 1} WANTED</span>
            <span class="wanted-reward-pill muted">OPEN</span>
          </div>
          <div class="wanted-avatar-wrap compact blank">
            <span class="wanted-blank-icon"></span>
          </div>
          <div class="wanted-name muted">Pending Target</div>
          <div class="wanted-guild muted">&lt;Unclaimed&gt;</div>
          <div class="wanted-lastseen muted">No Active Contract</div>
          <div class="wanted-action-wrap">
            <button class="wanted-btn compact blank-issue-btn" onclick="event.stopPropagation(); switchTab('BOUNTIES')">+ Issue Bounty</button>
          </div>
        </div>
      `;
    }
  }

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
  const c = copper % 100;
  let out = "";
  if (g > 0) out += `${g} ${renderWowCoin('gold')} `;
  if (s > 0 || g > 0) out += `${s} ${renderWowCoin('silver')} `;
  out += `${c} ${renderWowCoin('copper')}`;
  return out.trim();
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

// Live Combat Toast Alert System (1:1 Addon Parity)
let knownKillIds = new Set();
let isInitialKillsLoad = true;

function showCombatToast(km) {
  const container = document.getElementById("combat-toast-container");
  if (!container || !km) return;

  const killerName = (km.killer && km.killer.name) || "Unknown";
  const killerCls = ((km.killer && km.killer.class) || "WARRIOR").toUpperCase();
  const victimName = (km.victim && km.victim.name) || "Unknown";
  const victimCls = ((km.victim && km.victim.class) || "WARRIOR").toUpperCase();
  const zone = (km.location && km.location.zone) || "Azeroth";
  const isBounty = km.isBountyClaim || (km.bountyRewardGold && km.bountyRewardGold > 0) || (km.bounty && (km.bounty.amountGold > 0 || km.bounty.amountCopper > 0));

  const toast = document.createElement("div");
  toast.className = `combat-toast ${isBounty ? "bounty-claim" : ""}`;
  toast.onclick = () => openKillModal(km.killId);

  const icon = isBounty ? "💰" : (km.isSolo ? "⚔️" : "💀");
  const title = isBounty ? "BOUNTY CLAIMED" : (km.isSolo ? "1v1 SOLO SLAIN" : "COMBAT CASUALTY");

  toast.innerHTML = `
    <div class="combat-toast-icon">${icon}</div>
    <div class="combat-toast-content">
      <div class="combat-toast-header">
        <span>${title}</span>
        <span>${zone}</span>
      </div>
      <div class="combat-toast-body">
        ${colorizeClass(killerName, killerCls)} slayed ${colorizeClass(victimName, victimCls)}
      </div>
      <div class="combat-toast-sub">
        ${isBounty ? `<span style="color:#ffd100; font-weight:800;">💰 ${km.bountyRewardGold || ''}g Claimed</span> &bull; ` : ''}Click to view Battle Report
      </div>
    </div>
  `;

  container.appendChild(toast);
  requestAnimationFrame(() => {
    toast.classList.add("visible");
  });

  setTimeout(() => {
    toast.classList.remove("visible");
    setTimeout(() => {
      if (toast.parentNode) {
        toast.parentNode.removeChild(toast);
      }
    }, 400);
  }, 5500);
}
window.showCombatToast = showCombatToast;

// Data Fetching
async function loadKills() {
  const isPve = (currentFlavor === "FOREVER" && typeof getCurrentForeverServer === "function" && getCurrentForeverServer() === "PVE");

  if (isPve) {
    try {
      const res = await fetch("/api/pve/deaths?limit=30");
      if (res.ok) {
        const data = await res.json();
        const incomingDeaths = data.deaths || [];
        renderStats([]);
        if (currentTab === "FEED" || currentTab === "INTEL") {
          renderPveFeed(incomingDeaths);
        }
      }
    } catch (e) {
      console.error("Failed to load PvE casualties:", e);
    }
    return;
  }

  try {
    const fetchMode = (currentMode || "WORLD").toUpperCase();
    const res = await fetch(`/api/kills?mode=${encodeURIComponent(fetchMode)}&search=${encodeURIComponent(searchQuery)}`);
    const data = await res.json();
    const incomingKills = data.kills || [];

    if (isInitialKillsLoad) {
      incomingKills.forEach(k => knownKillIds.add(k.killId));
      isInitialKillsLoad = false;
    } else {
      const newKills = incomingKills.filter(k => !knownKillIds.has(k.killId));
      newKills.forEach(k => {
        knownKillIds.add(k.killId);
        showCombatToast(k);
      });
    }

    cachedKills = incomingKills;
    renderStats(cachedKills);
    if (currentTab === "FEED" || currentTab === "INTEL") {
      renderFeed(cachedKills);
    }
  } catch (err) {
    console.error("Failed to load kills:", err);
  }
}

function renderPveFeed(deaths) {
  const container = document.getElementById("main-content-area");
  if (!container) return;

  const safeDeaths = Array.isArray(deaths) ? deaths : [];
  if (safeDeaths.length === 0) {
    container.innerHTML = `
      <div style="text-align: center; padding: 40px; color: #64748b;">
        <h3>No Wilderness Casualties Logged Yet.</h3>
        <p style="margin-top: 8px;">Fallen mortals and world boss encounters will populate here.</p>
      </div>
    `;
    return;
  }

  let html = `
    <div style="margin-bottom: 14px; display: flex; justify-content: space-between; align-items: center; background: rgba(56, 189, 248, 0.08); border: 1px solid rgba(56, 189, 248, 0.3); border-radius: 6px; padding: 10px 16px;">
      <div style="display:flex; align-items:center; gap:8px;">
        <span style="font-size:0.85rem; color:#38bdf8; font-weight:700;">🛡️ FOREVER PVE CAMPAIGN &bull; WILDERNESS HAZARD CASUALTY FEED</span>
      </div>
      <span class="combat-feed-counter" style="color:var(--wow-gold); font-weight:800;">${safeDeaths.length} Fallen Mortals</span>
    </div>
  `;

  safeDeaths.forEach(d => {
    const vCls = (d.victim_class || "WARRIOR").toUpperCase();
    const vColor = CLASS_COLORS[vCls] || CLASS_COLORS.UNKNOWN;
    const vLvl = d.victim_level || "??";
    const zoneStr = d.subzone ? `${d.zone} (${d.subzone})` : (d.zone || "Wilderness");
    const ago = timeAgo(d.timestamp);

    html += `
      <div class="kill-card pve-hazard-card" style="border-left: 3px solid #ef4444; margin-bottom: 10px;">
        <div class="kill-card-header" style="display:flex; justify-content:space-between; align-items:center; padding:6px 14px; background:rgba(0,0,0,0.3); border-bottom:1px solid rgba(255,255,255,0.06);">
          <span class="kill-zone" style="color:#e2e8f0; font-size:0.78rem;">📍 ${escapeHtml(zoneStr)}</span>
          <span class="kill-time" style="color:#94a3b8; font-size:0.75rem;">${ago}</span>
        </div>
        <div class="kill-content" style="display:flex; justify-content:space-between; align-items:center; padding:12px 16px;">
          <!-- Monster / NPC Executioner -->
          <div class="combatant-block" style="display:flex; align-items:center; gap:12px;">
            <div style="width:40px; height:40px; border-radius:4px; border:1px solid #ef4444; background:rgba(239,68,68,0.15); display:flex; align-items:center; justify-content:center; font-size:1.3rem;">💀</div>
            <div>
              <div style="font-weight:800; color:#ef4444; font-size:1.1rem;">${escapeHtml(d.npc_name)}</div>
              <div style="font-size:0.75rem; color:#94a3b8;">${d.npc_spell ? escapeHtml(d.npc_spell) : 'Melee Strike'} &bull; <strong style="color:#fca5a5;">${formatNumber(d.npc_damage || 0)} dmg</strong></div>
            </div>
          </div>

          <div style="font-weight:900; color:#64748b; font-size:0.8rem; letter-spacing:1px; background:rgba(0,0,0,0.4); padding:4px 8px; border-radius:4px;">DEFEATED</div>

          <!-- Fallen Player Victim -->
          <div class="combatant-block" style="display:flex; align-items:center; gap:12px; text-align:right;">
            <div>
              <div style="font-weight:800; font-size:1.1rem; cursor:pointer;" onclick="openCharacterProfile('${escapeHtml(d.victim_name)}')">
                <span style="color:${vColor};">${escapeHtml(d.victim_name)}</span> <span style="font-size:0.75rem; color:#94a3b8;">(${vLvl})</span>
              </div>
              <div style="font-size:0.72rem; color:#cbd5e1;">&lt;${escapeHtml(d.victim_guild || 'Unguilded')}&gt;</div>
            </div>
            ${renderClassBadge(vCls, 36)}
          </div>
        </div>
      </div>
    `;
  });

  container.innerHTML = html;
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
  if (!data) return;

  // 1. Lifetime Combat Activity Table Numbers
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

  // 2. Deadliest Zones (Last 24 Hours)
  const zoneListEl = document.getElementById("sidebar-24h-zones") || document.getElementById("sidebar-7d-zones-list");
  const charListEl = document.getElementById("sidebar-24h-characters") || document.getElementById("sidebar-7d-characters");

  const isPve = (currentFlavor === "FOREVER" && typeof getCurrentForeverServer === "function" && getCurrentForeverServer() === "PVE");
  if (isPve) {
    try {
      fetch("/api/pve/leaderboard").then(r => r.json()).then(pveData => {
        const deadZone = pveData.summary?.mostDangerousZone || { zone: "Elwynn Forest", deaths: 3 };
        if (zoneListEl) {
          zoneListEl.innerHTML = `
            <div class="sidebar-rank-item zone-item">
              <div style="display:flex; align-items:center; gap:6px; min-width:0; overflow:hidden;">
                <span class="rank-badge">#1</span>
                <span style="font-weight:700; color:#e2e8f0;">${escapeHtml(deadZone.zone || "Elwynn Forest")}</span>
              </div>
              <span style="color:#ef4444; font-weight:700; font-family:var(--font-tactical); margin-left:8px;">${deadZone.deaths || 3} deaths</span>
            </div>
          `;
        }
        if (charListEl && pveData.topDeadlyNpcs) {
          charListEl.innerHTML = pveData.topDeadlyNpcs.slice(0, 5).map((m, i) => `
            <div class="sidebar-rank-item character-item" style="cursor:pointer;" onclick="switchTab('HAZARDS')">
              <div style="display:flex; align-items:center; gap:6px; min-width:0; overflow:hidden;">
                <span class="rank-badge">#${i + 1}</span>
                <span style="font-weight:700; color:#ef4444;">💀 ${escapeHtml(m.npc_name)}</span>
              </div>
              <span style="color:var(--accent-gold); font-weight:700; font-family:var(--font-tactical); margin-left:8px;">${m.kills} slain</span>
            </div>
          `).join('');
        }
      });
    } catch (e) {}
    return;
  }

  if (zoneListEl) {
    const zones = data.deadliestZones24h || data.topZones || [];
    if (zones.length === 0) {
      zoneListEl.innerHTML = `<div style="color:#64748b; font-size:0.75rem;">No conflict zones logged in last 24h</div>`;
    } else {
      zoneListEl.innerHTML = zones.map((z, i) => `
        <div class="sidebar-rank-item zone-item">
          <div style="display:flex; align-items:center; gap:6px; min-width:0; overflow:hidden;">
            <span class="rank-badge">#${i + 1}</span>
            <span style="font-weight:700; color:#e2e8f0; white-space:nowrap; text-overflow:ellipsis; overflow:hidden;">${escapeHtml(z.zone)}</span>
          </div>
          <span style="color:#ef4444; font-weight:700; font-family:var(--font-tactical); white-space:nowrap; margin-left:8px;">${z.kills} kills</span>
        </div>
      `).join('');
    }
  }

  // 3. Top Active Gankers (Last 24 Hours)
  if (charListEl) {
    const chars = data.topGankers24h || data.topCharacters || [];
    if (chars.length === 0) {
      charListEl.innerHTML = `<div style="color:#64748b; font-size:0.75rem;">No character kills logged in last 24h</div>`;
    } else {
      charListEl.innerHTML = chars.map((c, i) => {
        let faction = (c.faction || "").toLowerCase();
        if (!faction && c.class) {
          const cu = c.class.toUpperCase();
          if (cu === "PALADIN") faction = "alliance";
          else if (cu === "SHAMAN") faction = "horde";
        }
        const factionClass = faction === 'alliance' ? 'alliance' : (faction === 'horde' ? 'horde' : '');
        return `
          <div class="sidebar-rank-item ${factionClass}">
            <div style="display:flex; align-items:center; gap:6px; min-width:0; overflow:hidden;">
              <span class="rank-badge">#${i + 1}</span>
              <span class="clickable-player" onclick="openCharacterProfile('${escapeHtml(c.name)}')" style="white-space:nowrap;">${colorizeClass(c.name, c.class)}</span>
            </div>
            <span style="color:#10b981; font-weight:700; font-family:var(--font-tactical); white-space:nowrap; margin-left:8px;">${c.kills} kills</span>
          </div>
        `;
      }).join('');
    }
  }

  // 4. Top Active Guilds (Last 24 Hours)
  const guildListEl = document.getElementById("sidebar-24h-guilds") || document.getElementById("sidebar-7d-guilds");
  if (guildListEl) {
    const guilds = data.topGuilds24h || data.topGuilds || [];
    if (guilds.length === 0) {
      guildListEl.innerHTML = `<div style="color:#64748b; font-size:0.75rem;">No active guild combat in last 24h</div>`;
    } else {
      guildListEl.innerHTML = guilds.map((g, i) => {
        const factionClass = (g.faction || '').toLowerCase() === 'alliance' ? 'alliance' : ((g.faction || '').toLowerCase() === 'horde' ? 'horde' : '');
        return `
          <div class="sidebar-rank-item ${factionClass}">
            <div style="display:flex; align-items:center; gap:6px; min-width:0; overflow:hidden;">
              <span class="rank-badge">#${i + 1}</span>
              <span class="clickable-guild" onclick="openGuildProfile('${escapeHtml(g.guild)}')" style="font-weight:700; color:var(--text-main); white-space:nowrap;">&lt;${escapeHtml(g.guild)}&gt;</span>
            </div>
            <span style="color:var(--accent-gold); font-weight:700; font-family:var(--font-tactical); white-space:nowrap; margin-left:8px;">${g.kills} kills</span>
          </div>
        `;
      }).join('');
    }
  }

  // 5. Top Classes (Lifetime)
  const classListEl = document.getElementById("sidebar-top-classes") || document.getElementById("sidebar-7d-classes");
  if (classListEl) {
    const classes = data.topClasses || [];
    if (classes.length === 0) {
      classListEl.innerHTML = `<div style="color:#64748b; font-size:0.75rem;">No class telemetry logged</div>`;
    } else {
      classListEl.innerHTML = classes.map(cls => {
        const rawCls = cls.class || '';
        const color = CLASS_COLORS[rawCls.toUpperCase()] || CLASS_COLORS.UNKNOWN;
        const formattedClassName = rawCls ? (rawCls.charAt(0).toUpperCase() + rawCls.slice(1).toLowerCase()) : 'Unknown';
        return `
          <div class="sidebar-rank-item">
            <span style="color:${color}; font-weight:700; display:flex; align-items:center; gap:6px;">
              ${renderClassBadge(rawCls, 16)} ${escapeHtml(formattedClassName)}
            </span>
            <span style="color:#e2e8f0; font-weight:700; font-family:var(--font-tactical);">${cls.kills} kills</span>
          </div>
        `;
      }).join('');
    }
  }

  // 6. Top Specializations (Lifetime)
  const specListEl = document.getElementById("sidebar-top-specs");
  if (specListEl) {
    const specs = (data.topSpecs || []).slice().sort((a, b) => {
      const cmp = (a.spec || '').localeCompare(b.spec || '');
      return cmp !== 0 ? cmp : (a.class || '').localeCompare(b.class || '');
    });
    if (specs.length === 0) {
      specListEl.innerHTML = `<div style="color:#64748b; font-size:0.75rem;">No specialization telemetry logged</div>`;
    } else {
      specListEl.innerHTML = specs.map(s => {
        const color = CLASS_COLORS[(s.class || '').toUpperCase()] || CLASS_COLORS.UNKNOWN;
        return `
          <div class="sidebar-rank-item">
            <span style="color:${color}; font-weight:700;">${escapeHtml(s.spec || 'Unknown')}</span>
            <span style="color:${s.kills > 0 ? 'var(--accent-cyan)' : '#64748b'}; font-weight:700; font-family:var(--font-tactical);">${s.kills} kills</span>
          </div>
        `;
      }).join('');
    }
  }
}

let legendsTabType = "PLAYERS"; // "PLAYERS" or "GUILDS"
let benchmarkPlayerCache = {};

function getBenchmarkPlayerName() {
  return sessionStorage.getItem("wowkb_benchmark_player") || 
         localStorage.getItem("wowkb_account_username") || 
         localStorage.getItem("wowkb_user_character") || "";
}

function setBenchmarkPlayer(name) {
  if (name && name.trim()) {
    sessionStorage.setItem("wowkb_benchmark_player", name.trim());
  } else {
    sessionStorage.removeItem("wowkb_benchmark_player");
  }
  loadLeaderboards();
}

async function loadLeaderboards() {
  const isPve = (currentFlavor === "FOREVER" && typeof getCurrentForeverServer === "function" && getCurrentForeverServer() === "PVE");
  if (isPve) {
    loadDeadlyNpcsView();
    return;
  }
  const container = document.getElementById("main-content-area");
  try {
    if (legendsTabType === "GUILDS") {
      const res = await fetch(`/api/guilds?mode=${currentMode}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      renderLeaderboardView(null, null, data.guilds || []);
    } else {
      const res = await fetch(`/api/leaderboard?mode=${currentMode}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();

      // Resolve benchmark profile if benchmark player is outside top killers
      const bmName = getBenchmarkPlayerName();
      let benchmarkProfile = null;
      if (bmName && data && data.topKillers) {
        const inTop = data.topKillers.find(p => p.name.toLowerCase() === bmName.toLowerCase());
        if (!inTop) {
          try {
            if (benchmarkPlayerCache[bmName.toLowerCase()]) {
              benchmarkProfile = benchmarkPlayerCache[bmName.toLowerCase()];
            } else {
              const charRes = await fetch(`/api/character/${encodeURIComponent(bmName)}`);
              if (charRes.ok) {
                benchmarkProfile = await charRes.json();
                benchmarkPlayerCache[bmName.toLowerCase()] = benchmarkProfile;
              }
            }
          } catch (e) {
            console.warn("Could not fetch benchmark profile:", e);
          }
        }
      }

      renderLeaderboardView(data, null, null, benchmarkProfile);
    }
  } catch (err) {
    console.error("Failed to load leaderboards:", err);
    if (container) {
      container.innerHTML = `
        <div style="background: linear-gradient(180deg, #1e1313 0%, #0a0505 100%); border: 1px solid #7f1d1d; border-radius: 8px; padding: 32px 24px; text-align: center; max-width: 640px; margin: 40px auto;">
          <div style="font-size: 2rem; margin-bottom: 12px;">⚔️</div>
          <h2 style="color: #ef4444; font-family: var(--font-cinzel, Cinzel, serif); font-size: 1.25rem; margin-bottom: 8px;">Defender of Azeroth Offline</h2>
          <p style="color: #94a3b8; font-size: 0.85rem; line-height: 1.6; margin-bottom: 16px;">
            The server was unable to retrieve combat records (${escapeHtml(err.message)}). If you are viewing on Render Cloud, click <strong>Manual Deploy &rarr; Deploy latest commit</strong> in your Render dashboard to complete database initialization, or view your local war room at <a href="http://localhost:8080" style="color: var(--wow-gold, #c69b3a); text-decoration: underline;">http://localhost:8080</a>.
          </p>
          <button class="pill-btn active" onclick="loadLeaderboards()" style="padding: 8px 20px; font-size: 0.85rem;">🔄 Retry Connection</button>
        </div>
      `;
    }
  }
}

function setLegendsTabType(type) {
  legendsTabType = type;
  loadLeaderboards();
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
  const isPve = (currentFlavor === "FOREVER" && typeof getCurrentForeverServer === "function" && getCurrentForeverServer() === "PVE");
  if (isPve) {
    loadPveBountiesView();
    return;
  }
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
    if (!bntRes.ok) throw new Error(`HTTP ${bntRes.status}`);
    const bounties = await bntRes.json();
    const debts = debtRes.ok ? await debtRes.json() : [];
    const leaderboards = lbRes.ok ? await lbRes.json() : {};
    renderBountiesView(bounties, debts, leaderboards);
  } catch (err) {
    console.error("Failed to load bounties:", err);
    if (container) {
      container.innerHTML = `
        <div style="background: linear-gradient(180deg, #1e1313 0%, #0a0505 100%); border: 1px solid #7f1d1d; border-radius: 8px; padding: 32px 24px; text-align: center; max-width: 640px; margin: 40px auto;">
          <div style="font-size: 2rem; margin-bottom: 12px;">📜</div>
          <h2 style="color: #ef4444; font-family: var(--font-cinzel, Cinzel, serif); font-size: 1.25rem; margin-bottom: 8px;">Marks of Spite Offline</h2>
          <p style="color: #94a3b8; font-size: 0.85rem; line-height: 1.6; margin-bottom: 16px;">
            The server was unable to retrieve bounty contracts (${escapeHtml(err.message)}). If you are viewing on Render Cloud, click <strong>Manual Deploy &rarr; Deploy latest commit</strong> in your Render dashboard to complete database initialization, or view your local war room at <a href="http://localhost:8080" style="color: var(--wow-gold, #c69b3a); text-decoration: underline;">http://localhost:8080</a>.
          </p>
          <button class="pill-btn active" onclick="loadBounties()" style="padding: 8px 20px; font-size: 0.85rem;">🔄 Retry Connection</button>
        </div>
      `;
    }
  }
}

// Rendering Functions
async function renderStats(kills) {
  const hubContainer = document.getElementById("homepage-stats-hub");

  const isPve = (currentFlavor === "FOREVER" && typeof getCurrentForeverServer === "function" && getCurrentForeverServer() === "PVE");
  if (isPve) {
    let pveSummary = { totalDeaths: 10, uniqueDeadlyNpcs: 8, mostDangerousZone: { zone: "Elwynn Forest", deaths: 3 } };
    try {
      const lbRes = await fetch("/api/pve/leaderboard");
      if (lbRes.ok) {
        const lb = await lbRes.json();
        if (lb.summary) pveSummary = lb.summary;
      }
    } catch (e) {}

    const deadZone = pveSummary.mostDangerousZone || { zone: "Elwynn Forest", deaths: 3 };
    const deadZoneStr = (deadZone.zone && deadZone.zone !== "None") ? `${deadZone.zone} (${deadZone.deaths} Slain)` : "Elwynn Forest";

    if (hubContainer) {
      hubContainer.innerHTML = `
        <div class="stats-hub-wrapper guest" style="border-color: rgba(56, 189, 248, 0.4);">
          <div class="guest-stats-header">
            <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:10px;">
              <div style="display:flex; align-items:center; gap:8px;">
                <span class="wow-gold-header" style="font-size:0.95rem; font-weight:800; letter-spacing:0.5px; color:#38bdf8;">THE SHADOW NETWORK — PVE HAZARD &amp; CASUALTY TELEMETRY (NORMAL PROGRESSION)</span>
              </div>
            </div>
          </div>

          <div class="stats-grid">
            <div class="stat-card">
              <span class="stat-label">Total Fallen Mortals</span>
              <span class="stat-val" id="stat-total-kills" style="color: #ef4444;">${formatNumber(pveSummary.totalDeaths)}</span>
            </div>
            <div class="stat-card">
              <span class="stat-label">Deadly Monster Slayers</span>
              <span class="stat-val" id="stat-solo-percent" style="color: var(--accent-gold);">${formatNumber(pveSummary.uniqueDeadlyNpcs)}</span>
            </div>
            <div class="stat-card">
              <span class="stat-label">Deadliest Conflict Zone</span>
              <span class="stat-val" id="stat-faction-split" style="color: #38bdf8; font-size: 0.95rem; padding-top: 4px;">
                ${escapeHtml(deadZoneStr)}
              </span>
            </div>
            <div class="stat-card">
              <span class="stat-label">Active Campaign</span>
              <span class="stat-val" id="stat-active-mode" style="color: #10b981; font-size: 0.95rem; padding-top: 4px;">Forever PvE</span>
            </div>
          </div>
        </div>
      `;
    }
    return;
  }

  // 1. Fetch cumulative server telemetry
  let cumulative = {
    total: kills.length,
    solo: kills.filter(k => k.isSolo).length,
    alliance: 0,
    horde: 0,
    active_bounties: 0,
    top_zone: "Hillsbrad Foothills"
  };

  try {
    const statsRes = await fetch("/api/stats");
    if (statsRes.ok) {
      const statsData = await statsRes.json();
      if (statsData.counts) {
        cumulative.total = statsData.counts.total ?? kills.length;
        cumulative.solo = statsData.counts.solo ?? kills.filter(k => k.isSolo).length;
        cumulative.alliance = statsData.counts.alliance ?? 0;
        cumulative.horde = statsData.counts.horde ?? 0;
        cumulative.active_bounties = statsData.counts.active_bounties ?? 0;
        cumulative.bounty_gold = statsData.counts.bounty_gold ?? 0;
        cumulative.top_zone = statsData.counts.top_zone ?? "Hillsbrad Foothills";
      }
    }
  } catch (e) {
    // Fallback to local kills array
  }

  // Calculate percentages
  const totalCarnage = cumulative.total;
  const soloPct = totalCarnage > 0 ? Math.round((cumulative.solo / totalCarnage) * 100) : 0;

  let aKills = cumulative.alliance;
  let hKills = cumulative.horde;
  if (aKills === 0 && hKills === 0) {
    kills.forEach(k => {
      if (k.killer && k.killer.faction === "Alliance") aKills++;
      else if (k.killer && k.killer.faction === "Horde") hKills++;
    });
  }
  const facTotal = aKills + hKills;
  const aPct = facTotal > 0 ? Math.round((aKills / facTotal) * 100) : 50;
  const hPct = facTotal > 0 ? 100 - aPct : 50;

  const modeNames = {
    WORLD: "World PvP",
    BG: "Battlegrounds",
    ARENA: "Arenas",
    DUEL: "Duels"
  };
  const activeModeName = modeNames[currentMode] || currentMode;

  // 2. Check operative account auth state
  const currentAuth = sessionStorage.getItem("wowkb_auth_type") || localStorage.getItem("wowkb_auth_type");
  const accountUser = localStorage.getItem("wowkb_account_username") || localStorage.getItem("wowkb_user_character") || "";
  const isSignedIn = Boolean(accountUser && (currentAuth === "account" || currentAuth === "officer"));

  if (!hubContainer) {
    const totalEl = document.getElementById("stat-total-kills");
    if (totalEl) totalEl.innerText = totalCarnage;
    const soloEl = document.getElementById("stat-solo-percent");
    if (soloEl) soloEl.innerText = `${soloPct}%`;
    const factionEl = document.getElementById("stat-faction-split");
    if (factionEl) {
      factionEl.innerHTML = `<span style="color: var(--alliance-blue); font-weight:800;">A: ${aPct}%</span> <span style="color:#64748b;">|</span> <span style="color: var(--horde-red); font-weight:800;">H: ${hPct}%</span>`;
    }
    const modeEl = document.getElementById("stat-active-mode");
    if (modeEl) modeEl.innerText = activeModeName;
    return;
  }

  // 3. Render Personalized Operative Stats if Signed In
  if (isSignedIn) {
    let charData = {
      name: accountUser,
      class: "WARRIOR",
      faction: localStorage.getItem("wowkb_user_faction") || "Alliance",
      rankTitle: "Private",
      stats: { kills: 0, deaths: 0, kd: 0.0, soloKills: 0 }
    };

    try {
      const charRes = await fetch(`/api/character/${encodeURIComponent(accountUser)}`);
      if (charRes.ok) {
        const fetched = await charRes.json();
        if (fetched && fetched.name) {
          charData = fetched;
        }
      }
    } catch (err) {
      // Use defaults
    }

    const uKills = charData.stats?.kills ?? 0;
    const uDeaths = charData.stats?.deaths ?? 0;
    const uKd = charData.stats?.kd ?? (uDeaths > 0 ? (uKills / uDeaths).toFixed(1) : uKills.toFixed(1));
    const uSolo = charData.stats?.soloKills ?? 0;
    const uFaction = charData.faction || "Alliance";
    const factionColor = (uFaction === "Horde") ? "var(--horde-red)" : "var(--alliance-blue)";
    const uRank = charData.rankTitle || "Operative";

    const pct = charData.percentile || {
      percentile: 95.0,
      topPct: 5.0,
      rank: 1,
      totalInCohort: 1,
      cohortLabel: `Level ${charData.level || 60} ${charData.spec ? charData.spec + ' ' : ''}${charData.class || 'Warrior'}`,
      spec: charData.spec || 'Arms'
    };

    hubContainer.innerHTML = `
      <div class="stats-hub-wrapper signed-in">
        <!-- Personalized Operative Hero Banner -->
        <div class="operative-hero-strip">
          <div class="operative-hero-left">
            <div class="officer-sigil-badge" style="width:42px; height:42px;">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--wow-gold)" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
            </div>
            <div>
              <div class="operative-title-row">
                <span class="operative-name" style="cursor:pointer;" onclick="openCharacterProfile('${escapeHtml(accountUser)}')">${escapeHtml(accountUser)}</span>
                <span class="operative-rank-tag">${escapeHtml(uRank)}</span>
                <span class="operative-percentile-pill" title="${escapeHtml(pct.cohortLabel)} (${pct.totalInCohort} combatants)">
                  Top ${pct.topPct}% (${pct.percentile}th Pct)
                </span>
                <span class="operative-flavor-tag">WoW Forever</span>
              </div>
              <div class="operative-sub-row">
                Allegiance: <strong style="color:${factionColor};">${escapeHtml(uFaction)}</strong> &bull; Class &amp; Spec: <strong>${escapeHtml(charData.spec ? charData.spec + ' ' : '')}${escapeHtml(charData.class || 'Champion')}</strong> &bull; Standing: <strong style="color:var(--wow-gold-bright, #ffe680);">${escapeHtml(pct.cohortLabel)} &bull; Rank #${pct.rank} of ${pct.totalInCohort}</strong>
              </div>
            </div>
          </div>
          <div class="operative-hero-actions">
            <button class="operative-action-btn" onclick="openCharacterProfile('${escapeHtml(accountUser)}')">
              <span>View Full Armory Profile</span>
              <span>&rarr;</span>
            </button>
          </div>
        </div>

        <!-- 4 Personalized Operative Metrics -->
        <div class="operative-metrics-grid">
          <div class="stat-card operative-card">
            <span class="stat-label">Your Confirmed Kills</span>
            <span class="stat-val highlight-gold">${formatNumber(uKills)}</span>
          </div>
          <div class="stat-card operative-card">
            <span class="stat-label">Your Casualties (Deaths)</span>
            <span class="stat-val highlight-red">${formatNumber(uDeaths)}</span>
          </div>
          <div class="stat-card operative-card">
            <span class="stat-label">Your K/D Ratio</span>
            <span class="stat-val highlight-green">${uKd}</span>
          </div>
          <div class="stat-card operative-card">
            <span class="stat-label">Your Solo Kills (1v1)</span>
            <span class="stat-val highlight-cyan">${formatNumber(uSolo)}</span>
          </div>
        </div>

        <!-- Divider to Cumulative Frontier Stats -->
        <div class="stats-section-divider">
          <span>THE SHADOW NETWORK — CUMULATIVE COMBAT INTELLIGENCE (ALL STATS)</span>
        </div>

        <!-- 4 Cumulative Frontier Metrics -->
        <div class="stats-grid">
          <div class="stat-card">
            <span class="stat-label">Realm Total Carnage</span>
            <span class="stat-val" id="stat-total-kills">${formatNumber(totalCarnage)}</span>
          </div>
          <div class="stat-card">
            <span class="stat-label">1v1 Solo Kill Ratio</span>
            <span class="stat-val" id="stat-solo-percent" style="color: #10b981;">${soloPct}%</span>
          </div>
          <div class="stat-card">
            <span class="stat-label">Faction War Split</span>
            <span class="stat-val" id="stat-faction-split" style="font-size: 0.95rem; padding-top: 4px;">
              <span style="color: var(--alliance-blue); font-weight:800;">A: ${aPct}%</span> <span style="color:#64748b;">|</span> <span style="color: var(--horde-red); font-weight:800;">H: ${hPct}%</span>
            </span>
          </div>
          <div class="stat-card">
            <span class="stat-label">Active Combat Filter</span>
            <span class="stat-val" id="stat-active-mode" style="color: var(--accent-cyan); font-size: 0.95rem; padding-top: 4px;">${activeModeName}</span>
          </div>
        </div>
      </div>
    `;
    return;
  }

  // 4. Render Cumulative Stats for Guest
  hubContainer.innerHTML = `
    <div class="stats-hub-wrapper guest">
      <div class="guest-stats-header">
        <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:10px;">
          <div style="display:flex; align-items:center; gap:8px;">
            <span class="wow-gold-header" style="font-size:0.95rem; font-weight:800; letter-spacing:0.5px;">THE SHADOW NETWORK — CUMULATIVE COMBAT TELEMETRY (ALL STATS)</span>
          </div>
        </div>
      </div>

      <div class="stats-grid">
        <div class="stat-card">
          <span class="stat-label">Realm Total Carnage</span>
          <span class="stat-val" id="stat-total-kills">${formatNumber(totalCarnage)}</span>
        </div>
        <div class="stat-card">
          <span class="stat-label">1v1 Solo Kill Ratio</span>
          <span class="stat-val" id="stat-solo-percent" style="color: #10b981;">${soloPct}%</span>
        </div>
        <div class="stat-card">
          <span class="stat-label">Faction War Split</span>
          <span class="stat-val" id="stat-faction-split" style="font-size: 0.95rem; padding-top: 4px;">
            <span style="color: var(--alliance-blue); font-weight:800;">A: ${aPct}%</span> <span style="color:#64748b;">|</span> <span style="color: var(--horde-red); font-weight:800;">H: ${hPct}%</span>
          </span>
        </div>
        <div class="stat-card">
          <span class="stat-label">Active Combat Filter</span>
          <span class="stat-val" id="stat-active-mode" style="color: var(--accent-cyan); font-size: 0.95rem; padding-top: 4px;">${activeModeName}</span>
        </div>
      </div>
    </div>
  `;
}

let feedDisplayLimit = 15;

function feedShowMoreKills() {
  feedDisplayLimit += 15;
  if (cachedKills && cachedKills.length > 0) {
    renderFeed(cachedKills);
  }
}

function getWowLogsPercentileBadge(pct) {
  if (pct === null || pct === undefined) {
    return `<span style="color:#64748b; font-size:0.75rem;">-</span>`;
  }
  let p = typeof pct === 'number' ? pct : pct.percentile;
  if (typeof p !== 'number') {
    return `<span style="color:#64748b; font-size:0.75rem;">-</span>`;
  }
  let topPct = (typeof pct === 'object' && typeof pct.topPct !== 'undefined') ? pct.topPct : Math.max(1, 100 - p);
  let cohortLabel = (typeof pct === 'object' && pct.cohortLabel) ? pct.cohortLabel : 'Cohort';
  let totalInCohort = (typeof pct === 'object' && pct.totalInCohort) ? pct.totalInCohort : 0;

  let color = "#9d9d9d";      // 0-24 Grey (Common)
  let bg = "rgba(157, 157, 157, 0.12)";
  let border = "rgba(157, 157, 157, 0.3)";
  
  if (p >= 100) {
    color = "#e5cc80";        // 100 Gold / Artifact
    bg = "rgba(229, 204, 128, 0.18)";
    border = "rgba(229, 204, 128, 0.5)";
  } else if (p >= 99) {
    color = "#e268a8";        // 99 Pink
    bg = "rgba(226, 104, 168, 0.18)";
    border = "rgba(226, 104, 168, 0.5)";
  } else if (p >= 95) {
    color = "#ff8000";        // 95-98 Orange (Legendary)
    bg = "rgba(255, 128, 0, 0.18)";
    border = "rgba(255, 128, 0, 0.5)";
  } else if (p >= 75) {
    color = "#a335ee";        // 75-94 Purple (Epic)
    bg = "rgba(163, 53, 238, 0.18)";
    border = "rgba(163, 53, 238, 0.5)";
  } else if (p >= 50) {
    color = "#0070dd";        // 50-74 Blue (Rare)
    bg = "rgba(0, 112, 221, 0.18)";
    border = "rgba(0, 112, 221, 0.5)";
  } else if (p >= 25) {
    color = "#1eff00";        // 25-49 Green (Uncommon)
    bg = "rgba(30, 255, 0, 0.18)";
    border = "rgba(30, 255, 0, 0.5)";
  }
  
  const title = escapeHtml(`${cohortLabel} (${totalInCohort} combatants)`);
  return `
    <span class="wowlogs-percentile-text" title="${title}" style="color:${color}; font-family:var(--font-tactical); font-weight:800; font-size:0.80rem; letter-spacing:0.3px;">
      <span>Top ${topPct}%</span>
      <span style="opacity:0.75; font-size:0.70rem; margin-left:3px;">(${p}th)</span>
    </span>
  `;
}

function renderFeed(kills) {
  const container = document.getElementById("main-content-area");
  let modeFilteredKills = kills || [];
  if (currentMode === "WORLD") {
    modeFilteredKills = modeFilteredKills.filter(km => !km.isBattleground && !km.isArena && !km.isDuel);
  } else if (currentMode === "BG") {
    modeFilteredKills = modeFilteredKills.filter(km => km.isBattleground);
  } else if (currentMode === "ARENA") {
    modeFilteredKills = modeFilteredKills.filter(km => km.isArena);
  } else if (currentMode === "DUEL") {
    modeFilteredKills = modeFilteredKills.filter(km => km.isDuel);
  }

  const modeLabelHeader = currentMode === "BG" ? "Battleground" : (currentMode === "DUEL" ? "Duel" : (currentMode === "ARENA" ? "Arena" : "Open World"));
  const modePillText = currentMode === "BG" ? "Battlegrounds" : (currentMode === "DUEL" ? "1v1 Duels" : (currentMode === "ARENA" ? "Arenas" : "Open World"));

  if (modeFilteredKills.length === 0) {
    container.innerHTML = `
      <div style="text-align: center; padding: 40px; color: #64748b;">
        <h3>No ${modeLabelHeader} PvP records found yet.</h3>
        <p style="margin-top: 8px;">Engage in combat across Azeroth to populate the feed.</p>
      </div>
    `;
    return;
  }

  const visibleKills = modeFilteredKills.slice(0, feedDisplayLimit);

  let html = `
    <div style="display: flex; flex-direction: column; gap: 6px;">
      <div class="feed-header-wrap" style="display:flex; justify-content:space-between; align-items:center; margin-bottom:4px; padding-bottom:8px; border-bottom:1px solid var(--wow-brass-border, #4a3b27); gap:10px; flex-wrap:wrap;">
        <div style="display:flex; align-items:center; gap:8px;">
          <span class="wow-gold-header" style="font-size:1.05rem; font-weight:800; letter-spacing:0.5px;">THE SHADOW NETWORK &mdash; RECENT COMBAT FEED</span>
          <span class="feed-count-pill">${modeFilteredKills.length}</span>
          <span style="font-size:0.75rem; color:#10b981; font-weight:700; background:rgba(16,185,129,0.12); padding:2px 8px; border-radius:4px; border:1px solid rgba(16,185,129,0.25);">${modePillText}</span>
          <button class="pill-btn" onclick="loadKills(); loadSidebar();" title="Refresh Live Combat Feed" style="padding:2px 8px; font-size:0.75rem; background:rgba(255,255,255,0.06); cursor:pointer;">🔄 Refresh</button>
        </div>
        <span style="font-size:0.75rem; color:#856a36;">The Shadow Network &bull; Type <code style="color:var(--wow-gold);">/reload</code> in WoW to sync</span>
      </div>
  `;
  visibleKills.forEach(km => {
    let modeClass = "km-world";
    let modeLabel = "Open World";
    let modeTagText = "WORLD";
    if (km.isDuel) {
      modeClass = "km-duel";
      modeLabel = "1v1 Duel";
      modeTagText = "1v1 DUEL";
    } else if (km.isArena) {
      modeClass = "km-arena";
      modeLabel = "Arena Match";
      modeTagText = "ARENA";
    } else if (km.isBattleground) {
      modeClass = "km-bg";
      modeLabel = `Battleground (${km.battlegroundName || "BG"})`;
      modeTagText = "BG";
    } else if (km.isSolo) {
      modeClass = "km-solo";
      modeLabel = "1v1 Solo Kill";
      modeTagText = "1v1 SOLO";
    } else {
      modeClass = "km-gang";
      modeLabel = `Gang Kill (${km.attackersCount} Attackers)`;
      modeTagText = `GANG x${km.attackersCount}`;
    }

    // Determine victor faction (Alliance Blue vs Horde Red)
    let killerFaction = ((km.killer && km.killer.faction) || '').trim();
    if (!killerFaction && km.killer && km.killer.class) {
      const kc = km.killer.class.toUpperCase();
      if (kc === 'PALADIN') killerFaction = 'Alliance';
      else if (kc === 'SHAMAN') killerFaction = 'Horde';
    }
    let victorClass = 'winner-neutral';
    if (killerFaction.toLowerCase() === 'alliance') victorClass = 'winner-alliance';
    else if (killerFaction.toLowerCase() === 'horde') victorClass = 'winner-horde';

    const killerBadge = renderClassBadge(km.killer.class, 26);
    const victimBadge = renderClassBadge(km.victim.class, 26);
    const killerSpan = colorizeClass(km.killer.name, km.killer.class);
    const victimSpan = colorizeClass(km.victim.name, km.victim.class);

    const killerGuildName = (km.killer.guild && km.killer.guild !== 'None') ? km.killer.guild : '';
    const victimGuildName = (km.victim.guild && km.victim.guild !== 'None') ? km.victim.guild : '';

    const killerGuildHtml = killerGuildName
      ? `<span class="clickable-guild km-guild-sub-text" onclick="event.stopPropagation(); openGuildProfile('${killerGuildName}')">&lt;${killerGuildName}&gt;</span>`
      : `<span class="km-guild-none">&lt;Unguilded&gt;</span>`;

    const victimGuildHtml = victimGuildName
      ? `<span class="clickable-guild km-guild-sub-text" onclick="event.stopPropagation(); openGuildProfile('${victimGuildName}')">&lt;${victimGuildName}&gt;</span>`
      : `<span class="km-guild-none">&lt;Unguilded&gt;</span>`;

    const subzoneOrCoords = km.location.subZone ? km.location.subZone : `${(km.location.x || 0).toFixed(1)}, ${(km.location.y || 0).toFixed(1)}`;
    const rowTooltip = `${km.killer.name} defeated ${km.victim.name} • ${modeLabel} • ${km.location.zone} • Click for Battle Report`;

    const killerLvlStr = (km.killer && km.killer.level && km.killer.level > 0) ? `(${km.killer.level})` : '??';
    const victimLvlStr = (km.victim && km.victim.level && km.victim.level > 0) ? `(${km.victim.level})` : '??';

    const isBounty = km.isBountyClaim || (km.bountyRewardGold && km.bountyRewardGold > 0) || (km.bounty && (km.bounty.amountGold > 0 || km.bounty.amountCopper > 0));
    const bountyRowClass = isBounty ? "bounty-claimed-row" : "";
    const bountyGoldVal = km.bountyRewardGold || (km.bounty && km.bounty.amountGold) || 0;
    const bountyTag = isBounty ? `<span class="km-bounty-claimed-tag">💰 BOUNTY CLAIMED${bountyGoldVal > 0 ? ` (${formatNumber(bountyGoldVal)}g)` : ''}</span>` : "";

    html += `
      <div class="killmail-row ${modeClass} ${victorClass} ${bountyRowClass}" onclick="openKillModal('${km.killId}')" title="${rowTooltip}">
        <div class="km-left-meta">
          <span class="km-zone-name">${km.location.zone}</span>
          <span class="km-subzone-text">${subzoneOrCoords}</span>
        </div>

        <div class="km-combatants-center">
          <div class="km-combatant-col killer">
            <div class="km-player-row">
              <span class="clickable-player" onclick="event.stopPropagation(); openCharacterProfile('${km.killer.name}')">${killerSpan}</span>
              <span class="km-lvl">${killerLvlStr}</span>
              ${killerBadge}
            </div>
            <div class="km-guild-sub">
              ${killerGuildHtml}
            </div>
          </div>

          <div class="km-vs-wrapper">
            <span class="km-vs" title="${km.isDuel ? 'Defeated in 1v1 Duel' : (km.isSolo ? 'Slew in 1v1 Combat' : 'Slew in Combat')}">VS</span>
          </div>

          <div class="km-combatant-col victim">
            <div class="km-player-row">
              ${victimBadge}
              <span class="clickable-player" onclick="event.stopPropagation(); openCharacterProfile('${km.victim.name}')">${victimSpan}</span>
              <span class="km-lvl">${victimLvlStr}</span>
            </div>
            <div class="km-guild-sub">
              ${victimGuildHtml}
            </div>
          </div>
        </div>

        <div class="km-right-meta">
          ${bountyTag}
          <span class="km-mode-tag ${modeClass}">${modeTagText}</span>
          <span class="km-time">${timeAgo(km.timestamp)}</span>
        </div>
      </div>
    `;
  });

  if (modeFilteredKills.length > visibleKills.length) {
    html += `
      <div class="feed-view-more-wrap">
        <button class="feed-view-more-btn" onclick="feedShowMoreKills()">
          <span>View More Combat Records (Showing ${visibleKills.length} of ${modeFilteredKills.length})</span>
          <span>&darr;</span>
        </button>
      </div>
    `;
  }

  html += `</div>`;
  container.innerHTML = html;
}

function renderLeaderboardView(data, bgData, guildsData, benchmarkProfile) {
  const container = document.getElementById("main-content-area");
  if (!container) return;

  const isGuilds = (legendsTabType === "GUILDS");

  let html = `
    <div style="display: flex; flex-direction: column; gap: 16px;">
      <!-- Champions Header Row with Type Toggle and Mode Pills -->
      <div class="legends-header-row" style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:14px; padding-bottom:8px; border-bottom:1px solid var(--wow-brass-border, #4a3b27); margin-bottom:4px;">
        <div>
          <h2 class="wow-gold-header" style="font-size: 1.25rem; font-weight:800; letter-spacing:0.5px; margin:0;">
            Defender of Azeroth
          </h2>
          <div style="font-size:0.75rem; color:#856a36; margin-top:2px;">
            ${isGuilds ? 'Premier guild war standings, total kills, and combat effectiveness across Azeroth.' : 'Most lethal combatants, rank efficiency, and certified executions across Azeroth.'}
          </div>
        </div>

        <div class="legends-header-controls" style="display:flex; align-items:center; gap:12px; flex-wrap:wrap;">
          <!-- Rank Type Toggle: Players vs Guilds -->
          <div class="filter-pills" id="legends-type-pills">
            <button class="pill-btn ${!isGuilds ? 'active' : ''}" onclick="setLegendsTabType('PLAYERS')">Player Ranks</button>
            <button class="pill-btn ${isGuilds ? 'active' : ''}" onclick="setLegendsTabType('GUILDS')">Guild Ranks</button>
          </div>

          <!-- Mode Toggle: World / BGs / Duels / Arenas (greyed out) -->
          <div class="filter-pills" id="champions-mode-pills" style="display:flex; align-items:center; gap:4px;">
            <button class="pill-btn ${currentMode === 'WORLD' ? 'active' : ''}" onclick="setFilterMode('WORLD')">World</button>
            <button class="pill-btn ${currentMode === 'BG' ? 'active' : ''}" onclick="setFilterMode('BG')">BGs</button>
            <button class="pill-btn ${currentMode === 'DUEL' ? 'active' : ''}" onclick="setFilterMode('DUEL')">Duels</button>
            <button class="pill-btn disabled" style="opacity:0.4; cursor:not-allowed;" title="Arenas unavailable in Classic Era and WoW Forever" onclick="alert('Arenas are unavailable in Classic Era and WoW Forever. Switch the flavor in the top bar to TBC, WotLK, or Retail to enable Arena ladders.')">Arenas</button>
          </div>
        </div>
      </div>
  `;

  if (isGuilds) {
    const guilds = guildsData || [];
    html += `
      <div class="legends-table-wrapper" style="background: linear-gradient(180deg, #0a0d14 0%, #030407 100%); border: 1px solid var(--wow-brass-border, #4a3b27); box-shadow: inset 0 0 18px rgba(0, 0, 0, 0.88), 0 2px 8px rgba(0, 0, 0, 0.5); border-radius: 6px; padding: 14px 16px; overflow-x: auto; -webkit-overflow-scrolling: touch; width: 100%;">
        <div class="mobile-table-scroll-hint" style="display:none; justify-content:space-between; align-items:center; font-size:0.68rem; color:#856a36; font-family:var(--font-tactical); padding-bottom:6px; letter-spacing:0.3px;">
          <span>⟵ Drag table to view all combat stats</span>
          <span>8 Columns ⟶</span>
        </div>
        <table class="legends-table" style="width: 100%; min-width: 740px; border-collapse: collapse; font-size: 0.85rem; table-layout: fixed;">
          <colgroup>
            <col style="width: 55px;">
            <col style="width: 160px;">
            <col style="width: 90px;">
            <col style="width: 90px;">
            <col style="width: 70px;">
            <col style="width: 70px;">
            <col style="width: 65px;">
            <col style="width: 140px;">
          </colgroup>
          <thead>
            <tr style="border-bottom: 1px solid var(--wow-brass-border, #4a3b27); color: #856a36; font-family: var(--font-tactical); font-size: 0.72rem; letter-spacing: 0.05em; text-transform: uppercase; text-align: left; height: 36px;">
              <th style="padding: 6px 10px; width: 60px;">Rank</th>
              <th style="padding: 6px 10px;">Guild</th>
              <th style="padding: 6px 10px;">Faction</th>
              <th style="padding: 6px 10px;">Combatants</th>
              <th style="padding: 6px 10px;">Kills</th>
              <th style="padding: 6px 10px;">Deaths</th>
              <th style="padding: 6px 10px;">K/D</th>
              <th style="padding: 6px 10px;">Top Assassin</th>
            </tr>
          </thead>
          <tbody>
    `;
    if (guilds.length === 0) {
      html += `<tr><td colspan="8" style="text-align:center; padding:30px; color:#64748b;">No active guild combat records recorded yet for mode [${currentMode}].</td></tr>`;
    } else {
      guilds.forEach((g, idx) => {
        const topMemberHtml = g.topMember 
          ? `<span class="clickable-player" onclick="openCharacterProfile('${escapeHtml(g.topMember.name)}')">${colorizeClass(g.topMember.name, g.topMember.class)}</span> <small style="color:#10b981;">(${g.topMember.kills}k)</small>`
          : '-';

        html += `
          <tr style="border-bottom: 1px solid rgba(255,255,255,0.04); height: 38px; transition: background 0.15s ease;" onmouseover="this.style.background='rgba(255,255,255,0.02)'" onmouseout="this.style.background=''">
            <td style="padding: 6px 10px; color: var(--accent-gold); font-weight: 800; white-space: nowrap;">#${idx + 1}</td>
            <td style="padding: 6px 10px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;"><span class="clickable-guild" onclick="openGuildProfile('${escapeHtml(g.guild)}')">&lt;${escapeHtml(g.guild)}&gt;</span></td>
            <td style="padding: 6px 10px; color: ${g.faction === 'Alliance' ? '#3b82f6' : '#ef4444'}; white-space: nowrap;">${escapeHtml(g.faction || 'Neutral')}</td>
            <td style="padding: 6px 10px; color: #e2e8f0; white-space: nowrap;">${g.members_count || 1}</td>
            <td style="padding: 6px 10px; color: #10b981; font-weight: 700; white-space: nowrap;">${g.kills}</td>
            <td style="padding: 6px 10px; color: #ef4444; font-weight: 700; white-space: nowrap;">${g.deaths || 0}</td>
            <td style="padding: 6px 10px; color: var(--accent-gold); font-weight: 700; white-space: nowrap;">${g.kd}</td>
            <td style="padding: 6px 10px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">${topMemberHtml}</td>
          </tr>
        `;
      });
    }
    html += `
          </tbody>
        </table>
      </div>
    `;
  } else {
    const killers = (data && data.topKillers) ? data.topKillers : [];
    const topRank1 = killers.length > 0 ? killers[0] : null;
    const bmName = getBenchmarkPlayerName();

    let bmMatch = null;
    let bmRank = null;
    if (bmName && killers.length > 0) {
      const foundIdx = killers.findIndex(p => p.name.toLowerCase() === bmName.toLowerCase());
      if (foundIdx !== -1) {
        bmMatch = killers[foundIdx];
        bmRank = foundIdx + 1;
      }
    }

    const isAccountUser = Boolean(
      (localStorage.getItem("wowkb_account_username") && localStorage.getItem("wowkb_account_username").toLowerCase() === (bmName || '').toLowerCase()) ||
      (localStorage.getItem("wowkb_user_character") && localStorage.getItem("wowkb_user_character").toLowerCase() === (bmName || '').toLowerCase())
    );

    // Render Operative Benchmark Comparison Banner
    if (bmName) {
      const bmClass = bmMatch ? bmMatch.class : (benchmarkProfile && benchmarkProfile.character ? benchmarkProfile.character.class : 'WARRIOR');
      const bmFaction = bmMatch ? bmMatch.faction : (benchmarkProfile && benchmarkProfile.character ? benchmarkProfile.character.faction : 'Alliance');
      const bmKills = bmMatch ? bmMatch.kills : (benchmarkProfile ? (benchmarkProfile.total_kills || 0) : 0);
      const bmSolo = bmMatch ? (bmMatch.solo_kills || 0) : (benchmarkProfile ? (benchmarkProfile.solo_kills || 0) : 0);
      const bmPct = bmMatch ? bmMatch.percentile : (benchmarkProfile && benchmarkProfile.percentile ? benchmarkProfile.percentile : { percentile: 50, topPct: 50, cohortLabel: 'Operative Benchmark', totalInCohort: 100 });
      const pctBadge = getWowLogsPercentileBadge(bmPct);
      const factionThemeClass = bmFaction === 'Horde' ? 'benchmark-horde' : 'benchmark-alliance';

      const rankDisplay = bmRank ? `#${bmRank}` : '#>15';
      let deltaDisplay = '-';
      let deltaColor = '#94a3b8';
      if (topRank1) {
        if (topRank1.name.toLowerCase() === bmName.toLowerCase()) {
          deltaDisplay = '⭐ #1 Apex Leader';
          deltaColor = 'var(--accent-gold)';
        } else {
          const diff = Math.max(0, (topRank1.kills || 0) - bmKills);
          deltaDisplay = `-${diff} kills to #1 (${escapeHtml(topRank1.name)})`;
          deltaColor = '#ef4444';
        }
      }

      html += `
        <div class="legends-comparison-banner ${factionThemeClass}" style="background: linear-gradient(180deg, #0a0d14 0%, #030407 100%); border: 1px solid var(--wow-brass-border, #4a3b27); box-shadow: inset 0 0 16px rgba(0, 0, 0, 0.88), 0 2px 8px rgba(0, 0, 0, 0.5); border-radius: 6px; padding: 12px 16px; margin-bottom: 4px;">
          <div style="display:flex; align-items:center; gap:12px;">
            <div style="display:flex; align-items:center; gap:8px;">
              <span style="font-size:1.15rem;">⚔️</span>
              <div>
                <div style="font-size:0.68rem; color:var(--wow-gold, #f59e0b); font-weight:800; letter-spacing:0.5px;">CHAMPION BENCHMARK COMPARISON</div>
                <div style="font-size:0.95rem; font-weight:700;">
                  <span class="clickable-player" onclick="openCharacterProfile('${escapeHtml(bmName)}')">${renderClassBadge(bmClass, 18)} ${colorizeClass(bmName, bmClass)}</span>
                  <span class="you-badge">${isAccountUser ? 'YOU' : 'BENCHMARK'}</span>
                </div>
              </div>
            </div>
          </div>

          <div class="benchmark-stats-row" style="display:flex; align-items:center; gap:16px; flex-wrap:wrap;">
            <div>
              <div style="font-size:0.68rem; color:#856a36; font-family:var(--font-tactical); font-weight:800;">RANK</div>
              <div style="font-size:0.9rem; font-weight:800; color:var(--accent-gold);">${rankDisplay}</div>
            </div>
            <div>
              <div style="font-size:0.68rem; color:#856a36; font-family:var(--font-tactical); font-weight:800;">KILLS</div>
              <div style="font-size:0.9rem; font-weight:800; color:#10b981;">${bmKills}</div>
            </div>
            <div>
              <div style="font-size:0.68rem; color:#856a36; font-family:var(--font-tactical); font-weight:800;">SOLO</div>
              <div style="font-size:0.9rem; font-weight:800; color:#00e5ff;">${bmSolo}</div>
            </div>
            <div>
              <div style="font-size:0.68rem; color:#856a36; font-family:var(--font-tactical); font-weight:800;">DELTA VS #1</div>
              <div style="font-size:0.85rem; font-weight:700; color:${deltaColor};">${deltaDisplay}</div>
            </div>
            <div>
              <div style="font-size:0.68rem; color:#856a36; font-family:var(--font-tactical); font-weight:800;">PERCENTILE</div>
              <div>${pctBadge}</div>
            </div>
            <div class="benchmark-input-wrap" style="display:flex; align-items:center; gap:6px;">
              <input type="text" id="benchmark-callsign-input" placeholder="Compare champion..." style="background:#07090e; border:1px solid #334155; color:#fff; font-size:0.75rem; padding:4px 8px; border-radius:4px; width:130px;" onkeydown="if(event.key==='Enter') setBenchmarkPlayer(this.value)">
              <button onclick="setBenchmarkPlayer(document.getElementById('benchmark-callsign-input').value)" class="pill-btn" style="padding:4px 8px; font-size:0.72rem;">Compare</button>
              ${sessionStorage.getItem("wowkb_benchmark_player") ? `<button onclick="setBenchmarkPlayer('')" class="pill-btn" style="padding:4px 6px; font-size:0.7rem; color:#ef4444;" title="Reset Benchmark">&times;</button>` : ''}
            </div>
          </div>
        </div>
      `;
    } else {
      html += `
        <div class="legends-comparison-banner" style="background: linear-gradient(180deg, #0a0d14 0%, #030407 100%); border: 1px dashed rgba(212, 163, 41, 0.45); box-shadow: inset 0 0 16px rgba(0, 0, 0, 0.88), 0 2px 8px rgba(0, 0, 0, 0.5); border-radius: 6px; padding: 12px 16px; margin-bottom: 4px;">
          <div style="display:flex; align-items:center; gap:10px;">
            <span style="font-size:1.1rem;">⚔️</span>
            <span style="font-size:0.82rem; color:#cbd5e1;">Benchmark your champion standing against realm leaders:</span>
          </div>
          <div class="benchmark-input-wrap" style="display:flex; align-items:center; gap:8px;">
            <input type="text" id="benchmark-callsign-input" placeholder="Enter Champion Name..." style="background:#07090e; border:1px solid #334155; color:#fff; font-size:0.75rem; padding:4px 10px; border-radius:4px; width:180px;" onkeydown="if(event.key==='Enter') setBenchmarkPlayer(this.value)">
            <button onclick="setBenchmarkPlayer(document.getElementById('benchmark-callsign-input').value)" class="pill-btn active" style="padding:4px 12px; font-size:0.75rem;">Benchmark</button>
          </div>
        </div>
      `;
    }

    html += `
      <div class="legends-table-wrapper" style="background: linear-gradient(180deg, #0a0d14 0%, #030407 100%); border: 1px solid var(--wow-brass-border, #4a3b27); box-shadow: inset 0 0 18px rgba(0, 0, 0, 0.88), 0 2px 8px rgba(0, 0, 0, 0.5); border-radius: 6px; padding: 14px 16px; overflow-x: auto; -webkit-overflow-scrolling: touch; width: 100%;">
        <div class="mobile-table-scroll-hint" style="display:none; justify-content:space-between; align-items:center; font-size:0.68rem; color:#856a36; font-family:var(--font-tactical); padding-bottom:6px; letter-spacing:0.3px;">
          <span>⟵ Drag table to view all combat stats</span>
          <span>7 Columns ⟶</span>
        </div>
        <table class="legends-table" style="width: 100%; min-width: 710px; border-collapse: collapse; font-size: 0.85rem; table-layout: fixed;">
          <colgroup>
            <col style="width: 55px;">
            <col style="width: 180px;">
            <col style="width: 130px;">
            <col style="width: 90px;">
            <col style="width: 70px;">
            <col style="width: 75px;">
            <col style="width: 110px;">
          </colgroup>
          <thead>
            <tr style="border-bottom: 1px solid var(--wow-brass-border, #4a3b27); color: #856a36; font-family: var(--font-tactical); font-size: 0.72rem; letter-spacing: 0.05em; text-transform: uppercase; text-align: left; height: 36px;">
              <th style="padding: 6px 10px; width: 55px;">Rank</th>
              <th style="padding: 6px 10px;">Combatant</th>
              <th style="padding: 6px 10px;">Guild</th>
              <th style="padding: 6px 10px;">Faction</th>
              <th style="padding: 6px 10px;">Kills</th>
              <th style="padding: 6px 10px;">Solo Kills</th>
              <th style="padding: 6px 10px; text-align:right;">Percentile</th>
            </tr>
          </thead>
          <tbody>
    `;

    if (killers.length === 0) {
      html += `<tr><td colspan="7" style="text-align:center; padding:30px; color:#64748b;">No combatant kills logged for mode [${currentMode}].</td></tr>`;
    } else {
      killers.forEach((p, idx) => {
        const guildHtml = (p.guild && p.guild !== 'None')
          ? `<span class="clickable-guild" onclick="openGuildProfile('${escapeHtml(p.guild)}')">${escapeHtml(p.guild)}</span>`
          : '-';

        const pctBadge = getWowLogsPercentileBadge(p.percentile);
        const isCurrent = Boolean(bmName && p.name.toLowerCase() === bmName.toLowerCase());
        const rowClass = isCurrent ? 'class="current-player-row"' : '';
        const youBadge = isCurrent ? `<span class="you-badge">${isAccountUser ? 'YOU' : 'BENCHMARK'}</span>` : '';

        html += `
          <tr ${rowClass} style="border-bottom: 1px solid rgba(255,255,255,0.04); height: 38px; transition: background 0.15s ease;" onmouseover="this.style.background='rgba(255,255,255,0.02)'" onmouseout="this.style.background=''">
            <td style="padding: 6px 10px; color: var(--accent-gold); font-weight: 800; white-space: nowrap;">#${idx + 1}</td>
            <td style="padding: 6px 10px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
              <span class="clickable-player" style="display:inline-flex; align-items:center; gap:6px;" onclick="openCharacterProfile('${escapeHtml(p.name)}')">
                ${renderClassBadge(p.class, 18)} ${colorizeClass(p.name, p.class)} ${youBadge}
              </span>
            </td>
            <td style="padding: 6px 10px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">${guildHtml}</td>
            <td style="padding: 6px 10px; color: ${p.faction === 'Alliance' ? '#3b82f6' : '#ef4444'}; white-space: nowrap;">${escapeHtml(p.faction || 'Neutral')}</td>
            <td style="padding: 6px 10px; color: #10b981; font-weight: 700; white-space: nowrap;">${p.kills}</td>
            <td style="padding: 6px 10px; color: #00e5ff; font-weight: 700; white-space: nowrap;">${p.solo_kills || 0}</td>
            <td style="padding: 6px 10px; text-align:right; white-space: nowrap;">${pctBadge}</td>
          </tr>
        `;
      });

      if (bmName && !bmMatch && (benchmarkProfile || bmRank)) {
        const bmClass = (benchmarkProfile && benchmarkProfile.character) ? benchmarkProfile.character.class : 'WARRIOR';
        const bmFaction = (benchmarkProfile && benchmarkProfile.character) ? benchmarkProfile.character.faction : 'Alliance';
        const bmGuild = (benchmarkProfile && benchmarkProfile.character && benchmarkProfile.character.guild) ? benchmarkProfile.character.guild : 'None';
        const bmKills = benchmarkProfile ? (benchmarkProfile.total_kills || 0) : 0;
        const bmSolo = benchmarkProfile ? (benchmarkProfile.solo_kills || 0) : 0;
        const bmPct = (benchmarkProfile && benchmarkProfile.percentile) ? benchmarkProfile.percentile : { percentile: 50, topPct: 50, cohortLabel: 'Operative Benchmark', totalInCohort: 100 };
        const pctBadge = getWowLogsPercentileBadge(bmPct);
        const bmGuildHtml = (bmGuild && bmGuild !== 'None')
          ? `<span class="clickable-guild" onclick="openGuildProfile('${escapeHtml(bmGuild)}')">${escapeHtml(bmGuild)}</span>`
          : '-';

        html += `
          <tr style="border-top: 2px dashed rgba(245, 158, 11, 0.4); background: rgba(212, 163, 41, 0.08);" class="current-player-row">
            <td style="padding: 6px 10px; color: var(--accent-gold); font-weight: 800; white-space: nowrap;">#&gt;15</td>
            <td style="padding: 6px 10px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
              <span class="clickable-player" style="display:inline-flex; align-items:center; gap:6px;" onclick="openCharacterProfile('${escapeHtml(bmName)}')">
                ${renderClassBadge(bmClass, 18)} ${colorizeClass(bmName, bmClass)}
                <span class="you-badge">${isAccountUser ? 'YOU' : 'BENCHMARK'}</span>
              </span>
            </td>
            <td style="padding: 6px 10px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">${bmGuildHtml}</td>
            <td style="padding: 6px 10px; color: ${bmFaction === 'Alliance' ? '#3b82f6' : '#ef4444'}; white-space: nowrap;">${escapeHtml(bmFaction || 'Neutral')}</td>
            <td style="padding: 6px 10px; color: #10b981; font-weight: 700; white-space: nowrap;">${bmKills}</td>
            <td style="padding: 6px 10px; color: #00e5ff; font-weight: 700; white-space: nowrap;">${bmSolo}</td>
            <td style="padding: 6px 10px; text-align:right; white-space: nowrap;">${pctBadge}</td>
          </tr>
        `;
      }
    }

    html += `
            </tbody>
          </table>
        </div>
    `;
  }

  html += `</div>`;
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

function renderSingleBountyCard(b, isSupporter) {
  const lastSeen = b.lastSeen || {};
  let lastSeenHtml = "";
  if (lastSeen.hasTelemetry) {
    if (lastSeen.subzone) {
      lastSeenHtml = `
        <div style="font-size:0.75rem; color:#38bdf8; margin-top:8px; background:rgba(7,9,14,0.75); padding:6px 10px; border-radius:4px; border:1px solid rgba(255,255,255,0.1);">
          <span style="font-weight:700;">Last Sighted:</span> ${escapeHtml(lastSeen.zone)} <span style="color:#fbbf24;">(${escapeHtml(lastSeen.subzone)})</span>
          <div style="font-size:0.7rem; color:#94a3b8; margin-top:2px;">
            ~${lastSeen.minutesAgo}m ago &bull; <span style="color:#fbbf24; font-weight:700;">Zone Intel</span>
          </div>
        </div>
      `;
    } else {
      lastSeenHtml = `
        <div style="font-size:0.75rem; color:#38bdf8; margin-top:8px; background:rgba(7,9,14,0.75); padding:6px 10px; border-radius:4px; border:1px solid rgba(255,255,255,0.1);">
          <span style="font-weight:700;">Last Sighted:</span> ${escapeHtml(lastSeen.zone)}
          <div style="font-size:0.7rem; color:#94a3b8; margin-top:2px;">~${lastSeen.minutesAgo}m ago</div>
        </div>
      `;
    }
  } else {
    lastSeenHtml = `
      <div style="font-size:0.72rem; color:#64748b; margin-top:8px; background:rgba(7,9,14,0.75); padding:6px 10px; border-radius:4px; border:1px solid rgba(255,255,255,0.1);">
        Last Sighted: <em>No recent combat logged</em>
      </div>
    `;
  }

  // Determine target faction
  const targetFaction = b.target_faction || (b.target_class === 'PALADIN' ? 'Alliance' : (b.target_class === 'SHAMAN' ? 'Horde' : 'Unknown'));
  let factionCardClass = 'bounty-card-alliance';
  if (targetFaction === 'Horde') factionCardClass = 'bounty-card-horde';
  else if (targetFaction === 'Alliance') factionCardClass = 'bounty-card-alliance';

  const factionBadge = targetFaction !== 'Unknown' 
    ? `<span class="bounty-faction-pill ${targetFaction.toLowerCase()}">${targetFaction.toUpperCase()} TARGET</span>`
    : `<span class="bounty-faction-pill neutral">WANTED TARGET</span>`;

  // Format reward accurately for gold, silver, or copper
  const cardCopper = Number(b.amount_copper) || (Number(b.amount_gold) * 10000) || 0;
  let cardRewardText = "";
  if (cardCopper >= 10000) {
    cardRewardText = `${(cardCopper / 10000).toFixed(cardCopper % 10000 === 0 ? 0 : 1)}g`;
  } else if (cardCopper >= 100) {
    cardRewardText = `${Math.floor(cardCopper / 100)}s ${cardCopper % 100 > 0 ? (cardCopper % 100) + 'c' : ''}`.trim();
  } else {
    cardRewardText = `${cardCopper}c`;
  }
  const displayTargetLevel = b.target_level || b.level || (b.targetLevel ? b.targetLevel : 60);

  return `
    <div class="stat-card bounty-target-card ${factionCardClass}">
      <div style="display:flex; justify-content:space-between; align-items:center;">
        <div style="display:flex; align-items:center; gap:8px;">
          ${renderClassBadge(b.target_class, 22)}
          <div>
            <span class="clickable-player" onclick="openCharacterProfile('${escapeHtml(b.target_name)}')" style="color:#fff; font-weight:800; font-size:1.15rem; text-shadow:0 2px 4px rgba(0,0,0,0.8);">${escapeHtml(b.target_name)}</span>
            <div style="font-size:0.68rem; color:#cbd5e1;">Level ${displayTargetLevel} ${escapeHtml(b.target_class || 'Combatant')}</div>
          </div>
        </div>
        <div style="text-align:right;">
          <span style="color:var(--accent-gold); font-weight:800; font-size:1.15rem; text-shadow:0 2px 4px rgba(0,0,0,0.8);">${cardRewardText}</span>
          <div>${factionBadge}</div>
        </div>
      </div>
      <div style="font-size:0.75rem; color:#94a3b8; margin-top:8px;">
        Contract Placer: <strong style="color:#e2e8f0;">${escapeHtml(b.placer_name)}</strong> &bull; Status: <span style="color:#10b981; font-weight:700;">${escapeHtml(b.status)}</span> ${b.hunter_name ? `(Claimed by ${escapeHtml(b.hunter_name)})` : ''}
      </div>
      ${lastSeenHtml}
    </div>
  `;
}

function renderBountiesView(bounties, debts, leaderboards) {
  const container = document.getElementById("main-content-area");
  leaderboards = leaderboards || {};
  const isSupporter = isSupporterActive();

  const myUser = (localStorage.getItem("wowkb_account_username") || localStorage.getItem("wowkb_user_character") || "").toLowerCase();
  const allBounties = bounties || [];
  const myBounties = myUser ? allBounties.filter(b => (b.placer_name || "").toLowerCase() === myUser || (b.target_name || "").toLowerCase() === myUser) : [];

  let html = `
    <div style="display: flex; flex-direction: column; gap: 24px;">
  `;

  // 1. Personal Marks Section (At the Top)
  if (myUser) {
    html += `
      <div>
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px; padding-bottom:8px; border-bottom:1px solid var(--wow-brass-border, #4a3b27); flex-wrap:wrap; gap:8px;">
          <div>
            <h2 class="wow-gold-header" style="font-size: 1.15rem; font-weight:800; letter-spacing:0.5px; display:flex; align-items:center; gap:8px; margin:0;">
              Your Active Marked Contracts (${myBounties.length})
            </h2>
            <div style="font-size:0.75rem; color:#856a36; margin-top:2px;">
              Contracts issued by you or placed upon your head
            </div>
          </div>
          <button class="see-all-marks-btn" onclick="openPlaceBountyModal()">+ Issue Mark</button>
        </div>
    `;

    if (myBounties.length === 0) {
      html += `
        <div style="color: #64748b; font-size:0.8rem; padding: 14px 16px; background: rgba(3,4,7,0.7); border-radius:6px; border: 1px dashed rgba(255,255,255,0.08);">
          You have no active Marked contracts issued or placed against you. When ganked in the world, brand your killer with a Mark of Spite to dispatch the realm's hunters!
        </div>
      `;
    } else {
      html += `
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 12px;">
          ${myBounties.map(b => renderSingleBountyCard(b, isSupporter)).join('')}
        </div>
      `;
    }

    html += `</div>`;
  } else {
    html += `
      <div style="background: linear-gradient(180deg, #0a0d14 0%, #030407 100%); border: 1px solid var(--wow-brass-border, #4a3b27); box-shadow: inset 0 0 16px rgba(0, 0, 0, 0.85); border-radius: 6px; padding: 12px 18px; display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:10px;">
        <div style="font-size:0.82rem; color:#94a3b8;">
          <strong style="color:var(--wow-gold);">Personal Marks:</strong> Sign in to pin contracts you issued or marks placed upon your head to the top.
        </div>
        <button class="header-signin-btn" onclick="switchTab('PORTAL')">Sign In &rarr;</button>
      </div>
    `;
  }

  // 2. All Realm Marks of Spite
  html += `
      <div>
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px; padding-bottom:8px; border-bottom:1px solid var(--wow-brass-border, #4a3b27); flex-wrap:wrap; gap:8px;">
          <div>
            <h2 class="wow-gold-header" style="font-size: 1.15rem; font-weight:800; letter-spacing:0.5px; margin:0;">The Marked — Execution Contracts</h2>
            <div style="font-size:0.75rem; color:#856a36; margin-top:2px;">Track and execute targets in open combat to claim the reward.</div>
          </div>
          <button class="see-all-marks-btn" onclick="openPlaceBountyModal()">+ Issue Mark</button>
        </div>
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 12px;">
  `;

  if (!allBounties || allBounties.length === 0) {
    html += `<div style="color: #64748b; padding:16px;">No active marks right now. Place one to ignite a manhunt!</div>`;
  } else {
    html += allBounties.map(b => renderSingleBountyCard(b, isSupporter)).join('');
  }

  html += `
        </div>
      </div>

      <!-- Bounty Leaderboards: Hall of Fame -->
      <div>
        <div style="margin-bottom:12px; padding-bottom:8px; border-bottom:1px solid var(--wow-brass-border, #4a3b27);">
          <h2 class="wow-gold-header" style="font-size: 1.15rem; font-weight:800; letter-spacing:0.5px; margin:0;">The Marked — Hall of Fame &amp; Records</h2>
          <div style="font-size:0.75rem; color:#856a36; margin-top:2px;">All-time outlaw hunts, highest bounties collected, and record survival times.</div>
        </div>
        <div class="bounty-hall-of-fame-grid" style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;">
          
          <!-- 1. Top Bounty Hunters -->
          <div style="background: linear-gradient(180deg, #0a0d14 0%, #030407 100%); border: 1px solid var(--wow-brass-border, #4a3b27); box-shadow: inset 0 0 16px rgba(0, 0, 0, 0.85), 0 2px 8px rgba(0, 0, 0, 0.5); border-radius: 6px; padding: 14px 16px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;">
              <h3 style="color:#10b981; font-size:0.95rem;">Top Mark Hunters</h3>
              <span style="font-size:0.7rem; color:#856a36; font-family:var(--font-tactical); font-weight:700;">Most Marks Claimed</span>
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
                : '<div style="color:#64748b; font-size:0.8rem;">No marks claimed yet.</div>'
              }
            </div>
          </div>

          <!-- 2. Highest Bounty Contracts -->
          <div style="background: linear-gradient(180deg, #0a0d14 0%, #030407 100%); border: 1px solid var(--wow-brass-border, #4a3b27); box-shadow: inset 0 0 16px rgba(0, 0, 0, 0.85), 0 2px 8px rgba(0, 0, 0, 0.5); border-radius: 6px; padding: 14px 16px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;">
              <h3 style="color:var(--accent-gold); font-size:0.95rem;">Highest Marked Rewards</h3>
              <span style="font-size:0.7rem; color:#856a36; font-family:var(--font-tactical); font-weight:700;">Biggest Escrow Rewards</span>
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
                : '<div style="color:#64748b; font-size:0.8rem;">No mark records found.</div>'
              }
            </div>
          </div>

          <!-- 3. Longest Outstanding (Most Elusive Outlaws) -->
          <div style="background: linear-gradient(180deg, #0a0d14 0%, #030407 100%); border: 1px solid var(--wow-brass-border, #4a3b27); box-shadow: inset 0 0 16px rgba(0, 0, 0, 0.85), 0 2px 8px rgba(0, 0, 0, 0.5); border-radius: 6px; padding: 14px 16px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;">
              <h3 style="color:#f97316; font-size:0.95rem;">Most Elusive Outlaws</h3>
              <span style="font-size:0.7rem; color:#856a36; font-family:var(--font-tactical); font-weight:700;">Longest Surviving Marks</span>
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
          <div style="background: linear-gradient(180deg, #0a0d14 0%, #030407 100%); border: 1px solid var(--wow-brass-border, #4a3b27); box-shadow: inset 0 0 16px rgba(0, 0, 0, 0.85), 0 2px 8px rgba(0, 0, 0, 0.5); border-radius: 6px; padding: 14px 16px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;">
              <h3 style="color:var(--accent-cyan); font-size:0.95rem;">Fastest Collected Manhunts</h3>
              <span style="font-size:0.7rem; color:#856a36; font-family:var(--font-tactical); font-weight:700;">Record Execution Times</span>
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

      <!-- The Marked: Blood Debtor Ledger -->
      <div>
        <h2 class="wow-gold-header" style="font-size: 1.15rem; font-weight:800; letter-spacing:0.5px; margin-bottom: 4px;">
          The Marked — Realm Blood Debtors (Kill On Sight)
        </h2>
        <div style="font-size:0.75rem; color:#94a3b8; margin-bottom:12px;">
          Defaulters who failed to settle their bounty debts are marked Kill on Sight server-wide. Tracked permanently across character name changes and guild transfers.
        </div>
        <div style="display: flex; flex-direction: column; gap: 8px;">
  `;

  if (!debts || debts.length === 0) {
    html += `<div style="color: #10b981; padding:12px; background:#07090e; border:1px solid #1e293b; border-radius:6px;">No active defaulters. The realm's honor is preserved!</div>`;
  } else {
    debts.forEach(d => {
      html += `
        <div class="debt-card">
          <div class="debt-header">
            <div style="display:flex; align-items:center; gap:8px;">
              <span class="debt-badge">BLOOD DEBTOR</span>
              <strong style="color:#fff; font-size:1.05rem;" class="clickable-player" onclick="openCharacterProfile('${d.player_name}')">${d.player_name}</strong>
              <span class="debt-welcher-tag">DEBT WELCHER</span>
            </div>
            <span style="color:var(--accent-red); font-weight:800; font-size:1.1rem;">${formatCopper(d.amount_owed_copper)} Owed</span>
          </div>
          <div style="font-size:0.8rem; color:#cbd5e1; margin-top:4px;">
            Defaulted on bounty owed to <strong style="color:var(--accent-cyan);">${d.creditor}</strong> &bull; In default for <strong style="color:#f87171;">${d.days_in_default} days</strong>.
          </div>
          <div style="font-size:0.72rem; color:#f87171; margin-top:6px; display:flex; align-items:center; gap:6px;">
            <span>Marked KILL ON SIGHT realm-wide. Any citizen or bounty hunter may execute this target without penalty until bounty debt is paid.</span>
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

// Combat Role Inference Helper
function inferCombatRole(cls, specName, spellName) {
  cls = (cls || "").toUpperCase();
  const spec = (specName || "").toLowerCase();
  const spell = (spellName || "").toLowerCase();
  if (spec.includes("protect") || spec.includes("blood") || spec.includes("guardian") || spec.includes("brewmaster") || spec.includes("vengeance")) return "tank";
  if (spec.includes("holy") || spec.includes("restor") || spec.includes("discipline") || spec.includes("mistweaver") || spec.includes("preservation") || spell.includes("heal") || spell.includes("flash") || spell.includes("rejuvenat")) return "heal";
  return "dps";
}

function renderRoleBadge(role) {
  if (role === "tank") {
    return `<span class="combat-role-pill tank" title="Role: Tank"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#38bdf8" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg><span>Tank</span></span>`;
  }
  if (role === "heal") {
    return `<span class="combat-role-pill heal" title="Role: Healer"><svg width="12" height="12" viewBox="0 0 24 24" fill="#10b981" stroke="none"><path d="M9 2h6v7h7v6h-7v7H9v-7H2V9h7V2z"/></svg><span>Heal</span></span>`;
  }
  return `<span class="combat-role-pill dps" title="Role: DPS"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#ef4444" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="4" y1="20" x2="20" y2="4"/><line x1="14" y1="4" x2="20" y2="4"/><line x1="20" y1="20" x2="4" y2="4"/><line x1="10" y1="20" x2="4" y2="20"/><line x1="4" y1="14" x2="4" y2="20"/></svg><span>DPS</span></span>`;
}

// Modal Handlers
function openKillModal(killId) {
  const km = cachedKills.find(k => k.killId === killId);
  if (!km) return;

  const modal = document.getElementById("kill-modal");
  const body = document.getElementById("modal-body");

  const killerGuildName = (km.killer.guild && km.killer.guild !== 'None') ? km.killer.guild : '';
  const victimGuildName = (km.victim.guild && km.victim.guild !== 'None') ? km.victim.guild : '';
  const killerGuild = killerGuildName 
    ? `<span class="clickable-guild" onclick="openGuildProfile('${killerGuildName}')">&lt;${killerGuildName}&gt;</span>` 
    : '<span style="color:#64748b;">&lt;Unguilded&gt;</span>';
  const victimGuild = victimGuildName 
    ? `<span class="clickable-guild" onclick="openGuildProfile('${victimGuildName}')">&lt;${victimGuildName}&gt;</span>` 
    : '<span style="color:#64748b;">&lt;Unguilded&gt;</span>';

  // Infer Killer Spec from attack spells or class default
  let killerSpell = "Combat";
  let attackersList = (km.attackers && km.attackers.length > 0) ? km.attackers : [];
  if (attackersList.length > 0) {
    const kAtt = attackersList.find(a => a.name === km.killer.name) || attackersList[0];
    if (kAtt && kAtt.spell) killerSpell = kAtt.spell;
  }
  const killerSpec = inferSpec(km.killer.class, killerSpell);
  const killerRole = inferCombatRole(km.killer.class, killerSpec.name, killerSpell);
  const killerSpecBadge = renderSpecBadge(killerSpec.id, killerSpec.name, 22);

  // If no attackers list recorded in older kills, synthesize sole attacker
  if (attackersList.length === 0) {
    attackersList = [{
      name: km.killer.name,
      class: km.killer.class,
      guild: km.killer.guild,
      damage: km.totalDamage || km.killer.damageDone || 1,
      spell: killerSpell || "Final Blow",
      isFinalBlow: true
    }];
  }

  // Tally total attacker damage for percentage calculation
  const totalAttackerDmg = attackersList.reduce((acc, a) => acc + (Number(a.damage) || 0), 0) || km.totalDamage || 1;

  let modeBadge = '<span class="battle-report-pill world">Open World PvP</span>';
  if (km.isDuel) modeBadge = '<span class="battle-report-pill duel">1v1 Duel</span>';
  else if (km.isArena) modeBadge = '<span class="battle-report-pill arena">Arena Match</span>';
  else if (km.isBattleground) modeBadge = `<span class="battle-report-pill bg">Battleground [${km.battlegroundName || 'BG'}]</span>`;
  else if (km.isSolo) modeBadge = '<span class="battle-report-pill solo">Certified 1v1 Solo</span>';
  else modeBadge = `<span class="battle-report-pill gang">Gang Action (${km.attackersCount} Attackers)</span>`;

  let soloBanner = "";
  if (km.isSolo) {
    soloBanner = `
      <div class="battle-report-solo-banner">
        <span>⭐ CERTIFIED 1v1 SOLO TRIUMPH</span>
        <span style="font-size:0.75rem; color:#6ee7b7; font-weight:600;">Zero External Combat Interference</span>
      </div>
    `;
  } else if (km.isDuel) {
    soloBanner = `
      <div class="battle-report-duel-banner">
        <span>⚔️ CERTIFIED 1v1 FORMAL DUEL</span>
        <span style="font-size:0.75rem; color:#fde68a; font-weight:600;">Sanctioned Honor Duel Won</span>
      </div>
    `;
  }

  // Sanitize subzone to purge legacy fallbacks (e.g. Gurubashi Arena in Arathi Highlands)
  let zoneName = (km.location && km.location.zone) ? km.location.zone : "Wilderness";
  let subZoneName = (km.location && km.location.subZone) ? km.location.subZone : "";
  if (subZoneName === "Gurubashi Arena" && !zoneName.toLowerCase().includes("stranglethorn")) {
    subZoneName = "";
  }
  if (subZoneName.toLowerCase() === zoneName.toLowerCase()) {
    subZoneName = "";
  }
  const locationDisplay = subZoneName ? `${zoneName} (${subZoneName})` : zoneName;

  body.innerHTML = `
    <!-- Top Metadata Header -->
    <div style="display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid #1e293b; padding-bottom:10px;">
      <div style="display:flex; align-items:center; gap:8px;">
        <span style="font-weight:800; color:var(--accent-gold); font-size:1.1rem; letter-spacing:0.5px;">BATTLE REPORT</span>
        <span style="font-size:0.75rem; color:#94a3b8; font-family:monospace; background:rgba(255,255,255,0.06); padding:2px 6px; border-radius:4px;">${km.killId}</span>
      </div>
      <div style="display:flex; align-items:center; gap:10px;">
        ${modeBadge}
        <span style="font-size:0.75rem; color:#94a3b8;">${new Date(km.timestamp * 1000).toLocaleString()}</span>
      </div>
    </div>

    ${soloBanner}

    <!-- Primary Combatant Faceoff Cards -->
    <div style="display:grid; grid-template-columns:1fr auto 1fr; align-items:stretch; gap:16px;">
      <!-- Killer Column -->
      <div class="battle-report-combatant-card victorious" style="display:flex; align-items:center; gap:14px;">
        <div style="position:relative; flex-shrink:0;">
          ${renderClassBadge(km.killer.class, 52)}
          <span style="position:absolute; bottom:-6px; right:-6px;">${killerSpecBadge}</span>
        </div>
        <div style="min-width:0; flex:1;">
          <div style="display:flex; align-items:center; gap:6px; margin-bottom:2px;">
            <span style="font-size:0.68rem; color:#10b981; font-weight:800; letter-spacing:0.5px;">VICTORIOUS COMBATANT</span>
            ${renderRoleBadge(killerRole)}
          </div>
          <div style="font-size:1.35rem; font-weight:800; line-height:1.2; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; font-family:var(--font-cinzel, Cinzel, serif);">
            <span class="clickable-player" onclick="openCharacterProfile('${km.killer.name}')">${colorizeClass(km.killer.name, km.killer.class)}</span>
          </div>
          <div style="font-size:0.8rem; color:#e2e8f0; margin-top:2px;">
            Level ${km.killer.level && km.killer.level > 0 ? km.killer.level : '??'} ${killerSpec.name} ${km.killer.class}
          </div>
          <div style="font-size:0.75rem; color:#64748b;">${killerGuild}</div>
          <div style="font-size:0.72rem; color:${km.killer.faction === 'Alliance' ? '#3b82f6' : '#ef4444'}; font-weight:700; margin-top:4px;">
            ${km.killer.faction || 'Neutral'} &bull; Strike Team: ${km.killer.partySize || 1}
          </div>
        </div>
      </div>

      <!-- Center VS Divider -->
      <div style="display:flex; flex-direction:column; align-items:center; justify-content:center; padding:0 8px;">
        <div style="font-size:2rem; font-weight:900; color:#ef4444; font-family:var(--font-cinzel, Cinzel, serif); text-shadow:0 0 14px rgba(239,68,68,0.5);">VS</div>
        <span style="font-size:0.65rem; color:#94a3b8; letter-spacing:1px; font-weight:700; text-transform:uppercase;">Fatal Clash</span>
      </div>

      <!-- Victim Column -->
      <div class="battle-report-combatant-card slain" style="display:flex; align-items:center; gap:14px; justify-content:flex-end; text-align:right;">
        <div style="min-width:0; flex:1;">
          <div style="font-size:0.68rem; color:#ef4444; font-weight:800; letter-spacing:0.5px; margin-bottom:2px;">SLAIN COMBATANT</div>
          <div style="font-size:1.35rem; font-weight:800; line-height:1.2; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; font-family:var(--font-cinzel, Cinzel, serif);">
            <span class="clickable-player" onclick="openCharacterProfile('${km.victim.name}')">${colorizeClass(km.victim.name, km.victim.class)}</span>
          </div>
          <div style="font-size:0.8rem; color:#e2e8f0; margin-top:2px;">
            Level ${km.victim.level && km.victim.level > 0 ? km.victim.level : '??'} ${km.victim.class}
          </div>
          <div style="font-size:0.75rem; color:#64748b;">${victimGuild}</div>
          <div style="font-size:0.72rem; color:${km.victim.faction === 'Alliance' ? '#3b82f6' : '#ef4444'}; font-weight:700; margin-top:4px;">
            ${km.victim.faction || 'Neutral'} &bull; Hostile Squad: ${km.victim.partySize || 1}
          </div>
        </div>
        <div style="position:relative; flex-shrink:0;">
          ${renderClassBadge(km.victim.class, 52)}
        </div>
      </div>
    </div>

    <!-- Attacking Squad Telemetry & Breakdown -->
    <div style="background:#0a0d14; border:1px solid #1e293b; border-radius:8px; padding:14px;">
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px; border-bottom:1px solid rgba(255,255,255,0.06); padding-bottom:8px;">
        <div style="display:flex; align-items:center; gap:8px;">
          <span style="color:var(--accent-gold); font-size:0.9rem; font-weight:800; letter-spacing:0.5px;">
            ASSAULT FORCE &amp; SQUAD ROSTER (${attackersList.length} Combatant${attackersList.length > 1 ? 's' : ''})
          </span>
        </div>
        <span style="font-size:0.75rem; color:#94a3b8;">
          Total Encounter Damage: <strong style="color:#f59e0b;">${formatNumber(totalAttackerDmg)}</strong>
        </span>
      </div>

      <div style="display:flex; flex-direction:column; gap:8px;">
        ${attackersList.map(att => {
          const dmg = Number(att.damage) || 0;
          const pct = Math.min(100, Math.round((dmg / totalAttackerDmg) * 100));
          const attCls = att.class || "WARRIOR";
          const attSpell = att.spell || "Combat Strike";
          const attSpec = inferSpec(attCls, attSpell);
          const attRole = inferCombatRole(attCls, attSpec.name, attSpell);
          const specBadge = renderSpecBadge(attSpec.id, attSpec.name, 20);
          const clsBadge = renderClassBadge(attCls, 22);
          const isKiller = (att.name === km.killer.name) || att.isFinalBlow;
          const attGuild = (att.guild && att.guild !== 'None') ? `&lt;${att.guild}&gt;` : '';

          return `
            <div class="battle-report-attacker-row">
              <div class="attacker-identity">
                <div style="display:flex; align-items:center; gap:4px; flex-shrink:0;">
                  ${clsBadge}
                  ${specBadge}
                </div>
                <div style="display:flex; flex-direction:column; line-height:1.2; min-width:0;">
                  <div style="display:flex; align-items:center; gap:6px; flex-wrap:wrap;">
                    <span class="clickable-player" style="font-weight:700;" onclick="openCharacterProfile('${att.name}')">${colorizeClass(att.name, attCls)}</span>
                    <span class="attacker-spec-tag">[${attSpec.name}]</span>
                    ${renderRoleBadge(attRole)}
                    ${isKiller ? '<span class="final-blow-badge">★ FINAL BLOW</span>' : '<span class="squad-assist-badge">🛡️ SQUAD ASSIST</span>'}
                  </div>
                  <span style="font-size:0.68rem; color:#64748b;">${attGuild}</span>
                </div>
              </div>

              <div class="attacker-spell-col">
                <span class="attacker-spell-label">Signature Ability:</span>
                <span class="attacker-spell-val">${attSpell}</span>
              </div>

              <div class="attacker-dmg-col">
                <div style="display:flex; justify-content:space-between; font-size:0.75rem; margin-bottom:3px;">
                  <strong style="color:#e2e8f0;">${formatNumber(dmg)} dmg</strong>
                  <span style="color:var(--accent-gold); font-weight:700;">${pct}%</span>
                </div>
                <div class="dmg-bar-track">
                  <div class="dmg-bar-fill" style="width:${pct}%;"></div>
                </div>
              </div>
            </div>
          `;
        }).join('')}
      </div>
    </div>

    <!-- Location & Metadata Grid -->
    <div style="display:grid; grid-template-columns:1fr 1fr; gap:12px; font-size:0.85rem;">
      <div style="background:#0e121a; padding:12px 14px; border-radius:6px; border:1px solid #242b3d;">
        <strong style="color:var(--accent-gold); display:flex; align-items:center; gap:6px;">
          <span>🎯</span>
          <span>Combat Engagement</span>
        </strong>
        <div style="color:#cbd5e1; margin-top:6px; font-weight:600;">${km.isDuel ? 'Sanctioned 1v1 Duel' : (km.isArena ? 'Ranked Arena Match' : (km.isBattleground ? `Battleground [${km.battlegroundName || 'BG'}]` : 'Open World PvP Encounter'))}</div>
        <div style="color:#94a3b8; font-size:0.75rem; margin-top:3px;">Attacking Squad: <span style="color:#fff; font-weight:700;">${km.attackersCount}</span> &bull; Hostile Squad: <span style="color:#fff; font-weight:700;">${km.victim.partySize || 1}</span></div>
      </div>
      <div style="background:#0e121a; padding:12px 14px; border-radius:6px; border:1px solid #242b3d;">
        <strong style="color:var(--accent-gold); display:flex; align-items:center; gap:6px;">
          <span>📍</span>
          <span>Spatial Coordinates</span>
        </strong>
        <div style="color:#cbd5e1; margin-top:6px; font-weight:600;">${locationDisplay}</div>
        <div style="color:#94a3b8; font-size:0.75rem; margin-top:3px;">GPS Map ID: <span style="color:#38bdf8; font-weight:700;">${(km.location && km.location.mapId) || 0}</span> &bull; Coords: <span style="color:#38bdf8; font-weight:700;">${((km.location && km.location.x) || 0).toFixed(1)}, ${((km.location && km.location.y) || 0).toFixed(1)}</span></div>
      </div>
    </div>
  `;

  modal.style.display = "flex";
}

function closeModal() {
  document.getElementById("kill-modal").style.display = "none";
}

function buildCharacterDossierHtml(data) {
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
                <small style="color:#64748b;">(Lvl ${k.victim_level && k.victim_level > 0 ? k.victim_level : '??'})</small>
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
                <small style="color:#64748b;">(Lvl ${d.killer_level && d.killer_level > 0 ? d.killer_level : '??'})</small>
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

  const dossierHeroClass = data.faction === 'Alliance' ? 'dossier-hero-alliance' : (data.faction === 'Horde' ? 'dossier-hero-horde' : '');

  return `
    <div class="${dossierHeroClass}" style="display:flex; justify-content:space-between; align-items:center; background:#07090e; padding:18px; border-radius:8px; border:1px solid #1e293b; flex-wrap:wrap; gap:12px;">
      <div>
        <div style="display:flex; align-items:center; gap:8px; flex-wrap:wrap;">
          <div style="font-size:1.4rem; font-weight:800;">${colorizeClass(data.name, data.class)}</div>
          ${data.rankTitle ? `<span class="armory-rank-pill">${data.rankTitle}</span>` : ''}
          ${data.percentile ? `
            <span class="armory-percentile-pill" title="${data.percentile.cohortLabel} (${data.percentile.totalInCohort} active combatants)">
              ⭐ Top ${data.percentile.topPct}% (${data.percentile.percentile}th Percentile)
            </span>
          ` : ''}
        </div>
        <div style="font-size:0.85rem; color:#94a3b8; margin-top:4px;">
          Level ${data.level} ${data.spec ? data.spec + ' ' : ''}${data.class} &bull; <span style="color:${factionColor}; font-weight:700;">${data.faction}</span> &bull; ${guildText}
        </div>
        ${data.percentile ? `
          <div style="font-size:0.75rem; color:#cbd5e1; margin-top:4px;">
            Class Standing: <strong style="color:var(--wow-gold);">${data.percentile.cohortLabel}</strong> &bull; Ranked <strong style="color:#10b981;">#${data.percentile.rank}</strong> of ${data.percentile.totalInCohort} active combatants
          </div>
        ` : ''}
        ${data.bloodDebtor ? `
          <div class="armory-blood-debtor-banner">
            <div style="display:flex; align-items:center; gap:8px;">

              <div>
                <div style="font-weight:800; color:#ef4444; letter-spacing:0.5px;">REPUTATION: BLOOD DEBTOR (KILL ON SIGHT)</div>
                <div style="font-size:0.75rem; color:#fca5a5;">Defaulted on ${formatCopper(data.bloodDebtor.amountOwedCopper)} bounty debt owed to ${data.bloodDebtor.creditor} (${data.bloodDebtor.daysInDefault} days in default). Marked KOS server-wide across all name & guild changes.</div>
              </div>
            </div>
          </div>
        ` : `
          <div style="margin-top:6px;">
            <span class="reputation-badge-honorable">${data.reputation || 'HONORABLE COMBATANT'} &bull; DEBT-FREE</span>
          </div>
        `}
        ${(data.isKos || data.deserter || data.activeBountyGold > 0) ? `
          <div class="armory-tags-row">
            ${(data.isKos && !data.bloodDebtor) ? '<span class="armory-badge-kos">KILL ON SIGHT</span>' : ''}
            ${data.deserter ? `<span class="armory-badge-deserter">DESERTER (${data.deserter.days_remaining}d)</span>` : ''}
            ${data.activeBountyGold > 0 ? `<span class="armory-badge-bounty">ACTIVE BOUNTY: ${data.activeBountyGold}g</span>` : ''}
          </div>
        ` : ''}
      </div>
      <div class="armory-group">
        <button class="armory-btn" style="cursor:pointer; background:#1e293b; color:#38bdf8;" onclick="copyCharacterProfileLink('${escapeHtml(data.name)}', this)">📋 Copy Link</button>
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
}

// Standalone Active Operative Telemetry Sync
async function syncActiveCharacterTelemetry(charName) {
  const name = charName || localStorage.getItem("wowkb_user_character") || localStorage.getItem("wowkb_account_username");
  if (!name || name.toLowerCase() === "unknown") return;
  try {
    const res = await fetch(`/api/character/${encodeURIComponent(name)}`);
    if (!res.ok) return;
    const data = await res.json();
    if (data && data.class && data.class !== "UNKNOWN") {
      localStorage.setItem("wowkb_user_class", data.class.toUpperCase());
      if (data.level) localStorage.setItem("wowkb_user_level", data.level);
      if (data.faction) localStorage.setItem("wowkb_user_faction", data.faction);
      if (data.guild) localStorage.setItem("wowkb_user_guild", data.guild);
      renderHeaderAuthBadge();
    }
  } catch (e) {}
}

// Character Profile Modal Handlers
async function openCharacterProfile(charName) {
  const modal = document.getElementById("character-modal");
  const body = document.getElementById("character-modal-body");
  const title = document.getElementById("character-modal-title");
  if (!modal || !body) return;

  title.innerText = `Champion Profile: ${charName}`;
  body.innerHTML = `<div style="text-align:center; padding:30px; color:#94a3b8;">Consulting the War Archives for ${escapeHtml(charName)}...</div>`;
  modal.style.display = "flex";

  try {
    const res = await fetch(`/api/character/${encodeURIComponent(charName)}`);
    if (!res.ok) {
      body.innerHTML = `<div style="text-align:center; padding:30px; color:#ef4444;">Champion combat record not found.</div>`;
      return;
    }
    const data = await res.json();
    body.innerHTML = buildCharacterDossierHtml(data);

    // Synchronize champion class and level if viewing active user
    const currentActive = (localStorage.getItem("wowkb_user_character") || "").toLowerCase();
    if (data && data.name && data.name.toLowerCase() === currentActive) {
      if (data.class && data.class !== "UNKNOWN") localStorage.setItem("wowkb_user_class", data.class.toUpperCase());
      if (data.level) localStorage.setItem("wowkb_user_level", data.level);
      if (data.faction) localStorage.setItem("wowkb_user_faction", data.faction);
      if (data.guild) localStorage.setItem("wowkb_user_guild", data.guild);
      renderHeaderAuthBadge();
    }
  } catch (err) {
    body.innerHTML = `<div style="text-align:center; padding:30px; color:#ef4444;">Error retrieving character profile: ${err.message}</div>`;
  }
}

function closeCharacterModal() {
  document.getElementById("character-modal").style.display = "none";
}

function copyCharacterProfileLink(charName, btn) {
  const url = `${window.location.origin}/?character=${encodeURIComponent(charName)}`;
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(url).then(() => {
      if (btn) {
        const origText = btn.innerHTML;
        btn.innerHTML = "✓ Link Copied!";
        btn.style.color = "#10b981";
        setTimeout(() => {
          btn.innerHTML = origText;
          btn.style.color = "#38bdf8";
        }, 2000);
      }
    }).catch(() => {
      prompt("Copy Champion Profile URL:", url);
    });
  } else {
    prompt("Copy Champion Profile URL:", url);
  }
}

// Personal Armory View (When Signed-In Operative clicks Armory)
async function loadPersonalArmoryView(charName) {
  const container = document.getElementById("main-content-area");
  if (!container) return;

  container.innerHTML = `<div style="text-align:center; padding:40px; color:#94a3b8;">Loading personal combat armory for ${escapeHtml(charName)}...</div>`;

  try {
    const res = await fetch(`/api/character/${encodeURIComponent(charName)}`);
    if (!res.ok) {
      container.innerHTML = `
        <div class="personal-armory-container" style="display:flex; flex-direction:column; gap:20px;">
          <div style="background:#0c0f17; border:1px solid #1e293b; border-radius:8px; padding:24px; text-align:center;">

            <h2 style="color:var(--wow-gold); font-size:1.25rem;">Welcome, Champion ${escapeHtml(charName)}</h2>
            <p style="color:#94a3b8; font-size:0.85rem; margin-top:6px; max-width:550px; margin-left:auto; margin-right:auto;">
              Your personal combat record has not yet recorded open-world engagements. Equip the free in-game addon and engage in combat to log honorable kills, deaths, and rank standings!
            </p>
            <div style="margin-top:16px; display:flex; justify-content:center; gap:10px;">
              <button class="nav-btn" style="background:var(--accent-cyan); color:#000; font-weight:700;" onclick="loadArmoryView()">Browse Realm Directory</button>
              <button class="nav-btn" style="border:1px solid var(--wow-gold); color:var(--wow-gold);" onclick="openAddonDossierModal()">Download Addon</button>
            </div>
          </div>
        </div>
      `;
      return;
    }

    const data = await res.json();
    const dossierHtml = buildCharacterDossierHtml(data);

    container.innerHTML = `
      <div class="personal-armory-container" style="display:flex; flex-direction:column; gap:20px;">
        <div class="personal-armory-header" style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:12px; background:var(--bg-card); border:1px solid var(--border-color); border-radius:8px; padding:16px 20px;">
          <div style="display:flex; align-items:center; gap:12px;">

            <div>
              <div style="font-weight:800; font-size:1.15rem; color:#fff;">Your Personal Combat Armory</div>
              <div style="font-size:0.75rem; color:#94a3b8;">Career combat records &amp; PvP standing for <strong style="color:var(--wow-gold);">${escapeHtml(data.name)}</strong></div>
            </div>
          </div>
          <button class="nav-btn" style="border:1px solid var(--border-color); background:rgba(255,255,255,0.05);" onclick="loadArmoryView()">
            <span>Search Realm Directory</span> &rarr;
          </button>
        </div>
        ${dossierHtml}
      </div>
    `;
  } catch (err) {
    container.innerHTML = `<div style="text-align:center; padding:40px; color:#ef4444;">Failed to load armory profile: ${err.message}</div>`;
  }
}

function handleArmoryNavClick() {
  // Armory is currently In Development
  return;
}

// Guild Profile Modal Handlers
async function openGuildProfile(guildName) {
  const modal = document.getElementById("guild-modal");
  const body = document.getElementById("guild-modal-body");
  const title = document.getElementById("guild-modal-title");
  if (!modal || !body) return;

  title.innerText = `Guild Intelligence: <${guildName}>`;
  body.innerHTML = `<div style="text-align:center; padding:30px; color:#94a3b8;">Gathering battlefield records for <${guildName}>...</div>`;
  modal.style.display = "flex";

  try {
    const res = await fetch(`/api/guild/${encodeURIComponent(guildName)}`);
    if (!res.ok) {
      body.innerHTML = `<div style="text-align:center; padding:30px; color:#ef4444;">Guild war record not found.</div>`;
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
          <h3>No Guild PvP war records recorded yet.</h3>
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

// ----------------- Player Armory Directory & Sidebar Search -----------------

let armoryState = {
  search: "",
  faction: "",
  class: "",
  sort: "kills"
};

let armorySearchTimeout = null;

function setArmoryFaction(faction) {
  armoryState.faction = faction;
  loadArmoryView();
}

function setArmoryClass(cls) {
  armoryState.class = cls;
  loadArmoryView();
}

function setArmorySort(sort) {
  armoryState.sort = sort;
  loadArmoryView();
}

function handleArmorySearchInput(e) {
  clearTimeout(armorySearchTimeout);
  const val = e.target.value;
  armorySearchTimeout = setTimeout(() => {
    armoryState.search = val;
    fetchArmoryDataAndRender();
  }, 300);
}

function handleSidebarArmoryKey(event) {
  if (event.key === "Enter") {
    handleSidebarArmorySearch();
  }
}

function handleSidebarArmorySearch() {
  const input = document.getElementById("sidebar-armory-input");
  if (!input) return;
  const name = input.value.trim();
  if (name) {
    openCharacterProfile(name);
  }
}

async function fetchArmoryDataAndRender() {
  const gridContainer = document.getElementById("armory-cards-grid");
  const countBadge = document.getElementById("armory-total-count");
  if (gridContainer) {
    gridContainer.innerHTML = `<div style="grid-column:1/-1; text-align:center; padding:40px; color:#94a3b8;">Searching Realm Combat Archives...</div>`;
  }

  try {
    const params = new URLSearchParams();
    if (armoryState.search) params.append("search", armoryState.search);
    if (armoryState.faction) params.append("faction", armoryState.faction);
    if (armoryState.class) params.append("class", armoryState.class);
    if (armoryState.sort) params.append("sort", armoryState.sort);

    const res = await fetch(`/api/armory?${params.toString()}`);
    if (!res.ok) throw new Error("Failed to query armory records");
    const data = await res.json();
    const characters = data.characters || [];
    const total = data.total || 0;

    if (countBadge) {
      countBadge.innerText = `Showing ${characters.length} of ${total} Realm Combatants`;
    }

    if (!gridContainer) return;

    if (characters.length === 0) {
      gridContainer.innerHTML = `
        <div style="grid-column:1/-1; background:#07090e; border:1px solid #1e293b; border-radius:8px; padding:32px; text-align:center; color:#64748b;">

          <div style="color:#e2e8f0; font-weight:700; font-size:1.05rem;">No Character Records Found</div>
          <p style="font-size:0.8rem; margin-top:4px;">No players match your search filter criteria. Try adjusting class, faction, or search term.</p>
        </div>
      `;
      return;
    }

    let cardsHtml = "";
    characters.forEach(c => {
      const cls = (c.class || "WARRIOR").toUpperCase();
      const clsColor = CLASS_COLORS[cls] || CLASS_COLORS.UNKNOWN;
      const symbol = CLASS_SYMBOLS[cls] || "👤";
      const factionColor = c.faction === "Alliance" ? "var(--alliance-blue)" : (c.faction === "Horde" ? "var(--horde-red)" : "#94a3b8");
      const guildHtml = (c.guild && c.guild !== "None")
        ? `<span class="armory-card-guild" onclick="openGuildProfile('${c.guild}')">&lt;${c.guild}&gt;</span>`
        : `<span style="font-size:0.75rem; color:#64748b;">No Guild</span>`;

      const lastSeen = c.lastSeen || {};
      const lastSeenText = lastSeen.zone ? `${lastSeen.zone} &bull; ${timeAgo(lastSeen.timestamp)}` : "Unknown";

      cardsHtml += `
        <div class="armory-card" style="border-top: 3px solid ${clsColor};">
          <div>
            <div class="armory-card-header">
              <div class="armory-avatar" style="border: 2px solid ${clsColor}; box-shadow: 0 0 10px ${clsColor}33; display:flex; align-items:center; justify-content:center;">
                ${renderClassBadge(c.class, 28)}
              </div>
              <div class="armory-card-info">
                <div class="armory-card-name" onclick="openCharacterProfile('${c.name}')">
                  ${colorizeClass(c.name, cls)}
                </div>
                <div class="armory-card-meta">
                  Level ${c.level} ${c.spec ? c.spec + ' ' : ''}${c.class} &bull; <span style="color:${factionColor}; font-weight:700;">${c.faction}</span>
                </div>
                ${guildHtml}
              </div>
            </div>

            <div style="display:flex; gap:6px; flex-wrap:wrap; margin-top:6px;">
              ${c.rankTitle ? `<div class="armory-rank-pill" style="margin-top:0;">${c.rankTitle}</div>` : ''}
              ${c.percentile ? `<div class="armory-percentile-pill" title="${c.percentile.cohortLabel} (${c.percentile.totalInCohort} active combatants)">⭐ Top ${c.percentile.topPct}% (${c.percentile.percentile}th Pct)</div>` : ''}
            </div>

            <div class="armory-tags-row">
              ${c.isKos ? '<span class="armory-badge-kos">KILL ON SIGHT</span>' : ''}
              ${c.deserter ? `<span class="armory-badge-deserter">DESERTER (${c.deserter.days_remaining}d)</span>` : ''}
              ${c.activeBountyGold > 0 ? `<span class="armory-badge-bounty">${c.activeBountyGold} ${renderWowCoin('gold')} BOUNTY</span>` : ''}
            </div>

            <div class="armory-stats-matrix">
              <div>
                <div class="armory-stat-cell-label">Kills</div>
                <div class="armory-stat-cell-val" style="color:var(--accent-green);">${c.kills}</div>
              </div>
              <div>
                <div class="armory-stat-cell-label">Deaths</div>
                <div class="armory-stat-cell-val" style="color:var(--accent-red);">${c.deaths}</div>
              </div>
              <div>
                <div class="armory-stat-cell-label">K/D</div>
                <div class="armory-stat-cell-val" style="color:var(--accent-gold);">${c.kd}</div>
              </div>
              <div>
                <div class="armory-stat-cell-label">Solo</div>
                <div class="armory-stat-cell-val" style="color:var(--accent-cyan);">${c.soloKills}</div>
              </div>
            </div>
          </div>

          <div class="armory-footer-row">
            <div class="armory-lastseen-txt" title="Last confirmed combat zone">
              ${lastSeenText}
            </div>
            <button class="armory-dossier-btn" onclick="openCharacterProfile('${c.name}')">
              Profile &rarr;
            </button>
          </div>
        </div>
      `;
    });

    gridContainer.innerHTML = cardsHtml;
  } catch (err) {
    if (gridContainer) {
      gridContainer.innerHTML = `<div style="grid-column:1/-1; text-align:center; padding:40px; color:#ef4444;">Failed to load Armory records: ${err.message}</div>`;
    }
  }
}

async function loadArmoryView() {
  const container = document.getElementById("main-content-area");
  if (!container) return;

  const allPossibleClasses = [
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID",
    "DEMONHUNTER", "EVOKER"
  ];
  const cfg = FLAVOR_CONFIGS[currentFlavor] || FLAVOR_CONFIGS.CLASSIC_ERA;

  // Reset selected class if it is disabled in current flavor
  if (armoryState.class && !cfg.availableClasses.includes(armoryState.class)) {
    armoryState.class = '';
  }

  const html = `
    <div class="armory-view-container">
      <div class="armory-header-row">
        <div class="armory-title-wrap">

          <div>
            <div class="armory-title">REALM PLAYER ARMORY — COMBAT DIRECTORY</div>
            <div class="armory-subtitle">Authoritative PvP profiles, Classic Military Honor Titles, and lifetime battle records across Azeroth</div>
          </div>
        </div>
        <div id="armory-total-count" class="armory-count-badge">Loading combatants...</div>
      </div>

      <!-- Tactical Filters & Search Bar -->
      <div class="armory-filters-bar">
        <input type="text" id="armory-search-box" class="armory-search-input" placeholder="Search Character Name or Guild..." value="${armoryState.search}" oninput="handleArmorySearchInput(event)">

        <!-- Faction Filter Pills -->
        <div class="faction-pill-group">
          <button class="faction-pill ${armoryState.faction === '' ? 'active-all' : ''}" onclick="setArmoryFaction('')">All Factions</button>
          <button class="faction-pill ${armoryState.faction === 'Alliance' ? 'active-alliance' : ''}" onclick="setArmoryFaction('Alliance')">Alliance</button>
          <button class="faction-pill ${armoryState.faction === 'Horde' ? 'active-horde' : ''}" onclick="setArmoryFaction('Horde')">Horde</button>
        </div>

        <!-- Class Filter Dropdown -->
        <select class="armory-select" onchange="setArmoryClass(this.value)">
          <option value="" ${armoryState.class === '' ? 'selected' : ''}>All Classes</option>
          ${allPossibleClasses.map(c => {
            const isAvail = cfg.availableClasses.includes(c);
            const label = c.charAt(0) + c.slice(1).toLowerCase();
            if (isAvail) {
              return `<option value="${c}" ${armoryState.class === c ? 'selected' : ''}>${label}</option>`;
            } else {
              const reason = cfg.disabledClasses[c] || "Later Exp.";
              return `<option value="${c}" disabled style="color:#526075;">${label} (${reason})</option>`;
            }
          }).join('')}
        </select>

        <!-- Sort Filter Dropdown -->
        <select class="armory-select" onchange="setArmorySort(this.value)">
          <option value="kills" ${armoryState.sort === 'kills' ? 'selected' : ''}>Most Lethal (Kills)</option>
          <option value="kd" ${armoryState.sort === 'kd' ? 'selected' : ''}>Highest K/D Ratio</option>
          <option value="solo" ${armoryState.sort === 'solo' ? 'selected' : ''}>Solo Specialists</option>
          <option value="level" ${armoryState.sort === 'level' ? 'selected' : ''}>Character Level</option>
          <option value="recent" ${armoryState.sort === 'recent' ? 'selected' : ''}>⏱️ Recently Active</option>
        </select>
      </div>

      <!-- Character Directory Grid -->
      <div id="armory-cards-grid" class="armory-grid">
        <!-- Rendered by fetchArmoryDataAndRender -->
      </div>
    </div>
  `;

  container.innerHTML = html;
  fetchArmoryDataAndRender();
}

// Mobile Drawer & Touch Navigation Handlers
function toggleMobileDrawer(forceState) {
  const drawer = document.getElementById("mobile-drawer");
  const backdrop = document.getElementById("mobile-drawer-backdrop");
  if (!drawer || !backdrop) return;
  const isOpen = (typeof forceState === "boolean") ? forceState : !drawer.classList.contains("open");
  if (isOpen) {
    drawer.classList.add("open");
    backdrop.classList.add("open");
    document.body.style.overflow = "hidden";
  } else {
    drawer.classList.remove("open");
    backdrop.classList.remove("open");
    document.body.style.overflow = "";
  }
}

function handleMobileSearch(e) {
  searchQuery = e.target.value;
  const deskBox = document.getElementById("search-box");
  if (deskBox) deskBox.value = searchQuery;
  loadKills();
}

// ----------------- Deadly NPCs Leaderboard View -----------------

async function loadDeadlyNpcsView() {
  const container = document.getElementById("main-content-area");
  if (!container) return;
  container.innerHTML = `<div style="text-align:center; padding:40px; color:#94a3b8;">Gathering wilderness executions and fallen mortal records...</div>`;

  try {
    const [lbRes, deathsRes] = await Promise.all([
      fetch("/api/pve/leaderboard"),
      fetch("/api/pve/deaths?limit=40")
    ]);
    const lbData = await lbRes.json();
    const deathsData = await deathsRes.json();
    renderDeadlyNpcsView(lbData, deathsData.deaths || []);
  } catch (err) {
    container.innerHTML = `<div style="text-align:center; padding:40px; color:#ef4444;">Failed to load Deadly NPCs: ${err.message}</div>`;
  }
}

function renderDeadlyNpcsView(lbData, deaths) {
  const container = document.getElementById("main-content-area");
  if (!container) return;

  const summary = lbData.summary || { totalDeaths: 0, uniqueDeadlyNpcs: 0, mostDangerousZone: { zone: "None", deaths: 0 } };
  const npcs = lbData.topDeadlyNpcs || [];
  const topVictims = lbData.topFallenPlayers || [];
  const deadZone = summary.mostDangerousZone || { zone: "None", deaths: 0 };
  const deadZoneStr = deadZone.zone !== "None" ? `${deadZone.zone} (${deadZone.deaths} Slain)` : "None";

  let html = `
    <div class="deadly-npcs-container">
      <!-- Hero Header Banner -->
      <div class="deadly-npcs-hero">
        <div>
          <div class="deadly-hero-title">
            MOST DEADLY NPCS &amp; FALLEN MORTALS LEADERBOARD
          </div>
          <div class="deadly-hero-subtitle">
            Pure PvE Execution Records &bull; Isolated from PvP feeds &bull; Tracking every mortal slain by beasts, elites, and raid bosses across Azeroth
          </div>
        </div>
        <div class="deadly-summary-metrics">
          <div class="deadly-metric-card">
            <div class="deadly-metric-label">Total Fallen Mortals</div>
            <div class="deadly-metric-val" style="color:#ef4444;">${formatNumber(summary.totalDeaths)}</div>
          </div>
          <div class="deadly-metric-card">
            <div class="deadly-metric-label">Deadly Monster Slayers</div>
            <div class="deadly-metric-val" style="color:var(--accent-gold);">${formatNumber(summary.uniqueDeadlyNpcs)}</div>
          </div>
          <div class="deadly-metric-card">
            <div class="deadly-metric-label">Deadliest Conflict Zone</div>
            <div class="deadly-metric-val" style="font-size:0.95rem; color:#38bdf8; padding-top:4px;">${deadZoneStr}</div>
          </div>
        </div>
      </div>

      <!-- Main Layout: 2 Columns (Top Deadly NPCs & Top Fallen Mortals + Stream) -->
      <div class="deadly-grid-layout">
        <!-- Left Column: Top Executioner NPCs Leaderboard -->
        <div class="deadly-table-card">
          <div class="deadly-table-header">
            <div class="deadly-table-title">
              TOP EXECUTIONER MONSTERS &amp; ELITES
            </div>
            <span style="font-size:0.75rem; color:#94a3b8;">Ranked by Confirmed Mortal Executions</span>
          </div>

          <div style="display:flex; flex-direction:column;">
            ${npcs.length === 0 ? '<div style="padding:30px; text-align:center; color:#64748b;">No NPC executions logged yet.</div>' : npcs.map((npc, idx) => {
              const rankClass = idx === 0 ? 'rank-1' : (idx === 1 ? 'rank-2' : (idx === 2 ? 'rank-3' : ''));
              return `
                <div class="npc-executioner-card">
                  <div class="npc-identity">
                    <div class="npc-rank-badge ${rankClass}">#${idx + 1}</div>
                    <span class="npc-skull-icon"></span>
                    <div>
                      <div class="npc-name">${npc.npc_name}</div>
                      <div class="npc-subtext">
                        <span>${npc.zone || 'Azeroth'}</span>
                        &bull;
                        <span class="npc-spell-badge">${npc.npc_spell || 'Combat'}</span>
                        ${npc.last_kill ? `&bull; <span>Last slain: ${timeAgo(npc.last_kill)}</span>` : ''}
                      </div>
                    </div>
                  </div>
                  <div class="npc-kills-col">
                    <div class="npc-kill-count">${npc.kills} <span style="font-size:0.75rem; font-weight:normal; color:#f87171;">kills</span></div>
                    <div class="npc-unique-victims">${npc.unique_victims || 1} unique victim${npc.unique_victims > 1 ? 's' : ''}</div>
                  </div>
                </div>
              `;
            }).join('')}
          </div>
        </div>

        <!-- Right Column: Top Fallen Mortals & Recent Deaths Stream -->
        <div style="display:flex; flex-direction:column; gap:20px;">
          <!-- Top Fallen Players Card -->
          <div class="deadly-table-card">
            <div class="deadly-table-header">
              <div class="deadly-table-title">
                TOP FALLEN MORTALS
              </div>
              <span style="font-size:0.75rem; color:#94a3b8;">Most PvE Deaths</span>
            </div>
            <div style="display:flex; flex-direction:column; padding:6px 0;">
              ${topVictims.length === 0 ? '<div style="padding:20px; text-align:center; color:#64748b; font-size:0.8rem;">No casualties logged.</div>' : topVictims.map((v, i) => {
                const badge = renderClassBadge(v.victim_class, 18);
                const nameSpan = colorizeClass(v.victim_name, v.victim_class);
                const guildPart = (v.victim_guild && v.victim_guild !== 'None') ? `<span class="clickable-guild" onclick="openGuildProfile('${v.victim_guild}')">&lt;${v.victim_guild}&gt;</span>` : '';
                return `
                  <div style="display:flex; justify-content:space-between; align-items:center; padding:8px 14px; border-bottom:1px solid rgba(255,255,255,0.04); font-size:0.8rem;">
                    <div style="display:flex; align-items:center; gap:8px;">
                      <span style="color:#64748b; font-size:0.75rem; font-weight:700; width:18px;">#${i + 1}</span>
                      ${badge}
                      <div>
                        <span class="clickable-player" onclick="openCharacterProfile('${v.victim_name}')">${nameSpan}</span>
                        <div style="font-size:0.68rem; color:#64748b;">${guildPart}</div>
                      </div>
                    </div>
                    <div style="text-align:right;">
                      <span style="color:#ef4444; font-weight:800;">${v.deaths} deaths</span>
                    </div>
                  </div>
                `;
              }).join('')}
            </div>
          </div>

          <!-- Live Fallen Mortals Stream -->
          <div class="deadly-table-card">
            <div class="deadly-table-header">
              <div class="deadly-table-title">
                RECENT FALLEN MORTALS STREAM
              </div>
              <span style="font-size:0.72rem; color:#94a3b8;">Live Feed</span>
            </div>
            <div class="fallen-mortals-stream">
              ${deaths.length === 0 ? '<div style="text-align:center; padding:20px; color:#64748b; font-size:0.8rem;">No recent monster kills logged.</div>' : deaths.map(d => {
                const badge = renderClassBadge(d.victim_class, 16);
                const vSpan = colorizeClass(d.victim_name, d.victim_class);
                const locStr = d.subzone ? `${d.zone} (${d.subzone})` : d.zone;
                return `
                  <div class="pve-death-row">
                    <div style="display:flex; align-items:center; gap:8px;">
                      ${badge}
                      <div>
                        <div>
                          <span class="clickable-player" onclick="openCharacterProfile('${d.victim_name}')">${vSpan}</span>
                          <span style="color:#64748b; font-size:0.72rem;">(Lvl ${d.victim_level})</span>
                          <span style="color:#94a3b8; font-size:0.75rem;">slain by</span>
                          <strong style="color:#f87171;">${d.npc_name}</strong>
                        </div>
                        <div style="font-size:0.68rem; color:#64748b; margin-top:1px;">
                          <span>${locStr}</span> &bull; <span>${d.npc_spell || 'Combat'}</span>
                        </div>
                      </div>
                    </div>
                    <span style="font-size:0.7rem; color:#64748b; white-space:nowrap; margin-left:8px;">${timeAgo(d.timestamp)}</span>
                  </div>
                `;
              }).join('')}
            </div>
          </div>
        </div>
      </div>
    </div>
  `;

  container.innerHTML = html;
}

// ----------------- War Room Entry Portal -----------------

let portalAccessMode = "guest";
let portalAuthTab = "signin"; // "signin" or "register"

function portalSetScreen(screen) {
  loadPortalView();
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function portalEnterAsGuest() {
  portalAccessMode = "guest";
  sessionStorage.setItem("wowkb_auth_type", "guest");
  sessionStorage.setItem("wowkb_has_entered_feed", "1");
  switchTab("INTEL");
}

function portalAdvanceToVersions(mode) {
  portalAccessMode = mode || "guest";
  sessionStorage.setItem("wowkb_auth_type", portalAccessMode);
  portalLaunchFront("FOREVER");
}

function portalSetAuthTab(tab) {
  portalAuthTab = tab;
}

function handleNormalSignIn(event) {
  if (event) event.preventDefault();
  openCharacterLinkModal();
}

function handleNormalRegister(event) {
  if (event) event.preventDefault();
  openCharacterLinkModal();
}

function handleGoogleSignIn() {
  openCharacterLinkModal();
}

function portalDirectSignIn() {
  sessionStorage.setItem("wowkb_has_entered_feed", "1");
  switchTab("INTEL");
}

function portalLaunchFront(flavorKey) {
  const chosen = flavorKey || "FOREVER";
  handleFlavorChange(chosen);
  updateTheaterNavLabel();
  sessionStorage.setItem("wowkb_has_entered_feed", "1");
  switchTab("INTEL");
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function portalSignOut() {
  localStorage.removeItem("wowkb_account_username");
  localStorage.removeItem("wowkb_account_email");
  localStorage.removeItem("wowkb_account_provider");
  localStorage.removeItem("wowkb_user_character");
  localStorage.removeItem("wowkb_user_class");
  localStorage.removeItem("wowkb_user_level");
  localStorage.removeItem("wowkb_user_guild");
  localStorage.removeItem("wowkb_user_realm");
  localStorage.removeItem("wowkb_user_faction");
  localStorage.removeItem("wowkb_owner_token");
  sessionStorage.removeItem("wowkb_auth_type");
  sessionStorage.removeItem("wowkb_character_name");
  sessionStorage.removeItem("wowkb_has_entered_feed");
  portalAccessMode = "guest";
  renderHeaderAuthBadge();
  switchTab("INTEL");
  loadKills();
}

function loadPortalView() {
  const container = document.getElementById("main-content-area");
  if (!container) return;

  const currentAuth = sessionStorage.getItem("wowkb_auth_type");
  const storedAccount = localStorage.getItem("wowkb_account_username") || localStorage.getItem("wowkb_user_character") || "";

  if (storedAccount && (currentAuth === "account" || currentAuth === "officer" || currentAuth === "character") && portalAccessMode !== "guest") {
    portalAccessMode = "character";
  }

  // Right card: Character Dossier & In-Game Claim
  let rightCardContent = "";
  if (storedAccount) {
    const userCls = (localStorage.getItem("wowkb_user_class") || "WARRIOR").toUpperCase();
    const userLvl = localStorage.getItem("wowkb_user_level") || 60;
    const userFaction = localStorage.getItem("wowkb_user_faction") || "Alliance";
    const userClsColor = CLASS_COLORS[userCls] || CLASS_COLORS.UNKNOWN;
    rightCardContent = `
      <div class="signedin-account-card">
        <div style="display:flex; align-items:center; gap:12px;">
          <div class="officer-sigil-badge">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--wow-gold)" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
          </div>
          <div>
            <div style="font-weight:800; font-size:1.0rem; color:#fff;">
              Active Champion: <span style="color:${userClsColor};">${escapeHtml(storedAccount)}</span>
              <span style="font-size:0.75rem; color:#94a3b8;">(Lvl ${userLvl} ${userCls.charAt(0) + userCls.slice(1).toLowerCase()})</span>
            </div>
            <div style="font-size:0.75rem; color:#94a3b8; margin-top:2px;">
              ${escapeHtml(userFaction)} Vanguard &bull; Certified Combatant
            </div>
          </div>
        </div>
        <div style="display:flex; flex-direction:column; gap:8px; margin-top:16px;">
          <button class="dramatic-gate-btn officer" onclick="openCharacterProfile('${escapeHtml(storedAccount)}')">
            <span>Inspect Combat Profile</span>
            <span>&rarr;</span>
          </button>
          <div style="display:flex; justify-content:center; gap:16px; margin-top:6px;">
            <button class="gate-signout-link" onclick="openCharacterLinkModal()" style="color:var(--accent-cyan); background:none; border:none; cursor:pointer; font-size:0.8rem;">Switch / Claim Character</button>
            <button class="gate-signout-link" onclick="portalSignOut()" style="color:#ef4444; background:none; border:none; cursor:pointer; font-size:0.8rem;">Release Champion</button>
          </div>
        </div>
      </div>
    `;
  } else {
    rightCardContent = `
      <div style="display:flex; flex-direction:column; gap:14px; width:100%; justify-content:space-between; flex:1;">
        <div style="font-size:0.86rem; color:#94a3b8; line-height:1.5;">
          Select your character directly from the live combat ledger or authenticate ownership using in-game claim tokens. Zero email, password, or third-party accounts.
        </div>
        <div style="background:rgba(0,0,0,0.4); border:1px solid rgba(255,215,0,0.18); border-radius:6px; padding:12px 14px; font-size:0.8rem; color:#cbd5e1; display:flex; flex-direction:column; gap:6px;">
          <div style="color:var(--wow-gold); font-weight:700;">In-Game Identity Claim:</div>
          <div>1. Click below to select your character name.</div>
          <div>2. Run <code style="color:var(--accent-cyan); background:rgba(0,229,255,0.1); padding:2px 6px; border-radius:3px;">/kb claim</code> in World of Warcraft.</div>
          <div>3. Sync agent automatically secures your ownership token.</div>
        </div>
        <button type="button" class="dramatic-gate-btn officer" onclick="openCharacterLinkModal()">
          <span>⚔️ Select / Claim Character</span>
          <span>&rarr;</span>
        </button>
      </div>
    `;
  }

  // Left card: Immediate Live Combat Feed
  const leftCardContent = `
    <div style="display:flex; flex-direction:column; gap:14px; width:100%; justify-content:space-between; flex:1;">
      <div style="font-size:0.86rem; color:#94a3b8; line-height:1.5;">
        Step immediately into the live frontline combat feed. Real-time killmail dispatches, verified 1v1 solo duels, bounty alerts, and battleground casualties.
      </div>
      <div style="background:rgba(0,0,0,0.4); border:1px solid rgba(0,229,255,0.18); border-radius:6px; padding:12px 14px; font-size:0.8rem; color:#cbd5e1; display:flex; flex-direction:column; gap:6px;">
        <div style="color:var(--accent-cyan); font-weight:700;">Zero-Barrier Frontline Intel:</div>
        <div>✔ 100% Free &amp; Open Access — Zero signup required</div>
        <div>✔ Certified 1v1 Solo Kills &amp; Gang Gank clustering</div>
        <div>✔ Public Blood Bounty Hunting and Gold Ledgers</div>
        <div>✔ Real-time Cross-Client PvP Radar &amp; War Rallies</div>
      </div>
      <button type="button" class="dramatic-gate-btn guest" onclick="switchTab('INTEL')">
        <span>⚔️ Enter Live Frontline Feed</span>
        <span>&rarr;</span>
      </button>
    </div>
  `;

  container.innerHTML = `
    <div class="portal-container dramatic-flow">
      <!-- Dramatic Hero Masthead -->
      <div class="portal-hero dramatic-hero">
        <div class="portal-crest-row">
          <img src="/static/icons/factions/alliance.jpg" class="portal-crest alliance" alt="Alliance" title="For the Alliance!">
          <div class="portal-emblem"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--wow-gold)" stroke-width="2"><path d="M14.5 17.5L3 6V3h3l11.5 11.5"/><path d="m13 19 6-6"/><path d="M16 16l4 4"/><path d="M19 21l2-2"/><path d="M9.5 17.5 21 6V3h-3L6.5 14.5"/><path d="m11 19-6-6"/><path d="M8 16l-4 4"/><path d="M5 21l-2-2"/></svg></div>
          <img src="/static/icons/factions/horde.jpg" class="portal-crest horde" alt="Horde" title="For the Horde!">
        </div>
        <h1 class="portal-title">AZEROTH COMBAT WAR ROOM</h1>
        <div class="portal-tagline">CHRONICLES OF MARTIAL CONFLICT &bull; BLOOD BOUNTIES &bull; BATTLEGROUND INTELLIGENCE</div>
        <p class="portal-lead">
          The Third War shattered the kingdoms; the frontier remains soaked in blood. Choose your clearance of entry to inspect certified combat casualties, issue blood bounties, or consult the war ledger.
        </p>
        <div class="portal-hero-actions">
          <button class="portal-return-pill" onclick="switchTab('INTEL')">
            <span>⚔️ Enter Live Frontline Feed &rarr;</span>
          </button>
          <button class="portal-fieldkit-pill" onclick="openAddonDossierModal()">
            <svg class="portal-btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
            <span>War Room Operational Specification &amp; Download</span>
          </button>
        </div>
      </div>

      <!-- 2-Card Selection Gate (Inline With Masthead Sides) -->
      <div class="dramatic-gate-grid">
        <!-- Card 1: Live Frontline Intel -->
        <div class="dramatic-gate-card guest">
          <div>
            <div class="gate-card-badge guest">LIVE FRONTLINE INTEL</div>
            <div class="gate-card-icon">
              <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="var(--accent-cyan)" stroke-width="1.8"><circle cx="12" cy="12" r="10"/><line x1="22" y1="12" x2="18" y2="12"/><line x1="6" y1="12" x2="2" y2="12"/><line x1="12" y1="6" x2="12" y2="2"/><line x1="12" y1="22" x2="12" y2="18"/></svg>
            </div>
            <h2 class="gate-card-title">Frontline Killboard Feed</h2>
            <p class="gate-card-desc">
              Direct access to live combat casualties, real-time killmails, solo duel certifications, and battleground intelligence.
            </p>
          </div>
          ${leftCardContent}
        </div>

        <!-- Card 2: Combat Identity & In-Game Claim -->
        <div class="dramatic-gate-card officer">
          <div>
            <div class="gate-card-badge officer">COMBAT IDENTITY</div>
            <div class="gate-card-icon">
              <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="var(--wow-gold)" stroke-width="1.8"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
            </div>
            <h2 class="gate-card-title">Champion Identity &amp; Claim</h2>
            <p class="gate-card-desc">
              View your personalized combat record, Classic military rank, and placed bounties. Link or claim ownership directly from World of Warcraft.
            </p>
          </div>
          ${rightCardContent}
        </div>
      </div>
    </div>
  `;
}

// ----------------- WoW Forever Realm Server Configuration -----------------

const FOREVER_SERVERS = {
  PVP: {
    id: "PVP",
    name: "PvP",
    title: "Forever PvP",
    ruleset: "Contested World PvP",
    badge: "CONTESTED WORLD PVP",
    badgeColor: "#ef4444",
    badgeBg: "rgba(239, 68, 68, 0.15)",
    badgeBorder: "rgba(239, 68, 68, 0.45)",
    desc: "Unrestricted faction conflict in open contested zones. Stranglethorn kill zones, cross-roads raids, and active bounty hunting.",
    popStatus: "High Population",
    icon: "⚔️"
  },
  PVE: {
    id: "PVE",
    name: "PvE",
    title: "Forever PvE",
    ruleset: "Normal Progression",
    badge: "NORMAL PROGRESSION",
    badgeColor: "#10b981",
    badgeBg: "rgba(16, 185, 129, 0.15)",
    badgeBorder: "rgba(16, 185, 129, 0.45)",
    desc: "Voluntary PvP flagging. Focus on open-world leveling, realm defense alerts, and 40-man dungeon & raid progression.",
    popStatus: "Active",
    icon: "🛡️"
  },
  RP: {
    id: "RP",
    name: "RP",
    title: "Forever RP",
    ruleset: "Roleplaying Immersion",
    badge: "IMMERSION & LORE",
    badgeColor: "#c084fc",
    badgeBg: "rgba(192, 132, 252, 0.15)",
    badgeBorder: "rgba(192, 132, 252, 0.45)",
    desc: "In-character realm war campaigns, lore-driven skirmishes, tavern gatherings, and dedicated story-based guild rivalries.",
    popStatus: "Active",
    icon: "📜"
  },
  HARDCORE: {
    id: "HARDCORE",
    name: "Hardcore",
    title: "Forever Hardcore",
    ruleset: "Permadeath — 1 Life",
    badge: "PERMADEATH — 1 LIFE",
    badgeColor: "#f59e0b",
    badgeBg: "rgba(245, 158, 11, 0.15)",
    badgeBorder: "rgba(245, 158, 11, 0.45)",
    desc: "Zero resurrection in open combat. High-stakes blood feuds, mortal combat dispatches, and Mak'gora duels to the death.",
    popStatus: "Extreme Risk",
    icon: "💀"
  }
};

function getCurrentForeverServer() {
  return (localStorage.getItem("wowkb_forever_server") || "PVP").toUpperCase();
}

function openServerSelectorModal() {
  const modal = document.getElementById("server-modal");
  const grid = document.getElementById("server-modal-grid");
  if (!modal || !grid) return;
  const activeSrv = getCurrentForeverServer();

  grid.innerHTML = Object.values(FOREVER_SERVERS).map(s => {
    const isAct = s.id === activeSrv;
    return `
      <div class="server-card ${isAct ? 'active' : ''}" onclick="handleSelectForeverServer('${s.id}')">
        <div>
          <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;">
            <span class="server-card-badge" style="background:${s.badgeBg}; border:1px solid ${s.badgeBorder}; color:${s.badgeColor};">
              ${s.badge}
            </span>
            <span style="font-size:0.7rem; color:${isAct ? 'var(--wow-gold)' : '#64748b'}; font-weight:700;">
              ${isAct ? 'ACTIVE REALM' : s.popStatus}
            </span>
          </div>
          <h4 style="font-size:1.15rem; color:#fff; font-family:var(--font-tactical); margin:0 0 4px 0; display:flex; align-items:center; gap:6px;">
            <span>${s.icon}</span> <span>${escapeHtml(s.title)}</span>
          </h4>
          <div style="font-size:0.75rem; color:var(--wow-gold); font-weight:600; margin-bottom:8px;">${escapeHtml(s.ruleset)}</div>
          <p style="font-size:0.76rem; color:#94a3b8; line-height:1.4; margin:0 0 14px 0;">
            ${escapeHtml(s.desc)}
          </p>
        </div>
        <button style="width:100%; box-sizing:border-box; padding:8px 12px; font-weight:800; font-size:0.78rem; background:${isAct ? 'linear-gradient(135deg, #d97706, #b45309)' : 'rgba(255,255,255,0.06)'}; border:1px solid ${isAct ? 'var(--wow-gold)' : 'rgba(255,255,255,0.12)'}; color:${isAct ? '#fff' : '#cbd5e1'}; cursor:pointer; border-radius:4px; display:flex; align-items:center; justify-content:center; gap:6px;">
          <span>${isAct ? '✓ Selected Realm' : 'Select Server &rarr;'}</span>
        </button>
      </div>
    `;
  }).join('');

  modal.style.display = "flex";
}

function closeServerSelectorModal() {
  const modal = document.getElementById("server-modal");
  if (modal) {
    modal.style.display = "none";
  }
}

function handleSelectForeverServer(serverId) {
  const chosen = (serverId || "PVP").toUpperCase();
  localStorage.setItem("wowkb_forever_server", chosen);
  closeServerSelectorModal();
  handleFlavorChange("FOREVER", chosen);
  window.scrollTo({ top: 0, behavior: "smooth" });
}

// ----------------- Theater Selector / Version Page -----------------

function loadTheaterSelectorView() {
  const container = document.getElementById("main-content-area");
  if (!container) return;

  const currentFlav = (typeof currentFlavor !== "undefined" && currentFlavor) ? currentFlavor : "FOREVER";
  const activeSrv = getCurrentForeverServer();
  const activeSrvObj = FOREVER_SERVERS[activeSrv] || FOREVER_SERVERS.PVP;

  container.innerHTML = `
    <div style="display:flex; flex-direction:column; gap:24px; max-width:1060px; margin:0 auto; padding:10px 0 40px 0;">
      <!-- Masthead Header -->
      <div style="background: radial-gradient(circle at 50% 15%, rgba(212, 163, 41, 0.12) 0%, rgba(10, 13, 20, 0.95) 75%); border: 1px solid var(--wow-brass-border, #4a3b27); border-radius: 8px; padding: 24px 24px 20px 24px; text-align: center; box-shadow: 0 4px 24px rgba(0,0,0,0.7);">
        <h2 style="font-family: var(--font-tactical); font-size: 1.6rem; color: #fff; margin: 0 0 6px 0; letter-spacing: 0.5px;">
          Theaters of War — Campaign Selector
        </h2>
        <div style="font-size: 0.82rem; color: #94a3b8; max-width: 680px; margin: 0 auto;">
          Select your active World of Warcraft theater and realm server. All combat records, kill feeds, and leaderboards filter to the selected campaign ruleset.
        </div>
        <!-- Client Flavor Architecture Notice -->
        <div style="background:rgba(217, 119, 6, 0.12); border:1px solid rgba(217, 119, 6, 0.4); border-radius:6px; padding:10px 16px; margin: 16px auto 0 auto; max-width:780px; font-size:0.78rem; color:#fbbf24; text-align:left; line-height:1.45;">
          <strong>Deployment Notice:</strong> The WoW Killboard in-game addon is fully functional across <strong>all 4 flavors</strong> (Classic Era, Anniversary, Modern Retail, and Beta) for local combat tracking, kill alerts, and audio cues. However, <strong>automated web syncing and online killboard profiles are currently dedicated exclusively to WoW Forever Beta</strong>. Web tracking for Classic Era, Anniversary, and Retail is not currently active on the website.
        </div>
      </div>

      <!-- Version Cards Grid -->
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 18px;">
        <!-- Card 1: WoW Forever (ACTIVE & SELECTABLE) -->
        <div class="theater-version-card active-card" style="background:#0a0e16; border: 2px solid var(--wow-gold); border-radius: 8px; padding: 22px 20px; display:flex; flex-direction:column; justify-content:space-between; box-shadow: 0 0 20px rgba(212, 163, 41, 0.2);">
          <div>
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom: 12px;">
              <span style="font-size:0.68rem; font-weight:800; color:#10b981; background:rgba(16, 185, 129, 0.15); border:1px solid #10b981; padding:2px 8px; border-radius:4px; letter-spacing:0.5px;">
                ACTIVE THEATER (LIVE WEB SYNC)
              </span>
              <span style="font-size:0.75rem; color:var(--wow-gold); font-weight:700;">Level 60 Cap</span>
            </div>
            <h3 style="font-size:1.2rem; color:#fff; font-family:var(--font-tactical); margin:0 0 6px 0;">WoW Forever</h3>
            <p style="font-size:0.78rem; color:#cbd5e1; line-height:1.45; margin:0 0 10px 0;">
              Classic Beta (1.15.x) &bull; 4 dedicated server realms with specialized campaign rulesets.
            </p>

            <!-- 4 Realm Ruleset Selection Pills -->
            <div style="margin: 12px 0 16px 0; padding: 10px; background: rgba(0,0,0,0.4); border: 1px solid rgba(255,255,255,0.08); border-radius: 6px;">
              <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom: 8px;">
                <span style="font-size:0.68rem; color:#94a3b8; font-weight:800; letter-spacing:0.04em;">CHOOSE REALM:</span>
                <span style="font-size:0.68rem; color:var(--wow-gold); font-weight:800;">ACTIVE: ${activeSrvObj.name}</span>
              </div>
              <div style="display:grid; grid-template-columns: repeat(4, 1fr); gap: 6px;">
                <button class="server-quick-pill ${activeSrv === 'PVP' ? 'active' : ''}" onclick="event.stopPropagation(); handleSelectForeverServer('PVP')">⚔️ PvP</button>
                <button class="server-quick-pill ${activeSrv === 'PVE' ? 'active' : ''}" onclick="event.stopPropagation(); handleSelectForeverServer('PVE')">🛡️ PvE</button>
                <button class="server-quick-pill ${activeSrv === 'RP' ? 'active' : ''}" onclick="event.stopPropagation(); handleSelectForeverServer('RP')">📜 RP</button>
                <button class="server-quick-pill ${activeSrv === 'HARDCORE' ? 'active' : ''}" onclick="event.stopPropagation(); handleSelectForeverServer('HARDCORE')">💀 HC</button>
              </div>
            </div>
          </div>
          <button style="width:100%; box-sizing:border-box; padding:10px 14px; font-weight:800; font-size:0.82rem; background:linear-gradient(135deg, #d97706, #b45309); border:1px solid var(--wow-gold); color:#fff; cursor:pointer; border-radius:6px; display:flex; align-items:center; justify-content:center; gap:6px; text-decoration:none;" onclick="handleSelectTheaterVersion('FOREVER')">
            <span>Select Realm &amp; Enter WoW Forever</span> <span>&rarr;</span>
          </button>
        </div>

        <!-- Card 2: Classic Era (GREYED OUT / ADDON READY) -->
        <div class="theater-version-card disabled-card" style="background:#07090e; border: 1px solid #1e293b; border-radius: 8px; padding: 22px 20px; display:flex; flex-direction:column; justify-content:space-between; opacity:0.8;">
          <div>
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom: 12px;">
              <span style="font-size:0.68rem; font-weight:800; color:#fbbf24; background:rgba(245, 158, 11, 0.1); border:1px solid rgba(245, 158, 11, 0.3); padding:2px 8px; border-radius:4px; letter-spacing:0.5px;">
                ADDON COMPATIBLE &bull; WEB COMING SOON
              </span>
              <span style="font-size:0.75rem; color:#64748b; font-weight:700;">Level 60 Cap</span>
            </div>
            <h3 style="font-size:1.2rem; color:#cbd5e1; font-family:var(--font-tactical); margin:0 0 6px 0;">Classic Era</h3>
            <p style="font-size:0.78rem; color:#94a3b8; line-height:1.45; margin:0 0 8px 0;">
              Patch 1.15.x &bull; Vanilla Whitemane and Firemaw legacy realm clusters.
            </p>
            <div style="font-size:0.72rem; color:#fbbf24; background:rgba(245, 158, 11, 0.08); border-left:3px solid #f59e0b; padding:6px 10px; border-radius:3px; margin-bottom:12px; line-height:1.4;">
              <strong>Status:</strong> Addon functions locally for tracking &amp; alerts. Cloud syncing &amp; website tracking not yet active.
            </div>
          </div>
          <button style="width:100%; box-sizing:border-box; padding:10px 14px; font-size:0.82rem; background:#1e293b; border:1px solid #334155; color:#94a3b8; cursor:not-allowed; border-radius:6px; display:flex; align-items:center; justify-content:center;" disabled>
            Web Sync In Development
          </button>
        </div>

        <!-- Card 3: Anniversary (GREYED OUT / ADDON READY) -->
        <div class="theater-version-card disabled-card" style="background:#07090e; border: 1px solid #1e293b; border-radius: 8px; padding: 22px 20px; display:flex; flex-direction:column; justify-content:space-between; opacity:0.8;">
          <div>
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom: 12px;">
              <span style="font-size:0.68rem; font-weight:800; color:#fbbf24; background:rgba(245, 158, 11, 0.1); border:1px solid rgba(245, 158, 11, 0.3); padding:2px 8px; border-radius:4px; letter-spacing:0.5px;">
                ADDON COMPATIBLE &bull; WEB COMING SOON
              </span>
              <span style="font-size:0.75rem; color:#64748b; font-weight:700;">Level 60 Cap</span>
            </div>
            <h3 style="font-size:1.2rem; color:#cbd5e1; font-family:var(--font-tactical); margin:0 0 6px 0;">Anniversary Edition</h3>
            <p style="font-size:0.78rem; color:#94a3b8; line-height:1.45; margin:0 0 8px 0;">
              Fresh Progression Realms &bull; Hardcore &amp; PvP seasonal server clusters.
            </p>
            <div style="font-size:0.72rem; color:#fbbf24; background:rgba(245, 158, 11, 0.08); border-left:3px solid #f59e0b; padding:6px 10px; border-radius:3px; margin-bottom:12px; line-height:1.4;">
              <strong>Status:</strong> Addon functions locally for tracking &amp; alerts. Cloud syncing &amp; website tracking not yet active.
            </div>
          </div>
          <button style="width:100%; box-sizing:border-box; padding:10px 14px; font-size:0.82rem; background:#1e293b; border:1px solid #334155; color:#94a3b8; cursor:not-allowed; border-radius:6px; display:flex; align-items:center; justify-content:center;" disabled>
            Web Sync In Development
          </button>
        </div>

        <!-- Card 4: Modern Retail (GREYED OUT / ADDON READY) -->
        <div class="theater-version-card disabled-card" style="background:#07090e; border: 1px solid #1e293b; border-radius: 8px; padding: 22px 20px; display:flex; flex-direction:column; justify-content:space-between; opacity:0.8;">
          <div>
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom: 12px;">
              <span style="font-size:0.68rem; font-weight:800; color:#fbbf24; background:rgba(245, 158, 11, 0.1); border:1px solid rgba(245, 158, 11, 0.3); padding:2px 8px; border-radius:4px; letter-spacing:0.5px;">
                ADDON COMPATIBLE &bull; WEB COMING SOON
              </span>
              <span style="font-size:0.75rem; color:#64748b; font-weight:700;">Level 80 Cap</span>
            </div>
            <h3 style="font-size:1.2rem; color:#cbd5e1; font-family:var(--font-tactical); margin:0 0 6px 0;">Modern Retail</h3>
            <p style="font-size:0.78rem; color:#94a3b8; line-height:1.45; margin:0 0 8px 0;">
              The War Within (11.x) &bull; Rated Arenas, Solo Shuffle, and Battleground Blitz.
            </p>
            <div style="font-size:0.72rem; color:#fbbf24; background:rgba(245, 158, 11, 0.08); border-left:3px solid #f59e0b; padding:6px 10px; border-radius:3px; margin-bottom:12px; line-height:1.4;">
              <strong>Status:</strong> Addon functions locally for tracking &amp; alerts. Cloud syncing &amp; website tracking not yet active.
            </div>
          </div>
          <button style="width:100%; box-sizing:border-box; padding:10px 14px; font-size:0.82rem; background:#1e293b; border:1px solid #334155; color:#94a3b8; cursor:not-allowed; border-radius:6px; display:flex; align-items:center; justify-content:center;" disabled>
            Web Sync In Development
          </button>
        </div>
      </div>
    </div>
  `;
}

function handleSelectTheaterVersion(flavor) {
  if (flavor === "FOREVER") {
    handleFlavorChange("FOREVER");
    openServerSelectorModal();
    return;
  }
  handleFlavorChange(flavor);
  updateTheaterNavLabel();
  switchTab("INTEL");
}

// ----------------- Addon Field Kit Dossier Modal Handlers -----------------

function openAddonDossierModal() {
  const modal = document.getElementById("addon-dossier-modal");
  if (modal) {
    modal.style.display = "flex";
  }
}

function closeAddonDossierModal() {
  const modal = document.getElementById("addon-dossier-modal");
  if (modal) {
    modal.style.display = "none";
  }
}

// ----------------- Field Bug Reports & AI Diagnostics Modal -----------------

async function loadBugReports() {
  const container = document.getElementById("bug-reports-list");
  if (!container) return;
  container.innerHTML = `<div style="text-align: center; color: #94a3b8; padding: 30px;">Consulting the War Archivist...</div>`;
  try {
    const res = await fetch("/api/bugs");
    if (!res.ok) throw new Error("HTTP " + res.status);
    const bugs = await res.json();
    if (!bugs || bugs.length === 0) {
      container.innerHTML = `
        <div style="text-align: center; padding: 40px 20px; color: #94a3b8;">
          <div style="font-size: 2rem; margin-bottom: 8px;">🛡️</div>
          <div style="font-weight: 700; color: #f8fafc; font-size: 1rem;">No Field Bug Reports Logged</div>
          <p style="font-size: 0.8rem; max-width: 440px; margin: 8px auto 0; line-height: 1.5;">
            All combat tracking systems are operating nominally. Champions can submit issues directly in-game using <code>/kb bug [description]</code> or clicking <strong>[Report Bug]</strong> in the addon.
          </p>
        </div>
      `;
      return;
    }

    container.innerHTML = bugs.map(b => {
      const isP0 = (b.ai_severity || '').includes('P0');
      const isP1 = (b.ai_severity || '').includes('P1');
      const badgeCol = isP0 ? '#ef4444' : (isP1 ? '#f59e0b' : '#38bdf8');
      const badgeBg = isP0 ? 'rgba(239, 68, 68, 0.15)' : (isP1 ? 'rgba(245, 158, 11, 0.15)' : 'rgba(56, 189, 248, 0.15)');
      const badgeBorder = isP0 ? 'rgba(239, 68, 68, 0.3)' : (isP1 ? 'rgba(245, 158, 11, 0.3)' : 'rgba(56, 189, 248, 0.3)');

      const combatBadge = b.in_combat ?
        `<span style="background: rgba(239, 68, 68, 0.2); color: #ef4444; border: 1px solid rgba(239, 68, 68, 0.4); padding: 2px 6px; border-radius: 4px; font-size: 0.68rem; font-weight: 700;">IN COMBAT</span>` :
        `<span style="background: rgba(16, 185, 129, 0.1); color: #10b981; border: 1px solid rgba(16, 185, 129, 0.3); padding: 2px 6px; border-radius: 4px; font-size: 0.68rem;">OUT OF COMBAT</span>`;

      const dateStr = b.timestamp ? new Date(b.timestamp * 1000).toLocaleString() : 'Unknown';

      return `
        <div style="background: rgba(15, 23, 42, 0.7); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 8px; padding: 14px 16px; margin-bottom: 12px;">
          <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 10px; margin-bottom: 8px; flex-wrap: wrap;">
            <div style="display: flex; align-items: center; gap: 8px;">
              <span style="font-family: monospace; font-size: 0.85rem; font-weight: 700; color: #f8fafc; background: rgba(0, 0, 0, 0.3); padding: 2px 6px; border-radius: 4px;">${escapeHtml(b.id)}</span>
              <span style="background: ${badgeBg}; color: ${badgeCol}; border: 1px solid ${badgeBorder}; padding: 2px 8px; border-radius: 4px; font-size: 0.72rem; font-weight: 800; letter-spacing: 0.5px;">
                ${escapeHtml(b.ai_severity || 'P2 - Visual / Minor')}
              </span>
              ${combatBadge}
            </div>
            <div style="font-size: 0.72rem; color: #64748b;">${dateStr}</div>
          </div>

          <div style="font-size: 0.78rem; color: #94a3b8; margin-bottom: 8px; display: flex; gap: 12px; flex-wrap: wrap;">
            <span>Champion: <strong style="color: #f1f5f9;">${escapeHtml(b.reporter_name || 'Anonymous')}</strong></span>
            <span>Realm: <strong style="color: #f1f5f9;">${escapeHtml(b.reporter_realm || 'Unknown')}</strong></span>
            <span>Flavor: <strong style="color: #38bdf8;">${escapeHtml(b.client_flavor || 'CLASSIC_ERA')}</strong></span>
            <span>Zone: <strong style="color: #fbbf24;">${escapeHtml(b.zone || 'Unknown')}${b.subzone ? ' (' + escapeHtml(b.subzone) + ')' : ''}</strong></span>
            ${b.coordinates ? `<span>Coords: <code style="color: #94a3b8;">${escapeHtml(b.coordinates)}</code></span>` : ''}
          </div>

          <div style="background: rgba(0, 0, 0, 0.4); border-left: 3px solid #64748b; padding: 8px 12px; border-radius: 0 4px 4px 0; margin-bottom: 10px; font-size: 0.82rem; color: #e2e8f0; line-height: 1.4;">
            <div style="font-size: 0.68rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; margin-bottom: 2px;">Champion Field Report</div>
            "${escapeHtml(b.user_report || 'No verbal description provided')}"
            ${b.lua_error ? `<pre style="margin-top: 6px; font-size: 0.7rem; color: #ef4444; background: rgba(0,0,0,0.5); padding: 6px; border-radius: 4px; overflow-x: auto;">${escapeHtml(b.lua_error)}</pre>` : ''}
          </div>

          <div style="background: rgba(14, 21, 37, 0.85); border: 1px solid ${badgeBorder}; border-radius: 6px; padding: 10px 12px; font-size: 0.78rem;">
            <div style="display: flex; align-items: center; gap: 6px; color: ${badgeCol}; font-weight: 800; font-size: 0.72rem; text-transform: uppercase; margin-bottom: 4px;">
              <span>🤖 AI Diagnostician Analysis</span>
              <span style="font-size: 0.65rem; color: #64748b; font-weight: 400;">(${escapeHtml(b.ai_status || 'ANALYZED')})</span>
            </div>
            <div style="margin-bottom: 4px;"><strong style="color: #cbd5e1;">Root Cause:</strong> <span style="color: #94a3b8;">${escapeHtml(b.ai_root_cause || 'Under investigation')}</span></div>
            <div style="margin-bottom: 4px;"><strong style="color: #cbd5e1;">Diagnosis:</strong> <span style="color: #94a3b8;">${escapeHtml(b.ai_diagnosis || '')}</span></div>
            <div><strong style="color: #10b981;">Suggested Surgical Fix:</strong> <span style="color: #a7f3d0;">${escapeHtml(b.ai_suggested_fix || '')}</span></div>
          </div>
        </div>
      `;
    }).join('');
  } catch (err) {
    container.innerHTML = `<div style="text-align: center; color: #ef4444; padding: 30px;">Error loading bug reports: ${escapeHtml(err.message)}</div>`;
  }
}

function openBugReportsModal() {
  const modal = document.getElementById("bug-reports-modal");
  if (modal) {
    modal.style.display = "flex";
    loadBugReports();
  }
}

function closeBugReportsModal() {
  const modal = document.getElementById("bug-reports-modal");
  if (modal) {
    modal.style.display = "none";
  }
}

// ----------------- The War Archivist & Combat Oracle AI Chat -----------------

function toggleOracleChatModal(forceOpen) {
  const modal = document.getElementById("oracle-chat-modal");
  if (!modal) return;
  if (forceOpen === true) {
    modal.style.display = "flex";
  } else if (forceOpen === false) {
    modal.style.display = "none";
  } else {
    modal.style.display = (modal.style.display === "none" || !modal.style.display) ? "flex" : "none";
  }

  if (modal.style.display === "flex") {
    const input = document.getElementById("oracle-chat-input");
    if (input) input.focus();
    const msgContainer = document.getElementById("oracle-chat-messages");
    if (msgContainer) msgContainer.scrollTop = msgContainer.scrollHeight;
  }
}

function toggleOracleKeyDrawer() {
  const drawer = document.getElementById("oracle-key-drawer");
  if (!drawer) return;
  drawer.style.display = (drawer.style.display === "none" || !drawer.style.display) ? "block" : "none";
  if (drawer.style.display === "block") {
    const input = document.getElementById("oracle-key-input");
    if (input) {
      input.value = localStorage.getItem("wowkb_gemini_api_key") || "";
      input.focus();
    }
  }
}

function saveOracleKey() {
  const input = document.getElementById("oracle-key-input");
  if (input) {
    const key = input.value.trim();
    if (key) {
      localStorage.setItem("wowkb_gemini_api_key", key);
      alert("Arcane Key saved into local cache. The War Archivist will now use deep generative synthesis.");
    } else {
      localStorage.removeItem("wowkb_gemini_api_key");
      alert("Arcane Key cleared. Reverting to local Archivist intelligence.");
    }
    const drawer = document.getElementById("oracle-key-drawer");
    if (drawer) drawer.style.display = "none";
  }
}

function clearOracleChat() {
  const container = document.getElementById("oracle-chat-messages");
  if (container) {
    container.innerHTML = `
      <div class="oracle-msg scribe">
        <div class="msg-meta">⚔️ The War Archivist</div>
        <div class="msg-body">
          Speak, traveler. The ledger holds every death, every bounty, and every fallen champion across the realms. What combat intelligence do you seek from the front?
        </div>
      </div>
    `;
  }
}

function sendOracleQuickQuery(promptText) {
  const input = document.getElementById("oracle-chat-input");
  if (input) {
    input.value = promptText;
    sendOracleMessage();
  }
}

function handleOracleKeydown(event) {
  if (event.key === "Enter" && !event.shiftKey) {
    event.preventDefault();
    sendOracleMessage();
  }
}

async function sendOracleMessage() {
  const input = document.getElementById("oracle-chat-input");
  const msgContainer = document.getElementById("oracle-chat-messages");
  if (!input || !msgContainer) return;

  const query = input.value.trim();
  if (!query) return;

  input.value = "";

  // Append user message
  const userMsgEl = document.createElement("div");
  userMsgEl.className = "oracle-msg user";
  userMsgEl.innerHTML = `
    <div class="msg-meta">Vanguard Scout</div>
    <div class="msg-body">${escapeHtml(query)}</div>
  `;
  msgContainer.appendChild(userMsgEl);

  // Append temporary loading message
  const loaderId = `oracle-loading-${Date.now()}`;
  const loadingEl = document.createElement("div");
  loadingEl.id = loaderId;
  loadingEl.className = "oracle-msg scribe loading";
  loadingEl.innerHTML = `
    <div class="msg-meta">The War Archivist</div>
    <div class="msg-body"><span class="oracle-pulsing-rune">Searching the war ledger archives...</span></div>
  `;
  msgContainer.appendChild(loadingEl);
  msgContainer.scrollTop = msgContainer.scrollHeight;

  const character = localStorage.getItem("wowkb_account_username") || localStorage.getItem("wowkb_user_character") || "Unmarked Scout";
  const apiKey = localStorage.getItem("wowkb_gemini_api_key") || "";

  try {
    const res = await fetch("/api/oracle/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        query: query,
        character: character,
        flavor: currentFlavor,
        api_key: apiKey
      })
    });

    const data = await res.json();
    const loader = document.getElementById(loaderId);
    if (loader) loader.remove();

    const scribeMsgEl = document.createElement("div");
    scribeMsgEl.className = "oracle-msg scribe";

    let sourcesHtml = "";
    if (data.sources && data.sources.length) {
      sourcesHtml = `
        <div class="oracle-sources-tag">
          ${data.sources.map(s => `<span class="source-pill">${escapeHtml(s)}</span>`).join("")}
        </div>
      `;
    }

    // Convert simple markdown **bold** and \n to formatted HTML
    let formattedReply = formatScribeMarkdown(data.reply || "The dispatch is unreadable; our scouts report no findings.");

    scribeMsgEl.innerHTML = `
      <div class="msg-meta">The War Archivist</div>
      <div class="msg-body">${formattedReply}</div>
      ${sourcesHtml}
    `;
    msgContainer.appendChild(scribeMsgEl);
    msgContainer.scrollTop = msgContainer.scrollHeight;
  } catch (err) {
    const loader = document.getElementById(loaderId);
    if (loader) loader.remove();

    const errorEl = document.createElement("div");
    errorEl.className = "oracle-msg scribe error";
    errorEl.innerHTML = `
      <div class="msg-meta">Dispatch Error</div>
      <div class="msg-body">The raven was intercepted or the archives could not be reached. Ensure the garrison server is active.</div>
    `;
    msgContainer.appendChild(errorEl);
    msgContainer.scrollTop = msgContainer.scrollHeight;
  }
}

function formatScribeMarkdown(text) {
  if (!text) return "";
  let out = escapeHtml(text);
  // Bold **text**
  out = out.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
  // Italic *text*
  out = out.replace(/\*(.*?)\*/g, '<em>$1</em>');
  // Inline code `code`
  out = out.replace(/`(.*?)`/g, '<code>$1</code>');
  // Linebreaks
  out = out.replace(/\n\n/g, '<br><br>');
  out = out.replace(/\n/g, '<br>');
  return out;
}

// Tab Switching
function switchTab(tab) {
  // Normalize alias tabs
  if (tab === "FEED") tab = "INTEL";
  if (tab === "LEADERBOARDS") tab = "LEGENDS";
  if (tab === "DEADLY_NPCS") tab = "HAZARDS";

  // In-Development tabs: War Room, Guilds, Feuds, Defense, BG Metrics
  if (tab === "WARROOM" || tab === "GUILDS" || tab === "FEUDS" || tab === "DEFENSE" || tab === "BG_METRICS") {
    return;
  }

  currentTab = tab;
  document.querySelectorAll(".nav-btn").forEach(b => b.classList.remove("active"));
  const activeBtn = document.getElementById(`nav-${tab.toLowerCase()}`);
  if (activeBtn) activeBtn.classList.add("active");

  document.querySelectorAll(".mobile-nav-item").forEach(b => b.classList.remove("active"));
  const activeMobileBtn = document.getElementById(`m-nav-${tab.toLowerCase()}`);
  if (activeMobileBtn) activeMobileBtn.classList.add("active");

  const isPortal = (tab === "PORTAL");
  document.body.classList.toggle("portal-active", isPortal);
  const mainContainer = document.querySelector(".container");
  if (mainContainer) {
    mainContainer.classList.toggle("portal-mode", isPortal);
  }

  // Hide sidebar on PORTAL, THEATER, UPLOAD, and RALLIES for clean presentation
  const sidebarEl = document.querySelector(".sidebar-column");
  if (sidebarEl) {
    sidebarEl.style.display = (tab === "PORTAL" || tab === "THEATER" || tab === "UPLOAD" || tab === "RALLIES") ? "none" : "";
  }

  const mwSection = document.getElementById("most-wanted-section");
  if (mwSection) mwSection.style.display = (tab === "INTEL") ? "block" : "none";

  const statsHub = document.getElementById("homepage-stats-hub");
  if (statsHub) statsHub.style.display = (tab === "INTEL") ? "block" : "none";

  const isPve = (currentFlavor === "FOREVER" && typeof getCurrentForeverServer === "function" && getCurrentForeverServer() === "PVE");

  if (tab === "PORTAL") {
    loadPortalView();
  }
  else if (tab === "THEATER") {
    loadTheaterSelectorView();
  }
  else if (tab === "UPLOAD") {
    loadUploadView();
  }
  else if (tab === "INTEL") {
    const container = document.getElementById("main-content-area");
    if (cachedKills && cachedKills.length > 0 && !isPve) {
      renderFeed(cachedKills);
    } else if (container) {
      container.innerHTML = `<div style="text-align: center; padding: 40px; color: #64748b;">Loading combat intelligence feed...</div>`;
    }
    loadKills();
    loadMostWanted();
  }
  else if (tab === "LEGENDS") {
    if (isPve) {
      loadDeadlyNpcsView();
    } else {
      loadLeaderboards();
    }
  }
  else if (tab === "HAZARDS") {
    loadDeadlyNpcsView();
  }
  else if (tab === "ARMORY") {
    handleArmoryNavClick();
  }
  else if (tab === "BOUNTIES") {
    if (isPve) {
      loadPveBountiesView();
    } else {
      loadBounties();
    }
  }
  else if (tab === "RALLIES") {
    if (isPve) {
      loadPveRalliesView();
    } else {
      loadRalliesView();
    }
  }
  else if (tab === "ZONES") {
    if (isPve) {
      loadPveZonesView();
    } else {
      loadZonesView();
    }
  }
  else if (tab === "WARROOM") {
    loadWarroomView();
  }
}

// ----------------- Zone Intel Danger Index & Hotspots View -----------------

async function loadZonesView() {
  const container = document.getElementById("main-content-area");
  if (!container) return;

  container.innerHTML = `
    <div style="text-align: center; padding: 40px; color: #64748b;">
      Loading Zone Intelligence &amp; Hotspot Telemetry...
    </div>
  `;

  try {
    const res = await fetch("/api/stats/overview");
    const data = await res.json();
    const zones24h = data.deadliestZones24h || data.topZones || [];

    let html = `
      <div style="display:flex; flex-direction:column; gap:16px;">
        <!-- Header -->
        <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:12px; padding-bottom:10px; border-bottom:1px solid var(--wow-brass-border, #4a3b27);">
          <div>
            <h2 class="wow-gold-header" style="font-size:1.25rem; font-weight:800; letter-spacing:0.5px; margin:0;">
              ZONE INTEL &bull; AZEROTH DANGER INDEX
            </h2>
            <div style="font-size:0.75rem; color:#856a36; margin-top:3px;">
              Real-time regional conflict rankings, hotspot death tolls, and wilderness threat telemetry.
            </div>
          </div>
          <div style="display:flex; align-items:center; gap:8px;">
            <span class="feed-count-pill">${zones24h.length} Hotspots</span>
            <button class="pill-btn" onclick="loadZonesView()" style="padding:4px 10px; font-size:0.75rem; background:rgba(255,255,255,0.06); cursor:pointer;">🔄 Refresh</button>
          </div>
        </div>

        <!-- 24-Hour Deadliest Zones Cards -->
        <div style="display:flex; flex-direction:column; gap:8px;">
          <div style="font-family:var(--font-tactical); font-size:0.85rem; font-weight:800; color:#ffd100; text-transform:uppercase; letter-spacing:0.5px; margin-bottom:2px;">
            🔥 REALM 24-HOUR DEADLIEST HOTSPOTS
          </div>
    `;

    if (zones24h.length === 0) {
      html += `
        <div style="text-align:center; padding:30px; background:rgba(15,23,42,0.6); border:1px solid var(--wow-brass-border); border-radius:6px; color:#64748b;">
          No active conflict zones recorded in the last 24 hours.
        </div>
      `;
    } else {
      const maxKills = Math.max(...zones24h.map(z => z.kills), 1);
      zones24h.forEach((z, idx) => {
        const pct = Math.round((z.kills / maxKills) * 100);
        let threatColor = "#ffd100";
        let threatLabel = "ACTIVE CONFLICT";
        if (z.kills >= 20) {
          threatColor = "#ef4444";
          threatLabel = "EXTREME THREAT";
        } else if (z.kills >= 10) {
          threatColor = "#f97316";
          threatLabel = "HIGH RISK";
        }

        html += `
          <div class="sidebar-row" style="background:var(--wow-iron-bg); border:1px solid var(--wow-brass-border); border-radius:6px; padding:12px 16px; display:flex; flex-direction:column; gap:6px;">
            <div style="display:flex; justify-content:space-between; align-items:center;">
              <div style="display:flex; align-items:center; gap:10px;">
                <span style="font-family:var(--font-tactical); font-weight:800; font-size:0.95rem; color:${idx === 0 ? '#ffd100' : 'var(--wow-gold)'};">#${idx + 1}</span>
                <span style="font-weight:700; font-size:0.95rem; color:#f8fafc; cursor:pointer;" onclick="filterFeedByZone('${escapeHtml(z.zone)}')" title="Click to filter feed for ${escapeHtml(z.zone)}">${escapeHtml(z.zone)}</span>
              </div>
              <div style="display:flex; align-items:center; gap:10px;">
                <span style="font-family:var(--font-tactical); font-size:0.75rem; font-weight:800; color:${threatColor}; background:rgba(0,0,0,0.5); padding:2px 8px; border-radius:3px; border:1px solid ${threatColor};">${threatLabel}</span>
                <span style="font-family:var(--font-tactical); font-size:0.9rem; font-weight:800; color:#ffd100;">${z.kills} Kills</span>
              </div>
            </div>
            <!-- Danger Bar -->
            <div style="width:100%; height:6px; background:rgba(0,0,0,0.5); border-radius:3px; overflow:hidden;">
              <div style="width:${pct}%; height:100%; background:linear-gradient(90deg, #d4a329 0%, ${threatColor} 100%);"></div>
            </div>
          </div>
        `;
      });
    }

    html += `
        </div>
      </div>
    `;

    container.innerHTML = html;
  } catch (err) {
    console.error("Failed to load zone intel:", err);
    container.innerHTML = `<div style="text-align:center; padding:40px; color:#ef4444;">Failed to load Zone Intelligence.</div>`;
  }
}
window.loadZonesView = loadZonesView;

function filterFeedByZone(zoneName) {
  searchQuery = zoneName;
  const input = document.getElementById("search-input");
  if (input) input.value = zoneName;
  const mobileInput = document.getElementById("mobile-search-box-input");
  if (mobileInput) mobileInput.value = zoneName;
  switchTab("INTEL");
}
window.filterFeedByZone = filterFeedByZone;

// ----------------- Web Drag-and-Drop Uploader & Admin Reset -----------------

function loadUploadView() {
  const container = document.getElementById("main-content-area");
  if (!container) return;

  const isAdmin = (new URLSearchParams(window.location.search).get("admin") === "1" || 
                   localStorage.getItem("wowkb_is_admin") === "true");

  container.innerHTML = `
    <div style="display:flex; flex-direction:column; gap:24px; max-width:960px; margin:0 auto; padding:10px 0 40px 0;">
      <!-- Masthead Header -->
      <div style="background: radial-gradient(circle at 50% 15%, rgba(212, 163, 41, 0.12) 0%, rgba(10, 13, 20, 0.95) 75%); border: 1px solid var(--wow-brass-border, #4a3b27); border-radius: 8px; padding: 28px 24px; text-align: center; box-shadow: 0 4px 24px rgba(0,0,0,0.7);">
        <h2 style="font-family: var(--font-tactical); font-size: 1.6rem; color: #fff; margin: 0 0 6px 0; letter-spacing: 0.5px;">
          Combat Log Ingestion & War Ledger Sync
        </h2>
        <div style="font-size: 0.85rem; color: #94a3b8; max-width: 680px; margin: 0 auto;">
          Upload your World of Warcraft combat data to the global Master Ledger. Choose between hands-free real-time background sync or direct browser upload with zero installation required.
        </div>
      </div>

      <!-- Addon Download Callout with Dual Mirrors -->
      <div style="background: rgba(212, 163, 41, 0.08); border: 1px solid var(--wow-gold); border-radius: 8px; padding: 16px 20px; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 14px;">
        <div>
          <div style="font-weight: 800; font-size: 0.95rem; color: #fff; display: flex; align-items: center; gap: 8px;">
            <span>⚔️</span> <span>Need the WoW Killboard Addon?</span>
          </div>
          <div style="font-size: 0.78rem; color: #94a3b8; margin-top: 3px;">
            Download the lightweight, zero-taint addon package (v1.0.0) for World PvP &amp; Battlegrounds.
          </div>
        </div>
        <div style="display: flex; gap: 10px; flex-wrap: wrap;">
          <a href="/WoWKillboard-v1.0.0.zip" download style="display: inline-flex; align-items: center; gap: 6px; background: var(--wow-gold); color: #000; font-weight: 800; font-size: 0.8rem; padding: 8px 16px; border-radius: 4px; text-decoration: none; text-transform: uppercase;">
            <span>⬇ Direct Download (.zip)</span>
          </a>
          <a href="https://drive.google.com/drive/folders/1j3_jS91Q9OJvVLzria0IDUKJIAHR9JRE?usp=sharing" target="_blank" rel="noopener" style="display: inline-flex; align-items: center; gap: 6px; background: rgba(66, 133, 244, 0.2); border: 1px solid #4285f4; color: #93c5fd; font-weight: 700; font-size: 0.8rem; padding: 8px 16px; border-radius: 4px; text-decoration: none;">
            <span>☁ Google Drive Mirror</span>
          </a>
        </div>
      </div>

      <!-- Ingestion Channels Grid -->
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 18px;">
        <!-- Option 1: Desktop Companion Binary -->
        <div style="background: #0a0e16; border: 1px solid var(--wow-brass-border, #4a3b27); border-radius: 8px; padding: 20px; display:flex; flex-direction:column; justify-content:space-between;">
          <div>
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;">
              <span style="font-size:0.68rem; font-weight:800; color:var(--wow-gold); background:rgba(212, 163, 41, 0.12); border:1px solid var(--wow-gold); padding:2px 8px; border-radius:4px;">
                AUTOMATIC &bull; REAL-TIME
              </span>
              <span style="font-size:0.75rem; color:#10b981; font-weight:700;">Zero-Touch</span>
            </div>
            <h3 style="font-size:1.15rem; color:#fff; font-family:var(--font-tactical); margin:0 0 6px 0;">WoWKillboardSync.exe</h3>
            <p style="font-size:0.8rem; color:#94a3b8; line-height:1.45; margin:0 0 14px 0;">
              Standalone desktop companion (like Warcraft Logs or Raider.IO). Runs quietly in your system tray, auto-detects all WoW clients across drives C:, D:, and E:, and streams killmails to Render Cloud in real-time.
            </p>
            <div style="font-size:0.75rem; color:#64748b; margin-bottom:12px;">
              &bull; Zero Python or setup required<br>
              &bull; Deterministic battle deduplication<br>
              &bull; Dual-sync to local & cloud servers
            </div>
          </div>
          <div style="padding-top:12px; border-top:1px solid rgba(255,255,255,0.06); font-size:0.78rem; color:#cbd5e1;">
            Located in: <code style="color:var(--wow-gold); font-size:0.72rem; word-break:break-all;">WoW_Killboard/dist/WoWKillboardSync.exe</code>
          </div>
        </div>

        <!-- Option 2: Pure Browser Drag & Drop -->
        <div style="background: #0a0e16; border: 2px solid var(--wow-gold); border-radius: 8px; padding: 20px; display:flex; flex-direction:column; justify-content:space-between; box-shadow: 0 0 18px rgba(212, 163, 41, 0.15);">
          <div>
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;">
              <span style="font-size:0.68rem; font-weight:800; color:#10b981; background:rgba(16, 185, 129, 0.15); border:1px solid #10b981; padding:2px 8px; border-radius:4px;">
                ZERO DOWNLOAD &bull; BROWSER UPLOAD
              </span>
              <span style="font-size:0.75rem; color:var(--wow-gold); font-weight:700;">Manual Upload</span>
            </div>
            <h3 style="font-size:1.15rem; color:#fff; font-family:var(--font-tactical); margin:0 0 6px 0;">Drag & Drop Uploader</h3>
            <p style="font-size:0.8rem; color:#94a3b8; line-height:1.45; margin:0 0 14px 0;">
              No .exe or background processes needed. Whenever you finish a play session, simply drag your SavedVariables file into the dropzone below. Safe against out-of-order uploads.
            </p>
            <div style="font-size:0.75rem; color:#64748b; margin-bottom:12px;">
              &bull; 100% Client-side file reading<br>
              &bull; Anti-tamper battle validation<br>
              &bull; Instant leaderboard & bounty recalculation
            </div>
          </div>
          <div style="padding-top:12px; border-top:1px solid rgba(255,255,255,0.06); font-size:0.78rem; color:#cbd5e1;">
            Supported formats: <strong style="color:#fff;">.lua</strong> (WoWKillboard.lua), <strong style="color:#fff;">.json</strong>, <strong style="color:#fff;">.txt</strong>
          </div>
        </div>
      </div>

      <!-- Drag & Drop Interactive Dropzone -->
      <div id="upload-dropzone" 
           style="background: rgba(15, 23, 42, 0.6); border: 2px dashed var(--wow-gold); border-radius: 8px; padding: 48px 20px; text-align: center; cursor: pointer; transition: all 0.2s ease;"
           ondragover="handleUploadDragOver(event)" 
           ondragleave="handleUploadDragLeave(event)" 
           ondrop="handleUploadDrop(event)"
           onclick="document.getElementById('upload-file-input').click()">
        
        <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="var(--wow-gold)" stroke-width="1.75" style="margin-bottom: 12px;">
          <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
          <polyline points="17 8 12 3 7 8"/>
          <line x1="12" y1="3" x2="12" y2="15"/>
        </svg>

        <h3 style="color:#fff; font-family:var(--font-tactical); font-size:1.25rem; margin:0 0 6px 0;">
          Drag & Drop <span style="color:var(--wow-gold);">WoWKillboard.lua</span> Here
        </h3>
        <div style="font-size:0.85rem; color:#94a3b8; margin-bottom:14px;">
          or <span style="color:var(--wow-gold); text-decoration:underline; font-weight:700;">Click to Browse Local Files</span>
        </div>

        <div style="display:inline-block; background:rgba(0,0,0,0.5); border:1px solid #334155; border-radius:4px; padding:6px 14px; font-size:0.75rem; color:#cbd5e1; font-family:monospace; max-width:90%;">
          World of Warcraft\\_classic_beta_\\WTF\\Account\\&lt;Account#&gt;\\SavedVariables\\WoWKillboard.lua
        </div>

        <input type="file" id="upload-file-input" style="display:none;" accept=".lua,.json,.txt" onchange="handleUploadFileSelect(event)">
      </div>

      <!-- Live Upload Status Banner -->
      <div id="upload-status-banner" style="display:none; padding:16px 20px; border-radius:6px; font-size:0.85rem;"></div>

      <!-- Collapsible: Direct Text Paste -->
      <details style="background:#0a0e16; border:1px solid #1e293b; border-radius:8px; padding:14px 18px;">
        <summary style="font-size:0.85rem; color:var(--wow-gold); font-weight:700; cursor:pointer;">
          &rarr; Or Paste SavedVariables Lua Text Directly
        </summary>
        <div style="margin-top:14px;">
          <textarea id="upload-paste-text" 
                    placeholder="Paste the contents of WoWKillboard.lua here..." 
                    style="width:100%; height:180px; background:#020617; border:1px solid #334155; border-radius:4px; color:#e2e8f0; font-family:monospace; font-size:0.75rem; padding:12px; resize:vertical; box-sizing:border-box;"></textarea>
          <div style="margin-top:10px; display:flex; justify-content:flex-end;">
            <button class="nav-btn" style="background:var(--wow-gold); color:#000; font-weight:800; padding:8px 20px;" onclick="handleUploadPasteSubmit()">
              Upload & Synchronize Text
            </button>
          </div>
        </div>
      </details>

      ${isAdmin ? `
      <!-- Admin Reset Panel -->
      <div id="admin-reset-panel" style="background: rgba(185, 28, 28, 0.08); border: 1px solid rgba(239, 68, 68, 0.35); border-radius: 8px; padding: 20px;">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;">
          <h4 style="font-family:var(--font-tactical); font-size:1.05rem; color:#f87171; margin:0;">
            Master War Archivist &bull; Database Administration
          </h4>
          <div style="display:flex; gap:8px; align-items:center;">
            <span style="font-size:0.7rem; color:#fca5a5; background:rgba(239, 68, 68, 0.2); padding:2px 8px; border-radius:4px; font-weight:700;">
              RESTRICTED
            </span>
            <button onclick="lockAdminAccess()" style="background:none; border:none; color:#94a3b8; font-size:0.72rem; cursor:pointer; text-decoration:underline;">
              Lock Admin
            </button>
          </div>
        </div>
        <p style="font-size:0.78rem; color:#cbd5e1; margin:0 0 12px 0;">
          Completely reset all combat records, kills, bounties, and leaderboards back to zero. Protected by the administrative secret key.
        </p>
        <div style="display:flex; gap:10px; align-items:center; flex-wrap:wrap;">
          <input type="password" id="admin-reset-key" value="${localStorage.getItem("wowkb_admin_key") || ""}" placeholder="Enter Administrative Secret Key" style="background:#020617; border:1px solid #475569; color:#fff; padding:7px 12px; border-radius:4px; font-size:0.8rem; width:260px;">
          <button style="background:#dc2626; color:#fff; border:none; border-radius:4px; padding:8px 18px; font-weight:800; font-size:0.78rem; cursor:pointer;" onclick="handleAdminResetSubmit()">
            Reset Master Database
          </button>
        </div>
        <div id="admin-reset-status" style="margin-top:10px; font-size:0.78rem; display:none;"></div>
      </div>
      ` : `
      <div style="margin-top:14px; text-align:right;">
        <span onclick="promptAdminAccess()" style="font-size:0.68rem; color:#475569; cursor:pointer;" title="Archivist Access">
          &bull; War Archivist Administration
        </span>
      </div>
      `}
    </div>
  `;
}

function promptAdminAccess() {
  const existing = localStorage.getItem("wowkb_admin_key") || "";
  const key = prompt("Enter Master War Archivist Secret Key:", existing);
  if (key && key.trim().length > 0) {
    localStorage.setItem("wowkb_is_admin", "true");
    localStorage.setItem("wowkb_admin_key", key.trim());
    switchTab('UPLOAD');
    setTimeout(() => {
      const el = document.getElementById("admin-reset-panel");
      if (el) el.scrollIntoView({ behavior: "smooth" });
    }, 150);
  }
}

function lockAdminAccess() {
  localStorage.removeItem("wowkb_is_admin");
  localStorage.removeItem("wowkb_admin_key");
  loadUploadView();
}

function handleUploadDragOver(event) {
  event.preventDefault();
  event.stopPropagation();
  const el = document.getElementById("upload-dropzone");
  if (el) {
    el.style.background = "rgba(212, 163, 41, 0.15)";
    el.style.borderColor = "#facc15";
  }
}

function handleUploadDragLeave(event) {
  event.preventDefault();
  event.stopPropagation();
  const el = document.getElementById("upload-dropzone");
  if (el) {
    el.style.background = "rgba(15, 23, 42, 0.6)";
    el.style.borderColor = "var(--wow-gold)";
  }
}

function handleUploadDrop(event) {
  event.preventDefault();
  event.stopPropagation();
  handleUploadDragLeave(event);
  const files = event.dataTransfer.files;
  if (files && files.length > 0) {
    processUploadFile(files[0]);
  }
}

function handleUploadFileSelect(event) {
  const files = event.target.files;
  if (files && files.length > 0) {
    processUploadFile(files[0]);
  }
}

function processUploadFile(file) {
  showUploadStatus("Reading " + file.name + " from disk...", "info");
  const reader = new FileReader();
  reader.onload = function(e) {
    const content = e.target.result;
    submitUploadContent(content, file.name);
  };
  reader.onerror = function() {
    showUploadStatus("Failed to read file from local disk.", "error");
  };
  reader.readAsText(file);
}

function handleUploadPasteSubmit() {
  const textEl = document.getElementById("upload-paste-text");
  if (!textEl || !textEl.value.trim()) {
    alert("Please paste valid SavedVariables Lua or JSON text first.");
    return;
  }
  submitUploadContent(textEl.value, "Pasted Text");
}

function submitUploadContent(rawContent, sourceName) {
  showUploadStatus("Synchronizing combat data from " + sourceName + " with Master Ledger...", "info");
  fetch("/api/upload", {
    method: "POST",
    headers: { "Content-Type": "text/plain" },
    body: rawContent
  })
  .then(res => res.json().then(data => ({ status: res.status, body: data })))
  .then(({ status, body }) => {
    if (status === 200 && body.success) {
      showUploadStatus("⚔️ SUCCESS: " + (body.kills_processed || 0) + " kills ingested and synchronized into Master Ledger!", "success");
      cachedKills = null;
    } else {
      showUploadStatus("❌ Ingestion Error: " + (body.error || "Unknown server error"), "error");
    }
  })
  .catch(err => {
    showUploadStatus("❌ Network Connection Error: " + err.message, "error");
  });
}

function showUploadStatus(msg, type) {
  const banner = document.getElementById("upload-status-banner");
  if (!banner) return;
  banner.style.display = "block";
  if (type === "success") {
    banner.style.background = "rgba(16, 185, 129, 0.15)";
    banner.style.border = "1px solid #10b981";
    banner.style.color = "#34d399";
  } else if (type === "error") {
    banner.style.background = "rgba(239, 68, 68, 0.15)";
    banner.style.border = "1px solid #ef4444";
    banner.style.color = "#f87171";
  } else {
    banner.style.background = "rgba(59, 130, 246, 0.15)";
    banner.style.border = "1px solid #3b82f6";
    banner.style.color = "#93c5fd";
  }
  banner.innerText = msg;
}

function handleAdminResetSubmit() {
  const keyInput = document.getElementById("admin-reset-key");
  const key = keyInput ? keyInput.value.trim() : "";
  if (!key) {
    alert("Please enter the Administrative Secret Key.");
    return;
  }
  if (!confirm("⚠️ WARNING: This will permanently reset all combat records, leaderboards, bounties, and war statistics. Proceed?")) {
    return;
  }
  const statusEl = document.getElementById("admin-reset-status");
  if (statusEl) {
    statusEl.style.display = "block";
    statusEl.style.color = "#93c5fd";
    statusEl.innerText = "Executing database wipe...";
  }
  fetch("/api/admin/reset", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ secret: key })
  })
  .then(res => res.json().then(data => ({ status: res.status, body: data })))
  .then(({ status, body }) => {
    if (status === 200 && body.success) {
      if (statusEl) {
        statusEl.style.color = "#34d399";
        statusEl.innerText = "✅ " + body.message;
      }
      cachedKills = null;
      if (keyInput) keyInput.value = "";
    } else {
      if (statusEl) {
        statusEl.style.color = "#f87171";
        statusEl.innerText = "❌ " + (body.error || "Invalid secret key.");
      }
    }
  })
  .catch(err => {
    if (statusEl) {
      statusEl.style.color = "#f87171";
      statusEl.innerText = "❌ Network Error: " + err.message;
    }
  });
}

// ----------------- Character Selector & Verified Character Claims -----------------

let knownCharactersCache = [];

function getOwnerToken() {
  let token = localStorage.getItem("wowkb_owner_token");
  if (!token) {
    token = "tok_" + Math.random().toString(36).substring(2, 10) + Math.random().toString(36).substring(2, 10);
    localStorage.setItem("wowkb_owner_token", token);
  }
  return token;
}

function openCharacterLinkModal() {
  const modal = document.getElementById("character-link-modal");
  if (!modal) return;
  modal.style.display = "flex";
  switchCharModalTab("known");
  loadKnownCharacters();
}

function closeCharacterLinkModal() {
  const modal = document.getElementById("character-link-modal");
  if (modal) modal.style.display = "none";
}

function handleCharacterModalBackdrop(event) {
  if (event.target && event.target.id === "character-link-modal") {
    closeCharacterLinkModal();
  }
}

function switchCharModalTab(tab) {
  const tabs = ["known", "custom"];
  tabs.forEach(t => {
    const btn = document.getElementById(`char-tab-btn-${t}`);
    const panel = document.getElementById(`char-panel-${t}`);
    if (btn) btn.classList.toggle("active", t === tab);
    if (panel) panel.style.display = (t === tab) ? "block" : "none";
  });
}

function showClaimCodeModal(name, code) {
  const modal = document.getElementById("claim-code-modal");
  const nameEl = document.getElementById("claim-modal-char-name");
  const codeEl = document.getElementById("claim-modal-code");
  const cmdEl = document.getElementById("claim-modal-command");
  const statusEl = document.getElementById("claim-modal-status");
  if (!modal) return;
  if (nameEl) nameEl.innerText = name;
  if (codeEl) codeEl.innerText = code;
  if (cmdEl) cmdEl.innerText = `/kb claim ${code}`;
  if (statusEl) {
    statusEl.innerText = "";
    statusEl.style.display = "none";
  }
  modal.style.display = "flex";
}

function closeClaimCodeModal() {
  const modal = document.getElementById("claim-code-modal");
  if (modal) modal.style.display = "none";
  loadKnownCharacters();
}

async function checkClaimStatus() {
  const nameEl = document.getElementById("claim-modal-char-name");
  const name = nameEl ? nameEl.innerText.trim() : "";
  const codeEl = document.getElementById("claim-modal-code");
  const code = codeEl ? codeEl.innerText.trim() : "";
  const statusEl = document.getElementById("claim-modal-status");
  if (!name) return;
  if (statusEl) {
    statusEl.innerHTML = `<span style="color:#00e5ff;">Checking ownership status on server...</span>`;
    statusEl.style.display = "block";
  }
  try {
    const res = await fetch("/api/characters?limit=100", {
      headers: { "X-Owner-Token": getOwnerToken() }
    });
    if (!res.ok) throw new Error("Failed to query characters");
    const chars = await res.json();
    const c = chars.find(x => x.name.toLowerCase() === name.toLowerCase());
    if (c && c.is_verified) {
      if (statusEl) {
        statusEl.innerHTML = `<span style="color:#10b981; font-weight:700;">🛡️ Success! Ownership of ${escapeHtml(name)} is verified and locked!</span>`;
      }
      setTimeout(() => {
        closeClaimCodeModal();
        selectKnownCharacter(c.name, c.class, c.level, c.faction, c.guild, c.realm);
      }, 1000);
    } else {
      if (statusEl) {
        statusEl.innerHTML = `<span style="color:#eab308;">⏳ Pending: Run <code>/kb claim ${escapeHtml(code)}</code> in-game and type <code>/reload</code> (or run WoWKillboardSync.exe).</span>`;
      }
    }
  } catch (err) {
    if (statusEl) {
      statusEl.innerHTML = `<span style="color:#ef4444;">Error checking status: ${escapeHtml(err.message)}</span>`;
    }
  }
}

async function loadKnownCharacters() {
  const listEl = document.getElementById("char-known-list");
  const countEl = document.getElementById("char-known-count");
  if (!listEl) return;

  try {
    const res = await fetch("/api/characters?limit=100", {
      headers: { "X-Owner-Token": getOwnerToken() }
    });
    if (!res.ok) throw new Error("Failed to fetch characters");
    knownCharactersCache = await res.json();
    if (countEl) countEl.innerText = knownCharactersCache.length;
    renderKnownCharactersList(knownCharactersCache);
  } catch (err) {
    listEl.innerHTML = `<div style="text-align:center; padding:20px; color:#ef4444;">Failed to load characters: ${err.message}</div>`;
  }
}

function filterKnownCharacters(query) {
  const searchInput = document.getElementById("char-search-input");
  const factionSelect = document.getElementById("char-faction-filter");
  const search = (query !== undefined ? query : (searchInput ? searchInput.value : "")).trim().toLowerCase();
  const faction = factionSelect ? factionSelect.value.toLowerCase() : "";

  const filtered = knownCharactersCache.filter(c => {
    const matchesSearch = !search || c.name.toLowerCase().includes(search) || (c.guild && c.guild.toLowerCase().includes(search));
    const matchesFaction = !faction || (c.faction && c.faction.toLowerCase() === faction);
    return matchesSearch && matchesFaction;
  });

  renderKnownCharactersList(filtered);
}

function renderKnownCharactersList(chars) {
  const listEl = document.getElementById("char-known-list");
  if (!listEl) return;

  if (!chars || chars.length === 0) {
    listEl.innerHTML = `
      <div style="text-align:center; padding:30px; color:#64748b;">
        <div>No matching combatants found.</div>
        <button type="button" class="pill-btn" style="margin-top:10px; background:var(--accent-cyan); color:#000; font-weight:700;" onclick="switchCharModalTab('custom')">
          + Register Custom Hero Name
        </button>
      </div>
    `;
    return;
  }

  const activeChar = (localStorage.getItem("wowkb_user_character") || "").toLowerCase();

  listEl.innerHTML = chars.map(c => {
    const cls = (c.class || "WARRIOR").toUpperCase();
    const clsColor = CLASS_COLORS[cls] || CLASS_COLORS.UNKNOWN;
    const isAct = (c.name.toLowerCase() === activeChar);
    const lvlStr = (c.level && c.level > 0 && c.level <= 85) ? `Level ${c.level}` : "Level ??";
    const guildStr = (c.guild && c.guild !== "None") ? `&lt;${escapeHtml(c.guild)}&gt;` : "";
    const isAlliance = (c.faction && c.faction.toLowerCase() === "alliance");
    const factionIcon = isAlliance ? "/static/icons/factions/alliance.jpg" : "/static/icons/factions/horde.jpg";

    let actionBtnHtml = "";
    let claimBadgeHtml = "";

    if (c.is_claimed) {
      if (c.is_verified) {
        // Certified / Verified Owner
        if (c.is_owner) {
          claimBadgeHtml = `<span style="background:rgba(16, 185, 129, 0.15); color:#10b981; border:1px solid rgba(16, 185, 129, 0.3); font-size:0.65rem; font-weight:700; padding:1px 6px; border-radius:3px; margin-left:6px;">🛡️ Verified Owner</span>`;
          if (isAct) {
            actionBtnHtml = `
              <div style="display:flex; gap:6px;">
                <button class="pill-btn active" style="background:#10b981; color:#fff; font-size:0.75rem; padding:4px 10px;" disabled>✓ Selected</button>
                <button class="pill-btn" style="background:rgba(239, 68, 68, 0.15); color:#ef4444; border:1px solid rgba(239, 68, 68, 0.35); font-size:0.72rem; padding:4px 8px; cursor:pointer;" onclick="releaseClaim('${escapeHtml(c.name)}')">Unlink</button>
              </div>
            `;
          } else {
            actionBtnHtml = `
              <div style="display:flex; gap:6px;">
                <button class="pill-btn" style="background:#10b981; color:#fff; font-weight:700; font-size:0.75rem; padding:5px 12px; border:none; cursor:pointer;" onclick="selectKnownCharacter('${escapeHtml(c.name)}', '${cls}', ${c.level || 60}, '${escapeHtml(c.faction || 'Alliance')}', '${escapeHtml(c.guild || 'None')}', '${escapeHtml(c.realm || 'WoW Forever')}')">Select &rarr;</button>
                <button class="pill-btn" style="background:rgba(239, 68, 68, 0.15); color:#ef4444; border:1px solid rgba(239, 68, 68, 0.35); font-size:0.72rem; padding:5px 8px; cursor:pointer;" onclick="releaseClaim('${escapeHtml(c.name)}')">Unlink</button>
              </div>
            `;
          }
        } else {
          claimBadgeHtml = `<span style="background:rgba(239, 68, 68, 0.15); color:#ef4444; border:1px solid rgba(239, 68, 68, 0.3); font-size:0.65rem; font-weight:700; padding:1px 6px; border-radius:3px; margin-left:6px;" title="This character has been claimed and locked by its verified owner.">🔒 Claimed (Protected)</span>`;
          actionBtnHtml = `<button class="pill-btn" style="background:#334155; color:#64748b; font-size:0.75rem; padding:4px 12px; cursor:not-allowed;" title="Locked by verified owner" disabled>Locked</button>`;
        }
      } else {
        // Pending In-Game Verification (NOT Verified!)
        if (c.is_owner) {
          claimBadgeHtml = `<span style="background:rgba(234, 179, 8, 0.15); color:#eab308; border:1px solid rgba(234, 179, 8, 0.3); font-size:0.65rem; font-weight:700; padding:1px 6px; border-radius:3px; margin-left:6px;">⏳ Verification Pending</span>`;
          const code = c.claim_code || "";
          actionBtnHtml = `
            <div style="display:flex; gap:6px;">
              <button class="pill-btn" style="background:linear-gradient(135deg, #d97706 0%, #b45309 100%); color:#fff; font-weight:700; font-size:0.72rem; padding:5px 10px; border:none; cursor:pointer;" onclick="showClaimCodeModal('${escapeHtml(c.name)}', '${escapeHtml(code)}')">Verify Code</button>
              <button class="pill-btn" style="background:rgba(239, 68, 68, 0.15); color:#ef4444; border:1px solid rgba(239, 68, 68, 0.35); font-size:0.72rem; padding:5px 8px; cursor:pointer;" title="Cancel pending claim" onclick="releaseClaim('${escapeHtml(c.name)}')">Cancel</button>
            </div>
          `;
        } else {
          claimBadgeHtml = `<span style="background:rgba(148, 163, 184, 0.15); color:#94a3b8; border:1px solid rgba(148, 163, 184, 0.3); font-size:0.65rem; font-weight:700; padding:1px 6px; border-radius:3px; margin-left:6px;">🔒 Claim Pending</span>`;
          actionBtnHtml = `<button class="pill-btn" style="background:#334155; color:#64748b; font-size:0.75rem; padding:4px 12px; cursor:not-allowed;" title="Pending verification by another player" disabled>Pending</button>`;
        }
      }
    } else {
      // Unclaimed Champion
      if (isAct) {
        actionBtnHtml = `
          <div style="display:flex; gap:6px;">
            <button class="pill-btn active" style="background:#10b981; color:#fff; font-size:0.75rem; padding:4px 10px;" disabled>✓ Selected</button>
            <button class="pill-btn" style="background:linear-gradient(135deg, #0284c7 0%, #0369a1 100%); color:#fff; font-weight:700; font-size:0.72rem; padding:5px 10px; border:none; cursor:pointer;" onclick="claimKnownCharacter('${escapeHtml(c.name)}', '${cls}', ${c.level || 60}, '${escapeHtml(c.faction || 'Alliance')}', '${escapeHtml(c.guild || 'None')}', '${escapeHtml(c.realm || 'WoW Forever')}')">Claim Champion &rarr;</button>
          </div>
        `;
      } else {
        actionBtnHtml = `
          <div style="display:flex; gap:6px;">
            <button class="pill-btn" style="background:rgba(255,255,255,0.08); color:#cbd5e1; border:1px solid rgba(255,255,255,0.2); font-size:0.75rem; padding:5px 10px; cursor:pointer;" onclick="selectKnownCharacter('${escapeHtml(c.name)}', '${cls}', ${c.level || 60}, '${escapeHtml(c.faction || 'Alliance')}', '${escapeHtml(c.guild || 'None')}', '${escapeHtml(c.realm || 'WoW Forever')}')">Select</button>
            <button class="pill-btn" style="background:linear-gradient(135deg, #0284c7 0%, #0369a1 100%); color:#fff; font-weight:700; font-size:0.75rem; padding:5px 12px; border:none; cursor:pointer;" onclick="claimKnownCharacter('${escapeHtml(c.name)}', '${cls}', ${c.level || 60}, '${escapeHtml(c.faction || 'Alliance')}', '${escapeHtml(c.guild || 'None')}', '${escapeHtml(c.realm || 'WoW Forever')}')">Claim Champion &rarr;</button>
          </div>
        `;
      }
    }

    return `
      <div class="char-select-card ${isAct ? 'active' : ''}">
        <div class="char-select-info">
          <img src="${factionIcon}" style="width:24px; height:24px; border-radius:50%; object-fit:cover; border:1px solid ${isAlliance ? '#38bdf8' : '#ef4444'}; flex-shrink:0;" alt="${c.faction || 'Faction'}">
          <div class="char-avatar-mini" style="border:1px solid ${clsColor}; border-radius:4px; overflow:hidden; width:28px; height:28px; flex-shrink:0;">
            <img src="/static/icons/classes/${cls.toLowerCase()}.jpg" style="width:100%; height:100%; object-fit:cover;" onerror="this.src='/static/icons/classes/warrior.jpg'" alt="${cls}">
          </div>
          <div style="min-width:0; flex:1;">
            <div style="font-weight:800; font-size:0.95rem; display:flex; align-items:center; flex-wrap:wrap; gap:4px;">
              <span style="color:${clsColor};">${escapeHtml(c.name)}</span>
              ${isAct ? '<span style="background:var(--accent-cyan); color:#000; font-size:0.65rem; font-weight:800; padding:1px 6px; border-radius:3px;">ACTIVE</span>' : ''}
              ${claimBadgeHtml}
            </div>
            <div style="font-size:0.75rem; color:#94a3b8; display:flex; align-items:center; gap:6px; margin-top:2px; flex-wrap:wrap;">
              <span>${lvlStr} ${cls.charAt(0) + cls.slice(1).toLowerCase()}</span>
              <span>&bull;</span>
              <span style="color:${isAlliance ? '#60a5fa' : '#f87171'};">${escapeHtml(c.faction || 'Neutral')}</span>
              ${guildStr ? `<span>&bull;</span> <span style="color:#cbd5e1; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:140px;">${guildStr}</span>` : ''}
            </div>
          </div>
        </div>
        <div class="char-select-actions">
          ${actionBtnHtml}
        </div>
      </div>
    `;
  }).join('');
}

async function claimKnownCharacter(name, cls, lvl, faction, guild, realm) {
  try {
    const res = await fetch("/api/auth/claim-character", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Owner-Token": getOwnerToken()
      },
      body: JSON.stringify({
        name: name,
        realm: realm || "WoW Forever",
        level: lvl || 60,
        class: cls || "WARRIOR",
        faction: faction || "Alliance",
        guild: guild || "None",
        owner_token: getOwnerToken()
      })
    });
    const d = await res.json();
    if (!res.ok || d.error) {
      alert(d.error || "Failed to claim character.");
      return;
    }
    if (d.owner_token) {
      localStorage.setItem("wowkb_owner_token", d.owner_token);
    }
    // Refresh character list so it displays "⏳ Verification Pending"
    loadKnownCharacters();
    if (d.claim_code) {
      showClaimCodeModal(name, d.claim_code);
    }
  } catch (err) {
    alert("Error claiming character: " + err.message);
  }
}

async function releaseClaim(name) {
  if (!confirm(`Are you sure you want to release the claim on "${name}"? This allows any player to claim or link it.`)) {
    return;
  }
  try {
    const res = await fetch("/api/auth/release-claim", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Owner-Token": getOwnerToken()
      },
      body: JSON.stringify({
        name: name,
        owner_token: getOwnerToken()
      })
    });
    const d = await res.json();
    if (!res.ok || d.error) {
      alert("Error releasing claim: " + (d.error || "Unknown error"));
      return;
    }
    const currentActive = (localStorage.getItem("wowkb_user_character") || "").toLowerCase();
    if (name.toLowerCase() === currentActive) {
      portalSignOut();
    }
    loadKnownCharacters();
  } catch (err) {
    alert("Network error: " + err.message);
  }
}

function selectKnownCharacter(name, cls, lvl, faction, guild, realm) {
  localStorage.setItem("wowkb_account_username", name);
  localStorage.setItem("wowkb_user_character", name);
  localStorage.setItem("wow_killboard_hunter_name", name);
  localStorage.setItem("wowkb_user_class", cls || "WARRIOR");
  localStorage.setItem("wowkb_user_faction", faction || "Alliance");
  localStorage.setItem("wowkb_user_level", lvl || 60);
  localStorage.setItem("wowkb_user_guild", guild || "None");
  localStorage.setItem("wowkb_user_realm", realm || "WoW Forever");
  localStorage.setItem("wowkb_supporter_active", "1");
  sessionStorage.setItem("wowkb_auth_type", "account");
  sessionStorage.setItem("wowkb_has_entered_feed", "1");
  portalAccessMode = "account";

  closeCharacterLinkModal();
  renderHeaderAuthBadge();
  updateSupporterButton();

  if (currentTab === "PORTAL") {
    portalLaunchFront("FOREVER");
  } else {
    loadKills();
    loadSidebar();
    if (currentTab === "FEED" || currentTab === "INTEL") {
      loadMostWanted();
    }
  }
}

async function handleCustomCharacterClaim(event) {
  if (event) event.preventDefault();
  const nameInput = document.getElementById("custom-char-name");
  const realmInput = document.getElementById("custom-char-realm");
  const levelInput = document.getElementById("custom-char-level");
  const classInput = document.getElementById("custom-char-class");
  const factionInput = document.getElementById("custom-char-faction");
  const guildInput = document.getElementById("custom-char-guild");

  const name = nameInput ? nameInput.value.trim() : "";
  if (!name) {
    alert("Please enter a character name.");
    return;
  }

  const realm = realmInput ? realmInput.value.trim() : "WoW Forever";
  const level = levelInput ? parseInt(levelInput.value) || 60 : 60;
  const cls = classInput ? classInput.value : "WARRIOR";
  const faction = factionInput ? factionInput.value : "Alliance";
  const guild = guildInput ? guildInput.value.trim() : "None";

  try {
    const res = await fetch("/api/auth/claim-character", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Owner-Token": getOwnerToken()
      },
      body: JSON.stringify({
        name, realm, level, class: cls, faction, guild,
        owner_token: getOwnerToken()
      })
    });
    const d = await res.json();
    if (d.success) {
      switchCharModalTab("known");
      loadKnownCharacters();
      if (d.claim_code) {
        showClaimCodeModal(name, d.claim_code);
      }
    } else {
      alert("Error claiming character: " + (d.error || "Unknown error"));
    }
  } catch (err) {
    alert("Network error claiming character: " + err.message);
  }
}

// ----------------- Header Auth & Theater State -----------------

function renderHeaderAuthBadge() {
  const badge = document.getElementById("header-auth-badge");
  if (!badge) return;

  const authType = sessionStorage.getItem("wowkb_auth_type");
  const username = localStorage.getItem("wowkb_account_username") || localStorage.getItem("wowkb_user_character") || sessionStorage.getItem("wowkb_character_name");
  const cls = (localStorage.getItem("wowkb_user_class") || "WARRIOR").toUpperCase();
  const clsColor = CLASS_COLORS[cls] || CLASS_COLORS.UNKNOWN;
  const lvl = localStorage.getItem("wowkb_user_level") || 60;
  const faction = (localStorage.getItem("wowkb_user_faction") || "Alliance").toLowerCase();
  const isAlliance = (faction === "alliance");
  const factionIcon = isAlliance ? "/static/icons/factions/alliance.jpg" : "/static/icons/factions/horde.jpg";

  if (authType && username) {
    const displayName = escapeHtml(username);
    badge.innerHTML = `
      <div class="header-user-pill" style="display:flex; align-items:center; gap:8px;">
        <img src="${factionIcon}" style="width:20px; height:20px; border-radius:50%; object-fit:cover; border:1px solid ${isAlliance ? '#38bdf8' : '#ef4444'};" alt="${faction}">
        <div style="border:1px solid ${clsColor}; border-radius:3px; overflow:hidden; width:20px; height:20px;">
          <img src="/static/icons/classes/${cls.toLowerCase()}.jpg" style="width:100%; height:100%; object-fit:cover;" onerror="this.src='/static/icons/classes/warrior.jpg'" alt="${cls}">
        </div>
        <span class="clickable-player" onclick="openCharacterProfile('${displayName}')" style="cursor:pointer;" title="View Profile">
          <strong style="color:${clsColor};">${displayName}</strong>
          <span style="font-size:0.75rem; color:#94a3b8;">(${lvl})</span>
        </span>
        <button class="header-switch-btn" onclick="openCharacterLinkModal()" title="Switch or Claim Character" style="background:rgba(255,255,255,0.08); border:1px solid rgba(255,255,255,0.2); color:#cbd5e1; border-radius:4px; padding:2px 8px; font-size:0.72rem; cursor:pointer;">Switch</button>
        <button class="header-signout-btn" onclick="handleHeaderSignOut()" title="Sign out">Sign Out</button>
      </div>
    `;
  } else {
    badge.innerHTML = `
      <button class="header-signin-btn" onclick="openCharacterLinkModal()">
        <span class="btn-text-desktop">Select / Claim Character</span>
        <span class="btn-text-mobile">⚔️ Claim Hero</span>
      </button>
    `;
  }
}

// ----------------- Web War Rallies Telemetry View & Muster Modal -----------------

let currentRallyGroupType = "PARTY";
let currentRallyContentType = "WORLD";
let currentRallyRoles = { tank: true, heal: true, dps: true };

const RALLY_OPEN_WORLD_ZONES = [
  "Stranglethorn Vale",
  "Hillsbrad Foothills",
  "Arathi Highlands",
  "Ashenvale",
  "Blackrock Mountain",
  "The Barrens",
  "Redridge Mountains",
  "Duskwood",
  "Tanaris",
  "Silithus",
  "Winterspring",
  "Western Plaguelands",
  "Eastern Plaguelands",
  "Felwood",
  "Un'Goro Crater",
  "Burning Steppes",
  "Searing Gorge",
  "Badlands",
  "Blasted Lands",
  "Feralas",
  "Desolace",
  "Dustwallow Marsh",
  "Alterac Mountains",
  "Thousand Needles",
  "Stonetalon Mountains",
  "Darkshore",
  "Westfall",
  "Loch Modan",
  "Wetlands",
  "Silverpine Forest",
  "Swamp of Sorrows"
];

const RALLY_BATTLEGROUND_ZONES = [
  "Warsong Gulch",
  "Arathi Basin",
  "Alterac Valley"
];

function populateRallyTargetDropdown() {
  const selectEl = document.getElementById("rally-select-target");
  const customWrap = document.getElementById("rally-custom-location-wrap");
  if (!selectEl) return;

  const isBG = (currentRallyContentType === "BG");
  const list = isBG ? RALLY_BATTLEGROUND_ZONES : RALLY_OPEN_WORLD_ZONES;
  const optLabel = isBG ? "WoW Forever Battlegrounds" : "Open World Zones";

  let html = `<optgroup label="${optLabel}">`;
  list.forEach(z => {
    html += `<option value="${escapeHtml(z)}">${escapeHtml(z)}</option>`;
  });
  html += `</optgroup>`;
  html += `<optgroup label="Custom Location">`;
  html += `<option value="__CUSTOM__">Custom Location (Type your own)...</option>`;
  html += `</optgroup>`;

  selectEl.innerHTML = html;
  if (customWrap) customWrap.style.display = "none";
}

function handleRallyTargetChange(val) {
  const customWrap = document.getElementById("rally-custom-location-wrap");
  const customInput = document.getElementById("rally-input-zone-custom");
  if (val === "__CUSTOM__") {
    if (customWrap) customWrap.style.display = "block";
    if (customInput) customInput.focus();
  } else {
    if (customWrap) customWrap.style.display = "none";
  }
}

function openRallyMusterModal() {
  const modal = document.getElementById("rally-muster-modal");
  if (!modal) return;
  modal.style.display = "flex";
  selectRallyGroupType("PARTY");
  selectRallyContentType("WORLD");
  populateRallyTargetDropdown();
}

function closeRallyMusterModal() {
  const modal = document.getElementById("rally-muster-modal");
  if (modal) modal.style.display = "none";
}

function selectRallyGroupType(type) {
  currentRallyGroupType = type;
  const pBtn = document.getElementById("rally-grp-party");
  const rBtn = document.getElementById("rally-grp-raid");
  if (pBtn) pBtn.classList.toggle("active", type === "PARTY");
  if (rBtn) rBtn.classList.toggle("active", type === "RAID");
}

function selectRallyContentType(type) {
  currentRallyContentType = type;
  const wBtn = document.getElementById("rally-cnt-world");
  const bBtn = document.getElementById("rally-cnt-bg");
  if (wBtn) wBtn.classList.toggle("active", type === "WORLD");
  if (bBtn) bBtn.classList.toggle("active", type === "BG");
  populateRallyTargetDropdown();
}

function setRallyLevelPreset(min, max) {
  const minEl = document.getElementById("rally-input-min-level");
  const maxEl = document.getElementById("rally-input-max-level");
  if (minEl) minEl.value = min;
  if (maxEl) maxEl.value = max;
}

function toggleRallyRole(role) {
  currentRallyRoles[role] = !currentRallyRoles[role];
  const btn = document.getElementById(`rally-role-${role}`);
  if (btn) {
    btn.classList.toggle("active", currentRallyRoles[role]);
    if (currentRallyRoles[role]) {
      if (role === "tank") {
        btn.style.background = "rgba(56, 189, 248, 0.18)";
        btn.style.color = "#38bdf8";
        btn.style.borderColor = "rgba(56, 189, 248, 0.6)";
      } else if (role === "heal") {
        btn.style.background = "rgba(34, 197, 94, 0.18)";
        btn.style.color = "#22c55e";
        btn.style.borderColor = "rgba(34, 197, 94, 0.6)";
      } else if (role === "dps") {
        btn.style.background = "rgba(239, 68, 68, 0.18)";
        btn.style.color = "#ef4444";
        btn.style.borderColor = "rgba(239, 68, 68, 0.6)";
      }
    } else {
      btn.style.background = "rgba(15, 23, 42, 0.6)";
      btn.style.color = "#64748b";
      btn.style.borderColor = "rgba(148, 163, 184, 0.2)";
    }
  }
}

async function handleCreateRallySubmit(event) {
  if (event) event.preventDefault();
  const selectTarget = document.getElementById("rally-select-target");
  const customInput = document.getElementById("rally-input-zone-custom");
  const minLevelInput = document.getElementById("rally-input-min-level");
  const maxLevelInput = document.getElementById("rally-input-max-level");
  const msgInput = document.getElementById("rally-input-msg");

  let zone = "Stranglethorn Vale";
  if (selectTarget && selectTarget.value === "__CUSTOM__") {
    zone = customInput ? customInput.value.trim() : "";
    if (!zone) {
      alert("Please type your custom location.");
      if (customInput) customInput.focus();
      return;
    }
  } else if (selectTarget && selectTarget.value) {
    zone = selectTarget.value.trim();
  }

  const minLevel = minLevelInput ? parseInt(minLevelInput.value) || 1 : 1;
  const maxLevel = maxLevelInput ? parseInt(maxLevelInput.value) || 60 : 60;
  const msg = msgInput ? msgInput.value.trim() : "Muster Vanguard Strike Team!";

  const commanderName = localStorage.getItem("wowkb_user_character") || localStorage.getItem("wowkb_account_username") || "Commander";
  const commanderClass = localStorage.getItem("wowkb_user_class") || "WARRIOR";
  const commanderFaction = localStorage.getItem("wowkb_user_faction") || "Alliance";
  const commanderGuild = localStorage.getItem("wowkb_user_guild") || "None";
  const commanderLevel = parseInt(localStorage.getItem("wowkb_user_level")) || 60;

  const payload = {
    character_name: commanderName,
    character_class: commanderClass,
    character_level: commanderLevel,
    faction: commanderFaction,
    guild_name: commanderGuild,
    zone: zone,
    group_type: currentRallyGroupType,
    content_type: currentRallyContentType,
    min_level: minLevel,
    max_level: maxLevel,
    roles: currentRallyRoles,
    message: msg,
    hostile_count: 1,
    hostile_names: (currentRallyContentType === "BG") ? "Enemy Vanguard" : "Hostile Combatants",
    timestamp: Math.floor(Date.now() / 1000)
  };

  try {
    const res = await fetch("/api/backup/distress", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });
    const d = await res.json();
    if (res.ok) {
      closeRallyMusterModal();
      loadRalliesView();
      alert(`Vanguard War Rally broadcasted for ${commanderName} in ${zone}!`);
    } else {
      alert("Failed to broadcast rally: " + (d.error || "Unknown error"));
    }
  } catch (err) {
    alert("Network error broadcasting rally: " + err.message);
  }
}

function loadRalliesView() {
  const container = document.getElementById("main-content-area");
  if (!container) return;

  container.innerHTML = `
    <div style="display:flex; flex-direction:column; gap:20px; max-width:960px; margin:0 auto; padding:10px 0 40px 0;">
      <!-- Header Banner -->
      <div style="background:rgba(15, 23, 42, 0.7); border:1px solid rgba(245, 158, 11, 0.4); border-radius:10px; padding:20px 24px; position:relative; overflow:hidden;">
        <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:16px;">
          <div>
            <div style="font-size:12px; font-weight:700; color:#f59e0b; text-transform:uppercase; letter-spacing:1px; margin-bottom:4px;">Frontline Vanguard Wire</div>
            <h2 style="font-size:24px; font-weight:800; color:#f8fafc; margin:0; display:flex; align-items:center; gap:10px;">
              <span>Vanguard Manhunt &amp; Call to Arms</span>
            </h2>
            <div style="font-size:14px; color:#94a3b8; margin-top:6px; max-width:640px;">
              Live joinable squads, open manhunts, and faction recruitment broadcast across Azeroth.
            </div>
          </div>
          <div style="display:flex; align-items:center; gap:10px;">
            <div style="background:rgba(217, 119, 6, 0.15); border:1px solid rgba(217, 119, 6, 0.45); border-radius:6px; padding:7px 14px; font-size:12px; color:#fbbf24; font-weight:700; display:flex; align-items:center; gap:8px;" title="Muster squads and manhunts in-game using the WoW Killboard addon (/kb manhunt)">
              <span>📯 Form up in-game: <code style="color:#fff; background:rgba(0,0,0,0.5); padding:2px 6px; border-radius:3px; font-family:monospace;">/kb manhunt</code></span>
            </div>
            <div style="background:rgba(30, 41, 59, 0.8); border:1px solid rgba(148, 163, 184, 0.2); border-radius:6px; padding:8px 14px; font-size:12px; color:#cbd5e1; display:flex; align-items:center; gap:8px;">
              <span style="display:inline-block; width:8px; height:8px; border-radius:50%; background:#10b981; animation:pulse 2s infinite;"></span>
              <span>Live Intel</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Information Callout -->
      <div style="background:rgba(14, 165, 233, 0.08); border-left:4px solid #00e5ff; border-radius:6px; padding:12px 18px; font-size:13px; color:#cbd5e1; display:flex; align-items:center; justify-content:space-between; flex-wrap:wrap; gap:10px;">
        <div>
          <strong style="color:#00e5ff;">In-Game Squad Join Notice:</strong>
          <span>Join any active squad inside World of Warcraft. Whisper <code>/w CommanderName manhunt</code> to any active rally commander for instant automatic squad invite.</span>
        </div>
        <span style="font-size:11px; color:#64748b; font-family:monospace;">Addon Feed Relay</span>
      </div>

      <!-- Live Rallies List Container -->
      <div id="rallies-list-container" style="display:flex; flex-direction:column; gap:14px;">
        <div style="text-align:center; padding:40px; color:#64748b;">
          Scanning frontline frequencies for active distress beacons...
        </div>
      </div>
    </div>
  `;

  // Fetch active beacons from /api/backup/distress
  fetch("/api/backup/distress")
    .then(r => r.json())
    .then(beacons => {
      const listEl = document.getElementById("rallies-list-container");
      if (!listEl) return;

      if (!beacons || beacons.length === 0) {
        listEl.innerHTML = `
          <div style="background:rgba(15, 23, 42, 0.5); border:1px dashed rgba(148, 163, 184, 0.2); border-radius:10px; padding:48px 24px; text-align:center;">
            <div style="margin-bottom:12px; display:flex; justify-content:center;">
              <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" stroke-width="1.8"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
            </div>
            <h3 style="font-size:18px; font-weight:700; color:#e2e8f0; margin:0 0 6px 0;">No Active Faction Manhunts</h3>
            <p style="font-size:14px; color:#94a3b8; max-width:540px; margin:0 auto 16px auto;">
              The frontier is quiet. No distress beacons or call-to-arms signals are currently broadcasting. Frontline squads will appear here in real-time when mustered in-game with the WoW Killboard addon (/kb manhunt)!
            </p>
            <div style="font-size:13px; color:#fbbf24; background:rgba(217, 119, 6, 0.12); border:1px solid rgba(217, 119, 6, 0.35); border-radius:6px; padding:8px 16px; display:inline-block;">
              <span>Form up in-game: <code style="color:#fff; background:rgba(0,0,0,0.5); padding:2px 6px; border-radius:3px; font-family:monospace;">/kb manhunt</code></span>
            </div>
          </div>
        `;
        return;
      }

      listEl.innerHTML = beacons.map(b => {
        const isAlliance = (b.faction === "Alliance");
        const factionColor = isAlliance ? "#38bdf8" : "#ef4444";
        const factionName = isAlliance ? "Alliance" : "Horde";
        const ago = (typeof timeAgo === "function") ? timeAgo(b.timestamp) : "Recent";
        const coords = (b.coord_x && b.coord_y && (b.coord_x > 0 || b.coord_y > 0)) ? `(${Number(b.coord_x).toFixed(1)}, ${Number(b.coord_y).toFixed(1)})` : "";
        const hostiles = b.hostile_names ? `${b.hostile_count || 1} Hostile(s) (${b.hostile_names})` : `${b.hostile_count || 1} Hostile(s)`;

        // Calculate exact duration rally has been running
        const elapsedSec = Math.max(0, Math.floor(Date.now() / 1000) - Number(b.timestamp || 0));
        let durationText = "";
        if (elapsedSec < 60) {
          durationText = `${elapsedSec}s`;
        } else if (elapsedSec < 3600) {
          const m = Math.floor(elapsedSec / 60);
          durationText = `${m}m`;
        } else {
          const h = Math.floor(elapsedSec / 3600);
          const remM = Math.floor((elapsedSec % 3600) / 60);
          durationText = `${h}h ${remM}m`;
        }

        const isRaid = (b.group_type === "RAID");
        const isBG = (b.content_type === "BG");
        const groupBadge = isRaid ? `<span style="background:rgba(239, 68, 68, 0.15); color:#ef4444; border:1px solid rgba(239, 68, 68, 0.3); font-size:11px; font-weight:700; padding:1px 6px; border-radius:4px;">40-MAN RAID</span>` : `<span style="background:rgba(59, 130, 246, 0.15); color:#38bdf8; border:1px solid rgba(59, 130, 246, 0.3); font-size:11px; font-weight:700; padding:1px 6px; border-radius:4px;">5-MAN SQUAD</span>`;
        const contentBadge = isBG ? `<span style="background:rgba(245, 158, 11, 0.15); color:#f59e0b; border:1px solid rgba(245, 158, 11, 0.3); font-size:11px; font-weight:700; padding:1px 6px; border-radius:4px;">BATTLEGROUND</span>` : `<span style="background:rgba(16, 185, 129, 0.15); color:#10b981; border:1px solid rgba(16, 185, 129, 0.3); font-size:11px; font-weight:700; padding:1px 6px; border-radius:4px;">OPEN WORLD PVP</span>`;
        const durationBadge = `<span style="display:inline-flex; align-items:center; gap:5px; background:rgba(245, 158, 11, 0.18); border:1px solid rgba(245, 158, 11, 0.5); border-radius:4px; padding:2px 8px; color:#fbbf24; font-weight:800; font-size:11px;">⏱️ Running for ${durationText}</span>`;
        const lvlBracket = (b.min_level || b.max_level) ? `<span style="font-size:11px; color:#cbd5e1; background:rgba(255,255,255,0.06); padding:1px 6px; border-radius:3px;">Lvl ${b.min_level || 1}–${b.max_level || 60}</span>` : "";
        const rolesStr = b.roles ? `<span style="font-size:11px; color:#94a3b8;">Roles: <strong style="color:#f8fafc;">${escapeHtml(b.roles)}</strong></span>` : "";
        const messageHtml = b.message ? `<div style="font-size:12px; color:#cbd5e1; font-style:italic; margin-top:8px; background:rgba(0,0,0,0.25); padding:6px 12px; border-radius:4px; border-left:3px solid #f59e0b;">"${escapeHtml(b.message)}"</div>` : "";

        return `
          <div style="background:rgba(15, 23, 42, 0.85); border:1px solid rgba(148, 163, 184, 0.15); border-left:4px solid ${factionColor}; border-radius:8px; padding:16px 20px; display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:16px;">
            <div style="display:flex; align-items:flex-start; gap:14px; flex:1; min-width:280px;">
              <div style="width:44px; height:44px; border-radius:8px; background:rgba(30, 41, 59, 0.8); border:1px solid rgba(148, 163, 184, 0.3); display:flex; align-items:center; justify-content:center; flex-shrink:0;">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" stroke-width="2"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/></svg>
              </div>
              <div style="flex:1;">
                <div style="display:flex; align-items:center; gap:8px; flex-wrap:wrap;">
                  <span style="font-size:16px; font-weight:800; color:#f8fafc;">${escapeHtml(b.character_name)}</span>
                  <span style="font-size:12px; font-weight:600; color:#ffd100; background:rgba(255, 209, 0, 0.1); border:1px solid rgba(255, 209, 0, 0.25); border-radius:4px; padding:1px 6px;">Lvl ${b.character_level || 60} ${escapeHtml(b.character_class || "Warrior")}</span>
                  ${b.guild_name && b.guild_name !== "None" ? `<span style="font-size:13px; color:#94a3b8;">&lt;${escapeHtml(b.guild_name)}&gt;</span>` : ""}
                  <span style="font-size:11px; font-weight:700; color:${factionColor}; background:${factionColor}18; border:1px solid ${factionColor}40; border-radius:4px; padding:1px 6px; text-transform:uppercase;">${factionName}</span>
                  ${groupBadge}
                  ${contentBadge}
                  ${durationBadge}
                  ${lvlBracket}
                </div>
                <div style="font-size:13px; color:#cbd5e1; margin-top:6px; display:flex; align-items:center; gap:12px; flex-wrap:wrap;">
                  <span><strong>${escapeHtml(b.zone || "Wilderness")}</strong> ${coords}</span>
                  ${rolesStr ? `<span style="color:#64748b;">•</span> ${rolesStr}` : ""}
                  <span style="color:#64748b;">•</span>
                  <span style="color:#ef4444;">${escapeHtml(hostiles)}</span>
                </div>
                ${messageHtml}
              </div>
            </div>
            <div style="text-align:right; flex-shrink:0;">
              <div style="font-size:12px; color:#fbbf24; font-weight:700;">Active for <strong>${durationText}</strong></div>
              <div style="font-size:11px; color:#94a3b8; margin-top:2px;">Mustered ${ago}</div>
              <div style="font-size:12px; color:#00e5ff; margin-top:6px; font-family:monospace; background:rgba(0, 229, 255, 0.08); border:1px solid rgba(0, 229, 255, 0.2); border-radius:4px; padding:4px 10px; display:inline-block;">
                /w ${escapeHtml(b.character_name)} rally
              </div>
            </div>
          </div>
        `;
      }).join("");
    })
    .catch(err => {
      console.error("Error loading rallies:", err);
      const listEl = document.getElementById("rallies-list-container");
      if (listEl) {
        listEl.innerHTML = `<div style="text-align:center; padding:30px; color:#ef4444;">Failed to load live manhunts.</div>`;
      }
    });
}

function handleHeaderSignOut() {
  portalSignOut();
}

function openLoginModal() {
  openCharacterLinkModal();
}

const THEATER_NAMES = {
  FOREVER: "WoW Forever",
  CLASSIC_ERA: "Classic Era",
  ANNIVERSARY: "Anniversary Edition",
  RETAIL: "Modern Retail"
};

function updateTheaterNavLabel() {
  const versionEl = document.getElementById("theater-nav-version");
  const serverPillEl = document.getElementById("theater-nav-server");
  const mNavEl = document.getElementById("m-nav-theater");
  const currentFlav = (typeof currentFlavor !== "undefined" && currentFlavor) ? currentFlavor : "FOREVER";
  const cfg = (typeof FLAVOR_CONFIGS !== "undefined" && FLAVOR_CONFIGS[currentFlav]) ? FLAVOR_CONFIGS[currentFlav] : null;
  const flavorColor = cfg ? (cfg.iconColor || "#00e5ff") : "#00e5ff";
  const displayVersion = THEATER_NAMES[currentFlav] || "WoW Forever";
  const activeSrvKey = (typeof getCurrentForeverServer === "function") ? getCurrentForeverServer() : "PVP";
  const srvInfo = (typeof FOREVER_SERVERS !== "undefined" && FOREVER_SERVERS[activeSrvKey]) 
    ? FOREVER_SERVERS[activeSrvKey] 
    : { name: "PvP", badgeColor: "#ef4444", badgeBg: "rgba(239, 68, 68, 0.15)", badgeBorder: "rgba(239, 68, 68, 0.45)" };

  // Update dynamic CSS variable for active menu underline and version color
  document.documentElement.style.setProperty("--active-flavor-color", flavorColor);

  if (versionEl) {
    versionEl.innerText = displayVersion;
    versionEl.style.color = flavorColor;
  }
  if (serverPillEl) {
    if (currentFlav === "FOREVER") {
      serverPillEl.style.display = "inline-flex";
      serverPillEl.innerText = srvInfo.name;
      serverPillEl.style.color = srvInfo.badgeColor;
      serverPillEl.style.backgroundColor = srvInfo.badgeBg;
      serverPillEl.style.borderColor = srvInfo.badgeBorder;
    } else {
      serverPillEl.style.display = "none";
    }
  }
  const caretEl = document.querySelector(".theater-caret");
  if (caretEl) {
    caretEl.style.color = flavorColor;
  }
  if (mNavEl) {
    const textSpan = mNavEl.querySelector("span");
    if (textSpan) {
      const srvSuffix = currentFlav === "FOREVER" ? ` (${srvInfo.name})` : "";
      textSpan.innerHTML = `<span class="theater-label">Theater:</span> <strong style="color:${flavorColor};">${displayVersion}${srvSuffix}</strong>`;
    }
  }
}

function updateNavigationLabels() {
  const activeSrv = (typeof getCurrentForeverServer === "function") ? getCurrentForeverServer() : "PVP";
  const isPve = (currentFlavor === "FOREVER" && activeSrv === "PVE");
  const isHc = (currentFlavor === "FOREVER" && activeSrv === "HARDCORE");
  const isRp = (currentFlavor === "FOREVER" && activeSrv === "RP");

  // 1. Desktop Navigation Buttons
  const navIntel = document.getElementById("nav-intel");
  const navLegends = document.getElementById("nav-legends");
  const navBounties = document.getElementById("nav-bounties");
  const navHazards = document.getElementById("nav-hazards");
  const navRallies = document.getElementById("nav-rallies");
  const navZones = document.getElementById("nav-zones");

  // 2. Mobile Drawer Navigation Items
  const mNavIntel = document.getElementById("m-nav-intel");
  const mNavLegends = document.getElementById("m-nav-legends");
  const mNavBounties = document.getElementById("m-nav-bounties");
  const mNavHazards = document.getElementById("m-nav-hazards");
  const mNavRallies = document.getElementById("m-nav-rallies");
  const mNavZones = document.getElementById("m-nav-zones");

  // 3. Top Mode Filter Pills
  const modeFilters = document.getElementById("header-mode-filters");

  // 4. Most Wanted Header
  const mwTitle = document.querySelector(".most-wanted-title");
  const mwSub = document.querySelector(".most-wanted-subtitle");
  const mwBtn = document.querySelector(".see-all-marks-btn");

  if (isPve) {
    if (navIntel) navIntel.innerText = "Casualties";
    if (navLegends) navLegends.innerText = "Deadly Hazards";
    if (navBounties) navBounties.innerText = "Wanted Monsters";
    if (navHazards) navHazards.innerText = "Bestiary";
    if (navRallies) navRallies.innerText = "Rescue Beacons";
    if (navZones) navZones.innerText = "Zone Mortality";

    if (mNavIntel && mNavIntel.querySelector("span")) mNavIntel.querySelector("span").innerText = "Casualties";
    if (mNavLegends && mNavLegends.querySelector("span")) mNavLegends.querySelector("span").innerText = "Deadly Hazards";
    if (mNavBounties && mNavBounties.querySelector("span")) mNavBounties.querySelector("span").innerText = "Wanted Monsters";
    if (mNavHazards && mNavHazards.querySelector("span")) mNavHazards.querySelector("span").innerText = "Bestiary";
    if (mNavRallies && mNavRallies.querySelector("span")) mNavRallies.querySelector("span").innerText = "Rescue Beacons";
    if (mNavZones && mNavZones.querySelector("span")) mNavZones.querySelector("span").innerText = "Zone Mortality";

    if (modeFilters) {
      modeFilters.innerHTML = `
        <div class="header-mode-pill active" style="border-color:#38bdf8; color:#38bdf8; background:rgba(56, 189, 248, 0.15); font-weight:700; cursor:default; pointer-events:none;">🛡️ PvE Ruleset</div>
      `;
    }

    if (mwTitle) mwTitle.innerHTML = "AZEROTH'S MOST WANTED &mdash; APEX PREDATORS &amp; ELITES";
    if (mwSub) mwSub.innerHTML = "Notorious Beasts &amp; Executioners Responsible for Mortal Casualties &bull; Track realm hazards";
    if (mwBtn) {
      mwBtn.innerHTML = "View Wanted Monsters &rarr;";
      mwBtn.onclick = () => switchTab('BOUNTIES');
    }
  } else if (isHc) {
    if (navIntel) navIntel.innerText = "Casualties";
    if (navLegends) navLegends.innerText = "Graveyard of Champions";
    if (navBounties) navBounties.innerText = "Apex Predators";
    if (navHazards) navHazards.innerText = "Deadly Hazards";
    if (navRallies) navRallies.innerText = "Rescue Beacons";
    if (navZones) navZones.innerText = "Zone Mortality";

    if (mNavIntel && mNavIntel.querySelector("span")) mNavIntel.querySelector("span").innerText = "Casualties";
    if (mNavLegends && mNavLegends.querySelector("span")) mNavLegends.querySelector("span").innerText = "Graveyard of Champions";
    if (mNavBounties && mNavBounties.querySelector("span")) mNavBounties.querySelector("span").innerText = "Apex Predators";
    if (mNavHazards && mNavHazards.querySelector("span")) mNavHazards.querySelector("span").innerText = "Deadly Hazards";
    if (mNavRallies && mNavRallies.querySelector("span")) mNavRallies.querySelector("span").innerText = "Rescue Beacons";
    if (mNavZones && mNavZones.querySelector("span")) mNavZones.querySelector("span").innerText = "Zone Mortality";

    if (modeFilters) {
      modeFilters.innerHTML = `
        <div class="header-mode-pill active" style="border-color:#f59e0b; color:#f59e0b; background:rgba(245, 158, 11, 0.15); font-weight:700; cursor:default; pointer-events:none;">💀 Hardcore (1 Life)</div>
      `;
    }

    if (mwTitle) mwTitle.innerHTML = "AZEROTH'S EXECUTIONERS &mdash; RUN ENDERS";
    if (mwSub) mwSub.innerHTML = "Monsters &amp; World Hazards that have permanently slain 1-Life characters across Azeroth";
    if (mwBtn) {
      mwBtn.innerHTML = "View Deadly Hazards &rarr;";
      mwBtn.onclick = () => switchTab('HAZARDS');
    }
  } else if (isRp) {
    if (navIntel) navIntel.innerText = "Intel";
    if (navLegends) navLegends.innerText = "Defender of Azeroth";
    if (navBounties) navBounties.innerText = "The Marked";
    if (navHazards) navHazards.innerText = "Deadly Hazards";
    if (navRallies) navRallies.innerText = "Chronicles";
    if (navZones) navZones.innerText = "Zone Intel";

    if (mNavIntel && mNavIntel.querySelector("span")) mNavIntel.querySelector("span").innerText = "Intel";
    if (mNavLegends && mNavLegends.querySelector("span")) mNavLegends.querySelector("span").innerText = "Defender of Azeroth";
    if (mNavBounties && mNavBounties.querySelector("span")) mNavBounties.querySelector("span").innerText = "The Marked";
    if (mNavHazards && mNavHazards.querySelector("span")) mNavHazards.querySelector("span").innerText = "Deadly Hazards";
    if (mNavRallies && mNavRallies.querySelector("span")) mNavRallies.querySelector("span").innerText = "Chronicles";
    if (mNavZones && mNavZones.querySelector("span")) mNavZones.querySelector("span").innerText = "Zone Intel";

    if (modeFilters) {
      modeFilters.innerHTML = `
        <div class="header-mode-pill active" style="border-color:#c084fc; color:#c084fc; background:rgba(192, 132, 252, 0.15); font-weight:700; cursor:default; pointer-events:none;">📜 Roleplay Realm</div>
      `;
    }

    if (mwTitle) mwTitle.innerHTML = "THE BLOOD LEDGER &mdash; AZEROTH'S MOST WANTED";
    if (mwSub) mwSub.innerHTML = "Open World Execution Contracts &amp; Certified Outlaws &bull; Deliver the final blow to claim the bounty";
    if (mwBtn) {
      mwBtn.innerHTML = "View The Marked &rarr;";
      mwBtn.onclick = () => switchTab('BOUNTIES');
    }
  } else {
    // PvP Default
    if (navIntel) navIntel.innerText = "Intel";
    if (navLegends) navLegends.innerText = "Defender of Azeroth";
    if (navBounties) navBounties.innerText = "The Marked";
    if (navHazards) navHazards.innerText = "Deadly Hazards";
    if (navRallies) navRallies.innerText = "Manhunt";
    if (navZones) navZones.innerText = "Zone Intel";

    if (mNavIntel && mNavIntel.querySelector("span")) mNavIntel.querySelector("span").innerText = "Intel";
    if (mNavLegends && mNavLegends.querySelector("span")) mNavLegends.querySelector("span").innerText = "Defender of Azeroth";
    if (mNavBounties && mNavBounties.querySelector("span")) mNavBounties.querySelector("span").innerText = "The Marked";
    if (mNavHazards && mNavHazards.querySelector("span")) mNavHazards.querySelector("span").innerText = "Deadly Hazards";
    if (mNavRallies && mNavRallies.querySelector("span")) mNavRallies.querySelector("span").innerText = "Manhunt";
    if (mNavZones && mNavZones.querySelector("span")) mNavZones.querySelector("span").innerText = "Zone Intel";

    if (modeFilters) {
      modeFilters.innerHTML = `
        <button class="header-mode-pill ${currentMode === 'WORLD' ? 'active' : ''}" id="hdr-pill-world" onclick="setFilterMode('WORLD')" title="Open-World Combat">World</button>
        <button class="header-mode-pill ${currentMode === 'BG' ? 'active' : ''}" id="hdr-pill-bg" onclick="setFilterMode('BG')" title="Battleground Matches">BGs</button>
        <button class="header-mode-pill ${currentMode === 'DUEL' ? 'active' : ''}" id="hdr-pill-duel" onclick="setFilterMode('DUEL')" title="1v1 Sanctioned Duels">Duels</button>
        <button class="header-mode-pill disabled" id="hdr-pill-arena" onclick="setFilterMode('ARENA')" title="Arena Matches">Arenas</button>
      `;
    }

    if (mwTitle) mwTitle.innerHTML = "THE BLOOD LEDGER &mdash; AZEROTH'S MOST WANTED";
    if (mwSub) mwSub.innerHTML = "Open World Execution Contracts &amp; Certified Outlaws &bull; Deliver the final blow to claim the bounty";
    if (mwBtn) {
      mwBtn.innerHTML = "View The Marked &rarr;";
      mwBtn.onclick = () => switchTab('BOUNTIES');
    }
  }
}

function reloadActiveView() {
  updateNavigationLabels();
  updateTheaterNavLabel();
  const isPve = (currentFlavor === "FOREVER" && typeof getCurrentForeverServer === "function" && getCurrentForeverServer() === "PVE");

  if (currentTab === "INTEL") {
    loadKills();
    loadMostWanted();
    loadSidebar();
  } else if (currentTab === "LEGENDS" || currentTab === "LEADERBOARDS") {
    if (isPve) {
      loadDeadlyNpcsView();
    } else {
      loadLeaderboards();
    }
    loadSidebar();
  } else if (currentTab === "BOUNTIES") {
    if (isPve) {
      loadPveBountiesView();
    } else {
      loadBounties();
    }
    loadSidebar();
  } else if (currentTab === "ZONES") {
    if (isPve) {
      loadPveZonesView();
    } else {
      loadZonesView();
    }
    loadSidebar();
  } else if (currentTab === "RALLIES") {
    if (isPve) {
      loadPveRalliesView();
    } else {
      loadRalliesView();
    }
    loadSidebar();
  } else if (currentTab === "HAZARDS" || currentTab === "DEADLY_NPCS") {
    loadDeadlyNpcsView();
    loadSidebar();
  } else if (currentTab === "ARMORY") {
    loadArmoryView();
  }
}

async function loadPveBountiesView() {
  const container = document.getElementById("main-content-area");
  if (!container) return;
  container.innerHTML = `<div style="text-align:center; padding:40px; color:#94a3b8;">Gathering Wanted Monster contracts &amp; apex predators...</div>`;

  try {
    const [lbRes, deathsRes] = await Promise.all([
      fetch("/api/pve/leaderboard"),
      fetch("/api/pve/deaths?limit=30")
    ]);
    const lb = await lbRes.json();
    const deaths = deathsRes.ok ? (await deathsRes.json()).deaths || [] : [];
    renderPveBountiesView(lb, deaths);
  } catch (err) {
    container.innerHTML = `<div style="text-align:center; padding:40px; color:#ef4444;">Failed to load Wanted Monsters: ${err.message}</div>`;
  }
}

function renderPveBountiesView(lbData, deaths) {
  const container = document.getElementById("main-content-area");
  if (!container) return;

  const npcs = (lbData && lbData.topDeadlyNpcs) || [];

  const monsterRoster = [
    { name: "Hogger", title: "Gnoll Chieftain", level: "11+", classification: "ELITE BOSS", zone: "Elwynn Forest", spell: "Vicious Bite", baseCopper: 5000, desc: "Terror of the Forest. High damage output against early questers." },
    { name: "Defias Pillager", title: "Bandit Sorcerer", level: "14-15", classification: "HUMANOID", zone: "Westfall", spell: "Fireball (240 DMG)", baseCopper: 2500, desc: "Lethal burst damage from Moonbrook tower roofs. Extreme range." },
    { name: "Son of Arugal", title: "Shadow Fang Worgen", level: "25+", classification: "ELITE PATROL", zone: "Silverpine Forest", spell: "Shadow Bolt / Rend", baseCopper: 10000, desc: "Roaming death machine. Wanders the main road ambushing level 12-14 mortals." },
    { name: "Mor'Ladim", title: "Restless Skeletal Knight", level: "35+", classification: "ELITE UNDEAD", zone: "Duskwood", spell: "Cleave / Mortal Strike", baseCopper: 25000, desc: "Cemetery executioner. Patrolling Raven Hill Cemetery with stealth-like aggro radius." },
    { name: "Stitches", title: "Embalmer's Construct", level: "35+", classification: "ELITE ABOMINATION", zone: "Duskwood", spell: "Aura of Rot / Slam", baseCopper: 30000, desc: "Marching abomination down the Duskwood highway towards Darkshire." }
  ];

  const cards = monsterRoster.map(m => {
    const liveMatch = npcs.find(n => n.npc_name.toLowerCase() === m.name.toLowerCase());
    const kills = liveMatch ? liveMatch.kills : (m.name === "Hogger" ? 3 : (m.name === "Defias Pillager" ? 2 : 1));
    const copper = m.baseCopper * Math.max(1, kills);
    let rewardText = "";
    if (copper >= 10000) rewardText = `${(copper / 10000).toFixed(copper % 10000 === 0 ? 0 : 1)}g`;
    else if (copper >= 100) rewardText = `${Math.floor(copper / 100)}s ${copper % 100 > 0 ? (copper % 100) + 'c' : ''}`.trim();
    else rewardText = `${copper}c`;

    return { ...m, kills, rewardText };
  });

  let html = `
    <div style="display: flex; flex-direction: column; gap: 24px;">
      <div style="background: rgba(14, 165, 233, 0.08); border-left: 4px solid #38bdf8; border-radius: 6px; padding: 14px 18px; font-size: 0.85rem; color: #cbd5e1; display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:10px;">
        <div>
          <strong style="color: #38bdf8; font-size:0.95rem;">🛡️ PvE Ruleset Active:</strong>
          <span>Player-vs-Player Marks of Spite are disabled on <strong>WoW Forever [PvE]</strong>. Showing realm-wide <strong>Monster Execution Bounties</strong> and lethal wilderness hazards.</span>
        </div>
        <span class="feed-count-pill" style="border-color:#38bdf8; color:#38bdf8;">PvE Campaign</span>
      </div>

      <div style="display:flex; justify-content:space-between; align-items:center; padding-bottom:8px; border-bottom:1px solid var(--wow-brass-border, #4a3b27); flex-wrap:wrap; gap:8px;">
        <div>
          <h2 class="wow-gold-header" style="font-size: 1.25rem; font-weight:800; letter-spacing:0.5px; margin:0;">
            Azeroth's Most Wanted &mdash; Apex Predators &amp; Hazardous Elites
          </h2>
          <div style="font-size:0.75rem; color:#856a36; margin-top:2px;">
            Town militia execution contracts for lethal beasts and rogue elites responsible for mortal deaths.
          </div>
        </div>
        <span style="font-size:0.8rem; font-family:var(--font-tactical); color:var(--accent-gold); font-weight:700;">
          ${cards.length} Wanted Targets Active
        </span>
      </div>

      <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 14px;">
        ${cards.map((c) => `
          <div class="stat-card bounty-target-card neutral" style="border-color: rgba(239, 68, 68, 0.4); background: linear-gradient(180deg, #181116 0%, #0a080d 100%);">
            <div style="display:flex; justify-content:space-between; align-items:center;">
              <div style="display:flex; align-items:center; gap:10px;">
                <div style="width:36px; height:36px; border-radius:50%; background:rgba(239, 68, 68, 0.15); border:1px solid #ef4444; display:flex; align-items:center; justify-content:center; font-size:1.2rem;">
                  💀
                </div>
                <div>
                  <div style="color:#fff; font-weight:800; font-size:1.1rem; text-shadow:0 2px 4px rgba(0,0,0,0.8);">${escapeHtml(c.name)}</div>
                  <div style="font-size:0.68rem; color:#cbd5e1;">Level ${c.level} &bull; ${escapeHtml(c.classification)}</div>
                </div>
              </div>
              <div style="text-align:right;">
                <span style="color:var(--accent-gold); font-weight:800; font-size:1.15rem; text-shadow:0 2px 4px rgba(0,0,0,0.8);">${c.rewardText}</span>
                <div><span class="bounty-faction-pill neutral" style="border-color:#ef4444; color:#f87171;">MILITIA BOUNTY</span></div>
              </div>
            </div>

            <div style="margin: 10px 0 6px 0; padding: 8px 10px; background: rgba(0,0,0,0.45); border-radius: 4px; border: 1px solid rgba(255,255,255,0.06); font-size:0.75rem;">
              <div style="display:flex; justify-content:space-between; margin-bottom:4px;">
                <span style="color:#94a3b8;">Primary Territory:</span>
                <strong style="color:#e2e8f0;">${escapeHtml(c.zone)}</strong>
              </div>
              <div style="display:flex; justify-content:space-between; margin-bottom:4px;">
                <span style="color:#94a3b8;">Lethal Spell:</span>
                <span style="color:#f87171; font-family:monospace; font-weight:600;">${escapeHtml(c.spell)}</span>
              </div>
              <div style="display:flex; justify-content:space-between;">
                <span style="color:#94a3b8;">Confirmed Slain:</span>
                <strong style="color:#ef4444; font-family:var(--font-tactical);">${c.kills} Mortals</strong>
              </div>
            </div>

            <div style="font-size:0.72rem; color:#94a3b8; font-style:italic; line-height:1.35; margin-bottom:10px;">
              ${escapeHtml(c.desc)}
            </div>

            <div style="display:flex; justify-content:space-between; align-items:center; padding-top:6px; border-top:1px solid rgba(255,255,255,0.06);">
              <span style="font-size:0.68rem; color:#64748b;">Issued by: Town Council</span>
              <button class="bounty-action-btn" onclick="switchTab('HAZARDS')" style="background:rgba(239, 68, 68, 0.2); border:1px solid #ef4444; color:#fca5a5; padding:4px 10px; font-size:0.75rem; border-radius:4px; cursor:pointer;">
                Execution Intel &rarr;
              </button>
            </div>
          </div>
        `).join('')}
      </div>

      <div style="margin-top:10px;">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px; padding-bottom:6px; border-bottom:1px solid var(--wow-brass-border, #4a3b27);">
          <div>
            <h3 class="wow-gold-header" style="font-size:1.05rem; font-weight:800; margin:0;">Mortality Ledger &amp; Spirit Debt</h3>
            <div style="font-size:0.72rem; color:#856a36;">Status of fallen mortal penance across Azeroth.</div>
          </div>
        </div>
        <div style="color: #64748b; font-size:0.8rem; padding: 16px 20px; background: rgba(3,4,7,0.7); border-radius:6px; border: 1px dashed rgba(255,255,255,0.08); text-align:center;">
          ✨ <strong>0 Mortals in Default:</strong> In PvE realms, all mortality debts are settled at the Spirit Healer. No players are branded onto the Realm KOS Blacklist.
        </div>
      </div>
    </div>
  `;

  container.innerHTML = html;
}

async function loadPveZonesView() {
  const container = document.getElementById("main-content-area");
  if (!container) return;
  container.innerHTML = `<div style="text-align:center; padding:40px; color:#94a3b8;">Loading Zone Mortality &amp; Wilderness Hazard Telemetry...</div>`;

  try {
    const [lbRes, deathsRes] = await Promise.all([
      fetch("/api/pve/leaderboard"),
      fetch("/api/pve/deaths?limit=50")
    ]);
    const lb = await lbRes.json();
    const deaths = deathsRes.ok ? (await deathsRes.json()).deaths || [] : [];

    const zoneCounts = {};
    deaths.forEach(d => {
      const z = d.zone || "Elwynn Forest";
      zoneCounts[z] = (zoneCounts[z] || 0) + 1;
    });
    if (Object.keys(zoneCounts).length === 0) {
      zoneCounts["Elwynn Forest"] = 3;
      zoneCounts["Westfall"] = 2;
      zoneCounts["Duskwood"] = 2;
      zoneCounts["Silverpine Forest"] = 1;
    }
    const zoneList = Object.entries(zoneCounts).map(([zone, kills]) => ({ zone, kills })).sort((a, b) => b.kills - a.kills);

    let html = `
      <div style="display:flex; flex-direction:column; gap:16px;">
        <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:12px; padding-bottom:10px; border-bottom:1px solid var(--wow-brass-border, #4a3b27);">
          <div>
            <h2 class="wow-gold-header" style="font-size:1.25rem; font-weight:800; letter-spacing:0.5px; margin:0;">
              ZONE MORTALITY &bull; WILDERNESS HAZARD INDEX
            </h2>
            <div style="font-size:0.75rem; color:#856a36; margin-top:3px;">
              Regional casualty rates, lethal predator territories, and dangerous road segments where mortals fall most frequently.
            </div>
          </div>
          <div style="display:flex; align-items:center; gap:8px;">
            <span class="feed-count-pill" style="border-color:#38bdf8; color:#38bdf8;">${zoneList.length} Hazard Zones</span>
            <button class="pill-btn" onclick="loadPveZonesView()" style="padding:4px 10px; font-size:0.75rem; background:rgba(255,255,255,0.06); cursor:pointer;">🔄 Refresh</button>
          </div>
        </div>

        <div style="display:flex; flex-direction:column; gap:8px;">
          <div style="font-family:var(--font-tactical); font-size:0.85rem; font-weight:800; color:#38bdf8; text-transform:uppercase; letter-spacing:0.5px; margin-bottom:2px;">
            🌲 REALM DEADLIEST WILDERNESS REGIONS
          </div>
    `;

    zoneList.forEach((z, idx) => {
      let threatColor = "#ffd100";
      let threatLabel = "WILDERNESS HAZARD";
      if (z.kills >= 3) {
        threatColor = "#ef4444";
        threatLabel = "EXTREME DANGER";
      } else if (z.kills >= 2) {
        threatColor = "#f97316";
        threatLabel = "HIGH CASUALTY";
      }

      html += `
        <div class="sidebar-row" style="background:var(--wow-iron-bg); border:1px solid var(--wow-brass-border); border-radius:6px; padding:12px 16px; display:flex; flex-direction:column; gap:6px;">
          <div style="display:flex; justify-content:space-between; align-items:center;">
            <div style="display:flex; align-items:center; gap:10px;">
              <span style="font-family:var(--font-tactical); font-weight:800; font-size:0.95rem; color:${idx === 0 ? '#38bdf8' : 'var(--wow-gold)'};">#${idx + 1}</span>
              <span style="font-weight:700; font-size:0.95rem; color:#f8fafc;">${escapeHtml(z.zone)}</span>
            </div>
            <div style="display:flex; align-items:center; gap:10px;">
              <span style="font-family:var(--font-tactical); font-size:0.75rem; font-weight:800; color:${threatColor}; background:rgba(0,0,0,0.5); padding:2px 8px; border-radius:3px; border:1px solid ${threatColor};">${threatLabel}</span>
              <span style="font-family:var(--font-tactical); font-size:0.9rem; font-weight:800; color:#ef4444;">${z.kills} Fallen Mortals</span>
            </div>
          </div>
        </div>
      `;
    });

    html += `
        </div>
      </div>
    `;
    container.innerHTML = html;
  } catch (e) {
    container.innerHTML = `<div style="text-align:center; padding:40px; color:#ef4444;">Failed to load Zone Mortality: ${e.message}</div>`;
  }
}

function loadPveRalliesView() {
  const container = document.getElementById("main-content-area");
  if (!container) return;

  container.innerHTML = `
    <div style="display:flex; flex-direction:column; gap:20px; max-width:960px; margin:0 auto; padding:10px 0 40px 0;">
      <div style="background:rgba(15, 23, 42, 0.7); border:1px solid rgba(56, 189, 248, 0.4); border-radius:10px; padding:20px 24px; position:relative; overflow:hidden;">
        <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:16px;">
          <div>
            <div style="font-size:12px; font-weight:700; color:#38bdf8; text-transform:uppercase; letter-spacing:1px; margin-bottom:4px;">PvE Rescue Network &bull; Frontline Frequency</div>
            <h2 style="font-size:24px; font-weight:800; color:#f8fafc; margin:0; display:flex; align-items:center; gap:10px;">
              <span>Expedition Rescue Beacons &amp; Squad Mustering</span>
            </h2>
            <div style="font-size:14px; color:#94a3b8; margin-top:6px; max-width:640px;">
              Form reinforcements for dangerous elite quests, dungeon parties, and world boss encounters.
            </div>
          </div>
          <div style="display:flex; align-items:center; gap:10px;">
            <div style="background:rgba(56, 189, 248, 0.15); border:1px solid rgba(56, 189, 248, 0.45); border-radius:6px; padding:7px 14px; font-size:12px; color:#38bdf8; font-weight:700; display:flex; align-items:center; gap:8px;">
              <span>🛡️ Signal in-game: <code style="color:#fff; background:rgba(0,0,0,0.5); padding:2px 6px; border-radius:3px; font-family:monospace;">/kb sos</code></span>
            </div>
          </div>
        </div>
      </div>

      <div style="background:rgba(14, 165, 233, 0.08); border-left:4px solid #38bdf8; border-radius:6px; padding:12px 18px; font-size:13px; color:#cbd5e1;">
        <strong style="color:#38bdf8;">Dungeon &amp; Quest Reinforcement:</strong>
        <span>All emergency distress signals broadcast across your faction network in real-time. Join nearby adventurers to defeat lethal world hazards together.</span>
      </div>

      <div id="rallies-list-container" style="display:flex; flex-direction:column; gap:14px;">
        <div style="text-align:center; padding:40px; color:#64748b; background:rgba(15,23,42,0.5); border:1px dashed rgba(255,255,255,0.08); border-radius:8px;">
          No active SOS emergency beacons transmitting. Use <code>/kb sos</code> in-game to broadcast a rescue signal to all active operatives.
        </div>
      </div>
    </div>
  `;
}

// ----------------- Warroom & Feuds -----------------

function renderSingleFeudCard(f) {
  const isCompleted = f.status === 'COMPLETED';
  const cScore = f.challenger_score || 0;
  const tScore = f.target_score_current || 0;
  const maxScore = f.target_score || 100;
  const cPct = Math.min(100, Math.round((cScore / maxScore) * 100));
  const tPct = Math.min(100, Math.round((tScore / maxScore) * 100));

  const cEntity = f.feud_type === 'GUILD' ? (f.challenger_guild || f.challenger_name) : f.challenger_name;
  const tEntity = f.feud_type === 'GUILD' ? (f.target_guild || f.target_name) : f.target_name;

  return `
    <div class="feud-card" style="${isCompleted ? 'border-color:#475569; opacity:0.85;' : 'border-color:#dc2626;'}">
      <div class="feud-card-header">
        <span style="font-size:0.75rem; font-weight:800; color:${isCompleted ? '#94a3b8' : '#ef4444'};">
          ${escapeHtml(f.feud_type || '')} CONTEST &bull; ${escapeHtml(f.status || '')}
        </span>
        <span style="font-size:0.72rem; color:#94a3b8;">Goal: First to ${maxScore} Kills</span>
      </div>

      <div class="feud-vs-row">
        <div style="text-align:left;">
          <div style="font-size:0.7rem; color:#3b82f6; font-weight:700;">CHALLENGER</div>
          <div style="font-size:1.05rem; font-weight:800; color:#fff;">${escapeHtml(cEntity || '')}</div>
          <div style="font-size:0.85rem; color:#3b82f6; font-weight:800; margin-top:2px;">${cScore} / ${maxScore}</div>
        </div>

        <div style="font-size:1.2rem; font-weight:900; color:#ef4444;">VS</div>

        <div style="text-align:right;">
          <div style="font-size:0.7rem; color:#ef4444; font-weight:700;">DEFENDER</div>
          <div style="font-size:1.05rem; font-weight:800; color:#fff;">${escapeHtml(tEntity || '')}</div>
          <div style="font-size:0.85rem; color:#ef4444; font-weight:800; margin-top:2px;">${tScore} / ${maxScore}</div>
        </div>
      </div>

      <!-- Double Progress Bar -->
      <div class="feud-progress-bar">
        <div class="feud-progress-fill-challenger" style="width:${cPct}%;"></div>
        <div style="flex:1; background:transparent;"></div>
        <div class="feud-progress-fill-target" style="width:${tPct}%;"></div>
      </div>

      <!-- Rules of Engagement Badges -->
      <div class="roe-pill-group">
        <span class="roe-pill">Min Level ${f.roe_min_level || 55}+</span>
        ${f.roe_underdog_bonus ? '<span class="roe-pill" style="border-color:#10b981; color:#10b981;">2x Underdog Bonus</span>' : ''}
        <span class="roe-pill" style="border-color:#f59e0b; color:#f59e0b;">Zerg Filter (0 Pts)</span>
        ${f.roe_zone ? `<span class="roe-pill">Zone: ${escapeHtml(f.roe_zone)}</span>` : ''}
      </div>

      ${isCompleted ? `
        <div style="background:#110d14; border:1px solid #10b981; border-radius:4px; padding:8px 10px; margin-top:10px; font-size:0.75rem; text-align:center;">
          <strong>Victor:</strong> <span style="color:#10b981; font-weight:800;">${escapeHtml(f.winner_name || "Unknown")}</span> &bull; Loser Consigned to KOS Blacklist!
        </div>
      ` : ''}
    </div>
  `;
}

async function loadWarroomView() {
  const container = document.getElementById("main-content-area");
  if (!container) return;
  container.innerHTML = `<div style="text-align:center; padding:40px; color:#94a3b8;">Loading Warroom tactical operations, blood feuds, and realm KOS records...</div>`;

  try {
    const [feudsRes, kosRes] = await Promise.all([
      fetch("/api/feuds"),
      fetch("/api/kos/blacklist")
    ]);
    const feuds = await feudsRes.json();
    const kosData = await kosRes.json();
    const guilds = kosData.guilds || [];
    const deserters = kosData.deserters || [];

    // Check signed-in user's character for personal wars pinning
    const myName = (localStorage.getItem("wowkb_account_username") || sessionStorage.getItem("wowkb_character_name") || "").toLowerCase().trim();
    let personalFeuds = [];
    let otherFeuds = [];

    if (Array.isArray(feuds)) {
      feuds.forEach(f => {
        const cName = (f.challenger_name || "").toLowerCase();
        const cGuild = (f.challenger_guild || "").toLowerCase();
        const tName = (f.target_name || "").toLowerCase();
        const tGuild = (f.target_guild || "").toLowerCase();

        if (myName && (cName === myName || cGuild === myName || tName === myName || tGuild === myName)) {
          personalFeuds.push(f);
        } else {
          otherFeuds.push(f);
        }
      });
    }

    let personalSectionHtml = "";
    if (personalFeuds.length > 0) {
      personalSectionHtml = `
        <div style="background:rgba(217, 119, 6, 0.08); border:1px solid var(--accent-gold); border-radius:8px; padding:18px 20px; margin-bottom:20px;">
          <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:14px;">
            <div style="display:flex; align-items:center; gap:8px;">
              <h3 style="font-size:1.05rem; color:var(--wow-gold); font-weight:800; margin:0;">
                Personal Engagements (${personalFeuds.length})
              </h3>
            </div>
            <span style="font-size:0.75rem; color:var(--accent-gold); font-weight:700;">Pinned to Top</span>
          </div>
          <div class="feuds-grid">
            ${personalFeuds.map(f => renderSingleFeudCard(f)).join("")}
          </div>
        </div>
      `;
    }

    let feudsGridHtml = "";
    if (otherFeuds.length === 0 && personalFeuds.length === 0) {
      feudsGridHtml = `
        <div style="background:#07090e; border:1px solid #1e293b; border-radius:8px; padding:24px; text-align:center; color:#64748b;">

          <div style="color:#e2e8f0; font-weight:700;">No Blood Feuds Active</div>
          <p style="font-size:0.8rem; margin-top:4px;">Challenge an enemy guild or player to a grudge match with custom Rules of Engagement!</p>
        </div>
      `;
    } else {
      feudsGridHtml = `
        <div class="feuds-grid">
          ${otherFeuds.map(f => renderSingleFeudCard(f)).join("")}
        </div>
      `;
    }

    let html = `
      <div style="display:flex; flex-direction:column; gap:24px;">
        <!-- Header & Action -->
        <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:12px;">
          <div>
            <h2 style="font-size:1.3rem; color:var(--accent-red); letter-spacing:-0.5px; display:flex; align-items:center; gap:8px; margin:0;">
              Warroom: Blood Feuds &amp; Rules of Engagement
            </h2>
            <div style="font-size:0.8rem; color:#94a3b8; margin-top:2px;">
              Guild Wars &amp; 1v1 Grudge Matches &bull; First to target score wins &bull; Defeated guilds condemned to the Realm KOS Blacklist!
            </div>
          </div>
          <button class="supporter-btn" style="background:linear-gradient(135deg, #b91c1c, #991b1b); border:1px solid #ef4444; color:#fff;" onclick="openDeclareFeudModal()">
            Declare Blood Feud
          </button>
        </div>

        <!-- Pinned Personal Wars -->
        ${personalSectionHtml}

        <!-- All Active Contests Grid -->
        <div>
          <h3 style="font-size:1rem; color:#e2e8f0; font-weight:700; margin-bottom:12px; display:flex; align-items:center; gap:8px;">
            Active Realm Feuds (${otherFeuds.length})
          </h3>
          ${feudsGridHtml}
        </div>

        <!-- Realm KOS Blacklist Section -->
        <div class="kos-section">
          <div style="border-top:1px solid #1e293b; padding-top:20px; display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:10px;">
            <div>
              <h2 style="font-size:1.25rem; color:var(--accent-red); display:flex; align-items:center; gap:8px; margin:0;">
                Realm KOS Blacklist &amp; Deserter Ledger
              </h2>
              <div style="font-size:0.78rem; color:#94a3b8; margin-top:2px;">
                Zero-Gold Retribution &bull; Defeated Guilds &amp; Outlaws Branded for Immediate Eradication &bull; In-Game Proximity Sirens Active
              </div>
            </div>
            <button class="nav-btn" style="border:1px solid #dc2626; color:#f87171; font-size:0.75rem;" onclick="openBrandKosModal()">
              + Brand KOS Target
            </button>
          </div>

          <!-- Blacklisted Guilds Table -->
          <div style="background:#07090e; border:1px solid #1e293b; border-radius:8px; padding:16px; margin-top:14px;">
            <h3 style="font-size:0.95rem; color:#f87171; margin-bottom:10px;">Blacklisted Enemy Guilds</h3>
            ${guilds.length === 0 ? '<div style="color:#64748b; font-size:0.8rem;">No enemy guilds currently blacklisted.</div>' : `
              <div style="display:flex; flex-direction:column; gap:8px;">
                ${guilds.map(g => `
                  <div style="display:flex; justify-content:space-between; align-items:center; background:#0f121a; padding:10px 14px; border-radius:6px; border-left:4px solid #dc2626;">
                    <div>
                      <strong style="color:#fff; font-size:0.95rem;" class="clickable-guild" onclick="openGuildProfile('${escapeHtml(g.entity_name)}')">&lt;${escapeHtml(g.entity_name)}&gt;</strong>
                      <span style="font-size:0.75rem; color:#94a3b8; margin-left:8px;">${escapeHtml(g.reason)}</span>
                    </div>
                    <span style="font-size:0.72rem; color:#f87171; background:rgba(220,38,38,0.2); padding:3px 8px; border-radius:4px; font-weight:800;">
                      KILL ON SIGHT
                    </span>
                  </div>
                `).join('')}
              </div>
            `}
          </div>

          <!-- 30-Day Anti-Guild-Hop Deserters Grid -->
          <div style="background:#07090e; border:1px solid #1e293b; border-radius:8px; padding:16px; margin-top:14px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px; flex-wrap:wrap; gap:6px;">
              <div>
                <h3 style="font-size:0.95rem; color:#fbbf24; margin:0;">30-Day Anti-Guild-Hop Deserter Stain</h3>
                <div style="font-size:0.72rem; color:#94a3b8; margin-top:2px;">
                  Leaving (/gquit) a blacklisted guild does not erase your shame. Tracked by permanent character Player-GUID.
                </div>
              </div>
              <span style="font-size:0.75rem; color:#f59e0b; font-weight:700;">${deserters.length} Marked Deserters</span>
            </div>

            <div class="deserter-grid">
              ${deserters.length === 0 ? '<div style="color:#64748b; font-size:0.8rem; grid-column:1/-1;">No deserters currently serving penance.</div>' : deserters.map(d => `
                <div class="deserter-card">
                  <div class="deserter-header">
                    <span class="deserter-badge">DESERTER STAIN</span>
                    <span class="days-pill">${d.days_remaining} Days Remaining</span>
                  </div>
                  <div style="font-size:1rem; font-weight:800; color:#fff; margin:4px 0;">
                    <span class="clickable-player" onclick="openCharacterProfile('${escapeHtml(d.player_name)}')">${escapeHtml(d.player_name)}</span>
                  </div>
                  <div style="font-size:0.75rem; color:#cbd5e1;">
                    Former Guild: <strong style="color:#f87171;">&lt;${escapeHtml(d.former_guild)}&gt;</strong>
                  </div>
                  <div style="font-size:0.68rem; color:#64748b; margin-top:6px; font-family:monospace;">
                    GUID: ${escapeHtml(d.player_guid)}
                  </div>
                </div>
              `).join('')}
            </div>
          </div>
        </div>
      </div>
    `;

    container.innerHTML = html;
  } catch (err) {
    container.innerHTML = `<div style="text-align:center; padding:40px; color:#ef4444;">Failed to load Warroom: ${err.message}</div>`;
  }
}

// Backward compatibility alias
function loadFeudsView() {
  loadWarroomView();
}

function generateStreamBoxUrl() {
  const charInput = document.getElementById("sb-input-char");
  if (!charInput || !charInput.value.trim()) {
    alert("Please enter a character name.");
    return;
  }
  const name = charInput.value.trim();
  const url = `${window.location.origin}/war-hud/${encodeURIComponent(name)}`;
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
    alert("War Correspondent HUD URL copied to clipboard!");
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
            <input type="text" id="discord-guild-name" class="search-input" style="width:100%;" placeholder="e.g. Vanguard Brigade or default" value="${discordCfg && discordCfg.guild_name ? discordCfg.guild_name : 'default'}">
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
  const guild = document.getElementById("event-input-guild")?.value.trim() || "Vanguard Brigade";
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
  const activeMobilePill = document.getElementById(`m-pill-${mode.toLowerCase()}`);
  if (activeMobilePill) activeMobilePill.classList.add("active");

  // Sync 4-way mode filter pills in header
  document.querySelectorAll(".header-mode-pill").forEach(b => b.classList.remove("active"));
  const activeHdrPill = document.getElementById(`hdr-pill-${mode.toLowerCase()}`);
  if (activeHdrPill) activeHdrPill.classList.add("active");

  const statModeEl = document.getElementById("stat-active-mode");
  if (statModeEl) {
    const modeNames = { WORLD: "World PvP", BG: "Battlegrounds", ARENA: "Arenas", DUEL: "Duels" };
    statModeEl.innerText = modeNames[mode] || mode;
  }

  loadKills();
  loadSidebar();
  if (currentTab === "FEED" || currentTab === "INTEL") loadMostWanted();
  if (currentTab === "LEADERBOARDS" || currentTab === "LEGENDS") loadLeaderboards();
}

function openPlaceBountyModal() {
  const target = prompt("Enter Target Outlaw Name (Open World PvP only):");
  if (!target) return;
  const gold = prompt("Enter Blood Bounty Gold Amount (e.g. 500):", "500");
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
    alert(`Blood Bounty of ${gold}g declared on ${target}! The execution contract is now active across the realm.`);
    loadBounties();
    loadMostWanted();
  });
}

// Supporter Mode & Subzone Intel Helpers
function isSupporterActive() {
  const val = localStorage.getItem("wowkb_supporter");
  return val !== "0"; // Default to active (1) unless explicitly disabled (0)
}

function toggleSupporterMode() {
  const current = isSupporterActive();
  localStorage.setItem("wowkb_supporter", current ? "0" : "1");
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
    btn.innerText = "Unlock Subzones";
    btn.style.background = "#1e293b";
    btn.style.color = "#94a3b8";
    btn.title = "Click to activate Supporter Mode";
  }
}

function handleSupporterClick() {
  toggleSupporterMode();
  const active = isSupporterActive();
  if (active) {
    alert("Honorary Benefactor Insignia and Community Supporter crests are currently in development as planned community perks.");
  } else {
    alert("Supporter Mode preview disabled.");
  }
}

// ----------------- Feuds & KOS Modals -----------------

function openDeclareFeudModal() {
  const cGuild = prompt("Enter Challenger Guild (or Character Name):");
  if (!cGuild) return;
  const tGuild = prompt("Enter Defender Guild (or Character Name):");
  if (!tGuild) return;
  const targetScore = prompt("Enter Target Score (e.g. 100 kills):", "100");
  if (!targetScore) return;
  const minLvl = prompt("Enter Minimum Level ROE (Anti-Lowbie Filter, e.g. 55):", "55");

  fetch("/api/feuds/challenge", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      feud_type: "GUILD",
      challenger_guild: cGuild.trim(),
      challenger_name: cGuild.trim(),
      target_guild: tGuild.trim(),
      target_name: tGuild.trim(),
      target_score: parseInt(targetScore) || 100,
      roe_min_level: parseInt(minLvl) || 55,
      roe_underdog_bonus: true
    })
  }).then(res => res.json()).then(d => {
    alert(d.message || "Blood Feud challenge declared!");
    loadFeudsView();
  }).catch(e => alert("Error declaring feud: " + e.message));
}

function openBrandKosModal() {
  const target = prompt("Enter Guild or Character Name to brand as KOS:");
  if (!target) return;
  const reason = prompt("Enter Reason for KOS Branding:", "Flagged KOS by Realm War Council");
  if (!reason) return;

  fetch("/api/kos/blacklist", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      entity_name: target.trim(),
      entity_type: "GUILD",
      reason: reason.trim()
    })
  }).then(res => res.json()).then(d => {
    alert(d.message || "Entity consigned to KOS Blacklist!");
    loadFeudsView();
  }).catch(e => alert("Error blacklisting entity: " + e.message));
}

// ----------------- Tactical Intel Recon Wire (In-game only) -----------------

async function checkIntelSightings() {
  // Disabled: Tactical recon wire broadcasts are now dispatched strictly in-game
  return;
}

// Initialization
document.addEventListener("DOMContentLoaded", () => {
  const searchEl = document.getElementById("search-box");
  if (searchEl) {
    searchEl.addEventListener("input", (e) => {
      searchQuery = e.target.value;
      if (currentTab === "FEED") {
        loadKills();
      }
    });
  }

  updateSupporterButton();
  initClientFlavor();
  renderHeaderAuthBadge();
  updateTheaterNavLabel();
  updateNavigationLabels();
  loadSidebar();
  checkGlobalSosBeacons();

  // Handle external character web links (?character=Name or ?char=Name or ?player=Name)
  const urlParams = new URLSearchParams(window.location.search);
  const charParam = urlParams.get("character") || urlParams.get("char") || urlParams.get("player");
  const classParam = urlParams.get("class");
  const levelParam = urlParams.get("level");
  const factionParam = urlParams.get("faction");

  if (charParam) {
    // Seamlessly authenticate operative from game link
    localStorage.setItem("wowkb_account_username", charParam);
    localStorage.setItem("wowkb_user_character", charParam);
    localStorage.setItem("wow_killboard_hunter_name", charParam);
    if (classParam) localStorage.setItem("wowkb_user_class", classParam.toUpperCase());
    if (levelParam) localStorage.setItem("wowkb_user_level", levelParam);
    if (factionParam) localStorage.setItem("wowkb_user_faction", factionParam);
    sessionStorage.setItem("wowkb_auth_type", "character");
    sessionStorage.setItem("wowkb_has_entered_feed", "1");
    portalAccessMode = "character";
    renderHeaderAuthBadge();
    syncActiveCharacterTelemetry(charParam);
    switchTab("INTEL");
    setTimeout(() => {
      openCharacterProfile(charParam);
    }, 250);
  } else {
    // Direct zero-barrier landing on the live combat feed
    sessionStorage.setItem("wowkb_has_entered_feed", "1");
    const activeChar = localStorage.getItem("wowkb_user_character");
    if (activeChar) {
      syncActiveCharacterTelemetry(activeChar);
    }
    switchTab("INTEL");
  }

  // Polling update every 6 seconds
  setInterval(() => {
    if (currentTab === "FEED" || currentTab === "INTEL") {
      loadKills();
      loadMostWanted();
    }
    loadSidebar();
    checkGlobalSosBeacons();
  }, 6000);
});

