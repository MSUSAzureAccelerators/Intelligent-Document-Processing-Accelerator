using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Table;
using System.Linq;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using Microsoft.Azure.Cosmos;
using Microsoft.WindowsAzure.Storage.Blob;

namespace msrpacdbskill
{
    public static class DataProcessor
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
                public List<FormDoc> FormDoc { get; set; }
                public string FormDocJson { get; set; }
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

        private static WebApiRequest GetStructuredInput(Stream requestBody)
        {
            string request = new StreamReader(requestBody).ReadToEnd();
            var data = JsonConvert.DeserializeObject<WebApiRequest>(request);
            return data;
        }

        [FunctionName("DataProcessor")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,
            ILogger log)
        {

            log.LogInformation("Data Processor skill: C# HTTP trigger function processed a request.");

            // Read input, deserialize it and validate it.
            var data = GetStructuredInput(req.Body);
            if (data == null)
            {
                return new BadRequestObjectResult("The request schema does not match expected schema.");
            }

            var storageConnectionString = Environment.GetEnvironmentVariable("StorageContainerString");
            var entityTable = Environment.GetEnvironmentVariable("EntityTableName");
            var cosmosUri = Environment.GetEnvironmentVariable("CosmosUri");
            var cosmosKey = Environment.GetEnvironmentVariable("CosmosKey");
            var cosmosDbId = Environment.GetEnvironmentVariable("CosmosDbId");
            var cosmosContainer = Environment.GetEnvironmentVariable("CosmosContainer");

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
                    FormDoc = new List<FormDoc>()
                };

                try
                {
                    log.LogInformation("Data Processor skill: Process record : {0}", record.Data.Url);

                    var storageAccount = CreateStorageAccountFromConnectionString(storageConnectionString);
                    var sourceBlob = new CloudBlob(new Uri(record.Data.Url), storageAccount.Credentials);
                    var sourceContainer = sourceBlob.Container.Name;
                    var sourceFilePath = sourceBlob.Name;
                    var sourceFileName = sourceFilePath.Replace(sourceBlob.Parent.Prefix, "").Replace(".pdf", "");

                    var json = string.Empty;
                    var formDoc = await ProcessData(storageConnectionString, entityTable, 
                        sourceFileName, sourceContainer, log);

                    rootObject.FormDoc = formDoc;

                    json = JsonConvert.SerializeObject(formDoc, Formatting.Indented);
                    log.LogInformation("Json Value : " + json);

                    WriteToCosmos(formDoc, cosmosUri, cosmosDbId,
                        cosmosContainer, cosmosKey);

                    rootObject.FormDocJson = json;
                    responseRecord.Data = rootObject;
                }
                catch (Exception e)
                {
                    // Something bad happened, log the issue.
                    var error = new OutputRecord.OutputRecordMessage
                    {
                        Message = e.Message
                    };

                    log.LogInformation("Data Processor skill: C# Exception : {0}", e.Message);

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

            log.LogInformation($"Completed");

            return new OkObjectResult(response);
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

        private static async Task<List<FormDoc>> ProcessData(string storageConnectionString,
            string entityTable, string sourceFileName,
            string sourceContainer, ILogger log)
        {
            List<FormDoc> formDocuments = new List<FormDoc>();

            var storageAccount = CreateStorageAccountFromConnectionString(storageConnectionString);

            // Create the table client.
            var tableClient = storageAccount.CreateCloudTableClient();
            var formEntity = tableClient.GetTableReference(entityTable);

            var keyFieldPage = "1";
            var formFilter = "(IsProcessed eq 0 and PartitionKey eq '" + string.Concat(sourceFileName, "_", keyFieldPage.PadLeft(3, '0'), ".jpg") + "')";
            TableQuery<FormEntity> query = new TableQuery<FormEntity>()
                .Where(formFilter);

            log.LogInformation("Data Processor skill Form Filter : {0}", formFilter);

            TableContinuationToken token = null;
            token = null;
            do
            {
                TableQuerySegment<FormEntity> resultSegment =
                    await formEntity.ExecuteQuerySegmentedAsync(query, token);

                token = resultSegment.ContinuationToken;

                var formEntities = resultSegment.Results;
                var sortedEntities = formEntities.OrderBy(a => a.PartitionKey).GroupBy(b => b.PartitionKey).ToList();

                log.LogInformation("Data Processor skill Sorted Entities : {0}", sortedEntities.Count);

                // Get all unique entries
                foreach (var entity in sortedEntities)
                {
                    var formDoc = new FormDoc()
                    {
                        IsProcessed = false,
                        CreatedDate = DateTime.Today.ToShortDateString(),
                        Id = Guid.NewGuid().ToString()
                    };

                    var paritionKey = string.Empty;
                    var formType = string.Empty;
                    var entities = entity.ToList();
                    var keyValue = string.Empty;
                    foreach (var ent in entities)
                    {
                        paritionKey = ent.PartitionKey;
                        formType = ent.FormType;
                        keyValue = ent.Value;
                        //if (ent.Key.Contains(keyField))
                        //    keyValue = ent.Value.Replace("_", "").Replace("-","").Replace(".","").Trim().ToUpper();
                            
                    }

                    formDoc.KeyValue = keyValue;
                    formDoc.FormName = paritionKey.Replace("_001.jpg", "");
                    formDoc.FormType = formType;

                    log.LogInformation("Data Processor skill Key Value : {0}", keyValue);
                    log.LogInformation("Data Processor skill Partition Key : {0}", formDoc.FormName);

                    // Query again based on PartitionKey
                    var partitionFilter = "(PartitionKey ge 'partitionKeyStart' and PartitionKey le 'partitionKeyEnd')";
                    var partitionKeyStart = Regex.Replace(paritionKey, "_[0-9][0-9][0-9].jpg", "_001.jpg");
                    var partitionKeyEnd = Regex.Replace(paritionKey, "_[0-9][0-9][0-9].jpg", "_999.jpg");

                    TableQuery<FormEntity> partitionQuery = new TableQuery<FormEntity>()
                        .Where(partitionFilter.Replace("partitionKeyStart", partitionKeyStart).Replace("partitionKeyEnd", partitionKeyEnd));

                    TableContinuationToken partitionToken = null;
                    do
                    {
                        TableQuerySegment<FormEntity> partitionResult =
                            await formEntity.ExecuteQuerySegmentedAsync(partitionQuery, partitionToken);

                        partitionToken = partitionResult.ContinuationToken;

                        var partitionEntities = partitionResult.Results;

                        var orderEntities = partitionEntities.OrderBy(p => p.Page).ToList();
                        var listPageData = new List<PageData>();

                        var prevPage = string.Empty;
                        bool firstTime = true;

                        Dictionary<string, string> fEntities = null;
                        PageData pageData = null;
                        TableOperation updateEntity = null;
                        foreach (var pEntity in orderEntities)
                        {
                            if (string.IsNullOrEmpty(prevPage))
                                firstTime = true;
                            else
                                firstTime = false;

                            if ( prevPage != pEntity.Page)
                            {
                                if (!firstTime)
                                {
                                    pageData.FormEntities = fEntities;
                                    listPageData.Add(pageData);
                                }

                                prevPage = pEntity.Page;
                                fEntities = new Dictionary<string, string>();
                                pageData = new PageData()
                                {
                                    PageNumber = prevPage,
                                };
                                fEntities.Add(pEntity.Key, pEntity.Value);
                                pEntity.IsProcessed = 1;
                                updateEntity = TableOperation.Replace(pEntity);
                                await formEntity.ExecuteAsync(updateEntity);
                                continue;
                            }

                            if ( prevPage == pEntity.Page)
                            {
                                fEntities.Add(pEntity.Key, pEntity.Value);
                            }

                            // Update IsProcessed = 1
                            pEntity.IsProcessed = 1;
                            updateEntity = TableOperation.Replace(pEntity);
                            await formEntity.ExecuteAsync(updateEntity);

                        }
                        pageData.FormEntities = fEntities;
                        listPageData.Add(pageData);
                        formDoc.PageData = listPageData;
                    } while (partitionToken != null);
                    formDocuments.Add(formDoc);
                }
            } while (token != null);
            log.LogInformation("Data Processor skill Total Form Doc: {0}", formDocuments.Count);

            return formDocuments;
        }

        private static async void WriteToCosmos(List<FormDoc> entities, string cosmosUri, string cosmosDbId,
            string cosmosContainer, string cosmosKey)
        {

            var cosmosClient = new CosmosClient(cosmosUri, cosmosKey);
            var cosmosDb = cosmosClient.GetDatabase(cosmosDbId);
            var container = cosmosDb.GetContainer(cosmosContainer);

            foreach( var entity in entities)
            {
                var itemResponse = await container.CreateItemAsync(entity);
            }
        }
    }
}
