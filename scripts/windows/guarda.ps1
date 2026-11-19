# Hook PreToolUse (matcher Bash|PowerShell|Write|Edit|MultiEdit): barreira determinística.
# Exit 2 bloqueia a ferramenta e a mensagem em stderr volta para o Claude.
# Em sessão interativa bloqueia só o catastrófico. Em loop/agente autônomo (CEREBRO_LOOP=1) é mais rígido.
$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "lib.ps1")
$entrada = ""
if ([Console]::IsInputRedirected) { $entrada = [Console]::In.ReadToEnd() }
try { $j = $entrada | ConvertFrom-Json } catch { exit 0 }

$ferramenta = [string]$j.tool_name
$cmd = [string]$j.tool_input.command
$arquivo = [string]$j.tool_input.file_path
$conteudo = ([string]$j.tool_input.content) + ([string]$j.tool_input.new_string)
$autonomo = ($env:CEREBRO_LOOP -eq "1")

function Bloquear([string]$Motivo) {
  Write-CerebroLog "Guarda" ("bloqueado ({0}): {1}" -f $ferramenta, $Motivo)
  [Console]::Error.WriteLine("Bloqueado pela guarda do cérebro: $Motivo. Escolha outro caminho ou peça ao dono.")
  exit 2
}

if ($ferramenta -in @("Bash", "PowerShell")) {
  $sempre = @(
    @('git\s+push\b.*(\s--force\b|\s-f\b|\s--force-with-lease\b)', 'push forçado'),
    @('\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)\s+(/|~|\$HOME|[A-Za-z]:[\\/]?)(\s|$)', 'apagar raiz ou home'),
    @('Remove-Item\b.*-Recurse.*\s([A-Za-z]:\\?|~|\$HOME|\$env:USERPROFILE)(\s|$)', 'apagar raiz ou home'),
    @('(curl|wget|iwr|Invoke-WebRequest)\b[^|]*\|\s*(sh|bash|iex|Invoke-Expression)\b', 'executar script baixado da internet'),
    @('\b(DROP\s+(DATABASE|TABLE)|TRUNCATE\s+TABLE)\b', 'comando destrutivo de banco'),
    @('\bformat\s+[A-Za-z]:', 'formatar disco')
  )
  foreach ($r in $sempre) { if ($cmd -match $r[0]) { Bloquear $r[1] } }

  if ($autonomo) {
    $loop = @(
      @('\bgit\s+push\b', 'agente autônomo não faz push; o executor cuida disso'),
      @('\bgh\s+pr\s+(merge|close)\b', 'agente autônomo não faz merge'),
      @('\bgit\s+(reset\s+--hard|clean\s+-[a-zA-Z]*f|checkout\s+(main|master)\b|rebase\b)', 'comando git que perde trabalho ou troca de base'),
      @('--no-verify\b', 'pular hooks de verificação'),
      @('\b(npm|pnpm|yarn)\s+publish\b', 'publicar pacote'),
      @('\b(terraform|kubectl|helm)\s+(apply|delete|destroy|upgrade|install)\b', 'mexer em infraestrutura'),
      @('\b(sudo|runas)\b', 'elevar privilégio')
    )
    foreach ($r in $loop) { if ($cmd -match $r[0]) { Bloquear $r[1] } }
  }
}

if ($ferramenta -in @("Write", "Edit", "MultiEdit")) {
  if ($arquivo -match '(^|[\\/])(\.env(\.[\w-]+)?|id_rsa|id_ed25519|.*\.pem|.*\.pfx|credentials(\.json)?)$' -and $arquivo -notmatch '\.env\.(example|sample|template)$') {
    Bloquear "escrever arquivo de segredo ($arquivo)"
  }
  if ((Hide-Segredos $conteudo) -ne $conteudo -and $conteudo -match '(github_pat_|gh[pousr]_|sk-ant-|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|xox[abprs]-)') {
    Bloquear "o conteúdo parece ter um segredo; use variável de ambiente"
  }
  if ($autonomo) {
    $vaultNorm = ($Vault -replace '/', '\').TrimEnd('\') + '\'
    $arqNorm = $arquivo -replace '/', '\'
    if ($arqNorm.StartsWith($vaultNorm, [StringComparison]::OrdinalIgnoreCase) -and
        $arqNorm -notmatch '\\(propostas|inbox|tarefas)\\') {
      Bloquear "agente autônomo só escreve em propostas/, inbox/ ou tarefas/ do vault"
    }
  }
}
exit 0
