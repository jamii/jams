{ }:

let

pkgs = import <nixpkgs> {};

zig = pkgs.stdenv.mkDerivation {
        name = "zig";
        src = fetchTarball (
            if (pkgs.system == "x86_64-linux") then {
                url = "https://ziglang.org/builds/zig-linux-x86_64-0.10.0-dev.4060+61aaef0b0.tar.xz";
                sha256 = "062x1l566zxv6b0d4rq5mayipf737c15drgvk2hkgnggihlrfwjf";
            } else
            throw ("Unknown system " ++ pkgs.system)
        );
        dontConfigure = true;
        dontBuild = true;
        installPhase = ''
            mkdir -p $out
            mv ./* $out/
            mkdir -p $out/bin
            mv $out/zig $out/bin
        '';
    };

in

pkgs.mkShell rec {
    buildInputs = [
        zig
        pkgs.glfw
    ];
}