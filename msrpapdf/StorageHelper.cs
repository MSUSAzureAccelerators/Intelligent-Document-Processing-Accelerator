using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Blob;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace msrpapdf
{
    public static class StorageHelper
    {
        public static CloudStorageAccount CreateStorageAccountFromConnectionString(string storageConnectionString)
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

        public static async Task<List<string>> GetFiles(string storageConnectionString, string container, string prefix)
        {
            var files = new List<string>();

            var storageAccount = CreateStorageAccountFromConnectionString(storageConnectionString);

            var blobClient = storageAccount.CreateCloudBlobClient();
            var cbc = blobClient.GetContainerReference(container);

            var dir = cbc.GetDirectoryReference(container);

            IEnumerable<IListBlobItem> listBlobs = await ListBlobsAsync(cbc, prefix);
            foreach (CloudBlockBlob cloudBlockBlob in listBlobs)
            {
                if (string.IsNullOrEmpty(prefix))
                    files.Add(cloudBlockBlob.Name);
                else
                    files.Add(cloudBlockBlob.Name.Replace(cloudBlockBlob.Parent.Prefix, ""));
            }
            return files;
        }


        public static CloudBlockBlob GetBlobReference(string inputFileName, string containerName, string storageConnectionString)
        {
            CloudStorageAccount storageAccount = CreateStorageAccountFromConnectionString(storageConnectionString);

            // Create the blob client.
            CloudBlobClient blobClient = storageAccount.CreateCloudBlobClient();

            // Retrieve reference to a previously created container.
            CloudBlobContainer container = blobClient.GetContainerReference(containerName);

            // Retrieve reference to a blob named "myblob".
            CloudBlockBlob blockBlob = container.GetBlockBlobReference(inputFileName);
            return blockBlob;
        }

       
        private static async Task<List<IListBlobItem>> ListBlobsAsync(CloudBlobContainer container, string prefix)
        {
            BlobContinuationToken continuationToken = null;
            List<IListBlobItem> results = new List<IListBlobItem>();
            do
            {
                bool useFlatBlobListing = true;
                BlobListingDetails blobListingDetails = BlobListingDetails.None;
                int maxBlobsPerRequest = 500;
                var response = await container.ListBlobsSegmentedAsync(prefix,useFlatBlobListing, blobListingDetails, maxBlobsPerRequest, continuationToken, null, null);
                continuationToken = response.ContinuationToken;
                results.AddRange(response.Results);
            }
            while (continuationToken != null);
            return results;
        }
    }
}
