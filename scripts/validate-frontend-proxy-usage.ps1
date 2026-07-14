param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot,

  [string]$ProxyBase = "/simple_proxy",

  [string[]]$AllowedDirectEndpoints = @("callApi", "getAppHtml")
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ($ProxyBase -notmatch '^/[A-Za-z0-9_-]+_proxy$') {
  throw "ProxyBase 必须是 /项目代号_proxy 格式。当前值：$ProxyBase"
}

if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
  throw "ProjectRoot 不存在：$ProjectRoot"
}

$projectPath = (Resolve-Path -LiteralPath $ProjectRoot).Path
$frontendRoot = Join-Path $projectPath "frontend"
if (-not (Test-Path -LiteralPath $frontendRoot -PathType Container)) {
  throw "未找到前端目录：$frontendRoot"
}

$allowed = @{}
foreach ($endpoint in $AllowedDirectEndpoints) {
  $normalized = $endpoint.Trim().TrimStart('/')
  if ($normalized) {
    $allowed[$normalized.ToLowerInvariant()] = $true
  }
}

$extensions = @(".js", ".jsx", ".ts", ".tsx", ".vue", ".html", ".mjs", ".cjs")
$excludedDirectories = @("node_modules", "dist", "build", ".git", "coverage")
$excludedFileNames = @(
  "vite.config.js", "vite.config.ts", "vite.config.mjs", "vite.config.cjs",
  "webpack.config.js", "webpack.config.ts", "rollup.config.js", "rollup.config.ts"
)
$proxyPattern = [regex]::Escape($ProxyBase) + '(?<suffix>/[A-Za-z0-9_.~-]+)?'
$apiPrefixPattern = [regex]::Escape("/api$ProxyBase")
$businessApiPrefixPattern = '(?i)[''"`][\s]*/api(?:/|[''"`])'
$absolutePattern = 'https?://[^\s''""`]+?' + [regex]::Escape($ProxyBase)
$violations = New-Object System.Collections.Generic.List[string]

$files = Get-ChildItem -LiteralPath $frontendRoot -Recurse -File | Where-Object {
  $extensions -contains $_.Extension.ToLowerInvariant() -and
  $excludedFileNames -notcontains $_.Name.ToLowerInvariant() -and
  -not ($_.FullName.Split([System.IO.Path]::DirectorySeparatorChar) | Where-Object { $excludedDirectories -contains $_ })
}

foreach ($file in $files) {
  $lineNumber = 0
  foreach ($line in Get-Content -LiteralPath $file.FullName -Encoding UTF8) {
    $lineNumber++
    $relativePath = $file.FullName.Substring($projectPath.Length).TrimStart('\', '/')

    if ([regex]::IsMatch($line, $apiPrefixPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
      $violations.Add("${relativePath}:${lineNumber} 禁止在代理路径前增加 /api：$($line.Trim())")
      continue
    }

    if ([regex]::IsMatch($line, $businessApiPrefixPattern)) {
      $violations.Add("${relativePath}:${lineNumber} 禁止在 callApi.reqPath 或业务路径中增加 /api；例如 /api/customers 必须改为 /customers：$($line.Trim())")
      continue
    }

    if ([regex]::IsMatch($line, $absolutePattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
      $violations.Add("${relativePath}:${lineNumber} 禁止写入代理域名或 IP，必须使用站内相对路径：$($line.Trim())")
      continue
    }

    foreach ($match in [regex]::Matches($line, $proxyPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
      $suffix = $match.Groups["suffix"].Value
      if (-not $suffix) {
        $violations.Add("${relativePath}:${lineNumber} 禁止在前端定义裸代理基址 $ProxyBase；请直接使用 $ProxyBase/callApi：$($line.Trim())")
        continue
      }

      $endpoint = $suffix.TrimStart('/').ToLowerInvariant()
      if (-not $allowed.ContainsKey($endpoint)) {
        $violations.Add("${relativePath}:${lineNumber} 禁止直连 $ProxyBase/$endpoint；业务路径 /$endpoint 必须放入 callApi.reqPath：$($line.Trim())")
        continue
      }

      $nextIndex = $match.Index + $match.Length
      if ($nextIndex -lt $line.Length -and $line[$nextIndex] -eq '/') {
        $violations.Add("${relativePath}:${lineNumber} 只允许固定入口 $ProxyBase/$endpoint，不允许继续拼接业务路径：$($line.Trim())")
      }
    }
  }
}

if ($violations.Count -gt 0) {
  $details = $violations -join [Environment]::NewLine
  throw "前端代理调用校验失败。除明确白名单外，所有业务请求必须统一 POST 到 $ProxyBase/callApi。`n$details"
}

$allowedText = ($allowed.Keys | Sort-Object) -join ", "
Write-Host "前端代理调用校验通过：$ProxyBase；允许的直接入口：$allowedText"
