using module ../module/AzureDevOpsDscv3/AzureDevOpsDscv3.psd1

BeforeAll {
    # Import the module using the manifest - this makes the module available
    $modulePath = Join-Path $PSScriptRoot '..' 'module' 'AzureDevOpsDscv3' 'AzureDevOpsDscv3.psd1'
    Import-Module $modulePath -Force
}

Describe 'OrganizationUserResource' {
    Context 'When testing OrganizationUserResource class' {
        It 'Should have required properties' {
            $resource = [OrganizationUserResource]::new()
            $resource | Should -Not -BeNullOrEmpty
            $resource.PSObject.Properties.Name | Should -Contain 'UserPrincipalName'
            $resource.PSObject.Properties.Name | Should -Contain 'Organization'
            $resource.PSObject.Properties.Name | Should -Contain 'AccessLevel'
            $resource.PSObject.Properties.Name | Should -Contain 'Ensure'
        }

        It 'Should have default AccessLevel as Stakeholder' {
            $resource = [OrganizationUserResource]::new()
            $resource.AccessLevel | Should -Be 'Stakeholder'
        }

        It 'Should have default Ensure as Present' {
            $resource = [OrganizationUserResource]::new()
            $resource.Ensure | Should -Be 'Present'
        }

        It 'Should have default apiVersion' {
            $resource = [OrganizationUserResource]::new()
            $resource.apiVersion | Should -Be '7.1-preview.1'
        }
    }

    Context 'When testing GetTokenValue method' {
        It 'Should return token string when pat is a string' {
            $resource = [OrganizationUserResource]@{
                UserPrincipalName = 'test@example.com'
                Organization = 'TestOrg'
                pat = 'test-token-123'
            }
            $token = $resource.GetTokenValue()
            $token | Should -Be 'test-token-123'
        }
    }

    Context 'When testing GetAccountLicenseType method' {
        It 'Should return stakeholder for Stakeholder access level' {
            $resource = [OrganizationUserResource]@{
                UserPrincipalName = 'test@example.com'
                Organization = 'TestOrg'
                pat = 'token'
                AccessLevel = 'Stakeholder'
            }
            $licenseType = $resource.GetAccountLicenseType()
            $licenseType | Should -Be 'stakeholder'
        }

        It 'Should return express for Basic access level' {
            $resource = [OrganizationUserResource]@{
                UserPrincipalName = 'test@example.com'
                Organization = 'TestOrg'
                pat = 'token'
                AccessLevel = 'Basic'
            }
            $licenseType = $resource.GetAccountLicenseType()
            $licenseType | Should -Be 'express'
        }

        It 'Should return advanced for BasicPlusTestPlans access level' {
            $resource = [OrganizationUserResource]@{
                UserPrincipalName = 'test@example.com'
                Organization = 'TestOrg'
                pat = 'token'
                AccessLevel = 'BasicPlusTestPlans'
            }
            $licenseType = $resource.GetAccountLicenseType()
            $licenseType | Should -Be 'advanced'
        }
    }

    Context 'When testing resource instantiation with different parameters' {
        It 'Should allow setting UserPrincipalName' {
            $resource = [OrganizationUserResource]@{
                UserPrincipalName = 'user@contoso.com'
                Organization = 'MyOrg'
                pat = 'token'
            }
            $resource.UserPrincipalName | Should -Be 'user@contoso.com'
        }

        It 'Should allow setting AccessLevel to Basic' {
            $resource = [OrganizationUserResource]@{
                UserPrincipalName = 'test@example.com'
                Organization = 'TestOrg'
                pat = 'token'
                AccessLevel = 'Basic'
            }
            $resource.AccessLevel | Should -Be 'Basic'
        }

        It 'Should allow setting Ensure to Absent' {
            $resource = [OrganizationUserResource]@{
                UserPrincipalName = 'test@example.com'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Absent'
            }
            $resource.Ensure | Should -Be 'Absent'
        }
    }

    Context 'When testing GetOrganizationValue method' {
        It 'Should return organization string when Organization is a string' {
            $resource = [OrganizationUserResource]@{
                UserPrincipalName = 'test@example.com'
                Organization = 'TestOrganization'
                pat = 'token'
            }
            $org = $resource.GetOrganizationValue()
            $org | Should -Be 'TestOrganization'
        }
    }

    Context 'When testing OrganizationUserResource Test/Set/Get methods' {
        It 'Test() should return true when user exists with matching license' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 {
                    return @{ value = @(
                        @{ id = 'u1'; user = @{ principalName = 'test@example.com' }; accessLevel = @{ accountLicenseType = 'stakeholder' } }
                    ) }
                }

            $resource = [OrganizationUserResource]@{
                UserPrincipalName = 'test@example.com'
                Organization = 'TestOrg'
                pat = 'token'
                AccessLevel = 'Stakeholder'
                Ensure = 'Present'
            }

            $resource.Test() | Should -BeTrue
            Should -Invoke Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -Times 1 -ParameterFilter { $Method -eq 'GET' }
        }

        It 'Test() should return true when user missing and Ensure=Absent' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 { return @{ value = @() } }

            $resource = [OrganizationUserResource]@{
                UserPrincipalName = 'missing@example.com'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Absent'
            }

            $resource.Test() | Should -BeTrue
        }

        It 'Set() should create user when missing' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Method -eq 'GET' } { return @{ value = @() } }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Method -eq 'POST' } { return @{ id = 'u1' } }

            $resource = [OrganizationUserResource]@{
                UserPrincipalName = 'new@example.com'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Present'
            }

            $resource.Set()
            Should -Invoke Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -Times 1 -ParameterFilter { $Method -eq 'POST' }
        }

        It 'Set() should update user when exists' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Method -eq 'GET' } {
                return @{ value = @(
                    @{ id = 'u1'; user = @{ principalName = 'test@example.com' }; accessLevel = @{ accountLicenseType = 'express' } }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Method -eq 'PATCH' } { return $null }

            $resource = [OrganizationUserResource]@{
                UserPrincipalName = 'test@example.com'
                Organization = 'TestOrg'
                pat = 'token'
                AccessLevel = 'BasicPlusTestPlans'
                Ensure = 'Present'
            }

            $resource.Set()
            Should -Invoke Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -Times 1 -ParameterFilter { $Method -eq 'PATCH' }
        }

        It 'Set() should delete user when Ensure=Absent and user exists' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Method -eq 'GET' } {
                return @{ value = @(
                    @{ id = 'u1'; user = @{ principalName = 'test@example.com' } }
                ) }
            }
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -ParameterFilter { $Method -eq 'DELETE' } { return $null }

            $resource = [OrganizationUserResource]@{
                UserPrincipalName = 'test@example.com'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Absent'
            }

            $resource.Set()
            Should -Invoke Invoke-RestMethod -ModuleName AzureDevOpsDscv3 -Times 1 -ParameterFilter { $Method -eq 'DELETE' }
        }

        It 'Get() should return Present when user found' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 {
                return @{ value = @(
                    @{ id = 'u1'; user = @{ principalName = 'test@example.com' }; accessLevel = @{ accountLicenseType = 'express' } }
                ) }
            }

            $resource = [OrganizationUserResource]@{
                UserPrincipalName = 'test@example.com'
                Organization = 'TestOrg'
                pat = 'token'
            }

            $result = $resource.Get()
            $result.Ensure | Should -Be 'Present'
            $result.AccessLevel | Should -Be 'Basic'
        }

        It 'Get() should return Absent when user missing' {
            Mock Invoke-RestMethod -ModuleName AzureDevOpsDscv3 { return @{ value = @() } }

            $resource = [OrganizationUserResource]@{
                UserPrincipalName = 'missing@example.com'
                Organization = 'TestOrg'
                pat = 'token'
            }

            $result = $resource.Get()
            $result.Ensure | Should -Be 'Absent'
        }
    }
}
