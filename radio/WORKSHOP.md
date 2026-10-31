# Publishing @Armapunk2035 to Steam Workshop (owner-gated)

Everything is pre-staged: signed build in `radio/dist/@Armapunk2035/`, preview card
`radio/dist/workshop_preview.png`, upload manifest `radio/dist/workshop_item.vdf`.

## First publish (creates the item, UNLISTED)

1. Rebuild fresh if code changed since the last build: `bash radio/build_addon.sh && bash radio/sign_addon.sh`
2. Upload (interactive -- Steam Guard will prompt; the account you log in with OWNS the item
   publicly, so pick deliberately):
   `~/.local/opt/steamcmd/steamcmd.sh +login <steam_account> +workshop_build_item /home/timb/loonybin-doomba/radio/dist/workshop_item.vdf +quit`
3. The output prints the new PublishedFileId. Record it:
   - paste it into `radio/dist/workshop_item.vdf` (`publishedfileid`) -- future runs UPDATE instead of re-creating
   - paste it into `radio/addon/meta.cpp` (`publishedid`) and rebuild once, so launchers link the item
4. Verify while UNLISTED: open the item URL (steamcommunity.com/sharedfiles/filedetails/?id=<id>),
   subscribe from the owning account, confirm the launcher pulls it and the game loads it.
5. SERVER SIDE before going public: `keys/maldenradio.bikey` into BOTH servers' `keys/` dirs
   (live runs verifySignatures=2 -- without the key, addon users get kicked).
6. Go public: edit `visibility` to `"0"` in the vdf and re-run the steamcmd line (or flip it on
   the item's web page). Announce in Discord -- no @everyone.

## Updates (every release after)

`bash radio/build_addon.sh && bash radio/sign_addon.sh`, bump `changenote` in the vdf, re-run the
steamcmd line. Subscribers auto-update. The bikey only changes if the key pair changes (don't).

Notes: title/description/preview live in the vdf and can be edited on the web page afterward;
visibility values: 0 public, 1 friends, 2 private, 3 unlisted.
