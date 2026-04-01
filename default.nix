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

  # Python environment for patching voice models with alignment support.
  # pkgs.piper-tts has the piper module but isn't a proper pythonPackage,
  # so we set PYTHONPATH manually to include both piper-tts and onnx.
  onnxPython = pkgs.python3.withPackages (ps: [
    ps.onnx
    ps.onnxruntime
  ]);
  piperSitePackages = "${pkgs.piper-tts}/lib/python${pkgs.python3.pythonVersion}/site-packages";

  # Patch a voice ONNX model to expose phoneme alignment data.
  # This marks the internal Ceil tensor (phoneme durations) as an additional
  # model output so piper can return per-phoneme timing alongside audio.
  patchVoice = name: onnxPath: src:
    pkgs.runCommand "piper-${name}-voice-patched" { nativeBuildInputs = [ onnxPython ]; } ''
      mkdir -p $out/$(dirname ${onnxPath})
      cp -r ${src}/$(dirname ${onnxPath})/* $out/$(dirname ${onnxPath})/
      chmod +w $out/${onnxPath}
      PYTHONPATH="${piperSitePackages}:$PYTHONPATH" \
        python3 -m piper.patch_voice_with_alignment $out/${onnxPath}
    '';

  piper-amy-voice-src = pkgs.fetchgit {
    url = "https://huggingface.co/rhasspy/piper-voices";
    rev = "834f23262168a7e809179465e4113f23f5a7d1f7";
    hash = "sha256-MKBOTTPy3WXUcKa+0+U7HOT5Nm/LuWVqCi7lTMIpo0Y=";
    fetchLFS = true;
    sparseCheckout = [
      "en/en_US/amy/medium/en_US-amy-medium.onnx"
      "en/en_US/amy/medium/en_US-amy-medium.onnx.json"
    ];
  };
  piper-amy-voice = patchVoice "amy"
    "en/en_US/amy/medium/en_US-amy-medium.onnx"
    piper-amy-voice-src;

  piper-joe-voice-src = pkgs.fetchgit {
    url = "https://huggingface.co/rhasspy/piper-voices";
    rev = "834f23262168a7e809179465e4113f23f5a7d1f7";
    hash = "sha256-nhZrIjbVBl4vGnRdIh3AOgB38QAyGfdxav2qVxusu+k=";
    fetchLFS = true;
    sparseCheckout = [
      "en/en_US/joe/medium/en_US-joe-medium.onnx"
      "en/en_US/joe/medium/en_US-joe-medium.onnx.json"
    ];
  };
  piper-joe-voice = patchVoice "joe"
    "en/en_US/joe/medium/en_US-joe-medium.onnx"
    piper-joe-voice-src;

  cabal-voice-src = pkgs.fetchFromGitHub {
    owner = "jappeace-sloth";
    repo = "cabal-voice";
    rev = "c25a5dbd46d28becd5edddb53ec81d6688e2ffc1";
    hash = "sha256-0U9uVssZ+qgOk7SeXBICS3EF08pBKJVP+puOXTZGHqc=";
  };

  piper-cabal-voice-unpacked = pkgs.runCommand "piper-cabal-voice-unpacked" {} ''
    mkdir -p $out/en/en_US/cabal/medium
    cp ${cabal-voice-src}/en_US-cabal-medium.onnx $out/en/en_US/cabal/medium/
    cp ${cabal-voice-src}/en_US-cabal-medium.onnx.json $out/en/en_US/cabal/medium/
  '';
  piper-cabal-voice = patchVoice "cabal"
    "en/en_US/cabal/medium/en_US-cabal-medium.onnx"
    piper-cabal-voice-unpacked;

  morag-voice-src = pkgs.fetchFromGitHub {
    owner = "jappeace-sloth";
    repo = "scottish-tts";
    rev = "75928690dfbea822be6d740a10a9a5c155c4f981";
    hash = "sha256-tMyonoTIyqnSzoU9Z2av44dezwlyHzCeSaM68qn+yYc=";
  };

  piper-morag-voice-unpacked = pkgs.runCommand "piper-morag-voice-unpacked" {} ''
    mkdir -p $out/en/en_US/morag/medium
    cp ${morag-voice-src}/scottish-model.onnx $out/en/en_US/morag/medium/en_US-morag-medium.onnx
    cp ${morag-voice-src}/scottish-model.onnx.json $out/en/en_US/morag/medium/en_US-morag-medium.onnx.json
  '';
  piper-morag-voice = patchVoice "morag"
    "en/en_US/morag/medium/en_US-morag-medium.onnx"
    piper-morag-voice-unpacked;

  piper-voices = pkgs.symlinkJoin {
    name = "piper-voices";
    paths = [ piper-amy-voice piper-joe-voice piper-cabal-voice piper-morag-voice ];
  };

  piper = pkgs.writeShellScriptBin "piper" ''
    MODEL="''${PIPER_MODEL:-${piper-voices}/en/en_US/amy/medium/en_US-amy-medium.onnx}"
    ${pkgs.piper-tts}/bin/piper -m "$MODEL" "$@"
  '';

  # Python environment with piper-tts for phoneme alignment extraction
  piperPython = pkgs.python3.withPackages (_ps: [
    pkgs.piper-tts
  ]);
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
      piperPython
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
      pkgs.sox
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
