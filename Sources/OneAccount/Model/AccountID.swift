import Foundation

public typealias AccountID = UUID

extension AccountID {
    public static let invalidAccountID: AccountID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}
