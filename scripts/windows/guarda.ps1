# Hook PreToolUse: barreira determinística (ADR 0006).
# Matcher: Bash|PowerShell|Write|Edit|MultiEdit|NotebookEdit|Read|WebSearch|WebFetch
# Exit 2 bloqueia a ferramenta e a mensagem em stderr volta para o Claude.
#
# Sessão interativa: bloqueia só o catastrófico.
# Modo autônomo (CEREBRO_LOOP=1, ligado pelo Invoke-Claude): mais rígido e FALHA FECHADO.
#   - escrita só dentro de CEREBRO_RAIZES (o worktree do executor ou o vault);
#   - no vault, só áreas liberadas (e as de baixo risco com CEREBRO_ESCRITA=auto);
#   - tarefa: só cria ou edita em rascunho, e o resultado da edição (simulado aqui) continua rascunho;
#   - não escreve em arquivo que executa código sozinho (.github, .husky, .vscode, package.json...);
#   - busca na web não pode levar termos de config/termos-internos.txt.
$autonomo = ($env:CEREBRO_LOOP -eq "1")
try {
  $ErrorActionPreference = "Stop"
  . (Join-Path $PSScriptRoot "lib.ps1")
  $ErrorActionPreference = "SilentlyContinue"
  $entrada = Read-EntradaHook
  $j = $entrada | ConvertFrom-Json
} catch {
  if ($autonomo) { [Console]::Error.WriteLine("Guarda indisponível em modo autônomo: ação negada."); exit 2 }
  exit 0
}

$ferramenta = [string]$j.tool_name
if (-not $ferramenta) { if ($autonomo) { exit 2 } else { exit 0 } }
$ti = $j.tool_input
$cmd = [string]$ti.command
$arquivo = [string]$ti.file_path
if (-not $arquivo) { $arquivo = [string]$ti.notebook_path }
$conteudo = ([string]$ti.content) + ([string]$ti.new_string) + ([string]$ti.new_source)
if ($ti.edits) { foreach ($e in $ti.edits) { $conteudo += [string]$e.new_string } }

function Bloquear([string]$Motivo) {
  Write-CerebroLog "Guarda" ("bloqueado ({0}, papel {1}): {2}" -f $ferramenta, $env:CEREBRO_PAPEL, $Motivo)
  [Console]::Error.WriteLine("Bloqueado pela guarda do cérebro: $Motivo. Escolha outro caminho ou deixe como proposta para o dono.")
  exit 2
}

function Get-Caminho([string]$c) {
  if (-not $c) { return "" }
  if ($c.StartsWith('\\?\') -or $c.StartsWith('\\.\')) { Bloquear "caminho de dispositivo não permitido" }
  try { return [System.IO.Path]::GetFullPath(($c -replace '/', '\')).TrimEnd('\') } catch { Bloquear "caminho inválido" }
}

# Arquivos e pastas que fazem código rodar sem ninguém pedir (CI, hooks, tarefas da IDE, scripts do npm).
# Em modo autônomo ficam com o dono: mudar um deles é mudar o que roda na verificação ou no CI.
$executaSozinho = '\\(\.git|\.github|\.husky|\.vscode|\.idea|\.claude|\.devcontainer|\.circleci|\.gitlab)(\\|$)|\\(package\.json|\.npmrc|\.yarnrc(\.yml)?|\.pnpmfile\.cjs|\.gitattributes|\.gitmodules|\.gitlab-ci\.yml|azure-pipelines\.yml|Makefile|Directory\.Build\.(props|targets)|nuget\.config|global\.json)$'

# Texto do arquivo depois da edição pedida, para decidir pelo resultado e não pelo trecho novo.
# Devolve $null quando não dá para simular (a guarda então nega em modo autônomo).
function Get-Troca([string]$Texto, [string]$Velho, [string]$Novo, [bool]$Todos) {
  if (-not $Velho) { if (-not $Texto) { return $Novo }; return $null }
  $i = $Texto.IndexOf($Velho, [StringComparison]::Ordinal)
  if ($i -lt 0) { return $null }
  if ($Todos) { return $Texto.Replace($Velho, $Novo) }
  return $Texto.Substring(0, $i) + $Novo + $Texto.Substring($i + $Velho.Length)
}
function Get-TextoAposEdicao([string]$Ferr, [string]$Atual, $Entrada) {
  if ($Ferr -eq "Write") { return [string]$Entrada.content }
  if ($Ferr -eq "Edit") { return (Get-Troca $Atual ([string]$Entrada.old_string) ([string]$Entrada.new_string) ([bool]$Entrada.replace_all)) }
  if ($Ferr -eq "MultiEdit") {
    $t = $Atual
    foreach ($e in @($Entrada.edits)) {
      $t = Get-Troca $t ([string]$e.old_string) ([string]$e.new_string) ([bool]$e.replace_all)
      if ($null -eq $t) { return $null }
    }
    return $t
  }
  return $null
}
function Get-StatusTarefa([string]$Texto) {
  if (-not $Texto) { return "" }
  $fm = Get-Frontmatter $Texto
  if (-not $fm) { return "" }
  return ([string]$fm["status"]).Trim().Trim('"', "'").ToLower()
}

$segredoArq = '(^|\\)(\.env(\.[\w-]+)?|id_rsa|id_ed25519|[^\\]*\.pem|[^\\]*\.pfx|[^\\]*\.key|credentials(\.json)?|\.credentials\.json|\.git-credentials|\.npmrc|\.netrc)$'
$segredoOk = '\.env\.(example|sample|template)$'

# ---------------------------------------------------------------- terminal
if ($ferramenta -in @("Bash", "PowerShell")) {
  $sempre = @(
    @('git\s+push\b.*(\s--force\b|\s-f\b|\s--force-with-lease\b|\s\+\S+)', 'push forçado'),
    @('\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)\s+(/|~|\$HOME|[A-Za-z]:[\\/]?)(\s|$)', 'apagar raiz ou home'),
    @('Remove-Item\b.*-Recurse.*\s([A-Za-z]:\\?|~|\$HOME|\$env:USERPROFILE)(\s|$)', 'apagar raiz ou home'),
    @('(curl|wget|iwr|irm|Invoke-WebRequest|Invoke-RestMethod)\b[^|]*\|\s*(sh|bash|iex|Invoke-Expression)\b', 'executar script baixado da internet'),
    @('\b(DROP\s+(DATABASE|TABLE)|TRUNCATE\s+TABLE)\b', 'comando destrutivo de banco'),
    @('\bformat\s+[A-Za-z]:', 'formatar disco'),
    @('\.credentials\.json', 'ler credenciais do Claude')
  )
  foreach ($r in $sempre) { if ($cmd -match $r[0]) { Bloquear $r[1] } }

  if ($autonomo) {
    $loop = @(
      @('\bgit\s+push\b', 'agente autônomo não faz push; o executor cuida disso'),
      @('\bgh\s+pr\s+(merge|close)\b', 'agente autônomo não faz merge'),
      @('\bgit\s+(reset\s+--hard|clean\s+-[a-zA-Z]*f|checkout\s+(main|master)\b|switch\b|rebase\b|worktree\b|remote\b|config\b)', 'comando git que perde trabalho, troca de base ou muda configuração'),
      @('--no-verify\b', 'pular hooks de verificação'),
      @('\b(npm|pnpm|yarn)\s+publish\b', 'publicar pacote'),
      @('(^|[;&|(]\s*)(terraform|kubectl|helm|az|aws|gcloud)\s', 'mexer em nuvem ou infraestrutura'),
      @('\b(sudo|runas|Start-Process\b.*-Verb\s+RunAs)\b', 'elevar privilégio'),
      @('\b(curl|wget|Invoke-WebRequest|Invoke-RestMethod|iwr|irm)\b', 'acesso à rede pelo terminal'),
      @('(\.claude[\\/]|cerebro[\\/]config|\.env\b)', 'tocar configuração do Claude, do cérebro ou segredos pelo terminal')
    )
    foreach ($r in $loop) { if ($cmd -match $r[0]) { Bloquear $r[1] } }
  }
}

# ---------------------------------------------------------------- leitura
if ($ferramenta -eq "Read") {
  $p = Get-Caminho $arquivo
  if ($p -match '\\\.credentials\.json$') { Bloquear "ler credenciais do Claude" }
  if ($autonomo -and $p -match $segredoArq -and $p -notmatch $segredoOk) { Bloquear "agente autônomo não lê arquivo de segredo" }
}

# ---------------------------------------------------------------- web
if ($autonomo -and $ferramenta -in @("WebSearch", "WebFetch")) {
  $termosArq = Join-Path $Vault "config\termos-internos.txt"
  if (Test-Path $termosArq) {
    $consulta = (([string]$ti.query) + " " + ([string]$ti.url) + " " + ([string]$ti.prompt)).ToLower()
    foreach ($t in (Get-Content -Encoding UTF8 $termosArq)) {
      $t = $t.Trim()
      if (-not $t -or $t.StartsWith("#")) { continue }
      if ($consulta.Contains($t.ToLower())) { Bloquear "a busca contém um termo interno da empresa; generalize a pergunta sem nomes" }
    }
  }
}

# ---------------------------------------------------------------- escrita
if ($ferramenta -in @("Write", "Edit", "MultiEdit", "NotebookEdit")) {
  $p = Get-Caminho $arquivo
  if ($p -match $segredoArq -and $p -notmatch $segredoOk) { Bloquear "escrever arquivo de segredo ($arquivo)" }
  if ($conteudo -match '(github_pat_|gh[pousr]_[A-Za-z0-9]{20,}|sk-ant-|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|xox[abprs]-)') {
    Bloquear "o conteúdo parece ter um segredo; use variável de ambiente"
  }

  if ($autonomo) {
    # 0. nada que faça código rodar sozinho (CI, hooks, scripts do npm)
    if ($p -match $executaSozinho) { Bloquear "arquivo que executa código sozinho ($arquivo); descreva a mudança no relatório e o dono aplica" }

    # 1. só dentro das raízes do papel
    $raizes = @(($env:CEREBRO_RAIZES -split ';') | Where-Object { $_ })
    if ($raizes.Count -eq 0) { Bloquear "este papel não tem permissão de escrita" }
    $dentro = $false
    foreach ($r in $raizes) { if ($p.Equals($r, [StringComparison]::OrdinalIgnoreCase) -or $p.StartsWith($r + '\', [StringComparison]::OrdinalIgnoreCase)) { $dentro = $true } }
    if (-not $dentro) { Bloquear "fora das pastas permitidas para este agente ($p)" }

    # 2. dentro do vault, só áreas liberadas
    if ($p.StartsWith($Vault + '\', [StringComparison]::OrdinalIgnoreCase)) {
      $rel = $p.Substring($Vault.Length + 1)
      $livre = '^(propostas|inbox|tarefas)\\'
      $auto  = '^((notas|projetos|pessoas|referencias|reunioes)\\|indice\.md$|memory\\MEMORY\.md$)'
      $ok = ($rel -match $livre) -or ($env:CEREBRO_ESCRITA -eq "auto" -and $rel -match $auto)
      if (-not $ok) { Bloquear "em modo automático, $rel é só com o dono presente; vire proposta" }
      # Tarefa: decide pelo arquivo como ficaria depois da edição, não pelo trecho novo
      # (um Edit que troca só "rascunho" por "pronta" não tem "status:" no trecho).
      if ($rel -match '^tarefas\\' -and $rel -ne 'tarefas\README.md') {
        $atual = ""
        if (Test-Path -LiteralPath $p) { $atual = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
        $antes = Get-StatusTarefa $atual
        if ($antes -and $antes -ne "rascunho") { Bloquear "a tarefa está com status $antes e já é do dono; em modo automático só se mexe em tarefa em rascunho" }
        $depois = Get-TextoAposEdicao $ferramenta $atual $ti
        if ($null -eq $depois) { Bloquear "não consegui conferir como a tarefa ficaria depois da edição" }
        if ((Get-StatusTarefa $depois) -ne "rascunho") { Bloquear "tarefa criada ou editada em modo automático tem que ficar com status: rascunho; só o dono libera" }
      }
      if ($ferramenta -eq "Write" -and (Test-Path -LiteralPath $p) -and $rel -notmatch '^(propostas|inbox)\\') {
        Bloquear "não reescreva uma nota inteira em modo automático; use Edit para anexar"
      }
    }
  }
}
exit 0
