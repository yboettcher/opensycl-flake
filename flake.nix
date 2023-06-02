{
  inputs = {
    opensycl_src = {
      url = "github:OpenSYCL/OpenSYCL/develop";
      flake = false;
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = inputs@{flake-parts, ...}: flake-parts.lib.mkFlake {inherit inputs;} {
    systems = ["x86_64-linux" "aarch64-linux"];
    perSystem = { config, self', inputs', pkgs, system, lib, ... }: let
      # a function to create sycl derivations easier
      # depending on whether rocm support is enabled or not, we choose a different mkDerivation, postFixup routine and add an extra buildInput
      makeSycl = {rocmSupport ? false}: let
        mkDerivation = if rocmSupport then pkgs.llvmPackages_rocm.rocmClangStdenv.mkDerivation else pkgs.clang15Stdenv.mkDerivation;
        postFixup = if rocmSupport then ''
          wrapProgram $out/bin/syclcc-clang \
            --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.python3 ]} \
            --add-flags "-L${pkgs.llvmPackages_15.openmp}/lib" \
            --add-flags "-I${pkgs.llvmPackages_15.openmp.dev}/include" \
            --add-flags "--rocm-device-lib-path=${pkgs.rocm-device-libs}/amdgcn/bitcode" \
            --add-flags "--opensycl-targets=hip"
        '' else ''
          wrapProgram $out/bin/syclcc-clang \
            --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.python3 ]} \
            --add-flags "-L${pkgs.llvmPackages_15.openmp}/lib" \
            --add-flags "-I${pkgs.llvmPackages_15.openmp.dev}/include"
        '';
        extraBuildInput = if rocmSupport then [ pkgs.rocm-runtime ] else [ pkgs.llvmPackages_15.libclang.dev ];
      in mkDerivation {
        name = "opensycl";
        version = "0.0.0";
        src = inputs.opensycl_src;
        nativeBuildInputs = [
          pkgs.cmake
          pkgs.boost
          pkgs.llvmPackages_15.openmp
          pkgs.llvm_15
        ] ++ lib.optionals rocmSupport [ pkgs.hip ];
        buildInputs = [
          pkgs.libxml2
          pkgs.libffi
          pkgs.makeWrapper
        ] ++ extraBuildInput;
        # opensycl makes use of clangs internal headers. It's cmake does not successfully discover them automatically on nixos, so we supply the path manually
        cmakeFlags = [
          "-DCLANG_INCLUDE_PATH=${pkgs.llvmPackages_15.libclang.dev}/include"
        ];
        inherit postFixup;
      };
    in {

      # manual derivations
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

      packages.syclRocmOnly = pkgs.llvmPackages_rocm.rocmClangStdenv.mkDerivation {
        name = "opensycl";
        version = "0.0.0";
        src = inputs.opensycl_src;
        nativeBuildInputs = [
          pkgs.cmake
          pkgs.boost
          pkgs.llvmPackages_15.openmp
          pkgs.llvmPackages_15.llvm
          pkgs.hip
        ];
        buildInputs = [
          pkgs.libxml2
          pkgs.libffi
          pkgs.makeWrapper
          pkgs.rocm-runtime
        ];
        cmakeFlags = [
          "-DCLANG_INCLUDE_PATH=${pkgs.llvmPackages_15.libclang.dev}/include"
        ];
        # since there is a cpu only version, I hardcoded this to always target hip
        postFixup = ''
          wrapProgram $out/bin/syclcc-clang \
            --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.python3 ]} \
            --add-flags "-L${pkgs.llvmPackages_15.openmp}/lib" \
            --add-flags "-I${pkgs.llvmPackages_15.openmp.dev}/include" \
            --add-flags "--rocm-device-lib-path=${pkgs.rocm-device-libs}/amdgcn/bitcode" \
            --add-flags "--opensycl-targets=hip"
        '';
      };

      packages.default = makeSycl { rocmSupport = false; };
    };
  };
}
