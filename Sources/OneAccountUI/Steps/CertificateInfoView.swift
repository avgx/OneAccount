import SwiftUI
import OneAccount
import SSLPinning

@MainActor
struct CertificateInfoView: View {
    let info: CertificateInfo
    let full: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(info.commonName)
                .font(.headline)
            Text(info.subjectName)
            Text(info.issuer)
            
            let isValid = info.validityRange.notBefore <= Date() && info.validityRange.notAfter >= Date()
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(isValid ? .secondary : .red)
                Text("\(info.validityRange.notBefore.formatted(date: .abbreviated, time: .omitted)) → \(info.validityRange.notAfter.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundColor(isValid ? .secondary : .red)
            }
            
            if full {
                HStack {
                    Image(systemName: "barcode")
                        .font(.caption)
                    Text("\(info.sha256)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Image(systemName: "number")
                        .font(.caption)
                    Text("\(info.serialNumber)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                
                if info.isSelfSigned == true {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        Text("Self-signed")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(action: copyCertificateInfo) {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }
    
    private func copyCertificateInfo() {
        let infoText = info.description
        #if os(iOS)
        UIPasteboard.general.string = infoText
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(infoText, forType: .string)
        #endif
    }
}
