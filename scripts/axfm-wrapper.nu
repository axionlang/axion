# axfm.axi — nushell wrapper (for nushell users; the POSIX shell version is axfm-wrapper.sh).
#
# Enable it by sourcing from your nu config — add this line to ~/.config/nushell/config.nu:
#     source /path/to/axfm/scripts/axfm-wrapper.nu
# (or just paste the `def --env axfm` below into config.nu).
#
# What it does: axfm writes its final directory to ~/.cache/axfm/axfm.d when you quit. A child process
# cannot change its parent shell's working directory, so this wrapper reads that file and cd's there
# after axfm exits — so you land in the directory you were browsing. `def --env` is REQUIRED: it makes
# the `cd` propagate to your shell (a plain `def` would change the dir only inside the function).
#
# The binary must be on PATH as `axfm` (build it with `axionc --release -o axfm examples/axfm.axi`),
# or set `$env.AXFM_BIN` to its full path.

def --env axfm [...args] {
    let bin = ($env.AXFM_BIN? | default "axfm")
    ^$bin ...$args
    let d = ($env.HOME | path join ".cache/axfm/axfm.d")
    if ($d | path exists) {
        let dir = (open --raw $d | str trim)
        if ($dir | path type) == "dir" { cd $dir }
    }
}
