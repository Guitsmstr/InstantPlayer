# Core / Utilities

Helper types and functions shared by more than one feature (R7).

**Placement rule:** a utility lives here only when it is needed by more than one
feature (R7). A feature-only utility belongs to that feature
(`Features/<Feature>/…`). Framework capabilities (playback, filesystem) are never
utilities here — they are reached only through protocol seams (R11), which live in
`Core/Protocols` when shared and in a feature's `Domain` otherwise. Nothing ships
here until a second consumer actually exists.

> Note: this file is named `Utilities.md` (not `README.md`) because synchronized
> groups copy bundle resources flattened into `Contents/Resources/` — three
> same-named READMEs would collide at build time (design §1, resource-ride fact).
