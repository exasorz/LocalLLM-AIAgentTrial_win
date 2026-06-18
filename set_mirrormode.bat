@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: WSL2 ミラーモード（networkingMode=mirrored）の自動診断 ＆ 強制有効化
:: ============================================================================
echo [検証] WSL2のネットワーク環境（ミラーモード）を診断中...

set "WSL_CONFIG=%USERPROFILE%\.wslconfig"
set "NEED_SHUTDOWN=0"
set "HAS_MIRRORED=0"

:: .wslconfig が存在するかチェック
if not exist "!WSL_CONFIG!" (
    echo [警告] .wslconfig が見つからないため、最適化設定ファイルを新規作成します。
    echo [wsl2]> "!WSL_CONFIG!"
    echo memory=4GB>> "!WSL_CONFIG!"
    echo swap=2GB>> "!WSL_CONFIG!"
    echo networkingMode=mirrored>> "!WSL_CONFIG!"
    set "NEED_SHUTDOWN=1"
    goto WSL_CONFIG_APPLIED
)

:: 既存ファイル内に networkingMode=mirrored があるかスキャン
findstr /I /C:"networkingMode=mirrored" "!WSL_CONFIG!" >nul
if !errorlevel! equ 0 (
    set "HAS_MIRRORED=1"
)

:: ミラーモードが無効、または記述がない場合の自動書き換え処理
if !HAS_MIRRORED! equ 0 (
    echo [警告] WSL2が古いネットワークモード（NAT）で動作している可能性があります。
    echo [情報] Ollamaとの通信を100%%安定させるため、ミラーモードを自動有効化します...
    
    :: 安全のため既存ファイルのバックアップを作成
    copy /Y "!WSL_CONFIG!" "!WSL_CONFIG!.bak" >nul
    
    :: [wsl2] セクションの直後に networkingMode=mirrored を動的挿入
    set "TEMP_CONFIG=!WSL_CONFIG!.tmp"
    if exist "!TEMP_CONFIG!" del "!TEMP_CONFIG!"
    
    for /f "delims=" %%L in (!WSL_CONFIG!) do (
        echo %%L>> "!TEMP_CONFIG!"
        echo %%L | findstr /I "\[wsl2\]" >nul
        if !errorlevel! equ 0 (
            echo networkingMode=mirrored>> "!TEMP_CONFIG!"
        )
    )
    move /Y "!TEMP_CONFIG!" "!WSL_CONFIG!" >nul
    set "NEED_SHUTDOWN=1"
)

:WSL_CONFIG_APPLIED
:: 設定が書き換えられた場合は、ユーザーに通知してWSL2を強制リセット
if !NEED_SHUTDOWN! equ 1 (
    echo ----------------------------------------------------------------
    echo 【重要】WSL2のネットワーク設定（ミラーモード）を有効化しました。
    echo ----------------------------------------------------------------
    echo 設定をOS層に反映させるため、起動中のWSL環境を一度強制終了します。
    echo.
    wsl --shutdown
    echo.
    echo [確認] Windows側のOllamaアプリも、一度「Quit」して再起動してください。
    echo.
    echo 準備が整ったら、何かキーを押して環境構築を再開してください...
    pause >nul
) else (
    echo [正常] WSL2ミラーモードは既に有効です。インフラ構築を進めます。
)
:: ============================================================================

pause
