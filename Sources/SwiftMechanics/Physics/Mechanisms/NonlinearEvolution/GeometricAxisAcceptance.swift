/// Full physical axis derivatives, independent of the regular two-row alignment chart.
internal enum GeometricAxisAcceptance {
    static func validate(_ geometry:GeometricConstraintSystem,snapshot:KinematicSnapshot,acceleration:[Double]?,
                         tolerance:Double,work:inout NumericalWork) throws(RuntimeFailure) {
        let n=snapshot.tree.layout.velocityCount,t=geometry.layout.timeScale
        guard acceleration == nil || acceleration?.count == n else { throw RuntimeFailure(.invalidState,message:"Original axis acceleration shape differs.") }
        for relation in geometry.relations where relation.kind == .alignedAxes {
            do throws(NumericalError) { try work.chargeOperations(try NumericalWork.product(1024,n+1)) }
            catch { throw RuntimeFailure(.capacityExceeded,message:"Original physical axis admission exhausted.") }
            let rate:Vector3,second:Vector3?
            do {
                func direction(_ endpoint:GeometricFrameEndpoint) throws -> (axis:Vector3,rate:Vector3,second:Vector3) {
                    let frame=try snapshot.frame(endpoint.frame),body=try snapshot.body(endpoint.body)
                    let axis=try frame.motion.pose.rotation.rotating(endpoint.axis),w=frame.motion.velocity.angular
                    let rate=try w.cross(axis)
                    let prescribed=snapshot.tree.joints.contains { joint in
                        guard joint.parentAnchor.frame == endpoint.frame else { return false }
                        if case .prescribed=joint.parentAnchor.placement { return true };return false
                    }
                    var alpha=prescribed ? frame.motion.acceleration.angular : body.accelerationBias.angular
                    if let acceleration,!prescribed {
                        let columns=try snapshot.geometricColumns(body:endpoint.body)
                        for (i,column) in columns.enumerated() { alpha=try alpha.adding(column.angular.scaled(by:acceleration[i])) }
                    }
                    return (axis,rate,try alpha.cross(axis).adding(w.cross(rate)))
                }
                let a=try direction(relation.first),b=try direction(relation.second)
                rate=try a.rate.cross(b.axis).adding(a.axis.cross(b.rate)).scaled(by:t)
                if acceleration != nil {
                    second=try a.second.cross(b.axis).adding(a.rate.cross(b.rate).scaled(by:2)).adding(a.axis.cross(b.second)).scaled(by:t*t)
                } else { second=nil }
            } catch { throw RuntimeFailure(.invalidState,message:"Original physical axis source/arithmetic failed.") }
            guard rate.x.isFinite,rate.y.isFinite,rate.z.isFinite,
                  max(abs(rate.x),max(abs(rate.y),abs(rate.z))) <= tolerance else { throw RuntimeFailure(.invalidState,message:"Original full physical axis velocity rejected.") }
            if let second {
                guard second.x.isFinite,second.y.isFinite,second.z.isFinite,
                      max(abs(second.x),max(abs(second.y),abs(second.z))) <= tolerance else { throw RuntimeFailure(.invalidState,message:"Original full physical axis acceleration rejected.") }
            }
        }
    }
}
