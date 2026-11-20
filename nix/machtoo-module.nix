{ self }:
{ config, lib, pkgs, ... }:
let
  cfg = config.services.machtoo;
  system = pkgs.stdenv.hostPlatform.system;
in {
  options.services.machtoo = {
    enable = lib.mkEnableOption "Machtoo";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${system}.machtoo or
        (throw "Machtoo is not packaged for ${system}");
      description = "The Machtoo package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
