@echo off
setlocal enabledelayedexpansion
chcp 932 > nul
cd /d %~dp0

call check_env.bat default
if %errorlevel% neq 0 (
    pause
    exit /b %errorlevel%
)

:: Windows側で Ollama が動いているか確認、無ければ起動
tasklist /FI "IMAGENAME eq ollama.exe" 2>NUL | find /I /N "ollama.exe" >NUL
if %errorlevel% neq 0 (
    echo [情報] Ollama が起動していません。起動します...
    start /b ollama serve
    timeout /t 5 /nobreak >nul
)

echo [情報] コンテナを再起動しています...
wsl -u root -- bash -c "if [ -d /usr/local/share/ai-env ]; then cd /usr/local/share/ai-env && podman-compose down && podman-compose up -d; fi"

echo --------------------------------------------------
echo  AI開発環境（デフォルト）を起動しました。
echo  - Web UI: http://localhost:3000
echo  - SearXNG: http://localhost:8888
echo --------------------------------------------------
echo WSLターミナルに入ります...
wsl --cd ~
exit /b 0
