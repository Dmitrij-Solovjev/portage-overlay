# portage-overlay

personal portage repository for [Gentoo Linux](http://www.gentoo.org/)

## Included packages

| package | name | description | generates native code |
|---------|------|-------------|------|
| `app-admin/enpass` | [Enpass](https://www.enpass.io/) | Password Manager | |
| `app-editors/code` | [Code](https://github.com/elementary/code) | Code editor designed for elementary OS | ✔ |
| `dev-db/dbeaver-ce` | [DBeaver Community](https://dbeaver.io/) | Universal Database Tool | |
| `dev-db/sequeler` | [Sequeler](https://github.com/Alecaddd/sequeler) | SQL Client built in Vala | ✔ |
| `dev-util/idea-ultimate` | [IntelliJ IDEA Ultimate](https://www.jetbrains.com/idea/) | Capable and Ergonomic IDE for JVM | |
| `dev-vcs/github-desktop` | [GitHub Desktop (unofficial)](https://github.com/shiftkey/desktop) | Fork of GitHub Desktop to support various Linux distributions | |
| `media-fonts/source-han-code-jp` | [Source Han Code JP](https://github.com/adobe-fonts/source-han-code-jp) | Source Han Code JP / 源ノ角ゴシック | |
| `media-fonts/source-han-serif` | [Source Han Serif](https://github.com/adobe-fonts/source-han-serif) | Source Han Serif / 源ノ明朝 | |
| `net-im/caprine` | [Caprine](https://sindresorhus.com/caprine/) | Elegant Facebook Messenger desktop app | |
| `www-misc/webtaku` | [webtaku](https://github.com/shimataro/webtaku) | webpage snapshot image generator | ✔ |
| `x11-libs/bamf` | [BAMF](https://launchpad.net/bamf) | Removes the headache of applications matching into a simple DBus daemon and c wrapper library | ✔ |
| `x11-misc/plank` | [Plank](https://launchpad.net/plank) | The dock for elementary Pantheon, stupidly simple | ✔ |
| `x11-misc/vala-panel` | [vala-panel](https://github.com/rilian-la-te/vala-panel) | Vala rewrite of SimplePanel | ✔ |
| `x11-misc/vala-panel-appmenu` | [vala-panel-appmenu](https://github.com/rilian-la-te/vala-panel-appmenu) | Global Menu for Vala Panel (and xfce4-panel and mate-panel) | ✔ |
| `x11-themes/flat-remix` | [Flat Remix](https://github.com/daniruiz/flat-remix) | A flat theme with transparent elements | |
| `x11-themes/flat-remix-gnome` | [Flat Remix GNOME](https://github.com/daniruiz/flat-remix-gnome) | A flat theme with transparent elements | |
| `x11-themes/flat-remix-gtk` | [Flat Remix GTK](https://github.com/daniruiz/flat-remix-gtk) | A flat theme with transparent elements | |
| `x11-themes/yaru` | [Yaru](https://github.com/ubuntu/yaru) | Ubuntu community theme "yaru". Better than a 🌯. | |

## How to use

1. Delete below code in `/etc/portage/make.conf`

    ```conf
    PORTDIR="..."
    ```

1. Copy [`shimataro.conf`](./shimataro.conf) to `/etc/portage/repos.conf/`
(create if directory doesn't exist)

## How to build manifest file

```bash
ebuild path/to/ebuild digest
```

## Project page

<https://github.com/shimataro/portage-overlay>
