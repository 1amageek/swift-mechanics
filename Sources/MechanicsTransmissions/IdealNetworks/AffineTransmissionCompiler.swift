import MechanicsCore
import MechanicsJoints
import MechanicsNumerics
import MechanicsConstraints

public struct AffineTransmissionCompiler: TransmissionCompiling {
    public init() {}
    @inline(never)
    public func compile(id: UInt64, layout: ConstraintCoordinateLayout, ports: [TransmissionPortBinding], relations: [TransmissionRelation],
                        minimumPosition: [Double], maximumPosition: [Double], minimumTime: Double, maximumTime: Double,
                        policy: TransmissionPolicy, work: inout NumericalWork) throws(TransmissionError) -> CompiledTransmissionNetwork {
        try TransmissionArithmetic.validate(ports,layout:layout,policy:policy,work:&work)
        let n=layout.scales.count, m=relations.count
        guard m > 0, m <= policy.maximumRelations else { throw .capacityExceeded }
        guard minimumPosition.count == n, maximumPosition.count == n, minimumTime.isFinite, maximumTime.isFinite, minimumTime <= maximumTime else { throw .invalidDimensions }
        let square=try TransmissionArithmetic.product(n,n), mn=try TransmissionArithmetic.product(m,n)
        try TransmissionArithmetic.storage(TransmissionArithmetic.sum(square,TransmissionArithmetic.sum(TransmissionArithmetic.product(2,mn),TransmissionArithmetic.sum(TransmissionArithmetic.product(64,m),TransmissionArithmetic.product(2,n)))),&work)
        for i in 0..<n { try TransmissionArithmetic.charge(2,&work); guard minimumPosition[i].isFinite, maximumPosition[i].isFinite, minimumPosition[i] <= maximumPosition[i] else { throw .invalidInput } }
        let zeroHessian=[Double](repeating:0,count:square), zeroLinear=[Double](repeating:0,count:n)
        var physical: [PhysicalTransmissionRow]=[], rows: [QuadraticConstraint]=[]
        physical.reserveCapacity(m); rows.reserveCapacity(m)
        for i in 0..<m {
            try TransmissionArithmetic.check(policy)
            for j in 0..<i { try TransmissionArithmetic.charge(1,&work); guard relations[i].id != relations[j].id else { throw .invalidInput } }
            let row=try compileRow(relations[i],ports:ports,count:n,policy:policy,work:&work)
            var normalized=[Double](repeating:0,count:n)
            for k in 0..<n { try TransmissionArithmetic.charge(2,&work); normalized[k]=try TransmissionArithmetic.finite(row.coefficients[k]*layout.scales[k]/row.phaseScale) }
            try TransmissionArithmetic.charge(1,&work)
            rows.append(QuadraticConstraint(id:row.id,constant:try TransmissionArithmetic.finite(-row.phase/row.phaseScale),linear:normalized,hessian:zeroHessian,timeLinear:0,timeQuadratic:0,mixedTime:zeroLinear))
            physical.append(row)
        }
        let system: QuadraticConstraintSystem
        do { system=try QuadraticConstraintSystem(layout:layout,rows:rows,minimumPosition:minimumPosition,maximumPosition:maximumPosition,minimumTime:minimumTime,maximumTime:maximumTime) } catch { throw .constraint(error) }
        try TransmissionArithmetic.check(policy)
        return CompiledTransmissionNetwork(id:id,modelRevision:policy.expectedModelRevision,ports:ports,physicalRows:physical,equations:system)
    }
    @inline(never)
    private func compileRow(_ relation: TransmissionRelation, ports: [TransmissionPortBinding], count: Int, policy: TransmissionPolicy, work: inout NumericalWork) throws(TransmissionError) -> PhysicalTransmissionRow {
        var c=[Double](repeating:0,count:count)
        let phase: Double, scale: Double, dimension: PhysicalDimension
        switch relation.kind {
        case .externalGear(let first,let second,let a,let b,let p,let s), .internalGear(let first,let second,let a,let b,let p,let s):
            try indices(first,second,ports:ports,work:&work); guard a > 0, b > 0 else { throw .invalidInput }
            let orientation=try TransmissionArithmetic.parallel(ports[first],ports[second],policy,&work)
            let mesh: Double
            if case .externalGear = relation.kind { mesh=1 } else { mesh = -1 }
            try TransmissionArithmetic.charge(1,&work)
            c[ports[first].coordinateIndex]=Double(a); c[ports[second].coordinateIndex]=mesh*orientation*Double(b)
            phase=p; scale=s; dimension = .angle
        case .rackPinion(let pinion,let rack,let radius,let sign,let p,let s):
            try indices(pinion,rack,ports:ports,work:&work)
            guard radius.isFinite, radius > 0, sign == 1 || sign == -1, ports[pinion].manifold.kind == .revolute, ports[rack].manifold.kind == .prismatic else { throw .invalidInput }
            let axis=try TransmissionArithmetic.axis(ports[pinion],&work), direction=try TransmissionArithmetic.axis(ports[rack],&work)
            try TransmissionArithmetic.charge(1,&work); let dot: Double
            do { dot=try axis.dot(direction) } catch { throw .core(error) }
            guard abs(dot) <= policy.geometryTolerance else { throw .incompatibleGeometry }
            try TransmissionArithmetic.charge(1,&work); c[ports[pinion].coordinateIndex] = -Double(sign)*radius; c[ports[rack].coordinateIndex]=1
            phase=p; scale=s; dimension = .length
        case .rigidShaft(let first,let second,let p,let s):
            try indices(first,second,ports:ports,work:&work)
            c[ports[first].coordinateIndex]=1; c[ports[second].coordinateIndex] = -(try TransmissionArithmetic.parallel(ports[first],ports[second],policy,&work))
            phase=p; scale=s; dimension = .angle
        case .pulley(let first,let second,let a,let b,let crossed,let p,let s):
            try indices(first,second,ports:ports,work:&work); guard a.isFinite, a > 0, b.isFinite, b > 0 else { throw .invalidInput }
            let orientation=try TransmissionArithmetic.parallel(ports[first],ports[second],policy,&work)
            try TransmissionArithmetic.charge(1,&work); c[ports[first].coordinateIndex]=a; c[ports[second].coordinateIndex]=(crossed ? 1 : -1)*orientation*b
            phase=p; scale=s; dimension = .length
        case .planetary(let sun,let ring,let carrier,let a,let b,let p,let s):
            try indices(sun,ring,third:carrier,ports:ports,work:&work); guard a > 0, b > a else { throw .invalidInput }
            let ringSign=try TransmissionArithmetic.parallel(ports[sun],ports[ring],policy,&work), carrierSign=try TransmissionArithmetic.parallel(ports[sun],ports[carrier],policy,&work)
            try TransmissionArithmetic.charge(4,&work)
            c[ports[sun].coordinateIndex]=Double(a); c[ports[ring].coordinateIndex]=ringSign*Double(b)
            c[ports[carrier].coordinateIndex] = -carrierSign*(Double(a)+Double(b)); phase=p; scale=s; dimension = .angle
        // FIXME(INCOMPLETE_IMPLEMENTATION): Selected extended geometry/engagement/contact fidelities have no validated transmission equations or physical reaction model in this production compiler. Each must obtain its own original equation/power/state proof before success.
        case .unsupported: throw .unsupportedFidelity
        }
        guard phase.isFinite, scale.isFinite, scale > 0 else { throw .invalidInput }
        return PhysicalTransmissionRow(id:relation.id,coefficients:c,phase:phase,phaseScale:scale,phaseDimension:dimension)
    }
    private func indices(_ first: Int,_ second: Int,third: Int? = nil,ports: [TransmissionPortBinding],work: inout NumericalWork) throws(TransmissionError) {
        try TransmissionArithmetic.charge(5,&work)
        guard first >= 0, first < ports.count, second >= 0, second < ports.count, first != second else { throw .invalidDimensions }
        if let third { try TransmissionArithmetic.charge(4,&work); guard third >= 0, third < ports.count, third != first, third != second else { throw .invalidDimensions } }
    }
}
