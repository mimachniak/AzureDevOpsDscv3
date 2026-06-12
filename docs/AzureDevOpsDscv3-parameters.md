# AzureDevOpsDsc v3 - Resource Parameters

This document describes the parameters for each DSC resource included in the AzureDevOpsDsc v3 module.

---

## Table of Contents

- [ProjectResource](#projectresource)
- [OrganizationUserResource](#organizationuserresource)
- [OrganizationGroupResource](#organizationgroupresource)
- [OrganizationUserPermissionResource](#organizationuserpermissionresource)
- [OrganizationGroupPermissionResource](#organizationgrouppermissionresource)
- [ProjectUserPermissionResource](#projectuserpermissionresource)
- [ProjectGroupPermissionResource](#projectgrouppermissionresource)

---

## ProjectResource

Manages Azure DevOps projects for an organization.

### Parameters

| Parameter | Description | Default Value | Required |
|-----------|-------------|---------------|----------|
| `ProjectName` | Azure DevOps project name | None | ✅ Yes |
| `Description` | Optional project description | None | ❌ No |
| `SourceControlType` | Source control type for the project (`Git` or `Tfvc`) | `Git` | ❌ No |
| `Organization` | Azure DevOps organization name | None | ✅ Yes |
| `Ensure` | Desired state: `Present` or `Absent` | None | ✅ Yes |
| `pat` | Personal access token used for authentication | None | ✅ Yes |
| `templateTypeId` | Process template type ID used when creating a project Basic: b8a3a935-7e91-48b8-a94c-606d37c3e9f2, Scrum: 6b724908-ef14-45cf-84f8-768b5384da45           Agile: adcc42ab-9882-485e-a3ed-7678f01f66bc, CMMI: 27450541-8e31-4150-9947-dc59f998fc01  | `adcc42ab-9882-485e-a3ed-7678f01f66bc` | ❌ No |
| `apiVersion` | Azure DevOps REST API version | `7.1-preview.1` | ❌ No |

---

## OrganizationUserResource

Manages Azure DevOps user entitlements for an organization.

### Parameters

| Parameter | Description | Default Value | Required |
|-----------|-------------|---------------|----------|
| `UserPrincipalName` | User principal name (email) to manage entitlements for | None | ✅ Yes |
| `Organization` | Azure DevOps organization name | None | ✅ Yes |
| `AccessLevel` | Access level: `Stakeholder`, `Basic`, or `BasicPlusTestPlans` | `Stakeholder` | ❌ No |
| `Ensure` | Desired state: `Present` or `Absent` | None | ✅ Yes |
| `pat` | Personal access token used for authentication | None | ✅ Yes |
| `apiVersion` | Azure DevOps REST API version | `7.1-preview.1` | ❌ No |

---

## OrganizationGroupResource

Manages Azure DevOps group entitlements for an organization.

### Parameters

| Parameter | Description | Default Value | Required |
|-----------|-------------|---------------|----------|
| `GroupOriginId` | Origin ID of the group in Azure DevOps (Entra ID Group Object ID) | None | ✅ Yes |
| `GroupDisplayName` | Display name for the group | None | ❌ No |
| `Organization` | Azure DevOps organization name | None | ✅ Yes |
| `AccessLevel` | Access level: `Stakeholder`, `Basic`, or `BasicPlusTestPlans` | `Stakeholder` | ❌ No |
| `Ensure` | Desired state: `Present` or `Absent` | None | ✅ Yes |
| `pat` | Personal access token used for authentication | None | ✅ Yes |
| `apiVersion` | Azure DevOps REST API version | `7.1-preview.1` | ❌ No |

---

## OrganizationUserPermissionResource

Manages a user's membership in an organization-level (Project Collection) Azure DevOps security group.

### Parameters

| Parameter | Description | Default Value | Required |
|-----------|-------------|---------------|----------|
| `UserPrincipalName` | User principal name (email) to add or remove | None | ✅ Yes |
| `Organization` | Azure DevOps organization name | None | ✅ Yes |
| `PermissionLevel` | Organization-level group: `ProjectCollectionAdministrators`, `ProjectCollectionBuildAdministrators`, `ProjectCollectionBuildServiceAccounts`, `ProjectCollectionProxyServiceAccounts`, `ProjectCollectionServiceAccounts`, `ProjectCollectionTestServiceAccounts`, `ProjectCollectionValidUsers`, `ProjectScopedUsers`, or `SecurityServiceGroup` | None | ✅ Yes |
| `Ensure` | Desired state: `Present` or `Absent` | `Present` | ❌ No |
| `pat` | Personal access token used for authentication | None | ✅ Yes |
| `apiVersion` | Azure DevOps REST API version | `7.1-preview.1` | ❌ No |

---

## OrganizationGroupPermissionResource

Manages an Entra (Azure AD) security group's membership in an organization-level (Project Collection) Azure DevOps security group. If the Entra group is not yet linked to the organization it is added automatically.

### Parameters

| Parameter | Description | Default Value | Required |
|-----------|-------------|---------------|----------|
| `GroupOriginId` | Origin ID (Object ID) of the Entra security group | None | ✅ Yes |
| `GroupDisplayName` | Display name of the Entra security group (for reference) | None | ❌ No |
| `Organization` | Azure DevOps organization name | None | ✅ Yes |
| `PermissionLevel` | Organization-level group: `ProjectCollectionAdministrators`, `ProjectCollectionBuildAdministrators`, `ProjectCollectionBuildServiceAccounts`, `ProjectCollectionProxyServiceAccounts`, `ProjectCollectionServiceAccounts`, `ProjectCollectionTestServiceAccounts`, `ProjectCollectionValidUsers`, `ProjectScopedUsers`, or `SecurityServiceGroup` | None | ✅ Yes |
| `Ensure` | Desired state: `Present` or `Absent` | `Present` | ❌ No |
| `pat` | Personal access token used for authentication | None | ✅ Yes |
| `apiVersion` | Azure DevOps REST API version | `7.1-preview.1` | ❌ No |

---

## ProjectGroupPermissionResource

Manages Azure DevOps project-level security group membership for an Entra (Azure AD) security group.

### Parameters

| Parameter | Description | Default Value | Required |
|-----------|-------------|---------------|----------|
| `GroupOriginId` | Origin ID of the group in Azure DevOps (Entra ID Group Object ID) | None | ✅ Yes |
| `GroupDisplayName` | Display name for the group | None | ❌ No |
| `Organization` | Azure DevOps organization name | None | ✅ Yes |
| `ProjectName` | Azure DevOps project name. | None | ✅ Yes |
| `PermissionLevel` | The project-level group to manage: `BuildAdministrators`, `Contributors`, `ProjectAdministrators`, `ProjectValidUsers`, `Readers`, or `ReleaseAdministrators`. | None | ✅ Yes  |
| `Ensure` | Desired state: `Present` or `Absent` | None | ✅ Yes |
| `pat` | Personal access token used for authentication | None | ✅ Yes |
| `apiVersion` | Azure DevOps REST API version | `7.1-preview.1` | ❌ No |


## ProjectUserPermissionResource

Manages Azure DevOps project-level security group membership for a user.

### Parameters

| Parameter | Description | Default Value | Required |
|-----------|-------------|---------------|----------|
| `UserPrincipalName` | User principal name (email) to manage entitlements for | None | ✅ Yes |
| `Organization` | Azure DevOps organization name | None | ✅ Yes |
| `ProjectName` | Azure DevOps project name. | None | ✅ Yes |
| `PermissionLevel` | The project-level group to manage: `BuildAdministrators`, `Contributors`, `ProjectAdministrators`, `ProjectValidUsers`, `Readers`, or `ReleaseAdministrators`. | None | ✅ Yes  |
| `Ensure` | Desired state: `Present` or `Absent` | None | ✅ Yes |
| `pat` | Personal access token used for authentication | None | ✅ Yes |
| `apiVersion` | Azure DevOps REST API version | `7.1-preview.1` | ❌ No |


