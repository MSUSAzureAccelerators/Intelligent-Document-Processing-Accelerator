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

if($uniqueName -eq "default")
{
    Write-Error "Please specify a existing unique name."
    break;
}

if($uniqueName.Length > 17)
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
				Write-Error "Please specify a location."
		}
	}
}

Function Pause ($Message = "Press any key to continue...") {
   # Check if running in PowerShell ISE
   If ($psISE) {
      # "ReadKey" not supported in PowerShell ISE.
      # Show MessageBox UI
      $Shell = New-Object -ComObject "WScript.Shell"
      $Button = $Shell.Popup("Click OK to continue.", 0, "Hello", 0)
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
   While ($KeyInfo.VirtualKeyCode -Eq $Null -Or $Ignore -Contains $KeyInfo.VirtualKeyCode) {
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

if ($ScriptRoot -eq "" -or $ScriptRoot -eq $null) {
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
#   Step 1 - Get Resource Group		 							 #
#----------------------------------------------------------------#

# Get  Resource Group 
Write-Host `nCreating Resource Group $resourceGroupName"..." -ForegroundColor Green `n
try {
		Get-AzResourceGroup `
			-Name $resourceGroupName `
			-Location $location `
	}
catch {
		Write-Host "Resource group does not exist. You can deploy new models only to existing resource group" -ForegroundColor Green `n
		exit
	}

#----------------------------------------------------------------#
#   Step 2 - Get Cognitive Services								 #
#----------------------------------------------------------------#
# Form Recognizer Account

$formRecognizerName = $prefix + "frcs"
$outArray.Add("v_formRecognizerName=$formRecognizerName")

Write-Host Get Form Recognizer service... -ForegroundColor Green

try
{
	Get-AzCognitiveServicesAccount `
	-ResourceGroupName $resourceGroupName `
	-Name $formRecognizerName
}
catch
{
	Write-Host "Form recognizer service not found." -ForegroundColor Green `n
	exit
}
# Get Key and Endpoint
$formRecognizerEndpoint =  (Get-AzCognitiveServicesAccount -ResourceGroupName $resourceGroupName -Name $formRecognizerName).Endpoint		
$formRecognizerSubscriptionKey =  (Get-AzCognitiveServicesAccountKey -ResourceGroupName $resourceGroupName -Name $formRecognizerName).Key1		
$outArray.Add("v_formRecognizerEndpoint=$formRecognizerEndpoint")
$outArray.Add("v_formRecognizerSubscriptionKey=$formRecognizerSubscriptionKey")


$luisAuthoringName = $prefix + "lacs"
$outArray.Add("v_luisAuthoringName=$luisAuthoringName")
Write-Host Get Luis Authoring Service... -ForegroundColor Green

try
{
	Get-AzCognitiveServicesAccount `
	-ResourceGroupName $resourceGroupName `
	-Name $luisAuthoringName
}
catch
{
	Write-Host "Luis Authoring service not found." -ForegroundColor Green `n
	exit
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

Write-Host Get Cognitive service... -ForegroundColor Green

try
{
	Get-AzCognitiveServicesAccount `
	-ResourceGroupName $resourceGroupName `
	-Name $cognitiveServicesName
}
catch
{
	Write-Host "Cognitive services  not found." -ForegroundColor Green `n
	exit
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

Write-Host Get Cognitive service Custom Vision Training ... -ForegroundColor Green

try
{
	Get-AzCognitiveServicesAccount `
	-ResourceGroupName $resourceGroupName `
	-Name $customVisionTrain
}
catch
{
	Write-Host "Custom Vision Training not found." -ForegroundColor Green `n
	exit
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
	Write-Host "Custom Vision Prediction service not found." -ForegroundColor Green `n
	exit
}

# Get Key and Endpoint
$customVisionPredictEndpoint =  (Get-AzCognitiveServicesAccount -ResourceGroupName $resourceGroupName -Name $customVisionPredict).Endpoint		
$customVisionPredictSubscriptionKey =  (Get-AzCognitiveServicesAccountKey -ResourceGroupName $resourceGroupName -Name $customVisionPredict).Key1		
$outArray.Add("v_customVisionPredictEndpoint=$customVisionPredictEndpoint")
$outArray.Add("v_customVisionPredictSubscriptionKey=$customVisionPredictSubscriptionKey")
		
#----------------------------------------------------------------#
#   Step 3 - Find all forms that needs training and upload		 #
#----------------------------------------------------------------#
# We currently have two level of "Folders" that we process
$trainingFormFilePath = "$ScriptRoot\..\newformstrain\"
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

#----------------------------------------------------------------#
#   Step 4 - Train Form Recognizer Models						 #
#----------------------------------------------------------------#
# Train Form Recognizer
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

#----------------------------------------------------------------#
#   Step 5 - Train LUIS Models						 			 #
#----------------------------------------------------------------#
# Train LUIS
Write-Host Luis Models... -ForegroundColor Green
$luisAppImportUrl = $luisAuthoringEndpoint + "luis/api/v2.0/apps/import"
$outArray.Add("v_luisAppImportUrl=$luisAppImportUrl")

$luisHeader = @{
    "Ocp-Apim-Subscription-Key" = $luisAuthoringSubscriptionKey
}
$luisModels = @{ }
$luisModels.Clear()

$trainingLuisFilePath = "$ScriptRoot\..\newluistrain\"

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

#----------------------------------------------------------------#
#   Step 6 - Build, Train and Publish Custom Vision Model		 #
#----------------------------------------------------------------#
#$customVisionProjectName = $prefix + $id + "classify"
$customVisionContainers = New-Object System.Collections.ArrayList($null)
$customVisionContainers.Clear()

$customVisionProjectName = $prefix + "cvfclassify"
$outArray.Add("v_customVisionProjectName = $customVisionProjectName")

$customVisionClassificationType = "Multilabel"
$customVisionProjectUrl = $customVisionTrainEndpoint + "customvision/v3.0/training/projects?name=" + $customVisionProjectName + "&classificationType=" + $customVisionClassificationType 
$outArray.Add("v_customVisionProjectUrl = $customVisionProjectUrl")

$customVisionHeader = @{
    "Training-Key" = $customVisionTrainSubscriptionKey
}

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
$outArray.Add("v_customVisionProjectId = $customVisionProjectId")

$custVisionTrainFilePath = "$ScriptRoot\..\newcustvisiontrain\"

# Get Tag Id for "Yes"
try
{
	$customVisionExistingTagUrl = $customVisionTrainEndpoint + "customvision/v3.0/training/projects/" + $customVisionProjectId + "/tags"
	$cvTagsResp = Invoke-RestMethod -Method Get -Uri $customVisionExistingTagUrl -ContentType "application/json" -Headers $customVisionHeader

	$yesTagId = $cvTagsResp | where { $_.name -eq 'Yes' }
	$customVisionYesTagId = $yesTagId.id
}
catch
{
	Write-Host "Exception on getting existing tags"
	exit
}

# Create Custom Vision Tags
$cvFolders = Get-ChildItem $custVisionTrainFilePath
foreach ($folder in $cvFolders) {
	$tagName = $folder.Name.toLower()
	
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
$projectTrainUri = $customVisionTrainEndpoint + "customvision/v3.0/training/projects/" + $customVisionProjectId + "/train?trainingType=Regular&reservedBudgetInHours=1"
$outArray.Add("v_projectTrainUri = $projectTrainUri")

$projectTrainResponse = Invoke-RestMethod -Method POST -Uri $projectTrainUri -ContentType "application/json" -Headers $customVisionHeader
$trainingIterationId = $projectTrainResponse.id
$outArray.Add("v_trainingIterationId = $trainingIterationId")

Write-Host Since we are performing advance train, wait five minutes before publishing iterations -ForegroundColor Green
# TODO - Check if the training is "Completed" and create loop here before publishing iteration
Start-Sleep -s 60

#Unpublish Iteration?
try
{
	$customVisionCurrentIterationUrl = $customVisionTrainEndpoint + "customvision/v3.0/training/projects/" + $customVisionProjectId + "/iterations"
	$cvIterationResp = Invoke-RestMethod -Method Get -Uri $customVisionCurrentIterationUrl -ContentType "application/json" -Headers $customVisionHeader

	$iterationId = $cvIterationResp | where { $_.publishName -eq 'latest' }
	$customVisionIterationId = $iterationId.id
	
	$customVisionUnpublishIterationUrl = $customVisionTrainEndpoint + "customvision/v3.0/training/projects/" + $customVisionProjectId + "/iterations/" + $customVisionIterationId + "/publish"
	$cvUnpublishIterationResp = Invoke-RestMethod -Method DELETE -Uri $customVisionUnpublishIterationUrl -ContentType "application/json" -Headers $customVisionHeader

	$cvUnpublishIterationResp
}
catch
{
	Write-Host "Exception on getting existing project"
	exit
}

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


#----------------------------------------------------------------#
#   Step 14 - Get Azure Table and store model information		 #
#----------------------------------------------------------------#
$storageAccountName = $prefix + "sa";
$storageAccount = Get-AzStorageAccount `
	-ResourceGroupName $resourceGroupName `
	-AccountName $storageAccountName
$storageContext = $storageAccount.Context

Write-Host Create Azure Table and store model information -ForegroundColor Green

$modelTableName = 'modelinformation'
$outArray.Add("v_modelTableName = $modelTableName")

try {
	Get-AzStorageTable -Name $modelTableName -Context $storageContext
}
catch{
	Write-Host 'Unable to find modelinformation table' -ForegroundColor Green
	exit
}
	
$cloudTable = (Get-AzStorageTable -Name $modelTableName -Context $storageContext).CloudTable

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

#----------------------------------------------------------------#
#   Step 16 - Upload sample documents for E2E testing			 #
#----------------------------------------------------------------#
Write-Host Upload sample data and trigger Logic app -ForegroundColor Green
$solTestFormFilePath = "$ScriptRoot\..\newe2etest\"
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


$outputArray = @()
$pNames = @("Variables")
foreach($row in $outArray) {
	$obj = new-object PSObject
	$obj | add-member -membertype NoteProperty -name $pNames[0] -value $row
	Write-Host $obj -ForegroundColor Green
	$outputArray+=$obj
	$obj=$null
}
$outputArray | export-csv "newmsrpa.csv" -NoTypeInformation
Write-Host Deployment complete. -ForegroundColor Green `n