##################################################################
#                                                                #
#   Setup Script                                                 #
#                                                                #
#   Spins up azure resources for RPA solution using MS Services. #
##################################################################


#----------------------------------------------------------------#
#   Parameters                                                   #
#----------------------------------------------------------------#
param (
    [Parameter(Mandatory=$true)]
    [string]$uniqueName = "default", 
    [string]$subscriptionId = "default",
    [string]$location = "default",
	[string]$resourceGroupName = "default"
)
$formsTraining = 'true'
$customVisionTraining = 'true'
$luisTraining = 'true'
$cognitiveSearch = 'true'
$deployWebUi = 'true'

if($uniqueName -eq "default")
{
    Write-Error "Please specify a unique name."
    break;
}

if($uniqueName.Length -gt 17)
{
    Write-Error "The unique name is too long. Please specify a name with less than 17 characters."
}

if($uniqueName -Match "-")
{
	Write-Error "The unique name should not contain special characters"
}

if($location -eq "default")
{
	while ($TRUE) {
		try {
			$location = Read-Host -Prompt "Input Location(westus, eastus, centralus, southcentralus): "
			break  
		}
		catch {
				Write-Error "Please specify a resource group name."
		}
	}
}

Function Pause ($Message = "Press any key to continue...") {
   # Check if running in PowerShell ISE
   If ($psISE) {
      # "ReadKey" not supported in PowerShell ISE.
      # Show MessageBox UI
      $Shell = New-Object -ComObject "WScript.Shell"
      Return
   }
 
   $Ignore =
      16,  # Shift (left or right)
      17,  # Ctrl (left or right)
      18,  # Alt (left or right)
      20,  # Caps lock
      91,  # Windows key (left)
      92,  # Windows key (right)
      93,  # Menu key
      144, # Num lock
      145, # Scroll lock
      166, # Back
      167, # Forward
      168, # Refresh
      169, # Stop
      170, # Search
      171, # Favorites
      172, # Start/Home
      173, # Mute
      174, # Volume Down
      175, # Volume Up
      176, # Next Track
      177, # Previous Track
      178, # Stop Media
      179, # Play
      180, # Mail
      181, # Select Media
      182, # Application 1
      183  # Application 2
 
   Write-Host -NoNewline $Message -ForegroundColor Red
   While ($Null -eq $KeyInfo.VirtualKeyCode  -Or $Ignore -Contains $KeyInfo.VirtualKeyCode) {
      $KeyInfo = $Host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown")
   }
}

$uniqueName = $uniqueName.ToLower();

# prefixes
$prefix = $uniqueName

if ( $resourceGroupName -eq 'default' ) {
	$resourceGroupName = $prefix
}

#$ScriptRoot = "C:\Projects\Repos\msrpa\deploy\scripts"
$outArray = New-Object System.Collections.ArrayList($null)

if ($ScriptRoot -eq "" -or $null -eq $ScriptRoot ) {
	$ScriptRoot = (Get-Location).path
}

$outArray.Add("v_prefix=$prefix")
$outArray.Add("v_resourceGroupName=$resourceGroupName")
$outArray.Add("v_location=$location")

#----------------------------------------------------------------#
#   Setup - Azure Subscription Login							 #
#----------------------------------------------------------------#
$ErrorActionPreference = "Stop"
#Install-Module AzTable -Force

# Sign In
Write-Host Logging in... -ForegroundColor Green
Connect-AzAccount

if($subscriptionId -eq "default"){
	# Set Subscription Id
	while ($TRUE) {
		try {
			$subscriptionId = Read-Host -Prompt "Input subscription Id"
			break  
		}
		catch {
			Write-Host Invalid subscription Id. -ForegroundColor Green `n
		}
	}
}

$outArray.Add("v_subscriptionId=$subscriptionId")
$context = Get-AzSubscription -SubscriptionId $subscriptionId
Set-AzContext @context

Enable-AzContextAutosave -Scope CurrentUser
$index = 0
$numbers = "123456789"
foreach ($char in $subscriptionId.ToCharArray()) {
    if ($numbers.Contains($char)) {
        break;
    }
    $index++
}
$id = $subscriptionId.Substring($index, $index + 5)


#----------------------------------------------------------------#
#   Step 1 - Register Resource Providers and Resource Group		 #
#----------------------------------------------------------------#

$resourceProviders = @(
    "microsoft.documentdb",
    "microsoft.insights",
    "microsoft.search",
    "microsoft.sql",
    "microsoft.storage",
    "microsoft.logic",
    "microsoft.web",
	"microsoft.eventgrid"
)
	
Write-Host Registering resource providers: -ForegroundColor Green`n 
foreach ($resourceProvider in $resourceProviders) {
    Write-Host - Registering $resourceProvider -ForegroundColor Green
	Register-AzResourceProvider `
            -ProviderNamespace $resourceProvider
}

# Create Resource Group 
Write-Host `nCreating Resource Group $resourceGroupName"..." -ForegroundColor Green `n
try {
		Get-AzResourceGroup `
			-Name $resourceGroupName `
			-Location $location `
	}
catch {
		New-AzResourceGroup `
			-Name $resourceGroupName `
			-Location $location `
			-Force
	}

#----------------------------------------------------------------#
#   Step 2 - Storage Account & Containers						 #
#----------------------------------------------------------------#
# Create Storage Account
# storage resources
#$storageAccountName = $prefix + $id + "stor";
$storageAccountName = $prefix + "sa";
$storageContainerFormsPdf = "formspdf"
$storageContainerFormsPdfProcessed = "formspdfprocessed"
$storageContainerFormsImages = "formsimages"
$storageContainerProcessForms = "processforms"

$outArray.Add("v_storageAccountName=$storageAccountName")
$outArray.Add("v_storageContainerFormsPdf=$storageContainerFormsPdf")
$outArray.Add("v_storageContainerFormsPdfProcessed=$storageContainerFormsPdfProcessed")
$outArray.Add("v_storageContainerFormsImages=$storageContainerFormsImages")
$outArray.Add("v_storageContainerProcessForms=$storageContainerProcessForms")

Write-Host Creating storage account... -ForegroundColor Green

try {
        $storageAccount = Get-AzStorageAccount `
            -ResourceGroupName $resourceGroupName `
            -AccountName $storageAccountName
    }
    catch {
        $storageAccount = New-AzStorageAccount `
            -AccountName $storageAccountName `
            -ResourceGroupName $resourceGroupName `
            -Location $location `
            -SkuName Standard_LRS `
            -Kind StorageV2 
    }
$storageAccount
$storageContext = $storageAccount.Context
Start-Sleep -s 1

Enable-AzStorageStaticWebsite `
	-Context $storageContext `
	-IndexDocument "index.html" `
	-ErrorDocument404Path "error.html"

$CorsRules = (@{
		AllowedHeaders  = @("*");
		AllowedOrigins  = @("*");
		MaxAgeInSeconds = 0;
		AllowedMethods  = @("Get", "Put", "Post");
		ExposedHeaders  = @("*");
	})
Set-AzStorageCORSRule -ServiceType Blob -CorsRules $CorsRules -Context $storageContext


# Create Storage Containers
Write-Host Creating blob containers... -ForegroundColor Green
$storageContainerNames = @($storageContainerFormsPdf, $storageContainerFormsPdfProcessed, $storageContainerFormsImages, $storageContainerProcessForms)
foreach ($containerName in $storageContainerNames) {
	 $storageAccount = Get-AzStorageAccount `
            -ResourceGroupName $resourceGroupName `
            -Name $storageAccountName
        $storageContext = $storageAccount.Context
        try {
            Get-AzStorageContainer `
                -Name $containerName `
                -Context $storageContext
        }
        catch {
            new-AzStoragecontainer `
                -Name $containerName `
                -Context $storageContext `
                -Permission container
        }
}

# Get Account Key and connection string
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $storageAccountName).Value[0]
$storageAccountConnectionString = 'DefaultEndpointsProtocol=https;AccountName=' + $storageAccountName + ';AccountKey=' + $storageAccountKey + ';EndpointSuffix=core.windows.net' 

$outArray.Add("v_storageAccountKey=$storageAccountKey")
$outArray.Add("v_storageAccountConnectionString=$storageAccountConnectionString")

#----------------------------------------------------------------#
#   Step 3 - Cognitive Services									 #
#----------------------------------------------------------------#
# Create Form Recognizer Account

# cognitive services resources
#$formRecognizerName = $prefix + $id + "formreco"
$formRecognizerName = $prefix + "frcs"
$outArray.Add("v_formRecognizerName=$formRecognizerName")

Write-Host Creating Form Recognizer service... -ForegroundColor Green

try
{
	Get-AzCognitiveServicesAccount `
	-ResourceGroupName $resourceGroupName `
	-Name $formRecognizerName
}
catch
{
	New-AzCognitiveServicesAccount `
			-ResourceGroupName $resourceGroupName `
			-Name $formRecognizerName `
			-Type FormRecognizer `
			-SkuName S0 `
			-Location $location
}
# Get Key and Endpoint
$formRecognizerEndpoint =  (Get-AzCognitiveServicesAccount -ResourceGroupName $resourceGroupName -Name $formRecognizerName).Endpoint		
$formRecognizerSubscriptionKey =  (Get-AzCognitiveServicesAccountKey -ResourceGroupName $resourceGroupName -Name $formRecognizerName).Key1		
$outArray.Add("v_formRecognizerEndpoint=$formRecognizerEndpoint")
$outArray.Add("v_formRecognizerSubscriptionKey=$formRecognizerSubscriptionKey")


# Create Cognitive Services ( All in one )
#$cognitiveServicesName = $prefix + $id + "cogsvc"
$cognitiveServicesName = $prefix + "cs"
$outArray.Add("v_cognitiveServicesName=$cognitiveServicesName")

$luisAuthoringName = $prefix + "lacs"
$outArray.Add("v_luisAuthoringName=$luisAuthoringName")
Write-Host Creating Luis Authoring Service... -ForegroundColor Green

try
{
	Get-AzCognitiveServicesAccount `
	-ResourceGroupName $resourceGroupName `
	-Name $luisAuthoringName
}
catch
{
	New-AzCognitiveServicesAccount `
			-ResourceGroupName $resourceGroupName `
			-Name $luisAuthoringName `
			-Type LUIS.Authoring `
			-SkuName F0 `
			-Location 'westus'
}
# Get Key and Endpoint
$luisAuthoringEndpoint =  (Get-AzCognitiveServicesAccount -ResourceGroupName $resourceGroupName -Name $luisAuthoringName).Endpoint		
$luisAuthoringSubscriptionKey =  (Get-AzCognitiveServicesAccountKey -ResourceGroupName $resourceGroupName -Name $luisAuthoringName).Key1		
$outArray.Add("v_luisAuthoringEndpoint=$luisAuthoringEndpoint")
$outArray.Add("v_luisAuthoringSubscriptionKey=$luisAuthoringSubscriptionKey")


# Create Cognitive Services ( All in one )
#$cognitiveServicesName = $prefix + $id + "cogsvc"
$cognitiveServicesName = $prefix + "cs"
$outArray.Add("v_cognitiveServicesName=$cognitiveServicesName")

Write-Host Creating Cognitive service... -ForegroundColor Green

try
{
	Get-AzCognitiveServicesAccount `
	-ResourceGroupName $resourceGroupName `
	-Name $cognitiveServicesName
}
catch
{
	New-AzCognitiveServicesAccount `
			-ResourceGroupName $resourceGroupName `
			-Name $cognitiveServicesName `
			-Type CognitiveServices `
			-SkuName S0 `
			-Location $location
}

# Get Key and Endpoint
$cognitiveServicesEndpoint =  (Get-AzCognitiveServicesAccount -ResourceGroupName $resourceGroupName -Name $cognitiveServicesName).Endpoint		
$cognitiveServicesSubscriptionKey =  (Get-AzCognitiveServicesAccountKey -ResourceGroupName $resourceGroupName -Name $cognitiveServicesName).Key1		
$outArray.Add("v_cognitiveServicesEndpoint=$cognitiveServicesEndpoint")
$outArray.Add("v_cognitiveServicesSubscriptionKey=$cognitiveServicesSubscriptionKey")

# Create Custom Vision Training Cognitive service
#$customVisionTrain = $prefix + $id + "cvtrain"
$customVisionTrain = $prefix + "cvtraincs"
$outArray.Add("v_customVisionTrain=$customVisionTrain")

Write-Host Creating Cognitive service Custom Vision Training ... -ForegroundColor Green

try
{
	Get-AzCognitiveServicesAccount `
	-ResourceGroupName $resourceGroupName `
	-Name $customVisionTrain
}
catch
{
	New-AzCognitiveServicesAccount `
			-ResourceGroupName $resourceGroupName `
			-Name $customVisionTrain `
			-Type CustomVision.Training `
			-SkuName S0 `
			-Location $location
}
# Get Key and Endpoint
$customVisionTrainEndpoint =  (Get-AzCognitiveServicesAccount -ResourceGroupName $resourceGroupName -Name $customVisionTrain).Endpoint		
$customVisionTrainSubscriptionKey =  (Get-AzCognitiveServicesAccountKey -ResourceGroupName $resourceGroupName -Name $customVisionTrain).Key1		
$outArray.Add("v_customVisionTrainEndpoint=$customVisionTrainEndpoint")
$outArray.Add("v_customVisionTrainSubscriptionKey=$customVisionTrainSubscriptionKey")

# Create Custom Vision Prediction Cognitive service
#$customVisionPredict = $prefix + $id + "cvpredict"
$customVisionPredict = $prefix + "cvpredictcs"
$outArray.Add("v_customVisionPredict=$customVisionPredict")

Write-Host Creating Cognitive service Custom Vision Prediction ... -ForegroundColor Green

try
{
	Get-AzCognitiveServicesAccount `
	-ResourceGroupName $resourceGroupName `
	-Name $customVisionPredict
}
catch
{
	New-AzCognitiveServicesAccount `
			-ResourceGroupName $resourceGroupName `
			-Name $customVisionPredict `
			-Type CustomVision.Prediction `
			-SkuName S0 `
			-Location $location
}

# Get Key and Endpoint
$customVisionPredictEndpoint =  (Get-AzCognitiveServicesAccount -ResourceGroupName $resourceGroupName -Name $customVisionPredict).Endpoint		
$customVisionPredictSubscriptionKey =  (Get-AzCognitiveServicesAccountKey -ResourceGroupName $resourceGroupName -Name $customVisionPredict).Key1		
$outArray.Add("v_customVisionPredictEndpoint=$customVisionPredictEndpoint")
$outArray.Add("v_customVisionPredictSubscriptionKey=$customVisionPredictSubscriptionKey")
		
#----------------------------------------------------------------#
#   Step 4 - App Service Plan 									 #
#----------------------------------------------------------------#

# Create App Service Plan
Write-Host Creating app service plan... -ForegroundColor Green
# app service plan
#$appServicePlanName = $prefix +$id + "asp"
$appServicePlanName = $prefix + "asp"
$outArray.Add("v_appServicePlanName=$appServicePlanName")

#az functionapp create -g $resourceGroupName -n $appServicePlanName -s $storageAccountName -c $location

$currentApsName = Get-AzAppServicePlan -Name $appServicePlanName -ResourceGroupName $resourceGroupName
if ($currentApsName.Name -eq $null ) {
	New-AzAppServicePlan `
        -Name $appServicePlanName `
        -Location $location `
        -ResourceGroupName $resourceGroupName `
        -Tier Basic
}

#----------------------------------------------------------------#
#   Step 5 - Azure Search Service								 #
#----------------------------------------------------------------#
# Create Cognitive Search Service
Write-Host Creating Cognitive Search Service... -ForegroundColor Green
#$cognitiveSearchName = $prefix + $id + "azsearch"
$cognitiveSearchName = $prefix + "azs"
$outArray.Add("v_cognitiveSearchName=$cognitiveSearchName")

$currentAzSearchName = Get-AzSearchService -ResourceGroupName $resourceGroupName -Name $cognitiveSearchName
if ($null -eq $currentAzSearchName.Name) {
	New-AzSearchService `
			-ResourceGroupName $resourceGroupName `
			-Name $cognitiveSearchName `
			-Sku "Basic" `
			-Location $location
}

$cognitiveSearchKey = (Get-AzSearchAdminKeyPair -ResourceGroupName $resourceGroupName -ServiceName $cognitiveSearchName).Primary
$cognitiveSearchEndPoint = 'https://' + $cognitiveSearchName + '.search.windows.net'
$outArray.Add("v_cognitiveSearchKey=$cognitiveSearchKey")
$outArray.Add("v_cognitiveSearchEndPoint=$cognitiveSearchEndPoint")

#----------------------------------------------------------------#
#   Step 6 - App Insight and Function Storage Account			 #
#----------------------------------------------------------------#
#$appInsightName = $prefix + $id + "appinsight"
$appInsightName = $prefix + "ai"
$outArray.Add("v_appInsightName=$appInsightName")

Write-Host Creating application insight account... -ForegroundColor Green
try
{
	Get-AzApplicationInsights `
	-ResourceGroupName $resourceGroupName `
	-Name $appInsightName
}
catch
{
	New-AzApplicationInsights `
	-ResourceGroupName $resourceGroupName `
	-Name $appInsightName `
	-Location $location `
	-Kind web
}

$appInsightInstrumentationKey = (Get-AzApplicationInsights -ResourceGroupName $resourceGroupName -Name $appInsightName).InstrumentationKey
$outArray.Add("v_appInsightInstrumentationKey=$appInsightInstrumentationKey")


#$funcStorageAccountName = $prefix + $id + "funcstor";
$funcStorageAccountName = $prefix + "funcsa";
$outArray.Add("v_funcStorageAccountName=$funcStorageAccountName")

Write-Host Creating storage account... -ForegroundColor Green

try {
        $funcStorageAccount = Get-AzStorageAccount `
            -ResourceGroupName $resourceGroupName `
            -AccountName $funcStorageAccountName
    }
    catch {
        $funcStorageAccount = New-AzStorageAccount `
            -AccountName $funcStorageAccountName `
            -ResourceGroupName $resourceGroupName `
            -Location $location `
            -SkuName Standard_LRS `
            -Kind StorageV2 
    }

# Get Account Key and connection string
$funcStorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $funcStorageAccountName).Value[0]
#$funcStorageAccountKey = ($funcStorageAccount).Value[0]
$funcStorageAccountConnectionString = 'DefaultEndpointsProtocol=https;AccountName=' + $funcStorageAccountName + ';AccountKey=' + $funcStorageAccountKey + ';EndpointSuffix=core.windows.net' 
$outArray.Add("v_funcStorageAccountKey=$funcStorageAccountKey")
$outArray.Add("v_funcStorageAccountConnectionString=$funcStorageAccountConnectionString")

#----------------------------------------------------------------#
#   Step 7 - CosmosDb account, database and container			 #
#----------------------------------------------------------------#

# cosmos resources
$cosmosAccountName = $prefix + "cdbsql"
$cosmosDatabaseName = "entities"
#$cosmosAccountName = $prefix + $id + "cdbsql"
$cosmosContainer = "formentities"
$outArray.Add("v_cosmosAccountName=$cosmosAccountName")
$outArray.Add("v_cosmosDatabaseName=$cosmosDatabaseName")
$outArray.Add("v_cosmosContainer=$cosmosContainer")

# Create Cosmos SQL API Account
Write-Host Creating CosmosDB account... -ForegroundColor Green
$cosmosLocations = @(
    @{ "locationName" = "East US"; "failoverPriority" = 0 }
)
$consistencyPolicy = @{
    "defaultConsistencyLevel" = "BoundedStaleness";
    "maxIntervalInSeconds"    = 300;
    "maxStalenessPrefix"      = 100000
}
$cosmosProperties = @{
    "databaseAccountOfferType"     = "standard";
    "locations"                    = $cosmosLocations;
    "consistencyPolicy"            = $consistencyPolicy;
    "enableMultipleWriteLocations" = "true"
}

try
{
	Get-AzResource `
        -ResourceType "Microsoft.DocumentDb/databaseAccounts" `
        -ApiVersion "2015-04-08" `
        -ResourceGroupName $resourceGroupName `
        -Name $cosmosAccountName 
}
catch
{		
	New-AzResource `
        -ResourceType "Microsoft.DocumentDb/databaseAccounts" `
        -ApiVersion "2015-04-08" `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -Name $cosmosAccountName `
        -PropertyObject ($cosmosProperties) `
        -Force
}

Start-Sleep -s 10
		
# Create Cosmos Database
Write-Host Creating CosmosDB Database... -ForegroundColor Green
$cosmosDatabaseProperties = @{
    "resource" = @{ "id" = $cosmosDatabaseName };
    "options"  = @{ "Throughput" = 400 }
} 
$cosmosResourceName = $cosmosAccountName + "/sql/" + $cosmosDatabaseName
$currentCosmosDb = Get-AzResource `
        -ResourceType "Microsoft.DocumentDb/databaseAccounts/apis/databases" `
        -ResourceGroupName $resourceGroupName `
        -Name $cosmosResourceName 
		
if ($null -eq $currentCosmosDb.Name) {
	New-AzResource `
        -ResourceType "Microsoft.DocumentDb/databaseAccounts/apis/databases" `
        -ApiVersion "2015-04-08" `
        -ResourceGroupName $resourceGroupName `
        -Name $cosmosResourceName `
        -PropertyObject ($cosmosDatabaseProperties) `
        -Force
}

# Create Cosmos Containers
Write-Host Creating CosmosDB Containers... -ForegroundColor Green
$cosmosContainerNames = @($cosmosContainer)
foreach ($containerName in $cosmosContainerNames) {
    $containerResourceName = $cosmosAccountName + "/sql/" + $cosmosDatabaseName + "/" + $containerName
	 $cosmosContainerProperties = @{
            "resource" = @{
                "id"           = $containerName; 
                "partitionKey" = @{
                    "paths" = @("/FormType"); 
                    "kind"  = "Hash"
                }; 
            };
            "options"  = @{ }
        }
	try 
	{
		Get-AzResource `
				-ResourceType "Microsoft.DocumentDb/databaseAccounts/apis/databases/containers" `
				-ApiVersion "2015-04-08" `
				-ResourceGroupName $resourceGroupName `
				-Name containerResourceName
	}
	catch
	{	
		New-AzResource `
				-ResourceType "Microsoft.DocumentDb/databaseAccounts/apis/databases/containers" `
				-ApiVersion "2015-04-08" `
				-ResourceGroupName $resourceGroupName `
				-Name $containerResourceName `
				-PropertyObject $cosmosContainerProperties `
				-Force 
	}
}

$cosmosEndPoint = (Get-AzResource -ResourceType "Microsoft.DocumentDb/databaseAccounts" `
     -ApiVersion "2015-04-08" -ResourceGroupName $resourceGroupName `
     -Name $cosmosAccountName | Select-Object Properties).Properties.documentEndPoint
$cosmosPrimaryKey = (Invoke-AzResourceAction -Action listKeys `
    -ResourceType "Microsoft.DocumentDb/databaseAccounts" -ApiVersion "2015-04-08" `
    -ResourceGroupName $resourceGroupName -Name $cosmosAccountName -Force).primaryMasterKey
$cosmosConnectionString = (Invoke-AzResourceAction -Action listConnectionStrings `
    -ResourceType "Microsoft.DocumentDb/databaseAccounts" -ApiVersion "2015-04-08" `
    -ResourceGroupName $resourceGroupName -Name $cosmosAccountName -Force).connectionStrings.connectionString[0]
$outArray.Add("v_cosmosEndPoint=$cosmosEndPoint")
$outArray.Add("v_cosmosPrimaryKey=$cosmosPrimaryKey")
$outArray.Add("v_cosmosConnectionString=$cosmosConnectionString")

#----------------------------------------------------------------#
#   Step 8 - Deploy Azure Functions							 	 #
#----------------------------------------------------------------#

# function app
#$functionApppdf = $prefix + $id + "pdf"
#$functionAppbo = $prefix + $id + "bo"
#$functionAppfr = $prefix + $id + "frskill"
#$functionAppcdb = $prefix + $id + "cdbskill"
$functionApppdf = $prefix + "pdfaf"
$functionAppbo = $prefix + "boaf"
$functionAppfr = $prefix + "fraf"
$functionAppcdb = $prefix + "cdbaf"
$functionAppluis = $prefix + "luisaf"
$outArray.Add("v_functionApppdf=$functionApppdf")
$outArray.Add("v_functionAppbo=$functionAppbo")
$outArray.Add("v_functionAppfr=$functionAppfr")
$outArray.Add("v_functionAppcdb=$functionAppcdb")
$outArray.Add("v_functionAppluis=$functionAppluis")

$filePathpdf = "$ScriptRoot\..\functions\msrpapdf.zip"
$filePathbo = "$ScriptRoot\..\functions\msrpabo.zip"
$filePathcdb = "$ScriptRoot\..\functions\msrpacdbskill.zip"
$filePathfr = "$ScriptRoot\..\functions\mrrpafrskill.zip"
$filePathluis = "$ScriptRoot\..\functions\msrpaluisskill.zip"

$outArray.Add("v_filePathpdf=$filePathpdf")
$outArray.Add("v_filePathbo=$filePathbo")
$outArray.Add("v_filePathcdb=$filePathcdb")
$outArray.Add("v_filePathfr=$filePathfr")
$outArray.Add("v_filePathluis=$filePathluis")

$pdf32Bit = $False
$bo32Bit = $True
$fr32Bit = $True
$cdb32Bit = $True
$luis32Bit = $True

$functionKeys = @{ }
$functionKeys.Clear()

# Azure Functions
$functionAppInformation = @(
    ($functionApppdf, $filePathpdf, $pdf32Bit), `
    ($functionAppbo, $filePathbo, $bo32Bit), `
    ($functionAppfr, $filePathfr, $fr32Bit),
	($functionAppcdb, $filePathcdb, $cdb32Bit),
	($functionAppluis, $filePathluis, $luis32Bit))
foreach ($info in $functionAppInformation) {
    $name = $info[0]
    $filepath = $info[1]
	$IsProcess32Bit = $info[2]
    $functionAppSettings = @{
        serverFarmId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Web/serverFarms/$AppServicePlanName";
        alwaysOn     = $True;
    }

    # Create Function App
    Write-Host Creating Function App $name"..." -ForegroundColor Green
	$currentaf = Get-AzResource `
            -ResourceGroupName $resourceGroupName `
            -ResourceName $name 
	 if ( $null -eq $currentAf.Name)
	 {
		 New-AzResource `
				-ResourceGroupName $resourceGroupName `
				-Location $location `
				-ResourceName $name `
				-ResourceType "microsoft.web/sites" `
				-Kind "functionapp" `
				-Properties $functionAppSettings `
				-Force
	}
	
	$functionWebAppSettings = @{
		AzureWebJobsDashboard       = $funcStorageAccountConnectionString;
		AzureWebJobsStorage         = $funcStorageAccountConnectionString;
		FUNCTION_APP_EDIT_MODE      = "readwrite";
		FUNCTIONS_EXTENSION_VERSION = "~2";
		FUNCTIONS_WORKER_RUNTIME    = "dotnet";
		APPINSIGHTS_INSTRUMENTATIONKEY = $appInsightInstrumentationKey;
		EntityTableName = "entities";
		ModelTableName = "modelinformation";
		StorageContainerString = $storageAccountConnectionString;
		CosmosContainer = $cosmosContainer;
		CosmosDbId = $cosmosDatabaseName;
		CosmosKey = $cosmosPrimaryKey;
		CosmosUri = $cosmosEndpoint;
	}
	
	# Configure Function App
	Write-Host Configuring $name"..." -ForegroundColor Green
	Set-AzWebApp `
		-Name $name `
		-ResourceGroupName $resourceGroupName `
		-AppSettings $functionWebAppSettings `
		-Use32BitWorkerProcess $IsProcess32Bit

	# Set 64 Bit to True
	Set-AzWebApp -ResourceGroupName $resourceGroupName -Name $name -Use32BitWorkerProcess $IsProcess32Bit

	# Deploy Function To Function App 
        Write-Host Deploying $name"..." -ForegroundColor Green
        $deploymentCredentials = Invoke-AzResourceAction `
            -ResourceGroupName $resourceGroupName `
            -ResourceType Microsoft.Web/sites/config `
            -ResourceName ($name + "/publishingcredentials") `
            -Action list `
            -ApiVersion 2015-08-01 `
            -Force
	
	$username = $deploymentCredentials.Properties.PublishingUserName
	$password = $deploymentCredentials.Properties.PublishingPassword 
	$apiUrl = "https://$($name).scm.azurewebsites.net/api/zipdeploy"
	# For authenticating to Kudu
	$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $password)))
	$userAgent = "powershell/1.0"
	Invoke-RestMethod `
		-Uri $apiUrl `
		-Headers @{Authorization = ("Basic {0}" -f $base64AuthInfo) } `
		-UserAgent $userAgent `
		-Method POST `
		-InFile $filepath `
		-ContentType "multipart/form-data"
	
	$apiBaseUrl = "https://$($name).scm.azurewebsites.net/api"
	$siteBaseUrl = "https://$($name).azurewebsites.net"

	# Call Kudu /api/functions/admin/token to get a JWT that can be used with the Functions Key API 
	$jwt = Invoke-RestMethod -Uri "$apiBaseUrl/functions/admin/token" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method GET

	# Call Functions Key API to get the default key 
	$defaultKey = Invoke-RestMethod -Uri "$siteBaseUrl/admin/host/functionkeys/default" -Headers @{Authorization=("Bearer {0}" -f $jwt)} -Method GET

	$functionKeys[$name] = $defaultKey.value
	$outArray.Add("$name=$defaultKey.value")

	#Publish-AzWebapp -ResourceGroupName $resourceGroupName -Name $name -ArchivePath $filepath -Force
}

$functionKeys

#----------------------------------------------------------------#
#   Step 9 - Find all forms that needs training and upload		 #
#----------------------------------------------------------------#
if ($formsTraining -eq 'true')
{
	# We currently have two level of "Folders" that we process
	$trainingFormFilePath = "$ScriptRoot\..\formstrain\"
	$outArray.Add("v_trainingFormFilePath=$trainingFormFilePath")

	$trainingFormContainers = New-Object System.Collections.ArrayList($null)
	$trainingFormContainers.Clear()

	$trainingStorageAccountName = $prefix + "frsa"
	$outArray.Add("v_trainingStorageAccountName=$trainingStorageAccountName")

	$folders = Get-ChildItem $trainingFormFilePath
	foreach ($folder in $folders) {
		$subFolders = Get-ChildItem $folder
		foreach ($subFolder in $subFolders) {
			$formContainerName = $folder.Name.toLower() + $subFolder.Name.toLower()
			Write-Host Creating storage account to train forms... -ForegroundColor Green
				try {
					$frStorageAccount = Get-AzStorageAccount `
						-ResourceGroupName $resourceGroupName `
						-AccountName $trainingStorageAccountName
				}
				catch {
					$frStorageAccount = New-AzStorageAccount `
						-AccountName $trainingStorageAccountName `
						-ResourceGroupName $resourceGroupName `
						-Location $location `
						-SkuName Standard_LRS `
						-Kind StorageV2 
				}
				
			Write-Host Create Container $formContainerName	 -ForegroundColor Green		
			$frStorageContext = $frStorageAccount.Context
			try {
				Get-AzStorageContainer `
					-Name $formContainerName `
					-Context $frStorageContext
			}
			catch {
				New-AzStoragecontainer `
					-Name $formContainerName `
					-Context $frStorageContext `
					-Permission container
			}
			$trainingFormContainers.Add($formContainerName)
			$files = Get-ChildItem $subFolder
			foreach($file in $files){
				$filePath = $trainingFormFilePath + $folder.Name + '\' + $subFolder.Name + '\' + $file.Name
				Write-Host Upload File $filePath -ForegroundColor Green
				Set-AzStorageBlobContent `
					-File $filePath `
					-Container $formContainerName `
					-Blob $file.Name `
					-Context $frStorageContext `
					-Force
				
			}
		}
	}
	$trainingFormContainers
}

#----------------------------------------------------------------#
#   Step 10 - Train Form Recognizer Models						 #
#----------------------------------------------------------------#
# Train Form Recognizer
if ($formsTraining -eq 'true')
{
	Write-Host Training Form Recognizer... -ForegroundColor Green
	$formRecognizerTrainUrl = $formRecognizerEndpoint + "formrecognizer/v1.0-preview/custom/train"
	$outArray.Add("v_formRecognizerTrainUrl=$formRecognizerTrainUrl")

	$formRecognizeHeader = @{
		"Ocp-Apim-Subscription-Key" = $formRecognizerSubscriptionKey
	}
	$formRecognizerModels = @{ }
	$formrecognizerModels.Clear()
	foreach ($containerName in $trainingFormContainers) {
			$frStorageAccount = Get-AzStorageAccount `
				-ResourceGroupName $resourceGroupName `
				-Name $trainingStorageAccountName
			$frStorageContext = $frStorageAccount.Context
			$storageContainerUrl = (Get-AzStorageContainer -Context $frStorageContext -Name $containerName).CloudBlobContainer.Uri.AbsoluteUri
			$body = "{`"source`": `"$($storageContainerUrl)`"}"
			$valid = $false
			while ($valid -eq $false)
			{
				try
				{
					$response = Invoke-RestMethod -Method Post -Uri $formRecognizerTrainUrl -ContentType "application/json" -Headers $formRecognizeHeader -Body $body
					$valid = $true
				}
				catch
				{
					$valid = $false
					Start-Sleep -s 30
				}
			}
			$response
			$formRecognizerModels[$containerName] = $response.modelId
			$outArray.Add("$containerName=$response.modelId")
			#return $formRecognizerModels
	}

	$formRecognizerModels
}

#----------------------------------------------------------------#
#   Step 11 - Train LUIS Models						 			 #
#----------------------------------------------------------------#
# Train LUIS
if ($luisTraining -eq 'true')
{
	Write-Host Luis Models... -ForegroundColor Green
	$luisAppImportUrl = $luisAuthoringEndpoint + "luis/api/v2.0/apps/import"
	$outArray.Add("v_luisAppImportUrl=$luisAppImportUrl")

	$luisHeader = @{
		"Ocp-Apim-Subscription-Key" = $luisAuthoringSubscriptionKey
	}
	$luisModels = @{ }
	$luisModels.Clear()

	$trainingLuisFilePath = "$ScriptRoot\..\luistrain\"

	$folders = Get-ChildItem $trainingLuisFilePath
	foreach ($folder in $folders) {
		$luisApplicationName = $folder.Name.toLower()
		Write-Host Creating luis application... -ForegroundColor Green
		#$luisAppBody = "{`"name`": `"$($luisApplicationName)`",`"culture`":`"en-us`"}"
		
		$files = Get-ChildItem $folder
		foreach($file in $files){
			$luisApplicationFilePath = $trainingLuisFilePath + $folder.Name + '\' + $file.Name
			$luisApplicationTemplate = Get-Content $luisApplicationFilePath
			$appVersion = '0.1'
			
			try
			{
				$luisAppResponse = Invoke-RestMethod -Method Post `
							-Uri $luisAppImportUrl -ContentType "application/json" `
							-Headers $luisHeader `
							-Body $luisApplicationTemplate
				$luisAppId = $luisAppResponse
				$luisModels[$luisApplicationName] = $luisAppId

				$luisTrainUrl = $luisAuthoringEndpoint + "luis/api/v2.0/apps/" + $luisAppId + "/versions/" + $appVersion + "/train"
				
				Write-Host Training Luis Models... -ForegroundColor Green
				$luisAppTrainResponse = Invoke-RestMethod -Method Post `
							-Uri $luisTrainUrl `
							-Headers $luisHeader
				
				# Get Training Status
				# For now wait for 10 seconds
				Start-Sleep -s 10
				$luisAppTrainResponse = Invoke-RestMethod -Method Get `
							-Uri $luisTrainUrl `
							-Headers $luisHeader

				$publishJsonBody = "{
					'versionId': '$appVersion',
					'isStaging': false,
					'directVersionPublish': false
				}"

				#Publish the Model
				Write-Host Publish Luis Models... -ForegroundColor Green
				$luisPublihUrl = $luisAuthoringEndpoint + "luis/api/v2.0/apps/" + $luisAppId + "/publish"
				$luisAppPublishResponse = Invoke-RestMethod -Method Post `
							-Uri $luisPublihUrl -ContentType "application/json" `
							-Headers $luisHeader `
							-Body $luisApplicationTemplate
				$luisAppPublishResponse
			}
			catch
			{
			}

		}
		
	}

	$luisModels
}

#----------------------------------------------------------------#
#   Step 12 - Build, Train and Publish Custom Vision Model		 #
#----------------------------------------------------------------#
#$customVisionProjectName = $prefix + $id + "classify"
$customVisionProjectName = $prefix + "cvfclassify"
$outArray.Add("v_customVisionProjectName = $customVisionProjectName")

$customVisionClassificationType = "Multilabel"
$customVisionProjectUrl = $customVisionTrainEndpoint + "customvision/v3.0/training/projects?name=" + $customVisionProjectName + "&classificationType=" + $customVisionClassificationType 
$outArray.Add("v_customVisionProjectUrl = $customVisionProjectUrl")

$customVisionHeader = @{
	"Training-Key" = $customVisionTrainSubscriptionKey
}

if ($customVisionTraining -eq 'true')
{
	$customVisionContainers = New-Object System.Collections.ArrayList($null)
	$customVisionContainers.Clear()

	# Create the Custom vision Project
	$response = Invoke-RestMethod -Method Post -Uri $customVisionProjectUrl -ContentType "application/json" -Headers $customVisionHeader
	$response
	$customVisionProjectId = $response.id
	$outArray.Add("v_customVisionProjectId = $customVisionProjectId")

	# Create Custom Vision Tag - "Yes"
	$YesTagName = 'Yes'
	$custVisionYesTagUrl = $customVisionTrainEndpoint + "customvision/v3.0/training/projects/" + $customVisionProjectId + "/tags?name=" + $YesTagName
	$outArray.Add("v_custVisionYesTagUrl = $custVisionYesTagUrl")

	Write-Host Custom Vision Url $custVisionYesTagUrl -ForegroundColor Green
	$YesTagResponse = Invoke-RestMethod -Method Post -Uri $custVisionYesTagUrl -ContentType "application/json" -Headers $customVisionHeader
	$customVisionYesTagId = $YesTagResponse.id
	$outArray.Add("v_customVisionYesTagId = $customVisionYesTagId")

	$custVisionTrainFilePath = "$ScriptRoot\..\custvisiontrain\"

	# Create Custom Vision Tags
	$cvFolders = Get-ChildItem $custVisionTrainFilePath
	foreach ($folder in $cvFolders) {
		$tagName = $folder.Name.toLower()
		
		# Create Containers
		#Write-Host Create Container $tagName
		#$storageAccount = Get-AzStorageAccount `
		#	-ResourceGroupName $resourceGroupName `
		#	-Name $storageAccountName
		#$storageContext = $storageAccount.Context
		#try {
		#	Get-AzStorageContainer `
		#		-Name $tagName `
		#		-Context $storageContext
		#}
		#catch {
		#	new-AzStoragecontainer `
		#		-Name $tagName `
		#		-Context $storageContext `
		#		-Permission container
		#}
		
		$customVisionContainers.Add($tagName)
		# Create Tags
		Write-Host Create Tag $tagName -ForegroundColor Green
		$custVisionTagUrl = $customVisionTrainEndpoint + "customvision/v3.0/training/projects/" + $customVisionProjectId + "/tags?name=" + $tagName
		Write-Host Custom Vision Url $custVisionTagUrl -ForegroundColor Green
		$tagResponse = Invoke-RestMethod -Method Post -Uri $custVisionTagUrl -ContentType "application/json" -Headers $customVisionHeader
		$customVisionTagId = $tagResponse.id
		$outArray.Add("v_customVisionTagId = $customVisionTagId")

		$cvSubFolders = Get-ChildItem $folder
		foreach ($subFolder in $cvSubFolders) {
			$files = Get-ChildItem $subFolder
			foreach($file in $files){
				$filePath = $custVisionTrainFilePath + $folder.Name + '\' + $subFolder.Name + '\' + $file.Name
				Write-Host Upload File $filePath -ForegroundColor Green
				
				try
				{
					#Encoding to base64-image to be delivered to Custom Vision AI
					$encodedimage = [Convert]::ToBase64String([IO.File]::ReadAllBytes($filePath))
				}
				catch
				{
					Write-Host $Error -ForegroundColor Green
					Write-Warning "base64 encoding failed. Exiting"
					Exit
				}
				
				$jsonBody = "{ 
				  'images': [ 
					{ `
					  'name': '$file.Name', 
					  'contents': '$encodedimage', 
					  'tagIds': ['$customVisionTagId'], 
					  'regions': [] 
					} 
				  ] 
				}"
				
				$multipleTags = "'" + $customVisionTagId + "','" + $customVisionYesTagId + "'"
				$uploadUri = $customVisionTrainEndpoint + "customvision/v3.0/training/projects/" + $customVisionProjectId + "/images?tagIds=[" + $multipleTags + "]"
				Write-Host Upload Uri $uploadUri -ForegroundColor Green

				$properties = @{
					Uri         = $uploadUri
					Headers     = $customVisionHeader
					ContentType = "application/json"
					Method      = "POST"
					Body        = $jsonbody
				}
				$imageFile = Get-ChildItem $filePath
				$uploadResponse = Invoke-RestMethod -Method POST -Uri $uploadUri -ContentType "application/octet-stream" -Headers $customVisionHeader -Infile $imageFile
				#uploadResponse = Invoke-RestMethod @properties
				$imageId = $uploadResponse.images.image.id

				# Associate image with Tag			
				$imageJsonBody = "{ 
				  'tags': [ 
					{ `
					  'imageId': '$imageId', 
					  'tagId': '$customVisionTagId'
					},
					{ `
					  'imageId': '$imageId', 
					  'tagId': '$customVisionYesTagId'
					} 
				  ] 
				}"
				
				$imageTagUri = $customVisionTrainEndpoint + "customvision/v3.0/training/projects/" + $customVisionProjectId + "/images/tags"
				$imageTagResponse = Invoke-RestMethod -Method POST -Uri $imageTagUri -ContentType "application/json" -Headers $customVisionHeader -Body $imageJsonBody
				$imageTagResponse
			}
		}
	}

	Write-Host Train Custom Vision Model -ForegroundColor Green
	# Train Custom Vision Model
	$projectTrainUri = $customVisionTrainEndpoint + "customvision/v3.0/training/projects/" + $customVisionProjectId + "/train?trainingType=Advanced&reservedBudgetInHours=1"
	$outArray.Add("v_projectTrainUri = $projectTrainUri")

	$projectTrainResponse = Invoke-RestMethod -Method POST -Uri $projectTrainUri -ContentType "application/json" -Headers $customVisionHeader
	$trainingIterationId = $projectTrainResponse.id
	$outArray.Add("v_trainingIterationId = $trainingIterationId")

	Write-Host Since we are performing advance train, wait five minutes before publishing iterations -ForegroundColor Green
	# TODO - Check if the training is "Completed" and create loop here before publishing iteration
	Start-Sleep -s 300

	#Unpublish Iteration?
	$validPublish = $false
	while ($validPublish -eq $false)
	{
		try
		{
			# Publish Iteration
			$customVisionResourceId = (Get-AzResource -ResourceGroupName $resourceGroupName -Name $customVisionPredict).ResourceId
			$projectPublishUri = $customVisionTrainEndpoint + "customvision/v3.0/training/projects/" + $customVisionProjectId + "/iterations/" + $trainingIterationId + "/publish?publishName=latest&predictionId=" + $customVisionResourceId
			Write-Host Publish Iteration to $projectPublishUri -ForegroundColor Green
			$projectPublishResponse = Invoke-RestMethod -Method POST -Uri $projectPublishUri -ContentType "application/json" -Headers $customVisionHeader
			$projectPublishResponse
			$validPublish = $true
		}
		catch
		{
			$validPublish = $false
			Start-Sleep -s 30
		}
	}

	# Build Prediction Url
	$projectPredictionUrl = $customVisionTrainEndpoint + "customvision/v3.0/Prediction/" + $customVisionProjectId + "/classify/iterations/latest/url"
	$projectPredictionKey = $customVisionPredictSubscriptionKey
	$outArray.Add("v_projectPredictionUrl = $projectPredictionUrl")
	$outArray.Add("v_projectPredictionKey = $projectPredictionKey")
}
else
{
	# Get Projects
	try
	{
		$customVisioncurrentProjectUrl = $customVisionTrainEndpoint + "customvision/v3.0/training/projects"
		$cvProjectResp = Invoke-RestMethod -Method Get -Uri $customVisioncurrentProjectUrl -ContentType "application/json" -Headers $customVisionHeader

		$prjId = $cvProjectResp | where { $_.name -eq $customVisionProjectName }
		$customVisionProjectId = $prjId.id
	}
	catch
	{
		Write-Host "Exception on getting existing project"
		exit
	}
	
	# Build Prediction Url
	$projectPredictionUrl = $customVisionTrainEndpoint + "customvision/v3.0/Prediction/" + $customVisionProjectId + "/classify/iterations/latest/url"
	$projectPredictionKey = $customVisionPredictSubscriptionKey
	$outArray.Add("v_projectPredictionUrl = $projectPredictionUrl")
	$outArray.Add("v_projectPredictionKey = $projectPredictionKey")
}

#----------------------------------------------------------------#
#   Step 13 - Create API Connection and Deploy Logic app		 #
#----------------------------------------------------------------#
$azureBlobApiConnectionName = $prefix + "blobapi"
$outArray.Add("v_azureBlobApiConnectionName = $azureBlobApiConnectionName")

$azureblobTemplateFilePath = "$ScriptRoot\..\templates\azureblob-template.json"
$azureblobParametersFilePath = "$ScriptRoot\..\templates\azureblob-parameters.json"
$azureblobParametersTemplate = Get-Content $azureblobParametersFilePath | ConvertFrom-Json
$azureblobParameters = $azureblobParametersTemplate.parameters
$azureblobParameters.subscription_id.value = $subscriptionId
$azureblobParameters.storage_account_name.value = $storageAccountName
$azureblobParameters.storage_access_key.value = $storageAccountKey
$azureblobParameters.location.value = $location
$azureblobParameters.connections_azureblob_name.value = $azureBlobApiConnectionName
$azureblobParametersTemplate | ConvertTo-Json | Out-File $azureblobParametersFilePath

Write-Host Deploying $azureBlobApiConnectionName"..." -ForegroundColor Green
New-AzResourceGroupDeployment `
		-ResourceGroupName $resourceGroupName `
		-Name $azureBlobApiConnectionName `
		-TemplateFile $azureblobTemplateFilePath `
		-TemplateParameterFile $azureblobParametersFilePath

Write-Host Deploy azureeventgrid API connection -ForegroundColor Green
$azureEventGridApiConnectionName = $prefix + "aegapi"
$outArray.Add("v_azureEventGridApiConnectionName = $azureEventGridApiConnectionName")

$azureEventGridTemplateFilePath = "$ScriptRoot\..\templates\azureeventgrid-template.json"
$azureEventGridParametersFilePath = "$ScriptRoot\..\templates\azureeventgrid-parameters.json"
$outArray.Add("v_azureEventGridTemplateFilePath = $azureEventGridTemplateFilePath")
$outArray.Add("v_azureEventGridParametersFilePath = $azureEventGridParametersFilePath")

$azureEventGridParametersTemplate = Get-Content $azureEventGridParametersFilePath | ConvertFrom-Json
$azureEventGridParameters = $azureEventGridParametersTemplate.parameters
$azureEventGridParameters.subscription_id.value = $subscriptionId
$azureEventGridParameters.location.value = $location
$azureEventGridParameters.connections_eventgrid_name.value = $azureEventGridApiConnectionName
$azureEventGridParametersTemplate | ConvertTo-Json | Out-File $azureEventGridParametersFilePath

Write-Host Deploying $azureEventGridApiConnectionName"..." -ForegroundColor Green
New-AzResourceGroupDeployment `
		-ResourceGroupName $resourceGroupName `
		-Name $azureEventGridApiConnectionName `
		-TemplateFile $azureEventGridTemplateFilePath `
		-TemplateParameterFile $azureEventGridParametersFilePath

$pauseMessage = 'Go to Azure resource group ' + $resourceGroupName + 'and authorize eventgrid connection, save and continue here'
Pause $pauseMessage

# logic app
$logicAppPdfName = $prefix + "processpdfeg"
$outArray.Add("v_logicAppPdfName = $logicAppPdfName")

$logicAppPdfTemplateFilePath = "$ScriptRoot\..\templates\msrpaprocesspdfeg-template.json"
$logicAppPdfParametersFilePath = "$ScriptRoot\..\templates\msrpaprocesspdfeg-parameters.json"
$outArray.Add("v_logicAppPdfTemplateFilePath = $logicAppPdfTemplateFilePath")
$outArray.Add("v_logicAppPdfParametersFilePath = $logicAppPdfParametersFilePath")

$pdfConverterResourceId = Get-AzResource `
    -ResourceGroupName $resourceGroupName `
    -Name $functionApppdf
$blobOperationResourceId = Get-AzResource `
    -ResourceGroupName $resourceGroupName `
    -Name $functionAppbo
$azureblobResourceid = Get-AzResource `
    -ResourceGroupName $resourceGroupName `
    -Name $azureBlobApiConnectionName
$azureEventGridResourceid = Get-AzResource `
    -ResourceGroupName $resourceGroupName `
    -Name $azureEventGridApiConnectionName
	
$outArray.Add("v_pdfConverterResourceId = $pdfConverterResourceId")
$outArray.Add("v_blobOperationResourceId = $blobOperationResourceId")
$outArray.Add("v_azureblobResourceid = $azureblobResourceid")
$outArray.Add("v_azureEventGridResourceid = $azureEventGridResourceid")
	

$logicAppPdfParametersTemplate = Get-Content $logicAppPdfParametersFilePath | ConvertFrom-Json
$logicAppPdfParameters = $logicAppPdfParametersTemplate.parameters
$logicAppPdfParameters.logic_app_name.value = $logicAppPdfName
$logicAppPdfParameters.subscription_id.value = $subscriptionId
$logicAppPdfParameters.resource_group_name.value = $resourceGroupName
$logicAppPdfParameters.location.value = $location
$logicAppPdfParameters.bo_resource_id.value = $blobOperationResourceId.Id
$logicAppPdfParameters.pdf_resource_id.value = $pdfConverterResourceId.Id
$logicAppPdfParameters.azureblob_resource_id.value = $azureblobResourceid.Id
$logicAppPdfParameters.azureeventgrid_resource_id.value = $azureEventGridResourceid.Id
$logicAppPdfParameters.form_classification_key.value = $projectPredictionKey
$logicAppPdfParameters.form_classification_url.value = $projectPredictionUrl
$logicAppPdfParameters.storage_connection_string.value = $storageAccountConnectionString
$logicAppPdfParameters.storage_url.value = "https://" + $storageAccountName + ".blob.core.windows.net"
$logicAppPdfParameters.storage_name.value = $storageAccountName
$logicAppPdfParametersTemplate | ConvertTo-Json | Out-File $logicAppPdfParametersFilePath

Write-Host Deploying Logic App to Process Pdf ... -ForegroundColor Green
New-AzResourceGroupDeployment `
        -ResourceGroupName $resourceGroupName `
        -Name $logicAppPdfName `
        -TemplateFile $logicAppPdfTemplateFilePath `
        -TemplateParameterFile $logicAppPdfParametersFilePath


Write-Host Deploy office365 API connection -ForegroundColor Green
$office365ApiConnectionName = $prefix + "o365api"
$outArray.Add("v_office365ApiConnectionName = $office365ApiConnectionName")

$office365TemplateFilePath = "$ScriptRoot\..\templates\office365-template.json"
$office365ParametersFilePath = "$ScriptRoot\..\templates\office365-parameters.json"
$outArray.Add("v_office365TemplateFilePath = $office365TemplateFilePath")
$outArray.Add("v_office365ParametersFilePath = $office365ParametersFilePath")

$office365ParametersTemplate = Get-Content $office365ParametersFilePath | ConvertFrom-Json
$office365Parameters = $office365ParametersTemplate.parameters
$office365Parameters.subscription_id.value = $subscriptionId
$office365Parameters.location.value = $location
$office365Parameters.connections_office365_name.value = $office365ApiConnectionName
$office365ParametersTemplate | ConvertTo-Json | Out-File $office365ParametersFilePath

Write-Host Deploying $office365ApiConnectionName"..." -ForegroundColor Green
New-AzResourceGroupDeployment `
		-ResourceGroupName $resourceGroupName `
		-Name $office365ApiConnectionName `
		-TemplateFile $office365TemplateFilePath `
		-TemplateParameterFile $office365ParametersFilePath

$pauseMessage = 'Go to Azure resource group ' + $resourceGroupName + 'and authorize office365 connection, save and continue here'
Pause $pauseMessage

Write-Host Deploy Logic app to process emails -ForegroundColor Green
$logicAppEmailName = $prefix + "processemail"
$outArray.Add("v_logicAppEmailName = $logicAppEmailName")

$logicAppEmailTemplateFilePath = "$ScriptRoot\..\templates\msrpaprocessemail-template.json"
$logicAppEmailParametersFilePath = "$ScriptRoot\..\templates\msrpaprocessemail-parameters.json"
$outArray.Add("v_logicAppEmailTemplateFilePath = $logicAppEmailTemplateFilePath")
$outArray.Add("v_logicAppEmailParametersFilePath = $logicAppEmailParametersFilePath")

$azureblobResourceid = Get-AzResource `
    -ResourceGroupName $resourceGroupName `
    -Name $azureBlobApiConnectionName

$office365Resourceid = Get-AzResource `
    -ResourceGroupName $resourceGroupName `
    -Name $office365ApiConnectionName	
$outArray.Add("v_azureblobResourceid = $azureblobResourceid")
$outArray.Add("v_office365Resourceid = $office365Resourceid")

$logicAppEmailParametersTemplate = Get-Content $logicAppEmailParametersFilePath | ConvertFrom-Json
$logicAppEmailParameters = $logicAppEmailParametersTemplate.parameters
$logicAppEmailParameters.logic_app_name.value = $logicAppEmailName
$logicAppEmailParameters.subscription_id.value = $subscriptionId
$logicAppEmailParameters.location.value = $location
$logicAppEmailParameters.office365_resource_id.value = $office365Resourceid.Id
$logicAppEmailParameters.azureblob_resource_id.value = $azureblobResourceid.Id
$logicAppEmailParameters.storage_connection_string.value = $storageAccountConnectionString
$logicAppEmailParameters.storage_url.value = "https://" + $storageAccountName + ".blob.core.windows.net"
$logicAppEmailParametersTemplate | ConvertTo-Json | Out-File $logicAppEmailParametersFilePath

Write-Host Deploying Logic App ... -ForegroundColor Green
New-AzResourceGroupDeployment `
        -ResourceGroupName $resourceGroupName `
        -Name $logicAppEmailName `
        -TemplateFile $logicAppEmailTemplateFilePath `
        -TemplateParameterFile $logicAppEmailParametersFilePath

#----------------------------------------------------------------#
#   Step 14 - Create Azure Table and store model information	 #
#----------------------------------------------------------------#
$storageAccount = Get-AzStorageAccount `
	-ResourceGroupName $resourceGroupName `
	-AccountName $storageAccountName
$storageContext = $storageAccount.Context

Write-Host Create Azure Table and store model information -ForegroundColor Green

$modelTableName = 'modelinformation'
$entityTableName = 'entities'
$outArray.Add("v_modelTableName = $modelTableName")
$outArray.Add("v_entityTableName = $entityTableName")

try {
	Get-AzStorageTable -Name $modelTableName -Context $storageContext
}
catch{
		New-AzStorageTable -Name $modelTableName -Context $storageContext
}
try {
	Get-AzStorageTable -Name $entityTableName -Context $storageContext
}
catch{
		New-AzStorageTable -Name $entityTableName -Context $storageContext
}
	
$cloudTable = (Get-AzStorageTable -Name $modelTableName -Context $storageContext).CloudTable

if ( $formsTraining -eq 'true' )
{ 
	# Get List of all Forms and store it to model Information
	$folders = Get-ChildItem $trainingFormFilePath
	foreach ($folder in $folders) {
		$formTagName = $folder.Name.toLower()
		
		try
		{
			#####################################
			#TODO - Fix the ModelId hardcoding from just 'page1' to all pages 
			#####################################
			Write-Host Add table entry on form model $formTagName -ForegroundColor Green
			Add-AzTableRow `
			-table $cloudTable `
			-partitionKey $formTagName  `
			-rowKey ("0") -property @{"ComputerVisionKey"=$cognitiveServicesSubscriptionKey;"ComputerVisionUri"=$cognitiveServicesEndpoint + "vision/v2.0/read/core/asyncBatchAnalyze";"EndIndex"=4000;"EndPoint"=$formRecognizerEndpoint + "formrecognizer/v1.0-preview/custom/models/ModelId/analyze";"ImageContainerName"=$formTagName;
			"IsActive"=$true;"ModelId"=$formRecognizerModels[$formTagName + 'page1'];"ModelName"="Form";"Page"="1";"StartIndex"=0;"SubscriptionKey"=$formRecognizerSubscriptionKey}
		}
		catch
		{
		}	
	}
}

if ( $luisTraining -eq 'true' )
{
	$folders = Get-ChildItem $trainingLuisFilePath
	foreach ($folder in $folders) {
		$formTagName = $folder.Name.toLower()

		$files = Get-ChildItem $folder
		foreach($file in $files){
			$luisApplicationFilePath = $trainingLuisFilePath + $folder.Name + '\' + $file.Name
			$luisApplicationTemplate = Get-Content $luisApplicationFilePath
			try
			{		
				Write-Host Add table entry on Luis model $formTagName -ForegroundColor Green
				# Each luis application could have multiple intents for each page. 
				$luisApplicationJsonTemplate = $luisApplicationTemplate | ConvertFrom-Json
				$luisIntents = $luisApplicationJsonTemplate.intents
				$index = 0
				foreach($intent in $luisIntents)
				{
					if ($intent.name.toLower() -ne 'none')
					{
						################################
						## TODO - Store StartIndex in folder?
						################################
						$pageNumber = $intent.name.toLower() -replace 'page',''
						
						Add-AzTableRow `
							-table $cloudTable `
							-partitionKey $formTagName  `
							-rowKey ("$index") `
							-property @{"ComputerVisionKey"=$cognitiveServicesSubscriptionKey;"ComputerVisionUri"=$cognitiveServicesEndpoint + "vision/v2.0/read/core/asyncBatchAnalyze";"EndIndex"=4000;"EndPoint"=$luisAuthoringEndpoint;"ImageContainerName"=$formTagName;
							"IsActive"=$true;"ModelId"=$luisModels[$formTagName];"ModelName"="Luis";"Page"="$pageNumber";"StartIndex"=0;"SubscriptionKey"=$luisAuthoringSubscriptionKey}
							
						$index = $index + 1
					}
				}
			}
			catch
			{
			}
		}
	}
}

#----------------------------------------------------------------#
#   Step 13 - Upload sample documents so that we can run indexer #
#----------------------------------------------------------------#
#$testFormFilePath = "$ScriptRoot\..\deploytest\"
#$testFolders = Get-ChildItem $testFormFilePath
#foreach ($testFolder in $testFolders) {
#	$formContainerName = $testFolder.Name.toLower()
#	$storageAccount = Get-AzStorageAccount `
#		-ResourceGroupName $resourceGroupName `
#		-Name $storageAccountName
#	$storageContext = $storageAccount.Context
#	
#	$subTestFolders = Get-ChildItem $testFolder
#	foreach($subTestFolder in $subTestFolders ){
#		$subFolderName = $subTestFolder.Name.toLower()
#		$testFiles = Get-ChildItem $subTestFolder
#		foreach($testFile in $testFiles){
#			$testFilePath = $testFormFilePath + $testFolder.Name + '\' + $subTestFolder.Name + '\' + $testFile.Name
#			$blobName = $subTestFolder.Name + '\' + $testFile.Name
#			Write-Host Upload File $testFilePath
#			Set-AzStorageBlobContent `
#				-File $testFilePath `
#				-Container $formContainerName `
#				-Blob $blobName `
#				-Context $storageContext `
#				-Force
#		}		
#	}
#}

#----------------------------------------------------------------#
#   Step 15 - Cognitive Search Skills, Index & Indexer			 #
#----------------------------------------------------------------#
# cognitive search
#$customVisionContainers
if ( $cognitiveSearch -eq 'true' )
{
	Write-Host Create Cognitive Search Data Source -ForegroundColor Green
	#foreach( $containerDs in $customVisionContainers ) {
		# Create Data Source(s)
		#$datasourceName = $containerDs + "ds"
		$dataSourceName = $storageContainerProcessForms + "ds"
		$outArray.Add("v_dataSourceName = $dataSourceName")

		Write-Host Creating cognitive search datasource $dataSourceName... -ForegroundColor Green	
		$dataSourceHeader = @{
			"api-key" = $cognitiveSearchKey
		}
		$dataSourceUrl = "https://" + $cognitiveSearchName + ".search.windows.net/datasources?api-version=2019-05-06"
		$outArray.Add("v_dataSourceUrl = $dataSourceUrl")

		$dataSourceBody = @{
			"name"        = $dataSourceName
			"type"        = "azureblob"
			"credentials" = @{"connectionString" = $storageAccountConnectionString }
			"container"   = @{ "name" = $storageContainerProcessForms }
		} | ConvertTo-Json
		try {
			Invoke-RestMethod `
				-Method Post `
				-Uri $dataSourceUrl `
				-Headers $dataSourceHeader `
				-Body $dataSourceBody `
				-ContentType "application/json"
		}
		catch { }
	#}

	Write-Host Create Cognitive Search Skillset -ForegroundColor Green
	# Create Cognitive Search Skillset
	$skillsetName = $storageContainerProcessForms + "ss"
	$outArray.Add("v_skillsetName = $skillsetName")

	$frUri = 'https://' + $functionAppfr + ".azurewebsites.net/api/FormRecognizer?code=" + $functionKeys[$functionAppfr]
	$luisUri = 'https://' + $functionAppluis + ".azurewebsites.net/api/LuisEntities?code=" + $functionKeys[$functionAppluis]
	$cdbUri = 'https://' + $functionAppcdb + ".azurewebsites.net/api/DataProcessor?code=" + $functionKeys[$functionAppcdb]
	$outArray.Add("v_frUri = $frUri")
	$outArray.Add("v_luisUri = $luisUri")
	$outArray.Add("v_cdbUri = $cdbUri")

	Write-Host Creating cognitive search skillset $skillsetName... -ForegroundColor Green
	$skillsetHeader = @{
		'api-key'      = $cognitiveSearchKey
		'Content-Type' = 'application/json' 
	}
	$skillsetBody = '
	{
		"name": "' + $skillsetName + '",
		"description": "Generic skillset",
		"skills": [
			{
				"@odata.type": "#Microsoft.Skills.Vision.OcrSkill",
				"name": "Ocr Skill",
				"description": null,
				"context": "/document/normalized_images/*",
				"textExtractionAlgorithm": "printed",
				"lineEnding": "Space",
				"defaultLanguageCode": "en",
				"detectOrientation": true,
				"inputs": [
					{
						"name": "image",
						"source": "/document/normalized_images/*",
						"sourceContext": null,
						"inputs": []
					}
				],
				"outputs": [
					{
						"name": "text",
						"targetName": "text"
					},
					{
						"name": "layoutText",
						"targetName": "layoutText"
					}
				]
			},
			{
				"@odata.type": "#Microsoft.Skills.Text.MergeSkill",
				"name": "Merge Skill",
				"description": null,
				"context": "/document",
				"insertPreTag": " ",
				"insertPostTag": " ",
				"inputs": [
					{
						"name": "text",
						"source": "/document/content",
						"sourceContext": null,
						"inputs": []
					},
					{
						"name": "itemsToInsert",
						"source": "/document/normalized_images/*/text",
						"sourceContext": null,
						"inputs": []
					},
					{
						"name": "offsets",
						"source": "/document/normalized_images/*/contentOffset",
						"sourceContext": null,
						"inputs": []
					}
				],
				"outputs": [
					{
						"name": "mergedText",
						"targetName": "merged_content"
					}
				]
			},
			{
			  "@odata.type": "#Microsoft.Skills.Text.EntityRecognitionSkill",
			  "name":"Entity Recognition Skill",
			  "categories": [ "Person", "Organization", "Location", "URL"],
			  "defaultLanguageCode": "en",
			  "inputs": [
				{ "name": "text", "source": "/document/merged_content" }
			  ],
			  "outputs": [
				{ "name": "persons", "targetName": "persons" },
				{ "name": "organizations", "targetName": "organizations" },
				{ "name": "locations", "targetName": "locations" },
				{ "name": "urls", "targetName": "urls" }
			  ]
			},
			{
				"@odata.type": "#Microsoft.Skills.Text.SplitSkill",
				"name": "Split Skills",
				"description": null,
				"context": "/document",
				"defaultLanguageCode": "en",
				"textSplitMode": "pages",
				"maximumPageLength": 4000,
				"inputs": [
					{
						"name": "text",
						"source": "/document/content",
						"sourceContext": null,
						"inputs": []
					}
				],
				"outputs": [
					{
						"name": "textItems",
						"targetName": "pages"
					}
				]
			},
			{
				"@odata.type": "#Microsoft.Skills.Text.KeyPhraseExtractionSkill",
				"name": "Key Phrase Skill",
				"description": null,
				"context": "/document/pages/*",
				"defaultLanguageCode": "en",
				"maxKeyPhraseCount": null,
				"inputs": [
					{
						"name": "text",
						"source": "/document/pages/*",
						"sourceContext": null,
						"inputs": []
					}
				],
				"outputs": [
					{
						"name": "keyPhrases",
						"targetName": "keyPhrases"
					}
				]
			},
			{
				"@odata.type": "#Microsoft.Skills.Custom.WebApiSkill",
				"description": "Form Recognizer Skill",
				"uri": "' + $luisUri + '",
				"timeout": "PT230S",
				"context": "/document",
				"inputs": [
				  {
					"name": "Url",
					"source": "/document/url"
				  },
				  {
					"name": "OcrText",
					"source": "/document/normalized_images/*/text"
				  }
				],
				"outputs": [
				  {
					"name": "luisEntities",
					"targetName": "luisEntities"
				  }
				]
			},
			{
				"@odata.type": "#Microsoft.Skills.Custom.WebApiSkill",
				"description": "Form Recognizer Skill",
				"uri": "' + $frUri + '",
				"timeout": "PT230S",
				"context": "/document",
				"inputs": [
				  {
					"name": "Url",
					"source": "/document/url"
				  },
				  {
					"name": "luisEntities",
					"source": "/document/luisEntities"
				  }
				],
				"outputs": [
				  {
					"name": "formEntities",
					"targetName": "formEntities"
				  }
				]
			},
			{
				"@odata.type": "#Microsoft.Skills.Custom.WebApiSkill",
				"description": "CosmosDb Recognizer Skill",
				"uri": "' + $cdbUri + '",
				"timeout": "PT230S",
				"context": "/document",
				"inputs": [
				  {
					"name": "Url",
					"source": "/document/url"
				  },
				  {
					"name": "formEntities",
					"source": "/document/formEntities"
				  }
				],
				"outputs": [
				  {
					"name": "formDoc",
					"targetName": "formDoc"
				  },
				  {
					"name": "formDocJson",
					"targetName": "formDocJson"
				  }
				]
			}
		],
		"cognitiveServices": {
			"@odata.type": "#Microsoft.Azure.Search.CognitiveServicesByKey",
			"description": "",
			"key": "' + $cognitiveServicesSubscriptionKey + '"
		}
	}'
	$skillsetUrl = "https://" + $cognitiveSearchName + ".search.windows.net/skillsets/" + $skillsetName + "?api-version=2019-05-06"
	Invoke-RestMethod `
		-Uri $skillsetUrl `
		-Headers $skillsetHeader `
		-Method Put `
		-Body $skillsetBody


	Write-Host Create Cognitive Search Index -ForegroundColor Green
	# Create Cognitive Search Index
	$indexName = $storageContainerProcessForms + "idx"

	$outArray.Add("v_indexName = $indexName")

	Write-Host Creating cognitive search index... -ForegroundColor Green
	$indexHeader = @{
		'api-key'      = $cognitiveSearchKey
		'Content-Type' = 'application/json' 
	}
	$indexBody = '{
		"name"  : "' + $indexName + '",
		"fields": [
			{
				"name": "id",
				"type": "Edm.String",
				"searchable": true,
				"filterable": false,
				"retrievable": true,
				"sortable": true,
				"facetable": false,
				"key": true,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": null,
				"synonymMaps": []
			},
			{
				"name": "file_name",
				"type": "Edm.String",
				"searchable": true,
				"filterable": true,
				"retrievable": true,
				"sortable": false,
				"facetable": false,
				"key": false,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": null,
				"synonymMaps": []
			},
			{
				"name": "url",
				"type": "Edm.String",
				"searchable": true,
				"filterable": true,
				"retrievable": true,
				"sortable": false,
				"facetable": false,
				"key": false,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": null,
				"synonymMaps": []
			},
			{
				"name": "metadata_storage_sas_token",
				"type": "Edm.String",
				"searchable": true,
				"filterable": true,
				"retrievable": true,
				"sortable": false,
				"facetable": false,
				"key": false,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": null,
				"synonymMaps": []
			},
			{
				"name": "content",
				"type": "Edm.String",
				"searchable": true,
				"filterable": false,
				"retrievable": true,
				"sortable": false,
				"facetable": false,
				"key": false,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": "standard.lucene",
				"synonymMaps": []
			},
			{
				"name": "size",
				"type": "Edm.Int64",
				"searchable": false,
				"filterable": false,
				"retrievable": true,
				"sortable": false,
				"facetable": false,
				"key": false,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": null,
				"synonymMaps": []
			},
			{
				"name": "last_modified",
				"type": "Edm.DateTimeOffset",
				"searchable": false,
				"filterable": false,
				"retrievable": true,
				"sortable": false,
				"facetable": false,
				"key": false,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": null,
				"synonymMaps": []
			},
			{
				"name": "keyPhrases",
				"type": "Collection(Edm.String)",
				"searchable": true,
				"filterable": false,
				"retrievable": true,
				"sortable": false,
				"facetable": true,
				"key": false,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": null,
				"synonymMaps": []
			},
			{
				"name": "urls",
				"type": "Collection(Edm.String)",
				"searchable": true,
				"filterable": true,
				"retrievable": true,
				"sortable": false,
				"facetable": true,
				"key": false,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": null,
				"synonymMaps": []
			},
			{
				"name": "persons",
				"type": "Collection(Edm.String)",
				"searchable": true,
				"filterable": false,
				"retrievable": true,
				"sortable": false,
				"facetable": true,
				"key": false,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": "standard.lucene",
				"synonymMaps": []
			},
			{
				"name": "organizations",
				"type": "Collection(Edm.String)",
				"searchable": true,
				"filterable": false,
				"retrievable": true,
				"sortable": false,
				"facetable": true,
				"key": false,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": "standard.lucene",
				"synonymMaps": []
			},
			{
				"name": "locations",
				"type": "Collection(Edm.String)",
				"searchable": true,
				"filterable": false,
				"retrievable": true,
				"sortable": false,
				"facetable": true,
				"key": false,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": "standard.lucene",
				"synonymMaps": []
			},
			{
				"name": "merged_content",
				"type": "Edm.String",
				"searchable": true,
				"filterable": false,
				"retrievable": true,
				"sortable": false,
				"facetable": false,
				"key": false,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": "standard.lucene",
				"synonymMaps": []
			},
			{
				"name": "enriched",
				"type": "Edm.String",
				"searchable": false,
				"filterable": false,
				"retrievable": false,
				"sortable": false,
				"facetable": false,
				"key": false,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": null,
				"synonymMaps": []
			},
			{
				"name": "text",
				"type": "Collection(Edm.String)",
				"searchable": true,
				"filterable": true,
				"retrievable": true,
				"sortable": false,
				"facetable": false,
				"key": false,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": "standard.lucene",
				"synonymMaps": []
			},
			{
				"name": "isProcessed",
				"type": "Edm.String",
				"searchable": false,
				"filterable": true,
				"retrievable": true,
				"sortable": false,
				"facetable": false,
				"key": false,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": null,
				"synonymMaps": []
			},
			{
				"name": "luisEntities",
				"type": "Edm.String",
				"searchable": true,
				"filterable": true,
				"retrievable": true,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": null,
				"synonymMaps": []
			},
			{
				"name": "formEntities",
				"type": "Edm.String",
				"searchable": true,
				"filterable": true,
				"retrievable": true,
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"analyzer": null,
				"synonymMaps": []
			},
			{
				"name": "formDocJson",
				"type": "Edm.String",
				"indexAnalyzer": null,
				"searchAnalyzer": null,
				"searchable": true,
				"filterable": true,
				"retrievable": true,
				"analyzer": null,
				"synonymMaps": []
			}

	   ],
		"scoringProfiles": [],
		"corsOptions": {  
				"allowedOrigins":["*"]
			},
		"suggesters": [],
		"analyzers": [],
		"tokenizers": [],
		"tokenFilters": [],
		"charFilters": []
	}'
	$indexUrl = "https://" + $cognitiveSearchName + ".search.windows.net/indexes?api-version=2019-05-06-Preview"
	$outArray.Add("v_indexUrl = $indexUrl")

	try {
		Invoke-RestMethod `
			-Method Post `
			-Uri $indexUrl `
			-Headers $indexHeader `
			-Body $indexBody `
			-ContentType "application/json"
	}
	catch { }

	Write-Host Create Cognitive Search Indexer -ForegroundColor Green
	# Create Cognitive Search Indexer for each data source
	Write-Host Creating cognitive search indexer... -ForegroundColor Green
	$indexerName = $storageContainerProcessForms + "idxr"

	$outArray.Add("v_indexerName = $indexerName")

	$indexerHeader = @{
		"api-key" = $cognitiveSearchKey
	}
	#foreach( $containerDs in $customVisionContainers ) {
		# Create Data Source(s)
		#$datasourceName = $containerDs + "ds"
		#$indexerName = $containerDs + "idxr"

		$datasourceName = $storageContainerProcessForms + "ds"
		$indexerName = $storageContainerProcessForms + "idxr"
		$outArray.Add("v_datasourceName = $datasourceName")
		$outArray.Add("v_indexerName = $indexerName")

		$indexerUrl = "https://" + $cognitiveSearchName + ".search.windows.net/indexers/" + $indexerName + "?api-version=2019-05-06"
		$outArray.Add("v_indexerUrl = $indexerUrl")

		$indexerBody = '
		{
			"dataSourceName": "' + $datasourceName + '",
			"targetIndexName": "' + $indexName + '",
			"skillsetName": "' + $skillsetName + '",
			"fieldMappings": [
				{
					"sourceFieldName": "metadata_storage_path",
					"targetFieldName": "id",
					"mappingFunction": {
						"name": "base64Encode"
					}
				},
				{
					"sourceFieldName": "metadata_storage_path",
					"targetFieldName": "url"
				},
				{
					"sourceFieldName": "metadata_storage_name",
					"targetFieldName": "file_name"
				},
				{
					"sourceFieldName": "metadata_storage_size",
					"targetFieldName": "size"
				},
				{
					"sourceFieldName": "metadata_storage_last_modified",
					"targetFieldName": "last_modified"
				},
				{
					"sourceFieldName": "metadata_storage_sas_token",
					"targetFieldName": "metadata_storage_sas_token"
				},
				{
					"sourceFieldName": "content",
					"targetFieldName": "content"
				}
			],
			"outputFieldMappings": [
				{
					"sourceFieldName": "/document/persons",
					"targetFieldName": "persons"
				},
				{
					"sourceFieldName": "/document/organizations",
					"targetFieldName": "organizations"
				},
				{
					"sourceFieldName": "/document/locations",
					"targetFieldName": "locations"
				},
				{
					"sourceFieldName": "/document/urls",
					"targetFieldName": "urls"
				},
				{
					"sourceFieldName": "/document/pages/*/keyPhrases/*",
					"targetFieldName": "keyPhrases"
				},
				{
					"sourceFieldName": "/document/luisEntities",
					"targetFieldName": "luisEntities"
				},
				{
					"sourceFieldName": "/document/formEntities",
					"targetFieldName": "formEntities"
				},
				{
					"sourceFieldName": "/document/formDocJson",
					"targetFieldName": "formDocJson"
				},
				{
					"sourceFieldName": "/document/merged_content",
					"targetFieldName": "merged_content"
				},
				{
					"sourceFieldName": "/document/normalized_images/*/text",
					"targetFieldName": "text"
				}
			],
			"schedule": {
					"interval": "PT5M",
					"startTime": "2019-10-12T05:00:00Z"
			},
			"parameters": {
				"batchSize": 1,
				"maxFailedItems": 999,
				"maxFailedItemsPerBatch": 999,
				"configuration": {
					"imageAction": "generateNormalizedImagePerPage",
					"dataToExtract": "contentAndMetadata",
					"parsingMode": "default",
					"excludedFileNameExtensions":".jpg,.gif,.png"
				}
			}
		}'
		try {
			Invoke-RestMethod `
				-Method Put `
				-Uri $indexerUrl `
				-Headers $indexerHeader `
				-Body $indexerBody `
				-ContentType "application/json"
		}
		catch{}
	#}
}

#----------------------------------------------------------------#
#   Step 16 - Upload sample documents for E2E testing			 #
#----------------------------------------------------------------#
Write-Host Upload sample data and trigger Logic app -ForegroundColor Green
$solTestFormFilePath = "$ScriptRoot\..\e2etest\"
$outArray.Add("v_solTestFormFilePath = $solTestFormFilePath")

$solTestFolders = Get-ChildItem $solTestFormFilePath
foreach ($solTestFolder in $solTestFolders) {
	$formContainerName = 'formspdf'
	$storageAccount = Get-AzStorageAccount `
		-ResourceGroupName $resourceGroupName `
		-Name $storageAccountName
	$storageContext = $storageAccount.Context
	
	$solTestFiles = Get-ChildItem $solTestFolder
	foreach($solTestFile in $solTestFiles){
		$solTestFilePath = $solTestFormFilePath + $solTestFolder.Name + '\' + $solTestFile.Name
		$blobName = $solTestFolder.Name + '\' + $solTestFile.Name
		Write-Host Upload File $solTestFilePath -ForegroundColor Green
		Set-AzStorageBlobContent `
			-File $solTestFilePath `
			-Container $formContainerName `
			-Blob $blobName `
			-Context $storageContext `
			-Force
	}		
}

#Start-AzLogicApp -ResourceGroupName $resourceGroupName -Name $logicAppPdfName -TriggerName "Recurrence"

#----------------------------------------------------------------#
#   Step 17 - Deploy Search Web Api to Azure 					 #
#----------------------------------------------------------------#
if ( $deployWebUi -eq 'true')
{
	Write-Host Create Azure Website to deploy searchui webapi -ForegroundColor Green
	$searchUiWebApiName = $prefix + 'webapi'
	$outArray.Add("v_searchUiWebApiName = $searchUiWebApiName")

	$webApiSettings = @{
			serverFarmId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Web/serverFarms/$AppServicePlanName";
			alwaysOn     = $True;
		}
		
	$currentUiWebApi = Get-AzResource `
			-ResourceGroupName $resourceGroupName `
			-ResourceName $searchUiWebApiName 
	 if ( $currentUiWebApi.Name -eq $null )
	 {
		 New-AzResource `
				-ResourceGroupName $resourceGroupName `
				-Location $location `
				-ResourceName $searchUiWebApiName `
				-ResourceType "microsoft.web/sites" `
				-Kind "app" `
				-Properties $webApiSettings `
				-Force
	}

	$webApiApplicationSettings = @{
			APPINSIGHTS_INSTRUMENTATIONKEY = $appInsightInstrumentationKey;
			SearchServiceName = $cognitiveSearchName;
			SearchServiceKey = $cognitiveSearchKey;
			SearchServiceApiVersion = '2019-05-06';
			SearchIndexName = $indexName;
			InstrumentationKey = $appInsightInstrumentationKey;
			StorageAccountName = $storageAccountName;
			StorageAccountKey = $storageAccountKey;
			StorageContainerAddress = 'http://' + $storageAccountName + '.blob.core.windows.net/' + $storageContainerProcessForms;
			StorageAccountContainerName = $storageContainerProcessForms;
			UploadStorageContainerName = $storageContainerFormsPdf
			KeyField = "id";
			IsPathBase64Encoded = "true";
			GraphFacet = "keyPhrases";
		}
		
		# Configure Function App
		Write-Host Configuring $searchUiWebApiName"..." -ForegroundColor Green
		Set-AzWebApp `
			-Name $searchUiWebApiName `
			-ResourceGroupName $resourceGroupName `
			-AppSettings $webApiApplicationSettings `

	$filePathsearchApiUi = "$ScriptRoot\..\apps\msrpawebapi.zip"
	$outArray.Add("v_filePathsearchApiUi = $filePathsearchApiUi")

	Write-Host Publishing $searchUiWebApiName"..." -ForegroundColor Green

	Publish-AzWebapp -ResourceGroupName $resourceGroupName -Name $searchUiWebApiName -ArchivePath $filePathsearchApiUi -Force

	#----------------------------------------------------------------#
	#   Step 18 - Deploy Search UI to Azure 					 	 #
	#----------------------------------------------------------------#
	Write-Host Create Azure Website to deploy searchui -ForegroundColor Green
	$searchUiWebAppName = $prefix + 'webapp'
	$outArray.Add("v_searchUiWebAppName = $searchUiWebAppName")

	$webAppSettings = @{
			serverFarmId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Web/serverFarms/$AppServicePlanName";
			alwaysOn     = $True;
		}
		
	$currentUiWebApp = Get-AzResource `
			-ResourceGroupName $resourceGroupName `
			-ResourceName $searchUiWebAppName 
	 if ( $currentUiWebApp.Name -eq $null )
	 {
		 New-AzResource `
				-ResourceGroupName $resourceGroupName `
				-Location $location `
				-ResourceName $searchUiWebAppName `
				-ResourceType "microsoft.web/sites" `
				-Kind "app" `
				-Properties $webAppSettings `
				-Force
	}

	$webAppApplicationSettings = @{
			APPINSIGHTS_INSTRUMENTATIONKEY = $appInsightInstrumentationKey;
			ApiProtocol = "https";
			ApiUrl = 'https://' + $searchUiWebApiName + '.azurewebsites.net';
			OrganizationName = 'Microsoft';
			OrganizationWebSiteUrl = 'https://www.microsoft.com';
			OrganizationLogo = 'Microsoft-Logo-PNG.png';
			Customizable = 'true';
		}
		
		# Configure Function App
		Write-Host Configuring $searchUiWebAppName"..." -ForegroundColor Green
		Set-AzWebApp `
			-Name $searchUiWebAppName `
			-ResourceGroupName $resourceGroupName `
			-AppSettings $webAppApplicationSettings `

	$filePathsearchAppUi = "$ScriptRoot\..\apps\msrpaweb.zip"
	$outArray.Add("v_filePathsearchAppUi = $filePathsearchAppUi")

	Write-Host Publishing $searchUiWebAppName"..." -ForegroundColor Green

	Publish-AzWebapp -ResourceGroupName $resourceGroupName -Name $searchUiWebAppName -ArchivePath $filePathsearchAppUi -Force

	$webappResource = Get-AzResource -ResourceType Microsoft.Web/sites/config -ResourceGroupName $resourceGroupName -ResourceName $searchUiWebApiName -ApiVersion 2015-08-01
	$webappResource.Properties.cors =  @{allowedOrigins =  @('https://' + $searchUiWebAppName + '.azurewebsites.net')}
	$webappResource | Set-AzResource -ApiVersion 2015-08-01 -Force
}

$outputArray = @()
$pNames = @("Variables")
foreach($row in $outArray) {
	$obj = new-object PSObject
	$obj | add-member -membertype NoteProperty -name $pNames[0] -value $row
	Write-Host $obj -ForegroundColor Green
	$outputArray+=$obj
	$obj=$null
}
$outputArray | export-csv "msrpa.csv" -NoTypeInformation
Write-Host Deployment complete. -ForegroundColor Green `n
