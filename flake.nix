{
  description = "Home Automation tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs = {
      nixpkgs.follows = "nixpkgs";
      flake-utils.follows = "flake-utils";
    };
  };

  outputs = {
    nixpkgs,
    flake-utils,
    rust-overlay,
    ...
  }: let
    rust-xtensa-overlay = final: prev: {
      llvmPackages_xtensa = prev.llvmPackages_16.override {
        monorepoSrc = let
          espressif-llvm = prev.fetchFromGitHub {
            owner = "espressif";
            repo = "llvm-project";
            rev = "0b255ec2fb67b3469af4b7e1336a64ed60f4e251";
            sha256 = "sha256-bnSnyPq30Cc6bz6T/FVMgdBk6HGmgTTgRirJMBWDC0c=";
          };
        in
          final.runCommand "espressif-llvm-prepatched" {} ''
            cp -r ${espressif-llvm} $out
            chmod -R u+w $out
            cd $out/llvm
            patch --strip=1 < ${./nix-llvm-prepatch.patch}
          '';
      };

      rust-esp = prev.callPackage ./esp-rs-rust.nix {
        inherit (final.darwin.apple_sdk.frameworks) CoreFoundation Security SystemConfiguration;
        llvm_16 = final.llvmPackages_xtensa.libllvm;
        llvmPackages_16 = final.llvmPackages_xtensa;
        rustNixPath = "${nixpkgs}/pkgs/development/compilers/rust/default.nix";
      };
    };
  in
    (flake-utils.lib.eachSystem flake-utils.lib.allSystems (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          rust-xtensa-overlay
          rust-overlay.overlays.default
        ];
      };
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = [
          pkgs.arduino
          pkgs.cargo-binutils
          pkgs.cargo-espflash
          pkgs.espup
          pkgs.esptool
          pkgs.gdb
          pkgs.minicom
          pkgs.probe-rs
          pkgs.rust-esp.packages.stable.cargo
          pkgs.rust-esp.packages.stable.rustc
        ];
      };
    }))
    // {
      overlays.default = rust-xtensa-overlay;
    };
}
