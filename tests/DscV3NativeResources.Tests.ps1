#Requires -Version 7.2

BeforeAll {
    # ── Install DSC v3 if not already on PATH ────────────────────────────────
    if (-not (Get-Command dsc -ErrorAction SilentlyContinue)) {
        try {
            Write-Host 'DSC not found on PATH – downloading latest release from GitHub…'

            $release    = Invoke-RestMethod 'https://api.github.com/repos/PowerShell/DSC/releases/latest' -UseBasicParsing
            $version    = $release.tag_name -replace '^v', ''

            $assetName = if ($IsWindows) {
                "DSC-$version-x86_64-pc-windows-msvc.zip"
            } elseif ($IsMacOS) {
                $arch = (uname -m).Trim()
                if ($arch -eq 'arm64') { "DSC-$version-aarch64-apple-darwin.tar.gz" }
                else                   { "DSC-$version-x86_64-apple-darwin.tar.gz" }
            } else {
                "DSC-$version-x86_64-unknown-linux-gnu.tar.gz"
            }

            $asset = $release.assets | Where-Object name -EQ $assetName
            if (-not $asset) { throw "Release asset '$assetName' not found in v$version" }

            $installDir  = Join-Path ([IO.Path]::GetTempPath()) 'dsc-v3'
            New-Item -ItemType Directory -Path $installDir -Force | Out-Null
            $archivePath = Join-Path $installDir $assetName

            Write-Host "Downloading DSC v$version…"
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $archivePath -UseBasicParsing

            if ($assetName.EndsWith('.zip')) {
                Expand-Archive -Path $archivePath -DestinationPath $installDir -Force
            } else {
                tar -xzf $archivePath -C $installDir
            }

            $dscBin = Join-Path $installDir (if ($IsWindows) { 'dsc.exe' } else { 'dsc' })
            if (-not $IsWindows) { chmod +x $dscBin }

            $sep      = if ($IsWindows) { ';' } else { ':' }
            $env:PATH = "$installDir$sep$env:PATH"

            Write-Host "DSC v$version ready at $installDir"
        }
        catch {
            Write-Warning "Could not install DSC v3: $_"
        }
    }

    $Script:DscAvailable = $null -ne (Get-Command dsc -ErrorAction SilentlyContinue)

    # ── Set DSC_RESOURCE_PATH ────────────────────────────────────────────────
    # Allow the caller (CI step) to override by pre-setting the variable.
    if ([string]::IsNullOrEmpty($env:DSC_RESOURCE_PATH)) {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
        $resBase  = Join-Path $repoRoot 'dsc-resources'
        $pathSep  = if ($IsWindows) { ';' } else { ':' }

        $env:DSC_RESOURCE_PATH = (@(
            'project'
            'organization-user'
            'organization-group'
            'project-user-permission'
            'project-group-permission'
        ) | ForEach-Object { Join-Path $resBase $_ }) -join $pathSep
    }
}

# ── DSC binary ───────────────────────────────────────────────────────────────
Describe 'DSC v3 binary' {

    It 'is available on PATH' {
        $Script:DscAvailable | Should -BeTrue
    }

    It 'reports a version string' {
        if (-not $Script:DscAvailable) { Set-ItResult -Skipped -Because 'dsc not on PATH'; return }
        $out = & dsc --version 2>&1 | Out-String
        $out | Should -Match '\d+\.\d+\.\d+'
    }
}

# ── Resource discovery ───────────────────────────────────────────────────────
Describe 'Native AzureDevOps resource discovery' {

    BeforeAll {
        if ($Script:DscAvailable) {
            $Script:ListOutput = & dsc resource list 2>&1 | Out-String
        }
    }

    $resourceTypes = @(
        'AzureDevOps/Project'
        'AzureDevOps/OrganizationUser'
        'AzureDevOps/OrganizationGroup'
        'AzureDevOps/ProjectUserPermission'
        'AzureDevOps/ProjectGroupPermission'
    )

    It 'dsc resource list discovers <_>' -ForEach $resourceTypes {
        if (-not $Script:DscAvailable) { Set-ItResult -Skipped -Because 'dsc not on PATH'; return }
        $Script:ListOutput | Should -Match ([regex]::Escape($_))
    }
}

# ── Manifest sanity ──────────────────────────────────────────────────────────
Describe 'Resource manifest files are valid JSON' {

    $repoRoot  = Resolve-Path (Join-Path $PSScriptRoot '..')
    $manifests = Get-ChildItem -Path (Join-Path $repoRoot 'dsc-resources') -Filter '*.dsc.resource.json' -Recurse

    It '<_.Name> parses as valid JSON' -ForEach $manifests {
        $content = Get-Content $_.FullName -Raw
        { $content | ConvertFrom-Json } | Should -Not -Throw
    }

    It '<_.Name> declares a type field' -ForEach $manifests {
        $manifest = Get-Content $_.FullName -Raw | ConvertFrom-Json
        $manifest.type | Should -Not -BeNullOrEmpty
    }

    It '<_.Name> declares a version field' -ForEach $manifests {
        $manifest = Get-Content $_.FullName -Raw | ConvertFrom-Json
        $manifest.version | Should -Match '^\d+\.\d+\.\d+$'
    }
}
