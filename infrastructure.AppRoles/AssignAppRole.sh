managedIdentityObjectId=02dd1731-6547-4038-95bb-49e20f58b5a5 #The object ID for the managed identity you want to assign the role to
backendEnterpriseApplicationObjectId=d3033bfd-8965-4d84-9e78-6e9dc861dddf #The *object* ID for the Enterprise Application/Service Principal for the back end
roleguid=1d78caa0-9d19-4da9-83f5-ed765bce4150 #The GUID for the App Role role you want to assign

url=https://graph.microsoft.com/v1.0/servicePrincipals/$managedIdentityObjectId/appRoleAssignments
body="{\"principalId\": \"$managedIdentityObjectId\", \"resourceId\": \"$backendEnterpriseApplicationObjectId\",\"appRoleId\": \"$roleguid\"}"
az rest -m POST -u "$url" -b "$body"