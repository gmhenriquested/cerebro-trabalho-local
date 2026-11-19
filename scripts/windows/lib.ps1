# Biblioteca comum do cérebro (Windows PowerShell 5.1).
# Carregada com:  . (Join-Path $PSScriptRoot "lib.ps1")
# Lê config.ps1 (gerado pelo instalador) com $Vault, $ClaudeExe e $TemGitBash.

[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
$Utf8SemBom = New-Object System.Text.UTF8Encoding $false
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['Add-Content:Encoding'] = 'UTF8'

$Config = Join-Path $PSScriptRoot "config.ps1"
if (Test-Path $Config) { . $Config }
if (-not $Vault) { $Vault = Join-Path $HOME "cerebro-trabalho" }
$Vault = [System.IO.Path]::GetFullPath($Vault).TrimEnd('\')
if (-not $ClaudeExe) { $ClaudeExe = "claude" }
if ($null -eq $TemGitBash) { $TemGitBash = $true }

$State = Join-Path $HOME ".claude\state\cerebro"
$Log   = Join-Path $State "cerebro.log"
$Metricas = Join-Path $Vault "metricas"
$LoopSettings = Join-Path $PSScriptRoot "loop-settings.json"
New-Item -ItemType Directory -Force -Path $State | Out-Null

function Write-CerebroLog([string]$Origem, [string]$Msg) {
  try { Add-Content -Path $Log -Encoding UTF8 -Value ("{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Origem, $Msg) } catch {}
}

function Read-Arquivo([string]$Caminho) {
  if (-not $Caminho -or -not (Test-Path -LiteralPath $Caminho)) { return "" }
  return [System.IO.File]::ReadAllText($Caminho, [System.Text.Encoding]::UTF8)
}

function Write-Arquivo([string]$Caminho, [string]$Texto) {
  $dir = Split-Path -Parent $Caminho
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($Caminho, $Texto, $Utf8SemBom)
}

function Add-Arquivo([string]$Caminho, [string]$Texto) {
  $dir = Split-Path -Parent $Caminho
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::AppendAllText($Caminho, $Texto, $Utf8SemBom)
}

# Lê o JSON que o Claude Code manda no stdin dos hooks, sempre em UTF-8
# (o [Console]::In usa a página OEM do Windows e quebra caminhos com acento).
function Read-EntradaHook {
  try {
    $sr = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))
    return $sr.ReadToEnd()
  } catch { return "" }
}

# Trava atômica por diretório. Trava com mais de 3h é considerada abandonada.
function Enter-Trava([string]$Nome) {
  $lock = Join-Path $State "$Nome.lock"
  if ((Test-Path $lock) -and (Get-Item $lock).LastWriteTime -lt (Get-Date).AddHours(-3)) {
    Remove-Item $lock -Force -Recurse -ErrorAction SilentlyContinue
  }
  try { New-Item -ItemType Directory -Path $lock -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}
function Exit-Trava([string]$Nome) {
  Remove-Item (Join-Path $State "$Nome.lock") -Force -Recurse -ErrorAction SilentlyContinue
}

# Lê <vault>\config\cerebro.json (ou um objeto vazio).
function Get-ConfigCerebro {
  $arq = Join-Path $Vault "config\cerebro.json"
  if (Test-Path $arq) { try { return ((Read-Arquivo $arq) | ConvertFrom-Json) } catch {} }
  return (New-Object PSObject)
}

# Loop ligado? (config loops.<nome>.ativo; padrão = ligado, exceto o que vier com $PadraoDesligado)
function Test-LoopAtivo([string]$Nome, [switch]$PadraoDesligado) {
  $cfg = Get-ConfigCerebro
  $l = $null
  if ($cfg.loops) { $l = $cfg.loops.$Nome }
  if ($l -and $null -ne $l.ativo) { return [bool]$l.ativo }
  return (-not $PadraoDesligado)
}

# Modelo de um papel (colhedor, juiz, executor...) ou de um agente, pelo config modelos.
function Get-ModeloPapel([string]$Papel) {
  $cfg = Get-ConfigCerebro
  if ($cfg.modelos) {
    if ($cfg.modelos.papeis -and $cfg.modelos.papeis.$Papel) { return [string]$cfg.modelos.papeis.$Papel }
    if ($cfg.modelos.agentes -and $cfg.modelos.agentes.$Papel) { return [string]$cfg.modelos.agentes.$Papel }
    if ($cfg.modelos.padrao) { return [string]$cfg.modelos.padrao }
  }
  return ""
}

function Add-Metrica([string]$Arquivo, [string]$Cabecalho, [string]$Linha) {
  $arq = Join-Path $Metricas $Arquivo
  if (-not (Test-Path $arq)) { Write-Arquivo $arq "$Cabecalho`n" }
  Add-Arquivo $arq "$Linha`n"
}

# Roda o Claude em modo não interativo e devolve o texto final ("" se falhou).
#  -Papel     nome usado para escolher o modelo (config modelos) e para as métricas
#  -Raizes    pastas onde o agente pode escrever (a guarda nega todo o resto)
#  -Escrita   liga a escrita automática de baixo risco no vault
# CEREBRO_LOOP=1 silencia os hooks de ritual; a guarda continua e falha fechado.
# --setting-sources user ignora .claude/settings.json de projeto (um repo não amplia permissões);
# --settings loop-settings.json garante a guarda e as regras deny mesmo sem merge no settings do dono.
function Invoke-Claude {
  param(
    [Parameter(Mandatory = $true)][string]$Prompt,
    [string]$Papel = "loop",
    [string]$Tools = "Read,Grep,Glob",
    [string]$Allowed = "",
    [string]$Dir = $Vault,
    [string]$Modelo = "",
    [string]$Agente = "",
    [int]$MaxTurnos = 40,
    [string[]]$AddDir = @(),
    [string[]]$Raizes = @(),
    [switch]$Escrita
  )
  $ErrorActionPreference = "Continue"
  if (-not $Modelo) { $Modelo = Get-ModeloPapel $Papel }
  if (-not $Allowed) { $Allowed = $Tools }   # em dontAsk, ferramenta fora de --allowedTools é negada
  $env:CEREBRO_LOOP = "1"
  $env:CEREBRO_PAPEL = $Papel
  if ($Escrita) { $env:CEREBRO_ESCRITA = "auto" } else { $env:CEREBRO_ESCRITA = "" }
  $env:CEREBRO_RAIZES = (($Raizes | Where-Object { $_ } | ForEach-Object { [System.IO.Path]::GetFullPath($_).TrimEnd('\') }) -join ";")

  if (-not (Test-Path -LiteralPath $Dir)) { Write-CerebroLog $Papel "pasta inexistente: $Dir"; return "" }
  $id = [guid]::NewGuid().ToString("N").Substring(0, 8)
  $tmp = Join-Path $State "prompt-$id.md"
  Write-Arquivo $tmp $Prompt
  $a = @("-p", "--output-format", "json", "--no-session-persistence", "--tools", $Tools,
         "--allowedTools", $Allowed, "--permission-mode", "dontAsk", "--max-turns", "$MaxTurnos",
         "--setting-sources", "user")
  if (Test-Path $LoopSettings) { $a += @("--settings", $LoopSettings) }
  if ($Modelo) { $a += @("--model", $Modelo) }
  if ($Agente) { $a += @("--agent", $Agente) }
  foreach ($d in $AddDir) { $a += @("--add-dir", $d) }

  $inicio = Get-Date
  $bruto = @()
  Push-Location -LiteralPath $Dir -ErrorAction Stop
  try {
    $bruto = @(Get-Content -Raw -Encoding UTF8 $tmp | & $ClaudeExe @a 2>&1)
    $codigo = $LASTEXITCODE
  } finally {
    Pop-Location
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  }
  $saida = ($bruto | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | Out-String).Trim()
  $erros = ($bruto | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { $_.ToString() }) -join " "
  if ($erros) { Write-CerebroLog $Papel ("stderr: " + (Hide-Segredos $erros)) }

  $texto = ""; $ok = $false; $custo = ""; $turnos = ""
  try {
    $j = $saida | ConvertFrom-Json
    $custo = [string]$j.total_cost_usd; $turnos = [string]$j.num_turns
    if (-not $j.is_error -and $j.subtype -eq "success") { $texto = [string]$j.result; $ok = $true }
    else { Write-CerebroLog $Papel ("falhou: {0} {1}" -f $j.subtype, ([string]$j.result).Substring(0, [Math]::Min(200, ([string]$j.result).Length))) }
  } catch {
    Write-CerebroLog $Papel ("saída inesperada (código {0}): {1}" -f $codigo, $saida.Substring(0, [Math]::Min(200, $saida.Length)))
  }
  $seg = [int]((Get-Date) - $inicio).TotalSeconds
  $mod = $Modelo; if (-not $mod) { $mod = "padrao" }
  Add-Metrica "loops.csv" "data,papel,modelo,ok,custo_usd,turnos,segundos" ("{0},{1},{2},{3},{4},{5},{6}" -f (Get-Date -Format "yyyy-MM-dd HH:mm"), $Papel, $mod, $ok, $custo, $turnos, $seg)
  return $texto
}

# Resposta do modelo que diz "não há nada"? (aceita crases, preâmbulo curto e pontuação)
function Test-Vazio([string]$Texto) {
  if (-not $Texto.Trim()) { return $true }
  $semCodigo = ($Texto -replace '`', '').Trim()
  return ($semCodigo -match '(?m)^\s*(SEM_PROPOSTAS|NADA_A_COLHER)\.?\s*$' -and $semCodigo -notmatch '(?m)^## ')
}

# Separa a saída de um loop:
#  - seção "## Aplicado automaticamente" -> anexada ao log do dia propostas/AAAA-MM-DD-auto.md
#  - propostas pendentes -> propostas/AAAA-MM-DD-<nome>.md (só se houver alguma)
function Save-Resultado([string]$Nome, [string]$Texto) {
  if (Test-Vazio $Texto) { Write-CerebroLog $Nome "nada a registrar"; return $null }
  $Texto = Hide-Segredos $Texto
  $hoje = Get-Date -Format "yyyy-MM-dd"
  $auto = [regex]::Match($Texto, '(?s)## Aplicado automaticamente.*?(?=\r?\n## |\z)')
  if ($auto.Success) {
    $logAuto = Join-Path $Vault "propostas\$hoje-auto.md"
    if (-not (Test-Path $logAuto)) { Write-Arquivo $logAuto "# Aplicado automaticamente em $hoje`n`nO semanal relê estas mudanças. Para desfazer: git revert do commit correspondente.`n" }
    $corpo = ($auto.Value -replace '(?m)^## Aplicado automaticamente\s*', '').Trim()
    Add-Arquivo $logAuto ("`n## {0} ({1})`n{2}`n" -f $Nome, (Get-Date -Format "HH:mm"), $corpo)
  }
  if ($Texto -match '\*\*Status:\*\*\s*pendente') {
    $semAuto = $Texto
    if ($auto.Success) { $semAuto = $Texto.Replace($auto.Value, "") }
    $arq = Join-Path $Vault ("propostas\{0}-{1}.md" -f $hoje, $Nome)
    if (Test-Path $arq) { $arq = $arq -replace '\.md$', ("-{0}.md" -f (Get-Date -Format "HHmm")) }
    Write-Arquivo $arq $semAuto.Trim()
    Write-CerebroLog $Nome "propostas em $arq"
    return $arq
  }
  return $null
}
# Compatibilidade com o nome antigo.
function Save-Proposta([string]$Nome, [string]$Texto) { return (Save-Resultado $Nome $Texto) }

# Lista as propostas pendentes: objetos com Arquivo, Titulo e Tipo.
function Get-PropostasPendentes {
  $lista = @()
  foreach ($f in (Get-ChildItem (Join-Path $Vault "propostas") -Filter *.md -ErrorAction SilentlyContinue | Sort-Object Name)) {
    $blocos = [regex]::Split((Read-Arquivo $f.FullName), '(?m)^(?=## )')
    foreach ($b in $blocos) {
      if ($b -match '\*\*Status:\*\*\s*pendente') {
        $titulo = (($b -split '\r?\n')[0] -replace '^##\s*', '').Trim()
        $tipo = [regex]::Match($b, '\*\*Tipo:\*\*\s*([^\r\n]+)').Groups[1].Value.Trim()
        $lista += New-Object PSObject -Property @{ Arquivo = $f.Name; Titulo = $titulo; Tipo = $tipo }
      }
    }
  }
  return $lista
}

# Lê o frontmatter YAML simples (chave: valor) de uma nota.
function Get-Frontmatter([string]$Texto) {
  $fm = @{}
  if ($Texto -notmatch '^﻿?---\r?\n') { return $null }
  $m = [regex]::Match($Texto, '^﻿?---\r?\n([\s\S]*?)\r?\n---')
  if (-not $m.Success) { return $null }
  foreach ($linha in ($m.Groups[1].Value -split '\r?\n')) {
    $kv = [regex]::Match($linha, '^([A-Za-z_][\w-]*):\s*(.*)$')
    if ($kv.Success) { $fm[$kv.Groups[1].Value] = $kv.Groups[2].Value.Trim() }
  }
  return $fm
}

function Set-CampoFrontmatter([string]$Texto, [string]$Campo, [string]$Valor) {
  $re = New-Object System.Text.RegularExpressions.Regex ("(?m)^{0}:[^\r\n]*" -f [regex]::Escape($Campo))
  if ($re.IsMatch($Texto)) { return $re.Replace($Texto, "${Campo}: $Valor", 1) }
  $abre = New-Object System.Text.RegularExpressions.Regex '^(﻿?---\r?\n)'
  return $abre.Replace($Texto, "`$1${Campo}: $Valor`n", 1)
}

# Mascara segredos antes de mandar texto para um modelo ou gravar em arquivo.
$PadroesSegredo = @(
  'github_pat_\w+', 'gh[pousr]_[A-Za-z0-9]{20,}', 'sk-ant-[\w-]+', 'sk-[A-Za-z0-9_-]{20,}',
  'AKIA[0-9A-Z]{16}', 'xox[abprs]-[\w-]+', '(?i)bearer\s+\S+', 'eyJ[\w-]+\.[\w-]+\.[\w-]+',
  '(?i)(senha|password|pwd|token|secret|api[_-]?key)\s*[:=]\s*\S+',
  '\b(?=[A-Za-z0-9_\-]*\d)(?=[A-Za-z0-9_\-]*[A-Za-z])[A-Za-z0-9_\-]{32,}\b'
)
function Hide-Segredos([string]$Texto) {
  foreach ($p in $PadroesSegredo) { $Texto = [regex]::Replace($Texto, $p, "[SEGREDO REMOVIDO]") }
  return $Texto
}

function Get-Prompt([string]$Nome) {
  return Read-Arquivo (Join-Path $PSScriptRoot "prompts\$Nome.md")
}

# Commit + push do vault no fim de um loop (mesma lógica do hook de sync).
function Sync-Vault([string]$Origem) {
  & (Join-Path $PSScriptRoot "sync.ps1") -Origem $Origem -Worker
}
