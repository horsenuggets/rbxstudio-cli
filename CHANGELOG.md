# Changelog

## 1.0.2
- Add one-liner install scripts for macOS, Linux, and Windows
- Add test-install and test-install-scripts CI workflows
- Add comprehensive README with installation instructions and command reference
- Use Toolkit.build for cross-platform require patching in compiled binaries
- Add test-install checks to branch protection
- Fix DemoList mock data PascalCase keys and StudioHelpers Windows crash

## 1.0.1
- Add install and update subcommands using shared Toolkit from commandline-luau 0.2.0
- Users can run "rbxstudio install" for global installation and "rbxstudio update" for self-updating
- Update shell completions to include install and update commands

## 1.0.0
- Standardize CI workflows with cross-platform builds and artifact uploads
- Add per-repo Terraform config for branch protection
- Remove Wally publish from private package release workflow
- Sync gitignore from template

## 0.0.1
- Consolidate commands into open and start with place ID and file path support
- Add auto-cleanup for stale temp places as detached background process
- Add shell completion generation and install scripts for zsh and PowerShell
- Bump commandline-luau to 0.0.15 and lune to 0.10.4-horse.14.2
- Add lune setup and version generation steps to CI
- Gitignore generated __VERSION__.luau
