#!/usr/bin/env python3
"""
WoWKillboard - sync/gui.py
Native Desktop Companion GUI (Warcraft Logs / Raider.IO style).
Provides a modern dark-themed tactical desktop dashboard for WoWKillboardSync,
with automated multi-drive detection, 1-click Windows startup, and smart self-installation.
"""

import os
import sys
import time
import queue
import threading
import webbrowser
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

# UI Color Palette (Warcraft Tactical Dark Theme)
BG_MAIN = "#0a0e17"       # Deep dark navy slate
BG_CARD = "#121a29"       # Card panel background
BG_CARD_INNER = "#0c121e" # Inner nested panels
BG_CONSOLE = "#06090f"    # Deep black-navy for log feed
BORDER_COLOR = "#1e2c44"  # Subtle slate border
BORDER_ACCENT = "#d4a329" # WoW Gold accent
TEXT_MAIN = "#f1f5f9"     # High-contrast white/slate
TEXT_MUTED = "#94a3b8"    # Subtle grey
TEXT_GOLD = "#ffd100"     # In-game gold text
TEXT_GREEN = "#10b981"    # Status emerald green
TEXT_RED = "#ef4444"      # PvP Crimson
TEXT_CYAN = "#38bdf8"     # Information blue
BTN_BG = "#1e293b"        # Button background
BTN_HOVER = "#334155"     # Button hover background

def _get_watcher_mod():
    """Resolves the watcher module regardless of whether executed as package, standalone script, or PyInstaller frozen bundle."""
    try:
        import sync.watcher as w
        return w
    except ImportError:
        pass
    try:
        import watcher as w
        return w
    except ImportError:
        pass
    import __main__ as w
    return w

class DesktopCompanionApp:
    def __init__(self, root, watcher_instance, target_files, target_apis, on_sync_request=None, on_folder_change=None):
        self.root = root
        self.watcher = watcher_instance
        self.target_files = target_files
        self.target_apis = target_apis
        self.on_sync_request = on_sync_request
        self.on_folder_change = on_folder_change

        self.log_queue = queue.Queue()
        self.kills_synced_count = 0
        self.last_sync_time = "Never"

        self.root.title("WoW Killboard — Desktop Companion")
        self.root.geometry("740x590")
        self.root.minsize(680, 520)
        self.root.configure(bg=BG_MAIN)

        self._setup_styles()
        self._build_ui()
        self._poll_log_queue()

    def _setup_styles(self):
        style = ttk.Style()
        try:
            style.theme_use("clam")
        except Exception:
            pass

        style.configure("TFrame", background=BG_MAIN)
        style.configure("Card.TFrame", background=BG_CARD)
        style.configure("CardInner.TFrame", background=BG_CARD_INNER)
        style.configure("TLabel", background=BG_MAIN, foreground=TEXT_MAIN, font=("Segoe UI", 9))
        style.configure("Muted.TLabel", background=BG_MAIN, foreground=TEXT_MUTED, font=("Segoe UI", 8))
        style.configure("Header.TLabel", background=BG_MAIN, foreground=TEXT_GOLD, font=("Segoe UI", 12, "bold"))
        style.configure("SubHeader.TLabel", background=BG_MAIN, foreground=TEXT_MUTED, font=("Segoe UI", 8))

    def _build_ui(self):
        # 1. Top Header Banner
        header_frame = tk.Frame(self.root, bg=BG_CARD, highlightthickness=1, highlightbackground=BORDER_COLOR, padx=16, pady=12)
        header_frame.pack(fill=tk.X, padx=12, pady=(12, 8))

        # Brand Title & Subtitle (Left)
        title_box = tk.Frame(header_frame, bg=BG_CARD)
        title_box.pack(side=tk.LEFT)

        brand_lbl = tk.Label(title_box, text="⚔️ WoW KILLBOARD", font=("Segoe UI", 13, "bold"), fg=TEXT_GOLD, bg=BG_CARD)
        brand_lbl.pack(anchor="w")

        sub_text = "Universal Combat Telemetry Companion & Real-Time Sync Agent"
        sub_lbl = tk.Label(title_box, text=sub_text, font=("Segoe UI", 8), fg=TEXT_MUTED, bg=BG_CARD)
        sub_lbl.pack(anchor="w")

        # Live Status Pill (Right)
        pill_box = tk.Frame(header_frame, bg=BG_CARD)
        pill_box.pack(side=tk.RIGHT)

        self.status_pill = tk.Label(
            pill_box,
            text="● LIVE & MONITORING",
            font=("Segoe UI", 8, "bold"),
            fg=TEXT_GREEN,
            bg="#062419",
            highlightthickness=1,
            highlightbackground="#059669",
            padx=10,
            pady=4
        )
        self.status_pill.pack(anchor="e", pady=(0, 2))

        api_url = self.target_apis[0] if self.target_apis else "https://wowkillboard.com"
        api_lbl = tk.Label(pill_box, text=f"Target: {api_url}", font=("Segoe UI", 7), fg=TEXT_MUTED, bg=BG_CARD)
        api_lbl.pack(anchor="e")

        # 2. Check if running from Downloads / Temp -> show integrated install banner
        _w = _get_watcher_mod()
        install_dir = _w.get_install_dir() if hasattr(_w, "get_install_dir") else ""
        curr_exe = os.path.abspath(sys.argv[0])
        curr_dir = os.path.dirname(curr_exe)

        if curr_dir.lower() != install_dir.lower() and ("downloads" in curr_dir.lower() or "temp" in curr_dir.lower()):
            self.install_banner = tk.Frame(self.root, bg="#1e1b4b", highlightthickness=1, highlightbackground="#6366f1", padx=14, pady=7)
            self.install_banner.pack(fill=tk.X, padx=12, pady=(0, 8))

            banner_text = tk.Label(
                self.install_banner,
                text="🚀 Running from Downloads — Click to install to PC and create a clean Desktop shortcut:",
                font=("Segoe UI", 8),
                fg="#e0e7ff",
                bg="#1e1b4b"
            )
            banner_text.pack(side=tk.LEFT)

            def on_banner_install():
                target = _w.install_application_to_pc(curr_exe)
                self.append_log(f"[Installer] Installed application to: {target}", tag="sync")
                self.append_log("[Installer] Desktop shortcut created: Desktop\\WoW Killboard.lnk", tag="sync")
                self.install_banner.destroy()
                messagebox.showinfo("Installation Complete", "WoW Killboard Desktop Companion installed!\nA shortcut icon was created on your Desktop.")

            banner_btn = tk.Button(
                self.install_banner,
                text="🚀 Install to PC",
                font=("Segoe UI", 8, "bold"),
                fg="#1e1b4b",
                bg="#a5b4fc",
                activebackground="#c7d2fe",
                relief=tk.FLAT,
                padx=10,
                pady=2,
                cursor="hand2",
                command=on_banner_install
            )
            banner_btn.pack(side=tk.RIGHT)

        # 3. WoW Installation & Detection Card
        install_card = tk.Frame(self.root, bg=BG_CARD, highlightthickness=1, highlightbackground=BORDER_COLOR, padx=14, pady=10)
        install_card.pack(fill=tk.X, padx=12, pady=(0, 8))

        top_inst_row = tk.Frame(install_card, bg=BG_CARD)
        top_inst_row.pack(fill=tk.X)

        inst_title = tk.Label(top_inst_row, text="WORLD OF WARCRAFT INSTALLATIONS", font=("Segoe UI", 8, "bold"), fg=TEXT_GOLD, bg=BG_CARD)
        inst_title.pack(side=tk.LEFT)

        change_folder_btn = tk.Button(
            top_inst_row,
            text="📁 Select / Change Folder...",
            font=("Segoe UI", 8),
            fg=TEXT_MAIN,
            bg=BTN_BG,
            activebackground=BTN_HOVER,
            activeforeground=TEXT_MAIN,
            relief=tk.FLAT,
            padx=8,
            pady=2,
            cursor="hand2",
            command=self._on_choose_folder
        )
        change_folder_btn.pack(side=tk.RIGHT)

        # Discovered paths display
        self.install_path_lbl = tk.Label(
            install_card,
            text=self._get_discovered_path_summary(),
            font=("Segoe UI", 8),
            fg="#cbd5e1",
            bg=BG_CARD,
            anchor="w",
            justify=tk.LEFT
        )
        self.install_path_lbl.pack(fill=tk.X, pady=(4, 6))

        # Flavor Badges Row
        self.badges_frame = tk.Frame(install_card, bg=BG_CARD)
        self.badges_frame.pack(fill=tk.X)
        self._refresh_flavor_badges()

        # 4. Live Telemetry & Log Activity Stream
        log_card = tk.Frame(self.root, bg=BG_CARD, highlightthickness=1, highlightbackground=BORDER_COLOR, padx=12, pady=10)
        log_card.pack(fill=tk.BOTH, expand=True, padx=12, pady=(0, 8))

        log_header = tk.Frame(log_card, bg=BG_CARD)
        log_header.pack(fill=tk.X, pady=(0, 6))

        log_title = tk.Label(log_header, text="REAL-TIME COMBAT TELEMETRY & SYNC STREAM", font=("Segoe UI", 8, "bold"), fg=TEXT_GOLD, bg=BG_CARD)
        log_title.pack(side=tk.LEFT)

        self.metrics_lbl = tk.Label(
            log_header,
            text="Kills Synced: 0  |  Accounts: 0  |  Last Sync: Never",
            font=("Segoe UI", 8),
            fg=TEXT_MUTED,
            bg=BG_CARD
        )
        self.metrics_lbl.pack(side=tk.RIGHT)

        # Log Text Box with Custom Scrollbar
        log_container = tk.Frame(log_card, bg=BG_CONSOLE)
        log_container.pack(fill=tk.BOTH, expand=True)

        scrollbar = tk.Scrollbar(log_container)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        self.log_text = tk.Text(
            log_container,
            bg=BG_CONSOLE,
            fg="#cbd5e1",
            insertbackground=TEXT_GOLD,
            font=("Consolas", 9),
            wrap=tk.WORD,
            yscrollcommand=scrollbar.set,
            relief=tk.FLAT,
            padx=8,
            pady=8
        )
        self.log_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.config(command=self.log_text.yview)

        # Define syntax tags for log highlights
        self.log_text.tag_config("time", foreground="#64748b")
        self.log_text.tag_config("kill", foreground="#f87171", font=("Consolas", 9, "bold"))
        self.log_text.tag_config("sync", foreground="#34d399", font=("Consolas", 9, "bold"))
        self.log_text.tag_config("gold", foreground="#fbbf24")
        self.log_text.tag_config("blue", foreground="#60a5fa")
        self.log_text.tag_config("muted", foreground="#94a3b8")

        # 5. Bottom Controls & Action Bar
        bottom_bar = tk.Frame(self.root, bg=BG_MAIN, padx=4, pady=4)
        bottom_bar.pack(fill=tk.X, padx=12, pady=(0, 10))

        # Left: Windows Auto-Start Checkbox
        self.startup_var = tk.BooleanVar(value=_w.is_windows_startup_enabled() if hasattr(_w, "is_windows_startup_enabled") else False)

        startup_check = tk.Checkbutton(
            bottom_bar,
            text="Launch automatically with Windows (Startup)",
            variable=self.startup_var,
            font=("Segoe UI", 8),
            fg=TEXT_MAIN,
            bg=BG_MAIN,
            activebackground=BG_MAIN,
            activeforeground=TEXT_GOLD,
            selectcolor=BG_CARD,
            command=self._on_toggle_startup
        )
        startup_check.pack(side=tk.LEFT)

        # Right: Action Buttons
        btn_box = tk.Frame(bottom_bar, bg=BG_MAIN)
        btn_box.pack(side=tk.RIGHT)

        shortcut_btn = tk.Button(
            btn_box,
            text="📌 Desktop Icon",
            font=("Segoe UI", 8),
            fg=TEXT_MAIN,
            bg=BTN_BG,
            activebackground=BTN_HOVER,
            activeforeground=TEXT_MAIN,
            relief=tk.FLAT,
            padx=10,
            pady=4,
            cursor="hand2",
            command=self._on_create_shortcut
        )
        shortcut_btn.pack(side=tk.LEFT, padx=(0, 6))

        sync_btn = tk.Button(
            btn_box,
            text="⚡ Sync Now",
            font=("Segoe UI", 8, "bold"),
            fg="#047857",
            bg="#d1fae5",
            activebackground="#a7f3d0",
            activeforeground="#047857",
            relief=tk.FLAT,
            padx=12,
            pady=4,
            cursor="hand2",
            command=self._on_manual_sync
        )
        sync_btn.pack(side=tk.LEFT, padx=(0, 6))

        web_btn = tk.Button(
            btn_box,
            text="🌐 Open Web Killboard",
            font=("Segoe UI", 8, "bold"),
            fg="#78350f",
            bg="#fef3c7",
            activebackground="#fde68a",
            activeforeground="#78350f",
            relief=tk.FLAT,
            padx=12,
            pady=4,
            cursor="hand2",
            command=self._on_open_web
        )
        web_btn.pack(side=tk.LEFT)

    def _get_discovered_path_summary(self) -> str:
        _w = _get_watcher_mod()
        roots = _w.find_all_wow_roots() if hasattr(_w, "find_all_wow_roots") else []
        if roots:
            return f"Root Directory: {roots[0]}  ({len(self.target_files)} active account files monitored)"
        return "No World of Warcraft directory detected automatically. Click 'Select Folder' to configure."

    def _refresh_flavor_badges(self):
        for widget in self.badges_frame.winfo_children():
            widget.destroy()

        flavors = [
            ("Forever Beta", "_classic_beta_"),
            ("Classic Era", "_classic_era_"),
            ("Anniversary", "_anniversary_"),
            ("Modern Retail", "_retail_")
        ]

        _w = _get_watcher_mod()
        roots = _w.find_all_wow_roots() if hasattr(_w, "find_all_wow_roots") else []

        for name, folder in flavors:
            detected = False
            for root in roots:
                if os.path.exists(os.path.join(root, folder)):
                    detected = True
                    break

            if detected:
                badge = tk.Label(
                    self.badges_frame,
                    text=f"✓ {name}",
                    font=("Segoe UI", 7, "bold"),
                    fg="#10b981",
                    bg="#062419",
                    highlightthickness=1,
                    highlightbackground="#059669",
                    padx=6,
                    pady=2
                )
            else:
                badge = tk.Label(
                    self.badges_frame,
                    text=f"○ {name}",
                    font=("Segoe UI", 7),
                    fg="#64748b",
                    bg="#1e293b",
                    highlightthickness=1,
                    highlightbackground="#334155",
                    padx=6,
                    pady=2
                )
            badge.pack(side=tk.LEFT, padx=(0, 6))

    def _on_choose_folder(self):
        chosen = filedialog.askdirectory(title="Select your World of Warcraft Directory")
        if chosen and os.path.exists(chosen):
            _w = _get_watcher_mod()
            norm = _w.normalize_wow_root(chosen)
            _w.save_config({"wow_path": norm})
            self.target_files = _w.find_all_saved_variables()
            if self.watcher:
                self.watcher.filepaths = self.target_files
            self.install_path_lbl.config(text=self._get_discovered_path_summary())
            self._refresh_flavor_badges()
            self.append_log(f"[Config] Saved custom World of Warcraft directory: {norm}", tag="gold")
            if self.on_folder_change:
                self.on_folder_change(norm)

    def _on_toggle_startup(self):
        _w = _get_watcher_mod()
        enable = self.startup_var.get()
        success = _w.set_windows_startup(enable) if hasattr(_w, "set_windows_startup") else False
        if success:
            msg = "[Startup] Windows Auto-Start ENABLED. WoW Killboard will start with Windows." if enable else "[Startup] Windows Auto-Start DISABLED."
            self.append_log(msg, tag="sync" if enable else "muted")
        else:
            self.append_log("[Startup] Failed to configure Windows Auto-Start.", tag="kill")

    def _on_create_shortcut(self):
        _w = _get_watcher_mod()
        desktop = os.path.join(os.environ.get("USERPROFILE", ""), "Desktop")
        target_installed = os.path.join(_w.get_install_dir(), "WoWKillboardSync.exe") if hasattr(_w, "get_install_dir") else ""
        exe_to_link = target_installed if os.path.exists(target_installed) else os.path.abspath(sys.argv[0])
        shortcut_path = os.path.join(desktop, "WoW Killboard.lnk")
        if hasattr(_w, "create_windows_shortcut"):
            ok = _w.create_windows_shortcut(exe_to_link, shortcut_path)
            if ok:
                self.append_log(f"[Shortcut] Desktop shortcut created: {shortcut_path}", tag="sync")
                messagebox.showinfo("Desktop Shortcut", "WoW Killboard shortcut icon has been created on your Desktop!")
            else:
                self.append_log("[Shortcut] Could not create Desktop shortcut.", tag="kill")
        else:
            self.append_log("[Shortcut] Shortcut creation unsupported on this platform.", tag="muted")

    def _on_manual_sync(self):
        self.append_log("[Sync] Manual sync triggered by user...", tag="blue")
        if self.on_sync_request:
            threading.Thread(target=self.on_sync_request, daemon=True).start()

    def _on_open_web(self):
        url = self.target_apis[0] if self.target_apis else "https://wowkillboard.com"
        webbrowser.open(url)

    def show_install_dialog(self, curr_exe: str):
        """Displays the setup modal smoothly once mainloop is running."""
        _w = _get_watcher_mod()
        cfg = _w.load_config() if hasattr(_w, "load_config") else {}
        if cfg.get("run_portable", False):
            return

        setup_win = tk.Toplevel(self.root)
        setup_win.title("WoW Killboard — Setup & Installation")
        setup_win.geometry("540x360")
        setup_win.resizable(False, False)
        setup_win.configure(bg=BG_MAIN)
        setup_win.transient(self.root)

        # Center over main window
        self.root.update_idletasks()
        rx = self.root.winfo_x()
        ry = self.root.winfo_y()
        rw = self.root.winfo_width()
        rh = self.root.winfo_height()
        x = max(0, rx + (rw - 540) // 2)
        y = max(0, ry + (rh - 360) // 2)
        setup_win.geometry(f"540x360+{x}+{y}")

        header = tk.Frame(setup_win, bg=BG_CARD, padx=16, pady=12, highlightthickness=1, highlightbackground=BORDER_COLOR)
        header.pack(fill=tk.X, padx=14, pady=(14, 10))

        brand = tk.Label(header, text="⚔️ WoW KILLBOARD COMPANION SETUP", font=("Segoe UI", 12, "bold"), fg=TEXT_GOLD, bg=BG_CARD)
        brand.pack(anchor="w")

        sub = tk.Label(header, text="Clean Windows Desktop Installation", font=("Segoe UI", 8), fg=TEXT_MUTED, bg=BG_CARD)
        sub.pack(anchor="w")

        body_card = tk.Frame(setup_win, bg=BG_CARD, padx=16, pady=14, highlightthickness=1, highlightbackground=BORDER_COLOR)
        body_card.pack(fill=tk.BOTH, expand=True, padx=14, pady=(0, 10))

        q_lbl = tk.Label(body_card, text="Install WoW Killboard Desktop Companion to your PC?", font=("Segoe UI", 10, "bold"), fg=TEXT_MAIN, bg=BG_CARD, wraplength=480, justify=tk.LEFT)
        q_lbl.pack(anchor="w", pady=(0, 8))

        points = [
            "• Installs cleanly into your Windows Apps folder (AppData/Programs)",
            "• Creates a Desktop shortcut icon (WoW Killboard)",
            "• Adds an entry to your Windows Start Menu",
            "• Keeps your Downloads folder clean and free of logs"
        ]
        for pt in points:
            p_lbl = tk.Label(body_card, text=pt, font=("Segoe UI", 8), fg="#cbd5e1", bg=BG_CARD)
            p_lbl.pack(anchor="w", pady=2)

        remember_var = tk.BooleanVar(value=False)
        rem_check = tk.Checkbutton(
            body_card,
            text="Remember my choice (don't ask again)",
            variable=remember_var,
            font=("Segoe UI", 8),
            fg=TEXT_MUTED,
            bg=BG_CARD,
            activebackground=BG_CARD,
            activeforeground=TEXT_GOLD,
            selectcolor=BG_MAIN
        )
        rem_check.pack(anchor="w", pady=(8, 0))

        btn_row = tk.Frame(setup_win, bg=BG_MAIN, padx=14, pady=(0, 14))
        btn_row.pack(fill=tk.X)

        def do_install():
            target = _w.install_application_to_pc(curr_exe)
            setup_win.destroy()
            if hasattr(os, "startfile"):
                os.startfile(target)
            else:
                import subprocess
                subprocess.Popen([target])
            self.root.destroy()
            sys.exit(0)

        def do_portable():
            if remember_var.get() and hasattr(_w, "save_config"):
                _w.save_config({"run_portable": True})
            setup_win.destroy()

        inst_btn = tk.Button(
            btn_row,
            text="🚀 Install & Launch (Recommended)",
            font=("Segoe UI", 9, "bold"),
            fg="#047857",
            bg="#d1fae5",
            activebackground="#a7f3d0",
            activeforeground="#047857",
            relief=tk.FLAT,
            padx=14,
            pady=6,
            cursor="hand2",
            command=do_install
        )
        inst_btn.pack(side=tk.LEFT)

        port_btn = tk.Button(
            btn_row,
            text="⚡ Run Portably",
            font=("Segoe UI", 9),
            fg=TEXT_MUTED,
            bg=BTN_BG,
            activebackground=BTN_HOVER,
            activeforeground=TEXT_MAIN,
            relief=tk.FLAT,
            padx=12,
            pady=6,
            cursor="hand2",
            command=do_portable
        )
        port_btn.pack(side=tk.RIGHT)

    def append_log(self, msg: str, tag: str = None):
        self.log_queue.put((msg, tag))

    def _poll_log_queue(self):
        try:
            while True:
                msg, tag = self.log_queue.get_nowait()
                self._insert_formatted_log(msg, tag)
                self.log_queue.task_done()
        except queue.Empty:
            pass
        self.root.after(100, self._poll_log_queue)

    def _insert_formatted_log(self, line: str, forced_tag: str = None):
        self.log_text.config(state=tk.NORMAL)
        ts_str = time.strftime("%H:%M:%S")

        # Update metrics if kill or sync is reported
        if "Synced:" in line or "1 new kills" in line:
            self.last_sync_time = ts_str
            if "new kills" in line:
                import re
                m = re.search(r"(\d+)\s+new kills", line)
                if m:
                    self.kills_synced_count += int(m.group(1))
            self._update_metrics_bar()

        tag = forced_tag
        if not tag:
            if "2-WAY SYNC" in line or "Manual Sync" in line or "Synced:" in line:
                tag = "sync"
            elif "kill" in line.lower() or "casualt" in line.lower():
                tag = "kill"
            elif "discovered" in line.lower() or "monitoring" in line.lower():
                tag = "gold"
            elif "error" in line.lower() or "failed" in line.lower():
                tag = "kill"
            else:
                tag = "muted"

        self.log_text.insert(tk.END, f"[{ts_str}] ", "time")
        self.log_text.insert(tk.END, f"{line}\n", tag)
        self.log_text.see(tk.END)
        self.log_text.config(state=tk.DISABLED)

    def _update_metrics_bar(self):
        acc_count = len(self.target_files) if self.target_files else 0
        text = f"Kills Synced: {self.kills_synced_count}  |  Accounts: {acc_count}  |  Last Sync: {self.last_sync_time}"
        self.metrics_lbl.config(text=text)

def launch_gui(watcher_instance, target_files, target_apis):
    """Launches the Tkinter Desktop Companion application."""
    root = tk.Tk()
    
    def handle_sync():
        if watcher_instance:
            for p in list(watcher_instance.filepaths):
                watcher_instance.process_file(p)
            watcher_instance.sync_realm_data_to_client()

    app = DesktopCompanionApp(
        root=root,
        watcher_instance=watcher_instance,
        target_files=target_files,
        target_apis=target_apis,
        on_sync_request=handle_sync
    )

    # Register log hook with watcher
    _w = _get_watcher_mod()
    def on_watcher_log(formatted_msg):
        # Strip out initial timestamp if present
        if formatted_msg.startswith("[") and "]" in formatted_msg:
            idx = formatted_msg.find("]")
            clean_msg = formatted_msg[idx+1:].strip()
        else:
            clean_msg = formatted_msg
        app.append_log(clean_msg)

    if hasattr(_w, "register_log_hook"):
        _w.register_log_hook(on_watcher_log)

    # Initial greeting log
    app.append_log(f"WoW Killboard Desktop Companion v{getattr(watcher_instance, 'version', '1.0.3')} initialized.", tag="gold")
    app.append_log(f"Connected to Ingestion API: {target_apis[0] if target_apis else 'https://wowkillboard.com'}", tag="sync")
    app.append_log(f"Actively monitoring {len(target_files)} WoW client accounts.", tag="blue")
    app.append_log("ℹ️ Note: WoW writes combat data to disk on /reload or character logout.", tag="muted")

    # Start watcher background daemon thread
    if watcher_instance:
        def daemon_worker():
            try:
                watcher_instance.run_daemon(poll_interval=2.0)
            except Exception as e:
                app.append_log(f"Watcher daemon error: {e}", tag="kill")

        t = threading.Thread(target=daemon_worker, daemon=True)
        t.start()

    # Trigger install prompt dialog smoothly after mainloop starts
    curr_exe = os.path.abspath(sys.argv[0])
    curr_dir = os.path.dirname(curr_exe)
    install_dir = _w.get_install_dir() if hasattr(_w, "get_install_dir") else ""
    cfg = _w.load_config() if hasattr(_w, "load_config") else {}

    if (curr_dir.lower() != install_dir.lower() and 
        not cfg.get("run_portable", False) and 
        ("downloads" in curr_dir.lower() or "temp" in curr_dir.lower())):
        root.after(300, lambda: app.show_install_dialog(curr_exe))

    def on_closing():
        if watcher_instance:
            watcher_instance.running = False
        root.destroy()

    root.protocol("WM_DELETE_WINDOW", on_closing)
    root.mainloop()
