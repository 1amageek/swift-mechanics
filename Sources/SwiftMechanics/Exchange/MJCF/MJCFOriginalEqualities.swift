internal enum MJCFOriginalEqualities {
    static func evaluate(bindings: [MJCFEqualityBinding], system: QuadraticConstraintSystem, evaluation: ConstraintEvaluation,
                         position: [Double], context: MJCFImportContext, work: inout MJCFWork) throws(MJCFError) -> [MJCFEqualitySample] {
        let n = position.count
        guard bindings.count == evaluation.values.count, evaluation.rowIDs.count == bindings.count,
              evaluation.timeDerivative.count == bindings.count, evaluation.accelerationBias.count == bindings.count,
              system.layout.scales.count == n, evaluation.layoutRevision == context.source.revision,
              evaluation.jacobian.count == (try MJCFArithmetic.product(n,bindings.count)) else { throw .identityMismatch }
        try work.allocate(try MJCFArithmetic.product(bindings.count, MemoryLayout<MJCFEqualitySample>.stride))
        var result: [MJCFEqualitySample] = []
        for r in bindings.indices {
            let binding = bindings[r]
            guard evaluation.rowIDs[r] == binding.rowID, binding.gradientSI.count == n else { throw .identityMismatch }
            guard evaluation.timeDerivative[r] == 0, evaluation.accelerationBias[r] == 0 else { throw .originalResidualMismatch(node: binding.node) }
            var original = binding.constantSI
            for i in position.indices {
                try work.charge(5)
                original = try MJCFArithmetic.finite(original + binding.gradientSI[i] * position[i])
                let physicalJ = try MJCFArithmetic.finite(evaluation.jacobian[r*n+i] * binding.residualScale / system.layout.scales[i])
                let accepted = try MJCFArithmetic.core { () throws(CoreError) in
                    try context.equalityTolerance.contains(error: physicalJ - binding.gradientSI[i], scale: max(abs(physicalJ),abs(binding.gradientSI[i])))
                }
                guard accepted else { throw .originalResidualMismatch(node: binding.node) }
            }
            let reconstructed = try MJCFArithmetic.finite(evaluation.values[r] * binding.residualScale)
            let error = try MJCFArithmetic.finite(reconstructed - original)
            let accepted = try MJCFArithmetic.core { () throws(CoreError) in
                try context.equalityTolerance.contains(error: error, scale: max(abs(original),abs(reconstructed)))
            }
            guard accepted else { throw .originalResidualMismatch(node: binding.node) }
            result.append(MJCFEqualitySample(rowID: binding.rowID, node: binding.node, residualSI: original, gradientSI: binding.gradientSI, originalReplayErrorSI: error))
        }
        return result
    }
}
