import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        #if os(iOS)
        NavigationStack {
            ScrollView {
                onboardingContent(showCloseButton: false)
                    .safeAreaPadding(.horizontal, 24)
                    .safeAreaPadding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("CheatSheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: finish)
                }
            }
        }
        #else
        ZStack {
            AppBackdrop()

            ScrollView {
                onboardingContent(showCloseButton: true)
                .padding(28)
                .frame(idealWidth: 560, maxWidth: 620)
                .liquidGlassPanel(tint: Color(hex: CheatSheetPalette.blue.rawValue), cornerRadius: 30)
                .padding(28)
            }
        }
        #endif
    }

    private func onboardingContent(showCloseButton: Bool) -> some View {
        VStack(alignment: .leading, spacing: onboardingSpacing) {
            header(showCloseButton: showCloseButton)

            stepGroup

            VStack(spacing: onboardingPreviewSpacing) {
                OnboardingStartButton(action: finish)
                    .frame(maxWidth: 260)

                StickyNotePreview(note: CheatSheetNote.starterNotes[0])
                    .frame(maxWidth: onboardingPreviewMaxWidth)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func header(showCloseButton: Bool) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CheatSheet")
                    .font(.largeTitle)
                    .bold()

                Text("100% free and open source. Liquid Glass notes for the coding commands you reach for every day.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if showCloseButton {
                Button("Close", systemImage: "xmark", action: finish)
                    .labelStyle(.iconOnly)
                    .glassCompatibleButtonStyle()
                    .help("Close")
            }
        }
    }

    private var stepGroup: some View {
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
                    description: "Choose Use in Widget, then add the CheatSheet widget on supported platforms."
                )
            }
        }
    }

    private var onboardingSpacing: CGFloat {
        #if os(iOS)
        18
        #else
        22
        #endif
    }

    private var onboardingPreviewSpacing: CGFloat {
        #if os(iOS)
        14
        #else
        18
        #endif
    }

    private var onboardingPreviewMaxWidth: CGFloat {
        #if os(iOS)
        340
        #else
        400
        #endif
    }

    private func finish() {
        hasCompletedOnboarding = true
        dismiss()
    }
}
