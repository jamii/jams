{}: let
  pkgs = import <nixpkgs> {};

  zig = pkgs.stdenv.mkDerivation {
    name = "zig";
    src = fetchTarball (
      if (pkgs.system == "x86_64-linux")
      then {
        url = "https://ziglang.org/download/0.10.1/zig-linux-x86_64-0.10.1.tar.xz";
        sha256 = "1acanv3avbkq50ybwjhp89znx1crvs2jba73giffwkgyniyk2xiq";
      }
      else throw ("Unknown system " ++ pkgs.system)
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
