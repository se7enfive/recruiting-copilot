# install-51job.ps1 - 一键安装 51job CLI（Windows PowerShell）
# 用法: powershell -ExecutionPolicy Bypass -File install-51job.ps1 [-CheckOnly]
# 需要: Node.js 20+ / npm / git（均需在 PATH 中）

param(
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
$SJOB_CLI_SOURCE = if ($env:SJOB_CLI_SOURCE) { $env:SJOB_CLI_SOURCE } else { "51job-cli" }

function Die([string]$msg) {
    Write-Host "Error: $msg" -ForegroundColor Red
    exit 1
}

# --- 1. 前置检查 ---
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Die "Node.js 20 or newer is required (node not found)." }
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { Die "npm is required (npm not found)." }

$nodeMajor = & node -p "process.versions.node.split('.')[0]" 2>$null
if ($nodeMajor -notmatch '^\d+$') { Die "could not parse Node.js version: $nodeMajor" }
if ([int]$nodeMajor -lt 20) { Die "Node.js 20 or newer is required (found v$nodeMajor)." }

$npmPrefix = & npm config get prefix
if ([string]::IsNullOrWhiteSpace($npmPrefix)) { Die "npm global prefix is empty." }

Write-Host "Node.js: v$nodeMajor"
Write-Host "npm global prefix: $npmPrefix"
Write-Host "51job CLI source: $SJOB_CLI_SOURCE"

# --- 2. 检测 PATH（Windows npm 全局 bin 默认 %APPDATA%\npm）---
$npmBin = Join-Path $npmPrefix ""  # npm prefix 已是全局 bin 所在（Windows）
$inPath = ($env:PATH -split ';') | Where-Object { $_ -and $_.TrimEnd('\') -eq $npmBin.TrimEnd('\') }
if (-not $inPath) {
    if ($CheckOnly) {
        Write-Host "PATH needs update: add $npmBin"
    } else {
        $env:PATH = "$npmBin;$env:PATH"
        Write-Host "Added $npmBin to PATH for this session. Reopen terminal for permanent effect."
    }
}

if ($CheckOnly) {
    Write-Host "Check only: no packages were installed."
    exit 0
}

# --- 3. 已装直接跳过 ---
if (Get-Command 51job -ErrorAction SilentlyContinue) {
    $exe = (Get-Command 51job).Source
    Write-Host "51job CLI already available at $exe"
    exit 0
}

# --- 4. 安装（默认 npm 包；git+ 源才走 clone/build/pack）---
$installSource = $SJOB_CLI_SOURCE
$buildDir = $null
if ($SJOB_CLI_SOURCE -like 'git+*#*') {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Die "git is required to build the 51job CLI from a git source." }
    $repo = $SJOB_CLI_SOURCE -replace '^git\+', ''
    $repo = $repo -replace '#.*$', ''
    $ref = if ($SJOB_CLI_SOURCE -match '#([^#]+)$') { $Matches[1] } else { 'main' }
    if ([string]::IsNullOrWhiteSpace($repo)) { Die "51job CLI repository is empty." }

    $buildDir = Join-Path $env:TEMP ("51job-cli-" + [System.IO.Path]::GetRandomFileName())
    try {
        Write-Host "Cloning 51job CLI ($ref)..."
        git clone --depth 1 --branch $ref $repo (Join-Path $buildDir "source")
        Write-Host "Building 51job CLI..."
        Push-Location (Join-Path $buildDir "source")
        try {
            npm ci
            npm run build
            npm pack --pack-destination $buildDir
        } finally {
            Pop-Location
        }
        $tgz = Get-ChildItem -Path $buildDir -Filter "*.tgz" | Select-Object -First 1
        if (-not $tgz) { Die "51job CLI build did not produce a package archive." }
        $installSource = $tgz.FullName
    } catch {
        if ($buildDir -and (Test-Path $buildDir)) { Remove-Item -Recurse -Force $buildDir }
        throw
    }
}

try {
    Write-Host "Installing 51job CLI globally..."
    npm install -g $installSource
} finally {
    if ($buildDir -and (Test-Path $buildDir)) { Remove-Item -Recurse -Force $buildDir }
}

# --- 5. 验证 ---
$sjobExe = Get-Command 51job -ErrorAction SilentlyContinue
if (-not $sjobExe) { Die "51job CLI executable not found after install." }
& $sjobExe.Source --version *>$null
if ($LASTEXITCODE -ne 0) { Die "51job CLI installed but failed to run --version." }
Write-Host "51job CLI ready: $($sjobExe.Source)"
Write-Host "Next: run '51job login' once (headed browser window will open for QR scan)."