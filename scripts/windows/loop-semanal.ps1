# Loop semanal (reconciliação + retrospectiva). Sexta, 17h.
# Roda o lint, junta métricas e histórico do git e pede o resumo da semana com correções sugeridas.
param([switch]$ComEvals)
$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "lib.ps1")
if (-not (Enter-Trava "semanal")) { Write-CerebroLog "Semanal" "já rodando"; exit 0 }
try {
  if ($ComEvals) { & (Join-Path $PSScriptRoot "evals.ps1") | Out-Null }

  $lint = (& (Join-Path $PSScriptRoot "lint.ps1") | Out-String)
  $git = (git -C $Vault log --since="7 days ago" --name-status --pretty="format:%ad %s" --date=short 2>$null | Select-Object -First 300) -join "`n"
  $metricas = ""
  $csv = Join-Path $Vault "propostas\metricas.csv"
  if (Test-Path $csv) {
    $linhas = Import-Csv $csv | Where-Object { try { [datetime]::Parse($_.data) -gt (Get-Date).AddDays(-28) } catch { $false } }
    $metricas = ($linhas | Group-Object resultado | ForEach-Object { "$($_.Name): $($_.Count)" }) -join ", "
  }
  $evalsCsv = Join-Path $Vault "evals\historico.csv"
  $evals = ""
  if (Test-Path $evalsCsv) { $evals = ((Get-Content -Encoding UTF8 $evalsCsv) | Select-Object -Last 40) -join "`n" }

  $prompt = (Get-Prompt "semanal") + "`n`n# Data de hoje: $((Get-Date).ToString('yyyy-MM-dd'))`n`n" +
    "# Relatório do lint`n`n$lint`n`n# Mudanças no vault nos últimos 7 dias`n`n" + '```text' + "`n$git`n" + '```' + "`n`n" +
    "# Propostas nas últimas 4 semanas (por resultado)`n`n$(if ($metricas) { $metricas } else { '(sem métricas ainda)' })`n`n" +
    "# Últimos resultados de evals`n`n``````text`n$(if ($evals) { $evals } else { '(nenhum)' })`n``````"

  $saida = Invoke-Claude -Prompt $prompt -MaxTurnos 40
  Save-Proposta "semanal" $saida | Out-Null
  Sync-Vault "Loop"
} finally { Exit-Trava "semanal" }
