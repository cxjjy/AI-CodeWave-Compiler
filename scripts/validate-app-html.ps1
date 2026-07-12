param(
  [Parameter(Mandatory = $true)]
  [string]$HtmlPath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $HtmlPath -PathType Leaf)) {
  throw "前端入口文件不存在：$HtmlPath"
}

$html = Get-Content -LiteralPath $HtmlPath -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($html)) {
  throw "前端入口文件为空：$HtmlPath"
}

$requiredPatterns = [ordered]@{
  "<!doctype html>" = '(?is)^\s*<!doctype\s+html\b'
  "<html>" = '(?is)<html\b'
  "</html>" = '(?is)</html\s*>'
  "<head>" = '(?is)<head\b'
  "<body>" = '(?is)<body\b'
  "</body>" = '(?is)</body\s*>'
}

$missing = @()
foreach ($item in $requiredPatterns.GetEnumerator()) {
  if ($html -notmatch $item.Value) {
    $missing += $item.Key
  }
}

if ($missing.Count -gt 0) {
  throw "getAppHtml 只能返回完整 HTML 文档，当前文件缺少：$($missing -join '、')。禁止只返回 style、script 或 body 片段。"
}

$externalAssets = [regex]::Matches(
  $html,
  '(?is)<(?:script|link)\b[^>]*(?:src|href)\s*=\s*["''](?:/|\./)?assets/'
)
if ($externalAssets.Count -gt 0) {
  throw "前端入口仍引用 assets 分包资源。请先构建为单文件 HTML，再放入代理依赖库。"
}

$invalidBusinessPaths = [regex]::Matches(
  $html,
  '(?i)[''"`][\s]*/api(?:/|[''"`])'
)
if ($invalidBusinessPaths.Count -gt 0) {
  throw "前端入口仍包含 /api/... 业务路径。callApi 的 reqPath 禁止携带 /api 前缀，例如 /api/customers 必须改为 /customers。"
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
  throw "未找到 Node.js，无法校验内联 JavaScript。必须先安装 Node.js 并通过语法校验，禁止跳过后交付。"
}

$scripts = [regex]::Matches(
  $html,
  '(?is)<script\b(?![^>]*\bsrc\s*=)([^>]*)>(.*?)</script\s*>'
)
$index = 0
foreach ($script in $scripts) {
  $attributes = $script.Groups[1].Value
  $typeMatch = [regex]::Match($attributes, '(?is)\btype\s*=\s*["'']([^"'']+)["'']')
  if ($typeMatch.Success -and $typeMatch.Groups[1].Value -notmatch '^(?:module|text/javascript|application/javascript)$') {
    continue
  }

  $source = $script.Groups[2].Value
  if ([string]::IsNullOrWhiteSpace($source)) {
    continue
  }

  $index++
  $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ("codewave-app-script-{0}-{1}.mjs" -f $PID, $index)
  try {
    [System.IO.File]::WriteAllText($tempFile, $source, [System.Text.UTF8Encoding]::new($false))
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $node.Source
    $startInfo.Arguments = "--check `"$tempFile`""
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
      $syntaxMessage = ($stderr + [Environment]::NewLine + $stdout).Trim()
      throw "前端入口中的第 $index 个内联脚本语法校验失败。请修复顶层 return、括号缺失或其他 JavaScript 语法错误。Node 输出：$syntaxMessage"
    }
  } finally {
    if (Test-Path -LiteralPath $tempFile) {
      Remove-Item -LiteralPath $tempFile -Force
    }
  }
}

Write-Host "getAppHtml 前端入口校验通过：$HtmlPath"
