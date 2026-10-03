import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsCollision
import MechanicsContactLaws
internal enum GranularSupplierValidation {
    static func identity(_ id: ContactIdentity,policy: GranularPolicy,work: inout NumericalWork) throws(GranularError) {
        try GranularArithmetic.key(id.key,policy:policy,work:&work); try GranularArithmetic.key(id.firstBody.id.key,policy:policy,work:&work)
        try GranularArithmetic.key(id.secondBody.id.key,policy:policy,work:&work); try GranularArithmetic.key(id.frame.id.key,policy:policy,work:&work)
        if let s=id.firstMaterialSite { try GranularArithmetic.key(s.key,policy:policy,work:&work) }
        if let s=id.secondMaterialSite { try GranularArithmetic.key(s.key,policy:policy,work:&work) }
    }
    static func pair(_ pair: ContactLawPair,policy: GranularPolicy,work: inout NumericalWork) throws(GranularError) {
        try GranularArithmetic.key(pair.firstMaterial.id.key,policy:policy,work:&work); try GranularArithmetic.key(pair.secondMaterial.id.key,policy:policy,work:&work)
    }
    static func witness(_ w: CollisionWitness,first: CollisionProxy,second: CollisionProxy,policy: GranularPolicy,work: inout NumericalWork) throws(GranularError) {
        try accountGeometry(w.pair.first,policy:policy,work:&work); try accountGeometry(w.pair.second,policy:policy,work:&work)
        guard w.pair.first == first.geometry, w.pair.second == second.geometry, w.poseA == first.pose, w.poseB == second.pose,
            w.separation.isFinite, w.approximationError.isFinite, w.approximationError >= 0,
            w.approximationError <= policy.collision.maximumApproximationError else { throw .invalidSupplierOutput }
        let balance=try GranularArithmetic.norm(GranularArithmetic.sub(GranularArithmetic.sub(w.pointB,w.pointA),GranularArithmetic.scale(w.normal,w.separation)))
        let norm=abs(try GranularArithmetic.norm(w.normal)-1)
        guard balance <= policy.collision.lengthTolerance, norm <= policy.collision.normalTolerance else { throw .invalidSupplierOutput }
    }
    private static func accountGeometry(_ g: CollisionGeometryIdentity,policy: GranularPolicy,work: inout NumericalWork) throws(GranularError) {
        try GranularArithmetic.key(g.colliderID.key,policy:policy,work:&work); try GranularArithmetic.key(g.bodyID.key,policy:policy,work:&work)
        try GranularArithmetic.key(g.frameID.key,policy:policy,work:&work); try GranularArithmetic.key(g.representation.assetKey,policy:policy,work:&work)
        try GranularArithmetic.key(g.representation.provenance.source,policy:policy,work:&work)
    }
    static func response(_ r: ContactResponse,input: ContactInput,binding: GranularBinding,accepted: ContactHistory,h: Double,policy: GranularPolicy,work: inout NumericalWork) throws(GranularError) {
        try identity(r.trialHistory.identity,policy:policy,work:&work); try identity(binding.identity,policy:policy,work:&work)
        try pair(r.trialHistory.pair,policy:policy,work:&work); try pair(binding.law,policy:policy,work:&work)
        let (next,overflow)=accepted.sequence.addingReportingOverflow(1)
        guard !overflow, r.trialHistory.identity == binding.identity, r.trialHistory.pair == binding.law,
            r.acceptedHistorySequence == accepted.sequence, r.trialHistory.sequence == next,
            r.trialHistory.timeSeconds == input.startTimeSeconds+h,
            r.trialHistory.firstBristleDisplacement.isFinite, r.trialHistory.secondBristleDisplacement.isFinite,
            r.trialHistory.cumulativeTangentialDissipation.isFinite, r.trialHistory.cumulativeTangentialDissipation >= accepted.cumulativeTangentialDissipation,
            r.compressiveNormalForce.isFinite, r.compressiveNormalForce >= 0, r.cohesiveNormalForce.isFinite,
            r.normalStoredEnergy.isFinite, r.normalStoredEnergy >= 0, r.tangentialStoredEnergy.isFinite, r.tangentialStoredEnergy >= 0,
            r.cohesivePotentialEnergy.isFinite, r.normalDissipationPower.isFinite, r.normalDissipationPower >= 0,
            r.resistanceDissipationPower.isFinite, r.resistanceDissipationPower >= 0,
            r.tangentialDissipationEnergy.isFinite, r.tangentialDissipationEnergy >= 0 else { throw .invalidSupplierOutput }
        let cumulative=try GranularArithmetic.finite(accepted.cumulativeTangentialDissipation+r.tangentialDissipationEnergy)
        let cumulativeThreshold=try GranularArithmetic.finite(policy.contact.absoluteEnergyTolerance+policy.contact.relativeTolerance*max(policy.contact.referenceEnergy,abs(cumulative)))
        guard abs(r.trialHistory.cumulativeTangentialDissipation-cumulative) <= cumulativeThreshold else { throw .invalidSupplierOutput }
        if case .elasticCoulomb(let friction)=binding.law.parameters.friction {
            let oldU=try GranularArithmetic.finite(0.5*friction.tangentialStiffness*(accepted.firstBristleDisplacement*accepted.firstBristleDisplacement+accepted.secondBristleDisplacement*accepted.secondBristleDisplacement))
            let newU=try GranularArithmetic.finite(0.5*friction.tangentialStiffness*(r.trialHistory.firstBristleDisplacement*r.trialHistory.firstBristleDisplacement+r.trialHistory.secondBristleDisplacement*r.trialHistory.secondBristleDisplacement))
            let tangentVelocity=try GranularArithmetic.sub(input.relativeVelocity,GranularArithmetic.scale(input.basis.normal,GranularArithmetic.dot(input.basis.normal,input.relativeVelocity)))
            let directD=try GranularArithmetic.finite(-h*GranularArithmetic.dot(r.forceOnB,tangentVelocity)-(newU-oldU))
            let threshold=try GranularArithmetic.finite(policy.contact.absoluteEnergyTolerance+policy.contact.relativeTolerance*max(policy.contact.referenceEnergy,max(abs(directD),max(oldU,newU))))
            guard abs(newU-r.tangentialStoredEnergy) <= threshold, abs(directD-r.tangentialDissipationEnergy) <= threshold else { throw .invalidSupplierOutput }
        }
        let expected=try GranularArithmetic.add(GranularArithmetic.scale(input.basis.normal,r.compressiveNormalForce+r.cohesiveNormalForce),
            GranularArithmetic.add(GranularArithmetic.scale(input.basis.firstTangent,r.tangentialForceFirst),GranularArithmetic.scale(input.basis.secondTangent,r.tangentialForceSecond)))
        let residual=try GranularArithmetic.norm(GranularArithmetic.sub(expected,r.forceOnB))
        let scale=try GranularArithmetic.norm(r.forceOnB)
        let forceThreshold=try GranularArithmetic.finite(policy.momentumTolerance/h+policy.relativeTolerance*max(policy.referenceMomentum/h,scale))
        guard residual <= forceThreshold else { throw .invalidSupplierOutput }
        let direct=try GranularArithmetic.finite(GranularArithmetic.dot(r.forceOnB,input.relativeVelocity)+GranularArithmetic.dot(r.coupleOnB,input.relativeAngularVelocity))
        let powerThreshold=try GranularArithmetic.finite(policy.contact.absolutePowerTolerance+policy.contact.relativeTolerance*max(policy.contact.referencePower,abs(direct)))
        guard r.relativeMechanicalPower.isFinite, abs(direct-r.relativeMechanicalPower) <= powerThreshold else { throw .invalidSupplierOutput }
    }
}
