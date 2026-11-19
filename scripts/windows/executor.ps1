# Executor autônomo (camada 5). Pega tarefas com status "pronta" em tarefas/ e executa cada uma
# num git worktree isolado (fora de ~/.claude), com o ciclo:
#   implementar (modelo do papel "executor") -> verificar (comando objetivo, fora do modelo)
#   -> corrigir com o modelo de escalada ("executor_escalar") até N tentativas
#   -> revisor independente (outro claude, só leitura) -> relatório + retro -> status
# O agente só escreve dentro do worktree (a guarda nega o resto, inclusive o vault).
# Nunca faz merge. Push da branch + PR em rascunho só no nível 2.
# Liga/desliga e limites em <vault>\config\cerebro.json ("executor.ativo": true).
param([string]$Tarefa = "", [switch]$Simular)
$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "lib.ps1")

$cfg = Get-ConfigCerebro
if (-not $cfg.executor) { Write-CerebroLog "Executor" "sem seção executor em config/cerebro.json"; exit 0 }
if (-not $cfg.executor.ativo -and -not $Tarefa) { Write-CerebroLog "Executor" "desligado (executor.ativo=false)"; exit 0 }
if (-not (Enter-Trava "executor")) { Write-CerebroLog "Executor" "já rodando"; exit 0 }

$RaizWt = Join-Path $env:LOCALAPPDATA "cerebro\worktrees"
New-Item -ItemType Directory -Force -Path $RaizWt | Out-Null
$env:GIT_TERMINAL_PROMPT = "0"

function Set-Status([string]$Arq, [string]$Status) {
  Write-Arquivo $Arq (Set-CampoFrontmatter (Read-Arquivo $Arq) "status" $Status)
}
function Add-Secao([string]$Arq, [string]$Texto) {
  Write-Arquivo $Arq ((Read-Arquivo $Arq).TrimEnd() + "`n`n" + $Texto.Trim() + "`n")
}
function Invoke-Git([string]$Dir, [string[]]$Args2) {
  $out = (& git -C $Dir @Args2 2>&1 | ForEach-Object { $_.ToString() }) -join "`n"
  if ($out) { Write-CerebroLog "Executor" ("git {0}: {1}" -f ($Args2 -join ' '), $out.Substring(0, [Math]::Min(300, $out.Length))) }
  return ($LASTEXITCODE -eq 0)
}
function Invoke-Verificacao([string]$Dir, [string]$Comando) {
  if (-not $Comando) { return @{ ok = $true; saida = "(sem comando de verificação configurado)" } }
  Push-Location -LiteralPath $Dir
  try {
    $out = (cmd /c "$Comando 2>&1" | Out-String)
    $ok = ($LASTEXITCODE -eq 0)
  } finally { Pop-Location }
  if ($out.Length -gt 8000) { $out = "..." + $out.Substring($out.Length - 8000) }
  return @{ ok = $ok; saida = (Hide-Segredos $out) }
}

try {
  $todas = @(Get-ChildItem (Join-Path $Vault "tarefas") -Filter *.md | Where-Object { $_.Name -ne "README.md" } | Sort-Object Name)

  # Limpeza sem ritual: tarefa presa em "fazendo" (o executor morreu) vira bloqueada;
  # worktree de tarefa feita ou recusada é removido.
  foreach ($t in $todas) {
    $fm = Get-Frontmatter (Read-Arquivo $t.FullName)
    if (-not $fm) { continue }
    if ($fm["status"] -eq "fazendo") {
      Set-Status $t.FullName "bloqueada"
      Add-Secao $t.FullName "## Executor ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))`nA execução anterior foi interrompida (tempo limite ou máquina desligada). Volte para ``pronta`` para tentar de novo."
    }
    if ($fm["status"] -in @("feita", "recusada") -and $fm["repo"]) {
      $wtVelho = Join-Path $RaizWt $t.BaseName
      $repoVelho = $cfg.repos.($fm["repo"])
      if ((Test-Path $wtVelho) -and $repoVelho) {
        if (Invoke-Git $repoVelho.caminho @("worktree", "remove", "--force", $wtVelho)) { Write-CerebroLog "Executor" "worktree removido: $($t.BaseName)" }
      }
    }
  }

  $fila = $todas
  if ($Tarefa) { $fila = @($fila | Where-Object { $_.BaseName -eq $Tarefa }) }
  else { $fila = @($fila | Where-Object { $f2 = Get-Frontmatter (Read-Arquivo $_.FullName); $f2 -and $f2["status"] -eq "pronta" }) }
  $max = [int]$cfg.executor.max_tarefas_por_rodada; if ($max -lt 1) { $max = 1 }
  $fila = @($fila | Select-Object -First $max)
  if ($fila.Count -eq 0) { Write-CerebroLog "Executor" "nenhuma tarefa pronta"; exit 0 }

  $resumo = @()
  foreach ($f in $fila) {
    $arq = $f.FullName; $slug = $f.BaseName
    $texto = Read-Arquivo $arq
    $fm = Get-Frontmatter $texto
    $repoNome = $fm["repo"]
    $repo = $null; if ($repoNome) { $repo = $cfg.repos.$repoNome }
    $agora = Get-Date -Format 'yyyy-MM-dd HH:mm'
    if (-not $repo) {
      Set-Status $arq "bloqueada"; Add-Secao $arq "## Relatório do executor ($agora)`nRepo ``$repoNome`` não está em config/cerebro.json > repos."
      $resumo += "- [[$slug]]: bloqueada (repo fora da lista)"; continue
    }
    $nivelTarefa = [int]$repo.nivel; if ($fm["nivel"]) { $nivelTarefa = [int]$fm["nivel"] }
    $nivel = [Math]::Min([int]$repo.nivel, $nivelTarefa)
    $caminho = [string]$repo.caminho; $base = [string]$repo.branch_base; if (-not $base) { $base = "main" }
    if (-not (Test-Path (Join-Path $caminho ".git"))) {
      Set-Status $arq "bloqueada"; Add-Secao $arq "## Relatório do executor ($agora)`nCaminho ``$caminho`` não é um repositório git."
      $resumo += "- [[$slug]]: bloqueada (caminho inválido)"; continue
    }
    if ($Simular) { $resumo += "- [[$slug]]: simulação, nível $nivel em $caminho"; continue }

    Set-Status $arq "fazendo"
    Write-CerebroLog "Executor" "início $slug (nível $nivel)"
    $branch = "agente/$slug"
    $wt = Join-Path $RaizWt $slug
    [void](Invoke-Git $caminho @("fetch", "-q", "origin", $base))
    $ref = "origin/$base"
    & git -C $caminho rev-parse -q --verify $ref 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { $ref = $base }

    # Reaproveita a branch se ela já existe (tarefa voltou para ajuste): não perde trabalho anterior.
    & git -C $caminho rev-parse -q --verify "refs/heads/$branch" 2>&1 | Out-Null
    $branchExiste = ($LASTEXITCODE -eq 0)
    $wtOk = (Test-Path (Join-Path $wt ".git"))
    if (-not $wtOk) {
      if (Test-Path $wt) { [void](Invoke-Git $caminho @("worktree", "prune")) }
      if ($branchExiste) { $wtOk = Invoke-Git $caminho @("worktree", "add", "-q", $wt, $branch) }
      else { $wtOk = Invoke-Git $caminho @("worktree", "add", "-q", "-b", $branch, $wt, $ref) }
    }
    if (-not $wtOk -or -not (Test-Path (Join-Path $wt ".git"))) {
      Set-Status $arq "bloqueada"
      Add-Secao $arq "## Relatório do executor ($agora)`nNão consegui criar o worktree ``$wt`` (branch ``$branch``). Veja cerebro.log."
      $resumo += "- [[$slug]]: bloqueada (worktree)"; continue
    }

    $permitidos = @("Read", "Edit", "Write", "Grep", "Glob")
    $tools = "Read,Edit,Write,Grep,Glob"
    if ($TemGitBash) { $tools += ",Bash"; foreach ($c in $repo.comandos_permitidos) { $permitidos += "Bash($c" + ":*)" } }
    else { $tools += ",PowerShell"; foreach ($c in $repo.comandos_permitidos) { $permitidos += "PowerShell($c" + ":*)" } }
    $allowed = $permitidos -join ","
    if ($nivel -eq 0) { $tools = "Read,Grep,Glob"; $allowed = $tools }

    # Contexto do vault vai inline: o agente não tem acesso ao vault.
    $memoria = Read-Arquivo (Join-Path $Vault "memory\MEMORY.md")
    $notaProjeto = Read-Arquivo (Join-Path $Vault "projetos\$repoNome.md")
    if ($notaProjeto.Length -gt 6000) { $notaProjeto = $notaProjeto.Substring(0, 6000) + "..." }
    $contexto = "# Tarefa ($slug)`n`n$texto`n`n# Ambiente`n- Diretório de trabalho: worktree isolado na branch ``$branch`` (base ``$ref``). Você só consegue escrever aqui.`n" +
      "- Nível de autonomia: $nivel.`n- Comando de verificação que será rodado depois de você: ``$($repo.verificar)``.`n" +
      "- Comandos de terminal permitidos: $($repo.comandos_permitidos -join ', ').`n`n" +
      "# Memória do dono (índice)`n`n$memoria`n`n# Nota do projeto no cérebro`n`n$(if ($notaProjeto) { $notaProjeto } else { '(não há)' })"

    $tentativas = [int]$cfg.executor.tentativas; if ($tentativas -lt 1) { $tentativas = 2 }
    $verif = @{ ok = $false; saida = "" }; $saidaAgente = ""; $feedback = ""; $feitas = 0; $papelUsado = "executor"
    for ($i = 1; $i -le $tentativas; $i++) {
      $feitas = $i
      $papel = "executor"; if ($i -gt 1) { $papel = "executor_escalar" }
      $papelUsado = $papel
      $p = (Get-Prompt "executor") + "`n`n" + $contexto
      if ($feedback) { $p += "`n`n# Tentativa $($i): a verificação anterior falhou`n`n" + '```text' + "`n$feedback`n" + '```' + "`n`nCorrija a causa (não o teste) e rode a verificação de novo." }
      $saidaAgente = Invoke-Claude -Prompt $p -Papel $papel -Tools $tools -Allowed $allowed -Dir $wt -Raizes @($wt) -MaxTurnos ([int]$cfg.executor.max_turnos)
      if ($nivel -eq 0) { $verif = @{ ok = $true; saida = "(nível 0: só plano)" }; break }
      if (& git -C $wt status --porcelain) {
        [void](Invoke-Git $wt @("add", "-A")); [void](Invoke-Git $wt @("commit", "-q", "-m", "agente: $slug (tentativa $i)"))
      }
      $verif = Invoke-Verificacao $wt ([string]$repo.verificar)
      if ($verif.ok) { break }
      $feedback = $verif.saida
    }

    $diff = (& git -C $wt diff "$ref...HEAD" 2>$null | Out-String)
    $stat = (& git -C $wt diff --stat "$ref...HEAD" 2>$null | Out-String).Trim()
    if ($diff.Length -gt 60000) { $diff = $diff.Substring(0, 60000) + "`n(diff cortado)" }

    $veredito = "sem mudanças"; $revisao = ""
    if ($diff.Trim()) {
      $pr = (Get-Prompt "revisor") + "`n`n# Tarefa`n`n$texto`n`n# Verificação: $(if ($verif.ok) { 'passou' } else { 'FALHOU' })`n`n" +
        '```text' + "`n$($verif.saida)`n" + '```' + "`n`n# Diff`n`n" + '```diff' + "`n$diff`n" + '```'
      $revisao = Invoke-Claude -Prompt $pr -Papel "revisor_executor" -Dir $wt -MaxTurnos 25
      $m = [regex]::Match($revisao, 'VEREDITO:\s*\**\s*(aprovar|ajustar|bloquear)')
      if ($m.Success) { $veredito = $m.Groups[1].Value } else { $veredito = "ajustar" }
    }

    $link = ""
    if ($nivel -ge 2 -and $verif.ok -and $veredito -eq "aprovar") {
      if (Invoke-Git $wt @("push", "-q", "-u", "origin", $branch)) {
        if (Get-Command gh -ErrorAction SilentlyContinue) {
          Push-Location -LiteralPath $wt
          $link = ((gh pr create --draft --base $base --head $branch --title "agente: $slug" --body "Tarefa feita pelo executor autônomo. Relatório no cérebro: tarefas/$slug.md" 2>&1) | Out-String).Trim()
          Pop-Location
        }
      }
    }

    # revisar = terminou e passou na verificação (o revisor pode ter pedido ajuste: leia o relatório)
    $novoStatus = "revisar"
    if (-not $verif.ok -or $veredito -eq "bloquear") { $novoStatus = "bloqueada" }
    Set-Status $arq $novoStatus
    $rel = "## Relatório do executor ($agora)`n`n" +
      "- **Branch:** ``$branch`` (worktree em ``$wt``)`n" +
      "- **Verificação:** $(if ($verif.ok) { 'passou' } else { 'falhou' }) após $feitas tentativa(s); modelo final: papel ``$papelUsado`` ($(Get-ModeloPapel $papelUsado))`n" +
      "- **Revisor:** $veredito`n$(if ($link) { "- **PR (rascunho):** $link`n" })`n### Arquivos`n" + '```text' + "`n$stat`n" + '```' + "`n`n" +
      "### O que o agente disse`n$saidaAgente`n`n### Revisão independente`n$revisao`n`n" +
      "### Verificação`n" + '```text' + "`n$($verif.saida)`n" + '```'
    Add-Secao $arq (Hide-Segredos $rel)
    Add-Metrica "executor.csv" "data,tarefa,repo,nivel,modelo_final,verificacao,tentativas,veredito" ("{0},{1},{2},{3},{4},{5},{6},{7}" -f $agora, $slug, $repoNome, $nivel, (Get-ModeloPapel $papelUsado), $verif.ok, $feitas, $veredito)
    Write-CerebroLog "Executor" "fim $slug -> $novoStatus ($veredito)"
    $resumo += "- [[$slug]]: **$novoStatus**, verificação $(if ($verif.ok) { 'ok' } else { 'falhou' }), revisor: $veredito"
  }

  $prop = "# Executor autônomo: $(Get-Date -Format 'yyyy-MM-dd')`n`n## P1 · Revisar tarefas feitas por agente`n- **Status:** pendente`n- **Tipo:** revisão de tarefa`n" +
    "- **Por quê:** o executor terminou estas tarefas e nada foi mesclado.`n- **Mudança:** ler o relatório no fim de cada tarefa, testar a branch e decidir: mesclar (você) e marcar ``feita``; pedir ajuste (escreva o que mudar e volte para ``pronta``: a branch é reaproveitada); ou ``recusada``. O worktree é removido sozinho depois.`n`n" + ($resumo -join "`n")
  Save-Resultado "executor" $prop | Out-Null
  Sync-Vault "Loop"
} finally { Exit-Trava "executor" }
