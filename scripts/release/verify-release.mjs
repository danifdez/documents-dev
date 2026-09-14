#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { validateReleaseContract } from './release-contract.mjs';

const output = path.resolve(process.argv[2] ?? '');
if (!process.argv[2]) throw new Error('Usage: verify-release.mjs <release-directory>');

const manifest = JSON.parse(await readFile(path.join(output, 'release.json'), 'utf8'));
validateReleaseContract(manifest, process.env.DOCUMENTS_REQUIRE_STANDALONE === '1');

async function sha256(file) {
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(file)) hash.update(chunk);
  return hash.digest('hex');
}

let artifactCount = 0;
for (const [targetName, target] of Object.entries(manifest.targets)) {
  const components = [];
  for (const [name, descriptor] of Object.entries(target)) {
    if (name === 'models') {
      for (const [variant, modelDescriptor] of Object.entries(descriptor)) {
        components.push({ name: `models:${variant}`, ...modelDescriptor });
      }
    } else {
      components.push({ name, ...descriptor });
    }
  }

  for (const component of components) {
    artifactCount += 1;
    const file = path.resolve(output, component.file);
    const relative = path.relative(output, file);
    if (relative.startsWith('..') || path.isAbsolute(relative)) {
      throw new Error(`Artifact escapes release directory: ${component.file}`);
    }
    const fileStat = await stat(file);
    if (fileStat.size !== component.size) throw new Error(`Size mismatch: ${component.file}`);
    const hash = await sha256(file);
    if (hash !== component.sha256) throw new Error(`Checksum mismatch: ${component.file}`);
  }
}

console.log(`Verified ${artifactCount} artifacts for ${manifest.release}`);
