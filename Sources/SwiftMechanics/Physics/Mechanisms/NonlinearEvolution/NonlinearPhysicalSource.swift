/// Public physical-source witness comparison; no lower component storage is inspected.
internal enum NonlinearPhysicalSource {
    static func matches(_ actual:RigidDynamicsInput,_ expected:RigidDynamicsInput) -> Bool {
        actual.velocity == expected.velocity && actual.inertias == expected.inertias && actual.gravity == expected.gravity
            && actual.bodyWrenches == expected.bodyWrenches && actual.generalizedForces == expected.generalizedForces
            && matches(actual.snapshot,expected.snapshot)
    }
    static func matches(_ actual:KinematicSnapshot,_ expected:KinematicSnapshot) -> Bool {
        let a=actual.tree,e=expected.tree
        guard actual.time == expected.time,a.revision == e.revision,a.layout == e.layout,a.rootBase == e.rootBase,
              a.worldFrame == e.worldFrame,a.frameCount == e.frameCount,a.bodies == e.bodies,a.joints == e.joints,
              actual.bodies == expected.bodies,actual.frames == expected.frames,actual.joints == expected.joints,
              actual.coordinateRate == expected.coordinateRate else { return false }
        for body in e.bodies {
            do throws(JointError) {
                let lhs=try actual.geometricColumns(body:body.id),rhs=try expected.geometricColumns(body:body.id)
                guard lhs.elementsEqual(rhs) else { return false }
            } catch { return false }
        }
        return true
    }
}
