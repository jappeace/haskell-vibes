---
name: vastai-gpu
description: >
  Rent and manage Vast.ai GPU instances for ML training, inference, and ONNX export.
  Use when renting GPUs, running remote training jobs, transferring files to/from GPU instances,
  or managing Vast.ai instances. Covers CLI setup, SSH access, file transfer, and instance lifecycle.
user-invocable: false
---

# Vast.ai GPU Instance Management

## CLI Installation

The `vastai` CLI cannot be installed into the nix store. Use a Python venv:

```bash
python3 -m venv /tmp/vastai-venv
/tmp/vastai-venv/bin/pip install vastai
```

## Environment Variables

The vastai CLI crashes on import if it can't create `~/.cache` and `~/.config` directories.
Override these three env vars on every invocation:

```bash
XDG_CONFIG_HOME=/tmp/xdg_config XDG_CACHE_HOME=/tmp/xdg_cache HOME=/tmp/vastai_home /tmp/vastai-venv/bin/vastai <command>
```

Create the directories first:
```bash
mkdir -p /tmp/xdg_config /tmp/xdg_cache /tmp/vastai_home
```

## API Key

The API key lives at `/home/claude/vibes/.config/vastai/vast_api_key`. Copy it to the temp config:
```bash
mkdir -p /tmp/xdg_config/vastai
cp /home/claude/vibes/.config/vastai/vast_api_key /tmp/xdg_config/vastai/
```

Notify the user if it doesn't exist.
Make sure it exists before doing a plan!

## Searching for Instances

```bash
vastai search offers 'gpu_name=RTX_3090 num_gpus=1 reliability>0.95 inet_down>100 disk_space>=50' -o 'dph'
```

- GPU names use underscores: `RTX_3090`, `RTX_4090`, `A100_SXM4`
- `-o 'dph'` sorts by dollars per hour (cheapest first)
- For large model downloads, require `inet_down>500` to avoid stalled transfers
- `reliability>0.98` avoids flaky machines

## Creating an Instance

### Preferred: Nix Docker image (pure, reproducible)

```bash
vastai create instance OFFER_ID \
  --image ghcr.io/jappeace-sloth/scottish-tts-training:nix-cuda \
  --disk 100 --ssh
```

**Always prefer a Nix-built Docker image over pip.** Nix verifies ALL dependencies
at build time — if it builds, everything is present. Pip-based images have caused
multiple training failures from missing/conflicting deps (onnx, torchmetrics, numpy).

Build with: `nix-build docker.nix` (see `/home/claude/vibes/scottish-tts/docker.nix`)

### Fallback: PyTorch base image (pip-based)

```bash
vastai create instance OFFER_ID --image pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime --disk 100 --ssh
```

- Only use this if no Nix image is available
- Requires extensive pip install + patching at runtime (fragile)

### Notes

- The `--ssh` flag enables SSH access (Vast.ai's `.launch` script handles sshd)
- Instance takes 2-10 minutes to go from `loading` to `running`

## Polling Instance Status

```bash
vastai show instances          # human-readable table
vastai show instances --raw    # JSON output
```

Extract SSH connection details programmatically:
```bash
vastai show instances --raw | python3 -c "import json,sys; data=json.load(sys.stdin); print(data[0]['id'], data[0]['ssh_host'], data[0]['ssh_port'])"
```

Wait for `actual_status` to become `"running"` before connecting.

## SSH Key Setup

Register your SSH key with the Vast.ai account AND attach it to the instance:

```bash
vastai create ssh-key 'ssh-ed25519 AAAA... comment'
vastai attach ssh INSTANCE_ID 'ssh-ed25519 AAAA... comment'
```

Note: `attach ssh` is two words, not `attach-ssh`. The SSH key string is a positional argument, not a flag.

## SSH and SCP Access

SSH and SCP are not available in the base nix environment. Wrap every command with `nix-shell -p openssh`:

### SSH (lowercase -p for port):
```bash
nix-shell -p openssh --run "ssh -o StrictHostKeyChecking=no -p PORT root@sshN.vast.ai 'COMMAND'"
```

### SCP upload (uppercase -P for port):
```bash
nix-shell -p openssh --run "scp -o StrictHostKeyChecking=no -P PORT -r LOCAL_PATH root@sshN.vast.ai:/workspace/"
```

### SCP download:
```bash
nix-shell -p openssh --run "scp -o StrictHostKeyChecking=no -P PORT root@sshN.vast.ai:/workspace/REMOTE_FILE LOCAL_PATH"
```

### SSH helper script (for repeated use):
```bash
cat > /tmp/vssh.sh << SCRIPT
#!/bin/bash
nix-shell -p openssh --run "ssh -o StrictHostKeyChecking=no -p PORT root@sshN.vast.ai \"\$*\""
SCRIPT
chmod +x /tmp/vssh.sh
```

## Running Long Jobs

Use `nohup` with background execution for long-running tasks:

```bash
ssh ... 'nohup bash /workspace/train.sh > /workspace/train.log 2>&1 &'
```

Monitor progress:
```bash
ssh ... 'tail -50 /workspace/train.log'
```

## Shell Quoting

Running Python code over SSH through nix-shell creates multi-level quoting nightmares.
When commands get complex, write them to a local file, SCP to the instance, then execute:

```bash
# Write script locally
cat > /tmp/my_script.py << 'EOF'
import torch
# ... complex code ...
EOF

# Upload
nix-shell -p openssh --run "scp -o StrictHostKeyChecking=no -P PORT /tmp/my_script.py root@sshN.vast.ai:/workspace/"

# Execute
nix-shell -p openssh --run "ssh -o StrictHostKeyChecking=no -p PORT root@sshN.vast.ai 'cd /workspace && python3 my_script.py'"
```

## Destroying Instances

Always destroy instances when done to stop billing:

```bash
vastai destroy instance INSTANCE_ID
```

## Common Gotchas

1. **HuggingFace downloads stall**: Large model downloads (>1GB) can hang on low-bandwidth machines. If a download stalls, destroy the instance and rent one with `inet_down>500`.

2. **Pre-installed PyTorch conflicts**: The pytorch Docker images have system-level torch. If installing packages that need a different torch version (e.g., ChatterBox TTS), create a separate venv:
   ```bash
   python3 -m venv /workspace/my-venv --system-site-packages
   source /workspace/my-venv/bin/activate
   ```

3. **SSH intermittent failures (exit code 255)**: Vast.ai SSH proxies occasionally drop connections. Just retry. The Vast.ai banner says "If authentication fails, try again after a few seconds."

4. **Missing system packages**: The pytorch Docker image is minimal. You'll likely need:
   ```bash
   apt-get update && apt-get install -y espeak-ng libespeak-ng-dev build-essential
   ```
   With a Nix image, all system packages are baked in at build time — no apt-get needed.

5. **Working directory**: All files go under `/workspace/` which persists for the instance lifetime. With Nix images, use `/root/` instead (Nix containers don't have `/workspace/`).

6. **PyTorch 2.6+ PosixPath issue**: Loading old checkpoints fails with `Unsupported global: GLOBAL pathlib.PosixPath`. Fix by converting PosixPaths to strings:
   ```python
   import torch
   from pathlib import PosixPath
   torch.serialization.add_safe_globals([PosixPath])
   ckpt = torch.load("model.ckpt", map_location="cpu")
   ```

7. **ONNX export dynamo issues**: PyTorch 2.6+ defaults to `dynamo=True` for `torch.onnx.export`, which requires `onnxscript` and often fails on VITS models. Force legacy export:
   ```python
   torch.onnx.export(..., dynamo=False)
   ```

8. **Nix + pip don't mix**: Never pip install into a Nix Python environment. The Nix store is read-only and pip will error with "externally-managed-environment". If you absolutely must use pip alongside Nix Python, use `--target /some/writable/dir` and prepend that to PYTHONPATH. But prefer putting everything in Nix.

9. **Vast.ai container infrastructure expectations**: The Vast.ai `.launch` script expects these to exist in the container:
   - `/var/log`, `/var/run`, `/run`, `/tmp` — log and runtime directories
   - `/usr/sbin/sshd` — hardcoded sshd path (symlink to actual binary)
   - `/etc/ssh/ssh_host_*` — SSH host keys (generate at image build time)
   - `/etc/passwd` with `root` and `sshd` users (sshd needs privsep user)
   - `/etc/group` with matching groups
   - `/etc/bash.bashrc` — sourced by bash login
   - `/var/empty` — sshd privilege separation directory (chmod 755)
   Nix's `dockerTools.buildLayeredImage` doesn't provide any of these by default.
   Use `extraCommands` to create them. See `docker.nix` for a working example.

10. **Nix CUDA builds — restrict architectures**: Building torch with `cudaSupport = true` compiles magma from source. By default Nix builds for ALL GPU architectures (sm_75 through sm_120 = ~3492 CUDA kernel files, ~13 hours). **Always restrict to just the target GPU:**
    ```nix
    import <nixpkgs> {
      config = {
        allowUnfree = true;
        cudaSupport = true;
        cudaCapabilities = [ "8.9" ];  # sm_89 = RTX 4090 only
        cudaForwardCompat = false;     # no PTX for future archs
      };
    }
    ```
    Common mappings: RTX 3090 = `"8.6"`, RTX 4090 = `"8.9"`, A100 = `"8.0"`, H100 = `"9.0"`.
    Restricting to one arch cuts build time from ~13h to ~2h. Once built, derivations are cached in the local Nix store.

11. **Pushing Nix Docker images to GHCR**: Use skopeo (not docker) since Nix images are tar archives:
    ```bash
    nix-shell -p skopeo --run "skopeo copy docker-archive:./result docker://ghcr.io/YOUR_ORG/IMAGE:TAG"
    ```
    Authenticate with `GH_TOKEN` environment variable via skopeo login or auth config.

12. **Nix image layer count**: `buildLayeredImage` produces ~99-100 layers. Docker's max is 127 layers. Don't add too many separate packages to `contents` — group related tools or use `buildEnv` if approaching the limit.

13. **fakeNss vs custom passwd**: Nix's `dockerTools.fakeNss` provides a read-only `/etc/passwd` with only root and nobody. If you need additional users (like sshd), create passwd/group manually in `extraCommands` instead of using fakeNss.

## Typical Workflow

1. Install CLI, configure API key
2. Search offers, create instance
3. Poll `show instances` until status is `running`
4. Register SSH key with `create ssh-key` and `attach ssh`
5. Upload data/scripts via SCP
6. Run training via `nohup`, monitor with `tail`
7. Download results via SCP
8. Destroy instance immediately
