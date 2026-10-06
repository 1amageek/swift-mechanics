import SwiftMechanics
public protocol ModalReductionQualifying: Sendable {
    func run(_ selected: ModalReductionQualificationCase) throws(ModalReductionQualificationError)
}
