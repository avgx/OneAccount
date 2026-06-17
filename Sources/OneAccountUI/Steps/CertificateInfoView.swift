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
    let full: Bool
    var pinHighlight: PinHighlight = .none

    private var isValid: Bool {
        info.validityRange.notBefore <= Date() && info.validityRange.notAfter >= Date()
    }

    private var validityText: String {
        "\(info.validityRange.notBefore.formatted(date: .abbreviated, time: .omitted)) → \(info.validityRange.notAfter.formatted(date: .abbreviated, time: .omitted))"
    }

    var body: some View {
        Group {
            LabeledRow("Name", systemImage: "signature", value: info.commonName)

            if let organization = Self.organization(from: info.issuer) {
                LabeledRow("Issuer", systemImage: "building.2", value: organization)
            }

            LabeledRow("Valid", systemImage: "calendar") {
                Text(validityText)
                    .foregroundColor(isValid ? Color.secondary : Color.red)
            }

            if full {
                LabeledRow("SPKI", systemImage: "key") {
                    monospacedValue(info.spki)
                }
                .labeledRowHighlighted(pinHighlight == .spki)

                LabeledRow("SHA-256", systemImage: "barcode") {
                    monospacedValue(info.sha256)
                }
                .labeledRowHighlighted(pinHighlight == .certificate)

                LabeledRow("Serial", systemImage: "number", value: info.serialNumber)
            }
        }
        .modifier(CertificateCopyMenuModifier(info: info))
    }

    @ViewBuilder
    private func monospacedValue(_ value: String) -> some View {
        Text(value)
            .font(.caption.monospaced())
            .lineLimit(1)
            .truncationMode(.middle)
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

#if os(iOS) || os(macOS)
private struct CertificateCopyMenuModifier: ViewModifier {
    let info: CertificateInfo

    func body(content: Content) -> some View {
        content.contextMenu {
            Button(action: copyCertificateInfo) {
                Label("Copy", systemImage: "doc.on.doc")
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
}
#else
private struct CertificateCopyMenuModifier: ViewModifier {
    let info: CertificateInfo

    func body(content: Content) -> some View {
        content
    }
}
#endif
