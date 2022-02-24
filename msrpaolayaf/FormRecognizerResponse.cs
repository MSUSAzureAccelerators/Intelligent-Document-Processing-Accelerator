using System;
using System.Collections.Generic;
using System.Text;

namespace msrpaolayaf
{
    public class FormsRecognizerResponse
    {
        public DateTime createdDateTime { get; set; }
        public AnalyzeResult analyzeResult { get; set; }
        public string status { get; set; }
        public DateTime lastUpdatedDateTime { get; set; }

    }

    public class AnalyzeResult
    {
        public List<ReadResult> readResults { get; set; }
        public string version { get; set; }
        public List<PageResult> pageResults { get; set; }
        public List<object> errors { get; set; }
        public List<DocumentResult> documentResults { get; set; }
    }

    public class DocumentResult
    {
        public string docType { get; set; }
        public List<int> pageRange { get; set; }
        public Dictionary<string, Field> fields { get; set; }

    }

    public class Field
    {
        public string type { get; set; }
        public string valueString { get; set; }
        public string text { get; set; }
        public int page { get; set; }
        public List<double> boundingBox { get; set; }
        public double confidence { get; set; }

    }

    public class PageResult
    {
        public int? clusterId { get; set; }
        public int? page { get; set; }
        public List<KeyValuePair> keyValuePairs { get; set; }
        public List<Table> tables { get; set; }
    }

    public class Table
    {
        public int rows { get; set; }
        public int columns { get; set; }
        public List<Cell> cells { get; set; }
    }

    public class Value
    {
        public string text { get; set; }
        public string elements { get; set; }
        public List<double> boundingBox { get; set; }
    }

    public class KeyValuePair
    {
        public Key key { get; set; }
        public Value value { get; set; }
        public double confidence { get; set; }
    }

    public class Cell
    {
        public string isHeader { get; set; }
        public string text { get; set; }
        public int rowSpan { get; set; }
        public int columnIndex { get; set; }
        public int rowIndex { get; set; }
        public List<int> boundingBox { get; set; }
        public string isFooter { get; set; }
        public int columnSpan { get; set; }
        public double confidence { get; set; }
        public List<string> elements { get; set; }
    }

    public class ReadResult
    {
        public int page { get; set; }
        public List<object> lines { get; set; }
        public int height { get; set; }
        public double angle { get; set; }
        public string unit { get; set; }
        public int width { get; set; }
    }

    public class Key
    {
        public string text { get; set; }
        public string elements { get; set; }
        public List<double> boundingBox { get; set; }
    }
}
