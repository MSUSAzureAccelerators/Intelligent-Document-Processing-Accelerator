![MSUS Solution Accelerator](./images/MSUS%20Solution%20Accelerator%20Banner%20Two_981.png)

# Intelligent Document Processing Accelerator

Many organizations process huge volumes of diverse documents in various formats. These forms go through a manual entry process to extract all the relevant information before the data can be used by software applications. The manual process is costly, adds time and is a often error-prone practice. The accelerator described here demonstrates how organizations can use Azure cognitive services to completely automate the data extraction and entry from pdf forms, highlighting the usage of the  **Form Recognizer** and **Azure Cognitive Search**. The pattern and template is data agnostic (i.e., it can be easily customized to work on a custom set of forms as required by a POC, MVP or a demo). The demo scales well through different kinds of forms and supports multiple page forms. 

## Architecture

![Architecture Diagram](/images/architecture.png)

## Process-Flow

* Receive forms from Email or upload via the custom web application
* The logic app will process the email attachment and persist the PDF form into blob storage
  * Uploaded Form via the UI will be persisted directly into blob storage
* Event grid will trigger the Logic app (PDF Forms processing)
* Logic app will
  * Convert the PDF (Azure function call)
  * Classify the form type using Custom Vision
  * Perform the blob operations organization (Azure Function Call)
* Cognitive Search Indexer will trigger the AI Pipeline
  * Execute standard out of the box skills (Key Phrase, NER)
  * Execute custom skills (if applicable) to extract Key/Value pair from the received form
  * Execute Luis skills (if applicable) to extract custom entities from the received form
  * Execute CosmosDb skills to insert the extracted entities into the container as document
* Custom UI provides the search capability into indexed document repository in Azure Search

## Deployment

### Step 0 - Before you start (Pre-requisites)

These are the key pre-requisites to deploy this accelerator:
1. You need a Microsoft Azure account to create the services used in this accelerator. You can create a [free account](https://azure.microsoft.com/en-us/free/), use your MSDN account, or any other subscription where you have permission to create Azure services.
2.	PowerShell: The one-command deployment process uses PowerShell to execute all the required activities to get the accelerator up and running. If you don't have PowerShell, install it from [here](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-windows-powershell?view=powershell-6). Direct link to [MSI download](https://github.com/PowerShell/PowerShell/releases/download/v6.2.3/PowerShell-6.2.3-win-x64.msi). If you have an older version of Power Shell you will have to update to the latest version.
3.	Request access to Form recognizer.  Form Recognizer is available in a limited-access preview. To get access to the preview, fill out and submit the Form Recognizer [access request form](https://aka.ms/FormRecognizerRequestAccess). Once you have access, you can [create](https://portal.azure.com/?microsoft_azure_marketplace_ItemHideKey=microsoft_azure_cognitiveservices_formUnderstandingPreview#create/Microsoft.CognitiveServicesFormRecognizer) the form recognizer service

### Step 1 - Environment Setup

Follow these steps to prepare the deployment:
* Run the PowerShell terminal as an Administrator
* Set the priorities running (every time you restart the PowerShell)
  `Set-ExecutionPolicy -ExecutionPolicy unrestricted`.  (Choose "A", to change the policy to Yes to All)
* Install following Azure Module (one-time)
  * `Install-Module -Name Az -AllowClobber -Scope AllUsers`
  * `Install-Module -Name Az.Search -AllowClobber -Scope AllUsers`
  * `Install-Module AzTable -Force`
* Clone the repo, using [Git for Windows](https://gitforwindows.org/) or any other git app you want. The command is git clone https://github.com/MSUSSolutionAccelerators/Automated-Document-Ingestion-Solution-Accelerator.git

### Step 2 - Customization

The demo contains built-in data set for doing a plug and play scenario. However, before you start the deployment, you can customize the accelerator to use the set of forms you would like to demonstrate. You can also skip this step if you do not want to use your own custom data.

#### Built in Dataset

In the sample template, 5 datasets are included. This data is located inside the package. After extraction go to <path to extracted folder>\deply\formstrain\ These datasets include different forms that will be processed through Cognitive Search and Cognitive Services AI capabilities. 

Dataset | Description
------- | -----------
1098 | Mortgage Interest Form
Contoso Invoice | Invoice Format 1 for Contoso
Customer Invoice | Invoice format 2
W2 | W2 Forms
Loan agreement | Sample Loan agreement contract

#### Adding custom Dataset
 
To add your own custom data set for training the models 
* Create a folder inside <path to extracted folder>\deploy\formstrain\ with a meaningful name. The folder name is further reflected in blob storage so using a meaningful name would help you navigate through the accelerator better. (Avoid using special characters or spaces in the folder name).
* If your forms have multiple pages, break the pdf into separate pages.
* Under the newly created folder, create a separate folder for each page named page1, page2, etc. Add the pages to relevant folder. 
* Add at least 5 sets of sample data for an optimum training of cognitive models. 
  * ![Custom Data](/images/customdata.png)
  * ![Custom Data Page](/images/customdatapage.png)
* To enable end to end testing. Go to <path to extracted folder>\deploy\e2etest\, create a new folder the same as step above with an exact same name and directly add the testing forms inside the newly created folder. 

### Step 3 - Deployment
 
* Run the PowerShell terminal as an Administrator
* Go to to <path to extracted folder>\deploy\scripts folder
* Choose a unique name with 3 or more nonspecial characters with no spaces. It will be used as the prefix of the name of all Azure resources. If the name is already used, the deployment will fail. The name will be converted to lowercase.
* Get the subscription id from the Azure Portal.
* Using the information collected above, run following command: 
  `.\Deploy.ps1 -uniqueName <unique_name> -subscriptionId <subscription_id> -location <location> -resourceGroupName <rgName>`
  
**Note - Currently form recognizer, custom vision (training and prediction services) are available only in a certain region, so make sure to select the region where all required services are available. (List of services by region available at https://azure.microsoft.com/en-us/global-infrastructure/services/?products=all)**

* If you are not logged in, the script will ask you to do it. Authenticate in the browser using the authentication code. Make sure to log in using the account that has access to the subscription you provided in above step ![Signin](/images/signin.png)
* Script execution could take upto 15 minutes to deploy all the artifacts. It is possible that in some remote cases the script would exit prematurely due to request throttling of form recognizer or custom vision service. If this happens then go back to step 3 and rerun deployment, it will automatically skip the already deployed resources and continue to next one. 
* Towards the end of the script there are few API connection that needs to be authorized for your account/subscript. Event Grid and Office 365 API connection will prompt for authorization. ![Authorize](/images/authorize.png)
  * Go to the Azure portal and open the resource group that you defined in deployment script. Locate the event grid API connection and open it. ![EventGrid](/images/eventgrid.png)
  * Click on the orange ribbon that says the connection is not authenticated.
  * Click on Authorize and then click save ![Authenticate](/images/authorize1.png)
  * After saving the changes go back to script and press enter
  * Repeat the same with the office365 API connection and wait for the deployment to finish and then verify the artifacts deployed on the Azure portal.

## List of Artifacts Deployed
 
* API Connection
  * Azure Blob
  * Event Grid
  * Office 366
* App Services/Function App
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
  * PDF Form Processing
  * Email Processing
* Azure Search
* Storage Account
  * Function app Storage
  * Storage for Forms
  * Storage for Training

## Testing
 
* Retrieve the unique name provided at the start of the script and create the URI by appending the web app postfix. <uniquname>webapp.azure.websites.net. There is no space between the uniquename and webapp. Open this uri from the browser. 
* All the data from the forms added in e2etest folder can be searched using the search tab and you can also look at key phrases locations and organizations.
* Alternatively, this accelerator allows you to upload files through its web interface, with 2 limitations: files up to 30 MB and up to 10 files at a time.
* This accelerator allows you to send the email (currently it is filtering emails with subject msrpa) to your office365 authenticated connections inbox folder. To test this path send one form of any of the trained categories with a subject name msrpa to the email address associated with the Azure subscription used. 
* The cognitive search pipeline runs every 5 minutes so you might have to wait a few minutes before the data shows up on the webapp. 
* You can also verify and look at the processed data in the Cosmos DB container “formentities”  on the Azure portal.


#### Note
 
Custom UI is part of our [Knowledge Mining Accelerator](https://github.com/Azure/AIPlatform/tree/master/end-to-end-solutions/kma), an open source end-to-end application that enables you to try the latest features of Azure Cognitive Search.  Additional Reference:
* [KMA Demos Homepage](http://aka.ms/kma)
* [KMA Source Code](https://github.com/Azure/AIPlatform/tree/master/end-to-end-solutions/kma/src)
* [KMA 1-Click Deployment](https://aka.ms/kmadeployment)
* [KMB - Knowledge Mining Bootcamp](http://aka.ms/kmb)

## Contributors
 
[Shekhar Kumar](https://github.com/shkumar64)

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
