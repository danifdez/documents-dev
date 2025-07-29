import requests
from typing import Any, Dict, Optional

class BackendClient:
    def __init__(self):
        self.base_url = "http://backend:3000"

    def get(self, endpoint: str, params: Optional[Dict[str, Any]] = None, **kwargs) -> requests.Response:
        url = f"{self.base_url}/{endpoint.lstrip('/')}"
        print(url)
        return requests.get(url, params=params, **kwargs)

    def post(self, endpoint: str, data: Optional[Any] = None, json: Optional[Any] = None, **kwargs) -> requests.Response:
        url = f"{self.base_url}/{endpoint.lstrip('/')}"
        return requests.post(url, data=data, json=json, **kwargs)

    def put(self, endpoint: str, data: Optional[Any] = None, json: Optional[Any] = None, **kwargs) -> requests.Response:
        url = f"{self.base_url}/{endpoint.lstrip('/')}"
        return requests.put(url, data=data, json=json, **kwargs)
