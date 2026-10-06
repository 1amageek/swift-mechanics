/// Explicit native ledgers for the complete bounded replay, not per-step inferred limits.
public struct GranularRuntimePhysicsBudget: Sendable {
    public let numerical: NumericalBudget
    public let collision: CollisionBudget
    public let contact: ContactBudget
    public let maximumSupplierCalls: Int
    public let maximumWorkUnits: Int
    public let logicalStorageBytes: Int
    public init(numerical: NumericalBudget, collision: CollisionBudget, contact: ContactBudget,
                maximumSupplierCalls: Int) throws(GranularRuntimeError) {
        guard maximumSupplierCalls >= 0 else { throw .invalidInput }
        self.numerical=numerical;self.collision=collision;self.contact=contact;self.maximumSupplierCalls=maximumSupplierCalls
        var units=0,slots=0
        for count in [numerical.arithmeticOperations,numerical.iterations,collision.operations,collision.iterations,contact.operations,maximumSupplierCalls] {
            units=try GranularJournalWire.sum(units,count)
        }
        for count in [numerical.scalarStorage,collision.scalarStorage,contact.scalarStorage] { slots=try GranularJournalWire.sum(slots,count) }
        maximumWorkUnits=units;logicalStorageBytes=try GranularJournalWire.product(8,slots)
    }
    internal func matches(_ other: Self) -> Bool {
        numerical == other.numerical && collision == other.collision && contact.operations == other.contact.operations &&
        contact.scalarStorage == other.contact.scalarStorage && contact.records == other.contact.records && maximumSupplierCalls == other.maximumSupplierCalls
    }
}
