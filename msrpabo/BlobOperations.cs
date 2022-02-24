using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

namespace msrpabo
{
    public static class BlobOperations
    {
        [FunctionName("BlobOperations")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,
            ILogger log)
        {
            object _locker = new object();

            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            dynamic data = Newtonsoft.Json.JsonConvert.DeserializeObject(requestBody);
            var destinationContainer = data?.destContainer;
            var storageString = data?.storageString;
            var sourceContainer = data?.sourceContainer;
            var pdfFolder = data?.pdfFolder;
            var imageFolder = data?.imageFolder;
            var destFolder = data?.destFolder;
            var processedContainer = data?.processedContainer;

            lock (_locker)
            {
                BlobHelper.ProcessFiles(storageString.Value, destinationContainer.Value, 
                    sourceContainer.Value, destFolder.Value, imageFolder.Value, pdfFolder.Value, processedContainer.Value);
                log.LogInformation($"Completed");
            }

            return (ActionResult)new OkObjectResult($"Completed");
        }
    }
}
