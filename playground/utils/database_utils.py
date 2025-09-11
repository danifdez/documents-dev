import os
import psycopg
from psycopg.rows import dict_row
from typing import Optional


def get_postgres_conn(host: str = None, port: int = None, dbname: str = None, user: str = None, password: str = None) -> Optional[psycopg.Connection]:
    """
    Returns a connection with row factory set to dict_row for convenience.
    """
    try:
        host = host or os.getenv("POSTGRES_HOST", "database")
        port = int(port or os.getenv("POSTGRES_PORT", "5432"))
        dbname = dbname or os.getenv("POSTGRES_DB", "documents")
        user = user or os.getenv("POSTGRES_USER", "postgres")
        password = password or os.getenv("POSTGRES_PASSWORD", "example")

        conn = psycopg.connect(
            host=host,
            port=port,
            dbname=dbname,
            user=user,
            password=password,
            autocommit=True,
            row_factory=dict_row,
        )
        return conn
    except Exception as e:
        print(f"Failed to connect to Postgres: {e}")
        return None
