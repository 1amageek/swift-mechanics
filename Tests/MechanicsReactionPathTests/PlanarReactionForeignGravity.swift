import SwiftMechanics

internal struct PlanarReactionForeignGravity: GravityEvaluating {
    func point(_ field:AffineGravity,body:EntityID,sample:GravitySample,work:inout LoadWork) throws(LoadError)->GravityResponse {
        let acceleration:Vector3
        do throws(CoreError) { acceleration=try Vector3(0,-20,0) }
        catch { throw .core(error) }
        let foreign=try AffineGravity(frame:field.frame,accelerationAtOrigin:acceleration)
        return try GravityEvaluator().point(foreign,body:body,sample:sample,work:&work)
    }
    func distributed(_ field:AffineGravity,body:EntityID,samples:[GravitySample],referencePoint:Vector3,work:inout LoadWork) throws(LoadError)->EquivalentLoad {
        try GravityEvaluator().distributed(field,body:body,samples:samples,referencePoint:referencePoint,work:&work)
    }
}
