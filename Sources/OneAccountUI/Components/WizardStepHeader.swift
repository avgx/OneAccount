import SwiftUI
import OneAccount

/// Step dots `1.circle` / `1.circle.fill` and “step i of n” for the add-account wizard.
@MainActor
struct WizardStepHeader: View {
    let current: Int
    let total: Int
    /// Tighter layout for ``ToolbarItem`` / navigation bar; default is the original form-style block.
    var compact: Bool = false

    var body: some View {
        if compact {
            compactBody
        } else {
            fullBody
        }
    }

    private var fullBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            stepIconsRow(imageScale: .medium, trailingSpacer: true)
            Text("Step \(current) of \(total)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var compactBody: some View {
        VStack(spacing: 2) {
            stepIconsRow(imageScale: .small, trailingSpacer: false)
            Text("Step \(current) of \(total)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    private func stepIconsRow(imageScale: Image.Scale, trailingSpacer: Bool) -> some View {
        HStack(spacing: 6) {
            ForEach(1 ... total, id: \.self) { index in
                Image(systemName: index <= current ? "\(index).circle.fill" : "\(index).circle")
                    .imageScale(imageScale)
                    .foregroundStyle(index == current ? Color.accentColor : Color.secondary)
            }
            if trailingSpacer {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: trailingSpacer ? .infinity : nil)
    }
}
