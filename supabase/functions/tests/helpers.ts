// Routes match by URL substring; first match wins.
export function fakeFetch(routes: { match: string; body: unknown; status?: number }[]): typeof fetch {
  return (async (input: string | URL | Request) => {
    const url = String(input);
    const r = routes.find((x) => url.includes(x.match));
    if (!r) throw new Error(`unrouted ${url}`);
    return new Response(JSON.stringify(r.body), { status: r.status ?? 200 });
  }) as typeof fetch;
}
