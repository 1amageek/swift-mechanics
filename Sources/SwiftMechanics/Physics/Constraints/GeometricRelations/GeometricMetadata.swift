internal enum GeometricMetadata {
    static func encode(model:CompiledMechanicalModel,layout:ConstraintCoordinateLayout,relations:[GeometricRelation],minimum:[Double],maximum:[Double],
                       minimumTime:Double,maximumTime:Double,limit:Int,work:inout NumericalWork,prescribedMotion:PrescribedMotionProgram? = nil,
                       prescribedRoot:PrescribedRootBinding? = nil) throws(GeometricConstraintError) -> String {
        // First pass bounds encoded bytes. No identifier or string buffer is allocated before the bound passes.
        let prefix=prescribedRoot != nil ? "body-frame-prescribed-root-v5" : (model.tree.bodies.first?.dimension == .planar ? "body-frame-planar-holonomic-v4" : (prescribedMotion == nil ? "body-frame-holonomic-v2" : "body-frame-holonomic-v3"))
        var count=max(24,prefix.utf8.count)
        func walk(_ emit:(UInt64)->Void,_ identifier:(String)->Void) {
            func vector(_ v:Vector3) { emit(v.x.bitPattern);emit(v.y.bitPattern);emit(v.z.bitPattern) }
            func pose(_ p:RigidTransform) { vector(p.translation);emit(p.rotation.w.bitPattern);emit(p.rotation.x.bitPattern);emit(p.rotation.y.bitPattern);emit(p.rotation.z.bitPattern) }
            func id(_ value:EntityID) { switch value.kind { case .body:emit(1);case .frame:emit(2);case .joint:emit(3);default:emit(4) };identifier(value.key) }
            func endpoint(_ e:GeometricFrameEndpoint) { id(e.body);id(e.frame);vector(e.point);vector(e.axis) }
            identifier(model.stamp.identity);emit(model.stamp.revision);id(model.tree.worldFrame)
            switch model.tree.rootBase { case .fixed:emit(0);case .planarFloating:emit(1);case .spatialFloating:emit(2) }
            emit(UInt64(model.tree.layout.positionCount));emit(UInt64(model.tree.layout.velocityCount));emit(UInt64(model.tree.bodies.count));emit(UInt64(model.tree.joints.count))
            if let root=prescribedRoot {
                identifier(root.program.metadata);emit(UInt64(root.knownCoordinates.count))
                for value in root.knownCoordinates { emit(UInt64(value)) };for value in root.dynamicCoordinates { emit(UInt64(value)) }
                for value in root.rowIDs { emit(value) }
                for body in model.descriptor.bodies { id(body.id);switch body.mode { case .static:emit(0);case .dynamic:emit(1);case .prescribedKinematic:emit(2) } }
            }
            if let program=prescribedMotion { identifier(program.metadata);for body in model.descriptor.bodies { id(body.id);switch body.mode { case .static:emit(0);case .dynamic:emit(1);case .prescribedKinematic:emit(2) } } }
            for body in model.tree.bodies { id(body.id);id(body.frame);pose(body.referencePose) }
            for joint in model.tree.joints {
                id(joint.id);id(joint.parentBody);id(joint.childBody);id(joint.parentAnchor.frame);id(joint.childAnchor.frame)
                if prescribedMotion != nil || prescribedRoot != nil {
                    for anchor in [joint.parentAnchor,joint.childAnchor] { switch anchor.placement { case .fixed:emit(0);case .prescribed:emit(1) } }
                    if let descriptor=model.descriptor.joints.first(where:{$0.record.id == joint.id}) { switch descriptor.authority { case .fixed:emit(0);case .dynamicState:emit(1);case .prescribedMotion:emit(2) } }
                }
                if case .fixed(let p)=joint.parentAnchor.placement { pose(p) };if case .fixed(let p)=joint.childAnchor.placement { pose(p) }
                emit(UInt64(joint.manifold.positionCount));emit(UInt64(joint.manifold.velocityCount));emit(UInt64(joint.manifold.orderedAxes.count))
                for axis in joint.manifold.orderedAxes { switch axis.kind { case .revolute:emit(0);case .prismatic:emit(1);case .screw:emit(2) };vector(axis.direction);emit(axis.pitchMetersPerRadian.bitPattern) }
            }
            emit(layout.revision);emit(layout.timeScale.bitPattern)
            for i in layout.scales.indices {
                emit(layout.coordinateIDs[i]);emit(layout.scales[i].bitPattern)
                let d=layout.dimensions[i]
                for e in [d.length,d.mass,d.time,d.angle,d.electricCurrent,d.temperature,d.amount,d.luminousIntensity] { emit(UInt64(UInt8(bitPattern:e))) }
            }
            for i in minimum.indices { emit(minimum[i].bitPattern);emit(maximum[i].bitPattern) }
            emit(minimumTime.bitPattern);emit(maximumTime.bitPattern);emit(UInt64(relations.count))
            for row in relations {
                emit(row.kind.rawValue);emit(UInt64(row.rowIDs.count));for id in row.rowIDs { emit(id) }
                endpoint(row.first);endpoint(row.second);emit(row.scale.bitPattern);emit(row.axisSign.bitPattern);vector(row.transverseFirst);vector(row.transverseSecond)
                vector(row.target.value);vector(row.target.rate);vector(row.target.second);emit(row.target.referenceTime.bitPattern)
            }
        }
        var overflow=false
        walk({ _ in let next=count.addingReportingOverflow(17);count=next.partialValue;overflow = overflow || next.overflow },{ s in
            let doubled=s.utf8.count.multipliedReportingOverflow(by:2),framed=doubled.partialValue.addingReportingOverflow(18),next=count.addingReportingOverflow(framed.partialValue)
            count=next.partialValue;overflow = overflow || doubled.overflow || framed.overflow || next.overflow
        })
        guard !overflow,count <= limit else { throw .capacityExceeded }
        try GeometricArithmetic.numeric { () throws(NumericalError) -> Void in try work.requireStorage(try NumericalWork.sum(work.peakScalarStorage,count/8+1)) }
        try GeometricArithmetic.charge(count,&work)
        var result=prefix;result.reserveCapacity(count)
        walk({ value in result.append(":");let raw=String(value,radix:16);result.append(String(repeating:"0",count:16-raw.count));result.append(raw) },{ value in
            result.append(":");result.append(String(value.utf8.count,radix:16));result.append(":")
            for byte in value.utf8 { let raw=String(byte,radix:16);if raw.count == 1 { result.append("0") };result.append(raw) }
        })
        return result
    }
}
