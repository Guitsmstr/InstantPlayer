# Core / Extensions

Extensions on standard types shared by more than one feature (R7).

**Placement rule:** an extension lives here only when it is needed by more than
one feature (R7). A feature-only extension belongs to that feature (typically its
`Domain` or `Presentation` layer, `Features/<Feature>/…`). Nothing ships here
until a second consumer actually exists; inventing extensions ahead of a consumer
fabricates product design that belongs to feature stories.

> Note: this file is named `Extensions.md` (not `README.md`) because synchronized
> groups copy bundle resources flattened into `Contents/Resources/` — three
> same-named READMEs would collide at build time (design §1, resource-ride fact).
