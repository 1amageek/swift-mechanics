import MechanicsCore
import MechanicsModel
import MechanicsFlexible
import MechanicsMaterials
import MechanicsNumerics
public struct ReferenceHarmonicAnalyzer: HarmonicAnalyzing, Sendable {
    public let solver: any LinearSolving<Double>
    public init(solver: any LinearSolving<Double> = ReferenceLinearSolver<Double>()) { self.solver=solver }
    @inline(never)
    public func response(_ pencil: StructuralPencil,expectedBinding: StructuralBinding,excitation: HarmonicExcitation,
                         linearTolerance: LinearTolerance<Double>,policy: StructuralPolicy,work: inout NumericalWork) throws(StructuralError) -> HarmonicResponse {
        try StructuralArithmetic.validate(pencil,expected:expectedBinding,policy:policy,work:&work)
        try StructuralArithmetic.metadata(excitation.identity,"",policy:policy)
        let bytes=try StructuralArithmetic.sum(try StructuralArithmetic.sum(pencil.binding.identity.utf8.count,pencil.binding.frame.key.utf8.count),try StructuralArithmetic.sum(pencil.binding.provenance?.source.utf8.count ?? 0,excitation.identity.utf8.count))
        guard bytes<=policy.maximumMetadataBytes else { throw .capacityExceeded }
        let n=pencil.count,o=excitation.outputDimensions.count,nn=try StructuralArithmetic.size(n,n),twice=try StructuralArithmetic.size(2,n)
        guard o>0,o<=policy.maximumCoordinates,excitation.realEffort.count==n,excitation.imaginaryEffort.count==n,
            excitation.outputMap.count == (try StructuralArithmetic.size(o,n)) else { throw .invalidInput }
        let omega=excitation.angularFrequency
        guard omega.isFinite,omega>=0,excitation.maximumAngularFrequency.isFinite,excitation.maximumAngularFrequency>=omega,
            excitation.maximumNormalizedAmplitude.isFinite,excitation.maximumNormalizedAmplitude>0 else { throw .outsideDomain }
        let reserve=try StructuralArithmetic.sum(try StructuralArithmetic.bindingStorage(pencil.binding),try StructuralArithmetic.sum(try StructuralArithmetic.size(8,nn),try StructuralArithmetic.sum(try StructuralArithmetic.size(12,n),try StructuralArithmetic.size(4,try StructuralArithmetic.size(o,n)))))
        try StructuralArithmetic.reserve(reserve,&work)
        var block=[Double](repeating:0,count:try StructuralArithmetic.size(twice,twice)),rhs=[Double](repeating:0,count:twice)
        let omega2=try StructuralArithmetic.finite(omega*omega)
        for i in 0..<n {
            try StructuralArithmetic.check(policy);try StructuralArithmetic.charge(try StructuralArithmetic.sum(6,try StructuralArithmetic.size(12,n)),&work)
            guard excitation.realEffort[i].isFinite,excitation.imaginaryEffort[i].isFinite else { throw .invalidInput }
            let si=pencil.binding.coordinateScales[i]
            rhs[i]=try StructuralArithmetic.finite(excitation.realEffort[i]/policy.energyScale*si)
            rhs[n+i]=try StructuralArithmetic.finite(excitation.imaginaryEffort[i]/policy.energyScale*si)
            for j in 0..<n {
                let ij=i*n+j,sj=pencil.binding.coordinateScales[j]
                let real=try StructuralArithmetic.finite((pencil.stiffness[ij]-omega2*pencil.mass[ij])/policy.energyScale*si*sj)
                let imaginary=try StructuralArithmetic.finite(omega*pencil.damping[ij]/policy.energyScale*si*sj)
                block[i*twice+j]=real;block[i*twice+n+j] = -imaginary
                block[(n+i)*twice+j]=imaginary;block[(n+i)*twice+n+j]=real
            }
        }
        let matrix=try StructuralArithmetic.num { () throws(NumericalError) in try DenseMatrix(rows:twice,columns:twice,values:block) }
        let budget=try StructuralArithmetic.num { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserve) }
        let solved:LinearSolution<Double>
        do { solved=try solver.solve(matrix,rightHandSide:rhs,capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),tolerance:linearTolerance,budget:budget) }
        catch { throw .numerical(error,failedSupplierWorkUnavailable:true) }
        try StructuralArithmetic.num { () throws(NumericalError) in try work.absorb(solved.diagnostics.work,reservedStorage:reserve) }
        guard solved.values.count==twice else { throw .invalidInput }
        var coordinates:[StructuralComplex]=[];coordinates.reserveCapacity(n);var amplitude=0.0
        for i in 0..<n { try StructuralArithmetic.check(policy)
            let real=try StructuralArithmetic.finite(solved.values[i]*pencil.binding.coordinateScales[i]),imaginary=try StructuralArithmetic.finite(solved.values[n+i]*pencil.binding.coordinateScales[i])
            let z=try StructuralComplex(real:real,imaginary:imaginary);coordinates.append(z)
            amplitude=max(amplitude,try StructuralArithmetic.finite(z.amplitude/pencil.binding.coordinateScales[i]))
        }
        guard amplitude<=excitation.maximumNormalizedAmplitude else { throw .outsideDomain }
        try beamEnvelope(pencil,coordinates:coordinates,policy:policy,work:&work)
        var residual=0.0
        for i in 0..<n {
            try StructuralArithmetic.check(policy);var real=0.0,imaginary=0.0
            for j in 0..<n { try StructuralArithmetic.charge(14,&work);let ij=i*n+j,a=pencil.stiffness[ij]-omega2*pencil.mass[ij],b=omega*pencil.damping[ij]
                real=try StructuralArithmetic.finite(real+a*coordinates[j].real-b*coordinates[j].imaginary)
                imaginary=try StructuralArithmetic.finite(imaginary+a*coordinates[j].imaginary+b*coordinates[j].real)
            }
            let si=pencil.binding.coordinateScales[i]/policy.energyScale
            let reference=max(1,max(abs(real*si),max(abs(imaginary*si),max(abs(excitation.realEffort[i]*si),abs(excitation.imaginaryEffort[i]*si)))))
            let error=try StructuralArithmetic.finite(max(abs((real-excitation.realEffort[i])*si),abs((imaginary-excitation.imaginaryEffort[i])*si))/reference)
            residual=max(residual,error)
        }
        guard residual<=policy.originalResidualTolerance else { throw .residualRejected(value:residual,threshold:policy.originalResidualTolerance) }
        var outputs:[StructuralComplex]=[];outputs.reserveCapacity(o)
        for row in 0..<o { try StructuralArithmetic.check(policy);var real=0.0,imaginary=0.0
            for j in 0..<n { try StructuralArithmetic.charge(5,&work);let entry=excitation.outputMap[row*n+j];guard entry.isFinite else { throw .invalidInput }
                real=try StructuralArithmetic.finite(real+entry*coordinates[j].real);imaginary=try StructuralArithmetic.finite(imaginary+entry*coordinates[j].imaginary)
            };let z=try StructuralComplex(real:real,imaginary:imaginary);guard z.amplitude.isFinite else { throw .nonFiniteResult };outputs.append(z)
        }
        try StructuralArithmetic.check(policy)
        return HarmonicResponse(binding:pencil.binding,excitation:excitation,coordinates:coordinates,outputs:outputs,maximumOriginalResidual:residual,maximumNormalizedAmplitude:amplitude,work:work)
    }
    private func beamEnvelope(_ pencil:StructuralPencil,coordinates:[StructuralComplex],policy:StructuralPolicy,work:inout NumericalWork) throws(StructuralError) {
        guard let beam=pencil.binding.beam else { return }
        let h=try StructuralArithmetic.finite(beam.length/Double(beam.elements)),e=try StructuralArithmetic.finite(9/(3/beam.elasticity.shearModulus+1/beam.elasticity.bulkModulus))
        guard h>0,e>0 else { throw .nonFiniteResult }
        let axial=try StructuralArithmetic.finite(pencil.binding.operatingCoordinates[0]/(e*beam.area))
        for cell in 0..<beam.elements {
            try StructuralArithmetic.check(policy);try StructuralArithmetic.charge(try StructuralArithmetic.sum(30,try StructuralArithmetic.size(4,pencil.count)),&work)
            var displacement=0.0,slope=0.0
            for local in 0..<4 {
                let original=2*cell+local
                if let index=pencil.binding.retainedCoordinates.firstIndex(of:original) {
                    if original%2==0 { displacement=try StructuralArithmetic.finite(displacement+coordinates[index].amplitude) }
                    else { slope=try StructuralArithmetic.finite(slope+coordinates[index].amplitude) }
                }
            }
            let slopeBound=try StructuralArithmetic.finite(1.5*displacement/h+slope)
            let curvatureBound=try StructuralArithmetic.finite((6*displacement/h+4*slope)/h)
            let strainBound=try StructuralArithmetic.finite(axial+beam.maximumFiberDistance*curvatureBound)
            guard slopeBound<=beam.maximumSlope,strainBound<=beam.maximumLinearStrain else { throw .outsideDomain }
        }
    }
}
