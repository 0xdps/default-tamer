//
//  PlusFeatureBadge.swift
//  Default Tamer
//
//  Small inline badge shown next to features that require the Power plan.
//

import SwiftUI

/// Shows a compact "POWER" pill badge — used inline next to Power-only UI elements.
struct PlusFeatureBadge: View {
    var body: some View {
        Text("POWER")
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.15))
            .foregroundColor(.orange)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.orange.opacity(0.4), lineWidth: 0.5))
    }
}
