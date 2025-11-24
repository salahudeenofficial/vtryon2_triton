# Triton CUDA Memory Pool Size Analysis

## Current Situation

**Default Pool**: 64 MB per GPU  
**Your Tensor Sizes**: 
- Largest stage (sampling): 14.17 MB peak
- Output image: 12.42 MB
- Text encodings: 12.10 MB total

## Concurrent Request Analysis

| Concurrent Requests | Required Pool | Current Pool (64 MB) | Status |
|---------------------|---------------|----------------------|--------|
| 1 request           | 14.17 MB      | 64 MB (22%)          | ✅ OK  |
| 2 requests          | 28.34 MB      | 64 MB (44%)          | ✅ OK  |
| 4 requests          | 56.68 MB      | 64 MB (89%)          | ⚠️ TIGHT |
| 8 requests          | 113.35 MB     | 64 MB (177%)         | ❌ EXCEEDS |

## Problem

**64 MB is NOT enough** for:
- 4+ concurrent requests (88.6% utilization - too tight)
- 8 concurrent requests (177% - exceeds pool, falls back to regular allocations)

## Impact of Insufficient Pool

When pool is exhausted:
1. ✅ **Still works** - Triton falls back to regular CUDA allocations
2. ⚠️ **Performance loss** - Loses optimization benefit of pre-allocated pool
3. ⚠️ **Potential slowdown** - More allocation overhead per request

## Solution

**Recommended Pool Size**: **170 MB** (for 8 concurrent requests with 50% headroom)

### Configuration

Updated `entrypoint.sh` to include:
```bash
--cuda-memory-pool-byte-size=0:178257920
```

This sets:
- GPU 0: 170 MB pool
- Supports 8+ concurrent requests comfortably
- 50% headroom for safety

### Memory Trade-off

- **Pool size**: 170 MB (pre-allocated, always reserved)
- **Available for models**: Total GPU memory - 170 MB
- **Impact**: Minimal (170 MB is 0.7% of 24GB GPU, 1.4% of 12GB GPU)

## Verification

After updating, check logs for:
```
cuda_memory_pool_byte_size{0} = 178257920
```

## Alternative: Keep 64 MB

If you want to keep 64 MB (saves 106 MB GPU memory):
- ✅ Works for 1-2 concurrent requests
- ⚠️ Tight for 4 concurrent (may fall back)
- ❌ Exceeds for 8 concurrent (will fall back)

**Recommendation**: Use 170 MB for better performance with concurrent requests.


