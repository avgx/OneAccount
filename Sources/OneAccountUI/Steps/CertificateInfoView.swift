import SwiftUI
import OneAccount
import SSLPinning

@MainActor
struct CertificateInfoView: View {
    enum PinHighlight: Equatable {
        case none
        case certificate
        case spki
    }

    let info: CertificateInfo
    let role: String?
    let full: Bool
    var pinHighlight: PinHighlight = .none

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(info.commonName)
                    .font(.headline)
                Spacer()
            }
            .padding(4)
            
            if let organization = Self.organization(from: info.issuer) {
                HStack {
                    Image(systemName: "building.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(organization)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(4)
            }

            let isValid = info.validityRange.notBefore <= Date() && info.validityRange.notAfter >= Date()
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(isValid ? .secondary : .red)
                Text("\(info.validityRange.notBefore.formatted(date: .abbreviated, time: .omitted)) → \(info.validityRange.notAfter.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundColor(isValid ? .secondary : .red)
            }
            .padding(4)
            
            if full {
                fingerprintRow(
                    icon: "key",
                    value: info.spki,
                    highlighted: pinHighlight == .spki
                )

                fingerprintRow(
                    icon: "barcode",
                    value: info.sha256,
                    highlighted: pinHighlight == .certificate
                )

                fingerprintRow(
                    icon: "number",
                    value: info.serialNumber,
                    highlighted: pinHighlight == .certificate
                )
                
                
            }
        }
        .overlay(alignment: .topTrailing) {
            if full && info.isSelfSigned == true {
                HStack {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text("Self-signed")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            } else if let role {
                HStack {
                    Spacer()
                    Text(role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contextMenu {
            Button(action: copyCertificateInfo) {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }

    @ViewBuilder
    private func fingerprintRow(icon: String, value: String, highlighted: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(4)
        .background(highlighted ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            if highlighted {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1)
            }
        }
    }

    private func copyCertificateInfo() {
        let infoText = info.description + "\n\n" + (info.pem ?? "")
        #if os(iOS)
        UIPasteboard.general.string = infoText
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(infoText, forType: .string)
        #endif
    }

    /// Extracts the organization (`O=`) attribute from a distinguished name string.
    static func organization(from distinguishedName: String) -> String? {
        let trimmed = distinguishedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        for part in trimmed.split(separator: ",") {
            let attribute = part.trimmingCharacters(in: .whitespaces)
            if attribute.hasPrefix("O=") {
                let value = String(attribute.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }
}
