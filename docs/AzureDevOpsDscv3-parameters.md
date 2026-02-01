


## Manages Azure DevOps projects for an organization.
.PARAMETER ProjectName  
Azure DevOps project name.  
Default value: **None**
.PARAMETER Description  
Optional project description.  
Default value: **None**
.PARAMETER SourceControlType  
Source control type for the project (Git or Tfvc). 
Default value: **Git** 
.PARAMETER Organization  
Azure DevOps organization name.  
.PARAMETER Ensure  
Desired state: Present or Absent.  
.PARAMETER pat  
Default value: **None**
Personal access token used for authentication.  
.PARAMETER templateTypeId  
Default value: **adcc42ab-9882-485e-a3ed-7678f01f66bc"**
Process template type ID used when creating a project.  
Default value: **None**  
.PARAMETER apiVersion  
Azure DevOps REST API version.  
Default value: **7.1-preview.1**


## Manages Azure DevOps user entitlements for an organization.
.PARAMETER UserPrincipalName  
User principal name (email) to manage entitlements for.  
Default value: **None**
.PARAMETER Organization  
Azure DevOps organization name.  
Default value: **None**
.PARAMETER AccessLevel  
Access level: Stakeholder, Basic, or BasicPlusTestPlans.  
Default value: **Stakeholder**
.PARAMETER Ensure  
Desired state: Present or Absent.  
Default value: **None**  
.PARAMETER pat
Personal access token used for authentication.  
Default value: **None**
.PARAMETER apiVersion  
Azure DevOps REST API version.
Default value: **7.1-preview.1**

## Manages Azure DevOps group entitlements for an organization.
.PARAMETER GroupOriginId  
Origin ID of the group in Azure DevOps.  
Default value: **None**
.PARAMETER GroupDisplayName  
Optional display name for the group.  
Default value: **None**
.PARAMETER Organization  
Azure DevOps organization name.  
Default value: **None**
.PARAMETER AccessLevel  
Access level: Stakeholder, Basic, or BasicPlusTestPlans. 
Default value: **Stakeholder**
.PARAMETER Ensure  
Desired state: Present or Absent. 
Default value: **None** 
.PARAMETER pat  
Personal access token used for authentication.  
Default value: **None**
.PARAMETER apiVersion  
Azure DevOps REST API version.  
Default value: **7.1-preview.1**