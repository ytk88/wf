#!/bin/bash
set -e

source /venv/main/bin/activate

WORKSPACE=${WORKSPACE:-/workspace}
COMFYUI_DIR=${WORKSPACE}/ComfyUI

echo "=== Vast.ai ComfyUI provisioning ==="

# ─────────────────────────────────────────────
# 1. Clone ComfyUI
# ─────────────────────────────────────────────
if [[ ! -d "${COMFYUI_DIR}" ]]; then
    echo "Cloning ComfyUI..."
    git clone https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
fi

cd "${COMFYUI_DIR}"

# ─────────────────────────────────────────────
# 2. Install base requirements
# ─────────────────────────────────────────────
if [[ -f requirements.txt ]]; then
    pip install --no-cache-dir -r requirements.txt
fi

# ─────────────────────────────────────────────
# 3. CONFIG (Добавлены недостающие ноды)
# ─────────────────────────────────────────────
NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/kijai/ComfyUI-WanVideoWrapper"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
    "https://github.com/Fannovel16/comfyui_controlnet_aux"
    "https://github.com/Derfuu/Derfuu_ComfyUI_ModdedNodes"
)

WAN_JSON_MODELS=(
    "https://huggingface.co/diego97martinez/video_baile_stady_dancer/resolve/main/WAN2-1-SteadyDancer-FP8.json"
)

WAN_FP8_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/SteadyDancer/Wan21_SteadyDancer_fp8_e4m3fn_scaled_KJ.safetensors"
)

LORA_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"
)

VAE_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/a328a632b80d44062fda7df9b6b1a7b2c3a5cf2c/Wan2_1_VAE_bf16.safetensors"
)

CLIP_VISION_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"
)

TEXT_ENCODER_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp16.safetensors"
)

UPSCALE_MODELS=(
    "https://raw.githubusercontent.com/gamefurius32-lgtm/upsclane1xskin/main/1xSkinContrast-SuperUltraCompact%20(3).pth"
)

# ─────────────────────────────────────────────
# 4. FUNCTIONS
# ─────────────────────────────────────────────
download_files() {
    local dir="$1"
    shift
    mkdir -p "$dir"

    for url in "$@"; do
        echo "Downloading: $url"
        if [[ -n "$HF_TOKEN" && "$url" =~ huggingface.co ]]; then
            wget --header="Authorization: Bearer $HF_TOKEN" \
                 -nc --content-disposition -P "$dir" "$url"
        else
            wget -nc --content-disposition -P "$dir" "$url"
        fi
    done
}

# ─────────────────────────────────────────────
# 5. Custom nodes (С автоматической установкой pip)
# ─────────────────────────────────────────────
mkdir -p custom_nodes

for repo in "${NODES[@]}"; do
    dir_name=$(basename "$repo")
    path="custom_nodes/${dir_name}"
    
    if [[ -d "$path" ]]; then
        echo "Updating node: $dir_name"
        (cd "$path" && git pull)
    else
        echo "Cloning node: $dir_name"
        git clone "$repo" "$path" --recursive
    fi

    # Автоматическая установка зависимостей для каждой ноды
    if [[ -f "${path}/requirements.txt" ]]; then
        echo "Installing requirements for $dir_name..."
        pip install --no-cache-dir -r "${path}/requirements.txt"
    fi
done

# ─────────────────────────────────────────────
# 6. Download models
# ─────────────────────────────────────────────
download_files "models/diffusion_models" "${WAN_JSON_MODELS[@]}"
download_files "models/diffusion_models" "${WAN_FP8_MODELS[@]}"
download_files "models/loras" "${LORA_MODELS[@]}"
download_files "models/vae" "${VAE_MODELS[@]}"
download_files "models/clip_vision" "${CLIP_VISION_MODELS[@]}"
download_files "models/text_encoders" "${TEXT_ENCODER_MODELS[@]}"
download_files "models/upscale_models" "${UPSCALE_MODELS[@]}"

# ─────────────────────────────────────────────
# 7. Launch
# ─────────────────────────────────────────────
echo "=== Starting ComfyUI ==="
# Используем порт из конфига Vast или стандартный 8188
python main.py --listen 0.0.0.0 --port 8188
