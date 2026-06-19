{ buf, protoc-gen-go, ocaml-protoc }:
buf.generate {
  name = "gast";
  src = ../.;

  flags = [
    "--config=${../buf.yaml}"
  ];

  template = buf.mkTemplate {
    managed.enabled = true;
    managed.override = [
      {
        file_option = "go_package_prefix";
        value = "github.com/UnstoppableMango/gast/gen/go";
      }
    ];

    inputs = [
      { directory = "./proto"; }
    ];

    plugins = [
      {
        package = protoc-gen-go;
        out = "gen/go";
        opt = [ "paths=source_relative" ];
      }
      {
        package = ocaml-protoc;
        out = "gen/ocaml";
        # opt = [ "paths=source_relative" ];
      }
    ];
  };
}
