# freebsd-in6-hlim

![FreeBSD](https://img.shields.io/badge/FreeBSD-15.1-AB2B28?logo=freebsd)
![PR](https://img.shields.io/badge/PR-279653-blue)
![status](https://img.shields.io/badge/upstream-open-orange)

Local fix for FreeBSD 15.1 kernel panic **PR 279653** (`page fault` in
`in6_selecthlim()`, fault address `0x10`).

## Problem

`if_detach()` clears `if_afdata[AF_INET6]` before it waits for the net epoch
and frees the data. A TCP retransmit timer that runs in that window looks up
the nexthop, gets an interface that is being detached and dereferences
`ND_IFINFO(nh->nh_ifp)`, which is now NULL.

Seen on starlink (Dell XPS 13 9343, 2026-11-10 13:56 UTC): AX210 firmware
crashed (`Device error - SW reset`), `iwlwifi0: detached`, then a page fault
with backtrace `softclock -> tcp_timer_rexmt -> tcp_default_output ->
in6_selecthlim`.

## Fix

`in6_ifhlim()` reads the IPv6 data once and falls back to `V_ip6_defhlim`
when it is NULL. Both branches of `in6_selecthlim()` use it. A NULL check is
enough because the data is not freed while the caller is in the net epoch,
which is exactly what the `XXXZL` comment in `if_detach_internal()` relies on.

Upstream, `main` fixes the race by reworking how IPv6 data is attached to an
interface (D54728 and the revisions it depends on), which does not apply to
stable/15.

## Status

The patch applies cleanly to 15.1-p6 `/usr/src` and compiles with the kernel's own flags (`-Werror`). It has not run yet, so it is not proven to fix anything: the panic needs the Wi-Fi firmware to crash while a TCP retransmit timer is pending, which does not happen on demand.

Article: https://tradik.com/blog/freebsd-in6-selecthlim-iwlwifi-panic/

## Use

```sh
scp in6-selecthlim-detach.patch build-kernel.sh starlink:kernel-patches/
ssh starlink 'sudo sh ~/kernel-patches/build-kernel.sh' && ssh starlink 'sudo shutdown -r now'
```

The script also removes the experimental atkbdc resume hook from `/usr/src`
and rebuilds all modules, so `linux*.ko` (PR 298878) and `ig4.ko`
(PR 298558) come from the patched tree too. Rerun after every
`freebsd-update`.
