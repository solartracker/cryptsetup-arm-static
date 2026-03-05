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
## Cryptsetup ARM Static Build Backends

| Backend (`--with-crypto_backend=`) | `cryptsetup` Size (bytes) | Notes / Features                                                                 |
|----------------------------------|--------------------------|-------------------------------------------------------------------------------|
| **kernel**                        | 1,235,560                | Smallest; AES-XTS (disk encryption) handled by Linux kernel crypto API; hardware acceleration supported; PBKDF/HMAC limited if kernel lacks support; no fallback to userspace. |
| **nettle**                        | 1,276,544                | Slightly larger; userspace PBKDF, HMAC, and hash operations handled by Nettle; minimal footprint; disk encryption can use kernel if KERNEL_CAPI enabled. |
| **mbedtls**                        | 1,304,840                | Slightly larger than Nettle; userspace PBKDF/HMAC/hash via mbedTLS; disk encryption can use kernel; minimal footprint. |
| **gcrypt**                        | 2,386,584                | Much larger; full-featured Libgcrypt provides userspace PBKDF/HMAC/hash/ciphers; disk encryption can use kernel. |
| **openssl**                        | 3,458,284                | Largest; userspace OpenSSL handles PBKDF/HMAC/hash/ciphers; heavy static binary; disk encryption can use kernel. |

### Dependencies (build versions)

- cryptsetup: 2.8.4  
- libgcrypt: 1.12.0  
- OpenSSL: 3.6.0  
- mbedTLS: 3.6.5  
- Nettle: 3.10.2  
- Argon2: 20190702  
- libssh: 0.12.0  
- util-linux: 2.41.3

### Notes

- **Kernel backend**: Offloads AES-XTS / AES-CBC encryption to the Linux kernel; fastest, smallest, hardware acceleration supported.  
- **Userspace backends** (Nettle, mbedTLS, Libgcrypt, OpenSSL): handle PBKDF2, Argon2, HMAC, SHA, and other hashes.  
- For **minimal static ARM builds** that fully support LUKS1/LUKS2 with Argon2, **Nettle** is the most size-efficient compromise.

---

## License

This project is licensed under the GPLv3 License.





