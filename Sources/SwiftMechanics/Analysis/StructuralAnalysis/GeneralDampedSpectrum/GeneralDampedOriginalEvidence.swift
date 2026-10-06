internal enum GeneralDampedOriginalEvidence {
    @inline(never)
    static func supplier(_ result:ComplexSpectrumResult,matrix:ComplexSpectralMatrix,policy:StructuralPolicy,spectrumPolicy:ComplexSpectrumPolicy,work:inout NumericalWork) throws(GeneralDampedSpectrumCause) {
        let d=matrix.dimension,dd=try DampedSpectrumArithmetic.product(d,d)
        guard result.dimension==d,result.eigenvalues.count==d,result.eigenvectors.count==dd,
            result.maximumOriginalResidual.isFinite,result.maximumOriginalResidual>=0,
            result.maximumOriginalResidual<=spectrumPolicy.originalResidualTolerance else { throw .invalidSupplierOutput }
        for mode in 0..<d {
            let z=try DampedSpectrumArithmetic.finite(result.eigenvalues[mode]);var norm=0.0
            for row in 0..<d {
                try DampedSpectrumArithmetic.check(policy);try DampedSpectrumArithmetic.charge(try DampedSpectrumArithmetic.product(96,d),&work)
                let v=try DampedSpectrumArithmetic.finite(result.eigenvectors[mode*d+row]);norm=ScalarMath.norm(norm,v.amplitude)
                var left=DampedSpectrumArithmetic.zero,scale=0.0
                for j in 0..<d {
                    let term=try DampedSpectrumArithmetic.multiply(matrix.entries[row*d+j],result.eigenvectors[mode*d+j])
                    left=try DampedSpectrumArithmetic.add(left,term);scale=try DampedSpectrumArithmetic.finite(scale+term.amplitude)
                }
                let right=try DampedSpectrumArithmetic.multiply(z,v)
                scale=try DampedSpectrumArithmetic.finite(scale+right.amplitude)
                let residual=try DampedSpectrumArithmetic.finite(ScalarMath.norm(left.real-right.real,left.imaginary-right.imaginary)/max(1,scale))
                guard residual<=spectrumPolicy.originalResidualTolerance else { throw .invalidSupplierOutput }
            }
            guard abs(norm-1)<=spectrumPolicy.originalResidualTolerance else { throw .invalidSupplierOutput }
        }
    }
    @inline(never)
    static func publish(_ pencil:StructuralPencil,spectral:ComplexSpectrumResult,policy:StructuralPolicy,spectrumPolicy:ComplexSpectrumPolicy,work:inout NumericalWork) throws(GeneralDampedSpectrumCause) -> GeneralDampedModalResult {
        let n=pencil.count,d=2*n
        var poles=[SpectrumComplex](repeating:DampedSpectrumArithmetic.zero,count:d),modes=[SpectrumComplex](repeating:DampedSpectrumArithmetic.zero,count:d*n)
        for mode in 0..<d {
            try DampedSpectrumArithmetic.check(policy);try DampedSpectrumArithmetic.charge(try DampedSpectrumArithmetic.product(32,n),&work)
            poles[mode]=try DampedSpectrumArithmetic.scale(spectral.eigenvalues[mode],1/policy.timeScale)
            for row in 0..<n { modes[mode*n+row]=try DampedSpectrumArithmetic.scale(spectral.eigenvectors[mode*d+row],pencil.binding.coordinateScales[row]) }
            let inner=try massInner(pencil,modes:modes,mode:mode,policy:policy,work:&work)
            guard inner.real>0,abs(inner.imaginary)/inner.real<=policy.originalResidualTolerance else { throw .invalidSupplierOutput }
            let normalization=1/inner.real.squareRoot();var pivot=0
            for row in 0..<n { if modes[mode*n+row].amplitude>modes[mode*n+pivot].amplitude { pivot=row } }
            let p=modes[mode*n+pivot]
            guard p.amplitude>0 else { throw .invalidSupplierOutput }
            let phase=SpectrumComplex(real:p.real/p.amplitude,imaginary:-p.imaginary/p.amplitude)
            try DampedSpectrumArithmetic.charge(try DampedSpectrumArithmetic.product(32,n),&work)
            for row in 0..<n { modes[mode*n+row]=try DampedSpectrumArithmetic.scale(DampedSpectrumArithmetic.multiply(modes[mode*n+row],phase),normalization) }
        }
        let evidence=try original(pencil,poles:poles,modes:modes,policy:policy,work:&work)
        try DampedSpectrumArithmetic.check(policy)
        try DampedSpectrumArithmetic.check(spectrumPolicy)
        return GeneralDampedModalResult(binding:pencil.binding,poles:poles,modes:modes,residual:evidence.0,massError:evidence.1,work:work)
    }
    private static func massInner(_ p:StructuralPencil,modes:[SpectrumComplex],mode:Int,policy:StructuralPolicy,work:inout NumericalWork) throws(GeneralDampedSpectrumCause) -> SpectrumComplex {
        let n=p.count;var inner=DampedSpectrumArithmetic.zero
        for i in 0..<n {
            try DampedSpectrumArithmetic.check(policy);try DampedSpectrumArithmetic.charge(try DampedSpectrumArithmetic.product(48,n),&work)
            let left=modes[mode*n+i],conjugate=SpectrumComplex(real:left.real,imaginary:-left.imaginary)
            for j in 0..<n { inner=try DampedSpectrumArithmetic.add(inner,DampedSpectrumArithmetic.scale(DampedSpectrumArithmetic.multiply(conjugate,modes[mode*n+j]),p.mass[i*n+j])) }
        }
        return inner
    }
    @inline(never)
    private static func original(_ p:StructuralPencil,poles:[SpectrumComplex],modes:[SpectrumComplex],policy:StructuralPolicy,work:inout NumericalWork) throws(GeneralDampedSpectrumCause) -> (Double,Double) {
        let n=p.count;var maximum=0.0,massError=0.0
        for mode in poles.indices {
            try DampedSpectrumArithmetic.charge(16,&work)
            let z=poles[mode],z2=try DampedSpectrumArithmetic.multiply(z,z)
            for row in 0..<n {
                try DampedSpectrumArithmetic.check(policy);try DampedSpectrumArithmetic.charge(try DampedSpectrumArithmetic.product(128,n),&work)
                var m=DampedSpectrumArithmetic.zero,c=m,k=m
                for j in 0..<n {
                    let v=modes[mode*n+j],ij=row*n+j
                    m=try DampedSpectrumArithmetic.add(m,DampedSpectrumArithmetic.scale(v,p.mass[ij]))
                    c=try DampedSpectrumArithmetic.add(c,DampedSpectrumArithmetic.scale(v,p.damping[ij]))
                    k=try DampedSpectrumArithmetic.add(k,DampedSpectrumArithmetic.scale(v,p.stiffness[ij]))
                }
                let factor=try DampedSpectrumArithmetic.finite(p.binding.coordinateScales[row]*policy.timeScale/policy.energyScale.squareRoot())
                guard factor>0 else { throw .structural(.nonFiniteResult) }
                let first=try DampedSpectrumArithmetic.scale(DampedSpectrumArithmetic.multiply(z2,m),factor),second=try DampedSpectrumArithmetic.scale(DampedSpectrumArithmetic.multiply(z,c),factor),third=try DampedSpectrumArithmetic.scale(k,factor)
                let residual=try DampedSpectrumArithmetic.add(DampedSpectrumArithmetic.add(first,second),third)
                let denominator=try DampedSpectrumArithmetic.finite(first.amplitude+second.amplitude+third.amplitude)
                maximum=max(maximum,try DampedSpectrumArithmetic.finite(residual.amplitude/max(1,denominator)))
            }
            let mass=try massInner(p,modes:modes,mode:mode,policy:policy,work:&work)
            massError=max(massError,max(abs(mass.real-1),abs(mass.imaginary)))
        }
        let error=max(maximum,massError)
        guard error<=policy.originalResidualTolerance else { throw .residualRejected(value:error,threshold:policy.originalResidualTolerance) }
        return (maximum,massError)
    }
}
