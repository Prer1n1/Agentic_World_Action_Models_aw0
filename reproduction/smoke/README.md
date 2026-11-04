# RoboTwin simulator smoke test

## Scope
A scripted simulator test, not an AW-0 policy rollout.
The program reads an observation and requests the left arm's home position.

## Verified configuration
- GPU: NVIDIA H100 80 GB HBM3
- Simulator Python: /root/aw0/codegen-sim-venv/bin/python
- Simulator PyTorch: 2.4.1+cu121
- CuRobo: 0.7.8, rebuilt using /usr/local/cuda-12.8
- Host compilers: GCC/G++ 12
- PyTorch3D source: 75ebeeaea0908c5527e7b1e305fbc7681382db47
- Task: stack_blocks_two
- Seed: 101
- Configuration: iterate/configs/priv_clean.yaml

## Observed result
- observation: dict
- home motion: True
- Sandbox failed: 0
- Reward: 0.0
- Task Completed: False
- A six-frame combined video was saved.

Zero reward is expected: the program does not attempt stacking.
This confirms the basic scripted execution path, not task performance.

## Setup issues resolved
- Used the simulator environment explicitly to resolve the tyro import.
- CuRobo built with CUDA 12.1 crashed during planner warmup.
- Rebuilding CuRobo with CUDA 12.8 resolved that crash for this test.
- Extracted background textures locally after mounted-storage extraction stalled.

## Remaining issue
Saving initial_prompt produced an ASCII encoding error.
The robot command and video recording still completed.
Use PYTHONUTF8=1 and PYTHONIOENCODING=utf-8 for subsequent Python runs.

## Storage
- Robot/object assets: /workspace/aw0-assets
- Extracted textures: /root/aw0/local-assets/background_texture
- Texture ZIP retained on the Global Volume.
- Environment archives: /workspace/aw0-backup

## Restoration limitation
The existing aw0_setup.sh does not yet automate this complete milestone.
Archive restoration has not been tested.

## Evidence boundary
This test verified simulator initialization, observation retrieval,
and acceptance of a home-position command without a runtime crash.
Visible arm movement was not verified. The arm may already have
been near its home position. This is not an AW-0 rollout or a
successful stacking demonstration.

## Measured gripper-motion test
Program: gripper_motion.py
Task: stack_blocks_two; seed: 101

Measured normalized left-gripper opening:
- After open: 0.992793
- After close: 0.002217
- After reopen: 0.949806

Sandbox failed: 0
Combined video: 67 frames
Reward: 0.0; task completed: false (stacking was not attempted).

Conclusion: scripted gripper movement is verified through measured
opening changes. Arm movement and AW-0 policy execution remain unverified.
