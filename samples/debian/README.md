
# Scripts for creating Proxmox templates

In this folder are a variety of scripts for setting up Debian VM templates.

## Usage

### Basic Debian 12 "Bookworm" template

```sh
$export VMID=8001 STORAGE=local-zfs
$curl -fsSL https://github.com/UntouchedWagons/Ubuntu-CloudInit-Docs/raw/refs/heads/main/samples/debian/debian-12-cloudinit.sh | bash
```

### Debian 12 "Bookworm" template with Docker auto-installed

```sh
$export VMID=8002 STORAGE=local-zfs
$curl -fsSL https://github.com/UntouchedWagons/Ubuntu-CloudInit-Docs/raw/refs/heads/main/samples/debian/debian-12-cloudinit+docker.sh | bash
```

### Basic Debian 13 "Trixie" template

```sh
$export VMID=8003 STORAGE=local-zfs
$curl -fsSL https://github.com/UntouchedWagons/Ubuntu-CloudInit-Docs/raw/refs/heads/main/samples/debian/debian-13-cloudinit.sh | bash
```

### Debian 13 "Trixie" template with Docker auto-installed

```sh
$export VMID=8004 STORAGE=local-zfs
$curl -fsSL https://github.com/UntouchedWagons/Ubuntu-CloudInit-Docs/raw/refs/heads/main/samples/debian/debian-13-cloudinit+docker.sh | bash
```

### Debian 13 "Trixie" template with NVidia driver and container runtime auto-installed

```sh
$export VMID=8005 STORAGE=local-zfs
$curl -fsSL https://github.com/UntouchedWagons/Ubuntu-CloudInit-Docs/raw/refs/heads/main/samples/debian/debian-13-cloudinit+nvidia.sh | bash
```

Note: Building the nvidia driver takes a couple of minutes.