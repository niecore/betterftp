{
  description = "FTP Ramp Test App - Flutter development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Flutter SDK
            flutter

            # General tools
            git
            curl
            unzip
            which
          ];

          shellHook = ''
            # Use system Xcode instead of Nix-bundled SDK
            export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
            unset SDKROOT

            echo "Flutter FTP Ramp Test development environment"
            echo ""
            echo "Platform toolchains (install separately):"
            echo "  - Android: Install Android Studio from https://developer.android.com/studio"
            echo "  - iOS/macOS: Install Xcode from the App Store"
            echo ""
            echo "Run 'flutter doctor' to check your setup"
            echo ""
          '';
        };
      }
    );
}
