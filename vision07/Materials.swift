import ShaderGraphCoder
import SwiftUI
import RealityKit
import RealityKitContent

func makeMaterial(hue1: SIMD3<Float> = [1.5, 0.8, 0.3],
                  hue2: SIMD3<Float> = [0.8, 1, 1.5]) async throws -> ShaderGraphMaterial {
  let timeOffset = SGValue.floatParameter(name: "TimeOffset", defaultValue: 0)
  let brightness = SGValue.floatParameter(name: "Brightness", defaultValue: 1)
  let mode = SGValue.floatParameter(name: "Mode", defaultValue: 0)
  let uv = SGValue.uv0
  let x = abs(uv.x - 0.5)
  let length = mix(fg: SGValue.float(2), bg: SGValue.float(3), mix: mode)
  let ty = uv.y - timeOffset
  let y = (fract(ty) - 0.5) * length

  // Mode 1
  let shapeX1 = (0.3 - x) / x
  let shapeY1 = exp(y * y * SGValue.float(-30.0))
  let bright1 = shapeX1 * shapeY1 * SGValue.float(0.01) * brightness
  let color1 = SGValue.color3f(hue1) * bright1

  // Mode 2
  let shapeX2 = (0.5 - x) / x
  let shapeY2 = exp(y * y * SGValue.float(-30.0))
  let bright2 = shapeX2 * shapeY2 * SGValue.float(0.01) * brightness
  let color2 = SGValue.color3f(hue2) * bright2

  let color = mix(fg: color2, bg: color1, mix: mode)
  let surface = unlitSurface(color: color,
                             opacity: SGScalar(source: .constant(.float(0))),
                             applyPostProcessToneMap: false,
                             hasPremultipliedAlpha: true)
  return try await ShaderGraphMaterial(surface: surface)
}

func makeSineMaterial(hue: SIMD3<Float>) async throws -> ShaderGraphMaterial {
  let timeOffset = SGValue.floatParameter(name: "TimeOffset", defaultValue: 1.3)
  let uv = SGValue.texcoordVector2(index: 0)

  let x = abs(uv.x - 0.5), y = uv.y
  let brightness = (0.5 - x) / x
  let mask = sin((y - timeOffset) * .pi * 2)
  let color = SGValue.color3f(hue) * brightness * mask * SGValue.float(0.03)
  let surface = unlitSurface(color: color,
                             opacity: SGScalar(source: .constant(.float(0))),
                             applyPostProcessToneMap: false,
                             hasPremultipliedAlpha: true)
  return try await ShaderGraphMaterial(surface: surface)
}

#Preview(immersionStyle: .full) {
  RealityView { content in
    let parent = Entity()
    parent.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
    parent.transform.translation = [0, 1.5, -1]
    content.add(parent)

    let mesh = MeshResource.generatePlane(width: 0.1, depth: 1.5)

    var mat1 = try! await makeMaterial()
    let entity1 = ModelEntity(mesh: mesh, materials: [mat1])
    entity1.transform.translation.x = -0.4
    parent.addChild(entity1)

    try! mat1.setParameter(name: "Mode", value: .float(0.5))
    let entity1a = ModelEntity(mesh: mesh, materials: [mat1])
    entity1a.transform.translation.x = -0.2
    parent.addChild(entity1a)

    try! mat1.setParameter(name: "Mode", value: .float(1))
    let entity1b = ModelEntity(mesh: mesh, materials: [mat1])
    entity1b.transform.translation.x = 0
    parent.addChild(entity1b)

    let mat2 = try! await makeSineMaterial(hue: [0.8, 1, 1.5])
    let entity2 = ModelEntity(mesh: mesh, materials: [mat2])
    entity2.transform.translation.x = 0.2
    parent.addChild(entity2)
  }
}
