# Maintainer: tails1154
# TailsTalk 2 for Linux is a GPL-licensed fork of KDE NeoChat.
pkgname=tailstalk2-forlinux
pkgver=26.11.70
pkgrel=6
pkgdesc='TailsTalk 2 for Linux desktop client, based on KDE NeoChat'
arch=('x86_64')
url='https://github.com/tails1154/tailstalk2-forlinux'
license=('GPL-3.0-or-later')
depends=(
  'cmark'
  'icu'
  'kcoreaddons'
  'kcrash'
  'kdbusaddons'
  'kdeclarative'
  'kglobalaccel'
  'kguiaddons'
  'ki18n'
  'kio'
  'kirigami'
  'kirigami-addons'
  'kitemmodels'
  'knotifications'
  'kquickimageeditor'
  'kservice'
  'ksvg'
  'kwindowsystem'
  'libquotient'
  'purpose'
  'qt6-base'
  'qt6-declarative'
  'qt6-location'
  'qt6-multimedia'
  'qt6-svg'
  'qt6-speech'
  'qt6-webview'
  'qcoro'
  'kunifiedpush'
)
makedepends=('cmake' 'ninja' 'clang' 'extra-cmake-modules')
conflicts=('neochat')
replaces=('neochat')
options=('!strip')

build() {
  cmake --build "$startdir/build" --parallel 4
}

package() {
  DESTDIR="$pkgdir" cmake --install "$startdir/build" --prefix /usr
}
