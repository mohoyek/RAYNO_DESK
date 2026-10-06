# RAYNODesk — standalone exe, Persian, RD icon

## What the 32-bit build actually is

The 32-bit target is the legacy Sciter UI, not Flutter. The Flutter matrix's
`i686-pc-windows-msvc` entry is commented out in `flutter-build.yml:117`, and the
comment above it states "The fallback for the flutter version, we use Sciter for
32bit Windows." So the plan below targets the Sciter UI (`src/ui/`), which is what
`rayno-win32.yml` produces.

The last 32-bit run succeeded: `Finished release [optimized] target(s) in 21m 31s`,
artifact `raynodesk-unsigned-windows-x86` (18.9 MB, 9 files).

## Findings that shape the work

1. **`fa.rs` is already a complete translation** — 780/780 keys, 777 non-empty,
   registered as `"fa"` in `src/lang.rs:89` and selected at `:219`. All 10 keys used
   by `src/ui/install.tis` exist. Persian is reachable today; nothing forces it on.
2. **The setup page has exactly one hardcoded `rustdesk`**: the EULA link at
   `src/ui/install.tis:53` (`http://rustdesk.com/privacy`). All other text already
   goes through `translate()`. The install path is dynamic via
   `handler.get_app_name()` (`install.tis:47`).
3. **Three old-blue spots remain in the Sciter UI**: `index.tis:606` (copyright
   banner, `#2c8cff`), `header.tis:18` (SVG mic icon, `#2C8CFF`), `file_transfer.tis:25`
   (SVG file icon, `#2C8CFF`).
4. **The portable packer hardcodes the exe name.** `libs/portable/generate.py:127`
   defaults the executable to `rustdesk.exe`, and the extracted process on the user's
   disk is therefore `rustdesk.exe`, not `RAYNODesk.exe`.
5. **Persian is RTL and the Sciter UI has no RTL support** — zero hits for `dir=`,
   `rtl`, `unicode-bidi` in `src/ui/`. Flutter gets RTL implicitly from
   `supportedLocales` (`flutter/lib/common.dart:677`). Known limit, not fixed here.
6. **Icons**: `res/icon.ico` (99 KB, Windows app icon) and `res/tray-icon.ico`
   (4.3 KB, tray — embedded via `include_bytes!` at `src/tray.rs:50`).
   `flutter/windows/runner/resources/app_icon.ico` is the Flutter one.

### Corrected: how to force the Persian default

My first draft proposed writing `lang` into `BUILTIN_SETTINGS`. **That does not
work.** `BUILTIN_SETTINGS` is only consulted by dedicated accessors —
`no_register_device` (`config.rs:1164`), `is_disable_change_id` (`:1182`),
`is_disable_unlock_pin` (`:1191`) and a few others. `lang` has no such accessor, and
`LocalConfig::get_option` (`:2200`) never reads `BUILTIN_SETTINGS`.

The correct map is `DEFAULT_LOCAL_SETTINGS`, which `get_option` *does* read at
`:2204`. Priority comes from `get_or` (`:2742`):

```
OVERWRITE_LOCAL_SETTINGS  >  saved user options  >  DEFAULT_LOCAL_SETTINGS
```

So inserting `lang -> fa` into `DEFAULT_LOCAL_SETTINGS` sets the default, and a
value the user picks later still wins because saved options sit above defaults.

Two mechanics worth recording:

- `DEFAULT_LOCAL_SETTINGS` is also written by `read_custom_client` (`:2415`) via
  `default-settings` in `custom.txt`, but `load_custom_client` (`:2377`) only runs
  when a `custom.txt` exists next to the exe. This repo ships none, so nothing
  overwrites our value.
- Insertion order matters. `global_init()` runs at `core_main.rs:33`, before
  `load_custom_client()` at `:36`. Inserting in `apply_client_branding()` therefore
  lands first and a future `custom.txt` would still be able to override it, which is
  the correct precedence.

Users can still switch language: `is_option_can_save` (`:2757`) returns false only
when the chosen value equals the default, so picking `fa` stores nothing (correct)
while picking anything else persists and takes priority.

## Changes

### 1. Publish the standalone exe unconditionally

`rayno-win32.yml`: drop the `if: env.SIGN_BASE_URL != '-2'` guard from the
`Publish Release` step. The exe is already built and correct; only publication is
gated. The release stays `prerelease: true` and unsigned — Windows SmartScreen will
warn, which is expected for an unsigned build.

Rename the release file to drop the `-sciter` suffix the user did not ask for:
`RAYNODesk-1.5.0-x86-sciter.exe` → `RAYNODesk-1.5.0-x86.exe`.

### 2. App name

`get_app_name()` already returns `RAYNODesk` (`src/common.rs:1096`), which the Sciter
window title, tray tooltip, install path and registry all read. The remaining leak
is the extracted filename (finding 4).

Fix in the workflow's `Build rustdesk` step, before packaging:

```bash
mv ./target/release/rustdesk.exe ./Release/RAYNODesk.exe
```

and pass `-e ../../Release/RAYNODesk.exe` to `generate.py`. The `rustdesk` sentinel
bytes at `generate.py:61,76` are internal framing for the blob, not a user-visible
name, so they stay unchanged.

### 3. Colors

Replace the three remaining old-blue values (finding 3) with `39B7FF`. The banner
at `index.tis:606` also carries "Copyright © 2026 Purslane Tech Pte. Ltd." — that is
upstream's legal attribution. **I will not change that text without explicit
instruction**; recorded under Known limits.

### 4. Persian

In the existing `apply_client_branding()` in `src/common.rs`, alongside the
`conn-type` and `hide-powered-by-me` inserts:

```rust
config::DEFAULT_LOCAL_SETTINGS
    .write()
    .unwrap()
    .insert(keys::OPTION_LANGUAGE.to_owned(), "fa".to_owned());
```

`keys::OPTION_LANGUAGE` resolves through `keys.rs:6` (`pub use
hbb_common::config::keys::*`) to `"lang"` at `hbb_common/src/config.rs:2868`, and
`keys.rs:221` confirms it is in `KEYS_LOCAL_SETTINGS`.

Nothing to change on the setup page itself: its 10 keys are already translated in
`fa.rs:155-161`. Only the EULA URL at `install.tis:53` needs to stop pointing at
rustdesk.com. **The user must supply the URL** — I will not invent one.

### 5. Icon "RD"

Generate a new multi-resolution `res/icon.ico`: `RD` in white on `39B7FF`, at
16/32/48/128/256 px, matching the sizes `res/gen_icon.sh` produces. Replace
`res/tray-icon.ico` with an `RD` in the same color.

`res/gen_icon.sh` uses ImageMagick (`convert`), which is not present on this Windows
machine. Plan is to generate the ICO with a small Python script using Pillow. If
Pillow is absent and cannot be installed (no network), this item is blocked and
needs the user's decision.

The Flutter icon (`flutter/windows/runner/resources/app_icon.ico`) is left alone —
it affects only the 64-bit Flutter build, out of scope for the 32-bit deliverable.

## Regression surface

| File | Change | Why unavoidable |
|---|---|---|
| `.github/workflows/rayno-win32.yml` | publish unconditional, exe renamed before packing | the requested deliverable |
| `src/common.rs` | one `DEFAULT_LOCAL_SETTINGS` insert in `apply_client_branding()` | Persian default |
| `src/ui/index.tis:606`, `header.tis:18`, `file_transfer.tis:25` | color literals | remaining old blue |
| `src/ui/install.tis:53` | EULA URL | requested |
| `res/icon.ico`, `res/tray-icon.ico` | binary | requested |

No existing runtime path changes behavior apart from the default language. The
`conn-type=incoming` and `hide-powered-by-me` settings are untouched.

## Known limits

- **The Sciter UI stays LTR under Persian.** Text is Persian, layout is left-to-right.
  Making it RTL needs a per-locale direction switch that does not exist in Sciter
  here. Recorded rather than attempted.
- **The copyright banner at `index.tis:606` keeps "Purslane Tech Pte. Ltd."** It is
  upstream's legal attribution. Color only, text untouched, pending instruction.
- **MSI installer strings stay English.** `res/msi/Package/Language/` has only
  `en-us`. The 32-bit portable build does not use MSI, so the deliverable is
  unaffected. Adding a `fa-ir.wxl` is a separate task.
- **Windows SmartScreen will warn** on the unsigned exe. Fixing that needs a code
  signing certificate.
- **`fa.rs` has 3 empty entries** (`terminal-clipboard-write-tip` at 766, and two
  voice-call keys). They degrade to English. Pre-existing, not touched.
- **8 keys used by the Sciter UI are missing from every lang file** (`WOL`, `Key`,
  `Email`, `Insert`, `Clear permanent password`, `Direct IP Access Settings`,
  `Click to update`/`Click to download`, the auto-update advisory). They render as
  raw English in Persian. Pre-existing; adding them means new keys in
  `template.rs` plus every lang file, which is a separate task.

## Verification

1. `python res/inline-sciter.py` then confirm `39B7FF` appears in the generated
   Sciter output.
2. Local Rust compile is not possible on this machine (no working `gcc.exe`), so
   rely on CI.
3. After the next 32-bit run: download the artifact, confirm the zip contains
   `RAYNODesk.exe` (not `rustdesk.exe`), run it, check the window title, tray
   tooltip, Persian UI, and that no outgoing-remote UI is present.
4. Confirm the release page shows the standalone exe.

## Open questions for the user

1. **EULA / privacy URL** — what should `install.tis:53` point to?
2. **Copyright line** — leave "Purslane Tech Pte. Ltd." or change it?
3. **Icon design** — `RD` white on `39B7FF`, or another treatment? Also is `RD` for
   the tray icon too, or does the tray stay a plain glyph?