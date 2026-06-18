import SwiftUI
import URLKit
import OneAccount

extension AccountRecord {
    public var icon: String { self.backend?.icon ?? "pc" }
}

extension AccountRecord {
    public var title: String {
        if let name = profile.name, !name.isEmpty {
            return name
        } else if endpoint.backend == .cloud {
            return user
        } else if user.contains("@") || user.starts(with: "\\\\") {
            return user
        } else {
            return "\(user)@\(endpoint.url.pretty())"
        }
    }
}

extension AccountRecord {
    public var subtitle: String {
        if let name = profile.name, !name.isEmpty {
            if self.backend == .cloud {
                return "\(endpoint.url.pretty()) / \(user)"
            } else {
                return "\(user)@\(endpoint.url.pretty())"
            }
        } else {
            return endpoint.url.pretty()
        }
    }
}
