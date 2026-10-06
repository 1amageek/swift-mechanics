import SwiftMechanics
struct EnvironmentalLoadFixture {
    static func body() throws -> EntityID { try EntityID(kind: .body, key: "environment-body") }
    static func frame() throws -> EntityID { try EntityID(kind: .frame, key: "world") }
    static func work(_ units: Int = 10000, scalars: Int = 1000, cancelled: Bool = false) throws -> LoadWork {
        LoadWork(budget: try LoadBudget(maximumWork: units, maximumScalars: scalars, isCancelled: { cancelled }))
    }
    static func close(_ a: Double, _ b: Double, tolerance: Double = 1e-9) -> Bool { abs(a-b) <= tolerance * max(1,abs(a),abs(b)) }
    static func close(_ a: Vector3, _ b: Vector3, tolerance: Double = 1e-9) -> Bool {
        close(a.x,b.x,tolerance:tolerance) && close(a.y,b.y,tolerance:tolerance) && close(a.z,b.z,tolerance:tolerance)
    }
}
