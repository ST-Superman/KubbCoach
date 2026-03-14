import SwiftUI

// MARK: - Training Mode Enum

enum FieldSetupMode {
    case eightMeter
    case blasting
    case inkasting

    var phase: TrainingPhase {
        switch self {
        case .eightMeter: return .eightMeters
        case .blasting: return .fourMetersBlasting
        case .inkasting: return .inkastingDrilling
        }
    }

    var color: Color {
        switch self {
        case .eightMeter: return KubbColors.phase8m
        case .blasting: return KubbColors.phase4m
        case .inkasting: return KubbColors.phaseInkasting
        }
    }
}

struct KubbFieldSetupView: View {
    let mode: FieldSetupMode
    var onComplete: (() -> Void)? = nil

    @State private var currentStep = 0
    @State private var animationTrigger = UUID()

    private var steps: [SetupStep] {
        switch mode {
        case .eightMeter:
            return [
                SetupStep(
                    title: "Set up a standard kubb pitch",
                    description: "5m × 8m field with corner and midfield stakes, 5 kubbs per baseline, and the King in center.",
                    highlight: .all
                ),
                SetupStep(
                    title: "Position Target Kubbs",
                    description: "Your targets are the 5 kubbs on the far baseline.",
                    highlight: .teamA
                ),
                SetupStep(
                    title: "Aim for the far kubbs",
                    description: "Throw each of your batons at the kubbs on the far baseline. Record \"hit\" if the baton is knocked over.",
                    highlight: .king
                ),
                SetupStep(
                    title: "Aim for the far kubbs",
                    description: "Record any throw that misses, or fails to knock a kubb down as a \"miss\".",
                    highlight: .throwingLine
                ),
                SetupStep(
                    title: "Round Completion",
                    description: "Continue throwing all 6 batons.  Once all 6 batons have been thrown, reset the pitch by gathering your batons and standing up any knocked down kubbs.  If you successfully knock down all 5 kubbs and still have a baton, you can throw your last baton at the king.",
                    highlight: .all
                ),
                SetupStep(
                    title: "Next Round",
                    description: "The next round follows the same process, but throwing at the other baseline.  Keep track of your scores and try to beat your previous record!",
                    highlight: .all
                )
            ]

        case .blasting:
            return [
                SetupStep(
                    title: "Set up a standard kubb pitch",
                    description: "5m × 8m field with corner and midfield stakes.",
                    highlight: .all
                ),
                SetupStep(
                    title: "Inkast Field Kubbs",
                    description: "Each round will tell you how many kubbs to inkast. For example, the first round asks you to inkast 2 kubbs.",
                    highlight: .targetZone
                ),
                SetupStep(
                    title: "Place or Practice",
                    description: "You can simulate this by physically placing the kubbs on the opposing side of the pitch, or you can get extra inkasting practice by inkasting the kubbs from behind your baseline.",
                    highlight: .targetZone
                ),
                SetupStep(
                    title: "Knock Down Field Kubbs",
                    description: "Once the kubbs are in place on the opposing side, you will throw your batons, trying to knock down all of the field kubbs in as few throws as possible. Record the number of kubbs you knock down with each toss.",
                    highlight: .targetZone
                ),
                SetupStep(
                    title: "PAR Scoring System",
                    description: "Each round has a target PAR score (like a golf course). Each baton throw can be thought of as a stroke and any field kubbs not knocked down after all 6 batons award penalty strokes.",
                    highlight: .targetZone
                ),
                SetupStep(
                    title: "Prepare for Next Round",
                    description: "When the round is over, gather the batons at your baseline and either inkast or place the kubbs for the next round.",
                    highlight: .targetZone
                )
            ]

        case .inkasting:
            return [
                SetupStep(
                    title: "Set up a standard kubb pitch",
                    description: "5m × 8m field with corner and midfield stakes. The midline divides the field into two halves.",
                    highlight: .all
                ),
                SetupStep(
                    title: "Your target: the opposite half",
                    description: "Kubbs must land past the midline, in your opponent's territory. The general idea is to get the kubbs as close to the corner of the midline and sideline as possible",
                    highlight: .targetZone
                ),
                SetupStep(
                    title: "Set up and get ready",
                    description: "Place your phone on a tripod outside the pitch near the midline, pointed at the target zone. Stand at your baseline ready to throw.",
                    highlight: .all
                ),
                SetupStep(
                    title: "Throw kubbs to the target zone",
                    description: "Throw 5 kubbs underhand into the opposite half. Aim to land them close together. Then stand the kubbs up, take a photo, and mark the top of each kubb by tapping on it.",
                    highlight: .all
                ),
                SetupStep(
                    title: "Understanding your results",
                    description: "Your score is based on clustering: tight groups score well, while outliers beyond the target radius count against you.",
                    highlight: .all
                ),
                SetupStep(
                    title: "Ready to practice!",
                    description: "Each round, throw all kubbs and analyze your clustering. Tighter clusters = better scores. Good luck! For added practice, try to blast the field kubbs down with 3 batons for 5 kubbs or 4 batons for 10 kubbs.",
                    highlight: .all
                )
            ]
        }
    }

    var body: some View {
        ZStack {
            // App background gradient
            DesignGradients.trainingBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text(mode.phase.displayName.uppercased() + " SETUP")
                        .font(.title3)
                        .fontWeight(.bold)
                        .tracking(4)
                        .foregroundColor(mode.color)

                    Text("STEP \(currentStep + 1) OF \(steps.count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(mode.color.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(mode.color.opacity(0.15))
                        .clipShape(Capsule())

                    Text(steps[currentStep].title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)

                    Text(steps[currentStep].description)
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
                .padding(.top, 20)

                // Field Diagram (hidden on step 5 for blasting and 8-meter modes)
                if !(currentStep == 4 && (mode == .blasting || mode == .eightMeter)) {
                    GeometryReader { geometry in
                        let availableWidth = geometry.size.width - 48
                        let availableHeight = geometry.size.height
                        let aspectRatio: CGFloat = 0.625 // 5m / 8m

                        let width = min(availableWidth, availableHeight * aspectRatio) * 0.9
                        let height = width / aspectRatio

                        KubbFieldDiagramView(
                            mode: mode,
                            step: currentStep,
                            highlight: steps[currentStep].highlight,
                            animationTrigger: animationTrigger
                        )
                        .frame(width: width, height: height)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(KubbColors.trainingSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(mode.color.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 4)
                                .padding(12)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                Spacer()

                // Blasting scorecard overlay (step 5)
                if mode == .blasting && currentStep == 4 {
                    BlastingScorecardView()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 60)
                        .transition(.opacity)
                }

                // Controls
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        // Back button
                        Button(action: {
                            if currentStep > 0 {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep -= 1
                                    animationTrigger = UUID()
                                }
                            }
                        }) {
                            Text("← Back")
                                .font(.subheadline)
                        }
                        .buttonStyle(StepButtonStyle(color: mode.color, isDisabled: currentStep == 0, isPrimary: false))
                        .disabled(currentStep == 0)

                        // Step progress bars
                        HStack(spacing: 5) {
                            ForEach(0..<steps.count, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        index < currentStep ? mode.color :
                                        index == currentStep ? mode.color :
                                        Color.white.opacity(0.2)
                                    )
                                    .frame(height: 3)
                                    .opacity(index < currentStep ? 0.6 : 1.0)
                                    .animation(.easeInOut(duration: 0.3), value: currentStep)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            currentStep = index
                                            animationTrigger = UUID()
                                        }
                                    }
                            }
                        }

                        // Next / Begin Training button
                        Button(action: {
                            if currentStep < steps.count - 1 {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep += 1
                                    animationTrigger = UUID()
                                }
                            } else {
                                // On final step, call completion callback
                                onComplete?()
                            }
                        }) {
                            Text(currentStep == steps.count - 1 ? "Begin Training" : "Next →")
                                .font(.subheadline)
                        }
                        .buttonStyle(StepButtonStyle(color: mode.color, isDisabled: false, isPrimary: true))
                    }

                    Text("Step \(currentStep + 1) of \(steps.count)")
                        .font(.caption)
                        .tracking(1)
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Supporting Types

struct SetupStep {
    let title: String
    let description: String
    let highlight: HighlightType
}

enum HighlightType {
    case corners
    case midstakes
    case teamA
    case teamB
    case king
    case throwingLine
    case blastingLine
    case targetZone
    case all
}

// MARK: - Field Diagram View

struct KubbFieldDiagramView: View {
    let mode: FieldSetupMode
    let step: Int
    let highlight: HighlightType
    let animationTrigger: UUID

    // Animation state for throw sequences
    @State private var batonProgress: CGFloat = 0
    @State private var showHitMessage = false
    @State private var hitKubbs: Set<Int> = []
    @State private var baton2Progress: CGFloat = 0
    @State private var showMissMessage = false
    @State private var missedKubbs: Set<Int> = []

    // Blasting mode field kubb animation
    @State private var fieldKubb1Progress: CGFloat = 0
    @State private var fieldKubb2Progress: CGFloat = 0
    @State private var showFieldKubbsLabel = false

    // Blasting mode baton throw (step 4)
    @State private var blastingBatonProgress: CGFloat = 0
    @State private var showBlastingHit1 = false
    @State private var showBlastingHit2 = false

    // Inkasting mode animations
    @State private var showBullseyeTarget = false
    @State private var showCameraIcon = false
    @State private var inkastingKubb1Progress: CGFloat = 0
    @State private var inkastingKubb2Progress: CGFloat = 0
    @State private var inkastingKubb3Progress: CGFloat = 0
    @State private var inkastingKubb4Progress: CGFloat = 0
    @State private var inkastingKubb5Progress: CGFloat = 0

    // Inkasting visualization (steps 6-8)
    @State private var showClusterCenter = false
    @State private var showCoreCircle = false
    @State private var showTargetCircle = false
    @State private var highlightOutlier = false

    // Visibility based on mode
    var showCorners: Bool { step >= 0 }
    var showMid: Bool {
        switch mode {
        case .eightMeter: return step >= 0
        case .blasting: return step >= 0
        case .inkasting: return step >= 1
        }
    }
    var showBlastingLine: Bool {
        mode == .blasting && step >= 1
    }
    var showTeamA: Bool {
        switch mode {
        case .eightMeter: return step >= 0
        case .blasting: return false // Field kubbs are used instead
        case .inkasting: return false
        }
    }
    var showTeamB: Bool {
        mode == .eightMeter && step >= 0
    }
    var showKing: Bool {
        switch mode {
        case .eightMeter: return step >= 0
        case .blasting: return false
        case .inkasting: return false
        }
    }
    var showThrowingLine: Bool {
        switch mode {
        case .eightMeter: return step >= 3
        case .blasting: return step >= 3
        case .inkasting: return step >= 3
        }
    }
    var showTargetZone: Bool {
        mode == .inkasting && step >= 2
    }

    func isHighlighted(_ type: HighlightType) -> Bool {
        // Special case: Step 3 (index 2) in 8m mode highlights Team A for throw animation
        if mode == .eightMeter && step == 2 && type == .teamA {
            return true
        }
        // Blasting mode: don't highlight stakes after step 1
        if mode == .blasting && step > 0 && (type == .corners || type == .midstakes) {
            return false
        }
        return highlight == type || highlight == .all
    }

    private func throwingLineLabel() -> (text: String, y: CGFloat) {
        let fieldH: CGFloat = 800 // Will be scaled by geometry reader
        let padding: CGFloat = 48
        let innerH: CGFloat = fieldH - padding * 2

        switch mode {
        case .eightMeter:
            return ("THROW FROM HERE", fieldH - padding - 10)
        case .blasting:
            return ("4M LINE", padding + (innerH / 2) - 14)
        case .inkasting:
            return ("THROW FROM HERE", fieldH - padding - 10)
        }
    }

    private func playerPosition(fieldW: CGFloat, fieldH: CGFloat, padding: CGFloat) -> (x: CGFloat, y: CGFloat) {
        if mode == .eightMeter {
            let x = fieldW / 2
            let y = step == 5 ? padding - 45 : fieldH - padding + 45
            return (x, y)
        } else if mode == .blasting {
            let x = fieldW - padding
            let y = fieldH - padding + 45
            return (x, y)
        } else { // inkasting mode
            let x = fieldW - padding - 20
            let y = fieldH - padding + 45
            return (x, y)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let fieldW = geometry.size.width
            let fieldH = geometry.size.height
            let padding = fieldW * 0.096
            let innerW = fieldW - padding * 2
            let innerH = fieldH - padding * 2

            ZStack {
                // Field Canvas (static elements)
                Canvas { context, size in
                    // Dark grass background - neutral dark tone for better text contrast
                    context.fill(
                        Path(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerRadius: 8),
                        with: .color(Color(red: 0.15, green: 0.18, blue: 0.15))
                    )

                    // Inner grass field - darker, desaturated for contrast with all phase colors
                    let grassRect = CGRect(x: padding, y: padding, width: innerW, height: innerH)
                    context.fill(
                        Path(roundedRect: grassRect, cornerRadius: 4),
                        with: .color(Color(red: 0.20, green: 0.25, blue: 0.20))
                    )

                    // Grass pattern - subtle texture
                    var grassPath = Path()
                    for i in stride(from: padding, through: padding + innerH, by: 20) {
                        grassPath.move(to: CGPoint(x: padding, y: i))
                        grassPath.addLine(to: CGPoint(x: padding + innerW, y: i))
                    }
                    for i in stride(from: padding, through: padding + innerW, by: 20) {
                        grassPath.move(to: CGPoint(x: i, y: padding))
                        grassPath.addLine(to: CGPoint(x: i, y: padding + innerH))
                    }
                    context.stroke(
                        grassPath,
                        with: .color(Color(red: 0.25, green: 0.30, blue: 0.25).opacity(0.2)),
                        lineWidth: 0.5
                    )

                    // Field border
                    let borderColor: Color = showCorners ? mode.color : Color(.systemGray4)
                    context.stroke(
                        Path(roundedRect: grassRect, cornerRadius: 4),
                        with: .color(borderColor),
                        style: StrokeStyle(lineWidth: 2, dash: showCorners ? [] : [6, 4])
                    )

                    // Opponent baseline strip (Swedish blue) — far end
                    let oppBaseline = CGRect(x: padding, y: padding, width: innerW, height: 5)
                    context.fill(Path(oppBaseline), with: .color(Color(hex: "006AA7").opacity(0.75)))

                    // Player baseline strip (phase color) — near end
                    let plyBaseline = CGRect(x: padding, y: size.height - padding - 5, width: innerW, height: 5)
                    context.fill(Path(plyBaseline), with: .color(mode.color.opacity(0.75)))

                    // Centerline (8m and inkasting modes)
                    if mode != .blasting {
                        let centerlineColor: Color = showMid ? mode.color : Color(.systemGray5)
                        var centerPath = Path()
                        centerPath.move(to: CGPoint(x: padding, y: size.height / 2))
                        centerPath.addLine(to: CGPoint(x: size.width - padding, y: size.height / 2))
                        context.stroke(
                            centerPath,
                            with: .color(centerlineColor),
                            style: StrokeStyle(lineWidth: showMid ? 1.5 : 1, dash: [8, 5])
                        )
                    }

                    // Blasting 4m line
                    if mode == .blasting && showBlastingLine {
                        let blastingY = padding + (innerH / 2) // 4m from far baseline
                        let lineColor: Color = isHighlighted(.blastingLine) ? mode.color : mode.color.opacity(0.6)
                        var blastingPath = Path()
                        blastingPath.move(to: CGPoint(x: padding, y: blastingY))
                        blastingPath.addLine(to: CGPoint(x: size.width - padding, y: blastingY))
                        context.stroke(
                            blastingPath,
                            with: .color(lineColor),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 5])
                        )
                    }

                    // Target zone highlight (inkasting)
                    if showTargetZone {
                        let targetRect = CGRect(x: padding, y: padding, width: innerW, height: innerH / 2)
                        context.fill(
                            Path(roundedRect: targetRect, cornerRadius: 4),
                            with: .color(mode.color.opacity(isHighlighted(.targetZone) ? 0.15 : 0.08))
                        )
                    }

                    // Throwing line indicator
                    if showThrowingLine {
                        let throwLineY: CGFloat
                        switch mode {
                        case .eightMeter, .inkasting:
                            throwLineY = fieldH - padding
                        case .blasting:
                            throwLineY = padding + (innerH / 2)
                        }

                        let lineColor = isHighlighted(.throwingLine) ? mode.color : mode.color.opacity(0.4)
                        var throwPath = Path()
                        throwPath.move(to: CGPoint(x: padding, y: throwLineY))
                        throwPath.addLine(to: CGPoint(x: size.width - padding, y: throwLineY))
                        context.stroke(
                            throwPath,
                            with: .color(lineColor),
                            style: StrokeStyle(lineWidth: isHighlighted(.throwingLine) ? 3 : 2)
                        )
                    }
                }

                // Target labels - position changes on step 6
                if showTeamA && mode != .inkasting && step != 5 {
                    Text("TARGETS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .tracking(2)
                        .foregroundColor(mode.color.opacity(0.8))
                        .position(x: fieldW / 2, y: padding + 30)
                        .transition(.opacity)
                }

                // Step 6: TARGETS label on Team B (near baseline)
                if mode == .eightMeter && step == 5 {
                    Text("TARGETS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .tracking(2)
                        .foregroundColor(mode.color.opacity(0.8))
                        .position(x: fieldW / 2, y: fieldH - padding - 30)
                        .transition(.opacity)
                }

                // Step 6: YOUR KUBBS label on Team A (far baseline)
                if mode == .eightMeter && step == 5 {
                    Text("YOUR KUBBS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .tracking(2)
                        .foregroundColor(mode.color.opacity(0.8))
                        .position(x: fieldW / 2, y: padding + 30)
                        .transition(.opacity)
                }

                // Throwing position label
                if showThrowingLine {
                    let label = throwingLineLabel()
                    Text(label.text)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .tracking(2)
                        .foregroundColor(mode.color.opacity(0.8))
                        .position(x: fieldW / 2, y: label.y)
                        .transition(.opacity)
                }

                // Dimension labels
                if showCorners {
                    Text("5 m")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(Color.white.opacity(0.6))
                        .position(x: fieldW / 2, y: padding - 25)

                    Text("8 m")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(Color.white.opacity(0.6))
                        .rotationEffect(.degrees(90))
                        .position(x: fieldW - padding + 15, y: fieldH / 2)
                }

                // Corner stakes
                if showCorners {
                    ForEach(0..<4, id: \.self) { i in
                        let positions: [CGPoint] = [
                            CGPoint(x: padding, y: padding),
                            CGPoint(x: fieldW - padding, y: padding),
                            CGPoint(x: fieldW - padding, y: fieldH - padding),
                            CGPoint(x: padding, y: fieldH - padding)
                        ]
                        StakeView(
                            color: mode.color,
                            isHighlighted: isHighlighted(.corners),
                            delay: Double(i) * 0.08
                        )
                        .position(positions[i])
                    }
                }

                // Mid stakes (8m and inkasting)
                if showMid {
                    ForEach(0..<2, id: \.self) { i in
                        let positions: [CGPoint] = [
                            CGPoint(x: padding, y: fieldH / 2),
                            CGPoint(x: fieldW - padding, y: fieldH / 2)
                        ]
                        StakeView(
                            color: mode.color,
                            isHighlighted: isHighlighted(.midstakes),
                            delay: Double(i) * 0.1
                        )
                        .position(positions[i])
                    }
                }

                // Blasting line stakes
                if showBlastingLine {
                    ForEach(0..<2, id: \.self) { i in
                        let blastingY = padding + (innerH / 2)
                        let positions: [CGPoint] = [
                            CGPoint(x: padding, y: blastingY),
                            CGPoint(x: fieldW - padding, y: blastingY)
                        ]
                        StakeView(
                            color: mode.color,
                            isHighlighted: isHighlighted(.blastingLine),
                            delay: Double(i) * 0.1
                        )
                        .position(positions[i])
                    }
                }

                // Target kubbs (far baseline - Team A)
                if showTeamA {
                    let kubbMargin: CGFloat = 28
                    let kubbAreaWidth = innerW - (kubbMargin * 2)
                    ForEach(0..<5, id: \.self) { i in
                        let isHit = hitKubbs.contains(i)
                        KubbView(
                            color: isHit ? Color.gray : mode.color,
                            isHighlighted: isHit ? false : isHighlighted(.teamA),
                            delay: Double(i) * 0.08
                        )
                        .position(
                            x: padding + kubbMargin + (kubbAreaWidth / 4) * CGFloat(i),
                            y: padding
                        )
                    }
                }

                // Your baseline kubbs (Team B) - 8m mode only
                if showTeamB {
                    let kubbMargin: CGFloat = 28
                    let kubbAreaWidth = innerW - (kubbMargin * 2)
                    ForEach(0..<5, id: \.self) { i in
                        KubbView(
                            color: mode.color,
                            isHighlighted: isHighlighted(.teamB),
                            delay: Double(i) * 0.08 + 0.4
                        )
                        .position(
                            x: padding + kubbMargin + (kubbAreaWidth / 4) * CGFloat(i),
                            y: fieldH - padding
                        )
                    }
                }

                // King (8m mode only)
                if showKing {
                    KingView(
                        color: mode.color,
                        isHighlighted: isHighlighted(.king)
                    )
                    .position(x: fieldW / 2, y: fieldH / 2)
                }

                // Player figure
                if (mode == .eightMeter && step >= 1 && step != 4) ||
                   (mode == .blasting && step >= 1) ||
                   (mode == .inkasting && step >= 2) {
                    let pos = playerPosition(fieldW: fieldW, fieldH: fieldH, padding: padding)
                    PersonView(
                        color: mode.color,
                        delay: 0.6,
                        isHighlighted: (mode == .eightMeter && step == 2) ||
                                      (mode == .inkasting && step == 2)
                    )
                    .position(x: pos.x, y: pos.y)
                }

                // Bullseye target (inkasting mode, step 2+)
                if mode == .inkasting && (step == 1 || step == 2) && showBullseyeTarget {
                    let bullseyeX = fieldW / 2 + innerW * 0.45
                    let bullseyeY = padding + innerH * 0.45

                    // Bullseye circles (concentric rings)
                    Canvas { context, size in
                        // Outer ring (largest)
                        let outerRadius: CGFloat = 35
                        let outerPath = Path(ellipseIn: CGRect(
                            x: bullseyeX - outerRadius,
                            y: bullseyeY - outerRadius,
                            width: outerRadius * 2,
                            height: outerRadius * 2
                        ))
                        context.stroke(outerPath, with: .color(Color.red.opacity(0.6)), lineWidth: 3)

                        // Middle ring
                        let middleRadius: CGFloat = 23
                        let middlePath = Path(ellipseIn: CGRect(
                            x: bullseyeX - middleRadius,
                            y: bullseyeY - middleRadius,
                            width: middleRadius * 2,
                            height: middleRadius * 2
                        ))
                        context.stroke(middlePath, with: .color(Color.red.opacity(0.7)), lineWidth: 3)

                        // Inner ring
                        let innerRadius: CGFloat = 12
                        let innerPath = Path(ellipseIn: CGRect(
                            x: bullseyeX - innerRadius,
                            y: bullseyeY - innerRadius,
                            width: innerRadius * 2,
                            height: innerRadius * 2
                        ))
                        context.fill(innerPath, with: .color(Color.red.opacity(0.8)))
                    }
                    .allowsHitTesting(false)

                    Text("TARGET")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .tracking(1)
                        .foregroundColor(.red)
                        .position(x: bullseyeX, y: bullseyeY - 50)
                }

                // Camera icon (inkasting mode, step 3)
                if mode == .inkasting && step >= 2 && showCameraIcon {
                    let cameraX = fieldW - padding + 40
                    let cameraY = fieldH / 2

                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                        .foregroundColor(mode.color)
                        .position(x: cameraX, y: cameraY)

                    Text("CAMERA")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .tracking(1)
                        .foregroundColor(mode.color)
                        .position(x: cameraX, y: cameraY + 25)
                }

                // Kubbs next to player (blasting mode, step 2 only)
                if mode == .blasting && step == 1 {
                    ForEach(0..<2, id: \.self) { i in
                        KubbView(
                            color: mode.color,
                            isHighlighted: false,
                            delay: Double(i) * 0.1 + 0.5
                        )
                        .position(
                            x: fieldW - padding - 50 + CGFloat(i) * 25,
                            y: fieldH - padding + 45
                        )
                    }
                }

                // Animated field kubb 1 (blasting mode, step 3)
                if mode == .blasting && step >= 2 {
                    let startX = fieldW - padding
                    let startY = fieldH - padding + 45
                    let targetX = fieldW - padding - 40 // Close to right sideline
                    let targetY = fieldH / 2 - 30 // Just past midline into top half

                    let tfk1 = fieldKubb1Progress
                    let midXfk1 = (startX + targetX) / 2
                    let arcYfk1 = min(startY, targetY) - 45
                    let currentX = (1-tfk1)*(1-tfk1)*startX + 2*(1-tfk1)*tfk1*midXfk1 + tfk1*tfk1*targetX
                    let currentY = (1-tfk1)*(1-tfk1)*startY + 2*(1-tfk1)*tfk1*arcYfk1 + tfk1*tfk1*targetY

                    KubbView(color: mode.color, isHighlighted: false, delay: 0)
                        .position(x: currentX, y: currentY)
                }

                // Animated field kubb 2 (blasting mode, step 3)
                if mode == .blasting && step >= 2 {
                    let startX = fieldW - padding
                    let startY = fieldH - padding + 45
                    let targetX = fieldW - padding - 25 // Very close to right sideline
                    let targetY = fieldH / 2 - 50 // Further past midline into top half

                    let tfk2 = fieldKubb2Progress
                    let midXfk2 = (startX + targetX) / 2
                    let arcYfk2 = min(startY, targetY) - 38
                    let currentX = (1-tfk2)*(1-tfk2)*startX + 2*(1-tfk2)*tfk2*midXfk2 + tfk2*tfk2*targetX
                    let currentY = (1-tfk2)*(1-tfk2)*startY + 2*(1-tfk2)*tfk2*arcYfk2 + tfk2*tfk2*targetY

                    KubbView(color: mode.color, isHighlighted: false, delay: 0)
                        .position(x: currentX, y: currentY)
                }

                // Field Kubbs label (blasting mode, step 3)
                if showFieldKubbsLabel && mode == .blasting && step >= 2 {
                    Text("FIELD KUBBS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(2)
                        .foregroundColor(mode.color.opacity(0.8))
                        .position(x: fieldW - padding - 60, y: fieldH / 2 - 100)
                        .transition(.opacity)
                }

                // Blasting baton (step 4)
                if mode == .blasting && step >= 3 {
                    let startX = fieldW - padding
                    let startY = fieldH - padding + 60 // Behind player
                    let targetX = fieldW - padding - 40 // First field kubb
                    let targetY = fieldH / 2 - 10

                    let tb = blastingBatonProgress
                    let midXb = (startX + targetX) / 2
                    let arcYb = min(startY, targetY) - 50
                    let currentX = (1-tb)*(1-tb)*startX + 2*(1-tb)*tb*midXb + tb*tb*targetX
                    let currentY = (1-tb)*(1-tb)*startY + 2*(1-tb)*tb*arcYb + tb*tb*targetY

                    BatonView(color: mode.color)
                        .position(x: currentX, y: currentY)
                }

                // Blasting HIT message 1 (step 4)
                if showBlastingHit1 && mode == .blasting && step >= 3 {
                    let targetX = fieldW - padding - 40
                    let targetY = fieldH / 2 - 30

                    Text("HIT")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(KubbColors.forestGreen)
                        .cornerRadius(8)
                        .position(x: targetX, y: targetY - 35)
                        .transition(.scale.combined(with: .opacity))
                }

                // Blasting HIT message 2 (step 4)
                if showBlastingHit2 && mode == .blasting && step >= 3 {
                    let targetX = fieldW - padding - 25
                    let targetY = fieldH / 2 - 40

                    Text("HIT")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(KubbColors.forestGreen)
                        .cornerRadius(8)
                        .position(x: targetX, y: targetY - 35)
                        .transition(.scale.combined(with: .opacity))
                }

                // First baton (step 3 - 8m mode)
                if mode == .eightMeter && (step == 2 || step == 3) {
                    let startX = fieldW / 2
                    let startY = fieldH - padding + 35 // Start from player position
                    let kubbMargin: CGFloat = 28
                    let targetX = padding + kubbMargin // Far left kubb
                    let targetY = padding

                    let t1 = batonProgress
                    let midX1 = (startX + targetX) / 2
                    let arcY1 = min(startY, targetY) - 65
                    let currentX = (1-t1)*(1-t1)*startX + 2*(1-t1)*t1*midX1 + t1*t1*targetX
                    let currentY = (1-t1)*(1-t1)*startY + 2*(1-t1)*t1*arcY1 + t1*t1*targetY

                    BatonView(color: step == 3 ? Color.gray : mode.color)
                        .position(x: currentX, y: currentY)
                        .opacity(step == 3 ? 0.5 : 1.0)
                }

                // Second baton (step 4 - 8m mode, goes to center kubb)
                if mode == .eightMeter && step == 3 {
                    let startX = fieldW / 2
                    let startY = fieldH - padding + 35
                    let kubbMargin: CGFloat = 28
                    let kubbAreaWidth = innerW - (kubbMargin * 2)
                    let targetX = padding + kubbMargin + (kubbAreaWidth / 4) * 2 // Center kubb (index 2)
                    let targetY = padding

                    // Stop at 85% for a miss — parabolic arc
                    let missProgress = min(baton2Progress, 0.85)
                    let t2 = missProgress
                    let midX2 = (startX + targetX) / 2
                    let arcY2 = min(startY, targetY) - 55
                    let currentX = (1-t2)*(1-t2)*startX + 2*(1-t2)*t2*midX2 + t2*t2*targetX
                    let currentY = (1-t2)*(1-t2)*startY + 2*(1-t2)*t2*arcY2 + t2*t2*targetY

                    BatonView(color: mode.color)
                        .position(x: currentX, y: currentY)
                }

                // Hit message
                if showHitMessage && mode == .eightMeter && (step == 2 || step == 3) {
                    let kubbMargin: CGFloat = 28
                    let targetX = padding + kubbMargin
                    let targetY = padding

                    Text("HIT")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(KubbColors.forestGreen)
                        .cornerRadius(8)
                        .position(x: targetX, y: targetY - 35)
                        .transition(.scale.combined(with: .opacity))
                        .opacity(step == 3 ? 0.5 : 1.0)
                }

                // Miss message
                if showMissMessage && mode == .eightMeter && step == 3 {
                    let kubbMargin: CGFloat = 28
                    let kubbAreaWidth = innerW - (kubbMargin * 2)
                    let targetX = padding + kubbMargin + (kubbAreaWidth / 4) * 2 // Center kubb
                    let targetY = padding

                    Text("MISS")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(KubbColors.miss)
                        .cornerRadius(8)
                        .position(x: targetX, y: targetY - 35)
                        .transition(.scale.combined(with: .opacity))
                }

                // Animated kubbs (inkasting mode, steps 4+)
                if mode == .inkasting && step >= 3 {
                    let startX = fieldW - padding - 20
                    let startY = fieldH - padding + 45
                    let clusterCenterX = fieldW / 2 + innerW * 0.3
                    let clusterCenterY = padding + innerH * 0.3

                    // Define kubb positions relative to cluster center
                    let kubbOffsets: [(x: CGFloat, y: CGFloat)] = [
                        (0, 0),           // Kubb 1 - center
                        (-20, -15),       // Kubb 2 - left-up
                        (18, -12),        // Kubb 3 - right-up
                        (-25, 20),        // Kubb 4 - left-down
                        (30, 55)          // Kubb 5 - right-down (outlier)
                    ]

                    let kubbProgresses = [inkastingKubb1Progress, inkastingKubb2Progress,
                                         inkastingKubb3Progress, inkastingKubb4Progress,
                                         inkastingKubb5Progress]

                    ForEach(0..<5, id: \.self) { i in
                        if kubbProgresses[i] >= 0 {
                            let targetX = clusterCenterX + kubbOffsets[i].x
                            let targetY = clusterCenterY + kubbOffsets[i].y
                            // Parabolic arc for underhand kubb throw
                            let tp = kubbProgresses[i]
                            let midXp = (startX + targetX) / 2
                            let arcYp = min(startY, targetY) - 46
                            let currentX = (1-tp)*(1-tp)*startX + 2*(1-tp)*tp*midXp + tp*tp*targetX
                            let currentY = (1-tp)*(1-tp)*startY + 2*(1-tp)*tp*arcYp + tp*tp*targetY

                            // Kubb 5 (index 4) changes color when outlier is highlighted
                            let kubbColor = (i == 4 && highlightOutlier) ? Color.orange : mode.color

                            KubbView(color: kubbColor, isHighlighted: highlightOutlier && i == 4, delay: 0)
                                .position(x: currentX, y: currentY)
                        }
                    }
                }

                // Cluster visualization overlays (inkasting steps 5-7)
                if mode == .inkasting && step >= 4 {
                    let clusterCenterX = fieldW / 2 + innerW * 0.3
                    let clusterCenterY = padding + innerH * 0.3

                    // Cluster center crosshair (step 6)
                    if showClusterCenter {
                        Canvas { context, size in
                            let crosshairSize: CGFloat = 15
                            var path = Path()
                            path.move(to: CGPoint(x: clusterCenterX - crosshairSize, y: clusterCenterY))
                            path.addLine(to: CGPoint(x: clusterCenterX + crosshairSize, y: clusterCenterY))
                            path.move(to: CGPoint(x: clusterCenterX, y: clusterCenterY - crosshairSize))
                            path.addLine(to: CGPoint(x: clusterCenterX, y: clusterCenterY + crosshairSize))
                            context.stroke(path, with: .color(.blue), lineWidth: 2)
                        }
                        .allowsHitTesting(false)

                        Text("CLUSTER CENTER")
                            .font(.caption)
                            .fontWeight(.bold)
                            .tracking(1)
                            .foregroundColor(.blue)
                            .position(x: clusterCenterX - 140, y: clusterCenterY)
                    }

                    // Core circle (step 7)
                    if showCoreCircle {
                        Circle()
                            .stroke(mode.color.opacity(0.6), lineWidth: 3)
                            .frame(width: 65, height: 65)
                            .position(x: clusterCenterX, y: clusterCenterY)

                        Text("CORE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .tracking(1)
                            .foregroundColor(mode.color)
                            .position(x: clusterCenterX, y: clusterCenterY - 40)
                    }

                    // Target radius circle (step 7)
                    if showTargetCircle {
                        Canvas { context, size in
                            let radius: CGFloat = 50
                            let circlePath = Path(ellipseIn: CGRect(
                                x: clusterCenterX - radius,
                                y: clusterCenterY - radius,
                                width: radius * 2,
                                height: radius * 2
                            ))
                            context.stroke(
                                circlePath,
                                with: .color(.orange.opacity(0.7)),
                                style: StrokeStyle(lineWidth: 3, dash: [6, 4])
                            )
                        }
                        .allowsHitTesting(false)

                        Text("TARGET RADIUS")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .tracking(1)
                            .foregroundColor(.orange)
                            .position(x: clusterCenterX, y: clusterCenterY - 65)
                    }

                    // Outlier label (step 8)
                    if highlightOutlier {
                        Text("OUTLIER")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .tracking(1)
                            .foregroundColor(.orange)
                            .position(x: clusterCenterX - 15, y: clusterCenterY + 65)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .id(animationTrigger)
            .onChange(of: step) { oldValue, newValue in
                // Trigger animation when entering step 3 (index 2)
                if newValue == 2 && mode == .eightMeter {
                    // Reset animation state
                    batonProgress = 0
                    showHitMessage = false
                    hitKubbs = []

                    // Start baton throw animation (slow for clear visibility)
                    withAnimation(.easeInOut(duration: 3.0).delay(0.5)) {
                        batonProgress = 1.0
                    }

                    // Show hit message after baton reaches target
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.7) {
                        withAnimation(.spring(response: 0.4)) {
                            showHitMessage = true
                            hitKubbs.insert(0) // Mark first kubb as hit
                        }
                    }
                }

                // Trigger animation when entering step 4 (index 3)
                if newValue == 3 && mode == .eightMeter {
                    // Reset second throw animation state
                    baton2Progress = 0
                    showMissMessage = false
                    missedKubbs = []

                    // Start second baton throw animation
                    withAnimation(.easeInOut(duration: 3.0).delay(0.5)) {
                        baton2Progress = 1.0
                    }

                    // Show miss message after baton stops short
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.7) {
                        withAnimation(.spring(response: 0.4)) {
                            showMissMessage = true
                            missedKubbs.insert(2) // Mark center kubb as missed
                        }
                    }
                }

                // Trigger animation when entering step 3 (index 2) - Blasting mode
                if newValue == 2 && mode == .blasting {
                    // Reset animation state
                    fieldKubb1Progress = 0
                    fieldKubb2Progress = 0
                    showFieldKubbsLabel = false

                    // Throw first kubb (linear for direct path)
                    withAnimation(.linear(duration: 0.75).delay(0.5)) {
                        fieldKubb1Progress = 1.0
                    }

                    // Throw second kubb after first lands
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                        withAnimation(.linear(duration: 0.75)) {
                            fieldKubb2Progress = 1.0
                        }
                    }

                    // Show field kubbs label after both land
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showFieldKubbsLabel = true
                        }
                    }
                }

                // Trigger animation when entering step 4 (index 3) - Blasting mode
                if newValue == 3 && mode == .blasting {
                    // Reset animation state
                    blastingBatonProgress = 0
                    showBlastingHit1 = false
                    showBlastingHit2 = false

                    // Throw baton
                    withAnimation(.linear(duration: 0.75).delay(0.5)) {
                        blastingBatonProgress = 1.0
                    }

                    // Show first HIT after baton reaches
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                        withAnimation(.spring(response: 0.4)) {
                            showBlastingHit1 = true
                        }
                    }

                    // Show second HIT immediately after first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.75) {
                        withAnimation(.spring(response: 0.4)) {
                            showBlastingHit2 = true
                        }
                    }
                }

                // Step 2: Show bullseye target (index 1) - Inkasting mode
                if newValue == 1 && mode == .inkasting {
                    showBullseyeTarget = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            showBullseyeTarget = true
                        }
                    }
                }

                // Step 3: Show camera icon (index 2) - Inkasting mode
                if newValue == 2 && mode == .inkasting {
                    showCameraIcon = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showCameraIcon = true
                        }
                    }
                }

                // Step 4: Throw kubbs (index 3) - Inkasting mode
                if newValue == 3 && mode == .inkasting {
                    // Reset state
                    inkastingKubb1Progress = 0
                    inkastingKubb2Progress = 0
                    inkastingKubb3Progress = 0
                    inkastingKubb4Progress = 0
                    inkastingKubb5Progress = 0

                    // Throw kubbs with stagger
                    withAnimation(.linear(duration: 0.75).delay(0.3)) {
                        inkastingKubb1Progress = 1.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.linear(duration: 0.75)) {
                            inkastingKubb2Progress = 1.0
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        withAnimation(.linear(duration: 0.75)) {
                            inkastingKubb3Progress = 1.0
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        withAnimation(.linear(duration: 0.75)) {
                            inkastingKubb4Progress = 1.0
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                        withAnimation(.linear(duration: 0.75)) {
                            inkastingKubb5Progress = 1.0
                        }
                    }
                }

                // Step 5: Show cluster analysis (index 4) - Inkasting mode
                if newValue == 4 && mode == .inkasting {
                    // Reset all visualization states
                    showClusterCenter = false
                    showCoreCircle = false
                    showTargetCircle = false
                    highlightOutlier = false

                    // 1. Show cluster center immediately for instant feedback
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showClusterCenter = true
                        }
                    }

                    // 2. Show core circle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                            showCoreCircle = true
                        }
                    }

                    // 3. Show target radius circle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                            showTargetCircle = true
                        }
                    }

                    // 4. Highlight outlier with more pronounced animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                            highlightOutlier = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Blasting Scorecard

struct BlastingScorecardView: View {
    let rounds = [
        (round: 1, kubbs: 2, par: 2),
        (round: 2, kubbs: 3, par: 2),
        (round: 3, kubbs: 4, par: 3),
        (round: 4, kubbs: 5, par: 3),
        (round: 5, kubbs: 6, par: 3),
        (round: 6, kubbs: 7, par: 4),
        (round: 7, kubbs: 8, par: 4),
        (round: 8, kubbs: 9, par: 4),
        (round: 9, kubbs: 10, par: 5)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("Round")
                    .frame(width: 60)
                    .font(.caption)
                    .fontWeight(.bold)

                Text("Kubbs")
                    .frame(width: 60)
                    .font(.caption)
                    .fontWeight(.bold)

                Text("Par")
                    .frame(width: 50)
                    .font(.caption)
                    .fontWeight(.bold)

                Text("Score")
                    .frame(width: 60)
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .background(KubbColors.phase4m)

            // Rows
            ForEach(rounds, id: \.round) { item in
                HStack(spacing: 0) {
                    Text("\(item.round)")
                        .frame(width: 60)
                        .font(.caption)

                    Text("\(item.kubbs)")
                        .frame(width: 60)
                        .font(.caption)

                    Text("\(item.par)")
                        .frame(width: 50)
                        .font(.caption)

                    Text(item.round == 1 ? "1" : "")
                        .frame(width: 60)
                        .font(.caption)
                        .fontWeight(item.round == 1 ? .bold : .regular)
                }
                .foregroundColor(.white)
                .padding(.vertical, 6)
                .background(item.round % 2 == 0 ? Color.white.opacity(0.05) : Color.clear)
            }
        }
        .background(KubbColors.trainingSurface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KubbColors.phase4m.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Component Views

struct StakeView: View {
    let color: Color
    let isHighlighted: Bool
    let delay: Double

    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.42, green: 0.27, blue: 0.14))
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color(red: 0.23, green: 0.12, blue: 0), lineWidth: 1.5)
                )

            if isHighlighted {
                Circle()
                    .stroke(color, lineWidth: 1.5)
                    .frame(width: 20, height: 20)
                    .opacity(0.6)
            }
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).delay(delay)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

struct KubbView: View {
    let color: Color
    let isHighlighted: Bool
    let delay: Double

    @State private var dropOffset: CGFloat = -44
    @State private var opacity: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(isHighlighted ?
                  Color(red: 0.91, green: 0.79, blue: 0.48) :
                  Color(red: 0.83, green: 0.66, blue: 0.42))
            .frame(width: 18, height: 28)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(
                        isHighlighted ? color : Color(red: 0.54, green: 0.37, blue: 0.16),
                        lineWidth: isHighlighted ? 2.5 : 1.5
                    )
            )
            .shadow(
                color: isHighlighted ? color.opacity(0.6) : .clear,
                radius: isHighlighted ? 6 : 0
            )
            .offset(y: dropOffset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(delay)) {
                    dropOffset = 0
                    opacity = 1.0
                }
            }
    }
}

struct KingView: View {
    let color: Color
    let isHighlighted: Bool

    @State private var opacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowRadius: CGFloat = 6

    var body: some View {
        ZStack {
            // King body
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.91, green: 0.79, blue: 0.48))
                .frame(width: 22, height: 30.8) // 22 * 1.4
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isHighlighted ? color : Color(red: 0.54, green: 0.37, blue: 0.16), lineWidth: 2)
                )

            // Crown notches
            HStack(spacing: 1) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(red: 0.91, green: 0.79, blue: 0.48))
                        .frame(width: 5, height: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 1)
                                .stroke(Color(red: 0.54, green: 0.37, blue: 0.16), lineWidth: 1.5)
                        )
                }
            }
            .offset(y: -22)

            // K label
            Text("K")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundColor(Color(red: 0.23, green: 0.12, blue: 0))
                .offset(y: 2)
        }
        .shadow(
            color: isHighlighted ? color.opacity(glowRadius * 0.1) : .clear,
            radius: glowRadius
        )
        .scaleEffect(pulseScale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.6)) {
                opacity = 1.0
            }
            if isHighlighted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                        pulseScale = 1.18
                        glowRadius = 16
                    }
                }
            }
        }
    }
}

struct PersonView: View {
    let color: Color
    let delay: Double
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 3) {
            // Head
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)

            // Body
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 24, height: 32)
        }
        .shadow(
            color: isHighlighted ? color.opacity(0.8) : .clear,
            radius: isHighlighted ? 12 : 0
        )
        .shadow(
            color: isHighlighted ? color.opacity(0.6) : .clear,
            radius: isHighlighted ? 20 : 0
        )
        .opacity(0.8)
    }
}

struct BatonView: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color(red: 0.83, green: 0.66, blue: 0.42))
            .frame(width: 9, height: 36)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color(red: 0.54, green: 0.37, blue: 0.16), lineWidth: 1.5)
            )
            .rotationEffect(.degrees(-45))
    }
}

// MARK: - Button Style

struct StepButtonStyle: ButtonStyle {
    let color: Color
    let isDisabled: Bool
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                isPrimary && !isDisabled ? color : Color.clear
            )
            .foregroundColor(
                isPrimary && !isDisabled ? .white : color
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color, lineWidth: 1.5)
            )
            .cornerRadius(10)
            .opacity(isDisabled ? 0.4 : (configuration.isPressed ? 0.8 : 1.0))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("8 Meter") {
    KubbFieldSetupView(mode: .eightMeter)
}

#Preview("Blasting") {
    KubbFieldSetupView(mode: .blasting)
}

#Preview("Inkasting") {
    KubbFieldSetupView(mode: .inkasting)
}
