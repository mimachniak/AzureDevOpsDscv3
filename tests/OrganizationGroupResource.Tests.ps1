BeforeAll {
    # Import the module using the manifest - this makes the module available
    $modulePath = Join-Path $PSScriptRoot '..' 'module' 'AzureDevOpsDscv3' 'AzureDevOpsDscv3.psd1'
    Import-Module $modulePath -Force
    
    # For PowerShell classes in psm1 files, we need to dot-source the file
    # Using the call operator (.) to execute the script in the current scope
    $psmPath = Join-Path $PSScriptRoot '..' 'module' 'AzureDevOpsDscv3' 'AzureDevOpsDscv3.psm1'
    # Read and execute the content to load the classes into the current scope
    $scriptContent = [System.IO.File]::ReadAllText($psmPath)
    . ([scriptblock]::Create($scriptContent))
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
}
