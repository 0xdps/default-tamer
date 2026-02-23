//
//  MenuItemView.swift
//  Default Tamer
//
//  Custom menu item view with hover effects
//

import SwiftUI

struct MenuItemView: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 16, alignment: .center)
                    .foregroundColor(isDestructive ? .red : .primary)
                Text(title)
                    .foregroundColor(isDestructive ? .red : .primary)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(width: UIConstants.menuBarPopoverWidth)
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.accentColor.opacity(0.15) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
