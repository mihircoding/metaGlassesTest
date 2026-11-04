import { test } from 'node:test';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';

const sql = (f) => readFileSync(new URL(f, import.meta.url), 'utf8');

test('schema, RLS and functions', async () => {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.exec(sql('./auth_stub.sql'));
  await db.exec(sql('../migrations/0001_init.sql'));
  await db.exec(sql('./rls_check.sql'));
});
