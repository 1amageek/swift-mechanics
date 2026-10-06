/// Authority for the original force law, ideal linkage and compiled physical inertia.
public final class NonlinearStabilitySource: Sendable {
    public let model: StaticForceModel
    public let constraints: StaticConstraints?
    public let compiled: CompiledMechanicalModel
    public let branch: EquilibriumBranch
    public let time: Double
    public let limits: EquilibriumLimits
    public let freeCoordinates: Int
    /// Coordinate-major physical basis derived from the actual constraint rows.
    public let nullBasis: [Double]
    public let count: Int
    internal let rowCount: Int
    internal let dimension: Int
    internal let reserve: Int
    @inline(never)
    public init(model: StaticForceModel, constraints: StaticConstraints?, compiled: CompiledMechanicalModel,
                branch: EquilibriumBranch, time: Double, limits: EquilibriumLimits, work: inout NumericalWork)
        throws(NonlinearStabilityFailure) {
        do throws(NonlinearStabilityFailure.Cause) {
            let n=model.chart.count,r=constraints?.system.rows.count ?? 0
            guard n<=limits.coordinates,r<=limits.rows,compiled.tree.bodies.count<=limits.bodies else { throw NonlinearStabilityFailure.Cause.capacityExceeded }
            guard n>=2,r<=n-2,time.isFinite,branch.minimumPosition.count==n,branch.maximumPosition.count==n else { throw NonlinearStabilityFailure.Cause.unsupportedDomain }
            guard case .springs=model.law else { throw NonlinearStabilityFailure.Cause.unsupportedDomain }
            let d=try StabilityArithmetic.sum(try StabilityArithmetic.sum(n,r),1)
            let dense=try StabilityArithmetic.product(200,try StabilityArithmetic.product(d,d))
            let binding=try StabilityArithmetic.sum(try StabilityArithmetic.product(64,try StabilityArithmetic.product(n,compiled.tree.bodies.count)),try StabilityArithmetic.product(32,compiled.tree.frameCount))
            let reserve=try StabilityArithmetic.sum(dense,binding)
            try StabilityArithmetic.numerical { () throws(NumericalError) in try work.requireStorage(reserve) }
            try StabilityMetadataAdmission.validate(model: model, compiled: compiled, branch: branch, limit: limits.identifierBytes, work: &work)
            try Self.binding(model,compiled:compiled,work:&work)
            if let c=constraints {
                let s=c.system
                guard s.layout.revision==model.chart.stamp.revision,c.policy.evaluation.expectedLayoutRevision==s.layout.revision,
                    s.layout.coordinateIDs==model.chart.coordinateIDs,s.layout.dimensions==model.chart.dimensions,s.layout.scales==model.chart.scales else { throw NonlinearStabilityFailure.Cause.staleSource }
                guard time>=s.minimumTime,time<=s.maximumTime else { throw NonlinearStabilityFailure.Cause.outsideDomain }
                let nn=try StabilityArithmetic.product(n,n)
                for row in s.rows {
                    guard row.linear.count==n,row.hessian.count==nn,row.mixedTime.count==n else { throw NonlinearStabilityFailure.Cause.invalidInput }
                    guard row.timeLinear==0,row.timeQuadratic==0,row.hessian.allSatisfy({$0==0}),row.mixedTime.allSatisfy({$0==0}) else { throw NonlinearStabilityFailure.Cause.unsupportedDomain }
                }
            }
            let basis=try Self.basis(model,constraints:constraints,work:&work)
            self.model=model;self.constraints=constraints;self.compiled=compiled;self.branch=branch;self.time=time;self.limits=limits
            self.count=n;self.rowCount=r;self.dimension=d;self.freeCoordinates=n-r;self.nullBasis=basis;self.reserve=reserve
        } catch { throw NonlinearStabilityFailure(error,work:work) }
    }
    @inline(never)
    private static func binding(_ model: StaticForceModel, compiled: CompiledMechanicalModel, work: inout NumericalWork)
        throws(NonlinearStabilityFailure.Cause) {
        let chart=model.chart,n=chart.count,tree=compiled.tree
        guard chart.stamp==compiled.stamp,chart.frame==tree.worldFrame,tree.revision==chart.stamp.revision else { throw .staleSource }
        guard tree.rootBase == .fixed,compiled.descriptor.rootAuthority == .fixed,
            tree.layout.positionCount==n,tree.layout.velocityCount==n else { throw .unsupportedDomain }
        try StabilityArithmetic.charge(try StabilityArithmetic.product(16,try StabilityArithmetic.sum(tree.joints.count,compiled.descriptor.bodies.count)),&work)
        var offset=0
        for joint in tree.joints {
            if joint.manifold.kind == .fixed { continue }
            guard joint.manifold.kind == .prismatic || joint.manifold.kind == .revolute || joint.manifold.kind == .screw,
                joint.manifold.positionCount==1,joint.manifold.velocityCount==1,
                case .fixed=joint.parentAnchor.placement,case .fixed=joint.childAnchor.placement else { throw .unsupportedDomain }
            guard offset<n,chart.joints[offset]==joint.id,chart.dimensions[offset]==(joint.manifold.kind == .prismatic ? .length : .angle) else { throw .staleSource }
            offset+=1
        }
        guard offset==n else { throw .staleSource }
        for joint in compiled.descriptor.joints {
            if joint.record.manifold.velocityCount>0 { guard joint.authority == .dynamicState else { throw .unsupportedDomain } }
        }
        for body in compiled.descriptor.bodies {
            guard case .spatial(let record)=body,record.inertia != nil else { throw .unsupportedDomain }
        }
    }
    @inline(never)
    private static func basis(_ model: StaticForceModel, constraints: StaticConstraints?, work: inout NumericalWork)
        throws(NonlinearStabilityFailure.Cause) -> [Double] {
        let n=model.chart.count,r=constraints?.system.rows.count ?? 0,k=n-r
        var a=[Double](repeating:0,count:try StabilityArithmetic.product(r,n))
        if let c=constraints { for j in 0..<r { for i in 0..<n { a[j*n+i]=c.system.rows[j].linear[i] } } }
        var maximum=0.0;for x in a { maximum=max(maximum,abs(x)) }
        let tolerance=(constraints?.policy.rankRelativeTolerance ?? 0)*maximum
        var pivots:[Int]=[];pivots.reserveCapacity(r)
        try StabilityArithmetic.charge(try StabilityArithmetic.product(8,try StabilityArithmetic.product(n,try StabilityArithmetic.product(max(1,r),max(1,r)))),&work)
        for col in 0..<n {
            if pivots.count==r { break }
            let row=pivots.count;var pivot=row
            for j in row..<r { if abs(a[j*n+col])>abs(a[pivot*n+col]) { pivot=j } }
            if abs(a[pivot*n+col])<=tolerance { continue }
            if pivot != row { for i in 0..<n { a.swapAt(row*n+i,pivot*n+i) } }
            let divisor=a[row*n+col]
            for i in 0..<n { a[row*n+i]/=divisor }
            for j in 0..<r where j != row { let factor=a[j*n+col];for i in 0..<n { a[j*n+i]-=factor*a[row*n+i] } }
            pivots.append(col)
        }
        guard pivots.count==r else { throw .unsupportedDomain }
        var result=[Double](repeating:0,count:try StabilityArithmetic.product(n,k));var slot=0
        for col in 0..<n where !pivots.contains(col) {
            result[col*k+slot]=model.chart.scales[col]
            for j in 0..<r { result[pivots[j]*k+slot] = -a[j*n+col]*model.chart.scales[pivots[j]] }
            slot+=1
        }
        try StabilityArithmetic.finite(result)
        if let c=constraints { for row in c.system.rows { for j in 0..<k {
            var value=0.0,scale=0.0
            for i in 0..<n { let term=row.linear[i]*result[i*k+j]/model.chart.scales[i];value+=term;scale+=abs(term) }
            guard value.isFinite,abs(value)<=c.policy.originalResidualTolerance*max(1,scale) else { throw .originalResidualRejected }
        } } }
        return result
    }
}
