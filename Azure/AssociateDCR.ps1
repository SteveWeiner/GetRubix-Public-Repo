# Config
$tenantId           = "TENANT ID HERE"
$subscriptionId     = "SUBSCRIPTION ID HERE"
$resourceGroup      = "NAME OF RESOURCE GROUP"
$DCRName            = "NAME OF DCR"
$location           = "YOUR LOCATION"
$associationName    = "ASSOCIATION NAME"

# Connect Everything
Connect-AzAccount -Tenant $tenantId
Set-AzContext -SubscriptionId $subscriptionId

# Get auth token
$auth = Get-AzAccessToken -ResourceUrl "https://management.azure.com/"
# Handle both String and SecureString
if ($auth.Token -is [System.Security.SecureString]) {
    $token = ConvertFrom-SecureString $auth.Token -AsPlainText
} else {
    $token = $auth.Token
}
$authHeader = @{
    "Content-Type"  = "application/json"
    "Authorization" = "Bearer $token"
}

# Step 1: Assign Monitored Object Contributor role
$user    = Get-AzADUser -UserPrincipalName (Get-AzContext).Account.Id
$newGuid = (New-Guid).Guid

$roleBody = [ordered]@{
    properties = [ordered]@{
        roleDefinitionId = "/providers/Microsoft.Authorization/roleDefinitions/56be40e24db14ccf93c37e44c597135b"
        principalId = $user.Id
    }
} | ConvertTo-Json

$request = "https://management.azure.com/providers/microsoft.insights/providers/microsoft.authorization/roleassignments/$newGuid`?api-version=2021-04-01-preview"
try {
    Invoke-RestMethod -Uri $request -Headers $authHeader -Method PUT -Body $roleBody | Out-Null
    Write-Host "Role was assigned" -ForegroundColor Green
} catch {
    if ($_.ErrorDetails.Message -match "RoleAssignmentExists") {
        Write-Host "Role already exists, moving on..." -ForegroundColor Yellow
    } else { throw }
}

# Step 2: Create Monitored Object
$moBody = [ordered]@{
    properties = [ordered]@{
        location = $location
    }
} | ConvertTo-Json

$request = "https://management.azure.com/providers/Microsoft.Insights/monitoredObjects/$tenantId`?api-version=2021-09-01-preview"
try {
    $response = Invoke-RestMethod -Uri $request -Headers $authHeader -Method PUT -Body $moBody
    $responseId = $response.id
    Write-Host "Monitored Object created: $responseId" -ForegroundColor Green
}
catch {
    if ($_.ErrorDetails.Message -match "already exists") {
        Write-Host "Monitored Object already exists, fetching id..." -ForegroundColor Yellow
        $response = Invoke-RestMethod -Uri $request -Headers $authHeader -Method GET
        $responseId = $response.id
        Write-Host " ID: $responseId" -ForegroundColor Yellow
    } else { throw }
}

# Step 3: Associate Monitored Object to DCR
$dcrBody = [ordered]@{
    properties = [ordered]@{
        dataCollectionRuleId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionRules/$DCRName"
    }
} | ConvertTo-Json

$request = "https://management.azure.com$responseId/providers/microsoft.insights/datacollectionruleassociations/$associationName`?api-version=2021-09-01-preview"
try {
    Invoke-RestMethod -Uri $request -Headers $authHeader -Method PUT -Body $dcrBody | Out-Null
    Write-Host "DCR associated successfully" -ForegroundColor Green
}
catch {
    throw
}

Write-Host "`nDone. Monitored Object ID: $responseId" -ForegroundColor Cyan