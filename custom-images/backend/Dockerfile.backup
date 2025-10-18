# ============================================
# Bisheng Backend Enterprise - Custom Image
# ============================================
ARG BASE_IMAGE=dataelement/bisheng-backend:v2.2.0-beta2
FROM ${BASE_IMAGE}

LABEL maintainer="Bisheng Enterprise Team"
LABEL version="2.0-enterprise"
LABEL description="Enhanced Bisheng Backend with PostgreSQL, PyTorch, and Advanced ML"

# ============================================
# Environment Variables
# ============================================
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    USER_AGENT="Bisheng-Enterprise/2.0" \
    PYTHONWARNINGS="ignore::DeprecationWarning" \
    TRANSFORMERS_CACHE=/app/cache/transformers \
    HF_HOME=/app/cache/huggingface \
    TORCH_HOME=/app/cache/torch

# ============================================
# System Dependencies
# ============================================
USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build tools
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    # PostgreSQL client
    postgresql-client \
    libpq-dev \
    # Image processing
    libimage-exiftool-perl \
    libmagic1 \
    poppler-utils \
    tesseract-ocr \
    tesseract-ocr-eng \
    tesseract-ocr-ara \
    tesseract-ocr-chi-sim \
    tesseract-ocr-fra \
    tesseract-ocr-deu \
    tesseract-ocr-spa \
    # Document processing
    pandoc \
    libreoffice \
    # PDF tools
    ghostscript \
    # Network tools
    curl \
    wget \
    netcat \
    # Utilities
    git \
    unzip \
    vim \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# ============================================
# Python Dependencies - ML & Data Science
# ============================================
RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir \
    # PostgreSQL adapter
    psycopg2-binary==2.9.9 \
    asyncpg==0.29.0 \
    # PyTorch (CPU version for production)
    torch==2.1.2 \
    torchvision==0.16.2 \
    torchaudio==2.1.2 \
    --index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir \
    # Transformers & NLP
    transformers==4.36.2 \
    sentence-transformers==2.3.1 \
    tokenizers==0.15.0 \
    # LangChain ecosystem
    langchain==0.1.0 \
    langchain-community==0.0.10 \
    langchain-core==0.1.10 \
    langchain-openai==0.0.2 \
    # Vector stores
    pymilvus==2.3.5 \
    elasticsearch==8.12.0 \
    # AutoML
    "flaml[automl]"==2.1.1 \
    # Document processing
    python-docx==1.1.0 \
    python-pptx==0.6.23 \
    openpyxl==3.1.2 \
    xlrd==2.0.1 \
    PyPDF2==3.0.1 \
    pdfplumber==0.10.3 \
    pdfminer.six==20221105 \
    pypandoc==1.12 \
    # OCR
    pytesseract==0.3.10 \
    pdf2image==1.17.0 \
    Pillow==10.2.0 \
    # Data processing
    pandas==2.1.4 \
    numpy==1.26.3 \
    scipy==1.11.4 \
    # Computer vision
    opencv-python-headless==4.9.0.80 \
    # Audio processing
    librosa==0.10.1 \
    soundfile==0.12.1 \
    # Web scraping
    beautifulsoup4==4.12.2 \
    lxml==5.1.0 \
    # API clients
    openai==1.7.2 \
    anthropic==0.8.1 \
    google-generativeai==0.3.2 \
    # Monitoring & Observability
    prometheus-client==0.19.0 \
    opentelemetry-api==1.22.0 \
    opentelemetry-sdk==1.22.0 \
    opentelemetry-instrumentation-fastapi==0.43b0 \
    # Performance
    uvloop==0.19.0 \
    httptools==0.6.1 \
    orjson==3.9.12 \
    # Security
    cryptography==42.0.0 \
    python-jose[cryptography]==3.3.0 \
    passlib[bcrypt]==1.7.4 \
    # Validation
    pydantic==2.5.3 \
    pydantic-settings==2.1.0 \
    # Task queue
    celery[redis]==5.3.4 \
    flower==2.0.1 \
    # Caching
    redis==5.0.1 \
    hiredis==2.3.2 \
    # Utilities
    python-multipart==0.0.6 \
    python-magic==0.4.27 \
    chardet==5.2.0 \
    tqdm==4.66.1 \
    tenacity==8.2.3 \
    # Chinese text processing
    jieba==0.42.1 \
    pypinyin==0.50.0

# ============================================
# Download Pre-trained Models (Optional)
# ============================================
# Uncomment if you want to pre-download models
# RUN python -c "from sentence_transformers import SentenceTransformer; \
#     SentenceTransformer('paraphrase-multilingual-MiniLM-L12-v2').save('/app/cache/models/sentence-transformers')"

# ============================================
# Create necessary directories
# ============================================
RUN mkdir -p /app/cache/{transformers,huggingface,torch,models} \
    /app/logs \
    /app/uploads \
    /app/temp && \
    chmod -R 777 /app/cache /app/logs /app/uploads /app/temp

# ============================================
# Health Check Script
# ============================================
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

# ============================================
# Entrypoint Script
# ============================================
COPY entrypoint-enterprise.sh /usr/local/bin/entrypoint-enterprise.sh
RUN chmod +x /usr/local/bin/entrypoint-enterprise.sh

# ============================================
# User & Permissions
# ============================================
RUN useradd -m -u 1000 -s /bin/bash bisheng && \
    chown -R bisheng:bisheng /app

USER bisheng

# ============================================
# Expose Ports
# ============================================
EXPOSE 7860

# ============================================
# Health Check
# ============================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# ============================================
# Entrypoint
# ============================================
ENTRYPOINT ["/usr/local/bin/entrypoint-enterprise.sh"]
CMD ["api"]