using './main.bicep'

// ========== Required Parameters ==========

// Azure AI Search Configuration
param searchServiceName = 'aisearch-sp-${uniqueString(readEnvironmentVariable('AZURE_SUBSCRIPTION_ID', 'default'))}'
param searchServiceSku = 'standard'

// Azure OpenAI Configuration
param azureOpenAIName = 'aoai-sp-${uniqueString(readEnvironmentVariable('AZURE_SUBSCRIPTION_ID', 'default'))}'
param azureOpenAILocation = 'eastus' // Adjust based on model availability in your region

// Embedding Model Configuration
param embeddingModelName = 'text-embedding-3-large'
param embeddingModelVersion = '1'
param embeddingDeploymentCapacity = 10 // TPM in thousands

// ========== Optional Parameters ==========

// Location for resources (Azure AI Search)
param location = 'eastus'

// Enable managed identity for secure authentication
param enableManagedIdentity = true

// Tags for resource organization
param tags = {
  Environment: 'Development'
  Project: 'AI-Search-SharePoint'
  ManagedBy: 'Bicep'
}
