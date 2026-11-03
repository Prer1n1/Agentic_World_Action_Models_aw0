# AW-0 reproduction environment

Official source revision:
275818e5787d59012eba4c43504342f1201ad25b

## Verified
- GPU: NVIDIA H100 80 GB HBM3
- NVIDIA driver: 595.91.07
- Python: 3.10.22
- AW-0 environment: PyTorch 2.7.1+cu128
- Simulator environment: PyTorch 2.4.1+cu121
- AW-0 GPU BF16 matrix multiplication passed.
- Both environments passed uv pip check.
- SAPIEN rendered a 128 x 128 RGBA image with finite values.

## Local configuration
- Code and environments are under /root/aw0.
- /workspace is a FUSE mount: ordinary writes passed, but Git chmod
  and uv package extraction failed there.
- Build/download cache: UV_CACHE_DIR=/root/aw0/uv-cache
- Temporary build directory: TMPDIR=/root/aw0/tmp
- Vulkan: VK_ICD_FILENAMES=/etc/vulkan/icd.d/nvidia_icd.json
- Runtime directory: XDG_RUNTIME_DIR=/root/aw0/runtime

## Pending
- Confirm allocated storage and asset locations.
- Install CUDA 12.1 build tools for simulator extensions.
- Build RoboTwin dependencies and download assets.
- Test robot loading and scripted movement.
- Download AW-0 weights and run evaluation.

Package snapshots describe this machine's installed packages.
They may contain local editable paths and need adaptation for restoration.
