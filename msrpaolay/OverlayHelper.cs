using ImageMagick;
using iText.IO.Image;
using iText.Kernel.Geom;
using iText.Kernel.Pdf;
using iText.Layout;
using iText.Layout.Element;
using Microsoft.WindowsAzure.Storage.Blob;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using Path = System.IO.Path;

namespace msrpaolay
{
    public class OverlayHelper
    {

        internal static void ProcessFiles(string storageConnectionString, string sourceContainer)
        {
            var storageAccount = StorageHelper.CreateStorageAccountFromConnectionString(storageConnectionString);

            var blobClient = storageAccount.CreateCloudBlobClient();
            var cbc = blobClient.GetContainerReference(sourceContainer);

            // We have 2 levels of folders in current structure
            var folders = StorageHelper.ListBlobsHierarchicalListingAsync(cbc, string.Empty).Result;
            foreach( var folder in folders)
            {
                var subFolders = StorageHelper.ListBlobsHierarchicalListingAsync(cbc, folder).Result;
                foreach ( var subFolder in subFolders)
                {
                    // Check if we have "_complete" file then skip processing
                    var files = StorageHelper.GetSpecificFiles(storageConnectionString, sourceContainer, subFolder, ".complete").Result;
                    if (files.Count <= 0)
                    {
                        var jComplete = StorageHelper.GetSpecificFiles(storageConnectionString, sourceContainer, subFolder, ".jcomplete").Result;

                        var jpegFiles = StorageHelper.GetSpecificFiles(storageConnectionString, sourceContainer, subFolder, ".jpg").Result;
                        if ( jpegFiles.Count > 0 && jComplete.Count > 0)
                        {
                            //var pdfStream = new MemoryStream();
                            //PdfDocument pdfDoc = new PdfDocument(new PdfWriter(pdfStream));
                            var pdfNameLocal = string.Concat(Path.GetFileNameWithoutExtension
                               (jpegFiles[0]).Substring(0,Path.GetFileNameWithoutExtension(jpegFiles[0]).Length - 4)
                               , ".pdf");
                            var pdfName = string.Concat(subFolder, pdfNameLocal);

                            PdfDocument pdfDoc = new PdfDocument(new PdfWriter(System.IO.Path.GetTempPath() + pdfNameLocal));
                            Document doc = new Document(pdfDoc);
                           
                           

                            foreach (var jpgFile in jpegFiles)
                            {
                                var blob = StorageHelper.GetBlobReference(subFolder + jpgFile, sourceContainer, storageConnectionString);
                                // Now that we have jpeg file, get the JSON
                                var jsonFile = jpgFile.Replace(".jpg", ".json");

                                Stream jpgBlob = new MemoryStream();
                                blob.DownloadToStreamAsync(jpgBlob).Wait();
                                jpgBlob.Position = 0;

                                try
                                {
                                    var jBlob = StorageHelper.GetBlobReference(subFolder + jsonFile, sourceContainer, storageConnectionString);
                                    var frJson = jBlob.DownloadTextAsync().Result;
                                    var jStream = DrawBoxes(jpgBlob, frJson);
                                    byte[] m_Bytes = ReadToEnd(jStream);
                                    //pdfDoc.AddNewPage(new PageSize(image.getImageWidth(), image.getImageHeight()));
                                    pdfDoc.AddNewPage();
                                    var pdfImage = new Image(ImageDataFactory.Create(m_Bytes));
                                    doc.Add(pdfImage);
                                }
                                catch
                                {
                                    // Json file doesn't exist
                                    continue;
                                }
                            }
                            try
                            {

                                doc.Close();
                                pdfDoc.Close();
                                StorageHelper.UploadFileToBlob(
                                      pdfName, Path.GetTempPath() + pdfNameLocal, storageConnectionString, sourceContainer);

                                File.Delete(Path.GetTempPath() + pdfNameLocal);
                                
                            }
                            catch
                            {

                            }
                        }
                    }
                    else
                        continue;
                }
            }
        }

        public static byte[] ReadToEnd(System.IO.Stream stream)
        {
            long originalPosition = 0;

            if (stream.CanSeek)
            {
                originalPosition = stream.Position;
                stream.Position = 0;
            }

            try
            {
                byte[] readBuffer = new byte[4096];

                int totalBytesRead = 0;
                int bytesRead;

                while ((bytesRead = stream.Read(readBuffer, totalBytesRead, readBuffer.Length - totalBytesRead)) > 0)
                {
                    totalBytesRead += bytesRead;

                    if (totalBytesRead == readBuffer.Length)
                    {
                        int nextByte = stream.ReadByte();
                        if (nextByte != -1)
                        {
                            byte[] temp = new byte[readBuffer.Length * 2];
                            Buffer.BlockCopy(readBuffer, 0, temp, 0, readBuffer.Length);
                            Buffer.SetByte(temp, totalBytesRead, (byte)nextByte);
                            readBuffer = temp;
                            totalBytesRead++;
                        }
                    }
                }

                byte[] buffer = readBuffer;
                if (readBuffer.Length != totalBytesRead)
                {
                    buffer = new byte[totalBytesRead];
                    Buffer.BlockCopy(readBuffer, 0, buffer, 0, totalBytesRead);
                }
                return buffer;
            }
            finally
            {
                if (stream.CanSeek)
                {
                    stream.Position = originalPosition;
                }
            }
        }

        public static Stream DrawBoxes( Stream jpgFile, string frJson)
        {
            var outImage = new MagickImage(jpgFile).Clone();


            var response = JsonConvert.DeserializeObject<FormsRecognizerResponse>(frJson);

            if (response.analyzeResult != null)
            {
                if (response.analyzeResult.documentResults != null)
                {
                    // Custom model with supervised training stores data in "DocumentResults"
                    foreach (var docResult in response.analyzeResult.documentResults)
                    {
                        //foreach (var pair in response.pages[0].KeyValuePairs)
                        foreach (var pair in docResult.fields)
                        {
                            var formKey = pair.Key;
                            if (formKey.Contains("Token"))
                                continue;

                            double[] bb = new double[8];

                            for (int j = 0; j < 8; j++)
                            {
                                bb[j] = Double.Parse(pair.Value.boundingBox[j].ToString());
                            }

                            WriteLabelAndBoundingBox(outImage, formKey, bb, "blue");
                        }
                    }
                }

                // Process each tables and Key-value pair - Results from unsupervised training
                if (response.analyzeResult.pageResults != null)
                {
                    foreach (var pages in response.analyzeResult.pageResults)
                    {
                        var pageNumber = pages.page;
                        int iTable = 0;

                        // Process KV Pairs
                        if (pages.keyValuePairs != null)
                        {
                            foreach (var kvPair in pages.keyValuePairs)
                            {
                                var formKey = kvPair.key.text.
                                    Replace(":", "").Replace(" ", "_").Replace("-", "_")
                                    .Replace("'", "").Replace("(", "").Replace(")", "")
                                    .Replace(",", "").Replace("/", "_").Replace("\\", "_").Trim();

                                if (formKey.Contains("Token"))
                                    continue;

                                var text = kvPair.value.text;

                                double[] bb = new double[8];

                                for (int j = 0; j < 8; j++)
                                {
                                    bb[j] = Double.Parse(kvPair.value.boundingBox[j].ToString());
                                }

                                WriteLabelAndBoundingBox(outImage, formKey, bb, "blue");
                            }
                        }

                        // Process Tables
                        if (pages.tables != null)
                        {
                            foreach (var table in pages.tables)
                            {
                                iTable++;
                                var totalRows = table.rows;
                                var totalColumns = table.columns;

                                for (int r = 0; r < totalRows; r++)
                                {
                                    var cells = table.cells.Where(c => c.rowIndex == r).OrderBy(c => c.columnIndex);
                                    StringBuilder sb = new StringBuilder();
                                    if (r == 0)
                                    {
                                        var formKey = string.Concat("Table", iTable, "Header");
                                        foreach (var colummn in cells)
                                        {
                                            sb.Append(colummn.text);
                                            sb.Append(",");
                                        }
                                    }
                                    else
                                    {
                                        var formKey = string.Concat("Table", iTable, "Row", r);
                                        foreach (var colummn in cells)
                                        {
                                            sb.Append(colummn.text);
                                            sb.Append(",");
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            //// process key-value pairs: key+value
            //foreach (var outputRecord in resource["pages"][0]["keyValuePairs"].Children()) // top-level keys/values -- 3 in my sample JSON file
            //{
            //    // for each of these there's a key 
            //    string text = outputRecord["key"][0]["text"].ToString();
            //    double[] bb = new double[8];
            //    string valueColour = "purple";

            //    if (!text.Contains("_Tokens_")) // skip writting out the box for this, as it's just a marker
            //    {
            //        for (int j = 0; j < 8; j++)
            //        {
            //            bb[j] = Double.Parse(outputRecord["key"][0]["boundingBox"][j].ToString());
            //        }

            //        WriteLabelAndBoundingBox(outputImage, imageHeight, text, bb, "blue");
            //        Console.WriteLine(text);

            //        valueColour = "blue";
            //    }
            //    else
            //    {
            //        valueColour = "purple";
            //    }

            //    // and 1+ values for the above key
            //    foreach(var valuesRecord in outputRecord["value"])
            //    {
            //        text = valuesRecord["text"].ToString();

            //        if (!text.Contains("thisisawatermark")) // not sure why this is in the output, but if it shows up just skip it
            //        {
            //            for (int j = 0; j < 8; j++)
            //            {
            //                bb[j] = Double.Parse(valuesRecord["boundingBox"][j].ToString());
            //            }

            //            WriteLabelAndBoundingBox(outputImage, imageHeight, text, bb, valueColour);
            //            Console.WriteLine(text);
            //        }
            //    }
            //}

            //// process tables
            //foreach (var outputTable in resource["pages"][0]["tables"].Children()) // top-level tables
            //{
            //    foreach(var column in outputTable["columns"].Children()) // columns in a table
            //    {
            //        string header = column["header"][0]["text"].ToString();
            //        double[] bb = new double[8];

            //        for (int j = 0; j < 8; j++)
            //        {
            //            bb[j] = Double.Parse(column["header"][0]["boundingBox"][j].ToString());
            //        }

            //        WriteLabelAndBoundingBox(outputImage, imageHeight, header, bb, "red");
            //        Console.WriteLine(header);

            //        foreach(var entries in column["entries"][0].Children())
            //        {
            //            string entry = entries["text"].ToString();

            //            bb = new double[8];

            //            for (int j = 0; j < 8; j++)
            //            {
            //                bb[j] = Double.Parse(entries["boundingBox"][j].ToString());
            //            }

            //            WriteLabelAndBoundingBox(outputImage, imageHeight, header, bb, "green");
            //            Console.WriteLine(entry);

            //        }
            //    }
            //}


            var outStream = new MemoryStream();
            outImage.Write(outStream);
            return outStream;
        }

        private static void WriteLabelAndBoundingBox(IMagickImage outputImage, 
            string text, double[] bb, string drawColor)
        {
            DrawableStrokeColor strokeColor = new DrawableStrokeColor(new MagickColor(drawColor));
            DrawableStrokeWidth strokeWidth = new DrawableStrokeWidth(3);
            DrawableFillColor fillColor = new DrawableFillColor(new MagickColor(50, 50, 50, 128));
            DrawableRectangle dr = new DrawableRectangle(bb[0], bb[1], bb[4], bb[5]);
            DrawableText dt = new DrawableText(bb[0], bb[1], text);
            outputImage.Draw(strokeColor, strokeWidth, fillColor, dr, dt);
        }
    }
}
