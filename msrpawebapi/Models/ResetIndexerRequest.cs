using Newtonsoft.Json;

namespace msrpawebapi
{
    public class ResetIndexerRequest
    {
        [JsonProperty("delete")]
        public bool Delete { get; set; }

        [JsonProperty("run")]
        public bool Run { get; set; }

        [JsonProperty("reset")]
        public bool Reset { get; set; }
    }
}
