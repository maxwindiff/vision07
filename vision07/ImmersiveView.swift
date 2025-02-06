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

      let mesh = try! makeRingMesh(rings: [
        Ring(radius: 0.2, width: 0.1, offset: .zero, segments: 32),
        Ring(radius: 0.3, width: 0.05, offset: SIMD3<Float>(-0.1, 0.05, -0.1), segments: 32),
      ])
      let resource = try! await MeshResource(from: mesh)
      let entity2 = ModelEntity(mesh: resource, materials: [mat])
      entity2.transform.translation = [0, 1, -1.5]

      content.add(entity0)
      content.add(entity1)
      content.add(entity2)
    }
  }
}

#Preview(immersionStyle: .mixed) {
  ImmersiveView()
    .environment(AppModel())
}
