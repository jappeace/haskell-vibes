let
  sources = import ../npins/default.nix;
  pkgs = import sources.nixpkgs {};
  haskellDeps = hpkgs: with hpkgs; [
    gi-gtk
    gi-gdk
    gi-glib
    gi-gio
    gi-cairo-render
    gi-cairo-connector
    aeson
    vector
    text
    bytestring
    containers
    tasty
    tasty-hunit
  ];
  ghc = pkgs.haskellPackages.ghcWithPackages haskellDeps;
in
pkgs.mkShell {
  buildInputs = [
    ghc
    pkgs.cabal-install
    pkgs.pkg-config
    pkgs.gobject-introspection
    pkgs.gtk4
    pkgs.cairo
  ];
}
