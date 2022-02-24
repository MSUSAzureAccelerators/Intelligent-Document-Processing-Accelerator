using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Extensions.Logging;

namespace msrpapdf
{
    public static class PdfConvertor
    {
        [FunctionName("PdfConvertor")]
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
            var folder = data?.folder;
            var processedContainer = data?.processedContainer;

            lock (_locker)
            {
                PdfHelper.ProcessFiles(storageString.Value, destinationContainer.Value, sourceContainer.Value, folder.Value, processedContainer.Value);
                log.LogInformation($"Completed");
            }

            return (ActionResult)new OkObjectResult($"Completed");
        }
       
    }
}