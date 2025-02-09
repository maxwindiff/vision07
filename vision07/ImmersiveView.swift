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

struct Ring {
  var scale: Float = 1
  var offset: Float = 0

  var time: Float = 0
  var speed: Float = 0.4
  var brightness: Float = 1
}

class RingComponent: Component {
  let fingerTips: [AnchorEntity]
  var ringParam: Ring
  var factor: Float = 0

  init(fingerTips: [AnchorEntity], ringParam: Ring) {
    self.fingerTips = fingerTips
    self.ringParam = ringParam
  }
}

class RingSystem: System {
  private static let query = EntityQuery(where: .has(RingComponent.self))

  required init(scene: RealityKit.Scene) { }

  func update(context: SceneUpdateContext) {
    var targetFactor: Float = -1

    for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
      let comp = entity.components[RingComponent.self]!

      // Only need to compute targetFactor once
      if targetFactor < 0 {
        var maxDist: Float = 0
        for i in 0..<comp.fingerTips.count {
          for j in 0..<i {
            maxDist = max(maxDist, distance(comp.fingerTips[i].position(relativeTo: nil),
                                            comp.fingerTips[j].position(relativeTo: nil)))
          }
        }
        targetFactor = 1 - normalize(value: maxDist, range: 0.05...0.15)
      }

      // Slow ramp up, fast ramp down
      if targetFactor > comp.factor {
        comp.factor += (targetFactor - comp.factor) * 0.003
      } else {
        comp.factor += (targetFactor - comp.factor) * 0.007
      }
      comp.ringParam.time += comp.ringParam.speed * (1 + comp.factor * 10)
      let brightness = comp.ringParam.brightness * (1 + comp.factor * 5)

      if var modelComponent = entity.components[ModelComponent.self],
         var mat = modelComponent.materials.first as? ShaderGraphMaterial {
        try? mat.setParameter(name: "TimeOffset", value: .float(comp.ringParam.time))
        try? mat.setParameter(name: "Brightness", value: .float(brightness))
        modelComponent.materials = [mat]
        entity.components.set(modelComponent)
      }
    }
  }
}

struct ImmersiveView: View {
  let session = SpatialTrackingSession()
  let palm = AnchorEntity(.hand(.right, location: .palm))
  let fingerTips = [
    AnchorEntity(.hand(.right, location: .joint(for: .indexFingerTip))),
    AnchorEntity(.hand(.right, location: .joint(for: .thumbTip))),
    AnchorEntity(.hand(.right, location: .joint(for: .middleFingerTip))),
    AnchorEntity(.hand(.right, location: .joint(for: .ringFingerTip))),
    AnchorEntity(.hand(.right, location: .joint(for: .littleFingerTip))),
  ]
  let preview = Entity()

  let ringsEntity = Entity()

  var body: some View {
    RealityView { content in
      var mat = try! await makeMaterial(hue: [0.8, 1, 1.5])

      // Sanity check
      let entity0 = ModelEntity(mesh: .generateBox(size: 0.2), materials: [mat])
      entity0.transform.translation = [0, 1.5, -1.5]
      content.add(entity0)

      // Containers / systems
      RingComponent.registerComponent()
      RingSystem.registerSystem()
      content.add(palm)
      for fingerTip in fingerTips {
        content.add(fingerTip)
      }
      preview.transform.translation = [-0.05, 1.5, -0.5]
      content.add(preview)

      // Rings
      let inMesh = try! await MeshResource(from: try! makeRingMesh(radius: 1, width: 0.01, side: .inside))
      let outMesh = try! await MeshResource(from: try! makeRingMesh(radius: 1, width: 0.01, side: .outside))

      var rings: [Ring] = []
      for _ in 0..<100 {
        let (x, y) = sampleCircle()
        rings.append(Ring(scale: 0.05 + x * 0.01,
                               offset: y * 0.01,
                               time: Float.random(in: 0...10),
                               speed: Float.random(in: 0.001...0.002),
                               brightness: Float.random(in: 0.5...0.5)))
      }
      rings.sort { $0.scale > $1.scale }

      let group = ModelSortGroup(depthPass: nil)
      for (i, ring) in rings.enumerated() {
        try? mat.setParameter(name: "TimeOffset", value: .float(ring.time))
        try? mat.setParameter(name: "Speed", value: .float(0.01))
        try? mat.setParameter(name: "Brightness", value: .float(ring.brightness))
        let inEntity = await makeEntity(mesh: inMesh, mat: mat, sortGroup: group, sortOrder: Int32(i))
        let outEntity = await makeEntity(mesh: outMesh, mat: mat, sortGroup: group, sortOrder: Int32(rings.count*2 - i))
        inEntity.transform.scale = [ring.scale, 1, ring.scale]
        inEntity.transform.translation.y = ring.offset
        outEntity.transform = inEntity.transform

        let ringComponent = RingComponent(fingerTips: fingerTips, ringParam: ring)
        inEntity.components.set(ringComponent)
        outEntity.components.set(ringComponent)

        ringsEntity.addChild(inEntity)
        ringsEntity.addChild(outEntity)
      }

      let occlusion = await makeEntity(mesh: MeshResource.generateCylinder(height: 0.2, radius: 0.03),
                                       mat: OcclusionMaterial(),
                                       sortGroup: group,
                                       sortOrder: -1)
      ringsEntity.addChild(occlusion)

      ringsEntity.transform.rotation = simd_quatf(angle: .pi/2, axis: [0, 0, 1])
      ringsEntity.transform.translation.x = 0.1
    }
    .upperLimbVisibility(.hidden)
    .task {
      if (await session.run(SpatialTrackingSession.Configuration(tracking: [.hand]))) != nil {
        preview.addChild(ringsEntity)
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
