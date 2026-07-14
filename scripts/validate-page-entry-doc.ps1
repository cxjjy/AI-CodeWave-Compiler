param(
  [Parameter(Mandatory = $true)]
  [string]$ScriptPath,

  [Parameter(Mandatory = $true)]
  [string[]]$DocPath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
  throw "标准页面进入脚本不存在：$ScriptPath"
}

function Normalize-Text([string]$Value) {
  return (($Value -replace "`r`n", "`n") -replace "`r", "`n").Trim()
}

$scriptText = Normalize-Text (Get-Content -LiteralPath $ScriptPath -Raw -Encoding UTF8)
$pattern = '(?s)```js\s*(.*?)\s*```'

foreach ($path in $DocPath) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "页面进入教程文档不存在：$path"
  }

  $document = Get-Content -LiteralPath $path -Raw -Encoding UTF8
  if ($document -match 'CODEWAVE_PAGE_ENTRY_JS_START|CODEWAVE_PAGE_ENTRY_JS_END') {
    throw "教程不能包含复制开始/结束标记，JS 代码块必须能一键完整复制：$path"
  }

  $matches = [regex]::Matches($document, $pattern)
  $exactMatches = @()
  foreach ($match in $matches) {
    $documentScript = Normalize-Text $match.Groups[1].Value
    if ($documentScript -ceq $scriptText) {
      $exactMatches += $match
    }
  }
  if ($exactMatches.Count -ne 1) {
    throw "教程必须且只能包含一段与 skill/assets/codewave-page-entry.js 完全一致、无额外标记的 js 代码块：$path"
  }

  Write-Host "教程完整 JS 校验通过：$path"
}
