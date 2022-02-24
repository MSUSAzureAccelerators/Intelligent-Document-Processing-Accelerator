using Newtonsoft.Json;

namespace msrpaazure
{
    public class FDGraphEdge
    {
        [JsonProperty("source")]
        public int Source { get; set; }
        [JsonProperty("target")]
        public int Target { get; set; }
    }
}