# Triton Inference Server Download Guide

## Understanding Triton Releases

### Important: Server Binary vs Client Libraries

When looking at Triton releases, you need to distinguish between:

1. **Server Binary** (what we need): `tritonserver-{version}-ubuntu{version}.tar.gz`
   - Contains the actual `tritonserver` executable
   - Required to run Triton Inference Server

2. **Client Libraries**: `v{version}_ubuntu{version}.clients.tar.gz`
   - Only contains Python/HTTP/gRPC client libraries
   - NOT the server itself

3. **NGC Container**: References to "NGC container 25.10"
   - Docker images, not standalone binaries
   - Requires Docker (not available in your containerized VastAI)

### Why Version 2.62.0 Doesn't Work

Looking at release 2.62.0, the available assets are:
- `tritonserver2.62.0-igpu.tar` - Integrated GPU version (specialized)
- `tritonserver2.62.0-sbsa.tar` - ARM SBSA version (not x86_64)
- `v2.62.0_ubuntu2404.clients.tar.gz` - **Client libraries only** (not server)
- Source code

**The server binary for Ubuntu 24.04 is missing from this release.**

## Solution: Use Older Stable Releases

Use releases **2.47.0 or earlier** which have full server binaries:

### Recommended Versions (with server binaries):

1. **v2.47.0** - Most recent with full server package
   - Has: `tritonserver-2.47.0-ubuntu22.04.tar.gz` ✅
   - Compatible with Ubuntu 24.04

2. **v2.46.0** - Stable release
   - Has: `tritonserver-2.46.0-ubuntu22.04.tar.gz` ✅

3. **v2.45.0** - Stable release
   - Has: `tritonserver-2.45.0-ubuntu22.04.tar.gz` ✅

## Direct Download Commands

### Option 1: Version 2.47.0 (Recommended)

```bash
cd /workspace/vtryon2_triton/microservices

# Download server binary (NOT client libraries)
wget https://github.com/triton-inference-server/server/releases/download/v2.47.0/tritonserver-2.47.0-ubuntu22.04.tar.gz

# Extract
tar -xzf tritonserver-2.47.0-ubuntu22.04.tar.gz

# Rename to consistent name
mv tritonserver-2.47.0-ubuntu22.04 tritonserver

# Verify
ls -la tritonserver/bin/tritonserver

# Cleanup
rm tritonserver-2.47.0-ubuntu22.04.tar.gz
```

### Option 2: Version 2.46.0

```bash
wget https://github.com/triton-inference-server/server/releases/download/v2.46.0/tritonserver-2.46.0-ubuntu22.04.tar.gz
tar -xzf tritonserver-2.46.0-ubuntu22.04.tar.gz
mv tritonserver-2.46.0-ubuntu22.04 tritonserver
rm tritonserver-2.46.0-ubuntu22.04.tar.gz
```

### Option 3: Version 2.45.0

```bash
wget https://github.com/triton-inference-server/server/releases/download/v2.45.0/tritonserver-2.45.0-ubuntu22.04.tar.gz
tar -xzf tritonserver-2.45.0-ubuntu22.04.tar.gz
mv tritonserver-2.45.0-ubuntu22.04 tritonserver
rm tritonserver-2.45.0-ubuntu22.04.tar.gz
```

## How to Identify the Right Package

When browsing releases, look for assets named:
- ✅ `tritonserver-{version}-ubuntu{version}.tar.gz` - **This is what you need**
- ❌ `v{version}_ubuntu{version}.clients.tar.gz` - Client libraries only
- ❌ `tritonserver{version}-igpu.tar` - Specialized GPU version
- ❌ `tritonserver{version}-sbsa.tar` - ARM version

## Verification

After installation, verify:

```bash
# Check if server binary exists
ls -la tritonserver/bin/tritonserver

# Check version
./tritonserver/bin/tritonserver --version

# Should output something like:
# tritonserver 2.47.0
```

## Why Ubuntu 22.04 Package Works on 24.04

Ubuntu 24.04 is backward compatible with 22.04 binaries because:
- Same architecture (x86_64)
- Compatible glibc versions
- Compatible system libraries

The 22.04 package will run fine on 24.04.

## Troubleshooting

If downloads fail:

1. **Check internet connection**:
   ```bash
   curl -I https://github.com
   ```

2. **Try different version**:
   - Use the manual install script: `./manual_triton_install.sh`
   - Or try versions 2.46.0, 2.45.0, 2.44.0

3. **Check release page directly**:
   - Visit: https://github.com/triton-inference-server/server/releases
   - Look for releases with `tritonserver-*-ubuntu22.04.tar.gz` assets
   - Avoid releases that only have client libraries

## Summary

**What you need**: `tritonserver-2.47.0-ubuntu22.04.tar.gz` (or similar)
**What you DON'T need**: `v2.62.0_ubuntu2404.clients.tar.gz` (client libraries only)

Use version 2.47.0 or earlier for full server binaries.

