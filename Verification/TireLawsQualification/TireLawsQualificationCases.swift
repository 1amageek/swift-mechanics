import SwiftMechanics

public enum TireLawsQualificationCases {
    private typealias Fixtures = TireLawsQualificationFixtures
    private static func require(_ condition: Bool, _ label: String) throws {
        guard condition else {throw TireLawsQualificationError.assertion(label)}
    }
    private static func close(_ actual: Double, _ expected: Double, _ label: String) throws {
        try require(actual.isFinite && abs(actual-expected)<=1e-8*max(1,abs(expected)),label)
    }
    private static func vector(_ actual: Vector3, _ x: Double, _ y: Double, _ z: Double, _ label: String) throws {
        try close(actual.x,x,label+" X");try close(actual.y,y,label+" Y");try close(actual.z,z,label+" Z")
    }
    private static func expect(_ expected: TireLawError, _ label: String, _ operation: () throws(TireLawError) -> Void) throws {
        do throws(TireLawError) {try operation()}
        catch {guard error==expected else {throw TireLawsQualificationError.originalFailure(error)};return}
        throw TireLawsQualificationError.unexpectedSuccess(label)
    }
    public static func zeroSlipPureCurvesAndLoad() throws {
        let law:any TireRoadEvaluating=RadialBrushTireLaw(),c=try Fixtures.calibration(),p=try Fixtures.policy(),f=try Fixtures.frame()
        var w=try Fixtures.work()
        for (spin,force,saturated) in [(20.0,0.0,false),(22,1900.0/27,false),(18,-1900.0/27,false),(26,100,true),(30,100,true)] {
            let r=try law.evaluate(sample:Fixtures.sample(spin:spin),frame:f,calibration:c,policy:p,work:&w)
            try close(r.longitudinalForce,force,"literal longitudinal radial anchor")
            try close(r.lateralForce,0,"zero lateral force")
            try require(r.isForceSaturated==saturated,"exact saturation branch")
            try close(r.rollingMoment,-4,"explicit rolling capacity")
            try close(r.power.rollingDissipationPower,4*spin,"independent rolling work rate")
            try vector(r.wheelCenterWrench.force,force,0,0,"no supplied normal-owner force")
            try vector(r.wheelCenterWrench.torque,0,-force/2-4,0,"literal lever-arm and rolling torque")
        }
        let lateral=try law.evaluate(sample:Fixtures.sample(vy:0.5),frame:f,calibration:c,policy:p,work:&w)
        try close(lateral.lateralForce,-1900.0/27,"literal lateral radial anchor")
        let lower=try law.evaluate(sample:Fixtures.sample(spin:22,normalLoad:100),frame:f,calibration:c,policy:p,work:&w)
        try close(lower.longitudinalForce,1300.0/27,"explicit supplied load changes shared capacity")
        let small=try Fixtures.sample(spin:20.00002),k=(0.5*small.spin-10)/10
        let r=try law.evaluate(sample:small,frame:f,calibration:c,policy:p,work:&w)
        try require(abs(r.longitudinalForce/k-1000)<=1000*(1000*abs(k)/100)/3*1.001,"initial longitudinal slope analytical cubic bound")
        let lat=try law.evaluate(sample:Fixtures.sample(vy:0.00001),frame:f,calibration:c,policy:p,work:&w)
        try require(abs(-lat.lateralForce/0.000001-2000)<=2000*(2000*0.000001/100)/3*1.001,"initial lateral slope analytical cubic bound")
    }
    public static func unequalStiffnessCombinedCone() throws {
        let law:any TireRoadEvaluating=RadialBrushTireLaw();var w=try Fixtures.work()
        let c=try Fixtures.calibration(),p=try Fixtures.policy(),f=try Fixtures.frame()
        let mixed=try law.evaluate(sample:Fixtures.sample(vy:0.2,spin:20.6),frame:f,calibration:c,policy:p,work:&w)
        try close(mixed.longitudinalForce,455.0/18,"3-4-5 independent radial longitudinal force")
        try close(mixed.lateralForce,-910.0/27,"3-4-5 independent radial lateral force")
        try close(mixed.slip.longitudinalRatio,0.03,"actual longitudinal ratio")
        try close(mixed.slip.lateralTangent,0.02,"actual lateral tangent")
        try close(mixed.power.slipDissipationPower,1547.0/108,"independent mixed surface work")
        try close(mixed.power.rollingDissipationPower,82.4,"independent mixed rolling loss")
        try require(!mixed.isForceSaturated,"mixed point remains below saturation")
        let saturated=try law.evaluate(sample:Fixtures.sample(vy:2,spin:26),frame:f,calibration:c,policy:p,work:&w)
        try close(saturated.longitudinalForce,60,"anisotropic saturated cone longitudinal")
        try close(saturated.lateralForce,-80,"anisotropic saturated cone lateral")
        try close(saturated.power.slipDissipationPower,340,"saturated actual surface loss")
        try require(saturated.isForceSaturated,"combined demand reaches common cone")
        try close((saturated.longitudinalForce*saturated.longitudinalForce+saturated.lateralForce*saturated.lateralForce).squareRoot(),100,"single shared100N cone")
        try require(mixed.power.wheelMechanicalPower+mixed.power.roadMechanicalPower<=0 && saturated.power.wheelMechanicalPower+saturated.power.roadMechanicalPower<=0,"original pair passivity")
    }
    public static func reverseBrakingAndRollingJump() throws {
        let law:any TireRoadEvaluating=RadialBrushTireLaw(),c=try Fixtures.calibration(),p=try Fixtures.policy(),f=try Fixtures.frame()
        var w=try Fixtures.work()
        for (vx,spin,kappa,force,moment) in [(10.0,18.0,-0.1,-1900.0/27,-4.0),(-10,-18,0.1,1900.0/27,4),(-10,-22,-0.1,-1900.0/27,4)] {
            let r=try law.evaluate(sample:Fixtures.sample(vx:vx,spin:spin),frame:f,calibration:c,policy:p,work:&w)
            try close(r.slip.longitudinalRatio,kappa,"signed physical reverse slip")
            try close(r.longitudinalForce,force,"force opposes original signed surface slip")
            try close(r.rollingMoment,moment,"rolling couple opposes signed spin")
            try require(r.power.slipDissipationPower>=0 && r.power.rollingDissipationPower>=0,"signed loss nonnegative")
        }
        for (spin,moment) in [(0.0,0.0),(1e-12,-4),(-1e-12,4)] {
            let r=try law.evaluate(sample:Fixtures.sample(spin:spin),frame:f,calibration:c,policy:p,work:&w)
            try close(r.longitudinalForce,-100,"spin-zero motion retains braking surface force")
            try close(r.rollingMoment,moment,"unsmoothed one-sided rolling moment")
            try close(r.power.rollingDissipationPower,4*abs(spin),"spin-zero loss and one-sided work")
        }
    }
    public static func worldWrenchMovingRoadAndBoost() throws {
        let law:any TireRoadEvaluating=RadialBrushTireLaw(),c=try Fixtures.calibration(),p=try Fixtures.policy()
        let rotation=try UnitQuaternion(axis:.unitZ,angle:.pi/2),point=try Vector3(4,-3,2),road=try Vector3(3,-2,0)
        let f=try Fixtures.frame(rotation:rotation,point:point);var w=try Fixtures.work()
        let r=try law.evaluate(sample:Fixtures.sample(vy:0.2,spin:20.6,roadVelocity:road,rotation:rotation,point:point),frame:f,calibration:c,policy:p,work:&w)
        try vector(r.wheelCenterWrench.force,910.0/27,455.0/18,0,"literal90-degree force mapping")
        try vector(r.wheelCenterWrench.torque,599.0/36,-455.0/27,0,"literal90-degree center torque")
        try vector(r.roadContactWrench.force,-910.0/27,-455.0/18,0,"original reaction force")
        try vector(r.roadContactWrench.torque,-4,0,0,"pure opposite rolling road couple")
        try vector(r.tangentialPointLoad.point,4,-3,2,"issued physical contact point")
        let wheel = -(599.0/36)*20.6+(910.0/27)*2.8+(455.0/18)*8,roadPower = -455.0/9
        try close(r.power.wheelMechanicalPower,wheel,"independent scalar wheel power")
        try close(r.power.roadMechanicalPower,roadPower,"independent translating-road power")
        try close(wheel+roadPower+1547.0/108+82.4,0,"independent pair/loss balance")
        try close(r.power.slipDissipationPower,1547.0/108,"frame-covariant physical slip loss")
        try close(r.power.rollingDissipationPower,82.4,"frame-covariant physical rolling loss")
        let boost=try Vector3(1024,-2048,512),boostedRoad=try road.adding(boost)
        let b=try law.evaluate(sample:Fixtures.sample(vy:0.2,spin:20.6,roadVelocity:boostedRoad,rotation:rotation,point:point),frame:f,calibration:c,policy:p,work:&w)
        let boostPower=(910.0/27)*1024-(455.0/18)*2048
        try close(b.power.wheelMechanicalPower,wheel+boostPower,"Galilean wheel power shift")
        try close(b.power.roadMechanicalPower,roadPower-boostPower,"Galilean road opposite shift")
        try close(b.power.slipDissipationPower,1547.0/108,"boost does not loosen physical slip loss")
        try close(b.power.wheelMechanicalPower+b.power.roadMechanicalPower,-1547.0/108-82.4,"boost preserves original dissipative pair")
        try require(r.tangentialPointLoad.potentialEnergy==nil,"no invented stored tire energy")
    }
    public static func calibrationAndArithmeticRefusals() throws {
        let tire=try Fixtures.tire(),road=try Fixtures.road(),domain=try Fixtures.domain()
        for (longitudinal,lateral,friction,rolling,formulation,source) in [
            (0.0,2000.0,0.5,0.02,TireBrushCalibration.formulation,"synthetic"),
            (1000,0,0.5,0.02,TireBrushCalibration.formulation,"synthetic"),
            (1000,2000,0,0.02,TireBrushCalibration.formulation,"synthetic"),
            (1000,2000,0.5,-0.02,TireBrushCalibration.formulation,"synthetic"),
            (1000,2000,0.5,0.02,"different-law","synthetic"),
            (1000,2000,0.5,0.02,TireBrushCalibration.formulation,"")
        ] {
            try expect(.invalidCalibration,"invalid explicit calibration") { () throws(TireLawError) in 
                _=try TireBrushCalibration(source:source,revision:7,tire:tire,roadSurface:road,
                    longitudinalStiffness:longitudinal,lateralStiffness:lateral,frictionCoefficient:friction,
                    rollingResistanceLength:rolling,domain:domain,fittedFormulation:formulation)
            }
        }
        try expect(.invalidCalibration,"wrong calibration entity kind") { () throws(TireLawError) in 
            _=try TireBrushCalibration(source:"synthetic",revision:7,tire:road,roadSurface:road,
                longitudinalStiffness:1000,lateralStiffness:2000,frictionCoefficient:0.5,
                rollingResistanceLength:0.02,domain:domain,fittedFormulation:TireBrushCalibration.formulation)
        }
        try expect(.invalidCalibration,"zero positive load envelope") { () throws(TireLawError) in _=try Fixtures.domain(loadMinimum:0)}
        try expect(.invalidCalibration,"inverted load envelope") { () throws(TireLawError) in _=try Fixtures.domain(loadMinimum:500)}
        try expect(.invalidCalibration,"negative slip envelope") { () throws(TireLawError) in _=try Fixtures.domain(slipMaximum: -1)}
        try expect(.invalidPolicy,"unit relative tolerance") { () throws(TireLawError) in 
            _=try TireAcceptancePolicy(contactDistanceTolerance:0,normalSpeedTolerance:0,
                absolutePowerTolerance:0,referencePower:1,absoluteForceTolerance:0,referenceForce:1,relativeTolerance:1)
        }
        let world=try Fixtures.world()
        try expect(.invalidInput,"non-frame road reference") { () throws(TireLawError) in 
            _=try TireRoadFrame(reference:tire,contactToReference:.identity,planePoint:.zero)
        }
        for (time,radius,load,spin) in [(-1.0,0.5,200.0,20.0),(2,0,200,20),(2,0.5,0,20),(2,0.5,200,Double.infinity)] {
            try expect(.invalidInput,"original sample scalar admission") { () throws(TireLawError) in 
                _=try TireRoadSample(tire:tire,roadSurface:road,referenceFrame:world,calibrationRevision:7,timeSeconds:time,
                    centerPosition:.zero,centerVelocity:.zero,roadContactVelocity:.zero,spin:spin,radius:radius,normalLoad:load)
            }
        }
        let law:any TireRoadEvaluating=RadialBrushTireLaw(),policy=try Fixtures.policy(),frame=try Fixtures.frame()
        let large=try Fixtures.calibration(longitudinal:1.7e308,lateral:1.7e308,friction:1,rolling:0,
            domain:Fixtures.domain(loadMinimum:1,loadMaximum:1,slipMaximum:1,lateralMaximum:1))
        let largeSample=try Fixtures.sample(vx:1,vy:1,spin:4,normalLoad:1)
        var work=try Fixtures.work()
        try expect(.nonFiniteResult,"finite components overflowing combined demand") { () throws(TireLawError) in 
            _=try law.evaluate(sample:largeSample,frame:frame,calibration:large,policy:policy,work:&work)
        }
        let small=try Fixtures.calibration(longitudinal:Double.leastNonzeroMagnitude,rolling:0)
        let smallSample=try Fixtures.sample(spin:20.2)
        try expect(.nonFiniteResult,"nonzero slip demand underflow") { () throws(TireLawError) in 
            _=try law.evaluate(sample:smallSample,frame:frame,calibration:small,policy:policy,work:&work)
        }
        let smallRolling=try Fixtures.calibration(friction:1,rolling:Double.leastNonzeroMagnitude,
            domain:Fixtures.domain(loadMinimum:0.1,loadMaximum:0.1))
        let rollingSample=try Fixtures.sample(normalLoad:0.1)
        try expect(.nonFiniteResult,"nonzero rolling calibration capacity underflow") { () throws(TireLawError) in 
            _=try law.evaluate(sample:rollingSample,frame:frame,calibration:smallRolling,policy:policy,work:&work)
        }
    }
    public static func geometryRevisionsAndEnvelope() throws {
        let law:any TireRoadEvaluating=RadialBrushTireLaw(),c=try Fixtures.calibration(),p=try Fixtures.policy(),f=try Fixtures.frame()
        var w=try Fixtures.work()
        let originalSample=try Fixtures.sample(spin:22)
        let original=try law.evaluate(sample:originalSample,frame:f,calibration:c,policy:p,work:&w)
        let changedFrame=try Fixtures.frame(reference:Fixtures.world(revision:2))
        try expect(.frameMismatch,"exact frame revision") { () throws(TireLawError) in 
            _=try law.evaluate(sample:originalSample,frame:changedFrame,calibration:c,policy:p,work:&w)
        }
        let refusals:[(TireRoadSample,TireLawError)]=[
            (try Fixtures.sample(tire:Fixtures.tire(revision:2)),.calibrationMismatch),
            (try Fixtures.sample(road:Fixtures.road(revision:2)),.calibrationMismatch),
            (try Fixtures.sample(calibrationRevision:8),.calibrationMismatch),
            (try Fixtures.sample(height:0.51),.contactGeometryMismatch),
            (try Fixtures.sample(vz:0.1),.contactGeometryMismatch),
            (try Fixtures.sample(vx:0.1,spin:0),.lowSpeedDomain),
            (try Fixtures.sample(radius:0.7),.outsideCalibratedDomain),
            (try Fixtures.sample(normalLoad:401),.outsideCalibratedDomain),
            (try Fixtures.sample(vx:21),.outsideCalibratedDomain),
            (try Fixtures.sample(vy:11),.outsideCalibratedDomain),
            (try Fixtures.sample(spin:101),.outsideCalibratedDomain),
            (try Fixtures.sample(spin:80),.outsideCalibratedDomain),
            (try Fixtures.sample(vx:1,vy:2,spin:2),.outsideCalibratedDomain)
        ]
        for (sample,error) in refusals {
            try expect(error,"original selected envelope refusal") { () throws(TireLawError) in 
                _=try law.evaluate(sample:sample,frame:f,calibration:c,policy:p,work:&w)
            }
        }
        for sample in [try Fixtures.sample(normalLoad:100),try Fixtures.sample(normalLoad:400),
            try Fixtures.sample(spin:25,radius:0.4),try Fixtures.sample(spin:50.0/3,radius:0.6),
            try Fixtures.sample(vx:0.2,spin:0.4),try Fixtures.sample(vx:20,spin:40),
            try Fixtures.sample(vx:20,spin:100),try Fixtures.sample(vy:10),try Fixtures.sample(spin:60)] {
            let boundary=try law.evaluate(sample:sample,frame:f,calibration:c,policy:p,work:&w)
            try require(boundary.sample.radius==sample.radius && boundary.sample.normalLoad==sample.normalLoad &&
                boundary.power.slipDissipationPower>=0,"closed admitted envelope retains original physical input")
        }
        let later=try law.evaluate(sample:Fixtures.sample(spin:18),frame:f,calibration:c,policy:p,work:&w)
        try close(original.longitudinalForce,1900.0/27,"older immutable issued force")
        try close(later.longitudinalForce,-1900.0/27,"later invocation uses original new motion")
        try require(original.sample.spin==22 && original.sample.timeSeconds==2 && original.calibration.source==c.source &&
            original.calibration.revision==7 && original.frame.reference==f.reference,"issued source/time/revision lifetimes")
        for ratio in [0.025,0.075,0.125,0.2,0.3,0.4] {
            let r=try law.evaluate(sample:Fixtures.sample(spin:20+20*ratio),frame:f,calibration:c,policy:p,work:&w)
            let remaining=max(0,1-(1000*ratio)/(3*100)),expected=100*(1-remaining*remaining*remaining)
            try close(r.longitudinalForce,expected,"independently factored adhesion curve")
        }
    }
    public static func exactWorkPrefixesAndCancellation() throws {
        let law:any TireRoadEvaluating=RadialBrushTireLaw(),c=try Fixtures.calibration(),p=try Fixtures.policy(),f=try Fixtures.frame(),s=try Fixtures.sample()
        let metadata=[s.tire.id.key,s.roadSurface.id.key,s.referenceFrame.id.key,f.reference.id.key,
            c.tire.id.key,c.roadSurface.id.key,c.source,TireBrushCalibration.formulation]
        let exact=metadata.reduce(1) {$0+$1.utf8.count},graphemes=metadata.reduce(1) {$0+$1.count}
        var full=try Fixtures.work(limit:2*exact)
        _=try law.evaluate(sample:s,frame:f,calibration:c,policy:p,work:&full)
        try require(full.consumed==exact && full.peakScalars==192,"exact UTF8 metadata and single constitutive work unit")
        _=try law.evaluate(sample:s,frame:f,calibration:c,policy:p,work:&full)
        try require(full.consumed==2*exact,"exclusive original work accumulates across calls")
        try expect(.load(.workExhausted),"no reset of exhausted original work") { () throws(TireLawError) in 
            _=try law.evaluate(sample:s,frame:f,calibration:c,policy:p,work:&full)
        }
        try require(full.consumed==2*exact,"exhausted original prefix preserved")
        for limit in [3,exact-1,graphemes] {
            var partial=try Fixtures.work(limit:limit)
            try expect(.load(.workExhausted),"bounded exact metadata failure") { () throws(TireLawError) in 
                _=try law.evaluate(sample:s,frame:f,calibration:c,policy:p,work:&partial)
            }
            try require(partial.consumed==limit && partial.peakScalars==192,"actual work prefix retained without partial response")
        }
        try require(graphemes<exact,"Unicode metadata distinguishes UTF8 budget")
        var short=try Fixtures.work(scalars:191)
        try expect(.load(.capacityExceeded),"scalar admission") { () throws(TireLawError) in 
            _=try law.evaluate(sample:s,frame:f,calibration:c,policy:p,work:&short)
        }
        try require(short.consumed==0 && short.peakScalars==0,"failed scalar reservation publishes no storage")
        var cancelled=try Fixtures.work(cancelled:{true})
        try expect(.load(.cancelled),"original caller cancellation callback") { () throws(TireLawError) in 
            _=try law.evaluate(sample:s,frame:f,calibration:c,policy:p,work:&cancelled)
        }
        try require(cancelled.consumed==0 && cancelled.peakScalars==0,"cancel before any metadata/storage charge")
    }
}
