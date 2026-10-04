
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct NativeRuntimeCheckpointCodec: RuntimeCheckpointCoding, Sendable {
    public init() {}
    private func checksum(_ bytes: ArraySlice<UInt8>) -> UInt64 {
        var value: UInt64 = 0xcbf29ce484222325
        for byte in bytes { value = (value ^ UInt64(byte)) &* 0x100000001b3 }; return value
    }
    public func encode(_ checkpoint: RuntimeCheckpoint, capacity: RuntimeCapacity) throws(RuntimeFailure) -> [UInt8] {
        let scalars = try RuntimeCounts.physical(state: checkpoint.physical)
        guard scalars <= capacity.maximumPhysicalScalars, checkpoint.physical.acceleration.count == checkpoint.physical.v.count,
              checkpoint.contributors.count <= capacity.maximumContributors else { throw RuntimeFailure(.capacityExceeded, message: "Checkpoint scalar/record capacity exceeded.") }
        var metadata = 0, estimated = 8 + 8 + 24 + 8 + 24 + 8
        for text in [checkpoint.model.identity, checkpoint.continuation.build, checkpoint.continuation.backend, checkpoint.continuation.precision] {
            metadata = try RuntimeCounts.sum(metadata, text.utf8.count); estimated = try RuntimeCounts.sum(estimated, try RuntimeCounts.sum(8, text.utf8.count))
        }
        if !checkpoint.physical.prescribedAnchors.isEmpty {
            estimated = try RuntimeCounts.sum(estimated, 8)
            for sample in checkpoint.physical.prescribedAnchors {
                metadata = try RuntimeCounts.sum(metadata, sample.frame.key.utf8.count)
                estimated = try RuntimeCounts.sum(estimated, try RuntimeCounts.sum(8, sample.frame.key.utf8.count))
            }
        }
        let (scalarBytes, overflow) = scalars.multipliedReportingOverflow(by: 8)
        guard !overflow else { throw RuntimeFailure(.integerOverflow, message: "Checkpoint scalar bytes overflow.") }
        estimated = try RuntimeCounts.sum(estimated, scalarBytes)
        var payloadCount = 0
        for record in checkpoint.contributors {
            metadata = try RuntimeCounts.sum(metadata, record.id.utf8.count)
            payloadCount = try RuntimeCounts.sum(payloadCount, record.bytes.count)
            estimated = try RuntimeCounts.sum(estimated, try RuntimeCounts.sum(25, try RuntimeCounts.sum(record.id.utf8.count, record.bytes.count)))
        }
        let total = try RuntimeCounts.sum(estimated, 28)
        guard metadata <= capacity.maximumMetadataBytes, payloadCount <= capacity.maximumContributorBytes, total <= capacity.maximumCheckpointBytes else { throw RuntimeFailure(.capacityExceeded, message: "Checkpoint metadata/payload/envelope exceeds capacity.") }
        var payload = RuntimeByteWriter(maximum: capacity.maximumCheckpointBytes - 28, reservation: estimated)
        try payload.string(checkpoint.model.identity); try payload.integer(checkpoint.model.revision)
        try payload.string(checkpoint.continuation.build); try payload.string(checkpoint.continuation.backend); try payload.string(checkpoint.continuation.precision)
        try payload.integer(checkpoint.acceptedSteps); try payload.integer(checkpoint.random.seed); try payload.integer(checkpoint.random.state); try payload.integer(checkpoint.random.draws)
        try payload.integer(checkpoint.physical.time.bitPattern)
        try payload.doubles(checkpoint.physical.q); try payload.doubles(checkpoint.physical.v); try payload.doubles(checkpoint.physical.acceleration)
        if !checkpoint.physical.prescribedAnchors.isEmpty {
            try payload.integer(UInt64(checkpoint.physical.prescribedAnchors.count))
            for sample in checkpoint.physical.prescribedAnchors { try write(sample, to: &payload) }
        }
        try payload.integer(UInt64(checkpoint.contributors.count))
        for record in checkpoint.contributors {
            try payload.string(record.id); try payload.append(record.category.rawValue); try payload.integer(record.version)
            try payload.integer(UInt64(record.bytes.count)); for byte in record.bytes { try payload.append(byte) }
        }
        var writer = RuntimeByteWriter(maximum: capacity.maximumCheckpointBytes, reservation: payload.bytes.count + 28)
        for byte: UInt8 in [83,77,82,84] { try writer.append(byte) }
        try writer.integer(checkpoint.physical.prescribedAnchors.isEmpty ? 1 : 2); try writer.integer(UInt64(payload.bytes.count)); try writer.integer(checksum(payload.bytes[...]))
        for byte in payload.bytes { try writer.append(byte) }; return writer.bytes
    }
    public func decode(_ bytes: [UInt8], capacity: RuntimeCapacity) throws(RuntimeFailure) -> RuntimeCheckpoint {
        guard bytes.count <= capacity.maximumCheckpointBytes else { throw RuntimeFailure(.capacityExceeded, message: "Native checkpoint exceeds byte capacity.") }
        guard bytes.count >= 28 else { throw RuntimeFailure(.truncatedCheckpoint, message: "Checkpoint envelope is truncated.") }
        var reader = RuntimeByteReader(bytes: bytes[...], capacity: capacity)
        for byte: UInt8 in [83,77,82,84] { guard try reader.byte() == byte else { throw RuntimeFailure(.corruptCheckpoint, message: "Checkpoint magic is invalid.") } }
        let version = try reader.integer()
        guard version == 1 || version == 2 else { throw RuntimeFailure(.incompatibleContinuation, message: "Native checkpoint format version is unsupported.") }
        let length = try reader.count(maximum: capacity.maximumCheckpointBytes), expected = try reader.integer()
        guard length == reader.remaining else { throw RuntimeFailure(length > reader.remaining ? .truncatedCheckpoint : .corruptCheckpoint, message: "Envelope length does not match bytes.") }
        guard checksum(bytes[28...]) == expected else { throw RuntimeFailure(.corruptCheckpoint, message: "Checkpoint integrity checksum failed.") }
        let identity = try reader.string(), revision = try reader.integer()
        let continuation = try RuntimeContinuationIdentity(build: reader.string(), backend: reader.string(), precision: reader.string())
        let accepted = try reader.integer(), seed = try reader.integer(), state = try reader.integer(), draws = try reader.integer()
        let time = Double(bitPattern: try reader.integer())
        guard time.isFinite else { throw RuntimeFailure(.corruptCheckpoint, message: "Checkpoint time is nonfinite.") }
        let q = try reader.doubles(), v = try reader.doubles(), acceleration = try reader.doubles()
        var anchors: [PrescribedAnchorState] = []
        if version == 2 {
            let anchorCount = try reader.count(maximum: capacity.maximumPhysicalScalars / 20)
            guard anchorCount > 0 else { throw RuntimeFailure(.corruptCheckpoint, message: "Checkpoint v2 requires prescribed samples.") }
            try reader.reserveScalars(RuntimeCounts.product(anchorCount, 20))
            // Each anchor needs its string length field and twenty scalars before allocation.
            guard anchorCount <= reader.remaining / 168 else { throw RuntimeFailure(.truncatedCheckpoint, message: "Prescribed sample fields are truncated.") }
            anchors.reserveCapacity(anchorCount)
            for _ in 0..<anchorCount {
                let sample = try readAnchor(from: &reader)
                guard !anchors.contains(where: { $0.frame == sample.frame }) else { throw RuntimeFailure(.corruptCheckpoint, message: "Prescribed frame is duplicated.") }
                anchors.append(sample)
            }
        }
        let count = try reader.count(maximum: capacity.maximumContributors)
        var records: [RuntimeContributorState] = []; records.reserveCapacity(count)
        for _ in 0..<count {
            let id = try reader.string(), tag = try reader.byte()
            guard let category = RuntimeContributorCategory(rawValue: tag) else { throw RuntimeFailure(.corruptCheckpoint, message: "Contributor category tag is invalid.") }
            let version = try reader.integer(), payload = try reader.payload()
            records.append(try RuntimeContributorState(id: id, category: category, version: version, bytes: payload))
        }
        guard reader.remaining == 0 else { throw RuntimeFailure(.corruptCheckpoint, message: "Checkpoint has trailing fields.") }
        let physical: KinematicState
        do { physical = try KinematicState(revision: revision, time: time, q: q, v: v, acceleration: acceleration, prescribedAnchors: anchors) }
        catch { throw RuntimeFailure(.corruptCheckpoint, message: "Checkpoint physical state is invalid.") }
        return try RuntimeCheckpoint(model: ModelStamp(identity: identity, revision: revision), continuation: continuation, physical: physical,
            contributors: records, random: RuntimeRandomState(seed: seed, state: state, draws: draws), acceptedSteps: accepted)
    }

    private func write(_ sample: PrescribedAnchorState, to writer: inout RuntimeByteWriter) throws(RuntimeFailure) {
        try writer.string(sample.frame.key); try writer.integer(sample.time.bitPattern)
        let rotation = sample.motion.pose.rotation
        try writer.integer(rotation.w.bitPattern); try writer.integer(rotation.x.bitPattern)
        try writer.integer(rotation.y.bitPattern); try writer.integer(rotation.z.bitPattern)
        try write(sample.motion.pose.translation, to: &writer)
        try write(sample.motion.velocity.angular, to: &writer); try write(sample.motion.velocity.linear, to: &writer)
        try write(sample.motion.acceleration.angular, to: &writer); try write(sample.motion.acceleration.linear, to: &writer)
    }
    private func write(_ vector: Vector3, to writer: inout RuntimeByteWriter) throws(RuntimeFailure) {
        try writer.integer(vector.x.bitPattern); try writer.integer(vector.y.bitPattern); try writer.integer(vector.z.bitPattern)
    }
    private func readAnchor(from reader: inout RuntimeByteReader) throws(RuntimeFailure) -> PrescribedAnchorState {
        let key = try reader.string(), time = try reader.scalar()
        let w = try reader.scalar(), x = try reader.scalar(), y = try reader.scalar(), z = try reader.scalar()
        let translation = try readVector(from: &reader)
        let angularVelocity = try readVector(from: &reader), linearVelocity = try readVector(from: &reader)
        let angularAcceleration = try readVector(from: &reader), linearAcceleration = try readVector(from: &reader)
        do {
            let rotation = try UnitQuaternion(unitW: w, x: x, y: y, z: z)
            let pose = RigidTransform(rotation: rotation, translation: translation)
            let motion = FrameMotion(pose: pose, velocity: SpatialMotion(angular: angularVelocity, linear: linearVelocity),
                acceleration: SpatialMotion(angular: angularAcceleration, linear: linearAcceleration))
            return try PrescribedAnchorState(frame: EntityID(kind: .frame, key: key), time: time, motion: motion)
        } catch { throw RuntimeFailure(.corruptCheckpoint, message: "Prescribed frame/rotation is invalid.") }
    }
    private func readVector(from reader: inout RuntimeByteReader) throws(RuntimeFailure) -> Vector3 {
        let x = try reader.scalar(), y = try reader.scalar(), z = try reader.scalar()
        do { return try Vector3(x, y, z) }
        catch { throw RuntimeFailure(.corruptCheckpoint, message: "Prescribed vector is invalid.") }
    }
}
