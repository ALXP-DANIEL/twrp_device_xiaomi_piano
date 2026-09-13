# Stage 8/9 implementation — 2026-09-12

Experimental work; FBE and credential unlock are **not working yet**. The gzip-only control failed to reach TWRP and the original LZ4 baseline was restored; no crypto candidate has been flashed. Preserve the boot-tested 27,906,048-byte baseline identified in the README.

## Metadata visibility

ADB confirmed TWRP `3.7.1_14-0`, active slot `_a`. `/metadata` and `/data` were initially unmounted. Metadata resolves to `/dev/block/sda20`.

The kernel source permits orphan cleanup even on a read-only F2FS mount. Inspection therefore temporarily set the metadata block device read-only and mounted it with `ro,norecovery`. Only directory entries and file sizes were inspected; no key contents were displayed or copied. The mount was removed and the original block-device read/write setting restored after inspection.

Existing `/metadata/vold/metadata_encryption/key` files:

| File | Bytes |
| --- | ---: |
| encrypted_key | 278 |
| keymaster_key_blob | 210 |
| secdiscardable | 16384 |
| version | 1 |

This proves visibility, not successful key use or data decryption. No replacement keys were generated.

## Crypto-only size candidate

The Ubuntu builder has the experimental addition `TW_INCLUDE_CRYPTO := true`. This is not yet promoted to the canonical BoardConfig. The known-good image was backed up as `~/piano-fbe-evidence/recovery-pre-fbe.img` before building.

Native crypto compilation completed, but packaging hit stale generated ODM directory/symlink collisions. Only generated `root`, `recovery`, and recovery packaging intermediates were cleared for retry, with `recovery/root/system/etc` recreated. A subsequent Soong attempt failed on a license-provider mutation assertion in an unrelated fingerprint Rust module; retry succeeded with `BUILD_EXIT:0`.

Crypto-only candidate: **32,665,600 bytes**, ramdisk 32,661,461 bytes, header v4, kernel size 0, legacy LZ4. SHA-256: `5d0d979b498e82b601ff772ff6483277551b267ddfa94dc879baf0a080b9601a`. It has not been flashed because its size lies in the previously failing range. No baseline ramdisk paths were removed.

ELF inspection found a missing `libresetprop.so` dependency of the crypto-enabled recovery executable. `patches/bootable_recovery/0001-package-linked-libresetprop.patch` adds that library to ramdisk packaging when the existing linkage flag is enabled. It does not add property overrides. Rebuild validation passed; the image contains the 204,712-byte library. The patched image is 32,735,232 bytes, SHA-256 `e0cc6a629cd5d9909436a3b23f00c9f3ad964fc39c4164412a07f9b7f3059907`, header v4 and kernel size 0. It has not been flashed.

The patched source compile initially failed because `OPENSSL_cleanse` lacked its header; `openssl/crypto.h` is now included. Separate builder failures included a malformed path in the cached module finder and a malformed Ninja variable during Soong generation. The generated file index was archived and regenerated; no unrelated product-source workaround was added. The retry with `GOMAXPROCS=4` completed successfully. This is a successful workaround observation, not proof of the underlying builder failure cause.

## Prepared generic source fixes

Candidate patches target `system/vold` commit `b865130d263a84d86440f6b8b9e1f08c6938d6a5` from the builder's `nebrassy/android_system_vold` Android 14 checkout. They are not automatically applied by the device tree. All three patches passed Android compilation into the recovery executable; no patched recovery image has been device tested.

- `0001-handle-absent-keystore-results.patch`: avoid dereferencing absent upgraded key blobs and optional finish output; bound keystore service discovery to approximately five seconds. This does not bound individual Binder RPC duration. Existing upgraded-blob output remains under `/tmp`; the patch does not commit upgrades to stock key files.
- `0002-validate-weaver-record-and-authenticate-spblob.patch`: parse the versioned Weaver slot as big-endian with length/version/range checks; validate synthetic-password payload lengths and keystore availability; verify the actual trailing AES-GCM tag before deriving a disk secret.

The exact parser and EVP authentication sequence passed host tests with AddressSanitizer/UndefinedBehaviorSanitizer: slot endian/bounds, AES-256-GCM known answer, modified ciphertext/tag, wrong key/IV, and truncation. Tests used synthetic public test-vector data only. Host OpenSSL tests do not establish Android/BoringSSL compilation or hardware compatibility. AIDL Weaver support is still required; these patches alone do not provide it.

- `0003-load-existing-de-keys-without-initializing-storage.patch`: TWRP's `Decrypt_DE()` selects an existing-only mode. It uses `neverGen()`, preserves the configured wrapped-key policy, skips reference/per-boot-key writes, requires existing user 0 DE and CE key directories, and skips directory/policy preparation. Other callers retain the default initialization behavior. Exact function bodies passed host tests with mocked storage/service dependencies and sanitizers. This is a DE initializer safeguard, not proof that all metadata, CE, fsck, or mount paths are safe; those still require audit.

- `0004-add-aidl-weaver-v2-client.patch`: adds an AIDL Weaver v2 client with HIDL fallback, recovery/libtar link dependencies, and FBE library packaging. The first public-header version caused a syslog/libchrome macro collision in `Decrypt.cpp`; moving AIDL includes into `Weaver1.cpp` and using a forward declaration fixed it without changing `Decrypt.cpp`. The next link exposed missing Weaver v2 dependencies in both Make consumers of libvold; these are included in the patch. After one transient Soong Blueprint SIGSEGV, the corrected revision passed full `m recovery -j4` compilation and linking (02:47, exit 0). This proves the recovery executable builds, not recovery-image generation or runtime decryption. No image from this revision has been flashed.

## Hardware-backed key-service gate

Read-only EROFS mounts of the active stock `vendor_a` and `odm_a` made the KeyMint, Weaver, and QSEE binaries available for dependency inspection without packaging them. Their direct ELF dependencies resolve in recovery when the stock `libc++.so` is supplied before recovery libraries; this avoids the earlier `libutils` symbol mismatch. That establishes only loader compatibility, not service operation.

The QSEE daemon still exits immediately in recovery. The first hypothesis was the absent `/dev/qseecom` node: recovery exposes `/dev/smcinvoke`, with `qseecom_proxy` and `smcinvoke_dlkm` loaded, while the proxy source only forwards kernel-client operations. However, a normal HyperOS boot has the same absent `/dev/qseecom` node while `qseecomd`, KeyMint, and Weaver run. The node is therefore not the demonstrated root cause.

The remaining gate is the startup environment: recovery can resolve the binaries only with an explicit stock C++ runtime overlay, whereas normal Android supplies the vendor linker namespace, service domain, file contexts, init environment, and supporting services. A temporary read-only bind of stock vendor paths into recovery did not make `qseecomd` stay alive. It was fully unmounted afterwards; recovery remained Enforcing. Do not add a fake node, disable SELinux, or claim that the secure-service path works. The next technical step is to reproduce the smallest required runtime namespace and init/service context, then observe the first concrete startup error.

## Compression control

The live stock `/proc/config.gz` confirms `CONFIG_RD_GZIP=y`, `CONFIG_RD_LZ4=y`, and `CONFIG_RD_ZSTD=y`; XZ/LZMA are disabled. Offline gzip compression of the crypto-only ramdisk measured 28,132,315 bytes, before header/padding and the missing-library correction. This is not boot proof or a final size guarantee.

A gzip-only control was made from the exact known-good image. Decompressed ramdisk bytes are unchanged, verified by round-trip comparison; boot header is unchanged except ramdisk size, with no boot signature payload in the original. Control size: **23,986,176 bytes**; SHA-256: `c7c5b8d750033ddc58d22a7ed7ec17c69987ebb3ad903c52247dcd97172bac8e`. Raw ramdisk SHA-256: `49daa2f77b4df4deedb1fcb51bbcf476c1cc299ae5a1980734bf0d57ca2fc7d1`.

The control was flashed to `recovery_a` only after bootloader fastboot confirmed `is-userspace: no`, `current-slot: a`, `slot-successful:a: yes`, and `slot-unbootable:a: no`. The control returned to HyperOS after `adb reboot recovery`; TWRP was not reached. Kernel gzip support alone did not establish compatibility with this recovery boot path. The original LZ4 image was restored to `recovery_a`, then HyperOS boot and `adb reboot recovery` returned to TWRP `3.7.1_14-0`, slot `_a`, SELinux Enforcing. The maintainer confirmed landscape display and touch work normally. No crypto behavior was present in the control. Keep LZ4 for further candidates.

## Next gates

### Follow-up after Weaver compilation

The empty-path follow-up did not reproduce: `build/soong` is clean at `e2019ec`, the jarjar generator already supplies the rules file as an explicit implicit dependency, and a minimal Ninja test accepted the edge-local variable pattern. Both bundled Linux Ninja binaries parsed the full graph. A strict dry run (`usesphonyoutputs=yes`, `dupbuild=err`, `missingdepfile=err`, target `recoveryimage`) also exited 0 and planned through image packaging. Its log is `~/piano-fbe-evidence/weaver-v2-ninja-dryrun.log`. A dry run executes no compilation/packaging and is not image proof. No CTS or Soong source workaround was added; compare execution environment and transient builder state next.

Builder follow-up: approximately 18 GiB memory was available and no matching kernel OOM/hardware error was found. A packaging attempt under `taskset -c 0,1` confirmed the live Soong process inherited that affinity; its process environment did not contain GOMAXPROCS. The run completed graph generation but Ninja rejected an empty path at generated line 962547, in the HealthFitness `CtsExerciseRouteTestRouteReaderWriterApp` jarjar rule (which references `${rulesFile}` among prerequisites). The exact failing build log is `~/piano-fbe-evidence/weaver-v2-packaging-affinity.log` on the builder. This run ended with exit 1; it is not still running. Neither low concurrency nor available memory proves the underlying corruption/source issue resolved. Investigate this generated rule against its Soong generator before another packaging attempt.

The subsequent `m recoveryimage -j4` attempt failed before packaging with a Go runtime bad-pointer/heap error during Soong generation. No `recovery.img` exists from this revision; successful executable compilation remains the last completed build gate. Repeated differing Soong memory failures require builder diagnosis rather than a device-source workaround.

Read-only checks still report TWRP 3.7.1_14-0, slot `_a`, and SELinux Enforcing. Recovery labels `/dev/smcinvoke` as `device` and the two QSEE DMA heaps as `dmabuf_heap_device`. Stock file contexts instead specify `tee_device`, `vendor_dmabuf_qseecom_heap_device`, and `vendor_dmabuf_qseecom_ta_heap_device`. No matching qseecom/smcinvoke/KeyMint/Weaver AVC denial was returned by the filtered current kernel log. These differences are investigation leads, not proven causes or permission to relabel nodes. Stock init also creates the `notify-topology` socket for qseecomd; it is absent in the baseline. No service was launched and no device state was changed during this check.

Resolve the secure-service startup-environment gate; measure a complete candidate after source integration; audit all key-access and filesystem write paths before runtime decryption; demonstrate existing metadata-key use, dm-default-key, F2FS and DE with CE locked; then implement/test the actual protector route and real GUI credential entry. Finish with a normal HyperOS boot and unlock. Never log credentials or key material, format data, wipe metadata, change slot, or modify protected partitions.
