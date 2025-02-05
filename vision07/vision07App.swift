import SwiftUI

@main
struct vision07App: App {
  @Environment(\.openImmersiveSpace) private var openImmersiveSpace
  @State private var appModel = AppModel()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(appModel)
        .task {
          await openImmersiveSpace(id: appModel.immersiveSpaceID)
        }
    }
    .defaultSize(width: 400, height: 300)

    ImmersiveSpace(id: appModel.immersiveSpaceID) {
      ImmersiveView()
        .environment(appModel)
        .onAppear {
          appModel.immersiveSpaceState = .open
        }
        .onDisappear {
          appModel.immersiveSpaceState = .closed
        }
    }
    .immersionStyle(selection: .constant(.full), in: .full)
  }
}
