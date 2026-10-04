public struct ReferenceModalAnalyzer: ModalAnalyzing, Sendable {
    public init() {}
    @inline(never)
    public func modes(_ pencil: StructuralPencil,expectedBinding: StructuralBinding,policy: StructuralPolicy,work: inout NumericalWork) throws(StructuralError) -> ModalResult {
        try StructuralArithmetic.validate(pencil,expected:expectedBinding,policy:policy,work:&work)
        let n=pencil.count,nn=try StructuralArithmetic.size(n,n)
        try StructuralArithmetic.reserve(try StructuralArithmetic.sum(try StructuralArithmetic.bindingStorage(pencil.binding),try StructuralArithmetic.sum(try StructuralArithmetic.size(18,nn),try StructuralArithmetic.size(12,n))),&work)
        let time2=try StructuralArithmetic.finite(policy.timeScale*policy.timeScale)
        guard time2>0 else { throw .nonFiniteResult }
        var mass=[Double](repeating:0,count:nn),stiffness=mass
        for i in 0..<n { try StructuralArithmetic.check(policy);try StructuralArithmetic.charge(try StructuralArithmetic.size(8,n),&work)
            for j in i..<n { let index=i*n+j,si=pencil.binding.coordinateScales[i],sj=pencil.binding.coordinateScales[j]
                let m=try StructuralArithmetic.finite(((pencil.mass[index]/policy.energyScale)*si)*sj/time2),k=try StructuralArithmetic.finite(((pencil.stiffness[index]/policy.energyScale)*si)*sj)
                mass[index]=m;mass[j*n+i]=m;stiffness[index]=k;stiffness[j*n+i]=k
            }
        }
        let massSpectrum=try JacobiSpectrum.compute(mass,n:n,policy:policy,work:&work)
        var whitening=[Double](repeating:0,count:nn)
        for column in 0..<n {
            guard massSpectrum.values[column]>policy.positiveMassThreshold else { throw .nonPositiveMass }
            let factor=1/massSpectrum.values[column].squareRoot()
            try StructuralArithmetic.charge(try StructuralArithmetic.size(2,n),&work)
            for row in 0..<n { whitening[row*n+column]=try StructuralArithmetic.finite(massSpectrum.vectors[row*n+column]*factor) }
        }
        var temporary=[Double](repeating:0,count:nn),reduced=temporary
        for i in 0..<n { try StructuralArithmetic.check(policy)
            for j in 0..<n { var sum=0.0;try StructuralArithmetic.charge(try StructuralArithmetic.size(2,n),&work)
                for k in 0..<n { sum=try StructuralArithmetic.finite(sum+stiffness[i*n+k]*whitening[k*n+j]) };temporary[i*n+j]=sum
            }
        }
        for i in 0..<n { try StructuralArithmetic.check(policy)
            for j in i..<n { var sum=0.0;try StructuralArithmetic.charge(try StructuralArithmetic.size(2,n),&work)
                for k in 0..<n { sum=try StructuralArithmetic.finite(sum+whitening[k*n+i]*temporary[k*n+j]) };reduced[i*n+j]=sum;reduced[j*n+i]=sum
            }
        }
        let spectrum=try JacobiSpectrum.compute(reduced,n:n,policy:policy,work:&work)
        var modes=[Double](repeating:0,count:nn),values=[Double](repeating:0,count:n),classes:[ModeClassification]=[];classes.reserveCapacity(n)
        let normalization=try StructuralArithmetic.finite(policy.energyScale.squareRoot()*policy.timeScale)
        guard normalization>0 else { throw .nonFiniteResult }
        for column in 0..<n {
            try StructuralArithmetic.check(policy);values[column]=try StructuralArithmetic.finite(spectrum.values[column]/time2)
            classes.append(values[column] > policy.zeroEigenvalueThreshold ? .oscillatory : (values[column] < -policy.zeroEigenvalueThreshold ? .unstable : .neutral))
            var pivot=0
            for row in 0..<n { var value=0.0;try StructuralArithmetic.charge(try StructuralArithmetic.sum(3,try StructuralArithmetic.size(2,n)),&work)
                for k in 0..<n { value=try StructuralArithmetic.finite(value+whitening[row*n+k]*spectrum.vectors[k*n+column]) }
                modes[row*n+column]=try StructuralArithmetic.finite(pencil.binding.coordinateScales[row]*value/normalization)
                if abs(modes[row*n+column])>abs(modes[pivot*n+column]) { pivot=row }
            }
            if modes[pivot*n+column]<0 { for row in 0..<n { modes[row*n+column] = -modes[row*n+column] } }
        }
        let evidence=try original(pencil,values:values,modes:modes,policy:policy,work:&work)
        try StructuralArithmetic.check(policy)
        return ModalResult(binding:pencil.binding,eigenvalues:values,modes:modes,classifications:classes,maximumOriginalResidual:evidence.0,maximumMassOrthogonalityError:evidence.1,work:work)
    }
    private func original(_ pencil: StructuralPencil,values: [Double],modes: [Double],policy: StructuralPolicy,work: inout NumericalWork) throws(StructuralError) -> (Double,Double) {
        let n=pencil.count;var residual=0.0,orthogonality=0.0
        for column in 0..<n { try StructuralArithmetic.check(policy)
            for row in 0..<n { var k=0.0,m=0.0;try StructuralArithmetic.charge(try StructuralArithmetic.size(4,n),&work)
                for j in 0..<n { k=try StructuralArithmetic.finite(k+pencil.stiffness[row*n+j]*modes[j*n+column]);m=try StructuralArithmetic.finite(m+pencil.mass[row*n+j]*modes[j*n+column]) }
                let right=try StructuralArithmetic.finite(values[column]*m)
                let factor=try StructuralArithmetic.finite(pencil.binding.coordinateScales[row]*policy.timeScale/policy.energyScale.squareRoot())
                let leftScaled=try StructuralArithmetic.finite(k*factor),rightScaled=try StructuralArithmetic.finite(right*factor)
                let scaled=try StructuralArithmetic.finite(abs(leftScaled-rightScaled)/max(1,max(abs(leftScaled),abs(rightScaled))))
                residual=max(residual,scaled)
            }
            for other in 0...column { var inner=0.0
                for i in 0..<n { try StructuralArithmetic.charge(try StructuralArithmetic.size(3,n),&work)
                    for j in 0..<n { inner=try StructuralArithmetic.finite(inner+modes[i*n+column]*pencil.mass[i*n+j]*modes[j*n+other]) }
                }
                orthogonality=max(orthogonality,abs(inner-(other==column ? 1 : 0)))
            }
        }
        let error=max(residual,orthogonality)
        guard error<=policy.originalResidualTolerance else { throw .residualRejected(value:error,threshold:policy.originalResidualTolerance) }
        return (residual,orthogonality)
    }
    public func dampedModes(_ pencil: StructuralPencil,expectedBinding: StructuralBinding,massDamping: Double,stiffnessDamping: Double,
                            policy: StructuralPolicy,work: inout NumericalWork) throws(StructuralError) -> DampedModalResult {
        guard massDamping.isFinite,massDamping>=0,stiffnessDamping.isFinite,stiffnessDamping>=0 else { throw .invalidInput }
        let modes=try modes(pencil,expectedBinding:expectedBinding,policy:policy,work:&work),n=pencil.count
        var first:[StructuralComplex]=[],second:[StructuralComplex]=[];first.reserveCapacity(n);second.reserveCapacity(n)
        var residual=0.0
        for i in 0..<n { try StructuralArithmetic.check(policy)
            guard modes.classifications[i] == .oscillatory else { throw .outsideDomain }
            let lambda=modes.eigenvalues[i],d=try StructuralArithmetic.finite(massDamping+stiffnessDamping*lambda),half=d/2
            let discriminant=try StructuralArithmetic.finite(half*half-lambda)
            let z1:StructuralComplex,z2:StructuralComplex
            if discriminant<=0 { let imag=(-discriminant).squareRoot();z1=try StructuralComplex(real:-half,imaginary:imag);z2=try StructuralComplex(real:-half,imaginary:-imag) }
            else { let root=discriminant.squareRoot();let large = -half-root;z1=try StructuralComplex(real:large,imaginary:0);z2=try StructuralComplex(real:lambda/large,imaginary:0) }
            first.append(z1);second.append(z2)
            for row in 0..<n { var mv=0.0,cv=0.0,kv=0.0
                for j in 0..<n { let ij=row*n+j,v=modes.modes[j*n+i]
                    try StructuralArithmetic.charge(16,&work)
                    let expected=try StructuralArithmetic.finite(massDamping*pencil.mass[ij]+stiffnessDamping*pencil.stiffness[ij])
                    guard abs(pencil.damping[ij]-expected)/max(1,abs(expected))<=policy.originalResidualTolerance else { throw .unsupportedDomain }
                    mv=try StructuralArithmetic.finite(mv+pencil.mass[ij]*v);cv=try StructuralArithmetic.finite(cv+pencil.damping[ij]*v);kv=try StructuralArithmetic.finite(kv+pencil.stiffness[ij]*v)
                }
                for pole in 0..<2 {
                    let z=pole==0 ? z1 : z2
                    let real=try StructuralArithmetic.finite((z.real*z.real-z.imaginary*z.imaginary)*mv+z.real*cv+kv)
                    let imag=try StructuralArithmetic.finite(2*z.real*z.imaginary*mv+z.imaginary*cv)
                    let factor=try StructuralArithmetic.finite(pencil.binding.coordinateScales[row]*policy.timeScale/policy.energyScale.squareRoot())
                    let scale=max(1,max(abs(kv*factor),max(abs(z.real*cv*factor),abs((z.real*z.real-z.imaginary*z.imaginary)*mv*factor))))
                    residual=max(residual,try StructuralArithmetic.finite(max(abs(real*factor),abs(imag*factor))/scale))
                }
            }
        }
        guard residual<=policy.originalResidualTolerance else { throw .residualRejected(value:residual,threshold:policy.originalResidualTolerance) }
        try StructuralArithmetic.check(policy);return DampedModalResult(modes:modes,firstPoles:first,secondPoles:second,maximumOriginalQuadraticResidual:residual,work:work)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Nonproportional damped eigenanalysis is not implemented. This public branch rejects requests until a real nonsymmetric complex pencil algorithm and original quadratic residual/profile proof exist.
    public func nonproportionalDampedModes(_ pencil: StructuralPencil,expectedBinding: StructuralBinding,policy: StructuralPolicy,work: inout NumericalWork) throws(StructuralError) -> DampedModalResult {
        try StructuralArithmetic.validate(pencil,expected:expectedBinding,policy:policy,work:&work);throw .unsupportedDomain
    }
}
