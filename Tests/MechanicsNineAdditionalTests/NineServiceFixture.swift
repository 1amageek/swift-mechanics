import SwiftMechanics

struct NineServiceFixture {
    static func near(_ a: Double, _ b: Double, absolute: Double = 1e-9, relative: Double = 1e-7) -> Bool {
        abs(a-b) <= absolute + relative * max(abs(a), abs(b))
    }
    static func tensorNear(_ a: SymmetricTensor, _ b: SymmetricTensor) -> Bool {
        near(a.xx,b.xx) && near(a.yy,b.yy) && near(a.zz,b.zz) && near(a.xy,b.xy) && near(a.yz,b.yz) && near(a.xz,b.xz)
    }
    static func work(maximumWork: Int = 10000, maximumScalars: Int = 1000, cancelled: Bool = false) throws -> LoadWork {
        LoadWork(budget: try LoadBudget(maximumWork: maximumWork, maximumScalars: maximumScalars, isCancelled: { cancelled }))
    }
    static func domain() throws -> StrainDomain { try StrainDomain(maximumStrainNorm: 0.5, minimumVolumeRatio: 0.5) }
}
