import SwiftMechanics

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,visionOS 2.0,*)
internal struct PlanarReactionCancellingGravity: GravityEvaluating {
    let flag: PlanarReactionCancellationFlag
    func point(_ field:AffineGravity,body:EntityID,sample:GravitySample,work:inout LoadWork) throws(LoadError)->GravityResponse {
        let original=try GravityEvaluator().point(field,body:body,sample:sample,work:&work)
        flag.cancel()
        return original
    }
    func distributed(_ field:AffineGravity,body:EntityID,samples:[GravitySample],referencePoint:Vector3,work:inout LoadWork) throws(LoadError)->EquivalentLoad {
        try GravityEvaluator().distributed(field,body:body,samples:samples,referencePoint:referencePoint,work:&work)
    }
}
