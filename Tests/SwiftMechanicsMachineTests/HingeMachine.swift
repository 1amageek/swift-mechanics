import SwiftMechanics

struct HingeMachine: Machine {
    let root: BodyRecord3D
    let child: BodyRecord3D
    let hinge: MechanicalJoint
    var body: some Machine {
        MachineBody(root)
        MachineBody(child)
        MachineJoint(hinge)
    }
}
