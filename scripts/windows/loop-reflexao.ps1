# Loop de autoaperfeiçoamento (camada 4). Dias úteis, 18h.
# Junta: falas do dono desde a última rodada + retros das tarefas autônomas + recusas recentes
# e pede ao Claude propostas de mudança em memória, agentes, skills, prompts, CLAUDE.md e evals.
$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "lib.ps1")
if (-not (Enter-Trava "reflexao")) { Write-CerebroLog "Reflexao" "já rodando"; exit 0 }
try {
  $marca = Join-Path $State "reflexao.ultima"
  $desde = (Get-Date).AddDays(-1)
  if (Test-Path $marca) { try { $desde = [datetime]::Parse((Read-Arquivo $marca).Trim()) } catch {} }
  $agora = Get-Date

  $digest = (& (Join-Path $PSScriptRoot "digest.ps1") -Desde $desde | Out-String).Trim()

  $retros = ""
  foreach ($t in (Get-ChildItem (Join-Path $Vault "tarefas") -Filter *.md | Where-Object { $_.LastWriteTime -gt $desde })) {
    $m = [regex]::Match((Read-Arquivo $t.FullName), '(?s)## Retro.*?(?=\n## |\z)')
    if ($m.Success) { $retros += "### tarefas/$($t.Name)`n$($m.Value)`n`n" }
  }

  $recusas = ""
  foreach ($p in (Get-ChildItem (Join-Path $Vault "propostas") -Filter *.md | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-30) })) {
    foreach ($m in [regex]::Matches((Read-Arquivo $p.FullName), '(?m)^## (P\d+[^\r\n]*)\r?\n(?:[^\r\n]*\r?\n)*?- \*\*Status:\*\* (recusada[^\r\n]*)')) {
      $recusas += "- $($p.Name) / $($m.Groups[1].Value): $($m.Groups[2].Value)`n"
    }
  }

  if (-not $digest -and -not $retros) {
    Write-CerebroLog "Reflexao" "nada novo"
    Write-Arquivo $marca $agora.ToString("o"); exit 0
  }

  $prompt = (Get-Prompt "reflexao") + "`n`n# Data de hoje: $($agora.ToString('yyyy-MM-dd'))`n`n" +
    "# Conversas desde $($desde.ToString('yyyy-MM-dd HH:mm'))`n`n$digest`n`n" +
    "# Retros das tarefas autônomas`n`n$(if ($retros) { $retros } else { '(nenhuma)' })`n`n" +
    "# Propostas recusadas nos últimos 30 dias (não repita sem evidência nova)`n`n$(if ($recusas) { $recusas } else { '(nenhuma)' })"

  $claudeHome = Join-Path $HOME ".claude"
  $saida = Invoke-Claude -Prompt $prompt -AddDir @($claudeHome) -MaxTurnos 30
  Save-Proposta "reflexao" $saida | Out-Null
  Write-Arquivo $marca $agora.ToString("o")
  Sync-Vault "Loop"
} finally { Exit-Trava "reflexao" }
