# Nix packaging (getmissionctrl fork)

```nix
inputs.fifine-control-deck = {
  url = "github:getmissionctrl/FifineControlDeck";
  inputs.nixpkgs.follows = "nixpkgs";
};

# in a NixOS configuration
imports = [ inputs.fifine-control-deck.nixosModules.default ];
programs.fifine-control-deck = {
  enable = true;                 # app + 70-fifine-deck.rules (uaccess)
  autostart.enable = true;       # systemd user service, GUI --hidden
  autostart.extraPath = [ pkgs.obs-cmd ];
};
```

`nix run github:getmissionctrl/FifineControlDeck` runs the GUI; `fifine-deck-probe`
is upstream's `probe_device.py`. The udev rule must sort before
`73-seat-late.rules` for `uaccess` to apply, so it ships as a udev package, not
`services.udev.extraRules`.
