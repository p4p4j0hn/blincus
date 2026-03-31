{
  description = "Manage development containers with Incus";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        pname = "blincus";
        wrapScript = name: pkgs.writeShellScriptBin name (builtins.readFile ./${name});
        generateRunnablePackage = {
          name,
          dependencies,
        }:
          pkgs.symlinkJoin {
            name = "${name}";
            paths =
              if dependencies != null
              then [(wrapScript name)] ++ dependencies
              else [(wrapScript name)];
            buildInputs = [pkgs.makeWrapper];
            postBuild = ''
              ${
                if name == pname
                then "wrapProgram $out/bin/${name} --prefix PATH : $out/bin"
                else "wrapProgram $out/bin/${name} --prefix PATH : $out/bin/${pname}-${name}"
              }

              # Install bash completions for the main blincus package
              ${
                if name == pname
                then ''
                  mkdir -p $out/share/bash-completion/completions
                  cp ${./completions.bash} $out/share/bash-completion/completions/${name}
                ''
                else ""
              }
            '';
          };
      in {
        packages = {
          default = self.packages.${system}.blincus;
          ${pname} = generateRunnablePackage {
            name = "${pname}";
            dependencies = with pkgs; [
              incus
              jq
              xhost # X11 host access control (renamed from xorg.xhost)
              coreutils
              gnugrep
              gnused
              getent
              util-linux
              dconf
              coreutils-full
              # Wayland support
              wayland
              wayland-protocols
              wayland-utils
              # PipeWire audio support
              pipewire
              wireplumber
            ];
          };
          install = generateRunnablePackage {
            name = "install";
            dependencies = with pkgs; [curl wget gnutar coreutils];
          };
          uninstall = generateRunnablePackage {
            name = "uninstall";
            dependencies = with pkgs; [coreutils];
          };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [shellcheck nodePackages.bash-language-server];
          shellHook = ''
            echo "Entering Nix dev shell"
            export PS1="[nix-shell] $PS1"
          '';
        };

        formatter = pkgs.alejandra;
      }
    );
}
