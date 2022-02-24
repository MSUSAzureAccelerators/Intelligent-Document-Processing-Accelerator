namespace msrpaweb
{
    public class AppConfig
    {
        public ApiConfig ApiConfig { get; set; }
        public AppInsightsConfig AppInsights { get; set; }
        public OrganizationConfig Organization { get; set; }

        public bool Customizable { get; set; }
    }
}