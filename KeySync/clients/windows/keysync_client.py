#!/usr/bin/env python3
"""
KeySync Windows Companion Receiver
-----------------------------------
Receives smooth mouse movements, clicks, scrolls, and keystrokes from your Mac over local Wi-Fi.
Uses Windows SendInput for sub-millisecond, zero-lag input injection.
"""

import sys
import os
import socket
import json
import argparse
import time

IS_WINDOWS = sys.platform == "win32"

if IS_WINDOWS:
    import ctypes
    from ctypes import wintypes
    user32 = ctypes.windll.user32

    INPUT_MOUSE = 0
    INPUT_KEYBOARD = 1

    MOUSEEVENTF_MOVE = 0x0001
    MOUSEEVENTF_LEFTDOWN = 0x0002
    MOUSEEVENTF_LEFTUP = 0x0004
    MOUSEEVENTF_RIGHTDOWN = 0x0008
    MOUSEEVENTF_RIGHTUP = 0x0010
    MOUSEEVENTF_MIDDLEDOWN = 0x0020
    MOUSEEVENTF_MIDDLEUP = 0x0040
    MOUSEEVENTF_WHEEL = 0x0800
    MOUSEEVENTF_HWHEEL = 0x1000

    KEYEVENTF_EXTENDEDKEY = 0x0001
    KEYEVENTF_KEYUP = 0x0002
    KEYEVENTF_SCANCODE = 0x0008

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

# Mac virtual keycode to Windows Virtual Key (VK) mapping
MAC_TO_WIN_VK = {
    0: 0x41,   # A
    1: 0x53,   # S
    2: 0x44,   # D
    3: 0x46,   # F
    4: 0x48,   # H
    5: 0x47,   # G
    6: 0x5A,   # Z
    7: 0x58,   # X
    8: 0x43,   # C
    9: 0x56,   # V
    11: 0x42,  # B
    12: 0x51,  # Q
    13: 0x57,  # W
    14: 0x45,  # E
    15: 0x52,  # R
    16: 0x59,  # Y
    17: 0x54,  # T
    18: 0x31,  # 1
    19: 0x32,  # 2
    20: 0x33,  # 3
    21: 0x34,  # 4
    22: 0x36,  # 6
    23: 0x35,  # 5
    24: 0xBB,  # =
    25: 0x39,  # 9
    26: 0x37,  # 7
    27: 0xBD,  # -
    28: 0x38,  # 8
    29: 0x30,  # 0
    30: 0xDD,  # ]
    31: 0x4F,  # O
    32: 0x55,  # U
    33: 0xDB,  # [
    34: 0x49,  # I
    35: 0x50,  # P
    36: 0x0D,  # Return / Enter
    37: 0x4C,  # L
    38: 0x4A,  # J
    39: 0xDE,  # '
    40: 0x4B,  # K
    41: 0xBA,  # ;
    42: 0xDC,  # \
    43: 0xBC,  # ,
    44: 0xBF,  # /
    45: 0x4E,  # N
    46: 0x4D,  # M
    47: 0xBE,  # .
    48: 0x09,  # Tab
    49: 0x20,  # Space
    50: 0xC0,  # `
    51: 0x08,  # Backspace
    53: 0x1B,  # Escape
    55: 0x5B,  # Cmd -> Win Key
    56: 0x10,  # Shift
    57: 0x14,  # CapsLock
    58: 0x12,  # Option -> Alt
    59: 0x11,  # Control -> Ctrl
    117: 0x2E, # Delete
    123: 0x25, # Left Arrow
    124: 0x27, # Right Arrow
    125: 0x28, # Down Arrow
    126: 0x26, # Up Arrow
}

def send_mouse_move(dx, dy):
    if not IS_WINDOWS:
        return
    inp = INPUT()
    inp.type = INPUT_MOUSE
    inp.u.mi.dx = int(dx)
    inp.u.mi.dy = int(dy)
    inp.u.mi.dwFlags = MOUSEEVENTF_MOVE
    user32.SendInput(1, ctypes.byref(inp), ctypes.sizeof(INPUT))

def send_mouse_click(button, is_down):
    if not IS_WINDOWS:
        return
    inp = INPUT()
    inp.type = INPUT_MOUSE
    # 0 = Left, 1 = Right, 2 = Middle
    if button == 0:
        inp.u.mi.dwFlags = MOUSEEVENTF_LEFTDOWN if is_down else MOUSEEVENTF_LEFTUP
    elif button == 1:
        inp.u.mi.dwFlags = MOUSEEVENTF_RIGHTDOWN if is_down else MOUSEEVENTF_RIGHTUP
    elif button == 2:
        inp.u.mi.dwFlags = MOUSEEVENTF_MIDDLEDOWN if is_down else MOUSEEVENTF_MIDDLEUP
    else:
        inp.u.mi.dwFlags = MOUSEEVENTF_LEFTDOWN if is_down else MOUSEEVENTF_LEFTUP
    user32.SendInput(1, ctypes.byref(inp), ctypes.sizeof(INPUT))

def send_mouse_scroll(dx, dy):
    if not IS_WINDOWS:
        return
    # Vertical scroll
    if dy != 0:
        inp = INPUT()
        inp.type = INPUT_MOUSE
        inp.u.mi.mouseData = int(dy * 12)  # Scale delta
        inp.u.mi.dwFlags = MOUSEEVENTF_WHEEL
        user32.SendInput(1, ctypes.byref(inp), ctypes.sizeof(INPUT))
    # Horizontal scroll
    if dx != 0:
        inp = INPUT()
        inp.type = INPUT_MOUSE
        inp.u.mi.mouseData = int(dx * 12)
        inp.u.mi.dwFlags = MOUSEEVENTF_HWHEEL
        user32.SendInput(1, ctypes.byref(inp), ctypes.sizeof(INPUT))

def send_key(key_code, is_down):
    if not IS_WINDOWS:
        return
    vk = MAC_TO_WIN_VK.get(key_code)
    if not vk:
        return
    inp = INPUT()
    inp.type = INPUT_KEYBOARD
    inp.u.ki.wVk = vk
    inp.u.ki.dwFlags = 0 if is_down else KEYEVENTF_KEYUP
    user32.SendInput(1, ctypes.byref(inp), ctypes.sizeof(INPUT))

def run_client(host="127.0.0.1", port=6060):
    print("=" * 60)
    print("           KeySync Windows Companion Receiver")
    print("=" * 60)
    print(f"Connecting to Mac at {host}:{port}...")

    while True:
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            s.connect((host, port))
            print(f"🟢 Connected to Mac ({host}:{port})!")
            print("   - Mouse movements, clicks, scrolls, and keystrokes are synchronized.")
            print("   - Return cursor back across the edge on Mac or press 'Esc' on Mac to release.")

            buffer = ""
            while True:
                data = s.recv(4096).decode("utf-8")
                if not data:
                    print("⚠️ Mac disconnected. Reconnecting in 2 seconds...")
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
                            send_mouse_click(event.get("button", 0), True)
                        elif ev_type == "mouseUp":
                            send_mouse_click(event.get("button", 0), False)
                        elif ev_type == "mouseScroll":
                            send_mouse_scroll(event.get("dx", 0), event.get("dy", 0))
                        elif ev_type == "keyDown":
                            send_key(event.get("keyCode", 0), True)
                        elif ev_type == "keyUp":
                            send_key(event.get("keyCode", 0), False)
                        elif ev_type == "ping":
                            # Reply with pong
                            s.sendall(json.dumps({"type": "pong", "timestamp": event.get("timestamp", 0)}).encode("utf-8") + b"\n")
                    except Exception:
                        pass
        except KeyboardInterrupt:
            print("\nKeySync stopped by user.")
            break
        except Exception as e:
            print(f"⚠️ Connection failed ({e}). Retrying in 2 seconds...")
            time.sleep(2)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="KeySync Windows Companion Receiver")
    parser.add_argument("host", nargs="?", default=None, help="Mac IP address")
    parser.add_argument("--host", dest="opt_host", default=None, help="Mac IP address")
    parser.add_argument("--port", type=int, default=6060, help="KeySync port (default: 6060)")
    args = parser.parse_args()

    target_host = args.host or args.opt_host
    if not target_host:
        target_host = input("Enter Mac IP (shown in KeySync app on Mac, e.g. 192.168.1.100) [127.0.0.1]: ").strip()
        if not target_host:
            target_host = "127.0.0.1"

    run_client(host=target_host, port=args.port)
