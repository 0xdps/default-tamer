//
//  FeedbackView.swift
//  Default Tamer
//
//  Modal sheet for submitting user feedback via Inbounce.
//

import SwiftUI

struct FeedbackView: View {
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var rating: Double = 0
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var errorMessage: String?
    @State private var rateLimitedUntil: Date?

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(didSubmit ? "Thanks for your feedback!" : "Send Feedback")
                    .font(.headline)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            if didSubmit {
                // Success state
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Your feedback helps make Default Tamer better.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            } else if let until = rateLimitedUntil {
                // Rate-limited state
                VStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text("You've already sent feedback today.")
                        .font(.headline)
                    Text("You can send feedback again after \(Self.timeFormatter.string(from: until)), or after updating to a newer version.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            } else {
                // Form
                VStack(alignment: .leading, spacing: 16) {
                    // Star rating
                    VStack(alignment: .leading, spacing: 6) {
                        Text("How would you rate Default Tamer?")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        StarRatingView(rating: $rating)
                    }

                    // Name (optional)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name (optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Your name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Comment
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Comment")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        ZStack(alignment: .topLeading) {
                            if comment.isEmpty {
                                Text("Tell us what you think…")
                                    .font(.body)
                                    .foregroundColor(Color(NSColor.placeholderTextColor))
                                    .padding(.horizontal, 5)
                                    .padding(.top, 7)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $comment)
                                .font(.body)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                        }
                        .frame(height: 90)
                        .padding(1)
                        .background(Color(NSColor.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(20)

                Divider()

                // Actions
                HStack {
                    Spacer()
                    Button("Cancel") { isPresented = false }
                        .keyboardShortcut(.cancelAction)
                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Send")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(rating == 0 || comment.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
        .frame(width: 380)
        .onAppear {
            rateLimitedUntil = FeedbackManager.nextAllowedDate
        }
    }

    private func submit() {
        errorMessage = nil
        isSubmitting = true
        Task {
            do {
                try await FeedbackManager.submit(name: name, rating: rating, comment: comment)
                didSubmit = true
            } catch FeedbackError.rateLimited(let until) {
                rateLimitedUntil = until
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

// MARK: - Star Rating

private struct StarRatingView: View {
    @Binding var rating: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                HStack(spacing: 0) {
                    // Left half → n - 0.5
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16, height: 28)
                        .contentShape(Rectangle())
                        .onTapGesture { rating = Double(star) - 0.5 }
                    // Right half → n
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16, height: 28)
                        .contentShape(Rectangle())
                        .onTapGesture { rating = Double(star) }
                }
                .overlay {
                    starImage(for: star)
                        .font(.title2)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func starImage(for star: Int) -> some View {
        let full = Double(star)
        let half = full - 0.5
        if rating >= full {
            return Image(systemName: "star.fill").foregroundColor(.orange)
        } else if rating >= half {
            return Image(systemName: "star.leadinghalf.filled").foregroundColor(.orange)
        } else {
            return Image(systemName: "star").foregroundColor(.secondary)
        }
    }
}
