import path from 'node:path';

const SHA256_PATTERN = /^[a-f0-9]{64}$/;
const TARGET_PATTERN = /^(linux|darwin|win32)-(x64|arm64)$/;

function isObject(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function validateDescriptor(descriptor, label) {
  if (!isObject(descriptor) || typeof descriptor.version !== 'string' || !descriptor.version) {
    throw new Error(`Invalid artifact descriptor: ${label}`);
  }
  if (typeof descriptor.file !== 'string' || !isSafeReleasePath(descriptor.file)) {
    throw new Error(`Invalid artifact path: ${label}`);
  }
  if (!Number.isSafeInteger(descriptor.size) || descriptor.size <= 0) {
    throw new Error(`Invalid artifact size: ${label}`);
  }
  if (typeof descriptor.sha256 !== 'string' || !SHA256_PATTERN.test(descriptor.sha256)) {
    throw new Error(`Invalid artifact checksum: ${label}`);
  }
}

export function isSafeReleasePath(value) {
  if (!value || value.includes('\\') || path.posix.isAbsolute(value) || /^[a-zA-Z]:/.test(value)) return false;
  return value.split('/').every((segment) => segment !== '' && segment !== '.' && segment !== '..');
}

export function validateReleaseContract(manifest, requireStandalone = false) {
  if (!isObject(manifest) || manifest.schemaVersion !== 1 || typeof manifest.release !== 'string' || !manifest.release) {
    throw new Error('Invalid release manifest header');
  }
  if (!isObject(manifest.targets) || Object.keys(manifest.targets).length === 0) {
    throw new Error('Release manifest has no targets');
  }

  for (const [targetName, target] of Object.entries(manifest.targets)) {
    if (!TARGET_PATTERN.test(targetName) || !isObject(target)) throw new Error(`Invalid release target: ${targetName}`);
    for (const component of ['node', 'backend', 'postgres', 'frontend']) {
      if (target[component] !== undefined) validateDescriptor(target[component], `${targetName}.${component}`);
    }
    if (target.models !== undefined) {
      if (!isObject(target.models)) throw new Error(`Invalid Models variants: ${targetName}`);
      for (const [variant, descriptor] of Object.entries(target.models)) {
        if (!['cpu', 'cuda', 'metal'].includes(variant)) throw new Error(`Invalid Models variant: ${variant}`);
        validateDescriptor(descriptor, `${targetName}.models.${variant}`);
      }
    }

    if (!requireStandalone) continue;
    for (const required of ['node', 'backend', 'postgres', 'frontend']) {
      if (!target[required]) throw new Error(`Standalone target ${targetName} is missing ${required}`);
    }
    if (!target.models || Object.keys(target.models).length === 0) {
      throw new Error(`Standalone target ${targetName} is missing models`);
    }
    if (target.backend.runtime?.node !== target.node.version) {
      throw new Error(`Backend and Node versions are incompatible for ${targetName}`);
    }
    const postgresExtensions = new Set(target.postgres.requires?.extensions ?? []);
    for (const extension of target.backend.requires?.extensions ?? []) {
      if (!postgresExtensions.has(extension)) {
        throw new Error(`PostgreSQL is missing Backend extension ${extension} for ${targetName}`);
      }
    }
  }

  return manifest;
}
