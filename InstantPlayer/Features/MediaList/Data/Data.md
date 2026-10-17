# MediaList — Data layer (placement note)

Deliberately empty in E5-S1 (design §1.1): the list performs **no I/O**.
Rows are display-only projections of the already-materialized
`MediaCollection` (Core) — file names read from values already resident in
memory, inside the security-scoped session opened at folder open (D19).
There is no framework capability to hide behind a seam and no conformance
to place: D7's "framework capabilities behind seams" has nothing to gate
here, and nothing in this layer can reach the filesystem.

E5-S2's file operations (zip/move/reveal/trash — product R30–R33) land the
first real conformances in this layer: the `MediaItemOperations` domain
seam (working name, design §6.2) acting on the `MediaListSelection` value
— the single seam E5-S1 defines — behind D16's "never rewrite" rule and
inside the D19 session.
