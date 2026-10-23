# Deploying the render tracker web app (keyboard only)

`tracker_webapp.gs` is the endpoint `tools/web_render` uses to read its work queue from the
tracker spreadsheet and to log every attempt there. It is deployed with
[clasp](https://github.com/google/clasp) (`@google/clasp@3.4.1`, run through `npx`, so nothing
needs installing). `deploy.mjs` runs every clasp command for you. After the one-time steps
below, rendering needs no clicking at all.

Spreadsheet: `1WNbk19jM4_gVMklRA4rdA8Im9K_v8rb7VdvDFVc8geA` (pass `--sheet ID` for another).

## One time

Do these once, from the repository root. Each one opens its page in the renderer's Chrome
profile, which is already signed in to Google if you ran `node tools/web_render/render.mjs --login`.
Add `--no-open` to have the URL printed instead.

1. **Sign clasp in**

   ```bash
   node tools/render_tracker/deploy.mjs login
   ```

   This runs `npx @google/clasp@3.4.1 login`. On Google's page, pick the account and allow
   access. Tab and Enter work on every Google page. The browser then shows "Logged in!". The
   credentials are saved in `~/.clasprc.json`.

2. **Deploy**

   ```bash
   node tools/render_tracker/deploy.mjs
   ```

   It does the following:
   - generates a 48-character shared secret and writes it to `tracker_secret.local.gs`, which
     is pushed to Apps Script. The secret is never printed.
   - `clasp create-script --type standalone --parentId <spreadsheet id>`: creates the script
     **bound to the tracker spreadsheet**. The Apps Script API binds a script to the file given
     as parent. The script ID is saved in `.clasp.json`.
   - `clasp push --force`: pushes `tracker_webapp.gs`, `tracker_secret.local.gs` and
     `appsscript.json` (`.claspignore` lists these three files). The manifest declares the web
     app as **execute as me** (`USER_DEPLOYING`) and **anyone, even anonymous**
     (`ANYONE_ANONYMOUS`). The shared secret is the access control.
   - `clasp create-deployment`: deploys the web app. It saves the deployment ID in
     `deploy.local.json`. Only then does it write `trackerUrl`
     (`https://script.google.com/macros/s/<id>/exec`) and `trackerSecret` into
     `tools/web_render/config.local.json`, both together. A deploy that fails half-way
     therefore leaves the renderer's config as it was.
   - The first time, it opens the web app URL so that Google can ask you **once** to let the
     script edit the spreadsheet. Choose the account, then **Advanced**, then **Go to Render
     tracker web app**, then **Allow**. The page then shows `{"ok":false,"error":"unauthorized"}`.
     That is correct: the browser did not send the secret.
   - It waits until the tracker answers, then prints the queue state of each kind.

   The first request stores the secret as the Script Property **`TRACKER_SECRET`**
   (`checkSecret_` copies it from `tracker_secret.local.gs`). You never have to open Project
   Settings.

   If clasp reports that the **Apps Script API** is off for the account, `deploy.mjs` opens
   https://script.google.com/home/usersettings. Switch "Google Apps Script API" on (Tab to the
   switch, then Space), and run `deploy.mjs` again. Google requires this switch for clasp, once
   per account.

## Afterwards

```bash
node tools/web_render/render.mjs --queue     # per-kind cap / gap / cooldown, eligible rows
node tools/web_render/render.mjs --render    # unattended tracker run (see web_render/README.md)
```

- **After editing `tracker_webapp.gs`:** run `node tools/render_tracker/deploy.mjs` again. It
  pushes the change and redeploys to the **same** deployment, so the URL does not change.
- **To rotate the secret:** run `node tools/render_tracker/deploy.mjs --new-secret`. It writes
  the new secret to both files, then pushes and redeploys. The script's first request replaces
  the Script Property.

## Configuration on the renderer side

`tools/web_render/config.local.json` is gitignored (`tools/web_render/.gitignore`, line
`config.local.json`; `git check-ignore -v tools/web_render/config.local.json` confirms it).
`deploy.mjs` creates it with mode 600. To set it up by hand:

```json
{
  "trackerUrl": "https://script.google.com/macros/s/<deployment id>/exec",
  "trackerSecret": "<the same string as the TRACKER_SECRET Script Property>"
}
```

The environment variables `WEB_RENDER_TRACKER_URL` and `WEB_RENDER_TRACKER_SECRET` override the
file. The renderer accepts only `https://` tracker URLs, and it never prints the secret or
writes it to its run logs.

Also gitignored, in `tools/render_tracker/.gitignore`: `tracker_secret.local.gs`, `.clasp.json`
and `deploy.local.json`.

## By hand, without clasp

1. In the spreadsheet, open Extensions > Apps Script and paste `tracker_webapp.gs`.
2. Open Project Settings > Script Properties and add `TRACKER_SECRET` = a random string of at
   least 32 characters.
3. Choose Deploy > New deployment > Web app, with Execute as: Me and Who has access: Anyone.
   Authorize when asked.
4. Put the `/exec` URL and the secret into `tools/web_render/config.local.json` as shown above.

## Troubleshooting

- **The renderer says "reply is not JSON but an HTML page".** The web app is not shared with
  "Anyone", or the one-time authorization was not given. Open the `/exec` URL in the signed-in
  browser and allow access.
- **The renderer says `unauthorized`.** The secret in `config.local.json` does not match the
  Script Property. Run `deploy.mjs --new-secret`.
- **A row is stuck in `Rendering`.** The renderer was killed during an asset. After 120 minutes
  (`STALE_RENDERING_MIN`) the row is offered again automatically.
