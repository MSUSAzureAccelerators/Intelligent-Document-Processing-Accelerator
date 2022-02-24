using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Microsoft.Azure.CognitiveServices.Language.LUIS.Runtime;
using System.Threading;
using Microsoft.WindowsAzure.Storage.Blob;
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Table;

namespace msrpaluiskill
{

    /// <summary>
    /// Luis custom skill that finds the entities to connect it with a 
    /// cognitive search pipeline.
    /// </summary>
    public static class LuisSkill
    {

        #region Class used to deserialize the request
        private class InputRecord
        {
            public class InputRecordData
            {
                public string Url { get; set; }
                public List<string> OcrText { get; set; }
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
                public Dictionary<string, string> LuisEntities { get; set; }
                //public Dictionary<string, object> Fields { get; set; }
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
            public List<OutputRecord> Values { get; set; }
        }
        #endregion

        #region The Azure Function definition

        [FunctionName("LuisEntities")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "post", Route = null)] HttpRequest req,
            ILogger log)
        {
            log.LogInformation("LuisSkill function: C# HTTP trigger function processed a request.");

            var response = new WebApiResponse
            {
                Values = new List<OutputRecord>()
            };

            string requestBody = new StreamReader(req.Body).ReadToEnd();
            var data = JsonConvert.DeserializeObject<WebApiRequest>(requestBody);

            // Do some schema validation
            if (data == null)
            {
                return new BadRequestObjectResult("The request schema does not match expected schema.");
            }
            if (data.Values == null)
            {
                return new BadRequestObjectResult("The request schema does not match expected schema. Could not find values array.");
            }

            var storageConnectionString = Environment.GetEnvironmentVariable("StorageContainerString");
            var modelTable = Environment.GetEnvironmentVariable("ModelTableName");
            var entityTable = Environment.GetEnvironmentVariable("EntityTableName");

            log.LogInformation("LuisSkill function: Model Name : {0}", modelTable);

            foreach (var record in data.Values)
            {
                OutputRecord responseRecord = new OutputRecord
                {
                    RecordId = record.RecordId
                };
                // Read Azure Table and find all entries where mlmodel = "luis"
                // Read information about the storage account and storage key from App Settings
                var storageAccount = CreateStorageAccountFromConnectionString(storageConnectionString);
                var sourceBlob = new CloudBlob(new Uri(record.Data.Url), storageAccount.Credentials);
                var sourceContainer = sourceBlob.Container.Name;
                var sourceFilePath = sourceBlob.Name;
                // Since we are storing the file into format "container/formtype/attachmenttype/files"
                var formType = sourceBlob.Parent.Parent.Prefix.Replace("/", "");
                var sourceFileName = sourceFilePath.Replace(sourceBlob.Parent.Prefix, "").Replace(".pdf", "");

                log.LogInformation("LuisSkill function: Url : {0}", record.Data.Url);

                log.LogInformation("LuisSkill function: Text  : {0}", record.Data.OcrText);

                var sortedModel = GetModelInfo(storageConnectionString, modelTable,
                    formType, log).Result;

                // Construct object for results
                var rootObject = new OutputRecord.OutputRecordData
                {
                    LuisEntities = new Dictionary<string, string>()
                };

                var duplicatePair = new ListWithDuplicates();

                // Loop through all the results once it's sorted by Page Number
                foreach (var model in sortedModel)
                {
                    var folder = sourceBlob.Parent.Prefix;
                    var file = sourceFileName + "_" + model.Page.PadLeft(3, '0') + ".jpg";
                    log.LogInformation("LuisSkill function: Model  : {0}, {1}", model.PartitionKey, model.Page);

                    var convertedText = record.Data.OcrText[Convert.ToInt32(model.Page) - 1];
                    if (model.StartIndex > 0 && convertedText.Substring(model.StartIndex).Length > 500)
                        convertedText = convertedText.Substring(model.StartIndex, 500);
                    else if (model.StartIndex > 0)
                        convertedText = convertedText.Substring(model.StartIndex);

                    if (model.StartIndex == 0 && convertedText.Length > 500)
                        convertedText = convertedText.Substring(model.StartIndex, 500);
                    var entities = GetEntities(convertedText, model.ModelId, model.EndPoint,
                        model.SubscriptionKey, rootObject.LuisEntities, formType, entityTable,
                        storageConnectionString, file, model.Page, log, duplicatePair).Result;
                }
                responseRecord.Data = rootObject;

                response.Values.Add(responseRecord);
            }

            return (ActionResult)new OkObjectResult(response);
        }

        #endregion

        #region Methods to call the Luis API

        private static async Task<List<ModelEntity>> GetModelInfo(string storageConnectionString,
            string modelTable, string sourceContainer, ILogger log)
        {
            log.LogInformation("LuisSkill function GetModel Info: C# HTTP trigger function processed a request.");

            var storageAccount = CreateStorageAccountFromConnectionString(storageConnectionString);
            var tableClient = storageAccount.CreateCloudTableClient();
            var modelInfo = tableClient.GetTableReference(modelTable);

            string filter = "(PartitionKey eq '" + sourceContainer + "' and ModelName eq 'Luis' and IsActive eq true)";

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

            log.LogInformation("LuisSkill function GetModel Info Completed");

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

        private static async void CreateTableEntity(string formType, string entityTable,
            string storageConnectionString, string sourceFile, int entityIndex,
            string key, string value, string page, ILogger log)
        {
            log.LogInformation("LuisSkill function CreateTableEntity Info: C# HTTP trigger function processed a request.");

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
                await formTable.ExecuteAsync(insertOperation);
            }
            catch( Exception e )
            {
                log.LogInformation("LuisSkill function CreateTableEntity Exception : {0}, {1}", e.Message,
                    e.StackTrace);
            }

            log.LogInformation("LuisSkill function CreateTableEntity Completed");

        }

        private static async Task<Dictionary<string, string>> GetEntities(string query,
            string modelId, string endPoint, string subscriptionKey,
            Dictionary<string, string> luisEntities, string formType, string entityTable,
            string storageConnectionString, string sourceFile, string page, ILogger log,
            ListWithDuplicates duplicatePair)
        {

            log.LogInformation("LuisSkill function GetEntities Info: C# HTTP trigger function processed a request.");

            // Use Language Understanding or Cognitive Services key
            // to create authentication credentials
            var endpointPredictionkey = subscriptionKey;
            var credentials = new ApiKeyServiceClientCredentials(endpointPredictionkey);

            // Create Luis client and set endpoint
            // region of endpoint must match key's region, for example `westus`
            var luisClient = new LUISRuntimeClient(credentials, new System.Net.Http.DelegatingHandler[] { })
            {
                Endpoint = endPoint 
            };

            // public Language Understanding Home Automation app
            var appId = modelId;

            // common settings for remaining parameters
            Double? timezoneOffset = null;
            var verbose = true;
            var staging = false;
            var spellCheck = false;
            String bingSpellCheckKey = null;
            var boolLog = false;

            // Create prediction client
            var prediction = new Prediction(luisClient);

            // get prediction
            var luisResult = await prediction.ResolveAsync(appId, query, timezoneOffset, verbose,
                staging, spellCheck, bingSpellCheckKey, boolLog, CancellationToken.None);

            //var entities = new Dictionary<string, string>();


            int entityIndex = 0;
            foreach (var entity in luisResult.Entities)
            {
                // Get keys
                List<string> allKeys =
                    (from kvp in duplicatePair select kvp.Key).ToList();

                var entityValue = entity.Entity.
                         Replace(" , ", ",").Replace(" . ", ".").
                         Replace(" / ", "/").Replace(" - ", "-").
                         Replace(" _ ", "_");

                var formKeyNew = entity.Type;
                // Count the # of keys for current Key pair
                if (allKeys.Contains(entity.Type, StringComparer.OrdinalIgnoreCase))
                {
                    List<string> allValues =
                        (from kvp in duplicatePair
                         where kvp.Key.ToUpper() == entity.Type.ToUpper()
                         select kvp.Value).ToList();

                    var count = allValues.Count();
                    if (count > 0)
                        formKeyNew = entity.Type + (count).ToString();
                }

                duplicatePair.Add(entity.Type, entityValue);

                // Remove any extra whitespaces added by LUIS
                //if (!luisEntities.Keys.Contains(entity.Type))
                //    luisEntities.Add(entity.Type, entityValue);
                luisEntities.Add(formKeyNew, entityValue);


                CreateTableEntity(formType, entityTable, storageConnectionString, sourceFile, entityIndex,
                    formKeyNew, entityValue, string.Concat("Page", page), log);
                entityIndex++;
            }

            log.LogInformation("LuisSkill function GetEntities Completed");

            return luisEntities;

            // return the results object
            //return rootObject;


        }
        #endregion
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