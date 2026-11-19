# Colhedor: guarda no vault o que importa da conversa, em segundo plano, sem interromper.
#
# Como hook (Stop, PreCompact, SessionEnd) ele só decide se é hora e dispara um worker escondido:
#   - a cada N turnos (config colhedor.a_cada_turnos, padrão 8);
#   - ou se passaram colhedor.minutos_minimos desde a última colheita e houve pelo menos 3 turnos;
#   - sempre no PreCompact e no SessionEnd.
# O worker lê só o trecho novo da conversa, chama o Claude com escrita automática de baixo risco
# (a guarda limita onde) e grava um relatório em propostas/ com o que aplicou e o que propõe.
param(
  [string]$Evento = "",
  [switch]$Worker,
  [string]$Transcript = "",
  [string]$Sessao = "",
  [string]$Pasta = ""
)
$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "lib.ps1")

# ---------------------------------------------------------------- modo hook (rápido)
if (-not $Worker) {
  $entrada = Read-EntradaHook
  if ($env:CEREBRO_LOOP -eq "1") { exit 0 }
  $cfg = Get-ConfigCerebro
  if ($cfg.colhedor -and $cfg.colhedor.ativo -eq $false) { exit 0 }
  try { $j = $entrada | ConvertFrom-Json } catch { exit 0 }
  $sid = [string]$j.session_id; $tp = [string]$j.transcript_path
  if (-not $sid -or -not $tp -or -not (Test-Path $tp)) { exit 0 }
  if (-not $Evento) { $Evento = [string]$j.hook_event_name }

  $limite = 8; $minutos = 20
  if ($cfg.colhedor.a_cada_turnos) { $limite = [int]$cfg.colhedor.a_cada_turnos }
  if ($cfg.colhedor.minutos_minimos) { $minutos = [int]$cfg.colhedor.minutos_minimos }

  # contador de turnos e hora da última colheita (arquivo do hook); offset é do worker
  $contArq = Join-Path $State "colhedor-$sid.turnos"
  $turnos = 0; $ultima = Get-Date
  if (Test-Path $contArq) {
    $partes = (Read-Arquivo $contArq).Trim() -split '\|'
    $turnos = [int]$partes[0]
    if ($partes.Count -gt 1) { try { $ultima = [datetime]::Parse($partes[1]) } catch {} }
  }
  if ($Evento -eq "Stop") { $turnos++ }

  $offset = 0L
  $offArq = Join-Path $State "colhedor-$sid.offset"
  if (Test-Path $offArq) { try { $offset = [long]((Read-Arquivo $offArq).Trim()) } catch {} }
  $novoBytes = (Get-Item $tp).Length - $offset

  $disparar = ($Evento -in @("PreCompact", "SessionEnd")) -or ($turnos -ge $limite) -or
              ($turnos -ge 3 -and ((Get-Date) - $ultima).TotalMinutes -ge $minutos)
  if ($novoBytes -lt 3000) { $disparar = $false }
  # teto diário de colheitas (config colhedor.max_por_dia, padrão 30)
  $maxDia = 30; if ($cfg.colhedor.max_por_dia) { $maxDia = [int]$cfg.colhedor.max_por_dia }
  $diaArq = Join-Path $State ("colhedor-dia-" + (Get-Date -Format "yyyy-MM-dd"))
  $hojeN = 0; if (Test-Path $diaArq) { $hojeN = [int](Read-Arquivo $diaArq).Trim() }
  if ($disparar -and $hojeN -ge $maxDia) { $disparar = $false; Write-CerebroLog "Colhedor" "teto diário atingido" }
  if ($disparar) { Write-Arquivo $diaArq ("{0}" -f ($hojeN + 1)) }

  if ($disparar) {
    $cwd = [string]$j.cwd
    Start-Process -WindowStyle Hidden -FilePath "powershell" -ArgumentList @(
      "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"", "-Worker",
      "-Transcript", "`"$tp`"", "-Sessao", $sid, "-Evento", $Evento, "-Pasta", "`"$cwd`""
    )
    $turnos = 0; $ultima = Get-Date
  }
  Write-Arquivo $contArq ("{0}|{1}" -f $turnos, $ultima.ToString("o"))
  # .turnos velhos saem em 7 dias; .offset fica 90 dias (sessão retomada não é relida do zero)
  Get-ChildItem $State -Filter "colhedor-*.turnos" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | Remove-Item -Force
  Get-ChildItem $State -Filter "colhedor-*.offset" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-90) } | Remove-Item -Force
  exit 0
}

# ---------------------------------------------------------------- modo worker (em segundo plano)
$trava = "colhedor-$Sessao"
if (-not (Enter-Trava $trava)) { exit 0 }
try {
  $offArq = Join-Path $State "colhedor-$Sessao.offset"
  $offset = 0L
  if (Test-Path $offArq) { try { $offset = [long]((Read-Arquivo $offArq).Trim()) } catch {} }

  $fs = [System.IO.File]::Open($Transcript, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
  try {
    if ($offset -gt $fs.Length) { $offset = 0 }
    [void]$fs.Seek($offset, [System.IO.SeekOrigin]::Begin)
    $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
    $novo = $sr.ReadToEnd()
    $fim = $fs.Position
  } finally { $fs.Close() }

  $pular = @("<command-", "<local-command", "<system-reminder>", "Caveat:", "[Request interrupted",
             "<task-notification", "<bash-", "<agent-message", "Stop hook feedback")
  $sb = New-Object System.Text.StringBuilder
  $falasDono = 0
  foreach ($linha in ($novo -split "`n")) {
    if (-not $linha.Trim()) { continue }
    try { $d = $linha | ConvertFrom-Json } catch { continue }
    if ($d.isMeta -or $d.isSidechain -or $d.isCompactSummary) { continue }
    $c = $d.message.content
    $texto = ""
    if ($c -is [string]) { $texto = $c }
    elseif ($c -is [System.Array]) { $texto = (($c | Where-Object { $_.type -eq "text" } | ForEach-Object { $_.text }) -join "`n") }
    $texto = $texto.Trim()
    if (-not $texto) { continue }
    if ($d.type -eq "user") {
      $ignorar = $false
      foreach ($p in $pular) { if ($texto.StartsWith($p)) { $ignorar = $true; break } }
      if ($ignorar) { continue }
      if ($texto.Length -gt 2000) { $texto = $texto.Substring(0, 2000) + "..." }
      [void]$sb.AppendLine("**Dono:** $texto`n"); $falasDono++
    } elseif ($d.type -eq "assistant") {
      if ($texto.Length -gt 1500) { $texto = $texto.Substring(0, 1500) + "..." }
      [void]$sb.AppendLine("**Claude:** $texto`n")
    }
  }

  if ($falasDono -eq 0) { Write-Arquivo $offArq "$fim"; exit 0 }
  $conversa = Hide-Segredos $sb.ToString()
  if ($conversa.Length -gt 50000) { $conversa = "(início cortado)`n" + $conversa.Substring($conversa.Length - 50000) }

  $prompt = (Get-Prompt "colhedor") + "`n`n# Data de hoje: $((Get-Date).ToString('yyyy-MM-dd'))`n" +
    "# Sessão: $($Sessao.Substring(0, [Math]::Min(8, $Sessao.Length))) | pasta da sessão: $Pasta | gatilho: $Evento`n`n" +
    "# Trecho novo da conversa`n`n$conversa"
  $saida = Invoke-Claude -Prompt $prompt -Papel "colhedor" -Tools "Read,Grep,Glob,Edit,Write" -Raizes @($Vault) -Escrita -MaxTurnos 40
  if (-not $saida) { Write-CerebroLog "Colhedor" "claude falhou; o trecho fica para a próxima colheita"; exit 0 }
  Save-Resultado ("colhedor-" + $Sessao.Substring(0, [Math]::Min(8, $Sessao.Length))) $saida | Out-Null
  Write-Arquivo $offArq "$fim"
  Sync-Vault "Colhedor"
} finally { Exit-Trava $trava }
