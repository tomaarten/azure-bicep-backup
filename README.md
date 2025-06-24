# Azure Automation: Scheduled Export of Azure Resources to Bicep in Storage

This repository provides end-to-end automation to export all Azure resources in a subscription as Bicep templates, store them in a structured folder hierarchy in Azure Storage, and keep your infrastructure as code up to date—automatically!

---

## Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Step-by-step Setup](#step-by-step-setup)
    - [1. Clone/download this repository](#1-clonedownload-this-repository)
    - [2. Run the Prerequisites Script](#2-run-the-prerequisites-script)
    - [3. Upload and Publish the Export Runbook](#3-upload-and-publish-the-export-runbook)
    - [4. Create and Link a Schedule](#4-create-and-link-a-schedule)
    - [5. Monitor and Validate the Export](#5-monitor-and-validate-the-export)
5. [Example Configuration](#example-configuration)
6. [Screenshots](#screenshots)
7. [FAQ](#faq)
8. [Troubleshooting](#troubleshooting)
9. [References](#references)

---

## Overview

This solution:
- Creates/configures an Azure Automation Account with a managed identity and all needed permissions.
- Schedules a Runbook to export every resource group/resource as Bicep files daily.
- Saves the exported Bicep files in an Azure Storage account, structured as:
    ```
    /yyyy-MM-dd/resourceGroup/resourceType-resourceName.bicep
    ```
- Ensures you have a repeatable, self-updating Bicep code base for disaster recovery, drift detection, or migration!

---

## Architecture

![Architecture Diagram](https://user-images.githubusercontent.com/123456789/azure-automation-bicep-architecture.png)

1. **Automation Account**: Runs PowerShell Runbook on schedule.
2. **Managed Identity**: Grants necessary permissions to read Azure resources and write to Storage.
3. **Bicep CLI**: Used to decompile ARM templates to Bicep (must be on a Hybrid Worker VM).
4. **Azure Storage**: Stores the exported Bicep files in a dated, logical folder structure.

---

## Prerequisites

- Azure Subscription Owner or User Access Administrator
- Resource Group (or permission to create one)
- Storage Account (blob container created)
- [Az PowerShell module](https://learn.microsoft.com/powershell/azure/install-az-ps) installed locally or use [Azure Cloud Shell](https://shell.azure.com)
- (Optional) Windows VM for Hybrid Worker if using Bicep CLI

---

## Step-by-step Setup

### 1. Clone/download this repository

Download or clone the repo to your local workstation or use the "Download ZIP" button.

---

### 2. Run the Prerequisites Script

This script sets up the Automation Account (if needed), enables its Managed Identity, assigns all required roles, installs required modules, and optionally installs the Bicep CLI on a Hybrid Worker VM.

#### a. Prepare parameters

| Parameter               | Example Value            | Description                                             |
|-------------------------|-------------------------|---------------------------------------------------------|
| ResourceGroupName       | `infra-backup`          | Resource group for Automation/Storage                   |
| AutomationAccountName   | `bicep-backup-automation`| Name for Automation Account                             |
| StorageAccountName      | `bicepbackupstore`      | Name of your Storage Account                            |
| Location                | `westeurope`            | Azure region                                            |
| HybridWorkerVMName      | (opt) `bicepworker01`   | VM name for Hybrid Worker (needs Bicep CLI)             |
| SubscriptionId          | (opt) `xxxx-xxxx...`    | Subscription ID                                         |

#### b. Run the script in Azure Cloud Shell or PowerShell


### First create the Resourcegroup and Storage Account

## ResourceGroup
New-AzResourceGroup -Name infra-backup -Location westeurope

## Storage Account
New-AzStorageAccount -ResourceGroupName infra-backup -Name bicepbackupstore -Location westeurope -SkuName Standard_LRS -Kind StorageV2

## Now run this script 
```powershell
cd automation
.\Setup-AutomationPrereqs.ps1 `
    -ResourceGroupName "infra-backup" `
    -AutomationAccountName "bicep-backup-automation" `
    -StorageAccountName "bicepbackupstore" `
    -Location "westeurope" `
    -HybridWorkerVMName "bicepworker01" `
    -SubscriptionId "xxxx-xxxx-xxxx-xxxx"
```

You will see output similar to:

```
Creating Automation Account: bicep-backup-automation
Assigning Reader role...
Assigning Resource Group template export role...
Assigning Storage Blob Data Contributor role...
Importing Az.Accounts...
Importing Az.Resources...
Importing Az.Storage...
Importing Az.Automation...
Installing Bicep CLI on Hybrid Worker VM: bicepworker01
All prerequisites completed.
```

---

### 3. Upload and Publish the Export Runbook

1. In the Azure Portal, navigate to your **Automation Account** (`bicep-backup-automation`).
2. Go to **Runbooks** > **Create a Runbook**.
3. Name: `Export-Bicep-To-Storage`
4. Runbook Type: `PowerShell`
5. Paste the contents of `Export-Bicep-To-Storage.ps1` (from this repo).
6. Click **Save** then **Publish**.

#### Set Default Parameters

- After publishing, click **Edit** and set default values for:
    - `$SubscriptionId`, `$StorageAccountName`, `$StorageContainerName`
    - (You can also provide these when running/scheduling the Runbook.)

---

### 4. Create and Link a Schedule

1. In your Automation Account, open **Runbooks** and select `Export-Bicep-To-Storage`.
2. Click **Schedules** > **Add a schedule**.
3. Click **Link a schedule to your runbook** > **Create a new schedule**.
    - Name: `DailyExport`
    - Recurrence: Daily, 00:00 (or as needed)
4. In "Parameters", provide values if not set as defaults.
5. Click **Create**.

---

### 5. Monitor and Validate the Export

- After the first scheduled run, check the **Jobs** tab for status and logs.
- Visit your Storage Account’s container to see new folders/files (in `/yyyy-MM-dd/resourceGroup/resourceType-resourceName.bicep` format).
- Download a file to confirm it’s valid Bicep.

---

## Example Configuration

Example parameter values for a test environment:

- ResourceGroupName: `infra-backup`
- AutomationAccountName: `bicep-backup-automation`
- StorageAccountName: `bicepbackupstore`
- StorageContainerName: `backups`
- Location: `westeurope`
- HybridWorkerVMName: `bicepworker01`
- SubscriptionId: `11111111-2222-3333-4444-555555555555`

---

## Screenshots

### 1. Creating a Runbook

![Create Runbook](https://user-images.githubusercontent.com/123456789/azure-create-runbook.png)

### 2. Publishing the Runbook

![Publish Runbook](https://user-images.githubusercontent.com/123456789/azure-publish-runbook.png)

### 3. Linking a Schedule

![Link Schedule](https://user-images.githubusercontent.com/123456789/azure-link-schedule.png)

### 4. Storage Account Structure

![Storage Structure](https://user-images.githubusercontent.com/123456789/azure-storage-structure.png)

---

## FAQ

**Q: Do I need a Hybrid Worker VM?**  
A: Yes, if you want to run the Bicep CLI. The default Azure Automation sandbox does not support custom executables.

**Q: Can I export only certain resource groups?**  
A: Yes, modify the runbook to filter resource groups as needed.

**Q: Are there costs?**  
A: Automation Account, Storage, and (if used) Hybrid Worker VMs may incur small charges.

**Q: Can I store files in a Git repo instead?**  
A: Yes, but you’ll need to adapt the Runbook to use git CLI or REST API.

---

## Troubleshooting

- **Permissions**: Role assignments can take several minutes to propagate.
- **Modules**: If Az modules are missing in Automation, import them manually.
- **Bicep CLI**: Confirm the CLI is installed and in the path on your Hybrid Worker.
- **Runbook errors**: Check the Job logs in the Automation Account for details.

---

## References

- [Azure Automation Docs](https://learn.microsoft.com/azure/automation/)
- [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Export-AzResourceGroup](https://learn.microsoft.com/powershell/module/az.resources/export-azresourcegroup)
- [Set-AzStorageBlobContent](https://learn.microsoft.com/powershell/module/az.storage/set-azstorageblobcontent)

---

> For questions or improvements, open an issue or PR in this repository!
