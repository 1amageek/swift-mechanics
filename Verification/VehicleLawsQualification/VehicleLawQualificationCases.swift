import Foundation
import SwiftMechanics

public enum VehicleLawQualificationCases {
    private static func require(_ condition: Bool, _ message: String) throws(VehicleLawQualificationError) {
        guard condition else { throw .assertion(message) }
    }
    private static func close(_ actual: Double, _ expected: Double, _ message: String, tolerance: Double = 1e-9) throws(VehicleLawQualificationError) {
        try require(actual.isFinite && expected.isFinite && abs(actual-expected) <= tolerance*max(1,abs(expected)),message)
    }
    private static func close(_ actual: Vector3, _ expected: Vector3, _ message: String, tolerance: Double = 1e-9) throws(VehicleLawQualificationError) {
        try close(actual.x,expected.x,message+" x",tolerance:tolerance)
        try close(actual.y,expected.y,message+" y",tolerance:tolerance)
        try close(actual.z,expected.z,message+" z",tolerance:tolerance)
    }
    private static func expectTire(_ expected: TireLawError, _ message: String, _ operation: () throws(TireLawError) -> Void) throws(VehicleLawQualificationError) {
        do throws(TireLawError) { try operation() }
        catch {
            guard error == expected else { throw .unexpectedTireFailure(expected:message,actual:error) }
            return
        }
        throw .unexpectedSuccess(message)
    }
    private static func expectTerrain(_ expected: TerrainLawError, _ message: String, _ operation: () throws(TerrainLawError) -> Void) throws(VehicleLawQualificationError) {
        do throws(TerrainLawError) { try operation() }
        catch {
            guard error == expected else { throw .unexpectedTerrainFailure(expected:message,actual:error) }
            return
        }
        throw .unexpectedSuccess(message)
    }

    public static func tireCurvesAndCombinedBound() throws {
        let law:any TireRoadEvaluating=RadialBrushTireLaw()
        let calibration=try VehicleLawQualificationFixtures.tireCalibration(), policy=try VehicleLawQualificationFixtures.tirePolicy()
        let frame=try VehicleLawQualificationFixtures.tireFrame()
        var work=try VehicleLawQualificationFixtures.work()
        for (kappa,expected,saturated) in [(0.0,0.0,false),(0.1,244.0,false),(0.5,500.0,true),(1.0,500.0,true),(-0.1,-244.0,false)] {
            let response=try law.evaluate(sample:VehicleLawQualificationFixtures.tireSample(spin:20*(1+kappa)),frame:frame,
                calibration:calibration,policy:policy,work:&work)
            try close(response.slip.longitudinalRatio,kappa,"original longitudinal slip")
            try close(response.longitudinalForce,expected,"independent literal pure longitudinal anchor")
            try close(response.lateralForce,0,"pure longitudinal lateral force")
            try require(response.isForceSaturated == saturated,"saturation branch must agree with physical capacity")
            try close(response.rollingMoment,-10,"calibrated rolling couple")
            try require(response.power.slipDissipationPower >= 0 && response.power.rollingDissipationPower >= 0,"physical nonnegative losses")
        }
        let lateral=try law.evaluate(sample:VehicleLawQualificationFixtures.tireSample(vy:1),frame:frame,calibration:calibration,policy:policy,work:&work)
        try close(lateral.lateralForce,-244,"independent literal lateral anchor")
        try close(lateral.longitudinalForce,0,"pure lateral longitudinal force")
        let small=try law.evaluate(sample:VehicleLawQualificationFixtures.tireSample(spin:20.00002),frame:frame,calibration:calibration,policy:policy,work:&work)
        try require(abs(small.longitudinalForce/small.slip.longitudinalRatio-3000) < 0.01,"independent initial longitudinal stiffness")
        let reverse=try law.evaluate(sample:VehicleLawQualificationFixtures.tireSample(vx:-10,spin:-18),frame:frame,calibration:calibration,policy:policy,work:&work)
        try close(reverse.slip.longitudinalRatio,0.1,"reverse travel uses absolute longitudinal denominator")
        try close(reverse.longitudinalForce,244,"reverse braking force opposes actual slip")
        try close(reverse.rollingMoment,10,"rolling couple changes sign with spin")
        for (kappa,tangent) in [(0.1,0.1),(0.2,-0.15),(1.0,0.5)] {
            let sample=try VehicleLawQualificationFixtures.tireSample(vy:10*tangent,spin:20*(1+kappa))
            let response=try law.evaluate(sample:sample,frame:frame,calibration:calibration,policy:policy,work:&work)
            let qx=3000*kappa, qy = -3000*tangent, demand=(qx*qx+qy*qy).squareRoot(), capacity=500.0
            let remaining=max(0,1-demand/(3*capacity))
            let magnitude=capacity*(1-remaining*remaining*remaining)
            try close(response.longitudinalForce,qx/demand*magnitude,"independent combined radial direction/magnitude")
            try close(response.lateralForce,qy/demand*magnitude,"independent combined lateral direction/magnitude")
            let actual=(response.longitudinalForce*response.longitudinalForce+response.lateralForce*response.lateralForce).squareRoot()
            try require(actual <= 500+1e-9,"combined tangential force must remain within original friction capacity")
        }
        try require(work.consumed > 0 && work.peakScalars >= 192,"actual tire work and storage must be charged")
    }

    public static func tireFramesMovingRoadAndWork() throws {
        let law:any TireRoadEvaluating=RadialBrushTireLaw()
        let calibration=try VehicleLawQualificationFixtures.tireCalibration(), policy=try VehicleLawQualificationFixtures.tirePolicy()
        let rotation=try UnitQuaternion(axis:Vector3(1,2,3),angle:0.6), origin=try Vector3(4,-3,2), roadVelocity=try Vector3(2,-1,0.3)
        let frame=try VehicleLawQualificationFixtures.tireFrame(rotation:rotation,origin:origin)
        let sample=try VehicleLawQualificationFixtures.tireSample(vy:1,spin:22,roadVelocity:roadVelocity,rotation:rotation,origin:origin)
        var work=try VehicleLawQualificationFixtures.work()
        let response=try law.evaluate(sample:sample,frame:frame,calibration:calibration,policy:policy,work:&work)
        let demand=300.0*Double(2).squareRoot(), remainder=1-demand/1500
        let component=500*(1-remainder*remainder*remainder)/Double(2).squareRoot()
        let localForce=try Vector3(component,-component,0), localCenterTorque=try Vector3(-component/2,-component/2-10,0)
        let force=try rotation.rotating(localForce), centerTorque=try rotation.rotating(localCenterTorque), rolling=try rotation.rotating(Vector3(0,-10,0))
        try close(response.wheelCenterWrench.force,force,"rigid frame covariance of physical force")
        try close(response.wheelCenterWrench.torque,centerTorque,"actual contact lever arm and rolling center couple")
        try close(response.roadContactWrench.force,force.scaled(by:-1),"action/reaction force")
        try close(response.roadContactWrench.torque,rolling.scaled(by:-1),"road opposite rolling couple")
        try close(response.tangentialPointLoad.point,origin,"contact point lies on supplied translated plane")
        let angular=try rotation.rotating(Vector3(0,22,0))
        let directWheel=try centerTorque.dot(angular)+force.dot(sample.centerVelocity)
        let directRoad=try -force.dot(roadVelocity)
        let directSlipLoss=2*component, directRollingLoss=220.0
        try close(response.power.wheelMechanicalPower,directWheel,"independent wheel center original mechanical power")
        try close(response.power.roadMechanicalPower,directRoad,"independent moving-road power")
        try close(response.power.slipDissipationPower,directSlipLoss,"independent force times actual two-axis surface slip")
        try close(response.power.rollingDissipationPower,directRollingLoss,"independent rolling dissipation")
        try close(directWheel+directRoad+directSlipLoss+directRollingLoss,0,"independent original physical pair-power balance")
        try require(directWheel+directRoad <= 0,"physical interface is passive despite individually moving road/wheel powers")
        let roadMomentAtCenter=try response.roadContactWrench.torque.adding(origin.subtracting(sample.centerPosition).cross(response.roadContactWrench.force))
        try close(response.wheelCenterWrench.torque.adding(roadMomentAtCenter),.zero,"equal/opposite wrench at one original reference")
        let stationary=try law.evaluate(sample:VehicleLawQualificationFixtures.tireSample(vy:1,spin:22),
            frame:VehicleLawQualificationFixtures.tireFrame(),calibration:calibration,policy:policy,work:&work)
        try close(response.power.slipDissipationPower,stationary.power.slipDissipationPower,"rigid transform/translation does not change slip loss")
        try close(response.power.rollingDissipationPower,stationary.power.rollingDissipationPower,"rigid transform does not change rolling loss")
    }

    public static func tireRefusalsAndBudgets() throws {
        let law:any TireRoadEvaluating=RadialBrushTireLaw()
        let calibration=try VehicleLawQualificationFixtures.tireCalibration(), policy=try VehicleLawQualificationFixtures.tirePolicy()
        let frame=try VehicleLawQualificationFixtures.tireFrame()
        var work=try VehicleLawQualificationFixtures.work()
        let slow=try VehicleLawQualificationFixtures.tireSample(vx:0,spin:0)
        try expectTire(.lowSpeedDomain,"no invented low-speed success") { () throws(TireLawError) in
            _=try law.evaluate(sample:slow,frame:frame,calibration:calibration,policy:policy,work:&work)
        }
        let stale=try VehicleLawQualificationFixtures.tireSample(revision:8)
        try expectTire(.calibrationMismatch,"exact calibration revision") { () throws(TireLawError) in
            _=try law.evaluate(sample:stale,frame:frame,calibration:calibration,policy:policy,work:&work)
        }
        let wrongFrame=try VehicleLawQualificationFixtures.tireSample(frame:VehicleLawQualificationFixtures.reference(.frame,"other-frame"))
        try expectTire(.frameMismatch,"exact frame provenance") { () throws(TireLawError) in
            _=try law.evaluate(sample:wrongFrame,frame:frame,calibration:calibration,policy:policy,work:&work)
        }
        let wrongContact=try VehicleLawQualificationFixtures.tireSample(height:0.6)
        try expectTire(.contactGeometryMismatch,"original radius/plane separation") { () throws(TireLawError) in
            _=try law.evaluate(sample:wrongContact,frame:frame,calibration:calibration,policy:policy,work:&work)
        }
        let loadOutside=try VehicleLawQualificationFixtures.tireSample(normalLoad:2001)
        let slipOutside=try VehicleLawQualificationFixtures.tireSample(spin:70)
        for sample in [loadOutside,slipOutside] {
            try expectTire(.outsideCalibratedDomain,"calibrated load/slip domain") { () throws(TireLawError) in
                _=try law.evaluate(sample:sample,frame:frame,calibration:calibration,policy:policy,work:&work)
            }
        }
        try expectTire(.invalidCalibration,"an unfit formulation cannot be renamed") { () throws(TireLawError) in
            _=try TireBrushCalibration(source:"synthetic-invalid",revision:7,tire:calibration.tire,roadSurface:calibration.roadSurface,
                longitudinalStiffness:3000,lateralStiffness:3000,frictionCoefficient:0.5,rollingResistanceLength:0.01,
                domain:calibration.domain,fittedFormulation:"unfitted-formulation")
        }
        let valid=try VehicleLawQualificationFixtures.tireSample(spin:22)
        var exhausted=try VehicleLawQualificationFixtures.work(limit:3)
        try expectTire(.load(.workExhausted),"actual nonzero exhausted-work prefix") { () throws(TireLawError) in
            _=try law.evaluate(sample:valid,frame:frame,calibration:calibration,policy:policy,work:&exhausted)
        }
        try require(exhausted.consumed == 3,"failed tire evaluation must retain actual three charged metadata units")
        var small=try VehicleLawQualificationFixtures.work(scalars:191)
        try expectTire(.load(.capacityExceeded),"actual scalar admission") { () throws(TireLawError) in
            _=try law.evaluate(sample:valid,frame:frame,calibration:calibration,policy:policy,work:&small)
        }
        var cancelled=try VehicleLawQualificationFixtures.work(cancelled:{ true })
        try expectTire(.load(.cancelled),"original caller cancellation") { () throws(TireLawError) in
            _=try law.evaluate(sample:valid,frame:frame,calibration:calibration,policy:policy,work:&cancelled)
        }
    }

    public static func terrainClippingCompactionAndReload() throws {
        let law:any TerrainLawEvaluating=BekkerJanosiTerrainLaw(), policy=try VehicleLawQualificationFixtures.terrainPolicy()
        var work=try VehicleLawQualificationFixtures.work()
        let initial=try VehicleLawQualificationFixtures.history(service:law,work:&work)
        try require(initial.cells.count == 4 && initial.sequence == 0,"actual virgin four-subarea issuance")
        let xs=[0.625,1.375,0.625,1.375], ys=[0.75,0.75,1.25,1.25]
        for i in 0..<4 {
            try require(initial.cells[i].cellIndex == i,"row-major clipped cell identity")
            try close(initial.cells[i].area,0.375,"exact rectangle-cell overlap")
            try close(initial.cells[i].centroidX,xs[i],"exact clipped centroid x")
            try close(initial.cells[i].centroidY,ys[i],"exact clipped centroid y")
        }
        let trial=try law.evaluate(step:VehicleLawQualificationFixtures.step(initial,localVelocity:Vector3(0,0,-0.1)),accepted:initial,policy:policy,work:&work)
        try require(initial.sequence == 0 && initial.cells.allSatisfy({ $0.peakSinkage == 0 }),"trial must not publish history")
        try close(trial.response.meanNormalLoad,150,"independent integrated virgin normal load")
        try close(trial.response.interfaceWork,-15,"independent normal force-displacement work")
        try close(trial.response.recoverableEnergyChange,3,"independent unloading elastic energy")
        try close(trial.response.compactionLoss,12,"independent irrecoverable envelope minus elastic work")
        try close(trial.response.interfaceWrench.torque,Vector3(150,-150,0),"independent off-origin rectangle normal moment")
        let loaded=try law.accept(trial:trial,replacing:initial,work:&work)
        try require(loaded.sequence == 1 && loaded.timeSeconds == 1,"actual accepted sequence/time")
        for cell in loaded.cells {
            try close(cell.currentSinkage,0.1,"actual current sinkage")
            try close(cell.peakSinkage,0.1,"actual irreversible peak")
            try close(cell.irreversibleSinkage,0.08,"independent plastic sinkage")
            try close(cell.recoverableEnergy,0.75,"independent subarea elastic energy")
            try close(cell.cumulativeCompactionLoss,3,"independent subarea compaction history")
        }
        let unloadingTrial=try law.evaluate(step:VehicleLawQualificationFixtures.step(loaded,localVelocity:Vector3(0,0,0.01)),accepted:loaded,policy:policy,work:&work)
        try close(unloadingTrial.response.meanNormalLoad,225,"independent elastic unload mean pressure")
        try close(unloadingTrial.response.interfaceWork,2.25,"recoverable work returned on unload")
        try close(unloadingTrial.response.recoverableEnergyChange,-2.25,"unload stored-energy decrease")
        try close(unloadingTrial.response.compactionLoss,0,"unloading does not undo or add compaction")
        let unloading=try law.accept(trial:unloadingTrial,replacing:loaded,work:&work)
        let separationTrial=try law.evaluate(step:VehicleLawQualificationFixtures.step(unloading,localVelocity:Vector3(0,0,0.02)),accepted:unloading,policy:policy,work:&work)
        try close(separationTrial.response.meanNormalLoad,37.5,"exact integral across elastic-to-separated branch")
        try close(separationTrial.response.interfaceWork,0.75,"remaining elastic energy returned")
        let separated=try law.accept(trial:separationTrial,replacing:unloading,work:&work)
        try require(separated.cells.allSatisfy({ $0.recoverableEnergy == 0 }),"separated soil has no tensile stored energy")
        let crossing=try law.evaluate(step:VehicleLawQualificationFixtures.step(separated,localVelocity:Vector3(0,0,-0.05)),
            accepted:separated,policy:policy,work:&work)
        try close(crossing.response.meanNormalLoad,192,"independent gap elastic and new-envelope crossing mean load")
        try close(crossing.response.interfaceWork,-9.6,"independent reload-to-new-peak pressure integral")
        try close(crossing.response.recoverableEnergyChange,4.32,"independent crossed-peak stored energy")
        try close(crossing.response.compactionLoss,5.28,"independent new-peak compaction after elastic reload")
        let reloadTrial=try law.evaluate(step:VehicleLawQualificationFixtures.step(separated,localVelocity:Vector3(0,0,-0.03)),accepted:separated,policy:policy,work:&work)
        try close(reloadTrial.response.meanNormalLoad,100,"exact elastic reload mean across separation")
        try close(reloadTrial.response.compactionLoss,0,"reloading old peak does not duplicate plastic loss")
        let reloaded=try law.accept(trial:reloadTrial,replacing:separated,work:&work)
        for cell in reloaded.cells {
            try close(cell.peakSinkage,0.1,"peak is preserved over unload/separate/reload")
            try close(cell.irreversibleSinkage,0.08,"plastic sinkage is preserved")
            try close(cell.cumulativeCompactionLoss,3,"irreversible loss never resets")
        }
        let gapped=try law.initialHistory(grid:initial.grid,calibration:initial.calibration,footprint:initial.footprint,
            interfaceBody:initial.interfaceBody,interfaceHeight:0.05,timeSeconds:0,policy:policy,work:&work)
        let gapCrossing=try law.evaluate(step:VehicleLawQualificationFixtures.step(gapped,localVelocity:Vector3(0,0,-0.15)),
            accepted:gapped,policy:policy,work:&work)
        try close(gapCrossing.response.meanNormalLoad,100,"independent initial geometric gap and virgin envelope mean load")
        try close(gapCrossing.response.interfaceWork,-15,"open gap contributes no normal work before first contact")
        try close(gapCrossing.response.recoverableEnergyChange,3,"independent gap-crossing endpoint stored energy")
        try close(gapCrossing.response.compactionLoss,12,"independent virgin compaction after initial gap")
        let initialSquare=try VehicleLawQualificationFixtures.history(service:law,work:&work,n:2)
        let square=try law.evaluate(step:VehicleLawQualificationFixtures.step(initialSquare,localVelocity:Vector3(0,0,-0.1)),accepted:initialSquare,policy:policy,work:&work)
        try close(square.response.meanNormalLoad,10,"independent quadratic Bekker pressure integral")
        try close(square.response.interfaceWork,-1,"independent quadratic envelope work")
        try close(square.response.recoverableEnergyChange,0.03,"independent quadratic elastic energy")
        try close(square.response.compactionLoss,0.97,"independent quadratic compaction")
        for cell in square.response.cells { try close(cell.endpointNormalPressure,20,"quadratic pressure endpoint") }
        try require(work.consumed > 0 && work.peakScalars >= 544,"actual terrain work and candidate storage admission")
    }

    public static func terrainJanosiTravelAndPartition() throws {
        let law:any TerrainLawEvaluating=BekkerJanosiTerrainLaw(), policy=try VehicleLawQualificationFixtures.terrainPolicy()
        var work=try VehicleLawQualificationFixtures.work()
        let initial=try VehicleLawQualificationFixtures.history(service:law,work:&work)
        let loading=try law.evaluate(step:VehicleLawQualificationFixtures.step(initial,localVelocity:Vector3(0,0,-0.1)),accepted:initial,policy:policy,work:&work)
        let loaded=try law.accept(trial:loading,replacing:initial,work:&work)
        let whole=try law.evaluate(step:VehicleLawQualificationFixtures.step(loaded,localVelocity:.unitX),accepted:loaded,policy:policy,work:&work)
        let mean=1-0.2*(1-exp(-5.0)), stress=110*mean, force=1.5*stress
        try close(whole.response.interfaceWrench.force,Vector3(-force,0,300),"independent Janosi integral and loaded pressure")
        try close(whole.response.shearLoss,force,"independent shear traction times one metre travel")
        try close(whole.response.interfaceWork,-force,"physical pure-shear work")
        let afterWhole=try law.accept(trial:whole,replacing:loaded,work:&work)
        for cell in afterWhole.cells {
            try close(cell.shearTravel,1,"actual accumulated absolute shear travel")
            try close(cell.cumulativeShearLoss,stress*0.375,"independent per-subarea history loss")
        }
        let half1=try law.evaluate(step:VehicleLawQualificationFixtures.step(loaded,localVelocity:.unitX,dt:0.5),accepted:loaded,policy:policy,work:&work)
        let mid=try law.accept(trial:half1,replacing:loaded,work:&work)
        let half2=try law.evaluate(step:VehicleLawQualificationFixtures.step(mid,localVelocity:.unitX,dt:0.5),accepted:mid,policy:policy,work:&work)
        let afterHalves=try law.accept(trial:half2,replacing:mid,work:&work)
        try close(half1.response.shearLoss+half2.response.shearLoss,force,"independent interval partition invariance of shear integral")
        for i in 0..<4 {
            try close(afterHalves.cells[i].shearTravel,afterWhole.cells[i].shearTravel,"partitioned original travel")
            try close(afterHalves.cells[i].cumulativeShearLoss,afterWhole.cells[i].cumulativeShearLoss,"partitioned irreversible loss")
        }
        let reverse=try law.evaluate(step:VehicleLawQualificationFixtures.step(afterWhole,localVelocity:Vector3(-1,0,0)),accepted:afterWhole,policy:policy,work:&work)
        let reversed=try law.accept(trial:reverse,replacing:afterWhole,work:&work)
        let reverseMean=1-0.2*(exp(-5.0)-exp(-10.0)), reverseForce=1.5*110*reverseMean
        try close(reverse.response.interfaceWrench.force.x,reverseForce,"reversed shear force opposes actual reversed velocity")
        try close(reverse.response.shearLoss,reverseForce,"independent second Janosi interval loss")
        for cell in reversed.cells { try close(cell.shearTravel,2,"slip reversal adds travel rather than undoing soil history") }
        let small=try law.evaluate(step:VehicleLawQualificationFixtures.step(loaded,localVelocity:Vector3(1e-6,0,0)),accepted:loaded,policy:policy,work:&work)
        let ratio=5e-6, meanSmall=ratio/2-ratio*ratio/6+ratio*ratio*ratio/24-ratio*ratio*ratio*ratio/120
        try close(small.response.cells[0].meanShearStress,110*meanSmall,"independent small-ratio Janosi integral",tolerance:1e-13)
        try close(small.response.shearLoss,1.5*110*meanSmall*1e-6,"independent small-travel positive loss",tolerance:1e-14)
        try require(small.response.shearLoss > 0,"small finite shear travel must not become a zero-loss fallback")
    }

    public static func terrainFramesAndInterfaceWork() throws {
        let law:any TerrainLawEvaluating=BekkerJanosiTerrainLaw(), policy=try VehicleLawQualificationFixtures.terrainPolicy()
        let rotation=try UnitQuaternion(axis:Vector3(1,2,3),angle:0.4), origin=try Vector3(2,-1,3)
        let terrainVelocity=try Vector3(2,-1,0.3), reference=try Vector3(1,-2,0.5)
        var work=try VehicleLawQualificationFixtures.work()
        let initial=try VehicleLawQualificationFixtures.history(service:law,work:&work,rotation:rotation,origin:origin)
        let loading=try law.evaluate(step:VehicleLawQualificationFixtures.step(initial,localVelocity:Vector3(0,0,-0.1)),accepted:initial,policy:policy,work:&work)
        let loaded=try law.accept(trial:loading,replacing:initial,work:&work)
        let step=try VehicleLawQualificationFixtures.step(loaded,localVelocity:Vector3(0.6,0.8,0),terrainVelocity:terrainVelocity,referencePoint:reference)
        let trial=try law.evaluate(step:step,accepted:loaded,policy:policy,work:&work)
        let stress=110*(1-0.2*(1-exp(-5.0)))
        let localCellForce=try Vector3(-0.6*stress*0.375,-0.8*stress*0.375,75)
        let cellForce=try rotation.rotating(localCellForce)
        var totalForce=Vector3.zero, totalMoment=Vector3.zero
        let xs=[0.625,1.375,0.625,1.375], ys=[0.75,0.75,1.25,1.25]
        for i in 0..<4 {
            let point=try origin.adding(rotation.rotating(Vector3(xs[i],ys[i],-0.1)))
            try close(trial.response.cells[i].point,point,"independent rotated clipped contact point")
            try close(trial.response.cells[i].forceOnInterface,cellForce,"independent rotated shear/normal cell force")
            totalForce=try totalForce.adding(cellForce)
            totalMoment=try totalMoment.adding(point.subtracting(reference).cross(cellForce))
        }
        try close(trial.response.interfaceWrench.force,totalForce,"independent original force sum")
        try close(trial.response.interfaceWrench.torque,totalMoment,"independent moment about actual supplied reference")
        try close(trial.response.terrainWrench.force,totalForce.scaled(by:-1),"actual world force reaction")
        try close(trial.response.terrainWrench.torque,totalMoment.scaled(by:-1),"actual world moment reaction at same reference")
        let direct=try (totalForce.dot(step.interfaceVelocity)-totalForce.dot(step.terrainVelocity))*step.timeStepSeconds
        try close(trial.response.interfaceWork,direct,"independent original moving-interface pair work")
        try close(direct,-1.5*stress,"rotation and Galilean translation preserve actual shear work")
        try close(direct+trial.response.recoverableEnergyChange+trial.response.compactionLoss+trial.response.shearLoss,0,"independent original physical energy identity")
        // The supplied world velocities recover a tiny negative local normal velocity;
        // rounded issued peak growth must retain its real positive plastic work.
        let localVelocity=try rotation.conjugated().rotating(step.interfaceVelocity.subtracting(step.terrainVelocity))
        let issuedSinkage=max(0,-(loaded.interfaceHeight+localVelocity.z*step.timeStepSeconds))
        var expectedCompaction=0.0, compactionUpperBound=0.0
        for cell in loaded.cells {
            let deltaPeak=max(issuedSinkage-cell.peakSinkage,0)
            expectedCompaction += cell.area*2000*deltaPeak*(cell.peakSinkage+deltaPeak/2)*(1-2000.0/10000)
            compactionUpperBound += cell.area*2000*deltaPeak*issuedSinkage
        }
        try require(localVelocity.z < 0 && expectedCompaction > 0 && trial.response.compactionLoss > 0,
            "original rotated world input advances peak and preserves positive compaction")
        try require(abs(trial.response.compactionLoss-expectedCompaction) <= 1e-9*expectedCompaction &&
                    trial.response.compactionLoss <= compactionUpperBound,
            "independent analytical tiny positive compaction and constitutive upper bound")
        try require(trial.response.shearLoss > 0,"physical irreversible shear remains positive")
    }

    public static func terrainRefusalsCheckpointAndBudgets() throws {
        let law:any TerrainLawEvaluating=BekkerJanosiTerrainLaw(), policy=try VehicleLawQualificationFixtures.terrainPolicy()
        var work=try VehicleLawQualificationFixtures.work()
        let initial=try VehicleLawQualificationFixtures.history(service:law,work:&work)
        let validStep=try VehicleLawQualificationFixtures.step(initial,localVelocity:Vector3(0,0,-0.1))
        let validTrial=try law.evaluate(step:validStep,accepted:initial,policy:policy,work:&work)
        let loaded=try law.accept(trial:validTrial,replacing:initial,work:&work)
        try expectTerrain(.staleSource,"stale trial base cannot overwrite an accepted prefix") { () throws(TerrainLawError) in
            _=try law.accept(trial:validTrial,replacing:loaded,work:&work)
        }
        let checkpoint=try law.checkpoint(accepted:loaded,work:&work)
        let restored=try law.restore(checkpoint:checkpoint,currentGrid:loaded.grid,currentCalibration:loaded.calibration,
            currentFootprint:loaded.footprint,currentInterfaceBody:loaded.interfaceBody,work:&work)
        try require(restored == loaded,"issued checkpoint restores all exact histories, source identities, time and sequence")
        let replayStep=try VehicleLawQualificationFixtures.step(loaded,localVelocity:.unitX)
        let replayA=try law.evaluate(step:replayStep,accepted:loaded,policy:policy,work:&work)
        let replayB=try law.evaluate(step:replayStep,accepted:restored,policy:policy,work:&work)
        let acceptedA=try law.accept(trial:replayA,replacing:loaded,work:&work)
        let acceptedB=try law.accept(trial:replayB,replacing:restored,work:&work)
        try require(acceptedA == acceptedB,"actual checkpoint replay reproduces all history bits without pseudo-restoration")
        let changedGrid=try VehicleLawQualificationFixtures.grid(work:&work,revision:4)
        let changedCalibration=try VehicleLawQualificationFixtures.soil(revision:10)
        try expectTerrain(.staleSource,"checkpoint original grid revision") { () throws(TerrainLawError) in
            _=try law.restore(checkpoint:checkpoint,currentGrid:changedGrid,currentCalibration:loaded.calibration,
                currentFootprint:loaded.footprint,currentInterfaceBody:loaded.interfaceBody,work:&work)
        }
        try expectTerrain(.staleSource,"checkpoint original calibration revision") { () throws(TerrainLawError) in
            _=try law.restore(checkpoint:checkpoint,currentGrid:loaded.grid,currentCalibration:changedCalibration,
                currentFootprint:loaded.footprint,currentInterfaceBody:loaded.interfaceBody,work:&work)
        }
        let wrongBody=try VehicleLawQualificationFixtures.reference(.body,"other-interface")
        try expectTerrain(.staleSource,"checkpoint original interface owner") { () throws(TerrainLawError) in
            _=try law.restore(checkpoint:checkpoint,currentGrid:loaded.grid,currentCalibration:loaded.calibration,
                currentFootprint:loaded.footprint,currentInterfaceBody:wrongBody,work:&work)
        }
        let movingFootprint=try TerrainRectangularFootprint(minimumX:0.3,maximumX:1.8,minimumY:0.5,maximumY:1.5)
        let movedStep=try VehicleLawQualificationFixtures.step(initial,localVelocity:Vector3(0,0,-0.1),footprint:movingFootprint)
        let staleStep=try VehicleLawQualificationFixtures.step(initial,localVelocity:.zero,startTime:1)
        let staleSourceStep=try VehicleLawQualificationFixtures.step(initial,localVelocity:.zero,gridRevision:4)
        let tooDeep=try VehicleLawQualificationFixtures.step(initial,localVelocity:Vector3(0,0,-0.6))
        let tooShort=try VehicleLawQualificationFixtures.step(initial,localVelocity:.zero,dt:5e-7)
        for (step,expected,message) in [(movedStep,TerrainLawError.changingFootprint,"fixed subarea history refuses footprint motion"),
            (staleStep,.staleTime,"original start time"),(staleSourceStep,.staleSource,"original source revision"),
            (tooDeep,.outsideCalibratedDomain,"bounded sinkage"),(tooShort,.outsideCalibratedDomain,"bounded time step")] {
            try expectTerrain(expected,message) { () throws(TerrainLawError) in
                _=try law.evaluate(step:step,accepted:initial,policy:policy,work:&work)
            }
        }
        try expectTerrain(.initiallyLoadedState,"no fabricated loaded soil importer") { () throws(TerrainLawError) in
            _=try law.initialHistory(grid:initial.grid,calibration:initial.calibration,footprint:initial.footprint,
                interfaceBody:initial.interfaceBody,interfaceHeight:-0.01,timeSeconds:0,policy:policy,work:&work)
        }
        let outside=try TerrainRectangularFootprint(minimumX:-0.25,maximumX:1.25,minimumY:0.5,maximumY:1.5)
        try expectTerrain(.outsideGrid,"actual footprint-grid coverage") { () throws(TerrainLawError) in
            _=try law.initialHistory(grid:initial.grid,calibration:initial.calibration,footprint:outside,
                interfaceBody:initial.interfaceBody,interfaceHeight:0,timeSeconds:0,policy:policy,work:&work)
        }
        let c=initial.calibration
        try expectTerrain(.invalidCalibration,"elastic unloading modulus must dominate bounded envelope slope") { () throws(TerrainLawError) in
            _=try TerrainSoilCalibration(source:c.source,revision:c.revision,material:c.material,cohesiveModulus:c.cohesiveModulus,
                frictionalModulus:c.frictionalModulus,sinkageExponent:c.sinkageExponent,unloadingModulus:2000,cohesion:c.cohesion,
                frictionTangent:c.frictionTangent,janosiLength:c.janosiLength,domain:c.domain,fittedFormulation:TerrainSoilCalibration.formulation)
        }
        let grid=initial.grid
        try expectTerrain(.cellLimit,"bounded actual grid cell allocation") { () throws(TerrainLawError) in
            _=try TerrainGrid(source:grid.source,revision:grid.revision,terrainBody:grid.terrainBody,material:grid.material,
                referenceFrame:grid.referenceFrame,terrainToReference:grid.terrainToReference,referenceOrigin:grid.referenceOrigin,
                minimumX:grid.minimumX,minimumY:grid.minimumY,cellWidth:grid.cellWidth,cellLength:grid.cellLength,
                columns:grid.columns,rows:grid.rows,undeformedHeights:grid.undeformedHeights,maximumCells:3,work:&work)
        }
        var exhausted=try VehicleLawQualificationFixtures.work(limit:3)
        try expectTerrain(.load(.workExhausted),"actual failed terrain metadata prefix") { () throws(TerrainLawError) in
            _=try law.evaluate(step:validStep,accepted:initial,policy:policy,work:&exhausted)
        }
        try require(exhausted.consumed == 3,"actual failed terrain trial retains three consumed units")
        var small=try VehicleLawQualificationFixtures.work(scalars:543)
        try expectTerrain(.load(.capacityExceeded),"actual candidate scalar bound") { () throws(TerrainLawError) in
            _=try law.evaluate(step:validStep,accepted:initial,policy:policy,work:&small)
        }
        var cancelled=try VehicleLawQualificationFixtures.work(cancelled:{ true })
        try expectTerrain(.load(.cancelled),"original caller cancellation before candidate publication") { () throws(TerrainLawError) in
            _=try law.evaluate(step:validStep,accepted:initial,policy:policy,work:&cancelled)
        }
        try require(initial.sequence == 0 && initial.interfaceHeight == 0 && initial.cells.allSatisfy({ $0.peakSinkage == 0 && $0.shearTravel == 0 }),
            "all rejected trials leave the caller's actual virgin accepted state unchanged")
        try require(loaded == restored,"failure paths cannot mutate the issued saved prefix")
    }
}
