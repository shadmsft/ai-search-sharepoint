# Azure AI Search - SharePoint Indexing with Vectorization

## Solution Overview
This solution indexes SharePoint Online documents (Word docs and scanned PDFs) with Azure AI Search and Azure OpenAI vectorization, including a custom DepartmentName lookup column.

## Key Features Implemented

### 1. **OCR for Scanned PDFs** ✅
- Added `OcrSkill` to extract text from scanned PDFs without embedded OCR
- Configured `imageAction: generateNormalizedImages` in indexer parameters
- Merges OCR text with native content using `MergeSkill`

### 2. **DepartmentName Lookup Column** ✅
- Included in data source via `additionalColumns=DepartmentName` parameter
- Mapped as a searchable, filterable, sortable, and facetable field
- Field mapping configured in indexer to pass through from SharePoint

### 3. **Vectorization with Azure OpenAI** ✅
- Text chunked into 2000-character pages with 200-character overlap
- Each chunk embedded using Azure OpenAI `text-embedding-3-large` (3072 dimensions)
- Hybrid search enabled (keyword + vector) with integrated vectorizer

## Pipeline Architecture

```
SharePoint Docs → Data Source
       ↓
[OCR Skill] → Extract text from scanned PDFs
       ↓
[Merge Skill] → Combine OCR + native content
       ↓
[Split Skill] → Chunk into 2000-char pages
       ↓
[Embedding Skill] → Generate vectors (3072-dim)
       ↓
Index with DepartmentName field
```

## Execution Steps

Execute the HTTP files in order:

1. **[00-setup-managed-identity.md](00-setup-managed-identity.md))** - Follow these steps to setup the identity and permissions. 
1. **[01-createdatasource.http](01-createdatasource.http)** - Creates SharePoint data source with DepartmentName column
2. **[02-createskillset.http](02-createskillset.http)** - Creates OCR + chunking + embedding skillset
3. **[03-createindex.http](03-createindex.http)** - Creates index with vector field and DepartmentName
4. **[04-createindexer.http](04-createindexer.http)** - Creates and runs the indexer
5. **[05-query-hybrid.http](05-query-hybrid.http)** - Query examples (hybrid search, filtering by department)

## Important Configuration Details

### Data Source
- **Type**: `sharepoint`
- **Container query**: `useQuery` with `additionalColumns=DepartmentName` to include the lookup column
- **Authentication**: Azure AD app with `Files.Read.All` and `Sites.FullControl.All` permissions

### Skillset Skills
1. **OCR Skill**: Extracts text from images/scanned PDFs
2. **Merge Skill**: Combines OCR text with document content
3. **Split Skill**: Creates 2000-char chunks with 200-char overlap
4. **Embedding Skill**: Generates 3072-dimensional vectors per chunk

### Index Schema
- **Key field**: `metadata_spo_site_library_item_id` (base64-encoded)
- **Vector field**: `content_vector` (Collection(Edm.Single), 3072 dimensions)
- **Custom field**: `DepartmentName` (searchable, filterable, sortable, facetable)
- **Vectorizer**: Azure OpenAI integrated vectorizer for query-time encoding

### Indexer Configuration
- **imageAction**: `generateNormalizedImages` - enables OCR processing
- **File types**: `.pdf, .docx` (excluded: `.png, .jpg`)
- **Error handling**: Max 10 failed items, 5 per batch
- **Field mappings**: Maps DepartmentName and base64-encodes the key
- **Output mappings**: Maps chunks and vectors from skillset

## Project Files Explained

### Configuration Files

#### `http-client.private.env.json` - Your Secrets & Settings
**What it is:** Central configuration file storing all your API keys, endpoints, and service names.

**Why it exists:** Keeps secrets in one place instead of hardcoded in every file. This file is gitignored for security.

**What's inside:**
```json
{
  "dev": {
    "searchServiceName": "aisearchsrp3",           // Your Azure AI Search service
    "searchAdminKey": "***",                        // Admin API key
    "sharepointEndpoint": "https://...",           // SharePoint site URL
    "appId": "***",                                 // Entra app ID for SharePoint access
    "appSecret": "***",                             // App secret
    "tenantId": "***",                              // Microsoft Entra tenant ID
    "aoaiEndpoint": "https://...",                 // Azure OpenAI endpoint
    "aoaiDeploymentId": "text-embedding-3-large"   // Embedding model deployment
  }
}
```

**When to edit:** 
- First-time setup
- When switching environments (dev/prod)
- When credentials change

---

#### `.gitignore` - Protects Your Secrets
**What it is:** Tells Git which files to never commit to source control.

**Why it exists:** Prevents accidentally committing API keys and secrets to GitHub.

**What's protected:**
- `http-client.private.env.json` (all your secrets)
- `config.txt` (backup config file)
- Any `*.key` or `*.secret` files

---

#### `00-setup-managed-identity.md` - Security Best Practices
**What it is:** Step-by-step guide for setting up managed identity authentication.

**Why it exists:** Managed identities are more secure than API keys (no secrets to rotate or leak).

**What it covers:**
1. Enable managed identity on Azure AI Search service
2. Grant "Cognitive Services OpenAI User" role
3. Configure for both system-assigned and user-assigned identities
4. Troubleshooting authentication issues

**When to use:** Before running the indexer, especially in production environments.

---

### Resource Creation Files (Run in Order)

#### `01-createdatasource.http` - Connect to SharePoint
**What it does:** Creates a connection from Azure AI Search to your SharePoint document library.

**Key responsibilities:**
- Authenticates to SharePoint using Entra app credentials
- Specifies which SharePoint library to index
- Includes custom columns like `DepartmentName` via `additionalColumns` parameter
- Defines the endpoint and connection string

**What gets created:** A data source named `sp-docs-ds`

**Configuration highlights:**
```json
{
  "type": "sharepoint",
  "container": {
    "query": "includeLibrary=<url>;additionalColumns=DepartmentName"
  }
}
```

**When to run:** 
- First-time setup
- When changing SharePoint library or site
- When adding new SharePoint columns to index

---

#### `02-createskillset.http` - AI Processing Pipeline
**What it does:** Defines the AI skills that process documents before indexing.

**The AI Pipeline:**
```
Document Input
    ↓
[1. OCR Skill]
    Extracts text from scanned PDFs and images
    Output: OCR text from each page/image
    ↓
[2. Merge Skill]
    Combines native text + OCR text
    Output: Complete merged document text
    ↓
[3. Embedding Skill]
    Sends merged text to Azure OpenAI
    Output: 3072-dimensional vector (semantic representation)
```

**Why each skill matters:**
- **OCR Skill**: Without this, scanned PDFs would be blank
- **Merge Skill**: Ensures we don't lose native text when adding OCR
- **Embedding Skill**: Creates vectors for AI-powered similarity search

**What gets created:** A skillset named `sp-vector-skillset`

**When to run:**
- First-time setup
- When changing AI processing (e.g., adjusting OCR settings)
- When switching Azure OpenAI models

---

#### `03-createindex.http` - Define the Search Schema
**What it does:** Creates the search index structure - like creating a database table schema.

**Index Fields Defined:**

| Field Name | Type | Purpose | Searchable? | Filterable? |
|------------|------|---------|-------------|-------------|
| `metadata_spo_site_library_item_id` | String | Unique ID (key) | No | No |
| `title` | String | Document title | Yes | Yes |
| `metadata_spo_item_name` | String | File name | Yes | No |
| `metadata_spo_path` | String | SharePoint URL | No | Yes |
| `content` | String | Full text content | Yes | No |
| `DepartmentName` | String | Custom lookup column | Yes | Yes (sortable, facetable) |
| `content_vector` | Collection(Single) | 3072-D embeddings | Yes (vector search) | No |

**Vector Search Configuration:**
- **Algorithm**: HNSW (Hierarchical Navigable Small World) - fast approximate nearest neighbor search
- **Dimensions**: 3072 (matches Azure OpenAI text-embedding-3-large)
- **Integrated Vectorizer**: Automatically converts query text to vectors at search time

**What gets created:** An index named `sp-vector-index`

**When to run:**
- First-time setup
- When adding/removing fields (requires deleting existing index)
- When changing vector dimensions

**⚠️ Important:** Changing the index schema requires deleting and recreating it, which means re-indexing all documents.

---

#### `04-createindexer.http` - Run the Indexing Pipeline
**What it does:** The indexer is the "engine" that pulls everything together and executes the pipeline.

**What it orchestrates:**
1. **Pulls documents** from SharePoint data source (`sp-docs-ds`)
2. **Processes them** through AI skillset (`sp-vector-skillset`)
3. **Stores results** in search index (`sp-vector-index`)

**Field Mappings:**
```json
"fieldMappings": [
  {
    // Maps SharePoint's unique ID to index (base64 encoded for safety)
    "sourceFieldName": "metadata_spo_site_library_item_id",
    "mappingFunction": { "name": "base64Encode" }
  },
  {
    // Maps SharePoint lookup column to index field
    "sourceFieldName": "DepartmentName",
    "targetFieldName": "DepartmentName"
  }
]
```

**Output Field Mappings:**
```json
"outputFieldMappings": [
  {
    // Maps merged content from skillset to content field
    "sourceFieldName": "/document/merged_content",
    "targetFieldName": "content"
  },
  {
    // Maps generated vectors to vector field
    "sourceFieldName": "/document/content_vector",
    "targetFieldName": "content_vector"
  }
]
```

**Configuration Settings:**
- **Error handling**: Continues indexing even if some documents fail
- **Image processing**: `generateNormalizedImages` enables OCR
- **Batch size**: 10 documents at a time
- **File types**: All supported types (no extension filter for maximum compatibility)

**What gets created:** An indexer named `sp-sharepoint-indexer`

**When to run:**
- First-time setup
- When updating indexer configuration
- After modifying data source, skillset, or index

**How to monitor:**
```http
GET https://{{searchServiceName}}.search.windows.net/indexers/sp-sharepoint-indexer/status
```

---

### Query Files (Use After Indexing)

#### `05-query-hybrid.http` - Production Search Queries
**What it does:** Contains ready-to-use search queries for your application.

**Query Types Included:**

**1. Hybrid Search (Keyword + Vector + Filter)**
```json
{
  "search": "employee benefits",           // Keyword search
  "vectorQueries": [{                      // Vector similarity search
    "text": "employee benefits",
    "fields": "content_vector"
  }],
  "filter": "DepartmentName eq 'HR'"     // Department filter
}
```
- Combines traditional keyword matching with AI semantic understanding
- Filters results by department
- Best for user-facing search experiences

**2. Vector-Only Search**
```json
{
  "vectorQueries": [{
    "text": "what are vacation policies?",
    "fields": "content_vector",
    "k": 10
  }]
}
```
- Pure semantic similarity search
- Finds documents by meaning, not just keywords
- Great for "find similar documents" features

**3. Faceted Search**
```json
{
  "search": "*",
  "facets": ["DepartmentName"]
}
```
- Returns count of documents per department
- Useful for building filter UI in applications

**When to use:** Production application queries, testing search quality

---

#### `06-test-queries.http` - Diagnostic & Troubleshooting Queries
**What it does:** Helps you verify the indexing worked correctly and debug issues.

**Test Sequence:**

**Query 1: View All Documents**
- Shows all indexed documents with their DepartmentName values
- Use to verify documents were indexed

**Query 2: Get Department Facets**
- Lists all unique DepartmentName values
- Shows count of documents per department
- **Critical for debugging:** If all values are `null`, field mapping failed

**Query 3: Filter by Department**
- Tests filtering functionality
- Replace `'YourDepartmentValueHere'` with actual value from Query 2

**Query 4: Find Documents with DepartmentName**
- Returns only documents where DepartmentName is populated
- Helps identify which documents have the field set

**Query 5: Find Documents Missing DepartmentName**
- Returns documents where DepartmentName is `null`
- Useful for data quality checks

**Query 6: Hybrid Search with Filter**
- Tests combination of keyword, vector, and filter
- Validates the complete search pipeline

**Query 7: Content Type + Department Filter**
- Tests multiple filter conditions
- Shows advanced filtering capabilities

**When to use:**
- After first indexing run
- When DepartmentName values aren't appearing
- When filters don't seem to work
- When troubleshooting any search issues

---

## How Everything Connects

```
Configuration (http-client.private.env.json)
    ↓
[1] Data Source (01-createdatasource.http)
    Connects to SharePoint
    ↓
[2] Skillset (02-createskillset.http)
    Defines AI processing: OCR → Merge → Embed
    ↓
[3] Index (03-createindex.http)
    Creates storage schema with fields and vectors
    ↓
[4] Indexer (04-createindexer.http)
    Executes: Data Source → Skillset → Index
    ↓
Indexed Documents Ready for Search!
    ↓
Query with (05 & 06)
    Search, filter, find similar documents
```

---

## Troubleshooting

### Check Indexer Status
```http
GET https://aisearchsrp3.search.windows.net/indexers/sp-sharepoint-indexer/status?api-version=2025-11-01-preview
api-key: {admin-key}
```

### Common Issues

1. **OCR not working**: Ensure `imageAction: generateNormalizedImages` is set in indexer configuration
2. **DepartmentName empty**: Verify the column exists in SharePoint and is included in `additionalColumns`
3. **High latency**: OCR + vectorization is compute-intensive; monitor Azure OpenAI TPM limits
4. **Empty vectors**: Check that `context: /document/chunks/*` is set correctly in embedding skill

## Security Recommendations

⚠️ **IMPORTANT**: The current configuration uses API keys in plain text for demonstration purposes.

### Production Best Practices:
1. **Use Managed Identity** instead of API keys for Azure OpenAI
2. **Store secrets in Azure Key Vault** 
3. **Enable RBAC** on Azure AI Search and Azure OpenAI
4. **Consider ACL ingestion** if you need document-level permissions

Example managed identity configuration:
```json
"authIdentity": {
  "type": "systemAssignedManagedIdentity"
}
```

## Query Examples

### Hybrid Search with Department Filter
```json
{
  "search": "employee benefits",
  "vectorQueries": [{
    "kind": "text",
    "text": "employee benefits",
    "fields": "content_vector",
    "k": 5
  }],
  "filter": "DepartmentName eq 'Human Resources'"
}
```

### Semantic Ranker (Optional)
For even better search quality, consider enabling semantic ranking:
```json
{
  "search": "employee benefits",
  "queryType": "semantic",
  "semanticConfiguration": "default"
}
```

## Next Steps

1. ✅ Test the pipeline with sample documents
2. ✅ Verify DepartmentName values are indexed correctly
3. ⏭️ Set up incremental indexing schedule (currently commented out)
4. ⏭️ Implement managed identity authentication
5. ⏭️ Consider ACL ingestion for document-level security
6. ⏭️ Add monitoring and alerting for indexer failures
7. ⏭️ Optimize chunk size based on your document structure

## References
- [SharePoint indexer documentation](https://learn.microsoft.com/en-us/azure/search/search-how-to-index-sharepoint-online)
- [Integrated vectorization](https://learn.microsoft.com/en-us/azure/search/search-how-to-integrated-vectorization)
- [OCR skill](https://learn.microsoft.com/en-us/azure/search/cognitive-search-skill-ocr)
- [Azure OpenAI embedding skill](https://learn.microsoft.com/en-us/azure/search/cognitive-search-skill-azure-openai-embedding)
