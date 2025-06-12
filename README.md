# APIOps - GitOps for Azure API Management

![APIOps Logo](https://azure.github.io/apiops/assets/images/apimops_small_light.png)

APIOps applies the concepts of GitOps and DevOps to API deployment. By using practices from these two methodologies, APIOps enables everyone involved in the lifecycle of API design, development, and deployment with self-service and automated tools to ensure the quality of the specifications and APIs that they're building.

## 🌟 Key Features

- **Infrastructure as Code**: Place Azure API Management infrastructure under version control
- **GitOps Workflow**: Make changes through code reviews and audits rather than direct portal changes
- **Multi-Environment Support**: Seamlessly promote changes across Dev → QA → Prod environments
- **Security First**: Implements least-privilege access principles
- **Automated Quality Gates**: Early feedback for policy changes and API specifications
- **Consistency**: Ensures greater consistency between APIs across teams

## 🎯 Benefits of APIOps

1. **Increased Collaboration**: Enhanced collaboration between developers, platform teams, infrastructure teams, and management stakeholders
2. **Version Control & Audit History**: Complete tracking of all changes with Git history
3. **APIM Backup in Code**: Your entire APIM configuration serves as a backup through code
4. **Standardized Deployments**: Consistent deployment processes across all environments
5. **Governance & Quality**: Improved governance with consistent APIM deployment experiences
6. **Risk Reduction**: Early detection of issues through automated validation and code reviews

## 📋 Table of Contents

- [Basic Concepts](#basic-concepts)
- [Prerequisites](#prerequisites)
- [Supported Scenarios](#supported-scenarios)
- [Project Structure](#project-structure)
- [Core Tools](#core-tools)
- [Configuration](#configuration)
- [Getting Started](#getting-started)
- [Workflows](#workflows)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## 🎯 Basic Concepts

### What is APIOps?

APIOps is designed to facilitate the promotion of changes across different Azure API Management (APIM) instances. It combines:

- **GitOps**: Using Git repositories as the single source of truth for infrastructure and application code
- **DevOps**: Automated pipelines for continuous integration and deployment
- **Infrastructure as Code**: Managing APIM configurations through code rather than manual portal changes

### Core Principles

1. **Version Control Everything**: All APIM artifacts are stored in Git
2. **Automated Deployment**: Changes flow through automated pipelines
3. **Code Reviews**: All changes go through pull request reviews
4. **Environment Promotion**: Consistent deployment across environments
5. **Rollback Capability**: Easy rollback through Git history

## ✅ Prerequisites

Before utilizing the APIOps tool, ensure you have:

### Azure Requirements
- Access to the [Azure Portal](https://portal.azure.com/)
- Active [Azure subscription](https://portal.azure.com/#blade/Microsoft_Azure_Billing/SubscriptionsBlade)
- **Contributor role** in a resource group to deploy API Management instances
- Existing Azure API Management instance(s)

### DevOps Platform Requirements

Choose one of the following:

#### Azure DevOps
- Access to a valid [Azure DevOps](https://dev.azure.com/) organization
- Permissions to create and manage pipelines

#### GitHub
- Access to a valid [GitHub](https://github.com/) organization
- For private repositories: GitHub Enterprise Organization (for environments feature)
- For public repositories: Standard GitHub account

#### GitLab
- Access to GitLab instance (Cloud or Self-hosted)
- Permissions to create CI/CD pipelines

### Local Development
- **PowerShell** (for configuration scripts)
- **Git** client
- **Azure CLI** or **Azure PowerShell**
- **.NET 6.0+** (for custom tool execution)

## 🎭 Supported Scenarios

APIOps supports two main development scenarios:

### Scenario A: Portal-First Development

**Workflow:**
1. Developers make changes in Azure Portal/API Management portal
2. Manually run the **Extractor** pipeline to pull changes into Git
3. Automated PR creation with extracted artifacts
4. Code review and approval process
5. Merge triggers **Publisher** pipeline
6. Automated deployment to target environments

**Best For:**
- Teams familiar with Azure Portal
- Legacy API management processes
- Quick prototyping and testing

### Scenario B: Code-First Development

**Workflow:**
1. Developers create/modify artifacts in IDE (VS Code, etc.)
2. Commit changes to feature branch
3. Create pull request to main branch
4. Code review and approval process
5. Merge triggers **Publisher** pipeline
6. Automated deployment to all environments

**Best For:**
- DevOps-mature teams
- New API development projects
- Teams requiring strict version control

## 📁 Project Structure

Your APIOps project follows this standardized structure:

```
api-ops/
├── 📄 configuration.prod.yaml           # Environment-specific overrides
├── 📁 apimartifacts/                    # Extracted APIM artifacts
│   ├── 📄 policy.xml                    # Global policies
│   ├── 📁 apis/                         # API definitions
│   │   └── 📁 echo-api/
│   │       ├── 📄 apiInformation.json   # API metadata
│   │       ├── 📄 specification.yaml    # OpenAPI specification
│   │       └── 📁 operations/           # Operation-level policies
│   ├── 📁 products/                     # Product definitions
│   │   ├── 📁 starter/
│   │   └── 📁 unlimited/
│   ├── 📁 groups/                       # User groups
│   ├── 📁 named values/                 # Configuration values
│   ├── 📁 subscriptions/                # API subscriptions
│   ├── 📁 loggers/                      # Logging configurations
│   └── 📁 diagnostics/                  # Diagnostic settings
└── 📁 tools/                            # Utility scripts
    └── 📁 scripts/
        ├── 📄 New-ExtractorConfiguration.ps1
        ├── 📄 autogen.configuration.extractor.dev.yaml
        └── 📄 autogen.configuration.extractor.prod.yaml
```

### Key Artifacts Explained

| Artifact | Description | Location |
|----------|-------------|----------|
| **APIs** | API definitions, specifications, and policies | `apimartifacts/apis/` |
| **Products** | Product configurations and associated APIs | `apimartifacts/products/` |
| **Named Values** | Configuration values and secrets | `apimartifacts/named values/` |
| **Policies** | Global and API-level policies | `apimartifacts/policy.xml` |
| **Groups** | User groups and permissions | `apimartifacts/groups/` |
| **Subscriptions** | API access subscriptions | `apimartifacts/subscriptions/` |
| **Loggers** | Application Insights and logging | `apimartifacts/loggers/` |
| **Diagnostics** | Monitoring and diagnostics | `apimartifacts/diagnostics/` |

## 🔧 Core Tools

APIOps provides two main tools for managing your API infrastructure:

### 1. Extractor Tool

**Purpose**: Generates APIOps artifacts from an existing APIM instance

**Key Parameters**:
```yaml
AZURE_SUBSCRIPTION_ID: "your-subscription-id"
AZURE_RESOURCE_GROUP_NAME: "your-resource-group"
API_MANAGEMENT_SERVICE_NAME: "your-apim-instance"
API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: "./apimartifacts"
API_SPECIFICATION_FORMAT: "OpenAPIV3Yaml"  # Options: Json, Yaml, OpenAPIV2Json, etc.
CONFIGURATION_YAML_PATH: "./configuration.yaml"  # Optional: for selective extraction
```

**Supported Formats**:
- OpenAPI v3 YAML (default)
- OpenAPI v3 JSON
- OpenAPI v2 JSON/YAML

### 2. Publisher Tool

**Purpose**: Updates Azure APIM instance with artifact folder contents

**Key Parameters**:
```yaml
AZURE_SUBSCRIPTION_ID: "your-subscription-id"
AZURE_RESOURCE_GROUP_NAME: "your-resource-group"
API_MANAGEMENT_SERVICE_NAME: "your-apim-instance"
API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: "./apimartifacts"
CONFIGURATION_YAML_PATH: "./configuration.prod.yaml"  # Environment overrides
COMMIT_ID: "abc123"  # Optional: deploy only changed files
```

## ⚙️ Configuration

### Environment-Specific Overrides

The `configuration.{env}.yaml` file allows you to override configurations when promoting across environments. This file is crucial for managing different settings across dev, staging, and production environments.

#### How to Write Configuration Files

Based on your current `configuration.prod.yaml`, here's the structure and explanation:

```yaml
# configuration.prod.yaml - Production environment overrides
apimServiceName: apiops-prod-eastus  # Target APIM instance name

# Named Values Configuration
namedValues:
  - name: named-value-1
    properties:
      displayName: "named-value-1"
      keyVault:
        identityClientId: "c52e89f4-8f46-466d-a946-fc451398b455"  # Managed Identity Client ID
        secretIdentifier: "https://kv-apiops-prod-eastus.vault.azure.net/secrets/secret-1"
        
  - name: named-value-2
    properties:
      displayName: "named-value-2"
      keyVault:
        identityClientId: "c52e89f4-8f46-466d-a946-fc451398b455"
        secretIdentifier: "https://kv-apiops-prod-eastus.vault.azure.net/secrets/secret-2"
        
  - name: named-value-3
    properties:
      displayName: "named-value-3"
      keyVault:
        identityClientId: "c52e89f4-8f46-466d-a946-fc451398b455"
        secretIdentifier: "https://kv-apiops-prod-eastus.vault.azure.net/secrets/secret-3"
        
  - name: application-insights-instrumentation-key
    properties:
      displayName: "application-insights-instrumentation-key"
      keyVault:
        identityClientId: "c52e89f4-8f46-466d-a946-fc451398b455"
        secretIdentifier: "https://kv-apiops-prod-eastus.vault.azure.net/secrets/application-insights-instrumentation-key"

# Logger Configuration
loggers:
  - name: applicationinsights
    properties:
      loggerType: applicationInsights
      description: prod application insights
      resourceId: "/subscriptions/df7ed44c-e98a-43c4-af18-241e33567262/resourceGroups/RG-UmeshPagar/providers/microsoft.insights/components/appi-apiops-prod-eastus"
      credentials:
        instrumentationKey: "{{application-insights-instrumentation-key}}"
        
  - name: azuremonitor
    properties:
      loggerType: azureMonitor
      isBuffered: true

# Diagnostics Configuration
diagnostics:
  - name: applicationinsights
    properties:
      verbosity: Error
      loggerId: "/subscriptions/df7ed44c-e98a-43c4-af18-241e33567262/resourceGroups/RG-UmeshPagar/providers/Microsoft.ApiManagement/service/api-ops-prod-eastus/loggers/appi-apiops-prod-eastus"
      
  - name: azuremonitor
    properties:
      verbosity: Error
      loggerId: "/subscriptions/df7ed44c-e98a-43c4-af18-241e33567262/resourceGroups/RG-UmeshPagar/providers/Microsoft.ApiManagement/service/api-ops-prod-eastus/loggers/azuremonitor"
```

#### Configuration File Best Practices

1. **Environment Naming**: Use clear environment suffixes
   - `configuration.dev.yaml` - Development environment
   - `configuration.qa.yaml` - QA/Staging environment
   - `configuration.prod.yaml` - Production environment

2. **Key Vault Integration**:
   ```yaml
   keyVault:
     identityClientId: "your-managed-identity-client-id"
     secretIdentifier: "https://your-keyvault.vault.azure.net/secrets/secret-name"
   ```

3. **Resource ID Format**:
   ```yaml
   resourceId: "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/{provider}/{resource-name}"
   ```

4. **Named Value References**:
   - Use `{{named-value-name}}` to reference named values in other configurations
   - Ensure the named value exists before referencing it

5. **Verbosity Levels**: Choose appropriate logging levels
   - `Critical` - Only critical errors
   - `Error` - Error messages
   - `Warning` - Warning and error messages
   - `Information` - Informational, warning, and error messages
   - `Verbose` - All messages (use carefully in production)

#### Creating Configuration Files for Different Environments

**Step 1: Start with a base template**
```powershell
# Copy your production config as a template
Copy-Item "configuration.prod.yaml" "configuration.dev.yaml"
```

**Step 2: Update environment-specific values**
```yaml
# configuration.dev.yaml
apimServiceName: apiops-dev-eastus  # Different APIM instance

namedValues:
  - name: named-value-1
    properties:
      displayName: "named-value-1"
      keyVault:
        identityClientId: "dev-managed-identity-client-id"  # Different identity
        secretIdentifier: "https://kv-apiops-dev-eastus.vault.azure.net/secrets/secret-1"  # Different Key Vault
```

**Step 3: Validate your configuration**
```powershell
# Test YAML syntax
python -c "import yaml; print('Valid YAML') if yaml.safe_load(open('configuration.prod.yaml')) else print('Invalid YAML')"
```

### Selective Extraction

For multi-team scenarios, create team-specific extraction configurations:

```yaml
# team-a-extraction.yaml
apis:
  - name: "payment-api"
  - name: "billing-api"
    
products:
  - name: "payment-product"
  
namedValues:
  - name: "payment-backend-url"
```

### Common Configuration Patterns

#### 1. Environment-Specific Backend URLs
```yaml
# configuration.prod.yaml
namedValues:
  - name: backend-service-url
    properties:
      displayName: "Backend Service URL"
      value: "https://api.prod.company.com"

# configuration.dev.yaml  
namedValues:
  - name: backend-service-url
    properties:
      displayName: "Backend Service URL"
      value: "https://api.dev.company.com"
```

#### 2. Different Application Insights per Environment
```yaml
# Each environment points to its own Application Insights
loggers:
  - name: applicationinsights
    properties:
      loggerType: applicationInsights
      resourceId: "/subscriptions/{subscription}/resourceGroups/{env}-rg/providers/microsoft.insights/components/{env}-appinsights"
```

#### 3. Key Vault Secret Management
```yaml
# Secrets stored in environment-specific Key Vaults
namedValues:
  - name: database-connection-string
    properties:
      displayName: "Database Connection String"
      keyVault:
        identityClientId: "{env-specific-managed-identity-id}"
        secretIdentifier: "https://kv-{env}.vault.azure.net/secrets/db-connection"
```

#### 4. API Rate Limiting per Environment
```yaml
# Different rate limits for different environments
products:
  - name: starter
    properties:
      subscriptionsLimit: 100  # Production: higher limits
      
# vs development
products:
  - name: starter
    properties:
      subscriptionsLimit: 10   # Development: lower limits
```

## 🚀 Getting Started

### Step 1: Repository Setup

1. **Clone/Fork the APIOps repository**:
   ```bash
   git clone https://github.com/Azure/apiops.git
   cd apiops
   ```

2. **Set up your branch structure**:
   ```bash
   git checkout -b develop
   git checkout -b feature/initial-setup
   ```

### Step 2: Extract Existing APIM Configuration

1. **Configure the extractor** (using provided PowerShell script):
   ```powershell
   .\tools\scripts\New-ExtractorConfiguration.ps1 `
     -SubscriptionId "your-subscription-id" `
     -ResourceGroupName "your-rg" `
     -ApimInstanceName "your-apim" `
     -Stage "dev"
   ```

2. **Run the extraction** (manually or via pipeline):
   ```bash
   # If using Azure CLI
   az account set --subscription "your-subscription-id"
   
   # Run extractor tool
   dotnet run --project tools/extractor -- \
     --subscriptionId "your-subscription-id" \
     --resourceGroupName "your-rg" \
     --apimInstanceName "your-apim" \
     --outputFolder "./apimartifacts"
   ```

### Step 3: Set Up CI/CD Pipelines

#### For Azure DevOps:
1. Import the provided pipeline templates
2. Configure service connections (preferably workload identity per environment)
3. Set up variable groups for environment-specific values
4. Configure approvals for production deployments
5. Create Azure DevOps environments for approval gates and historical job logs

**Multi-Stage Publisher Pipeline Setup**:

Create separate stages for each environment in your `tools/pipelines/run-publisher.yaml`:

```yaml
stages:
- stage: push_changes_to_Dev_APIM
  displayName: Push changes to Dev APIM
  jobs:
  - job: push_changes_to_Dev_APIM
    displayName: Push changes to Dev APIM
    pool:
      vmImage: ubuntu-latest
    steps:
    - template: run-publisher-with-env.yaml
      parameters:
        API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: ${{ parameters.API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH }}
        RESOURCE_GROUP_NAME: $(RESOURCE_GROUP_NAME)
        API_MANAGEMENT_SERVICE_NAME: $(APIM_NAME)
        ENVIRONMENT: "Dev"
        COMMIT_ID: ${{ parameters.COMMIT_ID }}
        SERVICE_CONNECTION_NAME_ENV: $(SERVICE_CONNECTION_NAME)

- stage: push_changes_to_Test_APIM
  displayName: Push changes to Test APIM
  jobs:
  - deployment: push_changes_to_Test_APIM
    displayName: Push changes to Test APIM
    pool:
      vmImage: ubuntu-latest
    environment: 'Test'  # Creates approval gate
    strategy:
      runOnce:
        deploy:
          steps:
          - template: run-publisher-with-env.yaml
            parameters:
              API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: ${{ parameters.API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH }}
              RESOURCE_GROUP_NAME: $(RESOURCE_GROUP_NAME_Test)
              CONFIGURATION_YAML_PATH: $(Build.SourcesDirectory)/configuration.test.yaml
              ENVIRONMENT: "Test"
              COMMIT_ID: ${{ parameters.COMMIT_ID }}
              SERVICE_CONNECTION_NAME_ENV: $(SERVICE_CONNECTION_NAME_TEST)

- stage: push_changes_to_Prod_APIM
  displayName: Push changes to Prod APIM
  jobs:
  - deployment: push_changes_to_Prod_APIM
    displayName: Push changes to Prod APIM
    pool:
      vmImage: ubuntu-latest
    environment: 'Prod'  # Creates approval gate
    strategy:
      runOnce:
        deploy:
          steps:
          - template: run-publisher-with-env.yaml
            parameters:
              API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH: ${{ parameters.API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH }}
              RESOURCE_GROUP_NAME: $(RESOURCE_GROUP_NAME_Prod)
              CONFIGURATION_YAML_PATH: $(Build.SourcesDirectory)/configuration.prod.yaml
              ENVIRONMENT: "Prod"
              COMMIT_ID: ${{ parameters.COMMIT_ID }}
              SERVICE_CONNECTION_NAME_ENV: $(SERVICE_CONNECTION_NAME_PROD)
```

#### For GitHub Actions:
1. Set up repository secrets for Azure authentication
2. Configure environment protection rules
3. Import workflow templates
4. Set up environment-specific variables

### Step 4: Configure Environment Overrides

1. **Create environment-specific configuration files**:
   ```bash
   cp configuration.yaml configuration.dev.yaml
   cp configuration.yaml configuration.qa.yaml
   cp configuration.yaml configuration.prod.yaml
   ```

2. **Update each file** with environment-specific values

3. **Commit and push**:
   ```bash
   git add .
   git commit -m "Initial APIOps setup"
   git push origin feature/initial-setup
   ```

## 📊 Workflows

### Portal-First Workflow (Scenario A)

```mermaid
graph LR
    A[Azure Portal Changes] --> B[Manual Extractor Run]
    B --> C[Auto-generated PR]
    C --> D[Code Review]
    D --> E[Merge to Main]
    E --> F[Publisher Pipeline]
    F --> G[Deploy to Environments]
```

1. **Development Phase**:
   - Make changes in Azure Portal
   - Test changes in development environment

2. **Extraction Phase**:
   - Trigger extractor pipeline manually
   - Review generated artifacts in PR

3. **Review Phase**:
   - Code review of extracted artifacts
   - Validate policy changes
   - Approve and merge PR

4. **Deployment Phase**:
   - Automatic deployment to higher environments
   - Manual approvals for production

### Code-First Workflow (Scenario B)

```mermaid
graph LR
    A[IDE Development] --> B[Feature Branch]
    B --> C[Create PR]
    C --> D[Code Review]
    D --> E[Merge to Main]
    E --> F[Publisher Pipeline]
    F --> G[Deploy to All Environments]
```

1. **Development Phase**:
   - Create/modify artifacts in IDE
   - Use OpenAPI specifications
   - Define policies as XML files

2. **Integration Phase**:
   - Create feature branch
   - Commit changes with descriptive messages
   - Create pull request

3. **Review Phase**:
   - Peer review of code changes
   - Automated validation (if configured)
   - Approve and merge

4. **Deployment Phase**:
   - Automatic deployment pipeline execution
   - Environment-specific configurations applied

## 🏆 Best Practices

### Pre-Implementation Readiness and Standardization

**Critical**: The major hurdle to adopting APIOps is standardizing your APIM properties. All named values, APIs, loggers, diagnostics, backends, etc., must have **consistent names across all environments**. APIOps overwrites values, not names, during environment promotion.

#### 1. **API Policy Standardization**

**✅ DO THIS** - Use named values for dynamic content:
```xml
<policies>
  <inbound>
    <base />
    <choose>
      <when condition="@(context.Variables.GetValueOrDefault("iss", "").Equals("https://sts.windows.net/someTenantId/"))">
        <validate-azure-ad-token tenant-id="00000000-0000-0000-0000-000000000000">
          <client-application-ids>
            <application-id>{{api-appId}}</application-id>
          </client-application-ids>
        </validate-azure-ad-token>
      </when>
    </choose>
  </inbound>
</policies>
```

**❌ AVOID THIS** - Hard-coded values:
```xml
<policies>
  <inbound>
    <base />
    <choose>
      <when condition="@(context.Variables.GetValueOrDefault("iss", "").Equals("https://sts.windows.net/someTenantId/"))">
        <validate-azure-ad-token tenant-id="00000000-0000-0000-0000-000000000000">
          <client-application-ids>
            <application-id>bccc8b07-147f-4502-9fcf-bf2125adc4e1</application-id>
          </client-application-ids>
        </validate-azure-ad-token>
      </when>
    </choose>
  </inbound>
</policies>
```

#### 2. **CORS Policy Standardization**

**✅ DO THIS** - Dynamic CORS origins:
```xml
<allowed-origins>
  <origin>@{
    string[] allowedOrigins = "{{api-allowed-origins}}"
      .Replace(" ", string.Empty)
      .Split(',');
    string requestOrigin = context.Request.Headers.GetValueOrDefault("Origin", "");
    bool isAllowed = Array.Exists(allowedOrigins, origin => origin == requestOrigin);
    return isAllowed ? requestOrigin : string.Empty;
  }</origin>
</allowed-origins>
```

**❌ AVOID THIS** - Hard-coded CORS:
```xml
<allowed-origins>
  <origin>http://localhost:7890</origin>
</allowed-origins>
```

#### 3. **Backend Naming Convention**

- **Standardize names**: Change `dev-someApi-backend` to `someApi-backend`
- **Consistent across environments**: Same backend name in dev, test, and prod
- **Override URLs and Resource IDs**: Use configuration files to specify environment-specific values

#### 4. **Named Values Standardization**

- **Remove environment prefixes**: Change `dev-api-secret` to `api-secret`
- **Use Key Vault for secrets**: Link sensitive values to Azure Key Vault
- **Consistent naming**: Same named value names across all environments

#### 5. **Application Insights Configuration**

**Use static names** for loggers and diagnostics:
- ✅ Use: `applicationInsights`
- ❌ Avoid: `prod-appInsights-apim`

Example `loggerInformation.json`:
```json
{
  "properties": {
    "loggerType": "applicationInsights",
    "credentials": {
      "instrumentationKey": "{{applicationInsights-instrumentation-key}}"
    },
    "isBuffered": true,
    "resourceId": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-uks-dev-apim/providers/microsoft.insights/components/app-insights-dev"
  }
}
```

### Development Best Practices

1. **Use Descriptive Names**:
   - API names should be clear and consistent
   - Use meaningful operation IDs
   - Follow naming conventions across teams

2. **Version Control**:
   - Always create feature branches for changes
   - Use semantic versioning for APIs
   - Tag releases for easy rollback

3. **Policy Management**:
   - Keep policies modular and reusable
   - Use named values for environment-specific settings
   - Test policies in lower environments first

4. **Security**:
   - Store secrets in Azure Key Vault
   - Use managed identities when possible
   - Implement proper RBAC controls

### Configuration File Organization

**💡 Tip**: Add comments and separators in YAML files for better readability:

```yaml
# configuration.prod.yaml example
#########################
## MARK: APIM Instance ##
#########################
apimServiceName: apim-uks-prod-rios

#########################
## MARK: Named Values  ##
#########################
namedValues:
- name: api-appId
  properties:
    displayName: api-appId
    secret: false
    value: 00000000-0000-0000-0000-000000000000

###################
## MARK: Loggers ##
###################
loggers:
- name: applicationInsights
  properties:
    loggerType: applicationInsights
    # ...additional configuration
```

**💡 Tip**: Use Azure Portal's "Export template" feature to easily collect higher environment APIM instance values for your YAML override files.

### Operational Best Practices

1. **Environment Isolation**:
   - Separate APIM instances per environment
   - Use different Azure subscriptions if possible
   - Implement network isolation

2. **Monitoring**:
   - Configure Application Insights for all environments
   - Set up alerts for API failures
   - Monitor performance metrics

3. **Backup and Recovery**:
   - Regular exports of APIM configurations
   - Document rollback procedures
   - Test disaster recovery scenarios

### Team Collaboration

1. **Code Reviews**:
   - Require PR reviews for all changes
   - Include security reviews for policy changes
   - Document review criteria

2. **Documentation**:
   - Maintain API documentation
   - Document environment-specific configurations
   - Keep runbooks updated

3. **Training**:
   - Train team members on APIOps workflows
   - Provide OpenAPI specification training
   - Regular knowledge sharing sessions

## 🐛 Troubleshooting

### Common Issues

#### 1. Extraction Failures

**Problem**: Extractor fails to connect to APIM instance
```
Error: Unable to authenticate to Azure API Management
```

**Solutions**:
- Verify Azure credentials and permissions
- Check APIM instance name and resource group
- Ensure subscription ID is correct
- Validate Azure CLI authentication: `az account show`

#### 2. Publishing Errors

**Problem**: Publisher fails to deploy artifacts
```
Error: Conflict - API already exists with different configuration
```

**Solutions**:
- Check for conflicting changes in target environment
- Use commit ID parameter for incremental deployments
- Verify configuration override syntax
- Review ARM API version compatibility

#### 3. Policy Validation Errors

**Problem**: Invalid policy XML
```
Error: Policy contains invalid XML or unsupported elements
```

**Solutions**:
- Validate XML syntax using online validators
- Check policy expressions for correct syntax
- Test policies in development environment first
- Reference APIM policy documentation

#### 4. Named Values Issues

**Problem**: Named values not resolving correctly
```
Error: Named value 'backend-url' not found
```

**Solutions**:
- Verify named value exists in configuration file
- Check spelling and case sensitivity
- Ensure proper environment configuration
- Validate Key Vault permissions (if using Key Vault)

#### 5. Configuration File Issues

**Problem**: YAML syntax errors in configuration files
```
Error: Invalid YAML syntax in configuration file
```

**Solutions**:
- Validate YAML syntax using online validators or tools
- Check indentation (use spaces, not tabs)
- Ensure proper quoting of special characters
- Validate file encoding (should be UTF-8)

**Problem**: Key Vault access denied
```
Error: Access denied to Key Vault secret
```

**Solutions**:
- Verify managed identity has Key Vault access policies
- Check `identityClientId` matches the managed identity
- Ensure Key Vault URL and secret name are correct
- Validate subscription and resource group permissions

**Problem**: Logger configuration errors
```
Error: Logger resource not found
```

**Solutions**:
- Verify Application Insights resource exists
- Check resource ID format and subscription ID
- Ensure resource group and component names are correct
- Validate APIM service has access to Application Insights

### Common Gotchas and Advanced Troubleshooting

#### Service Connection Issues
**Problem**: Publishing fails due to multiple subscription access
**Solution**: 
- Ensure each service connection has access to only the necessary subscription
- Use one identity per environment
- Modify pipeline to explicitly set the required subscription

#### Publisher Commit Behavior
**Problem**: Publisher only processes changes from the last commit
**Solutions**:
- Run pipeline in full artifact mode to redeploy all artifacts
- Use incremental commits for changes
- Ensure all related changes are in the same commit

#### Environment Consistency Issues
**Problem**: Deployment fails due to environment discrepancies
**Solutions**:
- Check higher APIM instances for discrepancies between dev/prod
- Ensure all environments have matching versions, revisions, etc.
- Align or remove unnecessary differences between environments

#### Override Configuration Behavior
**Important**: Anything not explicitly in the override configuration takes values from Git repository artifact files
**Best Practice**: 
- Include all necessary property changes in override files
- Remember that overrides are the only way to change values during APIOps promotion
- Document what gets overridden vs. what comes from Git artifacts

#### OpenAPI Specification Issues
**Problem**: Validation errors only appear during APIM deployment
**Solution**: 
- Align to OpenAPI v3 specification
- Implement Spectral analysis in PR validation
- Catch validation errors before publisher pipeline runs
- Prevent situations where fixes only apply to last commit

#### API Deletion Behavior
**Problem**: APIOps doesn't delete resources that are removed from repository
**Solution**:
- APIOps only detects changes when files are committed and then removed
- To delete an API: commit it to repository first, then delete and commit again
- For APIs: delete both specification file AND information file
- Always delete the entire folder when removing an API

### Debugging Tips

1. **Enable Verbose Logging**:
   ```yaml
   Logging__LogLevel__Default: "Debug"
   ```

2. **Use Incremental Deployments**:
   ```yaml
   COMMIT_ID: "your-commit-id"  # Deploy only changed files
   ```

3. **Validate Configurations**:
   ```bash
   # Test YAML syntax
   python -c "import yaml; yaml.safe_load(open('configuration.prod.yaml'))"
   ```

4. **Check Azure Permissions**:
   ```bash
   az role assignment list --assignee your-user-id --resource-group your-rg
   ```

## 🏗️ Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Development   │    │    Staging       │    │   Production    │
│      APIM       │    │      APIM        │    │      APIM       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Git Repository                           │
│  ┌───────────────┐  ┌─────────────────┐  ┌─────────────────┐   │
│  │   Artifacts   │  │ Configurations  │  │   Pipelines     │   │
│  │               │  │                 │  │                 │   │
│  │ • APIs        │  │ • dev.yaml      │  │ • Extractor     │   │
│  │ • Products    │  │ • qa.yaml       │  │ • Publisher     │   │
│  │ • Policies    │  │ • prod.yaml     │  │ • Validation    │   │
│  │ • Named Values│  │                 │  │                 │   │
│  └───────────────┘  └─────────────────┘  └─────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Component Interaction

1. **Extractor Tool**: Pulls configuration from APIM → Git
2. **Publisher Tool**: Pushes configuration from Git → APIM
3. **Configuration Files**: Override settings per environment
4. **CI/CD Pipelines**: Orchestrate the entire process
5. **Version Control**: Maintains history and enables collaboration

## 🔍 API Quality and Governance

### Spectral Linting Integration

Enhance your API governance by integrating [Spectral](https://stoplight.io/open-source/spectral) linting into your pull request validation pipeline.

#### Why Use Spectral?
- **Early Error Detection**: Catch OpenAPI specification issues before deployment
- **Consistent Standards**: Enforce organizational API design guidelines
- **Prevent Pipeline Failures**: Avoid APIM REST API deployment failures

#### Setting Up Spectral

1. **Install Spectral** in your pipeline:
   ```bash
   npm install -g @stoplight/spectral-cli
   ```

2. **Create a Spectral ruleset** (`.spectral.yml`):
   ```yaml
   extends: ["spectral:oas"]
   rules:
     # Custom rules for your organization
     info-contact: error
     info-description: error
     operation-description: error
     operation-operationId: error
     operation-summary: error
     operation-tags: error
   ```

3. **Add to your PR pipeline**:
   ```yaml
   - task: Npm@1
     displayName: 'Install Spectral'
     inputs:
       command: 'install'
       workingDir: '$(System.DefaultWorkingDirectory)'
       verbose: false
       customRegistry: 'useNpmrc'
       customEndpoint: 'spectral'
   
   - script: |
       spectral lint "apimartifacts/apis/**/*.{json,yml,yaml}" --format junit --output spectral-results.xml
     displayName: 'Run Spectral API Linting'
   
   - task: PublishTestResults@2
     displayName: 'Publish Spectral Results'
     inputs:
       testResultsFormat: 'JUnit'
       testResultsFiles: 'spectral-results.xml'
       failTaskOnFailedTests: true
   ```

#### Benefits of Early Validation
- **Prevent Commit-Based Issues**: Avoid situations where deployment fails and subsequent fixes are ignored
- **Improve API Quality**: Ensure consistent API design across your organization
- **Reduce Deployment Time**: Catch issues before they reach the publisher pipeline

### Azure API Center Integration

Microsoft's [Azure API Center](https://learn.microsoft.com/en-us/azure/api-center/overview) can complement your APIOps implementation:

#### Key Features:
- **Centralized API Discovery**: Track all organizational APIs in one location
- **API Governance**: Implement organization-wide API standards
- **Lifecycle Management**: Manage API versions and lifecycles
- **Integration Ready**: Built to work with existing DevOps pipelines

#### Integration with APIOps:
- Use API Center for discovery and governance
- Maintain APIOps for deployment and environment management
- Combine both for comprehensive API management strategy

### OpenAPI v3 Alignment

**Recommendation**: Align all API specifications to OpenAPI v3 standard for:
- Better tooling support
- Enhanced validation capabilities
- Future-proof API definitions
- Integration with modern API tools and platforms

## ✨ Project Status and Community

### Important Notes

- **Open Source**: APIOps is an open-source project and is **not officially supported by Microsoft**
- **Community Driven**: This is a best-effort project relying on community contributions
- **Key Contributors**: The project is largely led and organized by:
  - [Wael Kdouh](https://waelkdouh.medium.com/) (Microsoft FTE)
  - [guythetechie](https://github.com/guythetechie) (Core contributor)
- **Active Development**: The project is actively maintained with regular updates and improvements

### Getting Help

Before implementing APIOps in your organization:

1. **Review Documentation**: Start with the [official documentation](https://azure.github.io/apiops/)
2. **Watch the Introduction Video**: Available on the documentation site
3. **Understand Supported Scenarios**: Review the [supported scenarios section](https://azure.github.io/apiops/apiops/1-supportedScenarios/)
4. **Join the Community**: Participate in GitHub discussions and issues

## 📚 Additional Resources

### Official Documentation
- [APIOps Documentation](https://azure.github.io/apiops/)
- [Azure API Management Documentation](https://docs.microsoft.com/azure/api-management/)
- [OpenAPI Specification](https://swagger.io/specification/)

### Community Resources
- [APIOps GitHub Repository](https://github.com/Azure/apiops)
- [Azure API Management Community](https://techcommunity.microsoft.com/t5/azure-integration-services/bd-p/AzureIntegrationServices)
- [API Design Guidelines](https://github.com/microsoft/api-guidelines)

### Training Materials
- [Azure API Management Learning Path](https://docs.microsoft.com/learn/paths/publish-manage-apis-with-azure-api-management/)
- [GitOps Best Practices](https://www.gitops.tech/)
- [OpenAPI 3.0 Tutorial](https://swagger.io/docs/specification/about/)

## 🤝 Contributing

We welcome contributions to improve this APIOps implementation! Please:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Commit your changes** (`git commit -m 'Add amazing feature'`)
4. **Push to the branch** (`git push origin feature/amazing-feature`)
5. **Open a Pull Request**

### Contribution Guidelines

- Follow existing code style and conventions
- Add tests for new functionality
- Update documentation as needed
- Ensure all pipelines pass before submitting PR

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/Azure/apiops/blob/main/LICENSE) file for details.

## 📞 Support

For support and questions:

- **Issues**: [GitHub Issues](https://github.com/Azure/apiops/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Azure/apiops/discussions)
- **Microsoft Support**: For Azure-specific issues, contact Microsoft Support

---

**Made with ❤️ by the Azure API Management team and the community**

> This README is based on APIOps version 2022-09-01 and Azure API Management service API version 2022-04-01-preview. For the latest updates, please refer to the [official documentation](https://azure.github.io/apiops/).
