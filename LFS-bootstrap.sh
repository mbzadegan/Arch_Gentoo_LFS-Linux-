#!/bin/bash
set -e

# LFS base configuration
export LFS=/mnt/lfs
export LFS_TGT=$(uname -m)-lfs-linux-gnu
export MAKEFLAGS="-j$(nproc)"

# Prepare directories
mkdir -pv $LFS/{sources,tools}
chmod -v a+wt $LFS/sources
ln -sv $LFS/tools /

# Check for necessary user (should be run as root)
if ! id lfs >/dev/null 2>&1; then
  echo "Creating lfs user..."
  groupadd lfs
  useradd -s /bin/bash -g lfs -m -k /dev/null lfs
  echo "lfs:lfs" | chpasswd
fi

# Give permissions
chown -v lfs $LFS/{sources,tools}
chown -v lfs $LFS

# Create environment file for lfs user
cat > /home/lfs/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' PATH=/bin:/usr/bin:/usr/local/bin:/tools/bin /bin/bash
EOF

cat > /home/lfs/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH
EOF

chown lfs:lfs /home/lfs/.bash*

# Download latest LFS book for reference
wget -P /tmp https://www.linuxfromscratch.org/lfs/downloads/stable/wget-list
wget -P /tmp https://www.linuxfromscratch.org/lfs/downloads/stable/md5sums

# Download all packages
echo "Downloading source packages..."
cd $LFS/sources
wget --input-file=/tmp/wget-list --continue --directory-prefix=$LFS/sources

echo "✅ Base LFS environment is ready."
echo "👉 Switch to the 'lfs' user and follow the LFS book from Chapter 5."
echo "   Run: 'su - lfs'"
