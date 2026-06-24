import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CheatSheet")
                                .font(.largeTitle)
                                .bold()

                            Text("Liquid Glass notes for the coding commands you reach for every day.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Button("Close", systemImage: "xmark", action: finish)
                            .labelStyle(.iconOnly)
                            .glassCompatibleButtonStyle()
                            .help("Close")
                    }

                    LiquidGlassGroup(spacing: 12) {
                        VStack(spacing: 12) {
                            OnboardingStepRow(
                                symbol: "plus",
                                title: "Add notes",
                                description: "Use the plus button to create small Git, Swift, terminal, or project checklists."
                            )

                            OnboardingStepRow(
                                symbol: "paintpalette",
                                title: "Tune the look",
                                description: "Pick a color or font above the editor and the widget follows that style."
                            )

                            OnboardingStepRow(
                                symbol: "pin.fill",
                                title: "Pin the widget note",
                                description: "Choose Use in Widget, then add the CheatSheet widget from macOS widgets."
                            )
                        }
                    }

                    VStack(spacing: 18) {
                        StickyNotePreview(note: CheatSheetNote.starterNotes[0])
                            .frame(maxWidth: 400)

                        OnboardingStartButton(action: finish)
                            .frame(maxWidth: 260)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(28)
                .frame(idealWidth: 560, maxWidth: 620)
                .liquidGlassPanel(tint: Color(hex: CheatSheetPalette.blue.rawValue), cornerRadius: 30)
                .padding(28)
            }
        }
    }

    private func finish() {
        hasCompletedOnboarding = true
        dismiss()
    }
}
