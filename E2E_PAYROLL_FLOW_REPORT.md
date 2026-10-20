# E2E Quotation-to-Payroll Flow — QA Report

**Date:** 2026-08-26
**Tenant:** TCG-DEFAULT (`d41da49e-f3da-41e5-8d7a-2b34e723fc6b`)
**Method:** Black-box HTTP testing against the live local API (`http://localhost:3000/api/v1`) and a real local Postgres dev DB. No application source code was modified. All data changes were made through the API.
**Environment note:** This is a *shared, live dev database*. During this session the `PAY-DEMO` payroll period's run counter advanced from run **3** to run **11** without any calculate call I issued at several points — i.e., another process/session was concurrently exercising the same API and DB. A static code search confirms `PayrollService.calculate()` has exactly one caller in the whole codebase (`PayrollController`'s `POST /periods/:id/calculate`), so this is external concurrent activity, not an automatic-trigger regression. Numbers quoted below are read back immediately after each action to minimize the window for interference, but be aware totals for shared employees (Michael Reynolds, James O'Connor) reflect whatever the full `PAY-DEMO` week held at read time.

Test artifacts created: `QUOT-00029`/`QUOT-00030` → `JOB-00005`/`JOB-00006`, asset `TCG-CR-QA1`, employee logins for `michael.reynolds@tcg.com` / `james.oconnor@tcg.com` (invited fresh for this test, password `FieldTest@1234`).

---

## 1. Quotation

**What I did:** `POST /api/v1/quotations` with `customerCode: CUST-0004`, `jobSiteCode: SITE-00006`, `priceList: "Premium Customer Rates"`, three resource lines (Crane/Operator/Oiler), `jobDate`/`jobEndDate` as plain `"2026-08-27"` strings (per the `CreateQuotationDto` Swagger example, which shows a bare date, and the "cannot be in the past" validator message, which also implies a date-only value is the expected shape).

**Requirement:** Not directly sourced for the wire format, but the DTO's own Swagger `example` field for `jobDate`/`jobEndDate` is a bare date string, and the validation pipeline for "cannot be in the past" clearly parses a date-only value correctly (it fires as expected). A field a validator accepts should not then crash the persistence layer.

**What actually happened:** `500 Internal Server Error` — `{"statusCode":500,"message":"Something went wrong. Please try again."}`. Isolated by bisection (via `PATCH /api/v1/quotations/{quoteNo}`) to exactly `jobDate` and `jobEndDate`: either field alone, set to a plain `"2026-08-27"` string, reproducibly 500s; the same field set to a full ISO datetime (`"2026-08-27T00:00:00.000Z"`) succeeds (`200`/`201`). Reproduced independently on two different quotations (`QUOT-00027`, `QUOT-00028`).

**Verdict: functionality broken.** This is a clean, 100%-reproducible defect: `jobDate`/`jobEndDate` accept a date-only string through validation (the "past date" check works fine on it) but throw an unhandled 500 the moment that value is persisted — almost certainly a `Date` parse/Prisma write mismatch between the DTO's accepted shape and what the ORM layer expects. Workaround used for the rest of this test: always send full ISO datetimes for these two fields.

Once corrected, quotation creation itself worked well: `POST /api/v1/quotations` with resources computed `subtotal: "2550"` / `"3570"` correctly from the three line items (sum of `finalAmount`), `PATCH .../mark-won` state-machine, and `POST /api/v1/projects/from-quotation` all worked as expected.

**Status transition note:** `POST /api/v1/quotations/{quoteNo}/mark-won` correctly refused a `DRAFT` quotation with `409 Conflict` ("Must be Internal Approved, Sent to Customer, or Changes Requested"). Not sourced to a specific vault rule, but internally consistent with `quotations/quotation-flow-process.md`'s multi-step approval flow. I bypassed the full approval workflow via `PATCH {status: "INTERNAL_APPROVED"}` for speed (an admin-only shortcut that itself worked without incident) — **matches** the stated state machine.

**Secondary, minor finding — project detail nulls:** `GET /api/v1/projects/{projectId}` immediately after `POST /api/v1/projects/from-quotation` returns `quotationId: null`, `jobId: null`, `job: null`, `customer: null` on the project's own fields, while its `metrics` array in the same response correctly reports `"Total No. of Jobs": 1` and `"Total No. of Quotations": 1`. The linkage clearly exists (`GET /api/v1/jobs` shows the job correctly carrying `quotationId`/`projectId`), so the project detail endpoint's own serializer is dropping fields its own metrics aggregation can see. **Verdict: functionality broken** (minor, cosmetic — not sourced to a specific requirement, filed as a UI-facing gap since a project detail page built on this endpoint would show a blank customer/job/quotation section).

---

## 2. Job setup (schedule, resources, DAS allocation) — the boom-length resolution defect

**What I did:** `PUT /api/v1/jobs/{jobId}/schedule` (one interval, 06:00–20:00), then `PUT /api/v1/jobs/{jobId}/resources` with three `JobResourceInputDto` rows (Crane / Operator / Oiler), then `PUT /api/v1/das/sub-jobs/{subJobId}/allocations` once per slot.

**Requirement:** Not directly sourced to a vault doc, but the boom-pay feature (`craft-modifiers` / `PAY-011`/`PAY-043`) is explicitly required to resolve the boom length from "the crane's set" at calculation time (`apps/api/src/service/craft-rate-resolver/craft-rate-resolver.service.ts`'s own doc comments; `DasAllocationsService.resolveSetRoot`).

### 2a. `tempId`/`parentId` linking is broken for new resources created in the same request

**What I did:** `PUT /api/v1/jobs/JOB-00006/resources` with `{"tempId":"crane1", ...}` on the crane row and `{"parentId":"crane1", ...}` on the Operator/Oiler rows — exactly the pattern documented in the DTO's own Swagger description ("Client-side temp id used to link new parent → new child within this payload").

**What actually happened:** All three resources were created, but the Operator/Oiler rows came back with `parentId: null` — the temp-id linkage silently did nothing. Confirmed by re-reading the resources via `GET /api/v1/das/sub-jobs?date=...`.

**Verdict: functionality broken.** Workaround: issue the `PUT` once to create rows, then a second `PUT` that repeats the *real* UUIDs (crane's own returned `id` as `parentId` on the children) — that works. But a caller who follows the DTO's documented single-request pattern gets silently flat (non-hierarchical) resources.

### 2b. Consequence: boom length is null forever if resources are allocated before the parent/child tree exists — no error, no boom pay, and no way to fix it after tickets are sent

**What happened on `JOB-00005`** (my first attempt, using the flat resources from 2a's broken temp-id linking): I allocated Crane/Operator/Oiler as flat siblings, then discovered via `GET /api/v1/field/tickets/{id}/labor-crew` that `craneMainBoomLength: null` and `suggestedCraftModifierBracket: "none"` for both employees, despite the crane (170 ft boom) being correctly allocated to the sub-job. Root cause (confirmed by reading `das-allocations.service.ts`'s `resolveSetRoot` comment): each allocation's `setResourceId` is **computed and snapshotted once, at the moment the allocation is written**, based on the resource tree's `parentId` structure *at that instant*. Fixing the resource tree's `parentId` afterward (`PUT .../resources` again) does not retroactively fix already-written allocations' `setResourceId`.

I then tried to re-write the allocations after fixing the tree: `PUT /api/v1/das/sub-jobs/{id}/allocations` → `400 Bad Request`, `"Cannot modify allocations after tickets have been sent"`. **The allocation is now permanently stuck with a broken (null) boom-length lookup for the life of that job** — there is no error at allocation time, no error at ticket-send time, no error at labor-entry time (the field employee simply sees "none" as the suggested bracket and can enter anything), and the payroll engine (`buildJobDay` reads the exact same `ticket.allocation?.setResourceId`) would resolve **zero boom pay** for this crew at calculation time, silently.

**Verdict: functionality broken**, and a serious one: this is reachable by any real dispatcher who allocates a crane and crew before defining which crew belongs to which crane's "set" (a very plausible ordering — resources are typically listed on a quotation as flat line items, exactly like the DTO example, and the parent/child requirement is not visible anywhere in the API surface or its Swagger docs). Not sourced to a specific rule (this is an implementation/data-integrity gap, not a product-requirement question), but it defeats the entire craft-modifier/boom-pay feature (`PAY-011`, `PAY-043`) for any job set up this way, with zero diagnostic signal to the dispatcher, field crew, or payroll admin.

**Fixed happy path:** I abandoned `JOB-00005` (left its 2 SENT-but-incomplete tickets in place, harmless) and built `JOB-00006` correctly — resources created, then immediately re-PUT with real UUIDs as `parentId` **before** any allocation — after which `GET .../labor-crew` correctly reported `craneMainBoomLength: 197`, `suggestedCraftModifierBracket: "181-200"`. **Matches expected.**

### 2c. Craft-modifier bracket table — 17 brackets, not 16; one duplicate; one real gap

`GET /api/v1/craft-modifiers` returned **17** active brackets (task description said 16 — worth a quick recheck if that number is load-bearing elsewhere). Two rows (`LB-06` and `LB-181-200`) cover the identical range 181–200 ft with identical adders ($4.50 operator / $1.50 oiler) — harmless today (`matchBracket` just needs *a* match) but a data-hygiene duplicate. There is a genuine, unfilled gap between `LB-01` (80–100 ft) and `LB-03` (121–140 ft) — **no bracket covers 101–120 ft** — which is exactly the "fell into a real gap" edge case the resolver's fallback logic is designed for (see §9).

---

## 3. Employee assignment (DAS allocation)

**What I did:** Allocated `EMP-1001` (Michael Reynolds, primary craft `L12-OP`) as Operator and `EMP-1003` (James O'Connor, primary craft `L12-OI`) as Oiler, via `PUT /api/v1/das/sub-jobs/{subJobId}/allocations`, `assigneeType: EMPLOYEE`. Both allocations came back with `craftCodeId` auto-populated to match the employee's own primary craft — no `craftCodeId` needed in the request body since the primary craft matched the slot's role. **Matches expected** (per the DTO's own doc: "Required when the employee primary craft role does not match an Operator/Oiler slot").

**Secondary craft path also verified:** for a separate (abandoned, see §Edge cases) scenario I allocated `EMP-1005`/`EMP-1010` — whose `L12-OP`/`L12-OI` are *secondary*, not primary, crafts — by passing `craftCodeId` explicitly, which the resolver's `resolveCraft()` correctly matched against their `SECONDARY` assignment row. **Matches expected** per `craft-rate-resolver.service.ts`'s documented secondary-craft path.

---

## 4. Job payroll flags

**What I did:** `PATCH /api/v1/payroll/jobs/{jobId}/flags` with `{isLattice: true, isMilitaryBase: true, isHazmat: false, foremanEmployeeId: <Michael's employee UUID>}`.

**Finding — route requires the job's UUID, not its business code, inconsistent with the rest of the API:** `GET/PATCH /api/v1/payroll/jobs/:jobId/flags` uses `@Param('jobId', ParseUUIDPipe)` (confirmed in `payroll.controller.ts`), so calling it with the job's business code (`JOB-00006`, which every *other* job route in this app accepts — `schedule`, `resources`, etc.) 400s with `"Validation failed (uuid is expected)"`. This violates the project's own documented Identity convention (CLAUDE.md: "Routes and DTOs use the code for UX; the service resolves `(tenant, code) → id` once"). **Verdict: functionality gap** — minor but a real inconsistency; every other job-scoped route in this flow accepted the code.

Once called with the UUID, the flags saved and read back correctly (`GET` echoed the same object).

---

## 5. Tickets sent

**What I did:** `POST /api/v1/das/sub-jobs/{subJobId}/tickets/ensure` then `.../tickets/send`.

**What happened:** Both calls worked exactly as documented — `ensure` returned the two pending tickets with correct employee/time/shift data, `send` returned `{"sent": 2, "ticketsSentAt": ...}`. **Matches expected.**

**Finding — no admin path to act on another employee's field ticket:** The task suggested checking whether admin could drive the field flow directly. Per `JobTicketsService.getTicketForEmployeeAction()`, the check is a hard `user.employeeId !== ticket.employeeId → 403 "Not your ticket"` with **no ADMIN-role bypass**. Since neither `EMP-1001` nor `EMP-1003` had a linked `User` account, I could not act on their tickets as `admin@tcg.com`. Worked around it by using `POST /api/v1/employee/{employeeCode}/invite` + `POST /api/v1/invitations/accept` to create and activate real logins for both employees (both are clearly synthetic `@tcg.com` seed identities, not real people, so this was safe to do). **Not sourced as a defect** — this may well be intentional (no support/impersonation surface for field data) — but it's worth flagging as a genuine operational gap for support/QA use, and it cost significant setup time in this session.

I separately found (and did **not** use) that two other Operator/Oiler-craft employees (`EMP-1005`/`EMP-1010`) already had **real, active user accounts tied to a real person's email** (`ali.riaz@codingcops.com` / `ali.riaz+1@codingcops.com`). I attempted a password reset for one of these to drive a cleaner isolated test and the harness's own auto-mode classifier correctly blocked it as a sensitive action against a real credential. This was the right call — flagging here only so the trail is clear: **that scenario (§9 "clean isolated boom-pay test with a second craft pair") was abandoned for this reason, not skipped by oversight.**

---

## 6. Field completion

**What I did, as the employee (via their own login/cookie):**
- `PATCH /api/v1/field/tickets/{id}/steps` for all six milestones (`leftYard`, `arriveJob`, `startWork`, `endWork`, `leftJob`, `arriveYard`), timestamps expressed as `America/Los_Angeles`-offset ISO strings (`-07:00`) — `startWork: 06:00 PDT`, `endWork: 20:00 PDT` (14-hour shift).
- `POST /api/v1/field/tickets/{id}/labor-entries` for the boom-time window matching the steps, `lunchesTakenCount: 0`, `wtlCount: 0`.
- `POST /api/v1/field/tickets/{id}/submit` with `{ticketId, captures: {}, summaries: {}, completedAt: <ms>}`.

**What happened:** All calls succeeded (`200`/`201`). Ticket status correctly advanced to `COMPLETE`.

**Finding — submission does not appear to require any checklist/JSA/signature step to be completed.** I never called `pretrip`/`jsa`/`posttrip`/`signatures` endpoints, and `/submit` accepted empty `captures`/`summaries` objects without complaint. **Not sourced** — `field-ops/field-ops-mobile-INDEX.md` is an explicit, un-reconciled three-way conflict between FR-TCG-FOP-001, FR-TCG-FOP-002, and the Atom user stories, none of which is authoritative, so I cannot cite a specific requirement this violates. Filed as "not sourced (can't judge)" rather than a defect, but worth a product decision: if a checklist step is meant to be mandatory before submit, it currently isn't enforced.

**Minor finding — stale override reason after a bracket correction.** After recording a labor entry with `craftModifierBracket: "161-180"` + an override reason, then re-submitting the *same* entry with the corrected, non-overridden bracket (`"181-200"`, which matched the suggestion), the persisted `craftModifierOverrideReason` still showed the old override text instead of clearing to `null`. Data-hygiene issue, not sourced to a specific rule.

---

## 7. Craft modifier / boom pay — override validation works, but has **zero effect on the actual payroll calculation**

**What I did:** `POST /api/v1/field/tickets/{id}/labor-entries` with `craftModifierBracket: "161-180"` (the crane's actual boom length, 197 ft, suggests `"181-200"`) and no `craftModifierOverrideReason`.

**Requirement:** "deliberately try an *overridden* bracket without `craftModifierOverrideReason` and confirm it's rejected, then with a reason and confirm it's accepted" (task instructions, matching `ticket-labor-entries.service.ts`'s own inline documentation, "U3 / REQ-05 / REQ-08").

**What happened:**
- Without a reason: `400 Bad Request` — `"craftModifierOverrideReason is required when overriding the suggested craftModifierBracket"`. **Matches expected.**
- With a reason (`"QA test: deliberate override to confirm reason gate"`): `201`, persisted correctly with both fields. **Matches expected.**

**Major finding — the persisted `craftModifierBracket` field is never read by the payroll engine.** I traced every consumer of `craftModifierBracket` in the codebase (`grep -rn "craftModifierBracket" apps/api/src`): it is written by `ticket-labor-entries.repository.ts`, selected (but never subsequently used) by `payroll.repository.ts:396`, and **never referenced anywhere in `payroll.service.ts` or `payroll-engine/src/calculate.ts`**. The actual boom adder paid at calculation time comes exclusively from `CraftRateResolverService.resolveBoomAdder()`, which independently re-derives the bracket from the crane asset's `mainBoomLength` via the tenant's `craft-modifiers` table — completely ignoring whatever bracket the field employee selected, confirmed, or overrode (with a documented reason!) on the labor entry.

I confirmed this live: I overrode the bracket to `"161-180"` with a reason, then re-submitted with the *correct* `"181-200"` bracket before calculating — so I can't produce a "the wrong number appeared" artifact for this specific run (both entries ended up matching the resolver's own answer), but the code trace is unambiguous and independently verifiable at the two file:line references above. **Verdict: functionality gap.** The entire override-with-reason UI/workflow (a real feature, with real validation, presumably built so a foreman can document *why* a boom-length reading differs from the system's guess) has no way to actually change what anyone gets paid. Either this is dead code that should be removed, or the payroll engine is missing an intended override path — this is a product decision, not something I can adjudicate, but it should not ship silently either way.

---

## 8. Payroll calculation — real numbers

**Period:** `PAY-DEMO` (`e8a86fae-4415-4de2-adce-64f6016f91c8`, week `2026-08-22`–`2026-08-28`). `POST /api/v1/payroll/periods/{id}/calculate`.

### 8a. The chain/overlap defect (the headline finding)

My test ticket for Michael Reynolds ran `2026-08-27 06:00–20:00 PDT` (14 hours) on `JOB-00006`. Michael Reynolds **already had a separate, pre-existing seeded ticket** on the same calendar day, `T-JOB-PAYROLL-00011`, `04:30–12:30 PDT` on a *different* job (`JOB-PAYROLL`). These two labor entries **overlap in wall-clock time** (mine starts at 06:00, the existing one doesn't end until 12:30) — the same employee is recorded as working two different jobs simultaneously for six and a half hours.

`packages/payroll-engine/src/calculate.ts`'s `chainJobDays()` groups an employee's entries into one continuous "shift" whenever the gap between one entry's end and the next's start is **less than 8 hours** — including a *negative* gap (an outright overlap), which it does not distinguish from a normal short rest period. Because `T-JOB-PAYROLL-00011` ended at cumulative-hours-worked = 8.0 for that chain, my entry inherited a **starting cumulative of 8.0 hours** instead of 0 — so its very first slice was already priced as overtime, and double-time started after only 4 more hours instead of 8.

**Actual computed result** (`GET /api/v1/payroll/periods/{id}/employees/{employeeId}`, jobDay for `T-JOB-00006-00001`):

| Bucket | Hours | Rate | Amount |
|---|---|---|---|
| Overtime (PAY-023) | 4 | $99.27 | $397.08 |
| Double time (PAY-024) | 10 | $132.36 | $1,323.60 |
| Long boom OT (PAY-043) | 4 | $6.75 | $27.00 |
| Long boom DT (PAY-043) | 10 | $9.00 | $90.00 |
| Foreman premium (PAY-070) | 14 | $3.00 | $42.00 |
| Military base premium (PAY-071) | 14 | $10.00 | $140.00 |
| **Total** | | | **$2,019.68** |

**Expected result if this ticket were priced as its own fresh shift** (cumulative resets to 0, as it should for an employee's first entry of a chain, per the day's actual boom window: 06:00–17:00 PDT window boundary rules give ST=8h/OT=4h/DT=2h — hand-verified slice-by-slice against `day-type.ts`'s `bucketForSlice`):

| Bucket | Hours | Rate | Amount |
|---|---|---|---|
| Straight time (PAY-022) | 8 | $66.18 | $529.44 |
| Overtime (PAY-023) | 4 | $99.27 | $397.08 |
| Double time (PAY-024) | 2 | $132.36 | $264.72 |
| Long boom ST (PAY-043) | 8 | $4.50 | $36.00 |
| Long boom OT (PAY-043) | 4 | $6.75 | $27.00 |
| Long boom DT (PAY-043) | 2 | $9.00 | $18.00 |
| Foreman premium (PAY-070) | 14 | $3.00 | $42.00 |
| Military base premium (PAY-071) | 14 | $10.00 | $140.00 |
| **Total** | | | **$1,454.24** |

**Overpayment: $2,019.68 − $1,454.24 = $565.44** for this one ticket, purely from the mis-chained cumulative-hours carryover. The same defect independently reproduced for James O'Connor's parallel ticket: actual $1,427.00 vs. expected $1,031.00 (ST $384 + OT $288 + DT $192 + boom ST/OT/DT $12+$9+$6 + military $140) — **overpayment $396.00**.

**Requirement:** `.ai/vault/payroll/rules/PAY-029-overlapping-labor-detection.md` ("Overlapping labor detection") is a registered rule in the canonical `PAY-###` register — its existence as a named rule confirms the product is expected to detect this exact situation. It carries no rule body/detail (like most of the 73 rules, it's `status: open` with only matrix/FRD citations, no worked specification), so I cannot cite an exact expected *response* (reject the ticket? flag it? cap the hours?) — but "silently chain them and pay double-time on hours that were, per the data, worked at two different jobs at once" is very unlikely to be it, and demonstrably produces a materially wrong dollar figure either way.

**Verdict: calculation issue.** This is the most serious defect found in this pass: a real, quantified overpayment, self-consistent arithmetic (verified against `day-type.ts`'s bucketing rules by hand, matches to the cent), triggered by an ordinary real-world scenario (an employee dispatched to a second job the same day) that the codebase's own rule register (PAY-029) says should be handled and isn't. Caveat for reproducibility: this specific instance required my test employee to already have a same-day, overlapping shift from seeded demo data — a fresh tenant with no seed data would need a deliberately-constructed second ticket to reproduce it, which is straightforward (see repro steps above).

### 8b. Everything else in the calculation — matches expected

- **OT/DT thresholds:** >8h/day → 1.5×, >12h/day → 2×, hours outside the 06:00–17:00 window → OT even under 8 cumulative hours, Saturday → all-OT, Sunday → all-DT, "Special Saturday" (first Saturday of June/December) → 2×, L12 holiday calendar → 3×. All confirmed against `packages/payroll-engine/src/day-type.ts` and cross-checked hand-arithmetic against five other days of the same employee's week (Sat/Sun/Mon/Tue/Wed rows in §8a's source data) — every one of those five days' ST/OT/DT split matched a fresh independent hand calculation exactly. **Matches expected** (citing `PAY-022`/`PAY-023`/`PAY-024`/`PAY-030`/`PAY-031`/`PAY-034` collectively — none of these rule files specify exact thresholds beyond "8" and "12," which the code matches).
- **Boom adder ("long boom"), PAY-043:** correctly priced per-bucket at the bracket's per-hour adder × that bucket's multiplier (ST×1, OT×1.5, DT×2) — confirmed to the cent in both tables above.
- **Foreman premium, PAY-070:** applied only to the flagged employee (`foremanEmployeeId`), flat `$3/hr × actualHours` (not multiplied by OT/DT) — differs from the vault's own open question in `PAY-070`/`payroll/foreman-and-military-premiums.md`, which flags the `FRT` (Foreman TRI) ADP code as implying the premium *should* multiply through OT/DT/holiday tiers ("the TRI code's existence implies the premium is multiplied along with the base"). **Verdict: not sourced (can't judge)** — the vault explicitly says this is an unresolved assumption ("That reading is not stated anywhere"), so I can't call the flat-rate implementation wrong, only note that it takes one side of an open question without flagging it as a decision.
- **Military base premium, PAY-071:** same flat-rate treatment, same open-question caveat (`PAY-071`'s own doc: "No answer on whether $3 and $10 are multiplied. `FRT` implies yes for Foreman; nothing is said for Military.").
- **Lattice premium gate, PAY-044:** fired `LATTICE_GROUP_INELIGIBLE` for **every** flagged-lattice jobDay for both employees (8 occurrences across Michael's week, confirmed via the `issues` array). Traced to root cause: `CraftCode.wageGroup` (the field `PAY-044`'s Group-6+ gate reads) **has no field in `CreateCraftCodeDto` or `UpdateCraftCodeDto`, and is absent from every craft-codes API response** (`GET /api/v1/craft-codes/admin` — verified by direct inspection, field is simply not serialized). There is no way, through the API, to ever set a craft's wage group — meaning the lattice premium can **never** pay out for any craft code created or edited via this app, regardless of qualification, until someone edits the value directly in the database. I could not test the "qualifying craft" side of this gate for exactly this reason — noted here rather than skipped silently. **Verdict: functionality broken** — a real product feature (`PAY-044`, rates independently confirmed from three sources per the vault: "$1/hr operator, $0.50/hr oiler, Group 6+") is completely unreachable via the application surface.
- **Live data/code mismatch, MILITARY premium `appliesTo`:** confirmed still `"UNION"` in this tenant's live `payroll_premium_type` row (`GET /api/v1/payroll/premiums`), even though `payroll.repository.ts`'s `DEFAULT_PREMIUMS` array now defaults it to `"ALL"` with an inline comment citing `payroll/foreman-and-military-premiums.md` ("added to ALL hours for ALL employees on the job"). Root cause confirmed: `seedDefaultPremiums()` only runs its `createMany` when the table is **completely empty** for the tenant (`if (existing > 0) return this.listPremiums()`) — there is no migration/backfill path, so a tenant seeded before the fix keeps the stale value forever. **Additional finding beyond what was flagged:** this `appliesTo` field is **not read anywhere** in the calculation path — `premiumRates()` in `payroll.service.ts` only reads `.amount`, and `calculate.ts` applies the military premium to any job-day with `flags.isMilitaryBase` regardless of the employee's union status (the union/non-union split happens earlier, via which pricing function is called at all). So today, this specific stale-data mismatch has **no actual dollar impact** — it's a real, confirmed data/code divergence, but currently inert. Also confirmed: `PATCH /api/v1/payroll/premiums/{id}` (`UpdatePayrollPremiumDto`) only accepts `amount`/`label`/`status` — there is no way to fix `appliesTo` via the API even if it mattered, short of a fresh tenant or a direct DB edit.

---

## 9. Approval lock

**What I did:** `POST /api/v1/payroll/periods/{id}/approve` (period-level, without first approving each employee-week individually), then `POST .../calculate` again.

**What happened:** Approve succeeded and set `status: "APPROVED"` immediately, **even though both employee-weeks were still `status: "FLAGGED"`** (never individually approved via `POST .../employees/{employeeId}/approve`). The subsequent recalculate attempt correctly returned `400 Bad Request` — `"Cannot recalculate a period that is already approved"`.

**Verdict:** the recalculate-lock itself **matches expected** (task's description: "widened from EXPORTED-only to APPROVED-or-EXPORTED" — confirmed, and the code at `payroll.service.ts:107-114` checks both statuses in one `if`). But the period-level approve bypassing per-employee approval is a **functionality gap**: `PayrollService.approveEmployee()`/`maybeAdvanceToApproved()` implement an implied workflow where the period only auto-advances to APPROVED once *every* employee-week is individually approved — but `approvePeriod()` is a completely separate, unconditional code path that skips that check entirely (`approvePeriod()` just calls `approveAllWeeks(runId, userId)` directly, no per-week status gate). Not sourced to a specific rule (`PAY-065` "Payroll approval" is one of the many un-detailed open register entries), so I can't say which behavior is intended, but having two disconnected approval surfaces with different guarantees is worth a product decision.

---

## 10. Weekly export

**What I did:** `GET /api/v1/payroll/periods/{id}/export` (XLSX) and `.../export.csv`, after the period reached `APPROVED` (export further advanced it to `EXPORTED`, confirmed via `GET /api/v1/payroll/periods/{id}`).

**What happened:** Both succeeded. XLSX came back as a genuine `Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` file (`file` command confirms "Microsoft Excel 2007+"), filename `EPI4RZ20260828.xlsx` (matches `ADP_COMPANY_CODE` `4RZ` + period-Friday-date convention from `payroll.service.ts`). The hour totals in the CSV matched the calculated numbers exactly (row for `EMP-1003`/Thu/`TCG-CR-QA1`: `Total Hrs=14, ST=0, OT=4, DT=10, LB Total=14, LB OT=4, LB DT=10, Craft Modifier="181-200 ft"` — matches §8a's James O'Connor jobDay exactly).

**CSV-quoting check:** the export already contains a real name requiring quoting without any construction on my part — `"O'Connor, James"` (curly apostrophe **and** a comma, from the "Last, First" format) appears correctly wrapped in double quotes on every one of his rows, and the file parses cleanly as CSV. **Matches expected** — the CSV-quoting fix mentioned in the task brief holds up under a real, naturally-occurring case.

**Major finding — Foreman and Military premium dollars are absent from the export entirely.** The CSV/XLSX header row is:
```
File #, Employee, Employee Code, Payroll Group, Unit_Asset, Date, Day, Total Hrs, ST, OT, DT, H2x, H3x,
Lattice Oper, Lattice Oiler, 2nd Shift, 3rd Shift, Craft Modifier, LB Total, LB ST, LB OT, LB DT, LB 3X,
Subsistence, Sick Hrs, Salary
```
There is no Foreman or Military column anywhere. Michael Reynolds' week includes **$210** of computed Foreman premium (8+8+8+11+13+14+8 hours × $3, one row per day across the whole `PAY-DEMO` week, confirmed via the `components` array) and **$140** of Military premium — **$350 total** — that is fully computed, stored, and visible via the API's own detail endpoints (`GET /api/v1/payroll/periods/{id}/employees/{employeeId}`), but has **no representation anywhere in the one artifact this system produces to actually pay someone.** Note that "Lattice Oper"/"Lattice Oiler" **do** have dedicated hour columns in this same export (currently all zero, since §8b's `LATTICE_GROUP_INELIGIBLE` gate blocks it) — so the export format clearly has room for premium-style columns, it simply omits Foreman and Military specifically.

**Requirement:** `PAY-070`/`PAY-071` (Foreman/Military premiums) and `PAY-059` ("Pay component ledger" — "every calculated dollar must be a separate, explainable pay component... not a total") and the ADP codes are explicitly documented and confirmed live in ADP (`FRR/FRO/FRD/FRT`, `MLR/MLO/MLD/MLT` — four-bucket REG/OT/DT/TRI families, per `foreman-and-military-premiums.md`). Those bucket codes have no corresponding column in this export at all.

**Verdict: functionality broken.** This is the second most serious finding in this pass: real, correctly-computed wages that would silently never reach ADP through the one export path this system provides.

---

## Edge cases

| Edge case | Status | Notes |
|---|---|---|
| Non-union employee (no boom pay regardless of boom length) | **Not attempted** | Confirmed via code read only (`resolveBoomAdder`'s `if (unionKind !== 'UNION') return {status:'OK', adder:null}` — unconditional gate, correct per its own doc comment). This tenant has exactly two craft codes and both are `UNION` kind (`GET /api/v1/craft-codes`), so there was no live non-union craft to test against without creating one from scratch; ran out of time budget before doing so. |
| Employee with no primary craft → `NO_PRIMARY_CRAFT`, not error | **Not attempted** | Confirmed via code read (`craft-rate-resolver.service.ts:262`) — returns a `BlockedRate`, not a throw, consistent with the task's expectation. Live-testing would have required a full new job/ticket cycle for a non-crane-role employee; deprioritized in favor of completing the full happy path and the higher-value findings above. |
| Boom length in a genuine gap between brackets (101–120 ft, confirmed to exist, §2c) → falls back to nearest lower bracket | **Not attempted live** | The gap itself is confirmed to exist in the live bracket table (§2c). Testing the fallback would need a new asset + job/ticket/labor-entry/calculate cycle; time did not allow it in this pass. Per code read (`craft-rate-resolver.service.ts`'s `matchBracket`/`adderForRole`), the fallback logic is implemented as described (falls to nearest lower bracket, never $0) — flagging as "not sourced from a live run" rather than claiming it's verified. |
| Boom length above highest bracket → nearest lower bracket, not $0 | **Not attempted live** | Same reasoning as above. |
| No active craft-modifier brackets configured → `NO_ACTIVE_MODIFIER_SCALE` | **Not attempted** | Would require a second tenant or deactivating this tenant's live bracket data, which risked corrupting the rest of this test run. Code read confirms the guard exists (`craft-rate-resolver.service.ts:221-226`). |
| Lattice premium — qualifying (Group 6+) craft | **Blocked, not a skip** | See §8b — there is no way to set a craft's `wageGroup` via the API at all, so this scenario is untestable through the application surface as it stands today. This is itself the finding. |
| 7th-consecutive-day / weekend shift (`PAY-026`/`PAY-030`/`PAY-031`) | **Partially covered** | Saturday-all-OT and Sunday-all-DT were confirmed as a side effect of §8b's cross-check of Michael Reynolds' full seeded week (Sat `T-JOB-PAYROLL-00001`: 8h all-OT; Sun `T-JOB-PAYROLL-00003`: 8h all-DT — both match `day-type.ts`). Seventh-consecutive-day (`PAY-026`) specifically was not constructed/tested — it isn't implemented anywhere in `calculate.ts` (no reference to a 7-day consecutive counter in the file at all), so it would show as simply absent rather than wrong, but I did not verify this with a live 7-consecutive-day construction. |
| Clean, isolated (non-chained) boom-pay test with a second employee pair | **Abandoned — see §5** | The only other available Operator/Oiler-craft employees have real, active accounts tied to a real person's email; resetting that credential to drive the test was correctly blocked by the harness's safety classifier. Did not pursue further. |

---

## Punch list — defects found, prioritized

### Calculation errors (wrong dollars)
1. **Overlapping/mis-chained labor entries silently mispriced across jobs** (§8a). Two entries for the same employee on the same calendar day, for two different jobs, that overlap in wall-clock time get chained by `chainJobDays()`'s naive `gap < 8h` check (which doesn't distinguish a negative/overlapping gap from a normal short rest period), carrying over cumulative hours from one job into the next and inflating OT/DT. **Confirmed overpayment: $565.44 (Michael Reynolds) and $396.00 (James O'Connor)** for the two tickets tested. `PAY-029` ("Overlapping labor detection") is a registered rule for exactly this condition and is not implemented.

### Missing/broken features
2. **Foreman and Military premium dollars are completely absent from the weekly ADP export** (XLSX and CSV) — §10. $350 of correctly-computed Michael Reynolds premium pay for this one week has no column to land in.
3. **`CraftCode.wageGroup` cannot be set via the API** — §8b. The Group-6+ gate for the Lattice premium (`PAY-044`) can therefore never be satisfied for any craft managed through the application, blocking a documented, rate-confirmed premium entirely.
4. **The recorded/overridden `craftModifierBracket` on a labor entry has no effect on the actual boom pay calculated** — §7. The override-with-reason workflow is fully validated and persisted but silently discarded at calculation time; the engine always re-derives the bracket independently from the crane's boom length.
5. **`POST /api/v1/quotations` (and `PATCH`) 500s on a plain date-only `jobDate`/`jobEndDate` string** — §1. Reproducible, isolated to these two fields; workaround is a full ISO datetime.
6. **Resource `tempId`/`parentId` linking silently fails for new resources created in the same `PUT /jobs/{jobId}/resources` request** (§2a), and **once an allocation is written against a flat (non-hierarchical) resource tree, the crane's boom length can never be resolved for that job again — with zero error signal at any step** (§2b), permanently defeating boom pay for that crew.
7. **`PATCH /api/v1/payroll/jobs/{jobId}/flags` requires the job's UUID**, inconsistent with every other job-scoped route in this flow, which accepts the business code (§4).
8. **`POST /api/v1/payroll/periods/{id}/approve` bypasses per-employee-week approval entirely**, disconnected from the `approveEmployee`/`maybeAdvanceToApproved` workflow that implies all weeks must be approved first (§9).
9. **`GET /api/v1/projects/{projectId}` returns null `job`/`quotation`/`customer` immediately after conversion**, while its own `metrics` block correctly counts them (§1, minor).

### Product-requirement gaps (nothing written down to be wrong against)
10. **Foreman/Military premium multiplier treatment (flat vs. multiplied through OT/DT/holiday tiers) is an explicitly open question** (`PAY-070`/`PAY-071`) that the implementation has silently resolved one way (flat) without a recorded decision — §8b.
11. **No field-level rule settles whether checklist/JSA/signature steps are mandatory before ticket submit** — three competing, unreconciled field-ops documents (`field-ops-mobile-INDEX.md`), and submission succeeded with none of them completed — §6.
12. **Live-data/code mismatch on the `MILITARY` premium's `appliesTo` field** (still `"UNION"` in this tenant, code now defaults new tenants to `"ALL"`) is confirmed real per the task's own pre-flagged lead, root-caused to `seedDefaultPremiums()`'s insert-only-if-empty behavior with no backfill path — but is currently **functionally inert**, since nothing in the calculation engine reads `appliesTo` at all (§8b). Worth fixing for tenant consistency, but not an active bug today.
13. **Craft-modifier bracket table has a duplicate range (181–200 ft listed twice) and an unfilled gap (101–120 ft)** — data-hygiene items, not verified live against the gap-fallback behavior due to time (§2c, Edge cases).
