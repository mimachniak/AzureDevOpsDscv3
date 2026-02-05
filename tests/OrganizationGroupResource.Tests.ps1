using module ../module/AzureDevOpsDscv3/AzureDevOpsDscv3.psd1

BeforeAll {
    # Import the module using the manifest - this makes the module available
    $modulePath = Join-Path $PSScriptRoot '..' 'module' 'AzureDevOpsDscv3' 'AzureDevOpsDscv3.psd1'
    Import-Module $modulePath -Force
}

Describe 'OrganizationGroupResource' {
    Context 'When testing OrganizationGroupResource class' {
        It 'Should have required properties' {
            $resource = [OrganizationGroupResource]::new()
            $resource | Should -Not -BeNullOrEmpty
            $resource.PSObject.Properties.Name | Should -Contain 'GroupOriginId'
            $resource.PSObject.Properties.Name | Should -Contain 'Organization'
            $resource.PSObject.Properties.Name | Should -Contain 'AccessLevel'
            $resource.PSObject.Properties.Name | Should -Contain 'Ensure'
        }

        It 'Should have default AccessLevel as Stakeholder' {
            $resource = [OrganizationGroupResource]::new()
            $resource.AccessLevel | Should -Be 'Stakeholder'
        }

        It 'Should have default Ensure as Present' {
            $resource = [OrganizationGroupResource]::new()
            $resource.Ensure | Should -Be 'Present'
        }

        It 'Should have default apiVersion' {
            $resource = [OrganizationGroupResource]::new()
            $resource.apiVersion | Should -Be '7.1-preview.1'
        }
    }

    Context 'When testing GetTokenValue method' {
        It 'Should return token string when pat is a string' {
            $resource = [OrganizationGroupResource]@{
                GroupOriginId = 'group-123'
                Organization = 'TestOrg'
                pat = 'test-token-123'
            }
            $token = $resource.GetTokenValue()
            $token | Should -Be 'test-token-123'
        }
    }

    Context 'When testing GetAccountLicenseType method' {
        It 'Should return stakeholder for Stakeholder access level' {
            $resource = [OrganizationGroupResource]@{
                GroupOriginId = 'group-123'
                Organization = 'TestOrg'
                pat = 'token'
                AccessLevel = 'Stakeholder'
            }
            $licenseType = $resource.GetAccountLicenseType()
            $licenseType | Should -Be 'stakeholder'
        }

        It 'Should return express for Basic access level' {
            $resource = [OrganizationGroupResource]@{
                GroupOriginId = 'group-123'
                Organization = 'TestOrg'
                pat = 'token'
                AccessLevel = 'Basic'
            }
            $licenseType = $resource.GetAccountLicenseType()
            $licenseType | Should -Be 'express'
        }

        It 'Should return advanced for BasicPlusTestPlans access level' {
            $resource = [OrganizationGroupResource]@{
                GroupOriginId = 'group-123'
                Organization = 'TestOrg'
                pat = 'token'
                AccessLevel = 'BasicPlusTestPlans'
            }
            $licenseType = $resource.GetAccountLicenseType()
            $licenseType | Should -Be 'advanced'
        }
    }

    Context 'When testing resource instantiation with different parameters' {
        It 'Should allow setting GroupOriginId' {
            $resource = [OrganizationGroupResource]@{
                GroupOriginId = 'origin-123'
                Organization = 'MyOrg'
                pat = 'token'
            }
            $resource.GroupOriginId | Should -Be 'origin-123'
        }

        It 'Should allow setting GroupDisplayName' {
            $resource = [OrganizationGroupResource]@{
                GroupOriginId = 'group-123'
                Organization = 'TestOrg'
                pat = 'token'
                GroupDisplayName = 'Test Group'
            }
            $resource.GroupDisplayName | Should -Be 'Test Group'
        }

        It 'Should allow setting AccessLevel to Basic' {
            $resource = [OrganizationGroupResource]@{
                GroupOriginId = 'group-123'
                Organization = 'TestOrg'
                pat = 'token'
                AccessLevel = 'Basic'
            }
            $resource.AccessLevel | Should -Be 'Basic'
        }

        It 'Should allow setting Ensure to Absent' {
            $resource = [OrganizationGroupResource]@{
                GroupOriginId = 'group-123'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Absent'
            }
            $resource.Ensure | Should -Be 'Absent'
        }
    }

    Context 'When testing GetOrganizationValue method' {
        It 'Should return organization string when Organization is a string' {
            $resource = [OrganizationGroupResource]@{
                GroupOriginId = 'group-123'
                Organization = 'TestOrganization'
                pat = 'token'
            }
            $org = $resource.GetOrganizationValue()
            $org | Should -Be 'TestOrganization'
        }
    }

    Context 'When testing OrganizationGroupResource Test/Set/Get methods' {
        It 'Test() should return true when group exists with matching license' {
            Mock Invoke-RestMethod {
                return @{ value = @(
                    @{ id = 'g1'; group = @{ originId = 'group-123' }; licenseRule = @{ accountLicenseType = 'stakeholder' } }
                ) }
            }

            $resource = [OrganizationGroupResource]@{
                GroupOriginId = 'group-123'
                Organization = 'TestOrg'
                pat = 'token'
                AccessLevel = 'Stakeholder'
                Ensure = 'Present'
            }

            $resource.Test() | Should -BeTrue
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Method -eq 'GET' }
        }

        It 'Test() should return true when group missing and Ensure=Absent' {
            Mock Invoke-RestMethod { return @{ value = @() } }

            $resource = [OrganizationGroupResource]@{
                GroupOriginId = 'missing-group'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Absent'
            }

            $resource.Test() | Should -BeTrue
        }

        It 'Set() should create group when missing' {
            Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'GET' } { return @{ value = @() } }
            Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'POST' } { return @{ id = 'g1' } }

            $resource = [OrganizationGroupResource]@{
                GroupOriginId = 'group-123'
                GroupDisplayName = 'Test Group'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Present'
            }

            $resource.Set()
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Method -eq 'POST' }
        }

        It 'Set() should update group when exists' {
            Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'GET' } {
                return @{ value = @(
                    @{ id = 'g1'; group = @{ originId = 'group-123' }; licenseRule = @{ accountLicenseType = 'express' } }
                ) }
            }
            Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'PATCH' } { return $null }

            $resource = [OrganizationGroupResource]@{
                GroupOriginId = 'group-123'
                Organization = 'TestOrg'
                pat = 'token'
                AccessLevel = 'BasicPlusTestPlans'
                Ensure = 'Present'
            }

            $resource.Set()
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Method -eq 'PATCH' }
        }

        It 'Set() should delete group when Ensure=Absent and group exists' {
            Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'GET' } {
                return @{ value = @(
                    @{ id = 'g1'; group = @{ originId = 'group-123' } }
                ) }
            }
            Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'DELETE' } { return $null }

            $resource = [OrganizationGroupResource]@{
                GroupOriginId = 'group-123'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Absent'
            }

            $resource.Set()
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Method -eq 'DELETE' }
        }

        It 'Get() should return Present when group found' {
            Mock Invoke-RestMethod {
                return @{ value = @(
                    @{ id = 'g1'; group = @{ originId = 'group-123'; displayName = 'Test Group' }; licenseRule = @{ accountLicenseType = 'express' } }
                ) }
            }

            $resource = [OrganizationGroupResource]@{
                GroupOriginId = 'group-123'
                Organization = 'TestOrg'
                pat = 'token'
            }

            $result = $resource.Get()
            $result.Ensure | Should -Be 'Present'
            $result.AccessLevel | Should -Be 'Basic'
        }

        It 'Get() should return Absent when group missing' {
            Mock Invoke-RestMethod { return @{ value = @() } }

            $resource = [OrganizationGroupResource]@{
                GroupOriginId = 'missing-group'
                Organization = 'TestOrg'
                pat = 'token'
            }

            $result = $resource.Get()
            $result.Ensure | Should -Be 'Absent'
        }
    }
}
