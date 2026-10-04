internal final class GranularRuntimeSupplierPrefix: Sendable {
    let numerical: NumericalWork
    let collision: CollisionWork
    let contact: ContactWork
    let suppliers: GranularSupplierWork
    init(_ work: GranularRuntimeWork) {
        numerical=work.numerical;collision=work.collision;contact=work.contact;suppliers=work.suppliers
    }
}
