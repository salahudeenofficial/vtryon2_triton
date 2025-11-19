#!/usr/bin/env python3
"""
Generate Triton config.pbtxt files from Phase 2 test results.

This script reads TRITON_CONFIG_DATA.json from each service's test results
and generates the corresponding config.pbtxt files for Triton Inference Server.
"""

import json
import sys
from pathlib import Path
from typing import Dict, Any, List

def load_test_results(service_name: str) -> Dict[str, Any]:
    """Load TRITON_CONFIG_DATA.json for a service."""
    test_results_path = Path(__file__).parent / "test_results" / service_name / "TRITON_CONFIG_DATA.json"
    if not test_results_path.exists():
        raise FileNotFoundError(f"Test results not found: {test_results_path}")
    
    with open(test_results_path, 'r') as f:
        return json.load(f)

def get_triton_type(python_type: str) -> str:
    """Convert Python type to Triton type."""
    type_map = {
        "torch.float32": "TYPE_FP32",
        "torch.float16": "TYPE_FP16",
        "torch.int32": "TYPE_INT32",
        "torch.int64": "TYPE_INT64",
        "str": "TYPE_STRING",
        "STRING": "TYPE_STRING",
    }
    return type_map.get(python_type, "TYPE_FP32")

def format_dims(shape: List[int]) -> str:
    """Format tensor dimensions for config.pbtxt."""
    if not shape:
        return "[]"
    # Use -1 for batch dimension (first dimension)
    dims = shape.copy()
    if len(dims) > 0:
        dims[0] = -1  # Dynamic batch dimension
    return "[" + ", ".join(str(d) for d in dims) + "]"

def generate_latent_encoder_config(data: Dict[str, Any]) -> str:
    """Generate config.pbtxt for latent_encoder."""
    tensor_info = data["tensor_info"]
    resource_req = data.get("resource_requirements", {})
    concurrency = data.get("triton_config", {}).get("concurrency_analysis", {})
    
    input_info = tensor_info["input"]
    output_info = tensor_info["output"]
    
    recommended_instances = concurrency.get("recommended_instances", 1)
    
    config = f'''name: "latent_encoder"
backend: "python"
max_batch_size: 1

input [
  {{
    name: "{input_info.get('name', 'input_image')}"
    data_type: TYPE_STRING
    dims: [ 1 ]
  }}
]

output [
  {{
    name: "{output_info.get('name', 'latent')}"
    data_type: {get_triton_type(output_info.get('data_type', 'torch.float32'))}
    dims: {format_dims(output_info.get('shape', []))}
  }}
]

instance_group [
  {{
    count: {recommended_instances}
    kind: KIND_GPU
  }}
]

parameters [
  {{
    key: "MODEL_DIR"
    value: {{ string_value: "${{TRITON_MODEL_REPOSITORY}}/shared_models" }}
  }},
  {{
    key: "COMFYUI_PATH"
    value: {{ string_value: "${{TRITON_MODEL_REPOSITORY}}/shared_comfyui" }}
  }}
]
'''
    return config

def generate_text_encoder_config(data: Dict[str, Any]) -> str:
    """Generate config.pbtxt for text_encoder."""
    tensor_info = data["tensor_info"]
    resource_req = data.get("resource_requirements", {})
    concurrency = data.get("triton_config", {}).get("concurrency_analysis", {})
    
    inputs = tensor_info["inputs"]
    outputs = tensor_info["outputs"]
    
    recommended_instances = concurrency.get("recommended_instances", 1)
    
    input_section = "input [\n"
    for key, info in inputs.items():
        input_section += f'  {{\n    name: "{key}"\n    data_type: TYPE_STRING\n    dims: [ 1 ]\n  }}\n'
    input_section += "]"
    
    output_section = "output [\n"
    for key, info in outputs.items():
        name = info.get('name', key)
        dtype = get_triton_type(info.get("data_type", "torch.float32"))
        dims = format_dims(info.get("shape", []))
        output_section += f'  {{\n    name: "{name}"\n    data_type: {dtype}\n    dims: {dims}\n  }}\n'
    output_section += "]"
    
    config = f'''name: "text_encoder"
backend: "python"
max_batch_size: 1

{input_section}

{output_section}

instance_group [
  {{
    count: {recommended_instances}
    kind: KIND_GPU
  }}
]

parameters [
  {{
    key: "MODEL_DIR"
    value: {{ string_value: "${{TRITON_MODEL_REPOSITORY}}/shared_models" }}
  }},
  {{
    key: "COMFYUI_PATH"
    value: {{ string_value: "${{TRITON_MODEL_REPOSITORY}}/shared_comfyui" }}
  }}
]
'''
    return config

def generate_sampling_config(data: Dict[str, Any]) -> str:
    """Generate config.pbtxt for sampling."""
    tensor_info = data["tensor_info"]
    resource_req = data.get("resource_requirements", {})
    concurrency = data.get("triton_config", {}).get("concurrency_analysis", {})
    
    inputs = tensor_info["inputs"]
    output = tensor_info["output"]
    
    recommended_instances = concurrency.get("recommended_instances", 1)
    
    input_section = "input [\n"
    for key, info in inputs.items():
        if info.get("type") == "tensor_file":
            input_section += f'  {{\n    name: "{key}"\n    data_type: TYPE_STRING\n    dims: [ 1 ]\n  }}\n'
        else:
            triton_type = get_triton_type(info.get("type", "INT64"))
            input_section += f'  {{\n    name: "{key}"\n    data_type: {triton_type}\n    dims: [ 1 ]\n  }}\n'
    input_section += "]"
    
    config = f'''name: "sampling"
backend: "python"
max_batch_size: 1

{input_section}

output [
  {{
    name: "{output.get('name', 'sampled_latent')}"
    data_type: {get_triton_type(output.get('data_type', 'torch.float32'))}
    dims: {format_dims(output.get('shape', []))}
  }}
]

instance_group [
  {{
    count: {recommended_instances}
    kind: KIND_GPU
  }}
]

parameters [
  {{
    key: "MODEL_DIR"
    value: {{ string_value: "${{TRITON_MODEL_REPOSITORY}}/shared_models" }}
  }},
  {{
    key: "COMFYUI_PATH"
    value: {{ string_value: "${{TRITON_MODEL_REPOSITORY}}/shared_comfyui" }}
  }}
]
'''
    return config

def generate_decoding_config(data: Dict[str, Any]) -> str:
    """Generate config.pbtxt for decoding."""
    tensor_info = data["tensor_info"]
    resource_req = data.get("resource_requirements", {})
    concurrency = data.get("triton_config", {}).get("concurrency_analysis", {})
    
    input_info = tensor_info["input"]
    output_info = tensor_info["output"]
    
    recommended_instances = concurrency.get("recommended_instances", 1)
    
    config = f'''name: "decoding"
backend: "python"
max_batch_size: 1

input [
  {{
    name: "{input_info.get('name', 'latent')}"
    data_type: TYPE_STRING
    dims: [ 1 ]
  }}
]

output [
  {{
    name: "{output_info.get('name', 'image')}"
    data_type: {get_triton_type(output_info.get('data_type', 'torch.float32'))}
    dims: {format_dims(output_info.get('shape', []))}
  }}
]

instance_group [
  {{
    count: {recommended_instances}
    kind: KIND_GPU
  }}
]

parameters [
  {{
    key: "MODEL_DIR"
    value: {{ string_value: "${{TRITON_MODEL_REPOSITORY}}/shared_models" }}
  }},
  {{
    key: "COMFYUI_PATH"
    value: {{ string_value: "${{TRITON_MODEL_REPOSITORY}}/shared_comfyui" }}
  }}
]
'''
    return config

def main():
    """Generate all Triton config files."""
    services = {
        "latent_encoder": generate_latent_encoder_config,
        "text_encoder": generate_text_encoder_config,
        "sampling": generate_sampling_config,
        "decoding": generate_decoding_config,
    }
    
    repo_path = Path(__file__).parent / "triton_model_repository"
    repo_path.mkdir(exist_ok=True)
    
    print("=" * 60)
    print("Generating Triton Config Files from Phase 2 Test Results")
    print("=" * 60)
    print()
    
    for service_name, generator_func in services.items():
        try:
            print(f"Processing {service_name}...")
            data = load_test_results(service_name)
            config_content = generator_func(data)
            
            # Write config file
            service_dir = repo_path / service_name
            service_dir.mkdir(exist_ok=True)
            config_path = service_dir / "config.pbtxt"
            
            with open(config_path, 'w') as f:
                f.write(config_content)
            
            print(f"  ✓ Generated: {config_path}")
            
        except Exception as e:
            print(f"  ✗ Error processing {service_name}: {e}")
            import traceback
            traceback.print_exc()
    
    print()
    print("=" * 60)
    print("Config generation complete!")
    print(f"Config files written to: {repo_path}")
    print("=" * 60)

if __name__ == "__main__":
    main()

