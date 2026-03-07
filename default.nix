let
  sources = import ./npins/default.nix;
  pkgs = import sources.nixpkgs { config.allowUnfree = true; };
  systemGitConfig = pkgs.writeTextDir "etc/gitconfig" ''
    [user]
      name = jappeace-sloth
      email = sloth@jappie.me
  '';
in

pkgs.dockerTools.buildImage {
  name = "claude-env";
  tag = "latest";
  extraCommands = ''
    # Create necessary directories
    mkdir -p home/claude etc tmp

    # Set permissions
    chown -R 1000:100 home/claude
    chmod 1777 tmp

    # Define user identity for Nix/Bash
    echo "claude:x:1000:100:Claude:/home/claude:${pkgs.bashInteractive}/bin/bash" > etc/passwd
    echo "claude:x:100:claude" > etc/group
  '';

  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    paths = [
      systemGitConfig
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.gh
      pkgs.python3
      pkgs.git
      pkgs.curl
      pkgs.xz
      pkgs.nix
      pkgs.w3m
      pkgs.cacert
      pkgs.gnugrep
      pkgs.gnused
      pkgs.which
      pkgs.claude-code
    ];
    pathsToLink = [ "/" ];
  };

  config = {
    Entrypoint = [ "${pkgs.claude-code}/bin/claude" ];
    Env = [
      "HOME=/home/claude"
      "USER=claude"
      "TERM=xterm-256color"
      "COLORTERM=truecolor"
      "NODE_OPTIONS=--dns-result-order=ipv4first"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      # IMPORTANT: Since you mount the socket, 'daemon' is correct here
      "NIX_REMOTE=daemon"
      "PATH=/bin:/nix/var/nix/profiles/default/bin"
    ];
    WorkingDir = "/home/claude";
  };
}
