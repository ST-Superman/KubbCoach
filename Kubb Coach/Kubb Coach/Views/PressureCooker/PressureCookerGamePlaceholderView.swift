//
//  PressureCookerGamePlaceholderView.swift
//  Kubb Coach
//

import SwiftUI

struct PressureCookerGamePlaceholderView: View {
    let game: PressureCookerGame

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Game icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    game.accentColor.opacity(0.25),
                                    game.accentColor.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    if game.isSystemIcon {
                        game.iconImage
                            .font(.system(size: 48))
                            .foregroundStyle(game.accentColor)
                    } else {
                        game.iconImage
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                    }
                }
                .padding(.top, 16)

                Text(game.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                // Description card
                VStack(alignment: .leading, spacing: 12) {
                    Text("About This Challenge")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(game.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(DesignConstants.mediumRadius)
                .padding(.horizontal)

                // Coming soon card
                VStack(spacing: 16) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(KubbColors.swedishGold)

                    VStack(spacing: 6) {
                        Text("Coming Soon")
                            .font(.title3)
                            .fontWeight(.bold)

                        Text("This mini-game is under construction. Check back in a future update!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(28)
                .background(Color(.systemBackground))
                .cornerRadius(DesignConstants.mediumRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignConstants.mediumRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [KubbColors.swedishGold.opacity(0.4), KubbColors.phasePressureCooker.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .cardShadow()
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(game.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PressureCookerGamePlaceholderView(game: .fieldBlitz)
    }
}
