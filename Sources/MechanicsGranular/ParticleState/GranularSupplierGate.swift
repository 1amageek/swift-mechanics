import MechanicsCollision
import MechanicsContactLaws
internal enum GranularSupplierGate {
    static func valid(_ after: ContactWork,_ before: ContactWork) -> Bool {
        after.budget.operations == before.budget.operations && after.budget.scalarStorage == before.budget.scalarStorage && after.budget.records == before.budget.records &&
        after.operations >= before.operations && after.peakScalarStorage >= before.peakScalarStorage
    }
    static func valid(_ after: CollisionWork,_ before: CollisionWork) -> Bool {
        after.budget == before.budget && after.operations >= before.operations && after.iterations >= before.iterations && after.peakScalarStorage >= before.peakScalarStorage
    }
    static func contact<T>(work: inout ContactWork,_ operation: (inout ContactWork) throws(ContactLawError) -> T) throws(GranularError) -> T {
        let before=work
        let result: T
        do { result=try operation(&work) }
        catch {
            let invalid = !valid(work,before)
            if invalid { work=before }
            throw .contact(error,failedSupplierWorkUnavailable:invalid)
        }
        guard valid(work,before) else { work=before; throw .invalidSupplierLedger(supplier:"contact") }
        return result
    }
    static func collision<T>(work: inout CollisionWork,_ operation: (inout CollisionWork) throws(CollisionError) -> T) throws(GranularError) -> T {
        let before=work
        let result: T
        do { result=try operation(&work) }
        catch {
            let invalid = !valid(work,before)
            if invalid { work=before }
            throw .collision(error,failedSupplierWorkUnavailable:invalid)
        }
        guard valid(work,before) else { work=before; throw .invalidSupplierLedger(supplier:"collision") }
        return result
    }
}
