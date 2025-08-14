# Manzolo Linux Builder

An educational Bash script that guides you through the process of building a minimal Linux distribution from scratch, using the Linux kernel and BusyBox.

## 🌟 Features

* **Step-by-step guidance**: A fully interactive, menu-driven script that explains each step of the build process.
* **Kernel Compilation**: Automatically downloads, configures, and compiles the latest Linux kernel LTS version.
* **Minimal Filesystem**: Creates a minimal root filesystem with BusyBox, a single executable containing many core Unix utilities.
* **Initramfs Generation**: Builds an `initramfs` (initial RAM filesystem) required for booting.
* **Bootable ISO**: Creates a bootable ISO image using GRUB, ready to be burned to a CD/DVD or used in a VM.
* **QEMU Integration**: Easily test your newly created Linux system with a single menu option using QEMU.
* **Prerequisite Check**: Automatically detects and offers to install all necessary packages on Debian/Ubuntu-based systems.

## 🚀 Getting Started

### Prerequisites

This script is designed for **Debian/Ubuntu** based systems. It will automatically check for and offer to install the required packages:

* `build-essential`
* `flex`
* `libncurses5-dev`
* `bc`
* `libelf-dev`
* `bison`
* `libssl-dev`
* `grub-pc-bin`
* `xorriso`
* `mtools`
* `wget`
* `qemu-system-x86`

### Usage

1.  **Clone the repository** (or download the script):
    ```bash
    git clone [https://github.com/manzolo/linux-builder.git](https://github.com/your-username/linux-builder.git)
    cd linux-builder
    ```

2.  **Make the script executable**:
    ```bash
    chmod +x builder.sh
    ```

3.  **Run the script**:
    ```bash
    ./builder.sh
    ```

4.  Follow the on-screen menu to perform the build operations. It is recommended to follow the steps in order:
    1.  `Check prerequisites`
    2.  `Prepare Linux kernel`
    3.  `Prepare BusyBox (filesystem)`
    4.  `Test system with QEMU` or `Create bootable ISO image`

## 💡 How It Works

The script automates the manual process of building a Linux system:

* It first downloads the Linux kernel source code and compiles it to create the `bzImage` file.
* It then downloads and compiles BusyBox as a static binary, which bundles together common commands like `ls`, `cat`, and `sh`.
* A basic `init` script is created to mount virtual filesystems and provide a minimal shell.
* BusyBox and the `init` script are packaged together into an `initramfs.cpio.gz` file.
* Finally, the `bzImage` and `initramfs` are used with QEMU for testing or combined with a GRUB configuration to create a bootable ISO image.

## ⚙️ Customization

You can easily customize the project by changing the `KERNEL_VERSION` and `BUSYBOX_VERSION` variables at the beginning of the script.

## 📄 License

This project is licensed under the MIT License.

## 🙏 Credits

This script is inspired by and based on the guide from ThyCrow:
[Compiling the Linux Kernel and Creating a Bootable ISO from it](https://medium.com/@ThyCrow/compiling-the-linux-kernel-and-creating-a-bootable-iso-from-it-6afb8d23ba22)
