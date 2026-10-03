import MechanicsNumerics
internal struct JacobiSpectrum {
    let values: [Double]
    let vectors: [Double]
    @inline(never)
    static func compute(_ matrix: [Double],n: Int,policy: StructuralPolicy,work: inout NumericalWork) throws(StructuralError) -> JacobiSpectrum {
        let nn=try StructuralArithmetic.size(n,n)
        guard matrix.count==nn,n>0 else { throw .invalidInput }
        var scale=0.0
        for value in matrix { guard value.isFinite else { throw .invalidInput };scale=max(scale,abs(value)) }
        // A zero matrix has exact zero eigenvalues and an identity basis, not a fabricated physical mode.
        var a=[Double](repeating:0,count:nn),v=a
        try StructuralArithmetic.charge(try StructuralArithmetic.size(2,nn),&work)
        for i in 0..<n { v[i*n+i]=1 }
        if scale>0 { for i in 0..<nn { a[i]=matrix[i]/scale } }
        var error=0.0
        while true {
            try StructuralArithmetic.check(policy)
            var p=0,q=0,off=0.0
            try StructuralArithmetic.charge(nn,&work)
            for i in 0..<n { for j in i+1..<n { let value=abs(a[i*n+j]);if value>off { off=value;p=i;q=j } } }
            error=off
            if off<=policy.spectralTolerance { break }
            do { try work.advanceIteration() } catch {
                if case .resourceLimit(resource:.iterations,limit:_) = error { throw .nonConvergence(iterations:work.iterations,residual:off) }
                throw .numerical(error,failedSupplierWorkUnavailable:false)
            }
            let ap=a[p*n+p],aq=a[q*n+q],b=a[p*n+q],delta=aq-ap
            let root=(delta*delta+4*b*b).squareRoot()
            let t=delta==0 ? (b>0 ? 1.0 : -1.0) : 2*b/(delta+(delta>0 ? root : -root))
            let c=1/(1+t*t).squareRoot(),s=t*c
            try StructuralArithmetic.charge(try StructuralArithmetic.sum(30,try StructuralArithmetic.size(30,n)),&work)
            for i in 0..<n where i != p && i != q {
                let x=a[i*n+p],y=a[i*n+q]
                let nextP=try StructuralArithmetic.finite(c*x-s*y),nextQ=try StructuralArithmetic.finite(s*x+c*y)
                a[i*n+p]=nextP;a[p*n+i]=nextP;a[i*n+q]=nextQ;a[q*n+i]=nextQ
            }
            a[p*n+p]=try StructuralArithmetic.finite(ap-t*b);a[q*n+q]=try StructuralArithmetic.finite(aq+t*b);a[p*n+q]=0;a[q*n+p]=0
            for i in 0..<n { let x=v[i*n+p],y=v[i*n+q];v[i*n+p]=c*x-s*y;v[i*n+q]=s*x+c*y }
        }
        var values=[Double](repeating:0,count:n)
        for i in 0..<n { values[i]=try StructuralArithmetic.finite(a[i*n+i]*scale) }
        try StructuralArithmetic.charge(try StructuralArithmetic.size(3,nn),&work)
        // Deterministic ascending order, with original column index breaking equal-value ties.
        for i in 0..<n {
            var selected=i
            for j in i+1..<n { if values[j]<values[selected] { selected=j } }
            if selected != i { values.swapAt(i,selected);for row in 0..<n { v.swapAt(row*n+i,row*n+selected) } }
        }
        try StructuralArithmetic.check(policy)
        _=error
        return JacobiSpectrum(values:values,vectors:v)
    }
}
