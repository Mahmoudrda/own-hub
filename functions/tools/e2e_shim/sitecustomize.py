"""Emulator-only: points the code's pinned Firestore project at the emulator's.

The Functions emulator runs under a demo project (E2E_PROJECT, for example
demo-own-hub) so nothing can reach production, but identity/store.py builds its
client for the literal project "own-hub", a different namespace in the Firestore
emulator (so triggers never see the callables' writes). PYTHONPATH puts this
file on the worker's path only in tools/e2e_*.sh runs; production never loads it.
"""

import os

_project = os.environ.get("E2E_PROJECT")
if _project and os.environ.get("FIRESTORE_EMULATOR_HOST"):
    from google.cloud import firestore

    _init = firestore.Client.__init__

    def _patched(self, *args, **kwargs):
        if kwargs.get("project") == "own-hub":
            kwargs["project"] = _project
        _init(self, *args, **kwargs)

    firestore.Client.__init__ = _patched

# Cloud Vision does not exist in the emulators. When E2E_OCR_FILE is set,
# payments.ocr.TextReader.read returns that file's text (the walk writes the
# receipt it drew) instead of calling Vision; the checks that judge the text
# are the real ones. Patched when payments.ocr is first imported.
_ocr_file = os.environ.get("E2E_OCR_FILE")
if _ocr_file:
    import importlib.abc
    import sys

    class _OcrHook(importlib.abc.MetaPathFinder):
        def find_spec(self, name, path, target=None):
            if name != "payments.ocr":
                return None
            sys.meta_path.remove(self)
            import importlib.util

            spec = importlib.util.find_spec(name)
            loader = spec.loader
            run = loader.exec_module

            def exec_module(module):
                run(module)

                def read(self, jpeg):
                    try:
                        return open(_ocr_file, encoding="utf-8").read()
                    except OSError:
                        return None

                module.TextReader.read = read

            loader.exec_module = exec_module
            return spec

    sys.meta_path.insert(0, _OcrHook())

# macOS only: cv::resize's libdispatch thread pool segfaults inside the emulator's forked
# worker (OPENCV_FOR_THREADS_NUM does not stop it), so OpenCV runs single-threaded here.
if _project:
    try:
        import cv2

        cv2.setNumThreads(0)
    except ImportError:
        pass
