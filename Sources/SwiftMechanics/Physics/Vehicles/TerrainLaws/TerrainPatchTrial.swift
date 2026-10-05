/// A successful candidate is not accepted until checked against its unchanged base.
public struct TerrainPatchTrial: Sendable {
    public let response: TerrainPatchResponse
    internal let base: TerrainPatchHistory
    internal let candidate: TerrainPatchHistory

    internal init(response: TerrainPatchResponse, base: TerrainPatchHistory, candidate: TerrainPatchHistory) {
        self.response = response; self.base = base; self.candidate = candidate
    }
}
