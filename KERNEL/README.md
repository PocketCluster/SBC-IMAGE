# Kernel Compile  

We need to build custom kernel for each board to satisfy all the options Docker needs. Further, it will be necessary to build in secure boot that users should not be able to mount file system to open up what's inside.

In order to minimize the amount of work required, we'll build a process follows this.

1. Acquire the stock kernel from published, distributed boot image
2. Acquire kernel config

  ```sh
  # if /proc/config.gz is not available
  sudo modprobe configs
  zcat /proc/config.gz
  ```

3. [Check config](https://github.com/docker/docker/blob/master/contrib/check-config.sh) for docker
4. Combine the two compile options together. Make sure all required are built-in rather than become a module
5. Compile kernel


> References

- <>