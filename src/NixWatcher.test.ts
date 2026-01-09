import { execSync, spawn } from 'child_process';
import { describe, it, expect } from 'vitest';
import {
  mkdtempSync,
  cpSync,
  readdirSync,
  readFileSync,
  existsSync,
  copyFileSync,
  mkdirSync,
} from 'fs';
import { setTimeout } from 'timers';

function fileContains(filePath: string, search: string): boolean {
  const content = readFileSync(filePath, 'utf8');
  return content.includes(search);
}

function countProcesses(processName: string) {
  let count = 0;
  const entries = readdirSync('/proc');
  for (const entry of entries) {
    if (!/^\d+$/.test(entry)) continue; // skip non-PID directories

    const commPath = `/proc/${entry}/comm`;
    try {
      const comm = readFileSync(commPath, 'utf8').trim();
      if (comm.includes(processName)) {
        // matches pgrep's default substring search
        count++;
      }
    } catch {
      // Ignore: process may have terminated or permission issue
    }
  }
  return count;
}

function isNixAvailable(): boolean {
  try {
    execSync('which nix', { stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
}

describe.skipIf(!isNixAvailable())('Nix Watcher Integration Tests', () => {
  it('should sync bun.lock changes to bun.nix and clean up processes', async () => {
    const temp = mkdtempSync('/tmp/');
    // Copy only lock files, nix files, and json files
    const filesToCopy = [
      'bun.lock',
      'bun.nix',
      'flake.nix',
      'flake.lock',
      'package.json',
    ];
    for (const file of filesToCopy) {
      if (existsSync(file)) {
        const destPath = `${temp}/${file}`;
        // Ensure destination directory exists
        const destDir = destPath.substring(0, destPath.lastIndexOf('/'));
        if (destDir && !existsSync(destDir)) {
          mkdirSync(destDir, { recursive: true });
        }
        copyFileSync(file, destPath);
      }
    }
    process.chdir(temp);

    const initialCount = countProcesses('inotifywait');

    execSync('WATCHER_TIMEOUT=2 timeout 10 nix develop --command bun install cowsay', {
      stdio: 'inherit',
    });

    await new Promise((resolve) => setTimeout(resolve, 3000));

    const cowsayPassed = fileContains('bun.lock', 'cowsay');
    const cowsayNixPassed = fileContains('bun.nix', 'cowsay');
    const afterCount = countProcesses('inotifywait');
    const inotifyPassed = afterCount === initialCount;
    const bunPassed = existsSync('bun.nix');

    expect(inotifyPassed).toBe(true);
    expect(bunPassed).toBe(true);
    expect(cowsayPassed).toBe(true);
    expect(cowsayNixPassed).toBe(true);
  }, 10000);

  it('should not leave inotifywait processes after command', async () => {
    const temp = mkdtempSync('/tmp/');
    // Copy only lock files, nix files, and json files
    const filesToCopy = [
      'bun.lock',
      'bun.nix',
      'flake.nix',
      'flake.lock',
      'package.json',
    ];
    for (const file of filesToCopy) {
      if (existsSync(file)) {
        const destPath = `${temp}/${file}`;
        // Ensure destination directory exists
        const destDir = destPath.substring(0, destPath.lastIndexOf('/'));
        if (destDir && !existsSync(destDir)) {
          mkdirSync(destDir, { recursive: true });
        }
        copyFileSync(file, destPath);
      }
    }
    process.chdir(temp);

    const initialCount = countProcesses('inotifywait');
    const output = execSync(
      'WATCHER_TIMEOUT=2 timeout 10 nix develop --command echo "Hello World"',
      {
        encoding: 'utf8',
      }
    );
    await new Promise((resolve) => setTimeout(resolve, 2000));
    const afterCount = countProcesses('inotifywait');
    const inotifyPassed = afterCount === initialCount;
    const outputPassed = output.includes('Hello World');

    expect(inotifyPassed).toBe(true);
    expect(outputPassed).toBe(true);
  }, 10000);

  it('should count running processes correctly', async () => {
    const proc = spawn('sleep', ['5'], { detached: true, stdio: 'ignore' });
    await new Promise((resolve) => setTimeout(resolve, 200));
    const countBefore = countProcesses('sleep');
    expect(countBefore).toBeGreaterThanOrEqual(1);
    proc.kill('SIGKILL');
    await new Promise((resolve) => setTimeout(resolve, 500));
    const countAfter = countProcesses('sleep');
    expect(countAfter).toBeLessThanOrEqual(countBefore);
  }, 10000);

  it('should pass nix flake check', () => {
    const temp = mkdtempSync('/tmp/');
    // Copy only lock files, nix files, and json files
    const filesToCopy = [
      'bun.lock',
      'bun.nix',
      'flake.nix',
      'flake.lock',
      'package.json',
    ];
    for (const file of filesToCopy) {
      if (existsSync(file)) {
        const destPath = `${temp}/${file}`;
        // Ensure destination directory exists
        const destDir = destPath.substring(0, destPath.lastIndexOf('/'));
        if (destDir && !existsSync(destDir)) {
          mkdirSync(destDir, { recursive: true });
        }
        copyFileSync(file, destPath);
      }
    }
    process.chdir(temp);

    execSync('nix flake check', { stdio: 'inherit' });
  }, 20000);
});
