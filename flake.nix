{
  description = "Development shell with MariaDB, MySQL Workbench, and local history/config caching";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem = { pkgs, ... }:
        let
          workbench-wrapped = pkgs.symlinkJoin {
            name = "mysql-workbench-adwaita";
            paths = [ pkgs.mysql-workbench ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/mysql-workbench \
                --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}" \
                --prefix XDG_DATA_DIRS : "${pkgs.adwaita-icon-theme}/share" \
                --set GTK_THEME "Adwaita" \
                --set GTK_DATA_DIR "${pkgs.adw-gtk3}/share" \
                --set ADW_DISABLE_PORTAL "1"
            '';
          };

          workbench-launcher = pkgs.writeShellScriptBin "workbench" ''
            # Override HOME so Workbench creates .data/.mysql instead of ~/.mysql
            HOME="$PWD/.data" nohup ${workbench-wrapped}/bin/mysql-workbench >/dev/null 2>&1 &
            disown
          '';
          db-start = pkgs.writeShellScriptBin "db-start" ''
            set -e
            MYSQL_DIR="$PWD/.data/mysql"
            MYSQL_DATADIR="$MYSQL_DIR/data"
            MYSQL_UNIX_PORT="$MYSQL_DIR/mysql.sock"
            MYSQL_PID_FILE="$MYSQL_DIR/mysql.pid"
            MYSQL_LOG="$MYSQL_DIR/mariadb.log"

            mkdir -p "$MYSQL_DATADIR"

            if [ ! -d "$MYSQL_DATADIR/mysql" ]; then
              echo "Initializing MariaDB system tables in $MYSQL_DATADIR..."
              ${pkgs.mariadb}/bin/mariadb-install-db \
                --auth-root-authentication-method=normal \
                --datadir="$MYSQL_DATADIR" \
                --basedir="${pkgs.mariadb}" \
                --pid-file="$MYSQL_PID_FILE"
            fi

            if [ -f "$MYSQL_PID_FILE" ] && kill -0 $(cat "$MYSQL_PID_FILE") 2>/dev/null; then
              echo "MariaDB is already running."
            else
              echo "Starting MariaDB background server..."
              ${pkgs.mariadb}/bin/mariadbd \
                --datadir="$MYSQL_DATADIR" \
                --pid-file="$MYSQL_PID_FILE" \
                --socket="$MYSQL_UNIX_PORT" \
                --log-error="$MYSQL_LOG" &

              sleep 1

              if [ -f "$MYSQL_PID_FILE" ]; then
                echo "MariaDB started successfully (PID: $(cat "$MYSQL_PID_FILE"))."
                echo "Socket path: $MYSQL_UNIX_PORT"
              else
                echo "Failed to start MariaDB. Check logs at: $MYSQL_LOG"
                exit 1
              fi
            fi
          '';

          db-stop = pkgs.writeShellScriptBin "db-stop" ''
            MYSQL_DIR="$PWD/.data/mysql"
            MYSQL_PID_FILE="$MYSQL_DIR/mysql.pid"

            if [ -f "$MYSQL_PID_FILE" ]; then
              PID=$(cat "$MYSQL_PID_FILE")
              kill "$PID" 2>/dev/null || true
              rm -f "$MYSQL_PID_FILE"
              echo "MariaDB (PID $PID) stopped."
            else
              echo "No running MariaDB instance found."
            fi
          '';
        in
        {
          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.mariadb
              workbench-wrapped
              workbench-launcher
              pkgs.adw-gtk3
              pkgs.adwaita-icon-theme
              pkgs.gnome-keyring
              db-start
              db-stop
            ];

            shellHook = ''
              # Auto shutdown on shell exit
              trap '${db-stop}/bin/db-stop' EXIT

              if [ -z "$SSH_AUTH_SOCK" ]; then
                eval $(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh 2>/dev/null) >/dev/null
                export SSH_AUTH_SOCK
              fi

              # Project local path definitions
              export MYSQL_HOME="$PWD/.data/mysql"
              export MYSQL_UNIX_PORT="$MYSQL_HOME/mysql.sock"
              
              # Redirect CLI history from ~/.mysql_history to project directory
              export MYSQL_HISTFILE="$PWD/.data/.mysql_history"

              # Redirect Workbench / GTK config and caches from ~/.config and ~/.cache
              export XDG_CONFIG_HOME="$PWD/.data/config"
              export XDG_CACHE_HOME="$PWD/.data/cache"
              export XDG_DATA_HOME="$PWD/.data/share"

              # Create directories automatically
              mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"

              echo "----------------------------------------------------"
              echo "  MariaDB & MySQL Workbench DevShell Ready"
              echo "----------------------------------------------------"
              echo "  - Run 'db-start' to start MariaDB"
              echo "  - Run 'workbench' to launch MySQL Workbench"
              echo "  - Connect CLI: mariadb -u root --socket=\$MYSQL_UNIX_PORT"
              echo "  - Local history saved in: .data/.mysql_history"
              echo "----------------------------------------------------"
            '';
          };
        };
    };
}
