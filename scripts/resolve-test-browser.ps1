param(
  [switch]$NoFallbackInstall
)

$ErrorActionPreference = "Stop"

function Add-Candidate([System.Collections.Generic.List[object]]$List, [string]$Name, [string]$Path) {
  if ($Path -and (Test-Path -LiteralPath $Path -PathType Leaf)) {
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    if (-not ($List | Where-Object { $_.Path -eq $resolved })) {
      $List.Add([pscustomobject]@{ Name = $Name; Path = $resolved })
    }
  }
}

$candidates = [System.Collections.Generic.List[object]]::new()
if ($env:OS -eq "Windows_NT") {
  Add-Candidate $candidates "Chrome" (Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe")
  Add-Candidate $candidates "Chrome" (Join-Path $env:ProgramFiles "Google\Chrome\Application\chrome.exe")
  Add-Candidate $candidates "Chrome" (Join-Path ${env:ProgramFiles(x86)} "Google\Chrome\Application\chrome.exe")
  Add-Candidate $candidates "Edge" (Join-Path $env:ProgramFiles "Microsoft\Edge\Application\msedge.exe")
  Add-Candidate $candidates "Edge" (Join-Path ${env:ProgramFiles(x86)} "Microsoft\Edge\Application\msedge.exe")
  Add-Candidate $candidates "Edge" (Join-Path $env:LOCALAPPDATA "Microsoft\Edge\Application\msedge.exe")
}

foreach ($commandName in @("google-chrome", "chrome", "msedge", "microsoft-edge")) {
  $command = Get-Command $commandName -ErrorAction SilentlyContinue
  if ($command) {
    $name = if ($commandName -match "edge") { "Edge" } else { "Chrome" }
    Add-Candidate $candidates $name $command.Source
  }
}

foreach ($candidate in $candidates) {
  Write-Host "发现本机 $($candidate.Name)：$($candidate.Path)"
  Write-Output $candidate.Path
  return
}

$npx = Get-Command npx -ErrorAction SilentlyContinue
if ($NoFallbackInstall) {
  throw "未找到本机 Chrome 或 Edge。"
}
if (-not $npx) {
  throw "本机 Chrome/Edge 均不可用，且未找到 npx，无法自动安装 Playwright Chromium。请先安装 Node.js LTS。"
}

Write-Host "本机 Chrome/Edge 均不可用，正在安装 Playwright Chromium。"
& $npx.Source --yes playwright install chromium
if ($LASTEXITCODE -ne 0) {
  throw "Playwright Chromium 自动安装失败，请检查 npm 网络或代理配置。"
}

Write-Host "Playwright Chromium 安装完成。"
Write-Output "playwright:chromium"
