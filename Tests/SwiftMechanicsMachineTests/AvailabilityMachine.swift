import SwiftMechanics

struct AvailabilityMachine: Machine {
    let record: BodyRecord3D
    var body: some Machine {
        if #available(macOS 999.0, *) { FutureMachine(record: record) }
        else { MachineBody(record) }
    }
}
