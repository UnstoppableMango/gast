# gast — Goals and Scope

## Abstract

`gast` (Global AST) is a project for defining and aggregating programming language abstract syntax trees (ASTs) in a standardized, polyglot-consumable format. It aims to serve as the common schema layer for code generation pipelines that operate across language boundaries — for example, a pipeline that reads TypeScript source, converts it to a Go representation, and generates Go types. The project's primary output is an OpenAPI 3.1 specification; generated SDKs and tool binaries are secondary outputs.

---

## 1. Goals

### 1.1 Primary Goal

`gast` MUST define a common, extensible schema for programming language ASTs, published as an OpenAPI 3.1 specification. This specification serves as the canonical interchange format for tools that parse, transform, or generate source code across language boundaries.

### 1.2 Secondary Goals

- `gast` SHOULD generate client SDKs from the OpenAPI specification to enable consumption in multiple programming languages without requiring consumers to hand-write schema bindings.
- `gast` SHOULD ship ad-hoc tool binaries that assist in deriving or adapting language ASTs for inclusion in the specification (see [§4. Tool Binaries](#4-tool-binaries)).

---

## 2. Scope

### 2.1 In Scope

- **Core schema definition.** A set of common AST base types (e.g. node kind, source span, children) that all language schemas MUST conform to.
- **Language extensions.** Per-language schema extensions that annotate or extend core types to express language-specific AST structures.
- **Language coverage.** Initial target languages are Go, OCaml, and Nix. The model MUST be pluggable to support additional languages over time.
- **Schema derivation.** Where an official AST definition exists (e.g. `go/ast`, the TypeScript compiler), the `gast` schema SHOULD be derived from that source. Where no official AST exists or is inaccessible, the schema MUST be implemented best-effort and documented as such.
- **OpenAPI 3.1 output.** The specification MUST conform to the OpenAPI 3.1 standard.
- **Generated SDKs.** Client libraries generated from the OpenAPI specification.
- **Tool binaries.** Utilities that assist in the process of making a language's AST accessible for schema derivation (see [§4](#4-tool-binaries)).

### 2.2 Out of Scope

The following are explicitly outside the scope of this repository:

- **AST conversion.** Transforming one language's AST into another (e.g. TypeScript AST → Go AST). Such tools MAY exist separately but MUST NOT be part of this repository.
- **Language server protocols (LSP).** LSP implementations or integrations MAY exist separately but MUST NOT be part of this repository.
- **Compilation.** `gast` is not a compiler and MUST NOT implement compilation pipelines.
- **Runtime evaluation.** `gast` MUST NOT evaluate, interpret, or execute code represented by an AST.
- **Type inference.** Type resolution or inference over AST nodes is out of scope.

---

## 3. Schema Design

### 3.1 Core Types

`gast` MUST define a set of core AST types shared across all language schemas. At minimum, these SHOULD include:

- A base node type with a discriminating `kind` field.
- Source location information (file, line, column, byte offset or span).
- A mechanism for expressing child node relationships.

### 3.2 Language Extensions

Per-language schemas MUST extend core types rather than replacing them. Language-specific fields and node kinds MUST be expressed as OpenAPI schema extensions or composition (e.g. `allOf`) against the core types. This ensures that generic tooling can process any `gast`-conformant AST at the core level without knowledge of a specific language.

### 3.3 Schema Derivation

When an official AST definition exists for a target language, `gast` SHOULD derive its schema from that authoritative source to maximize accuracy and maintainability. The derivation process, including any transformations applied, SHOULD be documented. Where derivation is not possible, the schema MUST be noted as a best-effort implementation.

---

## 4. Tool Binaries

`gast` MAY include ad-hoc tool binaries whose sole purpose is to assist in making a language's AST accessible for schema derivation. These tools are scoped strictly to the problem of AST _acquisition_, not transformation or generation.

Examples of in-scope tool use:

- A Nix-to-OpenAPI parser for languages that do not publish a formal AST (e.g. Nix).
- A source-massaging tool that re-exports AST types hidden behind `internal` packages (e.g. the Go implementation of the TypeScript compiler).

Tool binaries MUST NOT implement AST conversion, code generation, or any functionality listed in [§2.2](#22-out-of-scope).

---

## 5. Versioning

### 5.1 Core

`gast-core` (the shared base schema and common types) MUST be versioned using [Semantic Versioning (SemVer)](https://semver.org/). Changes to core types that break schema compatibility MUST increment the major version.

### 5.2 Language Extensions

Individual language extensions SHOULD be versioned independently of core and independently of each other. Extensions SHOULD use SemVer, but MAY use an alternative versioning scheme if the upstream language's AST definition uses one. Breaking changes to an extension schema MUST be clearly documented regardless of versioning scheme.

### 5.3 Compatibility

AST schema changes SHOULD be considered breaking by default. Additive changes (new optional fields, new node kinds) MAY be treated as minor or patch increments at the maintainer's discretion, provided existing consumers are not affected.

---

## 6. Non-Goals and Constraints

- `gast` MUST NOT take a runtime dependency on any specific cloud provider.
- The OpenAPI specification MUST remain vendor-neutral and consumable by any standards-compliant OpenAPI toolchain.
- `gast` does not aim to be a universal IR (intermediate representation) for compilation; it targets static structure only.

---

*This document is intended to evolve. Sections marked with SHOULD or MAY represent aspirational or flexible guidance and are subject to revision as the project matures.*
