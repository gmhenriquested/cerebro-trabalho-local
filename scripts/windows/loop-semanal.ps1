# Loop semanal (reconciliação + retrospectiva). Sexta, 17h.
# Roda o lint, junta métricas, histórico do git e o que foi aplicado sozinho; conserta o que é
# de baixo risco e escreve o resumo da semana com o resto como proposta.
param([switch]$ComEvals)
$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "lib.ps1")
if (-not (Test-LoopAtivo "semanal")) { exit 0 }
if (-not (Enter-Trava "semanal")) { Write-CerebroLog "Semanal" "já rodando"; exit 0 }
try {
  # Evals só com motivo (agente mudou, cache vencido) e com teto de chamadas: ver evals.ps1 -Auto
  if ($ComEvals) { & (Join-Path $PSScriptRoot "evals.ps1") -Auto | Out-Null }

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
  foreach ($f in (Get-ChildItem (Join-Path $Vault "propostas") -Filter "*-auto.md" | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) })) {
    $t = Read-Arquivo $f.FullName; if ($t.Length -gt 6000) { $t = $t.Substring(0, 6000) + "..." }
    $auto += "### $($f.Name)`n$t`n`n"
  }
  # Métricas passivas (de graça): execuções e custo por papel/modelo, executor por modelo.
  $metr = ""
  $loopsCsv = Join-Path $Metricas "loops.csv"
  if (Test-Path $loopsCsv) {
    $l7 = @(Import-Csv $loopsCsv | Where-Object { try { [datetime]::Parse($_.data) -gt (Get-Date).AddDays(-7) } catch { $false } })
    $metr += ($l7 | Group-Object papel, modelo | ForEach-Object {
      $custo = ($_.Group | ForEach-Object { try { [double]::Parse($_.custo_usd, [Globalization.CultureInfo]::InvariantCulture) } catch { 0 } } | Measure-Object -Sum).Sum
      $falhas = @($_.Group | Where-Object { $_.ok -ne "True" }).Count
      "- {0}: {1} execuções, {2} falhas, US$ {3:N2}" -f $_.Name, $_.Count, $falhas, $custo
    }) -join "`n"
  }
  $execCsv = Join-Path $Metricas "executor.csv"
  if (Test-Path $execCsv) { $metr += "`n`nExecutor (últimas 20):`n" + ((Get-Content -Encoding UTF8 $execCsv | Select-Object -Last 21) -join "`n") }
  $prompt = (Get-Prompt "semanal") + "`n`n# Data de hoje: $((Get-Date).ToString('yyyy-MM-dd'))`n`n" +
    "# Relatório do lint`n`n$lint`n`n# Mudanças no vault nos últimos 7 dias`n`n" + '```text' + "`n$git`n" + '```' + "`n`n" +
    "# Métricas passivas da semana (por papel e modelo)`n`n$(if ($metr) { $metr } else { '(sem dados)' })`n`n" +
    "# Propostas nas últimas 4 semanas (por resultado)`n`n$(if ($metricas) { $metricas } else { '(sem métricas ainda)' })`n`n" +
    "# O que foi aplicado automaticamente na semana`n`n$(if ($auto) { $auto } else { '(nada)' })`n`n" +
    "# Últimos resultados de evals`n`n``````text`n$(if ($evals) { $evals } else { '(nenhum)' })`n``````"

  $saida = Invoke-Claude -Prompt $prompt -Papel "semanal" -Tools "Read,Grep,Glob,Edit,Write" -Raizes @($Vault) -Escrita -MaxTurnos 80
  Save-Resultado "semanal" $saida | Out-Null
  Sync-Vault "Loop"
} finally { Exit-Trava "semanal" }
