#!/bin/bash
# Fix batch size mismatch in sampling model
# Run this in the container

file_path="/models/sampling/1/model.py"

echo "Fixing batch size handling in sampling model..."

python3 << PYEOF
import sys

file_path = sys.argv[1]

# Read the file
with open(file_path, 'r') as f:
    content = f.read()

# Find the section to replace
old_section_start = "# Extract tensors from Triton format"
old_section_end = "# Extract seed"

# Find the start and end lines
lines = content.split('\n')
start_idx = None
end_idx = None

for i, line in enumerate(lines):
    if old_section_start in line and start_idx is None:
        start_idx = i
    if start_idx is not None and "# Extract seed" in line:
        end_idx = i
        break

if start_idx is None or end_idx is None:
    print("✗ Could not find section to replace")
    sys.exit(1)

# New batch dimension handling code
new_code = '''                # Extract tensors from Triton format
                positive_np = positive_tensor.as_numpy().astype(np.float32)
                negative_np = negative_tensor.as_numpy().astype(np.float32)
                latent_np = latent_tensor.as_numpy().astype(np.float32)
                
                # Log shapes for debugging
                self.logger.log_info(f"Input shapes BEFORE processing - positive: {positive_np.shape}, negative: {negative_np.shape}, latent: {latent_np.shape}")
                
                # Convert to PyTorch tensors
                positive_pt = torch.from_numpy(positive_np)
                negative_pt = torch.from_numpy(negative_np)
                latent_pt = torch.from_numpy(latent_np)
                
                # CRITICAL: When called from ensemble with max_batch_size=1, Triton automatically prepends batch dimension
                # All inputs should arrive with batch dimension [1, ...] from the ensemble
                # We need to ensure all have exactly batch size 1 before processing
                
                # Normalize positive encoding to [1, seq_len, hidden_dim]
                if len(positive_pt.shape) == 2:
                    # [437, 3584] -> [1, 437, 3584] (no batch, add it)
                    positive_pt = positive_pt.unsqueeze(0)
                elif len(positive_pt.shape) == 3:
                    # [1, 437, 3584] or [batch, 437, 3584] - ensure batch=1
                    if positive_pt.shape[0] != 1:
                        self.logger.log_warn(f"Positive encoding has batch size {positive_pt.shape[0]}, taking first element")
                        positive_pt = positive_pt[0:1]
                else:
                    self.logger.log_warn(f"Unexpected positive encoding shape: {positive_pt.shape}")
                
                # Normalize negative encoding to [1, seq_len, hidden_dim]
                if len(negative_pt.shape) == 2:
                    # [407, 3584] -> [1, 407, 3584] (no batch, add it)
                    negative_pt = negative_pt.unsqueeze(0)
                elif len(negative_pt.shape) == 3:
                    # [1, 407, 3584] or [batch, 407, 3584] - ensure batch=1
                    if negative_pt.shape[0] != 1:
                        self.logger.log_warn(f"Negative encoding has batch size {negative_pt.shape[0]}, taking first element")
                        negative_pt = negative_pt[0:1]
                else:
                    self.logger.log_warn(f"Unexpected negative encoding shape: {negative_pt.shape}")
                
                # Normalize latent image to [1, channels, depth, height, width]
                if len(latent_pt.shape) == 4:
                    # [16, 1, 147, 110] -> [1, 16, 1, 147, 110] (no batch, add it)
                    latent_pt = latent_pt.unsqueeze(0)
                elif len(latent_pt.shape) == 5:
                    # [1, 16, 1, 147, 110] or [batch, 16, 1, 147, 110] - ensure batch=1
                    if latent_pt.shape[0] != 1:
                        self.logger.log_warn(f"Latent image has batch size {latent_pt.shape[0]}, taking first element")
                        latent_pt = latent_pt[0:1]
                else:
                    self.logger.log_warn(f"Unexpected latent image shape: {latent_pt.shape}")
                
                # Final verification - all must have batch size 1
                positive_batch = positive_pt.shape[0] if len(positive_pt.shape) >= 2 else 0
                negative_batch = negative_pt.shape[0] if len(negative_pt.shape) >= 2 else 0
                latent_batch = latent_pt.shape[0] if len(latent_pt.shape) >= 4 else 0
                
                self.logger.log_info(f"Input shapes AFTER processing - positive: {positive_pt.shape} (batch={positive_batch}), negative: {negative_pt.shape} (batch={negative_batch}), latent: {latent_pt.shape} (batch={latent_batch})")
                
                if positive_batch != negative_batch or positive_batch != latent_batch or negative_batch != latent_batch:
                    error_msg = f"Batch size mismatch after normalization: positive={positive_batch}, negative={negative_batch}, latent={latent_batch}"
                    self.logger.log_error(error_msg)
                    raise ValueError(error_msg)
                
'''

# Replace the section
new_lines = lines[:start_idx] + new_code.split('\n') + lines[end_idx:]
new_content = '\n'.join(new_lines)

# Write back
with open(file_path, 'w') as f:
    f.write(new_content)

print(f"✓ Fixed batch size handling in {file_path}")
PYEOF
"$file_path"

echo ""
echo "✅ Fix applied! Restart Triton:"
echo "   pkill -f tritonserver; sleep 2; /workspace/entrypoint.sh"


