import SwiftUI
import OneAccount

@MainActor
struct WizardStepHeader: View {
    let current: Int
    let total: Int

    var body: some View {
        Text("Step \(current) of \(total)")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}
