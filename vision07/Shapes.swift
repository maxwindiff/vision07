import RealityKit

enum Side {
  case outside
  case inside

  func normalFactor() -> Float {
    switch self {
    case .outside: return 1
    case .inside: return -1
    }
  }
}

@MainActor
func makeRingMesh(radius: Float, width: Float, side: Side, segments: Int = 120) throws -> LowLevelMesh {
  let vertexCount = segments * 2 + 2
  let f2stride = MemoryLayout<SIMD2<Float>>.stride
  let f3stride = MemoryLayout<SIMD3<Float>>.stride

  var desc = LowLevelMesh.Descriptor()
  desc.vertexLayouts = [
    .init(bufferIndex: 0, bufferOffset: f3stride * vertexCount * 0, bufferStride: f3stride), // position
    .init(bufferIndex: 0, bufferOffset: f3stride * vertexCount * 1, bufferStride: f3stride), // normal
    .init(bufferIndex: 0, bufferOffset: f3stride * vertexCount * 2, bufferStride: f3stride), // bitangent
    .init(bufferIndex: 1, bufferOffset: f2stride * vertexCount * 0, bufferStride: f2stride), // uv0
    .init(bufferIndex: 1, bufferOffset: f2stride * vertexCount * 1, bufferStride: f2stride), // uv1
    .init(bufferIndex: 1, bufferOffset: f2stride * vertexCount * 2, bufferStride: f2stride), // uv2
  ]
  desc.vertexAttributes = [
    .init(semantic: .position, format: .float3, layoutIndex: 0, offset: 0),
    .init(semantic: .normal, format: .float3, layoutIndex: 1, offset: 0),
    .init(semantic: .bitangent, format: .float3, layoutIndex: 2, offset: 0),
    .init(semantic: .uv0, format: .float2, layoutIndex: 3, offset: 0),
    .init(semantic: .uv1, format: .float2, layoutIndex: 4, offset: 0),
    .init(semantic: .uv2, format: .float2, layoutIndex: 5, offset: 0),
  ]
  desc.vertexCapacity = vertexCount
  desc.indexCapacity = vertexCount
  desc.indexType = .uint16
  let mesh = try LowLevelMesh(descriptor: desc)

  var bounds = BoundingBox()
  mesh.withUnsafeMutableBytes(bufferIndex: 0) { buffer in
    let vertexData = buffer.bindMemory(to: SIMD3<Float>.self)
    var posIndex = 0, normalIndex = vertexCount, bitangentIndex = vertexCount * 2

    let angleStep = 2 * Float.pi / Float(segments)
    for i in 0..<segments+1 {
      let angle = Float(i) * angleStep
      let x = radius * cos(angle)
      let z = radius * sin(angle)
      vertexData[posIndex] = SIMD3<Float>(x, -width / 2, z)
      vertexData[posIndex+1] = SIMD3<Float>(x, width / 2, z)
      vertexData[normalIndex] = normalize(SIMD3<Float>(x, 0, z)) * side.normalFactor()
      vertexData[normalIndex+1] = vertexData[normalIndex]
      vertexData[bitangentIndex] = normalize(SIMD3<Float>(-z, 0, x))
      vertexData[bitangentIndex+1] = vertexData[bitangentIndex]
      posIndex += 2
      normalIndex += 2
      bitangentIndex += 2

      bounds.formUnion(vertexData[posIndex])
      bounds.formUnion(vertexData[posIndex]+1)
    }
  }
  mesh.withUnsafeMutableBytes(bufferIndex: 1) { rawBuffer in
    let uvData = rawBuffer.bindMemory(to: SIMD2<Float>.self)
    var uv0Index = 0, uv1Index = vertexCount, uv2Index = vertexCount * 2

    let vStep = Float(1) / Float(segments)
    for i in 0..<segments+1 {
      let v = Float(i) * vStep
      uvData[uv0Index] = SIMD2<Float>(0, v)
      uvData[uv0Index+1] = SIMD2<Float>(1, v)
      uvData[uv1Index] = .zero
      uvData[uv1Index+1] = .zero
      uvData[uv2Index] = .zero
      uvData[uv2Index+1] = .zero
      uv0Index += 2
      uv1Index += 2
      uv2Index += 2
    }
  }
  mesh.withUnsafeMutableIndices { rawIndices in
    let indexBuffer = rawIndices.bindMemory(to: UInt16.self)

    if side == .outside {
      for i in 0..<vertexCount {
        indexBuffer[i] = UInt16(i)
      }
    } else {
      for i in 0..<vertexCount {
        indexBuffer[i] = UInt16(i ^ 1)
      }
    }
  }

  mesh.parts.append(LowLevelMesh.Part(
    indexOffset: 0,
    indexCount: desc.indexCapacity,
    topology: .triangleStrip,
    materialIndex: 0,
    bounds: bounds
  ))
  return mesh
}
