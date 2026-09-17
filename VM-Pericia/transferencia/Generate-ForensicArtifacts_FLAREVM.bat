@echo off
setlocal
title TechCorp - Gerador de Evidencias Forenses - FLARE-VM

echo ============================================================
echo   PROJETO INTEGRADOR - PERICIA COMPUTACIONAL
echo   GERADOR DE EVIDENCIAS FICTICIAS - CASO TECHCORP
echo ============================================================
echo.
echo Este script deve ser executado SOMENTE na FLARE-VM/laboratorio.
echo Nao utilize dados pessoais ou dispositivos reais.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Generate-ForensicArtifacts_FLAREVM.ps1"

if errorlevel 1 (
    echo.
    echo [ERRO] O PowerShell retornou erro.
    echo Verifique a mensagem acima.
    pause
    exit /b 1
)

echo.
echo [OK] Evidencias criadas.
echo.
echo Diretorio principal:
echo C:\LabForensic\Caso_TechCorp
echo.
echo Event Viewer:
echo   C:\LabForensic\Caso_TechCorp\Logs
echo.
echo Wireshark:
echo   C:\LabForensic\Caso_TechCorp\Network
echo.
echo IDA/Ghidra:
echo   C:\LabForensic\Caso_TechCorp\Evidence
echo   C:\LabForensic\Caso_TechCorp\Tools
echo.
echo Manifesto SHA-256:
echo   C:\LabForensic\Caso_TechCorp\Manifest_SHA256.csv
echo.
timeout /t 3 /nobreak >nul

del /f /q "%~dp0Generate-ForensicArtifacts_FLAREVM.ps1" >nul 2>&1
del /f /q "%~f0" >nul 2>&1

endlocal
