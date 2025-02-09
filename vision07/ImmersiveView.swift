import ShaderGraphCoder
import SwiftUI
import RealityKit
import RealityKitContent

func makeEntity(mesh: LowLevelMesh, mat: RealityKit.Material,
                sortGroup: ModelSortGroup?, sortOrder: Int32?) async throws -> ModelEntity {
  let resource = try await MeshResource(from: mesh)
  let entity = await ModelEntity(mesh: resource, materials: [mat])
  if let sortGroup, let sortOrder {
    let sortComponent = ModelSortGroupComponent(group: sortGroup, order: sortOrder)
    await entity.components.set(sortComponent)
  }
  return entity
}

struct RingInstance {
  var scale: Float = 1
  var yOffset: Float = 0
  var timeOffset: Float = 0
}

func sampleCircle() -> (Float, Float) {
  while true {
    let x = Float.random(in: 0...1)
    let y = Float.random(in: 0...1)
    if (x * x + y * y) <= 1 {
      return (x, y)
    }
  }
  return (0, 0)
}

struct ImmersiveView: View {
  var body: some View {
    RealityView { content in
      var mat = try! await makeMaterial(hue: [0.8, 1, 1.5])

      // Sanity check
      let entity0 = ModelEntity(mesh: .generateBox(size: 0.16), materials: [mat])
      entity0.transform.translation = [-0.1, 1.5, -1.5]
      let entity1 = ModelEntity(mesh: .generateSphere(radius: 0.1), materials: [mat])
      entity1.transform.translation = [0.1, 1.5, -1.5]
      content.add(entity0)
      content.add(entity1)

      let basicRing = Ring(radius: 1, width: 0.01)
      let inMesh = try! makeRingMesh(ring: basicRing, side: .inside)
      let outMesh = try! makeRingMesh(ring: basicRing, side: .outside)

      var rings: [RingInstance] = []
      for _ in 0..<100 {
        let (x, y) = sampleCircle()
        rings.append(RingInstance(scale: 0.05 + x * 0.01,
                                  yOffset: y * 0.01,
                                  timeOffset: Float.random(in: 0...10)))
      }
      rings.sort { $0.scale > $1.scale }

      let ringParent = Entity()
      let group = ModelSortGroup(depthPass: nil)
      for (i, ring) in rings.enumerated() {
        try? mat.setParameter(name: "TimeOffset", value: .float(ring.timeOffset))
        let inEntity = try! await makeEntity(mesh: inMesh,
                                             mat: mat, sortGroup: group, sortOrder: Int32(i))
        let outEntity = try! await makeEntity(mesh: outMesh,
                                              mat: mat, sortGroup: group, sortOrder: Int32(rings.count*2 - i))
        inEntity.transform.scale = [ring.scale, 1, ring.scale]
        inEntity.transform.translation.y = ring.yOffset
        outEntity.transform = inEntity.transform
        ringParent.addChild(inEntity)
        ringParent.addChild(outEntity)
      }
      ringParent.transform.translation = [0, 1.2, -0.7]
      content.add(ringParent)
    }
  }
}

#Preview(immersionStyle: .mixed) {
  ImmersiveView()
    .environment(AppModel())
}
