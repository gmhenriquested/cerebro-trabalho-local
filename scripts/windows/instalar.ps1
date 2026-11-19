# Instalador do cérebro de trabalho (Windows PowerShell 5.1).
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\instalar.ps1 [-Vault C:\caminho] [-SemAgendar] [-Forcar]
# Nunca sobrescreve notas do vault. Agentes e skills já existentes só são trocados com -Forcar.
param(
  [string]$Vault = (Join-Path $HOME "cerebro-trabalho"),
  [switch]$SemAgendar,
  [switch]$Forcar
)
$ErrorActionPreference = "Stop"
$Kit = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ClaudeDir = Join-Path $HOME ".claude"
$Destino = Join-Path $ClaudeDir "hooks\cerebro"
$Utf8SemBom = New-Object System.Text.UTF8Encoding $false
function Passo([string]$m) { Write-Host "-> $m" -ForegroundColor Cyan }
function Aviso([string]$m) { Write-Host "!! $m" -ForegroundColor Yellow }

# 0. Pré-requisitos
foreach ($bin in @("git", "claude")) {
  if (-not (Get-Command $bin -ErrorAction SilentlyContinue)) { Aviso "$bin não encontrado no PATH."; if ($bin -eq "git") { exit 1 } }
}
$claudeExe = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claudeExe) {
  foreach ($c in @((Join-Path $HOME ".local\bin\claude.exe"), (Join-Path $env:APPDATA "npm\claude.cmd"))) { if (Test-Path $c) { $claudeExe = $c } }
}
if (-not $claudeExe) { $claudeExe = "claude"; Aviso "Não achei o executável do claude; os loops agendados vão usar 'claude' do PATH." }

# 1. Vault (copia só o que falta)
Passo "Vault em $Vault"
$origemVault = Join-Path $Kit "vault"
Get-ChildItem $origemVault -Recurse -Force -File | ForEach-Object {
  $rel = $_.FullName.Substring($origemVault.Length).TrimStart('\')
  $alvo = Join-Path $Vault $rel
  if (-not (Test-Path $alvo)) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $alvo) | Out-Null
    Copy-Item $_.FullName $alvo
  }
}
if (-not (Test-Path (Join-Path $Vault ".git"))) {
  git -C $Vault init -q -b main
  git -C $Vault add -A
  git -C $Vault commit -q -m "Cérebro de trabalho: estrutura inicial (cerebro-trabalho-kit)"
  Passo "git iniciado no vault (crie um repo PRIVADO e rode: git -C `"$Vault`" remote add origin <url>)"
}

# 2. Agentes e skills
foreach ($tipo in @("agents", "skills")) {
  $src = Join-Path $Kit "claude\$tipo"
  $dst = Join-Path $ClaudeDir $tipo
  New-Item -ItemType Directory -Force -Path $dst | Out-Null
  foreach ($item in (Get-ChildItem $src)) {
    $alvo = Join-Path $dst $item.Name
    if ((Test-Path $alvo) -and -not $Forcar) { Aviso "$tipo\$($item.Name) já existe (use -Forcar para trocar)"; continue }
    Copy-Item $item.FullName $alvo -Recurse -Force
  }
  Passo "$tipo copiados para $dst"
}

# 3. Scripts + config
New-Item -ItemType Directory -Force -Path $Destino | Out-Null
Copy-Item (Join-Path $Kit "scripts\windows\*") $Destino -Recurse -Force
$cfg = "# Gerado pelo instalador em $(Get-Date -Format 'yyyy-MM-dd')`r`n`$Vault = '$Vault'`r`n`$ClaudeExe = '$claudeExe'`r`n"
[System.IO.File]::WriteAllText((Join-Path $Destino "config.ps1"), $cfg, (New-Object System.Text.UTF8Encoding $true))
Passo "scripts em $Destino"

# 4. Hooks no settings.json
$d = ($Destino -replace '\\', '/')
function Cmd([string]$script, [string]$args2 = "") { return "powershell -NoProfile -ExecutionPolicy Bypass -File `"$d/$script`" $args2".Trim() }
$hooks = [ordered]@{
  SessionStart = @(@{ hooks = @(@{ type = "command"; command = (Cmd "session-start.ps1"); timeout = 30 }) })
  Stop         = @(@{ hooks = @(@{ type = "command"; command = (Cmd "stop-lembrete.ps1") }, @{ type = "command"; command = (Cmd "sync.ps1" "-Origem Stop") }) })
  SessionEnd   = @(@{ hooks = @(@{ type = "command"; command = (Cmd "sync.ps1" "-Origem SessionEnd -Worker"); timeout = 60 }) })
  PreToolUse   = @(@{ matcher = "Bash|PowerShell|Write|Edit|MultiEdit"; hooks = @(@{ type = "command"; command = (Cmd "guarda.ps1"); timeout = 15 }) })
}
$settingsArq = Join-Path $ClaudeDir "settings.json"
$settings = $null
if (Test-Path $settingsArq) { $settings = [System.IO.File]::ReadAllText($settingsArq) | ConvertFrom-Json }
if ($settings -and $settings.PSObject.Properties["hooks"]) {
  $snip = Join-Path $Destino "settings.hooks.json"
  [System.IO.File]::WriteAllText($snip, (@{ hooks = $hooks } | ConvertTo-Json -Depth 10), $Utf8SemBom)
  Aviso "settings.json já tem hooks. Mescle à mão (ou peça ao Claude) o conteúdo de $snip"
} else {
  if (-not $settings) { $settings = New-Object PSObject }
  $settings | Add-Member -NotePropertyName hooks -NotePropertyValue $hooks -Force
  if (Test-Path $settingsArq) { Copy-Item $settingsArq "$settingsArq.bak-cerebro" }
  [System.IO.File]::WriteAllText($settingsArq, ($settings | ConvertTo-Json -Depth 10), $Utf8SemBom)
  Passo "hooks ligados em $settingsArq (backup em settings.json.bak-cerebro, se existia)"
}

# 5. Trecho no CLAUDE.md global
$globalMd = Join-Path $ClaudeDir "CLAUDE.md"
$marca = "<!-- cerebro-trabalho -->"
$trecho = ([System.IO.File]::ReadAllText((Join-Path $Kit "claude\CLAUDE.global.md"))) -replace '\{\{VAULT\}\}', $Vault
$atual = ""; if (Test-Path $globalMd) { $atual = [System.IO.File]::ReadAllText($globalMd) }
if ($atual -notmatch [regex]::Escape($marca)) {
  [System.IO.File]::WriteAllText($globalMd, ($atual.TrimEnd() + "`r`n`r`n" + $marca + "`r`n" + $trecho), $Utf8SemBom)
  Passo "regras globais adicionadas em $globalMd"
}

# 6. Agendamento
if (-not $SemAgendar) {
  $dias = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
  $loops = @(
    @{ Nome = "Cerebro - Reflexao"; Script = "loop-reflexao.ps1"; Gatilho = (New-ScheduledTaskTrigger -Weekly -DaysOfWeek $dias -At "18:00") },
    @{ Nome = "Cerebro - Noturno";  Script = "loop-noturno.ps1";  Gatilho = (New-ScheduledTaskTrigger -Weekly -DaysOfWeek $dias -At "19:00") },
    @{ Nome = "Cerebro - Executor"; Script = "executor.ps1";      Gatilho = (New-ScheduledTaskTrigger -Weekly -DaysOfWeek $dias -At "20:00") },
    @{ Nome = "Cerebro - Semanal";  Script = "loop-semanal.ps1";  Gatilho = (New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At "17:00") }
  )
  $conf = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 3)
  foreach ($l in $loops) {
    try {
      $acao = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Destino\$($l.Script)`""
      Register-ScheduledTask -TaskName $l.Nome -Action $acao -Trigger $l.Gatilho -Settings $conf -Force | Out-Null
      Passo "agendado: $($l.Nome)"
    } catch {
      Aviso "não consegui agendar $($l.Nome) ($($_.Exception.Message)). Rode na mão: powershell -File `"$Destino\$($l.Script)`""
    }
  }
  Aviso "O executor autônomo fica DESLIGADO até você editar $Vault\config\autonomia.json."
}

Write-Host ""
Write-Host "Pronto. Próximos passos:" -ForegroundColor Green
Write-Host "  1. Crie um repositório PRIVADO e rode: git -C `"$Vault`" remote add origin <url>; git -C `"$Vault`" push -u origin main"
Write-Host "  2. Abra $Vault no Obsidian (Open folder as vault)."
Write-Host "  3. Abra o Claude Code e peça: 'confere a instalação do cérebro seguindo o AGENTS.md do kit'."
