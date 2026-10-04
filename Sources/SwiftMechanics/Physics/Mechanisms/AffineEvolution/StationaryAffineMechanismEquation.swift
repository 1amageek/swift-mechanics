@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class StationaryAffineMechanismEquation:SmoothODEEquations,StationaryAffineMotionComputing,Sendable {
    public let descriptor:ODEDescriptor
    public let base:AffineMechanismEquation
    public let catalog:StationaryLoadCatalog
    public let selection:StationaryLoadSelection
    private let execution:any StationaryLoadExecuting
    public init(base:AffineMechanismEquation,catalog:StationaryLoadCatalog,selection:StationaryLoadSelection,execution:any StationaryLoadExecuting,maximumIdentityBytes:Int) throws(RuntimeFailure) {
        self.base=base;self.catalog=catalog;self.selection=selection;self.execution=execution
        do throws(StationaryLoadError) { try catalog.validate(model:base.model,layout:base.constraints.layout);_=try catalog.program(selection) }
        catch { throw error.runtimeFailure }
        let source:[UInt8]
        do throws(StationaryLoadError) { source=try catalog.physicalSignature(model:base.model,policy:base.policy,admission:base.admission,drive:base.drive,maximumBytes:maximumIdentityBytes) }
        catch { throw error.runtimeFailure }
        // Hex encoding is bounded before materialization; exact bytes, no lossy hash or description.
        let required:Int
        do { required=try NumericalWork.sum(base.descriptor.chart.utf8.count,try NumericalWork.sum(32,try NumericalWork.product(2,try NumericalWork.sum(source.count,catalog.signature.count)))) }
        catch { throw RuntimeFailure(.capacityExceeded,message:"Loaded chart byte count overflow.") }
        guard required <= maximumIdentityBytes else { throw RuntimeFailure(.capacityExceeded,message:"Loaded chart metadata capacity exhausted.") }
        var chart=base.descriptor.chart+":stationary-loaded-v1:"
        let hex=Array("0123456789abcdef".utf8)
        var bytes:[UInt8]=[];bytes.reserveCapacity(required)
        bytes.append(contentsOf:chart.utf8)
        for stream in [source,catalog.signature] { for byte in stream { bytes.append(hex[Int(byte >> 4)]);bytes.append(hex[Int(byte & 15)]) };bytes.append(58) }
        chart=String(decoding:bytes,as:UTF8.self)
        do { descriptor=try ODEDescriptor(identity:base.descriptor.identity,chart:chart,model:base.model.stamp,dimensions:base.descriptor.dimensions,maximumIdentityBytes:maximumIdentityBytes,maximumCoordinates:base.descriptor.dimensions.count) }
        catch { throw RuntimeFailure(.invalidInput,message:"Loaded equation descriptor admission failed.") }
    }
    public func validate(model:CompiledMechanicalModel) throws(RuntimeFailure) { try base.validate(model:model) }
    public func read(_ state:KinematicState,into point:inout [Double]) throws(RuntimeFailure) { try base.read(state,into:&point) }
    public func read(_ trial:RuntimeTrial,into point:inout [Double]) throws(RuntimeFailure) { try base.read(trial,into:&point) }
    public func prepare(trial:inout RuntimeTrial,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units:1);_=try base.reserve(work:&work)
        var point=[Double](repeating:0,count:descriptor.dimensions.count);try base.read(trial,into:&point)
        _=try base.checkedSample(time:trial.timeSeconds,point:point,work:&work,control:nil)
    }
    public func derivative(time:Double,point:[Double],into output:inout [Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units:1)
        let n=base.model.tree.layout.velocityCount
        guard point.count == 2*n,output.count == point.count else { throw RuntimeFailure(.invalidState,message:"Loaded derivative shape differs.") }
        do throws(NumericalError) { try work.requireStorage(try NumericalWork.product(3,n));try work.chargeOperations(try NumericalWork.product(3,n)) }
        catch { throw RuntimeFailure(.capacityExceeded,message:"Loaded stage source-copy capacity exhausted.") }
        let physical:KinematicState
        do { physical=try KinematicState(revision:base.model.stamp.revision,time:time,q:Array(point[..<n]),v:Array(point[n...]),acceleration:[Double](repeating:0,count:n)) }
        catch { throw RuntimeFailure(.invalidState,message:"Loaded stage state is invalid.") }
        let result=try loadedMotion(physical:physical,selection:selection,execution:execution,work:&work)
        for i in 0..<n { output[i]=point[n+i];output[n+i]=result.motion.values[i] }
    }
    @inline(never)
    public func loadedMotion(physical:KinematicState,selection:StationaryLoadSelection,execution:any StationaryLoadExecuting,work:inout NumericalWork) throws(RuntimeFailure) -> StationaryAffineMotion {
        try base.stationaryMotion(physical:physical,catalog:catalog,selection:selection,execution:execution,work:&work)
    }
    @inline(never)
    public func loadedMotion(physical:KinematicState,selection:StationaryLoadSelection,drive:[Double],execution:any StationaryLoadExecuting,work:inout NumericalWork) throws(RuntimeFailure) -> StationaryAffineMotion {
        try base.stationaryMotion(physical:physical,catalog:catalog,selection:selection,execution:execution,work:&work,driveOverride:drive)
    }
    public func write(point:[Double],derivative:[Double],time:Double,trial:inout RuntimeTrial) throws(RuntimeFailure) { try base.write(point:point,derivative:derivative,time:time,trial:&trial) }
}
