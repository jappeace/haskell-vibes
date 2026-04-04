{ uid, gid, voiceName ? "amy" }:
let
  sources = import ./npins/default.nix;
  pkgs = import sources.nixpkgs { config.allowUnfree = true; };
  # passwd needs Nix interpolation for bashInteractive path, so use writeText
  systemPasswd = pkgs.writeText "passwd" ''
    root:x:0:0:System Tech Leadership:/root:/bin/sh
    claude:x:${toString uid}:${toString gid}:Claude:/home/claude:${pkgs.bashInteractive}/bin/bash
    nixbld1:x:30001:30000:Nix build user 1:/var/empty:/sbin/nologin
    nixbld2:x:30002:30000:Nix build user 2:/var/empty:/sbin/nologin
    nixbld3:x:30003:30000:Nix build user 3:/var/empty:/sbin/nologin
    nixbld4:x:30004:30000:Nix build user 4:/var/empty:/sbin/nologin
    nixbld5:x:30005:30000:Nix build user 5:/var/empty:/sbin/nologin
    nixbld6:x:30006:30000:Nix build user 6:/var/empty:/sbin/nologin
    nixbld7:x:30007:30000:Nix build user 7:/var/empty:/sbin/nologin
    nixbld8:x:30008:30000:Nix build user 8:/var/empty:/sbin/nologin
    nixbld9:x:30009:30000:Nix build user 9:/var/empty:/sbin/nologin
    nixbld10:x:30010:30000:Nix build user 10:/var/empty:/sbin/nologin
  '';

  # Voice model definitions
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

  cabal-voice-src = pkgs.fetchFromGitHub {
    owner = "jappeace-sloth";
    repo = "cabal-voice";
    rev = "c25a5dbd46d28becd5edddb53ec81d6688e2ffc1";
    hash = "sha256-0U9uVssZ+qgOk7SeXBICS3EF08pBKJVP+puOXTZGHqc=";
  };

  piper-cabal-voice = pkgs.runCommand "piper-cabal-voice" {} ''
    mkdir -p $out/en/en_US/cabal/medium
    cp ${cabal-voice-src}/en_US-cabal-medium.onnx $out/en/en_US/cabal/medium/
    cp ${cabal-voice-src}/en_US-cabal-medium.onnx.json $out/en/en_US/cabal/medium/
  '';

  morag-voice-src = pkgs.fetchFromGitHub {
    owner = "jappeace-sloth";
    repo = "scottish-tts";
    rev = "75928690dfbea822be6d740a10a9a5c155c4f981";
    hash = "sha256-tMyonoTIyqnSzoU9Z2av44dezwlyHzCeSaM68qn+yYc=";
  };

  piper-morag-voice = pkgs.runCommand "piper-morag-voice" {} ''
    mkdir -p $out/en/en_US/morag/medium
    cp ${morag-voice-src}/scottish-model.onnx $out/en/en_US/morag/medium/en_US-morag-medium.onnx
    cp ${morag-voice-src}/scottish-model.onnx.json $out/en/en_US/morag/medium/en_US-morag-medium.onnx.json
  '';

  # Map voice name to its derivation, defaulting to amy for unknown names
  voiceDerivations = {
    amy = piper-amy-voice;
    joe = piper-joe-voice;
    cabal = piper-cabal-voice;
    morag = piper-morag-voice;
  };

  selectedVoice = voiceDerivations.${voiceName} or piper-amy-voice;
  resolvedVoiceName = if builtins.hasAttr voiceName voiceDerivations then voiceName else "amy";

  piper = pkgs.writeShellScriptBin "piper" ''
    MODEL="''${PIPER_MODEL:-${selectedVoice}/en/en_US/${resolvedVoiceName}/medium/en_US-${resolvedVoiceName}-medium.onnx}"
    ${pkgs.piper-tts}/bin/piper -m "$MODEL" "$@"
  '';

  entrypoint = pkgs.writeScript "entrypoint" (builtins.readFile ./entrypoint.sh);

  env = pkgs.buildEnv {
    name = "image-root";
    paths = [
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.gh
      pkgs.python3
      pkgs.git
      pkgs.curl
      pkgs.xz
      pkgs.su-exec
      pkgs.lix # better nix
      pkgs.w3m
      pkgs.cacert
      pkgs.gnugrep
      pkgs.gnused
      pkgs.which
      pkgs.claude-code
      pkgs.cowsay
      piper
      pkgs.sox
      pkgs.util-linux
      pkgs.jq
      pkgs.openssh
      (pkgs.runCommand "setup-env" {} ''
    # Create necessary directories (added var/empty for nixbld users)

    mkdir -p $out/home/claude $out/tmp $out/var/empty
    mkdir -p $out/etc/nix

    # Write config files directly into the image filesystem rather than
    # as symlinks to nix store paths. Store symlinks created by writeTextDir
    # break when nix GC runs inside the container.
    cp ${./nix.conf} $out/etc/nix/nix.conf
    cp ${./builder-ssh-config} $out/etc/nix/builder-ssh-config
    cp ${systemPasswd} $out/etc/passwd

    cat > $out/etc/nsswitch.conf << 'NSSWITCH'
    passwd:    files
    group:     files
    shadow:    files
    NSSWITCH

    cat > $out/etc/group << 'GROUP'
    root:x:0:
    claude:x:100:
    nixbld:x:30000:claude
    GROUP

    cat > $out/etc/gitconfig << 'GITCONFIG'
    [user]
      name = jappeace-sloth
      email = sloth@jappie.me
    GITCONFIG

    # Set permissions
    chown -R ${toString uid}:${toString gid} $out/home/claude
    chmod 755 $out/home/claude
    chmod 1777 $out/tmp
  '')
    ];
    pathsToLink = [ "/" ];
  };
in

{
  inherit env;
  image =
pkgs.dockerTools.buildImage {
  name = "claude-env";
  tag = "latest";

  copyToRoot = env;

  config = {
    Entrypoint = [ "${entrypoint}" ];
    Env = [
      "HOME=/home/claude"
      "USER=claude"
      "TERM=xterm-256color"
      "COLORTERM=truecolor"
      "NODE_OPTIONS=--dns-result-order=ipv4first"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      # entrypoint.sh starts nix-daemon locally in the container
      "PATH=/bin:/nix/var/nix/profiles/default/bin"

      "NIX_PATH=nixpkgs=${pkgs.path}" # fixes import <nixpkgs> errors
      "PIPER_VOICES=${selectedVoice}/en/en_US"
    ];
    WorkingDir = "/home/claude";
  };
};

}
