import ShaderGraphCoder
import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
  func makeMaterial(hue: SIMD3<Float>) async throws -> ShaderGraphMaterial {
    let uv = SGValue.texcoordVector2(index: 0)
    let x = abs(uv.x - 0.5), y = abs(uv.y - 0.5)
    let brightness = (0.5 - x) / x
    let color = SGValue.color3f(hue) * brightness * SGScalar(source: .constant(.float(0.03)))
    let surface = unlitSurface(color: color,
                               opacity: SGScalar(source: .constant(.float(0))),
                               applyPostProcessToneMap: false,
                               hasPremultipliedAlpha: true)
    return try await ShaderGraphMaterial(surface: surface)
  }

  func makeEntity(mesh: LowLevelMesh, mat: RealityKit.Material, sortGroup: ModelSortGroup?, sortOrder: Int32?) async throws -> ModelEntity {
    let resource = try await MeshResource(from: mesh)
    let entity = ModelEntity(mesh: resource, materials: [mat])
    if let sortGroup, let sortOrder {
      let sortComponent = ModelSortGroupComponent(group: sortGroup, order: sortOrder)
      entity.components.set(sortComponent)
    }
    return entity
  }

  var body: some View {
    RealityView { content in
      let mat = try! await makeMaterial(hue: [0.8, 1, 1.5])

      let entity0 = ModelEntity(mesh: .generateBox(size: 0.16), materials: [mat])
      entity0.transform.translation = [-0.1, 1.5, -1.5]

      let entity1 = ModelEntity(mesh: .generateSphere(radius: 0.1), materials: [mat])
      entity1.transform.translation = [0.1, 1.5, -1.5]

      let ring1 = Ring(radius: 0.2, width: 0.1), ring2 = Ring(radius: 0.3, width: 0.05)
      let out1mesh = try! makeRingMesh(ring: ring1, side: .outside)
      let in1mesh = try! makeRingMesh(ring: ring1, side: .inside)
      let out2mesh = try! makeRingMesh(ring: ring2, side: .outside)
      let in2mesh = try! makeRingMesh(ring: ring2, side: .inside)

      let group = ModelSortGroup(depthPass: nil)
      let in2 = try! await makeEntity(mesh: in2mesh, mat: mat, sortGroup: group, sortOrder: 1)
      let in1 = try! await makeEntity(mesh: in1mesh, mat: mat, sortGroup: group, sortOrder: 2)
      let out1 = try! await makeEntity(mesh: out1mesh, mat: mat, sortGroup: group, sortOrder: 3)
      let out2 = try! await makeEntity(mesh: out2mesh, mat: mat, sortGroup: group, sortOrder: 4)
      in1.transform.translation = [0, 1.01, -1.5]
      in2.transform.translation = [0, 1, -1.5]
      out1.transform.translation = [0, 1.01, -1.5]
      out2.transform.translation = [0, 1, -1.5]

      content.add(entity0)
      content.add(entity1)
      content.add(in1)
      content.add(in2)
      content.add(out1)
      content.add(out2)
    }
  }
}

#Preview(immersionStyle: .mixed) {
  ImmersiveView()
    .environment(AppModel())
}
