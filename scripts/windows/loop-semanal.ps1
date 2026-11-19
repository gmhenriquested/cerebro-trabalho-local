# Loop semanal (reconciliação + retrospectiva). Sexta, 17h.
# Roda o lint, junta métricas, histórico do git e o que foi aplicado sozinho; conserta o que é
# de baixo risco e escreve o resumo da semana com o resto como proposta.
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

  $auto = ""
  foreach ($f in (Get-ChildItem (Join-Path $Vault "propostas") -Filter *.md | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) })) {
    $m = [regex]::Match((Read-Arquivo $f.FullName), '(?s)## Aplicado automaticamente.*?(?=\n## |\z)')
    if ($m.Success) { $auto += "### $($f.Name)`n$($m.Value)`n`n" }
  }
  $prompt = (Get-Prompt "semanal") + "`n`n# Data de hoje: $((Get-Date).ToString('yyyy-MM-dd'))`n`n" +
    "# Relatório do lint`n`n$lint`n`n# Mudanças no vault nos últimos 7 dias`n`n" + '```text' + "`n$git`n" + '```' + "`n`n" +
    "# Propostas nas últimas 4 semanas (por resultado)`n`n$(if ($metricas) { $metricas } else { '(sem métricas ainda)' })`n`n" +
    "# O que foi aplicado automaticamente na semana`n`n$(if ($auto) { $auto } else { '(nada)' })`n`n" +
    "# Últimos resultados de evals`n`n``````text`n$(if ($evals) { $evals } else { '(nenhum)' })`n``````"

  $saida = Invoke-Claude -Prompt $prompt -Tools "Read,Grep,Glob,Edit,Write" -Escrita -MaxTurnos 80
  Save-Proposta "semanal" $saida | Out-Null
  Sync-Vault "Loop"
} finally { Exit-Trava "semanal" }
