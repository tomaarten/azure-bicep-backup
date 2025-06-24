<#
.SYNOPSIS
    Sets up prerequisites for an Azure Automation Account to export Bicep templates to Azure Storage.

.DESCRIPTION
    - Creates an Azure Automation Account with a System-Assigned Managed Identity (if not existing).
    - Assigns required roles to the managed identity:
        - Reader and 'Resource Group template export' on the subscription.
        - 'Storage Blob Data Contributor' on the storage account.
    - Ensures required Az modules are imported into the Automation Account.
    - Installs Bicep CLI on a linked Hybrid Runbook Worker VM (if provided).

.PARAMETER ResourceGroupName
    Name of the resource group where the Automation Account and Storage Account reside.

.PARAMETER AutomationAccountName
    Name of the Automation Account.

.PARAMETER StorageAccountName
    Name of the Storage Account for storing Bicep exports.

.PARAMETER Location
    Azure region (used only if Automation Account needs creation).

.PARAMETER HybridWorkerVMName
    (Optional) Name of linked Hybrid Worker VM (required to install Bicep CLI).

.PARAMETER SubscriptionId
    (Optional) Subscription ID (defaults to current context).
#>

param (
    [Parameter(Mandatory)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory)]
    [string]$AutomationAccountName,

    [Parameter(Mandatory)]
    [string]$StorageAccountName,

    [Parameter(Mandatory)]
    [string]$Location,

    [Parameter()]
    [string]$HybridWorkerVMName,

    [Parameter()]
    [string]$SubscriptionId
)

# Login and set subscription if specified
if ($SubscriptionId) {
    Set-AzContext -SubscriptionId $SubscriptionId
}

# 1. Create Automation Account if not exists
$automation = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -ErrorAction SilentlyContinue
if (-not $automation) {
    Write-Host "Creating Automation Account: $AutomationAccountName"
    $automation = New-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -Location $Location -AssignSystemIdentity
} else {
    Write-Host "Automation Account already exists."
    # Ensure identity is enabled
    if (-not $automation.Identity.PrincipalId) {
        Write-Host "Enabling System-Assigned Managed Identity."
        Update-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -AssignSystemIdentity
        $automation = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName
    }
}

# 2. Assign roles to Managed Identity

$principalId = $automation.Identity.PrincipalId
$automationResourceId = $automation.Id

# Get Storage Account Resource Id
$storage = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
$storageResourceId = $storage.Id

# Assign Reader and 'Resource Group template export' on the subscription
$subId = ($automationResourceId -split "/")[2]
$subscriptionResourceId = "/subscriptions/$subId"
# Reader
New-AzRoleAssignment -ObjectId $principalId -RoleDefinitionName "Reader" -Scope $subscriptionResourceId -ErrorAction SilentlyContinue
# Resource Group template export (built-in role name: "Resource Group template export")
New-AzRoleAssignment -ObjectId $principalId -RoleDefinitionName "Resource Group template export" -Scope $subscriptionResourceId -ErrorAction SilentlyContinue

# Assign Storage Blob Data Contributor on Storage Account
New-AzRoleAssignment -ObjectId $principalId -RoleDefinitionName "Storage Blob Data Contributor" -Scope $storageResourceId -ErrorAction SilentlyContinue

Write-Host "Role assignments complete."

# 3. Import required Az Modules into Automation Account
$requiredModules = @("Az.Accounts", "Az.Resources", "Az.Storage", "Az.Automation")
foreach ($module in $requiredModules) {
    $mod = Get-AzAutomationModule -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name $module -ErrorAction SilentlyContinue
    if (-not $mod) {
        Write-Host "Importing Az module: $module"
        Import-AzAutomationModule -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name $module
    } else {
        Write-Host "Az module already imported: $module"
    }
}

# 4. (Optional) Install Bicep CLI on Hybrid Worker VM
if ($HybridWorkerVMName) {
    Write-Host "Installing Bicep CLI on Hybrid Worker VM: $HybridWorkerVMName"
    # Use Custom Script Extension to install Bicep on Windows VM
    $script = @"
Invoke-WebRequest -Uri https://github.com/Azure/bicep/releases/latest/download/bicep-win-x64.exe -OutFile 'C:\Program Files\bicep\bicep.exe'
$env:Path += ';C:\Program Files\bicep'
[Environment]::SetEnvironmentVariable('Path', $env:Path, [System.EnvironmentVariableTarget]::Machine)
"@
    Set-AzVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $HybridWorkerVMName `
        -Name "InstallBicep" -Location $Location -FileUri "https://raw.githubusercontent.com/tomaarten/azure-bicep-backup/main/automation/Install-Bicep.ps1" `
        -Run "Install-Bicep.ps1"
    Write-Host "Bicep CLI installation triggered. Verify installation on the Hybrid Worker."
} else {
    Write-Host "Hybrid Worker VM not specified. Ensure Bicep CLI is available where runbook is executed."
}

Write-Host "All prerequisites completed."