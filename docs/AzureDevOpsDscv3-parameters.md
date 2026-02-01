# AzureDevOpsDsc v3 - Resource Parameters

This document describes the parameters for each DSC resource included in the AzureDevOpsDsc v3 module.

---

## Table of Contents

- [ProjectResource](#projectresource)
- [OrganizationUserResource](#organizationuserresource)
- [OrganizationGroupResource](#organizationgroupresource)

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
