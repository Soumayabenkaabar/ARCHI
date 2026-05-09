import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Correspondance modèles Anthropic → Groq
function mapModel(anthropicModel: string): string {
  if (anthropicModel.includes('haiku'))  return 'llama-3.1-8b-instant'
  if (anthropicModel.includes('sonnet')) return 'llama-3.3-70b-versatile'
  return 'llama-3.1-8b-instant'
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Corps au format Anthropic envoyé par Flutter
    const body = await req.json()

    // Conversion vers format OpenAI (compatible Groq)
    const messages: { role: string; content: string }[] = []
    if (body.system) {
      messages.push({ role: 'system', content: body.system })
    }
    for (const m of (body.messages ?? [])) {
      messages.push({ role: m.role, content: m.content })
    }

    const groqBody = {
      model:      mapModel(body.model ?? ''),
      messages,
      max_tokens: body.max_tokens ?? 1024,
    }

    const groqRes = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')}`,
        'Content-Type':  'application/json',
      },
      body: JSON.stringify(groqBody),
    })

    const data = await groqRes.json()

    if (!groqRes.ok) {
      return new Response(JSON.stringify({ error: data }), {
        status: groqRes.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Conversion réponse Groq → format Anthropic (attendu par Flutter)
    const anthropicResponse = {
      content: [{ text: data.choices[0].message.content as string }],
    }

    return new Response(JSON.stringify(anthropicResponse), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
