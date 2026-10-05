internal enum ArticulatedRecursion {
    @inline(never)
    static func solve(_ workspace: inout ArticulatedWorkspace, input: RigidDynamicsInput,
                      policy: ArticulatedDynamicsPolicy, work: inout NumericalWork) throws(ArticulatedDynamicsFailure) -> [Double] {
        let count = workspace.parents.count
        var reduced = [Double](repeating:0,count:36), intermediate = reduced
        var projected = [Double](repeating:0,count:6), propagated = projected, image = projected, parentAcceleration = projected
        for i in stride(from:count-1,through:1,by:-1) {
            try ArticulatedArithmetic.check(policy)
            do { try work.advanceIteration() } catch { throw ArticulatedDynamicsFailure(.numerical(error)) }
            let matrixOffset = 36*i, vectorOffset = 6*i, coordinate = workspace.coordinates[i], parent = workspace.parents[i]
            var divisor = 1.0, effort = 0.0
            if coordinate >= 0 {
                for row in 0..<6 {
                    var value = 0.0
                    for column in 0..<6 { try ArticulatedArithmetic.charge(2,&work); value = try ArticulatedArithmetic.finite(value+workspace.inertia[matrixOffset+row*6+column]*workspace.subspace[vectorOffset+column]) }
                    workspace.projectedInertia[vectorOffset+row] = value
                }
                var pivot = 0.0, projectedBias = 0.0
                for row in 0..<6 {
                    try ArticulatedArithmetic.charge(4,&work)
                    pivot = try ArticulatedArithmetic.finite(pivot+workspace.subspace[vectorOffset+row]*workspace.projectedInertia[vectorOffset+row])
                    projectedBias = try ArticulatedArithmetic.finite(projectedBias+workspace.subspace[vectorOffset+row]*workspace.forceBias[vectorOffset+row])
                }
                try ArticulatedArithmetic.charge(6,&work)
                let scale = policy.coordinateScales[coordinate]
                let normalized = try ArticulatedArithmetic.finite((((pivot/policy.energyScale)*scale)*scale)/(policy.timeScale*policy.timeScale))
                guard pivot > 0, normalized > policy.pivotThreshold else {
                    throw ArticulatedDynamicsFailure(.singularJoint(joint:input.snapshot.tree.joints[i-1].id,normalizedPivot:normalized,threshold:policy.pivotThreshold))
                }
                divisor = pivot; effort = try ArticulatedArithmetic.finite(workspace.generalizedEffort[coordinate]-projectedBias)
                workspace.pivots[i] = divisor; workspace.efforts[i] = effort
            }
            for row in 0..<6 {
                for column in 0..<6 {
                    var value = workspace.inertia[matrixOffset+row*6+column]
                    if coordinate >= 0 {
                        try ArticulatedArithmetic.charge(3,&work)
                        value = try ArticulatedArithmetic.finite(value-workspace.projectedInertia[vectorOffset+row]*workspace.projectedInertia[vectorOffset+column]/divisor)
                    }
                    reduced[row*6+column] = value
                }
            }
            for row in 0..<6 {
                var value = workspace.forceBias[vectorOffset+row]
                for column in 0..<6 { try ArticulatedArithmetic.charge(2,&work); value = try ArticulatedArithmetic.finite(value+reduced[row*6+column]*workspace.bias[vectorOffset+column]) }
                if coordinate >= 0 { try ArticulatedArithmetic.charge(3,&work); value = try ArticulatedArithmetic.finite(value+workspace.projectedInertia[vectorOffset+row]*effort/divisor) }
                projected[row] = value
            }
            // Articulated inertia is transported with the actual mechanical X^T*IAbar*X.
            for row in 0..<6 {
                for column in 0..<6 {
                    var value = 0.0
                    for k in 0..<6 { try ArticulatedArithmetic.charge(2,&work); value = try ArticulatedArithmetic.finite(value+reduced[row*6+k]*workspace.transport[matrixOffset+k*6+column]) }
                    intermediate[row*6+column] = value
                }
            }
            for row in 0..<6 {
                for column in 0..<6 {
                    var value = 0.0
                    for k in 0..<6 { try ArticulatedArithmetic.charge(2,&work); value = try ArticulatedArithmetic.finite(value+workspace.transport[matrixOffset+k*6+row]*intermediate[k*6+column]) }
                    try ArticulatedArithmetic.charge(1,&work)
                    workspace.inertia[parent*36+row*6+column] = try ArticulatedArithmetic.finite(workspace.inertia[parent*36+row*6+column]+value)
                }
                var value = 0.0
                for k in 0..<6 { try ArticulatedArithmetic.charge(2,&work); value = try ArticulatedArithmetic.finite(value+workspace.transport[matrixOffset+k*6+row]*projected[k]) }
                propagated[row] = value
            }
            for row in 0..<6 { try ArticulatedArithmetic.charge(1,&work); workspace.forceBias[parent*6+row] = try ArticulatedArithmetic.finite(workspace.forceBias[parent*6+row]+propagated[row]) }
        }
        var acceleration = [Double](repeating:0,count:workspace.generalizedEffort.count)
        // Root acceleration is fixed at zero; no gravity convention is encoded in root motion.
        for i in 1..<count {
            try ArticulatedArithmetic.check(policy)
            do { try work.advanceIteration() } catch { throw ArticulatedDynamicsFailure(.numerical(error)) }
            let parent = workspace.parents[i], matrixOffset = 36*i, vectorOffset = 6*i, coordinate = workspace.coordinates[i]
            for row in 0..<6 { parentAcceleration[row] = workspace.bodyAcceleration[parent*6+row] }
            try ArticulatedMatrix6.applying(workspace.transport,offset:matrixOffset,vector:parentAcceleration,into:&image,work:&work)
            for row in 0..<6 { try ArticulatedArithmetic.charge(1,&work); image[row] = try ArticulatedArithmetic.finite(image[row]+workspace.bias[vectorOffset+row]) }
            if coordinate >= 0 {
                var value = workspace.efforts[i]
                for row in 0..<6 { try ArticulatedArithmetic.charge(2,&work); value = try ArticulatedArithmetic.finite(value-workspace.projectedInertia[vectorOffset+row]*image[row]) }
                try ArticulatedArithmetic.charge(1,&work); acceleration[coordinate] = try ArticulatedArithmetic.finite(value/workspace.pivots[i])
                for row in 0..<6 { try ArticulatedArithmetic.charge(2,&work); image[row] = try ArticulatedArithmetic.finite(image[row]+workspace.subspace[vectorOffset+row]*acceleration[coordinate]) }
            }
            for row in 0..<6 { workspace.bodyAcceleration[vectorOffset+row] = image[row] }
        }
        try ArticulatedArithmetic.check(policy)
        return acceleration
    }
}
