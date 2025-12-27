{
  description = "Zerobyte - Self-hosted backup automation and management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Systems for packages and devShells
      allSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # Linux-only systems for NixOS module and tests
      linuxSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # shoutrrr version and hashes (SRI format)
      shoutrrrVersion = "0.13.1";
      shoutrrrHashes = {
        x86_64-linux = "sha256-TZrDstm5InQOalYf9da5rhnsJm7qTnmG18jLJtvsD8A=";
        aarch64-linux = "sha256-IHgZhsykJbmW/uYUsd6o7Wh3EIsUldduIKFZ0GkjrwI=";
        x86_64-darwin = "sha256-pzmAGRzbWYVHoZqvx6tsuxpuKcfIXMVNPXbKHeeAyxs=";
        aarch64-darwin = "sha256-DKQRzdDd1xccNqetscEKKzgyT1IatOlwPBwa4E8fbDc=";
      };

      # Map Nix system to shoutrrr release naming
      shoutrrrArch = {
        x86_64-linux = "linux_amd64";
        aarch64-linux = "linux_arm64v8";
        x86_64-darwin = "macOS_amd64";
        aarch64-darwin = "macOS_arm64v8";
      };

      # Check if system is Linux
      isLinux = system: builtins.elem system linuxSystems;

      # Package definitions (shared across systems)
      mkPackages = pkgs: system: rec {
        shoutrrr = pkgs.stdenv.mkDerivation {
          pname = "shoutrrr";
          version = shoutrrrVersion;

          src = pkgs.fetchurl {
            url = "https://github.com/nicholas-fedor/shoutrrr/releases/download/v${shoutrrrVersion}/shoutrrr_${shoutrrrArch.${system}}_${shoutrrrVersion}.tar.gz";
            hash = shoutrrrHashes.${system};
          };

          sourceRoot = ".";

          # autoPatchelfHook only needed on Linux
          nativeBuildInputs = pkgs.lib.optionals (isLinux system) [ pkgs.autoPatchelfHook ];

          installPhase = ''
            runHook preInstall
            install -Dm755 shoutrrr $out/bin/shoutrrr
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Notification library and CLI for various services";
            homepage = "https://github.com/nicholas-fedor/shoutrrr";
            license = licenses.mit;
            platforms = platforms.unix;
          };
        };

        zerobyte = pkgs.stdenv.mkDerivation {
          pname = "zerobyte";
          version = "0.1.0";

          src = pkgs.lib.cleanSource ./.;

          nativeBuildInputs = with pkgs; [
            bun
            nodejs
            npmHooks.npmConfigHook
            makeWrapper
          ];

          # Pre-fetched npm dependencies (pure)
          npmDeps = pkgs.fetchNpmDeps {
            src = pkgs.lib.cleanSource ./.;
            hash = "sha256-l2OlExVklyDInPE52WBaXW6d9r8XgC4y4s/b6Ju9sb0=";
          };

          # Handle peer dependency conflicts
          npmFlags = [ "--legacy-peer-deps" ];
          makeCacheWritable = true;

          # Disable fixup phase for node_modules (has many binaries)
          dontFixup = !isLinux system;

          buildPhase = ''
            runHook preBuild

            export HOME=$(mktemp -d)

            # Build the application using bun
            bun run build

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            # Create output directories
            mkdir -p $out/lib/zerobyte
            mkdir -p $out/bin

            # Copy built assets
            cp -r dist/server $out/lib/zerobyte/server
            cp -r dist/client $out/lib/zerobyte/client
            cp -r app/drizzle $out/lib/zerobyte/migrations
            cp package.json $out/lib/zerobyte/
            cp bun.lock $out/lib/zerobyte/

            # Copy node_modules
            cp -r node_modules $out/lib/zerobyte/

            # Create wrapper script with runtime dependencies
            # Note: davfs2 and fuse3 are Linux-only
            makeWrapper ${pkgs.bun}/bin/bun $out/bin/zerobyte \
              --add-flags "$out/lib/zerobyte/server/index.js" \
              --prefix PATH : ${pkgs.lib.makeBinPath ([
                pkgs.restic
                pkgs.rclone
                shoutrrr
                pkgs.openssh
              ] ++ pkgs.lib.optionals (isLinux system) [
                pkgs.fuse3
                pkgs.davfs2
              ])} \
              --set NODE_ENV "production"

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Self-hosted backup automation and management";
            homepage = "https://github.com/nicotsx/zerobyte";
            license = licenses.mit;
            platforms = platforms.unix;
            mainProgram = "zerobyte";
          };
        };

        default = zerobyte;
      };

    in
    flake-utils.lib.eachSystem allSystems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        packages = mkPackages pkgs system;
      in
      {
        packages = packages;

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # JavaScript runtime and package manager
            bun
            nodejs

            # Development tools
            biome
            typescript

            # Nix packaging tools (for updating npmDeps hash)
            prefetch-npm-deps

            # External tools (for local testing)
            restic
            rclone
            packages.shoutrrr

            # Database tools
            sqlite

            # Utilities
            git
            curl
            jq
          ];

          shellHook = ''
            echo "Zerobyte development environment"
            echo "  bun:      $(bun --version)"
            echo "  node:     $(node --version)"
            echo "  restic:   $(restic version | head -1)"
            echo "  rclone:   $(rclone version | head -1)"
            echo ""
            echo "To update npm deps hash:"
            echo "  npm install --package-lock-only --legacy-peer-deps"
            echo "  prefetch-npm-deps package-lock.json"
          '';
        };
      }
    ) // {
      # Overlay
      overlays.default = final: prev: {
        zerobyte = (mkPackages final final.system).zerobyte;
        shoutrrr = (mkPackages final final.system).shoutrrr;
      };

      # NixOS Module
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.services.zerobyte;
        in
        {
          options.services.zerobyte = {
            enable = lib.mkEnableOption "Zerobyte backup management service";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.zerobyte;
              defaultText = lib.literalExpression "pkgs.zerobyte";
              description = "The Zerobyte package to use.";
            };

            user = lib.mkOption {
              type = lib.types.str;
              default = "zerobyte";
              description = "User account under which Zerobyte runs.";
            };

            group = lib.mkOption {
              type = lib.types.str;
              default = "zerobyte";
              description = "Group under which Zerobyte runs.";
            };

            createUser = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Whether to create the user and group automatically.
                Set to false if using an existing user account.
              '';
            };

            dataDir = lib.mkOption {
              type = lib.types.path;
              default = "/var/lib/zerobyte";
              description = "Directory to store Zerobyte data.";
            };

            port = lib.mkOption {
              type = lib.types.port;
              default = 4096;
              description = "Port on which Zerobyte listens.";
            };

            openFirewall = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether to open the firewall for Zerobyte.";
            };

            serverIp = lib.mkOption {
              type = lib.types.str;
              default = "0.0.0.0";
              description = "IP address to bind the server to.";
            };

            timezone = lib.mkOption {
              type = lib.types.str;
              default = "UTC";
              description = "Timezone for scheduling backups.";
            };

            resticHostname = lib.mkOption {
              type = lib.types.str;
              default = "zerobyte";
              description = "Hostname used for restic operations.";
            };

            environment = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = {};
              description = "Additional environment variables for Zerobyte.";
            };

            fuse = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = ''
                  Enable FUSE mounting capabilities.
                  Requires CAP_SYS_ADMIN and access to /dev/fuse.
                  Enables NFS, SMB, and WebDAV volume mounts.
                '';
              };
            };
          };

          config = lib.mkIf cfg.enable {
            users.users.${cfg.user} = lib.mkIf cfg.createUser {
              isSystemUser = true;
              group = cfg.group;
              home = cfg.dataDir;
              createHome = true;
              description = "Zerobyte service user";
            };

            users.groups.${cfg.group} = lib.mkIf cfg.createUser {};

            systemd.services.zerobyte = {
              description = "Zerobyte backup management service";
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];

              environment = {
                NODE_ENV = "production";
                SERVER_IP = cfg.serverIp;
                RESTIC_HOSTNAME = cfg.resticHostname;
                DATABASE_URL = "${cfg.dataDir}/data/ironmount.db";
                TZ = cfg.timezone;
              } // cfg.environment;

              serviceConfig = {
                Type = "simple";
                User = cfg.user;
                Group = cfg.group;
                ExecStart = "${cfg.package}/bin/zerobyte";
                Restart = "on-failure";
                RestartSec = 5;

                # State directory
                StateDirectory = "zerobyte";
                StateDirectoryMode = "0750";
                WorkingDirectory = cfg.dataDir;

                # FUSE capabilities
                AmbientCapabilities = lib.mkIf cfg.fuse.enable [ "CAP_SYS_ADMIN" ];
                CapabilityBoundingSet = lib.mkIf cfg.fuse.enable [ "CAP_SYS_ADMIN" ];
                DeviceAllow = lib.mkIf cfg.fuse.enable [ "/dev/fuse rw" ];

                # Security hardening
                PrivateTmp = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                NoNewPrivileges = !cfg.fuse.enable;
                ProtectKernelTunables = true;
                ProtectKernelModules = true;
                ProtectControlGroups = true;
                RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
                RestrictNamespaces = !cfg.fuse.enable;
                LockPersonality = true;
                MemoryDenyWriteExecute = false; # Required for bun/V8
                RestrictRealtime = true;
                RestrictSUIDSGID = true;
                RemoveIPC = true;
                PrivateMounts = !cfg.fuse.enable;

                # Allow write access to data directory
                ReadWritePaths = [ cfg.dataDir ];
              };
            };

            networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
          };
        };

      # nix-darwin Module (macOS)
      darwinModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.services.zerobyte;
        in
        {
          options.services.zerobyte = {
            enable = lib.mkEnableOption "Zerobyte backup management service";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.zerobyte;
              defaultText = lib.literalExpression "pkgs.zerobyte";
              description = "The Zerobyte package to use.";
            };

            dataDir = lib.mkOption {
              type = lib.types.path;
              default = "/var/lib/zerobyte";
              description = "Directory to store Zerobyte data.";
            };

            port = lib.mkOption {
              type = lib.types.port;
              default = 4096;
              description = "Port on which Zerobyte listens.";
            };

            serverIp = lib.mkOption {
              type = lib.types.str;
              default = "0.0.0.0";
              description = "IP address to bind the server to.";
            };

            timezone = lib.mkOption {
              type = lib.types.str;
              default = "UTC";
              description = "Timezone for scheduling backups.";
            };

            resticHostname = lib.mkOption {
              type = lib.types.str;
              default = "zerobyte";
              description = "Hostname used for restic operations.";
            };

            environment = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = {};
              description = "Additional environment variables for Zerobyte.";
            };
          };

          config = lib.mkIf cfg.enable {
            # Create data directory
            system.activationScripts.zerobyte.text = ''
              mkdir -p ${cfg.dataDir}/data
              chmod 750 ${cfg.dataDir}
            '';

            launchd.daemons.zerobyte = {
              serviceConfig = {
                Label = "org.zerobyte.daemon";
                ProgramArguments = [ "${cfg.package}/bin/zerobyte" ];
                RunAtLoad = true;
                KeepAlive = true;
                WorkingDirectory = "${cfg.dataDir}";

                EnvironmentVariables = {
                  NODE_ENV = "production";
                  SERVER_IP = cfg.serverIp;
                  RESTIC_HOSTNAME = cfg.resticHostname;
                  DATABASE_URL = "${cfg.dataDir}/data/ironmount.db";
                  TZ = cfg.timezone;
                } // cfg.environment;

                StandardOutPath = "/var/log/zerobyte.log";
                StandardErrorPath = "/var/log/zerobyte.error.log";
              };
            };
          };
        };

      # NixOS VM Tests (Linux only)
      checks = builtins.listToAttrs (map (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          name = system;
          value = {
            integration = pkgs.nixosTest {
              name = "zerobyte-integration";

              nodes.machine = { config, pkgs, ... }: {
                imports = [ self.nixosModules.default ];

                services.zerobyte = {
                  enable = true;
                  openFirewall = true;
                };

                # Ensure the test VM has enough resources
                virtualisation = {
                  memorySize = 1024;
                  diskSize = 2048;
                };
              };

              testScript = ''
                machine.start()
                machine.wait_for_unit("zerobyte.service")
                machine.wait_for_open_port(4096)

                # Test healthcheck endpoint
                result = machine.succeed("curl -s http://localhost:4096/healthcheck")
                assert "ok" in result, f"Healthcheck failed: {result}"

                machine.log("Zerobyte integration test passed!")
              '';
            };
          };
        }
      ) linuxSystems);
    };
}
