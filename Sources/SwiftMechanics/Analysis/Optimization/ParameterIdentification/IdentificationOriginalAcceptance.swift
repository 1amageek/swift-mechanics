internal enum IdentificationOriginalAcceptance {
    @inline(never)
    static func evaluate(_ p:PhysicalIdentificationProblem,result:OptimizationResult,design:[Double],offset:[Double],
        equations:any RigidEquationComputing,derivatives:any MechanicalDifferentiating,loads:any ScalarLoadEvaluating,
        policy:IdentificationPolicy,physicalResiduals:inout [Double],loadWork:inout LoadWork,supplierWork:inout DerivativeSupplierWork,
        context c:inout IdentificationContext,work:inout NumericalWork) throws(IdentificationCause) -> ([Double],Double,OptimizationCertificate,[Bool],[Bool],[Double],Double) {
        guard result.status == .optimal,let certificate=result.optimum,let physical=result.physicalPoint,let objective=result.physicalObjective,
              certificate.point.count == 2,physical.count == 2,certificate.lowerMultipliers.count == 2,certificate.upperMultipliers.count == 2,
              certificate.equalityMultipliers.isEmpty,certificate.inequalityMultipliers.isEmpty,
              result.metadata.variableIDs.count == 2,result.metadata.variableReferences.count == 2 else { throw .invalidSupplierOutput }
        try IdentificationArithmetic.key(result.metadata.identity,policy,&c,&work)
        try IdentificationArithmetic.key(result.metadata.provenance.source,policy,&c,&work)
        try IdentificationArithmetic.key(p.metadata.provenance.source,policy,&c,&work)
        guard result.metadata.identity == p.metadata.identity,result.metadata.provenance == p.metadata.provenance,
              result.metadata.variableIDs == p.metadata.variableIDs,result.metadata.equalityReferences.isEmpty,result.metadata.inequalityReferences.isEmpty,
              result.metadata.objectiveReference.dimension == .dimensionless,result.metadata.objectiveReference.magnitude == 1 else { throw .invalidSupplierOutput }
        for i in 0..<2 {
            try IdentificationArithmetic.charge(12,policy,&work)
            guard result.metadata.variableReferences[i].dimension == p.metadata.variableReferences[i].dimension,
                  result.metadata.variableReferences[i].magnitude == p.metadata.variableReferences[i].magnitude,
                  certificate.point[i].isFinite,physical[i].isFinite,certificate.lowerMultipliers[i].isFinite,certificate.upperMultipliers[i].isFinite,
                  try IdentificationArithmetic.agrees(physical[i],certificate.point[i]*p.metadata.variableReferences[i].magnitude,policy.normalizedAgreement) else { throw .invalidSupplierOutput }
        }
        guard objective.isFinite,certificate.objective.isFinite,physical[0] > 0,physical[1] >= 0 else { throw .invalidSupplierOutput }
        var mechanics=MechanicalDerivativeWorkspace(),value=0.0,gradient=[0.0,0.0]
        for i in p.observations.indices {
            let observation=p.observations[i],sigma=observation.forceStandardDeviationNewtons
            let sample=try MechanicalIdentificationSampling.sample(observation,source:p.source,mass:physical[0],damping:physical[1],equations:equations,derivatives:derivatives,loads:loads,
                policy:policy,workspace:&mechanics,loadWork:&loadWork,supplierWork:&supplierWork,context:&c,work:&work)
            try IdentificationArithmetic.charge(20,policy,&work)
            physicalResiduals[i]=sample.0
            c.residual=max(c.residual ?? 0,abs(sample.0))
            let normalized=try IdentificationArithmetic.finite(sample.0/sigma)
            let predicted=try IdentificationArithmetic.finite(design[2*i]*certificate.point[0]+design[2*i+1]*certificate.point[1]+offset[i])
            guard try IdentificationArithmetic.agrees(sample.0,predicted*sigma,policy.physicalAgreement) else { throw .originalEvidenceRejected }
            let a=try IdentificationArithmetic.finite(sample.1*p.metadata.variableReferences[0].magnitude/sigma)
            let b=try IdentificationArithmetic.finite(sample.2*p.metadata.variableReferences[1].magnitude/sigma)
            guard try IdentificationArithmetic.agrees(a,design[2*i],policy.normalizedAgreement),
                  try IdentificationArithmetic.agrees(b,design[2*i+1],policy.normalizedAgreement) else { throw .originalEvidenceRejected }
            value=try IdentificationArithmetic.finite(value+0.5*normalized*normalized)
            gradient[0]=try IdentificationArithmetic.finite(gradient[0]+a*normalized)
            gradient[1]=try IdentificationArithmetic.finite(gradient[1]+b*normalized)
        }
        c.objective=value
        guard try IdentificationArithmetic.agrees(value,objective,policy.normalizedAgreement),
              try IdentificationArithmetic.agrees(value,certificate.objective,policy.normalizedAgreement) else { throw .originalEvidenceRejected }
        var stationarity=0.0,lowerActive=[false,false],upperActive=[false,false]
        for i in 0..<2 {
            try IdentificationArithmetic.charge(20,policy,&work)
            let scale=p.metadata.variableReferences[i].magnitude,x=certificate.point[i]
            let lower=p.lowerBounds[i]/scale,upper=p.upperBounds[i]/scale,lm=certificate.lowerMultipliers[i],um=certificate.upperMultipliers[i]
            let feasibility=max(0,max(lower-x,x-upper)),dual=max(0,max(-lm,-um))
            let balance=try IdentificationArithmetic.finite(gradient[i]-lm+um)
            let complementarity=try IdentificationArithmetic.finite(max(abs(lm*(x-lower)),abs(um*(upper-x))))
            guard try IdentificationArithmetic.core({ () throws(CoreError) in try policy.normalizedAgreement.contains(error:feasibility,scale:max(abs(x),max(abs(lower),abs(upper)))) }),
                  try IdentificationArithmetic.core({ () throws(CoreError) in try policy.normalizedAgreement.contains(error:dual,scale:max(abs(lm),abs(um))) }),
                  try IdentificationArithmetic.core({ () throws(CoreError) in try policy.normalizedAgreement.contains(error:balance,scale:max(abs(gradient[i]),max(abs(lm),abs(um)))) }),
                  try IdentificationArithmetic.agrees(complementarity,0,policy.normalizedAgreement) else { throw .originalEvidenceRejected }
            stationarity=max(stationarity,abs(balance))
            lowerActive[i]=try IdentificationArithmetic.agrees(x,lower,policy.normalizedAgreement)
            upperActive[i]=try IdentificationArithmetic.agrees(x,upper,policy.normalizedAgreement)
        }
        try IdentificationArithmetic.check(policy)
        return (physical,value,certificate,lowerActive,upperActive,gradient,stationarity)
    }
}
