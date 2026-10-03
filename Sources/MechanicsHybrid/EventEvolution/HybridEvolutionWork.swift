import MechanicsNumerics
import MechanicsCollision
import MechanicsContactLaws
import MechanicsLoads
import MechanicsIntegration

public struct HybridEvolutionWork: Sendable {
    public var numerical: NumericalWork
    public var collision: CollisionWork
    public var contact: ContactWork
    public var loads: LoadWork
    public private(set) var queries=0
    public private(set) var rootIterations=0
    public private(set) var acceptedSegments=0
    public private(set) var acceptedImpacts=0
    public private(set) var trajectoryOuterArithmetic=0
    public private(set) var trajectorySupplierArithmetic=0
    public private(set) var trajectoryDerivativeCalls=0
    public private(set) var failedSupplierWorkUnavailable=false
    public init(numerical: NumericalWork, collision: CollisionWork, contact: ContactWork, loads: LoadWork) {
        self.numerical=numerical; self.collision=collision; self.contact=contact; self.loads=loads
    }
    internal mutating func beginQuery(policy: HybridEvolutionPolicy) throws(HybridError) {
        guard queries < policy.maximumQueries else { throw .capacityExceeded }; queries += 1
    }
    internal mutating func absorb(_ report: IntegrationWorkReport) throws(HybridError) {
        trajectoryOuterArithmetic=try ImpactArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(trajectoryOuterArithmetic,report.outerArithmeticBoundCharged) }
        trajectorySupplierArithmetic=try ImpactArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(trajectorySupplierArithmetic,report.supplierArithmeticCharged) }
        trajectoryDerivativeCalls=try ImpactArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(trajectoryDerivativeCalls,report.derivativeCalls) }
        failedSupplierWorkUnavailable = failedSupplierWorkUnavailable || report.failedSupplierWorkUnavailable
    }
    internal mutating func iterated() throws(HybridError) { rootIterations=try ImpactArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(rootIterations,1) } }
    internal mutating func committed(impact: Bool) { acceptedSegments += 1; if impact { acceptedImpacts += 1 } }
    internal mutating func failed(_ error: HybridError) {
        failedSupplierWorkUnavailable = failedSupplierWorkUnavailable || error.failedSupplierWorkUnavailable
        if case .trajectory(let failure)=error { failedSupplierWorkUnavailable = failedSupplierWorkUnavailable || failure.work.failedSupplierWorkUnavailable }
    }
}
