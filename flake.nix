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
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      rust-esp8266-overlay = final: prev: {
        llvmPackages_xtensa = prev.llvmPackages_16.override {
          monorepoSrc = prev.fetchFromGitHub {
            owner = "espressif";
            repo = "llvm-project";
            rev = "c8306cc404d36b072b3aee975495c300c15c56fb";
            sha256 = "sha256-oHLPAQeBHFPwPncNRUcaVOA7qeuAehrMNwiwppPyeNs=";
          };
        };

        rust-esp = prev.callPackage ./esp-rs-rust.nix {
          inherit (pkgs.darwin.apple_sdk.frameworks) CoreFoundation Security SystemConfiguration;
          llvm_16 = final.llvmPackages_xtensa.libllvm;
          llvmPackages_16 = final.llvmPackages_xtensa;
          rustNixPath = "${nixpkgs}/pkgs/development/compilers/rust/default.nix";
        };
      };

      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          rust-esp8266-overlay
          rust-overlay.overlays.default
        ];
      };
    in {
      packages.llvm = pkgs.llvmPackages_xtensa.llvm;

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
        ];
      };
    });
}
