@echo off
setlocal enabledelayedexpansion
chcp 932 > nul

cd /d %~dp0

openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo [エラー] このスクリプトは「管理者として実行」する必要があります。
    echo 右クリックして「管理者として実行」を選び直してください。
    pause
    exit /b
)

echo ===================================================================
echo  AI開発環境 完全アンインストール・クリーンアップツール
echo ===================================================================
echo.
echo 削除するターゲット環境のタイプを選択してください。
echo.
echo  [1] 専用独自環境（AI-Dev-Env）を丸ごと完全消去する
echo      - ディストリビューションごと一撃で消去し、ストレージを100%%解放します。
echo.
echo  [2] 既存のWSL2環境から、本アセット（コンテナ・設定）のみを削除する
echo      - Linux本体は残し、Ansibleの機能で追加分だけをピンポイントで撤去します。
echo.
:CHOOSE_UNINSTALL
set /p UN_CHOICE="選択してください (1 または 2): "

if "!UN_CHOICE!"=="1" (
    echo.
    set /p CONFIRM="専用環境「AI-Dev-Env」を丸ごと完全消去します。よろしいですか？ (y/N): "
    if /I not "!CONFIRM!"=="Y" goto CANCEL
    
    echo [情報] 独自環境の完全削除を開始します...
    wsl --unregister AI-Dev-Env 2>nul
    echo [正常] 専用ディストリビューション「AI-Dev-Env」を消去しました。

) else if "!UN_CHOICE!"=="2" (
    echo.
    wsl --list --quiet
    echo.
    set /p WSL_DIST="クリーンアップ対象のディストリビューション名を入力してください: "
    
    set /p CONFIRM="!WSL_DIST! からAIコンテナ・環境変数・設定ファイルのみを削除します。よろしいですか？ (y/N): "
    if /I not "!CONFIRM!"=="Y" goto CANCEL

    echo [情報] Ansibleによるピンポイントクリーンアップを開始します...
    wsl -d !WSL_DIST! -u root -- bash -c "if command -v ansible-playbook >/dev/null; then ansible-playbook /usr/local/share/ai-env/playbook.yml --tags=uninstall; else cd /usr/local/share/ai-env && podman-compose down -v && rm -rf /usr/local/share/ai-env; fi"
    echo [正常] Linux内部のクリーンアップが完了しました。
) else (
    echo [エラー] 1 または 2 を入力してください。
    goto CHOOSE_UNINSTALL
)

:: 共通のWindows側環境変数クリーンアップ
echo.
echo -------------------------------------------------------------------
echo  プロセス 3: Windowsホスト側の共通環境変数の削除
echo -------------------------------------------------------------------
echo [情報] 不要になったシステム環境変数を削除中...
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v OLLAMA_HOST /f >nul 2>nul
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v OPENAI_API_BASE /f >nul 2>nul
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v CODEX_CONFIG_PATH /f >nul 2>nul

:: Ollamaの削除確認
echo.
echo -------------------------------------------------------------------
echo  プロセス 4: Windows側の Ollama アプリ・モデルデータの削除選択
echo -------------------------------------------------------------------
echo Windowsホスト側にインストールされている Ollama もアンインストールしますか？
echo ※ダウンロードしたAIモデル（qwen3.5:2b 等）の巨大なデータも同時に消去します。
echo.
set /p OLLAMA_DEL="Ollamaを削除しますか？ (y/N): "

if /I "!OLLAMA_DEL!"=="Y" (
    echo [情報] パフォーマンス用環境変数をクリア中...
    reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v OLLAMA_KEEP_ALIVE /f >nul 2>nul
    reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v OLLAMA_VULKAN /f >nul 2>nul
    reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v OLLAMA_VULKAN_FALLBACK /f >nul 2>nul
    reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v OLLAMA_INTEL_GPU /f >nul 2>nul

    echo [情報] 起動中のOllamaプロセスを強制終了中...
    taskkill /F /IM "ollama app.exe" >nul 2>nul
    taskkill /F /IM "ollama.exe" >nul 2>nul

    if exist "%USERPROFILE%\.ollama" (
        echo [情報] 巨大なAIモデルデータ（%USERPROFILE%\.ollama）を削除しています...
        rmdir /s /q "%USERPROFILE%\.ollama"
        echo [正常] モデルデータを完全消去しました。
    )

    echo.
    echo [重要] 画面に「プログラムのアンインストール」ウィンドウを開きます。
    echo        一覧から「Ollama」を探して手動でアンインストールを完了させてください。
    echo.
    echo キーを押すと画面が開きます...
    pause > nul
    control appwiz.cpl
) else (
    echo [情報] Ollamaアプリ本体およびモデルデータはそのまま残します。
)

echo.
echo -------------------------------------------------------------------
echo  プロセス 5: WSL2サブシステムのリセット
echo -------------------------------------------------------------------
wsl --shutdown
echo [正常] WSLサブシステムをシャットダウンしました。

echo.
echo ===================================================================
echo  クリーンアップが正常に完了しました。
echo ===================================================================
echo お疲れ様でした。
echo.
pause
exit /b 0

:CANCEL
echo [情報] キャンセルしました。処理を終了します。
timeout /t 3 > nul
exit /b 0
