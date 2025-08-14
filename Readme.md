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

## 📸 Screenshots

These images show the key steps of the compilation process and the final result.

### Main Menu
The initial screen showing all available options.
<img width="810" height="453" alt="Main Menu" src="https://github.com/user-attachments/assets/5b9e3140-7cad-4ac4-b9bf-42b9c1b533ea" />
<img width="804" height="459" alt="Main Menu 2" src="https://github.com/user-attachments/assets/b02f6b14-2e2c-457a-a7ca-73530731e6af" />

### Kernel Configuration
The kernel configuration menu, where you can customize options.
<img width="810" height="453" alt="Kernel Configuration" src="https://github.com/user-attachments/assets/4caf29fc-22ac-4912-ae7a-c598cb305042" />
<img width="804" height="459" alt="Kernel Configuration 2" src="https://github.com/user-attachments/assets/bd4d0177-ddf3-4c1a-9da7-f81d85412d71" />
<img width="804" height="459" alt="Kernel Configuration 3" src="https://github.com/user-attachments/assets/80ea9c55-2805-479d-92ec-45f61106fee1" />
<img width="804" height="459" alt="Kernel Configuration 4" src="https://github.com/user-attachments/assets/200e51ae-1660-4ba5-92cf-d75f6ee91ab7" />
<img width="804" height="459" alt="Kernel Configuration 5" src="https://github.com/user-attachments/assets/6f5c1824-71df-4ce2-b416-e40baf28201f" />

### BusyBox Compilation
The BusyBox compilation output, which creates a minimal filesystem.
<img width="804" height="459" alt="BusyBox" src="https://github.com/user-attachments/assets/5065e67a-873d-42f9-97c1-af69448f8f2c" />

### Booting with QEMU
The system booted with the QEMU emulator.
<img width="719" height="514" alt="Qemu" src="https://github.com/user-attachments/assets/aa33fbfd-a98b-464d-a26d-b275b8135770" />

### Bootable ISO
The GRUB bootloader of the final ISO image.
<img width="810" height="453" alt="Grub" src="https://github.com/user-attachments/assets/9e2abbe7-ce28-4bc8-a9e6-c93cf20429b1" />

### Statistics
<img width="810" height="453" alt="Statistics" src="https://github.com/user-attachments/assets/3292aecc-17b6-4af0-9a2e-9ebce94123da" />
