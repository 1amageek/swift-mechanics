import SwiftMechanics

struct ThreeModelFixture {
    static func near(_ a: Double, _ b: Double, absolute: Double = 1e-10, relative: Double = 1e-8) -> Bool {
        abs(a-b) <= absolute + relative * max(abs(a),abs(b))
    }
    static func vectorNear(_ a: Vector3, _ b: Vector3) -> Bool {
        near(a.x,b.x) && near(a.y,b.y) && near(a.z,b.z)
    }
    static func tensorNear(_ a: SymmetricTensor, _ b: SymmetricTensor) -> Bool {
        near(a.xx,b.xx) && near(a.yy,b.yy) && near(a.zz,b.zz) && near(a.xy,b.xy) && near(a.yz,b.yz) && near(a.xz,b.xz)
    }
    static func work(maximumWork: Int = 10000, maximumScalars: Int = 1000, cancelled: Bool = false) throws -> LoadWork {
        LoadWork(budget: try LoadBudget(maximumWork: maximumWork, maximumScalars: maximumScalars, isCancelled: { cancelled }))
    }
}
