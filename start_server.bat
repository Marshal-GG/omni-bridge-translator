@echo off
echo Starting OmniBridge Flutter Server...
call "%~dp0server_env\Scripts\activate.bat"
cd /d "%~dp0server"
python flutter_server.py
pause
