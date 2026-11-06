# gpumon

GPU usage history for this machine, viewable in any terminal (works over SSH).

```
alias gpumon=/var/tmp/gpumon/gpumon     # add to your ~/.bashrc
```

| Command | What it shows |
|---|---|
| `gpumon` | Overview: current use, 1h / 24h / 7d averages per GPU, who is using each GPU, and heatmaps for the last hour, day and week |
| `gpumon --memory` | Same, but "utilization" means GPU memory used (%) instead of compute busy (`--compute`, the default) |
| `gpumon show -r 24h` | Heatmap and chart for one range (`1h`, `24h`, `7d`, `30d`, ...) |
| `gpumon show -r 7d -m mem` | Same for another metric: `util` (default), `mem`, `power`, `temp` |
| `gpumon show -g 0,2-3` | Only some GPUs (works on every view) |
| `gpumon users -r 7d` | GPU-hours per user or container |
| `gpumon free` | GPUs that are idle right now, with a ready-made `CUDA_VISIBLE_DEVICES` |
| `gpumon -w 30` | Redraw every 30 s (any view) |
| `gpumon export -r 24h > x.csv` | Raw per-minute rows as CSV |
| `gpumon status` | Collector health, history length, storage used |

Heatmap cells are brighter for more use; `·` means no data (collector not running then).
In utilization and memory heatmaps, 0 (dark navy) means the GPU was unused: no process on it, under 5% utilization and
under 1 GiB of memory. Anything else is drawn as at least 1%, which already shows as a distinct
brown, so a GPU that someone has claimed stands out even when it is doing almost nothing.
Colors turn off automatically when output is not a terminal, or with `NO_COLOR=1` / `--color never`
(then shades ` ░▒▓█` are used). Set `COLORTERM=truecolor` for smoother color steps.

## How it works

* **Collector** (`gpumon collect`): one Python process, standard library only. It reads
  utilization, memory, power and temperature for every GPU through NVML every 5 s, keeps
  the samples in memory, and writes one averaged row per GPU per minute to SQLite. Once a
  minute it also runs `nvidia-smi --query-compute-apps` to record which user owns each GPU
  process; processes inside Docker are attributed to their container name (`ctr:<name>`).
  It runs at low priority (nice 10), uses about 35 MB of RAM and a fraction of a percent of
  one CPU core.
* **Storage**: minute rows are kept for 8 days and hourly roll-ups for 400 days. The database
  levels off at about 5 MB for 8 GPUs and grows by under 1 MB a year after that.
* **Viewing**: read-only. Any user can read the database. It uses a rollback journal rather than WAL, so
  readers need no write access.
* **Keeping it running**: `install.sh` adds two lines to the installing user's crontab:
  `@reboot`, and a check every 10 minutes that restarts the collector if it stopped. A lock
  file ensures only one collector runs. No root is needed.

## Install / upgrade / remove (maintainer)

```
./install.sh              # installs to /var/tmp/gpumon, sets up cron, starts the collector
./install.sh --uninstall  # stops the collector and removes cron entries; data is kept
```

`GPUMON_PREFIX=/some/dir ./install.sh` installs somewhere else; `GPUMON_DATA` or `--data`
points the viewer at another data directory. Logs: `/var/tmp/gpumon/data/collector.log`.
