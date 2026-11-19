# Hook SessionStart: puxa o vault (se limpo), injeta MEMORY.md + indice.md e avisa pendências.
$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "lib.ps1")
if ([Console]::IsInputRedirected) { [void][Console]::In.ReadToEnd() }
if ($env:CEREBRO_LOOP -eq "1") { exit 0 }

if ((Test-Path (Join-Path $Vault ".git")) -and -not (git -C $Vault status --porcelain)) {
  $env:GIT_HTTP_LOW_SPEED_LIMIT = "1000"
  $env:GIT_HTTP_LOW_SPEED_TIME  = "5"
  git -C $Vault pull -q --ff-only 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) { Write-CerebroLog "SessionStart" "pull ok" }
}

Write-Output "# Cérebro de trabalho ($Vault): contexto carregado automaticamente"
Write-Output "Regras do vault em $Vault\CLAUDE.md. Memória nova vai em $Vault\memory\ (um fato por arquivo) com linha em MEMORY.md."
Write-Output ""
Write-Output (Read-Arquivo (Join-Path $Vault "memory\MEMORY.md"))
Write-Output ""
Write-Output (Read-Arquivo (Join-Path $Vault "indice.md"))

$pendentes = @(Get-PropostasPendentes)
$revisar = @(Get-ChildItem (Join-Path $Vault "tarefas") -Filter *.md -ErrorAction SilentlyContinue |
  Where-Object { $fm = Get-Frontmatter (Read-Arquivo $_.FullName); $fm -and $fm["status"] -eq "revisar" })

# Revisão de um clique: no máximo N vezes por dia o Claude oferece aprovar, numa pausa natural.
$cfg = Get-ConfigCerebro
$maxDia = 1
if ($cfg.revisao_na_sessao -and $cfg.revisao_na_sessao.max_por_dia) { $maxDia = [int]$cfg.revisao_na_sessao.max_por_dia }
$ofertaArq = Join-Path $State ("oferta-" + (Get-Date -Format "yyyy-MM-dd"))
$ofertasHoje = 0; if (Test-Path $ofertaArq) { $ofertasHoje = [int](Read-Arquivo $ofertaArq).Trim() }
$oferecer = ($pendentes.Count -gt 0) -and ($ofertasHoje -lt $maxDia) -and -not ($cfg.revisao_na_sessao -and $cfg.revisao_na_sessao.ativo -eq $false)

if ($pendentes.Count -gt 0 -or $revisar.Count -gt 0) {
  Write-Output ""
  Write-Output "## Pendências do cérebro"
  if ($revisar.Count -gt 0) { Write-Output ("- {0} tarefa(s) feitas por agente esperando revisão em tarefas/: {1}" -f $revisar.Count, (($revisar | ForEach-Object { $_.BaseName }) -join ", ")) }
  if ($oferecer) {
    Write-Arquivo $ofertaArq ("{0}" -f ($ofertasHoje + 1))
    Write-Output ("- {0} proposta(s) pendente(s) em propostas/:" -f $pendentes.Count)
    foreach ($p in ($pendentes | Select-Object -First 6)) { Write-Output ("  - {0} ({1})" -f $p.Titulo, $p.Arquivo) }
    Write-Output ""
    Write-Output "**Revisão de um clique:** quando terminar a PRIMEIRA tarefa que o dono pedir nesta sessão (nunca antes e nunca no meio de uma tarefa), ofereça numa única pergunta AskUserQuestion com multiSelect até 4 dessas propostas (as de maior valor; título + por quê em poucas palavras). Leia cada proposta antes. Aplique as escolhidas seguindo a skill revisar-propostas (passos 5 a 7: aplicar, marcar status com data, métricas). As não escolhidas ficam pendentes; se o dono ignorar ou recusar a pergunta, não insista nesta sessão."
  } elseif ($pendentes.Count -gt 0) {
    Write-Output ("- {0} proposta(s) pendente(s). Não ofereça de novo hoje; só se o dono perguntar." -f $pendentes.Count)
  }
}
exit 0
