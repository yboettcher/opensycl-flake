{
  inputs = {
    opensycl_src = {
      url = "github:OpenSYCL/OpenSYCL/develop";
      flake = false;
    };
    llvm_15_src = {
      url = "github:llvm/llvm-project/release/15.x";
      flake = false;
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = inputs@{flake-parts, ...}: flake-parts.lib.mkFlake {inherit inputs;} {
    systems = ["x86_64-linux" "aarch64-linux"];
    perSystem = { config, self', inputs', pkgs, system, lib, ... }: {
      packages.syclCPUOnly = pkgs.clang15Stdenv.mkDerivation {
        name = "opensycl";
        version = "0.0.0";
        src = inputs.opensycl_src;
        nativeBuildInputs = [
          pkgs.cmake
          pkgs.boost
          pkgs.llvmPackages_15.openmp
          pkgs.llvm_15
        ];
        buildInputs = [
          pkgs.libxml2
          pkgs.libffi
          pkgs.makeWrapper
          # for internal clang headers. see comment below
          pkgs.llvmPackages_15.libclang.dev
        ];
        # opensycl makes use of clangs internal headers. It's cmake does not successfully discover them automatically on nixos, so we supply the path manually
        cmakeFlags = [
          "-DCLANG_INCLUDE_PATH=${pkgs.llvmPackages_15.libclang.dev}/include"
        ];
        # it appears that syclcc is in part a python script, so we add python to the path.
        # on building a sycl application for CPUs (openmp target?) it needs to find -lomp and omp.h, so we add these too
        postFixup = ''
          wrapProgram $out/bin/syclcc-clang \
            --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.python3 ]} \
            --add-flags "-L${pkgs.llvmPackages_15.openmp}/lib" \
            --add-flags "-I${pkgs.llvmPackages_15.openmp.dev}/include"
        '';
      };

      packages.syclRocm = pkgs.llvmPackages_rocm.rocmClangStdenv.mkDerivation {
        name = "opensycl";
        version = "0.0.0";
        src = inputs.opensycl_src;
        nativeBuildInputs = [
          pkgs.cmake
          pkgs.boost
          pkgs.llvmPackages_15.openmp
          pkgs.llvmPackages_15.llvm
          pkgs.hip
          # not necessary to build apparently
#           pkgs.hipcc
#           pkgs.rocm-cmake
#           pkgs.rocm-runtime
        ];
        buildInputs = [
          pkgs.libxml2
          # pkgs.llvmPackages_15.libclang.dev
          pkgs.libffi
          pkgs.makeWrapper
          pkgs.rocm-runtime
        ];
        cmakeFlags = [
          "-DCLANG_INCLUDE_PATH=${pkgs.llvmPackages_15.libclang.dev}/include"
        ];
        postFixup = ''
          wrapProgram $out/bin/syclcc-clang \
            --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.python3 ]} \
            --add-flags "-L${pkgs.llvmPackages_15.openmp}/lib" \
            --add-flags "-I${pkgs.llvmPackages_15.openmp.dev}/include" \
            --add-flags "--rocm-device-lib-path=${pkgs.rocm-device-libs}/amdgcn/bitcode" \
            --add-flags "--opensycl-targets=hip"
        '';
      };

      packages.default = self'.packages.syclCPUOnly;
    };
  };
}
