# Trava do kit público: impede commit que leve termo interno da empresa para o repositório.
# Os termos ficam só no vault (config/termos-internos.txt); aqui eles são lidos, nunca copiados.
# Chamado pelos hooks de scripts/git-hooks (ligados pelo instalador com core.hooksPath).
#   sem parâmetro   -> confere nomes de arquivo e linhas adicionadas no que está staged
#   -Mensagem <arq> -> confere a mensagem do commit
param([string]$Mensagem = "")
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$Vault = $null
$cfg = Join-Path $HOME ".claude\hooks\cerebro\config.ps1"
if (Test-Path $cfg) { . $cfg }
if (-not $Vault) { $Vault = Join-Path $HOME "cerebro-trabalho" }
$arq = Join-Path $Vault "config\termos-internos.txt"
if (-not (Test-Path $arq)) {
  Write-Host "Trava do kit: não achei $arq; commit sem conferência de termos internos."
  exit 0
}
$termos = @(Get-Content -Encoding UTF8 $arq | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") })
if ($termos.Count -eq 0) { exit 0 }

if ($Mensagem) {
  $texto = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Mensagem).Path, [System.Text.Encoding]::UTF8)
  $onde = "a mensagem do commit"
} else {
  $nomes = @(git -c core.quotepath=false diff --cached --name-only) -join "`n"
  $linhas = @(git -c core.quotepath=false diff --cached -U0 --no-color --no-ext-diff |
    Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+ ' }) -join "`n"
  $texto = $nomes + "`n" + $linhas
  $onde = "o que você está commitando"
}

$achados = @($termos | Where-Object { $texto.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
if ($achados.Count -gt 0) {
  [Console]::Error.WriteLine("Commit bloqueado: $onde tem termo interno da empresa ($($achados -join ', ')).")
  [Console]::Error.WriteLine("O kit é público. Tire o trecho; o que é da empresa vai para o vault. Lista em $arq.")
  exit 1
}
exit 0
