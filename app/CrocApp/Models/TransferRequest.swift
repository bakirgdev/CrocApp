import Foundation

/// Everything a transfer starts from. `TransferController.start(_:)` takes one,
/// and `retry()` runs the last one again with the same inputs.
enum TransferRequest: Equatable {
    /// Files and folders. An empty code lets croc make one.
    case sendFiles(urls: [URL], code: String)
    /// An empty code lets croc make one.
    case sendText(text: String, code: String)
    /// `folderIsScoped`: the folder is user-picked, so it needs security scope.
    case receive(code: String, folder: URL, folderIsScoped: Bool)
    /// Send as Link: regular files only, uploaded encrypted to the link server
    /// in Settings. Ends in `.stored(receipt)`.
    case storedSend(urls: [URL], downloads: Int, lifetimeSeconds: Int)
    /// Opens a stored link: the incoming preview, then the same accept and
    /// Keep Both / Replace answer as a live receive. Auto-accept never applies.
    case storedReceive(link: URL, folder: URL, folderIsScoped: Bool)

    var direction: TransferController.Direction {
        switch self {
        case .sendFiles, .sendText, .storedSend: .send
        case .receive, .storedReceive: .receive
        }
    }

    /// Goes through a stored-transfer server rather than a croc peer.
    var isStored: Bool {
        switch self {
        case .storedSend, .storedReceive: true
        case .sendFiles, .sendText, .receive: false
        }
    }
}
