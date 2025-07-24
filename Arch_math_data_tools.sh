#!/bin/bash

# Arch Linux: Mathematics & Data Analysis Toolkit Installer.

set -e

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "Please run as root (use sudo)"
   exit 1
fi

echo "==> Updating system..."
pacman -Syu --noconfirm

echo "==> Installing base development tools..."
pacman -S --noconfirm base-devel git

echo "==> Installing math and numerical libraries..."
pacman -S --noconfirm \
  blas lapack arpack \
  gsl fftw eigen openblas \
  suitesparse armadillo \
  hdf5 netcdf

echo "==> Installing mathematics and symbolic computation tools..."
pacman -S --noconfirm \
  maxima \
  wxmaxima \
  sagemath \
  sympy \
  giac \
  mathomatic

echo "==> Installing statistical and data analysis tools..."
pacman -S --noconfirm \
  r \
  rstudio-desktop-bin \
  gnuplot \
  pspp \
  jupyterlab \
  python-pandas \
  python-numpy \
  python-scipy \
  python-matplotlib \
  python-seaborn \
  python-statsmodels \
  python-scikit-learn \
  python-openpyxl \
  python-xarray

echo "==> Installing general programming tools for data science..."
pacman -S --noconfirm \
  python \
  ipython \
  julia \
  octave \
  perl \
  lua \
  rust \
  go \
  ruby

echo "==> Installing AUR helper (yay)..."
if ! command -v yay &> /dev/null; then
  cd /opt
  git clone https://aur.archlinux.org/yay.git
  chown -R "$SUDO_USER":"$SUDO_USER" yay
  cd yay
  sudo -u "$SUDO_USER" makepkg -si --noconfirm
fi

echo "==> Installing AUR packages with yay..."
sudo -u "$SUDO_USER" yay -S --noconfirm \
  rstudio-desktop-bin \
  spyder \
  anaconda \
  gmt \
  wxmaxima

# Optional: Install CUDA for GPU computing (Uncomment if needed)
# echo "==> Installing GPU libraries..."
# pacman -S --noconfirm cuda cudnn python-pytorch-opt

echo "==> All tools installed successfully."
