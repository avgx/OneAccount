import Foundation

/// Builds the shared keychain access group from Info.plist.
///
/// Expects `KEYCHAIN_GROUP_ID` (and ideally `AppIdentifierPrefix` or `TEAM`) in the main bundle.
/// - `*` / empty → `nil` (do not set `kSecAttrAccessGroup`; use the app default group).
/// - otherwise → `AppIdentifierPrefix` + id, or `TEAM` + id.
public enum KeychainAccessGroup {
    public static func fromMainBundle(_ bundle: Bundle = .main) -> String? {
        let info = bundle.infoDictionary
        let group = info?["KEYCHAIN_GROUP_ID"] as? String
        guard let group, !group.isEmpty, group != "*" else { return nil }

        if let prefix = info?["AppIdentifierPrefix"] as? String, !prefix.isEmpty {
            return prefix.hasSuffix(".") ? "\(prefix)\(group)" : "\(prefix).\(group)"
        }
        if let team = info?["TEAM"] as? String, !team.isEmpty, team != "??????????" {
            return "\(team).\(group)"
        }
        return nil
    }
}
