# generally the goal is to prevent dumb errors so claude
# can start cooking faster. (uses fewer tokens too)
let
  sources = import ./npins/default.nix;
  pkgs = import sources.nixpkgs { config.allowUnfree = true; };
  systemGitConfig = pkgs.writeTextDir "etc/gitconfig" ''
    [user]
      name = jappeace-sloth
      email = sloth@jappie.me
  '';
  systemPasswd = pkgs.writeTextDir "etc/passwd" ''
    claude:x:1000:100:Claude:/home/claude:${pkgs.bashInteractive}/bin/bash
  '';

  systemGroup = pkgs.writeTextDir "etc/group" ''
    claude:x:100:claude
  '';

  piper-amy-voice = pkgs.fetchgit {
    url = "https://huggingface.co/rhasspy/piper-voices";
    rev = "834f23262168a7e809179465e4113f23f5a7d1f7";
    hash = "sha256-MKBOTTPy3WXUcKa+0+U7HOT5Nm/LuWVqCi7lTMIpo0Y=";
    fetchLFS = true;
    sparseCheckout = [
      "en/en_US/amy/medium/en_US-amy-medium.onnx"
      "en/en_US/amy/medium/en_US-amy-medium.onnx.json"
    ];
  };

  piper-joe-voice = pkgs.fetchgit {
    url = "https://huggingface.co/rhasspy/piper-voices";
    rev = "834f23262168a7e809179465e4113f23f5a7d1f7";
    hash = "sha256-nhZrIjbVBl4vGnRdIh3AOgB38QAyGfdxav2qVxusu+k=";
    fetchLFS = true;
    sparseCheckout = [
      "en/en_US/joe/medium/en_US-joe-medium.onnx"
      "en/en_US/joe/medium/en_US-joe-medium.onnx.json"
    ];
  };

  piper-ryan-voice = pkgs.fetchgit {
    url = "https://huggingface.co/rhasspy/piper-voices";
    rev = "834f23262168a7e809179465e4113f23f5a7d1f7";
    hash = "sha256-55OHFCO5lQl8XMiqvzA+IhjwpUiUB8gtho2QUfLXX+c=";
    fetchLFS = true;
    sparseCheckout = [
      "en/en_US/ryan/medium/en_US-ryan-medium.onnx"
      "en/en_US/ryan/medium/en_US-ryan-medium.onnx.json"
    ];
  };

  piper-voices = pkgs.symlinkJoin {
    name = "piper-voices";
    paths = [ piper-amy-voice piper-joe-voice piper-ryan-voice ];
  };

  piper = pkgs.writeShellScriptBin "piper" ''
    MODEL="''${PIPER_MODEL:-${piper-voices}/en/en_US/amy/medium/en_US-amy-medium.onnx}"
    ${pkgs.piper-tts}/bin/piper -m "$MODEL" "$@"
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
  '';

  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    paths = [
      systemPasswd
      systemGroup
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
      pkgs.cowsay
      pkgs.vlc
      piper
      pkgs.util-linux
      pkgs.jq
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

      "NIX_PATH=nixpkgs=${pkgs.path}" # fixes import <nixpkgs> errors
      "PIPER_VOICES=${piper-voices}/en/en_US"
    ];
    WorkingDir = "/home/claude";
  };
}
