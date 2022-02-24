using Newtonsoft.Json;
using System.Collections.Generic;

namespace msrpacdbskill
{
    public class FormDoc
    {
        [JsonProperty(PropertyName = "id")]
        public string Id { get; set; }
        public string FormName { get; set; }
        public string FormType { get; set; }
        public string CreatedDate { get; set; }
        public string KeyValue { get; set; }
        public bool IsProcessed { get; set; }
        public List<PageData> PageData { get;set;}
    }

    public class PageData
    {
        public Dictionary<string, string> FormEntities { get; set; }
        public string PageNumber { get; set; }

    }
}
