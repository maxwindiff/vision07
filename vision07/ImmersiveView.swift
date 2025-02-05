import ShaderGraphCoder
import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
  let surface = SGValue.color3f([0, 0, 1]).pbrSurface()
  var body: some View {
    RealityView { content in
      let mat = try! await ShaderGraphMaterial(surface: surface, geometryModifier: nil)
      let entity0 = ModelEntity(mesh: .generateBox(size: 0.16), materials: [mat])
      entity0.transform.translation = [-0.1, 1.5, -1.0]
      let entity1 = ModelEntity(mesh: .generateSphere(radius: 0.1), materials: [mat])
      entity1.transform.translation = [0.1, 1.5, -1.0]
      content.add(entity0)
      content.add(entity1)
    }
  }
}

#Preview(immersionStyle: .mixed) {
  ImmersiveView()
    .environment(AppModel())
}
