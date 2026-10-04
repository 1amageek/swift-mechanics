internal enum GeometricDimensionAdmission {
    static func validate(_ model: CompiledMechanicalModel, relations: [GeometricRelation], program: PrescribedMotionProgram?) throws(GeometricConstraintError) {
        let tree = model.tree
        if tree.bodies.allSatisfy({ $0.dimension == .spatial }) { return }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Planar floating/prescribed partitions and planar alignment do not have admitted geometric contracts. This construction path fails until their original physical evidence exists.
        guard tree.bodies.allSatisfy({ $0.dimension == .planar }), tree.rootBase == .fixed,
              model.descriptor.rootAuthority == .fixed, program == nil else { throw .unsupportedDomain }
        for relation in relations {
            guard relation.kind != .alignedAxes, relation.first.point.z == 0, relation.second.point.z == 0,
                  relation.target.value.z == 0, relation.target.rate.z == 0, relation.target.second.z == 0 else { throw .unsupportedDomain }
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
