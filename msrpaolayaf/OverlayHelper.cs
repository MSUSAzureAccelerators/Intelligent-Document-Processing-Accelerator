using ImageMagick;
using Microsoft.WindowsAzure.Storage.Blob;
using System;
using System.Collections.Generic;
using System.Text;

namespace msrpaolayaf
{
    public class OverlayHelper
    {

        internal static void ProcessFiles(string storageConnectionString, string sourceContainer)
        {
            CloudBlockBlob blob;
            var files = StorageHelper.GetFiles(storageConnectionString, sourceContainer, string.Empty).Result;
            foreach ( var file in files)
            {
                var t = file;
            }


        }

        private static void DrawBoxes(string imageFilename, string formRecognizerOutputJsonFile)
        {
            //string projectDir =
            //    Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, @"..\..\.."));

            //imageFilename = string.Concat(projectDir, "\\", imageFilename);
            //IMagickImage outputImage = new MagickImage(imageFilename).Clone();
            //int imageHeight = outputImage.Height;
            //outputImage.AutoOrient();
            //outputImage.RePage();

            //formRecognizerOutputJsonFile = string.Concat(projectDir, "\\", formRecognizerOutputJsonFile);
            //string json = File.ReadAllText(formRecognizerOutputJsonFile);

            //var response = JsonConvert.DeserializeObject<FormsRecognizerResponse>(json);

            ////JObject resource = JObject.Parse(json);

            //if (response.analyzeResult != null)
            //{
            //    if (response.analyzeResult.documentResults != null)
            //    {
            //        // Custom model with supervised training stores data in "DocumentResults"
            //        foreach (var docResult in response.analyzeResult.documentResults)
            //        {
            //            //foreach (var pair in response.pages[0].KeyValuePairs)
            //            foreach (var pair in docResult.fields)
            //            {
            //                var formKey = pair.Key;
            //                if (formKey.Contains("Token"))
            //                    continue;

            //                double[] bb = new double[8];

            //                for (int j = 0; j < 8; j++)
            //                {
            //                    bb[j] = Double.Parse(pair.Value.boundingBox[j].ToString());
            //                }

            //                WriteLabelAndBoundingBox(outputImage, imageHeight, formKey, bb, "blue");
            //                Console.WriteLine(formKey);

            //                //var text = pair.Value.text;

            //                //for (int j = 0; j < 8; j++)
            //                //{
            //                //    bb[j] = Double.Parse(pair.Value.boundingBox[j].ToString());
            //                //}

            //                //WriteLabelAndBoundingBox(outputImage, imageHeight, text, bb, "purple");
            //                //Console.WriteLine(text);
            //            }
            //        }
            //    }

            //    // Process each tables and Key-value pair - Results from unsupervised training
            //    if (response.analyzeResult.pageResults != null)
            //    {
            //        foreach (var pages in response.analyzeResult.pageResults)
            //        {
            //            var pageNumber = pages.page;
            //            int iTable = 0;

            //            // Process KV Pairs
            //            if (pages.keyValuePairs != null)
            //            {
            //                foreach (var kvPair in pages.keyValuePairs)
            //                {
            //                    var formKey = kvPair.key.text.
            //                        Replace(":", "").Replace(" ", "_").Replace("-", "_")
            //                        .Replace("'", "").Replace("(", "").Replace(")", "")
            //                        .Replace(",", "").Replace("/", "_").Replace("\\", "_").Trim();

            //                    if (formKey.Contains("Token"))
            //                        continue;

            //                    var text = kvPair.value.text;
            //                }
            //            }

            //            // Process Tables
            //            if (pages.tables != null)
            //            {
            //                foreach (var table in pages.tables)
            //                {
            //                    iTable++;
            //                    var totalRows = table.rows;
            //                    var totalColumns = table.columns;

            //                    for (int r = 0; r < totalRows; r++)
            //                    {
            //                        var cells = table.cells.Where(c => c.rowIndex == r).OrderBy(c => c.columnIndex);
            //                        StringBuilder sb = new StringBuilder();
            //                        if (r == 0)
            //                        {
            //                            var formKey = string.Concat("Table", iTable, "Header");
            //                            foreach (var colummn in cells)
            //                            {
            //                                sb.Append(colummn.text);
            //                                sb.Append(",");
            //                            }
            //                        }
            //                        else
            //                        {
            //                            var formKey = string.Concat("Table", iTable, "Row", r);
            //                            foreach (var colummn in cells)
            //                            {
            //                                sb.Append(colummn.text);
            //                                sb.Append(",");
            //                            }
            //                        }
            //                    }
            //                }
            //            }
            //        }
            //    }
            //}
            ////// process key-value pairs: key+value
            ////foreach (var outputRecord in resource["pages"][0]["keyValuePairs"].Children()) // top-level keys/values -- 3 in my sample JSON file
            ////{
            ////    // for each of these there's a key 
            ////    string text = outputRecord["key"][0]["text"].ToString();
            ////    double[] bb = new double[8];
            ////    string valueColour = "purple";

            ////    if (!text.Contains("_Tokens_")) // skip writting out the box for this, as it's just a marker
            ////    {
            ////        for (int j = 0; j < 8; j++)
            ////        {
            ////            bb[j] = Double.Parse(outputRecord["key"][0]["boundingBox"][j].ToString());
            ////        }

            ////        WriteLabelAndBoundingBox(outputImage, imageHeight, text, bb, "blue");
            ////        Console.WriteLine(text);

            ////        valueColour = "blue";
            ////    }
            ////    else
            ////    {
            ////        valueColour = "purple";
            ////    }

            ////    // and 1+ values for the above key
            ////    foreach(var valuesRecord in outputRecord["value"])
            ////    {
            ////        text = valuesRecord["text"].ToString();

            ////        if (!text.Contains("thisisawatermark")) // not sure why this is in the output, but if it shows up just skip it
            ////        {
            ////            for (int j = 0; j < 8; j++)
            ////            {
            ////                bb[j] = Double.Parse(valuesRecord["boundingBox"][j].ToString());
            ////            }

            ////            WriteLabelAndBoundingBox(outputImage, imageHeight, text, bb, valueColour);
            ////            Console.WriteLine(text);
            ////        }
            ////    }
            ////}

            ////// process tables
            ////foreach (var outputTable in resource["pages"][0]["tables"].Children()) // top-level tables
            ////{
            ////    foreach(var column in outputTable["columns"].Children()) // columns in a table
            ////    {
            ////        string header = column["header"][0]["text"].ToString();
            ////        double[] bb = new double[8];

            ////        for (int j = 0; j < 8; j++)
            ////        {
            ////            bb[j] = Double.Parse(column["header"][0]["boundingBox"][j].ToString());
            ////        }

            ////        WriteLabelAndBoundingBox(outputImage, imageHeight, header, bb, "red");
            ////        Console.WriteLine(header);

            ////        foreach(var entries in column["entries"][0].Children())
            ////        {
            ////            string entry = entries["text"].ToString();

            ////            bb = new double[8];

            ////            for (int j = 0; j < 8; j++)
            ////            {
            ////                bb[j] = Double.Parse(entries["boundingBox"][j].ToString());
            ////            }

            ////            WriteLabelAndBoundingBox(outputImage, imageHeight, header, bb, "green");
            ////            Console.WriteLine(entry);

            ////        }
            ////    }
            ////}

            //string outputFilename = "out-" + Path.GetFileName(imageFilename);
            ////string outputFilename = string.Concat("out-", projectDir, "\\", Path.GetFileName(imageFilename));

            //outputImage.Write(outputFilename);
            //Console.Write("\nWrote out to {0} . \nPress enter to exit...", outputFilename);
            //Console.ReadLine();
        }

        private static void WriteLabelAndBoundingBox(IMagickImage outputImage, int imageHeight, string text, double[] bb, string drawColor)
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
