# Loop noturno (camadas 2 e 3). Dias úteis, 19h.
# Triagem do inbox + enriquecimento das notas com enriquecer: true. Tudo vira proposta.
param([int]$MaxInbox = 15, [int]$MaxEnriquecer = 5)
$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "lib.ps1")
if (-not (Enter-Trava "noturno")) { Write-CerebroLog "Noturno" "já rodando"; exit 0 }
try {
  function Rel($f) { return $f.FullName.Substring($Vault.Length).TrimStart('\') -replace '\\', '/' }

  $inbox = @(Get-ChildItem (Join-Path $Vault "inbox") -Filter *.md | Where-Object { $_.Name -ne "README.md" } |
    Sort-Object LastWriteTime | Select-Object -First $MaxInbox)
  $marcadas = @(Get-ChildItem $Vault -Recurse -Filter *.md | Where-Object { $_.FullName -notmatch '\\(\.obsidian|\.git|templates|propostas)\\' } |
    Where-Object { $fm = Get-Frontmatter (Read-Arquivo $_.FullName); $fm -and $fm["enriquecer"] -eq "true" } |
    Select-Object -First $MaxEnriquecer)

  if ($inbox.Count -eq 0 -and $marcadas.Count -eq 0) { Write-CerebroLog "Noturno" "nada para fazer"; exit 0 }

  $blocoInbox = ($inbox | ForEach-Object {
    $t = Hide-Segredos (Read-Arquivo $_.FullName); if ($t.Length -gt 3000) { $t = $t.Substring(0, 3000) + "..." }
    "### $(Rel $_)`n``````markdown`n$t`n``````"
  }) -join "`n`n"
  $blocoMarcadas = ($marcadas | ForEach-Object { "- $(Rel $_)" }) -join "`n"

  $prompt = (Get-Prompt "noturno") + "`n`n# Data de hoje: $((Get-Date).ToString('yyyy-MM-dd'))`n`n" +
    "# Itens do inbox`n`n$(if ($blocoInbox) { $blocoInbox } else { '(vazio)' })`n`n" +
    "# Notas marcadas para enriquecer (leia cada uma com Read)`n`n$(if ($blocoMarcadas) { $blocoMarcadas } else { '(nenhuma)' })"

  $tools = "Read,Grep,Glob"
  if ($marcadas.Count -gt 0) { $tools = "Read,Grep,Glob,WebSearch,WebFetch" }
  $saida = Invoke-Claude -Prompt $prompt -Tools $tools -MaxTurnos 60
  Save-Proposta "noturno" $saida | Out-Null
  Sync-Vault "Loop"
} finally { Exit-Trava "noturno" }
