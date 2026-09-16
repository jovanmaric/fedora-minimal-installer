# Fedora minimal installer

Generates a custom Fedora installation ISO with an interactive kickstart configuration included.

Installs the bare minimum "the Arch way": With no weak dependencies and bloat, while providing an interactive installer for networking, disk selection, encryption and passwords.

It is meant to be as minimal as possible, so that ansible configuration can be applied later on.

- [Fedora minimal installer](#fedora-minimal-installer)
  * [What the ISO does](#what-the-iso-does)
  * [Building the ISO](#building-the-iso)
    + [Requirements](#requirements)
    + [With Docker](#with-docker)
    + [Without Docker](#without-docker)
    + [Generating the ISO](#generating-the-iso)
  * [Post-install](#post-install)
    + [Connect to WiFi](#connect-to-wifi)
  * [License](#license)

## What the ISO does

> **Running the ISO is destructive.** Make backups and read the on-screen output carefully.

The kickstart script will interactively:

- Connect to the internet via WiFi or Ethernet using NetworkManager (`nmcli`).
- Ask for locale, keyboard layout, and timezone.
- Ask which disk to install to.
- Optionally set up full disk encryption (LUKS).
- Set a root password.

Then automatically:

- Install a minimal base system (`@core`) with no weak dependencies.
- On top of that, explicitly remove as they should be opted-in when needed:

  | Package                     | Reason                               |
  |-----------------------------|--------------------------------------|
  | `man-db`                    | Man pages.                           |
  | `openssh-server`            | SSH server.                          |
  | `firewalld`                 | Firewall daemon.                     |
  | `systemd-resolved`          | Systemd DNS resolver.                |
  | `plymouth`                  | Boot splash screen.                  |
  | `zram-generator-defaults`   | Compressed RAM swap.                 |

- Install `linux-firmware` and `NetworkManager`.
- Install any extra packages passed via `--add-packages`.
- Remove any additional packages passed via `--remove-packages`.
- Post-install (chroot):
  - Refresh the mirrorlist and update all packages without weak dependencies.
  - Remove saved NetworkManager connections (`/etc/NetworkManager/system-connections/*`) as they are in plaintext.
  - Remove Anaconda kickstart files (`/root/*.cfg`) as they could contain passwords in plaintext.

## Building the ISO

### Requirements

Docker is the recommended way to build the ISO as it contains all dependencies. Otherwise the following packages are needed:

| Package       | Purpose                                                                  |
|---------------|--------------------------------------------------------------------------|
| `lorax`       | Embeds the kickstart file into the ISO with `mkksiso`.                   |
| `pykickstart` | Validates the kickstart file with `ksvalidator` before building the ISO. |

```bash
sudo dnf install -y lorax pykickstart
```

### With Docker

`mkksiso` needs access to loop devices to build the ISO. Therefore the `--privileged` flag is required to expose them.

Build the image and drop into the container:

```bash
docker build --build-arg FEDORA_VERSION=44 \
             --tag localhost/fedora_iso_builder \
             .

docker run --interactive \
           --tty \
           --privileged \
           --volume './:/home/fedora:z' \
           localhost/fedora_iso_builder \
           bash
```

### Without Docker

Run `create_iso.sh` directly on a Fedora host with the dependencies above installed. `mkksiso` requires loop device access, so run as root or with `sudo`.

### Generating the ISO

`create_iso.sh` accepts the following flags:

| Flag                         | Required | Description                                                          |
|------------------------------|----------|----------------------------------------------------------------------|
| `--fedora-url <url>`         | yes      | URL to the base Fedora Everything netinstall ISO to build on top of. |
| `--add-packages <pkg...>`    |          | Space-separated list of packages to add.                             |
| `--remove-packages <pkg...>` |          | Space-separated list of packages to remove.                          |
| `--help`                     |          | Show usage information.                                              |

The following example targets a Framework 13 laptop (AMD Ryzen 7840U), which needs the MediaTek WiFi driver (`mt7xxx-firmware`) and `NetworkManager-wifi` for wireless support:

```bash
./create_iso.sh --fedora-url https://download.fedoraproject.org/pub/fedora/linux/releases/44/Everything/x86_64/iso/Fedora-Everything-netinst-x86_64-44-1.7.iso \
                --add-packages mt7xxx-firmware NetworkManager-wifi ansible
```

The resulting ISO is written to `.dist/fedora.iso`. To `destructively` write it to a USB drive:

> **Replace `/dev/sdX`** with your USB device. Double-check with `lsblk` first that you don't wipe a device by accident.

```bash
sudo dd bs=4M \
        if=.dist/fedora.iso \
        of=/dev/sdX \
        conv=fsync \
        oflag=direct \
        status=progress
```

## Post-install

### Connect to WiFi

NetworkManager is installed as part of the base system and is available immediately after first boot.
If you have the proper WiFi drivers installed, you can turn it on as follows:

```bash
# Enable WiFi radio.
nmcli radio wifi on

# List available networks.
nmcli dev wifi list

# Connect to a network.
nmcli dev wifi connect SSID_NAME --ask

# Verify connection.
nmcli dev status
```

## License

This project is licensed under the [MIT License](LICENSE).
