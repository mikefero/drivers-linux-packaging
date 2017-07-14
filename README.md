# DataStax Drivers - Packaging for Linux Distros
The [`build.sh`](https://github.com/mikefero/drivers-linux-packaging) script
will perform the package building (e.g. release package generation) for the
C/C++ DataStax drivers (core and DSE) against the following distros:

- CentOS 5.11
- CentOS 6.9
- CentOS 7.3
- Ubuntu 12.04 LTS
- Ubuntu 14.04 LTS
- Ubuntu 16.04 LTS

## Obtaining Dependencies

### Requirements
- [Virtual Box](https://www.virtualbox.org/wiki/Downloads)
- [Vagrant](https://www.vagrantup.com/downloads.html)

## Usage - Building Packages for Distros

```
Usage: build.sh [OPTION...]

    --clean                    enable packing directory clean
    --help                     display this message

Dependencies:
    --libuv=(version)          libuv driver dependency version to build

Drivers:
    DataStax C/C++ Driver:
      --cpp-core=(branch|tag)  DataStax C/C++ driver version to build
      --cpp-dse=(branch|tag)   DataStax C/C++ DSE driver version to build
```

### Example Build Configurations

1. To build the packages with libuv v1.13.1 and DataStax C/C++ driver v2.7.0

```
./build.sh --libuv=1.13.1 --cpp-core=2.7.0
```

2. To build the packages with libuv v1.13.1 DataStax C/C++ driver v2.7.0, and
   C/C++ DSE driver v1.3.0

```
./build.sh --libuv=1.13.1 --cpp-core=2.7.0 --cpp-dse=1.3.0
```

# TODO
- Update packages directory to mimic the downloads.datastax.com site
- Simplify `Vagrantfile` and remove unnecessary configuration options
- Vendor the libuv-packaging repository and combine into `build.sh` script
- Remove multiple `Vagrantfile` scripts for heredoc generation in script
- Add 32-bit packaging for applicable distros
