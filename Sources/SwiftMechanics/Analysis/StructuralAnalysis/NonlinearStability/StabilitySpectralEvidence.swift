internal enum StabilitySpectralEvidence {
    typealias Cause = NonlinearStabilityFailure.Cause
    struct Data {
        let mass: [Double], stiffness: [Double], eigenvalues: [Double], modes: [Double]
        let residual: Double, massError: Double
        let classification: NonlinearStabilityPoint.Classification
    }
    @inline(never)
    static func evaluate(_ s: NonlinearStabilitySource, mass: [Double], hessian: [Double],
                         linear: any LinearSolving<Double>, spectrum: any ComplexSpectralSolving,
                         policy p: NonlinearStabilityPolicy, work: inout NumericalWork) throws(Cause) -> Data {
        try StabilityArithmetic.check(p)
        let n=s.count,k=s.freeCoordinates,kk=try StabilityArithmetic.product(k,k),N=s.nullBasis
        guard k<=p.spectrum.maximumDimension else { throw .capacityExceeded }
        try StabilityArithmetic.charge(try StabilityArithmetic.product(12,try StabilityArithmetic.product(kk,try StabilityArithmetic.product(n,n))),&work)
        var M=[Double](repeating:0,count:kk),H=M
        for a in 0..<k { for b in 0..<k { for i in 0..<n { for j in 0..<n {
            let factor=N[i*k+a]*N[j*k+b]
            M[a*k+b]+=factor*mass[i*n+j];H[a*k+b]+=factor*hessian[i*n+j]
        } } } }
        try StabilityArithmetic.finite(M);try StabilityArithmetic.finite(H)
        // Positive physical mass is a prerequisite, not inferred from a successful LU solve.
        var maximum=0.0;for value in M { maximum=max(maximum,abs(value)) }
        guard maximum>0 else { throw .nonPositiveMass }
        var L=M
        try StabilityArithmetic.charge(try StabilityArithmetic.product(8,try StabilityArithmetic.product(k,kk)),&work)
        for i in 0..<k { for j in 0...i {
            guard abs(M[i*k+j]-M[j*k+i])<=p.spectralTolerance*maximum else { throw .inertialMismatch }
            var v=M[i*k+j]/maximum
            for a in 0..<j { v-=L[i*k+a]*L[j*k+a] }
            if i==j { guard v.isFinite,v>p.minimumMassPivot else { throw .nonPositiveMass };L[i*k+j]=v.squareRoot() }
            else { L[i*k+j]=v/L[j*k+j] }
        } }
        var operatorEntries=[SpectrumComplex](repeating:SpectrumComplex(real:0,imaginary:0),count:kk)
        var rhs=[Double](repeating:0,count:k)
        for col in 0..<k {
            for i in 0..<k { rhs[i]=H[i*k+col] }
            let x=try StabilityArithmetic.solve(M,rhs:rhs,supplier:linear,policy:p,reserve:s.reserve,work:&work)
            for i in 0..<k { operatorEntries[i*k+col]=SpectrumComplex(real:x[i],imaginary:0) }
        }
        let matrix=ComplexSpectralMatrix(dimension:k,entries:operatorEntries)
        let cap=try StabilityArithmetic.numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:s.reserve) }
        var nested=NumericalWork(budget:cap)
        try StabilityArithmetic.numerical { () throws(NumericalError) in try nested.chargeOperations(1) }
        let seed=nested,result:ComplexSpectrumResult
        do { result=try spectrum.solve(matrix,policy:p.spectrum,work:&nested) }
        catch {
            do { try StabilityArithmetic.prefix(seed,&nested) } catch { try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(seed,reservedStorage:s.reserve) };throw error }
            try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(nested,reservedStorage:s.reserve) };throw .spectral(error)
        }
        do { try StabilityArithmetic.prefix(seed,&nested) } catch { try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(seed,reservedStorage:s.reserve) };throw error }
        guard result.work==nested else { try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(seed,reservedStorage:s.reserve) };throw .invalidSupplierWork }
        try StabilityArithmetic.numerical { () throws(NumericalError) in try work.absorb(nested,reservedStorage:s.reserve) }
        try StabilityArithmetic.check(p)
        guard result.dimension==k,result.eigenvalues.count==k,result.eigenvectors.count==kk,
            result.maximumOriginalResidual.isFinite,result.maximumOriginalResidual>=0,
            result.maximumOriginalResidual<=p.spectrum.originalResidualTolerance else { throw .invalidSupplierOutput }
        var eigenvalues=[Double](repeating:0,count:k),V=[Double](repeating:0,count:kk),modes=[Double](repeating:0,count:n*k)
        try StabilityArithmetic.charge(try StabilityArithmetic.product(64,try StabilityArithmetic.product(k,try StabilityArithmetic.sum(kk,try StabilityArithmetic.product(n,k)))),&work)
        for mode in 0..<k {
            let lambda=result.eigenvalues[mode]
            guard lambda.real.isFinite,lambda.imaginary.isFinite,
                abs(lambda.imaginary)<=p.spectralTolerance*max(1,abs(lambda.real)) else { throw .invalidSupplierOutput }
            eigenvalues[mode]=lambda.real
            var pivot=0
            for i in 0..<k { let v=result.eigenvectors[mode*k+i]
                guard v.real.isFinite,v.imaginary.isFinite else { throw .invalidSupplierOutput }
                if v.amplitude>result.eigenvectors[mode*k+pivot].amplitude { pivot=i }
            }
            let v=result.eigenvectors[mode*k+pivot],amp=v.amplitude
            guard amp>0 else { throw .invalidSupplierOutput }
            for i in 0..<k {
                let w=result.eigenvectors[mode*k+i],real=(w.real*v.real+w.imaginary*v.imaginary)/amp,imag=(w.imaginary*v.real-w.real*v.imaginary)/amp
                guard imag.isFinite,real.isFinite,abs(imag)<=p.spectralTolerance else { throw .invalidSupplierOutput }
                V[mode*k+i]=real
            }
            var norm=0.0
            for i in 0..<k { for j in 0..<k { norm+=V[mode*k+i]*M[i*k+j]*V[mode*k+j] } }
            guard norm.isFinite,norm>0 else { throw .invalidSupplierOutput }
            for i in 0..<k { V[mode*k+i]/=norm.squareRoot() }
            for i in 0..<n { for j in 0..<k { modes[mode*n+i]+=N[i*k+j]*V[mode*k+j] } }
        }
        var residual=0.0,massError=0.0
        for mode in 0..<k {
            try StabilityArithmetic.check(p)
            for i in 0..<k {
                var h=0.0,m=0.0,scale=0.0
                for j in 0..<k { let v=V[mode*k+j];h+=H[i*k+j]*v;m+=M[i*k+j]*v
                    scale+=abs(H[i*k+j]*v)+abs(eigenvalues[mode]*M[i*k+j]*v)
                }
                let error=abs(h-eigenvalues[mode]*m)/max(1,scale)
                guard error.isFinite,error<=p.spectralTolerance else { throw .originalResidualRejected };residual=max(residual,error)
            }
            // Full-coordinate mass orthonormality verifies completeness and rejects duplicate supplier modes.
            for other in 0...mode {
                var inner=0.0
                for i in 0..<n { for j in 0..<n { inner+=modes[mode*n+i]*mass[i*n+j]*modes[other*n+j] } }
                let error=abs(inner-(other==mode ? 1 : 0))
                guard error.isFinite,error<=p.spectralTolerance else { throw .invalidSupplierOutput };massError=max(massError,error)
            }
        }
        // Stable ordering is owned here; no supplier ordering is assumed.
        for i in 0..<k { var pivot=i
            for j in i..<k { if eigenvalues[j]<eigenvalues[pivot] { pivot=j } }
            if pivot != i { eigenvalues.swapAt(i,pivot);for row in 0..<n { modes.swapAt(i*n+row,pivot*n+row) } }
        }
        let classification:NonlinearStabilityPoint.Classification
        if eigenvalues[0] < -p.zeroStiffnessTolerance { classification = .negative }
        else if eigenvalues[0] <= p.zeroStiffnessTolerance { classification = .neutral }
        else { classification = .positive }
        try StabilityArithmetic.check(p)
        return Data(mass:M,stiffness:H,eigenvalues:eigenvalues,modes:modes,residual:residual,massError:massError,classification:classification)
    }
}
