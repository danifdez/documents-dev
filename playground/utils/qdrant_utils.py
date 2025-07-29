from qdrant_client import QdrantClient
from typing import Optional

def get_qdrant_client(host: str = "qdrant", port: int = 6333, https: bool = False, api_key: str = None) -> Optional[QdrantClient]:
    """
    Create and return a Qdrant client.
    Args:
        host (str): Qdrant host address.
        port (int): Qdrant port.
        https (bool): Use HTTPS connection.
        api_key (str, optional): API key for authentication.
    Returns:
        QdrantClient or None: The Qdrant client instance, or None if connection fails.
    """
    try:
        client = QdrantClient(host=host, port=port, https=https, api_key=api_key)
        # Try a simple request to verify connection
        client.get_collections()
        
        return client
    except Exception as e:
        print(f"Failed to connect to Qdrant: {e}")
        return None
