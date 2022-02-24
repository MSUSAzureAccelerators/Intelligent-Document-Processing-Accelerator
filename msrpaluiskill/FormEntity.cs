using Microsoft.WindowsAzure.Storage.Table;
using System;
using System.Collections.Generic;
using System.Text;

namespace msrpaluiskill
{
    public class FormEntity : TableEntity
    {
        public FormEntity(string partitionKey, string rowKey)
        {
            this.PartitionKey = partitionKey;
            this.RowKey = rowKey;
        }

        public FormEntity() { }

        public string Key { get; set; }

        public string Value { get; set; }

        public Int32 IsProcessed { get; set; }

        public string Page { get; set; }

        public string FormType { get; set; }

    }
}
