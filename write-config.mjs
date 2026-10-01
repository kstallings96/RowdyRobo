// Runs as the Vercel build step on the `deploy` branch.
//
// The Supabase credentials live in the Vercel project's environment variables,
// not in git. The exported .pck therefore ships with an empty config.json, and
// this writes the real one next to index.html, which is what the web build
// actually fetches at startup.
//
// The anon/publishable key is public once deployed — anyone can read it out of
// devtools. Row-level security is what protects the data (supabase/schema.sql).
// The service_role key must never be set here.

import { writeFileSync } from 'node:fs';

const supabase_url = (process.env.SUPABASE_URL ?? '').trim().replace(/\/+$/, '');
const supabase_anon_key = (process.env.SUPABASE_ANON_KEY ?? '').trim();

if (!supabase_url || !supabase_anon_key) {
  console.error(
    'SUPABASE_URL / SUPABASE_ANON_KEY are not set on this Vercel project.\n' +
      'Deploying now would publish a game that silently records nothing, so this\n' +
      'build is stopped instead. Add them under Settings -> Environment Variables.'
  );
  process.exit(1);
}

if (supabase_anon_key.includes('service_role')) {
  console.error('That looks like a service_role key. It bypasses row-level security — refusing.');
  process.exit(1);
}

writeFileSync(
  'build/config.json',
  JSON.stringify({ supabase_url, supabase_anon_key }, null, 2) + '\n'
);

console.log(`Wrote build/config.json pointing at ${supabase_url}`);
