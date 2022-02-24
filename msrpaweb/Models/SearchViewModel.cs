namespace msrpaweb
{
    public class SearchViewModel
    {
        public string Query { get; set; }
        public string SearchId { get; set; }
        public string[] SearchFacets { get; set; }
        public AppConfig AppConfig { get; set; }
    }
}