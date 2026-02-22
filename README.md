# cryptsetup-arm-static

A build script for a **statically linked version of `cryptsetup`**, capable of running on any ARMv7 Linux device. Currently uses **libgcrypt** as the crypto backend; additional backends will be supported in future releases.

---

## What is `cryptsetup`?

`cryptsetup` is a utility for managing **LUKS (Linux Unified Key Setup) encrypted volumes**. It allows you to:  

- Create, open, and close encrypted partitions or devices  
- Mount encrypted filesystems securely  
- Integrate encryption into scripts or boot-time workflows

### How it works

`cryptsetup` itself is **user-space software** — it does not perform encryption directly. Instead, it relies on:  

- **Kernel crypto API** (`dm-crypt`, AES, XTS, SHA modules, etc.) to perform actual encryption and decryption  
- **Device-mapper** to present decrypted volumes under `/dev/mapper/<name>`  
- Optional cryptographic libraries in user-space (like `libgcrypt` for key management or hashing)  

This separation allows `cryptsetup` to provide a **portable interface** for LUKS volumes while leveraging the **kernel’s highly optimized crypto routines**. On ARM devices, this also ensures that static binaries can work on minimal kernels that provide the necessary crypto modules.

---

## Features

- Fully static binary (no runtime dependencies)  
- Works on legacy ARMv7 Linux devices  
- Tested on: ASUS RT-AC68U with patched Linux 2.6.36.4  
- Target architecture: `arm-linux-musleabi` (soft-float)  
- Minimum kernel: Linux 2.6.36.4 with crypto support enabled  
- Required kernel modules: `dm-mod`, `dm-crypt`, `gf128mul`, `xts`, `sha256_generic`, `sha512_generic`, and any backend-specific modules

---

## Build Instructions

Clone the repository and run the build script:

```bash
git clone https://github.com/solartracker/cryptsetup-arm-static
cd cryptsetup-arm-static
./cryptsetup-arm-musl.sh
```

**Toolchain used:** GCC 15.2.0 + musl libc 1.2.5  

The resulting binary is **statically linked** and can be copied to any ARMv7 device.

---

## Example Usage

This shows how to open and mount a LUKS-encrypted partition manually:

```bash
# 1. Create a proper mount point
mkdir -p /mnt/mydata
chmod 700 /mnt/mydata  # optional: restrict access

# 2. Print the LUKS UUID (for reference)
uuid=$(./cryptsetup luksUUID /dev/sdb2)
if [ $? -ne 0 ]; then
    echo "Failed to read LUKS UUID"
    exit 1
fi
echo "LUKS UUID: $uuid"

# 3. Open the encrypted partition
./cryptsetup luksOpen /dev/sdb2 mydata
# Enter passphrase when prompted

# 4. Mount the decrypted device
mount /dev/mapper/mydata /mnt/mydata

# 5. When done, unmount and close
umount /mnt/mydata
./cryptsetup luksClose mydata
```

> **Note:** Ensure your kernel has crypto support enabled (`dm-crypt`, AES-XTS, SHA modules, etc.) and manually load any required modules on legacy ARM devices.

---

## License

This project is licensed under the GPLv3 License.





