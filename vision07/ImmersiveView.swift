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
  var size: Float = 0.1
  var xOffset: Float = 0
  var yOffset0: Float = 0
  var ySpeed: Float = 0

  var yOffset: Float = 0
  var time: Float = 0
  var speed: Float = 0
  var brightness: Float = 1
}

class RingComponent: Component {
  let fingerTips: [AnchorEntity]
  var ring: Ring
  var factor: Float = 0

  init(fingerTips: [AnchorEntity], ringParam: Ring) {
    self.fingerTips = fingerTips
    self.ring = ringParam
  }
}

class RingSystem: System {
  private static let query = EntityQuery(where: .has(RingComponent.self))

  required init(scene: RealityKit.Scene) { }

  var time: Float = 0

  func update(context: SceneUpdateContext) {
    time += Float(context.deltaTime)
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
        targetFactor = 1 - normalize(value: maxDist, range: 0.05...0.08)
      }

      // Slow ramp up, fast ramp down
      if targetFactor > comp.factor {
        comp.factor += (targetFactor - comp.factor) * 0.004
      } else {
        comp.factor += (targetFactor - comp.factor) * 0.006
      }
      comp.ring.yOffset = comp.ring.yOffset0 * cos(time * comp.ring.ySpeed)
      comp.ring.time += comp.ring.speed * (1 + comp.factor * 5)
      let brightness = comp.ring.brightness * (1 + comp.factor)
      let scale = 1.0 - comp.factor * 0.9
      let size = comp.ring.size * (1.0 - comp.factor * 0.15) + comp.ring.xOffset * scale

      if var modelComponent = entity.components[ModelComponent.self],
         var mat = modelComponent.materials.first as? ShaderGraphMaterial {
        try? mat.setParameter(name: "TimeOffset", value: .float(comp.ring.time))
        try? mat.setParameter(name: "Brightness", value: .float(brightness))
        try? mat.setParameter(name: "Mode", value: .float(comp.factor))
        modelComponent.materials = [mat]
        entity.components.set(modelComponent)
        entity.transform.scale = [size, 1, size]
        entity.transform.translation.y = comp.ring.yOffset * scale
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
      var mat = try! await makeMaterial()

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
      for _ in 0..<150 {
        let (x, y) = sampleCircle()
        let ring = Ring(size: 0.05,
                        xOffset: x * 0.01,
                        yOffset0: y * 0.01,
                        ySpeed: Float.random(in: 0...1),
                        time: Float.random(in: 0...10),
                        speed: Float.random(in: 0.002...0.004),
                        brightness: Float.random(in: 0.5...1))
        rings.append(ring)
      }
      rings.sort { $0.xOffset > $1.xOffset }

      let group = ModelSortGroup(depthPass: nil)
      for (i, ring) in rings.enumerated() {
        try? mat
          .setParameter(
            name: "HSV1",
            value: .color(CGColor(red: CGFloat(Float.random(in: 0...1)), green: 0.5, blue: 0.8, alpha: 0))
          )
        try? mat.setParameter(name: "TimeOffset", value: .float(ring.time))
        try? mat.setParameter(name: "Speed", value: .float(0.01))
        try? mat.setParameter(name: "Brightness", value: .float(ring.brightness))
        try? mat.setParameter(name: "Mode", value: .float(0))
        let inEntity = await makeEntity(mesh: inMesh, mat: mat, sortGroup: group, sortOrder: Int32(i))
        let outEntity = await makeEntity(mesh: outMesh, mat: mat, sortGroup: group, sortOrder: Int32(rings.count*2 - i))
        inEntity.transform.scale = [ring.size + ring.xOffset, 1, ring.size + ring.xOffset]
        inEntity.transform.translation.y = ring.yOffset
        outEntity.transform = inEntity.transform

        let ringComponent = RingComponent(fingerTips: fingerTips, ringParam: ring)
        inEntity.components.set(ringComponent)
        outEntity.components.set(ringComponent)

        ringsEntity.addChild(inEntity)
        ringsEntity.addChild(outEntity)
      }

      let occlusion = await makeEntity(mesh: MeshResource.generateCylinder(height: 0.2, radius: 0.03 ),
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
