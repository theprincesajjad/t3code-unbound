# T3 Code Unbound

[T3 Code](https://github.com/pingdotgg/t3code) with file attachments of any size.

Official builds refuse a file attachment over 50 MB. This build sends files as
large as the host's disk allows. It was tested end to end with a 3 GiB file.

This repository holds a small patch series and a workflow, not a copy of T3 Code.
The workflow watches upstream for stable releases, applies the patches to each
one, and publishes the runtime archives that `t3 update` installs. Once a machine
runs this build, `t3 update` follows the releases here, so updating keeps the change.

## Install

On a machine that already runs T3 Code:

```sh
git clone https://github.com/theprincesajjad/t3code-unbound.git
t3code-unbound/scripts/install.sh            # stage the newest release
t3 service restart                           # switch when nothing is running
```

`scripts/install.sh --restart` does both. Restarting the service interrupts
agent turns and terminals running in it.

On a machine without T3 Code, use upstream's installer with this repository as
the release source:

```sh
curl -fsSL https://t3.codes/install.sh | \
  T3CODE_RELEASE_BASE_URL=https://github.com/theprincesajjad/t3code-unbound/releases/download \
  T3CODE_VERSION=0.1.11 sh
```

Archives are built for macOS arm64, Linux x64 and Linux arm64.

## Update

```sh
t3 update          # newest release here; restart the service when prompted
```

A release appears here a few hours after upstream publishes one. If the patches
stop applying to a new upstream version, the workflow opens an issue instead of
publishing, and `t3 update` keeps offering the last good release.

## Go back to official builds

```sh
T3CODE_RELEASE_BASE_URL=https://github.com/pingdotgg/t3code/releases/download \
  t3 update <official version> --allow-downgrade
```

An official version at least as new as the one installed needs no database
change. Threads holding large files stay readable there: see below.

## What the patches change

`patches/0001` lifts the limit:

- **Upload limit.** The server advertises no file size limit, and the web client
  stops clamping it to 50 MB.
- **Resumable chunked upload.** A file over 50 MB goes up in 16 MB chunks on the
  existing signed upload URL (`?unbound-offset=<bytes>`). One request cannot carry
  gigabytes: Node drops a request after five minutes, and a dropped connection
  would restart from zero. The server reports how many bytes it holds, so a retry
  continues from there. Files up to 50 MB still use upstream's single request.
- **Compatible storage.** Official desktop and mobile apps reject a file
  attachment whose `sizeBytes` exceeds 50 MB, as would an official server reading
  the database after a rollback. So the stored and transmitted `sizeBytes` stays
  clamped and the true size travels in `actualSizeBytes`, a key those readers
  ignore. Official apps open threads with large files normally.
- **No second copy.** Sending a file used to copy it into the thread's folder.
  It is now a copy-on-write clone where the filesystem supports one (APFS, Btrfs,
  XFS), so a large file is stored once.

`patches/0002` points `t3 update` at this repository's releases.

## Limits

- Only clients carrying the patch can *send* a large file: the web UI this
  server serves (open the server's address in a browser, on any device). The
  official desktop and mobile apps keep their own 50 MB check until they are
  rebuilt with the patch. They can open and read threads that contain large files.
- A file must fit on the host's disk. There is no quota.
- Images keep upstream's 10 MB limit; the client already compresses larger ones.
- Agents receive the file's path, not its bytes, so a large file costs no context.

## Maintaining the patches

```sh
scripts/refresh-patches.sh 0.1.12    # rebase the series onto an upstream release
git add -A && git commit && git push # the Verify workflow typechecks and tests it
gh workflow run release.yml -f version=0.1.12
```

`refresh-patches.sh` works in `./src`, a clone of upstream with the series on the
`unbound` branch. On a conflict it stops inside the rebase: resolve it there,
run `git rebase --continue`, and run the script again.

| Path | Purpose |
| --- | --- |
| `patches/*.patch` | The series, as `git format-patch` output |
| `patches/BASE` | The upstream version the series was last rebased onto |
| `.github/workflows/release.yml` | Builds and publishes each upstream stable release |
| `.github/workflows/verify.yml` | Typechecks and tests the series on every change |
| `scripts/apply-patches.sh` | Applies the series to an upstream checkout |
| `scripts/refresh-patches.sh` | Rebases the series onto a new upstream release |
| `scripts/install.sh` | Switches a machine from an official build to this one |

T3 Code is MIT licensed, and so are these patches.
