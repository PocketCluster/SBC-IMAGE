# ARM64 kernel BUILD - Cross Compile - Ubuntu PC host

In order to speed up compilation, please execute compilation on bare-metal PC

### ODROID C2 

1. Update and Install dev packages

  ```sh
  apt update && apt install git lzop build-essential gcc libncurses5-dev libc6-i386 lib32stdc++6 zlib1g:i386
  ```
2. Install compiler toolchain

  * Download [gcc-linaro-aarch64-linux-gnu-4.9-2014.09_linux.tar.xz](http://releases.linaro.org/archive/14.09/components/toolchain/binaries/gcc-linaro-aarch64-linux-gnu-4.9-2014.09_linux.tar.xz)  

  ```sh
  mkdir -p /opt/toolchains
  tar Jxvf gcc-linaro-aarch64-linux-gnu-4.9-2014.09_linux.tar.xz -C /opt/toolchains/
  ```
3. Have a compile environment script

  `compile-env.bashrc`

  ```sh
  export ARCH=arm64
  export CROSS_COMPILE=aarch64-linux-gnu-
  export PATH=/opt/toolchains/gcc-linaro-aarch64-linux-gnu-4.9-2014.09_linux/bin/:$PATH
  ```

  ```sh
  source compile-env.bashrc
  ```
  
  ```sh
  $ aarch64-linux-gnu-gcc -v
  ...
  gcc version 4.9.2 20140904 (prerelease) (crosstool-NG linaro-1.13.1-4.9-2014.09 - Linaro GCC 4.9-2014.09)
  ```
4. Download kernel source or clone source tree 

  - **Should match with stock kernel so config option can be reused**
  - <https://github.com/hardkernel/linux/tree/odroidc2-3.14.y>

  ```sh
  git clone --depth 1 --single-branch -b odroidc2-3.14.y https://github.com/hardkernel/linux
  ```
5. Make default config and adjust options (take a look at [the table](wiki/How-To-compile-a-custom-Linux-kernel-for-your-ARM-device#build-your-custom-kernel) for default config)
   
  ```sh
  make odroidc2_defconfig
  ```
6. Make image, device driver tree, modules

  ```sh
  make -j4 Image dtbs modules
  ```
7. Copy `.dtb` and `Image` to boot partition

  ```sh
  cp arch/arm64/boot/Image arch/arm64/boot/dts/meson64_odroidc2.dtb ./boot && sync
  ```
8. Install modules

  ```sh
  make modules_install ARCH=arm64 INSTALL_MOD_PATH=<target_path> && sync
  ```
9. Install firmware (WIP : What variable for path? `INSTALL_FIRMWARE_PATH`?)

  ```sh
  make firmware_install
  ```  

> Reference

- <http://odroid.com/dokuwiki/doku.php?id=en:c2_building_kernel>

### PINE64 (WIP)

- Overall, it is similar to Odroid C2
- <https://github.com/longsleep/linux-pine64>
- Default config <https://github.com/longsleep/build-pine64-image/tree/master/u-boot-postprocess>
  
  ```sh
  make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- sun50iw1p1_config
  ```

> References

- [Kernel for A64 git](http://forum.pine64.org/showthread.php?tid=293)
  * [longsleep/build-pine64-image](https://github.com/longsleep/build-pine64-image)
- [U-Boot for A64 git](http://forum.pine64.org/showthread.php?tid=99)
  * [longsleep/u-boot-pine64](https://github.com/longsleep/u-boot-pine64)
