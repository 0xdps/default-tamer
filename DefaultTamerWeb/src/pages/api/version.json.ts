import type { APIRoute } from 'astro';
import latestRelease from '../../data/release.json';

export const GET: APIRoute = () => {
  const payload = {
    version: latestRelease.version,
    releaseDate: latestRelease.releaseDate,
    downloadUrl: `https://www.defaulttamer.app${latestRelease.downloadUrl}`,
    releaseNotesUrl: latestRelease.releaseNotesUrl,
  };

  return new Response(JSON.stringify(payload), {
    headers: {
      'Content-Type': 'application/json',
    },
  });
};
