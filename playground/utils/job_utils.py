from typing import Any, Dict, Tuple, Optional
import time
import uuid
from utils.database_utils import get_postgres_conn


def send_job(job_type: str, priority: str, payload: Dict[str, Any]) -> str:
    """Insert a new job row into the Postgres jobs table and return the generated id (text/uuid)."""
    conn = get_postgres_conn()
    if conn is None:
        raise RuntimeError("Failed to connect to Postgres.")

    import json
    job_id = str(uuid.uuid4())
    payload_json = json.dumps(payload)
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO jobs (id, type, payload, status, priority) VALUES (%s, %s, %s, %s, %s)",
            (job_id, job_type, payload_json, 'pending', priority),
        )
    return job_id


def send_and_await_job(job_type: str, priority: str, payload: Dict[str, Any], poll_interval: float = 1.0, timeout: float = 60.0) -> Tuple[str, Optional[dict]]:
    """Create a job and wait until its status is 'completed' or 'failed'."""
    job_id = send_job(job_type, priority, payload)
    conn = get_postgres_conn()
    if conn is None:
        raise RuntimeError("Failed to connect to Postgres.")

    start_time = time.time()
    while True:
        with conn.cursor() as cur:
            cur.execute("SELECT status, result FROM jobs WHERE id = %s", (job_id,))
            row = cur.fetchone()
            if row is None:
                return ("not_found", None)
            status = row.get("status") or "pending"
            if status in ("completed", "failed"):
                return (status, row.get("result"))
        if time.time() - start_time > timeout:
            return ("timeout", None)
        time.sleep(poll_interval)
