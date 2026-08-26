# Custom rules are scoped to commit-type → Bump Type mapping only

`.semver.json` lets a repo customize its Bump Type Rules table (which `type:` keyword produces which Bump Type), but we deliberately kept this pass's scope to that one axis. Two related extensions were considered and explicitly deferred:

- **Type-and-scope combination rules** (e.g. a rule specific to `feat(api):` rather than any `feat:`), which would need a richer rule-matching grammar than a flat keyword table.
- **Release Tag pattern customization**, which is a separate concern (tag recognition, ADR 0001/0003) from Bump Type derivation, and **initial-version override** (the `0.1.0` default when no prior Release Tag exists), which is a separate concern from rule-based bumping entirely.

We decided to ship only the commit-type → Bump Type mapping now, because it's the one piece of "fixed rules" the README already called out as a limitation, and it fits the existing `bump_type_for_range` seam (the data-driven table introduced to hold the built-in `feat`/`fix` rules) without changing the shape of Release Tag recognition or the initial-version rule. This was chosen over a single larger `.semver.json` covering all three axes at once, because each axis has a different validation shape and blast radius — bundling them would have forced premature decisions (e.g. a scope-matching grammar) that aren't needed to solve the immediate problem. Both deferred extensions remain candidates for a future `.semver.json` key, additive to the current `rules` shape.
