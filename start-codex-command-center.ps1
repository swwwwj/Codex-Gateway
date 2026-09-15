$ErrorActionPreference = "Stop"

$gatewayDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$composeArgs = @(
  "compose",
  "-f", (Join-Path $gatewayDir "docker-compose.yml"),
  "-f", (Join-Path $gatewayDir "docker-compose.local.yml")
)

function Show-StartupError([string]$message) {
  Add-Type -AssemblyName PresentationFramework
  [System.Windows.MessageBox]::Show(
    $message,
    "Codex Command Center",
    [System.Windows.MessageBoxButton]::OK,
    [System.Windows.MessageBoxImage]::Error
  ) | Out-Null
}

try {
  docker info *> $null
  if ($LASTEXITCODE -ne 0) {
    $dockerDesktop = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (-not (Test-Path -LiteralPath $dockerDesktop)) {
      throw "Docker Desktop is not installed at the expected location."
    }
    Start-Process -FilePath $dockerDesktop -WindowStyle Hidden
    $dockerReady = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
      Start-Sleep -Seconds 2
      docker info *> $null
      if ($LASTEXITCODE -eq 0) {
        $dockerReady = $true
        break
      }
    }
    if (-not $dockerReady) {
      throw "Docker Desktop did not become ready within 120 seconds."
    }
  }

  docker network inspect web-common *> $null
  if ($LASTEXITCODE -ne 0) {
    docker network create web-common *> $null
    if ($LASTEXITCODE -ne 0) {
      throw "Could not create the Docker network web-common."
    }
  }

  & docker @composeArgs up -d
  if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose could not start Codex Gateway."
  }

  $gatewayReady = $false
  for ($attempt = 0; $attempt -lt 60; $attempt++) {
    try {
      $response = Invoke-WebRequest -Uri "http://127.0.0.1:8787" -UseBasicParsing -TimeoutSec 2
      if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
        $gatewayReady = $true
        break
      }
    } catch {
      Start-Sleep -Seconds 2
    }
  }
  if (-not $gatewayReady) {
    $logs = (& docker @composeArgs logs --tail=100 codex-gateway 2>&1 | Out-String)
    throw "Codex Gateway did not become ready.`n`n$logs"
  }

  $edgeCandidates = @(
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    (Join-Path $env:LOCALAPPDATA "Microsoft\Edge\Application\msedge.exe")
  )
  $edge = $edgeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if (-not $edge) {
    throw "Microsoft Edge was not found."
  }
  Start-Process -FilePath $edge -ArgumentList "--app=http://127.0.0.1:8787"
} catch {
  Show-StartupError $_.Exception.Message
  exit 1
}
