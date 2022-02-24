using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using System.Text;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Collections.Generic;
using Microsoft.WindowsAzure.Storage.Blob;
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Table;
using System.Linq;
using System.Threading;

namespace mrrpafrv2skill
{
    public static class FormRecognizer
    {

        #region Class used to deserialize the request
        private class InputRecord
        {
            public class InputRecordData
            {
                public string Url;
            }

            public string RecordId { get; set; }
            public InputRecordData Data { get; set; }
        }

        private class WebApiRequest
        {
            public List<InputRecord> Values { get; set; }
        }
        #endregion

        #region Classes used to serialize the response
        private class OutputRecord
        {
            public class OutputRecordData
            {
                //public Dictionary<string, string> FormEntities { get; set; }
                public Dictionary<string, string> FormEntitiesv2 { get; set; }
            }

            public class OutputRecordMessage
            {
                public string Message { get; set; }
            }

            public string RecordId { get; set; }
            public OutputRecordData Data { get; set; }
            public List<OutputRecordMessage> Errors { get; set; }
            public List<OutputRecordMessage> Warnings { get; set; }
        }

        private class WebApiResponse
        {
            public WebApiResponse()
            {
                this.values = new List<OutputRecord>();
            }

            public List<OutputRecord> values { get; set; }
        }
        #endregion

        #region Classes used to interact with the Forms Recognizer Analyze API
        private class FormsRecognizerResponse
        {
            public DateTime createdDateTime { get; set; }
            public AnalyzeResult analyzeResult { get; set; }
            public string status { get; set; }
            public DateTime lastUpdatedDateTime { get; set; }

        }

        public class AnalyzeResult
        {
            public List<ReadResult> readResults { get; set; }
            public string version { get; set; }
            public List<PageResult> pageResults { get; set; }
            public List<object> errors { get; set; }
            public List<DocumentResult> documentResults { get; set; }
        }

        public class DocumentResult
        {
            public string docType { get; set; }
            public List<int> pageRange { get; set; }
            public Dictionary<string, Field> fields { get; set; }

        }

        public class Field
        {
            public string type { get; set; }
            public string valueString { get; set; }
            public string text { get; set; }
            public int page { get; set; }
            public List<double> boundingBox { get; set; }
            public double confidence { get; set; }

        }

        public class PageResult
        {
            public int? clusterId { get; set; }
            public int? page { get; set; }
            public List<KeyValuePair> keyValuePairs { get; set; }
            public List<Table> tables { get; set; }
        }

        public class Table
        {
            public int rows { get; set; }
            public int columns { get; set; }
            public List<Cell> cells { get; set; }
        }

        public class Value
        {
            public string text { get; set; }
            public string elements { get; set; }
            public List<double> boundingBox { get; set; }
        }

        public class KeyValuePair
        {
            public Key key { get; set; }
            public Value value { get; set; }
            public double confidence { get; set; }
        }

        public class Cell
        {
            public string isHeader { get; set; }
            public string text { get; set; }
            public int rowSpan { get; set; }
            public int columnIndex { get; set; }
            public int rowIndex { get; set; }
            public List<int> boundingBox { get; set; }
            public string isFooter { get; set; }
            public int columnSpan { get; set; }
            public double confidence { get; set; }
            public List<string> elements { get; set; }
        }

        public class ReadResult
        {
            public int page { get; set; }
            public List<object> lines { get; set; }
            public int height { get; set; }
            public double angle { get; set; }
            public string unit { get; set; }
            public int width { get; set; }
        }

        public class Key
        {
            public string text { get; set; }
            public string elements { get; set; }
            public List<double> boundingBox { get; set; }
        }

        #endregion

        [FunctionName("FormRecognizer")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,
            ILogger log)
        {
            log.LogInformation("Custom skill: C# HTTP trigger function processed a request.");

            // Read input, deserialize it and validate it.
            var data = GetStructuredInput(req.Body);
            if (data == null)
            {
                return new BadRequestObjectResult("The request schema does not match expected schema.");
            }

            var storageConnectionString = Environment.GetEnvironmentVariable("StorageContainerString");
            var modelTable = Environment.GetEnvironmentVariable("ModelTableName");
            var entityTable = Environment.GetEnvironmentVariable("EntityTableName");

            // Calculate the response for each value.
            var response = new WebApiResponse();
            foreach (var record in data.Values)
            {
                if (record == null || record.RecordId == null) continue;

                OutputRecord responseRecord = new OutputRecord
                {
                    RecordId = record.RecordId
                };

                var rootObject = new OutputRecord.OutputRecordData
                {
                    FormEntitiesv2 = new Dictionary<string, string>()
                };

                try
                {
                    // Read Azure Table and find all entries where mlmodel = "Form"
                    // Read information about the storage account and storage key from App Settings
                    var storageAccount = CreateStorageAccountFromConnectionString(storageConnectionString);
                    var sourceBlob = new CloudBlob(new Uri(record.Data.Url), storageAccount.Credentials);
                    var sourceContainer = sourceBlob.Container.Name;
                    // Since we are storing the file into format "container/formtype/attachmenttype/files"
                    var formType = sourceBlob.Parent.Parent.Prefix.Replace("/", "");
                    var sourceFilePath = sourceBlob.Name;
                    var sourceFileName = sourceFilePath.Replace(sourceBlob.Parent.Prefix, "").Replace(".pdf", "");

                    log.LogInformation("Form Recognizer Skill function: Url : {0}", record.Data.Url);

                    var sortedModel = GetModelInfo(storageConnectionString, modelTable,
                        formType).Result;

                    // Loop through all the results once it's sorted by Page Number
                    foreach (var model in sortedModel)
                    {
                        var folder = sourceBlob.Parent.Prefix;
                        var file = sourceFileName + "_" + model.Page.PadLeft(3, '0') + ".jpg";
                        var blob = GetBlobReference(folder + file, sourceContainer, storageConnectionString);
                        Stream myBlob = new MemoryStream();
                        blob.DownloadToStreamAsync(myBlob).Wait();
                        myBlob.Position = 0;

                        var entities = AnalyzeForm(model.ModelId, model.EndPoint,
                        model.SubscriptionKey, myBlob, rootObject.FormEntitiesv2, entityTable,
                        storageConnectionString, file, model.Page, formType, folder, sourceContainer).Result;
                        log.LogInformation("Form Recognizer Skill : C# HTTP output : {0}", responseRecord.Data);
                    }

                    responseRecord.Data = rootObject;
                }
                catch (Exception e)
                {
                    // Something bad happened, log the issue.
                    var error = new OutputRecord.OutputRecordMessage
                    {
                        Message = e.Message
                    };

                    log.LogInformation("Custom skill: C# Exception : {0}", e.Message);

                    responseRecord.Errors = new List<OutputRecord.OutputRecordMessage>
                    {
                        error
                    };
                }
                finally
                {
                    response.values.Add(responseRecord);
                }
            }

            return new OkObjectResult(response);
        }

        private static CloudBlockBlob GetBlobReference(string inputFileName, string containerName,
            string storageConnectionString)
        {
            var storageAccount = CreateStorageAccountFromConnectionString(storageConnectionString);

            // Create the blob client.
            CloudBlobClient blobClient = storageAccount.CreateCloudBlobClient();

            // Retrieve reference to a previously created container.
            CloudBlobContainer container = blobClient.GetContainerReference(containerName);

            // Retrieve reference to a blob named "myblob".
            CloudBlockBlob blockBlob = container.GetBlockBlobReference(inputFileName);
            return blockBlob;
        }

        private static WebApiRequest GetStructuredInput(Stream requestBody)
        {
            string request = new StreamReader(requestBody).ReadToEnd();
            var data = JsonConvert.DeserializeObject<WebApiRequest>(request);
            return data;
        }

        private static async Task<List<ModelEntity>> GetModelInfo(string storageConnectionString,
          string modelTable, string sourceContainer)
        {
            var storageAccount = CreateStorageAccountFromConnectionString(storageConnectionString);
            var tableClient = storageAccount.CreateCloudTableClient();
            var modelInfo = tableClient.GetTableReference(modelTable);

            string filter = "(PartitionKey eq '" + sourceContainer + "' and ModelName eq 'Form' and ModelVersion eq '2' and IsActive eq true)";

            TableQuery<ModelEntity> query = new TableQuery<ModelEntity>()
                .Where(filter);

            List<ModelEntity> sortedModels = new List<ModelEntity>();
            TableContinuationToken token = null;
            do
            {
                TableQuerySegment<ModelEntity> resultSegment =
                    await modelInfo.ExecuteQuerySegmentedAsync(query, token);

                token = resultSegment.ContinuationToken;

                var modelEntities = resultSegment.Results;
                sortedModels = modelEntities.OrderBy(a => a.Page).ToList();
            } while (token != null);

            return sortedModels;
        }

        private static CloudStorageAccount CreateStorageAccountFromConnectionString(
            string storageConnectionString)
        {
            CloudStorageAccount storageAccount;

            try
            {
                storageAccount = CloudStorageAccount.Parse(storageConnectionString);
            }
            catch (FormatException)
            {
                throw;
            }
            catch (ArgumentException)
            {
                throw;
            }
            return storageAccount;
        }

        public static byte[] ReadFully(Stream input)
        {
            byte[] buffer = new byte[16 * 1024];
            using (MemoryStream ms = new MemoryStream())
            {
                int read;
                while ((read = input.Read(buffer, 0, buffer.Length)) > 0)
                {
                    ms.Write(buffer, 0, read);
                }
                return ms.ToArray();
            }
        }

        private static void CreateTableEntity(string entityTable,
            string storageConnectionString, string sourceFile, int entityIndex,
            string key, string value, string page, string formType)
        {
            try
            {
                var storageAccount = CreateStorageAccountFromConnectionString(storageConnectionString);

                // Create the table client.
                var tableClient = storageAccount.CreateCloudTableClient();
                var formTable = tableClient.GetTableReference(entityTable);
                formTable.CreateIfNotExistsAsync();

                var formEntity = new FormEntity(sourceFile, entityIndex.ToString())
                {
                    Key = key,
                    Value = value,
                    IsProcessed = 0,
                    Page = page,
                    FormType = formType
                };

                TableOperation insertOperation = TableOperation.InsertOrReplace(formEntity);

                // Execute the insert operation.
                formTable.ExecuteAsync(insertOperation).Wait();
            }
            catch (Exception e)
            {

            }

        }

        private static async Task<Dictionary<string, string>> AnalyzeForm(string modelId,
            string endPoint, string subscriptionKey, Stream myBlob,
            Dictionary<string, string> formEntities, string entityTable,
            string storageConnectionString, string sourceFile, string page, string formType,
            string folder, string sourceContainer)
        {
            var outputRecord = new OutputRecord.OutputRecordData
            {
                FormEntitiesv2 = new Dictionary<string, string>()
            };

            byte[] bytes = null;
            bytes = ReadFully(myBlob);

            using (var client = new HttpClient())
            using (var request = new HttpRequestMessage())
            {
                endPoint = endPoint.Replace("ModelId", modelId);
                request.Method = HttpMethod.Post;
                request.RequestUri = new Uri(endPoint);
                request.Content = new ByteArrayContent(bytes);
                request.Content.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
                request.Headers.Add("Ocp-Apim-Subscription-Key", subscriptionKey);
                var frResult = new FormsRecognizerResponse() { status = "Running" };

                var response = await client.SendAsync(request);
                var responseBody = await response.Content.ReadAsStringAsync();

                var result = string.Empty;

                if (response.StatusCode == System.Net.HttpStatusCode.Accepted)
                {
                    var operationLocation = response.Headers.GetValues("Operation-Location").FirstOrDefault();
                    if (!string.IsNullOrEmpty(operationLocation))
                    {
                        var clientGet = new HttpClient();
                        clientGet.DefaultRequestHeaders.Add(
                            "Ocp-Apim-Subscription-Key", subscriptionKey);

                        while (frResult.status.Trim().ToLower() != "succeeded"
                            && frResult.status.Trim().ToLower() != "failed")
                        {
                            Thread.Sleep(1000);
                            var httpGetResult = clientGet.GetAsync(operationLocation).Result;
                            result = httpGetResult.Content.ReadAsStringAsync().Result;
                            frResult = JsonConvert.DeserializeObject<FormsRecognizerResponse>(result);
                        }

                        if ( frResult.status.Trim().ToLower() == "failed")
                        {
                            return formEntities;
                        }
                    }

                    // Save the returned Json to Blob
                    var storageAccount = CreateStorageAccountFromConnectionString(storageConnectionString);
                    var jsonFile = sourceFile.Replace(".jpg", ".json");
                    var blob = GetBlobReference(folder + jsonFile, sourceContainer, storageConnectionString);
                    blob.UploadTextAsync(result).Wait();

                    GetKeyValuePairs(frResult, formEntities, entityTable,
                        storageConnectionString, sourceFile, page, formType);
                    formEntities.Add("IsProcessed", "false");
                    return formEntities;

                }
                else
                {
                    throw new SystemException(response.StatusCode.ToString() + ": " + response.ToString() + "\n " + responseBody);
                }
            }
        }

        private static Dictionary<string, string> GetKeyValuePairs(FormsRecognizerResponse response,
            Dictionary<string, string> formEntities, string entityTable,
            string storageConnectionString, string sourceFile, string page, string formType)
        {
            // Analyze the results
            if (response.analyzeResult != null)
            {
                int entityIndex = 0;
                var duplicatePair = new ListWithDuplicates();

                if (response.analyzeResult.documentResults != null)
                {
                    // Custom model with supervised training stores data in "DocumentResults"
                    foreach (var docResult in response.analyzeResult.documentResults)
                    {
                        //foreach (var pair in response.pages[0].KeyValuePairs)
                        foreach (var pair in docResult.fields)
                        {
                            var formKey = pair.Key;
                            if (formKey.Contains("Token"))
                                continue;

                            // then concatenate the result;
                            StringBuilder sb = new StringBuilder();
                            sb.Append(pair.Value.text);

                            // Get keys
                            List<string> allKeys =
                                (from kvp in duplicatePair select kvp.Key).ToList();

                            var formKeyNew = formKey;
                            // Count the # of keys for current Key pair
                            if (allKeys.Contains(formKey, StringComparer.OrdinalIgnoreCase))
                            {
                                List<string> allValues =
                                    (from kvp in duplicatePair
                                     where kvp.Key.ToUpper() == formKey.ToUpper()
                                     select kvp.Value).ToList();

                                var count = allValues.Count();
                                if (count > 0)
                                    formKeyNew = formKey + (count).ToString();
                            }

                            duplicatePair.Add(formKey, sb.ToString());

                            CreateTableEntity(entityTable, storageConnectionString, sourceFile, entityIndex,
                                     formKeyNew, sb.ToString(), string.Concat("Page", page), formType);
                            entityIndex++;

                            formEntities.Add(formKeyNew, sb.ToString());
                        }
                    }
                }

                // Process each tables and Key-value pair - Results from unsupervised training
                if (response.analyzeResult.pageResults != null)
                {
                    foreach (var pages in response.analyzeResult.pageResults)
                    {
                        var pageNumber = pages.page;
                        int iTable = 0;

                        // Process KV Pairs
                        if (pages.keyValuePairs != null)
                        {
                            foreach (var kvPair in pages.keyValuePairs)
                            {
                                var formKey = kvPair.key.text.
                                    Replace(":", "").Replace(" ", "_").Replace("-", "_")
                                    .Replace("'", "").Replace("(", "").Replace(")", "")
                                    .Replace(",", "").Replace("/", "_").Replace("\\", "_").Trim();

                                if (formKey.Contains("Token"))
                                    continue;

                                // then concatenate the result;
                                StringBuilder sb = new StringBuilder();
                                sb.Append(kvPair.value.text);

                                // Get keys
                                List<string> allKeys =
                                    (from kvp in duplicatePair select kvp.Key).ToList();

                                var formKeyNew = formKey;
                                // Count the # of keys for current Key pair
                                if (allKeys.Contains(formKey, StringComparer.OrdinalIgnoreCase))
                                {
                                    List<string> allValues =
                                        (from kvp in duplicatePair
                                            where kvp.Key.ToUpper() == formKey.ToUpper()
                                            select kvp.Value).ToList();

                                    var count = allValues.Count();
                                    if (count > 0)
                                        formKeyNew = formKey + (count).ToString();
                                }

                                duplicatePair.Add(formKey, sb.ToString());

                                CreateTableEntity(entityTable, storageConnectionString, sourceFile, entityIndex,
                                            formKeyNew, sb.ToString(), string.Concat("Page", page), formType);
                                entityIndex++;

                                formEntities.Add(formKeyNew, sb.ToString());
                                
                            }
                        }

                        // Process Tables
                        if (pages.tables != null)
                        {
                            foreach (var table in pages.tables)
                            {
                                iTable++;
                                var totalRows = table.rows;
                                var totalColumns = table.columns;

                                for (int r = 0; r < totalRows; r++)
                                {
                                    var cells = table.cells.Where(c => c.rowIndex == r).OrderBy(c => c.columnIndex);
                                    StringBuilder sb = new StringBuilder();
                                    if (r == 0)
                                    {
                                        var formKey = string.Concat("Table", iTable, "Header");
                                        foreach (var colummn in cells)
                                        {
                                            sb.Append(colummn.text);
                                            sb.Append(",");
                                        }

                                        duplicatePair.Add(formKey, sb.ToString());

                                        CreateTableEntity(entityTable, storageConnectionString, sourceFile, entityIndex,
                                                 formKey, sb.ToString(), string.Concat("Page", page), formType);
                                        entityIndex++;

                                        formEntities.Add(formKey, sb.ToString());

                                    }
                                    else
                                    {
                                        var formKey = string.Concat("Table", iTable, "Row", r);
                                        foreach (var colummn in cells)
                                        {
                                            sb.Append(colummn.text);
                                            sb.Append(",");
                                        }
                                        duplicatePair.Add(formKey, sb.ToString());

                                        CreateTableEntity(entityTable, storageConnectionString, sourceFile, entityIndex,
                                                 formKey, sb.ToString(), string.Concat("Page", page), formType);
                                        entityIndex++;

                                        formEntities.Add(formKey, sb.ToString());

                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Could not find it in that page.
            return formEntities;
        }
    }

    public class ListWithDuplicates : List<KeyValuePair<string, string>>
    {
        public void Add(string key, string value)
        {
            var element = new KeyValuePair<string, string>(key, value);
            this.Add(element);
        }
    }
}
