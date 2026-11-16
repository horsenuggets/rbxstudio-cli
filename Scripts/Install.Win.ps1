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

    # Releases publish a zip per target. Releases before 1.0.3 only have a bare
    # binary, so a tagged install of one of those falls back to it.
    $archiveName = "$PROGRAM_NAME-windows-$arch.zip"
    $legacyName = "$PROGRAM_NAME-windows-$arch.exe"

    $asset = $releaseInfo.assets | Where-Object { $_.name -eq $archiveName } | Select-Object -First 1
    $isArchive = [bool]$asset
    if (-not $asset) {
        $asset = $releaseInfo.assets | Where-Object { $_.name -eq $legacyName } | Select-Object -First 1
    }

    if (-not $asset) {
        throw "Could not find `"$archiveName`" or `"$legacyName`" in the release."
    }

    $assetName = $asset.name
    $downloadUrl = $asset.browser_download_url

    # Create installation directory
    Write-Host "[2 / 4] Creating installation directory."
    New-Item -ItemType Directory -Force -Path $BIN_DIR | Out-Null

    # Download the asset
    Write-Host "[3 / 4] Downloading `"$assetName`"."
    $zipDest = "$BIN_DIR\.$PROGRAM_NAME-download.zip"
    $binDest = "$BIN_DIR\$PROGRAM_NAME.exe"
    try {
        if ($isArchive) {
            Invoke-WebRequest $downloadUrl -OutFile $zipDest -ErrorAction Stop
            # Without Stop, a failed extraction is non-terminating, and a binary
            # left by an earlier install would pass for the new one. LiteralPath
            # keeps brackets in a profile folder name from acting as wildcards.
            Expand-Archive -LiteralPath $zipDest -DestinationPath $BIN_DIR -Force -ErrorAction Stop
        } else {
            Invoke-WebRequest $downloadUrl -OutFile $binDest -ErrorAction Stop
        }
    }
    catch {
        throw "Failed to install `"$assetName`" from $downloadUrl. $_"
    }
    finally {
        Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $zipDest
    }

    if (-not (Test-Path -LiteralPath $binDest)) {
        throw "Failed to install the binary."
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
