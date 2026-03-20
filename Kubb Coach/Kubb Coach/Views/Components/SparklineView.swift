import SwiftUI

struct SparklineView: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            // Guard against invalid geometry or insufficient data
            if values.count >= 2,
               geometry.size.width > 0,
               geometry.size.height > 0,
               values.allSatisfy({ $0.isFinite }) {

                let minVal = max(0, (values.min() ?? 0) - 10)
                let maxVal = min(100, (values.max() ?? 100) + 10)
                let range = max(maxVal - minVal, 1)

                Path { path in
                    for (index, value) in values.enumerated() {
                        let x = geometry.size.width * CGFloat(index) / CGFloat(values.count - 1)
                        let y = geometry.size.height * (1 - CGFloat((value - minVal) / range))

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
