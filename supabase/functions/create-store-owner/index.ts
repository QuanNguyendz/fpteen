import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Deno runtime global (for TypeScript type checking)
// This declaration has no effect at runtime on Supabase Edge Functions.
declare const Deno: any;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Verify caller is admin
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return jsonError("Unauthorized", 401);

    const { data: { user: caller }, error: authError } =
      await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
    if (authError || !caller) return jsonError("Unauthorized", 401);

    const { data: callerProfile } = await supabase
      .from("users")
      .select("role")
      .eq("id", caller.id)
      .single();

    if (!callerProfile || callerProfile.role !== "admin") {
      return jsonError("Forbidden: admin only", 403);
    }

    const { email, password, full_name, store_name, store_description, store_address } =
      await req.json();

    if (!email || !password || !full_name || !store_name) {
      return jsonError("Missing required fields: email, password, full_name, store_name", 400);
    }

    // Create auth user with service role (no sign-in side effect)
    const { data: newAuthUser, error: createError } =
      await supabase.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name, role: "store_owner" },
      });

    if (createError || !newAuthUser.user) {
      return jsonError(`Failed to create user: ${createError?.message}`, 500);
    }

    const newUserId = newAuthUser.user.id;

    // Ensure public.users row exists (trigger should have created it, but safety check)
    await supabase.from("users").upsert({
      id: newUserId,
      email,
      full_name,
      role: "store_owner",
    }, { onConflict: "id" });

    // Create the store
    const { data: store, error: storeError } = await supabase
      .from("stores")
      .insert({
        owner_id: newUserId,
        name: store_name,
        description: store_description ?? null,
        address: store_address ?? null,
        is_active: true,
      })
      .select()
      .single();

    if (storeError) {
      // Rollback: delete the auth user
      await supabase.auth.admin.deleteUser(newUserId);
      return jsonError(`Failed to create store: ${storeError.message}`, 500);
    }

    return new Response(
      JSON.stringify({ user_id: newUserId, store_id: store.id }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("create-store-owner error:", err);
    return jsonError("Internal server error", 500);
  }
});

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
