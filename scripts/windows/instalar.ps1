# Instalador do cérebro (Windows PowerShell 5.1).
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\instalar.ps1 [-Vault C:\caminho] [-SemAgendar] [-Forcar]
# Nunca sobrescreve notas do vault. Agentes e skills já existentes só são trocados com -Forcar.
# Hooks existentes no settings.json são preservados: os do cérebro são acrescentados por evento.
param(
  [string]$Vault = (Join-Path $HOME "cerebro-trabalho"),
  [switch]$SemAgendar,
  [switch]$Forcar
)
$ErrorActionPreference = "Stop"
$Kit = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Vault = [System.IO.Path]::GetFullPath($Vault).TrimEnd('\')
$ClaudeDir = Join-Path $HOME ".claude"
$Destino = Join-Path $ClaudeDir "hooks\cerebro"
$Utf8SemBom = New-Object System.Text.UTF8Encoding $false
function Passo([string]$m) { Write-Host "-> $m" -ForegroundColor Cyan }
function Aviso([string]$m) { Write-Host "!! $m" -ForegroundColor Yellow }
function Aspas([string]$s) { return $s.Replace("'", "''") }

# 0. Pré-requisitos
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
  Aviso "O PowerShell está em modo restrito ($($ExecutionContext.SessionState.LanguageMode)), comum com AppLocker/WDAC. Os scripts do cérebro não vão funcionar; fale com o suporte da empresa."
  exit 1
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Aviso "git não encontrado no PATH."; exit 1 }
$claudeExe = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claudeExe) {
  foreach ($c in @((Join-Path $HOME ".local\bin\claude.exe"), (Join-Path $env:APPDATA "npm\claude.cmd"))) { if (Test-Path $c) { $claudeExe = $c } }
}
if (-not $claudeExe) { $claudeExe = "claude"; Aviso "Não achei o executável do claude; os loops vão usar 'claude' do PATH." }
$temGitBash = [bool](Get-Command bash -ErrorAction SilentlyContinue) -or (Test-Path "C:\Program Files\Git\bin\bash.exe")
if (-not $temGitBash) { Aviso "Git Bash não encontrado: o Claude Code usa a ferramenta PowerShell e o executor vai liberar comandos como PowerShell(...)." }

# 1. Vault (copia só o que falta)
Passo "Vault em $Vault"
$origemVault = Join-Path $Kit "vault"
Get-ChildItem $origemVault -Recurse -Force -File | ForEach-Object {
  $rel = $_.FullName.Substring($origemVault.Length).TrimStart('\')
  $alvo = Join-Path $Vault $rel
  if (-not (Test-Path -LiteralPath $alvo)) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $alvo) | Out-Null
    Copy-Item -LiteralPath $_.FullName $alvo
  }
}
if (-not (Test-Path (Join-Path $Vault ".git"))) {
  git -C $Vault init -q -b main
  git -C $Vault add -A
  git -C $Vault commit -q -m "Cérebro: estrutura inicial (cerebro-trabalho-local)"
  Passo "git iniciado no vault (remoto é opcional)"
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
Remove-Item (Join-Path $Destino "stop-lembrete.ps1") -Force -ErrorAction SilentlyContinue
$cfg = "# Gerado pelo instalador em $(Get-Date -Format 'yyyy-MM-dd')`r`n`$Vault = '$(Aspas $Vault)'`r`n`$ClaudeExe = '$(Aspas $claudeExe)'`r`n`$TemGitBash = `$$($temGitBash.ToString().ToLower())`r`n"
[System.IO.File]::WriteAllText((Join-Path $Destino "config.ps1"), $cfg, (New-Object System.Text.UTF8Encoding $true))
Passo "scripts em $Destino"

# 4. Hooks
$d = ($Destino -replace '\\', '/')
function Cmd([string]$Arquivo, [string]$Extra = "") { return ("powershell -NoProfile -ExecutionPolicy Bypass -File `"$d/$Arquivo`" $Extra").Trim() }
$matcherGuarda = "Bash|PowerShell|Write|Edit|MultiEdit|NotebookEdit|Read|WebSearch|WebFetch"
$grupoGuarda = @{ matcher = $matcherGuarda; hooks = @(@{ type = "command"; command = (Cmd "guarda.ps1"); timeout = 15 }) }
$hooks = [ordered]@{
  SessionStart = @(@{ hooks = @(@{ type = "command"; command = (Cmd "session-start.ps1"); timeout = 30 }) })
  Stop         = @(@{ hooks = @(@{ type = "command"; command = (Cmd "colhedor.ps1" "-Evento Stop"); timeout = 15 }, @{ type = "command"; command = (Cmd "sync.ps1" "-Origem Stop"); timeout = 15 }) })
  PreCompact   = @(@{ hooks = @(@{ type = "command"; command = (Cmd "colhedor.ps1" "-Evento PreCompact"); timeout = 15 }) })
  SessionEnd   = @(@{ hooks = @(@{ type = "command"; command = (Cmd "colhedor.ps1" "-Evento SessionEnd"); timeout = 15 }, @{ type = "command"; command = (Cmd "sync.ps1" "-Origem SessionEnd -Worker"); timeout = 60 }) })
  PreToolUse   = @($grupoGuarda)
}

# 4a. Config de segurança própria dos loops (passada com --settings): guarda + regras deny.
#     Vale mesmo que o settings.json do dono não tenha sido mesclado.
$credPath = ((Join-Path $ClaudeDir ".credentials.json") -replace '\\', '/')
$loopSettings = [ordered]@{
  permissions = @{ deny = @("Read(//$credPath)", "Edit(//$d/**)", "Write(//$d/**)", "Edit(//$(($Vault -replace '\\','/'))/config/**)", "Write(//$(($Vault -replace '\\','/'))/config/**)") }
  hooks = [ordered]@{ PreToolUse = @($grupoGuarda) }
}
[System.IO.File]::WriteAllText((Join-Path $Destino "loop-settings.json"), ($loopSettings | ConvertTo-Json -Depth 10), $Utf8SemBom)

# 4b. settings.json do dono: acrescenta os grupos do cérebro em cada evento, sem apagar nada.
$settingsArq = Join-Path $ClaudeDir "settings.json"
$settings = $null
if (Test-Path $settingsArq) {
  $settings = [System.IO.File]::ReadAllText($settingsArq) | ConvertFrom-Json
  Copy-Item $settingsArq "$settingsArq.bak-cerebro" -Force
}
if (-not $settings) { $settings = New-Object PSObject }
if (-not $settings.PSObject.Properties["hooks"]) { $settings | Add-Member -NotePropertyName hooks -NotePropertyValue (New-Object PSObject) }
foreach ($evento in $hooks.Keys) {
  $prop = $settings.hooks.PSObject.Properties[$evento]
  if (-not $prop) {
    $settings.hooks | Add-Member -NotePropertyName $evento -NotePropertyValue $hooks[$evento]
  } elseif ((($prop.Value | ConvertTo-Json -Depth 10) -notmatch 'hooks/cerebro/')) {
    $settings.hooks.$evento = @($prop.Value) + $hooks[$evento]
  } else {
    # já instalado: troca os grupos antigos do cérebro pelos novos
    $outros = @($prop.Value | Where-Object { ($_ | ConvertTo-Json -Depth 10) -notmatch 'hooks/cerebro/' })
    $settings.hooks.$evento = $outros + $hooks[$evento]
  }
}
[System.IO.File]::WriteAllText($settingsArq, ($settings | ConvertTo-Json -Depth 20), $Utf8SemBom)
Passo "hooks do cérebro mesclados em $settingsArq (backup: settings.json.bak-cerebro)"

# 5. Trecho no CLAUDE.md global
$globalMd = Join-Path $ClaudeDir "CLAUDE.md"
$marca = "<!-- cerebro-trabalho -->"
$trecho = ([System.IO.File]::ReadAllText((Join-Path $Kit "claude\CLAUDE.global.md"))) -replace '\{\{VAULT\}\}', $Vault.Replace('$', '$$')
$atual = ""; if (Test-Path $globalMd) { $atual = [System.IO.File]::ReadAllText($globalMd) }
if ($atual -notmatch [regex]::Escape($marca)) {
  [System.IO.File]::WriteAllText($globalMd, ($atual.TrimEnd() + "`r`n`r`n" + $marca + "`r`n" + $trecho), $Utf8SemBom)
  Passo "regras globais adicionadas em $globalMd"
}

# 6. Modelos dos agentes conforme config/cerebro.json
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Destino "aplicar-modelos.ps1") | Out-Null
Passo "modelos dos agentes aplicados (config/cerebro.json > modelos)"

# 7. Agendamento (cada loop também respeita config/cerebro.json > loops.<nome>.ativo)
if (-not $SemAgendar) {
  $dias = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
  $loops = @(
    @{ Nome = "Cerebro - Reflexao"; Script = "loop-reflexao.ps1"; Extra = "";          Gatilho = (New-ScheduledTaskTrigger -Weekly -DaysOfWeek $dias -At "18:00") },
    @{ Nome = "Cerebro - Noturno";  Script = "loop-noturno.ps1";  Extra = "";          Gatilho = (New-ScheduledTaskTrigger -Weekly -DaysOfWeek $dias -At "19:00") },
    @{ Nome = "Cerebro - Executor"; Script = "executor.ps1";      Extra = "";          Gatilho = (New-ScheduledTaskTrigger -Weekly -DaysOfWeek $dias -At "20:00") },
    @{ Nome = "Cerebro - Semanal";  Script = "loop-semanal.ps1";  Extra = "-ComEvals"; Gatilho = (New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At "17:00") }
  )
  $conf = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 3)
  foreach ($l in $loops) {
    try {
      $acao = New-ScheduledTaskAction -Execute "powershell.exe" -Argument ("-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Destino\$($l.Script)`" $($l.Extra)").Trim()
      Register-ScheduledTask -TaskName $l.Nome -Action $acao -Trigger $l.Gatilho -Settings $conf -Force | Out-Null
      Passo "agendado: $($l.Nome)"
    } catch {
      Aviso "não consegui agendar $($l.Nome) ($($_.Exception.Message)). Rode na mão: powershell -File `"$Destino\$($l.Script)`""
    }
  }
  Aviso "O executor autônomo fica DESLIGADO até você editar $Vault\config\cerebro.json (executor.ativo)."
}

# 8. Trava do kit público: se o kit é um clone git, todo commit nele passa pela conferência
#    dos termos internos do vault (nada da empresa vai para o repositório público).
if (Test-Path (Join-Path $Kit ".git")) {
  git -C $Kit config core.hooksPath scripts/git-hooks
  Passo "trava de termos internos ligada nos commits do kit"
}

Write-Host ""
Write-Host "Pronto. Próximos passos:" -ForegroundColor Green
Write-Host "  1. Abra $Vault no Obsidian (Open folder as vault)."
Write-Host "  2. Coloque nomes internos (clientes, projetos, sistemas) em $Vault\config\termos-internos.txt."
Write-Host "  3. (Opcional) Remoto PRIVADO para backup: git -C `"$Vault`" remote add origin <url>"
Write-Host "  4. Abra o Claude Code e peça: 'confere a instalação do cérebro seguindo o AGENTS.md do kit'."
