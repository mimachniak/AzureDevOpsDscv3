using module ../module/AzureDevOpsDscv3/AzureDevOpsDscv3.psd1

BeforeAll {
    # Import the module using the manifest - this makes the module available
    $modulePath = Join-Path $PSScriptRoot '..' 'module' 'AzureDevOpsDscv3' 'AzureDevOpsDscv3.psd1'
    Import-Module $modulePath -Force
}

Describe 'ProjectResource' {
    Context 'When testing ProjectResource class' {
        It 'Should have required properties' {
            $resource = [ProjectResource]::new()
            $resource | Should -Not -BeNullOrEmpty
            $resource.PSObject.Properties.Name | Should -Contain 'ProjectName'
            $resource.PSObject.Properties.Name | Should -Contain 'Organization'
            $resource.PSObject.Properties.Name | Should -Contain 'Ensure'
        }

        It 'Should have default SourceControlType as Git' {
            $resource = [ProjectResource]::new()
            $resource.SourceControlType | Should -Be 'Git'
        }

        It 'Should have default Ensure as Present' {
            $resource = [ProjectResource]::new()
            $resource.Ensure | Should -Be 'Present'
        }

        It 'Should have default templateTypeId' {
            $resource = [ProjectResource]::new()
            $resource.templateTypeId | Should -Be 'adcc42ab-9882-485e-a3ed-7678f01f66bc'
        }

        It 'Should have default apiVersion' {
            $resource = [ProjectResource]::new()
            $resource.apiVersion | Should -Be '7.1'
        }
    }

    Context 'When testing GetTokenValue method' {
        It 'Should return token string when pat is a string' {
            $resource = [ProjectResource]@{
                ProjectName = 'TestProject'
                Organization = 'TestOrg'
                pat = 'test-token-123'
            }
            $token = $resource.GetTokenValue()
            $token | Should -Be 'test-token-123'
        }
    }

    Context 'When testing resource instantiation with different parameters' {
        It 'Should allow setting ProjectName' {
            $resource = [ProjectResource]@{
                ProjectName = 'MyProject'
                Organization = 'MyOrg'
                pat = 'token'
            }
            $resource.ProjectName | Should -Be 'MyProject'
        }

        It 'Should allow setting Description' {
            $resource = [ProjectResource]@{
                ProjectName = 'TestProject'
                Organization = 'TestOrg'
                pat = 'token'
                Description = 'Test Description'
            }
            $resource.Description | Should -Be 'Test Description'
        }

        It 'Should allow setting SourceControlType to Tfvc' {
            $resource = [ProjectResource]@{
                ProjectName = 'TestProject'
                Organization = 'TestOrg'
                pat = 'token'
                SourceControlType = 'Tfvc'
            }
            $resource.SourceControlType | Should -Be 'Tfvc'
        }

        It 'Should allow setting Ensure to Absent' {
            $resource = [ProjectResource]@{
                ProjectName = 'TestProject'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Absent'
            }
            $resource.Ensure | Should -Be 'Absent'
        }
    }

    Context 'When testing ProjectResource Test/Set/Get methods' {
        It 'Test() should return true when project exists and Ensure=Present' {
            Mock Invoke-RestMethod {
                return @{
                    name = 'TestProject'
                    description = 'Desc'
                    capabilities = @{ versioncontrol = @{ sourceControlType = 'Git' } }
                }
            }

            $resource = [ProjectResource]@{
                ProjectName = 'TestProject'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Present'
            }

            $resource.Test() | Should -BeTrue
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Method -eq 'GET' }
        }

        It 'Test() should return true when project missing and Ensure=Absent' {
            Mock Invoke-RestMethod { throw 'NotFound' }

            $resource = [ProjectResource]@{
                ProjectName = 'MissingProject'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Absent'
            }

            $resource.Test() | Should -BeTrue
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Method -eq 'GET' }
        }

        It 'Set() should create project when missing' {
            Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'GET' } { throw 'NotFound' }
            Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'POST' } { return @{ id = 'p1' } }

            $resource = [ProjectResource]@{
                ProjectName = 'NewProject'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Present'
            }

            $resource.Set()

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Method -eq 'POST' }
        }

        It 'Set() should delete project when Ensure=Absent and project exists' {
            Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'GET' } {
                return @{ id = 'p1' }
            }
            Mock Invoke-RestMethod -ParameterFilter { $Method -eq 'DELETE' } { return $null }

            $resource = [ProjectResource]@{
                ProjectName = 'OldProject'
                Organization = 'TestOrg'
                pat = 'token'
                Ensure = 'Absent'
            }

            $resource.Set()

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Method -eq 'DELETE' }
        }

        It 'Get() should return Present when project found' {
            Mock Invoke-RestMethod {
                return @{
                    name = 'TestProject'
                    description = 'Desc'
                    capabilities = @{ versioncontrol = @{ sourceControlType = 'Git' } }
                }
            }

            $resource = [ProjectResource]@{
                ProjectName = 'TestProject'
                Organization = 'TestOrg'
                pat = 'token'
            }

            $result = $resource.Get()
            $result.Ensure | Should -Be 'Present'
        }

        It 'Get() should return Absent when project missing' {
            Mock Invoke-RestMethod { throw 'NotFound' }

            $resource = [ProjectResource]@{
                ProjectName = 'MissingProject'
                Organization = 'TestOrg'
                pat = 'token'
            }

            $result = $resource.Get()
            $result.Ensure | Should -Be 'Absent'
        }
    }
}
