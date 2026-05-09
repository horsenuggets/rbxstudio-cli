$PROGRAM_NAME = "rbxstudio"
$REPOSITORY = "horsenuggets/rbxstudio-cli"
$INSTALL_DIR = "$env:USERPROFILE\.rbxstudio-cli"
$BIN_DIR = "$INSTALL_DIR\bin"

Function Get-ReleaseInfo {
    param (
        [string]$ApiUrl
    )

    $headers = @{
        'X-GitHub-Api-Version' = '2022-11-28'
    }

    if ($env:GITHUB_PAT) {
        $headers['Authorization'] = "token $env:GITHUB_PAT"
    }

    try {
        $response = Invoke-RestMethod -Uri $ApiUrl -Headers $headers -ErrorAction Stop
        return $response
    }
    catch {
        throw "Failed to fetch release info. $_"
    }
}

Function Get-WindowsUserPath {
    try {
        $path = [Environment]::GetEnvironmentVariable("Path", "User")
        return $path
    }
    catch {
        return $null
    }
}

Function Add-ToPath {
    param (
        [string]$Directory
    )

    $currentPath = Get-WindowsUserPath
    if ($currentPath -and $currentPath.ToLower().Contains($Directory.ToLower())) {
        Write-Host "PATH already configured."
        return $false
    }

    $newPath = if ($currentPath) { "$currentPath;$Directory" } else { $Directory }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Added $Directory to user PATH."
    return $true
}

try {
    if ($env:GITHUB_PAT) {
        Write-Host "Using the provided GITHUB_PAT for authentication."
    }

    # Determine architecture
    $arch = if ([Environment]::Is64BitOperatingSystem) {
        if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or $env:PROCESSOR_ARCHITEW6432 -eq "ARM64") {
            "aarch64"
        } else {
            "x86_64"
        }
    } else {
        Write-Error "32-bit systems are not supported."
        exit 1
    }

    # Determine version to download
    $version = $args[0]
    if ($version) {
        Write-Host "`n[1 / 4] Looking for $PROGRAM_NAME release with tag `"$version`"."
        $apiUrl = "https://api.github.com/repos/$REPOSITORY/releases/tags/$version"
    } else {
        Write-Host "`n[1 / 4] Looking for the latest $PROGRAM_NAME release."
        $apiUrl = "https://api.github.com/repos/$REPOSITORY/releases/latest"
    }

    $releaseInfo = Get-ReleaseInfo -ApiUrl $apiUrl
    $releaseVersion = $releaseInfo.tag_name
    Write-Host "Found version $releaseVersion."

    # Find the download URL
    $binaryName = "$PROGRAM_NAME-windows-$arch.exe"

    $asset = $releaseInfo.assets | Where-Object { $_.name -eq $binaryName } | Select-Object -First 1

    if (-not $asset) {
        throw "Could not find the binary `"$binaryName`" in the release."
    }

    $downloadUrl = $asset.browser_download_url

    # Create installation directory
    Write-Host "[2 / 4] Creating installation directory."
    New-Item -ItemType Directory -Force -Path $BIN_DIR | Out-Null

    # Download the binary
    Write-Host "[3 / 4] Downloading `"$binaryName`"."
    $binDest = "$BIN_DIR\$PROGRAM_NAME.exe"
    try {
        Invoke-WebRequest $downloadUrl -OutFile $binDest -ErrorAction Stop
    }
    catch {
        throw "Failed to download binary from $downloadUrl. $_"
    }

    if (-not (Test-Path $binDest)) {
        throw "Failed to download the binary."
    }

    # Configure PATH
    Write-Host "[4 / 4] Configuring PATH."
    $pathChanged = Add-ToPath -Directory $BIN_DIR

    # Print success message
    Write-Host "`nInstallation complete!"
    Write-Host ""
    Write-Host "Installed version $releaseVersion."
    Write-Host "Binary at $binDest."

    if ($pathChanged) {
        Write-Host ""
        Write-Host "Restart your terminal to use rbxstudio."
    }
}
catch {
    Write-Error "Installation failed. $_"
    exit 1
}
