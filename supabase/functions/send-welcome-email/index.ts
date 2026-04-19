import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, authorization",
};

function generatePassword(email: string): string {
  const prefix = email.split("@")[0].substring(0, 4);
  return `Archi@${prefix}2025!`;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email, name } = await req.json();
    if (!email) throw new Error("Email requis");

    const password = generatePassword(email);

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // ── 1. Créer le compte Auth ──────────────────────────────
    const { error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (authError && !authError.message.toLowerCase().includes("already")) {
      throw new Error(authError.message);
    }

    // ── 2. Envoyer via Brevo ─────────────────────────────────
    const res = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: {
        "api-key": Deno.env.get("BREVO_API_KEY")!,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        sender: { name: "ArchiManager", email: "soumayabenkaabar4@gmail.com" },
        to: [{ email: email, name: name }],
        subject: "Votre accès au portail ArchiManager",
        htmlContent: `
          <div style="font-family:sans-serif;max-width:480px;margin:auto;padding:24px">
            <h2 style="color:#1a1a1a">Bienvenue, ${name} 👋</h2>
            <p>Votre accès au portail client ArchiManager a été créé.</p>
            <div style="background:#f3f4f6;border-radius:8px;padding:16px;margin:20px 0">
              <p style="margin:0 0 8px"><b>Email :</b> ${email}</p>
              <p style="margin:0"><b>Mot de passe :</b>
                <span style="font-family:monospace;background:#e5e7eb;padding:2px 8px;border-radius:4px">
                  ${password}
                </span>
              </p>
            </div>
            <p style="color:#ef4444;font-size:13px">
              ⚠️ Changez votre mot de passe après la première connexion.
            </p>
          </div>
        `,
      }),
    });

    if (!res.ok) {
      const data = await res.json();
      throw new Error(JSON.stringify(data));
    }

    console.log("✅ Email envoyé à:", email);

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );

  } catch (e) {
    console.error("❌ ERROR:", e.message);
    return new Response(
      JSON.stringify({ error: e.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});