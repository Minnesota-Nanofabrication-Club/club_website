# Guide: Search Engine Optimization

The `<head>` template every page on this site should carry, how to write a title and
description that win the searches this club can actually win, and the structured data that
tells Google what a student fab club is. **Everything here is hand-written markup pasted
into the HTML — there is no plugin, no build step, and nothing in Drive generates it.**
The one moving part is `scripts/generate_sitemap.py`, which rewrites `sitemap.xml` from
whatever `*.html` files exist in the repo root.

---

## Contents

- [What this can and cannot do](#what-this-can-and-cannot-do)
- [The head template](#the-head-template)
- [Every tag, and what breaks without it](#every-tag-and-what-breaks-without-it)
- [Writing titles and descriptions for this site](#writing-titles-and-descriptions-for-this-site)
- [Structured data](#structured-data)
- [`robots.txt` and `sitemap.xml`](#robotstxt-and-sitemapxml)
- [What has to be done outside the repo](#what-has-to-be-done-outside-the-repo)
- [Pre-publish checklist](#pre-publish-checklist)
- [Common pitfalls](#common-pitfalls)

---

## What this can and cannot do

Read this section before spending an afternoon on meta tags, because it sets the ceiling on
what the rest of the guide is worth.

Search ranking is dominated by *who links to you*. This site is a project page on a shared
`github.io` host with, as of writing, essentially no inbound links. No arrangement of meta
tags changes that. What the markup in this guide actually buys:

| Realistic outcome | Not going to happen |
| --- | --- |
| Google indexes all nine machine pages instead of just the home page | Ranking for `reactive ion etcher` against Oxford Instruments and Plasma-Therm |
| Someone searching `DIY reactive ion etcher` or `student built RIE` finds the page | Ranking for `photolithography` or `sputtering` |
| A search for `MNF` or `Minnesota nanofabrication club` returns the right page first | Outranking the UMN Nano Center for `minnesota nanofabrication` |
| A link pasted in Discord or Slack unfurls with a real title and summary instead of a bare URL | A traffic spike from tags alone |
| Google's knowledge panel and site-name display show `Minnesota Nanofabrication Club`, not `minnesota-nanofabrication-club.github.io` | Rich result cards; none of the eligible types apply to these pages |

The honest ordering of effort, most valuable first:

1. **Get linked from sites that already rank.** A link from the Hacker Fab documentation
   site, the UMN ECE department, or the university's student-organization directory is worth
   more than every tag in this guide combined. That is the actual bottleneck.
2. **Write pages with real technical detail.** `stepper.html` ranks on the strength of naming
   a Basler `acA1920-40uc`, a `10×` DIN Plan objective, and GRBL — those are the phrases a
   person building the same thing types into a search box. Thin pages do not rank regardless
   of their markup.
3. **Then** the markup below, which makes sure the good pages are findable and legible.

!!! note "Expect weeks, not days"
    A brand-new page with no inbound links typically takes days to a few weeks to be
    indexed, and longer to settle into a position. Submitting the sitemap (below) speeds up
    discovery; it does not speed up ranking. If a page is still not in the index a month
    after submission, that is a signal worth investigating — before then it is just normal.

!!! warning "The never-invent rule applies to meta tags too"
    A `<meta name="description">` is site content, and `CLAUDE.md` rule 1 covers it without
    exception: every claim must trace to a Drive doc. The temptation is specific and
    predictable — an empty project folder produces a boring description, and a richer one is
    easy to write. Do not. `Etcher` has an empty Drive folder and a `Planned` status; its
    description says it is planned and stops there. A description promising a `13.56 MHz RF
    plasma etcher with load-lock` is a claim the club has no record of making, it is now the
    snippet Google shows the world, and no sync will ever remove it.

---

## The head template

Copy this into a new machine page and change the four values listed under it. It is written
for `etcher.html`; the same shape works for every subpage.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>DIY Reactive Ion Etcher (RIE) &mdash; MNF</title>
  <meta name="description" content="A student-built reactive ion etcher for the Minnesota Nanofabrication Club's open fab line at the University of Minnesota. Planned &mdash; design not yet started.">
  <link rel="canonical" href="https://minnesota-nanofabrication-club.github.io/club_website/etcher.html">

  <meta property="og:type" content="article">
  <meta property="og:site_name" content="Minnesota Nanofabrication Club">
  <meta property="og:title" content="DIY Reactive Ion Etcher (RIE) &mdash; MNF">
  <meta property="og:description" content="A student-built reactive ion etcher for the Minnesota Nanofabrication Club's open fab line at the University of Minnesota. Planned &mdash; design not yet started.">
  <meta property="og:url" content="https://minnesota-nanofabrication-club.github.io/club_website/etcher.html">

  <meta name="twitter:card" content="summary">

  <link rel="stylesheet" href="style.css">
</head>
```

The four values to replace, and nothing else:

| Placeholder | Appears in | Rule |
| --- | --- | --- |
| The title string | `<title>`, `og:title` | Identical in both. See [writing titles](#writing-titles-and-descriptions-for-this-site) |
| The description string | `description`, `og:description` | Identical in both |
| `etcher.html` | `canonical`, `og:url` | The real filename, twice, absolute URL both times |
| `og:type` | one tag | `article` on machine pages, `website` on `index.html` |

For `index.html` the only differences are `og:type` set to `website` and both URLs set to the
bare directory form, `https://minnesota-nanofabrication-club.github.io/club_website/` — no
`index.html` suffix. Both forms serve the same bytes; picking one and stating it in the
canonical tag is what stops Google from treating them as two competing pages.

!!! tip "There is deliberately no og:image"
    No image file exists in this repo, and `CLAUDE.md` forbids external assets, so there is
    nothing to point `og:image` at and inventing a URL would produce a broken unfurl — worse
    than none, because a card with a failed image looks abandoned. When someone adds a real
    image, add exactly two lines and change one:

    ```html
    <meta property="og:image" content="https://minnesota-nanofabrication-club.github.io/club_website/og-etcher.png">
    <meta property="og:image:alt" content="The reactive ion etcher chamber on the bench">
    ```

    and switch `twitter:card` from `summary` to `summary_large_image`. Use an absolute URL —
    relative `og:image` paths are not resolved by most unfurlers. Target 1200×630 px and
    under 1 MB.

---

## Every tag, and what breaks without it

| Tag | What it does | What it affects | What breaks if omitted or wrong |
| --- | --- | --- | --- |
| `lang="en"` on `<html>` | Declares the page language | Screen-reader pronunciation, Google's language targeting, browser translation prompts | Screen readers may read English with the wrong phoneme set; Chrome offers to translate an English page into English. Never a ranking penalty, always an accessibility bug. Already present on both existing pages — do not drop it |
| `<meta charset="UTF-8">` | Declares the byte encoding | Rendering of every non-ASCII character | `1100 °C` and `10×` render as mojibake. Must be within the first 1024 bytes of the document, which is why it stays the first line of `<head>` |
| `<meta name="viewport">` | Sets the mobile layout viewport | Mobile rendering | The page renders zoomed-out at desktop width on phones. Google indexes the mobile rendering, so this is one of the few tags with a genuine ranking consequence |
| `<title>` | The page name | The blue clickable line in results, the browser tab, the default share text, the bookmark name | A missing or generic title is the single most damaging omission here. Google will synthesize one from the page's headings, and `Minnesota Nanofabrication Club` on all nine pages makes them indistinguishable in results — a reader cannot tell the etcher page from the furnace page and clicks neither |
| `<meta name="description">` | A summary for search engines | The grey snippet under the title. **Not a ranking factor** | Google generates a snippet from whatever page text matches the query — often a stray sentence from the middle of a table. The page still ranks identically; it just pitches itself badly and gets fewer clicks |
| `<link rel="canonical">` | Declares the one true URL | Which URL Google indexes and shows | Without it, `/club_website/`, `/club_website/index.html`, and any URL with a tracking parameter appended look like separate duplicate pages competing with each other. **A wrong canonical is far worse than none** — pointing every subpage at the home page tells Google the subpages are duplicates and it will drop them from the index entirely |
| `og:type` | Content class for social unfurls | Card layout on Facebook, LinkedIn, Discord, Slack | Defaults to `website`, which is merely imprecise. Use `article` for machine pages, `website` for the home page |
| `og:site_name` | The site the page belongs to | The small label above the card title | The unfurl shows the raw host `minnesota-nanofabrication-club.github.io`, which reads like a personal repo rather than a club |
| `og:title` | Card headline | Discord, Slack, LinkedIn, iMessage previews | Unfurlers fall back to `<title>`, so this is a safety net rather than a necessity — but keep it in sync, because a stale `og:title` left behind after a `<title>` edit is a silent inconsistency nobody notices until a link is shared |
| `og:description` | Card body text | Same surfaces | The card shows a title and nothing else, or a scrape of the first body text — usually the site-wide header boilerplate, identical on all nine pages |
| `og:url` | The canonical URL for social platforms | Link deduplication and share counts | Shares of `?utm_source=...` variants are counted as different pages. Keep it byte-identical to the `canonical` href |
| `twitter:card` | Twitter/X card style | Card rendering on X, and some other unfurlers that read Twitter tags first | The link renders as a bare URL on X. `summary` is correct while there is no image; `summary_large_image` without an `og:image` produces an empty grey box |
| `<link rel="stylesheet">` | Loads `style.css` | Everything visual | Kept last in `<head>` here purely as house convention — no SEO effect |

!!! danger "Never add `<meta name=\"robots\" content=\"noindex\">`"
    It is the only tag in this area that can remove the site from Google outright, and it
    fails silently: the page loads fine, looks fine, and simply stops existing in search.
    There is no reason for any page on this site to carry it. If a page must be hidden,
    keep it out of the repo — GitHub Pages serves the branch verbatim, and `noindex` is not
    access control anyway.

---

## Writing titles and descriptions for this site

**Write the title for the search a stranger types, not for the club's internal name for the
tool.** Nobody outside the club searches `Etcher`. People building fab equipment search
`DIY reactive ion etcher`, `homemade RIE`, `hacker fab plasma etcher`. The club's word for
the machine belongs in the `<h2>`; the searcher's words belong in the `<title>`. If the
title only contains the internal name, the page is only findable by people who already know
the club exists — which is the one audience that does not need search.

The formula, in order:

```
[what a stranger would search] [distinguishing detail] &mdash; [club name]
```

Rules that follow from it:

| Rule | Why |
| --- | --- |
| Aim for 50&ndash;60 characters | Google truncates around 60. Past that the club name gets cut and the result looks anonymous |
| Front-load the machine words | Truncation eats the end. `MNF: Etcher` puts the only useful word where it may get cut |
| Suffix is `Minnesota Nanofabrication Club`, or `MNF` when that overflows | `MNF` is the short form the club uses. Use the long form on `index.html`, where it is the primary search term |
| Every page gets a different title | Nine pages with one title compete with each other and Google picks one to show. The other eight effectively vanish |
| `DIY`, `open-source`, `student-built`, `homemade` are the qualifiers that match real intent | They are how people searching for buildable versions distinguish them from commercial equipment listings |

For descriptions: 140&ndash;160 characters, one or two sentences, containing the machine name,
the fact that students built it, and one concrete detail from the Drive doc. It is a pitch,
not a summary — the reader has already seen the title and is deciding whether to click.

### Before and after

**Etcher** — Drive folder is empty, status `Planned`. This is the constrained case:

| | |
| --- | --- |
| Before | `<title>Etcher &mdash; Minnesota Nanofabrication Club</title>` |
| After | `<title>DIY Reactive Ion Etcher (RIE) &mdash; MNF</title>` |
| Description | `A student-built reactive ion etcher for the Minnesota Nanofabrication Club's open fab line at the University of Minnesota. Planned &mdash; design not yet started.` |

`Etcher` alone matches nothing; `reactive ion etcher` and `RIE` are the terms in the
literature and in the searches. Note what the description does **not** do: it names no
gas, no power, no chamber, because the Drive folder contains no doc that says any of those.
Saying `Planned` plainly is the honest version and costs nothing — a reader looking for a
completed build leaves either way, and a reader looking for a project to join stays.

**Tube Furnace** — `Design complete`, with a real sourced spec:

| | |
| --- | --- |
| Before | `<title>Tube Furnace &mdash; Minnesota Nanofabrication Club</title>` |
| After | `<title>DIY 1100 &deg;C Tube Furnace for Wafer Oxidation &mdash; MNF</title>` |
| Description | `A kanthal-element tube furnace built by University of Minnesota students to reach 1100 &deg;C for annealing and oxidizing doped silicon wafers. Design complete.` |

`1100 °C`, `kanthal`, and `wafer oxidation` all come from the project's Drive docs and are
already on `index.html`. Each one is a phrase a person searching for exactly this build
would type; `Tube Furnace` alone competes with every ceramics kiln on the internet.

**DC Magnetron Sputterer** — `In design`:

| | |
| --- | --- |
| Before | `<title>Sputterer &mdash; Minnesota Nanofabrication Club</title>` |
| After | `<title>DIY DC Magnetron Sputtering System for Thin Films &mdash; MNF</title>` |
| Description | `A student-built DC magnetron sputtering chamber for depositing metal thin films, built by University of Minnesota students. Currently in design.` |

`DC magnetron` earns its place in the title because it is what Drive actually records, and it
is a far more specific query than `sputtering`. **Do not upgrade it to `RF` because RF would
be more impressive.** RF drive and DC drive deposit different materials, so the swap is a
capability claim, and a searcher looking for an RF chamber who lands on a DC one has been
misled by the club's own page. The title has to trace to Drive exactly as the body copy does.

!!! warning "Do not put a BOM cost or a vendor into a title or description"
    Meta tags feel like metadata rather than published content, which is exactly why this
    slips through. They are published content: indexed, cached by third parties, and shown
    in results and unfurls. Every item on the never-publish list in `CLAUDE.md` — budgets,
    funding status, vendor names, pricing, BOM costs, sponsorship or professor-outreach
    correspondence, `[MASTER]` to-do lists — is equally forbidden here. `Thorlabs` and
    `Basler` appear in the stepper's Key Components table as technical specification with
    no pricing attached; a description reading `built for under $800 using surplus Thorlabs
    optics` is a budget disclosure and must not be written.

---

## Structured data

JSON-LD is a `<script>` block placed at the end of `<body>`, describing the page in
schema.org vocabulary. It does not improve ranking. What it does is let Google resolve
entity questions it would otherwise guess at — that `MNF` and `Minnesota
Nanofabrication Club` are one organization, that the organization sits inside the
University of Minnesota, and that a machine page is technical documentation rather than a
product listing.

!!! danger "HTML entities do not work inside JSON-LD"
    The rest of this repo writes em dashes as `&mdash;`, and inside a
    `<script type="application/ld+json">` block that convention silently corrupts the data.
    Script content is not HTML-parsed: the JSON parser receives the literal seven
    characters `&mdash;` and stores them in the string. Google then reads a description
    containing `&mdash;` as text. Inside JSON-LD, and only there, write a literal `—`
    character, and escape `"` as `\"` and `\` as `\\` per JSON rules.

### Home page — `Organization`

Paste before `</body>` in `index.html`:

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "name": "Minnesota Nanofabrication Club",
  "alternateName": "MNF",
  "url": "https://minnesota-nanofabrication-club.github.io/club_website/",
  "description": "A student organization at the University of Minnesota Twin Cities building an open, vertically integrated semiconductor program — designing a custom compute kernel, developing the fabrication equipment and processes to manufacture it, and integrating both into a functioning silicon system.",
  "email": "jin00404@umn.edu",
  "parentOrganization": {
    "@type": "CollegeOrUniversity",
    "name": "University of Minnesota Twin Cities"
  }
}
</script>
```

Every field traces to `index.html`, which traces to Drive. `description` is a compression of
the About section; `email` is the one address the club has agreed to publish, already live in
the Get Involved section.

**Fields deliberately absent, and what it would take to add them:**

| Field | Why it is missing | To add it |
| --- | --- | --- |
| `logo` | No image exists in the repo | Commit a square PNG of at least 112×112 px, reference it by absolute URL. This is the one real gap — Google's organization display prefers a logo |
| `foundingDate` | Not recorded in any Drive doc | Confirm the founding date with Leonard, then add `"foundingDate": "YYYY-MM-DD"` |
| `sameAs` | No public social or directory profiles are known | Once the club has a GopherLink directory entry, a GitHub org page, or a Discord invite that is meant to be public, list them as an array. `sameAs` is the strongest single signal for tying `MNF` to this club |
| `address` | Not published anywhere on the site | Only if the club decides a physical location should be public |
| `url` on `parentOrganization` | The campus URL is not cited in any Drive doc or on the site | Add it once someone confirms the exact URL resolves. A wrong URL here asserts a false relationship |
| Member or officer names | Publishing rule 2 in `CLAUDE.md` | Officers *may* be named, since they are already public through RSO registration. Members may not, and structured data is a poor place to relitigate that — see [The Officer Roster Decision](../background/roster-decision.md) |

`EducationalOrganization` was the obvious alternative, and it is wrong: in schema.org it
means a school, college, or similar institution that provides instruction. This is a student
club inside one. `Organization` with a `CollegeOrUniversity` parent states that relationship
correctly, which is the whole point of including the block.

### Machine subpage — `TechArticle`

Paste before `</body>`, changing the four values that vary:

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "DIY Reactive Ion Etcher (RIE)",
  "description": "A student-built reactive ion etcher for the Minnesota Nanofabrication Club's open fab line at the University of Minnesota. Planned — design not yet started.",
  "url": "https://minnesota-nanofabrication-club.github.io/club_website/etcher.html",
  "inLanguage": "en",
  "about": {
    "@type": "Thing",
    "name": "Reactive ion etcher"
  },
  "author": {
    "@type": "Organization",
    "name": "Minnesota Nanofabrication Club"
  },
  "publisher": {
    "@type": "Organization",
    "name": "Minnesota Nanofabrication Club",
    "url": "https://minnesota-nanofabrication-club.github.io/club_website/"
  },
  "isPartOf": {
    "@type": "WebSite",
    "name": "Minnesota Nanofabrication Club",
    "url": "https://minnesota-nanofabrication-club.github.io/club_website/"
  }
}
</script>
```

`headline` is the title without the club suffix; `description` matches the meta description
verbatim; `url` matches the canonical; `about.name` is the generic machine name.

**Why `TechArticle`,** given the alternatives:

| Type | Verdict |
| --- | --- |
| `TechArticle` | **Chosen.** These pages are exactly what the type describes: a technical write-up of a system — what it is, how it works, its components, its schedule. It carries no eligibility promise that the page cannot keep, and it is a documented, widely-consumed subtype of `Article` |
| `Product` | Rejected. It asserts the machine is a thing for sale. Google's product handling expects `offers`, `price`, `availability`, and `review` data that will never exist here, and asserting a commercial relationship the club does not have is a false claim, not just an unhelpful one |
| `HowTo` | Rejected. These pages describe a system; they are not ordered build instructions. Google also retired `HowTo` rich results, so the type buys nothing even where it fits |
| `CreativeWork` | Rejected as too weak. It is `TechArticle`'s grandparent and says only "someone made something." If a more specific accurate type exists, use it |
| `Project` | Not a schema.org type at all. The nearest real option is `CreativeWork` |

Add `"datePublished"` and `"dateModified"` (as `YYYY-MM-DD`) once someone is willing to keep
them accurate. **Do not add them otherwise:** a `dateModified` frozen at the day the page was
written is a stale-freshness claim, and it is worse than no date because it actively misleads
rather than merely omitting.

### Validating a block

Paste the rendered page source into the Schema Markup Validator (`validator.schema.org`),
which reports JSON syntax errors and unrecognized properties for any type. Google's Rich
Results Test (`search.google.com/test/rich-results`) is the wrong tool here — it only
evaluates types eligible for rich results, and will report "no rich results detected" for a
perfectly valid `TechArticle`. That message is not an error.

Neither validator can tell you that a correctly-formed claim is false. That is a human review
job, and it is the failure mode that matters here.

---

## `robots.txt` and `sitemap.xml`

### `robots.txt`

`robots.txt` at the repo root allows all crawlers and points at the sitemap. It needs no
routine maintenance.

!!! note "It may not be served where crawlers look for it"
    `robots.txt` is a **per-host** file. Crawlers fetch it from
    `https://minnesota-nanofabrication-club.github.io/robots.txt` — the domain root — and
    never from `/club_website/robots.txt`. Because this is a project page on a subpath, the
    file in this repo is only authoritative if the organization publishes no separate
    root-level Pages site. This is not a problem to fix: the file allows everything, so
    being ignored changes nothing, and the sitemap is submitted directly in Search Console
    anyway. It is documented here so nobody spends an afternoon debugging why the file
    "isn't working."

### `sitemap.xml`

`sitemap.xml` lists every page with its last-modified date, so Google can discover subpages
without having to crawl its way to them through links. It is generated, never hand-edited:

```bash
python3 scripts/generate_sitemap.py           # rewrite sitemap.xml
python3 scripts/generate_sitemap.py --check   # exit 1 if it is stale; writes nothing
```

The script has no dependencies, walks `*.html` in the repo root only, and takes each page's
`<lastmod>` from `git log -1 --format=%cs`, falling back to the filesystem mtime for a file
that has never been committed. Output is sorted with `index.html` first and rewritten only
when the bytes actually change, so repeated runs produce no diff — a sitemap that churned on
every run would put a meaningless commit into every sync pull request and train reviewers to
skim past the file.

| Situation | What to do |
| --- | --- |
| Added a new `*.html` page | Run the script and commit `sitemap.xml` alongside the page |
| Renamed or deleted a page | Run the script; the stale entry disappears. A `<loc>` pointing at a deleted page reports a 404 in Search Console |
| Edited an existing page's copy | Nothing. `<lastmod>` updates by itself on the next run after the commit lands |
| Reviewing a sync pull request | If a page was added and `sitemap.xml` was not regenerated, ask for it |

!!! warning "Nothing runs this automatically"
    The sync workflow does not call it, and no other CI job does either. A new machine page
    therefore lands on the site absent from the sitemap, and the omission is invisible — the
    page renders and links fine, it is just slower for Google to find. Regenerating is a manual
    step in the same commit as the new page.

    Wiring it into `.github/workflows/sync-from-drive.yml` is a reasonable change, and note
    that the sync **agent** cannot make it: the guard step fails any run that touches
    `.github/` or `scripts/`. It is a human's change, along with the corresponding update to
    [Anatomy of a Sync Run](../operations/sync-run.md).

---

## What has to be done outside the repo

Four things, none of which live in version control, and the site gets a fraction of the
benefit until they are done. All require Leonard, or whoever holds the club's Google account.

### 1. Verify the site in Google Search Console

Go to `search.google.com/search-console` and add a **URL prefix** property for exactly:

```
https://minnesota-nanofabrication-club.github.io/club_website/
```

**Use the URL-prefix property type, not Domain.** Domain verification requires a DNS `TXT`
record, and nobody at the club controls DNS for `github.io`. Choose the **HTML file upload**
verification method: it hands over a file named like `google1a2b3c4d5e6f.html`, which gets
committed to the repo root, merged to `main`, and left there permanently — deleting it later
un-verifies the property. GitHub Pages serves it verbatim, so no configuration is involved.

`scripts/generate_sitemap.py` will pick that file up as a page and list it in the sitemap,
because it is a `*.html` file in the repo root. Harmless but untidy; to suppress it, add the
filename to `EXCLUDED_FILENAMES` near the top of the script and regenerate.

The alternative method, an HTML `<meta name="google-site-verification">` tag in
`index.html`'s `<head>`, also works and needs no extra file. Either is fine; the file method
survives an accidental `<head>` rewrite, the tag method survives nothing being committed to
the root.

Without verification there is no way to see which queries reach the site, which pages are
indexed, or which are erroring — SEO becomes guesswork with no feedback.

### 2. Submit the sitemap

Once verified: **Sitemaps** in the left nav, submit `sitemap.xml` (relative to the property
prefix). Check back in a few days — the report shows how many URLs were discovered and lists
any that failed. This is the step that gets the nine machine pages crawled promptly rather
than eventually.

### 3. Confirm the GitHub Pages settings

Under **Settings → Pages** on the repository, confirm:

| Setting | Required value | If wrong |
| --- | --- | --- |
| Source | Deploy from a branch — `main`, folder `/ (root)` | Nothing publishes, or the wrong directory does |
| Custom domain | Empty | A custom domain changes the base URL, which invalidates every canonical, `og:url`, and sitemap `<loc>` in the repo. If the club ever buys a domain, that is a repo-wide find-and-replace plus a **new** Search Console property |
| Enforce HTTPS | On | Mixed `http`/`https` URLs look like duplicate pages, and every URL written in this repo is `https` |
| Visibility | Public | A private Pages site cannot be crawled at all |

Nothing in the repo controls these — see [Deployment](../operations/deployment.md).

### 4. Ask for inbound links

The one item with real upside, and the only one that is not a settings change. Concretely:
ask the Hacker Fab community to list the club on `docs.hackerfab.org`; ask UMN ECE to link
the club from a department or student-organizations page; make sure the club's entry in the
university's student-organization directory carries the site URL. Each is an email. Together
they are worth more than everything else in this guide.

---

## Pre-publish checklist

For any new machine page, before merging:

- [ ] `<title>` is unique across the site, under ~60 characters, and leads with the words a stranger would search
- [ ] `<meta name="description">` is 140&ndash;160 characters and every claim in it traces to a Drive doc
- [ ] `canonical` and `og:url` are identical, absolute, `https`, and contain the real filename
- [ ] `og:title` and `og:description` match `<title>` and the meta description
- [ ] `og:type` is `article` (`website` only on `index.html`)
- [ ] No `og:image` unless an image file is actually committed
- [ ] JSON-LD block present, with literal `—` rather than `&mdash;`, and validated
- [ ] No budget, vendor pricing, or member name anywhere in the head or the JSON-LD
- [ ] `python3 scripts/generate_sitemap.py` run, and `sitemap.xml` in the same commit
- [ ] Previewed with `python3 -m http.server 8000`

---

## Common pitfalls

- **Copying the head template and forgetting to change the URLs.** The most likely error by a
  wide margin, and the most damaging: nine pages whose canonical points at `etcher.html`
  tells Google there is one page, and eight machine pages drop out of the index. There is no
  warning; the pages look perfect. Search for the old filename after every paste.
- **Writing a description the Drive folder does not support.** Nothing removes it. The sync
  only adds and corrects against Drive, so the invented sentence stays, and it is now the
  text Google shows for the page.
- **Letting `og:title` drift from `<title>`.** A title edit that misses the Open Graph tag
  produces a page that says one thing in search and another in Discord. Nothing checks this.
- **Using `&mdash;` inside JSON-LD.** The entity is stored literally and shipped to Google as
  text. See the admonition above.
- **Adding `og:image` pointing at a file that is not in the repo.** A card with a failed image
  renders worse than a card with no image.
- **Regenerating `sitemap.xml` on a dirty tree and committing unrelated changes with it.** Run
  the script as its own step, and check `git diff` before staging.
- **Expecting tags to substitute for links.** They do not. Re-read
  [what this can and cannot do](#what-this-can-and-cannot-do) before concluding the markup
  failed.
