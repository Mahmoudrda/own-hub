"""tools/upload_media.py: the only way a picture or a clip enters the library.

It must refuse what the content rules would refuse (type, size, path), refuse a
file whose bytes do not match its name, shrink and convert pictures to WebP,
upload to content/{collection}/{doc}/{file} with a long cache lifetime, and
register the file where the console's media library reads it. Nothing is
uploaded unless every file passed.
"""

from __future__ import annotations

import cv2
import numpy as np
import pytest

from tools import upload_media as um


def _png(width=40, height=30) -> bytes:
    ok, data = cv2.imencode(".png", np.full((height, width, 3), 200, np.uint8))
    assert ok
    return data.tobytes()


def _jpg(width=40, height=30) -> bytes:
    ok, data = cv2.imencode(".jpg", np.full((height, width, 3), 120, np.uint8))
    assert ok
    return data.tobytes()


MP4 = b"\x00\x00\x00\x18ftypmp42" + b"\x00" * 64


class FakeBlob:
    def __init__(self, path, bucket):
        self.path, self.bucket = path, bucket
        self.cache_control = None

    def upload_from_string(self, data, content_type=None):
        self.bucket.uploads[self.path] = (data, content_type, self.cache_control)


class FakeBucket:
    def __init__(self):
        self.uploads = {}

    def blob(self, path):
        return FakeBlob(path, self)


class FakeDb:
    def __init__(self):
        self.docs = {}

    def collection(self, name):
        db = self

        class _Col:
            def document(self, doc_id):
                class _Doc:
                    def set(self, data):
                        db.docs[f"{name}/{doc_id}"] = data

                return _Doc()

        return _Col()


def run(argv, files):
    bucket, db, lines = FakeBucket(), FakeDb(), []
    code = um.main(
        argv,
        clients=lambda: (bucket, db),
        require_adc=lambda: None,
        read=lambda path: files[path],
        out=lines.append,
    )
    return code, bucket, db, lines


def test_a_picture_is_converted_to_webp_and_registered():
    code, bucket, db, lines = run(
        ["--collection", "recipes", "--doc", "om_ali", "Om Ali.JPG"],
        {"Om Ali.JPG": _jpg()},
    )
    assert code == 0
    data, content_type, cache = bucket.uploads["content/recipes/om_ali/om_ali.webp"]
    assert content_type == "image/webp"
    assert data[:4] == b"RIFF" and data[8:12] == b"WEBP"
    assert cache == um.CACHE_CONTROL
    entry = db.docs["mediaLibrary/recipes__om_ali__om_ali.webp"]
    assert entry["path"] == "content/recipes/om_ali/om_ali.webp"
    assert entry["kind"] == "picture"
    assert entry["name"] == "om_ali.webp"
    assert lines == [
        f"uploaded content/recipes/om_ali/om_ali.webp ({len(data)} bytes). "
        "Choose it as om_ali.webp"
    ]


def test_a_large_picture_is_shrunk_to_the_longest_side():
    prepared = um.prepare("big.png", _png(width=4000, height=2000))
    image = cv2.imdecode(np.frombuffer(prepared.data, np.uint8), cv2.IMREAD_COLOR)
    assert image.shape[1] == um.MAX_SIDE
    assert image.shape[0] == um.MAX_SIDE // 2


def test_keep_original_uploads_the_picture_as_it_is():
    original = _png()
    prepared = um.prepare("cover.png", original, convert=False)
    assert prepared.data == original and prepared.content_type == "image/png"


def test_a_clip_is_uploaded_as_it_is_for_an_exercise():
    code, bucket, db, _ = run(
        ["--collection", "exercises", "--doc", "glute_bridge", "bridge.mp4"],
        {"bridge.mp4": MP4},
    )
    assert code == 0
    data, content_type, _ = bucket.uploads["content/exercises/glute_bridge/bridge.mp4"]
    assert data == MP4 and content_type == "video/mp4"
    assert db.docs["mediaLibrary/exercises__glute_bridge__bridge.mp4"]["kind"] == "video"


def test_an_event_cover_goes_under_the_event_id():
    code, bucket, _, _ = run(
        ["--collection", "events", "--doc", "AbC123xyz", "cover.png"],
        {"cover.png": _png()},
    )
    assert code == 0
    assert "content/events/AbC123xyz/cover.webp" in bucket.uploads


@pytest.mark.parametrize(
    "name, data, reason",
    [
        ("photo.gif", b"GIF89a....", "only jpg, png, webp and mp4"),
        ("photo.jpg", _png(), "do not match its name"),
        ("clip.mp4", _jpg(), "do not match its name"),
        ("empty.png", b"", "empty"),
        ("photo.png", b"\x89PNG\r\n\x1a\n" + b"not really", "could not be read"),
    ],
)
def test_what_the_rules_would_refuse_is_refused_first(name, data, reason):
    code, bucket, db, lines = run(
        ["--collection", "recipes", "--doc", "om_ali", name], {name: data}
    )
    assert code == 2
    assert reason in lines[0]
    assert bucket.uploads == {} and db.docs == {}


def test_over_200_mb_is_refused_without_reading_it_as_a_picture(monkeypatch):
    monkeypatch.setattr(um, "MAX_BYTES", 10)
    with pytest.raises(um.MediaRefused, match="200 MB"):
        um.prepare("clip.mp4", MP4)


def test_one_bad_file_uploads_nothing_at_all():
    code, bucket, db, _ = run(
        ["--collection", "recipes", "--doc", "om_ali", "a.png", "b.gif"],
        {"a.png": _png(), "b.gif": b"GIF89a"},
    )
    assert code == 2
    assert bucket.uploads == {} and db.docs == {}


@pytest.mark.parametrize("doc", ["../users/x", "om ali", "", "a/b"])
def test_the_path_cannot_leave_content(doc):
    code, bucket, _, lines = run(
        ["--collection", "recipes", "--doc", doc, "a.png"], {"a.png": _png()}
    )
    assert code == 2 and bucket.uploads == {}
    assert lines[0].startswith("refused:")


def test_a_file_name_is_never_a_path():
    assert um.safe_name("../../etc/Passwd Photo.PNG") == "passwd_photo.png"


def test_the_collection_must_be_a_content_collection():
    with pytest.raises(SystemExit):
        um.main(
            ["--collection", "users", "--doc", "x", "a.png"],
            clients=lambda: (FakeBucket(), FakeDb()),
            require_adc=lambda: None,
            read=lambda p: _png(),
            out=lambda _line: None,
        )


def test_no_owner_credentials_no_upload(monkeypatch):
    import google.auth

    def none():
        raise google.auth.exceptions.DefaultCredentialsError("none")

    monkeypatch.setattr(google.auth, "default", none)
    with pytest.raises(SystemExit, match="refused"):
        um._require_adc()
