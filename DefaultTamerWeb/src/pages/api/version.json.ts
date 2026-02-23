import type { APIRoute } from 'astro';
import { latestRelease } from '../../data/release';

export const GET: APIRoute = () => {
  const payload = {
    version: latestRelease.version,
    releaseDate: latestRelease.releaseDate,
    downloadUrl: `https://defaulttamer.app${latestRelease.downloadUrl}`,
    releaseNotesUrl: latestRelease.releaseNotesUrl,
  };

  return new Response(JSON.stringify(payload), {
    headers: {
      'Content-Type': 'application/json',
    },
  });
};
