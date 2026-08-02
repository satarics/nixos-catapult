# Catapult for NixOS

This repository provides a NixOS package for [Catapult](https://github.com/qrrk/Catapult) — a cross-platform launcher and content manager for Cataclysm: Dark Days Ahead (DDA) and Bright Nights (BN).

## Why a special package for NixOS?

Running Catapult on NixOS out-of-the-box is tricky due to three specific challenges. This package solves them using a 3-layer architecture:

1. **Read-only Store vs. Godot's Save System:** Godot writes saves and configs relative to the executable path. Since `/nix/store` is read-only, we copy the binary to a writable `XDG_DATA_HOME/catapult` directory on first run.
2. **Godot's `dlopen` behavior:** Godot 4.x loads X11/Wayland/OpenGL libraries via `dlopen()` at runtime, not via `DT_NEEDED`. Nix's `autoPatchelfHook` cannot detect these. We manually inject them via `LD_LIBRARY_PATH`.
3. **Hardcoded FHS Paths:** Catapult internally calls `/bin/bash -c "tar ... && find ..."`. NixOS doesn't have a standard FHS. We wrap the app in `buildFHSEnv` to provide these exact paths.

## Quick Start (Run without installing)

If you have Nix with flakes enabled, you can run it immediately without installing:

```bash
nix run github:satarics/nixos-catapult
```

## Installation

### Method 1: Using Flakes (Recommended)

**For NixOS (System-wide):**

Add the input to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    catapult.url = "github:satarics/nixos-catapult";
  };

  outputs = { self, nixpkgs, catapult }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        catapult.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

**For Home Manager:**

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    catapult.url = "github:satarics/nixos-catapult";
  };

  outputs = { self, nixpkgs, home-manager, catapult }: {
    homeConfigurations.your-username = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        catapult.homeManagerModules.default
      ];
    };
  };
}
```

### Method 2: Classic Nix (Without Flakes)

If you don't use flakes, you can import the package directly.

**Local clone (Most reliable for classic Nix):**

```bash
git clone https://github.com/satarics/nixos-catapult.git ~/nixos-catapult
```

Then in your `configuration.nix` or `home.nix`:

```nix
{ pkgs, ... }:

let
  catapult = import ~/nixos-catapult/default.nix { inherit pkgs; };
in
{
  environment.systemPackages = [ # or home.packages for HM
    catapult.package
    catapult.desktopItem
  ];
}
```

**Using `fetchTarball` (Requires the repo to be pushed to GitHub):**

```nix
{ pkgs, ... }:

let
  catapult = import (builtins.fetchTarball {
    url = "https://github.com/satarics/nixos-catapult/archive/refs/heads/main.tar.gz";
  }) { inherit pkgs; };
in
{
  environment.systemPackages = [
    catapult.package
    catapult.desktopItem
  ];
}
```

### Method 3: As an Overlay

If you prefer to inject it into `pkgs` directly:

```nix
{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (import (builtins.fetchTarball {
      url = "https://github.com/satarics/nixos-catapult/archive/refs/heads/main.tar.gz";
    } + "/overlay.nix"))
  ];

  environment.systemPackages = with pkgs; [
    catapult
  ];
}
```

## Configuration & Data

By default, Catapult stores its data (including the mutable copy of the binary and game saves) in:
`~/.local/share/catapult` (or `$XDG_DATA_HOME/catapult`).

You can override this location by setting the `CATAPULT_DATA_DIR` environment variable:

```bash
CATAPULT_DATA_DIR=/path/to/custom/dir nix run github:satarics/nixos-catapult
```

## Future Plans & Roadmap

## Roadmap / Future Plans

- [ ] **Support for older game builds:** Currently, older versions of Cataclysm: DDA/BN fail to launch through the packaged launcher. Need to investigate and fix compatibility for legacy builds.
- [ ] **Fix desktop entry icon:** The `.desktop` file currently doesn't show the proper icon. Need to extract the actual Catapult icon from the upstream release and link it correctly in `pkgs.makeDesktopItem`.
- [ ] **Submit to NUR:** Register the package in the [Nix User Repository (NUR)](https://github.com/nix-community/nur) once the package stabilizes.
