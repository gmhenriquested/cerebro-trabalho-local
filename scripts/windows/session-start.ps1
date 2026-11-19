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

$pendentes = @(Get-ChildItem (Join-Path $Vault "propostas") -Filter *.md -ErrorAction SilentlyContinue |
  Where-Object { (Read-Arquivo $_.FullName) -match '\*\*Status:\*\*\s*pendente' })
$revisar = @(Get-ChildItem (Join-Path $Vault "tarefas") -Filter *.md -ErrorAction SilentlyContinue |
  Where-Object { $fm = Get-Frontmatter (Read-Arquivo $_.FullName); $fm -and $fm["status"] -eq "revisar" })

if ($pendentes.Count -gt 0 -or $revisar.Count -gt 0) {
  Write-Output ""
  Write-Output "## Pendências do cérebro"
  if ($pendentes.Count -gt 0) { Write-Output ("- {0} arquivo(s) de propostas pendentes. Sugira ao dono rodar /revisar-propostas." -f $pendentes.Count) }
  if ($revisar.Count -gt 0) { Write-Output ("- {0} tarefa(s) feitas por agente esperando revisão em tarefas/: {1}" -f $revisar.Count, (($revisar | ForEach-Object { $_.BaseName }) -join ", ")) }
}
exit 0
