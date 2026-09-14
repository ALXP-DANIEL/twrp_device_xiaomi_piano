# Source patches — TWRP16 piano

Applied to the build checkout (`~/android/twrp-16`), not to this device tree.
The device tree carries them so the build is reproducible from the pinned
manifest plus these files.

## system_vold

### 0001-recovery-crypto-safety-invariants.patch

Phase 7S. Ports the safety invariants established during the TWRP14 bring-up
into this tree's `system/vold` at revision
`4c83041ec61f9b482085685f1e6aed5a62f103aa`.

This is a port of the *invariants*, not of the TWRP14 patch queue. Each was
re-checked against this revision first, and half of the original contract
turned out to be unnecessary because upstream TWRP-Test has already adopted it:

| Invariant | State at this revision | Action |
| --- | --- | --- |
| device key uses `neverGen()` | already present (`FsCrypt.cpp:557`) | none needed |
| user 0 DE/CE keys never created | already present, "refusing to create one" | none needed |
| Weaver record parsed correctly | **broken** | fixed |
| synthetic password authenticated | **broken** | fixed |
| metadata encrypt/format refused | **absent** | added |
| CE key material never deleted | **absent** | added |

#### Weaver record parsing

Upstream reads the slot with:

```c
const int* intptr = (const int*)weaver_data.data() + sizeof(unsigned char);
wd->slot = *intptr;
```

That is pointer arithmetic on `int*`, so it advances **four** bytes: it reads 4
bytes at offset 4 of a 5-byte record — one byte out of bounds — and interprets
them in native byte order. Android writes one version byte followed by a
big-endian `uint32` (`DataOutputStream.writeInt`, and `ByteBuffer` defaults to
big endian), so the value was wrong as well as overread.

Replaced with a length check, a version check, and an explicit big-endian
decode of bytes 1..4.

#### Synthetic password authentication

Upstream:

```c
EVP_DecryptUpdate(d_ctx, secret_key, &actual_size, intermediate_cipher_text, cipher_size);
unsigned char tag[AES_BLOCK_SIZE];
EVP_CIPHER_CTX_ctrl(d_ctx, EVP_CTRL_GCM_SET_TAG, 16, tag);
EVP_DecryptFinal_ex(d_ctx, secret_key + actual_size, &final_size);
```

The GCM tag is taken from an **uninitialised stack buffer**, `cipher_size`
includes the trailing 16-byte tag so the tag is decrypted as ciphertext, and
the `EVP_DecryptFinal_ex` result is discarded. The decryption is therefore
completely unauthenticated — any ciphertext "succeeds".

Replaced with: plaintext length `cipher_size - 16`, the real tag taken from the
trailing 16 bytes, every OpenSSL call's return checked, and the buffer
`OPENSSL_cleanse`d and the secret refused on authentication failure.

#### Metadata encryption: refuse to encrypt or format

`fscrypt_mount_metadata_encrypted()` now returns false immediately when
`needs_encrypt` or `should_format` is set, making `encrypt_inplace` and
`f2fs::Format` unreachable from recovery regardless of what any caller passes.

#### CE key material is never deleted

Both `fixate_user_ce_key()` call sites are removed — the direct one in
`fscrypt_set_ce_key_protection()` and the deferred pass in
`fscrypt_deferred_fixate_ce_keys()`. Fixation deletes every other on-disk
binding of the key; recovery only needs the key in memory, and a failed attempt
must leave the user's protectors exactly as they were.

## Not yet done

Negative tests have not been run, and crypto is still disabled in
`BoardConfig.mk`. These patches are staged, compiled only when crypto is
enabled, and unproven until then.
