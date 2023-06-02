# OpenSYCL Flake

This repository contains a flake to build the [OpenSYCL](https://github.com/OpenSYCL/OpenSYCL) compiler on NixOS. The flake provides 3 ways of building the compiler:

 - a CPU only derivation.
 - a Rocm only derivation. This is (currently) hardcoded to only compile to hip.
 - a function building either of the above based on the arguments. This is inspired by the Rocm variants of pytorch in the official nixpkgs.

OpenSYCL supports more backends (CUDA and oneAPI Level Zero), but I lack the hardware necessary for those.

These derivations do not run automatic tests since ctest coud not find any tests.

In my own experiments, the compiler produces working executables for the CPU as well as for my RX 480.

For a test, I adapted the example from [here](https://www.codingame.com/playgrounds/48226/introduction-to-sycl/hello-world).
The adapted version uses vectors for a, b and c with about 1 million entries and basically loops `c_acc[it] += a_acc[it] + b_acc[it];` one million times for each element.
On my CPU, this completes in about 1:30 min with the correct result.
On my RX 480 however, this crashes my wayland session (`[drm:amdgpu_job_timedout [amdgpu]] *ERROR* ring gfx timeout, but soft recovered`) if not run from a tty but still computes the correct result in about 43 s (if run from a tty).
