# Aplica o roteamento de modelos de config/cerebro.json (modelos.agentes) no frontmatter
# dos agentes em ~/.claude/agents/. Roda sozinho no SessionStart quando a config muda.
$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "lib.ps1")
$cfg = Get-ConfigCerebro
$dir = Join-Path $HOME ".claude\agents"
$mudou = @()
if ($cfg.modelos -and $cfg.modelos.agentes) {
  foreach ($prop in $cfg.modelos.agentes.PSObject.Properties) {
    $arq = Join-Path $dir ($prop.Name + ".md")
    if (-not (Test-Path $arq)) { continue }
    $txt = Read-Arquivo $arq
    $fm = Get-Frontmatter $txt
    if (-not $fm) { continue }
    if ($fm["model"] -ne [string]$prop.Value) {
      Write-Arquivo $arq (Set-CampoFrontmatter $txt "model" ([string]$prop.Value))
      $mudou += "$($prop.Name)=$($prop.Value)"
    }
  }
}
Write-Arquivo (Join-Path $State "modelos-aplicados") (Get-Date).ToString("o")
if ($mudou.Count -gt 0) { Write-CerebroLog "Modelos" ("agentes atualizados: " + ($mudou -join ", ")) }
Write-Output ($mudou -join ", ")
