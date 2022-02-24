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

namespace mrrpafrskill
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
                public Dictionary<string, string> FormEntities { get; set; }
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
            public string status;
            public List<Page> pages { get; set; }
            public List<object> errors { get; set; }

        }

        private class Page
        {
            public int? number { get; set; }
            public int? height { get; set; }
            public int? width { get; set; }
            public int? clusterId { get; set; }

            public List<KeyValuePair> keyValuePairs { get; set; }

            public List<Table> tables { get; set; }
        }
        public class KeyValuePair
        {
            public List<Key> key { get; set; }
            public List<Value> value { get; set; }
        }

        public class Key
        {
            public string text { get; set; }
            public List<double> boundingBox { get; set; }
        }

        public class Value
        {
            public string text { get; set; }
            public List<double> boundingBox { get; set; }
            public double? confidence { get; set; }
        }

        public class Header
        {
            public string text { get; set; }
            public List<double> boundingBox { get; set; }
        }

        public class Column
        {
            public List<Header> header { get; set; }
            public List<List<Value>> entries { get; set; }
        }

        public class Table
        {
            public string id { get; set; }
            public List<Column> columns { get; set; }
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
                    FormEntities = new Dictionary<string, string>()
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
                        model.SubscriptionKey, myBlob, rootObject.FormEntities, entityTable,
                        storageConnectionString, file, model.Page, formType).Result;
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

            string filter = "(PartitionKey eq '" + sourceContainer + "' and ModelName eq 'Form' and IsActive eq true)";

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
            string storageConnectionString, string sourceFile, string page, string formType)
        {
            var outputRecord = new OutputRecord.OutputRecordData
            {
                FormEntities = new Dictionary<string, string>()
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

                var response = await client.SendAsync(request);
                var responseBody = await response.Content.ReadAsStringAsync();

                if (response.IsSuccessStatusCode)
                {
                    dynamic data = JsonConvert.DeserializeObject(responseBody);

                    var result = JsonConvert.DeserializeObject<FormsRecognizerResponse>(responseBody);

                    GetKeyValuePairs(result, formEntities, entityTable,
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
            // Find the Address in Page 0
            if (response.pages != null)
            {
                //Assume that a given field is in the first page.
                if (response.pages[0] != null)
                {
                    var duplicatePair = new ListWithDuplicates();
                    int entityIndex = 0;

                    //foreach (var pair in response.pages[0].KeyValuePairs)
                    foreach (var pair in response.pages.FirstOrDefault().keyValuePairs)
                    {

                        foreach (var key in pair.key)
                        {
                            var formKey = key.text.
                                Replace(":", "").Replace(" ", "_").Replace("-", "_")
                                .Replace("'", "").Replace("(", "").Replace(")", "")
                                .Replace(",", "").Replace("/", "_").Replace("\\", "_").Trim();

                            if (formKey.Contains("Token"))
                                continue;

                            // then concatenate the result;
                            StringBuilder sb = new StringBuilder();
                            foreach (var value in pair.value)
                            {
                                sb.Append(value.text);
                                // You could replace this for a newline depending on your scenario.
                                sb.Append(" ");
                            }

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

                    // Process each tables
                    foreach (var table in response.pages.FirstOrDefault().tables)
                    {

                        foreach (var column in table.columns)
                        {
                            foreach (var hdr in column.header)
                            {
                                var formKey = hdr.text.Trim();

                                if (formKey.Contains("Token"))
                                    continue;

                                // then concatenate the result;
                                StringBuilder sb = new StringBuilder();
                                foreach (var value in column.entries)
                                {
                                    for (int i = 0; i < value.Count; i++)
                                    {
                                        sb.Append(value[i].text);
                                        // You could replace this for a newline depending on your scenario.
                                        sb.Append(" ");
                                    }

                                }

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
