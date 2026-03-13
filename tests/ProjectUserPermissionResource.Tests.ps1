using module ../module/AzureDevOpsDscv3/AzureDevOpsDscv3.psd1

BeforeAll {
    # Import the module using the manifest - this makes the module available
    $modulePath = Join-Path $PSScriptRoot '..' 'module' 'AzureDevOpsDscv3' 'AzureDevOpsDscv3.psd1'
    Import-Module $modulePath -Force
}

Describe 'ProjectUserPermissionResource' {
    Context 'When testing ProjectUserPermissionResource class' {
        It 'Should have required properties' {
            $resource = [ProjectUserPermissionResource]::new()
            $resource | Should -Not -BeNullOrEmpty
            $resource.PSObject.Properties.Name | Should -Contain 'ProjectName'
            $resource.PSObject.Properties.Name | Should -Contain 'UserPrincipalName'
            $resource.PSObject.Properties.Name | Should -Contain 'PermissionLevel'
            $resource.PSObject.Properties.Name | Should -Contain 'Organization'
            $resource.PSObject.Properties.Name | Should -Contain 'Ensure'
            $resource.PSObject.Properties.Name | Should -Contain 'pat'
        }

        It 'Should have default Ensure as Present' {
            $resource = [ProjectUserPermissionResource]::new()
            $resource.Ensure | Should -Be 'Present'
        }

        It 'Should have default apiVersion' {
            $resource = [ProjectUserPermissionResource]::new()
            $resource.apiVersion | Should -Be '7.1-preview.1'
        }
    }

    Context 'When testing GetTokenValue method' {
        It 'Should return token string when pat is a string' {
            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'TestProject'
                UserPrincipalName = 'user@domain.com'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'test-token-123'
            }
            $token = $resource.GetTokenValue()
            $token | Should -Be 'test-token-123'
        }
    }

    Context 'When testing GetGroupDisplayName method' {
        It 'Should return "Build Administrators" for BuildAdministrators' {
            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'TestProject'
                UserPrincipalName = 'user@domain.com'
                PermissionLevel = 'BuildAdministrators'
                Organization = 'TestOrg'
                pat = 'token'
            }
            $displayName = $resource.GetGroupDisplayName()
            $displayName | Should -Be 'Build Administrators'
        }

        It 'Should return "Contributors" for Contributors' {
            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'TestProject'
                UserPrincipalName = 'user@domain.com'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
            }
            $displayName = $resource.GetGroupDisplayName()
            $displayName | Should -Be 'Contributors'
        }

        It 'Should return "Project Administrators" for ProjectAdministrators' {
            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'TestProject'
                UserPrincipalName = 'user@domain.com'
                PermissionLevel = 'ProjectAdministrators'
                Organization = 'TestOrg'
                pat = 'token'
            }
            $displayName = $resource.GetGroupDisplayName()
            $displayName | Should -Be 'Project Administrators'
        }

        It 'Should return "Project Valid Users" for ProjectValidUsers' {
            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'TestProject'
                UserPrincipalName = 'user@domain.com'
                PermissionLevel = 'ProjectValidUsers'
                Organization = 'TestOrg'
                pat = 'token'
            }
            $displayName = $resource.GetGroupDisplayName()
            $displayName | Should -Be 'Project Valid Users'
        }

        It 'Should return "Readers" for Readers' {
            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'TestProject'
                UserPrincipalName = 'user@domain.com'
                PermissionLevel = 'Readers'
                Organization = 'TestOrg'
                pat = 'token'
            }
            $displayName = $resource.GetGroupDisplayName()
            $displayName | Should -Be 'Readers'
        }

        It 'Should return "Release Administrators" for ReleaseAdministrators' {
            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'TestProject'
                UserPrincipalName = 'user@domain.com'
                PermissionLevel = 'ReleaseAdministrators'
                Organization = 'TestOrg'
                pat = 'token'
            }
            $displayName = $resource.GetGroupDisplayName()
            $displayName | Should -Be 'Release Administrators'
        }
    }

    Context 'When testing resource instantiation with different parameters' {
        It 'Should allow setting ProjectName' {
            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'MyProject'
                UserPrincipalName = 'user@domain.com'
                PermissionLevel = 'Contributors'
                Organization = 'MyOrg'
                pat = 'token'
            }
            $resource.ProjectName | Should -Be 'MyProject'
        }

        It 'Should allow setting UserPrincipalName' {
            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'TestProject'
                UserPrincipalName = 'testuser@contoso.com'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
            }
            $resource.UserPrincipalName | Should -Be 'testuser@contoso.com'
        }

        It 'Should allow setting PermissionLevel to ProjectAdministrators' {
            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'TestProject'
                UserPrincipalName = 'user@domain.com'
                PermissionLevel = 'ProjectAdministrators'
                Organization = 'TestOrg'
                pat = 'token'
            }
            $resource.PermissionLevel | Should -Be 'ProjectAdministrators'
        }

        It 'Should allow setting Ensure to Absent' {
            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'TestProject'
                UserPrincipalName = 'user@domain.com'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Absent'
            }
            $resource.Ensure | Should -Be 'Absent'
        }
    }

    Context 'When testing GetOrganizationValue method' {
        It 'Should return organization string when Organization is a string' {
            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'TestProject'
                UserPrincipalName = 'user@domain.com'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrganization'
                pat = 'token'
            }
            $org = $resource.GetOrganizationValue()
            $org | Should -Be 'TestOrganization'
        }
    }

    Context 'When testing ProjectUserPermissionResource Test/Set/Get methods' {
        BeforeEach {
            # Reset mocks before each test
        }

        It 'Test() should return true when user is member and Ensure=Present' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/projects/' } {
                return @{ id = 'proj-123'; name = 'TestProject' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/descriptors/' } {
                return @{ value = 'scope-descriptor-123' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?scopeDescriptor' } {
                return @{ value = @(
                    @{ displayName = 'Contributors'; descriptor = 'group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/users\?' } {
                return @{ value = @(
                    @{ principalName = 'user@domain.com'; descriptor = 'user-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/memberships/' } {
                return @{ }
            }

            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'TestProject'
                UserPrincipalName = 'user@domain.com'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Present'
            }

            $resource.Test() | Should -BeTrue
        }

        It 'Test() should return true when user is not member and Ensure=Absent' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/projects/' } {
                return @{ id = 'proj-123'; name = 'TestProject' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/descriptors/' } {
                return @{ value = 'scope-descriptor-123' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?scopeDescriptor' } {
                return @{ value = @(
                    @{ displayName = 'Contributors'; descriptor = 'group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/users\?' } {
                return @{ value = @(
                    @{ principalName = 'user@domain.com'; descriptor = 'user-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/memberships/' } {
                throw "Not found"
            }

            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'TestProject'
                UserPrincipalName = 'user@domain.com'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Absent'
            }

            $resource.Test() | Should -BeTrue
        }

        It 'Set() should add user to group when Ensure=Present' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/projects/' } {
                return @{ id = 'proj-123'; name = 'TestProject' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/descriptors/' } {
                return @{ value = 'scope-descriptor-123' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?scopeDescriptor' } {
                return @{ value = @(
                    @{ displayName = 'Contributors'; descriptor = 'group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/users\?' } {
                return @{ value = @(
                    @{ principalName = 'user@domain.com'; descriptor = 'user-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Method -eq 'PUT' -and $Uri -match '/memberships/' } {
                return @{ }
            }

            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'TestProject'
                UserPrincipalName = 'user@domain.com'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Present'
            }

            $resource.Set()
            Should -Invoke Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -Times 1 -ParameterFilter { $Method -eq 'PUT' -and $Uri -match '/memberships/' }
        }

        It 'Set() should remove user from group when Ensure=Absent' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/projects/' } {
                return @{ id = 'proj-123'; name = 'TestProject' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/descriptors/' } {
                return @{ value = 'scope-descriptor-123' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?scopeDescriptor' } {
                return @{ value = @(
                    @{ displayName = 'Contributors'; descriptor = 'group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/users\?' } {
                return @{ value = @(
                    @{ principalName = 'user@domain.com'; descriptor = 'user-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Method -eq 'DELETE' -and $Uri -match '/memberships/' } {
                return $null
            }

            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'TestProject'
                UserPrincipalName = 'user@domain.com'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Absent'
            }

            $resource.Set()
            Should -Invoke Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -Times 1 -ParameterFilter { $Method -eq 'DELETE' -and $Uri -match '/memberships/' }
        }

        It 'Get() should return Present when user is member' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/projects/' } {
                return @{ id = 'proj-123'; name = 'TestProject' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/descriptors/' } {
                return @{ value = 'scope-descriptor-123' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?scopeDescriptor' } {
                return @{ value = @(
                    @{ displayName = 'Contributors'; descriptor = 'group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/users\?' } {
                return @{ value = @(
                    @{ principalName = 'user@domain.com'; descriptor = 'user-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/memberships/' } {
                return @{ }
            }

            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'TestProject'
                UserPrincipalName = 'user@domain.com'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
            }

            $result = $resource.Get()
            $result.Ensure | Should -Be 'Present'
            $result.ProjectName | Should -Be 'TestProject'
            $result.UserPrincipalName | Should -Be 'user@domain.com'
        }

        It 'Get() should return Absent when user is not member' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/projects/' } {
                return @{ id = 'proj-123'; name = 'TestProject' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/descriptors/' } {
                return @{ value = 'scope-descriptor-123' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?scopeDescriptor' } {
                return @{ value = @(
                    @{ displayName = 'Contributors'; descriptor = 'group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/users\?' } {
                return @{ value = @(
                    @{ principalName = 'user@domain.com'; descriptor = 'user-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/memberships/' } {
                throw "Not found"
            }

            $resource = [ProjectUserPermissionResource]@{
                ProjectName = 'TestProject'
                UserPrincipalName = 'user@domain.com'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
            }

            $result = $resource.Get()
            $result.Ensure | Should -Be 'Absent'
        }
    }
}
