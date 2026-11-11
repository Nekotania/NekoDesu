/// Rank identity. Order, names, thresholds, and lines live in `RankTable`.
/// Raw values are persisted; do not rename them.
enum Rank: String, Codable, CaseIterable {
    case eKitten
    case strayCat
    case streetCat
    case alleyCat
    case houseCat
    case greatOldCat
}
