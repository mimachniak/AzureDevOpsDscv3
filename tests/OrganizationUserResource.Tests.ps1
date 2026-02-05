BeforeAll {
    # Import the module using the manifest - this makes the module available
    $modulePath = Join-Path $PSScriptRoot '..' 'module' 'AzureDevOpsDscv3' 'AzureDevOpsDscv3.psd1'
    Import-Module $modulePath -Force
    
    # For PowerShell classes in psm1 files, dot-source the file
    # Using the call operator (.) to execute the script in the current scope
    $psmPath = Join-Path $PSScriptRoot '..' 'module' 'AzureDevOpsDscv3' 'AzureDevOpsDscv3.psm1'
    . $psmPath
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
}
