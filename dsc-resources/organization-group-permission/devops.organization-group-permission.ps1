# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
.SYNOPSIS
    DSC v3 resource script for managing Entra group membership in Azure DevOps organization-level groups.

.DESCRIPTION
    Implements Get, Set, and Test operations for an Entra security group's membership
    in an organization-level (Project Collection) Azure DevOps security group such as
    Project Collection Administrators, Project Collection Valid Users, Project-Scoped Users, etc.
    If the Entra group is not yet linked to the Azure DevOps organization, it is
    added automatically during Set.
    Requires network access to https://dev.azure.com and https://vssps.dev.azure.com,
    and a PAT with 'Graph > Read & manage' permissions.

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

function Get-GroupDisplayName {
    param([string]$PermissionLevel)
    $map = @{
        'ProjectCollectionAdministrators'      = 'Project Collection Administrators'
        'ProjectCollectionBuildAdministrators' = 'Project Collection Build Administrators'
        'ProjectCollectionBuildServiceAccounts'= 'Project Collection Build Service Accounts'
        'ProjectCollectionProxyServiceAccounts'= 'Project Collection Proxy Service Accounts'
        'ProjectCollectionServiceAccounts'     = 'Project Collection Service Accounts'
        'ProjectCollectionTestServiceAccounts' = 'Project Collection Test Service Accounts'
        'ProjectCollectionValidUsers'          = 'Project Collection Valid Users'
        'ProjectScopedUsers'                   = 'Project-Scoped Users'
        'SecurityServiceGroup'                 = 'Security Service Group'
    }
    if (-not $map.ContainsKey($PermissionLevel)) {
        throw "Unknown permissionLevel '$PermissionLevel'."
    }
    return $map[$PermissionLevel]
}

function Get-OrgGroupDescriptor {
    param([string]$Organization, [string]$GroupDisplayName, [string]$Token, [string]$ApiVersion)

    $uri    = "https://vssps.dev.azure.com/$Organization/_apis/graph/groups?api-version=$ApiVersion"
    $groups = Invoke-AdoApi -Method GET -Uri $uri -Token $Token

    if ($null -eq $groups -or $null -eq $groups.value) {
        throw "No groups found for organization '$Organization'."
    }
    $escapedOrg = [regex]::Escape($Organization)
    $group = $groups.value | Where-Object { $_.displayName -eq $GroupDisplayName -and $_.principalName -match "^\[$escapedOrg\]" } | Select-Object -First 1
    if ($null -eq $group) {
        throw "Organization group '$GroupDisplayName' not found in '$Organization'."
    }
    return $group.descriptor
}

function Get-OrEnsureSourceGroupDescriptor {
    param([string]$Organization, [string]$GroupOriginId, [string]$Token, [string]$ApiVersion)

    $uri    = "https://vssps.dev.azure.com/$Organization/_apis/graph/groups?api-version=$ApiVersion"
    $groups = Invoke-AdoApi -Method GET -Uri $uri -Token $Token

    if ($null -ne $groups -and $null -ne $groups.value) {
        $existing = $groups.value | Where-Object { $_.originId -eq $GroupOriginId } | Select-Object -First 1
        if ($null -ne $existing) { return $existing.descriptor }
    }

    # Group not yet linked — add it from Entra
    Write-DscTrace -Level Info -Message "Entra group '$GroupOriginId' not found in organization; linking it now."
    $payload  = @{ originId = $GroupOriginId } | ConvertTo-Json -Depth 5
    $addUri   = "https://vssps.dev.azure.com/$Organization/_apis/graph/groups?api-version=$ApiVersion"
    $newGroup = Invoke-AdoApi -Method POST -Uri $addUri -Token $Token -Body $payload

    if ($null -eq $newGroup -or [string]::IsNullOrWhiteSpace($newGroup.descriptor)) {
        throw "Failed to link Entra group '$GroupOriginId' to the organization."
    }
    return $newGroup.descriptor
}

function Get-SourceGroupDescriptorIfExists {
    param([string]$Organization, [string]$GroupOriginId, [string]$Token, [string]$ApiVersion)

    $uri    = "https://vssps.dev.azure.com/$Organization/_apis/graph/groups?api-version=$ApiVersion"
    $groups = Invoke-AdoApi -Method GET -Uri $uri -Token $Token

    if ($null -ne $groups -and $null -ne $groups.value) {
        $existing = $groups.value | Where-Object { $_.originId -eq $GroupOriginId } | Select-Object -First 1
        if ($null -ne $existing) { return $existing.descriptor }
    }
    return $null
}

function Test-IsMember {
    param([string]$Organization, [string]$SubjectDescriptor, [string]$ContainerDescriptor, [string]$Token, [string]$ApiVersion)

    try {
        $encSubject   = [uri]::EscapeDataString($SubjectDescriptor)
        $encContainer = [uri]::EscapeDataString($ContainerDescriptor)
        $uri = "https://vssps.dev.azure.com/$Organization/_apis/graph/memberships/$($encSubject)/$($encContainer)?api-version=$ApiVersion"
        Invoke-AdoApi -Method GET -Uri $uri -Token $Token | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

$desired = $jsonInput | ConvertFrom-Json

$org         = $desired.organization
$originId    = $desired.groupOriginId
$displayName = $desired.groupDisplayName
$permLevel   = $desired.permissionLevel
$token       = Get-TokenValue -Value $desired.pat
$apiVersion  = if ($desired.apiVersion) { $desired.apiVersion } else { '7.1-preview.1' }
$ensure      = if ($desired.ensure) { $desired.ensure } else { 'Present' }

if ([string]::IsNullOrWhiteSpace($token)) {
    Write-DscTrace -Level Error -Message 'pat is required and must not be empty.'
    exit 1
}
if ([string]::IsNullOrWhiteSpace($org)) {
    Write-DscTrace -Level Error -Message 'organization is required and must not be empty.'
    exit 1
}

$groupDisplayName = Get-GroupDisplayName -PermissionLevel $permLevel

switch ($Operation) {

    'Get' {
        try {
            $orgGroupDesc    = Get-OrgGroupDescriptor -Organization $org -GroupDisplayName $groupDisplayName -Token $token -ApiVersion $apiVersion
            $sourceGroupDesc = Get-SourceGroupDescriptorIfExists -Organization $org -GroupOriginId $originId -Token $token -ApiVersion $apiVersion

            $isMember = $false
            if ($null -ne $sourceGroupDesc) {
                $isMember = Test-IsMember -Organization $org -SubjectDescriptor $sourceGroupDesc -ContainerDescriptor $orgGroupDesc -Token $token -ApiVersion $apiVersion
            }

            $rEnsure = if ($isMember) { 'Present' } else { 'Absent' }
            [ordered]@{
                groupOriginId    = $originId
                groupDisplayName = $displayName
                permissionLevel  = $permLevel
                organization     = $org
                ensure           = $rEnsure
                pat              = $desired.pat
                apiVersion       = $apiVersion
                _inDesiredState  = $null
            } | ConvertTo-Json -Compress
        }
        catch {
            Write-DscTrace -Level Error -Message "Get failed: $_"
            exit 1
        }
    }

    'Test' {
        try {
            $orgGroupDesc    = Get-OrgGroupDescriptor -Organization $org -GroupDisplayName $groupDisplayName -Token $token -ApiVersion $apiVersion
            $sourceGroupDesc = Get-SourceGroupDescriptorIfExists -Organization $org -GroupOriginId $originId -Token $token -ApiVersion $apiVersion

            $isMember = $false
            if ($null -ne $sourceGroupDesc) {
                $isMember = Test-IsMember -Organization $org -SubjectDescriptor $sourceGroupDesc -ContainerDescriptor $orgGroupDesc -Token $token -ApiVersion $apiVersion
            }

            $inDesiredState = if ($ensure -eq 'Present') { $isMember } else { -not $isMember }
            $rEnsure        = if ($isMember) { 'Present' } else { 'Absent' }

            [ordered]@{
                groupOriginId    = $originId
                groupDisplayName = $displayName
                permissionLevel  = $permLevel
                organization     = $org
                ensure           = $rEnsure
                pat              = $desired.pat
                apiVersion       = $apiVersion
                _inDesiredState  = $inDesiredState
            } | ConvertTo-Json -Compress
        }
        catch {
            Write-DscTrace -Level Error -Message "Test failed: $_"
            exit 1
        }
    }

    'Set' {
        try {
            $orgGroupDesc    = Get-OrgGroupDescriptor -Organization $org -GroupDisplayName $groupDisplayName -Token $token -ApiVersion $apiVersion

            if ($ensure -eq 'Present') {
                # Ensure/link the Entra group before adding membership
                $sourceGroupDesc = Get-OrEnsureSourceGroupDescriptor -Organization $org -GroupOriginId $originId -Token $token -ApiVersion $apiVersion

                Write-DscTrace -Level Info -Message "Adding Entra group '$originId' to '$groupDisplayName' in organization '$org'."
                $encSource = [uri]::EscapeDataString($sourceGroupDesc)
                $encTarget = [uri]::EscapeDataString($orgGroupDesc)
                $uri = "https://vssps.dev.azure.com/$org/_apis/graph/memberships/$($encSource)/$($encTarget)?api-version=$apiVersion"
                Invoke-AdoApi -Method PUT -Uri $uri -Token $token -Body '' | Out-Null
                Write-DscTrace -Level Info -Message "Membership added successfully."
            }
            else {
                $sourceGroupDesc = Get-SourceGroupDescriptorIfExists -Organization $org -GroupOriginId $originId -Token $token -ApiVersion $apiVersion

                if ($null -ne $sourceGroupDesc) {
                    Write-DscTrace -Level Info -Message "Removing Entra group '$originId' from '$groupDisplayName' in organization '$org'."
                    $encSource = [uri]::EscapeDataString($sourceGroupDesc)
                    $encTarget = [uri]::EscapeDataString($orgGroupDesc)
                    $uri = "https://vssps.dev.azure.com/$org/_apis/graph/memberships/$($encSource)/$($encTarget)?api-version=$apiVersion"
                    Invoke-AdoApi -Method DELETE -Uri $uri -Token $token | Out-Null
                    Write-DscTrace -Level Info -Message "Membership removed successfully."
                }
                else {
                    Write-DscTrace -Level Info -Message "Entra group '$originId' is not linked to the organization; no action required."
                }
            }

            # Return current state after set
            $sourceGroupDesc = Get-SourceGroupDescriptorIfExists -Organization $org -GroupOriginId $originId -Token $token -ApiVersion $apiVersion
            $isMember = $false
            if ($null -ne $sourceGroupDesc) {
                $isMember = Test-IsMember -Organization $org -SubjectDescriptor $sourceGroupDesc -ContainerDescriptor $orgGroupDesc -Token $token -ApiVersion $apiVersion
            }

            $rEnsure = if ($isMember) { 'Present' } else { 'Absent' }
            [ordered]@{
                groupOriginId    = $originId
                groupDisplayName = $displayName
                permissionLevel  = $permLevel
                organization     = $org
                ensure           = $rEnsure
                pat              = $desired.pat
                apiVersion       = $apiVersion
                _inDesiredState  = $null
            } | ConvertTo-Json -Compress
        }
        catch {
            Write-DscTrace -Level Error -Message "Set failed: $_"
            exit 1
        }
    }
}
