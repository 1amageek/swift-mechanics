public struct ReferenceComplexSpectralSolver: ComplexSpectralSolving, Sendable {
    public init() {}
    @inline(never)
    public func solve(_ matrix:ComplexSpectralMatrix,policy:ComplexSpectrumPolicy,work:inout NumericalWork) throws(ComplexSpectrumError) -> ComplexSpectrumResult {
        try ComplexSpectrumArithmetic.check(policy)
        let n=matrix.dimension
        guard n>0,n<=policy.maximumDimension else { throw .capacityExceeded }
        let nn=try ComplexSpectrumArithmetic.size(n,n)
        guard matrix.entries.count==nn else { throw .invalidInput }
        try ComplexSpectrumArithmetic.reserve(try ComplexSpectrumArithmetic.sum(try ComplexSpectrumArithmetic.size(30,nn),try ComplexSpectrumArithmetic.size(20,n)),&work)
        var scale=0.0
        for row in 0..<n {
            try ComplexSpectrumArithmetic.check(policy);try ComplexSpectrumArithmetic.charge(try ComplexSpectrumArithmetic.size(8,n),&work)
            for column in 0..<n { let value=matrix.entries[row*n+column];guard value.finite else { throw .invalidInput };scale=max(scale,value.amplitude) }
        }
        if scale==0 { scale=1 }
        try ComplexSpectrumArithmetic.charge(try ComplexSpectrumArithmetic.size(4,nn),&work)
        var qr=ComplexQRWorkspace(matrix,scale:scale)
        try qr.hessenberg(policy:policy,work:&work);try qr.schur(policy:policy,work:&work)
        var vectors=try qr.eigenvectors(policy:policy,work:&work),values=[SpectrumComplex](repeating:.zero,count:n)
        for i in 0..<n { values[i]=try ComplexSpectrumArithmetic.finite(qr.h[i*n+i]*scale) }
        // Deterministic order is a value contract, independent of QR deflation order.
        for i in 0..<n {
            try ComplexSpectrumArithmetic.check(policy);try ComplexSpectrumArithmetic.charge(try ComplexSpectrumArithmetic.size(8,n),&work)
            var best=i
            for j in i..<n { if values[j].real<values[best].real || (values[j].real==values[best].real && values[j].imaginary<values[best].imaginary) { best=j } }
            if best != i { values.swapAt(i,best);for row in 0..<n { vectors.swapAt(i*n+row,best*n+row) } }
        }
        let residual=try original(matrix,values:values,vectors:vectors,policy:policy,work:&work)
        try ComplexSpectrumArithmetic.check(policy)
        return ComplexSpectrumResult(dimension:n,eigenvalues:values,eigenvectors:vectors,maximumOriginalResidual:residual,work:work)
    }
    @inline(never)
    private func original(_ matrix:ComplexSpectralMatrix,values:[SpectrumComplex],vectors:[SpectrumComplex],policy:ComplexSpectrumPolicy,work:inout NumericalWork) throws(ComplexSpectrumError) -> Double {
        let n=matrix.dimension;var maximum=0.0
        for mode in 0..<n { for row in 0..<n {
            try ComplexSpectrumArithmetic.check(policy);try ComplexSpectrumArithmetic.charge(try ComplexSpectrumArithmetic.size(32,n),&work)
            var left=SpectrumComplex.zero,scale=0.0
            for j in 0..<n { let term=try ComplexSpectrumArithmetic.finite(matrix.entries[row*n+j]*vectors[mode*n+j]);left=try ComplexSpectrumArithmetic.finite(left+term);scale=try ComplexSpectrumArithmetic.finite(scale+term.amplitude) }
            let right=try ComplexSpectrumArithmetic.finite(values[mode]*vectors[mode*n+row])
            scale=try ComplexSpectrumArithmetic.finite(scale+right.amplitude)
            let residual=try ComplexSpectrumArithmetic.finite((left-right).amplitude/max(1,scale));maximum=max(maximum,residual)
        } }
        guard maximum<=policy.originalResidualTolerance else { throw .residualRejected(value:maximum,threshold:policy.originalResidualTolerance) }
        return maximum
    }
}
