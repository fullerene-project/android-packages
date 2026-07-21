{
  description = "Android apk nix build environment";

  inputs = {
    nixpkgs-25-05.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-25-11.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    android-nixpkgs.url = "github:tadfisher/android-nixpkgs";
  };

  outputs = { self, ... }@inputs:
    let
      system = "x86_64-linux";
      mkPkgs = input: import input {
        inherit system;
        config.allowUnfree = true;
        config.android_sdk.accept_license = true;
      };

      channels = {
        n25_11 = mkPkgs inputs.nixpkgs-25-11;
        n25_05 = mkPkgs inputs.nixpkgs-25-05;
        unstable = mkPkgs inputs.nixpkgs-unstable;
        sdkGenerator = inputs.android-nixpkgs.sdk.${system};
      };

      breezy-weather = import ./pkgs/org.breezyweather { inherit channels; };
      vetnutri-mp = import ./pkgs/fr.vetbrain.vetnutri_mp { inherit channels; };

    in {
      packages.${system} = {
        "org.breezyweather" = breezy-weather.package;
        "fr.vetbrain.vetnutri_mp" = vetnutri-mp.package;
      };

      devShells.${system} = {
        "org.breezyweather" = breezy-weather.devShell;
        "fr.vetbrain.vetnutri_mp" = vetnutri-mp.devShell;
      };
    };
}
