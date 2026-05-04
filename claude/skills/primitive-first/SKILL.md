# Primitive-First Architecture

Use this skill BEFORE proposing any infrastructure, deployment, or platform-level architecture for Floom.

## Rule

You may NOT propose custom infrastructure (Dockerfiles, container orchestration, API gateways, hand-rolled OpenAPI specs, self-hosted runners) until you have completed the three-step lock below.

## The Lock

### 1. State the Core Primitive
Write one sentence describing what we actually need to do, without implementation details.

- ❌ Wrong: "We need a FastAPI service in Docker on Modal."
- ✅ Right: "We need to safely execute untrusted user code and return stdout/artifacts."

### 2. Search for SaaS/API Solutions
Search the web or your knowledge for managed services that solve this exact primitive. You must list at least 3 candidates with a one-line verdict.

Examples for common Floom primitives:
- **Sandboxed code execution**: e2b, CodeSandbox API, Replit API, GitHub Codespaces API
- **Background jobs**: Inngest, Trigger.dev, QStash, Temporal Cloud
- **Serverless functions**: Vercel Functions, Netlify Functions, Cloudflare Workers
- **Managed databases**: Supabase, Neon, PlanetScale, Upstash
- **File storage**: UploadThing, Cloudflare R2, S3 (only if egress matters)

### 3. Rejection Justification
If you want to build custom infrastructure instead of using a managed service, you must provide a specific, falsifiable reason:

- "e2b's max timeout is 5 minutes, we need 30." → OK
- "At our scale, self-hosted costs $X vs service costs $Y." → OK
- "We need it." → NOT OK
- "For flexibility." → NOT OK
- "We might need X later." → NOT OK

If you cannot write a specific rejection, you MUST use the managed service.

## Examples of Past Mistakes

The following were proposed by agents and were wrong. Do not repeat them:

| Bad Proposal | Why It Was Wrong | What We Should Have Used |
|---|---|---|
| Modal + Railway + custom Docker for code execution | e2b already exists to run arbitrary code safely | e2b SDK |
| Hand-rolled OpenAPI spec for function schemas | OpenAI/Anthropic already define function calling standards | Use their spec directly |
| Self-hosted queue system for background jobs | Managed job queues exist with SDKs | Inngest, Trigger.dev, or QStash |

## Enforcement

If you are asked to design or architect anything, your first message must contain the completed lock above. No exceptions.
