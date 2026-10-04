public struct GranularRuntimeWork: Sendable {
    public let physics: GranularRuntimePhysicsBudget
    public let maximumBytes: Int
    public let maximumWorkUnits: Int
    public let isCancelled: @Sendable () -> Bool
    public private(set) var workUnits = 0
    public private(set) var peakBytes = 0
    public var numerical: NumericalWork
    public var collision: CollisionWork
    public var contact: ContactWork
    public var suppliers: GranularSupplierWork
    private var physicsAdmitted = false
    internal var safePoint: (@Sendable () throws(RuntimeFailure) -> Void)?
    public init(physics: GranularRuntimePhysicsBudget, maximumBytes: Int, maximumWorkUnits: Int,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(GranularRuntimeError) {
        guard maximumBytes >= 0,maximumWorkUnits >= 0 else { throw .invalidInput }
        self.physics=physics;self.maximumBytes=maximumBytes;self.maximumWorkUnits=maximumWorkUnits;self.isCancelled=isCancelled
        numerical=NumericalWork(budget:physics.numerical);collision=CollisionWork(budget:physics.collision);contact=ContactWork(budget:physics.contact)
        do throws(GranularError) { suppliers=try GranularSupplierWork(maximumCalls:physics.maximumSupplierCalls) }
        catch { throw .physical(error) }
    }
    public func poll() throws(GranularRuntimeError) {
        guard !Task.isCancelled,!isCancelled() else { throw .cancelled }
        if let safePoint { do throws(RuntimeFailure) { try safePoint() } catch { throw .runtime(error) } }
    }
    public mutating func charge(_ units: Int) throws(GranularRuntimeError) {
        try poll();let next=try GranularJournalWire.sum(workUnits,units)
        guard next <= maximumWorkUnits else { throw .capacityExceeded };workUnits=next
    }
    internal mutating func reserve(_ bytes: Int) throws(GranularRuntimeError) {
        try poll();guard bytes >= 0,bytes <= maximumBytes else { throw .capacityExceeded };peakBytes=max(peakBytes,bytes)
    }
    internal func nativeBudgetsMatch() -> Bool {
        numerical.budget == physics.numerical && collision.budget == physics.collision &&
        contact.budget.operations == physics.contact.operations && contact.budget.scalarStorage == physics.contact.scalarStorage &&
        contact.budget.records == physics.contact.records && suppliers.maximumCalls == physics.maximumSupplierCalls
    }
    internal mutating func admitPhysics() throws(GranularRuntimeError) {
        if !physicsAdmitted { try charge(physics.maximumWorkUnits);physicsAdmitted=true }
    }
}
