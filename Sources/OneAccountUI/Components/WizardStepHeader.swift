import SwiftUI
import OneAccount

@MainActor
struct WizardStepHeader: View {
    let current: Int
    let total: Int

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }
    
    var body: some View {
        HStack {
            Text("Step \(current)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            ProgressBadge(progress: .constant(percentage))
                .font(.caption2)
                .foregroundStyle(Color.accentColor)
        }
    }
}
