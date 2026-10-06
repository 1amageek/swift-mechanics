public struct ShellAdmission: Sendable {
    public let maximumCells: Int
    public let maximumNodes: Int
    public let maximumMetadataBytes: Int
    public let massForm: ShellMassForm
    public let isCancelled: @Sendable () -> Bool

    public init(maximumCells: Int, maximumNodes: Int, maximumMetadataBytes: Int, massForm: ShellMassForm,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(ShellError) {
        guard maximumCells > 0, maximumNodes > 0, maximumMetadataBytes >= 0 else {
            throw .invalidParameter(name: "admissionCapacity")
        }
        self.maximumCells = maximumCells; self.maximumNodes = maximumNodes
        self.maximumMetadataBytes = maximumMetadataBytes; self.massForm = massForm; self.isCancelled = isCancelled
    }
}
