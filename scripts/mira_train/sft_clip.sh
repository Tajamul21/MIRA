export OMP_NUM_THREADS=8
export NCCL_IB_DISABLE=0
export NCCL_IB_GID_INDEX=3
# export NCCL_SOCKET_IFNAME=eth0
export NCCL_DEBUG=INFO

LLM_VERSION="meta-llama/Meta-Llama-3-8B" 
LLM_VERSION_CLEAN="${LLM_VERSION//\//_}"
VISION_MODEL_VERSION="biomedclip"
VISION_MODEL_VERSION_CLEAN="${VISION_MODEL_VERSION//\//_}"

############### Pretrain ################

PROMPT_VERSION="llama_v3"

BASE_RUN_NAME="llavanext-${VISION_MODEL_VERSION_CLEAN}-${LLM_VERSION_CLEAN}-mlp2x_gelu-pretrain_blip558k_plain"
echo "BASE_RUN_NAME: ${BASE_RUN_NAME}"

MID_RUN_NAME="llava-onevision-${VISION_MODEL_VERSION_CLEAN}-${LLM_VERSION_CLEAN}-sft_stage_am9"

CKPT_PATH=$LLM_VERSION # this could also be the previous stage checkpoint

# ACCELERATE_CPU_AFFINITY=1 torchrun --nproc_per_node="${NUM_GPUS}" --nnodes="${NNODES}" --node_rank="${RANK}" --master_addr="${ADDR}" --master_port="${PORT}" \
# --mm_tunable_parts="mm_vision_tower,mm_mlp_adapter,mm_language_model" \
deepspeed llava/train/train_mem.py \
    --deepspeed scripts/zero2_offload.json \
    --model_name_or_path ${CKPT_PATH} \
    --version ${PROMPT_VERSION} \
    --data_path /home/jinhong.wang/workdir/dataset/llava_med_jsons/checked/instruct/llava_med_instruct_60k.json \
    --image_folder /home/jinhong.wang/workdir/dataset/llava_med/images \
    --pretrain_mm_mlp_adapter /home/jinhong.wang/workdir/checkpoints/pt-projector/llavamed-lnext-rag-biomedclip-llama3-8b/mm_projector.bin \
    --mm_tunable_parts="mm_vision_tower,mm_mlp_adapter,mm_language_model" \
    --mm_vision_tower_lr=2e-6 \
    --vision_tower ${VISION_MODEL_VERSION} \
    --mm_projector_type mlp2x_gelu \
    --mm_vision_select_layer -2 \
    --mm_use_im_start_end False \
    --mm_use_im_patch_token False \
    --group_by_modality_length True \
    --rag_enabled True \
    --rag_idx /home/jinhong.wang/workdir/database_rag/faiss_index_1222.idx \
    --rag_mdpath /home/jinhong.wang/workdir/database_rag/metadata_1222.csv \
    --rag_tokenizer all-MiniLM-L6-v2 \
    --rag_topk 5 \
    --query_rewrite_enabled False \
    --query_rewrite_host http://localhost:11434/api/chat \
    --query_rewrite_model mistral-small:22b \
    --image_aspect_ratio anyres \
    --image_grid_pinpoints "[(384, 768), (768, 384), (768, 768), (1152, 384), (384, 1152)]" \
    --mm_patch_merge_type spatial_unpad \
    --bf16 True \
    --run_name $MID_RUN_NAME \
    --output_dir "/home/jinhong.wang/workdir/checkpoints/ft-lmed-rag/${MID_RUN_NAME}" \
    --num_train_epochs 1 \
    --per_device_train_batch_size 1 \
    --per_device_eval_batch_size 1 \
    --gradient_accumulation_steps 32 \
    --evaluation_strategy "no" \
    --save_strategy "steps" \
    --save_steps 1000 \
    --save_total_limit 1 \
    --learning_rate 1e-5 \
    --weight_decay 0. \
    --warmup_ratio 0.03 \
    --lr_scheduler_type "cosine" \
    --logging_steps 1 \
    --tf32 True \
    --model_max_length 32768 \
    --gradient_checkpointing True \
    --dataloader_num_workers 16 \
    --lazy_preprocess True \
    --report_to wandb \
    --torch_compile True \
    --torch_compile_backend "inductor" \
    --dataloader_drop_last True \
    --attn_implementation sdpa

# You can delete the sdpa attn_implementation if you want to use flash attn
