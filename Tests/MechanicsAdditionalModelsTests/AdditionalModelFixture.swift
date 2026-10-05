import SwiftMechanics

struct AdditionalModelFixture {
    static func near(_ value: Double, _ expected: Double, absolute: Double = 1e-10, relative: Double = 1e-9) -> Bool {
        abs(value - expected) <= absolute + relative * max(abs(value), abs(expected))
    }
    static func vectorNear(_ a: Vector3, _ b: Vector3) -> Bool {
        near(a.x, b.x) && near(a.y, b.y) && near(a.z, b.z)
    }
    static func actuationWork(maximumWork: Int = 10000, maximumScalars: Int = 1000, cancelled: Bool = false) throws -> ActuationWork {
        ActuationWork(budget: try ActuationBudget(maximumWork: maximumWork, maximumScalars: maximumScalars,
            maximumBytes: 0, maximumBindings: 0, maximumMetadataBytes: 0, isCancelled: { cancelled }))
    }
    static func loadWork(maximumWork: Int = 10000, maximumScalars: Int = 1000, cancelled: Bool = false) throws -> LoadWork {
        LoadWork(budget: try LoadBudget(maximumWork: maximumWork, maximumScalars: maximumScalars, isCancelled: { cancelled }))
    }
}
