{ system ? builtins.currentSystem
, crossSystem ? null
, config ? {}
# Set application for getting a specific application nixkgs-src.json
, application ? ""
# Override nixpkgs-src.json to a file in your repo
, nixpkgsJsonOverride ? ""
}:

let
  # Default nixpkgs-src.json to use
  nixpkgsJsonDefault = ./nixpkgs-pins/default-nixpkgs-src.json;
  nixpkgsJson = if (nixpkgsJsonOverride != "") then nixpkgsJsonOverride else
    (if (application != "") then (getNixpkgsJson application) else nixpkgsJsonDefault);

  getNixpkgsJson = application: ./nixpkgs-pins + "/${application}-nixpkgs-src.json";
  jemallocOverlay = import ./overlays/jemalloc.nix;

  commonLib = rec {
    fetchNixpkgs = import ./fetch-nixpkgs.nix;
    # equivalent of <nixpkgs> but pinned instead of system
    nixpkgs = fetchNixpkgs nixpkgsJson;
    getPkgs = let
      system' = system;
      crossSystem' = crossSystem;
      config' = config;
    in { args ? {}
       , extraOverlays ? []
       , system ? system'
       , crossSystem ? crossSystem'
       , config ? config' }:
         import (fetchNixpkgs nixpkgsJson) ({
         overlays = [ jemallocOverlay ] ++ extraOverlays;
         inherit system crossSystem config;
       } // args);
    pkgs = getPkgs {};
    getPackages = pkgs.callPackage ./get-packages.nix {};
    maybeEnv = import ./maybe-env.nix;
    cleanSourceHaskell = pkgs.callPackage ./clean-source-haskell.nix {};
    haskellPackages = import ./haskell-packages.nix;
    commitIdFromGitRepo = pkgs.callPackage ./commit-id.nix {};
  };
  nix-tools = rec {
    # Programs for generating nix haskell package sets from cabal and
    # stack.yaml files.
    package = commonLib.pkgs.callPackage ./nix-tools.nix {};
    # Script to invoke nix-tools stack-to-nix on a repo.
    regeneratePackages =  commonLib.pkgs.callPackage ./nix-tools-regenerate.nix {
      nix-tools = package;
    };
  };

  tests = {
    hlint = ./tests/hlint.nix;
    shellcheck = ./tests/shellcheck.nix;
    stylishHaskell = ./tests/stylish-haskell.nix;
  };

in {
  inherit tests nix-tools jemallocOverlay;
  inherit (commonLib) pkgs haskellPackages fetchNixpkgs maybeEnv cleanSourceHaskell getPkgs nixpkgs commitIdFromGitRepo getPackages;
}
