@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0backend"

if not exist ".env" (
  set S1=%RANDOM%%RANDOM%%RANDOM%
  set S2=%RANDOM%%RANDOM%%RANDOM%
  (
    echo PORT=4000
    echo JWT_SECRET=famil_!S1!_!S2!_%DATE:~-4%%TIME:~0,2%%TIME:~3,2%
    echo DB_PATH=./data/famil.db
    echo CORS_ORIGIN=*
  ) > .env
)

if not exist "data" mkdir data
if not exist "uploads\profiles" mkdir uploads\profiles

echo FAMil 백엔드 서버를 시작합니다...
start "FAMil Backend" /min "%~dp0node\node.exe" src\server.js

timeout /t 2 /nobreak >nul

echo FAMil APP을 실행합니다...
start "" "%~dp0app\famil_app.exe"
