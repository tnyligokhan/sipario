# Ruflo — Claude Code Configuration

## Rules

- Do what has been asked; nothing more, nothing less
- NEVER create files unless absolutely necessary — prefer editing existing files
- NEVER create documentation files unless explicitly requested
- NEVER save working files or tests to root — use `/src`, `/tests`, `/docs`, `/config`, `/scripts`
- ALWAYS read a file before editing it
- NEVER commit secrets, credentials, or .env files
- NEVER add a `Co-Authored-By` trailer to user commits unless this project's `.claude/settings.json` has `attribution.commit` set (#2078). The Claude Code Bash tool may suggest one in its default commit-message template — ignore it. `Co-Authored-By` is semantic authorship attribution under git/GitHub convention; the tool is the facilitator, not a co-author.
- Keep files under 500 lines
- Validate input at system boundaries

## Agent Comms (SendMessage-First Coordination)

Named agents coordinate via `SendMessage`, not polling or shared state.

```
Lead (you) ←→ architect ←→ developer ←→ tester ←→ reviewer
              (named agents message each other directly)
```

### Spawning a Coordinated Team

```javascript
// ALL agents in ONE message, each knows WHO to message next
Agent({ prompt: "Research the codebase. SendMessage findings to 'architect'.",
  subagent_type: "researcher", name: "researcher", run_in_background: true })
Agent({ prompt: "Wait for 'researcher'. Design solution. SendMessage to 'coder'.",
  subagent_type: "system-architect", name: "architect", run_in_background: true })
Agent({ prompt: "Wait for 'architect'. Implement it. SendMessage to 'tester'.",
  subagent_type: "coder", name: "coder", run_in_background: true })
Agent({ prompt: "Wait for 'coder'. Write tests. SendMessage results to 'reviewer'.",
  subagent_type: "tester", name: "tester", run_in_background: true })
Agent({ prompt: "Wait for 'tester'. Review code quality and security.",
  subagent_type: "reviewer", name: "reviewer", run_in_background: true })

// Kick off the pipeline
SendMessage({ to: "researcher", summary: "Start", message: "[task context]" })
```

### Patterns

| Pattern | Flow | Use When |
|---------|------|----------|
| **Pipeline** | A → B → C → D | Sequential dependencies (feature dev) |
| **Fan-out** | Lead → A, B, C → Lead | Independent parallel work (research) |
| **Supervisor** | Lead ↔ workers | Ongoing coordination (complex refactor) |

### Rules

- ALWAYS name agents — `name: "role"` makes them addressable
- ALWAYS include comms instructions in prompts — who to message, what to send
- Spawn ALL agents in ONE message with `run_in_background: true`
- After spawning: STOP, tell user what's running, wait for results
- NEVER poll status — agents message back or complete automatically

## Swarm & Routing

### Config
- **Topology**: hierarchical-mesh (anti-drift)
- **Max Agents**: 5
- **Memory**: hybrid
- **HNSW**: Enabled
- **Neural**: Enabled

```bash
npx @claude-flow/cli@latest swarm init --topology hierarchical --max-agents 8 --strategy specialized
```

### Agent Routing

| Task | Agents | Topology |
|------|--------|----------|
| Bug Fix | researcher, coder, tester | hierarchical |
| Feature | architect, coder, tester, reviewer | hierarchical |
| Refactor | architect, coder, reviewer | hierarchical |
| Performance | perf-engineer, coder | hierarchical |
| Security | security-architect, auditor | hierarchical |

### When to Swarm
- **YES**: 3+ files, new features, cross-module refactoring, API changes, security, performance
- **NO**: single file edits, 1-2 line fixes, docs updates, config changes, questions

### 3-Tier Model Routing

| Tier | Handler | Use Cases |
|------|---------|-----------|
| 1 | Agent Booster (WASM) | Simple transforms — skip LLM, use Edit directly |
| 2 | Haiku | Simple tasks, low complexity |
| 3 | Sonnet/Opus | Architecture, security, complex reasoning |

## Memory & Learning

### Before Any Task
```bash
npx @claude-flow/cli@latest memory search --query "[task keywords]" --namespace patterns
npx @claude-flow/cli@latest hooks route --task "[task description]"
```

### After Success
```bash
npx @claude-flow/cli@latest memory store --namespace patterns --key "[name]" --value "[what worked]"
npx @claude-flow/cli@latest hooks post-task --task-id "[id]" --success true --store-results true
```

### MCP Tools (use `ToolSearch("keyword")` to discover)

| Category | Key Tools |
|----------|-----------|
| **Memory** | `memory_store`, `memory_search`, `memory_search_unified` |
| **Bridge** | `memory_import_claude`, `memory_bridge_status` |
| **Swarm** | `swarm_init`, `swarm_status`, `swarm_health` |
| **Agents** | `agent_spawn`, `agent_list`, `agent_status` |
| **Hooks** | `hooks_route`, `hooks_post-task`, `hooks_worker-dispatch` |
| **Security** | `aidefence_scan`, `aidefence_is_safe`, `aidefence_has_pii` |
| **Hive-Mind** | `hive-mind_init`, `hive-mind_consensus`, `hive-mind_spawn` |

### Background Workers

| Worker | When |
|--------|------|
| `audit` | After security changes |
| `optimize` | After performance work |
| `testgaps` | After adding features |
| `map` | Every 5+ file changes |
| `document` | After API changes |

```bash
npx @claude-flow/cli@latest hooks worker dispatch --trigger audit
```

## Agents

**Core**: `coder`, `reviewer`, `tester`, `planner`, `researcher`
**Architecture**: `system-architect`, `backend-dev`, `mobile-dev`
**Security**: `security-architect`, `security-auditor`
**Performance**: `performance-engineer`, `perf-analyzer`
**Coordination**: `hierarchical-coordinator`, `mesh-coordinator`, `adaptive-coordinator`
**GitHub**: `pr-manager`, `code-review-swarm`, `issue-tracker`, `release-manager`

Any string works as a custom agent type.

## Build & Test

- ALWAYS run tests after code changes
- ALWAYS verify build succeeds before committing

```bash
npm run build && npm test
```

## CLI Quick Reference

```bash
npx @claude-flow/cli@latest init --wizard           # Setup
npx @claude-flow/cli@latest swarm init --v3-mode     # Start swarm
npx @claude-flow/cli@latest memory search --query "" # Vector search
npx @claude-flow/cli@latest hooks route --task ""    # Route to agent
npx @claude-flow/cli@latest doctor --fix             # Diagnostics
npx @claude-flow/cli@latest security scan            # Security scan
npx @claude-flow/cli@latest performance benchmark    # Benchmarks
```

26 commands, 140+ subcommands. Use `--help` on any command for details.

## Setup

```bash
claude mcp add claude-flow -- npx -y ruflo@latest mcp start
npx ruflo@latest doctor --fix
```

> The background `daemon` is optional. It runs interval workers that each spawn
> a headless `claude` session, so it consumes tokens continuously. Start it only
> if you want those sweeps: `npx ruflo@latest daemon start` (self-stops after 12h
> by default; `--ttl 0` to disable, `daemon status --all` to audit running daemons).

**Agent tool** handles execution (agents, files, code, git). **MCP tools** handle coordination (swarm, memory, hooks). **CLI** is the same via Bash.

## Proje
BRIEF.md bu projenin tek kaynağıdır — önce onu oku.
Sonra DECISIONS.md'yi (verilmiş kararlar ve gerekçeleri — bunları yeniden tartışma)
ve PLAN.md'yi (yol haritası + güncel durum + sıradaki işler) oku.
Kullanıcı "vardiyaya başlıyorum" (ya da benzeri bir açılış) dediğinde:
PLAN.md'deki "🔻 VARDİYA DEVİR NOTU" ve "SIRADAKİ İŞLER" bölümlerini oku ve
ÖZETİNİ İLK MESAJINDA sun — ne yapıldı, ne yapılmadı, sıradaki en kritik işler.
YAPILACAKLAR.md bayattır; çelişki halinde PLAN.md doğrudur.
Mimar sensin: şemayı, stack'i, planı sen kur.
Sadece ilk planı onaya sun; onaydan sonra karar sorma.
Önemli kararları DECISIONS.md'nin SONUNA tek satır yaz (otomatik commit mesajı son satırı alır).
Vardiya/oturum sonunda PLAN.md'nin "Güncel durum" bölümünü güncelle.
Bu projede iki geliştirici nöbetleşe çalışır; sohbet geçmişi paylaşılmaz —
depodaki bu üç dosya ortak hafızadır, güncel tutulmaları pazarlıksızdır.
Benimle Türkçe konuş.

## Sürümleme — SemVer, İKİ AYRI HAT (kural, 2026-08-09)

**İki bağımsız sürüm vardır ve birbirine bağlanmaz:**

| Hat | Kaynak (tek doğru yer) | Neyi anlatır |
|-----|------------------------|--------------|
| **Uygulama** | `apps/mobile/pubspec.yaml` → `version:` | Bayinin telefonundaki sürüm |
| **API** | `apps/api/config/app.php` → `'version'` | Sunucudaki sözleşmenin sürümü |

Aynı anda değişebilirler, ama **aynı numarayı taşımak zorunda değiller** — birini diğerine
eşitlemek, ikisinden birinin sürüm numarasını anlamsız kılar.

### Artırma kuralı (MAJOR.MINOR.PATCH)

Bu projede sürümün anlamı **istemci–sunucu sözleşmesidir**, kod büyüklüğü değil:

- **MAJOR** — eski istemci yeni sunucuyla ÇALIŞAMAZ (alan/uç nokta kaldırıldı, anlamı değişti,
  zorunlu alan eklendi). ⚠️ Bu projede MAJOR bir olaydır: uygulama offline-first çalışır ve
  telefonlar günlerce eski sürümde kalabilir (ölçüldü: `main` bir ara `dev`'in 41 commit
  gerisindeydi). MAJOR atmadan önce eski istemcinin ne yapacağı YAZILI olarak kararlaştırılır.
- **MINOR** — geriye dönük uyumlu yeni davranış/alan/ekran. Eski istemci çalışmaya devam eder.
- **PATCH** — davranış değiştirmeyen düzeltme.

**Her kullanıcıya görünen değişiklik en az PATCH artırır.** Sürümü artırmayan bir vardiya,
"neyin ne zaman gittiğini" cevaplayamaz hâle getirir.

### Derleme numarası (`+N`) SÜRÜM DEĞİLDİR — silme

`+N` ve Android `versionCode` insana bir şey anlatmaz; **makinenin karşılaştırma anahtarıdır**
ve üçü birden buna dayanır: (1) Play daha küçük `versionCode`lu yüklemeyi reddeder, (2) uygulama
içi güncelleme "uzaktaki benden yeni mi?" sorusunu tam sayı karşılaştırmasıyla çözer, (3) ABI
sapması yüzünden `versionCode` güvenilmezdir, bu yüzden gerçek anahtar
`--dart-define=SIPARIO_YAPIM=<git commit sayısı>` ile geçilir.

Yani: **SemVer insan içindir, derleme numarası makine içindir.** İkisi bir arada yaşar;
SemVer'e geçmek derleme numarasını kaldırmak DEĞİLDİR. `pubspec.yaml`'daki `+1` CI tarafından
ezilir, elle güncellenmez.

### 🔴 SÜRÜM ARTIŞI İŞİN PARÇASIDIR — ayrı bir adım değil (kural, 2026-08-13)

**Kullanıcıya görünen bir iş, sürümü artırılmadan BİTMİŞ SAYILMAZ.** Kod yeşil, testler yeşil
ama sürüm sabitse iş yarımdır: "neyin ne zaman gittiği" cevaplanamaz hâle gelir.

Bu kural bir kez çiğnendi ve bedeli ölçüldü (2026-08-13): tek bir vardiyada menü baştan
kuruldu, ayarlar beş sayfaya bölündü, yeni bir Hesap sayfası eklendi, sessiz saatler açıldı ve
bir **yetki açığı** kapatıldı — `pubspec.yaml` hiç artmadı. Hata kuralın yokluğu değildi (kural
yukarıda zaten yazılıydı), kuralın İZİNİN olmamasıydı.

**Her iş kolu bittiğinde, o iş kolunun kapanış adımı şudur:**

1. `apps/mobile/pubspec.yaml` → `version:` işe göre artır (aşağıdaki tablo).
2. `lib/guncelleme/surum_notlari.dart` → EN ÜSTE o sürümün notunu yaz.
   (`surum_notlari_test.dart` en üstteki kaydın pubspec ile aynı olmasını zorlar — yani
   sürümü artırıp not yazmamak testi kırar. Ters yön korumasızdır: not yazmadan sürümü
   artırmamak sessizce geçer, **dikkat edilmesi gereken taraf budur.**)
3. Sunucu sözleşmesi değiştiyse `apps/api/config/app.php` → `'version'` AYRICA artır.
   İki hat bağımsızdır, birbirine eşitlenmez.

| Ne yapıldı | Artış |
|---|---|
| Yeni ekran/akış, davranış değişikliği, yetki değişikliği | **MINOR** |
| Görünen bir hatanın düzeltilmesi, metin/yerleşim onarımı | **PATCH** |
| Yalnız iç düzenleme (kullanıcı hiçbir farkı görmüyor) | artış YOK |
| Eski istemci yeni sunucuyla çalışamıyor | **MAJOR** — önce yazılı karar |

**Birden çok iş kolu aynı vardiyada bitiyorsa her biri kendi artışını alır**; hepsini tek
numaraya yığmak, sahada "hangi sürümde neyin geldiğini" yine cevapsız bırakır.

Otomatik commit kancası (`scripts/quality-gate-commit.ps1`) `apps/mobile/lib/**` dokunulan her
commit'in gövdesine `SURUM:` satırını yazar; sürüm bir önceki commit'le aynıysa bunu açıkça
belirtir. Kanca **bloklamaz** (bir vardiyada onlarca commit var, her birinde artış SemVer'i
anlamsızlaştırırdı) — yalnız atlanan sürümü `git log`'da GÖRÜNÜR kılar.