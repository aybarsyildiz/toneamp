import StoreKit
import SwiftUI

/// Full-screen Pro paywall — hero, feature list, plan selection, CTA.
/// Prices come from StoreKit once the App Store Connect products load;
/// the static strings below are display fallbacks only.
struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(SessionStore.self) private var session
    @Environment(ProStore.self) private var pro

    private enum Plan: String, CaseIterable, Identifiable {
        case yearly
        case monthly

        var id: String { rawValue }

        var productID: String {
            switch self {
            case .yearly: return ProStore.yearlyID
            case .monthly: return ProStore.monthlyID
            }
        }

        var title: String {
            switch self {
            case .yearly: return "Yearly"
            case .monthly: return "Monthly"
            }
        }

        var fallbackPrice: String {
            switch self {
            case .yearly: return "$29.99 / year"
            case .monthly: return "$4.99 / month"
            }
        }

        var subtitle: String {
            switch self {
            case .yearly: return "≈ $2.50 a month — 7-day free trial"
            case .monthly: return "Cancel anytime"
            }
        }

        var badge: String? {
            switch self {
            case .yearly: return "BEST VALUE"
            case .monthly: return nil
            }
        }
    }

    @State private var selectedPlan: Plan = .yearly

    private func price(for plan: Plan) -> String {
        guard let product = pro.product(for: plan.productID) else {
            return plan.fallbackPrice
        }
        let unit = plan == .yearly ? "year" : "month"
        return "\(product.displayPrice) / \(unit)"
    }

    private var privacyURL: URL {
        AIToneService.proxyURL?.appendingPathComponent("privacy")
            ?? URL(string: "https://github.com/aybarsyildiz/toneamp")!
    }

    private var termsURL: URL {
        URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 26) {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 108, height: 108)
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 46))
                                .foregroundStyle(.tint)
                                .symbolEffect(.bounce, options: .nonRepeating)
                        }
                        Text("ToneAmp Pro")
                            .font(.largeTitle.bold())
                        Text("The AI tone engine, tuned to your gear.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 18) {
                        PaywallFeatureRow(
                            symbol: "sparkles",
                            tint: .purple,
                            title: "Identify Tones",
                            text: "A researched tone sheet for any song — amp, knobs, and pedal chain."
                        )
                        PaywallFeatureRow(
                            symbol: "wand.and.rays",
                            tint: .orange,
                            title: "Adapt to My Gear",
                            text: "Any tone translated to your exact amp, multi-FX, and pedals, step by step."
                        )
                        PaywallFeatureRow(
                            symbol: "square.and.arrow.down.fill",
                            tint: .blue,
                            title: "Your AI tone library",
                            text: "Every result saved per song and rig — yours to keep and republish."
                        )
                        PaywallFeatureRow(
                            symbol: "star.fill",
                            tint: .green,
                            title: "First in line",
                            text: "New Pro features land here first."
                        )
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 10) {
                        ForEach(Plan.allCases) { plan in
                            planCard(plan)
                        }
                    }
                    .padding(.horizontal, 20)

                    Text(pro.products.isEmpty
                         ? "Connecting to the App Store…"
                         : "Auto-renews until cancelled in Settings → Apple ID → Subscriptions.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 16)
            }

            VStack(spacing: 10) {
                Button {
                    Task {
                        await pro.purchase(productID: selectedPlan.productID)
                        if pro.hasEntitlement {
                            dismiss()
                        }
                    }
                } label: {
                    Group {
                        if pro.isPurchasing {
                            ProgressView()
                        } else {
                            Text(selectedPlan == .yearly ? "Start Free Trial" : "Continue")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(pro.products.isEmpty || pro.isPurchasing)
                .padding(.horizontal, 20)
                HStack(spacing: 18) {
                    Button("Restore Purchases") {
                        Task {
                            await pro.restore()
                            if pro.hasEntitlement {
                                dismiss()
                            }
                        }
                    }
                    Button("Terms") {
                        openURL(termsURL)
                    }
                    Button("Privacy") {
                        openURL(privacyURL)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.bottom, 12)
            .background(.bar)
        }
        .background(Color(.systemBackground))
        .sensoryFeedback(.selection, trigger: selectedPlan)
        .alert("Purchase Problem", isPresented: Binding(
            get: { pro.lastError != nil },
            set: { if !$0 { pro.lastError = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(pro.lastError ?? "")
        }
        .task {
            await pro.loadProducts()
        }
    }

    private func planCard(_ plan: Plan) -> some View {
        Button {
            withAnimation(.snappy) {
                selectedPlan = plan
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedPlan == plan ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(selectedPlan == plan ? Color.accentColor : Color(.systemGray3))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let badge = plan.badge {
                            Text(badge)
                                .font(.caption2.weight(.heavy))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.accentColor, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    Text(plan.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(price(for: plan))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        selectedPlan == plan ? Color.accentColor : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PaywallFeatureRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
