public final class TopologyReleaseObservation: Sendable {
    public let release: SubtreeRelease
    public let metric: TopologyReleaseMetric
    public let observed: Double
    public let threshold: Double
    private init(release:SubtreeRelease,metric:TopologyReleaseMetric,observed:Double,threshold:Double) {
        self.release=release; self.metric=metric; self.observed=observed; self.threshold=threshold
    }
    public static func explicit(_ release:SubtreeRelease) -> TopologyReleaseObservation {
        TopologyReleaseObservation(release:release,metric:.explicitRelease,observed:0,threshold:0)
    }
    public static func scalar(_ release:SubtreeRelease,reaction:ConstrainedMotion,threshold:Double,
                              work:inout NumericalWork) throws(TopologyReleaseFailure) -> TopologyReleaseObservation? {
        guard !Task.isCancelled else { throw .cancelled }
        try TopologyArithmetic.charge(try TopologyArithmetic.numerical { () throws(NumericalError) in
            try NumericalWork.product(128,release.sourceSnapshot.bodies.count)
        },&work)
        let a=reaction.sourceSnapshot,e=release.sourceSnapshot
        guard threshold.isFinite,threshold >= 0,reaction.sourceVelocity == release.source.state.v,reaction.time == e.time,
              reaction.basis == e.tree.layout,reaction.layout.revision == release.source.stamp.revision,
              reaction.frame == e.tree.worldFrame,a.tree.revision == e.tree.revision,a.tree.layout == e.tree.layout,
              a.tree.bodies == e.tree.bodies,a.tree.joints == e.tree.joints,a.tree.rootBase == e.tree.rootBase,
              a.tree.worldFrame == e.tree.worldFrame,a.bodies == e.bodies,a.frames == e.frames,a.joints == e.joints,
              a.coordinateRate == e.coordinateRate,
              let entry=e.tree.layout.joints.first(where: { $0.joint == release.removedJoint }),entry.velocities.count == 1,
              let joint=e.tree.joints.first(where: { $0.id == release.removedJoint }),
              reaction.generalizedReaction.count == e.tree.layout.velocityCount else { throw .staleSource }
        for body in e.tree.bodies {
            let equal: Bool
            do throws(JointError) { equal = try a.geometricColumns(body:body.id).elementsEqual(e.geometricColumns(body:body.id)) }
            catch { throw .staleSource }
            guard equal else { throw .staleSource }
        }
        let observed=reaction.generalizedReaction[entry.velocities.start]
        guard observed.isFinite else { throw .originalAcceptance }
        let metric:TopologyReleaseMetric
        switch (joint.manifold.kind,reaction.temporalMeaning) {
        case (.revolute,.accelerationForce): metric = .torque
        case (.prismatic,.accelerationForce): metric = .force
        case (.revolute,.instantaneousVelocityImpulse): metric = .angularImpulse
        case (.prismatic,.instantaneousVelocityImpulse): metric = .linearImpulse
        default: throw .unsupportedDomain
        }
        guard abs(observed) > threshold else { return nil }
        return TopologyReleaseObservation(release:release,metric:metric,observed:observed,threshold:threshold)
    }
}
