@echo off
setlocal enabledelayedexpansion
chcp 932 > nul

:: 【最重要ガードレール】右クリック「管理者として実行」された際、System32に強制移動させられた
:: カレントディレクトリを、このバッチファイルが置いてある本来のフォルダへと自動引き戻し
cd /d %~dp0

echo ======================================================
echo  AI開発環境 一括自動構築スクリプト (Codex対応版)
echo ======================================================

echo [情報] STEP 1. 管理者権限チェック
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo [エラー] このスクリプトは「管理者として実行」する必要があります。
    echo 右クリックして「管理者として実行」を選び直してください。
    pause
    exit /b
)

echo [情報] STEP 2. Cドライブの空き容量をチェックします（目安：30GB）
set REQUIRED_GB=30
for /f "usebackq tokens=*" %%A in (`powershell -NoProfile -Command "[math]::truncate\(\(Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='C:'\"\).FreeSpace / 1GB\)"`) do set FREE_GB=%%A

if "%FREE_GB%"=="" (
    echo [警告] 容量の自動チェックに失敗しました。処理を続行します。
    goto SKIP_DISK_CHECK
)
if %FREE_GB% LSS %REQUIRED_GB% (
    echo [エラー] Cドライブの空き容量が不足しています。 (空き: %FREE_GB% GB)
    pause
    exit /b
)
:SKIP_DISK_CHECK

echo [情報] STEP 3. Windows側：環境変数の設定 (ミラーモードを見据え 127.0.0.1 化)
setx OLLAMA_KEEP_ALIVE "-1" /M > nul
setx OLLAMA_VULKAN "1" /M > nul
setx OLLAMA_VULKAN_FALLBACK "-1" /M > nul
setx OLLAMA_HOST "127.0.0.1" /M > nul
set OLLAMA_KEEP_ALIVE=-1
set OLLAMA_VULKAN=1
set OLLAMA_VULKAN_FALLBACK=1
set OLLAMA_HOST=127.0.0.1

echo [情報] STEP 4. Windows側：Intel GPUの自動判別
wmic path win32_VideoController get Name | findstr /I "Intel" > nul
if %errorlevel%==0 (
    setx OLLAMA_INTEL_GPU "1" /M > nul
    set OLLAMA_INTEL_GPU=1
)

echo [情報] STEP 5. Windows側：Ollama のインストール有無チェック ＆ 起動
where ollama >nul 2>&1
if %errorlevel% neq 0 (
    echo [情報] Ollama が見つかりません。winget経由でインストールを開始します...
    winget install --id Ollama.Ollama -e --accept-source-agreements --accept-package-agreements
    echo --------------------------------------------------
    echo [注意] インストール完了後、この画面を閉じ、再度「管理者として実行」してください。
    echo --------------------------------------------------
    pause
    exit /b
)
tasklist /FI "IMAGENAME eq ollama.exe" 2>NUL | find /I /N "ollama.exe" >NUL
if %errorlevel% neq 0 (
    start /b ollama serve
    timeout /t 5 /nobreak >nul
)

echo [情報] STEP 6. Windows側：qwen3.5:2b モデルの自動ダウンロード
ollama pull qwen3.5:2b

echo [情報] STEP 7. Windows側：WSL2 基本機能のチェック
wsl --status >nul 2>&1
if %errorlevel% neq 0 (
    wsl --install --no-distribution
    echo --------------------------------------------------
    echo [注意] PCの再起動が必要です。再起動後、もう一度本バッチを実行してください。
    echo --------------------------------------------------
    pause
    exit /b
)

echo [情報] STEP 8. WSL2 ネットワーク最適化（外部モジュール呼び出し）
if exist "set_mirrormode.bat" (
    call set_mirrormode.bat
) else (
    echo [エラー] set_mirrormode.bat が見つかりません。同一フォルダに配置してください。
    pause
    exit /b 1
)

echo [情報] STEP 9. WSL環境のターゲット選択
echo --------------------------------------------------
echo  構築対象となるWSL2環境を選択してください。
echo --------------------------------------------------
echo  [1] 既存のデフォルトWSL環境（Ubuntu等）をそのまま使用する
echo  [2] 既存環境を汚さないよう、新しくAI専用のWSL環境「AI-Dev-Env」を作る
echo --------------------------------------------------
set /p WSL_CHOICE="選択してください (1 or 2): "

set WSL_DISTRO=Ubuntu
set WSL_USER=
if "%WSL_CHOICE%"=="2" (
    set WSL_DISTRO=AI-Dev-Env
    set WSL_USER=aiuser
    wsl -d !WSL_DISTRO! -u root -- true >nul 2>&1
    if !errorlevel! neq 0 (
        mkdir "%USERPROFILE%\wsl-tmp" > nul 2>&1
        mkdir "%USERPROFILE%\WSL-Distros\AI-Dev-Env" > nul 2>&1
        echo [情報] Ubuntu Base 24.04 LTS イメージをダウンロードします...
        powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-amd64.tar.gz' -OutFile '%USERPROFILE%\wsl-tmp\ubuntu-rootfs.tar.gz'"
        if !errorlevel! neq 0 (
            echo [エラー] Ubuntu ベースイメージのダウンロードに失敗しました。
            pause
            exit /b 1
        )
        echo [情報] "AI-Dev-Env" をインポートします...
        wsl --import AI-Dev-Env "%USERPROFILE%\WSL-Distros\AI-Dev-Env" "%USERPROFILE%\wsl-tmp\ubuntu-rootfs.tar.gz" --version 2
        if !errorlevel! neq 0 (
            echo [エラー] AI-Dev-Env のインポートに失敗しました。
            echo 既に壊れたディレクトリが残っている場合は uninstall.bat で削除してから再実行してください。
            pause
            exit /b 1
        )
        del "%USERPROFILE%\wsl-tmp\ubuntu-rootfs.tar.gz" > nul 2>&1
        rmdir "%USERPROFILE%\wsl-tmp" > nul 2>&1
    ) else (
        echo [情報] 既存の AI-Dev-Env を使用します。
    )
    echo [情報] AI-Dev-Env の通常ユーザー aiuser を準備します...
    wsl -d !WSL_DISTRO! -u root -- bash -lc "id -u aiuser >/dev/null 2>&1 || useradd -m -s /bin/bash aiuser; mkdir -p /etc/sudoers.d; printf 'aiuser ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/99-aiuser; chmod 0440 /etc/sudoers.d/99-aiuser; printf '[user]\ndefault=aiuser\n' > /etc/wsl.conf"
    if !errorlevel! neq 0 (
        echo [エラー] AI-Dev-Env の通常ユーザー作成に失敗しました。
        pause
        exit /b 1
    )
    wsl --terminate !WSL_DISTRO! >nul 2>&1
) else if "%WSL_CHOICE%"=="1" (
    for /f "delims=" %%U in ('wsl -d %WSL_DISTRO% -- bash -lc "id -un" 2^>nul') do set "WSL_USER=%%U"
) else (
    echo [エラー] 1 または 2 を入力してください。
    pause
    exit /b 1
)
if "%WSL_USER%"=="" set WSL_USER=root
echo [情報] WSL環境「%WSL_DISTRO%」に対してパッケージ資材を先行配置中...
wsl -d %WSL_DISTRO% -u root -- mkdir -p /usr/local/share/ai-env
if %errorlevel% neq 0 (
    echo [エラー] WSL環境「%WSL_DISTRO%」を起動できませんでした。
    pause
    exit /b 1
)
for /f "delims=" %%P in ('wsl -d %WSL_DISTRO% -u root -- wslpath -a "%CD%"') do set "WSL_SOURCE_DIR=%%P"
if "%WSL_SOURCE_DIR%"=="" (
    echo [エラー] Windows側の資材フォルダをWSLパスに変換できませんでした。
    pause
    exit /b 1
)
wsl -d %WSL_DISTRO% -u root -- bash -lc "cd ""%WSL_SOURCE_DIR%"" && cp -a README.md setup.bat set_mirrormode.bat uninstall.bat inventory.ini playbook.yml files images /usr/local/share/ai-env/"
if %errorlevel% neq 0 (
    echo [エラー] WSL環境への資材コピーに失敗しました。
    pause
    exit /b 1
)

echo [情報] WSL環境「%WSL_DISTRO%」の初期OSアップデートを実行中...
wsl -d %WSL_DISTRO% -u root -- bash -lc "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y ansible curl ca-certificates sudo"
if %errorlevel% neq 0 (
    echo [エラー] WSL環境への Ansible インストールに失敗しました。
    pause
    exit /b 1
)

echo [情報] Ansibleによる環境自動構築を開始します...
wsl -d %WSL_DISTRO% -u root -- bash -lc "cd /usr/local/share/ai-env && ansible-playbook -i inventory.ini playbook.yml --tags=install -e target_user=%WSL_USER%"
if %errorlevel% neq 0 (
    echo [エラー] Ansible による環境構築に失敗しました。
    pause
    exit /b 1
)

echo.
echo ======================================================
echo  すべての構築が完了しました！
echo.
echo  [Open WebUI]  http://localhost:3000 (ブラウザUI)
echo  [SearXNG]     http://localhost:8888 (ローカル検索)
echo  [Ollama API]   http://127.0.0.1:11434/v1 (qwen3.5:2b)
echo.
echo  ※ WSLターミナルから通常ユーザー「%WSL_USER%」で「codex」コマンドが利用可能です。
echo.
echo  【重要】
echo  次回以降の環境起動には、以下の起動用スクリプトをご利用ください：
echo  - デフォルト環境の場合: run_default.bat
echo  - AI専用環境の場合    : run_AI-DEV-Env.bat
echo ======================================================
pause
exit /b 0
