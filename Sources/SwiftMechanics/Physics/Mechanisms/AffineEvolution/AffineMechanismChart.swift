
internal enum AffineMechanismChart {
    static func signature(_ system:QuadraticConstraintSystem,drive:[Double],tolerance:Double,maximumBytes:Int) throws(MechanismError) -> String {
        let n=system.layout.scales.count,m=system.rows.count
        let fields=try MechanismArithmetic.numerical { () throws(NumericalError) in
            try NumericalWork.sum(try NumericalWork.product(m,try NumericalWork.sum(4,n)),try NumericalWork.sum(try NumericalWork.product(5,n),5))
        }
        let maximum=try MechanismArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(32,try NumericalWork.product(fields,17)) }
        guard maximumBytes >= maximum else { throw .capacityExceeded }
        var value="affine-scalar-index-reduced-v1"
        func put(_ bits:UInt64) { value.append(":");value.append(String(bits,radix:16)) }
        put(system.layout.revision);put(system.layout.timeScale.bitPattern);put(system.minimumTime.bitPattern);put(system.maximumTime.bitPattern);put(tolerance.bitPattern)
        for i in 0..<n { put(system.layout.coordinateIDs[i]);put(system.layout.scales[i].bitPattern);put(system.minimumPosition[i].bitPattern);put(system.maximumPosition[i].bitPattern);put(drive[i].bitPattern) }
        for row in system.rows {
            put(row.id);put(row.constant.bitPattern);put(row.timeLinear.bitPattern);put(UInt64(row.linear.count))
            for entry in row.linear { put(entry.bitPattern) }
        }
        return value
    }
    static func bounded(_ text:String,maximum:Int) throws(MechanismError) {
        guard maximum >= 0,!text.isEmpty else { throw .invalidInput }
        var count=0
        for _ in text.utf8 { guard count < maximum else { throw .capacityExceeded };count+=1 }
    }
}
