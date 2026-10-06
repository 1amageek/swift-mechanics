/// Operation-local normalized physical matrices and nonsymmetric companion; no shared cache.
internal struct GeneralDampedWorkspace {
    let n:Int,dimension:Int,reserved:Int
    let mass:[Double],stiffness:[Double],damping:[Double],companion:ComplexSpectralMatrix
    @inline(never)
    init(_ pencil:StructuralPencil,expected:StructuralBinding,policy:StructuralPolicy,work:inout NumericalWork) throws(GeneralDampedSpectrumCause) {
        let bindingStorage=try GeneralDampedAdmission.validate(pencil,expected:expected,policy:policy,work:&work)
        n=pencil.count;dimension=try DampedSpectrumArithmetic.product(2,n)
        let nn=try DampedSpectrumArithmetic.product(n,n),dd=try DampedSpectrumArithmetic.product(dimension,dimension)
        reserved=try DampedSpectrumArithmetic.sum(bindingStorage,try DampedSpectrumArithmetic.sum(try DampedSpectrumArithmetic.product(40,nn),try DampedSpectrumArithmetic.product(40,n)))
        try DampedSpectrumArithmetic.reserve(reserved,&work)
        let t2=try DampedSpectrumArithmetic.finite(policy.timeScale*policy.timeScale)
        guard t2>0 else { throw .structural(.nonFiniteResult) }
        var m=[Double](repeating:0,count:nn),k=m,c=m,l=m
        for i in 0..<n {
            try DampedSpectrumArithmetic.check(policy);try DampedSpectrumArithmetic.charge(try DampedSpectrumArithmetic.product(32,n),&work)
            for j in 0..<n {
                let ij=i*n+j,si=pencil.binding.coordinateScales[i],sj=pencil.binding.coordinateScales[j]
                m[ij]=try DampedSpectrumArithmetic.finite(((pencil.mass[ij]/policy.energyScale)*si)*sj/t2)
                k[ij]=try DampedSpectrumArithmetic.finite(((pencil.stiffness[ij]/policy.energyScale)*si)*sj)
                c[ij]=try DampedSpectrumArithmetic.finite(((pencil.damping[ij]/policy.energyScale)*si)*sj/policy.timeScale)
            }
        }
        for i in 0..<n {
            try DampedSpectrumArithmetic.check(policy)
            for j in 0...i {
                try DampedSpectrumArithmetic.charge(try DampedSpectrumArithmetic.sum(8,try DampedSpectrumArithmetic.product(4,j)),&work)
                var sum=m[i*n+j]
                for q in 0..<j { sum=try DampedSpectrumArithmetic.finite(sum-l[i*n+q]*l[j*n+q]) }
                if i==j {
                    guard sum>policy.positiveMassThreshold else { throw .structural(.nonPositiveMass) };l[i*n+j]=sum.squareRoot()
                } else { l[i*n+j]=try DampedSpectrumArithmetic.finite(sum/l[j*n+j]) }
            }
        }
        let inverseK=try Self.massSolve(l,k,n:n,policy:policy,work:&work),inverseC=try Self.massSolve(l,c,n:n,policy:policy,work:&work)
        var a=[SpectrumComplex](repeating:DampedSpectrumArithmetic.zero,count:dd)
        try DampedSpectrumArithmetic.charge(try DampedSpectrumArithmetic.product(8,dd),&work)
        for i in 0..<n {
            a[i*dimension+n+i]=SpectrumComplex(real:1,imaginary:0)
            for j in 0..<n {
                a[(n+i)*dimension+j]=SpectrumComplex(real:-inverseK[i*n+j],imaginary:0)
                a[(n+i)*dimension+n+j]=SpectrumComplex(real:-inverseC[i*n+j],imaginary:0)
            }
        }
        mass=m;stiffness=k;damping=c;companion=ComplexSpectralMatrix(dimension:dimension,entries:a)
    }
    @inline(never)
    private static func massSolve(_ l:[Double],_ b:[Double],n:Int,policy:StructuralPolicy,work:inout NumericalWork) throws(GeneralDampedSpectrumCause) -> [Double] {
        var x=b
        for column in 0..<n {
            try DampedSpectrumArithmetic.check(policy);try DampedSpectrumArithmetic.charge(try DampedSpectrumArithmetic.product(12,try DampedSpectrumArithmetic.product(n,n)),&work)
            for row in 0..<n {
                var sum=x[row*n+column]
                for j in 0..<row { sum=try DampedSpectrumArithmetic.finite(sum-l[row*n+j]*x[j*n+column]) }
                x[row*n+column]=try DampedSpectrumArithmetic.finite(sum/l[row*n+row])
            }
            for row in stride(from:n-1,through:0,by:-1) {
                var sum=x[row*n+column]
                if row+1<n { for j in (row+1)..<n { sum=try DampedSpectrumArithmetic.finite(sum-l[j*n+row]*x[j*n+column]) } }
                x[row*n+column]=try DampedSpectrumArithmetic.finite(sum/l[row*n+row])
            }
        }
        return x
    }
}
