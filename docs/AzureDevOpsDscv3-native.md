# Using Native DSC v3 Resources for Azure DevOps

This guide covers how to copy the native DSC v3 resource files to a working directory, verify that DSC can discover them, and apply a configuration.

## Prerequisites

- [PowerShell 7+](https://github.com/PowerShell/PowerShell/releases) (`pwsh`) on `PATH`
- [DSC v3](https://github.com/PowerShell/DSC/releases) (`dsc`) on `PATH`
- A Personal Access Token (PAT) with the following scopes:
  - **Project and Team** – Read, write & manage
  - **Graph** – Read & manage
  - **Member Entitlement Management** – Read & write

---

## Available Resources

| DSC Type | Folder | Description |
|---|---|---|
| `AzureDevOps/Project` | `dsc-resources/project/` | Create / update / delete an ADO project |
| `AzureDevOps/OrganizationUser` | `dsc-resources/organization-user/` | Manage user entitlement (access level) in an organization |
| `AzureDevOps/OrganizationGroup` | `dsc-resources/organization-group/` | Manage Entra group entitlement (license rule) in an organization |
| `AzureDevOps/OrganizationUserPermission` | `dsc-resources/organization-user-permission/` | Add / remove a user from an organization-level (Project Collection) security group |
| `AzureDevOps/OrganizationGroupPermission` | `dsc-resources/organization-group-permission/` | Add / remove an Entra group from an organization-level (Project Collection) security group |
| `AzureDevOps/ProjectUserPermission` | `dsc-resources/project-user-permission/` | Add / remove a user from a project-level security group |
| `AzureDevOps/ProjectGroupPermission` | `dsc-resources/project-group-permission/` | Add / remove an Entra group from a project-level security group |

---

## Step 1 – Copy Resources to a Working Directory

Each resource folder contains a manifest (`.json`) and a script (`.ps1`). Both files must stay together.

### PowerShell (Windows / Linux / macOS)

```powershell
$src  = "D:\Git\AzureDevOpsDscv3\dsc-resources"
$dest = "C:\dsc-resources\AzureDevOps"

$resources = @(
    "project",
    "organization-user",
    "organization-group",
    "organization-user-permission",
    "organization-group-permission",
    "project-user-permission",
    "project-group-permission"
)

foreach ($r in $resources) {
    $target = Join-Path $dest $r
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Copy-Item -Path (Join-Path $src $r "*") -Destination $target -Recurse
}
```

---

## Step 2 – Set `DSC_RESOURCE_PATH`

DSC discovers resources by scanning directories listed in the `DSC_RESOURCE_PATH` environment variable. Add each resource folder as a separate path entry (semicolon-separated on Windows, colon-separated on Linux/macOS).

### Current session (PowerShell)

```powershell
$base = "C:\dsc-resources\AzureDevOps"

$env:DSC_RESOURCE_PATH = @(
    "$base\project",
    "$base\organization-user",
    "$base\organization-group",
    "$base\organization-user-permission",
    "$base\organization-group-permission",
    "$base\project-user-permission",
    "$base\project-group-permission"
) -join ";"
```

### Persist for the current user (Windows)

```powershell
[System.Environment]::SetEnvironmentVariable(
    "DSC_RESOURCE_PATH",
    $env:DSC_RESOURCE_PATH,
    "User"
)
```

---

## Step 3 – Verify DSC Discovers the Resources

List all discovered resources and filter for the AzureDevOps ones:

```powershell
dsc resource list | Select-String "AzureDevOps"
```

Expected output:

```
AzureDevOps/OrganizationGroup             0.1.0
AzureDevOps/OrganizationGroupPermission   0.1.0
AzureDevOps/OrganizationUser              0.1.0
AzureDevOps/OrganizationUserPermission    0.1.0
AzureDevOps/Project                       0.1.0
AzureDevOps/ProjectGroupPermission        0.1.0
AzureDevOps/ProjectUserPermission         0.1.0
```

If a resource is missing, verify:
1. Both the `.json` manifest and the `.ps1` script are in the same folder.
2. That folder is included in `DSC_RESOURCE_PATH`.
3. `pwsh` is available on `PATH` (the manifest uses `condition: "[not(equals(tryWhich('pwsh'), null()))]"`).

To inspect a single resource manifest:

```powershell
dsc resource get --resource AzureDevOps/Project --input '{}'
```

---

## Step 4 – Create a Parameters File

Sensitive values (PAT, org name) are kept in a separate parameters file and never hardcoded in the configuration.

**`devops.parameters.yaml`**

```yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
parameters:
  Organization:
    value: myorg
  Token:
    value: "<your-PAT>"
  EntraGroupObjectId:
    value: "00000000-0000-0000-0000-000000000000"
  OrgAccessLevel:
    value: Basic
  UserProjectPermissionLevel:
    value: Contributors
  GroupProjectPermissionLevel:
    value: Readers
```

---

## Step 5 – Apply the Configuration

### Check current state (read-only)

```powershell
dsc config get --file devops.example.dsc.config.yaml --parameters-file devops.parameters.yaml
```

### Test whether state matches desired (dry-run)

```powershell
dsc config test --file devops.example.dsc.config.yaml --parameters-file devops.parameters.yaml
```

### Apply desired state

```powershell
dsc config set --file devops.example.dsc.config.yaml --parameters-file devops.parameters.yaml
```

DSC processes resources in dependency order (respecting `dependsOn`). The project is created first, then org entitlements, then project-level permissions.

---

## Reference: `dependsOn` Syntax

DSC v3 requires `dependsOn` to be a **list** using the `resourceId()` function:

```yaml
dependsOn:
  - "[resourceId('AzureDevOps/Project','Create DevOps Project')]"
```

A plain resource name (e.g. `- Create DevOps Project`) is **not** valid and will cause a runtime error.
