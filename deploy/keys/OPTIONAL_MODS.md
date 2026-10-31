# Optional client mods

This server runs `verifySignatures = 2` (deploy/server.cfg). That means **every addon a client loads must
be signed by a key present in the server's `keys/` directory**, or the player is kicked on join. So an
"optional" client-side mod is enabled simply by **whitelisting its public `.bikey`** here — without adding
the mod to `-mod` / `-serverMod`. Result:

- Players who **choose** to load the mod pass signature verification (its PBOs are signed by a key we trust).
- Players who **don't** load it are completely unaffected — it is never required.
- The server itself does **not** run the mod (it's not in `-serverMod`), so it adds zero server load and
  cannot change gameplay/balance.

Adding a mod's **public** `.bikey` is safe: it only lets the server trust PBOs signed with that mod's
**private** key (which only the mod author holds). Nobody can sign a fake/cheat PBO with just the public key.

`deploy/run-boot2.sh` copies **every** `deploy/keys/*.bikey` into `$A3SRV/keys/` on each restart, so any key
dropped in this folder is auto-deployed on the next natural restart.

---

## Currently whitelisted optional mods

### JSRS SOUNDMOD 2025  — Steam Workshop `3407948300`
Client-side audio overhaul (weapons / vehicles / environment). ~3.9 GB. No gameplay, balance, or server
logic — purely sound. Totally optional.

**STATUS: enabled.** `jsrssoundmod2025.bikey` is staged in `deploy/keys/` (copied from the installed mod;
the JSRS PBOs are signed `*.pbo.jsrssoundmod2025.bisign`). It deploys to `$A3SRV/keys/` on the next restart,
after which opt-in players pass `verifySignatures=2`. The note is in `deploy/patchnote_override.txt`.

For reference, the key came from the downloaded mod's key folder:

```
# if subscribed/downloaded via Steam or SteamCMD (appid 107410):
~/.local/share/Steam/steamapps/workshop/content/107410/3407948300/keys/*.bikey
#   (the subfolder may be "keys" or "Keys")

# or pull it headless with SteamCMD:
steamcmd +login <steam_user> +workshop_download_item 107410 3407948300 +quit
cp ~/.local/share/Steam/steamapps/workshop/content/107410/3407948300/[Kk]eys/*.bikey \
   "<repo>/deploy/keys/"
```

Then a normal restart (`run-boot2.sh`) stages the key. **Do not** add JSRS to `-mod`/`-serverMod`.

**For players:** Subscribe to *JSRS SOUNDMOD 2025* on the Workshop, tick it in the Arma 3 Launcher, and
join as usual. It's optional — load it for better sound, or skip it.
