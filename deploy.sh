#!/bin/bash

###############################################################################
# Deploy Azure AI Search SharePoint Indexing Solution
# This script deploys the required Azure resources using Bicep
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print header
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Azure AI Search SharePoint Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed.${NC}"
    echo "Please install Azure CLI from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

# Check if user is logged in
echo -e "${YELLOW}Checking Azure CLI authentication...${NC}"
az account show &> /dev/null || {
    echo -e "${RED}Not logged in to Azure.${NC}"
    echo "Please run: az login"
    exit 1
}

# Get current subscription
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo -e "${GREEN}✓ Using subscription: ${SUBSCRIPTION_NAME}${NC}"
echo ""

# Prompt for resource group name
read -p "Enter resource group name (press Enter for 'rg-ai-search-sharepoint'): " RESOURCE_GROUP
RESOURCE_GROUP=${RESOURCE_GROUP:-rg-ai-search-sharepoint}

# Prompt for location
read -p "Enter location (press Enter for 'eastus'): " LOCATION
LOCATION=${LOCATION:-eastus}

# Create resource group if it doesn't exist
echo -e "${YELLOW}Creating resource group if it doesn't exist...${NC}"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
echo -e "${GREEN}✓ Resource group ready: ${RESOURCE_GROUP}${NC}"
echo ""

# Deploy Bicep template
echo -e "${YELLOW}Deploying Azure resources (this may take 5-10 minutes)...${NC}"
DEPLOYMENT_NAME="ai-search-sp-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file main.bicep \
    --parameters main.bicepparam \
    --output json > deployment-output.json

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Deployment completed successfully!${NC}"
    echo ""
else
    echo -e "${RED}✗ Deployment failed. Check the error messages above.${NC}"
    exit 1
fi

# Extract outputs
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Deployment Outputs${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

SEARCH_SERVICE_NAME=$(jq -r '.properties.outputs.searchServiceName.value' deployment-output.json)
SEARCH_SERVICE_ENDPOINT=$(jq -r '.properties.outputs.searchServiceEndpoint.value' deployment-output.json)
AOAI_ENDPOINT=$(jq -r '.properties.outputs.azureOpenAIEndpoint.value' deployment-output.json)
EMBEDDING_DEPLOYMENT=$(jq -r '.properties.outputs.embeddingDeploymentName.value' deployment-output.json)

echo -e "${GREEN}Azure AI Search Service:${NC}"
echo "  Name: $SEARCH_SERVICE_NAME"
echo "  Endpoint: $SEARCH_SERVICE_ENDPOINT"
echo ""
echo -e "${GREEN}Azure OpenAI Service:${NC}"
echo "  Endpoint: $AOAI_ENDPOINT"
echo "  Embedding Deployment: $EMBEDDING_DEPLOYMENT"
echo ""

# Update http-client.private.env.json if it exists
if [ -f "http-client.private.env.json" ]; then
    echo -e "${YELLOW}Updating http-client.private.env.json with deployment outputs...${NC}"
    
    # Create backup
    cp http-client.private.env.json http-client.private.env.json.backup
    
    # Update values (requires jq)
    jq --arg searchName "$SEARCH_SERVICE_NAME" \
       --arg aoaiEndpoint "$AOAI_ENDPOINT" \
       --arg embeddingModel "$EMBEDDING_DEPLOYMENT" \
       '.dev.searchServiceName = $searchName |
        .dev.aoaiEndpoint = $aoaiEndpoint |
        .dev.aoaiDeploymentId = $embeddingModel |
        .dev.aoaiModelName = $embeddingModel' \
       http-client.private.env.json > http-client.private.env.json.tmp
    
    mv http-client.private.env.json.tmp http-client.private.env.json
    echo -e "${GREEN}✓ Configuration file updated${NC}"
    echo ""
fi

# Print next steps
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Next Steps${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}1. Configure Microsoft Entra ID App Registration:${NC}"
echo "   - Create a new app registration in the Azure Portal"
echo "   - Grant API permissions: Files.Read.All, Sites.FullControl.All"
echo "   - Create a client secret"
echo "   - See 00-setup-managed-identity.md for detailed instructions"
echo ""
echo -e "${YELLOW}2. Grant SharePoint Access:${NC}"
echo "   - Navigate to your SharePoint site"
echo "   - Grant the Entra app access to the document library"
echo ""
echo -e "${YELLOW}3. Update Configuration:${NC}"
echo "   - Update http-client.private.env.json with:"
echo "     * searchAdminKey (from Azure Portal)"
echo "     * sharepointEndpoint"
echo "     * sharepointLibraryUrl"
echo "     * appId (Entra app client ID)"
echo "     * appSecret (Entra app client secret)"
echo "     * tenantId"
echo ""
echo -e "${YELLOW}4. Run the HTTP requests:${NC}"
echo "   - Execute requests in order: 01-createdatasource.http through 06-test-queries.http"
echo ""
echo -e "${GREEN}Deployment complete! 🎉${NC}"

# Cleanup
rm -f deployment-output.json
