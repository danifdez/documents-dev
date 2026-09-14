import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { validateReleaseContract } from './release-contract.mjs';

const scriptsDir = path.dirname(new URL(import.meta.url).pathname);

async function fixture() {
  const output = await mkdtemp(path.join(tmpdir(), 'documents-release-test-'));
  await mkdir(path.join(output, 'components'));
  await mkdir(path.join(output, '.metadata'));
  await writeFile(path.join(output, 'components', 'backend.tar.gz'), 'artifact');
  await writeFile(path.join(output, '.metadata', 'backend.json'), JSON.stringify({
    component: 'backend',
    version: '1.2.3',
    target: 'linux-x64',
    artifact: 'components/backend.tar.gz',
  }));
  return output;
}

test('generates and verifies a release manifest', async () => {
  const output = await fixture();
  const generated = spawnSync(process.execPath, [
    path.join(scriptsDir, 'manifest.mjs'),
    '--version', '1.2.3', '--target', 'linux-x64',
    '--output', output, '--metadata', path.join(output, '.metadata'),
  ], { encoding: 'utf8' });
  assert.equal(generated.status, 0, generated.stderr);

  const manifest = JSON.parse(await readFile(path.join(output, 'release.json'), 'utf8'));
  assert.equal(manifest.targets['linux-x64'].backend.file, 'components/backend.tar.gz');
  assert.match(manifest.targets['linux-x64'].backend.sha256, /^[0-9a-f]{64}$/);

  const verified = spawnSync(process.execPath, [
    path.join(scriptsDir, 'verify-release.mjs'), output,
  ], { encoding: 'utf8' });
  assert.equal(verified.status, 0, verified.stderr);
});

test('rejects an artifact changed after manifest generation', async () => {
  const output = await fixture();
  const generated = spawnSync(process.execPath, [
    path.join(scriptsDir, 'manifest.mjs'),
    '--version', '1.2.3', '--target', 'linux-x64',
    '--output', output, '--metadata', path.join(output, '.metadata'),
  ]);
  assert.equal(generated.status, 0);
  await writeFile(path.join(output, 'components', 'backend.tar.gz'), 'corrupt');

  const verified = spawnSync(process.execPath, [
    path.join(scriptsDir, 'verify-release.mjs'), output,
  ], { encoding: 'utf8' });
  assert.notEqual(verified.status, 0);
  assert.match(verified.stderr, /(Size|Checksum) mismatch/);
});

test('does not declare a standalone release complete without the Node runtime', async () => {
  const output = await fixture();
  const generated = spawnSync(process.execPath, [
    path.join(scriptsDir, 'manifest.mjs'),
    '--version', '1.2.3', '--target', 'linux-x64',
    '--output', output, '--metadata', path.join(output, '.metadata'),
  ]);
  assert.equal(generated.status, 0);

  const verified = spawnSync(process.execPath, [
    path.join(scriptsDir, 'verify-release.mjs'), output,
  ], { encoding: 'utf8', env: { ...process.env, DOCUMENTS_REQUIRE_STANDALONE: '1' } });
  assert.notEqual(verified.status, 0);
  assert.match(verified.stderr, /missing node/);
});

test('rejects a standalone Backend built for another Node runtime', () => {
  const artifact = {
    version: '1.2.3', file: 'components/artifact.tar.gz', size: 1, sha256: 'a'.repeat(64),
  };
  const manifest = {
    schemaVersion: 1,
    release: '1.2.3',
    targets: {
      'linux-x64': {
        node: { ...artifact, version: '22.23.1' },
        backend: { ...artifact, runtime: { node: '22.0.0' }, requires: { extensions: ['vector', 'age'] } },
        postgres: { ...artifact, requires: { extensions: ['vector', 'age'] } },
        models: { cpu: artifact },
        frontend: artifact,
      },
    },
  };

  assert.throws(() => validateReleaseContract(manifest, true), /Backend and Node versions are incompatible/);
});
