import Foundation

public enum PersistenceError: Error, Sendable {
    case encodingFailed(Error)
    case decodingFailed(Error)
    case writeFailed(Error)
    case readFailed(Error)
    case accountNotFound(AccountID)
}
