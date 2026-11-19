# Executor autônomo (camada 5). Pega tarefas com status "pronta" em tarefas/ e executa cada uma
# num git worktree isolado, com o ciclo:
#   implementar -> verificar (comando objetivo, fora do modelo) -> corrigir (até N tentativas)
#   -> revisor independente (outro claude, só leitura) -> relatório + retro -> status "revisar"
# Nunca faz merge. Push da branch + PR em rascunho só no nível 2.
# Liga/desliga e limites em <vault>\config\cerebro.json  ("executor.ativo": true).
param([string]$Tarefa = "", [switch]$Simular)
$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "lib.ps1")

$cfgArq = Join-Path $Vault "config\cerebro.json"
if (-not (Test-Path $cfgArq)) { Write-CerebroLog "Executor" "sem config/cerebro.json"; exit 0 }
$cfg = (Read-Arquivo $cfgArq) | ConvertFrom-Json
if (-not $cfg.executor.ativo -and -not $Tarefa) { Write-CerebroLog "Executor" "desligado (executor.ativo=false)"; exit 0 }
if (-not (Enter-Trava "executor")) { Write-CerebroLog "Executor" "já rodando"; exit 0 }

function Set-Status([string]$Arq, [string]$Status) {
  $t = Read-Arquivo $Arq
  Write-Arquivo $Arq (Set-CampoFrontmatter $t "status" $Status)
}
function Add-Secao([string]$Arq, [string]$Texto) {
  Write-Arquivo $Arq ((Read-Arquivo $Arq).TrimEnd() + "`n`n" + $Texto.Trim() + "`n")
}
function Invoke-Verificacao([string]$Dir, [string]$Comando) {
  if (-not $Comando) { return @{ ok = $true; saida = "(sem comando de verificação configurado)" } }
  Push-Location $Dir
  try {
    $out = cmd /c "$Comando 2>&1" | Out-String
    $ok = ($LASTEXITCODE -eq 0)
  } finally { Pop-Location }
  if ($out.Length -gt 8000) { $out = "..." + $out.Substring($out.Length - 8000) }
  return @{ ok = $ok; saida = $out }
}

try {
  $arquivos = @(Get-ChildItem (Join-Path $Vault "tarefas") -Filter *.md | Where-Object { $_.Name -ne "README.md" } | Sort-Object Name)
  if ($Tarefa) { $arquivos = @($arquivos | Where-Object { $_.BaseName -eq $Tarefa }) }
  else { $arquivos = @($arquivos | Where-Object { (Get-Frontmatter (Read-Arquivo $_.FullName))["status"] -eq "pronta" }) }
  $max = [int]$cfg.executor.max_tarefas_por_rodada; if ($max -lt 1) { $max = 1 }
  $arquivos = @($arquivos | Select-Object -First $max)
  if ($arquivos.Count -eq 0) { Write-CerebroLog "Executor" "nenhuma tarefa pronta"; exit 0 }

  $resumo = @()
  foreach ($f in $arquivos) {
    $arq = $f.FullName; $slug = $f.BaseName
    $texto = Read-Arquivo $arq
    $fm = Get-Frontmatter $texto
    $repoNome = $fm["repo"]
    $repo = $cfg.repos.$repoNome
    if (-not $repo) {
      Set-Status $arq "bloqueada"; Add-Secao $arq "## Relatório do executor ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))`nRepo ``$repoNome`` não está na lista de config/cerebro.json."
      $resumo += "- [[$slug]]: bloqueada (repo fora da lista)"; continue
    }
    $nivel = [Math]::Min([int]$repo.nivel, [int]$(if ($fm["nivel"]) { $fm["nivel"] } else { $repo.nivel }))
    $caminho = $repo.caminho; $base = $repo.branch_base; if (-not $base) { $base = "main" }
    if (-not (Test-Path (Join-Path $caminho ".git"))) {
      Set-Status $arq "bloqueada"; Add-Secao $arq "## Relatório do executor`nCaminho ``$caminho`` não é um repositório git."
      $resumo += "- [[$slug]]: bloqueada (caminho inválido)"; continue
    }
    if ($Simular) { $resumo += "- [[$slug]]: simulação, nível $nivel em $caminho"; continue }

    Set-Status $arq "fazendo"
    Write-CerebroLog "Executor" "início $slug (nível $nivel)"
    $branch = "agente/$slug"
    $wt = Join-Path $State "worktrees\$slug"
    git -C $caminho fetch -q origin $base 2>$null
    $ref = "origin/$base"; git -C $caminho rev-parse -q --verify $ref 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { $ref = $base }
    if (Test-Path $wt) { git -C $caminho worktree remove --force $wt 2>$null }
    git -C $caminho worktree add -q -B $branch $wt $ref 2>&1 | Add-Content -Encoding UTF8 $Log

    $permitidos = @("Read", "Edit", "Write", "Grep", "Glob")
    foreach ($c in $repo.comandos_permitidos) { $permitidos += "Bash($c" + ":*)" }
    $allowed = $permitidos -join ","
    $tools = "Read,Edit,Write,Grep,Glob,Bash"
    if ($nivel -eq 0) { $tools = "Read,Grep,Glob"; $allowed = "" }

    $contexto = "# Tarefa ($slug)`n`n$texto`n`n# Ambiente`n- Diretório de trabalho: worktree isolado na branch ``$branch`` (base ``$ref``).`n" +
      "- Nível de autonomia: $nivel.`n- Comando de verificação que será rodado depois de você: ``$($repo.verificar)``.`n" +
      "- Comandos de terminal permitidos: $($repo.comandos_permitidos -join ', ').`n- O vault (só leitura) está em $Vault; leia memory/MEMORY.md e a nota do projeto se existir."

    $tentativas = [int]$cfg.executor.tentativas; if ($tentativas -lt 1) { $tentativas = 2 }
    $verif = @{ ok = $false; saida = "" }; $saidaAgente = ""; $feedback = ""
    for ($i = 1; $i -le $tentativas; $i++) {
      $p = (Get-Prompt "executor") + "`n`n" + $contexto
      if ($feedback) { $p += "`n`n# Tentativa $i: a verificação anterior falhou`n`n``````text`n$feedback`n```````n`nCorrija a causa (não o teste) e rode a verificação de novo." }
      $saidaAgente = Invoke-Claude -Prompt $p -Tools $tools -Allowed $allowed -Dir $wt -MaxTurnos ([int]$cfg.executor.max_turnos) -AddDir @($Vault)
      if ($nivel -eq 0) { $verif = @{ ok = $true; saida = "(nível 0: só plano)" }; break }
      if (git -C $wt status --porcelain) {
        git -C $wt add -A; git -C $wt commit -q -m "agente: $slug (tentativa $i)" 2>&1 | Out-Null
      }
      $verif = Invoke-Verificacao $wt $repo.verificar
      if ($verif.ok) { break }
      $feedback = $verif.saida
    }

    $diff = (git -C $wt diff "$ref...HEAD" 2>$null | Out-String)
    $stat = (git -C $wt diff --stat "$ref...HEAD" 2>$null | Out-String).Trim()
    if ($diff.Length -gt 60000) { $diff = $diff.Substring(0, 60000) + "`n(diff cortado)" }

    $veredito = "sem mudanças"; $revisao = ""
    if ($diff.Trim()) {
      $pr = (Get-Prompt "revisor") + "`n`n# Tarefa`n`n$texto`n`n# Verificação: $(if ($verif.ok) { 'passou' } else { 'FALHOU' })`n`n```````n$($verif.saida)`n```````n`n# Diff`n`n``````diff`n$diff`n``````"
      $revisao = Invoke-Claude -Prompt $pr -Dir $wt -MaxTurnos 25
      $m = [regex]::Match($revisao, 'VEREDITO:\s*(aprovar|ajustar|bloquear)')
      if ($m.Success) { $veredito = $m.Groups[1].Value } else { $veredito = "ajustar" }
    }

    $link = ""
    if ($nivel -ge 2 -and $verif.ok -and $veredito -eq "aprovar") {
      git -C $wt push -q -u origin $branch 2>&1 | Add-Content -Encoding UTF8 $Log
      if ($LASTEXITCODE -eq 0 -and (Get-Command gh -ErrorAction SilentlyContinue)) {
        Push-Location $wt
        $link = (gh pr create --draft --base $base --head $branch --title "agente: $slug" --body "Tarefa feita pelo executor autônomo. Relatório no cérebro: tarefas/$slug.md" 2>>$Log | Out-String).Trim()
        Pop-Location
      }
    }

    $novoStatus = "revisar"
    if (-not $verif.ok -or $veredito -eq "bloquear") { $novoStatus = "bloqueada" }
    Set-Status $arq $novoStatus
    $rel = "## Relatório do executor ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))`n`n" +
      "- **Branch:** ``$branch`` (worktree em ``$wt``)`n- **Verificação:** $(if ($verif.ok) { 'passou' } else { 'falhou' }) após $([Math]::Min($i, $tentativas)) tentativa(s)`n" +
      "- **Revisor:** $veredito`n$(if ($link) { "- **PR (rascunho):** $link`n" })`n### Arquivos`n``````text`n$stat`n```````n`n" +
      "### O que o agente disse`n$saidaAgente`n`n### Revisão independente`n$revisao`n`n" +
      "### Verificação`n``````text`n$($verif.saida)`n``````"
    Add-Secao $arq (Hide-Segredos $rel)
    Write-CerebroLog "Executor" "fim $slug -> $novoStatus ($veredito)"
    $resumo += "- [[$slug]]: **$novoStatus**, verificação $(if ($verif.ok) { 'ok' } else { 'falhou' }), revisor: $veredito"
  }

  $prop = "# Executor autônomo: $(Get-Date -Format 'yyyy-MM-dd')`n`n## P1 · Revisar tarefas feitas por agente`n- **Status:** pendente`n- **Tipo:** revisão de tarefa`n" +
    "- **Por quê:** o executor terminou estas tarefas e nada foi mesclado.`n- **Mudança:** abrir cada tarefa, ler o relatório, testar a branch e decidir: mesclar (você), pedir ajuste (status pronta de novo, com nota) ou descartar.`n`n" + ($resumo -join "`n")
  Save-Proposta "executor" $prop | Out-Null
  Sync-Vault "Loop"
} finally { Exit-Trava "executor" }
