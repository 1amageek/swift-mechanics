public enum SleepTopologyContributorDisposition: Sendable {
    case appendHistory
    case retireSleep
    case initializeGlobalIntegration(retiredID:String)
    case preserve(id:String,validator:any RuntimeContributorHandling)
}
