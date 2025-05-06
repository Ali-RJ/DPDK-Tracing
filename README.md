## Introduction

The Data Plane Development Kit (DPDK) is an open-source set of libraries and drivers for fast packet processing, primarily designed to run on x86, ARM, and PowerPC processors. DPDK bypasses the Linux kernel network stack to enable high-performance packet processing in user space, making it ideal for:

* High-speed network packet processing
* Network function virtualization (NFV)
* Software-defined networking (SDN) solutions
* Router, switch, and gateway implementations
* Traffic monitoring and analysis tools

## 1. DPDK Installation Roadmap

### 1.1. System Requirements

Before installing DPDK, ensure your system meets the following requirements:

1. OS: Linux (Ubuntu, CentOS, Fedora, etc.)
2. CPU: x86, ARM, or PowerPC (with supported NICs)
3. Memory: HugePages configured (recommended for performance)
4. NIC: DPDK-supported network interface card (Intel, Mellanox, Broadcom, etc.)

Prerequisites:

1. gcc or clang
2. make
3. python3 (for some scripts)
4. libnuma-dev (for NUMA support)

### 1.2. Installation Steps

Step 1: Install Dependencies
On Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y build-essential meson ninja-build python3-pyelftools libnuma-dev pkg-config
```

Step 2: Download DPDK
Get the latest stable release from the DPDK website or clone from GitHub:

```bash
wget https://fast.dpdk.org/rel/dpdk-<version>.tar.xz
tar xf dpdk-<version>.tar.xz
cd dpdk-<version>
```

Step 3: Build and Install DPDK
1.Configure the build:

```bash
meson setup build
```

2.Compile DPDK:

```bash
ninja -C build
```

3.Install DPDK libraries and tools:

```bash
sudo ninja -C build install
sudo ldconfig
```

Step 4: Configure HugePages (Optional but Recommended)
1.Check current HugePages:

```bash
grep Huge /proc/meminfo
```

2.Reserve HugePages (e.g., 1024 x 2MB pages):

```bash
echo 1024 | sudo tree /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
```

3.Mount HugePages:

```bash
sudo mkdir -p /dev/hugepages
sudo mount -t hugetlbfs nodev /dev/hugepages
```

Step 6: Verify Installation
Run a test application to confirm DPDK works:

```bash
sudo ./build/app/dpdk-testpmd -l 0-3 -- -i
```

(Press start to begin packet forwarding.)

## 2. Adding -finstrument-functions to DPDK Build

### 2.1. Purpose

This document explains how and why to add the -finstrument-functions compiler flag to DPDK’s lib/ and drivers/ components. This flag enables function call instrumentation, which helps in debugging and performance analysis by logging every function entry and exit.

### 2.2. Changes Made

The following files were modified to include the flag:

1. dpdk/lib/meson.build

    ```build
    default_cflags += ['-finstrument-functions']
    ```

2. dpdk/drivers/meson.build

    ```build
    default_cflags += ['-finstrument-functions']
    ```

### 2.3. Build Memif

1. build

    ```bash
    cd dpdk-main
    meson setup build
    ```

2. Compile DPDK:

    ```bash
    ninja -C build
    ```

### 2.4. What This Does

1. Compiler-Level Instrumentation
The -finstrument-functions flag instructs GCC/Clang to:

    * Insert `__cyg_profile_func_enter()` at the start of every function.

    * Insert `__cyg_profile_func_exit()` at the end of every function.

2. Expected Behavior
    * All functions in DPDK libraries and drivers will now generate call traces.

    * Requires custom implementation of the profiling hooks (see below).

    * Introduces runtime overhead (use only for debugging, not production).

3. Use Cases
    * Debugging crashes – Trace which functions executed before a failure.

    * Performance profiling – Measure time spent in critical paths.

    * Call graph analysis – Understand DPDK’s internal execution flow.

## 3. LTTng Tracing for DPDK testpmd with memif 2-way Traffic

### 3.1. Introduction

This document explains how to use LTTng (Linux Trace Toolkit next generation) to trace userspace events in a DPDK testpmd application with memif 2-way traffic. LTTng provides low-overhead tracing capabilities that help analyze performance, identify bottlenecks, and debug issues in real-time packet processing scenarios.

### 3.2. Memif Poll Mode Driver

Shared memory packet interface (memif) PMD allows for DPDK and any other client using memif (DPDK, VPP, libmemif) to communicate using shared memory. Memif is Linux only.

The created device transmits packets in a raw format. It can be used with Ethernet mode, IP mode, or Punt/Inject. At this moment, only Ethernet mode is supported in DPDK memif implementation.

#### 3.2.1. Example: testpmd

In this example we run two instances of testpmd application and transmit packets over memif.

1. First create server interface:

    ```bash
    ./<build_dir>/app/dpdk-testpmd -l 0-1 --proc-type=primary --file-prefix=pmd1 --vdev=net_memif,role=server -- -i
    ```

2. Now create client interface (server must be already running so the **client** will connect):

    ```bash
    ./<build_dir>/app/dpdk-testpmd -l 2-3 --proc-type=primary --file-prefix=pmd2 --vdev=net_memif -- -i
    ```

3. You can also enable **zero-copy** on **client** interface:

    ```bash
    ./<build_dir>/app/dpdk-testpmd -l 2-3 --proc-type=primary --file-prefix=pmd2 --vdev=net_memif,zero-copy=yes --single-file-segments -- -i
    ```

4. Start forwarding packets:

    ```text
    Client:
        testpmd> start

    Server:
        testpmd> start tx_first
    ```

5. Show status:

    ```text
    testpmd> show port stats 0
    ```

### 3.3. LTTng Script

Create a Tracing Session:

```bash
sudo lttng create testpmd-memif-2way-traffic
```

Configure Userspace Channel:

```bash
sudo lttng enable-channel --userspace --num-subbuf=4 --subbuf-size=64M channel0
```

Enable All Userspace Events:

```bash
sudo lttng enable-event --channel channel0 --userspace --all
```

Add Contextual Information:

```bash
lttng add-context --channel channel0 --userspace --type=vpid --type=vtid --type=procname --type=perf:thread:cpu-cycles --type=perf:thread:instructions --type=perf:thread:cache-misses
```

Start/Stop tracing:

```bash
sudo lttng start
```

Wait for a duration as needed:

```bash
sudo lttng stop
```

Clean up:

```bash
sudo lttng destroy --all
```
