namespace msrpaazure
{
    public class BlobStorageConfig
    {
        public string AccountName { get; set; }
        public string Key { get; set; }
        public string ContainerName { get; set; }
        public string FacetsFilteringContainerName { get; set; }
        public string UploadContainerName { get; set; }

        public BlobStorageConfig Copy()
        {
            return new BlobStorageConfig() {
                AccountName = this.AccountName, Key = this.Key,
                ContainerName = this.ContainerName,
                FacetsFilteringContainerName = this.FacetsFilteringContainerName,
                UploadContainerName = this.UploadContainerName};
        }
    }
}