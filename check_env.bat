@echo off
setlocal enabledelayedexpansion
:: %1: WSL_DISTRO (e.g. default, AI-Dev-Env)

:: 1. WSL自体のインストールチェック
wsl --status >nul 2>&1
if !errorlevel! neq 0 (
    echo [エラー] WSL2がインストールされていないか、有効になっていません。
    goto NEED_SETUP
)

:: 2. ディストリビューションの存在チェック
if "%~1"=="default" (
    wsl -- true >nul 2>&1
    if !errorlevel! neq 0 (
        echo [エラー] デフォルトのWSLディストリビューションが起動できません。
        goto NEED_SETUP
    )
) else (
    wsl -d %~1 -- true >nul 2>&1
    if !errorlevel! neq 0 (
        echo [エラー] WSLディストリビューション "%~1" が存在しないか、起動できません。
        goto NEED_SETUP
    )
)

:: すべてチェック通過
exit /b 0

:NEED_SETUP
echo --------------------------------------------------
echo 環境のセットアップが行われていません。
echo setup.bat を実行して環境を構築する必要があります。
echo --------------------------------------------------
set /p RUN_SETUP="セットアップを実行しますか？ (y/N): "
if /I "!RUN_SETUP!"=="Y" (
    echo 管理者権限で setup.bat を起動します...
    powershell -NoProfile -Command "Start-Process '%~dp0setup.bat' -Verb RunAs"
    exit /b 1
)
exit /b 1
