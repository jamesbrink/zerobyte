{
  description = "Zerobyte - Backup automation for remote storage";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };

        # Common packages for all platforms
        commonPackages = with pkgs; [
          # JavaScript runtime and package manager
          bun
          nodejs_22

          # Development tools
          biome
          typescript

          # Database tools
          sqlite

          # Version control
          git

          # Runtime dependencies for backups
          restic
          rclone
        ];

        # Linux-specific packages for full functionality
        linuxPackages = with pkgs; [
          # FUSE for mounting
          fuse3
          sshfs

          # Mount tools
          nfs-utils
          cifs-utils
          davfs2

          # SSH for SFTP
          openssh
        ];

        # macOS-specific packages
        # Note: macfuse must be installed via Homebrew: brew install --cask macfuse
        darwinPackages = with pkgs; [
          # SSH for SFTP repository backend
          openssh
        ];

        platformPackages = if pkgs.stdenv.isDarwin
          then darwinPackages
          else linuxPackages;

      in {
        devShells.default = pkgs.mkShell {
          buildInputs = commonPackages ++ platformPackages;

          shellHook = ''
            echo ""
            echo "  ╔═══════════════════════════════════════════════╗"
            echo "  ║     Zerobyte Development Environment          ║"
            echo "  ╚═══════════════════════════════════════════════╝"
            echo ""
            echo "  Platform: ${system}"
            echo "  Bun:      $(bun --version 2>/dev/null || echo 'not found')"
            echo "  Restic:   $(restic version 2>/dev/null | head -1 || echo 'not found')"
            echo "  Rclone:   $(rclone version 2>/dev/null | head -1 || echo 'not found')"
            echo ""
            ${if pkgs.stdenv.isDarwin then ''
            echo "  ⚠️  macOS Notes:"
            echo "     - Remote mount backends (NFS, SMB, WebDAV, SFTP, Rclone)"
            echo "       are not supported on macOS"
            echo "     - Use Directory backend or cloud repository backends"
            echo "     - For macFUSE (optional): brew install --cask macfuse"
            echo ""
            '' else ''
            echo "  ✓ Linux detected - full functionality available"
            echo ""
            ''}
            echo "  Quick Start:"
            echo "    bun install     - Install dependencies"
            echo "    bun run dev     - Start development server"
            echo "    bun run build   - Build for production"
            echo "    bun run test    - Run tests"
            echo "    bun run tsc     - Type check"
            echo ""
          '';

          # Environment variables for development
          DATABASE_URL = "";  # Uses platform default from getPaths()
          NODE_ENV = "development";
        };

        # Package for building Zerobyte
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "zerobyte";
          version = "0.19.0";
          src = ./.;

          nativeBuildInputs = with pkgs; [ bun nodejs_22 ];

          buildPhase = ''
            export HOME=$TMPDIR
            bun install --frozen-lockfile
            bun run build
          '';

          installPhase = ''
            mkdir -p $out/bin $out/share/zerobyte

            cp -r dist $out/share/zerobyte/
            cp -r node_modules $out/share/zerobyte/
            cp package.json $out/share/zerobyte/

            cat > $out/bin/zerobyte << EOF
            #!/bin/sh
            cd $out/share/zerobyte
            exec ${pkgs.bun}/bin/bun run start "\$@"
            EOF
            chmod +x $out/bin/zerobyte
          '';

          meta = with pkgs.lib; {
            description = "Backup automation for remote storage";
            homepage = "https://github.com/nicotsx/zerobyte";
            license = licenses.agpl3Only;
            platforms = platforms.unix;
          };
        };
      }
    );
}
