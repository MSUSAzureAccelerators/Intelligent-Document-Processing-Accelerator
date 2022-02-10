# Automated Document Ingestion

Handling Claims processing through an intelligent agent with cognitive skills to handle image, ID, and documents with goal to reduce claims processing time and manual effort in end-to-end claims processing for better customer experience 

The solution will showcase Azure platform’s machine learning capability to recognize document type, extract required fields and push data to downstream applications, significantly reducing manual efforts and creating smoother customer experience.




## Architecture
![Architecture Diagram](/images/architecture.JPG)
## Process-Flow
* Customer uses voice activated intelligent agent to file a new claim via the Chat bots
* Customer uploads the claim related document (taking pictures or uploading the images from the library) via the bot (Driving License, Insurance Card, Service Estimate, Damage of the Windshield)
* In the backend, the data is uploaded to **Azure Storage Services**
* The logic app will process the uploaded documents and images from the blob storage
* Logic app will
  * Extract the metadata from out of the box model related documents (like ID and Invoices)
  * Extract the metadata from the custom models (like insurance card)
  * Data will be persisted and stored into data store(cosmos Db)
* Cognitive Search Indexer will trigger index the documents
* Custom UI provides the search capability into indexed document repository in Azure Search
## Deployment

### Step0 - Before you start (Pre-requisites)
These are the key pre-requisites to deploy this solution:
1. You need a Microsoft Azure account to create the services used in this solution. You can create a [free account](https://azure.microsoft.com/en-us/free/), use your MSDN account, or any other subscription where you have permission to create Azure services.
2.	PowerShell: The one-command deployment process uses PowerShell to execute all the required activities to get the solution up and running. If you don't have PowerShell, install it from [here](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-windows-powershell?view=powershell-6). Direct link to [MSI download](https://github.com/PowerShell/PowerShell/releases/download/v6.2.3/PowerShell-6.2.3-win-x64.msi). If you have an older version of Power Shell you will have to update to the latest version.
3.	Request access to Form recognizer.  Form Recognizer is available in a limited-access preview. To get access to the preview, fill out and submit the Form Recognizer [access request form](https://aka.ms/FormRecognizerRequestAccess). Once you have access, you can [create](https://portal.azure.com/?microsoft_azure_marketplace_ItemHideKey=microsoft_azure_cognitiveservices_formUnderstandingPreview#create/Microsoft.CognitiveServicesFormRecognizer) the form recognizer service
## List of Artifacts Deployed
* API Connection
  * Azure Blob
* App Services
  * Blob operations
  * CosmosDb
  * Form Recognizer
  * Luis
  * Web API & Web App(UI)
* App Service Plan
* Application Insight
* Cognitive Services
  * All-in-one Cognitive Services
  * Custom Vision Training & Prediction
  * Form Recognizer
  * Luis Authoring
* Logic Apps
* Azure Search
* Storage Account
  * Storage for Forms
  * Storage for Training


[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fshkumar64%2Ffsihack%2Fmaster%2Ftemplate.json)

