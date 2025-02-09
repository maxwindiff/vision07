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

func normalize(value: Float, range: ClosedRange<Float>) -> Float {
  let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
  return min(max(normalized, 0), 1)
}

