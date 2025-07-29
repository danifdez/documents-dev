from pymongo import MongoClient
from typing import Optional

def get_mongo_client(uri: str = "mongodb://root:example@database:27017", timeout_ms: int = 5000) -> Optional[MongoClient]:
    """
    Create and return a MongoDB client.
    Args:
        uri (str): MongoDB connection URI.
        timeout_ms (int): Connection timeout in milliseconds.
    Returns:
        MongoClient or None: The MongoDB client instance, or None if connection fails.
    """
    try:
        client = MongoClient(uri, serverSelectionTimeoutMS=timeout_ms)
        # Trigger a server selection to verify connection
        client.admin.command('ping')
        db = client["documents"]
        return db
    except Exception as e:
        print(f"Failed to connect to MongoDB: {e}")
        return None
