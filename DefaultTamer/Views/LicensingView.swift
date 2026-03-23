//
//  LicensingView.swift
//  Default Tamer
//
//  Preferences tab for managing the Power plan license.
//  Shows current plan status and a sign-in / sign-out action.
//

import SwiftUI

struct LicensingTab: View {
    @EnvironmentObject var licensing: LicensingManager
    @EnvironmentObject var appState: AppState


    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)

                    Text("Power Plan")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Unlock advanced routing features for power users.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                Divider()

                // Plan status
                if licensing.isValidating {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Checking license…")
                            .foregroundColor(.secondary)
                    }
                } else if let status = licensing.status, status.plan.isPaid {
                    activePlanCard(status: status)
                } else if licensing.status != nil {
                    // Signed in but on free plan — show upgrade prompt
                    signedInFreePlanCard
                } else {
                    signInCard
                }

                Divider()

                // Feature list
                featureList

                Spacer()
            }
            .padding(24)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func activePlanCard(status: LicenseStatus) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Power Plan — Active")
                        .fontWeight(.semibold)
                    if let until = status.validUntil {
                        Text("Renews \(until.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding()
            .background(Color.green.opacity(0.08))
            .cornerRadius(8)

            Button(role: .destructive) {
                licensing.signOut()
            } label: {
                Text("Sign out")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    @State private var isUpgrading = false
    @State private var upgradeError: String? = nil

    // Not signed in at all
    private var signInCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bolt.circle.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Power Plan")
                        .fontWeight(.semibold)
                    Text("Sign in and purchase to unlock all features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color.orange.opacity(0.06))
            .cornerRadius(8)

            Button {
                isUpgrading = true
                upgradeError = nil
                Task {
                    await licensing.startUpgrade(
                        fallbackBrowserId: appState.settings.fallbackBrowserId
                    )
                    isUpgrading = false
                }
            } label: {
                if isUpgrading {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small).tint(.white)
                        Text("Opening checkout…")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Label("Get Power Plan", systemImage: "bolt.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isUpgrading)
            .help("Sign in with Google and purchase the Power plan")

            Button {
                licensing.startOAuth(fallbackBrowserId: appState.settings.fallbackBrowserId)
            } label: {
                Text("Already have a plan? Sign in")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .help("Sign in to restore an existing Power plan on this device")
        }
    }

    // Signed in, but no active subscription
    private var signedInFreePlanCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free Plan")
                        .fontWeight(.semibold)
                    Text("You're signed in — upgrade to unlock all features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(8)

            if let error = upgradeError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                isUpgrading = true
                upgradeError = nil
                Task {
                    await licensing.startUpgrade(
                        fallbackBrowserId: appState.settings.fallbackBrowserId
                    )
                    isUpgrading = false
                }
            } label: {
                if isUpgrading {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small).tint(.white)
                        Text("Opening checkout\u{2026}")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Label("Upgrade to Power", systemImage: "bolt.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isUpgrading)
            .help("Opens your browser to purchase the Power plan")

            Button(role: .destructive) {
                licensing.signOut()
            } label: {
                Text("Sign out")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What's included")
                .font(.headline)

            featureRow(
                icon: "eye.slash",
                title: "Private Browsing rules",
                description: "Route specific links to a private/incognito browser session.",
                feature: .privateBrowsing
            )
            featureRow(
                icon: "person.2",
                title: "Chrome Profile rules",
                description: "Open links in a specific Chrome profile by name.",
                feature: .chromeProfiles
            )
            featureRow(
                icon: "keyboard",
                title: "Keyboard Shortcut rules",
                description: "Trigger routing rules with a global keyboard shortcut.",
                feature: .shortcutRules
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func featureRow(icon: String, title: String, description: String, feature: LicenseFeature) -> some View {
        let unlocked = licensing.isEnabled(feature)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(unlocked ? .orange : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .fontWeight(.medium)
                    if !unlocked {
                        PlusFeatureBadge()
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
