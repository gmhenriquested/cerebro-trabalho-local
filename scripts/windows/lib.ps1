# Biblioteca comum do cérebro de trabalho (Windows PowerShell 5.1).
# Carregada com:  . (Join-Path $PSScriptRoot "lib.ps1")
# Lê config.ps1 (gerado pelo instalador) com $Vault e $ClaudeExe.

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
$Utf8SemBom = New-Object System.Text.UTF8Encoding $false

$Config = Join-Path $PSScriptRoot "config.ps1"
if (Test-Path $Config) { . $Config }
if (-not $Vault) { $Vault = Join-Path $HOME "cerebro-trabalho" }
if (-not $ClaudeExe) { $ClaudeExe = "claude" }

$State = Join-Path $HOME ".claude\state\cerebro"
$Log   = Join-Path $State "cerebro.log"
New-Item -ItemType Directory -Force -Path $State | Out-Null

function Write-CerebroLog([string]$Origem, [string]$Msg) {
  Add-Content -Path $Log -Encoding UTF8 -Value ("{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Origem, $Msg)
}

function Read-Arquivo([string]$Caminho) {
  if (-not (Test-Path $Caminho)) { return "" }
  return [System.IO.File]::ReadAllText($Caminho, [System.Text.Encoding]::UTF8)
}

function Write-Arquivo([string]$Caminho, [string]$Texto) {
  $dir = Split-Path -Parent $Caminho
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($Caminho, $Texto, $Utf8SemBom)
}

# Trava por diretório: impede duas execuções do mesmo loop. Trava com mais de 3h é descartada.
function Enter-Trava([string]$Nome) {
  $lock = Join-Path $State "$Nome.lock"
  if (Test-Path $lock) {
    if ((Get-Item $lock).LastWriteTime -lt (Get-Date).AddHours(-3)) { Remove-Item $lock -Force -Recurse }
    else { return $false }
  }
  New-Item -ItemType Directory -Path $lock -ErrorAction SilentlyContinue | Out-Null
  return (Test-Path $lock)
}
function Exit-Trava([string]$Nome) {
  Remove-Item (Join-Path $State "$Nome.lock") -Force -Recurse -ErrorAction SilentlyContinue
}

# Roda o Claude em modo não interativo.
# CEREBRO_LOOP=1 faz os hooks de ritual (contexto, colhedor, sync) ficarem quietos;
# o hook de guarda continua ativo e fica mais rígido.
function Invoke-Claude {
  param(
    [Parameter(Mandatory = $true)][string]$Prompt,
    [string]$Tools = "Read,Grep,Glob",
    [string]$Allowed = "",
    [string]$Dir = $Vault,
    [string]$Modo = "dontAsk",
    [int]$MaxTurnos = 40,
    [string[]]$AddDir = @(),
    [switch]$Escrita
  )
  $env:CEREBRO_LOOP = "1"
  # Escrita automática de baixo risco no vault (a guarda decide onde pode).
  if ($Escrita) { $env:CEREBRO_ESCRITA = "auto" } else { $env:CEREBRO_ESCRITA = "" }
  $tmp = Join-Path $State ("prompt-{0}.md" -f ([guid]::NewGuid().ToString("N").Substring(0, 8)))
  Write-Arquivo $tmp $Prompt
  $argsClaude = @("-p", "--no-session-persistence", "--tools", $Tools, "--permission-mode", $Modo, "--max-turns", "$MaxTurnos")
  if ($Allowed) { $argsClaude += @("--allowedTools", $Allowed) }
  foreach ($d in $AddDir) { $argsClaude += @("--add-dir", $d) }
  Push-Location $Dir
  try {
    $saida = Get-Content -Raw -Encoding UTF8 $tmp | & $ClaudeExe @argsClaude 2>> $Log
  } finally {
    Pop-Location
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  }
  return (($saida | Out-String).Trim())
}

# Lê <vault>\config\cerebro.json (ou um objeto vazio).
function Get-ConfigCerebro {
  $arq = Join-Path $Vault "config\cerebro.json"
  if (Test-Path $arq) { try { return ((Read-Arquivo $arq) | ConvertFrom-Json) } catch {} }
  return (New-Object PSObject)
}

# Lista as propostas pendentes: objetos com Arquivo e Titulo.
function Get-PropostasPendentes {
  $lista = @()
  foreach ($f in (Get-ChildItem (Join-Path $Vault "propostas") -Filter *.md -ErrorAction SilentlyContinue | Sort-Object Name)) {
    $blocos = [regex]::Split((Read-Arquivo $f.FullName), '(?m)^(?=## )')
    foreach ($b in $blocos) {
      if ($b -match '\*\*Status:\*\*\s*pendente') {
        $titulo = (($b -split '\r?\n')[0] -replace '^##\s*', '').Trim()
        $lista += New-Object PSObject -Property @{ Arquivo = $f.Name; Titulo = $titulo }
      }
    }
  }
  return $lista
}

# Grava a saída de um loop em propostas/AAAA-MM-DD-<nome>.md (ou não grava, se não houver nada).
function Save-Proposta([string]$Nome, [string]$Texto) {
  if (-not $Texto -or $Texto -match '^\s*(SEM_PROPOSTAS|NADA_A_COLHER)') {
    Write-CerebroLog $Nome "rodou, sem propostas"
    return $null
  }
  $arq = Join-Path $Vault ("propostas\{0}-{1}.md" -f (Get-Date -Format "yyyy-MM-dd"), $Nome)
  if (Test-Path $arq) { $arq = $arq -replace '\.md$', ("-{0}.md" -f (Get-Date -Format "HHmm")) }
  Write-Arquivo $arq $Texto
  Write-CerebroLog $Nome "propostas em $arq"
  return $arq
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
