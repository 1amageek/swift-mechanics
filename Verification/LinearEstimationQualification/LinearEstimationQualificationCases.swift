import SwiftMechanics

public enum LinearEstimationQualificationCases {
    private typealias F = LinearEstimationQualificationFixtures
    public static func scalarPredictionInnovationAndJoseph() throws {
        let service: any LinearEstimating = ReferenceLinearEstimator()
        let model = try F.model(), initial = try F.initial(model), policy = try F.policy()
        var work = try F.work()
        let predicted = try service.predict(initial,input:F.input(initial),policy:policy,work:&work)
        try F.require(predicted.tick==1 && predicted.timeSeconds==2.5 && !predicted.sampleResolved,"One original prediction tick")
        try F.near(predicted.mean[0],8,"Independent scalar predicted mean")
        try F.matrix(predicted.covariance,[9],"Independent scalar predicted covariance")
        let update = try service.update(predicted,observation:F.reading(predicted),missing:.fail,policy:policy,work:&work)
        guard let innovation=update.innovation, let gain=update.gain, let s=update.innovationCovariance else {
            throw LinearEstimationQualificationError.assertion("Observed update requires original innovation and solve values")
        }
        try F.near(innovation[0],2,"Independent scalar innovation")
        try F.matrix(s,[13],"Independent scalar innovation covariance")
        try F.matrix(gain,[9.0/13],"Independent scalar Kalman gain")
        try F.near(update.state.mean[0],122.0/13,"Independent scalar posterior mean")
        try F.matrix(update.state.covariance,[36.0/13],"Independent scalar Joseph covariance")
        try F.require(update.state.sampleResolved && !update.missingObservation && update.state.lastObservationSequence==7 &&
            update.state.lastObservationTimeSeconds==2.5,"Original observed slot resolution")
        try diagnostics(update,count:1,reservationDimension:1)
        try F.near(initial.mean[0],1,"Original immutable initial mean")
        try F.matrix(initial.covariance,[2],"Original immutable initial covariance")
        try F.require(work.operations>0 && work.iterations==1 && work.peakScalarStorage>=329,"Cumulative original scalar reservations")
    }
    public static func coupledStatesAndMeasurements() throws {
        let service: any LinearEstimating = ReferenceLinearEstimator(), policy = try F.policy()
        let model = try F.model(n:2,a:[1,1,0,1],b:[0.5,1],h:[1,0],q:[0.25,0,0,0.5],r:[2])
        let initial = try F.initial(model,mean:[1,2],p:[4,1,1,3])
        var work = try F.work()
        let predicted = try service.predict(initial,input:F.input(initial),policy:policy,work:&work)
        try F.near(predicted.mean[0],4,"Independent position prediction")
        try F.near(predicted.mean[1],4,"Independent rate prediction")
        try F.matrix(predicted.covariance,[37.0/4,4,4,7.0/2],"Independent transported coupled covariance")
        let update = try service.update(predicted,observation:F.reading(predicted,values:[9]),missing:.fail,policy:policy,work:&work)
        guard let gain=update.gain, let s=update.innovationCovariance, let innovation=update.innovation else {
            throw LinearEstimationQualificationError.assertion("Coupled update values missing")
        }
        try F.matrix(gain,[37.0/45,16.0/45],"Independent two-state gain")
        try F.matrix(s,[45.0/4],"Independent scalar innovation covariance of two states")
        try F.near(innovation[0],5,"Independent two-state innovation")
        try F.near(update.state.mean[0],73.0/9,"Independent coupled posterior position")
        try F.near(update.state.mean[1],52.0/9,"Independent coupled posterior rate")
        try F.matrix(update.state.covariance,[74.0/45,32.0/45,32.0/45,187.0/90],"Independent full Joseph covariance")
        let p00=try update.state.covariance.coefficient(row:0,column:0),p01=try update.state.covariance.coefficient(row:0,column:1)
        let p10=try update.state.covariance.coefficient(row:1,column:0),p11=try update.state.covariance.coefficient(row:1,column:1)
        try F.require(p01==p10 && p00>0 && p11>0,"Joseph symmetry and positive diagonal")
        try F.near(p00*p11-p01*p10,131.0/45,"Independent positive Joseph determinant")
        try diagnostics(update,count:2,reservationDimension:1)
        let observedModel = try F.model(n:2,m:2,a:[1,0,0,1],b:[0,0],h:[1,0,0,1],q:[0,0,0,0],r:[1,0.5,0.5,2])
        let observedInitial = try F.initial(observedModel,mean:[0,0],p:[2,0.25,0.25,1])
        let observedPrediction = try F.predicted(observedInitial,values:[0])
        let joint = try service.update(observedPrediction,observation:F.reading(observedPrediction,values:[3,-1]),missing:.fail,policy:policy,work:&work)
        guard let jointGain=joint.gain, let jointS=joint.innovationCovariance else {
            throw LinearEstimationQualificationError.assertion("Coupled measurement solves missing")
        }
        try F.matrix(jointS,[3,0.75,0.75,3],"Independent coupled measurement covariance")
        try F.matrix(jointGain,[31.0/45,-4.0/45,0,1.0/3],"Independent coupled measurement gain")
        try F.near(joint.state.mean[0],97.0/45,"Independent coupled measurement posterior first state")
        try F.near(joint.state.mean[1],-1.0/3,"Independent coupled measurement posterior second state")
        try F.matrix(joint.state.covariance,[29.0/45,1.0/6,1.0/6,2.0/3],"Independent coupled measurement Joseph covariance")
        try diagnostics(joint,count:2,reservationDimension:2)
    }
    public static func observabilityAndCovarianceAdmission() throws {
        let service: any LinearEstimating = ReferenceLinearEstimator(), policy = try F.policy()
        let zeroModel = try F.model(q:[0]), zero = try F.initial(zeroModel,mean:[1],p:[0])
        let predicted = try F.predicted(zero)
        var work = try F.work()
        let update = try service.update(predicted,observation:F.reading(predicted),missing:.fail,policy:policy,work:&work)
        try F.matrix(update.state.covariance,[0],"Zero PSD covariance is admitted without artificial noise")
        try F.near(update.state.mean[0],8,"Zero covariance does not assimilate uncertain reading")
        try modelFailure(.unobservable(rank:1)) { _ = try F.model(n:2,a:[1,0,0,1],b:[0,1],h:[1,0],q:[0,0,0,0],r:[1]) }
        try modelFailure(.invalidCovariance(pivot:1)) { _ = try F.model(n:2,a:[1,1,0,1],b:[0,1],h:[1,0],q:[1,2,2,1],r:[1]) }
        try modelFailure(.invalidCovariance(pivot:1)) { _ = try F.model(n:2,a:[1,1,0,1],b:[0,1],h:[1,0],q:[1,0.1,0.2,1],r:[1]) }
        try modelFailure(.invalidCovariance(pivot:0)) { _ = try F.model(n:2,a:[1,1,0,1],b:[0,1],h:[1,0],q:[0,1,1,1],r:[1]) }
        try modelFailure(.invalidCovariance(pivot:0)) { _ = try F.model(r:[0]) }
        try modelFailure(.capacity) { _ = try F.model(n:2,a:[1,1,0,1],b:[0,1],h:[1,0],q:[1,0,0,1],r:[1],admittedPolicy:F.policy(stateCount:1)) }
        try modelFailure(.capacity) { _ = try F.model(admittedPolicy:F.policy(metadata:2)) }
        try modelFailure(.invalidModel) { _ = try F.model(admittedPolicy:F.policy(magnitude:1)) }
        let model = try F.model(), bad = try DenseMatrix<Double>(rows:1,columns:1,values:[-1])
        let failure = try F.failure { () throws(LinearEstimatorFailure) in
            _ = try service.initialize(model:model,mean:[1],covariance:bad,policy:policy,work:&work)
        }
        try F.require(failure.cause == .invalidCovariance(pivot:0) && failure.prefix==nil && failure.admittedWork==work,"Rejected initial covariance has exact setup ledger")
    }
    public static func clockMissingAndSourceRefusals() throws {
        let service: any LinearEstimating = ReferenceLinearEstimator(), policy = try F.policy()
        let initial = try F.initial(F.model()), predicted = try F.predicted(initial)
        var work = try F.work()
        let missing = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.update(predicted,observation:nil,missing:.fail,policy:policy,work:&work) }
        try F.prefix(missing,predicted,work:work,cause:.missingObservation)
        let retain = try service.update(predicted,observation:nil,missing:.retainPrediction,policy:policy,work:&work)
        try F.require(retain.missingObservation && retain.innovation==nil && retain.gain==nil && retain.innovationCovariance==nil &&
            retain.supplierSolveDiagnostics.isEmpty && retain.state.sampleResolved && retain.state.lastObservationSequence==nil,"Missing slot resolution explicitly retains no old reading")
        try F.matrix(retain.state.covariance,[9],"Missing slot preserves original covariance")
        try F.near(retain.state.mean[0],8,"Missing slot preserves original mean")
        let unresolved = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.predict(predicted,input:F.input(predicted),policy:policy,work:&work) }
        try F.prefix(unresolved,predicted,work:work,cause:.unresolvedSample)
        let observed = try service.update(predicted,observation:F.reading(predicted),missing:.fail,policy:policy,work:&work).state
        let duplicateSlot = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.update(observed,observation:F.reading(observed),missing:.fail,policy:policy,work:&work) }
        try F.prefix(duplicateSlot,observed,work:work,cause:.unresolvedSample)
        let next = try F.predicted(observed)
        let stale = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.update(next,observation:F.reading(next,sequence:8,sample:2.5),missing:.fail,policy:policy,work:&work) }
        try F.prefix(stale,next,work:work,cause:.delayedObservation)
        let future = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.update(next,observation:F.reading(next,sequence:8,sample:3.5),missing:.fail,policy:policy,work:&work) }
        try F.prefix(future,next,work:work,cause:.timingMismatch)
        let late = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.update(next,observation:F.reading(next,sequence:8,delivery:3.1),missing:.fail,policy:policy,work:&work) }
        try F.prefix(late,next,work:work,cause:.delayedObservation)
        let order = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.update(next,observation:F.reading(next,sequence:7),missing:.fail,policy:policy,work:&work) }
        try F.prefix(order,next,work:work,cause:.outOfOrderObservation)
        let foreign = ModelStamp(identity:next.model.source.identity,revision:18)
        let source = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.update(next,observation:F.reading(next,sequence:8,source:foreign),missing:.fail,policy:policy,work:&work) }
        try F.prefix(source,next,work:work,cause:.sourceMismatch)
        let wrongScale = LinearEstimatorCoordinate(identity:"z",frame:"world",dimension:.dimensionless,normalizationSI:2)
        let layout = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.update(next,observation:F.reading(next,sequence:8,coordinates:[wrongScale]),missing:.fail,policy:policy,work:&work) }
        try F.prefix(layout,next,work:work,cause:.sourceMismatch)
        let revision = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.predict(initial,input:F.input(initial,revision:20),policy:policy,work:&work) }
        try F.prefix(revision,initial,work:work,cause:.sourceMismatch)
        let interval = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.predict(initial,input:F.input(initial,end:2.75),policy:policy,work:&work) }
        try F.prefix(interval,initial,work:work,cause:.timingMismatch)
        let invalid = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.update(next,observation:F.reading(next,values:[.nan],sequence:8),missing:.fail,policy:policy,work:&work) }
        try F.prefix(invalid,next,work:work,cause:.invalidInput)
        try modelFailure(.timingMismatch) { _ = try F.model(clock:LinearEstimatorClock(epochSeconds:2,periodSeconds:0.5,maximumTick:UInt64.max)) }
        try modelFailure(.invalidModel) { _ = try F.model(clock:LinearEstimatorClock(epochSeconds:2,periodSeconds:0,maximumTick:10)) }
        let terminalModel = try F.model(clock:LinearEstimatorClock(epochSeconds:2,periodSeconds:0.5,maximumTick:1))
        let terminal = try F.predicted(F.initial(terminalModel))
        let resolved = try service.update(terminal,observation:nil,missing:.retainPrediction,policy:policy,work:&work).state
        let beyond = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.predict(resolved,input:F.input(resolved),policy:policy,work:&work) }
        try F.prefix(beyond,resolved,work:work,cause:.timingMismatch)
        let good = try service.update(next,observation:F.reading(next,sequence:8),missing:.fail,policy:policy,work:&work)
        try F.require(good.state.sampleResolved && good.state.lastObservationSequence==8,"All failed trials leave original prefix reusable")
    }
    public static func continuationBitsAndRefusals() throws {
        let codec: any LinearEstimatorContinuationCoding = ReferenceLinearEstimatorContinuationCodec()
        let service: any LinearEstimating = ReferenceLinearEstimator(), policy = try F.policy()
        let model = try F.model(), original = try F.initial(model,mean:[-0.0])
        var work = try F.work()
        let schema = try codec.schema(model:model,policy:policy,work:&work), record = try codec.record(original,policy:policy,work:&work)
        try F.require(schema.id=="mechanics.linearEstimator.kf" && schema.category == .controller && schema.version==1 &&
            schema.maximumBytes==447 && record.bytes.count==447,"Independent complete scalar contributor size and identity")
        let words: [UInt64] = [0,Double(2).bitPattern,1,0,0,0,Double(-0.0).bitPattern,Double(2).bitPattern]
        try F.require(Array(record.bytes.suffix(64))==littleEndian(words),"Independent original scalar state payload bits")
        let restored = try codec.restore(record,model:model,policy:policy,work:&work)
        try F.sameState(restored,original)
        let repeated = try codec.record(restored,policy:policy,work:&work)
        try F.require(record==repeated,"Bit-exact original continuation replay")
        let predicted = try F.predicted(original), checkpoint = try codec.record(predicted,policy:policy,work:&work)
        let pending = try codec.restore(checkpoint,model:model,policy:policy,work:&work)
        try F.sameState(pending,predicted)
        let resumed = try service.update(pending,observation:F.reading(pending),missing:.fail,policy:policy,work:&work).state
        let uninterrupted = try service.update(predicted,observation:F.reading(predicted),missing:.fail,policy:policy,work:&work).state
        try F.sameState(resumed,uninterrupted)
        var corrupt = record.bytes;corrupt[0]=2
        let bad = try RuntimeContributorState(id:record.id,category:record.category,version:record.version,bytes:corrupt)
        let failure = try F.failure { () throws(LinearEstimatorFailure) in _ = try codec.restore(bad,model:model,policy:policy,work:&work) }
        try F.require(failure.cause == .corruptContinuation && failure.prefix==nil && failure.admittedWork==work,"Corrupt model prefix cannot publish restored state")
        let changed = try F.model(revision:20)
        let stale = try F.failure { () throws(LinearEstimatorFailure) in _ = try codec.restore(record,model:changed,policy:policy,work:&work) }
        try F.require(stale.cause == .corruptContinuation && stale.prefix==nil && stale.admittedWork==work,"Stale filter revision is not restored")
        let changedPolicy = try F.policy(covariance:1e-10)
        let configuration = try F.failure { () throws(LinearEstimatorFailure) in _ = try codec.restore(record,model:model,policy:changedPolicy,work:&work) }
        try F.require(configuration.cause == .corruptContinuation && configuration.prefix==nil && configuration.admittedWork==work,"Original complete policy prefix is required")
        let wrongCategory = try RuntimeContributorState(id:record.id,category:.actuator,version:1,bytes:record.bytes)
        let category = try F.failure { () throws(LinearEstimatorFailure) in _ = try codec.restore(wrongCategory,model:model,policy:policy,work:&work) }
        try F.require(category.cause == .corruptContinuation && category.prefix==nil && category.admittedWork==work,"Contributor category is authoritative")
        var invalidTime = record.bytes
        let offset = invalidTime.count-64
        let badTick = littleEndian([UInt64(11)])
        for i in 0..<8 { invalidTime[offset+i]=badTick[i] }
        let badState = try RuntimeContributorState(id:record.id,category:record.category,version:1,bytes:invalidTime)
        let temporal = try F.failure { () throws(LinearEstimatorFailure) in _ = try codec.restore(badState,model:model,policy:policy,work:&work) }
        try F.require(temporal.cause == .timingMismatch && temporal.prefix==nil && temporal.admittedWork==work,"Decoded tick beyond original clock is explicitly refused")
    }
    public static func budgetsAndCallbackCancellation() throws {
        let service: any LinearEstimating = ReferenceLinearEstimator(), policy = try F.policy()
        let initial = try F.initial(F.model()), predicted = try F.predicted(initial)
        var small = try F.work(operations:5);try small.chargeOperations(2)
        let limit = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.predict(initial,input:F.input(initial),policy:policy,work:&small) }
        try F.prefix(limit,initial,work:small,cause:.numerical(.resourceLimit(resource:.arithmeticOperations,limit:5)))
        try F.require(small.operations==5 && small.peakScalarStorage==320,"Arithmetic refusal retains actual charged prefix")
        var storage = try F.work(storage:319);try storage.chargeOperations(7)
        let envelope = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.predict(initial,input:F.input(initial),policy:policy,work:&storage) }
        try F.prefix(envelope,initial,work:storage,cause:.numerical(.resourceLimit(resource:.scalarStorage,limit:319)))
        try F.require(storage.operations==7 && storage.peakScalarStorage==0,"Failed envelope does not publish reserved storage")
        var solverStorage = try F.work(storage:320)
        let nested = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.update(predicted,observation:F.reading(predicted),missing:.fail,policy:policy,work:&solverStorage) }
        try F.prefix(nested,predicted,work:solverStorage,cause:.numerical(.resourceLimit(resource:.scalarStorage,limit:320)))
        try F.require(solverStorage.peakScalarStorage==320 && solverStorage.iterations==0 && solverStorage.operations>0,"Nested storage refusal retains known original work")
        var iterations = try F.work(iterations:0)
        let iteration = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.update(predicted,observation:F.reading(predicted),missing:.fail,policy:policy,work:&iterations) }
        try F.prefix(iteration,predicted,work:iterations,cause:.numerical(.resourceLimit(resource:.iterations,limit:0)))
        try F.require(iterations.operations>=40 && iterations.iterations==0 && iterations.peakScalarStorage==329,"Nested iteration refusal retains admitted solver reservation")
        var cancelled = try F.work();try cancelled.chargeOperations(7)
        let before = cancelled, cancellationPolicy = try F.policy(cancelled:{ true })
        let failure = try F.failure { () throws(LinearEstimatorFailure) in _ = try service.predict(initial,input:F.input(initial),policy:cancellationPolicy,work:&cancelled) }
        try F.prefix(failure,initial,work:cancelled,cause:.cancelled)
        try F.require(cancelled==before,"Callback cancellation before reservation preserves seeded ledger")
        let codec: any LinearEstimatorContinuationCoding = ReferenceLinearEstimatorContinuationCodec()
        let bytePolicy = try F.policy(bytes:1)
        var bytes = try F.work()
        let byteLimit = try F.failure { () throws(LinearEstimatorFailure) in _ = try codec.record(initial,policy:bytePolicy,work:&bytes) }
        try F.prefix(byteLimit,initial,work:bytes,cause:.capacity)
        let retry = try F.predicted(initial)
        try F.near(retry.mean[0],8,"Budget/cancellation failures preserve reusable original state")
    }
    public static func failedSupplierReservationAndPrefix() throws {
        let service: any LinearEstimating = ReferenceLinearEstimator()
        let policy = try F.policy(magnitude:1e308,covariance:0,rank:1e-310,pivot:0)
        let model = try F.model(a:[1],b:[1],h:[1e-309],q:[0],r:[1e-320],admittedPolicy:policy)
        let initial = try F.initial(model,mean:[0],p:[1e308],admittedPolicy:policy)
        let predicted = try F.predicted(initial,values:[0],admittedPolicy:policy)
        var work = try F.work();try work.chargeOperations(11)
        let failure = try F.failure { () throws(LinearEstimatorFailure) in
            _ = try service.update(predicted,observation:F.reading(predicted,values:[0]),missing:.fail,policy:policy,work:&work)
        }
        try F.prefix(failure,predicted,work:work,cause:.failedSupplierWorkUnavailable(.nonFiniteResult))
        try F.require(work.operations>=51 && work.iterations==1 && work.peakScalarStorage==329,"Failed original Cholesky retains nonzero admitted reservation")
        try F.near(predicted.mean[0],0,"Failed gain cannot publish candidate mean")
        let p=try predicted.covariance.coefficient(row:0,column:0)
        try F.require(p.bitPattern==Double(1e308).bitPattern && !predicted.sampleResolved,"Failed gain cannot publish covariance or resolved slot")
    }
    private static func diagnostics(_ update: LinearEstimatorUpdate, count: Int, reservationDimension: Int) throws {
        try F.require(update.supplierSolveDiagnostics.count==count,"Every original gain-row solve retains actual diagnostics")
        let n=reservationDimension, reserved=8*n*n*n+16*n*n+16*n
        for d in update.supplierSolveDiagnostics {
            try F.require(d.capability.algorithm == .cholesky && d.originalResidual.isAccepted && d.work.operations>0 &&
                d.work.operations<=reserved && d.work.iterations==n && d.work.peakScalarStorage==3*n*n+6*n,"Original SPD solve residual and actual work are independently retained")
        }
    }
    private static func modelFailure(_ expected: LinearEstimatorError, _ operation: () throws -> Void) throws {
        let failure: LinearEstimatorFailure
        do { try operation();throw LinearEstimationQualificationError.assertion("Expected model admission refusal") }
        catch let error as LinearEstimatorFailure { failure=error }
        try F.require(failure.cause==expected && failure.prefix==nil && failure.admittedWork.operations>=0,"Original setup failure and admitted prefix")
    }
    private static func littleEndian(_ words: [UInt64]) -> [UInt8] {
        var bytes: [UInt8]=[]
        for word in words { for shift in stride(from:0,to:64,by:8) { bytes.append(UInt8(truncatingIfNeeded:word>>shift)) } }
        return bytes
    }
}
