internal enum GeometricDimensionAdmission {
    static func validate(_ model: CompiledMechanicalModel, relations: [GeometricRelation], program: PrescribedMotionProgram?,
                         prescribedBase:PrescribedBaseMotionProgram? = nil) throws(GeometricConstraintError) {
        let tree = model.tree
        if tree.bodies.allSatisfy({ $0.dimension == .spatial }) { return }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Dynamic planar floating roots without prescribed motion still lack a qualified geometry/evolution contract. Production geometric admission rejects that domain; it requires original manifold, force, and replay proof before success.
        guard tree.bodies.allSatisfy({ $0.dimension == .planar }), program == nil,
              (tree.rootBase == .fixed && model.descriptor.rootAuthority == .fixed) ||
              (tree.rootBase == .planarFloating && model.descriptor.rootAuthority == .prescribedMotion && prescribedBase != nil) else { throw .unsupportedDomain }
        for relation in relations {
            guard (relation.kind != .alignedAxes || prescribedBase != nil), relation.first.point.z == 0, relation.second.point.z == 0,
                  relation.target.value.z == 0, relation.target.rate.z == 0, relation.target.second.z == 0 else { throw .unsupportedDomain }
            if relation.kind == .alignedAxes { guard relation.first.axis.z == 0,relation.second.axis.z == 0 else { throw .unsupportedDomain } }
        }
        for body in tree.bodies { guard planar(body.referencePose) else { throw .unsupportedDomain } }
        for joint in tree.joints {
            for anchor in [joint.parentAnchor, joint.childAnchor] {
                guard case .fixed(let pose) = anchor.placement, planar(pose) else { throw .unsupportedDomain }
            }
        }
    }
    private static func planar(_ pose: RigidTransform) -> Bool {
        pose.translation.z == 0 && pose.rotation.x == 0 && pose.rotation.y == 0
    }
}
