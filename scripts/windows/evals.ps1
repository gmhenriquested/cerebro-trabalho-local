# Evals: cada correção importante vira um caso de teste para agentes e prompts.
# Casos em <vault>\evals\casos\*.md com frontmatter "alvo:" (nome de um agente em ~/.claude/agents,
# ou "geral") e as seções "## Entrada" e "## Critérios".
# Para cada caso: roda o alvo, um juiz dá nota 0-10 por critério, grava em evals\historico.csv.
# Uso: evals.ps1 [-Filtro texto]   Rode antes e depois de mudar um agente ou prompt.
param([string]$Filtro = "")
$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "lib.ps1")
if (-not (Enter-Trava "evals")) { Write-CerebroLog "Evals" "já rodando"; exit 0 }
try {
  $casos = @(Get-ChildItem (Join-Path $Vault "evals\casos") -Filter *.md | Where-Object { $_.Name -ne "README.md" -and $_.BaseName -like "*$Filtro*" })
  if ($casos.Count -eq 0) { Write-Output "Nenhum caso em evals\casos."; exit 0 }
  $csv = Join-Path $Vault "evals\historico.csv"
  if (-not (Test-Path $csv)) { Write-Arquivo $csv "data,caso,alvo,versao,nota`n" }
  $hoje = Get-Date -Format "yyyy-MM-dd"
  $linhas = @(); $relatorio = "# Evals $hoje`n`n| Caso | Alvo | Nota | Falhas |`n|---|---|---|---|`n"

  foreach ($c in $casos) {
    $txt = Read-Arquivo $c.FullName
    $fm = Get-Frontmatter $txt
    $alvo = $fm["alvo"]; if (-not $alvo) { $alvo = "geral" }
    $entrada = [regex]::Match($txt, '(?s)## Entrada\s*(.*?)(?=\n## |\z)').Groups[1].Value.Trim()
    $criterios = [regex]::Match($txt, '(?s)## Crit[ée]rios\s*(.*?)(?=\n## |\z)').Groups[1].Value.Trim()

    $instrucoes = ""; $versao = "-"
    $agenteArq = Join-Path $HOME ".claude\agents\$alvo.md"
    if ($alvo -ne "geral" -and (Test-Path $agenteArq)) {
      $instrucoes = "Você é o agente abaixo. Siga as instruções dele.`n`n" + (Read-Arquivo $agenteArq) + "`n`n---`n`n"
      $versao = (Get-FileHash $agenteArq -Algorithm SHA256).Hash.Substring(0, 8)
    }
    $resposta = Invoke-Claude -Prompt ($instrucoes + "# Pedido`n`n$entrada") -MaxTurnos 20
    $juiz = (Get-Prompt "juiz") + "`n`n# Critérios`n`n$criterios`n`n# Pedido`n`n$entrada`n`n# Resposta avaliada`n`n$resposta"
    $veredito = Invoke-Claude -Prompt $juiz -Tools "Read" -MaxTurnos 3
    $nota = [regex]::Match($veredito, 'NOTA:\s*(\d+(?:[.,]\d+)?)').Groups[1].Value -replace ',', '.'
    if (-not $nota) { $nota = "?" }
    $falhas = ([regex]::Match($veredito, '(?s)FALHAS:\s*(.*)').Groups[1].Value -replace '\s+', ' ').Trim()
    if ($falhas.Length -gt 200) { $falhas = $falhas.Substring(0, 200) + "..." }
    $linhas += "$hoje,$($c.BaseName),$alvo,$versao,$nota"
    $relatorio += "| $($c.BaseName) | $alvo | $nota | $($falhas -replace '\|', '/') |`n"
  }
  Add-Content -Encoding UTF8 -Path $csv -Value $linhas
  Write-Arquivo (Join-Path $Vault "evals\resultados\$hoje.md") $relatorio
  Write-Output $relatorio
  Write-CerebroLog "Evals" "$($casos.Count) caso(s) avaliados"
} finally { Exit-Trava "evals" }
