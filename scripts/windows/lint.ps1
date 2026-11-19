# Reconciliação do vault: acha o que está fora do lugar e escreve um relatório em markdown.
# Uso: lint.ps1 [-Saida caminho.md]   (sem -Saida, imprime no stdout)
param([string]$Saida = "")
$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "lib.ps1")

$hoje = Get-Date
$todos = Get-ChildItem $Vault -Recurse -Filter *.md |
  Where-Object { $_.FullName -notmatch '\\(\.obsidian|\.trash|\.git)\\' }
$notas = $todos | Where-Object { $_.FullName -notmatch '\\templates\\' }

function Rel($f) { return $f.FullName.Substring($Vault.Length).TrimStart('\', '/') -replace '\\', '/' }

$existe = @{}
foreach ($f in $todos) {
  $existe[$f.BaseName.ToLower()] = $true
  $existe[((Rel $f) -replace '\.md$', '').ToLower()] = $true
}

$entrada = @{}; $semLink = @(); $semFm = @(); $faltaCampo = @(); $velhas = @(); $enriquecer = @(); $porStatus = @{}
foreach ($f in $notas) {
  $txt = Read-Arquivo $f.FullName
  $rel = Rel $f
  foreach ($m in [regex]::Matches($txt, '\[\[([^\]\|#\^]+)')) {
    $alvo = $m.Groups[1].Value.Trim().ToLower() -replace '\.md$', ''
    $base = ($alvo -split '/')[-1]
    if ($existe[$alvo] -or $existe[$base]) { $entrada[$base] = 1 + [int]$entrada[$base] }
    else { $semLink += "``$rel`` -> [[$($m.Groups[1].Value.Trim())]]" }
  }
  if ($rel -match '^(memory|propostas)/' -or $f.Name -eq "README.md") { continue }
  $fm = Get-Frontmatter $txt
  if (-not $fm) { $semFm += "``$rel``"; continue }
  foreach ($campo in @("tags", "criado", "status")) { if (-not $fm.ContainsKey($campo)) { $faltaCampo += "``$rel`` sem ``$campo``" } }
  $st = $fm["status"]; if ($st) { $porStatus[$st] = 1 + [int]$porStatus[$st] }
  if ($fm["enriquecer"] -eq "true") { $enriquecer += "``$rel``" }
  if ($fm["revisado_em"] -and $st -ne "estavel") {
    try { if ([datetime]::Parse($fm["revisado_em"]) -lt $hoje.AddDays(-90)) { $velhas += "``$rel`` (revisado em $($fm['revisado_em']))" } } catch {}
  }
}

$orfas = @()
foreach ($f in $notas) {
  $rel = Rel $f
  if ($rel -match '^(memory|propostas|inbox|evals)/' -or $f.Name -in @("README.md", "indice.md", "CLAUDE.md")) { continue }
  if (-not $entrada[$f.BaseName.ToLower()]) { $orfas += "``$rel``" }
}

$indiceMem = Read-Arquivo (Join-Path $Vault "memory\MEMORY.md")
$memFora = @(Get-ChildItem (Join-Path $Vault "memory") -Filter *.md | Where-Object { $_.Name -ne "MEMORY.md" -and $indiceMem -notmatch [regex]::Escape($_.Name) } | ForEach-Object { "``memory/$($_.Name)``" })
$memLinks = @([regex]::Matches($indiceMem, '\]\(([^)]+\.md)\)') | ForEach-Object { $_.Groups[1].Value } | Where-Object { -not (Test-Path (Join-Path $Vault "memory\$_")) } | ForEach-Object { "``$_``" })

$inboxVelho = @(Get-ChildItem (Join-Path $Vault "inbox") -Filter *.md | Where-Object { $_.Name -ne "README.md" -and $_.LastWriteTime -lt $hoje.AddDays(-7) } | ForEach-Object { "``inbox/$($_.Name)``" })
$propVelhas = @(Get-ChildItem (Join-Path $Vault "propostas") -Filter *.md | Where-Object { $_.LastWriteTime -lt $hoje.AddDays(-7) -and (Read-Arquivo $_.FullName) -match '\*\*Status:\*\*\s*pendente' } | ForEach-Object { "``propostas/$($_.Name)``" })
$tarefas = @{}
foreach ($t in (Get-ChildItem (Join-Path $Vault "tarefas") -Filter *.md | Where-Object { $_.Name -ne "README.md" })) {
  $fm = Get-Frontmatter (Read-Arquivo $t.FullName)
  if ($fm -and $fm["status"]) { $s = $fm["status"]; if (-not $tarefas[$s]) { $tarefas[$s] = @() }; $tarefas[$s] += "``tarefas/$($t.Name)``" }
}

function Secao([string]$Titulo, $Itens, [string]$Dica) {
  $itens = @($Itens)
  $r = "## $Titulo ($($itens.Count))`n"
  if ($itens.Count -eq 0) { return $r + "Nada.`n`n" }
  if ($Dica) { $r += "_$($Dica)_`n" }
  return $r + (($itens | Select-Object -First 40 | ForEach-Object { "- $_" }) -join "`n") + "`n`n"
}

$rel = "# Lint do cérebro ($($hoje.ToString('yyyy-MM-dd')))`n`n"
$rel += "Notas: $($notas.Count). Por status: " + (($porStatus.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ", ") + "`n`n"
$rel += Secao "Memórias fora do MEMORY.md" $memFora "Adicionar linha no índice ou apagar a memória."
$rel += Secao "Linhas do MEMORY.md apontando para arquivo inexistente" $memLinks ""
$rel += Secao "Notas sem frontmatter" $semFm ""
$rel += Secao "Campos obrigatórios faltando" $faltaCampo ""
$rel += Secao "Links para notas que não existem" $semLink "Pode ser lembrete de criar a nota, ou erro de digitação."
$rel += Secao "Notas órfãs (ninguém linka)" $orfas "Linkar no indice.md ou em nota relacionada."
$rel += Secao "Possivelmente desatualizadas (revisado_em > 90 dias)" $velhas ""
$rel += Secao "Inbox parado há mais de 7 dias" $inboxVelho "Rodar /processar-inbox."
$rel += Secao "Propostas pendentes há mais de 7 dias" $propVelhas "Rodar /revisar-propostas ou recusar."
$rel += Secao "Notas marcadas para enriquecer" $enriquecer ""
foreach ($s in @("revisar", "bloqueada", "fazendo")) { if ($tarefas[$s]) { $rel += Secao "Tarefas em '$s'" $tarefas[$s] "" } }

if ($Saida) { Write-Arquivo $Saida $rel } else { Write-Output $rel }
