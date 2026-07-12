param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot,

  [string]$ProxyBase = "/simple_proxy"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ($ProxyBase -notmatch '^/[A-Za-z0-9_/-]+$') {
  throw "ProxyBase must start with / and contain only letters, numbers, underscore, hyphen, and slash. Current value: $ProxyBase"
}

if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
  throw "ProjectRoot does not exist: $ProjectRoot"
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path

function Assert-FileContains([string]$Path, [string]$Expected, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Proxy path validation file is missing: $Path"
  }

  $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  if (-not $content.Contains($Expected)) {
    throw "$Label does not use the unified proxy path $Expected. Sync page entry JS, frontend API_BASE, Vite proxy, and Java RawController. File: $Path"
  }
}

function Assert-ExactJavaScriptPath([string]$Path, [string]$VariableName, [string]$Expected, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Proxy path validation file is missing: $Path"
  }

  $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  $pattern = '(?m)\b(?:const|let|var)\s+' + [regex]::Escape($VariableName) + '\s*=\s*([''"])(?<value>[^''"]+)\1'
  $match = [regex]::Match($content, $pattern)
  if (-not $match.Success) {
    throw "$Label variable $VariableName was not found. File: $Path"
  }

  $actual = $match.Groups["value"].Value
  if ($actual -ne $Expected) {
    throw "$Label must use the exact relative path $Expected. Do not add a domain, proxy server address, IP address, or /api prefix. Current value: $actual. File: $Path"
  }
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $ProjectRoot)

Assert-FileContains `
  -Path (Join-Path $repoRoot "skill\assets\codewave-page-entry.js") `
  -Expected "$ProxyBase/getAppHtml" `
  -Label "页面进入 JS"

Assert-FileContains `
  -Path (Join-Path $ProjectRoot "frontend\src\main.js") `
  -Expected "$ProxyBase/callApi" `
  -Label "前端 API_BASE"

Assert-FileContains `
  -Path (Join-Path $ProjectRoot "frontend\vite.config.js") `
  -Expected "'$ProxyBase'" `
  -Label "Vite 本地代理"

Assert-FileContains `
  -Path (Join-Path $ProjectRoot "backend-library\src\main\java\com\example\simpleproxy\SimpleProxyRawController.java") `
  -Expected "@RequestMapping(`"$ProxyBase`")" `
  -Label "Java RawController"

Assert-ExactJavaScriptPath `
  -Path (Join-Path $repoRoot "skill\assets\codewave-page-entry.js") `
  -VariableName "getAppHtmlUrl" `
  -Expected "$ProxyBase/getAppHtml" `
  -Label "页面进入 JS"

Assert-ExactJavaScriptPath `
  -Path (Join-Path $ProjectRoot "frontend\src\main.js") `
  -VariableName "API_BASE" `
  -Expected "$ProxyBase/callApi" `
  -Label "前端 API_BASE"

Write-Host "Proxy path consistency validation passed: $ProxyBase"
