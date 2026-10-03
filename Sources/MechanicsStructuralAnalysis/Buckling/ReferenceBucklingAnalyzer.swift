import CMechanicsMath
import MechanicsCore
import MechanicsModel
import MechanicsFlexible
import MechanicsNumerics
public struct ReferenceBucklingAnalyzer: BucklingAnalyzing, Sendable {
    public let modes: any ModalAnalyzing
    public init(modes: any ModalAnalyzing = ReferenceModalAnalyzer()) { self.modes=modes }
    public func beam(_ assembly: BeamAssembly,fixedCoordinates: [Int],expectedRevision: UInt64,policy: StructuralPolicy,
                     work: inout NumericalWork) throws(StructuralError) -> BeamBucklingResult {
        let builder=ReferenceStructuralModelBuilder()
        let base=try builder.beam(assembly,fixedCoordinates:fixedCoordinates,compressiveLoad:0,expectedRevision:expectedRevision,policy:policy,work:&work)
        let retained=base.binding.retainedCoordinates,n=base.count,nn=try StructuralArithmetic.size(n,n)
        try StructuralArithmetic.reserve(try StructuralArithmetic.size(24,try StructuralArithmetic.size(assembly.coordinateCount,assembly.coordinateCount)),&work)
        var geometric=[Double](repeating:0,count:nn)
        for i in 0..<n { try StructuralArithmetic.check(policy);try StructuralArithmetic.charge(n,&work)
            for j in 0..<n { geometric[i*n+j]=assembly.geometricStiffness[retained[i]*assembly.coordinateCount+retained[j]] }
        }
        // Physical load pencil uses G as the metric. Returned eigenvalues are N, not modal s^-2.
        // Unit time scale one is an explicit algebraic adapter; no dynamic mass is inferred from G.
        let loadPolicy=try StructuralPolicy(maximumCoordinates:policy.maximumCoordinates,maximumMetadataBytes:policy.maximumMetadataBytes,
            energyScale:policy.energyScale,timeScale:1,spectralTolerance:policy.spectralTolerance,positiveMassThreshold:policy.positiveMassThreshold,
            originalResidualTolerance:policy.originalResidualTolerance,zeroEigenvalueThreshold:0,isCancelled:policy.isCancelled)
        let pencil=StructuralPencil(binding:base.binding,mass:geometric,stiffness:base.stiffness,damping:base.damping)
        let result=try modes.modes(pencil,expectedBinding:base.binding,policy:loadPolicy,work:&work)
        guard result.binding==base.binding,result.eigenvalues.count==n,result.modes.count==nn else { throw .staleBinding }
        guard result.eigenvalues.allSatisfy({ $0.isFinite && $0>0 }) else { throw .outsideDomain }
        let ea=try StructuralArithmetic.finite(assembly.youngModulus*assembly.beam.area)
        guard result.eigenvalues[0]/ea<=assembly.beam.maximumLinearStrain else { throw .outsideDomain }
        var mode=[Double](repeating:0,count:n),residual=0.0
        for i in 0..<n { mode[i]=result.modes[i*n] }
        for i in 0..<n { try StructuralArithmetic.check(policy);var left=0.0,right=0.0
            for j in 0..<n { try StructuralArithmetic.charge(5,&work);left=try StructuralArithmetic.finite(left+base.stiffness[i*n+j]*mode[j]);right=try StructuralArithmetic.finite(right+result.eigenvalues[0]*geometric[i*n+j]*mode[j]) }
            let factor=base.binding.coordinateScales[i]/policy.energyScale.squareRoot()
            residual=max(residual,try StructuralArithmetic.finite(abs((left-right)*factor)/max(1,max(abs(left*factor),abs(right*factor)))))
        }
        guard residual<=policy.originalResidualTolerance else { throw .residualRejected(value:residual,threshold:policy.originalResidualTolerance) }
        try StructuralArithmetic.check(policy)
        return BeamBucklingResult(assembly:assembly,retainedCoordinates:retained,criticalLoad:result.eigenvalues[0],mode:mode,maximumOriginalResidual:residual,work:work)
    }
    public func truss(_ model: NonlinearTruss,height: Double,expectedRevision: UInt64,policy: StructuralPolicy,
                      work: inout NumericalWork) throws(StructuralError) -> TrussPoint {
        try StructuralArithmetic.check(policy);try StructuralArithmetic.metadata(model.identity,model.frame.key,policy:policy)
        guard try StructuralArithmetic.sum(try StructuralArithmetic.sum(model.identity.utf8.count,model.frame.key.utf8.count),model.source.source.utf8.count) <= policy.maximumMetadataBytes else { throw .capacityExceeded }
        guard model.revision==expectedRevision else { throw .staleBinding }
        guard height.isFinite,height>=0 else { throw .outsideDomain }
        try StructuralArithmetic.reserve(64,&work);try StructuralArithmetic.charge(48,&work)
        let a=model.halfSpan,l0=sm_hypot(a,model.initialHeight),l=sm_hypot(a,height)
        guard l0.isFinite,l.isFinite,l>0,l0>0 else { throw .nonFiniteResult }
        let strain=try StructuralArithmetic.finite((l-l0)/l0)
        guard abs(strain)<=model.maximumAbsoluteEngineeringStrain else { throw .outsideDomain }
        let coefficient=try StructuralArithmetic.finite(2*model.axialRigidity/l0)
        let force=try StructuralArithmetic.finite(coefficient*(l-l0)*height/l),load = -force
        let energy=try StructuralArithmetic.finite(model.axialRigidity/l0*(l-l0)*(l-l0))
        let tangent=try StructuralArithmetic.finite(coefficient*(1-(l0/l)*(a/l)*(a/l)))
        // Independent bar-force resolution checks the original apex balance, rather than a solver flag.
        let axial=try StructuralArithmetic.finite(model.axialRigidity*strain)
        let residual=try StructuralArithmetic.finite(abs(2*axial*height/l+load)/max(1,abs(load)))
        guard residual<=policy.originalResidualTolerance else { throw .residualRejected(value:residual,threshold:policy.originalResidualTolerance) }
        let normalized=tangent/coefficient
        let classification:TangentClassification=normalized>policy.spectralTolerance ? .positive : (normalized < -policy.spectralTolerance ? .negative : .neutral)
        try StructuralArithmetic.check(policy)
        return TrussPoint(height:height,downwardLoad:load,energy:energy,verticalTangent:tangent,engineeringStrain:strain,classification:classification,originalForceResidual:residual)
    }
    public func continueTruss(_ model: NonlinearTruss,heights: [Double],descending: Bool,expectedRevision: UInt64,
                              policy: StructuralPolicy,work: inout NumericalWork) throws(StructuralError) -> TrussContinuation {
        try StructuralArithmetic.check(policy)
        guard !heights.isEmpty,heights.count<=policy.maximumCoordinates else { throw .capacityExceeded }
        try StructuralArithmetic.reserve(try StructuralArithmetic.sum(80,try StructuralArithmetic.size(12,heights.count)),&work)
        var points:[TrussPoint]=[];points.reserveCapacity(heights.count)
        for i in heights.indices {
            try StructuralArithmetic.check(policy);try StructuralArithmetic.charge(1,&work)
            if i>0 { guard descending ? heights[i]<heights[i-1] : heights[i]>heights[i-1] else { throw .invalidInput } }
            points.append(try truss(model,height:heights[i],expectedRevision:expectedRevision,policy:policy,work:&work))
        }
        try StructuralArithmetic.check(policy);return TrussContinuation(model:model,points:points,descending:descending)
    }
    public func criticalTruss(_ model: NonlinearTruss,lowerHeight: Double,upperHeight: Double,positionTolerance: Double,
                              expectedRevision: UInt64,policy: StructuralPolicy,work: inout NumericalWork) throws(StructuralError) -> TrussCriticalPoint {
        guard positionTolerance.isFinite,positionTolerance>0,lowerHeight.isFinite,upperHeight.isFinite,lowerHeight<upperHeight else { throw .invalidInput }
        try StructuralArithmetic.reserve(96,&work)
        let low=try truss(model,height:lowerHeight,expectedRevision:expectedRevision,policy:policy,work:&work)
        let high=try truss(model,height:upperHeight,expectedRevision:expectedRevision,policy:policy,work:&work)
        guard low.verticalTangent<=0,high.verticalTangent>=0 else { throw .noCriticalBracket }
        let l0=sm_hypot(model.halfSpan,model.initialHeight),coefficient=try StructuralArithmetic.finite(2*model.axialRigidity/l0)
        var lower=lowerHeight,upper=upperHeight,point=low,error=abs(low.verticalTangent/coefficient)
        while true {
            try StructuralArithmetic.check(policy)
            do { try work.advanceIteration() } catch {
                if case .resourceLimit(resource:.iterations,limit:_) = error { throw .nonConvergence(iterations:work.iterations,residual:abs(point.verticalTangent/coefficient)) }
                throw .numerical(error,failedSupplierWorkUnavailable:false)
            }
            let mid=try StructuralArithmetic.finite(lower+(upper-lower)/2)
            guard mid>lower,mid<upper else { throw .nonConvergence(iterations:work.iterations,residual:error) }
            point=try truss(model,height:mid,expectedRevision:expectedRevision,policy:policy,work:&work);error=abs(point.verticalTangent/coefficient)
            if point.verticalTangent<0 { lower=mid } else { upper=mid }
            if upper-lower<=positionTolerance,error<=policy.originalResidualTolerance { break }
        }
        // Bound |dP/dy| over the admitted positive-height branch using l>=a.
        let bound=try StructuralArithmetic.finite(coefficient*(1+l0/model.halfSpan)*(upper-lower))
        try StructuralArithmetic.check(policy)
        return TrussCriticalPoint(model:model,point:point,lowerHeight:lower,upperHeight:upper,loadUncertaintyBound:bound,normalizedTangentResidual:error,work:work)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Nonlinear beam continuation is not implemented. Public requests fail until a physical nonlinear beam element/material tangent and independently validated postbuckling continuation exist.
    public func nonlinearBeam(_ assembly: BeamAssembly,policy: StructuralPolicy,work: inout NumericalWork) throws(StructuralError) -> BeamBucklingResult {
        try StructuralArithmetic.check(policy);throw .unsupportedDomain
    }
}
