![MSUS Solution Accelerator](./images/MSUS%20Solution%20Accelerator%20Banner%20Two_981.jpg)
# Automated Document Ingestion Solution Accelerator

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
* 
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

## License
Copyright (c) Microsoft Corporation

All rights reserved.

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the ""Software""), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE


## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
