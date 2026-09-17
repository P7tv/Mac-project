@echo off
title AudioTunnel Windows Client
cd /d "%~dp0"
echo ========================================================
echo   AudioTunnel Windows Receiver
echo ========================================================
python audiotunnel_receiver.py
pause
