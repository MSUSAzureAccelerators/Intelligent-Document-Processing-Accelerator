using System;

namespace msrpaolay
{
    class Program
    {
        static void Main(string[] args)
        {
            var storageConnectionString = "DefaultEndpointsProtocol=https;AccountName=formsmvpsa;AccountKey=4FLrdxzbI7MDgjn9TdLSYjiDI7ZGHQsh4WU/28D20szF4QdjuxUqAsivE4T1S9yZNIiH5j6LJHkHMstvpQehWg==;EndpointSuffix=core.windows.net";
            var sourceContainer = "processforms";

            OverlayHelper.ProcessFiles(storageConnectionString, sourceContainer);
        }
    }
}
