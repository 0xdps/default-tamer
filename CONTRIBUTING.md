# Contributing to Default Tamer

Thank you for your interest in contributing to Default Tamer! This document provides guidelines for contributing to the project.

## Code of Conduct

Be respectful, inclusive, and constructive in all interactions.

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](../../issues)
2. If not, create a new issue with:
   - Clear, descriptive title
   - Steps to reproduce
   - Expected vs actual behavior
   - macOS version and Default Tamer version
   - Relevant logs or screenshots

### Suggesting Features

1. Check [Issues](../../issues) for existing feature requests
2. Create a new issue with:
   - Clear description of the feature
   - Use case and benefits
   - Potential implementation approach (optional)

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature-name`
3. **Make your changes**:
   - Follow existing code style
   - Add comments for complex logic
   - Update documentation if needed
4. **Test thoroughly**:
   - Build and run the app
   - Test affected functionality
   - Verify no regressions
5. **Commit with clear messages**: `git commit -m "Add feature: description"`
6. **Push to your fork**: `git push origin feature/your-feature-name`
7. **Create a Pull Request**:
   - Reference related issues
   - Describe what changed and why
   - Include screenshots for UI changes

## Development Setup

### Prerequisites

- macOS 13.0 or later
- Xcode 14.0 or later
- [`just`](https://github.com/casey/just): `brew install just`

### Getting Started

```bash
git clone --recurse-submodules https://github.com/0xdps/default-tamer.git
cd default-tamer
just deploy
```

### Common Commands

```bash
just deploy       # Fast rebuild + deploy
just fresh        # Full clean rebuild
just logs         # Stream live app logs
just reset        # Reset first-run flag
just reset-all    # Wipe all app data
```

Run `just --list` for the full command reference.

### Project Structure

```
DefaultTamer/
├── Models/           # Data models
├── Services/         # Business logic
├── Views/            # SwiftUI views
├── Utilities/        # Helper functions
├── AppDelegate.swift
└── DefaultTamerApp.swift
```

## Code Style

- **Swift**: Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- **Formatting**: Use Xcode's default formatting (⌃I)
- **Naming**: Clear, descriptive names
- **Comments**: Explain "why", not "what"

## Testing

Before submitting a PR:

- [ ] App builds without warnings
- [ ] All existing features still work
- [ ] New features work as expected
- [ ] No memory leaks or crashes
- [ ] Tested on supported macOS versions

## Areas for Contribution

- **Bug fixes**: Check open issues
- **Features**: See roadmap in README
- **Documentation**: Improve guides and comments
- **Testing**: Add test coverage
- **UI/UX**: Enhance user experience
- **Performance**: Optimize routing and UI

## Questions?

- Open a [Discussion](../../discussions)
- Comment on relevant issues

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
