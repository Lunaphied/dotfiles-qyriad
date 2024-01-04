let
  flakeref = builtins.getFlake (toString ./.);
  mkForSystem = self: { system ? builtins.currentSystem }:
    self // {
      packages = self.packages.${system};
      legacyPackages = self.legacyPackages.${system};
    }
  ;
in
  flakeref // {
    __functor = mkForSystem;
  }
