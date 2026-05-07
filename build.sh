#!/bin/bash

SECONDS=0
DATE=$(date '+%Y%m%d-%H%M')

DEVICE="${1:-chopin}"
DEFCONFIG="${DEVICE}_defconfig"
ZIPNAME="Exordium-${DEVICE}-${DATE}.zip"

echo -e "Building for: $DEVICE\n"

# Toolchain
TC_DIR="$HOME/toolchains/proton-clang-13"
CURRENT_DIR=$(pwd)
if [ ! -d "$TC_DIR" ]; then
  mkdir -p "$HOME/toolchains"
  cd "$HOME/toolchains"
  git clone --depth=1 https://gitlab.com/LeCmnGend/proton-clang.git -b clang-13 proton-clang-13
  cd "$CURRENT_DIR"
  # Remove bundled host linkers — incompatible with GCC 15 libgcc_s
  rm -f "$TC_DIR/bin/ld" "$TC_DIR/bin/ld.bfd" "$TC_DIR/bin/ld.gold"
fi
export PATH="$TC_DIR/bin:$PATH"

export USE_CCACHE=1
export LC_ALL=C
export HOSTCFLAGS="-fno-integrated-as"
ccache -M 100G

# Options
CLEAN_BUILD=false
for arg in "$@"; do
  case $arg in
    -c) CLEAN_BUILD=true ;;
  esac
done

[ "$CLEAN_BUILD" = true ] && rm -rf out

mkdir -p out

MAKE_FLAGS=(
  O=out
  ARCH=arm64
  CC="ccache clang"
  CLANG_TRIPLE=aarch64-linux-gnu-
  CROSS_COMPILE=aarch64-linux-gnu-
  CROSS_COMPILE_ARM32=arm-linux-gnueabi-
  LD=ld.lld
  AR=llvm-ar
  NM=llvm-nm
  AS=llvm-as
  STRIP=llvm-strip
  OBJCOPY=llvm-objcopy
  OBJDUMP=llvm-objdump
  CONFIG_NO_ERROR_ON_MISMATCH=y
  HOSTCC=clang
  HOSTCXX=clang++
)

make "${MAKE_FLAGS[@]}" $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) "${MAKE_FLAGS[@]}" Image.gz
if [ "$?" -eq 0 ]; then
  echo -e "\nKernel compiled successfully! Zipping up...\n"
  git clone -q --depth=1 https://github.com/froyoandroid/AnyKernel3 AnyKernel3
  cp out/arch/arm64/boot/Image.gz AnyKernel3
  rm -rf *zip out/arch/arm64/boot
  (cd AnyKernel3 && zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder)
  rm -rf AnyKernel3
  echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)!"
  echo "Zip: $ZIPNAME"
else
  echo -e "\nCompilation failed!"
fi
