# Parameter help description
param(
[Parameter(Mandatory = $true, HelpMessage = "For example 'https://mywebapp.azurewebsites.net' (no trailing slash)")]
[string]$webSiteUrl,

[Parameter(Mandatory = $true, HelpMessage = "For example 'mywebapp.azurewebsites.net'")]
[string]$appRegistrationNameAndId,

[Parameter(HelpMessage = "Tenant ID. May just save you a lot of time when logging in.")]
[string]$tenantId,

[Parameter(HelpMessage = "The email of the person to set as owner. If not specifued, the current user will be used.")]
[string]$ownerEmail
)

if ($tenantId) {
    Connect-AzureAD -Tenant $tenantId 
} else {
    Connect-AzureAD   
}

$identifierUri = "api://$($appRegistrationNameAndId)"
$replyUrl = "$($webSiteUrl)/.auth/login/aad/callback"

$appRegistration = New-AzureADApplication `
    -DisplayName $appRegistrationNameAndId `
    -AvailableToOtherTenants $false `
    -IdentifierUris $identifierUri `
    -ReplyUrls $replyUrl 


# Assign owners
if (!$ownerEmail) {
    $ownerEmail = (Get-AzureADCurrentSessionInfo).Account.Id
}
$ownerId = (Get-AzureADUser -Filter "Mail eq '$($ownerEmail)'").ObjectId

Add-AzureADApplicationOwner -ObjectId $appRegistration.ObjectId -RefObjectId $ownerId

Write-Host "Created app registration '$($appRegistration.DisplayName)' with id '$($appRegistration.AppId)'"
Write-Host "Identifier URI: '$identifierUri'. Add this to the 'Allowed Token Audiences' in the app service."
