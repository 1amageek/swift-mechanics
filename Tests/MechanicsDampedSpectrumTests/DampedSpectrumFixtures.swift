@testable import SwiftMechanics

struct DampedSpectrumFixtures {
    static func policy(cancelled:@escaping @Sendable ()->Bool={false},time:Double=1,energy:Double=1,residual:Double=1e-8,coordinates:Int=16) throws -> StructuralPolicy {
        try StructuralPolicy(maximumCoordinates:coordinates,maximumMetadataBytes:10000,energyScale:energy,timeScale:time,
            spectralTolerance:1e-13,positiveMassThreshold:1e-14,originalResidualTolerance:residual,zeroEigenvalueThreshold:1e-8,isCancelled:cancelled)
    }
    static func spectrum(iterations:Int=10000,residual:Double=1e-9,cancelled:@escaping @Sendable ()->Bool={false}) throws -> ComplexSpectrumPolicy {
        try ComplexSpectrumPolicy(maximumDimension:32,maximumQRIterations:iterations,deflationTolerance:1e-13,
            eigenvectorPivotThreshold:1e-12,originalResidualTolerance:residual,isCancelled:cancelled)
    }
    static func work(storage:Int=100000,operations:Int=10000000,iterations:Int=10000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:iterations))
    }
    static func binding(n:Int=2,revision:UInt64=1,scales:[Double]=[1,1]) throws -> StructuralBinding {
        try StructuralBinding(identity:"independent-coupled-pencil",revision:revision,frame:EntityID(kind:.frame,key:"spectrum-frame"),source:.equilibriumReduction,
            provenance:SourceProvenance(source:"independent-original-quadratic-equations",revision:1),sourceCoordinateIDs:[],reductionBasis:[],beam:nil,
            equilibriumModel:nil,operatingParameter:nil,branchIdentity:nil,retainedCoordinates:Array(0..<n),dimensions:[PhysicalDimension](repeating:.length,count:n),
            coordinateScales:scales,operatingTime:0,operatingCoordinates:[])
    }
    static func pencil(coupling:Double=2.0.squareRoot(),congruence:[Double]=[1,1],scales:[Double]=[1,1]) throws -> StructuralPencil {
        let a=congruence[0],b=congruence[1]
        return try StructuralPencil(binding:binding(scales:scales),mass:[a*a,0,0,b*b],stiffness:[2*a*a,0,0,8*b*b],damping:[a*a,coupling*a*b,coupling*a*b,2*b*b])
    }
    static var expected:[SpectrumComplex] {
        [SpectrumComplex(real:-1,imaginary:-3.0.squareRoot()),SpectrumComplex(real:-1,imaginary:3.0.squareRoot()),
         SpectrumComplex(real:-0.5,imaginary:-15.0.squareRoot()/2),SpectrumComplex(real:-0.5,imaginary:15.0.squareRoot()/2)]
    }
    static func nearest(_ values:[SpectrumComplex],_ expected:SpectrumComplex) -> SpectrumComplex {
        values.min{ComplexFixtureMath.distance($0,expected)<ComplexFixtureMath.distance($1,expected)}!
    }
    static func original(_ p:StructuralPencil,_ result:GeneralDampedModalResult) -> (Double,Double) {
        let n=p.count;var residual=0.0,massError=0.0
        for mode in result.poles.indices {
            let z=result.poles[mode],z2=ComplexFixtureMath.multiply(z,z);var realMass=0.0,imaginaryMass=0.0
            for row in 0..<n {
                var real=0.0,imaginary=0.0
                for j in 0..<n {
                    let coefficient=SpectrumComplex(real:z2.real*p.mass[row*n+j]+z.real*p.damping[row*n+j]+p.stiffness[row*n+j],imaginary:z2.imaginary*p.mass[row*n+j]+z.imaginary*p.damping[row*n+j])
                    let v=result.modes[mode*n+j],term=ComplexFixtureMath.multiply(coefficient,v)
                    real+=term.real;imaginary+=term.imaginary
                    let left=result.modes[mode*n+row]
                    realMass+=p.mass[row*n+j]*(left.real*v.real+left.imaginary*v.imaginary)
                    imaginaryMass+=p.mass[row*n+j]*(left.real*v.imaginary-left.imaginary*v.real)
                }
                residual=max(residual,(real*real+imaginary*imaginary).squareRoot())
            }
            massError=max(massError,max(abs(realMass-1),abs(imaginaryMass)))
        }
        return (residual,massError)
    }
}
