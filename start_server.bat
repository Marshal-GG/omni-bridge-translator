@echo off
echo Starting OmniBridge Flutter Server...
set OMNI_BRIDGE_DEBUG=true
call "%~dp0.venv\Scripts\activate.bat"
cd /d "%~dp0server"
python flutter_server.py
pause
