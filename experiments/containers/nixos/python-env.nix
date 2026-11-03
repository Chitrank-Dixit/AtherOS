let
  pkgs = import <nixpkgs> { };
in
{
  pythonEnv = pkgs.python3.withPackages (pythonPackages:
    assert pythonPackages.jsonschema.version == "4.26.0";
    [ pythonPackages.jsonschema ]
  );
}
