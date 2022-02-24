using Ghostscript.NET;
using Ghostscript.NET.Processor;
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Blob;
using System;
using System.Collections.Generic;
using System.IO;

namespace msrpapdf
{
    public static class PdfHelper
    {
        public static void ProcessFiles(string storageConnectionString,
            string destinationContainer, string sourceContainer, string folder, string processedContainer)
        {


            if (!folder.Contains(".pdf"))
                return;

            CloudBlockBlob blob;
            blob = StorageHelper.GetBlobReference(folder, sourceContainer, storageConnectionString);

            Stream myBlob = new MemoryStream();
            blob.DownloadToStreamAsync(myBlob).Wait();

            myBlob.Position = 0;

            string inputFile = System.IO.Path.GetTempPath() + Path.GetFileName(folder);

            using (var fileStream = new FileStream(inputFile, FileMode.Create, FileAccess.Write))
            {
                myBlob.CopyTo(fileStream);
            }

            string outputFile = Path.GetTempPath() + Path.GetFileNameWithoutExtension(blob.Name) + "_%03d.jpg";
            int pageFrom = 1;
            int pageTo = 999;

            //log.LogInformation($"Output file:{outputFile}");

            GhostscriptVersionInfo gvi = new GhostscriptVersionInfo("D:\\home\\site\\wwwroot\\bin\\gsdll64.dll");
            //GhostscriptVersionInfo gvi = new GhostscriptVersionInfo("C:\\Projects\\Repos\\msrpa\\msrpapdf\\bin\\Debug\\netcoreapp2.1\\bin\\gsdll32.dll");
                    
            using (GhostscriptProcessor ghostscript = new GhostscriptProcessor(gvi))
            {
                List<string> switches = new List<string>
                {
                    "-empty",
                    "-dSAFER",
                    "-dBATCH",
                    "-dNOPAUSE",
                    "-dNOPROMPT",
                    "-dFirstPage=" + pageFrom.ToString(),
                    "-dLastPage=" + pageTo.ToString(),
                    "-sDEVICE=jpeg",
                    "-r188",
                    "-dJPEGQ=100",
                    //switches.Add("-dGraphicsAlphaBits=4");
                    @"-sOutputFile=" + outputFile,
                    @"-f",
                    inputFile
                };

                ghostscript.Process(switches.ToArray());
            }

            UploadFilesToBlob(Path.GetFileNameWithoutExtension(blob.Name), blob.Name, storageConnectionString, destinationContainer);

            // Delete pdf file
            File.Delete(inputFile);
            // Move Blob to Processed Container
            MoveBlob(storageConnectionString, sourceContainer, folder, processedContainer);
        }

        static void MoveBlob(string storageConnectionString, string container, string folder, string processContainer)
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

                    var files = StorageHelper.GetFiles(storageConnectionString, container, folder).Result;

                    CloudBlockBlob sourceBlob;
                    CloudBlockBlob destBlob;
                    
                    sourceBlob = StorageHelper.GetBlobReference(folder, container, storageConnectionString);
                    destBlob = StorageHelper.GetBlobReference(folder, processContainer, storageConnectionString);
                
                    destBlob.StartCopyAsync(sourceBlob).Wait();
                    sourceBlob.DeleteAsync().Wait();
                }
                catch (Exception e)
                {

                }
            }
        }

        static void UploadFilesToBlob(string outputFileName, string originalFileName, string storageConnectionString,
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
                    cloudBlobContainer.CreateIfNotExistsAsync();

                    var files = Directory.GetFiles(System.IO.Path.GetTempPath(), outputFileName + "_*.jpg");

                    foreach (var file in files)
                    {
                        var cloudBlockBlob = cloudBlobContainer.GetBlockBlobReference(string.Concat(outputFileName, "/", Path.GetFileName(file)));
                        if (cloudBlockBlob != null)
                        {
                            cloudBlockBlob.UploadFromFileAsync(file).Wait();

                            // Get the blob attributes
                            cloudBlockBlob.FetchAttributesAsync();

                            // Write the blob metadata
                            cloudBlockBlob.Metadata["OriginalFileName"] = originalFileName;
                            cloudBlockBlob.Metadata["FileNameofImage"] = Path.GetFileName(file);
                            cloudBlockBlob.Metadata["FolderName"] = outputFileName;
                            cloudBlockBlob.Metadata["PageNo"] = Path.GetFileNameWithoutExtension(file).Substring(Path.GetFileNameWithoutExtension(file).Length - 3);

                            // Save the blob metadata
                            cloudBlockBlob.SetMetadataAsync();
                        }
                        // Delete local file
                        File.Delete(file);
                    }
                }
                catch (StorageException ex)
                {
                    //Console.WriteLine("Error returned from the service: {0}", ex.Message);
                }
            }

        }
    }
}
