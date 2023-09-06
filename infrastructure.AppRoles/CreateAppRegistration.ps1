# Parameter help description
param(
[Parameter(Mandatory = $true, HelpMessage = "For example 'https://mywebapp.azurewebsites.net' (no trailing slash)")]
[string]$webSiteUrl,

[Parameter(Mandatory = $true, HelpMessage = "For example 'mywebapp.azurewebsites.net'")]
[string]$appRegistrationNameAndId,

[Parameter(HelpMessage = "Tenant ID. May just save you a lot of time when logging in.")]
[string]$tenantId,

[Parameter(HelpMessage = "The email of the person to set as owner. If not specified, the current user will be used.")]
[string]$ownerEmail
)

if ($tenantId) {
    Connect-AzureAD -Tenant $tenantId 
} else {
    Connect-AzureAD   
}

$identifierUri = "api://$($appRegistrationNameAndId)"
$replyUrl = "$($webSiteUrl)/.auth/login/aad/callback"

# This is the app registration
$appRegistration = New-AzureADApplication `
    -DisplayName $appRegistrationNameAndId `
    -AvailableToOtherTenants $false `
    -IdentifierUris $identifierUri `
    -ReplyUrls $replyUrl 

$appId = $appRegistration.AppId

# This is the Enterprise Application / Service Principal
$servicePrincipal = New-AzureADServicePrincipal `
    -AppId $appId `
    -AppRoleAssignmentRequired $true  # This sets AssignmentRequired to true

# This creates a special App Role
# Liberally inspired by https://jeevanbmanoj.medium.com/programmatic-ways-to-create-app-roles-in-azure-ad-a21fc93c531b
$roleName = 'Api.Access' # You can give this whatever name you like
$appRole = New-Object Microsoft.Open.AzureAD.Model.AppRole
$appRole.AllowedMemberTypes = New-Object System.Collections.Generic.List[string]
$appRole.AllowedMemberTypes.Add(“User”); # You can remove this, if desired
$appRole.AllowedMemberTypes.Add(“Application”);
$appRole.DisplayName = $roleName
$appRole.Id = New-Guid
$appRole.IsEnabled = $true
$appRole.Description = 'API access'
$appRole.Value = $roleName

$roleList = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.AppRole]    
$roleList.Add($appRole)

Set-AzureADApplication -ObjectId $appRegistration.ObjectId -AppRoles $roleList


# Assign owners
if (!$ownerEmail) {
    $ownerEmail = (Get-AzureADCurrentSessionInfo).Account.Id
}
$ownerId = (Get-AzureADUser -Filter "Mail eq '$($ownerEmail)'").ObjectId

Add-AzureADApplicationOwner -ObjectId $appRegistration.ObjectId -RefObjectId $ownerId

Write-Host "Created app registration '$($appRegistration.DisplayName)'"
Write-Host "For Bicep, you will need this:"
Write-Host "backendAuthappRegistrationClientId:  '$($appRegistration.AppId)'"
Write-Host "backendAuthApplicationIDUri: '$identifierUri'. Add this to the 'Allowed Token Audiences' in the app service."
Write-Host "----------------------------"
Write-Host "For assigning the App Role to the front-end, you will need this:"
Write-Host "Enterprise Application Object ID: '$($servicePrincipal.ObjectId)'"
Write-Host "App Role ID: '$($appRole.Id)'"


