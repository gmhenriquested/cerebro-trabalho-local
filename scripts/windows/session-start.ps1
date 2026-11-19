# Hook SessionStart: puxa o vault (se limpo), injeta pendências, memória e índice.
# A saída de hook é limitada a 10.000 caracteres: pendências vêm primeiro e o resto é cortado.
$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "lib.ps1")
[void](Read-EntradaHook)
if ($env:CEREBRO_LOOP -eq "1") { exit 0 }

if ((Test-Path (Join-Path $Vault ".git")) -and -not (git -C $Vault status --porcelain) -and (git -C $Vault remote)) {
  $env:GIT_HTTP_LOW_SPEED_LIMIT = "1000"
  $env:GIT_HTTP_LOW_SPEED_TIME  = "5"
  $env:GIT_TERMINAL_PROMPT = "0"
  git -C $Vault pull -q --ff-only 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) { Write-CerebroLog "SessionStart" "pull ok" }
}

# Modelos dos agentes seguem config/cerebro.json (sem ritual: aplica quando a config muda).
$cfgArq = Join-Path $Vault "config\cerebro.json"
$marca = Join-Path $State "modelos-aplicados"
if ((Test-Path $cfgArq) -and (-not (Test-Path $marca) -or (Get-Item $cfgArq).LastWriteTime -gt (Get-Item $marca).LastWriteTime)) {
  & (Join-Path $PSScriptRoot "aplicar-modelos.ps1") | Out-Null
}

function Limitar([string]$Texto, [int]$Max, [string]$Caminho) {
  if ($Texto.Length -le $Max) { return $Texto }
  return $Texto.Substring(0, $Max) + "`n(... cortado; leia o resto em $Caminho)"
}

Write-Output "# Cérebro ($Vault): contexto carregado automaticamente"
Write-Output "Regras em $Vault\CLAUDE.md. Um colhedor em segundo plano guarda o que importa da conversa; não interrompa o dono para salvar."

$pendentes = @(Get-PropostasPendentes)
$revisar = @(Get-ChildItem (Join-Path $Vault "tarefas") -Filter *.md -ErrorAction SilentlyContinue |
  Where-Object { $fm = Get-Frontmatter (Read-Arquivo $_.FullName); $fm -and $fm["status"] -in @("revisar", "bloqueada") })

$cfg = Get-ConfigCerebro
$maxDia = 1
if ($cfg.revisao_na_sessao -and $cfg.revisao_na_sessao.max_por_dia) { $maxDia = [int]$cfg.revisao_na_sessao.max_por_dia }
$ofertaArq = Join-Path $State ("oferta-" + (Get-Date -Format "yyyy-MM-dd"))
$ofertasHoje = 0; if (Test-Path $ofertaArq) { $ofertasHoje = [int](Read-Arquivo $ofertaArq).Trim() }
$oferecer = ($pendentes.Count -gt 0) -and ($ofertasHoje -lt $maxDia) -and -not ($cfg.revisao_na_sessao -and $cfg.revisao_na_sessao.ativo -eq $false)

if ($pendentes.Count -gt 0 -or $revisar.Count -gt 0) {
  Write-Output ""
  Write-Output "## Pendências do cérebro"
  if ($revisar.Count -gt 0) { Write-Output ("- Tarefas de agente esperando o dono em tarefas/: {0}" -f (($revisar | ForEach-Object { $_.BaseName }) -join ", ")) }
  if ($oferecer) {
    Write-Arquivo $ofertaArq ("{0}" -f ($ofertasHoje + 1))
    Write-Output ("- {0} proposta(s) pendente(s) em propostas/:" -f $pendentes.Count)
    foreach ($p in ($pendentes | Select-Object -First 6)) { Write-Output ("  - {0} [{1}] ({2})" -f $p.Titulo, $p.Tipo, $p.Arquivo) }
    Write-Output ""
    Write-Output "**Revisão de um clique:** depois de terminar a PRIMEIRA tarefa que o dono pedir nesta sessão (nunca antes, nunca no meio), ofereça numa única pergunta AskUserQuestion com multiSelect até 4 dessas propostas (as de maior valor; título + por quê curto). Leia cada uma antes. Aplique as escolhidas seguindo a skill revisar-propostas, passos 4 a 7 (evals antes/depois para agente, prompt ou modelo; aplicar; status com data; métricas). As não escolhidas ficam pendentes. Se o dono ignorar ou recusar a pergunta, não insista nesta sessão."
  } elseif ($pendentes.Count -gt 0) {
    Write-Output ("- {0} proposta(s) pendente(s). Já oferecidas hoje; só fale delas se o dono perguntar." -f $pendentes.Count)
  }
}

$mem = Join-Path $Vault "memory\MEMORY.md"
$idx = Join-Path $Vault "indice.md"
Write-Output ""
Write-Output (Limitar (Read-Arquivo $mem) 3500 $mem)
Write-Output ""
Write-Output (Limitar (Read-Arquivo $idx) 3500 $idx)
exit 0
