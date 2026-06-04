# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
.SYNOPSIS
    DSC v3 resource script for managing Azure DevOps group entitlements.

.DESCRIPTION
    Implements Get, Set, and Test operations for an Azure DevOps organization
    group entitlement (license rule). Requires network access to
    https://vsaex.dev.azure.com and a PAT with
    'Member Entitlement Management > Read & write' permission.

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

function Get-GroupEntitlement {
    param([string]$Organization, [string]$GroupOriginId, [string]$Token, [string]$ApiVersion)

    $uri = "https://vsaex.dev.azure.com/$Organization/_apis/groupentitlements?api-version=$ApiVersion"
    $response = Invoke-AdoApi -Method GET -Uri $uri -Token $Token
    if ($null -eq $response -or $null -eq $response.value) { return $null }
    return $response.value | Where-Object { $_.group.originId -eq $GroupOriginId } | Select-Object -First 1
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

$desired = $jsonInput | ConvertFrom-Json

$org          = $desired.organization
$originId     = $desired.groupOriginId
$displayName  = $desired.groupDisplayName
$token        = Get-TokenValue -Value $desired.pat
$apiVersion   = if ($desired.apiVersion) { $desired.apiVersion } else { '7.1-preview.1' }
$ensure       = if ($desired.ensure) { $desired.ensure } else { 'Present' }
$accessLevel  = if ($desired.accessLevel) { $desired.accessLevel } else { 'Stakeholder' }

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
            $group = Get-GroupEntitlement -Organization $org -GroupOriginId $originId -Token $token -ApiVersion $apiVersion

            if ($null -ne $group) {
                $result = [ordered]@{
                    groupOriginId    = $group.group.originId
                    groupDisplayName = $group.group.displayName
                    organization     = $org
                    accessLevel      = ConvertFrom-LicenseType -LicenseType $group.licenseRule.accountLicenseType
                    ensure           = 'Present'
                    pat              = $desired.pat
                    apiVersion       = $apiVersion
                    _inDesiredState  = $null
                }
            }
            else {
                $result = [ordered]@{
                    groupOriginId    = $originId
                    groupDisplayName = $displayName
                    organization     = $org
                    accessLevel      = $accessLevel
                    ensure           = 'Absent'
                    pat              = $desired.pat
                    apiVersion       = $apiVersion
                    _inDesiredState  = $null
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
            $group  = Get-GroupEntitlement -Organization $org -GroupOriginId $originId -Token $token -ApiVersion $apiVersion
            $exists = $null -ne $group

            $inDesiredState = if ($ensure -eq 'Present') {
                $exists -and ($group.licenseRule.accountLicenseType -eq (ConvertTo-LicenseType -AccessLevel $accessLevel))
            }
            else {
                -not $exists
            }

            $rDisplayName = if ($exists) { $group.group.displayName } else { $displayName }
            $rAccessLevel = if ($exists) { ConvertFrom-LicenseType -LicenseType $group.licenseRule.accountLicenseType } else { $accessLevel }
            $rEnsure      = if ($exists) { 'Present' } else { 'Absent' }
            $result = [ordered]@{
                groupOriginId    = $originId
                groupDisplayName = $rDisplayName
                organization     = $org
                accessLevel      = $rAccessLevel
                ensure           = $rEnsure
                pat              = $desired.pat
                apiVersion       = $apiVersion
                _inDesiredState  = $inDesiredState
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
            $group  = Get-GroupEntitlement -Organization $org -GroupOriginId $originId -Token $token -ApiVersion $apiVersion
            $exists = $null -ne $group

            if ($ensure -eq 'Present') {
                if (-not $exists) {
                    Write-DscTrace -Level Info -Message "Adding group entitlement '$originId' to organization '$org'."

                    $payload = @{
                        group       = @{
                            originId    = $originId
                            subjectKind = 'group'
                        }
                        licenseRule = @{
                            accountLicenseType = ConvertTo-LicenseType -AccessLevel $accessLevel
                            licensingSource    = 'account'
                        }
                    }
                    if (-not [string]::IsNullOrWhiteSpace($displayName)) {
                        $payload.group.displayName = $displayName
                    }

                    $uri = "https://vsaex.dev.azure.com/$org/_apis/groupentitlements?api-version=$apiVersion"
                    Invoke-AdoApi -Method POST -Uri $uri -Token $token -Body ($payload | ConvertTo-Json -Depth 10) | Out-Null
                    Write-DscTrace -Level Info -Message "Group entitlement '$originId' added successfully."
                }
                else {
                    $currentLicense = $group.licenseRule.accountLicenseType
                    $desiredLicense = ConvertTo-LicenseType -AccessLevel $accessLevel
                    if ($currentLicense -ne $desiredLicense) {
                        Write-DscTrace -Level Info -Message "Updating license rule for group '$originId' from '$currentLicense' to '$desiredLicense'."
                        $groupId = $group.id
                        $patch = @(
                            @{
                                op    = 'replace'
                                path  = '/licenseRule/accountLicenseType'
                                value = $desiredLicense
                            }
                            @{
                                op    = 'replace'
                                path  = '/licenseRule/licensingSource'
                                value = 'account'
                            }
                        )
                        $uri = "https://vsaex.dev.azure.com/$org/_apis/groupentitlements/$($groupId)?api-version=$apiVersion"
                        Invoke-AdoApi -Method PATCH -Uri $uri -Token $token -Body (ConvertTo-Json -Depth 10 -InputObject $patch) -ContentType 'application/json-patch+json' | Out-Null
                        Write-DscTrace -Level Info -Message "License rule updated successfully."
                    }
                    else {
                        Write-DscTrace -Level Info -Message "Group entitlement '$originId' already has the desired license; no action required."
                    }
                }
            }
            else {
                if ($exists) {
                    Write-DscTrace -Level Info -Message "Removing group entitlement '$originId' from organization '$org'."
                    $groupId = $group.id
                    $uri = "https://vsaex.dev.azure.com/$org/_apis/groupentitlements/$($groupId)?api-version=$apiVersion"
                    Invoke-AdoApi -Method DELETE -Uri $uri -Token $token | Out-Null
                    Write-DscTrace -Level Info -Message "Group entitlement '$originId' removed successfully."
                }
                else {
                    Write-DscTrace -Level Info -Message "Group entitlement '$originId' does not exist; no action required."
                }
            }

            # Return current state after set
            $group = Get-GroupEntitlement -Organization $org -GroupOriginId $originId -Token $token -ApiVersion $apiVersion
            $rDisplayName = if ($null -ne $group) { $group.group.displayName } else { $displayName }
            $rAccessLevel = if ($null -ne $group) { ConvertFrom-LicenseType -LicenseType $group.licenseRule.accountLicenseType } else { $accessLevel }
            $rEnsure      = if ($null -ne $group) { 'Present' } else { 'Absent' }
            $result = [ordered]@{
                groupOriginId    = $originId
                groupDisplayName = $rDisplayName
                organization     = $org
                accessLevel      = $rAccessLevel
                ensure           = $rEnsure
                pat              = $desired.pat
                apiVersion       = $apiVersion
                _inDesiredState  = $null
            }
            $result | ConvertTo-Json -Compress
        }
        catch {
            Write-DscTrace -Level Error -Message "Set failed: $_"
            exit 1
        }
    }
}
