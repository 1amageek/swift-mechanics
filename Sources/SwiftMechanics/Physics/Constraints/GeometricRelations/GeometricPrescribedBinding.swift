/// Binds mathematical anchor laws to the actual public compiler authority and tree inventory.
internal enum GeometricPrescribedBinding {
    static func validate(_ model:CompiledMechanicalModel,program:PrescribedMotionProgram?,work:inout NumericalWork) throws(GeometricConstraintError) {
        let tree=model.tree
        try GeometricArithmetic.charge(try GeometricArithmetic.numeric { () throws(NumericalError) -> Int in try NumericalWork.product(128,try NumericalWork.product(tree.joints.count+1,tree.bodies.count+1)) },&work)
        var count=0
        for joint in tree.joints {
            if case .prescribed=joint.childAnchor.placement { throw .unsupportedDomain }
            guard let descriptor=model.descriptor.joints.first(where:{$0.record.id == joint.id}) else { throw .staleSource }
            if program != nil {
            if joint.manifold.velocityCount == 0 {
                guard descriptor.authority == .fixed else { throw .unsupportedDomain }
            } else { guard descriptor.authority == .dynamicState else { throw .unsupportedDomain } }
            }
            if case .prescribed=joint.parentAnchor.placement {
                count+=1
                guard tree.rootBase == .fixed,model.descriptor.rootAuthority == .fixed,joint.parentBody == model.descriptor.root,
                      joint.manifold.velocityCount == 0,
                      model.descriptor.bodies.first(where:{$0.id == joint.parentBody})?.mode == .static,
                      model.descriptor.bodies.first(where:{$0.id == joint.childBody})?.mode == .prescribedKinematic,
                      let parent=tree.bodies.first(where:{$0.id == joint.parentBody}),let program,
                      let motion=program.motions.first(where:{$0.frame == joint.parentAnchor.frame}),motion.parentFrame == parent.frame else { throw .unsupportedDomain }
            }
        }
        guard count == (program?.motions.count ?? 0) else { throw .staleSource }
    }
}
