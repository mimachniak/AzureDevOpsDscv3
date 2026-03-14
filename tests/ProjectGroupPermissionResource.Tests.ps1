using module ../module/AzureDevOpsDscv3/AzureDevOpsDscv3.psd1

BeforeAll {
    # Import the module using the manifest - this makes the module available
    $modulePath = Join-Path $PSScriptRoot '..' 'module' 'AzureDevOpsDscv3' 'AzureDevOpsDscv3.psd1'
    Import-Module $modulePath -Force
}

Describe 'ProjectGroupPermissionResource' {
    Context 'When testing ProjectGroupPermissionResource class' {
        It 'Should have required properties' {
            $resource = [ProjectGroupPermissionResource]::new()
            $resource | Should -Not -BeNullOrEmpty
            $resource.PSObject.Properties.Name | Should -Contain 'ProjectName'
            $resource.PSObject.Properties.Name | Should -Contain 'GroupOriginId'
            $resource.PSObject.Properties.Name | Should -Contain 'GroupDisplayName'
            $resource.PSObject.Properties.Name | Should -Contain 'PermissionLevel'
            $resource.PSObject.Properties.Name | Should -Contain 'Organization'
            $resource.PSObject.Properties.Name | Should -Contain 'Ensure'
            $resource.PSObject.Properties.Name | Should -Contain 'pat'
        }

        It 'Should have default Ensure as Present' {
            $resource = [ProjectGroupPermissionResource]::new()
            $resource.Ensure | Should -Be 'Present'
        }

        It 'Should have default apiVersion' {
            $resource = [ProjectGroupPermissionResource]::new()
            $resource.apiVersion | Should -Be '7.1-preview.1'
        }
    }

    Context 'When testing GetTokenValue method' {
        It 'Should return token string when pat is a string' {
            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'group-origin-123'
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
            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'group-origin-123'
                PermissionLevel = 'BuildAdministrators'
                Organization = 'TestOrg'
                pat = 'token'
            }
            $displayName = $resource.GetGroupDisplayName()
            $displayName | Should -Be 'Build Administrators'
        }

        It 'Should return "Contributors" for Contributors' {
            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'group-origin-123'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
            }
            $displayName = $resource.GetGroupDisplayName()
            $displayName | Should -Be 'Contributors'
        }

        It 'Should return "Project Administrators" for ProjectAdministrators' {
            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'group-origin-123'
                PermissionLevel = 'ProjectAdministrators'
                Organization = 'TestOrg'
                pat = 'token'
            }
            $displayName = $resource.GetGroupDisplayName()
            $displayName | Should -Be 'Project Administrators'
        }

        It 'Should return "Project Valid Users" for ProjectValidUsers' {
            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'group-origin-123'
                PermissionLevel = 'ProjectValidUsers'
                Organization = 'TestOrg'
                pat = 'token'
            }
            $displayName = $resource.GetGroupDisplayName()
            $displayName | Should -Be 'Project Valid Users'
        }

        It 'Should return "Readers" for Readers' {
            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'group-origin-123'
                PermissionLevel = 'Readers'
                Organization = 'TestOrg'
                pat = 'token'
            }
            $displayName = $resource.GetGroupDisplayName()
            $displayName | Should -Be 'Readers'
        }

        It 'Should return "Release Administrators" for ReleaseAdministrators' {
            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'group-origin-123'
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
            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'MyProject'
                GroupOriginId = 'group-origin-123'
                PermissionLevel = 'Contributors'
                Organization = 'MyOrg'
                pat = 'token'
            }
            $resource.ProjectName | Should -Be 'MyProject'
        }

        It 'Should allow setting GroupOriginId' {
            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'abc-123-def-456'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
            }
            $resource.GroupOriginId | Should -Be 'abc-123-def-456'
        }

        It 'Should allow setting GroupDisplayName' {
            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'group-origin-123'
                GroupDisplayName = 'My Entra Group'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
            }
            $resource.GroupDisplayName | Should -Be 'My Entra Group'
        }

        It 'Should allow setting PermissionLevel to ProjectAdministrators' {
            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'group-origin-123'
                PermissionLevel = 'ProjectAdministrators'
                Organization = 'TestOrg'
                pat = 'token'
            }
            $resource.PermissionLevel | Should -Be 'ProjectAdministrators'
        }

        It 'Should allow setting Ensure to Absent' {
            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'group-origin-123'
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
            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'group-origin-123'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrganization'
                pat = 'token'
            }
            $org = $resource.GetOrganizationValue()
            $org | Should -Be 'TestOrganization'
        }
    }

    Context 'When testing ProjectGroupPermissionResource Test/Set/Get methods' {
        BeforeEach {
            # Reset mocks before each test
        }

        It 'Test() should return true when group is member and Ensure=Present' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/projects/' } {
                return @{ id = 'proj-123'; name = 'TestProject' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/descriptors/' } {
                return @{ value = 'scope-descriptor-123' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?scopeDescriptor' } {
                return @{ value = @(
                    @{ displayName = 'Contributors'; descriptor = 'project-group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?api-version' -and $Uri -notmatch 'scopeDescriptor' } {
                return @{ value = @(
                    @{ originId = 'group-origin-123'; descriptor = 'entra-group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/memberships/' -and $Method -eq 'GET' } {
                return @{ }
            }

            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'group-origin-123'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Present'
            }

            $resource.Test() | Should -BeTrue
        }

        It 'Test() should return true when group is not member and Ensure=Absent' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/projects/' } {
                return @{ id = 'proj-123'; name = 'TestProject' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/descriptors/' } {
                return @{ value = 'scope-descriptor-123' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?scopeDescriptor' } {
                return @{ value = @(
                    @{ displayName = 'Contributors'; descriptor = 'project-group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?api-version' -and $Uri -notmatch 'scopeDescriptor' } {
                return @{ value = @(
                    @{ originId = 'group-origin-123'; descriptor = 'entra-group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/memberships/' -and $Method -eq 'GET' } {
                throw "Not found"
            }

            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'group-origin-123'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Absent'
            }

            $resource.Test() | Should -BeTrue
        }

        It 'Set() should add group to project group when Ensure=Present' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/projects/' } {
                return @{ id = 'proj-123'; name = 'TestProject' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/descriptors/' } {
                return @{ value = 'scope-descriptor-123' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?scopeDescriptor' } {
                return @{ value = @(
                    @{ displayName = 'Contributors'; descriptor = 'project-group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?api-version' -and $Uri -notmatch 'scopeDescriptor' } {
                return @{ value = @(
                    @{ originId = 'group-origin-123'; descriptor = 'entra-group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Method -eq 'PUT' -and $Uri -match '/memberships/' } {
                return @{ }
            }

            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'group-origin-123'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Present'
            }

            $resource.Set()
            Should -Invoke Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -Times 1 -ParameterFilter { $Method -eq 'PUT' -and $Uri -match '/memberships/' }
        }

        It 'Set() should remove group from project group when Ensure=Absent' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/projects/' } {
                return @{ id = 'proj-123'; name = 'TestProject' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/descriptors/' } {
                return @{ value = 'scope-descriptor-123' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?scopeDescriptor' } {
                return @{ value = @(
                    @{ displayName = 'Contributors'; descriptor = 'project-group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?api-version' -and $Uri -notmatch 'scopeDescriptor' } {
                return @{ value = @(
                    @{ originId = 'group-origin-123'; descriptor = 'entra-group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Method -eq 'DELETE' -and $Uri -match '/memberships/' } {
                return $null
            }

            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'group-origin-123'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Absent'
            }

            $resource.Set()
            Should -Invoke Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -Times 1 -ParameterFilter { $Method -eq 'DELETE' -and $Uri -match '/memberships/' }
        }

        It 'GetSourceGroupDescriptor() should add group to org when not found' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/projects/' } {
                return @{ id = 'proj-123'; name = 'TestProject' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/descriptors/' } {
                return @{ value = 'scope-descriptor-123' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?scopeDescriptor' } {
                return @{ value = @(
                    @{ displayName = 'Contributors'; descriptor = 'project-group-desc-123' }
                ) }
            }
            # First call returns empty, group not found
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/groups\?api-version' -and $Uri -notmatch 'scopeDescriptor' } {
                return @{ value = @() }
            }
            # POST to add the group
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Method -eq 'POST' -and $Uri -match '/groups\?' } {
                return @{ descriptor = 'new-entra-group-desc-123' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Method -eq 'PUT' -and $Uri -match '/memberships/' } {
                return @{ }
            }

            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'new-group-origin-123'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Present'
            }

            $resource.Set()
            Should -Invoke Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -Times 1 -ParameterFilter { $Method -eq 'POST' -and $Uri -match '/groups\?' }
        }

        It 'Get() should return Present when group is member' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/projects/' } {
                return @{ id = 'proj-123'; name = 'TestProject' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/descriptors/' } {
                return @{ value = 'scope-descriptor-123' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?scopeDescriptor' } {
                return @{ value = @(
                    @{ displayName = 'Contributors'; descriptor = 'project-group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?api-version' -and $Uri -notmatch 'scopeDescriptor' } {
                return @{ value = @(
                    @{ originId = 'group-origin-123'; descriptor = 'entra-group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/memberships/' -and $Method -eq 'GET' } {
                return @{ }
            }

            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'group-origin-123'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
            }

            $result = $resource.Get()
            $result.Ensure | Should -Be 'Present'
            $result.ProjectName | Should -Be 'TestProject'
            $result.GroupOriginId | Should -Be 'group-origin-123'
        }

        It 'Get() should return Absent when group is not member' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/projects/' } {
                return @{ id = 'proj-123'; name = 'TestProject' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/descriptors/' } {
                return @{ value = 'scope-descriptor-123' }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?scopeDescriptor' } {
                return @{ value = @(
                    @{ displayName = 'Contributors'; descriptor = 'project-group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/groups\?api-version' -and $Uri -notmatch 'scopeDescriptor' } {
                return @{ value = @(
                    @{ originId = 'group-origin-123'; descriptor = 'entra-group-desc-123' }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Uri -match '/memberships/' -and $Method -eq 'GET' } {
                throw "Not found"
            }

            $resource = [ProjectGroupPermissionResource]@{
                ProjectName = 'TestProject'
                GroupOriginId = 'group-origin-123'
                PermissionLevel = 'Contributors'
                Organization = 'TestOrg'
                pat = 'token'
            }

            $result = $resource.Get()
            $result.Ensure | Should -Be 'Absent'
        }
    }
}
