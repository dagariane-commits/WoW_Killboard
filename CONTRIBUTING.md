# Contributing to WoW Killboard

Thank you for your interest in contributing to **WoW Killboard**! This document provides guidelines for contributing code, documentation, and bug reports to ensure the addon remains 100% taint-free, high-performance, and compatible across all World of Warcraft client environments.

---

## 1. Guiding Principles & Engineering Standards

### Zero-Taint Invariant (Non-Negotiable)
- **No Blizzard XML Templates**: Never inherit from `BasicFrameTemplateWithInset`, `UIPanelButtonTemplate`, `UIPanelCloseButton`, or similar XML templates. All frames must be created using anonymous pure Lua widgets and `"BackdropTemplate"`.
- **No `UISpecialFrames`**: Custom frames must never be inserted into `UISpecialFrames`. Use custom key listeners on the parent frame (`SetPropagateKeyboardInput`) to handle `ESCAPE`.
- **Combat Lockdown Gating**: Any function modifying frame sizes, anchors, or mouse interaction must check `if InCombatLockdown() then return end`.

### Dependency Minimization
- **No Heavy External Libraries**: Do not introduce Ace3, LibSharedMedia, or large library suites unless explicitly approved. Keep the addon lightweight, auditable, and blazing fast.

### Cross-Client Parity
- Code must function seamlessly across:
  - **WoW Forever / Classic Beta** (`_classic_beta_` / `WowB.exe`)
  - **Classic Era** (`_classic_era_`)
  - **Anniversary** (`_anniversary_`)
  - **Retail** (`_retail_`)
- Always gate client-specific API calls behind feature detection rather than fragile version string parsing.

---

## 2. Development & Testing Workflow

### Repository Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/ForgedByValor/WoW_Killboard.git
   cd WoW_Killboard
   ```
2. Set up Python virtual environment (for tests and desktop sync):
   ```bash
   python -m venv venv
   source venv/bin/activate  # Or venv\Scripts\activate on Windows
   pip install -r requirements.txt
   ```

### Running Automated Verification
Before submitting any pull request, you **must** pass all local verification tests:

1. **Lua Syntax & Bracket Validation**:
   ```powershell
   python tests/validate_lua.py
   ```
   *All 10 Lua files must return `[PASS]`.*

2. **Pipeline, Parser & API Unit Tests**:
   ```powershell
   python -m unittest discover tests
   ```
   *All end-to-end tests must pass.*

---

## 3. Pull Request Protocol

1. **Create a Feature Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. **Commit Changes**:
   - Write clear, concise commit messages adhering to Conventional Commits:
     - `feat: add duel win percentage tracking`
     - `fix: resolve number-with-string comparison on bg score update`
     - `docs: update architecture specification`
3. **Update Documentation**:
   - If your change alters UI behavior, data models, or API endpoints, update [`CHANGELOG.md`](CHANGELOG.md) under the `[Unreleased]` section.
4. **Submit Pull Request**:
   - Provide a BLUF (Bottom Line Up Front) summary of what changed.
   - Attach in-game screenshots showing that the UI renders without overlap or Lua errors.
   - Confirm that `python tests/validate_lua.py` passed with zero errors.

---

## 4. Reporting Issues & Security Vulnerabilities

- **Bug Reports**: Open an issue detailing your client flavor (`Classic Era`, `Forever Beta`, `Retail`), the exact Lua error stack trace, and reproduction steps.
- **Security Vulnerabilities**: For potential exploits regarding gold transactions or anti-win-trade heuristics, please email `security@forgedbyvalor.com` directly rather than filing public issues.
