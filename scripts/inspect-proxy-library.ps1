param(
  [Parameter(Mandatory = $true)]
  [string]$ProxyZip,

  [Parameter(Mandatory = $true)]
  [string]$ProxyBase,

  [switch]$AllowExternalBackend
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ($ProxyBase -notmatch '^/[A-Za-z0-9_/-]+$') {
  throw "ProxyBase format is invalid: $ProxyBase"
}

if (-not (Test-Path -LiteralPath $ProxyZip -PathType Leaf)) {
  throw "Proxy library zip does not exist: $ProxyZip"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$outer = [System.IO.Compression.ZipFile]::OpenRead($ProxyZip)
try {
  $sourceEntry = $outer.GetEntry("source.zip")
  if (-not $sourceEntry) {
    throw "source.zip is missing in proxy library: $ProxyZip"
  }

  $sourceStream = New-Object System.IO.MemoryStream
  try {
    $entryStream = $sourceEntry.Open()
    try {
      $entryStream.CopyTo($sourceStream)
    } finally {
      $entryStream.Dispose()
    }

    $sourceStream.Position = 0
    $sourceZip = New-Object System.IO.Compression.ZipArchive($sourceStream, [System.IO.Compression.ZipArchiveMode]::Read, $true)
    try {
      $combined = New-Object System.Text.StringBuilder
      $backendModeContent = New-Object System.Text.StringBuilder
      $frontendRuntimeContent = New-Object System.Text.StringBuilder
      foreach ($entry in $sourceZip.Entries) {
        if ($entry.FullName -match '\.(java|js|html|md|xml|json|properties|yml|yaml)$') {
          $reader = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
          try {
            [void]$combined.AppendLine($reader.ReadToEnd())
          } finally {
            $reader.Dispose()
          }
        }
        if ($entry.FullName -match '\.(java|kt|properties|yml|yaml|xml)$') {
          $modeReader = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
          try {
            [void]$backendModeContent.AppendLine($modeReader.ReadToEnd())
          } finally {
            $modeReader.Dispose()
          }
        }
        if ($entry.FullName -match '\.(js|jsx|ts|tsx|vue|html)$') {
          $frontendReader = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
          try {
            [void]$frontendRuntimeContent.AppendLine($frontendReader.ReadToEnd())
          } finally {
            $frontendReader.Dispose()
          }
        }
      }

      $text = $combined.ToString()
      $required = @(
        "$ProxyBase/callApi",
        "@RequestMapping(`"$ProxyBase`")",
        "@PostMapping(`"/getAppHtml`")",
        "@PostMapping(`"/callApi`")"
      )

      $missing = @()
      foreach ($item in $required) {
        if (-not $text.Contains($item)) {
          $missing += $item
        }
      }

      if ($missing.Count -gt 0) {
        throw "Proxy library does not contain expected proxy path $ProxyBase. Missing: $($missing -join ', '). Re-run set-proxy-base.ps1, bump version, rebuild, re-import, and publish."
      }

      $logicSourceChecks = @(
        @{ Name = "getAppHtml"; Pattern = '(?s)@NaslLogic\s+public\s+[\w<>,\s\.\[\]?]+\s+getAppHtml\s*\(' },
        @{ Name = "callApi"; Pattern = '(?s)@NaslLogic\s+public\s+[\w<>,\s\.\[\]?]+\s+callApi\s*\(' }
      )

      foreach ($check in $logicSourceChecks) {
        if ($text -notmatch $check.Pattern) {
          throw "Proxy library source does not register $($check.Name) as a CodeWave backend logic. Add @NaslLogic public ... $($check.Name)(...) in the proxy facade, rebuild with nasl-metadata-maven-plugin archive goal, bump version, re-import, and publish."
        }
      }

      if ($ProxyBase -ne "/simple_proxy" -and $text.Contains("/simple_proxy")) {
        throw "Proxy library still contains /simple_proxy while expected $ProxyBase. This is usually an old or partially updated package."
      }

      if ($frontendRuntimeContent.ToString() -match '(?i)[''"`][\s]*/api(?:/|[''"`])') {
        throw "Proxy library frontend still contains an /api/... business path. callApi reqPath must use /customers, /users, and similar business paths without the /api prefix."
      }

      if (-not $AllowExternalBackend) {
        $modeText = $backendModeContent.ToString()
        $externalBackendPatterns = @(
          '(?i)\b[a-z0-9_.-]*backend[._-](?:base[._-]?url|url|host)\b',
          '\b[A-Z][A-Z0-9_]*BACKEND_(?:BASE_)?(?:URL|HOST)\b',
          '(?i)\b(?:backend|upstream|target)(?:Base)?(?:Url|Host)\b',
          '(?i)\b(?:forwardRequest|proxyToUpstream|forwardToBackend)\b',
          '未配置.{0,40}后端地址|代理服务端设置.{0,80}backend'
        )
        foreach ($pattern in $externalBackendPatterns) {
          if ($modeText -match $pattern) {
            throw "Proxy library contains external-backend forwarding configuration, but embedded backend mode is required. Do not configure a CodeWave platform URL or backend Base URL; rebuild with local business handlers and platform DataSource."
          }
        }
        if ($modeText -notmatch '\b(?:javax\.sql\.)?DataSource\b') {
          throw "Proxy library embedded mode does not contain platform DataSource integration. Do not replace local CRUD with external-backend forwarding."
        }
      }
    } finally {
      $sourceZip.Dispose()
    }
  } finally {
    $sourceStream.Dispose()
  }

  $metadataEntry = $outer.GetEntry("nasl-metadata.json")
  if (-not $metadataEntry) {
    throw "nasl-metadata.json is missing in proxy library: $ProxyZip"
  }

  $metadataReader = New-Object System.IO.StreamReader($metadataEntry.Open(), [System.Text.Encoding]::UTF8)
  try {
    $metadataText = $metadataReader.ReadToEnd()
  } finally {
    $metadataReader.Dispose()
  }

  $metadataChecks = @(
    @{ Name = "top-level logics"; Pattern = '"logics"\s*:' },
    @{ Name = "getAppHtml naslName"; Pattern = '"naslName"\s*:\s*"getAppHtml"' },
    @{ Name = "callApi naslName"; Pattern = '"naslName"\s*:\s*"callApi"' },
    @{ Name = "getAppHtml logic"; Pattern = '"name"\s*:\s*"getAppHtml"' },
    @{ Name = "callApi logic"; Pattern = '"name"\s*:\s*"callApi"' }
  )

  $missingMetadata = @()
  foreach ($check in $metadataChecks) {
    if ($metadataText -notmatch $check.Pattern) {
      $missingMetadata += $check.Name
    }
  }

  if ($missingMetadata.Count -gt 0) {
    throw "Proxy library metadata does not expose required CodeWave backend logics. Missing: $($missingMetadata -join ', '). getAppHtml and callApi must be generated into nasl-metadata.json top-level logics; rebuild with the bundled nasl-metadata-maven-plugin archive goal, bump version, re-import, and publish."
  }
} finally {
  $outer.Dispose()
}

Write-Host "Proxy library content validation passed: $ProxyBase"
