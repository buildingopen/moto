// moto runtime-api
// Minimal code-execution sandbox. POST /exec with {cmd, timeout_ms} → stdout/stderr.
// Intended for trusted agents only — this is NOT a multi-tenant sandbox.

import Fastify from 'fastify';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';

const app = Fastify({ logger: true });
const PORT = Number(process.env.PORT || 3001);

app.get('/health', async () => ({ status: 'ok', ts: Date.now() }));

app.post('/exec', async (req, reply) => {
  const { cmd, cwd = '/tmp', timeout_ms = 60_000, shell = '/bin/bash' } = req.body ?? {};
  if (!cmd || typeof cmd !== 'string') {
    reply.code(400);
    return { error: "body must include { cmd: string }" };
  }

  const id = randomUUID();
  const start = Date.now();
  return await new Promise((resolve) => {
    const child = spawn(shell, ['-lc', cmd], { cwd });
    let stdout = '', stderr = '', killed = false;
    const timer = setTimeout(() => {
      killed = true;
      child.kill('SIGKILL');
    }, timeout_ms);

    child.stdout.on('data', (b) => { stdout += b.toString(); });
    child.stderr.on('data', (b) => { stderr += b.toString(); });
    child.on('close', (code) => {
      clearTimeout(timer);
      resolve({
        id,
        code,
        killed,
        duration_ms: Date.now() - start,
        stdout: stdout.slice(-64_000),
        stderr: stderr.slice(-64_000),
      });
    });
  });
});

app.listen({ host: '0.0.0.0', port: PORT }).then(() => {
  app.log.info(`runtime-api listening on ${PORT}`);
});
