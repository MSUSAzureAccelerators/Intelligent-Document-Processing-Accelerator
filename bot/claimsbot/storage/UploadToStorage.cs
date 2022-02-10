using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Runtime.CompilerServices;
using System.Threading;
using System.Threading.Tasks;
using AdaptiveExpressions.Properties;
using Microsoft.Bot.Builder;
using Microsoft.Bot.Builder.Dialogs;
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Blob;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace storage
{
    public class UploadToStorage : Dialog
    {
        [JsonConstructor]
        public UploadToStorage([CallerFilePath] string sourceFilePath = "", [CallerLineNumber] int sourceLineNumber = 0)
            : base()
        {
            // enable instances of this command as debug break point
            this.RegisterSourceLocation(sourceFilePath, sourceLineNumber);
        }

        [JsonProperty("$kind")]
        public const string Kind = "UploadToStorage";

        [JsonProperty("contentUrl")]
        public StringExpression ContentUrl { get; set; }

        [JsonProperty("storageString")]
        public StringExpression StorageString { get; set; }

        [JsonProperty("container")]
        public StringExpression Container { get; set; }

        [JsonProperty("blobName")]
        public StringExpression BlobName { get; set; }

        public async override Task<DialogTurnResult> BeginDialogAsync(DialogContext dc, object options = null, CancellationToken cancellationToken = default(CancellationToken))
        {
            if (options is CancellationToken)
            {
                throw new ArgumentException($"{nameof(options)} cannot be a cancellation token");
            }

            var contentUrl = this.ContentUrl.GetValue(dc.State);
            if (String.IsNullOrEmpty(contentUrl))
            {
                throw new Exception($"{this.Id}: \"contentUrl\" is null or an empty string.");
            }
            var storageString = this.StorageString.GetValue(dc.State);
            if (String.IsNullOrEmpty(storageString))
            {
                throw new Exception($"{this.Id}: \"storageString\" is null or an empty string.");
            }
            var container = this.Container.GetValue(dc.State);
            if (String.IsNullOrEmpty(container))
            {
                throw new Exception($"{this.Id}: \"container\" is null or an empty string.");
            }
            var blobName = this.BlobName.GetValue(dc.State);
            if (String.IsNullOrEmpty(blobName))
            {
                throw new Exception($"{this.Id}: \"blobName\" is null or an empty string.");
            }


            var cloudStorageAccount = CloudStorageAccount.Parse(storageString);
            var cloudBlobClient = cloudStorageAccount.CreateCloudBlobClient();
            var cloudBlobContainer = cloudBlobClient.GetContainerReference(container);

            using (var webClient = new WebClient())
            {
                byte[] data = webClient.DownloadData(contentUrl);
                using (var buffer = new MemoryStream(data))
                {
                    // Write changes
                    await UploadBinaryAsync(cloudStorageAccount, cloudBlobContainer, buffer, blobName);
                }
            }
            return await dc.EndDialogAsync("Completed Successfuly uploading the content", cancellationToken).ConfigureAwait(false);
        }

        public static async Task UploadBinaryAsync(CloudStorageAccount cloudStorageAccount, CloudBlobContainer cloudBlobContainer,
            Stream data, string fileName)
        {
            try
            {
                var cloudBlobClient = cloudStorageAccount.CreateCloudBlobClient();
                //get Blob reference  
                var cloudBlockBlob = cloudBlobContainer.GetBlockBlobReference(fileName);
                await cloudBlockBlob.UploadFromStreamAsync(data);
            }
            catch (Exception e)
            {
            }
        }
    }
}
