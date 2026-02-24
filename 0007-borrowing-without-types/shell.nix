let

pkgs = import <nixpkgs> {};

zig = pkgs.stdenv.mkDerivation {
    name = "zig";
    src = fetchTarball (
        if (pkgs.stdenv.hostPlatform.system == "x86_64-linux") then {
            url = "https://ziglang.org/download/0.15.2/zig-x86_64-linux-0.15.2.tar.xz";
            sha256 = "sha256:0skmy2qjg2z4bsxnkdzqp1hjzwwgnvqhw4qjfnsdpv6qm23p4wm0";
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
    ];
    buildInputs = [
    ];
}