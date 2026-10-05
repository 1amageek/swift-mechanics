internal struct SpatialWorkKernel {
    @inline(never) static func verify(old:SpatialState,new:SpatialState,predictor:SpatialPredictor,projection:SpatialProjectionEvidence,
                                     source:SpatialSource,dt:Double,policy:SpatialPolicy,work:inout NumericalWork) throws(SpatialFluidError)->SpatialStepEvidence {
        let g=old.grid,m=g.cellMass
        var maximum=0.0,momentum=[Double](repeating:0,count:3),forceScale=[Double](repeating:0,count:3)
        for k in 0..<g.count {
            try policy.poll();try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(140) }
            for axis in 0..<3 {
                let acceleration=(new.component(axis)[k]-old.component(axis)[k])/dt
                let gradient=SpatialGeometry.gradient(new.pressure,grid:g,at:k,axis:axis)/g.density
                let force=try spatialFinite(m*(acceleration-predictor.rate[axis][k]+gradient))
                try spatialResidual(force,scale:m*(abs(acceleration)+abs(predictor.rate[axis][k])+abs(gradient)),absolute:policy.forceAbsolute,relative:policy.forceRelative)
                maximum=max(maximum,abs(force))
                momentum[axis]=try spatialFinite(momentum[axis]+m*(acceleration-source.component(axis)))
                forceScale[axis]=try spatialFinite(forceScale[axis]+m*(abs(acceleration)+abs(source.component(axis))))
            }
        }
        for axis in 0..<3 { try spatialResidual(momentum[axis],scale:forceScale[axis],absolute:policy.forceAbsolute,relative:policy.forceRelative) }
        try spatialNumerics { () throws(NumericalError) in try work.chargeOperations(40) }
        let expected=try spatialFinite(dt*(predictor.sourcePower-predictor.viscousPower-predictor.donorPower+predictor.divergencePower)+predictor.injection-projection.projectionLoss+projection.pressureResidualWork)
        let change=try spatialFinite(projection.kineticAfter-predictor.kinetic),defect=try spatialFinite(change-expected)
        try spatialResidual(defect,scale:max(abs(change),abs(expected)),absolute:policy.energyAbsolute,relative:policy.energyRelative)
        if source.accelerationX == 0,source.accelerationY == 0,source.accelerationZ == 0 {
            let allowance=try spatialFinite(policy.energyAbsolute+policy.energyRelative*predictor.kinetic+dt*abs(predictor.divergencePower)+abs(projection.pressureResidualWork))
            guard change <= allowance else { throw .stability }
        }
        try policy.poll()
        return SpatialStepEvidence(maximumCourantFactor:predictor.courantFactor,maximumAdvectiveFactor:predictor.advectiveFactor,
            viscousFactor:predictor.viscousFactor,maximumMomentumResidual:maximum,meanMomentumResidualX:momentum[0],meanMomentumResidualY:momentum[1],meanMomentumResidualZ:momentum[2],
            kineticBefore:predictor.kinetic,viscousLossPower:predictor.viscousPower,donorLossPower:predictor.donorPower,
            divergenceTransportPower:predictor.divergencePower,sourcePower:predictor.sourcePower,explicitTimeInjection:predictor.injection,energyDefect:defect)
    }
}
