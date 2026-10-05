internal struct RollingPointMotion {
    let velocity: Vector3
    let acceleration: Vector3
    let accelerationBias: Vector3
    let drift: Vector3
    let columns: [Vector3]
}
