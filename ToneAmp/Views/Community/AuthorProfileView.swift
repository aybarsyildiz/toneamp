import SwiftUI
import UIKit

/// Circle avatar with graceful fallbacks: image → initials → guitar glyph.
struct AvatarCircleView: View {
    let image: UIImage?
    let name: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if !initials.isEmpty {
                Text(initials)
                    .font(.system(size: size * 0.37, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "guitars.fill")
                    .font(.system(size: size * 0.39))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }
}

/// Public page for a community author: avatar, name, and every tone
/// they've published. Reached from any tone's detail page.
struct AuthorProfileView: View {
    let authorID: String
    let authorName: String

    @State private var tones: [CommunityTone] = []
    @State private var avatar: UIImage?
    @State private var displayName: String?
    @State private var isLoading = true

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    AvatarCircleView(image: avatar, name: displayName ?? authorName, size: 92)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    Text(displayName ?? authorName)
                        .font(.title3.bold())
                    Text(tones.count == 1 ? "1 published tone" : "\(tones.count) published tones")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section("Published Tones") {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if tones.isEmpty {
                    Text("Nothing published yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tones) { tone in
                        NavigationLink(value: tone) {
                            CommunityToneRow(tone: tone)
                        }
                    }
                }
            }
        }
        .navigationTitle(displayName ?? authorName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let profile = await CommunityService.profile(authorID: authorID)
            if let data = profile.avatarData {
                avatar = UIImage(data: data)
            }
            if let name = profile.displayName, !name.isEmpty {
                displayName = name
            }
            tones = (try? await CommunityService.tones(byAuthorID: authorID)) ?? []
            isLoading = false
        }
    }
}
