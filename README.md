# portage-overlay

personal portage repository for [Gentoo Linux](http://www.gentoo.org/)

## Included packages

| package | name | description | generates native code | note |
|---------|------|-------------|-----------------------|------|
| [`x11-themes/yaru`](./x11-themes/yaru) | [Yaru](https://github.com/ubuntu/yaru) | Ubuntu community theme "yaru". Better than a 🌯. | | |

## How to use

1. Delete below code in `/etc/portage/make.conf`

    ```bash
    PORTDIR="..."
    ```

1. Copy [`dmitrij.conf`](./dmitrij.conf) to `/etc/portage/repos.conf/`
(create if directory doesn't exist)

## How to build manifest file

```bash
ebuild path/to/ebuild digest
```

## Project page

<https://github.com/Dmitrij-Solovjev/portage-overlay>
