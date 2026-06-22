{ buf, protoc-gen-go, ocaml-protoc-plugin }:
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
        local = "${ocaml-protoc-plugin}/bin/protoc-gen-ocaml";
        out = "gen/ocaml";
      }
    ];
  };
}
