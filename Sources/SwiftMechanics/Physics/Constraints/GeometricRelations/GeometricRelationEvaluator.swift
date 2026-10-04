public struct GeometricRelationEvaluator: HolonomicGeometryProviding, Sendable {
    public init() {}
    @inline(never)
    public func evaluate(_ system:GeometricConstraintSystem,state:KinematicState,policy:ConstraintEvaluationPolicy,
                         work:inout NumericalWork) throws(GeometricConstraintError) -> HolonomicGeometrySample {
        try Self.compute(system,state:state,policy:policy,original:false,work:&work)
    }
    @inline(never)
    internal static func compute(_ system:GeometricConstraintSystem,state:KinematicState,policy:ConstraintEvaluationPolicy,
                                 original:Bool,work:inout NumericalWork) throws(GeometricConstraintError) -> HolonomicGeometrySample {
        let snapshot=try system.snapshot(state,policy:policy,work:&work),n=state.v.count,m=system.rowIDs.count
        let t=system.layout.timeScale,s=system.layout.scales
        var values=[Double](repeating:0,count:m),rows=[Double](repeating:0,count:m*n),drift=values,bias=values
        var start=0,alignmentResiduals:[Vector3]=[];alignmentResiduals.reserveCapacity(system.relations.count)
        for relation in system.relations {
            try GeometricArithmetic.check(policy)
            // Reserve endpoint transformations, lower point callbacks, vector algebra and all row entries before work.
            try GeometricArithmetic.charge(try GeometricArithmetic.numeric { () throws(NumericalError) -> Int in try NumericalWork.product(1024,n+snapshot.tree.bodies.count+1) },&work)
            let a=try GeometricEndpointMotion.make(relation.first,snapshot:snapshot,original:original)
            let b=try GeometricEndpointMotion.make(relation.second,snapshot:snapshot,original:original),target=try relation.target.sample(state.time)
            if relation.kind == .distance,target.value.x <= 0 { throw .outsideDomain }
            if relation.kind == .alignedAxes {
                let dot=try GeometricArithmetic.geometry { try a.axis.dot(b.axis) }
                guard dot*relation.axisSign > 0 else { throw .branchViolation(row:relation.rowIDs[0]) }
            }
            let transverse:[GeometricDirectionMotion]
            if relation.kind == .alignedAxes {
                transverse=[try GeometricDirectionMotion.make(relation.second,frameDirection:relation.transverseFirst,snapshot:snapshot),
                    try GeometricDirectionMotion.make(relation.second,frameDirection:relation.transverseSecond,snapshot:snapshot)]
                alignmentResiduals.append(try GeometricArithmetic.geometry { try a.axis.cross(b.axis) })
            } else { transverse=[] }
            let data:([Double],[Double],[Double],[Double])=try GeometricArithmetic.geometry {
                switch relation.kind {
                case .coincidence:
                    let value=try a.point.subtracting(b.point).subtracting(target.value).scaled(by:1/relation.scale)
                    let d=try a.drift.subtracting(b.drift).subtracting(target.rate).scaled(by:t/relation.scale)
                    let second=try a.bias.subtracting(b.bias).subtracting(relation.target.second).scaled(by:t*t/relation.scale)
                    var matrix=[Double](repeating:0,count:3*n)
                    for j in 0..<n { let c=GeometricArithmetic.components(try a.columns[j].subtracting(b.columns[j]).scaled(by:s[j]/relation.scale));for k in 0..<3 { matrix[k*n+j]=c[k] } }
                    return (GeometricArithmetic.components(value),matrix,GeometricArithmetic.components(d),GeometricArithmetic.components(second))
                case .distance:
                    let r=try a.point.subtracting(b.point),v=try a.velocity.subtracting(b.velocity),d=try a.drift.subtracting(b.drift),acc=try a.bias.subtracting(b.bias)
                    let length=target.value.x,rate=target.rate.x,second=relation.target.second.x,c=relation.scale*relation.scale
                    let value=(try r.dot(r)-length*length)/(2*c)
                    let td=t*(try r.dot(d)-length*rate)/c
                    let ab=t*t*(try v.dot(v)+r.dot(acc)-rate*rate-length*second)/c
                    var matrix=[Double](repeating:0,count:n)
                    for j in 0..<n { matrix[j]=try r.dot(a.columns[j].subtracting(b.columns[j]))*s[j]/c }
                    return ([value],matrix,[td],[ab])
                case .alignedAxes:
                    // A regular two-coordinate chart of relative unit direction; the second-frame basis moves physically.
                    var value=[Double](repeating:0,count:2),d=value,ab=value,matrix=[Double](repeating:0,count:2*n)
                    for k in 0..<2 {
                        let basis=transverse[k]
                        value[k]=try a.axis.dot(basis.direction)
                        d[k]=try t*(a.axisDrift.dot(basis.direction)+a.axis.dot(basis.drift))
                        ab[k]=try t*t*(a.axisBias.dot(basis.direction)+2*a.axisRate.dot(basis.rate)+a.axis.dot(basis.bias))
                        for j in 0..<n { matrix[k*n+j]=try s[j]*(a.axisColumns[j].dot(basis.direction)+a.axis.dot(basis.columns[j])) }
                    }
                    return (value,matrix,d,ab)
                }
            }
            for k in relation.rowIDs.indices {
                values[start+k]=try GeometricArithmetic.finite(data.0[k]);drift[start+k]=try GeometricArithmetic.finite(data.2[k]);bias[start+k]=try GeometricArithmetic.finite(data.3[k])
                for j in 0..<n { rows[(start+k)*n+j]=try GeometricArithmetic.finite(data.1[k*n+j]) }
            }
            start+=relation.rowIDs.count
        }
        try GeometricArithmetic.check(policy)
        return HolonomicGeometrySample(source:state,snapshot:snapshot,metadata:system.metadata,values:values,
            velocity:VelocityConstraintSample(layout:system.layout,rowIDs:system.rowIDs,rows:rows,drift:drift,accelerationBias:bias,isIntegrable:true),alignmentResiduals:alignmentResiduals)
    }
}
