# Definitions

TDL descriptions of syntax trees, the source of truth for everything in `proto/`.
`unist` is the core every other tree builds on.

| Definition | Describes | Generates |
| --- | --- | --- |
| `unist/unist.tdl` | [unist](https://github.com/syntax-tree/unist), the node shape every unified tree shares | `proto/unist/v1/unist.proto` |
| `mdast/mdast.tdl` | [mdast](https://github.com/syntax-tree/mdast), markdown as remark parses it | `proto/mdast/v1/mdast.proto` |
| `hast/hast.tdl` | [hast](https://github.com/syntax-tree/hast), HTML as rehype parses it | `proto/hast/v1/hast.proto` |

Each target block names its `out`, so `make generate` (`tdl gen` over every file) rewrites `proto/`, then runs `buf generate`, which rewrites the Go SDK in `gen/go` from `buf.gen.yaml`.
The SDK is the module `github.com/unmango/treespec`, with one package per tree: `gen/go/unist/v1`, `gen/go/mdast/v1`, and `gen/go/hast/v1`.
Commit the result: `nix flake check` runs `tdl gen --verify` and fails when `proto/` is stale, along with `tdl check` and `tdl fmt --check`.
`tdl.toml` allows the losses a protobuf schema cannot avoid; each is about reading the `.proto` back into TDL, which nothing here does.

`unist.Node` is a node of any tree, for a tool that knows no tree's own types.
A tree's own node, such as an `mdast.v1.Nodes`, rides along packed in its `extensions`.
mdast and hast import `Position` from unist, and unist's `Data`, `Value`, and `Extension` are `google.protobuf.Struct`, `Value`, and `Any`.

## What the definitions loosen

- **Children.** mdast and hast narrow what each parent holds, and TDL cannot name a subset of an enum's variants, so every `children` is a list of any node.
- **Heading depth.** `min(1) max(6)` is a constraint, and the protobuf backend generates no validation.
- **Null.** mdast allows null where a field may be absent. Protobuf has one way to be absent, so those fields are `T?`, and a table column aligned with null is `ALIGN_TYPE_UNSPECIFIED`.
- **hast property values.** hast allows a boolean, a number, a string, null, or a list of strings and numbers. TDL has no untagged union, so `PropertyValue` is a string.

## Not checked yet

UnstoppableMango/tdl held these as `models/` and checked TypeScript generated from them against DefinitelyTyped's `@types/unist`, `@types/mdast`, and `@types/hast`.
That check needs mdast and hast to generate their own copies of `Point` and `Position`, since tdl's typescript backend does not generate a type from another package yet (UnstoppableMango/tdl#1029).
Bring it back here once it does.
