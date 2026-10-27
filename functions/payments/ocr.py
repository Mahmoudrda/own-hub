"""Server OCR: Cloud Vision through the adapter the ID check already uses."""

from __future__ import annotations

from typing import Optional


class TextReader:
    """`read(jpeg)` returns the recognised text, or None when the reader could
    not run. The text is held in memory for one request: never logged, never
    stored (it can carry card digits and balances)."""

    def __init__(self, ocr=None):
        self._ocr = ocr

    def read(self, jpeg: bytes) -> Optional[str]:
        if self._ocr is None:
            from identity import providers_selfhosted

            self._ocr = providers_selfhosted.VisionOcr()
        result = self._ocr.read(jpeg)
        return result.text if getattr(result, "ok", False) else None
