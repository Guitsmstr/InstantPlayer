# Core / Models

Cross-feature value types shared by more than one feature (R7) — e.g. the future
`MediaItem` model both Feed and MediaList will consume.

**Placement rule:** a model lives here only when it is needed by more than one
feature (R7). A feature-only model belongs to that feature's `Domain` layer
(`Features/<Feature>/Domain/`). Nothing ships here until a second consumer
actually exists; inventing types ahead of a consumer fabricates product design
that belongs to feature stories.

> Note: this file is named `Models.md` (not `README.md`) because synchronized
> groups copy bundle resources flattened into `Contents/Resources/` — three
> same-named READMEs would collide at build time (design §1, resource-ride fact).
