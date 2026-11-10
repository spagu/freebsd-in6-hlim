# Changelog

## 2026-11-10
- Added `in6-selecthlim-detach.patch` for PR 279653. It applies cleanly to 15.1-p6 `/usr/src` and compiles with the kernel's own flags (`-Werror`).
- Added `build-kernel.sh`: applies the patch, restores stock `atkbdc_isa.c`, creates a boot environment, then runs buildkernel and installkernel.
