using System;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;

namespace msrpaolayaf
{
    public static class PdfOverlay
    {
        [FunctionName("PdfOverlay")]
        public static void Run([TimerTrigger("0 */5 * * * *")]TimerInfo myTimer, ILogger log)
        {
            object _locker = new object();

            var storageConnectionString = Environment.GetEnvironmentVariable("StorageContainerString");
            var sourceContainer = Environment.GetEnvironmentVariable("SourceContainer");

            lock (_locker)
            {
                OverlayHelper.ProcessFiles(storageConnectionString, sourceContainer);
                log.LogInformation($"Completed");
            }
        }
    }
}
