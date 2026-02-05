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
}
