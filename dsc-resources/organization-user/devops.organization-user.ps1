# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
.SYNOPSIS
    DSC v3 resource script for managing Azure DevOps user entitlements.

.DESCRIPTION
    Implements Get, Set, and Test operations for an Azure DevOps organization
    user entitlement. Requires network access to https://vsaex.dev.azure.com
    and a PAT with 'Member Entitlement Management > Read & write' permission.

.PARAMETER Operation
    The DSC operation to perform: Get, Set, or Test.

.PARAMETER jsonInput
    JSON string received via pipeline containing the desired state properties.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('Get', 'Set', 'Test')]
    [string]$Operation,

    [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)]
    [string]$jsonInput
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-DscTrace {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Error', 'Warn', 'Info', 'Debug', 'Trace')]
        [string]$Level,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Message
    )

    $trace = @{ $Level.ToLower() = $Message } | ConvertTo-Json -Compress
    $host.ui.WriteErrorLine($trace)
}

function Get-TokenValue {
    param([object]$Value)

    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in @('value', 'secureString', 'Token', 'PersonalAccessToken', 'pat', '_value')) {
            if ($Value.Contains($key)) { return $Value[$key].ToString() }
        }
        $first = $Value.Keys | Select-Object -First 1
        if ($first) { return $Value[$first].ToString() }
    }
    if ($null -ne $Value.PSObject -and $Value.PSObject.Properties['secureString']) {
        return $Value.secureString.ToString()
    }
    return $Value.ToString()
}

function Invoke-AdoApi {
    param(
        [string]$Method,
        [string]$Uri,
        [string]$Token,
        [string]$Body,
        [string]$ContentType = 'application/json'
    )

    $base64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Token"))
    $headers = @{
        Authorization  = "Basic $base64"
        'Content-Type' = $ContentType
    }
    $params = @{
        Uri         = $Uri
        Method      = $Method
        Headers     = $headers
        ErrorAction = 'Stop'
    }
    if ($Body) { $params.Body = $Body }

    try {
        return Invoke-RestMethod @params
    }
    catch {
        $msg = $_.ToString()
        if ($_.Exception.Response) {
            try {
                $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $msg += " | Response: $($reader.ReadToEnd())"
            } catch {}
        }
        throw $msg
    }
}

function ConvertTo-LicenseType {
    param([string]$AccessLevel)
    $map = @{
        'Basic'              = 'express'
        'BasicPlusTestPlans' = 'advanced'
    }
    if ($map.ContainsKey($AccessLevel)) { return $map[$AccessLevel] }
    return 'stakeholder'
}

function ConvertFrom-LicenseType {
    param([string]$LicenseType)
    $map = @{
        'express'  = 'Basic'
        'advanced' = 'BasicPlusTestPlans'
    }
    if ($map.ContainsKey($LicenseType)) { return $map[$LicenseType] }
    return 'Stakeholder'
}

function Get-UserEntitlement {
    param([string]$Organization, [string]$Upn, [string]$Token, [string]$ApiVersion)

    $uri = "https://vsaex.dev.azure.com/$Organization/_apis/userentitlements?api-version=$ApiVersion"
    $response = Invoke-AdoApi -Method GET -Uri $uri -Token $Token
    if ($null -eq $response -or $null -eq $response.value) { return $null }
    return $response.value | Where-Object { $_.user.principalName -eq $Upn } | Select-Object -First 1
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

$desired = $jsonInput | ConvertFrom-Json

$org        = $desired.organization
$upn        = $desired.userPrincipalName
$token      = Get-TokenValue -Value $desired.pat
$apiVersion = if ($desired.apiVersion) { $desired.apiVersion } else { '7.1-preview.1' }
$ensure     = if ($desired.ensure) { $desired.ensure } else { 'Present' }
$accessLevel = if ($desired.accessLevel) { $desired.accessLevel } else { 'Stakeholder' }

if ([string]::IsNullOrWhiteSpace($token)) {
    Write-DscTrace -Level Error -Message 'pat is required and must not be empty.'
    exit 1
}
if ([string]::IsNullOrWhiteSpace($org)) {
    Write-DscTrace -Level Error -Message 'organization is required and must not be empty.'
    exit 1
}

switch ($Operation) {

    'Get' {
        try {
            $user = Get-UserEntitlement -Organization $org -Upn $upn -Token $token -ApiVersion $apiVersion

            if ($null -ne $user) {
                $result = [ordered]@{
                    userPrincipalName = $user.user.principalName
                    organization      = $org
                    accessLevel       = ConvertFrom-LicenseType -LicenseType $user.accessLevel.accountLicenseType
                    ensure            = 'Present'
                    pat               = $desired.pat
                    apiVersion        = $apiVersion
                    _inDesiredState   = $null
                }
            }
            else {
                $result = [ordered]@{
                    userPrincipalName = $upn
                    organization      = $org
                    accessLevel       = $accessLevel
                    ensure            = 'Absent'
                    pat               = $desired.pat
                    apiVersion        = $apiVersion
                    _inDesiredState   = $null
                }
            }

            $result | ConvertTo-Json -Compress
        }
        catch {
            Write-DscTrace -Level Error -Message "Get failed: $_"
            exit 1
        }
    }

    'Test' {
        try {
            $user   = Get-UserEntitlement -Organization $org -Upn $upn -Token $token -ApiVersion $apiVersion
            $exists = $null -ne $user

            $inDesiredState = if ($ensure -eq 'Present') {
                $exists -and ($user.accessLevel.accountLicenseType -eq (ConvertTo-LicenseType -AccessLevel $accessLevel))
            }
            else {
                -not $exists
            }

            $rAccessLevel = if ($exists) { ConvertFrom-LicenseType -LicenseType $user.accessLevel.accountLicenseType } else { $accessLevel }
            $rEnsure      = if ($exists) { 'Present' } else { 'Absent' }
            $result = [ordered]@{
                userPrincipalName = $upn
                organization      = $org
                accessLevel       = $rAccessLevel
                ensure            = $rEnsure
                pat               = $desired.pat
                apiVersion        = $apiVersion
                _inDesiredState   = $inDesiredState
            }

            $result | ConvertTo-Json -Compress
        }
        catch {
            Write-DscTrace -Level Error -Message "Test failed: $_"
            exit 1
        }
    }

    'Set' {
        try {
            $user   = Get-UserEntitlement -Organization $org -Upn $upn -Token $token -ApiVersion $apiVersion
            $exists = $null -ne $user

            if ($ensure -eq 'Present') {
                if (-not $exists) {
                    Write-DscTrace -Level Info -Message "Adding user '$upn' to organization '$org' with access level '$accessLevel'."

                    $payload = @{
                        accessLevel         = @{
                            accountLicenseType = ConvertTo-LicenseType -AccessLevel $accessLevel
                            licensingSource    = 'account'
                        }
                        user                = @{
                            principalName = $upn
                            subjectKind   = 'user'
                        }
                        projectEntitlements = @()
                    }
                    $uri = "https://vsaex.dev.azure.com/$org/_apis/userentitlements?api-version=$apiVersion"
                    Invoke-AdoApi -Method POST -Uri $uri -Token $token -Body ($payload | ConvertTo-Json -Depth 10) | Out-Null
                    Write-DscTrace -Level Info -Message "User '$upn' added successfully."
                }
                else {
                    $currentLicense = $user.accessLevel.accountLicenseType
                    $desiredLicense = ConvertTo-LicenseType -AccessLevel $accessLevel
                    if ($currentLicense -ne $desiredLicense) {
                        Write-DscTrace -Level Info -Message "Updating access level for '$upn' from '$currentLicense' to '$desiredLicense'."
                        $userId = $user.id
                        $patch = @(
                            @{
                                op    = 'replace'
                                path  = '/accessLevel'
                                value = @{
                                    accountLicenseType = $desiredLicense
                                    licensingSource    = 'account'
                                }
                            }
                        )
                        $uri = "https://vsaex.dev.azure.com/$org/_apis/userentitlements/$($userId)?api-version=$apiVersion"
                        Invoke-AdoApi -Method PATCH -Uri $uri -Token $token -Body (ConvertTo-Json -Depth 10 -InputObject $patch) -ContentType 'application/json-patch+json' | Out-Null
                        Write-DscTrace -Level Info -Message "Access level updated successfully."
                    }
                    else {
                        Write-DscTrace -Level Info -Message "User '$upn' already has the desired access level; no action required."
                    }
                }
            }
            else {
                if ($exists) {
                    Write-DscTrace -Level Info -Message "Removing user '$upn' from organization '$org'."
                    $userId = $user.id
                    $uri = "https://vsaex.dev.azure.com/$org/_apis/userentitlements/$($userId)?api-version=$apiVersion"
                    Invoke-AdoApi -Method DELETE -Uri $uri -Token $token | Out-Null
                    Write-DscTrace -Level Info -Message "User '$upn' removed successfully."
                }
                else {
                    Write-DscTrace -Level Info -Message "User '$upn' does not exist; no action required."
                }
            }

            # Return current state after set
            $user = Get-UserEntitlement -Organization $org -Upn $upn -Token $token -ApiVersion $apiVersion
            $rAccessLevel = if ($null -ne $user) { ConvertFrom-LicenseType -LicenseType $user.accessLevel.accountLicenseType } else { $accessLevel }
            $rEnsure      = if ($null -ne $user) { 'Present' } else { 'Absent' }
            $result = [ordered]@{
                userPrincipalName = $upn
                organization      = $org
                accessLevel       = $rAccessLevel
                ensure            = $rEnsure
                pat               = $desired.pat
                apiVersion        = $apiVersion
                _inDesiredState   = $null
            }
            $result | ConvertTo-Json -Compress
        }
        catch {
            Write-DscTrace -Level Error -Message "Set failed: $_"
            exit 1
        }
    }
}
