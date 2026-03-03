# X Distribution — Roadmap

A comprehensive roadmap for the X Linux distribution, an Arch-based spin with its own package repository.

---

## Phase 1: Branding & Identity <!-- phase:branding -->

- [x] System identity (`/etc/os-release`)
- [x] GRUB distributor name (`GRUB_DISTRIBUTOR="X"`)
- [x] Bootloader menu entries (GRUB, systemd-boot, syslinux)
- [x] Fastfetch configuration
- [x] ISO profile (`profiledef.sh`)
- [x] MOTD (Message of the Day)

---

## Phase 2: Package Repository <!-- phase:package-repo -->

- [x] Create `x-release` PKGBUILD
- [x] Create install hooks
- [x] Add repository to `pacman.conf`
- [ ] Build package with `./build-repo.sh`
- [ ] Create `x-repo` repository on GitHub
- [ ] Upload package files to GitHub Releases (tag: `latest`)
- [ ] Test ISO build with package
- [ ] Migrate additional tools to the x repository

---

## Phase 3: Installation Experience <!-- phase:installation -->

- [x] Archinstall configuration (`user_configuration.json`)
- [x] Automated installation (`x-autostart.sh`)
- [x] Post-install branding (`x-postinstall.sh`)
- [ ] Custom installer UI (future)
- [ ] Welcome app on first boot (future)

---

## Phase 4: Desktop Environment <!-- phase:desktop-env -->

- [x] GNOME branding (wallpaper, GDM logo)
- [x] KDE Plasma branding
- [x] XFCE branding
- [x] Display manager configuration (GDM, SDDM, LightDM)
- [ ] Custom theme/icons (future)
- [ ] Default application configuration

---

## Phase 5: Documentation & Website <!-- phase:docs -->

- [ ] Landing page at `dev.xscriptor.com/x`
- [ ] Installation guide
- [ ] FAQ / Troubleshooting
- [ ] Release notes template

---

## Phase 6: Release Pipeline <!-- phase:release -->

- [ ] Automated ISO builds (GitHub Actions / GitLab CI)
- [ ] Package signing with GPG
- [ ] Release versioning strategy
- [ ] Mirror setup (optional)

---

## Quick Start Commands

```bash
# Build the x-release package
cd x-packages
./build-repo.sh

# Build the ISO
cd /path/to/x-linux
./xbuild.sh

# Build a WSL tarball
sudo ./xbuildwsl.sh
```

---

## Files Reference

| File | Purpose |
|------|---------|
| `profiledef.sh` | ISO metadata and build settings |
| `pacman.conf` | Package manager configuration with x repo |
| `packages.x86_64` | Packages included in the ISO |
| `airootfs/etc/os-release` | System identity |
| `airootfs/etc/default/grub` | GRUB configuration |
| `xbuild.sh` | ISO build script |
| `xbuildwsl.sh` | WSL tarball build script |
