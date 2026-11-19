# Commit + pull --rebase + push do vault.
#   Hook Stop       -> sync.ps1 -Origem Stop          (relança em segundo plano)
#   Hook SessionEnd -> sync.ps1 -Origem SessionEnd -Worker
#   Loops           -> sync.ps1 -Origem Loop -Worker
param(
  [string]$Origem = "Stop",
  [switch]$Worker
)
$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "lib.ps1")
if ([Console]::IsInputRedirected -and -not $Worker) { [void][Console]::In.ReadToEnd() }
if ($env:CEREBRO_LOOP -eq "1" -and $Origem -ne "Loop") { exit 0 }

if (-not $Worker) {
  Start-Process -WindowStyle Hidden -FilePath "powershell" -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"", "-Origem", $Origem, "-Worker"
  )
  exit 0
}

if (-not (Test-Path (Join-Path $Vault ".git"))) { Write-CerebroLog $Origem "vault sem git"; exit 0 }
if (-not (Enter-Trava "sync")) { Write-CerebroLog $Origem "sync já em andamento"; exit 0 }

try {
  Set-Location $Vault
  $branch = (git rev-parse --abbrev-ref HEAD).Trim()
  if ($branch -ne "main") { Write-CerebroLog $Origem "fora da main, pulando"; exit 0 }

  if (git status --porcelain) {
    git add -A
    git commit -q -m "Auto: cérebro ($Origem, $env:COMPUTERNAME)"
    if ($LASTEXITCODE -eq 0) { Write-CerebroLog $Origem "commit feito" }
  }

  if (-not (git remote)) { exit 0 }
  $pendente = git log "@{u}..HEAD" --oneline 2>$null
  if ($pendente -or $Origem -ne "Stop" -or $LASTEXITCODE -ne 0) {
    git pull -q --rebase --autostash 2>&1 | Add-Content -Encoding UTF8 $Log
    if ($LASTEXITCODE -ne 0) {
      git rebase --abort 2>$null
      Write-CerebroLog $Origem "conflito no pull, push adiado"
      exit 0
    }
    git push -q -u origin main 2>&1 | Add-Content -Encoding UTF8 $Log
    if ($LASTEXITCODE -eq 0) { Write-CerebroLog $Origem "push ok" }
  }
}
finally {
  Exit-Trava "sync"
}
exit 0
