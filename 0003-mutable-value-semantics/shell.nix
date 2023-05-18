let

pkgs = import <nixpkgs> {};

zig = pkgs.stdenv.mkDerivation {
    name = "zig";
    src = fetchTarball (
        if (pkgs.system == "x86_64-linux") then {
            url = "https://ziglang.org/builds/zig-linux-x86_64-0.11.0-dev.3202+378264d40.tar.xz";
            sha256 = "0kfrc4zrjhqh0df61b7qgp63vv8kqbp0gggrqrfvp1isb5rhsmqv";
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
