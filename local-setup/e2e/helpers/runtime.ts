import { execFileSync } from 'node:child_process';

import { adminKubeconfigPath, infraKubeconfigPath, remoteMode, runtimeKubeconfigPath } from './constants';

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

// In remote mode, pin to the runtime kubeconfig explicitly so we don't depend
// on the developer's ambient KUBECONFIG pointing at the right cluster.  In
// single-cluster mode, fall through to whatever KUBECONFIG already points at.
function runRuntimeKubectl(args: string[], input?: string): string {
  if (remoteMode) {
    return runKubectlWithKubeconfig(runtimeKubeconfigPath, args, input);
  }
  return execFileSync('kubectl', args, {
    encoding: 'utf8',
    input,
  }).trim();
}

// Only meaningful in remote mode (operator + flux/argo run on infra).  Callers
// should guard with `remoteMode` before invoking.
function runInfraKubectl(args: string[], input?: string): string {
  return runKubectlWithKubeconfig(infraKubeconfigPath, args, input);
}

export { runKubectlWithKubeconfig, runAdminKubectl, runInfraKubectl, runRuntimeKubectl };
