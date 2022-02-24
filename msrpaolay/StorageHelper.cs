using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Blob;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace msrpaolay
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

        public static async Task<List<string>> GetSpecificFiles(
            string storageConnectionString, string container, string prefix,
            string extensionFilter)
        {
            var files = new List<string>();

            var storageAccount = CreateStorageAccountFromConnectionString(storageConnectionString);

            var blobClient = storageAccount.CreateCloudBlobClient();
            var cbc = blobClient.GetContainerReference(container);

            IEnumerable<IListBlobItem> listBlobs = await ListSpecificBlobsAsync(cbc, prefix, extensionFilter);
            foreach (CloudBlockBlob cloudBlockBlob in listBlobs)
            {
                if (string.IsNullOrEmpty(prefix))
                    files.Add(cloudBlockBlob.Name);
                else
                    files.Add(cloudBlockBlob.Name.Replace(cloudBlockBlob.Parent.Prefix, ""));
            }
            return files;
        }

        public static async Task<List<string>> GetFiles(
            string storageConnectionString, string container, string prefix)
        {
            var files = new List<string>();

            var storageAccount = CreateStorageAccountFromConnectionString(storageConnectionString);

            var blobClient = storageAccount.CreateCloudBlobClient();
            var cbc = blobClient.GetContainerReference(container);

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

        public static void UploadFileToBlob(string outputFileName, string file, string storageConnectionString,
            string destContainer)
        {
            CloudBlobContainer cloudBlobContainer = null;

            if (CloudStorageAccount.TryParse(storageConnectionString, out CloudStorageAccount storageAccount))
            {
                try
                {
                    // Create the CloudBlobClient that represents the Blob storage endpoint for the storage account.
                    CloudBlobClient cloudBlobClient = storageAccount.CreateCloudBlobClient();

                    cloudBlobContainer = cloudBlobClient.GetContainerReference(destContainer);
                    var cloudBlockBlob = cloudBlobContainer.GetBlockBlobReference(outputFileName);

                    cloudBlockBlob.UploadFromFileAsync(file).Wait();
                }
                catch (StorageException ex)
                {
                    //Console.WriteLine("Error returned from the service: {0}", ex.Message);
                }
            }

        }
        public static async Task<List<string>> ListBlobsHierarchicalListingAsync(CloudBlobContainer container, string prefix)
        {
            CloudBlobDirectory dir;
            BlobContinuationToken continuationToken;

            var files = new List<string>();

            try
            {
                // Call the listing operation and enumerate the result segment.
                // When the continuation token is null, the last segment has been returned and 
                // execution can exit the loop.
                do
                {
                    BlobResultSegment resultSegment = await container.ListBlobsSegmentedAsync(prefix,
                        false, BlobListingDetails.Metadata, null, null, null, null);
                    foreach (var blobItem in resultSegment.Results)
                    {
                        // A hierarchical listing may return both virtual directories and blobs.
                        if (blobItem is CloudBlobDirectory)
                        {
                            dir = (CloudBlobDirectory)blobItem;

                            // Write out the prefix of the virtual directory.
                            files.Add(dir.Prefix);
                            //Console.WriteLine("Virtual directory prefix: {0}", dir.Prefix);

                            // Call recursively with the prefix to traverse the virtual directory.
                            await ListBlobsHierarchicalListingAsync(container, dir.Prefix);
                        }
                    }

                    // Get the continuation token and loop until it is null.
                    continuationToken = resultSegment.ContinuationToken;

                } while (continuationToken != null);
            }
            catch (StorageException e)
            {
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

        private static async Task<List<IListBlobItem>> ListSpecificBlobsAsync(
            CloudBlobContainer container, string prefix, string extensionFilter)
        {
            BlobContinuationToken continuationToken = null;
            List<IListBlobItem> results = new List<IListBlobItem>();
            do
            {
                bool useFlatBlobListing = true;
                BlobListingDetails blobListingDetails = BlobListingDetails.All;
                int maxBlobsPerRequest = 999;
                var response = await container.ListBlobsSegmentedAsync(prefix, useFlatBlobListing, blobListingDetails, maxBlobsPerRequest, continuationToken, null, null);
                continuationToken = response.ContinuationToken;

                foreach (var blobItem in response.Results)
                {
                    // A flat listing operation returns only blobs, not virtual directories.
                    var blob = (CloudBlob)blobItem;
                    if (blob.Uri.Segments.Last().EndsWith(extensionFilter))
                        results.Add(blobItem);

                }

                //results.AddRange(response.Results);
            }
            while (continuationToken != null);
            return results;
        }

        private static async Task<List<IListBlobItem>> ListBlobsAsync(CloudBlobContainer container, string prefix)
        {
            BlobContinuationToken continuationToken = null;
            List<IListBlobItem> results = new List<IListBlobItem>();
            do
            {
                bool useFlatBlobListing = true;
                BlobListingDetails blobListingDetails = BlobListingDetails.None;
                int maxBlobsPerRequest = 999;
                var response = await container.ListBlobsSegmentedAsync(prefix,useFlatBlobListing, blobListingDetails, maxBlobsPerRequest, continuationToken, null, null);
                continuationToken = response.ContinuationToken;
                results.AddRange(response.Results);
            }
            while (continuationToken != null);
            return results;
        }
    }
}
