//
//  LicensingView.swift
//  Default Tamer
//
//  Preferences tab for managing the Power plan license.
//

import SwiftUI

struct LicensingTab: View {
    @EnvironmentObject var licensing: LicensingManager
    @EnvironmentObject var appState: AppState
    @ObservedObject private var promoManager = PromoManager.shared
    @State private var isUpgrading = false
    @State private var showSignOutConfirmation = false

    // Promo code
    @State private var promoCode = ""
    @State private var isValidatingPromo = false
    @State private var promoResult: PromoValidationResult?

    private var validatedPromoCode: String? {
        guard let result = promoResult, result.valid else { return nil }
        return promoCode.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                statusSection
                    .padding(28)

                Divider()
                    .padding(.horizontal, 28)

                featuresSection
                    .padding(28)
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .confirmationDialog("Sign out?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { licensing.signOut() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You'll need to sign in again to access Power features on this device.")
        }
        // When the tab appears, fetch the latest promo immediately (bypasses the 24h
        // throttle so the tab always shows the current state) and apply any already-
        // published value in case the fetch completed before this view was created.
        .onAppear {
            applyActivePromoIfNeeded(promoManager.activePromo)
            promoManager.checkNow()
        }
        // Auto-fill + validate whenever PromoManager publishes a new active promo
        // (from the daily poll or a deep link tap).
        .onReceive(promoManager.$activePromo) { promo in
            applyActivePromoIfNeeded(promo)
        }
    }

    private func applyActivePromoIfNeeded(_ promo: PromoConfig?) {
        guard let code = promo?.code, !code.isEmpty else { return }
        let current = promoCode.trimmingCharacters(in: .whitespaces)
        guard current.isEmpty || current.lowercased() != code.lowercased() else { return }
        // Validate silently first — only show the promo in the UI if the server
        // confirms it's active. This avoids flashing an error for expired/inactive codes.
        Task {
            let result = await licensing.validatePromoCode(code)
            guard result.valid else { return }
            promoCode = code
            promoResult = result
        }
    }

    // MARK: - Status section

    @ViewBuilder
    private var statusSection: some View {
        if licensing.isValidating && licensing.status == nil {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking license…")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else if let status = licensing.status, status.plan.isPaid {
            activePlanSection(status: status)
        } else if licensing.status != nil {
            freePlanSection
        } else {
            notSignedInSection
        }
    }

    // Active paid plan
    @ViewBuilder
    private func activePlanSection(status: LicenseStatus) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Power Plan")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("ACTIVE")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                }
                if let until = status.validUntil {
                    Text("Renews \(until.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Lifetime — no expiry")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 14) {
                Button {
                    licensing.validateOnLaunch()
                } label: {
                    if licensing.isValidating {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(licensing.isValidating)
                .help("Refresh license status")

                Button {
                    showSignOutConfirmation = true
                } label: {
                    Text("Sign out")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Sign out of your Power plan account")
            }
        }
    }

    // Signed in but free
    private var freePlanSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 52, height: 52)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Upgrade to Power")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("You're signed in — unlock all features below")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button {
                    isUpgrading = true
                    Task {
                        await licensing.startUpgrade(
                            promoCode: validatedPromoCode,
                            fallbackBrowserId: appState.settings.fallbackBrowserId
                        )
                        isUpgrading = false
                    }
                } label: {
                    if isUpgrading {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small).tint(.white)
                            Text("Opening…")
                        }
                    } else {
                        Label("Upgrade to Power", systemImage: "bolt.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isUpgrading)

                Button {
                    licensing.validateOnLaunch()
                } label: {
                    Label("Restore", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .help("Re-check for an existing subscription on your account")

                Spacer()

                Button {
                    showSignOutConfirmation = true
                } label: {
                    Text("Sign Out")
                }
                .buttonStyle(.bordered)
            }

            promoCodeSection
        }
    }

    // Not signed in
    private var notSignedInSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 52, height: 52)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Power Plan")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Advanced routing for power users")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button {
                    isUpgrading = true
                    Task {
                        await licensing.startUpgrade(
                            promoCode: validatedPromoCode,
                            fallbackBrowserId: appState.settings.fallbackBrowserId
                        )
                        isUpgrading = false
                    }
                } label: {
                    if isUpgrading {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small).tint(.white)
                            Text("Opening…")
                        }
                    } else {
                        Label("Get Power Plan", systemImage: "bolt.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isUpgrading)
                .help("Sign in with Google and purchase the Power plan")

                Button {
                    licensing.startOAuth(fallbackBrowserId: appState.settings.fallbackBrowserId)
                } label: {
                    Label("Sign In", systemImage: "person.fill")
                }
                .buttonStyle(.bordered)
                .help("Sign in to restore an existing Power plan on this device")
            }

            promoCodeSection
        }
    }

    // MARK: - Promo code

    private var promoCodeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("Promo code", text: $promoCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)
                    .disabled(isValidatingPromo)
                    .onChange(of: promoCode) { _ in promoResult = nil }
                    .onSubmit { applyPromoCode() }

                if isValidatingPromo {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Apply") { applyPromoCode() }
                        .buttonStyle(.bordered)
                        .disabled(promoCode.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if promoResult?.valid == true {
                    Button {
                        promoCode = ""
                        promoResult = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove promo code")
                }
            }

            if let result = promoResult {
                if result.valid {
                    Label("Promo code applied ✓", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label(result.errorMessage, systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }

    private func applyPromoCode() {
        let trimmed = promoCode.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isValidatingPromo = true
        promoResult = nil
        Task {
            let result = await licensing.validatePromoCode(trimmed)
            promoResult = result
            isValidatingPromo = false
        }
    }

    // MARK: - Features grid

    /// Column count adapts to feature count:
    ///   2 features → 1 row  of 2  (2 cols)
    ///   3 features → 1 row  of 3  (3 cols)
    ///   4 features → 2 rows of 2  (2 cols)
    private var featureColumnCount: Int {
        switch LicenseFeature.allCases.count {
        case 3:  return 3
        default: return 2
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What’s included")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: featureColumnCount),
                spacing: 12
            ) {
                featureTile(
                    icon: "eye.slash",
                    title: "Private Browsing",
                    description: "Route links to private/incognito browser sessions.",
                    feature: .privateBrowsing
                )
                featureTile(
                    icon: "person.2",
                    title: "Chrome Profiles",
                    description: "Open links in a specific Chrome profile by name.",
                    feature: .chromeProfiles
                )
                featureTile(
                    icon: "keyboard",
                    title: "Keyboard Shortcuts",
                    description: "Trigger routing rules with a global hotkey.",
                    feature: .shortcutRules
                )
            }
        }
    }

    private func featureTile(icon: String, title: String, description: String, feature: LicenseFeature) -> some View {
        let unlocked = licensing.isEnabled(feature)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(unlocked ? .orange : .secondary)
                    .frame(width: 20)
                Spacer()
                if unlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    PlusFeatureBadge()
                }
            }

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer(minLength: 0)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    unlocked ? Color.orange.opacity(0.35) : Color.primary.opacity(0.07),
                    lineWidth: unlocked ? 1.5 : 1
                )
        )
    }
}

