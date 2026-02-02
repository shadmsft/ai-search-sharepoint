metadata name = 'Azure AI Search SharePoint Indexing Solution'
metadata description = 'Deploys Azure AI Search and Azure OpenAI resources for SharePoint document indexing with integrated vectorization'

targetScope = 'resourceGroup'

// ========== Parameters ==========

@description('The location for all resources.')
param location string = resourceGroup().location

@description('The name of the Azure AI Search service. Must be globally unique.')
@minLength(2)
@maxLength(60)
param searchServiceName string

@description('The pricing tier of the Azure AI Search service. Standard tier or higher is recommended for production workloads.')
@allowed([
  'basic'
  'standard'
  'standard2'
  'standard3'
  'storage_optimized_l1'
  'storage_optimized_l2'
])
param searchServiceSku string = 'standard'

@description('The name of the Azure OpenAI service. Must be globally unique.')
@minLength(2)
@maxLength(64)
param azureOpenAIName string

@description('The location for Azure OpenAI service. May differ from the main location based on model availability.')
param azureOpenAILocation string = location

@description('The name of the embedding model deployment.')
param embeddingModelName string = 'text-embedding-3-large'

@description('The version of the embedding model.')
param embeddingModelVersion string = '1'

@description('The capacity (TPM in thousands) for the embedding model deployment.')
@minValue(1)
@maxValue(1000)
param embeddingDeploymentCapacity int = 10

@description('Optional. Tags for all resources.')
param tags object = {}

@description('Enable system-assigned managed identity for Azure AI Search service.')
param enableManagedIdentity bool = true

// ========== Variables ==========

var cognitiveServicesOpenAIUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd' // Cognitive Services OpenAI User role

// ========== Resources ==========

// Azure AI Search Service
module searchService 'br/public:avm/res/search/search-service:0.12.0' = {
  name: 'searchService-${uniqueString(resourceGroup().id)}'
  params: {
    name: searchServiceName
    location: location
    sku: searchServiceSku
    tags: tags
    
    // Enable system-assigned managed identity
    managedIdentities: enableManagedIdentity ? {
      systemAssigned: true
    } : null
    
    // Network configuration - allow public access (required for SharePoint indexer)
    publicNetworkAccess: 'Enabled'
    
    // Disable local authentication to enforce managed identity usage (optional)
    // authOptions: {
    //   disableLocalAuth: false
    // }
    
    // Semantic search configuration
    semanticSearch: 'standard'
  }
}

// Azure OpenAI Service
module openAIService 'br/public:avm/res/cognitive-services/account:0.14.1' = {
  name: 'openAIService-${uniqueString(resourceGroup().id)}'
  params: {
    name: azureOpenAIName
    location: azureOpenAILocation
    kind: 'OpenAI'
    sku: 'S0'
    tags: tags
    
    // Deployments for embedding model
    deployments: [
      {
        name: embeddingModelName
        model: {
          format: 'OpenAI'
          name: embeddingModelName
          version: embeddingModelVersion
        }
        sku: {
          name: 'Standard'
          capacity: embeddingDeploymentCapacity
        }
      }
    ]
    
    // Network configuration
    publicNetworkAccess: 'Enabled'
    
    // Disable local authentication to enforce managed identity usage
    disableLocalAuth: false
  }
}

// Role assignment: Grant Azure AI Search service access to Azure OpenAI
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableManagedIdentity) {
  name: guid(resourceGroup().id, azureOpenAIName, searchServiceName, cognitiveServicesOpenAIUserRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUserRoleId)
    principalId: searchService.outputs.systemAssignedMIPrincipalId!!
    principalType: 'ServicePrincipal'
  }
}

// ========== Outputs ==========

@description('The name of the Azure AI Search service.')
output searchServiceName string = searchService.outputs.name

@description('The resource ID of the Azure AI Search service.')
output searchServiceResourceId string = searchService.outputs.resourceId

@description('The endpoint URL of the Azure AI Search service.')
output searchServiceEndpoint string = 'https://${searchService.outputs.name}.search.windows.net'

@description('The primary admin key for the Azure AI Search service. Store securely.')
@secure()
output searchServiceAdminKey string = searchService.outputs.primaryKey

@description('The name of the Azure OpenAI service.')
output azureOpenAIName string = openAIService.outputs.name

@description('The resource ID of the Azure OpenAI service.')
output azureOpenAIResourceId string = openAIService.outputs.resourceId

@description('The endpoint URL of the Azure OpenAI service.')
output azureOpenAIEndpoint string = openAIService.outputs.endpoint

@description('The deployment name for the embedding model.')
output embeddingDeploymentName string = embeddingModelName

@description('The system-assigned managed identity principal ID of the Azure AI Search service.')
output searchServicePrincipalId string = enableManagedIdentity ? searchService.outputs.systemAssignedMIPrincipalId!! : ''

@description('The location where resources were deployed.')
output location string = location

@description('The resource group name where resources were deployed.')
output resourceGroupName string = resourceGroup().name
