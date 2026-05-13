import Foundation

extension URL {

    public func fragment() -> String? {
        guard let builder = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return builder.fragment
    }
}
