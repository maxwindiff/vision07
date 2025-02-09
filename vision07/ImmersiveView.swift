import ShaderGraphCoder
import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
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
      var mat = try! await makeSineMaterial(hue: [0.8, 1, 1.5])

      // Sanity check
      let entity0 = ModelEntity(mesh: .generateBox(size: 0.16), materials: [mat])
      entity0.transform.translation = [-0.1, 1.5, -1.5]
      let entity1 = ModelEntity(mesh: .generateSphere(radius: 0.1), materials: [mat])
      entity1.transform.translation = [0.1, 1.5, -1.5]
      content.add(entity0)
      content.add(entity1)

      let radiusAvg: Float = 0.2, radiusRange: Float = 0.02;
      let widthAvg: Float = 0.02, widthRange: Float = 0.000;
      let yRange: Float = 0.01;
      var rings: [Ring] = []
      for _ in 0..<30 {
        let radius = radiusAvg + Float.random(in: -radiusRange...radiusRange)
        let width = widthAvg + Float.random(in: -widthRange...widthRange)
        let y = Float.random(in: -yRange...yRange)
        rings.append(Ring(radius: radius, width: width, offset: [0, y, 0]))
      }
      rings.sort { $0.radius > $1.radius }

      let group = ModelSortGroup(depthPass: nil)
      for (i, ring) in rings.enumerated() {
        let animationOffset = Float.random(in: 0...2)

        try? mat.setParameter(name: "Offset", value: .float(animationOffset))
        let inEntity = try! await makeEntity(mesh: try! makeRingMesh(ring: ring, side: .inside),
                                             mat: mat, sortGroup: group, sortOrder: Int32(i))
        let outEntity = try! await makeEntity(mesh: try! makeRingMesh(ring: ring, side: .outside),
                                              mat: mat, sortGroup: group, sortOrder: Int32(rings.count*2 - i))
        inEntity.transform.translation = [0, 1.2, -0.7] + ring.offset
        outEntity.transform.translation = [0, 1.2, -0.7] + ring.offset
        content.add(inEntity)
        content.add(outEntity)
      }
    }
  }
}

#Preview(immersionStyle: .mixed) {
  ImmersiveView()
    .environment(AppModel())
}
