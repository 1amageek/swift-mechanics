internal enum GeneralDampedAdmission {
    @inline(never)
    static func validate(_ pencil:StructuralPencil,expected:StructuralBinding,policy:StructuralPolicy,work:inout NumericalWork) throws(GeneralDampedSpectrumCause) -> Int {
        try DampedSpectrumArithmetic.check(policy)
        let n=pencil.count,nn=try DampedSpectrumArithmetic.product(n,n),maxBasis=try DampedSpectrumArithmetic.product(policy.maximumCoordinates,policy.maximumCoordinates)
        guard n>0,n<=policy.maximumCoordinates,pencil.mass.count==nn,pencil.stiffness.count==nn,pencil.damping.count==nn else { throw .structural(.capacityExceeded) }
        var bindingStorage=0
        for selector in 0..<2 {
            let b=selector==0 ? pencil.binding : expected
            guard b.retainedCoordinates.count==n,b.coordinateScales.count==n,b.dimensions.count==n,
                b.sourceCoordinateIDs.count<=policy.maximumCoordinates,b.reductionBasis.count<=maxBasis,
                b.operatingCoordinates.count<=policy.maximumCoordinates else { throw .structural(.capacityExceeded) }
            var bytes=try DampedSpectrumArithmetic.sum(b.identity.utf8.count,b.frame.key.utf8.count)
            bytes=try DampedSpectrumArithmetic.sum(bytes,b.provenance?.source.utf8.count ?? 0)
            guard !b.identity.isEmpty,bytes<=policy.maximumMetadataBytes else { throw .structural(.capacityExceeded) }
            if let model=b.equilibriumModel {
                guard model.chart.count<=policy.maximumCoordinates else { throw .structural(.capacityExceeded) }
                bytes=try DampedSpectrumArithmetic.sum(bytes,try DampedSpectrumArithmetic.sum(model.identity.utf8.count,model.parameterIdentity.utf8.count))
                bytes=try DampedSpectrumArithmetic.sum(bytes,b.branchIdentity?.utf8.count ?? 0)
                for joint in model.chart.joints {
                    bytes=try DampedSpectrumArithmetic.sum(bytes,joint.key.utf8.count)
                    guard bytes<=policy.maximumMetadataBytes else { throw .structural(.capacityExceeded) }
                }
            }
            if let beam=b.beam {
                guard try DampedSpectrumArithmetic.product(2,try DampedSpectrumArithmetic.sum(beam.elements,1))<=policy.maximumCoordinates else { throw .structural(.capacityExceeded) }
            }
            guard bytes<=policy.maximumMetadataBytes else { throw .structural(.capacityExceeded) }
            try DampedSpectrumArithmetic.charge(bytes,&work)
            if selector==0 {
                bindingStorage=try DampedSpectrumArithmetic.sum(b.sourceCoordinateIDs.count,try DampedSpectrumArithmetic.sum(b.reductionBasis.count,b.operatingCoordinates.count))
                bindingStorage=try DampedSpectrumArithmetic.sum(bindingStorage,try DampedSpectrumArithmetic.product(20,n))
                bindingStorage=try DampedSpectrumArithmetic.sum(bindingStorage,b.beam == nil ? 0:32)
                bindingStorage=try DampedSpectrumArithmetic.sum(bindingStorage,try DampedSpectrumArithmetic.product(16,b.equilibriumModel?.chart.count ?? 0))
            }
        }
        try DampedSpectrumArithmetic.charge(try DampedSpectrumArithmetic.sum(bindingStorage,nn),&work)
        guard pencil.binding==expected else { throw .structural(.staleBinding) }
        for i in 0..<n {
            try DampedSpectrumArithmetic.check(policy);try DampedSpectrumArithmetic.charge(try DampedSpectrumArithmetic.product(16,n),&work)
            guard pencil.binding.coordinateScales[i].isFinite,pencil.binding.coordinateScales[i]>0 else { throw .structural(.invalidInput) }
            for j in 0..<n {
                let ij=i*n+j,ji=j*n+i
                guard pencil.mass[ij].isFinite,pencil.damping[ij].isFinite,pencil.stiffness[ij].isFinite else { throw .structural(.invalidInput) }
                guard pencil.mass[ij]==pencil.mass[ji],pencil.damping[ij]==pencil.damping[ji],pencil.stiffness[ij]==pencil.stiffness[ji] else { throw .structural(.nonsymmetric) }
            }
        }
        return bindingStorage
    }
}
