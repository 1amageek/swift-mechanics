import SwiftMechanics

internal struct PlanarPrescribedRootGravitySupplier: GravityEvaluating {
    let foreign: AffineGravity?
    let fails: Bool
    init(foreign: AffineGravity? = nil, fails: Bool = false) { self.foreign=foreign;self.fails=fails }
    func point(_ field: AffineGravity, body: EntityID, sample: GravitySample, work: inout LoadWork) throws(LoadError) -> GravityResponse {
        let response=try GravityEvaluator().point(foreign ?? field,body:body,sample:sample,work:&work)
        if fails { throw .providerFailure(26) }
        return response
    }
    func distributed(_ field: AffineGravity, body: EntityID, samples: [GravitySample], referencePoint: Vector3,
                     work: inout LoadWork) throws(LoadError) -> EquivalentLoad {
        try GravityEvaluator().distributed(foreign ?? field,body:body,samples:samples,referencePoint:referencePoint,work:&work)
    }
}
