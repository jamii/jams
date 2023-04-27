let

pkgs = import <nixpkgs> {};

zig = pkgs.stdenv.mkDerivation {
    name = "zig";
    src = fetchTarball (
        if (pkgs.system == "x86_64-linux") then {
            url = "https://ziglang.org/builds/zig-linux-x86_64-0.11.0-dev.1797+d3c9bfada.tar.xz";
            sha256 = "1ra25m6xms7lqncpz227z9hy7zdg8pkj542dbpbqsdpdbgy94224";
        } else
        throw ("Unknown system " ++ pkgs.system)
    );
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    installPhase = ''
    mkdir -p $out
    mv ./* $out/
    mkdir -p $out/bin
    mv $out/zig $out/bin
    '';
};

in

pkgs.mkShell rec {
    nativeBuildInputs = [
        zig
        pkgs.wabt
    ];
    buildInputs = [
    ];
}
