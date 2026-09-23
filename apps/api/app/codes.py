import secrets
import string
from urllib.parse import urlparse

_ALPHABET = string.ascii_letters + string.digits
_ALLOWED_SCHEMES = {"http", "https"}


class InvalidUrlError(ValueError):
    pass


def generate_code(length: int) -> str:
    return "".join(secrets.choice(_ALPHABET) for _ in range(length))


def validate_url(url: str) -> str:
    parsed = urlparse(url)
    if parsed.scheme not in _ALLOWED_SCHEMES or not parsed.netloc:
        raise InvalidUrlError(f"URL scheme must be one of {sorted(_ALLOWED_SCHEMES)}")
    return url
