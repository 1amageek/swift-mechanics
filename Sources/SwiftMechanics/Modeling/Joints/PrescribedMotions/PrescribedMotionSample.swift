public struct PrescribedMotionSample: Sendable {
    public let metadata:String
    public let time:Double
    public let anchors:[PrescribedAnchorState]
    public init(metadata:String,time:Double,anchors:[PrescribedAnchorState],policy:PrescribedMotionPolicy) throws(PrescribedMotionError) {
        guard anchors.count <= policy.maximumSamples,metadata.utf8.count <= policy.maximumMetadataBytes else { throw .capacityExceeded }
        guard time.isFinite else { throw .invalidInput }
        for (i,anchor) in anchors.enumerated() {
            guard anchor.frame.key.utf8.count <= policy.maximumIdentifierBytes else { throw .capacityExceeded }
            guard anchor.time.bitPattern == time.bitPattern,!anchors[..<i].contains(where:{$0.frame == anchor.frame}) else { throw .staleSource }
        }
        self.metadata=metadata;self.time=time;self.anchors=anchors
    }
}
