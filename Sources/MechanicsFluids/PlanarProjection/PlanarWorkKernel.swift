import MechanicsNumerics
internal struct PlanarWorkKernel {
    @inline(never) static func verify(old:PlanarState,new:PlanarState,predictor:PlanarPredictor,projection:PlanarProjectionEvidence,
                                     source:PlanarSource,dt:Double,policy:PlanarPolicy,work:inout NumericalWork) throws(PlanarFluidError)->PlanarStepEvidence {
        let g=old.grid,m=g.cellMass
        var maximum=0.0,meanU=0.0,meanV=0.0,forceScaleU=0.0,forceScaleV=0.0
        for k in 0..<g.count {
            try policy.poll();try planarNumerics { () throws(NumericalError) in try work.chargeOperations(64) }
            let au=(new.u[k]-old.u[k])/dt,av=(new.v[k]-old.v[k])/dt
            let gu=PlanarGeometry.gradientX(new.pressure,grid:g,at:k)/g.density,gv=PlanarGeometry.gradientY(new.pressure,grid:g,at:k)/g.density
            let fu=try planarFinite(m*(au-predictor.rateU[k]+gu)),fv=try planarFinite(m*(av-predictor.rateV[k]+gv))
            try planarResidual(fu,scale:m*(abs(au)+abs(predictor.rateU[k])+abs(gu)),absolute:policy.forceAbsolute,relative:policy.forceRelative)
            try planarResidual(fv,scale:m*(abs(av)+abs(predictor.rateV[k])+abs(gv)),absolute:policy.forceAbsolute,relative:policy.forceRelative)
            maximum=max(maximum,max(abs(fu),abs(fv)))
            meanU=try planarFinite(meanU+m*(au-source.accelerationX));meanV=try planarFinite(meanV+m*(av-source.accelerationY))
            forceScaleU=try planarFinite(forceScaleU+m*(abs(au)+abs(source.accelerationX)))
            forceScaleV=try planarFinite(forceScaleV+m*(abs(av)+abs(source.accelerationY)))
        }
        try planarResidual(meanU,scale:forceScaleU,absolute:policy.forceAbsolute,relative:policy.forceRelative)
        try planarResidual(meanV,scale:forceScaleV,absolute:policy.forceAbsolute,relative:policy.forceRelative)
        let expected=try planarFinite(dt*(predictor.sourcePower-predictor.viscousPower-predictor.donorPower+predictor.divergencePower)+predictor.injection-projection.projectionLoss+projection.pressureResidualWork)
        let change=try planarFinite(projection.kineticAfter-predictor.kinetic),defect=try planarFinite(change-expected)
        try planarResidual(defect,scale:max(abs(change),abs(expected)),absolute:policy.energyAbsolute,relative:policy.energyRelative)
        if source.accelerationX == 0,source.accelerationY == 0 {
            let allowance=try planarFinite(policy.energyAbsolute+policy.energyRelative*predictor.kinetic+dt*abs(predictor.divergencePower)+abs(projection.pressureResidualWork))
            guard change <= allowance else { throw .stability }
        }
        try policy.poll()
        return PlanarStepEvidence(maximumCourantFactor:predictor.courantFactor,maximumAdvectiveFactor:predictor.advectiveFactor,
            viscousFactor:predictor.viscousFactor,maximumMomentumResidual:maximum,meanMomentumResidualX:meanU,meanMomentumResidualY:meanV,
            kineticBefore:predictor.kinetic,viscousLossPower:predictor.viscousPower,donorLossPower:predictor.donorPower,
            divergenceTransportPower:predictor.divergencePower,sourcePower:predictor.sourcePower,explicitTimeInjection:predictor.injection,energyDefect:defect)
    }
}
