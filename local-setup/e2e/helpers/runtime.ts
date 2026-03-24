import { execFileSync } from 'node:child_process';

import { adminKubeconfigPath } from './constants';

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
  return execFileSync('kubectl', args, {
    encoding: 'utf8',
    input,
  }).trim();
}

export { runKubectlWithKubeconfig, runAdminKubectl, runRuntimeKubectl };
