import os
import sys
import glob

# Add root directory to sys.path
sys.path.insert(0, os.path.abspath("."))
from sync.watcher import KillboardWatcher, auto_detect_saved_variables

saved_vars = auto_detect_saved_variables()
print(f"Pushing all SavedVariables from: {saved_vars} directly to Render Cloud...")

watcher = KillboardWatcher(saved_vars, api_urls=["https://wow-killboard.onrender.com"])
watcher.process_file()
print("[DONE] Historical SavedVariables push complete.")
