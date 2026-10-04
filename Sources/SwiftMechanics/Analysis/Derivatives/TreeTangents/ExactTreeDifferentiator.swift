
public struct ExactTreeDifferentiator: TreeDifferentiating {
    public init() {}
    @inline(never)
    public func direction(_ tree: KinematicTree, state: KinematicState, direction d: TreeDirection,
                          jointPolicy: JointEvaluationPolicy, policy p: DerivativePolicy,
                          workspace s: inout TreeTangentWorkspace, supplierWork: inout DerivativeSupplierWork,
                          work w: inout NumericalWork) throws(DerivativeError) -> TreeTangent {
        try DifferentialArithmetic.checkpoint(p)
        let n=tree.layout.velocityCount, b=tree.bodies.count
        guard b <= p.maximumBodies, n <= p.maximumVelocities, state.prescribedAnchors.count <= (try DifferentialArithmetic.product(tree.joints.count,2)) else { throw .capacityExceeded }
        guard state.revision == tree.revision, d.revision == tree.revision else { throw .staleBinding }
        guard d.configuration.count == n, d.velocity.count == n, d.acceleration.count == n, d.screwPitch.count == n,
              d.prescribed.count == state.prescribedAnchors.count else { throw .invalidShape }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Planar body trees and planar floating roots have no derivative qualification. This public path fails until spatial/planar chart composition has independent evidence.
        guard tree.rootBase != .planarFloating, tree.bodies.allSatisfy({ $0.dimension == .spatial }) else { throw .derivativeUnavailable }
        try DifferentialArithmetic.charge(try DifferentialArithmetic.sum(try DifferentialArithmetic.product(n,4),1),&w)
        guard d.configuration.allSatisfy({ $0.isFinite }), d.velocity.allSatisfy({ $0.isFinite }), d.acceleration.allSatisfy({ $0.isFinite }),
              d.screwPitch.allSatisfy({ $0.isFinite }), d.time.isFinite else { throw .invalidInput }
        let bn=try DifferentialArithmetic.product(b,n)
        // Both retained workspace and immutable publication plus fixed six-axis scratch are included.
        let storage=try DifferentialArithmetic.sum(try DifferentialArithmetic.product(b,400),try DifferentialArithmetic.sum(try DifferentialArithmetic.product(bn,48),1440))
        try DifferentialArithmetic.storage(DifferentialArithmetic.sum(storage,s.retainedScalarSlots()),&w)
        try DifferentialArithmetic.identityBytes(tree.worldFrame,p,&w)
        for body in tree.bodies {
            try DifferentialArithmetic.identityBytes(body.id,p,&w); try DifferentialArithmetic.identityBytes(body.frame,p,&w)
        }
        for joint in tree.joints {
            try DifferentialArithmetic.identityBytes(joint.id,p,&w); try DifferentialArithmetic.identityBytes(joint.parentBody,p,&w)
            try DifferentialArithmetic.identityBytes(joint.childBody,p,&w); try DifferentialArithmetic.identityBytes(joint.parentAnchor.frame,p,&w)
            try DifferentialArithmetic.identityBytes(joint.childAnchor.frame,p,&w)
        }
        for sample in state.prescribedAnchors { try DifferentialArithmetic.identityBytes(sample.frame,p,&w) }
        try supplierWork.chargeCall()
        let snapshot: KinematicSnapshot
        do { snapshot=try TreeKinematicsEvaluator().evaluate(tree,state:state,policy:jointPolicy) }
        catch let error as JointError { throw .joints(error,failedSupplierWorkUnavailable:true) }
        catch let error as CoreError { throw .core(error) }
        catch let error as ModelError { throw .model(error) }
        catch { throw .unexpectedSupplierFailure }
        s.frames.removeAll(keepingCapacity:true); s.columns.removeAll(keepingCapacity:true)
        s.frames.reserveCapacity(b); s.columns.reserveCapacity(bn)
        if tree.rootBase == .fixed {
            s.frames.append(try fixed(tree.bodies[0].referencePose,&w))
            for _ in 0..<n { s.columns.append(.zero) }
        } else {
            let root=try quaternion(state,d,qStart:0,vStart:0,spherical:false,&w)
            s.frames.append(root)
            for i in 0..<n { s.columns.append(i < 6 ? try quaternionColumn(root,i,spherical:false,&w) : .zero) }
            for i in 0..<6 { guard d.screwPitch[i] == 0 else { throw .derivativeUnavailable } }
        }
        for i in 1..<b {
            try DifferentialArithmetic.checkpoint(p)
            let joint=tree.joints[i-1], layout=tree.layout.joints[i-1]
            var parent: Int? = nil
            for j in 0..<i {
                try DifferentialArithmetic.identityBytes(joint.parentBody,p,&w)
                try DifferentialArithmetic.identityBytes(tree.bodies[j].id,p,&w)
                if tree.bodies[j].id == joint.parentBody { parent=j; break }
            }
            guard let parent else { throw .staleBinding }
            let pa=try anchor(joint.parentAnchor,state,d,p,&w), ca=try anchor(joint.childAnchor,state,d,p,&w)
            let wp=try DifferentialFrame.compose(s.frames[parent],pa,&w)
            let relative: DifferentialFrame
            s.localColumns.removeAll(keepingCapacity:true)
            if joint.manifold.kind == .spherical || joint.manifold.kind == .sixDOF {
                let spherical=joint.manifold.kind == .spherical
                relative=try quaternion(state,d,qStart:layout.positions.start,vStart:layout.velocities.start,spherical:spherical,&w)
                for k in 0..<layout.velocities.count {
                    guard d.screwPitch[layout.velocities.start+k] == 0 else { throw .derivativeUnavailable }
                    s.localColumns.append(try quaternionColumn(relative,k,spherical:spherical,&w))
                }
            } else {
                relative=try ordered(joint.manifold,state,d,layout.positions.start,layout.velocities.start,&s,&w)
            }
            let wc=try DifferentialFrame.compose(wp,relative,&w)
            let body=try DifferentialFrame.compose(wc,DifferentialFrame.inverse(ca,&w),&w)
            let po=try DifferentialArithmetic.subtract(body.translation,s.frames[parent].translation,&w)
            let co=try DifferentialArithmetic.subtract(body.translation,wc.translation,&w)
            for k in 0..<n {
                let pc=s.columns[parent*n+k]
                var angular=pc.angular, linear=try DifferentialArithmetic.add(pc.linear,DifferentialArithmetic.cross(pc.angular,po,&w),&w)
                if layout.velocities.range.contains(k) {
                    let local=s.localColumns[k-layout.velocities.start]
                    let extra=try DifferentialArithmetic.apply(wp.rotation,local.angular,&w)
                    let lv=try DifferentialArithmetic.add(DifferentialArithmetic.apply(wp.rotation,local.linear,&w),DifferentialArithmetic.cross(extra,co,&w),&w)
                    angular=try DifferentialArithmetic.add(angular,extra,&w); linear=try DifferentialArithmetic.add(linear,lv,&w)
                }
                s.columns.append(DifferentialMotion(angular,linear))
            }
            s.frames.append(body)
        }
        return try publish(snapshot,state,d,p,&s,&supplierWork,&w)
    }
    @inline(never)
    private func publish(_ snapshot: KinematicSnapshot, _ state: KinematicState, _ d: TreeDirection, _ p: DerivativePolicy,
                         _ s: inout TreeTangentWorkspace, _ supplier: inout DerivativeSupplierWork, _ w: inout NumericalWork) throws(DerivativeError) -> TreeTangent {
        let n=state.v.count
        var bodies:[BodyTangent]=[], directions:[SpatialMotion]=[], bias:[DifferentialMotion]=[]
        bodies.reserveCapacity(s.frames.count); directions.reserveCapacity(s.columns.count); bias.reserveCapacity(s.frames.count)
        for i in s.frames.indices {
            try DifferentialArithmetic.checkpoint(p)
            let actual=snapshot.bodies[i], f=s.frames[i]
            try DifferentialArithmetic.equal(f.translation.value,actual.motion.pose.translation,p,&w)
            try DifferentialArithmetic.charge(60,&w)
            let actualR=try DifferentialArithmetic.core { () throws(CoreError) in try actual.motion.pose.rotation.matrix() }
            for r in 0..<3 { for c in 0..<3 {
                let av=try DifferentialArithmetic.core { () throws(CoreError) in try actualR.element(row:r,column:c) }
                let fv=try DifferentialArithmetic.core { () throws(CoreError) in try f.rotation.value.element(row:r,column:c) }
                try DifferentialArithmetic.equal(av,fv,p,&w)
            } }
            try DifferentialArithmetic.equal(f.velocity.angular.value,actual.motion.velocity.angular,p,&w)
            try DifferentialArithmetic.equal(f.velocity.linear.value,actual.motion.velocity.linear,p,&w)
            try DifferentialArithmetic.equal(f.acceleration.angular.value,actual.motion.acceleration.angular,p,&w)
            try DifferentialArithmetic.equal(f.acceleration.linear.value,actual.motion.acceleration.linear,p,&w)
            try DifferentialArithmetic.identityBytes(actual.body,p,&w)
            try supplier.chargeCall()
            try supplierCallColumns(snapshot,actual.body,i,n,p,&s,&directions,&w)
            var jv=DifferentialMotion.zero, ja=DifferentialMotion.zero
            for k in 0..<n {
                let column=s.columns[i*n+k], v=try DifferentialArithmetic.scalar(state.v[k],d.velocity[k]), a=try DifferentialArithmetic.scalar(state.acceleration[k],d.acceleration[k])
                jv=DifferentialMotion(try DifferentialArithmetic.add(jv.angular,DifferentialArithmetic.scale(column.angular,v,&w),&w),try DifferentialArithmetic.add(jv.linear,DifferentialArithmetic.scale(column.linear,v,&w),&w))
                ja=DifferentialMotion(try DifferentialArithmetic.add(ja.angular,DifferentialArithmetic.scale(column.angular,a,&w),&w),try DifferentialArithmetic.add(ja.linear,DifferentialArithmetic.scale(column.linear,a,&w),&w))
            }
            let drift=DifferentialMotion(try DifferentialArithmetic.subtract(f.velocity.angular,jv.angular,&w),try DifferentialArithmetic.subtract(f.velocity.linear,jv.linear,&w))
            let ab=DifferentialMotion(try DifferentialArithmetic.subtract(f.acceleration.angular,ja.angular,&w),try DifferentialArithmetic.subtract(f.acceleration.linear,ja.linear,&w))
            bias.append(ab)
            bodies.append(BodyTangent(body:actual.body,frame:actual.bodyFrame,translation:f.translation.direction,rotationMatrix:f.rotation.direction,
                velocity:f.velocity.direction,acceleration:f.acceleration.direction,prescribedDrift:drift.direction,accelerationBias:ab.direction))
        }
        try DifferentialArithmetic.checkpoint(p)
        let coordinateRate=try rates(snapshot,state,d,p,&w)
        try DifferentialArithmetic.checkpoint(p)
        return TreeTangent(snapshot:snapshot,bodies:bodies,coordinateRate:coordinateRate,geometricColumns:directions,frames:s.frames,columns:s.columns,bias:bias)
    }
    @inline(never)
    private func rates(_ snapshot: KinematicSnapshot, _ state: KinematicState, _ d: TreeDirection, _ p: DerivativePolicy,
                       _ w: inout NumericalWork) throws(DerivativeError) -> [Double] {
        var result:[Double]=[]; result.reserveCapacity(state.q.count)
        if snapshot.tree.rootBase == .spatialFloating { try quaternionRate(state,d,0,0,false,&result,&w) }
        for (i,joint) in snapshot.tree.joints.enumerated() {
            try DifferentialArithmetic.checkpoint(p)
            let layout=snapshot.tree.layout.joints[i]
            if joint.manifold.kind == .spherical || joint.manifold.kind == .sixDOF {
                try quaternionRate(state,d,layout.positions.start,layout.velocities.start,joint.manifold.kind == .spherical,&result,&w)
            } else { for k in layout.velocities.range { result.append(d.velocity[k]) } }
        }
        guard result.count == state.q.count else { throw .invalidShape }
        return result
    }
    private func quaternionRate(_ state: KinematicState, _ d: TreeDirection, _ qs: Int, _ vs: Int, _ spherical: Bool,
                                _ output: inout [Double], _ w: inout NumericalWork) throws(DerivativeError) {
        let offset=spherical ? 0 : 3, qStart=qs+offset, vStart=vs+offset
        if !spherical { for k in 0..<3 { output.append(d.velocity[vs+k]) } }
        try DifferentialArithmetic.charge(100,&w)
        let q=try DifferentialArithmetic.core { () throws(CoreError) in try UnitQuaternion(w:state.q[qStart],x:state.q[qStart+1],y:state.q[qStart+2],z:state.q[qStart+3]) }
        let eta=try vector(d.configuration,vStart), omega=try vector(state.v,vStart), domega=try vector(d.velocity,vStart)
        let dq=try DifferentialArithmetic.core { () throws(CoreError) in try q.bodyRate(for:eta) }
        let dw = -0.5*(dq.x*omega.x+dq.y*omega.y+dq.z*omega.z+q.x*domega.x+q.y*domega.y+q.z*domega.z)
        let dx = 0.5*(dq.w*omega.x+dq.y*omega.z-dq.z*omega.y+q.w*domega.x+q.y*domega.z-q.z*domega.y)
        let dy = 0.5*(dq.w*omega.y+dq.z*omega.x-dq.x*omega.z+q.w*domega.y+q.z*domega.x-q.x*domega.z)
        let dz = 0.5*(dq.w*omega.z+dq.x*omega.y-dq.y*omega.x+q.w*domega.z+q.x*domega.y-q.y*domega.x)
        output.append(try DifferentialArithmetic.finite(dw)); output.append(try DifferentialArithmetic.finite(dx))
        output.append(try DifferentialArithmetic.finite(dy)); output.append(try DifferentialArithmetic.finite(dz))
    }
    private func supplierCallColumns(_ snapshot: KinematicSnapshot, _ body: EntityID, _ i: Int, _ n: Int, _ p: DerivativePolicy,
                                     _ s: inout TreeTangentWorkspace, _ out: inout [SpatialMotion], _ w: inout NumericalWork) throws(DerivativeError) {
        let cols: ArraySlice<SpatialMotion>
        do { cols=try snapshot.geometricColumns(body:body) } catch { throw .joints(error,failedSupplierWorkUnavailable:true) }
        for (k,c) in cols.enumerated() {
            try DifferentialArithmetic.equal(c.angular,s.columns[i*n+k].angular.value,p,&w)
            try DifferentialArithmetic.equal(c.linear,s.columns[i*n+k].linear.value,p,&w)
            out.append(s.columns[i*n+k].direction)
        }
    }
    private func fixed(_ pose: RigidTransform, _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialFrame {
        DifferentialFrame(rotation:try DifferentialArithmetic.rotation(pose.rotation,tangent:.zero,&w),translation:DifferentialVector(pose.translation))
    }
    private func anchor(_ a: JointAnchor, _ state: KinematicState, _ d: TreeDirection, _ p: DerivativePolicy,
                        _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialFrame {
        switch a.placement {
        case .fixed(let pose): return try fixed(pose,&w)
        case .prescribed:
            for i in state.prescribedAnchors.indices {
                try DifferentialArithmetic.identityBytes(a.frame,p,&w)
                try DifferentialArithmetic.identityBytes(state.prescribedAnchors[i].frame,p,&w)
                if state.prescribedAnchors[i].frame == a.frame { return try DifferentialFrame.sample(state.prescribedAnchors[i].motion,d.prescribed[i],&w) }
            }
            throw .derivativeUnavailable
        }
    }
    private func vector(_ values: [Double], _ start: Int) throws(DerivativeError) -> Vector3 {
        try DifferentialArithmetic.core { () throws(CoreError) in try Vector3(values[start],values[start+1],values[start+2]) }
    }
    private func quaternion(_ state: KinematicState, _ d: TreeDirection, qStart: Int, vStart: Int, spherical: Bool,
                            _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialFrame {
        let offset=spherical ? 0 : 3, qs=qStart+offset, vs=vStart+offset
        let q=try DifferentialArithmetic.core { () throws(CoreError) in try UnitQuaternion(w:state.q[qs],x:state.q[qs+1],y:state.q[qs+2],z:state.q[qs+3]) }
        let r=try DifferentialArithmetic.rotation(q,tangent:vector(d.configuration,vs),&w)
        let angular=try DifferentialArithmetic.apply(r,DifferentialVector(vector(state.v,vs),vector(d.velocity,vs)),&w)
        let alpha=try DifferentialArithmetic.apply(r,DifferentialVector(vector(state.acceleration,vs),vector(d.acceleration,vs)),&w)
        let t=spherical ? DifferentialVector.zero : try DifferentialVector(vector(state.q,qStart),vector(d.configuration,vStart))
        let v=spherical ? DifferentialVector.zero : try DifferentialVector(vector(state.v,vStart),vector(d.velocity,vStart))
        let a=spherical ? DifferentialVector.zero : try DifferentialVector(vector(state.acceleration,vStart),vector(d.acceleration,vStart))
        return DifferentialFrame(rotation:r,translation:t,velocity:DifferentialMotion(angular,v),acceleration:DifferentialMotion(alpha,a))
    }
    private func quaternionColumn(_ f: DifferentialFrame, _ index: Int, spherical: Bool, _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialMotion {
        let axis: Vector3
        switch index % 3 { case 0: axis = .unitX; case 1: axis = .unitY; default: axis = .unitZ }
        if !spherical && index < 3 { return DifferentialMotion(.zero,DifferentialVector(axis)) }
        return DifferentialMotion(try DifferentialArithmetic.apply(f.rotation,DifferentialVector(axis),&w),.zero)
    }
    @inline(never)
    private func ordered(_ m: JointManifold, _ state: KinematicState, _ d: TreeDirection, _ qs: Int, _ vs: Int,
                         _ s: inout TreeTangentWorkspace, _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialFrame {
        var f=DifferentialFrame.identity
        s.prefixes.removeAll(keepingCapacity:true)
        for k in m.orderedAxes.indices {
            let axis=m.orderedAxes[k], q=try DifferentialArithmetic.scalar(state.q[qs+k],d.configuration[vs+k])
            let pitch=try DifferentialArithmetic.scalar(axis.pitchMetersPerRadian,d.screwPitch[vs+k])
            guard axis.kind == .screw || pitch.direction == 0 else { throw .derivativeUnavailable }
            s.prefixes.append(f)
            let angular=axis.kind == .prismatic ? DifferentialVector.zero : DifferentialVector(axis.direction)
            let linear: DifferentialVector
            if axis.kind == .prismatic { linear=DifferentialVector(axis.direction) }
            else if axis.kind == .screw { linear=try DifferentialArithmetic.scale(DifferentialVector(axis.direction),pitch,&w) }
            else { linear = .zero }
            let r: DifferentialMatrix
            if axis.kind == .prismatic { r = .identity }
            else {
                let rotation=try DifferentialArithmetic.core { () throws(CoreError) in try UnitQuaternion(axis:axis.direction,angle:q.value) }
                let tangent=try DifferentialArithmetic.core { () throws(CoreError) in try axis.direction.scaled(by:q.direction) }
                r=try DifferentialArithmetic.rotation(rotation,tangent:tangent,&w)
            }
            let translation=try DifferentialArithmetic.scale(linear,q,&w)
            let rate=try DifferentialArithmetic.scalar(state.v[vs+k],d.velocity[vs+k]), acc=try DifferentialArithmetic.scalar(state.acceleration[vs+k],d.acceleration[vs+k])
            let rel=DifferentialFrame(rotation:r,translation:translation,
                velocity:DifferentialMotion(try DifferentialArithmetic.scale(angular,rate,&w),try DifferentialArithmetic.scale(linear,rate,&w)),
                acceleration:DifferentialMotion(try DifferentialArithmetic.scale(angular,acc,&w),try DifferentialArithmetic.scale(linear,acc,&w)))
            f=try DifferentialFrame.compose(f,rel,&w)
        }
        for k in m.orderedAxes.indices {
            let axis=m.orderedAxes[k], prefix=s.prefixes[k]
            let angular=axis.kind == .prismatic ? DifferentialVector.zero : DifferentialVector(axis.direction)
            let linear: DifferentialVector
            if axis.kind == .prismatic { linear=DifferentialVector(axis.direction) }
            else if axis.kind == .screw { linear=try DifferentialArithmetic.scale(DifferentialVector(axis.direction),DifferentialArithmetic.scalar(axis.pitchMetersPerRadian,d.screwPitch[vs+k]),&w) }
            else { linear = .zero }
            let wa=try DifferentialArithmetic.apply(prefix.rotation,angular,&w)
            let delta=try DifferentialArithmetic.subtract(f.translation,prefix.translation,&w)
            let wl=try DifferentialArithmetic.add(DifferentialArithmetic.apply(prefix.rotation,linear,&w),DifferentialArithmetic.cross(wa,delta,&w),&w)
            s.localColumns.append(DifferentialMotion(wa,wl))
        }
        return f
    }
}
