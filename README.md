# Minnesota Nanofabrication Club

### 👉 [minnesota-nanofabrication-club.github.io/club_website](https://minnesota-nanofabrication-club.github.io/club_website/)

**Looking for the club? Everything is on the website above** — what we're building,
the projects currently underway, and how to join.

---

This repository just holds the source for that site. It's a static site (plain HTML
and CSS, no build step) served by GitHub Pages from `main`.

| File | Purpose |
| --- | --- |
| `index.html` | Home — about the club, Full Stack Codesign, current projects, team |
| `stepper.html` | Maskless lithography stepper project page |
| `style.css` | Shared stylesheet |
| `SYNC.md` | How the site is kept in sync with the club Google Drive |
| `CLAUDE.md` | Context and standing decisions for anyone (or any agent) editing this repo |

## Editing

Edit the HTML directly and push to `main`; Pages redeploys automatically. To preview
locally, open `index.html` in a browser, or serve the folder:

```
python3 -m http.server 8000
```

## Source of truth

Project content on the site is derived from the club's **Ultra Hardcore Chip Codesign**
Google Drive, which is the authoritative record. The site is refreshed from Drive on a
weekly schedule — see [`SYNC.md`](SYNC.md) for what gets synced and how to run it
manually. Prefer updating Drive over editing project copy here by hand, or the next
sync may overwrite it.
