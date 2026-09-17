#requires -version 5.1
<#
LABORATÓRIO DIDÁTICO DE PERÍCIA COMPUTACIONAL — FLARE-VM
Caso: TechCorp
Objetivo: gerar evidências FICTÍCIAS para análise em Event Viewer, Wireshark e IDA/Ghidra.
ATENÇÃO: execute SOMENTE em uma VM/laboratório isolado fornecido pelo professor.
O script NÃO cria malware nem realiza persistência real. O executável do caso é um artefato benigno
de laboratório com strings e comportamento controlado para facilitar análise estática.
#>

$ErrorActionPreference = "Stop"

$Root = "C:\LabForensic\Caso_TechCorp"
$Evidence = Join-Path $Root "Evidence"
$Logs = Join-Path $Root "Logs"
$Network = Join-Path $Root "Network"
$Mobile = Join-Path $Root "Mobile_Simulated"
$Tools = Join-Path $Root "Tools"

New-Item -ItemType Directory -Force -Path $Root,$Evidence,$Logs,$Network,$Mobile,$Tools | Out-Null

function Write-LabFile {
    param([string]$Path,[string]$Content)
    $Content | Set-Content -Path $Path -Encoding UTF8
}

function SHA256($Path) {
    (Get-FileHash -Algorithm SHA256 -Path $Path).Hash
}

# ------------------------------------------------------------
# 1. DOCUMENTAÇÃO DO CASO
# ------------------------------------------------------------
Write-LabFile "$Root\CASE_README.txt" @"
CASO TECHCORP — LABORATÓRIO DIDÁTICO
=====================================

Escopo:
Investigar artefatos fictícios relacionados ao componente CorpSync_Service.

Evidências principais:
E01 - CorpSync_Service.exe
E02 - CorpSync_Service.log
E03 - Application Event Log / Source CorpSync_Service
E04 - C2_Traffic_Capture.pcap
E05 - Mobile_Sync_Artifacts
E06 - Timeline.csv

Perguntas:
1. Quais fatos são diretamente observáveis?
2. Quais indicadores precisam de correlação?
3. A comunicação observada no PCAP pode ser relacionada ao executável?
4. Como a integridade das evidências foi preservada?
5. Quais conclusões permanecem indeterminadas?
"@

# ------------------------------------------------------------
# 2. LOGS PARA EVENT VIEWER
# ------------------------------------------------------------
$log = @"
2026-08-31 08:41:12 [INFO] CorpSync_Service iniciado.
2026-08-31 08:41:15 [INFO] Configuração carregada: C:\ProgramData\CorpSync\config.json
2026-08-31 08:42:03 [INFO] Usuário: analyst
2026-08-31 08:43:27 [WARN] Tentativa de acesso ao arquivo: C:\Users\analyst\Documents\Financeiro.xlsx
2026-08-31 08:44:02 [INFO] Preparando sincronização.
2026-08-31 08:44:18 [WARN] Endpoint remoto configurado: 192.168.56.20:8080
2026-08-31 08:44:22 [INFO] Requisição HTTP de teste enviada.
2026-08-31 08:45:01 [WARN] Arquivo temporário criado: C:\ProgramData\CorpSync\cache\sync.tmp
2026-08-31 08:46:33 [INFO] Sincronização finalizada.
"@
Write-LabFile "$Logs\CorpSync_Service.log" $log

# Criar Application Source/Events fictícios em arquivo CSV e também registrar eventos reais
# em Application, sem depender de uma DLL de Event Source.
$events = @(
    [pscustomobject]@{Time="2026-08-31 08:41:12"; Id=1001; Level="Information"; Source="CorpSync_Service"; Message="Service started successfully."}
    [pscustomobject]@{Time="2026-08-31 08:43:27"; Id=1002; Level="Warning"; Source="CorpSync_Service"; Message="Access attempt: C:\Users\analyst\Documents\Financeiro.xlsx"}
    [pscustomobject]@{Time="2026-08-31 08:44:18"; Id=1003; Level="Warning"; Source="CorpSync_Service"; Message="Remote endpoint configured: 192.168.56.20:8080"}
)
$events | Export-Csv "$Logs\EventViewer_CorpSync.csv" -NoTypeInformation -Encoding UTF8

# Registrar 3 eventos no log Application usando uma fonte já existente: Windows PowerShell.
# A mensagem contém a fonte fictícia do caso, permitindo a correlação didática.
foreach($e in $events){
    $msg = "[LAB][CorpSync_Service][ID=$($e.Id)] $($e.Message)"
    try {
        Write-EventLog -LogName Application -Source "Windows PowerShell" -EventId ([int]$e.Id) -EntryType Information -Message $msg
    } catch {
        # Caso a política/ambiente impeça Write-EventLog, o CSV continua sendo a evidência didática.
    }
}

# ------------------------------------------------------------
# 3. ARTEFATOS "MOBILE" SIMULADOS
# ------------------------------------------------------------
Write-LabFile "$Mobile\device_info.txt" @"
DEVICE_ID=TC-MOBILE-014
PLATFORM=Android-Lab-Simulation
ACQUISITION_TYPE=Simulated logical export
USER=analyst
EXPORT_TIME=2026-08-31 08:30:00
NOTE=Dados fictícios para aula; não representam dispositivo real.
"@

Write-LabFile "$Mobile\app_sync_preferences.json" @'
{
  "application": "CorpSync Mobile",
  "version": "4.2.1-lab",
  "account": "analyst",
  "sync_enabled": true,
  "server": "192.168.56.20",
  "server_port": 8080,
  "last_sync": "2026-08-31T08:44:18"
}
'@

Write-LabFile "$Mobile\messages_simulated.txt" @"
[2026-08-31 08:42:03] analyst -> CorpSync Mobile: iniciar sincronização
[2026-08-31 08:44:18] CorpSync Mobile -> servidor: sincronização iniciada
[2026-08-31 08:46:33] CorpSync Mobile -> servidor: sincronização concluída
"@

# ------------------------------------------------------------
# 4. ARTEFATO PARA IDA/ANÁLISE ESTÁTICA
# ------------------------------------------------------------
# Cria um pequeno programa C benigno e, se gcc estiver disponível, compila.
# Caso não haja compilador, cria um arquivo-fonte e um script de compilação.
$source = @'
#include <stdio.h>
#include <string.h>

static const char *LAB_CASE = "TECHCORP-LAB";
static const char *SERVICE = "CorpSync_Service";
static const char *SERVER = "192.168.56.20";
static const char *URL = "http://192.168.56.20:8080/api/v1/sync";
static const char *TARGET = "C:\\Users\\analyst\\Documents\\Financeiro.xlsx";
static const char *USER = "analyst";
static const char *UA = "CorpSync-Lab/4.2.1";

int main(void) {
    char buffer[128];
    snprintf(buffer, sizeof(buffer), "%s -> %s", SERVICE, SERVER);
    printf("%s\n", buffer);
    printf("URL=%s\n", URL);
    printf("TARGET=%s\n", TARGET);
    printf("USER=%s\n", USER);
    printf("USER_AGENT=%s\n", UA);
    printf("CASE=%s\n", LAB_CASE);
    return 0;
}
'@
Write-LabFile "$Tools\CorpSync_Service.c" $source

$compileBat = @'
@echo off
where gcc >nul 2>&1
if errorlevel 1 (
  echo GCC nao encontrado. O arquivo CorpSync_Service.c pode ser analisado como fonte.
  exit /b 1
)
gcc -O0 -o "C:\LabForensic\Caso_TechCorp\Evidence\CorpSync_Service.exe" "C:\LabForensic\Caso_TechCorp\Tools\CorpSync_Service.c"
echo Executavel de laboratorio criado.
'@
Write-LabFile "$Tools\compile_CorpSync.bat" $compileBat

# Tentar compilar se gcc existir.
try {
    & gcc -O0 -o "$Evidence\CorpSync_Service.exe" "$Tools\CorpSync_Service.c" 2>$null
} catch {}

# Se não houver GCC, criar um arquivo de texto com extensão .txt para não fingir ser executável.
if(-not (Test-Path "$Evidence\CorpSync_Service.exe")){
    Write-LabFile "$Evidence\CorpSync_Service_SOURCE_ONLY.txt" "GCC não disponível nesta VM. Analise Tools\CorpSync_Service.c ou compile com o script Tools\compile_CorpSync.bat."
}

# ------------------------------------------------------------
# 5. PCAP PARA WIRESHARK
# ------------------------------------------------------------
# Tenta criar uma captura real de laboratório usando pktmon, ferramenta nativa do Windows.
# Gera tráfego HTTP somente para um endpoint local/isolado. Se pktmon não estiver disponível,
# cria um arquivo de instruções para o professor gerar a captura no Wireshark.
$pcap = "$Network\C2_Traffic_Capture.pcapng"
$pcapInstructions = "$Network\COMO_GERAR_PCAP.txt"

Write-LabFile $pcapInstructions @"
PCAP DO CASO TECHCORP
=====================

Se C2_Traffic_Capture.pcapng não foi criado automaticamente:
1. Inicie o Wireshark na FLARE-VM.
2. Selecione a interface de laboratório/loopback apropriada.
3. Inicie a captura.
4. Em outro terminal, gere tráfego HTTP de laboratório para:
   http://127.0.0.1:8080/api/v1/sync
5. Pare a captura e salve como:
   C:\LabForensic\Caso_TechCorp\Network\C2_Traffic_Capture.pcapng

Para análise:
- http
- tcp.port == 8080
- ip.addr == 127.0.0.1
"@

# Servidor local temporário para permitir uma captura real e controlada.
$serverScript = "$Network\lab_server.py"
Write-LabFile $serverScript @'
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        body=b'{"case":"TECHCORP-LAB","service":"CorpSync_Service","status":"sync"}'
        self.send_response(200)
        self.send_header("Content-Type","application/json")
        self.send_header("Content-Length",str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, fmt, *args): pass
HTTPServer(("127.0.0.1",8080),H).handle_request()
'@

# Gerador PowerShell de tráfego local (funciona sem Python)
$invoke = "$Network\generate_lab_http.ps1"
Write-LabFile $invoke @'
try {
  $r = Invoke-WebRequest -Uri "http://127.0.0.1:8080/api/v1/sync" -Headers @{"User-Agent"="CorpSync-Lab/4.2.1"} -UseBasicParsing -TimeoutSec 3
  "HTTP status: $($r.StatusCode)"
  "Body: $($r.Content)"
} catch {
  "Endpoint local não está ativo. Inicie um servidor HTTP de laboratório antes da captura."
}
'@

# Se pktmon existir, o professor pode usá-lo para conversão para pcapng.
if (Get-Command pktmon.exe -ErrorAction SilentlyContinue) {
    Write-LabFile "$Network\pktmon_capture_steps.txt" @"
EXEMPLO CONTROLADO:
1. Abra Wireshark ou pktmon.
2. Capture somente a interface de laboratório/loopback.
3. Gere uma requisição para 127.0.0.1:8080.
4. Salve/exporte a captura em C2_Traffic_Capture.pcapng.
"@
}

# ------------------------------------------------------------
# 6. TIMELINE
# ------------------------------------------------------------
$timeline = @(
    [pscustomobject]@{Timestamp="2026-08-31 08:41:12"; Source="Application"; Artifact="CorpSync_Service"; Event="Service started"}
    [pscustomobject]@{Timestamp="2026-08-31 08:43:27"; Source="Application"; Artifact="CorpSync_Service"; Event="Access attempt to Financeiro.xlsx"}
    [pscustomobject]@{Timestamp="2026-08-31 08:44:18"; Source="Application"; Artifact="CorpSync_Service"; Event="Remote endpoint configured"}
    [pscustomobject]@{Timestamp="2026-08-31 08:44:22"; Source="Network"; Artifact="PCAP"; Event="HTTP lab request"}
    [pscustomobject]@{Timestamp="2026-08-31 08:46:33"; Source="Mobile"; Artifact="CorpSync Mobile"; Event="Sync completed"}
)
$timeline | Export-Csv "$Evidence\Timeline.csv" -NoTypeInformation -Encoding UTF8

# ------------------------------------------------------------
# 7. HASHES / MANIFESTO
# ------------------------------------------------------------
$files = Get-ChildItem $Root -File -Recurse |
    Where-Object { $_.FullName -notmatch "\\Manifest_SHA256.csv$" }

$manifest = foreach($f in $files){
    [pscustomobject]@{
        EvidenceFile = $f.FullName.Substring($Root.Length+1)
        SizeBytes = $f.Length
        SHA256 = (Get-FileHash -Algorithm SHA256 -Path $f.FullName).Hash
        LastWriteTime = $f.LastWriteTime.ToString("s")
    }
}
$manifest | Export-Csv "$Root\Manifest_SHA256.csv" -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "==============================================="
Write-Host "CASO TECHCORP GERADO COM SUCESSO"
Write-Host "Local: $Root"
Write-Host "Manifesto: $Root\Manifest_SHA256.csv"
Write-Host "==============================================="
Write-Host "Para Wireshark: $Network"
Write-Host "Para Event Viewer: $Logs"
Write-Host "Para IDA/Ghidra: $Evidence e $Tools"
