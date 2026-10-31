# Server-side UI pages

These are the pages the SERVER hands to clients at open time
(`APS_fnc_webPageSRV`). Clients never download this addon, so **editing a page
here changes the UI without changing the mission PBO** — and therefore without
every connected player re-downloading 230 MB to receive 200 KB of markup.

Layout mirrors the mission: `ui\html\deck.html` here answers a request for
`ui\html\deck.html` there. Same relative path in both trees, so a diff between
them is meaningful and a page moves between them by copying.

## The copy in the mission PBO is a BASELINE

It still ships, it still renders, and it never has to be updated again. If this
file is missing, older, or the server is not running this feature, the client
keeps the page it already drew. The fallback is not a code path — it is the
absence of a reply.

## Shipping a UI change

1. Edit the page here.
2. Clients pick it up on their next open of that screen. No client download, no
   repack, no restart: the PySQF daemon (`webpages` module) reads this directory
   off disk on every request.

## What a client actually receives

Only a page that differs from what the client already holds. The server keeps a
sha1 of each file: a client sends back the tag it got with its last override, and
a matching tag is answered "unchanged". A client with no tag is compared against
the mission tree (`mission/Armapunk2035.Malden/ui/html/`), which is what the PBO
was packed from — byte-identical means the PBO copy already is this page, and no
bytes are sent. That is the state every deploy leaves behind (the reload script
republishes the mission copies here), so the steady-state cost of this feature is
one small round trip per open.

Measured 2026-09-02: a shipped deck.html is 364 KB raw / 121 KB deflated and takes
about 3 s to cross the network on loopback, after which the page re-boots. That
is the cost of an actual change, paid once per client session per page (the
override is cached and tagged); it was the cost of EVERY open before the tag.

## Do not put anything secret here

The whole point is that these bytes get sent to clients. This directory is not
a private area of the server addon; it is a publishing directory.
