import { newOrgName } from './constants';

function logStep(step: string): void {
  console.log(`[portal-e2e] ${new Date().toISOString()} ${step}`);
}

function portalOrgUrl(pathname = ''): string {
  return `https://${newOrgName}.portal.localhost:8443/${pathname.replace(/^\//, '')}`;
}

export { logStep, portalOrgUrl };
