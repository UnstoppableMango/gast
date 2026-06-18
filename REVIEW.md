# GOALS.md — Senior Review

**Status:** Draft — open for iteration  
**Reviewed:** 2026-06-15  
**Scope:** Architectural feedback on `gast` proposal before implementation begins

---

## Overall

Proposal is well-structured and scoped tightly. RFC keyword discipline (MUST/SHOULD/MAY) is good. But there are critical architectural questions that need answers before implementation starts.

---

## Critical

### 1. TreeSitter is the elephant in the room

TreeSitter is a production, polyglot parse tree library with grammars for Go, OCaml, Nix, TypeScript, and 100+ others. It's used by Neovim, GitHub Linguist, and major editors. The proposal must address it — either explain why it fails for this use case, or reconsider the entire approach. Ignoring it in the goals doc is a red flag to any reviewer.

### 2. OpenAPI is the wrong primitive for AST schemas

OpenAPI 3.1 was designed for REST request/response contracts. ASTs are recursive, deeply-nested, discriminated-union trees. This mismatch causes:

- Discriminated unions (`oneOf` over dozens of node kinds) are verbose and tooling support is inconsistent across generators.
- Circular `$ref` handling breaks many OpenAPI SDK generators.
- No native concept of "sealed" type hierarchies.

Better fits: **Protocol Buffers** (strong codegen, binary efficiency, widely polyglot), **JSON Schema** (no REST baggage, more complete recursion support), or **TreeSitter grammars** (already the standard). If OpenAPI is chosen, justify it against these alternatives explicitly.

### 3. No wire format / serialization story

The spec defines *shape* but not *format*. A full TypeScript file AST is often megabytes of JSON. Will actual AST data be JSON? Binary? Streaming? This must be answered before any SDK design makes sense.

### 4. No concrete consumer story

Who uses this and how? The abstract says "code generation pipelines" but never says: Do consumers import an SDK? Download a JSON file? Call a CLI? Without a real usage walkthrough, it's impossible to validate whether OpenAPI is even the right output layer.

---

## Major

### 5. "Pluggable model" is asserted, not designed

§2.1: language support "MUST be pluggable." §3.2 says use `allOf`. That's not a plugin mechanism — that's composition. What does pluggability actually mean? Separate files? A registry? Conditional includes? Needs a design, not a promise.

### 6. `go/ast` derivation isn't straightforward

Go's AST is interface-based: `Node`, `Stmt`, `Expr`, `Decl` are interfaces with many implementors. Mapping Go interfaces → OpenAPI discriminated unions requires explicit design decisions. How does the tool figure out which concrete types implement which interface? How does it handle unexported fields?

### 7. Independent versioning of extensions creates diamond dependency risk

If a consumer depends on `core@2.0` and `go-ext@1.0`, and `go-ext@1.0` was built against `core@1.0`, which wins? The proposal says extensions version independently but doesn't define compatibility guarantees between core and extension versions. This will bite early adopters.

### 8. AST "stage" is undefined

"AST" is ambiguous — it can mean parse tree (pre-analysis), untyped AST, typed/resolved AST, or post-optimization IR. Each stage has different node shapes and information content. The proposal doesn't say which stage `gast` represents. Consumers need to know this.

---

## Minor

### 9. §4 example is confusing

> "re-exports AST types hidden behind `internal` packages (e.g. the Go implementation of the TypeScript compiler)"

What is "the Go implementation of the TypeScript compiler"? If this means `microsoft/TypeScript-Go`, say that explicitly. If it means something else, clarify.

### 10. Nix complexity is underappreciated

Nix is a lazy, dynamically-scoped language where parsing and evaluation are intertwined (thunks, attribute set merging, `builtins`). A purely static parse tree representation loses significant semantic content. "Best-effort" is honest but the section should acknowledge what specifically won't be captured.

### 11. No spec update process

When Go 1.23 ships a new AST node type, what triggers a `gast` update? Is derivation manual? Automated in CI? The version section covers *how to bump versions*, not *how updates are detected or triggered*.

---

## Suggested Additions

1. **Comparison table:** gast vs. TreeSitter vs. LSP vs. language-server ASTs — one table, three rows, four columns (coverage, format, codegen, maintainability).
2. **End-to-end example:** "Given a `.go` file, a consumer produces X by doing Y using a gast SDK." Even pseudocode.
3. **Core schema sketch:** Even a 10-line YAML block showing what a base node actually looks like in OpenAPI 3.1 — it will immediately reveal the discriminated-union pain.
4. **Update cadence policy:** Define how `gast` tracks upstream language AST changes (e.g. "Go AST changes tracked within one minor release").

---

## Summary

Scope discipline is good — the out-of-scope list especially is clear and useful. But the format choice (OpenAPI) needs explicit justification against TreeSitter and protobuf, and the proposal can't move to implementation without a wire format decision and a real consumer story.

---

*Open items to resolve before implementation:*

- [x] Address TreeSitter comparison (#1)
- [x] Justify OpenAPI vs. alternatives or switch (#2)
- [x] Define wire format (#3)
- [x] Write end-to-end consumer example (#4)
- [x] Design plugin mechanism (#5)
- [x] Define `go/ast` derivation strategy (#6)
- [x] Define core↔extension version compatibility contract (#7)
- [ ] Specify which AST stage `gast` targets (#8)
