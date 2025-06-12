# Azure API Management Logger Management Script
# This script lists, creates, and deletes loggers for an Azure API Management service using the REST API
# References: 
# - List: https://learn.microsoft.com/en-us/rest/api/apimanagement/logger/list-by-service?view=rest-apimanagement-2024-05-01&tabs=HTTP
# - Delete: https://learn.microsoft.com/en-us/rest/api/apimanagement/logger/delete?view=rest-apimanagement-2024-05-01&tabs=HTTP
# - Create: https://learn.microsoft.com/en-us/rest/api/apimanagement/logger/create-or-update?view=rest-apimanagement-2024-05-01&tabs=HTTP

param(
    [Parameter(Mandatory = $false)]
    [string]$ServiceName = "apiops-dev-eastus",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "RG-UmeshPagar",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = "14688d65-0570-4508-a201-955fbc8abe06",
    
    [Parameter(Mandatory = $false)]
    [string]$Action = "List",  # Options: "List", "Delete", "Create"
    
    [Parameter(Mandatory = $false)]
    [string]$LoggerName = "",  # Required when Action is "Delete" or "Create"
    
    [Parameter(Mandatory = $false)]
    [string]$LoggerType = "applicationInsights",  # Options: "applicationInsights", "azureMonitor", "azureEventHub"
    
    [Parameter(Mandatory = $false)]
    [string]$InstrumentationKeyNamedValue = "application-insights-instrumentation-key",  # Named value containing instrumentation key
    
    [Parameter(Mandatory = $false)]
    [string]$Description = "",  # Optional description for the logger
    
    [Parameter(Mandatory = $false)]
    [switch]$Force = $false,  # Skip confirmation prompts when deleting
    
    [Parameter(Mandatory = $false)]
    [switch]$Help = $false  # Show help information
)

# Set error action preference to stop on errors
$ErrorActionPreference = "Stop"

# Function to write output with timestamp
function Write-LogOutput {
    param([string]$Message, [string]$Level = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Success" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

# Function to get access token using Azure CLI (recommended for interactive scenarios)
function Get-AccessToken {
    try {
        Write-LogOutput "Authenticating with Azure..."
        
        # Check if Azure CLI is installed and user is logged in
        $azAccount = az account show 2>$null | ConvertFrom-Json
        if (-not $azAccount) {
            Write-LogOutput "Please log in to Azure CLI first: az login" -Level "Error"
            throw "Azure CLI authentication required"
        }
        
        # Set the subscription context
        az account set --subscription $SubscriptionId
        Write-LogOutput "Using subscription: $($azAccount.name) ($SubscriptionId)"
        
        # Get access token for Azure Resource Manager
        $tokenResponse = az account get-access-token --resource https://management.azure.com/ | ConvertFrom-Json
        return $tokenResponse.accessToken
    }
    catch {
        Write-LogOutput "Failed to get access token: $_" -Level "Error"
        throw
    }
}

# Function to make REST API call with retry logic
function Invoke-ApiRequest {
    param(
        [string]$Uri,
        [hashtable]$Headers,
        [string]$Method = "GET",
        [int]$MaxRetries = 3
    )
    
    $retryCount = 0
    $baseDelay = 1
    
    while ($retryCount -lt $MaxRetries) {
        try {
            Write-LogOutput "Making $Method API request to: $Uri"
            $response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method $Method
            return $response
        }
        catch {
            $retryCount++
            $statusCode = $_.Exception.Response.StatusCode.value__
            
            if ($statusCode -eq 429 -or $statusCode -ge 500) {
                if ($retryCount -lt $MaxRetries) {
                    $delay = $baseDelay * [Math]::Pow(2, $retryCount - 1)
                    Write-LogOutput "Request failed with status $statusCode. Retrying in $delay seconds... (Attempt $retryCount/$MaxRetries)" -Level "Warning"
                    Start-Sleep -Seconds $delay
                    continue
                }
            }
            
            Write-LogOutput "API request failed: $($_.Exception.Message)" -Level "Error"
            if ($_.Exception.Response) {
                $statusCode = $_.Exception.Response.StatusCode.value__
                $statusDescription = $_.Exception.Response.StatusDescription
                Write-LogOutput "Status Code: $statusCode - $statusDescription" -Level "Error"
            }
            throw
        }
    }
}

# Function to format and display logger information
function Format-LoggerOutput {
    param([object]$Loggers)
    
    if (-not $Loggers.value -or $Loggers.value.Count -eq 0) {
        Write-LogOutput "No loggers found in the API Management service." -Level "Warning"
        return
    }
    
    Write-LogOutput "Found $($Loggers.value.Count) logger(s):" -Level "Success"
    Write-Host "`n" -NoNewline
    
    # Create a formatted table
    $loggerData = @()
    foreach ($logger in $Loggers.value) {
        $loggerData += [PSCustomObject]@{
            Name = $logger.name
            Type = $logger.properties.loggerType
            ResourceId = $logger.properties.resourceId
            Description = $logger.properties.description
        }
    }
    
    $loggerData | Format-Table -AutoSize
    
    # Display detailed information for each logger
    Write-Host "`nDetailed Logger Information:" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    
    foreach ($logger in $Loggers.value) {
        Write-Host "`nLogger: $($logger.name)" -ForegroundColor Yellow
        Write-Host "  Type: $($logger.properties.loggerType)"
        Write-Host "  Resource ID: $($logger.properties.resourceId)"
        Write-Host "  Description: $($logger.properties.description)"
        
        if ($logger.properties.credentials) {
            Write-Host "  Credentials: Configured" -ForegroundColor Green
        }
        
        if ($logger.properties.isBuffered) {
            Write-Host "  Buffered: $($logger.properties.isBuffered)"
        }
    }
}

# Function to list all loggers
function Get-ApiManagementLoggers {
    param(
        [hashtable]$Headers,
        [string]$BaseUri,
        [string]$ResourcePath,
        [string]$ApiVersion
    )
    
    $uri = "$BaseUri$ResourcePath" + "?api-version=$ApiVersion"
    $response = Invoke-ApiRequest -Uri $uri -Headers $Headers -Method "GET"
    return $response
}

# Function to delete a specific logger
function Remove-ApiManagementLogger {
    param(
        [hashtable]$Headers,
        [string]$BaseUri,
        [string]$ResourcePath,
        [string]$LoggerName,
        [string]$ApiVersion,
        [string]$IfMatch = "*"
    )
    
    # Construct the delete URI
    $deleteUri = "$BaseUri$ResourcePath/$LoggerName" + "?api-version=$ApiVersion"
    
    # Add If-Match header for delete operation (required by API)
    $deleteHeaders = $Headers.Clone()
    $deleteHeaders['If-Match'] = $IfMatch
      try {
        Write-LogOutput "Attempting to delete logger: $LoggerName"
        Invoke-ApiRequest -Uri $deleteUri -Headers $deleteHeaders -Method "DELETE" | Out-Null
        Write-LogOutput "Logger '$LoggerName' deleted successfully" -Level "Success"
        return $true
    }    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorBody = ""
        
        # Try to get the error response body for more details
        try {
            if ($_.Exception.Response.Content) {
                $stream = $_.Exception.Response.Content.ReadAsStreamAsync().Result
                $reader = New-Object System.IO.StreamReader($stream)
                $errorBody = $reader.ReadToEnd()
                $reader.Close()
                $stream.Close()
            }
        }
        catch {
            # Ignore errors when trying to read the response body
        }
        
        if ($statusCode -eq 404) {
            Write-LogOutput "Logger '$LoggerName' not found (404)" -Level "Warning"
        }
        elseif ($statusCode -eq 400) {
            Write-LogOutput "Bad Request (400). The logger may be a built-in logger that cannot be deleted." -Level "Error"
            if ($errorBody) {
                Write-LogOutput "Error details: $errorBody" -Level "Error"
            }
        }
        elseif ($statusCode -eq 412) {
            Write-LogOutput "Precondition failed (412). The logger may have been modified. Try again." -Level "Error"
        }
        else {
            Write-LogOutput "Failed to delete logger '$LoggerName': $($_.Exception.Message)" -Level "Error"
            if ($errorBody) {
                Write-LogOutput "Error details: $errorBody" -Level "Error"
            }
        }        return $false
    }
}

# Function to create or update a logger
function New-ApiManagementLogger {
    param(
        [hashtable]$Headers,
        [string]$BaseUri,
        [string]$ResourcePath,
        [string]$LoggerName,
        [string]$LoggerType,
        [string]$InstrumentationKeyNamedValue,
        [string]$Description,
        [string]$ApiVersion
    )
    
    # Construct the create/update URI
    $createUri = "$BaseUri$ResourcePath/$LoggerName" + "?api-version=$ApiVersion"
    
    # Build the logger configuration based on type
    $loggerConfig = @{
        properties = @{
            loggerType = $LoggerType
        }
    }
    
    # Add description if provided
    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        $loggerConfig.properties.description = $Description
    }
    
    # Configure logger based on type
    switch ($LoggerType.ToLower()) {
        "applicationinsights" {
            # For Application Insights, we reference the named value containing the instrumentation key
            $loggerConfig.properties.credentials = @{
                instrumentationKey = "{{$InstrumentationKeyNamedValue}}"
            }
            Write-LogOutput "Configuring Application Insights logger with named value: $InstrumentationKeyNamedValue"
        }
        "azuremonitor" {
            # Azure Monitor logger doesn't require additional credentials
            Write-LogOutput "Configuring Azure Monitor logger"
        }
        "azureeventhub" {
            Write-LogOutput "Azure Event Hub logger requires additional configuration not implemented in this script" -Level "Warning"
            throw "Azure Event Hub logger configuration not supported"
        }
        default {
            throw "Unsupported logger type: $LoggerType"
        }
    }
    
    # Convert to JSON
    $body = $loggerConfig | ConvertTo-Json -Depth 10
    
    # Prepare headers for PUT request
    $createHeaders = $Headers.Clone()
    $createHeaders['Content-Type'] = 'application/json'
    
    try {
        Write-LogOutput "Attempting to create/update logger: $LoggerName"
        Write-LogOutput "Logger Type: $LoggerType"
        Write-LogOutput "Request Body: $body"
        
        $response = Invoke-RestMethod -Uri $createUri -Headers $createHeaders -Method "PUT" -Body $body
        
        Write-LogOutput "Logger '$LoggerName' created/updated successfully" -Level "Success"
        return $response
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorBody = ""
        
        # Try to get the error response body for more details
        try {
            if ($_.Exception.Response.Content) {
                $stream = $_.Exception.Response.Content.ReadAsStreamAsync().Result
                $reader = New-Object System.IO.StreamReader($stream)
                $errorBody = $reader.ReadToEnd()
                $reader.Close()
                $stream.Close()
            }
        }
        catch {
            # Ignore errors when trying to read the response body
        }
        
        if ($statusCode -eq 400) {
            Write-LogOutput "Bad Request (400). Check logger configuration and named value existence." -Level "Error"
            if ($errorBody) {
                Write-LogOutput "Error details: $errorBody" -Level "Error"
            }
        }
        elseif ($statusCode -eq 404) {
            Write-LogOutput "Resource not found (404). Check service name and subscription details." -Level "Error"
        }
        elseif ($statusCode -eq 409) {
            Write-LogOutput "Conflict (409). Logger may already exist with different configuration." -Level "Error"
        }
        else {
            Write-LogOutput "Failed to create logger '$LoggerName': $($_.Exception.Message)" -Level "Error"
            if ($errorBody) {
                Write-LogOutput "Error details: $errorBody" -Level "Error"
            }
        }
        throw
    }
}

# Function to show help information
function Show-Help {
    Write-Host @"

Azure API Management Logger Management Script
============================================

This script allows you to list, create, and delete loggers in an Azure API Management service.

SYNTAX:
    .\logger.ps1 [[-ServiceName] <String>] [[-ResourceGroupName] <String>] 
                 [[-SubscriptionId] <String>] [[-Action] <String>] 
                 [[-LoggerName] <String>] [[-LoggerType] <String>]
                 [[-InstrumentationKeyNamedValue] <String>] [[-Description] <String>]
                 [-Force] [-Help]

PARAMETERS:
    -ServiceName <String>
        The name of the API Management service.
        Default: "apiops-dev-eastus"
        
    -ResourceGroupName <String>
        The name of the resource group containing the API Management service.
        Default: "RG-UmeshPagar"
        
    -SubscriptionId <String>
        The Azure subscription ID.
        Default: "14688d65-0570-4508-a201-955fbc8abe06"
        
    -Action <String>
        The action to perform. Valid values: "List", "Delete", "Create"
        Default: "List"
        
    -LoggerName <String>
        The name of the logger (required when Action is "Delete" or "Create").
        
    -LoggerType <String>
        The type of logger to create. Valid values: "applicationInsights", "azureMonitor", "azureEventHub"
        Default: "applicationInsights"
        
    -InstrumentationKeyNamedValue <String>
        The name of the named value containing the instrumentation key (for Application Insights loggers).
        Default: "application-insights-instrumentation-key"
        
    -Description <String>
        Optional description for the logger.
        
    -Force
        Skip confirmation prompts when deleting loggers.
        
    -Help
        Display this help information.

EXAMPLES:
    # List all loggers
    .\logger.ps1
    .\logger.ps1 -Action List
    
    # Create an Application Insights logger
    .\logger.ps1 -Action Create -LoggerName "applicationinsights" -LoggerType "applicationInsights"
    
    # Create a logger with custom description
    .\logger.ps1 -Action Create -LoggerName "mylogger" -LoggerType "applicationInsights" -Description "My custom logger"
    
    # Delete a specific logger with confirmation
    .\logger.ps1 -Action Delete -LoggerName "mylogger"
    
    # Delete a logger without confirmation
    .\logger.ps1 -Action Delete -LoggerName "mylogger" -Force
      # Use with different service parameters
    .\logger.ps1 -ServiceName "my-apim" -ResourceGroupName "my-rg" -SubscriptionId "my-sub-id"

NOTES:
    - You must be authenticated with Azure CLI (az login) before running this script.
    - Some built-in loggers (like 'azuremonitor') may not be deletable.
    - The script uses the Azure REST API version 2024-05-01.
    - For Application Insights loggers, ensure the named value with instrumentation key exists.

"@ -ForegroundColor Cyan
}

# Function to confirm delete action
function Confirm-DeleteAction {
    param([string]$LoggerName)
    
    if ($Force) {
        return $true
    }
    
    Write-Host "`nWARNING: You are about to delete the logger '$LoggerName'." -ForegroundColor Red
    Write-Host "This action cannot be undone." -ForegroundColor Red
    
    do {
        $confirmation = Read-Host "`nDo you want to continue? (y/N)"
        if ($confirmation -eq '' -or $confirmation -match '^[Nn]') {
            return $false
        }
        elseif ($confirmation -match '^[Yy]') {
            return $true
        }
        else {
            Write-Host "Please enter 'y' for yes or 'n' for no."
        }
    } while ($true)
}

# Main execution
try {
    # Show help if requested
    if ($Help) {
        Show-Help
        exit 0
    }
    
    Write-LogOutput "Starting Azure API Management Logger $Action Operation"
    Write-LogOutput "Service: $ServiceName"
    Write-LogOutput "Resource Group: $ResourceGroupName"
    Write-LogOutput "Subscription: $SubscriptionId"
      # Validate action parameter
    if ($Action -notin @("List", "Delete", "Create")) {
        Write-LogOutput "Invalid action '$Action'. Valid actions are: List, Delete, Create" -Level "Error"
        exit 1
    }
    
    # Validate logger name for delete and create operations
    if ($Action -in @("Delete", "Create") -and [string]::IsNullOrWhiteSpace($LoggerName)) {
        Write-LogOutput "LoggerName parameter is required when Action is '$Action'" -Level "Error"
        Write-LogOutput "Usage: .\logger.ps1 -Action $Action -LoggerName 'logger-name'" -Level "Error"
        exit 1
    }
    
    # Get access token
    $accessToken = Get-AccessToken
    
    # Prepare headers
    $headers = @{
        'Authorization' = "Bearer $accessToken"
        'Content-Type' = 'application/json'
        'Accept' = 'application/json'
    }
    
    # Construct the API paths
    $apiVersion = "2024-05-01"
    $baseUri = "https://management.azure.com"
    $resourcePath = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ApiManagement/service/$ServiceName/loggers"
      # Execute the requested action
    switch ($Action) {
        "List" {
            Write-LogOutput "Listing all loggers..."
            $response = Get-ApiManagementLoggers -Headers $headers -BaseUri $baseUri -ResourcePath $resourcePath -ApiVersion $apiVersion
            Format-LoggerOutput -Loggers $response
            Write-LogOutput "Logger list operation completed successfully" -Level "Success"
        }
        
        "Delete" {
            Write-LogOutput "Preparing to delete logger: $LoggerName"
            
            # Confirm deletion
            if (-not (Confirm-DeleteAction -LoggerName $LoggerName)) {
                Write-LogOutput "Delete operation cancelled by user" -Level "Warning"
                exit 0
            }
            
            # Perform deletion
            $deleteResult = Remove-ApiManagementLogger -Headers $headers -BaseUri $baseUri -ResourcePath $resourcePath -LoggerName $LoggerName -ApiVersion $apiVersion
            
            if ($deleteResult) {
                Write-LogOutput "Logger delete operation completed successfully" -Level "Success"
                
                # Optionally list remaining loggers after deletion
                Write-LogOutput "`nListing remaining loggers..."
                $response = Get-ApiManagementLoggers -Headers $headers -BaseUri $baseUri -ResourcePath $resourcePath -ApiVersion $apiVersion
                Format-LoggerOutput -Loggers $response
            }
            else {
                Write-LogOutput "Logger delete operation failed" -Level "Error"
                exit 1
            }
        }
        
        "Create" {
            Write-LogOutput "Preparing to create logger: $LoggerName"
            Write-LogOutput "Logger Type: $LoggerType"
            Write-LogOutput "Instrumentation Key Named Value: $InstrumentationKeyNamedValue"
            
            # Perform creation
            try {
                New-ApiManagementLogger -Headers $headers -BaseUri $baseUri -ResourcePath $resourcePath -LoggerName $LoggerName -LoggerType $LoggerType -InstrumentationKeyNamedValue $InstrumentationKeyNamedValue -Description $Description -ApiVersion $apiVersion | Out-Null
                
                Write-LogOutput "Logger create operation completed successfully" -Level "Success"
                
                # List all loggers after creation to show the new logger
                Write-LogOutput "`nListing all loggers after creation..."
                $response = Get-ApiManagementLoggers -Headers $headers -BaseUri $baseUri -ResourcePath $resourcePath -ApiVersion $apiVersion
                Format-LoggerOutput -Loggers $response
            }
            catch {
                Write-LogOutput "Logger create operation failed" -Level "Error"
                exit 1
            }
        }
    }
}
catch {
    Write-LogOutput "Script execution failed: $_" -Level "Error"
    exit 1
}