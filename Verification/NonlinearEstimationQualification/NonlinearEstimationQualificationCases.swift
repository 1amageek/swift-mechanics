import SwiftMechanics

// FIXME(INCOMPLETE_IMPLEMENTATION): These prepared public cases call the real selected EKF but have no executed matched-source qualification yet. Native tests and standalone entry use this declaration; success requires the original physical/covariance/refusal/work oracles on a source/object-bound repaired producer.
public enum NonlinearEstimationQualificationCases {
    private static func require(_ value: Bool, _ message: String) throws(NonlinearEstimationQualificationError) {
        guard value else { throw .assertion(message) }
    }
    private static func close(_ a: Double, _ b: Double, _ message: String, tolerance: Double = 1e-10) throws(NonlinearEstimationQualificationError) {
        try require(a.isFinite && b.isFinite && abs(a-b) <= tolerance*max(1,max(abs(a),abs(b))), message)
    }
    private static func vector(_ a: [Double], _ b: [Double], _ message: String, tolerance: Double = 1e-10) throws(NonlinearEstimationQualificationError) {
        try require(a.count == b.count,message+" shape")
        for i in a.indices { try close(a[i],b[i],message+" index "+String(i),tolerance:tolerance) }
    }
    private static func failure(_ operation: () throws -> Void) throws(NonlinearEstimationQualificationError) -> NonlinearEstimatorFailure {
        do { try operation() }
        catch let error as NonlinearEstimatorFailure { return error }
        catch { throw .unexpectedSupplier }
        throw .assertion("Expected typed estimator refusal")
    }
    public static func originalMechanicsAndPhysicalJacobian() throws(NonlinearEstimationQualificationError) {
        try NonlinearEstimationQualificationFixtures.translated {
            let plant = try NonlinearEstimationQualificationFixtures.plant()
            let checkpoint = try NonlinearEstimationQualificationFixtures.initial(plant)
            let same = try NonlinearEstimationQualificationFixtures.update(checkpoint,target:2,substeps:0,q:[0,0,0,0])
            let encoder = same.predictedEncoder
            try require(plant.model.stamp.identity == "original-polynomial-prismatic-model" && plant.model.stamp.revision == 29,
                "Independent original compiled stamp")
            let movingID = try NonlinearEstimationQualificationFixtures.id(.body,"moving")
            guard let original = plant.model.descriptor.bodies.first(where: { $0.id == movingID }),
                  case .spatial(let moving) = original, let inertia = moving.inertia else {
                throw NonlinearEstimationQualificationError.assertion("Original physical inertia representation absent")
            }
            try require(inertia.provenance.source == "original-two-kilogram-slider" && inertia.provenance.revision == 29 && inertia.quality == .exact,
                "Independent original physical provenance/fidelity")
            try close(plant.movingMassKilograms,2,"Original actual moving mass")
            try close(encoder.accelerations[0],NonlinearEstimationQualificationOracle.acceleration(0.6,-0.4),"Original nonlinear mass acceleration")
            try require(encoder.model == plant.model.stamp && encoder.joint == plant.joint && encoder.parentAnchorFrame == plant.parentAnchorFrame,"Original encoder source/frame")
            try require(encoder.timeSeconds == 2 && encoder.positionUnits == [.length] && encoder.velocityUnits == [.velocity]
                && encoder.accelerationUnits == [.acceleration] && encoder.accelerationAuthority == .suppliedState,"Original encoder SI/time/acceleration authority")
            try require(same.checkpoint.updateSequence == 1 && same.checkpoint.lastObservationSequence == nil,"Missing observation sequence")
            try vector(same.normalizedTransition,[1,0,0,1],"Zero-time transition")
            let epsilon = 1e-6
            var derivatives: [Double] = []
            for variable in 0..<2 {
                let plus = try NonlinearEstimationQualificationFixtures.initial(plant,position:0.6+(variable == 0 ? epsilon : 0),rate:-0.4+(variable == 1 ? epsilon : 0))
                let minus = try NonlinearEstimationQualificationFixtures.initial(plant,position:0.6-(variable == 0 ? epsilon : 0),rate:-0.4-(variable == 1 ? epsilon : 0))
                let upper = try NonlinearEstimationQualificationFixtures.update(plus,target:2,substeps:0,q:[0,0,0,0])
                let lower = try NonlinearEstimationQualificationFixtures.update(minus,target:2,substeps:0,q:[0,0,0,0])
                derivatives.append((upper.predictedEncoder.accelerations[0]-lower.predictedEncoder.accelerations[0])/(2*epsilon))
            }
            try vector(derivatives,[(-3-6*0.5*0.5)/2,(-0.4-1.8*0.4*0.4)/2],"Original physical acceleration Jacobian FD",tolerance:2e-8)
        }
    }
    public static func originalRK4AndDiscreteTransition() throws(NonlinearEstimationQualificationError) {
        try NonlinearEstimationQualificationFixtures.translated {
            let plant = try NonlinearEstimationQualificationFixtures.plant(), checkpoint = try NonlinearEstimationQualificationFixtures.initial(plant)
            let prediction = try NonlinearEstimationQualificationFixtures.update(checkpoint)
            let independent = NonlinearEstimationQualificationOracle.rk4(position:0.6,rate:-0.4,interval:0.1,steps:4)
            try vector([prediction.predictedPositionMeters,prediction.predictedRateMetersPerSecond],independent,"Independent polynomial RK4")
            let epsilon = 1e-6, scales = [2.0,3.0]
            var fd = [Double](repeating:0,count:4)
            for column in 0..<2 {
                let displacement = epsilon*scales[column]
                let plus = try NonlinearEstimationQualificationFixtures.initial(plant,position:0.6+(column == 0 ? displacement : 0),rate:-0.4+(column == 1 ? displacement : 0))
                let minus = try NonlinearEstimationQualificationFixtures.initial(plant,position:0.6-(column == 0 ? displacement : 0),rate:-0.4-(column == 1 ? displacement : 0))
                let upper = try NonlinearEstimationQualificationFixtures.update(plus), lower = try NonlinearEstimationQualificationFixtures.update(minus)
                fd[column] = (upper.predictedPositionMeters-lower.predictedPositionMeters)/(2*epsilon*scales[0])
                fd[2+column] = (upper.predictedRateMetersPerSecond-lower.predictedRateMetersPerSecond)/(2*epsilon*scales[1])
            }
            try vector(prediction.normalizedTransition,fd,"Whole discrete RK4 normalized transition FD",tolerance:2e-6)
            let cov = NonlinearEstimationQualificationOracle.covariance(fd,checkpoint.normalizedCovariance,[0.01,0,0,0.02])
            try vector(prediction.predictedNormalizedCovariance,cov,"Independent FPF plus discrete Q",tolerance:2e-6)
            try require(prediction.normalizedGain == nil && prediction.normalizedInnovation == nil && prediction.checkpoint.lastObservationSequence == nil,"Missing data does not invent a measurement")
            try close(prediction.predictedEncoder.accelerations[0],NonlinearEstimationQualificationOracle.acceleration(independent[0],independent[1]),"Actual final original acceleration")
        }
    }
    public static func originalInnovationAndJoseph() throws(NonlinearEstimationQualificationError) {
        try NonlinearEstimationQualificationFixtures.translated {
            let plant = try NonlinearEstimationQualificationFixtures.plant(), checkpoint = try NonlinearEstimationQualificationFixtures.initial(plant)
            let prediction = try NonlinearEstimationQualificationFixtures.update(checkpoint)
            let measurement = try NonlinearEstimationQualificationFixtures.reading(plant,time:2.1,position:prediction.predictedPositionMeters+0.2)
            let actual = try NonlinearEstimationQualificationFixtures.update(checkpoint,measurement:measurement)
            let p = prediction.predictedNormalizedCovariance, r = 0.16/4, innovation = 0.2/2, variance = p[0]+r
            let k0 = p[0]/variance, k1 = p[2]/variance
            guard let y = actual.normalizedInnovation, let s = actual.normalizedInnovationVariance,
                  let nis = actual.normalizedInnovationSquared, let gain = actual.normalizedGain else { throw NonlinearEstimationQualificationError.assertion("Actual innovation evidence absent") }
            try close(y,innovation,"Independent normalized encoder innovation")
            try close(s,variance,"Independent innovation variance")
            try close(nis,innovation*innovation/variance,"Independent NIS")
            try vector(gain,[k0,k1],"Independent gain")
            try close(actual.checkpoint.positionMeters,prediction.predictedPositionMeters+2*k0*innovation,"Posterior SI position")
            try close(actual.checkpoint.rateMetersPerSecond,prediction.predictedRateMetersPerSecond+3*k1*innovation,"Posterior SI rate")
            let joseph = NonlinearEstimationQualificationOracle.covariance([1-k0,0,-k1,1],p,[k0*r*k0,k0*r*k1,k1*r*k0,k1*r*k1])
            try vector(actual.checkpoint.normalizedCovariance,joseph,"Independent complete Joseph posterior")
            try require(joseph[0] > 0 && joseph[3] > 0 && joseph[0]*joseph[3]-joseph[1]*joseph[2] > 0,"Original posterior SPD")
            try require(actual.checkpoint.timeSeconds == 2.1 && actual.checkpoint.updateSequence == 1 && actual.checkpoint.lastObservationSequence == 7,"Actual posterior clock/sequence")
            let replay = try NonlinearEstimationQualificationFixtures.update(checkpoint,measurement:measurement)
            try vector(replay.checkpoint.normalizedCovariance,actual.checkpoint.normalizedCovariance,"Immutable replay covariance")
            try require(checkpoint.positionMeters == 0.6 && checkpoint.updateSequence == 0 && checkpoint.lastObservationSequence == nil,"Original input checkpoint immutable")
        }
    }
    public static func originalScaledCovariance() throws(NonlinearEstimationQualificationError) {
        try NonlinearEstimationQualificationFixtures.translated {
            let firstPlant = try NonlinearEstimationQualificationFixtures.plant(), secondPlant = try NonlinearEstimationQualificationFixtures.plant(positionScale:1,rateScale:1)
            let first = try NonlinearEstimationQualificationFixtures.initial(firstPlant), second = try NonlinearEstimationQualificationFixtures.initial(secondPlant,covariance:[1.6,0.6,0.6,2.7])
            let observedFirst = try NonlinearEstimationQualificationFixtures.reading(firstPlant,time:2.1,position:0.7)
            let observedSecond = try NonlinearEstimationQualificationFixtures.reading(secondPlant,time:2.1,position:0.7)
            let a = try NonlinearEstimationQualificationFixtures.update(first,measurement:observedFirst)
            let b = try NonlinearEstimationQualificationFixtures.update(second,q:[0.04,0,0,0.18],measurement:observedSecond)
            try vector([a.checkpoint.positionMeters,a.checkpoint.rateMetersPerSecond],[b.checkpoint.positionMeters,b.checkpoint.rateMetersPerSecond],"Normalized scales preserve SI posterior")
            try vector(NonlinearEstimationQualificationOracle.physical(a.checkpoint.normalizedCovariance,scales:[2,3]),b.checkpoint.normalizedCovariance,"Explicit physical covariance scale conversion")
            guard let firstNIS = a.normalizedInnovationSquared, let secondNIS = b.normalizedInnovationSquared else { throw NonlinearEstimationQualificationError.assertion("NIS missing") }
            try close(firstNIS,secondNIS,"NIS scale equivalence")
        }
    }
    public static func originalTimeSourceAndDomain() throws(NonlinearEstimationQualificationError) {
        try NonlinearEstimationQualificationFixtures.translated {
            let plant = try NonlinearEstimationQualificationFixtures.plant(), checkpoint = try NonlinearEstimationQualificationFixtures.initial(plant)
            let delayed = try NonlinearEstimationQualificationFixtures.reading(plant,time:2,position:0.6)
            let old = try failure { _ = try NonlinearEstimationQualificationFixtures.update(checkpoint,measurement:delayed) }
            if case .delayedObservationUnsupported(measured:2,target:2.1) = old.cause {} else { throw NonlinearEstimationQualificationError.assertion("Exact delayed refusal") }
            let future = try NonlinearEstimationQualificationFixtures.reading(plant,time:2.2,position:0.6)
            let ahead = try failure { _ = try NonlinearEstimationQualificationFixtures.update(checkpoint,measurement:future) }
            if case .observationTimeMismatch(measured:2.2,target:2.1) = ahead.cause {} else { throw NonlinearEstimationQualificationError.assertion("Exact future refusal") }
            let lateDelivery = try NonlinearEstimationQualificationFixtures.reading(plant,time:2.1,position:0.6,delivery:2.2)
            let delivery = try failure { _ = try NonlinearEstimationQualificationFixtures.update(checkpoint,measurement:lateDelivery) }
            if case .deliveryTimeMismatch = delivery.cause {} else { throw NonlinearEstimationQualificationError.assertion("Exact delivery refusal") }
            let reading = try NonlinearEstimationQualificationFixtures.reading(plant,time:2.1,position:0.6)
            let accepted = try NonlinearEstimationQualificationFixtures.update(checkpoint,measurement:reading)
            let duplicate = try failure { _ = try NonlinearEstimationQualificationFixtures.update(accepted.checkpoint,target:2.1,substeps:0,q:[0,0,0,0],measurement:reading) }
            if case .observationSequenceMismatch = duplicate.cause {} else { throw NonlinearEstimationQualificationError.assertion("Exact duplicate refusal") }
            let foreign = try NonlinearEstimationQualificationFixtures.reading(plant,time:2.1,position:0.6,foreignModel:NonlinearEstimationQualificationFixtures.model(identity:"foreign-original-model"))
            let source = try failure { _ = try NonlinearEstimationQualificationFixtures.update(checkpoint,measurement:foreign) }
            if case .sourceMismatch = source.cause {} else { throw NonlinearEstimationQualificationError.assertion("Original model source refusal") }
            let backwards = try failure { _ = try NonlinearEstimationQualificationFixtures.update(checkpoint,target:1.9) }
            if case .invalidInput = backwards.cause {} else { throw NonlinearEstimationQualificationError.assertion("Clock reversal refusal") }
            let bounded = try NonlinearEstimationQualificationFixtures.policy(coordinate:0.59)
            let domain = try failure { _ = try NonlinearEstimationQualificationFixtures.update(checkpoint,admittedPolicy:bounded) }
            if case .outsidePhysicalDomain = domain.cause {} else { throw NonlinearEstimationQualificationError.assertion("Physical domain refusal") }
            var modelWork = try NonlinearEstimationQualificationFixtures.work()
            let unsupported = try failure { _ = try PrismaticEstimationModel(model:NonlinearEstimationQualificationFixtures.model(axis:.unitY),joint:plant.joint,
                passiveLaw:plant.passiveLaw,positionScaleMeters:2,rateScaleMetersPerSecond:3,policy:NonlinearEstimationQualificationFixtures.policy(),work:&modelWork) }
            if case .unsupportedModel = unsupported.cause {} else { throw NonlinearEstimationQualificationError.assertion("Original unsupported axis refusal") }
            try require(checkpoint.timeSeconds == 2 && checkpoint.updateSequence == 0,"All failed updates preserve original checkpoint")
        }
    }
    public static func originalPSDAndCovariance() throws(NonlinearEstimationQualificationError) {
        try originalExponentSafePSD()
        try NonlinearEstimationQualificationFixtures.translated {
            let plant = try NonlinearEstimationQualificationFixtures.plant(), checkpoint = try NonlinearEstimationQualificationFixtures.initial(plant)
            for q in [[1.0,1e-200,1e-200,0],[0,1e-200,1e-200,1],[1,Double.leastNonzeroMagnitude,Double.leastNonzeroMagnitude,0],[-0.1,0,0,0],[1,2,2,1],[1,0.1,0.2,1],[Double.nan,0,0,0]] {
                let refused = try failure { _ = try NonlinearEstimationQualificationFixtures.update(checkpoint,q:q) }
                if case .invalidCovariance = refused.cause {} else { throw NonlinearEstimationQualificationError.assertion("Original literal invalid Q refusal") }
            }
            for q in [[0.0,0,0,0],[0,0,0,0.2],[0.2,0.1,0.1,0.05]] {
                let admitted = try NonlinearEstimationQualificationFixtures.update(checkpoint,q:q)
                try require(admitted.checkpoint.normalizedCovariance.allSatisfy({ $0.isFinite }),"Genuine PSD Q is accepted without jitter")
            }
            let singular = try failure { _ = try NonlinearEstimationQualificationFixtures.initial(plant,covariance:[1,0,0,0]) }
            if case .linear(.nonPositiveDefinite(pivot:1),failedSupplierWorkUnavailable:true) = singular.cause {} else { throw NonlinearEstimationQualificationError.assertion("Original singular P Cholesky refusal") }
            let invalidR = try NonlinearEstimationQualificationFixtures.reading(plant,time:2.1,position:0.6,variance:0)
            let variance = try failure { _ = try NonlinearEstimationQualificationFixtures.update(checkpoint,measurement:invalidR) }
            if case .invalidInput = variance.cause {} else { throw NonlinearEstimationQualificationError.assertion("Original invalid physical R refusal") }
            let reading = try NonlinearEstimationQualificationFixtures.reading(plant,time:2.1,position:10)
            let nis = try failure { _ = try NonlinearEstimationQualificationFixtures.update(checkpoint,measurement:reading,admittedPolicy:NonlinearEstimationQualificationFixtures.policy(nis:1)) }
            if case .innovationRejected(let actual,limit:1) = nis.cause { try require(actual > 1,"Original excessive NIS") } else { throw NonlinearEstimationQualificationError.assertion("Original NIS typed rejection") }
            let nonzeroAtZero = try failure { _ = try NonlinearEstimationQualificationFixtures.update(checkpoint,target:2,substeps:0,q:[1e-200,0,0,0]) }
            if case .invalidCovariance = nonzeroAtZero.cause {} else { throw NonlinearEstimationQualificationError.assertion("Zero interval forbids nonzero discrete Q") }
        }
    }
    public static func originalExponentSafePSD() throws(NonlinearEstimationQualificationError) {
        try NonlinearEstimationQualificationFixtures.translated {
            let plant = try NonlinearEstimationQualificationFixtures.plant(), checkpoint = try NonlinearEstimationQualificationFixtures.initial(plant)
            let small = Double(sign: .plus, exponent: -664, significand: 1)
            let large = Double(sign: .plus, exponent: 664, significand: 1)
            let boundary = Double(sign: .plus, exponent: -536, significand: 1)
            let wide = try NonlinearEstimationQualificationFixtures.policy(covarianceMagnitude: 1e201)
            let invalid = [
                [Double.leastNonzeroMagnitude,5e-162,5e-162,4],
                [Double.leastNonzeroMagnitude,boundary.nextUp,boundary.nextUp,4],
                [1e-200,2,2,1e200],
                [small,1.0.nextUp,1.0.nextUp,large],
                [small,-1.0.nextUp,-1.0.nextUp,large]
            ]
            let metadataBytes = ["original-polynomial-prismatic-model", "ekf-original-slide", "ekf-original-world",
                "ekf-original-parent-anchor", "ekf-original-child-anchor", "ekf-original-root", "ekf-original-root-frame",
                "ekf-original-moving", "ekf-original-moving-frame"].reduce(0) { $0+$1.utf8.count }
            let service: any NonlinearStateEstimating = ReferenceMechanicalEKF()
            for q in invalid {
                var ledger = try NonlinearEstimationQualificationFixtures.work()
                try ledger.chargeOperations(7); try ledger.requireStorage(11)
                let refused = try failure {
                    _ = try service.update(checkpoint,request:NonlinearEstimatorRequest(targetTimeSeconds:2.1,heldEffortNewtons:1.5,
                        substeps:4,normalizedProcessCovariance:q,measurement:nil),policy:wide,work:&ledger)
                }
                if case .invalidCovariance = refused.cause {} else {
                    throw NonlinearEstimationQualificationError.assertion("Exact exponent-separated indefinite Q refusal")
                }
                try require(refused.phase == "update-admission" && refused.derivativeCalls == 0,
                    "Indefinite Q is refused before physical propagation")
                try require(ledger.operations == 263+metadataBytes && ledger.peakScalarStorage == 512 && refused.work == ledger,
                    "Exact bounded admission and metadata work retained on PSD refusal")
            }
            for q in [[Double.leastNonzeroMagnitude,boundary,boundary,4],
                      [Double.leastNonzeroMagnitude,boundary.nextDown,boundary.nextDown,4],
                      [Double.leastNonzeroMagnitude,-boundary,-boundary,4],
                      [small,1,1,large], [small,1.0.nextDown,1.0.nextDown,large], [small,0,0,large]] {
                let admitted = try NonlinearEstimationQualificationFixtures.update(checkpoint,q:q,admittedPolicy:wide)
                try require(admitted.checkpoint.updateSequence == 1 && admitted.checkpoint.normalizedCovariance.allSatisfy({ $0.isFinite }),
                    "Exact rank-one and positive exponent-separated Q accepted without repair")
            }
            try require(checkpoint.updateSequence == 0 && checkpoint.timeSeconds == 2,
                "Exponent-separated covariance cases preserve original checkpoint")
        }
    }
    public static func originalWorkCapacityAndCancellation() throws(NonlinearEstimationQualificationError) {
        try NonlinearEstimationQualificationFixtures.translated {
            let plant = try NonlinearEstimationQualificationFixtures.plant(), checkpoint = try NonlinearEstimationQualificationFixtures.initial(plant)
            let service: any NonlinearStateEstimating = ReferenceMechanicalEKF()
            var operations = try NonlinearEstimationQualificationFixtures.work(operations:262)
            try operations.chargeOperations(7);try operations.requireStorage(11)
            let original = operations
            let failedOps = try failure { _ = try service.initialize(plant:plant,timeSeconds:2,positionMeters:0.6,rateMetersPerSecond:-0.4,
                normalizedCovariance:[0.4,0.1,0.1,0.3],policy:NonlinearEstimationQualificationFixtures.policy(),work:&operations) }
            if case .numerical(.resourceLimit(resource:.arithmeticOperations,limit:262)) = failedOps.cause {} else { throw NonlinearEstimationQualificationError.assertion("Exact upfront operation refusal") }
            try require(operations == original && failedOps.work == original && failedOps.derivativeCalls == 0,"Refused charge retains exact consumed prefix")
            var storage = try NonlinearEstimationQualificationFixtures.work(storage:511)
            try storage.chargeOperations(7);try storage.requireStorage(11)
            let failedStorage = try failure { _ = try service.initialize(plant:plant,timeSeconds:2,positionMeters:0.6,rateMetersPerSecond:-0.4,
                normalizedCovariance:[0.4,0.1,0.1,0.3],policy:NonlinearEstimationQualificationFixtures.policy(),work:&storage) }
            if case .numerical(.resourceLimit(resource:.scalarStorage,limit:511)) = failedStorage.cause {} else { throw NonlinearEstimationQualificationError.assertion("Exact storage refusal") }
            try require(storage.operations == 263 && storage.peakScalarStorage == 11 && failedStorage.work == storage,"Successful256 charge retained before storage refusal")
            let callLimit = try failure { _ = try NonlinearEstimationQualificationFixtures.update(checkpoint,admittedPolicy:NonlinearEstimationQualificationFixtures.policy(derivativeCalls:0)) }
            if case .derivatives(.capacityExceeded) = callLimit.cause {} else { throw NonlinearEstimationQualificationError.assertion("Original derivative-call refusal") }
            try require(callLimit.derivativeCalls == 0 && callLimit.work.operations >= 256,"Known derivative-call failure prefix retained")
            let substeps = try failure { _ = try NonlinearEstimationQualificationFixtures.update(checkpoint,substeps:33) }
            if case .capacityExceeded = substeps.cause {} else { throw NonlinearEstimationQualificationError.assertion("Declared substep capacity refusal") }
            var cancelled = try NonlinearEstimationQualificationFixtures.work()
            try cancelled.chargeOperations(17);try cancelled.requireStorage(23)
            let prefix = cancelled
            let cancelRefusal = try failure { _ = try service.update(checkpoint,request:NonlinearEstimatorRequest(targetTimeSeconds:2.1,heldEffortNewtons:1.5,substeps:4,
                normalizedProcessCovariance:[0,0,0,0],measurement:nil),policy:NonlinearEstimationQualificationFixtures.policy(cancelled:{true}),work:&cancelled) }
            if case .cancelled = cancelRefusal.cause {} else { throw NonlinearEstimationQualificationError.assertion("Original callback cancellation") }
            try require(cancelled == prefix && cancelRefusal.work == prefix && cancelRefusal.derivativeCalls == 0,"Cancellation preserves exact original work")
        }
    }
    public static func actualNativeCancellation(checkpoint: NonlinearEstimatorCheckpoint) throws(NonlinearEstimationQualificationError) {
        try NonlinearEstimationQualificationFixtures.translated {
            var ledger = try NonlinearEstimationQualificationFixtures.work();try ledger.chargeOperations(17);try ledger.requireStorage(23)
            let prefix = ledger, service: any NonlinearStateEstimating = ReferenceMechanicalEKF()
            let refused = try failure { _ = try service.update(checkpoint,request:NonlinearEstimatorRequest(targetTimeSeconds:2.1,heldEffortNewtons:1.5,substeps:4,
                normalizedProcessCovariance:[0,0,0,0],measurement:nil),policy:NonlinearEstimationQualificationFixtures.policy(),work:&ledger) }
            if case .cancelled = refused.cause {} else { throw NonlinearEstimationQualificationError.assertion("Actual cancelled Native Task") }
            try require(ledger == prefix && refused.work == prefix && refused.derivativeCalls == 0,"Actual Task preserves known consumed prefix")
        }
    }
}
