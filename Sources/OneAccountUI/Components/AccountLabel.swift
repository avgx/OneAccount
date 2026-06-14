import SwiftUI
import URLKit
import OneAccount


@MainActor
public struct AccountLabel: View {
    let account: AccountRecord
    
    public init(_ account: AccountRecord) {
        self.account = account
    }
     
    public var body: some View {
        HStack {
            Image(systemName: account.icon)
            
            VStack(alignment: .leading) {
                Text(account.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                if !account.subtitle.isEmpty {
                    Text(account.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                }
            }
            Spacer()
        }
        .contentShape(.rect)
    }
}

#Preview {
    Group {
        AccountLabel(AccountRecord(baseURL: URL(string: "https://try.example.com/")!, user: "root", password: "root"))
        
        AccountLabel(AccountRecord(baseURL: URL(string: "http://try.example.com/")!, user: "no.name@example.com", password: "root"))
            
        
        AccountLabel(AccountRecord(baseURL: URL(string: "http://try.digital.nothing.example.com/")!, user: "no.name@example.com", password: "root"))
            .overlay(alignment: .trailing) {
                if true {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        
        AccountLabel(AccountRecord(baseURL: URL(string: "https://example.com/")!, user: "root", password: "root"))
        
        AccountLabel(AccountRecord(baseURL: URL(string: "http://192.168.1.41")!, user: "root", password: "root", backend: .next))
        
        AccountLabel(AccountRecord(baseURL: URL(string: "http://192.168.1.41")!, user: "root", password: "root", name: "My home", backend: .next))
        
        AccountLabel(AccountRecord(baseURL: URL(string: "http://192.168.1.41")!, user: "\\\\mydomain\\my.user", password: "root", backend: .next))
        
        AccountLabel(AccountRecord(baseURL: URL(string: "https://example.com/")!, user: "no.name@example.com", password: "root", backend: .cloud))
    }
}
