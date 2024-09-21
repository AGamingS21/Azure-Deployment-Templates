Param($Create)

function New-GithubSecret {
    param (
        $secretValue,
        $secretName,
        $owner,
        $repo,
        $token
    )
    # Step 1: Get the Public Key
    $publicKeyUrl = "https://api.github.com/repos/$owner/$repo/actions/secrets/public-key"
    $headers = @{
        "Authorization" = "token $token"
        "Accept" = "application/vnd.github.v3+json"
    }
    $response = Invoke-RestMethod -Uri $publicKeyUrl -Method Get -Headers $headers
    $publicKey = $response.key
    $keyId = $response.key_id
    # Encrypt the secret
    $encryptedSecret = ConvertTo-SodiumEncryptedString -Text $secretValue -PublicKey $publicKey
    # Create Secret
    $createSecretUrl = "https://api.github.com/repos/$owner/$repo/actions/secrets/$secretName"
    $body = @{
        encrypted_value = $encryptedSecret
        key_id = $keyId
    } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri $createSecretUrl -Method Put -Headers $headers -Body $body -ContentType "application/json"   

    Write-Host("Created Github actions secret $secretName")

}

function Deploy-WebApp {
    param (
        $owner,
        $workflowId,
        $branch,
        $repo,
        $token
    )

    # Prepare the API request
    $uri = "https://api.github.com/repos/$owner/$repo/actions/workflows/$workflowId/dispatches"
    $body = @{
        ref = $branch
    } | ConvertTo-Json

    # Make the API call
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers @{
        Authorization = "token $token"
        "Accept" = "application/vnd.github.v3+json"
    } -Body $body

    # Output the response
    $response

    Write-Host("Triggered Github actions workflow $workflowId")

    
}

$parametersFilePath = "./deployment/parameters.json"

# If there is no existing parameters file then create one.
if(!(Test-Path -Path $parametersFilePath))
{
    $parameterValues = @{}
    $parameterValues["ResourceGroupName"] = Read-Host("Resource Group Name")
    $parameterValues["Location"] = Read-Host("Location")
    $parameterValues["KeyVaultName"] = Read-Host("Key Vault Name")
    $parameterValues["RegisteredAppName"] = Read-Host("Registered Application Name")
    $parameterValues["AzureSubscriptionId"] = Read-Host("Azure Subscription Id")
    $parameterValues["ServicePrincipalRoleName"] = Read-Host("Role Name for Service Principal for Subscription")
    $parameterValues["WebAppName"] = Read-Host("Web App Name")
    $parameterValues["storageAccountName"] = Read-Host("Storage Account Name")
    $parameterValues["GithubRepo"] = Read-Host("Github Repo")
    $parameterValues["GithubOwner"] = Read-Host("GithubOwner")
    $parameterValues["GithubPAT"] = Read-Host("Github PAT")

    $json = $parameterValues | ConvertTo-Json

    # Output to a file
    $json | Out-File -FilePath $parametersFilePath
}

# Get Json file into object
$jsonContent = Get-Content -Path $parametersFilePath -Raw
$parameters = $jsonContent | ConvertFrom-Json

# Json Variable Assignments
$ResourceGroupName = $parameters.ResourceGroupName
$Location = $parameters.Location
$keyVaultName = $parameters.KeyVaultName
$registeredAppName = $parameters.RegisteredAppName
$subscription = $parameters.AzureSubscriptionId
$roleName = $parameters.ServicePrincipalRoleName
$webAppName = $parameters.WebAppName
$storageAccountName = $parameters.storageAccountName
$githubOwner = $parameters.GithubOwner
$githubRepo = $parameters.GithubRepo
$token = $parameters.GithubPAT


# Static Variable Assignments
$tenantIdName = "tenantid"
$clientSecretName = "clientsecret"
$clientIdName = "clientid"
$BicepPath = "./deployment/WebApp.bicep"
$secretName = "AZURE_CREDENTIALS"
$workflowId = "deploy.yml"
$branch = "main"
$secretCreated = $false
$startDate = [System.DateTime]::Now
$endDate = $startDate.AddYears(1) # Set expiry to one year from now


Connect-AzAccount -Subscription $subscription
$user = Get-AzADUser
$tenantId = (Get-AzTenant).Id

if($create)
{
    Write-Host("Creating Web App Seleted")

    # Ensure Registered App is created
    $app = Get-AzADApplication -Filter "DisplayName eq '$registeredAppName'"
    if($null -eq $app)
    {
        Write-Host("Creating Registered App $registeredAppName as it does not exist yet")
        # Create a new client secret
        $app = New-AzADApplication -SigninAudience AzureADandPersonalMicrosoftAccount -DisplayName $registeredAppName

        # ApplicationId is AppId of Application object which is different from directory id in Azure AD.
        $secret = Get-AzADApplication -ApplicationId $app.AppId | New-AzADAppCredential -StartDate $startDate -EndDate $endDate

        # Turn Application into service principal
        $servicePrincipal = New-AzADServicePrincipal -ApplicationId $app.AppId

        New-AzRoleAssignment -ObjectId $servicePrincipal.Id -RoleDefinitionName $roleName -Scope "/subscriptions/$subscription"

        $secretCreated = $true
    }
    else
    {
        Write-Host("Registered App $registeredAppName already exists")
    }

    Get-AzResourceGroup -Name $ResourceGroupName -ErrorVariable notPresent -ErrorAction SilentlyContinue | Out-Null

    if ($notPresent)
    {
        Write-Host("Creating Resource Group $ResourceGroupName")
        # Create Resource Group
        New-AzResourceGroup -Name $ResourceGroupName -Location $Location
    }
    else
    {
        Write-Host("Resource Group $ResourceGroupName Already Exists")
    }


    # Create a hashtable for parameters
    $parameters = @{
        "objectId" = $user.Id
        "vaultName" = $keyVaultName
        "webAppName" = $webAppName
        "storageAccountName" = $storageAccountName
    }

    Write-Host("Deploying Bicep template")

    # Apply Bicep Template.
    New-AzResourceGroupDeployment -Name DeployWebApp -ResourceGroupName $ResourceGroupName -TemplateFile $BicepPath -TemplateParameterObject $parameters -Mode Complete -Force 
    Write-Host("Completed Deploying Bicep template")

    if($secretCreated)
    {
        Write-Host("Creating secrets in keyvault for new service principal")
        # Create Secrets for client id tenant id and client secret
        $secureTenantId = ConvertTo-SecureString -String $tenantId -AsPlainText -Force
        Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $tenantIdName -SecretValue $secureTenantId

        $secureClientId = ConvertTo-SecureString -String $app.AppId -AsPlainText -Force
        Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $clientIdName -SecretValue $secureClientId

        $secureSecretValue = ConvertTo-SecureString -String $secret.SecretText -AsPlainText -Force    
        Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $clientSecretName -SecretValue $secureSecretValue
    
        
        $creds = @{
            "clientSecret" = $secret.SecretText
            "subscriptionId" = $subscription
            "tenantId" = $tenantId
            "clientId" = $app.AppId
        } | ConvertTo-Json

        
        # Get Secrets to be used in workflow
        New-GithubSecret -secretValue $creds -secretName $secretName -owner $githubOwner -repo $githubRepo -token $token
        New-GithubSecret -secretValue $webAppName -secretName "WEBAPP_NAME" -owner $githubOwner -repo $githubRepo -token $token
        New-GithubSecret -secretValue $ResourceGroupName -secretName "RESOURCE_GROUP" -owner $githubOwner -repo $githubRepo -token $token

        # Trigger workflow since this should be the first time it is ran.
        Deploy-WebApp -owner $githubOwner -repo $githubRepo -token $token -workflowId $workflowId -branch $branch
        
    }

    Write-Host("Completed Creating $webAppName")

}
else 
{
    Write-Host("Delete Web App Seleted")

    
    Remove-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue -Force | Out-Null
    Write-Host("Deleted resource group $ResourceGroupName")
    Remove-AzADApplication -DisplayName $registeredAppName -ErrorAction SilentlyContinue | Out-Null
    Write-Host("Deleted registered application $registeredAppName")
    Remove-AzKeyVault -VaultName $keyVaultName -InRemovedState -Location $Location -ErrorAction SilentlyContinue -Force | Out-Null
    Write-Host("Purged keyvault $keyVaultName")


    Write-Host("Completed Deleting $webAppName")
}