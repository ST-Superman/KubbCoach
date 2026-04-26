//
//  ProgressScrollerView.swift
//  Kubb Coach
//
//  Vertical scroll-wheel for selecting a Kubb Progress value within a dynamic range.
//  Negative = field kubbs left uncleaned; positive = baseline kubbs (+ king) knocked.
//

import SwiftUI

struct ProgressScrollerView: View {
    @Binding var value: Int
    let minValue: Int
    let maxValue: Int

    private let itemHeight: CGFloat = 56
    private let visibleItems = 5  // odd number so center is the selected value

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        // Top padding to center first item
                        Color.clear.frame(height: itemHeight * CGFloat(visibleItems / 2))

                        ForEach(minValue...maxValue, id: \.self) { number in
                            progressItem(number, totalWidth: totalWidth)
                                .id(number)
                                .frame(height: itemHeight)
                        }

                        // Bottom padding to center last item
                        Color.clear.frame(height: itemHeight * CGFloat(visibleItems / 2))
                    }
                }
                .frame(height: itemHeight * CGFloat(visibleItems))
                .overlay(selectionIndicator)
                .simultaneousGesture(
                    DragGesture()
                        .onEnded { gesture in
                            let delta = gesture.translation.height
                            let steps = Int((-delta / itemHeight).rounded())
                            let newValue = max(minValue, min(maxValue, value + steps))
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                value = newValue
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                )
                .onChange(of: value) { _, newVal in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        proxy.scrollTo(newVal, anchor: .center)
                    }
                }
                .onChange(of: minValue) { _, _ in
                    let clamped = max(minValue, min(maxValue, value))
                    value = clamped
                    proxy.scrollTo(clamped, anchor: .center)
                }
                .onChange(of: maxValue) { _, _ in
                    let clamped = max(minValue, min(maxValue, value))
                    value = clamped
                    proxy.scrollTo(clamped, anchor: .center)
                }
                .onAppear {
                    let clamped = max(minValue, min(maxValue, value))
                    value = clamped
                    proxy.scrollTo(clamped, anchor: .center)
                }
            }
        }
        .frame(height: itemHeight * CGFloat(visibleItems))
    }

    // MARK: - Item view

    private func progressItem(_ number: Int, totalWidth: CGFloat) -> some View {
        let isSelected = number == value
        let distance = abs(number - value)
        let scale: CGFloat = isSelected ? 1.0 : max(0.65, 1.0 - CGFloat(distance) * 0.12)
        let opacity: Double = isSelected ? 1.0 : max(0.2, 1.0 - Double(distance) * 0.25)

        return ZStack {
            Text(formattedNumber(number))
                .font(.system(size: 36, weight: isSelected ? .bold : .regular, design: .rounded))
                .foregroundStyle(color(for: number))
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .frame(width: totalWidth, height: itemHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                value = number
            }
        }
    }

    private var selectionIndicator: some View {
        VStack {
            Spacer()
            Rectangle()
                .fill(Color.Kubb.swedishBlue.opacity(0.2))
                .frame(height: 1)
            Spacer().frame(height: itemHeight - 2)
            Rectangle()
                .fill(Color.Kubb.swedishBlue.opacity(0.2))
                .frame(height: 1)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func formattedNumber(_ n: Int) -> String {
        n > 0 ? "+\(n)" : "\(n)"
    }

    private func color(for number: Int) -> Color {
        if number < 0 { return Color.Kubb.phasePC }
        if number == 0 { return .primary }
        return Color.Kubb.forestGreen
    }
}

// MARK: - Preview helper

#if DEBUG
struct ProgressScrollerView_Previews: PreviewProvider {
    struct Wrapper: View {
        @State var value = 0
        var body: some View {
            VStack {
                Text("Selected: \(value > 0 ? "+\(value)" : "\(value)")")
                    .font(.title2.bold())
                ProgressScrollerView(value: $value, minValue: -5, maxValue: 6)
            }
            .padding()
        }
    }
    static var previews: some View {
        Wrapper()
    }
}
#endif
