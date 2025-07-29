FROM python:3.11-slim

WORKDIR /app

RUN adduser --disabled-password --gecos '' appuser

RUN apt-get update && apt-get install -y build-essential cmake ninja-build python3-dev git && rm -rf /var/lib/apt/lists/*

RUN pip3 install --upgrade pip
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

COPY . .

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8888

CMD ["jupyter", "notebook", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root", "--NotebookApp.token=''"]