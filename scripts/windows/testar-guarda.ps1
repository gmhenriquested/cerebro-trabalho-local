# Testes da guarda: manda entradas de hook falsas para guarda.ps1 e confere se bloqueia (código 2) ou deixa (0).
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File testar-guarda.ps1
# Cria dois arquivos temporários em <vault>\tarefas e um worktree falso em %TEMP%; apaga tudo no fim.
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib.ps1")
$guarda = Join-Path $PSScriptRoot "guarda.ps1"
$id = [guid]::NewGuid().ToString("N").Substring(0, 6)
$rasc = Join-Path $Vault "tarefas\zz-teste-guarda-$id-rascunho.md"
$pronta = Join-Path $Vault "tarefas\zz-teste-guarda-$id-pronta.md"
$nova = Join-Path $Vault "tarefas\zz-teste-guarda-$id-nova.md"
$wt = Join-Path $env:TEMP "cerebro-teste-guarda-$id"
$falhas = 0; $total = 0

function Testar([string]$Nome, [int]$Esperado, [hashtable]$Entrada, [string]$Raizes, [switch]$Interativo) {
  $script:total++
  if ($Interativo) { $env:CEREBRO_LOOP = "" } else { $env:CEREBRO_LOOP = "1" }
  $env:CEREBRO_RAIZES = $Raizes; $env:CEREBRO_ESCRITA = "auto"; $env:CEREBRO_PAPEL = "teste"
  $json = $Entrada | ConvertTo-Json -Depth 5 -Compress
  $null = ($json | & powershell -NoProfile -ExecutionPolicy Bypass -File $guarda 2>&1)
  $obtido = $LASTEXITCODE
  if ($obtido -eq $Esperado) { Write-Host "ok    $Nome" -ForegroundColor Green }
  else { Write-Host "FALHA $Nome (esperado $Esperado, veio $obtido)" -ForegroundColor Red; $script:falhas++ }
}

try {
  Write-Arquivo $rasc "---`ntags: [teste]`ncriado: 2026-01-01`nstatus: rascunho`nrepo: exemplo`n---`n`n# Teste`n`nCorpo.`n"
  Write-Arquivo $pronta "---`ntags: [teste]`ncriado: 2026-01-01`nstatus: pronta`nrepo: exemplo`n---`n`n# Teste`n`nCorpo.`n"
  New-Item -ItemType Directory -Force -Path (Join-Path $wt "src") | Out-Null

  # Tarefas (a falha corrigida: Edit que troca só a palavra)
  Testar "Edit troca só rascunho por pronta" 2 @{ tool_name = "Edit"; tool_input = @{ file_path = $rasc; old_string = "rascunho"; new_string = "pronta" } } $Vault
  Testar "Edit com replace_all para feita" 2 @{ tool_name = "Edit"; tool_input = @{ file_path = $rasc; old_string = "rascunho"; new_string = "feita"; replace_all = $true } } $Vault
  Testar "MultiEdit que termina em pronta" 2 @{ tool_name = "MultiEdit"; tool_input = @{ file_path = $rasc; edits = @(@{ old_string = "status: rasc"; new_string = "status: pr" }, @{ old_string = "status: prunho"; new_string = "status: pronta" }) } } $Vault
  Testar "Edit no corpo de tarefa em rascunho" 0 @{ tool_name = "Edit"; tool_input = @{ file_path = $rasc; old_string = "Corpo."; new_string = "Corpo melhor." } } $Vault
  Testar "Edit no corpo de tarefa já pronta" 2 @{ tool_name = "Edit"; tool_input = @{ file_path = $pronta; old_string = "Corpo."; new_string = "Faça outra coisa." } } $Vault
  Testar "Write de tarefa nova em rascunho" 0 @{ tool_name = "Write"; tool_input = @{ file_path = $nova; content = "---`nstatus: rascunho`n---`n# x" } } $Vault
  Testar "Write de tarefa nova já pronta" 2 @{ tool_name = "Write"; tool_input = @{ file_path = $nova; content = "---`nstatus: pronta`n---`n# x" } } $Vault
  Testar "Edit com trecho que não existe" 2 @{ tool_name = "Edit"; tool_input = @{ file_path = $rasc; old_string = "nao existe"; new_string = "x" } } $Vault

  # Executor: arquivos que fazem código rodar sozinho
  Testar "Write em src do worktree" 0 @{ tool_name = "Write"; tool_input = @{ file_path = (Join-Path $wt "src\a.ts"); content = "export const a = 1" } } $wt
  Testar "Write em package.json" 2 @{ tool_name = "Write"; tool_input = @{ file_path = (Join-Path $wt "package.json"); content = "{}" } } $wt
  Testar "Write em workflow do GitHub" 2 @{ tool_name = "Write"; tool_input = @{ file_path = (Join-Path $wt ".github\workflows\ci.yml"); content = "on: push" } } $wt
  Testar "Write em hook do husky" 2 @{ tool_name = "Write"; tool_input = @{ file_path = (Join-Path $wt ".husky\pre-commit"); content = "x" } } $wt
  Testar "Write fora das raízes" 2 @{ tool_name = "Write"; tool_input = @{ file_path = (Join-Path $env:TEMP "fora-$id.txt"); content = "x" } } $wt

  # O que já existia continua valendo
  Testar "push forçado (sessão interativa)" 2 @{ tool_name = "Bash"; tool_input = @{ command = "git push --force origin main" } } "" -Interativo
  Testar "git status (sessão interativa)" 0 @{ tool_name = "Bash"; tool_input = @{ command = "git status" } } "" -Interativo
} finally {
  foreach ($f in @($rasc, $pronta, $nova)) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
  Remove-Item -LiteralPath $wt -Recurse -Force -ErrorAction SilentlyContinue
  $env:CEREBRO_LOOP = ""; $env:CEREBRO_RAIZES = ""; $env:CEREBRO_ESCRITA = ""; $env:CEREBRO_PAPEL = ""
}
Write-Host ""
if ($falhas -eq 0) { Write-Host "Guarda: $total de $total testes ok." -ForegroundColor Green; exit 0 }
Write-Host "Guarda: $falhas de $total testes falharam." -ForegroundColor Red; exit 1
