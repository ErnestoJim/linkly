import pytest

from app.codes import InvalidUrlError, generate_code, validate_url


def test_generate_code_length_and_alphabet():
    code = generate_code(6)
    assert len(code) == 6
    assert code.isalnum()


def test_generate_code_is_random():
    codes = {generate_code(8) for _ in range(200)}
    assert len(codes) == 200


@pytest.mark.parametrize("url", ["http://example.com", "https://example.com/path?q=1"])
def test_validate_url_accepts_http_and_https(url):
    assert validate_url(url) == url


@pytest.mark.parametrize(
    "url",
    ["ftp://example.com", "javascript:alert(1)", "file:///etc/passwd", "not-a-url", ""],
)
def test_validate_url_rejects_other_schemes(url):
    with pytest.raises(InvalidUrlError):
        validate_url(url)
