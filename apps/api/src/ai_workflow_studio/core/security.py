import base64
import hashlib
import hmac
import secrets


def random_token(byte_count: int = 32) -> str:
    """Return a URL-safe token with enough entropy for browser credentials."""

    return secrets.token_urlsafe(byte_count)


def token_digest(token: str, secret: str) -> str:
    """Create a keyed digest so leaked database rows cannot be used as cookies."""

    return hmac.new(secret.encode(), token.encode(), hashlib.sha256).hexdigest()


def pkce_challenge(verifier: str) -> str:
    digest = hashlib.sha256(verifier.encode("ascii")).digest()
    return base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii")


def constant_time_equal(left: str, right: str) -> bool:
    return hmac.compare_digest(left, right)
