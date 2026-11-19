# Loop noturno (camadas 2 e 3). Dias úteis, 19h.
# Triagem do inbox + enriquecimento das notas com enriquecer: true.
# O que é óbvio e de baixo risco ele aplica (escrita automática); o resto vira proposta.
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

  $tools = "Read,Grep,Glob,Edit,Write"
  if ($marcadas.Count -gt 0) { $tools += ",WebSearch,WebFetch" }
  $saida = Invoke-Claude -Prompt $prompt -Tools $tools -Escrita -MaxTurnos 80

  # Itens que o Claude arquivou saem do inbox (só arquivos dentro de inbox/).
  $inboxDir = (Join-Path $Vault "inbox").TrimEnd('\') + '\'
  foreach ($m in [regex]::Matches($saida, '(?m)^ARQUIVADO:\s*(inbox/[^\s]+\.md)\s*$')) {
    $alvo = Join-Path $Vault ($m.Groups[1].Value -replace '/', '\')
    $cheio = [System.IO.Path]::GetFullPath($alvo)
    if ($cheio.StartsWith($inboxDir, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path $cheio) -and $cheio -notmatch 'README\.md$') {
      Remove-Item $cheio -Force
      Write-CerebroLog "Noturno" "arquivado e removido do inbox: $($m.Groups[1].Value)"
    }
  }
  $saida = [regex]::Replace($saida, '(?m)^ARQUIVADO:.*\r?\n?', '')
  Save-Proposta "noturno" $saida | Out-Null
  Sync-Vault "Loop"
} finally { Exit-Trava "noturno" }
