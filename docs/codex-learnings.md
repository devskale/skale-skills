# Learnings from the Codex repo

Grundlage der Coding-Guidelines in [CONVENTION.md → Coding Guidelines](../CONVENTION.md) und
der Empfehlung in [AGENTS.md](../AGENTS.md) ("as implementation gets cheaper, tests, boundaries,
and lint matter more, not less").

> **Quelle:** John J. Wang, *Learnings from the Codex repo* (2026-08-27)
> <https://johnjwang.com/post/2026/08/27/learnings-from-the-codex-repo/>
>
> Analyse von OpenAI's Open-Source-[Codex-Repo](https://github.com/openai/codex), erstellt mit
> Codex (gpt-5.6-sol) + Claude Code (Fable 5).

## Kernaussage

> **As implementation gets cheaper, the rest of engineering gets *more* important, not less.**

OpenAI's Codex-Repo skaliert auf **135 Autoren / ~900 Commits pro Monat** (neben Agents). Das
funktioniert nur, weil in Tests, Grenzen (boundaries), Abstraktionen und automatisierte Linting-
Systeme investiert wird — klassische Engineering-Exzellenz. Die Meta-Lehre: billigere
Implementierung macht Tests, Grenzen und Lint **wichtiger**, nicht überflüssiger.

## Datenpunkte (Velocity)

| | Mai 2025 | März 2026 | Aug 2026 |
|---|---|---|---|
| Commits pro Monat | 98 | 791 | 893 |
| Regelmäßige Autoren (5+ Commits) | 2 | 28 | 35 |
| Anteil des aktivsten Autors | 91% | 14% | 18% |
| Autoren an einem Median-Tag | 1 | 12 | ~18 |
| Rust-Crates am Median-Tag | 4 | 16 | ~28 |

## Wie Codex die Regeln ableitet (Muster)

1. Ein Problem taucht **wiederholt in Code-Review** auf.
2. Es wird in **`AGENTS.md`** geschrieben, damit Menschen *und* Agents es VOR der Änderung sehen.
3. Sobald die Regel stabil und objektiv prüfbar ist, wird sie zu einem **Lint / CI-Check**.
4. Nicht jede Regel schafft den letzten Schritt — aber die teuren und objektiv prüfbaren tun es.

Codex hat **38 Lint-Regeln** — viele automatisierte Checks verhindern Out-of-Policy-Verhalten
deterministisch.

## Konkrete Regeln aus Codex' AGENTS.md

- **"Never add or modify any code related to `CODEX_SANDBOX_NETWORK_DISABLED_ENV_VAR` / `CODEX_SANDBOX_ENV_VAR`."** — Tests prüfen diese Variablen; ein Agent könnte sie als "im Weg" sehen und "fixen". Bekannte Cheat-Verhalten aus Testläufen werden als Regel kodiert.
- **"Do not add tests for values that are statically defined"** und **"Do not add negative tests for logic that was removed."** — verhindert plausibel aussehende Test-Volumen ohne echten Verhaltens-Check; hält die Suite auf regressionsfähiges Verhalten fokussiert.
- **"Features that change the agent logic MUST add an integration test."** — Agent-Verhalten kommt aus Kombination von Kontext, Tools, Modell-Antworten und Turn-Loop; ein kleiner Unit-Test reicht oft nicht. Codex nutzt dafür den `TestCodexBuilder`-Harness (realer Agent-Loop gegen Fake-Modell-Streams).
- **"Avoid bool or ambiguous `Option` parameters."** — opake Werte wie `false`, `None` oder nackte Zahlen brauchen einen exakten `/*param_name*/`-Kommentar daneben.

## Lint-Regeln (Beispiel: mehrdeutige Argumente)

```rust
// vorher — ohne Kontext nicht reviewbar
foo(false, None, 1000)

// nachher — Kommentar muss exakt dem Parameternamen entsprechen
foo(
    /*enabled*/ false,
    /*parent_turn_id*/ None,
    /*timeout_ms*/ 1000,
)
```

Daraus baute das Team einen **Custom-Lint**, der prüft, ob der Kommentar exakt dem
Parameternamen in der Funktionsdefinition entspricht (eingeführt März 2026, danach in Bazel-CI).

## Investition in einen Integration-Test-Harness

- Tests umfassen **~615k Zeilen (~40% des Codebase)**.
- ~7k Zeilen über 300+ Commits für einen Mock-Harness, der HTTP-Antworten der Responses-API stubbed — läuft einen **echten Codex-Thread** (Tools, Approvals, Iteration), deterministisch.

## Gestaffeltes Testen (nur relevante Tests während Dev)

Codex läuft NICHT dieselbe riesige Suite in jeder Stufe:

1. **Während der Änderung:** nur der betroffene Rust-Crate (z. B. Terminal-UI-Tests, nicht der ganze Workspace) → schneller Edit-Test-Loop.
2. **Vor Merge (CI):** Bazel über macOS/Linux/Windows + separate Jobs für SDKs, Formatting, Dependencies, Repo-Regeln; größte Workloads über Maschinen verteilt, Remote-Build-Cache.
3. **Nach main:** vollständige Cargo-Suite über 5 Plattform-/Architektur-Kombinationen, Binaries paketiert und über 4 Maschinen verteilt; langsame native Windows-Checks, Release-Builds, Remote-Env-Tests.

→ Nur relevante Tests beim Entwickeln, progressiv gründlicher je näher am Deployment → schnell
shippen UND langfristig sicher.

## Migrationen mit Linting + Feature-Flags

Große Änderungen werden gestaffelt (alt + neu koexistieren), der Migrationsplan wird in
Lint-Regeln kodiert statt auf Erinnerung zu bauen.

**TUI-Migration als Beispiel:**
- 16. März: temporäre Parallel-Implementierung hinter `tui_app_server`-Feature-Flag.
- 26. März: per Default aktiviert.
- Stabilität erreicht → alte TUI + Flag gelöscht (Flag in Config weiter akzeptiert, kein Fehler für Bestandsnutzer).
- 2 Wochen später: **CI-Regel, die TUI am direkten Import von `codex-core` hindert** — verhindert, dass jemand die Arbeit später versehentlich rückgängig macht.

## Fazit: speed == testing, boundaries, lint, hiring

Als die Implementierung billiger wurde, wurde der Rest des Engineerings **nicht** unwichtiger.
Codex investierte stark in die klassischen Säulen: **Testing, hochwertige Boundaries/Abstraktionen,
automatische Linting-Systeme, und gute Leute.**

## Referenzen (Original)

- Artikel: <https://johnjwang.com/post/2026/08/27/learnings-from-the-codex-repo/>
- Codex-Repo: <https://github.com/openai/codex>
- AGENTS.md (Codex): <https://github.com/openai/codex/blob/4fea5234664ebc628b1a5322761cb132eaacc9e2/AGENTS.md>
- Sandbox-Var-Tests: `codex-rs/core/tests/suite/compact_resume_fork.rs`
- Integration-Test-Harness: `codex-rs/core/tests/common/test_codex.rs`
- Custom-Lint (mehrdeutige Argumente): Commit `4b31848f5bd112816eb0f7f4e9a33dc2330ea617`
- TUI-Migration: Commits `db89b73a9cd553ac2a2afda93c9f9bdcc223540c` (Flag), `e7139e14a29de0411a61658a0e5765e2502a0cd2` (default), `d65deec61718f291cba5a51de9489603865779df` (delete), `66e13efd9cfd0dd3525713c8cf27ea7fbcb6b3e4` (CI-Regel)
