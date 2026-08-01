import SwiftUI

/// `.keyboardType`/`.textInputAutocapitalization`/`.navigationBarTitleDisplayMode` only exist on
/// iOS/tvOS/watchOS — this target also builds for macOS purely so `swift build` succeeds from the
/// CLI in an environment with no iOS Simulator (see README "Why SPM, not an .xcodeproj"). These
/// no-op on macOS instead of failing to compile. Ported from the sibling Swift ports'
/// `Support/PlatformCompat.swift`, trimmed to what this app actually uses (no image picker in this
/// app's feature set).
extension View {
    @ViewBuilder
    func emailKeyboard() -> some View {
        #if os(iOS) || os(tvOS) || os(watchOS)
        self.keyboardType(.emailAddress).textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS) || os(tvOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
