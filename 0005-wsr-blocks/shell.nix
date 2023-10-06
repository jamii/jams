let

pkgs = import <nixpkgs> {};

in

pkgs.mkShell rec {
    nativeBuildInputs = [
        pkgs.go
    ];
    buildInputs = [
    ];
}
