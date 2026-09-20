from ai_workflow_studio.core.security import (
    constant_time_equal,
    pkce_challenge,
    random_token,
    token_digest,
)


def test_tokens_are_random_and_url_safe() -> None:
    first = random_token()
    second = random_token()

    assert first != second
    assert len(first) >= 40
    assert "=" not in first


def test_token_digest_is_keyed_and_stable() -> None:
    assert token_digest("token", "a" * 32) == token_digest("token", "a" * 32)
    assert token_digest("token", "a" * 32) != token_digest("token", "b" * 32)
    assert constant_time_equal("same", "same")
    assert not constant_time_equal("same", "different")


def test_pkce_challenge_uses_s256() -> None:
    # RFC 7636 Appendix B verifier/challenge test vector.
    verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    assert pkce_challenge(verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
