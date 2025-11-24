# Fix Batch Size Mismatch Error

## Error
```
{"error":"in ensemble 'vtryon_pipeline', [request id: <id_unknown>] input 'latent_image' batch size does not match other inputs for 'sampling'"}
```

## Cause
When Triton passes data through an ensemble with `max_batch_size=1`, it automatically prepends batch dimensions. However, inputs may have inconsistent batch dimensions, causing a mismatch.

## Fix Applied Locally
The file `/home/fashionx/vtryon2/microservices/triton_model_repository/sampling/1/model.py` has been updated to:
1. Normalize all inputs by removing batch dimension if present
2. Add batch dimension uniformly to all inputs
3. Verify and fix any remaining batch size mismatches

## Apply Fix in Container

### Option 1: Manual Edit (Quick)
Edit `/models/sampling/1/model.py` in the container and replace lines 71-130 with the fixed version.

### Option 2: Python Script (Automated)
Run this in the container:

```python
python3 << 'PYEOF'
import sys

file_path = "/models/sampling/1/model.py"

# Read the fixed code section
fixed_code = '''                # Extract tensors from Triton format
                positive_np = positive_tensor.as_numpy().astype(np.float32)
                negative_np = negative_tensor.as_numpy().astype(np.float32)
                latent_np = latent_tensor.as_numpy().astype(np.float32)
                
                # Log shapes for debugging
                self.logger.log_info(f"Input shapes - positive: {positive_np.shape}, negative: {negative_np.shape}, latent: {latent_np.shape}")
                
                # Convert to PyTorch tensors
                positive_pt = torch.from_numpy(positive_np)
                negative_pt = torch.from_numpy(negative_np)
                latent_pt = torch.from_numpy(latent_np)
                
                # When called from ensemble with max_batch_size=1, Triton automatically prepends batch dimension
                # So inputs come as: [1, ...] but we need to ensure consistency
                # Remove batch dimension if present, then add it back uniformly
                
                # Positive encoding: remove batch if present, then add
                if len(positive_pt.shape) == 3 and positive_pt.shape[0] == 1:
                    # [1, 437, 3584] -> [437, 3584]
                    positive_pt = positive_pt[0]
                if len(positive_pt.shape) == 2:
                    # [437, 3584] -> [1, 437, 3584]
                    positive_pt = positive_pt.unsqueeze(0)
                
                # Negative encoding: remove batch if present, then add
                if len(negative_pt.shape) == 3 and negative_pt.shape[0] == 1:
                    # [1, 407, 3584] -> [407, 3584]
                    negative_pt = negative_pt[0]
                if len(negative_pt.shape) == 2:
                    # [407, 3584] -> [1, 407, 3584]
                    negative_pt = negative_pt.unsqueeze(0)
                
                # Latent image: remove batch if present, then add
                if len(latent_pt.shape) == 5 and latent_pt.shape[0] == 1:
                    # [1, 16, 1, 147, 110] -> [16, 1, 147, 110]
                    latent_pt = latent_pt[0]
                if len(latent_pt.shape) == 4:
                    # [16, 1, 147, 110] -> [1, 16, 1, 147, 110]
                    latent_pt = latent_pt.unsqueeze(0)
                
                # Verify all have same batch size
                batch_sizes = []
                if len(positive_pt.shape) >= 2:
                    batch_sizes.append(positive_pt.shape[0])
                if len(negative_pt.shape) >= 2:
                    batch_sizes.append(negative_pt.shape[0])
                if len(latent_pt.shape) >= 4:
                    batch_sizes.append(latent_pt.shape[0])
                
                if batch_sizes and len(set(batch_sizes)) > 1:
                    self.logger.log_warn(f"Batch size mismatch: positive={positive_pt.shape[0] if len(positive_pt.shape) >= 2 else 'N/A'}, negative={negative_pt.shape[0] if len(negative_pt.shape) >= 2 else 'N/A'}, latent={latent_pt.shape[0] if len(latent_pt.shape) >= 4 else 'N/A'}")
                    # Use the first batch size and adjust others
                    target_batch = batch_sizes[0]
                    if len(positive_pt.shape) >= 2 and positive_pt.shape[0] != target_batch:
                        if positive_pt.shape[0] == 1:
                            positive_pt = positive_pt.expand(target_batch, -1, -1)
                        else:
                            positive_pt = positive_pt[:target_batch]
                    if len(negative_pt.shape) >= 2 and negative_pt.shape[0] != target_batch:
                        if negative_pt.shape[0] == 1:
                            negative_pt = negative_pt.expand(target_batch, -1, -1)
                        else:
                            negative_pt = negative_pt[:target_batch]
                    if len(latent_pt.shape) >= 4 and latent_pt.shape[0] != target_batch:
                        if latent_pt.shape[0] == 1:
                            latent_pt = latent_pt.expand(target_batch, -1, -1, -1, -1)
                        else:
                            latent_pt = latent_pt[:target_batch]'''

# Read original file
with open(file_path, 'r') as f:
    lines = f.readlines()

# Find the section to replace (lines 71-89)
start_line = None
end_line = None
for i, line in enumerate(lines):
    if '# Extract tensors from Triton format' in line and start_line is None:
        start_line = i
    if start_line is not None and '# Extract seed' in line:
        end_line = i
        break

if start_line is not None and end_line is not None:
    # Replace the section
    new_lines = lines[:start_line] + [fixed_code + '\n'] + lines[end_line:]
    with open(file_path, 'w') as f:
        f.writelines(new_lines)
    print(f"✓ Fixed {file_path}")
else:
    print(f"✗ Could not find replacement section in {file_path}")
PYEOF
```

### Option 3: Rebuild Image
Rebuild the Docker image with the updated file.

## After Applying Fix
Restart Triton:
```bash
pkill -f tritonserver
/workspace/entrypoint.sh
```

## Verification
The fix ensures all inputs (positive_encoding, negative_encoding, latent_image) have the same batch size before being passed to the service function.


