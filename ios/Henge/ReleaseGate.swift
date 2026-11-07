import Foundation

/// Between releases, the release adds this file: the version the build reports.
/// Henge's main branch does not build from source without it.
enum ReleaseGate {
    static let version = "0.2.0"
}
