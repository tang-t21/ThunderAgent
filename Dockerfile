FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:${PATH} \
    HF_HOME=/workspace/.cache/huggingface \
    VLLM_WORKER_MULTIPROC_METHOD=spawn \
    NO_PROXY=127.0.0.1,localhost \
    no_proxy=127.0.0.1,localhost

ENV http_proxy=http://10.51.6.1:6890 \
    https_proxy=http://10.51.6.1:6890

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python-is-python3 \
    build-essential \
    cmake \
    ninja-build \
    git \
    git-lfs \
    curl \
    ca-certificates \
    docker.io \
    numactl \
    libnuma-dev \
    libaio-dev \
    pciutils \
    && rm -rf /var/lib/apt/lists/* \
    && git lfs install

WORKDIR /workspace/ThunderAgent

# Copy only the parts needed for the ThunderAgent + mini-swe-agent ablation stack.
COPY pyproject.toml README.md /workspace/ThunderAgent/
COPY ThunderAgent /workspace/ThunderAgent/ThunderAgent
COPY examples/inference/mini-swe-agent /workspace/ThunderAgent/examples/inference/mini-swe-agent

RUN python -m venv "${VIRTUAL_ENV}" && \
    "${VIRTUAL_ENV}/bin/python" -m pip install --upgrade pip wheel uv && \
    "${VIRTUAL_ENV}/bin/python" -m pip install "setuptools==80.10.2" && \
    uv pip install --python "${VIRTUAL_ENV}/bin/python" \
        --index-url https://download.pytorch.org/whl/cu128 \
        torch==2.10.0+cu128 \
        torchvision==0.25.0+cu128 \
        torchaudio==2.10.0+cu128 && \
    uv pip install --python "${VIRTUAL_ENV}/bin/python" -e . && \
    uv pip install --python "${VIRTUAL_ENV}/bin/python" vllm && \
    uv pip install --python "${VIRTUAL_ENV}/bin/python" -e examples/inference/mini-swe-agent && \
    uv pip install --python "${VIRTUAL_ENV}/bin/python" datasets huggingface_hub

EXPOSE 8000 8100

# Mount the host Docker socket at runtime so mini-swe-agent can launch SWE-bench containers:
#   -v /var/run/docker.sock:/var/run/docker.sock
CMD ["/bin/bash"]
