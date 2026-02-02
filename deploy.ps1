#Requires -Version 7.0

<#
.SYNOPSIS
    Deploy Azure AI Search SharePoint Indexing Solution

.DESCRIPTION
    This script deploys the required Azure resources using Bicep

.EXAMPLE
    .\deploy.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Print header
Write-Host "========================================" -ForegroundColor Blue
Write-Host "Azure AI Search SharePoint Deployment" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# Check if Azure CLI is installed
try {
    $null = Get-Command az -ErrorAction Stop
} catch {
    Write-Host "Error: Azure CLI is not installed." -ForegroundColor Red
    Write-Host "Please install Azure CLI from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
}

# Check if user is logged in
Write-Host "Checking Azure CLI authentication..." -ForegroundColor Yellow
try {
    $account = az account show 2>&1 | ConvertFrom-Json
    if (-not $account) {
        throw "Not logged in"
    }
} catch {
    Write-Host "Not logged in to Azure." -ForegroundColor Red
    Write-Host "Please run: az login"
    exit 1
}

# Get current subscription
$subscriptionName = az account show --query name -o tsv
$subscriptionId = az account show --query id -o tsv
Write-Host "✓ Using subscription: $subscriptionName" -ForegroundColor Green
Write-Host ""

# Prompt for resource group name
$resourceGroup = Read-Host "Enter resource group name (press Enter for 'rg-ai-search-sharepoint')"
if ([string]::IsNullOrWhiteSpace($resourceGroup)) {
    $resourceGroup = "rg-ai-search-sharepoint"
}

# Prompt for location
$location = Read-Host "Enter location (press Enter for 'eastus')"
if ([string]::IsNullOrWhiteSpace($location)) {
    $location = "eastus"
}

# Create resource group if it doesn't exist
Write-Host "Creating resource group if it doesn't exist..." -ForegroundColor Yellow
az group create --name $resourceGroup --location $location --output none
Write-Host "✓ Resource group ready: $resourceGroup" -ForegroundColor Green
Write-Host ""

# Deploy Bicep template
Write-Host "Deploying Azure resources (this may take 5-10 minutes)..." -ForegroundColor Yellow
$deploymentName = "ai-search-sp-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

$deploymentOutput = az deployment group create `
    --name $deploymentName `
    --resource-group $resourceGroup `
    --template-file infra/main.bicep `
    --parameters infra/main.bicepparam `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Deployment completed successfully!" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "✗ Deployment failed. Check the error messages above." -ForegroundColor Red
    exit 1
}

# Extract outputs
Write-Host "========================================" -ForegroundColor Blue
Write-Host "Deployment Outputs" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

$searchServiceName = $deploymentOutput.properties.outputs.searchServiceName.value
$searchServiceEndpoint = $deploymentOutput.properties.outputs.searchServiceEndpoint.value
$aoaiEndpoint = $deploymentOutput.properties.outputs.azureOpenAIEndpoint.value
$embeddingDeployment = $deploymentOutput.properties.outputs.embeddingDeploymentName.value

Write-Host "Azure AI Search Service:" -ForegroundColor Green
Write-Host "  Name: $searchServiceName"
Write-Host "  Endpoint: $searchServiceEndpoint"
Write-Host ""
Write-Host "Azure OpenAI Service:" -ForegroundColor Green
Write-Host "  Endpoint: $aoaiEndpoint"
Write-Host "  Embedding Deployment: $embeddingDeployment"
Write-Host ""

# Update http-client.private.env.json if it exists
if (Test-Path "http-client.private.env.json") {
    Write-Host "Updating http-client.private.env.json with deployment outputs..." -ForegroundColor Yellow
    
    # Create backup
    Copy-Item "http-client.private.env.json" "http-client.private.env.json.backup"
    
    # Read and update configuration
    $config = Get-Content "http-client.private.env.json" | ConvertFrom-Json
    $config.dev.searchServiceName = $searchServiceName
    $config.dev.aoaiEndpoint = $aoaiEndpoint
    $config.dev.aoaiDeploymentId = $embeddingDeployment
    $config.dev.aoaiModelName = $embeddingDeployment
    
    $config | ConvertTo-Json -Depth 10 | Set-Content "http-client.private.env.json"
    Write-Host "✓ Configuration file updated" -ForegroundColor Green
    Write-Host ""
}

# Print next steps
Write-Host "========================================" -ForegroundColor Blue
Write-Host "Next Steps" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""
Write-Host "1. Configure Microsoft Entra ID App Registration:" -ForegroundColor Yellow
Write-Host "   - Create a new app registration in the Azure Portal"
Write-Host "   - Grant API permissions: Files.Read.All, Sites.FullControl.All"
Write-Host "   - Create a client secret"
Write-Host "   - See 00-setup-managed-identity.md for detailed instructions"
Write-Host ""
Write-Host "2. Grant SharePoint Access:" -ForegroundColor Yellow
Write-Host "   - Navigate to your SharePoint site"
Write-Host "   - Grant the Entra app access to the document library"
Write-Host ""
Write-Host "3. Update Configuration:" -ForegroundColor Yellow
Write-Host "   - Update http-client.private.env.json with:"
Write-Host "     * searchAdminKey (from Azure Portal)"
Write-Host "     * sharepointEndpoint"
Write-Host "     * sharepointLibraryUrl"
Write-Host "     * appId (Entra app client ID)"
Write-Host "     * appSecret (Entra app client secret)"
Write-Host "     * tenantId"
Write-Host ""
Write-Host "4. Run the HTTP requests:" -ForegroundColor Yellow
Write-Host "   - Execute requests in order: 01-createdatasource.http through 06-test-queries.http"
Write-Host ""
Write-Host "Deployment complete! 🎉" -ForegroundColor Green
