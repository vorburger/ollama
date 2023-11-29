#!/bin/bash
# This script is intended to run inside the go generate
# working directory must be ../llm/llama.cpp

set -ex
set -o pipefail

echo "Starting linux generate script"
if [ -z "${CUDACXX}" -a -x /usr/local/cuda/bin/nvcc ] ; then
    export CUDACXX=/usr/local/cuda/bin/nvcc
fi
source $(dirname $0)/gen_common.sh
init_vars
git_module_setup
apply_patches
CMAKE_DEFS="-DLLAMA_CUBLAS=on -DCMAKE_POSITION_INDEPENDENT_CODE=on -DLLAMA_NATIVE=off -DLLAMA_AVX=on -DLLAMA_AVX2=off -DLLAMA_AVX512=off -DLLAMA_FMA=off -DLLAMA_F16C=off ${CMAKE_DEFS}"
BUILD_DIR="gguf/build/cuda"
LIB_DIR="${BUILD_DIR}/lib"
mkdir -p ../../dist/
build
# TODO - explore mechanism to soften the hard cuda dependency on linux
#        by conditionally building some archive here that aggregates the cuda libs if present
#        so that the cgo flags link this intermediate archive instead of the underlying cuda libs
# 
# gcc -fPIC -g -shared -o ${LIB_DIR}/libcuda_server.so \
#     -Wl,--whole-archive \
#     ${BUILD_DIR}/examples/server/CMakeFiles/ext_server.dir/server.cpp.o \
#     ${BUILD_DIR}/common/libcommon.a \
#     ${BUILD_DIR}/libllama.a \
#     ${BUILD_DIR}/examples/llava/libllava_static.a \
#     -Wl,--no-whole-archive \
#     -lrt -lpthread -ldl -lstdc++ -lm \
#     /usr/local/cuda/lib64/libcudart_static.a \
#     /usr/local/cuda/lib64/libcublas_static.a \
#     /usr/local/cuda/lib64/libcublasLt_static.a \
#     /usr/local/cuda/lib64/libcudadevrt.a \
#     /usr/local/cuda/lib64/libculibos.a

if [ -z "${ROCM_PATH}" ] ; then
    # Try the default location in case it exists
    ROCM_PATH=/opt/rocm
fi

BUILD_DIR="gguf/build/rocm"
LIB_DIR="${BUILD_DIR}/lib"
mkdir -p ${LIB_DIR}
# Ensure we have at least one file present for the embed
touch ${LIB_DIR}/.generated 

if [ -d "${ROCM_PATH}" ] ; then
    echo "Building ROCm"
    init_vars
    CMAKE_DEFS="-DCMAKE_POSITION_INDEPENDENT_CODE=on -DCMAKE_VERBOSE_MAKEFILE=on -DLLAMA_HIPBLAS=on -DCMAKE_C_COMPILER=$ROCM_PATH/llvm/bin/clang -DCMAKE_CXX_COMPILER=$ROCM_PATH/llvm/bin/clang++ -DAMDGPU_TARGETS='gfx803;gfx900;gfx906:xnack-;gfx908:xnack-;gfx90a:xnack+;gfx90a:xnack-;gfx1010;gfx1012;gfx1030;gfx1100;gfx1101;gfx1102' -DGPU_TARGETS='gfx803;gfx900;gfx906:xnack-;gfx908:xnack-;gfx90a:xnack+;gfx90a:xnack-;gfx1010;gfx1012;gfx1030;gfx1100;gfx1101;gfx1102'"
    CMAKE_DEFS="-DLLAMA_ACCELERATE=on -DLLAMA_NATIVE=off -DLLAMA_AVX=on -DLLAMA_AVX2=off -DLLAMA_AVX512=off -DLLAMA_FMA=off -DLLAMA_F16C=off ${CMAKE_DEFS}"
    build
    gcc -fPIC -g -shared -o ${LIB_DIR}/librocm_server.so \
        -Wl,--whole-archive \
        ${BUILD_DIR}/examples/server/libext_server.a \
        ${BUILD_DIR}/common/libcommon.a \
        ${BUILD_DIR}/libllama.a \
        -Wl,--no-whole-archive \
        -lrt -lpthread -ldl -lstdc++ -lm \
        -L/opt/rocm/lib -L/opt/amdgpu/lib/x86_64-linux-gnu/ \
        -Wl,-rpath,/opt/rocm/lib,-rpath,/opt/amdgpu/lib/x86_64-linux-gnu/ \
        -lhipblas -lrocblas -lamdhip64 -lrocsolver -lamd_comgr -lhsa-runtime64 -lrocsparse -ldrm -ldrm_amdgpu
fi
