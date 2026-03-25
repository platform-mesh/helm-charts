import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';

import { adminKubeconfigPath, runtimeKubeconfigPath, infraKubeconfigPath } from './constants';

function runKubectlWithKubeconfig(kubeconfigPath: string, args: string[], input?: string): string {
  return execFileSync('kubectl', ['--kubeconfig', kubeconfigPath, ...args], {
    encoding: 'utf8',
    input,
  }).trim();
}

function runAdminKubectl(args: string[], input?: string): string {
  return execFileSync('kubectl', args, {
    encoding: 'utf8',
    env: {
      ...process.env,
      KUBECONFIG: adminKubeconfigPath,
    },
    input,
  }).trim();
}

function runRuntimeKubectl(args: string[], input?: string): string {
  // In remote mode, the runtime cluster has its own kubeconfig
  if (existsSync(runtimeKubeconfigPath)) {
    return execFileSync('kubectl', ['--kubeconfig', runtimeKubeconfigPath, ...args], {
      encoding: 'utf8',
      input,
    }).trim();
  }
  return execFileSync('kubectl', args, {
    encoding: 'utf8',
    input,
  }).trim();
}

function runInfraKubectl(args: string[], input?: string): string {
  return execFileSync('kubectl', ['--kubeconfig', infraKubeconfigPath, ...args], {
    encoding: 'utf8',
    input,
  }).trim();
}

export { runKubectlWithKubeconfig, runAdminKubectl, runRuntimeKubectl, runInfraKubectl };
