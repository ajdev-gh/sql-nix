# sql-nix

A zero-pollution Nix development shell providing a pre-configured MariaDB database server and MySQL Workbench GUI with GTK Adwaita styling.

All runtime data, logs, CLI query history, and Workbench settings are strictly contained inside the local `.data/` directory.

## Features

* MariaDB Server: Run locally without system-wide services or root privileges.
* MySQL Workbench: Pre-wrapped with Adwaita GTK themes and local configuration path overrides to keep `~` clean.
* Auto Cleanup: Background database process automatically stops when you exit the shell.
* Isolated Environment: Custom `$HOME` and `XDG` path overrides keep history and configs inside `.data/`.

## Prerequisites

* [Nix](https://nixos.org/) with [Flakes enabled](https://nixos.wiki/wiki/Flakes).

## Quick Start

1. Enter the shell:
   - Either clone the flake locally

   ```bash
   git clone https://github.com/ajdev-gh/sql-nix
   cd sql-nix
   nix develop 
   ```
  
   - Or pull the devShell directly in nix (recommended)
  
   ```bash
   nix develop github:ajdev-gh/sql-nix
   ```

2. Start the database:
   ```bash
   db-start
   ```

3. Launch MySQL Workbench:
   ```bash
   workbench
   ```

4. Connect via CLI:
   ```bash
   mariadb -u root --socket=$MYSQL_UNIX_PORT
   ```

5. Stop the database:
   ```bash
   db-stop
   ```

> [!NOTE]
> The database will also automatically shut down when you exit the shell environment.

## Connecting in MySQL Workbench

When setting up your connection inside Workbench:

* Connection Method: Local Socket / Pipe
* Socket Path: Run `echo $MYSQL_UNIX_PORT` to copy your absolute socket path
* Username: root
* Password: (Leave blank)

## Project Structure
```text
.
├── flake.nix
├── flake.lock
├── README.md
└── .data/              # Ignored by Git (stores DB, history, and configs)
    ├── mysql/          # MariaDB data files, socket, and logs
    ├── .mysql/         # Workbench GUI settings and layout state
    └── .mysql_history  # MariaDB CLI command history
```
