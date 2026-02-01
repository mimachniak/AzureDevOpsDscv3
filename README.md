# AzureDevOpsDsc v3

This is a refactored version of the **AzureDevOpsDsc** project, originally created by the [DSC Community](https://github.com/dsccommunity/AzureDevOpsDsc). This refactored poroject that support DSC v3.

![PowerShell Gallery](https://img.shields.io/powershellgallery/v/AzureDevOpsDscv3.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-PowerShell%207%2B-lightgrey)
![Downloads](https://img.shields.io/powershellgallery/dt/AzureDevOpsDscv3)


---

## 📘 Table of Contents

- [About This Project](#about-this-project)
- [Parameters documentation](./docs/AzureDevOpsDscv3-parameters.md)
- [Original Project](#original-project)
- [Credits](#credits)
- [License](#license)
- [Getting Started](#getting-started)
- [Prerequisites](#prerequisites)
- [Setup and Example of Configuration](#setup-and-example-of-configuration)
  - [DSC V3 Configuration File](#dsc-v3-configuration-file)
  - [DSC Run and Setup Azure DevOps](#dsc-run-and-setup-azure-devops)
- [Change Log](#change-log)

---

## About This Project

This repository represents a modernized and refactored implementation of the AzureDevOpsDsc module, building upon the foundation established by the DSC Community. The v3 version aims to improve maintainability, performance, and compatibility with current Azure DevOps and PowerShell DSC standards.

## Original Project

The original AzureDevOpsDsc project was developed and maintained by the DSC Community and can be found at:
- **Repository**: [https://github.com/dsccommunity/AzureDevOpsDsc](https://github.com/dsccommunity/AzureDevOpsDsc)

## Credits

Full credit for the original concept and implementation goes to the DSC Community and all contributors to the original AzureDevOpsDsc project.

## License

Please refer to the [LICENSE](LICENSE) file for licensing information.

## Getting started

To get started either:

- Install from the PowerShell Gallery using PowerShellGet by running the
  following command:

```powershell
Install-Module -Name AzureDevOpsDscv3 -Repository PSGallery
```

- Download AzureDevOpsDsc from the [PowerShell Gallery](https://www.powershellgallery.com/packages/AzureDevOpsDscv3)
  and then unzip it to one of your PowerShell modules folders (such as
  `$env:ProgramFiles\WindowsPowerShell\Modules`).

To confirm installation, run the below command and ensure you see the AzureDevOpsDsc
DSC resources available:

```powershell
Get-DscResource -Module AzureDevOpsDscv3
```

## Prerequisites

The minimum Windows Management Framework (PowerShell) version required is 5.0
or higher, which ships with Windows 10 or Windows Server 2016,
but can also be installed on Windows 7 SP1, Windows 8.1, Windows Server 2012,
and Windows Server 2012 R2.  

DSCv3: [DSCv3 Get-Started](https://github.com/PowerShell/DSC/blob/main/docs/get-started/index.md)

## Setup and example of configuration

### DSC V3 configuration file

```yaml

$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
parameters:
  Token:
    type: string
    defaultValue: PAT-Token
resources:
- name: Working with classic DSC resources for ADO v4
  type: Microsoft.Windows/WindowsPowerShell
  properties:
    resources:
    - name: Create ADO project - DSC
      type: AzureDevOpsDscv3/ProjectResource
      properties:
        Organization: ExampleOrganization
        ProjectName: TestDSC
        Description: "Project created via DSC v3 with secure parameters"
        pat: "[parameters('Token')]"
        SourceControlType: Git
        Ensure: Present
    - name: AddUser
      type: AzureDevOpsDscv3/OrganizationUserResource
      properties:
        UserPrincipalName: UserPrincipalName
        Organization: ExampleOrganization
        AccessLevel: Basic  # or Stakeholder, BasicPlusTestPlans
        Ensure: Present
        pat: "[parameters('Token')]"
    - name: AddGroup
      type: AzureDevOpsDscv3/OrganizationGroupResource
      properties:
        GroupOriginId: EntraID-GroupObjectID   # group descriptor
        GroupDisplayName: EntraID-GroupDisplayName
        Organization: ExampleOrganization
        AccessLevel: Basic
        Ensure: Present
        pat: "[parameters('Token')]"


```

### DSC run and setup Azure DevOps

```powershell 

#(Note: If you are on a 32-bit system, use .x86 instead).
winget install Microsoft.VCRedist.2015+.x64 

# Install latest stable
winget install --id 9NVTPZWRC6KQ --source msstore

```

```bash

dsc --version

dsc -l debug config set --file .\dsc_resources_ado.dsc.yaml    

```

## Change log

A full list of changes in each version can be found in the [change log](https://github.com/mimachniak/AzureDevOpsDscv3/blob/main/CHANGELOG.md).
