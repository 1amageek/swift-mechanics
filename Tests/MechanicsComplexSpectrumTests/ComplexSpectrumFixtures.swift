import SwiftMechanics

struct ComplexSpectrumFixtures {
    static func policy(iterations:Int=10000,deflation:Double=1e-13,residual:Double=1e-9,cancelled:Bool=false,dimension:Int=32) throws -> ComplexSpectrumPolicy {
        try ComplexSpectrumPolicy(maximumDimension:dimension,maximumQRIterations:iterations,deflationTolerance:deflation,
            eigenvectorPivotThreshold:1e-12,originalResidualTolerance:residual,isCancelled:{cancelled})
    }
    static func work(storage:Int=100000,operations:Int=10000000,iterations:Int=10000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:iterations))
    }
    static func matrix(_ entries:[Double],n:Int) -> ComplexSpectralMatrix {
        ComplexSpectralMatrix(dimension:n,entries:entries.map{SpectrumComplex(real:$0,imaginary:0)})
    }
    static func distance(_ a:SpectrumComplex,_ b:SpectrumComplex) -> Double {
        ((a.real-b.real)*(a.real-b.real)+(a.imaginary-b.imaginary)*(a.imaginary-b.imaginary)).squareRoot()
    }
    static func times(_ a:SpectrumComplex,_ b:SpectrumComplex) -> SpectrumComplex {
        SpectrumComplex(real:a.real*b.real-a.imaginary*b.imaginary,imaginary:a.real*b.imaginary+a.imaginary*b.real)
    }
    static func originalResidual(_ a:ComplexSpectralMatrix,_ result:ComplexSpectrumResult) -> Double {
        var maximum=0.0
        for mode in 0..<a.dimension { for row in 0..<a.dimension {
            var real=0.0,imaginary=0.0
            for j in 0..<a.dimension {
                let x=a.entries[row*a.dimension+j],v=result.eigenvectors[mode*a.dimension+j]
                real+=x.real*v.real-x.imaginary*v.imaginary;imaginary+=x.real*v.imaginary+x.imaginary*v.real
            }
            let z=result.eigenvalues[mode],v=result.eigenvectors[mode*a.dimension+row]
            real-=z.real*v.real-z.imaginary*v.imaginary;imaginary-=z.real*v.imaginary+z.imaginary*v.real
            maximum=max(maximum,(real*real+imaginary*imaginary).squareRoot())
        } }
        return maximum
    }
}
