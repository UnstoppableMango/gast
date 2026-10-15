build:
	nix build .#

update:
	nix flake update

check lint:
	nix flake check

format fmt:
	nix fmt

DEFS := defs/unist/unist.tdl defs/mdast/mdast.tdl defs/hast/hast.tdl

generate gen:
	tdl gen ${DEFS}
