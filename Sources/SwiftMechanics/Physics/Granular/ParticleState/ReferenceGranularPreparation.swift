public struct ReferenceGranularPreparation: GranularPreparing, Sendable {
    private let evaluator: any ContactLawEvaluating
    public init(evaluator: any ContactLawEvaluating = CompliantContactEvaluator()) { self.evaluator=evaluator }
    @inline(never)
    public func prepare(revision: UInt64, frame: ModelReference, particles: [GranularParticle], boundaries: [GranularBoundary], laws: [ContactLawPair],
        motions: [GranularMotion], random: RuntimeRandomState, timeSeconds: Double, policy: GranularPolicy,
        numericalWork: inout NumericalWork, contactWork: inout ContactWork, supplierWork: inout GranularSupplierWork) throws(GranularError) -> GranularState {
        try GranularArithmetic.check(policy)
        let n=particles.count, m=boundaries.count
        guard n > 0, motions.count == n, frame.id.kind == .frame, timeSeconds.isFinite, timeSeconds >= 0 else { throw .invalidInput }
        try GranularAdmission.capacity(n,m,policy:policy)
        let count=try GranularArithmetic.addCount(GranularArithmetic.product(n,n-1)/2,GranularArithmetic.product(n,m))
        guard laws.count == count else { throw .invalidBinding }
        guard count <= policy.maximumContacts else { throw .capacity(resource:"contacts",limit:policy.maximumContacts) }
        try GranularArithmetic.storage(GranularArithmetic.addCount(GranularArithmetic.product(n,32),GranularArithmetic.product(count,100)),work:&numericalWork)
        for i in 0..<n {
            try GranularAdmission.proxy(particles[i].proxy,body:particles[i].body,frame:frame,policy:policy,work:&numericalWork)
            guard motions[i].position == particles[i].proxy.pose.translation else { throw .invalidInput }
            for j in 0..<i { try GranularAdmission.distinct(particles[i].proxy,particles[j].proxy,policy:policy,work:&numericalWork) }
        }
        for i in 0..<m {
            try GranularAdmission.proxy(boundaries[i].proxy,body:boundaries[i].body,frame:frame,policy:policy,work:&numericalWork)
            for particle in particles { try GranularAdmission.distinct(boundaries[i].proxy,particle.proxy,policy:policy,work:&numericalWork) }
            for j in 0..<i { try GranularAdmission.distinct(boundaries[i].proxy,boundaries[j].proxy,policy:policy,work:&numericalWork) }
        }
        var bindings=[GranularBinding](); bindings.reserveCapacity(count)
        var contacts=[GranularContactState](); contacts.reserveCapacity(count)
        for i in 0..<n {
            for j in (i+1)..<n { try append(first:i,second:j,boundary:nil,firstProxy:particles[i].proxy,secondProxy:particles[j].proxy,
                firstBody:particles[i].body,secondBody:particles[j].body,firstMaterial:particles[i].material,secondMaterial:particles[j].material,
                law:laws[bindings.count],frame:frame,time:timeSeconds,policy:policy,bindings:&bindings,contacts:&contacts,
                numericalWork:&numericalWork,contactWork:&contactWork,supplierWork:&supplierWork) }
        }
        for i in 0..<n { for j in 0..<m { try append(first:i,second:nil,boundary:j,firstProxy:particles[i].proxy,secondProxy:boundaries[j].proxy,
            firstBody:particles[i].body,secondBody:boundaries[j].body,firstMaterial:particles[i].material,secondMaterial:boundaries[j].material,
            law:laws[bindings.count],frame:frame,time:timeSeconds,policy:policy,bindings:&bindings,contacts:&contacts,
            numericalWork:&numericalWork,contactWork:&contactWork,supplierWork:&supplierWork) } }
        try GranularArithmetic.check(policy)
        return GranularState(model:GranularModel(revision:revision,frame:frame,particles:particles,boundaries:boundaries,bindings:bindings),
            motions:motions,contacts:contacts,random:random,timeSeconds:timeSeconds,steps:0)
    }
    @inline(never)
    private func append(first: Int, second: Int?, boundary: Int?, firstProxy: CollisionProxy, secondProxy: CollisionProxy,
        firstBody: ModelReference, secondBody: ModelReference, firstMaterial: ModelReference, secondMaterial: ModelReference,
        law: ContactLawPair, frame: ModelReference, time: Double, policy: GranularPolicy,
        bindings: inout [GranularBinding], contacts: inout [GranularContactState], numericalWork: inout NumericalWork,
        contactWork: inout ContactWork, supplierWork: inout GranularSupplierWork) throws(GranularError) {
        try GranularArithmetic.charge(128,policy:policy,work:&numericalWork)
        try GranularArithmetic.key(firstMaterial.id.key,policy:policy,work:&numericalWork)
        try GranularArithmetic.key(secondMaterial.id.key,policy:policy,work:&numericalWork)
        try GranularSupplierValidation.pair(law,policy:policy,work:&numericalWork)
        guard firstMaterial == law.firstMaterial, secondMaterial == law.secondMaterial,
            firstProxy.filter.maskBits & secondProxy.filter.layerBits != 0, secondProxy.filter.maskBits & firstProxy.filter.layerBits != 0 else { throw .invalidBinding }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Instantaneous impact/separate restitution is not this compliant DEM update.
        // Selected separate-impact laws must fail before histories are initialized; no silent damping substitution.
        guard case .compliantDampingOnly=law.lossPolicy else { throw .unsupportedDomain }
        if case .sphere(let firstRadius)=firstProxy.geometry.shape {
            let effective: Double
            if case .sphere(let secondRadius)=secondProxy.geometry.shape { effective=try GranularArithmetic.finite(1/(1/firstRadius+1/secondRadius)) }
            else { effective=firstRadius }
            switch law.parameters.normal {
            case .linear: break
            case .hertz(_,let radius,_,_), .huntCrossley(_,_,let radius,_,_):
                guard abs(radius-effective) <= policy.collision.lengthTolerance else { throw .invalidBinding }
            }
        } else { throw .invalidBinding }
        try GranularArithmetic.key(firstBody.id.key,policy:policy,work:&numericalWork)
        try GranularArithmetic.key(secondBody.id.key,policy:policy,work:&numericalWork)
        try GranularArithmetic.key(frame.id.key,policy:policy,work:&numericalWork)
        let identity: ContactIdentity
        do { identity=try ContactIdentity(key:"granular:"+String(bindings.count),firstBody:firstBody,secondBody:secondBody,frame:frame,
            firstGeometryRevision:firstProxy.geometry.geometryRevision,secondGeometryRevision:secondProxy.geometry.geometryRevision,tangentLayoutRevision:1) }
        catch { throw .contact(error,failedSupplierWorkUnavailable:false) }
        try supplierWork.begin()
        let history: ContactHistory
        history=try GranularSupplierGate.contact(work:&contactWork) { (ledger: inout ContactWork) throws(ContactLawError) in
            try evaluator.initialHistory(identity:identity,pair:law,timeSeconds:time,work:&ledger)
        }
        try GranularSupplierValidation.identity(history.identity,policy:policy,work:&numericalWork)
        try GranularSupplierValidation.identity(identity,policy:policy,work:&numericalWork)
        try GranularSupplierValidation.pair(history.pair,policy:policy,work:&numericalWork)
        guard history.identity == identity, history.pair == law, history.timeSeconds == time, history.sequence == 0,
            history.firstBristleDisplacement == 0, history.secondBristleDisplacement == 0, history.cumulativeTangentialDissipation == 0 else { throw .invalidSupplierOutput }
        bindings.append(GranularBinding(firstParticle:first,secondParticle:second,boundary:boundary,identity:identity,law:law))
        contacts.append(GranularContactState(history:history,basis:nil))
    }
}
