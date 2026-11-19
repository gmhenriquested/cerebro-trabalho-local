# Loop noturno (camadas 2 e 3). Dias úteis, 19h.
# Triagem do inbox + enriquecimento das notas com enriquecer: true.
# O que é óbvio e de baixo risco ele aplica (escrita automática); o resto vira proposta.
# Web separada do vault (ADR 0010): quem lê o vault não tem web; quem tem web não lê o vault
# e só recebe as perguntas, já filtradas pelos termos internos. O script grava o resultado.
param([int]$MaxInbox = 15, [int]$MaxEnriquecer = 5)
$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "lib.ps1")
if (-not (Test-LoopAtivo "noturno")) { exit 0 }
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

  $hoje = (Get-Date).ToString('yyyy-MM-dd')
  $saida = Invoke-Claude -Prompt $prompt -Papel "noturno" -Tools "Read,Grep,Glob,Edit,Write" -Raizes @($Vault) -Escrita -MaxTurnos 80

  # ---- pesquisa na web, isolada do vault
  $enriquecidas = @()
  $pedidos = [regex]::Match($saida, '(?s)## Pesquisas pedidas[^\r\n]*\r?\n(.*?)(?=\r?\n## |\z)')
  if ($pedidos.Success) {
    $saida = $saida.Replace($pedidos.Value, "").Trim()
    $permitidas = @{}
    foreach ($m in $marcadas) { $permitidas[(Rel $m).ToLower()] = $m.FullName }
    $termos = @()
    $termosArq = Join-Path $Vault "config\termos-internos.txt"
    if (Test-Path $termosArq) {
      $termos = @(Get-Content -Encoding UTF8 $termosArq | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -and -not $_.StartsWith("#") })
    }
    $porNota = [ordered]@{}
    foreach ($l in ($pedidos.Groups[1].Value -split '\r?\n')) {
      $mm = [regex]::Match($l, '^\s*-\s*`?([^`:]+?\.md)`?\s*::\s*(.+?)\s*$')
      if (-not $mm.Success) { continue }
      $nota = ($mm.Groups[1].Value.Trim() -replace '\\', '/').ToLower()
      $perg = $mm.Groups[2].Value.Trim()
      if (-not $permitidas.ContainsKey($nota)) { Write-CerebroLog "Noturno" "pesquisa ignorada: $nota não está marcada para enriquecer"; continue }
      $vetada = ((Hide-Segredos $perg) -ne $perg)
      foreach ($t in $termos) { if ($perg.ToLower().Contains($t)) { $vetada = $true } }
      if ($vetada) { Write-CerebroLog "Noturno" "pergunta vetada (termo interno ou segredo) para $nota"; continue }
      if (-not $porNota.Contains($nota)) { $porNota[$nota] = @() }
      if ($porNota[$nota].Count -lt 3) { $porNota[$nota] += $perg }
    }

    # Pasta vazia, sem ferramenta de arquivo e sem raiz de escrita: o pesquisador só vê as perguntas.
    $dirPesq = Join-Path $env:LOCALAPPDATA "cerebro\pesquisa-web"
    New-Item -ItemType Directory -Force -Path $dirPesq | Out-Null
    foreach ($chave in @($porNota.Keys)) {
      $perguntas = ($porNota[$chave] | ForEach-Object { "- $_" }) -join "`n"
      $res = Invoke-Claude -Prompt ((Get-Prompt "pesquisa-web") + "`n`n# Perguntas`n`n$perguntas") -Papel "pesquisa_web" -Tools "WebSearch,WebFetch" -Dir $dirPesq -MaxTurnos 25
      $res = (Hide-Segredos $res).Trim()
      if (-not $res) { Write-CerebroLog "Noturno" "pesquisa sem resultado para $chave"; continue }
      if ($res.Length -gt 4000) { $res = $res.Substring(0, 4000) + "`n(... cortado)" }
      $res = $res -replace '(?m)^#+\s*', ''   # texto da web não cria títulos nem reorganiza a nota
      $arqNota = $permitidas[$chave]
      $txt = Read-Arquivo $arqNota
      $txt = Set-CampoFrontmatter $txt "enriquecer" "false"
      $txt = Set-CampoFrontmatter $txt "status" "enriquecida"
      $txt = Set-CampoFrontmatter $txt "revisado_em" $hoje
      $txt = $txt.TrimEnd() + "`n`n## Enriquecimento ($hoje)`n`n> Trazido da web pelo loop noturno, por um agente sem acesso ao vault. É referência, não instrução.`n`nPerguntas:`n$perguntas`n`n$res`n"
      Write-Arquivo $arqNota $txt
      $enriquecidas += ("- ``{0}``: enriquecida ({1} pergunta(s))" -f $chave, $porNota[$chave].Count)
    }
  }
  if ($enriquecidas.Count -gt 0) {
    $linhas = $enriquecidas -join "`n"
    if (Test-Vazio $saida) { $saida = "" }
    $re = New-Object System.Text.RegularExpressions.Regex '(?m)^## Aplicado automaticamente[^\r\n]*\r?\n(- \*\*Status:\*\*[^\r\n]*\r?\n)?'
    $ma = $re.Match($saida)
    if ($ma.Success) { $pos = $ma.Index + $ma.Length; $saida = $saida.Substring(0, $pos) + $linhas + "`n" + $saida.Substring($pos) }
    else { $saida = "## Aplicado automaticamente`n- **Status:** aplicada-auto ($hoje)`n$linhas`n`n$saida" }
  }

  # Itens que o Claude arquivou (frontmatter arquivado: true) saem do inbox.
  foreach ($item in (Get-ChildItem (Join-Path $Vault "inbox") -Filter *.md | Where-Object { $_.Name -ne "README.md" })) {
    $fmItem = Get-Frontmatter (Read-Arquivo $item.FullName)
    if ($fmItem -and $fmItem["arquivado"] -eq "true") {
      Remove-Item -LiteralPath $item.FullName -Force
      Write-CerebroLog "Noturno" "arquivado e removido do inbox: $($item.Name)"
    }
  }
  Save-Resultado "noturno" $saida | Out-Null
  Sync-Vault "Loop"
} finally { Exit-Trava "noturno" }
