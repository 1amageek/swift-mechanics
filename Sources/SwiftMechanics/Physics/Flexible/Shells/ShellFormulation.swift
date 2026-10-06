public enum ShellFormulation: Equatable, Sendable {
    case infinitesimalMITC4
    // FIXME(INCOMPLETE_IMPLEMENTATION): Objective finite-rotation shell laws are not implemented.
    // ShellAssembling currently refuses this selection; successful admission requires actual
    // finite-rotation strain, force, tangent, inertia and behavioral qualification together.
    case finiteRotation
}
