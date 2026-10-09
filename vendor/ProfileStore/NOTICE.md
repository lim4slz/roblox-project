# ProfileStore (vendored)

| Field      | Value |
|------------|-------|
| Package    | `lm-loleris/profilestore` (Wally) |
| Version    | 1.0.3 |
| Author     | loleris (MAD STUDIO) |
| License    | Apache License 2.0 — see [`LICENSE`](./LICENSE) |
| Upstream   | https://github.com/MadStudioRoblox/ProfileStore |
| Docs       | https://madstudioroblox.github.io/ProfileStore/ |
| SHA-256    | `799263dc0d281f360432e172f57ef337761ec38482575273b3cb079d114ecf71` (`ProfileStore.luau`) |

`ProfileStore.luau` is an **unmodified** copy of the module published to the Wally
registry. It is excluded from formatting, linting and strict type analysis because
it is third-party code.

## Updating

1. Download the new version, e.g. `wally install` with
   `ProfileStore = "lm-loleris/profilestore@x.y.z"` in a scratch project, or grab it from
   the Roblox Creator Store asset `109379033046155`.
2. Replace `ProfileStore.luau`, update the version + SHA-256 above.
3. Run the full test suite (`lune run tests/run`) — the integration tests exercise
   session locking, auto-save, DataStore failures and receipt handling through it.
