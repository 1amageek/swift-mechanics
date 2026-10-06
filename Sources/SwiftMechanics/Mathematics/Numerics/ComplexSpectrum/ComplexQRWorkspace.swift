/// Exclusive per-operation Hessenberg/Schur storage; no state escapes as shared mutable storage.
internal struct ComplexQRWorkspace {
    let n:Int
    var h:[SpectrumComplex],unitary:[SpectrumComplex],vector:[SpectrumComplex]
    init(_ matrix:ComplexSpectralMatrix,scale:Double) {
        n=matrix.dimension;h=matrix.entries;unitary=[SpectrumComplex](repeating:.zero,count:h.count)
        vector=[SpectrumComplex](repeating:.zero,count:n)
        for i in h.indices { h[i]=h[i]/scale }
        for i in 0..<n { unitary[i*n+i] = .one }
    }
    @inline(never)
    mutating func hessenberg(policy:ComplexSpectrumPolicy,work:inout NumericalWork) throws(ComplexSpectrumError) {
        if n<3 { return }
        for k in 0..<(n-2) {
            try ComplexSpectrumArithmetic.check(policy)
            try ComplexSpectrumArithmetic.charge(try ComplexSpectrumArithmetic.size(120,try ComplexSpectrumArithmetic.size(n,n)),&work)
            var norm=0.0
            for i in (k+1)..<n { vector[i]=h[i*n+k];norm=ScalarMath.norm(norm,vector[i].amplitude) }
            if norm==0 { continue }
            let first=vector[k+1],phase=first.amplitude==0 ? SpectrumComplex.one : first/first.amplitude
            vector[k+1]=vector[k+1]+phase*norm
            var vnorm=0.0
            for i in (k+1)..<n { vnorm=ScalarMath.norm(vnorm,vector[i].amplitude) }
            for i in (k+1)..<n { vector[i]=vector[i]/vnorm }
            for column in k..<n {
                var dot=SpectrumComplex.zero
                for row in (k+1)..<n { dot=dot+vector[row].conjugate*h[row*n+column] }
                for row in (k+1)..<n { h[row*n+column]=try ComplexSpectrumArithmetic.finite(h[row*n+column]-vector[row]*dot*2) }
            }
            for row in 0..<n {
                try ComplexSpectrumArithmetic.check(policy)
                var dot=SpectrumComplex.zero,udot=SpectrumComplex.zero
                for column in (k+1)..<n { dot=dot+h[row*n+column]*vector[column];udot=udot+unitary[row*n+column]*vector[column] }
                for column in (k+1)..<n {
                    h[row*n+column]=try ComplexSpectrumArithmetic.finite(h[row*n+column]-dot*vector[column].conjugate*2)
                    unitary[row*n+column]=try ComplexSpectrumArithmetic.finite(unitary[row*n+column]-udot*vector[column].conjugate*2)
                }
            }
            for row in (k+2)..<n { h[row*n+k] = .zero }
        }
    }
    @inline(never)
    mutating func schur(policy:ComplexSpectrumPolicy,work:inout NumericalWork) throws(ComplexSpectrumError) {
        var hi=n-1,steps=0
        while hi>0 {
            try ComplexSpectrumArithmetic.check(policy)
            try ComplexSpectrumArithmetic.charge(try ComplexSpectrumArithmetic.size(16,n),&work)
            var lo=0
            for i in stride(from:hi,through:1,by:-1) {
                let threshold=policy.deflationTolerance*(1+h[(i-1)*n+i-1].amplitude+h[i*n+i].amplitude)
                if h[i*n+i-1].amplitude<=threshold { h[i*n+i-1] = .zero;lo=i;break }
            }
            if lo==hi { hi-=1;continue }
            guard steps<policy.maximumQRIterations else { throw .nonConvergence(iterations:steps,residual:h[hi*n+hi-1].amplitude) }
            do { try work.advanceIteration() } catch { throw .numerical(error) }
            try ComplexSpectrumArithmetic.charge(128,&work)
            let shift=try trailingShift(hi:hi,steps:steps)
            try step(lo:lo,hi:hi,shift:shift,policy:policy,work:&work)
            steps+=1
        }
    }
    private func trailingShift(hi:Int,steps:Int) throws(ComplexSpectrumError) -> SpectrumComplex {
        let a=h[(hi-1)*n+hi-1],b=h[(hi-1)*n+hi],c=h[hi*n+hi-1],d=h[hi*n+hi]
        // Periodic exceptional complex shifts break exact cycling without changing the matrix.
        if steps>0 && steps%20==0 { return try ComplexSpectrumArithmetic.finite(d+SpectrumComplex(real:0.75*c.amplitude,imaginary:0.25*c.amplitude)) }
        let half=(a-d)/2,root=try ComplexSpectrumArithmetic.finite((half*half+b*c).squareRoot)
        let center=(a+d)/2,first=center+root,second=center-root
        return try ComplexSpectrumArithmetic.finite((first-d).amplitude < (second-d).amplitude ? first : second)
    }
    @inline(never)
    private mutating func step(lo:Int,hi:Int,shift:SpectrumComplex,policy:ComplexSpectrumPolicy,work:inout NumericalWork) throws(ComplexSpectrumError) {
        for k in lo..<hi {
            try ComplexSpectrumArithmetic.check(policy)
            try ComplexSpectrumArithmetic.charge(try ComplexSpectrumArithmetic.size(160,n),&work)
            let a=k==lo ? h[k*n+k]-shift : h[k*n+k-1],b=k==lo ? h[(k+1)*n+k] : h[(k+1)*n+k-1]
            let norm=ScalarMath.norm(a.amplitude,b.amplitude)
            if norm==0 { continue }
            let cosine=a.amplitude/norm,phase=a.amplitude==0 ? SpectrumComplex.one : a/a.amplitude
            let sine=phase*b.conjugate/norm,p=k,q=k+1
            for column in max(lo,k-1)..<n {
                let x=h[p*n+column],y=h[q*n+column]
                h[p*n+column]=try ComplexSpectrumArithmetic.finite(x*cosine+sine*y)
                h[q*n+column]=try ComplexSpectrumArithmetic.finite(-sine.conjugate*x+y*cosine)
            }
            for row in 0...min(hi,k+2) {
                let x=h[row*n+p],y=h[row*n+q]
                h[row*n+p]=try ComplexSpectrumArithmetic.finite(x*cosine+y*sine.conjugate)
                h[row*n+q]=try ComplexSpectrumArithmetic.finite(-x*sine+y*cosine)
            }
            for row in 0..<n {
                let x=unitary[row*n+p],y=unitary[row*n+q]
                unitary[row*n+p]=try ComplexSpectrumArithmetic.finite(x*cosine+y*sine.conjugate)
                unitary[row*n+q]=try ComplexSpectrumArithmetic.finite(-x*sine+y*cosine)
            }
            if k>lo { h[q*n+k-1] = .zero }
        }
    }
    @inline(never)
    mutating func eigenvectors(policy:ComplexSpectrumPolicy,work:inout NumericalWork) throws(ComplexSpectrumError) -> [SpectrumComplex] {
        var result=[SpectrumComplex](repeating:.zero,count:h.count)
        for mode in 0..<n {
            try ComplexSpectrumArithmetic.check(policy)
            try ComplexSpectrumArithmetic.charge(try ComplexSpectrumArithmetic.size(40,try ComplexSpectrumArithmetic.size(n,n)),&work)
            for i in 0..<n { vector[i] = .zero };vector[mode] = .one
            if mode>0 {
                for row in stride(from:mode-1,through:0,by:-1) {
                    var sum=SpectrumComplex.zero
                    for j in (row+1)...mode { sum=sum+h[row*n+j]*vector[j] }
                    let denominator=h[row*n+row]-h[mode*n+mode]
                    if denominator.amplitude<=policy.eigenvectorPivotThreshold {
                        guard sum.amplitude<=policy.eigenvectorPivotThreshold else { throw .illConditionedEigenvector(index:mode) }
                        vector[row] = .zero
                    } else { vector[row]=try ComplexSpectrumArithmetic.finite(-sum/denominator) }
                    // Rescaling preserves direction while protecting subsequent triangular products.
                    var largest=1.0
                    for j in row...mode { largest=max(largest,vector[j].amplitude) }
                    if largest>1 { for j in row...mode { vector[j]=vector[j]/largest } }
                }
            }
            var norm=0.0,pivot=0
            for row in 0..<n {
                var value=SpectrumComplex.zero
                for j in 0...mode { value=value+unitary[row*n+j]*vector[j] }
                result[mode*n+row]=try ComplexSpectrumArithmetic.finite(value)
                norm=ScalarMath.norm(norm,value.amplitude)
                if value.amplitude>result[mode*n+pivot].amplitude { pivot=row }
            }
            guard norm>0,norm.isFinite else { throw .illConditionedEigenvector(index:mode) }
            let phase=result[mode*n+pivot].conjugate/result[mode*n+pivot].amplitude
            for row in 0..<n { result[mode*n+row]=try ComplexSpectrumArithmetic.finite(result[mode*n+row]*phase/norm) }
        }
        return result
    }
}
