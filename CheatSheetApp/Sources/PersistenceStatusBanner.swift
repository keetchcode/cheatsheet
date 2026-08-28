import SwiftUI

/// Shows storage problems that the user would otherwise never see. Notes are
/// held in memory, so a failed load or save is invisible until the app is
/// relaunched and the work is gone.
struct PersistenceStatusBanner: View {
    let status: PersistenceStatus
    let canRetryLoad: Bool
    let retryAction: () -> Void

    var body: some View {
        if let message = failureMessage {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))

                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if canRetryLoad {
                    Button("Try Again", action: retryAction)
                        .controlSize(.small)
                        .accessibilityIdentifier("persistence-retry-button")
                }
            }
            .padding(.horizontal, AppDesign.panelPadding)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .overlay(alignment: .bottom) {
                Divider()
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("persistence-status-banner")
        }
    }

    private var title: String {
        canRetryLoad
            ? String(localized: "persistence.title.loadFailed", defaultValue: "Notes could not be opened")
            : String(localized: "persistence.title.saveFailed", defaultValue: "Changes are not being saved")
    }

    private var failureMessage: String? {
        switch status {
        case let .loadFailed(message):
            canRetryLoad
                ? String(
                    localized: "persistence.loadFailed.retryable",
                    defaultValue: "\(message) Editing is paused so your stored notes are not overwritten."
                )
                : message
        case let .saveFailed(message):
            String(
                localized: "persistence.saveFailed.suffix",
                defaultValue: "\(message) Recent edits are only in memory."
            )
        case .ready, .saving, .saved:
            nil
        }
    }
}
