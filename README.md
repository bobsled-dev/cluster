# cluster

Package up RKE2 airgap files and install scripts into a single tarball. On the target machine extract and install rke2.

## Quickstart

```sh
make build # creates a cluster-package-vX.Y.Z.tar.gz file
# move the file to the target machine
tar -xzf cluster-package-vX.Y.Z.tar.gz
sudo su
rke2-install.sh ... #
```