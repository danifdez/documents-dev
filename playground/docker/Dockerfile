FROM python:3.12-slim

WORKDIR /app

RUN adduser --disabled-password --gecos '' appuser

RUN apt-get update && apt-get install -y build-essential cmake ninja-build python3-dev git libomp-dev libcurl4-openssl-dev pkg-config ca-certificates && rm -rf /var/lib/apt/lists/*

RUN pip3 install --upgrade pip
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

COPY . .

# Build and install standalone llama.cpp (ggml-based) so binaries persist in the image
RUN git clone https://github.com/ggerganov/llama.cpp.git /tmp/llama.cpp \
    && cd /tmp/llama.cpp \
    && mkdir -p build && cd build \
    && cmake .. \
    && make -j$(nproc) \
    && mkdir -p /usr/local/lib /usr/local/bin \
    && cp -a ../build/bin/* /usr/local/bin/ || true \
    && cp -a ../build/bin/lib*.so* /usr/local/lib/ || true \
    && ldconfig || true

USER appuser

EXPOSE 8888

CMD ["jupyter", "notebook", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root", "--NotebookApp.token=''"]