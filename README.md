<!--
    SPDX-FileCopyrightText: 2020-2021 Carl Schwan <carlschwan@kde.org>
    SPDX-FileCopyrightText: 2020-2024 Tobias Fella <tobias.fella@kde.org>
    SPDX-FileCopyrightText: 2023 James Graham <james.h.graham@protonmail.com>
    SPDX-License-Identifier: CC0-1.0
-->

# TailsTalk 2 for Linux

A Qt/QML desktop client for TailsTalk 2, built from KDE's NeoChat foundation.

This project keeps the GPL-3.0 license and KDE/QML interface as its starting
point, while adding a native TailsTalk 2 client protocol. TailsTalk 2 servers,
channels, messages, users, and invites are handled as TailsTalk data instead of
being squeezed into another protocol's model.

The native TailsTalk interface is the default. The `--matrix` option remains as
a compatibility escape hatch for the inherited KDE interface while the native
client grows feature-by-feature.

## Introduction

TailsTalk 2 for Linux is a native client for TailsTalk 2.

TailsTalk 2 for Linux is based on KDE Frameworks and Qt Quick. The legacy
compatibility interface still uses [libQuotient](https://github.com/quotient-im/libQuotient/),
which is retained and credited as a KDE/Matrix compatibility component.

![Timeline](https://cdn.kde.org/screenshots/neochat/application.png)

## Features

- Native TailsTalk 2 sign-in and session handling
- Server and channel discovery
- Channel history and live message updates
- Message sending through the TailsTalk 2 API
- A friendly native desktop shell built with KDE Kirigami
- Legacy Matrix-compatible interface available with `--matrix`

## Get it

Arch Linux packages can be built with the included `PKGBUILD` from this
development checkout with `makepkg --noextract --nodeps`. The `src/` directory
is the checked-out source tree, so do not run `makepkg` without `--noextract`:
makepkg normally clears its source directory before building. The project is
also designed to be installed from the TailsTalk 2 development workspace while
the native client is under active development.

## Building TailsTalk 2 for Linux

The best way to build KDE apps during development is to use `kde-builder`. The full instructions for this can be found on
the KDE community website's get involved section under [development](https://develop.kde.org/docs/getting-started/building/). This
is primarily aimed at Linux development.

For Windows and Android, [Craft](https://invent.kde.org/packaging/craft) is the primary choice. There are guides for setting up
development environments for [Windows](https://develop.kde.org/docs/getting-started/building/craft/) and [Android](https://develop.kde.org/docs/packaging/android/building_applications/).

## Running

Start `build/bin/tailstalk2-forlinux` from the build directory, or launch
`tailstalk2-forlinux` after installation. Pass `--matrix` only when you need the
legacy compatibility interface.

## Tests

Tests are in the repository under [autotests](autotests) and [appiumtests](appiumtests).

The project has CI setup to test new commits to the repository. All tests are expected to pass for a merge request to
be complete.

## Current build status

The native client is being expanded incrementally. Contributions that improve
TailsTalk protocol coverage, accessibility, and testing are especially welcome.

## Contributing

As is the case throughout the KDE ecosystem, contributions are welcome from all. The code base is managed in the
The active project repository is [TailsTalk 2 for Linux on GitHub](https://github.com/tails1154/tailstalk2-forlinux).
The original KDE source and history remain available in the upstream
[NeoChat repository](https://invent.kde.org/network/neochat).

- [Code of Conduct](https://kde.org/code-of-conduct)
- [Report a Bug](https://github.com/tails1154/tailstalk2-forlinux/issues)
- [Feature Request](https://community.kde.org/Infrastructure/GitLab#Submitting_a_merge_request)
- [Create a Merge Request](https://community.kde.org/Infrastructure/GitLab#Submitting_a_merge_request)
- [Translation](https://community.kde.org/Get_Involved/translation)

## Contact

For TailsTalk 2 bugs and ideas, use the project's GitHub issues. KDE and
NeoChat attribution, history, and licensing information are preserved below.

## Acknowledgement

The legacy compatibility interface uses [libQuotient](https://github.com/quotient-im/libQuotient/).
It is not required by the native TailsTalk message path, but remains linked for
the compatibility mode and is credited under its LGPL license.

NeoChat is a fork of [Spectral](https://gitlab.com/spectral-im/spectral/).

## License

![GPLv3](https://www.gnu.org/graphics/gplv3-127x51.png)

This program is licensed under GNU General Public License, Version 3. 

