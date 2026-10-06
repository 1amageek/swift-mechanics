import SwiftMechanics

struct ConstitutiveFixture {
    static func near(_ a: Double, _ b: Double, absolute: Double = 1e-10, relative: Double = 1e-7) -> Bool {
        abs(a-b) <= absolute+relative*max(abs(a),abs(b))
    }
    static func matrixNear(_ a: Matrix3, _ b: Matrix3, absolute: Double = 1e-9, relative: Double = 1e-6) throws -> Bool {
        for row in 0..<3 {
            for column in 0..<3 {
                if !near(try a.element(row: row,column: column), try b.element(row: row,column: column),
                    absolute: absolute, relative: relative) { return false }
            }
        }
        return true
    }
    static func diagonal(_ a: Double, _ b: Double, _ c: Double) throws -> Matrix3 {
        try Matrix3(a,0,0,0,b,0,0,0,c)
    }
}
