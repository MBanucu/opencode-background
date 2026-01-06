# Changelog

## [1.1.1-alpha.2](https://github.com/MBanucu/opencode-background/compare/v1.1.0-alpha.2...v1.1.1-alpha.2) (2026-01-06)


### Bug Fixes

* update ci-agent to use permissions instead of deprecated tools ([5191d55](https://github.com/MBanucu/opencode-background/commit/5191d55b8408921376c1dd65008b4034cf2abc04))

## [1.1.0-alpha.2](https://github.com/MBanucu/opencode-background/compare/v1.0.0-alpha.2...v1.1.0-alpha.2) (2026-01-06)


### Features

* Bun lockfile migration with CI updates ([#14](https://github.com/MBanucu/opencode-background/issues/14)) ([0d35d26](https://github.com/MBanucu/opencode-background/commit/0d35d260cad04cebdfa680e2dd7517f4cd1a666f))

## [1.0.0-alpha.2](https://github.com/MBanucu/opencode-background/compare/v0.2.0-alpha.2...v1.0.0-alpha.2) (2026-01-06)


### ⚠ BREAKING CHANGES

* **background-tasks:** Renamed core classes and interfaces from BackgroundTask to BackgroundProcess
    - Renamed `BackgroundTask` class to `BackgroundProcess`
    - Updated all related test files, type names, and documentation
    - Renamed `BackgroundTaskManager` to `BackgroundProcessManager`
    - Updated README to reflect terminology change from "tasks" to "processes"

### Features

* add demo assets and update documentation ([047e7d1](https://github.com/MBanucu/opencode-background/commit/047e7d111ca674cda112d9c0e049c88b89bd36dc))
* implement OIDC-based npm publishing with separate release and publish workflows ([da47216](https://github.com/MBanucu/opencode-background/commit/da47216668406900c442a02983c1e571cd0b1c06))


### Bug Fixes

* add missing repository field to package.json and version management task ([a82459a](https://github.com/MBanucu/opencode-background/commit/a82459a04ebf57011679c29a854213e5e9113af0))
* correct 'OpenCod(e' typo to 'OpenCode' in plugin install script message ([db18f8a](https://github.com/MBanucu/opencode-background/commit/db18f8ac3455407670b73548127780ca6f5bf218))
* simplify ci ([#7](https://github.com/MBanucu/opencode-background/issues/7)) ([bd37a54](https://github.com/MBanucu/opencode-background/commit/bd37a5434204c1e1f7fe4d3a74d619892d766922))
* update .gitignore and AGENTS.md to include .memory/ directory for temporary data ([10624fc](https://github.com/MBanucu/opencode-background/commit/10624fcd251d1ca1392c9a806a2ec8b0f481c27b))
* update echo syntax for release data output in workflow ([511e5fe](https://github.com/MBanucu/opencode-background/commit/511e5fe874584a008dc940714b14c234007ea9f8))
* update task descriptions and dependencies in mise scripts ([3e0b818](https://github.com/MBanucu/opencode-background/commit/3e0b818ac9a40abf548832d8554291482a8fbf3b))


### Code Refactoring

* **background-tasks:** rename BackgroundTask to BackgroundProcess ([ea8cd63](https://github.com/MBanucu/opencode-background/commit/ea8cd63d4cdb6e0abe65a48ce4d301d816403dad))

## [0.2.0-alpha.2](https://github.com/zenobi-us/opencode-background/compare/v0.1.0-alpha.2...v0.2.0-alpha.2) (2025-11-22)


### Features

* implement OIDC-based npm publishing with separate release and publish workflows ([da47216](https://github.com/zenobi-us/opencode-background/commit/da47216668406900c442a02983c1e571cd0b1c06))


### Bug Fixes

* add missing repository field to package.json and version management task ([a82459a](https://github.com/zenobi-us/opencode-background/commit/a82459a04ebf57011679c29a854213e5e9113af0))

## [0.1.0-alpha.2](https://github.com/zenobi-us/opencode-background/compare/v0.1.0-alpha.1...v0.1.0-alpha.2) (2025-11-21)


### ⚠ BREAKING CHANGES

* **background-tasks:** Renamed core classes and interfaces from BackgroundTask to BackgroundProcess
    - Renamed `BackgroundTask` class to `BackgroundProcess`
    - Updated all related test files, type names, and documentation
    - Renamed `BackgroundTaskManager` to `BackgroundProcessManager`
    - Updated README to reflect terminology change from "tasks" to "processes"

### Bug Fixes

* simplify ci ([#7](https://github.com/zenobi-us/opencode-background/issues/7)) ([bd37a54](https://github.com/zenobi-us/opencode-background/commit/bd37a5434204c1e1f7fe4d3a74d619892d766922))
* update .gitignore and AGENTS.md to include .memory/ directory for temporary data ([10624fc](https://github.com/zenobi-us/opencode-background/commit/10624fcd251d1ca1392c9a806a2ec8b0f481c27b))
* update echo syntax for release data output in workflow ([511e5fe](https://github.com/zenobi-us/opencode-background/commit/511e5fe874584a008dc940714b14c234007ea9f8))
* update task descriptions and dependencies in mise scripts ([3e0b818](https://github.com/zenobi-us/opencode-background/commit/3e0b818ac9a40abf548832d8554291482a8fbf3b))


### Code Refactoring

* **background-tasks:** rename BackgroundTask to BackgroundProcess ([ea8cd63](https://github.com/zenobi-us/opencode-background/commit/ea8cd63d4cdb6e0abe65a48ce4d301d816403dad))
