# AEP integration plan

Use this template to write a plan in the developer's repository. Replace the
placeholders with verified facts and approved decisions. This is an executable
plan, not a historical changelog. Never record credentials or personal data.

## Goal and scope

- Target repository and application:
- Selected SDK and version:
- Selected role: Agent application / Service / Both
- Selected capabilities:
- Included work:
- Explicitly excluded work:
- Completion criteria:

Implement only the selected integration. Detect existing related protocols and
model their actual behavior where relevant. If a related integration is planned
but absent, ask whether to continue without it or pause for its separate guide.
Do not advertise planned capabilities as implemented or add another protocol
without approval.

When coordinated by the Directory guide, also update
`COMMERCE-INTEGRATION-PLAN.md` before handoffs. Reuse its confirmed scope and
answers. Return related-integration blockers and completion evidence to that
coordinator instead of starting nested guides. The application assessment and
implementation tasks remain in this child plan.

## Current assessment

Inspect the current repository on every run, even when an earlier plan exists.
Confirm prior completion claims against the current code. Preserve working
behavior and plan only the changes needed for the approved target scope.

| Capability          | Current implementation         | Evidence                           | Planned change          |
| ------------------- | ------------------------------ | ---------------------------------- | ----------------------- |
| Feature or endpoint | Present, absent, or unverified | File and line or observed response | Required change or none |

Record framework, routes, data sources, authentication, payments, deployment
constraints, existing tests, and relevant user changes. Distinguish installed
dependencies from capabilities actually configured and implemented.

## Sources and unresolved questions

Protocol specifications govern protocol requirements. The selected SDK version's
source establishes its actual API. Repository code establishes current behavior.
Developer decisions establish intended scope. A scope decision does not change a
protocol requirement. Surface conflicts rather than silently choosing a shortcut.

| Requirement or fact                         | Authoritative source and version         | Implementation boundary     |
| ------------------------------------------- | ---------------------------------------- | --------------------------- |
| Required, recommended, or optional behavior | Specification section or source location | Relevant endpoint or module |

| Unresolved question                | Evidence and context              | Options and recommendation      | Decision |
| ---------------------------------- | --------------------------------- | ------------------------------- | -------- |
| Question requiring developer input | What is known and what is missing | Concrete choices with tradeoffs | Pending  |

Ask only questions the repository cannot answer. Do not assume permission to
change existing authentication, payment behavior, or public interfaces.

## Decisions

| Decision                 | Rationale                    | Approval           |
| ------------------------ | ---------------------------- | ------------------ |
| Approved scope or design | Why it fits this application | Developer response |

## Active work

- Stage: Interview / Assessment / Plan awaiting approval / Implementation / Verification

- State: Not started / In progress / Waiting for developer / Blocked / Complete
- Current task:
- Next action:
- Approval needed:

Create or reconcile this file once the repository is confirmed. Save answers and
findings throughout the interview and assessment without changing the application.
Update it before every response returning control, including questions and
suggestions to switch workflows. Keep unresolved decisions pending. Before a
switch, record the destination, reason, and resumption step without waiting for a
checkpoint request. On return, reassess current code and preserve user notes.
Early planning is not implementation approval. Report any inability to save.

Present the assessment and plan before implementation. Pause after each agreed
stage or coherent task. Say what comes next and ask the developer to type
`go` to continue. A continuation applies to that stated step, not unrestricted
implementation, deployment, publication, or payment execution.

## Ordered tasks

Replace the example row with concrete, dependency-ordered tasks. Separate
independent subsystems and split work too large to review coherently. Include
documentation and verification as real tasks, not implicit finishing work.

| Order | State       | Task          | Dependencies | Output                      | Verification                  | Approval needed |
| ----- | ----------- | ------------- | ------------ | --------------------------- | ----------------------------- | --------------- |
| 10    | Not started | Concrete task | None         | Files or behavior delivered | Actual command or observation | Plan approval   |

Update task states as work proceeds. Record why a task is reordered, deferred,
or removed; obtain approval for scope changes.

## Review and verification

Apply these steps to each implementation task:

1. Trace applicable requirements to their implementation boundaries. Separate
   required behavior, optional features, and deferred scope.
2. Identify relevant failure cases before coding, including malformed or omitted
   values, overflow, cancellation, concurrency, redirects, credential leakage,
   custom implementations, and mutation of caller-owned data.
3. Implement in small coherent slices using the application's existing patterns.
4. Review the final code skeptically. Trace external calls, authentication,
   payments, state changes, storage, retries, and recovery end to end. Challenge
   whether each change is necessary, correct, safe, and compatible with the
   approved scope. Avoid unnecessary helpers, dependencies, and compatibility code.
5. Run the repository's prescribed checks and meaningful integration checks.
   Mocks do not prove behavior at an external boundary. Do not trigger real
   charges, publish data, or deploy without explicit approval.
6. Inspect every changed file after verification. Confirm the reviewed and tested
   tree matches the delivered tree and contains no unrelated or generated drift.
7. Hand back the result with verified requirements, findings fixed, exact checks
   and outcomes, excluded work, and the precise next action. Create a commit or
   pull request only when authorized.

| Check                | Command or procedure                      | Result  | Evidence or limitation                 |
| -------------------- | ----------------------------------------- | ------- | -------------------------------------- |
| Repository checks    | Actual prescribed commands                | Not run | Record failures or blockers honestly   |
| Integration behavior | Relevant local endpoint or consumer check | Not run | Distinguish actual behavior from mocks |
| Final diff review    | Review all changed files                  | Not run | Record remaining findings              |

Select checks relevant to the implementation. Explain any prescribed check that
could not run; never mark it passed. Keep local verification, deployed
verification, and directory submission as separate outcomes.

Identify existing browser and API flows affected by the changes and verify their
behavior is preserved. Include login, checkout, credentials, permissions, and
tenant separation where relevant. Use existing tests or controlled environments;
do not perform real purchases or mandate an unrelated test framework.

## Risks and discovered work

| Finding                        | Impact                | Evidence               | Resolution or developer decision |
| ------------------------------ | --------------------- | ---------------------- | -------------------------------- |
| Risk, blocker, or missing work | Practical consequence | Source or failed check | Fix in scope, defer, or ask      |

Before each handoff, record any outstanding work mentioned in chat here or in
the task list. Do not silently expand scope. For blockers, record what was tried,
what decision is needed, and the next action that can unblock the task.

## Completion and handoff

Close the plan only when completion criteria and verification are satisfied and
each task is complete or explicitly deferred with the developer's agreement.

- Completed behavior:
- Requirements verified:
- Review findings fixed:
- Files changed:
- Commands run and results:
- Local versus deployed verification:
- Deferred work and its destination:
- Remaining risks or decisions:
- Precise next action:

Keep enough current-state evidence for a later run to reassess the integration
without relying on chat history. A later run may select a different integration
level or discover newly implemented AEP or payment endpoints.

## Exit criteria

Generate concrete criteria from this guide and the approved application scope.
Both groups below are required. InFlow acceptance does not replace the project's
tests, coverage requirements, or other quality gates.

### Project acceptance

| Criterion             | Command or procedure                                                                | Expected result                            | Result and evidence |
| --------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------ | ------------------- |
| Project quality gates | Actual unit and integration tests, coverage, static analysis, and regression checks | Project's required outcomes and thresholds | Pending             |

### InFlow acceptance

| Criterion                            | Environment and target      | Prerequisites and authorization                                 | Command or procedure                           | Expected result                | Result and evidence |
| ------------------------------------ | --------------------------- | --------------------------------------------------------------- | ---------------------------------------------- | ------------------------------ | ------------------- |
| Running-system check from this guide | Exact origin or counterpart | Deployment, account setup, explicit approval when state changes | Verified CLI invocation and application checks | Observable successful behavior | Pending             |

Replace the example rows with individually checkable criteria. Verify installed
CLI syntax and actual endpoints. Include a criterion for each selected payment
protocol in a Payments plan, applicable enrollment and protected access in an AEP
plan, and catalog verification plus Directory publication in an ODP plan. For
client-only integrations, require actual application-to-counterpart checks as
well as CLI reference checks; CLI success alone does not test the client code.

Keep running-system verification, submission, and confirmed indexing distinct.
In coordinated work, the later child includes applicable combined-flow checks
and references earlier child evidence. Never record secrets in commands or logs.
Pending authorization, deployment, or external availability is not a pass.
Document an approved deferral and its next action without claiming full completion.