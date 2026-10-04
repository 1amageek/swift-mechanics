import SwiftMechanics

struct BranchMachine: Machine {
    let records: [BodyRecord3D]
    let optional: BodyRecord3D?
    let enabled: Bool
    let selection: Int
    var body: some Machine {
        MachineBody(records[0])
        if let optional { MachineBody(optional) }
        if enabled { MachineBody(records[1]) }
        else { MachineGroup { MachineBody(records[2]); EmptyMachine() } }
        switch selection {
        case 0: MachineBody(records[3])
        case 1: MachineGroup { MachineBody(records[4]); EmptyMachine() }
        default: EmptyMachine()
        }
        for record in records.dropFirst(5) { MachineBody(record) }
    }
}
