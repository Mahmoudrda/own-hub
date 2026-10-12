"""Own Hub identity verification.

Module map, in the order spec §2's pipeline runs them:

    nid.py        pure parser for the 14-digit number   (no I/O, spec §8)
    arabic.py     pure reader for the printed النوع word (no I/O)
    imagesize.py  pure header reader: image size before any decode (T24)
    providers.py  the three paid seams, plus mocks and the unfilled AWS slot
    config.py     every dial, with its score scale attached
    decisions.py  spec §3's matrix, as one pure function
    ledger.py     the per-uid micro-USD budget, spec §6
    dedupe.py     id_hmac and the one-card-one-account registry, spec §2 step 5
    evidence.py   the flagged-case bundle, spec §4 — OFF by default
    pipeline.py   the order the above are called in, and nothing else
    main.py       the callables (at the package root, not here)

Nothing in this package writes an image anywhere. See main.py's header.
"""
