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
    @State private var isUpgrading = false
    @State private var showSignOutConfirmation = false

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
                        await licensing.startUpgrade(fallbackBrowserId: appState.settings.fallbackBrowserId)
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
                        await licensing.startUpgrade(fallbackBrowserId: appState.settings.fallbackBrowserId)
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
                    Text("Sign In")
                }
                .buttonStyle(.bordered)
                .help("Sign in to restore an existing Power plan on this device")
            }
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

