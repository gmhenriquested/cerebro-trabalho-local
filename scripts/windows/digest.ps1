# Extrai as falas do dono (com a fala anterior do Claude como contexto) das conversas do
# Claude Code modificadas desde uma data. Segredos são mascarados.
# Uso: digest.ps1 -Desde "2026-11-19T00:00:00"   (escreve markdown no stdout)
param([Parameter(Mandatory = $true)][datetime]$Desde, [int]$MaxChars = 60000)
$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "lib.ps1")

$pular = @("Stop hook feedback", "<command-", "<local-command", "<system-reminder>", "Caveat:",
           "[Request interrupted", "<task-notification", "<bash-", "<agent-message")

function Get-TextoConteudo($c) {
  if ($c -is [string]) { return $c }
  if ($c -is [System.Array]) {
    return (($c | Where-Object { $_.type -eq "text" } | ForEach-Object { $_.text }) -join "`n")
  }
  return ""
}

$saida = New-Object System.Text.StringBuilder
$arquivos = Get-ChildItem (Join-Path $HOME ".claude\projects") -Recurse -Filter *.jsonl -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTime -gt $Desde -and $_.FullName -notmatch '\\subagents\\' } | Sort-Object LastWriteTime

foreach ($f in $arquivos) {
  $ultimoClaude = ""
  $trechos = New-Object System.Collections.Generic.List[string]
  try { $todasLinhas = [System.IO.File]::ReadAllLines($f.FullName, [System.Text.Encoding]::UTF8) } catch { continue }
  foreach ($linha in $todasLinhas) {
    try { $d = $linha | ConvertFrom-Json } catch { continue }
    $ts = $null
    if ($d.timestamp) { try { $ts = [datetime]::Parse($d.timestamp).ToLocalTime() } catch {} }
    if ($d.type -eq "assistant") {
      $t = Get-TextoConteudo $d.message.content
      if ($t.Trim()) { $ultimoClaude = $t }
      continue
    }
    if ($d.type -ne "user" -or $d.isMeta) { continue }
    if ($ts -and $ts -lt $Desde) { continue }
    $c = (Get-TextoConteudo $d.message.content).Trim()
    if (-not $c) { continue }
    $ignorar = $false
    foreach ($p in $pular) { if ($c.StartsWith($p)) { $ignorar = $true; break } }
    if ($ignorar) { continue }
    $ctx = ($ultimoClaude -replace '\s+', ' ').Trim()
    if ($ctx.Length -gt 500) { $ctx = $ctx.Substring(0, 500) + "..." }
    if (-not $ctx) { $ctx = "(início)" }
    if ($c.Length -gt 1500) { $c = $c.Substring(0, 1500) + "..." }
    $quando = ""; if ($ts) { $quando = $ts.ToString("yyyy-MM-dd HH:mm") }
    $trechos.Add(("- **Claude antes:** {0}`n  **Dono ({1}):** {2}" -f (Hide-Segredos $ctx), $quando, (Hide-Segredos $c)))
  }
  if ($trechos.Count -gt 0) {
    $projeto = $f.Directory.Name
    [void]$saida.AppendLine(("## Sessão {0} ({1})`n" -f $f.BaseName.Substring(0, [Math]::Min(8, $f.BaseName.Length)), $projeto))
    [void]$saida.AppendLine(($trechos -join "`n"))
    [void]$saida.AppendLine("")
  }
  if ($saida.Length -gt $MaxChars) { [void]$saida.AppendLine("(cortado: limite de tamanho)"); break }
}
Write-Output $saida.ToString()
