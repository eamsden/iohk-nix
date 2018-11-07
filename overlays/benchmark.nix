{ pkgs, filter }:

with import ../../lib.nix;

self: super: {
  mkDerivation = args: super.mkDerivation (args // optionalAttrs (filter args.pname) {
    # Enables building but not running of benchmarks for all
    doBenchmark = true;
    configureFlags = (args.configureFlags or []) ++ ["--enable-benchmarks"];
  } // optionalAttrs (isBenchmark args) {
    # Provide a dummy installPhase for benchmark packages.
    installPhase = "mkdir -p $out";
  });
}
