param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot,

  [switch]$AllowExternalBackend
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
  throw "ProjectRoot 不存在：$ProjectRoot"
}

$projectPath = (Resolve-Path -LiteralPath $ProjectRoot).Path
$sourceRoots = @(
  (Join-Path $projectPath "backend-library\src"),
  (Join-Path $projectPath "service-library\src")
) | Where-Object { Test-Path -LiteralPath $_ -PathType Container }

if ($sourceRoots.Count -eq 0) {
  throw "未找到 backend-library/src 或 service-library/src，无法校验后端运行模式。"
}

$extensions = @(".java", ".kt", ".properties", ".yml", ".yaml", ".xml")
$files = @($sourceRoots | ForEach-Object {
  Get-ChildItem -LiteralPath $_ -Recurse -File | Where-Object {
    $extensions -contains $_.Extension.ToLowerInvariant()
  }
})

$combined = New-Object System.Text.StringBuilder
foreach ($file in $files) {
  [void]$combined.AppendLine((Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8))
}
$text = $combined.ToString()

if ($AllowExternalBackend) {
  Write-Host "后端模式校验通过：已由用户明确启用外部后端转发模式。外部地址只能来自服务端或平台环境配置。"
  exit 0
}

$rules = @(
  @{ Name = "外部后端配置键"; Pattern = '(?i)\b[a-z0-9_.-]*backend[._-](?:base[._-]?url|url|host)\b' },
  @{ Name = "外部后端环境变量"; Pattern = '\b[A-Z][A-Z0-9_]*BACKEND_(?:BASE_)?(?:URL|HOST)\b' },
  @{ Name = "外部上游地址变量"; Pattern = '(?i)\b(?:backend|upstream|target)(?:Base)?(?:Url|Host)\b' },
  @{ Name = "外部转发实现"; Pattern = '(?i)\b(?:forwardRequest|proxyToUpstream|forwardToBackend)\b' },
  @{ Name = "缺少外部后端地址提示"; Pattern = '未配置.{0,40}后端地址|代理服务端设置.{0,80}backend' }
)

$violations = New-Object System.Collections.Generic.List[string]
foreach ($file in $files) {
  $lineNumber = 0
  foreach ($line in Get-Content -LiteralPath $file.FullName -Encoding UTF8) {
    $lineNumber++
    foreach ($rule in $rules) {
      if ($line -match $rule.Pattern) {
        $relativePath = $file.FullName.Substring($projectPath.Length).TrimStart('\', '/')
        $violations.Add("${relativePath}:${lineNumber} $($rule.Name)：$($line.Trim())")
        break
      }
    }
  }
}

if ($violations.Count -gt 0) {
  $details = $violations -join [Environment]::NewLine
  throw "后端模式校验失败：默认必须使用依赖库内置业务逻辑和 CodeWave 平台 DataSource，不得要求客户配置平台地址或外部后端 Base URL。`n$details"
}

if ($text -notmatch '\b(?:javax\.sql\.)?DataSource\b') {
  throw "后端模式校验失败：默认内置模式未发现平台 DataSource 注入。请把 CRUD 和数据库初始化放入依赖库，不能改成外部后端转发。"
}

Write-Host "后端模式校验通过：依赖库内置业务逻辑 + CodeWave 平台 DataSource"
