{
  description = "dicom4ortho Python and Swift development environments";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # dicom3tools is not in nixpkgs; extract dciodvfy from the Debian package.
        # Only built on x86_64-linux (the .deb is amd64-only).
        dciodvfy = pkgs.stdenv.mkDerivation {
          pname = "dciodvfy";
          version = "1.00-20240118131615-1";
          src = pkgs.fetchurl {
            url = "https://ftp.debian.org/debian/pool/main/d/dicom3tools/dicom3tools_1.00~20240118131615-1_amd64.deb";
            sha256 = "sha256-nVQpLLpjoEEPRGajeV5hbdzz5YRGpvLf7errW4ycx2g=";
          };
          nativeBuildInputs = [ pkgs.dpkg pkgs.autoPatchelfHook ];
          buildInputs = [ pkgs.stdenv.cc.cc.lib ];  # libstdc++6, libgcc_s
          unpackPhase = "dpkg-deb -x $src .";
          installPhase = ''
            mkdir -p $out/bin
            cp usr/bin/dciodvfy $out/bin/
          '';
          dontBuild = true;
          meta.platforms = [ "x86_64-linux" ];
        };
        commonPackages = with pkgs; [ gnumake git gitflow curl jq dcmtk ];
        # Do not pull an amd64 Linux binary into ARM Linux or Darwin shells.
        validationPackages = pkgs.lib.optionals (system == "x86_64-linux") [ dciodvfy ];
        shellHelp = mode: ''
          source ${./tools/development-shell-help.sh} ${mode}
        '';
        pythonShell = pkgs.mkShell {
          packages = commonPackages ++ validationPackages ++ [
            pkgs.python310 pkgs.docker pkgs.docker-compose
          ];
          shellHook = shellHelp "python" + pkgs.lib.optionalString pkgs.stdenv.isLinux ''
            # Expose libstdc++ so pip-installed native wheels (numpy, pillow, etc.) can load.
            export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:''${LD_LIBRARY_PATH:-}"
          '' + ''
            # Refuse stale activation paths and stop on dependency-install errors.
            source python/tools/setup-python-env.sh || exit 1
            echo "dicom4ortho Python shell ready"
            echo "  Python     : $(python --version)"
            echo "  pynetdicom : $(python -c 'import pynetdicom; print(pynetdicom.__version__)')"
          '';
        };
        swiftShell = pkgs.mkShell {
          packages = commonPackages ++ validationPackages;
          # The locked nixpkgs Swift is 5.8, below Package.swift's tools version.
          # Do not inject an incompatible compiler or shadow a user's newer one.
          # Use an explicitly supplied/native toolchain until Nix packages 6.4+.
          shellHook = shellHelp "swift" + ''
            source ${./apple/Tools/SetupSwiftEnvironment.sh} || exit 1
          '';
        };
      in
      {
        devShells = {
          # Preserve the existing bare `nix develop` Python workflow. The startup
          # guidance is informational, never an interactive read that could hang CI.
          default = pythonShell;
          python = pythonShell;
          swift = swiftShell;
        };
      }
    );
}
