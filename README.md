# cluster

Package up RKE2 airgap files and install scripts into a single tarball. On the target machine extract and install rke2.

## Quickstart

```sh
curl | wget https://github.com/bobsled-dev/cluster/releases/download/vx.y.z/cluster-package-vx.y.z.tar.gz
# move the file to the target machine
tar -xf cluster-package-vX.Y.Z.tar.gz
sudo su
rke2-install.sh ... #
```