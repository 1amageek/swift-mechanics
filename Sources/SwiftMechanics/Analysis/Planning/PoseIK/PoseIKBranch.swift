public enum PoseIKBranch: Equatable, Sendable {
    /// Finite coordinate bounds select the supplied Euclidean chart; no angle wrapping occurs.
    /// Orientation errors must have cos(angle) strictly greater than this margin in [0,1).
    case suppliedLocal(cosineMargin: Double)
    // FIXME(INCOMPLETE_IMPLEMENTATION): Multi-branch initialization is unavailable in PoseIKSolving.solve; this case fails until branch enumeration and per-branch original acceptance are implemented and qualified.
    case enumerateBranches
}
