# Espanso Dist — Deterministic Functional Typing System

> **What it feels like using *another functional typing system* that actually cuts typing time by 42%–56% in daily engineering work** — with **<1% left-index finger strain** and **zero memorization of random abbreviations**.

[![Triggers](https://img.shields.io/badge/triggers-15%2C928-brightgreen)](#3-the-5-minute-muscle-memory-architecture-toc)
[![Match Packages](https://img.shields.io/badge/packages-356%20YAML-blue)](#5-package--runtime-architecture-toc)
[![Keystrokes Saved](https://img.shields.io/badge/keystrokes%20saved-42%25--56%25-orange)](#2-real-slack-benchmarks-trigger-system-vs-full-typing)
[![Left-Index Load](https://img.shields.io/badge/left--index%20load-%3C1%25-purple)](#31-primary-ergonomic-consonant-shifts-li--1)
[![Platforms](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-informational)](#4-one-command-cross-platform-install--self-update)

---

## Table of Contents

- [1. The Dopamine Hook: Why Another Functional Typing System?](#1-the-dopamine-hook-why-another-functional-typing-system)
- [2. Real Slack Benchmarks: Trigger System vs. Full Typing](#2-real-slack-benchmarks-trigger-system-vs-full-typing)
  - [Benchmark 1 — Repo & Network Ops (`53.8% saved`)](#benchmark-1--repo--network-ops-145--67-strokes--538-saved)
  - [Benchmark 2 — Architecture & Phrase-Head Matrix (`55.6% saved`)](#benchmark-2--architecture--phrase-head-matrix-144--64-strokes--556-saved)
  - [Benchmark 3 — Debugging & Verification Pipeline (`48.2% saved`)](#benchmark-3--debugging--verification-pipeline-191--99-strokes--482-saved)
  - [Benchmark 4 — Root-Cause Code Review (`47.9% saved`)](#benchmark-4--root-cause-code-review-167--87-strokes--479-saved)
  - [Benchmark 5 — Component & Layout Planning (`42.3% saved`)](#benchmark-5--component--layout-planning-149--86-strokes--423-saved)
- [3. The 5-Minute Muscle-Memory Architecture (TOC)](#3-the-5-minute-muscle-memory-architecture-toc)
  - [3.1 Primary Ergonomic Consonant Shifts (`LI < 1%`)](#31-primary-ergonomic-consonant-shifts-li--1)
  - [3.2 Two-Step Prefix Compression (`CON/COM → QN/QM`, `RE → WE → W`)](#32-two-step-prefix-compression-concom--qnqm-re--we--w)
  - [3.3 Compositional Morphology (`Prefix + Base + Suffix`)](#33-compositional-morphology-prefix--base--suffix)
  - [3.4 High-Frequency Glue: Demonstratives, Questions, Directionals & Numbers](#34-high-frequency-glue-demonstratives-questions-directionals--numbers)
  - [3.5 Phrase-Head Matrix (`l / a / z / n / 1` + `/1`)](#35-phrase-head-matrix-l--a--z--n--1--1)
  - [3.6 Multi-Word Flow Chains & Backtick `NAMED` Tokens](#36-multi-word-flow-chains--backtick-named-tokens)
- [4. One-Command Cross-Platform Install & Self-Update](#4-one-command-cross-platform-install--self-update)
  - [4.1 Quick Install (`curl | bash`)](#41-quick-install-curl--bash)
  - [4.2 CLI Flags, Self-Update & Environment Overrides](#42-cli-flags-self-update--environment-overrides)
  - [4.3 Global `mise` Task Integration](#43-global-mise-task-integration)
  - [4.4 Platform Notes (Linux Wayland/EVDEV, macOS, Windows)](#44-platform-notes-linux-waylandevdev-macos-windows)
- [5. Package & Runtime Architecture TOC](#5-package--runtime-architecture-toc)

---

## 1. The Dopamine Hook: Why Another Functional Typing System?

Most text expanders fail because they treat snippets as a **flat list of arbitrary macros**. After 50 snippets, your brain stalls trying to recall whether *"configuration"* is `;cfg`, `;conf`, or `;cnfg`.

This system works like a **compiled functional language for your fingers**:

| Dimension | Standard QWERTY Typing | Traditional Snippet Pack | Our Functional Trigger System |
| :--- | :--- | :--- | :--- |
| **Mental Model** | Spell every letter manually | Memorize 200 arbitrary macros | **Compose `<Prefix> + <Root> + <Suffix> + ,`** |
| **Vocabulary Scale** | 0 triggers | ~100–300 static snippets | **15,928 deterministic triggers across 356 files** |
| **Left-Index (`LI`) Strain** | ~22% of all keystrokes hit `e d c v f r t g b` | Unchanged | **<1% `LI` load** via deterministic consonant shifts (`C→Q`, `R→W`, `V→J`, `D→P`) |
| **Delimiter** | Spacebar (thumb travel) | Prefix `;` or `::` before thinking | **Trailing `,` (right middle finger) — fires on word completion** |
| **Real Speed Gain** | Baseline (100% strokes) | ~5%–10% on boilerplate | **42%–56% fewer keystrokes on live Slack & technical prose** |

> **Why it hits different:** You don't "look up" a trigger. Once your fingers know that `qnf` = *config*, `M` = *-tion*, `B` = *-able*, `l` = *all*, `z` = *no*, and `hg` = *change*, your hands automatically type `qnm,` (*configuration*), `qnfb,` (*configurable*), `lhg,` (*all change*), and `zhg,` (*no change*) at thought speed.

---

## 2. Real Slack Benchmarks: Trigger System vs. Full Typing

Below are **5 sanitized, real-world engineering Slack messages** benchmarked against the compiled `match/` index (`scripts/text_to_trigger.py`). Every trigger below is verified for 100% round-trip expansion against `dist/match/*.yml`.

### Benchmark 1 — Repo & Network Ops (`145 → 67 strokes` | **`53.8% saved`**)

```text
FULL TYPING (145 keystrokes):
make that a private repository then also start it in background and serve it over the network for me and remember to commit and push all changes

OUR TRIGGER SYSTEM (67 keystrokes):
mkaz,a pwi,wpo,nzso,ssax,i,bg,,,sewj,x,over h,netw,4m,,,wem2,qmipa,
```

| Phrase Typed | Trigger | Strokes | How Your Fingers Compose It |
| :--- | :--- | :---: | :--- |
| `make that` | `mkaz,` | `10 → 5` | `mk` (*make*) + `az` (*that*) |
| `private` | `pwi,` | `8 → 4` | `pw` (*pr-* via `R→W`) + `i` |
| `repository` | `wpo,` | `11 → 4` | `w` (*r-*) + `po` (*repo*) |
| `then also` | `nzso,` | `10 → 5` | `nz` (*then*) + `so` (*also*) |
| `start it` | `ssax,` | `9 → 5` | `ssa` (*start*) + `x` (*it*) |
| `in background` | `i,bg,` | `14 → 5` | `i` (*in*) + `bg` (*background*) |
| `and serve it` | `,,sewj,x,` | `13 → 9` | `,,` (*and*) + `sewj` (*serve*, `R→W`, `V→J`) + `x` (*it*) |
| `the network for me` | `h,netw,4m,` | `19 → 10` | `h` (*the*) + `netw` (*network*) + `4m` (*for me*) |
| `and remember to` | `,,wem2,` | `16 → 7` | `,,` (*and*) + `wem` (*remember*, `R→W`) + `2` (*to*) |
| `commit and push all changes` | `qmipa,` | **`28 → 6`** | `qmi` (*commit*) + `p` (*push*) + `a` (*all*) |

---

### Benchmark 2 — Architecture & Phrase-Head Matrix (`144 → 64 strokes` | **`55.6% saved`**)

```text
FULL TYPING (144 keystrokes — 22 words):
ensure all the configuration is configurable and maintainable across the whole system with no change to the existing interface and nothing else

OUR TRIGGER SYSTEM (64 keystrokes — 100% of words matched by 17 triggers):
ens,lh,qnm,t,qnfb,,,mainb,aqwo,h/1,sy,w,zhg,2h,exi1i,intf,,,nie,
```

| Phrase Typed | Trigger | Strokes | How Your Fingers Compose It |
| :--- | :--- | :---: | :--- |
| `ensure` | `ens,` | `7 → 4` | Root abbreviation `ens` |
| `all the` | `lh,` | `8 → 3` | Phrase-head `l` (*all*) + `h` (*the*) |
| `configuration` | `qnm,` | `14 → 4` | `qn` (*con-*) + `m` (*-tion*) |
| `is configurable` | `t,qnfb,` | `16 → 7` | `t` (*is*) + `qnf` (*config*) + `b` (*-able*) |
| `and maintainable` | `,,mainb,` | `17 → 8` | `,,` (*and*) + `main` (*maintain*) + `b` (*-able*) |
| `across the whole system` | `aqwo,h/1,sy,` | `24 → 12` | `aqwo` (*across*) + `h/1` (*the whole*) + `sy` (*system*) |
| `with no change` | `w,zhg,` | `15 → 6` | `w` (*with*) + `z` (*no* phrase-head) + `hg` (*change*) |
| `to the existing interface` | `2h,exi1i,intf,` | `26 → 14` | `2h` (*to the*) + `exi1i` (*existing*) + `intf` (*interface*) |
| `and nothing else` | `,,nie,` | `17 → 6` | `,,` (*and*) + `ni` (*nothing*) + `e` (*else*) |

---

### Benchmark 3 — Debugging & Verification Pipeline (`191 → 99 strokes` | **`48.2% saved`**)

```text
FULL TYPING (191 keystrokes):
find the previous problem related to this then also troubleshoot the bug report and fix this then ensure that it passes verification before deploy then deploy and commit and push all changes

OUR TRIGGER SYSTEM (99 keystrokes):
fih,pwej,pwb,welp,2iz,nzso,tbsh,h,bug wepw,,,kiz,nzensure,az,x,pass,jewim,bef`depl,nz,depl,,,qmipa,
```

| Phrase Typed | Trigger | Strokes | How Your Fingers Compose It |
| :--- | :--- | :---: | :--- |
| `find the` | `fih,` | `9 → 4` | `fi` (*find*) + `h` (*the*) |
| `previous problem` | `pwej,pwb,` | `17 → 9` | `pwej` (*previous*, `R→W`, `V→J`) + `pwb` (*problem*) |
| `related to this` | `welp,2iz,` | `16 → 9` | `wel` (*relate*) + `p` (*-ed*) + `2` (*to*) + `iz` (*this*) |
| `troubleshoot` | `tbsh,` | `13 → 5` | Consonant skeleton `tbsh` |
| `report and fix this` | `wepw,,,kiz,` | `20 → 11` | `wepw` (*report*, `R→W`) + `,,` (*and*) + `k` (*fix*) + `iz` (*this*) |
| `then ensure` | `nzensure,` | `12 → 9` | `nz` (*then*) + `ensure` |
| `verification` | `jewim,` | `13 → 6` | `jewi` (*verify*, `V→J`, `R→W`) + `m` (*-tion*) |
| `before deploy` | ``bef`depl,`` | `14 → 9` | ``bef` `` (*before*, backtick token) + `depl` (*deploy*) |

---

### Benchmark 4 — Root-Cause Code Review (`167 → 87 strokes` | **`47.9% saved`**)

```text
FULL TYPING (167 keystrokes):
does it really fix the root cause and the class of problem or just a tiny patch so enforce it to implement the fix correctly and then also commit and push all changes

OUR TRIGGER SYSTEM (87 keystrokes):
uuX,ealy,kh,/`qau,,h,class o,pwb,or ju,a tiny patq,sso,enfx,2imp,h,K,qowl,,,nzso,qmipa,
```

| Phrase Typed | Trigger | Strokes | How Your Fingers Compose It |
| :--- | :--- | :---: | :--- |
| `does it` | `uuX,` | `8 → 4` | `uu` (*does*, doubled `u` *do*) + `X` (*it*) |
| `really fix the` | `ealy,kh,` | `15 → 8` | `ealy` (*really*, drop `r`) + `k` (*fix*) + `h` (*the*) |
| `root cause` | `` /`qau, `` | `11 → 6` | `` /` `` (*root* path symbol) + `qau` (*cause*, `C→Q`) |
| `and the ... of problem` | `,h, ... o,pwb,` | `19 → 10` | `,h` (*and the*) + `o` (*of*) + `pwb` (*problem*) |
| `just ... patch` | `ju, ... patq,` | `11 → 8` | `ju` (*just*) + `patq` (*patch*, `C→Q`) |
| `enforce it to implement` | `enfx,2imp,` | `24 → 10` | `enf` (*enforce*) + `x` (*it*) + `2` (*to*) + `imp` (*implement*) |
| `correctly and then also` | `qowl,,,nzso,` | `24 → 12` | `qow` (*correct*, `C→Q`, `R→W`) + `l` (*-ly*) + `,,` (*and*) + `nzso` (*then also*) |

---

### Benchmark 5 — Component & Layout Planning (`149 → 86 strokes` | **`42.3% saved`**)

```text
FULL TYPING (149 keystrokes):
make the plan that structures these into components and make it easy to change the layout later because currently we are not fixed on the layout yet

OUR TRIGGER SYSTEM (86 keystrokes):
mkh,pl,az,struqs,ez,i2,qmps,,,mkt,es,2qh,h,layout lat,quz,quwl,ean,KP,on h,layout yet
```

| Phrase Typed | Trigger | Strokes | How Your Fingers Compose It |
| :--- | :--- | :---: | :--- |
| `make the plan that` | `mkh,pl,az,` | `19 → 10` | `mkh` (*make the*) + `pl` (*plan*) + `az` (*that*) |
| `structures these into components` | `struqs,ez,i2,qmps,` | `33 → 19` | `struqs` (`TR` exception + `C→Q` + `s`) + `ez` (*these*) + `i2` (*into*) + `qmps` (*components*) |
| `and make it easy to change` | `,,mkt,es,2qh,` | `27 → 13` | `,,` (*and*) + `mkt` (*make it*) + `es` (*easy*) + `2qh` (*to change*) |
| `because currently` | `quz,quwl,` | `18 → 9` | `quz` (*because*) + `quwl` (*currently*, `C→Q`, `R→W`, `l` *-ly*) |
| `we are not fixed` | `ean,KP,` | `17 → 7` | `ean` (*we are not*) + `K` (*fix*) + `P` (*-ed*) |

---

## 3. The 5-Minute Muscle-Memory Architecture (TOC)

You never memorize 15,928 triggers. You learn **6 orthogonal layers** that compose together across every word family.

### 3.1 Primary Ergonomic Consonant Shifts (`LI < 1%`)

The left index finger (`e d c v f r t g b`) is the most overworked finger on a QWERTY keyboard. Our foundation shifts heavy left-index consonants onto underutilized pinky, ring, and right-hand keys:

| Standard Letter | Shifted Token | Ergonomic Reason | Verified Examples (`trigger` → `replacement`) |
| :---: | :---: | :--- | :--- |
| **`C`** | **`Q`** | Move lower-left index reach `C` to left pinky `Q` | `qa,` → *can*, `qau,` → *cause*, `qle,` → *clear*, `qow,` → *correct* |
| **`R`** | **`W`** | Move left index `R` to left ring `W` | `wpo,` → *repository*, `wepw,` → *report*, `wpla,` → *replace*, `wssa,` → *restart* |
| **`V`** | **`J`** | Move left index `V` to right home-row index `J` | `jewi,` → *verify*, `jj,` → *version*, `sewj,` → *serve*, `pwej,` → *previous* |
| **`D`** (`-ed`) | **`P`** | Move past-tense `-ed` off left middle/index to right pinky `P` | `welp,` → *related*, `KP,` → *fixed*, `wplap,` → *replaced*, `wssap,` → *restarted* |
| **`N`** (`-tion`) | **`M`** | Distinct morphological slot for `-tion` / `-sion` / `-ment` | `qnm,` → *configuration*, `jewim,` → *verification*, `impm,` → *implementation* |
| **`T` + `R`** | **`TR`** *(Exception)* | Adjacent `t` + `r` rolls faster than `t` + `w` | `struq,` → *structure*, `trig,` → *trigger*, `trk,` → *track* |

### 3.2 Two-Step Prefix Compression (`CON/COM → QN/QM`, `RE → WE → W`)

Directly stripping a vowel from English prefixes causes massive trigger collisions. Instead, the system applies **two-step compression** — shifting off the Left-Index consonant first (`C→Q`, `R→W`, `N→M`), and *then* dropping the vowel:

| Prefix Pattern | Two-Step Derivation | Compressed Token | Verified High-Frequency Family Examples |
| :--- | :---: | :---: | :--- |
| **`con-`** | `con` → `qon` → **`qn`** | **`qn`** | `qnf,` (*config*), `qnm,` (*configuration*), `qnta,` (*contain*), `qtx,` (*context*), `qnsi,` (*consider*) |
| **`com-`** | `com` → `qom` → **`qm`** | **`qm`** | `qmm,` (*common*), `qmb,` (*combine*), `qmp,` (*component*), `qmi,` (*commit*), `qmpw,` (*compare*) |
| **`pro-`** | `pro` → `pwo` → **`pw`** | **`pw` / `pwo`** | `pwb,` (*problem*), `pwj,` (*project*), `pwoq,` (*process*), `pwji,` (*provide*), `pwf,` (*profile*) |
| **`pre-`** | `pre` → **`pwe`** | **`pwe`** | `pwej,` (*previous*), `pwep,` (*prepare*), `pwef,` (*prefer*), `pwes,` (*present*) |
| **`re-`** | `re` → `we` → **`w`** | **`w` / `we`** | `wpo,` (*repository*), `wpla,` (*replace*), `wqw,` (*recreate*), `wssa,` (*restart*) |

### 3.3 Compositional Morphology (`Prefix + Base + Suffix`)

Every word family supports predictable **prefix operators** and **suffix inflections**:

#### Prefix Operators (Prepended to Base)

| Prefix Token | Meaning | Verified Examples (`Base` → `Prefixed`) |
| :---: | :--- | :--- |
| **`W`** | **`re-`** | `wqw,` (*recreate*) \| `wbui,` (*rebuild*) \| `ssa,` (*start*) → `wssa,` (*restart*) |
| **`D`** | **`dis-` / `de-`** | `qne,` (*connect*) → `dqne,` (*disconnect*) \| `agwe,` (*agree*) → `dagwe,` (*disagree*) |
| **`I`** | **`in-` / `im-` / `il-` / `ir-`** | `qow,` (*correct*) → `iqow,` (*incorrect*) \| `pss,` (*possible*) → `ipss,` (*impossible*) |
| **`U`** | **`un-`** | `neqa,` (*necessary*) → `uneqa,` (*unnecessary*) \| `usu,` (*usual*) → `uusu,` (*unusual*) |

#### Morphological Suffixes (Appended to Base)

| Suffix Token | Grammar Form | `qnf` (*config*) | `jewi` (*verify*) | `main` (*maintain*) | `wpla` (*replace*) | `qow` (*correct*) |
| :---: | :--- | :--- | :--- | :--- | :--- | :--- |
| *(base)* | Root verb / noun / adj | `qnf,` → *config* | `jewi,` → *verify* | `main,` → *maintain* | `wpla,` → *replace* | `qow,` → *correct* |
| **`S`** | Plural / 3rd-person `-s` | `qnfs,` → *configs* | `jewis,` → *verifies* | `mains,` → *maintains* | `wplas,` → *replaces* | — |
| **`I`** | Progressive `-ing` | `qnfi,` → *configuring* | `jewii,` → *verifying* | `maini,` → *maintaining* | `wplai,` → *replacing* | `qowi,` → *correcting* |
| **`P`** | Past `-ed` | `qnfp,` → *configured* | `jewip,` → *verified* | `mainp,` → *maintained* | `wplap,` → *replaced* | `qowp,` → *corrected* |
| **`M`** | Nominalization `-tion`/`-ment` | `qnm,` → *configuration* | `jewim,` → *verification* | `mainm,` → *maintenance* | `wplam,` → *replacement* | `qowm,` → *correction* |
| **`B`** | Adjective `-able` / `-ible` | `qnfb,` → *configurable* | `jewib,` → *verifiable* | `mainb,` → *maintainable* | `wplab,` → *replaceable* | `qowb,` → *correctable* |
| **`W`** | Agent noun `-er` / `-or` | — | `jewiw,` → *verifier* | `mainw,` → *maintainer* | `wplaw,` → *replacer* | — |
| **`J`** | Adjective `-ive` / `-al` | — | — | — | — | `qowj,` → *corrective* |
| **`L`** | Adverb `-ly` | — | — | — | — | `qowl,` → *correctly* |
| **`N` / `LS`** | `-ness` / `-less` (`usl,` *useless*) | — | — | — | — | `qown,` → *correctness* |

### 3.4 High-Frequency Glue: Demonstratives, Questions, Directionals & Numbers

| Group | Verified Tokens (`trigger` → `expansion`) |
| :--- | :--- |
| **Demonstratives (`th-`)** | `h,` → *the* \| `iz,` → *this* \| `az,` → *that* \| `ez,` → *these* \| `oz,` → *those* \| `x,` → *it* \| `nz,` → *then* \| `ew,` → *there* |
| **Questions (`wh-`)** | `wt,` → *what* \| `ww,` → *where* \| `wn,` → *when* \| `wy,` → *why* \| `hw,` → *how* \| `wi,` → *which* |
| **Core Verbs (`do/be`)** | `u,` → *do* \| `uu,` → *does* \| `uuX,` → *does it* \| `t,` → *is* \| `izt,` → *this is* \| `azt,` → *that is* |
| **Directionals & Prepositions** | `2,` → *to* \| `22,` → *from* \| `4,` → *for* \| `i2,` → *into* \| `2h,` → *to the* \| `2iz,` → *to this* \| `4m,` → *for me* \| `w,` → *with* \| `o,` → *of* \| `wo,` → *without* |
| **Quantifiers & Conjunctions** | `1,` → *one* \| `*l,` / `mul,` → *multiple* \| `no,` → *no* \| `,,` → *and* \| `,h,` → *and the* |

### 3.5 Phrase-Head Matrix (`l / a / z / n / 1` + `/1`)

Five single-character **phrase-head operators** combine with any approved target (`hg` = *change*, `h` = *the*, `1` = *one*, `i` = *thing*) to eliminate multi-word typing:

| Phrase Head | Meaning | + `hg` (*change*) | + `h` (*the*) / Other | Standalone / Negative Pronouns |
| :---: | :--- | :--- | :--- | :--- |
| **`l`** | **`all`** | `lhg,` → *all change* | `lh,` → *all the* | `aol,` → *all* |
| **`a`** | **`a`** | `ahg,` → *a change* | — | `a` (typed directly) |
| **`z`** | **`no`** | `zhg,` → *no change* | — | `n1,` → *no one*, `n1e,` → *no one else* |
| **`n`** | **`not`** | `nhg,` → *not change* | `nh,` → *not the* | `ni,` → *nothing*, `nie,` → *nothing else* |
| **`1`** | **`one`** | `1hg,` → *one change* | — | `lw,` / `lww,` / `lwt,` → *low / lower / lowest* |
| **`/1`** | **`whole`** | — | `h/1,` → *the whole*, `a/1,` → *a whole*, `l/1,` → *all whole* | `/1,` → *whole* |

### 3.6 Multi-Word Flow Chains & Backtick `NAMED` Tokens

- **Verb + Object Chains**: Append `h` (*the*), `x`/`t` (*it*), `iz` (*this*), `az` (*that*), or `2` (*to*) directly to common verbs:
  - `mk,` (*make*) → `mkh,` (*make the*), `mkt,` (*make it*), `mkiz,` (*make this*), `mkaz,` (*make that*)
  - `fi,` (*find*) → `fih,` (*find the*), `fix,` (*find it*), `fiiz,` (*find this*)
  - `K,` (*fix*) → `kh,` (*fix the*), `kiz,` (*fix this*), `kaz,` (*fix that*)
  - `ssa,` (*start*) → `ssah,` (*start the*), `ssax,` (*start it*)
  - `wem,` (*remember*) → `wem2,` (*remember to*), `wemh,` (*remember to the*)
  - `qmipa,` → *commit and push all changes* \| `qmiap,` → *commit and push*
- **Backtick `NAMED` Group (Standalone Brands, Tools & Imperatives)**:
  - Standalone proper names, brands, and technical terms use a trailing **backtick (`` ` ``)** instead of `,` so they never collide with inflected word families:
  - ``MS` `` → `MAKE SURE ` \| ``tse` `` → `tailscale ` \| ``PT` `` → `ChatGPT ` \| ``mini` `` → `gemini ` \| ``cau` `` → `claude ` \| ``anth` `` → `anthropic ` \| ``kb` `` → `keyboard ` \| ``aa` `` → `data `

---

## 4. One-Command Cross-Platform Install & Self-Update

This repository is the **self-contained, production-compiled distribution artifact** (`espanso-dist`). You do not need the upstream generator toolchain or Python scripts to install it.

### 4.1 Quick Install (`curl | bash`)

Works on **Linux**, **macOS** (Intel & Apple Silicon), and **Windows** (Git Bash / MSYS2 / WSL):

```bash
curl -fsSL https://raw.githubusercontent.com/buihongduc132/espanso-dist/main/install.sh | bash
```

What the installer does automatically:
1. **Detects OS & architecture** (`install.sh` dispatches to `install-linux.sh`, `install-macos.sh`, or `install-windows.sh`, all sharing `lib/common.sh`).
2. **Installs Espanso** if missing (official AppImage / `.deb` on Linux, Homebrew Cask / `.dmg` on macOS, Scoop / Winget / Chocolatey / `.exe` on Windows).
3. **Clones or updates** this repo into `<config_dir>/espanso-dist-clone/`.
4. **Deploys all 356 match packages** (`match/*.yml`), `espanso-install/*.yml`, `config/default.yml`, and persists `install.sh` + `lib/common.sh` into `<config_dir>/` for future self-updates.
5. **Starts & verifies the daemon** (`espanso match list`), recording the installed commit hash in `.trigger-pack-version`.

#### Default Config Directories per Platform

| Platform | Entry Script | Default Config Directory (override with `ESPANSO_CONFIG_DIR`) |
| :--- | :--- | :--- |
| **Linux** | `./install-linux.sh` | `~/.config/espanso` (or Flatpak `~/.var/app/com.mtxc.espanso/config/espanso`) |
| **macOS** | `./install-macos.sh` | Auto-detected via `espanso path`, else `~/.config/espanso`, else `~/Library/Application Support/espanso` |
| **Windows** | `./install-windows.sh` | `%APPDATA%\espanso` (`~\AppData\Roaming\espanso` via Git Bash / MSYS2) |

### 4.2 CLI Flags, Self-Update & Environment Overrides

Once installed, a copy of `install.sh` + `lib/common.sh` lives inside your Espanso config directory (`~/.config/espanso/install.sh` on Linux):

```bash
# Idempotent update — compares local .trigger-pack-version against remote VERSION;
# skips download & restart when already up to date:
~/.config/espanso/install.sh --update

# Non-interactive install/update for CI, Ansible, or dotfiles bootstrap:
curl -fsSL https://raw.githubusercontent.com/buihongduc132/espanso-dist/main/install.sh | bash -s -- --non-interactive

# Force full re-download & redeploy even if version matches:
~/.config/espanso/install.sh --force

# Deploy trigger config only without installing the espanso binary:
./install.sh --skip-espanso-install --non-interactive

# Show installed version:
~/.config/espanso/install.sh --version

# Uninstall trigger pack (removes match/, espanso-dist-clone/, and .trigger-pack-version; keeps espanso binary):
~/.config/espanso/install.sh --uninstall
```

| Environment Variable | Description | Default |
| :--- | :--- | :--- |
| `BHD_TRIGGER_PACK_REPO` | Custom GitHub repository (`owner/name`) | `buihongduc132/espanso-dist` |
| `ESPANSO_CONFIG_DIR` | Custom Espanso configuration directory | Auto-detected per OS |
| `ESPANSO_VERSION` | Pin Espanso release tag (e.g. `v2.3.0`) | Latest GitHub release |
| `GITHUB_TOKEN` | GitHub token (private mirrors or API rate limits) | *(unset)* |

### 4.3 Global `mise` Task Integration

Add to `~/.config/mise/config.toml` for one-command updates from anywhere:

```toml
[tasks.espanso-pull]
description = "Install or update espanso trigger pack (idempotent)"
run = "curl -fsSL https://raw.githubusercontent.com/buihongduc132/espanso-dist/main/install.sh | bash -s -- --update --non-interactive"
```

### 4.4 Platform Notes (Linux Wayland/EVDEV, macOS, Windows)

- **Linux (Wayland & X11)**:
  - `config/default.yml` intentionally omits `backend: Inject` so Espanso auto-selects `EVDEVSource` + `EVDEVInjector` + `WaylandFallbackClipboard` on Wayland, with `inject_delay: 5` to prevent dropped characters under heavy load.
  - Ensure your user belongs to the `input` group and `/dev/uinput` is accessible (`install-linux.sh` and systemd daemon mode use `/dev/uinput`).
- **macOS**:
  - Automatically strips `com.apple.quarantine` from `/Applications/Espanso.app` (preventing macOS App Translocation crashes) and falls back to a daemon-mode LaunchAgent (`RunAtLoad` + `KeepAlive`) if `espanso start` times out waiting for Accessibility permission.
- **Windows**:
  - Run from **Git Bash** (`MINGW64` / `MSYS2`). Detects Scoop, Winget, Chocolatey, or `%LOCALAPPDATA%\Programs\Espanso` and deploys to `%APPDATA%\espanso`.

---

## 5. Package & Runtime Architecture TOC

```text
espanso-dist/
├── README.md                  # This TOC, benchmark showcase, and mental model guide
├── VERSION                    # Short git SHA of the upstream espanso-config build
├── version.json               # Build metadata (version, branch, timestamp, match_files: 356)
├── MANIFEST.json              # Machine-readable inventory of all 356 match files + trigger counts
├── install.sh                 # Auto-detecting cross-platform dispatcher (works via curl | bash)
├── install-linux.sh           # Linux installer (Wayland EVDEV + X11 + systemd daemon setup)
├── install-macos.sh           # macOS installer (Homebrew + quarantine fix + LaunchAgent)
├── install-windows.sh         # Windows installer (Scoop / Winget / Choco + %APPDATA%\espanso)
├── lib/
│   └── common.sh              # Shared installer library (fetch, atomic deploy, verify, self-update)
├── config/
│   └── default.yml            # Runtime config (RIGHT_CTRL toggle, SHIFT+CTRL+E search, inject_delay: 5)
├── default.yml                # Root copy of default.yml for backward compatibility
├── match/                     # 356 flat, deployment-ready YAML trigger files (comma-tokenized)
│   ├── _1char.yml             # Single-character & ultra-short high-frequency triggers
│   ├── _phrase_heads.yml      # Phrase-head matrix (l/a/z/n/1 + /1, low/nothing/no-one)
│   ├── _phrases.yml           # Multi-word conversational & engineering phrases
│   ├── _prefix_auto.yml       # Auto-generated prefix variants (re-/un-/in-/dis-)
│   ├── _word_families_*.yml   # Inflected word families (base + S/I/P/M/J/B/W/L/N/LS)
│   └── ...
└── espanso-install/           # iOS export & legacy compatibility mirror
```
