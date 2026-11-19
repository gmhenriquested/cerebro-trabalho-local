# Evals: correções viram casos de teste; também escolhem o modelo mais barato que dá conta.
# Casos em <vault>\evals\casos\*.md com frontmatter "alvo:" (agente em ~/.claude/agents, ou "geral")
# e as seções "## Entrada" e "## Critérios".
#
# Barato por desenho:
#  - CACHE: nota guardada por (caso, versão do agente, modelo). Sem mudança, não roda de novo
#    (validade em config evals.validade_dias, padrão 30).
#  - CASCATA: testa o modelo atual; se passa, tenta só os mais baratos (do mais barato para cima)
#    e para no primeiro que passa; se falha, sobe até o primeiro que passa.
#  - TETO: no máximo evals.max_chamadas por rodada (cada caso = 1 execução + 1 juiz).
#  - MOTIVO (-Auto, usado pelo semanal): só avalia agente cuja versão mudou ou cujo cache venceu.
# Resultado: evals\historico.csv, evals\resultados\AAAA-MM-DD.md e, se valer trocar de modelo,
# uma proposta (tipo "modelo") para a revisão de um clique.
param([string]$Filtro = "", [switch]$Auto, [switch]$SemCascata)
$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "lib.ps1")
if (-not (Enter-Trava "evals")) { Write-CerebroLog "Evals" "já rodando"; exit 0 }
try {
  $cfg = Get-ConfigCerebro
  $notaMin = 8.0; $maxCham = 40; $validade = 30
  if ($cfg.evals) {
    if ($cfg.evals.nota_minima) { $notaMin = [double]$cfg.evals.nota_minima }
    if ($cfg.evals.max_chamadas) { $maxCham = [int]$cfg.evals.max_chamadas }
    if ($cfg.evals.validade_dias) { $validade = [int]$cfg.evals.validade_dias }
  }
  $escada = @("haiku", "sonnet", "opus")
  if ($cfg.modelos -and $cfg.modelos.escada) { $escada = @($cfg.modelos.escada) }

  $casos = @(Get-ChildItem (Join-Path $Vault "evals\casos") -Filter *.md | Where-Object { $_.Name -ne "README.md" -and $_.BaseName -like "*$Filtro*" })
  if ($casos.Count -eq 0) { Write-Output "Nenhum caso em evals\casos."; exit 0 }

  $csv = Join-Path $Vault "evals\historico.csv"
  if (-not (Test-Path $csv)) { Write-Arquivo $csv "data,caso,alvo,versao,modelo,nota`n" }
  $hist = @(Import-Csv $csv)
  $hoje = Get-Date -Format "yyyy-MM-dd"
  $script:chamadas = 0
  $novas = New-Object System.Collections.Generic.List[string]
  $relatorio = "# Evals $hoje`n`nNota mínima: $notaMin. Teto: $maxCham chamadas.`n`n| Alvo | Modelo | Nota média | Casos | Origem |`n|---|---|---|---|---|`n"
  $propostas = @()

  function Get-Cache([string]$Caso, [string]$Versao, [string]$Mod) {
    $r = $hist | Where-Object { $_.caso -eq $Caso -and $_.versao -eq $Versao -and $_.modelo -eq $Mod } |
      Where-Object { try { [datetime]::Parse($_.data) -gt (Get-Date).AddDays(-$validade) } catch { $false } } |
      Select-Object -Last 1
    if ($r -and $r.nota -ne "?") { return [double]::Parse($r.nota, [Globalization.CultureInfo]::InvariantCulture) }
    return $null
  }

  # Roda um caso num modelo. Devolve a nota (0-10) ou $null se estourou o teto.
  function Invoke-Caso($Caso, [string]$Alvo, [string]$AgenteTxt, [string]$Mod) {
    if ($script:chamadas + 2 -gt $maxCham) { return $null }
    $txt = Read-Arquivo $Caso.FullName
    $entrada = [regex]::Match($txt, '(?s)## Entrada\s*(.*?)(?=\r?\n## |\z)').Groups[1].Value.Trim()
    $criterios = [regex]::Match($txt, '(?s)## Crit[ée]rios\s*(.*?)(?=\r?\n## |\z)').Groups[1].Value.Trim()
    $script:chamadas += 2
    if ($Alvo -ne "geral" -and $AgenteTxt) {
      # O agente roda como de verdade (--agent), numa pasta de projeto temporária com o modelo trocado.
      $dir = Join-Path $State "evals-run\$Alvo-$Mod"
      Write-Arquivo (Join-Path $dir ".claude\agents\$Alvo.md") (Set-CampoFrontmatter $AgenteTxt "model" $Mod)
      $fmA = Get-Frontmatter $AgenteTxt
      $tools = "Read,Grep,Glob"; if ($fmA -and $fmA["tools"]) { $tools = ($fmA["tools"] -replace '\s', '') }
      $resp = Invoke-Claude -Prompt $entrada -Papel "eval-$Alvo" -Modelo $Mod -Agente $Alvo -Tools $tools -Dir $dir -Raizes @($dir) -MaxTurnos 20
    } else {
      $resp = Invoke-Claude -Prompt $entrada -Papel "eval-geral" -Modelo $Mod -MaxTurnos 20
    }
    $juiz = (Get-Prompt "juiz") + "`n`n# Critérios`n`n$criterios`n`n# Pedido`n`n$entrada`n`n# Resposta avaliada`n`n$resp"
    $v = Invoke-Claude -Prompt $juiz -Papel "juiz" -Tools "Read" -MaxTurnos 3
    $nota = [regex]::Match($v, 'NOTA:\s*\**\s*(\d+(?:[.,]\d+)?)').Groups[1].Value -replace ',', '.'
    if (-not $nota) { return 0.0 }
    return [double]::Parse($nota, [Globalization.CultureInfo]::InvariantCulture)
  }

  # Nota média de um alvo num modelo (cache primeiro). $null = sem orçamento.
  function Get-NotaAlvo([string]$Alvo, $CasosAlvo, [string]$AgenteTxt, [string]$Versao, [string]$Mod) {
    $soma = 0.0; $origem = "cache"
    foreach ($c in $CasosAlvo) {
      $n = Get-Cache $c.BaseName $Versao $Mod
      if ($null -eq $n) {
        $n = Invoke-Caso $c $Alvo $AgenteTxt $Mod
        if ($null -eq $n) { return $null }
        $origem = "rodado"
        $novas.Add(("{0},{1},{2},{3},{4},{5}" -f $hoje, $c.BaseName, $Alvo, $Versao, $Mod, $n.ToString([Globalization.CultureInfo]::InvariantCulture)))
      }
      $soma += $n
    }
    $media = [Math]::Round($soma / $CasosAlvo.Count, 1)
    $script:relatorio += "| $Alvo | $Mod | $media | $($CasosAlvo.Count) | $origem |`n"
    return $media
  }

  foreach ($grupo in ($casos | Group-Object { $fm = Get-Frontmatter (Read-Arquivo $_.FullName); if ($fm -and $fm["alvo"]) { $fm["alvo"] } else { "geral" } })) {
    $alvo = $grupo.Name; $casosAlvo = @($grupo.Group)
    $agenteArq = Join-Path $HOME ".claude\agents\$alvo.md"
    $agenteTxt = ""; $versao = "-"
    if ($alvo -ne "geral" -and (Test-Path $agenteArq)) {
      $agenteTxt = Read-Arquivo $agenteArq
      $semModelo = [regex]::Replace($agenteTxt, '(?m)^model:[^\r\n]*', '')
      $sha = [System.Security.Cryptography.SHA256]::Create()
      $versao = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($semModelo))) -replace '-', '').Substring(0, 8)
    }
    $atual = Get-ModeloPapel $alvo
    if (-not $atual) { $fmA = Get-Frontmatter $agenteTxt; if ($fmA -and $fmA["model"] -and $fmA["model"] -ne "inherit") { $atual = $fmA["model"] } }
    if (-not $atual -or $escada -notcontains $atual) { $atual = $escada[[Math]::Min(1, $escada.Count - 1)] }

    if ($Auto) {
      $temCache = $true
      foreach ($c in $casosAlvo) { if ($null -eq (Get-Cache $c.BaseName $versao $atual)) { $temCache = $false } }
      if ($temCache) { continue }   # nada mudou: sem custo
    }

    $notaAtual = Get-NotaAlvo $alvo $casosAlvo $agenteTxt $versao $atual
    if ($null -eq $notaAtual) { $relatorio += "| $alvo | $atual | (teto de chamadas) | | |`n"; continue }
    if ($SemCascata -or $alvo -eq "geral") { continue }

    $idx = [array]::IndexOf($escada, $atual)
    $escolhido = $null; $notaEscolhido = $null
    if ($notaAtual -ge $notaMin) {
      for ($k = 0; $k -lt $idx; $k++) {   # mais barato primeiro; para no primeiro que passa
        $n = Get-NotaAlvo $alvo $casosAlvo $agenteTxt $versao $escada[$k]
        if ($null -eq $n) { break }
        if ($n -ge $notaMin -and $n -ge ($notaAtual - 0.5)) { $escolhido = $escada[$k]; $notaEscolhido = $n; break }
      }
    } else {
      for ($k = $idx + 1; $k -lt $escada.Count; $k++) {   # sobe até o primeiro que passa
        $n = Get-NotaAlvo $alvo $casosAlvo $agenteTxt $versao $escada[$k]
        if ($null -eq $n) { break }
        if ($n -ge $notaMin) { $escolhido = $escada[$k]; $notaEscolhido = $n; break }
      }
      if (-not $escolhido) {
        $propostas += "## P$($propostas.Count + 1) · Agente $alvo abaixo da nota mínima`n- **Status:** pendente`n- **Tipo:** alerta`n- **Arquivo:** ~/.claude/agents/$alvo.md`n- **Por quê:** nota $notaAtual com $atual e nenhum modelo da escada passou de $notaMin. O problema é o prompt do agente ou os critérios do caso, não o modelo.`n- **Mudança:** revisar o agente e os casos em evals/casos/ com alvo $alvo."
      }
    }
    if ($escolhido -and $escolhido -ne $atual) {
      $dir = "mais barato"; if ([array]::IndexOf($escada, $escolhido) -gt $idx) { $dir = "mais forte" }
      $propostas += "## P$($propostas.Count + 1) · Trocar o modelo do agente $alvo para $escolhido ($dir)`n- **Status:** pendente`n- **Tipo:** modelo`n- **Arquivo:** config/cerebro.json`n" +
        "- **Evidência:** evals de $($hoje): $($atual) = $($notaAtual), $($escolhido) = $($notaEscolhido) (nota mínima $notaMin, $($casosAlvo.Count) caso(s)).`n" +
        "- **Por quê:** $(if ($dir -eq 'mais barato') { 'mesma qualidade por menos custo e mais velocidade' } else { 'o modelo atual não atinge a nota mínima' }).`n" +
        "- **Mudança:**`n" + '```json' + "`n""modelos"": { ""agentes"": { ""$alvo"": ""$escolhido"" } }`n" + '```' + "`nDepois de aplicar, o SessionStart atualiza o frontmatter do agente sozinho."
    }
  }

  if ($novas.Count -gt 0) { Add-Arquivo $csv (($novas -join "`n") + "`n") }
  $relatorio += "`nChamadas usadas: $($script:chamadas) de $maxCham.`n"
  Write-Arquivo (Join-Path $Vault "evals\resultados\$hoje.md") $relatorio
  if ($propostas.Count -gt 0) { Save-Resultado "evals" ("# Evals: $hoje`n`n" + ($propostas -join "`n`n")) | Out-Null }
  Write-Output $relatorio
  Write-CerebroLog "Evals" "$($script:chamadas) chamadas, $($propostas.Count) proposta(s)"
} finally { Exit-Trava "evals" }
