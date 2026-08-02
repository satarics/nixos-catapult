final: prev:
let
  catapult = import ./default.nix { pkgs = final; };
in
{
  catapult = catapult.package;
  catapult-desktop = catapult.desktopItem;
}