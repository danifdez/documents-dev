#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { readFile, readdir, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 2) {
    const key = argv[index];
    const value = argv[index + 1];
    if (!key?.startsWith('--') || value === undefined) {
      throw new Error(`Invalid argument near ${key ?? '<end>'}`);
    }
    args[key.slice(2)] = value;
  }
  return args;
}

async function sha256(file) {
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(file)) hash.update(chunk);
  return hash.digest('hex');
}

const args = parseArgs(process.argv.slice(2));
const output = path.resolve(args.output ?? '');
const metadataDir = path.resolve(args.metadata ?? path.join(output, '.metadata'));
if (!args.version || !args.target || !args.output) {
  throw new Error('--version, --target and --output are required');
}

const entries = [];
for (const name of (await readdir(metadataDir)).sort()) {
  if (!name.endsWith('.json')) continue;
  const metadata = JSON.parse(await readFile(path.join(metadataDir, name), 'utf8'));
  const artifactPath = path.resolve(output, metadata.artifact);
  const relative = path.relative(output, artifactPath);
  if (relative.startsWith('..') || path.isAbsolute(relative)) {
    throw new Error(`Artifact escapes output directory: ${metadata.artifact}`);
  }
  const artifactStat = await stat(artifactPath);
  entries.push({
    component: metadata.component,
    variant: metadata.variant ?? null,
    version: metadata.version,
    target: metadata.target,
    file: relative.split(path.sep).join('/'),
    size: artifactStat.size,
    sha256: await sha256(artifactPath),
    runtime: metadata.runtime ?? {},
    requires: metadata.requires ?? {},
  });
}

if (entries.length === 0) throw new Error('No component metadata found');
for (const entry of entries) {
  if (entry.target !== args.target) throw new Error(`Target mismatch in ${entry.file}`);
}

const manifestPath = path.join(output, 'release.json');
let release = { schemaVersion: 1, release: args.version, targets: {} };
try {
  release = JSON.parse(await readFile(manifestPath, 'utf8'));
} catch (error) {
  if (error.code !== 'ENOENT') throw error;
}
if (release.schemaVersion !== 1 || release.release !== args.version) {
  throw new Error('Existing release manifest is incompatible with this build');
}

const target = {};
for (const entry of entries) {
  const descriptor = {
    version: entry.version,
    file: entry.file,
    size: entry.size,
    sha256: entry.sha256,
    runtime: entry.runtime,
    requires: entry.requires,
  };
  if (entry.component === 'models') {
    target.models ??= {};
    target.models[entry.variant] = descriptor;
  } else {
    target[entry.component] = descriptor;
  }
}
release.targets[args.target] = target;
await writeFile(path.join(output, 'release.json'), `${JSON.stringify(release, null, 2)}\n`);

const allEntries = [];
for (const configuredTarget of Object.values(release.targets)) {
  for (const [component, descriptor] of Object.entries(configuredTarget)) {
    if (component === 'models') allEntries.push(...Object.values(descriptor));
    else allEntries.push(descriptor);
  }
}
await writeFile(
  path.join(output, 'checksums.sha256'),
  `${allEntries.sort((left, right) => left.file.localeCompare(right.file)).map((entry) => `${entry.sha256}  ${entry.file}`).join('\n')}\n`,
);
