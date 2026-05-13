import SwiftUI
import URLKit
import OneAccount

@MainActor
public struct AccountDetailedLabel: View {
    let account: AccountRecord
    let checkmark: Bool
    
    public init(account: AccountRecord, checkmark: Bool = false) {
        self.account = account
        self.checkmark = checkmark
    }
    
    public var body: some View {
        HStack {
            ZStack(alignment: .topTrailing) {
                AvatarView(account.user, url: account.baseURL)
                    .frame(width: 40, height: 40)
                if checkmark {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white, .green)
                        .offset(x: 5, y: -5)
                }
            }
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let name = account.name {
                        Text(name)
                        Text(account.baseURL.absoluteString)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(account.baseURL.absoluteString)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                
                Text(account.user)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
            }
            Spacer()
        }
        .contentShape(.rect)
    }
}

#Preview {
    Group {
        AccountDetailedLabel(account: .init(baseURL: URL(string: "https://try.example.com/")!, user: "root", password: "root"))
        
        AccountDetailedLabel(account: .init(baseURL: URL(string: "http://try.example.com/")!, user: "no.name@example.com", password: "root"), checkmark: true)
        
        AccountDetailedLabel(account: .init(baseURL: URL(string: "https://example.com/")!, user: "root", password: "root"))
        
        AccountDetailedLabel(account: .init(baseURL: URL(string: "http://192.168.1.41")!, user: "root", password: "root"))
    }
}
