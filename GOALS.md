# gast — Goals and Scope

## Abstract

`gast` (Global AST) is a project for defining and aggregating programming language parse trees in a standardized, polyglot-consumable format. The term "AST" is used for approachability; `gast` targets the parse stage with concrete syntax tree (CST) fidelity — preserving whitespace, comments, and source positions as first-class schema data. It aims to serve as the common schema layer for code generation pipelines that operate across language boundaries — for example, a pipeline that reads TypeScript source, converts it to a Go representation, and generates Go types. The project's primary output is a Protocol Buffers schema; generated SDKs and tool binaries are secondary outputs.

---

## 1. Goals

### 1.1 Primary Goal

`gast` MUST define a common, extensible schema for programming language ASTs, published as a Protocol Buffers schema. This schema serves as the canonical interchange format for tools that parse, transform, or generate source code across language boundaries.

### 1.2 Secondary Goals

- `gast` SHOULD generate client SDKs from the protobuf schema to enable consumption in multiple programming languages without requiring consumers to hand-write schema bindings.
- `gast` SHOULD ship ad-hoc tool binaries that assist in deriving or adapting language ASTs for inclusion in the specification (see [§4. Tool Binaries](#4-tool-binaries)).

---

## 2. Scope

### 2.1 In Scope

- **Core schema definition.** A set of common AST base types (e.g. node kind, source span, children) that all language schemas MUST conform to.
- **Language extensions.** Per-language schema extensions that annotate or extend core types to express language-specific AST structures.
- **Language coverage.** Initial target languages are Go, OCaml, and Nix. The model MUST be pluggable to support additional languages over time.
- **Schema derivation.** Where an official AST definition exists (e.g. `go/ast`), the `gast` schema SHOULD be derived from that source. Where no official AST exists or is inaccessible, the schema MUST be implemented best-effort and documented as such.
- **Protocol Buffers schema.** The schema MUST be defined in `.proto` files and conform to proto3 syntax.
- **Generated SDKs.** Client libraries generated from the protobuf schema via `protoc` and language-specific plugins.
- **Tool binaries.** Utilities that assist in the process of making a language's AST accessible for schema derivation (see [§4](#4-tool-binaries)).

### 2.2 Out of Scope

The following are explicitly outside the scope of this repository:

- **AST conversion.** Transforming one language's AST into another (e.g. TypeScript AST → Go AST). Such tools MAY exist separately but MUST NOT be part of this repository.
- **Language server protocols (LSP).** LSP implementations or integrations MAY exist separately but MUST NOT be part of this repository.
- **Compilation.** `gast` is not a compiler and MUST NOT implement compilation pipelines.
- **Runtime evaluation.** `gast` MUST NOT evaluate, interpret, or execute code represented by an AST.
- **Type inference.** Type resolution or inference over AST nodes is out of scope.
- **Name binding and scope resolution.** Resolving which declaration an identifier refers to requires semantic analysis and is out of scope. `gast` represents identifiers as written in source.
- **Post-analysis representations.** Typed ASTs, HIR, MIR, or any IR produced after semantic analysis are out of scope. `gast` targets pre-analysis parse output only (see [§2.3](#23-ast-stage-and-fidelity-target)).

### 2.3 AST Stage and Fidelity Target

`gast` targets the **parse stage** — the representation produced by a language parser before any semantic analysis, type resolution, or name binding is performed.

**Fidelity target: CST-level.** `gast` aims for concrete syntax tree (CST) fidelity: the schema MUST represent whitespace, comments, and source positions as first-class data. Round-trip fidelity to source text SHOULD be achievable from a `gast` representation without loss. This is stricter than a minimal abstract syntax tree, which typically discards syntactic noise.

**Out of scope at the schema level:**

- Type resolution or inference (see [§2.2](#22-out-of-scope)).
- Name binding or scope resolution.
- Any information requiring a type-checker or semantic analysis pass.

**When upstream sources are ASTs, not CSTs.** Some languages publish AST definitions rather than CST definitions (e.g., `go/ast` is an AST, though it does carry comment and position data). In these cases, `gast` MUST build toward CST purity: it MUST supplement the upstream AST to represent any syntactic information the upstream drops. Where full CST reconstruction is not feasible, the gap MUST be documented in the language extension schema.

**Why retain the "AST" name.** "AST" is the broadly recognized term for structured representations of parsed source code. `gast` retains it for approachability. The formal intent is a parse-stage, CST-fidelity representation — not the minimal, semantics-only tree a compiler front-end produces.

---

## 3. Schema Design

### 3.1 Core Types

`gast` MUST define a set of core AST types shared across all language schemas. At minimum, these SHOULD include:

- A base node type with a discriminating `kind` field.
- Source location information (file, line, column, byte offset or span).
- A mechanism for expressing child node relationships.

### 3.2 Language Extensions

Per-language schemas MUST extend core types rather than replacing them. The core `Node` type MUST include a `repeated google.protobuf.Any extensions` field. Language-specific concepts that do not map cleanly to core node types MAY be expressed as distinct proto messages packed into that field.

**Plugin contract:**

- **Parsers** MUST populate core fields for all concepts that map to core types. For concepts with no clean core mapping, parsers SHOULD emit a language-specific message (e.g. `NixLambdaPattern`) packed as `Any` in `extensions`.
- **Transformers** MUST process core fields. Transformers MAY unpack and consume known `extensions` entries to enable language-aware behavior (e.g. a Nix→Go transformer consuming `NixLambdaPattern`). Unknown extension type URLs MUST be ignored and SHOULD be forwarded unchanged.
- **Generators** follow the same contract as transformers: core fields are required, extension consumption is optional, unknown extensions MUST be ignored.

This ensures generic pipeline middleware can operate on any `gast`-conformant AST without knowledge of any specific language, while language-aware tools can opt into richer fidelity. The `Any` type URL acts as the extension registry — no central registration is required; consumers check the URL to determine support.

**Extension discovery:** `Any` type URLs are sufficient for v1 — consumers check the URL, unpack or ignore. No central registry required. Extension authors SHOULD compile the necessary proto descriptors into their tools; descriptor distribution or dynamic reflection is optional. Unknown extension types SHOULD be ignored. A well-known namespace (`gast.core.v1.*`) SHOULD be established for extension concepts that appear across multiple languages (e.g. type annotations, visibility modifiers, generics); promoting a concept to well-known enables language-agnostic transformer behavior without per-language handling. Well-known types SHOULD NOT be defined until a concept is observed in two or more language implementations.

### 3.3 Schema Derivation

When an official AST definition exists for a target language, `gast` SHOULD derive its schema from that authoritative source to maximize accuracy and maintainability. The derivation process, including any transformations applied, SHOULD be documented. Where derivation is not possible, the schema MUST be noted as a best-effort implementation.

**Interface and union types.** Source languages often express node categories through interface or union types (Go interfaces, OCaml variants, TypeScript union types). These MUST be mapped to protobuf wrapper messages with a `oneof` field covering all known concrete members, making the type hierarchy explicit and schema-visible. The full member set MUST be documented in the language extension schema.

**Public API surface only.** The gast schema for a language MUST cover only the public, documented API surface of the source AST definition. Internal, unexported, or deprecated members MUST be excluded. Exclusions MUST be documented in the language extension schema with the reason.

*Example — Go:* `go/ast` defines `Node`, `Stmt`, `Expr`, and `Decl` as interfaces with many concrete struct implementors; each maps to a `oneof` wrapper message. Unexported fields and deprecated `*ast.Object` fields (pre-type-checker scope data superseded by `go/types`) are excluded.

### 3.4 Wire Format

The canonical interchange format is protobuf binary. Consumers MUST serialize and deserialize `gast` data using the protobuf binary encoding of the generated types.

---

## 4. Tool Binaries

`gast` MAY include ad-hoc tool binaries whose sole purpose is to assist in making a language's AST accessible for schema derivation. These tools are scoped strictly to the problem of AST _acquisition_, not transformation or generation.

Examples of in-scope tool use:

- A parser for languages that do not publish a formal AST (e.g. Nix).
- A source-massaging tool that re-exports AST types hidden behind `internal` packages (e.g. a hypothetical wrapper around [`microsoft/TypeScript-Go`](https://github.com/microsoft/TypeScript-Go), which provides a pseudo-public Go implementation of the TypeScript compiler's AST but does not export its internal node types directly, were TypeScript a target language).

Tool binaries MUST NOT implement AST conversion, code generation, or any functionality listed in [§2.2](#22-out-of-scope).

---

## 5. Versioning

### 5.1 Core

`gast-core` (the shared base schema and common types) MUST be versioned using [Semantic Versioning (SemVer)](https://semver.org/). Changes to core types that break schema compatibility MUST increment the major version.

### 5.2 Language Extensions

Individual language extensions SHOULD be versioned independently of core and independently of each other. Extensions SHOULD use SemVer, but MAY use an alternative versioning scheme if the upstream language's AST definition uses one. Breaking changes to an extension schema MUST be clearly documented regardless of versioning scheme.

### 5.3 Compatibility

AST schema changes SHOULD be considered breaking by default. Additive changes (new optional fields, new node kinds) MAY be treated as minor or patch increments at the maintainer's discretion, provided existing consumers are not affected.

### 5.4 Core–Extension Compatibility Contract

Independent extension versioning creates diamond dependency risk: a consumer combining `core@2.0` with `go-ext@1.0` (built against `core@1.0`) faces ambiguous compatibility without an explicit contract.

**Core major version as compatibility hub.** Each core major version is a stable compatibility surface (analogous to a k8s storage version hub). All extensions declaring support for a given hub are guaranteed a consistent schema surface. Crossing hub boundaries requires explicit re-validation.

**Extension manifest requirements:**

- Each extension MUST declare `min_core_major` — the minimum core major version the extension supports.
- Each extension SHOULD declare `max_core_major` — the highest core major version the extension has been validated against. If omitted, consumers MUST treat it as equal to `min_core_major`.

**Core backward-compatibility guarantee.** Within a major version, core MUST be backward-compatible: adding optional fields, new message types, or new enum values is non-breaking. Removing, renaming, or retyping any existing field is a major-version break. This guarantee means an extension built against `core@1.0` is guaranteed to work with any `core@1.x`.

**Toolchain enforcement.** Consumers MUST NOT combine an extension with a core version outside its declared range (`min_core_major ≤ core.major ≤ max_core_major`). The `gast` toolchain SHOULD enforce this at schema resolution time (codegen invocation or manifest parse) and MUST emit an error, not a warning, on violation. This mirrors CNI version negotiation: both parties declare supported version ranges; incompatible combinations are rejected at resolution time, not at runtime.

**Upgrade path.** When core increments major (e.g. `core@1.x → core@2.0`), extension authors MUST explicitly bump `max_core_major` after validation. This is a deliberate attestation act, not an automatic assumption. An extension that has not been updated for a new core major MUST be treated as incompatible with that major, even if no schema changes affect it in practice.

### 5.5 Update Detection and Cadence

Upstream language AST changes (e.g. a new node type in Go 1.N) MUST be tracked and incorporated into the corresponding `gast` extension. The update trigger is standard dependency management tooling (e.g. Renovate): when an upstream language package or compiler version is bumped in the `gast` dependency manifest, the extension MUST be reviewed and updated to reflect any AST changes.

Three update paths are defined, in order of increasing automation:

- **Common path:** A maintainer manually reviews upstream AST changes introduced by the version bump and updates the extension schema and parser accordingly.
- **Happy path:** The parser is partially generated from the upstream AST definition. A codegen run after the version bump rebuilds the affected parser components automatically, requiring only human review of the diff.
- **Ideal path:** The parser and schema derivation are fully codegen'd from the upstream AST definition. An automated pipeline (CI) detects the version bump, reruns codegen, and produces a schema update PR with no manual schema authoring required.

Extension authors SHOULD document which update path applies to their extension. Extensions on the common path SHOULD include a changelog entry summarizing AST changes incorporated from each upstream version.

---

## 6. Non-Goals and Constraints

- `gast` MUST NOT take a runtime dependency on any specific cloud provider.
- The protobuf schema MUST remain vendor-neutral and consumable by any standards-compliant `protoc` toolchain.
- `gast` does not aim to be a universal IR (intermediate representation) for compilation; it targets parse-stage, pre-analysis structure only.
- **Streaming protocols** are out of scope for the initial release. They MAY be considered if performance requirements demand it.

---

## 7. Relationship to Existing Tools

### 7.1 TreeSitter

TreeSitter is a production, polyglot parse-tree library used by Neovim, GitHub Linguist, and major editors. It deserves direct comparison.

**TreeSitter solves:** Real-time, incremental, error-tolerant parsing for editor tooling. Given source text, it produces an ephemeral in-memory concrete syntax tree suitable for syntax highlighting, code folding, and structural navigation — including on incomplete or broken code.

**TreeSitter does not solve:**

- **Serialization.** TreeSitter trees are ephemeral in-memory structures with no standard wire format for transmission or storage.
- **Code generation.** TreeSitter is one-directional: source text → tree. There is no mechanism for tree → generated source.
- **Typed node schemas.** TreeSitter nodes are identified by untyped strings (`node.type == "function_declaration"`). There is no schema layer and therefore no SDK generation story.
- **Cross-language shared structure.** Each TreeSitter grammar is independent. There is no common base type shared across grammars, making it impossible to write language-agnostic pipeline middleware.
- **Pipeline interchange.** TreeSitter is a runtime library (C, with language bindings), not a serialization contract. A downstream tool cannot consume a TreeSitter tree without taking a direct runtime dependency on TreeSitter itself.

**`gast`'s position:** `gast` provides the schema layer for source-to-source transformation pipelines, not editor tooling. The primary artifact is a schema-defined, serializable interchange format for lossless CSTs. This enables a pipeline where:

1. A parser produces a `gast`-conformant CST from source (e.g. Nix).
2. The CST is serialized and passed to a transformer tool.
3. The transformer maps the source CST to a target language representation (e.g. Go AST).
4. A generator emits target source from that representation.

TreeSitter MAY serve as an input to step 1 — a TreeSitter parse result could be adapted into a `gast` representation — but it does not replace steps 2–4, nor does it provide the schema contract that makes the pipeline composable across independent tools and languages.

|                     | TreeSitter                 | gast                                    |
| ------------------- | -------------------------- | --------------------------------------- |
| Primary use case    | Editor tooling             | Source-to-source transform pipeline     |
| Direction           | Parse only (source → tree) | Parse + generate (source ↔ tree)        |
| Serialization       | None standard              | Schema-defined interchange format       |
| Node typing         | Untyped strings            | Protobuf schema (typed SDKs via protoc) |
| Cross-language base | None                       | Shared core all extensions conform to   |
| Runtime dependency  | C library required         | Schema-first; any compliant toolchain   |
| Lossless            | Yes (in memory)            | Yes, and serializable                   |
| Error recovery      | Yes (designed for it)      | Not a goal                              |

---

*This document is intended to evolve. Sections marked with SHOULD or MAY represent aspirational or flexible guidance and are subject to revision as the project matures.*
