# Troubleshooting Guide - SharePoint Indexing with Azure AI Search

## Common Errors and Solutions

### Error: "generalException while processing"

```json
{
    "error": {
        "code": "",
        "message": "Error with data source: Code: generalException\r\nMessage: General exception while processing\r\nClientRequestId: ...\r\n  Please adjust your data source definition in order to proceed."
    }
}
```

This error from the data source typically indicates an issue with the SharePoint connection.

#### Cause 1: SharePoint App Permissions Not Granted ⭐ MOST COMMON

**Symptoms:**
- Data source creation fails with generalException
- Indexer fails immediately

**Check:**
```bash
# Verify in Azure Portal
# Entra ID → App Registrations → Your App (98dc22b3-a57d-40ce-a263-a483a41c1f0b) → API Permissions

Required permissions:
✅ Files.Read.All (Application) - Status: Granted for [tenant]
✅ Sites.FullControl.All (Application) - Status: Granted for [tenant]
```

**Fix:**
1. Go to Azure Portal → Microsoft Entra ID
2. App Registrations → Search for app ID `98dc22b3-a57d-40ce-a263-a483a41c1f0b`
3. Click **API Permissions**
4. Ensure both permissions show "Granted for [your tenant]"
5. If not, click **Grant admin consent for [tenant]**
6. Wait 5-10 minutes for changes to propagate

---

#### Cause 2: Invalid SharePoint Library URL

**Symptoms:**
- Data source creates successfully but indexer fails
- Error mentions invalid site or library

**Check your configuration in `01-createdatasource.http`:**
```json
"query": "includeLibrary=https://mngenvmcap746080.sharepoint.com/Files/Forms/AllItems.aspx"
```

**Common issues:**
- ❌ Missing `/Forms/AllItems.aspx` at the end
- ❌ Wrong site collection URL
- ❌ Typo in library name (case-sensitive)
- ❌ Library doesn't exist or was renamed

**Fix:**
1. Open SharePoint in browser
2. Navigate to the document library
3. Copy the exact URL from the address bar
4. Update `sharepointLibraryUrl` in `http-client.private.env.json`

**Valid URL format:**
```
https://[tenant].sharepoint.com/[SitePath]/[LibraryName]/Forms/AllItems.aspx
```

**Examples:**
```
✅ https://contoso.sharepoint.com/sites/HR/Documents/Forms/AllItems.aspx
✅ https://contoso.sharepoint.com/Shared%20Documents/Forms/AllItems.aspx
❌ https://contoso.sharepoint.com/sites/HR/Documents (missing /Forms/AllItems.aspx)
❌ https://contoso.sharepoint.com/sites/HR (missing library)
```

---

#### Cause 3: App Secret Expired or Invalid

**Symptoms:**
- Authentication fails
- Error: "invalid_client" or "generalException"

**Check:**
```bash
# Azure Portal → Entra ID → App Registrations → Your App → Certificates & secrets
# Look at "Expires" column for your client secret
```

**Fix if expired:**
1. Generate new client secret in Azure Portal
2. Copy the secret VALUE (not the Secret ID)
3. Update `http-client.private.env.json`:
   ```json
   "appSecret": "NEW_SECRET_VALUE_HERE"
   ```
4. Update `01-createdatasource.http` and run it again

---

#### Cause 4: SharePoint Endpoint Format Error

**Symptoms:**
- Data source fails to create
- Connection string validation error

**Check your connection string format:**
```json
"connectionString": "SharePointOnlineEndpoint=https://mngenvmcap746080.sharepoint.com;ApplicationId=98dc22b3-a57d-40ce-a263-a483a41c1f0b;ApplicationSecret=...;TenantId=bb1273f5-1215-439b-904b-aff8b71224bc"
```

**Common mistakes:**
- ❌ Including site path in endpoint: `https://tenant.sharepoint.com/sites/MySite` 
- ✅ Correct: `https://tenant.sharepoint.com`
- ❌ Missing semicolons between parameters
- ❌ Extra spaces in connection string
- ❌ Wrong parameter names (must be exact: SharePointOnlineEndpoint, ApplicationId, ApplicationSecret, TenantId)

---

#### Cause 5: SharePoint Indexer Preview Not Enrolled

**Symptoms:**
- Error: "SharePoint data source not supported"
- Feature not available

**Check:**
- Azure AI Search service must be Basic tier or higher
- Must be enrolled in SharePoint indexer preview
- API version must be `2025-11-01-preview` or later

**Fix:**
1. Verify search service tier:
   ```bash
   az search service show \
     --name aisearchsrp3 \
     --resource-group ai3 \
     --query sku.name
   ```
2. Contact Microsoft support to enroll in preview if needed
3. Ensure using `api-version=2025-11-01-preview` in all requests

---

#### Cause 6: DepartmentName Column Issues

**Symptoms:**
- Data source works without additionalColumns but fails with it
- Column not found error

**Check:**
```json
"query": "includeLibrary=...;additionalColumns=DepartmentName"
```

**Common issues:**
- ❌ Column name typo (case-sensitive)
- ❌ Column doesn't exist in the library
- ❌ Column is in a different list (lookup source)

**Fix:**
1. Verify column exists:
   - Go to SharePoint library
   - Click gear icon → Library settings
   - Check "Columns" section for exact name

2. For lookup columns, try:
   ```json
   "additionalColumns=DepartmentNameLookupValue"
   ```

3. Test without additionalColumns first:
   ```json
   "query": "includeLibrary=https://mngenvmcap746080.sharepoint.com/Files/Forms/AllItems.aspx"
   ```

---

### Error: DepartmentName Always Null in Search Results

**Symptoms:**
- Documents indexed successfully
- DepartmentName field exists but always shows `null`
- Filters don't work

**Diagnostic Query:**
```http
POST https://{{searchServiceName}}.search.windows.net/indexes/sp-vector-index/docs/search?api-version={{searchApiVersion}}
api-key: {{searchAdminKey}}
Content-Type: application/json

{
  "search": "*",
  "facets": ["DepartmentName,count:100"],
  "top": 0
}
```

**If all values are null:**

#### Cause 1: Field Mapping Missing or Incorrect

**Check `04-createindexer.http`:**
```json
"fieldMappings": [
  {
    "sourceFieldName": "DepartmentName",
    "targetFieldName": "DepartmentName"
  }
]
```

**Fix for lookup columns:**
```json
"fieldMappings": [
  {
    "sourceFieldName": "DepartmentNameLookupValue",
    "targetFieldName": "DepartmentName"
  }
]
```

Also update data source:
```json
"query": "includeLibrary=...;additionalColumns=DepartmentNameLookupValue"
```

---

#### Cause 2: Documents Don't Have DepartmentName Set

**Check in SharePoint:**
1. Open a document's properties
2. Verify DepartmentName field has a value
3. If empty, populate it and re-run indexer

---

### Error: Word Documents Not Indexing

**Symptoms:**
- PDFs indexed successfully
- .docx files missing from index
- No errors in indexer status

**Check indexer configuration in `04-createindexer.http`:**

**Problem:**
```json
"configuration": {
  "indexedFileNameExtensions": ".pdf, .docx"  // ❌ Spaces cause issues
}
```

**Fix 1: Remove spaces**
```json
"configuration": {
  "indexedFileNameExtensions": ".pdf,.docx,.doc"
}
```

**Fix 2: Remove filter entirely (recommended)**
```json
"configuration": {
  "dataToExtract": "contentAndMetadata",
  "imageAction": "generateNormalizedImages",
  "failOnUnsupportedContentType": false,
  "failOnUnprocessableDocument": false
}
```

---

### Error: Scanned PDFs Not Being Indexed

**Symptoms:**
- Regular PDFs work fine
- Scanned PDFs appear in index but content is empty
- No searchable text extracted

**Check skillset has OCR:**
```json
{
  "@odata.type": "#Microsoft.Skills.Vision.OcrSkill",
  "name": "#ocr",
  "context": "/document/normalized_images/*"
}
```

**Check indexer has image processing:**
```json
"configuration": {
  "imageAction": "generateNormalizedImages"  // ✅ Required for OCR
}
```

**Fix:**
1. Ensure OCR skill exists in `02-createskillset.http`
2. Ensure `imageAction` is set in `04-createindexer.http`
3. Reset and re-run indexer

---

### Error: Vector Dimension Mismatch

```
There's a mismatch in vector dimensions. The field 'content_vector', with dimension of 'X', expects a length of 'X'. However, the provided vector has a length of 'Y'.
```

**Cause:**
Index dimensions don't match Azure OpenAI model output.

**Model outputs:**
- `text-embedding-3-large` → 3072 dimensions (default)
- `text-embedding-3-small` → 1536 dimensions
- `text-embedding-ada-002` → 1536 dimensions

**Fix in `03-createindex.http`:**
```json
{
  "name": "content_vector",
  "type": "Collection(Edm.Single)",
  "dimensions": 3072  // ✅ Must match model output
}
```

**Important:** Changing dimensions requires deleting and recreating the index:
```http
DELETE https://{{searchServiceName}}.search.windows.net/indexes/sp-vector-index?api-version={{searchApiVersion}}
```

---

### Error: Authentication Failed with Azure OpenAI

```
"error": "Access denied" or "Unauthorized"
```

#### Using Managed Identity

**Check role assignment:**
```bash
# Set variables
SEARCH_SERVICE_NAME="aisearchsrp3"
RESOURCE_GROUP="ai3"
AOAI_RESOURCE_NAME="aoaisrpsrchsrp3"
SUBSCRIPTION_ID="f549d128-3c63-47d6-be7c-6b0d35eb33cd"

# Get search service principal ID
PRINCIPAL_ID=$(az search service show \
  --name $SEARCH_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --query identity.principalId -o tsv)

# Verify role assignment
az role assignment list \
  --assignee $PRINCIPAL_ID \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.CognitiveServices/accounts/$AOAI_RESOURCE_NAME
```

**Fix:**
```bash
# Grant role (if missing)
az role assignment create \
  --role "Cognitive Services OpenAI User" \
  --assignee-object-id $PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.CognitiveServices/accounts/$AOAI_RESOURCE_NAME
```

Wait 5-10 minutes for role propagation.

---

### Error: Search Filters Not Working

**Symptoms:**
- Search returns results
- Filter applied but all documents returned
- No filtering happening

**Check field is filterable in `03-createindex.http`:**
```json
{
  "name": "DepartmentName",
  "type": "Edm.String",
  "filterable": true,  // ✅ Required for filtering
  "searchable": true
}
```

**Check filter syntax:**
```json
// ✅ Correct
"filter": "DepartmentName eq 'Human Resources'"

// ❌ Wrong - missing quotes
"filter": "DepartmentName eq Human Resources"

// ❌ Wrong - case-sensitive
"filter": "DepartmentName eq 'human resources'"  // Won't match 'Human Resources'
```

**Find exact values:**
```http
POST https://{{searchServiceName}}.search.windows.net/indexes/sp-vector-index/docs/search

{
  "search": "*",
  "facets": ["DepartmentName,count:100"]
}
```

Use the **exact** values from facets in your filter.

---

## Diagnostic Commands

### Check Indexer Status
```http
GET https://{{searchServiceName}}.search.windows.net/indexers/sp-sharepoint-indexer/status?api-version={{searchApiVersion}}
api-key: {{searchAdminKey}}
```

Look for:
- `lastResult.status`: Should be "success"
- `lastResult.errors`: Lists specific errors
- `lastResult.itemsProcessed`: Number of documents indexed
- `lastResult.itemsFailed`: Number of failures

### Check Index Statistics
```http
GET https://{{searchServiceName}}.search.windows.net/indexes/sp-vector-index/stats?api-version={{searchApiVersion}}
api-key: {{searchAdminKey}}
```

Shows:
- Document count
- Storage size

### Reset Indexer (Reprocess All Documents)
```http
POST https://{{searchServiceName}}.search.windows.net/indexers/sp-sharepoint-indexer/reset?api-version={{searchApiVersion}}
api-key: {{searchAdminKey}}
```

### Run Indexer Manually
```http
POST https://{{searchServiceName}}.search.windows.net/indexers/sp-sharepoint-indexer/run?api-version={{searchApiVersion}}
api-key: {{searchAdminKey}}
```

### Test Data Source Connection
```http
# Just create the data source - if it succeeds, credentials are valid
PUT https://{{searchServiceName}}.search.windows.net/datasources/sp-docs-ds?api-version={{searchApiVersion}}
api-key: {{searchAdminKey}}
```

---

## Troubleshooting Workflow

```
1. Check indexer status
   ↓
2. Review errors in lastResult.errors
   ↓
3. Check data source connection
   ↓
4. Verify SharePoint app permissions
   ↓
5. Test with minimal configuration
   ↓
6. Add features back one at a time
   ↓
7. Monitor indexer execution
```

---

## Getting More Help

### Enable Detailed Logging
```json
// In indexer configuration
"parameters": {
  "maxFailedItems": -1,  // Continue indexing even with errors
  "configuration": {
    "failOnUnsupportedContentType": false,
    "failOnUnprocessableDocument": false
  }
}
```

### Common Log Locations
- Azure Portal → Search Service → Monitoring → Logs
- Indexer status endpoint (see above)
- Azure OpenAI resource logs

### Support Resources
- [SharePoint Indexer Docs](https://learn.microsoft.com/en-us/azure/search/search-how-to-index-sharepoint-online)
- [Skillset Troubleshooting](https://learn.microsoft.com/en-us/azure/search/cognitive-search-debug-session)
- Azure Support ticket for preview enrollment issues
