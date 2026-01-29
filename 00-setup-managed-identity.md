# Setup Managed Identity Authentication

## Prerequisites

Your configuration now uses **system-assigned managed identity** instead of API keys. This requires setup in Azure.

## Configuration Parameters

Set these variables before running commands (or replace directly in commands):

```bash
# Azure Search Service
SEARCH_SERVICE_NAME="<<search service name>>"
RESOURCE_GROUP="<<resource group name>>"

# Azure OpenAI Service  
AOAI_RESOURCE_NAME="<<azure open ai resource name>>"

# Azure Subscription
SUBSCRIPTION_ID="<<subscription id>>"

# Optional: User-Assigned Identity Name
USER_IDENTITY_NAME="user assigned identity"
```

## Required Ste˙

### 1. Enable Managed Identity on Search Service

```bash
# Enable system-assigned managed identity
az search service update \
  --name $SEARCH_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --identity-type SystemAssigned
```

### 2. Get the Search Service's Managed Identity Object ID

```bash
# Get the principal ID (object ID) and save it to a variable
PRINCIPAL_ID=$(az search service show \
  --name $SEARCH_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --query identity.principalId -o tsv)

echo "Principal ID: $PRINCIPAL_ID"
```

This Principal ID is saved to `$PRINCIPAL_ID` variable for use in the next step.

### 3. Grant RBAC Role on Azure OpenAI

The search service needs **"Cognitive Services OpenAI User"** role on your Azure OpenAI resource.
 (uses $PRINCIPAL_ID from step 2)
az role assignment create \
  --role "Cognitive Services OpenAI User" \
  --assignee-object-id $PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.CognitiveServices/accounts/$AOAI_RESOURCE_NAME
  --assignee-principal-type ServicePrincipal \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.CognitiveServices/accounts/aoaisrpsrchsrp3
```

**Or via Azure Portal:**
1. Go to your Azure OpenAI resource: `aoaisrpsrchsrp3`
2. Click **Access control (IAM)** → **Add role assignment**
3. Select role: **Cognitive Services OpenAI User**
4. Click **Next**
5. Select **Managed Identity** → **Search service** → `aisearchsrp3`
6. Click **Review + assign**

### 4. Verify the Configuration (wait 5-10 minutes for role to propagate):

```bash
# Verify role assignment
az role assignment list \
  --assignee $PRINCIPAL_ID \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.CognitiveServices/accounts/$AOAI_RESOURCE_NAME
```

Then test the skillset by running `02-createskillset.http`http
PUT https://aisearchsrp3.search.windows.net/skillsets/sp-vector-skillset?api-version=2025-11-01-preview
```

## Alternative: User-Assigned Managed Identity

If you need more control, use a user-assigned managed identity:
$USER_IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP
```

### Assign to Search Service

```bash
az search service update \
  --name $SEARCH_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --identity-type UserAssigned \
  --user-assigned-identities /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$USER_IDENTITY_NAME
az search service update \
  --name aisearchsrp3 \
  --resource-group $RESOURCE_GROUP \
  --identity-type UserAssigned \
  --user-assigned-identities /subscriptions/<sub-id>/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/search-aoai-identity
```
USER_PRINCIPAL_ID=$(az identity show \
  --name $USER_IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --query principalId -o tsv)

echo "User-Assigned Principal ID: $USER_PRINCIPAL_ID"

# Grant role
az role assignment create \
  --role "Cognitive Services OpenAI User" \
  --assignee-object-id $USER_PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.CognitiveServices/accounts/$AOAI_RESOURCE_NAME
az role assignment create \
  --role "Cognitive Services OpenAI User" \
  --assignee-object-id $PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --scope /su (`02-createskillset.http`):**
```json
"authIdentity": {
  "@odata.type": "#Microsoft.Azure.Search.DataUserAssignedIdentity",
  "userAssignedIdentity": "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/search-aoai-identity"
}
```

**In index vectorizer (`03-createindex.http`):**
```json
"authIdentity": {
  "@odata.type": "#Microsoft.Azure.Search.DataUserAssignedIdentity",
  "userAssignedIdentity": "/subscriptions/$SUBSCRIPTION_ID
```

**In index vectorizer:**
```json
"authIdentity": {
  "@odata.type": "#Microsoft.Azure.Search.DataUserAssignedIdentity",
  "userAssignedIdentity": "/subscriptions/<sub-id>/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/search-aoai-identity"
}
```

## Troubleshooting
```bash
# Confirm managed identity is enabled
az search service show \
  --name $SEARCH_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --query identity
```
- For user-assigned, verify the resource ID is correct

### Check Role Assignment
```bash
az role assignment list \
  --assignee $PRINCIPAL_ID \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.CognitiveServices/accounts/$AOAI_RESOURCE_NAME
- For user-assigned, verify the resource ID is correct

### Check Role Assignment
```bash
az role assignment list \
  --assignee <principal-id> \
  --scope /subscriptions/<subscription-id>/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.CognitiveServices/accounts/aoaisrpsrchsrp3
```

## Benefits of Managed Identity

✅ **No secrets to rotate** - Azure handles credentials automatically  
✅ **Better security** - Follows zero-trust principles  
✅ **Compliance** - Meets most organizational security policies  
✅ **Audit trail** - All access logged in Azure AD  
✅ **Key Vault not needed** - Simpler architecture
