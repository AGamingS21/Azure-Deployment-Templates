# Azure Deployment Templates
This repo contains an example termplate for deploying a .Net Blazor project to an Azure App Service.

This repo contains a basic Blazor Web app, PowerShell to deploy and an Azure Bicep template to create the resources. The blazor app is designed to be basic and to interact with the resources that that PowerShell script produces.

## Requirements

### PowerShell Modules
- Az Module
- PSSodium Module

### Azure
In order to run the Create Web App VsCode Launch setting you will need the following: 
- Azure Account
- Valid Azure Subscription

### Github
In order to push the scripts to github make sure that a personal access token is created with the following permissions:
- Write Secrets to Repository
- Trigger Workflows

## How to Run

### Creating Web App
In order to run this make sure the requirements above are satisfied. Once that is done then in VS Code run the Create Web App Launch Task. If not in vscode then just run the CreateWithBicep.ps1 PowerShell script. Answer any prompts that appear, login and then the powershell script should:
- Create Service Principal with access to subscription
- Create the resource group
- Deploy the Bicep to create the resources
- push client secret from service principal to new key vault
- push Service Principal secrets, web app name and resource group name to Github repo secrets
- Trigger Github Actions workflow to deploy application to Azure

##### Parameters File:
If the file does not exist then there will be a series of prompts that will ask you to enter in information about the web app.

Example of the output of the parameters file:

![Alt text](/documentation/images/paramatersExample.png)


Once that is done then you should be ready to view your web app and create any changes required. If you have changes to the Bicep template run this as many times as needed. The Registered app, key vault secrets and github actions will only run in the registered app does not exists.

### Deleting Web App
If you need to clean up the resources the run the Delete Web App vscode task which will:
- Delete the Registered Application
- Delete the resource group
- Purge the key vault that was deleted

## Todo
Bicep:
- Create Log Analytics and App insights in Bicep
- Add in the name of the production and staging app settings for the storage account in the deployment slots

## Contributing
PRs are always welcome!

## Known Issues
- Remove-AzKeyVault can take about 5-10 mins to complete