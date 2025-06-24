# Azure Automation: Export Subscription Resources as Bicep

## Overview

This Automation Runbook exports all resources in all resource groups of a subscription, decompiles them to Bicep, and saves them to an Azure Storage account in a dated, hierarchical folder structure.

## Folder Structure in Storage

```
/{yyyy-MM-dd}/{resourceGroup}/{resourceType-resourceName}.bicep
```

## Prerequisites

- Azure Automation Account with a System-Assigned Managed Identity.
- The Managed Identity must have:
  - Reader and Export Template permissions on the subscription.
  - Storage Blob Data Contributor on the Storage Account.
- The Automation Account must have the Az modules and Bicep CLI installed.

## Usage

1. Update parameters in `Export-Bicep-To-Storage.ps1`:
   - SubscriptionId
   - StorageAccountName
   - StorageContainerName

2. Import the script as a PowerShell Runbook.

3. Schedule the runbook to run daily.

4. Files will appear in the specified storage account under the structure described above.

## Notes

- The script assumes that Bicep CLI is available on the Hybrid Worker or Automation Sandbox (consider a Hybrid Worker for custom tools).
- You may need to adapt `$resource.ResourceId` for complex resources.