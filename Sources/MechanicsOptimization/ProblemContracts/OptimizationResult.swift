public struct OptimizationResult: Sendable {
    public let status: OptimizationStatus
    public let metadata: OptimizationMetadata
    public let optimum: OptimizationCertificate?
    public let infeasibility: OptimizationInfeasibility?
    public let uniqueness: OptimizationUniqueness
    public let physicalPoint: [Double]?
    public let physicalObjective: Double?
    public let processedBases: Int
    internal init(metadata: OptimizationMetadata, optimum: OptimizationCertificate, physicalPoint: [Double], physicalObjective: Double, uniqueness: OptimizationUniqueness, processed: Int) {
        status = .optimal; self.metadata=metadata; self.optimum=optimum; infeasibility=nil; self.uniqueness=uniqueness
        self.physicalPoint=physicalPoint; self.physicalObjective=physicalObjective; processedBases=processed
    }
    internal init(metadata: OptimizationMetadata, infeasibility: OptimizationInfeasibility, processed: Int) {
        status = .infeasible; self.metadata=metadata; optimum=nil; self.infeasibility=infeasibility; uniqueness = .notEstablished
        physicalPoint=nil; physicalObjective=nil; processedBases=processed
    }
}
