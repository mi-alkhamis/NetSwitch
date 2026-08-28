---
name: netswitch-swift-build-loop
description: Use when writing, editing, or debugging Swift or SwiftUI code for the NetSwitch macOS menu bar app, when implementing a NetSwitch roadmap phase task, when fixing a networksetup, osascript, or App Sandbox entitlements issue, or when reviewing Swift code for this project.
---

# NetSwitch Swift Build & Debug Loop

## Before writing any code
1. Re-read the Project Instructions for the current phase scope — only build what's listed for the active phase unless explicitly told otherwise.
2. If the task touches App Sandbox entitlements, privilege escalation (osascript), or any macOS API whose exact name may have changed across OS versions, say so explicitly before writing code. Do not silently guess at API names.

## Making a change
1. Make the smallest change that satisfies the current task — avoid refactoring unrelated files.
2. Keep networking logic in NetworkService.swift, persistence in ProfileStore.swift, and UI in the View files. Don't blur these boundaries.
3. No third-party dependencies. No private or undocumented APIs.

## After writing code
1. If you have the ability to actually compile this Swift project (a real macOS + Xcode/Swift toolchain), build it and report the exact compiler output — success, or the exact error text, not a paraphrase.
2. If you do NOT have a working Swift/macOS build environment available, say so plainly, and instead give the user:
   - The exact file(s) changed
   - Step-by-step instructions for testing the change themselves in Xcode (what to click, what result to expect)
   - What kind of error to paste back if it doesn't work
3. Never describe code as "tested" or "working" unless it was actually compiled and run in this session.

## When something fails
1. Ask for the exact Xcode error text and line number rather than guessing at the cause.
2. Check first whether the issue is App Sandbox-related (a known common failure mode in this specific project) before assuming it's a plain logic bug.

## Definition of done for a Phase 1 task
The user can build and run the app in Xcode, perform the specific action requested (for example "edit a profile" or "see current SSID"), and it behaves as described — not just "the code looks correct."
