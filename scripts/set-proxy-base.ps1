param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot,

  [string]$ProjectCode,

  [string]$ProxyBase,

  [string]$OldProxyBase = "/simple_proxy"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Convert-ToProjectCode([string]$Value) {
  $normalized = $Value.Trim().ToLowerInvariant()
  $normalized = $normalized -replace '[^a-z0-9]+', '_'
  $normalized = $normalized.Trim('_')
  if ([string]::IsNullOrWhiteSpace($normalized)) {
    throw "ProjectCode cannot be empty. Examples: crm, oa, erp."
  }
  return $normalized
}

if ([string]::IsNullOrWhiteSpace($ProxyBase)) {
  if ([string]::IsNullOrWhiteSpace($ProjectCode)) {
    throw "Pass ProjectCode or ProxyBase. Example: -ProjectCode crm generates /crm_proxy."
  }
  $ProxyBase = "/" + (Convert-ToProjectCode $ProjectCode) + "_proxy"
}

if ($ProxyBase -notmatch '^/[a-z0-9]+(?:_[a-z0-9]+)*_proxy$') {
  throw "ProxyBase must use /project_code_proxy format, for example /crm_proxy or /oa_proxy. Current value: $ProxyBase"
}

if ($OldProxyBase -notmatch '^/[A-Za-z0-9_/-]+$') {
  throw "OldProxyBase format is invalid: $OldProxyBase"
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $ProjectRoot)
$files = @(
  (Join-Path $repoRoot "skill\assets\codewave-page-entry.js"),
  (Join-Path $ProjectRoot "frontend\src\main.js"),
  (Join-Path $ProjectRoot "frontend\vite.config.js"),
  (Join-Path $ProjectRoot "backend-library\src\main\java\com\example\simpleproxy\SimpleProxyRawController.java"),
  (Join-Path $ProjectRoot "README.md"),
  (Join-Path $ProjectRoot "docs\codewave-import-usage.md"),
  (Join-Path $repoRoot "docs\manual.md"),
  (Join-Path $repoRoot "docs\troubleshooting.md")
)

foreach ($path in $files) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    continue
  }

  $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8
  $updated = $content.Replace($OldProxyBase, $ProxyBase)
  if ($updated -ne $content) {
    Set-Content -LiteralPath $path -Value $updated -Encoding UTF8 -NoNewline
    Write-Host "Updated proxy path: $path"
  }
}

$validator = Join-Path $repoRoot "skill\scripts\validate-proxy-path-consistency.ps1"
if (Test-Path -LiteralPath $validator -PathType Leaf) {
  & $validator -ProjectRoot $ProjectRoot -ProxyBase $ProxyBase
}

Write-Host "Proxy path synchronized: $ProxyBase"
