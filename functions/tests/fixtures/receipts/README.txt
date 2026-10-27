Receipt fixtures for tests/test_payments_receipts_realistic.py.

texts/NAME.txt            what the server's OCR returned for one receipt; several images are separated by a line of =====
texts/NAME.expected.json  {"amountPiasters", "address", "created", "now", "colour", "reasons" (each must appear), "honest", "reference"?}

These texts are synthetic: written to look like the InstaPay result screen, an HSBC-style InstaPay receipt (spec 13.12) and
the shapes a forger would type. Real bank receipts go beside them the same way: black out names, phone numbers and account
digits BEFORE the text is added, and never commit the original image. A real fixture marked "honest": true must never be RED
and at least 95 percent of the honest ones must reach GREEN.
