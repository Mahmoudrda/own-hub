"""Account deletion (S4). Lives outside `identity/` on purpose: deletion has to
delete Storage prefixes, and nothing in `identity/` may touch Cloud Storage
(tests/test_contract.py bans it there)."""
