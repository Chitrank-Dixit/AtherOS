{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    gnumake
    python3
    nodejs
    go
  ];
}
