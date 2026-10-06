internal enum StabilityInertiaEvidence {
    typealias Cause = NonlinearStabilityFailure.Cause
    @inline(never)
    static func evaluate(_ s: NonlinearStabilitySource, position: [Double], supplier: any RigidEquationComputing,
                         policy p: NonlinearStabilityPolicy, work: inout NumericalWork) throws(Cause) -> (mass: [Double], error: Double) {
        try StabilityArithmetic.check(p)
        let n=s.count,k=s.freeCoordinates,zero=[Double](repeating:0,count:n)
        try StabilityArithmetic.charge(try StabilityArithmetic.product(64,try StabilityArithmetic.product(n,s.compiled.tree.bodies.count)),&work)
        let snapshot: KinematicSnapshot
        do {
            let state=try KinematicState(revision:s.compiled.stamp.revision,time:s.time,q:position,v:zero,acceleration:zero)
            snapshot=try s.compiled.evaluate(s.compiled.makeState(state))
        } catch { throw .compilation }
        var inertias:[RigidBodyInertia]=[];inertias.reserveCapacity(snapshot.bodies.count)
        try StabilityArithmetic.charge(try StabilityArithmetic.product(16,try StabilityArithmetic.product(snapshot.bodies.count,s.compiled.descriptor.bodies.count)),&work)
        for body in snapshot.bodies {
            guard let descriptor=s.compiled.descriptor.bodies.first(where:{$0.id==body.body}),
                case .spatial(let record)=descriptor,record.frame==body.bodyFrame,let original=record.inertia else { throw .staleSource }
            do { inertias.append(try RigidBodyInertia(body:body.body,frame:body.bodyFrame,properties:original.properties)) }
            catch { throw .dynamics(error) }
        }
        let input:RigidDynamicsInput
        do { input=try RigidDynamicsInput(snapshot:snapshot,velocity:zero,inertias:inertias,gravity:nil) } catch { throw .dynamics(error) }
        let remaining=try StabilityArithmetic.numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:0) }
        let loadCap:LoadBudget
        do { loadCap=try LoadBudget(maximumWork:min(p.loadBudget.maximumWork,remaining.arithmeticOperations),maximumScalars:min(p.loadBudget.maximumScalars,remaining.scalarStorage),isCancelled:p.loadBudget.isCancelled) }
        catch { throw .load(error) }
        var load=LoadWork(budget:loadCap)
        let before=work,system:RigidDynamicsSystem
        do { system=try supplier.assemble(input,admission:p.dynamics,loadWork:&load,work:&work) }
        catch { try StabilityArithmetic.prefix(before,&work);try StabilityArithmetic.charge(load.consumed,&work);throw .dynamics(error) }
        try StabilityArithmetic.prefix(before,&work)
        guard system.assemblyWork==work,system.velocityCount==n,system.massMatrix.count==n*n,
            system.input.snapshot.bodies==snapshot.bodies,system.input.snapshot.frames==snapshot.frames,
            system.input.velocity==zero,system.input.inertias==inertias else { throw .invalidSupplierOutput }
        try StabilityArithmetic.numerical { () throws(NumericalError) in try work.requireStorage(try NumericalWork.sum(system.scalarStorage,load.peakScalars)) }
        try StabilityArithmetic.charge(load.consumed,&work)
        try StabilityArithmetic.finite(system.massMatrix)
        var a=zero,f=zero;var maximum=0.0
        let beforeZero=work
        do { try supplier.originalInertialForce(system,acceleration:zero,includeBias:true,into:&f,work:&work) }
        catch { try StabilityArithmetic.prefix(beforeZero,&work);throw .dynamics(error) }
        try StabilityArithmetic.prefix(beforeZero,&work)
        guard f.count==n else { throw .invalidSupplierOutput }
        for i in 0..<n { guard f[i].isFinite,abs(f[i])<=p.evidence.inertialAbsoluteTolerances[i] else { throw .inertialMismatch } }
        for col in 0..<k {
            try StabilityArithmetic.check(p)
            for i in 0..<n { a[i]=s.nullBasis[i*k+col] }
            let beforeAction=work
            do { try supplier.originalInertialForce(system,acceleration:a,includeBias:false,into:&f,work:&work) }
            catch { try StabilityArithmetic.prefix(beforeAction,&work);throw .dynamics(error) }
            try StabilityArithmetic.prefix(beforeAction,&work)
            guard f.count==n else { throw .invalidSupplierOutput }
            try StabilityArithmetic.charge(try StabilityArithmetic.product(4,try StabilityArithmetic.product(n,n)),&work)
            for i in 0..<n {
                var value=0.0;for j in 0..<n { value+=system.massMatrix[i*n+j]*a[j] }
                let error=abs(value-f[i]);maximum=max(maximum,error)
                guard error.isFinite,error<=p.evidence.inertialAbsoluteTolerances[i] else { throw .inertialMismatch }
            }
        }
        try StabilityArithmetic.check(p)
        return (system.massMatrix,maximum)
    }
}
