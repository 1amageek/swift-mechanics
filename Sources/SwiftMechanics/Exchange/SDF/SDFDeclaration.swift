internal struct SDFDeclaration {
    enum Kind: Equatable { case model, link, joint, frame }
    let node: Int
    let kind: Kind
    let name: String
    let scope: String
    let top: String
    let staticModel: Bool
}
