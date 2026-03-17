# Playground

The playground is a Jupyter-based experimentation environment for prototyping document processing workflows. It includes ML/AI libraries (PyTorch, TensorFlow, LangChain, llama-cpp-python, etc.) and example notebooks for interacting with the backend API, databases, and AI models.

## Getting Started

### With Docker (recommended)

Start it using the `local` profile from the repository root:

```bash
docker compose up playground
```

Access the Jupyter interface at **http://localhost:8888**.

### Local

```bash
cd playground
pip install -r requirements.txt
jupyter notebook
```

## Example Notebooks

| Notebook               | Description                                    |
|------------------------|------------------------------------------------|
| `backend_call.ipynb`   | Test API calls to the backend service          |
| `database.ipynb`       | Interact with the PostgreSQL database directly |
| `huggingface.ipynb`    | Experiment with Hugging Face models            |
| `llama_cpp.ipynb`      | Test local LLM inference with llama-cpp        |
| `qdrant.ipynb`         | Interact with the Qdrant vector database       |

## Structure

```
playground/
├── docker/              # Dockerfile for the Jupyter container
├── examples/            # Example notebooks
├── utils/               # Shared utilities
├── models/              # Local AI model storage (gitignored)
└── requirements.txt     # Python dependencies
```

## Docker Configuration

- **Profile**: `local` — does not start with the default `docker compose up`, requires explicit `docker compose up playground`
- **Port**: 8888
- **Base image**: Python 3.12 with llama.cpp built from source
- **Volume**: `./playground` mounted at `/app`

## Dependencies

The environment includes 28+ packages covering:

- **ML/AI**: PyTorch, TensorFlow, scikit-learn, transformers, llama-cpp-python, sentence-transformers, spaCy
- **Data**: NumPy, Pandas, Matplotlib, Seaborn
- **NLP**: LangChain, LangGraph, tiktoken
- **Databases**: psycopg (PostgreSQL), qdrant-client, neo4j
- **Document Processing**: BeautifulSoup4, python-docx, PyPDF2, lxml
- **Networking**: NetworkX, Pydantic, Requests

See `playground/requirements.txt` for the full list.
