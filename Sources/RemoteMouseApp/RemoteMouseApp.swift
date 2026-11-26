import SwiftUI
import RemoteMouseCore

@main
public struct RemoteMouseApp: App {
    @StateObject private var viewModel = TouchpadViewModel()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            TouchpadView(viewModel: viewModel)
        }
    }
}
