# TOME Build Script Examples

## Interactive Mode (Recommended)
```bash
./build.sh
```
This will:
1. Show current version
2. Analyze git changes and suggest version bump
3. Let you choose version increment type
4. Let you choose build configuration
5. Show build summary before proceeding

## Automated Builds

### Quick patch release (bug fixes)
```bash
./build.sh --auto-patch
```

### Minor release (new features)
```bash
./build.sh --auto-minor
```

### Major release (breaking changes)
```bash
./build.sh --auto-major
```

## Sample Interactive Session

```
╭─────────────────────────────────────────╮
│           TOME Build System             │
│     Advanced Version Management         │
╰─────────────────────────────────────────╯

📊 Analyzing recent changes...
Changes since v1.5.2:
  • f8a3d12 Add new Garden environment breathing exercises
  • 2b7e391 Fix hardware connection timeout issues
  • a1c8f45 Update OpenAI integration with new models

✨ Detected new features - consider MINOR version bump

Version Management
Current version: 1.5.2

Select version increment:
  1) Patch (1.5.2 → 1.5.3) - Bug fixes, small changes
  2) Minor (1.5.2 → 1.6.0) - New features, backward compatible
  3) Major (1.5.2 → 2.0.0) - Breaking changes, major updates
  4) Keep (1.5.2) - No version change
  5) Custom - Enter custom version

Select option [1-5]: 2

Build Configuration
Select build type:
  1) Debug   - Development build with debug symbols
  2) Release - Optimized production build
  3) Archive - Signed release for distribution

Select build type [1-3]: 2

🎯 Build Summary
Project: TOME
Version: 1.6.0
Build: 202509221430
Git: f8a3d12 (main)
Type: release

Proceed with build? [Y/n]: y

📝 Updating version in project files...
✓ Version updated in project files

🔨 Building TOME v1.6.0 (release)...
✓ Build completed successfully

📦 Creating release package...
✓ Release package created: releases/TOME-v1.6.0.zip

Create git tag for v1.6.0? [y/N]: y
✓ Git tag v1.6.0 created

Push tag to remote? [y/N]: y
✓ Tag pushed to remote

🎉 Build completed successfully!
Version: 1.6.0
Build: 202509221430
Release package: releases/TOME-v1.6.0.zip

Next steps:
• Test the build thoroughly
• Update documentation if needed
• Consider creating a release on GitHub
• Deploy to your target environment
```

## Version Management

### Semantic Versioning
- **Patch (x.x.X)**: Bug fixes, performance improvements, small tweaks
- **Minor (x.X.x)**: New features, environment additions, UI improvements
- **Major (X.x.x)**: Breaking changes, architecture changes, API changes

### Change Detection
The script analyzes git commits since the last tag and suggests version bumps based on:
- **BREAKING/major** keywords → Major version
- **feat/feature/add/new** keywords → Minor version  
- **fix/bug/patch/hotfix** keywords → Patch version

### Auto-Generated Files
The script automatically creates/updates:
- `VERSION` file with current version
- `Sources/TOME/Version.swift` with version constants
- Release packages in `releases/` directory
- Git tags (optional)

## Build Types

### Debug Build
- Includes debug symbols
- No optimization
- Suitable for development and testing
- Binary location: `.build/debug/TOME`

### Release Build
- Optimized for performance
- Stripped debug symbols
- Production ready
- Binary location: `.build/release/TOME`
- Creates ZIP package in `releases/`

### Archive Build
- Creates Xcode archive
- Suitable for App Store submission
- Includes signing and notarization prep
- Archive location: `releases/TOME-vX.X.X.xcarchive`

## Continuous Integration

For CI/CD pipelines, use automated modes:

```bash
# In your CI script
if [[ "$COMMIT_MSG" =~ "BREAKING" ]]; then
    ./build.sh --auto-major
elif [[ "$COMMIT_MSG" =~ "feat:" ]]; then
    ./build.sh --auto-minor
else
    ./build.sh --auto-patch
fi
```

## Troubleshooting

### Common Issues
1. **"Package.swift not found"**: Make sure you're in the project root
2. **"Permission denied"**: Run `chmod +x build.sh` to make script executable
3. **Build failures**: Check Swift/Xcode installation and dependencies

### Debug Mode
For verbose output, modify the script and add `set -x` at the top.

### Clean Builds
To force a clean build:
```bash
swift package clean
./build.sh
```