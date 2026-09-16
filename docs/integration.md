# Integrate AEP into your application

This guide is for a coding agent working with a developer in their application
repository. AEP (Agent Enrollment Protocol) lets an Agent enroll with a Service,
check its enrollment status, and obtain supported session credentials. The
Service decides whether to accept the Agent and how to authorize access.

A coding agent is the developer's implementation assistant. An AEP Agent is the
application that calls a Service. Keep those meanings distinct during the interview.

## When the Directory guide coordinates this work

If this guide was opened by the
[Directory integration guide](https://directory.inflowpay.ai/integration.md),
read its `COMMERCE-INTEGRATION-PLAN.md` and reuse confirmed answers. Continue in
the same session. Skip a repeated welcome gate, but retain this guide's assessment,
design decisions, plan approval, implementation reviews, and verification.

During assessment, the child plan and the coordination plan are the only intended
writes. Save both before a handoff. Do not assess other integrations on behalf of
the coordinator or duplicate another child's implementation queue.

In coordinated mode, the related-integration pause suggestions below do not start
another guide. Record follow-up work for the selected child's turn. If a real
dependency blocks progress, return to the coordinator for a developer decision.
Do not add an unselected integration. At completion, return the child-plan path,
acceptance evidence, pending work, and next action to the coordinator.

## Working rules

Follow one stage at a time. Explain the next step and wait for the developer.
Do not turn an initial request into permission to implement the entire workflow.

- Follow repository instructions and preserve unrelated changes.
- Inspect source before making claims. Separate installed packages from
  capabilities actually configured and reached by requests.
- Keep application assessment read-only except for the planning file and,
  in coordinated mode, the coordination plan.
  Do not install dependencies, change code,
  access live credentials, or invoke enrollment, revocation, payments, or other
  state-changing operations during assessment.
- Implement AEP only. ODP and MPP/x402 integrations are separate workflows.
- Preserve existing authentication and authorization. Identify conflicts before
  proposing changes; do not make protected resources public.
- Never record secrets, private keys, tokens, or personal claim values in the plan.
- At each stage, summarize the result and state the specific next action:
  "Next step: type `go` to begin the repository assessment."
  Ask for an explicit answer when a design choice is unresolved; `go` alone
  does not resolve an ambiguous choice.
- Deployment, publication, commits, and pull requests require authorization.

## Keep one durable plan from the start

Once the repository is confirmed, load the
[integration queue template](https://www.aep.foundation/integration-queue-template.md)
and create or reconcile `AEP-INTEGRATION-PLAN.md` there. Announce that it
holds interview answers, findings, decisions, and the eventual execution plan.
Do not wait until implementation planning or ask a separate checkpoint question.

During assessment, write only this planning file and, in coordinated mode, the
coordination plan. Application code and configuration remain unchanged. If the
template cannot be read or the file cannot be saved, report that limitation.
Preserve existing notes and unfinished work. Never store secrets or personal data.

Track the stage as Interview, Assessment, Plan awaiting approval, Implementation,
or Verification. Keep stage separate from whether work is blocked or waiting.
Before every response returning control to the developer, save confirmed answers,
source-backed findings, selected and excluded capabilities, unanswered questions,
the current stage, and the precise next action. Mark proposed choices pending,
not approved. This includes questions and suggestions to switch workflows.

Before suggesting another integration, record the reason, destination, and what
to reassess on return. Save before the suggestion: the developer may immediately
leave the session. Early planning does not authorize application changes.

On return, read the plan and verify current repository state. Reconcile new
capabilities and user changes rather than replaying stale tasks. If the plan is
missing, reassess and recreate it without assuming prior answers or completion.

## Sources

Use the [AEP documentation](https://www.aep.foundation/documentation/) for
explanations and the [AEP specifications](https://www.aep.foundation/protocol/)
for normative requirements. Read the core draft and the applicable identity,
claims, session-credential, and Platform documents. Record their revisions.

Choose the SDK that fits the application:

| Language             | Repository                                   |
| -------------------- | -------------------------------------------- |
| Go                   | https://github.com/aep-foundation/aep-go     |
| Java                 | https://github.com/aep-foundation/aep-java   |
| Node.js / TypeScript | https://github.com/aep-foundation/aep-node   |
| Python               | https://github.com/aep-foundation/aep-python |
| Rust                 | https://github.com/aep-foundation/aep-rust   |

Read the selected version's public APIs, integration guidance, and relevant
examples. Verify framework compatibility and persistence requirements. Do not
assume that package names, adapters, or constructors match across SDKs.

Specifications establish protocol requirements. SDK source establishes available
APIs. Application source establishes current behavior. Developer decisions
establish intended scope. Report conflicts rather than modifying one silently to
fit another. An example is not a substitute for production integration guidance.

## 1. Welcome

Start with a short introduction:

> Welcome to the AEP integration process. We will identify which side of AEP
> your application needs, examine the current code, and create an integration
> plan with you. Once you approve it, we will implement and verify one task at
> a time while preserving your application's existing behavior.

Explain that the workflow supports first-time integration and updates. An
existing plan is helpful but not required. Pause before beginning the interview.

## 2. Confirm the role and goals

Ask these questions in small groups, skipping answers already provided:

1. Which repository and application should receive AEP?
2. Are you building an Agent application that calls Services, a Service that
   accepts Agents, or both?
3. Which SDK should we use: Go, Java, Node.js, Python, or Rust? Offer to recommend
   one from the repository if the developer is unsure.
4. What should the application be able to do after integration? Ask for a
   concrete example, such as enrolling before calling a search API, or accepting
   enrolled Agents on an existing endpoint.
5. Is this a new integration or an expansion of existing AEP support?
6. Are related ODP or MPP/x402 integrations planned? Existing implementations
   will be checked during assessment.

Explain the role choices:

| Role              | What this integration enables                                                                                              |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Agent application | Discover a Service's requirements, enroll, check status, and use supported authentication and session credentials.         |
| Service           | Advertise requirements, handle enrollment, verify requests, apply access policy, and optionally issue session credentials. |
| Both              | Implement both responsibilities in separate, independently reviewed tasks.                                                 |

Do not assume that the application must operate a Platform. Hosted identity is a
separate design question when identity custody or an existing provider makes it
relevant. Using a Platform is different from building one.

Unlike catalog richness, AEP scope is defined by concrete responsibilities and
capabilities. Do not apply ODP's Minimal/Recommended/Complete labels as AEP
conformance tiers. Help the developer select the required behavior after the
assessment; every selected feature must meet its applicable requirements.

Summarize the target and goals. Pause before scanning.

## 3. Assess the current repository

Announce what you will inspect. Keep the scan bounded to the confirmed
application and do not expose secrets or personal data.

Inspect:

- Runtime, framework, dependency versions, routes, middleware, and deployment.
- Existing AEP discovery, command handlers or clients, and prior integration plans.
- Existing identity custody, signing, user approval, and credential storage.
- Authentication and authorization for application resources.
- Persistence, tenant separation, transaction behavior, caches, and expiry.
- Existing enrollment or account lifecycle rules and required user information.
- ODP and MPP/x402 configuration and relevant request paths, if present.
- Tests, startup instructions, build gates, and uncommitted work.

For Agent applications, trace where identities and credentials come from, how
requests receive authentication, and how pending operations reach the user.
For Services, trace how requests reach validation, policy, storage, and protected
resources. Distinguish source inspection from runtime behavior actually tested.

### Discover where Agent access belongs

For a Service integration, start from the authenticated experiences the
application already provides. Look for browser login, customer accounts,
shopping and checkout, authenticated REST APIs, and API-key or token issuance.
Trace them to account ownership, tenant boundaries, permissions, credential
storage, and operations requiring authentication.

Propose which existing capabilities enrolled Agents could use before asking the
developer to design an enrollment system:

> Your website requires a customer account to purchase, and your REST API
> accepts API keys. Should enrolled Agents be able to purchase, use the API,
> or both?

Use that wording only when supported by repository evidence. Present the actual
operations and restrictions found, followed by a selection table:

| Capability found       | Existing access model                     | Proposed AEP integration                            | Developer selection |
| ---------------------- | ----------------------------------------- | --------------------------------------------------- | ------------------- |
| Authenticated checkout | Customer account and purchase permissions | Agent access to selected purchase operations        | Include or exclude  |
| Authenticated REST API | API key and API permissions               | AEP session credentials for selected API operations | Include or exclude  |

Replace these illustrative rows with actual findings and source locations.
Do not assume browser checkout has a suitable Agent-callable API. If application
API work is needed, explain it and obtain approval before adding it to the plan.
Preserve existing browser login and shopping behavior unless the developer
explicitly requests a change.

Then establish how Agent access fits the application:

- Does enrollment associate the Agent with an existing customer account, create
  a separate Agent relationship, or use another existing model?
- If the Agent acts for a customer, how does that customer authorize the
  association? Which existing account-linking or approval flow can be reused?
- Which existing permissions and tenant restrictions apply?
- Can existing credential infrastructure issue and validate AEP session
  credentials while satisfying identifier, expiry, and revocation requirements?
- Which operations accept those credentials, and which remain outside the scope?

Enrollment does not automatically grant customer permissions. A browser session
is not automatically an Agent credential. Never copy browser sessions, associate
accounts solely from unverified claims, or transfer customer permissions to an
Agent without an approved design.

API-key sessions are a useful recommendation when they fit an existing API,
not a universal requirement. Verify existing key infrastructure against the
selected grant type; matching names do not prove compatibility. Preserve
application authorization after authentication succeeds.

For an Agent application, apply the same discovery-first reasoning to its
existing outbound API calls and credential handling. Propose which interactions
should use AEP, constrained by the destination Services' advertisements.
Do not apply Service-side account or endpoint changes to an Agent-only project.

Follow this order: discover protected capabilities, propose the access scope,
obtain the developer's selection, then design enrollment and credentials.
Record excluded capabilities too. If no authentication infrastructure exists,
report that and discuss the needed design rather than assuming a web account
or credential system exists.

Present an assessment with exact evidence:

| Area                        | Current behavior | Integration implications        | Unresolved decision         |
| --------------------------- | ---------------- | ------------------------------- | --------------------------- |
| Role and framework          | Verified source  | Selected SDK components         | Compatibility question      |
| Identity and authentication | Verified source  | Existing behavior to preserve   | Custody or access choice    |
| Persistence and lifecycle   | Verified source  | Required stores and cleanup     | Durability or policy choice |
| Related protocols           | Verified source  | Existing interactions           | Planned integrations        |
| Verification                | Existing checks  | Additional integration evidence | Environment constraints     |

Reconcile any older plan against current code. Do not rebuild working integration
code just because the plan is absent or outdated. Pause for assessment review.

## 4. Resolve role-specific choices

Ask only questions that source inspection cannot answer. Explain the practical
effect of each choice using the application's actual endpoints and data.
First confirm the access scope selected from the assessment. Reuse selections
already provided; ask the following design questions only where still unresolved
for the selected capabilities.

### Agent application

Confirm:

- Which Service origins the application will contact, or how users select them.
- How Agent identity keys will be held and persisted: existing local custody,
  an existing hosted identity provider, or another supported approach.
- How the application supplies claims and handles required Owner action without
  fabricating user data or leaking it into logs.
- Which supported credential types the application needs and how credentials
  remain separated by Service and Agent identity.
- How pending enrollment or signing, cancellation, expiry, and retry are shown
  to users or returned to automated callers.
- Which protected resources will be called and which advertised authentication
  methods are appropriate.

A Service's Inspect advertisement determines available commands and methods.
Do not infer support from a familiar endpoint name or attempt unadvertised
commands. Do not give the Agent application privileged lifecycle administration.

### Service

Confirm:

- Public origin, Service identity, endpoint base, and framework adapter.
- Supported identity methods and how assertions are verified.
- Enrollment policy: immediate acceptance, review, claims, or other requirements.
- Which claims are required, preferred, or optional, why they are requested,
  and how supplied claims are evaluated.
- Whether session credentials are needed and which formats the Service will
  actually issue and accept.
- Which application resources require authentication and how enrollment state
  and application permissions affect access.
- Storage for enrollment, credentials, replay prevention, and idempotency, using
  the application's existing persistence where supported.
- Expiry, revocation, concurrency, tenant isolation, and restart behavior.

Do not invent scopes, claim requirements, account roles, or approval processes.
An application may accept enrollment automatically or require additional action;
ask which policy is intended. Distinguish a submitted claim from a verified one.

### Authentication distinctions

Exposed Enroll, Status, Grant, and Revoke commands accept baseline
`Authorization: AEP <jwt>` authentication. Grant and Revoke use that baseline
assertion. Inspect is unauthenticated.

Protected application resources are separate: use their advertised
`authentication.methods`. Baseline authentication on AEP command endpoints
does not imply that a protected resource accepts `aep-jwt`.

An Agent may enroll without obtaining a session credential. When a credential
is issued, follow its grant-type requirements, including its identifier,
presentation rules, expiry, and revocation behavior. Do not weaken credential
requirements merely because issuing a credential is optional.

Plan against the selected specification revision rather than treating this
summary as an exhaustive substitute for the drafts.

### Related integrations

AEP does not require payment support. If payments or ODP are absent, do not add
them or present that absence as a conformance failure.

If the developer plans a related integration, offer to continue AEP with the
current application or pause and complete the separate workflow first:

- [ODP integration](https://www.offeringprotocol.org/integration.md)
- [InFlow Payments integration](https://app.inflowpay.ai/integration.md)

Check the destination guide before handing off. If it is empty or unavailable,
say so without inventing its instructions. Do not implement it inside this plan.

Existing payment endpoints can require attention to authentication header
composition and middleware order. Trace their real behavior; do not replace
payment authentication with AEP or bypass settlement. If existing ODP metadata
needs revision, record the follow-up for the ODP workflow rather than silently
expanding this integration.

When a separate integration is complete, reassess current code before resuming.
Summarize and obtain agreement on the exact AEP scope.

## 5. Complete the executable plan

Expand the existing `AEP-INTEGRATION-PLAN.md` using the confirmed interview and
assessment. Preserve their evidence and decisions. Set the stage to Plan awaiting
approval; early notes are not an approved implementation plan.

Include the chosen role, SDK version, specification revisions, source-backed
assessment, approved decisions, and concrete completion criteria. Separate
Agent and Service tasks if both are needed.

Record selected and excluded capabilities, the account-association design,
reused permissions and credential infrastructure, and any explicitly approved
application API work. Make these decisions visible before implementation.

Map applicable normative requirements to implementation and verification tasks.
Include the requirements relevant to:

- Inspect discovery, media type, version handling, origin binding, and redirects.
- Command advertisement, paths, assertion verification, and identity methods.
- Enrollment lifecycle, claims, pending states, and Owner action.
- Session-credential issuance, storage, expiry, and revocation when selected.
- Protected-resource authentication and application authorization.
- Replay prevention, idempotency, concurrency, and durable storage.
- Errors, cancellation, retries, credential leakage, and partial failures.
- Affected existing browser and API flows and checks preserving their behavior.

Reuse the SDK's verified protocol implementation rather than building a second
protocol engine. Supply application policy, storage, and framework integration
at the boundaries the SDK actually exposes. Do not use in-memory example stores
for a deployment that requires persistence across restarts or multiple instances.

Present the plan, its first task, checks, and unresolved issues. Obtain approval
before modifying application code.

## 6. Implement and review one task at a time

Follow the plan template's seven-step review process. Work in coherent slices.
Trace actual request and response paths, challenge security-sensitive defaults,
and test integration with application storage and middleware.

For each task, update the plan and report:

- Behavior implemented and requirements verified.
- Review findings fixed.
- Actual checks run and their outcomes.
- Remaining limitations, deferred work, or decisions.
- The next task and an invitation to type `go`.

Do not equate enrollment with permission to perform every application action.
Do not add compatibility code, new storage layers, or helpers without a concrete
need. Ask before changing the approved design.

## Exit criteria to generate in the plan

End the generated plan with two separate, cumulative acceptance groups:

1. **Project acceptance:** derive the project's prescribed unit tests, integration
   tests, coverage thresholds, static analysis, regression checks, and other
   agreed quality gates from its source and instructions. These remain required.
2. **InFlow acceptance:** verify the integration against a running system using
   InFlow CLI and the role-specific checks below. These do not replace project
   tests or justify lowering their thresholds.

For every criterion, record the exact command or procedure, environment, target,
prerequisites, expected result, evidence, and state. Verify CLI syntax and options
against its installed version before generating runnable commands. Command names
below are examples, not complete invocations. Never save secrets in command logs.

For a Service integration, generate `inflow aep inspect` and authorized
`inflow aep enroll` checks against the running Service. Include approval or pending
handling, `inflow aep status`, session-credential grants when selected, and actual
access to a protected resource using the supported authentication. Check that
missing or invalid authentication does not obtain protected results.

For an Agent-only integration, CLI enrollment alone does not exercise the Agent
being built. Require its own enrollment and protected-resource flow against a
controlled compatible Service; use the CLI against that Service as a reference.
Do not introduce Service endpoints into an Agent-only application just for a check.

Distinguish implementation complete, local verification, deployed verification,
and external publication. Obtain explicit authorization for enrollment, credential
changes, payments, and publication. Pending approval or unavailable infrastructure
is not a passing criterion. A developer-approved deferral remains visible in the
handoff rather than being reported as end-to-end success.

## 7. Verify and hand off

Verify affected existing flows identified in the plan, not only the new protocol
behavior. Examples include browser login and checkout, catalog navigation, and
existing API credentials, permissions, and tenant restrictions. Select relevant
flows and use existing tests or controlled test environments. This does not
authorize real purchases or a new application-wide test framework. Report
affected flows that could not be verified.

Run the repository's prescribed checks and relevant integration tests. Use
controlled local or test environments for state-changing scenarios. Obtain
explicit authorization before accessing live accounts or changing live state.

Verify the paths implemented for the selected role: discovery and identity
binding; successful and unsuccessful enrollment; supported pending/approval
flows; protected-resource authentication; and session credentials when enabled.
Check failures at the real integration boundaries, not only mocks of assumptions.

Verify storage survives restarts where required and that tenant or Service
identities cannot share credentials incorrectly. Check revocation, expiry,
retries, cancellation, and error presentation for applicable flows.

Review every changed file after the checks. Distinguish locally verified
behavior from deployed behavior, and explain checks that could not run.
Do not claim end-to-end success when a real counterpart was unavailable.

Finish with the plan path, files changed, commands and results, remaining risks,
and the precise next action. Deployment and publication require separate approval.

## Re-run this guide

Start from current repository evidence on every run. A developer may add
session credentials, use a hosted identity provider, introduce payments, or
build the other side of AEP later. Confirm the new goals and plan the changes
needed without discarding working behavior. A previous plan is useful context,
not a prerequisite or proof that the integration is complete.