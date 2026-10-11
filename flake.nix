{
  description = "unist, mdast, and hast as TDL definitions, with the protobuf schema and SDKs generated from them";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    systems.url = "github:nix-systems/default";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    a2b = {
      url = "github:UnstoppableMango/a2b";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
      inputs.flake-parts.follows = "flake-parts";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };

    mangopkgs = {
      url = "github:unmango/pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
      inputs.flake-parts.follows = "flake-parts";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };

    tdl = {
      url = "github:UnstoppableMango/tdl";
      # tdl builds with a newer Go than this flake's nixpkgs may carry.
      inputs.mangopkgs.follows = "mangopkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        inputs.tdl.flakeModules.default
        inputs.treefmt-nix.flakeModule
      ];

      perSystem =
        { inputs', pkgs, ... }:
        let
          defs = [
            "defs/unist/unist.tdl"
            "defs/mdast/mdast.tdl"
            "defs/hast/hast.tdl"
          ];
        in
        {
          packages.default = pkgs.callPackage ./nix {
            inherit (inputs'.a2b.legacyPackages.lib) buf;
            inherit (pkgs.ocamlPackages) ocaml-protoc-plugin;
          };

          # defs/ is the source of truth, and proto/ is generated from it and
          # committed. tdl-gen fails when the two disagree.
          tdl = {
            enable = true;
            package = inputs'.tdl.packages.default;
            src = ./.;
            files = defs;
            gen.files = defs;
            devShell.enable = false;
          };

          devShells.default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              buf
              gnumake
              inputs'.tdl.packages.default
              nixfmt
            ];
          };

          treefmt.programs = {
            buf.enable = true;
            nixfmt.enable = true;
          };
        };
    };
}
