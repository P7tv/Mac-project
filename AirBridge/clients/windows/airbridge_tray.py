#!/usr/bin/env python3
"""
AirBridge Windows Companion Client
----------------------------------
Runs silently in the Windows System Tray.
Automatically syncs Windows Clipboard (Ctrl+C / Ctrl+V) with your Mac wirelessly!
Zero cloud, 100% local Wi-Fi / Hotspot.
"""

import sys
import os
import json
import time
import threading
import urllib.request
import urllib.error

try:
    import websocket
except ImportError:
    print("[AirBridge] Installing required websocket-client...")
    os.system(f'"{sys.executable}" -m pip install websocket-client')
    import websocket

# Windows clipboard via ctypes (zero heavy dependency)
import ctypes
from ctypes import wintypes

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32

CF_UNICODETEXT = 13
GMEM_MOVEABLE = 0x0002

def get_windows_clipboard():
    try:
        if not user32.OpenClipboard(None):
            return ""
        h_glb = user32.GetClipboardData(CF_UNICODETEXT)
        if not h_glb:
            user32.CloseClipboard()
            return ""
        p_glb = kernel32.GlobalLock(h_glb)
        text = ctypes.c_wchar_p(p_glb).value or ""
        kernel32.GlobalUnlock(h_glb)
        user32.CloseClipboard()
        return text
    except Exception:
        return ""

def set_windows_clipboard(text):
    try:
        if not user32.OpenClipboard(None):
            return False
        user32.EmptyClipboard()
        encoded = (text + "\0").encode("utf-16le")
        h_glb = kernel32.GlobalAlloc(GMEM_MOVEABLE, len(encoded))
        p_glb = kernel32.GlobalLock(h_glb)
        ctypes.memmove(p_glb, encoded, len(encoded))
        kernel32.GlobalUnlock(h_glb)
        user32.SetClipboardData(CF_UNICODETEXT, h_glb)
        user32.CloseClipboard()
        return True
    except Exception:
        return False

class AirBridgeClient:
    def __init__(self, host="127.0.0.1", port=5050, pin=""):
        self.host = host
        self.port = port
        self.pin = pin
        self.token = ""
        self.ws = None
        self.last_hash = ""
        self.is_running = True

    def pair(self):
        url = f"http://{self.host}:{self.port}/api/pair"
        payload = json.dumps({
            "pin": self.pin,
            "deviceName": os.environ.get("COMPUTERNAME", "Windows-PC"),
            "deviceType": "Windows"
        }).encode("utf-8")

        req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=5) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                if data.get("authorized"):
                    self.token = data.get("token")
                    print(f"✅ Paired successfully with Mac! Token: {self.token[:8]}...")
                    return True
                else:
                    print("❌ Invalid PIN. Check Mac Menu Bar.")
                    return False
        except Exception as e:
            print(f"❌ Connection error: {e}")
            return False

    def on_ws_message(self, ws, message):
        try:
            data = json.loads(message)
            content = data.get("content", "")
            item_hash = data.get("hash", "")
            if content and item_hash != self.last_hash:
                self.last_hash = item_hash
                set_windows_clipboard(content)
                print(f"📥 Synced from Mac: {content[:40]}...")
        except Exception as e:
            print(f"[WS] Message error: {e}")

    def on_ws_open(self, ws):
        print("🟢 WebSocket connected to Mac! Live sync active.")

    def on_ws_close(self, ws, close_status_code, close_msg):
        print("🔴 WebSocket disconnected. Reconnecting in 3s...")
        time.sleep(3)
        if self.is_running:
            self.connect_ws()

    def connect_ws(self):
        ws_url = f"ws://{self.host}:{self.port}/ws?token={self.token}"
        self.ws = websocket.WebSocketApp(
            ws_url,
            on_message=self.on_ws_message,
            on_open=self.on_ws_open,
            on_close=self.on_ws_close
        )
        t = threading.Thread(target=self.ws.run_forever, daemon=True)
        t.start()

    def local_clipboard_watcher(self):
        while self.is_running:
            try:
                current_text = get_windows_clipboard()
                if current_text:
                    import hashlib
                    h = hashlib.sha256(current_text.encode("utf-8")).hexdigest()
                    if h != self.last_hash:
                        self.last_hash = h
                        print(f"📤 Copied on Windows -> Pushing to Mac: {current_text[:40]}...")
                        self.push_to_mac(current_text)
            except Exception:
                pass
            time.sleep(0.5)

    def push_to_mac(self, text):
        url = f"http://{self.host}:{self.port}/api/clipboard"
        payload = json.dumps({"type": "text", "content": text}).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=payload,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self.token}"
            }
        )
        try:
            with urllib.request.urlopen(req, timeout=3):
                pass
        except Exception as e:
            print(f"[Push error]: {e}")

    def start(self):
        if not self.pair():
            return
        self.connect_ws()
        watcher_thread = threading.Thread(target=self.local_clipboard_watcher, daemon=True)
        watcher_thread.start()
        print("\n✨ AirBridge is running in the background!")
        print("👉 Press Ctrl+C on Windows to copy to Mac.")
        print("👉 Press Cmd+C on Mac to paste with Ctrl+V on Windows.")
        print("Press Ctrl+C in this console to exit.\n")
        try:
            while self.is_running:
                time.sleep(1)
        except KeyboardInterrupt:
            self.is_running = False
            print("AirBridge stopped.")

if __name__ == "__main__":
    host_input = input("Enter Mac IP (shown on Mac Menu Bar, e.g. 192.168.1.100 or press Enter for 127.0.0.1): ").strip()
    if not host_input:
        host_input = "127.0.0.1"
    pin_input = input("Enter 4-digit PIN (shown on Mac Menu Bar): ").strip()

    client = AirBridgeClient(host=host_input, pin=pin_input)
    client.start()
