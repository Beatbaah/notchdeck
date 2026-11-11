import Foundation

/// Finds a cover for songs whose player gives none (streamed Apple Music songs have no
/// artwork over AppleScript): asks Apple's public iTunes Search service by artist and
/// title. Only the title and artist are sent, and only when the cover is missing.
enum ArtworkLookup {
    static func searchURL(title: String, artist: String) -> URL? {
        guard !title.isEmpty else { return nil }
        var parts = URLComponents(string: "https://itunes.apple.com/search")!
        parts.queryItems = [
            URLQueryItem(name: "term", value: [artist, title].filter { !$0.isEmpty }.joined(separator: " ")),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "1"),
        ]
        return parts.url
    }

    /// The first result's cover, asked for at 600×600 instead of the 100×100 thumbnail.
    static func artworkURL(fromResponse data: Data) -> URL? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let first = (json["results"] as? [[String: Any]])?.first,
              let small = first["artworkUrl100"] as? String,
              let url = URL(string: small.replacingOccurrences(of: "100x100bb", with: "600x600bb")),
              url.scheme == "https" else { return nil }
        return url
    }

    /// Looks the cover up and downloads it; `completion` runs on the main thread.
    static func fetch(title: String, artist: String, completion: @escaping (Data?) -> Void) {
        guard let search = searchURL(title: title, artist: artist) else { completion(nil); return }
        URLSession.shared.dataTask(with: search) { data, _, _ in
            guard let data, let cover = artworkURL(fromResponse: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            URLSession.shared.dataTask(with: cover) { image, _, _ in
                DispatchQueue.main.async { completion(image) }
            }.resume()
        }.resume()
    }
}
