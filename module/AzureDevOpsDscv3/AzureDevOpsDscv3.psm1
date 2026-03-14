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
    BuildAdministrators
    Contributors
    ProjectAdministrators
    ProjectValidUsers
    Readers
    ReleaseAdministrators
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
Manages Azure DevOps project-level user membership (permissions).
.DESCRIPTION
Adds or removes a user (by UPN) to/from a project-level security group such as
Build Administrators, Contributors, Project Administrators, Project Valid Users,
Readers, or Release Administrators. Uses the Azure DevOps Graph REST API.
.PARAMETER ProjectName
Azure DevOps project name.
.PARAMETER UserPrincipalName
User principal name (email) to add or remove from the project group.
.PARAMETER PermissionLevel
The project-level group to manage: BuildAdministrators, Contributors,
ProjectAdministrators, ProjectValidUsers, Readers, or ReleaseAdministrators.
.PARAMETER Organization
Azure DevOps organization name.
.PARAMETER Ensure
Desired state: Present (add membership) or Absent (remove membership).
.PARAMETER pat
Personal access token used for authentication.
.PARAMETER apiVersion
Azure DevOps REST API version for the Graph endpoints.
#>
[DscResource()]
class ProjectUserPermissionResource {
    [DscProperty(Key)]
    [string]$ProjectName

    [DscProperty(Key)]
    [string]$UserPrincipalName

    [DscProperty(Mandatory)]
    [ProjectPermissionLevel]$PermissionLevel

    [DscProperty(Mandatory)]
    [string]$Organization

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

    # Call the main dev.azure.com REST API
    hidden [object] CallProjectApi([string]$Method, [string]$UriSuffix, [string]$Body) {
        [string]$StringToken = $this.GetTokenValue()
        [string]$OrgName = $this.GetOrganizationValue()

        if ([string]::IsNullOrWhiteSpace($StringToken)) { throw "Token is null or empty" }
        if ([string]::IsNullOrWhiteSpace($OrgName)) { throw "Organization is null or empty" }

        $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$StringToken"))
        $Uri = "https://dev.azure.com/$OrgName/_apis" + $UriSuffix
        $Headers = @{
            Authorization  = "Basic $Base64AuthInfo"
            "Content-Type" = "application/json"
        }

        $Params = @{
            Uri         = $Uri
            Method      = $Method
            Headers     = $Headers
            ErrorAction = "Stop"
        }
        if ($Body) { $Params.Body = $Body }

        try {
            return Invoke-RestMethod @Params
        }
        catch {
            Write-Error "ProjectPermissionResource.CallProjectApi error: $_"
            throw
        }
    }

    # Call the vssps.dev.azure.com Graph REST API
    hidden [object] CallGraphApi([string]$Method, [string]$UriSuffix, [string]$Body) {
        [string]$StringToken = $this.GetTokenValue()
        [string]$OrgName = $this.GetOrganizationValue()

        if ([string]::IsNullOrWhiteSpace($StringToken)) { throw "Token is null or empty" }
        if ([string]::IsNullOrWhiteSpace($OrgName)) { throw "Organization is null or empty" }

        $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$StringToken"))
        $Uri = "https://vssps.dev.azure.com/$OrgName/_apis/graph" + $UriSuffix
        $Headers = @{
            Authorization  = "Basic $Base64AuthInfo"
            "Content-Type" = "application/json"
        }

        $Params = @{
            Uri         = $Uri
            Method      = $Method
            Headers     = $Headers
            ErrorAction = "Stop"
        }
        if ($Body) { $Params.Body = $Body }

        try {
            return Invoke-RestMethod @Params
        }
        catch {
            Write-Error "ProjectPermissionResource.CallGraphApi error: $_"
            throw
        }
    }

    # Map enum value to the Azure DevOps display name for the project group
    hidden [string] GetGroupDisplayName() {
        $result = switch ($this.PermissionLevel) {
            'BuildAdministrators'   { "Build Administrators" }
            'Contributors'          { "Contributors" }
            'ProjectAdministrators' { "Project Administrators" }
            'ProjectValidUsers'     { "Project Valid Users" }
            'Readers'               { "Readers" }
            'ReleaseAdministrators' { "Release Administrators" }
            default { throw "Unknown PermissionLevel: $($this.PermissionLevel)" }
        }
        return $result
    }

    # Resolve the project ID from its name
    hidden [string] GetProjectId() {
        $EncodedName = [uri]::EscapeDataString($this.ProjectName)
        $project = $this.CallProjectApi("GET", "/projects/$($EncodedName)?api-version=7.1", $null)
        return $project.id
    }

    # Get the scope descriptor for a project (needed for Graph group queries)
    hidden [string] GetProjectScopeDescriptor([string]$ProjectId) {
        $response = $this.CallGraphApi("GET", "/descriptors/$($ProjectId)?api-version=$($this.apiVersion)", $null)
        return $response.value
    }

    # Find the target group descriptor within the project scope
    hidden [string] GetGroupDescriptor([string]$ScopeDescriptor) {
        $targetName = $this.GetGroupDisplayName()
        $groups = $this.CallGraphApi("GET", "/groups?scopeDescriptor=$ScopeDescriptor&api-version=$($this.apiVersion)", $null)

        if ($null -eq $groups -or $null -eq $groups.value) {
            throw "No groups found for project '$($this.ProjectName)'"
        }

        $group = $groups.value | Where-Object { $_.displayName -eq $targetName }
        if ($null -eq $group) {
            throw "Group '$targetName' not found in project '$($this.ProjectName)'"
        }

        return $group.descriptor
    }

    # Resolve a user's descriptor by UPN
    hidden [string] GetUserDescriptor() {
        $users = $this.CallGraphApi("GET", "/users?api-version=$($this.apiVersion)", $null)

        if ($null -eq $users -or $null -eq $users.value) {
            throw "No users returned from Graph API"
        }

        $user = $users.value | Where-Object { $_.principalName -eq $this.UserPrincipalName }
        if ($null -eq $user) {
            throw "User '$($this.UserPrincipalName)' not found in the organization"
        }

        return $user.descriptor
    }

    # Check if the user is already a member of the target group
    hidden [bool] IsMember([string]$UserDescriptor, [string]$GroupDescriptor) {
        try {
            $encodedUser  = [uri]::EscapeDataString($UserDescriptor)
            $encodedGroup = [uri]::EscapeDataString($GroupDescriptor)
            $this.CallGraphApi("GET", "/memberships/$encodedUser/$($encodedGroup)?api-version=$($this.apiVersion)", $null)
            return $true
        }
        catch {
            return $false
        }
    }

    [bool] Test() {
        try {
            Write-Verbose "Test() - Checking project permission: $($this.UserPrincipalName) -> $($this.PermissionLevel) in $($this.ProjectName)"

            $projectId       = $this.GetProjectId()
            $scopeDescriptor = $this.GetProjectScopeDescriptor($projectId)
            $groupDescriptor = $this.GetGroupDescriptor($scopeDescriptor)
            $userDescriptor  = $this.GetUserDescriptor()
            $isMember        = $this.IsMember($userDescriptor, $groupDescriptor)

            if ($this.Ensure -eq [Ensure]::Present) {
                return $isMember
            }
            else {
                return -not $isMember
            }
        }
        catch {
            Write-Error "Test() - Error: $_"
            return $this.Ensure -eq [Ensure]::Absent
        }
    }

    [void] Set() {
        try {
            Write-Verbose "Set() - Setting project permission: $($this.UserPrincipalName) -> $($this.PermissionLevel) in $($this.ProjectName), Ensure=$($this.Ensure)"

            $projectId       = $this.GetProjectId()
            $scopeDescriptor = $this.GetProjectScopeDescriptor($projectId)
            $groupDescriptor = $this.GetGroupDescriptor($scopeDescriptor)
            $userDescriptor  = $this.GetUserDescriptor()

            $encodedUser  = [uri]::EscapeDataString($userDescriptor)
            $encodedGroup = [uri]::EscapeDataString($groupDescriptor)

            if ($this.Ensure -eq [Ensure]::Present) {
                $this.CallGraphApi("PUT", "/memberships/$encodedUser/$($encodedGroup)?api-version=$($this.apiVersion)", "")
                Write-Verbose "Set() - Added '$($this.UserPrincipalName)' to '$($this.GetGroupDisplayName())' in project '$($this.ProjectName)'"
            }
            else {
                $this.CallGraphApi("DELETE", "/memberships/$encodedUser/$($encodedGroup)?api-version=$($this.apiVersion)", $null)
                Write-Verbose "Set() - Removed '$($this.UserPrincipalName)' from '$($this.GetGroupDisplayName())' in project '$($this.ProjectName)'"
            }
        }
        catch {
            Write-Error "Set() - Error: $_"
            throw
        }
    }

    [ProjectUserPermissionResource] Get() {
        try {
            Write-Verbose "Get() - Retrieving project permission: $($this.UserPrincipalName) -> $($this.PermissionLevel) in $($this.ProjectName)"

            $projectId       = $this.GetProjectId()
            $scopeDescriptor = $this.GetProjectScopeDescriptor($projectId)
            $groupDescriptor = $this.GetGroupDescriptor($scopeDescriptor)
            $userDescriptor  = $this.GetUserDescriptor()
            $isMember        = $this.IsMember($userDescriptor, $groupDescriptor)

            $result = [ProjectUserPermissionResource]::new()
            $result.ProjectName       = $this.ProjectName
            $result.UserPrincipalName = $this.UserPrincipalName
            $result.PermissionLevel   = $this.PermissionLevel
            $result.Organization      = $this.GetOrganizationValue()
            $result.Ensure            = if ($isMember) { [Ensure]::Present } else { [Ensure]::Absent }
            $result.pat               = $this.pat
            $result.apiVersion        = $this.apiVersion
            return $result
        }
        catch {
            Write-Error "Get() - Error: $_"

            $result = [ProjectUserPermissionResource]::new()
            $result.ProjectName       = $this.ProjectName
            $result.UserPrincipalName = $this.UserPrincipalName
            $result.PermissionLevel   = $this.PermissionLevel
            $result.Organization      = $this.GetOrganizationValue()
            $result.Ensure            = [Ensure]::Absent
            $result.pat               = $this.pat
            $result.apiVersion        = $this.apiVersion
            return $result
        }
    }
}

<#
.SYNOPSIS
Manages Azure DevOps project-level security group membership (permissions) for Entra groups.
.DESCRIPTION
Adds or removes an Entra (Azure AD) security group to/from a project-level security group such as
Build Administrators, Contributors, Project Administrators, Project Valid Users,
Readers, or Release Administrators. Uses the Azure DevOps Graph REST API.
.PARAMETER ProjectName
Azure DevOps project name.
.PARAMETER GroupOriginId
The Origin ID (Object ID) of the Entra security group to add or remove from the project group.
.PARAMETER GroupDisplayName
Optional display name of the Entra security group (for reference).
.PARAMETER PermissionLevel
The project-level group to manage: BuildAdministrators, Contributors,
ProjectAdministrators, ProjectValidUsers, Readers, or ReleaseAdministrators.
.PARAMETER Organization
Azure DevOps organization name.
.PARAMETER Ensure
Desired state: Present (add membership) or Absent (remove membership).
.PARAMETER pat
Personal access token used for authentication.
.PARAMETER apiVersion
Azure DevOps REST API version for the Graph endpoints.
#>
[DscResource()]
class ProjectGroupPermissionResource {
    [DscProperty(Key)]
    [string]$ProjectName

    [DscProperty(Key)]
    [string]$GroupOriginId

    [DscProperty()]
    [string]$GroupDisplayName

    [DscProperty(Mandatory)]
    [ProjectPermissionLevel]$PermissionLevel

    [DscProperty(Mandatory)]
    [string]$Organization

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

    # Call the main dev.azure.com REST API
    hidden [object] CallProjectApi([string]$Method, [string]$UriSuffix, [string]$Body) {
        [string]$StringToken = $this.GetTokenValue()
        [string]$OrgName = $this.GetOrganizationValue()

        if ([string]::IsNullOrWhiteSpace($StringToken)) { throw "Token is null or empty" }
        if ([string]::IsNullOrWhiteSpace($OrgName)) { throw "Organization is null or empty" }

        $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$StringToken"))
        $Uri = "https://dev.azure.com/$OrgName/_apis" + $UriSuffix
        $Headers = @{
            Authorization  = "Basic $Base64AuthInfo"
            "Content-Type" = "application/json"
        }

        $Params = @{
            Uri         = $Uri
            Method      = $Method
            Headers     = $Headers
            ErrorAction = "Stop"
        }
        if ($Body) { $Params.Body = $Body }

        try {
            return Invoke-RestMethod @Params
        }
        catch {
            Write-Error "ProjectGroupPermissionResource.CallProjectApi error: $_"
            throw
        }
    }

    # Call the vssps.dev.azure.com Graph REST API
    hidden [object] CallGraphApi([string]$Method, [string]$UriSuffix, [string]$Body) {
        [string]$StringToken = $this.GetTokenValue()
        [string]$OrgName = $this.GetOrganizationValue()

        if ([string]::IsNullOrWhiteSpace($StringToken)) { throw "Token is null or empty" }
        if ([string]::IsNullOrWhiteSpace($OrgName)) { throw "Organization is null or empty" }

        $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$StringToken"))
        $Uri = "https://vssps.dev.azure.com/$OrgName/_apis/graph" + $UriSuffix
        $Headers = @{
            Authorization  = "Basic $Base64AuthInfo"
            "Content-Type" = "application/json"
        }

        $Params = @{
            Uri         = $Uri
            Method      = $Method
            Headers     = $Headers
            ErrorAction = "Stop"
        }
        if ($Body) { $Params.Body = $Body }

        try {
            return Invoke-RestMethod @Params
        }
        catch {
            Write-Error "ProjectGroupPermissionResource.CallGraphApi error: $_"
            throw
        }
    }

    # Map enum value to the Azure DevOps display name for the project group
    hidden [string] GetGroupDisplayName() {
        $result = switch ($this.PermissionLevel) {
            'BuildAdministrators'   { "Build Administrators" }
            'Contributors'          { "Contributors" }
            'ProjectAdministrators' { "Project Administrators" }
            'ProjectValidUsers'     { "Project Valid Users" }
            'Readers'               { "Readers" }
            'ReleaseAdministrators' { "Release Administrators" }
            default { throw "Unknown PermissionLevel: $($this.PermissionLevel)" }
        }
        return $result
    }

    # Resolve the project ID from its name
    hidden [string] GetProjectId() {
        $EncodedName = [uri]::EscapeDataString($this.ProjectName)
        $project = $this.CallProjectApi("GET", "/projects/$($EncodedName)?api-version=7.1", $null)
        return $project.id
    }

    # Get the scope descriptor for a project (needed for Graph group queries)
    hidden [string] GetProjectScopeDescriptor([string]$ProjectId) {
        $response = $this.CallGraphApi("GET", "/descriptors/$($ProjectId)?api-version=$($this.apiVersion)", $null)
        return $response.value
    }

    # Find the target group descriptor within the project scope
    hidden [string] GetGroupDescriptor([string]$ScopeDescriptor) {
        $targetName = $this.GetGroupDisplayName()
        $groups = $this.CallGraphApi("GET", "/groups?scopeDescriptor=$ScopeDescriptor&api-version=$($this.apiVersion)", $null)

        if ($null -eq $groups -or $null -eq $groups.value) {
            throw "No groups found for project '$($this.ProjectName)'"
        }

        $group = $groups.value | Where-Object { $_.displayName -eq $targetName }
        if ($null -eq $group) {
            throw "Group '$targetName' not found in project '$($this.ProjectName)'"
        }

        return $group.descriptor
    }

    # Resolve Entra security group descriptor by Origin ID, adding it to the org if needed
    hidden [string] GetSourceGroupDescriptor() {
        $groups = $this.CallGraphApi("GET", "/groups?api-version=$($this.apiVersion)", $null)

        if ($null -ne $groups -and $null -ne $groups.value) {
            $sourceGroup = $groups.value | Where-Object { $_.originId -eq $this.GroupOriginId }
            if ($null -ne $sourceGroup) {
                return $sourceGroup.descriptor
            }
        }

        # Group not found in the organization - add it from Entra
        Write-Verbose "GetSourceGroupDescriptor() - Group with Origin ID '$($this.GroupOriginId)' not found. Adding to organization..."
        
        $addGroupPayload = @{
            originId = $this.GroupOriginId
        }
        $jsonPayload = $addGroupPayload | ConvertTo-Json -Depth 10
        
        try {
            $newGroup = $this.CallGraphApi("POST", "/groups?api-version=$($this.apiVersion)", $jsonPayload)
            if ($null -eq $newGroup -or [string]::IsNullOrWhiteSpace($newGroup.descriptor)) {
                throw "Failed to add Entra group with Origin ID '$($this.GroupOriginId)' to the organization."
            }
            Write-Verbose "GetSourceGroupDescriptor() - Successfully added group. Descriptor: $($newGroup.descriptor)"
            return $newGroup.descriptor
        }
        catch {
            throw "Failed to add Entra security group with Origin ID '$($this.GroupOriginId)' to the organization. Error: $_"
        }
    }

    # Check if the source group is already a member of the target project group
    hidden [bool] IsMember([string]$SourceGroupDescriptor, [string]$ProjectGroupDescriptor) {
        try {
            $encodedSourceGroup  = [uri]::EscapeDataString($SourceGroupDescriptor)
            $encodedProjectGroup = [uri]::EscapeDataString($ProjectGroupDescriptor)
            $this.CallGraphApi("GET", "/memberships/$encodedSourceGroup/$($encodedProjectGroup)?api-version=$($this.apiVersion)", $null)
            return $true
        }
        catch {
            return $false
        }
    }

    [bool] Test() {
        try {
            Write-Verbose "Test() - Checking project group permission: $($this.GroupOriginId) -> $($this.PermissionLevel) in $($this.ProjectName)"

            $projectId            = $this.GetProjectId()
            $scopeDescriptor      = $this.GetProjectScopeDescriptor($projectId)
            $projectGroupDesc     = $this.GetGroupDescriptor($scopeDescriptor)
            $sourceGroupDescriptor = $this.GetSourceGroupDescriptor()
            $isMember             = $this.IsMember($sourceGroupDescriptor, $projectGroupDesc)

            if ($this.Ensure -eq [Ensure]::Present) {
                return $isMember
            }
            else {
                return -not $isMember
            }
        }
        catch {
            Write-Error "Test() - Error: $_"
            return $this.Ensure -eq [Ensure]::Absent
        }
    }

    [void] Set() {
        try {
            Write-Verbose "Set() - Setting project group permission: $($this.GroupOriginId) -> $($this.PermissionLevel) in $($this.ProjectName), Ensure=$($this.Ensure)"

            $projectId            = $this.GetProjectId()
            $scopeDescriptor      = $this.GetProjectScopeDescriptor($projectId)
            $projectGroupDesc     = $this.GetGroupDescriptor($scopeDescriptor)
            $sourceGroupDescriptor = $this.GetSourceGroupDescriptor()

            $encodedSourceGroup  = [uri]::EscapeDataString($sourceGroupDescriptor)
            $encodedProjectGroup = [uri]::EscapeDataString($projectGroupDesc)

            if ($this.Ensure -eq [Ensure]::Present) {
                $this.CallGraphApi("PUT", "/memberships/$encodedSourceGroup/$($encodedProjectGroup)?api-version=$($this.apiVersion)", "")
                Write-Verbose "Set() - Added group '$($this.GroupOriginId)' to '$($this.GetGroupDisplayName())' in project '$($this.ProjectName)'"
            }
            else {
                $this.CallGraphApi("DELETE", "/memberships/$encodedSourceGroup/$($encodedProjectGroup)?api-version=$($this.apiVersion)", $null)
                Write-Verbose "Set() - Removed group '$($this.GroupOriginId)' from '$($this.GetGroupDisplayName())' in project '$($this.ProjectName)'"
            }
        }
        catch {
            Write-Error "Set() - Error: $_"
            throw
        }
    }

    [ProjectGroupPermissionResource] Get() {
        try {
            Write-Verbose "Get() - Retrieving project group permission: $($this.GroupOriginId) -> $($this.PermissionLevel) in $($this.ProjectName)"

            $projectId            = $this.GetProjectId()
            $scopeDescriptor      = $this.GetProjectScopeDescriptor($projectId)
            $projectGroupDesc     = $this.GetGroupDescriptor($scopeDescriptor)
            $sourceGroupDescriptor = $this.GetSourceGroupDescriptor()
            $isMember             = $this.IsMember($sourceGroupDescriptor, $projectGroupDesc)

            $result = [ProjectGroupPermissionResource]::new()
            $result.ProjectName      = $this.ProjectName
            $result.GroupOriginId    = $this.GroupOriginId
            $result.GroupDisplayName = $this.GroupDisplayName
            $result.PermissionLevel  = $this.PermissionLevel
            $result.Organization     = $this.GetOrganizationValue()
            $result.Ensure           = if ($isMember) { [Ensure]::Present } else { [Ensure]::Absent }
            $result.pat              = $this.pat
            $result.apiVersion       = $this.apiVersion
            return $result
        }
        catch {
            Write-Error "Get() - Error: $_"

            $result = [ProjectGroupPermissionResource]::new()
            $result.ProjectName      = $this.ProjectName
            $result.GroupOriginId    = $this.GroupOriginId
            $result.GroupDisplayName = $this.GroupDisplayName
            $result.PermissionLevel  = $this.PermissionLevel
            $result.Organization     = $this.GetOrganizationValue()
            $result.Ensure           = [Ensure]::Absent
            $result.pat              = $this.pat
            $result.apiVersion       = $this.apiVersion
            return $result
        }
    }
}

