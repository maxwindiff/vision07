import RealityKit

struct Ring {
  let radius: Float
  let width: Float
  let offset: SIMD3<Float>
  let segments: Int
  var vertexCount: Int { segments * 2 }
}

@MainActor
func makeRingMesh(rings: [Ring]) throws -> LowLevelMesh {
  var N: Int = 0
  for ring in rings {
    N += ring.vertexCount * 2 // two-sided
  }
  let f2stride = MemoryLayout<SIMD2<Float>>.stride
  let f3stride = MemoryLayout<SIMD3<Float>>.stride

  var desc = LowLevelMesh.Descriptor()
  desc.vertexLayouts = [
    .init(bufferIndex: 0, bufferOffset: f3stride * N * 0, bufferStride: f3stride), // position
    .init(bufferIndex: 0, bufferOffset: f3stride * N * 1, bufferStride: f3stride), // normal
    .init(bufferIndex: 0, bufferOffset: f3stride * N * 2, bufferStride: f3stride), // bitangent
    .init(bufferIndex: 1, bufferOffset: f2stride * N * 0, bufferStride: f2stride), // uv0
    .init(bufferIndex: 1, bufferOffset: f2stride * N * 1, bufferStride: f2stride), // uv1
    .init(bufferIndex: 1, bufferOffset: f2stride * N * 2, bufferStride: f2stride), // uv2
  ]
  desc.vertexAttributes = [
    .init(semantic: .position, format: .float3, layoutIndex: 0, offset: 0),
    .init(semantic: .normal, format: .float3, layoutIndex: 1, offset: 0),
    .init(semantic: .bitangent, format: .float3, layoutIndex: 2, offset: 0),
    .init(semantic: .uv0, format: .float2, layoutIndex: 3, offset: 0),
    .init(semantic: .uv1, format: .float2, layoutIndex: 4, offset: 0),
    .init(semantic: .uv2, format: .float2, layoutIndex: 5, offset: 0),
  ]
  desc.vertexCapacity = N
  desc.indexCapacity = N + rings.count * 2 * 3 // N total vertices + 3 per triangle fan surface
  desc.indexType = .uint16
  let mesh = try LowLevelMesh(descriptor: desc)

  var bounds = BoundingBox()
  mesh.withUnsafeMutableBytes(bufferIndex: 0) { buffer in
    let vertexData = buffer.bindMemory(to: SIMD3<Float>.self)
    var posIndex = 0, normalIndex = N, bitangentIndex = N * 2
    for ring in rings {
      let angleStep = 2 * Float.pi / Float(ring.segments)
      for i in 0..<ring.segments {
        let angle = Float(i) * angleStep
        let x = ring.radius * cos(angle)
        let z = ring.radius * sin(angle)
        vertexData[posIndex] = SIMD3<Float>(x, -ring.width / 2, z) + ring.offset
        vertexData[posIndex+1] = SIMD3<Float>(x, ring.width / 2, z) + ring.offset
        vertexData[normalIndex] = normalize(SIMD3<Float>(x, 0, z))
        vertexData[normalIndex+1] = vertexData[normalIndex]
        vertexData[bitangentIndex] = normalize(SIMD3<Float>(-z, 0, x))
        vertexData[bitangentIndex+1] = vertexData[bitangentIndex]
        posIndex += 2
        normalIndex += 2
        bitangentIndex += 2

        bounds.formUnion(vertexData[posIndex])
        bounds.formUnion(vertexData[posIndex]+1)
      }

      // Copy back side
      for _ in 0..<ring.vertexCount {
        vertexData[posIndex] = vertexData[posIndex-ring.vertexCount]
        vertexData[normalIndex] = -vertexData[normalIndex-ring.vertexCount]
        vertexData[bitangentIndex] = vertexData[bitangentIndex-ring.vertexCount]
        posIndex += 1
        normalIndex += 1
        bitangentIndex += 1
      }
    }
  }
  mesh.withUnsafeMutableBytes(bufferIndex: 1) { rawBuffer in
    let uvData = rawBuffer.bindMemory(to: SIMD2<Float>.self)
    var uv0Index = 0, uv1Index = N, uv2Index = N * 2
    for ring in rings {
      let vStep = Float(1) / Float(ring.segments)
      for i in 0..<ring.segments {
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

      // Copy back side
      for _ in 0..<ring.vertexCount {
        uvData[uv0Index] = uvData[uv0Index-ring.vertexCount]
        uvData[uv1Index] = uvData[uv1Index-ring.vertexCount]
        uvData[uv2Index] = uvData[uv2Index-ring.vertexCount]
        uv0Index += 1
        uv1Index += 1
        uv2Index += 1
      }
    }
  }
  mesh.withUnsafeMutableIndices { rawIndices in
    let indexBuffer = rawIndices.bindMemory(to: UInt16.self)
    var indexIdx = 0, vertexStart: UInt16 = 0
    for ring in rings {
      for i in 0..<ring.vertexCount {
        indexBuffer[indexIdx + i] = vertexStart + UInt16(i)
      }
      indexIdx += ring.vertexCount
      indexBuffer[indexIdx] = vertexStart
      indexBuffer[indexIdx+1] = vertexStart + 1
      indexBuffer[indexIdx+2] = UInt16.max
      indexIdx += 3
      vertexStart += UInt16(ring.vertexCount)

      // The backside has different vertex indices, so we can't just copy it! Also change the order.
      for i in 0..<ring.vertexCount {
        indexBuffer[indexIdx + i] = vertexStart + UInt16(i ^ 1)
      }
      indexIdx += ring.vertexCount
      indexBuffer[indexIdx] = vertexStart + 1
      indexBuffer[indexIdx+1] = vertexStart
      indexBuffer[indexIdx+2] = UInt16.max
      indexIdx += 3
      vertexStart += UInt16(ring.vertexCount)
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
