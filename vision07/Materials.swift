import ShaderGraphCoder
import SwiftUI
import RealityKit
import RealityKitContent

func makeMaterial(hue: SIMD3<Float>) async throws -> ShaderGraphMaterial {
  let timeOffset = SGValue.floatParameter(name: "TimeOffset", defaultValue: 0)
  let speed = SGValue.floatParameter(name: "Speed", defaultValue: 0.3)
  let brightness = SGValue.floatParameter(name: "Brightness", defaultValue: 1)
  let uv = SGValue.texcoordVector2(index: 0)

  let x = abs(uv.x - 0.5)
  let y = (fract(uv.y - SGValue.time * speed - timeOffset) - 0.5) * 3
  let lightX = (0.5 - x) / x
  let lightY = exp(y * y * SGValue.float(-30.0))
  let light = lightX * lightY * SGValue.float(0.01) * brightness
  let color = SGValue.color3f(hue) * light
  let surface = unlitSurface(color: color,
                             opacity: SGScalar(source: .constant(.float(0))),
                             applyPostProcessToneMap: false,
                             hasPremultipliedAlpha: true)
  return try await ShaderGraphMaterial(surface: surface)
}

func makeSineMaterial(hue: SIMD3<Float>) async throws -> ShaderGraphMaterial {
  let timeOffset = SGValue.floatParameter(name: "TimeOffset", defaultValue: 0)
  let uv = SGValue.texcoordVector2(index: 0)

  let x = abs(uv.x - 0.5), y = uv.y
  let brightness = (0.5 - x) / x
  let mask = sin((y - timeOffset) * .pi * 2 - SGScalar.time * 5)
  let color = SGValue.color3f(hue) * brightness * mask * SGValue.float(0.03)
  let surface = unlitSurface(color: color,
                             opacity: SGScalar(source: .constant(.float(0))),
                             applyPostProcessToneMap: false,
                             hasPremultipliedAlpha: true)
  return try await ShaderGraphMaterial(surface: surface)
}

#Preview(immersionStyle: .full) {
  RealityView { content in
    let mat1 = try! await makeMaterial(hue: [0.8, 1, 1.5])
    let mat2 = try! await makeSineMaterial(hue: [0.8, 1, 1.5])

    let entity1 = ModelEntity(mesh: .generatePlane(width: 0.1, depth: 1.5), materials: [mat1])
    entity1.transform.translation = [-0.3, 1.5, -1.5]
    entity1.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
    content.add(entity1)

    let entity2 = ModelEntity(mesh: .generatePlane(width: 0.1, depth: 1.5), materials: [mat2])
    entity2.transform.translation = [0.3, 1.5, -1.5]
    entity2.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
    content.add(entity2)
  }
}
