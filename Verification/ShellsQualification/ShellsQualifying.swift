public protocol ShellsQualifying: Sendable {
    func run(_ selected: ShellsQualificationCase) throws(ShellsQualificationError)
}
