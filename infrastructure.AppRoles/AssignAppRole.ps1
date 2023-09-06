# This doesn't work!
# Either the escaping is wrong or az rest is broken on Windows.
# I get an error that "Write requests (excluding DELETE) must contain the Content-Type header" 
# which is nonsense as az rest is supposed to set that

param(
[Parameter(Mandatory = $true, HelpMessage = "The object ID for the managed identity you want to assign the role to")]
[string]$managedIdentityObjectId,

[Parameter(Mandatory = $true, HelpMessage = "The *object* ID for the Enterprise Application/Service Principal for the back end")]
[string]$backendEnterpriseApplicationObjectId,

[Parameter(Mandatory = $true, HelpMessage = "The GUID for the App Role role you want to assign")]
[string]$roleguid
)


$url = "https://graph.microsoft.com/v1.0/servicePrincipals/$managedIdentityObjectId/appRoleAssignments"
# PowerShell uses ` for escaping because of course it does.
$body = '{`"principalId`": `"$managedIdentityObjectId`", `"resourceId`": `"$backendEnterpriseApplicationObjectId`",`"appRoleId`": `"$roleguid`"}'
az rest -m POST -u $url -b $body