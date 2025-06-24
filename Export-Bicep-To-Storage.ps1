param(
    [string] $SubscriptionId = "<YOUR_SUBSCRIPTION_ID>",
    [string] $StorageAccountName = "<YOUR_STORAGE_ACCOUNT_NAME>",
    [string] $StorageContainerName = "<YOUR_CONTAINER_NAME>"
)

# Login with Managed Identity or Automation Connection
Connect-AzAccount -Identity
Select-AzSubscription -SubscriptionId $SubscriptionId

# Date folder in yyyy-MM-dd format
$dateFolder = (Get-Date -Format 'yyyy-MM-dd')

# Get Storage Context
$storageAccount = Get-AzStorageAccount -Name $StorageAccountName
$ctx = $storageAccount.Context

# Get all resource groups
$resourceGroups = Get-AzResourceGroup

foreach ($rg in $resourceGroups) {
    $rgName = $rg.ResourceGroupName
    $resources = Get-AzResource -ResourceGroupName $rgName

    foreach ($resource in $resources) {
        $resName = $resource.Name
        $resType = $resource.ResourceType
        $safeResType = $resType -replace '/', '-'

        # Export the resource as an ARM template
        $export = Export-AzResourceGroup -ResourceGroupName $rgName -Resource $resource.ResourceId -Force
        $templatePath = $export.TemplateFile

        # Prepare output paths
        $bicepFolder = "$dateFolder/$rgName"
        $bicepFileName = "$safeResType-$resName.bicep"
        $bicepFilePath = "$bicepFolder/$bicepFileName"

        # Convert ARM JSON to Bicep using Bicep CLI
        $bicepTempFile = [System.IO.Path]::GetTempFileName() + ".bicep"
        bicep decompile $templatePath --outfile $bicepTempFile

        # Upload to Azure Storage
        Set-AzStorageBlobContent -File $bicepTempFile -Container $StorageContainerName -Blob $bicepFilePath -Context $ctx | Out-Null

        # Cleanup temp files
        Remove-Item $templatePath -Force
        Remove-Item $bicepTempFile -Force
    }
}