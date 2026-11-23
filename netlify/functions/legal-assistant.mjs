const json = (body, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
})

export default async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed.' }, 405)
  const env = globalThis.process?.env || {}
  const supabaseUrl = env.SUPABASE_URL
  const supabaseKey = env.SUPABASE_ANON_KEY
  const openAiKey = env.OPENAI_API_KEY
  const model = env.OPENAI_MODEL
  if (!supabaseUrl || !supabaseKey || !openAiKey || !model) return json({ error: 'The private AI service is not fully configured yet.' }, 503)

  const authorization = request.headers.get('authorization') || ''
  if (!authorization.startsWith('Bearer ')) return json({ error: 'Sign in to use the assistant.' }, 401)

  try {
    const supabaseBase = supabaseUrl.replace(/\/$/, '')
    const auth = await fetch(`${supabaseBase}/auth/v1/user`, {
      headers: { apikey: supabaseKey, authorization },
    })
    if (!auth.ok) return json({ error: 'Your session is no longer valid. Please sign in again.' }, 401)
    const user = await auth.json()

    const body = await request.json()
    const question = typeof body.question === 'string' ? body.question.trim() : ''
    const jurisdiction = typeof body.jurisdiction === 'string' ? body.jurisdiction.trim().slice(0, 120) : ''
    if (!question || question.length > 5000) return json({ error: 'Enter a question under 5,000 characters.' }, 400)

    const utcStart = new Date()
    utcStart.setUTCHours(0, 0, 0, 0)
    const usageQuery = new URLSearchParams({ select: 'id', owner_id: `eq.${user.id}`, created_at: `gte.${utcStart.toISOString()}` })
    const usageHeaders = { apikey: supabaseKey, authorization, 'content-type': 'application/json' }
    const usageResponse = await fetch(`${supabaseBase}/rest/v1/ai_usage?${usageQuery}`, { headers: { ...usageHeaders, range: '0-25' } })
    if (!usageResponse.ok) return json({ error: 'The assistant usage limit could not be checked. Please try again later.' }, 503)
    const usage = await usageResponse.json()
    if (usage.length >= 25) return json({ error: 'You have reached the assistant limit of 25 questions for today.' }, 429)
    const recorded = await fetch(`${supabaseBase}/rest/v1/ai_usage`, {
      method: 'POST', headers: { ...usageHeaders, prefer: 'return=minimal' }, body: JSON.stringify({ owner_id: user.id }),
    })
    if (!recorded.ok) return json({ error: 'The assistant could not record this request. Please try again later.' }, 503)

    const response = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: { authorization: `Bearer ${openAiKey}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        model,
        store: false,
        instructions: 'You are an assistant for legal professionals. Provide general legal information and drafting support, not legal advice. Ask for jurisdiction if the answer depends on local law. Do not invent statutes, cases, citations, deadlines, or facts. State uncertainty and recommend checking primary legal sources and a qualified lawyer. Do not imply you reviewed client records or documents unless the user includes their contents in this question.',
        input: `Jurisdiction: ${jurisdiction || 'Not specified'}\n\nQuestion: ${question}`,
        max_output_tokens: 900,
      }),
    })
    if (!response.ok) {
      const errorBody = await response.json().catch(() => ({}))
      const message = errorBody?.error?.message || 'The AI provider could not complete this request.'
      return json({ error: message }, response.status === 429 ? 429 : 502)
    }
    const result = await response.json()
    const answer = result.output_text || (result.output || []).flatMap((item) => item.content || []).filter((item) => item.type === 'output_text').map((item) => item.text).join('\n')
    if (!answer) return json({ error: 'The assistant did not return an answer. Please try again.' }, 502)
    return json({ answer })
  } catch {
    return json({ error: 'The assistant could not reach its service. Please try again.' }, 502)
  }
}
