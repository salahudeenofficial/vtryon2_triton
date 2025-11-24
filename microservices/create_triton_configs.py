#!/usr/bin/env python3
"""
Generate Triton config.pbtxt files from Phase 2 test results.

This script reads TRITON_CONFIG_DATA.json files from test_results/ and generates
config.pbtxt files for each service and the ensemble model.

Usage:
    python create_triton_configs.py
"""

import json
import os
from pathlib import Path
from typing import Dict, Any, List

# Service names
SERVICES = ["latent_encoder", "text_encoder", "sampling", "decoding"]
ENSEMBLE_NAME = "vtryon_pipeline"

# Triton repository path
TRITON_REPO = Path("triton_model_repository")
TEST_RESULTS = Path("test_results")


def load_test_results(service: str) -> Dict[str, Any]:
    """Load TRITON_CONFIG_DATA.json for a service."""
    config_file = TEST_RESULTS / service / "TRITON_CONFIG_DATA.json"
    if not config_file.exists():
        raise FileNotFoundError(f"Test results not found: {config_file}")
    
    with open(config_file, 'r') as f:
        return json.load(f)


def shape_to_dim(shape: List[int]) -> str:
    """Convert shape list to Triton dim format."""
    dims = []
    for dim in shape:
        if dim == -1:
            dims.append("-1")  # Dynamic dimension
        else:
            dims.append(str(dim))
    return ", ".join(dims)


def dtype_to_triton_type(dtype: str) -> str:
    """Convert PyTorch dtype to Triton type."""
    dtype_map = {
        "torch.float32": "TYPE_FP32",
        "torch.float16": "TYPE_FP16",
        "torch.int64": "TYPE_INT64",
        "torch.int32": "TYPE_INT32",
        "torch.uint8": "TYPE_UINT8",
        "TYPE_FP32": "TYPE_FP32",
        "TYPE_FP16": "TYPE_FP16",
        "TYPE_INT64": "TYPE_INT64",
        "TYPE_INT32": "TYPE_INT32",
    }
    return dtype_map.get(dtype, "TYPE_FP32")


def generate_latent_encoder_config(data: Dict[str, Any]) -> str:
    """Generate config.pbtxt for latent_encoder."""
    tensor_info = data["tensor_info"]
    batch_config = data.get("batch_config", {})
    triton_config = data.get("triton_config", {})
    
    output = tensor_info["output"]
    max_batch_size = batch_config.get("max_batch_size", 1)
    instance_count = triton_config.get("recommended_instance_count", 1)
    
    config = f'''name: "latent_encoder"
backend: "python"
max_batch_size: {max_batch_size}

input {{
  name: "image_path"
  data_type: TYPE_STRING
  dims: [ -1 ]
}}

output {{
  name: "latent"
  data_type: {dtype_to_triton_type(output.get("data_type", "torch.float32"))}
  dims: [ {shape_to_dim(output["shape"][1:])} ]
}}

instance_group [
  {{
    count: {instance_count}
    kind: KIND_GPU
  }}
]
'''
    return config


def generate_text_encoder_config(data: Dict[str, Any]) -> str:
    """Generate config.pbtxt for text_encoder."""
    tensor_info = data["tensor_info"]
    batch_config = data.get("batch_config", {})
    triton_config = data.get("triton_config", {})
    
    inputs = tensor_info["inputs"]
    outputs = tensor_info["outputs"]
    max_batch_size = batch_config.get("max_batch_size", 1)
    instance_count = triton_config.get("recommended_instance_count", 1)
    
    config = f'''name: "text_encoder"
backend: "python"
max_batch_size: {max_batch_size}

input [
  {{
    name: "image1_path"
    data_type: TYPE_STRING
    dims: [ -1 ]
  }},
  {{
    name: "image2_path"
    data_type: TYPE_STRING
    dims: [ -1 ]
  }},
  {{
    name: "prompt"
    data_type: TYPE_STRING
    dims: [ -1 ]
  }}
]

output [
  {{
    name: "positive_encoding"
    data_type: {dtype_to_triton_type(outputs["positive_encoding"].get("data_type", "torch.float32"))}
    dims: [ {shape_to_dim(outputs["positive_encoding"]["shape"][1:])} ]
  }},
  {{
    name: "negative_encoding"
    data_type: {dtype_to_triton_type(outputs["negative_encoding"].get("data_type", "torch.float32"))}
    dims: [ {shape_to_dim(outputs["negative_encoding"]["shape"][1:])} ]
  }}
]

instance_group [
  {{
    count: {instance_count}
    kind: KIND_GPU
  }}
]
'''
    return config


def generate_sampling_config(data: Dict[str, Any], all_data: Dict[str, Dict[str, Any]]) -> str:
    """Generate config.pbtxt for sampling."""
    tensor_info = data["tensor_info"]
    batch_config = data.get("batch_config", {})
    triton_config = data.get("triton_config", {})
    
    inputs = tensor_info.get("inputs", {})
    output = tensor_info.get("output", {})
    max_batch_size = batch_config.get("max_batch_size", 1)
    instance_count = triton_config.get("recommended_instance_count", 1)
    
    # Get tensor shapes from previous services
    # positive_encoding from text_encoder output
    text_encoder_outputs = all_data["text_encoder"]["tensor_info"]["outputs"]
    pos_shape = text_encoder_outputs["positive_encoding"]["shape"]
    neg_shape = text_encoder_outputs["negative_encoding"]["shape"]
    
    # latent_image from latent_encoder output
    latent_encoder_output = all_data["latent_encoder"]["tensor_info"]["output"]
    latent_shape = latent_encoder_output["shape"]
    
    # Build input list
    input_configs = [
        f'''  {{
    name: "positive_encoding"
    data_type: {dtype_to_triton_type(text_encoder_outputs["positive_encoding"].get("data_type", "torch.float32"))}
    dims: [ {shape_to_dim(pos_shape[1:])} ]
  }}''',
        f'''  {{
    name: "negative_encoding"
    data_type: {dtype_to_triton_type(text_encoder_outputs["negative_encoding"].get("data_type", "torch.float32"))}
    dims: [ {shape_to_dim(neg_shape[1:])} ]
  }}''',
        f'''  {{
    name: "latent_image"
    data_type: {dtype_to_triton_type(latent_encoder_output.get("data_type", "torch.float32"))}
    dims: [ {shape_to_dim(latent_shape[1:])} ]
  }}''',
        f'''  {{
    name: "seed"
    data_type: TYPE_INT64
    dims: [ ]
  }}'''
    ]
    
    config = f'''name: "sampling"
backend: "python"
max_batch_size: {max_batch_size}

input [
{",".join(input_configs)}
]

output {{
  name: "sampled_latent"
  data_type: {dtype_to_triton_type(output.get("data_type", "torch.float32"))}
  dims: [ {shape_to_dim(output["shape"][1:])} ]
}}

instance_group [
  {{
    count: {instance_count}
    kind: KIND_GPU
  }}
]
'''
    return config


def generate_decoding_config(data: Dict[str, Any], all_data: Dict[str, Dict[str, Any]]) -> str:
    """Generate config.pbtxt for decoding."""
    tensor_info = data["tensor_info"]
    batch_config = data.get("batch_config", {})
    triton_config = data.get("triton_config", {})
    
    output = tensor_info.get("output", {})
    max_batch_size = batch_config.get("max_batch_size", 1)
    instance_count = triton_config.get("recommended_instance_count", 1)
    
    # Get latent shape from sampling output
    sampling_output = all_data["sampling"]["tensor_info"]["output"]
    latent_shape = sampling_output["shape"]
    
    config = f'''name: "decoding"
backend: "python"
max_batch_size: {max_batch_size}

input {{
  name: "latent"
  data_type: {dtype_to_triton_type(sampling_output.get("data_type", "torch.float32"))}
  dims: [ {shape_to_dim(latent_shape[1:])} ]
}}

output {{
  name: "image"
  data_type: {dtype_to_triton_type(output.get("data_type", "torch.float32"))}
  dims: [ {shape_to_dim(output["shape"][1:])} ]
}}

instance_group [
  {{
    count: {instance_count}
    kind: KIND_GPU
  }}
]
'''
    return config


def generate_ensemble_config(all_data: Dict[str, Dict[str, Any]]) -> str:
    """Generate config.pbtxt for ensemble model."""
    text_encoder = all_data["text_encoder"]
    latent_encoder = all_data["latent_encoder"]
    sampling = all_data["sampling"]
    decoding = all_data["decoding"]
    
    config = f'''name: "vtryon_pipeline"
platform: "ensemble"
max_batch_size: 1

input [
  {{
    name: "image1_path"
    data_type: TYPE_STRING
    dims: [ -1 ]
  }},
  {{
    name: "image2_path"
    data_type: TYPE_STRING
    dims: [ -1 ]
  }},
  {{
    name: "prompt"
    data_type: TYPE_STRING
    dims: [ -1 ]
  }}
]

output {{
  name: "output_image"
  data_type: {dtype_to_triton_type(decoding["tensor_info"]["output"].get("data_type", "torch.float32"))}
  dims: [ {shape_to_dim(decoding["tensor_info"]["output"]["shape"][1:])} ]
}}

ensemble_scheduling {{
  step [
    {{
      model_name: "latent_encoder"
      model_version: -1
      input_map {{
        key: "image_path"
        value: "image1_path"
      }}
      output_map {{
        key: "latent"
        value: "latent_encoded"
      }}
    }},
    {{
      model_name: "text_encoder"
      model_version: -1
      input_map {{
        key: "image1_path"
        value: "image1_path"
      }}
      input_map {{
        key: "image2_path"
        value: "image2_path"
      }}
      input_map {{
        key: "prompt"
        value: "prompt"
      }}
      output_map {{
        key: "positive_encoding"
        value: "positive_encoding"
      }}
      output_map {{
        key: "negative_encoding"
        value: "negative_encoding"
      }}
    }},
    {{
      model_name: "sampling"
      model_version: -1
      input_map {{
        key: "positive_encoding"
        value: "positive_encoding"
      }}
      input_map {{
        key: "negative_encoding"
        value: "negative_encoding"
      }}
      input_map {{
        key: "latent_image"
        value: "latent_encoded"
      }}
      output_map {{
        key: "sampled_latent"
        value: "sampled_latent"
      }}
    }},
    {{
      model_name: "decoding"
      model_version: -1
      input_map {{
        key: "latent"
        value: "sampled_latent"
      }}
      output_map {{
        key: "image"
        value: "output_image"
      }}
    }}
  ]
}}
'''
    return config


def main():
    """Generate all config.pbtxt files."""
    print("=" * 60)
    print("Generating Triton Config Files from Test Results")
    print("=" * 60)
    print()
    
    # Check test results exist
    if not TEST_RESULTS.exists():
        print(f"❌ Error: Test results directory not found: {TEST_RESULTS}")
        print(f"   Please copy test results from /home/fashionx/Desktop/test_results")
        print(f"   to microservices/test_results/")
        return 1
    
    # Load all test results
    all_data = {}
    for service in SERVICES:
        try:
            all_data[service] = load_test_results(service)
            print(f"✓ Loaded test results for {service}")
        except FileNotFoundError as e:
            print(f"❌ Error: {e}")
            return 1
    
    # Create Triton repository structure
    TRITON_REPO.mkdir(exist_ok=True)
    
    # Generate configs for each service
    for service in SERVICES:
        service_dir = TRITON_REPO / service
        service_dir.mkdir(exist_ok=True)
        
        if service == "latent_encoder":
            config_content = generate_latent_encoder_config(all_data[service])
        elif service == "text_encoder":
            config_content = generate_text_encoder_config(all_data[service])
        elif service == "sampling":
            config_content = generate_sampling_config(all_data[service], all_data)
        elif service == "decoding":
            config_content = generate_decoding_config(all_data[service], all_data)
        else:
            raise ValueError(f"Unknown service: {service}")
        
        config_file = service_dir / "config.pbtxt"
        
        with open(config_file, 'w') as f:
            f.write(config_content)
        
        print(f"✓ Generated {config_file}")
    
    # Generate ensemble config
    ensemble_dir = TRITON_REPO / ENSEMBLE_NAME
    ensemble_dir.mkdir(exist_ok=True)
    
    ensemble_config = generate_ensemble_config(all_data)
    ensemble_file = ensemble_dir / "config.pbtxt"
    
    with open(ensemble_file, 'w') as f:
        f.write(ensemble_config)
    
    print(f"✓ Generated {ensemble_file}")
    
    print()
    print("=" * 60)
    print("✅ All config files generated successfully!")
    print("=" * 60)
    print()
    print("Generated files:")
    for service in SERVICES:
        print(f"  - triton_model_repository/{service}/config.pbtxt")
    print(f"  - triton_model_repository/{ENSEMBLE_NAME}/config.pbtxt")
    print()
    print("Next steps:")
    print("  1. Review generated config files")
    print("  2. Verify tensor shapes match test results")
    print("  3. Proceed to Phase 5: Python Backend Implementation")
    
    return 0


if __name__ == "__main__":
    exit(main())


Generate Triton config.pbtxt files from Phase 2 test results.

This script reads TRITON_CONFIG_DATA.json files from test_results/ and generates
config.pbtxt files for each service and the ensemble model.

Usage:
    python create_triton_configs.py
"""

import json
import os
from pathlib import Path
from typing import Dict, Any, List

# Service names
SERVICES = ["latent_encoder", "text_encoder", "sampling", "decoding"]
ENSEMBLE_NAME = "vtryon_pipeline"

# Triton repository path
TRITON_REPO = Path("triton_model_repository")
TEST_RESULTS = Path("test_results")


def load_test_results(service: str) -> Dict[str, Any]:
    """Load TRITON_CONFIG_DATA.json for a service."""
    config_file = TEST_RESULTS / service / "TRITON_CONFIG_DATA.json"
    if not config_file.exists():
        raise FileNotFoundError(f"Test results not found: {config_file}")
    
    with open(config_file, 'r') as f:
        return json.load(f)


def shape_to_dim(shape: List[int]) -> str:
    """Convert shape list to Triton dim format."""
    dims = []
    for dim in shape:
        if dim == -1:
            dims.append("-1")  # Dynamic dimension
        else:
            dims.append(str(dim))
    return ", ".join(dims)


def dtype_to_triton_type(dtype: str) -> str:
    """Convert PyTorch dtype to Triton type."""
    dtype_map = {
        "torch.float32": "TYPE_FP32",
        "torch.float16": "TYPE_FP16",
        "torch.int64": "TYPE_INT64",
        "torch.int32": "TYPE_INT32",
        "torch.uint8": "TYPE_UINT8",
        "TYPE_FP32": "TYPE_FP32",
        "TYPE_FP16": "TYPE_FP16",
        "TYPE_INT64": "TYPE_INT64",
        "TYPE_INT32": "TYPE_INT32",
    }
    return dtype_map.get(dtype, "TYPE_FP32")


def generate_latent_encoder_config(data: Dict[str, Any]) -> str:
    """Generate config.pbtxt for latent_encoder."""
    tensor_info = data["tensor_info"]
    batch_config = data.get("batch_config", {})
    triton_config = data.get("triton_config", {})
    
    output = tensor_info["output"]
    max_batch_size = batch_config.get("max_batch_size", 1)
    instance_count = triton_config.get("recommended_instance_count", 1)
    
    config = f'''name: "latent_encoder"
backend: "python"
max_batch_size: {max_batch_size}

input {{
  name: "image_path"
  data_type: TYPE_STRING
  dims: [ -1 ]
}}

output {{
  name: "latent"
  data_type: {dtype_to_triton_type(output.get("data_type", "torch.float32"))}
  dims: [ {shape_to_dim(output["shape"][1:])} ]
}}

instance_group [
  {{
    count: {instance_count}
    kind: KIND_GPU
  }}
]
'''
    return config


def generate_text_encoder_config(data: Dict[str, Any]) -> str:
    """Generate config.pbtxt for text_encoder."""
    tensor_info = data["tensor_info"]
    batch_config = data.get("batch_config", {})
    triton_config = data.get("triton_config", {})
    
    inputs = tensor_info["inputs"]
    outputs = tensor_info["outputs"]
    max_batch_size = batch_config.get("max_batch_size", 1)
    instance_count = triton_config.get("recommended_instance_count", 1)
    
    config = f'''name: "text_encoder"
backend: "python"
max_batch_size: {max_batch_size}

input [
  {{
    name: "image1_path"
    data_type: TYPE_STRING
    dims: [ -1 ]
  }},
  {{
    name: "image2_path"
    data_type: TYPE_STRING
    dims: [ -1 ]
  }},
  {{
    name: "prompt"
    data_type: TYPE_STRING
    dims: [ -1 ]
  }}
]

output [
  {{
    name: "positive_encoding"
    data_type: {dtype_to_triton_type(outputs["positive_encoding"].get("data_type", "torch.float32"))}
    dims: [ {shape_to_dim(outputs["positive_encoding"]["shape"][1:])} ]
  }},
  {{
    name: "negative_encoding"
    data_type: {dtype_to_triton_type(outputs["negative_encoding"].get("data_type", "torch.float32"))}
    dims: [ {shape_to_dim(outputs["negative_encoding"]["shape"][1:])} ]
  }}
]

instance_group [
  {{
    count: {instance_count}
    kind: KIND_GPU
  }}
]
'''
    return config


def generate_sampling_config(data: Dict[str, Any], all_data: Dict[str, Dict[str, Any]]) -> str:
    """Generate config.pbtxt for sampling."""
    tensor_info = data["tensor_info"]
    batch_config = data.get("batch_config", {})
    triton_config = data.get("triton_config", {})
    
    inputs = tensor_info.get("inputs", {})
    output = tensor_info.get("output", {})
    max_batch_size = batch_config.get("max_batch_size", 1)
    instance_count = triton_config.get("recommended_instance_count", 1)
    
    # Get tensor shapes from previous services
    # positive_encoding from text_encoder output
    text_encoder_outputs = all_data["text_encoder"]["tensor_info"]["outputs"]
    pos_shape = text_encoder_outputs["positive_encoding"]["shape"]
    neg_shape = text_encoder_outputs["negative_encoding"]["shape"]
    
    # latent_image from latent_encoder output
    latent_encoder_output = all_data["latent_encoder"]["tensor_info"]["output"]
    latent_shape = latent_encoder_output["shape"]
    
    # Build input list
    input_configs = [
        f'''  {{
    name: "positive_encoding"
    data_type: {dtype_to_triton_type(text_encoder_outputs["positive_encoding"].get("data_type", "torch.float32"))}
    dims: [ {shape_to_dim(pos_shape[1:])} ]
  }}''',
        f'''  {{
    name: "negative_encoding"
    data_type: {dtype_to_triton_type(text_encoder_outputs["negative_encoding"].get("data_type", "torch.float32"))}
    dims: [ {shape_to_dim(neg_shape[1:])} ]
  }}''',
        f'''  {{
    name: "latent_image"
    data_type: {dtype_to_triton_type(latent_encoder_output.get("data_type", "torch.float32"))}
    dims: [ {shape_to_dim(latent_shape[1:])} ]
  }}''',
        f'''  {{
    name: "seed"
    data_type: TYPE_INT64
    dims: [ ]
  }}'''
    ]
    
    config = f'''name: "sampling"
backend: "python"
max_batch_size: {max_batch_size}

input [
{",".join(input_configs)}
]

output {{
  name: "sampled_latent"
  data_type: {dtype_to_triton_type(output.get("data_type", "torch.float32"))}
  dims: [ {shape_to_dim(output["shape"][1:])} ]
}}

instance_group [
  {{
    count: {instance_count}
    kind: KIND_GPU
  }}
]
'''
    return config


def generate_decoding_config(data: Dict[str, Any], all_data: Dict[str, Dict[str, Any]]) -> str:
    """Generate config.pbtxt for decoding."""
    tensor_info = data["tensor_info"]
    batch_config = data.get("batch_config", {})
    triton_config = data.get("triton_config", {})
    
    output = tensor_info.get("output", {})
    max_batch_size = batch_config.get("max_batch_size", 1)
    instance_count = triton_config.get("recommended_instance_count", 1)
    
    # Get latent shape from sampling output
    sampling_output = all_data["sampling"]["tensor_info"]["output"]
    latent_shape = sampling_output["shape"]
    
    config = f'''name: "decoding"
backend: "python"
max_batch_size: {max_batch_size}

input {{
  name: "latent"
  data_type: {dtype_to_triton_type(sampling_output.get("data_type", "torch.float32"))}
  dims: [ {shape_to_dim(latent_shape[1:])} ]
}}

output {{
  name: "image"
  data_type: {dtype_to_triton_type(output.get("data_type", "torch.float32"))}
  dims: [ {shape_to_dim(output["shape"][1:])} ]
}}

instance_group [
  {{
    count: {instance_count}
    kind: KIND_GPU
  }}
]
'''
    return config


def generate_ensemble_config(all_data: Dict[str, Dict[str, Any]]) -> str:
    """Generate config.pbtxt for ensemble model."""
    text_encoder = all_data["text_encoder"]
    latent_encoder = all_data["latent_encoder"]
    sampling = all_data["sampling"]
    decoding = all_data["decoding"]
    
    config = f'''name: "vtryon_pipeline"
platform: "ensemble"
max_batch_size: 1

input [
  {{
    name: "image1_path"
    data_type: TYPE_STRING
    dims: [ -1 ]
  }},
  {{
    name: "image2_path"
    data_type: TYPE_STRING
    dims: [ -1 ]
  }},
  {{
    name: "prompt"
    data_type: TYPE_STRING
    dims: [ -1 ]
  }}
]

output {{
  name: "output_image"
  data_type: {dtype_to_triton_type(decoding["tensor_info"]["output"].get("data_type", "torch.float32"))}
  dims: [ {shape_to_dim(decoding["tensor_info"]["output"]["shape"][1:])} ]
}}

ensemble_scheduling {{
  step [
    {{
      model_name: "latent_encoder"
      model_version: -1
      input_map {{
        key: "image_path"
        value: "image1_path"
      }}
      output_map {{
        key: "latent"
        value: "latent_encoded"
      }}
    }},
    {{
      model_name: "text_encoder"
      model_version: -1
      input_map {{
        key: "image1_path"
        value: "image1_path"
      }}
      input_map {{
        key: "image2_path"
        value: "image2_path"
      }}
      input_map {{
        key: "prompt"
        value: "prompt"
      }}
      output_map {{
        key: "positive_encoding"
        value: "positive_encoding"
      }}
      output_map {{
        key: "negative_encoding"
        value: "negative_encoding"
      }}
    }},
    {{
      model_name: "sampling"
      model_version: -1
      input_map {{
        key: "positive_encoding"
        value: "positive_encoding"
      }}
      input_map {{
        key: "negative_encoding"
        value: "negative_encoding"
      }}
      input_map {{
        key: "latent_image"
        value: "latent_encoded"
      }}
      output_map {{
        key: "sampled_latent"
        value: "sampled_latent"
      }}
    }},
    {{
      model_name: "decoding"
      model_version: -1
      input_map {{
        key: "latent"
        value: "sampled_latent"
      }}
      output_map {{
        key: "image"
        value: "output_image"
      }}
    }}
  ]
}}
'''
    return config


def main():
    """Generate all config.pbtxt files."""
    print("=" * 60)
    print("Generating Triton Config Files from Test Results")
    print("=" * 60)
    print()
    
    # Check test results exist
    if not TEST_RESULTS.exists():
        print(f"❌ Error: Test results directory not found: {TEST_RESULTS}")
        print(f"   Please copy test results from /home/fashionx/Desktop/test_results")
        print(f"   to microservices/test_results/")
        return 1
    
    # Load all test results
    all_data = {}
    for service in SERVICES:
        try:
            all_data[service] = load_test_results(service)
            print(f"✓ Loaded test results for {service}")
        except FileNotFoundError as e:
            print(f"❌ Error: {e}")
            return 1
    
    # Create Triton repository structure
    TRITON_REPO.mkdir(exist_ok=True)
    
    # Generate configs for each service
    for service in SERVICES:
        service_dir = TRITON_REPO / service
        service_dir.mkdir(exist_ok=True)
        
        if service == "latent_encoder":
            config_content = generate_latent_encoder_config(all_data[service])
        elif service == "text_encoder":
            config_content = generate_text_encoder_config(all_data[service])
        elif service == "sampling":
            config_content = generate_sampling_config(all_data[service], all_data)
        elif service == "decoding":
            config_content = generate_decoding_config(all_data[service], all_data)
        else:
            raise ValueError(f"Unknown service: {service}")
        
        config_file = service_dir / "config.pbtxt"
        
        with open(config_file, 'w') as f:
            f.write(config_content)
        
        print(f"✓ Generated {config_file}")
    
    # Generate ensemble config
    ensemble_dir = TRITON_REPO / ENSEMBLE_NAME
    ensemble_dir.mkdir(exist_ok=True)
    
    ensemble_config = generate_ensemble_config(all_data)
    ensemble_file = ensemble_dir / "config.pbtxt"
    
    with open(ensemble_file, 'w') as f:
        f.write(ensemble_config)
    
    print(f"✓ Generated {ensemble_file}")
    
    print()
    print("=" * 60)
    print("✅ All config files generated successfully!")
    print("=" * 60)
    print()
    print("Generated files:")
    for service in SERVICES:
        print(f"  - triton_model_repository/{service}/config.pbtxt")
    print(f"  - triton_model_repository/{ENSEMBLE_NAME}/config.pbtxt")
    print()
    print("Next steps:")
    print("  1. Review generated config files")
    print("  2. Verify tensor shapes match test results")
    print("  3. Proceed to Phase 5: Python Backend Implementation")
    
    return 0


if __name__ == "__main__":
    exit(main())

