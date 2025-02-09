import ShaderGraphCoder
import SwiftUI
import RealityKit
import RealityKitContent

func makeEntity(mesh: MeshResource, mat: RealityKit.Material,
                sortGroup: ModelSortGroup?, sortOrder: Int32?) async -> ModelEntity {
  let entity = await ModelEntity(mesh: mesh, materials: [mat])
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
  let session = SpatialTrackingSession()
  let palm = AnchorEntity(.hand(.right, location: .palm))
  let preview = Entity()

  @State var rings: [RingInstance] = []
  let ringsEntity = Entity()

  var body: some View {
    RealityView { content in
      var mat = try! await makeMaterial(hue: [0.8, 1, 1.5])

      // Sanity check
      let entity0 = ModelEntity(mesh: .generateBox(size: 0.2), materials: [mat])
      entity0.transform.translation = [0, 1.5, -1.5]
      content.add(entity0)

      let basicRing = Ring(radius: 1, width: 0.01)
      let inMesh = try! makeRingMesh(ring: basicRing, side: .inside)
      let outMesh = try! makeRingMesh(ring: basicRing, side: .outside)

      for _ in 0..<100 {
        let (x, y) = sampleCircle()
        rings.append(RingInstance(scale: 0.05 + x * 0.01,
                                  yOffset: y * 0.01,
                                  timeOffset: Float.random(in: 0...10)))
      }
      rings.sort { $0.scale > $1.scale }

      let group = ModelSortGroup(depthPass: nil)
      for (i, ring) in rings.enumerated() {
        try? mat.setParameter(name: "TimeOffset", value: .float(ring.timeOffset))
        let inEntity = await makeEntity(mesh: try! await MeshResource(from: inMesh),
                                        mat: mat, sortGroup: group, sortOrder: Int32(i))
        let outEntity = await makeEntity(mesh: try! await MeshResource(from: outMesh),
                                         mat: mat, sortGroup: group, sortOrder: Int32(rings.count*2 - i))
        inEntity.transform.scale = [ring.scale, 1, ring.scale]
        inEntity.transform.translation.y = ring.yOffset
        outEntity.transform = inEntity.transform
        ringsEntity.addChild(inEntity)
        ringsEntity.addChild(outEntity)
      }
      ringsEntity.transform.rotation = simd_quatf(angle: .pi/2, axis: [0, 0, 1])
      ringsEntity.transform.translation.x = 0.1

      let occlusion = await makeEntity(mesh: MeshResource.generateCylinder(height: 0.2, radius: 0.025),
                                       mat: OcclusionMaterial(),
                                       sortGroup: group,
                                       sortOrder: -1)
      ringsEntity.addChild(occlusion)

      content.add(palm)
      content.add(preview)
    }
    .upperLimbVisibility(.hidden)
    .task {
      if (await session.run(SpatialTrackingSession.Configuration(tracking: [.hand]))) != nil {
        preview.addChild(ringsEntity)
        preview.transform.translation = [0, 1.5, -0.5]
      } else {
        palm.addChild(ringsEntity)
      }
    }
  }
}

#Preview(immersionStyle: .mixed) {
  ImmersiveView()
    .environment(AppModel())
}
