public class SfProject
{
    public string id { get; set; }
    public string displayName { get; set; }
    public string solutionPath { get; set; }
    public string webAppPath { get; set; }
    public string websiteName { get; set; }

    public string branch { get; set; }
    public string description { get; set; }
    public System.Nullable<System.DateTime> lastGetLatest { get; set; }
    public bool isInitialized { get; set; }
    public string[] tags { get; set; }
    public System.Nullable<int> daysSinceLastGet { get; set; }
    public SiteBinding defaultBinding { get; set; }
}