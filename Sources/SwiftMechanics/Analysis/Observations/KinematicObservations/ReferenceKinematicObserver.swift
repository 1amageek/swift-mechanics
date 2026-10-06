
public struct ReferenceKinematicObserver: KinematicObserving {
    private let composer:any FrameMotionComposing
    /// Injected successes are admitted only when their full motion is exactly reference-equivalent.
    public init(composer:any FrameMotionComposing = FrameMotionComposer()) { self.composer=composer }
    @inline(never)
    public func motion(source:ObservationSource,mount:ObservationMount,policy:ObservationPolicy,work:inout NumericalWork) throws(ObservationError) -> MountedMotionObservation {
        try ObservationArithmetic.admit(source,policy:policy,work:&work)
        try ObservationArithmetic.metadata([mount.sensor.key,mount.body.key,mount.sensorFrame.key],policy:policy,work:&work)
        guard mount.sensorFrame != source.snapshot.tree.worldFrame,
              !source.snapshot.frames.contains(where:{$0.frame == mount.sensorFrame}) else { throw .invalidMounting }
        let body:BodyKinematics
        do throws(JointError) { body=try source.snapshot.body(mount.body) } catch { throw .unknownIdentity }
        try ObservationArithmetic.numerical { () throws(NumericalError) in try work.chargeOperations(1) }
        let result:FrameMotion
        do { result=try composer.composed(parent:body.motion,relative:.stationary(pose:mount.sensorToBody)) }
        catch { throw .frameSupplierFailure }
        try ObservationArithmetic.check(policy)
        try ObservationArithmetic.numerical { () throws(NumericalError) in try work.chargeOperations(1) }
        let original:FrameMotion
        do { original=try FrameMotionComposer().composed(parent:body.motion,relative:.stationary(pose:mount.sensorToBody)) }
        catch { throw .frameSupplierFailure }
        try ObservationArithmetic.motion(result,original:original,policy:policy,work:&work)
        return MountedMotionObservation(header:ObservationHeader(source:source,mount:mount,frame:source.snapshot.tree.worldFrame),motion:result)
    }
    public func encoder(source:ObservationSource,joint:EntityID,policy:ObservationPolicy,work:inout NumericalWork) throws(ObservationError) -> JointEncoderObservation {
        try ObservationArithmetic.admit(source,policy:policy,work:&work)
        try ObservationArithmetic.metadata([joint.key],policy:policy,work:&work)
        guard joint.kind == .joint,
              let record=source.snapshot.tree.joints.first(where:{$0.id == joint}),
              let layout=source.snapshot.tree.layout.joints.first(where:{$0.joint == joint}) else { throw .unknownIdentity }
        let q=layout.positions.count,v=layout.velocities.count
        try ObservationArithmetic.numerical { () throws(NumericalError) in
            try work.requireStorage(try NumericalWork.product(8,try NumericalWork.sum(q,v)))
            try work.chargeOperations(try NumericalWork.sum(q,v))
        }
        var positionUnits:[PhysicalDimension]=[],velocityUnits:[PhysicalDimension]=[]
        let convention:JointEncoderObservation.VelocityConvention
        switch record.manifold.kind {
        case .spherical:
            positionUnits=[PhysicalDimension](repeating:.dimensionless,count:4)
            velocityUnits=[PhysicalDimension](repeating:PhysicalDimension(time:-1,angle:1),count:3);convention = .bodyAngular
        case .sixDOF:
            positionUnits=[.length,.length,.length,.dimensionless,.dimensionless,.dimensionless,.dimensionless]
            velocityUnits=[.velocity,.velocity,.velocity,PhysicalDimension(time:-1,angle:1),PhysicalDimension(time:-1,angle:1),PhysicalDimension(time:-1,angle:1)]
            convention = .parentLinearAndBodyAngular
        default:
            for axis in record.manifold.orderedAxes {
                let dimension:PhysicalDimension = axis.kind == .prismatic ? .length : .angle
                positionUnits.append(dimension)
                velocityUnits.append(PhysicalDimension(length:dimension.length,time:-1,angle:dimension.angle))
            }
            convention = .orderedAxisRates
        }
        guard positionUnits.count == q,velocityUnits.count == v else { throw .unsupportedChart }
        let rates=positionUnits.map { PhysicalDimension(length:$0.length,time:-1,angle:$0.angle) }
        let accelerationUnits=velocityUnits.map { PhysicalDimension(length:$0.length,time:-2,angle:$0.angle) }
        try ObservationArithmetic.check(policy)
        return JointEncoderObservation(model:source.model.stamp,timeSeconds:source.state.state.time,joint:joint,parentAnchorFrame:record.parentAnchor.frame,
            positions:Array(source.state.state.q[layout.positions.range]),coordinateRates:Array(source.snapshot.coordinateRate[layout.positions.range]),
            velocities:Array(source.state.state.v[layout.velocities.range]),accelerations:Array(source.state.state.acceleration[layout.velocities.range]),
            positionUnits:positionUnits,coordinateRateUnits:rates,velocityUnits:velocityUnits,accelerationUnits:accelerationUnits,
            velocityConvention:convention,accelerationAuthority:source.accelerationAuthority)
    }
}
