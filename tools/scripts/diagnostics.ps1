# Azure API Management Diagnostics Management Script
# This script lists and deletes diagnostics for an Azure API Management service using the REST API
# References: 
# - List: https://learn.microsoft.com/en-us/rest/api/apimanagement/diagnostic/list-by-service?view=rest-apimanagement-2024-05-01&tabs=HTTP
# - Delete: https://learn.microsoft.com/en-us/rest/api/apimanagement/diagnostic/delete?view=rest-apimanagement-2024-05-01&tabs=HTTP

param(
    [Parameter(Mandatory = $false)]
    [string]$ServiceName = "apiops-dev-eastus",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "RG-UmeshPagar",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = "14688d65-0570-4508-a201-955fbc8abe06",
    
    [Parameter(Mandatory = $false)]
    [string]$Action = "List",  # Options: "List", "Delete"
    
    [Parameter(Mandatory = $false)]
    [string]$DiagnosticName = "",  # Required when Action is "Delete"
    
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

# Function to show help information
function Show-Help {
    Write-Host @"

Azure API Management Diagnostics Management Script
================================================

This script allows you to list and delete diagnostics configurations in an Azure API Management service.

SYNTAX:
    .\diagnostics.ps1 [[-ServiceName] <String>] [[-ResourceGroupName] <String>] 
                      [[-SubscriptionId] <String>] [[-Action] <String>] 
                      [[-DiagnosticName] <String>] [-Force] [-Help]

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
        The action to perform. Valid values: "List", "Delete"
        Default: "List"
        
    -DiagnosticName <String>
        The name of the diagnostic to delete (required when Action is "Delete").
        
    -Force
        Skip confirmation prompts when deleting diagnostics.
        
    -Help
        Display this help information.

EXAMPLES:
    # List all diagnostics
    .\diagnostics.ps1
    .\diagnostics.ps1 -Action List
    
    # Delete a specific diagnostic with confirmation
    .\diagnostics.ps1 -Action Delete -DiagnosticName "applicationinsights"
    
    # Delete a diagnostic without confirmation
    .\diagnostics.ps1 -Action Delete -DiagnosticName "azuremonitor" -Force
    
    # Use with different service parameters
    .\diagnostics.ps1 -ServiceName "my-apim" -ResourceGroupName "my-rg" -SubscriptionId "my-sub-id"

NOTES:
    - You must be authenticated with Azure CLI (az login) before running this script.
    - The script uses the Azure REST API version 2024-05-01.
    - Diagnostics are used to configure logging and monitoring for API Management operations.
    - Common diagnostic names include: applicationinsights, azuremonitor

"@ -ForegroundColor Cyan
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

# Function to format and display diagnostic information
function Format-DiagnosticOutput {
    param([object]$Diagnostics)
    
    if (-not $Diagnostics.value -or $Diagnostics.value.Count -eq 0) {
        Write-LogOutput "No diagnostics found in the API Management service." -Level "Warning"
        return
    }
    
    Write-LogOutput "Found $($Diagnostics.value.Count) diagnostic(s):" -Level "Success"
    Write-Host "`n" -NoNewline
    
    # Create a formatted table
    $diagnosticData = @()
    foreach ($diagnostic in $Diagnostics.value) {
        $diagnosticData += [PSCustomObject]@{
            Name = $diagnostic.name
            LoggerId = $diagnostic.properties.loggerId
            AlwaysLog = $diagnostic.properties.alwaysLog
            HttpCorrelationProtocol = $diagnostic.properties.httpCorrelationProtocol
            LogClientIp = $diagnostic.properties.logClientIp
        }
    }
    
    $diagnosticData | Format-Table -AutoSize
    
    # Display detailed information for each diagnostic
    Write-Host "`nDetailed Diagnostic Information:" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    
    foreach ($diagnostic in $Diagnostics.value) {
        Write-Host "`nDiagnostic: $($diagnostic.name)" -ForegroundColor Yellow
        Write-Host "  Logger ID: $($diagnostic.properties.loggerId)"
        Write-Host "  Always Log: $($diagnostic.properties.alwaysLog)"
        Write-Host "  HTTP Correlation Protocol: $($diagnostic.properties.httpCorrelationProtocol)"
        Write-Host "  Log Client IP: $($diagnostic.properties.logClientIp)"
        Write-Host "  Verbosity: $($diagnostic.properties.verbosity)"
        Write-Host "  Sampling Type: $($diagnostic.properties.sampling.samplingType)"
        Write-Host "  Sampling Percentage: $($diagnostic.properties.sampling.percentage)"
        
        # Display frontend configuration
        if ($diagnostic.properties.frontend) {
            Write-Host "  Frontend Configuration:" -ForegroundColor Green
            Write-Host "    Request - Headers to Log: $($diagnostic.properties.frontend.request.headers -join ', ')"
            Write-Host "    Request - Body Bytes: $($diagnostic.properties.frontend.request.body.bytes)"
            Write-Host "    Response - Headers to Log: $($diagnostic.properties.frontend.response.headers -join ', ')"
            Write-Host "    Response - Body Bytes: $($diagnostic.properties.frontend.response.body.bytes)"
        }
        
        # Display backend configuration
        if ($diagnostic.properties.backend) {
            Write-Host "  Backend Configuration:" -ForegroundColor Green
            Write-Host "    Request - Headers to Log: $($diagnostic.properties.backend.request.headers -join ', ')"
            Write-Host "    Request - Body Bytes: $($diagnostic.properties.backend.request.body.bytes)"
            Write-Host "    Response - Headers to Log: $($diagnostic.properties.backend.response.headers -join ', ')"
            Write-Host "    Response - Body Bytes: $($diagnostic.properties.backend.response.body.bytes)"
        }
        
        # Display operation name filter if present
        if ($diagnostic.properties.operationNameFormat) {
            Write-Host "  Operation Name Format: $($diagnostic.properties.operationNameFormat)"
        }
        
        # Display metrics configuration
        if ($diagnostic.properties.metrics) {
            Write-Host "  Metrics Enabled: $($diagnostic.properties.metrics)"
        }
    }
}

# Function to list all diagnostics
function Get-ApiManagementDiagnostics {
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

# Function to delete a specific diagnostic
function Remove-ApiManagementDiagnostic {
    param(
        [hashtable]$Headers,
        [string]$BaseUri,
        [string]$ResourcePath,
        [string]$DiagnosticName,
        [string]$ApiVersion,
        [string]$IfMatch = "*"
    )
    
    # Construct the delete URI
    $deleteUri = "$BaseUri$ResourcePath/$DiagnosticName" + "?api-version=$ApiVersion"
    
    # Add If-Match header for delete operation (required by API)
    $deleteHeaders = $Headers.Clone()
    $deleteHeaders['If-Match'] = $IfMatch
    
    try {
        Write-LogOutput "Attempting to delete diagnostic: $DiagnosticName"
        Invoke-ApiRequest -Uri $deleteUri -Headers $deleteHeaders -Method "DELETE" | Out-Null
        Write-LogOutput "Diagnostic '$DiagnosticName' deleted successfully" -Level "Success"
        return $true
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
        
        if ($statusCode -eq 404) {
            Write-LogOutput "Diagnostic '$DiagnosticName' not found (404)" -Level "Warning"
        }
        elseif ($statusCode -eq 400) {
            Write-LogOutput "Bad Request (400). The diagnostic may be a built-in diagnostic that cannot be deleted." -Level "Error"
            if ($errorBody) {
                Write-LogOutput "Error details: $errorBody" -Level "Error"
            }
        }
        elseif ($statusCode -eq 412) {
            Write-LogOutput "Precondition failed (412). The diagnostic may have been modified. Try again." -Level "Error"
        }
        else {
            Write-LogOutput "Failed to delete diagnostic '$DiagnosticName': $($_.Exception.Message)" -Level "Error"
            if ($errorBody) {
                Write-LogOutput "Error details: $errorBody" -Level "Error"
            }
        }
        return $false
    }
}

# Function to confirm delete action
function Confirm-DeleteAction {
    param([string]$DiagnosticName)
    
    if ($Force) {
        return $true
    }
    
    Write-Host "`nWARNING: You are about to delete the diagnostic '$DiagnosticName'." -ForegroundColor Red
    Write-Host "This action cannot be undone and will remove all logging configuration for this diagnostic." -ForegroundColor Red
    
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
    
    Write-LogOutput "Starting Azure API Management Diagnostics $Action Operation"
    Write-LogOutput "Service: $ServiceName"
    Write-LogOutput "Resource Group: $ResourceGroupName"
    Write-LogOutput "Subscription: $SubscriptionId"
    
    # Validate action parameter
    if ($Action -notin @("List", "Delete")) {
        Write-LogOutput "Invalid action '$Action'. Valid actions are: List, Delete" -Level "Error"
        exit 1
    }
    
    # Validate diagnostic name for delete operation
    if ($Action -eq "Delete" -and [string]::IsNullOrWhiteSpace($DiagnosticName)) {
        Write-LogOutput "DiagnosticName parameter is required when Action is 'Delete'" -Level "Error"
        Write-LogOutput "Usage: .\diagnostics.ps1 -Action Delete -DiagnosticName 'diagnostic-name'" -Level "Error"
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
    $resourcePath = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ApiManagement/service/$ServiceName/diagnostics"
    
    # Execute the requested action
    switch ($Action) {
        "List" {
            Write-LogOutput "Listing all diagnostics..."
            Write-LogOutput "API URL: $baseUri$resourcePath" + "?api-version=$apiVersion"
            $response = Get-ApiManagementDiagnostics -Headers $headers -BaseUri $baseUri -ResourcePath $resourcePath -ApiVersion $apiVersion
            Format-DiagnosticOutput -Diagnostics $response
            Write-LogOutput "Diagnostics list operation completed successfully" -Level "Success"
        }
        
        "Delete" {
            Write-LogOutput "Preparing to delete diagnostic: $DiagnosticName"
            
            # Confirm deletion
            if (-not (Confirm-DeleteAction -DiagnosticName $DiagnosticName)) {
                Write-LogOutput "Delete operation cancelled by user" -Level "Warning"
                exit 0
            }
            
            # Perform deletion
            $deleteResult = Remove-ApiManagementDiagnostic -Headers $headers -BaseUri $baseUri -ResourcePath $resourcePath -DiagnosticName $DiagnosticName -ApiVersion $apiVersion
            
            if ($deleteResult) {
                Write-LogOutput "Diagnostic delete operation completed successfully" -Level "Success"
                
                # Optionally list remaining diagnostics after deletion
                Write-LogOutput "`nListing remaining diagnostics..."
                $response = Get-ApiManagementDiagnostics -Headers $headers -BaseUri $baseUri -ResourcePath $resourcePath -ApiVersion $apiVersion
                Format-DiagnosticOutput -Diagnostics $response
            }
            else {
                Write-LogOutput "Diagnostic delete operation failed" -Level "Error"
                exit 1
            }
        }
    }
}
catch {
    Write-LogOutput "Script execution failed: $_" -Level "Error"
    exit 1
}
