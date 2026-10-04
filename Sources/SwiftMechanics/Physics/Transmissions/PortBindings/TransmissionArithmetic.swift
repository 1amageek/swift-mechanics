
internal enum TransmissionArithmetic {
    static func check(_ p: TransmissionPolicy) throws(TransmissionError) {
        guard !Task.isCancelled, !p.isCancelled() else { throw .cancelled }
    }
    static func charge(_ n: Int,_ w: inout NumericalWork) throws(TransmissionError) {
        guard !Task.isCancelled else { throw .cancelled }; do { try w.chargeOperations(n) } catch { throw .numerical(error) }
    }
    static func storage(_ n: Int,_ w: inout NumericalWork) throws(TransmissionError) { do { try w.requireStorage(n) } catch { throw .numerical(error) } }
    static func product(_ a: Int,_ b: Int) throws(TransmissionError) -> Int { do { return try NumericalWork.product(a,b) } catch { throw .numerical(error) } }
    static func sum(_ a: Int,_ b: Int) throws(TransmissionError) -> Int { do { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) } }
    static func finite(_ x: Double) throws(TransmissionError) -> Double { guard x.isFinite else { throw .nonFiniteResult }; return x }
    static func same(_ a: EntityID,_ b: EntityID,_ p: TransmissionPolicy,_ w: inout NumericalWork) throws(TransmissionError) -> Bool {
        try admitBytes(a.key,p,&w); try admitBytes(b.key,p,&w)
        try charge(1,&w); return a == b
    }
    private static func admitBytes(_ key: String,_ p: TransmissionPolicy,_ w: inout NumericalWork) throws(TransmissionError) {
        var bytes=key.utf8.makeIterator()
        while true { try check(p); try charge(2,&w); if bytes.next() == nil { break } }
    }
    static func axis(_ port: TransmissionPortBinding,_ w: inout NumericalWork) throws(TransmissionError) -> Vector3 {
        guard port.manifold.positionCount == 1, port.manifold.velocityCount == 1,
              port.manifold.kind == .revolute || port.manifold.kind == .prismatic else {
            // FIXME(INCOMPLETE_IMPLEMENTATION): This production binding supports scalar revolute/prismatic axes only. Coupled/quaternion transmission ports require their physical coordinate-rate and effort maps before success.
            throw .unsupportedFidelity
        }
        try charge(1,&w)
        do { return try port.jointToReference.transforming(direction:port.manifold.orderedAxes[0].direction) } catch { throw .core(error) }
    }
    static func validate(_ ports: [TransmissionPortBinding],layout: ConstraintCoordinateLayout,policy p: TransmissionPolicy,work w: inout NumericalWork) throws(TransmissionError) {
        try check(p)
        let n=layout.scales.count
        guard n <= p.maximumCoordinates, ports.count > 0, ports.count <= p.maximumPorts else { throw .capacityExceeded }
        guard layout.revision == p.expectedLayoutRevision else { throw .staleBinding }
        for i in 0..<n {
            try check(p); try charge(2,&w); guard layout.scales[i].isFinite, layout.scales[i] > 0 else { throw .invalidInput }
            for j in 0..<i { try charge(1,&w); guard layout.coordinateIDs[i] != layout.coordinateIDs[j] else { throw .invalidInput } }
        }
        for i in ports.indices {
            try check(p); let port=ports[i]
            guard port.coordinateIndex < n else { throw .invalidDimensions }
            try charge(4,&w)
            guard port.layoutRevision == p.expectedLayoutRevision, port.modelRevision == p.expectedModelRevision,
                  port.coordinateID == layout.coordinateIDs[port.coordinateIndex] else { throw .staleBinding }
            _=try axis(port,&w)
            let dimension: PhysicalDimension=port.manifold.kind == .revolute ? .angle : .length
            guard layout.dimensions[port.coordinateIndex] == dimension else { throw .invalidDimensions }
            guard try same(port.frame,ports[0].frame,p,&w) else { throw .frameMismatch }
            for j in 0..<i {
                try charge(1,&w); guard port.coordinateIndex != ports[j].coordinateIndex else { throw .invalidInput }
                guard !(try same(port.joint,ports[j].joint,p,&w)) else { throw .invalidInput }
            }
        }
    }
    static func parallel(_ a: TransmissionPortBinding,_ b: TransmissionPortBinding,_ p: TransmissionPolicy,_ w: inout NumericalWork) throws(TransmissionError) -> Double {
        guard a.manifold.kind == .revolute, b.manifold.kind == .revolute else { throw .invalidDimensions }
        let x=try axis(a,&w), y=try axis(b,&w)
        try charge(1,&w); let dot: Double
        do { dot=try x.dot(y) } catch { throw .core(error) }
        guard abs(abs(dot)-1) <= p.geometryTolerance else { throw .incompatibleGeometry }; return dot >= 0 ? 1 : -1
    }
}
