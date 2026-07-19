import SwiftUI

/// Full view of a published tone: the shared amp/pedal UI plus author info
/// and interactive rating.
struct CommunityToneDetailView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ModerationStore.self) private var moderation
    @Environment(\.dismiss) private var dismiss
    let tone: CommunityTone

    @State private var myRating = 0
    @State private var ratingCount: Int
    @State private var ratingTotal: Int
    @State private var isRating = false
    @State private var showingSignIn = false
    @State private var ratingError: String?
    @State private var showingReportDialog = false
    @State private var reportConfirmation: String?

    init(tone: CommunityTone) {
        self.tone = tone
        _ratingCount = State(initialValue: tone.ratingCount)
        _ratingTotal = State(initialValue: tone.ratingTotal)
    }

    private var averageRating: Double? {
        guard ratingCount > 0 else { return nil }
        return Double(ratingTotal) / Double(ratingCount)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    SongArtworkView(genre: tone.genre, artworkURL: tone.artworkURL, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tone.songTitle)
                            .font(.headline)
                            .lineLimit(1)
                        Text(tone.artistName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("Tone by \(tone.authorName) · \(tone.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Rating") {
                VStack(spacing: 10) {
                    HStack {
                        RatingSummaryLabel(average: averageRating, count: ratingCount)
                        Spacer()
                        if isRating {
                            ProgressView()
                        }
                    }
                    RatingStarsView(rating: myRating, size: 26) { stars in
                        rate(stars)
                    }
                    .frame(maxWidth: .infinity)
                    Text(myRating > 0 ? "Your rating" : "Tap to rate this tone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let ratingError {
                        Text(ratingError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Amp") {
                HStack {
                    Label(tone.ampName.isEmpty ? "Not specified" : tone.ampName, systemImage: "amplifier")
                    Spacer()
                    CharacterBadge(character: tone.character)
                }
            }

            Section("Settings") {
                AmpPanelView(settings: tone.settings)
            }

            if !tone.guitar.isEmpty || !tone.pickup.isEmpty {
                Section("Guitar") {
                    if !tone.guitar.isEmpty {
                        LabeledContent {
                            Text(tone.guitar)
                                .multilineTextAlignment(.trailing)
                        } label: {
                            Label("Guitar", systemImage: "guitars.fill")
                        }
                    }
                    if !tone.pickup.isEmpty {
                        LabeledContent {
                            Text(tone.pickup)
                                .multilineTextAlignment(.trailing)
                        } label: {
                            Label("Pickup", systemImage: "dot.radiowaves.left.and.right")
                        }
                    }
                }
            }

            Section("Pedals & Effects") {
                if tone.pedals.isEmpty {
                    Label("Straight into the amp — no pedals", systemImage: "cable.connector")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tone.pedals) { pedal in
                        PedalRow(pedal: pedal)
                    }
                }
            }

            Section("For Your Rig") {
                RigTipsView(pickup: tone.pickup, amp: tone.ampName, pedals: tone.pedals)
                AdaptToMyGearButton(
                    input: ToneAdaptationInput(
                        trackID: tone.trackID,
                        songTitle: tone.songTitle,
                        artist: tone.artistName,
                        albumName: tone.albumName,
                        year: tone.year,
                        genre: tone.genre,
                        artworkURL: tone.artworkURL,
                        toneName: tone.toneName,
                        ampName: tone.ampName,
                        settings: tone.settings,
                        guitar: tone.guitar,
                        pickup: tone.pickup,
                        pedals: tone.pedals,
                        notes: tone.notes
                    )
                )
            }

            if !tone.notes.isEmpty {
                Section("Notes") {
                    Text(tone.notes)
                        .font(.callout)
                }
            }
        }
        .navigationTitle(tone.toneName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: toneShareText(
                        songTitle: tone.songTitle,
                        artist: tone.artistName,
                        toneName: tone.toneName,
                        amp: tone.ampName,
                        settings: tone.settings,
                        guitar: tone.guitar,
                        pickup: tone.pickup,
                        pedals: tone.pedals,
                        notes: tone.notes
                    )
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingReportDialog = true
                    } label: {
                        Label("Report This Tone", systemImage: "exclamationmark.bubble")
                    }
                    Button(role: .destructive) {
                        moderation.hide(toneID: tone.id)
                        dismiss()
                    } label: {
                        Label("Hide This Tone", systemImage: "eye.slash")
                    }
                    if !tone.authorID.isEmpty {
                        Button(role: .destructive) {
                            moderation.block(authorID: tone.authorID)
                            dismiss()
                        } label: {
                            Label("Block \(tone.authorName)", systemImage: "person.slash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Report This Tone", isPresented: $showingReportDialog, titleVisibility: .visible) {
            ForEach(["Spam or junk", "Wrong or misleading", "Offensive content"], id: \.self) { reason in
                Button(reason) {
                    submitReport(reason: reason)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Thanks for the Report", isPresented: Binding(
            get: { reportConfirmation != nil },
            set: { if !$0 { reportConfirmation = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(reportConfirmation ?? "")
        }
        .sensoryFeedback(.success, trigger: myRating)
        .sheet(isPresented: $showingSignIn) {
            SignInSheet()
        }
        .task {
            if let userID = session.userID {
                let stars = await CommunityService.myRating(toneID: tone.id, userID: userID)
                if let stars {
                    myRating = stars
                }
            }
        }
    }

    private func submitReport(reason: String) {
        let reporterID = session.userID ?? "anonymous"
        Task { @MainActor in
            try? await CommunityService.report(
                toneID: tone.id,
                toneName: tone.toneName,
                reason: reason,
                reporterID: reporterID
            )
            reportConfirmation = "We'll review \u{201C}\(tone.toneName)\u{201D}. You can also hide it or block the author from the ••• menu."
        }
    }

    private func rate(_ stars: Int) {
        guard let userID = session.userID else {
            showingSignIn = true
            return
        }
        guard !isRating else { return }
        let previous = myRating
        myRating = stars
        isRating = true
        ratingError = nil
        Task { @MainActor in
            do {
                try await CommunityService.rate(toneID: tone.id, stars: stars, userID: userID)
                if previous == 0 {
                    ratingCount += 1
                    ratingTotal += stars
                } else {
                    ratingTotal += stars - previous
                }
            } catch {
                myRating = previous
                ratingError = error.localizedDescription
            }
            isRating = false
        }
    }
}
