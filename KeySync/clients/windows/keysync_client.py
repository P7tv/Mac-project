#!/usr/bin/env python3
"""
KeySync Windows Companion Receiver
-----------------------------------
Receives smooth mouse movements and keystrokes from your Mac over local Wi-Fi.
Uses Windows SendInput for sub-millisecond, zero-lag input injection.
"""

import sys
import socket
import json
import ctypes
from ctypes import wintypes

# Windows Input Structure Setup
user32 = ctypes.windll.user32

INPUT_MOUSE = 0
INPUT_KEYBOARD = 1

MOUSEEVENTF_MOVE = 0x0001
MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004
MOUSEEVENTF_RIGHTDOWN = 0x0008
MOUSEEVENTF_RIGHTUP = 0x0010
MOUSEEVENTF_WHEEL = 0x0800

class MOUSEINPUT(ctypes.Structure):
    _fields_ = [
        ("dx", wintypes.LONG),
        ("dy", wintypes.LONG),
        ("mouseData", wintypes.DWORD),
        ("dwFlags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ctypes.POINTER(wintypes.ULONG))
    ]

class KEYBDINPUT(ctypes.Structure):
    _fields_ = [
        ("wVk", wintypes.WORD),
        ("wScan", wintypes.WORD),
        ("dwFlags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ctypes.POINTER(wintypes.ULONG))
    ]

class HARDWAREINPUT(ctypes.Structure):
    _fields_ = [
        ("uMsg", wintypes.DWORD),
        ("wParamL", wintypes.WORD),
        ("wParamH", wintypes.WORD)
    ]

class DUMMYUNIONNAME(ctypes.Union):
    _fields_ = [
        ("mi", MOUSEINPUT),
        ("ki", KEYBDINPUT),
        ("hi", HARDWAREINPUT)
    ]

class INPUT(ctypes.Structure):
    _fields_ = [
        ("type", wintypes.DWORD),
        ("u", DUMMYUNIONNAME)
    ]

def send_mouse_move(dx, dy):
    inp = INPUT()
    inp.type = INPUT_MOUSE
    inp.u.mi.dx = int(dx)
    inp.u.mi.dy = int(dy)
    inp.u.mi.dwFlags = MOUSEEVENTF_MOVE
    user32.SendInput(1, ctypes.byref(inp), ctypes.sizeof(INPUT))

def send_mouse_click(button, is_down):
    inp = INPUT()
    inp.type = INPUT_MOUSE
    if button == 1:
        inp.u.mi.dwFlags = MOUSEEVENTF_LEFTDOWN if is_down else MOUSEEVENTF_LEFTUP
    elif button == 2:
        inp.u.mi.dwFlags = MOUSEEVENTF_RIGHTDOWN if is_down else MOUSEEVENTF_RIGHTUP
    user32.SendInput(1, ctypes.byref(inp), ctypes.sizeof(INPUT))

def run_client(host="127.0.0.1", port=6060):
    print(f"Connecting to Mac at {host}:{port}...")
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    try:
        s.connect((host, port))
        print("🟢 Connected to Mac! Mouse & Keyboard sharing active.")
        print("Move cursor back across the edge on Mac or press Cmd+Esc to release.")
        buffer = ""
        while True:
            data = s.recv(4096).decode("utf-8")
            if not data:
                break
            buffer += data
            while "\n" in buffer:
                line, buffer = buffer.split("\n", 1)
                line = line.strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                    ev_type = event.get("type")
                    if ev_type == "mouseMove":
                        send_mouse_move(event.get("dx", 0), event.get("dy", 0))
                    elif ev_type == "mouseDown":
                        send_mouse_click(event.get("button", 1), True)
                    elif ev_type == "mouseUp":
                        send_mouse_click(event.get("button", 1), False)
                except Exception:
                    pass
    except Exception as e:
        print(f"❌ Connection error: {e}")
    finally:
        s.close()
        print("KeySync client stopped.")

if __name__ == "__main__":
    mac_ip = input("Enter Mac IP (shown on Mac Menu Bar, e.g. 192.168.1.100 or press Enter for 127.0.0.1): ").strip()
    if not mac_ip:
        mac_ip = "127.0.0.1"
    run_client(host=mac_ip)
