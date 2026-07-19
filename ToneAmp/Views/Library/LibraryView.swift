import SwiftUI

struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(FavoritesStore.self) private var favorites
    @Environment(SessionStore.self) private var session
    @State private var searchText = ""
    @State private var selectedGenre: Genre?
    @State private var showingSettings = false

    private var results: [Song] {
        library.songs(matching: searchText, genre: selectedGenre)
    }

    private var isBrowsing: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedGenre == nil
    }

    /// Contacts-style letter grouping for the browse list.
    private var letterSections: [(letter: String, songs: [Song])] {
        let grouped = Dictionary(grouping: results) { indexLetter(for: $0.title) }
        return grouped.keys.sorted().map { letter in
            (letter, grouped[letter] ?? [])
        }
    }

    private func indexLetter(for title: String) -> String {
        let folded = title
            .translatedFromTurkish()
            .uppercased()
        guard let first = folded.first, first.isLetter, first.isASCII else {
            return "#"
        }
        return String(first)
    }

    /// Deterministic daily pick — same song all day, new song tomorrow.
    private var toneOfTheDay: Song? {
        let songs = library.songs
        guard !songs.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let year = Calendar.current.component(.year, from: Date())
        return songs[(day * 31 + year) % songs.count]
    }

    var body: some View {
        NavigationStack {
            Group {
                if results.isEmpty {
                    ContentUnavailableView {
                        Label("Not in the Library", systemImage: "magnifyingglass")
                    } description: {
                        Text("The library holds hand-checked classics. For everything else, search the Community tab — any song, tones by real players.")
                    }
                } else {
                    ScrollViewReader { proxy in
                    List {
                        if isBrowsing {
                            if let song = toneOfTheDay {
                                Section {
                                    NavigationLink(value: song) {
                                        ToneOfTheDayCard(song: song)
                                    }
                                    .buttonStyle(.plain)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                                }
                            }
                            Section {
                                featuredShelf
                            } header: {
                                Text("Featured")
                                    .font(.title3.bold())
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                            }
                        }
                        Section {
                            genreChips
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                .listRowBackground(Color.clear)
                        }
                        if isBrowsing {
                            ForEach(letterSections, id: \.letter) { section in
                                Section {
                                    ForEach(section.songs) { song in
                                        NavigationLink(value: song) {
                                            SongRow(song: song)
                                        }
                                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                            FavoriteSwipeButton(song: song)
                                        }
                                    }
                                } header: {
                                    Text(section.letter)
                                        .id("index-\(section.letter)")
                                }
                            }
                        } else {
                            Section("Songs") {
                                ForEach(results) { song in
                                    NavigationLink(value: song) {
                                        SongRow(song: song)
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        FavoriteSwipeButton(song: song)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .overlay(alignment: .trailing) {
                        if isBrowsing {
                            SectionIndexBar(letters: letterSections.map { $0.letter }) { letter in
                                proxy.scrollTo("index-\(letter)", anchor: .top)
                            }
                        }
                    }
                    }
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: Song.self) { song in
                if session.isSignedIn {
                    SongDetailView(song: song)
                } else {
                    SignInRequiredView()
                }
            }
            .searchable(text: $searchText, prompt: "Songs or artists")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        FavoritesView()
                    } label: {
                        Label("Favorites", systemImage: "star")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .task {
                await library.loadArtworkIfNeeded()
            }
        }
    }

    private var featuredShelf: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(library.featuredSongs) { song in
                    NavigationLink(value: song) {
                        FeaturedSongCard(song: song)
                    }
                    .buttonStyle(.plain)
                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                        content
                            .scaleEffect(phase.isIdentity ? 1 : 0.93)
                            .opacity(phase.isIdentity ? 1 : 0.8)
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var genreChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                GenreChip(label: "All", isSelected: selectedGenre == nil) {
                    selectedGenre = nil
                }
                ForEach(Genre.allCases) { genre in
                    GenreChip(label: genre.rawValue, isSelected: selectedGenre == genre) {
                        selectedGenre = genre
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}

private struct GenreChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.snappy) {
                action()
            }
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.regularMaterial),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

/// Editorial card: album artwork with a legibility scrim, character tag,
/// title, and artist — Apple Music-style.
struct FeaturedSongCard: View {
    let song: Song

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            artworkBackground
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 3) {
                if let tone = song.tones.first {
                    Text(tone.character.rawValue.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Text(song.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }
            .padding(14)
        }
        .frame(width: 244, height: 152)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var artworkBackground: some View {
        if let url = song.artworkURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.opacity)
                default:
                    gradientFallback
                }
            }
            .frame(width: 244, height: 152)
            .clipped()
        } else {
            gradientFallback
        }
    }

    private var gradientFallback: some View {
        LinearGradient(
            colors: [song.genre.tint.opacity(0.9), song.genre.tint.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Image(systemName: "guitars.fill")
                .font(.system(size: 46))
                .foregroundStyle(.white.opacity(0.25))
                .padding(10)
        }
        .frame(width: 244, height: 152)
    }
}

/// Contacts-style tappable/draggable letter index.
struct SectionIndexBar: View {
    let letters: [String]
    let onSelect: (String) -> Void

    @State private var currentLetter = ""

    private let rowHeight: CGFloat = 13

    var body: some View {
        VStack(spacing: 0) {
            ForEach(letters, id: \.self) { letter in
                Text(letter)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 18, height: rowHeight)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    select(at: value.location.y)
                }
        )
        .padding(.trailing, 3)
        .frame(maxHeight: .infinity, alignment: .center)
        .sensoryFeedback(.selection, trigger: currentLetter)
    }

    private func select(at y: CGFloat) {
        guard !letters.isEmpty else { return }
        let index = max(0, min(letters.count - 1, Int(y / rowHeight)))
        let letter = letters[index]
        if letter != currentLetter {
            currentLetter = letter
            onSelect(letter)
        }
    }
}

extension String {
    /// Transliterates Turkish characters for index grouping and slugs.
    func translatedFromTurkish() -> String {
        let table: [Character: Character] = [
            "ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u",
            "Ç": "C", "Ğ": "G", "İ": "I", "Ö": "O", "Ş": "S", "Ü": "U",
        ]
        return String(map { table[$0] ?? $0 })
    }
}

/// Full-width daily hero banner.
struct ToneOfTheDayCard: View {
    let song: Song

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let url = song.artworkURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            gradientFallback
                        }
                    }
                } else {
                    gradientFallback
                }
            }
            .frame(height: 168)
            .clipped()
            LinearGradient(
                colors: [.black.opacity(0.15), .clear, .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 3) {
                Label("TONE OF THE DAY", systemImage: "sparkles")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.85))
                Text(song.title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    if let tone = song.tones.first {
                        Text(tone.character.rawValue)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.22), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(14)
        }
        .frame(height: 168)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 6)
        .accessibilityElement(children: .combine)
    }

    private var gradientFallback: some View {
        LinearGradient(
            colors: [song.genre.tint.opacity(0.95), song.genre.tint.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct FavoriteSwipeButton: View {
    @Environment(FavoritesStore.self) private var favorites
    @Environment(SessionStore.self) private var session
    let song: Song

    var body: some View {
        Button {
            guard session.requireSignIn() else { return }
            favorites.toggle(song)
        } label: {
            if favorites.isFavorite(song) {
                Label("Unfavorite", systemImage: "star.slash.fill")
            } else {
                Label("Favorite", systemImage: "star.fill")
            }
        }
        .tint(.orange)
    }
}
