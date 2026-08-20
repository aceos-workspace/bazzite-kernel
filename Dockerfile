ARG FEDORA_VERSION=42

FROM fedora:${FEDORA_VERSION}

RUN dnf install -y fedpkg fedora-packager rpmdevtools ncurses-devel pesign \
    asciidoc audit-libs-devel bc bindgen binutils-devel bison clang dwarves \
    elfutils-devel flex fuse-devel gcc gcc-c++ gettext glibc-static hostname \
    java-devel kernel-rpm-macros libbabeltrace-devel libbpf-devel ccache \
    libcap-devel libcap-ng-devel libmnl-devel libnl3-devel libtraceevent-devel \
    libtracefs-devel lld llvm-devel lvm2 m4 make net-tools newt-devel \
    numactl-devel openssl openssl-devel pciutils-devel perl perl-devel \
    perl-generators python3-devel python3-docutils rsync rust rust-src \
    systemd-boot-unsigned systemd-ukify which xmlto xz-devel zlib-devel \
    python3-requests hmaccalc dracut tpm2-tools rustfmt clippy bpftool \
    python3-jsonschema libxml2-devel swig opencsd-devel automake \
    libtool libtirpc libtirpc-devel curl xz && dnf clean all

# AceOS 定制：Fedora 43 自带 rustc 1.96.0，与 Linux 6.17 内核不兼容
# (Rust 1.93+ 稳定化 -Zno-jump-tables, 1.95+ 稳定化自定义 target JSON 需要 -Zunstable-options)
# 覆盖为官方 Rust 1.92.0（Linux 6.17 支持的最后一个兼容版本），rust-src 一并替换保持匹配
ARG RUST_VERSION=1.92.0
RUN set -eux; \
    ARCH="x86_64-unknown-linux-gnu"; \
    TARBALL="rust-${RUST_VERSION}-${ARCH}.tar.xz"; \
    curl --fail --retry 10 --retry-delay 5 --retry-all-errors -L \
         -o "/tmp/${TARBALL}" \
         "https://static.rust-lang.org/dist/${TARBALL}"; \
    tar -xJf "/tmp/${TARBALL}" -C /tmp; \
    "/tmp/rust-${RUST_VERSION}-${ARCH}/install.sh" \
        --prefix=/usr/local \
        --components=rustc,rust-std-${ARCH},cargo,rustfmt-preview,clippy-preview,rust-src \
        --disable-ldconfig; \
    rm -rf "/tmp/rust-${RUST_VERSION}-${ARCH}" "/tmp/${TARBALL}"; \
    # 先移除 Fedora 装的 rust 二进制和 rust-src 避免版本冲突
    rm -f /usr/bin/rustc /usr/bin/cargo /usr/bin/rustfmt /usr/bin/clippy-driver; \
    ln -sf /usr/local/bin/rustc         /usr/bin/rustc; \
    ln -sf /usr/local/bin/cargo         /usr/bin/cargo; \
    ln -sf /usr/local/bin/rustfmt       /usr/bin/rustfmt; \
    ln -sf /usr/local/bin/clippy-driver /usr/bin/clippy-driver; \
    # 替换 rust-src 保持与 rustc 版本匹配
    rm -rf /usr/lib/rustlib/src/rust; \
    mkdir -p /usr/lib/rustlib/src; \
    ln -sf /usr/local/lib/rustlib/src/rust /usr/lib/rustlib/src/rust; \
    /usr/bin/rustc --version; \
    /usr/bin/cargo --version

ARG UID=1000
ARG GID=1000

RUN groupadd -g $GID -o builder && \
    useradd -m -u $UID -g $GID -o -s /bin/bash builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder && \
    chmod 0440 /etc/sudoers.d/builder
    
USER builder

WORKDIR /workspace

ENTRYPOINT [ "env" ]