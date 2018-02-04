#!/usr/bin/env bash

# Shell script used to build the torch/lib/* dependencies prior to
# linking the libraries and passing the headers to the Python extension
# compilation stage. This file is used from setup.py, but can also be
# called standalone to compile the libraries outside of the overall PyTorch
# build process.

set -e

# Options for building only a subset of the libraries
WITH_CUDA=0
WITH_ROCM=0
if [[ "$1" == "--with-cuda" ]]; then
  WITH_CUDA=1
  shift
elif [[ "$1" == "--with-rocm" ]]; then
  WITH_ROCM=1
  WITH_CUDA=0
  shift
fi

WITH_NNPACK=0
if [[ "$1" == "--with-nnpack" ]]; then
  WITH_NNPACK=1
  shift
fi

WITH_GLOO_IBVERBS=0
if [[ "$1" == "--with-gloo-ibverbs" ]]; then
  WITH_GLOO_IBVERBS=1
  shift
fi

cd "$(dirname "$0")/../.."
PWD=`printf "%q\n" "$(pwd)"`
BASE_DIR="$PWD"
cd torch/lib
INSTALL_DIR="$PWD/tmp_install"
CMAKE_VERSION=${CMAKE_VERSION:="cmake"}
C_FLAGS=" -DTH_INDEX_BASE=0 -I\"$INSTALL_DIR/include\" \
  -I\"$INSTALL_DIR/include/TH\" -I\"$INSTALL_DIR/include/THC\" \
  -I\"$INSTALL_DIR/include/THS\" -I\"$INSTALL_DIR/include/THCS\" \
  -I\"$INSTALL_DIR/include/THNN\" -I\"$INSTALL_DIR/include/THCUNN\""
# Workaround OpenMPI build failure
# ImportError: /build/pytorch-0.2.0/.pybuild/pythonX.Y_3.6/build/torch/_C.cpython-36m-x86_64-linux-gnu.so: undefined symbol: _ZN3MPI8Datatype4FreeEv
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=686926
C_FLAGS="${C_FLAGS} -DOMPI_SKIP_MPICXX=1"
LDFLAGS="-L\"$INSTALL_DIR/lib\" "
LD_POSTFIX=".so.1"
LD_POSTFIX_UNVERSIONED=".so"
# if [[ $(uname) == 'Darwin' ]]; then
#     LDFLAGS="$LDFLAGS -Wl,-rpath,@loader_path"
#     LD_POSTFIX=".1.dylib"
#     LD_POSTFIX_UNVERSIONED=".dylib"
# else
#     LDFLAGS="$LDFLAGS -Wl,-rpath,\$ORIGIN"
# fi
CPP_FLAGS=" -std=c++11 "
GLOO_FLAGS=""
THD_FLAGS=""
NCCL_ROOT_DIR=${NCCL_ROOT_DIR:-$INSTALL_DIR}
if [[ $WITH_CUDA -eq 1 ]]; then
    GLOO_FLAGS="-DUSE_CUDA=1 -DNCCL_ROOT_DIR=$NCCL_ROOT_DIR"
fi
# Gloo infiniband support
if [[ $WITH_GLOO_IBVERBS -eq 1 ]]; then
    GLOO_FLAGS+=" -DUSE_IBVERBS=1 -DBUILD_SHARED_LIBS=1"
    THD_FLAGS="-DWITH_GLOO_IBVERBS=1"
fi
CWRAP_FILES="\
$BASE_DIR/torch/lib/ATen/Declarations.cwrap;\
$BASE_DIR/torch/lib/THNN/generic/THNN.h;\
$BASE_DIR/torch/lib/THCUNN/generic/THCUNN.h;\
$BASE_DIR/torch/lib/ATen/nn.yaml"
CUDA_NVCC_FLAGS=$C_FLAGS
if [[ $CUDA_DEBUG -eq 1 ]]; then
  CUDA_NVCC_FLAGS="$CUDA_NVCC_FLAGS -g -G"
fi

# Used to build an individual library, e.g. build TH
function build() {
  # We create a build directory for the library, which will
  # contain the cmake output
  mkdir -p build/$1
  cd build/$1
  BUILD_C_FLAGS=''
  case $1 in
      THCS | THCUNN ) BUILD_C_FLAGS=$C_FLAGS;;
      nanopb ) BUILD_C_FLAGS=$C_FLAGS" -fPIC -fexceptions";;
      *) BUILD_C_FLAGS=$C_FLAGS" -fexceptions";;
  esac
  ${CMAKE_VERSION} ../../$1 -DCMAKE_MODULE_PATH="$BASE_DIR/cmake/FindCUDA" \
              ${CMAKE_GENERATOR} \
              -DTorch_FOUND="1" \
              -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
              -DCMAKE_C_FLAGS="$BUILD_C_FLAGS" \
              -DCMAKE_CXX_FLAGS="$BUILD_C_FLAGS $CPP_FLAGS" \
              -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
              -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS" \
              -DCMAKE_INSTALL_LIBDIR="$INSTALL_DIR/lib" \
              -DCUDA_NVCC_FLAGS="$CUDA_NVCC_FLAGS" \
              -DCMAKE_PREFIX_PATH="$INSTALL_DIR" \
              -Dcwrap_files="$CWRAP_FILES" \
              -DTH_INCLUDE_PATH="$INSTALL_DIR/include" \
              -DTH_LIB_PATH="$INSTALL_DIR/lib" \
              -DTH_LIBRARIES="$INSTALL_DIR/lib/libTH$LD_POSTFIX" \
              -DATEN_LIBRARIES="$INSTALL_DIR/lib/libATen$LD_POSTFIX" \
              -DTHNN_LIBRARIES="$INSTALL_DIR/lib/libTHNN$LD_POSTFIX" \
              -DTHCUNN_LIBRARIES="$INSTALL_DIR/lib/libTHCUNN$LD_POSTFIX" \
              -DTHS_LIBRARIES="$INSTALL_DIR/lib/libTHS$LD_POSTFIX" \
              -DTHC_LIBRARIES="$INSTALL_DIR/lib/libTHC$LD_POSTFIX" \
              -DTHCS_LIBRARIES="$INSTALL_DIR/lib/libTHCS$LD_POSTFIX" \
              -DTH_SO_VERSION=1 \
              -DTHC_SO_VERSION=1 \
              -DTHNN_SO_VERSION=1 \
              -DTHCUNN_SO_VERSION=1 \
              -DTHD_SO_VERSION=1 \
              -DNO_CUDA=$((1-$WITH_CUDA)) \
              -DNO_NNPACK=$((1-$WITH_NNPACK)) \
              -DNCCL_EXTERNAL=1 \
              -Dnanopb_BUILD_GENERATOR=0 \
              -DCMAKE_DEBUG_POSTFIX="" \
              -DCMAKE_BUILD_TYPE=$([ $DEBUG ] && echo Debug || echo Release) \
              ${@:2} \
              -DCMAKE_EXPORT_COMPILE_COMMANDS=1
  ${CMAKE_INSTALL} -j$(getconf _NPROCESSORS_ONLN)
  cd ../..

  local lib_prefix=$INSTALL_DIR/lib/lib$1
  if [ -f "$lib_prefix$LD_POSTFIX" ]; then
    rm -rf -- "$lib_prefix$LD_POSTFIX_UNVERSIONED"
  fi

  if [[ $(uname) == 'Darwin' ]]; then
    cd tmp_install/lib
    for lib in *.dylib; do
      echo "Updating install_name for $lib"
      install_name_tool -id @rpath/$lib $lib
    done
    cd ../..
  fi
}
function build_rocm_THC() {
  cd ../../aten/src/
  ROCM_INSTALL_DIR="$PWD/tmp_install"
  mkdir -p build/THC
  cd build/THC
  BUILD_C_FLAGS=''

  # case $1 in
  case THC in
      THCS | THCUNN ) BUILD_C_FLAGS=$C_FLAGS;;
      *) BUILD_C_FLAGS=$C_FLAGS" -fexceptions";;
  esac
  cmake ../../THC/hip -DCMAKE_MODULE_PATH="/opt/rocm/hip/cmake" \
               -DTorch_FOUND="1" \
               -DCMAKE_INSTALL_PREFIX="$ROCM_INSTALL_DIR" \
               -DCMAKE_C_FLAGS="$BUILD_C_FLAGS" \
               -DCMAKE_CXX_FLAGS="$BUILD_C_FLAGS $CPP_FLAGS" \
               -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
               -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS" \
               -DCUDA_NVCC_FLAGS="$C_FLAGS" \
               -DTH_INCLUDE_PATH="$INSTALL_DIR/include" \
               -DTH_LIB_PATH="$INSTALL_DIR/lib" \
               -DTH_LIBRARIES="$INSTALL_DIR/lib/libTH$LD_POSTFIX" \
               -DTHPP_LIBRARIES="$INSTALL_DIR/lib/libTHPP$LD_POSTFIX" \
               -DATEN_LIBRARIES="$INSTALL_DIR/lib/libATen$LD_POSTFIX" \
               -DTHNN_LIBRARIES="$INSTALL_DIR/lib/libTHNN$LD_POSTFIX" \
               -DTHCUNN_LIBRARIES="$INSTALL_DIR/lib/libTHCUNN$LD_POSTFIX" \
               -DTHS_LIBRARIES="$INSTALL_DIR/lib/libTHS$LD_POSTFIX" \
               -DTHC_LIBRARIES="$INSTALL_DIR/lib/libTHC$LD_POSTFIX" \
               -DTHCS_LIBRARIES="$INSTALL_DIR/lib/libTHCS$LD_POSTFIX" \
               -DTH_SO_VERSION=1 \
               -DTHC_SO_VERSION=1 \
               -DTHNN_SO_VERSION=1 \
               -DTHCUNN_SO_VERSION=1 \
               -DTHD_SO_VERSION=1 \
               -DNO_CUDA=0 \
               -DCMAKE_BUILD_TYPE=$([ $DEBUG ] && echo Debug || echo Release)
  make install -j$(getconf _NPROCESSORS_ONLN)
  cd ../..
  cd ../../torch/lib

  local lib_prefix=$INSTALL_DIR/lib/libTHC
  if [ -f "$lib_prefix$LD_POSTFIX" ]; then
    rm -rf -- "$lib_prefix$LD_POSTFIX_UNVERSIONED"
  fi
}
function build_rocm_THCUNN() {
  # We create a build directory for the library, which will
  # contain the cmake output
  cd ../../aten/src/
  mkdir -p build/THCUNN
  cd build/THCUNN
  BUILD_C_FLAGS=''
  case THCUNN in
      THCS | THCUNN ) BUILD_C_FLAGS=$C_FLAGS;;
      *) BUILD_C_FLAGS=$C_FLAGS" -fexceptions";;
  esac
  cmake ../../THCUNN/hip -DCMAKE_MODULE_PATH="/opt/rocm/hip/cmake" \
               -DTorch_FOUND="1" \
               -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
               -DCMAKE_C_FLAGS="$BUILD_C_FLAGS" \
               -DCMAKE_CXX_FLAGS="$BUILD_C_FLAGS $CPP_FLAGS" \
               -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
               -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS" \
               -DCUDA_NVCC_FLAGS="$C_FLAGS" \
               -DTH_INCLUDE_PATH="$INSTALL_DIR/include" \
               -DTH_LIB_PATH="$INSTALL_DIR/lib" \
               -DTH_LIBRARIES="$INSTALL_DIR/lib/libTH$LD_POSTFIX" \
               -DTHPP_LIBRARIES="$INSTALL_DIR/lib/libTHPP$LD_POSTFIX" \
               -DATEN_LIBRARIES="$INSTALL_DIR/lib/libATen$LD_POSTFIX" \
               -DTHNN_LIBRARIES="$INSTALL_DIR/lib/libTHNN$LD_POSTFIX" \
               -DTHCUNN_LIBRARIES="$INSTALL_DIR/lib/libTHCUNN$LD_POSTFIX" \
               -DTHS_LIBRARIES="$INSTALL_DIR/lib/libTHS$LD_POSTFIX" \
               -DTHC_LIBRARIES="$INSTALL_DIR/lib/libTHC$LD_POSTFIX" \
               -DTHCS_LIBRARIES="$INSTALL_DIR/lib/libTHCS$LD_POSTFIX" \
               -DTH_SO_VERSION=1 \
               -DTHC_SO_VERSION=1 \
               -DTHNN_SO_VERSION=1 \
               -DTHCUNN_SO_VERSION=1 \
               -DTHD_SO_VERSION=1 \
               -DNO_CUDA=0 \
               -DCMAKE_BUILD_TYPE=$([ $DEBUG ] && echo Debug || echo Release)
  make install -j$(getconf _NPROCESSORS_ONLN)
  cd ../..
  cd ../../torch/lib

  local lib_prefix=$INSTALL_DIR/lib/libTHC
  if [ -f "$lib_prefix$LD_POSTFIX" ]; then
    rm -rf -- "$lib_prefix$LD_POSTFIX_UNVERSIONED"
  fi
}
function build_rocm_THCS() {
  # We create a build directory for the library, which will
  # contain the cmake output
  cd ../../aten/src/
  mkdir -p build/THCS
  cd build/THCS
  BUILD_C_FLAGS=''
  # case $1 in
  case THCS in
      THCS | THCUNN ) BUILD_C_FLAGS=$C_FLAGS;;
      *) BUILD_C_FLAGS=$C_FLAGS" -fexceptions";;
  esac
  cmake ../../THCS/hip -DCMAKE_MODULE_PATH="/opt/rocm/hip/cmake" \
               -DTorch_FOUND="1" \
               -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
               -DCMAKE_C_FLAGS="$BUILD_C_FLAGS" \
               -DCMAKE_CXX_FLAGS="$BUILD_C_FLAGS $CPP_FLAGS" \
               -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
               -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS" \
               -DCUDA_NVCC_FLAGS="$C_FLAGS" \
               -DTH_INCLUDE_PATH="$INSTALL_DIR/include" \
               -DTH_LIB_PATH="$INSTALL_DIR/lib" \
               -DTH_LIBRARIES="$INSTALL_DIR/lib/libTH$LD_POSTFIX" \
               -DTHPP_LIBRARIES="$INSTALL_DIR/lib/libTHPP$LD_POSTFIX" \
               -DATEN_LIBRARIES="$INSTALL_DIR/lib/libATen$LD_POSTFIX" \
               -DTHNN_LIBRARIES="$INSTALL_DIR/lib/libTHNN$LD_POSTFIX" \
               -DTHCUNN_LIBRARIES="$INSTALL_DIR/lib/libTHCUNN$LD_POSTFIX" \
               -DTHS_LIBRARIES="$INSTALL_DIR/lib/libTHS$LD_POSTFIX" \
               -DTHC_LIBRARIES="$INSTALL_DIR/lib/libTHC$LD_POSTFIX" \
               -DTHCS_LIBRARIES="$INSTALL_DIR/lib/libTHCS$LD_POSTFIX" \
               -DTH_SO_VERSION=1 \
               -DTHC_SO_VERSION=1 \
               -DTHNN_SO_VERSION=1 \
               -DTHCUNN_SO_VERSION=1 \
               -DTHD_SO_VERSION=1 \
               -DNO_CUDA=0 \
               -DCMAKE_BUILD_TYPE=$([ $DEBUG ] && echo Debug || echo Release)
  make install -j$(getconf _NPROCESSORS_ONLN)
  cd ../..
  cd ../../torch/lib

  local lib_prefix=$INSTALL_DIR/lib/libTHC
  if [ -f "$lib_prefix$LD_POSTFIX" ]; then
    rm -rf -- "$lib_prefix$LD_POSTFIX_UNVERSIONED"
  fi

  if [[ $(uname) == 'Darwin' ]]; then
    cd tmp_install/lib
    for lib in *.dylib; do
      echo "Updating install_name for $lib"
      install_name_tool -id @rpath/$lib $lib
    done
    cd ../..
  fi
}
function build_rocm_ATen() {
  mkdir -p build/aten
  cd  build/aten
  BUILD_C_FLAGS=''
  case ATen in
      THCS | THCUNN ) BUILD_C_FLAGS=$C_FLAGS;;
      *) BUILD_C_FLAGS=$C_FLAGS" -fexceptions";;
  esac
  cmake ../../../../aten -DCMAKE_MODULE_PATH="/opt/rocm/hip/cmake" \
  ${CMAKE_GENERATOR} \
  -DCMAKE_BUILD_TYPE=$([ $DEBUG ] && echo Debug || echo Release) \
  -DNO_CUDA=$((1-$WITH_CUDA)) \
  -DNO_NNPACK=$((1-$WITH_NNPACK)) \
  -DCUDNN_INCLUDE_DIR=$CUDNN_INCLUDE_DIR \
  -DCUDNN_LIB_DIR=$CUDNN_LIB_DIR \
  -DCUDNN_LIBRARY=$CUDNN_LIBRARY \
  -DATEN_NO_CONTRIB=1 \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
  -DWITH_ROCM=1
  # purpusefully not passing C_FLAGS for the same reason as above
  make install -j$(getconf _NPROCESSORS_ONLN)
  cd ../..

  local lib_prefix=$INSTALL_DIR/lib/libATen$LD_POSTFIX
  if [ -f "$lib_prefix$LD_POSTFIX" ]; then
    rm -rf -- "$lib_prefix$LD_POSTFIX_UNVERSIONED"
  fi

  if [[ $(uname) == 'Darwin' ]]; then
    cd tmp_install/lib
    for lib in *.dylib; do
      echo "Updating install_name for $lib"
      install_name_tool -id @rpath/$lib $lib
    done
    cd ../..
  fi
}

function build_nccl() {
   mkdir -p build/nccl
   cd build/nccl
   ${CMAKE_VERSION} ../../nccl -DCMAKE_MODULE_PATH="$BASE_DIR/cmake/FindCUDA" \
               ${CMAKE_GENERATOR} \
               -DCMAKE_BUILD_TYPE=Release \
               -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
               -DCMAKE_C_FLAGS="$C_FLAGS" \
               -DCMAKE_CXX_FLAGS="$C_FLAGS $CPP_FLAGS"
  ${CMAKE_INSTALL}
   mkdir -p ${INSTALL_DIR}/lib
   cp "lib/libnccl.so.1" "${INSTALL_DIR}/lib/libnccl.so.1"
   if [ ! -f "${INSTALL_DIR}/lib/libnccl.so" ]; then
     ln -s "${INSTALL_DIR}/lib/libnccl.so.1" "${INSTALL_DIR}/lib/libnccl.so"
   fi
   cd ../..
}

# purpusefully not using build() because we need ATen to build the same
# regardless of whether it is inside pytorch or not, so it
# cannot take any special flags
# special flags need to be part of the ATen build itself
#
# However, we do explicitly pass library paths when setup.py has already
# detected them (to ensure that we have a consistent view between the
# PyTorch and ATen builds.)
function build_aten() {
  mkdir -p build/aten
  cd  build/aten
  ${CMAKE_VERSION} ../../../../aten \
  ${CMAKE_GENERATOR} \
  -DCMAKE_BUILD_TYPE=$([ $DEBUG ] && echo Debug || echo Release) \
  -DNO_CUDA=$((1-$WITH_CUDA)) \
  -DNO_NNPACK=$((1-$WITH_NNPACK)) \
  -DCUDNN_INCLUDE_DIR=$CUDNN_INCLUDE_DIR \
  -DCUDNN_LIB_DIR=$CUDNN_LIB_DIR \
  -DCUDNN_LIBRARY=$CUDNN_LIBRARY \
  -DATEN_NO_CONTRIB=1 \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=1
  # purpusefully not passing C_FLAGS for the same reason as above
  ${CMAKE_INSTALL} -j$(getconf _NPROCESSORS_ONLN)
  cd ../..
}

# In the torch/lib directory, create an installation directory
mkdir -p tmp_install

# Build
if [[ $WITH_ROCM -eq 1 ]]; then
    mkdir -p HIP
    cd HIP
    if [ ! -L "THC" ]; then
        ln -s ../THC/hip THC
    fi
    if [ ! -L "THCUNN" ]; then
        ln -s ../THCUNN/hip THCUNN
    fi
    if [ ! -L "THD" ]; then
        ln -s ../THD THD
    fi
    if [ ! -L "THPP" ]; then
        ln -s ../THPP THPP
    fi
    if [ ! -L "THS" ]; then
        ln -s ../THS THS
    fi
    if [ ! -L "ATen" ]; then
        ln -s ../ATen ATen
    fi
    cd ..
fi
for arg in "$@"; do
    if [[ $WITH_ROCM -eq 1 ]]; then
        if [[ "$arg" == "THC" ]]; then
            build_rocm_THC
        elif [[ "$arg" == "THCUNN" ]]; then
            build_rocm_THCUNN
        elif [[ "$arg" == "THCS" ]]; then
            build_rocm_THCS
        elif [[ "$arg" == "ATen" ]]; then
            build_rocm_ATen
        elif [[ "$arg" == "nccl" ]]; then
            build_nccl
        elif [[ "$arg" == "gloo" ]]; then
            build gloo $GLOO_FLAGS
        else
            build $arg
        fi
    else
        if [[ "$arg" == "nccl" ]]; then
            build_nccl
        elif [[ "$arg" == "gloo" ]]; then
            build gloo $GLOO_FLAGS
        elif [[ "$arg" == "ATen" ]]; then
            build_aten
        elif [[ "$arg" == "THD" ]]; then
            build THD $THD_FLAGS
        else
            build $arg
        fi
    fi
done
# If all the builds succeed we copy the libraries, headers,
# binaries to torch/lib
rm -rf "$INSTALL_DIR/lib/cmake"
rm -rf "$INSTALL_DIR/lib/python"
cp "$INSTALL_DIR/lib"/* .
if [ -d "$INSTALL_DIR/lib64/" ]; then
    cp "$INSTALL_DIR/lib64"/* .
fi
cp ../../aten/src/THNN/generic/THNN.h .
cp ../../aten/src/THCUNN/generic/THCUNN.h .
cp -r "$INSTALL_DIR/include" .
if [ -d "$INSTALL_DIR/bin/" ]; then
    cp "$INSTALL_DIR/bin/"/* .
fi

# this is for binary builds
if [[ $PYTORCH_BINARY_BUILD && $PYTORCH_SO_DEPS ]]
then
    echo "Copying over dependency libraries $PYTORCH_SO_DEPS"
    # copy over dependency libraries into the current dir
    cp "$PYTORCH_SO_DEPS" .
fi
