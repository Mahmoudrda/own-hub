"""The rules files, read as text: the reviewer dashboard's collections stay
server-only, the profile keys the onboarding sync needs are allowed, and only
exercise and workout content opens to a signed-out visitor. The emulator suite
in test/rules covers the same rules by behaviour."""

from __future__ import annotations

import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as handle:
        return handle.read()


FIRESTORE = _read("firebase", "firestore.rules")


def test_the_new_collections_are_server_only():
    for name in ("verificationPreapproved", "verificationReviewers", "verificationBookings"):
        assert re.search(
            rf"match /{name}/\{{\w+\}}\s*\{{ allow read, write: if false; \}}", FIRESTORE
        ), name


def test_the_profile_allows_the_schedule_keys():
    block = FIRESTORE.split("function validProfile()")[1].split("function validNotify")[0]
    for key in ("weekdays", "level", "minutesCustom", "days", "minutes", "goal"):
        assert f"'{key}'" in block
    assert "hasOnly" in block, "the profile stays a whitelist"
    assert "idHmac" not in block and "verified" not in block


def test_only_content_documents_are_public_to_read():
    open_reads = re.findall(r"match (/[^\s{]+(?:/\{\w+\})?)\s*\{ allow read: if true;", FIRESTORE)
    assert sorted(open_reads) == [
        "/meta/exerciseLibrary",
        "/meta/exercises",
        "/meta/workouts",
        "/workoutLibrary/{id}",
    ]


def test_the_other_meta_documents_still_need_sign_in():
    assert re.search(
        r"match /meta/\{docId\}\s*\{ allow read: if isVerified\(\) \|\| isAdmin\(\);\s*"
        r"allow write: if isAdmin\(\)\s*"
        r"&& docId != 'communityFoods'\s*&& docId != 'communityFoodsVersion'; \}",
        FIRESTORE,
    )
    assert "match /workoutLibrary/{id} { allow read: if true; allow write: if isAdmin(); }" in FIRESTORE


def test_exercise_media_is_the_only_public_storage_path():
    for name in ("storage.rules", "storage.library.rules"):
        text = _read("firebase", name)
        public = re.findall(r"match (/[^\s]+) \{\s*allow read: if true;", text)
        assert public == ["/content/exercises/{docId}/{file}"], name
        assert "match /content/{collection}/{docId}/{file} {\n      allow read: if signedIn() && collection != 'events';" in text
        events = re.search(r"match /content/events/\{eventId\}/\{file\} \{(.*?)\n    \}", text, re.S)
        assert events, name
        assert "request.auth.token.get('verified', false) == true" in events.group(1), name
        assert "allow read: if true" not in events.group(1), name
        assert re.search(r"match /\{allPaths=\*\*\} \{\s*allow read, write: if false;", text)


def test_the_test_phone_file_is_ignored_by_git():
    lines = _read(".gitignore").splitlines()
    assert ".env.*" in lines
