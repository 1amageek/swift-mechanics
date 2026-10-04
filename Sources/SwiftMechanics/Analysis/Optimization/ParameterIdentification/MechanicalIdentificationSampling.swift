internal enum MechanicalIdentificationSampling {
    @inline(never)
    static func sample(_ observation:ForceObservation,source:PrismaticIdentificationSource,mass:Double,damping:Double,
        equations:any RigidEquationComputing,derivatives:any MechanicalDifferentiating,loads:any ScalarLoadEvaluating,
        policy:IdentificationPolicy,workspace:inout MechanicalDerivativeWorkspace,loadWork:inout LoadWork,
        supplierWork:inout DerivativeSupplierWork,context:inout IdentificationContext,work:inout NumericalWork) throws(IdentificationCause) -> (Double,Double,Double) {
        try IdentificationArithmetic.charge(40,policy,&work)
        guard context.modelAttempts < policy.maximumModelValidationAttempts else { throw .capacity }
        context.modelAttempts += 1
        let reference=source.referenceInertias[1].properties
        let inertia=try IdentificationArithmetic.core { () throws(CoreError) in try reference.inertiaAtCenter.scaled(by:mass/reference.mass) }
        let properties:MassProperties3D
        do { properties=try MassProperties3D(mass:mass,centerOfMass:reference.centerOfMass,inertiaAtCenter:inertia,policy:policy.inertiaValidation) }
        catch let error as ModelError { throw .model(error) }
        catch let error as CoreError { throw .core(error) }
        catch { throw .invalidSupplierOutput }
        var inertias=source.referenceInertias
        do { inertias[1]=try RigidBodyInertia(body:source.body.id,frame:source.referenceInertias[1].frame,properties:properties) }
        catch { throw .dynamics(error) }
        let response=try dashpot(observation,source:source,damping:damping,loads:loads,policy:policy,context:&context,work:&work,loadWork:&loadWork)
        let contribution:GeneralizedForceContribution
        do { contribution=try GeneralizedForceContribution(values:[response.dissipative],channel:.applied,potentialEnergy:0,dissipatedPower:response.dissipatedPower) }
        catch { throw .dynamics(error) }
        let input=MechanicalDerivativeInput(tree:source.tree,state:observation.state,inertias:inertias,gravity:nil,generalizedForces:[contribution],drive:[0])
        let first=try product(input,observation:observation,source:source,massDirection:true,equations:equations,derivatives:derivatives,
            policy:policy,workspace:&workspace,loadWork:&loadWork,supplierWork:&supplierWork,context:&context,work:&work)
        let second=try product(input,observation:observation,source:source,massDirection:false,equations:equations,derivatives:derivatives,
            policy:policy,workspace:&workspace,loadWork:&loadWork,supplierWork:&supplierWork,context:&context,work:&work)
        guard try IdentificationArithmetic.agrees(first.0,second.0,policy.physicalAgreement) else { throw .originalEvidenceRejected }
        // An independent check for the admitted unit-axis translation rejects a wrong product rather than substituting it.
        let massReference=source.referenceInertias[1].properties.mass
        guard try IdentificationArithmetic.agrees(first.1*massReference,observation.state.acceleration[0]*massReference,policy.physicalAgreement),
              try IdentificationArithmetic.agrees(second.1,observation.state.v[0],policy.normalizedAgreement) else { throw .originalEvidenceRejected }
        return (first.0,first.1,second.1)
    }
    @inline(never)
    private static func dashpot(_ observation:ForceObservation,source:PrismaticIdentificationSource,damping:Double,
        loads:any ScalarLoadEvaluating,policy:IdentificationPolicy,context:inout IdentificationContext,
        work:inout NumericalWork,loadWork:inout LoadWork) throws(IdentificationCause) -> ScalarLoadResponse {
        let law:PolynomialSpringDamper
        do { law=try PolynomialSpringDamper(coordinateKind:.translation,restCoordinate:source.dashpotRestCoordinate,
            quadraticStiffness:0,linearDamping:damping,maximumDisplacement:source.maximumDisplacement,maximumRate:source.maximumRate) }
        catch { throw .loads(error) }
        let budget=loadWork.budget
        var nested:LoadWork
        do {
            nested=LoadWork(budget:try LoadBudget(maximumWork:budget.maximumWork-loadWork.consumed,maximumScalars:budget.maximumScalars,isCancelled:budget.isCancelled))
            try nested.charge(1)
        } catch { throw .loads(error) }
        let before=nested
        var failure:LoadError?
        var result:ScalarLoadResponse?
        do { result=try loads.evaluate(law,coordinate:observation.state.q[0],rate:observation.state.v[0],work:&nested) }
        catch { failure=error }
        guard nested.budget.maximumWork == before.budget.maximumWork,nested.budget.maximumScalars == before.budget.maximumScalars,
              nested.consumed >= before.consumed,nested.peakScalars >= before.peakScalars else {
            context.unavailable=true
            do { try loadWork.charge(before.consumed);try loadWork.reserve(scalars:before.peakScalars) } catch { throw .loads(error) }
            throw .invalidSupplierLedger
        }
        do { try loadWork.charge(nested.consumed);try loadWork.reserve(scalars:nested.peakScalars) } catch { throw .loads(error) }
        if let failure { throw .loads(failure) }
        guard let result else { throw .invalidSupplierOutput }
        try IdentificationArithmetic.charge(9,policy,&work)
        let expected=try IdentificationArithmetic.finite(-damping*observation.state.v[0])
        let power=try IdentificationArithmetic.finite(-expected*observation.state.v[0])
        guard result.conservative == 0,result.active == 0,result.coordinateDerivative == 0,result.potentialEnergy == 0,
              try IdentificationArithmetic.agrees(result.dissipative,expected,policy.physicalAgreement),
              try IdentificationArithmetic.agrees(result.rateDerivative,-damping,policy.normalizedAgreement),
              try IdentificationArithmetic.agrees(result.dissipatedPower,power,policy.physicalAgreement) else { throw .invalidSupplierOutput }
        try IdentificationArithmetic.check(policy)
        return result
    }
    @inline(never)
    private static func product(_ input:MechanicalDerivativeInput,observation:ForceObservation,source:PrismaticIdentificationSource,
        massDirection:Bool,equations:any RigidEquationComputing,derivatives:any MechanicalDifferentiating,
        policy:IdentificationPolicy,workspace:inout MechanicalDerivativeWorkspace,loadWork:inout LoadWork,
        supplierWork:inout DerivativeSupplierWork,context:inout IdentificationContext,work:inout NumericalWork) throws(IdentificationCause) -> (Double,Double) {
        // Precharge the boundary copies and bounded three-ledger reconciliation before the supplier can fail/reset them.
        try IdentificationArithmetic.charge(72,policy,&work)
        let unitInertia=try IdentificationArithmetic.core { () throws(CoreError) in try source.referenceInertias[1].properties.inertiaAtCenter.scaled(by:1/source.referenceInertias[1].properties.mass) }
        let directions=[BodyInertiaDirection(body:input.inertias[0].body,frame:input.inertias[0].frame),
            BodyInertiaDirection(body:input.inertias[1].body,frame:input.inertias[1].frame,mass:massDirection ? 1 : 0,inertiaAtCenter:massDirection ? unitInertia : .zero)]
        let d=MechanicalDirection(tree:TreeDirection(revision:source.tree.revision,configuration:[0],velocity:[0],acceleration:[0],screwPitch:[0]),
            inertias:directions,generalizedForces:[[massDirection ? 0 : -observation.state.v[0]]],drive:[0])
        var nested=try IdentificationArithmetic.nested(work,reserved:context.reserved)
        do { try supplierWork.chargeCall() } catch { throw .derivative(error) }
        let before=nested,calls=supplierWork,oldLoad=loadWork
        var failure:DerivativeError?,value:MechanicalTangent?
        do { value=try derivatives.direction(input,direction:d,jointPolicy:policy.joint,admission:policy.dynamics,policy:policy.derivative,
            workspace:&workspace,loadWork:&loadWork,supplierWork:&supplierWork,work:&nested) }
        catch { failure=error }
        try reconcile(nested,before:before,callsBefore:calls,loadBefore:oldLoad,loadWork:&loadWork,
            supplierWork:&supplierWork,context:&context,work:&work)
        if let failure {
            switch failure {
            case .invalidSupplierLedger(let flag): context.unavailable = context.unavailable || flag
            case .dynamics(_,let flag),.joints(_,let flag),.constraints(_,let flag): context.unavailable = context.unavailable || flag
            default: break
            }
            throw .derivative(failure)
        }
        guard let tangent=value,tangent.massMatrix.count == 1,tangent.inertialBias.count == 1,tangent.totalForce.count == 1,
              tangent.system.input.velocity.count == 1,tangent.system.input.inertias.count == 2,
              tangent.tree.snapshot.bodies.count == 2,tangent.tree.snapshot.tree.bodies.count == 2,
              tangent.tree.snapshot.tree.joints.count == 1 else { throw .invalidSupplierOutput }
        let actualTree=tangent.tree.snapshot.tree
        for i in 0..<2 {
            try IdentificationArithmetic.id(actualTree.bodies[i].id,policy,&context,&work)
            try IdentificationArithmetic.id(actualTree.bodies[i].frame,policy,&context,&work)
        }
        try IdentificationArithmetic.id(actualTree.worldFrame,policy,&context,&work)
        let joint=actualTree.joints[0]
        try IdentificationArithmetic.id(joint.id,policy,&context,&work)
        try IdentificationArithmetic.id(joint.parentBody,policy,&context,&work)
        try IdentificationArithmetic.id(joint.childBody,policy,&context,&work)
        try IdentificationArithmetic.id(joint.parentAnchor.frame,policy,&context,&work)
        try IdentificationArithmetic.id(joint.childAnchor.frame,policy,&context,&work)
        for inertia in tangent.system.input.inertias {
            try IdentificationArithmetic.id(inertia.body,policy,&context,&work)
            try IdentificationArithmetic.id(inertia.frame,policy,&context,&work)
        }
        guard actualTree.revision == source.tree.revision,actualTree.worldFrame == source.tree.worldFrame,actualTree.bodies == source.tree.bodies,
              actualTree.joints == source.tree.joints,tangent.tree.snapshot.time == observation.state.time,
              tangent.system.input.velocity == observation.state.v,tangent.system.input.inertias == input.inertias else { throw .invalidSupplierOutput }
        let live=try IdentificationArithmetic.sum(context.reserved,nested.peakScalarStorage)
        var original=try IdentificationArithmetic.nested(work,reserved:live)
        let originalBefore=original
        var output=[Double](repeating:.nan,count:1),originalFailure:DynamicsError?
        do { try equations.originalInertialForce(tangent.system,acceleration:observation.state.acceleration,includeBias:true,into:&output,work:&original) }
        catch { originalFailure=error }
        try IdentificationArithmetic.ledger(original,originalBefore,reserved:live,&context,&work)
        try IdentificationArithmetic.absorb(original,reserved:live,&work)
        if let originalFailure {
            if case .numerical(_,let flag)=originalFailure { context.unavailable=context.unavailable || flag }
            throw .dynamics(originalFailure)
        }
        guard output.count == 1,output[0].isFinite else { throw .invalidSupplierOutput }
        guard try IdentificationArithmetic.agrees(output[0],input.inertias[1].properties.mass*observation.state.acceleration[0],policy.physicalAgreement) else { throw .originalEvidenceRejected }
        let force:Double
        do { force=try tangent.system.forces.total(at:0) } catch { throw .dynamics(error) }
        guard try IdentificationArithmetic.agrees(force,input.generalizedForces[0].values[0],policy.physicalAgreement) else { throw .originalEvidenceRejected }
        try IdentificationArithmetic.charge(8,policy,&work)
        let residual=try IdentificationArithmetic.finite(output[0]-force-observation.appliedForceNewtons)
        let column=try IdentificationArithmetic.finite(tangent.massMatrix[0]*observation.state.acceleration[0]+tangent.inertialBias[0]-tangent.totalForce[0])
        try IdentificationArithmetic.check(policy)
        return (residual,column)
    }
    @inline(never)
    private static func reconcile(_ numerical:NumericalWork,before:NumericalWork,callsBefore:DerivativeSupplierWork,
        loadBefore:LoadWork,loadWork:inout LoadWork,supplierWork:inout DerivativeSupplierWork,
        context:inout IdentificationContext,work:inout NumericalWork) throws(IdentificationCause) {
        // Inspect every ledger before a fallible restoration/absorption can choose the failure.
        let numericalValid=numerical.budget == before.budget && numerical.operations >= before.operations &&
            numerical.iterations >= before.iterations && numerical.peakScalarStorage >= before.peakScalarStorage
        let callsValid=supplierWork.maximumCalls == callsBefore.maximumCalls && supplierWork.calls >= callsBefore.calls
        let observedLoad=loadWork
        let loadValid=observedLoad.budget.maximumWork == loadBefore.budget.maximumWork &&
            observedLoad.budget.maximumScalars == loadBefore.budget.maximumScalars &&
            observedLoad.consumed >= loadBefore.consumed && observedLoad.peakScalars >= loadBefore.peakScalars
        if !callsValid { supplierWork=callsBefore }
        // Closure identity cannot be compared. Preserve the original cancellation authority unconditionally.
        loadWork=loadBefore
        var loadFailure:LoadError?
        if loadValid {
            do {
                try loadWork.charge(observedLoad.consumed-loadBefore.consumed)
                try loadWork.reserve(scalars:observedLoad.peakScalars)
            } catch {
                loadFailure=error
                if loadWork.consumed < observedLoad.consumed || loadWork.peakScalars < observedLoad.peakScalars { context.unavailable=true }
            }
        }
        if !numericalValid || !callsValid || !loadValid { context.unavailable=true }
        try IdentificationArithmetic.absorb(numericalValid ? numerical : before,reserved:context.reserved,&work)
        guard numericalValid,callsValid,loadValid else { throw .invalidSupplierLedger }
        if let loadFailure { throw .loads(loadFailure) }
    }
}
