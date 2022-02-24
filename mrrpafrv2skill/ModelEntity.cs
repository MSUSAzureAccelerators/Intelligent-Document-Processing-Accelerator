using Microsoft.WindowsAzure.Storage.Table;
using System;
using System.Collections.Generic;
using System.Text;

namespace mrrpafrv2skill
{
    public class ModelEntity : TableEntity
    {
        public ModelEntity(string partitionKey, string rowKey)
        {
            this.PartitionKey = partitionKey;
            this.RowKey = rowKey;
        }

        public ModelEntity() { }

        public string SubscriptionKey { get; set; }

        public string ModelId { get; set; }

        public Boolean IsActive { get; set; }

        public string Page { get; set; }

        public string EndPoint { get; set; }

        public Int32 StartIndex { get; set; }

        public Int32 EndIndex { get; set; }
        public string ModelName { get; set; }

        public string ImageContainerName { get; set; }
        public string ComputerVisionKey { get; set; }
        public string ComputerVisionUri { get; set; }


    }
}
