#!/usr/bin/env bash
# AW-0 machine bootstrap and resume helper. Run with bash, not source.
set -euo pipefail
BASE="${AW0_HOME:-/root/aw0}"
REPO="$BASE/agentic-wam"
URL="${AW0_REPO_URL:-https://github.com/Prer1n1/Agentic_World_Action_Models_aw0.git}"
export UV_CACHE_DIR="$BASE/uv-cache"
export TMPDIR="$BASE/tmp"
export XDG_RUNTIME_DIR="$BASE/runtime"
export PATH="$BASE/bin:$PATH"
mkdir -p "$TMPDIR" "$XDG_RUNTIME_DIR" "$BASE/bin"
chmod 700 "$XDG_RUNTIME_DIR"
trap 'echo "Stopped at line $LINENO. Fix the reported error, then rerun the same command." >&2' ERR

help() {
cat <<'EOF'
Usage: bash aw0_setup.sh COMMAND
  restore    Install host tools, clone if absent, restore both Python environments
  toolkit    Install CUDA 12.1 toolkit only (large download; optional build stage)
  verify     Check Python environments, GPU computation and dependency consistency
  shell      Open a simulator shell with CUDA/Vulkan settings
  model-shell Open an AW-0 model shell (without simulator CUDA settings)
  status     Show repository, environments, disk and remaining milestones

Override AW0_HOME and AW0_REPO_URL if needed. Default root: /root/aw0.
No tokens are stored. Git authentication is handled by Git.
Existing repositories are not reset, pulled, or overwritten.
This restores the setup completed so far, NOT unfinished RoboTwin builds/assets,
model checkpoints, training, evaluation, or experiment outputs.
Keep valuable checkpoints/data on separately verified persistent storage.
EOF
}

need_uv() {
  if ! command -v uv >/dev/null; then
    curl -fsSL https://astral.sh/uv/install.sh -o "$TMPDIR/uv-install.sh"
    UV_INSTALL_DIR="$BASE/bin" sh "$TMPDIR/uv-install.sh"
  fi
}

restore() {
  [[ "$(id -u)" == 0 ]] || { echo 'restore requires root for apt packages'; exit 1; }
  apt-get update
  apt-get install -y git curl ca-certificates build-essential gcc-12 g++-12 \
    ninja-build unzip ffmpeg libvulkan1 vulkan-tools libgl1 libegl1 libglib2.0-0
  need_uv
  if [[ ! -e "$REPO" ]]; then
    git clone "$URL" "$REPO"
  fi
  git -C "$REPO" rev-parse --show-toplevel
  echo 'Restoring from this checkout (no automatic pull):'
  git -C "$REPO" rev-parse HEAD
  uv python install 3.10.22
  for name in agenticwam-venv codegen-sim-venv; do
    if [[ ! -e "$BASE/$name" ]]; then
      uv venv --python 3.10.22 --seed "$BASE/$name"
    fi
    "$BASE/$name/bin/python" -c 'import sys; assert sys.version_info[:2] == (3,10)'
  done
  uv pip install --python "$BASE/agenticwam-venv/bin/python" \
    torch==2.7.1+cu128 torchvision==0.22.1+cu128 \
    --index-url https://download.pytorch.org/whl/cu128
  uv pip install --python "$BASE/agenticwam-venv/bin/python" -e "$REPO"
  uv pip install --python "$BASE/codegen-sim-venv/bin/python" \
    torch==2.4.1 torchvision==0.19.1 \
    --index-url https://download.pytorch.org/whl/cu121
  uv pip install --python "$BASE/codegen-sim-venv/bin/python" \
    -r "$REPO/codegen/sim/requirements.txt"
  verify
  echo 'Python restore complete. Use toolkit if simulator build tools are missing.'
}

toolkit() {
  if [[ ! -x "$BASE/cuda-12.1/bin/nvcc" ]]; then
    echo 'Installing toolkit only; downloading about 4.1 GB plus extraction/install space.'
    echo 'CUDA 12.1 on Ubuntu 24.04 still requires actual build validation.'
    local free_kb
    free_kb=$(df -Pk "$BASE" | awk 'END {print $4}')
    [[ "$free_kb" -gt 15728640 ]] || {
      echo 'Need more than 15 GiB free for installer/extraction headroom. Free space first.'; exit 1;
    }
    mkdir -p "$BASE/installers" "$BASE/compiler-bin"
    test -x /usr/bin/gcc-12
    test -x /usr/bin/g++-12
    ln -sf /usr/bin/gcc-12 "$BASE/compiler-bin/gcc"
    ln -sf /usr/bin/g++-12 "$BASE/compiler-bin/g++"
    curl -fL --retry 3 \
      https://developer.download.nvidia.com/compute/cuda/12.1.1/local_installers/cuda_12.1.1_530.30.02_linux.run \
      -o "$BASE/installers/cuda-12.1.1.run"
    PATH="$BASE/compiler-bin:$PATH" sh "$BASE/installers/cuda-12.1.1.run" \
      --silent --toolkit --toolkitpath="$BASE/cuda-12.1"
    "$BASE/cuda-12.1/bin/nvcc" --version
    rm "$BASE/installers/cuda-12.1.1.run"
  else
    "$BASE/cuda-12.1/bin/nvcc" --version
  fi
}

verify() {
  need_uv
  for name in agenticwam-venv codegen-sim-venv; do
    uv pip check --python "$BASE/$name/bin/python"
    "$BASE/$name/bin/python" - "$name" <<'PY'
import sys, torch
expected = '2.7.1+cu128' if sys.argv[1] == 'agenticwam-venv' else '2.4.1+cu121'
assert torch.__version__ == expected, (torch.__version__, expected)
assert torch.cuda.is_available(), 'No CUDA GPU available'
x = torch.ones((256,256), device='cuda', dtype=torch.bfloat16)
assert (x @ x)[0,0].item() == 256
print(sys.argv[1], torch.__version__, torch.cuda.get_device_name(0), 'GPU calculation OK')
PY
  done
  "$BASE/agenticwam-venv/bin/python" -c 'import agenticwam, transformers; print(agenticwam.__file__, transformers.__version__)'
  "$BASE/codegen-sim-venv/bin/python" -c 'import sapien, mplib; print("Simulator imports OK; rendering still needs a separate smoke test")'
}

session() {
  local name="$1"
  local entry clean_path=""
  local -a path_entries
  IFS=: read -r -a path_entries <<< "$PATH"
  for entry in "${path_entries[@]}"; do
    [[ "$entry" == "${VIRTUAL_ENV:-/nonexistent}/bin" ]] && continue
    [[ "$entry" == "$BASE/cuda-12.1/bin" ]] && continue
    clean_path="${clean_path:+$clean_path:}$entry"
  done
  export PATH="$clean_path"
  unset VIRTUAL_ENV CUDA_HOME CUDAHOSTCXX
  if [[ -f /etc/vulkan/icd.d/nvidia_icd.json ]]; then
    export VK_ICD_FILENAMES=/etc/vulkan/icd.d/nvidia_icd.json
  fi
  if [[ "$name" == codegen-sim-venv ]]; then
    export CC=/usr/bin/gcc-12 CXX=/usr/bin/g++-12 CUDAHOSTCXX=/usr/bin/g++-12
    if [[ -x "$BASE/cuda-12.1/bin/nvcc" ]]; then
      export CUDA_HOME="$BASE/cuda-12.1"
      export PATH="$CUDA_HOME/bin:$PATH"
    fi
  fi
  # Strip the previous virtualenv from PATH when switching environments.
  source "$BASE/$name/bin/activate"
  cd "$REPO"
  echo "Opening $name. Type exit to return."
  bash --noprofile --norc -i
}

status() {
  df -h "$BASE"
  if [[ -d "$REPO/.git" ]]; then git -C "$REPO" status --short --branch; fi
  for path in agenticwam-venv/bin/python codegen-sim-venv/bin/python cuda-12.1/bin/nvcc; do
    if [[ -x "$BASE/$path" ]]; then echo "Present: $BASE/$path"; else echo "Missing: $BASE/$path"; fi
  done
  echo 'Unfinished: CUDA extension builds, RoboTwin assets/config, robot movement, AW-0 weights/inference.'
  echo 'Git preserves committed files only; it does not preserve installed environments or untracked data.'
}

case "${1:-help}" in
  restore) restore ;;
  toolkit) toolkit ;;
  verify) verify ;;
  shell) session codegen-sim-venv ;;
  model-shell) session agenticwam-venv ;;
  status) status ;;
  help|--help|-h) help ;;
  *) help; exit 2 ;;
esac
