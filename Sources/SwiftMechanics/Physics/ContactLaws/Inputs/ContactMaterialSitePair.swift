internal final class ContactMaterialSitePair: Equatable, Sendable {
    let first: ContactMaterialSite
    let second: ContactMaterialSite

    init(first: ContactMaterialSite, second: ContactMaterialSite) {
        self.first = first
        self.second = second
    }

    static func == (lhs: ContactMaterialSitePair, rhs: ContactMaterialSitePair) -> Bool {
        lhs.first == rhs.first && lhs.second == rhs.second
    }
}
