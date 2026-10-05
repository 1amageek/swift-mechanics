public struct URDFLoss: Sendable {
    public let feature: String
    public let location: XMLLocation
    /// Input markup is retained; this semantic is absent from the compiled mechanical configuration.
    public let retainedInExport: Bool
    internal init(feature: String, location: XMLLocation) {
        self.feature = feature; self.location = location; retainedInExport = true
    }
}
