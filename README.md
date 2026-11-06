# gpumon

GPU usage history for this machine, viewable in any terminal (works over SSH).
`gpumon` is on everyone's `PATH`; nothing to set up.

| Command | What it does |
|---|---|
| `gpumon` | Overview: current use, 1h / 24h / 7d averages per GPU, who claimed each GPU, who used it in the last hour and who is on it right now, and heatmaps for the last hour, day and week |
| `gpumon watch` | The same overview, redrawn once a minute (Ctrl-C to quit) |
| `gpumon take 0,1,2` | Mark GPUs 0-2 as claimed by you for 2 hours (`0-3` ranges work too) |
| `gpumon take 0,1,2 --for 8` | Same, for 8 hours (at most 24); taking GPUs you already hold resets the time |
| `gpumon release 0,1,2` | Drop your claim right away |

Claims are a courtesy notice: claimed GPUs are highlighted in the overview with the
owner's name and the time left, but nothing stops anyone from using them. You can't
take a GPU someone else has claimed until their claim ends, and only you (or root) can
release your claim. Claims end on their own when their time runs out.

Heatmap cells are brighter for more use; `·` means no data (collector not running then).
0 (dark navy) means the GPU was unused: no process on it, under 5% utilization and
under 1 GiB of memory. Anything else is drawn as at least 1%, which already shows as a distinct
brown, so a GPU that someone holds stands out even when it is doing almost nothing.
Colors turn off automatically when output is not a terminal or with `NO_COLOR=1`
(then shades ` ░▒▓█` are used). Set `COLORTERM=truecolor` for smoother color steps.

## How it works

* **Collector** (`gpumon collect`, run by `gpumon.service` as root): one Python process,
  standard library only. It reads utilization, memory, power and temperature for every GPU
  through NVML every 5 s, keeps the samples in memory, and writes one averaged row per GPU
  per minute to SQLite. Once a minute it also runs `nvidia-smi --query-compute-apps` to
  record which user owns each GPU process; processes inside Docker are attributed to their
  container name (`ctr:<name>`). It also deletes expired claims. It runs at low priority
  (nice 10), uses about 35 MB of RAM and a fraction of a percent of one CPU core.
* **Storage** (`/var/lib/gpumon`): minute rows are kept for 8 days and hourly roll-ups for
  400 days. The database levels off at about 5 MB for 8 GPUs and grows by under 1 MB a year.
* **Viewing**: read-only. Any user can read the database. It uses a rollback journal rather
  than WAL, so readers need no write access. "users (current)" comes from a live
  `nvidia-smi` query when you run `gpumon`; container names come from the collector, so
  users without Docker access still see them.
* **Claims**: one file per claim in `/var/lib/gpumon/claims` (world-writable with the
  sticky bit, like `/tmp`). The claim's owner is the file's owner, so it can't be faked.

## Install / upgrade / remove (maintainer, as root)

```
sudo ./install.sh              # installs /usr/local/bin/gpumon, starts gpumon.service
sudo ./install.sh --uninstall  # stops the service and removes the program; data is kept
```

Running `install.sh` again upgrades in place and restarts the collector; existing data is kept.

Status and logs: `systemctl status gpumon`, `/var/lib/gpumon/collector.log`.
`GPUMON_DATA=/some/dir gpumon` points the viewer at another data directory (for testing).
