# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Deterministic attributed-range cache identity across Stage 0 measurement and Stage 1 prepared layout reuse.
- Public Phase 1 engine controls through `PreparedTextMeasurementOptions`, `PreparedTextDiagnosticsSnapshot`, and explicit invalidation wiring.
- `PreparedInvalidationCenter` lifecycle hooks for content-size, locale, font-set, attachment, and background-trim invalidation.
- Attachment-aware placeholder / resolver plumbing through `PreparedAttachmentRegistry` and `PreparedTextAttachment`.
- Signpost instrumentation for hot Stage 0 / Stage 1 engine paths.
- Core-owned finite-line display policy through `PreparedTextLayoutOptions`, `PreparedTextLineBreakStrategy`, truncation state, and visible-range metadata on prepared layout packets.
- Public prepared-representation surfaces through `PreparedToken`, `PreparedAnnotation`, `PreparedAttachmentSpan`, and practical `PreparedTextSourceCoordinateMap` helpers.
- Narrow public obstacle layout through `PreparedTextObstacleLayouter`, `PreparedObstacle`, and circle exclusion zones over prepared line walking.

### Changed

- Benchmarks now compare exact, bucketed, and pixel-aligned policies across Latin, Korean/CJK, emoji-heavy, token-heavy, long-token, attachment-inline, and long-text corpora.
- Core `layout` / `layoutPacket` now own max-lines, truncation, line-break strategy, and layout-direction-sensitive alignment semantics instead of leaving that responsibility to UIKit-only post-processing.
- Validation and benchmark tooling now exercise line-limited and URL-heavy core layout scenarios directly.
- Validation, benchmark, and demo surfaces now exercise attachment spans, visible token/annotation queries, coordinate-map best-effort semantics, and obstacle-layout helpers directly.
- README and maintainer docs now describe the repository as a reusable read-only layout engine rather than a thin text wrapper.
- Pull request metadata now uses a conventional sectioned OSS template, while whylog remains commit-only.

## [0.1.0] - 2026-04-03

### Added

- First public repository setup for `prepared-text-ios`.
- Community health files, issue forms, pull request template, and CODEOWNERS.
- Maintainer scripts for PR validation, release preparation, tag creation, repository readiness, and GitHub bootstrap.
- GitHub Actions workflows for CI, PR metadata validation, and release checks.
- Maintainer-facing documentation for repository setup, versioning, and releases.
