import MechanicsFlexible
import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsCollision
public struct SelectedSurfaceWitnessQueries: SurfaceWitnessQuerying {
    private let geometry: any CollisionGeometryQuerying
    public init(geometry: any CollisionGeometryQuerying = AnalyticCollisionQueries()) { self.geometry=geometry }
    @inline(never)
    public func plane(_ s: DeformingSurfaceSnapshot, face: SurfaceFeatureID, obstacle: CollisionProxy, obstacleBody: ModelReference,
                      policy p: DeformingContactPolicy, collisionPolicy: CollisionQueryPolicy, work: inout NumericalWork,
                      collisionWork: inout CollisionWork) throws(DeformingContactError) -> SurfaceContactWitness {
        try SurfaceQueryAdmission.snapshot(s,policy:p,work:&work)
        try SurfaceArithmetic.text(obstacleBody.id.key,p,&work)
        try SurfaceQueryAdmission.geometry(obstacle.geometry,policy:p,work:&work)
        guard let triangle=s.surface.triangles.first(where: { $0.feature == face }), obstacleBody.id == obstacle.geometry.bodyID,
              obstacle.geometry.frameID == s.state.frame, obstacle.geometry.frameRevision == s.surface.mesh.mesh.revision else { throw .staleGeometry }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Other obstacle shapes reach surface contact queries.
        // Exact triangle feature admission and independent geometric residuals are required before qualification.
        guard case .halfSpace=obstacle.geometry.shape, obstacle.geometry.margin == 0, obstacle.geometry.resolution == .analytic else { throw .unsupportedDomain }
        guard obstacle.filter.enabled, !obstacle.filter.isTrigger else { throw .invalidInput }
        try SurfaceArithmetic.numerical { () throws(NumericalError) in try work.requireStorage(512) }
        var samples: [CollisionPointResult]=[]; samples.reserveCapacity(3)
        for node in triangle.nodes {
            try SurfaceArithmetic.charge(512,p,&work)
            let previous=collisionWork
            var captured: CollisionPointResult?, failure: CollisionError?
            do throws(CollisionError) { captured=try geometry.point(proxy:obstacle,query:s.state.positions[node],policy:collisionPolicy,work:&collisionWork) }
            catch { failure=error }
            guard collisionWork.budget == previous.budget, collisionWork.operations >= previous.operations,
                  collisionWork.peakScalarStorage >= previous.peakScalarStorage else { collisionWork=previous; throw .supplierLedgerReplaced }
            if let failure { throw .collision(failure,failedSupplierWorkUnavailable:true) }
            guard let sample=captured else { throw .invalidSupplierOutput }
            samples.append(sample)
            try SurfaceQueryAdmission.geometry(sample.geometry,policy:p,work:&work)
            let outward=try SurfaceArithmetic.core { () throws(CoreError) in try obstacle.pose.transforming(direction:.unitZ) }
            let distance=try SurfaceArithmetic.core { () throws(CoreError) in try s.state.positions[node].subtracting(obstacle.pose.translation).dot(outward) }
            let expected=try SurfaceArithmetic.core { () throws(CoreError) in try s.state.positions[node].subtracting(outward.scaled(by:distance)) }
            let normalError=try SurfaceArithmetic.core { () throws(CoreError) in try sample.outwardNormal.subtracting(outward).magnitude() }
            let pointError=try SurfaceArithmetic.core { () throws(CoreError) in try sample.boundaryPoint.subtracting(expected).magnitude() }
            guard sample.geometry == obstacle.geometry, sample.degeneracy == .regular, sample.signedDistance.isFinite,
                  abs(sample.signedDistance-distance) <= p.lengthTolerance, normalError <= p.rotationTolerance, pointError <= p.lengthTolerance else { throw .invalidSupplierOutput }
        }
        var index=0
        for i in 1..<3 { if samples[i].signedDistance < samples[index].signedDistance { index=i } }
        for i in 0..<3 where i != index { guard abs(samples[i].signedDistance-samples[index].signedDistance) > p.lengthTolerance else { throw .ambiguousFeature } }
        let sample=samples[index]
        guard sample.geometry == obstacle.geometry, sample.degeneracy == .regular else { throw .invalidSupplierOutput }
        let normal=try SurfaceArithmetic.core { () throws(CoreError) in try sample.outwardNormal.scaled(by:-1) }
        let balance=try SurfaceArithmetic.core { () throws(CoreError) in try sample.boundaryPoint.subtracting(s.state.positions[triangle.nodes[index]]).subtracting(normal.scaled(by:sample.signedDistance)).magnitude() }
        guard balance <= p.lengthTolerance else { throw .physicalResidual }
        var weights=[Double](repeating:0,count:3); weights[index]=1
        let material=try SurfaceMaterialPoint(feature:face,barycentric:weights,sumTolerance:p.rotationTolerance)
        let tangent=try SurfaceArithmetic.core { () throws(CoreError) in try obstacle.pose.transforming(direction:.unitX) }
        try SurfaceArithmetic.check(p)
        return SurfaceContactWitness(snapshot:s,first:material,second:nil,obstacle:obstacle,secondBody:obstacleBody,
            pointA:s.state.positions[triangle.nodes[index]],pointB:sample.boundaryPoint,normal:normal,separation:sample.signedDistance,
            rotation:try rotation(normal:normal,tangent:tangent,policy:p))
    }
    @inline(never)
    public func selfContact(_ s: DeformingSurfaceSnapshot, first: SurfaceFeatureID, vertex: Int, second: SurfaceFeatureID,
                            policy p: DeformingContactPolicy, work: inout NumericalWork) throws(DeformingContactError) -> SurfaceContactWitness {
        try SurfaceQueryAdmission.snapshot(s,policy:p,work:&work)
        try SurfaceArithmetic.numerical { () throws(NumericalError) in try work.requireStorage(512) }
        try SurfaceArithmetic.charge(1024,p,&work)
        guard (0..<3).contains(vertex), let a=s.surface.triangles.first(where: { $0.feature == first }),
              let b=s.surface.triangles.first(where: { $0.feature == second }) else { throw .invalidInput }
        guard !a.nodes.contains(where: { b.nodes.contains($0) }) else { throw .adjacentPair }
        let frame=try Self.frame(b,snapshot:s,policy:p)
        let point=s.state.positions[a.nodes[vertex]]
        let height=try SurfaceArithmetic.core { () throws(CoreError) in try point.subtracting(frame.origin).dot(frame.normal) }
        guard abs(height) > p.lengthTolerance else { throw .ambiguousFeature }
        let projected=try SurfaceArithmetic.core { () throws(CoreError) in try point.subtracting(frame.normal.scaled(by:height)) }
        let delta=try SurfaceArithmetic.core { () throws(CoreError) in try projected.subtracting(frame.origin) }
        let uu=try SurfaceArithmetic.core { () throws(CoreError) in try frame.firstEdge.dot(frame.firstEdge) }, uv=try SurfaceArithmetic.core { () throws(CoreError) in try frame.firstEdge.dot(frame.secondEdge) }
        let vv=try SurfaceArithmetic.core { () throws(CoreError) in try frame.secondEdge.dot(frame.secondEdge) }
        let du=try SurfaceArithmetic.core { () throws(CoreError) in try delta.dot(frame.firstEdge) }, dv=try SurfaceArithmetic.core { () throws(CoreError) in try delta.dot(frame.secondEdge) }
        let denominator=try SurfaceArithmetic.finite(uu*vv-uv*uv)
        guard denominator > 0 else { throw .degenerateFace }
        let y=try SurfaceArithmetic.finite((du*vv-dv*uv)/denominator), z=try SurfaceArithmetic.finite((dv*uu-du*uv)/denominator), x=try SurfaceArithmetic.finite(1-y-z)
        // FIXME(INCOMPLETE_IMPLEMENTATION): Edge/vertex projections and general triangle intersections reach this selected query.
        // Complete robust feature/coverage certification is required before those pairs can be admitted.
        guard min(x,min(y,z)) > p.barycentricInterior else { throw .outsideInterior }
        var weights=[Double](repeating:0,count:3); weights[vertex]=1
        let ma=try SurfaceMaterialPoint(feature:first,barycentric:weights,sumTolerance:p.rotationTolerance)
        let mb=try SurfaceMaterialPoint(feature:second,barycentric:[x,y,z],sumTolerance:p.rotationTolerance)
        let normal=try SurfaceArithmetic.core { () throws(CoreError) in try frame.normal.scaled(by:-1) }
        try SurfaceArithmetic.check(p)
        return SurfaceContactWitness(snapshot:s,first:ma,second:mb,obstacle:nil,secondBody:s.surface.body,pointA:point,pointB:projected,
            normal:normal,separation:height,rotation:try rotation(normal:normal,tangent:frame.firstEdge,policy:p))
    }
    internal static func frame(_ face: BoundaryTriangle, snapshot s: DeformingSurfaceSnapshot, policy p: DeformingContactPolicy) throws(DeformingContactError) -> SurfaceTriangleFrame {
        let origin=s.state.positions[face.nodes[0]]
        let u=try SurfaceArithmetic.core { () throws(CoreError) in try s.state.positions[face.nodes[1]].subtracting(origin) }
        let v=try SurfaceArithmetic.core { () throws(CoreError) in try s.state.positions[face.nodes[2]].subtracting(origin) }
        let cross=try SurfaceArithmetic.core { () throws(CoreError) in try u.cross(v) }, area=try SurfaceArithmetic.core { () throws(CoreError) in try cross.magnitude() }
        guard area >= p.minimumDoubleArea else { throw .degenerateFace }
        return SurfaceTriangleFrame(origin:origin,firstEdge:u,secondEdge:v,normal:try SurfaceArithmetic.core { () throws(CoreError) in try cross.normalized() },doubleArea:area)
    }
    private func rotation(normal: Vector3, tangent: Vector3, policy p: DeformingContactPolicy) throws(DeformingContactError) -> UnitQuaternion {
        try SurfaceArithmetic.core { () throws(CoreError) in
            let x=try tangent.normalized(), y=try normal.cross(x).normalized()
            return try UnitQuaternion(matrix:Matrix3(x.x,y.x,normal.x,x.y,y.y,normal.y,x.z,y.z,normal.z),tolerance:NumericalTolerance(absolute:p.rotationTolerance,relative:0))
        }
    }
}
