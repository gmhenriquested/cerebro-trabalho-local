# Hook Stop: uma vez por sessão, lembra o Claude de salvar o que é durável no vault.
$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "lib.ps1")
$entrada = ""
if ([Console]::IsInputRedirected) { $entrada = [Console]::In.ReadToEnd() }
if ($env:CEREBRO_LOOP -eq "1") { exit 0 }

$sid = "x"; $ativo = $false
try {
  $j = $entrada | ConvertFrom-Json
  if ($j.session_id) { $sid = $j.session_id }
  if ($j.stop_hook_active) { $ativo = $true }
} catch {}

$flag = Join-Path $State "lembrado-$sid"
if ($ativo -or (Test-Path $flag)) { exit 0 }
New-Item -ItemType File -Force -Path $flag | Out-Null
Get-ChildItem $State -Filter "lembrado-*" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) } | Remove-Item -Force

$motivo = "Ritual do cérebro: se esta sessão gerou algo durável (decisão, preferência, status de projeto, aprendizado, correção sua), salve agora no vault ($Vault): decisão vira ADR em decisoes/, fato vira memória em memory/ com linha em MEMORY.md, e atualize indice.md. Se a correção do dono mostra um erro que pode voltar, proponha também um caso em evals/casos/. Se não houver nada durável, apenas encerre."
@{ decision = "block"; reason = $motivo } | ConvertTo-Json -Compress
exit 0
