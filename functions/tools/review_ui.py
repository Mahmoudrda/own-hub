"""The woman reviewer's queue as a simple page on her own Mac.

    cd functions
    .venv/bin/python -m tools.review_ui

Opens http://127.0.0.1:8765 in her browser. She signs in on that page as herself
(email, password, her App Check debug token); the server side of this file calls
the same callables as tools/review_queue.py, so the `womanReviewer` claim, the
consent rule and the access log all still apply. Nothing she types is written to
disk or logged, and the page is reachable only from this computer.
"""

from __future__ import annotations

import datetime as dt
import json
import secrets
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from zoneinfo import ZoneInfo

from tools import review_queue as rq

PORT = 8765
CAIRO = ZoneInfo("Africa/Cairo")
RUN_TOKEN = secrets.token_urlsafe(24)

_state = {"client": None}
_lock = threading.Lock()

FRIENDLY = {
    "review_consent_missing": "She has not asked for the call yet, so her number is hidden.",
    "duplicate_id": "This card is already registered to another account. Ask the owner.",
    "UNAUTHENTICATED": "Your account is not set up as a reviewer. Ask the owner.",
    "app_check_missing": "Your App Check key was not accepted. Ask the owner for a new one.",
    "INVALID_LOGIN_CREDENTIALS": "Wrong email or password.",
    "sex_digit_male": "That ID number says male (the 13th digit is odd). Check the digits again. If the card really says male, choose Not approved.",
    "invalid_nid": "Those 14 digits do not look right. Check the card and try again.",
}


def friendly(code: str) -> str:
    return FRIENDLY.get(code, f"Something went wrong ({code}). Try again, or tell the owner.")


def _client():
    return _state["client"]


def handle(path: str, body: dict) -> dict:
    """One action. Returns a JSON-able dict; raises CallError / SignInError."""
    if path == "/api/login":
        session = rq.PasswordSession(str(body.get("email", "")).strip(), str(body.get("password", "")), rq.API_KEY)
        check = rq.DebugAppCheck(str(body.get("appCheck", "")).strip(), rq.APP_ID, rq.API_KEY)
        check.refresh()
        client = rq.Client(session, check, rq.DEFAULT_BASE)
        client.call("list_verification_flags", {})  # proves the reviewer claim now
        _state["client"] = client
        return {"ok": True}
    if path == "/api/logout":
        _state["client"] = None
        return {"ok": True}
    client = _client()
    if client is None:
        raise rq.CallError("UNAUTHENTICATED", "UNAUTHENTICATED")
    if path == "/api/list":
        return client.call("list_verification_flags", {})
    if path == "/api/contact":
        flag = body.get("flagId")
        rows = client.call("list_verification_flags", {}).get("flags", [])
        row = next((r for r in rows if r.get("flagId") == flag), None)
        if row is not None and row.get("consentGiven") is not True:
            raise rq.CallError("FAILED_PRECONDITION", rq.REVIEW_CONSENT_MISSING)
        return {"phone": client.call("get_review_contact", {"flagId": flag})["phone"]}
    if path == "/api/schedule":
        local = dt.datetime.fromisoformat(str(body.get("at")))
        when = local.replace(tzinfo=CAIRO).isoformat()
        client.call("schedule_verification_review", {"flagId": body.get("flagId"), "route": body.get("route"), "scheduledFor": when})
        return {"ok": True}
    if path == "/api/decide":
        data = {"flagId": body.get("flagId"), "approve": body.get("approve") is True}
        if data["approve"] and body.get("nid"):
            data["nid"] = str(body["nid"]).strip()
        result = client.call("decide_verification_flag", data)
        data = None
        return {"outcome": result.get("outcome")}
    raise rq.CallError("NOT_FOUND", "not_found")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):  # nothing is logged
        pass

    def _send(self, code: int, payload, ctype="application/json"):
        raw = payload if isinstance(payload, bytes) else json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def _local(self) -> bool:
        return self.headers.get("Host", "") in (f"127.0.0.1:{PORT}", f"localhost:{PORT}")

    def do_GET(self):
        if not self._local() or self.path != "/":
            return self._send(404, {"error": "not_found"})
        self._send(200, PAGE.replace("__TOKEN__", RUN_TOKEN).encode(), "text/html; charset=utf-8")

    def do_POST(self):
        if not self._local() or self.headers.get("X-Run-Token") != RUN_TOKEN:
            return self._send(403, {"error": "forbidden"})
        try:
            size = int(self.headers.get("Content-Length") or 0)
            body = json.loads(self.rfile.read(size) or b"{}")
            with _lock:
                result = handle(self.path, body)
            self._send(200, result)
        except rq.CallError as error:
            self._send(200, {"error": friendly(error.reason or error.status)})
        except rq.SignInError as error:
            self._send(200, {"error": friendly(str(error))})
        except Exception:
            self._send(200, {"error": friendly("internal_error")})


def main() -> int:
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    url = f"http://127.0.0.1:{PORT}"
    print(f"Review queue is open at {url}  (press Ctrl+C to close it)")
    threading.Timer(0.5, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


PAGE = """<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Own Hub reviews</title>
<style>
:root{--bg:#FCF8F2;--ink:#123F50;--pink:#F4BEBB;--petrol:#1A5D74;--mute:#52656C;--line:#E8DED3}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:17px/1.5 -apple-system,system-ui,sans-serif}
main{max-width:720px;margin:0 auto;padding:20px 16px 60px}h1{font-size:26px;margin:8px 0}
.card{background:#fff;border:1px solid var(--line);border-radius:16px;padding:18px;margin:14px 0}
label{display:block;font-weight:600;margin:12px 0 4px}
input,select{width:100%;font:inherit;padding:12px;border:1px solid var(--line);border-radius:10px;background:#fff;color:var(--ink)}
button{font:inherit;font-weight:700;border:0;border-radius:12px;padding:14px 18px;cursor:pointer;background:var(--pink);color:var(--ink);min-height:48px}
button.sec{background:#fff;border:2px solid var(--petrol);color:var(--petrol)}button.no{background:#fff;border:2px solid var(--mute);color:var(--mute)}
button:disabled{opacity:.45;cursor:not-allowed}.row{display:flex;gap:10px;flex-wrap:wrap;margin-top:12px}.row>*{flex:1 1 150px}
.step{border-top:1px solid var(--line);margin-top:16px;padding-top:14px}.num{display:inline-block;width:26px;height:26px;border-radius:50%;background:var(--petrol);color:#fff;text-align:center;font-weight:700;margin-inline-end:8px}
#msg{position:sticky;top:0;z-index:9}.mute{color:var(--mute);font-size:15px}.msg{padding:12px 14px;border-radius:10px;margin:12px 0;background:#F9DEDC}.ok{background:#DDEEE3}
.phone{font-size:24px;font-weight:800;direction:ltr;user-select:all}.top{display:flex;justify-content:space-between;align-items:center}
.top button{min-height:40px;padding:8px 14px}
</style></head><body><main>
<div class="top"><h1>Own Hub reviews</h1><button class="sec" id="out" hidden onclick="logout()">Sign out</button></div>
<div id="msg"></div><div id="app"></div></main>
<script>
const T="__TOKEN__";const $=id=>document.getElementById(id);
const esc=s=>String(s??"").replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
async function api(p,b){const r=await fetch(p,{method:"POST",headers:{"Content-Type":"application/json","X-Run-Token":T},body:JSON.stringify(b||{})});return r.json()}
function say(t,ok){$("msg").innerHTML=t?`<div class="msg ${ok?"ok":""}"><b>${esc(t)}</b></div>`:"";if(t)window.scrollTo({top:0,behavior:"smooth"})}
function loginView(){$("out").hidden=true;$("app").innerHTML=`<div class="card"><b>Sign in</b><p class="mute">Use the email and password the owner made for you. Nothing is saved on this computer.</p>
<label>Email</label><input id="e" type="email" autocomplete="username"><label>Password</label><input id="p" type="password" autocomplete="current-password">
<label>App Check key</label><input id="k" type="password" placeholder="The long key the owner sent you"><div class="row"><button onclick="login()">Sign in</button></div></div>`}
async function login(){say("Signing in...");const r=await api("/api/login",{email:$("e").value,password:$("p").value,appCheck:$("k").value});
if(r.error){say(r.error);return}say("");load()}
async function logout(){await api("/api/logout");say("");loginView()}
function when(s){if(!s)return"";try{return new Date(s).toLocaleString([], {weekday:"short",day:"numeric",month:"short",hour:"2-digit",minute:"2-digit"})}catch(e){return s}}
async function load(){const r=await api("/api/list");if(r.error){say(r.error);loginView();return}
$("out").hidden=false;const f=r.flags||[];
if(!f.length){$("app").innerHTML=`<div class="card"><b>All clear</b><p class="mute">Nobody is waiting for a check right now.</p><div class="row"><button class="sec" onclick="load()">Refresh</button></div></div>`;return}
$("app").innerHTML=`<p class="mute">${f.length} waiting, oldest first. Each request closes after 72 hours if no call is booked.</p>`+f.map(card).join("")+`<div class="row"><button class="sec" onclick="load()">Refresh</button></div>`}
function card(x,i){const id=esc(x.flagId),booked=!!x.scheduledFor,dup=(x.flags||[]).includes("duplicate_id");
const phone=x.consentGiven?`<button class="sec" onclick="phone('${id}',this)">Show her phone number</button><div id="ph-${id}"></div>`:`<p class="mute">She has not asked for the call yet. You can't see her number until she does.</p>`;
return `<div class="card"><b>Request ${i+1}</b> <span class="mute">· closes ${esc(when(x.slaExpiresAt))}</span>${dup?`<div class="msg">This ID card is already used by another account. Do not approve. Tell the owner.</div>`:""}
<div class="step"><span class="num">1</span><b>Call her</b><div class="mute">Video call or ladies-only gym. Check she is a woman and the photo matches.</div>${phone}</div>
<div class="step"><span class="num">2</span><b>Book the time</b>${booked?`<div class="mute">Booked: ${esc(x.route)} · ${esc(when(x.scheduledFor))}</div>`:""}
<div class="row"><select id="rt-${id}"><option value="video">Video call</option><option value="gym">At a ladies-only gym</option></select><input id="at-${id}" type="datetime-local"></div>
<div class="row"><button class="sec" onclick="book('${id}')">${booked?"Change booking":"Book"}</button></div><div class="mute">Times are Cairo time.</div></div>
<div class="step"><span class="num">3</span><b>Decide</b>${booked?"":`<div class="mute">Book the time first.</div>`}
${x.needsNidOnCall?`<label>14 digits on her national ID (read on the call)</label><input id="nid-${id}" inputmode="numeric" maxlength="14" type="password" autocomplete="off">`:""}
<div class="row"><button ${booked&&!dup?"":"disabled"} onclick="decide('${id}',true,${!!x.needsNidOnCall})">Approve her</button><button class="no" ${booked?"":"disabled"} onclick="decide('${id}',false,false)">Not approved</button></div></div></div>`}
async function phone(id,b){const r=await api("/api/contact",{flagId:id});if(r.error){say(r.error);return}b.hidden=true;$("ph-"+id).innerHTML=`<div class="phone">${esc(r.phone)}</div><div class="mute">This lookup is logged.</div>`}
async function book(id){const at=$("at-"+id).value;if(!at){say("Pick a date and time first.");return}
const r=await api("/api/schedule",{flagId:id,route:$("rt-"+id).value,at});if(r.error){say(r.error);return}say("Booked.",1);load()}
async function decide(id,ok,needNid){let nid;if(ok&&needNid){nid=$("nid-"+id).value;if(!/^\\d{14}$/.test(nid)){say("Type the 14 digits from her ID card.");return}}
const b=event.target;if(b.dataset.sure!=="1"){b.dataset.sure="1";b.dataset.was=b.textContent;b.textContent=ok?"Tap again to approve":"Tap again to confirm";setTimeout(()=>{b.dataset.sure="";b.textContent=b.dataset.was},4000);return}
b.disabled=true;say("Saving...");const r=await api("/api/decide",{flagId:id,approve:ok,nid});if(r.error){say(r.error);b.disabled=false;b.textContent=b.dataset.was;return}say(ok?"Approved. She is in.":"Saved. She was not approved.",1);load()}
loginView();
</script></body></html>"""

if __name__ == "__main__":
    sys.exit(main())
