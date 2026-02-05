enum Ensure {
    Present
    Absent
}

enum SourceControl {
    Git
    Tfvc
}

enum RequiredAction
{
    None
    Get
    New
    Set
    Remove
    Test
    Error
}

enum ProjectPermissionLevel {
    ProjectAdministrator
    ProjectContributor
    ProjectReader
}

<#
.SYNOPSIS
Manages Azure DevOps projects for an organization.
.PARAMETER ProjectName
Azure DevOps project name.
.PARAMETER Description
Optional project description.
.PARAMETER SourceControlType
Source control type for the project (Git or Tfvc).
.PARAMETER Organization
Azure DevOps organization name.
.PARAMETER Ensure
Desired state: Present or Absent.
.PARAMETER pat
Personal access token used for authentication.
.PARAMETER templateTypeId
Process template type ID used when creating a project.
.PARAMETER apiVersion
Azure DevOps REST API version.
#>
[DscResource()]
class ProjectResource {
    [DscProperty(Key)]
    [string]$ProjectName

    [DscProperty()]
    [string]$Description

    [DscProperty()]
    [string]$SourceControlType = [SourceControl]::Git

    [DscProperty(Mandatory)]
    [string]$Organization

    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty(Mandatory)]
    [Alias('Token','PersonalAccessToken')]
    [System.String]
    $pat

    [DscProperty()]
    [string]$templateTypeId = "adcc42ab-9882-485e-a3ed-7678f01f66bc"

    [DscProperty()]
    [string]$apiVersion = "7.1"
    hidden [string] GetTokenValue() {
        if ($this.pat -is [hashtable]) {
            $keyNames = @("value", "secureString", "Token", "PersonalAccessToken", "pat", "_value")
            foreach ($key in $keyNames) {
                if ($this.pat.ContainsKey($key)) {
                    return $this.pat[$key].ToString()
                }
            }
            
            $firstKey = $this.pat.Keys | Select-Object -First 1
            if ($firstKey) {
                return $this.pat[$firstKey].ToString()
            }
        }
        
        return $this.pat.ToString()
    }

    hidden [object] CallApi([string]$Method, [string]$UriSuffix, [string]$Body) {
        [string]$StringToken = $this.GetTokenValue()
        $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$StringToken"))

        $BaseUrl = "https://dev.azure.com/$($this.Organization)/_apis"
        $Uri = $BaseUrl + "/projects" + $UriSuffix + "?api-version=$($this.apiVersion)"
        $Headers = @{
            Authorization = "Basic $Base64AuthInfo"
            "Content-Type" = "application/json"
        }

        if ($Method -eq "PATCH") {
            $Headers["Content-Type"] = "application/json-patch+json"
        }

        if ($Method -eq "PATCH") {
            $Headers["Content-Type"] = "application/json-patch+json"
        }

        $Params = @{
            Uri     = $Uri
            Method  = $Method
            Headers = $Headers
            ErrorAction = "Stop"
        }

        if ($Body) { $Params.Body = $Body }

        try {
            return Invoke-RestMethod @Params
        }
        catch {
            $errorMsg = $_
            Write-Error "ProjectResource.CallApi error: $errorMsg"
            if ($_.Exception.Response) {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd()
                Write-Error "ProjectResource API Response Body: $responseBody"
            }
            throw
        }
    }

    [bool] Test() {
        try {
            $EncodedName = [uri]::EscapeDataString($this.ProjectName)
            $Project = $this.CallApi("GET", "/$EncodedName", $null)
            $Exists = $null -ne $Project
            
            if ($this.Ensure -eq [Ensure]::Present) {
                return $Exists
            } else {
                return !$Exists
            }
        }
        catch {
            return $this.Ensure -eq [Ensure]::Absent
        }
    }

    [void] Set() {
        if ($this.Ensure -eq [Ensure]::Present) {
            # Check if project already exists
            try {
                $EncodedName = [uri]::EscapeDataString($this.ProjectName)
                $Project = $this.CallApi("GET", "/$EncodedName", $null)
                if ($Project) {
                    return
                }
            }
            catch {
                # Project doesn't exist, continue with creation
            }

            $Payload = @{
                name = $this.ProjectName
                capabilities = @{
                    versioncontrol = @{
                        sourceControlType = $this.SourceControlType
                    }
                    processTemplate = @{
                        templateTypeId = $this.templateTypeId
                    }
                }
            }

            if (![string]::IsNullOrEmpty($this.Description)) {
                $Payload.description = $this.Description
            }

            $JsonPayload = $Payload | ConvertTo-Json -Depth 10
            $this.CallApi("POST", "", $JsonPayload)
        }
        else {
            Write-Host "DEBUG: Deleting project: $($this.ProjectName)"
            $EncodedName = [uri]::EscapeDataString($this.ProjectName)
            try {
                $Project = $this.CallApi("GET", "/$EncodedName", $null)
                if ($Project) {
                    $ProjectId = $Project.id
                    $this.CallApi("DELETE", "/$ProjectId", $null)
                }
            }
            catch {
                # Project not found; nothing to delete
            }
        }
    }

    [ProjectResource] Get() {
        try {
            $EncodedName = [uri]::EscapeDataString($this.ProjectName)
            $Project = $this.CallApi("GET", "/$EncodedName", $null)
            return [ProjectResource]@{
                ProjectName       = $Project.name
                Description       = $Project.description
                SourceControlType = $Project.capabilities.versioncontrol.sourceControlType
                Ensure            = [Ensure]::Present
            }
        }
        catch {
            return [ProjectResource]@{
                ProjectName = $this.ProjectName
                Ensure      = [Ensure]::Absent
            }
        }
    }
}
<#
.SYNOPSIS
Manages Azure DevOps user entitlements for an organization.
.PARAMETER UserPrincipalName
User principal name (email) to manage entitlements for.
.PARAMETER Organization
Azure DevOps organization name.
.PARAMETER AccessLevel
Access level: Stakeholder, Basic, or BasicPlusTestPlans.
.PARAMETER Ensure
Desired state: Present or Absent.
.PARAMETER pat
Personal access token used for authentication.
.PARAMETER apiVersion
Azure DevOps REST API version.
#>
[DscResource()]
class OrganizationUserResource {
    [DscProperty(Key)]
    [string]$UserPrincipalName

    [DscProperty(Mandatory)]
    [string]$Organization

    [DscProperty()]
    [string]$AccessLevel = "Stakeholder"

    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty(Mandatory)]
    [Alias('Token','PersonalAccessToken')]
    [string]$pat

    [DscProperty()]
    [string]$apiVersion = "7.1-preview.1"

    hidden [string] GetTokenValue() {
        if ($this.pat -is [hashtable]) {
            $keyNames = @("value", "secureString", "Token", "PersonalAccessToken", "pat", "_value")
            foreach ($key in $keyNames) {
                if ($this.pat.ContainsKey($key)) {
                    return $this.pat[$key].ToString()
                }
            }
            
            $firstKey = $this.pat.Keys | Select-Object -First 1
            if ($firstKey) {
                return $this.pat[$firstKey].ToString()
            }
        }
        
        return $this.pat.ToString()
    }

    hidden [string] GetOrganizationValue() {
        if ($this.Organization -is [hashtable]) {
            $firstValue = $this.Organization.Values | Select-Object -First 1
            if ($firstValue) { return $firstValue.ToString() }
        }
        return $this.Organization
    }

    hidden [object] CallApi([string]$Method, [string]$UriSuffix, [string]$Body) {
        [string]$StringToken = $this.GetTokenValue()
        [string]$OrgName = $this.GetOrganizationValue()
        
        if ([string]::IsNullOrWhiteSpace($StringToken)) {
            throw "Token is null or empty"
        }
        
        if ([string]::IsNullOrWhiteSpace($OrgName)) {
            throw "Organization is null or empty"
        }
        
        $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$StringToken"))

        $BaseUrl = "https://vsaex.dev.azure.com/$OrgName/_apis"
        $Uri = $BaseUrl + $UriSuffix + "?api-version=$($this.apiVersion)"
        $Headers = @{
            Authorization = "Basic $Base64AuthInfo"
            "Content-Type" = "application/json"
        }

        if ($Method -eq "PATCH") {
            $Headers["Content-Type"] = "application/json-patch+json"
        }

        $Params = @{
            Uri     = $Uri
            Method  = $Method
            Headers = $Headers
            ErrorAction = "Stop"
        }

        if ($Body) { $Params.Body = $Body }

        try {
            return Invoke-RestMethod @Params
        }
        catch {
            $errorMsg = $_
            Write-Error "OrganizationUserResource.CallApi error: $errorMsg"
            if ($_.Exception.Response) {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd()
                Write-Error "OrganizationUserResource API Response Body: $responseBody"
            }
            throw
        }
    }

    hidden [string] GetAccountLicenseType() {
        $result = switch ($this.AccessLevel) {
            "Stakeholder" { "stakeholder" }
            "Basic" { "express" }
            "BasicPlusTestPlans" { "advanced" }
            default { "stakeholder" }
        }
        return $result
    }

    [bool] Test() {
        try {
            Write-Verbose "Test() - Checking user: $($this.UserPrincipalName)"
            
            $users = $this.CallApi("GET", "/userentitlements", $null)
            
            if ($null -eq $users -or $null -eq $users.value) {
                Write-Verbose "Test() - No users returned from API"
                return $this.Ensure -eq [Ensure]::Absent
            }
            
            $existingUser = $users.value | Where-Object { $_.user.principalName -eq $this.UserPrincipalName }
            
            if ($this.Ensure -eq [Ensure]::Present) {
                if ($existingUser) {
                    $currentLicense = $existingUser.accessLevel.accountLicenseType
                    $desiredLicense = $this.GetAccountLicenseType()
                    $match = $currentLicense -eq $desiredLicense
                    Write-Verbose "Test() - User exists with license: $currentLicense, desired: $desiredLicense, match: $match"
                    return $match
                }
                Write-Verbose "Test() - User does not exist"
                return $false
            } else {
                $exists = $null -ne $existingUser
                Write-Verbose "Test() - Ensure=Absent, user exists: $exists"
                return !$exists
            }
        }
        catch {
            Write-Error "Test() - Error: $_"
            return $this.Ensure -eq [Ensure]::Absent
        }
    }

    [void] Set() {
        try {
            if ($this.Ensure -eq [Ensure]::Present) {
                # Check if user already exists and matches desired license
                $users = $this.CallApi("GET", "/userentitlements", $null)
                $existingUser = $users.value | Where-Object { $_.user.principalName -eq $this.UserPrincipalName }

                if ($null -eq $existingUser) {
                    $Payload = @{
                        accessLevel = @{
                            accountLicenseType = $this.GetAccountLicenseType()
                            licensingSource = "account"
                        }
                        user = @{
                            principalName = $this.UserPrincipalName
                            subjectKind = "user"
                        }
                        projectEntitlements = @()
                    }

                    $JsonPayload = $Payload | ConvertTo-Json -Depth 10
                    $response = $this.CallApi("POST", "/userentitlements", $JsonPayload)
                }
                else {
                    $userId = $existingUser.id
                    $Payload = @(
                        @{
                            op = "replace"
                            path = "/accessLevel"
                            value = @{
                                accountLicenseType = $this.GetAccountLicenseType()
                                licensingSource = "account"
                            }
                        }
                    )

                    $JsonPayload = ConvertTo-Json -Depth 10 -InputObject $Payload
                    $response = $this.CallApi("PATCH", "/userentitlements/$userId", $JsonPayload)
                }
            }
            else {
                $users = $this.CallApi("GET", "/userentitlements", $null)
                $existingUser = $users.value | Where-Object { $_.user.principalName -eq $this.UserPrincipalName }
                
                if ($existingUser) {
                    $userId = $existingUser.id
                    $this.CallApi("DELETE", "/userentitlements/$userId", $null)
                }
            }
        }
        catch {
            Write-Error "Set() - Error: $_"
            throw
        }
    }

    [OrganizationUserResource] Get() {
        try {
            Write-Verbose "Get() - Retrieving user: $($this.UserPrincipalName)"
            
            $users = $this.CallApi("GET", "/userentitlements", $null)
            
            if ($null -eq $users) {
                Write-Verbose "Get() - No users found"
                $result = [OrganizationUserResource]::new()
                $result.UserPrincipalName = $this.UserPrincipalName
                $result.Organization = $this.GetOrganizationValue()
                $result.Ensure = [Ensure]::Absent
                $result.pat = $this.pat
                $result.apiVersion = $this.apiVersion
                return $result
            }
            
            $existingUser = $users.value | Where-Object { $_.user.principalName -eq $this.UserPrincipalName }
            
            if ($existingUser) {
                Write-Verbose "Get() - User found"
                $licenseType = $existingUser.accessLevel.accountLicenseType
                $userAccessLevel = switch ($licenseType) {
                    "stakeholder" { "Stakeholder" }
                    "express" { "Basic" }
                    "advanced" { "BasicPlusTestPlans" }
                    default { "Stakeholder" }
                }

                $result = [OrganizationUserResource]::new()
                $result.UserPrincipalName = $existingUser.user.principalName
                $result.Organization = $this.GetOrganizationValue()
                $result.AccessLevel = $userAccessLevel
                $result.Ensure = [Ensure]::Present
                $result.pat = $this.pat
                $result.apiVersion = $this.apiVersion
                return $result
            }
            else {
                Write-Verbose "Get() - User not found"
                $result = [OrganizationUserResource]::new()
                $result.UserPrincipalName = $this.UserPrincipalName
                $result.Organization = $this.GetOrganizationValue()
                $result.AccessLevel = $this.AccessLevel
                $result.Ensure = [Ensure]::Absent
                $result.pat = $this.pat
                $result.apiVersion = $this.apiVersion
                return $result
            }
        }
        catch {
            Write-Error "Get() - Error: $_"
            
            $result = [OrganizationUserResource]::new()
            $result.UserPrincipalName = $this.UserPrincipalName
            $result.Organization = $this.GetOrganizationValue()
            $result.Ensure = [Ensure]::Absent
            $result.pat = $this.pat
            $result.apiVersion = $this.apiVersion
            return $result
        }
    }
}
<#
.SYNOPSIS
Manages Azure DevOps group entitlements for an organization.
.PARAMETER GroupOriginId
Origin ID of the group in Azure DevOps.
.PARAMETER GroupDisplayName
Optional display name for the group.
.PARAMETER Organization
Azure DevOps organization name.
.PARAMETER AccessLevel
Access level: Stakeholder, Basic, or BasicPlusTestPlans.
.PARAMETER Ensure
Desired state: Present or Absent.
.PARAMETER pat
Personal access token used for authentication.
.PARAMETER apiVersion
Azure DevOps REST API version.
#>
[DscResource()]
class OrganizationGroupResource {
    [DscProperty(Key)]
    [string]$GroupOriginId

    [DscProperty()]
    [string]$GroupDisplayName

    [DscProperty(Mandatory)]
    [string]$Organization

    [DscProperty()]
    [string]$AccessLevel = "Stakeholder"

    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty(Mandatory)]
    [Alias('Token','PersonalAccessToken')]
    [string]$pat

    [DscProperty()]
    [string]$apiVersion = "7.1-preview.1"

    hidden [string] GetTokenValue() {
        if ($this.pat -is [hashtable]) {
            $keyNames = @("value", "secureString", "Token", "PersonalAccessToken", "pat", "_value")
            foreach ($key in $keyNames) {
                if ($this.pat.ContainsKey($key)) {
                    return $this.pat[$key].ToString()
                }
            }

            $firstKey = $this.pat.Keys | Select-Object -First 1
            if ($firstKey) {
                return $this.pat[$firstKey].ToString()
            }
        }

        return $this.pat.ToString()
    }

    hidden [string] GetOrganizationValue() {
        if ($this.Organization -is [hashtable]) {
            $firstValue = $this.Organization.Values | Select-Object -First 1
            if ($firstValue) { return $firstValue.ToString() }
        }
        return $this.Organization
    }

    hidden [object] CallApi([string]$Method, [string]$UriSuffix, [string]$Body) {
        [string]$StringToken = $this.GetTokenValue()
        [string]$OrgName = $this.GetOrganizationValue()

        if ([string]::IsNullOrWhiteSpace($StringToken)) {
            throw "Token is null or empty"
        }

        if ([string]::IsNullOrWhiteSpace($OrgName)) {
            throw "Organization is null or empty"
        }

        $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$StringToken"))

        $BaseUrl = "https://vsaex.dev.azure.com/$OrgName/_apis"
        $Uri = $BaseUrl + $UriSuffix + "?api-version=$($this.apiVersion)"
        $Headers = @{
            Authorization = "Basic $Base64AuthInfo"
            "Content-Type" = "application/json"
        }

        if ($Method -eq "PATCH") {
            $Headers["Content-Type"] = "application/json-patch+json"
        }

        $Params = @{
            Uri     = $Uri
            Method  = $Method
            Headers = $Headers
            ErrorAction = "Stop"
        }

        if ($Body) { $Params.Body = $Body }

        try {
            return Invoke-RestMethod @Params
        }
        catch {
            $errorMsg = $_
            Write-Error "OrganizationGroupResource.CallApi error: $errorMsg"
            if ($_.Exception.Response) {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd()
                Write-Error "OrganizationGroupResource API Response Body: $responseBody"
            }
            throw
        }
    }

    hidden [string] GetAccountLicenseType() {
        $result = switch ($this.AccessLevel) {
            "Stakeholder" { "stakeholder" }
            "Basic" { "express" }
            "BasicPlusTestPlans" { "advanced" }
            default { "stakeholder" }
        }
        return $result
    }

    [bool] Test() {
        try {
            Write-Verbose "Test() - Checking group entitlement: $($this.GroupOriginId)"

            $groups = $this.CallApi("GET", "/groupentitlements", $null)

            if ($null -eq $groups -or $null -eq $groups.value) {
                Write-Verbose "Test() - No group entitlements returned from API"
                return $this.Ensure -eq [Ensure]::Absent
            }

            $existingGroup = $groups.value | Where-Object { $_.group.originId -eq $this.GroupOriginId }

            if ($this.Ensure -eq [Ensure]::Present) {
                if ($existingGroup) {
                    $currentLicense = $existingGroup.licenseRule.accountLicenseType
                    $desiredLicense = $this.GetAccountLicenseType()
                    $match = $currentLicense -eq $desiredLicense
                    Write-Verbose "Test() - Group exists with license: $currentLicense, desired: $desiredLicense, match: $match"
                    return $match
                }
                Write-Verbose "Test() - Group entitlement does not exist"
                return $false
            } else {
                $exists = $null -ne $existingGroup
                Write-Verbose "Test() - Ensure=Absent, group exists: $exists"
                return !$exists
            }
        }
        catch {
            Write-Error "Test() - Error: $_"
            return $this.Ensure -eq [Ensure]::Absent
        }
    }

    [void] Set() {
        try {
            if ($this.Ensure -eq [Ensure]::Present) {
                $groups = $this.CallApi("GET", "/groupentitlements", $null)
                $existingGroup = $groups.value | Where-Object { $_.group.originId -eq $this.GroupOriginId }

                if ($null -eq $existingGroup) {
                    $Payload = @{
                        group = @{
                            originId = $this.GroupOriginId
                            subjectKind = "group"
                        }
                        licenseRule = @{
                            accountLicenseType = $this.GetAccountLicenseType()
                            licensingSource = "account"
                        }
                    }

                    if (![string]::IsNullOrWhiteSpace($this.GroupDisplayName)) {
                        $Payload.group.displayName = $this.GroupDisplayName
                    }

                    $JsonPayload = $Payload | ConvertTo-Json -Depth 10
                    $response = $this.CallApi("POST", "/groupentitlements", $JsonPayload)
                }
                else {
                    $groupId = $existingGroup.id
                    $Payload = @(
                        @{
                            op = "replace"
                            path = "/licenseRule/accountLicenseType"
                            value = $this.GetAccountLicenseType()
                        }
                        @{
                            op = "replace"
                            path = "/licenseRule/licensingSource"
                            value = "account"
                        }
                    )

                    $JsonPayload = ConvertTo-Json -Depth 10 -InputObject $Payload
                    $response = $this.CallApi("PATCH", "/groupentitlements/$groupId", $JsonPayload)
                }
            }
            else {
                $groups = $this.CallApi("GET", "/groupentitlements", $null)
                $existingGroup = $groups.value | Where-Object { $_.group.originId -eq $this.GroupOriginId }

                if ($existingGroup) {
                    $groupId = $existingGroup.id
                    $this.CallApi("DELETE", "/groupentitlements/$groupId", $null)
                }
            }
        }
        catch {
            Write-Error "Set() - Error: $_"
            throw
        }
    }

    [OrganizationGroupResource] Get() {
        try {
            Write-Verbose "Get() - Retrieving group entitlement: $($this.GroupOriginId)"

            $groups = $this.CallApi("GET", "/groupentitlements", $null)

            if ($null -eq $groups) {
                Write-Verbose "Get() - No group entitlements found"
                $result = [OrganizationGroupResource]::new()
                $result.GroupOriginId = $this.GroupOriginId
                $result.Organization = $this.GetOrganizationValue()
                $result.Ensure = [Ensure]::Absent
                $result.pat = $this.pat
                $result.apiVersion = $this.apiVersion
                return $result
            }

            $existingGroup = $groups.value | Where-Object { $_.group.originId -eq $this.GroupOriginId }

            if ($existingGroup) {
                Write-Verbose "Get() - Group entitlement found"
                $licenseType = $existingGroup.licenseRule.accountLicenseType
                $groupAccessLevel = switch ($licenseType) {
                    "stakeholder" { "Stakeholder" }
                    "express" { "Basic" }
                    "advanced" { "BasicPlusTestPlans" }
                    default { "Stakeholder" }
                }

                $result = [OrganizationGroupResource]::new()
                $result.GroupOriginId = $existingGroup.group.originId
                $result.GroupDisplayName = $existingGroup.group.displayName
                $result.Organization = $this.GetOrganizationValue()
                $result.AccessLevel = $groupAccessLevel
                $result.Ensure = [Ensure]::Present
                $result.pat = $this.pat
                $result.apiVersion = $this.apiVersion
                return $result
            }
            else {
                Write-Verbose "Get() - Group entitlement not found"
                $result = [OrganizationGroupResource]::new()
                $result.GroupOriginId = $this.GroupOriginId
                $result.GroupDisplayName = $this.GroupDisplayName
                $result.Organization = $this.GetOrganizationValue()
                $result.AccessLevel = $this.AccessLevel
                $result.Ensure = [Ensure]::Absent
                $result.pat = $this.pat
                $result.apiVersion = $this.apiVersion
                return $result
            }
        }
        catch {
            Write-Error "Get() - Error: $_"

            $result = [OrganizationGroupResource]::new()
            $result.GroupOriginId = $this.GroupOriginId
            $result.GroupDisplayName = $this.GroupDisplayName
            $result.Organization = $this.GetOrganizationValue()
            $result.Ensure = [Ensure]::Absent
            $result.pat = $this.pat
            $result.apiVersion = $this.apiVersion
            return $result
        }
    }
}

<#
.SYNOPSIS
Manages Azure DevOps project-level permissions for a user or group.
.PARAMETER ProjectName
Azure DevOps project name.
.PARAMETER IdentityDescriptor
Identity descriptor for user or group (e.g., Microsoft.IdentityModel.Claims.ClaimsIdentity;...)
.PARAMETER Organization
Azure DevOps organization name.
.PARAMETER PermissionLevel
Permission level: Project Administrator, Project Contributor, or Project Reader.
.PARAMETER Ensure
Desired state: Present or Absent.
.PARAMETER pat
Personal access token used for authentication.
.PARAMETER apiVersion
Azure DevOps REST API version.
.PARAMETER namespaceId
Security namespace ID for project permissions.
.PARAMETER securityToken
Optional security token. If not provided, project ID is used.
#>
[DscResource()]
class ProjectPermissionResource {
    [DscProperty(Key)]
    [string]$ProjectName

    [DscProperty(Key)]
    [string]$IdentityDescriptor

    [DscProperty(Mandatory)]
    [string]$Organization

    [DscProperty()]
    [ValidateSet('Project Administrator','Project Contributor','Project Reader')]
    [string]$PermissionLevel = 'Project Reader'

    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty(Mandatory)]
    [Alias('Token','PersonalAccessToken')]
    [string]$pat

    [DscProperty()]
    [string]$apiVersion = '7.1-preview.1'

    [DscProperty()]
    [string]$namespaceId = '52d39943-cb85-4d7f-8fa8-c6baac873819'

    [DscProperty()]
    [string]$securityToken

    hidden [string] GetTokenValue() {
        if ($this.pat -is [hashtable]) {
            $keyNames = @('value', 'secureString', 'Token', 'PersonalAccessToken', 'pat', '_value')
            foreach ($key in $keyNames) {
                if ($this.pat.ContainsKey($key)) {
                    return $this.pat[$key].ToString()
                }
            }

            $firstKey = $this.pat.Keys | Select-Object -First 1
            if ($firstKey) {
                return $this.pat[$firstKey].ToString()
            }
        }

        return $this.pat.ToString()
    }

    hidden [string] GetOrganizationValue() {
        if ($this.Organization -is [hashtable]) {
            $firstValue = $this.Organization.Values | Select-Object -First 1
            if ($firstValue) { return $firstValue.ToString() }
        }
        return $this.Organization
    }

    hidden [int] GetPermissionBits() {
        $reader = 1
        $contributor = 3
        $administrator = 63

        return switch ($this.PermissionLevel) {
            'Project Administrator' { $administrator }
            'Project Contributor' { $contributor }
            'Project Reader' { $reader }
            default { $reader }
        }
    }

    hidden [string] GetPermissionLevelFromBits([int]$allowBits) {
        if (($allowBits -band 63) -eq 63) { return 'Project Administrator' }
        if (($allowBits -band 3) -eq 3) { return 'Project Contributor' }
        if (($allowBits -band 1) -eq 1) { return 'Project Reader' }
        return 'Project Reader'
    }

    hidden [object] CallProjectApi([string]$Method, [string]$UriSuffix, [string]$Body) {
        [string]$StringToken = $this.GetTokenValue()
        [string]$OrgName = $this.GetOrganizationValue()

        $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$StringToken"))
        $BaseUrl = "https://dev.azure.com/$OrgName/_apis"
        $Uri = $BaseUrl + "/projects" + $UriSuffix + "?api-version=7.1"
        $Headers = @{
            Authorization = "Basic $Base64AuthInfo"
            "Content-Type" = "application/json"
        }

        $Params = @{
            Uri = $Uri
            Method = $Method
            Headers = $Headers
            ErrorAction = 'Stop'
        }

        if ($Body) { $Params.Body = $Body }

        return Invoke-RestMethod @Params
    }

    hidden [object] CallAccessControlEntries([string]$Method, [string]$Query, [string]$Body) {
        [string]$StringToken = $this.GetTokenValue()
        [string]$OrgName = $this.GetOrganizationValue()

        $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$StringToken"))
        $BaseUrl = "https://dev.azure.com/$OrgName/_apis"
        $Uri = $BaseUrl + "/accesscontrolentries/$($this.namespaceId)" + $Query + "&api-version=$($this.apiVersion)"
        $Headers = @{
            Authorization = "Basic $Base64AuthInfo"
            "Content-Type" = "application/json"
        }

        $Params = @{
            Uri = $Uri
            Method = $Method
            Headers = $Headers
            ErrorAction = 'Stop'
        }

        if ($Body) { $Params.Body = $Body }

        return Invoke-RestMethod @Params
    }

    hidden [string] GetProjectId() {
        $encodedName = [uri]::EscapeDataString($this.ProjectName)
        $project = $this.CallProjectApi('GET', "/$encodedName", $null)
        return $project.id
    }

    hidden [string] GetSecurityToken() {
        if (![string]::IsNullOrWhiteSpace($this.securityToken)) {
            return $this.securityToken
        }

        return $this.GetProjectId()
    }

    [bool] Test() {
        try {
            $token = $this.GetSecurityToken()
            $descriptor = [uri]::EscapeDataString($this.IdentityDescriptor)
            $tokenEncoded = [uri]::EscapeDataString($token)
            $response = $this.CallAccessControlEntries('GET', "?token=$tokenEncoded&descriptors=$descriptor", $null)

            if ($null -eq $response -or $null -eq $response.value -or $response.count -eq 0) {
                return $this.Ensure -eq [Ensure]::Absent
            }

            $entry = $response.value | Select-Object -First 1
            $desiredBits = $this.GetPermissionBits()
            $hasDesired = (($entry.allow -band $desiredBits) -eq $desiredBits) -and (($entry.deny -band $desiredBits) -eq 0)

            if ($this.Ensure -eq [Ensure]::Present) {
                return $hasDesired
            }

            return -not $hasDesired
        }
        catch {
            return $this.Ensure -eq [Ensure]::Absent
        }
    }

    [void] Set() {
        $token = $this.GetSecurityToken()
        $descriptor = $this.IdentityDescriptor
        $desiredBits = $this.GetPermissionBits()

        if ($this.Ensure -eq [Ensure]::Present) {
            $payload = @{
                token = $token
                merge = $true
                accessControlEntries = @(
                    @{ descriptor = $descriptor; allow = $desiredBits; deny = 0 }
                )
            }

            $jsonPayload = $payload | ConvertTo-Json -Depth 10
            $this.CallAccessControlEntries('POST', "?token=$([uri]::EscapeDataString($token))", $jsonPayload) | Out-Null
        }
        else {
            $tokenEncoded = [uri]::EscapeDataString($token)
            $descriptorEncoded = [uri]::EscapeDataString($descriptor)
            $this.CallAccessControlEntries('DELETE', "?tokens=$tokenEncoded&descriptors=$descriptorEncoded", $null) | Out-Null
        }
    }

    [ProjectPermissionResource] Get() {
        $result = [ProjectPermissionResource]::new()
        $result.ProjectName = $this.ProjectName
        $result.IdentityDescriptor = $this.IdentityDescriptor
        $result.Organization = $this.GetOrganizationValue()
        $result.pat = $this.pat
        $result.apiVersion = $this.apiVersion
        $result.namespaceId = $this.namespaceId
        $result.securityToken = $this.securityToken

        try {
            $token = $this.GetSecurityToken()
            $descriptor = [uri]::EscapeDataString($this.IdentityDescriptor)
            $tokenEncoded = [uri]::EscapeDataString($token)
            $response = $this.CallAccessControlEntries('GET', "?token=$tokenEncoded&descriptors=$descriptor", $null)

            if ($null -eq $response -or $null -eq $response.value -or $response.count -eq 0) {
                $result.Ensure = [Ensure]::Absent
                $result.PermissionLevel = 'Project Reader'
                return $result
            }

            $entry = $response.value | Select-Object -First 1
            $result.PermissionLevel = $this.GetPermissionLevelFromBits($entry.allow)
            $result.Ensure = [Ensure]::Present
            return $result
        }
        catch {
            $result.Ensure = [Ensure]::Absent
            $result.PermissionLevel = 'Project Reader'
            return $result
        }
    }
}