using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Blob;
using System;
using System.IO;

namespace msrpabo
{
    public static class BlobHelper
    {
        public static void ProcessFiles(string storageConnectionString,
            string destinationContainer, string sourceContainer, string destFolder,
            string imageFolder, string pdfFolder, string processedContainer)
        {
            // Process Source container ( one which has image files )
            MoveBlobFolder(storageConnectionString, sourceContainer, imageFolder, destFolder, destinationContainer);

            // Process Processed container ( one which has PDF files )
            MoveBlob(storageConnectionString, processedContainer, pdfFolder, destFolder, destinationContainer);
        }

        static void MoveBlobFolder(string storageConnectionString, string container, 
            string imageFolder, string folder, string processContainer)
        {
            CloudBlobContainer sourceContainer = null;
            CloudBlobContainer processedContainer = null;

            if (CloudStorageAccount.TryParse(storageConnectionString, out CloudStorageAccount storageAccount))
            {
                try
                {
                    // Create the CloudBlobClient that represents the Blob storage endpoint for the storage account.
                    CloudBlobClient cloudBlobClient = storageAccount.CreateCloudBlobClient();
                    sourceContainer = cloudBlobClient.GetContainerReference(container);
                    processedContainer = cloudBlobClient.GetContainerReference(processContainer);

                    var files = StorageHelper.GetFiles(storageConnectionString, container, imageFolder).Result;

                    foreach (var file in files)
                    {
                        CloudBlockBlob sourceBlob;
                        CloudBlockBlob destBlob;
                        if (string.IsNullOrEmpty(folder))
                        {
                            sourceBlob = StorageHelper.GetBlobReference(file, container, storageConnectionString);
                            destBlob = StorageHelper.GetBlobReference(file, processContainer, storageConnectionString);
                        }
                        else
                        {
                            sourceBlob = StorageHelper.GetBlobReference(imageFolder + "/" + file, container, storageConnectionString);
                            destBlob = StorageHelper.GetBlobReference(folder + "/" + file, processContainer, storageConnectionString);

                        }
                        destBlob.StartCopyAsync(sourceBlob).Wait();
                        sourceBlob.DeleteAsync().Wait();
                    }
                }
                catch (Exception e)
                {

                }
            }
        }

        static void MoveBlob(string storageConnectionString, string container, string folder, string destFolder, string processContainer)
        {
            CloudBlobContainer sourceContainer = null;
            CloudBlobContainer processedContainer = null;

            if (CloudStorageAccount.TryParse(storageConnectionString, out CloudStorageAccount storageAccount))
            {
                try
                {
                    // Create the CloudBlobClient that represents the Blob storage endpoint for the storage account.
                    CloudBlobClient cloudBlobClient = storageAccount.CreateCloudBlobClient();
                    sourceContainer = cloudBlobClient.GetContainerReference(container);
                    processedContainer = cloudBlobClient.GetContainerReference(processContainer);

                    CloudBlockBlob sourceBlob;
                    CloudBlockBlob destBlob;
                    sourceBlob = StorageHelper.GetBlobReference(folder, container, storageConnectionString);
                    var destBlobFolder = destFolder + "/" + Path.GetFileName(folder);
                    destBlob = StorageHelper.GetBlobReference(destBlobFolder, processContainer, storageConnectionString);

                    destBlob.StartCopyAsync(sourceBlob).Wait();
                    sourceBlob.DeleteAsync().Wait();
                }
                catch (Exception e)
                {

                }
            }
        }
    }
}
