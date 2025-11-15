# Use environment variable GH_PROXY if set, otherwise default to empty
if (-not $env:GH_PROXY) {
    $GH_PROXY = "" 
} else {
    $GH_PROXY = $env:GH_PROXY
}

function Test-Url {
    param([string]$Url)
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 5
        return $true
    } catch {
        return $false
    }
}

try {
    Write-Host "Fetching latest Neovim release..."

    $repo = "neovim/neovim"
    $apiUrl  = "https://api.github.com/repos/$repo/releases/latest"
    $headers = @{ "User-Agent" = "PowerShellScript" }

    # Fetch release JSON
    $json = Invoke-RestMethod -Uri $apiUrl -Headers $headers

    # Detect system architecture
    if ([Environment]::Is64BitOperatingSystem) {
        $fileNamePattern = "nvim-win64.msi"
    } else {
        $fileNamePattern = "nvim-win-arm64.msi"
    }

    $asset = $json.assets |
             Where-Object { $_.name -eq $fileNamePattern } |
             Select-Object -First 1

    if (-not $asset) { throw "MSI file not found: $fileNamePattern" }

    $downloadUrl = $asset.browser_download_url

    # Apply GH_PROXY only to download URL if set and reachable
    if ($GH_PROXY -ne "") {
        $proxiedUrl = "$GH_PROXY$downloadUrl"
        if (Test-Url $proxiedUrl) {
            $downloadUrl = $proxiedUrl
            Write-Host "Using GH_PROXY for download: $GH_PROXY"
        } else {
            Write-Host "GH_PROXY is set but unreachable, using original URL"
        }
    }

    Write-Host "Found MSI: $($asset.name)"
    Write-Host "Download URL: $downloadUrl"

    $tmpDir = [System.IO.Path]::GetTempPath()
    $localFile = Join-Path -Path $tmpDir -ChildPath $asset.name

    Write-Host "Downloading to $localFile..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $localFile

    if (-not (Test-Path $localFile)) { throw "Download failed: $localFile does not exist" }

    Write-Host "Installing Neovim silently..."
    $installArgs = "/i `"$localFile`" /quiet /norestart"
    Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -NoNewWindow

    # Update PATH for current PowerShell session
    $defaultInstallPath = "C:\Program Files\Neovim\bin"
    if (Test-Path $defaultInstallPath) {
        if (-not ($env:Path -split ";" | Where-Object { $_ -eq $defaultInstallPath })) {
            $env:Path += ";$defaultInstallPath"
            Write-Host "Updated PATH for current session: $defaultInstallPath"
        }
    }

    Write-Host "Cleaning up..."
    Remove-Item -Path $localFile -Force

    Write-Host "Neovim installed successfully and PATH updated."
}
catch {
    Write-Error "Error: $($_.Exception.Message)"
    exit 1
}
