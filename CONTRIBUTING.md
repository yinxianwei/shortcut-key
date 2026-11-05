# Contributing

Thanks for helping improve ShortcutKey.

1. Use an Apple Silicon Mac with Xcode and macOS 26 or newer.
2. Run `swift test --arch arm64` and `./scripts/build-app.sh` before opening a pull request.
3. Keep changes small and explain any new permission requirements or shortcut behavior.
4. Do not commit files from `.build/` or `dist/`.

Bug reports should include the macOS version, the affected app, the shortcut, and the steps to reproduce the problem. Do not include private configuration paths or unrelated personal data.
