# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
.SYNOPSIS
    DSC v3 resource script for managing Azure DevOps projects.

.DESCRIPTION
    Implements Get, Set, and Test operations for an Azure DevOps project resource.
    Requires network access to https://dev.azure.com and a valid PAT with
    'Project and Team > Read, write, & manage' permission.

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

function Get-ProjectApiBase {
    param([string]$Organization, [string]$ApiVersion)
    return "https://dev.azure.com/$Organization/_apis/projects?api-version=$ApiVersion"
}

function Get-ProjectByName {
    param([string]$Organization, [string]$ProjectName, [string]$Token, [string]$ApiVersion)

    $encoded = [uri]::EscapeDataString($ProjectName)
    $uri = "https://dev.azure.com/$Organization/_apis/projects/$($encoded)?includeCapabilities=true&api-version=$ApiVersion"
    try {
        return Invoke-AdoApi -Method GET -Uri $uri -Token $Token
    }
    catch {
        if ($_ -match '404|NotFound|does not exist') { return $null }
        throw
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

$desired = $jsonInput | ConvertFrom-Json

$org        = $desired.organization
$name       = $desired.projectName
$token      = Get-TokenValue -Value $desired.pat
$apiVersion = if ($desired.apiVersion) { $desired.apiVersion } else { '7.1' }
$ensure     = if ($desired.ensure) { $desired.ensure } else { 'Present' }
$scType     = if ($desired.sourceControlType) { $desired.sourceControlType } else { 'Git' }
$templateId = if ($desired.templateTypeId) { $desired.templateTypeId } else { 'adcc42ab-9882-485e-a3ed-7678f01f66bc' }
$description = $desired.description

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
            $project = Get-ProjectByName -Organization $org -ProjectName $name -Token $token -ApiVersion $apiVersion

            if ($null -ne $project) {
                $result = [ordered]@{
                    projectName       = $project.name
                    description       = $project.description
                    sourceControlType = if ($project.capabilities.versioncontrol.sourceControlType) { $project.capabilities.versioncontrol.sourceControlType } else { $scType }
                    organization      = $org
                    ensure            = 'Present'
                    pat               = $desired.pat
                    apiVersion        = $apiVersion
                    _inDesiredState   = $null
                }
            }
            else {
                $result = [ordered]@{
                    projectName       = $name
                    description       = $null
                    sourceControlType = $scType
                    organization      = $org
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
            $project = Get-ProjectByName -Organization $org -ProjectName $name -Token $token -ApiVersion $apiVersion
            $exists  = $null -ne $project

            $inDesiredState = if ($ensure -eq 'Present') { $exists } else { -not $exists }

            $result = [ordered]@{
                projectName       = $name
                description       = if ($exists) { $project.description } else { $null }
                sourceControlType = if ($exists -and $project.capabilities.versioncontrol.sourceControlType) { $project.capabilities.versioncontrol.sourceControlType } else { $scType }
                organization      = $org
                ensure            = if ($exists) { 'Present' } else { 'Absent' }
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
            $project = Get-ProjectByName -Organization $org -ProjectName $name -Token $token -ApiVersion $apiVersion
            $exists  = $null -ne $project

            if ($ensure -eq 'Present') {
                if (-not $exists) {
                    Write-DscTrace -Level Info -Message "Creating project '$name' in organization '$org'."

                    $payload = @{
                        name         = $name
                        capabilities = @{
                            versioncontrol  = @{ sourceControlType = $scType }
                            processTemplate = @{ templateTypeId    = $templateId }
                        }
                    }
                    if (-not [string]::IsNullOrEmpty($description)) {
                        $payload.description = $description
                    }

                    $uri = "https://dev.azure.com/$org/_apis/projects?api-version=$apiVersion"
                    Invoke-AdoApi -Method POST -Uri $uri -Token $token -Body ($payload | ConvertTo-Json -Depth 10) | Out-Null

                    Write-DscTrace -Level Info -Message "Project '$name' created successfully."
                }
                else {
                    Write-DscTrace -Level Info -Message "Project '$name' already exists; no action required."
                }
            }
            else {
                if ($exists) {
                    Write-DscTrace -Level Info -Message "Deleting project '$name' from organization '$org'."
                    $projectId = $project.id
                    $uri = "https://dev.azure.com/$org/_apis/projects/$($projectId)?api-version=$apiVersion"
                    Invoke-AdoApi -Method DELETE -Uri $uri -Token $token | Out-Null
                    Write-DscTrace -Level Info -Message "Project '$name' deleted successfully."
                }
                else {
                    Write-DscTrace -Level Info -Message "Project '$name' does not exist; no action required."
                }
            }

            # Return current state after set
            $project = Get-ProjectByName -Organization $org -ProjectName $name -Token $token -ApiVersion $apiVersion
            $result = [ordered]@{
                projectName       = $name
                description       = if ($null -ne $project) { $project.description } else { $null }
                sourceControlType = if ($null -ne $project) { $project.capabilities.versioncontrol.sourceControlType } else { $scType }
                organization      = $org
                ensure            = if ($null -ne $project) { 'Present' } else { 'Absent' }
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
